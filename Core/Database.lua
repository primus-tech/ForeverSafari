--[[
    Forever Safari: Database & Persistence Layer
    Handles SavedVariables, default data structures, inventory, party management,
    storage, and the Vanilla WoW style Unlocked Ability Training Grimoire.
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
        ["arcanite_capsule"] = 0,
        ["az_treat"] = 0,
        ["healing_salve"] = 0,
        ["revival_crystal"] = 0,
    },
    collection = {}, -- List of all captured companions
    team = {},       -- Array of up to 4 active team companion IDs
    activeSlot = 1,  -- Currently active deployed companion slot (1-4)
    discovered = {}, -- Bestiary seen/caught records [npcName] = { seen = 1, caught = 0, type = "Beast" }
    unlockedAbilities = { -- Learned abilities known to the trainer (Vanilla WoW pet training style)
        ["Tackle"] = true,
        ["Bite"] = true,
        ["Furious_Howl"] = true,
        ["Water_Jet"] = true,
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

-- Initialize DB on ADDON_LOADED
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

    DB:ValidateAndRepairSignatures()
    DB:ValidateTeam()
end

-- =========================================================================
-- CRYPTOGRAPHIC INTEGRITY & ANTI-TAMPER SIGNATURES
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
    return DB:Hash(str)
end

function DB:SignMob(mob)
    if not mob then return end
    mob.sig = DB:GenerateSignature(mob)
    return mob
end

function DB:ValidateAndRepairSignatures()
    if not ForeverSafariDB.collection then return end
    local abilitiesDB = ForeverSafari.Constants and ForeverSafari.Constants.ABILITIES or {}

    for _, mob in ipairs(ForeverSafariDB.collection) do
        -- Heal empty or invalid abilities on existing companions
        if not mob.abilities or #mob.abilities == 0 then
            if ForeverSafari.StatEngine and ForeverSafari.StatEngine.GenerateAbilities then
                mob.abilities = ForeverSafari.StatEngine:GenerateAbilities(mob.creatureType, mob.family)
            else
                mob.abilities = { (mob.creatureType == "Beast" and "Bite") or "Tackle" }
            end
        else
            for i, moveKey in ipairs(mob.abilities) do
                if not abilitiesDB[moveKey] then
                    mob.abilities[i] = (mob.creatureType == "Beast" and "Bite") or "Tackle"
                end
            end
        end

        -- Guarantee all companion moves are unlocked in Trainer Grimoire
        if mob.abilities then
            for _, moveKey in ipairs(mob.abilities) do
                if abilitiesDB[moveKey] then
                    DB:UnlockAbility(moveKey, mob.name, true)
                end
            end
        end

        local expectedSig = DB:GenerateSignature(mob)
        if not mob.sig or mob.sig ~= expectedSig then
            -- If tampered or legacy, recompute legal bounds
            if ForeverSafari.StatEngine and ForeverSafari.StatEngine.CalculateStats then
                local baseStats = nil
                if ForeverSafari.CreatureDB then
                    for _, entry in pairs(ForeverSafari.CreatureDB) do
                        if entry.name == mob.name and entry.baseStats then
                            baseStats = entry.baseStats
                            break
                        end
                    end
                end
                local stats = ForeverSafari.StatEngine:CalculateStats(mob.creatureType, mob.attunement or 0, mob.isElite, baseStats)
                mob.maxHP = stats.maxHP
                mob.hp = stats.maxHP
                mob.attack = stats.atk
                mob.atk = stats.atk
                mob.defense = stats.def
                mob.def = stats.def
                mob.speed = stats.spd
                mob.spd = stats.spd
                mob.rank = stats.rankData.rank
            end
            if not mob.currentHP or mob.currentHP > (mob.maxHP or 10) then
                mob.currentHP = mob.maxHP or 10
            end
            mob.hp = mob.currentHP
            mob.sig = DB:GenerateSignature(mob)
        else
            -- Ensure currentHP and maxHP are valid numbers
            if not mob.maxHP or mob.maxHP <= 0 then
                mob.maxHP = mob.hp or 10
            end
            if mob.currentHP == nil then
                mob.currentHP = mob.maxHP
            end
            mob.hp = mob.currentHP
        end
    end
end

-- =========================================================================
-- BASE64 & DNA STRING COMPANION SHARING
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
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function DB:ExportCompanionDNA(mob)
    if not mob then return "" end
    local abilitiesStr = table.concat(mob.abilities or {}, ",")
    local raw = string.format("%s~%s~%d~%d~%d~%d~%d~%d~%s~%s~%s",
        tostring(mob.name or "Wild Mob"),
        tostring(mob.nickname or mob.name or "Wild Mob"),
        tonumber(mob.level or 1),
        tonumber(mob.hp or 10),
        tonumber(mob.attack or 5),
        tonumber(mob.defense or 5),
        tonumber(mob.speed or 5),
        tonumber(mob.displayId or 903),
        tostring(mob.creatureType or "Beast"),
        abilitiesStr,
        tostring(mob.sig or "")
    )
    return "!FS:" .. DB:EncodeBase64(raw)
end

function DB:ImportCompanionDNA(dnaStr)
    if not dnaStr or not dnaStr:find("^!FS:") then return nil end
    local b64 = dnaStr:sub(5)
    local raw = DB:DecodeBase64(b64)
    if not raw or raw == "" then return nil end

    local parts = {}
    for part in string.gmatch(raw, "[^~]+") do
        table.insert(parts, part)
    end
    if #parts < 8 then return nil end

    local abilities = {}
    if parts[10] and parts[10] ~= "" then
        for ab in string.gmatch(parts[10], "[^,]+") do
            table.insert(abilities, ab)
        end
    end

    return {
        name = parts[1],
        nickname = parts[2],
        level = tonumber(parts[3]) or 1,
        hp = tonumber(parts[4]) or 10,
        maxHp = tonumber(parts[4]) or 10,
        attack = tonumber(parts[5]) or 5,
        defense = tonumber(parts[6]) or 5,
        speed = tonumber(parts[7]) or 5,
        displayId = tonumber(parts[8]) or 903,
        creatureType = parts[9] or "Beast",
        abilities = abilities,
        sig = parts[11] or ""
    }
end

function DB:GetTokens()
    return ForeverSafariDB.tokens or 0
end

function DB:AddTokens(amount, reason)
    if not amount or amount <= 0 then return end
    ForeverSafariDB.tokens = (ForeverSafariDB.tokens or 0) + amount
    ForeverSafariDB.stats.totalTokensEarned = (ForeverSafariDB.stats.totalTokensEarned or 0) + amount
    if ForeverSafari.Toast then
        ForeverSafari.Toast:ShowReward(string.format("+%d Safari Tokens!", amount), reason or "Quest Reward")
    end
    if ForeverSafari.ShopFrame and ForeverSafari.ShopFrame:IsShown() then
        ForeverSafari.ShopFrame:UpdateUI()
    end
end

function DB:SpendTokens(amount)
    if not amount or amount <= 0 then return false end
    if DB:GetTokens() >= amount then
        ForeverSafariDB.tokens = ForeverSafariDB.tokens - amount
        if ForeverSafari.ShopFrame and ForeverSafari.ShopFrame:IsShown() then
            ForeverSafari.ShopFrame:UpdateUI()
        end
        return true
    end
    return false
end

function DB:GetItemCount(itemId)
    return (ForeverSafariDB.inventory and ForeverSafariDB.inventory[itemId]) or 0
end

function DB:GetInventory()
    return ForeverSafariDB.inventory or {}
end

function DB:AddItem(itemId, count)
    count = count or 1
    if not ForeverSafariDB.inventory[itemId] then
        ForeverSafariDB.inventory[itemId] = 0
    end
    ForeverSafariDB.inventory[itemId] = ForeverSafariDB.inventory[itemId] + count
    if ForeverSafari.ShopFrame and ForeverSafari.ShopFrame:IsShown() then
        ForeverSafari.ShopFrame:UpdateUI()
    end
    if ForeverSafari.CaptureHUD and ForeverSafari.CaptureHUD:IsShown() then
        ForeverSafari.CaptureHUD:UpdateUI()
    end
    if ForeverSafari.SafariBagFrame and ForeverSafari.SafariBagFrame:IsShown() then
        ForeverSafari.SafariBagFrame:UpdateUI()
    end
end

function DB:AddInventoryItem(itemId, count)
    return self:AddItem(itemId, count)
end

function DB:RemoveItem(itemId, count)
    count = count or 1
    local current = DB:GetItemCount(itemId)
    if current >= count then
        ForeverSafariDB.inventory[itemId] = current - count
        if ForeverSafari.ShopFrame and ForeverSafari.ShopFrame:IsShown() then
            ForeverSafari.ShopFrame:UpdateUI()
        end
        if ForeverSafari.CaptureHUD and ForeverSafari.CaptureHUD:IsShown() then
            ForeverSafari.CaptureHUD:UpdateUI()
        end
        if ForeverSafari.SafariBagFrame and ForeverSafari.SafariBagFrame:IsShown() then
            ForeverSafari.SafariBagFrame:UpdateUI()
        end
        return true
    end
    return false
end

function DB:GetCollection()
    return ForeverSafariDB.collection or {}
end

function DB:GetMobById(id)
    for _, mob in ipairs(ForeverSafariDB.collection) do
        if mob.id == id then
            return mob
        end
    end
    return nil
end

-- =========================================================================
-- 🌟 ATTUNEMENT PROGRESSION & NOURISHMENT
-- =========================================================================

function DB:AddAttunement(mobId, points, reason)
    local mob = DB:GetMobById(mobId)
    if not mob then return false end

    points = math.max(1, tonumber(points) or 0)
    local prevRankData = ForeverSafari.StatEngine:GetAttunementRank(mob.attunement or 0)
    
    mob.attunement = (mob.attunement or 0) + points
    local newRankData = ForeverSafari.StatEngine:GetAttunementRank(mob.attunement)
    mob.rank = newRankData.rank

    -- Recalculate stats for the new Attunement Rank
    local stats = ForeverSafari.StatEngine:CalculateStats(mob.creatureType, mob.attunement, mob.isElite)
    mob.maxHP = stats.maxHP
    mob.hp = math.min(mob.hp or stats.maxHP, stats.maxHP)
    mob.attack = stats.atk
    mob.atk = stats.atk
    mob.defense = stats.def
    mob.def = stats.def
    mob.speed = stats.spd
    mob.spd = stats.spd

    DB:SignMob(mob)

    -- Did the companion rank up?
    if newRankData.rank > prevRankData.rank then
        PlaySound(1195) -- SOUNDKIT.IG_QUEST_LOG_COMPLETE
        local rankMsg = string.format("%s|cff00ff00[Attunement Rank Up!]|r |cffffd100%s|r achieved |cff%sRank %s: %s|r! (Unlocked %d Move Slots, %.2fx Stats)",
            ForeverSafari.Constants.PREFIX,
            mob.nickname ~= "" and mob.nickname or mob.name,
            newRankData.color,
            newRankData.roman,
            newRankData.title,
            newRankData.moveSlots,
            newRankData.statMult
        )
        DEFAULT_CHAT_FRAME:AddMessage(rankMsg)

        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowReward(
                "Attunement Rank Up!",
                string.format("%s reached Rank %s: %s!", mob.nickname ~= "" and mob.nickname or mob.name, newRankData.roman, newRankData.title)
            )
        end
    elseif reason then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffffd100%s|r gained |cff00ff00+%d Attunement|r (%s).",
            ForeverSafari.Constants.PREFIX, mob.nickname ~= "" and mob.nickname or mob.name, points, reason))
    end

    if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame:IsShown() then
        ForeverSafari.JournalFrame:UpdateUI()
    end
    return true
