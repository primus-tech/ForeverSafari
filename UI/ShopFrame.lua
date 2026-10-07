--[[
    Forever Safari: Nesingwary Safari Merchant System
    STRICTLY RESTRICTED: Shop access is ONLY granted via clicking the gossip interaction
    at Pet Trainers (for Safari Nets & Gear) and Innkeepers (for Safari Treats & Food Provisions).
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
local currentCategory = "gear"

Shop.isAtVendor = false
Shop.vendorType = nil

local CATEGORIES = {
    { id = "gear", name = "Capture Gear", icon = "Interface\\Icons\\INV_Misc_Net_01", desc = "Field research snares, nets, traps, and cages for in-battle capture." },
    { id = "crates", name = "Transport Crates", icon = "Interface\\Icons\\INV_Box_PetCarrier_01", desc = "Expedition crates to auto-board excess captured companions." },
    { id = "food", name = "Treats & Diets", icon = "Interface\\Icons\\INV_Misc_Food_14", desc = "Safari treats and species-specific dietary meals (+25 Attunement)." },
    { id = "medical", name = "Medicine & Aid", icon = "Interface\\Icons\\INV_Potion_54", desc = "Emergency field remedies to restore health and revive fallen companions." },
}

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
    frame:SetSize(490, 560)
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
    frame.Header = Theme:CreateHeader(frame, "Nesingwary Safari Outfitter", "Interface\\Icons\\Ability_Hunter_BeastTaming")

    -- Vendor Status Badge
    local vendorStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    vendorStatus:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -14)
    vendorStatus:SetJustifyH("RIGHT")
    frame.VendorStatus = vendorStatus

    -- Category Tabs
    frame.Tabs = {}
    local tabWidth = 110
    local tabHeight = 24
    local startX = 14
    for idx, cat in ipairs(CATEGORIES) do
        local tab = CreateFrame("Button", "ForeverSafariShopTab" .. idx, frame, "BackdropTemplate")
        tab:SetSize(tabWidth, tabHeight)
        tab:SetPoint("TOPLEFT", frame, "TOPLEFT", startX + ((idx - 1) * (tabWidth + 6)), -42)
        Theme:ApplyCardBackdrop(tab)
        tab.catId = cat.id

        local tText = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tText:SetPoint("CENTER", 0, 0)
        tText:SetText(cat.name)
        tab.Text = tText

        tab:SetScript("OnClick", function()
            currentCategory = cat.id
            PlaySound(844)
            Shop:UpdateTabs()
            Shop:BuildShopItems()
            Shop:UpdateUI()
        end)

        tab:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(cat.name, 1, 0.82, 0)
            GameTooltip:AddLine(cat.desc, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        tab:SetScript("OnLeave", function() GameTooltip:Hide() end)

        frame.Tabs[cat.id] = tab
    end

    -- Category Subheader / Banner
    local bannerFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bannerFrame:SetSize(462, 24)
    bannerFrame:SetPoint("TOPLEFT", 14, -70)
    bannerFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    bannerFrame:SetBackdropColor(0.06, 0.08, 0.12, 0.9)
    bannerFrame:SetBackdropBorderColor(0.0, 0.9, 0.4, 0.7)
    frame.BannerFrame = bannerFrame

    local bannerText = bannerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bannerText:SetPoint("LEFT", 8, 0)
    bannerText:SetPoint("RIGHT", -8, 0)
    bannerText:SetJustifyH("LEFT")
    frame.BannerText = bannerText

    -- Interactive Rest & Tend Squad Button (Gated Heal & Revive Action)
    local healBtn = CreateFrame("Button", "ForeverSafariShopHealBtn", frame, "BackdropTemplate")
    healBtn:SetSize(462, 30)
    healBtn:SetPoint("TOPLEFT", bannerFrame, "BOTTOMLEFT", 0, -4)
    Theme:ApplyCardBackdrop(healBtn, true)

    local healIcon = healBtn:CreateTexture(nil, "ARTWORK")
    healIcon:SetSize(18, 18)
    healIcon:SetPoint("LEFT", 8, 0)
    healIcon:SetTexture("Interface\\Icons\\Spell_Holy_Renew")
    healIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    healBtn.Icon = healIcon

    local healText = healBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    healText:SetPoint("LEFT", healIcon, "RIGHT", 6, 0)
    healText:SetPoint("RIGHT", -8, 0)
    healText:SetJustifyH("LEFT")
    healBtn.Text = healText

    healBtn:SetScript("OnClick", function(self)
        if DB and DB.HealTeam then
            local team = DB:GetTeam()
            local needsHealing = false
            for _, m in ipairs(team) do
                if m and (not m.currentHP or m.currentHP < (m.maxHP or 10)) then
                    needsHealing = true
                    break
                end
            end
            if needsHealing then
                DB:HealTeam(false)
                Shop:UpdateHealButton()
            else
                DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff00Your active companion squad is already at full health and vigor!|r")
                PlaySound(856)
            end
        end
    end)

    healBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.0, 1.0, 0.6, 1.0)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Tend, Revive & Rest Companion Squad", 1, 0.82, 0)
        GameTooltip:AddLine("Click to have the merchant tend to your battle companions, restoring all active squad members to 100% HP and reviving fainted pets.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    healBtn:SetScript("OnLeave", function(self)
        Shop:UpdateHealButton()
        GameTooltip:Hide()
    end)
    frame.HealButton = healBtn

    -- Scroll Area Container
    local scrollFrame = CreateFrame("ScrollFrame", "ForeverSafariShopScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", healBtn, "BOTTOMLEFT", 0, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 14)

    local content = CreateFrame("Frame", "ForeverSafariShopContentFrame", scrollFrame)
    content:SetSize(434, 400)
    scrollFrame:SetScrollChild(content)
    frame.ScrollFrame = scrollFrame
    frame.Content = content

    -- Register Gossip Events for Pet Trainer & Innkeeper Detection
    Shop:RegisterGossipEvents()

    frame:Hide()
end

function Shop:UpdateTabs()
    if not frame or not frame.Tabs then return end
    for _, cat in ipairs(CATEGORIES) do
        local tab = frame.Tabs[cat.id]
        if tab then
            if cat.id == currentCategory then
                tab:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                tab:SetBackdropColor(0.18, 0.15, 0.08, 0.95)
                tab.Text:SetTextColor(1.0, 0.82, 0.0)
            else
                tab:SetBackdropBorderColor(0.25, 0.35, 0.45, 0.7)
                tab:SetBackdropColor(Theme.Colors.CardBg.r, Theme.Colors.CardBg.g, Theme.Colors.CardBg.b, Theme.Colors.CardBg.a)
                tab.Text:SetTextColor(0.75, 0.80, 0.85)
            end
        end
    end
end

function Shop:UpdateHealButton()
    if not frame or not frame.HealButton then return end
    local team = DB:GetTeam()
    local needsHealing = false
    local woundedCount = 0
    for _, m in ipairs(team) do
        if m and (not m.currentHP or m.currentHP < (m.maxHP or 10)) then
            needsHealing = true
            woundedCount = woundedCount + 1
        end
    end

    local btn = frame.HealButton
    if needsHealing then
        btn:Enable()
        btn:SetBackdropBorderColor(0.0, 1.0, 0.5, 1.0)
        btn:SetBackdropColor(0.06, 0.18, 0.10, 0.95)
        btn.Text:SetText(string.format("|cff00ff00💖 Tend & Revive Squad (%d wounded/fainted) — Click to Heal|r", woundedCount))
    else
        btn:SetBackdropBorderColor(0.3, 0.4, 0.5, 0.6)
        btn:SetBackdropColor(0.08, 0.10, 0.14, 0.8)
        btn.Text:SetText("|cffaaaaaa✔ All Active Companions Fully Restored & In Peak Health|r")
    end
end

-- =========================================================================
-- 🏨 VENDOR DETECTION & GOSSIP MENU INTEGRATION
-- =========================================================================
function Shop:IsAtAuthorizedVendor()
    local unit = UnitExists("npc") and "npc" or (UnitExists("target") and "target" or nil)

    -- Strict title matching: only Pet Trainers and Innkeepers qualify.
    local function classify(text)
        local lower = string.lower(text)
        if string.find(lower, "pet trainer", 1, true) or string.find(lower, "beast trainer", 1, true) or string.find(lower, "pet master", 1, true) then
            return "Pet Trainer"
        elseif string.find(lower, "innkeeper", 1, true) then
            return "Innkeeper"
        end
        return nil
    end

    if unit then
        -- 1. Modern C_TooltipInfo scan (Zero taint in modern protected API)
        if C_TooltipInfo and C_TooltipInfo.GetUnit then
            local ok, info = pcall(C_TooltipInfo.GetUnit, unit)
            if ok and info and info.lines then
                for _, line in ipairs(info.lines) do
                    if line.leftText and not isSecret(line.leftText) then
                        local vType = classify(line.leftText)
                        if vType then return true, vType end
                    end
                end
            end
        end

        -- 2. Check Unit Name
        local unitName = UnitName(unit)
        if unitName and not isSecret(unitName) then
            local vType = classify(unitName)
            if vType then return true, vType end
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
        Shop.vendorType = vType or "Pet Trainer"

        if vType == "Innkeeper" then
            -- Open Safari Kennel Sidecar when interacting with an Innkeeper
            if ForeverSafari.KennelFrame then
                ForeverSafari.KennelFrame:ShowKennel()
            end
            if frame and frame:IsShown() then frame:Hide() end
        else
            -- Open Standalone Safari Supplies Outfitter docked to GossipFrame (Zero Taint)
            if GossipFrame and GossipFrame:IsShown() then
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", GossipFrame, "TOPRIGHT", 10, 0)
            end
            Shop:ShowShop(true)
        end
    else
        Shop.isAtVendor = false
        Shop.vendorType = nil
        if frame and frame:IsShown() then
            frame:Hide()
        end
    end
end

function Shop:OnGossipClosed()
    Shop.isAtVendor = false
    Shop.vendorType = nil
    -- Close shop immediately when leaving vendor
    if frame and frame:IsShown() then
        frame:Hide()
    end
    if ForeverSafari.KennelFrame and ForeverSafari.KennelFrame:IsShown() then
        ForeverSafari.KennelFrame:Hide()
    end
end

-- =========================================================================
-- 🛒 SHOP ITEMS PER TAB
-- =========================================================================
function Shop:BuildShopItems()
    local content = frame.Content
    
    -- Clear previous items
    for _, card in ipairs(itemListFrames) do
        card:Hide()
    end
    wipe(itemListFrames)

    Shop:UpdateTabs()

    local yOffset = -4
    frame.VendorStatus:SetText("|cff00ff00[ Pet Trainer — Outfitter & Supplies ]|r")

    -- Reset Scrollbar to Top
    if frame.ScrollFrame and frame.ScrollFrame.SetVerticalScroll then
        frame.ScrollFrame:SetVerticalScroll(0)
    end

    if currentCategory == "gear" then
        frame.BannerText:SetText("|cff00ff99🕸 Field Capture Gear: Snares, nets, traps, and cages for wild capture.|r")
        local cageKeys = { "copper_cage", "iron_cage", "mithril_cage", "thorium_trap" }
        for _, id in ipairs(cageKeys) do
            local itemData = C.CAGES[id]
            if itemData then
                local row = Shop:CreateShopItemRow(content, itemData, id, yOffset)
                table.insert(itemListFrames, row)
                yOffset = yOffset - 80
            end
        end

    elseif currentCategory == "crates" then
        frame.BannerText:SetText("|cff00ff99📦 Transport Crates: Secure cages used to auto-board excess captures into Kennels.|r")
        local crateKeys = { "crate_copper", "crate_iron", "crate_mithril", "crate_thorium" }
        for _, id in ipairs(crateKeys) do
            local itemData = C.TRANSPORT_CRATES[id] or C.SHOP_ITEMS[id]
            if itemData then
                local row = Shop:CreateShopItemRow(content, itemData, id, yOffset)
                table.insert(itemListFrames, row)
                yOffset = yOffset - 80
            end
        end

    elseif currentCategory == "food" then
        frame.BannerText:SetText("|cff00ff99🥩 Treats & Diets: Nourishing feasts and family diets granting +25 Attunement.|r")
        local treatKeys = { "az_treat", "az_feast" }
        for _, id in ipairs(treatKeys) do
            local itemData = C.SHOP_ITEMS[id]
            if itemData then
                local row = Shop:CreateShopItemRow(content, itemData, id, yOffset)
                table.insert(itemListFrames, row)
                yOffset = yOffset - 80
            end
        end

        local foodKeys = {
            "food_meat", "food_fish", "food_bread", "food_cheese", "food_fruit", "food_fungus",
            "food_parts", "food_bonedust", "food_shards", "food_crystals", "food_runes"
        }
        for _, id in ipairs(foodKeys) do
            local itemData = (ns.ItemDB and ns.ItemDB.DIET_ITEMS and ns.ItemDB.DIET_ITEMS[id]) or (C.SAFARI_ITEMS and C.SAFARI_ITEMS[id])
            if itemData then
                local iconPath = itemData.icon or "INV_Misc_Food_14"
                if not string.find(iconPath, "\\") then
                    iconPath = "Interface\\Icons\\" .. iconPath
                end
                local dataCopy = {
                    name = itemData.name,
                    icon = iconPath,
                    color = itemData.color or "ffffff",
                    description = itemData.desc or "Fresh Safari diet sustenance (+25 Favorite / +15 Accepted Attunement).",
                    price = itemData.tokenCost or 1,
                }
                local row = Shop:CreateShopItemRow(content, dataCopy, id, yOffset)
                table.insert(itemListFrames, row)
                yOffset = yOffset - 80
            end
        end

    elseif currentCategory == "medical" then
        frame.BannerText:SetText("|cff00ff99🧪 Medicine & Aid: Salves and revival crystals for quick recovery in the field.|r")
        local medKeys = { "healing_salve", "revival_crystal" }
        for _, id in ipairs(medKeys) do
            local itemData = C.SHOP_ITEMS[id]
            if itemData then
                local row = Shop:CreateShopItemRow(content, itemData, id, yOffset)
                table.insert(itemListFrames, row)
                yOffset = yOffset - 80
            end
        end
    end

    content:SetHeight(math.abs(yOffset) + 20)
end

-- =========================================================================
-- 🎴 ITEM ROW: Number Owned, Cost, and Buy Button BENEATH the Item
-- =========================================================================
function Shop:CreateShopItemRow(parent, data, id, yOffset)
    if not data then return nil end
    local card = Theme:CreateCard(parent, 430, 74)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, yOffset)
    card.itemId = id
    card.price = data.price or 5

    -- TOP ROW: Icon, Title & Multiplier, Full Description
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
    local tex = data.icon or "Interface\\Icons\\Ability_Hunter_BeastTaming"
    if not string.find(tex, "\\") then
        tex = "Interface\\Icons\\" .. tex
    end
    icon:SetTexture(tex)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Quality Color Tint for Crates
    if data.category == "Logistics" or string.find(id, "crate_") then
        if data.quality == 1 then
            icon:SetVertexColor(0.85, 0.65, 0.45) -- Copper
        elseif data.quality == 2 then
            icon:SetVertexColor(0.60, 0.90, 0.60) -- Iron / Green
        elseif data.quality == 3 then
            icon:SetVertexColor(0.40, 0.70, 1.00) -- Mithril / Blue
        elseif data.quality == 4 then
            icon:SetVertexColor(0.85, 0.45, 1.00) -- Thorium / Purple
        end
    else
        icon:SetVertexColor(1, 1, 1)
    end
    card.Icon = icon

    -- Title
    local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
    nameText:SetText(string.format("|cff%s%s|r", data.color or "ffffff", data.name))
    card.NameText = nameText

    -- Description (full width)
    local descText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    descText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -2)
    descText:SetJustifyH("LEFT")
    descText:SetText(data.description or data.desc or "")
    descText:SetTextColor(0.72, 0.76, 0.82)
    card.DescText = descText

    -- BOTTOM ROW (Beneath the item): Number Owned, Cost, and Buy Button
    -- 1. Number Owned (Left)
    local ownedText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ownedText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 8)
    ownedText:SetText("Owned: |cff00ff990|r")
    card.OwnedText = ownedText

    -- 2. Buy Button (Right)
    local buyBtn = Theme:CreateButton(card, "Buy x1", 84, 22, true)
    buyBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 6)
    buyBtn:SetScript("OnClick", function()
        Shop:BuyItem(id, 1, card.price, data.name)
    end)
    card.BuyBtn = buyBtn

    -- 3. Cost (Middle / Right aligned beside Buy Button)
    local priceText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    priceText:SetPoint("RIGHT", buyBtn, "LEFT", -12, 0)
    priceText:SetText(string.format("Cost: |cffffd100%d Safari %s|r", card.price, card.price == 1 and "Token" or "Tokens"))
    card.PriceText = priceText

    return card
