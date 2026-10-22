# 🗺️ Forever Safari — Master Development Roadmap
**Target Client:** World of Warcraft: Forever Beta (`_classic_beta_` / `dataEnv: 16` / `1.60.1`)  
**Target Engine:** Modern Retail WoW Engine (API 11.x/12.x)  
**Addon:** Forever Safari (`ForeverSafari`)  
**Organization:** Nesingwary Junior Safari League  

---

> [!IMPORTANT]
> ### 🚨 ACTIVE TOP PRIORITY: How We Get Our Creatures & Master Ingestion Architecture
> **The primary focus of development is strictly centered on [HOW_WE_GET_OUR_CREATURES.md](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/HOW_WE_GET_OUR_CREATURES.md).**  
> All ingestion scripts, zone censuses, and taxonomy compilers are gated behind resolving the 6 architectural holes identified in the master specification (Display IDs, Orphaned Beasts, Runtime Race Tagging, Channeled Observation, World Boss Drops, and Tinker Combobulation). **Zero code execution until architectural alignment is complete.**

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

## 📍 Phase 3: Anti-Tamper Vault & Minimal-State Persistence Engine (Completed ✅)
* [x] **Minimal Authoritative State (Zero-Stat-Trust Model)**:
  * Never persists mutable combat stats (`hp`, `atk`, `def`, `spd`) to disk; stores minimal seed tuples `{ speciesId, attunementPoints, anatomy, nickname, moves, isRare, ivSeed }`.
  * Evaluates the **100/110-Point Budget Law (Hamilton-Hare Algorithm)** dynamically at runtime upon load; impossible injected stats are ignored.
* [x] **Logically Atomic Dual-Generation Vault (`ForeverSafariVault`)**:
  * Dual-generation architecture (`active` and `backup`) with monotonic generation counter as the sole ordering authority.
  * Candidate snapshot verification before rotation: old active becomes backup only after candidate envelope successfully verifies.
  * Automated recovery from Alt+F4 crashes / save truncation, falling back safely to backup generation.
* [x] **Pure-Lua Cryptographic Vault Engine (`Core/Crypto.lua`)**:
  * Pure-Lua SHA-256 and HMAC-SHA256 (RFC 2104) with native WoW `bit` library acceleration.
  * Context-separated Key Derivation (KDF) deriving separate subkeys: `K_encrypt` (XXTEA) and `K_mac` (HMAC envelope).
  * Lightweight XXTEA 32-bit word block cipher + Base64 ASCII armoring for Blizzard SavedVariables compatibility.
  * Encrypt-then-MAC Authenticated Envelope binding: `IntegrityTag = HMAC(K_mac, schemaVersion || generation || playerGUID || payload)`. Detects accidental corruption, save truncation, and unauthorized edits by users who do not reproduce the addon’s integrity-generation logic.
* [x] **Debounced Dirty-Flag Pipeline & Zero-Plaintext Logout**:
  * Mutations flag dirty with 5.0-second idle debounce and 60-second hard ceiling.
  * Synchronous vault flush on `PLAYER_LOGOUT` / `/reload`; clears in-memory global `ForeverSafariDB = nil` before disk write so only the encrypted vault is persisted.
* [x] **Schema Migration & Benchmarking Suite**:
  * Static structural validation completed; in-game benchmarking suite (`/fs benchmark`) profiles JSON serialization, XXTEA encryption, HMAC-SHA256 hashing, and decryption across collection brackets.

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
  * **Rank I (Wild / Unbroken)**: 15% Disobedience chance, 1 Active Move, 0.85x Base Stats.
  * **Rank II (Tolerant)**: 10% Disobedience chance, 2 Active Moves, 0.95x Base Stats.
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
    * 🕸️ **Capture Gear**: Copper Snares, Iron Safari Nets, Mithril Hunter Traps, Thorium Expedition Cages.
    * 🥩 **Family Nourishment**: 17 wild harvested diets (Canine, Feline, Bear, Boar, Raptor, etc.) with favorite food attunement bonuses (+25 Attunement).
    * 🧬 **Evolution Catalysts**: Dungeon boss drops (Shadowfang Essence, Hydra Bile, Venomous Gland, Overclocked Core, Volcanic Core).
    * 🍖 **Consumables**: Treats (+50 Attunement), Feasts (+100 Attunement team-wide), Salves (100% Heal), and Revival Crystals.
  * **Context-Sensitive Actions**: Right-Clicking uses/equips items, feeds or heals active companion, or initiates Metamorphosis in the Field Guide. Shift-Clicking inserts item links into chat.
  * **Integration & Access**: Quick access buttons in Journal header, Minimap button middle/shift-click, Capture HUD, and `/fs bag` or `/fsbag` slash commands.

---

## 📍 Phase 7: Field Research Stalking & Observation Engine (Completed ✅)
* [x] **0% Mob Damage Decoupling (Field Research & Observation Architecture)**:
  * Eliminates mob HP whittling entirely. Live world quarry remains **100% untouched, un-tagged, and at full HP** in the game world.
  * Solves high-level one-shot accidents, tap theft, and hunter griefing over world rare spawns.
* [x] **Proximity & Stalking Radar (`Core/CaptureEngine.lua`, `UI/CaptureHUD.lua`)**:
  * **Close Stalk (~10 yards)**: High-risk proximity yielding **+25% Attunement & Move Discovery Bonus** (`1.25x`).
  * **Standard Perimeter (15–28 yards)**: Baseline observation perimeter (`1.0x`).
  * **Beyond Perimeter (>28 yards)**: Out of range; requires closing distance before channeling.
* [x] **Channeling Minigame & Observation Castbar**:
  * Channeled field study cast (3.0–5.0 seconds) with live line-of-sight and range heartbeat.
  * Breaking range (>28 yd), losing target, or entering combat interrupts observation.
  * Real-time radar gauge smoothly transforms into a channeled castbar with percentage progress.
* [x] **Field Study Resolution & Move Discovery**:
  * Studies target quarry from afar, unlocks species abilities for Trainer Grimoires, registers `[ 🔭 Seen ]` Bestiary sighting, and awards +15 Attunement.
  * Capturing creatures into your party/kennel takes place during turn-based combat (`/fsbattle` -> `[ BAG ] ➔ [ CAPTURE ]`).

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
* [x] **Safari Journal Field Directives (Tab 4 — `/fs` / `/fs bounties`)**:
  * Live field tracker for all Nesingwary research directives, target quotas, progress bars, and objective dossiers.
  * Allows players to check requirements anywhere in the wild while exploring.
