# 🐾 Forever Safari — Hunter Pet Taxonomy, Move Siloing & Observation Architecture
**Canonical Design Blueprint: 3-Axis Taxonomy, Spec Archetypes, Observation Loop & Kennel Expansion**  
*World of Warcraft: Forever Beta (`_classic_beta_` / `dataEnv: 16`)*

---

## 📖 1. Core Vision & Design Principles

*Forever Safari* adopts the authentic **World of Warcraft Hunter Pet System**, grounding companion discovery, archetypes, and combat progression directly in Warcraft lore:

1. **Two-Move Starting Instincts**:
   - Every companion begins with **exactly 2 moves**: **1 Base Offensive** and **1 Base Defensive**.
   - Slots 3 and 4 start empty.
2. **Observation-Gated Progression (Living Wildlife)**:
   - Advanced attacks, signatures, crowd control, and tactical auras for organic beasts are **locked until observed in the wild**.
   - Observing a wild creature unleash an ability records it in Hemet Nesingwary's Field Guide, permanently unlocking it in the companion's Training Drawer.
3. **Strict Beast Family Siloing**:
   - Beast families are organized by spec archetype (**Tenacity**, **Ferocity**, **Cunning**).
   - Movepools are strictly siloed (e.g., Bears cannot learn *Cower* or *Prowl*; Tanks stand their ground).
4. **Construct vs. Organic Move Acquisition Pathways**:
   - *Living Wildlife (Beasts & Dragonkin)*: Slots 3 and 4 unlock through wild Field Observation.
   - *Mechanical Constructs*: Constructs cannot learn biological instincts in the wild. Slots 3 and 4 are unlocked via **Catalyst Combobulation** at Master Tinkers (Booty Bay, Ironforge, Orgrimmar) using dungeon/raid catalysts (e.g., SFK Catalyst $\rightarrow$ Shadow/Undead; Gnomeregan Catalyst $\rightarrow$ Cryo-Coolant/Ice-Water).

---

## 🎯 2. The 3-Axis Ability Taxonomy & Filter System

Every ability in `MoveDB` is classified across three distinct dimensions, matching the Training Drawer UI filter bars:

```
[ Nature Filter ]   -->  [ All ]      [ Mundane ]       [ Magical ]
[ Role Filter ]     -->  [ All ]      [ Offensive ]     [ Defensive ]     [ Utility ]
[ Delivery Filter ] -->  [ All ]      [ Direct ]        [ Over Time ]     [ Procced ]
```

### A. Nature (Source & Delivery)
* **Mundane**: Physical strikes, claws, teeth, venom, martial techniques, and biological defenses.
* **Magical**: Elemental magic, arcane, shadow, nature spells, and celestial forces.

### B. Role (Combat Purpose)
* **Offensive**: Damages the opponent's health bar.
* **Defensive**: Preserves or restores the companion's health bar (**Mitigation**, **Shields**, **Direct Heals**, and **HoTs**).
* **Utility**: Controls battle momentum (**Stat Buffs/Debuffs**, **Crowd Control**, **Cleanses**, **Weather/Auras**).

### C. Delivery (Timing & Trigger)
* **Direct (Instant)**: Upfront impact executed immediately on the cast turn.
* **Over Time (Periodic)**: Lingering effect ticking across multiple turns (DoTs, HoTs, weather).
* **Procced (Triggered / Reactive)**: Conditional activation triggered by battle events (Counterattack on hit, bonus damage below 30% HP, revenge triggers).

---

## 🛡️ 3. Standard Hunter Spec Archetypes & Baseline Starting Pairs

When captured or unboxed, beasts automatically receive their spec baseline:

