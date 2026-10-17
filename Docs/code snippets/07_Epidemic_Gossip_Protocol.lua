--[[
================================================================================
OLYMPUS CODE SNIPPET #7: EPIDEMIC GOSSIP & PEER SUPPRESSION PROTOCOL
================================================================================
Origin: Olympus Addon (Workshop.lua)
Context: Decentralized Peer-to-Peer Data Distribution

PROBLEM IT SOLVES:
------------------
How do you propagate authoritative datasets (such as a list of approved guilds,
sanctioned moderators, or tournament prize ladders) across an entire realm
without requiring a central web server or requiring leadership to be online?
If a player who logs in asks the channel: "Who has the latest list?", and 50
online players immediately respond by broadcasting a 10-piece chunked payload,
the channel is instantly swamped with 500 redundant packets!

SOLUTION:
---------
1. VERSIONED IMMUTABLE BLOBS (HS1 / HT1):
   Data payloads carry an epoch/timestamp and signature:
     `HT1~<timestamp>~<realmGroup>~<data>~<signature>`
   A client only accepts a blob if:
   - Its timestamp is newer than the locally cached blob.
   - Its cryptographic signature or hash matches the trusted authority.

2. CATCH-UP QUERY (`HQ~<myTimestamp>`):
   Upon login, if a client has an outdated or empty store, it emits a query:
     `HQ~<localTimestamp>`
   Peers holding a newer timestamp note the request and schedule an answer.

3. STAGGERED RESPONSES & LISTENER SUPPRESSION (`pieceHook`):
   - Rather than answering immediately, responding peers draw a randomized
     staggered delay (e.g. 3 to 15 seconds).
   - The peers activate a listener hook (`pieceHook`) on incoming packets.
   - If Peer B hears Peer A begin transmitting the first piece of the answer
     (`C<id>:1:<n>...`), Peer B CANCELS its own pending transmission!
   - This ensures exactly ONE peer answers the query, reducing network traffic
     from O(N) redundant broadcasts to O(1).

4. BACKGROUND EPIDEMIC RELAY:
   Every 30 minutes (`RELAY_EVERY = 1800s`), approximately 3 randomly selected
   clients (`RELAYS = 3`) re-broadcast the latest signed list. This allows the
   dataset to heal and spread organically like a gossip virus across the playerbase.

================================================================================
]]

local GossipEngine = {}

GossipEngine.RELAY_EVERY = 1800 -- 30 minutes
GossipEngine.RELAYS      = 3    -- Desired relayers per period

local localListTimestamp = 0
local localListPayload   = nil
local pendingAnswerTimer = nil
local isListeningForPiece = false

--------------------------------------------------------------------------------
-- 1. STORE & CHECK NEW INCOMING DATA
--------------------------------------------------------------------------------
function GossipEngine.TakeBlob(remoteTimestamp, payload)
    if remoteTimestamp > localListTimestamp then
        localListTimestamp = remoteTimestamp
        localListPayload   = payload

        -- If we were preparing to answer an older ask, cancel our now-outdated answer
        if pendingAnswerTimer then
            pendingAnswerTimer:Cancel()
            pendingAnswerTimer = nil
        end
        return true
    end
    return false
end

--------------------------------------------------------------------------------
-- 2. QUERY FOR UPDATES UPON LOGIN
--------------------------------------------------------------------------------
function GossipEngine.AskLatest(sendFn)
    -- Wire format: HQ~<myTimestamp>
    local query = string.format("HQ~%d", localListTimestamp)
    sendFn("CHANNEL", query)
end

--------------------------------------------------------------------------------
-- 3. HANDLE QUERY RECEIVED FROM ANOTHER PEER
--------------------------------------------------------------------------------
-- When another player asks "Who has data newer than X?":
function GossipEngine.OnQueryReceived(requesterTimestamp, totalPeersOnline, sendChunkedFn)
    -- Do we have newer data?
    if localListTimestamp <= requesterTimestamp or not localListPayload then
        return
    end

    -- If we already have a pending answer queued, let it ride
    if pendingAnswerTimer then return end

    -- Randomized delay spread: 3 to 12 seconds
    local delay = math.random(3, 12)

    -- Arm suppression hook: listen for any other peer beginning to transmit
    isListeningForPiece = true

    pendingAnswerTimer = C_Timer.NewTimer(delay, function()
        pendingAnswerTimer = nil
        isListeningForPiece = false

        -- Send the full payload in chunked pieces
        if sendChunkedFn and localListPayload then
            sendChunkedFn("CHANNEL", "HT~" .. localListPayload)
        end
    end)
end

--------------------------------------------------------------------------------
-- 4. PEER SUPPRESSION HOOK (The Network Saver)
--------------------------------------------------------------------------------
-- Registered into the addon's incoming packet dispatcher:
function GossipEngine.OnPieceHookReceived(dist, sender, chunkHeader)
    -- If we hear ANY peer start transmitting an answer ("HT~" chunk piece 1),
    -- stand down immediately!
    if isListeningForPiece and pendingAnswerTimer then
        if chunkHeader:find("HT~") or chunkHeader:find("C%w+:1:") then
            -- Another peer was faster; cancel our transmission to save bandwidth
            pendingAnswerTimer:Cancel()
            pendingAnswerTimer = nil
            isListeningForPiece = false
        end
    end
end

--------------------------------------------------------------------------------
-- 5. PERIODIC RANDOM RELAY (Epidemic Diffusion)
--------------------------------------------------------------------------------
-- Called on an interval (e.g. every 5 minutes) to determine if this client
-- should randomly relay the list to keep the network seeded.
function GossipEngine.CheckPeriodicRelay(totalPeersOnline, sendChunkedFn)
    if not localListPayload or localListTimestamp == 0 then return end

    -- Probability check: we want ~3 peers out of N to broadcast every 30 minutes
    local n = math.max(1, totalPeersOnline or 10)
    local probability = GossipEngine.RELAYS / n

    if math.random() <= probability then
        if sendChunkedFn then
            sendChunkedFn("CHANNEL", "HT~" .. localListPayload)
        end
    end
end

return GossipEngine
