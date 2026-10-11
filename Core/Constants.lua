--[[
    Forever Safari: Constants & Core System Definitions
    Contains the 9 Pet Types, 4 core stats (Health, Attack, Defense, Speed),
    closed-loop 150% type effectiveness matrix, attunement ranks, and permit gates.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Constants = ns.Constants or {}

local C = ns.Constants

-- Secret value guard helper for WoW 12.1.5 / Forever Beta architecture
local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return true end
    if issecretpassphrase and issecretpassphrase(v) then return true end
    if issecretvariable and issecretvariable(v) then return true end
    local ok = pcall(function() local _ = (v == "") end)
    if not ok then return true end
    return false
end
C.IsSecret = isSecret

-- Addon Branding
C.ADDON_NAME = "Forever Safari"
C.VERSION = "0.1a"
C.ADDON_COLOR = "ffd100"
C.PREFIX = "|cffffd100[Forever Safari v0.1a]|r "

-- The 9 Official Pet Types & Passives (4 Core Stats: HP, ATK, DEF, SPD)
C.CREATURE_TYPES = {
    ["Aquatic"] = {
        name = "Aquatic",
        color = "00bfff",
        icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
        passiveName = "Aquatic Resilience",
        passiveDesc = "Reduces the duration of damage-over-time (DoT) effects by 50%.",
        strongAgainst = "Elemental",
        weakAgainst = "Flying",
        baseStats = { hp = 1.15, atk = 1.00, def = 1.05, spd = 1.00 },
    },
    ["Beast"] = {
        name = "Beast",
        color = "ff9900",
        icon = "Interface\\Icons\\Ability_Hunter_Pet_Cat",
        passiveName = "Enrage",
        passiveDesc = "Deals 25% extra damage when dropping below 50% health.",
        strongAgainst = "Undead",
        weakAgainst = "Mechanical",
        baseStats = { hp = 1.05, atk = 1.15, def = 0.95, spd = 1.15 },
    },
    ["Dragonkin"] = {
        name = "Dragonkin",
        color = "ff3333",
        icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        passiveName = "Draconic Fury",
        passiveDesc = "Deals 50% additional damage on the next round after reducing an opponent below 50% health.",
        strongAgainst = "Magic",
        weakAgainst = "Undead",
        baseStats = { hp = 1.20, atk = 1.25, def = 1.15, spd = 0.90 },
    },
    ["Elemental"] = {
        name = "Elemental",
        color = "00e5ff",
        icon = "Interface\\Icons\\Spell_Fire_Elemental_Totem",
        passiveName = "Primal Purity",
        passiveDesc = "Ignores all negative weather and environmental debuff effects.",
        strongAgainst = "Mechanical",
        weakAgainst = "Aquatic",
        baseStats = { hp = 0.95, atk = 1.20, def = 0.95, spd = 1.05 },
    },
    ["Flying"] = {
        name = "Flying",
        color = "ffff66",
        icon = "Interface\\Icons\\Ability_Hunter_Pet_Bat",
        passiveName = "Aerial Agility",
        passiveDesc = "Gains a 50% extra speed bonus while above 50% health.",
        strongAgainst = "Aquatic",
        weakAgainst = "Magic",
        baseStats = { hp = 0.90, atk = 1.10, def = 0.85, spd = 1.45 },
    },
    ["Magic"] = {
        name = "Magic",
        color = "cc33ff",
        icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
        passiveName = "Spell Ward",
        passiveDesc = "Cannot take more than 35% of their maximum health from a single attack.",
        strongAgainst = "Flying",
        weakAgainst = "Dragonkin",
        baseStats = { hp = 1.00, atk = 1.20, def = 1.00, spd = 0.95 },
    },
    ["Mechanical"] = {
        name = "Mechanical",
        color = "cccccc",
        icon = "Interface\\Icons\\INV_Misc_EngGizmos_17",
        passiveName = "Fail-Safe Reboot",
        passiveDesc = "Revives once per battle with 20% health after being defeated.",
        strongAgainst = "Beast",
        weakAgainst = "Elemental",
        baseStats = { hp = 1.10, atk = 1.05, def = 1.25, spd = 0.85 },
    },
    ["Undead"] = {
        name = "Undead",
        color = "9966cc",
        icon = "Interface\\Icons\\Spell_Shadow_DeadofNight",
        passiveName = "Unholy Immortality",
        passiveDesc = "Returns to life as immortal for one round after being defeated (dealing 25% less damage during that round).",
        strongAgainst = "Dragonkin",
        weakAgainst = "Beast",
        baseStats = { hp = 1.20, atk = 1.00, def = 0.90, spd = 0.85 },
    }
}

-- =========================================================================
-- 🌟 ATTUNEMENT & LOYALTY PROGRESSION SYSTEM (Ranks I to V)
-- =========================================================================
C.ATTUNEMENT_RANKS = {
    [1] = {
        rank = 1,
        roman = "I",
        title = "Wild / Unbroken",
        minPoints = 0,
        maxPoints = 250,
        disobedience = 0.25,
        moveSlots = 1,
        statMult = 0.85,
        critBonus = 0.00,
        canEvolve = false,
        color = "aaaaaa",
        desc = "25% Disobedience Chance. Slips into wild turns (random move / loafs). 1 Active Move. 0.85x Base Stats.",
    },
    [2] = {
        rank = 2,
        roman = "II",
        title = "Tolerant",
        minPoints = 250,
        maxPoints = 600,
        disobedience = 0.15,
        moveSlots = 2,
        statMult = 0.95,
        critBonus = 0.00,
        canEvolve = false,
        color = "00ff00",
        desc = "15% Disobedience Chance. Basic commands execute cleanly. 2 Active Moves. 0.95x Base Stats.",
    },
    [3] = {
        rank = 3,
        roman = "III",
        title = "Trusting",
        minPoints = 600,
        maxPoints = 1050,
        disobedience = 0.05,
        moveSlots = 3,
        statMult = 1.00,
        critBonus = 0.00,
        canEvolve = false,
        color = "00bfff",
        desc = "5% Disobedience Chance. Reliable in combat. 3 Active Moves. 1.00x Base Stats (True Base).",
    },
    [4] = {
        rank = 4,
        roman = "IV",
        title = "Devoted",
        minPoints = 1050,
        maxPoints = 1600,
        disobedience = 0.00,
        moveSlots = 4,
        statMult = 1.05,
        critBonus = 0.05,
        canEvolve = false,
        color = "a335ee",
        desc = "0% Disobedience. 5% Crit Strike boost on family abilities. 4 Active Moves. 1.05x Base Stats.",
    },
    [5] = {
        rank = 5,
        roman = "V",
        title = "Bestial Symbiosis",
        minPoints = 1600,
        maxPoints = 1600,
        disobedience = 0.00,
        moveSlots = 4,
        statMult = 1.15,
        critBonus = 0.05,
        canEvolve = true,
        color = "ff8000",
        desc = "0% Disobedience. Can safely endure Metamorphosis Catalysts! 4 Moves + Innate Perk. 1.15x Base Stats.",
    },
}

-- 8-Type Closed-Loop Effectiveness Matrix
C.TYPE_ADVANTAGES = {
    ["Aquatic"]     = { ["Elemental"] = 1.5, ["Flying"] = 0.67 },
    ["Beast"]       = { ["Undead"] = 1.5,    ["Mechanical"] = 0.67 },
    ["Dragonkin"]   = { ["Magic"] = 1.5,     ["Undead"] = 0.67 },
    ["Elemental"]   = { ["Mechanical"] = 1.5,["Aquatic"] = 0.67 },
    ["Flying"]      = { ["Aquatic"] = 1.5,   ["Magic"] = 0.67 },
    ["Magic"]       = { ["Flying"] = 1.5,    ["Dragonkin"] = 0.67 },
    ["Mechanical"]  = { ["Beast"] = 1.5,     ["Elemental"] = 0.67 },
    ["Undead"]      = { ["Dragonkin"] = 1.5,  ["Beast"] = 0.67 },
}

-- Normalize WoW creature types into the 9 types
function C.NormalizeCreatureType(rawType, mobName)
    if isSecret(rawType) or not rawType or type(rawType) ~= "string" or rawType == "" then rawType = "Beast" end
    if isSecret(mobName) or not mobName or type(mobName) ~= "string" then mobName = "" end
    local clean = string.lower(rawType)

    if clean == "aquatic" or clean == "water" then
        return "Aquatic"
    elseif clean == "beast" or clean == "critter" or clean == "animal" then
        if mobName and mobName ~= "" then
            local mobLower = string.lower(mobName)
            if (string.find(mobLower, "bat") or string.find(mobLower, "owl") or string.find(mobLower, "bird") or string.find(mobLower, "eagle") or string.find(mobLower, "hawk") or string.find(mobLower, "wasp") or string.find(mobLower, "buzzard") or string.find(mobLower, "strigid")) then
                return "Flying"
            elseif (string.find(mobLower, "crab") or string.find(mobLower, "fish") or string.find(mobLower, "turtle") or string.find(mobLower, "murloc") or string.find(mobLower, "clam") or string.find(mobLower, "crocolisk")) then
                return "Aquatic"
            end
        end
        return "Beast"
    elseif clean == "dragonkin" or clean == "dragon" then
        return "Dragonkin"
    elseif clean == "elemental" then
        return "Elemental"
    elseif clean == "flying" then
        return "Flying"
    elseif clean == "humanoid" or clean == "giant" then
        return "Humanoid"
    elseif clean == "magic" or clean == "demon" or clean == "aberration" then
        return "Magic"
    elseif clean == "mechanical" then
        return "Mechanical"
    elseif clean == "undead" then
        return "Undead"
    end

    return "Beast"
end

-- Default 3D Model Display IDs for the 9 Types and Iconic Mobs (CreatureDisplayInfo IDs)
C.DEFAULT_DISPLAY_IDS = {
    ["Aquatic"]     = 1153, -- Crawler / Sea Crab
    ["Beast"]       = 903,  -- Elwynn Timber Wolf / Forest Wolf
    ["Dragonkin"]   = 300,  -- Black Whelp
    ["Elemental"]   = 114,  -- Fire Elemental
    ["Flying"]      = 4184, -- Great Owl
    ["Humanoid"]    = 180,  -- Defias Bandit
    ["Magic"]       = 4449, -- Imp / Nether Beast
    ["Mechanical"]  = 387,  -- Harvest Golem
    ["Undead"]      = 239,  -- Skeleton Warrior
}

function C.GetDefaultDisplayId(creatureType, mobName)
    local cType = C.NormalizeCreatureType(creatureType, mobName)
    if mobName and not isSecret(mobName) and type(mobName) == "string" and mobName ~= "" then
        local nameLower = string.lower(mobName)
        if string.find(nameLower, "murloc") then return 1042 end
        if string.find(nameLower, "crab") or string.find(nameLower, "crawler") then return 1153 end
        if string.find(nameLower, "turtle") or string.find(nameLower, "snapjaw") then return 2470 end
        if string.find(nameLower, "wolf") or string.find(nameLower, "worg") or string.find(nameLower, "coyote") or string.find(nameLower, "timber") or string.find(nameLower, "gray") or string.find(nameLower, "grey") then return 903 end
        if string.find(nameLower, "cat") or string.find(nameLower, "tiger") or string.find(nameLower, "lion") or string.find(nameLower, "panther") or string.find(nameLower, "saber") then return 775 end
        if string.find(nameLower, "raptor") then return 1064 end
        if string.find(nameLower, "bear") or string.find(nameLower, "grizzly") then return 742 end
        if string.find(nameLower, "scorpid") or string.find(nameLower, "scorpion") then return 714 end
        if string.find(nameLower, "spider") then return 382 end
        if string.find(nameLower, "dragon") or string.find(nameLower, "whelp") or string.find(nameLower, "drake") then return 300 end
        if string.find(nameLower, "bat") then return 1500 end
        if string.find(nameLower, "owl") or string.find(nameLower, "bird") or string.find(nameLower, "eagle") or string.find(nameLower, "vulture") then return 4184 end
        if string.find(nameLower, "water") then return 891 end
        if string.find(nameLower, "fire") or string.find(nameLower, "flame") then return 114 end
        if string.find(nameLower, "earth") or string.find(nameLower, "rock") or string.find(nameLower, "stone") then return 892 end
        if string.find(nameLower, "air") or string.find(nameLower, "wind") or string.find(nameLower, "tempest") then return 115 end
        if string.find(nameLower, "golem") or string.find(nameLower, "robot") or string.find(nameLower, "mech") or string.find(nameLower, "harvest") then return 387 end
        if string.find(nameLower, "skeleton") or string.find(nameLower, "skeletal") or string.find(nameLower, "bone") then return 239 end
        if string.find(nameLower, "ghoul") then return 376 end
        if string.find(nameLower, "zombie") or string.find(nameLower, "corpse") then return 384 end
        if string.find(nameLower, "imp") or string.find(nameLower, "demon") or string.find(nameLower, "fiend") then return 4449 end
        if string.find(nameLower, "defias") or string.find(nameLower, "bandit") or string.find(nameLower, "rogue") or string.find(nameLower, "human") then return 180 end
        if string.find(nameLower, "boar") or string.find(nameLower, "swine") or string.find(nameLower, "pig") then return 485 end
        if string.find(nameLower, "croc") or string.find(nameLower, "alligator") then return 1086 end
        if string.find(nameLower, "gorilla") or string.find(nameLower, "ape") then return 1067 end
        if string.find(nameLower, "tallstrider") or string.find(nameLower, "strider") then return 1068 end
        if string.find(nameLower, "wasp") or string.find(nameLower, "hornet") or string.find(nameLower, "bee") then return 1440 end
        if string.find(nameLower, "stag") or string.find(nameLower, "deer") then return 667 end
        if string.find(nameLower, "serpent") or string.find(nameLower, "snake") or string.find(nameLower, "viper") or string.find(nameLower, "cobra") then return 1039 end
    end
    return C.DEFAULT_DISPLAY_IDS[cType] or 181
end

-- Eligible Wild Creature Types for Field Snaring (Humanoids are strictly prohibited)
C.ELIGIBLE_CAPTURE_TYPES = {
    ["Aquatic"] = true,
    ["Beast"] = true,
    ["Critter"] = true,
    ["Dragonkin"] = true,
    ["Elemental"] = true,
    ["Flying"] = true,
    ["Humanoid"] = false,
    ["Magical"] = true,
    ["Mechanical"] = true,
    ["Undead"] = true,
}

-- Creature Types Locked behind Nesingwary Research Permits & Quests
C.LOCKED_CREATURE_TYPES = {
    ["Mechanical"] = true,
    ["Elemental"]  = true,
    ["Undead"]     = true,
    ["Dragonkin"]  = true,
}

-- Default Unlocked Creature Types for New Recruits
C.DEFAULT_UNLOCKED_TYPES = {
    ["Beast"]   = true,
    ["Flying"]  = true,
    ["Aquatic"] = true,
    ["Critter"] = true,
    ["Magic"]   = true,
}

-- Nesingwary Research Permits Metadata
C.TYPE_RESEARCH_PERMITS = {
    ["Mechanical"] = {
        name = "Clockwork Engineering Permit",
        icon = "Interface\\Icons\\INV_Gizmo_02",
        desc = "Authorizes stalking, containment, and battle tagging of wild mechanical constructs.",
    },
    ["Elemental"] = {
        name = "Primal Attunement Permit",
        icon = "Interface\\Icons\\Spell_Fire_Elemental_Devastation",
        desc = "Authorizes field research and containment of raw elemental forces.",
    },
    ["Undead"] = {
        name = "Necrotic Containment Permit",
        icon = "Interface\\Icons\\Spell_Shadow_DeadofNight",
        desc = "Authorizes containment of undead and reanimated fauna.",
    },
    ["Dragonkin"] = {
        name = "Draconic Sanctuary Permit",
        icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        desc = "Authorizes tracking, research, and capture of dragonkin whelps and drakes.",
    },
}
