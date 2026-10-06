--[[
    Forever Safari: Nesingwary Safari Supplies Shop
    Custom merchant interface restricted exclusively to Innkeepers and Stable Masters
    via authentic gossip interactions, allowing players to spend Safari Tokens on nets and consumables.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.ShopFrame = ns.ShopFrame or {}

local Shop = ns.ShopFrame
local C = ns.Constants
local DB = ns.Database
local Theme = ns.Theme

local frame = nil
local itemListFrames = {}
local gossipBtn = nil
Shop.isAtVendor = false
Shop.vendorType = nil

local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then
        return true
    end
    return false
end

function Shop:Initialize()
    if frame then return end

    frame = CreateFrame("Frame", "ForeverSafariShopFrame", UIParent, "BackdropTemplate")
    frame:SetSize(480, 540)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")

    Theme:ApplyFrameBackdrop(frame, true)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    Theme:CreateCloseButton(frame)
    frame.Header = Theme:CreateHeader(frame, "Nesingwary Safari Supplies", "Interface\\Icons\\Ability_Hunter_BeastTaming")

    -- Vendor Status Badge
    local vendorStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    vendorStatus:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -14)
    vendorStatus:SetJustifyH("RIGHT")
    frame.VendorStatus = vendorStatus

    -- Category Subheader / Banner
    local bannerFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bannerFrame:SetSize(456, 32)
    bannerFrame:SetPoint("TOPLEFT", 12, -42)
    bannerFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
    })
    bannerFrame:SetBackdropColor(0.08, 0.10, 0.14, 0.9)
    bannerFrame:SetBackdropBorderColor(0.3, 0.4, 0.5, 0.6)
    frame.BannerFrame = bannerFrame

    local bannerText = bannerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bannerText:SetPoint("LEFT", 8, 0)
    bannerText:SetPoint("RIGHT", -8, 0)
    bannerText:SetJustifyH("LEFT")
    frame.BannerText = bannerText

    -- Scroll Area Container
    local scrollFrame = CreateFrame("ScrollFrame", "ForeverSafariShopScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 16)

    local content = CreateFrame("Frame", "ForeverSafariShopContentFrame", scrollFrame)
    content:SetSize(420, 600)
    scrollFrame:SetScrollChild(content)
    frame.Content = content

    -- Build Shop Rows
    Shop:BuildShopItems()

    -- Register Gossip Events for Innkeeper & Stable Master Detection
    Shop:RegisterGossipEvents()

    frame:Hide()
end

-- =========================================================================
-- 🏨 VENDOR DETECTION & GOSSIP MENU INTEGRATION
-- =========================================================================
function Shop:IsAtAuthorizedVendor()
    local unit = UnitExists("npc") and "npc" or (UnitExists("target") and "target" or nil)
    
    if unit then
        -- 1. Scan Unit Tooltip for Innkeeper / Stable Master titles
        local tooltip = ForeverSafariTooltipScan or CreateFrame("GameTooltip", "ForeverSafariTooltipScan", nil, "GameTooltipTemplate")
        tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
        tooltip:ClearLines()
        tooltip:SetUnit(unit)
        for i = 1, tooltip:NumLines() do
            local line = _G["ForeverSafariTooltipScanTextLeft" .. i]
            if line then
                local text = line:GetText()
                if text and not isSecret(text) then
                    local lower = string.lower(text)
                    if string.find(lower, "stable master") or string.find(lower, "stablemaster") or string.find(lower, "stable") then
                        return true, "Stable Master"
                    elseif string.find(lower, "innkeeper") or string.find(lower, "taverner") or string.find(lower, "barkeeper") or string.find(lower, "inn") then
                        return true, "Innkeeper"
                    end
                end
            end
        end

        -- 2. Check Unit Name
        local unitName = UnitName(unit)
        if unitName and not isSecret(unitName) then
            local lower = string.lower(unitName)
            if string.find(lower, "stable master") or string.find(lower, "stablemaster") then
                return true, "Stable Master"
            elseif string.find(lower, "innkeeper") then
                return true, "Innkeeper"
            end
        end
    end

    -- 3. Check Gossip Options
    if C_GossipInfo and C_GossipInfo.GetOptions then
        local options = C_GossipInfo.GetOptions()
        if options then
            for _, opt in ipairs(options) do
                local name = opt.name or opt.title or ""
                local lower = string.lower(name)
                if string.find(lower, "stable") or string.find(lower, "pet") then
                    return true, "Stable Master"
                elseif string.find(lower, "inn") or string.find(lower, "home") or string.find(lower, "bind") or string.find(lower, "hearthstone") then
                    return true, "Innkeeper"
                end
            end
        end
    end

    -- 4. Check Gossip Text
    local gText = (C_GossipInfo and C_GossipInfo.GetText and C_GossipInfo.GetText()) or (GetGossipText and GetGossipText()) or ""
    if gText and not isSecret(gText) and gText ~= "" then
        local lower = string.lower(gText)
        if string.find(lower, "stable") or string.find(lower, "beast") then
            return true, "Stable Master"
        elseif string.find(lower, "inn") or string.find(lower, "hearthstone") or string.find(lower, "home") or string.find(lower, "bed") or string.find(lower, "rest") then
            return true, "Innkeeper"
        end
    end

    return false, nil
end

function Shop:RegisterGossipEvents()
    local eventFrame = CreateFrame("Frame", "ForeverSafariShopGossipEvents")
    eventFrame:RegisterEvent("GOSSIP_SHOW")
    eventFrame:RegisterEvent("GOSSIP_CLOSED")

    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "GOSSIP_SHOW" then
            Shop:OnGossipShow()
        elseif event == "GOSSIP_CLOSED" then
            Shop:OnGossipClosed()
        end
    end)
