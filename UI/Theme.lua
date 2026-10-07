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

-- =========================================================================
-- 📖 HOVER TOOLTIP: PET ABILITIES & MOVES
-- =========================================================================
function Theme:ShowAbilityTooltip(owner, moveKeyOrData, anchor, moveState, defenderMob)
    if not owner or not moveKeyOrData then return end
    local C = ns.Constants
    local BE = ns.BattleEngine
    local MoveDB = ns.MoveDB or (ForeverSafari and ForeverSafari.MoveDB)

    local move = nil
    if type(moveKeyOrData) == "table" then
        move = moveKeyOrData
    else
        local kNum = tonumber(moveKeyOrData)
        if MoveDB and kNum and MoveDB[kNum] then
            move = MoveDB[kNum]
        elseif MoveDB and MoveDB[moveKeyOrData] then
            move = MoveDB[moveKeyOrData]
        elseif BE and BE.GetMoveData then
            move = BE:GetMoveData(moveKeyOrData)
        elseif C and C.ABILITIES and C.ABILITIES[moveKeyOrData] then
            move = C.ABILITIES[moveKeyOrData]
        end
    end
    if not move then return end

    GameTooltip:SetOwner(owner, anchor or "ANCHOR_TOP")
    
    -- Ability Name
    GameTooltip:AddLine(move.name or "Ability", 1.0, 1.0, 1.0)

    -- Type & Category
    local mType = move.type or move.element or "Beast"
    local typeInfo = (C and C.CREATURE_TYPES and C.CREATURE_TYPES[mType]) or { color = "ffd100" }
    local typeColor = typeInfo.color or "ffd100"
    local category = move.category or ((move.power and move.power > 0) and "Physical" or "Status")
    local catColor = (category == "Physical") and "|cffff8844Physical|r" or ((category == "Special") and "|cff33ccffSpecial|r" or "|cffaaaaaaStatus|r")

    local headerLine = string.format("Type: |cff%s%s|r  •  %s", typeColor, mType, catColor)
    if move.priority and move.priority > 0 then
        headerLine = headerLine .. string.format("  •  |cffffcc00[Priority +%d]|r", move.priority)
    end
    GameTooltip:AddLine(headerLine, 0.9, 0.9, 0.9)

    -- Combat Attributes (Power, Accuracy, PP/Uses, Cooldown)
    GameTooltip:AddLine(" ")
    local powerStr = (move.power and move.power > 0) and tostring(move.power) or "--"
    local accStr = (move.accuracy and move.accuracy > 0) and string.format("%d%%", move.accuracy) or "--"
    
    local maxUses = (moveState and moveState.maxUses) or move.maxUses or move.pp or 10
    local usesLeft = (moveState and moveState.usesLeft) or maxUses
    local ppStr = (moveState and string.format("%d / %d", usesLeft, maxUses)) or string.format("%d uses", maxUses)
    
    local cdStr = "Ready (0 CD)"
    if moveState and moveState.currentCD and moveState.currentCD > 0 then
        cdStr = string.format("|cffff4444%d Turn%s CD|r", moveState.currentCD, moveState.currentCD > 1 and "s" or "")
    elseif move.cooldown and move.cooldown > 0 then
        cdStr = string.format("%d Turn%s CD", move.cooldown, move.cooldown > 1 and "s" or "")
    end

    GameTooltip:AddDoubleLine(string.format("Power: |cffffffff%s|r", powerStr), string.format("Accuracy: |cffffffff%s|r", accStr), 1, 0.82, 0, 1, 0.82, 0)
    GameTooltip:AddDoubleLine(string.format("Battle Uses: |cffffffff%s|r", ppStr), string.format("Cooldown: |cffffffff%s|r", cdStr), 1, 0.82, 0, 1, 0.82, 0)

    -- Live Type Advantage vs active opponent if in combat
    if defenderMob and defenderMob.creatureType and C and C.TYPE_ADVANTAGES and C.TYPE_ADVANTAGES[mType] then
        local mult = C.TYPE_ADVANTAGES[mType][defenderMob.creatureType]
        if mult and mult >= 1.5 then
            GameTooltip:AddLine(string.format("vs %s: |cff00ff00Super Effective! (150%% Damage)|r", defenderMob.name or "Foe"), 0.8, 1, 0.8)
        elseif mult and mult <= 0.70 then
            GameTooltip:AddLine(string.format("vs %s: |cffff8800Resisted (67%% Damage)|r", defenderMob.name or "Foe"), 1, 0.7, 0.5)
        end
    end

    -- Description & Tactical Effect Callouts
    local desc = move.desc or move.description or "A tactical companion ability."
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(desc, 1, 1, 1, true)

    if move.heal then
        GameTooltip:AddLine(string.format("• Restores |cff00ff00%.0f%%|r Max HP immediately", move.heal * 100), 0, 1, 0.6)
    end
    if move.hot then
        GameTooltip:AddLine(string.format("• Restores |cff00ff00%.0f%%|r Max HP per turn for %d turns", (move.hot.healPercent or 0.15) * 100, move.hot.duration or 3), 0, 1, 0.6)
    end
    if move.buff then
        local dir = move.buff.multiplier > 1 and "Increases" or "Decreases"
        local pct = math.abs(move.buff.multiplier - 1) * 100
        GameTooltip:AddLine(string.format("• %s target's |cffffcc00%s|r by |cffffffff%.0f%%|r for %d turns", dir, string.upper(move.buff.stat or "ATK"), pct, move.buff.duration or 3), 0.8, 0.9, 1)
    end
    if move.flinchChance then
        GameTooltip:AddLine(string.format("• |cffffd100%d%% chance|r to cause opponent to flinch", move.flinchChance), 1, 0.82, 0)
    end
    if move.sleepChance then
        GameTooltip:AddLine(string.format("• |cff9966cc%d%% chance|r to put target to sleep for 2 rounds", move.sleepChance), 0.7, 0.5, 1)
    end

    GameTooltip:Show()
end

function Theme:HideAbilityTooltip()
    GameTooltip:Hide()
end
