# Changelog — Forever Safari

All notable changes to the Forever Safari addon are documented in this file.

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
