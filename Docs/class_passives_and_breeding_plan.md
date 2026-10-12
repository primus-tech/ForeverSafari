# 📜 Implementation Plan: Class Passives & Endgame Moonglade Breeding

## 🎯 Executive Summary
This plan details the full implementation of two core gameplay pillars for **Forever Safari**:
1. **Player Class Passives & Combat Mechanics**: 9 distinct, lore-accurate tactical combat and progression passives evaluated dynamically via `UnitClass("player")` with strict `math.ceil()` rounding.
2. **Moonglade Co-op Breeding Program**: An authentic, high-stakes endgame breeding system anchored to Moonglade Cenarion NPCs (`GOSSIP_SHOW`), featuring cryptographic Sire/Dam anatomy, P2P dual-confirmation handshake via `ForeverSafariComm`, the permanent sacrifice of both parents, and fair egg distribution with stat and move inheritance.

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
   │     Core/Crypto.lua       │                     │    UI/BattleFrame.lua     │
   │  Signed Sire/Dam anatomy  │                     │  Priest Divine Grace button│
   └─────────────┬─────────────┘                     └───────────────────────────┘
                 │
                 ▼
   ┌───────────────────────────┐                     ┌───────────────────────────┐
   │    Moonglade Nursery      │ ◄─────────────────► │     P2P Co-op Comms       │
   │   (UI/NurseryFrame.lua)   │   ForeverSafariComm │  Dual-Accept Handshake    │
   │  Gossip anchor at NPC     │                     │  Sire/Dam matching        │
   └─────────────┬─────────────┘                     └───────────────────────────┘
                 │
                 ▼
   ┌─────────────────────────────────────────────────────────────────────────────┐
   │                   The Ultimate Sacrifice & Fair Split                       │
   │  - Parents permanently consumed from Kennel/Vault                          │
   │  - Guaranteed 2-Egg Split (Egg 1 -> Sire owner, Egg 2 -> Dam owner)        │
   │  - Bonus 3rd Egg 20% roll with automated tie-breaker roll                  │
   │  - Eggs deposited directly into Virtual Safari Bag (/fsbag)                │
   └─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📅 Phased Implementation Breakdown