* [x] **Blizzard MailFrame Custom Tab ("Safari") & Authentic Two-Window Architecture**:
  * Seamless custom tab docked directly to Blizzard's physical `MailFrame` (`MAIL_SHOW` / `MAIL_CLOSED`).
  * Full-width inbox column with mail items, sender names, subject titles, and dynamic status badges (`[ 📦 Unopened Parcel ]`, `[ ✔ Ready to Claim ]`, `[ ✉️ New ]`).
  * Secondary sidecar `OpenMail` window attached to `MailFrame` with custom gold/dark styling, scrollable parchment body, item tooltip previews, and one-click unbox/claim action buttons.
* [x] **First-Load Starter Companion Crate Unboxing**:
  * First-login parcel from Hemet Nesingwary delivering the racial starter companion crate and 10x Copper Snares (0 free tokens).
* [x] **Official Nesingwary Field Bounties & Turn-Ins**:
  * Scrollable parchment letters distributing field research quests (Field Stalking 101, The Wild Nourishment, Apex Rares, Dungeon Catalysts).
  * Objective progress bars and physical turn-in requirements: players must return to a town mailbox to unbox parcels and collect their earned Safari Tokens and supplies.
* [x] **Outer Bezel Minimap Button Orbit**:
  * Shape-aware perimeter calculation supporting round, square, and modern WoW minimaps so the button stays docked on the outer bezel and never renders inside over the map texture.

---

## 📍 Phase 10: Pet Trainer Safari Outfitter (Completed ✅)
* [x] **Zero Out-of-World Store Access**:
  * Shop opening from field commands, bags, and journals removed. Access is strictly gated through NPC gossip interaction.
* [x] **Pet Trainer Specialization (Full Outfitter Catalog — Universal Class Access)**:
  * Standalone Sidecar Window attached cleanly to `UIParent` (Zero Taint).
  * Accessible to all classes (Hunters and non-hunters alike).
  * Offers Copper Snares (1 Token), Iron Safari Nets (5 Tokens), Mithril Hunter Traps (10 Tokens), Thorium Expedition Cages (25 Tokens).
  * Offers 4 tiers of Transport Crates (1, 5, 10, 25 Tokens) with quality tinting.
  * Offers Safari Treats, Grand Safari Feasts, harvested family nourishment diets, Healing Salves, and Revival Crystals.
* [x] **Interactive Rest & Tend Squad Button**:
  * `[ 💖 Tend & Revive Squad ]` button heals and revives companions when talking to pet trainers.
* [x] **Instant Gossip Cleanup**:
  * Closing NPC interaction immediately dismisses the merchant frame.

---

## 📍 Phase 11: In-Battle Captures & 4-Tier Transport Crates (Completed ✅)
* [x] **In-Battle Capture Flow (`Core/BattleEngine.lua`, `UI/BattleFrame.lua`, `Core/BattleCapture.lua`)**:
  * Thrown during turn-based combat via `[ BAG ] ➔ [ CAPTURE ]` submenu.
  * Turn ends smoothly upon throwing capture gear, advancing to opponent's turn on failure via speed-lapping turn order.
* [x] **Master Capture Formula & 4-Tier Snare Scaling**:
  * **4 Trap Tiers & 15-Level Brackets**: Copper Snare (Lv 1–15, 35%), Iron Safari Net (Lv 16–30, 55%), Mithril Hunter Trap (Lv 31–45, 75%), Thorium Expedition Cage (Lv 46–60, 98%).
  * **50% HP Pivot Dynamic**:
    * **Above 50% HP (Penalty)**: $1:1$ penalty ($-1\%$ capture chance per $1\%$ HP above 50%). Mathematically prevents full-health cheese (Copper Snare at 100% HP suffers $35\% - 50\% = -15\% \le 0\%$).
    * **Below 50% HP (Bonus)**: $2:1$ bonus ($+1\%$ capture chance per $2\%$ HP below 50%). Lowering quarry to 10% HP grants $+20\%$ catch bonus.
    * **At 50% HP**: Operates at exact baseline trap rate.
  * **Tier Mismatch Scaling**:
    * Over-geared (Higher tier trap on lower bracket quarry): **+25% flat catch bonus per tier down**.
    * Under-geared (Lower tier trap on higher bracket quarry): **Halves catch chance per tier up** ($\times 0.5$ per tier difference).
  * **Wild Rare Quarry Resistance**: Flat **-10% capture rate penalty** on all wild Rare spawns.
* [x] **Hunter Beastmastery Mastery (`Aspect of the Beastmaster`)**:
  * **+25% Multiplicative Capture Multiplier** (`1.25x`) on all wild capture attempts.
  * **+25% Multiplicative Attunement Accrual** (`1.25x`) from all combat victories, nursery tasks, and training.
* [x] **Active Squad (4 max) & Transport Crate Logistics**:
  * Players carry up to 4 active battle companions in their field party.
  * When active squad is full (4/4), in-battle capture requires and auto-consumes 1 matching or higher tier Transport Crate (`INV_Box_PetCarrier_01` tinted by quality) to safely crate and ship the wild specimen to the Safari Kennel.
  * If squad is not full (< 4), companion joins active squad directly with no crate consumed.
* [x] **Token Pricing Economy**:
  * Tier 1 (Common): 1 Token (Copper Snare / Copper Transport Crate).
  * Tier 2 (Uncommon): 5 Tokens (Iron Safari Net / Iron Transport Crate).
  * Tier 3 (Rare): 10 Tokens (Mithril Hunter Trap / Mithril Transport Crate).
  * Tier 4 (Epic): 25 Tokens (Thorium Expedition Cage / Thorium Transport Crate).

---

## 📍 Phase 12: Moonglade Cenarion Nursery & Sacred Genetic Breeding (Completed ✅)
* [x] **Social Co-Op Breeding Sanctuary (`UI/NurseryFrame.lua`)**:
  * Ritual breeding program stationed at Cenarion Keepers in Moonglade (and Capital City pet trainers).
  * Requires two Rank V (Bestial Symbiosis) companions of the exact same family: one Sire (♂) and one Dam (♀).
  * Peer-to-peer comms synchronization (`Core/Comms.lua`) for cross-player breeding handshakes and readiness verification.
* [x] **The Asymmetry Rule (50/50 Biological Sex Seed)**:
  * Persistent character-bound 50/50 seed per species permanently designates either Male (♂) or Female (♀) across all encounters, preventing solitary alt-farming and guaranteeing social collaboration.
  * Cryptographic HMAC signing of biological sex (`Core/Crypto.lua`) with colored gender badges (`|cff66ccff♂ Male (Sire)|r` / `|cffff99cc♀ Female (Dam)|r`).