end

function DB:FeedCompanion(mobId, resourceItem)
    local mob = DB:GetMobById(mobId)
    if not mob then return false, "Companion not found." end

    local count = DB:GetItemCount(resourceItem)
    if count < 1 then
        return false, "You do not have any of this nourishment resource."
    end

    DB:RemoveItem(resourceItem, 1)
    DB:AddAttunement(mobId, 25, "Nourished with " .. resourceItem)
    PlaySound(844)
    return true, "Nourished companion."
end

function DB:IsReservedRareName(name)
    if not name or name == "" then return false end
    local lowerName = string.lower(string.trim(name))
    
    -- Check CreatureDB for any rare/boss species with this name
    if ForeverSafari.CreatureDB then
        for _, entry in pairs(ForeverSafari.CreatureDB) do
            if (entry.classification == 4 or entry.classification == 2 or entry.isBoss) and entry.name then
                if string.lower(entry.name) == lowerName then
                    return true, entry.name
                end
            end
        end
    end
    return false
end

function DB:SetMobNickname(mobId, newNickname)
    local mob = DB:GetMobById(mobId)
    if not mob then return false, "Companion not found." end

    newNickname = string.trim(newNickname or "")
    if newNickname == "" then
        mob.nickname = mob.name
        DB:SignMob(mob)
        return true, "Nickname reset."
    end

    -- Check if attempting to forge a reserved rare spawn name
    local isReserved, realRareName = DB:IsReservedRareName(newNickname)
    if isReserved then
        local mobRealLower = string.lower(mob.name or "")
        if mobRealLower ~= string.lower(realRareName) then
            local msg = string.format("The name '%s' belongs to a wild Rare Spawn and cannot be used!", realRareName)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffff2020[Registry Alert]|r %s", ForeverSafari.Constants.PREFIX, msg))
            return false, msg
        end
    end

    mob.nickname = newNickname
    DB:SignMob(mob)

    if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame:IsShown() then
        ForeverSafari.JournalFrame:UpdateUI()
    end
    return true, "Nickname updated."
