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
    bannerFrame:SetBackdropBorderColor(0.0, 0.9, 0.4, 0.8)
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

    -- Register Gossip Events for Pet Trainer & Innkeeper Detection
    Shop:RegisterGossipEvents()

    frame:Hide()
end

-- =========================================================================
-- 🏨 VENDOR DETECTION & GOSSIP MENU INTEGRATION
-- =========================================================================
function Shop:IsAtAuthorizedVendor()
    local unit = UnitExists("npc") and "npc" or (UnitExists("target") and "target" or nil)
    
    if unit then
        -- 1. Scan Unit Tooltip for Innkeeper / Pet Trainer / Stable Master titles
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
                    if string.find(lower, "pet trainer") or string.find(lower, "battle pet") or string.find(lower, "pet master") or string.find(lower, "beast trainer") or string.find(lower, "trainer") or string.find(lower, "stable master") or string.find(lower, "stablemaster") or string.find(lower, "stable") then
                        return true, "Pet Trainer"
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
            if string.find(lower, "pet trainer") or string.find(lower, "battle pet") or string.find(lower, "pet master") or string.find(lower, "beast trainer") or string.find(lower, "stable master") or string.find(lower, "stablemaster") then
                return true, "Pet Trainer"
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
                if string.find(lower, "pet") or string.find(lower, "train") or string.find(lower, "stable") or string.find(lower, "beast") then
                    return true, "Pet Trainer"
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
        if string.find(lower, "pet") or string.find(lower, "train") or string.find(lower, "stable") or string.find(lower, "beast") or string.find(lower, "tame") then
            return true, "Pet Trainer"
        elseif string.find(lower, "inn") or string.find(lower, "hearthstone") or string.find(lower, "home") or string.find(lower, "bed") or string.find(lower, "rest") or string.find(lower, "tavern") then
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
        Shop.vendorType = vType or "Pet Trainer"

        -- Auto-heal & revive companion squad when visiting an Innkeeper or Pet Trainer
        if DB and DB.HealTeam then
            local team = DB:GetTeam()
            local needsHealing = false
            for _, mobId in ipairs(team) do
                local m = DB:GetMobById(mobId)
                if m and (not m.currentHP or m.currentHP < (m.maxHP or 10)) then
                    needsHealing = true
                    break
                end
            end
            if needsHealing then
                DB:HealTeam(true)
                local C = ForeverSafari.Constants
                DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00%s tended to your Safari companions! All active team members are fully healed & revived.|r", C.PREFIX, Shop.vendorType))
                if ForeverSafari.Toast then
                    ForeverSafari.Toast:ShowReward("Companions Restored!", string.format("Tended by %s (Team fully healed & revived).", Shop.vendorType))
                end
                PlaySound(895)
            end
        end

        -- Create or Attach Gossip Menu Button to GossipFrame
        if GossipFrame then
            if not gossipBtn then
                gossipBtn = CreateFrame("Button", "ForeverSafariGossipButton", GossipFrame, "BackdropTemplate")
                gossipBtn:SetSize(290, 34)
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
                icon:SetSize(22, 22)
                icon:SetPoint("LEFT", 8, 0)
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                gossipBtn.Icon = icon

                local label = gossipBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
                label:SetPoint("RIGHT", -6, 0)
                label:SetJustifyH("LEFT")
                gossipBtn.Label = label

                gossipBtn:SetScript("OnClick", function()
                    Shop:ShowShop(true)
                end)

                gossipBtn:SetScript("OnEnter", function(self)
                    self:SetBackdropBorderColor(0.0, 1.0, 0.6, 1.0)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    if Shop.vendorType == "Innkeeper" then
                        GameTooltip:AddLine("Nesingwary Safari Provisions", 1, 0.82, 0)
                        GameTooltip:AddLine("Authorized Innkeeper merchant. Purchase Safari Treats, Feasts, and fresh diets.", 1, 1, 1, true)
                    else
                        GameTooltip:AddLine("Nesingwary Safari Supplies", 1, 0.82, 0)
                        GameTooltip:AddLine("Authorized Pet Trainer merchant. Purchase Safari Nets, capsules, and gear.", 1, 1, 1, true)
                    end
                    GameTooltip:Show()
                end)

                gossipBtn:SetScript("OnLeave", function(self)
                    self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                    GameTooltip:Hide()
                end)
            end

            -- Update button style based on vendor type
            if Shop.vendorType == "Innkeeper" then
                gossipBtn.Icon:SetTexture("Interface\\Icons\\INV_Misc_Food_54")
                gossipBtn.Label:SetText("|cffffd100[ 🍖 Browse Safari Treats & Provisions ]|r")
            else
                gossipBtn.Icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
                gossipBtn.Label:SetText("|cffffd100[ 🐾 Browse Safari Nets & Gear ]|r")
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
    -- Close shop immediately when leaving vendor
    if frame and frame:IsShown() then
        frame:Hide()
    end
end

