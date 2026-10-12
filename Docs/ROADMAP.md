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
    * 🕸️ **Capture Gear**: Copper Snares, Iron Safari Nets, Mithril Hunter Traps, Thorium Expedition Cages.
    * 🥩 **Family Nourishment**: 17 wild harvested diets (Canine, Feline, Bear, Boar, Raptor, etc.) with favorite food attunement bonuses (+25 Attunement).
    * 🧬 **Evolution Catalysts**: Dungeon boss drops (Shadowfang Essence, Hydra Bile, Venomous Gland, Overclocked Core, Volcanic Core).
    * 🍖 **Consumables**: Treats (+50 Attunement), Feasts (+100 Attunement team-wide), Salves (100% Heal), and Revival Crystals.
  * **Context-Sensitive Actions**: Right-Clicking uses/equips items, feeds or heals active companion, or initiates Metamorphosis in the Field Guide. Shift-Clicking inserts item links into chat.
  * **Integration & Access**: Quick access buttons in Journal header, Minimap button middle/shift-click, Capture HUD, and `/fsbag` or `/safari bag` slash commands.

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
* [x] **Safari Journal Field Directives (Tab 4 — `/safari` / `/safari bounties`)**:
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
* [x] **In-Battle Capture Flow (`Core/BattleEngine.lua`, `UI/BattleFrame.lua`)**:
  * Thrown during turn-based combat via `[ BAG ] ➔ [ CAPTURE ]` submenu.
  * Capture probability factors in enemy remaining HP, tool tier bonus, and level difference.
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

## 📍 Phase 13: Authentic Azeroth Bestiary & Field Pokédex (Completed ✅)
* [x] **215 Curated Azeroth Species Roster (`Data/BestiaryDB.lua`)**:
  * Complete coverage across all 9 pet types: Beasts, Canines, Felines, Bears, Boars, Raptors, Avians, Bats, Crocolisks, Crabs, Turtles, Spiders, Scorpids, Hydras, Wind Serpents, Gorillas, Kodos, Tallstriders, Dragon Whelps, **Mechanicals (Harvest Reapers, Mech-Chickens, War Golems, Alarm-o-Bots)**, **Undead (Skeletal Raptors, Plaguebats, Ghostly Crabs, Bone Golems)**, and **Elementals (Blazing Elementals, Tide Walkers, Rock Rumblers, Tar Beasts, Dust Devils)**.
  * Verified 3D display IDs for 100% accurate paperdoll rendering.
  * Native regional habitats, favorite sustenance diets, base stats, and natural 4-move thematic movepools.
* [x] **3-Tier Pokédex Discovery Lifecycle (`Core/Database.lua`)**:
  * `[ ??? Undiscovered ]` ➔ `[ 🔭 Seen / Sighted ]` (stalked via `/safari observe` or encountered in combat) ➔ `[ 🐾 Captured ]` (caged into active squad or kennel).
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
    * `Core/DB/DB_Kennel.lua` — Storage boxes (1–10), crate transfer logic, kennel slots.
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
  * Wild creatures caught in snares/cages start at **Rank I: Wild / Unbroken** (0 Attunement, 0.85x stats, 25% disobedience), maintaining clear progression and domestic bonding loops.

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
  * Multi-template discovery (`PanelTabButtonTemplate`, `CharacterFrameTabButtonTemplate`, `UIPanelButtonTemplate`, and fallback) to support both legacy and modern `PortraitFrameTemplate` BankFrame architectures without Lua errors.
  * Toggles the companion vault docked alongside `BankFrame` and cleans up automatically on `BANKFRAME_CLOSED`.
* [x] **Druid Class Passive: Ecliptic Tides & 4-Role Ability Taxonomy**:
  * **Ecliptic Tides**: In-combat celestial pendulum tracking Solar vs. Lunar power up to companion Attunement Rank (1-5).
  * 5% per point surge check per turn with automatic 100% discharge at full meter capacity (Solar cleanses a debuff and grants a HoT; Lunar applies a Brambles Nature damage shield).
  * Standardized all 94 abilities across a 4-role taxonomy: Offensive (63 moves, builds Solar), Defensive (8 moves, builds Lunar), Field Hazard (11 moves, builds Lunar), and Weather (12 moves, builds Lunar).

---

## 📍 Phase 21: Combat Engine Architecture, Zero-Drift Stats & Taint Fortification (In Progress 🔄)
* [x] **Combat Engine Canon & Mechanics SSOT (`Docs/COMBAT_ENGINE_STATS_AND_MECHANICS.md`)**:
  * Unified all combat rules, stat algorithms, action-gauge speed lapping, 5-layer elemental resistances, and player class passives into a single authoritative canon.
* [x] **Zero-Drift Proportional Base Stat Algorithm**:
  * Formulated the Largest Remainder Method (Hamilton-Hare) guaranteeing exact, drift-free distribution to target budgets ($T = 100$ for Normal/Elite/Boss; $T = 110$ for Rare/Rare Elite).
  * Strict classification gating: Dungeon and raid bosses (`classification == 3`) strictly adhere to $T = 100$; wild rare spawns (`classification in (2, 4)`) receive $T = 110$.
