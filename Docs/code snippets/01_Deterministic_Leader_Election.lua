--[[
================================================================================
OLYMPUS CODE SNIPPET #1: DETERMINISTIC LEADER ELECTION & SUPPRESSION
================================================================================
Origin: Olympus Addon (Comm.lua, Codec.lua)
Context: World of Warcraft Classic / Vanilla Addon Communication

PROBLEM IT SOLVES:
------------------
In large guilds (e.g. 1,000 members), if every client broadcasts roster status
or census data onto a shared realm-wide custom chat channel, the channel is
immediately overwhelmed, triggering chat spam disconnects and Blizzard server
throttling.

SOLUTION:
---------
1. Elect exactly ONE member per guild to act as the "Reporter" (who broadcasts
   the guild summary to the hidden custom channel).
2. Elect a second member as the "Runner-Up / Witness" (who broadcasts at a much
   slower rate to corroborate leadership authenticity and prevent rogue spoofing).
3. NO NETWORK VOTING ROUNDS OR PAXOS/RAFT OVERHEAD:
   Members broadcast lightweight "Hello" heartbeats (H1) on the private GUILD
   channel. Every client maintains a local table of active peers heard within a
   sliding window (e.g. 180s). Every client then runs the exact same deterministic
   selection function (e.g. alphabetical sort on "Name-Realm"). Because every
   client has the same peer pool and executes the same pure function, they all
   elect the exact same leader without exchanging a single vote packet!
4. TRAFFIC SUPPRESSION ("Quiet Mode"):
   If 1,000 members said "Hello" every 60s, the guild channel would take ~16
   messages per second. Once a member calculates that enough alphabetically
   lower peers exist who would win before them, they transition to "quiet mode",
   transmitting only once every 10 minutes to remain counted without generating spam.
5. ROLLOUT GUARD / BENCHING:
   If an elected reporter is running an old or buggy client, or is not in the
   channel, and fails to broadcast on the channel for 400s (GUARD_AFTER), all
   other peers bench that player for 30 minutes (GUARD_FOR) and automatically
   elect the next candidate.

================================================================================
]]

local ElectionEngine = {}

-- Time constants (in seconds)
local HELLO_EVERY       = 60      -- Active peers broadcast hello this often
local PEER_WINDOW       = 180     -- Peers heard within 3 minutes are considered active
local COUNT_WINDOW      = 720     -- Quiet peers stay in counts for 12 minutes
local GUARD_AFTER       = 400     -- Unheard elected reporter is benched after this long
local GUARD_FOR         = 30 * 60 -- Benched reporter is excluded for 30 minutes
local QUIET_TOTAL       = 10      -- Max active chatter pool needed to reliably elect leaders
local QUIET_MIN         = 3       -- Minimum chatters required per realm

-- Internal state
local peers         = {} -- [fullName] = lastHeardTimestamp
local peerRealm     = {} -- [fullName] = realmName
local peerVersion   = {} -- [fullName] = addonVersionString
local benched       = {} -- [fullName] = benchedUntilTimestamp
local heardOnChan   = {} -- [shortName] = lastHeardReportingOnChannelTimestamp
local lastHello     = 0
local watchReporter = nil -- { name = fullName, since = timestamp }

ElectionEngine.isReporter = false
ElectionEngine.isRunnerUp = false
ElectionEngine.reporterName = nil

--------------------------------------------------------------------------------
-- 1. DETERMINISTIC SELECTION (Pure Function)
--------------------------------------------------------------------------------
-- Takes the player's own name and a map of { [peerName] = timestamp }.
-- Returns the alphabetically lowest peer name active within the window.
function ElectionEngine.PickReporter(selfName, activePool, now, window)
    local best = selfName
    for name, t in pairs(activePool) do
        if now - t <= window and name < best then
            best = name
        end
    end
    return best
end

--------------------------------------------------------------------------------
-- 2. QUIET AFTER THRESHOLD (Traffic Suppression)
--------------------------------------------------------------------------------
-- Determines how many alphabetically preceding members must be heard before
-- this client silences its own periodic "Hello" broadcasts.
function ElectionEngine.QuietAfter(now, numPresenceRealms)
    local realms = numPresenceRealms or 1
    return math.max(QUIET_MIN, math.ceil(QUIET_TOTAL / realms))
end

--------------------------------------------------------------------------------
-- 3. ELECTABLE CANDIDATE POOL
--------------------------------------------------------------------------------
-- Filters the peer list to remove benched players, inactive players, and players
-- from incompatible realms/banks on duty.
function ElectionEngine.GetElectablePool(now, currentRealm)
    local pool = {}
    for name, t in pairs(peers) do
        local isBenched = (benched[name] or 0) > now
        local isRecent  = (now - t) <= PEER_WINDOW
        local sameRealm = (peerRealm[name] == nil or peerRealm[name] == currentRealm)

        if not isBenched and isRecent and sameRealm then
            pool[name] = t
        end
    end
    return pool
