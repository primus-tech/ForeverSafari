# 🐾 Forever Safari
**The Premier Creature Taming, Battling & Evolution Addon for World of Warcraft: Forever Beta**

---

## 📖 Overview

**Forever Safari** brings deep, tactical creature-taming, attunement loyalty, and turn-based battle mechanics directly into Azeroth. Built specifically for **World of Warcraft: Forever Beta** (`_classic_beta_` / `dataEnv: 16`), it transforms the wilderness into an expansive monster-battling adventure guided by the legendary master hunter **Hemet Nesingwary Sr.**

---

## 📜 The Nesingwary Junior Safari League

Upon first logging into Azeroth, players receive an official **Safari Dispatch** from Hemet Nesingwary welcoming them to the *Junior Safari League*.

Recruits are supplied with:
1. **[Caged Starter Companion]** — A wild companion native to their race's starting region.
2. **[Copper Snares x 10]** — Essential hemp rope slip-nooses to snare wild creatures during combat.
3. **[Copper Transport Crates x 3]** — Reinforced transport carriers to safely ship excess captures to the Kennel.
4. **[Safari Healing Salves x 5]** — Soothing remedies to restore a wounded companion's health.
5. **[Revival Crystal x 1]** — Shard of rejuvenation to restore a fainted companion in emergencies.
6. **[Forever Safari Field Guide]** — The interactive 3D Paperdoll Journal and creature encyclopedia.

---

## 🐾 Racial Starter Companions

Every playable race receives an authentic wild companion indigenous to their homeland:

| Race | Starting Zone | Starter Companion | Family | Display ID | Thematic Heritage |
| :--- | :--- | :--- | :--- | :---: | :--- |
| 🛡️ **Human** | Elwynn Forest | **Mangy Wolf** | Canine | `903` | Scruffy predator of Northshire foothills |
| ⛏️ **Dwarf** | Dun Morogh | **Young Black Bear** | Bear | `8843` | Homage to the iconic 2004 cinematic Hunter bear |
| ⚙️ **Gnome** | Dun Morogh | **Crag Boar** | Boar | `138623` | Resilient, plucky grazer of the snowy peaks |
| 🌙 **Night Elf** | Teldrassil | **Young Nightsaber** | Cat | `11454` | Agile, moonlit stalker of Shadowglen |
| 🪓 **Orc** | Durotar | **Scorpid Worker** | Scorpid | `2485` | Venomous crawler from Valley of Trials |
| 🏹 **Troll** | Durotar / Sen'jin | **Bloodtalon Raptor** | Raptor | `1960` | Swift, ferocious predator of Sen'jin and the Darkspear Loa |
| 🪶 **Tauren** | Mulgore | **Kodo Calf** | Kodo | `1451` | Gentle yet thunderous powerhouse of the plains |
| 💀 **Undead** | Tirisfal Glades | **Mangy Duskbat** | Bat | `9535` | Eerie nocturnal flier haunting the ruined belfries |

> [!NOTE]
> **Starter Partner Status (Rank III: Trusting)**: Your starting companion is a specially trained partner provided by Hemet Nesingwary and begins at **Rank III: Trusting** (600 Attunement Points) with full **1.00x True Baseline Stats (100/100 points)**, **5% Disobedience**, and **Slot 3 Unlocked for Training**. Wild beasts caught in the field with snares start at **Rank I: Wild / Unbroken** (0 Attunement, 0.85x stats, 25% disobedience) requiring bonding and feeding to domesticate.

---

## 🌟 Core Features

### 1. Modular 3D Field Guide Journal (`/safari`)
Deconstructed into decoupled, high-performance UI views and components:
* **View 1: 3D Squad Spotlight (`ROSTER`)**: A single-companion high-definition 3D pedestal stage featuring fluid 360° mouse drag rotation, zoom, instant animation triggers (`[ ⚔ Attack ]`, `[ 🦁 Roar ]`, `[ 🏆 Victory ]`, `[ 🐾 Idle ]`), real-time nickname editing, attunement gauge, stat radar, 4-move cards, and an interactive nourishment feeding tray.
* **View 2: 3D Menagerie Gallery (`GRID`)**: Browse your entire captured collection in a 6-card 3D paperdoll grid with 9-type filter ribbon, pagination, real-time HP bars, and squad leader toggles.
* **View 3: Azeroth Bestiary (`BESTIARY`)**: Complete 215-species field Pokédex tracking discoveries (`seen`, `caught`), 9-element filter menu, search box, live 3D species stage with animations, native habitats, base stats, Nesingwary lore notes, and natural family movepools.
* **View 4: Field Directives & Quest Log (`BOUNTIES`)**: Track active Nesingwary research directives, target objectives, kill/tame quotas, progress bars, and lore dossiers directly from the field.
* **Active Party Dock (`JournalTeamDock.lua`)**: Bottom 4-slot party dock with live mini 3D pedestals and health gauges.
* **Beast Training Grimoire Drawer (`JournalTrainingDrawer.lua`)**: Popout grimoire drawer for slot ability training and move customisation.

