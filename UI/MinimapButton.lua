--[[
    Forever Safari: Minimap Button
    Provides quick access to the Field Guide Journal and Safari Bag, and displays active companion overview on hover.
    Reflects the 4 core stats (Health, Attack, Defense, Speed).
    Features shape-aware rim positioning (supporting round, square, and modern UI minimaps).
    
    Zero-Taint / Anti-Mask Architecture:
    - Parented cleanly to UIParent so it is NEVER clipped by Minimap mask stencils.
    - Synchronized with ForeverSafariSettings with auto-refresh on PLAYER_ENTERING_WORLD.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.MinimapButton = ns.MinimapButton or {}

local MB = ns.MinimapButton
local C = ns.Constants
local DB = ns.Database

local btn = nil

local function GetSavedAngle()
    if ForeverSafariSettings and ForeverSafariSettings.minimap and ForeverSafariSettings.minimap.angle then
        return tonumber(ForeverSafariSettings.minimap.angle) or 220
    end
    if ForeverSafariDB and ForeverSafariDB.settings and ForeverSafariDB.settings.minimapAngle then
        return tonumber(ForeverSafariDB.settings.minimapAngle) or 220
    end
    return 220
end

local function SetSavedAngle(angle)
    if ForeverSafariSettings then
        ForeverSafariSettings.minimap = ForeverSafariSettings.minimap or {}
        ForeverSafariSettings.minimap.angle = angle
    end
    if ForeverSafariDB then
        ForeverSafariDB.settings = ForeverSafariDB.settings or {}
        ForeverSafariDB.settings.minimapAngle = angle
    end
end

local function IsMinimapHidden()
    if ForeverSafariSettings and ForeverSafariSettings.minimap and ForeverSafariSettings.minimap.hide ~= nil then
        return ForeverSafariSettings.minimap.hide == true
    end
    return false
end

local function SetMinimapHidden(hide)
    if ForeverSafariSettings then
        ForeverSafariSettings.minimap = ForeverSafariSettings.minimap or {}
        ForeverSafariSettings.minimap.hide = (hide == true)
    end
end

-- Shape-aware boundary calculation for minimap rim orbit
local function GetMinimapPosition(angle)
    local shape = "ROUND"
    if GetMinimapShape then
        shape = GetMinimapShape()
    elseif Minimap and Minimap.GetMaskTexture then
        local mask = Minimap:GetMaskTexture()
        if not mask or mask == "" then
            shape = "SQUARE"
        end
    end
    
    -- In modern WoW (build >= 10.0 or Midnight/Dragonflight) or if no round mask is present, default to SQUARE
    local isModern = (select(4, GetBuildInfo()) or 0) >= 100000
    if not GetMinimapShape and isModern then
        shape = "SQUARE"
    end

    local rad = math.rad(angle or 220)
    local cos = math.cos(rad)
    local sin = math.sin(rad)
    
    local mw = (Minimap and Minimap:GetWidth()) or 140
    local mh = (Minimap and Minimap:GetHeight()) or 140
    if not mw or mw <= 20 then mw = 140 end
    if not mh or mh <= 20 then mh = 140 end

    local w = (mw / 2) + 10
    local h = (mh / 2) + 10

    if shape == "ROUND" then
        return cos * w, sin * h
    else
        -- Rectangular / Square boundary tracing:
        local absCos = math.abs(cos)
        local absSin = math.abs(sin)
        
        if absCos * h > absSin * w then
            -- Hits vertical edge (Left or Right)
            local x = (cos >= 0) and w or -w
            local y = (cos >= 0) and (sin / cos * w) or (-sin / cos * w)
            return x, y
        else
            -- Hits horizontal edge (Top or Bottom)
            local y = (sin >= 0) and h or -h
            local x = (sin >= 0) and (cos / sin * h) or (-cos / sin * h)
            return x, y
        end
    end
end

function MB:Initialize()
    if btn then
        MB:UpdatePosition()
        return btn
    end

    -- Parent strictly to UIParent to prevent Minimap mask clipping!
    btn = CreateFrame("Button", "ForeverSafariMinimapButton", UIParent)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(20)
    btn:SetClampedToScreen(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-Button-Highlight")

    -- Circular Background (so transparent minimaps do not bleed through)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(21, 21)
    bg:SetPoint("CENTER", 0, 0)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    btn.Background = bg

    -- Icon texture (Safari Paw / Beast Taming icon)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.Icon = icon

    -- Circular Golden Tracking Border
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn.Border = border

    -- Click Handlers
    btn:SetScript("OnClick", function(self, button)
        if IsShiftKeyDown() or button == "MiddleButton" then
            if ForeverSafari.JournalFrame then
                ForeverSafari.JournalFrame:ShowTab("BOUNTIES")
            end
        elseif button == "LeftButton" then
            if ForeverSafari.JournalFrame then
                ForeverSafari.JournalFrame:Toggle()
            end
        elseif button == "RightButton" then
            if ForeverSafari.SafariBagFrame then
                ForeverSafari.SafariBagFrame:Toggle()
            end
        end
    end)

    -- Drag Handlers (Smooth Minimap Rim Orbit)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            if not Minimap then return end
            local mx, my = Minimap:GetCenter()
            if not mx or not my then return end
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))
            if angle < 0 then angle = angle + 360 end
            SetSavedAngle(angle)
            MB:UpdatePosition()
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    -- Tooltip Handlers
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffffd100Forever Safari|r - Hemet's Safari", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local activeMob = DB and DB.GetActiveMob and DB:GetActiveMob()
        if activeMob then
            local cType = activeMob.creatureType or activeMob.family or activeMob.element or "Beast"
            local typeData = C.CREATURE_TYPES[cType] or {}
            local typeColor = typeData.color or "ffffff"
            local petName = (activeMob.customNickname and activeMob.customNickname ~= "" and activeMob.customNickname)
                or (activeMob.nickname and activeMob.nickname ~= "" and activeMob.nickname)
                or activeMob.name
                or "Companion"
            local rankData = (ForeverSafari.StatEngine and ForeverSafari.StatEngine.GetAttunementRank and ForeverSafari.StatEngine:GetAttunementRank(activeMob.attunement or activeMob.attunementPoints or 0)) or C.ATTUNEMENT_RANKS[activeMob.attunementRank or 1] or C.ATTUNEMENT_RANKS[1]
            local rankRoman = (rankData and rankData.roman) or "I"
            local curHP = activeMob.currentHP or activeMob.hp or 60
            local maxHP = activeMob.maxHP or activeMob.hp or 60
            local atk = activeMob.atk or activeMob.attack or 10
            local def = activeMob.def or activeMob.defense or 8
            local spd = activeMob.spd or activeMob.speed or 12

            GameTooltip:AddDoubleLine("Active Companion:", string.format("|cff%s%s|r (Rank %s %s)", typeColor, petName, rankRoman, cType))
            GameTooltip:AddDoubleLine("Health:", string.format("%d / %d", curHP, maxHP), 0.2, 0.8, 0.4, 1, 1, 1)
            GameTooltip:AddDoubleLine("Stats:", string.format("ATK: %d | DEF: %d | SPD: %d", atk, def, spd), 1, 0.85, 0.2, 1, 1, 1)
        else
            GameTooltip:AddLine("|cffaaaaaaNo active companion selected.|r")
        end

        GameTooltip:AddLine(" ")
        local tokenBal = (DB and DB.GetTokens and DB:GetTokens()) or 0
        GameTooltip:AddDoubleLine("Safari Tokens Balance:", string.format("|cffffd100%d|r", tokenBal))
        local totalCap = (ForeverSafariDB and ForeverSafariDB.stats and ForeverSafariDB.stats.totalCaptured) or 0
        GameTooltip:AddDoubleLine("Total Captured:", string.format("|cff00ff99%d|r", totalCap))

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00<Left Click>|r Open Field Guide & Team")
        GameTooltip:AddLine("|cff00ff00<Right Click>|r Open Virtual Safari Bag")
        GameTooltip:AddLine("|cff00ff00<Middle Click>|r or |cff00ff00<Shift-Click>|r View Field Directives")
        GameTooltip:AddLine("|cffaaaaaa<Drag>|r Move Minimap Button")
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Auto-hook Minimap size changes
    if Minimap and Minimap.HookScript then
        pcall(function()
            Minimap:HookScript("OnSizeChanged", function()
                MB:UpdatePosition()
            end)
        end)
    end

    -- Event listener for world load and login
    local evt = CreateFrame("Frame", nil, btn)
    evt:RegisterEvent("PLAYER_LOGIN")
    evt:RegisterEvent("PLAYER_ENTERING_WORLD")
    evt:RegisterEvent("VARIABLES_LOADED")
    evt:SetScript("OnEvent", function(self, event)
        MB:UpdatePosition()
        C_Timer.After(0.5, function() MB:UpdatePosition() end)
        C_Timer.After(2.0, function() MB:UpdatePosition() end)
    end)

    MB:UpdatePosition()
    return btn
end

function MB:UpdatePosition()
    if not btn or not Minimap then return end

    if IsMinimapHidden() then
        btn:Hide()
        return
    end

    local angle = GetSavedAngle()
    local x, y = GetMinimapPosition(angle)

    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    btn:Show()
end

function MB:Show()
    SetMinimapHidden(false)
    MB:UpdatePosition()
end

function MB:Hide()
    SetMinimapHidden(true)
    if btn then btn:Hide() end
end

function MB:Toggle()
    if IsMinimapHidden() then
        MB:Show()
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff00Minimap icon shown.|r")
    else
        MB:Hide()
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffffaa00Minimap icon hidden. Type |cffffd100/fs minimap|r to restore.|r")
    end
end

function MB:ResetPosition()
    SetSavedAngle(220)
    SetMinimapHidden(false)
    MB:UpdatePosition()
    DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff00Minimap icon reset to bottom-left bezel (220°).|r")
end
