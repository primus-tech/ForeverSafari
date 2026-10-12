# ⚔️ Forever Safari — Move Categorization & Combat Taxonomy
**The Official Reference Guide to Ability Mechanics, Delivery Archetypes & Siloed Movepools**  
*World of Warcraft: Forever Beta (`_classic_beta_` / `dataEnv: 16`)*

---

## 📖 1. System Overview

In *Forever Safari*, abilities are no longer lumped into flat, generic buckets. Instead, every technique in the League is governed by a **3-Axis Taxonomy**:

```
           +------------------------------------------+
           |           ABILITY TAXONOMY MATRIX        |
           +------------------------------------------+
           | 1. NATURE   : Mundane  vs  Magical       |
           | 2. ROLE     : Offensive | Defensive | Utility
           | 3. DELIVERY : Direct    | Over Time | Procced
           +------------------------------------------+
```

This 18-node combinatorial matrix provides deep tactical diversity, guarantees clear combat roles for every companion, and powers the interactive filtering system in the **Field Guide Training Drawer**.

---

## 🧭 2. The Three Foundational Axes

### Axis 1: Nature (Origin & Energy)
* **Mundane**:
  - Relies on physical biology, muscles, claws, teeth, biological venom, martial discipline, and natural endurance.
  - Affected by physical armor, parry, dodge, and bleeding vulnerabilities.
* **Magical**:
  - Channels Azeroth's primal schools: Nature, Fire, Frost, Arcane, Holy, Shadow, and Celestial elements.
  - Affected by elemental affinities, resistances, and weather auras.

---

### Axis 2: Role (Strategic Purpose)
* **Offensive**:
  - Purpose: Deplete the opponent's health bar.
  - Includes upfront burst strikes, periodic damage ticks (bleeds/burns), and execution attacks.
* **Defensive** *(Includes all Healing)*:
  - Purpose: Preserve and restore the companion's own health bar.
  - Includes physical armor boosts, absorption barriers, direct heals (*Lick Wounds*, *Healing Wave*), and regenerations over time (*Hibernate*, *Renew*).
* **Utility**:
  - Purpose: Manipulate the flow and mechanics of battle.
  - Includes crowd control (stuns, sleeps, roots), stat modifiers (*Growl*, *Screech*), cooldown reduction, cleanses, and weather conditions.

---

### Axis 3: Delivery (Timing & Mechanics)
* **Direct (Instant)**:
  - Executes immediate upfront value on the cast turn (*e.g., Claw, Bite, Fireball, Healing Wave*).
* **Over Time (Periodic)**:
  - Ticks across multiple turns after being applied (*e.g., Rend bleeds, Renew HoTs, Sandstorm auras*).
* **Procced (Triggered / Reactive)**:
  - Lies dormant until a specific condition or combat event occurs (*e.g., Thorns counterattack when struck, Riposte upon dodging, Enrage below 30% HP, Ambush from Prowl*).

---

## 📊 3. The 18 Archetype Combinatorial Matrix

