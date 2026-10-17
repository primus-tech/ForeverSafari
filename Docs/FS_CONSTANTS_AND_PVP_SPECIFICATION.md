# 🐾 Forever Safari — Core System Constants, Slash Command Architecture & PvP Specification

---

## 📌 Section 1: Core System Definitions (`Core/Constants.lua:1-49`)

```lua
--[[
    Forever Safari: Constants & Core System Definitions
    Contains the 9 Pet Types, 4 core stats (Health, Attack, Defense, Speed),
    closed-loop 150% type effectiveness matrix, attunement ranks, and permit gates.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Constants = ns.Constants or {}

local C = ns.Constants

-- Secret value guard helper for WoW 12.1.5 / Forever Beta architecture
local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return true end
    if issecretpassphrase and issecretpassphrase(v) then return true end
    if issecretvariable and issecretvariable(v) then return true end
    local ok = pcall(function() local _ = (v == "") end)
    if not ok then return true end
    return false
end
C.IsSecret = isSecret

-- Addon Branding
C.ADDON_NAME = "Forever Safari"
C.VERSION = "0.3a"
C.ADDON_COLOR = "ffd100"
C.PREFIX = "|cffffd100[Forever Safari v0.3a]|r "

-- Storage Enclosure Capacity (400 Slots Total)
C.MAX_KENNEL_BOXES = 20
C.SLOTS_PER_BOX = 20
C.TOTAL_KENNEL_CAPACITY = C.MAX_KENNEL_BOXES * C.SLOTS_PER_BOX -- 400

-- Biological Sexing & Construct Designation
C.GENDERLESS_TYPES = {
    ["Mechanical"] = true,
    ["Elemental"] = true,
}

-- The 9 Official Pet Types & Passives (4 Core Stats: HP, ATK, DEF, SPD)
C.CREATURE_TYPES = {
    ["Aquatic"] = {
        name = "Aquatic",
        color = "00bfff",
        icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
        passiveName = "Aquatic Resilience",
        passiveDesc = "Reduces the duration of damage-over-time (DoT) effects by 50%.",
        strongAgainst = "Elemental",
        weakAgainst = "Flying",
        baseStats = { hp = 1.15, atk = 1.00, def = 1.05, spd = 1.00 },
    },
    ["Beast"] = {
        name = "Beast",
        color = "ff9900",
        icon = "Interface\\Icons\\Ability_Hunter_Pet_Cat",
        passiveName = "Enrage",
        passiveDesc = "Deals 25% extra damage when dropping below 50% health.",
        strongAgainst = "Critter",
        weakAgainst = "Mechanical",
        baseStats = { hp = 1.00, atk = 1.15, def = 0.95, spd = 1.05 },
    },
    -- [Remaining Types: Critter, Dragonkin, Elemental, Flying, Humanoid (NPC Rivals only), Mechanical, Undead]
}
```

### Kennel Vault & Enclosure Architecture
* **Total Capacity**: 400 specimens partitioned across 20 distinct Enclosures (20 slots per enclosure).
* **Navigation**: Box Switcher with Prev/Next buttons and a 2-column Jump menu showing occupancy counts per enclosure.
* **Custom Naming**: Players can rename any enclosure via a native Blizzard popup dialog (`FOREVER_SAFARI_RENAME_ENCLOSURE`).
* **Journal Design Language**: Search editbox, type/family dropdown, biological sex filter (`♂`, `♀`, `⚙`), and rarity filter (`👑 Apex`).
* **Auto-Overflow**: Catches beyond the 4-member squad consume a transport crate and automatically route to `DB:GetNextAvailableBox()`.

---

## 🚫 Section 2: Strict Slash Command Policy (Strictly `/fs` Prefaced — Zero Shims, Zero Fallbacks)

> [!IMPORTANT]
> **Policy Directive**: All user-facing slash commands are strictly prefaced by `/fs`.
> Anything other than `/fs` prefaced commands is removed.
> Per project architectural standards (`Truth.md`), **no `/safari` aliases, no legacy shims, and no fallback bridges** are permitted anywhere in the system.

### 1. Canonical `/fs` Command Suite

Every interaction in the addon operates under the unified `/fs` command space:

