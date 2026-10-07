--[[
    Forever Safari: Toast Notification System
    Renders elegant animated pop-ups for captures, quest token rewards, and level-ups.
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
    local mLevel = mob and (mob.level or mob.attunementRank or 1) or 1
    local mName = mob and (mob.customNickname or mob.nickname or mob.name or "Companion") or "Companion"

    Toast:Enqueue({
        title = "Creature Captured!",
        sub = string.format("%s (Level %d %s)", mName, mLevel, cType),
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
