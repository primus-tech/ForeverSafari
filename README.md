# 🐾 Forever Safari
**The Premier Creature Taming, Battling & Evolution Addon for World of Warcraft: Forever Beta**

<p align="center">
  <img src="Media/ForeverSafari_Badge.jpg" alt="Forever Safari Official Badge" width="480"/>
</p>

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
> **Starter Partner Status (Rank III: Trusting)**: Your starting companion is a specially trained partner provided by Hemet Nesingwary and begins at **Rank III: Trusting** (600 Attunement Points) with full **1.00x True Baseline Stats (100/100 points)**, **5% Disobedience**, and **Slot 3 Unlocked for Training**. Wild beasts caught in the field with snares start at **Rank I: Wild / Unbroken** (0 Attunement, 0.85x stats, 15% disobedience) requiring bonding and feeding to domesticate.

---

## 🌟 Core Features

### 1. Modular 3D Field Guide Journal (`/fs`)
Deconstructed into decoupled, high-performance UI views and components:
* **View 1: 3D Squad Spotlight (`ROSTER`)**: A single-companion high-definition 3D pedestal stage featuring fluid 360° mouse drag rotation, zoom, instant animation triggers (`[ ⚔ Attack ]`, `[ 🦁 Roar ]`, `[ 🏆 Victory ]`, `[ 🐾 Idle ]`), real-time nickname editing, attunement gauge, stat radar, 4-move cards, and an interactive nourishment feeding tray.
* **View 2: 3D Menagerie Gallery (`GRID`)**: Browse your entire captured collection in a 6-card 3D paperdoll grid with 8-type filter ribbon, pagination, real-time HP bars, and squad leader toggles.
* **View 3: Azeroth Bestiary (`BESTIARY`)**: Complete 2,006-species field Pokédex tracking discoveries (`seen`, `caught`), 8-element filter menu, search box, live 3D species stage with animations, native habitats, base stats, Nesingwary lore notes, and natural family movepools.
* **View 4: Field Directives & Quest Log (`BOUNTIES`)**: Track active Nesingwary research directives, target objectives, kill/tame quotas, progress bars, and lore dossiers directly from the field.
* **Active Party Dock (`JournalTeamDock.lua`)**: Bottom 4-slot party dock with live mini 3D pedestals and health gauges.
* **Beast Training Grimoire Drawer (`JournalTrainingDrawer.lua`)**: Popout grimoire drawer for slot ability training and move customisation.

### 2. 2,006-Species Azeroth Bestiary (Authentic Field Pokédex)
A comprehensive, lore-accurate field catalog spanning all 2,008 world creature entities (2,006 unique species) across Classic Azeroth:
* 🐾 **Beasts**: Wolves, Cats, Bears, Boars, Raptors, Spiders, Crocolisks, Kodos, Bats, Wind Serpents, Scorpids, Hyenas, Tallstriders, Gorillas, Carrion Birds, Crabs, Turtles.
* ⚙️ **Mechanicals**: Harvest Watchers, Clockwork Gnomes, Mechano-Striders, Peacekeeper Units, Compact Harvesters.
* 💀 **Undead**: Plague Rats, Skittering Spiders, Scourge Ghouls, Ghost Claws, Spectral Wolves.
* 🌋 **Elementals**: Fire Elementals, Tar Elementals, Earth Rumbles, Water Elementals, Air Elementals.
* 🐉 **Dragonkin**: Whelps, Dragonhawks, Proto-Drakes, Fey Dragons.
* 🌊 **Aquatics**: Frenzies, Reef Crabs, River Crocolisks, Snapjaw Turtles.
* 🦅 **Flyers**: Owls, Vultures, Bats, Dragonhawks, Gryphons, Wind Serpents.
* ✨ **Magic**: Arcane Anomalies, Mana Wyrms, Sprite Darters.
*(Humanoids like Defias, Kobolds, Murlocs, and Centaurs are strictly **Rival AI Trainers**, never catchable companions).*

### 3. 5-Rank Attunement & Loyalty Progression (Replaces Numerical Leveling)
Companions progress through bonding, feeding, and battlefield survival rather than numerical XP grind:

