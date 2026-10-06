--[[
    Forever Safari: Minimap Button
    Provides quick access to the Field Guide Journal, Safari Bag, Safari Dispatch, and displays active companion overview on hover.
    Reflects the 4 core stats (Health, Attack, Defense, Speed).
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.MinimapButton = ns.MinimapButton or {}

local MB = ns.MinimapButton
local C = ns.Constants
local DB = ns.Database

local btn = nil

function MB:Initialize()
    btn = CreateFrame("Button", "ForeverSafariMinimapButton", UIParent)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 5) + 5)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-Button-Highlight")

    -- Icon texture
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.Icon = icon

    -- Circular Border
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Click Handlers
    btn:SetScript("OnClick", function(self, button)
        if IsShiftKeyDown() or button == "MiddleButton" then
            if ForeverSafari.SafariMailFrame then
                ForeverSafari.SafariMailFrame:ToggleStandalone()
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

    -- Drag Handlers
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            px, py = px / scale, py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))
            if angle < 0 then angle = angle + 360 end
            ForeverSafariDB.settings = ForeverSafariDB.settings or {}
            ForeverSafariDB.settings.minimapAngle = angle
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

        local activeMob = DB:GetActiveMob()
        if activeMob then
            local typeData = C.CREATURE_TYPES[activeMob.creatureType] or {}
            local typeColor = typeData.color or "ffffff"
            GameTooltip:AddDoubleLine("Active Companion:", string.format("|cff%s%s|r (Lv %d %s)", typeColor, activeMob.nickname ~= "" and activeMob.nickname or activeMob.name, activeMob.level, activeMob.creatureType))
            GameTooltip:AddDoubleLine("Health:", string.format("%d / %d", activeMob.currentHP, activeMob.maxHP), 0.2, 0.8, 0.4, 1, 1, 1)
            GameTooltip:AddDoubleLine("Stats:", string.format("ATK: %d | DEF: %d | SPD: %d", activeMob.atk or 10, activeMob.def or 8, activeMob.spd or 12), 1, 0.85, 0.2, 1, 1, 1)
        else
            GameTooltip:AddLine("|cffaaaaaaNo active companion selected.|r")
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Safari Tokens Balance:", string.format("|cffffd100%d|r", DB:GetTokens()))
        GameTooltip:AddDoubleLine("Total Captured:", string.format("|cff00ff99%d|r", ForeverSafariDB.stats.totalCaptured or 0))

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00<Left Click>|r Open Field Guide & Team")
        GameTooltip:AddLine("|cff00ff00<Right Click>|r Open Virtual Safari Bag")
        GameTooltip:AddLine("|cff00ff00<Middle Click>|r or |cff00ff00<Shift-Click>|r Safari Dispatch & Bounties")
        GameTooltip:AddLine("|cffaaaaaa<Drag>|r Move Minimap Button")
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    MB:UpdatePosition()
end

function MB:UpdatePosition()
    if not btn then return end
    local angle = (ForeverSafariDB.settings and ForeverSafariDB.settings.minimapAngle) or 45
    local rad = math.rad(angle)
    local cos = math.cos(rad)
    local sin = math.sin(rad)
    local radius = 80

    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", cos * radius, sin * radius)
end
