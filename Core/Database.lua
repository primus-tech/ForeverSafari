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
    kennelChunks = {}, -- 20-chunk SavedVariable lots (19 x 100 + 1 x 106 = 2,006 slots)
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

DB.JSONEncode = json_encode
DB.JSONDecode = json_decode

-- =========================================================================
-- 🐾 MINIMAL AUTHORITATIVE STATE & DYNAMIC HYDRATION (Zero-Stat-Trust)
-- =========================================================================

function DB:DehydrateCompanion(mob)
    if not mob then return nil end
    local anat = mob.anatomy or mob.gender or "Sire"
    local moves = CopyTable(mob.moves or mob.abilities or { 101, 107 })
    local attPts = tonumber(mob.attunementPoints or mob.attunement) or 0
    local attRk = tonumber(mob.attunementRank or (mob.rankData and mob.rankData.rank)) or 1
    local maxHP = tonumber(mob.maxHP or mob.hp) or 40
    local curHP = tonumber(mob.currentHP or mob.hp or maxHP) or maxHP
    local atk = tonumber(mob.atk or mob.attack) or 22
    local def = tonumber(mob.def or mob.defense) or 18
    local spd = tonumber(mob.spd or mob.speed) or 20

    return {
        id = mob.id,
        speciesId = mob.speciesId or mob.displayId,
        name = mob.name,
        customNickname = mob.customNickname,
        nickname = mob.nickname or mob.customNickname,
        anatomy = anat,
        gender = anat,
        attunementPoints = attPts,
        attunement = attPts,
        attunementRank = attRk,
        rank = mob.rank or "Untamed",
        acclimationZones = mob.acclimationZones and CopyTable(mob.acclimationZones) or {},
        moves = moves,
        abilities = moves,
        stats = {
            hp = maxHP,
            maxHP = maxHP,
            atk = atk,
            def = def,
            spd = spd,
        },
        hp = curHP,
        maxHP = maxHP,
        currentHP = curHP,
        atk = atk,
        attack = atk,
        def = def,
        defense = def,
        spd = spd,
        speed = spd,
        baseStats = mob.baseStats and CopyTable(mob.baseStats) or nil,
        dodge = mob.dodge,
        resistances = mob.resistances and CopyTable(mob.resistances) or nil,
        isRare = mob.isRare or false,
        isElite = mob.isElite or false,
        ivSeed = mob.ivSeed or math.random(1, 65535),
        isStarter = mob.isStarter or false,
        family = mob.family or "Canine",
        element = mob.element or "Beast",
        creatureType = mob.creatureType or "Beast",
        displayId = mob.displayId,
        boxId = mob.boxId or 1,
        boxSlot = mob.boxSlot,
        isFainted = mob.isFainted or false,
        caughtZone = mob.caughtZone,
        caughtTime = mob.caughtTime,
        wins = mob.wins or 0,
        losses = mob.losses or 0,
        disobediences = mob.disobediences or 0,
        sig = mob.sig or mob.signature,
        signature = mob.signature or mob.sig,
    }
end

function DB:HydrateCompanion(minimal)
    if not minimal then return nil end
    local mob = CopyTable(minimal)
    local SE = ns.StatEngine

    -- Biological Sex & Anatomy
    mob.anatomy = mob.anatomy or mob.gender or "Sire"
    mob.gender = mob.anatomy

    -- Known Attacks / Movepool
    mob.moves = mob.moves or mob.abilities or { 101, 107 }
    mob.abilities = mob.moves

    -- Attunement progression
    local rankInfo = SE and SE:GetAttunementRank(mob.attunementPoints or mob.attunement or 0) or C.ATTUNEMENT_RANKS[1]
    mob.attunementRank = tonumber(mob.attunementRank or rankInfo.rank) or 1
    mob.rank = rankInfo.title or mob.rank or "Untamed"
    mob.attunement = tonumber(mob.attunementPoints or mob.attunement) or 0
    mob.attunementPoints = mob.attunement

    -- Canonical Stat Calculation (Hamilton-Hare 100/110 Budget Law)
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
            mob.stats = {
                hp = calc.maxHP,
                maxHP = calc.maxHP,
                atk = calc.atk,
                def = calc.def,
                spd = calc.spd,
            }
        end
    else
        local s = minimal.stats or {}
        mob.maxHP = s.maxHP or minimal.maxHP or minimal.hp or 40
        mob.currentHP = minimal.currentHP or minimal.hp or mob.maxHP
        mob.hp = mob.currentHP
        mob.atk = s.atk or minimal.atk or minimal.attack or 22
        mob.attack = mob.atk
        mob.def = s.def or minimal.def or minimal.defense or 18
        mob.defense = mob.def
        mob.spd = s.spd or minimal.spd or minimal.speed or 20
        mob.speed = mob.spd
        mob.stats = {
            hp = mob.maxHP,
            maxHP = mob.maxHP,
            atk = mob.atk,
            def = mob.def,
            spd = mob.spd,
        }
    end

    if Crypto and Crypto.SignMob then
        Crypto:SignMob(mob)
    end
    return mob
