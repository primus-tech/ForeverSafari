# 🐾 How We Get Our Creatures, and Keeping Them Real
**The Canonical Ingestion Pipeline, Taxonomy Framework & Zero-Fabrication Governance for WoW: Forever**

---

## 1. Core Philosophy: Keeping Them Real

### The "Zero-Fabrication" Invariant
Every creature in *Forever Safari* must trace directly to authentic game data in **World of Warcraft: Forever**.
* ⛔ **NO INVENTED PLACEHOLDER CREATURES**: Non-canon names like *"Prairie Hawk"*, *"Prowler Wolf"*, and *"River Snapjaw"* that do not exist anywhere in World of Warcraft are strictly forbidden. Hand-authoring mock names pollutes the ecosystem and destroys immersion.
* ⛔ **NO ZONE ECOLOGY MISMATCHES**: Real mobs must remain in their authentic habitat. For example, **Mangy Wolf** is an authentic WoW mob (NPC ID 525 in Elwynn Forest, Zone 12, and the Human starter companion), but it should not be randomly placed into Westfall where native Coyotes and Prairie Wolves reside.
* ⛔ **NO DUMMY DISPLAY ID COPY-PASTES**: Models must never be filled with arbitrary numbers. Specifically, `displayId = 1629` (Mountaineer Gravelgaw, an Ironforge Dwarf) must never appear on beasts, birds, or tallstriders. Every creature model must match its true 3D model in the game engine.
* 🎯 **THE DUAL-IDENTIFIER INVARIANT (`npcId` + `displayId`)**:
  - In World of Warcraft, the NPC Template ID (`npcId`) defines server identity, name, and level, but the **`CreatureDisplayInfoID` (`displayId`)** is the **only identifier that controls the 3D model, textures, and geometry** rendered by `PlayerModel:SetDisplayInfo(displayId)`.
  - A creature entry with only an `npcId` is fundamentally incomplete: without `displayId`, the 3D Arena, Journal Spotlight, and Nursery cannot render the beast.
  - Every creature cataloged in *Forever Safari* must possess both its authentic `npcId` and its verified 3D `displayId`. Zero headless or invisible models.