end

function DB:AddMob(mobData)
    -- Check if this is an authentic rare spawn
    if mobData.name and DB:IsReservedRareName(mobData.name) then
        mobData.isRareSpawn = true
    end

    DB:SignMob(mobData)
    table.insert(ForeverSafariDB.collection, mobData)
    ForeverSafariDB.stats.totalCaptured = (ForeverSafariDB.stats.totalCaptured or 0) + 1

    -- Mark dex caught
    if mobData.name then
        if not ForeverSafariDB.discovered[mobData.name] then
            ForeverSafariDB.discovered[mobData.name] = { seen = 1, caught = 1, type = mobData.creatureType }
        else
            ForeverSafariDB.discovered[mobData.name].caught = (ForeverSafariDB.discovered[mobData.name].caught or 0) + 1
        end
    end

    -- Automatically unlock the mob's starting moves in training grimoire
    if mobData.abilities then
        for _, moveKey in ipairs(mobData.abilities) do
            DB:UnlockAbility(moveKey, mobData.name, true)
        end
    end

    -- Auto add to team if slot available
    if #ForeverSafariDB.team < 4 then
        table.insert(ForeverSafariDB.team, mobData.id)
    end

    if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame:IsShown() then
        ForeverSafari.JournalFrame:UpdateUI()
    end

    return mobData
