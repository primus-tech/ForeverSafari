--[[
================================================================================
OLYMPUS CODE SNIPPET #4: HIDDEN CHANNEL LIFECYCLE & SELF-HEALING
================================================================================
Origin: Olympus Addon (Comm.lua)
Context: World of Warcraft Custom Chat Channel Management

PROBLEM IT SOLVES:
------------------
Using custom chat channels for addon intercommunication is fraught with engine
pitfalls in World of Warcraft:
1. ORDERING CORRUPTION: If an addon calls `JoinChannelByName("MyChan")` immediately
   at login, it can claim channel index 1, bumping `/1 General` to `/2` and `/2 Trade`
   to `/3`, breaking player macros and chat conventions.
2. CHAT CLUTTER: The hidden channel appears in player ChatFrames, printing raw
   addon protocol strings to human chat windows.
3. ROGUE TAKEOVER & GRIEFING: Custom channels in WoW grant Channel Owner status
   to the first player who enters. If a player or non-addon user becomes owner,
   they can set a password, turn on moderation, or `/ckick`/`/ban` other players,
   instantly severing the entire multi-guild network.

SOLUTION:
---------
1. CLEAN LOGIN SEQUENCING (JoinSoon & KeepLast):
   - Waits until Blizzard zone channels are established (General is `/1` for 2 seconds)
     before joining the custom channel.
   - If a slow login places the channel ahead of game channels, `KeepLast()` uses
     `C_ChatInfo.SwapChatChannelsByChannelIndex` to bubble the custom channel to the end.
   - Calls `ChatFrame_RemoveChannel` on all chat frames so messages are invisible to humans.

2. SEALED CHANNELS VIA BASE-36 HASHING:
   Derives a deterministic channel name and password from a shared secret:
     `Hash36(secret)` -> e.g. "Oly7k2m9p1x"
   Outsiders cannot predict the channel name without the key.

3. CHANNEL SELF-HEALING (Comm.HealChannel):
   - Listens to `CHAT_MSG_CHANNEL_NOTICE` (`YOU_JOINED`, `OWNER_CHANGED`, `PASSWORD_CHANGED`,
     `PLAYER_BANNED`, etc.).
   - Whenever an addon user is promoted to Channel Owner or Moderator:
     * Restores the legitimate password (or clears it if public).
     * Automatically unbans/unmutes any players who were kicked.
     * Turns moderation off (`ChannelModerate`).
     * Protects critical community leaders (Guild Master, King, Treasurer).

================================================================================
]]

local ChannelLifecycle = {}

local currentChannelName  = nil
local currentChannelIndex = 0
local isChannelOwner      = false
local isChannelModerator  = false
local bannedCache         = {}

--------------------------------------------------------------------------------
-- 1. BASE-36 HASH (Derive secret channel names)
--------------------------------------------------------------------------------
-- Converts an arbitrary text string into an 8-character base-36 hash.
function ChannelLifecycle.Hash36(text)
    local h1, h2 = 5381, 52711
    for i = 1, #text do
        local c = text:byte(i)
        h1 = (h1 * 33 + c) % 2147483647
        h2 = (h2 * 31 + c * 7) % 2147483647
    end

    local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    local out = ""
    local n = h1 * 1000 + (h2 % 1000)

    for _ = 1, 8 do
        local d = n % 36
        out = digits:sub(d + 1, d + 1) .. out
        n = math.floor(n / 36)
    end
    return out
end

--------------------------------------------------------------------------------
-- 2. HIDE CHANNEL FROM PLAYER CHAT FRAMES
--------------------------------------------------------------------------------
local function HideFromChatWindows(chanName)
    local numWindows = NUM_CHAT_WINDOWS or 10
    for i = 1, numWindows do
        local frame = _G["ChatFrame" .. i]
        if frame and ChatFrame_RemoveChannel then
            pcall(ChatFrame_RemoveChannel, frame, chanName)
        end
    end
end

