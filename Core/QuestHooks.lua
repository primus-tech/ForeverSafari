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

local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return true end
    if issecretpassphrase and issecretpassphrase(v) then return true end
    if issecretvariable and issecretvariable(v) then return true end
    local ok = pcall(function() local _ = (v == "") end)
    if not ok then return true end
    return false
end

local recentKills = {}
local recentQuests = {}
local pendingToasts = {}
local lastCompletedQuestTitle = nil

local MECHANICAL_BOSSES = {
    -- Deadmines
    ["sneed's shredder"] = true,
    ["sneeds shredder"] = true,
    ["foe reaper 5000"] = true,
    ["foe reaper 4000"] = true,
    ["defias harvest reaper"] = true,
    ["defias watcher"] = true,
    ["sneed"] = true,
    -- Gnomeregan
    ["mekgineer thermaplugg"] = true,
    ["thermaplugg"] = true,
    ["electrocutioner 6000"] = true,
    ["electrocutioner"] = true,
    ["crowd pummeler 9-60"] = true,
    ["crowd pummeler"] = true,
}

local ELEMENTAL_BOSSES = {
    -- Gnomeregan
    ["viscous fallout"] = true,
    ["viscous"] = true,
    ["grubbis"] = true,
    -- Blackfathom Deeps
    ["baron aquanis"] = true,
    ["aquanis"] = true,
    ["fathom core"] = true,
    ["aku'mai"] = true,
    ["akumai"] = true,
    ["twilight lord kelris"] = true,
    ["kelris"] = true,
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

local isInitialized = false

function QH:Initialize()
    if isInitialized then return end
    isInitialized = true

    local f = CreateFrame("Frame", "ForeverSafariBossEventFrame")
    f:RegisterEvent("BOSS_KILL")
    f:RegisterEvent("ENCOUNTER_END")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("QUEST_TURNED_IN")
    f:RegisterEvent("QUEST_COMPLETE")
    f:RegisterEvent("QUEST_FINISHED")
    f:RegisterEvent("PARTY_KILL")
    f:RegisterEvent("LOOT_OPENED")

    f:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2.0, function()
                QH:SyncCompletedQuests(false)
            end)
        elseif event == "QUEST_COMPLETE" then
            local title = GetTitleText and GetTitleText()
            if title and title ~= "" then
                lastCompletedQuestTitle = title
            end
        elseif event == "QUEST_TURNED_IN" then
            local questID, xpReward, moneyReward = ...
            QH:OnQuestTurnedIn(questID, xpReward, moneyReward)
        elseif event == "BOSS_KILL" then
            local encounterID, name = ...
            QH:OnBossDefeated(name)
        elseif event == "ENCOUNTER_END" then
            local encounterID, encounterName, difficultyID, groupSize, success = ...
            if success == 1 then
                QH:OnBossDefeated(encounterName)
            end
        elseif event == "PARTY_KILL" or event == "LOOT_OPENED" then
            QH:CheckTrashDropChance()
        elseif event == "PLAYER_REGEN_ENABLED" then
            QH:FlushPendingCelebrations()
        end
    end)
end

-- Retroactively grant Safari Tokens for all previously completed quests on the character
function QH:SyncCompletedQuests(isManual)
    -- If starter kit hasn't been claimed yet, do not trigger popup during initial login;
    -- the grant is proudly bundled as part of their official Nesingwary Welcome Package!
    if not isManual and DB and DB.IsStarterClaimed and not DB:IsStarterClaimed() then
        return 0
    end

    if not C_QuestLog or not C_QuestLog.GetAllCompletedQuestIDs then
        if isManual then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444C_QuestLog.GetAllCompletedQuestIDs API unavailable on this game client.|r")
        end
        return 0
    end

    local completed = C_QuestLog.GetAllCompletedQuestIDs()
    if not completed or type(completed) ~= "table" then return 0 end

    local newlyRewardedCount = 0
    for _, qId in ipairs(completed) do
        if not DB:IsQuestRewarded(qId) then
            DB:MarkQuestRewarded(qId)
            newlyRewardedCount = newlyRewardedCount + 1
        end
    end

    if newlyRewardedCount > 0 then
        local tokenPayout = newlyRewardedCount * 5
        DB:AddTokens(tokenPayout, string.format("Retroactive Grant (%d Quests)", newlyRewardedCount))
        DB:UpdateQuestProgress("QUEST", newlyRewardedCount)
        if ForeverSafariDB and ForeverSafariDB.stats then
            ForeverSafariDB.stats.totalQuestsCompleted = (ForeverSafariDB.stats.totalQuestsCompleted or 0) + newlyRewardedCount
        end

        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[Safari Research Grant]|r Retroactively awarded |cffffd100+%d Safari Tokens|r for %d completed field quests!", 
            C.PREFIX, tokenPayout, newlyRewardedCount))

        if ForeverSafari.Toast and ForeverSafari.Toast.ShowReward then
            ForeverSafari.Toast:ShowReward("Retroactive Research Grant", string.format("+%d Safari Tokens (%d Quests)", tokenPayout, newlyRewardedCount))
        end

        PlaySound(1195)
    elseif isManual then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%sAll %d completed quests are already recorded and rewarded (No double-dipping).", C.PREFIX, #completed))
    end

    return newlyRewardedCount
