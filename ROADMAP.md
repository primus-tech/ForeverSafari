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

## 📍 Phase 20: Future Expansions & Social Leagues (Pending ⏳)
* [ ] **PvP Safari Tournaments & Guild Ladders**: Cross-faction companion duel tournaments and leaderboards.
* [ ] **Safari Attunement Quests**: Epic class and race-specific questlines to earn Master attunement and legendary nets.
* [ ] **World Boss Safari Raids**: Instanced raid encounter mechanics for legendary apex creatures.