| Nature | Role | Delivery | Canonical Examples | Tactical Function |
| :--- | :--- | :--- | :--- | :--- |
| **Mundane** | **Offensive** | **Direct** | *Bite*, *Claw*, *Maul*, *Tackle* | Upfront physical damage. |
| **Mundane** | **Offensive** | **Over Time** | *Rend*, *Rake*, *Serpent Sting* | Bleeds and physical poisons ticking per round. |
| **Mundane** | **Offensive** | **Procced** | *Riposte*, *Ambush (Prowl)*, *Counter-Strike* | Bonus hits triggered after dodging or opening from stealth. |
| **Mundane** | **Defensive** | **Direct** | *Thick Hide*, *Bandage*, *Shell Shield* | Instant armor buff or burst health restoration. |
| **Mundane** | **Defensive** | **Over Time** | *Lick Wounds*, *Hibernate*, *Primal Vitality* | Multi-turn physical regeneration and rest. |
| **Mundane** | **Defensive** | **Procced** | *Spiked Carapace*, *Survival Instincts* | Thorns damage when struck; survival trigger at low HP. |
| **Mundane** | **Utility** | **Direct** | *Growl*, *Tail Whip*, *Screech*, *Pummel* | Instant attack/defense reductions or interrupts. |
| **Mundane** | **Utility** | **Over Time** | *Web Trap*, *Dust Cloud*, *Primal Roar* | Persistent crowd control and terrain disruption. |
| **Mundane** | **Utility** | **Procced** | *Prowl (Stealth)*, *Camouflage* | Enters hidden state; triggers guaranteed crit on exit. |
| **Magical** | **Offensive** | **Direct** | *Fireball*, *Moonfire*, *Water Jet*, *Shadow Bolt* | Direct elemental spell damage. |
| **Magical** | **Offensive** | **Over Time** | *Ignite*, *Curse of Agony*, *Poison Spore* | Lingering magical burns and elemental afflictions. |
| **Magical** | **Offensive** | **Procced** | *Static Discharge*, *Chain Lightning*, *Reckoning* | Elemental retaliations and surge procs. |
| **Magical** | **Defensive** | **Direct** | *Healing Wave*, *Holy Light*, *Divine Shield* | Instant magical heal or complete immunity shield. |
| **Magical** | **Defensive** | **Over Time** | *Renew*, *Regrowth*, *Nature's Ward* | Lingering HoTs and elemental shielding barriers. |
| **Magical** | **Defensive** | **Procced** | *Seed of Life*, *Earth Shield*, *Frost Armor* | Heals only upon taking heavy damage; chills attackers. |
| **Magical** | **Utility** | **Direct** | *Frost Nova*, *Solar Beam*, *Purge* | Instant magical freeze, silence, or aura dispel. |
| **Magical** | **Utility** | **Over Time** | *Blizzard*, *Eclipse Aura*, *Healing Rain* | Lingering weather effects and global field auras. |
| **Magical** | **Utility** | **Procced** | *Ecliptic Surge*, *Soul Link* | Triggers upon reaching maximum Solar/Lunar energy. |

---

## 🔒 4. Beast Family Siloing & Anti-Synergy Restrictions

To preserve companion identity, movepools are strictly siloed by beast spec. Companions cannot learn abilities that violate their family's fantasy:

### 1. Tenacity (The Tanks)
* **Allowed**: Mundane Heavy Offense, Mundane & Magical Defense (Armor, Shields, Mitigation, Recovery), Ground Control.
* **Strictly Prohibited**: Evasion, cowardice, and pure stealth techniques (*Cower*, *Prowl*, *Dash*). A Bear or Turtle stands its ground.

### 2. Ferocity (The Strikers)
* **Allowed**: Direct burst damage, Bleeds, Crits, Attack power buffs, Stealth openers (*Prowl*), Speed enhancements.
* **Strictly Prohibited**: Hard defensive turtle shields (*Shell Shield*) and damage immunity barriers.

### 3. Cunning (The Controllers)
* **Allowed**: Crowd control, Disruption, Traps (*Web*), Sonic debuffs (*Screech*), Evasion (*Cower*), Movement speed slows.
* **Strictly Prohibited**: High-threat tanking abilities (*Thick Fur*, *Last Stand*).

---

## 🖥️ 5. Training Drawer UI Integration

In the companion management interface, the Training Drawer provides three interactive filter bars:

```
[ Nature ]   -->  [ All ]  [ Mundane ]  [ Magical ]
[ Role ]     -->  [ All ]  [ Offensive ]  [ Defensive ]  [ Utility ]
[ Delivery ] -->  [ All ]  [ Direct ]  [ Over Time ]  [ Procced ]
```

### Tooltip Specification
Hovering over any ability card displays the full taxonomy header:

```
+-------------------------------------------------------------------+
| Bite                                                              |
| Type: Beast  •  Mundane  •  Offensive  •  Direct                  |
|                                                                   |
| Power: 40        Accuracy: 100%       Uses: 10 / 10               |
|                                                                   |
| Tears the target with sharp teeth, dealing direct physical damage.|
+-------------------------------------------------------------------+
```

---

## 📜 6. Observation Discovery Progression

1. **Starter Baseline**: All pets unlock with **1 Offensive (Direct)** and **1 Defensive (Direct/HoT)**.
2. **Wild Observation**: When a wild creature casts a move in combat, Hemet Nesingwary's Field Guide detects and registers the technique:
   ```
   [Nesingwary Field Guide] New technique observed: Furious Howl (Mundane • Utility • Direct)!
   ```
3. **Training**: The player visits the companion's Training Drawer and assigns the newly unlocked ability into empty Slots 3 or 4.
