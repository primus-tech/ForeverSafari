--[[
    Forever Safari: Stalking & Channeling Capture Engine ("Field Research" Snare)
    Decouples creature capture from world-mob HP.
    Mechanics:
    - 0% Mob Damage: Live quarry remains untouched at 100% HP, un-tagged, left alive for Hunters and world adventurers.
    - Proximity & Stalking: Proximity detection via CheckInteractDistance (Close Stalk ~10 yd gives +25% bonus; Perimeter ~28 yd).
    - Net Channeling: 3.0 to 5.0s channeled snare cast minigame with live LoS and distance tracking.
    - Capture Minigame Resolution: Net Power * Distance Bonus * Level Delta * Apex Rarity Resistance.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.CaptureEngine = ns.CaptureEngine or {}

local CE = ns.CaptureEngine
local C = ns.Constants
local DB = ns.Database
local SE = ns.StatEngine

local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then
        return true
    end
    return false
end

local function SafeCheckInteractDistance(unit, index)
    if not unit or not UnitExists(unit) then return false end
    local ok, inRange = pcall(CheckInteractDistance, unit, index)
    if ok and not isSecret(inRange) and inRange == true then
        return true
    end
    return false
end

-- Active Channel State
CE.ChannelState = {
    isChanneling = false,
    unit = "target",
    cageId = "copper_cage",
    targetName = "Wild Creature",
    creatureType = "Beast",
    level = 1,
    isElite = false,
    displayId = 181,
    duration = 5.0,
    elapsed = 0,
    lastDistTier = "PERIMETER",
}

-- Proximity & Stalking Distance Check
-- Returns: tierKey ("CLOSE", "PERIMETER", "OUT_OF_RANGE", "NONE"), multiplier (1.25, 1.00, 0.0), statusText, colorHex
function CE:GetStalkingDistance(unit)
    unit = unit or "target"
    if not UnitExists(unit) then
        return "NONE", 0.0, "No Target", "888888"
    end

    -- Close Stalk (~10 yards, CheckInteractDistance 3 = duel/trade range) -> High Risk, High Reward (+25% catch)
    if SafeCheckInteractDistance(unit, 3) then
        return "CLOSE", 1.25, "Close Stalk (~10 yd) - Optimal Focus (+25% Catch Bonus)", "00ff99"
    end

    -- Standard Stalking Perimeter (~15-28 yards, CheckInteractDistance 4 = follow/inspect range)
    if SafeCheckInteractDistance(unit, 4) then
        return "PERIMETER", 1.00, "In Perimeter (15-28 yd) - Standard Tension", "ffd100"
    end

    -- Beyond stalking perimeter (>28 yards)
    return "OUT_OF_RANGE", 0.00, "Out of Range (>28 yd) - Close the Distance!", "ff4444"
end

-- Validate if player can initiate an observation channel on the unit
function CE:CanInitiateSnare(unit)
    unit = unit or "target"
    if not UnitExists(unit) then return false, "No quarry selected." end
    if UnitIsDead(unit) then return false, "Quarry is dead." end
    if UnitIsPlayer(unit) then return false, "Cannot observe players!" end

    local reaction = UnitReaction("player", unit)
    if not isSecret(reaction) and reaction and reaction > 4 then
        return false, "Target is a friendly NPC."
    end

    local classification = UnitClassification(unit)
    if classification == "worldboss" then
        return false, "World Bosses cannot be observed in the field!"
    end

    -- Check if in stalking range (within 28 yards)
    local inRange = SafeCheckInteractDistance(unit, 4)
    if not inRange then
        return false, "Quarry is too far away (>28 yd). Close the distance!"
    end

    local rawType = UnitCreatureType(unit)
    if isSecret(rawType) then rawType = "Beast" end
    local name = UnitName(unit)
    if isSecret(name) then name = "Wild Creature" end
    local creatureType = C.NormalizeCreatureType(rawType, name)

    if rawType == "Humanoid" or rawType == "Giant" or creatureType == "Humanoid" or (C.ELIGIBLE_CAPTURE_TYPES and not C.ELIGIBLE_CAPTURE_TYPES[creatureType]) then
        return false, "Humanoids and civilized targets cannot be observed for wild techniques!"
    end

    if not DB:IsTypeUnlocked(creatureType) then
        local permit = C.TYPE_RESEARCH_PERMITS and C.TYPE_RESEARCH_PERMITS[creatureType]
        local permitName = permit and permit.name or (creatureType .. " Research Permit")
        return false, string.format("%s research locked! Complete quest to earn [%s].", creatureType, permitName)
    end

    return true, "Eligible"
end

-- Calculate Catch Rate Threshold and Roll Details
-- Returns: success (bool), roll (0-1), finalThreshold (0-1), distTier, distMod, rarityMod
function CE:CalculateSnareRoll(unit, cageId)
    unit = unit or "target"
    cageId = cageId or "copper_cage"

    local cageData = C.CAGES[cageId] or C.CAGES["copper_cage"]
    local baseCatchRate = cageData.catchPower or (cageData.rateMultiplier and (cageData.rateMultiplier * 0.35)) or 0.35

    -- Distance Modifier
    local distTier, distMod, distText, distColor = CE:GetStalkingDistance(unit)
    if distMod <= 0 then distMod = 1.0 end

    -- Level Modifier
    local playerLevel = UnitLevel("player") or 1
    local targetLevel = UnitLevel(unit) or 1
    local levelMod = 1.0
    if not isSecret(playerLevel) and not isSecret(targetLevel) and type(playerLevel) == "number" and type(targetLevel) == "number" then
        if targetLevel > playerLevel then
            local diff = targetLevel - playerLevel
            levelMod = math.max(0.70, 1.0 - (diff * 0.03))
        elseif targetLevel < playerLevel then
            local diff = playerLevel - targetLevel
            levelMod = math.min(1.20, 1.0 + (diff * 0.01))
        end
    end

    -- Rare Apex Quarry Resistance Modifier
    local classification = UnitClassification(unit)
    local isRare = (classification == "rare" or classification == "rareelite")
    local isElite = (classification == "elite")
    local rarityMod = isRare and 0.50 or (isElite and 0.70 or 1.0)

    -- Calculate final threshold (clamped 5% to 99%)
    local finalThreshold = baseCatchRate * distMod * levelMod * rarityMod
    finalThreshold = math.min(0.99, math.max(0.05, finalThreshold))

    local roll = math.random()
    local success = (roll <= finalThreshold)

    return success, roll, finalThreshold, distTier, distMod, rarityMod
end

-- Get current capture probability for UI / HUD displays
function CE:GetCaptureRate(unit, cageId)
    unit = unit or "target"
    cageId = cageId or "copper_cage"

    if not UnitExists(unit) or UnitIsDead(unit) or UnitIsPlayer(unit) then
        return 0, "Invalid Target"
    end

    local distTier, distMod, distText, distColor = CE:GetStalkingDistance(unit)
    if distTier == "OUT_OF_RANGE" then
        return 0, "Out of Range"
    end

    local _, _, threshold = CE:CalculateSnareRoll(unit, cageId)
    return threshold, distText
end

-- Check if currently channeling
function CE:IsChanneling()
    return CE.ChannelState.isChanneling == true
end

-- Start Observation Channeling Sequence
function CE:StartSnareChannel(unit, cageId)
    unit = unit or "target"

    -- Check if already channeling
    if CE.ChannelState.isChanneling then
        CE:CancelSnareChannel("Observation interrupted by new command.")
    end

    local canObserve, reason = CE:CanInitiateSnare(unit)
    if not canObserve then
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Cannot Observe", reason)
        end
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444" .. reason .. "|r")
        return false
    end

    local name = UnitName(unit)
    if isSecret(name) or not name or name == "" then name = "Wild Creature" end

    local rawType = UnitCreatureType(unit) or "Unknown"
    if isSecret(rawType) then rawType = "Unknown" end

    local creatureType = C.NormalizeCreatureType(rawType, name)
    local level = UnitLevel(unit)
    if isSecret(level) or not level or level <= 0 then 
        local pLvl = UnitLevel("player")
        level = (not isSecret(pLvl) and pLvl) or 1 
    end
    local isElite = UnitClassification(unit) == "elite" or UnitClassification(unit) == "rareelite"
    local displayId = C.GetDefaultDisplayId(creatureType, name)

    local channelDuration = 4.0

    -- Set active channel state
    CE.ChannelState.isChanneling = true
    CE.ChannelState.unit = unit
    CE.ChannelState.cageId = cageId
    CE.ChannelState.targetName = name
    CE.ChannelState.creatureType = creatureType
    CE.ChannelState.level = level
    CE.ChannelState.isElite = isElite
    CE.ChannelState.displayId = displayId
    CE.ChannelState.duration = channelDuration
    CE.ChannelState.elapsed = 0

    -- Play start audio
    PlaySound(844) -- SOUNDKIT.IG_SPELLBOOK_OPEN

    DEFAULT_CHAT_FRAME:AddMessage(string.format("%sBegan observing & studying |cffffd100%s|r (Channel: %.1fs)... Maintain line of sight & range!", 
        C.PREFIX, name, channelDuration))

    -- Notify HUD to show channeling bar
    if ForeverSafari.CaptureHUD and ForeverSafari.CaptureHUD.StartChannelBar then
        ForeverSafari.CaptureHUD:StartChannelBar(name, channelDuration, "Field Study")
    end

    return true
end

-- Cancel active channeling
function CE:CancelSnareChannel(reason)
    if not CE.ChannelState.isChanneling then return end
    CE.ChannelState.isChanneling = false

    if ForeverSafari.CaptureHUD and ForeverSafari.CaptureHUD.StopChannelBar then
        ForeverSafari.CaptureHUD:StopChannelBar(reason or "Observation Cancelled")
    end

    if reason then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Observation cancelled: " .. reason .. "|r")
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Observation Interrupted", reason)
        end
    end
end

-- Complete Channeling & Resolve Field Move Observation
function CE:CompleteSnareChannel()
    if not CE.ChannelState.isChanneling then return end
    CE.ChannelState.isChanneling = false

    local state = CE.ChannelState
    local unit = state.unit or "target"

    PlaySound(1195) -- SOUNDKIT.IG_QUEST_LOG_COMPLETE

    -- Look up creature's abilities in CreatureDB or default family moves
    local discoveredMove = nil
    local targetName = state.targetName or "Wild Creature"
    local cType = state.creatureType or "Beast"

    -- Bestiary Sighting Discovery
    if DB and DB.DiscoverSpecies then
        DB:DiscoverSpecies(targetName, "seen")
    end

    if ForeverSafari.CreatureDB then
        for _, entry in pairs(ForeverSafari.CreatureDB) do
            if entry.name and string.lower(entry.name) == string.lower(targetName) and entry.abilities then
                for _, moveKey in ipairs(entry.abilities) do
                    if not DB:IsAbilityUnlocked(moveKey) then
                        discoveredMove = moveKey
                        break
                    end
                end
                if discoveredMove then break end
            end
        end
    end

    -- Fallback check for family moves
    if not discoveredMove and C.FAMILY_MOVES and C.FAMILY_MOVES[cType] then
        for _, moveKey in ipairs(C.FAMILY_MOVES[cType]) do
            if not DB:IsAbilityUnlocked(moveKey) then
                discoveredMove = moveKey
                break
            end
        end
    end

    if discoveredMove then
        DB:UnlockAbility(discoveredMove, targetName, false)
        local moveData = C.ABILITIES[discoveredMove]
        local mName = moveData and moveData.name or discoveredMove
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[Field Research Complete]|r Successfully observed |cffffd100%s|r and learned technique: |cffffd100[%s]|r!",
            C.PREFIX, targetName, mName))
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowReward("Technique Mastered", string.format("Learned [%s] from %s!", mName, targetName))
        end
        if ForeverSafari.CaptureHUD and ForeverSafari.CaptureHUD.ShowCaptureResult then
            ForeverSafari.CaptureHUD:ShowCaptureResult(true, string.format("Learned [%s]!", mName), 1.0)
        end
    else
        -- If all family moves already mastered, award Zone Acclimation / Attunement
        local activeMob = DB:GetActiveMob()
        if activeMob then
            DB:AddAttunement(activeMob.id, 15, "Observed wild " .. targetName)
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[Field Research Complete]|r Observed |cffffd100%s|r in its natural habitat! All moves already mastered; active companion gained +15 Attunement.",
            C.PREFIX, targetName))
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Field Observation", string.format("Studied %s! (+15 Attunement)", targetName))
        end
        if ForeverSafari.CaptureHUD and ForeverSafari.CaptureHUD.ShowCaptureResult then
            ForeverSafari.CaptureHUD:ShowCaptureResult(true, "Observation Complete (+15 Attunement)", 1.0)
        end
    end
