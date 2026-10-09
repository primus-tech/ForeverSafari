--[[
    Forever Safari: Data - NPC Rival Trainer Archetypes (TrainerDB.lua)
    Defines humanoid faction archetypes, intro/defeat quotes, title designations,
    and themed companion rosters for roaming AI trainer battles across Azeroth.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.TrainerDB = ns.TrainerDB or {}

local TrainerDB = ns.TrainerDB

TrainerDB.ARCHETYPES = {
    ["Defias"] = {
        title = "Defias Outlaw",
        intro = "You walked right into our territory, adventurer!",
        defeat = "Blast it! My cutthroats were bested...",
        tokenReward = 8,
        pool = {
            { name = "Mangy Wolf", family = "Canine", element = "Beast", displayId = 903, baseStats = { hp = 40, atk = 22, def = 18, spd = 20 }, moves = { 101, 104 } },
            { name = "Harvest Golem", family = "Mechanical", element = "Mechanical", displayId = 378, baseStats = { hp = 44, atk = 20, def = 24, spd = 12 }, moves = { 601, 602 } },
            { name = "Mine Spider", family = "Spider", element = "Beast", displayId = 382, baseStats = { hp = 38, atk = 20, def = 18, spd = 24 }, moves = { 501, 502 } },
            { name = "Goretusk Boar", family = "Boar", element = "Beast", displayId = 138623, baseStats = { hp = 42, atk = 20, def = 22, spd = 16 }, moves = { 108, 107 } },
        }
    },
    ["Kobold"] = {
        title = "Kobold Prospector",
        intro = "You no take candle! My beasts chew you up!",
        defeat = "Eeeek! Take anything, just leave candle!",
        tokenReward = 6,
        pool = {
            { name = "Mine Spider", family = "Spider", element = "Beast", displayId = 368, baseStats = { hp = 38, atk = 20, def = 18, spd = 24 }, moves = { 501, 502 } },
            { name = "Tar Elemental", family = "Elemental", element = "Elemental", displayId = 1146, baseStats = { hp = 36, atk = 26, def = 18, spd = 20 }, moves = { 801, 802 } },
            { name = "Tunnel Rat", family = "Canine", element = "Beast", displayId = 903, baseStats = { hp = 38, atk = 22, def = 16, spd = 24 }, moves = { 101, 107 } },
            { name = "Cave Bat", family = "Bat", element = "Flying", displayId = 9535, baseStats = { hp = 35, atk = 22, def = 15, spd = 28 }, moves = { 202, 709 } },
        }
    },
    ["Murloc"] = {
        title = "Murloc Tidecaller",
        intro = "Mrgggllbrlg! Aaaaaughibbrgubugbugrguburgle!",
        defeat = "Mrgllll... glub...",
        tokenReward = 8,
        pool = {
            { name = "Reef Crab", family = "Crab", element = "Aquatic", displayId = 724, baseStats = { hp = 42, atk = 18, def = 26, spd = 14 }, moves = { 401, 402 } },
            { name = "Shore Frenzy", family = "Aquatic", element = "Aquatic", displayId = 1530, baseStats = { hp = 36, atk = 26, def = 16, spd = 22 }, moves = { 401, 509 } },
            { name = "River Crocolisk", family = "Crocolisk", element = "Aquatic", displayId = 1386, baseStats = { hp = 46, atk = 20, def = 22, spd = 12 }, moves = { 401, 1005 } },
            { name = "Snapjaw Turtle", family = "Turtle", element = "Aquatic", displayId = 1386, baseStats = { hp = 48, atk = 16, def = 26, spd = 10 }, moves = { 401, 402 } },
        }
    },
    ["Gnoll"] = {
        title = "Riverpaw Packleader",
        intro = "Grrrr! Fresh meat for the pack!",
        defeat = "Yip! Yip! Pack falls back!",
        tokenReward = 8,
        pool = {
            { name = "Spotted Hyena", family = "Canine", element = "Beast", displayId = 2221, baseStats = { hp = 40, atk = 24, def = 16, spd = 20 }, moves = { 101, 104 } },
            { name = "Forest Wolf", family = "Canine", element = "Beast", displayId = 903, baseStats = { hp = 40, atk = 22, def = 18, spd = 20 }, moves = { 101, 107 } },
            { name = "Redridge Vulture", family = "Flying", element = "Flying", displayId = 2004, baseStats = { hp = 35, atk = 22, def = 15, spd = 28 }, moves = { 202, 709 } },
        }
    },
    ["Centaur"] = {
        title = "Kolkar Beast-Caller",
        intro = "The plains bow to the Khan! Slay the intruder!",
        defeat = "The spirits of the plains have forsaken me...",
        tokenReward = 10,
        pool = {
            { name = "Savannah Hyena", family = "Canine", element = "Beast", displayId = 2221, baseStats = { hp = 40, atk = 24, def = 16, spd = 20 }, moves = { 101, 104 } },
            { name = "Barrens Kodo", family = "Kodo", element = "Beast", displayId = 1451, baseStats = { hp = 48, atk = 18, def = 22, spd = 12 }, moves = { 108, 102 } },
            { name = "Sunscale Raptor", family = "Raptor", element = "Beast", displayId = 1960, baseStats = { hp = 36, atk = 26, def = 16, spd = 22 }, moves = { 103, 121 } },
            { name = "Thunderhead Serpent", family = "Dragonkin", element = "Dragonkin", displayId = 2769, baseStats = { hp = 38, atk = 24, def = 18, spd = 20 }, moves = { 901, 902 } },
        }
    },
    ["Scarlet"] = {
        title = "Scarlet Kennelmaster",
        intro = "By the Holy Light, cleanse these wretched beasts!",
        defeat = "Impossible... our Crusade will not falter!",
        tokenReward = 12,
        pool = {
            { name = "Scarlet Warhound", family = "Canine", element = "Beast", displayId = 1531, baseStats = { hp = 42, atk = 24, def = 18, spd = 16 }, moves = { 101, 104 } },
            { name = "Scarlet Hawk", family = "Flying", element = "Flying", displayId = 1629, baseStats = { hp = 35, atk = 24, def = 14, spd = 27 }, moves = { 202, 709 } },
            { name = "Monastery War Bear", family = "Bear", element = "Beast", displayId = 8843, baseStats = { hp = 46, atk = 20, def = 22, spd = 12 }, moves = { 101, 102 } },
        }
    },
    ["DarkIron"] = {
        title = "Dark Iron Engineer",
        intro = "Feast your eyes on Dark Iron mechanical superiority!",
        defeat = "Blast it! My gears are ruined!",
        tokenReward = 12,
        pool = {
            { name = "Compact Harvester", family = "Mechanical", element = "Mechanical", displayId = 1147, baseStats = { hp = 44, atk = 20, def = 24, spd = 12 }, moves = { 601, 602 } },
            { name = "Lava Elemental", family = "Elemental", element = "Elemental", displayId = 862, baseStats = { hp = 36, atk = 26, def = 18, spd = 20 }, moves = { 801, 802 } },
            { name = "Mountain Bear", family = "Bear", element = "Beast", displayId = 8843, baseStats = { hp = 45, atk = 20, def = 20, spd = 15 }, moves = { 101, 102 } },
        }
    },
    ["Cultist"] = {
        title = "Cultist Necromancer",
        intro = "The darkness hungers! Witness the glory of the Scourge!",
        defeat = "Death is only the beginning...",
        tokenReward = 14,
        pool = {
            { name = "Plague Rat", family = "Undead", element = "Undead", displayId = 2402, baseStats = { hp = 42, atk = 20, def = 18, spd = 20 }, moves = { 301, 302 } },
            { name = "Skeletal Hound", family = "Undead", element = "Undead", displayId = 1531, baseStats = { hp = 40, atk = 24, def = 18, spd = 18 }, moves = { 301, 104 } },
            { name = "Shadow Duskbat", family = "Bat", element = "Flying", displayId = 9535, baseStats = { hp = 35, atk = 22, def = 15, spd = 28 }, moves = { 301, 709 } },
        }
    },
    ["Syndicate"] = {
        title = "Syndicate Conspirator",
        intro = "Nothing personal... just business.",
        defeat = "Tch. Contract forfeited.",
        tokenReward = 10,
        pool = {
            { name = "Mountain Cougar", family = "Feline", element = "Beast", displayId = 11454, baseStats = { hp = 36, atk = 26, def = 16, spd = 22 }, moves = { 103, 107 } },
            { name = "Highland Wolf", family = "Canine", element = "Beast", displayId = 903, baseStats = { hp = 40, atk = 22, def = 18, spd = 20 }, moves = { 101, 104 } },
            { name = "Shadow Spider", family = "Spider", element = "Beast", displayId = 382, baseStats = { hp = 38, atk = 20, def = 18, spd = 24 }, moves = { 501, 502 } },
        }
    },
    ["Pirate"] = {
        title = "Bloodsail Deckhand",
        intro = "Avast! Hand over your tokens or walk the plank!",
        defeat = "Shiver me timbers... my crew is down!",
        tokenReward = 10,
        pool = {
            { name = "Tropical Parrot", family = "Flying", element = "Flying", displayId = 2004, baseStats = { hp = 35, atk = 24, def = 14, spd = 27 }, moves = { 202, 709 } },
            { name = "Shore Crab", family = "Crab", element = "Aquatic", displayId = 724, baseStats = { hp = 42, atk = 18, def = 26, spd = 14 }, moves = { 401, 402 } },
            { name = "Saltwater Crocolisk", family = "Crocolisk", element = "Aquatic", displayId = 1386, baseStats = { hp = 46, atk = 20, def = 22, spd = 12 }, moves = { 401, 1005 } },
        }
    },
    ["Troll"] = {
        title = "Voodoo Beastmaster",
        intro = "Da Loa spirits gonna tear ya to pieces, mon!",
        defeat = "Da Loa... why ya forsake me?",
        tokenReward = 10,
        pool = {
            { name = "Jungle Raptor", family = "Raptor", element = "Beast", displayId = 1960, baseStats = { hp = 36, atk = 26, def = 16, spd = 22 }, moves = { 103, 121 } },
            { name = "Jungle Tiger", family = "Feline", element = "Beast", displayId = 11454, baseStats = { hp = 36, atk = 26, def = 16, spd = 22 }, moves = { 103, 107 } },
            { name = "Emerald Wind Serpent", family = "Dragonkin", element = "Dragonkin", displayId = 2769, baseStats = { hp = 38, atk = 24, def = 18, spd = 20 }, moves = { 901, 902 } },
        }
    },
    ["Ogre"] = {
        title = "Ogre Behemoth",
        intro = "Ogre smash puny hunter! My pets eat you!",
        defeat = "Ow! Ogre head hurt...",
        tokenReward = 12,
        pool = {
            { name = "Heavy War Boar", family = "Boar", element = "Beast", displayId = 138623, baseStats = { hp = 44, atk = 22, def = 22, spd = 12 }, moves = { 108, 107 } },
            { name = "Boulder Bear", family = "Bear", element = "Beast", displayId = 8843, baseStats = { hp = 48, atk = 20, def = 22, spd = 10 }, moves = { 101, 102 } },
            { name = "Mountain Gorilla", family = "Gorilla", element = "Beast", displayId = 478, baseStats = { hp = 44, atk = 22, def = 20, spd = 14 }, moves = { 101, 108 } },
        }
    },
    ["Nesingwary"] = {
        title = "Nesingwary Safari Huntsman",
        intro = "Let's see if your safari training holds up against seasoned expedition veterans!",
        defeat = "Splendid form! You're a true safari master!",
        tokenReward = 20,
        pool = {
            { name = "Stranglethorn Tiger", family = "Feline", element = "Beast", displayId = 11454, baseStats = { hp = 36, atk = 28, def = 16, spd = 20 }, moves = { 103, 107 } },
            { name = "Jungle Stalker Raptor", family = "Raptor", element = "Beast", displayId = 1960, baseStats = { hp = 36, atk = 26, def = 16, spd = 22 }, moves = { 103, 121 } },
            { name = "Apex River Crocolisk", family = "Crocolisk", element = "Aquatic", displayId = 1386, baseStats = { hp = 46, atk = 22, def = 22, spd = 10 }, moves = { 401, 1005 } },
        }
    },
    ["Default"] = {
        title = "Wandering Safari Rival",
        intro = "A companion duel? Let's see whose beasts are stronger!",
        defeat = "Good match! Your companion has great attunement.",
        tokenReward = 8,
        pool = {
            { name = "Prowler Wolf", family = "Canine", element = "Beast", displayId = 903, baseStats = { hp = 40, atk = 22, def = 18, spd = 20 }, moves = { 101, 104 } },
            { name = "Prairie Hawk", family = "Flying", element = "Flying", displayId = 1629, baseStats = { hp = 35, atk = 22, def = 15, spd = 28 }, moves = { 202, 709 } },
            { name = "River Snapjaw", family = "Turtle", element = "Aquatic", displayId = 1386, baseStats = { hp = 48, atk = 16, def = 26, spd = 10 }, moves = { 401, 402 } },
        }
    }
}

local function isSecret(v)
    if v == nil then return false end
    if issecretpassphrase and issecretpassphrase(v) then return true end
    if type(v) == "userdata" or type(v) == "table" then
        local mt = getmetatable(v)
        if mt and type(mt) == "string" and mt == "secret" then return true end
    end
    return false
end

function TrainerDB:GetArchetypeForUnit(unitName, unitType, zoneName)
    if not unitName or isSecret(unitName) or type(unitName) ~= "string" then return self.ARCHETYPES["Default"] end
    local lower = string.lower(unitName)
    local lowerZone = (zoneName and not isSecret(zoneName) and type(zoneName) == "string") and string.lower(zoneName) or ""

    if string.find(lower, "defias") or string.find(lower, "brigand") or string.find(lower, "thief") or string.find(lower, "highwayman") then
        return self.ARCHETYPES["Defias"]
    elseif string.find(lower, "kobold") or string.find(lower, "tunnel rat") or string.find(lower, "geomancer") then
        return self.ARCHETYPES["Kobold"]
    elseif string.find(lower, "murloc") or string.find(lower, "puddlejumper") or string.find(lower, "tidecaller") or string.find(lower, "oracle") then
        return self.ARCHETYPES["Murloc"]
    elseif string.find(lower, "gnoll") or string.find(lower, "riverpaw") or string.find(lower, "mosshide") or string.find(lower, "mudsnout") then
        return self.ARCHETYPES["Gnoll"]
    elseif string.find(lower, "centaur") or string.find(lower, "kolkar") or string.find(lower, "galak") or string.find(lower, "magram") then
        return self.ARCHETYPES["Centaur"]
    elseif string.find(lower, "scarlet") or string.find(lower, "crusader") or string.find(lower, "zealot") then
        return self.ARCHETYPES["Scarlet"]
    elseif string.find(lower, "dark iron") or string.find(lower, "sapper") or string.find(lower, "darkiron") then
        return self.ARCHETYPES["DarkIron"]
    elseif string.find(lower, "cultist") or string.find(lower, "necromancer") or string.find(lower, "deathguard") or string.find(lower, "acolyte") then
        return self.ARCHETYPES["Cultist"]
    elseif string.find(lower, "syndicate") or string.find(lower, "conspirator") or string.find(lower, "shadowfoot") then
        return self.ARCHETYPES["Syndicate"]
    elseif string.find(lower, "pirate") or string.find(lower, "bloodsail") or string.find(lower, "swashbuckler") or string.find(lower, "deckhand") or string.find(lower, "freebooter") then
        return self.ARCHETYPES["Pirate"]
    elseif string.find(lower, "troll") or string.find(lower, "witherbark") or string.find(lower, "bloodscalp") or string.find(lower, "skullsplitter") then
        return self.ARCHETYPES["Troll"]
    elseif string.find(lower, "ogre") or string.find(lower, "enforcer") or string.find(lower, "brute") or string.find(lower, "mauler") then
        return self.ARCHETYPES["Ogre"]
    elseif string.find(lower, "nesingwary") or string.find(lower, "huntsman") or string.find(lower, "poacher") or string.find(lower, "tracker") then
        return self.ARCHETYPES["Nesingwary"]
    end

    return self.ARCHETYPES["Default"]
end
