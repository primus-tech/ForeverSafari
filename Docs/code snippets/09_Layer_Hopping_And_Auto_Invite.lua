--[[
================================================================================
OLYMPUS CODE SNIPPET #9: DISTRIBUTED LAYER HOPPING & AUTO-INVITE HANDSHAKE
================================================================================
Origin: Olympus Addon (Hop.lua)
Context: Cross-Layer Shard Hopping & Peer-to-Peer Invite Coordination

PROBLEM IT SOLVES:
------------------
In WoW Classic, when a high-value event occurs on another layer (e.g. Asmongold
is hosting a raid, a world boss spawned, or a tournament began), players typically
spam `/1 General` or guild chat: "INV TO LAYER 1 PLEASE!".
This creates massive chat spam, manual friction, and invites getting sent to
AFK or unresponsive players.
Furthermore:
1. SWARMING / THUNDERING HERD: If 500 players want to hop to Layer 1, and 50 helpers
   are on Layer 1, a naive broadcast would cause all 50 helpers to whisper all
   500 askers simultaneously, generating 25,000 whispers and crashing chat!
2. PARTY STRANDING: When a helper invites a stranger to pull them to their layer,
   the stranger often forgets to leave the party, blocking the helper from
   playing or inviting others.

SOLUTION:
---------
1. THE 5-STAGE DISTRIBUTED HOP HANDSHAKE:
   - Stage 1 (Broadcast Ask):
     Asker broadcasts `LQ~<id>~<mapID>~<zoneUID>` on the hidden channel.
   - Stage 2 (Probabilistic Offer via Whisper):
     Helpers on that layer run a probability function (`Hop.Chance`) scaled by
     the layer's population so only ~6 helpers whisper back `LO~<id>~<groupSize>~<load>`.
   - Stage 3 (Weighted Selection & Request):
     Asker collects offers for 3 seconds (`WINDOW = 3`), then draws one helper,
     weighting heavily toward helpers who are solo (`group == 0`) and have
     invited fewer people recently (`load`). Asker whispers `LR~<id>` to that helper.
   - Stage 4 (Invite & Auto-Accept):
     Helper calls `InviteUnit(target)` (or auto-invites if in "Always Invite" mode).
     Asker's addon detects the invite from the vouched helper and calls `AcceptGroup()`.
   - Stage 5 (Phase Confirmation & Auto-Leave):
     Asker monitors local NPC GUIDs (`Layers.Mine()`). The instant their `zoneUID`
     matches the target layer, their addon calls `LeaveParty()`, freeing the helper!
     If the guest stalls, helper whispers `LX~<id>` after 90s (`GUEST_TIME`) to release them.

================================================================================
]]

local LayerHopEngine = {}

-- Protocol Constants
LayerHopEngine.WINDOW     = 3   -- Seconds to collect offers before picking
LayerHopEngine.WAIT       = 30  -- Seconds helper has to invite before asker tries next
LayerHopEngine.OFFERS     = 6   -- Target number of offers wanted per ask
LayerHopEngine.GUEST_TIME = 90  -- Helper releases guest after 90 seconds
LayerHopEngine.ASK_GAP    = 20  -- Cooldown between asks

local currentAsk = nil
-- ask = { id, mapID, zoneUID, phase, offers = {}, helper = nil, tried = {}, timer = nil }

local myRecentInvites = {}
local activeGuests = {} -- [shortName] = { fullName, id, t }

--------------------------------------------------------------------------------
-- 1. HELPER SIDE: PROBABILISTIC OFFER CALCULATION
--------------------------------------------------------------------------------
-- If 50 helpers are on a layer, we only want ~6 of them to whisper offers.
function LayerHopEngine.CalculateOfferChance(estimatedLayerCrowd)
    local crowd = math.max(1, estimatedLayerCrowd or 10)
    return math.min(1.0, LayerHopEngine.OFFERS / crowd)
end

function LayerHopEngine.CanHelp(targetMapID, targetZoneUID, myLayer)
    if not myLayer or myLayer.mapID ~= targetMapID or myLayer.zoneUID ~= targetZoneUID then
        return false
    end
    if IsInInstance() or InCombatLockdown() then return false end

    -- Check if we have room in our group
    local inGroup = IsInGroup and IsInGroup()
    if inGroup then
        local isLeader = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
        local numMembers = GetNumGroupMembers()
        local isRaid = IsInRaid()
        local maxMembers = isRaid and 40 or 5
        return isLeader and (numMembers < maxMembers)
    end
    return true -- Solo player can always invite
