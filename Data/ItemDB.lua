--[[
    Forever Safari: Item Database (ItemDB)
    Canonical database for capture gear (snares/nets/traps/cages), transport crates,
    family nourishment diets, evolution catalysts, medicine, and shop items.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.ItemDB = ns.ItemDB or {}

local ItemDB = ns.ItemDB

-- =========================================================================
-- 🕸️ 1. CAPTURE GEAR (SNARES, NETS, TRAPS & EXPEDITION CAGES)
-- =========================================================================
ItemDB.CAGES = {
    ["copper_cage"] = {
        id = "copper_cage",
        name = "Copper Snare",
        tier = 1,
        quality = 1,
        qualityName = "Common",
        color = "ffffff",
        power = 1.0,
        catchRate = 0.35,
        tokenCost = 1,
        icon = "Interface\\Icons\\INV_Misc_Noose_01",
        desc = "Standard rope slip-noose used to snare low-level wild critters and cubs in battle (35% Base Catch).",
        category = "Capture Gear",
    },
    ["iron_cage"] = {
        id = "iron_cage",
        name = "Iron Safari Net",
        tier = 2,
        quality = 2,
        qualityName = "Uncommon",
        color = "1eff00",
        power = 1.5,
        catchRate = 0.55,
        tokenCost = 5,
        icon = "Interface\\Icons\\Hunter_PvP_TrackersNet",
        desc = "Reinforced iron-weighted woven mesh with improved capture hold in battle (55% Base Catch).",
        category = "Capture Gear",
    },
    ["mithril_cage"] = {
        id = "mithril_cage",
        name = "Mithril Hunter Trap",
        tier = 3,
        quality = 3,
        qualityName = "Rare",
        color = "0070dd",
        power = 2.0,
        catchRate = 0.75,
        tokenCost = 10,
        icon = "Interface\\Icons\\INV_Pet_PetTrap",
        desc = "High-tensile spring-loaded steel jaws designed to snap and pin fast, exotic predators in battle (75% Base Catch).",
        category = "Capture Gear",
    },
    ["thorium_trap"] = {
        id = "thorium_trap",
        name = "Thorium Expedition Cage",
        tier = 4,
        quality = 4,
        qualityName = "Epic",
        color = "a335ee",
        power = 3.0,
        catchRate = 0.98,
        tokenCost = 25,
        icon = "Interface\\Icons\\INV_Box_Birdcage_01",
        desc = "Heavy reinforced Thorium-alloy expedition cage engineered to secure massive apex behemoths and dungeon monstrosities in battle (98% Base Catch).",
        category = "Capture Gear",
    },
    ["arcanite_capsule"] = {
        id = "arcanite_capsule",
        name = "Thorium Expedition Cage",
        tier = 4,
        quality = 4,
        qualityName = "Epic",
        color = "a335ee",
        power = 3.0,
        catchRate = 0.98,
        tokenCost = 25,
        icon = "Interface\\Icons\\INV_Box_Birdcage_01",
        desc = "Heavy reinforced Thorium-alloy expedition cage engineered to secure massive apex behemoths and dungeon monstrosities in battle (98% Base Catch).",
        category = "Capture Gear",
    },
}

-- =========================================================================
-- 📦 2. TRANSPORT CRATES (KENNEL LOGISTICS)
-- =========================================================================
ItemDB.TRANSPORT_CRATES = {
    ["copper_crate"] = {
        id = "copper_crate",
        name = "Copper Transport Crate",
        tier = 1,
        quality = 1,
        qualityName = "Common",
        color = "ffffff",
        tokenCost = 1,
        icon = "Interface\\Icons\\INV_Box_PetCarrier_01",
        desc = "Essential wooden carrier required to crate and ship captured wild beasts (Common Tier) to the Safari Kennel when your squad is full.",
        category = "Transport Crates",
        maxTier = 1,
    },
    ["iron_crate"] = {
        id = "iron_crate",
        name = "Iron Transport Crate",
        tier = 2,
        quality = 2,
        qualityName = "Uncommon",
        color = "1eff00",
        tokenCost = 5,
        icon = "Interface\\Icons\\INV_Box_PetCarrier_01",
        desc = "Iron-banded reinforced carrier required to safely ship Uncommon specimens to the Safari Kennel.",
        category = "Transport Crates",
        maxTier = 2,
    },
    ["mithril_crate"] = {
        id = "mithril_crate",
        name = "Mithril Transport Crate",
        tier = 3,
        quality = 3,
        qualityName = "Rare",
        color = "0070dd",
        tokenCost = 10,
        icon = "Interface\\Icons\\INV_Box_PetCarrier_01",
        desc = "Heavy steel-locking carrier required to transport Rare wild beasts and apex stalkers to the Safari Kennel.",
        category = "Transport Crates",
        maxTier = 3,
    },
    ["thorium_crate"] = {
        id = "thorium_crate",
        name = "Thorium Transport Crate",
        tier = 4,
        quality = 4,
        qualityName = "Epic",
        color = "a335ee",
        tokenCost = 25,
        icon = "Interface\\Icons\\INV_Box_PetCarrier_01",
        desc = "Indestructible Thorium-plated transport vault required to crate Epic monsters and world bosses to the Safari Kennel.",
        category = "Transport Crates",
        maxTier = 4,
    },
}

-- =========================================================================
-- 🥩 3. HARVESTED FAMILY NOURISHMENT DIETS (+25 Attunement Bonus)
-- =========================================================================
ItemDB.FAMILY_NOURISHMENT = {
    ["Canine"]       = { item = "Wolf Flank",          icon = "Interface\\Icons\\INV_Misc_Food_14", desc = "Fresh gamy meat harvested from wild wolves.", favoriteFamily = "Canine" },
    ["Feline"]       = { item = "Panther Flank",       icon = "Interface\\Icons\\INV_Misc_Food_16", desc = "Lean, muscular meat harvested from wild big cats.", favoriteFamily = "Feline" },
    ["Bear"]         = { item = "Bear Ribs",           icon = "Interface\\Icons\\INV_Misc_Food_18", desc = "Thick, fatty ribs harvested from wild bears.", favoriteFamily = "Bear" },
    ["Boar"]         = { item = "Boar Ribs",           icon = "Interface\\Icons\\INV_Misc_Food_18", desc = "Tough, savory ribs harvested from wild boars.", favoriteFamily = "Boar" },
    ["Raptor"]       = { item = "Raptor Flesh",        icon = "Interface\\Icons\\INV_Misc_Food_17", desc = "Stringy, pungent reptile meat from raptors.", favoriteFamily = "Raptor" },
    ["Avian"]        = { item = "Wild Poultry Flank",  icon = "Interface\\Icons\\INV_Misc_Food_05", desc = "Plump game bird meat harvested from predatory birds.", favoriteFamily = "Avian" },
    ["Bat"]          = { item = "Bat Wing Flank",      icon = "Interface\\Icons\\INV_Misc_Food_15", desc = "Dark, leathery meat from giant bats.", favoriteFamily = "Bat" },
    ["Crocolisk"]    = { item = "Crocolisk Flank",     icon = "Interface\\Icons\\INV_Misc_Food_17", desc = "Dense, chewy meat harvested from river crocolisks.", favoriteFamily = "Crocolisk" },
    ["Spider"]       = { item = "Spider Venom Flank",  icon = "Interface\\Icons\\INV_Misc_Food_19", desc = "Delicately toxic spider tissue and glands.", favoriteFamily = "Spider" },
    ["Scorpid"]      = { item = "Scorpid Flank",       icon = "Interface\\Icons\\INV_Misc_Food_19", desc = "Chitin-shelled meat harvested from giant scorpids.", favoriteFamily = "Scorpid" },
    ["Hydra"]        = { item = "Hydra Tri-Flank",     icon = "Interface\\Icons\\INV_Misc_Food_16", desc = "Mystical tri-colored meat harvested from ancient hydras.", favoriteFamily = "Hydra" },
    ["Wind Serpent"] = { item = "Serpent Crest Flank",  icon = "Interface\\Icons\\INV_Misc_Food_17", desc = "Lightning-charged reptilian meat from wind serpents.", favoriteFamily = "Wind Serpent" },
    ["Gorilla"]      = { item = "Gorilla Flank",       icon = "Interface\\Icons\\INV_Misc_Food_14", desc = "Heavy red game meat harvested from jungle gorillas.", favoriteFamily = "Gorilla" },
    ["Kodo"]         = { item = "Kodo Meat",           icon = "Interface\\Icons\\INV_Misc_Food_18", desc = "Rich, hearty plains steak harvested from wild kodos.", favoriteFamily = "Kodo" },
    ["Tallstrider"]  = { item = "Tallstrider Flank",   icon = "Interface\\Icons\\INV_Misc_Food_05", desc = "Lean game meat harvested from flightless plainstriders.", favoriteFamily = "Tallstrider" },
    ["Dragonkin"]    = { item = "Dragonkin Flank",     icon = "Interface\\Icons\\INV_Misc_Food_17", desc = "Fire-seared scales and meat from wild whelps.", favoriteFamily = "Dragonkin" },
    ["Crab"]         = { item = "Crawler Meat",        icon = "Interface\\Icons\\INV_Misc_Food_16", desc = "Sweet succulent meat harvested from coast crawlers.", favoriteFamily = "Crab" },
    ["Mechanical"]   = { item = "Machine Oil",         icon = "Interface\\Icons\\INV_Misc_EngGizmos_17", desc = "High-grade lubricating fluid for mechanical units.", favoriteFamily = "Mechanical" },
    ["Undead"]       = { item = "Plagued Ichor",       icon = "Interface\\Icons\\Spell_Shadow_DeadofNight", desc = "Necrotic fluid harvested from undead beasts.", favoriteFamily = "Undead" },
    ["Elemental"]    = { item = "Elemental Core",      icon = "Interface\\Icons\\Spell_Fire_Elemental_Totem", desc = "Concentrated primal energy core from wild elementals.", favoriteFamily = "Elemental" },
}

-- =========================================================================
-- 🍖 4. GENERAL ITEMS, MEDICINE & EVOLUTION CATALYSTS
-- =========================================================================
ItemDB.ITEMS = {
    ["healing_salve"] = {
        name = "Safari Healing Salve",
        category = "Medicine & Aid",
        icon = "Interface\\Icons\\INV_Potion_24",
        quality = 1,
        color = "ffffff",
        tokenCost = 2,
        desc = "Soothing botanical salve that fully restores a wounded companion's Health outside combat.",
        useText = "Right-Click to restore active companion to 100% HP.",
    },
    ["revival_crystal"] = {
        name = "Revival Crystal",
        category = "Medicine & Aid",
        icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_01",
        quality = 3,
        color = "0070dd",
        tokenCost = 5,
        desc = "Rejuvenating shard that revives a fainted companion and restores them to 50% HP.",
        useText = "Right-Click to revive active companion from faint.",
    },
    ["safari_treats"] = {
        name = "Azsharan Safari Treats",
        category = "Treats & Diets",
        icon = "Interface\\Icons\\INV_Misc_Food_23",
        quality = 2,
        color = "1eff00",
        tokenCost = 3,
        desc = "Sweet glazed tidbits that instantly grant +50 Attunement points to your active companion.",
        useText = "Right-Click to grant +50 Attunement to companion.",
    },
    ["grand_safari_feast"] = {
        name = "Grand Safari Feast",
        category = "Treats & Diets",
        icon = "Interface\\Icons\\INV_Misc_Food_64",
        quality = 3,
        color = "0070dd",
        tokenCost = 10,
        desc = "Sumptuous safari feast that awards +100 Attunement points across your entire active 4-member squad.",
        useText = "Right-Click to grant +100 Attunement to all 4 squad pets.",
    },
    ["shadowfang_essence"] = {
        name = "Shadowfang Essence",
        category = "Evolution Catalysts",
        icon = "Interface\\Icons\\Spell_Shadow_GatherShadows",
        quality = 4,
        color = "a335ee",
        tokenCost = 30,
        desc = "Concentrated lunar curse essence harvested from Shadowfang Keep. Induces Rank V Metamorphosis (Mangy Wolf ➔ Slavering Worg).",
        useText = "Right-Click in Field Guide at Rank V to Metamorphose companion.",
    },
    ["hydra_bile"] = {
        name = "Hydra Bile",
        category = "Evolution Catalysts",
        icon = "Interface\\Icons\\INV_Misc_Slime_01",
        quality = 4,
        color = "a335ee",
        tokenCost = 30,
        desc = "Primordial acid collected from Blackfathom Deeps. Induces Rank V Metamorphosis.",
        useText = "Right-Click in Field Guide at Rank V to Metamorphose companion.",
    },
}

-- Fast Helper Methods
function ItemDB:GetCage(id)
    return self.CAGES[id]
end

function ItemDB:GetCrate(id)
    return self.TRANSPORT_CRATES[id]
end

function ItemDB:GetItem(id)
    return self.ITEMS[id] or self.CAGES[id] or self.TRANSPORT_CRATES[id]
end

function ItemDB:GetFamilyDiet(family)
    return self.FAMILY_NOURISHMENT[family]
end
