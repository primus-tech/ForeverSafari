--[[
    Forever Safari: Communications & Multiplayer Protocol
    Enables player-to-player duel challenges, team inspection, and companion trading/chat links.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Comms = ns.Comms or {}

local Comms = ns.Comms
local C = ns.Constants
local DB = ns.Database

local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return true end
    if issecretpassphrase and issecretpassphrase(v) then return true end
    if issecretvariable and issecretvariable(v) then return true end
    local ok = pcall(function() local _ = (v == "") end)
    if not ok then return true end
    return false
end

local COMM_PREFIX = "ForeverSafariComm"

function Comms:Initialize()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
    end

    local f = CreateFrame("Frame", "ForeverSafariCommFrame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
        if prefix == COMM_PREFIX then
            Comms:OnMessageReceived(text, channel, sender)
        end
    end)
end

function Comms:SendMessage(msgType, data, targetPlayer)
    local payload = string.format("%s:%s", msgType, data or "")
    if targetPlayer and targetPlayer ~= "" then
        if C_ChatInfo and C_ChatInfo.SendAddonMessage then
            C_ChatInfo.SendAddonMessage(COMM_PREFIX, payload, "WHISPER", targetPlayer)
        end
    else
        if C_ChatInfo and C_ChatInfo.SendAddonMessage then
            C_ChatInfo.SendAddonMessage(COMM_PREFIX, payload, "PARTY")
        end
    end
end

function Comms:SendCommMessage(text, channel, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        if channel == "WHISPER" and target then
            C_ChatInfo.SendAddonMessage(COMM_PREFIX, text, "WHISPER", target)
        else
            C_ChatInfo.SendAddonMessage(COMM_PREFIX, text, channel or "PARTY")
        end
    end
end

function Comms:OnMessageReceived(text, channel, sender)
    -- Format: TYPE:DATA
    local msgType, data = strsplit(":", text, 2)
    if not msgType then return end

    if msgType == "DUEL_REQUEST" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffffd100%s|r has challenged you to a Forever Safari duel!", C.PREFIX, sender))
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Duel Challenge", string.format("%s wants to battle companions!", sender))
        end
    elseif msgType == "PERMIT_UNLOCK" then
        -- Format: PERMIT_UNLOCK:Type:BossName
        local cType, bName = strsplit(":", data or "", 2)
        cType = cType or "Mechanical"
        bName = bName or "Boss"

        if cType == "Mechanical" then
            DB:UpdateQuestProgress("KILL_MECHANICAL_BOSS", 1)
        elseif cType == "Elemental" then
            DB:UpdateQuestProgress("KILL_ELEMENTAL_BOSS", 1)
        elseif cType == "Undead" then
            DB:UpdateQuestProgress("KILL_UNDEAD_BOSS", 1)
        elseif cType == "Dragonkin" then
            DB:UpdateQuestProgress("KILL_DRAGONKIN_BOSS", 1)
        end

        DB:UpdateQuestProgress("BOSS_KILL", 1)
        DB:AddTokens(25, bName .. " Defeated")

        local inCombat = InCombatLockdown and InCombatLockdown()
        if not DB:IsTypeUnlocked(cType) then
            DB:UnlockType(cType, inCombat)
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[%s Defeated]|r Party sync: +25 Safari Tokens! You unlocked |cffffd100%s|r research!", C.PREFIX, bName, cType))
    elseif msgType == "SHARE_MOB" then
        -- Received shared companion link from player
    end
end

function Comms:ChallengeTarget()
    if not UnitExists("target") or not UnitIsPlayer("target") then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Target a player to challenge them to a companion duel!|r")
        return
    end
    local targetName = UnitName("target")
    if isSecret(targetName) or not targetName or targetName == "" then targetName = "Target Player" end
    Comms:SendMessage("DUEL_REQUEST", "", targetName)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%sChallenged |cffffd100%s|r to a companion duel!", C.PREFIX, targetName))
end