| Rank | Title | Combat Behavior & Checks | Move Slots | Stat Mult | Metamorphosis |
| :---: | :--- | :--- | :--- | :--- :---: | :---: |
| **I** | **Wild / Unbroken** | 15% Disobedience chance (slips into wild turns, loafs, or hesitates). | **1** | **0.85x** | ❌ Destabilizes |
| **II** | **Tolerant** | 10% Disobedience chance. Basic orders execute cleanly. | **2** | **0.95x** | ❌ Destabilizes |
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
* **4-Role Ability Taxonomy Across All 94 Moves**:
  * ⚔️ **Offensive** (63 Moves): All direct damaging abilities (`power > 0`). In turn-based combat, advances the Druid Ecliptic Tides meter toward **Solar** power.
  * 🛡️ **Defensive** (8 Moves): Protective barriers, evasion, recovery, and shields (`Cower`, `Shell Shield`, `Frenzied Regeneration`, `Burrow`, `Prowl`, `Hardened Carapace`, `Stone Form`, `Barkskin`). Advances Ecliptic Tides toward **Lunar** power.
  * ⚠️ **Field Hazard** (11 Moves): Ground traps, debuffs, status effects, and control moves (`Screech`, `Faerie Fire`, `Web Wrap`, `Alarm Bark`, `Hyena Cackle`, `Slumbering Venom`, `Sticky Web`, `Spore Cloud`, `Intimidating Roar`, `Stun Needle`, `Dust Cloud`). Advances Ecliptic Tides toward **Lunar** power.
  * 🌦️ **Weather** (12 Moves): Atmospheric environmental shifts and domain conditions (`Rain Dance`, `Sunny Day`, `Sandstorm`, `Blizzard`, `Moonlight`, `Thunderstorm`, `Shadow Mist`, `Toxic Fog`, `Clear Skies`, `Nature's Wrath`, `Volcanic Ash`, `Arcane Winds`). Advances Ecliptic Tides toward **Lunar** power.

### 5. NPC Rival Battler Engine (Humanoids as AI Trainers)
* **Challenging Azeroth's Humanoids**: Targeting and challenging any roaming Humanoid mob across Azeroth (e.g. Defias Cutthroats, Kobold Miners, Murloc Tidecallers, Riverpaw Gnolls, Kolkar Centaurs, Scarlet Crusaders, Dark Iron Dwarves, Syndicate Rogues, Southsea Pirates, Bloodscalps, Ogres, Venture Co., Twilight Cultists, or Nesingwary Safari Trackers) initiates an **AI Trainer Battle** rather than a wild creature encounter.
* **14 Themed Faction Archetypes**: Each faction possesses a distinct title, immersive intro quote, defeat quote, token bounty payout, and a themed 1-to-3 companion roster scaling with level (Lv 1–15: 1 companion; Lv 16–35: 2 companions; Lv 36+: 3 companions).
* **AI Trainer Pet Switching**: When a trainer's active pet faints, they automatically send out their next companion from their bench with custom battle announcements.
* **Trainer Companion Protection**: Cages and snares cannot be thrown at trainer-owned pets (`"You cannot capture another hunter's companion!"`).
* **Safari Token Economy**: Roaming Humanoid AI Trainers are the primary open-world source of **Safari Tokens** (6–18+ tokens per victory, scaling with level and faction). Wild creature battles yield family nourishment diet items, attunement bonding, and quest progress, but do not drop tokens.

### 6. Normalized Base Stat Budgets (Largest Remainder Method) & Action-Gauge Combat
* **Zero-Drift Base Stat Budgets**:
  * **Standard Species & Bosses**: Exactly **100 base stat points** distributed across HP, Attack, Defense, and Speed using the Largest Remainder (Hamilton-Hare) algorithm.
  * **Rare & Apex Wild Species**: Exactly **110 base stat points** strictly reserved for authentic wild rare spawns (`classification in (2, 4)`). Dungeon and raid bosses remain at 100 to prevent boss stat creep.
* **Action-Gauge Speed Lapping (0–100 Meter)**: Replaces turn ping-pong with dynamic speed velocity. Reaching 100 meter triggers an action, allowing agile beasts to achieve 2:1 speed lapping over slower foes while enforcing speed scarcity.
* **5-Layer Elemental Resistances**: Universal 5% baseline + Native Element Affinities (+10%–15%) + Archetype traits + Attunement growth (+2%–10%) + Player Class Defenses.
* **2 Starting Abilities**: Every wild companion begins with exactly **2 starting moves** (Slot 1: Basic Attack, Slot 2: Defensive/Utility). Slots 3 & 4 unlock through higher Attunement Ranks.

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
    * **Tier 1 (Common)**: **Copper Snare** (`INV_Misc_Noose_01` — 1 Token, 35% Base Catch, Levels 1–15)
    * **Tier 2 (Uncommon)**: **Iron Safari Net** (`Hunter_PvP_TrackersNet` — 5 Tokens, 55% Base Catch, Levels 16–30)
    * **Tier 3 (Rare)**: **Mithril Hunter Trap** (`INV_Pet_PetTrap` — 10 Tokens, 75% Base Catch, Levels 31–45)
    * **Tier 4 (Epic)**: **Thorium Expedition Cage** (`INV_Box_Birdcage_01` — 25 Tokens, 98% Base Catch, Levels 46–60)
    * *Dynamics*: 50% HP pivot (1:1 penalty above 50% HP; 2:1 bonus below 50% HP), +25% per tier down / halved per tier up, -10% wild Rare resistance.
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

