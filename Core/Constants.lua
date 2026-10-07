--[[
    Forever Safari: Constants & Data Definitions
    Contains the 9 Pet Types, 4 core stats (Health, Attack, Defense, Speed),
    closed-loop 150% type effectiveness matrix, shop items, nets, and abilities database
    with turn cooldowns and battle usage limits.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Constants = ns.Constants or {}

local C = ns.Constants

-- Secret value guard helper for WoW 12.1.5 / Forever Beta architecture
local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then
        return true
    end
    return false
end
C.IsSecret = isSecret

-- Addon Branding
C.ADDON_NAME = "Forever Safari"
C.ADDON_COLOR = "ffd100"
C.PREFIX = "|cffffd100[Forever Safari]|r "

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
        weakAgainst = "Humanoid",
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
    ["Humanoid"] = {
        name = "Humanoid",
        color = "3399ff",
        icon = "Interface\\Icons\\Achievement_Character_Human_Male",
        passiveName = "Martial Recovery",
        passiveDesc = "Recovers 4% of their maximum health every round they deal damage.",
        strongAgainst = "Dragonkin",
        weakAgainst = "Undead",
        baseStats = { hp = 1.05, atk = 1.05, def = 1.10, spd = 1.00 },
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
        strongAgainst = "Humanoid",
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

-- =========================================================================
-- 🎒 VIRTUAL SAFARI BAG ITEMS & METADATA
-- =========================================================================
C.SAFARI_ITEMS = {
    -- 🕸️ Safari Nets
    ["copper_cage"] = {
        name = "Copper Safari Net",
        category = "Safari Net",
        icon = "INV_Misc_Net_01",
        quality = 1,
        color = "ffffff",
        desc = "Standard woven net used to snare low-level wild creatures in the field (1.0x Rate).",
        useText = "Right-Click to equip as active capture net.",
    },
    ["iron_cage"] = {
        name = "Iron Safari Net",
        category = "Safari Net",
        icon = "INV_Misc_Net_02",
        quality = 2,
        color = "1eff00",
        desc = "Reinforced chain netting with improved capture hold (1.5x Rate).",
        useText = "Right-Click to equip as active capture net.",
    },
    ["mithril_cage"] = {
        name = "Mithril Safari Net",
        category = "Safari Net",
        icon = "INV_Misc_Net_03",
        quality = 3,
        color = "0070dd",
        desc = "Heavy-gauge woven mithril net designed for fast and elusive beasts (2.0x Rate).",
        useText = "Right-Click to equip as active capture net.",
    },
    ["arcanite_capsule"] = {
        name = "Arcanite Safari Capsule",
        category = "Safari Net",
        icon = "INV_Misc_EngGizmos_17",
        quality = 4,
        color = "a335ee",
        desc = "Master-crafted engineering capture sphere. Guaranteed 100% capture rate on any non-boss wild fauna.",
        useText = "Right-Click to equip as active capture net.",
    },

    -- 🍖 Consumables & Balms
    ["az_treat"] = {
        name = "Safari Treat",
        category = "Consumable",
        icon = "INV_Misc_Food_54",
        quality = 2,
        color = "1eff00",
        desc = "A delicious honey-cured snack. Feed to your active companion to award +50 Attunement loyalty.",
        useText = "Right-Click to feed active companion (+50 Attunement).",
    },
    ["az_feast"] = {
        name = "Grand Safari Feast",
        category = "Consumable",
        icon = "INV_Misc_Food_54",
        quality = 3,
        color = "0070dd",
        desc = "A luxurious gourmet feast for your safari companions. Feeds all active team companions for +100 Attunement loyalty each.",
        useText = "Right-Click to feast entire active team (+100 Attunement).",
    },
    ["healing_salve"] = {
        name = "Safari Healing Salve",
        category = "Consumable",
        icon = "INV_Potion_24",
        quality = 1,
        color = "ffffff",
        desc = "Herbal soothing balm that restores 100% HP to your active companion.",
        useText = "Right-Click to heal active companion.",
    },
    ["revival_crystal"] = {
        name = "Revival Crystal",
        category = "Consumable",
        icon = "INV_Misc_Gem_Emerald_01",
        quality = 3,
        color = "0070dd",
        desc = "Energized primal crystal that revives a fainted companion with 50% health.",
        useText = "Right-Click to revive active companion.",
    },

    -- 🧬 Evolution Catalysts
    ["catalyst_1015"] = {
        name = "Shadowfang Essence",
        category = "Evolution Catalyst",
        icon = "Spell_Shadow_GatherShadows",
        quality = 4,
        color = "a335ee",
        desc = "Dark shadow essence from Shadowfang Keep. Triggers 3D pedestal Metamorphosis for Rank V Canines (evolves into Slavering Worg).",
        useText = "Right-Click to begin Metamorphosis.",
    },
    ["catalyst_1016"] = {
        name = "Hydra Bile",
        category = "Evolution Catalyst",
        icon = "Spell_Nature_AbolishPoison",
        quality = 4,
        color = "a335ee",
        desc = "Primordial acid from Aku'mai in BFD. Triggers 3D pedestal Metamorphosis for Rank V Reptiles (evolves into Ancient Snapjaw).",
        useText = "Right-Click to begin Metamorphosis.",
    },
    ["catalyst_1017"] = {
        name = "Venomous Gland",
        category = "Evolution Catalyst",
        icon = "Spell_Nature_CorrosiveBreath",
        quality = 4,
        color = "a335ee",
        desc = "Deadly venom sac from Razorfen Kraul. Triggers 3D pedestal Metamorphosis for Rank V Scorpids (evolves into Dreadscorpid).",
        useText = "Right-Click to begin Metamorphosis.",
    },
    ["catalyst_1018"] = {
        name = "Overclocked Core",
        category = "Evolution Catalyst",
        icon = "Trade_Engineering",
        quality = 4,
        color = "a335ee",
        desc = "Experimental gyro-core from Deadmines. Triggers 3D pedestal Metamorphosis for Rank V Mechanicals (evolves into War Golem).",
        useText = "Right-Click to begin Metamorphosis.",
    },
    ["catalyst_1019"] = {
        name = "Volcanic Core",
        category = "Evolution Catalyst",
        icon = "Spell_Fire_LavaSpawn",
        quality = 4,
        color = "a335ee",
        desc = "Molten core from Wailing Caverns. Triggers 3D pedestal Metamorphosis for Rank V Elementals (evolves into Blazing Invoker).",
        useText = "Right-Click to begin Metamorphosis.",
    },

    -- 🥩 Family Nourishment Diets (Harvested from downed wild animals)
    ["food_canine"]       = { name = "Wolf Meat & Sinew",      category = "Family Nourishment", icon = "INV_Misc_Food_14", quality = 2, color = "1eff00", family = "Canine", desc = "Fresh canine meat. Right-Click to feed a Canine companion for +25 Attunement." },
    ["food_feline"]       = { name = "Fresh Feline Flank",     category = "Family Nourishment", icon = "INV_Misc_Food_54", quality = 2, color = "1eff00", family = "Feline", desc = "Tender feline cut. Right-Click to feed a Feline companion for +25 Attunement." },
    ["food_bear"]         = { name = "Honeyed Bear Ribs",      category = "Family Nourishment", icon = "INV_Misc_Food_18", quality = 2, color = "1eff00", family = "Bear", desc = "Hearty bear ribs. Right-Click to feed a Bear companion for +25 Attunement." },
    ["food_boar"]         = { name = "Boar Chump Meat",        category = "Family Nourishment", icon = "INV_Misc_Food_53", quality = 2, color = "1eff00", family = "Boar", desc = "Succulent boar meat. Right-Click to feed a Boar companion for +25 Attunement." },
    ["food_spider"]       = { name = "Concentrated Venom Sac", category = "Family Nourishment", icon = "INV_Misc_MonsterSpiderVenom_01", quality = 2, color = "1eff00", family = "Spider", desc = "Venom extract. Right-Click to feed a Spider companion for +25 Attunement." },
    ["food_scorpid"]      = { name = "Scorpid Tail Gland",     category = "Family Nourishment", icon = "INV_Misc_MonsterTail_03", quality = 2, color = "1eff00", family = "Scorpid", desc = "Potent tail gland. Right-Click to feed a Scorpid companion for +25 Attunement." },
    ["food_raptor"]       = { name = "Raptor Flesh",           category = "Family Nourishment", icon = "INV_Misc_Food_70", quality = 2, color = "1eff00", family = "Raptor", desc = "Lean prime meat. Right-Click to feed a Raptor companion for +25 Attunement." },
    ["food_kodo"]         = { name = "Tough Kodo Meat",        category = "Family Nourishment", icon = "INV_Misc_Food_64", quality = 2, color = "1eff00", family = "Kodo", desc = "Thick kodo flank. Right-Click to feed a Kodo companion for +25 Attunement." },
    ["food_bat"]          = { name = "Vampiric Blood Vessel",  category = "Family Nourishment", icon = "INV_Misc_MonsterBlood_01", quality = 2, color = "1eff00", family = "Bat", desc = "Rich blood vessel. Right-Click to feed a Bat companion for +25 Attunement." },
    ["food_elemental"]    = { name = "Primal Elemental Core",  category = "Family Nourishment", icon = "Spell_Fire_LavaSpawn", quality = 2, color = "1eff00", family = "Elemental", desc = "Crackling core. Right-Click to feed an Elemental companion for +25 Attunement." },
    ["food_mechanical"]   = { name = "Spare Clockwork Gears",  category = "Family Nourishment", icon = "Trade_Engineering", quality = 2, color = "1eff00", family = "Mechanical", desc = "Polished gears. Right-Click to feed a Mechanical companion for +25 Attunement." },
    ["food_undead"]       = { name = "Necrotic Bone Dust",     category = "Family Nourishment", icon = "INV_Misc_Bone_01", quality = 2, color = "1eff00", family = "Undead", desc = "Necrotic dust. Right-Click to feed an Undead companion for +25 Attunement." },
    ["food_dragonkin"]    = { name = "Whelp Dragon Scale",     category = "Family Nourishment", icon = "INV_Misc_MonsterScales_01", quality = 2, color = "1eff00", family = "Dragonkin", desc = "Iridescent scale. Right-Click to feed a Dragonkin companion for +25 Attunement." },
    ["food_aquatic"]      = { name = "Saltwater Crustacean",   category = "Family Nourishment", icon = "INV_Misc_Fish_02", quality = 2, color = "1eff00", family = "Aquatic", desc = "Fresh crab meat. Right-Click to feed an Aquatic companion for +25 Attunement." },
    ["food_reptile"]      = { name = "Snapjaw Turtle Meat",    category = "Family Nourishment", icon = "INV_Misc_Fish_12", quality = 2, color = "1eff00", family = "Reptile", desc = "Tough turtle meat. Right-Click to feed a Reptile companion for +25 Attunement." },
    ["food_avian"]        = { name = "Crisp Bird Wing",        category = "Family Nourishment", icon = "INV_Misc_Food_17", quality = 2, color = "1eff00", family = "Avian", desc = "Plump bird wing. Right-Click to feed an Avian companion for +25 Attunement." },
    ["food_wind serpent"] = { name = "Serpent Scale Essence",  category = "Family Nourishment", icon = "INV_Misc_MonsterScales_02", quality = 2, color = "1eff00", family = "Wind Serpent", desc = "Sparkling essence. Right-Click to feed a Wind Serpent for +25 Attunement." },
}
C.ITEMS = C.SAFARI_ITEMS

-- 🥩 Family Nourishment Loot Tables (Harvested from wild encounters)
C.FAMILY_NOURISHMENT = {
    ["Canine"]       = { item = "Wolf Meat & Sinew",      yield = "Canine",       key = "food_canine" },
    ["Wolf"]         = { item = "Wolf Meat & Sinew",      yield = "Canine",       key = "food_canine" },
    ["Worg"]         = { item = "Wolf Meat & Sinew",      yield = "Canine",       key = "food_canine" },
    ["Feline"]       = { item = "Fresh Feline Flank",     yield = "Feline",       key = "food_feline" },
    ["Cat"]          = { item = "Fresh Feline Flank",     yield = "Feline",       key = "food_feline" },
    ["Tiger"]        = { item = "Fresh Feline Flank",     yield = "Feline",       key = "food_feline" },
    ["Lion"]         = { item = "Fresh Feline Flank",     yield = "Feline",       key = "food_feline" },
    ["Bear"]         = { item = "Honeyed Bear Ribs",      yield = "Bear",         key = "food_bear" },
    ["Boar"]         = { item = "Boar Chump Meat",        yield = "Boar",         key = "food_boar" },
    ["Spider"]       = { item = "Concentrated Venom Sac", yield = "Spider",       key = "food_spider" },
    ["Scorpid"]      = { item = "Scorpid Tail Gland",     yield = "Scorpid",      key = "food_scorpid" },
    ["Raptor"]       = { item = "Raptor Flesh",           yield = "Raptor",       key = "food_raptor" },
    ["Kodo"]         = { item = "Tough Kodo Meat",        yield = "Kodo",         key = "food_kodo" },
    ["Bat"]          = { item = "Vampiric Blood Vessel",  yield = "Bat",          key = "food_bat" },
    ["Elemental"]    = { item = "Primal Elemental Core",  yield = "Elemental",    key = "food_elemental" },
    ["Mechanical"]   = { item = "Spare Clockwork Gears",  yield = "Mechanical",   key = "food_mechanical" },
    ["Undead"]       = { item = "Necrotic Bone Dust",     yield = "Undead",       key = "food_undead" },
    ["Dragonkin"]    = { item = "Whelp Dragon Scale",     yield = "Dragonkin",    key = "food_dragonkin" },
    ["Aquatic"]      = { item = "Saltwater Crustacean",   yield = "Aquatic",      key = "food_aquatic" },
    ["Crab"]         = { item = "Saltwater Crustacean",   yield = "Aquatic",      key = "food_aquatic" },
    ["Crocolisk"]    = { item = "Saltwater Crustacean",   yield = "Aquatic",      key = "food_aquatic" },
    ["Reptile"]      = { item = "Snapjaw Turtle Meat",    yield = "Reptile",      key = "food_reptile" },
    ["Turtle"]       = { item = "Snapjaw Turtle Meat",    yield = "Reptile",      key = "food_reptile" },
    ["Avian"]        = { item = "Crisp Bird Wing",        yield = "Avian",        key = "food_avian" },
    ["Bird"]         = { item = "Crisp Bird Wing",        yield = "Avian",        key = "food_avian" },
    ["Flying"]       = { item = "Crisp Bird Wing",        yield = "Avian",        key = "food_avian" },
    ["Wind Serpent"] = { item = "Serpent Scale Essence",  yield = "Wind Serpent", key = "food_wind serpent" },
    ["Beast"]        = { item = "Wolf Meat & Sinew",      yield = "Canine",       key = "food_canine" },
}

-- 9-Type Closed-Loop Effectiveness Matrix
C.TYPE_ADVANTAGES = {
    ["Aquatic"]     = { ["Elemental"] = 1.5, ["Flying"] = 0.67 },
    ["Beast"]       = { ["Undead"] = 1.5,    ["Mechanical"] = 0.67 },
    ["Dragonkin"]   = { ["Magic"] = 1.5,     ["Humanoid"] = 0.67 },
    ["Elemental"]   = { ["Mechanical"] = 1.5,["Aquatic"] = 0.67 },
    ["Flying"]      = { ["Aquatic"] = 1.5,   ["Magic"] = 0.67 },
    ["Humanoid"]    = { ["Dragonkin"] = 1.5, ["Undead"] = 0.67 },
    ["Magic"]       = { ["Flying"] = 1.5,    ["Dragonkin"] = 0.67 },
    ["Mechanical"]  = { ["Beast"] = 1.5,     ["Elemental"] = 0.67 },
    ["Undead"]      = { ["Humanoid"] = 1.5,  ["Beast"] = 0.67 },
}

-- Normalize WoW creature types into the 9 types
function C.NormalizeCreatureType(rawType, mobName)
    if not rawType or rawType == "" then rawType = "Beast" end
    local clean = string.lower(rawType)

    if clean == "aquatic" or clean == "water" then
        return "Aquatic"
    elseif clean == "beast" or clean == "critter" or clean == "animal" then
        if mobName and (string.find(string.lower(mobName), "bat") or string.find(string.lower(mobName), "owl") or string.find(string.lower(mobName), "bird") or string.find(string.lower(mobName), "eagle") or string.find(string.lower(mobName), "hawk") or string.find(string.lower(mobName), "wasp") or string.find(string.lower(mobName), "buzzard") or string.find(string.lower(mobName), "strigid")) then
            return "Flying"
        elseif mobName and (string.find(string.lower(mobName), "crab") or string.find(string.lower(mobName), "fish") or string.find(string.lower(mobName), "turtle") or string.find(string.lower(mobName), "murloc") or string.find(string.lower(mobName), "clam") or string.find(string.lower(mobName), "crocolisk")) then
            return "Aquatic"
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
    if mobName then
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

-- Capture Cages Definition (Field Research Snares)
C.CAGES = {
    ["copper_cage"] = {
        id = "copper_cage",
        name = "Copper Safari Net",
        price = 5,
        catchPower = 0.35,
        rateMultiplier = 1.0,
        channelTime = 5.0,
        quality = 1,
        color = "ffffff",
        icon = "Interface\\Icons\\INV_Misc_Net_01",
        description = "Standard woven field research snare. Effective for basic wild tagging (35% Base Catch).",
    },
    ["iron_cage"] = {
        id = "iron_cage",
        name = "Reinforced Iron Net",
        price = 15,
        catchPower = 0.55,
        rateMultiplier = 1.5,
        channelTime = 4.5,
        quality = 2,
        color = "1eff00",
        icon = "Interface\\Icons\\INV_Misc_Net_02",
        description = "Reinforced weighted netting with improved hold (55% Base Catch).",
    },
    ["mithril_cage"] = {
        id = "mithril_cage",
        name = "Mithril Safari Net",
        price = 35,
        catchPower = 0.75,
        rateMultiplier = 2.0,
        channelTime = 4.0,
        quality = 3,
        color = "0070dd",
        icon = "Interface\\Icons\\INV_Misc_Net_03",
        description = "Heavy-gauge woven mithril net designed for fast and elusive beasts (75% Base Catch).",
    },
    ["arcanite_capsule"] = {
        id = "arcanite_capsule",
        name = "Arcanite Safari Capsule",
        price = 80,
        catchPower = 0.98,
        rateMultiplier = 3.2,
        channelTime = 3.0,
        quality = 4,
        color = "a335ee",
        icon = "Interface\\Icons\\INV_Misc_EngGizmos_17",
        description = "Masterwork gnomish stasis capsule. Near guaranteed capture on any wild quarry (98% Base Catch).",
    }
}

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

-- Consumables & Supplies
C.SHOP_ITEMS = {
    ["az_treat"] = {
        id = "az_treat",
        name = "Safari Treat",
        price = 8,
        quality = 2,
        color = "1eff00",
        icon = "Interface\\Icons\\INV_Misc_Food_54",
        description = "A delicious honey-cured snack beloved by safari companions. Awards +50 Attunement loyalty.",
        effect = { type = "attunement", value = 50 }
    },
    ["az_feast"] = {
        id = "az_feast",
        name = "Grand Safari Feast",
        price = 25,
        quality = 3,
        color = "0070dd",
        icon = "Interface\\Icons\\INV_Misc_Food_54",
        description = "A luxurious gourmet feast for your companion. Grants +500 Experience Points instantly.",
        effect = { type = "xp", value = 500 }
    },
    ["healing_salve"] = {
        id = "healing_salve",
        name = "Herbal Healing Salve",
        price = 4,
        quality = 1,
        color = "ffffff",
        icon = "Interface\\Icons\\INV_Potion_21",
        description = "Soothing poultice made from Peacebloom. Restores 50% max HP to an injured companion.",
        effect = { type = "heal", value = 0.50 }
    },
    ["revival_crystal"] = {
        id = "revival_crystal",
        name = "Spark of Life Crystal",
        price = 20,
        quality = 3,
        color = "0070dd",
        icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_02",
        description = "A resonant shard of rejuvenation. Revives a fainted companion back to full health.",
        effect = { type = "revive", value = 1.0 }
    }
}

-- =========================================================================
-- ✉️ NESINGWARY JUNIOR SAFARI LEAGUE MAILBOX DISPATCHES & BOUNTIES
-- =========================================================================
C.NESINGWARY_DISPATCHES = {
    [1] = {
        id = 1,
        key = "welcome_dispatch",
        title = "Welcome to the Safari League!",
        sender = "Hemet Nesingwary Sr.",
        location = "Expedition HQ",
        date = "Official Commission",
        icon = "Interface\\Icons\\INV_Box_01",
        isStarter = true,
        summary = "Unbox your racial starter companion, 10 Copper Safari Nets, 5 Healing Salves, and 1 Revival Crystal.",
        body = "Greetings, recruit!\n\nIf you are reading this dispatch, your petition to join the Junior Safari League has been officially accepted by the Nesingwary Expedition!\n\nWhether you hail from the dense glades of Teldrassil, the red canyons of Durotar, or the snowpeaks of Dun Morogh, Azeroth is teeming with majestic wildlife waiting to be researched, bonded with, and tested in honorable battle.\n\nAttached to this parcel is your Caged Starter Companion native to your homeland, along with ten field research nets, five soothing healing salves, and an emergency revival crystal. Treat your companion well, nourish it with native diets, and protect the wild balance!\n\nGood hunting,\n— Hemet Nesingwary Sr.",
        rewards = {
            tokens = 0,
            items = {
                { id = "copper_cage", count = 10 },
                { id = "healing_salve", count = 5 },
                { id = "revival_crystal", count = 1 },
            },
        }
    },
    [2] = {
        id = 2,
        key = "field_stalking_101",
        title = "Dispatch #2: Field Stalking 101",
        sender = "Hemet Nesingwary Sr.",
        location = "Stranglethorn Vale",
        date = "Field Directive",
        icon = "Interface\\Icons\\INV_Misc_Net_01",
        questType = "CAPTURE_TOTAL",
        targetCount = 3,
        summary = "Stalk and snare 3 wild beasts in the open world.",
        body = "Recruit,\n\nTrue naturalists do not obliterate wildlife—we stalk with care! Maintain proper distance (15 to 28 yards), hold your line of sight, and channel your field research snare without disturbing the ecosystem.\n\nStalk and successfully catalog three wild creatures in your journal.\n\n— Hemet Nesingwary Sr.",
        rewards = {
            tokens = 20,
            items = { { id = "iron_cage", count = 3 }, { id = "az_treat", count = 2 } },
        }
    },
    [3] = {
        id = 3,
        key = "nourishment_harvest",
        title = "Dispatch #3: The Wild Nourishment",
        sender = "Barnil Stonepot",
        location = "Camp Kitchen",
        date = "Camp Memo",
        icon = "Interface\\Icons\\INV_Misc_Food_54",
        questType = "FEED",
        targetCount = 2,
        summary = "Feed your active companion 2 treats or harvested family diets.",
        body = "Hello there, young naturalist!\n\nBarnil Stonepot here. You can't expect a wolf, bear, or raptor to trust your commands on an empty belly! A companion's attunement and loyalty grow rapidly when nourished with its favorite meats or honeyed Safari Treats.\n\nFeed your active companion twice to strengthen your bond!\n\n— Barnil Stonepot, Expedition Quartermaster",
        rewards = {
            tokens = 25,
            items = { { id = "az_feast", count = 1 }, { id = "healing_salve", count = 3 } },
        }
    },
    [4] = {
        id = 4,
        key = "apex_sighting",
        title = "Dispatch #4: Sighting of Apex Rares",
        sender = "Hemet Nesingwary Jr.",
        location = "Safari Outpost",
        date = "Rare Bounty",
        icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        questType = "CAPTURE_RARE",
        targetCount = 1,
        summary = "Track down and catalog an authentic rare apex beast.",
        body = "Fellow Hunter,\n\nWord from the scouts is that legendary apex beasts roam the wilds—unmarked by common breeds. Creatures like Broken Tooth, Lupos, and Humar the Pridelord carry an ancient wild aura.\n\nUse your stalking instincts to track down and snare a rare spawn. They have high resistance to basic netting, so stalk closely for the +25% focus bonus or prepare heavy-gauge nets!\n\n— Hemet Nesingwary Jr.",
        rewards = {
            tokens = 40,
            items = { { id = "mithril_cage", count = 2 }, { id = "az_feast", count = 2 } },
        }
    },
    [5] = {
        id = 5,
        key = "dungeon_catalyst",
        title = "Dispatch #5: Deep Dungeon Expedition",
        sender = "Ajeck Rouack",
        location = "Research Tent",
        date = "Special Assignment",
        icon = "Interface\\Icons\\Spell_Shadow_GatherShadows",
        questType = "BOSS_KILL",
        targetCount = 1,
        summary = "Defeat a dungeon boss to recover an Evolution Catalyst.",
        body = "Greetings, League Member.\n\nCertain ancient bosses in dungeons across Azeroth harbor primal mutation energies—Metamorphosis Catalysts such as Shadowfang Essence or Hydra Bile.\n\nVenture into a dungeon with an expedition party, down a boss, and greed for the secondary catalyst loot roll!\n\n— Ajeck Rouack, Senior Safari Alchemist",
        rewards = {
            tokens = 50,
            items = { { id = "arcanite_capsule", count = 1 }, { id = "az_feast", count = 3 } },
        }
    },
    [6] = {
        id = 6,
        key = "deadmines_mechanical_permit",
        title = "Research Permit: Mechanical Overhaul",
        sender = "Hemet Nesingwary Sr.",
        location = "Expedition Workshop",
        date = "Priority Directive",
        icon = "Interface\\Icons\\INV_Gizmo_02",
        questType = "KILL_MECHANICAL_BOSS",
        targetCount = 1,
        unlocksType = "Mechanical",
        summary = "Defeat the mechanical boss in Deadmines to earn the Clockwork Engineering Permit.",
        body = "Recruit,\n\nReports indicate that the Defias Brotherhood in the Deadmines have constructed advanced mechanical lumber reapers and combat shredders deep within their subterranean foundry.\n\nTo safely study and capture mechanical fauna and clockwork constructs in the field, we require vital telemetry from an active war machine. Infiltrate the Deadmines, bring down Sneed's Shredder (or Foe Reaper), and recover the core schematics!\n\nAll naturalists present for the takedown will immediately receive their Clockwork Engineering Permit and a bounty of Safari Tokens!\n\n— Hemet Nesingwary Sr.",
        rewards = {
            tokens = 50,
            items = { { id = "iron_cage", count = 5 }, { id = "healing_salve", count = 5 } },
        }
    },
    [7] = {
        id = 7,
        key = "bfd_elemental_permit",
        title = "Research Permit: Primal Attunement",
        sender = "Ajeck Rouack",
        location = "Alchemical Sanctuary",
        date = "Priority Directive",
        icon = "Interface\\Icons\\Spell_Fire_Elemental_Devastation",
        questType = "KILL_ELEMENTAL_BOSS",
        targetCount = 1,
        unlocksType = "Elemental",
        summary = "Defeat the elemental boss Baron Aquanis in Blackfathom Deeps to earn the Primal Attunement Permit.",
        body = "Naturalist,\n\nRaw elemental energy is inherently chaotic and violently resists standard containment nets. To attune our safari gear to capture and bond with elemental spirits, we require a condensed primal focus.\n\nDeep within the sunken temple of Blackfathom Deeps resides the water elemental entity Baron Aquanis. Delve into the depths, vanquish the elemental lord, and harness the pure primal resonance!\n\nAll party members assisting in the defeat will immediately earn their Primal Attunement Permit and Safari Tokens!\n\n— Ajeck Rouack, Senior Safari Alchemist",
        rewards = {
            tokens = 50,
            items = { { id = "mithril_cage", count = 3 }, { id = "az_treat", count = 5 } },
        }
    },
    [8] = {
        id = 8,
        key = "rfd_undead_permit",
        title = "Research Permit: Necrotic Containment",
        sender = "Hemet Nesingwary Jr.",
        location = "Southern Barrens",
        date = "Priority Directive",
        icon = "Interface\\Icons\\Spell_Shadow_DeadofNight",
        questType = "KILL_UNDEAD_BOSS",
        targetCount = 1,
        unlocksType = "Undead",
        summary = "Defeat Amnennar the Coldbringer in Razorfen Downs to earn the Necrotic Containment Permit.",
        body = "Hunter,\n\nReanimated beasts and skeletal fauna carry lingering necrotic curses that rot standard hemp netting upon contact. To safely contain and purify undead creatures for league companionship, we must extract the phylactery matrix from an authentic Scourge lich.\n\nVenture into the thorny catacombs of Razorfen Downs, confront Amnennar the Coldbringer, and shatter his reign of ice and decay!\n\nAll naturalists participating in the assault will be awarded their Necrotic Containment Permit and expedition tokens!\n\n— Hemet Nesingwary Jr.",
        rewards = {
            tokens = 50,
            items = { { id = "mithril_cage", count = 3 }, { id = "revival_crystal", count = 3 } },
        }
    },
}

-- Abilities Database (Cooldown in turns & Limited Usages per battle)
C.ABILITIES = {
    -- Universal / Tackle
    ["Tackle"] = {
        name = "Tackle",
        type = "Humanoid",
        power = 30,
        accuracy = 95,
        cooldown = 0,
        maxUses = 15,
        icon = "Interface\\Icons\\Ability_Physical_Taunt",
        description = "A direct physical charge into the opponent."
    },

    -- 1. Aquatic Moves
    ["Water_Jet"] = {
        name = "Water Jet",
        type = "Aquatic",
        power = 40,
        accuracy = 95,
        cooldown = 0,
        maxUses = 12,
        icon = "Interface\\Icons\\Spell_Frost_Frostbolt02",
        description = "Blasts the enemy with a high-pressure jet of water."
    },
    ["Surge"] = {
        name = "Tidal Surge",
        type = "Aquatic",
        power = 65,
        accuracy = 90,
        cooldown = 2,
        maxUses = 4,
        icon = "Interface\\Icons\\Spell_Frost_FrostNova",
        description = "Calls down a crushing wave of tidal water."
    },
    ["Cleansing_Rain"] = {
        name = "Cleansing Rain",
        type = "Aquatic",
        power = 0,
        accuracy = 100,
        heal = 0.35,
        cooldown = 5,
        maxUses = 3,
        icon = "Interface\\Icons\\Spell_Nature_HealingWaveGreater",
        description = "Bathes in healing rain, restoring 35% max health. (5 turn CD, max 3 uses)"
    },
    ["Aqua_Ring"] = {
        name = "Aqua Ring",
        type = "Aquatic",
        power = 0,
        accuracy = 100,
        buff = { stat = "def", multiplier = 1.35, duration = 3 },
        cooldown = 4,
        maxUses = 3,
        icon = "Interface\\Icons\\Spell_Frost_ManaRecharge",
        description = "Surrounds the user with a fluid barrier, boosting Defense by 35% for 3 turns."
    },

    -- 2. Beast Moves
    ["Bite"] = {
        name = "Fierce Bite",
        type = "Beast",
        power = 42,
        accuracy = 95,
        cooldown = 0,
        maxUses = 12,
        icon = "Interface\\Icons\\Ability_Druid_FerociousBite",
        description = "Sinks sharp fangs into the enemy, dealing beast damage."
    },
    ["Poison_Sting"] = {
        name = "Poison Sting",
        type = "Beast",
        power = 40,
        accuracy = 95,
        cooldown = 0,
        maxUses = 12,
        icon = "Interface\\Icons\\Ability_Hunter_Quickshot",
        description = "Stabs the target with a venomous barb, dealing beast poison damage."
    },
    ["Claw_Frenzy"] = {
        name = "Claw Frenzy",
        type = "Beast",
        power = 45,
        accuracy = 95,
        cooldown = 0,
        maxUses = 12,
        icon = "Interface\\Icons\\Ability_GhoulFrenzy",
        description = "Rakes the foe repeatedly with razor claws."
    },
    ["Ravage"] = {
        name = "Savage Ravage",
        type = "Beast",
        power = 70,
        accuracy = 85,
        cooldown = 3,
        maxUses = 4,
        icon = "Interface\\Icons\\Ability_Druid_Ravage",
        description = "A vicious assault that tears into the target's flesh."
    },
    ["Furious_Howl"] = {
        name = "Furious Howl",
        type = "Beast",
        power = 0,
        accuracy = 100,
        buff = { stat = "atk", multiplier = 1.30, duration = 3 },
        cooldown = 4,
        maxUses = 3,
        icon = "Interface\\Icons\\Ability_Hunter_Pet_Wolf",
        description = "Howls fiercely, raising Attack power by 30% for 3 turns."
    },
    ["Survival_Instincts"] = {
        name = "Survival Instincts",
        type = "Beast",
        power = 0,
        accuracy = 100,
        heal = 0.35,
        cooldown = 5,
        maxUses = 3,
        icon = "Interface\\Icons\\Ability_Druid_Enrage",
        description = "Taps into wild resilience, restoring 35% of max health. (5 turn CD, max 3 uses)"
    },

    -- 3. Dragonkin Moves
    ["Dragon_Breath"] = {
        name = "Dragon Breath",
        type = "Dragonkin",
        power = 62,
        accuracy = 90,
        dot = { damage = 14, duration = 2 },
        cooldown = 2,
        maxUses = 5,
        icon = "Interface\\Icons\\Spell_Fire_Fire",
        description = "Unleashes a torrent of searing flame that burns the target."
    },
    ["Tail_Sweep"] = {
        name = "Tail Sweep",
        type = "Dragonkin",
        power = 48,
        accuracy = 95,
        cooldown = 0,
        maxUses = 10,
        icon = "Interface\\Icons\\INV_Misc_MonsterTail_03",
        description = "Sweeps a heavy scaled tail across the battlefield."
    },
    ["Roar_of_Aspects"] = {
        name = "Roar of Aspects",
        type = "Dragonkin",
        power = 0,
        accuracy = 100,
        buff = { stat = "atk", multiplier = 1.35, duration = 3 },
        cooldown = 4,
        maxUses = 3,
        icon = "Interface\\Icons\\Spell_Fire_Burnout",
        description = "Channels dragon fury, boosting Attack by 35% for 3 turns."
    },
    ["Scale_Armor"] = {
        name = "Draconic Scales",
        type = "Dragonkin",
        power = 0,
        accuracy = 100,
        buff = { stat = "def", multiplier = 1.35, duration = 3 },
        cooldown = 4,
        maxUses = 3,
        icon = "Interface\\Icons\\INV_Misc_Monsterscales_03",
        description = "Hardens dragon scales, increasing defense by 35% for 3 turns."
    },

    -- 4. Elemental Moves
    ["Fire_Blast"] = {
        name = "Fire Blast",
        type = "Elemental",
        power = 50,
        accuracy = 95,
        cooldown = 0,
        maxUses = 10,
        icon = "Interface\\Icons\\Spell_Fire_Fireball",
        description = "Blasts the target with an explosion of pure flame."
    },
    ["Flame_Breath"] = {
        name = "Flame Breath",
        type = "Elemental",
        power = 48,
        accuracy = 95,
        cooldown = 0,
        maxUses = 12,
        icon = "Interface\\Icons\\Spell_Fire_Fire",
        description = "Exhales a burst of elemental flame."
    },
    ["Frost_Nova"] = {
        name = "Frost Nova",
        type = "Elemental",
        power = 40,
        accuracy = 90,
        cooldown = 2,
        maxUses = 4,
        icon = "Interface\\Icons\\Spell_Frost_FrostNova",
        description = "Freezes the foe in place, dealing elemental damage."
    },
    ["Earth_Shock"] = {
        name = "Earth Shock",
        type = "Elemental",
        power = 55,
        accuracy = 95,
        cooldown = 1,
        maxUses = 6,
        icon = "Interface\\Icons\\Spell_Nature_EarthShock",
        description = "Shocks the enemy with seismic force."
    },
    ["Elemental_Surge"] = {
        name = "Elemental Surge",
        type = "Elemental",
        power = 80,
        accuracy = 85,
        cooldown = 3,
        maxUses = 3,
        icon = "Interface\\Icons\\Spell_Nature_Lightning",
        description = "Channels catastrophic primal lightning for massive damage."
    },

    -- 5. Flying Moves
    ["Peck"] = {
        name = "Swift Peck",
        type = "Flying",
        power = 40,
        accuracy = 100,
        cooldown = 0,
        maxUses = 12,
        icon = "Interface\\Icons\\Ability_Hunter_EagleEye",
        description = "Strikes swiftly from above with a sharp beak."
    },
    ["Alpha_Strike"] = {
        name = "Alpha Strike",
        type = "Flying",
        power = 65,
        accuracy = 90,
        cooldown = 2,
        maxUses = 4,
        icon = "Interface\\Icons\\Ability_Hunter_Pet_Bat",
        description = "Dives at breakneck speed to hit the foe hard."
    },
    ["Tailwind"] = {
        name = "Tailwind",
        type = "Flying",
        power = 0,
        accuracy = 100,
        buff = { stat = "spd", multiplier = 1.40, duration = 3 },
        cooldown = 4,
        maxUses = 3,
        icon = "Interface\\Icons\\Spell_Magic_FeatherFall",
        description = "Summons a gust of wind, increasing speed by 40% for 3 turns."
    },
    ["Predatory_Dive"] = {
        name = "Predatory Dive",
        type = "Flying",
        power = 75,
        accuracy = 85,
        cooldown = 3,
        maxUses = 3,
        icon = "Interface\\Icons\\Ability_Hunter_Pet_Dragonhawk",
        description = "Ascends high and crashes into the prey."
    },

    -- 6. Humanoid Moves
    ["Mortal_Strike"] = {
        name = "Mortal Strike",
        type = "Humanoid",
        power = 60,
        accuracy = 90,
        cooldown = 1,
        maxUses = 6,
        icon = "Interface\\Icons\\Ability_Warrior_SavageBlow",
        description = "A devastating martial blow dealing heavy humanoid damage."
    },
    ["Shield_Block"] = {
        name = "Shield Block",
        type = "Humanoid",
        power = 0,
        accuracy = 100,
        buff = { stat = "def", multiplier = 1.40, duration = 3 },
        cooldown = 4,
        maxUses = 3,
        icon = "Interface\\Icons\\Ability_Defend",
        description = "Raises a sturdy defensive guard, increasing defense by 40% for 3 turns."
    },
    ["First_Aid"] = {
        name = "Field Bandage",
        type = "Humanoid",
        power = 0,
        accuracy = 100,
        heal = 0.30,
        cooldown = 5,
        maxUses = 3,
        icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
        description = "Quickly applies combat bandages, healing 30% max HP. (5 turn CD, max 3 uses)"
    },
    ["Battle_Shout"] = {
        name = "Battle Shout",
        type = "Humanoid",
        power = 0,
        accuracy = 100,
        buff = { stat = "atk", multiplier = 1.25, duration = 3 },
        cooldown = 4,
        maxUses = 3,
        icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
        description = "Empowers combat readiness, boosting Attack by 25% for 3 turns."
    },

    -- 7. Magic Moves
    ["Arcane_Blast"] = {
        name = "Arcane Blast",
        type = "Magic",
        power = 52,
        accuracy = 95,
        cooldown = 0,
        maxUses = 10,
        icon = "Interface\\Icons\\Spell_Arcane_Blast",
        description = "Strikes the target with concentrated arcane power."
    },
    ["Nether_Surge"] = {
        name = "Nether Surge",
        type = "Magic",
        power = 75,
        accuracy = 90,
        cooldown = 2,
        maxUses = 4,
        icon = "Interface\\Icons\\Spell_Arcane_ArcaneTorrent",
        description = "Unleashes an ethereal burst of magic energy."
    },
    ["Mana_Barrier"] = {
        name = "Mana Barrier",
        type = "Magic",
        power = 0,
        accuracy = 100,
        buff = { stat = "def", multiplier = 1.40, duration = 3 },
        cooldown = 4,
        maxUses = 3,
        icon = "Interface\\Icons\\Spell_Arcane_PrismaticCloak",
        description = "Erects a shimmering magic barrier, increasing Defense by 40% for 3 turns."
    },
    ["Amplify_Magic"] = {
        name = "Amplify Magic",
        type = "Magic",
        power = 0,
        accuracy = 100,
        buff = { stat = "atk", multiplier = 1.35, duration = 3 },
        cooldown = 4,
        maxUses = 3,
        icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
        description = "Empowers magical resonance, raising Attack by 35% for 3 turns."
    },

    -- 8. Mechanical Moves
    ["Rocket_Salvo"] = {
        name = "Rocket Salvo",
        type = "Mechanical",
        power = 65,
        accuracy = 90,
        cooldown = 2,
        maxUses = 4,
        icon = "Interface\\Icons\\Ability_Hunter_RocketBarrage",
        description = "Fires a miniature salvo of explosive micro-missiles."
    },
    ["Cog_Strike"] = {
        name = "Cog Strike",
        type = "Mechanical",
        power = 40,
        accuracy = 100,
        cooldown = 0,
        maxUses = 12,
        icon = "Interface\\Icons\\Trade_Engineering",
        description = "Strikes with whirling steel gears and mechanical precision."
    },
    ["Overclock"] = {
        name = "Overclock",
        type = "Mechanical",
        power = 0,
        accuracy = 100,
        buff = { stat = "spd", multiplier = 1.50, duration = 3 },
        cooldown = 4,
        maxUses = 3,
        icon = "Interface\\Icons\\INV_Gizmo_03",
        description = "Overrides safety protocols to boost Speed by 50% for 3 turns."
    },
    ["Self_Repair"] = {
        name = "Emergency Repair",
        type = "Mechanical",
        power = 0,
        accuracy = 100,
        heal = 0.40,
        cooldown = 5,
        maxUses = 3,
        icon = "Interface\\Icons\\INV_Gizmo_02",
        description = "Deploys nanite repair bots to restore 40% max HP. (5 turn CD, max 3 uses)"
    },
    ["Spark_Blast"] = {
        name = "Spark Blast",
        type = "Mechanical",
        power = 40,
        accuracy = 95,
        cooldown = 0,
        maxUses = 12,
        icon = "Interface\\Icons\\Spell_Nature_WispSplode",
        description = "Discharges high-voltage capacitors directly into the enemy."
    },

    -- 9. Undead Moves
    ["Shadow_Bolt"] = {
        name = "Shadow Bolt",
        type = "Undead",
        power = 50,
        accuracy = 90,
        cooldown = 0,
        maxUses = 10,
        icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
        description = "Hurls a bolt of dark energy at the foe."
    },
    ["Shadow_Fang"] = {
        name = "Shadow Fang",
        type = "Undead",
        power = 45,
        accuracy = 95,
        cooldown = 0,
        maxUses = 12,
        icon = "Interface\\Icons\\Spell_Shadow_FingerOfDeath",
        description = "Bites with shadowy ethereal fangs."
    },
    ["Drain_Life"] = {
        name = "Drain Life",
        type = "Undead",
        power = 45,
        accuracy = 95,
        drainPercent = 0.50,
        cooldown = 2,
        maxUses = 4,
        icon = "Interface\\Icons\\Spell_Shadow_LifeDrain02",
        description = "Drains life essence from the foe, healing for 50% of the damage dealt."
    },
    ["Plague_Touch"] = {
        name = "Plague Touch",
        type = "Undead",
        power = 34,
        accuracy = 90,
        dot = { damage = 16, duration = 3 },
        cooldown = 3,
        maxUses = 4,
        icon = "Interface\\Icons\\Spell_Shadow_CallofBone",
        description = "Afflicts the enemy with a rotting plague that deals damage over 3 turns."
    },
    ["Cannibalize"] = {
        name = "Cannibalize",
        type = "Undead",
        power = 0,
        accuracy = 100,
        heal = 0.40,
        cooldown = 5,
        maxUses = 3,
        icon = "Interface\\Icons\\Ability_Racial_Cannibalize",
        description = "Feasts upon dark energies to regenerate 40% max HP. (5 turn CD, max 3 uses)"
    }
}

-- Move Pools for the 9 Types
C.TYPE_MOVE_POOLS = {
    ["Aquatic"]     = { "Water_Jet", "Aqua_Ring", "Surge", "Cleansing_Rain" },
    ["Beast"]       = { "Bite", "Poison_Sting", "Claw_Frenzy", "Furious_Howl", "Ravage", "Survival_Instincts" },
    ["Dragonkin"]   = { "Dragon_Breath", "Tail_Sweep", "Roar_of_Aspects", "Scale_Armor" },
    ["Elemental"]   = { "Fire_Blast", "Flame_Breath", "Frost_Nova", "Earth_Shock", "Elemental_Surge" },
    ["Flying"]      = { "Peck", "Tailwind", "Alpha_Strike", "Predatory_Dive" },
    ["Humanoid"]    = { "Mortal_Strike", "Shield_Block", "Battle_Shout", "First_Aid", "Tackle" },
    ["Magic"]       = { "Arcane_Blast", "Mana_Barrier", "Nether_Surge", "Amplify_Magic" },
    ["Mechanical"]  = { "Spark_Blast", "Cog_Strike", "Overclock", "Rocket_Salvo", "Self_Repair" },
    ["Undead"]      = { "Shadow_Bolt", "Shadow_Fang", "Plague_Touch", "Drain_Life", "Cannibalize" }
}

-- Iconic Azeroth Species Bestiary Catalog for ForeverSafari Field Guide 3D Paperdoll Browsing
C.SPECIES_CATALOG = {
    {
        id = 1,
        name = "Murloc Coastrunner",
        type = "Aquatic",
        displayId = 1042,
        habitat = "Elwynn Forest, Westfall, Durotar",
        description = "Aggressive amphibious bipeds native to Azeroth's coasts, rivers, and shallow waters.",
        baseStats = { hp = 65, atk = 14, def = 11, spd = 13 },
        moves = { "Water_Jet", "Aqua_Ring", "Tackle" }
    },
    {
        id = 2,
        name = "Timber Wolf",
        type = "Beast",
        displayId = 903,
        habitat = "Elwynn Forest, Dun Morogh, Mulgore",
        description = "Fierce pack predators that roam temperate woodlands and strike with coordinated precision.",
        baseStats = { hp = 60, atk = 16, def = 10, spd = 15 },
        moves = { "Bite", "Furious_Howl", "Tackle" }
    },
    {
        id = 3,
        name = "Defias Rogue",
        type = "Humanoid",
        displayId = 180,
        habitat = "Westfall, Elwynn Forest, Deadmines",
        description = "Outlaw bandits fighting under the Brotherhood banner, skilled in swift martial combat.",
        baseStats = { hp = 62, atk = 15, def = 13, spd = 12 },
        moves = { "Mortal_Strike", "Shield_Block", "Tackle" }
    },
    {
        id = 4,
        name = "Harvest Watcher",
        type = "Mechanical",
        displayId = 387,
        habitat = "Westfall, Duskwood",
        description = "Rogue mechanical automata constructed by Westfall farmers, reinforced with heavy iron plating.",
        baseStats = { hp = 70, atk = 13, def = 18, spd = 8 },
        moves = { "Spark_Blast", "Self_Repair", "Tackle" }
    },
    {
        id = 5,
        name = "Fire Elemental",
        type = "Elemental",
        displayId = 114,
        habitat = "Searing Gorge, Molten Core, Durotar",
        description = "Living manifestation of primordial fire and destructive flame, ignoring environmental barriers.",
        baseStats = { hp = 55, atk = 19, def = 10, spd = 14 },
        moves = { "Fire_Blast", "Elemental_Surge", "Tackle" }
    },
    {
        id = 6,
        name = "Great Horned Owl",
        type = "Flying",
        displayId = 4184,
        habitat = "Teldrassil, Ashenvale",
        description = "Silent nocturnal raptors blessed by Elune, striking unsuspecting foes from high altitudes.",
        baseStats = { hp = 50, atk = 15, def = 9, spd = 20 },
        moves = { "Peck", "Tailwind", "Predatory_Dive" }
    },
    {
        id = 7,
        name = "Black Whelp",
        type = "Dragonkin",
        displayId = 300,
        habitat = "Redridge Mountains, Badlands, Dustwallow",
        description = "Young broodlings of the Black Dragonflight, exhaling scorching breath upon their enemies.",
        baseStats = { hp = 72, atk = 18, def = 15, spd = 11 },
        moves = { "Dragon_Breath", "Tail_Sweep", "Scale_Armor" }
    },
    {
        id = 8,
        name = "Fel Imp",
        type = "Magic",
        displayId = 4449,
        habitat = "Felwood, Desolace, Burning Steppes",
        description = "Mischievous lesser demons channeling chaotic arcane and fel energies to pierce physical armor.",
        baseStats = { hp = 56, atk = 17, def = 11, spd = 13 },
        moves = { "Arcane_Blast", "Nether_Surge", "Mana_Barrier" }
    },
    {
        id = 9,
        name = "Skeletal Fiend",
        type = "Undead",
        displayId = 239,
        habitat = "Tirisfal Glades, Duskwood, Western Plaguelands",
        description = "Reanimated skeletal warriors bound by dark necromancy, refusing to stay dead when struck down.",
        baseStats = { hp = 68, atk = 13, def = 12, spd = 10 },
        moves = { "Shadow_Bolt", "Plague_Touch", "Drain_Life" }
    },
    {
        id = 10,
        name = "Durotar Scorpid",
        type = "Beast",
        displayId = 714,
        habitat = "Durotar, Barrens, Tanaris",
        description = "Venomous arachnids adapted to harsh desert wastes, delivering debilitating stings.",
        baseStats = { hp = 64, atk = 15, def = 14, spd = 11 },
        moves = { "Bite", "Ravage", "Tackle" }
    },
    {
        id = 11,
        name = "Moonstalker Panther",
        type = "Beast",
        displayId = 775,
        habitat = "Darkshore, Ashenvale, Stranglethorn",
        description = "Stealthy feline stalkers cloaked in moonlight, capable of deadly burst ambushes.",
        baseStats = { hp = 58, atk = 18, def = 9, spd = 17 },
        moves = { "Bite", "Furious_Howl", "Ravage" }
    },
    {
        id = 12,
        name = "Bloodscalp Raptor",
        type = "Beast",
        displayId = 1064,
        habitat = "Stranglethorn Vale, Wetlands, Barrens",
        description = "Agile saurian predators armed with razor-sharp talons and unyielding aggression.",
        baseStats = { hp = 63, atk = 17, def = 11, spd = 16 },
        moves = { "Bite", "Ravage", "Survival_Instincts" }
    },
    {
        id = 13,
        name = "Spindleweb Spider",
        type = "Beast",
        displayId = 382,
        habitat = "Tirisfal Glades, Duskwood, Silverpine",
        description = "Eight-legged arachnids lurking in dark canopies, trapping prey in sticky silk webbing.",
        baseStats = { hp = 59, atk = 14, def = 12, spd = 14 },
        moves = { "Bite", "Ravage", "Tackle" }
    },
    {
        id = 14,
        name = "Sea Crawler Crab",
        type = "Aquatic",
        displayId = 1153,
        habitat = "Darkshore, Westfall, Durotar",
        description = "Heavily armored littoral crustaceans that pinch with bone-crushing claw pressure.",
        baseStats = { hp = 67, atk = 12, def = 19, spd = 8 },
        moves = { "Water_Jet", "Aqua_Ring", "Tackle" }
    },
    {
        id = 15,
        name = "Snapjaw Turtle",
        type = "Aquatic",
        displayId = 2470,
        habitat = "Hillsbrad Foothills, Tanaris, Dustwallow",
        description = "Ancient shelled reptiles with incredibly tough carapaces and powerful snapping jaws.",
        baseStats = { hp = 76, atk = 11, def = 20, spd = 7 },
        moves = { "Water_Jet", "Cleansing_Rain", "Tackle" }
    },
    {
        id = 16,
        name = "Forest Bear",
        type = "Beast",
        displayId = 742,
        habitat = "Elwynn Forest, Ashenvale, Silverpine",
        description = "Massive omnivorous beasts possessing immense physical endurance and raw brute strength.",
        baseStats = { hp = 78, atk = 14, def = 15, spd = 9 },
        moves = { "Bite", "Survival_Instincts", "Tackle" }
    },
    {
        id = 17,
        name = "Water Elemental",
        type = "Aquatic",
        displayId = 891,
        habitat = "Stranglethorn Vale, Dustwallow Marsh",
        description = "Pristine aquatic spirits summoned from the Abyssal Maw, controlling swirling torrents.",
        baseStats = { hp = 66, atk = 16, def = 12, spd = 12 },
        moves = { "Water_Jet", "Surge", "Cleansing_Rain" }
    },
    {
        id = 18,
        name = "Duskwood Ghoul",
        type = "Undead",
        displayId = 376,
        habitat = "Duskwood, Tirisfal Glades, Scourgeholme",
        description = "Ravenous undead corpses driven by insatiable flesh-hunger and plague contagion.",
        baseStats = { hp = 65, atk = 16, def = 11, spd = 12 },
        moves = { "Drain_Life", "Cannibalize", "Plague_Touch" }
    }
}

