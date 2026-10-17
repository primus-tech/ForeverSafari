--[[
    Forever Safari: View 3 - Azeroth Bestiary (JournalBestiaryView.lua)
    Comprehensive Azeroth Master Pokédex & Field Catalog with 2,000+ species,
    multi-mode sorting, element type filters, 30 Beast subfamily filters,
    virtual scrolling (60 FPS), live 3D species stage with animations,
    Nesingwary field notes, native habitats, base stats radar, and natural moves.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.JournalFrame = ns.JournalFrame or {}

local Journal = ns.JournalFrame
local Theme = ns.Theme
local DB = ns.Database
local C = ns.Constants

local bestiarySearchQuery = ""
local bestiarySelectedType = "ALL"
local bestiarySelectedFamily = "ALL"
local bestiarySelectedStatus = "ALL"
local bestiaryCurrentZoneOnly = false
local bestiarySortMode = "ID_ASC"
local selectedBestiaryId = 1
local bestiaryButtons = {}
local filteredSpeciesList = {}

local ROW_HEIGHT = 44
local NUM_VISIBLE_ROWS = 7

local BESTIARY_TYPE_FILTERS = {
    { id = "ALL", text = "All Types", icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { id = "Beast", text = "🐾 Beast", icon = "Interface\\Icons\\Ability_Hunter_Pet_Cat" },
    { id = "Mechanical", text = "⚙️ Mechanical", icon = "Interface\\Icons\\INV_Misc_EngGizmos_17" },
    { id = "Undead", text = "💀 Undead", icon = "Interface\\Icons\\Spell_Shadow_DeadofNight" },
    { id = "Elemental", text = "🌋 Elemental", icon = "Interface\\Icons\\Spell_Fire_Elemental_Totem" },
    { id = "Dragonkin", text = "🐉 Dragonkin", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
    { id = "Aquatic", text = "🌊 Aquatic", icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental" },
    { id = "Flying", text = "🦅 Flying", icon = "Interface\\Icons\\Ability_Hunter_Pet_Bat" },
    { id = "Magic", text = "✨ Magic", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
}

local BEAST_FAMILIES = {
    { id = "ALL", name = "All Beast Families", icon = "Interface\\Icons\\Ability_Hunter_Pet_Cat" },
    { id = "Aquatic", name = "Aquatic", icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental" },
    { id = "Basilisk", name = "Basilisk", icon = "Interface\\Icons\\Ability_Hunter_Pet_Crocolisk" },
    { id = "Bat", name = "Bat", icon = "Interface\\Icons\\Ability_Hunter_Pet_Bat" },
    { id = "Bear", name = "Bear", icon = "Interface\\Icons\\Ability_Hunter_Pet_Bear" },
    { id = "Bird of Prey", name = "Bird of Prey", icon = "Interface\\Icons\\Ability_Hunter_Pet_Owl" },
    { id = "Boar", name = "Boar", icon = "Interface\\Icons\\Ability_Hunter_Pet_Boar" },
    { id = "Carrion Bird", name = "Carrion Bird", icon = "Interface\\Icons\\Ability_Hunter_Pet_Vulture" },
    { id = "Cat", name = "Cat", icon = "Interface\\Icons\\Ability_Hunter_Pet_Cat" },
    { id = "Chimaera", name = "Chimaera", icon = "Interface\\Icons\\Ability_Hunter_Pet_Chimera" },
    { id = "Core Hound", name = "Core Hound", icon = "Interface\\Icons\\Ability_Hunter_Pet_CoreHound" },
    { id = "Crab", name = "Crab", icon = "Interface\\Icons\\Ability_Hunter_Pet_Crab" },
    { id = "Crocolisk", name = "Crocolisk", icon = "Interface\\Icons\\Ability_Hunter_Pet_Crocolisk" },
    { id = "Devilsaur", name = "Devilsaur", icon = "Interface\\Icons\\Ability_Hunter_Pet_Devilsaur" },
    { id = "Dinosaur", name = "Dinosaur", icon = "Interface\\Icons\\Ability_Hunter_Pet_Raptor" },
    { id = "Gorilla", name = "Gorilla", icon = "Interface\\Icons\\Ability_Hunter_Pet_Gorilla" },
    { id = "Hydra", name = "Hydra", icon = "Interface\\Icons\\Ability_Hunter_Pet_Hydra" },
    { id = "Hyena", name = "Hyena", icon = "Interface\\Icons\\Ability_Hunter_Pet_Hyena" },
    { id = "Kodo", name = "Kodo", icon = "Interface\\Icons\\Ability_Mount_Kodo_01" },
    { id = "Raptor", name = "Raptor", icon = "Interface\\Icons\\Ability_Hunter_Pet_Raptor" },
    { id = "Scorpid", name = "Scorpid", icon = "Interface\\Icons\\Ability_Hunter_Pet_Scorpid" },
    { id = "Serpent", name = "Serpent", icon = "Interface\\Icons\\Spell_Nature_GuardianWard" },
    { id = "Silithid", name = "Silithid", icon = "Interface\\Icons\\Ability_Hunter_Pet_Silithid" },
    { id = "Spider", name = "Spider", icon = "Interface\\Icons\\Ability_Hunter_Pet_Spider" },
    { id = "Stag", name = "Stag", icon = "Interface\\Icons\\Ability_Hunter_Pet_Stag" },
    { id = "Tallstrider", name = "Tallstrider", icon = "Interface\\Icons\\Ability_Hunter_Pet_Tallstrider" },
    { id = "Thunder Lizard", name = "Thunder Lizard", icon = "Interface\\Icons\\Spell_Nature_Lightning" },
    { id = "Turtle", name = "Turtle", icon = "Interface\\Icons\\Ability_Hunter_Pet_Turtle" },
    { id = "Wind Serpent", name = "Wind Serpent", icon = "Interface\\Icons\\Ability_Hunter_Pet_WindSerpent" },
    { id = "Wolf", name = "Wolf", icon = "Interface\\Icons\\Ability_Hunter_Pet_Wolf" },
    { id = "Worm", name = "Worm", icon = "Interface\\Icons\\Ability_Hunter_Pet_Worm" },
}

local BESTIARY_SORT_OPTIONS = {
    { id = "ID_ASC", text = "🔢 Number (#0001 →)" },
    { id = "ID_DESC", text = "🔢 Number (High → Low)" },
    { id = "NAME_ASC", text = "🔤 Name (A → Z)" },
    { id = "NAME_DESC", text = "🔤 Name (Z → A)" },
    { id = "CAUGHT_FIRST", text = "🐾 Status (Caught First)" },
    { id = "SEEN_FIRST", text = "🔭 Status (Seen First)" },
    { id = "UNSEEN_FIRST", text = "❓ Status (Unseen First)" },
    { id = "FAMILY_ASC", text = "🏷 Family (A → Z)" },
    { id = "STATS_DESC", text = "💪 Base Stats Total" },
}

local function GetStatusWeight(status)
    if status == "caught" then return 1 end
    if status == "seen" then return 2 end
    return 3
end

local function GetTotalStats(spec)
    local bs = spec and spec.baseStats
    if not bs then return 0 end
    return (bs.hp or 0) + (bs.atk or 0) + (bs.def or 0) + (bs.spd or 0)
end

function Journal:BuildBestiaryView(parent)
    -- =========================================================================
    -- LEFT COLUMN: SPECIES INDEX & POKÉDEX CONTROLS
    -- =========================================================================
    local leftPanel = Theme:CreateCard(parent, 256, 480)
    leftPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    parent.LeftPanel = leftPanel

    local listTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    listTitle:SetPoint("TOPLEFT", 12, -8)
    listTitle:SetText("|cffffd100📖 Safari Field Pokédex|r")

    -- Pokédex Completion Badge & Counter
    local statsText = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -2)
    statsText:SetText("Discovered: 0/0 | Captured: 0/0")
    leftPanel.StatsText = statsText

    -- Progress Bar
    local pBar = CreateFrame("StatusBar", nil, leftPanel)
    pBar:SetSize(232, 6)
    pBar:SetPoint("TOPLEFT", statsText, "BOTTOMLEFT", 0, -3)
    pBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    pBar:SetStatusBarColor(1.0, 0.82, 0.0)
    pBar:SetMinMaxValues(0, 100)
    pBar:SetValue(0)
    leftPanel.ProgressBar = pBar

    -- Search EditBox
    local searchBg = CreateFrame("Frame", nil, leftPanel, "BackdropTemplate")
    searchBg:SetSize(232, 20)
    searchBg:SetPoint("TOPLEFT", pBar, "BOTTOMLEFT", 0, -5)
    Theme:ApplyCardBackdrop(searchBg)

    local searchBox = CreateFrame("EditBox", "ForeverSafariBestiarySearchBox", searchBg)
    searchBox:SetSize(216, 18)
    searchBox:SetPoint("LEFT", searchBg, "LEFT", 8, 0)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(0, 0, 0, 0)

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 0, 0)
    searchPlaceholder:SetText("🔍 Search species, habitat, #ID...")
    searchBox.Placeholder = searchPlaceholder

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        bestiarySearchQuery = string.lower(strtrim(text))
        if bestiarySearchQuery == "" then
            self.Placeholder:Show()
        else
            self.Placeholder:Hide()
        end
        Journal:UpdateBestiaryView()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    leftPanel.SearchBox = searchBox

    -- Filter & Sort Row (Side by Side)
    local typeFilterBtn = CreateFrame("Button", "ForeverSafariBestiaryTypeFilterBtn", leftPanel, "BackdropTemplate")
    typeFilterBtn:SetSize(114, 20)
    typeFilterBtn:SetPoint("TOPLEFT", searchBg, "BOTTOMLEFT", 0, -4)
    Theme:ApplyCardBackdrop(typeFilterBtn)

    local typeFilterText = typeFilterBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    typeFilterText:SetPoint("LEFT", 6, 0)
    typeFilterText:SetText("Type: |cffffd100All|r ▼")
    typeFilterBtn.Text = typeFilterText
    leftPanel.TypeFilterBtn = typeFilterBtn

    local sortBtn = CreateFrame("Button", "ForeverSafariBestiarySortBtn", leftPanel, "BackdropTemplate")
    sortBtn:SetSize(114, 20)
    sortBtn:SetPoint("LEFT", typeFilterBtn, "RIGHT", 4, 0)
    Theme:ApplyCardBackdrop(sortBtn)

    local sortText = sortBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sortText:SetPoint("LEFT", 6, 0)
    sortText:SetText("Sort: |cffffd100# Asc|r ▼")
    sortBtn.Text = sortText
    leftPanel.SortBtn = sortBtn

    -- Beast Family Sub-Filter Row
    local familyFilterBtn = CreateFrame("Button", "ForeverSafariBestiaryFamilyFilterBtn", leftPanel, "BackdropTemplate")
    familyFilterBtn:SetSize(232, 20)
    familyFilterBtn:SetPoint("TOPLEFT", typeFilterBtn, "BOTTOMLEFT", 0, -4)
    Theme:ApplyCardBackdrop(familyFilterBtn)

    local familyFilterText = familyFilterBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    familyFilterText:SetPoint("LEFT", 6, 0)
    familyFilterText:SetText("🐾 Beast Family: |cffffd100All Families|r ▼")
    familyFilterBtn.Text = familyFilterText
    leftPanel.FamilyFilterBtn = familyFilterBtn

    -- Current Zone Checkbox Row
    local zoneCheck = CreateFrame("CheckButton", "ForeverSafariBestiaryZoneCheck", leftPanel, "UICheckButtonTemplate")
    zoneCheck:SetSize(20, 20)
    zoneCheck:SetPoint("TOPLEFT", familyFilterBtn, "BOTTOMLEFT", 0, -3)
    zoneCheck:SetHitRectInsets(0, -210, 0, 0)

    local zoneLabel = zoneCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneLabel:SetPoint("LEFT", zoneCheck, "RIGHT", 4, 1)
    zoneLabel:SetText("📍 Current Zone Only")
    zoneCheck.Label = zoneLabel
    leftPanel.ZoneCheck = zoneCheck

    zoneCheck:SetScript("OnClick", function(self)
        bestiaryCurrentZoneOnly = self:GetChecked() and true or false
        Journal:UpdateBestiaryView()
        PlaySound(856)
    end)

    -- Status Quick-Filter Row ([All] [🐾] [🔭] [❓])
    local statusRow = CreateFrame("Frame", nil, leftPanel)
    statusRow:SetSize(232, 18)
    statusRow:SetPoint("TOPLEFT", zoneCheck, "BOTTOMLEFT", 0, -3)

    local statusBtns = {}
    local statusDefs = {
        { id = "ALL", text = "All", width = 52 },
        { id = "caught", text = "🐾 Caught", width = 60 },
        { id = "seen", text = "🔭 Seen", width = 58 },
        { id = "unseen", text = "❓ Unseen", width = 56 },
    }

    local prevBtn = nil
    for _, sDef in ipairs(statusDefs) do
        local sBtn = CreateFrame("Button", nil, statusRow, "BackdropTemplate")
        sBtn:SetSize(sDef.width, 18)
        if not prevBtn then
            sBtn:SetPoint("LEFT", statusRow, "LEFT", 0, 0)
        else
            sBtn:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
        end
        Theme:ApplyCardBackdrop(sBtn)

        local sLabel = sBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sLabel:SetPoint("CENTER", 0, 0)
        sLabel:SetText(sDef.text)
        sBtn.Label = sLabel

        sBtn:SetScript("OnClick", function()
            bestiarySelectedStatus = sDef.id
            for _, b in ipairs(statusBtns) do
                if b.statusId == bestiarySelectedStatus then
                    b:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                    b:SetBackdropColor(0.25, 0.2, 0.05, 0.95)
                else
                    b:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
                    b:SetBackdropColor(Theme.Colors.CardBg.r, Theme.Colors.CardBg.g, Theme.Colors.CardBg.b, Theme.Colors.CardBg.a)
                end
            end
            Journal:UpdateBestiaryView()
            PlaySound(856)
        end)

        sBtn.statusId = sDef.id
        table.insert(statusBtns, sBtn)
        prevBtn = sBtn
    end
    leftPanel.StatusBtns = statusBtns

    -- Type Filter Popup Menu
    local typeMenu = CreateFrame("Frame", "ForeverSafariBestiaryTypeMenu", leftPanel, "BackdropTemplate")
    typeMenu:SetSize(160, #BESTIARY_TYPE_FILTERS * 20 + 8)
    typeMenu:SetPoint("TOPLEFT", typeFilterBtn, "BOTTOMLEFT", 0, -2)
    typeMenu:SetFrameStrata("DIALOG")
    Theme:ApplyCardBackdrop(typeMenu)
    typeMenu:SetBackdropColor(0.08, 0.11, 0.16, 0.98)
    typeMenu:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9)
    typeMenu:Hide()
    leftPanel.TypeMenu = typeMenu

    for idx, opt in ipairs(BESTIARY_TYPE_FILTERS) do
        local itemBtn = CreateFrame("Button", nil, typeMenu, "BackdropTemplate")
        itemBtn:SetSize(152, 18)
        itemBtn:SetPoint("TOPLEFT", typeMenu, "TOPLEFT", 4, -4 - ((idx - 1) * 20))

        local itemText = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemText:SetPoint("LEFT", 6, 0)
        itemText:SetText(opt.text)

        itemBtn:SetScript("OnClick", function()
            bestiarySelectedType = opt.id
            typeFilterText:SetText(string.format("Type: |cffffd100%s|r ▼", opt.id == "ALL" and "All" or opt.id))
            typeMenu:Hide()

            if opt.id ~= "ALL" and opt.id ~= "Beast" then
                bestiarySelectedFamily = "ALL"
            end

            Journal:UpdateBestiaryView()
            PlaySound(856)
        end)
        itemBtn:SetScript("OnEnter", function(self)
            self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            self:SetBackdropColor(1.0, 0.82, 0.0, 0.25)
        end)
        itemBtn:SetScript("OnLeave", function(self)
            self:SetBackdrop(nil)
        end)
    end

    typeFilterBtn:SetScript("OnClick", function()
        if leftPanel.SortMenu:IsShown() then leftPanel.SortMenu:Hide() end
        if leftPanel.FamilyMenu:IsShown() then leftPanel.FamilyMenu:Hide() end
        if typeMenu:IsShown() then
            typeMenu:Hide()
        else
            typeMenu:Show()
        end
        PlaySound(856)
    end)

    -- Beast Family Sub-Filter Scrollable Popup Menu
    local familyMenu = CreateFrame("Frame", "ForeverSafariBestiaryFamilyMenu", leftPanel, "BackdropTemplate")
    familyMenu:SetSize(210, 240)
    familyMenu:SetPoint("TOPLEFT", familyFilterBtn, "BOTTOMLEFT", 0, -2)
    familyMenu:SetFrameStrata("DIALOG")
    Theme:ApplyCardBackdrop(familyMenu)
    familyMenu:SetBackdropColor(0.08, 0.11, 0.16, 0.98)
    familyMenu:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9)
    familyMenu:Hide()
    leftPanel.FamilyMenu = familyMenu

    local fScroll = CreateFrame("ScrollFrame", "ForeverSafariFamilyMenuScroll", familyMenu, "UIPanelScrollFrameTemplate")
    fScroll:SetPoint("TOPLEFT", familyMenu, "TOPLEFT", 4, -4)
    fScroll:SetPoint("BOTTOMRIGHT", familyMenu, "BOTTOMRIGHT", -22, 4)

    local fContent = CreateFrame("Frame", nil, fScroll)
    fContent:SetSize(180, (#BEAST_FAMILIES * 20) + 8)
    fScroll:SetScrollChild(fContent)

    for idx, fOpt in ipairs(BEAST_FAMILIES) do
        local fItemBtn = CreateFrame("Button", nil, fContent, "BackdropTemplate")
        fItemBtn:SetSize(176, 18)
        fItemBtn:SetPoint("TOPLEFT", fContent, "TOPLEFT", 2, -2 - ((idx - 1) * 20))

        local fIcon = fItemBtn:CreateTexture(nil, "ARTWORK")
        fIcon:SetSize(14, 14)
        fIcon:SetPoint("LEFT", 4, 0)
        fIcon:SetTexture(fOpt.icon)
        fIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local fItemText = fItemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fItemText:SetPoint("LEFT", fIcon, "RIGHT", 6, 0)
        fItemText:SetText(fOpt.name)

        fItemBtn:SetScript("OnClick", function()
            bestiarySelectedFamily = fOpt.id
            if bestiarySelectedFamily ~= "ALL" and bestiarySelectedType ~= "Beast" and bestiarySelectedType ~= "ALL" then
                bestiarySelectedType = "Beast"
                typeFilterText:SetText("Type: |cffffd100Beast|r ▼")
            end
            familyMenu:Hide()
            Journal:UpdateBestiaryView()
            PlaySound(856)
        end)
        fItemBtn:SetScript("OnEnter", function(self)
            self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            self:SetBackdropColor(1.0, 0.82, 0.0, 0.25)
        end)
        fItemBtn:SetScript("OnLeave", function(self)
            self:SetBackdrop(nil)
        end)
    end

    familyFilterBtn:SetScript("OnClick", function()
        if leftPanel.TypeMenu:IsShown() then leftPanel.TypeMenu:Hide() end
        if leftPanel.SortMenu:IsShown() then leftPanel.SortMenu:Hide() end
        if familyMenu:IsShown() then
            familyMenu:Hide()
        else
            familyMenu:Show()
        end
        PlaySound(856)
    end)

    -- Sort Popup Menu
    local sortMenu = CreateFrame("Frame", "ForeverSafariBestiarySortMenu", leftPanel, "BackdropTemplate")
    sortMenu:SetSize(180, #BESTIARY_SORT_OPTIONS * 20 + 8)
    sortMenu:SetPoint("TOPLEFT", sortBtn, "BOTTOMLEFT", -40, -2)
    sortMenu:SetFrameStrata("DIALOG")
    Theme:ApplyCardBackdrop(sortMenu)
    sortMenu:SetBackdropColor(0.08, 0.11, 0.16, 0.98)
    sortMenu:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9)
    sortMenu:Hide()
    leftPanel.SortMenu = sortMenu

    for idx, sOpt in ipairs(BESTIARY_SORT_OPTIONS) do
        local sItemBtn = CreateFrame("Button", nil, sortMenu, "BackdropTemplate")
        sItemBtn:SetSize(172, 18)
        sItemBtn:SetPoint("TOPLEFT", sortMenu, "TOPLEFT", 4, -4 - ((idx - 1) * 20))

        local sItemText = sItemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sItemText:SetPoint("LEFT", 6, 0)
        sItemText:SetText(sOpt.text)

        sItemBtn:SetScript("OnClick", function()
            bestiarySortMode = sOpt.id
            sortText:SetText(string.format("Sort: |cffffd100%s|r ▼", string.sub(sOpt.text, 1, 9)))
            sortMenu:Hide()
            Journal:UpdateBestiaryView()
            PlaySound(856)
        end)
        sItemBtn:SetScript("OnEnter", function(self)
            self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            self:SetBackdropColor(1.0, 0.82, 0.0, 0.25)
        end)
        sItemBtn:SetScript("OnLeave", function(self)
            self:SetBackdrop(nil)
        end)
    end

    sortBtn:SetScript("OnClick", function()
        if leftPanel.TypeMenu:IsShown() then leftPanel.TypeMenu:Hide() end
        if leftPanel.FamilyMenu:IsShown() then leftPanel.FamilyMenu:Hide() end
        if sortMenu:IsShown() then
            sortMenu:Hide()
        else
            sortMenu:Show()
        end
        PlaySound(856)
    end)

    -- Virtual Scroll Container
    local scroll = CreateFrame("ScrollFrame", "ForeverSafariBestiaryScroll", leftPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", statusRow, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 8)

    local content = CreateFrame("Frame", "ForeverSafariBestiaryContent", scroll)
    content:SetSize(210, 500)
    scroll:SetScrollChild(content)
    parent.Content = content
    parent.ScrollFrame = scroll

    -- Zone Change Event Listeners
    leftPanel:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    leftPanel:RegisterEvent("ZONE_CHANGED")
    leftPanel:RegisterEvent("ZONE_CHANGED_INDOORS")
    leftPanel:SetScript("OnEvent", function(self, event)
        if self:IsShown() then
            Journal:UpdateBestiaryView()
        end
    end)

    -- Virtual Scrolling Handlers
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        self:SetVerticalScroll(offset)
        Journal:RenderVisibleBestiaryRows(offset)
    end)

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local maxScroll = math.max(0, (#filteredSpeciesList - NUM_VISIBLE_ROWS) * ROW_HEIGHT)
        local newScroll = math.max(0, math.min(maxScroll, current - (delta * ROW_HEIGHT * 2)))
        self:SetVerticalScroll(newScroll)
        Journal:RenderVisibleBestiaryRows(newScroll)
    end)

    -- Create Fixed Visible Button Pool
    for i = 1, NUM_VISIBLE_ROWS + 1 do
        local btn = CreateFrame("Button", nil, content, "BackdropTemplate")
        btn:SetSize(210, 42)
        Theme:ApplyCardBackdrop(btn)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("LEFT", 6, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.Icon = icon

        local title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -2)
        title:SetPoint("TOPRIGHT", -4, -2)
        title:SetJustifyH("LEFT")
        btn.Title = title

        local sub = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
        sub:SetPoint("TOPRIGHT", -4, -2)
        sub:SetJustifyH("LEFT")
        btn.Sub = sub

        btn:SetScript("OnClick", function(self)
            if self.specId then
                selectedBestiaryId = self.specId
                Journal:RenderVisibleBestiaryRows(scroll:GetVerticalScroll() or 0)
                Journal:UpdateBestiaryDossier()
                PlaySound(856)
            end
        end)

        btn:Hide()
        bestiaryButtons[i] = btn
    end

    -- =========================================================================
    -- RIGHT COLUMN: 3D SPECIES DOSSIER
    -- =========================================================================
    local rightPanel = Theme:CreateCard(parent, 552, 480)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 8, 0)
    parent.RightPanel = rightPanel

    local bName = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    bName:SetPoint("TOPLEFT", 16, -14)
    bName:SetText("Species Name")
    bName:SetTextColor(1, 0.82, 0)
    rightPanel.NameText = bName

    local bType = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bType:SetPoint("TOPLEFT", bName, "BOTTOMLEFT", 0, -3)
    bType:SetText("Family: - | Element: -")
    rightPanel.TypeText = bType

    local bStatus = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bStatus:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -16, -14)
    bStatus:SetText("Status: [???]")
    rightPanel.StatusText = bStatus

    -- 3D Species Stage
    local bStage = Theme:CreateCard(rightPanel, 240, 240)
    bStage:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 16, -58)
    rightPanel.Stage = bStage

    local bPedestal = bStage:CreateTexture(nil, "BACKGROUND")
    bPedestal:SetSize(180, 42)
    bPedestal:SetPoint("CENTER", bStage, "CENTER", 0, -60)
    bPedestal:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bPedestal:SetVertexColor(0.12, 0.22, 0.18, 0.8)

    local bModel = CreateFrame("PlayerModel", "ForeverSafariBestiary3DModel", bStage)
    bModel:SetSize(220, 190)
    bModel:SetPoint("BOTTOM", bPedestal, "CENTER", 0, -5)
    if Journal.Setup3DModelInteractions then
        Journal:Setup3DModelInteractions(bModel)
    end
    rightPanel.Model3D = bModel

    -- Animation Action Buttons
    local animRow = CreateFrame("Frame", nil, bStage)
    animRow:SetSize(220, 22)
    animRow:SetPoint("BOTTOM", bStage, "BOTTOM", 0, 6)

    local atkBtn = Theme:CreateButton(animRow, "⚔ Attack", 68, 20)
    atkBtn:SetPoint("LEFT", animRow, "LEFT", 4, 0)
    atkBtn:SetScript("OnClick", function()
        if bModel and bModel:IsShown() then
            pcall(function() bModel:SetAnimation(16) end)
        end
    end)

    local roarBtn = Theme:CreateButton(animRow, "🦁 Roar", 68, 20)
    roarBtn:SetPoint("CENTER", animRow, "CENTER", 0, 0)
    roarBtn:SetScript("OnClick", function()
        if bModel and bModel:IsShown() then
            pcall(function() bModel:SetAnimation(26) end)
        end
    end)

    local idleBtn = Theme:CreateButton(animRow, "🐾 Idle", 68, 20)
    idleBtn:SetPoint("RIGHT", animRow, "RIGHT", -4, 0)
    idleBtn:SetScript("OnClick", function()
        if bModel and bModel:IsShown() then
            pcall(function() bModel:SetAnimation(0) end)
        end
    end)

    -- Species Details (Habitat, Base Stats, Nesingwary Lore)
    local detailsCard = Theme:CreateCard(rightPanel, 268, 240)
    detailsCard:SetPoint("TOPLEFT", bStage, "TOPRIGHT", 10, 0)
    rightPanel.DetailsCard = detailsCard

    local habitatTitle = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    habitatTitle:SetPoint("TOPLEFT", 10, -10)
    habitatTitle:SetText("|cffffd100Native Habitats:|r")

    local habitatText = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    habitatText:SetPoint("TOPLEFT", habitatTitle, "BOTTOMLEFT", 0, -3)
    habitatText:SetPoint("TOPRIGHT", -10, -3)
    habitatText:SetJustifyH("LEFT")
    rightPanel.HabitatText = habitatText

    local descTitle = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    descTitle:SetPoint("TOPLEFT", habitatText, "BOTTOMLEFT", 0, -6)
    descTitle:SetText("|cffffd100Nesingwary Field Notes:|r")

    local descText = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descText:SetPoint("TOPLEFT", descTitle, "BOTTOMLEFT", 0, -3)
    descText:SetPoint("TOPRIGHT", -10, -3)
    descText:SetJustifyH("LEFT")
    descText:SetTextColor(0.8, 0.85, 0.9)
    rightPanel.DescText = descText

    local dietText = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dietText:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -6)
    dietText:SetPoint("TOPRIGHT", -10, -6)
    dietText:SetJustifyH("LEFT")
    rightPanel.DietText = dietText

    local baseStatsText = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    baseStatsText:SetPoint("TOPLEFT", dietText, "BOTTOMLEFT", 0, -6)
    baseStatsText:SetText("Base Stats: HP [ -- ] | ATK [ -- ] | DEF [ -- ] | SPD [ -- ]")
    rightPanel.BaseStatsText = baseStatsText

    -- Lower Natural Move Pool Panel
    local lowerCard = Theme:CreateCard(rightPanel, 520, 150)
    lowerCard:SetPoint("TOPLEFT", bStage, "BOTTOMLEFT", 0, -10)
    rightPanel.LowerCard = lowerCard

    local movesTitle = lowerCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    movesTitle:SetPoint("TOPLEFT", 10, -8)
    movesTitle:SetText("|cff00ff99Natural Family Movepool & Tactics:|r")

    local movesList = lowerCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    movesList:SetPoint("TOPLEFT", movesTitle, "BOTTOMLEFT", 0, -4)
    movesList:SetPoint("TOPRIGHT", -10, -4)
    movesList:SetJustifyH("LEFT")
    rightPanel.MovesList = movesList

    local adviceText = lowerCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    adviceText:SetPoint("BOTTOMLEFT", 10, 8)
    adviceText:SetPoint("BOTTOMRIGHT", -10, 8)
    adviceText:SetJustifyH("LEFT")
    adviceText:SetText("🔭 Stalk wild quarry in the field with /fs observe or engage in battle to record full research data.")
    rightPanel.AdviceText = adviceText
end

function Journal:UpdateBestiaryView()
    local parent = self.BestiaryContainer
    if not parent or not parent:IsShown() then return end

    local BestiaryDB = ForeverSafari.BestiaryDB
    local allSpecies = BestiaryDB and BestiaryDB:GetAllSpecies() or {}

    -- Update Beast Family button state and text
    local leftPanel = parent.LeftPanel
    if leftPanel and leftPanel.FamilyFilterBtn then
        local fBtn = leftPanel.FamilyFilterBtn
        local fText = fBtn.Text
        if bestiarySelectedType ~= "ALL" and bestiarySelectedType ~= "Beast" then
            fBtn:Disable()
            fBtn:SetAlpha(0.4)
            fText:SetText("🐾 Family: |cff777777N/A (Beast Only)|r")
        else
            fBtn:Enable()
            fBtn:SetAlpha(1.0)
            if bestiarySelectedFamily == "ALL" then
                fText:SetText("🐾 Beast Family: |cffffd100All Families|r ▼")
            else
                fText:SetText(string.format("🐾 Family: |cffffd100%s|r ▼", bestiarySelectedFamily))
            end
        end
    end

    -- 1. Filter species by Search Query, Element Type, Beast Family, Current Zone, and Status
    wipe(filteredSpeciesList)

    local currentZone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
    if currentZone == "" or currentZone == "Azeroth" then
        currentZone = (GetZoneText and GetZoneText()) or ""
    end

    if leftPanel and leftPanel.ZoneCheck and leftPanel.ZoneCheck.Label then
        if currentZone ~= "" then
            leftPanel.ZoneCheck.Label:SetText(string.format("📍 Current Zone: |cff00ff99%s|r", currentZone))
        else
            leftPanel.ZoneCheck.Label:SetText("📍 Current Zone Only")
        end
    end

    for _, spec in ipairs(allSpecies) do
        local entry = DB:GetBestiaryEntry(spec.id)
        local status = entry and entry.status or "unseen"

        -- Status Filter
        local statusMatch = (bestiarySelectedStatus == "ALL") or (status == bestiarySelectedStatus)

        -- Type Filter
        local typeMatch = (bestiarySelectedType == "ALL") or (spec.element == bestiarySelectedType) or (spec.family == bestiarySelectedType)

        -- Beast Family Sub-Filter
        local familyMatch = true
        if bestiarySelectedFamily ~= "ALL" then
            familyMatch = (spec.subFamily == bestiarySelectedFamily) or (spec.family == bestiarySelectedFamily)
        end

        -- Current Zone Filter
        local zoneMatch = true
        if bestiaryCurrentZoneOnly and currentZone ~= "" then
            zoneMatch = false
            if spec.habitats then
                local lowerCur = string.lower(currentZone)
                for _, h in ipairs(spec.habitats) do
                    local lowerH = string.lower(h)
                    if lowerH == lowerCur or string.find(lowerCur, lowerH, 1, true) or string.find(lowerH, lowerCur, 1, true) then
                        zoneMatch = true
                        break
                    end
                end
            end
        end

        if statusMatch and typeMatch and familyMatch and zoneMatch then
            if bestiarySearchQuery == "" then
                table.insert(filteredSpeciesList, spec)
            else
                local matchName = string.find(string.lower(spec.name), bestiarySearchQuery, 1, true)
                local matchFamily = string.find(string.lower(spec.family or ""), bestiarySearchQuery, 1, true)
                local matchSubFamily = string.find(string.lower(spec.subFamily or ""), bestiarySearchQuery, 1, true)
                local matchId = string.find(string.format("#%04d", spec.id), bestiarySearchQuery, 1, true) or (tostring(spec.id) == bestiarySearchQuery)
                local matchHabitat = false
                if spec.habitats then
                    for _, h in ipairs(spec.habitats) do
                        if string.find(string.lower(h), bestiarySearchQuery, 1, true) then
                            matchHabitat = true
                            break
                        end
                    end
                end

                if matchName or matchFamily or matchSubFamily or matchId or matchHabitat then
                    table.insert(filteredSpeciesList, spec)
                end
            end
        end
    end

    -- 2. Sort filtered list based on selected sort mode
    table.sort(filteredSpeciesList, function(a, b)
        if bestiarySortMode == "ID_ASC" then
            return a.id < b.id
        elseif bestiarySortMode == "ID_DESC" then
            return a.id > b.id
        elseif bestiarySortMode == "NAME_ASC" then
            return a.name < b.name
        elseif bestiarySortMode == "NAME_DESC" then
            return a.name > b.name
        elseif bestiarySortMode == "CAUGHT_FIRST" then
            local stA = GetStatusWeight(DB:GetBestiaryEntry(a.id) and DB:GetBestiaryEntry(a.id).status or "unseen")
            local stB = GetStatusWeight(DB:GetBestiaryEntry(b.id) and DB:GetBestiaryEntry(b.id).status or "unseen")
            if stA ~= stB then return stA < stB end
            return a.id < b.id
        elseif bestiarySortMode == "SEEN_FIRST" then
            local entryA = DB:GetBestiaryEntry(a.id)
            local entryB = DB:GetBestiaryEntry(b.id)
            local stA = (entryA and entryA.status == "seen") and 1 or ((entryA and entryA.status == "caught") and 2 or 3)
            local stB = (entryB and entryB.status == "seen") and 1 or ((entryB and entryB.status == "caught") and 2 or 3)
            if stA ~= stB then return stA < stB end
            return a.id < b.id
        elseif bestiarySortMode == "UNSEEN_FIRST" then
            local stA = GetStatusWeight(DB:GetBestiaryEntry(a.id) and DB:GetBestiaryEntry(a.id).status or "unseen")
            local stB = GetStatusWeight(DB:GetBestiaryEntry(b.id) and DB:GetBestiaryEntry(b.id).status or "unseen")
            if stA ~= stB then return stA > stB end
            return a.id < b.id
        elseif bestiarySortMode == "FAMILY_ASC" then
            local famA = a.family or ""
            local famB = b.family or ""
            if famA ~= famB then return famA < famB end
            local subA = a.subFamily or ""
            local subB = b.subFamily or ""
            if subA ~= subB then return subA < subB end
            return a.name < b.name
        elseif bestiarySortMode == "STATS_DESC" then
            local totA = GetTotalStats(a)
            local totB = GetTotalStats(b)
            if totA ~= totB then return totA > totB end
            return a.name < b.name
        end
        return a.id < b.id
    end)

    -- 3. Update Pokédex Completion Stats
    local totalFiltered = #filteredSpeciesList
    local stats = DB:GetBestiaryStats()
    if leftPanel and leftPanel.StatsText then
        if bestiaryCurrentZoneOnly and currentZone ~= "" then
            local zSeen, zCaught = 0, 0
            for _, sp in ipairs(filteredSpeciesList) do
                local e = DB:GetBestiaryEntry(sp.id)
                if e then
                    if e.status == "caught" then
                        zCaught = zCaught + 1
                        zSeen = zSeen + 1
                    elseif e.status == "seen" then
                        zSeen = zSeen + 1
                    end
                end
            end
            leftPanel.StatsText:SetText(string.format("Zone Quarry: |cff00ff99%d Seen|r  |  |cffffd100%d/%d Caught|r",
                zSeen, zCaught, totalFiltered))
            if leftPanel.ProgressBar then
                local pct = totalFiltered > 0 and ((zCaught / totalFiltered) * 100) or 0
                leftPanel.ProgressBar:SetValue(pct)
            end
        else
            leftPanel.StatsText:SetText(string.format("Discovered: |cff00ff99%d/%d|r  |  Captured: |cffffd100%d/%d|r",
                stats.seen, stats.total, stats.caught, stats.total))
            if leftPanel.ProgressBar then
                local pct = stats.total > 0 and ((stats.caught / stats.total) * 100) or 0
                leftPanel.ProgressBar:SetValue(pct)
            end
        end
    end

    -- 4. Update Scroll Child Height and render visible rows
    parent.Content:SetHeight(math.max(308, totalFiltered * ROW_HEIGHT))

    local scroll = parent.ScrollFrame
    local currentScroll = scroll and scroll:GetVerticalScroll() or 0
    local maxScroll = math.max(0, (totalFiltered - NUM_VISIBLE_ROWS) * ROW_HEIGHT)
    if currentScroll > maxScroll then
        currentScroll = maxScroll
        if scroll then scroll:SetVerticalScroll(currentScroll) end
    end

    self:RenderVisibleBestiaryRows(currentScroll)
    self:UpdateBestiaryDossier()
end

function Journal:RenderVisibleBestiaryRows(scrollOffset)
    local parent = self.BestiaryContainer
    if not parent or not parent:IsShown() then return end
    local content = parent.Content
    if not content then return end

    local total = #filteredSpeciesList
    local startIndex = math.floor(scrollOffset / ROW_HEIGHT)
    if startIndex < 0 then startIndex = 0 end

    for i = 1, NUM_VISIBLE_ROWS + 1 do
        local btn = bestiaryButtons[i]
        local dataIndex = startIndex + i

        if dataIndex <= total then
            local spec = filteredSpeciesList[dataIndex]
            btn.specId = spec.id

            local yPos = -(dataIndex - 1) * ROW_HEIGHT
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", content, "TOPLEFT", 2, yPos)

            local entry = DB:GetBestiaryEntry(spec.id)
            local status = entry and entry.status or "unseen"

            if status == "caught" then
                local iconPath = "Interface\\Icons\\Ability_Hunter_BeastTaming"
                if spec.family == "Mechanical" or spec.element == "Mechanical" then iconPath = "Interface\\Icons\\INV_Misc_EngGizmos_17"
                elseif spec.family == "Undead" or spec.element == "Undead" then iconPath = "Interface\\Icons\\Spell_Shadow_DeadofNight"
                elseif spec.family == "Elemental" or spec.element == "Elemental" then iconPath = "Interface\\Icons\\Spell_Fire_Elemental_Totem"
                elseif spec.element == "Magic" then iconPath = "Interface\\Icons\\Spell_Holy_MagicalSentry"
                elseif spec.subFamily == "Cat" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Cat"
                elseif spec.subFamily == "Wolf" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Wolf"
                elseif spec.subFamily == "Bear" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Bear"
                elseif spec.subFamily == "Boar" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Boar"
                elseif spec.subFamily == "Raptor" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Raptor"
                elseif spec.subFamily == "Bat" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Bat"
                elseif spec.subFamily == "Bird of Prey" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Owl"
                elseif spec.subFamily == "Spider" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Spider"
                elseif spec.subFamily == "Scorpid" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Scorpid"
                elseif spec.subFamily == "Crocolisk" or spec.subFamily == "Crab" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Crocolisk"
                elseif spec.family == "Dragonkin" or spec.subFamily == "Wind Serpent" then iconPath = "Interface\\Icons\\INV_Misc_Head_Dragon_01"
                elseif spec.subFamily == "Thunder Lizard" then iconPath = "Interface\\Icons\\Spell_Nature_Lightning"
                end

                btn.Icon:SetTexture(iconPath)
                btn.Icon:SetVertexColor(1, 1, 1)
                btn.Title:SetText(string.format("#%04d %s", spec.id, spec.name))
                local caughtCount = entry.caughtCount or 1
                btn.Sub:SetText(string.format("|cffffd100🐾 Caught (%dx)|r", caughtCount))

            elseif status == "seen" then
                btn.Icon:SetTexture("Interface\\Icons\\INV_Misc_Eye_02")
                btn.Icon:SetVertexColor(0.2, 0.8, 1.0)
                btn.Title:SetText(string.format("#%04d %s", spec.id, spec.name))
                btn.Sub:SetText("|cff33ccff🔭 Sighted|r")

            else
                btn.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                btn.Icon:SetVertexColor(0.5, 0.5, 0.5)
                btn.Title:SetText(string.format("#%04d %s", spec.id, spec.name))
                btn.Sub:SetText("|cff888888[Unobserved Quarry]|r")
            end

            if spec.id == selectedBestiaryId then
                btn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                btn:SetBackdropColor(0.18, 0.15, 0.08, 0.95)
            else
                btn:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
                btn:SetBackdropColor(Theme.Colors.CardBg.r, Theme.Colors.CardBg.g, Theme.Colors.CardBg.b, Theme.Colors.CardBg.a)
            end

            btn:Show()
        else
            btn:Hide()
        end
    end
end

function Journal:UpdateBestiaryDossier()
    local parent = self.BestiaryContainer
    if not parent then return end
    local rPanel = parent.RightPanel

    local BestiaryDB = ForeverSafari.BestiaryDB
    local spec = (BestiaryDB and BestiaryDB:GetSpecies(selectedBestiaryId)) or (BestiaryDB and BestiaryDB:GetAllSpecies()[1])
    if not spec then return end

    local entry = DB:GetBestiaryEntry(spec.id)
    local status = entry and entry.status or "unseen"

    if status == "unseen" then
        local apexTag = spec.isApexRare and " |cffff3333[👑 Apex World Rare]|r" or (spec.isBoss and " |cffff1111[💀 World Boss]|r" or "")
        rPanel.NameText:SetText(string.format("|cffaaaaaa#%04d %s|r%s", spec.id, spec.name, apexTag))
        rPanel.TypeText:SetText(string.format("Family: |cff888888%s (%s)|r  |  Element: |cff888888%s|r  |  Rarity: |cff888888%s|r",
            spec.family or "Beast", spec.subFamily or spec.family or "Beast", spec.element or "Physical", spec.rarity or "Common"))
        rPanel.StatusText:SetText("|cffff5555[Unobserved Wild Beast]|r")

        if rPanel.Model3D then
            rPanel.Model3D:ClearModel()
            rPanel.Model3D:Hide()
        end

        local habitatsStr = spec.habitats and table.concat(spec.habitats, ", ") or "Wilds of Azeroth"
        rPanel.HabitatText:SetText(string.format("|cff888888Known Regions: %s|r", habitatsStr))
        rPanel.DescText:SetText("|cff777777No field research recorded. Stalk this species with /fs observe or engage it in combat to unlock its full 3D model, stats, and technique roster.|r")
        rPanel.DietText:SetText("|cff666666Favorite Sustenance: ???|r")
        rPanel.BaseStatsText:SetText("Base Stats: HP [ |cff666666??|r ] | ATK [ |cff666666??|r ] | DEF [ |cff666666??|r ] | SPD [ |cff666666??|r ]  |  Total: |cff666666???|r")
        rPanel.MovesList:SetText("|cff666666Movepool data classified until observed in the field.|r")

    else
        -- SEEN or CAUGHT
        local apexTag = spec.isApexRare and " |cffff3333[👑 Apex World Rare]|r" or (spec.isBoss and " |cffff1111[💀 World Boss]|r" or "")
        if status == "caught" then
            rPanel.NameText:SetText(string.format("|cffffd100#%04d %s|r%s", spec.id, spec.name, apexTag))
            local cCount = entry.caughtCount or 1
            rPanel.StatusText:SetText(string.format("|cffffd100🐾 Captured (%dx)|r", cCount))
        else
            rPanel.NameText:SetText(string.format("|cff00ff99#%04d %s|r%s", spec.id, spec.name, apexTag))
            rPanel.StatusText:SetText("|cff33ccff🔭 Sighted & Logged|r")
        end

        rPanel.TypeText:SetText(string.format("Family: |cffffffff%s (%s)|r  |  Element: |cffffd100%s|r  |  Rarity: |cff00ff99%s|r",
            spec.family, spec.subFamily or spec.family, spec.element, spec.rarity or "Common"))

        if rPanel.Model3D then
            rPanel.Model3D:Show()
            if self.SetModelCreature then
                self:SetModelCreature(rPanel.Model3D, spec.displayId, spec.primaryNpcId)
            else
                rPanel.Model3D:SetDisplayInfo(spec.displayId)
            end
            if spec.modelScale and rPanel.Model3D.SetModelScale then
                rPanel.Model3D:SetModelScale(spec.modelScale)
            end
        end

        local habitatsStr = spec.habitats and table.concat(spec.habitats, ", ") or "Wilds of Azeroth"
        rPanel.HabitatText:SetText(habitatsStr)
        rPanel.DescText:SetText(spec.description or "")
        rPanel.DietText:SetText(string.format("|cffffd100Favorite Sustenance:|r %s", spec.diet or "Fresh Meat (+25 Attunement)"))

        local bs = spec.baseStats or { hp = 60, atk = 15, def = 12, spd = 14 }
        rPanel.BaseStatsText:SetText(string.format("Base Stats: HP [ |cff33ff33%d|r ] | ATK [ |cffffaa00%d|r ] | DEF [ |cff3399ff%d|r ] | SPD [ |cff00ff99%d|r ]  |  Total: |cffffd100%d|r",
            bs.hp or 0, bs.atk or 0, bs.def or 0, bs.spd or 0, (bs.hp or 0) + (bs.atk or 0) + (bs.def or 0) + (bs.spd or 0)))

        local movesStr = ""
        if spec.movepool then
            for _, moveId in ipairs(spec.movepool) do
                local m = ns.MoveDB and (ns.MoveDB[moveId] or (tonumber(moveId) and ns.MoveDB[tonumber(moveId)]))
                if m then
                    local cdText = (m.cooldown and m.cooldown > 0) and string.format(" (%dt CD)", m.cooldown) or " (Instant)"
                    local pwrText = (m.power and m.power > 0) and string.format(" [Pwr %d]", m.power) or ""
                    movesStr = movesStr .. string.format("• |cffffffff%s|r%s%s  ", m.name, pwrText, cdText)
                end
            end
        end
        rPanel.MovesList:SetText(movesStr ~= "" and movesStr or "Tackle")
    end
end
