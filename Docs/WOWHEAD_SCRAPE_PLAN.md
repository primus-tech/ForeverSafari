# Implementation Plan: Wowhead Open-World Creature Scrape & Siloing Pipeline

## 1. Executive Summary & Goals
This plan details the end-to-end automated data pipeline to extract, sanitize, and compile all open-world wild creatures across World of Warcraft into *Forever Safari*'s canonical database (`Data/CreatureDB.lua`).

### Core Objectives:
1. **Zero Dungeon / Raid / PvP Leaks**: Automatically exclude any creature that only spawns inside 5-man instances, raids, battlegrounds, or arenas.
2. **Strict Non-Sentient Verification**: Filter out sentient/humanoid creatures (e.g., Forsaken quest-givers, Dragonspawn generals, humanoid boss encounters).
3. **Beast Family & Spec Siloing**: Classify every beast into its authentic WoW Hunter family (Bear, Cat, Wolf, etc.) and assign its foundational spec (**Tenacity**, **Ferocity**, **Cunning**).
4. **Two-Move Instinct Provisioning**: Ensure every entry is equipped with **exactly 2 starter instincts** (1 Base Offensive + 1 Base Defensive), leaving Slots 3 and 4 empty for field observation.
5. **Lightweight Lua Registries**: Generate clean, optimized Lua tables split by creature type with zero runtime overhead.

---

## 2. Scraping Architecture & Data Pipeline

```
+---------------------------------------------------------------------------------+
|                               WOWHEAD DATA SOURCE                               |
|  - NPCs by Type: Beasts (1), Dragonkin (2), Elementals (4), Undead (6), Mechs (9)|
+---------------------------------------------------------------------------------+
                                        │
                                        ▼
+---------------------------------------------------------------------------------+
|                        STAGE 1: ZONE EXCLUSION ENGINE                           |
|  - Query creature spawn locations against Master Zone Filter                    |
|  - Discard NPCs exclusively located in Instances, Raids, BGs, or Arenas         |
+---------------------------------------------------------------------------------+
                                        │
                                        ▼
+---------------------------------------------------------------------------------+
|                    STAGE 2: SENTIENCE & SUBFAMILY SANITIZER                     |
|  - Verify non-sentient sub-family tags (e.g. Scourge Hound vs Forsaken)         |
|  - Tag Beast Subcategories: Cat, Bear, Wolf, Raptor, Spider, Turtle, Boar, etc.  |
+---------------------------------------------------------------------------------+
                                        │
                                        ▼
+---------------------------------------------------------------------------------+
|                    STAGE 3: SPEC & STAT ENGINE ASSIGNMENT                       |
|  - Tenacity (Tank)   : Bear, Turtle, Boar, Crab, Gorilla, Crocolisk, Beetle     |
|  - Ferocity (DPS)    : Cat, Raptor, Wolf, Wind Serpent, Hyena, Core Hound       |
|  - Cunning (Control) : Spider, Bat, Bird of Prey, Serpent, Fox, Monkey          |
|  - Baseline Moves    : Slot 1 (Offensive) + Slot 2 (Defensive)                  |
+---------------------------------------------------------------------------------+
                                        │
                                        ▼
+---------------------------------------------------------------------------------+
|                    STAGE 4: LUA COMPILER & EMITTER                              |
|  - Export to modular data files in Data/Creatures/                              |
|  - Generate master index in Data/CreatureDB.lua                                 |
+---------------------------------------------------------------------------------+
```

---

## 3. Detailed Execution Phases

### Phase 1: Master Zone Filter & Exclusion Registry
We will compile a comprehensive list of all known instances, raids, battlegrounds, and arenas.

* **Exclusion Criteria**:
  * Any zone flagged with instance type `Party`, `Raid`, `PvP`, or `Arena`.
  * Known classic and modern dungeons: Deadmines, Wailing Caverns, Shadowfang Keep, Blackfathom Deeps, Gnomeregan, Scarlet Monastery, Razorfen Kraul/Downs, Uldaman, Zul'Farrak, Maraudon, Sunken Temple, Blackrock Depths, Stratholme, Scholomance, Dire Maul.
  * Known raids: Molten Core, Onyxia, Blackwing Lair, Zul'Gurub, Ahn'Qiraj, Naxxramas.
  * Battlegrounds: Warsong Gulch, Arathi Basin, Alterac Valley, Eye of the Storm.
* **Open-World Acceptance**:
  * An NPC is accepted if it has at least one confirmed spawn coordinate in an open outdoor zone (e.g., Elwynn Forest, The Barrens, Stranglethorn Vale, Winterspring, Tanaris, Ashenvale).

---

### Phase 2: Category & Non-Sentient Taxonomy Rules

