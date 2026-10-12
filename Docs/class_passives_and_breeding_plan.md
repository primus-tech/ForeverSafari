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
       * 🛡️ **Warrior (Marshal's Tenacity)**: Physical damage reduction (+10% to +25%).
       * 🛡️ **Paladin (Aura of Light)**: Damage-to-healing conversion (+5% to +25%).
       * ⚡ **Shaman (Primal Rebirth)**: `RollAnkh()` 50% chance to revive companion at 50% HP once per battle.
       * 🔮 **Mage (Arcane Celerity & Ward)**:
         * **Chilling Tempo Proc**: 5% per Attunement Rank (5%–25%) on offense; 10% per Attunement Rank (10%–50%) on defense. Inflicts **Chilled** for 2 turns (-50% SPD).
         * **Direct Roll Subtraction**: Target's Frost Resistance % directly subtracts from proc chance: $\text{Effective Proc \%} = \max(0\%, \text{Base Proc \%} - \text{Frost Resist \%})$. (Countered by Polar Bears, Winter Wolves, Frostsabers, Snow Owls, Blue Dragonkin, Frost Elementals).
         * **Arcane Spell Ward**: 5% per Attunement Rank (+5% to +25%) non-physical / magical damage resistance.
       * 🗡️ **Rogue (Shadow Evasion)**: Enemy miss chance increase `+25%` (e.g. miss threshold +25).
       * 🌿 **Priest (Divine Grace)**: Active heal charges = `rank` uses per battle, each healing `math.ceil(maxHP * 0.25)`.
       * 🏹 **Hunter (Pathfinder's Mastery)**: Companion basic attack and defense boosted by `+5%` to `+25%`.
       * 🍃 **Druid (Wild Symbiosis)**: Attunement points boosted by `+25%`, Rank thresholds reduced by `25%`.
       * 💀 **Warlock (Curse of Suppression)**: When facing enemy AI trainer or PvP opponent, halves all opposed passives by `50%`.

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
