--[[
    Forever Safari: Database Core, Persistence Manager & State Vault (Database.lua)
    Implements:
      - Minimal Authoritative State Model (Zero-Stat-Trust)
      - Atomic Dual-Generation Monotonic Vault (active + backup)
      - Debounced Dirty-Flag Persistence Pipeline (5s idle, 60s hard ceiling)
      - Dynamic Runtime Companion Hydration (Hamilton-Hare 100/110 Budget Law)
      - Pure-Lua JSON State Serialization without loadstring dependencies
      - Crash, disconnect, and Alt-F4 automated recovery
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Database = ns.Database or {}

local DB = ns.Database
local C = ns.Constants
local Crypto = ns.Crypto

local function isSecret(v)
    if v == nil then return false end
    if issecret and issecret(v) then return true end
    if type(v) == "userdata" then return true end
    return false
end

-- =========================================================================
-- 📦 CANONICAL SCHEMA DEFINITION (V2)
-- =========================================================================

local DEFAULT_DB = {
    version = 2,
    tokens = 0,
    inventory = {
        ["copper_cage"] = 0,
        ["iron_cage"] = 0,
        ["mithril_cage"] = 0,
        ["thorium_trap"] = 0,
        ["copper_crate"] = 0,
        ["iron_crate"] = 0,
        ["mithril_crate"] = 0,
        ["thorium_crate"] = 0,
        ["az_treat"] = 0,
        ["healing_salve"] = 0,
        ["revival_crystal"] = 0,
    },
    collection = {}, -- Array of minimal companion seed tuples
    team = {},       -- Array of up to 4 active squad companion IDs
    activeSlot = 1,  -- Currently active deployed companion slot (1-4)
    discovered = {}, -- Legacy discovered table
    bestiary = {},   -- Modern 3-tier Pokédex discovery table
    rewardedQuests = {}, -- Map of questID -> timestamp (prevents double-dipping)
    scannedGuids = {},      -- Map of unitGUID -> epoch_timestamp (24h observation anti-farm lockout)
    defeatedTrainers = {},  -- Map of unitGUID -> epoch_timestamp (24h AI trainer battle lockout)
    defeatedOutposts = {},  -- Map of outpost.id -> epoch_timestamp (outpost victory record)
    badges = {},            -- Map of badgeId -> badge record
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

-- In-memory runtime state container
DB.state = nil
DB.keys = nil

-- Debounce timer variables
local isDirty = false
local saveTimer = nil
local lastSaveTime = 0
local DEBOUNCE_DELAY = 5.0
local HARD_SAVE_CEILING = 60.0

-- =========================================================================
-- 📄 PURE-LUA JSON SERIALIZER & DESERIALIZER (Zero loadstring Dependency)
-- =========================================================================

local function json_encode(v)
    local t = type(v)
    if t == "number" then
        return tostring(v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "table" then
        local isArray = (#v > 0)
        local parts = {}
        if isArray then
            for i = 1, #v do
                table.insert(parts, json_encode(v[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, val in pairs(v) do
                table.insert(parts, string.format("%q:%s", tostring(k), json_encode(val)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return "null"
    end
end

local function json_decode(str)
    if not str or str == "" then return nil end
    local pos = 1
    local len = #str

    local function skip_whitespace()
        while pos <= len do
            local b = string.byte(str, pos)
            if b == 32 or b == 9 or b == 10 or b == 13 then
                pos = pos + 1
            else
                break
            end
        end
    end

    local parse_value

    local function parse_string()
        pos = pos + 1 -- Skip opening quote
        local chars = {}
        while pos <= len do
            local c = string.sub(str, pos, pos)
            if c == '"' then
                pos = pos + 1
                return table.concat(chars)
            elseif c == '\\' then
                pos = pos + 1
                local esc = string.sub(str, pos, pos)
                if esc == 'n' then table.insert(chars, '\n')
                elseif esc == 'r' then table.insert(chars, '\r')
                elseif esc == 't' then table.insert(chars, '\t')
                elseif esc == '"' then table.insert(chars, '"')
                elseif esc == '\\' then table.insert(chars, '\\')
                else table.insert(chars, esc) end
                pos = pos + 1
            else
                table.insert(chars, c)
                pos = pos + 1
            end
        end
        return table.concat(chars)
    end

    local function parse_number()
        local s, e, numStr = string.find(str, '^(-?%d+%.?%d*)', pos)
        if numStr then
            pos = e + 1
            return tonumber(numStr)
        end
        pos = pos + 1
        return 0
    end

    local function parse_array()
        pos = pos + 1 -- Skip '['
        local arr = {}
        skip_whitespace()
        if pos <= len and string.sub(str, pos, pos) == ']' then
            pos = pos + 1
            return arr
        end
        while pos <= len do
            skip_whitespace()
            local val = parse_value()
            table.insert(arr, val)
            skip_whitespace()
            local c = string.sub(str, pos, pos)
            if c == ',' then
                pos = pos + 1
            elseif c == ']' then
                pos = pos + 1
                return arr
            else
                break
            end
        end
        return arr
    end

    local function parse_object()
        pos = pos + 1 -- Skip '{'
        local obj = {}
        skip_whitespace()
        if pos <= len and string.sub(str, pos, pos) == '}' then
            pos = pos + 1
            return obj
        end
        while pos <= len do
            skip_whitespace()
            if string.sub(str, pos, pos) == '"' then
                local key = parse_string()
                skip_whitespace()
                if string.sub(str, pos, pos) == ':' then
                    pos = pos + 1
                end
                skip_whitespace()
                local val = parse_value()
                obj[key] = val
                skip_whitespace()
                local c = string.sub(str, pos, pos)
                if c == ',' then
                    pos = pos + 1
                elseif c == '}' then
                    pos = pos + 1
                    return obj
                else
                    break
                end
            else
                pos = pos + 1
            end
        end
        return obj
    end

    parse_value = function()
        skip_whitespace()
        if pos > len then return nil end
        local c = string.sub(str, pos, pos)
        if c == '{' then
            return parse_object()
        elseif c == '[' then
            return parse_array()
        elseif c == '"' then
            return parse_string()
        elseif c == 't' and string.sub(str, pos, pos + 3) == 'true' then
            pos = pos + 4
            return true
        elseif c == 'f' and string.sub(str, pos, pos + 4) == 'false' then
            pos = pos + 5
            return false
        elseif c == 'n' and string.sub(str, pos, pos + 3) == 'null' then
            pos = pos + 4
            return nil
        else
            return parse_number()
        end
    end

    return parse_value()
end

function DB:SerializeState(state)
    -- Build a dehydated state where companions only store minimal tuples
    local dehydrated = CopyTable(state or self.state or DEFAULT_DB)
    if dehydrated.collection then
        for i, mob in ipairs(dehydrated.collection) do
            dehydrated.collection[i] = self:DehydrateCompanion(mob)
        end
    end
    return json_encode(dehydrated)
end

function DB:DeserializeState(str)
    local state = json_decode(str)
    if not state or type(state) ~= "table" then
        return CopyTable(DEFAULT_DB)
    end
    return state
end

-- =========================================================================
-- 🐾 MINIMAL AUTHORITATIVE STATE & DYNAMIC HYDRATION (Zero-Stat-Trust)
-- =========================================================================

function DB:DehydrateCompanion(mob)
    if not mob then return nil end
    return {
        id = mob.id,
        speciesId = mob.speciesId or mob.displayId,
        name = mob.name,
        customNickname = mob.customNickname,
        attunementPoints = mob.attunementPoints or mob.attunement or 0,
        attunementRank = mob.attunementRank or 1,
        anatomy = mob.anatomy or "Sire",
        moves = mob.moves or { 101, 107 },
        isRare = mob.isRare or false,
        ivSeed = mob.ivSeed or math.random(1, 65535),
        isStarter = mob.isStarter or false,
        family = mob.family or "Canine",
        element = mob.element or "Beast",
        creatureType = mob.creatureType or "Beast",
        displayId = mob.displayId,
        boxId = mob.boxId or 1,
        isFainted = mob.isFainted or false,
        currentHP = (mob.currentHP and mob.maxHP and mob.currentHP < mob.maxHP and mob.currentHP > 0) and mob.currentHP or nil,
        baseStats = mob.baseStats,
    }
end

function DB:HydrateCompanion(minimal)
    if not minimal then return nil end
    local mob = CopyTable(minimal)
    local SE = ns.StatEngine

    -- Determine rank and title dynamically from attunement points
    local rankInfo = SE and SE:GetAttunementRank(mob.attunementPoints or 0) or C.ATTUNEMENT_RANKS[1]
    mob.attunementRank = rankInfo.rank or mob.attunementRank or 1
    mob.rank = rankInfo.title or "Untamed"
    mob.attunement = mob.attunementPoints or 0

    -- Canonical Stat Calculation (Hamilton-Hare 100/110 Budget Law)
    -- Mutable stat values in files are completely overwritten with species canon!
    if SE and SE.CalculateStats then
        local calc = SE:CalculateStats(
            mob.element or mob.creatureType or mob.family or "Beast",
            mob.attunement or 0,
            mob.isRare or false,
            mob.baseStats
        )
        if calc then
            mob.maxHP = calc.maxHP
            mob.currentHP = mob.isFainted and 0 or (minimal.currentHP and math.min(math.max(1, minimal.currentHP), calc.maxHP) or calc.maxHP)
            mob.hp = mob.currentHP
            mob.atk = calc.atk
            mob.attack = calc.atk
            mob.def = calc.def
            mob.defense = calc.def
            mob.spd = calc.spd
            mob.speed = calc.spd
        end
    end

    if Crypto and Crypto.SignMob then
        Crypto:SignMob(mob)
    end
    return mob
end

-- =========================================================================
-- 🛡️ ATOMIC DUAL-GENERATION VAULT & DIRTY PERSISTENCE PIPELINE
-- =========================================================================

function DB:MarkDirty()
    isDirty = true
    local now = time()

    -- Hard ceiling: if 60s elapsed during continuous action, save immediately
    if (now - lastSaveTime) >= HARD_SAVE_CEILING then
        self:PersistVaultSnapshot()
        return
    end

    -- Debounced idle timer (5.0 seconds)
    if saveTimer and saveTimer.Cancel then
        saveTimer:Cancel()
    end
    if C_Timer and C_Timer.NewTimer then
        saveTimer = C_Timer.NewTimer(DEBOUNCE_DELAY, function()
            DB:PersistVaultSnapshot()
        end)
    end
end

function DB:FlushVault()
    if saveTimer and saveTimer.Cancel then
        saveTimer:Cancel()
        saveTimer = nil
    end
    if isDirty then
        self:PersistVaultSnapshot()
    end
end

function DB:PersistVaultSnapshot()
    if not self.keys or not self.state then return false end

    local playerGUID = UnitGUID("player") or "Player"
    local currentActive = ForeverSafariVault and ForeverSafariVault.active
    local nextGen = (currentActive and currentActive.generation or 0) + 1

    -- 1. Serialize in-memory state to minimal string
    local serialized = self:SerializeState(self.state)

    -- 2. Construct candidate snapshot C
    local candidate = Crypto:CreateVaultEnvelope(
        2, -- schemaVersion
        nextGen,
        playerGUID,
        serialized,
        self.keys.k_mac,
        self.keys.key4
    )

    -- 3. Validate candidate before rotation
    local isValid, err = Crypto:VerifyVaultEnvelope(candidate, self.keys.k_mac, 2)
    if not isValid then
        -- Abort! Keep existing active and backup completely untouched
        return false, "Candidate envelope verification failed: " .. tostring(err)
    end

    -- 4. Atomic state rotation: backup = old active, active = candidate
    if not ForeverSafariVault then
        ForeverSafariVault = {
            schemaVersion = 2,
            active = candidate,
            backup = candidate
        }
    else
        ForeverSafariVault.backup = ForeverSafariVault.active or candidate
        ForeverSafariVault.active = candidate
        ForeverSafariVault.schemaVersion = 2
    end

    isDirty = false
    lastSaveTime = time()
    return true
end

function DB:LoadVault()
    local playerGUID = UnitGUID("player") or "Player"
    local realmName = GetRealmName and GetRealmName() or "Forever"

    self.keys = Crypto:DeriveKeys(playerGUID, realmName)

    -- Detect legacy plaintext ForeverSafariDB on disk and migrate
    if (not ForeverSafariVault or not ForeverSafariVault.active) and ForeverSafariDB and type(ForeverSafariDB) == "table" and ForeverSafariDB.collection then
        self:MigrateLegacyDatabase()
        return
    end

    if not ForeverSafariVault or not ForeverSafariVault.active then
        -- Fresh new recruit
        self.state = CopyTable(DEFAULT_DB)
        ForeverSafariDB = self.state
        self:PersistVaultSnapshot()
        return
    end

    -- Attempt to verify & decrypt active slot
    local activeRecord = ForeverSafariVault.active
    local validActive = Crypto:VerifyVaultEnvelope(activeRecord, self.keys.k_mac, 2)
    local loadedPayload = nil

    if validActive then
        local payload, err = Crypto:DecryptVaultRecord(activeRecord, self.keys.key4)
        if payload and payload ~= "" then
            loadedPayload = payload
        end
    end

    -- If active failed, attempt fallback to backup generation
    if not loadedPayload and ForeverSafariVault.backup then
        local backupRecord = ForeverSafariVault.backup
        local validBackup = Crypto:VerifyVaultEnvelope(backupRecord, self.keys.k_mac, 2)
        if validBackup then
            local payload, err = Crypto:DecryptVaultRecord(backupRecord, self.keys.key4)
            if payload and payload ~= "" then
                loadedPayload = payload
                C_Timer.After(2.0, function()
                    DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffffcc00[Vault Recovery]|r An interrupted save was detected from your last session. State safely restored from backup generation!")
                    if ns.Toast and ns.Toast.ShowAlert then
                        ns.Toast:ShowAlert("Vault Recovered", "Restored from clean backup generation")
                    end
                end)
            end
        end
    end

    -- If both failed: Hard quarantine
    if not loadedPayload then
        ForeverSafariVault_Quarantine = CopyTable(ForeverSafariVault)
        ForeverSafariVault = nil
        self.state = CopyTable(DEFAULT_DB)
        ForeverSafariDB = self.state
        self:PersistVaultSnapshot()
        C_Timer.After(2.0, function()
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444[Security Alert]|r Vault integrity could not be verified. A clean profile has been initialized and corrupt data was quarantined.")
        end)
        return
    end

    -- Deserialization & dynamic hydration
    local rawState = self:DeserializeState(loadedPayload)
    self.state = self:MigrateSchema(rawState)
    ForeverSafariDB = self.state

    -- Hydrate all collection companions with canonical stats
    if self.state.collection then
        for i, minimal in ipairs(self.state.collection) do
            self.state.collection[i] = self:HydrateCompanion(minimal)
        end
    end
end

function DB:MigrateSchema(state)
    if not state or type(state) ~= "table" then
        return CopyTable(DEFAULT_DB)
    end

    local v = state.version or 1

    -- Migration Schema 1 -> Schema 2
    if v < 2 then
        state.version = 2
        for k, defVal in pairs(DEFAULT_DB) do
            if state[k] == nil then
                state[k] = (type(defVal) == "table") and CopyTable(defVal) or defVal
            end
        end
        if state.inventory then
            for itemKey, count in pairs(DEFAULT_DB.inventory) do
                if state.inventory[itemKey] == nil then
                    state.inventory[itemKey] = count
                end
            end
        end
        if state.stats then
            for statKey, statVal in pairs(DEFAULT_DB.stats) do
                if state.stats[statKey] == nil then
                    state.stats[statKey] = statVal
                end
            end
        end
    end

    -- Hook for future schema versions (e.g. v2 -> v3)
    -- if v < 3 then ... end

    return state
end

function DB:MigrateLegacyDatabase()
    local legacy = CopyTable(ForeverSafariDB)
    if ns.Crypto then
        ns.Crypto:ValidateAndRepairSignatures(legacy.collection)
    end
    self.state = self:MigrateSchema(legacy)
    ForeverSafariDB = self.state
    self:PersistVaultSnapshot()
    DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff00[Vault Migration]|r Legacy database successfully migrated into encrypted dual-generation vault.")
end

-- =========================================================================
-- 💾 DATABASE INITIALIZATION
-- =========================================================================

function DB:Initialize()
    if ForeverSafari.BuildDatabaseIndexes then
        ForeverSafari:BuildDatabaseIndexes()
    end

    -- Load or initialize encrypted vault
    self:LoadVault()

    -- Ensure all default structures exist in runtime state
    for k, v in pairs(DEFAULT_DB) do
        if self.state[k] == nil then
            if type(v) == "table" then
                self.state[k] = CopyTable(v)
            else
                self.state[k] = v
            end
        end
    end
    for k, v in pairs(DEFAULT_DB.inventory) do
        if self.state.inventory[k] == nil then
            self.state.inventory[k] = v
        end
    end
    for k, v in pairs(DEFAULT_DB.stats) do
        if self.state.stats[k] == nil then
            self.state.stats[k] = v
        end
    end

    -- Ensure settings
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

    self:ValidateTeam()
    self:PruneExpiredGuids()

    -- Audit static encounter tables
    if ns.OutpostDB and ns.OutpostDB.AuditIntegrity then
        local ok, reason = ns.OutpostDB:AuditIntegrity()
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444[Security Warning]|r " .. tostring(reason))
        end
    end
end

-- =========================================================================
-- 🧹 GUID ANTI-FARM LOCKOUT PRUNING
-- =========================================================================

function DB:PruneExpiredGuids()
    local now = time()
    local ttl = 86400 -- 24 hours
    if self.state and self.state.scannedGuids then
        for guid, timestamp in pairs(self.state.scannedGuids) do
            if (now - timestamp) > ttl then
                self.state.scannedGuids[guid] = nil
                self:MarkDirty()
            end
        end
    end
    if self.state and self.state.defeatedTrainers then
        for guid, timestamp in pairs(self.state.defeatedTrainers) do
            if (now - timestamp) > ttl then
                self.state.defeatedTrainers[guid] = nil
                self:MarkDirty()
            end
        end
    end
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
    if not self.state or not self.state.mail then return false end
    return self.state.mail.starterClaimed == true or #self:GetCollection() > 0
end

function DB:ClaimStarterKit()
    if not self.state then return false end
    self.state.mail = self.state.mail or {}
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
        customNickname = "",
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
        attunement = starterAttunement,
        rank = "Trusting",
        isStarter = true,
        ivSeed = math.random(1, 65535),
    }

    self:AddMob(starterMob, true)
    self:AddItem("copper_cage", 10)
    self:AddItem("copper_crate", 3)
    self:AddItem("healing_salve", 5)
    self:AddItem("revival_crystal", 1)
    self.state.mail.starterClaimed = true

    -- Calculate & award Veteran Field Grant from completed quests
    local grantCount = 0
    local grantTokens = 0
    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
        local completed = C_QuestLog.GetAllCompletedQuestIDs()
        if completed and type(completed) == "table" then
            for _, qId in ipairs(completed) do
                if not self:IsQuestRewarded(qId) then
                    self:MarkQuestRewarded(qId)
                    grantCount = grantCount + 1
                    local qLvl = nil
                    if C_QuestLog.GetQuestDifficultyLevel then
                        qLvl = C_QuestLog.GetQuestDifficultyLevel(qId)
                    end
                    if not qLvl or qLvl <= 0 then
                        local pLvl = UnitLevel("player") or 1
                        qLvl = (not isSecret(pLvl) and type(pLvl) == "number") and pLvl or 1
                    end
                    local tokenReward = math.max(1, math.ceil(qLvl / 10))
                    grantTokens = grantTokens + tokenReward
                end
            end
        end
    end

    if grantCount > 0 then
        self:AddTokens(grantTokens, string.format("Veteran Welcome Grant (%d Quests)", grantCount))
        self:UpdateQuestProgress("QUEST", grantCount)
        if self.state.stats then
            self.state.stats.totalQuestsCompleted = (self.state.stats.totalQuestsCompleted or 0) + grantCount
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

    self:MarkDirty()
    PlaySound(1195)
    return true, starterMob
end

function DB:IsLetterRead(letterId)
    if not self.state or not self.state.mail or not self.state.mail.readLetters then return false end
    return self.state.mail.readLetters[letterId] == true
end

function DB:MarkLetterRead(letterId)
    if not self.state then return end
    self.state.mail = self.state.mail or {}
    self.state.mail.readLetters = self.state.mail.readLetters or {}
    self.state.mail.readLetters[letterId] = true
    self:MarkDirty()
end

function DB:IsQuestClaimed(letterId)
    if not self.state or not self.state.mail or not self.state.mail.claimedQuests then return false end
    return self.state.mail.claimedQuests[letterId] == true
end

function DB:GetQuestProgress(questType)
    if not self.state or not self.state.mail or not self.state.mail.questProgress then return 0 end
    return self.state.mail.questProgress[questType] or 0
end

function DB:UpdateQuestProgress(questType, increment)
    if not self.state then return end
    self.state.mail = self.state.mail or {}
    self.state.mail.questProgress = self.state.mail.questProgress or {}
    local current = self.state.mail.questProgress[questType] or 0
    self.state.mail.questProgress[questType] = current + (increment or 1)
    self:MarkDirty()
end

-- =========================================================================
-- 📜 REAL QUEST REWARD TRACKING (PREVENT DOUBLE-DIPPING)
-- =========================================================================

function DB:IsQuestRewarded(questId)
    if not self.state or not self.state.rewardedQuests then return false end
    local qNum = tonumber(questId)
    local qKey = tostring(questId)
    return (qNum and self.state.rewardedQuests[qNum] ~= nil) or (self.state.rewardedQuests[qKey] ~= nil)
end

function DB:MarkQuestRewarded(questId)
    if not self.state then return end
    self.state.rewardedQuests = self.state.rewardedQuests or {}
    local qNum = tonumber(questId)
    local qKey = tostring(questId)
    local val = time()
    if qNum then self.state.rewardedQuests[qNum] = val end
    self.state.rewardedQuests[qKey] = val
    self:MarkDirty()
end

function DB:GetRewardedQuestCount()
    if not self.state or not self.state.rewardedQuests then return 0 end
    local count = 0
    for k, _ in pairs(self.state.rewardedQuests) do
        if type(k) == "number" then
            count = count + 1
        end
    end
    return count
end

function DB:ResetDB()
    self.state = CopyTable(DEFAULT_DB)
    ForeverSafariDB = self.state
    ForeverSafariVault = nil
    ForeverSafariVault_Quarantine = nil
    self:PersistVaultSnapshot()

    if ForeverSafari.HUDFrame and ForeverSafari.HUDFrame.UpdateHUD then
        ForeverSafari.HUDFrame:UpdateHUD()
    end
    if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame.RefreshAll then
        ForeverSafari.JournalFrame:RefreshAll()
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[Forever Safari]|r |cff00ff00Database reset! You are now a brand new recruit.|r Visit any town mailbox to unbox your starter kit.")
    if ns.Toast and ns.Toast.ShowReward then
        ns.Toast:ShowReward("Safari League Reset", "New recruit profile initialized! Visit any town mailbox.")
    end
    PlaySound(844)
end

-- =========================================================================
-- ⏱️ VAULT PERFORMANCE & INTEGRITY BENCHMARK (/safari benchmark)
-- =========================================================================
function DB:RunBenchmark()
    DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffffcc00[Vault Benchmark]|r Running persistence pipeline profiling...")

    if not self.keys then
        local playerGUID = UnitGUID("player") or "Player-16001-01A2B3C4"
        local realmName = GetRealmName and GetRealmName() or "Forever"
        self.keys = Crypto:DeriveKeys(playerGUID, realmName)
    end

    local testSizes = { 1, 10, 50, 100, 250 }
    for _, count in ipairs(testSizes) do
        local testCollection = {}
        for i = 1, count do
            table.insert(testCollection, {
                id = i,
                speciesId = 900 + (i % 50),
                name = "Companion #" .. i,
                attunementPoints = 600,
                attunementRank = 3,
                anatomy = (i % 2 == 0) and "Sire" or "Dam",
                moves = { 101, 107 },
                isRare = (i % 10 == 0),
                ivSeed = 12345 + i,
                family = "Canine",
                element = "Beast",
            })
        end

        local sampleState = {
            version = 2,
            tokens = 250,
            collection = testCollection,
            inventory = DEFAULT_DB.inventory,
            stats = DEFAULT_DB.stats,
        }

        local getTimeMs = function()
            return debugprofilestop and debugprofilestop() or (time() * 1000)
        end

        local t0 = getTimeMs()
        local serialized = self:SerializeState(sampleState)
        local t1 = getTimeMs()

        local candidate = Crypto:CreateVaultEnvelope(
            2,
            100,
            "Player-Benchmark",
            serialized,
            self.keys.k_mac,
            self.keys.key4
        )
        local t2 = getTimeMs()

        local isValid, err = Crypto:VerifyVaultEnvelope(candidate, self.keys.k_mac, 2)
        local decrypted = Crypto:DecryptVaultRecord(candidate, self.keys.key4)
        local restored = self:DeserializeState(decrypted)
        local t3 = getTimeMs()

        local serializeMs = t1 - t0
        local cryptAndMacMs = t2 - t1
        local verifyAndDecMs = t3 - t2
        local totalMs = t3 - t0
        local payloadBytes = #(candidate.payload or "")

        local statusTag = isValid and "|cff00ff00PASS|r" or "|cffff4444FAIL|r"
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  • [%s] %3d companions (%5d bytes): |cffffd100%.2f ms|r total (JSON: %.2fms | Encrypt+MAC: %.2fms | Decrypt: %.2fms)",
            statusTag, count, payloadBytes, totalMs, serializeMs, cryptAndMacMs, verifyAndDecMs
        ))
    end
    DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff00[Vault Benchmark]|r Benchmark suite complete!")
end
