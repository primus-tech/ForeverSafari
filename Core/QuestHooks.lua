--[[
    Forever Safari: Quest Hooks & Safari Rewards
    Monitors quest completions and awards Safari Tokens based on quest level and difficulty.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.QuestHooks = ns.QuestHooks or {}

local QH = ns.QuestHooks
local C = ns.Constants
local DB = ns.Database

local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then
        return true
    end
    return false
end

local recentKills = {}

local MECHANICAL_DEADMINES_NPCS = {
    [642] = "Sneed's Shredder",
    [643] = "Sneed",
    [43778] = "Foe Reaper 5000",
    [47418] = "Foe Reaper 5000",
    [5721] = "Foe Reaper 4000",
}

local MECHANICAL_DEADMINES_NAMES = {
    ["sneed's shredder"] = true,
    ["sneeds shredder"] = true,
    ["foe reaper 5000"] = true,
    ["foe reaper 4000"] = true,
    ["defias harvest reaper"] = true,
    ["defias watcher"] = true,
    ["sneed"] = true,
}

function QH:IsMechanicalDeadminesBoss(name, npcID)
    if npcID and MECHANICAL_DEADMINES_NPCS[npcID] then
        return true
    end
    if name and MECHANICAL_DEADMINES_NAMES[string.lower(name)] then
        return true
    end
    return false
end

function QH:HandleMechanicalBossKill(bossName)
    if not bossName or bossName == "" then bossName = "Sneed's Shredder" end
    local now = GetTime()
    if recentKills[bossName] and (now - recentKills[bossName]) < 15 then
        return
    end
    recentKills[bossName] = now

    -- Update Quest Progress
    DB:UpdateQuestProgress("KILL_MECHANICAL_BOSS", 1)
    DB:UpdateQuestProgress("BOSS_KILL", 1)

    -- Award tokens to player on the spot
    DB:AddTokens(25, bossName .. " Defeated")

    -- Unlock Mechanical research permit
    local wasUnlocked = DB:IsTypeUnlocked("Mechanical")
    if not wasUnlocked then
        DB:UnlockType("Mechanical")
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[%s Defeated]|r +25 Safari Tokens awarded!", C.PREFIX, bossName))
    end

    -- Broadcast to party/raid addon users
    if ns.Comms and ns.Comms.SendMessage then
        ns.Comms:SendMessage("PERMIT_UNLOCK", "Mechanical:" .. bossName)
    end
end

local ELEMENTAL_BFD_NPCS = {
    [12876] = "Baron Aquanis",
    [213334] = "Baron Aquanis",
    [4887] = "Baron Aquanis",
}

local ELEMENTAL_BFD_NAMES = {
    ["baron aquanis"] = true,
    ["aquanis"] = true,
}

function QH:IsElementalBfdBoss(name, npcID)
    if npcID and ELEMENTAL_BFD_NPCS[npcID] then
        return true
    end
    if name and ELEMENTAL_BFD_NAMES[string.lower(name)] then
        return true
    end
    return false
end

function QH:HandleElementalBossKill(bossName)
    if not bossName or bossName == "" then bossName = "Baron Aquanis" end
    local now = GetTime()
    if recentKills[bossName] and (now - recentKills[bossName]) < 15 then
        return
    end
    recentKills[bossName] = now

    -- Update Quest Progress
    DB:UpdateQuestProgress("KILL_ELEMENTAL_BOSS", 1)
    DB:UpdateQuestProgress("BOSS_KILL", 1)

    -- Award tokens to player on the spot
    DB:AddTokens(25, bossName .. " Defeated")

    -- Unlock Elemental research permit
    local wasUnlocked = DB:IsTypeUnlocked("Elemental")
    if not wasUnlocked then
        DB:UnlockType("Elemental")
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[%s Defeated]|r +25 Safari Tokens awarded!", C.PREFIX, bossName))
    end

    -- Broadcast to party/raid addon users
    if ns.Comms and ns.Comms.SendMessage then
        ns.Comms:SendMessage("PERMIT_UNLOCK", "Elemental:" .. bossName)
    end
end

local UNDEAD_RFD_NPCS = {
    [7358] = "Amnennar the Coldbringer",
    [7357] = "Mordresh Fire Eye",
    [8567] = "Glutton",
    [7356] = "Plaguemaw the Rotting",
    [7355] = "Tuten'kash",
    [7354] = "Ragglesnout",
}

local UNDEAD_RFD_NAMES = {
    ["amnennar the coldbringer"] = true,
    ["amnennar"] = true,
    ["mordresh fire eye"] = true,
    ["glutton"] = true,
    ["plaguemaw the rotting"] = true,
    ["tuten'kash"] = true,
    ["tutenkash"] = true,
}

function QH:IsUndeadRfdBoss(name, npcID)
    if npcID and UNDEAD_RFD_NPCS[npcID] then
        return true
    end
    if name and UNDEAD_RFD_NAMES[string.lower(name)] then
        return true
    end
    return false
end

function QH:HandleUndeadBossKill(bossName)
    if not bossName or bossName == "" then bossName = "Amnennar the Coldbringer" end
    local now = GetTime()
    if recentKills[bossName] and (now - recentKills[bossName]) < 15 then
        return
    end
    recentKills[bossName] = now

    -- Update Quest Progress
    DB:UpdateQuestProgress("KILL_UNDEAD_BOSS", 1)
    DB:UpdateQuestProgress("BOSS_KILL", 1)

    -- Award tokens to player on the spot
    DB:AddTokens(25, bossName .. " Defeated")

    -- Unlock Undead research permit
    local wasUnlocked = DB:IsTypeUnlocked("Undead")
    if not wasUnlocked then
        DB:UnlockType("Undead")
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[%s Defeated]|r +25 Safari Tokens awarded!", C.PREFIX, bossName))
    end

    -- Broadcast to party/raid addon users
    if ns.Comms and ns.Comms.SendMessage then
        ns.Comms:SendMessage("PERMIT_UNLOCK", "Undead:" .. bossName)
    end
end

function QH:Initialize()
    local f = CreateFrame("Frame", "ForeverSafariQuestEventFrame")
    f:RegisterEvent("QUEST_TURNED_IN")
    f:RegisterEvent("BOSS_KILL")
    f:RegisterEvent("ENCOUNTER_END")
    f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    f:SetScript("OnEvent", function(self, event, ...)
        if event == "QUEST_TURNED_IN" then
            local questID, xpReward, moneyReward = ...
            QH:OnQuestTurnedIn(questID, xpReward, moneyReward)
        elseif event == "BOSS_KILL" then
            local encounterID, name = ...
            QH:OnBossKilled(encounterID, name)
        elseif event == "ENCOUNTER_END" then
            local encounterID, encounterName, difficultyID, groupSize, success = ...
            if success == 1 then
                QH:OnBossKilled(encounterID, encounterName)
            end
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            if CombatLogGetCurrentEventInfo then
                local _, subevent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
                if subevent == "UNIT_DIED" and destName then
                    local npcID = nil
                    if destGUID then
                        local _, _, _, _, _, idStr = strsplit("-", destGUID)
                        npcID = tonumber(idStr)
                    end
                    if QH:IsMechanicalDeadminesBoss(destName, npcID) then
                        QH:HandleMechanicalBossKill(destName)
                    elseif QH:IsElementalBfdBoss(destName, npcID) then
                        QH:HandleElementalBossKill(destName)
                    elseif QH:IsUndeadRfdBoss(destName, npcID) then
                        QH:HandleUndeadBossKill(destName)
                    end
                end
            end
        end
    end)
end

function QH:OnBossKilled(encounterID, name)
    -- Update Dungeon Expedition Quest Progress
    DB:UpdateQuestProgress("BOSS_KILL", 1)

    if name then
        if QH:IsMechanicalDeadminesBoss(name) then
            QH:HandleMechanicalBossKill(name)
        elseif QH:IsElementalBfdBoss(name) then
            QH:HandleElementalBossKill(name)
        elseif QH:IsUndeadRfdBoss(name) then
            QH:HandleUndeadBossKill(name)
        end
    end

    -- Check if this boss drops a catalyst
    if ForeverSafari.GetBossCatalyst then
        local catId = ForeverSafari:GetBossCatalyst(encounterID)
        if not catId and ForeverSafari.EvolutionDB then
            -- Check if catalyst exists for encounter name or default
            for cId, evo in pairs(ForeverSafari.EvolutionDB) do
                if evo.source and name and string.find(string.lower(evo.source), string.lower(name)) then
                    catId = cId
                    break
                end
            end
        end

        if catId and ForeverSafari.CatalystLootFrame then
            ForeverSafari.CatalystLootFrame:StartRoll(catId, name)
        end
    end
end

function QH:CalculateTokensForQuest(questID, xpReward)
    local playerLevel = UnitLevel("player") or 1
    local questLevel = playerLevel

    -- Attempt to get quest level if API available
    if questID and C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
        local qLevel = C_QuestLog.GetQuestDifficultyLevel(questID)
        if qLevel and qLevel > 0 then
            questLevel = qLevel
        end
    end

    local tokens = 5
    if questLevel <= 15 then
        tokens = math.random(4, 7)
    elseif questLevel <= 30 then
        tokens = math.random(8, 12)
    elseif questLevel <= 45 then
        tokens = math.random(13, 18)
    elseif questLevel <= 55 then
        tokens = math.random(19, 25)
    else
        tokens = math.random(25, 35)
    end

    -- Bonus if high XP reward quest
    if xpReward and xpReward > 3000 then
        tokens = tokens + 5
    end

    return tokens
end

function QH:OnQuestTurnedIn(questID, xpReward, moneyReward)
    local questTitle = "Quest"
    if questID and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title and title ~= "" then
            questTitle = title
        end
    end

    local tokens = QH:CalculateTokensForQuest(questID, xpReward)
    DB:AddTokens(tokens, string.format("Quest: %s", questTitle))
    ForeverSafariDB.stats.totalQuestsCompleted = (ForeverSafariDB.stats.totalQuestsCompleted or 0) + 1

    DEFAULT_CHAT_FRAME:AddMessage(string.format("%sEarned |cff00ff00+%d Safari Tokens|r for completing quest: |cffffd100%s|r! (Total: |cffffd100%d|r)",
        C.PREFIX, tokens, questTitle, DB:GetTokens()))
    
    PlaySound(1195) -- SOUNDKIT.IG_QUEST_LOG_COMPLETE
end