| Canonical `/fs` Command | Shorthand | Description / Target Frame |
| :--- | :--- | :--- |
| **`/fs`** | `/fs journal` | Toggle Safari Journal (3D Field Guide & Menagerie Showcase) |
| **`/fs bag`** | `/fsbag` | Toggle Virtual Safari Bag (inventory & provisions) |
| **`/fs mail`** | `/fsmail` | Open Safari Mail tab at any town mailbox |
| **`/fs kennel`** | `/fskennel` | Open Safari Companion Kennel at any town Banker |
| **`/fs shop`** | `/fsshop` | Open Safari Outfitter Store at any Pet Trainer |
| **`/fs net`** | `/fsnet`, `/fs observe` | Attempt live field observation/capture on current target |
| **`/fs battle`** | `/fsbattle` | Engage targeted wild creature or NPC rival in turn-based combat |
| **`/fs duel [target]`**| `/fsduel` | Challenge targeted player to a companion duel |
| **`/fs war`** | `/fswar` | Territory War manager (`setnode`, `setbase`, `start`, `stop`, `bridge`) |
| **`/fs nursery`** | `/fsnursery`, `/fsbreed` | Open 2-Player Co-op Nursery breeding chamber |
| **`/fs errors`** | `/fserrors`, `/fsbugs` | Open interactive copy-paste Lua error inspector modal |
| **`/fs taint`** | `/fstaint`, `/fsdiag` | Inspect combat taint & action block diagnostics |
| **`/fs bounties`** | — | Open Research Directives & Bounties tab |
| **`/fs tokens`** | — | Query current Safari Token balance in chat |
| **`/fs syncquests`** | — | Retroactively claim tokens for completed quests |
| **`/fs abandon`** | `/fs release` | Release active companion back into the wild (with confirmation) |
| **`/fs reset`** | — | Factory reset active recruit data & vault (requires confirmation) |
| **`/fs benchmark`** | — | Run persistence vault crypto & hydration benchmark suite |

### 2. Complete Removal of Non-`/fs` Commands
* **Purge `/safari`**: Remove `SLASH_SAFARI1 = "/safari"` entirely from `ForeverSafari.lua`.
* **Purge `/safarinursery`**: Remove `SLASH_FSNURSERY3 = "/safarinursery"` from `UI/NurseryFrame.lua`.
* **Zero Exceptions**: If a command does not start with `/fs`, it does not exist in the addon. No shims, no legacy handlers, and no fallback aliases. Any non-`/fs` input returns the default WoW client unknown command message.
* **Help & Intro Text**: All login messages, welcome banners, and help dialogue strings updated to cite `/fs` exclusively.

---

## ⚔️ Section 3: PvP Architectural Specification (Solo, Party, Raid)

### 1. Solo PvP (1v1 Duels)
* **Zero-Stat-Trust Handshake**:
  * Players exchange 4-companion minimal seed tuples:
    $$\{ \text{speciesId}, \text{attunementRank}, \text{budgetDistribution}, \text{moves}, \text{anatomy}, \text{isRare}, \text{ivSeed} \}$$
  * Both clients independently execute the **Hamilton-Hare 100/110-Point Budget Law**. If an opponent's payload specifies illegal stat points or unlearnable moves, the challenge is aborted with a security violation alert.
* **Commit-Reveal Turn Resolution (SHA-256)**:
  * **Phase 1 (Commit)**: During the 15-second action window, both players submit an action. Client sends:
    $$\text{CommitTag} = \text{SHA256}(\text{ActionID} \parallel \text{Salt})$$
  * **Phase 2 (Reveal)**: Once both commits are received, clients broadcast plaintext `ActionID` + `Salt`.
  * **Phase 3 (Verify & Execute)**: Hashes are validated. Actions resolve based on companion Speed stats.
* **Deterministic Shared PRNG**:
  * Seed derived via $\text{MatchSeed} = \text{SHA256}(\text{Seed}_A \parallel \text{Seed}_B \parallel \text{Timestamp})$.
  * Critical hits, accuracy checks, and status procs advance identical random number generators on both machines, eliminating desyncs.

---