### 2. 215-Species Azeroth Bestiary (Authentic Field Pokédex)
A curated, lore-accurate field catalog spanning all 9 creature types of Classic Azeroth:
* 🐾 **Beasts**: Wolves, Cats, Bears, Boars, Raptors, Spiders, Crocolisks, Kodos, Bats, Wind Serpents, Scorpids, Hyenas, Tallstriders, Gorillas, Carrion Birds, Crabs, Turtles.
* ⚙️ **Mechanicals**: Harvest Watchers, Clockwork Gnomes, Mechano-Striders, Peacekeeper Units, Compact Harvesters.
* 💀 **Undead**: Plague Rats, Skittering Spiders, Scourge Ghouls, Ghost Claws, Spectral Wolves.
* 🌋 **Elementals**: Fire Elementals, Tar Elementals, Earth Rumbles, Water Elementals, Air Elementals.
* 🐉 **Dragonkin**: Whelps, Dragonhawks, Proto-Drakes, Fey Dragons.
* 🌊 **Aquatics**: Frenzies, Reef Crabs, River Crocolisks, Snapjaw Turtles.
* 🦅 **Flyers**: Owls, Vultures, Bats, Dragonhawks, Gryphons, Wind Serpents.
* ✨ **Magic**: Arcane Anomalies, Mana Wyrms, Sprite Darters.
* 🛡️ **Humanoids**: Murlocs, Troggs, Defias Outlaws, Kobolds.

### 3. 5-Rank Attunement & Loyalty Progression (Replaces Numerical Leveling)
Companions progress through bonding, feeding, and battlefield survival rather than numerical XP grind:

| Rank | Title | Combat Behavior & Checks | Move Slots | Stat Mult | Metamorphosis |
| :---: | :--- | :--- | :--- | :--- :---: | :---: |
| **I** | **Wild / Unbroken** | 25% Disobedience chance (slips into wild turns, loafs, or hesitates). | **1** | **0.85x** | ❌ Destabilizes |
| **II** | **Tolerant** | 15% Disobedience chance. Basic orders execute cleanly. | **2** | **0.95x** | ❌ Destabilizes |
| **III** | **Trusting** | 5% Disobedience chance. Reliable in combat. | **3** | **1.00x** | ❌ Destabilizes |
| **IV** | **Devoted** | 0% Disobedience. +5% Critical Strike bonus on family moves. | **4** | **1.05x** | ❌ Destabilizes |
| **V** | **Bestial Symbiosis** | 0% Disobedience. Maximum harmony and power. | **4 + Perk** | **1.15x** | ✅ **Catalyst Ready!** |

* **Battle Resilience**: Winning battles where your companion does not faint (+35 Attunement).
* **Family Nourishment**: Feeding matching dietary sustenance (e.g. Safari Meat, Fish, Cheese, Bread, Fruit, Fungus, Parts, Bonedust, Shards, Crystals, Runes) to foster loyalty (+25 Favorite Diet, +15 Accepted Diet).
* **Zone Acclimation**: Exploring with your companion active in its native regional habitat (+15 Acclimation).

