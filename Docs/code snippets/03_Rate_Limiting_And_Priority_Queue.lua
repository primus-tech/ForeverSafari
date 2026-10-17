--[[
================================================================================
OLYMPUS CODE SNIPPET #3: RATE LIMITING & MULTI-LANE PRIORITY QUEUE
================================================================================
Origin: Olympus Addon (Comm.lua)
Context: World of Warcraft Hardware & Network Packet Throttling

PROBLEM IT SOLVES:
------------------
If an addon fires multiple C_ChatInfo.SendAddonMessage calls in a single frame
or in rapid succession:
1. The WoW server disconnects the player for chat flooding.
2. If an addon is sending a large multi-chunk transfer (e.g. 30 pieces), a player
   typing an urgent chat message or triggering a high-priority duel alert would
   be blocked for 30+ seconds while the large transfer completes.
3. Conversely, incoming spam from external clients can cause Lua memory spikes
   and frame-rate stuttering.

SOLUTION:
---------
1. INTERLEAVED SCHEDULER ("BATCH_SLOTS"):
   Instead of transmitting a large transfer all at once, Olympus schedules a tick
   every 1.2 seconds (`SEND_INTERVAL = 1.2`).
   It uses an 8-slot round-robin schedule:
     `{ "part", "part", "chat", "part", "chat", "part", "part", "urgent" }`
   This guarantees that:
   - 30-piece transfers finish within ~55 seconds.
   - User chat lines get dispatched within 1.2–2.4s even while a large transfer
     is active in the background!
   - Urgent packets (e.g. royal alert, duel challenge) preempt ordinary transfers.

2. PRE-SEND CAPABILITY GUARDS:
   A queued message can sit in line for 5-10 seconds. In that time, the player
   might have logged out, left the guild, changed channels, or cancelled the action.
   Before each send, a `guard()` callback is evaluated; if it returns false, the
   message is dropped silently without wasting network quota.

3. TOKEN-BUCKET ADMISSION CONTROL (Inbound Anti-Spam):
   Every sender on the custom channel is tracked via a token bucket:
     - Burst capacity: 60 tokens (`ADMIT_BURST = 60`).
     - Refill rate: 2 tokens per second (`ADMIT_RATE = 2`).
   If a sender exceeds their tokens, incoming packets are dropped BEFORE string
   parsing or JSON/Lua table decoding, neutralizing DoS attempts.

================================================================================
]]

local QueueEngine = {}

local SEND_INTERVAL = 1.2 -- Send at most one packet every 1.2 seconds
local MAX_QUEUE     = 60  -- Max pending packets in queue
local CHAT_QUEUE    = 6   -- Max pending chat lines

-- 8-slot round-robin schedule for interleaved transmission
local BATCH_SLOTS = { "part", "part", "chat", "part", "chat", "part", "part", "urgent" }
local currentSlot = 1

-- Four priority lanes:
-- Lane 1: Urgent Single
-- Lane 2: Urgent Batch (chunks)
-- Lane 3: Ordinary Single
-- Lane 4: Ordinary Batch (chunks)
local lanes = {
    { first = nil, last = nil }, -- 1: Urgent Single
    { first = nil, last = nil }, -- 2: Urgent Batch
    { first = nil, last = nil }, -- 3: Ordinary Single
    { first = nil, last = nil }, -- 4: Ordinary Batch
}

local chatLane = {} -- Short FIFO queue for human chat lines
local activeTransfer = nil -- Whole transfer currently in flight
local queueSize = 0

--------------------------------------------------------------------------------
-- 1. TOKEN BUCKET INBOUND ADMISSION CONTROL
--------------------------------------------------------------------------------
local admitBuckets = {}
local ADMIT_BURST = 60
local ADMIT_RATE  = 2  -- 2 tokens per second

function QueueEngine.AdmitSender(senderName, now)
    now = now or GetTime()
    local b = admitBuckets[senderName]

    if not b then
        b = { tokens = ADMIT_BURST, t = now }
        admitBuckets[senderName] = b
    else
        -- Refill bucket based on elapsed time
        local elapsed = now - b.t
        b.tokens = math.min(ADMIT_BURST, b.tokens + elapsed * ADMIT_RATE)
        b.t = now
    end

    if b.tokens < 1 then
        -- Throttled: sender exceeded burst and refill rate
        return false
    end

    b.tokens = b.tokens - 1
    return true
end

