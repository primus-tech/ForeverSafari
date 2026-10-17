--[[
    Forever Safari: Toast Notification System
    Renders elegant animated pop-ups for captures, quest token rewards, and attunement rank advancements.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Toast = ns.Toast or {}

local Toast = ns.Toast
local C = ns.Constants

local toastFrame = nil
local toastQueue = {}
local isDisplaying = false

local function EnsureToastFrame()
    if toastFrame then return toastFrame end

    toastFrame = CreateFrame("Frame", "ForeverSafariToastFrame", UIParent, "BackdropTemplate")
    toastFrame:SetSize(320, 70)
    toastFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    toastFrame:SetFrameStrata("HIGH")
    toastFrame:SetClampedToScreen(true)

    toastFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    toastFrame:SetBackdropColor(0.06, 0.08, 0.12, 0.95)
    toastFrame:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9)

    -- Icon
    local icon = toastFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(42, 42)
    icon:SetPoint("LEFT", toastFrame, "LEFT", 14, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    toastFrame.Icon = icon

    -- Title
    local title = toastFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
    title:SetPoint("TOPRIGHT", toastFrame, "TOPRIGHT", -10, -2)
    title:SetJustifyH("LEFT")
    toastFrame.Title = title

    -- Subtitle
    local sub = toastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetPoint("BOTTOMRIGHT", toastFrame, "BOTTOMRIGHT", -10, 8)
    sub:SetJustifyH("LEFT")
    toastFrame.Sub = sub

    toastFrame:Hide()
    return toastFrame
end

local function ProcessQueue()
    if #toastQueue == 0 then
        isDisplaying = false
        return
    end

    isDisplaying = true
    local data = table.remove(toastQueue, 1)
    local f = EnsureToastFrame()

    f.Icon:SetTexture(data.icon or "Interface\\Icons\\Ability_Hunter_BeastTaming")
    f.Title:SetText(data.title or "Forever Safari")
    f.Title:SetTextColor(data.titleColor and data.titleColor.r or 1, data.titleColor and data.titleColor.g or 0.82, data.titleColor and data.titleColor.b or 0)
    f.Sub:SetText(data.sub or "")
    f:SetBackdropBorderColor(data.borderColor and data.borderColor.r or 1, data.borderColor and data.borderColor.g or 0.82, data.borderColor and data.borderColor.b or 0, 0.9)

    f:SetAlpha(0)
    f:Show()

    -- Fade In
    local fadeInElapsed = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        fadeInElapsed = fadeInElapsed + elapsed
        if fadeInElapsed <= 0.25 then
            self:SetAlpha(fadeInElapsed / 0.25)
        else
            self:SetAlpha(1)
            self:SetScript("OnUpdate", nil)
        end
    end)

    -- Timer for display duration
    C_Timer.After(3.2, function()
        -- Fade Out
        local fadeOutElapsed = 0
        f:SetScript("OnUpdate", function(self, elapsed)
            fadeOutElapsed = fadeOutElapsed + elapsed
            if fadeOutElapsed <= 0.3 then
                self:SetAlpha(1 - (fadeOutElapsed / 0.3))
            else
                self:SetAlpha(0)
                self:Hide()
                self:SetScript("OnUpdate", nil)
                ProcessQueue()
            end
        end)
    end)
end

function Toast:Enqueue(toastData)
    table.insert(toastQueue, toastData)
    if not isDisplaying then
        ProcessQueue()
    end
end

function Toast:ShowReward(title, sub)
    Toast:Enqueue({
        title = title,
        sub = sub,
        icon = "Interface\\Icons\\INV_Misc_Coin_02",
        titleColor = { r = 1.0, g = 0.85, b = 0.0 },
        borderColor = { r = 1.0, g = 0.85, b = 0.0 },
    })
end

function Toast:ShowCapture(mob)
    local cType = mob and (mob.creatureType or mob.family or mob.element or "Beast") or "Beast"
    local typeInfo = C.CREATURE_TYPES[cType] or C.CREATURE_TYPES["Beast"] or {}
    local mRank = mob and (mob.attunementRank or 1) or 1
    local mRoman = (C.ATTUNEMENT_RANKS[mRank] and C.ATTUNEMENT_RANKS[mRank].roman) or "I"
    local mName = mob and (mob.customNickname or mob.nickname or mob.name or "Companion") or "Companion"

    Toast:Enqueue({
        title = "Creature Captured!",
        sub = string.format("%s (Rank %s %s)", mName, mRoman, cType),
        icon = typeInfo.icon or "Interface\\Icons\\Ability_Hunter_BeastTaming",
        titleColor = { r = 1.0, g = 0.82, b = 0.0 },
        borderColor = { r = 1.0, g = 0.82, b = 0.0 },
    })
end

function Toast:ShowAlert(title, sub)
    Toast:Enqueue({
        title = title,
        sub = sub,
        icon = "Interface\\Icons\\Ability_Hunter_BeastTaming",
        titleColor = { r = 1.0, g = 0.4, b = 0.4 },
        borderColor = { r = 0.8, g = 0.2, b = 0.2 },
    })
end

-------------------------------------------------------------------------------
-- ⏱️ Live Suspension Countdown Toast (World Combat Ambush & Safety Window)
-------------------------------------------------------------------------------
local suspensionFrame = nil
local suspensionTicker = nil

local function EnsureSuspensionFrame()
    if suspensionFrame then return suspensionFrame end

    suspensionFrame = CreateFrame("Frame", "ForeverSafariSuspensionToastFrame", UIParent, "BackdropTemplate")
    suspensionFrame:SetSize(340, 74)
    suspensionFrame:SetPoint("TOP", UIParent, "TOP", 0, -80)
    suspensionFrame:SetFrameStrata("HIGH")
    suspensionFrame:SetClampedToScreen(true)

    suspensionFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    suspensionFrame:SetBackdropColor(0.06, 0.08, 0.12, 0.95)
    suspensionFrame:SetBackdropBorderColor(1.0, 0.75, 0.0, 0.95)

    -- Icon
    local icon = suspensionFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("LEFT", suspensionFrame, "LEFT", 12, 4)
    icon:SetTexture("Interface\\Icons\\Spell_Nature_TimeStop")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    suspensionFrame.Icon = icon

    -- Title
    local title = suspensionFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    title:SetPoint("TOPRIGHT", suspensionFrame, "TOPRIGHT", -10, -2)
    title:SetJustifyH("LEFT")
    suspensionFrame.Title = title

    -- Subtitle
    local sub = suspensionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    sub:SetPoint("TOPRIGHT", suspensionFrame, "TOPRIGHT", -10, -2)
    sub:SetJustifyH("LEFT")
    suspensionFrame.Sub = sub

    -- Progress Bar
    local bar = CreateFrame("StatusBar", nil, suspensionFrame)
    bar:SetSize(256, 6)
    bar:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1.0, 0.75, 0.0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    barBg:SetVertexColor(0.15, 0.15, 0.15, 0.8)

    suspensionFrame.Bar = bar

    suspensionFrame:Hide()
    return suspensionFrame
end

function Toast:ShowSuspensionCountdown(titleText, subTemplate, duration, onExpire)
    duration = duration or 120.0
    local remaining = duration
    local maxDuration = duration

    local f = EnsureSuspensionFrame()

    if suspensionTicker and suspensionTicker.Cancel then
        suspensionTicker:Cancel()
        suspensionTicker = nil
    end

    f.Title:SetText(titleText or "|cffffaa00[Battle Suspended]|r")
    f.Title:SetTextColor(1.0, 0.82, 0.0)
    f:SetBackdropBorderColor(1.0, 0.75, 0.0, 0.95)
    f.Icon:SetTexture("Interface\\Icons\\Spell_Nature_TimeStop")

    local function updateDisplay()
        local formatted = string.format(subTemplate or "Combat engaged • Safe resume in |cffffffff%ds|r (Max %ds)", math.ceil(remaining), math.floor(maxDuration))
        f.Sub:SetText(formatted)

        local pct = math.max(0, math.min(1, remaining / maxDuration))
        f.Bar:SetValue(pct)

        -- Color lerp: Amber -> Red as time falls below 30s
        if remaining <= 30 then
            f.Bar:SetStatusBarColor(1.0, 0.2, 0.2)
            f:SetBackdropBorderColor(1.0, 0.25, 0.25, 0.95)
        else
            f.Bar:SetStatusBarColor(1.0, 0.75, 0.0)
            f:SetBackdropBorderColor(1.0, 0.75, 0.0, 0.95)
        end
    end

    updateDisplay()
    f:SetAlpha(1)
    f:Show()

    suspensionTicker = C_Timer.NewTicker(1.0, function()
        remaining = remaining - 1.0
        if remaining <= 0 then
            if suspensionTicker and suspensionTicker.Cancel then
                suspensionTicker:Cancel()
                suspensionTicker = nil
            end
            f.Sub:SetText("|cffff4444Pause safety timeout expired!|r")
            f.Bar:SetValue(0)
            C_Timer.After(1.2, function()
                f:Hide()
            end)
            if onExpire then
                onExpire()
            end
        else
            updateDisplay()
        end
    end)
end

function Toast:HideSuspensionCountdown(resumeTitle, resumeSub)
    if suspensionTicker and suspensionTicker.Cancel then
        suspensionTicker:Cancel()
        suspensionTicker = nil
    end

    if not suspensionFrame or not suspensionFrame:IsShown() then return end

    if resumeTitle then
        suspensionFrame.Title:SetText(resumeTitle)
        suspensionFrame.Title:SetTextColor(0.0, 1.0, 0.5)
        suspensionFrame:SetBackdropBorderColor(0.0, 0.9, 0.4, 0.95)
        suspensionFrame.Icon:SetTexture("Interface\\Icons\\Spell_Holy_BlessingOfProtection")
        if resumeSub then
            suspensionFrame.Sub:SetText(resumeSub)
        end
        suspensionFrame.Bar:SetValue(1)
        suspensionFrame.Bar:SetStatusBarColor(0.0, 1.0, 0.5)

        C_Timer.After(1.6, function()
            if suspensionFrame and suspensionFrame:IsShown() then
                local fadeElapsed = 0
                suspensionFrame:SetScript("OnUpdate", function(self, elapsed)
                    fadeElapsed = fadeElapsed + elapsed
                    if fadeElapsed <= 0.3 then
                        self:SetAlpha(1 - (fadeElapsed / 0.3))
                    else
                        self:SetAlpha(0)
                        self:Hide()
                        self:SetScript("OnUpdate", nil)
                    end
                end)
            end
        end)
    else
        suspensionFrame:Hide()
    end
end

