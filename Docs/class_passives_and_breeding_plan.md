# 📜 Implementation Plan: Player Class Passives System

## 🎯 Executive Summary
This specification details the architecture and combat engine hooks for **Player Class Passives** in *Forever Safari*:
* **Class Tactical Identity**: 9 distinct, lore-accurate tactical combat and progression passives evaluated dynamically via `UnitClass("player")` with strict `math.ceil()` arithmetic.
* **Addon Architecture**: Handled centrally via `Core/ClassPassives.lua` with zero-taint hooks into `BattleEngine.lua` and `StatEngine.lua`.

> [!NOTE]
> For the Co-Op Breeding System, biological anatomy, tiered sanctuaries, and Catalyst inheritance, see:
> [Docs/BREEDING_SYSTEM_AND_GENETICS.md](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Docs/BREEDING_SYSTEM_AND_GENETICS.md)

---

## 🗂️ Architectural Overview

```
                      ┌────────────────────────────────────────┐
                      │          UnitClass("player")           │
                      └───────────────────┬────────────────────┘
                                          │
                 ┌────────────────────────┴────────────────────────┐
                 ▼                                                 ▼
   ┌───────────────────────────┐                     ┌───────────────────────────┐
   │    Core/ClassPassives.lua  │                     │   Core/BattleEngine.lua   │
   │  Passive lookup & math    │ ◄───────────────────┤ Damage mitigation, heals, │
   │  ceil modifiers           │                     │ turns, miss chance, ankh  │
   └─────────────┬─────────────┘                     └─────────────┬─────────────┘
                 │                                                 │
                 ▼                                                 ▼
   ┌───────────────────────────┐                     ┌───────────────────────────┐
   │    Core/StatEngine.lua    │                     │    UI/BattleFrame.lua     │
   │  Hunter stat scaling &    │                     │  Priest Divine Grace      │
   │  Druid loyalty bonus      │                     │  action button            │
   └───────────────────────────┘                     └───────────────────────────┘
```

---

## 📅 Phased Implementation Breakdown

### Phase 1: Class Passives System (`Core/ClassPassives.lua`)
* **Goal**: Implement the 9 class passives with strict `math.ceil()` arithmetic and zero-taint evaluation.
* **Tasks**:
  1. **Define `Core/ClassPassives.lua`**:
     * Export `ns.ClassPassives` with active player class detection: `local _, class = UnitClass("player")`.
     * Define metadata, display names, tooltips, and mathematical helper functions:
        * 🛡️ **Warrior (Marshal's Tenacity)**: **Static Slice**: **+5% per Attunement Rank** Physical Damage Reduction / Armor (**5%** at Rank 1 $\to$ **25%** at Rank V).
        * 🗡️ **Rogue (Shadow Evasion)**: **Static Slice**: **+5% per Attunement Rank** Enemy Miss Chance / Evasion (**5%** at Rank 1 $\to$ **25%** at Rank V).
        * 🏹 **Hunter (Aspect of the Wild & Pathfinder)**: **Static Slice**: **+5% per Attunement Rank** Nature Resistance (**5%** at Rank 1 $\to$ **25%** at Rank V); companion basic attack/defense scaling +5% to +25%.
        * 🍃 **Druid (Gift of the Wild & Symbiosis)**: **Static Slice**: **+2% per Attunement Rank** Pure Static Omni-Resist across all 6 magic schools (**2%** at Rank 1 $\to$ **10%** at Rank V); Attunement point acceleration.
        * 🔮 **Mage (Arcane Celerity & Ward)**:
          * **Chilling Tempo**: Procs on hit. Offense: 5% per Rank (5%–25%); Defense: 10% per Rank (10%–50%). Inflicts **Chilled** (-50% SPD for 2 turns). Countered via **Direct Roll Subtraction** by target's Frost Resistance %.
          * **Procced Ward (Arcane, Fire, & Frost)**: 5% per Rank proc chance; absorbs 10% per Rank (10%–50%) incoming damage on proc. Rolled per direct hit and **independently per DoT tick**.
        * ⚡ **Shaman (Elemental Shielding & Primal Rebirth)**:
          * **Procced Ward (Fire, Frost, & Nature)**: 5% per Rank proc chance; absorbs 10% per Rank (10%–50%) incoming damage. Rolled per direct hit and **independently per DoT tick**.
          * **Primal Rebirth**: `RollAnkh()` 50% chance to revive companion at 50% HP once per battle.
        * 💀 **Warlock (Fel Infusion & Curse of Suppression)**:
          * **Procced Ward (Shadow & Fire)**: 5% per Rank proc chance; absorbs 10% per Rank (10%–50%) incoming damage. Rolled per direct hit and **independently per DoT tick**.
          * **Curse of Suppression**: When facing enemy AI trainer or PvP opponent, halves all opposed passives by 50%.
        * 🕊️ **Priest (Ward of the Heavens & Divine Grace)**:
          * **Procced Ward (Shadow & Holy)**: 5% per Rank proc chance; absorbs 10% per Rank (10%–50%) incoming damage. Rolled per direct hit and **independently per DoT tick**.
          * **Divine Grace**: Active heal charges = `rank` uses per battle, each healing `math.ceil(maxHP * 0.25)`.
        * ⚔️ **Paladin (Aegis of Light)**:
          * **Procced Ward (Physical Armor & Holy)**: 5% per Rank proc chance; absorbs 10% per Rank (10%–50%) incoming damage. Rolled per direct hit and **independently per DoT tick**.
          * **Aura of Light**: Converts 5% to 25% of absorbed/mitigated damage into healing.

### Phase 2: Combat Engine Integration (`Core/BattleEngine.lua`)
* **Tasks**:
  1. **Turn Execution Hooks**:
     * Apply Warrior Physical mitigation and Mage Spell mitigation inside `BE:ApplyMoveEffects()`.
     * Apply Paladin damage-to-healing conversion.
     * Apply Rogue miss penalty to incoming enemy accuracy checks.
     * Apply Shaman Primal Rebirth check inside `BE:CheckDefeatPassives()`.
  2. **Mage Speed Suppression**:
     * Apply speed debuff and update turn order in the action-gauge queue.
  3. **Warlock Opponent Check**:
     * Detect enemy trainer class and apply suppression factor upon battle initialization.

### Phase 3: Interface Hooks (`UI/BattleFrame.lua`)
* **Tasks**:
  1. Add tactile `[ 💖 Divine Grace (X) ]` button to the battle command tray when `class == "PRIEST"`.
  2. Display active player class aura icon on the player's companion unit frame.

---

## 🚦 Verification & Acceptance Criteria
* [x] All 9 player classes calculate passives correctly using `math.ceil()`.
* [x] Class bonuses stack cleanly as static additive modifiers with creature archetype bonuses.
* [x] Zero taint across all combat and UI interactions.
