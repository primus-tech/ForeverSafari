--[[
    Forever Safari: Database Core & Persistence Manager (Database.lua)
    Handles SavedVariables initialization, schema migrations, cryptographic signatures,
    DNA string import/export, user settings, and Nesingwary mail/quest progression.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Database = ns.Database or {}

local DB = ns.Database

local DEFAULT_DB = {
    version = 2,
    tokens = 0,
    inventory = {
        ["copper_cage"] = 0,
        ["iron_cage"] = 0,
        ["mithril_cage"] = 0,
        ["thorium_trap"] = 0,
        ["arcanite_capsule"] = 0,
        ["az_treat"] = 0,
        ["healing_salve"] = 0,
        ["revival_crystal"] = 0,
    },
    collection = {}, -- List of all captured companions
    team = {},       -- Array of up to 4 active squad companion IDs
    activeSlot = 1,  -- Currently active deployed companion slot (1-4)
    discovered = {}, -- Legacy discovered table
    bestiary = {},   -- Modern 3-tier Pokédex discovery table
    rewardedQuests = {}, -- Map of questID -> timestamp (prevents double-dipping across sessions)
    unlockedAbilities = {
        ["101"] = true, -- Bite
        ["102"] = true, -- Growl
        ["108"] = true, -- Maul
        ["401"] = true, -- Water Jet
    },
    unlockedTypes = {
        ["Beast"] = true,
        ["Flying"] = true,
        ["Aquatic"] = true,
        ["Critter"] = true,
        ["Magic"] = true,
    },
    stats = {
        totalCaptured = 0,
        totalCagesThrown = 0,
        totalQuestsCompleted = 0,
        totalTokensEarned = 0,
        totalBattlesWon = 0,
        totalBattlesLost = 0,
        totalAbilitiesLearned = 4,
    },
    mail = {
        starterClaimed = false,
        readLetters = {},
        claimedQuests = {},
        questProgress = {
            ["CAPTURE_TOTAL"] = 0,
            ["FEED"] = 0,
            ["CAPTURE_RARE"] = 0,
            ["BOSS_KILL"] = 0,
        },
    }
}

local DEFAULT_SETTINGS = {
    showHUD = true,
    soundEnabled = true,
    combatLogAnnounce = true,
    minimap = {
        hide = false,
        angle = 45,
    }
}

-- =========================================================================
-- 💾 DATABASE INITIALIZATION & SCHEMA MIGRATIONS
-- =========================================================================
function DB:Initialize()
    if ForeverSafari.BuildDatabaseIndexes then
        ForeverSafari:BuildDatabaseIndexes()
    end

    if not ForeverSafariDB then
        ForeverSafariDB = CopyTable(DEFAULT_DB)
    else
        for k, v in pairs(DEFAULT_DB) do
            if ForeverSafariDB[k] == nil then
                if type(v) == "table" then
                    ForeverSafariDB[k] = CopyTable(v)
                else
                    ForeverSafariDB[k] = v
                end
            end
        end
        for k, v in pairs(DEFAULT_DB.inventory) do
            if ForeverSafariDB.inventory[k] == nil then
                ForeverSafariDB.inventory[k] = v
            end
        end
        for k, v in pairs(DEFAULT_DB.stats) do
            if ForeverSafariDB.stats[k] == nil then
                ForeverSafariDB.stats[k] = v
            end
        end
        if not ForeverSafariDB.unlockedAbilities then
            ForeverSafariDB.unlockedAbilities = CopyTable(DEFAULT_DB.unlockedAbilities)
        end
        if not ForeverSafariDB.unlockedTypes then
            ForeverSafariDB.unlockedTypes = CopyTable(DEFAULT_DB.unlockedTypes)
        end
        if not ForeverSafariDB.bestiary then
            ForeverSafariDB.bestiary = {}
        end

        -- Seamless migration: arcanite_capsule -> thorium_trap
        if ForeverSafariDB.inventory["arcanite_capsule"] and ForeverSafariDB.inventory["arcanite_capsule"] > 0 then
            ForeverSafariDB.inventory["thorium_trap"] = (ForeverSafariDB.inventory["thorium_trap"] or 0) + ForeverSafariDB.inventory["arcanite_capsule"]
            ForeverSafariDB.inventory["arcanite_capsule"] = 0
        end

        -- Auto-backfill Bestiary from current collection
        if self.BackfillBestiaryFromCollection then
            self:BackfillBestiaryFromCollection()
        end
    end

    if not ForeverSafariSettings then
        ForeverSafariSettings = CopyTable(DEFAULT_SETTINGS)
    else
        for k, v in pairs(DEFAULT_SETTINGS) do
            if ForeverSafariSettings[k] == nil then
                if type(v) == "table" then
                    ForeverSafariSettings[k] = CopyTable(v)
                else
                    ForeverSafariSettings[k] = v
                end
            end
        end
    end

    if ns.Crypto then ns.Crypto:ValidateAndRepairSignatures(ForeverSafariDB.collection) end
    self:ValidateTeam()
end

-- =========================================================================
-- ⚙️ SETTINGS & PREFERENCES
-- =========================================================================
function DB:GetSetting(key)
    if not ForeverSafariSettings then return nil end
    return ForeverSafariSettings[key]
end

function DB:SetSetting(key, value)
    if not ForeverSafariSettings then ForeverSafariSettings = {} end
    ForeverSafariSettings[key] = value
end

-- =========================================================================
-- ✉️ NESINGWARY MAILBOX & QUEST DISPATCH PROGRESSION
-- =========================================================================
function DB:IsStarterClaimed()
    if not ForeverSafariDB or not ForeverSafariDB.mail then return false end
    return ForeverSafariDB.mail.starterClaimed == true or #self:GetCollection() > 0
end

function DB:ClaimStarterKit()
    if not ForeverSafariDB then return false end
    ForeverSafariDB.mail = ForeverSafariDB.mail or {}
    if self:IsStarterClaimed() then return false, "Starter kit already claimed." end

    local _, playerRace = UnitRace("player")
    if not playerRace or playerRace == "" then playerRace = "Human" end

    local starterConfig = {
        ["Human"]     = { name = "Mangy Wolf",       type = "Beast", displayId = 903,    family = "Canine", element = "Beast", baseStats = { hp = 40, atk = 22, def = 18, spd = 20 }, moves = { 101, 104 } },
        ["Dwarf"]     = { name = "Young Black Bear", type = "Beast", displayId = 8843,   family = "Bear",   element = "Beast", baseStats = { hp = 45, atk = 20, def = 20, spd = 15 }, moves = { 101, 102 } },
        ["Gnome"]     = { name = "Crag Boar",        type = "Beast", displayId = 138623, family = "Boar",   element = "Beast", baseStats = { hp = 42, atk = 20, def = 22, spd = 16 }, moves = { 108, 107 } },
        ["NightElf"]  = { name = "Young Nightsaber", type = "Beast", displayId = 11454,  family = "Feline", element = "Beast", baseStats = { hp = 36, atk = 25, def = 16, spd = 23 }, moves = { 103, 107 } },
        ["Orc"]       = { name = "Scorpid Worker",   type = "Beast", displayId = 2485,   family = "Scorpid",element = "Beast", baseStats = { hp = 38, atk = 24, def = 22, spd = 16 }, moves = { 501, 502 } },
        ["Troll"]     = { name = "Bloodtalon Raptor",type = "Beast", displayId = 1960,   family = "Raptor", element = "Beast", baseStats = { hp = 36, atk = 26, def = 16, spd = 22 }, moves = { 103, 121 } },
        ["Tauren"]    = { name = "Kodo Calf",        type = "Beast", displayId = 1451,   family = "Kodo",   element = "Beast", baseStats = { hp = 48, atk = 18, def = 22, spd = 12 }, moves = { 108, 102 } },
        ["Scourge"]   = { name = "Mangy Duskbat",    type = "Flying",displayId = 9535,   family = "Bat",    element = "Flying",baseStats = { hp = 35, atk = 22, def = 15, spd = 28 }, moves = { 202, 709 } },
        ["Undead"]    = { name = "Mangy Duskbat",    type = "Flying",displayId = 9535,   family = "Bat",    element = "Flying",baseStats = { hp = 35, atk = 22, def = 15, spd = 28 }, moves = { 202, 709 } },
    }

    local data = starterConfig[playerRace] or starterConfig["Human"]
    local starterAttunement = 600 -- Rank 3: Trusting threshold (1.00x True Baseline Stats)
    local SE = ns.StatEngine
    local calc = SE and SE:CalculateStats(data.element or data.type, starterAttunement, false, data.baseStats)
    local maxHP = calc and calc.maxHP or data.baseStats.hp
    local atk = calc and calc.atk or data.baseStats.atk
    local def = calc and calc.def or data.baseStats.def
    local spd = calc and calc.spd or data.baseStats.spd

    local starterMob = {
        name = data.name,
        customNickname = "Starter " .. data.name,
        family = data.family,
        element = data.element,
        creatureType = data.element or data.type,
        displayId = data.displayId,
        level = 1,
        hp = maxHP,
        maxHP = maxHP,
        currentHP = maxHP,
        attack = atk,
        atk = atk,
        defense = def,
        def = def,
        speed = spd,
        spd = spd,
        baseStats = data.baseStats,
        moves = data.moves,
        attunementRank = 3,
        attunementPoints = starterAttunement,
        rank = "Trusting",
        isStarter = true,
    }

    self:AddMob(starterMob, true)
    self:AddItem("copper_cage", 10)
    self:AddItem("copper_crate", 3)
    self:AddItem("healing_salve", 5)
    self:AddItem("revival_crystal", 1)
    ForeverSafariDB.mail.starterClaimed = true

    -- Calculate & award Veteran Field Grant from completed quests
    local grantCount = 0
    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
        local completed = C_QuestLog.GetAllCompletedQuestIDs()
        if completed and type(completed) == "table" then
            for _, qId in ipairs(completed) do
                if not self:IsQuestRewarded(qId) then
                    self:MarkQuestRewarded(qId)
                    grantCount = grantCount + 1
                end
            end
        end
    end

    if grantCount > 0 then
        local grantTokens = grantCount * 5
        self:AddTokens(grantTokens, string.format("Veteran Welcome Grant (%d Quests)", grantCount))
        self:UpdateQuestProgress("QUEST", grantCount)
        if ForeverSafariDB.stats then
            ForeverSafariDB.stats.totalQuestsCompleted = (ForeverSafariDB.stats.totalQuestsCompleted or 0) + grantCount
        end

        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[Nesingwary Welcome Package]|r Unboxed %s, Field Gear, and an authorized Veteran Field Grant of |cffffd100+%d Safari Tokens|r for %d completed quests!", 
            ns.Constants.PREFIX, data.name, grantTokens, grantCount))

        if ns.Toast and ns.Toast.ShowReward then
            ns.Toast:ShowReward("Welcome Kit & Veteran Grant!", string.format("Received %s, Gear & +%d Safari Tokens (%d Quests)", data.name, grantTokens, grantCount))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[Nesingwary Welcome Package]|r Unboxed %s and Starter Field Supplies!", ns.Constants.PREFIX, data.name))

        if ns.Toast and ns.Toast.ShowReward then
            ns.Toast:ShowReward("Starter Kit Unboxed!", string.format("Received %s, 10x Snares, 3x Crates & Supplies", data.name))
        end
    end

    PlaySound(1195)
    return true, starterMob