* [x] **The Highlander Rule & The Ultimate Sacrifice**:
  * Unique ownership law: max 1 active instance per creature species.
  * Parents are permanently sacrificed to the sacred grove upon completing the ritual, producing guaranteed purebred Safari Eggs (with a 20% bonus 3rd egg roll).
* [x] **Attunement Rank Inheritance & Rare Genetic Mutation**:
  * Moonglade Sacred Grove hatches offspring at **Rank III: Trusting** (capital cities hatch at Rank I).
  * Roll for Rare offspring with 110 base stat budget and elite status.

---

## 📍 Phase 13: Authentic Azeroth Bestiary & Field Pokédex (Completed ✅)
* [x] **Dynamic 2,006-Species Pokédex (2,008 World Creatures) (`Data/BestiaryDB.lua`, `UI/Views/JournalBestiaryView.lua`)**:
  * Complete coverage across all 9 pet types: Beasts, Canines, Felines, Bears, Boars, Raptors, Avians, Bats, Crocolisks, Crabs, Turtles, Spiders, Scorpids, Hydras, Wind Serpents, Gorillas, Kodos, Tallstriders, Dragon Whelps, **Mechanicals (Harvest Reapers, Mech-Chickens, War Golems, Alarm-o-Bots)**, **Undead (Skeletal Raptors, Plaguebats, Ghostly Crabs, Bone Golems)**, and **Elementals (Blazing Elementals, Tide Walkers, Rock Rumblers, Tar Beasts, Dust Devils)**.
  * 2,006 unique species database (2,008 world creature entities) with verified 3D display IDs for 100% accurate paperdoll rendering.
  * High-performance 60 FPS virtual scrolling list with multi-mode sorting (Name, ID, Rank, Family).
  * Native regional habitats, favorite sustenance diets, base stats, and natural 4-move thematic movepools.
* [x] **Dedicated 30-Family Beast Subfamily Filtering**:
  * Secondary dropdown filter for distinct beast subfamilies (Kodos, Tallstriders, Thunder Lizards, Saurians, etc.).
* [x] **"Current Zone Only" Localized Tracking**:
  * Real-time zone detection checkbox filtering the Pokédex to the player's current map with localized completion progress counters.
* [x] **3-Tier Pokédex Discovery Lifecycle (`Core/Database.lua`)**:
  * `[ ??? Undiscovered ]` ➔ `[ 🔭 Seen / Sighted ]` (stalked via `/fs observe` or encountered in combat) ➔ `[ 🐾 Captured ]` (caged into active squad or kennel).
  * Pokédex completion progress bar with live seen/caught percentage counters.
* [x] **Dynamic Type & Family Filter Dropdown (`UI/JournalFrame.lua`)**:
  * Dropdown selector supporting instant 1-click filtering by *All Types, Beast, Mechanical, Undead, Elemental, Dragonkin, Aquatic, Flying, Magic*, stacked with real-time text searching.

---

## 📍 Phase 14: Architecture Modular Breakdown & 3D Showcase Overhaul (Completed ✅)
* [x] **3D Showcase Stage Overhaul & Visual Polish**:
  * **Next-Gen 3D Paperdoll Stage**: Dynamic pedestal lighting, ambient stage floor, smooth mouse rotation physics, responsive zoom, and animation controls (Attack, Roar, Idle, Fidget).
  * **Interactive Stat Radar & Combat Aptitudes**: Visual breakdown of HP, Attack, Defense, and Speed with type advantage indicators.
  * **Active Moveset & Nourishment Bar**: Direct feeding tray (+25 Attunement favorite diet bonus, +15 accepted diet bonus) and intuitive move teaching drawer.
* [x] **`UI/JournalFrame.lua` Sub-View Modularization**:
  * Extracted monolithic journal into focused, decoupled view files:
    * `UI/JournalFrame.lua` — Main window frame shell, top navigation tabs, header, footer.
    * `UI/Views/JournalRosterView.lua` — View 1 (3D Showcase Stage & Details Panel).
    * `UI/Views/JournalGridView.lua` — View 2 (3D Menagerie Gallery Grid).
    * `UI/Views/JournalBestiaryView.lua` — View 3 (Azeroth Field Pokédex & Dossier).
    * `UI/Views/JournalBountiesView.lua` — View 4 (Field Directives & Research Quest Log).
    * `UI/Components/JournalTeamDock.lua` — Bottom 4-member active battle squad dock.
    * `UI/Components/JournalTrainingDrawer.lua` — Move learning & grimoire teaching drawer.
* [x] **`Core/Database.lua` Domain Modularization**:
  * Partitioned DB operations into domain-specific modules:
    * `Core/Database.lua` — Core initialization, SavedVariables migration, schema upgrades, starter kit.
    * `Core/DB/DB_Pets.lua` — Pet collection CRUD, active party, level/XP, moves, feeding logic.
    * `Core/DB/DB_Kennel.lua` — Storage boxes (1–101, 2,006 total slots), crate transfer logic, kennel slots.
    * `Core/DB/DB_Bestiary.lua` — Pokédex discovery tracking, stats, and collection backfill.
    * `Core/DB/DB_Inventory.lua` — Safari Bag items, tokens, and consumables.
* [x] **Canonical Data Consolidation (`Data/MoveDB.lua` & `Data/ItemDB.lua`)**:
  * Unified move definitions into `Data/MoveDB.lua` as the single canonical source of truth with 94 moves and signatures.
  * Extracted all shop, cage, crate, net, treat, diet, and medicine definitions into `Data/ItemDB.lua`.
  * Cleaned `Core/Constants.lua` to focus on core branding, element matrix, and attunement rank thresholds.
* [x] **`Core/StatEngine.lua` Centralization**:
  * Centralized all stat calculations, 100/110 budget enforcement, attunement multipliers, and HP recovery.

---

## 📍 Phase 15: NPC Rival Battler Engine & Humanoid AI Trainers (Completed ✅)
* [x] **Roaming Humanoid AI Trainers**:
  * Targeting and challenging humanoid mobs across Azeroth (e.g. Defias, Kobolds, Murlocs, Gnolls, Centaurs, Scarlet Crusaders, Dark Iron Dwarves, Syndicate, Pirates, Bloodscalps, Ogres, Venture Co., Twilight Cultists, Nesingwary Trackers) initiates an **AI Trainer Battle**.
* [x] **14 Themed Faction Archetypes (`Data/TrainerDB.lua`, `Core/TrainerEngine.lua`)**:
  * Dynamic level scaling (1 pet for Lv 1–15, 2 pets for Lv 16–35, 3 pets for Lv 36+).
  * Faction titles, contextual intro quotes, and defeat quotes.
  * In-battle AI pet switching when a trainer's active companion faints.
