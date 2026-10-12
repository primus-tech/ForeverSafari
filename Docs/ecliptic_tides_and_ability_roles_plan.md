# Implementation Plan: Druid "Ecliptic Tides" & Move Role Taxonomy

This revised implementation plan details the architecture for formalizing move roles across the entire move database, replacing Druid's passive with the dynamic celestial pendulum **"Ecliptic Tides"**, incorporating early proc rolls and guaranteed automatic discharge upon reaching maximum meter capacity.

---

## 🧭 System Overview

### 1. The Move Role Taxonomy
Every move in `Data/MoveDB.lua` will be explicitly audited and assigned one of 4 canonical combat roles:
* **Offensive**: Direct damage attacks (Physical and Special damage, power > 0).
* **Defensive**: Mitigation, shields, armor buffs, damage prevention.
* **Healing**: Health restoration, regeneration, restorative salves.
* **Utility**: Crowd control (Stun, Sleep), stat modifications (Growl, Howl), speed manipulation, accuracy debuffs.

### 2. Druid Passive — "Ecliptic Tides"
Replaces the old progression threshold discount with an active celestial pendulum inside `/fsbattle`:
* **Total Pool Cap**: Equal to the companion's **Attunement Rank** (1 at Rank 1, up to 5 at Rank 5).
* **Starting State**: Begins at **Neutral** (0 Solar, 0 Lunar).
* **Point Accrual & Tug-of-War**:
  * Using an **Offensive** move adds **+1 Solar Point**.
  * Using a **Non-Offensive** move (Defensive, Healing, Utility) adds **+1 Lunar Point**.
  * If the meter total is full but mixed (e.g. 3 Solar, 2 Lunar at Rank 5), casting an Offensive move siphons 1 point from Lunar into Solar. Casting a Non-Offensive move siphons 1 point from Solar into Lunar.
* **The Two Ways Surges Trigger**:
  1. **Early Proc Roll (Every Cast)**:
     * Proc chance on each cast is **(Points on that side) * 5%**. (1 point = 5%, 2 points = 10%, up to 25% at 5 points).
     * If it procs early, it triggers at that current threshold, and resets both sides to 0.
  2. **Automatic 100% Discharge (Max Capacity Reach)**:
     * If the meter is completely filled to one end (i.e. **Solar Points == Attunement Rank** OR **Lunar Points == Attunement Rank**):
     * It **automatically discharges guaranteed with the maximum Rank effect**!
* **Solar Surge (Offensive Proc or 100% Solar Cap)**:
  * Instantly cleanses 1 active negative debuff/ailment (Poison, Bleed, Burn, Sleep, Stun).
  * Applies **Rejuvenating Bloom (HoT)** healing **(Solar Points * 5)% Max HP** per round, lasting for **(Solar Points)** rounds.
  * **Discharge**: Both Solar and Lunar points reset to 0.
* **Lunar Surge (Non-Offensive Proc or 100% Lunar Cap)**:
  * Applies **Bramble Damage Shield** reflecting **(Lunar Points * 5)%** of incoming damage back to attackers as Nature damage, lasting for **(Lunar Points)** rounds.
  * **Discharge**: Both Solar and Lunar points reset to 0.

---

## 📋 Implementation Phases

### Phase 1: Database Audit & 4-Role Classification (`Data/MoveDB.lua`)
1. Audit all 94 canonical moves in `Data/MoveDB.lua`.
2. Add explicit `role = "Offensive" | "Defensive" | "Healing" | "Utility"` to every move definition.
3. Add helper method `MoveDB:GetMoveRole(moveKey)` that returns the canonical role (with fallback to power > 0 if unassigned).
4. Color-code role badges in ability tooltips (`UI/Theme.lua` & `UI/BattleFrame.lua`):
   * `[Offensive]` -> Red/Orange (`|cffff6600`)
   * `[Defensive]` -> Blue (`|cff3399ff`)
   * `[Healing]` -> Green (`|cff33ff33`)
   * `[Utility]` -> Purple/Gold (`|cffffcc00`)

