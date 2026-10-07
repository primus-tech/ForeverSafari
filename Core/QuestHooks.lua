--[[
    Forever Safari: Boss Death & Research Permit Engine
    Listens for dungeon boss defeats and synchronizes research permit unlocks
    and Safari Token bounties across all party members with the addon.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.QuestHooks = ns.QuestHooks or {}

local QH = ns.QuestHooks
local C = ns.Constants
local DB = ns.Database

local recentKills = {}
local pendingToasts = {}

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
    local f = CreateFrame("Frame", "ForeverSafariBossEventFrame")
    f:RegisterEvent("BOSS_KILL")
    f:RegisterEvent("ENCOUNTER_END")
    f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")

    f:SetScript("OnEvent", function(self, event, ...)
        if event == "BOSS_KILL" then
            local encounterID, name = ...
            QH:OnBossDefeated(name)
        elseif event == "ENCOUNTER_END" then
            local encounterID, encounterName, difficultyID, groupSize, success = ...
            if success == 1 then
                QH:OnBossDefeated(encounterName)
            end
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            if CombatLogGetCurrentEventInfo then
                local _, subevent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
                if subevent == "UNIT_DIED" and destName then
                    QH:OnBossDefeated(destName)
                end
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            QH:FlushPendingCelebrations()
        end
    end)
end

function QH:OnBossDefeated(bossName)
    if not bossName or bossName == "" then return end
    local lowerName = string.lower(bossName)

    -- 1. Check Mechanical Bosses (Deadmines)
    if MECHANICAL_BOSSES[lowerName] then
        QH:HandlePermitUnlock("Mechanical", bossName, "KILL_MECHANICAL_BOSS")
        return
    end

    -- 2. Check Elemental Bosses (BFD)
    if ELEMENTAL_BOSSES[lowerName] then
        QH:HandlePermitUnlock("Elemental", bossName, "KILL_ELEMENTAL_BOSS")
        return
    end

    -- 3. Check Undead Bosses (RFD)
    if UNDEAD_BOSSES[lowerName] then
        QH:HandlePermitUnlock("Undead", bossName, "KILL_UNDEAD_BOSS")
        return
    end

    -- 4. Check Dragonkin Bosses (Sunken Temple)
    if DRAGONKIN_BOSSES[lowerName] then
        QH:HandlePermitUnlock("Dragonkin", bossName, "KILL_DRAGONKIN_BOSS")
        return
    end

    -- Check Evolution Catalysts
    if ForeverSafari.EvolutionDB and ForeverSafari.CatalystLootFrame then
        for catId, evo in pairs(ForeverSafari.EvolutionDB) do
            if evo.source and string.find(string.lower(evo.source), lowerName, 1, true) then
                ForeverSafari.CatalystLootFrame:StartRoll(catId, bossName)
                break
            end
        end
    end
end

function QH:OnBattleVictory(enemyMob)
    if not enemyMob then return end
    local name = enemyMob.name or "Wild Creature"
    QH:OnBossDefeated(name)
end

function QH:HandlePermitUnlock(cType, bossName, questTypeKey)
    local now = GetTime()
    local key = cType .. ":" .. (bossName or "")
    if recentKills[key] and (now - recentKills[key]) < 12 then return end
    recentKills[key] = now

    -- Update Virtual Database Progress
    if questTypeKey then
        DB:UpdateQuestProgress(questTypeKey, 1)
    end
    DB:UpdateQuestProgress("BOSS_KILL", 1)
    DB:AddTokens(25, bossName .. " Defeated")

    local wasUnlocked = DB:IsTypeUnlocked(cType)
    local inCombat = InCombatLockdown and InCombatLockdown()

    if not wasUnlocked then
        DB:UnlockType(cType, true) -- silent during combat
        if inCombat then
            table.insert(pendingToasts, {
                title = cType .. " Permit Unlocked!",
                desc = string.format("Defeated %s! %s research unlocked.", bossName, cType),
            })
        else
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[%s Defeated]|r +25 Safari Tokens! You unlocked |cffffd100%s|r pets!", C.PREFIX, bossName, cType))
            if ForeverSafari.Toast then
                ForeverSafari.Toast:ShowReward(cType .. " Permit Unlocked!", string.format("Defeated %s! %s research unlocked.", bossName, cType))
            end
            PlaySound(1195)
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[%s Defeated]|r +25 Safari Tokens awarded!", C.PREFIX, bossName))
    end

    -- Broadcast to entire party/raid so everyone receives the token & unlock
    if ns.Comms and ns.Comms.SendMessage then
        ns.Comms:SendMessage("PERMIT_UNLOCK", cType .. ":" .. bossName)
    end
end

function QH:FlushPendingCelebrations()
    if #pendingToasts == 0 then return end
    for _, toast in ipairs(pendingToasts) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[Research Permit Granted]|r %s", C.PREFIX, toast.desc))
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowReward(toast.title, toast.desc)
        end
        PlaySound(1195)
    end
    pendingToasts = {}
end