end

function DB:RemoveMob(id)
    for idx, mob in ipairs(ForeverSafariDB.collection) do
        if mob.id == id then
            table.remove(ForeverSafariDB.collection, idx)
            break
        end
    end
    for idx, memberId in ipairs(ForeverSafariDB.team) do
        if memberId == id then
            table.remove(ForeverSafariDB.team, idx)
            break
        end
    end
    DB:ValidateTeam()
    if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame:IsShown() then
        ForeverSafari.JournalFrame:UpdateUI()
    end
end

function DB:AbandonMob(id)
    local mob = DB:GetMobById(id)
    if not mob then return false, "Companion not found." end
    local name = mob.nickname ~= "" and mob.nickname or mob.name

    DB:RemoveMob(id)

    local C = ForeverSafari.Constants
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffff4444[Companion Released]|r You unsealed %s's cage and released it back into the wild. Farewell!", C.PREFIX, name))

    if ForeverSafari.Toast then
        ForeverSafari.Toast:ShowAlert("Companion Released", string.format("%s was released back to the wild.", name))
    end
    PlaySound(847)

    if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame:IsShown() then
        if ForeverSafari.JournalFrame.SelectMob then
            ForeverSafari.JournalFrame:SelectMob(nil)
        end
        ForeverSafari.JournalFrame:UpdateUI()
    end
    if ForeverSafari.MinimapButton then
        ForeverSafari.MinimapButton:UpdatePosition()
    end
    return true