| Creature Type | Wowhead Type ID | Allowed Sub-Families (Non-Sentient) | Excluded (Sentient / Ineligible) |
| :--- | :--- | :--- | :--- |
| **Beast** | `1` | All natural wild animals (Canines, Felines, Ursines, Raptors, Spiders, Rodents, Crocolisks, Bats, etc.) | Humanoid druids in beast forms with dialogue / quest roles. |
| **Dragonkin** | `2` | Whelps, Drakes, Proto-Drakes, Faerie Dragons, Dragonhawks, Netherdrakes | Drakonids, Dragonspawn with armor/weapons, humanoid Dragon aspects. |
| **Elemental** | `4` | Water Elementals, Fire Elementals, Tar Beasts, Earth Elementals, Air Sparks, Geodites | Elemental Lords, sentient shamans/speakers, Ascendants. |
| **Undead** | `6` | Plaguespiders, Scourge Hounds, Mindless Ghouls, Skeletal Raptors, Plagued Bears, Zombies | Forsaken NPCs, Death Knights, Liches, Vampyr, sentient ghosts. |
| **Mechanical** | `9` | Harvest Golems, Mech-striders, Clockwork Birds, Alarm-o-bots, Shredders, Robo-chickens | Sentient cyborgs, Mechagnome citizens, player vehicles. |

---

### Phase 3: Beast Spec & Baseline Move Provisioning

Each family automatically receives its authentic Hunter specialization and starting instincts:

#### 1. Tenacity (The Tanks)
* **Families**: Bear, Turtle, Crab, Boar, Gorilla, Crocolisk, Beetle, Rhino, Basilisk.
* **Archetype Focus**: Maximum HP, armor mitigation, threat, crowd disruption.
* **Starting Moves**:
  - Slot 1: **`Claw`** or **`Bite`** *(Mundane • Offensive • Direct — 40 Power)*
  - Slot 2: **`Thick Hide`** *(Mundane • Defensive • Direct — Damage absorption / defense boost)*
  - Slots 3 & 4: `nil` *(Empty — unlocked via Field Observation)*
* **Silo Constraints**: Prohibited from equipping *Prowl*, *Cower*, or *Dash*.

#### 2. Ferocity (The Strikers)
* **Families**: Cat, Raptor, Wolf, Wind Serpent, Hyena, Core Hound, Wasp, Carrion Bird.
* **Archetype Focus**: Physical attack power, critical strike, bleed afflictions.
* **Starting Moves**:
  - Slot 1: **`Bite`** or **`Claw`** *(Mundane • Offensive • Direct — 40 Power)*
  - Slot 2: **`Lick Wounds`** *(Mundane • Defensive • Over Time — Minor HoT restoration)*
  - Slots 3 & 4: `nil` *(Empty — unlocked via Field Observation)*
* **Silo Constraints**: Prohibited from equipping hard mitigation shields like *Shell Shield*.

#### 3. Cunning (The Controllers)
* **Families**: Spider, Bat, Bird of Prey, Serpent, Fox, Monkey, Moth.
* **Archetype Focus**: Speed control, crowd control, evasive mobility, poisons.
* **Starting Moves**:
  - Slot 1: **`Nip`** or **`Bite`** *(Mundane • Offensive • Direct — 40 Power)*
  - Slot 2: **`Cower`** / **`Evasive Reflexes`** *(Mundane • Defensive • Direct — Damage mitigation)*
  - Slots 3 & 4: `nil` *(Empty — unlocked via Field Observation)*
* **Silo Constraints**: Prohibited from equipping *Thick Fur* or *Last Stand*.

---

### Phase 4: Scraper Script Implementation (`scratch/scrape_openworld_creatures.py`)

A robust Python extraction script utilizing structured caching and rate limiting:

1. **Local Checkpointing**: Saves raw JSON snapshots in `scratch/cache/` so network interruptions never lose progress.
2. **Polite Request Throttling**: 0.5s to 1.0s delays between Wowhead query requests to prevent IP blocks.
3. **Data Extraction Schema**:
   ```python
   {
       "id": 1199,
       "name": "Ironfur Bear",
       "type": "Beast",
       "family": "Bear",
       "spec": "Tenacity",
       "minLevel": 11,
       "maxLevel": 12,
       "displayId": 903,
       "zones": ["Darkshore"],
       "moves": [101, 108], # Slot 1: Bite/Maul, Slot 2: Thick Hide
   }
   ```
4. **Sanity Audit**: Python verification script to ensure 100% of generated records have valid names, positive levels, existing zones, and zero syntax errors.

---

### Phase 5: Lua Table Generation & Addon Integration

The script outputs modular Lua data files directly into `ForeverSafari`:
* `Data/Creatures/Beasts.lua` — All siloed wild beasts categorized by family.
* `Data/Creatures/Elementals.lua` — Wild open-world elementals.
* `Data/Creatures/Dragonkin.lua` — Wild whelps, drakes, and faerie dragons.
* `Data/Creatures/Mechanicals.lua` — Wild golems, shredders, and constructs.
* `Data/Creatures/Undead.lua` — Non-sentient scourge beasts and ghouls.
* `Data/CreatureDB.lua` — Master index binding all modules to `ForeverSafari.CreatureDB`.

---

## 4. Verification & Validation Plan

1. **Exclusion Check**: Validate that dungeon-only mobs (e.g., *Cookie the Cook*, *Mutanus the Devourer*, *Garr*, *Baron Rivendare*) are 100% absent.
2. **Move Count Integrity**: Validate that every single scraped creature starts with exactly 2 moves (Slot 1 Offensive, Slot 2 Defensive) and zero 3rd or 4th moves.
3. **Beast Family Siloing Audit**: Run an automated check verifying that no Bear has *Cower*, no Turtle has *Prowl*, and no Cat has *Shell Shield*.
4. **Client Loading Test**: Run `/reload` in game, verify that `ForeverSafari` boots cleanly with zero frame hitches or Lua memory pressure.