end

--------------------------------------------------------------------------------
-- 2. HELPER SIDE: RECEIVE ASK (LQ) AND SEND OFFER (LO)
--------------------------------------------------------------------------------
function LayerHopEngine.OnAskReceived(senderFullName, text, myLayer, crowdSize, sendWhisperFn)
    -- Parse wire format: LQ~<id>~<mapID>~<zoneUID>
    local idStr, mapStr, zoneStr = text:match("^LQ~(%d+)~(%d+)~(%d+)$")
    if not idStr then return end

    local id      = tonumber(idStr)
    local mapID   = tonumber(mapStr)
    local zoneUID = tonumber(zoneStr)

    if not LayerHopEngine.CanHelp(mapID, zoneUID, myLayer) then return end

    -- Roll probability check so only a fraction of helpers reply
    local chance = LayerHopEngine.CalculateOfferChance(crowdSize)
    if math.random() > chance then return end

    -- Stagger whisper offer by 0.2 to 2.5s to prevent packet burst
    local delay = 0.2 + (math.random() * 2.3)
    C_Timer.After(delay, function()
        if not LayerHopEngine.CanHelp(mapID, zoneUID, myLayer) then return end

        local groupCount = IsInGroup() and GetNumGroupMembers() or 0
        local recentLoad = #myRecentInvites

        -- Wire format: LO~<id>~<groupSize>~<load>
        local offerPayload = string.format("LO~%d~%d~%d", id, groupCount, recentLoad)
        sendWhisperFn(senderFullName, offerPayload)
    end)
end

--------------------------------------------------------------------------------
-- 3. ASKER SIDE: INITIATE LAYER ASK (LQ)
--------------------------------------------------------------------------------
function LayerHopEngine.StartHop(mapID, zoneUID, sendChannelFn)
    if IsInGroup() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Hop]|r Cannot hop while already in a group.")
        return false
    end
    if currentAsk and currentAsk.phase ~= "done" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Hop]|r Another hop is already in progress.")
        return false
    end

    local askId = math.random(10000, 99999)
    currentAsk = {
        id      = askId,
        mapID   = mapID,
        zoneUID = zoneUID,
        phase   = "collecting",
        offers  = {},
        tried   = {},
        t       = GetTime(),
    }

    -- Broadcast request on the hidden channel: LQ~<id>~<mapID>~<zoneUID>
    local askPayload = string.format("LQ~%d~%d~%d", askId, mapID, zoneUID)
    sendChannelFn(askPayload)

    -- Collect offers for WINDOW (3s) before selecting the best helper
    C_Timer.After(LayerHopEngine.WINDOW, function()
        if currentAsk and currentAsk.id == askId and currentAsk.phase == "collecting" then
            LayerHopEngine.PickAndRequestNextHelper(sendChannelFn)
        end
    end)

    return true
end

--------------------------------------------------------------------------------
-- 4. ASKER SIDE: RECEIVE OFFER (LO)
--------------------------------------------------------------------------------
function LayerHopEngine.OnOfferReceived(helperFullName, text)
    if not currentAsk or currentAsk.phase ~= "collecting" then return end

    -- Parse wire format: LO~<id>~<groupSize>~<load>
    local idStr, grpStr, loadStr = text:match("^LO~(%d+)~(%d+)~(%d+)$")
    if not idStr or tonumber(idStr) ~= currentAsk.id then return end

    currentAsk.offers[helperFullName] = {
        name  = helperFullName,
        group = tonumber(grpStr) or 0,
        load  = tonumber(loadStr) or 0,
    }
end