| Spec Archetype | Primary Role | Beast Families Included | Base Offensive (Slot 1) | Base Defensive (Slot 2) |
| :--- | :--- | :--- | :--- | :--- |
| **Tenacity** | Tank / Mitigation | Bears, Turtles, Crabs, Boars, Gorillas, Crocolisks, Scorpids, **Scalehide (Kodos, Thunder Lizards, Stegodons)** | **`Claw`** or **`Bite`** *(40 Power, Direct)* | **`Thick Hide`** *(Damage absorption / armor boost)* |
| **Ferocity** | Striker / DPS | Cats, Raptors, Wolves, Wind Serpents, Hyenas, Carrion Birds, Tallstriders, **Hydras** | **`Bite`** or **`Claw`** *(40 Power, Direct)* | **`Lick Wounds`** *(Direct minor HoT restoration)* |
| **Cunning** | Disrupter / Control | Spiders, Bats, Birds of Prey | **`Nip`** or **`Bite`** *(40 Power, Direct)* | **`Cower`** / **`Evasive Reflexes`** *(Dodges or mitigates next attack)* |

---

## ⚡ 4. Signature Family Abilities (Gated Behind Wild Observation)

Signature techniques define each family's identity and can only be trained once observed in the field:

| Family | Signature Move | Taxonomy (Nature • Role • Delivery) | Effect Summary |
| :--- | :--- | :--- | :--- |
| **Cat** | **`Prowl`** | Mundane • Utility • Procced | Stealths companion; next attack lands a guaranteed critical strike. |
| **Turtle** | **`Shell Shield`** | Mundane • Defensive • Over Time | Reduces all damage taken by 50% for 3 turns. |
| **Wolf** | **`Furious Howl`** | Mundane • Utility • Direct | Inspires companion, increasing physical attack power for 2 turns. |
| **Spider** | **`Web Trap`** | Mundane • Utility • Direct | Entangles opponent in sticky silk, preventing switching and dropping speed. |
| **Boar** | **`Gore / Charge`** | Mundane • Offensive • Direct (Priority) | High-priority opener that interrupts and staggers the target. |
| **Bear** | **`Hibernate`** | Mundane • Defensive • Over Time | Deep hibernation for 2 turns; renders immune to debuffs and regenerates 100% HP. |
| **Gorilla** | **`Pummel`** | Mundane • Utility • Direct | Heavy smash that interrupts and locks out the opponent's last used move. |
| **Bat / Owl** | **`Screech`** | Mundane • Utility • Direct | Piercing sonic cry that demoralizes target, lowering their attack power. |
| **Crocolisk** | **`Death Roll`** | Mundane • Offensive • Direct | Heavy thrash that deals 1.5 * damage if the target is already bleeding. |
| **Scalehide** | **`Thunderstomp`** | Mundane • Offensive / Utility • Direct | Heavy seismic trample that damages enemy and lowers their speed by 25%. |
| **Hydra** | **`Triple Bite`** | Mundane • Offensive • Direct | Multi-headed strike that hits 3 times in rapid succession, with each hit having an independent crit chance. |

### B. Mechanical Modular Move Socketing (Catalyst-Gated via Master Tinkers)
Because constructs lack biological instincts, mechanical companions cannot unlock signature abilities via field observation in Nesingwary's Field Guide. Instead, their 3rd and 4th ability slots are modular hardware bays unlocked at Master Tinkers (Booty Bay, Ironforge, Orgrimmar) using dungeon/raid Catalysts:

| Catalyst Source | Installed Move 1 (Slot 3) | Installed Move 2 (Slot 4) | Elemental Alignment | Tactical Profile |
| :--- | :--- | :--- | :--- | :--- |
| **Shadowfang Keep (SFK)** | **`Shadow Shock`** *(Power 55)* | **`Unholy Overdrive`** *(Buff)* | Shadow / Undead | Dark-tech conversion; direct shadow damage and a temporary attack/speed surge at the expense of structural integrity. |
| **Gnomeregan (Viscous Fallout)** | **`Cryo Freeze`** *(Power 50)* | **`Supercoolant Vent`** *(Shield/Aura)* | Ice / Water | High-efficiency refrigerant coolant; slows enemy turn meter and coats chassis in a damage-mitigating ice glaze. |
| **Blackrock Depths (BRD)** | **`Thermal Flare`** *(Power 60)* | **`Magma Exhaust`** *(DoT)* | Fire / Magma | Superheats steam boilers; emits explosive flame and lingering molten shrapnel. |
| **Deadmines (Defias Artificer)** | **`Iron Cannonade`** *(Power 65)* | **`Scrap Plating`** *(Shield)* | Physical / Armor | Heavy foundry munitions; high direct physical damage backed by bolted-on armor plates. |