end

function DB:GetTeam()
    local team = {}
    for _, id in ipairs(ForeverSafariDB.team) do
        local mob = DB:GetMobById(id)
        if mob then
            table.insert(team, mob)
        end
    end
    return team
end

function DB:GetActiveMob()
    local team = DB:GetTeam()
    local slot = ForeverSafariDB.activeSlot or 1
    if slot > #team then
        slot = 1
        ForeverSafariDB.activeSlot = 1
    end
    return team[slot]
end

function DB:SetActiveSlot(slot)
    if slot >= 1 and slot <= 4 then
        ForeverSafariDB.activeSlot = slot
    end
end

function DB:SetTeamSlot(slotIndex, mobId)
    if slotIndex < 1 or slotIndex > 4 then return end
    for i, id in ipairs(ForeverSafariDB.team) do
        if id == mobId then
            table.remove(ForeverSafariDB.team, i)
            break
        end
    end
    ForeverSafariDB.team[slotIndex] = mobId
    DB:ValidateTeam()
    if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame:IsShown() then
        ForeverSafari.JournalFrame:UpdateUI()
    end
end

function DB:ValidateTeam()
    local validTeam = {}
    for _, id in ipairs(ForeverSafariDB.team or {}) do
        if DB:GetMobById(id) then
            table.insert(validTeam, id)
        end
    end
    if #validTeam == 0 and #ForeverSafariDB.collection > 0 then
        table.insert(validTeam, ForeverSafariDB.collection[1].id)
    end
    ForeverSafariDB.team = validTeam
    if ForeverSafariDB.activeSlot > #ForeverSafariDB.team then
        ForeverSafariDB.activeSlot = 1
    end
end

-- =========================================================================
-- VANILLA WOW PET ABILITY LEARNING & TRAINING SYSTEM
-- =========================================================================

-- Unlock an ability into the trainer's Grimoire (learned by observing higher level wild mobs)
function DB:UnlockAbility(moveKey, sourceMobName, silent)
    if not moveKey then return false end
    if not ForeverSafariDB.unlockedAbilities then
        ForeverSafariDB.unlockedAbilities = {}
    end

    if not ForeverSafariDB.unlockedAbilities[moveKey] then
        ForeverSafariDB.unlockedAbilities[moveKey] = true
        ForeverSafariDB.stats.totalAbilitiesLearned = (ForeverSafariDB.stats.totalAbilitiesLearned or 0) + 1

        if not silent then
            local moveData = ForeverSafari.Constants.ABILITIES[moveKey]
            local moveName = moveData and moveData.name or moveKey
            local src = sourceMobName or "Wild Mob"

            PlaySound(1195) -- SOUNDKIT.IG_QUEST_LOG_COMPLETE
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[Ability Learned!]|r You observed |cffffd100%s|r use |cff00ff99[%s]|r and learned how to teach it!",
                ForeverSafari.Constants.PREFIX, src, moveName))

            if ForeverSafari.Toast then
                ForeverSafari.Toast:ShowReward(
                    "New Ability Learned!",
                    string.format("Learned %s from %s!", moveName, src)
                )
            end
        end
        return true
    end
    return false
end

function DB:IsAbilityUnlocked(moveKey)
    return ForeverSafariDB.unlockedAbilities and ForeverSafariDB.unlockedAbilities[moveKey] == true
end

function DB:GetUnlockedAbilities()
    return ForeverSafariDB.unlockedAbilities or {}
end

-- Teach a known unlocked ability to a specific slot on a companion
function DB:SetMobAbility(mobId, slotIndex, moveKey)
    local mob = DB:GetMobById(mobId)
    if not mob or slotIndex < 1 or slotIndex > 4 then return false end

    mob.abilities = mob.abilities or {}
    
    -- Check if move is already in another slot on this mob
    for i, existingKey in ipairs(mob.abilities) do
        if existingKey == moveKey and i ~= slotIndex then
            mob.abilities[i] = mob.abilities[slotIndex] -- Swap slots
            break
        end
    end

    mob.abilities[slotIndex] = moveKey

    if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame:IsShown() then
        ForeverSafari.JournalFrame:UpdateUI()
    end
    return true