end

function DB:IsLetterRead(letterId)
    if not ForeverSafariDB.mail or not ForeverSafariDB.mail.readLetters then return false end
    return ForeverSafariDB.mail.readLetters[letterId] == true
end

function DB:MarkLetterRead(letterId)
    if not ForeverSafariDB.mail then ForeverSafariDB.mail = {} end
    if not ForeverSafariDB.mail.readLetters then ForeverSafariDB.mail.readLetters = {} end
    ForeverSafariDB.mail.readLetters[letterId] = true
end

function DB:IsQuestClaimed(letterId)
    if not ForeverSafariDB.mail or not ForeverSafariDB.mail.claimedQuests then return false end
    return ForeverSafariDB.mail.claimedQuests[letterId] == true
end

function DB:GetQuestProgress(questType)
    if not ForeverSafariDB.mail or not ForeverSafariDB.mail.questProgress then return 0 end
    return ForeverSafariDB.mail.questProgress[questType] or 0
end

function DB:UpdateQuestProgress(questType, increment)
    if not ForeverSafariDB.mail then ForeverSafariDB.mail = {} end
    if not ForeverSafariDB.mail.questProgress then ForeverSafariDB.mail.questProgress = {} end
    local current = ForeverSafariDB.mail.questProgress[questType] or 0
    ForeverSafariDB.mail.questProgress[questType] = current + (increment or 1)
