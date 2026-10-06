--[[
    Forever Safari: Virtual Safari Bag
    Authentic in-game container frame designed exclusively for storing, organizing,
    and utilizing items tied directly to the Forever Safari addon:
    - Safari Nets & Master Capsules
    - Consumables & Balms (Safari Treats, Safari Feasts, Healing Salves, Revival Crystals)
    - Evolution Catalysts (Shadowfang Essence, Hydra Bile, Venomous Gland, etc.)
    - Family Nourishment Diets (Harvested from downed wild animals across Azeroth)
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.SafariBagFrame = ns.SafariBagFrame or {}

local Bag = ns.SafariBagFrame
local C = ns.Constants
local DB = ns.Database
local Theme = ns.Theme

local TOTAL_SLOTS = 20
local COLUMNS = 4
local ROWS = 5
local SLOT_SIZE = 42
local SLOT_SPACING = 6

local frame = nil
local slotButtons = {}
local bagItems = {}

-- Retrieve item metadata from Constants, Cages, Shop, or Evolution DB
function Bag:GetItemData(itemId)
    if not itemId then return nil end

    -- 1. Check Constants.SAFARI_ITEMS
    if C.SAFARI_ITEMS and C.SAFARI_ITEMS[itemId] then
        local item = C.SAFARI_ITEMS[itemId]
        return {
            id = itemId,
            name = item.name or itemId,
            category = item.category or "Safari Item",
            icon = item.icon or "INV_Misc_QuestionMark",
            quality = item.quality or 1,
            color = item.color or "ffffff",
            desc = item.desc or item.description or "",
            useText = item.useText or "Right-Click to use.",
            family = item.family,
        }
    end

    -- 2. Check Constants.CAGES
    if C.CAGES and C.CAGES[itemId] then
        local cage = C.CAGES[itemId]
        return {
            id = itemId,
            name = cage.name or itemId,
            category = "Safari Net",
            icon = cage.icon or "INV_Misc_Net_01",
            quality = cage.quality or 1,
            color = cage.color or "ffffff",
            desc = cage.description or string.format("Increases capture rate by %.1fx.", cage.rateMultiplier or 1.0),
            useText = "Right-Click to equip as active capture net.",
        }
    end

    -- 3. Check Constants.SHOP_ITEMS
    if C.SHOP_ITEMS and C.SHOP_ITEMS[itemId] then
        local shopItem = C.SHOP_ITEMS[itemId]
        return {
            id = itemId,
            name = shopItem.name or itemId,
            category = "Consumable",
            icon = shopItem.icon or "INV_Misc_Food_11",
            quality = shopItem.quality or 1,
            color = shopItem.color or "ffffff",
            desc = shopItem.description or "",
            useText = "Right-Click to feed or treat companion.",
        }
    end

    -- 4. Check Evolution DB for catalysts
    if itemId:find("^catalyst_") then
        local catId = tonumber(itemId:match("catalyst_(%d+)"))
        if catId and ForeverSafari.EvolutionDB and ForeverSafari.EvolutionDB[catId] then
            local evo = ForeverSafari.EvolutionDB[catId]
            return {
                id = itemId,
                catalystId = catId,
                name = evo.name or "Evolution Catalyst",
                category = "Evolution Catalyst",
                icon = evo.itemIcon or "Spell_Shadow_GatherShadows",
                quality = 4,
                color = "a335ee",
                desc = string.format("Drops from %s. Evolves Rank V %s companions into %s.",
                    evo.source or "Dungeon Bosses", evo.requiredFamily or "Beasts", evo.resultSpecies and evo.resultSpecies.name or "Evolved Companion"),
                useText = "Right-Click to initiate Metamorphosis in the Field Guide.",
                family = evo.requiredFamily,
            }
        end
    end

    -- Fallback generic item
    return {
        id = itemId,
        name = itemId,
        category = "Expedition Item",
        icon = "INV_Misc_Bag_08",
        quality = 1,
        color = "ffffff",
        desc = "An expedition item used in the Safari League.",
        useText = "Right-Click to use.",
    }
end

-- Get category priority for sorting bag contents
local function GetCategoryPriority(itemData)
    if not itemData then return 99 end
    local cat = itemData.category or ""
    if cat == "Safari Net" then
        return 1
    elseif cat == "Consumable" then
        return 2
    elseif cat == "Evolution Catalyst" then
        return 3
    elseif cat == "Family Nourishment" then
        return 4
    end
    return 5
end

-- Format texture paths cleanly
local function NormalizeTexture(icon)
    if not icon or icon == "" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    if icon:find("^Interface\\") then return icon end
    return "Interface\\Icons\\" .. icon
end

function Bag:Initialize()
    if frame then return end

    -- Container Frame
    frame = CreateFrame("Frame", "ForeverSafariSafariBagFrame", UIParent, "BackdropTemplate")
    local frameWidth = (COLUMNS * SLOT_SIZE) + ((COLUMNS - 1) * SLOT_SPACING) + 36
    local frameHeight = (ROWS * SLOT_SIZE) + ((ROWS - 1) * SLOT_SPACING) + 90

    frame:SetSize(frameWidth, frameHeight)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")

    -- Authentic Container Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = false, tileSize = 16, edgeSize = 18,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.06, 0.08, 0.12, 0.96)
    frame:SetBackdropBorderColor(0.9, 0.75, 0.2, 0.95)

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Bag Portrait Icon
    local portraitFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    portraitFrame:SetSize(32, 32)
    portraitFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -7)
    portraitFrame:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    portraitFrame:SetBackdropBorderColor(1.0, 0.82, 0, 1)

    local portrait = portraitFrame:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(28, 28)
    portrait:SetPoint("CENTER", portraitFrame, "CENTER", 0, 0)
    portrait:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
    portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Bag Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", portraitFrame, "RIGHT", 8, 4)
    title:SetText("|cffffd100Safari Bag|r")
    frame.Title = title

    -- Bag Subtitle
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("|cff88aaccNesingwary Pouch|r")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        Bag:HideBag()
    end)

    -- Quick Header Action Buttons (Journal & Shop shortcuts)
    local journalQuickBtn = CreateFrame("Button", nil, frame)
    journalQuickBtn:SetSize(18, 18)
    journalQuickBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    journalQuickBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_09")
    journalQuickBtn:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)
    journalQuickBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    journalQuickBtn:SetScript("OnClick", function()
        if ForeverSafari.JournalFrame then ForeverSafari.JournalFrame:Toggle() end
    end)
    journalQuickBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffffd100Field Guide Journal|r", 1, 1, 1)
        GameTooltip:AddLine("Open the 3D Field Guide and Menagerie.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    journalQuickBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local mailQuickBtn = CreateFrame("Button", nil, frame)
    mailQuickBtn:SetSize(18, 18)
    mailQuickBtn:SetPoint("RIGHT", journalQuickBtn, "LEFT", -4, 0)
    mailQuickBtn:SetNormalTexture("Interface\\Icons\\INV_Letter_15")
    mailQuickBtn:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)
    mailQuickBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    mailQuickBtn:SetScript("OnClick", function()
        if ForeverSafari.SafariMailFrame then ForeverSafari.SafariMailFrame:ToggleStandalone() end
    end)
    mailQuickBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffffd100Safari Dispatch & Bounties|r", 1, 1, 1)
        GameTooltip:AddLine("Read official Nesingwary correspondence and bounties.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    mailQuickBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Container Slot Grid
    local slotContainer = CreateFrame("Frame", nil, frame)
    slotContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -44)
    slotContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 38)
    frame.SlotContainer = slotContainer

    -- Create 20 Item Slot Buttons
    for slotIndex = 1, TOTAL_SLOTS do
        local row = math.floor((slotIndex - 1) / COLUMNS)
        local col = (slotIndex - 1) % COLUMNS

        local slotBtn = CreateFrame("Button", "ForeverSafariBagSlot" .. slotIndex, slotContainer, "BackdropTemplate")
        slotBtn:SetSize(SLOT_SIZE, SLOT_SIZE)
        slotBtn:SetPoint("TOPLEFT", slotContainer, "TOPLEFT", col * (SLOT_SIZE + SLOT_SPACING), -(row * (SLOT_SIZE + SLOT_SPACING)))
        slotBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- Slot Texture & Backdrop
        slotBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 8, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        slotBtn:SetBackdropColor(0.10, 0.12, 0.16, 0.9)
        slotBtn:SetBackdropBorderColor(0.3, 0.35, 0.42, 0.7)

        -- Highlight Texture
        local hl = slotBtn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        hl:SetBlendMode("ADD")

        -- Empty Slot Icon Recess (faded bag icon)
        local emptyIcon = slotBtn:CreateTexture(nil, "BACKGROUND")
        emptyIcon:SetSize(22, 22)
        emptyIcon:SetPoint("CENTER", slotBtn, "CENTER", 0, 0)
        emptyIcon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        emptyIcon:SetAlpha(0.12)
        slotBtn.EmptyIcon = emptyIcon

        -- Item Icon Texture
        local icon = slotBtn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(SLOT_SIZE - 6, SLOT_SIZE - 6)
        icon:SetPoint("CENTER", slotBtn, "CENTER", 0, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:Hide()
        slotBtn.Icon = icon

        -- Quality Border Overlay
        local border = slotBtn:CreateTexture(nil, "OVERLAY")
        border:SetSize(SLOT_SIZE + 2, SLOT_SIZE + 2)
        border:SetPoint("CENTER", slotBtn, "CENTER", 0, 0)
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetBlendMode("ADD")
        border:Hide()
        slotBtn.QualityBorder = border

        -- Stack Count Badge
        local count = slotBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
        count:SetPoint("BOTTOMRIGHT", slotBtn, "BOTTOMRIGHT", -3, 3)
        count:SetTextColor(1, 1, 1, 1)
        count:Hide()
        slotBtn.Count = count

        -- Slot Scripts
        slotBtn.slotIndex = slotIndex
        slotBtn:SetScript("OnEnter", function(self)
            Bag:OnSlotEnter(self)
        end)
        slotBtn:SetScript("OnLeave", function(self)
            Bag:OnSlotLeave(self)
        end)
        slotBtn:SetScript("OnClick", function(self, button)
            Bag:OnSlotClick(self, button)
        end)

        slotButtons[slotIndex] = slotBtn
    end

    -- Bottom Bar: Used Slots Counter & Token Wallet
    local bottomBar = CreateFrame("Frame", nil, frame)
    bottomBar:SetHeight(28)
    bottomBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 6)
    bottomBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 6)

    -- Slots Usage Text
    local slotUsageText = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotUsageText:SetPoint("LEFT", bottomBar, "LEFT", 4, 0)
    slotUsageText:SetText("Slots: 0 / 20")
    frame.SlotUsageText = slotUsageText

    -- Token Wallet Count
    local tokenIcon = bottomBar:CreateTexture(nil, "ARTWORK")
    tokenIcon:SetSize(16, 16)
    tokenIcon:SetPoint("RIGHT", bottomBar, "RIGHT", -2, 0)
    tokenIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
    tokenIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local tokenText = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tokenText:SetPoint("RIGHT", tokenIcon, "LEFT", -4, 0)
    tokenText:SetText("0 Tokens")
    tokenText:SetTextColor(1, 0.85, 0)
    frame.TokenText = tokenText

    frame:Hide()