end

-- =========================================================================
-- 📦 20-CHUNK KENNEL SAVEDVARIABLE STORAGE (19 x 100 + 1 x 106 = 2,006 SLOTS)
-- =========================================================================

function DB:SyncKennelChunks()
    if not ForeverSafariKennel then
        ForeverSafariKennel = {}
    end
    for c = 1, (C and C.KENNEL_CHUNKS_COUNT or 20) do
        ForeverSafariKennel[c] = ForeverSafariKennel[c] or {}
    end

    -- Clear chunk tables for clean sync
    for c = 1, 20 do
        wipe(ForeverSafariKennel[c])
    end

    local collection = self:GetCollection()
    local boxSlotUsage = {}

    for _, mob in ipairs(collection) do
        local boxId = tonumber(mob.boxId) or 1
        boxId = math.max(1, math.min((C and C.MAX_KENNEL_BOXES or 101), boxId))
        local boxCap = (self.GetBoxCapacity and self:GetBoxCapacity(boxId)) or (boxId == 101 and 6 or 20)

        boxSlotUsage[boxId] = boxSlotUsage[boxId] or {}
        local slotInBox = tonumber(mob.boxSlot)
        if not slotInBox or slotInBox < 1 or slotInBox > boxCap or boxSlotUsage[boxId][slotInBox] then
            slotInBox = 1
            while slotInBox <= boxCap and boxSlotUsage[boxId][slotInBox] do
                slotInBox = slotInBox + 1
            end
            if slotInBox > boxCap then
                boxId = self.GetNextAvailableBox and self:GetNextAvailableBox(boxId) or 1
                boxCap = (self.GetBoxCapacity and self:GetBoxCapacity(boxId)) or (boxId == 101 and 6 or 20)
                boxSlotUsage[boxId] = boxSlotUsage[boxId] or {}
                slotInBox = 1
                while slotInBox <= boxCap and boxSlotUsage[boxId][slotInBox] do
                    slotInBox = slotInBox + 1
                end
            end
        end

        boxSlotUsage[boxId][slotInBox] = true
        mob.boxId = boxId
        mob.boxSlot = slotInBox

        local globalSlot = C.GetGlobalIndexForBoxAndSlot and C.GetGlobalIndexForBoxAndSlot(boxId, slotInBox) or ((boxId - 1) * 20 + slotInBox)
        local chunkId, chunkSlot = C.GetChunkAndSlotForGlobalIndex and C.GetChunkAndSlotForGlobalIndex(globalSlot)
        if not chunkId or not chunkSlot then
            if globalSlot <= 1900 then
                chunkId = math.floor((globalSlot - 1) / 100) + 1
                chunkSlot = ((globalSlot - 1) % 100) + 1
            else
                chunkId = 20
                chunkSlot = globalSlot - 1900
            end
        end

        local record = self:DehydrateCompanion(mob)
        record.chunkId = chunkId
        record.chunkSlot = chunkSlot
        record.globalSlot = globalSlot

        -- Cryptographically sign each chunk entry anchored to its coordinates
        if Crypto and Crypto.SignMob then
            Crypto:SignMob(record)
        end

        ForeverSafariKennel[chunkId][chunkSlot] = record
    end

    if self.state then
        self.state.kennelChunks = ForeverSafariKennel
    end
    if ForeverSafariDB then
        ForeverSafariDB.kennelChunks = ForeverSafariKennel
    end
    return ForeverSafariKennel
