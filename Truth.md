# Truth

## 1. Platform & Runtime Architecture
We are programming for **WoW: Forever**.

* **The Core Mental Model: "Blizzard's Turtle WoW"**:
  - The single clearest way to understand **WoW: Forever** is: **Think of WoW: Forever as Blizzard's official Turtle WoW.**
  - Just as Turtle WoW took original Azeroth and expanded it horizontally with new playable races (High Elves, Goblins), new landmasses/zones (Alah'Thalas, Tel'Abim, Lapidis Isle), and new dungeons rather than invalidating old content with vertical expansions, Blizzard is officially doing the exact same thing on their own servers with **WoW: Forever**.
  - It is **not** a generic rerun of 2004 Classic, **not** a disposable seasonal experiment (like Season of Discovery), and **not** a vertical gear-treadmill expansion. It is a permanent, evolving alternate branch of Vanilla Azeroth.
* **Official New Content is Canon (CRITICAL)**: **WoW: Forever** introduces brand new official playable races, zones, ecology, and storylines woven directly into the classic timeline.
  - Examples include the **Sky Elves**, the island zone of **Zephras**, and new regional creature species.
  - **NEVER** discard, alter, or flag official WoW: Forever races, zones, or creatures as "made-up" or "fabricated". They are authentic Blizzard beta canon and must be preserved with full fidelity.
* **The Engine & API Runtime (CRITICAL)**: **WoW: Forever runs on the Modern Retail WoW Engine (`dataEnv: 16`, API 11.x/12.x)**.
  - While the world and gameplay philosophy are Vanilla+, the underlying software is Blizzard's modern Retail client engine.
  - Under no circumstances should legacy 1.12 APIs, obsolete Classic snippets, or deprecated frame methods be introduced into this codebase. All Lua code must target modern Retail client standards (e.g. `C_TooltipInfo`, modern `PlayerModel` bounding-box perspective, `:AtBottom()`, and secret-value taint isolation).
* **Data Ecology & Active Beta Awareness**: Because WoW: Forever is an active Blizzard Beta, legacy third-party databases (such as static 2004/2019 Classic sites) do not represent the full picture of this game. New beta zones, races, and creature models coexist with classic content; do not assume old vanilla databases are the sole authority over live WoW: Forever beta data.
* **100% Client-Side Minigame Architecture (CRITICAL)**:
  * **Zero Server-Side Authority**: *Forever Safari* is entirely an in-client addon minigame. There is **no** custom game server, **no** backend database, and **no** Blizzard server-side C++ logic. Blizzard's servers do not recognize Safari pets, Attunement, or Safari battles.
  * **Complete Local Simulation**: 100% of gameplay—combat calculations, turns, AI decision trees, capture RNG, breeding inheritance, and dispatch progression—executes strictly within the player's local Lua environment.
  * **Virtual Items & Virtual Inventory**: Safari items (nets, snares, cages, food/treats, salves, revival crystals, catalysts, tokens, and research license specimens) are **completely virtual**. They do **not** occupy real Blizzard character inventory bags and possess no real Blizzard item IDs. All safari goods exist solely within the addon's virtual Safari Bag (`/fsbag`, `ItemDB.lua`, `state.inventory`).
  * **Persistence is Purely `SavedVariables`**: All pet collections, levels, kennels, and licenses reside exclusively in the client's `SavedVariables` tables (`ForeverSafariDB`, `ForeverSafariKennel`, `ForeverSafariVault`) written to the user's `WTF` directory.
  * **Multiplayer & PvP via P2P Addon Messaging**: Duels and co-op breeding do not run on server instances; they synchronize directly between players using Blizzard's addon chat channels (`C_ChatInfo.SendAddOnMessage`).
  * **World Interactivity via Client Overlays**: We cannot command the server to spawn custom mobs or inject server-authoritative dialogue. All interactions hook client-side unit events (`PLAYER_TARGET_CHANGED`, `GOSSIP_SHOW`, `NAME_PLATE_UNIT_ADDED`) and render custom HUDs and 3D overlays on top of authentic world entities.

---