* [x] **Trainer Pet Capture Protection**:
  * Traps and snares cannot be thrown at trainer-owned pets (`"You cannot capture another hunter's companion!"`).
* [x] **Token Economy Restructure**:
  * Safari tokens are awarded exclusively through defeating Humanoid AI Trainers (6–18+ tokens based on level and faction) and completing official mailbox bounties.
  * Wild random creature battles yield nourishment drops and attunement, but no tokens.

---

## 📍 Phase 16: 11-Item Safari Diet & Anti-Cannibalism System (Completed ✅)
* [x] **11 Canonical Safari Diets (`Data/ItemDB.lua`)**:
  * **Natural Diets**: Safari Meat (Carnivores), Safari Fish (Aquatic/Shore hunters), Safari Bread (Herbivores/Grazers), Safari Cheese (Omnivores/Rodents), Safari Fruit (Avians, Bats, Primates), Safari Fungus (Cave & Swamp scavengers).
  * **Special Diets**: Safari Parts (Mechanicals), Safari Bonedust (Undead), Safari Shards (Magic), Safari Crystals (Elementals), Safari Runes (Dragonkin).
* [x] **Universal Diet Evaluation Matrix (`FAMILY_DIETS` & `CanEatFood`)**:
  * **Favorite Food**: +25 Attunement & joyful roar/model animation.
  * **Accepted Food**: +15 Attunement & eating animation.
  * **Incompatible Food**: Companion refuses to eat, dialogue feedback, 0 items consumed.
* [x] **Interactive Feeding Tray & Bag Integration**:
  * Live feeding buttons with real-time inventory count badges on the 3D Spotlight stage.
  * Right-click feeding from the 20-slot Virtual Safari Bag.

---

## 📍 Phase 17: Starter Companion Rank III Trusting Initialization (Completed ✅)
* [x] **Partner Status Initialization**:
  * Racial starter companions provided by Hemet Nesingwary initialize at **Rank III: Trusting** (600 Attunement Points) with full **1.00x True Baseline Stats (100/100 points)**, **5% Disobedience**, and **Slot 3 Unlocked for Training**.
* [x] **Legacy Starter Auto-Promotion (`DB:ValidateAndRepairSignatures`)**:
  * Existing player profiles with starter companions at 0 attunement are automatically promoted to Rank III with signed cryptographic integrity.
* [x] **Wild Catch Differentiation**:
  * Wild creatures caught in snares/cages start at **Rank I: Wild / Unbroken** (0 Attunement, 0.85x stats, 15% disobedience), maintaining clear progression and domestic bonding loops.

---

## 📍 Phase 18: Real Quest Token Grants & Retroactive Back-Quest Compensation (Completed ✅)
* [x] **Real Quest Turn-In Integration (`QUEST_TURNED_IN`)**:
  * Turning in quests across Azeroth awards Safari Tokens scaled dynamically by player level (+5 Tokens for Lv 1–19, +7 Tokens for Lv 20–39, +10 Tokens for Lv 40+).
  * Awards **+20 Attunement Points** to the active squad companion per completed quest.
* [x] **Retroactive Back-Quest Compensation (`C_QuestLog.GetAllCompletedQuestIDs`)**:
  * Onboarding grant for existing characters automatically calculates all previously completed quests and awards a lump-sum Safari Research Grant upon first installation.
* [x] **Double-Dip Prevention (`SafariCharacterDB.rewardedQuests`)**:
  * Persistent quest registry in SavedVariables ensures each quest ID in Azeroth is rewarded exactly once per character.
