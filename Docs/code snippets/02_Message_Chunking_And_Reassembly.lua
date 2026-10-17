--[[
================================================================================
OLYMPUS CODE SNIPPET #2: MESSAGE CHUNKING & OUT-OF-ORDER REASSEMBLY
================================================================================
Origin: Olympus Addon (Codec.lua, Comm.lua)
Context: World of Warcraft Addon Communication Limits

PROBLEM IT SOLVES:
------------------
Blizzard's C_ChatInfo.SendAddonMessage has a hard limit of 255 bytes per message.
Large datasets (roster census, signed manifests, high-score boards, PvP battle logs)
require several kilobytes.
Furthermore, UDP-like network delivery in WoW means:
1. Chunks can arrive out of order.
2. Individual chunks can be lost or delayed.
3. Malicious or broken clients could spam chunk headers to cause memory exhaustion
   (denial of service).

SOLUTION:
---------
1. WIRE PROTOCOL FOR CHUNKS:
   "C<id>:<i>:<n>:<payload>"
   Where:
     <id>      = Short transfer identifier (e.g. "412")
     <i>       = Current chunk index (1-based, e.g. 1, 2, 3...)
     <n>       = Total chunk count (e.g. 10)
     <payload> = Up to 220 bytes of payload data

2. CHUNKING LOGIC (Codec.Chunk):
   Slices any arbitrary string into an array of chunks <= 255 bytes ready for transmission.

3. RESILIENT REASSEMBLER (Codec.NewAssembler & Codec.Feed):
   - Keyed by `sender .. "#" .. id` to guarantee isolation between senders.
   - Accepts chunks arriving in ANY sequence (e.g. piece 3 arrives before piece 1).
   - Only concatenates and emits the complete string once all `n` pieces arrive.
   - Enforces strict security bounds:
     * MAX_CHUNKS: Refuses transfers exceeding a sanity ceiling (e.g. 34 chunks = ~7.5 KB).
     * OPEN_PER_SENDER: At most 2 concurrent open assemblies per sender.
     * OPEN_MAX: At most 30 concurrent assemblies globally.
     * GC SWEEP: Automatically purges incomplete assemblies older than 60s.

================================================================================
]]

local ChunkingEngine = {}

ChunkingEngine.CHUNK_SIZE  = 220 -- Payload bytes per chunk (leaving room for header)
ChunkingEngine.MAX_CHUNKS  = 34  -- Max pieces allowed (7,480 bytes)
ChunkingEngine.OPEN_PER_SENDER = 2
ChunkingEngine.OPEN_MAX    = 30

--------------------------------------------------------------------------------
-- 1. CHUNKER: Split long string into array of wire-ready strings
--------------------------------------------------------------------------------
function ChunkingEngine.Chunk(payload, transferId)
    if type(payload) ~= "string" or #payload == 0 then return {} end
    
    local id = tostring(transferId or math.random(100, 999))
    local totalLen = #payload
    local numChunks = math.ceil(totalLen / ChunkingEngine.CHUNK_SIZE)

    if numChunks > ChunkingEngine.MAX_CHUNKS then
        error(string.format("Payload exceeds MAX_CHUNKS (%d > %d)", numChunks, ChunkingEngine.MAX_CHUNKS))
    end

    local chunks = {}
    for i = 1, numChunks do
        local startIdx = (i - 1) * ChunkingEngine.CHUNK_SIZE + 1
        local endIdx   = math.min(totalLen, i * ChunkingEngine.CHUNK_SIZE)
        local slice    = payload:sub(startIdx, endIdx)

        -- Wire format: C<id>:<i>:<n>:<piece>
        chunks[i] = string.format("C%s:%d:%d:%s", id, i, numChunks, slice)
    end

    return chunks
end

--------------------------------------------------------------------------------
-- 2. ASSEMBLER FACTORY
--------------------------------------------------------------------------------
function ChunkingEngine.NewAssembler()
    return {
        buf      = {}, -- [sender#id] = { n = total, parts = {}, got = count, t = timestamp, sender = name }
        bySender = {}, -- [sender] = count of active open transfers
        open     = 0,  -- total open transfers
        evicted  = 0,
        refused  = 0,
    }
end

--------------------------------------------------------------------------------
-- 3. CLOSE/REMOVE AN ASSEMBLY ENTRY
--------------------------------------------------------------------------------
function ChunkingEngine.Close(asm, key)
    local entry = asm.buf[key]
    if not entry then return end

    asm.buf[key] = nil
    asm.open = math.max(0, asm.open - 1)

    local currentSenderCount = (asm.bySender[entry.sender] or 1) - 1
    if currentSenderCount > 0 then
        asm.bySender[entry.sender] = currentSenderCount
    else
        asm.bySender[entry.sender] = nil
    end
end

--------------------------------------------------------------------------------
-- 4. FEED A CHUNK INTO THE ASSEMBLER
--------------------------------------------------------------------------------
-- Returns:
--   string: The fully reassembled payload if this chunk completes the transfer.
--   nil:    If more chunks are still pending or if the chunk was invalid/refused.
function ChunkingEngine.Feed(asm, sender, chunkText, now)
    now = now or GetTime()

    -- Parse wire format: C<id>:<i>:<n>:<body>
    local id, iStr, nStr, body = chunkText:match("^C(%w+):(%d+):(%d+):(.*)$")
    if not id then return nil end

    local i = tonumber(iStr)
    local n = tonumber(nStr)

    -- Sanity boundary checks
    if not n or n < 1 or n > ChunkingEngine.MAX_CHUNKS then return nil end
    if not i or i < 1 or i > n then return nil end

    local key = sender .. "#" .. id
    local entry = asm.buf[key]

    -- If this is the first chunk seen for this transfer:
    if not entry or entry.n ~= n then
        local senderOpen = asm.bySender[sender] or 0

        -- Rate limit concurrent open transfers per sender & globally
        if senderOpen >= ChunkingEngine.OPEN_PER_SENDER or asm.open >= ChunkingEngine.OPEN_MAX then
            asm.refused = asm.refused + 1
            return nil
        end

        entry = {
            n      = n,
            parts  = {},
            got    = 0,
            t      = now,
            sender = sender,
        }
        asm.buf[key] = entry
        asm.bySender[sender] = senderOpen + 1
        asm.open = asm.open + 1
    end

    -- Store chunk at its exact 1-based index (handles out-of-order arrival)
    if not entry.parts[i] then
        entry.parts[i] = body
        entry.got = entry.got + 1
    end

    -- Completion check
    if entry.got == n then
        ChunkingEngine.Close(asm, key)
        -- In Lua, table.concat on an array from 1 to n is highly optimized in C
        return table.concat(entry.parts, "", 1, n)
    end

    return nil
end

--------------------------------------------------------------------------------
-- 5. GARBAGE COLLECTION (Sweep expired incomplete transfers)
--------------------------------------------------------------------------------
-- Call this periodically (e.g. every 10-30 seconds).
function ChunkingEngine.Gc(asm, now)
    now = now or GetTime()
    local droppedCount = 0

    for key, entry in pairs(asm.buf) do
        local maxWait = (entry.n > 30) and 70 or 60 -- Allow slightly longer for 30+ piece payloads
        if now - entry.t > maxWait then
            droppedCount = droppedCount + 1
            ChunkingEngine.Close(asm, key)
        end
    end

    return droppedCount
end

return ChunkingEngine