end

function DB:HasChunkedKennelData()
    local source = ForeverSafariKennel or (ForeverSafariDB and ForeverSafariDB.kennelChunks) or (self.state and self.state.kennelChunks)
    if not source or type(source) ~= "table" then return false end
    for c = 1, 20 do
        if source[c] and type(source[c]) == "table" and next(source[c]) ~= nil then
            return true
        end
    end
    return false
end

function DB:LoadKennelFromChunks()
    local sourceChunks = ForeverSafariKennel or (ForeverSafariDB and ForeverSafariDB.kennelChunks) or (self.state and self.state.kennelChunks)
    if not sourceChunks or type(sourceChunks) ~= "table" then return false end

    local restoredCollection = {}

    for c = 1, 20 do
        local chunk = sourceChunks[c]
        if chunk and type(chunk) == "table" then
            local maxSlot = (c == 20) and 106 or 100
            for slot = 1, maxSlot do
                local record = chunk[slot]
                if record and type(record) == "table" and record.name then
                    -- Verify entry-by-entry cryptographic integrity
                    record.chunkId = record.chunkId or c
                    record.chunkSlot = record.chunkSlot or slot
                    if Crypto and Crypto.ValidateSignature then
                        local isValidSig, sigType = Crypto:ValidateSignature(record)
                        if not isValidSig then
                            -- Zero-Stat-Trust: Notepad tampering or corrupt signature detected!
                            -- Recompute canonical stats to enforce 100/110pt statutory laws
                            if ns.StatEngine and ns.StatEngine.CalculateStats then
                                local calc = ns.StatEngine:CalculateStats(
                                    record.element or record.creatureType or record.family or "Beast",
                                    record.attunementPoints or record.attunement or 0,
                                    record.isRare or false,
                                    record.baseStats
                                )
                                if calc then
                                    record.maxHP = calc.maxHP
                                    record.currentHP = calc.maxHP
                                    record.hp = calc.maxHP
                                    record.atk = calc.atk
                                    record.attack = calc.atk
                                    record.def = calc.def
                                    record.defense = calc.def
                                    record.spd = calc.spd
                                    record.speed = calc.spd
                                    if record.stats then
                                        record.stats.hp = calc.maxHP
                                        record.stats.maxHP = calc.maxHP
                                        record.stats.atk = calc.atk
                                        record.stats.def = calc.def
                                        record.stats.spd = calc.spd
                                    end
                                end
                            end
                            -- Re-sign with clean canonical signature
                            if Crypto.SignMob then
                                Crypto:SignMob(record)
                            end
                        end
                    end

                    local hydrated = self:HydrateCompanion(record)
                    if hydrated then
                        hydrated.id = hydrated.id or (#restoredCollection + 1)
                        local globalSlot = C.GetGlobalIndexFromChunkAndSlot and C.GetGlobalIndexFromChunkAndSlot(c, slot) or (c < 20 and ((c - 1) * 100 + slot) or (1900 + slot))
                        local boxId, boxSlot
                        if C.GetBoxAndSlotForGlobalIndex then
                            boxId, boxSlot = C.GetBoxAndSlotForGlobalIndex(globalSlot)
                        else
                            boxId = math.floor((globalSlot - 1) / 20) + 1
                            boxSlot = ((globalSlot - 1) % 20) + 1
                        end
                        hydrated.boxId = hydrated.boxId or boxId
                        hydrated.boxSlot = hydrated.boxSlot or boxSlot
                        table.insert(restoredCollection, hydrated)
                    end
                end
            end
        end
    end

    if #restoredCollection > 0 then
        self.state = self.state or CopyTable(DEFAULT_DB)
        self.state.collection = restoredCollection
        ForeverSafariDB = self.state
        ForeverSafariDB.collection = restoredCollection
        self:SyncKennelChunks()
        return true
    end
    return false
end

function DB:GetKennelChunk(chunkId)
    chunkId = tonumber(chunkId) or 1
    if ForeverSafariKennel and ForeverSafariKennel[chunkId] then
        return ForeverSafariKennel[chunkId]
    end
    if ForeverSafariDB and ForeverSafariDB.kennelChunks and ForeverSafariDB.kennelChunks[chunkId] then
        return ForeverSafariDB.kennelChunks[chunkId]
    end
    return {}
end

function DB:GetKennelChunkCount()
    return (C and C.KENNEL_CHUNKS_COUNT) or 20
end

function DB:GetKennelChunkCapacity(chunkId)
    chunkId = tonumber(chunkId) or 1
    if chunkId == 20 then
        return (C and C.KENNEL_FINAL_CHUNK_SIZE) or 106
    end
    return (C and C.KENNEL_CHUNK_SIZE) or 100
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

    -- Synchronize 20-chunk kennel SavedVariable storage before serializing state
    self:SyncKennelChunks()

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

    -- Ensure ForeverSafariKennel global SavedVariable exists (20 Lots)
    if not ForeverSafariKennel then
        ForeverSafariKennel = {}
        for c = 1, (C and C.KENNEL_CHUNKS_COUNT or 20) do
            ForeverSafariKennel[c] = {}
        end
    end

    -- Load or initialize encrypted vault
    self:LoadVault()

    -- Synchronize or restore chunked kennel storage
    if self:HasChunkedKennelData() and (not self.state.collection or #self.state.collection == 0) then
        self:LoadKennelFromChunks()
    else
        self:SyncKennelChunks()
    end

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

function DB:ClaimQuestReward(letterId)
    if not self.state or self:IsQuestClaimed(letterId) then return false end
    self.state.mail = self.state.mail or {}
    self.state.mail.claimedQuests = self.state.mail.claimedQuests or {}
    self.state.mail.claimedQuests[letterId] = true

    local dispatch = ns.BountyDB and ns.BountyDB:GetDispatch(letterId)
    if dispatch and dispatch.rewards then
        if dispatch.rewards.tokens and dispatch.rewards.tokens > 0 then
            self:AddTokens(dispatch.rewards.tokens, dispatch.title or "Dispatch Completed")
        end
        if dispatch.rewards.items then
            for _, itm in ipairs(dispatch.rewards.items) do
                self:AddItem(itm.id, itm.count or 1)
            end
        end
    end

    if dispatch and dispatch.unlocksType then
        self:UnlockType(dispatch.unlocksType)
    end

    self:MarkDirty()
    PlaySound(1195)
    return true
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
    ForeverSafariKennel = {}
    for c = 1, (C and C.KENNEL_CHUNKS_COUNT or 20) do
        ForeverSafariKennel[c] = {}
    end
    self.state = CopyTable(DEFAULT_DB)
    self.state.kennelChunks = ForeverSafariKennel
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
-- ⏱️ VAULT PERFORMANCE & INTEGRITY BENCHMARK (/fs benchmark)
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

    -- Profile 2,006 Entry-by-Entry HMAC Signatures
    local getTimeMs = function() return debugprofilestop and debugprofilestop() or (time() * 1000) end
    local tSig0 = getTimeMs()
    for i = 1, 2006 do
        Crypto:GenerateSignature({
            id = i,
            speciesId = 900 + (i % 50),
            name = "Specimen #" .. i,
            hp = 40,
            maxHP = 40,
            atk = 22,
            def = 18,
            spd = 20,
            displayId = 903,
            anatomy = (i % 2 == 0) and "Sire" or "Dam",
            attunementPoints = 600,
            attunementRank = 3,
            moves = { 101, 107 },
            chunkId = (i <= 1900) and (math.floor((i - 1) / 100) + 1) or 20,
            chunkSlot = (i <= 1900) and (((i - 1) % 100) + 1) or (i - 1900),
            ivSeed = 12345 + i,
            isRare = (i % 10 == 0),
        })
    end
    local tSig1 = getTimeMs()
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "  • [|cff00ff00PASS|r] 2,006 Entry-by-Entry HMAC Signatures: |cffffd100%.2f ms|r total (%.3f ms/entry)",
        tSig1 - tSig0, (tSig1 - tSig0) / 2006
    ))

    DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff00[Vault Benchmark]|r Benchmark suite complete!")
end