* [x] **Dungeon Boss Research Permits**:
  * Defeating key dungeon bosses (Sneed's Shredder in Deadmines, Viscous Fallout in Gnomeregan, Amnennar in RFD, Avatar of Hakkar in Sunken Temple) synchronizes Mechanical, Elemental, Undead, and Dragonkin research permits across all party members.

---

## 📍 Phase 19: Zero-Taint & Secret Value Resilience for Dungeons / Combat (Completed ✅)
* [x] **Universal `pcall`-Guarded Secret Value Detector**:
  * Standardized `isSecret(v)` implementation supporting `issecretvalue()`, `issecretpassphrase()`, `issecretvariable()`, `C_Secrets.IsSecret()`, and `pcall(function() local _ = (v == "") end)` comparison probing across all 38 Lua modules.
* [x] **Dungeon / Instance Anti-Automation Immune**:
  * Fortified `UnitCreatureType()`, `UnitClassification()`, `UnitReaction()`, `UnitLevel()`, `UnitName()`, and `GetZoneText()` against tainted secret string equality comparisons during dungeon/instance encounters.
* [x] **Zero UI Taint in Combat & Raids**:
  * Standalone sidecar windows, secure-safe frame hooks, and isolated namespace execution ensure zero Lua errors and zero tainted action blocks.

---

## 📍 Phase 20: Junior Safari League NPC Gossip, Bank Reserve & Ecliptic Tides (Completed ✅)
* [x] **Junior Safari League NPC Gossip Menu Integration (`Core/SafariGossip.lua`)**:
  * Clean, opt-in client-side integration with Blizzard's native `GossipFrame.GreetingPanel`.
  * **Pet Trainers**: `Junior Safari League: Challenge Outpost Leader` and `Junior Safari League: Visit Outfitter`.
  * **Innkeepers**: `Junior Safari League: Rest and Revive Squad` (100% squad HP restoration and fainted pet revival).
  * **Cenarion Keepers (Moonglade)**: `Junior Safari League: Breed My Pet` (Nursery interface).
  * **Non-Service NPCs**: Generic NPCs remain silent and never trigger addon popups or HUD elements.
* [x] **Universal Addon Row Stacking Engine**:
  * Dynamically scans visible button children on `GreetingPanel` to identify external third-party modifications (such as Olympus's `Bones!: Teach me Bones` or Questie).
  * Evaluates screen bottom coordinates (`child:GetBottom()`) and anchors Forever Safari's rows beneath the lowest external button, guaranteed to sit lowest on screen with zero hardcoded strings.
  * Dual-pass execution (Frame 0 immediate render + Frame 2 re-anchor) to cleanly handle event loop timings across different addons.
* [x] **Junior Safari Reserve Bank Tab (`UI/KennelFrame.lua`)**:
  * Replaced intrusive auto-open behavior with an integrated **Junior Safari Reserve** tab mounted on Blizzard's `BankFrame`.
  * Expanded vault capacity to **2,006 slots across 101 enclosures** — providing exactly 1 slot for every unique species in Azeroth under the **Highlander Law**.
  * Multi-template discovery (`PanelTabButtonTemplate`, `CharacterFrameTabButtonTemplate`, `UIPanelButtonTemplate`, and fallback) to support both legacy and modern `PortraitFrameTemplate` BankFrame architectures without Lua errors.
  * Features Shift-click $\pm 10$ enclosure skipping, a scrollable Jump menu with direct numeric entry, and real-time Journal search and filtering.
  * Toggles the companion vault docked alongside `BankFrame` and cleans up automatically on `BANKFRAME_CLOSED`.
* [x] **Druid Class Passive: Ecliptic Tides & 4-Role Ability Taxonomy**:
  * **Ecliptic Tides**: In-combat celestial pendulum tracking Solar vs. Lunar power up to companion Attunement Rank (1-5).
  * 5% per point surge check per turn with automatic 100% discharge at full meter capacity (Solar cleanses a debuff and grants a HoT; Lunar applies a Brambles Nature damage shield).
  * Standardized all 94 abilities across a 4-role taxonomy: Offensive (63 moves, builds Solar), Defensive (8 moves, builds Lunar), Field Hazard (11 moves, builds Lunar), and Weather (12 moves, builds Lunar).

---

## 📍 Phase 21: Combat Engine Architecture, Zero-Drift Stats & Taint Fortification (Completed ✅)
* [x] **Combat Engine Canon & Mechanics SSOT (`Docs/COMBAT_ENGINE_STATS_AND_MECHANICS.md`)**:
  * Unified all combat rules, stat algorithms, action-gauge speed lapping, 5-layer elemental resistances, and player class passives into a single authoritative canon.
* [x] **Zero-Drift Proportional Base Stat Algorithm**:
  * Formulated the Largest Remainder Method (Hamilton-Hare) guaranteeing exact, drift-free distribution to target budgets ($T = 100$ for Normal/Elite/Boss; $T = 110$ for Rare/Rare Elite).
  * Strict classification gating: Dungeon and raid bosses (`classification == 3`) strictly adhere to $T = 100$; wild rare spawns (`classification in (2, 4)`) receive $T = 110$.
* [x] **Layer 5 Defense Architecture (Static Slices vs. Procced Wards)**:
  * **Static Slices**: Warrior (Physical Armor, +5%/rank), Rogue (Dodge Evasion, +5%/rank synergizing with Cunning), Hunter (Nature Resist, +5%/rank), and Druid (Omni-Resist across all 6 magic schools, +2%/rank).
  * **Procced Wards**: Mage, Shaman, Warlock, Priest, and Paladin (Proc chance $5\% \times \text{Rank}$, Mitigation $5\% \times \text{Rank}$). Evaluated independently per direct strike and **independently rolled on every single DoT tick**.
  * **Mage Chilling Tempo & Frost Counterplay**: 5% off / 10% def chill proc (-50% SPD) proportionally reduced by target Frost Resistance % ($\text{Base} \times (1 - \text{Resist}/100)$).
  * **Druid Ecliptic Tides**: Role-driven Solar/Lunar pendulum with early proc rolls ($5\% \times \text{pts}$) and automatic 100% discharge at cap.
* [x] **Taint Purge & Diagnostic Watcher (`Core/TaintWatcher.lua`)**:
  * Purged obsolete `Core/InstancePupDrops.lua` CLEU event registration, resolving all Blizzard UI tainted action errors.
  * Added `Core/TaintWatcher.lua` (loaded first in TOC) and `/fstaint` diagnostics; verified 100% clean startup and interaction.
* [x] **Pipeline Tooling & Creature Regeneration (`Tools/build_creatures.py`)**:
  * Updated `calculate_stats()` to execute the Largest Remainder (Hamilton-Hare) zero-drift algorithm and regenerated all creature partitions in `Data/Creatures/` (2,008 creatures verified with zero drift).
* [x] **Combat Engine Execution (`Core/BattleEngine.lua` & `Core/StatEngine.lua`)**:
  * Implemented Action-Gauge 0–100 speed velocity and lapping queue (authentic 2:1 speed scarcity).
  * Implemented dynamic Layer 1–5 resistance derivation, dodge/deflection avoidance, Ferocity damage bonus, and procced ward evaluation (with independent per-tick DoT rolls).
  * Implemented Druid Ecliptic Tides pendulum and Priest Divine Grace battle frame tray integration.

---

## 📍 Phase 22: Beast Taxonomy Refinement & Elemental Saurians (Completed ✅)
* [x] **Discrete Beast Family Stratification (Zero Shims & Zero Aliases)**:
  * Formalized **Kodos** and **Tallstriders** as strictly decoupled, distinct families within the Beast genus across all database tables, dietary rules, and family movepools.
  * Established **Thunder Lizards** (`Thunder Lizard`) as their own dedicated saurian partition (`Data/Creatures/Beasts/Creatures_Beasts_ThunderLizard.lua`) with favorite `food_crystals` lodestone diet and canonical grimoire.
* [x] **Elemental License Gating for Thunder Lizards**:
  * Thunder Lizards harness primal nature and lightning fury. While taxonomically classified under the Beast genus, **capturing Thunder Lizards in the wild is strictly gated behind the Elemental Research Permit / License** (earned by defeating *Viscous Fallout* in Gnomeregan or *Baron Aquanis* in BFD).
* [x] **Kalimdor Saurian Species Roster**:
  * Added canonical Barrens and Desolace species (*Thunder Lizard*, *Lightning Hide*, *Stormsnout*, *Stormhide*, and rare apex *Thunderhead*) to both `Data/CreatureDB.lua` and `Data/BestiaryDB.lua` with verified 3D display IDs, 100/110 base stat distributions, and thematic lightning movepools (*Shock Blast*, *Static Charge*, *Tail Sweep*, *Storm Surge*).
* [x] **Spawn-Instance GUID Anti-Farm Lockouts (`UnitGUID`)**:
  * Track individual world spawn instances via `UnitGUID("target")` to eliminate duplicate engagements on the same living NPC.
  * **Observation / Scanning Lockout**: Successfully completing a field observation channel (`/fs observe`) marks the entity's GUID in `ForeverSafariDB.scannedGuids`, preventing redundant channels against that same wild specimen for 24 hours.
  * **Roaming AI Trainer Lockout**: Defeating a humanoid NPC in turn-based combat records their spawn GUID in `ForeverSafariDB.defeatedTrainers`, preventing players from repeatedly battling the same living humanoid for infinite Safari Tokens.
  * **Automated Expiration & Pruning (`DB:PruneExpiredGuids`)**: Automatic daily / 24-hour timestamp pruning on login to prevent SavedVariables bloat while allowing respawned world encounters.

---

## 📍 Phase 23: Virtual Duo Outposts, Party Scaling & Pre-Battle Squad Designation (Completed ✅)
* [x] **Virtual Duo Encounter Architecture (The Cenarion Twins)**:
  * Implemented flagship Virtual Duo encounter at Cenarion Hold in Silithus (**Jarund Stoutstrider & Layo Starstrike**) commanding an 8-companion joint roster.
  * Every companion strictly conforms to the **100-Point Budget Law** with verified Blizzard creature templates and DBC display IDs.
* [x] **Disparity Compounding Party Scaling**:
  * Scaling multiplier calculated from group disparity: $\Delta = \max(0, \text{Players} - \text{NPCs})$.
  * For 2-NPC Virtual Duos: $\Delta = 0$ (1–2 players) = $1.0000\times$; $\Delta = 1$ (3 players) = $\mathbf{1.2500\times}$; $\Delta = 2$ (4 players) = $\mathbf{1.3750\times}$; $\Delta = 3$ (5 players, Duo Cap) = $\mathbf{1.4438\times}$ Max HP and direct damage.
* [x] **Sympathetic Buffing, 50% Sympathetic Healing & Cycle-Based Ticking**:
  * **Sympathetic Buffing**: Beneficial buffs, shields (*Barkskin Aegis*, *Static Jolt*, *Thick Hide*), and HoTs (*Solar Bloom*) cast by either Twin replicate across both active companions of the Twins.
  * **50% Sympathetic Healing**: When either companion heals through primary or secondary effects (direct heals, Leech/Drain Life, regeneration HoTs), 50% of the healed amount is sympathetically restored to the other active Twin companion.
  * Shared defensive buffs decrement only once every 2 enemy turns (`duoTurnCounter % 2 == 0`) so fast companions do not prematurely burn through defensive barriers.
* [x] **Dual-Line Druid Ecliptic Meter**:
  * Single HUD displaying Jarund's Solar energy (☀️) and Layo's Lunar energy (🌙). At 5 charges, unleashes *Solar Bloom* (+12% Max HP squad HoT) or *Lunar Brambles* (40% thorns reflection). Both can be active concurrently.
  * Enemy status HUD dynamically resizes to 76px to display dual tracking lines with round countdowns.
* [x] **Pre-Battle Pet Designation & Squad Quota Lockout**:
  * Interactive checkboxes on `ForeverSafariPlayerParty` allow players to designate which companions enter combat before the battle starts.
  * Squad capacity quotas: 4–5 players = 2 pets; 3 players = 3 pets; 1–2 players = 4 pets.
  * Checkboxes permanently lock on turn 1 (`combatStarted = true`); benched companions cannot enter combat or be swapped in.
* [x] **15-Second Action Timeout**:
  * Real-time 15-second countdown ticker with animated color-lerping progress bar (`GREEN` $\to$ `YELLOW` $\to$ `RED`) above the dialogue console.
  * Automatically fires Move 1 if the timer expires without player input to keep combat fluid.
* [x] **Boss AoE Cleave Mechanics**:
  * Primary target takes full damage; collateral cleave strikes all conscious reserve party companions for 50% base power, mitigated through each pet's individual Defense and resistance layers.

---

## 📍 Phase 24: Safari Outpost Guide League, Argent Quartermaster & Spirit Healer Raid Boss (Completed ✅)
* [x] **55-Guide Regional Safari Circuit (`Data/OutpostDB.lua`)**:
  * Mapped 55 authentic World of Warcraft Stable Masters into a 5-Tier regional circuit across Azeroth:
    * Tier 1 (Racial Homelands): 1 pet @ Rank I attunement
    * Tier 2 (Provincial Outposts): 2 pets @ Rank II attunement
    * Tier 3 (Capital Grandmasters): 3 pets @ Rank III attunement
    * Tier 4 (Goblin Cartels): 4 pets @ Rank IV attunement
    * Tier 5 (Neutral Orders): 4 pets @ Rank V attunement
  * Strict tier progression gating (`OutpostDB:CanChallengeGuide`): Requires 10 same-tier roaming trainer victories and full lower-tier clears before challenging a Guide.
* [x] **Stable Master Target HUD & Dialogue Integration (`UI/CaptureHUD.lua`, `Core/SafariGossip.lua`)**:
  * Targeting any registered Stable Master renders a live badge/challenge HUD with direct combat initiation.
  * Contextual intro and defeat quotes tailored to each regional outpost location.
* [x] **Tier 5 Raid Encounter — Argent Quartermaster (Light's Hope Chapel)**:
  * Flagship Tier 5 Paladin Guide stationed at Light's Hope Chapel in Eastern Plaguelands (NPC 16786).
  * Commands a purified Western Plaguelands roster (Purified Wolf, Purified Grizzly, Purified Hound) anchored by the Spirit Healer (NPC 6491).
* [x] **Spirit Healer Boss Mechanics & Divine Pendulum**:
  * Holy Sephiroth ability kit: *Penance of the Dawn*, *Hammer of Wrath*, *Power Word: Sanctuary*, and *Final Judgment*.
  * *Divine Pendulum* innate passive providing dynamic offensive/defensive state switching.
  * Phase 3 Boss Enrage: Turn 5 *Mass Resurrection* (restoring all fallen companions at 50% HP with -25% Resurrection Sickness), tactical pet swapping, and +5% HP/turn bench healing.

---

## 📍 Phase 25: Research Licenses, Progressive Directives & Badge Cabinet (Completed ✅)
* [x] **Dungeon Boss Specimen Quest Drops (`Core/QuestHooks.lua`, `Data/ItemDB.lua`)**:
  * Dungeon bosses drop authentic virtual quest items directly into `/fsbag` instead of instant auto-unlocking creature families:
    * ⚙️ **Grinded Gears** (`quest_grinded_gears`) from Crowd Pummeler 9-60 in Gnomeregan (Mechanical).
    * 🌋 **Puddle of Mud** (`quest_puddle_mud`) from Lord Incendius in Blackrock Depths (Elemental).
    * 💀 **Cold Bones** (`quest_cold_bones`) from Baron Rivendare in Stratholme (Undead).
    * 🐉 **Poisonous Scales** (`quest_poisonous_scales`) from Shade of Eranikus in Sunken Temple (Dragonkin).
  * Slaying these dungeon bosses triggers fanfare celebration toasts, sound alerts, and raid team comms.
* [x] **Town Mailbox Specimen Exchange & License Certification (`UI/SafariMailFrame.lua`)**:
  * Implemented an interactive turn-in exchange on the town mailbox `[Safari]` tab: **`[ 📦 DISPATCH SPECIMEN & CLAIM LICENSE ]`**.
  * Players transport the specimen to any physical town mailbox, consume the virtual item from `/fsbag`, and dispatch it to Hemet Nesingwary.
  * Hemet returns an official certified Research Permit, unlocks stalking/capture for that creature family (`DB:UnlockType`), and grants **50 Safari Tokens** plus field supplies.
  * Added `DB:ClaimQuestReward` in `Core/Database.lua` to record claims and manage reward payouts.
* [x] **Progressive Dispatch Gating (`Data/BountyDB.lua`)**:
  * Implemented `BountyDB:IsDispatchUnlocked(id)` and `BountyDB:GetUnlockedDispatches()`.
  * New recruits are presented with only **Dispatch #1** (*Welcome to the Safari League!*) and **Dispatch #2** (*Field Observation 101*).
  * Subsequent directives (#3 *The Wild Nourishment*, #4 *Sighting of Apex Rares*, #5 *Deep Dungeon Expedition*, and creature license directives) unlock sequentially upon claiming prior directives or obtaining the required specimen.
  * Synchronized across both the town mailbox `[Safari]` tab and the Journal's **`[DIRECTIVES]`** view (`JournalBountiesView.lua`).
* [x] **Journal Badges & Credentials Cabinet (`UI/Views/JournalBadgesView.lua`, `UI/JournalFrame.lua`)**:
  * Added Tab 5 **`[BADGES]`** ("Badges & Licenses") to the Safari Journal header.
  * **Top Shelf (Research Permits)**: 4 large ornate credential plaques for *Clockwork Engineering*, *Primal Attunement*, *Necrotic Containment*, and *Draconic Sanctuary* with locked darkened brass vs. certified gold styling.
  * **Velvet Trophy Grid (Regional Badges)**: 4-column scrollable showcase displaying all **54 Regional Outpost Badges** from `Data/OutpostDB.lua`. Unearned badges render dark metallic silhouettes with zone and leader challenge details; earned badges display full-color icons, victory timestamps, and the leader's authentic defeat quote.
  * **Progress Tracker**: Header counter tracks total badges collected (e.g. `Badges Collected: 12 / 54 (22%)`).
  * Registered in `ForeverSafari.toc` load sequence.

---

## 📍 Phase 26: Release v1.0.2 Critical Bug Fixes & Architecture Fortification (Completed ✅)
* [x] **Combat Engine & UI Stability (`UI/BattleFrame.lua`)**:
  * Resolved runtime crash on battle turn start by replacing obsolete `:IsAtBottom()` with canonical modern Retail ScrollingMessageFrame method `:AtBottom()`.
* [x] **SavedVariables Session Persistence (`ForeverSafari.lua`)**:
  * Purged destructive `ForeverSafariDB = nil` on `PLAYER_LOGOUT`, guaranteeing full persistence of unboxed companions, catches, and inventories across client reloads and logouts.
* [x] **3D Paperdoll Model Framing & Camera Lock Purge**:
  * Stripped hardcoded `SetCustomCamera(0)` and `SetPortraitZoom(0)` across `UI/BattleFrame.lua`, `UI/JournalFrame.lua`, `UI/InspectorFrame.lua`, and `UI/Views/JournalRosterView.lua`.
  * Fully migrated to Retail engine bounding-box perspective rendering via `:SetDisplayInfo(displayId)` with clean diagonal arena facing angles (`math.rad(45)` player, `math.rad(-35)` enemy).
  * Unified Journal Spotlight rotation controls using `:SetRotation()`.
* [x] **Field Directive Observation Enforcement (`Data/BountyDB.lua`, `Core/CaptureEngine.lua`)**:
  * Reverted Dispatch #2 (*Field Observation 101*) strictly to non-invasive field study (`OBSERVE`), removing all capture requirements.
  * Wired field binoculars/lens channel completion directly to `DB:UpdateQuestProgress("OBSERVE", 1)`.
  * Verified town mailbox turn-in and reward claim pipeline.
* [x] **Truth.md Governance & Zero Off-Roading Mandate**:
  * Enshrined Section 2 in `Truth.md` enforcing zero unapproved design alterations, strict adherence to developer specifications, and modern Retail engine API standards.

---

## 📍 Immediate Priorities: v1.0.4 Integrity & Hotfix Patch (Completed ✅)
* [x] **Eliminate Prohibited Model APIs (`UI/KennelFrame.lua`)**:
  * Purged remaining `model:SetPortraitZoom(0.85)` call from `KennelFrame.lua:191`, added `model:EnableMouse(false)`, and enforced complete adherence to `Truth.md` Section 8 camera invariants.
* [x] **Fix NPC Gossip Shop Access (`Core/SafariGossip.lua`)**:
  * Corrected namespace binding in Pet Trainer gossip dialogue from `ns.Shop` to `ns.ShopFrame`, restoring player access to the Nesingwary Safari Outfitter.
* [x] **Reconcile Transport Crate Keys & Empty Shop Category (`UI/ShopFrame.lua`, `Data/BountyDB.lua`, `Core/BattleCapture.lua`, `Data/ItemDB.lua`)**:
  * Unified crate keys across the shop, dispatches, and capture handlers to `copper_crate`, `iron_crate`, `mithril_crate`, `thorium_crate`, repopulating the Shop Crates tab and adding alias compatibility in `ItemDB.lua`.
* [x] **Reconcile Safari Treats & Feasts (`Data/ItemDB.lua`, `Core/BattleEngine.lua`, `UI/BattleFrame.lua`, `UI/SafariBagFrame.lua`)**:
  * Added aliases for `az_treat` and `az_feast` in `ItemDB.lua` to fix blank battle bag buttons and untextured bag items.
* [x] **Implement Missing Toast Notification Methods (`UI/Toast.lua`)**:
  * Added definitions for `ShowTokenGain`, `ShowItemGain`, `ShowBestiaryDiscovery`, `ShowAttunementUp`, `ShowMoveLearned`, and `ShowPermitUnlocked` to restore visual celebration popups.
* [x] **Re-link Journal Frame UI Updaters (`Core/DB/DB_Pets.lua`)**:
  * Rerouted calls from nonexistent `ns.JournalTeamDock` and `ns.JournalRosterView` directly to `ns.JournalFrame:UpdateUI()`.
* [x] **Restore Multiplayer Catalyst Loot Rolling (`UI/CatalystLootFrame.lua`, `Core/Comms.lua`)**:
  * Fixed message dispatch to use `Comms:SendMessage("CATALYST_ROLL", ...)` and added `CATALYST_ROLL` receiver router in `Comms:OnMessageReceived`.
* [x] **Restore Bestiary Discovery Check in Target HUD (`UI/CaptureHUD.lua`, `Core/DB/DB_Bestiary.lua`)**:
  * Implemented `DB:IsSpeciesDiscovered(nameOrId)` in `DB_Bestiary.lua` so studied/caught wild specimens render authentic Dam/Sire sex badges rather than `[❓ Sex: Unknown]`.
* [x] **Ensure Active Companion Move Synchronization (`Core/StatEngine.lua`, `UI/Views/JournalRosterView.lua`)**:
  * Populated `mob.moves` alongside `mob.abilities` upon companion creation and added a fallback in `JournalRosterView.lua` so move cards render correctly.
* [x] **Correct TOC Load Order for Base Constants (`ForeverSafari.toc`)**:
  * Moved `Core\Constants.lua` above `Data\CreatureDB.lua` and `Data\BestiaryDB.lua` so default display ID helpers resolve during static bestiary initialization.
* [x] **Bind Battle HUD ExpBar to 5-Rank Attunement Curve (`UI/BattleFrame.lua`)**:
  * Updated `PlayerHUD.ExpBar` min/max and value bindings to track `player.attunement` against `C.ATTUNEMENT_RANKS` with `|cffaa44ffATN:|r` label.
* [x] **Synchronize Chat Prefix Version Tag (`Core/Constants.lua`, `ForeverSafari.toc`)**:
  * Bumped `C.PREFIX` and TOC version to `v1.0.4`.

## 📍 Phase 27: Master Census Ingestion, Creature Acquisition & Hole Remediation (Active Top Priority 🎯)
Governed directly by [HOW_WE_GET_OUR_CREATURES.md](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/HOW_WE_GET_OUR_CREATURES.md). Resolves the 6 core architectural gaps before executing the dual-pass scraper:

* [ ] **Hole 1 Remediation: Two-Stage Display ID Extraction Engine**:
  * Solve Wowhead listview JSON omitting `displayId`.
  * **Stage 1**: Pre-index returning Classic creatures (~95%) from local DBC client tables (`Data/CreatureDisplays.lua`).
  * **Stage 2**: Route individual page scrapes (`/forever/npc={id}`) strictly to newly added Beta 1.60.1 mobs (`firstseenpatch: 16001`) with atomic disk caching.
* [ ] **Hole 2 Remediation: Extended Wildlife & Orphaned Beast Taxonomy Mapping**:
  * Prevent dropped beasts during the Pass 1 $\bowtie$ Pass 2 join by mapping all WoW `type: 1` wildlife outside the 19 primary slugs into canonical families:
    * *Devilsaurs* ➔ Raptor subfamily (Ferocity)
    * *Basilisks* ➔ Scalehide / Crocolisk subfamily (Tenacity)
    * *Chimaeras* ➔ Wind Serpent subfamily (Ferocity)
    * *Silithid Wasps & Crawlers* ➔ Scorpid / Spider subfamily
    * *Stags, Gazelles, Rams* ➔ Scalehide / Tallstrider subfamily
    * *Carrion Grubs & Worms* ➔ Scorpid / Beast subfamily
* [ ] **Hole 3 Remediation: Pre-Compiled AI Trainer Race Tagging (Offline Keyword Tokenizer)**:
  * Overcome the engine limitation where `UnitRace("target")` returns `nil` for NPCs.
  * Implement offline name and title keyword tokenizer in the census scraper to identify races (*Centaur*, *Quilboar*, *Harpy*, *Murloc*, *Gnoll*, *Dwarf*, *Trogg*, etc.).
  * Bake authoritative `race = "X"` keys directly into `Zone_{id}_Humanoids.lua`.
* [ ] **Hole 4 Remediation: Reconcile Field Observation vs. Channeled Binoculars**:
  * Eliminate the conflict between non-invasive out-of-combat Binoculars study and in-combat spell cast triggers.
  * Codify the channeled Field Lens progress bar (6-second peaceful study) to unlock observed signature moves in Nesingwary's Field Guide.
* [ ] **Hole 5 Remediation: Open-World World Bosses & Apex Rare Elites Gating**:
  * Formally segregate open-world World Bosses and high-tier Elites (`classification >= 2`, e.g. Azuregos, Teremus the Devourer, Lord Kazzak, King Bangalash).
  * Exclude world bosses from standard turn-based net captures; gate their companion offspring to **`PUP_DROP`** on world slay (or specialized League Expedition Permits).
* [ ] **Hole 6 Remediation: Master Tinker Combobulation Lifecycle & Component Economy**:
  * Codify the 2-player co-op Combobulation handshake protocol at Master Tinkers (Booty Bay, Ironforge, Orgrimmar) via Pop-Up HUD.
* [ ] **Starter Pet Attunement Re-baseline (Rank I Wild / Untamed)**:
  * Revise initial unboxed starter pet from Rank III (600 ATN) down to **Attunement Rank 1 (0 ATN points)** (`Core/Database.lua`).
  * Enforces organic progression: the starter companion begins unbroken (15% disobedience, 1 active ability slot) and bonds with the trainer as they work through the initial dispatches.
* [ ] **7-Stage Progressive Dispatches Pipeline (`Data/BountyDB.lua`)**:
  * Expand the initial recruitment directives to insert dedicated capture and healing onboarding stages before nourishment:
    1. **Dispatch #1**: Welcome to the Safari League! (Unbox starter at Rank I).
    2. **Dispatch #2**: Field Observation 101 (`OBSERVE`, 3 beasts).
    3. **Dispatch #3**: The First Snare (`CAPTURE`, 1 wild beast in the field).
    4. **Dispatch #4**: Field Care & Recovery (`HEAL`, 1 companion via salve, bandage, or innkeeper).
    5. **Dispatch #5**: The Wild Nourishment (`FEED`, 2 treats/diets).
    6. **Dispatch #6**: Sighting of Apex Rares (`CAPTURE_RARE`, 1 rare beast).
    7. **Dispatch #7**: Deep Dungeon Expedition (`BOSS_KILL`, 1 catalyst boss).
* [ ] **Dual Zone Census Ingestion & Database Emission**:
  * Execute Pass 1 (`npcs?filter=6;{zoneId};0`) across all ~60 zones at a polite 5.0s throttle (~5 minutes total) with atomic caching.
  * Execute Pass 2 across the 19 Beast subfamilies + 3 non-beast families.
  * Compile clean, partitioned registries into `Data/Creatures/Zones/` and master index into `Data/CreatureDB.lua`.

---

## 📍 Phase 28: Future Expansions & Social Leagues (Pending ⏳)
* [ ] **PvP Safari Tournaments & Guild Ladders**: Cross-faction companion duel tournaments, bracket scheduling, and guild ladders.
* [ ] **Safari Attunement Master Quests**: Epic class- and race-specific questlines to earn Master attunement and legendary expedition traps.
* [ ] **World Boss Safari Raids**: Instanced raid encounter mechanics for legendary apex creatures.


