-- Forever Safari — Metamorphosis & Evolution Database
-- Defines dungeon boss catalyst items, requirements, and transformed companion models/stats.

local _, FS = ...
FS.EvolutionDB = FS.EvolutionDB or {}

FS.EvolutionDB = {
    -- 🐺 Shadowfang Keep: Shadowfang Essence evolves Wolves into Slavering Worgs
    [1015] = {
        name = "Shadowfang Essence",
        itemIcon = "Spell_Shadow_GatherShadows",
        source = "Shadowfang Keep (Boss Drop)",
        requiredFamily = "Canine",
        minLevel = 18,
        resultSpecies = {
            name = "Slavering Worg",
            displayId = 4403,
            element = "Shadow",
            statBoosts = { hp = 25, atk = 18, def = 10, spd = 12 },
            learnMove = 201, -- Shadow Fang
        },
        flavor = "Dark worgen magics mutate your wolf into a towering, red-eyed shadowy worg.",
    },

    -- 🐊 Blackfathom Deeps: Hydra Bile evolves Reptiles into Ancient Snapjaws
    [1016] = {
        name = "Hydra Bile",
        itemIcon = "Spell_Nature_AbolishPoison",
        source = "Blackfathom Deeps (Aku'mai)",
        requiredFamily = "Reptile",
        minLevel = 24,
        resultSpecies = {
            name = "Ancient Snapjaw",
            displayId = 1251,
            element = "Water",
            statBoosts = { hp = 40, atk = 10, def = 30, spd = 5 },
            learnMove = 402, -- Tidal Surge
        },
        flavor = "Primordial hydra essence hardens your turtle's shell into unbreakable spiked jade.",
    },

    -- 🕷️ Razorfen Kraul: Venomous Gland evolves Scorpids into Deathstalkers
    [1017] = {
        name = "Venomous Gland",
        itemIcon = "Spell_Nature_CorrosiveBreath",
        source = "Razorfen Kraul (Death Speaker Jargba)",
        requiredFamily = "Scorpid",
        minLevel = 28,
        resultSpecies = {
            name = "Dreadscorpid Stalker",
            displayId = 2485,
            element = "Nature",
            statBoosts = { hp = 20, atk = 22, def = 24, spd = 8 },
            learnMove = 501, -- Poison Sting
        },
        flavor = "Concentrated venom thickens the chitin and turns the tail into a lethal stinger.",
    },

    -- ⚙️ Deadmines: Overclocked Core evolves Harvest Watchers into War Shredders
    [1018] = {
        name = "Overclocked Core",
        itemIcon = "Trade_Engineering",
        source = "Deadmines (Sneed's Shredder)",
        requiredFamily = "Mechanical",
        minLevel = 16,
        resultSpecies = {
            name = "Prototype War Golem",
            displayId = 378,
            element = "Mechanical",
            statBoosts = { hp = 30, atk = 25, def = 20, spd = 10 },
            learnMove = 602, -- Overclock
        },
        flavor = "Sneed's experimental gyro-core supercharges the internal clockwork gears.",
    },
    -- 🔥 Wailing Caverns: Volcanic Core evolves Fire & Elementals
    [1019] = {
        name = "Volcanic Core",
        itemIcon = "Spell_Fire_LavaSpawn",
        source = "Wailing Caverns / BRD",
        requiredFamily = "Elemental",
        minLevel = 20,
        resultSpecies = {
            name = "Blazing Invoker",
            displayId = 1210,
            element = "Fire",
            statBoosts = { hp = 30, atk = 30, def = 15, spd = 12 },
            learnMove = 302, -- Magma Burst
        },
        flavor = "Primal volcanic heat infuses the elemental body with incandescent magma.",
    },
}

-- Boss NPC ID to Catalyst Drop Table
FS.BossCatalystDrops = {
    [4371] = 1015, -- Shadowfang Moonwalker (SFK)
    [3887] = 1015, -- Baron Silverlaine (SFK)
    [4275] = 1015, -- Archmage Arugal (SFK)
    [4829] = 1016, -- Aku'mai (BFD)
    [4887] = 1016, -- Ghamoo-ra (BFD)
    [4428] = 1017, -- Death Speaker Jargba (RFK)
    [4424] = 1017, -- Aggem Thorncurse (RFK)
    [644]  = 1018, -- Rhahk'Zor (Deadmines)
    [643]  = 1018, -- Sneed (Deadmines)
    [3654] = 1019, -- Mutanus the Devourer (Wailing Caverns)
    [3669] = 1019, -- Lord Cobrahn (Wailing Caverns)
}

function FS:GetEvolution(catalystId)
    return self.EvolutionDB[catalystId]
end

function FS:GetBossCatalyst(npcId)
    return self.BossCatalystDrops[npcId]
end

function FS:CanEvolveCompanion(mob, catalystId)
    if not mob then
        return false, "No companion selected."
    end

    -- Rare & Legendary Spawns cannot be evolved
    if mob.isRareSpawn or mob.isBoss or mob.classification == 4 or mob.classification == 2 then
        return false, "Rare and Legendary apex creatures cannot be evolved."
    end

    local evo = self.EvolutionDB[catalystId]
    if not evo then
        return false, "Invalid evolution catalyst."
    end

    if mob.family and mob.family ~= evo.requiredFamily then
        return false, string.format("This catalyst requires a %s family companion.", evo.requiredFamily)
    end

    -- Check Attunement Rank (Must be Rank V: Bestial Symbiosis)
    local rankData = ForeverSafari.StatEngine:GetAttunementRank(mob.attunement or 0)
    if rankData.rank < 5 then
        return false, string.format("Requires Rank V: Bestial Symbiosis (Current: Rank %s - %s) to safely undergo Metamorphosis.",
            rankData.roman, rankData.title)
    end

    return true, "Eligible for metamorphosis."
end