### 2. Party PvP (Multi-Trainer / 2v2 Doubles & 5v5 Skirmish)
* **2v2 Doubles (Co-op Tag Team)**:
  * 2 players on Team Red vs 2 players on Team Blue over `PARTY` / `RAID` addon comms.
  * **Configurable Match Ruleset (Sympathy: Optional Toggle)**:
    * **Standard 2v2 (Classic Doubles — Sympathy OFF)**:
      * Companions act independently. Single-target buffs, shields, and direct heals target only the intended companion.
      * Prevents forced double-healer/HoT-stacking stall metas in competitive dueling.
    * **Resonant 2v2 (Co-op Synergy — Sympathy ON)**:
      * Enables the **Virtual Duo Engine** (`Core/BattleEngine.lua`):
        * **Sympathetic Buffing**: Beneficial defensive shields (*Barkskin Aegis*, *Static Jolt*) cast by Player 1 replicate across both active allied pets.
        * **50% Sympathetic Healing**: Heals delivered to one pet sympathetically restore 50% value to the allied partner's pet.
        * Shared buff turn decrements synchronize to cycle counters (`duoTurnCounter % 2 == 0`).
    * **Handshake Negotiation**:
      * The challenger sets `sympathy = true | false` in the challenge prompt; the defending team can review and accept or decline the ruleset before the match locks in.
* **5v5 Dungeon Party Brawl (Full Party vs Full Party)**:
  * Two 5-player dungeon groups challenge each other in open world / arena zones.
  * **Relay Gauntlet Mode**: Party members duel in sequential 1v1 slots; winner holds the field with retained health until one party’s roster is eliminated.
  * **5v5 Active Arena**: Each party member controls 1 active lead pet with AoE cleave mechanics mitigating through individual Defense ratings.

---

### 3. Raid PvP & Zone Territory War (Node / Lane Control)

#### A. Player-Defined Dynamic Capture Nodes & Safe Zones (Custom Staking)
* **Zero Static Database Restrictions**:
  * Nodes and Safe Zones are **NOT** hardcoded or locked to static locations. Players can host a match anywhere in Azeroth (open world, arenas, city courtyards, dungeon grounds).
* **Pre-Battle Staking & Banner Planting**:
  * **Team Safe Zones (Base Camps)**:
    * Red Captain establishes their base camp: `/fs war setbase red` (or drops Red War Banner).
    * Blue Captain establishes their base camp: `/fs war setbase blue` (or drops Blue War Banner).
    * Fainted companions can return to their team's Safe Zone to safely revive.
  * **Capture Nodes (3 to 5 Custom Locations)**:
    * Host or team captains stake out 3 to 5 custom control nodes where they stand:
      * `/fs war setnode 1 "The Mill"`
      * `/fs war setnode 2 "The Bridge"`
      * `/fs war setnode 3 "The Ruins"`
    * Exact map coordinates `(x, y)` and `mapID` are captured dynamically via `C_Map.GetPlayerMapPosition` and synced over `/raid` comms.
  * **Dynamic Revival Rune Spawning**:
    * Neutral **Revival Runes** are automatically spawned at the geometric midpoints between nodes and safe zones (or placed manually via `/fs war setrune`).
  * **Instant Live Map & Minimap Synchronization**:
    * Once locked, every participant's World Map and Minimap instantly render custom pin badges for the staked Safe Zones, Nodes, and Revival Runes.
* **Point-Ticking Scoring (First to 1,000 Points Wins)**:
  * Holding captured player-defined nodes generates ticks every 5 seconds (Arathi Basin model):
    * **1 Node**: 1 pt / tick
    * **2 Nodes**: 2 pts / tick
    * **3 Nodes**: 4 pts / tick
    * **4 Nodes**: 8 pts / tick
    * **5 Nodes (Domination)**: 15 pts / tick
* **Shareable Custom Presets**:
  * Players can save and load custom battleground setups:
    * `/fs war save "Gurubashi 3-Node"` / `/fs war load "Gurubashi 3-Node"`

#### B. The Active Creature Prerequisite Law (Zero Ghost-Capping)
* **Strict Capture Rule**: A player **CANNOT** capture, contest, or tick over a control point without an **active, conscious, battle-ready companion**.
* **Anti-Stall / Anti-Body-Blocking**:
  * If a player's companion is knocked out or unsummoned, their physical presence generates **zero** capture progress.
  * An unconscious player standing inside a capture ring **does not pause or contest** an enemy's active capture channel. The enemy caps unimpeded.

