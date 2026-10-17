--[[
    Forever Safari: Virtual Combat Ambush Debuff Frame
    Renders an authentic, standalone virtual debuff in the player's aura area
    when a companion battle is suspended due to real world combat.
    
    Zero-Taint Architecture:
    - Exclusively standalone UI parented to UIParent.
    - Zero hooks into UnitAura, BuffFrame, or protected Blizzard frames.
    - Zero server-side check interference.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.VirtualDebuff = ns.VirtualDebuff or {}

local VirtualDebuff = ns.VirtualDebuff
local C = ns.Constants

local debuffFrame = nil
local ticker = nil

local function EnsureDebuffFrame()
    if debuffFrame then return debuffFrame end

    -- Standalone Frame parented strictly to UIParent (Zero Blizzard Taint)
    debuffFrame = CreateFrame("Button", "ForeverSafariVirtualDebuffFrame", UIParent)
    debuffFrame:SetSize(32, 32)
    debuffFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -215, -95)
    debuffFrame:SetFrameStrata("MEDIUM")
    debuffFrame:SetClampedToScreen(true)
    debuffFrame:EnableMouse(true)
    debuffFrame:RegisterForDrag("LeftButton")

    -- Allow Shift+Drag to reposition for custom UI suites (ElvUI, Tukui, etc.)
    debuffFrame:SetMovable(true)
    debuffFrame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    debuffFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- Spell Icon (Ability_Ambush)
    local icon = debuffFrame:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(30, 30)
    icon:SetPoint("CENTER", debuffFrame, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\Ability_Ambush")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    debuffFrame.Icon = icon

    -- Authentic Blizzard Red Debuff Border Overlay
    local border = debuffFrame:CreateTexture(nil, "OVERLAY")
    border:SetSize(35, 35)
    border:SetPoint("CENTER", debuffFrame, "CENTER", 0, 0)
    border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    border:SetVertexColor(1.0, 0.15, 0.15, 1.0)
    debuffFrame.Border = border

    -- Duration Timer Text (centered below icon)
    local durationText = debuffFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    durationText:SetPoint("TOP", debuffFrame, "BOTTOM", 0, -3)
    durationText:SetTextColor(1.0, 0.82, 0.0)
    debuffFrame.DurationText = durationText

    -- Mouseover Tooltip Handler
    debuffFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Battle Suspended", 1.0, 0.2, 0.2)
        GameTooltip:AddLine("World Combat Ambush", 1.0, 0.82, 0.0)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("A roaming creature engaged you in real combat. Your companion battle is frozen in memory.", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" ", 1, 1, 1)

        local BE = ns.BattleEngine
        local isPvP = BE and BE.State and BE.State.isPvP
        GameTooltip:AddDoubleLine("Status:", isPvP and "|cffffaa00PvP Duel Suspended|r" or "|cffffaa00Wild Battle Suspended|r", 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Safe Recovery Window:", string.format("%ds (Max %ds)", math.ceil(self.remaining or 120), math.floor(self.maxDuration or 120)), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cff00ff00Clear world combat to automatically resume battle.|r", 0.2, 1.0, 0.2, true)
        GameTooltip:AddLine("|cffff4444Exceeding 120s or logging out will forfeit the match.|r", 1.0, 0.3, 0.3, true)
        GameTooltip:AddLine("|cff888888(Shift+Left-Click Drag to reposition debuff)|r", 0.5, 0.5, 0.5, true)
        GameTooltip:Show()
    end)

    debuffFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    debuffFrame:Hide()
    return debuffFrame
end

local function FormatDuration(seconds)
    if seconds >= 60 then
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%d:%02d", mins, secs)
    else
        return string.format("%ds", math.ceil(seconds))
    end
end

function VirtualDebuff:ShowSuspension(duration, onExpire)
    duration = duration or 120.0
    local f = EnsureDebuffFrame()
    f.remaining = duration
    f.maxDuration = duration
    f.onExpire = onExpire

    if ticker and ticker.Cancel then
        ticker:Cancel()
        ticker = nil
    end

    f.DurationText:SetText(FormatDuration(f.remaining))
    f.DurationText:SetTextColor(1.0, 0.82, 0.0)
    f:SetAlpha(1)
    f:Show()

    PlaySound(847) -- Subtle debuff sound

    ticker = C_Timer.NewTicker(1.0, function()
        f.remaining = f.remaining - 1.0
        if f.remaining <= 0 then
            if ticker and ticker.Cancel then
                ticker:Cancel()
                ticker = nil
            end
            f:Hide()
            if f.onExpire then
                f.onExpire()
            end
        else
            f.DurationText:SetText(FormatDuration(f.remaining))
            if f.remaining <= 30 then
                f.DurationText:SetTextColor(1.0, 0.2, 0.2)
            else
                f.DurationText:SetTextColor(1.0, 0.82, 0.0)
            end

            -- Update tooltip if currently hovering
            if GameTooltip:IsOwned(f) then
                f:GetScript("OnEnter")(f)
            end
        end
    end)
end

function VirtualDebuff:HideSuspension()
    if ticker and ticker.Cancel then
        ticker:Cancel()
        ticker = nil
    end

    if debuffFrame and debuffFrame:IsShown() then
        if GameTooltip:IsOwned(debuffFrame) then
            GameTooltip:Hide()
        end
        debuffFrame:Hide()
    end
end

function VirtualDebuff:IsSuspended()
    return debuffFrame and debuffFrame:IsShown()
end