end

-- Refresh and re-render bag items
function Bag:UpdateUI()
    if not frame or not frame:IsShown() then return end

    -- Update Token Counter
    local tokens = DB:GetTokens()
    frame.TokenText:SetText(string.format("|cffffd100%d|r", tokens))

    -- Gather inventory items from DB with count > 0
    wipe(bagItems)
    local inv = DB:GetInventory()

    for itemId, count in pairs(inv) do
        if count and count > 0 then
            local itemData = Bag:GetItemData(itemId)
            if itemData then
                table.insert(bagItems, {
                    id = itemId,
                    count = count,
                    data = itemData,
                    priority = GetCategoryPriority(itemData),
                })
            end
        end
    end

    -- Sort items by Category Priority, then by Quality descending, then by Name
    table.sort(bagItems, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        if a.data.quality ~= b.data.quality then
            return (a.data.quality or 1) > (b.data.quality or 1)
        end
        return (a.data.name or "") < (b.data.name or "")
    end)

    -- Update Slots
    local usedCount = #bagItems
    for i = 1, TOTAL_SLOTS do
        local slotBtn = slotButtons[i]
        local item = bagItems[i]

        if item then
            slotBtn.item = item
            slotBtn.Icon:SetTexture(NormalizeTexture(item.data.icon))
            slotBtn.Icon:Show()
            slotBtn.EmptyIcon:Hide()

            -- Stack count
            if item.count > 1 then
                slotBtn.Count:SetText(item.count)
                slotBtn.Count:Show()
            else
                slotBtn.Count:Hide()
            end

            -- Quality Border
            local q = item.data.quality or 1
            if q == 2 then -- Uncommon Green
                slotBtn:SetBackdropBorderColor(0.12, 1.0, 0.0, 0.9)
                slotBtn.QualityBorder:SetVertexColor(0.12, 1.0, 0.0, 0.7)
                slotBtn.QualityBorder:Show()
            elseif q == 3 then -- Rare Blue
                slotBtn:SetBackdropBorderColor(0.0, 0.44, 0.87, 0.9)
                slotBtn.QualityBorder:SetVertexColor(0.0, 0.44, 0.87, 0.7)
                slotBtn.QualityBorder:Show()
            elseif q >= 4 then -- Epic Purple
                slotBtn:SetBackdropBorderColor(0.64, 0.21, 0.93, 0.9)
                slotBtn.QualityBorder:SetVertexColor(0.64, 0.21, 0.93, 0.7)
                slotBtn.QualityBorder:Show()
            else -- Common White/Grey
                slotBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.7)
                slotBtn.QualityBorder:Hide()
            end
        else
            slotBtn.item = nil
            slotBtn.Icon:Hide()
            slotBtn.Count:Hide()
            slotBtn.QualityBorder:Hide()
            slotBtn.EmptyIcon:Show()
            slotBtn:SetBackdropBorderColor(0.25, 0.30, 0.38, 0.5)
        end
    end

    -- Update Used Slots counter
    local colorHex = (usedCount >= TOTAL_SLOTS) and "ff3333" or "00ff99"
    frame.SlotUsageText:SetText(string.format("Slots: |cff%s%d|r / %d", colorHex, usedCount, TOTAL_SLOTS))
