# Olympus Addon: Intercommunication Code Snippets & Architecture Guide

This folder contains modular, battle-tested code snippets extracted from the **Olympus** multi-guild federation addon (`Interface/AddOns/Olympus`). 

These snippets solve the unique technical and architectural challenges of coordinating hundreds or thousands of players across multiple distinct guilds and realms in World of Warcraft without central servers, without triggering Blizzard chat spam disconnects, and without succumbing to forged network packets.

---

## 📁 Snippets Index

| File | Pattern / Subsystem | Primary Origin | Key Engineering Technique |
| :--- | :--- | :--- | :--- |
| **`01_Deterministic_Leader_Election.lua`** | Leader Election & Traffic Suppression | `Comm.lua`, `Codec.lua` | Pure alphabetical sort over active peer pool (`PickReporter`) elects 1 reporter and 1 runner-up per guild without consensus packets; traffic suppression drops chatters into 10-min quiet mode. |
| **`02_Message_Chunking_And_Reassembly.lua`** | 255-Byte Slicing & Out-of-Order Assembly | `Codec.lua`, `Comm.lua` | Slices arbitrary data into 220-byte chunks (`C<id>:<i>:<n>:<piece>`); reassembles out-of-order chunks per sender; caps concurrent buffers to prevent memory exhaustion DoS. |
| **`03_Rate_Limiting_And_Priority_Queue.lua`** | Multi-Lane Interleaved Scheduler & Token Bucket | `Comm.lua` | 8-slot round-robin scheduler (`part, part, chat, part, chat, part, part, urgent`) prevents large transfers from starving chat; token-bucket (`ADMIT_BURST=60`, `ADMIT_RATE=2`) throttles inbound spam. |
| **`04_Hidden_Channel_Lifecycle_And_Self_Healing.lua`** | Hidden Channel Management & Self-Healing | `Comm.lua` | Waits for `/1 General` to stabilize before joining so custom channels don't bump game channels; bubbles channel index using `SwapChatChannelsByChannelIndex`; auto-clears griefed passwords/bans if promoted to owner. |
| **`05_Cross_Guild_Chat_And_Rank_Verification.lua`** | Federation Chat & Zero-Trust Rank Security | `Channels.lua` | Uses Blizzard's `SendAddonMessageLogged` API; never trusts rank claims in message payloads; validates sender ranks strictly against local roster or cryptographic manifests. |
| **`06_Census_Data_Aggregation_And_Vouching.lua`** | Data Compaction & Majority Consensus | `Codec.lua`, `Data.lua` | High-density delimited encoding for zone/class/level maps; locks sender identity to one guild for 15 minutes (`CLAIM_TTL`); compares structural leadership signatures across reporters to detect rogue splits. |
| **`07_Epidemic_Gossip_Protocol.lua`** | Decentralized Data Diffusion & Suppression | `Workshop.lua` | Propagates versioned signed lists via random epidemic relays (`RELAY_EVERY=1800s`); uses `pieceHook` listener suppression so when one peer begins answering an ask, all other peers abort their transmissions. |
| **`08_Minimap_Arrow_And_Layer_Tracking.lua`** | Cross-Layer Minimap Arrow & Layer Snooping | `KingArrow.lua`, `Layers.lua`, `Hop.lua` | Snoops the layer `zoneUID` from NPC creature GUIDs (`Creature-0-...-zoneUID-...`); tracks Asmongold's location/layer; renders a 3-state minimap arrow (solid white for same layer, tinted desaturated blue for cross-layer/different zone). |
| **`09_Layer_Hopping_And_Auto_Invite.lua`** | Distributed Layer Hopping & Auto-Invite Handshake | `Hop.lua` | 5-stage handshake (`LQ` ask, `LO` probabilistic offer, `LR` weighted request, `InviteUnit`/`AcceptGroup`, auto-leave on layer phase confirmation, `LX` guest release). Prevents whisper storms and avoids party stranding. |

---

## 🏗️ Core Architecture Overview

```
                      +--------------------------------------------+
                      |       WORLD OF WARCRAFT ENGINE             |
                      +--------------------------------------------+
                                      |             |
                         "GUILD" Distribution   "CHANNEL" (Hidden Custom)
                                      |             |
           +--------------------------+             +--------------------------+
           |                                                                   |
           v                                                                   v
+------------------------+                                          +------------------------+
| 01_Leader_Election     |                                          | 04_Hidden_Channel      |
| Heartbeats (H1)        |                                          | Sealed Channel Hashing |
| Traffic Suppression    |                                          | Reordering (KeepLast)  |
| Deterministic Pick     |                                          | Self-Healing Guardian  |
+------------------------+                                          +------------------------+
           |                                                                   |
           | (Elected Reporter Only)                                           |
           v                                                                   v
+------------------------+       +------------------------+         +------------------------+
| 06_Census_Aggregation  | ----> | 03_Priority_Queue      | ------> | 02_Chunking_Assembly   |
| High-Density Encoding  |       | 8-Slot Interleaving    |         | 220-byte slicing       |
| Sender Guild Locking   |       | Pre-send Guards        |         | Reassembly State Mach. |
| Majority Vouching      |       | Token Bucket Admission |         | Memory Bounds & GC     |
+------------------------+       +------------------------+         +------------------------+
                                              |
                                              +-----> [05_Cross_Guild_Chat]
                                              |
                                              +-----> [07_Epidemic_Gossip]
```

---

## 🛠️ How to Adapt These for Other Addons

These patterns can be adapted for:
1. **Multi-Guild Alliances & Raiding Leagues**: Synchronizing attendance, DKP/Loot history, and federation officer announcements without Discord bots.
2. **Cross-Guild PvP Tournaments & Duels**: Pacing spectator battle-log transfers while keeping user chat snappy.
3. **Player-to-Player Marketplace / Trading**: Broadcasting trade cards publicly while conducting order settlement and escrow over verified whispers.
4. **Decentralized High Score Tables**: Spreading leaderboard updates via epidemic gossip.
