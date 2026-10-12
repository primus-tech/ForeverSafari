# Implementation Plan: Single-Window Junior Safari Reserve (`BankFrame`)

## 1. Overview & Architectural Goal
Currently, the companion vault is opened as a secondary standalone window (720 * 520) floating to the right of `BankFrame` (738 * 460). Because WoW automatically opens all player bags on the right side of the screen upon interacting with a Banker, secondary windows and slide-out drawers create unavoidable window collisions.

This plan integrates the **Junior Safari Reserve** directly **inside `BankFrame` as a single-window view swap**:
- A vertical side tab is mounted to the right border of `BankFrame` featuring a golden paw-print icon 🐾 and tooltip *"Junior Safari Reserve"*.
- Clicking the side tab hides `BankFrame.BankPanel` and displays the Reserve panel directly within the bank's existing 738 * 460 boundaries.
- Clicking the Blizzard bottom tabs (*Character Bank* or *Account Bank*) hides the Reserve panel and restores native bank slots.
- **Zero Bag Collisions**: The entire player inventory on the right remains 100% visible and unobstructed.
- **Zero Taint**: Standalone panel parented to `BankFrame`, using standard script hooks without touching Blizzard secure tables.

---

## 2. Visual & Structural Layout

```
+-------------------------------------------------------------------------+ [🐾 Reserve Tab]
| [Icon] Bank - Junior Safari Reserve                     [Search]  [X]   |
+-------------------------------------------------------------------------+
|                                                                         |
|  ACTIVE SQUAD (4 Max)            RESERVE ENCLOSURES (Bank)              |
|  +---------------------------+   [Box 1] [Box 2] [Box 3] [Box 4] [Box 5]|
|  | [1] Companion A  Lv.25    |   +------------------------------------+ |
|  |     HP: 100%  [Deposit]   |   | [Pet] [Pet] [Pet] [Pet] [Pet]      | |
|  +---------------------------+   | [Pet] [Pet] [Pet] [Pet] [Pet]      | |
|  | [2] Companion B  Lv.18    |   | [Pet] [Pet] [Pet] [Pet] [Pet]      | |
|  |     HP: 100%  [Deposit]   |   | [Pet] [Pet] [Pet] [Pet] [Pet]      | |
|  +---------------------------+   +------------------------------------+ |
|  | [3] Companion C  Lv.12    |                                          |
|  |     HP: 100%  [Deposit]   |   [ Selected Companion Info & Actions ]  |
|  +---------------------------+   [ Withdraw to Squad ]  [ Swap Slot ]   |
|  | [4] Empty Slot            |                                          |
+-------------------------------------------------------------------------+
|  [Character Bank] [Account Bank]                Reserved: 14 companions |
+-------------------------------------------------------------------------+
```

---

## 3. Key Components & Implementation Details

### A. Vertical Edge Side Tab on `BankFrame`
1. **Creation & Anchoring**:
   - Parented to `BankFrame`.
   - Anchored to the upper-right border:
     `sideTab:SetPoint("TOPLEFT", BankFrame, "TOPRIGHT", -2, -50)`
   - Size: `32 * 32` with a tab backing and a crisp paw-print icon (`Interface\Icons\Ability_Hunter_Pet_Cat` or `Interface\Icons\INV_Box_PetCarrier_01`).
2. **Interactive States**:
   - Normal, Highlight, and Selected active glow border.
   - Tooltip: `GameTooltip:SetText("Junior Safari Reserve\n|cffaaaaaaManage your active squad and banked companion enclosures.|r")`.
3. **Click Handler**:
   - Activates the Reserve view mode.

### B. In-Frame Reserve Panel (`ForeverSafariBankReservePanel`)
1. **Container Frame**:
   - Parented directly to `BankFrame`.
   - Anchored to fill the content area:
     `panel:SetPoint("TOPLEFT", BankFrame, "TOPLEFT", 14, -60)`
     `panel:SetPoint("BOTTOMRIGHT", BankFrame, "BOTTOMRIGHT", -14, 34)`
     (Interior dimensions: approximately `710 * 366`).
2. **Squad & Enclosure Layout**:
   - Left Column (Width 230): 4 active squad cards with HP bars, levels, and quick Deposit buttons.
   - Right Column (Width 460): 5 box tabs across the top, 20-slot enclosure grid (4 rows * 5 columns), companion inspection details, and Withdraw/Swap controls.
   - Bottom status line: Shows total reserved companions count.

### C. Seamless View Swapping & Zero-Taint State Synchronization
1. **Activating Junior Safari Reserve**:
   - If `BankFrame.BankPanel` is shown: `BankFrame.BankPanel:Hide()`.
   - If `BankFrame.AutoDepositFrame` is present: hide it.
   - Show `ForeverSafariBankReservePanel`.
   - Set side tab state to `Selected`.
   - Update `BankFrameTitleText` or header to display `|cffffd100Bank - Junior Safari Reserve|r`.
2. **Restoring Blizzard Bank (Character / Account Bank)**:
   - When the user clicks the native Blizzard bottom tabs (`TabSystem` or `BankFrameTab1`/`Tab2`):
     - Hide `ForeverSafariReservePanel`.
     - Set side tab state to unselected.
     - Restore `BankFrame.BankPanel:Show()`.
3. **Bank Close Cleanup (`BANKFRAME_CLOSED` / `OnHide`)**:
   - Hide `ForeverSafariBankReservePanel`.
   - If `BankFrame.BankPanel` was hidden, re-show it so the next bank interaction opens on native bank items.
   - Deselect the side tab.

---

## 4. Execution Steps

1. **Refactor `UI/KennelFrame.lua`**:
   - Convert standalone `ForeverSafariKennelFrame` into an embedded child panel `ForeverSafariBankReservePanel` parented to `BankFrame`.
   - Adjust internal coordinates to fit the 710 * 366 content area.
   - Add the vertical side tab creation on `BankFrame`'s right border.
   - Implement view-swapping logic between `BankPanel` and `ForeverSafariBankReservePanel`.
2. **Hook Blizzard Tab Switching**:
   - Hook native tab clicks so clicking *Character Bank* or *Account Bank* cleanly swaps back to standard bank slots.
3. **Syntax & Balance Validation**:
   - Run `scratch/check_syntax.py` to ensure block balance and zero syntax errors.
4. **Git Commit & Push**:
   - Commit changes to `main` branch.
