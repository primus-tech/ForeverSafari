--[[
    Forever Safari: Virtual Quest & Expedition Directive Engine
    Completely virtualized quest tracking, boss takedowns, and research permit milestones.
    Zero interaction with protected Blizzard quest logs, unit frames, or combat log events.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.QuestHooks = ns.QuestHooks or {}

local QH = ns.QuestHooks
local C = ns.Constants
local DB = ns.Database

local recentKills = {}

local MECHANICAL_BOSSES = {
    ["sneed's shredder"] = true,
    ["sneeds shredder"] = true,
    ["foe reaper 5000"] = true,
    ["foe reaper 4000"] = true,
    ["defias harvest reaper"] = true,
    ["defias watcher"] = true,
    ["sneed"] = true,
}

local ELEMENTAL_BOSSES = {
    ["baron aquanis"] = true,
    ["aquanis"] = true,
    ["fathom core"] = true,
}

local UNDEAD_BOSSES = {
    ["amnennar the coldbringer"] = true,
    ["amnennar"] = true,
    ["mordresh fire eye"] = true,
    ["glutton"] = true,
    ["plaguemaw the rotting"] = true,
    ["tuten'kash"] = true,
    ["tutenkash"] = true,
}

local DRAGONKIN_BOSSES = {
    ["shade of eranikus"] = true,
    ["eranikus"] = true,
    ["dreamscythe"] = true,
    ["weaver"] = true,
    ["hazzas"] = true,
    ["morphaz"] = true,
}

function QH:Initialize()
    -- Purely virtual: Zero Blizzard event registration to eliminate taint
end

function QH:OnBattleVictory(enemyMob)
    if not enemyMob then return end
    local name = enemyMob.name or "Wild Creature"
    local lowerName = string.lower(name)
    local isElite = enemyMob.isElite or false

    -- 1. Check Dungeon Expedition / Boss Kill Directives
    if isElite or enemyMob.classification == "boss" or enemyMob.classification == "elite" then
        DB:UpdateQuestProgress("BOSS_KILL", 1)
    end

    -- 2. Check Virtual Mechanical Boss Directives (Deadmines)
    if MECHANICAL_BOSSES[lowerName] or (enemyMob.creatureType == "Mechanical" and isElite) then
        QH:HandlePermitUnlock("Mechanical", name, "KILL_MECHANICAL_BOSS")
    end

    -- 3. Check Virtual Elemental Boss Directives (BFD)
    if ELEMENTAL_BOSSES[lowerName] or (enemyMob.creatureType == "Elemental" and isElite) then
        QH:HandlePermitUnlock("Elemental", name, "KILL_ELEMENTAL_BOSS")
    end

    -- 4. Check Virtual Undead Boss Directives (RFD)
    if UNDEAD_BOSSES[lowerName] or (enemyMob.creatureType == "Undead" and isElite) then
        QH:HandlePermitUnlock("Undead", name, "KILL_UNDEAD_BOSS")
    end

    -- 5. Check Virtual Dragonkin Boss Directives (Sunken Temple)
    if DRAGONKIN_BOSSES[lowerName] or (enemyMob.creatureType == "Dragonkin" and isElite) then
        QH:HandlePermitUnlock("Dragonkin", name, "KILL_DRAGONKIN_BOSS")
    end

    -- 6. Check Virtual Catalyst Loot Roll
    if ForeverSafari.EvolutionDB and ForeverSafari.CatalystLootFrame then
        for catId, evo in pairs(ForeverSafari.EvolutionDB) do
            if evo.source and string.find(string.lower(evo.source), lowerName, 1, true) then
                ForeverSafari.CatalystLootFrame:StartRoll(catId, name)
                break
            end
        end
    end
end

function QH:HandlePermitUnlock(cType, bossName, questTypeKey)
    local now = GetTime()
    if recentKills[bossName] and (now - recentKills[bossName]) < 10 then return end
    recentKills[bossName] = now

    if questTypeKey then
        DB:UpdateQuestProgress(questTypeKey, 1)
    end
    DB:UpdateQuestProgress("BOSS_KILL", 1)
    DB:AddTokens(25, bossName .. " Defeated")

    local wasUnlocked = DB:IsTypeUnlocked(cType)
    if not wasUnlocked then
        DB:UnlockType(cType)
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[%s Defeated]|r +25 Safari Tokens awarded!", C.PREFIX, bossName))
    end

    if ns.Comms and ns.Comms.SendMessage then
        ns.Comms:SendMessage("PERMIT_UNLOCK", cType .. ":" .. bossName)
    end
end