#### C. Ambush Dynamics, Virtual Combat Lock & The Spatial Tether Law
* **Virtual Addon State with Window & Spatial Monitoring**:
  * Because addons cannot lock physical 3D character inputs (WASD/steering), the ambush is enforced via an **authoritative virtual addon state** combining **Window State Monitoring** and **GPS Spatial Tethers**.
* **The Ambush Scenario & Spatial Tether Rules**:
  * *Initiation*:
    * Player A targets Player B and clicks **Fight** (`/fs battle` / Target HUD).
    * Player A's coordinates at that exact moment become the **Ambush Origin Point** $(x_0, y_0)$.
    * Player B's addon receives `AMBUSH_ENGAGE` and automatically pops open the `ForeverSafariBattleFrame`.
  * **Attacker's Anchor Law (Anti-"Drive-By" Exploit)**:
    * The attacker **MUST stay within a small radius (~20–25 yards) of where they initiated the ambush**.
    * If the attacker runs away or flees their own ambush origin to cap a node, the ambush collapses and the attacker forfeits. Attackers cannot "drive-by" ambush players and ride off.
  * **Defender's Range & Engagement Ticker (Anti-Fleeing Law)**:
    * The defender has a **15-second engagement window**.
    * If the defender continues riding away, ignores the fight, or fails to be within engagement range (~30 yards) of the ambush site when the 15-second timer expires:
      * **Auto-KO**: The defender's active companion is instantly knocked out.
      * The defender arrives at any destination with a dead companion that has zero capture power.
  * **Battle Window Monitoring**:
    * If either combatant closes the battle arena window (`OnHide` / hitting Escape / clicking the X):
      * **Immediate Forfeit & Auto-KO**: The companion instantly faints on the spot (`BE:ForfeitPvP("WINDOW_CLOSED")`).
* **Knockout Penalty & Strategic Consequences**:
  * Defeat in an ambush places the loser's companion in a **Fainted / Knocked Out** state.
  * While fainted, the player has zero capture authority, cannot contest nodes, and cannot initiate or accept ambushes.
* **The ONLY Two Ways to Revive**:
  1. **Return to Starting Safe Zone**:
     * Ride all the way back to the team's designated base camp (100% safe, but costs significant travel time and map presence).
  2. **Pick Up a Revival Rune (Minimap & World Map Pins)**:
     * High-stakes tactical **Revival Runes** spawn dynamically in neutral wilderness areas (river crossings, passes, ruins).
     * Runes are prominently **iconed and pinned on both the rotating Minimap and the full World Map** for both teams.
     * Riding into the Rune's coordinates instantly revives the companion, allowing immediate re-entry into combat.
     * *Strategic Consequence*: Because Runes appear on the map for everyone, enemies can predict retreat paths and set up counter-ambushes around active Runes.

---

## ⚡ Section 4: Network Optimization, Rate-Limiting & Sharding Architecture

### 1. Addon Message Throttling & Packet Batching
* **The Problem**:
  * Blizzard strictly rate-limits `C_ChatInfo.SendAddonMessage` (leaky bucket algorithm). In a 10v10 match, 20 players streaming coordinates on `OnUpdate` (60 Hz) would choke the addon channel and cause client disconnects within milliseconds.
* **The Architecture & Mitigations**:
  * **Low-Frequency Delta-Batched Heartbeat (1.0 Hz - 2.0 Hz)**:
    * Coordinates are **never** streamed every frame. Players broadcast a position packet only once every **1.5 seconds**, or immediately upon a state change (e.g., transition from *Traveling* $\to$ *Entered Capture Ring*).
  * **Compact Telemetry Packing**:
    * Coordinate payloads use ultra-short integer/delta formats:
      `POS:x,y,state` (e.g., `POS:452,153,1` for $45.2\%, 15.3\%$, Active). Entire payload is under 16 bytes.
  * **Channel Isolation for 1v1 Battles**:
    * Turn resolution (`COMMIT`, `REVEAL`) uses direct point-to-point **`WHISPER`** addon messages between the two combatants.
    * Only 2 tiny packets are exchanged per 15-second turn. Active fights generate near-zero load on the shared `RAID` channel.
  * **Single Authoritative Host Ticking**:
    * The Match Host's client is the sole authority for node point ticking (1 packet broadcast every 5.0 seconds). Clients do not redundantly broadcast score increments.

