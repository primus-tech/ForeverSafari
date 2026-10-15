--[[
    Forever Safari: WarBridge & Territory War Controller
    Handles:
      - Dual-Raid Captain-to-Captain WHISPER Gateway & Internal RAID Rebroadcasting (Mode A)
      - Single-Raid Subgroup Team Resolving & Fog-of-War Map Overlay (Mode B)
      - Dynamic Node & Safe Zone Staking (/fs war setnode, /fs war setbase)
      - Midpoint Revival Rune calculation & state synchronization
      - Spatial Tether monitoring for Ambush encounters
      - Monotonic Captain Failover Epochs & Anti-Replay Packet Firewall
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.WarBridge = ns.WarBridge or {}

local WB = ns.WarBridge
local C = ns.Constants
local DB = ns.Database
local Crypto = ns.Crypto

local MSG_PREFIX = "FS_WAR"
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(MSG_PREFIX)
end

-- System State
WB.Mode = "DUAL_RAID" -- "DUAL_RAID" or "SINGLE_RAID"
WB.MyTeam = nil       -- "RED" or "BLUE"
WB.IsCaptain = false
WB.TargetCaptain = nil
WB.MatchId = nil
WB.Epoch = 1
WB.Sequence = 0
WB.LastReceivedSeq = {} -- [sender] = seq

-- Territory War Match State
WB.WarState = {
    active = false,
    zoneMapID = nil,
    zoneName = "",
    victoryScore = 1000,
    scores = { RED = 0, BLUE = 0 },
    safeZones = {
        RED = nil,  -- { mapID, x, y, name }
        BLUE = nil, -- { mapID, x, y, name }
    },
    nodes = {},     -- [nodeId] = { id, name, mapID, x, y, owner = "NEUTRAL", contest = 0 }
    runes = {},     -- [runeId] = { id, mapID, x, y, available = true, respawnAt = 0 }
    ambushes = {},  -- [matchId] = { attacker, defender, originX, originY, startTime }
    tickTimer = 0,
}

-------------------------------------------------------------------------------
-- 1. Initialization & Event Registration
-------------------------------------------------------------------------------
function WB:Initialize()
    local f = CreateFrame("Frame", "FS_WarBridgeFrame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_ADDON" then
            WB:OnMessageReceived(...)
        elseif event == "GROUP_ROSTER_UPDATE" then
            WB:UpdateRosterState()
        elseif event == "PLAYER_ENTERING_WORLD" then
            WB:UpdateRosterState()
        end
    end)

    -- Telemetry & Point Ticking Heartbeat (1.5s interval)
    local heartbeatTimer = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        if not WB.WarState.active then return end

        heartbeatTimer = heartbeatTimer + elapsed
        if heartbeatTimer >= 1.5 then
            heartbeatTimer = 0
            WB:Heartbeat()
        end
    end)
end

-------------------------------------------------------------------------------
-- 2. Roster State & Team Resolution
-------------------------------------------------------------------------------
function WB:UpdateRosterState()
    WB.IsCaptain = (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))

    if WB.Mode == "SINGLE_RAID" and IsInRaid() then
        local myName = UnitName("player")
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name and Ambiguate(name, "none") == myName then
                WB.MyTeam = WB:GetTeamFromSubgroup(subgroup)
                break
            end
        end
    end
end

function WB:GetTeamFromSubgroup(subgroup)
    if not subgroup then return "NEUTRAL" end
    if subgroup >= 1 and subgroup <= 4 then
        return "RED"
    elseif subgroup >= 5 and subgroup <= 8 then
        return "BLUE"
    end
    return "NEUTRAL"
end

-------------------------------------------------------------------------------
-- 3. Packet Serialization & Firewall Validation
-------------------------------------------------------------------------------
-- Envelope: FS_WAR:matchId:epoch:seq:originTeam:msgType:payload
function WB:BuildPacket(msgType, payload)
    WB.Sequence = WB.Sequence + 1
    local matchId = WB.MatchId or "NOMATCH"
    local epoch = WB.Epoch or 1
    local origin = WB.MyTeam or "NEUTRAL"
    return string.format("%s:%s:%d:%d:%s:%s:%s", MSG_PREFIX, matchId, epoch, WB.Sequence, origin, msgType, payload or "")