## 2. Core Protocol: Zero "Off-Roading", Agent Conduct & Execution Guardrails
* **No Unsolicited Design Alterations**: Never modify, add to, or second-guess the gameplay loops, quest objectives, mechanics, or vision defined by the Lead Developer.
* **Zero "Creative Liberties"**: Do not "improve", expand, or alter a quest or mechanic on your own initiative (e.g. changing an observation task into a capture task). If a quest is defined as **Observe**, it is strictly **Observe**.
* **Direct Execution Only**: Implement exactly what is asked. Do not assume you know better than the developer. Unapproved "off-roading" breaks player trust, compromises live releases on platforms like CurseForge, and introduces severe game-breaking regressions.
* **Verify Scope Before Touching**: If a change feels necessary, ask explicitly first. Never write unsolicited gameplay or design changes directly into the codebase.
* **Direct Answers First (No Rabbit-Holes)**: When asked a direct question about numbers, stats, formulas, or mechanics, answer the question directly and immediately. Do not launch multi-file search runs for peripheral trivia before answering what was asked.
* **Mandatory Truth Re-Read Before Execution**: Before running shell commands, editing files, or writing code, re-read `Truth.md` every single time to guarantee zero off-roading, zero architectural drift, and absolute adherence to modern Retail standards.
* **Context Window Alerts**: Immediately inform the developer whenever the context window is growing excessively large, when a context compaction has taken place, or when earlier conversation trajectory has been truncated.

---

## 3. Canonical NPC Roles in Forever Safari
In *Forever Safari*, NPCs have strict, dedicated roles within our minigame ecosystem. No generic fallbacks, no accidental cross-contamination with class trainers, guards, flight masters, or profession trainers.

| NPC Archetype | In-Game Subtitle | Forever Safari Role | Description |
| :--- | :--- | :--- | :--- |
| **Pet Trainers** | `<Pet Trainer>` | **Outfitters, Healers & City Breeders** | Primary merchants for safari equipment, nets, crates, and provisions; provide squad healing and recovery; and host **early-game biological companion breeding in Capital Cities** (offspring hatches at Rank I: Untamed). |
| **Innkeepers** | `<Innkeeper>` | **Healers** | Merely healers. Dedicated squad rest, recovery, and revival stations across towns and taverns. |
| **Bankers** | `<Banker>` | **Kennelers** | The custodians of the Companion Reserve. Grant access to long-term pet storage, enclosures, and squad swapping. |
| **Stable Masters** | `<Stable Master>` | **Outpost Leaders** | The regional guides, outpost masters, and challenge leaders who test trainers in official Safari League battles (accessed via specialized HUD). |
| **Cenarion Keepers** | `<Cenarion Keeper>` | **Sacred Sanctuary Breeders** | Custodians of the Sacred Grove in Moonglade. Facilitate advanced endgame co-op breeding rituals (offspring hatches at Rank III: Attuned). |
| **Master Tinkers** | `<Engineering Trainer>` / `<Tinker>` | **Construct Combobulators** | Engineers in Booty Bay, Ironforge (Tinker Town), and Orgrimmar (Goblin Slums). Summoned via the specialized Pop-Up HUD to open the **Combobulation Interface** for mechanical chassis assembly and catalyst move modularization. |

