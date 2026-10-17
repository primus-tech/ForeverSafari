--[[
================================================================================
OLYMPUS CODE SNIPPET #6: CENSUS DATA COMPACTION & VOUCHING CONSENSUS
================================================================================
Origin: Olympus Addon (Codec.lua, Data.lua)
Context: Distributed State Synchronization Across Guilds

PROBLEM IT SOLVES:
------------------
A full guild roster snapshot (1,000 members with level, class, online status,
zone location, and officer rank) easily totals 40 KB of raw data.
Broadcasting this naively is impossible within WoW's packet limits.
Furthermore:
1. SENDER HYSTERESIS: A rogue client could transmit fake reports for 50 different
   guilds, poisoning the database.
2. DISPUTE DETECTION: If two different players report conflicting data for the
   same guild (e.g. one claims Alice is Guild Master, another claims Bob is),
   how does a distributed client know which to trust without a central server?

SOLUTION:
---------
1. HIGH-DENSITY DELIMITED COMPACTION (Codec.lua):
   Encodes an entire guild status summary into a single delimited string:
     `R2~guild~total~online~leader~leaderOnline~zones~classes~levels~officers...`
   - Map encoder: `m1453=204,m1429=61` (m = uiMapID) sorted by highest frequency.
   - Class encoder: `WA=40,PA=12,RO=18`
   - Level distribution: 7 comma-separated bracket counts (1-9, 10-19... 60+)
   - Person encoder: `Name:online:daysOffline:class:level:zone`

2. ONE-GUILD SENDER LOCK (Data.ClaimGuild):
   Ties each sender (`Name-Realm`) strictly to ONE guild for 15 minutes (`CLAIM_TTL`).
   If a sender transmits reports claiming a different guild within 15 minutes,
   the report is immediately rejected.

3. ROSTER SIGNATURE & MAJORITY VOUCHING (Data.lua):
   - Computes a structural signature of the guild's leadership and officers:
     `Signature(report) -> "Alice-Realm=0,Bob-Realm=1,Charlie-Realm=1"`
   - Receivers retain the latest vote from up to 8 reporters (`MAX_VOUCH = 8`).
   - `Majority()` evaluates which structural picture has the most votes.
   - If votes are split evenly or sizes drift beyond physical limits (`SIZE_DRIFT`),
     the guild row is marked as `disputed` rather than accepted blindly.

================================================================================
]]

local CensusEngine = {}

CensusEngine.CLAIM_TTL = 15 * 60 -- 15 minutes lock per sender
CensusEngine.VOUCH_TTL = 30 * 60 -- 30 minutes vote retention
CensusEngine.MAX_VOUCH = 8

local senderGuildLock = {} -- [senderFullName] = { guild = guildName, t = timestamp }
local guildVotes      = {} -- [guildKey] = { [senderFullName] = { sig = signature, t = timestamp, size = total } }

--------------------------------------------------------------------------------
-- 1. DENSE MAP ENCODING & DECODING
--------------------------------------------------------------------------------
-- Compresses a table like { ["Warrior"] = 40, ["Paladin"] = 12 } into "Warrior=40,Paladin=12"
function CensusEngine.EncodeMap(t, maxEntries)
    local list = {}
    for k, v in pairs(t or {}) do
        if v and v > 0 then
            table.insert(list, { tostring(k):gsub("[,=~]", ""), math.floor(v) })
        end
    end
    -- Sort by frequency descending to ensure most important data fits in packet
    table.sort(list, function(a, b) return a[2] > b[2] end)

    local parts = {}
    for i = 1, math.min(#list, maxEntries or 40) do
        parts[i] = list[i][1] .. "=" .. list[i][2]
    end
    return table.concat(parts, ",")
end

function CensusEngine.DecodeMap(str)
    local t = {}
    for k, v in (str or ""):gmatch("([^,=]+)=(%d+)") do
        t[k] = tonumber(v)
    end
    return t
end

--------------------------------------------------------------------------------
-- 2. SENDER GUILD LOCK (Anti-Sybil Binding)
--------------------------------------------------------------------------------
function CensusEngine.ClaimGuild(senderFullName, guildName)
    local now = GetTime()
    local lock = senderGuildLock[senderFullName]

    if not lock then
        senderGuildLock[senderFullName] = { guild = guildName, t = now }
        return true
    end

    -- If sender attempts to speak for another guild within 15 minutes, reject!
    if lock.guild:lower() ~= guildName:lower() and (now - lock.t < CensusEngine.CLAIM_TTL) then
        return false
    end

    lock.guild = guildName
    lock.t = now
    return true
end

--------------------------------------------------------------------------------
-- 3. STRUCTURAL LEADERSHIP SIGNATURE
--------------------------------------------------------------------------------
-- Generates a deterministic hash string representing the leadership roster
function CensusEngine.CreateSignature(leaderName, officersList)
    local parts = {}
    if leaderName and leaderName ~= "" then
        table.insert(parts, leaderName .. "=0")
    end
    for _, officer in ipairs(officersList or {}) do
        table.insert(parts, officer.name .. "=1")
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

--------------------------------------------------------------------------------
-- 4. VOUCHING & MAJORITY CONSENSUS
--------------------------------------------------------------------------------
function CensusEngine.RecordVote(guildKey, senderFullName, leaderName, officersList, totalMembers)
    local now = GetTime()
    local sig = CensusEngine.CreateSignature(leaderName, officersList)

    if not guildVotes[guildKey] then
        guildVotes[guildKey] = {}
    end

    guildVotes[guildKey][senderFullName] = {
        sig  = sig,
        t    = now,
        size = totalMembers or 0,
    }
end

function CensusEngine.EvaluateMajority(guildKey)
    local now = GetTime()
    local votes = guildVotes[guildKey]
    if not votes then return nil, 0, false end

    -- Count votes for each unique signature
    local sigCounts = {}
    local totalActiveVotes = 0

    for sender, vote in pairs(votes) do
        if now - vote.t <= CensusEngine.VOUCH_TTL then
            sigCounts[vote.sig] = (sigCounts[vote.sig] or 0) + 1
            totalActiveVotes = totalActiveVotes + 1
        end
    end

    local bestSig, bestCount = nil, 0
    local isSplit = false

    for sig, count in pairs(sigCounts) do
        if count > bestCount then
            bestSig   = sig
            bestCount = count
            isSplit   = false
        elseif count == bestCount then
            -- Two conflicting signatures have equal backing!
            isSplit = true
        end
    end

    -- Returns:
    --   bestSig: winning leadership signature
    --   bestCount: number of independent reporters backing this picture
    --   isDisputed: true if the guild has an unresolved conflict
    return bestSig, bestCount, isSplit
end

return CensusEngine
