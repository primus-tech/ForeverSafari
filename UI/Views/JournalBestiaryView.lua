--[[
    Forever Safari: View 3 - Azeroth Bestiary (JournalBestiaryView.lua)
    Authentic Pokédex & Field Catalog with 215 curated Classic Azeroth species,
    9-element filter menu, search box, live 3D species stage with animations,
    Nesingwary field notes, native habitats, base stats, and natural family movepool.
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
local selectedBestiaryId = 1
local bestiaryButtons = {}

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

function Journal:BuildBestiaryView(parent)
    -- =========================================================================
    -- LEFT COLUMN: SPECIES INDEX & POKÉDEX PROGRESS
    -- =========================================================================
    local leftPanel = Theme:CreateCard(parent, 256, 480)
    leftPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    parent.LeftPanel = leftPanel

    local listTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    listTitle:SetPoint("TOPLEFT", 12, -10)
    listTitle:SetText("|cffffd100📖 Safari Field Pokédex|r")

    -- Pokédex Completion Badge & Counter
    local statsText = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -3)
    statsText:SetText("Discovered: 0/0 | Captured: 0/0")
    leftPanel.StatsText = statsText

    -- Progress Bar
    local pBar = CreateFrame("StatusBar", nil, leftPanel)
    pBar:SetSize(232, 8)
    pBar:SetPoint("TOPLEFT", statsText, "BOTTOMLEFT", 0, -4)
    pBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    pBar:SetStatusBarColor(1.0, 0.82, 0.0)
    pBar:SetMinMaxValues(0, 100)
    pBar:SetValue(0)
    leftPanel.ProgressBar = pBar

    -- Search EditBox
    local searchBg = CreateFrame("Frame", nil, leftPanel, "BackdropTemplate")
    searchBg:SetSize(232, 22)
    searchBg:SetPoint("TOPLEFT", pBar, "BOTTOMLEFT", 0, -6)
    Theme:ApplyCardBackdrop(searchBg)

    local searchBox = CreateFrame("EditBox", "ForeverSafariBestiarySearchBox", searchBg)
    searchBox:SetSize(216, 18)
    searchBox:SetPoint("LEFT", searchBg, "LEFT", 8, 0)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(0, 0, 0, 0)

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 0, 0)
    searchPlaceholder:SetText("🔍 Search species or habitat...")
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

    -- Type Filter Dropdown Button
    local typeFilterBtn = CreateFrame("Button", "ForeverSafariBestiaryTypeFilterBtn", leftPanel, "BackdropTemplate")
    typeFilterBtn:SetSize(232, 22)
    typeFilterBtn:SetPoint("TOPLEFT", searchBg, "BOTTOMLEFT", 0, -4)
    Theme:ApplyCardBackdrop(typeFilterBtn)

    local typeFilterText = typeFilterBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    typeFilterText:SetPoint("LEFT", 8, 0)
    typeFilterText:SetText("Type: |cffffd100All Types|r ▼")
    typeFilterBtn.Text = typeFilterText
    leftPanel.TypeFilterBtn = typeFilterBtn

    -- Type Filter Floating Popup Menu
    local typeMenu = CreateFrame("Frame", "ForeverSafariBestiaryTypeMenu", leftPanel, "BackdropTemplate")
    typeMenu:SetSize(232, #BESTIARY_TYPE_FILTERS * 22 + 8)
    typeMenu:SetPoint("TOPLEFT", typeFilterBtn, "BOTTOMLEFT", 0, -2)
    typeMenu:SetFrameStrata("DIALOG")
    Theme:ApplyCardBackdrop(typeMenu)
    typeMenu:SetBackdropColor(0.08, 0.11, 0.16, 0.98)
    typeMenu:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9)
    typeMenu:Hide()
    leftPanel.TypeMenu = typeMenu

    for idx, opt in ipairs(BESTIARY_TYPE_FILTERS) do
        local itemBtn = CreateFrame("Button", nil, typeMenu, "BackdropTemplate")
        itemBtn:SetSize(224, 20)
        itemBtn:SetPoint("TOPLEFT", typeMenu, "TOPLEFT", 4, -4 - ((idx - 1) * 22))

        local itemIcon = itemBtn:CreateTexture(nil, "ARTWORK")
        itemIcon:SetSize(16, 16)
        itemIcon:SetPoint("LEFT", 4, 0)
        itemIcon:SetTexture(opt.icon)
        itemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local itemText = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemText:SetPoint("LEFT", itemIcon, "RIGHT", 6, 0)
        itemText:SetText(opt.text)

        itemBtn:SetScript("OnClick", function()
            bestiarySelectedType = opt.id
            typeFilterText:SetText(string.format("Type: |cffffd100%s|r ▼", opt.text))
            typeMenu:Hide()
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
        if typeMenu:IsShown() then
            typeMenu:Hide()
        else
            typeMenu:Show()
        end
        PlaySound(856)
    end)

    -- Scroll Area
    local scroll = CreateFrame("ScrollFrame", "ForeverSafariBestiaryScroll", leftPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", typeFilterBtn, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 8)

    local content = CreateFrame("Frame", "ForeverSafariBestiaryContent", scroll)
    content:SetSize(210, 500)
    scroll:SetScrollChild(content)
    parent.Content = content

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
    adviceText:SetText("🔭 Stalk wild quarry in the field with /safari observe or engage in battle to record full research data.")
    rightPanel.AdviceText = adviceText
end

function Journal:UpdateBestiaryView()
    local parent = self.BestiaryContainer
    if not parent or not parent:IsShown() then return end

    local BestiaryDB = ForeverSafari.BestiaryDB
    local allSpecies = BestiaryDB and BestiaryDB:GetAllSpecies() or {}
    local content = parent.Content

    -- Filter list based on selected type and search query
    local filtered = {}
    for _, spec in ipairs(allSpecies) do
        local matchType = (bestiarySelectedType == "ALL") or (spec.element == bestiarySelectedType) or (spec.family == bestiarySelectedType)
        if matchType then
            if bestiarySearchQuery == "" then
                table.insert(filtered, spec)
            else
                local matchName = string.find(string.lower(spec.name), bestiarySearchQuery, 1, true)
                local matchFamily = string.find(string.lower(spec.family), bestiarySearchQuery, 1, true)
                local matchHabitat = false
                if spec.habitats then
                    for _, h in ipairs(spec.habitats) do
                        if string.find(string.lower(h), bestiarySearchQuery, 1, true) then
                            matchHabitat = true
                            break
                        end
                    end
                end
                if matchName or matchFamily or matchHabitat then
                    table.insert(filtered, spec)
                end
            end
        end
    end

    -- Update Pokédex Completion Counter
    local stats = DB:GetBestiaryStats()
    local leftPanel = parent.LeftPanel
    if leftPanel and leftPanel.StatsText then
        leftPanel.StatsText:SetText(string.format("Discovered: |cff00ff99%d/%d|r  |  Captured: |cffffd100%d/%d|r",
            stats.seen, stats.total, stats.caught, stats.total))
    end
    if leftPanel and leftPanel.ProgressBar then
        local pct = stats.total > 0 and ((stats.caught / stats.total) * 100) or 0
        leftPanel.ProgressBar:SetValue(pct)
    end

    -- Hide all existing buttons
    for _, btn in ipairs(bestiaryButtons) do
        btn:Hide()
    end

    local yOffset = 0
    for i, spec in ipairs(filtered) do
        local btn = bestiaryButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, content, "BackdropTemplate")
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
                selectedBestiaryId = self.specId
                Journal:UpdateBestiaryView()
                Journal:UpdateBestiaryDossier()
                PlaySound(856)
            end)

            bestiaryButtons[i] = btn
        end

        btn:SetPoint("TOPLEFT", content, "TOPLEFT", 2, yOffset)
        btn.specId = spec.id

        local entry = DB:GetBestiaryEntry(spec.id)
        local status = entry and entry.status or "unseen"

        if status == "caught" then
            local iconPath = "Interface\\Icons\\Ability_Hunter_BeastTaming"
            if spec.family == "Mechanical" or spec.element == "Mechanical" then iconPath = "Interface\\Icons\\INV_Misc_EngGizmos_17"
            elseif spec.family == "Undead" or spec.element == "Undead" then iconPath = "Interface\\Icons\\Spell_Shadow_DeadofNight"
            elseif spec.family == "Elemental" or spec.element == "Elemental" then iconPath = "Interface\\Icons\\Spell_Fire_Elemental_Totem"
            elseif spec.element == "Magic" then iconPath = "Interface\\Icons\\Spell_Holy_MagicalSentry"
            elseif spec.family == "Feline" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Cat"
            elseif spec.family == "Canine" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Wolf"
            elseif spec.family == "Bear" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Bear"
            elseif spec.family == "Boar" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Boar"
            elseif spec.family == "Raptor" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Raptor"
            elseif spec.family == "Avian" or spec.family == "Bat" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Bat"
            elseif spec.family == "Spider" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Spider"
            elseif spec.family == "Scorpid" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Scorpid"
            elseif spec.family == "Crocolisk" or spec.family == "Crab" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Crocolisk"
            elseif spec.family == "Dragonkin" or spec.family == "Wind Serpent" then iconPath = "Interface\\Icons\\INV_Misc_Head_Dragon_01"
            end
            btn.Icon:SetTexture(iconPath)
            btn.Icon:SetVertexColor(1, 1, 1)
            btn.Title:SetText(string.format("#%03d %s", spec.id, spec.name))
            local caughtCount = entry.caughtCount or 1
            btn.Sub:SetText(string.format("|cffffd100🐾 Caught (%dx)|r", caughtCount))

        elseif status == "seen" then
            btn.Icon:SetTexture("Interface\\Icons\\INV_Misc_Eye_02")
            btn.Icon:SetVertexColor(0.2, 0.8, 1.0)
            btn.Title:SetText(string.format("#%03d %s", spec.id, spec.name))
            btn.Sub:SetText("|cff33ccff🔭 Sighted in Field|r")

        else
            btn.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            btn.Icon:SetVertexColor(0.5, 0.5, 0.5)
            btn.Title:SetText(string.format("#%03d ???", spec.id))
            btn.Sub:SetText("|cff666666[Undiscovered]|r")
        end

        if spec.id == selectedBestiaryId then
            btn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
            btn:SetBackdropColor(0.18, 0.15, 0.08, 0.95)
        else
            btn:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
            btn:SetBackdropColor(Theme.Colors.CardBg.r, Theme.Colors.CardBg.g, Theme.Colors.CardBg.b, Theme.Colors.CardBg.a)
        end

        btn:Show()
        yOffset = yOffset - 46
    end

    content:SetHeight(math.max(450, math.abs(yOffset) + 10))
    self:UpdateBestiaryDossier()
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
        rPanel.NameText:SetText(string.format("|cff888888#%03d ??? (Undiscovered Quarry)|r", spec.id))
        rPanel.TypeText:SetText("|cff666666Family: Unknown | Element: Unknown|r")
        rPanel.StatusText:SetText("|cffff5555[Unobserved Wild Beast]|r")

        if rPanel.Model3D then
            rPanel.Model3D:ClearModel()
            rPanel.Model3D:Hide()
        end

        rPanel.HabitatText:SetText("|cff777777Known to inhabit unexplored regions of Azeroth.|r")
        rPanel.DescText:SetText("|cff777777No research data recorded. Stalk this species with /safari observe or engage it in combat to unlock its full dossier and movepool.|r")
        rPanel.DietText:SetText("|cff666666Favorite Sustenance: ???|r")
        rPanel.BaseStatsText:SetText("Base Stats: HP [ |cff666666??|r ] | ATK [ |cff666666??|r ] | DEF [ |cff666666??|r ] | SPD [ |cff666666??|r ]")
        rPanel.MovesList:SetText("|cff666666Movepool data classified until observed in the field.|r")

    else
        -- SEEN or CAUGHT
        local apexTag = spec.isApexRare and " |cffff3333[👑 Apex World Rare]|r" or ""
        if status == "caught" then
            rPanel.NameText:SetText(string.format("|cffffd100#%03d %s|r%s", spec.id, spec.name, apexTag))
            local cCount = entry.caughtCount or 1
            rPanel.StatusText:SetText(string.format("|cffffd100🐾 Captured (%dx)|r", cCount))
        else
            rPanel.NameText:SetText(string.format("|cff00ff99#%03d %s|r%s", spec.id, spec.name, apexTag))
            rPanel.StatusText:SetText("|cff33ccff🔭 Sighted & Logged|r")
        end

        rPanel.TypeText:SetText(string.format("Family: |cffffffff%s|r  |  Element: |cffffd100%s|r  |  Rarity: |cff00ff99%s|r",
            spec.family, spec.element, spec.rarity or "Common"))

        if rPanel.Model3D then
            rPanel.Model3D:Show()
            if self.SetModelCreature then
                self:SetModelCreature(rPanel.Model3D, spec.displayId)
            else
                rPanel.Model3D:SetDisplayInfo(spec.displayId)
            end
            if spec.modelScale and rPanel.Model3D.SetModelScale then
                rPanel.Model3D:SetModelScale(spec.modelScale)
            end
        end

        local habitatsStr = spec.habitats and table.concat(spec.habitats, ", ") or "Azeroth"
        rPanel.HabitatText:SetText(habitatsStr)
        rPanel.DescText:SetText(spec.description or "")
        rPanel.DietText:SetText(string.format("|cffffd100Favorite Sustenance:|r %s", spec.diet or "Fresh Meat (+25 Attunement)"))

        local bs = spec.baseStats or { hp = 60, atk = 15, def = 12, spd = 14 }
        rPanel.BaseStatsText:SetText(string.format("Base Stats: HP [ |cff33ff33%d|r ] | ATK [ |cffffaa00%d|r ] | DEF [ |cff3399ff%d|r ] | SPD [ |cff00ff99%d|r ]",
            bs.hp, bs.atk, bs.def, bs.spd))

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