end

-- Primary Attempt Capture Trigger (Entry point for UI buttons and /fsnet)
function CE:AttemptCapture(unit, cageId)
    unit = unit or "target"
    cageId = cageId or "copper_cage"

    if CE.ChannelState.isChanneling then
        -- Clicking again while channeling acts as a cancel
        CE:CancelSnareChannel("Cancelled by player.")
        return false
    else
        return CE:StartSnareChannel(unit, cageId)
    end
end

-- Channeling Update Heartbeat Frame
local updateFrame = CreateFrame("Frame", "ForeverSafariCaptureEngineHeartbeat")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not CE.ChannelState.isChanneling then return end

    local state = CE.ChannelState
    local unit = state.unit or "target"

    -- 1. Check if unit still exists
    if not UnitExists(unit) then
        CE:CancelSnareChannel("Target lost / deselected.")
        return
    end

    -- 2. Check if unit died
    if UnitIsDead(unit) then
        CE:CancelSnareChannel("Target died.")
        return
    end

    -- 3. Check stalking range & Line of Sight
    if not CheckInteractDistance(unit, 4) then
        CE:CancelSnareChannel("Quarry moved out of stalking range (>28 yd).")
        return
    end

    -- Advance elapsed channeling time
    state.elapsed = state.elapsed + elapsed

    -- Update HUD Progress Bar
    if ForeverSafari.CaptureHUD and ForeverSafari.CaptureHUD.UpdateChannelProgress then
        ForeverSafari.CaptureHUD:UpdateChannelProgress(state.elapsed, state.duration)
    end

    -- Complete when timer reaches duration
    if state.elapsed >= state.duration then
        CE:CompleteSnareChannel()
    end
end)