---

## 📦 5. Scaled 1,000-Slot Kennel Architecture

To support the 1,700+ wild beasts across Azeroth, the Reserve expands from 5 hardcoded tabs to a scalable paginated storage vault:

* **Capacity**: 50 Enclosures * 20 Slots = **1,000 Companion Storage Capacity**.
* **Navigation UI**:
  - `[◀] Enclosure 1 of 50 [▶]` stepper controls.
  - Quick-jump dropdown to jump directly to any enclosure.
* **Custom Box Naming**: Players can rename enclosures (*"Bears"*, *"PvP Team"*, *"Favorites"*, *"Outland"*).
* **Search & Filter Bar**: Instant search across all 50 boxes by name, level, creature type, and Attunement rank.

---

## 🌐 6. Wowhead Ingestion Pipeline & Two-Pass Cross-Check

### Phase 1: Zone Exclusion Filter
A master exclusion list discards NPCs that spawn exclusively inside:
- **Instances & Raids**: Deadmines, Wailing Caverns, Molten Core, Onyxia's Lair, etc.
- **PvP Battlegrounds & Arenas**: Warsong Gulch, Arathi Basin, Alterac Valley.

### Phase 2: The Two-Pass Subfamily Cross-Check
To defeat Wowhead's 1,000-entity query truncation while maintaining airtight ecological and taxonomy accuracy:
1. **Pass 1 (Zone Census - `npcs?filter=6;{zoneId};0`)**: Scrapes every NPC per zone without exceeding 200–400 entities per call. Captures all wildlife and AI trainer candidates with exact zone presence.
2. **Pass 2 (Family & Subfamily Taxonomy)**:
   - Scrapes all 19 capturable Beast subfamilies: Bat, Bear, Bird of Prey, Boar, Carrion Bird, Cat, Crab, Crocolisk, Gorilla, Hyena, Raptor, Scorpid, Spider, Tallstrider, Turtle, Wind Serpent, Wolf, **Hydra**, and **Scalehide** (unifying Kodos, Thunder Lizards, and Stegodons). Plagued animals (e.g. *Plagued Wolf*, *Diseased Bear*, *Duskbat*) reside under their biological Beast subfamily with `Undead` or `Shadow` elemental typing.
   - Scrapes non-beast companion families: Dragonkin (`2`), Elementals (`4`), Mechanicals (`9`).
3. **Cross-Check & Join Resolution**: Cross-checks Pass 1 with Pass 2 on `npcId`. Every zone entity is enriched with its canonical subfamily, spec archetype, and 3D display model.
4. ⛔ **Purely Aquatic Exclusion**: Water-bound swimming fauna (**Threshers**, **Sharks**, **Frenzy Fish**, **Eels**) are strictly untamable and excluded during ingestion. Land-walking amphibious species (**Crabs**, **Crocolisks**, **Turtles**) are fully supported.
5. ⛔ **Sentient Undead (Category 6) Reclassified as AI Rival Trainers**:
   - Skeletons, Ghouls, Zombies, Wraiths, Banshees, and Necromancers are **strictly AI Battle Trainer Opponents**, never capturable companions.
   - Sentient corpses cannot be observed in Nesingwary's Field Guide, captured with Safari Nets, or housed in breeding sanctuaries.

### Phase 3: Reference Table Generation
Results are compiled into modular data registries in `Data/CreatureDB.lua` with NPC ID, display ID, name, level range, family subcategory, and spawn zones.