-- =========================================================================
-- 🛒 SHOP ITEMS (PET TRAINER GEAR vs INNKEEPER FOOD)
-- =========================================================================
function Shop:BuildShopItems()
    local content = frame.Content
    
    -- Clear previous items
    for _, card in ipairs(itemListFrames) do
        card:Hide()
    end
    wipe(itemListFrames)

    local yOffset = 0
    local isInnkeeper = (Shop.vendorType == "Innkeeper")

    if isInnkeeper then
        -- INNKEEPER: Treats, Feasts & Family Diets
        frame.Header.Title:SetText("Nesingwary Safari Provisions")
        frame.VendorStatus:SetText("|cff00ff00[ Innkeeper — Food & Treats ]|r")
        frame.BannerText:SetText("|cff00ff99🍖 Licensed Innkeeper Rations: Buy Safari Treats, Feasts, and fresh diets.|r")

        local sec1 = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        sec1:SetPoint("TOPLEFT", 6, yOffset)
        sec1:SetText("|cffffd100Safari Treats & Feasts|r")
        yOffset = yOffset - 26

        local treatKeys = { "az_treat", "az_feast", "healing_salve" }
        for _, id in ipairs(treatKeys) do
            local itemData = C.SHOP_ITEMS[id]
            if itemData then
                local row = Shop:CreateShopItemRow(content, itemData, id, yOffset)
                table.insert(itemListFrames, row)
                yOffset = yOffset - 66
            end
        end

        yOffset = yOffset - 10

        local sec2 = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        sec2:SetPoint("TOPLEFT", 6, yOffset)
        sec2:SetText("|cffffd100Fresh Family Meats & Sustenance|r")
        yOffset = yOffset - 26

        local foodKeys = {
            "food_canine", "food_feline", "food_bear", "food_boar", "food_raptor",
            "food_spider", "food_scorpid", "food_kodo", "food_bat", "food_aquatic",
            "food_reptile", "food_avian", "food_wind serpent"
        }
        for _, id in ipairs(foodKeys) do
            local itemData = C.SAFARI_ITEMS[id]
            if itemData then
                local dataCopy = {
                    name = itemData.name,
                    icon = "Interface\\Icons\\" .. (itemData.icon or "INV_Misc_Food_14"),
                    color = itemData.color or "1eff00",
                    description = itemData.desc or "Fresh harvested sustenance. (+25 Attunement)",
                    price = 3, -- 3 tokens per family food ration
                }
                local row = Shop:CreateShopItemRow(content, dataCopy, id, yOffset)
                table.insert(itemListFrames, row)
                yOffset = yOffset - 66
            end
        end
    else
        -- PET TRAINER: Nets, Capsules & Field Gear
        frame.Header.Title:SetText("Nesingwary Safari Supplies")
        frame.VendorStatus:SetText("|cff00ff00[ Pet Trainer — Nets & Gear ]|r")
        frame.BannerText:SetText("|cff00ff99🐾 Licensed Pet Trainer: Stock up on field research nets, capsules, and revival gear.|r")

        local sec1 = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        sec1:SetPoint("TOPLEFT", 6, yOffset)
        sec1:SetText("|cffffd100Safari Nets & Capsules|r")
        yOffset = yOffset - 26

        local cageKeys = { "copper_cage", "iron_cage", "mithril_cage", "arcanite_capsule" }
        for _, id in ipairs(cageKeys) do
            local itemData = C.CAGES[id]
            local row = Shop:CreateShopItemRow(content, itemData, id, yOffset)
            table.insert(itemListFrames, row)
            yOffset = yOffset - 66
        end

        yOffset = yOffset - 10

        local sec2 = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        sec2:SetPoint("TOPLEFT", 6, yOffset)
        sec2:SetText("|cffffd100Emergency Medical & Revival Gear|r")
        yOffset = yOffset - 26

        local gearKeys = { "healing_salve", "revival_crystal" }
        for _, id in ipairs(gearKeys) do
            local itemData = C.SHOP_ITEMS[id]
            if itemData then
                local row = Shop:CreateShopItemRow(content, itemData, id, yOffset)
                table.insert(itemListFrames, row)
                yOffset = yOffset - 66
            end
        end
    end

    content:SetHeight(math.abs(yOffset) + 30)
end

function Shop:CreateShopItemRow(parent, data, id, yOffset)
    if not data then return nil end
    local card = Theme:CreateCard(parent, 416, 60)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset)
    card.itemId = id
    card.price = data.price or 5

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
    descText:SetText(data.description or "")
    descText:SetTextColor(0.7, 0.7, 0.7)
    card.DescText = descText

    -- Owned count badge
    local ownedText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ownedText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)
    card.OwnedText = ownedText

    -- Price Tag
    local priceText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    priceText:SetPoint("RIGHT", card, "RIGHT", -110, 0)
    priceText:SetText(string.format("|cffffd100%d|r Tokens", card.price))
    card.PriceText = priceText

    -- Buy Button
    local buyBtn = Theme:CreateButton(card, "Buy x1", 95, 26, true)
    buyBtn:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    buyBtn:SetScript("OnClick", function()
        Shop:BuyItem(id, 1, card.price, data.name)
    end)
    card.BuyBtn = buyBtn

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
end

function Shop:ShowShop(fromVendor)
    local isAuth, vType = Shop:IsAtAuthorizedVendor()
    if not isAuth and not fromVendor then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Store access is restricted! Speak with a Pet Trainer (for Safari Nets & Gear) or an Innkeeper (for Safari Treats & Food Provisions).|r")
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
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Store access is restricted! Speak with a Pet Trainer (for Safari Nets & Gear) or an Innkeeper (for Safari Treats & Food Provisions).|r")
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