end

-- Slot Hover Tooltip
function Bag:OnSlotEnter(slotBtn)
    local item = slotBtn.item
    if not item or not item.data then
        GameTooltip:SetOwner(slotBtn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Empty Safari Slot", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Defeat wild beasts, earn dungeon catalysts, or buy safari nets to fill your bag.", 0.5, 0.5, 0.5, true)
        GameTooltip:Show()
        return
    end

    local d = item.data
    GameTooltip:SetOwner(slotBtn, "ANCHOR_RIGHT")

    -- Line 1: Item Name in Quality Color
    GameTooltip:AddLine(string.format("|cff%s[%s]|r", d.color or "ffffff", d.name), 1, 1, 1)

    -- Line 2: Category
    local catColor = "ffd100"
    if d.category == "Family Nourishment" then catColor = "00ff99"
    elseif d.category == "Evolution Catalyst" then catColor = "a335ee"
    elseif d.category == "Safari Net" then catColor = "00bfff" end
    GameTooltip:AddDoubleLine(string.format("|cff%s%s|r", catColor, d.category), string.format("|cffffffffCount: %d|r", item.count))

    -- Line 3: Description
    if d.desc and d.desc ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(d.desc, 0.85, 0.85, 0.85, true)
    end

    -- Active Companion Nourishment Preview
    local activeMob = DB:GetActiveMob()
    if d.category == "Family Nourishment" and activeMob then
        GameTooltip:AddLine(" ")
        local mobFam = activeMob.family or activeMob.creatureType or "Beast"
        local isFav = (d.family and string.lower(d.family) == string.lower(mobFam))
        if isFav then
            GameTooltip:AddLine(string.format("|cff00ff00★ Favorite food for active %s (+25 Attunement)!|r", activeMob.nickname ~= "" and activeMob.nickname or activeMob.name), 1, 1, 1)
        else
            GameTooltip:AddLine(string.format("|cffffd100Active %s enjoys %s food (+15 Attunement).|r", activeMob.nickname ~= "" and activeMob.nickname or activeMob.name, d.family or "this"), 1, 1, 1)
        end
    end

    -- Line 4: Right-Click Action Prompt
    if d.useText and d.useText ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("|cff00ff00<%s>|r", d.useText), 0, 1, 0)
    end

    GameTooltip:AddLine("|cff778899<Shift-Left-Click to Link in Chat>|r", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function Bag:OnSlotLeave(slotBtn)
    GameTooltip:Hide()
end

-- Slot Click Handlers (Right-Click Use & Shift-Click Chat Link)
function Bag:OnSlotClick(slotBtn, button)
    local item = slotBtn.item
    if not item or not item.data then return end

    local itemId = item.id
    local d = item.data

    -- Shift-Left-Click: Insert Chat Link
    if button == "LeftButton" and IsShiftKeyDown() then
        local link = string.format("|cff%s[%s]|r", d.color or "ffffff", d.name)
        if ChatEdit_InsertLink then
            if not ChatEdit_InsertLink(link) then
                DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "Item: " .. link)
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "Item: " .. link)
        end
        return
    end

    -- Right-Click: Use Item
    if button == "RightButton" then
        Bag:UseItem(itemId, d)
    end