end

function Shop:OnGossipShow()
    local isAuthorized, vType = Shop:IsAtAuthorizedVendor()
    if isAuthorized then
        Shop.isAtVendor = true
        Shop.vendorType = vType or "Innkeeper"

        -- Create or Attach Gossip Menu Button to GossipFrame
        if GossipFrame then
            if not gossipBtn then
                gossipBtn = CreateFrame("Button", "ForeverSafariGossipButton", GossipFrame, "BackdropTemplate")
                gossipBtn:SetSize(280, 32)
                gossipBtn:SetPoint("BOTTOM", GossipFrame, "BOTTOM", 0, 24)
                gossipBtn:SetFrameLevel(GossipFrame:GetFrameLevel() + 10)

                gossipBtn:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 12,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 }
                })
                gossipBtn:SetBackdropColor(0.12, 0.08, 0.04, 0.95)
                gossipBtn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)

                local icon = gossipBtn:CreateTexture(nil, "ARTWORK")
                icon:SetSize(20, 20)
                icon:SetPoint("LEFT", 6, 0)
                icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                gossipBtn.Icon = icon

                local label = gossipBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
                label:SetPoint("RIGHT", -6, 0)
                label:SetJustifyH("LEFT")
                label:SetText("|cffffd100[ 🐾 Browse Safari Supplies ]|r")
                gossipBtn.Label = label

                gossipBtn:SetScript("OnClick", function()
                    Shop:ShowShop(true)
                end)

                gossipBtn:SetScript("OnEnter", function(self)
                    self:SetBackdropBorderColor(0.0, 1.0, 0.6, 1.0)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:AddLine("Nesingwary Safari Supplies", 1, 0.82, 0)
                    GameTooltip:AddLine("Authorized merchant exchange. Spend Safari Tokens on nets, feasts, and treats.", 1, 1, 1, true)
                    GameTooltip:Show()
                end)

                gossipBtn:SetScript("OnLeave", function(self)
                    self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                    GameTooltip:Hide()
                end)
            end

            gossipBtn:Show()
        end
    else
        Shop.isAtVendor = false
        Shop.vendorType = nil
        if gossipBtn then gossipBtn:Hide() end
    end
end

function Shop:OnGossipClosed()
    Shop.isAtVendor = false
    Shop.vendorType = nil
    if gossipBtn then gossipBtn:Hide() end
    if frame and frame:IsShown() then
        Shop:UpdateUI()
    end
end

-- =========================================================================
-- 🛒 SHOP ITEMS & CATALOGUE
-- =========================================================================
function Shop:BuildShopItems()
    local content = frame.Content
    local yOffset = 0

    -- Section 1: Safari Nets Header
    local cageSection = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    cageSection:SetPoint("TOPLEFT", 6, yOffset)
    cageSection:SetText("|cffffd100Safari Nets|r")
    yOffset = yOffset - 26

    local cageKeys = { "copper_cage", "iron_cage", "mithril_cage", "arcanite_capsule" }
    for _, id in ipairs(cageKeys) do
        local itemData = C.CAGES[id]
        local row = Shop:CreateShopItemRow(content, itemData, id, yOffset)
        table.insert(itemListFrames, row)
        yOffset = yOffset - 66
    end

    yOffset = yOffset - 10

    -- Section 2: Consumables & Supplies
    local supplySection = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    supplySection:SetPoint("TOPLEFT", 6, yOffset)
    supplySection:SetText("|cffffd100Consumables & Training Supplies|r")
    yOffset = yOffset - 26

    local supplyKeys = { "az_treat", "az_feast", "healing_salve", "revival_crystal" }
    for _, id in ipairs(supplyKeys) do
        local itemData = C.SHOP_ITEMS[id]
        if itemData then
            local row = Shop:CreateShopItemRow(content, itemData, id, yOffset)
            table.insert(itemListFrames, row)
            yOffset = yOffset - 66
        end
    end

    content:SetHeight(math.abs(yOffset) + 20)
end

