# Implementation Plan: Wowhead Creature Scrape, Zone Classification & Acquisition Taxonomy Pipeline

## 1. Executive Summary & Goals
This plan details the updated automated data pipeline to extract, classify, and compile creatures across World of Warcraft into *Forever Safari*'s canonical database (`Data/CreatureDB.lua`).

### Core Architectural Pillars:
1. **Master Zone Classification**:
   - Classify all zones into **Open-World Zones** (levels 1-20, 21-40, 41-60) vs. **Instances, Raids, and Battlegrounds**.
2. **Location-Based Encounter & Acquisition Rules**:
   - **Open-World Creatures**:
     - `acquisitionMethod = "BATTLE"`
     - Engageable in wild Safari encounters / turn-based battles.
     - Catchable with Safari Nets in the field.
     - **Field Observation ENABLED**: Observing these creatures in the wild unlocks Slots 3 and 4 abilities.
   - **Instance, Raid & Battleground Creatures**:
     - `acquisitionMethod = "PUP_DROP"`
     - **NO wild Safari battles** in dungeons, raids, or battlegrounds.
     - **NO Field Observation** in dungeons, raids, or battlegrounds.
     - **Pup Drop Mechanic**: When players slay a mob in an instance, raid, or BG, there is a proc/drop chance to create/obtain a **"Pup"** (companion pup, hatchling, juvenile offspring, whelp, scrap-bot, or minion spark).
     - **Universal Applicability**: This pup drop mechanic applies across **all creature types** (Beasts, Dragonkin, Elementals, Mechanicals, Undead, Uncategorized).
3. **Beast Taxonomy Subcategory Resolution**:
   - Overcome Wowhead's 1,000-entry listing truncation by extracting all 17 authentic Hunter Pet subcategories (`bat`, `bear`, `bird-of-prey`, `boar`, `carrion-bird`, `cat`, `crab`, `crocolisk`, `gorilla`, `hyena`, `raptor`, `scorpid`, `spider`, `tallstrider`, `turtle`, `wind-serpent`, `wolf`).
   - Automatically assign authentic Hunter Family and Spec Archetype (**Tenacity**, **Ferocity**, **Cunning**).
4. **Starter Move Provisioning (Hunter Pet Model)**:
   - Exactly 2 starter abilities per companion: **1 Base Offensive + 1 Base Defensive**.
   - Slots 3 & 4 remain empty (`nil`), strictly gated behind Field Observation (for open-world creatures) or observation/training progression.
5. **Lightweight Lua Registries**:
   - Output clean, partitioned Lua tables in `Data/Creatures/` and master index in `Data/CreatureDB.lua`.

---

## 2. Acquisition & Encounter Architecture

```
                                  WOWHEAD CREATURE
                                         │
                                         ▼
                            [Check Spawn Location(s)]
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 │                                               │
                 ▼                                               ▼
      [Open-World Spawns]                             [Instance / Raid / BG Only]
                 │                                               │
     • acquisitionMethod = "BATTLE"                  • acquisitionMethod = "PUP_DROP"
     • Wild Safari Battles: YES                      • Wild Safari Battles: NO
     • Safari Net Catching: YES                      • Safari Net Catching: NO
     • Field Observation: YES                        • Field Observation: NO
     • Unlocks Moves in Slots 3 & 4                  • Slaying mob in instance has
                                                       drop chance to grant companion Pup
```

### Drop Rates & Pup Classification:
- **Standard Dungeon/Raid Trash Mob**: ~1.5% to 3.0% chance on kill to drop a companion pup/offspring.
- **Dungeon Boss**: ~10% to 15% guaranteed roll on boss defeat.
- **Raid Boss / Rare Elite**: ~20% to 25% roll on boss defeat.
- **Universal Offspring Forms**:
  - *Beasts*: Pups, Cubs, Hatchlings, Calves, Piglets.
  - *Dragonkin*: Whelps, Hatchlings, Broodlings.
  - *Elementals*: Sparks, Motes, Cores, Splinters.
  - *Mechanicals*: Micro-Golems, Scrap-Bots, Clockwork Chicks.
  - *Undead*: Bone Pups, Ghoul Pups, Spectral Wisps.

---

## 3. Data Pipeline & Execution Phases

### Phase 1: Master Zone Filter & Indexing Engine
Parse all zone endpoints to construct the complete zone lookup registry:
* **Instances & Raids & Battlegrounds**:
  - Dungeons (`/forever/zones/instances/dungeons` - 46 zones)
  - Raids (`/forever/zones/instances/raids` - 22 zones)
  - Battlegrounds & Arenas (Alterac Valley, Arathi Basin, Warsong Gulch, Darkspear Islands, etc.)
  - Tag: `isInstance = true`, `zoneType = "dungeon" | "raid" | "bg"`
* **Open-World Zones**:
  - Level bands 1-20 (`/forever/zones/levels-1-20` - 28 zones)
  - Level bands 21-40 (`/forever/zones/levels-21-40` - 28 zones)
  - Level bands 41-60 (`/forever/zones/levels-41-60` - 44 zones)
  - Tag: `isInstance = false`, `zoneType = "open_world"`

---

### Phase 2: NPC Extraction & Categorization