end

-- Context-sensitive item usage dispatcher
function Bag:UseItem(itemId, itemData)
    local activeMob = DB:GetActiveMob()

    -- 1. 🕸️ Safari Nets: Equip as active net or attempt capture
    if itemData.category == "Safari Net" then
        if ForeverSafari.CaptureHUD and ForeverSafari.CaptureHUD.SelectCage then
            ForeverSafari.CaptureHUD:SelectCage(itemId)
            if not ForeverSafari.CaptureHUD:IsShown() and UnitExists("target") then
                ForeverSafari.CaptureHUD:ShowHUD()
            end
        end
        PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%sEquipped |cff%s[%s]|r as your active safari capture net.",
            C.PREFIX, itemData.color or "ffffff", itemData.name))
        return
    end

    -- 2. 🥩 Family Nourishment: Feed active companion for Attunement
    if itemData.category == "Family Nourishment" then
        if not activeMob then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444You do not have an active companion summoned to feed.|r")
            PlaySound(847)
            return
        end

        local mobFam = activeMob.family or activeMob.creatureType or "Beast"
        local isFavorite = (itemData.family and string.lower(itemData.family) == string.lower(mobFam))
        local attunementGain = isFavorite and 25 or 15

        if DB:RemoveItem(itemId, 1) then
            PlaySound(844) -- SOUNDKIT.IG_SPELLBOOK_OPEN (chew)
            local pName = activeMob.nickname ~= "" and activeMob.nickname or activeMob.name
            DB:AddAttunement(activeMob.id, attunementGain, "Nourished with " .. itemData.name)
            DB:UpdateQuestProgress("FEED", 1)

            if isFavorite then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00Fed favorite [%s] to %s! (+%d Attunement Loyalty)|r",
                    C.PREFIX, itemData.name, pName, attunementGain))
            else
                DEFAULT_CHAT_FRAME:AddMessage(string.format("%sFed |cffffd100[%s]|r to %s (+%d Attunement).",
                    C.PREFIX, itemData.name, pName, attunementGain))
            end

            Bag:UpdateUI()
        end
        return
    end

    -- 3. 🍖 Consumables: Safari Treats, Feasts, Salves, Revival Crystals
    if itemId == "az_treat" then
        if not activeMob then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444You do not have an active companion summoned to feed.|r")
            PlaySound(847)
            return
        end
        if DB:RemoveItem("az_treat", 1) then
            PlaySound(844)
            local pName = activeMob.nickname ~= "" and activeMob.nickname or activeMob.name
            DB:AddAttunement(activeMob.id, 50, "Safari Treat")
            DB:UpdateQuestProgress("FEED", 1)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00Fed [Safari Treat] to %s! (+50 Attunement Loyalty)|r", C.PREFIX, pName))
            Bag:UpdateUI()
        end
        return
    elseif itemId == "az_feast" then
        local team = DB:GetTeam()
        if #team == 0 then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444No companions in your active team to feast.|r")
            PlaySound(847)
            return
        end
        if DB:RemoveItem("az_feast", 1) then
            PlaySound(1195)
            for _, member in ipairs(team) do
                DB:AddAttunement(member.id, 100, "Grand Safari Feast")
            end
            DB:UpdateQuestProgress("FEED", math.max(1, #team))
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00Served [Grand Safari Feast] to all %d companions in your team! (+100 Attunement each)|r", C.PREFIX, #team))
            Bag:UpdateUI()
        end
        return
    elseif itemId == "healing_salve" then
        if not activeMob then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444No active companion summoned to heal.|r")
            PlaySound(847)
            return
        end
        local currentHP = activeMob.hp or activeMob.currentHP or activeMob.maxHP or 10
        local maxHP = activeMob.maxHP or 10
        if currentHP >= maxHP then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffffd100Your active companion is already at full health.|r")
            return
        end
        if DB:RemoveItem("healing_salve", 1) then
            activeMob.hp = maxHP
            activeMob.currentHP = maxHP
            DB:SignMob(activeMob)
            PlaySound(895)
            local pName = activeMob.nickname ~= "" and activeMob.nickname or activeMob.name
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00Applied Safari Healing Salve! %s restored to full health (%d HP).|r", C.PREFIX, pName, maxHP))
            Bag:UpdateUI()
            if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame:IsShown() then
                ForeverSafari.JournalFrame:UpdateUI()
            end
        end
        return
    elseif itemId == "revival_crystal" then
        if not activeMob then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444No active companion selected to revive.|r")
            PlaySound(847)
            return
        end
        local currentHP = activeMob.hp or activeMob.currentHP or activeMob.maxHP or 10
        if currentHP > 0 then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffffd100Your active companion is not fainted.|r")
            return
        end
        if DB:RemoveItem("revival_crystal", 1) then
            activeMob.hp = activeMob.maxHP
            activeMob.currentHP = activeMob.maxHP
            DB:SignMob(activeMob)
            PlaySound(1195)
            local pName = activeMob.nickname ~= "" and activeMob.nickname or activeMob.name
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00Used Revival Crystal! %s was revived back to full health!|r", C.PREFIX, pName))
            Bag:UpdateUI()
            if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame:IsShown() then
                ForeverSafari.JournalFrame:UpdateUI()
            end
        end
        return
    end

    -- 4. 🧬 Evolution Catalysts: Initiate Metamorphosis
    if itemData.category == "Evolution Catalyst" or itemId:find("^catalyst_") then
        local catId = itemData.catalystId or tonumber(itemId:match("catalyst_(%d+)"))
        if not catId then return end

        local evo = ForeverSafari:GetEvolution(catId)
        if not evo then return end

        -- Check if active companion or any collection mob is ready for this catalyst
        if activeMob then
            local canEvolve, reason = ForeverSafari:CanEvolveCompanion(activeMob, catId)
            if canEvolve then
                if ForeverSafari.JournalFrame then
                    ForeverSafari.JournalFrame:ShowJournal()
                    -- Switch to Showcase and open Metamorphosis drawer
                    if ForeverSafari.JournalFrame.SetTab then ForeverSafari.JournalFrame:SetTab("SHOWCASE") end
                    if ForeverSafari.JournalFrame.OpenMetamorphosisDrawer then
                        ForeverSafari.JournalFrame:OpenMetamorphosisDrawer(catId)
                    end
                end
                DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffa335ee[Metamorphosis Pedestal Activated]|r Open Field Guide to evolve %s with [%s]!",
                    C.PREFIX, activeMob.nickname ~= "" and activeMob.nickname or activeMob.name, evo.name))
                PlaySound(1195)
                return
            else
                DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffff4444[Evolution Requirements Not Met]|r %s", C.PREFIX, reason))
                PlaySound(847)
                return
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Select a Rank V: Bestial Symbiosis companion to undergo Metamorphosis.|r")
            PlaySound(847)
            return
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage(string.format("%sUsed [%s].", C.PREFIX, itemData.name))
end

-- Open / Close / Toggle Bag
function Bag:ShowBag()
    if not frame then Bag:Initialize() end
    frame:Show()
    Bag:UpdateUI()
    PlaySound(862) -- SOUNDKIT.IG_BACKPACK_OPEN
end

function Bag:HideBag()
    if frame and frame:IsShown() then
        frame:Hide()
        PlaySound(863) -- SOUNDKIT.IG_BACKPACK_CLOSE
    end
end

function Bag:Toggle()
    if not frame then Bag:Initialize() end
    if frame:IsShown() then
        Bag:HideBag()
    else
        Bag:ShowBag()
    end
end

function Bag:IsShown()
    return frame and frame:IsShown()
end
