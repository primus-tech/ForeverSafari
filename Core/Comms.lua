--[[
    Forever Safari: Communications & Multiplayer Protocol
    Enables:
      - Zero-Trust Simulation Protocol Handshakes (1v1 & 2v2 Duels)
      - Canonical Companion Definition exchange & Hamilton-Hare 100/110 validation
      - Commit-Reveal Turn Message Transport (SHA-256)
      - Periodic Battle Checkpoint verification (STATE_HASH)
      - Ambush Mandatory Combat Lock & Forfeit notifications
      - Co-op Nursery breeding & shared party unlocks
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Comms = ns.Comms or {}

local Comms = ns.Comms
local C = ns.Constants
local DB = ns.Database
local Crypto = ns.Crypto

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

-- Pending Challenge State
Comms.PendingChallenge = nil

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

    -- Register StaticPopup for Duel Invitations
    StaticPopupDialogs["FOREVER_SAFARI_DUEL_INVITE"] = {
        text = "%s has challenged you to a Forever Safari companion duel (%s)!\nDo you accept?",
        button1 = "Accept",
        button2 = "Decline",
        OnAccept = function(self, data)
            if data and data.challenger then
                Comms:AcceptDuel(data.challenger, data.ruleset, data.seedA, data.team)
            end
        end,
        OnCancel = function(self, data)
            if data and data.challenger then
                Comms:SendMessage("DUEL_REJECT", "DECLINED", data.challenger)
            end
        end,
        timeout = 20,
        whileDead = false,
        hideOnEscape = true,
        preferredIndex = 3,
    }
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

-------------------------------------------------------------------------------
-- 🐾 Canonical Team Serialization (Minimal 7-Tuples — Zero Derived Stats)
-------------------------------------------------------------------------------
function Comms:GetCanonicalTeamPayload()
    local team = DB:GetTeam()
    local minimalTeam = {}
    for i, pet in ipairs(team) do
        if pet and pet.speciesId then
            table.insert(minimalTeam, {
                speciesId = pet.speciesId or pet.displayId,
                attunementRank = pet.attunementRank or 1,
                attunementPoints = pet.attunementPoints or 0,
                name = pet.name or "Companion",
                customNickname = pet.customNickname or "",
                anatomy = pet.anatomy or "Sire",
                moves = pet.moves or { 101, 107 },
                isRare = pet.isRare or false,
                ivSeed = pet.ivSeed or 1,
                family = pet.family or "Canine",
                element = pet.element or "Beast",
                creatureType = pet.creatureType or "Beast",
                baseStats = pet.baseStats or { hp = 40, atk = 22, def = 18, spd = 20 },
            })
        end
    end
    return DB.JSONEncode and DB.JSONEncode(minimalTeam) or "{}"
end

-------------------------------------------------------------------------------
-- 🛡️ Hamilton-Hare 100/110-Point Budget Law Validation
-------------------------------------------------------------------------------
function Comms:ValidateTeam(team)
    if not team or type(team) ~= "table" or #team == 0 then
        return false, "Empty team payload"
    end

    for i, pet in ipairs(team) do
        if not pet.speciesId then
            return false, "Missing speciesId"
        end

        local rank = pet.attunementRank or 1
        if rank < 1 or rank > 5 then
            return false, "Invalid attunement rank"
        end

        -- Budget Law Check
        local maxBudget = pet.isRare and 110 or 100
        local bs = pet.baseStats or { hp = 40, atk = 22, def = 18, spd = 20 }
        local totalBudget = (bs.hp or 40) + (bs.atk or 22) + (bs.def or 18) + (bs.spd or 20)
        if totalBudget > maxBudget then
            return false, string.format("Budget violation: %d > %d", totalBudget, maxBudget)
        end

        -- Move legality check
        if pet.moves and type(pet.moves) == "table" then
            if #pet.moves > 4 then
                return false, "Too many moves equipped (>4)"
            end
        end
    end

    return true, "VALID"
end

-------------------------------------------------------------------------------
-- ⚔️ 1v1 & 2v2 Duel Handshake Flow
-------------------------------------------------------------------------------
function Comms:ChallengeTarget(arg)
    if not UnitExists("target") or not UnitIsPlayer("target") then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Target a player to challenge them to a companion duel!|r")
        return
    end

    local activeMob = DB:GetActiveMob()
    if not activeMob or activeMob.isFainted then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444You cannot duel with a fainted active companion! Revive first.|r")
        return
    end

    local targetName = UnitName("target")
    if isSecret(targetName) or not targetName or targetName == "" then return end

    local ruleset = "1v1"
    if arg and string.find(string.lower(arg), "2v2") then
        ruleset = "2v2"
    end

    local seedA = math.random(10000000, 99999999)
    Comms.PendingChallenge = {
        target = targetName,
        ruleset = ruleset,
        seedA = seedA,
        timestamp = time(),
    }

    local teamJson = Comms:GetCanonicalTeamPayload()
    local payload = string.format("%s;%d;%s", ruleset, seedA, teamJson)

    Comms:SendMessage("DUEL_PROPOSE", payload, targetName)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%sChallenged |cffffd100%s|r to a |cff00ff99%s|r companion duel! Waiting for response...", C.PREFIX, targetName, ruleset))
end

function Comms:ChallengeTargetDirect(targetName, ruleset, opts)
    local seedA = math.random(10000000, 99999999)
    Comms.PendingChallenge = {
        target = targetName,
        ruleset = ruleset or "1v1",
        seedA = seedA,
        isAmbush = opts and opts.isAmbush,
        originX = opts and opts.originX,
        originY = opts and opts.originY,
        timestamp = time(),
    }

    local teamJson = Comms:GetCanonicalTeamPayload()
    local payload = string.format("%s;%d;%s", ruleset or "1v1", seedA, teamJson)
    Comms:SendMessage("DUEL_PROPOSE", payload, targetName)
end

function Comms:ReceiveDuelPropose(sender, payload)
    local ruleset, seedAStr, teamJson = strsplit(";", payload, 3)
    local seedA = tonumber(seedAStr) or 12345678
    ruleset = ruleset or "1v1"

    local opponentTeam = DB.JSONDecode and DB.JSONDecode(teamJson) or {}
    local valid, err = Comms:ValidateTeam(opponentTeam)
    if not valid then
        Comms:SendMessage("DUEL_REJECT", "ILLEGAL_PAYLOAD", sender)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffff4444Security Violation:|r Rejected duel from %s (%s).", C.PREFIX, sender, err))
        return
    end

    -- If currently in battle, reject
    if ns.BattleEngine and ns.BattleEngine.State and ns.BattleEngine.State.inBattle then
        Comms:SendMessage("DUEL_REJECT", "BUSY", sender)
        return
    end

    -- Prompt Accept / Decline
    StaticPopup_Show("FOREVER_SAFARI_DUEL_INVITE", sender, ruleset, {
        challenger = sender,
        ruleset = ruleset,
        seedA = seedA,
        team = opponentTeam,
    })
    PlaySound(847)
end

function Comms:AcceptDuel(challenger, ruleset, seedA, opponentTeam)
    local activeMob = DB:GetActiveMob()
    if not activeMob or activeMob.isFainted then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Cannot accept: your active companion is fainted!|r")
        Comms:SendMessage("DUEL_REJECT", "FAINTED", challenger)
        return
    end

    local seedB = math.random(10000000, 99999999)
    local teamJson = Comms:GetCanonicalTeamPayload()
    local payload = string.format("%d;%s", seedB, teamJson)

    Comms:SendMessage("DUEL_ACCEPT", payload, challenger)

    -- Derive shared MatchSeed
    local combinedSeeds = tostring(seedA) .. tostring(seedB)
    local matchSeed = Crypto:SHA256(combinedSeeds)

    -- Hydrate Opponent Team locally
    local hydratedTeam = {}
    for i, pet in ipairs(opponentTeam) do
        hydratedTeam[i] = DB:HydrateCompanion(pet)
    end

    -- Launch PvP Duel (Defender Side)
    if ns.BattleEngine and ns.BattleEngine.StartPvPDuel then
        ns.BattleEngine:StartPvPDuel(challenger, hydratedTeam, ruleset, matchSeed, false)
    end
end

function Comms:ReceiveDuelAccept(sender, payload)
    if not Comms.PendingChallenge or Comms.PendingChallenge.target ~= sender then
        return
    end

    local seedBStr, teamJson = strsplit(";", payload, 2)
    local seedB = tonumber(seedBStr) or 87654321
    local opponentTeam = DB.JSONDecode and DB.JSONDecode(teamJson) or {}

    local valid, err = Comms:ValidateTeam(opponentTeam)
    if not valid then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffff4444Security Violation:|r Opponent team failed validation (%s).", C.PREFIX, err))
        return
    end

    -- Derive shared MatchSeed
    local combinedSeeds = tostring(Comms.PendingChallenge.seedA) .. tostring(seedB)
    local matchSeed = Crypto:SHA256(combinedSeeds)
    local ruleset = Comms.PendingChallenge.ruleset

    -- Hydrate Opponent Team locally
    local hydratedTeam = {}
    for i, pet in ipairs(opponentTeam) do
        hydratedTeam[i] = DB:HydrateCompanion(pet)
    end

    local isAmbush = Comms.PendingChallenge.isAmbush
    local ox = Comms.PendingChallenge.originX
    local oy = Comms.PendingChallenge.originY
    Comms.PendingChallenge = nil

    -- Launch PvP Duel (Attacker Side)
    if ns.BattleEngine and ns.BattleEngine.StartPvPDuel then
        ns.BattleEngine:StartPvPDuel(sender, hydratedTeam, ruleset, matchSeed, true, { isAmbush = isAmbush, originX = ox, originY = oy })
    end
end

function Comms:AcceptDirectAmbush(attackerName, ox, oy)
    local activeMob = DB:GetActiveMob()
    if not activeMob or activeMob.isFainted then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Ambushed with a fainted companion! Auto-loss incurred.|r")
        Comms:SendMessage("DUEL_FORFEIT", "FAINTED_AMBUSH", attackerName)
        return
    end

    local seedB = math.random(10000000, 99999999)
    local teamJson = Comms:GetCanonicalTeamPayload()
    local payload = string.format("%d;%s", seedB, teamJson)

    Comms:SendMessage("DUEL_ACCEPT", payload, attackerName)
end

-------------------------------------------------------------------------------
-- 🔒 Commit-Reveal Turn Message Transport
-------------------------------------------------------------------------------
function Comms:SendTurnCommit(targetName, commitTag)
    Comms:SendMessage("TURN_COMMIT", commitTag, targetName)
end

function Comms:SendTurnReveal(targetName, actionStr, salt)
    local payload = string.format("%s;%s", actionStr, salt)
    Comms:SendMessage("TURN_REVEAL", payload, targetName)
end

function Comms:SendStateCheckpoint(targetName, turnIndex, stateHash)
    local payload = string.format("%d;%s", turnIndex, stateHash)
    Comms:SendMessage("CHECKPOINT", payload, targetName)
end

function Comms:SendForfeit(targetName, reason)
    Comms:SendMessage("DUEL_FORFEIT", reason or "FORFEIT", targetName)
end

function Comms:SendDuelSuspend(targetName, reason)
    Comms:SendMessage("DUEL_SUSPEND", reason or "COMBAT", targetName)
end

function Comms:SendDuelResume(targetName)
    Comms:SendMessage("DUEL_RESUME", "RESUME", targetName)
end

-------------------------------------------------------------------------------
-- 📥 Inbound Message Router
-------------------------------------------------------------------------------
function Comms:OnMessageReceived(text, channel, sender)
    local msgType, data = strsplit(":", text, 2)
    if not msgType then return end

    local senderName = Ambiguate(sender, "none")

    if msgType == "DUEL_PROPOSE" then
        Comms:ReceiveDuelPropose(senderName, data)
    elseif msgType == "DUEL_ACCEPT" then
        Comms:ReceiveDuelAccept(senderName, data)
    elseif msgType == "DUEL_REJECT" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffff4444%s declined or cannot accept the duel (%s).|r", C.PREFIX, senderName, data or "Declined"))
        Comms.PendingChallenge = nil
    elseif msgType == "TURN_COMMIT" then
        if ns.BattleEngine and ns.BattleEngine.OnPeerTurnCommit then
            ns.BattleEngine:OnPeerTurnCommit(senderName, data)
        end
    elseif msgType == "TURN_REVEAL" then
        if ns.BattleEngine and ns.BattleEngine.OnPeerTurnReveal then
            ns.BattleEngine:OnPeerTurnReveal(senderName, data)
        end
    elseif msgType == "CHECKPOINT" then
        if ns.BattleEngine and ns.BattleEngine.OnPeerCheckpoint then
            ns.BattleEngine:OnPeerCheckpoint(senderName, data)
        end
    elseif msgType == "DUEL_SUSPEND" then
        if ns.BattleEngine and ns.BattleEngine.OnPeerDuelSuspend then
            ns.BattleEngine:OnPeerDuelSuspend(senderName, data)
        end
    elseif msgType == "DUEL_RESUME" then
        if ns.BattleEngine and ns.BattleEngine.OnPeerDuelResume then
            ns.BattleEngine:OnPeerDuelResume(senderName)
        end
    elseif msgType == "DUEL_FORFEIT" then
        if ns.BattleEngine and ns.BattleEngine.OnPeerForfeit then
            ns.BattleEngine:OnPeerForfeit(senderName, data)
        end
    elseif msgType == "PERMIT_UNLOCK" then
        local cType, bName = strsplit(":", data or "", 2)
        cType = cType or "Mechanical"
        bName = bName or "Boss"
        DB:UpdateQuestProgress("BOSS_KILL", 1)
        DB:AddTokens(25, bName .. " Defeated")
    elseif msgType == "NURSERY_INVITE" then
        if ForeverSafari.NurseryFrame then ForeverSafari.NurseryFrame:ReceiveInvite(senderName) end
    elseif msgType == "NURSERY_CANDIDATE" then
        if ForeverSafari.NurseryFrame then ForeverSafari.NurseryFrame:ReceivePartnerCandidate(senderName, data) end
    elseif msgType == "NURSERY_READY" then
        if ForeverSafari.NurseryFrame then ForeverSafari.NurseryFrame:ReceivePartnerReady(senderName, data) end
    elseif msgType == "NURSERY_CONFIRM" then
        if ForeverSafari.NurseryFrame then ForeverSafari.NurseryFrame:ReceivePartnerSacrifice(senderName, data) end
    elseif msgType == "NURSERY_CANCEL" then
        if ForeverSafari.NurseryFrame then ForeverSafari.NurseryFrame:ReceivePartnerCancel(senderName) end
    end
end