--------------------------------------------------------------------------------
-- 5. ASKER SIDE: WEIGHTED PICK & REQUEST (LR)
--------------------------------------------------------------------------------
function LayerHopEngine.PickAndRequestNextHelper(sendWhisperFn)
    if not currentAsk or currentAsk.phase == "done" then return end

    local pool, totalWeight = {}, 0
    for name, offer in pairs(currentAsk.offers) do
        if not currentAsk.tried[name] then
            -- Weight: solo helpers (group == 0) get 2x priority; fewer recent invites get higher weight
            local weight = (offer.group == 0 and 2.0 or 1.0) / (1 + offer.load)
            table.insert(pool, { offer = offer, weight = weight })
            totalWeight = totalWeight + weight
        end
    end

    if #pool == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200[Hop]|r No helpers available on that layer.")
        currentAsk.phase = "done"
        return
    end

    -- Weighted random roll
    local roll = math.random() * totalWeight
    local chosen = nil
    for _, item in ipairs(pool) do
        roll = roll - item.weight
        if roll <= 0 then
            chosen = item.offer
            break
        end
    end
    chosen = chosen or pool[#pool].offer

    currentAsk.helper = chosen.name
    currentAsk.tried[chosen.name] = true
    currentAsk.phase = "requesting"

    -- Send request whisper: LR~<id>
    sendWhisperFn(chosen.name, string.format("LR~%d", currentAsk.id))

    -- Set timeout: if helper does not invite in 30s, try next offer
    C_Timer.After(LayerHopEngine.WAIT, function()
        if currentAsk and currentAsk.phase == "requesting" and currentAsk.helper == chosen.name then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff8000[Hop]|r Helper did not respond. Trying next helper...")
            LayerHopEngine.PickAndRequestNextHelper(sendWhisperFn)
        end
    end)
end

--------------------------------------------------------------------------------
-- 6. HELPER SIDE: RECEIVE REQUEST (LR) & ISSUE INVITE
--------------------------------------------------------------------------------
function LayerHopEngine.OnRequestReceived(askerFullName, text, autoInviteEnabled)
    local idStr = text:match("^LR~(%d+)$")
    if not idStr then return end
    local id = tonumber(idStr)

    local target = askerFullName:match("^([^%-]+)") or askerFullName

    -- Issue in-game invite
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(target)
    elseif InviteUnit then
        InviteUnit(target)
    end

    -- Track recent invite load and guest release timer
    table.insert(myRecentInvites, GetTime())
    activeGuests[target] = { fullName = askerFullName, id = id, t = GetTime() }

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[Hop]|r Invited %s to share layer.", target))
end

--------------------------------------------------------------------------------
-- 7. ASKER SIDE: ACCEPT INVITE & AUTO-LEAVE ON LAYER TRANSITION
--------------------------------------------------------------------------------
-- Called on PARTY_INVITE_REQUEST event:
function LayerHopEngine.OnPartyInvite(inviterName)
    if currentAsk and currentAsk.phase == "requesting" then
        local shortHelper = currentAsk.helper:match("^([^%-]+)") or currentAsk.helper
        if inviterName == shortHelper or inviterName == currentAsk.helper then
            -- Auto-accept party invite from our vouched helper
            if AcceptGroup then AcceptGroup() end
            if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
            currentAsk.phase = "joined"
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Hop]|r Joined helper's party. Waiting for shard phase...")
        end
    end
end

-- Called whenever Layers.Mine() observes a confirmed creature zoneUID update:
function LayerHopEngine.OnLayerChanged(newMapID, newZoneUID)
    if currentAsk and currentAsk.phase == "joined" then
        -- Have we arrived on the target layer?
        if newMapID == currentAsk.mapID and newZoneUID == currentAsk.zoneUID then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Hop]|r Phased onto target layer! Leaving party...")

            -- Leave group immediately to free the helper's slot!
            if C_PartyInfo and C_PartyInfo.LeaveParty then
                C_PartyInfo.LeaveParty()
            elseif LeaveParty then
                LeaveParty()
            end

            currentAsk.phase = "done"
            currentAsk = nil
        end
    end
end

--------------------------------------------------------------------------------
-- 8. HELPER SIDE: RELEASE GUEST TICKER (Failsafe)
--------------------------------------------------------------------------------
-- Call this periodically (e.g. every 10s) to release guests who stalled in group:
function LayerHopEngine.ReleaseStaleGuests(sendWhisperFn)
    local now = GetTime()
    for shortName, guest in pairs(activeGuests) do
        if now - guest.t >= LayerHopEngine.GUEST_TIME then
            -- Send release whisper: LX~<id>
            sendWhisperFn(guest.fullName, string.format("LX~%d", guest.id))
            activeGuests[shortName] = nil
        end
    end
end

return LayerHopEngine
