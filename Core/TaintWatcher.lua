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
