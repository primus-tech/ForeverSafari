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

    self:ValidateAndRepairSignatures()
    self:ValidateTeam()
end

-- =========================================================================
-- 🔐 CRYPTOGRAPHIC INTEGRITY & ANTI-TAMPER SIGNATURES
-- =========================================================================
local SECRET_SALT = "ForeverSafari_Nesingwary_League_2026_Secure"

function DB:Hash(str)
    local hash = 2166136261
    local prime = 16777619
    local combined = tostring(str) .. ":" .. SECRET_SALT
    for i = 1, #combined do
        local byte = string.byte(combined, i)
        hash = (hash + byte) * prime
        hash = hash % 4294967296
    end
    return string.format("%08x", hash)
end

function DB:GenerateSignature(mob)
    if not mob then return "" end
    local str = string.format("%s:%s:%d:%d:%d:%d:%d:%s",
        tostring(mob.id or 0),
        tostring(mob.name or ""),
        tonumber(mob.level or 1),
        tonumber(mob.hp or 10),
        tonumber(mob.attack or 5),
        tonumber(mob.defense or 5),
        tonumber(mob.speed or 5),
        tostring(mob.displayId or 0)
    )
    return self:Hash(str)
end

function DB:SignMob(mob)
    if not mob then return end
    mob.sig = self:GenerateSignature(mob)
    return mob
end

function DB:ValidateAndRepairSignatures()
    if not ForeverSafariDB or not ForeverSafariDB.collection then return end

    for _, mob in ipairs(ForeverSafariDB.collection) do
        -- Ensure default moves
        if not mob.moves or #mob.moves == 0 then
            mob.moves = { 101, 107, 102, 118 }
        end

        local expectedSig = self:GenerateSignature(mob)
        if not mob.sig or mob.sig ~= expectedSig then
            if not mob.maxHP or mob.maxHP <= 0 then
                mob.maxHP = mob.hp or 60
            end
            if not mob.currentHP or mob.currentHP > mob.maxHP then
                mob.currentHP = mob.maxHP
            end
            mob.hp = mob.currentHP
            self:SignMob(mob)
        else
            if not mob.maxHP or mob.maxHP <= 0 then
                mob.maxHP = mob.hp or 60
            end
            if mob.currentHP == nil then
                mob.currentHP = mob.maxHP
            end
            mob.hp = mob.currentHP
        end
    end
end

-- =========================================================================
-- 🧬 BASE64 & DNA STRING COMPANION SHARING
-- =========================================================================
local B64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function DB:EncodeBase64(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return B64_CHARS:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function DB:DecodeBase64(data)
    data = string.gsub(data, '[^'..B64_CHARS..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(B64_CHARS:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function DB:ExportCompanionDNA(mob)
    if not mob then return "" end
    local movesStr = table.concat(mob.moves or {}, ",")
    local raw = string.format("%s~%s~%d~%d~%d~%d~%d~%d~%s~%s~%s",
        tostring(mob.name or "Wild Mob"),
        tostring(mob.customNickname or mob.name or "Wild Mob"),
        tonumber(mob.level or 1),
        tonumber(mob.hp or 10),
        tonumber(mob.attack or 5),
        tonumber(mob.defense or 5),
        tonumber(mob.speed or 5),
        tonumber(mob.displayId or 903),
        tostring(mob.family or "Canine"),
        movesStr,
        tostring(mob.sig or "")
    )
    return "!FS:" .. self:EncodeBase64(raw)
end

function DB:ImportCompanionDNA(dnaStr)
    if not dnaStr or not dnaStr:find("^!FS:") then return nil end
    local b64 = dnaStr:sub(5)
    local raw = self:DecodeBase64(b64)
    if not raw or raw == "" then return nil end

    local parts = {}
    for part in string.gmatch(raw, "[^~]+") do
        table.insert(parts, part)
    end
    if #parts < 8 then return nil end

    local moves = {}
    if parts[10] and parts[10] ~= "" then
        for mv in string.gmatch(parts[10], "[^,]+") do
            table.insert(moves, tonumber(mv) or mv)
        end
    end

    return {
        name = parts[1],
        customNickname = parts[2],
        level = tonumber(parts[3]) or 1,
        hp = tonumber(parts[4]) or 10,
        maxHp = tonumber(parts[4]) or 10,
        attack = tonumber(parts[5]) or 5,
        defense = tonumber(parts[6]) or 5,
        speed = tonumber(parts[7]) or 5,
        displayId = tonumber(parts[8]) or 903,
        family = parts[9] or "Canine",
        moves = moves,
        sig = parts[11] or ""
    }
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
        ["Human"]     = { name = "Mangy Wolf",       type = "Beast", displayId = 903,    family = "Canine", element = "Beast", moves = { 101, 107, 102, 126 } },
        ["Dwarf"]     = { name = "Young Black Bear", type = "Beast", displayId = 8843,   family = "Bear",   element = "Beast", moves = { 108, 105, 119, 118 } },
        ["Gnome"]     = { name = "Crag Boar",        type = "Beast", displayId = 138623, family = "Boar",   element = "Beast", moves = { 108, 107, 119, 125 } },
        ["NightElf"]  = { name = "Young Nightsaber", type = "Beast", displayId = 11454,  family = "Feline", element = "Beast", moves = { 103, 104, 121, 124 } },
        ["Orc"]       = { name = "Scorpid Worker",   type = "Beast", displayId = 2485,   family = "Scorpid",element = "Beast", moves = { 501, 502, 108, 510 } },
        ["Troll"]     = { name = "Bloodtalon Raptor",type = "Beast", displayId = 1960,   family = "Raptor", element = "Beast", moves = { 103, 101, 107, 121 } },
        ["Tauren"]    = { name = "Kodo Calf",        type = "Beast", displayId = 1451,   family = "Kodo",   element = "Beast", moves = { 108, 105, 118, 119 } },
        ["Scourge"]   = { name = "Mangy Duskbat",    type = "Beast", displayId = 9535,   family = "Bat",    element = "Flying",moves = { 202, 709, 204, 126 } },
        ["Undead"]    = { name = "Mangy Duskbat",    type = "Beast", displayId = 9535,   family = "Bat",    element = "Flying",moves = { 202, 709, 204, 126 } },
    }

    local data = starterConfig[playerRace] or starterConfig["Human"]
    local starterMob = {
        name = data.name,
        customNickname = "Starter " .. data.name,
        family = data.family,
        element = data.element,
        displayId = data.displayId,
        level = 1,
        hp = 60,
        maxHP = 60,
        currentHP = 60,
        attack = 16,
        defense = 12,
        speed = 14,
        moves = data.moves,
        attunementRank = 1,
        attunementPoints = 0,
    }

    self:AddMob(starterMob, true)
    self:AddItem("copper_cage", 10)
    self:AddItem("copper_crate", 3)
    self:AddItem("healing_salve", 5)
    self:AddItem("revival_crystal", 1)
    ForeverSafariDB.mail.starterClaimed = true

    if ns.Toast and ns.Toast.ShowReward then
        ns.Toast:ShowReward("Starter Kit Unboxed!", string.format("Received %s, 10x Snares, 3x Crates & Supplies", data.name))
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

function DB:ResetDB()
    ForeverSafariDB = CopyTable(DEFAULT_DB)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[Forever Safari]|r |cff00ff00Database reset! You are now a brand new recruit.|r Visit any town mailbox to unbox your starter kit.")
    if ns.Toast and ns.Toast.ShowReward then
        ns.Toast:ShowReward("Safari League Reset", "New recruit profile initialized! Visit any town mailbox.")
    end
    PlaySound(844)
end
