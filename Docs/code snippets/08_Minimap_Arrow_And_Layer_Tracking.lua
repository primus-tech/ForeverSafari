--[[
================================================================================
OLYMPUS CODE SNIPPET #8: MINIMAP ARROW & CROSS-LAYER TRACKING ("ASMON ARROW")
================================================================================
Origin: Olympus Addon (KingArrow.lua, Layers.lua, Hop.lua, Positions.lua)
Context: World of Warcraft Classic Multi-Layer Sharding & VIP Tracking

PROBLEM IT SOLVES:
------------------
In WoW Classic / Vanilla, servers partition high-population zones into multiple
parallel virtual copies called "Layers" (shards).
1. The WoW API provides ZERO native functions to tell an addon which layer
   the player is currently on.
2. If a streamer/leader like Asmongold ("The King" in Olympus) is in Stormwind,
   thousands of players in Stormwind cannot see him if they are on Layer 2
   while he is on Layer 1.
3. How can an addon:
   a) Accurately discover which layer a player is on?
   b) Share that layer across guild and realm channels?
   c) Render a minimap pointer arrow that visually indicates whether you are
      on his exact layer, on a different layer, or in another zone?
   d) Coordinate invites to phase players onto his layer?

SOLUTION:
---------
1. NPC GUID "ZONE UID" SNOOPING (Layers.lua):
   In modern Classic WoW, creature GUIDs have a standard format:
     "Creature-0-server-instance-zoneUID-npc-spawn"
   By parsing `strsplit("-", UnitGUID("target"))`, field 5 is `zoneUID`.
   Every player on the same layer in that zone observes the exact same `zoneUID`
   on nearby creatures! If two players in Stormwind have different `zoneUID`s,
   they are on different layers.

2. TWO-CREATURE HYSTERESIS FILTER:
   Creatures near zone borders can spawn on neighbouring shards. To prevent
   false layer-flipping, Olympus requires observing at least two distinct
   creature GUIDs with the same `zoneUID` within 15s (`EVIDENCE_WINDOW`) before
   accepting a new layer.

3. VIP LOCATION & LAYER BROADCAST:
   - Location: `P1~<mapID>~<x>~<y>` broadcast via `Positions.lua` / `King.lua`.
   - Layer: `L1~<mapID>~<zoneUID>~<rank>~<guild>` broadcast via `Layers.lua`.
   Asmongold's client repeats his location every 20s and layer every 55s.

4. THREE-STATE MINIMAP ARROW (KingArrow.lua):
   - State 1: "EXACT" (Same Zone + Same Layer):
     `mine.mapID == at.mapID` AND `mine.zoneUID == there.zoneUID`
     Arrow is rendered full-opacity, bright white (100% alpha).
   - State 2: "MAYBE" (Same Zone + Different Layer):
     `mine.mapID == at.mapID` AND `mine.zoneUID ~= there.zoneUID`
     You are standing in the exact same physical area, but on a parallel layer.
     The arrow renders tinted blue, 55% transparent, and desaturated.
   - State 3: "ZONE" (Different Zone, Same Continent):
     Uses HereBeDragons-2.0 to translate map coordinates to world coordinates.
     The tinted arrow points toward his world position across zones!

5. LAYER HOPPING (Hop.lua):
   If Asmon is on another layer, `Hop.lua` finds Olympus members already on his
   layer and sends an automated invite request (`LQ~`) to phase the player.

================================================================================
]]

local LayerTrackingEngine = {}

--------------------------------------------------------------------------------
-- 1. EXTRACT ZONE UID FROM CREATURE GUID
--------------------------------------------------------------------------------
-- The secret sauce: Field 5 of a Creature/Vehicle GUID is the layer's zoneUID!
function LayerTrackingEngine.GetZoneUIDFromGUID(guid)
    if not guid then return nil end
    local unitType, _, _, _, zoneUID = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then
        return nil
    end
    return tonumber(zoneUID)
end

--------------------------------------------------------------------------------
-- 2. LOCAL LAYER DETECTOR (With Two-Creature Confirmation Filter)
--------------------------------------------------------------------------------
local currentLayerState = nil -- { mapID, zoneUID, t, confirmedAt }
local pendingLayerObservation = nil