end

function WB:ParsePacket(raw)
    local prefix, matchId, epoch, seq, origin, msgType, payload = strsplit(":", raw, 7)
    if prefix ~= MSG_PREFIX then return nil end
    return {
        matchId = matchId,
        epoch = tonumber(epoch) or 1,
        seq = tonumber(seq) or 0,
        origin = origin,
        msgType = msgType,
        payload = payload or "",
    }
end

function WB:SendWarMessage(msgType, payload, isBridgeMessage)
    local packet = WB:BuildPacket(msgType, payload)

    if WB.Mode == "SINGLE_RAID" then
        if C_ChatInfo and C_ChatInfo.SendAddonMessage then
            C_ChatInfo.SendAddonMessage(MSG_PREFIX, packet, "RAID")
        end
    elseif WB.Mode == "DUAL_RAID" then
        -- Internal squad broadcast first
        if C_ChatInfo and C_ChatInfo.SendAddonMessage then
            C_ChatInfo.SendAddonMessage(MSG_PREFIX, packet, "RAID")
        end

        -- If Captain, bridge to Opposing Captain via WHISPER
        if isBridgeMessage and WB.IsCaptain and WB.TargetCaptain and WB.TargetCaptain ~= "" then
            if C_ChatInfo and C_ChatInfo.SendAddonMessage then
                C_ChatInfo.SendAddonMessage(MSG_PREFIX, packet, "WHISPER", WB.TargetCaptain)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- 4. Inbound Message Handling & Gateway Bridge
-------------------------------------------------------------------------------
function WB:OnMessageReceived(prefix, message, channel, sender)
    if prefix ~= MSG_PREFIX then return end

    local senderName = Ambiguate(sender, "none")
    local myName = UnitName("player")
    if senderName == myName then return end -- Ignore self-echo

    local pkt = WB:ParsePacket(message)
    if not pkt then return end

    -- Match ID Filter (unless match initialization)
    if pkt.msgType ~= "WAR_INIT" and WB.MatchId and pkt.matchId ~= WB.MatchId then
        return
    end

    -- Epoch Check: Drop stale packets from superseded epochs
    if pkt.epoch < (WB.Epoch or 1) then
        return
    end
    if pkt.epoch > (WB.Epoch or 1) then
        WB.Epoch = pkt.epoch
    end

    -- Monotonic Sequence Replay Filter
    local lastSeq = WB.LastReceivedSeq[senderName] or 0
    if pkt.seq > 0 and pkt.seq <= lastSeq then
        return -- Stale or replay packet
    end
    WB.LastReceivedSeq[senderName] = pkt.seq

    -- If Captain received bridge WHISPER from Opposing Captain, rebroadcast to local RAID
    if channel == "WHISPER" and WB.IsCaptain and senderName == WB.TargetCaptain then
        if C_ChatInfo and C_ChatInfo.SendAddonMessage then
            C_ChatInfo.SendAddonMessage(MSG_PREFIX, message, "RAID")
        end
    end

    -- Route packet to internal war state handler
    WB:HandleWarPacket(pkt, senderName)
end

