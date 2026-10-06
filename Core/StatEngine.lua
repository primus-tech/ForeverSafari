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

-- Calculate 4 Core Stats (HP, ATK, DEF, SPD) using True Base Stats * Attunement Multiplier
function SE:CalculateStats(creatureType, points, isElite, baseStatsOverride)
    local rankData = SE:GetAttunementRank(points)
    local typeData = C.CREATURE_TYPES[creatureType] or C.CREATURE_TYPES["Beast"]
    local typeMult = typeData.baseStats or { hp = 1.0, atk = 1.0, def = 1.0, spd = 1.0 }
    
    local eliteMod = isElite and 1.30 or 1.00
    local attunementMod = rankData.statMult or 1.00

    local rawHP = baseStatsOverride and baseStatsOverride.hp or 65
    local rawAtk = baseStatsOverride and baseStatsOverride.atk or 18
    local rawDef = baseStatsOverride and baseStatsOverride.def or 14
    local rawSpd = baseStatsOverride and baseStatsOverride.spd or 15

    local maxHP = math.floor(rawHP * typeMult.hp * eliteMod * attunementMod)
    local atk = math.floor(rawAtk * typeMult.atk * eliteMod * attunementMod)
    local def = math.floor(rawDef * typeMult.def * eliteMod * attunementMod)
    local spd = math.floor(rawSpd * typeMult.spd * attunementMod)

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

-- Generate starting abilities restricted by initial rank capacity (Rank 1 = 1 move)
function SE:GenerateAbilities(creatureType, family)
    local abilities = {}
    
    -- Assign family-specific starter moves
    if family == "Canine" then
        table.insert(abilities, "Bite")
    elseif family == "Feline" or family == "Raptor" then
        table.insert(abilities, "Claw_Frenzy")
    elseif family == "Bear" or family == "Boar" or family == "Kodo" then
        table.insert(abilities, "Tackle")
    elseif family == "Spider" or family == "Scorpid" then
        table.insert(abilities, "Poison_Sting")
    elseif family == "Bat" or family == "Undead" then
        table.insert(abilities, "Shadow_Fang")
    elseif family == "Elemental" then
        table.insert(abilities, "Flame_Breath")
    elseif family == "Mechanical" then
        table.insert(abilities, "Cog_Strike")
    elseif family == "Aquatic" or family == "Reptile" then
        table.insert(abilities, "Water_Jet")
    else
        table.insert(abilities, "Tackle")
    end

    return abilities
end

-- Create a newly captured companion instance (Rank I: Wild / Unbroken)
function SE:CreateMobInstance(name, rawCreatureType, initialAttunement, isElite, displayId, family)
    local creatureType = C.NormalizeCreatureType(rawCreatureType, name)
    local attunement = initialAttunement or 0
    family = family or "Beast"

    -- Check if species exists in CreatureDB
    local baseStats = nil
    if ForeverSafari.CreatureDB then
        for _, entry in pairs(ForeverSafari.CreatureDB) do
            if entry.name == name and entry.baseStats then
                baseStats = entry.baseStats
                family = entry.family or family
                break
            end
        end
    end

    local stats = SE:CalculateStats(creatureType, attunement, isElite, baseStats)
    local abilities = SE:GenerateAbilities(creatureType, family)

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