---

### 2. Open-World Sharding & Layer Sync Mitigations
* **The Problem**:
  * In modern WoW / Forever Beta, players in open world zones can be split across different server shards/layers, preventing visual line-of-sight and local channel communication (`YELL`/`SAY`).
* **The Architecture & Mitigations**:
  * **Raid Group Layer Colocation**:
    * Territory War participants are organized into a single 40-man **Raid Group** (or two paired parties). Blizzard's server automatically pulls grouped raid members onto the **same layer/shard** within seconds.
  * **Strict Channel Routing (`RAID` & `WHISPER` Only)**:
    * Never use `YELL` or `SAY` for addon comms.
    * `RAID` addon messages penetrate all sub-zones, caves, and instances across the zone.
    * `WHISPER` addon messages are realm-wide, guaranteeing delivery even across phase boundaries.
  * **Packet Loss & Retransmit Handshake**:
    * Commit-reveal packets include a sequence tag (`turn:seq`). If an ACK is not received within 3.0 seconds, the packet retransmits before the 15-second forfeit timer expires.

---

## 🌉 Section 5: Dual-Raid Fog-of-War & Comms Bridge Architecture (`Core/WarBridge.lua`)

### 📌 Problem Statement & Design Challenge
In **Forever Safari Territory War (Raid PvP)**, two teams (Red: Groups 1–4, Blue: Groups 5–8) compete over dynamic capture nodes.
If both teams share a single Blizzard `RAID` group, the WoW C-engine automatically renders green/class-colored Minimap blips for all 40 players, destroying fog-of-war, ambush dynamics, and stealth play.
However, splitting players into **Two Separate Raids (Raid A vs. Raid B)** prevents standard `RAID` channel broadcasts across teams, and modern WoW API blocks `C_ChatInfo.SendAddonMessage` on custom player `CHANNEL`s.

To solve this, the architecture provides two selectable modes:
1. **Mode A (Dual-Raid Captain-to-Captain WHISPER Bridge)** — *Primary / Recommended for True Fog-of-War*.
2. **Mode B (Single-Raid Overlay Masking)** — *Fallback / Single-Group Tournament Mode*.

---

### 1. Dual-Raid Captain-to-Captain WHISPER Bridge (Mode A)

#### Network Topology
```
[Red Team Players (Raid A)]  ──(RAID Comms)──►  [Red Captain]
                                                    │
                                           (WHISPER Addon Msg)
                                                    ▼
[Blue Team Players (Raid B)] ◄──(RAID Comms)───  [Blue Captain]
```

#### Protocol Specification
* **Internal Cluster Comms**:
  * Red Team broadcasts internally using `C_ChatInfo.SendAddonMessage("FS_WAR", msg, "RAID")`.
  * Blue Team broadcasts internally using `C_ChatInfo.SendAddonMessage("FS_WAR", msg, "RAID")`.
* **Inter-Team Bridge**:
  * State changes (node captures, score ticks, ambush locks, match start/end) are routed exclusively between **Red Captain** and **Blue Captain** via `C_ChatInfo.SendAddonMessage("FS_WAR", msg, "WHISPER", targetCaptain)`.
  * Upon receiving a valid bridge payload, the receiving Captain automatically re-broadcasts it to their local raid group via `"RAID"`.
* **Heartbeat & Failover**:
  * Captains exchange a `PING` payload every 5 seconds.
  * If a Captain disconnects or drops, the addon automatically assigns the next available raid assistant/promoted player as the active **Bridge Proxy**.

---

### 2. Single-Raid Minimap Overlay & WorldMap Filtering (Mode B)

When running inside a single 40-man Raid (Red: Groups 1–4, Blue: Groups 5–8):

#### World Map (`WorldMapFrame`) Filtering
Hook `WorldMapFrame` pin providers to inspect raid subgroup numbers and hide opposing team members:
* Extract `subgroup` from `GetRaidRosterInfo(raidIndex)`.
* If `myTeam ~= targetTeam`, set pin alpha to 0 (`pin:SetAlpha(0)`), hide (`pin:Hide()`), and disable mouse interaction.

#### Minimap Fog-of-War Overlay (`Minimap`)
Create an opaque, custom-rendered canvas layer anchored over the native Minimap:
* Suppress native minimap tracking rendering where applicable.
* Draw custom unit pins **only** for allied subgroup members using `C_Map.GetPlayerMapPosition`.
* Completely omit opposing team units from the render loop.