end

function Shop:BuyItem(itemId, count, unitPrice, itemName)
    -- Enforce Vendor Presence
    local isAuthorized, vType = Shop:IsAtAuthorizedVendor()
    if not isAuthorized and not Shop.isAtVendor then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Purchases restricted! You must speak with an Innkeeper or Pet Trainer.|r")
        PlaySound(847)
        if frame and frame:IsShown() then frame:Hide() end
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

    for _, card in ipairs(itemListFrames) do
        local id = card.itemId
        local count = DB:GetItemCount(id)
        card.OwnedText:SetText(string.format("Owned: |cff00ff99%d|r", count))

        if DB:GetTokens() >= (card.price or 5) then
            card.BuyBtn:Enable()
            card.BuyBtn:SetText("Buy x1")
        else
            card.BuyBtn:Disable()
            card.BuyBtn:SetText("Buy x1")
        end
    end

    Shop:UpdateHealButton()
end

function Shop:ShowShop(fromVendor)
    local isAuth, vType = Shop:IsAtAuthorizedVendor()
    if not isAuth and not fromVendor then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Store access is restricted! Speak with a Pet Trainer (for Capture Gear & Supplies) or an Innkeeper (for Safari Treats & Food Provisions).|r")
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Vendor Required", "Speak to a Pet Trainer or Innkeeper!")
        end
        PlaySound(847)
        return false
    end

    Shop.isAtVendor = true
    Shop.vendorType = vType or Shop.vendorType or "Pet Trainer"

    if not frame then Shop:Initialize() end
    Shop:BuildShopItems()
    frame:Show()
    Shop:UpdateUI()
    PlaySound(844) -- SOUNDKIT.IG_SPELLBOOK_OPEN
    return true
end

function Shop:Toggle()
    local isAuth, vType = Shop:IsAtAuthorizedVendor()
    if not isAuth then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Store access is restricted! Speak with a Pet Trainer (for Capture Gear & Supplies) or an Innkeeper (for Safari Treats & Food Provisions).|r")
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Vendor Required", "Speak to a Pet Trainer or Innkeeper!")
        end
        PlaySound(847)
        return false
    end

    if frame and frame:IsShown() then
        frame:Hide()
    else
        Shop:ShowShop(true)
    end
end

function Shop:IsShown()
    return frame and frame:IsShown()
end
