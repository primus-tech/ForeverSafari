# Changelog — Forever Safari

All notable changes to the Forever Safari addon are documented in this file.

---

## [v1.0.3] — 2026-10-18

### 🐛 Critical Bug Fixes & System Improvements

#### 1. 3D Model Pedestal Arena Rendering & Viewport Synchronization
- **Fixed Blank Battle Arena Pedestals**: Resolved a critical issue where neither the player's companion nor the opposing trainer's beast appeared on the 3D model pedestals upon initiating battle.
- **Asynchronous Viewport Layout Synchronization**: Identified and resolved modern Retail client engine (`_classic_beta_` / `dataEnv: 16`) viewport layout race conditions where invoking `:SetDisplayInfo()` synchronously in the same call stack as `frame:Show()` failed due to uninitialized 0×0 native Direct3D/OpenGL canvas dimensions.
- **Multi-Pass Deferred Render Ticks**: Added deferred synchronization ticks via `C_Timer.After(0.05)` and `C_Timer.After(0.2)` in `BF:ShowBattle()`, combined with an `OnShow` frame script hook on `ForeverSafariBattleFrame` in [UI/BattleFrame.lua](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/UI/BattleFrame.lua).
- **Eliminated Asynchronous `ClearModel()` Race Condition**: Replaced unconditional `ClearModel()` calls with display ID caching (`_currentDisplayId`), preventing the engine's asynchronous unmount queue from destroying newly requested model display meshes.
- **Asynchronous `OnModelLoaded` Script Hook**: Registered `OnModelLoaded` event handlers on `PlayerModel` widgets to ensure rotation, camera distance scale (`1.0`), and idle animation (`0`) are cleanly applied after CASC streaming completes.
- **Corrected Player Model Initialization Facing**: Fixed the initial player companion rotation in `BF:Initialize()` from `math.rad(145)` to the canonical `math.rad(45)` facing diagonally forward toward the opponent.
- **Dynamic Turn Desync Auto-Recovery**: Added automatic state verification in `BF:UpdateUI()` so that if 3D model frames ever lose attachment, they immediately re-mount without requiring UI reloads.
- **Type-Safe Display ID Parsing**: Wrapped display IDs with `tonumber()` to guard against stringified SavedVariables causing Lua 5.1 comparison errors.

#### 2. Moonkin / Wildkin Humanoid Rival Battler & AI Trainer Archetype
- **Humanoid Mob Rule Enforcement**: Ensured all Moonkin, Wildkin, and Owlbeast mobs (such as Young Moonkin, Moonkin, and Raging Moonkin in Darkshore near Auberdine) are strictly recognized as Humanoid NPC Trainers fielding their own companion rosters, never as catchable wild beasts.
- **Dedicated `"Moonkin"` Archetype**: Added the `Wildkin Moon-Watcher` archetype to [Data/TrainerDB.lua](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/TrainerDB.lua) with authentic lore quotes:
  - *Intro*: "Hoooot! The sacred forest spirits answer the moon's call!"
  - *Defeat*: "Hoo-oo... Elune watches over your journey..."
  - *Bounty*: +12 Safari Tokens base reward.
- **Thematic Companion Beast Roster**: Configured an authentic nature/druidic companion squad for Wildkin trainers:
  - **Sprite Darter** (Dragonkin, Display ID: 2769, Moves: 901, 902)
  - **Darkshore Thistle Bear** (Beast, Display ID: 742, Moves: 101, 102)
  - **Moonstalker Cub** (Beast, Display ID: 775, Moves: 103, 107)
  - **Darkshore Strider** (Tallstrider, Display ID: 1068, Moves: 101, 202)
- **Robust Name & Creature Type Resolution**: Extended `TrainerDB:GetArchetypeForUnit` and `TE:IsHumanoidTrainer` ([Core/TrainerEngine.lua](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Core/TrainerEngine.lua)) with fallback string matching for `"moonkin"`, `"wildkin"`, and `"owlbeast"`.

---

## [v1.0.2] — 2026-10-17

### 🐛 Critical Bug Fixes

#### 1. Turn-Based Battle Engine & Combat Log Stability
- **Fixed Combat Start UI Crash**: Resolved a fatal Lua runtime error (`UI/BattleFrame.lua:301: attempt to call a nil value`) triggered during battle initialization. Replaced non-existent legacy method `:IsAtBottom()` with the canonical modern Retail ScrollingMessageFrame API method `:AtBottom()`.
- **Battle Log Auto-Scroll**: Messages now cleanly auto-scroll down to the latest round resolution without locking or interrupting turn sequencing.

#### 2. SavedVariables Persistence & Session Reload Integrity
- **Fixed `/reload` State Wipe**: Resolved an issue where newly unboxed starter companions, captured wildlife, and inventory items were wiped upon UI reload or logout.
- **Removed Destructive Logout Hook**: Purged `ForeverSafariDB = nil` from `ForeverSafari.lua` (`PLAYER_LOGOUT`), ensuring `ForeverSafariDB` remains persistent, encrypted, and authoritative across all client sessions.

#### 3. 3D Paperdoll Model Framing & Camera Lock Overhaul
- **Purged Legacy Portrait Camera Lock**: Removed hardcoded `SetCustomCamera(0)` and `SetPortraitZoom(0)` from `UI/BattleFrame.lua`, `UI/JournalFrame.lua`, `UI/InspectorFrame.lua`, and `UI/Views/JournalRosterView.lua`. 
- **Full Bounding-Box Perspective Rendering**: Modern Retail `PlayerModel` now relies on canonical `:SetDisplayInfo()` engine framing, cleanly centering the full creature body on its arena or journal pedestal without cropping or macro-zooming into teeth or skull bones.
- **Corrected Arena Facing Angles**: Player companion faces diagonally forward-right toward the quarry (`math.rad(45)`), and wild enemy faces diagonally forward-left toward the player (`math.rad(-35)`).
- **Smooth Spotlight Rotation & Zoom**: Unified rotation state in `UI/Views/JournalRosterView.lua` across mouse dragging and the `◄` / `►` buttons using `:SetRotation()`.

#### 4. Field Directives & Observation Quest Progression
- **Reverted Dispatch #2 to Field Observation**: Corrected `Dispatch #2: Field Observation 101` (`Data/BountyDB.lua`) from an unintended capture requirement (`CAPTURE_TOTAL`) back to pure field observation (`OBSERVE`).
- **Objective**: Study 3 wild creatures in their natural habitat using the field research lens / binoculars.
- **Progress Tracking Hook**: Connected `CaptureEngine:CompleteSnareChannel()` directly to `DB:UpdateQuestProgress("OBSERVE", 1)`.
- **Verified Mailbox Reward Claiming**: Validated turn-in at town mailboxes to claim +20 Safari Tokens, 3x Iron Cages, and 2x Safari Treats, cleanly unlocking Dispatch #3 (*The Wild Nourishment*).

---

## [v1.0.1] — 2026-10-15
- Initial public release of the modular Junior Safari League addon.
- Turn-based 2.5D Battle Arena, Virtual Safari Bag, Kennel Vault, and Field Guide Journal.
