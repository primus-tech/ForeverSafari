-- Forever Safari — Move & Ability Database
-- Defines native family moves, elemental affinities, damage powers, and status effects.

local _, FS = ...
FS.MoveDB = FS.MoveDB or {}

FS.MoveDB = {
    -- === 🐾 BEAST & PHYSICAL MOVES ===
    [101] = {
        name = "Bite",
        element = "Beast",
        category = "Physical",
        power = 40,
        accuracy = 100,
        pp = 30,
        icon = "Ability_Druid_Rake",
        desc = "A sharp, vicious bite. Basic physical attack.",
    },
    [102] = {
        name = "Growl",
        element = "Beast",
        category = "Status",
        power = 0,
        accuracy = 100,
        pp = 25,
        icon = "Ability_Physical_Taunt",
        desc = "Growls menacingly, lowering enemy Attack by 1 stage.",
    },
    [103] = {
        name = "Claw Frenzy",
        element = "Beast",
        category = "Physical",
        power = 55,
        accuracy = 95,
        pp = 20,
        icon = "Ability_GhoulFrenzy",
        desc = "Rakes with sharp claws in a furious frenzy.",
    },
    [104] = {
        name = "Furious Howl",
        element = "Beast",
        category = "Status",
        power = 0,
        accuracy = 100,
        pp = 15,
        icon = "Ability_Hunter_Pet_Wolf",
        desc = "Emits a battle howl, increasing team Attack by 20% for 3 turns.",
    },
    [105] = {
        name = "Ravage",
        element = "Beast",
        category = "Physical",
        power = 85,
        accuracy = 85,
        pp = 10,
        icon = "Ability_Druid_Ravage",
        desc = "A ferocious mauling blow dealing heavy damage.",
    },
    [106] = {
        name = "Charge",
        element = "Earth",
        category = "Physical",
        power = 50,
        accuracy = 95,
        pp = 20,
        icon = "Ability_Warrior_Charge",
        desc = "Slams headfirst into the foe with high priority.",
    },

    -- === 💀 SHADOW & UNDEAD MOVES ===
    [201] = {
        name = "Shadow Fang",
        element = "Shadow",
        category = "Physical",
        power = 60,
        accuracy = 100,
        pp = 15,
        icon = "Spell_Shadow_FingerOfDeath",
        desc = "Bites with cursed teeth infused with dark shadow essence.",
    },
    [202] = {
        name = "Death Coil",
        element = "Shadow",
        category = "Special",
        power = 70,
        accuracy = 90,
        pp = 10,
        icon = "Spell_Shadow_DeathCoil",
        desc = "Unleashes necrotic energy, draining 25% of damage dealt as HP.",
    },
    [203] = {
        name = "Screech of Dread",
        element = "Shadow",
        category = "Special",
        power = 45,
        accuracy = 100,
        pp = 20,
        icon = "Ability_Hunter_Pet_Bat",
        desc = "Emits a sonic dread screech that confuses and lowers enemy Speed.",
    },
    [204] = {
        name = "Bone Armor",
        element = "Shadow",
        category = "Status",
        power = 0,
        accuracy = 100,
        pp = 15,
        icon = "Spell_Shadow_AntiShadow",
        desc = "Encases the user in hard skeletal bone, boosting Defense by 2 stages.",
    },

    -- === 🔥 FIRE & ELEMENTAL MOVES ===
    [301] = {
        name = "Flame Breath",
        element = "Fire",
        category = "Special",
        power = 65,
        accuracy = 95,
        pp = 15,
        icon = "Spell_Fire_Fire",
        desc = "Breathes a searing torrent of fire, with 10% chance to burn.",
    },
    [302] = {
        name = "Magma Burst",
        element = "Fire",
        category = "Special",
        power = 85,
        accuracy = 85,
        pp = 10,
        icon = "Spell_Fire_SelfDestruct",
        desc = "Erupts molten lava in a catastrophic blast.",
    },

    -- === 💧 WATER & FROST MOVES ===
    [401] = {
        name = "Aqua Jet",
        element = "Water",
        category = "Physical",
        power = 40,
        accuracy = 100,
        pp = 25,
        icon = "Spell_Frost_FrostBlast",
        desc = "Strikes with pressurized water at high priority.",
    },
    [402] = {
        name = "Tidal Surge",
        element = "Water",
        category = "Special",
        power = 75,
        accuracy = 90,
        pp = 10,
        icon = "Spell_Frost_Glacier",
        desc = "Summons a crashing tidal wave over the battlefield.",
    },

    -- === 🌿 NATURE & POISON MOVES ===
    [501] = {
        name = "Poison Sting",
        element = "Nature",
        category = "Physical",
        power = 45,
        accuracy = 100,
        pp = 20,
        icon = "Ability_Hunter_Quickshot",
        desc = "Stabs with a venomous barb, inflicting poison damage over turns.",
    },
    [502] = {
        name = "Web Wrap",
        element = "Nature",
        category = "Status",
        power = 0,
        accuracy = 90,
        pp = 15,
        icon = "Spell_Nature_EarthBind",
        desc = "Traps the foe in sticky webs, reducing Speed by 50%.",
    },

    -- === ⚙️ MECHANICAL & ARCANE MOVES ===
    [601] = {
        name = "Cog Strike",
        element = "Mechanical",
        category = "Physical",
        power = 50,
        accuracy = 100,
        pp = 20,
        icon = "Trade_Engineering",
        desc = "Strikes with whirling steel gears and mechanical precision.",
    },
    [602] = {
        name = "Overclock",
        element = "Mechanical",
        category = "Status",
        power = 0,
        accuracy = 100,
        pp = 10,
        icon = "Spell_Nature_BloodLust",
        desc = "Overclocks internal engines, raising Attack and Speed by 2 stages.",
    },
}

function FS:GetMove(moveId)
    return self.MoveDB[moveId]
end