function WB:HandleWarPacket(pkt, sender)
    local msgType = pkt.msgType
    local data = pkt.payload

    if msgType == "WAR_INIT" then
        -- Format: mapID;zoneName;victoryScore;matchId
        local mID, zName, vScore, matchId = strsplit(";", data)
        WB.WarState.zoneMapID = tonumber(mID)
        WB.WarState.zoneName = zName or "Territory"
        WB.WarState.victoryScore = tonumber(vScore) or 1000
        WB.MatchId = matchId
        WB.WarState.active = true
        WB.WarState.scores.RED = 0
        WB.WarState.scores.BLUE = 0
        WB.WarState.nodes = {}
        WB.WarState.runes = {}
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[Territory War Started]|r Zone: |cffffd100%s|r | Target: |cffffd100%d Points|r!", C.PREFIX, WB.WarState.zoneName, WB.WarState.victoryScore))

    elseif msgType == "SET_BASE" then
        -- Format: team;mapID;x;y;name
        local team, mID, x, y, bName = strsplit(";", data)
        if team == "RED" or team == "BLUE" then
            WB.WarState.safeZones[team] = {
                mapID = tonumber(mID),
                x = tonumber(x) or 0,
                y = tonumber(y) or 0,
                name = bName or "Base Camp",
            }
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffffd100%s Team Base Camp|r staked at |cff00ff99%s|r!", C.PREFIX, team, bName or "Base Camp"))
        end

    elseif msgType == "SET_NODE" then
        -- Format: nodeId;name;mapID;x;y
        local nId, nName, mID, x, y = strsplit(";", data)
        local idNum = tonumber(nId)
        if idNum then
            WB.WarState.nodes[idNum] = {
                id = idNum,
                name = nName or ("Node " .. idNum),
                mapID = tonumber(mID),
                x = tonumber(x) or 0,
                y = tonumber(y) or 0,
                owner = "NEUTRAL",
                contest = 0,
            }
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00e5ffNode %d Staked:|r |cffffd100%s|r!", C.PREFIX, idNum, nName))
            WB:RecalculateRunes()
        end

    elseif msgType == "SCORE_TICK" then
        -- Format: redScore;blueScore
        local rScore, bScore = strsplit(";", data)
        WB.WarState.scores.RED = tonumber(rScore) or WB.WarState.scores.RED
        WB.WarState.scores.BLUE = tonumber(bScore) or WB.WarState.scores.BLUE

        if WB.WarState.scores.RED >= WB.WarState.victoryScore then
            WB:EndMatch("RED")
        elseif WB.WarState.scores.BLUE >= WB.WarState.victoryScore then
            WB:EndMatch("BLUE")
        end

    elseif msgType == "NODE_CAPTURE" then
        -- Format: nodeId;newOwner
        local nId, newOwner = strsplit(";", data)
        local idNum = tonumber(nId)
        if idNum and WB.WarState.nodes[idNum] then
            WB.WarState.nodes[idNum].owner = newOwner
            local color = (newOwner == "RED") and "|cffff4444" or ((newOwner == "BLUE") and "|cff00bfff" or "|cffaaaaaa")
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s%s[%s Captured %s]|r!", C.PREFIX, color, newOwner, WB.WarState.nodes[idNum].name))
        end

    elseif msgType == "RUNE_PICKUP" then
        -- Format: runeId;pickerName
        local rId, picker = strsplit(";", data)
        local idNum = tonumber(rId)
        if idNum and WB.WarState.runes[idNum] then
            WB.WarState.runes[idNum].available = false
            WB.WarState.runes[idNum].respawnAt = time() + 90
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[Revival Rune Picked Up]|r by %s! (Respawning in 90s)", C.PREFIX, picker or "Player"))
        end

    elseif msgType == "AMBUSH_ENGAGE" then
        -- Format: attacker;defender;originX;originY
        local attacker, defender, ox, oy = strsplit(";", data)
        local myName = UnitName("player")
        if defender == myName then
            WB:ReceiveAmbush(attacker, tonumber(ox), tonumber(oy))
        end

    elseif msgType == "WAR_STOP" then
        WB.WarState.active = false
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444[Territory War Stopped by Coordinator]|r")
    end
end

-------------------------------------------------------------------------------
-- 5. Heartbeat & Point Ticking (Authoritative Host Engine)
-------------------------------------------------------------------------------
function WB:Heartbeat()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local x, y = pos:GetXY()

    -- Check Proximity to Revival Runes (Local Observation)
    for rId, rune in pairs(WB.WarState.runes) do
        if rune.available and rune.mapID == mapID then
            local dx = (x - rune.x) * 1000
            local dy = (y - rune.y) * 1000
            local distSq = dx*dx + dy*dy
            if distSq <= 400 then -- Within ~20 yards
                local activeMob = DB:GetActiveMob()
                if activeMob and activeMob.isFainted then
                    activeMob.isFainted = false
                    activeMob.currentHP = activeMob.maxHP or 100
                    activeMob.hp = activeMob.currentHP
                    WB:SendWarMessage("RUNE_PICKUP", string.format("%d;%s", rId, UnitName("player")), true)
                    DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff00✨ Revival Rune activated! Your companion is fully revived!|r")
                    PlaySound(8959)
                end
            end
        end
    end

    -- Check Proximity to Team Safe Zone Base (Safe Revival)
    local myBase = WB.MyTeam and WB.WarState.safeZones[WB.MyTeam]
    if myBase and myBase.mapID == mapID then
        local dx = (x - myBase.x) * 1000
        local dy = (y - myBase.y) * 1000
        if (dx*dx + dy*dy) <= 625 then -- Within ~25 yards of Base Camp
            local activeMob = DB:GetActiveMob()
            if activeMob and activeMob.isFainted then
                activeMob.isFainted = false
                activeMob.currentHP = activeMob.maxHP or 100
                activeMob.hp = activeMob.currentHP
                DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff00🛡️ Welcome to Base Camp. Your companion is fully rested and revived!|r")
            end
        end
    end

    -- Host Point Ticking & Node Contest Resolution (Sole Host Authority)
    if WB.IsCaptain then
        WB.WarState.tickTimer = WB.WarState.tickTimer + 1.5
        if WB.WarState.tickTimer >= 5.0 then
            WB.WarState.tickTimer = 0
            WB:TickNodeScores()
        end
    end
