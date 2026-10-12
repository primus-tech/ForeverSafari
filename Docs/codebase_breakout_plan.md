# 🛠️ Forever Safari — Architecture Decoupling & Modular Breakout Plan
*(Strict Zero-Shim, Zero-Alias Architecture)*

**Goal:** Break out monolithic and multi-responsibility files, eliminate all legacy duplicated data tables, and update all call-sites to use **direct, canonical module references** with **zero backward-compatibility shims, zero aliases, and zero metatable redirects**.

---

## 🎯 Architecture Transformation

```
[ Current Monoliths & Duplicates ]             [ Clean Canonical Architecture ]
----------------------------------             --------------------------------
Core/Constants.lua (1,623 lines)       --->    Data/BountyDB.lua (Pure Dispatches & Bounties)
  - Duplicate C.ABILITIES                      Core/Constants.lua (~220 lines clean enums)
  - Duplicate C.SAFARI_ITEMS, C.CAGES          (All callers refactored directly to MoveDB/ItemDB/BountyDB)
  - Dead C.SPECIES_CATALOG & MovePools

Core/Database.lua (514 lines)          --->    Core/Crypto.lua (Pure HMAC Signatures & DNA)
  - Intertwined Crypto/HMAC/DNA                Core/Database.lua (~360 lines clean DB storage)
  - Intertwined Base64 Serializer              (All callers refactored directly to Crypto)

Core/BattleEngine.lua (1,171 lines)    --->    Core/BattleCapture.lua (Pure In-Battle Catch & Crates)
  - Intertwined In-Battle Catch                Core/BattleEngine.lua (~1,020 lines pure combat loop)
  - Intertwined Transport Crates               (All callers refactored directly to BattleCapture)
```

---

## 📋 Direct Step-by-Step Execution Plan

### 1. Extract & Directly Wire `Data/BountyDB.lua`
* **Target File:** Create [`Data/BountyDB.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/BountyDB.lua) under `ns.BountyDB`.
* **Content:**
  * Move the 5 canonical Nesingwary research dispatch definitions (*Welcome Package*, *Field Stalking 101*, *The Wild Nourishment*, *Sighting of Apex Rares*, *Deep Dungeon Expedition*) from `Constants.lua` into `ns.BountyDB.DISPATCHES`.
  * Define canonical helper functions on `ns.BountyDB`:
    * `BountyDB:GetDispatch(id)`
    * `BountyDB:GetAllDispatches()`
    * `BountyDB:GetActiveCount()`
* **Direct Caller Updates (Zero Aliases):**
  * In [`UI/SafariMailFrame.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/SafariMailFrame.lua): Replace all references to `C.NESINGWARY_DISPATCHES` with direct calls to `ns.BountyDB.DISPATCHES` / `ns.BountyDB:GetAllDispatches()`.
  * In [`UI/Views/JournalBountiesView.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/Views/JournalBountiesView.lua): Replace all references to `C.NESINGWARY_DISPATCHES` with direct calls to `ns.BountyDB.DISPATCHES` / `ns.BountyDB:GetAllDispatches()`.
* **Zero-Shim Rule:** Do **NOT** assign `C.NESINGWARY_DISPATCHES = ns.BountyDB.DISPATCHES`. Remove the symbol from `Constants.lua` completely.

---

### 2. Purge Duplicates & Directly Wire All Move / Item References
* **Target File:** [`Core/Constants.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/Constants.lua)
* **Dead Code Purge:**
  * Delete `C.SPECIES_CATALOG` (lines 1440–1623, 183 lines).
  * Delete `C.TYPE_MOVE_POOLS` (lines 1427–1439, 13 lines).
  * Delete `C.ABILITIES` (lines 966–1426, 460 lines).
  * Delete `C.SAFARI_ITEMS`, `C.ITEMS`, `C.FAMILY_NOURISHMENT`, `C.CAGES`, `C.TRANSPORT_CRATES`, `C.SHOP_ITEMS` (lines 196–797).
* **Direct Caller Updates for Abilities (Zero Metatables / Zero Shims):**
  * Update [`Core/BattleEngine.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/BattleEngine.lua): Update `BE:GetMoveData` to query only `ns.MoveDB`. Remove fallback to `C.ABILITIES`.
  * Update [`Core/CaptureEngine.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/CaptureEngine.lua): Change `C.ABILITIES[discoveredMove]` to `ns.MoveDB[discoveredMove]`.
  * Update [`UI/Theme.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/Theme.lua): Query `ns.MoveDB` directly in tooltip helpers.
  * Update [`UI/BattleFrame.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/BattleFrame.lua): Query `ns.MoveDB` directly.
  * Update [`UI/Views/JournalRosterView.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/Views/JournalRosterView.lua): Query `ns.MoveDB` directly.
  * Update [`UI/Views/JournalBestiaryView.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/Views/JournalBestiaryView.lua): Query `ns.MoveDB` directly.
