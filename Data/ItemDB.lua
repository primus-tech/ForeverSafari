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
-- 🥩 3. THE 11 CANONICAL SAFARI DIET ITEMS
-- =========================================================================
ItemDB.DIET_ITEMS = {
    ["food_meat"]     = { id = "food_meat",     name = "Safari Meat",     category = "Natural Diet", icon = "Interface\\Icons\\INV_Misc_Food_14", tokenCost = 1, desc = "Fresh raw cuts of game meat. Loved by carnivorous beasts." },
    ["food_fish"]     = { id = "food_fish",     name = "Safari Fish",     category = "Natural Diet", icon = "Interface\\Icons\\INV_Misc_Fish_08", tokenCost = 1, desc = "Freshly caught river and coastal fish. Loved by shore and aquatic hunters." },
    ["food_bread"]    = { id = "food_bread",    name = "Safari Bread",    category = "Natural Diet", icon = "Interface\\Icons\\INV_Misc_Food_11", tokenCost = 1, desc = "Hardy expedition trail bread. Loved by grazers and omnivores." },
    ["food_cheese"]   = { id = "food_cheese",   name = "Safari Cheese",   category = "Natural Diet", icon = "Interface\\Icons\\INV_Misc_Food_17", tokenCost = 1, desc = "Aged safari cheese wedge. Loved by rodents and omnivores." },
    ["food_fruit"]    = { id = "food_fruit",    name = "Safari Fruit",    category = "Natural Diet", icon = "Interface\\Icons\\INV_Misc_Food_19", tokenCost = 1, desc = "Sun-ripened wild forest berries and fruit. Loved by avians, bats, and primates." },
    ["food_fungus"]   = { id = "food_fungus",   name = "Safari Fungus",   category = "Natural Diet", icon = "Interface\\Icons\\INV_Mushroom_08",  tokenCost = 1, desc = "Earthy cave mushrooms and sporecaps. Loved by cave crawlers and scavengers." },
    ["food_parts"]    = { id = "food_parts",    name = "Safari Parts",    category = "Special Diet", icon = "Interface\\Icons\\INV_Misc_Gear_01", tokenCost = 1, desc = "Cogs, copper wires, and lubricating oil for maintaining mechanical units." },
    ["food_bonedust"] = { id = "food_bonedust", name = "Safari Bonedust", category = "Special Diet", icon = "Interface\\Icons\\INV_Misc_Dust_02", tokenCost = 1, desc = "Preserved necrotic bone dust for sustaining undead companions." },
    ["food_shards"]   = { id = "food_shards",   name = "Safari Shards",   category = "Special Diet", icon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01", tokenCost = 1, desc = "Glimmering arcane crystal shards for feeding magical anomalies." },
    ["food_crystals"] = { id = "food_crystals", name = "Safari Crystals", category = "Special Diet", icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_02",  tokenCost = 1, desc = "Resonant primal elemental crystals for igniting elemental companions." },
    ["food_runes"]    = { id = "food_runes",    name = "Safari Runes",    category = "Special Diet", icon = "Interface\\Icons\\INV_Misc_Rune_01", tokenCost = 1, desc = "Ancient etched dragon runes for empowering wild dragonkin." },
}

-- Backward compatibility alias
ItemDB.FAMILY_NOURISHMENT = ItemDB.DIET_ITEMS

-- Family & Creature Type Diet Matrix (Favorite = +25 Attunement, Accepted = +15 Attunement)
ItemDB.FAMILY_DIETS = {
    -- Beasts
    ["Canine"]       = { favorite = "food_meat",     accepted = { "food_meat" } },
    ["Wolf"]         = { favorite = "food_meat",     accepted = { "food_meat" } },
    ["Fox"]          = { favorite = "food_meat",     accepted = { "food_meat" } },
    ["Hyena"]        = { favorite = "food_meat",     accepted = { "food_meat" } },
    ["Feline"]       = { favorite = "food_meat",     accepted = { "food_meat", "food_fish" } },
    ["Cat"]          = { favorite = "food_meat",     accepted = { "food_meat", "food_fish" } },
    ["Raptor"]       = { favorite = "food_meat",     accepted = { "food_meat" } },
    ["Bear"]         = { favorite = "food_fish",     accepted = { "food_meat", "food_fish", "food_bread", "food_cheese", "food_fruit", "food_fungus" } },
    ["Boar"]         = { favorite = "food_fungus",   accepted = { "food_meat", "food_bread", "food_cheese", "food_fruit", "food_fungus" } },
    ["Spider"]       = { favorite = "food_meat",     accepted = { "food_meat", "food_fungus" } },
    ["Scorpid"]      = { favorite = "food_meat",     accepted = { "food_meat", "food_fungus" } },
    ["Crab"]         = { favorite = "food_fish",     accepted = { "food_fish", "food_meat", "food_fungus" } },
    ["Crocolisk"]    = { favorite = "food_fish",     accepted = { "food_fish", "food_meat", "food_fungus" } },
    ["Turtle"]       = { favorite = "food_fish",     accepted = { "food_fish", "food_meat", "food_fungus" } },
    ["Avian"]        = { favorite = "food_fruit",    accepted = { "food_fruit", "food_meat", "food_fish" } },
    ["Bat"]          = { favorite = "food_fruit",    accepted = { "food_fruit", "food_meat", "food_fish" } },
    ["Wind Serpent"] = { favorite = "food_fruit",    accepted = { "food_fruit", "food_meat", "food_fish" } },
    ["Gorilla"]      = { favorite = "food_fruit",    accepted = { "food_fruit", "food_bread", "food_fungus" } },
    ["Kodo"]         = { favorite = "food_bread",    accepted = { "food_bread", "food_fruit", "food_cheese" } },
    ["Tallstrider"]  = { favorite = "food_bread",    accepted = { "food_bread", "food_fruit", "food_meat" } },
    ["Hydra"]        = { favorite = "food_meat",     accepted = { "food_meat", "food_fish" } },

    -- Special Types
    ["Mechanical"]   = { favorite = "food_parts",    accepted = { "food_parts" } },
    ["Undead"]       = { favorite = "food_bonedust", accepted = { "food_bonedust", "food_meat" } },
    ["Magic"]        = { favorite = "food_shards",   accepted = { "food_shards" } },
    ["Elemental"]    = { favorite = "food_crystals", accepted = { "food_crystals" } },
    ["Dragonkin"]    = { favorite = "food_runes",    accepted = { "food_runes", "food_meat" } },
    ["Aquatic"]      = { favorite = "food_fish",     accepted = { "food_fish", "food_meat" } },
    ["Flying"]       = { favorite = "food_fruit",    accepted = { "food_fruit", "food_meat" } },
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

function ItemDB:GetDiet(id)
    return self.DIET_ITEMS[id]
end

function ItemDB:GetItem(id)
    return self.ITEMS[id] or self.DIET_ITEMS[id] or self.CAGES[id] or self.TRANSPORT_CRATES[id]
end

function ItemDB:GetFamilyDietInfo(family, creatureType)
    local key = family or creatureType or "Beast"
    local diet = self.FAMILY_DIETS[key] or self.FAMILY_DIETS[creatureType] or self.FAMILY_DIETS["Canine"]
    local favItem = diet and self.DIET_ITEMS[diet.favorite]
    return diet, favItem
end

function ItemDB:GetFamilyDiet(family)
    local _, favItem = self:GetFamilyDietInfo(family, "Beast")
    return favItem or self.DIET_ITEMS["food_meat"]
end

function ItemDB:CanEatFood(family, creatureType, foodKey)
    local diet = self:GetFamilyDietInfo(family, creatureType)
    if not diet then return false, false end
    if diet.favorite == foodKey then
        return true, true
    end
    for _, acceptedKey in ipairs(diet.accepted or {}) do
        if acceptedKey == foodKey then
            return true, false
        end
    end
    return false, false
end
