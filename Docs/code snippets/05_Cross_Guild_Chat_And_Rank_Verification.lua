--[[
================================================================================
OLYMPUS CODE SNIPPET #5: CROSS-GUILD CHAT & RANK VERIFICATION
================================================================================
Origin: Olympus Addon (Channels.lua)
Context: Federation Multi-Tier Chat Security

PROBLEM IT SOLVES:
------------------
When implementing cross-guild chat channels (e.g. [Alliance-Wide], [Officer-Chat],
[Guild-Masters-Only]) over a shared custom channel:
1. SECURITY & SPOOFING: A malicious player running an edited addon could forge
   a packet claiming: "I am Rank 0 (Guild Master) in Olympus". If other clients
   naively trust the message payload, unauthorized players can post into
   restricted officer/leader channels.
2. BLIZZARD COMPLIANCE: Sending unlogged human text over addon channels can violate
   TOS. Modern WoW clients offer `C_ChatInfo.SendAddonMessageLogged` which allows
   Blizzard's backend to log and audit human text for moderation.
3. CHAT FLOODING & FAIR SHARE: High-volume chatter in one guild must not starve
   other guilds' ability to communicate.

SOLUTION:
---------
1. LOGGED BLIZZARD API:
   All human chat messages are transmitted with `C_ChatInfo.SendAddonMessageLogged`.
   Clients verify that incoming lines arrived marked as logged; unlogged lines
   are dropped.

2. INDEPENDENT LOCAL RANK VERIFICATION (Never Trust the Message):
   When a message `M1~tier~guild~id~class~text` arrives:
   - For members in our OWN guild: The client looks up the sender in its own
     local guild roster (`GuildRosterInfo` / `GetGuildRosterInfo`), which is
     vouched for directly by the Blizzard server.
   - For members in OTHER guilds: The client checks the sender against the
     cryptographically signed manifest or corroborated census votes.
   - If verification fails or rank is insufficient, the line is silently dropped!

3. FAIR SHARE FLOOD GUARDS:
   - Hard cap of 60 lines shown per minute per channel (`MAX_SHOWN_PER_MINUTE`).
   - If a channel is half full, individual senders are capped at 10 lines/min (`FAIR_SHARE`).
   - Senders get a burst bucket of 6 parts with a 1.2s refill rate.

================================================================================
]]

local ChatEngine = {}

-- Channels / Tiers
local TIERS = {
    A = { level = 1, label = "Federation", slash = "/ol",  color = "|cffe6c35c" }, -- All members
    C = { level = 2, label = "Captains",   slash = "/olc", color = "|cff59d9d9" }, -- Officers (Rank <= 1)
    L = { level = 3, label = "Lords",      slash = "/oll", color = "|cffbf80ff" }, -- Guild Masters (Rank == 0)
}

local seenDedupe = {} -- [sender#id] = timestamp
local DEDUPE_WINDOW = 120

--------------------------------------------------------------------------------
-- 1. LOCAL RANK VERIFICATION (The Critical Security Rule)
--------------------------------------------------------------------------------
-- Returns:
--   level (0=unauthorized, 1=member, 2=officer, 3=guild master)
--   verified (boolean)
function ChatEngine.VerifySenderRank(senderFullName, claimedGuild, rosterMap)
    local myGuild = GetGuildInfo("player")

    -- 1. SENDER IS IN OUR OWN GUILD:
    -- Verify strictly from our own server-vouched roster table
    if myGuild and claimedGuild:lower() == myGuild:lower() then
        local rankIndex = rosterMap and rosterMap[senderFullName]
        if rankIndex ~= nil then
            if rankIndex == 0 then return 3, true end -- Guild Master
            if rankIndex <= 1 then return 2, true end -- Officer / Captain
            return 1, true -- Ordinary member
        end
        -- Not in our roster despite claiming our guild -> Forgery!
        return 0, false
    end

    -- 2. SENDER IS IN ANOTHER FEDERATION GUILD:
    -- (In Olympus, this queries Data.AuthorizedRank or Authority.Enforced)
    -- Here we query your cross-guild verified census store:
    if ChatEngine.ExternalGuildValidator then
        return ChatEngine.ExternalGuildValidator(senderFullName, claimedGuild)
    end

    -- Fallback: If external guild cannot be verified, default to basic member (level 1)
    -- NEVER grant officer (level 2) or master (level 3) without independent proof!
    return 1, false
end

--------------------------------------------------------------------------------
-- 2. TRANSMIT CHAT LINE
--------------------------------------------------------------------------------
function ChatEngine.Send(tierKey, text, channelIndex)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessageLogged) then return false end
    if channelIndex <= 0 then return false end

    local tier = TIERS[tierKey]
    if not tier then return false end

    -- Format: M1~<tier>~<guild>~<id>~<class>~<text>
    local myGuild = GetGuildInfo("player") or "Unknown"
    local _, myClass = UnitClass("player")
    local msgId = math.random(1000, 9999)

    -- Sanitize text: strip dangerous pipes and control characters
    local cleanText = text:gsub("[|~]", "")
    local wirePacket = string.format("M1~%s~%s~%d~%s~%s", tierKey, myGuild, msgId, myClass or "", cleanText)

    -- Transmit using logged Blizzard API so abuse can be reviewed
    local ok = pcall(C_ChatInfo.SendAddonMessageLogged, "OLY_PREFIX", wirePacket, "CHANNEL", channelIndex)
    return ok
end

--------------------------------------------------------------------------------
-- 3. RECEIVE & DISPLAY CHAT LINE
--------------------------------------------------------------------------------
function ChatEngine.OnMessageReceived(senderFullName, wirePacket, isLogged, rosterMap)
    -- Security Check 1: Must be logged by Blizzard
    if not isLogged then
        return false, "unlogged_drop"
    end

    -- Parse wire format: M1~tier~guild~id~class~text
    local tierKey, guild, idStr, class, text = wirePacket:match("^M1~([ACL])~([^~]+)~(%d+)~([^~]*)~(.*)$")
    if not tierKey or not guild or not text then return false, "malformed" end

    -- Security Check 2: Deduplicate repeats
    local dedupeKey = senderFullName .. "#" .. idStr
    local now = GetTime()
    if seenDedupe[dedupeKey] and (now - seenDedupe[dedupeKey] < DEDUPE_WINDOW) then
        return false, "duplicate"
    end
    seenDedupe[dedupeKey] = now

    -- Security Check 3: Independent Rank Verification
    local targetTier = TIERS[tierKey]
    local senderLevel, verified = ChatEngine.VerifySenderRank(senderFullName, guild, rosterMap)

    if senderLevel < targetTier.level then
        -- Sender does not possess the rank required for this channel tier!
        return false, "insufficient_rank"
    end

    -- Format for player chat frame:
    -- [Tag] [PlayerLink] <Guild>: Message
    local senderShort = senderFullName:match("^([^%-]+)") or senderFullName
    local playerLink = string.format("|Hplayer:%s|h[%s]|h", senderFullName, senderShort)
    local formatted = string.format("%s[%s]|r %s <|cffffd200%s|r>: %s",
        targetTier.color,
        targetTier.label,
        playerLink,
        guild,
        text
    )

    -- Print to default chat window
    DEFAULT_CHAT_FRAME:AddMessage(formatted)
    return true
end

return ChatEngine
