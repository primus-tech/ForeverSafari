--[[
    Forever Safari: Diagnostic Taint Watcher & Action Block Detector
    Listens for ADDON_ACTION_BLOCKED and ADDON_ACTION_FORBIDDEN events,
    records the exact blocked action, caller stack, and blamed addon,
    and provides the /fstaint command to inspect taint state.
]]

local addonName, ns = ...

-- Global storage for easy macro / /dump inspection
ForeverSafari_LastTaint = nil

local watcher = CreateFrame("Frame", "ForeverSafariTaintWatcherFrame")
watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watcher:RegisterEvent("PLAYER_LOGIN")

local function RecordTaint(event, blockedAddon, blockedAction)
    local stack = debugstack and debugstack(2, 14, 14) or "No debugstack available"
    local timeStr = date and date("%Y-%m-%d %H:%M:%S") or "Just now"

    ForeverSafari_LastTaint = {
        event = tostring(event),
        addon = tostring(blockedAddon),
        action = tostring(blockedAction),
        stack = stack,
        time = timeStr,
    }

    if ForeverSafariDB then
        ForeverSafariDB.lastTaint = ForeverSafari_LastTaint
    end

    local alert = string.format("|cffff0000[Forever Safari Taint Inspector]|r Event: |cffffff00%s|r | Addon: |cffff5555%s|r | Blocked Action: |cff00ffff%s|r", 
        tostring(event), tostring(blockedAddon), tostring(blockedAction))

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(alert)
        DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00Stack Trace:|r\n" .. stack)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffccTip: Type |cffffd100/fstaint|cff00ffcc at any time to review this diagnostic.|r")
    else
        print(alert)
        print(stack)
    end
end

watcher:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        RecordTaint(event, ...)
    elseif event == "PLAYER_LOGIN" then
        -- Optional: automatically enable taint logging in client if user enabled it
        if GetCVar and GetCVar("taintLog") == "0" then
            -- Can be toggled on demand via /fstaint log
        end
    end
end)

-- Diagnostic frame integrity prober
local function ProbeFrameSecurity(frameName)
    if not _G[frameName] then return "not loaded" end
    if issecurevariable then
        local isSec = issecurevariable(frameName)
        return isSec and "|cff00ff00Secure|r" or "|cffff4444TAINTED|r"
    end
    return "unknown"
end

-- Slash Command: /fstaint
SLASH_FSTAINT1 = "/fstaint"
SLASH_FSTAINT2 = "/fsdiag"
SlashCmdList["FSTAINT"] = function(msg)
    msg = string.lower(strtrim(msg or ""))

    if msg == "log" or msg == "enable" then
        if SetCVar then
            SetCVar("taintLog", "1")
            print("|cff00ff00[Forever Safari]|r Client CVar 'taintLog' set to 1. WoW will log full execution trees into Logs/taint.log on next reload.")
        end
        return
    elseif msg == "log2" or msg == "verbose" then
        if SetCVar then
            SetCVar("taintLog", "2")
            print("|cff00ff00[Forever Safari]|r Client CVar 'taintLog' set to 2 (Verbose). WoW will log full execution trees into Logs/taint.log.")
        end
        return
    elseif msg == "off" then
        if SetCVar then
            SetCVar("taintLog", "0")
            print("|cff00ff00[Forever Safari]|r Client CVar 'taintLog' disabled.")
        end
        return
    end

    print("|cffffd100=== Forever Safari Taint & Security Inspector ===|r")

    -- 1. Last recorded action block
    if ForeverSafari_LastTaint then
        local t = ForeverSafari_LastTaint
        print(string.format("|cffff4444Last Action Blocked:|r |cff00ffff%s|r", t.action or "Unknown"))
        print(string.format("  • Blamed Addon: |cffffaa00%s|r (%s)", t.addon or "Unknown", t.event or ""))
        print(string.format("  • Recorded At: %s", t.time or ""))
        print("|cffffaa00  • Call Stack:|r\n" .. (t.stack or "None"))
    else
        print("|cff00ff00✓ No blocked actions recorded yet in this game session.|r")
    end

    -- 2. Proactive security probe of key UI frames
    print("|cffffd100Frame Security Status:|r")
    local framesToProbe = { "GossipFrame", "MailFrame", "BankFrame", "Minimap", "ActionButton1", "CompactRaidFrameContainer" }
    for _, fName in ipairs(framesToProbe) do
        print(string.format("  • %s: %s", fName, ProbeFrameSecurity(fName)))
    end
    print("|cff888888Commands: |cffffffff/fstaint log|r (enable Logs/taint.log) | |cffffffff/fstaint off|r|r")
