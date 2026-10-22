# ⚠️ Forever Safari — Codebase Audit & Defect Registry

**Audit Timestamp:** October 18, 2026  
**Target Client:** World of Warcraft: Forever Beta (`_classic_beta_` / `dataEnv: 16` / modern Retail 11.x/12.x API)  
**Governance Standard:** [Truth.md](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Truth.md) & [FS_CONSTANTS_AND_PVP_SPECIFICATION.md](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Docs/FS_CONSTANTS_AND_PVP_SPECIFICATION.md)  
**Scope:** Full repository analysis (118 source files, 2,175 creature records, 110 moves, persistent state vault).

---

## 📊 Summary of Findings

| ID | Severity | Category | File & Line | Summary | Status |
|---|---|---|---|---|---|
| **#1** | ⛔ **Critical** | Engine / Invariant | [UI/KennelFrame.lua:191](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/KennelFrame.lua#L191) | Prohibited API `SetPortraitZoom(0.85)` present on Kennel card model. | ✅ **Resolved (v1.0.4)** |
| **#2** | ⛔ **Critical** | NPC Interaction | [Core/SafariGossip.lua:473](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/SafariGossip.lua#L473) | Gossip option checks `ns.Shop` instead of `ns.ShopFrame`. Outfitter never opens. | ✅ **Resolved (v1.0.4)** |
| **#3** | 🔴 **High** | Item Database / Economy | [UI/ShopFrame.lua:261](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/ShopFrame.lua#L261) | Crate keys desynced (`crate_copper` vs `copper_crate`). Crates tab is empty. | ✅ **Resolved (v1.0.4)** |
| **#4** | 🔴 **High** | Item Database / Combat | [Data/ItemDB.lua:235](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/ItemDB.lua#L235) | `az_treat` / `az_feast` registered as `safari_treats` / `grand_safari_feast`. | ✅ **Resolved (v1.0.4)** |
| **#5** | 🔴 **High** | UI Notifications | [UI/Toast.lua:115](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/Toast.lua#L115) | 6 caller methods missing from `Toast` system; notifications silently drop. | ✅ **Resolved (v1.0.4)** |
| **#6** | 🔴 **High** | UI State Binding | [Core/DB/DB_Pets.lua:216](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/DB/DB_Pets.lua#L216) | Calls `ns.JournalTeamDock` & `ns.JournalRosterView` which do not exist. | ✅ **Resolved (v1.0.4)** |
| **#7** | 🔴 **High** | Multiplayer Networking | [UI/CatalystLootFrame.lua:204](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/CatalystLootFrame.lua#L204) | Non-existent `SendCommMessage` call and missing `CATALYST_ROLL` listener in Comms. | ✅ **Resolved (v1.0.4)** |
| **#8** | 🟡 **Medium** | HUD / Taxonomy | [UI/CaptureHUD.lua:671](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/CaptureHUD.lua#L671) | Checks `DB:IsSpeciesDiscovered` which does not exist. Sex badge stays Unknown. | ✅ **Resolved (v1.0.4)** |
| **#9** | 🟡 **Medium** | Journal Dossier | [Core/StatEngine.lua:432](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/StatEngine.lua#L432) | `abilities` set on mob instance without `moves`; Journal Roster cards show blank. | ✅ **Resolved (v1.0.4)** |
| **#10** | 🟡 **Medium** | TOC Architecture | [ForeverSafari.toc:66, 72](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/ForeverSafari.toc#L66) | `Constants.lua` loads after `BestiaryDB.lua`, breaking fallback model ID lookups. | ✅ **Resolved (v1.0.4)** |
| **#11** | 🟡 **Medium** | Combat HUD | [UI/BattleFrame.lua:1503](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/BattleFrame.lua#L1503) | ExpBar queries obsolete `player.xp` instead of 5-Rank Attunement points. | ✅ **Resolved (v1.0.4)** |
| **#12** | 🟢 **Low** | Branding / Chat | [Core/Constants.lua:30](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/Constants.lua#L30) | `C.PREFIX` version tag `v1.0.2` desynced from TOC and CHANGELOG `v1.0.3`. | ✅ **Resolved (v1.0.4)** |
| **#13** | ⛔ **Critical** | Combat Engine / UI | [UI/BattleFrame.lua:715](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/BattleFrame.lua#L715) | Missing `C.GetDefaultIcon` causes Lua error on trainer battle turn, freezing combat. | ✅ **Resolved (v1.0.5)** |
| **#14** | 🔴 **High** | Item Consumables | [UI/SafariBagFrame.lua:575](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/SafariBagFrame.lua#L575) | `activeMob.hp` priority over `currentHP` falsely blocks Healing Salve on injured pets. | ✅ **Resolved (v1.0.5)** |
| **#15** | 🔴 **High** | Taxonomy / World Invariants | [Data/TrainerDB.lua:21, 181](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/TrainerDB.lua#L21) | Fabricated creature names and Ironforge Dwarf display ID (1629) collisions in Trainer/Outpost DBs. | ✅ **Resolved (v1.0.5)** |