end

function DB:RecordSeenMob(name, creatureType)
    if not name then return end
    if not ForeverSafariDB.discovered[name] then
        ForeverSafariDB.discovered[name] = { seen = 1, caught = 0, type = creatureType or "Beast" }
    else
        ForeverSafariDB.discovered[name].seen = (ForeverSafariDB.discovered[name].seen or 0) + 1
    end
end

function DB:GetSetting(key)
    return ForeverSafariSettings[key]
end

function DB:SetSetting(key, value)
    ForeverSafariSettings[key] = value
end

-- =========================================================================
-- ✉️ NESINGWARY MAILBOX & QUEST DISPATCH PERSISTENCE
-- =========================================================================
function DB:IsStarterClaimed()
    if not ForeverSafariDB.mail then return false end
    return ForeverSafariDB.mail.starterClaimed == true or #DB:GetCollection() > 0
end

function DB:ClaimStarterKit()
    if not ForeverSafariDB.mail then ForeverSafariDB.mail = {} end
    if DB:IsStarterClaimed() then return false, "Starter kit already claimed." end

    local _, playerRace = UnitRace("player")
    if not playerRace or playerRace == "" then playerRace = "Human" end

    local starterConfig = {
        ["Human"]     = { name = "Mangy Wolf",       type = "Beast", displayId = 903,  family = "Canine" },
        ["Dwarf"]     = { name = "Young Black Bear", type = "Beast", displayId = 8843, family = "Bear" },
        ["Gnome"]     = { name = "Crag Boar",        type = "Beast", displayId = 138623, family = "Boar" },
        ["NightElf"]  = { name = "Young Nightsaber", type = "Beast", displayId = 11454, family = "Cat" },
        ["Orc"]       = { name = "Scorpid Worker",   type = "Beast", displayId = 2485, family = "Scorpid" },
        ["Troll"]     = { name = "Bloodtalon Raptor",type = "Beast", displayId = 1960, family = "Raptor" },
        ["Tauren"]    = { name = "Kodo Calf",        type = "Beast", displayId = 1451, family = "Kodo" },
        ["Scourge"]   = { name = "Mangy Duskbat",    type = "Beast", displayId = 9535, family = "Bat" },
        ["Undead"]    = { name = "Mangy Duskbat",    type = "Beast", displayId = 9535, family = "Bat" },
    }

    local starterData = starterConfig[playerRace] or starterConfig["Human"]
    local starterMob = ForeverSafari.StatEngine:CreateMobInstance(starterData.name, starterData.type, 1, false, starterData.displayId)
    starterMob.nickname = "Starter " .. starterData.name
    starterMob.family = starterData.family
    
    DB:AddMob(starterMob)
    DB:AddItem("copper_cage", 10)
    DB:AddItem("healing_salve", 5)
    DB:AddItem("revival_crystal", 1)
    ForeverSafariDB.mail.starterClaimed = true

    if ForeverSafari.Toast then
        ForeverSafari.Toast:ShowReward("Starter Kit Unboxed!", string.format("Received %s, 10x Nets, 5x Salves & 1x Revive Crystal", starterData.name))
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

function DB:UpdateQuestProgress(questType, increment, param)
    if not ForeverSafariDB.mail then ForeverSafariDB.mail = {} end
    if not ForeverSafariDB.mail.questProgress then ForeverSafariDB.mail.questProgress = {} end
    
    local current = ForeverSafariDB.mail.questProgress[questType] or 0
    ForeverSafariDB.mail.questProgress[questType] = current + (increment or 1)

    if ForeverSafari.SafariMailFrame and ForeverSafari.SafariMailFrame:IsShown() then
        ForeverSafari.SafariMailFrame:UpdateUI()
    end
end

