# 📊 Forever Safari — Data Pipeline, Zone Classification & Acquisition Taxonomy
**The Canonical Architecture for Open-World Encounters, Instance Pup Drops & Hunter Pet Taxonomy**  
*World of Warcraft: Forever (`_classic_beta_` / `dataEnv: 16`)*

---

## 1. Executive Summary & Architecture
This specification details the data architecture to classify, compile, and provision creatures across Azeroth into *Forever Safari*'s canonical database (`Data/CreatureDB.lua`).

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
     - **Applicability**: Applies across **all valid companion families** (Beasts, Dragonkin, Elementals, Mechanicals).
     - **Sentient Undead Reclassified**: Skeletons, Ghouls, Zombies, and Ghosts are strictly **AI Rival Trainers** and never drop companion pups. Plagued beasts (e.g. Shadowfang wolves) drop as Beast pups.
3. **Beast Taxonomy Subcategory Resolution**:
   - Overcome Wowhead's 1,000-entry listing truncation by extracting all 19 authentic Hunter Pet subcategories (`bat`, `bear`, `bird-of-prey`, `boar`, `carrion-bird`, `cat`, `crab`, `crocolisk`, `gorilla`, `hyena`, `raptor`, `scorpid`, `spider`, `tallstrider`, `turtle`, `wind-serpent`, `wolf`, `hydra`, `scalehide`).
   - **Scalehide**: Unifies **Kodos**, **Thunder Lizards**, and **Stegodons** under an armor-plated Tenacity spec.
   - **Hydra**: Distinct apex multi-headed Ferocity family.
   - **Purely Aquatic Exclusion**: Water-bound swimming fauna (**Threshers**, **Sharks**, **Frenzy Fish**, **Eels**) are strictly untamable and excluded from Safari battles. Only amphibious species with land locomotion (**Crabs**, **Crocolisks**, **Turtles**) are capturable.
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
  - *Sentient Undead / Humanoids*: ⛔ Excluded (Rival Trainers only; zero companion pup drops).

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

### Phase 2: NPC Extraction & The Two-Pass Cross-Check Pipeline

To defeat Wowhead's 1,000-entity query truncation while maintaining 100% accurate zone-by-zone ecological alignment and subfamily attribution, ingestion executes across two complementary passes:

#### Pass 1: Zone Census (`npcs?filter=6;{zoneId};0`)
* Scrapes all mobs per zone (~60 zones total, polite 5.0s throttle, ~5 minutes total).
* Captures all zone wildlife (`type: 1, 2, 4, 9`) and AI trainer candidates (`type: 7, 6`).
* Single zones rarely exceed 200–400 total NPCs, so Pass 1 never triggers Wowhead's 1,000-item truncation cap.