* 🛡️ **STRICT HOME-ZONE INDEXING FOR NPC AI BATTLE TRAINERS**:
  - NPC AI Battle Trainers (roaming safari rivals, faction encounters like Defias/Scarlet/Dark Iron, and regional challengers) **must ALWAYS index companion creatures from their home zone**.
  - A trainer fought in **Westfall** must strictly field Westfall-native species (*Coyote*, *Greater Fleshripper*, *Harvest Golem*, *Goretusk*, *Shore Crawler*).
  - A trainer fought in **Elwynn Forest** must strictly field Elwynn-native species (*Young Wolf*, *Mangy Wolf*, *Stonetusk Boar*, *Forest Spider*).
  - A trainer fought on **Zephras Isle** must strictly field Zephras-native species (*Vuldren*, *Ornery Galestrider*, *Urs'anah*, *Slydris*).
  - Trainers are local wilderness survivalists and combatants; their squads must authentically mirror the territorial ecology of the ground they stand upon.
  - ⚡ **THE PLAGUELANDS CONTINUUM CAVEAT (WPL & EPL UNIFIED BIOME)**:
    - **Western Plaguelands (Zone 28)** and **Eastern Plaguelands (Zone 139)** are treated as **one unified macro-biome** for creature sourcing.
    - **Faction Lore & Holy Alignment Invariant**: The defenders of **Light's Hope Chapel (Argent Dawn)** and the zealots of **Tyr's Hand / Hearthglen (Scarlet Crusade)** would *never* fight alongside rotting Scourge horrors, plagued bats, or skeletal vermin. Because open-world EPL wildlife is heavily blighted by the Scourge, living human factions in EPL authentically source their companion beasts, warhounds, eagles, bears, and spiders from the surviving living ecology of WPL and the Tirisfal/Hearthglen borderlands.
    - Conversely, Scourge Necromancers, Cultists, and Deathguards across both zones draw strictly from the blighted Undead and Plagued beast pools.
* ✅ **BLIZZARD'S TURTLE WOW IS CANON**: WoW: Forever is Blizzard's official, living Vanilla+. Brand new official content—such as **Sky Elves**, **Zephras Isle**, **Riverglades**, **Gilneas**, **Karazhan Crypts**, and newly introduced regional beasts (e.g. *Mystmane*, *Vuldren*, *Urs'anah*)—is 100% official canon. We do not discard or question new beta content; we catalog it with full fidelity.

---

## 2. Zone Ecology: Standalone Sufficiency vs. Macro-Biome Linkage

### The "Capturable Density Principle" (The Rule-Filtered Pool)
Zones are **standalone by default**. An artificial zone merger is never performed merely because two zones share a border. Instead, whether a zone requires a macro-biome linkage is dictated by the **capturable creature count within the zone AFTER being templated against faction and ideological rules**.

* ✅ **The Standalone Sufficiency Benchmark (e.g. Tirisfal Glades)**:
  * In **Tirisfal Glades (Zone 85)**, both Forsaken and Scarlet Monastery crusaders have ample authentic wildlife natively present:
    * *Forsaken*: Tirisfal Bats, Greater Duskbats, Mangy Duskhounds, Night Web Spiders, Vile Fin Murlocs.
    * *Scarlet Crusaders*: Monastery hounds, crag coyotes, and forest vermin.
  * Because the rule-filtered capturable pool in Tirisfal is already dense, diverse, and self-sufficient, **Tirisfal Glades stands strictly on its own**. It does not borrow from WPL, Silverpine, or anywhere else.
* ⚡ **The Alignment Deprivation Exception (e.g. EPL & WPL)**:
  * In **Eastern Plaguelands (Zone 139)**, the raw mob count is high, but 95%+ of native wildlife is blighted, skeletal, or infected by the Scourge (Plagued Bats, Carrion Grubs, Plagued Swine).
  * For Scourge Cultists and Necromancers, EPL is self-sufficient.
  * **However**, holy human defenders (**Argent Dawn** at Light's Hope Chapel and **Scarlet Crusade** at Tyr's Hand) strictly obey the **Holy Alignment Invariant: ZERO Undead or Scourge-coded creatures**.
  * When this rule is applied to EPL, their available living companion pool drops to near zero. Therefore, and *only* therefore, living holy factions in EPL expand their sourcing pool into **Western Plaguelands (Zone 28)** and Hearthglen borderlands to recruit uncorrupted bears, warhounds, eagles, and spiders.

---

### Macro-Biomes & Regional Ecology Pairings (Qualified Roster)
A macro-biome linkage is established **only** under two conditions:
1. **Alignment Deprivation**: An indigenous faction's moral/lore rules eliminate the local fauna (e.g. Holy defenders in EPL).
2. **Contiguous Basin & Migrating Herds**: A singular, unbroken terrain where apex herds, wildlife, and nomad clans naturally roam across borders (e.g. Central Kalimdor savanna).

The qualified regional linkages are:

### 1. The Plaguelands Continuum *(Western Plaguelands [28] & Eastern Plaguelands [139])*
* **Geographic Connection**: A continuous blighted landscape divided only by the Thondroril River.
* **Faction & Morality Rule**: Holy human defenders (**Scarlet Crusade** at Tyr's Hand/Hearthglen and **Argent Dawn** at Light's Hope Chapel/Chillwind) *never* field rotting Scourge horrors or plagued vermin. Because open-world EPL is heavily blighted, living human factions in EPL legitimately source their companion beasts, warhounds, eagles, bears, and spiders from the surviving living ecology of WPL and the Hearthglen borderlands.
* **Scourge Factions**: Cultists, Necromancers, and Deathguards across both zones draw strictly from the blighted Undead and plague beast pools.

### 2. The Blackrock Caldera *(Searing Gorge [51] & Burning Steppes [46])*
* **Geographic Connection**: Brackets Blackrock Mountain to the north and south.
* **Shared Factions**: **Dark Iron Dwarves**, **Thorium Brotherhood**, and **Blackrock Orcs** move constantly through the mountain passes between both sides.
* **Shared Ecology**: Volcanic fauna—lava spiders, fire/lava elementals, scorpids, and ash-drakes. A Dark Iron engineer or Thorium smith in either zone draws from this shared volcanic pool.

### 3. The Lordaeron Foothills *(Hillsbrad Foothills [267] & Alterac Mountains [36])*
* **Geographic Connection**: Alterac's snowy crags rise directly from the northern pastures of Hillsbrad.
* **Shared Factions**: The **Syndicate** operates out of both zones simultaneously (Durnholde Keep in Hillsbrad; Strahnbrad and ruined manors in Alterac).
* **Shared Ecology**: Alpine and forest predators—mountain lions / cougars, brown bears, and highland raptors. A Syndicate Conspirator or hill bandit draws from this shared alpine pool.

### 4. The Central Kalimdor Savannah & Plains Basin *(Mulgore [215], The Barrens [17], & Durotar [14])*
* **Geographic Connection**: A vast, unbroken grassland and savanna basin linked by the Southfury River bridge to the east and the Camp Taurajo / Great Gate pass into Mulgore to the west.
* **Shared Herds & Ecology**:
  * **Kodos**: Indigenous herds roaming naturally between the lush grasslands of Mulgore and the arid central/southern Barrens plains.
  * **Tallstriders & Plainstriders**: Prairie Striders (Mulgore) and Plainstriders (The Barrens) sharing the expansive savanna.
  * **Prairie Wolves, Cougars & Savannah Hyenas**: Apex predators hunting across the contiguous plains.
* **Shared Factions & Indigenous Clans**:
  * **Quilboars (Bristleback & Razormane)**: Thorn ravines and bramble dens spanning eastern Mulgore, western Durotar, and the Barrens.
  * **Centaurs (Kolkar, Galak, Palemane)**: Nomad warbands contesting watering holes across the entire basin.
  * **Tauren & Orcish Huntsmen**: Indigenous tribes who range freely across the grasslands tracking game.

### 5. The Corrupted Kaldorei Canopy *(Felwood [361] & Northern Ashenvale [331])*
* **Geographic Connection**: Demonic corruption bled south from Jaedenar down into northern Ashenvale (Bloodvenom Falls, Satyrnaar, Night Run).
* **Shared Factions**: **Satyrs**, **Shadow Council Cultists**, and the **Timbermaw Furbolgs** bridging the mountain tunnels.
* **Shared Ecology**: Corrupted wolves, felhounds/felstalkers, diseased bears, and venomous spiders. Corrupted cultists and satyrs in northern Ashenvale summon the same tainted beasts found across Felwood.

### 6. The Southern Shifting Frontier *(Tanaris [440] & Un'Goro Crater [490])*
* **Geographic Connection**: Linked directly via the southern pass behind Thistleshrub Valley.
* **Shared Factions**: Silithid hives (Noxious Lair dunes connect directly down into the Slithering Scar) and goblin desert/jungle expedition outfits.
* **Shared Ecology**: Basilisks, scorpids, and silithid insects.

### 7. The Greymane Borderlands *(Gilneas [17065], Ruins of Gilneas [16756], & Southern Silverpine [130])*
* **Geographic Connection**: An active borderland in WoW: Forever where the Greymane Wall meets the Blackwald and Pyrewood forest.
* **Shared Factions**: Moonrage worgen, Gilnean survivalists, and Shadowfang outcasts.
* **Shared Ecology**: Feral wolves/hounds, giant forest spiders, black bears, and river frenzy fish.

---

## 3. The Target-As-Trainer Overlay Architecture
Rather than authoring synthetic NPC titles, static encounter rosters, or one-off scripted opponents, *Forever Safari* uses the **Target-As-Trainer Overlay**. Any targetable humanoid NPC in the 3D world automatically becomes an active Safari League competitor.

This system is built upon **Three Core Tenets**:

---

### Tenet 1: Use Target Name (`UnitName("target")`)
* **Universal Humanoid Target Overlay**: Every humanoid NPC across World of Warcraft—hostile, neutral, or friendly—can be engaged as an AI battle opponent. The engine captures `UnitName("target")` directly.
* **Strict Ban on Spiffy or Fabricated Titles**:
  * ⛔ **NO INVENTED IDENTITIES**: Titles like *"Defias Outlaw"*, *"Kobold Prospector"*, *"Murloc Tidecaller"*, *"Riverpaw Packleader"*, *"Voodoo Beastmaster"*, or *"Scarlet Kennelmaster"* are strictly prohibited.
  * ✅ **AUTHENTIC WORLD NAMES**: The target's exact in-game mob name is displayed directly across challenge prompts, encounter frames, battle logs, and defeat screens:
    * Targeting a `"Defias Highwayman"` in Westfall ➔ Trainer is **"Defias Highwayman"**.
    * Targeting a `"Venture Co. Geologist"` in Sludge Fen ➔ Trainer is **"Venture Co. Geologist"**.
    * Targeting a `"Kolkar Bloodcharger"` in the Barrens ➔ Trainer is **"Kolkar Bloodcharger"**.
    * Targeting a `"Bael'dun Excavator"` in southern Barrens ➔ Trainer is **"Bael'dun Excavator"**.
    * Targeting a `"Witchwing Slayer"` in the Charred Vale ➔ Trainer is **"Witchwing Slayer"**.
    * Targeting a `"Razormane Geomancer"` in Mulgore borderlands ➔ Trainer is **"Razormane Geomancer"**.
    * Targeting a `"Scarlet Centurion"` in Hearthglen ➔ Trainer is **"Scarlet Centurion"**.
    * Targeting a `"Southsea Freebooter"` in Tanaris ➔ Trainer is **"Southsea Freebooter"**.
* **Seamless Immersion**: By using Blizzard's authentic NPC names, the player feels like they are challenging the actual denizens of Azeroth, not a fictional mini-game clone.

---

### Tenet 2: Create Zone Creature Pool & Identity Priority Hierarchy
When constructing an AI trainer encounter, the engine resolves the NPC's identity, personality, and creature squad preferences through a strict **Three-Tier Priority Hierarchy**:

```
[1. RACE-BASED] ──> Sets intrinsic behavioral template & pet family sympathies
       │
[2. LOCATION-BASED] ──> Anchors hard ecological boundary (native zone/macro-biome pool)
       │
[3. FACTION-BASED] ──> Overlays lore/actual faction rules, gear & ideological filters
```

#### Priority 1: Race-Based Identity (Primary Baseline)
* **Innate Archetype**: Derived from the target's humanoid race (e.g., *Centaur*, *Quilboar*, *Harpy*, *Gnoll*, *Murloc*, *Kobold*, *Trogg*, *Furbolg*, *Goblin*, *Dwarf*, *Orc*, *Human*, *Tauren*, *Night Elf*, *Undead*, *Troll*).
* **Technical Parsing Invariant (WoW API Limitation)**:
  * Because native `UnitRace("target")` returns `nil` for non-player NPCs in World of Warcraft, the engine resolves race dynamically via **Target Name & Clan Keywords** (e.g. `Kolkar`/`Galak`/`Gelkis` ➔ Centaur; `Bristleback`/`Razormane` ➔ Quilboar; `Witchwing`/`Bloodfury` ➔ Harpy; `Bael'dun`/`Ironforge` ➔ Dwarf; `Sludge Fen`/`Steamwheedle` ➔ Goblin) supplemented by NPC display checks.
* **Intrinsic Sympathies & Voice**: Establishes the trainer's baseline dialogue style, combat quotes, and natural affinity for specific creature types:
  * *Centaur* ➔ Plains runners, herd grazers, wind serpents.
  * *Quilboar* ➔ Swill-tusk boars, bramble spiders, earth elementals.
  * *Harpy* ➔ Birds of prey, carrion vultures, high-altitude avians.
  * *Goblin* ➔ Mechanicals, rodents, nuisance burrowers.
  * *Dwarf* ➔ Mountain bears, cave beasts, stone elementals.
  * *Murloc* ➔ Shore crabs, frenzy fish, crocolisks, sea crawlers.
  * *Gnoll / Trogg* ➔ Wild hyenas, pack wolves, subterranean creepers.
* **Dialogue Quote Cascade**:
  * The Race template provides default Intro and Defeat quotes (e.g. Centaur battle cries, Murloc gargles).
  * If a target matches a specific Faction (Priority 3), the Faction's creed/battle cry takes precedence (e.g. Scarlet Crusade: *"By the Holy Light, cleanse these beasts!"*). Generic unaligned mobs use the race's natural dialogue.

#### Priority 2: Location-Based Grounding (Hard Ecological Boundary)
* **Physical Habitat**: Where the NPC physically stands grounds the candidate creature pool strictly to the **active zone or unified macro-biome**.
* **Zero Cross-Zone Contamination**: A Centaur in the Barrens draws strictly from Barrens fauna; a Centaur in Desolace draws strictly from Desolace scrub fauna; a Dwarf in Dun Morogh draws from Dun Morogh alpine snow beasts, while a Dwarf in Searing Gorge draws from volcanic fauna.
* The physical location provides the uncompromising boundary of what wildlife can spawn—guaranteeing 100% ecological fidelity.

#### Priority 3: Faction-Based Modifier (Lore or Actual Faction)
* **Ideological & Technological Refinement**: The mob's organization (whether an actual Blizzard reputation faction or a lore faction inferred from name and outpost) applies thematic overlays, specialized hardware, or strict ideological rules on top of the race and location:
  * **Venture Co. (Lore Faction)**: Overlays industrial constructs (harvesters, clockwork shredders) and exploitation pests onto local geography, regardless of base race.
  * **Scarlet Crusade & Argent Dawn (Actual Factions)**: Imposes the **Holy Alignment Invariant**—strictly zero Undead or Plagued beasts, sourcing living hounds and bears across the Plaguelands continuum.
  * **Defias Brotherhood (Lore Faction)**: Overlays harvest golems and trained guard coyotes onto Westfall/Elwynn farmland ecology.
  * **Syndicate (Lore Faction)**: Overlays trained mountain cougars and highland raptors onto Hillsbrad/Alterac terrain.
  * **Cult of the Damned / Scourge (Actual & Lore Factions)**: Overlays blighted, skeletal, and plague-ridden horrors over local species.
* **Graceful Fallback Guarantee**: If a specialized faction or racial filter yields fewer valid candidates in a specific zone than needed for a full team, the engine seamlessly falls back to the zone's wider native beast pool. It **never fails** to generate a match, and **never invents** an out-of-zone creature.

---

### Tenet 3: Randomize Selection at Runtime
* **Zero-Static Encounter Squads**:
  * No two battles against the same mob type are identical. Selection is dynamically evaluated at the instant the battle initiates (`GenerateTrainerMatch("target")`).
  * Fighting three consecutive Defias Highwaymen in Westfall will produce three distinct, unpredictably composed squads drawn from the Westfall pool.
* **Runtime Team Generation Algorithm**:
  1. **Squad Sizing via Target Level**:
     * **Level 1–15**: 1 Companion *(Solo Scout / Vanguard)*
     * **Level 16–35**: 2 Companions *(Duo Squad)*
     * **Level 36+**: 3 Companions *(Full Triad / Champion Team)*
  2. **Random Sampling Without Replacement**:
     * The engine draws `N` distinct species from the qualified zone pool using Lua's `math.random`.
     * No duplicate species are assigned to the same team unless the qualified local pool has fewer than `N` total species.
  3. **Dynamic Attunement & Level Scaling**:
     * Companion Attunement Rank (Tier I through Tier V) scales to match `UnitLevel("target")`:
       * Level 1–15 ➔ **Rank I (Untamed)**
       * Level 16–35 ➔ **Rank II (Trained)**
       * Level 36–45 ➔ **Rank III (Attuned)**
       * Level 46–55 ➔ **Rank IV (Exalted)**
       * Level 56–60+ ➔ **Rank V (Ascended)**
     * Combat stats (HP, Attack, Defense, Speed) are computed dynamically via `StatEngine:CalculateStats()` using the creature's canonical base stats and level-scaled rank points.
  4. **Moveset Resolution**:
     * Creatures receive 2 to 4 canonical abilities appropriate to their element/family and the battle tier (2 moves for Tier I–II, 3 moves for Tier III, 4 moves for Tier IV–V).
* **High Replayability & Emergent Strategy**:
  * Players cannot simply memorize a static guide to breeze through open-world encounters. Each battle demands real-time tactical adaptation to the randomly rolled composition.

---

## 4. Creature Families & Scope

Forever Safari structures the fauna and entities of Azeroth across **5 primary creature families**:

### A. Beasts & Subfamily Taxonomy
To bypass Wowhead's 1,000-entity listview truncation, beasts are indexed through granular, authentic subfamilies:
* **The Core Beast Subfamilies**:
  * **Tenacity (Tanks & High Armor)**: Bear, Boar, Crab, Crocolisk, Gorilla, Scorpid, Turtle, and **Scalehide** (unifying Kodos, Thunder Lizards, and Stegodons).
  * **Ferocity (Strikers & DPS)**: Carrion Bird, Cat, Hyena, Raptor, Tallstrider, Wind Serpent, Wolf, and **Hydra** (distinct apex multi-headed predators, e.g. Gahz'rilla, Gesharahan).
  * **Cunning (Disrupters & Control)**: Bat, Bird of Prey, Spider.
* **Scalehide Unification**:
  * Rather than fragmenting heavy reptilian quadrupeds, **Kodos**, **Thunder Lizards**, and **Stegodons** are consolidated under the canonical **Scalehide** subfamily (`scalehide`), sharing armor-plated Tenacity mechanics.
* **Hydras as a Distinct Family**:
  * **Hydras** (`hydra`) are treated as their own distinct apex family with multi-strike abilities and poison/acid mechanics, rather than being discarded or crammed into generic lizards.

### B. Other Core Companion Families
* **Dragonkin** (`npcs=2`): Drakes, Whelps, Broodlings, Faerie Dragons.
* **Elementals** (`npcs=4`): Spirits, Sparks, Cores, Motes.
* **Mechanicals** (`npcs=9`): Harvest Golems, Clockwork Bots, Micro-Mechs (governed by Tinker Combobulation; strictly no eggs).

### C. The Purely Aquatic Exclusion Invariant (No Water-Bound Swimmers)
* ⛔ **Purely Aquatic Swimmers Are STRICTLY UNTAMABLE**:
  * Creatures that are physically water-bound and lack limbs for dry-land locomotion—specifically **Threshers**, **Sharks**, **Frenzy Fish**, and **Giant Eels**—are **strictly untamable and excluded from Safari capture**.
  * *Design Rationale*: All Safari battles occur in dry-land arenas, town outposts, and open-world wilderness trails. Having a finned, swimming thresher or shark flopping around on the dry dirt of Durotar or the Barrens breaks immersion and is fundamentally nonsensical.
  * **Amphibious Wildlife Permitted**: Marine and aquatic creatures that possess natural legs or terrestrial mobility (**Crabs**, **Crocolisks**, and **Turtles**) are fully supported as valid land-walking companion species.

### D. The Competitor Invariant: Humanoids & Sentient Undead are Strictly Rival Trainers
* **Humanoids (`type: 7`) and Sentient Undead (`type: 6`) are strictly AI Battle Trainers and Opponents**:
  * Every humanoid (Defias, Venture Co., Centaurs, Quilboar, Syndicate, Scarlet) AND every sentient undead mob (Skeletons, Ghouls, Zombies, Wraiths, Banshees, Necromancers, Deathknights, Liches) exists to challenge the player as an AI battle competitor.
* ⛔ **NO CAPTURABLE HUMANOIDS OR ROTTING CORPSES**:
  * Humanoids and sentient undead can never be targeted with a Safari Net, awarded as pup drops, traded, or added to a player's squad or kennel.
  * You cannot capture a sentient decaying corpse and place it in a capital city nursery or Moonglade sacred grove.
* 🐾 **Where do "Undead Beasts" live?**:
  * Animalistic Scourge fauna (*Plagued Wolf*, *Plagued Bear*, *Plagued Bat*, *Plagued Swine*, *Ghost Saber*, *Carrion Grub*) are categorized under their authentic **Beast Subfamilies** (Wolves, Bears, Bats, Boars, Cats, Worms).
  * They receive an `Undead` or `Shadow` **elemental typing**, preserving biological taxonomy while allowing dark/blighted abilities.
* All bonded companions in *Forever Safari* belong exclusively to the 4 non-humanoid creature families: **Beasts, Dragonkin, Elementals, and Mechanicals**.

---

## 5. Acquisition Architecture: Open World vs. Instances

Not every creature is encountered or obtained the same way. We enforce a strict environmental separation of mechanics:

| Zone Type | Acquisition Method | Safari Battle? | Safari Net Capture? | Field Observation? | How It Is Acquired |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Open World** | `BATTLE` | ✅ Yes | ✅ Yes | ✅ Yes (Unlocks Moves 3 & 4) | Direct wild turn-based combat and capture. |
| **Dungeons / Raids / BGs** | `PUP_DROP` | ⛔ **STRICTLY NO** | ⛔ **STRICTLY NO** | ⛔ **STRICTLY NO** | Slaying instance mobs procs a companion **Pup / Offspring Drop** directly into inventory. |

### The Instance Non-Combat Invariant
* ⛔ **NO SAFARI BATTLES IN INSTANCES OR RAIDS**: Turn-based Safari combat UI, challenge overlays, and Safari Net captures are **strictly disabled inside all Dungeons, Raids, and Battlegrounds** (`IsInInstance()`).
  * *Design Rationale*: Players inside instances are actively engaged in real-time group PvE combat (threat, tanking, healing, boss mechanics). Popping up a turn-based minigame window or stopping to net an add would disrupt group coordination and wipe parties.
* 🎲 **Instance Acquisition Relies Exclusively on Random Dropping (`PUP_DROP`)**:
  * Slaying dungeon and raid bosses or elite trash procs a virtual **Companion Pup / Offspring Drop** directly into the player's virtual Safari inventory and Kennel.
  * **Boss & Elite Procs**: Dungeon and raid bosses possess designated drop tables for rare, exotic, and legendary offspring (e.g., Deadmines mine spider/parrot pups, Wailing Caverns viper/raptor hatchlings, Shadowfang Keep lupine pups, Scarlet Monastery warhound pups, Molten Core core hound pups, Onyxian whelplings).
  * **Zero Real-Time Disruption**: Instance pup drops register passively via loot procs and trigger a congratulatory HUD toast notification (`Toast.lua`) with zero interruption to active dungeon combat.

---

## 6. The Dual Zone Census Ingestion Pipeline (How We Get Them)

Rather than maintaining separate, disconnected databases or guessing at zone populations, *Forever Safari* uses the **Dual Zone Census Architecture**. For every zone in World of Warcraft, we ingest both:
1. **The Capturable Wildlife Census** (Beasts [1], Dragonkin [2], Elementals [4], Mechanicals [9])
2. **The AI Battle Trainer Census** (Humanoids [7], Sentient Undead [6])

This creates an airtight, 100% complete catalog of both the **combatants** and the **creatures they command** across Azeroth.

---

### Step 1: The Two-Pass Cross-Check Strategy

To overcome Wowhead's 1,000-entity query truncation while ensuring 100% accurate zone-by-zone ecological alignment and subfamily attribution, ingestion executes across two complementary passes:

* **Pass 1 — Zone Census (`npcs?filter=6;{zoneId};0`)**:
  * Scrapes all NPCs residing within a specific zone.
  * Captures every local wildlife species (`type: 1, 2, 4, 9`) and every local humanoid/undead actor (`type: 7, 6`).
  * Because single zones rarely exceed 200–400 total NPCs, **Pass 1 never triggers Wowhead's 1,000-item truncation cap**.
  * Delivers raw zone ecology: NPC ID, name, native level bracket, reaction flags, and faction tag.

* **Pass 2 — Family & Subfamily Taxonomy**:
  * Beast taxonomy queries use Wowhead's canonical slug syntax: `https://www.wowhead.com/forever/npcs/beasts/{subfamily}`
  * All 19 capturable Beast subfamilies are ingested via their exact verified slug endpoints:
    1. `bat` (ID 24 - Cunning) ➔ `https://www.wowhead.com/forever/npcs/beasts/bat`
    2. `bear` (ID 4 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/bear`
    3. `bird-of-prey` (ID 26 - Cunning) ➔ `https://www.wowhead.com/forever/npcs/beasts/bird-of-prey`
    4. `boar` (ID 5 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/boar`
    5. `carrion-bird` (ID 7 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/carrion-bird`
    6. `cat` (ID 2 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/cat`
    7. `crab` (ID 8 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/crab`
    8. `crocolisk` (ID 6 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/crocolisk`
    9. `gorilla` (ID 9 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/gorilla`
    10. `hyena` (ID 25 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/hyena`
    11. `raptor` (ID 11 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/raptor`
    12. `scorpid` (ID 20 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/scorpid`
    13. `spider` (ID 3 - Cunning) ➔ `https://www.wowhead.com/forever/npcs/beasts/spider`
    14. `tallstrider` (ID 12 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/tallstrider`
    15. `turtle` (ID 21 - Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/turtle`
    16. `wind-serpent` (ID 27 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/wind-serpent`
    17. `wolf` (ID 1 - Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/wolf`
    18. `hydra` (Ferocity) ➔ `https://www.wowhead.com/forever/npcs/beasts/hydra` *(Multi-headed apex predators)*
    19. `scalehide` (Tenacity) ➔ `https://www.wowhead.com/forever/npcs/beasts/scalehide` *(Consolidates Kodos, Thunder Lizards, and Stegodons)*
  * Non-beast companion families follow the identical slug pattern:
    - **Dragonkin** (ID 2) ➔ `https://www.wowhead.com/forever/npcs/dragonkin` (~305 NPCs)
    - **Elementals** (ID 4) ➔ `https://www.wowhead.com/forever/npcs/elementals` (~551 NPCs)
    - **Mechanicals** (ID 9) ➔ `https://www.wowhead.com/forever/npcs/mechanicals` (~214 NPCs)
  * Every individual query sits far below Wowhead's 1,000-entity truncation cap.
  * Delivers global taxonomy: authentic Hunter subfamily, spec archetype (Tenacity, Ferocity, Cunning), diet preference, and DBC display ID mappings.

* **The Cross-Check & Join Resolution**:
  * The ingestion pipeline cross-references Pass 1 against Pass 2 using `npcId`:
    $$\text{FinalZoneCreature} = \text{ZoneCensus}(npcId) \bowtie \text{TaxonomyRegistry}(npcId)$$
  * Any beast discovered in Zone X is automatically enriched with its authentic subfamily, spec archetype, and validated 3D display model.
  * ⛔ **Purely Aquatic Exclusion Filter**: Automatically discards water-locked swimming mobs (Threshers, Sharks, Frenzy fish, Eels) during join resolution. Only terrestrial or amphibious species (Crabs, Crocolisks, Turtles) are admitted.
  * Guarantees zero missing zone mobs, zero truncated lists, zero floating fish on dry land, and zero orphaned taxonomies.

---

### Step 2: Safe Throttling Policy & Execution Speed (5-Second Cadence)
* **Polite 5-Second Throttling**: Rather than spamming Wowhead's servers or triggering Cloudflare/CloudFront rate limits, the ingestion script enforces a **strict 5.0-second delay between HTTP requests**.
* **The Math for WoW: Forever**:
  * Total playable zones across the entire WoW: Forever world (Classic + Beta additions): **~60 zones**.
  * Total requests needed for Pass 1: **Exactly 1 request per zone**.
  * **Total Time**: $60 \text{ requests} \times 5 \text{ seconds} = 300 \text{ seconds} = \mathbf{5\text{ minutes flat}}$.
* **Unbreakable Resumption & Atomic Local Caching**:
  * Each zone payload is immediately committed to an atomic local cache file (`Data/Census/zone_{id}.json`) upon receipt.
  * If the script is interrupted at minute 3 (e.g. at Zone 36), restarting it instantly checks existing cache files and resumes at Zone 37 with **zero repeated network calls**.
* **Zero-Ban Human Footprint**: At 1 request every 5 seconds, network traffic mimics ordinary human browsing. There is zero risk of IP blacklisting or Cloudflare CAPTCHA interference.

---

### Step 3: Automated Dual Registry Partitioning
* **Zone Capturable Wildlife Registry (`Zone_{id}_Creatures.lua`)**:
  * All non-humanoid valid species are compiled into the zone's active capture and rival squad pool.
  * Every creature is linked to its authentic 3D `displayId`.
* **Zone Humanoid Trainer Registry (`Zone_{id}_Humanoids.lua`)**:
  * All humanoid mobs are indexed by their NPC Template ID and exact name.
  * Captures their faction `tag`, level bracket, and elite status.
  * Enables **instant, zero-overhead target identification** in-game: when a player targets a mob, its NPC ID from `UnitGUID("target")` matches the zone registry with 100% precision.

---

### Step 4: Mandatory Display ID Resolution & Lua Compilation
* **The Display ID Mandate**: A creature entry is considered fundamentally incomplete and will not be compiled into the addon unless its authentic 3D `displayId` is verified.
* **Dual Identification Standard**:
  * `id`: The NPC Template ID (used for zone mapping, spawn identity, and drop logic).
  * `displayId`: The `CreatureDisplayInfoID` (the **only** ID accepted by `PlayerModel:SetDisplayInfo()` to render 3D geometry and animations in the Arena, Journal, and Nursery).
* **Two-Stage Resolution**:
  * **Stage 1 (Classic DBC Mapping - ~90%)**: Display IDs for classic returning creatures are pre-indexed from verified DBC client tables into [`Data/CreatureDisplays.lua`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/CreatureDisplays.lua).
  * **Stage 2 (New Patch 1.60.1 Scrape - ~10%)**: All newly introduced beta mobs (`firstseenpatch: 16001`) or entities missing display data trigger an individual page scrape (`/forever/npc={id}`) to extract the 3D model viewer JSON (`displayId: X`).
* **Zero Dummy Fallbacks**: Every creature published to [`Data/Creatures/`](file:///home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program%20Files%20%28x86%29/World%20of%20Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/Creatures) contains both its authentic `npcId` and verified `displayId` side-by-side. Arbitrary dummy fallbacks (like Dwarf 1629) are strictly rejected by the compilation script.

---

## 7. Mechanical Constructs: The "No Egg" Principle & Combobulation Architecture

Mechanical companions (`type: 9`) occupy a unique mechanical and philosophical niche in *Forever Safari*.

### A. The "No Egg" Invariant
* **Constructs Do Not Lay Eggs**: Mechanicals are synthetic engineering marvels (cogs, gyros, plating, steam valves, and arcanite wiring). They are **not** biological wildlife.
* **Excluded from Cenarion Nurseries**: Mechanicals cannot be placed into biological breeding pens, cannot mate, and **never produce eggs**. The concept of a mechanical egg is strictly prohibited.

### B. Master Tinkers & The Specialized Pop-Up HUD
* **The Combobulation Interface**: Instead of biological breeding sanctuaries, mechanical pet reconstruction and modification is conducted by **Master Tinkers & Engineers**:
  * **Booty Bay**: Goblin Engineering Experts (Baron Revilgaz's tinkers).
  * **Ironforge**: Tinker Town Master Engineers (High Explorer & Gnome inventors).
  * **Orgrimmar**: Goblin Engineering Workshop (Nogg's Machine Shop).
  * **Ratchet & Gadgetzan**: Steamwheedle Engineering Specialists.
* **The Pop-Up HUD Interaction**:
  * Because standard Blizzard Gossip cannot be modified cleanly for custom mechanics, targeting or interacting with a Master Tinker / Engineer prompts **our specialized Pop-Up HUD**.
  * Clicking the HUD opens the **Combobulation Interface (`UI/CombobulationFrame.lua`)**, allowing players to re-engineer, calibrate, and upgrade mechanical frames.

### C. Dungeon & Raid Catalysts for Modular Move Socketing
Unlike living beasts—which unlock Moves 3 & 4 by observing predators unleash techniques in the wild—mechanical constructs possess modular hardware expansion slots. Their advanced ability slots (3 & 4) are unlocked by socketing **Dungeon & Raid Catalysts**:

* **Shadowfang Keep (SFK) Catalyst $\rightarrow$ Shadow / Undead Moves**:
  * Derived from Arugal's dark experiments and tainted worgen alchemy.
  * Socketing an SFK Catalyst into a mechanical construct installs modular dark-tech abilities:
    * *Slot 3*: **`Shadow Shock`** (Shadow-infused electrical discharge; deals direct magic damage).
    * *Slot 4*: **`Unholy Overdrive`** (Empowers mechanical output with dark energy; boosts speed and attack for 3 turns at the cost of periodic structural decay).
* **Gnomeregan Catalyst (Viscous Fallout) $\rightarrow$ Cryo-Coolant / Ice-Water Moves**:
  * Derived from the radioactive sludge and cooling systems of Gnomeregan (Viscous Fallout and irradiated machinery).
  * Socketing a Gnomeregan Catalyst installs modular industrial cooling systems:
    * *Slot 3*: **`Cryo Freeze`** (Direct chilling blast that slows and staggers the enemy).
    * *Slot 4*: **`Supercoolant Vent`** (Releases dense refrigerant vapor; grants a defensive thermal barrier while chilling attackers).
* **Other High-Tier Catalysts**:
  * *Blackrock Depths (BRD) Catalyst*: Overheats gyros with Magma/Fire abilities (*Thermal Flare*, *Magma Exhaust*).
  * *Deadmines Catalyst*: Heavy iron artillery modules (*Iron Cannonade*, *Defias Scrap Armor*).

---

## 8. Ongoing Quality Control & Invariant Checks
1. **Humanoid ID Trap Filter**: Automated verification to ensure display IDs never match known humanoid guard/vendor IDs.
2. **Zone Mapping Alignment**: Ensuring regional rival trainers and wild spawns only pull creatures native to the active zone (e.g. Westfall trainers strictly use Westfall ecology).
3. **Cache & Resumption**: All scrape progress is committed to local JSON caches immediately so no progress is lost.
4. **Mechanical Assembly Verification**: Ensures all mechanical constructs are strictly routed to the Combobulation pipeline and never flagged for egg generation.
5. **Purely Aquatic Exclusion Verification**: Automated filter ensuring water-bound swimming mobs (Threshers, Sharks, Frenzy Fish, Eels) are strictly excluded from capturable companion datasets. Amphibious fauna (Crabs, Crocolisks, Turtles) are verified for dry-land locomotion.

---

## 9. Open Framework Discussion Points (Living Document)
* *Topic 1: Handling Multi-Zone Spawns (Which zone takes precedence for trainer encounters?)*
* *Topic 2: Stat Scaling Curves between wild beasts vs. instance pup drops.*
* *Topic 3: Criteria for adding brand new subfamilies if Blizzard expands the Beta further.*

