--[[
    Forever Safari: UI Theme & Helper Toolkit
    Provides consistent styling, backdrops, buttons, fonts, and textures across all ForeverSafari interfaces.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Theme = ns.Theme or {}

local Theme = ns.Theme

-- Color Palette
Theme.Colors = {
    Primary = { r = 1.0, g = 0.82, b = 0.0, hex = "ffd100" },       -- Safari Gold
    Secondary = { r = 0.0, g = 1.0, b = 0.6, hex = "00ff99" },     -- Emerald Accent
    Background = { r = 0.07, g = 0.09, b = 0.13, a = 0.94 },        -- Dark Slate Glass
    CardBg = { r = 0.12, g = 0.15, b = 0.20, a = 0.85 },            -- Card Slate
    Border = { r = 0.25, g = 0.35, b = 0.45, a = 0.8 },             -- Subtle Slate Blue Border
    BorderAccent = { r = 1.0, g = 0.82, b = 0.0, a = 0.9 },          -- Glowing Gold Accent
    TextHighlight = { r = 1.0, g = 1.0, b = 1.0, hex = "ffffff" },
    TextMuted = { r = 0.7, g = 0.75, b = 0.8, hex = "b3bfcc" },
    HealthBar = { r = 0.18, g = 0.80, b = 0.44 },
    EnergyBar = { r = 0.20, g = 0.60, b = 1.0 },
    XPBar = { r = 0.60, g = 0.30, b = 0.90 },
}

-- Create standard backdrop
function Theme:ApplyFrameBackdrop(frame, hasGlow)
    if not frame.SetBackdrop then
        if BackdropTemplateMixin then
            Mixin(frame, BackdropTemplateMixin)
        end
    end

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            tileSize = 16,
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        frame:SetBackdropColor(Theme.Colors.Background.r, Theme.Colors.Background.g, Theme.Colors.Background.b, Theme.Colors.Background.a)
        if hasGlow then
            frame:SetBackdropBorderColor(Theme.Colors.BorderAccent.r, Theme.Colors.BorderAccent.g, Theme.Colors.BorderAccent.b, 0.9)
        else
            frame:SetBackdropBorderColor(Theme.Colors.Border.r, Theme.Colors.Border.g, Theme.Colors.Border.b, 0.8)
        end
    end
end

-- Aliases for window backdrops
Theme.ApplyWindowBackdrop = Theme.ApplyFrameBackdrop

-- Apply header subpanel backdrop
function Theme:ApplyHeaderBackdrop(frame)
    if not frame then return end
    if not frame.SetBackdrop then
        if BackdropTemplateMixin then
            Mixin(frame, BackdropTemplateMixin)
        end
    end

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            tileSize = 16,
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        frame:SetBackdropColor(0.05, 0.07, 0.10, 0.95)
        frame:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
    end
end

-- Apply card backdrop to an existing frame
function Theme:ApplyCardBackdrop(frame, hasGlow)
    if not frame then return end
    if not frame.SetBackdrop then
        if BackdropTemplateMixin then
            Mixin(frame, BackdropTemplateMixin)
        end
    end

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            tileSize = 16,
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        frame:SetBackdropColor(Theme.Colors.CardBg.r, Theme.Colors.CardBg.g, Theme.Colors.CardBg.b, Theme.Colors.CardBg.a)
        if hasGlow then
            frame:SetBackdropBorderColor(Theme.Colors.BorderAccent.r, Theme.Colors.BorderAccent.g, Theme.Colors.BorderAccent.b, 0.9)
        else
            frame:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
        end
    end
end

-- Create a card/subpanel container
function Theme:CreateCard(parent, width, height)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width or 100, height or 100)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    card:SetBackdropColor(Theme.Colors.CardBg.r, Theme.Colors.CardBg.g, Theme.Colors.CardBg.b, Theme.Colors.CardBg.a)
    card:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
    return card
end

-- Create styled modern button
function Theme:CreateButton(parent, text, width, height, isAccent)
    -- Robust parameter detection for (parent, width, height, text) vs (parent, text, width, height)
    if type(text) == "number" and (type(height) == "string" or type(isAccent) == "string") then
        local actualText = type(height) == "string" and height or isAccent
        local actualWidth = text
        local actualHeight = type(width) == "number" and width or 28
        local actualAccent = (type(height) == "boolean" and height) or (type(isAccent) == "boolean" and isAccent)
        text = actualText
        width = actualWidth
        height = actualHeight
        isAccent = actualAccent
    end

    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(type(width) == "number" and width or 120, type(height) == "number" and height or 28)
    btn:SetText(tostring(text or "Button"))

    -- Custom Styling
    local font = btn:GetFontString()
    if font then
        font:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        if isAccent then
            font:SetTextColor(1, 1, 1)
        else
            font:SetTextColor(0.9, 0.9, 0.9)
        end
    end

    return btn
end

-- Create Close Button
function Theme:CreateCloseButton(parent)
    local btn = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)
    btn:SetScript("OnClick", function()
        parent:Hide()
        PlaySound(840) -- SOUNDKIT.IG_MAINMENU_CLOSE
    end)
    return btn
end

-- Create Header with Title & Token display
function Theme:CreateHeader(parent, titleText, iconTexture)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(40)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -8)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -35, -8)

    -- Icon
    if iconTexture then
        local icon = header:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", header, "LEFT", 0, 0)
        icon:SetTexture(iconTexture)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        header.Icon = icon
    end

    -- Title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    if iconTexture then
        title:SetPoint("LEFT", header.Icon, "RIGHT", 8, 0)
    else
        title:SetPoint("LEFT", header, "LEFT", 0, 0)
    end
    title:SetText(titleText or "Forever Safari")
    title:SetTextColor(1, 0.82, 0)
    header.Title = title

    -- Token Counter Badge on Top Right
    local tokenFrame = CreateFrame("Frame", nil, header)
    tokenFrame:SetSize(130, 24)
    tokenFrame:SetPoint("RIGHT", header, "RIGHT", 0, 0)

    local tokenIcon = tokenFrame:CreateTexture(nil, "ARTWORK")
    tokenIcon:SetSize(18, 18)
    tokenIcon:SetPoint("LEFT", tokenFrame, "LEFT", 0, 0)
    tokenIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")

    local tokenText = tokenFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tokenText:SetPoint("LEFT", tokenIcon, "RIGHT", 5, 0)
    tokenText:SetText("0 Safari Tokens")
    tokenText:SetTextColor(1, 0.85, 0)
    header.TokenText = tokenText

    function header:UpdateTokens()
        local tokens = ForeverSafari.Database:GetTokens()
        header.TokenText:SetText(string.format("|cffffd100%d|r Safari Tokens", tokens))
    end

    header:UpdateTokens()
    return header
end