---

### 3. Controller Implementation File: `Core/WarBridge.lua`

```lua
local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.WarBridge = ns.WarBridge or {}

local WB = ns.WarBridge
local C = ns.Constants
local DB = ns.Database

local MSG_PREFIX = "FS_WAR"
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(MSG_PREFIX)
end

-- System State
WB.Mode = "DUAL_RAID" -- "DUAL_RAID" or "SINGLE_RAID"
WB.MyTeam = nil       -- "RED" or "BLUE"
WB.IsCaptain = false
WB.TargetCaptain = nil
WB.MatchID = nil
WB.Epoch = 1
WB.Seq = 0

-- Active War State
WB.State = {
    active = false,
    nodes = {},
    bases = {},
    runes = {},
    scores = { RED = 0, BLUE = 0 },
    participants = {},
}
```

---

## 🛡️ Section 6: Zero-Trust Simulation Protocol & Deterministic Architecture

### 1. The Core Paradigm: WoW as Host Environment vs. Forever Safari as Simulation

```
                    WORLD OF WARCRAFT (Host Environment)
             ┌──────────────────────────────────────────────┐
             │ Players / Groups / Maps                      │
             │ Movement / Chat Transport                    │
             │ UI / Client Window Framework / SavedVariables │
             └──────────────────────┬───────────────────────┘
                                    │
                             Forever Safari
                                    │
             ┌──────────────────────▼───────────────────────┐
             │       GAME SIMULATION & BATTLE ENGINE        │
             │                                              │
             │ Companions (Hamilton-Hare Budget Validation)  │
             │ Deterministic Turn-Based Combat              │
             │ Territory War & Capture Authority            │
             │ Knockout, Fainted State & Revival Runes      │
             │ Authoritative Match Protocol & Scoring       │
             └──────────────────────────────────────────────┘
```

WoW provides physical identity, player movement coordinates, and chat packet transport.  
**Forever Safari provides 100% of the game simulation, combat rules, stats, and match authority.**

---

### 2. Canonical Companion Construction vs. Derived Stats Rule

* **The Law**: **Derived combat statistics (`Max HP`, `Attack`, `Defense`, `Speed`, `Crit %`) are NEVER authoritative network inputs.**
* Clients transmit only the minimal **Canonical Companion Definition**:
  $$\{ \text{speciesId}, \text{attunementRank}, \text{budgetDistribution}, \text{moves}, \text{anatomy}, \text{isRare}, \text{ivSeed} \}$$
* Receiving clients independently reconstruct combat stats and evaluate the **Hamilton-Hare 100/110-Point Budget Law**:
  $$\text{Valid?} \implies \text{Species legal} \land \text{Rank legal} \land \text{Budget legal} \land \text{Moves legal} \land \text{IV valid}$$
* Any illegal distribution immediately marks `MATCH_INVALID` and terminates the handshake.

---

### 3. The Three State Categories

| Category | Definition & Scope | Mutability & Authority |
| :--- | :--- | :--- |
| **A. Immutable Match Definition** | `MatchID`, `Ruleset`, `Teams`, `Participants`, `Companion Definitions`, `Node Coordinates`, `Safe Zone Bases`, `Rune Locations`, `Victory Threshold`. | **Locked at Match Start**. Never mutates during play. |
| **B. Deterministic Simulation State** | `Current HP`, `Active Buffs/Debuffs`, `Move PP / Cooldowns`, `Current Turn`, `Active Companion`, `Fainted Status`, `PRNG State Index`. | **Locally Derived via Simulation**. Identical across peers without streaming raw stat values. |
| **C. Authoritative World State** | `Node Owner`, `Node Contest State`, `Team Scores`, `Match Phase`, `Rune Availability`, `Player Battle State`, `Player Capture Eligibility`. | **Host/Match Protocol Governed**. Managed via discrete state transition events. |

---

### 4. Pure Deterministic Battle Engine (`Resolve`)

Given identical initial conditions, rules, actions, and random seeds, the Battle Engine guarantees identical outcomes on all peers:
$$\text{Resolve}(\text{State}, \text{Action}_A, \text{Action}_B, \text{RNG}) \implies \text{Identical NextState}$$