### 4. Shared Family Movepools, Feral Druid Abilities & Apex Signatures
* **Shared Family Grimoires**: All creatures within the same family (e.g. all Felines) share a universal movepool.
* **Feral Druid & Tactical Movepool**:
  * **Dash** (`[117]`): +50% Speed burst for 3 turns.
  * **Cower** (`[118]`): +30% Defense defensive shield.
  * **Dive** (`[709]`): Flying aerial burst with speed surge.
  * **Frenzied Regeneration** (`[119]`): 3-round Heal-Over-Time (HoT) restoring 15% Max HP per round.
  * **Mangle** (`[120]`): Powerful beast strike inflicting a +50% bleed vulnerability debuff.
  * **Shred** (`[121]`): Behind-the-back claw strike with +20% extra critical strike chance.
  * **Swipe** (`[122]`): Sweeping multi-strike claw attack.
  * **Faerie Fire** (`[123]`): Reduces enemy Defense by 20% and reveals stealthed/flying targets.
  * **Tiger's Fury** (`[124]`): +35% Attack power enrage buff.
  * **Skull Bash** (`[125]`): Heavy headbutt with a 30% chance to cause the foe to flinch.
  * **Alarm Bark** (`[126]`): Breaks stealth/Prowl and aerial evasion, with a 25% flinch chance.
  * **Hyena Cackle** (`[127]`): Demoralizing laughter reducing enemy Attack by 25%.
  * **Constrict** (`[509]`): Squeezing clamp inflicting 3-round damage-over-time.
  * **Slumbering Venom** (`[510]`): Tranquilizing venom with a 50% chance to put the target to sleep for 2 rounds.
* **Apex Boss & World Rare Signatures**:
  * **Broken Tooth** (NPC `2850`): **Hyper Velocity** (`[1001]`, +2 priority lightning strike homage to its 1.0 attack speed).
  * **Humar the Pridelord** (NPC `5828`): **King's Roar** (`[1002]`, demoralizing apex roar reducing enemy Attack & Defense by 20%).
  * **Aku'mai** (NPC `4829`): **Void Stream** (`[1003]`, hybrid Water/Shadow surge dealing bonus damage against poisoned foes).
  * **Snarlmane** (NPC `1948`): **Shadowfang Rend** (`[1004]`, shadow necrotic curse).
  * **Rotgrip** (NPC `12258`): **Crushing Clamp** (`[1005]`, high-damage crocolisk lock-jaw clamp).

### 5. NPC Rival Battler Engine (Humanoids as AI Trainers)
* **Challenging Azeroth's Humanoids**: Targeting and challenging any roaming Humanoid mob across Azeroth (e.g. Defias Cutthroats, Kobold Miners, Murloc Tidecallers, Riverpaw Gnolls, Kolkar Centaurs, Scarlet Crusaders, Dark Iron Dwarves, Syndicate Rogues, Southsea Pirates, Bloodscalps, Ogres, Venture Co., Twilight Cultists, or Nesingwary Safari Trackers) initiates an **AI Trainer Battle** rather than a wild creature encounter.
* **14 Themed Faction Archetypes**: Each faction possesses a distinct title, immersive intro quote, defeat quote, token bounty payout, and a themed 1-to-3 companion roster scaling with level (Lv 1–15: 1 companion; Lv 16–35: 2 companions; Lv 36+: 3 companions).
* **AI Trainer Pet Switching**: When a trainer's active pet faints, they automatically send out their next companion from their bench with custom battle announcements.
* **Trainer Companion Protection**: Cages and snares cannot be thrown at trainer-owned pets (`"You cannot capture another hunter's companion!"`).
* **Safari Token Economy**: Roaming Humanoid AI Trainers are the primary open-world source of **Safari Tokens** (6–18+ tokens per victory, scaling with level and faction). Wild creature battles yield family nourishment diet items, attunement bonding, and quest progress, but do not drop tokens.

### 6. 100/110 Stat Budget Formula & 2-Move Starter Loadout
* **Normalized Base Stat Budgets**:
  * **Non-Rare Species**: Exactly **100 base stat points** distributed across HP, Attack, Defense, and Speed.
  * **Rare & Apex Species**: Exactly **110 base stat points** distributed across HP, Attack, Defense, and Speed.
* **Elemental Type Multipliers**: Multiplied by creature type passive modifiers (e.g. Beast 1.1x Attack, Mechanical 1.15x Defense, Flying 1.15x Speed).
* **2 Starting Abilities**: Every wild companion begins with exactly **2 starting moves** (Slot 1: Basic Attack, Slot 2: Family Signature/Utility Move). Slots 3 & 4 remain empty until unlocked and trained via the Beast Training Grimoire at higher Attunement Ranks.

