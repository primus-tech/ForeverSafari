# Truth

## 1. Platform & Vision
We are programming for **WoW: Forever**.

* **WoW: Forever** is a unique experience built on the framework of classic plus that is **horizontal rather than vertically progressive**.
* However, it is **not** Classic, Classic+, Vanilla, nor Vanilla+. It is its own distinct world and system: **WoW Forever**.

---

## 2. Canonical NPC Roles in Forever Safari
In *Forever Safari*, NPCs have strict, dedicated roles within our minigame ecosystem. No generic fallbacks, no accidental cross-contamination with class trainers, guards, flight masters, or profession trainers.

| NPC Archetype | In-Game Subtitle | Forever Safari Role | Description |
| :--- | :--- | :--- | :--- |
| **Pet Trainers** | `<Pet Trainer>` | **Outfitters, Healers & City Breeders** | Primary merchants for safari equipment, nets, crates, and provisions; provide squad healing and recovery; and host **early-game companion breeding in Capital Cities** (offspring hatches at Rank I: Untamed). |
| **Innkeepers** | `<Innkeeper>` | **Healers** | Merely healers. Dedicated squad rest, recovery, and revival stations across towns and taverns. |
| **Bankers** | `<Banker>` | **Kennelers** | The custodians of the Companion Reserve. Grant access to long-term pet storage, enclosures, and squad swapping. |
| **Stable Masters** | `<Stable Master>` | **Outpost Leaders** | The regional guides, outpost masters, and challenge leaders who test trainers in official Safari League battles (accessed via specialized HUD). |
| **Cenarion Keepers** | `<Cenarion Keeper>` | **Sacred Sanctuary Breeders** | Custodians of the Sacred Grove in Moonglade. Facilitate advanced endgame co-op breeding rituals (offspring hatches at Rank III: Attuned). |

---

## 3. Exclusion Rules
* **Guards & Sentries:** Have no gameplay function in *Forever Safari*. Any directional dialogue pointing to an inn or bank must never trigger safari interactions.
* **Flight Masters:** Have no gameplay function in *Forever Safari*.
* **Class Trainers (including Hunter Trainers):** Have no connection to *Forever Safari*.
* **Profession Trainers (Blacksmiths, Tailors, etc.):** Have no connection to *Forever Safari*.

---

## 4. Stable Master Interaction & The Specialized HUD
* **Server-Side Class Check:** In WoW: Forever, **Stable Masters do not offer gossip options to non-Hunters**. The server checks the player's class immediately upon interaction and terminates the gossip session if the player is not a Hunter.
* **The Specialized HUD Requirement:** Because native Blizzard Gossip cannot be used by non-Hunters at Stable Masters, **Forever Safari uses our specialized HUD** (targeting / world interaction HUD) to challenge Outpost Leaders and engage in Outpost Battles. Native gossip injection is never relied upon for Outpost challenges at Stable Masters.

---

## 5. Tiered Breeding Sanctuaries: Capital Cities vs. Sacred Grove
Breeding availability is tiered to provide early access while preserving sacred endgame progression:

| Breeding Sanctuary | NPC Host | Availability | Offspring Starting Rank | Gameplay Advantage |
| :--- | :--- | :---: | :---: | :--- |
| **Capital City Nurseries** | `<Pet Trainer>` | **Immediate Early Game** (Stormwind, Orgrimmar, Ironforge, Thunder Bluff, Darnassus, Undercity) | **Rank I (Untamed)** *(0 Points)* | Convenient local city access. Offspring must be nurtured and trained up from the wild baseline. |
| **Sacred Grove Sanctuary** | `<Cenarion Keeper>` | **Endgame Journey** (Moonglade - Nighthaven) | **Rank III (Attuned)** *(100 Points)* | **Sacred Rebirth**: Skips the early training grind entirely. Offspring begins with 0% disobedience, immediate battle readiness, and full catalyst support. |

---

## 6. The "King of the Hill" Naming Principle
* **Authentic Beast Names:** Companions never receive synthetic "Starter" prefixes attached to their names (e.g. **no** `"Starter Mangy Wolf"`).
* **True Champions from Day One:** An initial bonded companion is an authentic wild beast of Azeroth (**"Mangy Wolf"**, **"Young Black Bear"**, **"Crag Boar"**, **"Young Nightsaber"**). Players can nurture and climb all the way to the top of the Safari League with their very first companion.

---

## 7. Codebase Integrity: No Aliases, No Shims
* **Straightforward Code Only:** We do not write aliases, compatibility shims, proxy tables, wrapper polyfills, or indirect bridge layers.
* **Direct & Explicit:** Code must be direct and unambiguous. If a function or table exists, it has a single canonical name and implementation. Do not construct fallback cascades or masquerades for missing APIs. Write clean, native, straightforward code.

---

## 8. Virtual Duo Outposts, Party Scaling & Pre-Battle Squad Designation
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

## 9. Research Licenses, Dungeon Boss Specimen Drops & Mailbox Dispatch
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

## 10. Progressive Dispatch Flow & Badges Showcase
* **Sequential Mailbox Directives:**
  * To avoid overwhelming recruits on Day 1, only **Dispatch #1** (*First Steps*) and **Dispatch #2** (*Outpost Reconnaissance*) appear initially in the town mailbox and Journal.
  * As players complete and claim each directive, the subsequent directive reveals itself sequentially (#3 $\rightarrow$ #4 $\rightarrow$ #5 $\rightarrow$ Permit Directives).
* **The 3D Field Guide Badges Cabinet (Tab 5):**
  * Tab 5 (`[BADGES]`) provides a permanent trophy showcase in the Safari Journal:
    * **Top Shelf**: 4 large ornate Research License plaques (locked darkened brass vs. certified gold).
    * **Velvet Grid**: Scrollable showcase of all 54 Regional Outpost Badges with unearned mystery silhouettes and earned victory timestamps/defeat quotes.
    * **Live Tally**: Real-time progress tracking (`Badges Collected: X / 54 (Y%)`).