#### A. Beast Extraction via 17 Hunter Subcategories
To prevent the 1,000-item query limit from cutting off 700+ beasts, we extract every subcategory individually:
1. `bat` (Cunning)
2. `bear` (Tenacity)
3. `bird-of-prey` (Cunning)
4. `boar` (Tenacity)
5. `carrion-bird` (Ferocity)
6. `cat` (Ferocity)
7. `crab` (Tenacity)
8. `crocolisk` (Tenacity)
9. `gorilla` (Tenacity)
10. `hyena` (Ferocity)
11. `raptor` (Ferocity)
12. `scorpid` (Tenacity)
13. `spider` (Cunning)
14. `tallstrider` (Ferocity)
15. `turtle` (Tenacity)
16. `wind-serpent` (Ferocity)
17. `wolf` (Ferocity)

#### B. Additional Creature Families
- **Dragonkin** (`/forever/npcs/dragonkin` - 305 NPCs)
- **Elementals** (`/forever/npcs/elementals` - 551 NPCs)
- **Mechanicals** (`/forever/npcs/mechanicals` - 214 NPCs)
- **Undead** (`/forever/npcs/undead` - 983 NPCs)
- **Uncategorized** (`/forever/npcs/uncategorized` - Filtered wildlife/critters)

#### C. Cross-Referencing Location & Acquisition Flagging
For every creature:
```python
is_world = any(zid in world_zones for zid in npc.location)
is_instance = any(zid in instance_zones for zid in npc.location)

if is_world and not is_instance:
    npc.acquisition = "BATTLE"
    npc.allow_battle = True
    npc.allow_observation = True
elif is_instance and not is_world:
    npc.acquisition = "PUP_DROP"
    npc.allow_battle = False
    npc.allow_observation = False
    npc.pup_drop_rate = calculate_drop_rate(npc)
else: # Dual spawns (e.g. world bosses or dungeon trash with open world equivalents)
    npc.acquisition = "HYBRID"
    npc.allow_battle = True        # In open world only
    npc.allow_observation = True   # In open world only
    npc.pup_drop_rate = calculate_drop_rate(npc) # When slain in instance
```

---

### Phase 3: Sentience & Non-Sentient Sanitizer
* **Excluded**:
  - Humanoid NPC dialogue actors / quest givers / merchants / trainers (`tag` contains `<Merchant>`, `<Trainer>`, `<Quest>`).
  - Forsaken citizens, death knights, humanoid dragonkin officers/drakonids with polearms, sentient humanoid boss models.
* **Retained**:
  - Mindless undead (Ghouls, Skeletal Warhorses, Plaguespiders, Skeletons).
  - Wild dragons, drakes, whelps, faerie dragons.
  - Elemental spirits, tar beasts, water/fire elementals.
  - Autonomous mechs, harvest golems, alarm-o-bots, clockwork spiders.

---

### Phase 4: Starter Move Provisioning (2 Instincts)

Every companion receives exactly 2 baseline abilities based on its archetype and family:

| Archetype | Spec Focus | Starter Slot 1 (Offensive) | Starter Slot 2 (Defensive) | Slot 3 | Slot 4 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Tenacity** | Defense / Mitigation | `Bite` or `Claw` (Power 40) | `Thick Hide` (Damage Absorb / Def Up) | `nil` | `nil` |
| **Ferocity** | Burst DPS / Crits | `Claw` or `Rake` (Power 40) | `Harden` or `Bloodline Roar` (Atk/Crit Up) | `nil` | `nil` |
| **Cunning** | Speed / Control | `Peck` or `Bite` (Power 40) | `Quick Reflexes` or `Dodge` (Evasion Up) | `nil` | `nil` |
| **Dragonkin** | Magic / Breath | `Breath` (Elemental Dmg 40) | `Scales of Iron` (Magic Resist / Shield) | `nil` | `nil` |
| **Elemental** | Elemental Spells | `Elemental Blast` (Power 40) | `Elemental Barrier` (Shield / Ward) | `nil` | `nil` |
| **Mechanical** | Precision / Tech | `Tinker Spark` (Power 40) | `Armor Plating` (Armor Boost) | `nil` | `nil` |
| **Undead** | Shadow / Plague | `Bone Bite` or `Rot` (Power 40) | `Unholy Fortitude` (Life Drain / Ward) | `nil` | `nil` |

*Note: Slots 3 and 4 are strictly empty (`nil`), reserved for unlocks via Open-World Field Observation or Companion Pup Nurturing.*

---

### Phase 5: Codebase Emission & Lua Integration

1. **`Data/Creatures/Creatures_Beasts.lua`**: All 17 Hunter families, tagged with `spec`, `family`, `acquisition`, `location`.
2. **`Data/Creatures/Creatures_Dragonkin.lua`**: Dragonkin entries with whelp/pup drop mechanics.
3. **`Data/Creatures/Creatures_Elementals.lua`**: Elemental spirits and spark drops.
4. **`Data/Creatures/Creatures_Mechanicals.lua`**: Constructs and scrap-bot drops.
5. **`Data/Creatures/Creatures_Undead.lua`**: Skeletal companions and minion pup drops.
6. **`Data/CreatureDB.lua`**: Master lookup registry with query helpers:
   - `CreatureDB:GetCreaturesByZone(zoneID)`
   - `CreatureDB:IsInstanceOnly(creatureID)`
   - `CreatureDB:CanEncounterInBattle(creatureID)`
   - `CreatureDB:GetPupDropInfo(creatureID)`
7. **Instance Slay Hook (`Core/SafariInstanceDrops.lua`)**:
   - Hooks `COMBAT_LOG_EVENT_UNFILTERED` inside instances/raids/BGs.
   - On `UNIT_DIED`, looks up slain creature in `CreatureDB`.
   - If `creature.pupDropRate` procs, spawns/awards companion Pup to party/player!
