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
2. **[Nesingwary Safari Nets x 5]** — Essential capture nets to snare wild creatures in the field.
3. **[Forever Safari Field Guide]** — The interactive 3D Paperdoll Journal and creature encyclopedia.

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
### 1. 3D Paperdoll Journal & Field Guide
* **Interactive 3D Showcase**: Full 360° mouse drag rotation, zoom, animation triggers (Attack, Roar, Victory, Idle), and 4-stat combat radar dossier.
* **Paperdoll Gallery**: Browse your entire menagerie in live 3D card tiles with 9-element type filters and pagination.
* **Azeroth Bestiary**: 1,909 cataloged creatures with habitat maps, display previews, and diet specifications.
* **Field Directives & Quest Tracker (Tab 4)**: Track active Nesingwary research directives, target objectives, kill/tame quotas, progress bars, and lore dossiers directly from the field (`/safari` or `/safari bounties`).
* **3D Team Dock**: Live mini-paperdoll pedestals for your active 4-member battle squad.

### 2. 5-Rank Attunement & Loyalty Progression (Replaces Leveling)
Companions progress through bonding, feeding, and battlefield survival rather than numerical XP leveling:

| Rank | Title | Combat Behavior & Checks | Move Slots | Stat Mult | Metamorphosis |
| :---: | :--- | :--- | :---: | :---: | :---: |
| **I** | **Wild / Unbroken** | 25% Disobedience chance (slips into wild turns, loafs, or hesitates). | **1** | **0.85x** | ❌ Destabilizes |
| **II** | **Tolerant** | 15% Disobedience chance. Basic orders execute cleanly. | **2** | **0.95x** | ❌ Destabilizes |
| **III** | **Trusting** | 5% Disobedience chance. Reliable in combat. | **3** | **1.00x** | ❌ Destabilizes |
| **IV** | **Devoted** | 0% Disobedience. +5% Critical Strike bonus on family moves. | **4** | **1.05x** | ❌ Destabilizes |
| **V** | **Bestial Symbiosis** | 0% Disobedience. Maximum harmony and power. | **4 + Perk** | **1.15x** | ✅ **Catalyst Ready!** |

* **Battle Resilience**: Winning battles where your companion does not faint (+35 Attunement).
* **Family Nourishment**: Feeding wild meats/essences harvested from downed animals of the same family (+25 Attunement).
* **Zone Acclimation**: Exploring with your companion active in its native regional habitat (+15 Acclimation).

### 3. Shared Family Movepools (Vanilla Hunter Model)
* All creatures within the same family (e.g. all Wolves) share a universal **Family Grimoire**.
* **Field Discovery**: Encountering or capturing exotic wild variants unlocks abilities directly into your Trainer Grimoire.
* **Rank-Scaled Moves**: Move capacity scales from 1 to 4 active slots as Attunement increases.

### 4. Evolution Catalysts & Greed-Only Boss Loot
* Dungeon bosses drop rare **Evolution Catalysts** (such as *[Shadowfang Essence]* from SFK).
* **Secondary Loot Window**: Pops on boss defeat with a **Greed-Only fair roll** (Need is permanently disabled for all players).
* **Rank V Metamorphosis**: Using a catalyst on a companion at Rank V transforms its 3D model (e.g. Mangy Wolf ➔ **Slavering Worg**), scales base stats, and unlocks apex abilities while preserving its nickname and grimoire.

