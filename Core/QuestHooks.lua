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

function QH:Initialize()
    local f = CreateFrame("Frame", "ForeverSafariQuestEventFrame")
    f:RegisterEvent("QUEST_TURNED_IN")
    f:RegisterEvent("BOSS_KILL")
    f:RegisterEvent("ENCOUNTER_END")
    
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
        end
    end)
end

function QH:OnBossKilled(encounterID, name)
    -- Update Dungeon Expedition Quest Progress
    DB:UpdateQuestProgress("BOSS_KILL", 1)

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