function LayerTrackingEngine.ObserveUnit(unitID)
    if IsInInstance() then return end
    local guid = UnitGUID(unitID)
    local zoneUID = LayerTrackingEngine.GetZoneUIDFromGUID(guid)
    local mapID = C_Map.GetBestMapForUnit("player")

    if not zoneUID or not mapID then return end
    local now = GetTime()

    -- Case A: Still seeing creatures on our current confirmed layer
    if currentLayerState and currentLayerState.mapID == mapID and currentLayerState.zoneUID == zoneUID then
        currentLayerState.t = now
        pendingLayerObservation = nil
        return currentLayerState
    end

    -- Case B: Observing a new layer candidate
    if not pendingLayerObservation or pendingLayerObservation.zoneUID ~= zoneUID or (now - pendingLayerObservation.t > 15) then
        pendingLayerObservation = { zoneUID = zoneUID, guids = { [guid] = true }, n = 1, t = now }
        return currentLayerState
    end

    -- Record second unique creature observation
    if not pendingLayerObservation.guids[guid] then
        pendingLayerObservation.guids[guid] = true
        pendingLayerObservation.n = pendingLayerObservation.n + 1
    end

    -- Require at least 2 distinct creature GUIDs to switch layers (prevents border flickering)
    if pendingLayerObservation.n >= 2 then
        currentLayerState = {
            mapID       = mapID,
            zoneUID     = zoneUID,
            t           = now,
            confirmedAt = now,
        }
        pendingLayerObservation = nil
    end

    return currentLayerState
end

function LayerTrackingEngine.GetMyLayer()
    return currentLayerState
end

--------------------------------------------------------------------------------
-- 3. EVALUATE ARROW STATE (Cross-Layer Target Comparison)
--------------------------------------------------------------------------------
-- targetPos: { mapID, x, y, t, from }
-- targetLayer: { mapID, zoneUID, t }
-- Returns: state ("exact", "maybe", or nil), reason
function LayerTrackingEngine.EvaluateTarget(targetPos, targetLayer, myLayer)
    if not targetPos or not targetPos.mapID then return nil, "offline" end

    local now = GetTime()
    if (now - (targetPos.t or 0)) > 45 then return nil, "offline" end

    local myMap = C_Map.GetBestMapForUnit("player")
    if not myMap then return nil, "no_map" end

    -- 1. Check if in different zone
    if myMap ~= targetPos.mapID then
        -- In different zone: requires HereBeDragons continent comparison
        return "maybe", "different_zone"
    end

    -- 2. Both in the same zone: Check layer state
    if not myLayer or not targetLayer then
        return "maybe", "layer_unknown"
    end

    -- Stale check: layer reports must be under 120s old
    if (now - myLayer.t > 120) or (now - targetLayer.t > 120) then
        return "maybe", "layer_stale"
    end

    -- 3. Compare ZoneUIDs:
    if myLayer.zoneUID == targetLayer.zoneUID then
        -- BINGO: Standing in the same zone on the EXACT SAME LAYER!
        return "exact", "same_layer"
    else
        -- Standing in the same zone, but on a PARALLEL LAYER!
        return "maybe", "different_layer"
    end
end

--------------------------------------------------------------------------------
-- 4. MINIMAP ARROW RENDERER
--------------------------------------------------------------------------------
local arrowFrame = nil

function LayerTrackingEngine.CreateArrowFrame()
    if arrowFrame then return arrowFrame end

    local f = CreateFrame("Frame", "OlympusKingArrowFrame", Minimap)
    f:SetSize(26, 26)
    f:SetFrameLevel(Minimap:GetFrameLevel() + 2)
    f:EnableMouse(false)

    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    icon:SetAtlas("UI-HUD-Minimap-Arrow-Player")
    icon:SetBlendMode("ADD")
    f.icon = icon

    arrowFrame = f
    return f
end

-- Tints according to exact vs cross-layer state
local TINTS = {
    exact = { r = 1.0, g = 1.0, b = 1.0, a = 1.0, desaturate = false },
    maybe = { r = 0.55, g = 0.75, b = 1.0, a = 0.55, desaturate = true },
}

function LayerTrackingEngine.UpdateArrowVisuals(state)
    if not arrowFrame then return end

    if not state then
        arrowFrame:Hide()
        return
    end

    local tint = TINTS[state]
    if tint then
        arrowFrame.icon:SetVertexColor(tint.r, tint.g, tint.b, tint.a)
        if arrowFrame.icon.SetDesaturated then
            arrowFrame.icon:SetDesaturated(tint.desaturate)
        end
        arrowFrame:Show()
    end
end

return LayerTrackingEngine