end

-- =========================================================================
-- 🪲 SESSION LUA ERROR & BUG TRACKER (/fserrors /fsbugs)
-- =========================================================================
ForeverSafari_SessionErrors = ForeverSafari_SessionErrors or {}
local MAX_ERRORS = 30

local function RecordLuaError(msg)
    local safeMsg = "Unknown error"
    if msg ~= nil then
        local ok, str = pcall(function() return tostring(msg) end)
        if ok and str then
            safeMsg = str
        else
            safeMsg = "[Secret Value / Tainted Error Message]"
        end
    end

    local stack = ""
    if debugstack then
        local ok, s = pcall(function() return debugstack(3, 14, 14) end)
        if ok and s then stack = s end
    end
    local timeStr = date and date("%H:%M:%S") or "Just now"

    local fullText = safeMsg .. "\n" .. stack
    local culprit = "Unknown"

    -- 1. Check for explicit Blizzard execution taint annotation first
    local taintedBy = string.match(safeMsg, "execution tainted by '([^']+)'")
    if taintedBy then
        culprit = taintedBy
    else
        -- 2. Line-by-line inspection, ignoring our own TaintWatcher error interceptor
        for line in string.gmatch(fullText, "([^\r\n]+)") do
            if not string.find(line, "ForeverSafari[/\\]Core[/\\]TaintWatcher") then
                local addon = string.match(line, "Interface[/\\]AddOns[/\\]([^/\\:%.]+)")
                if addon then
                    culprit = addon
                    break
                elseif string.find(line, "Interface[/\\]FrameXML") or string.find(line, "Interface[/\\]SharedXML") then
                    culprit = "Blizzard UI"
                    break
                end
            end
        end
    end

    local rec = {
        id = #ForeverSafari_SessionErrors + 1,
        time = timeStr,
        msg = safeMsg,
        stack = stack,
        culprit = culprit,
        isOurs = (culprit == "ForeverSafari"),
    }

    table.insert(ForeverSafari_SessionErrors, rec)
    if #ForeverSafari_SessionErrors > MAX_ERRORS then
        table.remove(ForeverSafari_SessionErrors, 1)
    end
end

-- Hook global error handler without interfering with Blizzard or existing error catchers
local origErrorHandler = geterrorhandler and geterrorhandler()
if seterrorhandler then
    seterrorhandler(function(msg)
        pcall(RecordLuaError, msg)

        -- 🛡️ Tank & Combat Protection: Suppress modal popups during combat lockdown!
        -- Prevents screen-blocking windows from stealing mouse clicks during boss/trash pulls.
        if InCombatLockdown and InCombatLockdown() then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.01, function()
                    if ScriptErrorsFrame and ScriptErrorsFrame.Hide and ScriptErrorsFrame:IsShown() then
                        ScriptErrorsFrame:Hide()
                    end
                end)
            end
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[Error Suppressed in Combat]|r Type |cffffd100/fserrors|r after combat to inspect.")
            end
            return
        end

        if origErrorHandler and origErrorHandler ~= RecordLuaError then
            return origErrorHandler(msg)
        end
    end)
end

-- =========================================================================
-- 📋 COPY-PASTE ERROR INSPECTOR POPUP MODAL (ForeverSafariErrorViewerFrame)
-- =========================================================================
local errorFrame = nil