end

-- =========================================================================
-- 📜 REAL QUEST REWARD TRACKING (PREVENT DOUBLE-DIPPING)
-- =========================================================================
function DB:IsQuestRewarded(questId)
    if not ForeverSafariDB or not ForeverSafariDB.rewardedQuests then return false end
    local qNum = tonumber(questId)
    local qKey = tostring(questId)
    return (qNum and ForeverSafariDB.rewardedQuests[qNum] ~= nil) or (ForeverSafariDB.rewardedQuests[qKey] ~= nil)
end

function DB:MarkQuestRewarded(questId)
    if not ForeverSafariDB then return end
    ForeverSafariDB.rewardedQuests = ForeverSafariDB.rewardedQuests or {}
    local qNum = tonumber(questId)
    local qKey = tostring(questId)
    local val = time()
    if qNum then ForeverSafariDB.rewardedQuests[qNum] = val end
    ForeverSafariDB.rewardedQuests[qKey] = val
end

function DB:GetRewardedQuestCount()
    if not ForeverSafariDB or not ForeverSafariDB.rewardedQuests then return 0 end
    local count = 0
    for k, _ in pairs(ForeverSafariDB.rewardedQuests) do
        if type(k) == "number" then
            count = count + 1
        end
    end
    return count
end

function DB:ResetDB()
    ForeverSafariDB = CopyTable(DEFAULT_DB)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[Forever Safari]|r |cff00ff00Database reset! You are now a brand new recruit.|r Visit any town mailbox to unbox your starter kit.")
    if ns.Toast and ns.Toast.ShowReward then
        ns.Toast:ShowReward("Safari League Reset", "New recruit profile initialized! Visit any town mailbox.")
    end
    PlaySound(844)
end
