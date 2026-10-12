# 🐾 Forever Safari — Hunter Pet Taxonomy, Move Siloing & Observation Architecture
**Canonical Design Blueprint: 3-Axis Taxonomy, Spec Archetypes, Observation Loop & Kennel Expansion**  
*World of Warcraft: Forever Beta (`_classic_beta_` / `dataEnv: 16`)*

---

## 📖 1. Core Vision & Design Principles

*Forever Safari* adopts the authentic **World of Warcraft Hunter Pet System**, grounding companion discovery, archetypes, and combat progression directly in Warcraft lore:

1. **Two-Move Starting Instincts**:
   - Every companion begins with **exactly 2 moves**: **1 Base Offensive** and **1 Base Defensive**.
   - Slots 3 and 4 start empty.
2. **Observation-Gated Progression**:
   - Advanced attacks, signatures, crowd control, and tactical auras are **locked until observed in the wild**.
   - Observing a wild creature unleash an ability records it in Hemet Nesingwary's Field Guide, permanently unlocking it in the companion's Training Drawer.
3. **Strict Beast Family Siloing**:
   - Beast families are organized by spec archetype (**Tenacity**, **Ferocity**, **Cunning**).
   - Movepools are strictly siloed (e.g., Bears cannot learn *Cower* or *Prowl*; Tanks stand their ground).

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
| **Tenacity** | Tank / Mitigation | Bears, Turtles, Crabs, Boars, Gorillas, Crocolisks, Beetles | **`Claw`** or **`Bite`** *(40 Power, Direct)* | **`Thick Hide`** *(Damage absorption / armor boost)* |
| **Ferocity** | Striker / DPS | Cats, Raptors, Wolves, Wind Serpents, Core Hounds, Wasps, Hyenas | **`Bite`** or **`Claw`** *(40 Power, Direct)* | **`Lick Wounds`** *(Direct minor HoT restoration)* |
| **Cunning** | Disrupter / Control | Spiders, Bats, Birds of Prey, Serpents, Foxes, Monkeys | **`Nip`** or **`Bite`** *(40 Power, Direct)* | **`Cower`** / **`Evasive Reflexes`** *(Dodges or mitigates next attack)* |

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

## 🌐 6. Wowhead Open-World Scraping Pipeline

### Phase 1: Zone Exclusion Filter
A master exclusion list discards NPCs that spawn exclusively inside:
- **Instances & Raids**: Deadmines, Wailing Caverns, Molten Core, Onyxia's Lair, etc.
- **PvP Battlegrounds & Arenas**: Warsong Gulch, Arathi Basin, Alterac Valley.

### Phase 2: Creature Categorization & Non-Sentient Verification
Extract NPCs across 5 valid creature types:
1. **Beasts** (Category 1): Tagged with exact sub-family (Bear, Cat, Wolf, Raptor, etc.).
2. **Elementals** (Category 4): Wild elemental forms (Sparks, Water Elementals, Tar Beasts, Earth Elementals).
3. **Mechanicals** (Category 9): Wild constructs (Harvest Golems, Mech-striders, Clockwork Birds).
4. **Dragonkin** (Category 2): Whelps, Drakes, Proto-Drakes, Faerie Dragons.
5. **Undead** (Category 6): Non-sentient Scourge hounds, plaguespiders, mindless ghouls.

### Phase 3: Reference Table Generation
Results are compiled into modular data registries in `Data/CreatureDB.lua` with NPC ID, name, level range, family subcategory, and spawn zones.
