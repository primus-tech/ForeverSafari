--[[
    Forever Safari: Stat & Attunement Engine
    Replaces traditional leveling with the 5-Rank Attunement & Loyalty System.
    Calculates 4 core stats (HP, ATK, DEF, SPD), Disobedience checks,
    move capacity limits (1-4 moves), and Metamorphosis readiness.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.StatEngine = ns.StatEngine or {}

local SE = ns.StatEngine
local C = ns.Constants

-- Get Attunement Rank data from total points
function SE:GetAttunementRank(points)
    points = math.max(0, tonumber(points) or 0)
    local ranks = C.ATTUNEMENT_RANKS
    for i = #ranks, 1, -1 do
        if points >= ranks[i].minPoints then
            return ranks[i]
        end
    end
    return ranks[1]
end

-- Get Next Rank Points Target
function SE:GetRankProgress(points)
    points = math.max(0, tonumber(points) or 0)
    local currentRank = SE:GetAttunementRank(points)
    local nextRank = C.ATTUNEMENT_RANKS[currentRank.rank + 1]

    if not nextRank then
        return currentRank, points, currentRank.maxPoints, 1.0 -- Max Rank V
    end

    local pointsInCurrent = points - currentRank.minPoints
    local pointsRequired = nextRank.minPoints - currentRank.minPoints
    local fraction = math.min(1.0, math.max(0, pointsInCurrent / pointsRequired))

    return currentRank, pointsInCurrent, pointsRequired, fraction
end

-- Check Combat Disobedience
-- Returns: isDisobedient (boolean), reason (string)
function SE:CheckDisobedience(mob)
    if not mob then return false, nil end
    local points = mob.attunement or 0
    local rankData = SE:GetAttunementRank(points)

    if rankData.disobedience <= 0 then
        return false, nil
    end

    local roll = math.random()
    if roll < rankData.disobedience then
        local flavors = {
            "is ignoring your command and loafing around!",
            "growled wildly and refused to strike!",
            "panicked and slipped into a wild frenzy!",
            "is untested in battle and hesitated!",
        }
        local reason = flavors[math.random(1, #flavors)]
        return true, reason
    end

    return false, nil
end

-- Get Maximum Move Slots available based on Attunement Rank
function SE:GetMoveCapacity(mob)
    if not mob then return 1 end
    local rankData = SE:GetAttunementRank(mob.attunement or 0)
    return rankData.moveSlots or 1
end

-- Calculate 4 Core Stats (HP, ATK, DEF, SPD) using True Base Stats * Type Multiplier * Attunement Multiplier
-- Non-rares distribute 100 base points; Rares distribute 110 base points
function SE:CalculateStats(creatureType, points, isElite, baseStatsOverride)
    local rankData = SE:GetAttunementRank(points)
    local typeData = C.CREATURE_TYPES[creatureType] or C.CREATURE_TYPES["Beast"]
    local typeMult = typeData.baseStats or { hp = 1.0, atk = 1.0, def = 1.0, spd = 1.0 }
    
    local eliteMod = isElite and 1.20 or 1.00
    local attunementMod = rankData.statMult or 1.00

    -- Default budget: 100 points for normal, 110 points for elite/rare
    local defaultHP = isElite and 44 or 40
    local defaultAtk = isElite and 24 or 22
    local defaultDef = isElite and 20 or 18
    local defaultSpd = isElite and 22 or 20

    local rawHP = baseStatsOverride and baseStatsOverride.hp or defaultHP
    local rawAtk = baseStatsOverride and baseStatsOverride.atk or defaultAtk
    local rawDef = baseStatsOverride and baseStatsOverride.def or defaultDef
    local rawSpd = baseStatsOverride and baseStatsOverride.spd or defaultSpd

    local maxHP = math.max(1, math.floor(rawHP * (typeMult.hp or 1.0) * eliteMod * attunementMod))
    local atk = math.max(1, math.floor(rawAtk * (typeMult.atk or 1.0) * eliteMod * attunementMod))
    local def = math.max(1, math.floor(rawDef * (typeMult.def or 1.0) * eliteMod * attunementMod))
    local spd = math.max(1, math.floor(rawSpd * (typeMult.spd or 1.0) * attunementMod))

    return {
        maxHP = maxHP,
        hp = maxHP,
        attack = atk,
        atk = atk,
        defense = def,
        def = def,
        speed = spd,
        spd = spd,
        rankData = rankData,
    }
end

-- Generate starting abilities: all creatures start with only 2 abilities:
-- Slot 1: Their basic attack
-- Slot 2: One other ability that fits their family tree
-- Slots 3 & 4: empty (unlocked through training grimoire at higher attunement ranks)
function SE:GenerateAbilities(creatureType, family, signatureAbilities, speciesMovepool)
    local moves = {}

    -- 1. Check if species has a defined Bestiary movepool
    if speciesMovepool and type(speciesMovepool) == "table" and #speciesMovepool >= 2 then
        return { speciesMovepool[1], speciesMovepool[2] }
    end

    -- 2. If signature abilities were specified, take top 2
    if signatureAbilities and type(signatureAbilities) == "table" and #signatureAbilities >= 2 then
        return { signatureAbilities[1], signatureAbilities[2] }
    end

    -- 3. Check FamilyMovepools from MoveDB
    if ForeverSafari.FamilyMovepools and ForeverSafari.FamilyMovepools[family] then
        local pool = ForeverSafari.FamilyMovepools[family]
        if #pool >= 2 then
            return { pool[1], pool[2] }
        end
    end

    -- 4. Canonical 2-Ability Starter Templates per Family
    local basicMove = 101 -- Bite / Strike
    local familyMove = 102 -- Growl

    if family == "Canine" or family == "Wolf" or family == "Fox" then
        basicMove = 101 -- Bite
        familyMove = 104 -- Furious Howl
    elseif family == "Feline" or family == "Cat" then
        basicMove = 103 -- Claw Frenzy
        familyMove = 107 -- Prowl
    elseif family == "Raptor" then
        basicMove = 103 -- Claw Frenzy
        familyMove = 121 -- Shred
    elseif family == "Bear" then
        basicMove = 101 -- Bite
        familyMove = 102 -- Growl
    elseif family == "Boar" then
        basicMove = 108 -- Gore
        familyMove = 107 -- Boar Charge
    elseif family == "Spider" then
        basicMove = 501 -- Poison Sting
        familyMove = 502 -- Sticky Web
    elseif family == "Scorpid" then
        basicMove = 501 -- Poison Sting
        familyMove = 502 -- Hardened Shell
    elseif family == "Bat" or family == "Avian" or family == "Flying" or creatureType == "Flying" then
        basicMove = 202 -- Swoop
        familyMove = 709 -- Dive
    elseif family == "Crab" or family == "Crocolisk" or family == "Aquatic" or creatureType == "Aquatic" then
        basicMove = 401 -- Water Jet
        familyMove = 402 -- Bubble Shield
    elseif family == "Mechanical" or creatureType == "Mechanical" then
        basicMove = 601 -- Cog Strike
        familyMove = 602 -- Overclock
    elseif family == "Undead" or creatureType == "Undead" then
        basicMove = 301 -- Shadow Claw
        familyMove = 302 -- Unholy Frenzy
    elseif family == "Elemental" or creatureType == "Elemental" then
        basicMove = 801 -- Flame Blast
        familyMove = 802 -- Primal Surge
    elseif family == "Dragonkin" or creatureType == "Dragonkin" then
        basicMove = 901 -- Tail Sweep
        familyMove = 902 -- Draconic Roar
    elseif creatureType == "Humanoid" then
        basicMove = 101 -- Strike
        familyMove = 120 -- Mangle
    elseif creatureType == "Magic" then
        basicMove = 101 -- Mana Strike
        familyMove = 123 -- Faerie Fire
    end

    return { basicMove, familyMove }
end

-- Create a newly captured companion instance (Rank I: Wild / Unbroken)
function SE:CreateMobInstance(name, rawCreatureType, initialAttunement, isElite, displayId, family)
    local creatureType = C.NormalizeCreatureType(rawCreatureType, name)
    local attunement = initialAttunement or 0
    family = family or "Beast"

    -- Check if species exists in CreatureDB
    local baseStats = nil
    local sigAbilities = nil
    if ForeverSafari.CreatureDB then
        for _, entry in pairs(ForeverSafari.CreatureDB) do
            if entry.name == name then
                if entry.baseStats then baseStats = entry.baseStats end
                family = entry.family or family
                if entry.signatureAbilities then sigAbilities = entry.signatureAbilities end
                break
            end
        end
    end

    local stats = SE:CalculateStats(creatureType, attunement, isElite, baseStats)
    local abilities = SE:GenerateAbilities(creatureType, family, sigAbilities)

    local zone = GetZoneText() or "Azeroth"
    local timestamp = time()
    local uniqueId = string.format("fs_%d_%d", timestamp, math.random(1000, 9999))

    local mob = {
        id = uniqueId,
        name = name or "Wild Companion",
        nickname = "",
        creatureType = creatureType,
        family = family,
        attunement = attunement,
        rank = stats.rankData.rank,
        isElite = isElite or false,
        displayId = displayId or 903,
        
        -- 4 Core Stats
        currentHP = stats.maxHP,
        maxHP = stats.maxHP,
        hp = stats.maxHP,
        attack = stats.atk,
        atk = stats.atk,
        defense = stats.def,
        def = stats.def,
        speed = stats.spd,
        spd = stats.spd,
        
        -- Native habitat & capture location
        caughtZone = zone,
        caughtTime = timestamp,
        
        -- Active Moves Loadout (Rank 1 capacity = 1 move)
        abilities = abilities,
        
        -- Battle statistics
        wins = 0,
        losses = 0,
        disobediences = 0,
    }

    return mob
end

-- Experience / Attunement Bridge
function SE:AddExperience(mobId, points, source)
    if ForeverSafari.Database and ForeverSafari.Database.AddAttunement then
        return ForeverSafari.Database:AddAttunement(mobId, points, source or "Battle Victory")
    end
    return false
end