end

--------------------------------------------------------------------------------
-- 4. SEND "HELLO" HEARTBEAT (Over GUILD Channel)
--------------------------------------------------------------------------------
-- Called on a periodic timer (e.g. every 30-60s).
function ElectionEngine.SendHello(myFullName, myVersion, currentRealm, forceSend)
    if not IsInGuild() then return end

    local now = GetTime()
    local electable = ElectionEngine.GetElectablePool(now, currentRealm)

    -- Count how many active electable peers sort BEFORE this player
    local lowerPeersBeforeUs = 0
    for name, t in pairs(electable) do
        if name < myFullName then
            lowerPeersBeforeUs = lowerPeersBeforeUs + 1
        end
    end

    -- If enough candidates precede us and we aren't forced, suppress heartbeat
    local quietLimit = ElectionEngine.QuietAfter(now, 1)
    if not forceSend and lowerPeersBeforeUs >= quietLimit and (now - lastHello) < 600 then
        -- Suppressed: only ping once every 10 min (600s) to maintain census presence
        return
    end

    lastHello = now

    -- Wire format: H1~<version>~<realm>
    local payload = string.format("H1~%s~%s", myVersion, currentRealm)
    
    -- Send via Blizzard Addon Message API to GUILD
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage("OLY_PREFIX", payload, "GUILD")
    end
end

--------------------------------------------------------------------------------
-- 5. RECEIVE "HELLO" HEARTBEAT
--------------------------------------------------------------------------------
function ElectionEngine.OnHelloReceived(senderFullName, version, realm)
    local now = GetTime()
    peers[senderFullName] = now
    peerRealm[senderFullName] = realm or "Unknown"
    peerVersion[senderFullName] = version or "?"
end

--------------------------------------------------------------------------------
-- 6. CHANNEL REPORT RECEIVED (Election Feedback Loop)
--------------------------------------------------------------------------------
-- Whenever a guild census report is received on the hidden channel, record that
-- the reporter is actively doing their job.
function ElectionEngine.OnChannelReportReceived(reporterShortName)
    local now = GetTime()
    heardOnChan[reporterShortName] = now
    
    -- If this reporter was previously benched, unbench them now that they proved activity
    for name, benchEnd in pairs(benched) do
        local short = name:match("^([^%-]+)") or name
        if short == reporterShortName then
            benched[name] = nil
        end
    end
end

--------------------------------------------------------------------------------
-- 7. RE-EVALUATE ELECTION (Every Housekeeping Tick, e.g. 5s)
--------------------------------------------------------------------------------
function ElectionEngine.EvaluateElection(myFullName, currentRealm, channelIndex)
    local now = GetTime()
    local pool = ElectionEngine.GetElectablePool(now, currentRealm)

    -- 1. Elect the primary reporter
    local best = ElectionEngine.PickReporter(myFullName, pool, now, PEER_WINDOW)

    -- 2. Rollout / Silence Guard:
    -- If another peer won the election, but we sit on the channel and have NOT
    -- heard them report for our guild in GUARD_AFTER (400s), bench them!
    if best ~= myFullName and channelIndex > 0 then
        if not watchReporter or watchReporter.name ~= best then
            watchReporter = { name = best, since = now }
        end

        local bestShort = best:match("^([^%-]+)") or best
        local lastHeard = math.max(watchReporter.since, heardOnChan[bestShort] or 0)

        if now - lastHeard >= GUARD_AFTER then
            -- Bench the unresponsive reporter for 30 minutes
            benched[best] = now + GUARD_FOR
            pool[best] = nil
            watchReporter = nil

            -- Re-run election immediately without the benched peer
            best = ElectionEngine.PickReporter(myFullName, pool, now, PEER_WINDOW)
        end
    else
        watchReporter = nil
    end

    ElectionEngine.isReporter = (best == myFullName)
    ElectionEngine.reporterName = best

    -- 3. Elect the runner-up (witness)
    ElectionEngine.isRunnerUp = false
    if not ElectionEngine.isReporter then
        local runnerUpPool = {}
        for name, t in pairs(pool) do
            if name ~= best then
                runnerUpPool[name] = t
            end
        end

        local second = ElectionEngine.PickReporter(myFullName, runnerUpPool, now, PEER_WINDOW)
        
        -- Runner up only acts if the primary reporter is actually active on the channel
        local bestShort = best and (best:match("^([^%-]+)") or best)
        local reporterActiveOnChan = best and (now - (heardOnChan[bestShort] or 0) <= 2 * 170)

        ElectionEngine.isRunnerUp = (second == myFullName) and reporterActiveOnChan
    end

    return ElectionEngine.isReporter, ElectionEngine.isRunnerUp, ElectionEngine.reporterName
end

return ElectionEngine