### 10. Town Logistics: Junior Safari League Gossip & Interaction Matrix
* **Zero Out-of-World Access & Zero Popup Intrusions**: Town interactions are unified directly under Blizzard's native dialogue, specialized world interaction, and banking frames. No popups or sidecars appear automatically; all services are accessed on demand.
* **Non-Service NPCs Remain Silent**: Interacting with generic NPCs across Azeroth (guards, vendors, flight masters, mayors) will never trigger addon popups or HUD elements.
* **🏨 Innkeepers (Healers & Recuperation Sanctuary)**:
  * **Opt-In Dialogue Option**: Speaking with an Innkeeper appends `Junior Safari League: Rest and Revive Squad` to Blizzard's native `GossipFrame`.
  * **Restoration**: Fully revives fainted companions, heals all squad and reserve companions to 100% HP, and plays the rest toast.
  * **Exclusive Sanctuary**: Innkeepers strictly handle squad recuperation and resting; they do not sell supplies or manage bank vaults.
* **🎯 Pet Trainers (Outfitters, Healers & Capital City Breeders)**:
  * **Accessible to ALL Classes**: Non-Hunter classes and Hunters alike can interact with town Pet Trainers.
  * **Junior Safari League: Visit Outfitter**: Opens the Nesingwary Safari Supplies shop (`/fsshop`) with Capture Gear, Transport Crates, Diets, and Medicine.
  * **Capital City Breeding**: Pet Trainers in capital cities host early-game companion breeding (offspring hatches at Rank I: Untamed).
  * **Squad Healing**: Also revives and restores wounded companions.
* **🏇 Stable Masters (Outpost Leaders & Regional Circuit)**:
  * **Specialized Interaction HUD**: Because Stable Masters on *WoW: Forever* terminate gossip sessions for non-Hunters via server-side class validation, Forever Safari uses a dedicated on-target specialized interaction HUD to challenge Outpost Leaders across regional circuits.
* **🌿 Cenarion Keepers in Moonglade (Sacred Sanctuary Breeders)**:
  * **Sacred Grove Nursery**: Custodians of the Sacred Grove in Moonglade (Nighthaven) accessed via gossip or `/fsnursery`, facilitating advanced endgame co-op breeding (offspring hatches at Rank III: Attuned).
* **🏦 Bankers (Kennelers & Companion Reserve)**:
  * **On-Demand Companion Vault**: Interacting with any town Banker provides access to the Junior Safari Reserve vault (`/fskennel`), managing active squad slots and 2,006 banked reserve slots across 101 enclosures (1 slot for every unique species under the Highlander Law).