function DB:ClaimQuestReward(letterId)
    local dispatch = ForeverSafari.Constants.NESINGWARY_DISPATCHES[letterId]
    if not dispatch then return false, "Invalid letter." end
    if DB:IsQuestClaimed(letterId) then return false, "Reward already claimed." end

    local progress = DB:GetQuestProgress(dispatch.questType)
    if dispatch.targetCount and progress < dispatch.targetCount then
        return false, "Quest objective not yet completed."
    end

    if not ForeverSafariDB.mail then ForeverSafariDB.mail = {} end
    if not ForeverSafariDB.mail.claimedQuests then ForeverSafariDB.mail.claimedQuests = {} end
    ForeverSafariDB.mail.claimedQuests[letterId] = true

    if dispatch.rewards then
        if dispatch.rewards.tokens and dispatch.rewards.tokens > 0 then
            DB:AddTokens(dispatch.rewards.tokens, dispatch.title)
        end
        if dispatch.rewards.items then
            for _, item in ipairs(dispatch.rewards.items) do
                DB:AddItem(item.id, item.count)
            end
        end
    end

    PlaySound(1195)
    if ForeverSafari.Toast then
        ForeverSafari.Toast:ShowReward(dispatch.title .. " Complete!", string.format("+%d Safari Tokens & Supplies", dispatch.rewards.tokens or 0))
    end
    if ForeverSafari.SafariMailFrame and ForeverSafari.SafariMailFrame:IsShown() then
        ForeverSafari.SafariMailFrame:UpdateUI()
    end
    return true
end

-- Full clean reset of player progress to new recruit state
function DB:ResetDB()
    ForeverSafariDB = {
        version = 2,
        tokens = 0,
        inventory = {
            ["copper_cage"] = 0,
            ["iron_cage"] = 0,
            ["mithril_cage"] = 0,
            ["arcanite_capsule"] = 0,
            ["az_treat"] = 0,
            ["healing_salve"] = 0,
            ["revival_crystal"] = 0,
        },
        collection = {},
        team = {},
        activeSlot = 1,
        discovered = {},
        unlockedAbilities = {
            ["Tackle"] = true,
            ["Bite"] = true,
            ["Furious_Howl"] = true,
            ["Water_Jet"] = true,
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
        },
        settings = {
            minimapAngle = 220,
        }
    }

    if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame:IsShown() then
        ForeverSafari.JournalFrame:UpdateUI()
    end
    if ForeverSafari.SafariBagFrame and ForeverSafari.SafariBagFrame:IsShown() then
        ForeverSafari.SafariBagFrame:UpdateUI()
    end
    if ForeverSafari.SafariMailFrame and ForeverSafari.SafariMailFrame:IsShown() then
        ForeverSafari.SafariMailFrame:UpdateUI()
        ForeverSafari.SafariMailFrame:UpdateTabBadge()
    end
    if ForeverSafari.MinimapButton then
        ForeverSafari.MinimapButton:UpdatePosition()
    end

    local C = ForeverSafari.Constants
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00Database reset! You are now a brand new recruit.|r Visit any town mailbox and click the |cffffd100[Safari]|r tab to unbox your welcome parcel!", C.PREFIX))
    if ForeverSafari.Toast then
        ForeverSafari.Toast:ShowReward("Safari League Reset", "New recruit profile initialized! Visit any town mailbox.")
    end
    PlaySound(844)
end

function DB:HealMob(mobId)
    local mob = DB:GetMobById(mobId)
    if not mob then return false end
    mob.maxHP = mob.maxHP or mob.hp or 10
    mob.currentHP = mob.maxHP
    mob.hp = mob.maxHP
    DB:SignMob(mob)
    if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame:IsShown() then
        ForeverSafari.JournalFrame:UpdateUI()
    end
    if ForeverSafari.CaptureHUD and ForeverSafari.CaptureHUD:IsShown() then
        ForeverSafari.CaptureHUD:UpdateUI()
    end
    return true
end

function DB:HealTeam(silent)
    local team = DB:GetTeam()
    local healedCount = 0
    for _, mob in ipairs(team) do
        if mob and DB:HealMob(mob.id) then
            healedCount = healedCount + 1
        end
    end
    if not silent then
        local C = ForeverSafari.Constants
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00Your active team has been fully healed and revived!|r", C.PREFIX))
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowReward("Team Restored!", "All active companions are fully healed & revived.")
        end
        PlaySound(895)
    end
    return healedCount
end

