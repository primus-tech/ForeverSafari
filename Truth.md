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