* **Universal Gossip Row-Stacking Guarantee**:
  * On any NPC with gossip integration, Forever Safari dynamically evaluates all third-party addon rows on `GossipFrame.GreetingPanel` (e.g. Olympus's `Bones!: Teach me Bones`, Questie, etc.) and anchors directly beneath the lowest external row.
  * Forever Safari options are guaranteed to always be the bottom-most choices on screen with zero hardcoded strings or addon flags.

### 11. Party Battles, Virtual Duos & Pre-Battle Squad Designation
* **Disparity Compounding Party Scaling**:
  * Team and Virtual Duo encounters scale dynamically according to player party disparity: $\Delta = \max(0, \text{Players} - \text{NPCs})$.
  * For 2-NPC Virtual Duos: $\Delta = 0$ (1–2 players) = $1.0000\times$; $\Delta = 1$ (3 players) = $\mathbf{1.2500\times}$; $\Delta = 2$ (4 players) = $\mathbf{1.3750\times}$; $\Delta = 3$ (5 players, Duo Cap) = $\mathbf{1.4438\times}$ Max HP and damage.
* **The Cenarion Twins Virtual Duo (Jarund Stoutstrider & Layo Starstrike)**:
  * Stationed at Cenarion Hold in Silithus, fielding a coordinated 8-companion joint roster (Spirit Wolf, War Kodo, Thunder Lizard, Ancients, Nightsaber, Lunar Owl, Sprite Darter).
  * Every companion strictly conforms to the **100-Point Base Stat Budget Law** with verified DBC display IDs.
* **Dual-Line Druid Ecliptic Meter**:
  * Single HUD displaying Jarund's Solar energy (☀️) and Layo's Lunar energy (🌙). At 5 charges, unleashes *Solar Bloom* (+12% Max HP squad HoT) or *Lunar Brambles* (40% thorns reflection). Both can be active simultaneously.
* **Sympathetic Buffing & 50% Sympathetic Healing**:
  * Beneficial buffs and defensive shields (*Barkskin Aegis*, *Static Jolt*, *Thick Hide*) cast by either Twin immediately mirror across both active companions of the Twins.
  * When either pet heals through a primary or secondary effect (direct heal, leech/drain, regeneration HoT), 50% of that healing is sympathetically shared to the other active companion.
  * Shared defensive buffs decrement only once every 2 enemy turns (`duoTurnCounter % 2 == 0`).
* **15-Second Action Timeout**:
  * Animated countdown bar above dialogue console. If 15 seconds expire without player input, Move 1 is automatically fired to maintain battle velocity.
* **Pre-Battle Squad Designation**:
  * Interactive checkboxes on `ForeverSafariPlayerParty` allow players to designate which companions enter combat before the battle starts.
  * **Squad Quotas**: 4–5 players = 2 pets; 3 players = 3 pets; 1–2 players = 4 pets.
  * Locks permanently on turn 1 (`combatStarted = true`); benched pets cannot enter combat.
* **Boss AoE Cleave**:
  * Primary target takes full damage; collateral cleave strikes all conscious reserve companions for 50% base power, mitigated through each companion's own defense and resistance ratings.

### 12. Real Quest Token Grants, Retroactive Compensation & Companion Bonding
* **Real Quest Completion Rewards**: Turning in quests across Azeroth (`QUEST_TURNED_IN`) directly rewards the player with **Safari Tokens** calculated as **1/10 of the quest level, rounded up** (`math.ceil(QuestLevel / 10)`), minimum 1 Token.
  * *Examples*: Lv.1–10 = **+1 Token**; Lv.11–20 = **+2 Tokens**; Lv.21–30 = **+3 Tokens**; Lv.31–40 = **+4 Tokens**; Lv.41–50 = **+5 Tokens**; Lv.51–60 = **+6 Tokens**; Lv.61–70 = **+7 Tokens**; Lv.71–80 = **+8 Tokens**.
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

### 15. Player Class Passives & Combat Mechanics
* **Authentic Class Synergy**: Every player class grants an authentic tactical identity and defense layer scaled dynamically to active companion Attunement Rank (I–V) using strict `math.ceil()` arithmetic.
* **Static Slices (Permanent Innate Defenses)**:
  * 🛡️ **Warrior (Marshal's Tenacity)**: **+5% per Rank** Physical Damage Reduction (**5%** at Rank I $\to$ **25%** at Rank V).
  * 🗡️ **Rogue (Shadow Evasion)**: **+5% per Rank** Dodge Chance (**5%** at Rank I $\to$ **25%** at Rank V), synergizing with Cunning's +5% Dodge for up to **30% total Dodge Chance**.
  * 🏹 **Hunter (Aspect of the Beastmaster)**: **+25% Attunement Accrual** and **+25% Capture Chance** (multiplicative). Companion also gains **+5% per Rank** Nature Resistance (**5%** at Rank I $\to$ **25%** at Rank V).
  * 🍃 **Druid (Gift of the Wild & Ecliptic Tides)**: **+2% per Rank** Pure Static Omni-Resist across all 6 magic schools (**2%** at Rank I $\to$ **10%** at Rank V) plus the active **Ecliptic Tides** celestial pendulum (Solar cleanse/HoT and Lunar Brambles damage reflection).
* **Procced Wards (Mystic Reactive Elemental Absorption)**:
  * Trigger: **5% per Rank proc chance** (5%–25%) to absorb **10% per Rank damage** (10%–50%) on incoming strikes.
  * **Per-Tick DoT Evaluation**: Wards roll **independently on every periodic DoT tick** (resisting tick 1, taking full damage on tick 2, etc.).
  * 🔮 **Mage (Arcane Ward & Chilling Tempo)**: Arcane/Fire/Frost Ward + Chilling Tempo (5% off / 10% def chill proc countering speed) proportionally reduced by target Frost Resistance % (e.g. 50% frost resist lowers a 50% proc chance to 25%).
  * ⚡ **Shaman (Elemental Shielding & Primal Rebirth)**: Fire/Frost/Nature Ward + `RollAnkh()` flat 50% chance to resurrect companion once per battle.
  * 💀 **Warlock (Fel Infusion & Curse of Suppression)**: Shadow/Fire Ward + 50% suppression of opposed passives in duels/battles.
  * 🕊️ **Priest (Ward of the Heavens & Divine Grace)**: Shadow/Holy Ward + active `[Divine Grace]` emergency heal console button restoring 25% Max HP.
  * ⚔️ **Paladin (Aegis of Light & Aura of Light)**: Physical/Holy Ward + 5%–25% damage-to-healing conversion.

### 16. Tiered Companion Breeding & Co-op Genetics Program
* **Tiered Breeding Sanctuaries**:
  * **Capital City Nurseries (Pet Trainers)**: Available immediately across Stormwind, Orgrimmar, Ironforge, Thunder Bluff, Darnassus, and Undercity. Offspring hatches at **Rank I: Untamed** (0 Attunement points).
  * **Sacred Grove Sanctuary (Cenarion Keepers)**: Gated at the Sacred Grove in Moonglade (Nighthaven) via NPC gossip or `/fsnursery`. Offspring hatches at **Rank III: Attuned** (100 base stat points, 0% disobedience, immediate battle readiness).
* **Biological Designation**: Every companion possesses a signed biological designation: **Sire (♂)** or **Dam (♀)** (50/50 distribution).
* **Breeding Rules**:
  * 1. Exact Same Family (purebred lineage).
  * 2. Both candidates must be Rank V (Bestial Symbiosis / 1000 Loyalty).
  * 3. Compatible pairing: Exactly 1x Sire (♂) and 1x Dam (♀).
* **The Ultimate Sacrifice**: Both parent candidates are **PERMANENTLY consumed** from the player vault to merge life forces.
* **Egg Yield & Bonus Roll**:
  * Guaranteed: 1 purebred Safari Egg (`safari_egg_<family>`) to each trainer deposited into `/fsbag`.
  * Lucky Clutch: Exactly a **20% flat chance** to produce a 3rd bonus egg (50/50 roll between trainers in co-op).
* **Incubation**: Right-click any egg in `/fsbag` to hatch a newborn purebred companion with superior inherited IVs!

---

## 🎮 Slash Commands

* `/fs` — Open the Forever Safari 3D Field Guide & Squad Manager
* `/fs bag` (or `/fsbag`) — Open the Virtual Safari Bag container
* `/fs kennel` (or `/fskennel`) — Open the Safari Kennel (Requires Banker interaction)
* `/fs shop` (or `/fsshop`) — Open Nesingwary Safari Outfitter (Requires Pet Trainer interaction)
* `/fs mail` (or `/fsmail`) — Open Nesingwary Safari Correspondence (Turn in at Mailbox)
* `/fs nursery` (or `/fsnursery`, `/fsbreed`) — Open Moonglade Cenarion Breeding Nursery
* `/fs bounties` — View Active Field Directives & Quest Tracker (Tab 4)
* `/fs observe` (or `/fsnet`) — Channel field observation to stalk target and discover new moves
* `/fs battle` (or `/fsbattle`) — Engage targeted creature in turn-based combat
* `/fs duel [target]` (or `/fsduel`) — Challenge targeted player to a companion duel
* `/fs war` (or `/fswar`) — Raid Territory War commands (`setnode`, `setbase`, `start`, `stop`, `bridge`)
* `/fs tokens` — Check your current Safari Token balance
* `/fs taint` (or `/fstaint`) — Run live Blizzard UI taint diagnostics on gossip, bags, and secure frames
* `/fs abandon` (or `/fs release`) — Release active companion back into the wild (with confirmation)
* `/fs reset` — Reset all progress back to a fresh new recruit
* `/fs benchmark` — Profile cryptographic persistence and vault deserialization

---

## 🛠️ Project Structure

```
ForeverSafari/
├── ForeverSafari.toc                  # Addon Manifest (WoW Forever Beta 1.60.1)
├── ForeverSafari.lua                  # Main Addon Bootstrap & Slash Commands
├── README.md                          # Comprehensive Documentation & Architecture Manual
├── MANUAL.md                          # Official Player Field Guide
├── ROADMAP.md                         # Master Milestone & Feature Tracker
├── Truth.md                           # Canonical Constraints, Platform Truths & NPC Roles
├── Docs/                              # Deep-Dive System Design Documentation
│   ├── COMBAT_ENGINE_STATS_AND_MECHANICS.md # Core Combat Engine, Budgets & Mechanics
│   ├── SAFARI_OUTPOST_SYSTEM.md       # Regional Outposts, Virtual Duos & Neutral Orders
│   ├── HUNTER_TAXONOMY_AND_OBSERVATION.md   # Spec Archetypes, Move Siloing & Observation
│   ├── MOVE_CATEGORIZATION.md         # 18-Node Ability Taxonomy & Delivery Mechanics
│   ├── BREEDING_SYSTEM_AND_GENETICS.md# Co-op Breeding, Genetic Seeds & Sanctuaries
│   └── DATA_PIPELINE_AND_TAXONOMY.md  # Open-World vs Instance Pup Drops & Taxonomy
│
├── Data/                              # Canonical Data Registries
│   ├── ItemDB.lua                     # Snares, Traps, Cages, Crates, 11 Diets, Eggs & Consumables
│   ├── MoveDB.lua                     # 94 Moves (Feral Druid, Utility, Boss Signatures)
│   ├── CreatureDB.lua                 # 2,008 Master World Creature Entities across 35 Partitions
│   ├── BestiaryDB.lua                 # 2,006 Unique Species Bestiary Pokédex across 9 Families
│   ├── EvolutionDB.lua                # Metamorphosis Recipes & Boss Drops
│   └── TrainerDB.lua                  # 14 Humanoid Rival Factions, Quotes & Rosters
│
├── Core/                              # Core Engine & Subsystem Logic
│   ├── Constants.lua                  # Types, Elements, Attunement Ranks, Diets, Crates
│   ├── ClassPassives.lua              # 9 Player Class Tactical Passives (math.ceil)
│   ├── Crypto.lua                     # HMAC-SHA1 DNA Signatures & Anatomy Validation
│   ├── Database.lua                   # Core Initialization, Signatures, DNA & Settings
│   ├── DB/                            # Domain-Specific Database Sub-Modules
│   │   ├── DB_Pets.lua                # Companion CRUD, Active Party & Nicknames
│   │   ├── DB_Kennel.lua              # Storage Enclosure Boxes & Crate Logistics
│   │   ├── DB_Bestiary.lua            # Pokédex Discovery & Progress Tracking
│   │   └── DB_Inventory.lua           # Token Vault & Virtual Bag Management
│   ├── StatEngine.lua                 # Attunement Scaling, 100/110 Budget & Stat Engine
│   ├── TrainerEngine.lua              # Roaming Humanoid NPC AI Trainer Battle Matcher
│   ├── CaptureEngine.lua              # Capture Formulas, Catch Rates & Crate Logistics
│   ├── BattleCapture.lua              # In-Battle Trap Throwing & Capture Logic
│   ├── BattleEngine.lua               # Turn-Based Combat Loop, Passives, AI Trainers
│   ├── QuestHooks.lua                 # Boss Kills, Quest Hooks & Token Rewards
│   └── Comms.lua                      # P2P Multiplayer Sync, Nursery Protocol & Links
│
└── UI/                                # User Interface & Views
    ├── Theme.lua                      # Nesingwary Safari Gold & Dark Theme Tokens
    ├── Toast.lua                      # Animated Reward & Capture Notifications
    ├── MinimapButton.lua              # Minimap Radar Icon & Coordinates Tooltip
    ├── SafariMailFrame.lua            # Mailbox Custom Tab & Quest Correspondence Hub
    ├── DispatchLetterFrame.lua        # Nesingwary Parchment First-Login Onboarding
    ├── NurseryFrame.lua               # Moonglade Cenarion Nursery Breeding Sanctuary
    ├── InspectorFrame.lua             # 3D Paperdoll Popup for Chat Hyperlinks
    ├── CatalystLootFrame.lua          # Greed-Only Secondary Boss Loot Window
    ├── CaptureHUD.lua                 # Real-Time Proximity & Move Discovery HUD
    ├── ShopFrame.lua                  # Pet Trainer Outfitter (Tabs & Below-Card Layout)
    ├── KennelFrame.lua                # Banker Companion Vault (4 Squad + 2,006 Slots in 101 Enclosures)
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
        ├── JournalBestiaryView.lua    # View 3: 2,006-Species Azeroth Bestiary Pokédex
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
