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

-- Slash Command: /fserrors /fsbugs
SLASH_FSERRORS1 = "/fserrors"
SLASH_FSERRORS2 = "/fsbugs"
SlashCmdList["FSERRORS"] = function(msg)
    msg = string.lower(strtrim(msg or ""))

    if msg == "clear" or msg == "reset" then
        ForeverSafari_SessionErrors = {}
        print("|cff00ff00[Forever Safari Bug Tracker]|r Session error log cleared.")
        return
    end

    local targetIdx = tonumber(msg)
    if targetIdx then
        local found = nil
        for _, rec in ipairs(ForeverSafari_SessionErrors) do
            if rec.id == targetIdx then
                found = rec
                break
            end
        end
        if not found and ForeverSafari_SessionErrors[targetIdx] then
            found = ForeverSafari_SessionErrors[targetIdx]
        end

        if found then
            local headerColor = found.isOurs and "|cffff4444" or (found.culprit == "Blizzard UI" and "|cff3399ff" or "|cffffaa00")
            print(string.format("%s=== Error #%d [%s] at %s ===|r", headerColor, found.id, found.culprit, found.time))
            print("|cffffffffMessage:|r " .. found.msg)
            print("|cffffaa00Call Stack:|r\n" .. found.stack)
        else
            print(string.format("|cffff4444[Bug Tracker]|r No error found with ID #%d. Type |cffffd100/fserrors|r to list all.", targetIdx))
        end
        return
    end

    local count = #ForeverSafari_SessionErrors
    print(string.format("|cffffd100=== Forever Safari Bug Tracker (%d error(s) this session) ===|r", count))
    if count == 0 then
        print("|cff00ff00✓ Zero Lua errors recorded this session! All addons running cleanly.|r")
        return
    end

    for _, rec in ipairs(ForeverSafari_SessionErrors) do
        local tag
        if rec.isOurs then
            tag = "|cffff4444[ForeverSafari]|r"
        elseif rec.culprit == "Blizzard UI" then
            tag = "|cff3399ff[Blizzard UI]|r"
        else
            tag = string.format("|cffffaa00[%s]|r", rec.culprit)
        end

        local lineMsg = rec.msg:match("([^\r\n]+)") or rec.msg
        if #lineMsg > 75 then lineMsg = lineMsg:sub(1, 72) .. "..." end
        print(string.format("  #%d |cff888888[%s]|r %s %s", rec.id, rec.time, tag, lineMsg))
    end
    print("|cff00ffccType |cffffd100/fserrors <#ID>|r |cff00ffccto view the full call stack, or |cffffd100/fserrors clear|r|r")
end

