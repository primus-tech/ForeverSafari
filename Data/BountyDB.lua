--[[
    Forever Safari: Bounty & Research Dispatch Database (BountyDB.lua)
    Official Nesingwary research directives, research permits, and mailbox correspondence.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.BountyDB = ns.BountyDB or {}

local BountyDB = ns.BountyDB

BountyDB.DISPATCHES = {
    [1] = {
        id = 1,
        key = "welcome_dispatch",
        title = "Welcome to the Safari League!",
        sender = "Hemet Nesingwary Sr.",
        location = "Expedition HQ",
        date = "Official Commission",
        icon = "Interface\\Icons\\INV_Box_01",
        isStarter = true,
        summary = "Unbox your racial starter companion, 10 Copper Snares, 3 Copper Transport Crates, 5 Healing Salves, and 1 Revival Crystal.",
        body = "Greetings, recruit!\n\nIf you are reading this dispatch, your petition to join the Junior Safari League has been officially accepted by the Nesingwary Expedition!\n\nWhether you hail from the dense glades of Teldrassil, the red canyons of Durotar, or the snowpeaks of Dun Morogh, Azeroth is teeming with majestic wildlife waiting to be researched, bonded with, and tested in honorable battle.\n\nAttached to this parcel is your Caged Starter Companion native to your homeland, along with ten field research snares, three transport crates to ship wild catches back to the Innkeeper's Kennel, five soothing healing salves, and an emergency revival crystal. Treat your companion well, nourish it with native diets, and protect the wild balance!\n\nGood hunting,\n— Hemet Nesingwary Sr.",
        rewards = {
            tokens = 0,
            items = {
                { id = "copper_cage", count = 10 },
                { id = "crate_copper", count = 3 },
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
    [9] = {
        id = 9,
        key = "sunken_temple_dragonkin_permit",
        title = "Research Permit: Draconic Sanctuary",
        sender = "Hemet Nesingwary Sr.",
        location = "Swamp of Sorrows",
        date = "Master Directive",
        icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        questType = "KILL_DRAGONKIN_BOSS",
        targetCount = 1,
        unlocksType = "Dragonkin",
        summary = "Defeat Shade of Eranikus or the drakes in the Sunken Temple (Swamp of Sorrows) to earn the Draconic Sanctuary Permit.",
        body = "Master Naturalist,\n\nDragonkin are ancient, proud, and possess unmatched draconic scales that withstand ordinary traps and taming methods. To safely approach, research, and capture dragonkin whelps and drakes, you must prove your mastery against a true dragon of the Emerald Dream.\n\nSubmerge into the sunken Temple of Atal'Hakkar within the Swamp of Sorrows, confront the corrupted Green Dragon Shade of Eranikus, and claim the draconic focus!\n\nEvery expedition member present for the dragon's fall will be granted the Draconic Sanctuary Permit!\n\n— Hemet Nesingwary Sr.",
        rewards = {
            tokens = 60,
            items = { { id = "arcanite_capsule", count = 3 }, { id = "az_feast", count = 2 } },
        }
    },
}

function BountyDB:GetDispatch(id)
    if not id then return nil end
    return self.DISPATCHES[id]
end

function BountyDB:GetAllDispatches()
    return self.DISPATCHES
end

function BountyDB:GetCount()
    return #self.DISPATCHES
end