* **Direct Caller Updates for Items / Cages / Crates:**
  * Update [`UI/SafariBagFrame.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/SafariBagFrame.lua): Change `C.CAGES` and `C.TRANSPORT_CRATES` to `ns.ItemDB.CAGES` and `ns.ItemDB.TRANSPORT_CRATES`.
  * Update [`UI/ShopFrame.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/ShopFrame.lua): Query `ns.ItemDB` directly.
  * Update [`UI/SafariMailFrame.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/SafariMailFrame.lua): Query `ns.ItemDB.CAGES` directly.
* **Result:** `Constants.lua` shrinks from 1,623 lines down to ~220 pristine lines containing exclusively true constants: `CREATURE_TYPES`, `ATTUNEMENT_RANKS`, permit mappings, and secret-guard helpers.

---

### 3. Extract & Directly Wire `Core/Crypto.lua`
* **Target File:** Create [`Core/Crypto.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/Crypto.lua) under `ns.Crypto`.
* **Content:**
  * Move HMAC hashing (`Hash(str)`), salt key (`SECRET_SALT`), and signature generation (`GenerateSignature(mob)`).
  * Move companion DNA signing (`SignMob(mob)`) and integrity repair (`ValidateAndRepairSignatures(collection)`).
  * Move pure-Lua Base64 string encoding/decoding and companion DNA serializers (`EncodeDNA(mob)`, `DecodeDNA(dnaString)`).
* **Direct Caller Updates (Zero Shims on DB):**
  * In [`Core/Database.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/Database.lua): Replace internal `self:SignMob(mob)` and `self:ValidateAndRepairSignatures()` calls with direct `ns.Crypto:SignMob(mob)` and `ns.Crypto:ValidateAndRepairSignatures(...)`.
  * In [`Core/DB/DB_Pets.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/DB/DB_Pets.lua): Replace `self:SignMob(mob)` calls directly with `ns.Crypto:SignMob(mob)`.
  * In [`UI/InspectorFrame.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/InspectorFrame.lua): Call `ns.Crypto:ValidateSignature(mob)` directly.
* **Zero-Shim Rule:** Do **NOT** keep wrapper forwarding methods like `function DB:SignMob(mob) ns.Crypto:SignMob(mob) end`. Remove them completely from `Database.lua`.

---

### 4. Extract & Directly Wire `Core/BattleCapture.lua`
* **Target File:** Create [`Core/BattleCapture.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/BattleCapture.lua) under `ns.BattleCapture`.
* **Content:**
  * Move all in-battle capture logic:
    * `BattleCapture:CanCapture(enemy)` — checks humanoids, civilized targets, and dungeon boss research permits directly via `C.LOCKED_CREATURE_TYPES`.
    * `BattleCapture:GetCatchChance(enemy, cageId)` — factors in remaining enemy HP, cage gear tier, level delta, and apex rare resistance.
    * `BattleCapture:ExecuteCapture(enemy, cageId)` — performs the roll, manages Transport Crate auto-consumption if active squad is full (4/4), creates the companion instance via `StatEngine:CreateMobInstance`, adds to squad or ships to kennel, and triggers chat logs/toasts.
* **Direct Caller Updates (Zero Shims on BE):**
  * In [`UI/BattleFrame.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/BattleFrame.lua): In the `[ BAG ] ➔ [ CAPTURE ]` menu, invoke `ns.BattleCapture:ExecuteCapture(...)` directly.
  * In [`Core/BattleEngine.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/BattleEngine.lua): Remove capture resolution from lines 920–1020.
* **Zero-Shim Rule:** Do **NOT** keep forwarding wrappers on `BattleEngine`. Captures interact with the dedicated `BattleCapture` engine.

---

### 5. Update Manifest (`ForeverSafari.toc`)
* Update TOC with pure, chronological load order:
  ```toc
  # Canonical Data Registries
  Data\ItemDB.lua
  Data\MoveDB.lua
  Data\BountyDB.lua
  Data\CreatureDB.lua
  Data\BestiaryDB.lua
  Data\EvolutionDB.lua
  Data\TrainerDB.lua

  # Core Engine & Database
  Core\Constants.lua
  Core\Crypto.lua
  Core\Database.lua
  Core\DB\DB_Pets.lua
  Core\DB\DB_Kennel.lua
  Core\DB\DB_Bestiary.lua
  Core\DB\DB_Inventory.lua
  Core\StatEngine.lua
  Core\TrainerEngine.lua
  Core\CaptureEngine.lua
  Core\BattleCapture.lua
  Core\BattleEngine.lua
  Core\QuestHooks.lua
  Core\Comms.lua
  ```

---

## 🔍 Validation Plan

1. **Grep Verification:** Run ripgrep across the entire project for:
   * `C.ABILITIES` ➔ must return **0 results**
   * `C.NESINGWARY_DISPATCHES` ➔ must return **0 results**
   * `C.SPECIES_CATALOG` ➔ must return **0 results**
   * `C.CAGES` / `C.TRANSPORT_CRATES` ➔ must return **0 results**
2. **Syntax Validation:** Execute Python AST syntax verification across all 43 files in the addon directory.
3. **Runtime Consistency:** Confirm that all capture commands, mail frame openings, bestiary lookups, and battle arena actions reference their new canonical modules without any undefined symbol errors.