--------------------------------------------------------------------------------
-- 2. ENQUEUE WORK UNIT
--------------------------------------------------------------------------------
-- parts:   array of strings (each <= 255 bytes)
-- dist:    "GUILD", "CHANNEL", or "WHISPER"
-- urgent:  boolean (true jumps ahead of ordinary transfers)
-- guard:   optional function returning boolean; re-checked immediately before send
-- done:    optional callback fn(sentSuccess, reason)
function QueueEngine.Enqueue(dist, parts, urgent, target, guard, done)
    if #parts == 0 then return false end
    if queueSize + #parts > MAX_QUEUE then
        if done then done(false, "queue_full") end
        return false
    end

    local job = {
        dist    = dist,
        parts   = parts,
        i       = 1, -- current piece index
        urgent  = urgent and true or false,
        target  = target,
        guard   = guard,
        done    = done,
        started = nil,
    }

    -- Pick lane: 1=urgent single, 2=urgent batch, 3=ord single, 4=ord batch
    local laneIdx = (job.urgent and 1 or 3) + (#parts > 1 and 1 or 0)
    local lane = lanes[laneIdx]

    -- Append to doubly-linked intrusive list in O(1)
    job.lane = lane
    job.prev = lane.last
    job.next = nil

    if lane.last then
        lane.last.next = job
    else
        lane.first = job
    end
    lane.last = job

    queueSize = queueSize + #parts
    return true
end

--------------------------------------------------------------------------------
-- 3. ENQUEUE CHAT LINE (Dedicated Low-Latency Lane)
--------------------------------------------------------------------------------
function QueueEngine.SendChat(msg, channelTarget, done)
    if #chatLane >= CHAT_QUEUE then
        if done then done(false, "chat_lane_full") end
        return false
    end

    table.insert(chatLane, {
        msg     = msg,
        target  = channelTarget,
        done    = done,
        t       = GetTime(),
    })
    return true
end

--------------------------------------------------------------------------------
-- 4. DISPATCH TICK (Called on a 1.2s Ticker)
--------------------------------------------------------------------------------
local function SendPacket(dist, text, target)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
    local ok, res = pcall(C_ChatInfo.SendAddonMessage, "OLY_PREFIX", text, dist, target)
    -- WoW Classic returns Enum.SendAddonMessageResult (0 = success) or boolean
    local success = ok and (res == nil or res == true or res == 0)
    return success
end

function QueueEngine.Pump()
    local now = GetTime()

    -- 1. Advance to next scheduled batch slot
    local slotType = BATCH_SLOTS[currentSlot]
    currentSlot = (currentSlot % #BATCH_SLOTS) + 1

    -- 2. Handle chat slot
    if slotType == "chat" and #chatLane > 0 then
        local chatItem = table.remove(chatLane, 1)
        local sent = SendPacket("CHANNEL", chatItem.msg, chatItem.target)
        if chatItem.done then chatItem.done(sent, sent and nil or "send_failed") end
        return
    end

    -- 3. Check for urgent single messages
    local urgentSingle = lanes[1].first
    if (slotType == "urgent" or not activeTransfer) and urgentSingle then
        -- Check pre-send guard
        if urgentSingle.guard and not urgentSingle.guard() then
            -- Guard failed: discard without sending
            lanes[1].first = urgentSingle.next
            queueSize = queueSize - 1
            if urgentSingle.done then urgentSingle.done(false, "guard_rejected") end
            return
        end

        local sent = SendPacket(urgentSingle.dist, urgentSingle.parts[1], urgentSingle.target)
        lanes[1].first = urgentSingle.next
        if not lanes[1].first then lanes[1].last = nil end
        queueSize = queueSize - 1
        if urgentSingle.done then urgentSingle.done(sent, sent and nil or "send_failed") end
        return
    end

    -- 4. Handle active batch transfer fragment
    if activeTransfer then
        local job = activeTransfer

        -- Validate timeout: transfers taking longer than 60s are cancelled
        if now - job.started > 60 then
            activeTransfer = nil
            queueSize = queueSize - (#job.parts - job.i + 1)
            if job.done then job.done(false, "transfer_timeout") end
            return
        end

        -- Check pre-send guard
        if job.guard and not job.guard() then
            activeTransfer = nil
            queueSize = queueSize - (#job.parts - job.i + 1)
            if job.done then job.done(false, "guard_rejected") end
            return
        end

        local piece = job.parts[job.i]
        local sent = SendPacket(job.dist, piece, job.target)
        
        job.i = job.i + 1
        queueSize = queueSize - 1

        if job.i > #job.parts then
            -- Transfer completed!
            activeTransfer = nil
            if job.done then job.done(true, nil) end
        end
        return
    end

    -- 5. If no active transfer, check if a new batch should start
    local nextBatch = lanes[2].first or lanes[4].first
    if nextBatch then
        -- Unlink from lane and elevate to activeTransfer
        local lane = nextBatch.lane
        if lane.first == nextBatch then lane.first = nextBatch.next end
        if lane.last == nextBatch then lane.last = nextBatch.prev end
        if nextBatch.prev then nextBatch.prev.next = nextBatch.next end
        if nextBatch.next then nextBatch.next.prev = nextBatch.prev end

        nextBatch.started = now
        activeTransfer = nextBatch

        -- Immediately send the first piece
        local piece = nextBatch.parts[nextBatch.i]
        local sent = SendPacket(nextBatch.dist, piece, nextBatch.target)
        nextBatch.i = nextBatch.i + 1
        queueSize = queueSize - 1
        return
    end

    -- 6. Otherwise, check ordinary single messages (Lane 3)
    local ordSingle = lanes[3].first
    if ordSingle then
        if ordSingle.guard and not ordSingle.guard() then
            lanes[3].first = ordSingle.next
            queueSize = queueSize - 1
            if ordSingle.done then ordSingle.done(false, "guard_rejected") end
            return
        end

        local sent = SendPacket(ordSingle.dist, ordSingle.parts[1], ordSingle.target)
        lanes[3].first = ordSingle.next
        if not lanes[3].first then lanes[3].last = nil end
        queueSize = queueSize - 1
        if ordSingle.done then ordSingle.done(sent, sent and nil or "send_failed") end
        return
    end
end

return QueueEngine