* **Zero Engine Dependency**: Combat resolution has **no dependency** on:
  - Local frame rate or `OnUpdate` ticks
  - UI animation completion
  - System or local hardware clocks
  - Network packet arrival order (commit-reveal gates turn resolution)

---

### 5. Deterministic PRNG Pipeline & Consumption Order

* At match handshake, peers exchange seeds to derive the synchronized match seed:
  $$\text{MatchSeed} = \text{SHA256}(\text{Seed}_A \parallel \text{Seed}_B \parallel \text{Timestamp})$$
* **Strict Consumption Pipeline**: To avoid branching desyncs, PRNG values are consumed in an immutable sequence per move execution:
  1. **Accuracy Check**: `rng:Next()` $\to$ Hit / Miss
  2. **Critical Strike Roll**: `rng:Next()` $\to$ Crit / Normal
  3. **Damage Variance Roll**: `rng:Next()` $\to$ 85%–100% variance multiplier
  4. **Status Effect Proc**: `rng:Next()` $\to$ Secondary ailment trigger
  5. **Secondary Mechanics**: `rng:Next()` $\to$ Move-specific secondary checks

---

### 6. Local Observation, Distributed Validation (LODV) & Capture Predicate

* **LODV Principle**: Clients observe local events (`"I entered node"`, `"I reached rune"`, `"I initiated ambush"`), but these observations are advisory assertions until validated against match rules.
* **The Formal Capture Predicate (`CanCapture`)**:
  $$\text{CanCapture}(\text{Player}, \text{Node}) = \begin{cases} 
  \mathbf{True} & \text{if } \text{InMatch} \land \text{Alive} \land \text{CompanionActive} \land \neg \text{InBattle} \land \text{InRadius} \land \text{NodeCapturable} \\
  \mathbf{False} & \text{otherwise (contributes zero capture pressure)}
  \end{cases}$$
* **Formal Forfeit Resolution**:
  $$\text{15s Inaction / Window Dismissed} \implies \text{FORFEIT Event} \implies \text{BattleEngine Resolves Defeat} \implies \text{Companion } \to \text{FAINTED}$$
  *UI behavior never directly mutates persistent state; it triggers a formal battle resolution event.*

---

### 7. Packet Structure & Captain Epoch Protocol

All inter-team and intra-team packets conform to the structured packet envelope:
```text
FS_WAR : matchId=<ID> : epoch=<N> : seq=<SEQ> : origin=<RED|BLUE> : type=<TYPE> : payload=<DATA>
```

#### Firewall Validation Pipeline:
1. **Prefix Valid?** Matches registered `FS_WAR` prefix.
2. **Match Valid?** Matches current active `matchId`.
3. **Epoch Valid?** Current or advancing captain election epoch (drops stale packets from disconnected captains).
4. **Sequence Valid?** Strictly monotonic sequence counter (drops replays and out-of-order packets).
5. **State Legal?** Action is legal under the current match state machine.

---

### 8. Periodic Battle Checkpoints (`STATE_HASH`)

To detect divergence during extended battles:
* Every 5 turns, combatants exchange a compact state digest:
  $$\text{StateHash} = \text{SHA256}(\text{Turn} \parallel \text{HP}_A \parallel \text{HP}_B \parallel \text{RNGIndex})$$
* If `StateHash` matches $\to$ Simulation verified in lockstep.
* If `StateHash` diverges $\to$ `DESYNC_DETECTED` alert flagged with automated rollback to last verified checkpoint.

---

### 9. Formal 10-Point Protocol Freeze Matrix