---

### Phase 2: Core Engine Overhaul (`Core/ClassPassives.lua`)
1. Remove `ApplyDruidAttunementGain` and `GetDruidRankThreshold`.
2. Define "Ecliptic Tides" metadata and descriptions in `CP.PASSIVES["DRUID"]`.
3. Implement state transition helpers:
   * `CP:GetEclipseCap(rank)` -> returns `math.max(1, math.min(5, tonumber(rank) or 1))`.
   * `CP:UpdateEclipseMeter(meter, moveRole, rank)`:
     * Increments Solar or Lunar based on role.
     * Enforces the cap and executes the tug-of-war siphoning if total points exceeds `rank`.
     * Checks if either side reached `rank` (triggering automatic discharge).
   * `CP:RollEclipseSurge(points, opponentClass)`:
     * Calculates proc chance: `(points * 0.05) * suppressionMultiplier`.
     * Rolls `math.random(1, 100)`.
   * `CP:CalculateSolarHoT(maxHP, solarPoints)` -> `math.ceil(maxHP * (solarPoints * 0.05))`.
   * `CP:CalculateLunarBrambles(incomingDmg, lunarPoints, opponentClass)` -> `math.ceil(incomingDmg * (lunarPoints * 0.05))`.

---

### Phase 3: Battle Engine Integration (`Core/BattleEngine.lua`)
1. **Battle State Initialization**:
   * In `BE:StartWildBattle` and `BE:StartAIBattle`, initialize:
     * `BE.State.eclipse = { solar = 0, lunar = 0, hot = { amount = 0, turns = 0 }, brambles = { percent = 0, turns = 0 } }`.
2. **Turn Execution Hook (`BE:ExecutePlayerTurn`)**:
   * Identify move role via `MoveDB:GetMoveRole`.
   * Update Solar or Lunar points.
   * Check for **Automatic Discharge** (if side == rank) OR roll early proc chance `points * 5%`.
   * If Solar triggers:
     * Cleanse 1 active debuff.
     * Apply HoT buff with duration = `solarPoints` and amount = `(solarPoints * 5)% Max HP`.
     * Log celebratory surge message: `☀️ [Ecliptic Tides: Solar Surge]!`.
     * Reset `solar = 0, lunar = 0`.
   * If Lunar triggers:
     * Apply Brambles shield with duration = `lunarPoints` and percent = `(lunarPoints * 5)%`.
     * Log celebratory surge message: `🌙 [Ecliptic Tides: Lunar Surge]!`.
     * Reset `solar = 0, lunar = 0`.
3. **Turn-End HoT Tick**:
   * At the end of each combat round, if companion has active HoT:
     * Heals companion, ticks duration down by 1.
4. **Bramble Damage Reflection**:
   * In `ApplyMoveEffects`, when companion takes damage with active Brambles:
     * Reflects `percent * incomingDmg` back to attacker as Nature damage, ticks duration down if round ended.

---

### Phase 4: StatEngine & Database Cleanup
1. In `Core/StatEngine.lua`:
   * Remove Druid threshold modifiers from `GetAttunementRank` and `GetRankProgress` (all classes share standard thresholds).
2. In `Core/DB/DB_Pets.lua`:
   * Remove Druid attunement point multiplier from `AddAttunement`.

---

### Phase 5: Battle UI Visuals (`UI/BattleFrame.lua`)
1. For Druid characters, render a compact Eclipse indicator above the companion console:
   * e.g., `[ ☀️ Solar: 3 / 5 | 🌙 Lunar: 0 / 5 ]` with an active icon indicator when a HoT or Bramble shield is active.

---

### Phase 6: Documentation & Validation
1. Update `MANUAL.md` and `README.md` with complete documentation for "Ecliptic Tides".
2. Run automated Lua syntax and block-balance verification.
3. Commit and push to git repository.