function Shop:CreateShopItemRow(parent, data, id, yOffset)
    if not data then return nil end
    local card = Theme:CreateCard(parent, 416, 60)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset)
    card.itemId = id

    -- Icon
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("LEFT", card, "LEFT", 10, 0)
    icon:SetTexture(data.icon or "Interface\\Icons\\Ability_Hunter_BeastTaming")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.Icon = icon

    -- Title & Multiplier / Effect
    local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    nameText:SetText(string.format("|cff%s%s|r", data.color or "ffffff", data.name))
    card.NameText = nameText

    -- Description
    local descText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -3)
    descText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -150, -3)
    descText:SetJustifyH("LEFT")
    descText:SetText(data.description)
    descText:SetTextColor(0.7, 0.7, 0.7)
    card.DescText = descText

    -- Owned count badge
    local ownedText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ownedText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)
    card.OwnedText = ownedText

    -- Price Tag
    local priceText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    priceText:SetPoint("RIGHT", card, "RIGHT", -110, 0)
    priceText:SetText(string.format("|cffffd100%d|r Tokens", data.price))
    card.PriceText = priceText

    -- Buy Button
    local buyBtn = Theme:CreateButton(card, "Buy x1", 95, 26, true)
    buyBtn:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    buyBtn:SetScript("OnClick", function()
        Shop:BuyItem(id, 1, data.price, data.name)
    end)
    card.BuyBtn = buyBtn

    return card
end

function Shop:BuyItem(itemId, count, unitPrice, itemName)
    -- Enforce Vendor Presence
    local isAuthorized, vType = Shop:IsAtAuthorizedVendor()
    if not isAuthorized and not Shop.isAtVendor then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Purchases restricted! You must speak with an Innkeeper or Stable Master to purchase Safari Supplies.|r")
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Vendor Required", "Speak with an Innkeeper or Stable Master to buy supplies!")
        end
        PlaySound(847)
        return
    end

    local totalCost = unitPrice * count
    if DB:GetTokens() < totalCost then
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Insufficient Tokens", "Complete more field dispatches to earn Safari Tokens!")
        end
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444You do not have enough Safari Tokens! Complete quests or dispatches to earn more.|r")
        PlaySound(847)
        return
    end

    if DB:SpendTokens(totalCost) then
        DB:AddItem(itemId, count)
        PlaySound(856) -- SOUNDKIT.MONEY_FRAME_OPEN
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%sPurchased |cff00ff00%dx %s|r from %s for |cffffd100%d Safari Tokens|r!",
            C.PREFIX, count, itemName, (Shop.vendorType or "Vendor"), totalCost))
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowReward(string.format("Purchased %s!", itemName), string.format("Spent %d Safari Tokens", totalCost))
        end
        Shop:UpdateUI()
    end
end

function Shop:UpdateUI()
    if not frame or not frame:IsShown() then return end
    if frame.Header then
        frame.Header:UpdateTokens()
    end

    local isAuthorized, vType = Shop:IsAtAuthorizedVendor()
    local atVendor = isAuthorized or Shop.isAtVendor
    local activeVendorName = vType or Shop.vendorType or "Vendor"

    if atVendor then
        frame.VendorStatus:SetText(string.format("|cff00ff00[ Authorized Merchant: %s ]|r", activeVendorName))
        frame.BannerFrame:SetBackdropBorderColor(0.0, 0.9, 0.4, 0.8)
        frame.BannerText:SetText(string.format("|cff00ff00🐾 You are browsing with %s. Purchases are active!|r", activeVendorName))
    else
        frame.VendorStatus:SetText("|cffff4444[ Catalogue Mode ]|r")
        frame.BannerFrame:SetBackdropBorderColor(1.0, 0.6, 0.0, 0.8)
        frame.BannerText:SetText("|cffffcc00🐾 Catalogue Mode: Visit any Innkeeper or Stable Master to purchase supplies.|r")
    end

    for _, card in ipairs(itemListFrames) do
        local id = card.itemId
        local itemData = C.CAGES[id] or C.SHOP_ITEMS[id]
        if itemData then
            local count = DB:GetItemCount(id)
            card.OwnedText:SetText(string.format("Owned: |cff00ff99%d|r", count))

            if not atVendor then
                card.BuyBtn:Disable()
                card.BuyBtn:SetText("🔒 Visit Vendor")
            elseif DB:GetTokens() >= itemData.price then
                card.BuyBtn:Enable()
                card.BuyBtn:SetText(string.format("Buy x1"))
            else
                card.BuyBtn:Disable()
                card.BuyBtn:SetText(string.format("Buy x1"))
            end
        end
    end
end

function Shop:ShowShop(fromVendor)
    if not frame then Shop:Initialize() end
    if fromVendor then
        Shop.isAtVendor = true
    else
        local isAuth, vType = Shop:IsAtAuthorizedVendor()
        Shop.isAtVendor = isAuth
        Shop.vendorType = vType
    end
    frame:Show()
    Shop:UpdateUI()
    PlaySound(844) -- SOUNDKIT.IG_SPELLBOOK_OPEN
end

function Shop:Toggle()
    if not frame then Shop:Initialize() end
    if frame:IsShown() then
        frame:Hide()
    else
        Shop:ShowShop(false)
    end
end

function Shop:IsShown()
    return frame and frame:IsShown()
end
