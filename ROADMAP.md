# 🗺️ Forever Safari — Master Development Roadmap
**Target Client:** World of Warcraft: Forever Beta (`_classic_beta_` / `dataEnv: 16` / `1.60.1`)  
**Addon:** Forever Safari (`ForeverSafari`)  
**Organization:** Nesingwary Junior Safari League  

---

## 📍 Phase 1: Core Foundation & Branding (Completed ✅)
* [x] **Universal Addon Architecture**: Pure `ForeverSafari` namespace across all core and UI modules with zero legacy shims.
* [x] **3D Paperdoll Field Guide**:
  * 3D Carousel Showcase Stage with 360° mouse drag rotation, zoom, animation triggers (Attack, Roar, Victory, Idle), and flanking models.
  * 3D Menagerie Gallery Grid with 9-element type filters and pagination.
  * 3D Active Team Dock (Slots 1–4) with live mini-pedestals.
* [x] **Hemet Nesingwary Onboarding & 8-Race Starter Matrix**:
  * Dwarf (Bear), Gnome (Boar), Orc (Scorpid), Troll (Bloodtalon Raptor), Tauren (Kodo), Undead (Bat), Night Elf (Nightsaber), Human (Mangy Wolf).
* [x] **Creature Taxonomy & Forbidden Species Policy**:
  * Allowed: Beasts, Mindless Undead, Elementals, Dragon Whelps, Mechanicals, Uncategorized Behemoths (e.g. Aku'mai).
  * Prohibited: Bipedal/sapient humanoids & civilized tribes (No Ogres, Kobolds, Troggs, Gnolls, Defias, Murlocs, Naga, Furbolgs, Quilboars, Centaurs, sentient Forsaken/Liches, or humanoid Dragonkin).

---

## 📍 Phase 2: Wowhead Forever Data Pipeline & Relational DB (Completed ✅)
* [x] **Scraper Pipeline**: Extracted authentic Forever Beta `displayId`s (e.g. Mangy Wolf `903`, Aku'mai `2837`, Harvest Watcher `378`, Raptor `1960`).
* [x] **Normalized Relational Architecture (`Data/CreatureDB.lua`)**:
  * **Master Keyed Table**: 1,909 species across all allowed families with 715 exact 3D models.
  * Single source of truth with zero data duplication across multiple habitat zones.
  * $O(1)$ Instant World Target & Capturability detection via `UnitGUID("target")` -> `npcId`.
* [x] **Dynamic Inverted Indexing (`ADDON_LOADED`)**:
  * `ZoneIndex[zoneId] = { npcId1, npcId2, ... }` for zero-latency zone radar & habitat maps.
  * `FamilyIndex[family] = { ... }` and `ElementIndex[element] = { ... }` for instant 3D Menagerie grid filtering.
* [x] **Move & Evolution Databases (`Data/MoveDB.lua`, `Data/EvolutionDB.lua`)**:
  * Standardized movepools with power, accuracy, PP, and spell icons.
  * Boss drop tables for dungeon catalysts.

---

## 📍 Phase 3: Database Security & Signed DNA Architecture (Completed ✅)
* [x] **Salted Cryptographic Signature (`sig`)**:
  * Every companion generates an authentic signature: `sig = Hash(id, name, level, hp, atk, def, spd, displayId, SECRET_SALT)`.
  * Protects against manual Notepad tampering of levels, stats, or illegal abilities.
  * Integrity auto-validation on load; safely repairs or flags tampered entries.
* [x] **Pure-Lua Base64 Serializer (`Core/Database.lua`)**:
  * Encodes and decodes companion DNA strings (`!FS:...`) for external and cross-player sharing.
* [x] **Token Vault Protection**:
  * Account-bound protection for Safari Tokens to prevent currency spoofing.

---

## 📍 Phase 4: Social & 3D Companion Sharing (Completed ✅)
* [x] **In-Game Chat Hyperlinks**:
  * Shift-Click any companion in the Field Guide to generate an interactive chat link: `[Safari: Mangy Wolf (3D)]`.
* [x] **3D Companion Inspector Popup (`UI/InspectorFrame.lua`)**:
  * Clicking a chat link opens a popup rendering the friend's companion in live 3D with its stats, custom nickname, and active 4-move loadout.
* [x] **Hemet Nesingwary Dispatch Parchment (`UI/DispatchLetterFrame.lua`)**:
  * First-login antique letter modal from Hemet delivering the starter crate unboxing sequence.

---

## 📍 Phase 5: Attunement Loyalty & Metamorphosis (Completed ✅)
* [x] **5-Rank Attunement Loyalty System (Replaces XP Leveling)**:
  * **Attunement Channels**: Battle resilience (surviving battles without fainting), family nourishment (feeding resources from downed animals of same family), and native zone acclimation.
  * **Rank I (Wild / Unbroken)**: 25% Disobedience chance, 1 Active Move, 0.85x Base Stats.
  * **Rank II (Tolerant)**: 15% Disobedience chance, 2 Active Moves, 0.95x Base Stats.
  * **Rank III (Trusting)**: 5% Disobedience chance, 3 Active Moves, 1.00x Base Stats (True Base).
  * **Rank IV (Devoted)**: 0% Disobedience, 5% Crit Strike bonus, 4 Active Moves, 1.05x Base Stats.
  * **Rank V (Bestial Symbiosis)**: 0% Disobedience, 4 Active Moves + Innate Perk, 1.15x Base Stats, **Metamorphosis Eligible**!
* [x] **Vanilla Hunter-Style Family Grimoire**:
  * Shared movepools per family (e.g. all Wolves share the Canine Grimoire).
  * Observation & Field Learning: Capturing wild creatures unlocks abilities into your Trainer Grimoire.
  * Move capacity dynamically scales from 1 to 4 based on Attunement Rank.
* [x] **Rare Spawn Protection & Reserved Names**:
  * Reserved registry prevents naming common pets after world rares (e.g. *Humar the Pridelord*, *The Rake*, *Broken Tooth*).
  * Authentic wild rares display unforgeable Golden Rare Dragon crests in the 3D Inspector.
  * **Evolution Exemption**: Rare and Legendary apex creatures cannot be evolved, preserving their iconic wild prestige.
* [x] **Dungeon Evolution Catalysts & Greed-Only Secondary Loot (`UI/CatalystLootFrame.lua`)**:
  * Defeating dungeon bosses drops rare evolution catalysts (e.g. *[Shadowfang Essence]* from SFK).
  * **Secondary Loot Window**: Pops on boss defeat with a 60-second timer.
  * **Greed-Only Fair Roll**: Need button is permanently disabled ("No one can Need on League Catalysts"); players Greed or Pass with multi-player comm sync.
  * **Rank V Metamorphosis**: Using a catalyst at Rank V triggers a 3D pedestal evolution (Mangy Wolf ➔ Slavering Worg) with scaled stats and apex moves.

---

## 📍 Phase 6: Virtual Safari Bag & Item Management (Completed ✅)
* [x] **20-Slot Authentic Container Bag (`UI/SafariBagFrame.lua`)**:
  * Styled as an authentic World of Warcraft container bag with gold-trimmed border, quality borders, stack badges, and authentic container sounds.
  * **Addon-Exclusive Storage**: Stores exclusively items tied to Forever Safari without using player inventory bag slots.
  * **Categorized Inventory**:
    * 🕸️ **Safari Nets**: Copper, Iron, and Mithril Nets, Arcanite Capsules.
    * 🥩 **Family Nourishment**: 17 wild harvested diets (Canine, Feline, Bear, Boar, Raptor, etc.) with favorite food attunement bonuses (+25 Attunement).
    * 🧬 **Evolution Catalysts**: Dungeon boss drops (Shadowfang Essence, Hydra Bile, Venomous Gland, Overclocked Core, Volcanic Core).
    * 🍖 **Consumables**: Treats (+50 Attunement), Feasts (+100 Attunement team-wide), Salves (100% Heal), and Revival Crystals.
  * **Context-Sensitive Actions**: Right-Clicking uses/equips items, feeds or heals active companion, or initiates Metamorphosis in the Field Guide. Shift-Clicking inserts item links into chat.
  * **Integration & Access**: Quick access buttons in Journal header, Minimap button middle/shift-click, Capture HUD, and `/fsbag` or `/safari bag` slash commands.

---

## 📍 Phase 7: Field Research Stalking & Channeling Engine (Completed ✅)
* [x] **0% Mob Damage Decoupling (Hunter Coexistence Architecture)**:
  * Eliminates mob HP whittling entirely. Live world quarry remains **100% untouched, un-tagged, and at full HP** in the game world.
  * Solves high-level one-shot accidents, tap theft, and hunter griefing over world rare spawns.
* [x] **Proximity & Stalking Radar (`Core/CaptureEngine.lua`, `UI/CaptureHUD.lua`)**:
  * **Close Stalk (~10 yards)**: High-risk proximity yielding **+25% Catch Power Bonus** (`1.25x`).
  * **Standard Perimeter (15–28 yards)**: Baseline stalking perimeter (`1.0x`).
  * **Beyond Perimeter (>28 yards)**: Out of range; requires closing distance before channeling.
* [x] **Channeling Minigame & Stalking Castbar**:
  * Channeled snare cast (3.0–5.0 seconds based on net tier) with live line-of-sight and range heartbeat.
  * Breaking range (>28 yd), losing target, or entering combat interrupts the channel.
  * Real-time radar gauge smoothly transforms into a channeled castbar with percentage progress.
* [x] **Capture Resolution minigame**:
  * Resolves: `Catch Rate = Net Power * Stalking Distance Bonus * Level Delta * Apex Rarity Resistance`.
  * Success adds companion DNA to collection while leaving the world mob completely unharmed and available.

---

## 📍 Phase 8: Turn-Based Battle Engine & PvP Sync (Completed ✅)
* [x] **Game Boy Retro 3D Battle Arena (`UI/BattleFrame.lua`, `Core/BattleEngine.lua`)**:
  * Classic battle stage with animated 3D models, health bars, retro dialogue box, and 2x2 command menu (FIGHT / BAG / TEAM / RUN).
  * 4 Core Stats (HP, ATK, DEF, SPD) and 9-element 150% closed-loop advantages.
  * Live combat Disobedience checks and victory attunement & family nourishment harvesting.
* [x] **Peer-to-Peer PvP Dueling (`Core/Comms.lua`)**:
  * Wireless turn-state synchronization over `ForeverSafariComm` for turn-based trainer duels across Azeroth.

---

## 📍 Phase 9: Physical Mailbox Hub & Journal Field Directives (Completed ✅)
* [x] **Safari Journal Field Directives (Tab 4 — `/safari` / `/safari bounties`)**:
  * Live field tracker for all Nesingwary research directives, target quotas, progress bars, and objective dossiers.
  * Allows players to check requirements anywhere in the wild while exploring.
* [x] **Blizzard MailFrame Custom Tab ("Safari") & Authentic Two-Window Architecture**:
  * Seamless custom tab docked directly to Blizzard's physical `MailFrame` (`MAIL_SHOW` / `MAIL_CLOSED`).
  * Full-width inbox column with mail items, sender names, subject titles, and dynamic status badges (`[ 📦 Unopened Parcel ]`, `[ ✔ Ready to Claim ]`, `[ ✉️ New ]`).
  * Secondary sidecar `OpenMail` window attached to `MailFrame` with custom gold/dark styling, scrollable parchment body, item tooltip previews, and one-click unbox/claim action buttons.
* [x] **First-Load Starter Companion Crate Unboxing**:
  * First-login parcel from Hemet Nesingwary delivering the racial starter companion crate and 5x Copper Safari Nets (0 free tokens).
* [x] **Official Nesingwary Field Bounties & Turn-Ins**:
  * Scrollable parchment letters distributing field research quests (Field Stalking 101, The Wild Nourishment, Apex Rares, Dungeon Catalysts).
  * Objective progress bars and physical turn-in requirements: players must return to a town mailbox to unbox parcels and collect their earned Safari Tokens and supplies.
* [x] **Outer Bezel Minimap Button Orbit**:
  * Shape-aware perimeter calculation supporting round, square, and modern WoW minimaps so the button stays docked on the outer bezel and never renders inside over the map texture.

---

## 📍 Phase 10: Gossip Store & Strict Vendor Specialization (Completed ✅)
* [x] **Zero Out-of-World Store Access**:
  * Shop opening from field commands, bags, and journals removed. Access is strictly gated through NPC gossip interaction.
* [x] **Pet Trainer Specialization (Safari Nets & Capture Gear — Universal Class Access)**:
  * Gossip Button: `[ 🐾 Browse Safari Nets & Gear ]`
  * Accessible to all classes (Hunters and non-hunters alike).
  * Offers Copper, Iron, Mithril Safari Nets, Arcanite Capsules, Revival Crystals, and Salves.
* [x] **Innkeeper Specialization (Safari Treats & Food Provisions)**:
  * Gossip Button: `[ 🍖 Browse Safari Treats & Food Provisions ]`
  * Offers Safari Treats, Grand Safari Feasts, Healing Salves, and harvested family meats.
* [x] **Instant Gossip Cleanup**:
  * Closing gossip immediately dismisses the merchant frame and clears vendor credentials.