local function CreateErrorViewerFrame()
    if errorFrame then return errorFrame end

    local f = CreateFrame("Frame", "ForeverSafariErrorViewerFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(580, 420)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.12, 0.95)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("|cffffd100Forever Safari: Bug & Error Inspector|r")
    f.title = title

    -- Subtitle / Status
    local info = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info:SetPoint("TOP", title, "BOTTOM", 0, -4)
    info:SetText("No errors recorded.")
    f.info = info

    -- Close Button (Top right X)
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)

    -- Multi-line Scrollable EditBox
    local scrollFrame = CreateFrame("ScrollFrame", "ForeverSafariErrorScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -62)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -38, 52)

    local editBox = CreateFrame("EditBox", "ForeverSafariErrorEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(999999)
    editBox:EnableMouse(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetWidth(510)
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    scrollFrame:SetScrollChild(editBox)
    f.editBox = editBox

    -- Navigation: Prev Button
    local prevBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    prevBtn:SetSize(80, 24)
    prevBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 14)
    prevBtn:SetText("< Previous")
    f.prevBtn = prevBtn

    -- Navigation: Next Button
    local nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextBtn:SetSize(80, 24)
    nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
    nextBtn:SetText("Next >")
    f.nextBtn = nextBtn

    -- Select All Button
    local copyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copyBtn:SetSize(90, 24)
    copyBtn:SetPoint("LEFT", nextBtn, "RIGHT", 8, 0)
    copyBtn:SetText("Select All")
    copyBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    -- Clear All Button
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 24)
    clearBtn:SetPoint("LEFT", copyBtn, "RIGHT", 6, 0)
    clearBtn:SetText("Clear All")
    clearBtn:SetScript("OnClick", function()
        ForeverSafari_SessionErrors = {}
        f:DisplayError(1)
        print("|cff00ff00[Forever Safari Bug Tracker]|r All session errors cleared.")
    end)

    -- Close Button (Bottom right)
    local dismissBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    dismissBtn:SetSize(80, 24)
    dismissBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 14)
    dismissBtn:SetText("Close")
    dismissBtn:SetScript("OnClick", function() f:Hide() end)

    f.currentIndex = 1

    function f:DisplayError(index)
        local count = #ForeverSafari_SessionErrors
        if count == 0 then
            self.info:SetText("|cff00ff00Zero errors recorded this session.|r")
            self.editBox:SetText("No Lua errors have occurred in this game session. All addons running cleanly!\n\n(Tip: When an error happens, open this window and press Ctrl+C to copy-paste the full report.)")
            self.prevBtn:Disable()
            self.nextBtn:Disable()
            return
        end

        index = math.max(1, math.min(count, index or count))
        self.currentIndex = index
        local rec = ForeverSafari_SessionErrors[index]

        local culpritColor = rec.isOurs and "|cffff4444" or (rec.culprit == "Blizzard UI" and "|cff3399ff" or "|cffffaa00")
        self.info:SetText(string.format("Error %d of %d  •  Culprit: %s%s|r  •  Time: %s", index, count, culpritColor, rec.culprit, rec.time))

        local text = string.format("Time: %s\nCulprit Addon: %s\nError Message:\n%s\n\nCall Stack:\n%s", 
            rec.time, rec.culprit, rec.msg, rec.stack)
        self.editBox:SetText(text)
        self.editBox:SetCursorPosition(0)
        self.editBox:SetFocus()
        self.editBox:HighlightText() -- Auto-highlight so user just presses Ctrl+C!

        if index > 1 then self.prevBtn:Enable() else self.prevBtn:Disable() end
        if index < count then self.nextBtn:Enable() else self.nextBtn:Disable() end
    end

    prevBtn:SetScript("OnClick", function()
        f:DisplayError(f.currentIndex - 1)
    end)
    nextBtn:SetScript("OnClick", function()
        f:DisplayError(f.currentIndex + 1)
    end)

    if UISpecialFrames then
        table.insert(UISpecialFrames, "ForeverSafariErrorViewerFrame")
    end

    errorFrame = f
    return f
end

-- Slash Command: /fserrors /fsbugs
SLASH_FSERRORS1 = "/fserrors"
SLASH_FSERRORS2 = "/fsbugs"
SlashCmdList["FSERRORS"] = function(msg)
    msg = string.lower(strtrim(msg or ""))

    if msg == "clear" or msg == "reset" then
        ForeverSafari_SessionErrors = {}
        if errorFrame and errorFrame:IsShown() then
            errorFrame:DisplayError(1)
        end
        print("|cff00ff00[Forever Safari Bug Tracker]|r Session error log cleared.")
        return
    end

    -- Open the copy-paste modal window!
    local frame = CreateErrorViewerFrame()
    frame:Show()

    local targetIdx = tonumber(msg)
    if targetIdx then
        frame:DisplayError(targetIdx)
    else
        frame:DisplayError(#ForeverSafari_SessionErrors)
    end
end