* [x] **Layer 5 Defense Architecture (Static Slices vs. Procced Wards)**:
  * **Static Slices**: Warrior (Physical Armor, +5%/rank), Rogue (Miss/Evasion, +5%/rank), Hunter (Nature Resist, +5%/rank), and Druid (Omni-Resist across all 6 magic schools, +2%/rank).
  * **Procced Wards**: Mage, Shaman, Warlock, Priest, and Paladin (Proc chance $5\% \times \text{Rank}$, Mitigation $10\% \times \text{Rank}$). Evaluated independently per direct strike and **independently rolled on every single DoT tick**.
  * **Mage Chilling Tempo & Frost Counterplay**: 5% off / 10% def chill proc (-50% SPD) countered by target Frost Resistance % via **Direct Roll Subtraction** ($\max(0\%, \text{Base} - \text{Resist})$).
  * **Druid Ecliptic Tides**: Role-driven Solar/Lunar pendulum with early proc rolls ($5\% \times \text{pts}$) and automatic 100% discharge at cap.
* [x] **Taint Purge & Diagnostic Watcher (`Core/TaintWatcher.lua`)**:
  * Purged obsolete `Core/InstancePupDrops.lua` CLEU event registration, resolving all Blizzard UI tainted action errors.
  * Added `Core/TaintWatcher.lua` (loaded first in TOC) and `/fstaint` diagnostics; verified 100% clean startup and interaction.
* [ ] **Pipeline Tooling & Creature Regeneration (`Tools/build_creatures.py`)**:
  * Update `calculate_stats()` to execute the Largest Remainder algorithm and regenerate all 35 creature files in `Data/Creatures/`.
* [ ] **Combat Engine Execution (`Core/BattleEngine.lua` & `Core/StatEngine.lua`)**:
  * Implement the Action-Gauge 0–100 speed velocity and lapping queue.
  * Implement dynamic Layer 1–5 resistance derivation and procced ward evaluation (including independent per-tick DoT rolls).
  * Implement Druid Ecliptic Tides pendulum and Priest Divine Grace battle frame tray integration.

---

## 📍 Phase 22: Beast Taxonomy Refinement & Elemental Saurians (Pending ⏳)
* [ ] **Discrete Beast Family Stratification**:
  * Formalize **Kodos** and **Tallstriders** as strictly decoupled, distinct families within the Beast genus across all database tables, dietary rules, and family movepools.
  * Establish **Thunder Lizards** as their own dedicated saurian family (`Thunder Lizard` / `Lizard`) within Beasts.
* [ ] **Elemental License Gating for Thunder Lizards**:
  * Thunder Lizards harness primal nature and lightning fury. While taxonomically classified under the Beast genus, **capturing Thunder Lizards in the wild is strictly gated behind the Elemental Research Permit / License** (earned by defeating *Viscous Fallout* in Gnomeregan or *Baron Aquanis* in BFD).
* [ ] **Kalimdor Saurian Species Roster**:
  * Add canonical Barrens and Desolace species (*Thunder Lizard*, *Lightning Hide*, *Stormsnout*, and rare apex *Thunderhead*) to both `Data/CreatureDB.lua` and `Data/BestiaryDB.lua` with verified 3D display IDs, 100/110 base stat distributions, and thematic lightning movepools.
* [ ] **Spawn-Instance GUID Anti-Farm Lockouts (`UnitGUID`)**:
  * Track individual world spawn instances via `UnitGUID("target")` to eliminate duplicate engagements on the same living NPC.
  * **Observation / Scanning Lockout**: Successfully completing a field observation channel (`/safari observe`) marks the entity's GUID in `ForeverSafariDB.scannedGuids`, preventing redundant channels against that same wild specimen.
  * **Roaming AI Trainer Lockout**: Defeating a humanoid NPC in turn-based combat records their spawn GUID in `ForeverSafariDB.defeatedTrainers`, preventing players from repeatedly battling the same living humanoid for infinite Safari Tokens.
  * **Automated Expiration & Pruning**: Daily reset / 24-hour timestamp pruning to prevent SavedVariables bloat while allowing respawned world encounters.

---

## 📍 Phase 23: Future Expansions & Social Leagues (Pending ⏳)
* [ ] **Safari Outpost & Regional League System**: Implementation of the 5-Tier Faction-Parallel circuit, gym leaders, and 3D Field Guide Badge Case (`Docs/SAFARI_OUTPOST_SYSTEM.md`).
  * **Outpost Defeat Lockout (Anti-Farm Protection)**: Once an Outpost Leader / Gym is bested and awards its regional badge/crest, the outpost is locked against battle farming; subsequent interactions provide congratulatory dialogue and route the player to the next regional tier.
* [ ] **PvP Safari Tournaments & Guild Ladders**: Cross-faction companion duel tournaments and leaderboards.
* [ ] **Safari Attunement Quests**: Epic class and race-specific questlines to earn Master attunement and legendary nets.
* [ ] **World Boss Safari Raids**: Instanced raid encounter mechanics for legendary apex creatures.