end

function QH:OnQuestTurnedIn(questID, xpReward, moneyReward)
    if not questID then return end

    -- Check if quest was already rewarded to prevent double dipping
    if DB:IsQuestRewarded(questID) then
        return
    end

    -- Permanently register this quest as rewarded in SavedVariables
    DB:MarkQuestRewarded(questID)

    -- Deduplicate repeated event triggers in short windows
    local now = GetTime()
    if recentQuests[questID] and (now - recentQuests[questID]) < 4 then return end
    recentQuests[questID] = now

    local questTitle = nil
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        questTitle = C_QuestLog.GetTitleForQuestID(questID)
    end
    if (not questTitle or questTitle == "") and lastCompletedQuestTitle then
        questTitle = lastCompletedQuestTitle
    end
    if not questTitle or questTitle == "" then
        questTitle = string.format("Quest #%s", tostring(questID))
    end

    -- Scale token rewards based on character level
    local tokenReward = 5
    local pLevel = UnitLevel("player") or 1
    if not isSecret(pLevel) and type(pLevel) == "number" then
        if pLevel >= 40 then
            tokenReward = 10
        elseif pLevel >= 20 then
            tokenReward = 7
        end
    end

    -- Award Safari Tokens
    DB:AddTokens(tokenReward, string.format("Quest: %s", questTitle))
    DB:UpdateQuestProgress("QUEST", 1)

    -- Bond with active squad companion
    local activeMob = DB:GetActiveMob()
    if activeMob then
        DB:AddAttunement(activeMob.id, 20, "Quest Completed with Companion")
    end

    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[Quest Complete: %s]|r Awarded |cffffd100+%d Safari Tokens|r for field service!", C.PREFIX, questTitle, tokenReward))

    if ForeverSafari.Toast and ForeverSafari.Toast.ShowReward then
        ForeverSafari.Toast:ShowReward("Safari Research Grant", string.format("+%d Safari Tokens (%s)", tokenReward, questTitle))
    end

    PlaySound(1195)
end

function QH:OnBossDefeated(bossName)
    if isSecret(bossName) or not bossName or type(bossName) ~= "string" or bossName == "" then return end
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

local lastTrashRollTime = 0

function QH:CheckTrashDropChance()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then return end

    local now = GetTime()
    if (now - lastTrashRollTime) < 0.5 then return end
    lastTrashRollTime = now

    -- 0.1% chance (1 in 1000) for a Minor Evolution Shard
    if math.random(1, 1000) == 1 then
        QH:AwardMinorCatalyst()
    end
end

function QH:AwardMinorCatalyst()
    DB:AddItem("minor_catalyst", 1)
    PlaySound(1195)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff1eff00[Minor Evolution Shard]|r dropped from dungeon quarry! Added to your Safari Bag. (Collect 10 to forge a full Catalyst)", C.PREFIX))
    if ForeverSafari.Toast and ForeverSafari.Toast.ShowReward then
        ForeverSafari.Toast:ShowReward("Minor Catalyst Discovered!", "+1x [Minor Evolution Shard] (Collect 10 to Forge)")
    end
end

-- Auto-initialize hooks immediately
QH:Initialize()