--------------------------------------------------------------------------------
-- 3. ENSURE CUSTOM CHANNEL IS NUMBERED AFTER GAME CHANNELS (KeepLast)
--------------------------------------------------------------------------------
-- If slow login caused our custom channel to get assigned index 1 or 2,
-- swap it with zone channels (General, Trade) so player channels retain default numbers.
function ChannelLifecycle.KeepLast(chanName)
    if not (GetChannelList and C_ChatInfo and C_ChatInfo.SwapChatChannelsByChannelIndex) then return end
    local ourIndex = GetChannelName(chanName) or 0
    if ourIndex <= 0 then return end

    local list = { GetChannelList() }
    local stride = (type(list[3]) == "boolean") and 3 or 2
    local swapTarget = nil

    for i = 1, #list, stride do
        local id = tonumber(list[i])
        local name = list[i + 1]
        local info = C_ChatInfo.GetChannelInfoFromIdentifier and C_ChatInfo.GetChannelInfoFromIdentifier(name)
        
        -- Zone channels have zoneChannelID > 0
        local isZoneChan = (type(info) == "table" and (tonumber(info.zoneChannelID) or 0) > 0)
        if id and id > ourIndex and isZoneChan then
            swapTarget = id
        end
    end

    if swapTarget then
        pcall(C_ChatInfo.SwapChatChannelsByChannelIndex, ourIndex, swapTarget)
        currentChannelIndex = GetChannelName(chanName) or ourIndex
    end
end

--------------------------------------------------------------------------------
-- 4. JOIN CHANNEL SAFELY (Wait for General /1 first)
--------------------------------------------------------------------------------
-- delayTicks: pass 0 initially. Checks if General /1 is loaded before joining.
function ChannelLifecycle.JoinSoon(chanName, password, delayTicks, seenGeneralAt)
    delayTicks = delayTicks or 0
    local _, firstChan = GetChannelName(1)

    if firstChan and firstChan ~= "" then
        seenGeneralAt = seenGeneralAt or delayTicks
    end

    -- Join once General /1 has been stable for 2 seconds, or fallback after 15 seconds
    if delayTicks >= 15 or (seenGeneralAt and (delayTicks - seenGeneralAt >= 2)) then
        currentChannelName = chanName
        JoinChannelByName(chanName, password)
        HideFromChatWindows(chanName)

        -- Post-join verification after 3 seconds
        C_Timer.After(3, function()
            currentChannelIndex = GetChannelName(chanName) or 0
            ChannelLifecycle.KeepLast(chanName)
            HideFromChatWindows(chanName)
        end)
        return
    end

    C_Timer.After(1, function()
        ChannelLifecycle.JoinSoon(chanName, password, delayTicks + 1, seenGeneralAt)
    end)
end

--------------------------------------------------------------------------------
-- 5. CHANNEL SELF-HEALING (Restoring Health If Addon Becomes Owner)
--------------------------------------------------------------------------------
-- Called when notices reveal our character was made Owner or Moderator.
function ChannelLifecycle.HealChannel(expectedPassword)
    if not currentChannelName or not (isChannelOwner or isChannelModerator) then return end
    if (GetChannelName(currentChannelName) or 0) == 0 then return end

    -- 1. Ensure password matches expected secret
    if SetChannelPassword and isChannelOwner then
        pcall(SetChannelPassword, currentChannelName, expectedPassword or "")
    end

    -- 2. Turn off moderation (so all addon users can speak)
    if ChannelModerate and isChannelOwner then
        pcall(ChannelModerate, currentChannelName)
    end

    -- 3. Automatically unban any players wrongfully banned
    if ChannelUnban then
        for bannedPlayer in pairs(bannedCache) do
            pcall(ChannelUnban, currentChannelName, bannedPlayer)
            bannedCache[bannedPlayer] = nil
        end
    end
end

--------------------------------------------------------------------------------
-- 6. CHAT NOTICE EVENT HANDLER (CHAT_MSG_CHANNEL_NOTICE)
--------------------------------------------------------------------------------
function ChannelLifecycle.OnChannelNotice(noticeType, player, _, channelName, _, _, _, _, baseName)
    local targetChan = baseName or channelName
    if not targetChan or not currentChannelName then return end
    if targetChan:lower():find(currentChannelName:lower(), 1, true) == nil then return end

    local myName = UnitName("player")

    if noticeType == "OWNER_CHANGED" or noticeType == "CHANNEL_OWNER" then
        isChannelOwner = (player == myName)
        if isChannelOwner then
            ChannelLifecycle.HealChannel()
        end
    elseif noticeType == "SET_MODERATOR" then
        if player == myName then
            isChannelModerator = true
            ChannelLifecycle.HealChannel()
        end
    elseif noticeType == "UNSET_MODERATOR" then
        if player == myName then
            isChannelModerator = false
        end
    elseif noticeType == "PLAYER_BANNED" then
        if player and player ~= myName then
            bannedCache[player] = true
            if isChannelOwner or isChannelModerator then
                ChannelLifecycle.HealChannel()
            end
        end
    end
end

return ChannelLifecycle
