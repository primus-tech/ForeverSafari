--[[
    Forever Safari: Bestiary Database (Azeroth Field Pokédex)
    Curated Azeroth Beast & Creature Taxonomy with verified 3D display IDs,
    habitats, natural movepools, base stats, and Nesingwary field lore.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.BestiaryDB = ns.BestiaryDB or {}

local Bestiary = ns.BestiaryDB

-- Total Curated Azeroth Wildlife Catalog
Bestiary.SPECIES = {
    -- =========================================================================
    -- 🐺 CANINE (Wolves, Worgs, Coyotes, Hyenas, Foxes)
    -- =========================================================================
    {
        id = 1,
        name = "Timber Wolf",
        family = "Canine",
        element = "Beast",
        displayId = 903,
        habitats = { "Elwynn Forest", "Dun Morogh", "Westfall", "Loch Modan" },
        description = "Fierce pack predators roaming temperate woodlands, striking with coordinated precision.",
        baseStats = { hp = 60, atk = 16, def = 10, spd = 15 },
        movepool = { 101, 107, 102, 126 }, -- Bite, Dash, Furious Howl, Alarm Bark
        diet = "Wolf Meat / Fresh Flesh",
        rarity = "Common",
    },
    {
        id = 2,
        name = "Prairie Wolf",
        family = "Canine",
        element = "Beast",
        displayId = 903,
        habitats = { "Mulgore", "The Barrens" },
        description = "Swift golden-coated hunters stalking the grassy savannahs of Central Kalimdor.",
        baseStats = { hp = 58, atk = 17, def = 9, spd = 16 },
        movepool = { 101, 107, 102, 118 }, -- Bite, Dash, Furious Howl, Cower
        diet = "Wolf Meat / Savannah Flank",
        rarity = "Common",
    },
    {
        id = 3,
        name = "Slavering Worg",
        family = "Canine",
        element = "Beast",
        displayId = 6128,
        habitats = { "Silverpine Forest", "Duskwood", "Shadowfang Keep" },
        description = "Massive, muscle-bound canine corrupted by shadow and lunar curses, possessing terrifying jaw strength.",
        baseStats = { hp = 68, atk = 20, def = 13, spd = 14 },
        movepool = { 101, 102, 106, 125 }, -- Bite, Furious Howl, Ravage, Skull Bash
        diet = "Dark Meat / Shadow Essences",
        rarity = "Uncommon",
    },
    {
        id = 4,
        name = "Coyote",
        family = "Canine",
        element = "Beast",
        displayId = 478,
        habitats = { "Westfall", "Redridge Mountains", "The Barrens" },
        description = "Scrappy, cunning scavengers capable of outrunning larger predators with sudden bursts of speed.",
        baseStats = { hp = 52, atk = 15, def = 8, spd = 19 },
        movepool = { 101, 107, 126, 118 }, -- Bite, Dash, Alarm Bark, Cower
        diet = "Small Game / Poultry",
        rarity = "Common",
    },
    {
        id = 5,
        name = "Savannah Hyena",
        family = "Canine",
        element = "Beast",
        displayId = 718,
        habitats = { "The Barrens", "Desolace", "Tanaris" },
        description = "Vicious pack scavengers with bone-crushing jaws and a demoralizing, psychotic cackle.",
        baseStats = { hp = 62, atk = 18, def = 11, spd = 13 },
        movepool = { 101, 127, 106, 126 }, -- Bite, Hyena Cackle, Ravage, Alarm Bark
        diet = "Carrion / Savannah Meat",
        rarity = "Common",
    },
    {
        id = 6,
        name = "Lupos",
        family = "Canine",
        element = "Shadow",
        displayId = 903,
        habitats = { "Duskwood" },
        description = "Legendary spectral wolf of Duskwood said to infuse its fangs with pure shadow essence.",
        baseStats = { hp = 74, atk = 23, def = 14, spd = 20 },
        movepool = { 101, 201, 102, 126 }, -- Bite, Shadow Bolt, Furious Howl, Alarm Bark
        diet = "Spectral Essence / Dark Flesh",
        rarity = "Rare Apex",
        isApexRare = true,
    },
    {
        id = 7,
        name = "Barnabus",
        family = "Canine",
        element = "Beast",
        displayId = 6128,
        habitats = { "Badlands" },
        description = "Notorious apex worg stalking the arid canyons of the Badlands with ironclad endurance.",
        baseStats = { hp = 82, atk = 22, def = 18, spd = 12 },
        movepool = { 101, 106, 120, 102 }, -- Bite, Ravage, Mangle, Furious Howl
        diet = "Tough Badlands Flank",
        rarity = "Rare Apex",
        isApexRare = true,
    },

    -- =========================================================================
    -- 🐱 FELINE (Cats, Nightsabers, Mountain Lions, Tigers, Leopards)
    -- =========================================================================
    {
        id = 8,
        name = "Nightsaber",
        family = "Feline",
        element = "Beast",
        displayId = 11454,
        habitats = { "Teldrassil", "Darkshore", "Ashenvale" },
        description = "Stealthy apex predators prowling beneath the twilight canopy of ancient Kalimdor forests.",
        baseStats = { hp = 55, atk = 18, def = 8, spd = 19 },
        movepool = { 103, 104, 121, 124 }, -- Claw Frenzy, Prowl, Shred, Tiger's Fury
        diet = "Feline Flank / Fresh Fish",
        rarity = "Common",
    },
    {
        id = 9,
        name = "Mountain Lion",
        family = "Feline",
        element = "Beast",
        displayId = 775,
        habitats = { "Hillsbrad Foothills", "Alterac Mountains", "Redridge Mountains" },
        description = "Muscular ambush hunters that stalk craggy ridges and leap upon unsuspecting prey from above.",
        baseStats = { hp = 58, atk = 19, def = 9, spd = 17 },
        movepool = { 103, 104, 120, 107 }, -- Claw Frenzy, Prowl, Mangle, Dash
        diet = "Venison / Red Meat",
        rarity = "Common",
    },
    {
        id = 10,
        name = "Stranglethorn Tiger",
        family = "Feline",
        element = "Beast",
        displayId = 2390,
        habitats = { "Stranglethorn Vale" },
        description = "Monstrous striped cats camouflaged within the dense tropical foliage of the southern jungles.",
        baseStats = { hp = 64, atk = 21, def = 11, spd = 16 },
        movepool = { 103, 121, 124, 106 }, -- Claw Frenzy, Shred, Tiger's Fury, Ravage
        diet = "Jungle Meat / Fresh Flank",
        rarity = "Uncommon",
    },
    {
        id = 11,
        name = "Savannah Prowler",
        family = "Feline",
        element = "Beast",
        displayId = 775,
        habitats = { "The Barrens" },
        description = "Pride hunters of the sun-drenched savannahs, coordinating swift strikes against stampeding herds.",
        baseStats = { hp = 56, atk = 18, def = 9, spd = 18 },
        movepool = { 103, 105, 107, 120 }, -- Claw Frenzy, Roar, Dash, Mangle
        diet = "Savannah Meat / Plainstrider Flesh",
        rarity = "Common",
    },
    {
        id = 12,
        name = "Broken Tooth",
        family = "Feline",
        element = "Beast",
        displayId = 6082,
        habitats = { "Badlands" },
        description = "Legendary Badlands stalker renowned across Azeroth for blinding 1.0 attack speed and ruthless precision.",
        baseStats = { hp = 70, atk = 24, def = 14, spd = 26 },
        movepool = { 1001, 101, 121, 107 }, -- Hyper Velocity (Signature), Bite, Shred, Dash
        diet = "Prime Badlands Meat",
        rarity = "Rare Apex",
        isApexRare = true,
    },
    {
        id = 13,
        name = "Humar the Pridelord",
        family = "Feline",
        element = "Beast",
        displayId = 4424,
        habitats = { "The Barrens" },
        description = "The regal black lion of the Barrens, commanding surrounding pride members with earth-shaking roars.",
        baseStats = { hp = 76, atk = 25, def = 16, spd = 18 },
        movepool = { 1002, 101, 120, 105 }, -- King's Roar (Signature), Bite, Mangle, Roar
        diet = "King's Feast / Savannah Flank",
        rarity = "Rare Apex",
        isApexRare = true,
    },
    {
        id = 14,
        name = "The Rake",
        family = "Feline",
        element = "Beast",
        displayId = 775,
        habitats = { "Mulgore" },
        description = "Young, ferocious golden mountain cat prowling the cliffs of Mulgore with unmatched agility.",
        baseStats = { hp = 58, atk = 20, def = 10, spd = 22 },
        movepool = { 103, 121, 107, 124 }, -- Claw Frenzy, Shred, Dash, Tiger's Fury
        diet = "Mulgore Venison",
        rarity = "Rare Apex",
        isApexRare = true,
    },

    -- =========================================================================
    -- 🐻 BEAR (Black Bears, Grizzly Bears, Polar Bears)
    -- =========================================================================
    {
        id = 15,
        name = "Black Bear",
        family = "Bear",
        element = "Beast",
        displayId = 742,
        habitats = { "Dun Morogh", "Elwynn Forest", "Loch Modan", "Silverpine" },
        description = "Sturdy omnivores with thick hides, capable of weathering tremendous punishment while mauling foes.",
        baseStats = { hp = 75, atk = 15, def = 17, spd = 8 },
        movepool = { 108, 105, 119, 118 }, -- Tackle, Roar, Frenzied Regeneration, Cower
        diet = "Bear Ribs / Fish / Berries",
        rarity = "Common",
    },
    {
        id = 16,
        name = "Grizzly Bear",
        family = "Bear",
        element = "Beast",
        displayId = 742,
        habitats = { "Hillsbrad Foothills", "Ashenvale", "Feralas" },
        description = "Towering woodland juggernauts possessing immense brute force and unstoppable momentum.",
        baseStats = { hp = 82, atk = 18, def = 19, spd = 7 },
        movepool = { 108, 120, 119, 122 }, -- Tackle, Mangle, Frenzied Regeneration, Swipe
        diet = "Fresh Salmon / Prime Flank",
        rarity = "Uncommon",
    },
    {
        id = 17,
        name = "Polar Bear",
        family = "Bear",
        element = "Beast",
        displayId = 8843,
        habitats = { "Dun Morogh", "Winterspring", "Alterac Mountains" },
        description = "Arctic apex predators insulated by dense sub-zero fur and fat, thriving in glacial blizzards.",
        baseStats = { hp = 88, atk = 19, def = 20, spd = 6 },
        movepool = { 108, 119, 122, 105 }, -- Tackle, Frenzied Regeneration, Swipe, Roar
        diet = "Arctic Fish / Blubber",
        rarity = "Uncommon",
    },
    {
        id = 18,
        name = "Ursius",
        family = "Bear",
        element = "Beast",
        displayId = 742,
        habitats = { "Winterspring" },
        description = "Ancient frost-crowned behemoth bear commanding the highest peaks of Mount Hyjal foothills.",
        baseStats = { hp = 96, atk = 23, def = 24, spd = 7 },
        movepool = { 108, 120, 119, 122 }, -- Tackle, Mangle, Frenzied Regeneration, Swipe
        diet = "Winterspring Salmon",
        rarity = "Rare Apex",
        isApexRare = true,
    },

    -- =========================================================================
    -- 🐗 BOAR (Crag Boars, Mountain Boars, Razzashi Swine)
    -- =========================================================================
    {
        id = 19,
        name = "Crag Boar",
        family = "Boar",
        element = "Beast",
        displayId = 485,
        habitats = { "Dun Morogh", "Loch Modan", "Elwynn Forest", "Durotar" },
        description = "Tough, belligerent grazers equipped with razor tusks and an ironclad charging skull.",
        baseStats = { hp = 68, atk = 15, def = 15, spd = 11 },
        movepool = { 108, 107, 119, 125 }, -- Tackle, Dash, Frenzied Regeneration, Skull Bash
        diet = "Boar Ribs / Roots / Grains",
        rarity = "Common",
    },
    {
        id = 20,
        name = "Razzashi Swine",
        family = "Boar",
        element = "Beast",
        displayId = 485,
        habitats = { "Stranglethorn Vale", "Zul'Gurub Foothills" },
        description = "Tropical wild boar bred for aggressive territorial defense, adorned with venomous jungle spines.",
        baseStats = { hp = 72, atk = 17, def = 16, spd = 12 },
        movepool = { 108, 107, 125, 120 }, -- Tackle, Dash, Skull Bash, Mangle
        diet = "Jungle Roots / Carrion",
        rarity = "Uncommon",
    },

    -- =========================================================================
    -- 🦖 RAPTOR (Bloodtalons, Jungle Raptors, Scytheclaws)
    -- =========================================================================
    {
        id = 21,
        name = "Bloodtalon Raptor",
        family = "Raptor",
        element = "Beast",
        displayId = 1960,
        habitats = { "Durotar", "The Barrens", "Dustwallow Marsh" },
        description = "Intelligent, sickle-clawed reptiles that hunt in pack formations with surgical lethality.",
        baseStats = { hp = 58, atk = 21, def = 10, spd = 18 },
        movepool = { 103, 101, 107, 121 }, -- Claw Frenzy, Bite, Dash, Shred
        diet = "Raptor Flesh / Red Meat",
        rarity = "Common",
    },
    {
        id = 22,
        name = "Jungle Stalker",
        family = "Raptor",
        element = "Beast",
        displayId = 1064,
        habitats = { "Stranglethorn Vale", "Un'Goro Crater" },
        description = "Ferocious green-scaled jungle raptor revered by the Gurubashi tribes for pure predatory instinct.",
        baseStats = { hp = 66, atk = 23, def = 12, spd = 19 },
        movepool = { 103, 121, 120, 107 }, -- Claw Frenzy, Shred, Mangle, Dash
        diet = "Fresh Jungle Meat",
        rarity = "Uncommon",
    },
    {
        id = 23,
        name = "Tethis",
        family = "Raptor",
        element = "Beast",
        displayId = 1064,
        habitats = { "Stranglethorn Vale" },
        description = "The cunning alpha raptor hunted by Nesingwary's elite safari marksmen throughout the southern jungle.",
        baseStats = { hp = 78, atk = 26, def = 15, spd = 22 },
        movepool = { 103, 121, 120, 125 }, -- Claw Frenzy, Shred, Mangle, Skull Bash
        diet = "Prime Jungle Raptor Flank",
        rarity = "Rare Apex",
        isApexRare = true,
    },

    -- =========================================================================
    -- 🦅 AVIAN & BATS (Owls, Eagles, Vultures, Duskbats)
    -- =========================================================================
    {
        id = 24,
        name = "Strigid Owl",
        family = "Avian",
        element = "Flying",
        displayId = 4184,
        habitats = { "Teldrassil", "Darkshore", "Winterspring" },
        description = "Silent nocturnal fliers striking from the tree canopies with talons like steel daggers.",
        baseStats = { hp = 50, atk = 17, def = 8, spd = 22 },
        movepool = { 701, 702, 709, 123 }, -- Peck, Tailwind, Dive, Faerie Fire
        diet = "Small Rodents / Fish",
        rarity = "Common",
    },
    {
        id = 25,
        name = "Carrion Vulture",
        family = "Avian",
        element = "Flying",
        displayId = 4184,
        habitats = { "Westfall", "The Barrens", "Tanaris", "Badlands" },
        description = "Hardy scavengers circling thermal drafts above desolate battlefields and arid deserts.",
        baseStats = { hp = 56, atk = 16, def = 11, spd = 17 },
        movepool = { 701, 703, 709, 106 }, -- Peck, Alpha Strike, Dive, Ravage
        diet = "Carrion / Scraps",
        rarity = "Common",
    },
    {
        id = 26,
        name = "Duskbat",
        family = "Bat",
        element = "Flying",
        displayId = 9535,
        habitats = { "Tirisfal Glades", "Silverpine Forest", "Eastern Plaguelands" },
        description = "Blind nocturnal mammal navigating by screeching echolocation, draining blood from prey.",
        baseStats = { hp = 52, atk = 18, def = 9, spd = 20 },
        movepool = { 202, 709, 204, 126 }, -- Shadow Fang, Dive, Drain Life, Alarm Bark
        diet = "Fresh Blood / Insects",
        rarity = "Common",
    },
    {
        id = 27,
        name = "Olm the Wise",
        family = "Avian",
        element = "Flying",
        displayId = 4184,
        habitats = { "Felwood" },
        description = "Ancient white spirit owl radiating mystical arcane feathers and prophetic wisdom.",
        baseStats = { hp = 68, atk = 22, def = 14, spd = 24 },
        movepool = { 701, 703, 709, 123 }, -- Peck, Alpha Strike, Dive, Faerie Fire
        diet = "Pure Essence / Small Game",
        rarity = "Rare Apex",
        isApexRare = true,
    },

    -- =========================================================================
    -- 🐊 CROCOLISK (River Crocolisks, Saltwater Crocs, Snapjaws)
    -- =========================================================================
    {
        id = 28,
        name = "River Crocolisk",
        family = "Crocolisk",
        element = "Aquatic",
        displayId = 1086,
        habitats = { "Loch Modan", "Wetlands", "Dustwallow Marsh" },
        description = "Armor-scaled amphibious predators that lurk submerged near riverbanks before clamping shut.",
        baseStats = { hp = 74, atk = 18, def = 18, spd = 7 },
        movepool = { 401, 101, 108, 405 }, -- Water Jet, Bite, Tackle, Cleansing Rain
        diet = "Fish / Waterlogged Meat",
        rarity = "Common",
    },
    {
        id = 29,
        name = "Rotgrip",
        family = "Crocolisk",
        element = "Aquatic",
        displayId = 1195,
        habitats = { "Maraudon" },
        description = "Monstrous subterranean crocolisk boss guarding the foul waters of Princess Theradras's domain.",
        baseStats = { hp = 95, atk = 26, def = 24, spd = 8 },
        movepool = { 1005, 401, 108, 405 }, -- Crushing Clamp (Signature), Water Jet, Tackle, Cleansing Rain
        diet = "Subterranean Slime / Flesh",
        rarity = "Rare Apex",
        isApexRare = true,
    },

    -- =========================================================================
    -- 🕷️ SPIDER & SCORPID
    -- =========================================================================
    {
        id = 30,
        name = "Forest Spider",
        family = "Spider",
        element = "Beast",
        displayId = 382,
        habitats = { "Elwynn Forest", "Teldrassil", "Duskwood" },
        description = "Eight-legged web-spinners that paralyze prey with neurotoxins before wrapping them in silk.",
        baseStats = { hp = 52, atk = 17, def = 11, spd = 16 },
        movepool = { 501, 502, 509, 510 }, -- Poison Sting, Web Trap, Constrict, Slumbering Venom
        diet = "Insects / Spider Venom Glands",
        rarity = "Common",
    },
    {
        id = 31,
        name = "Scorpid Worker",
        family = "Scorpid",
        element = "Beast",
        displayId = 2485,
        habitats = { "Durotar", "The Barrens", "Desolace", "Silithus" },
        description = "Desert arachnid armored in chitin plates, striking with a curved tail dripping with potent acid venom.",
        baseStats = { hp = 64, atk = 16, def = 18, spd = 9 },
        movepool = { 501, 502, 108, 510 }, -- Poison Sting, Web Trap, Tackle, Slumbering Venom
        diet = "Scorpid Meat / Chitin",
        rarity = "Common",
    },
    {
        id = 32,
        name = "Death Flayer",
        family = "Scorpid",
        element = "Beast",
        displayId = 714,
        habitats = { "Durotar" },
        description = "Notorious black-chitin scorpid roaming the dry crags of Durotar, feared by young Orc recruits.",
        baseStats = { hp = 70, atk = 21, def = 22, spd = 10 },
        movepool = { 501, 509, 510, 108 }, -- Poison Sting, Constrict, Slumbering Venom, Tackle
        diet = "Durotar Crawler Chitin",
        rarity = "Rare Apex",
        isApexRare = true,
    },

    -- =========================================================================
    -- 🐍 HYDRA & SERPENT
    -- =========================================================================
    {
        id = 33,
        name = "Aku'mai",
        family = "Hydra",
        element = "Shadow",
        displayId = 2837,
        habitats = { "Blackfathom Deeps" },
        description = "Ancient multi-headed terror of the Old Gods, lurking within the submerged ruins of Blackfathom.",
        baseStats = { hp = 94, atk = 27, def = 20, spd = 11 },
        movepool = { 1003, 401, 408, 506 }, -- Void Stream (Signature), Water Jet, Acid Rain, Poison Spit
        diet = "Shadow Essence / Corrupted Water",
        rarity = "Rare Apex",
        isApexRare = true,
    },
    {
        id = 34,
        name = "Wind Serpent",
        family = "Wind Serpent",
        element = "Dragonkin",
        displayId = 1039,
        habitats = { "The Barrens", "Thousand Needles", "Hakkari Temples" },
        description = "Feathered serpentine fliers channeling lightning and nature bursts directly through their crests.",
        baseStats = { hp = 58, atk = 22, def = 11, spd = 19 },
        movepool = { 301, 709, 303, 123 }, -- Dragon Breath, Dive, Roar of Aspects, Faerie Fire
        diet = "Fresh Poultry / Fish",
        rarity = "Uncommon",
    },

    -- =========================================================================
    -- 🦧 GORILLA & KODO
    -- =========================================================================
    {
        id = 35,
        name = "Mistvale Gorilla",
        family = "Gorilla",
        element = "Beast",
        displayId = 1067,
        habitats = { "Stranglethorn Vale", "Un'Goro Crater" },
        description = "Immensely powerful silverback primates defending their jungle territories with ground-pounding fury.",
        baseStats = { hp = 80, atk = 20, def = 16, spd = 10 },
        movepool = { 108, 105, 125, 122 }, -- Tackle, Roar, Skull Bash, Swipe
        diet = "Jungle Bananas / Prime Flank",
        rarity = "Uncommon",
    },
    {
        id = 36,
        name = "Kodo Calf",
        family = "Kodo",
        element = "Beast",
        displayId = 1451,
        habitats = { "Mulgore", "The Barrens", "Desolace" },
        description = "Heavy thick-skinned quadruped revered by the Tauren for loyalty, endurance, and crushing power.",
        baseStats = { hp = 88, atk = 17, def = 20, spd = 6 },
        movepool = { 108, 105, 118, 119 }, -- Tackle, Roar, Cower, Frenzied Regeneration
        diet = "Plains Grains / Roots",
        rarity = "Common",
    },

    -- =========================================================================
    -- 👻 UNDEAD & SPECTRAL BEASTS
    -- =========================================================================
    {
        id = 37,
        name = "Snarlmane",
        family = "Undead",
        element = "Shadow",
        displayId = 1196,
        habitats = { "Shadowfang Keep" },
        description = "Cursed ghost worg bound to Arugal's keep, rending mortal flesh with anti-healing necrotic bites.",
        baseStats = { hp = 76, atk = 24, def = 17, spd = 15 },
        movepool = { 1004, 201, 104, 205 }, -- Shadowfang Rend (Signature), Shadow Bolt, Prowl, Curse of Agony
        diet = "Unholy Essences",
        rarity = "Rare Apex",
        isApexRare = true,
    },
    {
        id = 38,
        name = "Plagued Hound",
        family = "Undead",
        element = "Undead",
        displayId = 6128,
        habitats = { "Western Plaguelands", "Eastern Plaguelands" },
        description = "Rotting canine warped by the Scourge plague, spreading unholy blight with every feral strike.",
        baseStats = { hp = 70, atk = 21, def = 14, spd = 13 },
        movepool = { 202, 203, 204, 205 }, -- Shadow Fang, Plague Touch, Drain Life, Cannibalize
        diet = "Rotting Flesh / Plague Ichor",
        rarity = "Uncommon",
    },

    -- =========================================================================
    -- 🐉 DRAGONKIN & NETHER WHELPS
    -- =========================================================================
    {
        id = 39,
        name = "Red Whelpling",
        family = "Dragonkin",
        element = "Dragonkin",
        displayId = 300,
        habitats = { "Wetlands", "Grim Batol Foothills" },
        description = "Young broodling of the Red Dragonflight, breathing nascent flames to defend dragonkin roosts.",
        baseStats = { hp = 64, atk = 22, def = 15, spd = 16 },
        movepool = { 301, 302, 303, 304 }, -- Dragon Breath, Tail Sweep, Roar of Aspects, Scale Armor
        diet = "Small Mammals / Fire Essences",
        rarity = "Rare",
    },
    {
        id = 40,
        name = "Sprite Darter",
        family = "Dragonkin",
        element = "Magic",
        displayId = 300,
        habitats = { "Feralas" },
        description = "Elusive faerie dragon fluttering with iridescent wings, immune to hostile spellcraft.",
        baseStats = { hp = 55, atk = 20, def = 12, spd = 23 },
        movepool = { 301, 123, 709, 303 }, -- Dragon Breath, Faerie Fire, Dive, Roar of Aspects
        diet = "Nectar / Enchanted Leaves",
        rarity = "Rare",
    },
}

-- Fast Lookup Table by ID and Name
Bestiary.LookupById = {}
Bestiary.LookupByName = {}

for _, sp in ipairs(Bestiary.SPECIES) do
    Bestiary.LookupById[sp.id] = sp
    Bestiary.LookupByName[string.lower(sp.name)] = sp
end

function Bestiary:GetSpecies(id)
    return self.LookupById[id]
end

function Bestiary:FindSpeciesByName(name)
    if not name then return nil end
    return self.LookupByName[string.lower(name)]
end

function Bestiary:GetAllSpecies()
    return self.SPECIES
end