### 7. Evolution Catalysts & Greed-Only Boss Loot
* Dungeon bosses drop rare **Evolution Catalysts** (such as *[Shadowfang Essence]* from SFK or *[Hydra Bile]* from BFD).
* **Secondary Loot Window**: Pops on boss defeat with a **Greed-Only fair roll** (Need is permanently disabled for all players).
* **Rank V Metamorphosis**: Using a catalyst on a companion at Rank V transforms its 3D model (e.g. Mangy Wolf ➔ **Slavering Worg**), scales base stats, and unlocks apex abilities while preserving its custom nickname and learned grimoire.

### 8. Rare Spawn Protection & Reserved Names
* **Reserved Name Registry**: Prevents common pets from being renamed after iconic world rares (e.g. *Humar the Pridelord*, *The Rake*, *Broken Tooth*, *Aku'mai*).
* **Golden Dragon Crest**: Genuine wild rares display an unforgeable golden dragon crest and authentication stamp in the 3D Inspector.
* **Evolution Exemption**: World rares are legendary apex beasts and cannot be evolved, preserving their iconic wild prestige.

### 9. Virtual Safari Bag & 5-Tier Capture Gear Progression
* **Authentic Container Experience**: Styled as a classic 20-slot World of Warcraft backpack container with gold-trimmed borders, quality-tinted slots, stack count badges, and authentic sound effects.
* **Addon-Exclusive Items**:
  * 🕸️ **Capture Gear Progression**:
    * **Tier 1 (Common)**: **Copper Snare** (`INV_Misc_Noose_01` — 1 Token, 35% Base Catch)
    * **Tier 2 (Uncommon)**: **Iron Safari Net** (`Hunter_PvP_TrackersNet` — 5 Tokens, 55% Base Catch)
    * **Tier 3 (Rare)**: **Mithril Hunter Trap** (`INV_Pet_PetTrap` — 10 Tokens, 75% Base Catch)
    * **Tier 4 (Epic)**: **Thorium Expedition Cage** (`INV_Box_Birdcage_01` — 25 Tokens, 98% Base Catch)
  * 📦 **Transport Crates (Kennel Logistics)**:
    * **Tier 1 (Common)**: **Copper Transport Crate** (`INV_Box_PetCarrier_01` — 1 Token, Common/Small Game)
    * **Tier 2 (Uncommon)**: **Iron Transport Crate** (`INV_Box_PetCarrier_01` — 5 Tokens, Uncommon)
    * **Tier 3 (Rare)**: **Mithril Transport Crate** (`INV_Box_PetCarrier_01` — 10 Tokens, Rare)
  * 🥩 **11 Safari Diet Sustenance Items**:
    * **Natural Diets**: **Safari Meat** (Carnivores), **Safari Fish** (Shore / Aquatic hunters), **Safari Bread** (Herbivores / Grazers), **Safari Cheese** (Omnivores / Rodents), **Safari Fruit** (Avians, Bats, Primates), **Safari Fungus** (Cave & Swamp scavengers).
    * **Special Diets**: **Safari Parts** (Mechanicals), **Safari Bonedust** (Undead), **Safari Shards** (Magic), **Safari Crystals** (Elementals), **Safari Runes** (Dragonkin).
    * **Feeding Rewards**: +25 Attunement for Favorite Diets (with happy roar animation), +15 Attunement for Accepted Diets. Incompatible food is rejected without item loss.
  * 🧬 **Evolution Catalysts**: Dungeon boss drops (Shadowfang Essence, Hydra Bile, Venomous Gland, Overclocked Core, Volcanic Core).
  * 🍖 **Consumables**: Safari Treats (+50 Attunement), Grand Safari Feasts (+100 Attunement to full team), Safari Healing Salves (100% HP heal), and Revival Crystals.
* **Context-Sensitive Actions**: Right-Clicking items in the bag automatically uses or feeds your active companion, or opens the 3D Metamorphosis pedestal. Shift-Clicking any item links it directly into chat.

### 10. Innkeeper Safari Kennel (10 Enclosure Boxes = 200 Banked Pets)
* **Zero Out-of-World Access**: Store and bank interfaces are accessed **exclusively when interacting with authorized NPCs in town** via zero-taint standalone sidecar windows.
* **Innkeepers (Safari Kennel — The Pokémon Bank of Azeroth)**:
  * **Active Squad vs. Bank Enclosures**: Players carry up to 4 active battle companions in their field squad. The remaining creatures are stored across **10 Enclosure Bank Boxes** (20 slots per box = 200 banked companions).
  * **Interactive Pedestals & Transfer**: Withdraw, deposit, and swap companions seamlessly between your active 4-member squad and bank enclosures.
  * **`[ 💖 Tend & Rest All Pets ]`**: Instant full heal and revival for all active and banked companions while resting at any Inn.
* **Transport Crate Logistics**:
  * If the player's active squad is full (**4/4**), capturing a wild beast auto-consumes **1 matching (or higher tier) Transport Crate** from the Safari Bag and safely ships the specimen to the **Safari Kennel** at the Innkeeper.
  * If the squad has an open slot (< 4), the wild beast is recruited directly into the active team with no crate required.

### 11. Pet Trainers (Nesingwary Safari Outfitter — Universal Class Access)
* **Accessible to ALL Classes**: Non-Hunter classes (Warriors, Mages, Rogues, Priests, Warlocks, Paladins, Shamans, Druids) and Hunters alike can interact with town Pet Trainers.
* **Category Tabs**:
  * 🕸️ **Capture Gear**: Copper Snare, Iron Net, Mithril Trap, Thorium Cage.
  * 📦 **Transport Crates**: Copper, Iron, Mithril, and Thorium Crates with color-coded quality tints.
  * 🥩 **Treats & Diets**: Safari Treats, Grand Feasts, and 11 canonical Safari diet items.
  * 🧪 **Medicine & Aid**: Healing Salve and Revival Crystals.
* **Beneath-the-Item Card Layout**: Each item displays the number owned (`Owned: X`), token cost (`Cost: X Tokens`), and `[ Buy x1 ]` button directly beneath the item name and description.

### 12. Real Quest Token Grants, Retroactive Compensation & Companion Bonding
* **Real Quest Completion Rewards**: Turning in quests across Azeroth (`QUEST_TURNED_IN`) directly rewards the player with **Safari Tokens** scaled by character level:
  * **Level 1–19**: **+5 Safari Tokens** per quest.
  * **Level 20–39**: **+7 Safari Tokens** per quest.
  * **Level 40+**: **+10 Safari Tokens** per quest.
* **Active Companion Bonding**: Every completed quest awards **+20 Attunement Points** to your active squad companion, forging a deeper bond through field adventures.
* **Retroactive Back-Quest Compensation (`C_QuestLog.GetAllCompletedQuestIDs`)**:
  * When installing Forever Safari on an existing character (e.g. at Level 30 or 60), the addon automatically queries all previously completed quests and awards a lump-sum retroactive **Safari Research Grant** (e.g. 5 tokens per quest) in the welcome onboarding package.
  * **Double-Dip Protection**: Every rewarded quest ID is permanently recorded in `SafariCharacterDB.rewardedQuests`, ensuring each quest in Azeroth pays out exactly once.

### 13. Dungeon Boss Permits, Minor Shards & Evolution Catalyst Fair Loot (`UI/CatalystLootFrame.lua`)
* **Dungeon Boss Research Permits**: Defeating iconic dungeon bosses unlocks locked creature type research permits across the entire party:
  * **Mechanical Research Permit**: Defeating *Sneed's Shredder* or *Foe Reaper* in Deadmines.
  * **Elemental Research Permit**: Defeating *Viscous Fallout* in Gnomeregan (or *Baron Aquanis* in BFD).
  * **Undead Research Permit**: Defeating *Amnennar the Coldbringer* in Razorfen Downs.
  * **Dragonkin Research Permit**: Defeating *Avatar of Hakkar* or *Morphaz/Hazzas* in Sunken Temple.
* **Greed-Only Evolution Catalyst Rolling**:
  * Dungeon bosses drop rare **Evolution Catalysts** (e.g. *[Shadowfang Essence]*, *[Hydra Bile]*, *[Overclocked Core]*, *[Volcanic Core]*).
  * Triggers a dedicated, fair secondary loot window for all party members with **Greed-Only rolls** (Need is permanently disabled).
* **✨ Minor Evolution Shards & Instant Forge (10-to-1 Combining)**:
  * Regular dungeon trash mobs have a **0.1% chance (1 in 1,000)** to drop a **[Minor Evolution Shard]** into your Safari Bag.
  * Right-clicking a stack of **10 Minor Evolution Shards** in your Safari Bag instantly consumes them and forges **1 Full Evolution Catalyst**!
* **Rank V Metamorphosis**: Applying a catalyst to a companion at **Rank V: Bestial Symbiosis** evolves its 3D model, elevates its base stats, and unlocks apex moves while retaining custom nicknames and grimoires.

### 14. Physical Mailbox Hub & Standalone Sidecar ("Safari Dispatch")
* **Zero-Taint Mailbox Sidecar**: Standalone Nesingwary Dispatch Hub docked seamlessly alongside Blizzard's `MailFrame` (`MAIL_SHOW`) on `UIParent`.
* **Full-Width Inbox Column**: Displays received Nesingwary dispatches and field bounties with sender names, titles, and status tags (`[ 📦 Unopened Parcel ]`, `[ ✔ Ready to Claim ]`, `[ ✉️ New ]`).
* **Secondary OpenMail Window**: Dedicated `OpenMail` window attached to the side, styled with Nesingwary gold/dark theme, antique parchment letter body, and a parcel attachment tray with tooltips and one-click unbox/claim actions.

---

## 🎮 Slash Commands

* `/safari` or `/fs` — Open the Forever Safari 3D Field Guide & Squad Manager
* `/safari kennel` or `/fskennel` — Open the Safari Kennel (Requires Innkeeper interaction)
* `/safari bounties` — View Active Field Directives & Quest Tracker (Tab 4)
* `/safari observe` or `/fsnet` — Channel field observation to stalk target and discover new moves
* `/safari abandon` or `/safari release` — Release active companion back into the wild (with confirmation)
* `/fsbag` or `/safari bag` — Open the Virtual Safari Bag container
* `/fsmail` or `/safari mail` — Open Nesingwary Safari Correspondence (Turn in at Mailbox)
* `/fsshop` — Open Nesingwary Safari Outfitter (Requires Pet Trainer interaction)
* `/fsbattle` — Engage targeted creature in turn-based combat
* `/fsduel` — Challenge targeted player to a companion duel
* `/safari tokens` — Check your current Safari Token balance
* `/safari reset` — Reset all progress back to a fresh new recruit

---

## 🛠️ Project Structure

```
ForeverSafari/
├── ForeverSafari.toc                  # Addon Manifest (WoW Forever Beta 1.60.1)
├── ForeverSafari.lua                  # Main Addon Bootstrap & Slash Commands
├── README.md                          # Comprehensive Documentation & Architecture Manual
├── ROADMAP.md                         # Master Milestone & Feature Tracker
│
├── Data/                              # Canonical Data Registries
│   ├── ItemDB.lua                     # Snares, Traps, Cages, Crates, 11 Diets & Consumables
│   ├── MoveDB.lua                     # 94 Moves (Feral Druid, Utility, Boss Signatures)
│   ├── CreatureDB.lua                 # 1,910 Normalized Species & 715 3D Displays
│   ├── BestiaryDB.lua                 # 215 Curated Classic Species across 9 Families
│   ├── EvolutionDB.lua                # Metamorphosis Recipes & Boss Drops
│   └── TrainerDB.lua                  # 14 Humanoid Rival Factions, Quotes & Rosters
│
├── Core/                              # Core Engine & Subsystem Logic
│   ├── Constants.lua                  # Types, Elements, Attunement Ranks, Diets, Crates
│   ├── Database.lua                   # Core Initialization, Signatures, DNA & Settings
│   ├── DB/                            # Domain-Specific Database Sub-Modules
│   │   ├── DB_Pets.lua                # Companion CRUD, Active Party & Nicknames
│   │   ├── DB_Kennel.lua              # 10 Storage Enclosure Boxes & Crate Logistics
│   │   ├── DB_Bestiary.lua            # Pokédex Discovery & Progress Tracking
│   │   └── DB_Inventory.lua           # Token Vault & Virtual Bag Management
│   ├── StatEngine.lua                 # Attunement Scaling, 100/110 Budget & Stat Engine
│   ├── TrainerEngine.lua              # Roaming Humanoid NPC AI Trainer Battle Matcher
│   ├── CaptureEngine.lua              # Capture Formulas, Catch Rates & Crate Logistics
│   ├── BattleEngine.lua               # Turn-Based Combat Loop, AI Trainers & Statuses
│   ├── QuestHooks.lua                 # Boss Kills, Quest Hooks & Token Rewards
│   └── Comms.lua                      # P2P Multiplayer Sync & Chat Hyperlinks
│
└── UI/                                # User Interface & Views
    ├── Theme.lua                      # Nesingwary Safari Gold & Dark Theme Tokens
    ├── Toast.lua                      # Animated Reward & Capture Notifications
    ├── MinimapButton.lua              # Minimap Radar Icon & Coordinates Tooltip
    ├── SafariMailFrame.lua            # Mailbox Custom Tab & Quest Correspondence Hub
    ├── DispatchLetterFrame.lua        # Nesingwary Parchment First-Login Onboarding
    ├── InspectorFrame.lua             # 3D Paperdoll Popup for Chat Hyperlinks
    ├── CatalystLootFrame.lua          # Greed-Only Secondary Boss Loot Window
    ├── CaptureHUD.lua                 # Real-Time Proximity & Move Discovery HUD
    ├── ShopFrame.lua                  # Pet Trainer Outfitter (Tabs & Below-Card Layout)
    ├── KennelFrame.lua                # Innkeeper Companion Bank (4 Squad + 10 Enclosures)
    ├── SafariBagFrame.lua             # Virtual Safari Bag 20-Slot Authentic Container
    ├── BattleFrame.lua                # Retro 3D Combat Arena & Command Menu
    │
    ├── Components/                    # Modular UI Components
    │   ├── JournalTeamDock.lua        # Bottom 4-Slot Active Squad Dock
    │   └── JournalTrainingDrawer.lua  # Beast Training Grimoire Slide-Out Drawer
    │
    └── Views/                         # Modular Journal Views
        ├── JournalRosterView.lua      # View 1: 3D Companion Spotlight & Dossier
        ├── JournalGridView.lua        # View 2: 3D Menagerie Gallery Grid (6-Card)
        ├── JournalBestiaryView.lua    # View 3: 215-Species Azeroth Bestiary Pokédex
        └── JournalBountiesView.lua    # View 4: Field Directives & Research Quest Log
```

---

## 🏛️ World of Warcraft: Forever Beta Architecture Standards

Forever Safari is architected in 100% strict compliance with the **10 Commandments of WoW: Forever Beta (Build 69913/70009 / 16001 / Midnight 12.1.5 engine)**:

1. **`Interface: 16001`**: Multi-client compatible TOC with `16001` primary declaration for Forever Beta.
2. **Lua 5.1 Environment**: Zero prohibited keywords (`goto`, `//`, direct bitwise operators, `_ENV`, `require`, `dofile`, `loadfile`). Module loading handled strictly via `.toc`.
3. **Mainline 12.1.5 Engine**: Conforms to modern Mainline UI architecture, disarmament restrictions, and protected execution paths.
4. **`C_` Namespaces & Offline Data Integrity**: Fully decoupled from deprecated global APIs (`GetSpellInfo`, `GetItemInfo`), utilizing internal high-speed databases (`ItemDB`, `CreatureDB`, `MoveDB`, `BestiaryDB`, `EvolutionDB`, `Constants`).
5. **Namespace Isolation**: Every module starts with `local addonName, ns = ...` and attaches shared state directly to `ns`, preventing global namespace collision.
6. **Event-Driven Subsystems**: Zero `COMBAT_LOG_EVENT_UNFILTERED` registration. All game logic runs through clean high-level events (`ENCOUNTER_END`, `BOSS_KILL`, `QUEST_TURNED_IN`, `PLAYER_TARGET_CHANGED`, `UNIT_HEALTH`).
7. **Zero-Taint & Secret Value Resilience**: All unit and environment queries (`UnitCreatureType`, `UnitClassification`, `UnitReaction`, `UnitHealth`, `UnitLevel`, `UnitName`, `GetZoneText`) are fortified with robust `issecretvalue()`, `issecretpassphrase()`, `issecretvariable()`, and `pcall`-wrapped comparison guards. Fully immune to anti-automation secret string errors in dungeons, raids, and active combat.
8. **Capability-Based Detection**: No naive `WOW_PROJECT_ID` branching; feature probes are used instead.
9. **Zero Secure-Snippet Dependency**: Operates solely with custom `UIPanelButtonTemplate` and standard frame events without `loadstring_untainted` or secure unit frame tainting.
10. **Deterministic Load Order & Persistence**: Modular TOC load sequence with comprehensive `ADDON_LOADED` SavedVariables initialization.

---

## 📜 License & Credits

Developed with passion for the **World of Warcraft: Forever Beta** community. Dedicated to the Nesingwary Junior Safari League!
