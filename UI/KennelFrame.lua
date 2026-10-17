--[[
    Forever Safari: Junior Safari Reserve & Banked Companion Vault (KennelFrame.lua)
    - Standalone window accessible from Banker gossip ("Junior Safari League: Access Companion Reserve")
    - 400-Slot Storage: 20 Enclosures x 20 Slots each with Prev/Next switcher, Quick-Jump, and Custom Renaming.
    - Safari Journal Design Language: Search editbox, Type/Family filter, Biological Sex toggle (♂/♀/⚙), and Apex Rarity filter.
    - Zero Taint: Top-level independent frame parented to UIParent with ESC key closure via UISpecialFrames.
    - Micro Tile Badges: Micro Sex Badges (♂ cyan, ♀ pink, ⚙ silver), Apex Crown (👑), Attunement Rank, and rich tooltips.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.KennelFrame = ns.KennelFrame or {}

local Kennel = ns.KennelFrame
local C = ns.Constants
local DB = ns.Database
local SE = ns.StatEngine
local Theme = ns.Theme

local frame = nil
local activeCards = {}
local kennelTiles = {}
local currentBox = 1
local selectedKennelMobId = nil
local selectedSquadSlot = nil

-- Filter states
local searchQuery = ""
local filterType = "ALL"
local filterSex = "ALL"
local filterRarity = "ALL"

local TYPE_FILTERS = {
    { id = "ALL", text = "All Types" },
    { id = "Beast", text = "🐾 Beast" },
    { id = "Mechanical", text = "⚙️ Mechanical" },
    { id = "Undead", text = "💀 Undead" },
    { id = "Elemental", text = "🌋 Elemental" },
    { id = "Dragonkin", text = "🐉 Dragonkin" },
    { id = "Aquatic", text = "🌊 Aquatic" },
    { id = "Flying", text = "🦅 Flying" },
    { id = "Magic", text = "✨ Magic" },
}

local SEX_FILTERS = {
    { id = "ALL", text = "All Sexes" },
    { id = "Sire", text = "|cff66ccff♂ Sires (Males)|r" },
    { id = "Dam", text = "|cffff99cc♀ Dams (Females)|r" },
    { id = "Genderless", text = "|cffa0a0a0⚙ Genderless|r" },
}

local RARITY_FILTERS = {
    { id = "ALL", text = "All Rarities" },
    { id = "RARE", text = "|cffffd100👑 Apex Rares|r" },
    { id = "COMMON", text = "Standard (100)" },
}

-- StaticPopup for Renaming Enclosure
StaticPopupDialogs["FOREVER_SAFARI_RENAME_ENCLOSURE"] = {
    text = "Enter a custom name for Enclosure %d:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 24,
    OnShow = function(self, data)
        local curName = DB and DB.GetBoxName and DB:GetBoxName(data) or string.format("Enclosure %d", data)
        self.editBox:SetText(curName)
        self.editBox:HighlightText()
    end,
    OnAccept = function(self, data)
        local text = self.editBox:GetText()
        if DB and DB.SetBoxName then
            DB:SetBoxName(data, text)
            if Kennel and Kennel.UpdateUI then
                Kennel:UpdateUI()
            end
        end
    end,
    EditBoxOnEnterPressed = function(self, data)
        local text = self:GetText()
        if DB and DB.SetBoxName then
            DB:SetBoxName(data, text)
            if Kennel and Kennel.UpdateUI then
                Kennel:UpdateUI()
            end
        end
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function isSecret(v)
    if v == nil then return false end
    if issecret and issecret(v) then return true end
    if type(v) == "userdata" then return true end
    return false
end

-- Check if currently interacting with a Banker
function Kennel:IsAtBanker()
    if BankFrame and BankFrame:IsShown() then
        return true
    end
    local unit = UnitExists("npc") and "npc" or (UnitExists("target") and "target" or nil)
    if unit then
        if C_TooltipInfo and C_TooltipInfo.GetUnit then
            local ok, info = pcall(C_TooltipInfo.GetUnit, unit)
            if ok and info and info.lines then
                for _, line in ipairs(info.lines) do
                    if line.leftText then
                        local lower = string.lower(line.leftText)
                        if string.find(lower, "banker", 1, true) or string.find(lower, "vault", 1, true) then
                            return true
                        end
                    end
                end
            end
        end
        local unitName = UnitName(unit)
        if unitName and (string.find(string.lower(unitName), "banker", 1, true) or string.find(string.lower(unitName), "vault", 1, true)) then
            return true
        end
    end
    return false
end

function Kennel:Initialize()
    if frame then return end

    frame = CreateFrame("Frame", "ForeverSafariKennelFrame", UIParent, "BackdropTemplate")
    frame:SetSize(760, 440)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    Theme:ApplyFrameBackdrop(frame)

    -- Draggable
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- ESC Key Support
    tinsert(UISpecialFrames, "ForeverSafariKennelFrame")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() Kennel:Hide() end)

    -- Top Header Title
    local header = CreateFrame("Frame", nil, frame)
    header:SetSize(680, 24)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    title:SetPoint("LEFT", 4, 0)
    title:SetText("|cffffd100🐾 Junior Safari Reserve|r")
    header.Title = title

    local subTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subTitle:SetPoint("LEFT", title, "RIGHT", 10, 0)
    subTitle:SetText("|cff00ff99[ Banked Companion Vault • 400 Slots ]|r")

    -- =========================================================================
    -- LEFT COLUMN: ACTIVE SQUAD (4 Slots)
    -- =========================================================================
    local squadTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    squadTitle:SetPoint("TOPLEFT", 14, -36)
    squadTitle:SetText("|cffffd100Active Squad (4 Max)|r")

    for i = 1, 4 do
        local card = CreateFrame("Button", "ForeverSafariKennelSquadCard" .. i, frame, "BackdropTemplate")
        card:SetSize(218, 70)
        card:SetPoint("TOPLEFT", 14, -56 - ((i - 1) * 74))
        Theme:ApplyCardBackdrop(card)
        card.slotIndex = i

        -- 3D Model
        local model = CreateFrame("PlayerModel", nil, card)
        model:SetSize(52, 52)
        model:SetPoint("LEFT", 6, 0)
        if model.SetPortraitZoom then model:SetPortraitZoom(0.85) end
        if model.SetRotation then model:SetRotation(math.rad(25)) end
        card.Model = model

        -- Name Text
        local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("TOPLEFT", model, "TOPRIGHT", 8, -2)
        nameText:SetJustifyH("LEFT")
        nameText:SetText("Empty Slot")
        card.NameText = nameText

        -- Info / Rank / Sex Text
        local infoText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        infoText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
        infoText:SetText("")
        card.InfoText = infoText

        -- HP Status Bar
        local hpBar = CreateFrame("StatusBar", nil, card)
        hpBar:SetSize(130, 8)
        hpBar:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", 0, -3)
        hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        hpBar:SetStatusBarColor(0.2, 0.8, 0.4)
        hpBar:SetMinMaxValues(0, 100)
        hpBar:SetValue(100)
        card.HPBar = hpBar

        -- Deposit Button
        local depBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
        depBtn:SetSize(58, 18)
        depBtn:SetPoint("BOTTOMRIGHT", -4, 4)
        depBtn:SetText("Deposit")
        depBtn:SetScript("OnClick", function()
            if card.mobId then
                local ok, err = DB:MoveToKennel(card.mobId, currentBox)
                if not ok and err then
                    DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444" .. err .. "|r")
                    PlaySound(847)
                else
                    PlaySound(856)
                    Kennel:UpdateUI()
                end
            end
        end)
        card.DepositBtn = depBtn

        card:SetScript("OnClick", function()
            if selectedKennelMobId then
                DB:SwapSquadAndKennel(i, selectedKennelMobId)
                selectedKennelMobId = nil
                PlaySound(856)
                Kennel:UpdateUI()
            end
        end)

        activeCards[i] = card
    end

    -- =========================================================================
    -- RIGHT AREA: BOX SWITCHER & SEARCH/FILTER CONTROLS
    -- =========================================================================
    local rightX = 246

    -- Row 1: Box Switcher Bar (Y = -34)
    local switcherBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    switcherBar:SetSize(498, 26)
    switcherBar:SetPoint("TOPLEFT", rightX, -34)
    Theme:ApplyCardBackdrop(switcherBar)
    frame.SwitcherBar = switcherBar

    -- Prev Box Button
    local prevBtn = CreateFrame("Button", nil, switcherBar, "UIPanelButtonTemplate")
    prevBtn:SetSize(30, 20)
    prevBtn:SetPoint("LEFT", 4, 0)
    prevBtn:SetText("◀")
    prevBtn:SetScript("OnClick", function()
        currentBox = currentBox - 1
        if currentBox < 1 then currentBox = C.MAX_KENNEL_BOXES or 20 end
        selectedKennelMobId = nil
        PlaySound(844)
        Kennel:UpdateUI()
    end)
    switcherBar.PrevBtn = prevBtn

    -- Next Box Button
    local nextBtn = CreateFrame("Button", nil, switcherBar, "UIPanelButtonTemplate")
    nextBtn:SetSize(30, 20)
    nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
    nextBtn:SetText("▶")
    nextBtn:SetScript("OnClick", function()
        currentBox = currentBox + 1
        if currentBox > (C.MAX_KENNEL_BOXES or 20) then currentBox = 1 end
        selectedKennelMobId = nil
        PlaySound(844)
        Kennel:UpdateUI()
    end)
    switcherBar.NextBtn = nextBtn

    -- Box Title & Slot Count
    local boxTitleText = switcherBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    boxTitleText:SetPoint("LEFT", nextBtn, "RIGHT", 10, 0)
    boxTitleText:SetText("Enclosure 1 (0/20)")
    switcherBar.BoxTitleText = boxTitleText

    -- Quick-Jump Button
    local jumpBtn = CreateFrame("Button", nil, switcherBar, "UIPanelButtonTemplate")
    jumpBtn:SetSize(62, 20)
    jumpBtn:SetPoint("RIGHT", -76, 0)
    jumpBtn:SetText("Jump ▼")
    switcherBar.JumpBtn = jumpBtn

    -- Rename Box Button
    local renameBtn = CreateFrame("Button", nil, switcherBar, "UIPanelButtonTemplate")
    renameBtn:SetSize(68, 20)
    renameBtn:SetPoint("RIGHT", -4, 0)
    renameBtn:SetText("🏷 Rename")
    renameBtn:SetScript("OnClick", function()
        StaticPopup_Show("FOREVER_SAFARI_RENAME_ENCLOSURE", currentBox, nil, currentBox)
    end)
    switcherBar.RenameBtn = renameBtn

    -- Row 2: Search & Filter Ribbon (Y = -64)
    local filterBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    filterBar:SetSize(498, 24)
    filterBar:SetPoint("TOPLEFT", rightX, -64)
    Theme:ApplyCardBackdrop(filterBar)
    frame.FilterBar = filterBar

    -- Search Box
    local searchBg = CreateFrame("Frame", nil, filterBar, "BackdropTemplate")
    searchBg:SetSize(130, 18)
    searchBg:SetPoint("LEFT", 4, 0)
    Theme:ApplyCardBackdrop(searchBg)

    local searchBox = CreateFrame("EditBox", "ForeverSafariKennelSearchBox", searchBg)
    searchBox:SetSize(122, 16)
    searchBox:SetPoint("LEFT", 4, 0)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox:SetAutoFocus(false)

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", 2, 0)
    searchPlaceholder:SetText("🔍 Search...")
    searchBox.Placeholder = searchPlaceholder

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        searchQuery = string.lower(strtrim(text))
        if searchQuery == "" then
            self.Placeholder:Show()
        else
            self.Placeholder:Hide()
        end
        Kennel:UpdateUI()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    filterBar.SearchBox = searchBox

    -- Type Filter Button
    local typeBtn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
    typeBtn:SetSize(110, 18)
    typeBtn:SetPoint("LEFT", searchBg, "RIGHT", 4, 0)
    Theme:ApplyCardBackdrop(typeBtn)

    local typeText = typeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    typeText:SetPoint("LEFT", 6, 0)
    typeText:SetText("Type: All ▼")
    typeBtn.Text = typeText
    filterBar.TypeBtn = typeBtn

    -- Sex Filter Button
    local sexBtn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
    sexBtn:SetSize(100, 18)
    sexBtn:SetPoint("LEFT", typeBtn, "RIGHT", 4, 0)
    Theme:ApplyCardBackdrop(sexBtn)

    local sexText = sexBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sexText:SetPoint("LEFT", 6, 0)
    sexText:SetText("Sex: All ▼")
    sexBtn.Text = sexText
    filterBar.SexBtn = sexBtn

    -- Rarity Filter Button
    local rarityBtn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
    rarityBtn:SetSize(86, 18)
    rarityBtn:SetPoint("LEFT", sexBtn, "RIGHT", 4, 0)
    Theme:ApplyCardBackdrop(rarityBtn)

    local rarityText = rarityBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rarityText:SetPoint("LEFT", 6, 0)
    rarityText:SetText("Rarity: All ▼")
    rarityBtn.Text = rarityText
    filterBar.RarityBtn = rarityBtn

    -- Reset Filters Button
    local resetFiltersBtn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
    resetFiltersBtn:SetSize(22, 18)
    resetFiltersBtn:SetPoint("RIGHT", -4, 0)
    Theme:ApplyCardBackdrop(resetFiltersBtn)
    local resetText = resetFiltersBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetText:SetPoint("CENTER", 0, 0)
    resetText:SetText("✕")
    resetFiltersBtn:SetScript("OnClick", function()
        searchQuery = ""
        searchBox:SetText("")
        filterType = "ALL"
        typeText:SetText("Type: All ▼")
        filterSex = "ALL"
        sexText:SetText("Sex: All ▼")
        filterRarity = "ALL"
        rarityText:SetText("Rarity: All ▼")
        Kennel:UpdateUI()
        PlaySound(856)
    end)
    resetFiltersBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Reset Filters", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    resetFiltersBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- =========================================================================
    -- POPUP MENUS (Jump, Type, Sex, Rarity)
    -- =========================================================================
    -- 1. Jump Menu (2 Columns of 10 Boxes)
    local jumpMenu = CreateFrame("Frame", "ForeverSafariKennelJumpMenu", frame, "BackdropTemplate")
    jumpMenu:SetSize(320, 216)
    jumpMenu:SetPoint("TOPRIGHT", switcherBar, "BOTTOMRIGHT", 0, -2)
    jumpMenu:SetFrameStrata("DIALOG")
    Theme:ApplyCardBackdrop(jumpMenu)
    jumpMenu:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
    jumpMenu:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9)
    jumpMenu:Hide()
    frame.JumpMenu = jumpMenu

    jumpMenu.Items = {}
    for b = 1, (C.MAX_KENNEL_BOXES or 20) do
        local col = (b <= 10) and 1 or 2
        local row = (b <= 10) and b or (b - 10)
        local itemBtn = CreateFrame("Button", nil, jumpMenu, "BackdropTemplate")
        itemBtn:SetSize(150, 18)
        itemBtn:SetPoint("TOPLEFT", jumpMenu, "TOPLEFT", 6 + ((col - 1) * 154), -6 - ((row - 1) * 20))

        local itemText = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemText:SetPoint("LEFT", 4, 0)
        itemText:SetPoint("RIGHT", -4, 0)
        itemText:SetJustifyH("LEFT")
        itemBtn.Text = itemText

        itemBtn:SetScript("OnClick", function()
            currentBox = b
            selectedKennelMobId = nil
            jumpMenu:Hide()
            PlaySound(844)
            Kennel:UpdateUI()
        end)
        itemBtn:SetScript("OnEnter", function(self)
            self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            self:SetBackdropColor(1.0, 0.82, 0.0, 0.25)
        end)
        itemBtn:SetScript("OnLeave", function(self)
            self:SetBackdrop(nil)
        end)
        jumpMenu.Items[b] = itemBtn
    end

    jumpBtn:SetScript("OnClick", function()
        if frame.TypeMenu and frame.TypeMenu:IsShown() then frame.TypeMenu:Hide() end
        if frame.SexMenu and frame.SexMenu:IsShown() then frame.SexMenu:Hide() end
        if frame.RarityMenu and frame.RarityMenu:IsShown() then frame.RarityMenu:Hide() end
        if jumpMenu:IsShown() then
            jumpMenu:Hide()
        else
            -- Refresh jump menu labels with current counts and box names
            for b = 1, (C.MAX_KENNEL_BOXES or 20) do
                local bName = DB and DB.GetBoxName and DB:GetBoxName(b) or ("Enclosure " .. b)
                local count = DB and DB.GetKennelMobs and #DB:GetKennelMobs(b) or 0
                local prefix = (b == currentBox) and "|cffffd100▶ |r" or ""
                jumpMenu.Items[b].Text:SetText(string.format("%s%d. %s (|cff00ff99%d|r)", prefix, b, bName, count))
            end
            jumpMenu:Show()
        end
        PlaySound(856)
    end)

    -- 2. Type Menu
    local typeMenu = CreateFrame("Frame", "ForeverSafariKennelTypeMenu", frame, "BackdropTemplate")
    typeMenu:SetSize(140, #TYPE_FILTERS * 20 + 8)
    typeMenu:SetPoint("TOPLEFT", typeBtn, "BOTTOMLEFT", 0, -2)
    typeMenu:SetFrameStrata("DIALOG")
    Theme:ApplyCardBackdrop(typeMenu)
    typeMenu:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
    typeMenu:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9)
    typeMenu:Hide()
    frame.TypeMenu = typeMenu

    for idx, opt in ipairs(TYPE_FILTERS) do
        local itemBtn = CreateFrame("Button", nil, typeMenu, "BackdropTemplate")
        itemBtn:SetSize(132, 18)
        itemBtn:SetPoint("TOPLEFT", typeMenu, "TOPLEFT", 4, -4 - ((idx - 1) * 20))
        local itemText = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemText:SetPoint("LEFT", 6, 0)
        itemText:SetText(opt.text)

        itemBtn:SetScript("OnClick", function()
            filterType = opt.id
            typeText:SetText(string.format("Type: |cffffd100%s|r ▼", opt.id == "ALL" and "All" or opt.id))
            typeMenu:Hide()
            Kennel:UpdateUI()
            PlaySound(856)
        end)
        itemBtn:SetScript("OnEnter", function(self)
            self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            self:SetBackdropColor(1.0, 0.82, 0.0, 0.25)
        end)
        itemBtn:SetScript("OnLeave", function(self) self:SetBackdrop(nil) end)
    end

    typeBtn:SetScript("OnClick", function()
        if jumpMenu:IsShown() then jumpMenu:Hide() end
        if frame.SexMenu:IsShown() then frame.SexMenu:Hide() end
        if frame.RarityMenu:IsShown() then frame.RarityMenu:Hide() end
        if typeMenu:IsShown() then typeMenu:Hide() else typeMenu:Show() end
        PlaySound(856)
    end)

    -- 3. Sex Menu
    local sexMenu = CreateFrame("Frame", "ForeverSafariKennelSexMenu", frame, "BackdropTemplate")
    sexMenu:SetSize(140, #SEX_FILTERS * 20 + 8)
    sexMenu:SetPoint("TOPLEFT", sexBtn, "BOTTOMLEFT", 0, -2)
    sexMenu:SetFrameStrata("DIALOG")
    Theme:ApplyCardBackdrop(sexMenu)
    sexMenu:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
    sexMenu:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9)
    sexMenu:Hide()
    frame.SexMenu = sexMenu

    for idx, opt in ipairs(SEX_FILTERS) do
        local itemBtn = CreateFrame("Button", nil, sexMenu, "BackdropTemplate")
        itemBtn:SetSize(132, 18)
        itemBtn:SetPoint("TOPLEFT", sexMenu, "TOPLEFT", 4, -4 - ((idx - 1) * 20))
        local itemText = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemText:SetPoint("LEFT", 6, 0)
        itemText:SetText(opt.text)

        itemBtn:SetScript("OnClick", function()
            filterSex = opt.id
            sexText:SetText(string.format("Sex: |cffffd100%s|r ▼", opt.id == "ALL" and "All" or (opt.id == "Dam" and "♀" or (opt.id == "Sire" and "♂" or "⚙"))))
            sexMenu:Hide()
            Kennel:UpdateUI()
            PlaySound(856)
        end)
        itemBtn:SetScript("OnEnter", function(self)
            self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            self:SetBackdropColor(1.0, 0.82, 0.0, 0.25)
        end)
        itemBtn:SetScript("OnLeave", function(self) self:SetBackdrop(nil) end)
    end

    sexBtn:SetScript("OnClick", function()
        if jumpMenu:IsShown() then jumpMenu:Hide() end
        if typeMenu:IsShown() then typeMenu:Hide() end
        if frame.RarityMenu:IsShown() then frame.RarityMenu:Hide() end
        if sexMenu:IsShown() then sexMenu:Hide() else sexMenu:Show() end
        PlaySound(856)
    end)

    -- 4. Rarity Menu
    local rarityMenu = CreateFrame("Frame", "ForeverSafariKennelRarityMenu", frame, "BackdropTemplate")
    rarityMenu:SetSize(140, #RARITY_FILTERS * 20 + 8)
    rarityMenu:SetPoint("TOPLEFT", rarityBtn, "BOTTOMLEFT", 0, -2)
    rarityMenu:SetFrameStrata("DIALOG")
    Theme:ApplyCardBackdrop(rarityMenu)
    rarityMenu:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
    rarityMenu:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9)
    rarityMenu:Hide()
    frame.RarityMenu = rarityMenu

    for idx, opt in ipairs(RARITY_FILTERS) do
        local itemBtn = CreateFrame("Button", nil, rarityMenu, "BackdropTemplate")
        itemBtn:SetSize(132, 18)
        itemBtn:SetPoint("TOPLEFT", rarityMenu, "TOPLEFT", 4, -4 - ((idx - 1) * 20))
        local itemText = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemText:SetPoint("LEFT", 6, 0)
        itemText:SetText(opt.text)

        itemBtn:SetScript("OnClick", function()
            filterRarity = opt.id
            rarityText:SetText(string.format("Rarity: |cffffd100%s|r ▼", opt.id == "ALL" and "All" or (opt.id == "RARE" and "👑 Apex" or "Std")))
            rarityMenu:Hide()
            Kennel:UpdateUI()
            PlaySound(856)
        end)
        itemBtn:SetScript("OnEnter", function(self)
            self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            self:SetBackdropColor(1.0, 0.82, 0.0, 0.25)
        end)
        itemBtn:SetScript("OnLeave", function(self) self:SetBackdrop(nil) end)
    end

    rarityBtn:SetScript("OnClick", function()
        if jumpMenu:IsShown() then jumpMenu:Hide() end
        if typeMenu:IsShown() then typeMenu:Hide() end
        if sexMenu:IsShown() then sexMenu:Hide() end
        if rarityMenu:IsShown() then rarityMenu:Hide() else rarityMenu:Show() end
        PlaySound(856)
    end)

    -- =========================================================================
    -- ROW 3: KENNEL 20-SLOT TILE GRID (4 rows x 5 columns)
    -- =========================================================================
    local gridContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    gridContainer:SetSize(498, 290)
    gridContainer:SetPoint("TOPLEFT", rightX, -92)
    Theme:ApplyCardBackdrop(gridContainer)

    local tileSize = 44
    for row = 1, 4 do
        for col = 1, 5 do
            local idx = (row - 1) * 5 + col
            local tile = CreateFrame("Button", "ForeverSafariKennelTile" .. idx, gridContainer, "BackdropTemplate")
            tile:SetSize(tileSize, tileSize)
            tile:SetPoint("TOPLEFT", 14 + ((col - 1) * 96), -8 - ((row - 1) * 68))
            Theme:ApplyCardBackdrop(tile)

            local icon = tile:CreateTexture(nil, "ARTWORK")
            icon:SetSize(tileSize - 6, tileSize - 6)
            icon:SetPoint("CENTER", 0, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            tile.Icon = icon

            -- Micro Sex Badge (Top-Right)
            local sexBadge = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            sexBadge:SetPoint("TOPRIGHT", -2, -2)
            sexBadge:SetFont(sexBadge:GetFont(), 11, "OUTLINE")
            sexBadge:SetText("")
            tile.SexBadge = sexBadge

            -- Micro Apex Crown (Top-Left)
            local crownBadge = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            crownBadge:SetPoint("TOPLEFT", 2, -2)
            crownBadge:SetFont(crownBadge:GetFont(), 10, "OUTLINE")
            crownBadge:SetText("👑")
            crownBadge:Hide()
            tile.CrownBadge = crownBadge

            -- Name & Rank Label Below Tile
            local label = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("TOP", tile, "BOTTOM", 0, -2)
            label:SetWidth(92)
            label:SetJustifyH("CENTER")
            label:SetText("")
            tile.Label = label

            -- Selection Glow
            local glow = tile:CreateTexture(nil, "OVERLAY")
            glow:SetAllPoints()
            glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
            glow:SetBlendMode("ADD")
            glow:Hide()
            tile.SelGlow = glow

            tile:SetScript("OnClick", function()
                if tile.mobId then
                    if selectedKennelMobId == tile.mobId then
                        selectedKennelMobId = nil
                    else
                        selectedKennelMobId = tile.mobId
                    end
                    PlaySound(856)
                    Kennel:UpdateUI()
                end
            end)

            tile:SetScript("OnEnter", function(self)
                if self.mobId then
                    local mob = DB:GetMobById(self.mobId)
                    if mob then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        local rankData = SE:GetAttunementRank(mob.attunement or mob.attunementPoints or 0)
                        local anat = mob.anatomy or "Sire"
                        local anatStr = (anat == "Dam" and "|cffff99cc♀ Dam (Female)|r") or (anat == "Genderless" and "|cffa0a0a0⚙ Genderless (Construct)|r") or "|cff66ccff♂ Sire (Male)|r"
                        local crownStr = (mob.isRare or mob.isElite) and " |cffffd100[👑 Apex Rare]|r" or ""

                        GameTooltip:AddLine(string.format("|cff%s%s|r%s", rankData.color or "ffffff", mob.nickname ~= "" and mob.nickname or mob.name, crownStr), 1, 1, 1)
                        GameTooltip:AddLine(string.format("%s • %s — Rank %s (%s)", mob.creatureType or "Beast", mob.family or "Beast", rankData.roman, rankData.title), 0.8, 0.8, 0.8)
                        GameTooltip:AddLine(string.format("Biological Sex: %s", anatStr), 1, 1, 1)
                        GameTooltip:AddLine(string.format("HP: %d/%d  |  ATK: %d  |  DEF: %d  |  SPD: %d",
                            mob.currentHP or mob.hp or 10, mob.maxHP or mob.hp or 10,
                            mob.attack or mob.atk or 10, mob.defense or mob.def or 10, mob.speed or mob.spd or 10), 0.2, 1, 0.4)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("|cff00ff00<Click to select, then click an Active Squad card to swap>|r", 0, 1, 0)
                        GameTooltip:Show()
                    end
                end
            end)
            tile:SetScript("OnLeave", function() GameTooltip:Hide() end)

            kennelTiles[idx] = tile
        end
    end

    -- =========================================================================
    -- ROW 4: BOTTOM BAR CONTROLS
    -- =========================================================================
    local withdrawBtn = CreateFrame("Button", "ForeverSafariKennelWithdrawBtn", frame, "UIPanelButtonTemplate")
    withdrawBtn:SetSize(150, 24)
    withdrawBtn:SetPoint("BOTTOMLEFT", rightX, 12)
    withdrawBtn:SetText("⬆ Move to Squad")
    withdrawBtn:SetScript("OnClick", function()
        if selectedKennelMobId then
            local ok, err = DB:MoveToSquad(selectedKennelMobId)
            if not ok and err then
                DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444" .. err .. "|r")
                PlaySound(847)
            else
                selectedKennelMobId = nil
                PlaySound(856)
                Kennel:UpdateUI()
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Select a banked companion first!|r")
        end
    end)

    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMRIGHT", -16, 16)
    statusText:SetText("Reserved: 0/400 companions")
    frame.StatusText = statusText
end

function Kennel:UpdateUI()
    if not frame or not frame:IsShown() then return end

    -- Close open menus
    if frame.JumpMenu and frame.JumpMenu:IsShown() then frame.JumpMenu:Hide() end
    if frame.TypeMenu and frame.TypeMenu:IsShown() then frame.TypeMenu:Hide() end
    if frame.SexMenu and frame.SexMenu:IsShown() then frame.SexMenu:Hide() end
    if frame.RarityMenu and frame.RarityMenu:IsShown() then frame.RarityMenu:Hide() end

    -- Update Switcher Bar (Current Box Name and Count)
    local curBoxName = DB and DB.GetBoxName and DB:GetBoxName(currentBox) or string.format("Enclosure %d", currentBox)
    local allBoxMobs = DB and DB.GetKennelMobs and DB:GetKennelMobs(currentBox) or {}
    local boxCount = #allBoxMobs
    local maxPerBox = C.SLOTS_PER_BOX or 20

    if frame.SwitcherBar and frame.SwitcherBar.BoxTitleText then
        frame.SwitcherBar.BoxTitleText:SetText(string.format("%d. |cffffd100%s|r (|cff00ff99%d/%d|r)", currentBox, curBoxName, boxCount, maxPerBox))
    end

    -- Update Active Squad (4 slots)
    local team = DB:GetTeam()
    for i = 1, 4 do
        local card = activeCards[i]
        local mobId = team[i]
        local mob = mobId and (type(mobId) == "table" and mobId or DB:GetMobById(mobId)) or nil

        if mob then
            card.mobId = mob.id
            local name = mob.nickname ~= "" and mob.nickname or mob.name
            card.NameText:SetText(string.format("|cffffffff%s|r", name))

            local rankData = SE:GetAttunementRank(mob.attunement or mob.attunementPoints or 0)
            local anat = mob.anatomy or "Sire"
            local anatBadge = (anat == "Dam" and "|cffff99cc♀ Dam|r") or (anat == "Genderless" and "|cffa0a0a0⚙|r") or "|cff66ccff♂ Sire|r"
            card.InfoText:SetText(string.format("%s • %s — |cff%sRank %s|r", mob.creatureType or "Beast", anatBadge, rankData.color or "ffffff", rankData.roman))

            local curHP = mob.currentHP or mob.hp or 10
            local maxHP = mob.maxHP or mob.hp or 10
            local pct = math.floor((curHP / math.max(1, maxHP)) * 100)
            card.HPBar:SetMinMaxValues(0, maxHP)
            card.HPBar:SetValue(curHP)
            if pct > 50 then
                card.HPBar:SetStatusBarColor(0.2, 0.8, 0.4)
            elseif pct > 20 then
                card.HPBar:SetStatusBarColor(0.9, 0.8, 0.2)
            else
                card.HPBar:SetStatusBarColor(0.9, 0.2, 0.2)
            end

            if card.Model then
                card.Model:Show()
                local displayId = mob.displayId or 903
                pcall(card.Model.SetDisplayInfo, card.Model, displayId)
            end

            card.DepositBtn:Show()
            card:SetBackdropBorderColor(0.3, 0.4, 0.5, 0.8)
        else
            card.mobId = nil
            card.NameText:SetText("|cff888888Empty Slot|r")
            card.InfoText:SetText("")
            card.HPBar:SetValue(0)
            if card.Model then card.Model:Hide() end
            card.DepositBtn:Hide()
            card:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.5)
        end
    end

    -- Update Enclosure 20 Tiles (Filtered Query)
    local displayedMobs = DB and DB.GetFilteredKennelMobs and DB:GetFilteredKennelMobs(currentBox, searchQuery, filterType, filterSex, filterRarity) or allBoxMobs
    for idx = 1, 20 do
        local tile = kennelTiles[idx]
        local mob = displayedMobs[idx]

        if mob then
            tile.mobId = mob.id
            local iconTex = mob.icon or "Interface\\Icons\\INV_Box_PetCarrier_01"
            tile.Icon:SetTexture(iconTex)
            tile.Icon:Show()

            -- Micro Sex Badge (Top-Right)
            local anat = mob.anatomy or "Sire"
            if anat == "Dam" then
                tile.SexBadge:SetText("|cffff99cc♀|r")
            elseif anat == "Genderless" then
                tile.SexBadge:SetText("|cffa0a0a0⚙|r")
            else
                tile.SexBadge:SetText("|cff66ccff♂|r")
            end
            tile.SexBadge:Show()

            -- Micro Apex Crown (Top-Left)
            if mob.isRare or mob.isElite then
                tile.CrownBadge:Show()
            else
                tile.CrownBadge:Hide()
            end

            local name = mob.nickname ~= "" and mob.nickname or mob.name
            if string.len(name) > 10 then
                name = string.sub(name, 1, 9) .. "…"
            end
            local rankData = SE:GetAttunementRank(mob.attunement or mob.attunementPoints or 0)
            tile.Label:SetText(string.format("|cff%s%s|r\n|cffaaaaaaRank %s|r", rankData.color or "ffffff", name, rankData.roman))

            if selectedKennelMobId == mob.id then
                tile.SelGlow:Show()
                tile:SetBackdropBorderColor(1, 0.82, 0, 1)
            else
                tile.SelGlow:Hide()
                tile:SetBackdropBorderColor(0.25, 0.35, 0.45, 0.8)
            end
        else
            tile.mobId = nil
            tile.Icon:Hide()
            tile.SexBadge:Hide()
            tile.CrownBadge:Hide()
            tile.Label:SetText("")
            tile.SelGlow:Hide()
            tile:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.5)
        end
    end

    local totalBanked = DB and DB.GetKennelMobs and #DB:GetKennelMobs() or 0
    local totalCapacity = (C.TOTAL_KENNEL_CAPACITY or 400)
    local filterNotice = (#displayedMobs ~= boxCount) and string.format("  |cffffcc00[Showing %d / %d]|r", #displayedMobs, boxCount) or ""
    frame.StatusText:SetText(string.format("Reserved: |cffffd100%d / %d companions|r across %d Enclosures%s",
        totalBanked, totalCapacity, (C.MAX_KENNEL_BOXES or 20), filterNotice))
end

function Kennel:ShowKennel()
    if not frame then Kennel:Initialize() end
    if frame then
        frame:Show()
        Kennel:UpdateUI()
        PlaySound(844)
    end
end

function Kennel:Hide()
    if frame and frame:IsShown() then
        frame:Hide()
        PlaySound(845)
    end
end

function Kennel:IsShown()
    return frame and frame:IsShown()
end

function Kennel:Toggle()
    if frame and frame:IsShown() then
        Kennel:Hide()
    else
        Kennel:ShowKennel()
    end
end

-- Close automatically when walking away from banker or closing interaction
local eventFrame = CreateFrame("Frame", "ForeverSafariKennelEventFrame")
eventFrame:RegisterEvent("GOSSIP_CLOSED")
if Enum and Enum.PlayerInteractionType then
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
end
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        local pit = Enum and Enum.PlayerInteractionType
        if pit and (interactionType == pit.Banker or interactionType == pit.CharacterBanker or interactionType == pit.AccountBanker) then
            Kennel:Hide()
        end
    elseif event == "GOSSIP_CLOSED" then
        -- Optional soft close if opened via gossip
    end
end)