#### Pass 2: Family & Subfamily Taxonomy
* **19 Hunter Pet Subfamilies (`/forever/npcs/beasts/{subfamily}`)**: To prevent the 1,000-item query limit from cutting off 700+ beasts, extract all 19 subfamilies individually using Wowhead's verified slug structure:
  1. `bat` (ID 24 - Cunning) ➔ `https://www.wowhead.com/forever/npcs/beasts/bat`
  2. `bear` (ID 4 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/bear`
  3. `bird-of-prey` (ID 26 - Cunning) ➔ `https://www.wowhead.com/forever/npcs/beasts/bird-of-prey`
  4. `boar` (ID 5 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/boar`
  5. `carrion-bird` (ID 7 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/carrion-bird`
  6. `cat` (ID 2 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/cat`
  7. `crab` (ID 8 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/crab`
  8. `crocolisk` (ID 6 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/crocolisk`
  9. `gorilla` (ID 9 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/gorilla`
  10. `hyena` (ID 25 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/hyena`
  11. `raptor` (ID 11 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/raptor`
  12. `scorpid` (ID 20 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/scorpid`
  13. `spider` (ID 3 - Cunning) ➔ `https://www.wowhead.com/forever/npcs/beasts/spider`
  14. `tallstrider` (ID 12 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/tallstrider`
  15. `turtle` (ID 21 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/turtle`
  16. `wind-serpent` (ID 27 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/wind-serpent`
  17. `wolf` (ID 1 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/wolf`
  18. `hydra` (Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/hydra`
  19. `scalehide` (Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/scalehide` *(Consolidates Kodos, Thunder Lizards, Stegodons)*
* **Non-Beast Companion Families**:
  - **Dragonkin** (ID 2) ➔ `https://www.wowhead.com/forever/npcs/dragonkin` (~305 NPCs)
  - **Elementals** (ID 4) ➔ `https://www.wowhead.com/forever/npcs/elementals` (~551 NPCs)
  - **Mechanicals** (ID 9) ➔ `https://www.wowhead.com/forever/npcs/mechanicals` (~214 NPCs)

#### The Cross-Check & Join Resolution
* Cross-references Pass 1 with Pass 2 using `npcId`:
  $$\text{FinalZoneCreature} = \text{ZoneCensus}(npcId) \bowtie \text{TaxonomyRegistry}(npcId)$$
* Every zone spawn is enriched with authentic subfamily classification, spec archetype, diet, and verified 3D `displayId`.
* ⛔ **Purely Aquatic Exclusion Filter**: Water-bound swimming fauna (**Threshers**, **Sharks**, **Frenzy Fish**, **Eels**) are filtered out and excluded from the capturable wildlife pool. Only terrestrial or amphibious species (**Crabs**, **Crocolisks**, **Turtles**) are compiled.

#### Location Cross-Referencing & Acquisition Flagging
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
* **Routed to AI Battle Trainer Registry (`type: 7` Humanoids & `type: 6` Sentient Undead)**:
  * Humanoid NPC actors, bandits, cultists, quest givers, merchants, and rival hunters.
  * Sentient and humanoid undead: Skeletons, Ghouls, Zombies, Wraiths, Banshees, Death Knights, Liches, and Necromancers.
  * ⛔ Neither humanoids nor sentient undead can ever be captured, kept as pets, or placed in breeding sanctuaries.
* **Retained for Capturable Companion Pool (`type: 1, 2, 4, 9`)**:
  * Wild beasts across all subfamilies (including animalistic plagued wolves, bears, bats with `Undead`/`Shadow` element typing).
  * Wild dragons, drakes, whelps, faerie dragons (`Dragonkin`).
  * Elemental spirits, tar beasts, water/fire elementals (`Elemental`).
  * Autonomous mechs, harvest golems, alarm-o-bots, clockwork spiders (`Mechanical`).

---

### Phase 4: Starter Move Provisioning & Advanced Slot Unlocks

Every companion receives exactly 2 baseline abilities based on its archetype and family:

| Archetype | Spec Focus | Starter Slot 1 (Offensive) | Starter Slot 2 (Defensive) | Slot 3 | Slot 4 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Tenacity** | Defense / Mitigation | `Bite` or `Claw` (Power 40) | `Thick Hide` (Damage Absorb / Def Up) | `nil` | `nil` |
| **Ferocity** | Burst DPS / Crits | `Claw` or `Rake` (Power 40) | `Harden` or `Bloodline Roar` (Atk/Crit Up) | `nil` | `nil` |
| **Cunning** | Speed / Control | `Peck` or `Bite` (Power 40) | `Quick Reflexes` or `Dodge` (Evasion Up) | `nil` | `nil` |
| **Dragonkin** | Magic / Breath | `Breath` (Elemental Dmg 40) | `Scales of Iron` (Magic Resist / Shield) | `nil` | `nil` |
| **Elemental** | Elemental Spells | `Elemental Blast` (Power 40) | `Elemental Barrier` (Shield / Ward) | `nil` | `nil` |
| **Mechanical** | Precision / Tech | `Tinker Spark` (Power 40) | `Armor Plating` (Armor Boost) | `nil` | `nil` |

*Note on Advanced Slots 3 & 4:*
- **Beasts & Living Wildlife**: Unlocked via Open-World Field Observation.
- **Mechanical Constructs**: Unlocked via **Catalyst Combobulation** at Master Tinkers (e.g., SFK Catalyst $\rightarrow$ Shadow/Undead modules `Shadow Shock` / `Unholy Overdrive`; Gnomeregan Catalyst $\rightarrow$ Cryo-Coolant modules `Cryo Freeze` / `Supercoolant Vent`). Constructs do NOT lay eggs.

---

### Phase 5: Codebase Emission & Lua Integration

1. **`Data/Creatures/Creatures_Beasts.lua`**: All 17 Hunter families (including plagued variants), tagged with `spec`, `family`, `acquisition`, `location`.
2. **`Data/Creatures/Creatures_Dragonkin.lua`**: Dragonkin entries with whelp/pup drop mechanics.
3. **`Data/Creatures/Creatures_Elementals.lua`**: Elemental spirits and spark drops.
4. **`Data/Creatures/Creatures_Mechanicals.lua`**: Constructs and scrap-bot drops.
5. **`Data/Creatures/Zones/`**: Partitioned Zone Registries (`Zone_{id}_Creatures.lua` and `Zone_{id}_Humanoids.lua`).
6. **`Data/CreatureDB.lua`**: Master lookup registry with query helpers:
   - `CreatureDB:GetCreaturesByZone(zoneID)`
   - `CreatureDB:IsInstanceOnly(creatureID)`
   - `CreatureDB:CanEncounterInBattle(creatureID)`
   - `CreatureDB:GetPupDropInfo(creatureID)`
7. **Instance Slay Hook (`Core/SafariInstanceDrops.lua`)**:
   - Hooks `COMBAT_LOG_EVENT_UNFILTERED` inside instances/raids/BGs.
   - On `UNIT_DIED`, looks up slain creature in `CreatureDB`.
   - If `creature.pupDropRate` procs, spawns/awards companion Pup to party/player!