### NPC AI Battle Trainers: Strict Home-Zone Invariant
All humanoid AI rival trainers (faction encounters like Defias, Syndicate, Dark Iron, roaming safari rivals, and outpost leaders) **must strictly draw their battle companions from their home zone's native ecology**.
* **Zero Cross-Zone Contamination**: A trainer engaged in **Westfall** must strictly field Westfall-native species (*Coyote*, *Greater Fleshripper*, *Harvest Golem*, *Goretusk*, *Shore Crawler*).
* A trainer engaged in **Elwynn Forest** must field Elwynn-native species (*Young Wolf*, *Mangy Wolf*, *Stonetusk Boar*, *Forest Spider*).
* A trainer engaged on **Zephras Isle** must field Zephras-native species (*Vuldren*, *Ornery Galestrider*, *Urs'anah*, *Slydris*).
* AI trainers are local wilderness combatants; they never summon beasts from distant lands or unrelated biomes.
* ⚡ **The Plaguelands Continuum (WPL & EPL Unified Biome)**: Western Plaguelands (Zone 28) and Eastern Plaguelands (Zone 139) are treated as **one continuous macro-biome** for companion sourcing. Holy human defenders (Scarlet Crusade in Tyr's Hand/Hearthglen, Argent Dawn at Light's Hope) would *never* field rotting Scourge horrors or plagued beasts; they legitimately source living bears, warhounds, eagles, and wolves from surviving WPL ecology. Scourge Cultists and Necromancers draw strictly from blighted Undead pools.

### AI Trainer Battler Identity Priority Hierarchy
When generating an AI trainer match, the engine evaluates the target through a strict 3-tier cascade:
1. 🧬 **Race-Based Identity (Primary)**: Root humanoid race (*Centaur*, *Quilboar*, *Harpy*, *Goblin*, *Dwarf*, *Murloc*, *Trogg*, etc.) sets base dialogue, combat quotes, and innate pet family sympathies (e.g. Harpy ➔ avians; Quilboar ➔ boars).
2. 🗺️ **Location-Based Grounding (Secondary)**: Physical location (*active zone or unified macro-biome*) enforces the hard ecological boundary. Wildlife is drawn strictly from indigenous species cataloged for that area.
3. ⚔️ **Faction-Based Modifier (Tertiary - Lore or Actual)**: Organization or clan (*Venture Co.*, *Scarlet Crusade*, *Defias*, *Syndicate*, *Cult of the Damned*) overlays technological gear (mechanical harvesters), ideological invariants (holy ban on undead), or trained war beasts.
* **Target-As-Trainer Invariant**: The trainer's name is always `UnitName("target")`. Synthetic titles (*"Defias Outlaw"*, *"Kobold Prospector"*) are strictly prohibited.

---

## 4. Exclusion Rules
* **Guards & Sentries:** Have no gameplay function in *Forever Safari*. Any directional dialogue pointing to an inn or bank must never trigger safari interactions.
* **Flight Masters:** Have no gameplay function in *Forever Safari*.
* **Class Trainers (including Hunter Trainers):** Have no connection to *Forever Safari*.
* **Profession Trainers (Blacksmiths, Tailors, etc.):** Have no connection to *Forever Safari* (except designated Master Tinkers/Engineers who host Combobulation).
* **Dungeons, Raids & Battlegrounds (`IsInInstance()`):** Turn-based Safari combat UI, challenge overlays, and Safari Net captures are **strictly disabled**. In-instance acquisition relies exclusively on passive, virtual **Random Pup Drops (`PUP_DROP`)** on boss and elite mob kills.
* **Humanoids (`type: 7`) & Sentient Undead (`type: 6`):** Strictly AI Battle Trainer opponents and safari rivals. They can **never** be targeted with a Safari Net, obtained as companion pup drops, or kept as pets in a player's squad, kennel, or breeding nursery.
* **Mechanical Constructs (`type: 9`):** Synthetic constructs cannot be placed into biological breeding chambers, cannot mate, and **never lay eggs**. They are processed exclusively through Tinker Combobulation.
* **Purely Aquatic Water-Bound Swimmers:** Physically water-locked swimming fauna (**Threshers**, **Sharks**, **Frenzy Fish**, **Eels**) are **strictly excluded from taming and capture**. All Safari battles occur on dry land; finned swimming creatures cannot participate in land battles. Amphibious wildlife with terrestrial locomotion (**Crabs**, **Crocolisks**, **Turtles**) remain fully capturable.

---

## 5. Stable Master & Tinker Interaction: The Specialized HUD
* **Server-Side Class Check:** In WoW: Forever, **Stable Masters do not offer gossip options to non-Hunters**. The server checks the player's class immediately upon interaction and terminates the gossip session if the player is not a Hunter.
* **The Specialized HUD Requirement:** Because native Blizzard Gossip cannot be used by non-Hunters at Stable Masters (and cannot support advanced mechanical assembly at Tinkers), **Forever Safari uses our specialized HUD** (targeting / world interaction HUD):
  - Stable Masters: Opens the Outpost Battle & Regional Challenge Interface.
  - Master Tinkers: Opens the **Combobulation Interface** for mechanical calibration and catalyst move installation.
  - Native gossip injection is never relied upon for Outpost challenges or Tinker Combobulation.

---

## 6. Biological Sanctuaries vs. Master Tinker Combobulation
Reproduction and re-forging availability is tiered and categorized by companion nature:

| Sanctuary / Workshop | NPC Host | Access Method | Offspring / Product | Gameplay Advantage |
| :--- | :--- | :--- | :---: | :--- |
| **Capital City Nurseries** | `<Pet Trainer>` | Native Gossip | **Rank I Egg (Untamed)** *(0 Points)* | Convenient biological breeding for Beasts & Dragonkin. Offspring must be trained up from baseline. |
| **Sacred Grove Sanctuary** | `<Cenarion Keeper>` | Native Gossip | **Rank III Egg / Mote (Attuned)** *(100 Points)* | **Sacred Rebirth**: Biological Beasts, Dragonkin, and synthesized Elemental motes hatch at 0% disobedience. |
| **Tinker Combobulation Works** | `<Tinker>` / `<Engineering Trainer>` | **Pop-Up HUD** | **Assembled Chassis Blueprint** *(Zero Eggs)* | **Modular Tech**: Assembles construct frames; socketing dungeon Catalysts installs modular elemental abilities (SFK Shadow, Gnomeregan Cryo-Coolant). |

---

## 7. The "King of the Hill" Naming Principle
* **Authentic Beast Names:** Companions never receive synthetic "Starter" prefixes attached to their names (e.g. **no** `"Starter Mangy Wolf"`).
* **True Champions from Day One:** An initial bonded companion is an authentic wild beast of Azeroth (**"Mangy Wolf"**, **"Young Black Bear"**, **"Crag Boar"**, **"Young Nightsaber"**). Players can nurture and climb all the way to the top of the Safari League with their very first companion.

---

## 8. Codebase Integrity, Technical Invariants & Prohibited APIs

### Straightforward Architecture
* **No Aliases, No Shims**: We do not write aliases, compatibility shims, proxy tables, wrapper polyfills, or indirect bridge layers.
* **Direct & Explicit**: Code must be direct and unambiguous. If a function or table exists, it has a single canonical name and implementation.

### 3D Paperdoll Models (`PlayerModel`) Invariants
* ⛔ **STRICTLY PROHIBITED: `SetCustomCamera(0)` and `SetPortraitZoom()`**:
  - In Blizzard's M2 model system, **Camera 0 is hardcoded for 2D circular unit-frame headshot portraits**. It anchors point-blank to the skull/jawbone.
  - Calling `SetCustomCamera(0)` locks the camera onto the face at extreme close-up. Rotating the model then swings the head out of frame, cutting off the entire body and displaying only tails, hindquarters, or a mouth full of teeth.
  - **NEVER** call `SetCustomCamera(0)` or `SetPortraitZoom()` anywhere in this addon.
* ✅ **MANDATED: Engine Bounding-Box Perspective**:
  - Full-body 3D models (Arena, Journal Spotlight, Gallery Grid, Inspection) rely solely on canonical `:SetDisplayInfo(displayId)` or `:SetCreature(npcId)`.
  - The modern Retail client automatically calculates the model's bounding sphere and places the perspective camera to cleanly frame the whole beast centered on its pedestal.
* **Rotation**: Use canonical `:SetRotation(radians)` consistently. In battle, player faces diagonally toward enemy (`math.rad(45)`), enemy faces diagonally toward player (`math.rad(-35)`).
* **Zooming**: Use `:SetModelScale(scale)` or `:SetCamDistanceScale(scale)`.

### ScrollingMessageFrame Invariants
* ⛔ **DO NOT USE `:IsAtBottom()`**: Does not exist in modern Retail.
* ✅ **USE `:AtBottom()` and `:ScrollToBottom()`**: Canonical modern scrolling API.

### SavedVariables Lifecycle & Persistence
* ⛔ **NEVER WIPE ON LOGOUT**: Never write `ForeverSafariDB = nil` or overwrite saved tables in `PLAYER_LOGOUT` or reload events.
* ✅ **AUTHORITATIVE PERSISTENCE**: `ForeverSafariDB`, `ForeverSafariKennel`, and `ForeverSafariVault` are authoritative and must cleanly persist across sessions, reloads, and character swaps.

---

## 9. Virtual Duo Outposts, Party Scaling & Pre-Battle Squad Designation
* **Virtual Duo Encounter Architecture (The Cenarion Twins):**
  * Exemplified by **Jarund Stoutstrider & Layo Starstrike** at Cenarion Hold in Silithus.
  * Virtual Duos field a joint roster (e.g. 8 authentic companions total, 4 per Twin) and command active pets under coordinated AI.
* **Disparity Compounding Party Scaling:**
  * Scaling multiplier is calculated from group disparity: $\Delta = \max(0, \text{Players} - \text{NPCs})$.
  * For Duo battles (2 NPCs):
    * $\Delta = 0$ (1–2 Players): $1.0000\times$ (No disparity bonus).
    * $\Delta = 1$ (3 Players): $+25\% \rightarrow \mathbf{1.2500\times}$ max HP & offensive power.
    * $\Delta = 2$ (4 Players): $+10\% \rightarrow \mathbf{1.3750\times}$ max HP & offensive power.
    * $\Delta = 3$ (5 Players, Duo Cap): $+5\% \rightarrow \mathbf{1.4438\times}$ max HP & offensive power.
* **100-Point Budget Law & Authentic Templates:**
  * All companions across Outpost Virtual Teams and Duos adhere to verified Blizzard creature templates, authentic DBC display IDs, and strict 100-point base stat distribution.
* **Sympathetic Buffing & 50% Sympathetic Healing:**
  * **Sympathetic Buffing**: All beneficial buffs, stat amplifiers, and defensive shields (*Barkskin Aegis*, *Static Jolt*, *Thick Hide*) cast by either Twin's active pet instantly replicate across both active companions of the Twins.
  * **50% Sympathetic Healing**: When either Twin's companion heals through a primary effect (direct heal, Spectral Mend) or secondary effect (drain/leech, periodic HoT), exactly 50% of that healing is sympathetically shared to the other active companion.
* **Dual-Line Druid Ecliptic Meter:**
  * Rather than competing on a single scalar, Jarund drives Solar energy (☀️) and Layo drives Lunar energy (🌙). Both can accumulate independently, and both *Solar Bloom* (squad HoT) and *Lunar Brambles* (thorns reflection) can be active simultaneously.
* **Cycle-Based Buff Ticking:**
  * Shared Twins buffs decrement only when a full timeline cycle elapses (every 2 enemy turns) so agile pets do not exhaust team buffs prematurely.
* **15-Second Turn Timeout:**
  * A 15-second countdown timer governs player turns. If expired without action, Move 1 is automatically executed to keep combat fluid.
* **Pre-Battle Squad Designation:**
  * Players designate which companions from their 5-pet party enter battle using slot checkboxes prior to the first action.
  * Squad capacity quota enforces tactical balance based on group size:
    * 4–5 Players: **2 Pets**
    * 3 Players: **3 Pets**
    * 1–2 Players: **4 Pets**
  * Checkboxes lock permanently upon initiating combat; benched companions cannot enter battle or be swapped in.
* **Boss AoE Cleave:**
  * Boss-tier AoE cleaves strike the active primary target for full damage and hit all conscious reserve party companions for 50% collateral damage, evaluated against each individual pet's defense and resistances.

---

## 10. Research Licenses, Dungeon Boss Specimen Drops & Mailbox Dispatch
* **Authentic RPG Quest Loop (No Magic Auto-Unlocks):**
  * Slaying dungeon bosses (Crowd Pummeler 9-60, Lord Incendius, Baron Rivendare, Shade of Eranikus) does **not** silently auto-unlock creature categories in the background.
  * Instead, the boss drops an authentic physical specimen directly into the player's virtual Safari Bag (`/fsbag`):
    * ⚙️ **Grinded Gears** (`quest_grinded_gears`) $\rightarrow$ Mechanical
    * 🌋 **Puddle of Mud** (`quest_puddle_mud`) $\rightarrow$ Elemental
    * 💀 **Cold Bones** (`quest_cold_bones`) $\rightarrow$ Undead
    * 🐉 **Poisonous Scales** (`quest_poisonous_scales`) $\rightarrow$ Dragonkin
* **Town Mailbox Delivery to Hemet Nesingwary:**
  * To certify a Research Permit, players must visit any physical town mailbox in an inn or capital city, open the `[Safari]` tab, and click **`[ 📦 DISPATCH SPECIMEN & CLAIM LICENSE ]`**.
  * The specimen is safely dispatched to Hemet Nesingwary, who returns an official certified license, permanently unlocks stalking/capture for that creature family, and awards **50 Safari Tokens** plus field supplies.

---

## 11. Progressive Dispatch Directives & Quest Flow
The League's mailbox correspondence unfolds sequentially to ensure recruits build their naturalistic skills organically:

1. **Dispatch #1: Welcome to the Safari League!**
   - *Sender*: Hemet Nesingwary Sr.
   - *Action*: Unbox initial starter companion (**Rank I: Wild / Untamed**, 0 points, 1 active move slot), 10 Copper Snares, 3 Transport Crates, 5 Healing Salves, and 1 Revival Crystal.
2. **Dispatch #2: Field Observation 101 (STRICTLY OBSERVE ONLY)**
   - *Sender*: Hemet Nesingwary Sr.
   - *Objective*: Study 3 wild creatures in their natural habitat using the field research lens / binoculars.
   - ⛔ **NO CAPTURES**: True naturalists do not immediately obliterate or snare wildlife. This directive is 100% non-invasive field study.
   - *Reward*: +20 Safari Tokens, 3 Iron Cages, 2 Safari Treats. Unlocks Dispatch #3.
3. **Dispatch #3: The First Snare (First Capture)**
   - *Sender*: Hemet Nesingwary Jr.
   - *Objective*: Track down, engage, and successfully capture 1 wild creature in the open world using a Safari Net or Snare.
   - *Reward*: +20 Safari Tokens, 3 Transport Crates, 3 Healing Salves. Unlocks Dispatch #4.
4. **Dispatch #4: Field Care & Recovery (Heal Your Pet)**
   - *Sender*: Barnil Stonepot.
   - *Objective*: Tend to an injured companion by restoring its health using a Healing Salve, Pet Bandage, or visiting an Innkeeper / Pet Trainer.
   - *Reward*: +25 Safari Tokens, 5 Healing Salves, 1 Revival Crystal. Unlocks Dispatch #5.
5. **Dispatch #5: The Wild Nourishment**
   - *Sender*: Barnil Stonepot.
   - *Objective*: Feed companion twice with preferred family diets or Safari Treats to build Attunement.
   - *Reward*: +25 Safari Tokens, 1 Feast, 3 Healing Salves. Unlocks Dispatch #6.
6. **Dispatch #6: Sighting of Apex Rares**
   - *Sender*: Hemet Nesingwary Jr.
   - *Objective*: Track down and catalog an authentic rare apex beast in the wild.
   - *Reward*: +40 Safari Tokens, 2 Mithril Cages, 2 Feasts. Unlocks Dispatch #7.
7. **Dispatch #7: Deep Dungeon Expedition**
   - *Sender*: Ajeck Rouack.
   - *Objective*: Slay a dungeon boss with an expedition party to recover an Evolution Catalyst.
   - *Reward*: +50 Safari Tokens, 1 Arcanite Capsule, 3 Feasts. Unlocks Permit Directives (#8–#11).

---

## 12. The 3D Field Guide Badges Cabinet (Tab 5)
* Tab 5 (`[BADGES]`) provides a permanent trophy showcase in the Safari Journal:
  * **Top Shelf**: 4 large ornate Research License plaques (locked darkened brass vs. certified gold).
  * **Velvet Grid**: Scrollable showcase of all 54 Regional Outpost Badges with unearned mystery silhouettes and earned victory timestamps/defeat quotes.
  * **Live Tally**: Real-time progress tracking (`Badges Collected: X / 54 (Y%)`).

---

## 13. Attunement & Loyalty Progression vs. Traditional Leveling
* ⛔ **NO TRADITIONAL 1–60 LEVELING**: Companions in *Forever Safari* do **not** gain standard character levels (1–60) or experience points. There are no level-up dings or arbitrary stat inflations.
* ✅ **THE 5-RANK ATTUNEMENT & LOYALTY SYSTEM**: Progression is driven purely by building Attunement with your companions:

| Rank | Roman | Loyalty Title | Min Points | Max Points | Stat Mult | Disobedience | Active Move Slots | Key Perks |
| :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **1** | **I** | **Wild / Unbroken** | 0 | 250 | **0.85x** | **15%** | **1 Slot** | Baseline wild state. **Starter companions begin here (0 Points, Wild / Untamed)**. High disobedience in battle. |
| **2** | **II** | **Rebellious** | 250 | 600 | **0.90x** | **10%** | **2 Slots** | Second ability slot unlocked. |
| **3** | **III** | **Trusting** | 600 | 1,200 | **1.00x** | **5%** | **3 Slots** | **True Baseline Stats** (Zero stat penalties/bonuses). Third ability slot unlocked. |
| **4** | **IV** | **Devoted** | 1,200 | 2,500 | **1.10x** | **0%** | **4 Slots** | Full 4-ability movepool unlocked. 100% obedience guaranteed. |
| **5** | **V** | **Apex Companion** | 2,500 | 2,500 | **1.25x** | **0%** | **4 Slots** | Maximum power threshold. Enables **Rank V Metamorphosis** evolution via dungeon catalysts. |

---

## 14. Global Stat Law: The 100-Point Budget & Creature Type Scaling
* **The 100-Point Universal Budget**:
  * Every standard wild creature distributes **exactly 100 raw base points** across its 4 core attributes: `{ hp, atk, def, spd }`.
  * Rare and Elite species distribute **110 raw base points** (or receive an `eliteMod = 1.20x`).
* **Creature Type Multipliers (Family Scaling)**:
  * Raw base stats are multiplied by the creature's native **Creature Type** (`C.CREATURE_TYPES`):
    * **Beast**: `hp: 1.05x`, `atk: 1.15x`, `def: 0.95x`, `spd: 1.15x` (+10% Nature Resist, *Enrage* passive).
    * **Aquatic**: `hp: 1.15x`, `atk: 1.00x`, `def: 1.05x`, `spd: 1.00x` (+10% Frost Resist, -50% DoT duration).
    * **Dragonkin**: `hp: 1.20x`, `atk: 1.25x`, `def: 1.15x`, `spd: 0.90x` (+5% Omni-Magic Resist, *Draconic Fury*).
    * **Elemental**: `hp: 0.95x`, `atk: 1.20x`, `def: 0.95x`, `spd: 1.05x` (Weather/debuff immunity).
    * **Flying**: `hp: 0.90x`, `atk: 1.10x`, `def: 0.85x`, `spd: 1.45x` (+50% SPD when above 50% HP).
    * **Magic**: `hp: 1.00x`, `atk: 1.20x`, `def: 1.00x`, `spd: 0.95x` (Cannot take >35% max HP in one hit).
    * **Mechanical**: `hp: 1.10x`, `atk: 1.05x`, `def: 1.25x`, `spd: 0.85x` (+15% Phys/-5% Nat, 1x 20% Reboot).
    * **Undead**: `hp: 1.20x`, `atk: 1.00x`, `def: 0.90x`, `spd: 0.85x` (+15% Shad/-5% Holy, 1 round Immortality).
* **Sub-Family Role (Canine, Wolf, Bear, Boar, etc.)**:
  * Sub-families grant **zero direct numerical stat bonuses**.
  * Sub-families strictly determine: **Movepool trees** (which moves can be learned/unlocked), **Diet preferences**, and **Metamorphosis branching**.

---

## 15. Wild World Encounters, Observation & 120s Real-Combat Suspension
* **Authentic World Targets**: Safari encounters do not spawn synthetic dummy NPCs. Players interact directly with genuine wild Blizzard world creatures by targeting them.
* **Non-Invasive Field Study (Binoculars / Lens)**: Channelling observation studies creatures without engaging in combat or pulling threat.
* **120-Second Real-Combat Suspension (`C.BATTLE_COMBAT_PAUSE_TIMEOUT`)**:
  * Safari battles are client-side turn-based duels. If an unrelated world mob aggros the player during a battle, or if the player dies and must corpse-run, the Safari battle **automatically suspends for up to 120 seconds**.
  * The match state remains frozen in memory until the player leaves real WoW combat, allowing them to resume seamlessly without losing their companion or battle progress.

---

## 16. Universal Diet Matrix & Attunement Feeding
Companions build Attunement points outside of combat through nutritious virtual feeding (`ItemDB.FAMILY_DIETS`):
* **Favorite Diet Item**: **+25 Attunement Points** (e.g. *Safari Meat* for Canines/Wolves/Felines, *Safari Fish* for Bears/Aquatic, *Safari Fungus* for Boars/Spiders).
* **Accepted Diet Item**: **+15 Attunement Points** (secondary compatible food categories).
* **Safari Treats**: **+50 Attunement Points** (universal treat accepted by all living species).
* **Safari Feast**: **+100 Attunement Points** (grand universal banquet for instant squad attunement).