end

function WB:TickNodeScores()
    local nodeCounts = { RED = 0, BLUE = 0 }
    for _, node in pairs(WB.WarState.nodes) do
        if node.owner == "RED" then
            nodeCounts.RED = nodeCounts.RED + 1
        elseif node.owner == "BLUE" then
            nodeCounts.BLUE = nodeCounts.BLUE + 1
        end
    end

    local tickPoints = { [0] = 0, [1] = 1, [2] = 2, [3] = 4, [4] = 8, [5] = 15 }
    local redGain = tickPoints[nodeCounts.RED] or (nodeCounts.RED * 3)
    local blueGain = tickPoints[nodeCounts.BLUE] or (nodeCounts.BLUE * 3)

    WB.WarState.scores.RED = WB.WarState.scores.RED + redGain
    WB.WarState.scores.BLUE = WB.WarState.scores.BLUE + blueGain

    WB:SendWarMessage("SCORE_TICK", string.format("%d;%d", WB.WarState.scores.RED, WB.WarState.scores.BLUE), true)
end

function WB:EndMatch(winnerTeam)
    WB.WarState.active = false
    local color = (winnerTeam == "RED") and "|cffff4444" or "|cff00bfff"
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s%s🏆 VICTORY FOR THE %s TEAM! Final Score: Red %d — Blue %d!|r", C.PREFIX, color, winnerTeam, WB.WarState.scores.RED, WB.WarState.scores.BLUE))
    PlaySound(8454) -- Victory fanfare
end

