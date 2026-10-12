# Implementation Plan: Universal NPC Interaction & Gossip Row Stacking

## 1. Overview & Interaction Rules
This plan establishes the interaction model across all NPCs and bank interfaces in `Forever Safari`:

1. **Non-Interactive / Generic NPCs**:
   - Generic NPCs that are not Innkeepers, Pet Trainers, or Cenarion Keepers will **never** trigger the HUD, show gossip choices, or trigger any feature of the addon.
2. **Innkeepers / Bartenders (Gossip)**:
   - Offer: `Junior Safari League: Rest and Revive Squad` (Revives and restores 100% HP to all party companions).
3. **Pet Trainers / Beast Masters (Gossip)**:
   - Offer: `Junior Safari League: Challenge Outpost Leader` (Launches Outpost Leader battle).
   - Offer: `Junior Safari League: Visit Outfitter` (Opens Safari Supplies Outfitter shop).
4. **Cenarion Keepers in Moonglade (Gossip)**:
   - Offer: `Junior Safari League: Breed My Pet` (Opens co-op pet breeding nursery).
5. **Bankers & Bank Vault (`BankFrame`)**:
   - Bankers do not offer gossip and do not auto-pop sidecar frames.
   - When the bank opens (`BANKFRAME_OPENED`), an integrated **Junior Safari Reserve** tab is provided on `BankFrame`. Clicking this tab opens the banked companion vault docked alongside the bank.
   - Closes automatically when `BANKFRAME_CLOSED` fires.
6. **Universal Row-Stacking Guarantee on Gossip Windows**:
   - On any gossip NPC that displays options, if another third-party addon (e.g. Olympus's `Bones!`, Questie, etc.) modifies `GossipFrame.GreetingPanel`, Forever Safari dynamically detects the lowest external button and anchors directly below it.
   - Guaranteed to always be the bottom-most option on screen, with zero hardcoded addon names or strings.

---

## 2. Universal Addon Row Detection Engine (`Core/SafariGossip.lua`)

### A. Generic External Button Discovery
- Inspect all direct children of `GossipFrame.GreetingPanel`:
  - `child:GetObjectType() == "Button"`
  - `child:IsShown() == true`
  - `not child.isSafariGossipButton`
  - Exclude Blizzard native buttons (`panel.GoodbyeButton`, `GossipFrame.CloseButton`, name/text "Goodbye", "Close", "Cancel").
  - Exclude scrollbar elements and footer chrome (`child:GetBottom() > panel:GetBottom() + 20`).
- Evaluate `child:GetBottom()` across all valid external buttons to find `lowestExternal`.

### B. Dynamic Anchor Placement
- If `lowestExternal` exists:
  - Shrink `ScrollBox` by `totalRowHeight`.
  - Anchor first Forever Safari button to `lowestExternal:BOTTOMLEFT` at `(0, -ROW_GAP)`.
  - Anchor subsequent buttons sequentially beneath each other.
- If no external modifications:
  - Anchor directly beneath `ScrollBox` content extent.

### C. Timing
- Frame 0 (`C_Timer.After(0)`): Immediate layout.
- Frame 2 (`C_Timer.After(0.025)`): Re-evaluates for any third-party addon that initialized on Frame 1, ensuring we smoothly anchor beneath it.

---

## 3. BankFrame Integration (`UI/KennelFrame.lua`)

1. **Remove Automatic Sidecar Pop-up**:
   - Remove automatic `Kennel:ShowKennel()` call from `BANKFRAME_OPENED`.
2. **Attach "Junior Safari Reserve" Tab**:
   - On `BANKFRAME_OPENED`, attach a tab button to `BankFrame` titled **Junior Safari Reserve**.
   - Clicking the tab toggles `KennelFrame` docked cleanly at `TOPLEFT -> BankFrame TOPRIGHT`.
3. **Clean Teardown**:
   - When `BANKFRAME_CLOSED` fires, close `KennelFrame` and deselect the tab.

---

## 4. Execution Steps
1. Refactor `Core/SafariGossip.lua`:
   - Enforce strict NPC classification (return `{}` for generic NPCs).
   - Remove all hardcoded `"Bones"` and Olympus references.
   - Implement universal `IsAddonGossipRow` and `FindLowestExternalButton`.
2. Update `UI/KennelFrame.lua`:
   - Replace auto-popup with the `Junior Safari Reserve` tab on `BankFrame`.
   - Update titles to "Junior Safari Reserve".
3. Validate syntax using `scratch/check_syntax.py`.
4. Git commit and push changes.