### 5. Rare Spawn Protection & Reserved Names
* **Reserved Name Registry**: Prevents common pets from being renamed after world rares (e.g. *Humar the Pridelord*, *The Rake*, *Broken Tooth*, *Aku'mai*).
* **Golden Dragon Crest**: Genuine wild rares display an unforgeable golden dragon crest and authentication stamp in the 3D Inspector.
* **Evolution Exemption**: World rares are legendary apex beasts and cannot be evolved, preserving their iconic wild prestige.

### 6. Social 3D Chat Links & Paperdoll Inspector
* **Shift-Click Chat Links**: Shift-Click any companion in your Field Guide to post an interactive `[Safari: Nickname Lv.X (3D)]` link into chat.
* **Live 3D Inspector**: Clicking chat links opens a dedicated 3D Paperdoll Inspector showing live rotatable model, full stats, custom nickname, and active 4-move loadout.

### 7. Virtual Safari Bag (Addon-Exclusive Storage)
* **Authentic Container Experience**: Styled as a classic 20-slot World of Warcraft backpack container with gold-trimmed borders, quality-tinted slots, stack count badges, and authentic sound effects.
* **Addon-Exclusive Items**: Stores only items tied directly to the addon without cluttering default Blizzard bags:
  * 🕸️ **Safari Nets**: Copper, Iron, and Mithril Nets, plus Master Arcanite Capsules.
  * 🥩 **Family Nourishment**: 17 harvested wild creature diet types (Wolf Meat, Feline Flank, Bear Ribs, Raptor Flesh, etc.) for feeding active companions (+25 Attunement for favorite diets, +15 for standard sustenance).
  * 🧬 **Evolution Catalysts**: Dungeon boss drops (Shadowfang Essence, Hydra Bile, Venomous Gland, Overclocked Core, Volcanic Core).
  * 🍖 **Consumables**: Safari Treats (+50 Attunement), Grand Safari Feasts (+100 Attunement to full team), Safari Healing Salves (100% HP heal), and Revival Crystals.
* **Context-Sensitive Actions**: Right-Clicking items in the bag automatically equips nets, feeds or heals your active companion, or opens the 3D Metamorphosis pedestal. Shift-Clicking any item links it directly into chat.

### 8. Physical Mailbox Hub & Authentic Two-Window Mail System ("Safari Dispatch")
* **Blizzard Mailbox Tab ("Safari")**: Authentic custom tab attached directly to Blizzard's `MailFrame` (`MAIL_SHOW`).
* **Full-Width Inbox Column**: Displays a full-width list of received Nesingwary dispatches and field bounties with sender names, titles, status tags (`[ 📦 Unopened Parcel ]`, `[ ✔ Ready to Claim ]`, `[ ✉️ New ]`), and row hover highlights.
* **Secondary Sidecar OpenMail Window**: Clicking any dispatch opens a dedicated `OpenMail` window attached to the side of `MailFrame`, styled with Nesingwary gold/dark theme, antique parchment letter body, and a parcel attachment tray with tooltips and one-click unbox/claim actions.
* **First-Load Starter Parcel**: Recruits unbox their racial companion starter kit and 5x Copper Safari Nets (0 free token handouts) directly from Hemet Nesingwary's welcome dispatch.
* **Field Research Bounty Turn-Ins**: Completed bounties are unboxed and turned in at a physical town mailbox to collect earned Safari Tokens and supplies.

### 9. Innkeeper & Pet Trainer Vendor Specialization (Gossip Box Only)
* **Zero Out-of-World Access**: Supply and food purchases cannot be made out in the field. Store interfaces are accessed **exclusively by clicking gossip menu options** when interacting with authorized NPCs in town.
* **Pet Trainers (Safari Nets & Capture Gear — Universal Class Access)**:
  * **Accessible to ALL Classes**: Non-Hunter classes (Warriors, Mages, Rogues, Priests, Warlocks, Paladins, Shamans, Druids) and Hunters alike can interact with town Pet Trainers to access the gossip window.
  * Gossip Option: `[ 🐾 Browse Safari Nets & Gear ]`
  * Inventory: Copper, Iron, Mithril Safari Nets, Arcanite Capsules, Revival Crystals, and Salves.
* **Innkeepers (Safari Treats & Food Provisions)**:
  * Gossip Option: `[ 🍖 Browse Safari Treats & Food Provisions ]`
  * Inventory: Safari Treats, Grand Safari Feasts, Healing Salves, and fresh harvested family meats (Wolf, Feline, Bear, Boar, Raptor, etc.).
* **Instant Auto-Close**: Closing the NPC gossip window immediately closes the shop interface.

### 10. The "Field Research" Snare & Hunter Coexistence (0% Mob Damage)
Forever Safari decouples creature capturing completely from world-mob HP, transforming the capture minigame into an authentic, peaceful **Stalking & Snare Channeling** system:

```
[Target In Range (15-28 yd)] ──► [Begin Net Channel (3-5 sec)]
                                         │
                        (Beast Awareness & Range Check)
                                         ▼
                           [Channel Completes Intact]
                                         │
                        (Roll Net Tier vs Quarry Rank)
                                         ▼
                          [Success: Virtual Snare Added]
                        (Live mob remains untouched in world!)
```

* 🌿 **Zero Kill Guilt & 100% Mob Preservation**: The live creature in the world remains **100% untouched, at full health, and un-tagged**.
* 🏹 **Hunter Coexistence**: A Hunter camping *Broken Tooth* or *Humar the Pridelord* can let an expedition researcher channel their net first. The researcher catalogs the companion into their Safari Bag, and the rare beast is still standing right there at 100% health for the Hunter to cast *Tame Beast*.
* 🎯 **Level-Agnostic Stalking**: High-level characters can stalk a Level 10 Duskbat without any risk of one-shotting it with auto-attacks or damage auras.
* 🔭 **Proximity & Stalking Radar**:
  * **Close Stalk (~10 yards)**: High risk, optimal focus granting a **+25% Catch Power Bonus** (`1.25x`).
  * **Standard Perimeter (15–28 yards)**: Safe stalking distance (`1.0x`).
  * **Beyond Perimeter (>28 yards)**: Out of range; close distance to begin channeling.
* ⏱️ **Channeling Minigame**: Channeling lasts 3.0–5.0 seconds based on net quality. Breaking line of sight or allowing the quarry to path beyond 28 yards interrupts the snare channel.

### 11. Catchable Creature Categories & Taxonomy
Forever Safari focuses purely on non-humanoid monsters, wild fauna, constructs, and legendary dungeon behemoths:

* 🐾 **Beasts**: The natural predators and fauna of Azeroth (Wolves, Bears, Nightsabers, Boars, Scorpids, Raptors, Spiders, Crocolisks, Kodos, Bats, Wind Serpents, Tallstriders, Crabs, Gorillas).
* 💀 **Mindless Undead & Specters**: Non-sapient reanimated vessels and spectral entities (Skeletons, Rotting Zombies, Decaying Ghouls, Phantoms, Ghosts, Skeletal Beasts, and Stitched Horrors).
* ⚡ **Elementals**: Living primal forces of Azeroth (Fire, Water, Earth, and Air Elementals, Tar Beasts, Living Oozes, and Magma Spawns).
* 🐲 **Dragon Whelps**: True draconic broods and hatchlings (Red, Black, Blue, Green, Bronze, and Plagued Whelps).
* ⚙️ **Mechanicals**: Clockwork wonders and engineering constructs (Harvest Watchers, Clockwork Gnomes, Homing Robots, Mechanical Chickens, and Prototype Shredders).
* 🐙 **Uncategorized & Dungeon Boss Behemoths**: Legendary wild monstrosities, hydras, deep sea terrors, and ancient horrors—such as the three-headed shadow hydra **Aku'mai** from Blackfathom Deeps.
* 🚫 **Prohibited**: Bipedal/sapient humanoids & civilized races (No Ogres, Kobolds, Troggs, Gnolls, Defias, Murlocs, Naga, Furbolgs, Quilboars, Centaurs, sentient Forsaken/Liches, or humanoid dragonkin sentinels).

---

## 🎮 Slash Commands

* `/safari` or `/fs` — Open the Forever Safari 3D Field Guide & Team Manager
* `/safari bounties` — View Active Field Directives & Quest Tracker (Tab 4)
* `/safari abandon` or `/safari release` — Release active companion back into the wild (with confirmation)
* `/fsbag` or `/safari bag` — Open the Virtual Safari Bag container
* `/fsmail` or `/safari mail` — Open Nesingwary Safari Correspondence (Turn in at Mailbox)
* `/fsshop` — Open Nesingwary Safari Supplies (Requires Pet Trainer or Innkeeper interaction)
* `/fsnet` — Throw selected safari net at target
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
├── README.md                          # Player & Architecture Manual
├── ROADMAP.md                         # Master Milestone Tracker
│
├── Data/
│   ├── CreatureDB.lua                 # 1,909 Normalized Species & 715 3D Displays
│   ├── MoveDB.lua                     # Move Database (Power, Accuracy, PP, Icons)
│   └── EvolutionDB.lua                # Metamorphosis Recipes & Boss Drops
│
├── Core/
│   ├── Constants.lua                  # Types, Elements, Attunement Ranks, Food
│   ├── Database.lua                   # Salted Signatures, Base64 DNA, Nicknames
│   ├── StatEngine.lua                 # Attunement Scaling, Disobedience, Stats
│   ├── CaptureEngine.lua              # Capture Rates, Net Modifiers, RNG Reticle
│   ├── BattleEngine.lua               # Turn-based Combat Loop, Cooldowns, Loot
│   ├── QuestHooks.lua                 # Boss Kills, Quest Hooks & Token Rewards
│   └── Comms.lua                      # P2P Multiplayer Sync & Chat Hyperlinks
│
└── UI/
    ├── Theme.lua                      # Nesingwary Safari Gold & Dark Theme Tokens
    ├── Toast.lua                      # Animated Reward & Capture Notifications
    ├── MinimapButton.lua              # Minimap Radar Icon & Coordinates Tooltip
    ├── SafariMailFrame.lua            # Mailbox Custom Tab & Quest Correspondence Hub
    ├── DispatchLetterFrame.lua        # Nesingwary Parchment First-Login Onboarding
    ├── InspectorFrame.lua             # 3D Paperdoll Popup for Chat Hyperlinks
    ├── CatalystLootFrame.lua          # Greed-Only Secondary Boss Loot Window
    ├── CaptureHUD.lua                 # Real-time Capture Probability HUD
    ├── ShopFrame.lua                  # Safari Supplies, Nets, and Consumables (Vendor Restricted)
    ├── SafariBagFrame.lua             # Virtual Safari Bag 20-Slot Authentic Container
    ├── JournalFrame.lua               # 3D Paperdoll Stage, Dossier, Gallery, Dock
    └── BattleFrame.lua                # Retro 3D Combat Arena & Command Menu
```

---

## 🏛️ World of Warcraft: Forever Beta Architecture Standards

Forever Safari is architected in 100% strict compliance with the **10 Commandments of WoW: Forever Beta (Build 69913/70009 / 16001 / Midnight 12.1.5 engine)**:

1. **`Interface: 16001`**: Multi-client compatible TOC with `16001` primary declaration for Forever Beta.
2. **Lua 5.1 Environment**: Zero prohibited keywords (`goto`, `//`, direct bitwise operators, `_ENV`, `require`, `dofile`, `loadfile`). Module loading handled strictly via `.toc`.
3. **Mainline 12.1.5 Engine**: Conforms to modern Mainline UI architecture, disarmament restrictions, and protected execution paths.
4. **`C_` Namespaces & Offline Data Integrity**: Fully decoupled from deprecated global APIs (`GetSpellInfo`, `GetItemInfo`), utilizing internal high-speed databases (`CreatureDB`, `MoveDB`, `EvolutionDB`, `Constants`).
5. **Namespace Isolation**: Every module starts with `local addonName, ns = ...` and attaches shared state directly to `ns`, preventing global namespace collision.
6. **Event-Driven Subsystems**: Zero `COMBAT_LOG_EVENT_UNFILTERED` registration. All game logic runs through clean high-level events (`ENCOUNTER_END`, `BOSS_KILL`, `QUEST_TURNED_IN`, `PLAYER_TARGET_CHANGED`, `UNIT_HEALTH`).
7. **Secret Value Protection**: All unit reads (`UnitHealth`, `UnitHealthMax`, `UnitLevel`, `UnitName`, `UnitReaction`, `UnitRace`) are guarded with `issecretvalue()` checks. Status bars draw raw unit health directly to prevent protected arithmetic blocking.
8. **Capability-Based Detection**: No naive `WOW_PROJECT_ID` branching; feature probes are used instead.
9. **Zero Secure-Snippet Dependency**: Operates solely with custom `UIPanelButtonTemplate` and standard frame events without `loadstring_untainted` or secure unit frame tainting.
10. **Deterministic Load Order & Persistence**: Modular TOC load sequence with comprehensive `ADDON_LOADED` SavedVariables initialization.

---

## 📜 License & Credits

Developed with passion for the **World of Warcraft: Forever Beta** community. Dedicated to the Nesingwary Junior Safari League!