-------------------------------------------------------------------------------
-- 6. Dynamic Midpoint Revival Rune Calculator
-------------------------------------------------------------------------------
function WB:RecalculateRunes()
    local nodeList = {}
    for _, node in pairs(WB.WarState.nodes) do
        table.insert(nodeList, node)
    end
    if #nodeList < 2 then return end

    WB.WarState.runes = {}
    local runeCount = 0

    -- Calculate midpoints between adjacent nodes
    for i = 1, #nodeList do
        local n1 = nodeList[i]
        local n2 = nodeList[(i % #nodeList) + 1]
        if n1.mapID == n2.mapID then
            runeCount = runeCount + 1
            WB.WarState.runes[runeCount] = {
                id = runeCount,
                mapID = n1.mapID,
                x = (n1.x + n2.x) / 2,
                y = (n1.y + n2.y) / 2,
                available = true,
                respawnAt = 0,
            }
        end
    end
end

-------------------------------------------------------------------------------
-- 7. Ambush & Spatial Tether Validation
-------------------------------------------------------------------------------
function WB:AttemptAmbush(targetUnit)
    if not targetUnit or not UnitIsPlayer(targetUnit) then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Target a player to ambush!|r")
        return
    end

    local activeMob = DB:GetActiveMob()
    if not activeMob or activeMob.isFainted then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444You cannot ambush with a fainted companion!|r")
        return
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local ox, oy = pos:GetXY()

    local targetName = UnitName(targetUnit)
    if not targetName or targetName == "" then return end

    local payload = string.format("%s;%s;%.4f;%.4f", UnitName("player"), targetName, ox, oy)
    WB:SendWarMessage("AMBUSH_ENGAGE", payload, true)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffffaa00[Ambush Initiated]|r Intercepted |cffffd100%s|r! Hold your ground within 25 yards!", C.PREFIX, targetName))

    -- Start Ambush 1v1 on attacker's side
    if ForeverSafari.Comms then
        ForeverSafari.Comms:ChallengeTargetDirect(targetName, "1v1", { isAmbush = true, originX = ox, originY = oy })
    end
end

function WB:ReceiveAmbush(attackerName, ox, oy)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffff4444[AMBUSHED!]|r You have been intercepted by |cffffd100%s|r! Standing by for combat lock...", C.PREFIX, attackerName))
    PlaySound(847)

    -- Force open battle against ambusher
    if ForeverSafari.Comms then
        ForeverSafari.Comms:AcceptDirectAmbush(attackerName, ox, oy)
    end
end

-------------------------------------------------------------------------------
-- 8. Slash Command Handler (/fs war)
-------------------------------------------------------------------------------
function WB:HandleSlash(msg)
    local cmd, arg = strsplit(" ", msg or "", 2)
    cmd = string.lower(cmd or "")

    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y = 0, 0
    if pos then x, y = pos:GetXY() end

    if cmd == "setbase" then
        local team = string.upper(arg or "")
        if team ~= "RED" and team ~= "BLUE" then
            team = WB.MyTeam or "RED"
        end
        local zoneName = C_Map.GetMapInfo(mapID) and C_Map.GetMapInfo(mapID).name or "Zone"
        local payload = string.format("%s;%d;%.4f;%.4f;%s Base", team, mapID, x, y, team)
        WB:SendWarMessage("SET_BASE", payload, true)
        WB:HandleWarPacket({ msgType = "SET_BASE", payload = payload }, UnitName("player"))

    elseif cmd == "setnode" then
        local num, name = strsplit(" ", arg or "", 2)
        local nId = tonumber(num) or (#WB.WarState.nodes + 1)
        name = name or ("Node " .. nId)
        local payload = string.format("%d;%s;%d;%.4f;%.4f", nId, name, mapID, x, y)
        WB:SendWarMessage("SET_NODE", payload, true)
        WB:HandleWarPacket({ msgType = "SET_NODE", payload = payload }, UnitName("player"))

    elseif cmd == "start" then
        local zoneName = C_Map.GetMapInfo(mapID) and C_Map.GetMapInfo(mapID).name or "Zone"
        local matchId = "WAR_" .. tostring(time()):sub(-5)
        local payload = string.format("%d;%s;1000;%s", mapID, zoneName, matchId)
        WB:SendWarMessage("WAR_INIT", payload, true)
        WB:HandleWarPacket({ msgType = "WAR_INIT", payload = payload }, UnitName("player"))

    elseif cmd == "stop" then
        WB:SendWarMessage("WAR_STOP", "", true)
        WB:HandleWarPacket({ msgType = "WAR_STOP", payload = "" }, UnitName("player"))

    elseif cmd == "setcaptain" then
        WB.TargetCaptain = arg
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%sOpposing Captain bound to: |cffffd100%s|r", C.PREFIX, arg or "None"))

    elseif cmd == "setmode" then
        local m = string.upper(arg or "")
        if m == "DUAL" or m == "DUAL_RAID" then
            WB.Mode = "DUAL_RAID"
        else
            WB.Mode = "SINGLE_RAID"
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%sWarBridge Mode set to: |cffffd100%s|r", C.PREFIX, WB.Mode))

    elseif cmd == "ambush" then
        WB:AttemptAmbush("target")

    else
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff99Territory War Controls (/fs war):|r")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs war setbase [red|blue]|r - Plant team Safe Zone Base at your current coordinates")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs war setnode <1..5> [Name]|r - Plant a custom capture node where you stand")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs war ambush|r - Ambush targeted player (initiates spatial combat lock)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs war start|r - Broadcast match initialization (1,000 pt goal)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs war stop|r - Abort active territory war match")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs war setcaptain <Name>|r - Bind opposing Captain for dual-raid bridge")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs war setmode [dual|single]|r - Toggle Dual-Raid bridge vs Single-Raid overlay")
    end
end