| # | Protocol Area | Architectural Specification Status |
| :---: | :--- | :--- |
| **1** | **Battle Engine State Machine** | Strict 4-phase turn loop: `TURN_START` $\to$ `COMMIT` $\to$ `REVEAL` $\to$ `RESOLVE`. |
| **2** | **Companion Serialization** | Minimal 7-tuple representation; raw mutable stats strictly prohibited on the wire. |
| **3** | **PRNG Consumption Order** | Fixed 5-step pipeline: Accuracy $\to$ Crit $\to$ Variance $\to$ Status $\to$ Secondary. |
| **4** | **Match ID + Epoch + Seq** | Triple-header packet envelope preventing cross-match contamination, stale captains, and replays. |
| **5** | **Captain Failover Election** | Next promoted raid assistant assumes Gateway proxy at `epoch = epoch + 1`. |
| **6** | **Bridge Validation** | Distributed firewall dropping unauthenticated or out-of-order assertions. |
| **7** | **LODV Architecture** | Local observations sent as advisory events; receiving engine executes `CanCapture` & boundary checks. |
| **8** | **Periodic State Checkpoints** | Turn-modulo SHA-256 state hashes ensuring zero-divergence simulation. |
| **9** | **Transport & Map Canvas** | Rate-limited telemetry (1.5s delta heartbeats); Fog-of-War Minimap/WorldMap filtering. |
| **10**| **Forfeit & Disconnect Semantics** | 15s timer expiration or window hide emits formal `FORFEIT` $\to$ engine resolves defeat $\to$ `FAINTED`. |

---

## 🏆 Section 7: High-Trust Social Framing & Phased Implementation Roadmap

### 1. Updated Trust Model & Realistic Engineering Framing
* **Territory War as a High-Trust Social Mode**:
  * Designed for **same-guild events, moderated community tournaments, and friendly scrimmages** rather than an anonymous public ranked ladder.
  * Eliminates the need for paranoid cryptographic policing of physical world coordinates. Social accountability in guilds naturally prevents griefing, while our addon protocol provides the fun, interactive game structure.
* **Coherent End-to-End Security Architecture**:
  * **Single-Player Data**: Vault integrity via HMAC-SHA256, XXTEA, and Logically Atomic Dual-Generation storage.
  * **Player Duels (1v1 & 2v2)**: Zero-Trust Simulation Protocol, Hamilton-Hare 100/110-point validation, commit-reveal, and `STATE_HASH` lockstep checkpoints.
  * **Territory War (Raid PvP)**: High-trust protocol-enforced social event game with Captain Bridge gateways and Minimap fog-of-war masking.

---

### 2. The Core Disciplines
1. **Deterministic Core Stays Pure**:
   - The battle engine, PRNG consumption pipeline, and `STATE_HASH` checkpoints remain strictly enforced. Desyncs feel bad even among friends.
2. **Captain Failover with Epochs**:
   - Epoch counter and automatic assistant promotion remain required. Disconnects happen regardless of trust level.
3. **Clear Forfeit & Penalty Messaging**:
   - The UI must explicitly inform players *why* a forfeit occurred (*"Companion Fainted: 15-second action timeout"*, *"Companion Fainted: Abandoned ambush perimeter"*, *"Companion Fainted: Battle window dismissed"*).
4. **Pure Player-Defined Staking (Zero Static Presets Required)**:
   - Completely bypass hardcoded coordinate databases and static presets.
   - Players plant their own flags directly where they stand (`/fs war setnode [1..5]`, `/fs war setbase [red|blue]`). Zero database maintenance, infinite battlefield freedom anywhere in Azeroth.
5. **UI Honesty & Event Framing**:
   - Transparent in-game banner: *"Forever Safari Territory War is a protocol-enforced social event mode. Fair play depends on participants."*

---

### 3. Phased Implementation Roadmap

```
Phase 1: 1v1 Duels
  ├── Zero-Trust Minimal-Seed Handshake (Hamilton-Hare Budget Validation)
  ├── Commit-Reveal Turn Resolution (SHA-256)
  └── Periodic STATE_HASH Checkpoints (Turn % 5 Divergence Detection)
         │
         ▼
Phase 2: 2v2 Doubles
  ├── Configurable Sympathy Ruleset (Default: OFF)
  └── Multi-Combatant Turn State Machine
         │
         ▼
Phase 3: Territory War (Raid PvP)
  ├── Player-Defined Dynamic Staking (/fs war setnode, /fs war setbase)
  ├── Dual-Raid Captain-to-Captain WHISPER Bridge (Core/WarBridge.lua)
  ├── Minimap Canvas Overlay & WorldMap Fog-of-War Filtering
  ├── Ambush Spatial Tether Law & 15s Battle Window Forfeit Monitoring
  └── Automatic Midpoint Revival Rune Spawning
         │
         ▼
Phase 4: Social Tournaments & Guild Ladders
  └── Event Scoring, Brackets & Spectator Chat Announcements
```