### Phase 1: Class Passives System (`Core/ClassPassives.lua` & Engine Hooks)
* **Goal**: Implement the 9 class passives with strict `math.ceil()` arithmetic and zero-taint evaluation.
* **Tasks**:
  1. **Create `Core/ClassPassives.lua`**:
     * Export `ns.ClassPassives` with active player class detection: `local _, class = UnitClass("player")`.
     * Define metadata, display names, tooltips, and mathematical helper functions:
       * 🛡️ **Warrior (Marshal's Tenacity)**: `ReducePhysicalDamage(dmg)` -> `dmg - math.ceil(dmg * 0.25)`.
       * 🛡️ **Paladin (Aura of Light)**: `CalculateHealBack(dmg)` -> `math.ceil(dmg * 0.25)`.
       * ⚡ **Shaman (Primal Rebirth)**: `RollAnkh()` -> `math.random(1, 100) <= 50`, revives at `math.ceil(maxHP * 0.5)`.
       * 🔮 **Mage (Arcane Celerity & Ward)**:
         * Attacker speed halved for `rank` turns.
         * Non-physical mitigation: `dmg - math.ceil(dmg * 0.25)`.
       * 🗡️ **Rogue (Shadow Evasion)**: Enemy miss chance increase `+25%` (e.g. miss threshold +25).
       * 🌿 **Priest (Divine Grace)**: Active heal charges = `rank` uses per battle, each healing `math.ceil(maxHP * 0.25)`.
       * 🏹 **Hunter (Pathfinder's Mastery)**: Basic attack and defense boosted by `+25%` (`math.ceil(val * 1.25)`).
       * 🍃 **Druid (Wild Symbiosis)**: Attunement rewards `+25%` (`math.ceil(points * 1.25)`), Rank thresholds reduced by `25%` (`math.ceil(threshold * 0.75)`).
       * 💀 **Warlock (Curse of Suppression)**: When facing enemy AI trainer or PvP opponent, halving all opposed passives by `50%` (`math.ceil(opposedBonus * 0.5)`).
  2. **Hook into [BattleEngine.lua](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/BattleEngine.lua)**:
     * In combat turn execution: apply Warrior/Mage damage mitigation, Paladin healback log, Rogue evasion check, and Shaman death-check revive before fainting.
     * In Mage attacker speed debuff: apply speed alteration and recalculate round turn order.
     * In Warlock combat entry: check opponent passives and apply 50% suppression factor.
  3. **Priest Command Integration in [BattleFrame.lua](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/BattleFrame.lua)**:
     * Add tactile `[ 💖 Divine Grace (X) ]` button to the battle command tray when `class == "PRIEST"`.
  4. **Druid Hooks in [StatEngine.lua](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/StatEngine.lua)**:
     * Dynamically adjust loyalty thresholds and attunement gains for Druids.

---

### Phase 2: Cryptographic Biological Anatomy (`Sire` / `Dam`)
* **Goal**: Seed every companion permanently with `anatomy = "Sire"` or `"Dam"`.
* **Tasks**:
  1. **Database & Capture Seeding**:
     * In `Core/CaptureEngine.lua` and `Core/Database.lua`: assign `anatomy = math.random(1, 2) == 1 and "Sire" or "Dam"` upon wild capture, hatching, or starter unboxing.
     * Migration handler: existing companions without anatomy receive a deterministic assignment derived from their unique ID.
  2. **HMAC Signing in [Crypto.lua](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/Crypto.lua)**:
     * Include `anatomy` in the signed serialization payload (`Crypto:SignMob(mob)`) to prevent local tampering.
  3. **Visual Inspector Display**:
     * In [InspectorFrame.lua](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/InspectorFrame.lua) and [JournalRosterView.lua](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/Views/JournalRosterView.lua):
     * Render distinct badges: `|cff66ccff♂ Sire|r` (Cyan/Blue) or `|cffff99cc♀ Dam|r` (Pink/Magenta).

---

### Phase 3: Moonglade Cenarion Breeding Ground & Gossip Anchor
* **Goal**: Anchor breeding strictly to Moonglade NPCs via authentic `GOSSIP_SHOW` interaction.
* **Tasks**:
  1. **NPC Anchor Detection**:
     * Target anchor: *Loganaar* (Great Cenarion Keeper in Nighthaven, Moonglade) or *Cenarion Master Breeder*.
     * Check map zone: `C_Map.GetBestMapForUnit("player")` or NPC title/name matching Moonglade Cenarion order.
  2. **Gossip Option Injection**:
     * On `GOSSIP_SHOW`, detect Moonglade breeding anchor and present dialogue / open `UI/NurseryFrame.lua`.
     * Prevent opening outside of Moonglade.

---

### Phase 4: Moonglade Nursery Interface & P2P Co-op Comms
* **Goal**: Build `UI/NurseryFrame.lua` and P2P dual-acceptance protocol.
* **Tasks**:
  1. **Create `UI/NurseryFrame.lua`**:
     * Two pedestals: **Your Contributed Parent** (Left) and **Partner's Contributed Parent** (Right).
     * Partner target selector / invite button.
     * Validation status display:
       * ✔ Same Family / Subfamily match.
       * ✔ Both parents at **Rank V: Bestial Symbiosis** (2,000 Attunement).
       * ✔ One **Sire** and one **Dam**.
       * ⚠️ Warning Banner: *"Breeding requires the permanent sacrifice of both parents. They will return to the Cenarion wilds and cannot be retrieved!"*
     * Dual "Lock In" & "Perform Cenarion Ritual" confirmation flow.
  2. **Comms Handshake in [Comms.lua](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/Comms.lua)**:
     * Messages: `NURSERY_INVITE`, `NURSERY_OFFER`, `NURSERY_LOCK`, `NURSERY_EXECUTE`, `NURSERY_CANCEL`.
     * Validates cryptographic signatures of both pets across the P2P connection before executing.

---

### Phase 5: The Ultimate Sacrifice Ritual & Offspring Lineage
* **Goal**: Execute the permanent sacrifice, roll litter, distribute eggs, and handle hatching.
* **Tasks**:
  1. **Permanent Parent Consumption**:
     * Remove Sire from Player 1's collection/kennel.
     * Remove Dam from Player 2's collection/kennel.
     * Output emotional ceremony fanfare: *"Sire [Name] and Dam [Name] have entered the sacred Cenarion Grove. Their lineage lives on in the next generation."*
  2. **Litter Roll & Fair Split**:
     * Guaranteed **2 Eggs** (1 egg sent to Player 1, 1 egg sent to Player 2).
     * 20% chance for a **Bonus 3rd Egg**: triggers a built-in roll off between players.
     * Eggs deposited directly into Virtual Safari Bag (`/fsbag`).
  3. **Egg Traits & Incubation**:
     * Item `safari_egg_<family>` stored in bag.
     * Carries genetic inheritance payload: blended 100/110 base stats, inherited egg moves from parents, rare chromatic tint chance (5%).
     * Incubation progress through field activity (quests or battles), with right-click "Hatch" when fully gestated.

---

### Phase 6: Documentation, Testing & Git Deployment
* **Tasks**:
  1. Update [MANUAL.md](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/MANUAL.md) and [README.md](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/README.md) with complete Class Passives & Moonglade Nursery documentation.
  2. Update `ForeverSafari.toc` to register `Core\ClassPassives.lua` and `UI\NurseryFrame.lua`.
  3. Verify clean execution, zero taint, and push to GitHub `origin/main`.

---

## 🚦 Verification & Acceptance Criteria
* [ ] All 9 player classes calculate passives correctly using `math.ceil()`.
* [ ] Sire and Dam anatomy tags are cryptographically signed with zero tampering possible.
* [ ] Moonglade Cenarion NPC interaction gates access exclusively to Moonglade.
* [ ] Co-op nursery refuses any pair that isn't Rank V, same-family, and Sire + Dam.
* [ ] Both parents are permanently consumed, and eggs are fairly split into players' Safari Bags.