---

## 🔎 Detailed Defect Reports

### Defect 1: Prohibited Model API Violation in Kennel Frame
* **File**: [`UI/KennelFrame.lua:191`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/KennelFrame.lua#L191)
* **Severity**: ⛔ Critical (Governance Invariant Violation)
* **Specification Mandate**: `Truth.md` Section 8 explicitly states:
  > *"NEVER call SetCustomCamera(0) or SetPortraitZoom() anywhere in this addon. They distort, invert, or clip models on the modern client engine. Rely solely on SetCreature(), SetDisplayInfo(), or standard PlayerModel:SetModel() calls."*
* **Root Cause**: When the `v1.0.2` camera purge stripped legacy camera hooks from `BattleFrame`, `JournalFrame`, `InspectorFrame`, and `JournalRosterView`, `UI/KennelFrame.lua` was overlooked.
* **Impact**: On modern Retail engines (`dataEnv: 16`), calling `SetPortraitZoom` on small companion cards forces facial clipping and inverts or truncates animal bodies.
* **Fix**: Delete line 191 (`if model.SetPortraitZoom then model:SetPortraitZoom(0.85) end`).

---

### Defect 2: Broken NPC Gossip Link to Safari Outfitter Shop
* **File**: [`Core/SafariGossip.lua:473-475`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/SafariGossip.lua#L473-L475)
* **Severity**: ⛔ Critical (Gameplay Blocker)
* **Root Cause**: The gossip menu option for Pet Trainers attempts to invoke `ns.Shop:ShowShop(true)`:
  ```lua
  if ns.Shop and ns.Shop.ShowShop then
      ns.Shop:ShowShop(true)
  end
  ```
  However, in [`UI/ShopFrame.lua:11-13`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/ShopFrame.lua#L11-L13), the module is registered under `ns.ShopFrame`. `ns.Shop` is `nil`.
* **Impact**: Players speaking to Pet Trainers across capital cities and towns click *"Junior Safari League: Visit Outfitter"* and nothing happens. The Outfitter shop is completely inaccessible via NPC dialogue.
* **Fix**: Change `ns.Shop` to `ns.ShopFrame`.

---

### Defect 3: Transport Crate Key Mismatch (Empty Shop Tab & Broken Rewards)
* **Files**:
  - [`UI/ShopFrame.lua:261`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/ShopFrame.lua#L261)
  - [`Data/BountyDB.lua:29`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/BountyDB.lua#L29)
  - [`Core/BattleCapture.lua:93`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/BattleCapture.lua#L93)
  - [`Data/ItemDB.lua:105-145`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/ItemDB.lua#L105-L145)
* **Severity**: 🔴 High
* **Root Cause**: `Data/ItemDB.lua` defines the items with the metal prefix first:
  ```lua
  ItemDB.TRANSPORT_CRATES = {
      ["copper_crate"] = { ... },
      ["iron_crate"] = { ... },
      ["mithril_crate"] = { ... },
      ["thorium_crate"] = { ... },
  }
  ```
  `Core/DB/DB_Kennel.lua` also expects `copper_crate`, `iron_crate`, etc.
  Conversely:
  - `ShopFrame.lua:261` queries `local crateKeys = { "crate_copper", "crate_iron", "crate_mithril", "crate_thorium" }`.
  - `BountyDB.lua:29` awards `{ id = "crate_copper", count = 3 }`.
  - `BattleCapture.lua:93` constructs `crateKey = "crate_copper"`.
* **Impact**:
  1. The **Transport Crates** category in the Safari Outfitter Shop renders completely blank.
  2. Dispatch Bounty #1 awards an item ID that `ItemDB:GetItem()` returns `nil` for.
* **Fix**: Align all references to `copper_crate`, `iron_crate`, `mithril_crate`, `thorium_crate` and add backward-compatibility aliases in `ItemDB:GetCrate()` and `ItemDB:GetItem()`.

---

### Defect 4: Treat & Feast Key Desync (`az_treat` vs `safari_treats`)
* **Files**:
  - [`Data/ItemDB.lua:235-254`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/ItemDB.lua#L235-L254)
  - [`Core/BattleEngine.lua:2037`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/BattleEngine.lua#L2037)
  - [`UI/BattleFrame.lua:1099`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/BattleFrame.lua#L1099)
  - [`UI/SafariBagFrame.lua:536`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/SafariBagFrame.lua#L536)
  - [`Data/BountyDB.lua:49, 136`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/BountyDB.lua#L49)
* **Severity**: 🔴 High
* **Root Cause**: In `Data/ItemDB.lua`, treats are named `safari_treats` and `grand_safari_feast`. However, initial database inventories (`Core/Database.lua:44`), combat item usage (`Core/BattleEngine.lua:2037`), battle frame bag slots (`UI/BattleFrame.lua:1099`), bag item click handlers (`UI/SafariBagFrame.lua:536`), and bounty rewards all check for `"az_treat"` and `"az_feast"`.
* **Impact**:
  - `ItemDB:GetItem("az_treat")` returns `nil`.
  - In `BattleFrame.lua:1569`, slot 6 of the battle bag evaluates `itemData` to `nil` and renders as an untextured, dead button.
  - In `SafariBagFrame.lua`, treats fall back to generic brown backpack icons.
* **Fix**: Register `az_treat` and `az_feast` in `ItemDB.ITEMS` (or alias them to `safari_treats` and `grand_safari_feast`).

---

### Defect 5: Missing Toast Notification Methods (Silent Notification Failures)
* **Files**:
  - [`UI/Toast.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/Toast.lua)
  - [`Core/DB/DB_Inventory.lua:32, 71`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/DB/DB_Inventory.lua#L32)
  - [`Core/DB/DB_Bestiary.lua:81, 92`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/DB/DB_Bestiary.lua#L81)
  - [`Core/DB/DB_Pets.lua:284, 432, 473`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/DB/DB_Pets.lua#L284)
* **Severity**: 🔴 High
* **Root Cause**: `Toast.lua` defines only `ShowReward`, `ShowCapture`, and `ShowAlert`. The core modules attempt to trigger six specialized notification channels:
  1. `Toast:ShowTokenGain(amount, reason)`
  2. `Toast:ShowItemGain(itemId, count)`
  3. `Toast:ShowBestiaryDiscovery(spec, status)`
  4. `Toast:ShowAttunementUp(mob, newRank)`
  5. `Toast:ShowMoveLearned(moveKey, sourceMobName)`
  6. `Toast:ShowPermitUnlocked(creatureType)`
* **Impact**: Callers guard with `if ns.Toast and ns.Toast.ShowX then`. Because the methods do not exist, all of these celebration popups fail silently. Players receive no visual feedback upon token acquisition, ranking up companions, discovering new species, or learning moves.
* **Fix**: Implement the 6 missing notification methods in `UI/Toast.lua`.

---

### Defect 6: Invalid UI Refresh References in `DB_Pets.lua`
* **File**: [`Core/DB/DB_Pets.lua:216-221, 520-521, 550-551`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/DB/DB_Pets.lua#L216-L221)
* **Severity**: 🔴 High
* **Root Cause**: `DB_Pets.lua` invokes:
  ```lua
  if ns.JournalTeamDock and ns.JournalTeamDock.UpdateDock then
      ns.JournalTeamDock:UpdateDock()
  end
  if ns.JournalRosterView and ns.JournalRosterView.UpdateUI then
      ns.JournalRosterView:UpdateUI()
  end
  ```
  Neither `ns.JournalTeamDock` nor `ns.JournalRosterView` exist as standalone namespace tables. Their functions are attached directly to `ns.JournalFrame` as `Journal:UpdateTeamDock()` and `Journal:UpdateRosterView()`.
* **Impact**: Squad re-ordering, swaps, and resting at innkeepers fail to refresh the active squad dock and roster view if the Safari Journal is open.
* **Fix**: Re-route the calls to `ns.JournalFrame:UpdateTeamDock()` and `ns.JournalFrame:UpdateRosterView()`.

---

### Defect 7: Broken Peer-to-Peer Catalyst Loot Rolling
* **Files**:
  - [`UI/CatalystLootFrame.lua:204-206`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/CatalystLootFrame.lua#L204-L206)
  - [`Core/Comms.lua:348-402`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/Comms.lua#L348-L402)
* **Severity**: 🔴 High
* **Root Cause**:
  1. `CatalystLootFrame.lua` checks for `ForeverSafari.Comms.SendCommMessage`. The comms engine only exposes `SendMessage(msgType, data, targetPlayer)`.
  2. `Comms:OnMessageReceived` has no routing branch for `"CATALYST_ROLL"`.
* **Impact**: `CatalystLootFrame:ReceivePeerRoll` is orphaned. In dungeon groups, party rolls never broadcast or synchronize, making group catalyst distribution impossible.
* **Fix**: Use `Comms:SendMessage("CATALYST_ROLL", payload)` and register the handler in `Comms:OnMessageReceived`.

---

### Defect 8: Capture HUD Target Sex Check Calling Non-Existent DB Method
* **File**: [`UI/CaptureHUD.lua:671`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/CaptureHUD.lua#L671)
* **Severity**: 🟡 Medium
* **Root Cause**: The HUD queries `DB.IsSpeciesDiscovered and DB:IsSpeciesDiscovered(name)`. `DB` provides `GetBestiaryEntry(nameOrId)` and `DiscoverSpecies(nameOrId, status)`, but does not implement `IsSpeciesDiscovered`.
* **Impact**: `isDiscovered` is always `nil`. When targeting a wild creature already caught or recorded in the bestiary, the HUD falls back to `[❓ Sex: Unknown]` unless it was actively scanned in the current session.
* **Fix**: Implement `DB:IsSpeciesDiscovered(nameOrId)` in `Core/DB/DB_Bestiary.lua`.

---

### Defect 9: Newly Instantiated Companions Missing Move Cards in Journal
* **Files**:
  - [`Core/StatEngine.lua:432`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/StatEngine.lua#L432)
  - [`UI/Views/JournalRosterView.lua:570`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/Views/JournalRosterView.lua#L570)
* **Severity**: 🟡 Medium
* **Root Cause**: `SE:CreateMobInstance` assigns `abilities = abilities`, but does not assign `moves = abilities`. In `JournalRosterView.lua`, move card rendering checks `local moveId = mob.moves and mob.moves[i]` without falling back to `mob.abilities`.
* **Impact**: Newly captured or generated companions display empty move cards (`[+ Train]`) in the Safari Journal Roster view instead of their starting baseline abilities.
* **Fix**: In `StatEngine.lua`, assign `moves = abilities, abilities = abilities`, and add a fallback in `JournalRosterView.lua`.

---

### Defect 10: TOC File Load Order Prevents Fallback 3D Display Resolution
* **Files**:
  - [`ForeverSafari.toc:66, 72`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/ForeverSafari.toc#L66)
  - [`Data/BestiaryDB.lua:387, 434`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/BestiaryDB.lua#L387)
* **Severity**: 🟡 Medium
* **Root Cause**: `Data\BestiaryDB.lua` executes `Bestiary:BuildFromCreatureDB()` immediately at file parse time. In line 387, it queries `FS.Constants and FS.Constants.GetDefaultDisplayId`. Because `Core\Constants.lua` is loaded at line 72 (after `BestiaryDB.lua` at line 66), `FS.Constants` is `nil`.
* **Impact**: Fallback display IDs for creatures missing explicit display models cannot be assigned during bestiary build.
* **Fix**: Move `Core\Constants.lua` higher in `ForeverSafari.toc` before `Data\CreatureDB.lua` and `Data\BestiaryDB.lua`.

---

### Defect 11: Battle Frame EXP Bar Using Traditional RPG XP
* **File**: [`UI/BattleFrame.lua:1503-1504`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/BattleFrame.lua#L1503-L1504)
* **Severity**: 🟡 Medium
* **Root Cause**: Code binds the battle HUD experience bar to `player.maxXP` and `player.xp`:
  ```lua
  frame.PlayerHUD.ExpBar:SetMinMaxValues(0, player.maxXP or 100)
  frame.PlayerHUD.ExpBar:SetValue(player.xp or 0)
  ```
  Neither field exists in Forever Safari's 5-Rank Attunement system (`Truth.md` Section 13).
* **Impact**: The combat HUD ExpBar remains permanently static at 0/100 during wild encounters.
* **Fix**: Bind min/max and value to the companion's active rank in `C.ATTUNEMENT_RANKS` and `player.attunement`.

---

### Defect 12: Addon Chat Prefix Version String Mismatch
* **File**: [`Core/Constants.lua:30`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/Constants.lua#L30)
* **Severity**: 🟢 Low
* **Root Cause**: `C.PREFIX` contains `|cffffd100[Forever Safari v1.0.2]|r `, while `ForeverSafari.toc` and `CHANGELOG.md` are at `v1.0.3`.
* **Impact**: Chat announcements print an outdated version tag.
* **Fix**: Update prefix to `v1.0.4`.

---

### Defect 13: Missing `C.GetDefaultIcon` Causes Battle UI Crash in Trainer/Multi-Pet Battles
* **Files**:
  - [`Core/Constants.lua:305-314`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/Constants.lua#L305-L314)
  - [`UI/BattleFrame.lua:715, 823`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/BattleFrame.lua#L715)
* **Severity**: ⛔ Critical (Combat Freeze)
* **Root Cause**: In multi-pet battles and trainer battles (`isTrainerBattle = true`), `BF:UpdatePartyFrames()` is invoked to render the side roster bars. Lines 715 and 823 attempted to call `C.GetDefaultIcon(mob.family or mob.creatureType)`. However, `C.GetDefaultIcon` was not defined in `Core/Constants.lua`, throwing a nil-call Lua runtime error. When the player executed an attack (`BE:ExecutePlayerMove`), the initial log message (`BE:AddLog`) invoked `BF:UpdateLog()`, which called `BF:UpdateUI()`, crashing at line 715 before any damage or turn advance logic could run.
* **Impact**: Trainer and outpost battles completely froze after player selected their first attack move; animations and turns halted.
* **Fix**: Implemented `C.GetDefaultIcon(creatureType, mobName)` in `Constants.lua`, added fallback checks in `BattleFrame.lua:715, 823`, and wrapped `UpdatePartyFramesVisibility` in `pcall`.

---

### Defect 14: Incorrect HP Precedence Blocks Healing Salve and Revival Crystal
* **File**: [`UI/SafariBagFrame.lua:575, 600`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/SafariBagFrame.lua#L575)
* **Severity**: 🔴 High (Item Consumable Failure)
* **Root Cause**: `activeMob.hp` represents the static maximum base stat assigned during companion generation, whereas live battle damage and healing are tracked on `activeMob.currentHP`. Lines 575 and 600 checked:
  ```lua
  local currentHP = activeMob.hp or activeMob.currentHP or activeMob.maxHP or 10
  ```
  Because `activeMob.hp` was evaluated first, `currentHP` was read as `40` (full HP), causing `currentHP >= maxHP` to return true even when the companion was at `9 HP`.
* **Impact**: Players could not use Healing Salves from `/fsbag` on wounded pets.
* **Fix**: Corrected precedence to `tonumber(activeMob.currentHP) or tonumber(activeMob.hp) or tonumber(activeMob.maxHP)`, added faint guards, and synchronized `mob.hp = mob.currentHP` on damage/heal events in `Core/BattleEngine.lua`.

---

### Defect 15: Fabricated Creature Taxonomy and Humanoid Dwarf Display ID (1629) Collisions in Trainer/Outpost Databases
* **Files**:
  - [`Data/TrainerDB.lua:21, 81, 124, 181`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/TrainerDB.lua#L21)
  - [`Data/OutpostDB.lua:178, 688, 1363, 1758, 2033, 2123, 2153`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/OutpostDB.lua#L178)
* **Severity**: 🔴 High (Taxonomy & Visual Integrity)
* **Root Cause**:
  1. Although `Tools/build_creatures.py` scraped 2,175 canon World of Warcraft creatures into `Data/Creatures/` and pre-baked authentic display IDs in `Data/CreatureDisplays.lua`, early development of `Data/TrainerDB.lua` manually hardcoded mock companion pools ("Defias", "Default", "Pirate", "Scarlet") using invented placeholder names (`Prairie Hawk`, `Prowler Wolf`, `River Snapjaw`) and zone ecology misassignments (e.g. placing Elwynn Forest's `Mangy Wolf` into Westfall encounter pools instead of native Coyotes).
  2. In `CreatureDisplayInfo.dbc`, creature ID **1629** corresponds to **Mountaineer Gravelgaw** (an Ironforge Dwarf guard in Loch Modan). When authors created bird and tallstrider entries in `TrainerDB.lua` and `OutpostDB.lua`, they copy-pasted `displayId = 1629` as dummy data.
* **Impact**:
  - Whenever players encountered wandering rivals, Defias trainers, or outpost masters using these entries (such as "Prairie Hawk", "Scarlet Hawk", or various Tallstriders), the 3D model pedestal rendered an Ironforge Dwarf instead of a beast.
  - Fabricated creature names and zone mismatches violated canon WoW taxonomy and desynced encounters from authentic zone ecology (e.g. Westfall Zone 40).
* **Canon Preservation Note**:
  - **Zephras Isle** and **Zephras Reef Strider** are authentic canon from the new Sky Elf zone in WoW Forever Beta. All Zephras zone nomenclature, lore, and titles remain strictly intact; only the dummy `displayId = 1629` was replaced with the canonical Tallstrider model ID (`1219`).
* **Fix**:
  1. Purged `displayId = 1629` across all files:
     - `TrainerDB.lua`: `Default` rival pool now features authentic Westfall (Zone 40) creatures: `Coyote` (display 643), `Greater Fleshripper` (display 1105), `Shore Crawler` (display 9570).
     - `TrainerDB.lua`: `Defias` pool now uses `Coyote` (643), `Harvest Golem` (378), `Greater Fleshripper` (1105), and `Goretusk` (3027).
     - `TrainerDB.lua`: `Scarlet` replaced with `Plagued Bat` (display 9535); `Pirate` replaced with `Bloodsail Parrot` (display 2768).
     - `OutpostDB.lua`: `Prairie Strider`, `Mire Strider`, and `Zephras Reef Strider` updated to `displayId = 1219`; `Highborne Falcon` to `displayId = 4877`; `Mesa Tallstrider` to `displayId = 1220`; `Bloodsail Macaw` and `Trained Bloodsail Macaw` to `displayId = 2768`.

