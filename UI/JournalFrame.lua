--[[
    Forever Safari: Field Guide Journal & 3D Paperdoll Showcase
    Features interactive 3D Paperdoll browsing with 360° rotation controls,
    multi-view modes (3D Showcase Stage, 3D Gallery Grid, Azeroth Bestiary),
    flanking carousel 3D models, 4 core stats (HP, ATK, DEF, SPD),
    and the Vanilla WoW style Beast Training Grimoire.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.JournalFrame = ns.JournalFrame or {}

local Journal = ns.JournalFrame
local C = ns.Constants
local DB = ns.Database
local SE = ns.StatEngine
local Theme = ns.Theme

local frame = nil
local currentTab = "SHOWCASE" -- "SHOWCASE", "GRID", "BESTIARY"
local selectedMobId = nil
local selectedBestiaryId = 1
local gridPage = 1
local gridTypeFilter = "ALL"
local trainingSlotIndex = 1

local listButtons = {}
local gridCards = {}
local bestiaryButtons = {}
local trainerButtons = {}

-- Static Confirmation Dialog for Releasing / Abandoning a Companion
StaticPopupDialogs["FOREVERSAFARI_CONFIRM_ABANDON"] = {
    text = "Are you sure you want to abandon %s and release it back into the wild?\n\n|cffff4444This action cannot be undone.|r",
    button1 = "Release to Wild",
    button2 = "Cancel",
    OnAccept = function(self, data)
        local mobId = (data and data.mobId) or selectedMobId
        if mobId then
            DB:AbandonMob(mobId)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function Journal:SelectMob(mobId)
    selectedMobId = mobId
    if frame and frame:IsShown() then
        Journal:UpdateUI()
    end
end

-- Helper to safely load display IDs onto a PlayerModel frame
local function SetModelCreature(modelFrame, displayId)
    if not modelFrame or not displayId or displayId <= 0 then return end
    if modelFrame.ClearModel then modelFrame:ClearModel() end
    if modelFrame.SetDisplayInfo then
        modelFrame:SetDisplayInfo(displayId)
    elseif modelFrame.SetCreatureByDisplayID then
        modelFrame:SetCreatureByDisplayID(displayId)
    end
    if modelFrame.SetPortraitZoom then
        modelFrame:SetPortraitZoom(0)
    end
    if modelFrame.SetCamDistanceScale then
        modelFrame:SetCamDistanceScale(1.0)
    end
    if modelFrame.SetModelScale then
        modelFrame:SetModelScale(modelFrame.zoom or 1.0)
    end
    if modelFrame.SetRotation then
        modelFrame:SetRotation(modelFrame.rotation or math.rad(25))
    end
    if modelFrame.SetAnimation then
        modelFrame:SetAnimation(0)
    end
end

-- Helper to make any PlayerModel frame smoothly rotatable with left-drag and zoomable with mouse wheel
local function Setup3DModelInteractions(modelFrame)
    if not modelFrame then return end
    modelFrame:EnableMouse(true)
    modelFrame:EnableMouseWheel(true)
    modelFrame.rotation = modelFrame.rotation or math.rad(25)
    modelFrame.zoom = modelFrame.zoom or 1.0

    modelFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isRotating = true
            self.prevX, _ = GetCursorPosition()
        elseif button == "RightButton" then
            -- Trigger attack animation on right click
            self:SetAnimation(4)
            PlaySound(847)
            C_Timer.After(0.8, function()
                if self:IsShown() then self:SetAnimation(0) end
            end)
        end
    end)

    modelFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.isRotating = false
        end
    end)

    modelFrame:SetScript("OnUpdate", function(self)
        if self.isRotating then
            local curX, _ = GetCursorPosition()
            local diff = (curX - (self.prevX or curX)) * 0.02
            self.rotation = (self.rotation or 0) + diff
            self:SetRotation(self.rotation)
            self.prevX = curX
        end
    end)

    modelFrame:SetScript("OnMouseWheel", function(self, delta)
        self.zoom = math.max(0.5, math.min(2.5, (self.zoom or 1.0) + (delta * 0.1)))
        if self.SetModelScale then
            self:SetModelScale(self.zoom)
        elseif self.SetPortraitZoom then
            self:SetPortraitZoom(self.zoom)
        end
    end)
end

function Journal:Initialize()
    frame = CreateFrame("Frame", "ForeverSafariJournalFrame", UIParent, "BackdropTemplate")
    frame:SetSize(840, 620)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 15)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")

    Theme:ApplyFrameBackdrop(frame, true)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    Theme:CreateCloseButton(frame)
    frame.Header = Theme:CreateHeader(frame, "Forever Safari - Field Guide", "Interface\\Icons\\INV_Box_01")

    -- Top Navigation Tab Buttons (View Modes)
    -- Top Navigation Tab Buttons (View Modes)
    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetSize(540, 28)
    tabContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -38)
    frame.TabContainer = tabContainer

    local tabs = {
        { id = "SHOWCASE", text = "3D Showcase" },
        { id = "GRID",     text = "3D Gallery" },
        { id = "BESTIARY", text = "Azeroth Bestiary" },
        { id = "BOUNTIES", text = "Field Directives" },
    }

    frame.TabButtons = {}
    for i, tabInfo in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, tabContainer, "BackdropTemplate")
        btn:SetSize(126, 24)
        btn:SetPoint("LEFT", tabContainer, "LEFT", (i - 1) * 130, 0)
        btn.tabId = tabInfo.id

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
        })

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnText:SetPoint("CENTER", 0, 0)
        btnText:SetText(tabInfo.text)
        btn.Text = btnText

        btn:SetScript("OnClick", function(self)
            Journal:SetTab(self.tabId)
            PlaySound(856)
        end)

        frame.TabButtons[tabInfo.id] = btn
    end

    -- Top Right Quick Access Buttons (Safari Bag & Field Directives shortcut)
    local bagBtn = CreateFrame("Button", "ForeverSafariJournalBagBtn", frame, "BackdropTemplate")
    bagBtn:SetSize(110, 24)
    bagBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -134, -38)
    bagBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    bagBtn:SetBackdropColor(0.12, 0.16, 0.22, 0.9)
    bagBtn:SetBackdropBorderColor(1.0, 0.82, 0, 0.8)

    local bagIcon = bagBtn:CreateTexture(nil, "ARTWORK")
    bagIcon:SetSize(16, 16)
    bagIcon:SetPoint("LEFT", bagBtn, "LEFT", 6, 0)
    bagIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
    bagIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local bagText = bagBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bagText:SetPoint("LEFT", bagIcon, "RIGHT", 4, 0)
    bagText:SetText("|cffffd100Safari Bag|r")

    bagBtn:SetScript("OnClick", function()
        if ForeverSafari.SafariBagFrame then ForeverSafari.SafariBagFrame:Toggle() end
    end)
    bagBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffffd100Virtual Safari Bag|r", 1, 1, 1)
        GameTooltip:AddLine("Open your 20-slot container for safari nets, family diets, catalysts, and balms.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    bagBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.BagBtn = bagBtn

    local bountiesBtn = CreateFrame("Button", "ForeverSafariJournalBountiesBtn", frame, "BackdropTemplate")
    bountiesBtn:SetSize(114, 24)
    bountiesBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -38)
    bountiesBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    bountiesBtn:SetBackdropColor(0.12, 0.16, 0.22, 0.9)
    bountiesBtn:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.8)

    local bIcon = bountiesBtn:CreateTexture(nil, "ARTWORK")
    bIcon:SetSize(16, 16)
    bIcon:SetPoint("LEFT", bountiesBtn, "LEFT", 6, 0)
    bIcon:SetTexture("Interface\\Icons\\INV_Letter_15")
    bIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local bText = bountiesBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bText:SetPoint("LEFT", bIcon, "RIGHT", 4, 0)
    bText:SetText("|cffffd100Directives|r")

    bountiesBtn:SetScript("OnClick", function()
        Journal:SetTab("BOUNTIES")
    end)
    bountiesBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffffd100Field Directives & Bounties|r", 1, 1, 1)
        GameTooltip:AddLine("Track your active Nesingwary research directives and hunt objectives in the field.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    bountiesBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.BountiesBtn = bountiesBtn

    -- View 1: 3D Showcase Stage Container
    local showcaseContainer = CreateFrame("Frame", "ForeverSafariShowcaseContainer", frame)
    showcaseContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
    showcaseContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 60)
    frame.ShowcaseContainer = showcaseContainer

    Journal:BuildShowcaseView(showcaseContainer)

    -- View 2: 3D Paperdoll Gallery Grid Container
    local gridContainer = CreateFrame("Frame", "ForeverSafariGridContainer", frame)
    gridContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
    gridContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 60)
    frame.GridContainer = gridContainer

    Journal:BuildGridView(gridContainer)

    -- View 3: Azeroth Bestiary Container
    local bestiaryContainer = CreateFrame("Frame", "ForeverSafariBestiaryContainer", frame)
    bestiaryContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
    bestiaryContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 60)
    frame.BestiaryContainer = bestiaryContainer

    Journal:BuildBestiaryView(bestiaryContainer)

    -- View 4: Field Directives & Quest Log Container
    local bountiesContainer = CreateFrame("Frame", "ForeverSafariBountiesContainer", frame)
    bountiesContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
    bountiesContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 60)
    frame.BountiesContainer = bountiesContainer

    Journal:BuildBountiesView(bountiesContainer)

    -- Bottom Team Roster Dock with 3D Mini-Paperdolls
    Journal:BuildTeamDock(frame)

    -- Training Grimoire Drawer (Popout)
    Journal:BuildTrainingDrawer(frame)

    Journal:SetTab("SHOWCASE")
    frame:Hide()
end

function Journal:SetTab(tabId)
    currentTab = tabId

    for id, btn in pairs(frame.TabButtons) do
        if id == tabId then
            btn:SetBackdropColor(0.0, 0.45, 0.35, 0.95)
            btn:SetBackdropBorderColor(0.0, 1.0, 0.6, 1.0)
            btn.Text:SetTextColor(1, 1, 1)
        else
            btn:SetBackdropColor(0.1, 0.13, 0.18, 0.8)
            btn:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.6)
            btn.Text:SetTextColor(0.7, 0.75, 0.8)
        end
    end

    frame.ShowcaseContainer:SetShown(tabId == "SHOWCASE")
    frame.GridContainer:SetShown(tabId == "GRID")
    frame.BestiaryContainer:SetShown(tabId == "BESTIARY")
    frame.BountiesContainer:SetShown(tabId == "BOUNTIES")

    Journal:UpdateUI()
end

function Journal:ShowTab(tabId)
    if not frame then Journal:Initialize() end
    frame:Show()
    Journal:SetTab(tabId or "SHOWCASE")
end

-- =========================================================================
-- VIEW 1: 3D SHOWCASE STAGE (CAROUSEL & DOSSIER)
-- =========================================================================
function Journal:BuildShowcaseView(parent)
    -- Left Column: 3D Paperdoll Collection List
    local leftPanel = Theme:CreateCard(parent, 220, 480)
    leftPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    parent.LeftPanel = leftPanel

    local searchBox = CreateFrame("EditBox", "ForeverSafariSearchBox", leftPanel, "InputBoxTemplate")
    searchBox:SetSize(190, 20)
    searchBox:SetPoint("TOPLEFT", 14, -10)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("")
    searchBox:SetScript("OnTextChanged", function() Journal:UpdateList() end)
    parent.SearchBox = searchBox

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 5, 0)
    searchPlaceholder:SetText("Search Companions...")
    searchBox:SetScript("OnEditFocusGained", function() searchPlaceholder:Hide() end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then searchPlaceholder:Show() end
    end)

    local scrollFrame = CreateFrame("ScrollFrame", "ForeverSafariListScrollFrame", leftPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 6, -38)
    scrollFrame:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -26, 8)

    local listContent = CreateFrame("Frame", "ForeverSafariListContent", scrollFrame)
    listContent:SetSize(180, 440)
    scrollFrame:SetScrollChild(listContent)
    parent.ListContent = listContent

    -- Center Column: 3D Carousel Stage
    local centerStage = Theme:CreateCard(parent, 280, 480)
    centerStage:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 8, 0)
    parent.CenterStage = centerStage

    -- Carousel Title Header
    local stageTitle = centerStage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stageTitle:SetPoint("TOP", centerStage, "TOP", 0, -10)
    stageTitle:SetText("|cff00ff993D Paperdoll Showcase|r")
    centerStage.Title = stageTitle

    local stageCounter = centerStage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stageCounter:SetPoint("TOP", stageTitle, "BOTTOM", 0, -2)
    stageCounter:SetText("Mob 1 of 1")
    stageCounter:SetTextColor(0.7, 0.75, 0.8)
    centerStage.Counter = stageCounter

    -- Main Center 3D Pedestal
    local pedestal = centerStage:CreateTexture(nil, "BACKGROUND")
    pedestal:SetSize(210, 52)
    pedestal:SetPoint("CENTER", centerStage, "CENTER", 0, -40)
    pedestal:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    pedestal:SetVertexColor(0.10, 0.28, 0.22, 0.85)
    centerStage.Pedestal = pedestal

    -- Flanking Left Pedestal (Previous ForeverSafari)
    local leftPedestal = centerStage:CreateTexture(nil, "BACKGROUND")
    leftPedestal:SetSize(80, 24)
    leftPedestal:SetPoint("CENTER", pedestal, "LEFT", -20, 25)
    leftPedestal:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    leftPedestal:SetVertexColor(0.08, 0.16, 0.20, 0.6)

    local leftModel = CreateFrame("PlayerModel", "ForeverSafariLeftModel", centerStage)
    leftModel:SetSize(85, 95)
    leftModel:SetPoint("BOTTOM", leftPedestal, "CENTER", 0, -5)
    leftModel:SetRotation(math.rad(45))
    leftModel:EnableMouse(true)
    leftModel:SetAlpha(0.55)
    leftModel:SetScript("OnMouseDown", function()
        Journal:CycleSelectedMob(-1)
    end)
    centerStage.LeftModel = leftModel

    -- Flanking Right Pedestal (Next ForeverSafari)
    local rightPedestal = centerStage:CreateTexture(nil, "BACKGROUND")
    rightPedestal:SetSize(80, 24)
    rightPedestal:SetPoint("CENTER", pedestal, "RIGHT", 20, 25)
    rightPedestal:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    rightPedestal:SetVertexColor(0.08, 0.16, 0.20, 0.6)

    local rightModel = CreateFrame("PlayerModel", "ForeverSafariRightModel", centerStage)
    rightModel:SetSize(85, 95)
    rightModel:SetPoint("BOTTOM", rightPedestal, "CENTER", 0, -5)
    rightModel:SetRotation(math.rad(-45))
    rightModel:EnableMouse(true)
    rightModel:SetAlpha(0.55)
    rightModel:SetScript("OnMouseDown", function()
        Journal:CycleSelectedMob(1)
    end)
    centerStage.RightModel = rightModel

    -- Primary 3D Center Paperdoll Model
    local mainModel = CreateFrame("PlayerModel", "ForeverSafariMain3DModel", centerStage)
    mainModel:SetSize(240, 260)
    mainModel:SetPoint("BOTTOM", pedestal, "CENTER", 0, -18)
    Setup3DModelInteractions(mainModel)
    centerStage.MainModel = mainModel

    -- Navigation Buttons (< PREV and NEXT >)
    local prevBtn = Theme:CreateButton(centerStage, "< PREV", 65, 24)
    prevBtn:SetPoint("BOTTOMLEFT", centerStage, "BOTTOMLEFT", 12, 10)
    prevBtn:SetScript("OnClick", function() Journal:CycleSelectedMob(-1) end)

    local nextBtn = Theme:CreateButton(centerStage, "NEXT >", 65, 24)
    nextBtn:SetPoint("BOTTOMRIGHT", centerStage, "BOTTOMRIGHT", -12, 10)
    nextBtn:SetScript("OnClick", function() Journal:CycleSelectedMob(1) end)

    -- 3D Animation Controls Bar
    local animBar = CreateFrame("Frame", nil, centerStage)
    animBar:SetSize(256, 26)
    animBar:SetPoint("BOTTOM", centerStage, "BOTTOM", 0, 40)

    local animLabels = {
        { name = "Attack", anim = 4, sound = 847 },
        { name = "Roar",   anim = 5, sound = 856 },
        { name = "Victory",anim = 3, sound = 844 },
        { name = "Idle",   anim = 0, sound = nil },
    }

    for i, aInfo in ipairs(animLabels) do
        local aBtn = CreateFrame("Button", nil, animBar, "UIPanelButtonTemplate")
        aBtn:SetSize(58, 20)
        aBtn:SetPoint("LEFT", animBar, "LEFT", (i - 1) * 64, 0)
        aBtn:SetText(aInfo.name)
        aBtn:SetScript("OnClick", function()
            if mainModel:IsShown() then
                mainModel:SetAnimation(aInfo.anim)
                if aInfo.sound then PlaySound(aInfo.sound) end
                if aInfo.anim ~= 0 then
                    C_Timer.After(1.2, function()
                        if mainModel:IsShown() then mainModel:SetAnimation(0) end
                    end)
                end
            end
        end)
    end

    local rotateHint = centerStage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    rotateHint:SetPoint("BOTTOM", animBar, "TOP", 0, 4)
    rotateHint:SetText("< Left-Drag to Rotate 360° | Scroll to Zoom >")
    centerStage.RotateHint = rotateHint

    -- Right Column: Full Creature Dossier & Moveset
    local rightPanel = Theme:CreateCard(parent, 298, 480)
    rightPanel:SetPoint("TOPLEFT", centerStage, "TOPRIGHT", 8, 0)
    parent.RightPanel = rightPanel

    Journal:BuildDossierPanel(rightPanel)
end

function Journal:BuildDossierPanel(panel)
    -- Name & Type Header
    local nameText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    nameText:SetPoint("TOPLEFT", 14, -12)
    nameText:SetText("Select a Companion")
    nameText:SetTextColor(0, 1, 0.6)
    panel.NameText = nameText

    local typeBadge = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    typeBadge:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -3)
    typeBadge:SetText("Type: -")
    panel.TypeBadge = typeBadge

    local metaText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    metaText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -12)
    metaText:SetJustifyH("RIGHT")
    metaText:SetText("Caught: -")
    metaText:SetTextColor(0.65, 0.7, 0.75)
    panel.MetaText = metaText

    -- Health & XP Progress Bars
    local hpBar = CreateFrame("StatusBar", nil, panel)
    hpBar:SetSize(270, 14)
    hpBar:SetPoint("TOPLEFT", typeBadge, "BOTTOMLEFT", 0, -10)
    hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hpBar:SetStatusBarColor(0.18, 0.80, 0.44)
    local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    local hpText = hpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hpText:SetPoint("CENTER", 0, 0)
    hpBar.Text = hpText
    panel.HPBar = hpBar

    local xpBar = CreateFrame("StatusBar", nil, panel)
    xpBar:SetSize(270, 10)
    xpBar:SetPoint("TOPLEFT", hpBar, "BOTTOMLEFT", 0, -6)
    xpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    xpBar:SetStatusBarColor(0.65, 0.30, 0.90)
    local xpBg = xpBar:CreateTexture(nil, "BACKGROUND")
    xpBg:SetAllPoints()
    xpBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    local xpText = xpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xpText:SetPoint("CENTER", 0, 0)
    xpBar.Text = xpText
    panel.XPBar = xpBar

    -- 4 Core Stats Badge (HP, ATK, DEF, SPD)
    local statsCard = Theme:CreateCard(panel, 270, 52)
    statsCard:SetPoint("TOPLEFT", xpBar, "BOTTOMLEFT", 0, -8)
    panel.StatsCard = statsCard

    local statSummary = statsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statSummary:SetPoint("TOPLEFT", 8, -6)
    statSummary:SetText("ATK: 0   DEF: 0   SPD: 0")
    panel.StatSummary = statSummary

    local battleRecord = statsCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    battleRecord:SetPoint("TOPLEFT", statSummary, "BOTTOMLEFT", 0, -4)
    battleRecord:SetText("Battle Record: 0W / 0L")
    battleRecord:SetTextColor(0.8, 0.85, 0.9)
    panel.BattleRecord = battleRecord

    -- Type Passive & Matchups Card
    local passiveCard = Theme:CreateCard(panel, 270, 48)
    passiveCard:SetPoint("TOPLEFT", statsCard, "BOTTOMLEFT", 0, -6)
    panel.PassiveCard = passiveCard

    local passiveText = passiveCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    passiveText:SetPoint("TOPLEFT", 6, -4)
    passiveText:SetPoint("TOPRIGHT", -6, -4)
    passiveText:SetJustifyH("LEFT")
    panel.PassiveText = passiveText

    local matchupText = passiveCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    matchupText:SetPoint("TOPLEFT", passiveText, "BOTTOMLEFT", 0, -2)
    matchupText:SetPoint("TOPRIGHT", -6, -2)
    matchupText:SetJustifyH("LEFT")
    panel.MatchupText = matchupText

    -- Active Moveset (4 Slots)
    local movesHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    movesHeader:SetPoint("TOPLEFT", passiveCard, "BOTTOMLEFT", 0, -8)
    movesHeader:SetText("|cff00ff99Active Moveset|r |cffaaaaaa(Click to Teach)|r")

    panel.MoveCards = {}
    for i = 1, 4 do
        local mCard = CreateFrame("Button", nil, panel, "BackdropTemplate")
        mCard:SetSize(132, 42)
        local col = ((i - 1) % 2)
        local row = math.floor((i - 1) / 2)
        mCard:SetPoint("TOPLEFT", movesHeader, "BOTTOMLEFT", col * 138, -4 - (row * 46))
        mCard.slotIndex = i

        mCard:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
        })
        mCard:SetBackdropColor(0.12, 0.16, 0.22, 0.85)
        mCard:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)

        local mIcon = mCard:CreateTexture(nil, "ARTWORK")
        mIcon:SetSize(28, 28)
        mIcon:SetPoint("LEFT", 5, 0)
        mIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        mCard.Icon = mIcon

        local mName = mCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mName:SetPoint("TOPLEFT", mIcon, "TOPRIGHT", 5, -2)
        mCard.Name = mName

        local mInfo = mCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mInfo:SetPoint("TOPLEFT", mName, "BOTTOMLEFT", 0, -2)
        mCard.Info = mInfo

        mCard:SetScript("OnClick", function(self)
            Journal:OpenTrainingDrawer(self.slotIndex)
            PlaySound(856)
        end)

        mCard:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.0, 1.0, 0.6, 1.0)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(string.format("Move Slot %d", self.slotIndex), 1, 1, 1)
            GameTooltip:AddLine("Click to teach a learned ability from your Training Grimoire.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        mCard:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)
            GameTooltip:Hide()
        end)

        panel.MoveCards[i] = mCard
    end

    -- Bottom Action Buttons
    local abandonBtn = Theme:CreateButton(panel, "Release to Wild", 270, 20)
    abandonBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 6)
    local aFont = abandonBtn:GetFontString()
    if aFont then aFont:SetTextColor(1.0, 0.45, 0.45) end
    abandonBtn:SetScript("OnClick", function()
        if selectedMobId then
            local mob = DB:GetMobById(selectedMobId)
            if not mob then return end
            local mName = mob.nickname ~= "" and mob.nickname or mob.name
            local dialog = StaticPopup_Show("FOREVERSAFARI_CONFIRM_ABANDON", string.format("|cffffd100%s|r (Lv %d %s)", mName, mob.level, mob.creatureType))
            if dialog then
                dialog.data = { mobId = selectedMobId }
            end
        end
    end)
    abandonBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Release to Wild", 1, 0.3, 0.3)
        GameTooltip:AddLine("Permanently unseal and release this companion back into the wild.", 1, 1, 1, true)
        GameTooltip:AddLine("|cffff4444Warning: This action cannot be undone!|r", 1, 0.4, 0.4)
        GameTooltip:Show()
    end)
    abandonBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.AbandonBtn = abandonBtn

    local setActiveBtn = Theme:CreateButton(panel, "Set Active Leader", 132, 22, true)
    setActiveBtn:SetPoint("BOTTOMLEFT", abandonBtn, "TOPLEFT", 0, 4)
    setActiveBtn:SetScript("OnClick", function()
        if selectedMobId then
            local inTeamSlot = nil
            for idx, id in ipairs(ForeverSafariDB.team or {}) do
                if id == selectedMobId then
                    inTeamSlot = idx
                    break
                end
            end
            if inTeamSlot then
                DB:SetActiveSlot(inTeamSlot)
            else
                local team = ForeverSafariDB.team or {}
                if #team < 4 then
                    table.insert(ForeverSafariDB.team, selectedMobId)
                    DB:SetActiveSlot(#ForeverSafariDB.team)
                else
                    local activeSlot = ForeverSafariDB.activeSlot or 1
                    ForeverSafariDB.team[activeSlot] = selectedMobId
                end
                DB:ValidateTeam()
            end
            Journal:UpdateUI()
            PlaySound(856)
        end
    end)
    panel.SetActiveBtn = setActiveBtn

    local feedTreatBtn = Theme:CreateButton(panel, "Feed Treat (+XP)", 132, 22)
    feedTreatBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 30)
    feedTreatBtn:SetScript("OnClick", function() Journal:UseItemOnMob("az_treat") end)
    panel.FeedTreatBtn = feedTreatBtn

    local healBtn = Theme:CreateButton(panel, "Heal Salve", 132, 22)
    healBtn:SetPoint("BOTTOMLEFT", setActiveBtn, "TOPLEFT", 0, 4)
    healBtn:SetScript("OnClick", function() Journal:UseItemOnMob("healing_salve") end)
    panel.HealBtn = healBtn

    local trainBtn = Theme:CreateButton(panel, "Grimoire Training", 132, 22)
    trainBtn:SetPoint("BOTTOMRIGHT", feedTreatBtn, "TOPRIGHT", 0, 26)
    trainBtn:SetScript("OnClick", function() Journal:OpenTrainingDrawer(1) end)
    panel.TrainBtn = trainBtn
end

-- =========================================================================
-- VIEW 2: 3D PAPERDOLL GALLERY GRID (6 LIVE 3D CARDS)
-- =========================================================================
function Journal:BuildGridView(parent)
    -- Top Type Filter Ribbon
    local filterBar = CreateFrame("Frame", nil, parent)
    filterBar:SetSize(816, 26)
    filterBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    parent.FilterBar = filterBar

    local typeFilters = { "ALL", "Aquatic", "Beast", "Dragonkin", "Elemental", "Flying", "Humanoid", "Magic", "Mechanical", "Undead" }
    parent.FilterButtons = {}

    for i, fType in ipairs(typeFilters) do
        local fBtn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
        fBtn:SetSize(76, 22)
        fBtn:SetPoint("LEFT", filterBar, "LEFT", (i - 1) * 81, 0)
        fBtn.filterType = fType

        fBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
        })

        local fText = fBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fText:SetPoint("CENTER", 0, 0)
        fText:SetText(fType)
        fBtn.Text = fText

        fBtn:SetScript("OnClick", function(self)
            gridTypeFilter = self.filterType
            gridPage = 1
            Journal:UpdateGridView()
            PlaySound(856)
        end)

        parent.FilterButtons[fType] = fBtn
    end

    -- 6 Live 3D Paperdoll Cards Grid (2 rows of 3)
    parent.Cards = {}
    for i = 1, 6 do
        local card = Theme:CreateCard(parent, 266, 210)
        local col = ((i - 1) % 3)
        local row = math.floor((i - 1) / 3)
        card:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", col * 275, -10 - (row * 218))
        card.cardIndex = i

        -- Card Header: Level & Type Badge
        local lvlText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lvlText:SetPoint("TOPLEFT", 8, -8)
        card.LvlText = lvlText

        local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameText:SetPoint("TOPLEFT", lvlText, "BOTTOMLEFT", 0, -2)
        card.NameText = nameText

        local typeText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        typeText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
        card.TypeText = typeText

        -- 3D Pedestal
        local pedestal = card:CreateTexture(nil, "BACKGROUND")
        pedestal:SetSize(130, 30)
        pedestal:SetPoint("CENTER", card, "CENTER", 0, -10)
        pedestal:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        pedestal:SetVertexColor(0.12, 0.22, 0.18, 0.7)
        card.Pedestal = pedestal

        -- Live 3D Model Frame
        local model = CreateFrame("PlayerModel", "ForeverSafariGridModel" .. i, card)
        model:SetSize(140, 130)
        model:SetPoint("BOTTOM", pedestal, "CENTER", 0, -8)
        Setup3DModelInteractions(model)
        card.Model3D = model

        -- HP Bar
        local hpBar = CreateFrame("StatusBar", nil, card)
        hpBar:SetSize(250, 10)
        hpBar:SetPoint("BOTTOM", card, "BOTTOM", 0, 34)
        hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        hpBar:SetStatusBarColor(0.18, 0.80, 0.44)
        local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
        hpBg:SetAllPoints()
        hpBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        local hpLabel = hpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hpLabel:SetPoint("CENTER", 0, 0)
        hpBar.Text = hpLabel
        card.HPBar = hpBar

        -- Quick Action Buttons
        local inspectBtn = Theme:CreateButton(card, "3D Inspect", 120, 20, true)
        inspectBtn:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 8, 8)
        inspectBtn:SetScript("OnClick", function()
            if card.mobId then
                if IsShiftKeyDown() then
                    local mob = DB:GetMobById(card.mobId)
                    if mob and ChatEdit_InsertLink then
                        local dna = DB:ExportCompanionDNA(mob)
                        local link = string.format("|cffffd100|Hsafari:%s|h[Safari: %s Lv.%d (3D)]|h|r",
                            dna, mob.nickname ~= "" and mob.nickname or mob.name, mob.level)
                        if not ChatEdit_InsertLink(link) then
                            DEFAULT_CHAT_FRAME:AddMessage(string.format("%sShift-Click link: %s", C.PREFIX, link))
                        end
                        return
                    end
                end
                selectedMobId = card.mobId
                Journal:SetTab("SHOWCASE")
                PlaySound(856)
            end
        end)
        card.InspectBtn = inspectBtn

        local leaderBtn = Theme:CreateButton(card, "Make Leader", 120, 20)
        leaderBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 8)
        leaderBtn:SetScript("OnClick", function()
            if card.mobId then
                local inTeamSlot = nil
                for idx, id in ipairs(ForeverSafariDB.team or {}) do
                    if id == card.mobId then
                        inTeamSlot = idx
                        break
                    end
                end
                if inTeamSlot then
                    DB:SetActiveSlot(inTeamSlot)
                else
                    local team = ForeverSafariDB.team or {}
                    if #team < 4 then
                        table.insert(ForeverSafariDB.team, card.mobId)
                        DB:SetActiveSlot(#ForeverSafariDB.team)
                    else
                        local activeSlot = ForeverSafariDB.activeSlot or 1
                        ForeverSafariDB.team[activeSlot] = card.mobId
                    end
                    DB:ValidateTeam()
                end
                Journal:UpdateUI()
                PlaySound(856)
            end
        end)
        card.LeaderBtn = leaderBtn

        parent.Cards[i] = card
    end

    -- Bottom Pagination Controls
    local paginationBar = CreateFrame("Frame", nil, parent)
    paginationBar:SetSize(816, 26)
    paginationBar:SetPoint("BOTTOM", parent, "BOTTOM", 0, 0)
    parent.PaginationBar = paginationBar

    local prevPageBtn = Theme:CreateButton(paginationBar, "< Prev Page", 100, 22)
    prevPageBtn:SetPoint("LEFT", paginationBar, "LEFT", 260, 0)
    prevPageBtn:SetScript("OnClick", function()
        if gridPage > 1 then
            gridPage = gridPage - 1
            Journal:UpdateGridView()
            PlaySound(856)
        end
    end)
    parent.PrevPageBtn = prevPageBtn

    local pageInfo = paginationBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pageInfo:SetPoint("CENTER", paginationBar, "CENTER", 0, 0)
    pageInfo:SetText("Page 1 of 1")
    parent.PageInfo = pageInfo

    local nextPageBtn = Theme:CreateButton(paginationBar, "Next Page >", 100, 22)
    nextPageBtn:SetPoint("RIGHT", paginationBar, "RIGHT", -260, 0)
    nextPageBtn:SetScript("OnClick", function()
        gridPage = gridPage + 1
        Journal:UpdateGridView()
        PlaySound(856)
    end)
    parent.NextPageBtn = nextPageBtn
end

function Journal:UpdateGridView()
    local parent = frame.GridContainer
    if not parent or not parent:IsShown() then return end

    -- Update Filter Buttons styling
    for fType, btn in pairs(parent.FilterButtons) do
        if fType == gridTypeFilter then
            btn:SetBackdropColor(0.0, 0.45, 0.35, 0.95)
            btn:SetBackdropBorderColor(0.0, 1.0, 0.6, 1.0)
            btn.Text:SetTextColor(1, 1, 1)
        else
            btn:SetBackdropColor(0.1, 0.13, 0.18, 0.8)
            btn:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.6)
            btn.Text:SetTextColor(0.7, 0.75, 0.8)
        end
    end

    local collection = DB:GetCollection()
    local filtered = {}
    for _, mob in ipairs(collection) do
        if gridTypeFilter == "ALL" or mob.creatureType == gridTypeFilter then
            table.insert(filtered, mob)
        end
    end

    local totalPages = math.max(1, math.ceil(#filtered / 6))
    if gridPage > totalPages then gridPage = totalPages end
    if gridPage < 1 then gridPage = 1 end

    parent.PageInfo:SetText(string.format("Page %d of %d  |  Total: %d", gridPage, totalPages, #filtered))
    parent.PrevPageBtn:SetEnabled(gridPage > 1)
    parent.NextPageBtn:SetEnabled(gridPage < totalPages)

    local startIdx = (gridPage - 1) * 6 + 1
    for i = 1, 6 do
        local card = parent.Cards[i]
        local mob = filtered[startIdx + (i - 1)]
        if mob then
            card.mobId = mob.id
            local typeInfo = C.CREATURE_TYPES[mob.creatureType] or C.CREATURE_TYPES["Beast"]
            card.LvlText:SetText(string.format("|cffffd100Lv %d|r", mob.level))
            card.NameText:SetText(string.format("|cff00ff99%s|r", mob.nickname ~= "" and mob.nickname or mob.name))
            card.TypeText:SetText(string.format("|cff%s[%s]|r", typeInfo.color or "ffffff", mob.creatureType))

            -- 3D Model
            local displayId = (mob.displayId and mob.displayId > 0) and mob.displayId or C.GetDefaultDisplayId(mob.creatureType, mob.name)
            SetModelCreature(card.Model3D, displayId)
            card.Model3D:Show()

            -- HP Bar
            card.HPBar:SetMinMaxValues(0, mob.maxHP)
            card.HPBar:SetValue(mob.currentHP)
            card.HPBar.Text:SetText(string.format("%d / %d HP", mob.currentHP, mob.maxHP))

            if mob.id == selectedMobId then
                card:SetBackdropBorderColor(0.0, 1.0, 0.6, 1.0)
            else
                card:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
            end

            if card.LeaderBtn then
                local inTeamSlot = nil
                for idx, id in ipairs(ForeverSafariDB.team or {}) do
                    if id == mob.id then
                        inTeamSlot = idx
                        break
                    end
                end
                local activeSlot = ForeverSafariDB.activeSlot or 1
                if inTeamSlot and inTeamSlot == activeSlot then
                    card.LeaderBtn:SetText("|cff00ff00Active Leader|r")
                    card.LeaderBtn:Disable()
                elseif inTeamSlot then
                    card.LeaderBtn:SetText(string.format("Make Leader (#%d)", inTeamSlot))
                    card.LeaderBtn:Enable()
                else
                    card.LeaderBtn:SetText("+ Add to Party")
                    card.LeaderBtn:Enable()
                end
            end

            card:Show()
        else
            card.mobId = nil
            card:Hide()
        end
    end
end

-- =========================================================================
-- VIEW 3: AZEROTH BESTIARY (POKEDEX IN 3D PAPERDOLLS)
-- =========================================================================
function Journal:BuildBestiaryView(parent)
    -- Left: Species List
    local leftPanel = Theme:CreateCard(parent, 250, 480)
    leftPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    parent.LeftPanel = leftPanel

    local listTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    listTitle:SetPoint("TOPLEFT", 12, -10)
    listTitle:SetText("|cff00ff99Azeroth Species Index|r")

    local scroll = CreateFrame("ScrollFrame", "ForeverSafariBestiaryScroll", leftPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -32)
    scroll:SetPoint("BOTTOMRIGHT", -26, 8)

    local content = CreateFrame("Frame", "ForeverSafariBestiaryContent", scroll)
    content:SetSize(210, 500)
    scroll:SetScrollChild(content)
    parent.Content = content

    -- Right: 3D Paperdoll Species Dossier
    local rightPanel = Theme:CreateCard(parent, 558, 480)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 8, 0)
    parent.RightPanel = rightPanel

    local bName = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    bName:SetPoint("TOPLEFT", 16, -14)
    bName:SetText("Species Name")
    bName:SetTextColor(0, 1, 0.6)
    rightPanel.NameText = bName

    local bType = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bType:SetPoint("TOPLEFT", bName, "BOTTOMLEFT", 0, -3)
    bType:SetText("Type: -")
    rightPanel.TypeText = bType

    local bStatus = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bStatus:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -16, -14)
    bStatus:SetText("Status: Seen 0 | Caught 0")
    rightPanel.StatusText = bStatus

    -- 3D Species Stage
    local bStage = Theme:CreateCard(rightPanel, 240, 240)
    bStage:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 16, -60)
    rightPanel.Stage = bStage

    local bPedestal = bStage:CreateTexture(nil, "BACKGROUND")
    bPedestal:SetSize(180, 42)
    bPedestal:SetPoint("CENTER", bStage, "CENTER", 0, -60)
    bPedestal:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bPedestal:SetVertexColor(0.12, 0.22, 0.18, 0.8)

    local bModel = CreateFrame("PlayerModel", "ForeverSafariBestiary3DModel", bStage)
    bModel:SetSize(220, 220)
    bModel:SetPoint("BOTTOM", bPedestal, "CENTER", 0, -10)
    Setup3DModelInteractions(bModel)
    rightPanel.Model3D = bModel

    local bRotateHint = bStage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    bRotateHint:SetPoint("BOTTOM", bStage, "BOTTOM", 0, 4)
    bRotateHint:SetText("< Drag 360° | Scroll Zoom >")

    -- Species Details (Habitat, Base Stats, Passives, Matchups)
    local detailsCard = Theme:CreateCard(rightPanel, 270, 240)
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

    local descText = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descText:SetPoint("TOPLEFT", habitatText, "BOTTOMLEFT", 0, -8)
    descText:SetPoint("TOPRIGHT", -10, -8)
    descText:SetJustifyH("LEFT")
    descText:SetTextColor(0.8, 0.85, 0.9)
    rightPanel.DescText = descText

    local baseStatsText = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    baseStatsText:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -12)
    baseStatsText:SetText("Base Stats: HP 60 | ATK 15 | DEF 12 | SPD 14")
    rightPanel.BaseStatsText = baseStatsText

    -- Lower Matchup & Move Pool Panel
    local lowerCard = Theme:CreateCard(rightPanel, 526, 150)
    lowerCard:SetPoint("TOPLEFT", bStage, "BOTTOMLEFT", 0, -10)
    rightPanel.LowerCard = lowerCard

    local passiveTitle = lowerCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    passiveTitle:SetPoint("TOPLEFT", 10, -8)
    passiveTitle:SetPoint("TOPRIGHT", -10, -8)
    passiveTitle:SetJustifyH("LEFT")
    rightPanel.PassiveTitle = passiveTitle

    local matchupInfo = lowerCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    matchupInfo:SetPoint("TOPLEFT", passiveTitle, "BOTTOMLEFT", 0, -4)
    matchupInfo:SetPoint("TOPRIGHT", -10, -4)
    matchupInfo:SetJustifyH("LEFT")
    rightPanel.MatchupInfo = matchupInfo

    local movesTitle = lowerCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    movesTitle:SetPoint("TOPLEFT", matchupInfo, "BOTTOMLEFT", 0, -8)
    movesTitle:SetText("|cff00ff99Natural Move Pool:|r")

    local movesList = lowerCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    movesList:SetPoint("TOPLEFT", movesTitle, "BOTTOMLEFT", 0, -4)
    movesList:SetPoint("TOPRIGHT", -10, -4)
    movesList:SetJustifyH("LEFT")
    rightPanel.MovesList = movesList
end

function Journal:UpdateBestiaryView()
    local parent = frame.BestiaryContainer
    if not parent or not parent:IsShown() then return end

    local speciesList = C.SPECIES_CATALOG or {}
    local content = parent.Content
    local yOffset = 0

    for i, spec in ipairs(speciesList) do
        local btn = bestiaryButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, content, "BackdropTemplate")
            btn:SetSize(200, 40)
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 8,
            })
            btn:SetBackdropColor(0.1, 0.14, 0.20, 0.8)
            btn:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)

            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(26, 26)
            icon:SetPoint("LEFT", 6, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            btn.Icon = icon

            local title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -2)
            btn.Title = title

            local sub = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
            btn.Sub = sub

            btn:SetScript("OnClick", function(self)
                selectedBestiaryId = self.specId
                Journal:UpdateBestiaryDossier()
                PlaySound(856)
            end)

            bestiaryButtons[i] = btn
        end

        btn:SetPoint("TOPLEFT", content, "TOPLEFT", 4, yOffset)
        btn.specId = spec.id

        local typeInfo = C.CREATURE_TYPES[spec.type] or C.CREATURE_TYPES["Beast"]
        local isTypeLocked = C.LOCKED_CREATURE_TYPES and C.LOCKED_CREATURE_TYPES[spec.type] and not (DB and DB.IsTypeUnlocked and DB:IsTypeUnlocked(spec.type))
        btn.Icon:SetTexture(typeInfo.icon)
        btn.Title:SetText(string.format("#%02d %s", spec.id, spec.name))
        if isTypeLocked then
            btn.Sub:SetText(string.format("|cff%s%s|r |cffff5555[Permit Req]|r", typeInfo.color or "ffffff", spec.type))
        else
            btn.Sub:SetText(string.format("|cff%s%s|r", typeInfo.color or "ffffff", spec.type))
        end

        if spec.id == selectedBestiaryId then
            btn:SetBackdropBorderColor(0.0, 1.0, 0.6, 1.0)
        else
            btn:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)
        end

        btn:Show()
        yOffset = yOffset - 44
    end

    content:SetHeight(math.max(450, math.abs(yOffset) + 10))
    Journal:UpdateBestiaryDossier()
end

function Journal:UpdateBestiaryDossier()
    local parent = frame.BestiaryContainer
    if not parent then return end
    local rPanel = parent.RightPanel

    local speciesList = C.SPECIES_CATALOG or {}
    local spec = speciesList[selectedBestiaryId] or speciesList[1]
    if not spec then return end

    local typeInfo = C.CREATURE_TYPES[spec.type] or C.CREATURE_TYPES["Beast"]
    local isTypeLocked = C.LOCKED_CREATURE_TYPES and C.LOCKED_CREATURE_TYPES[spec.type] and not (DB and DB.IsTypeUnlocked and DB:IsTypeUnlocked(spec.type))

    rPanel.NameText:SetText(string.format("|cff00ff99#%02d %s|r", spec.id, spec.name))
    if isTypeLocked then
        local permit = C.TYPE_RESEARCH_PERMITS and C.TYPE_RESEARCH_PERMITS[spec.type]
        local permitName = permit and permit.name or (spec.type .. " Research Permit")
        rPanel.TypeText:SetText(string.format("Type: |cff%s[%s]|r |cffff5555[Locked]|r", typeInfo.color or "ffffff", spec.type))
        rPanel.StatusText:SetText(string.format("Status: |cffff5555[Research Permit Required]|r\n|cffffd100Earned via Quest: [%s]|r", permitName))
    else
        rPanel.TypeText:SetText(string.format("Type: |cff%s[%s]|r", typeInfo.color or "ffffff", spec.type))
        local discRecord = (ForeverSafariDB and ForeverSafariDB.discovered and ForeverSafariDB.discovered[spec.name]) or { seen = 0, caught = 0 }
        rPanel.StatusText:SetText(string.format("Status: |cffffd100Seen %d|r | |cff00ff99Caught %d|r", discRecord.seen or 0, discRecord.caught or 0))
    end

    SetModelCreature(rPanel.Model3D, spec.displayId)

    rPanel.HabitatText:SetText(spec.habitat or "Azeroth")
    rPanel.DescText:SetText(spec.description or "")

    local bs = spec.baseStats or { hp = 60, atk = 12, def = 10, spd = 12 }
    rPanel.BaseStatsText:SetText(string.format("Base Stats: HP |cff33ff33%d|r | ATK |cffffaa00%d|r | DEF |cff3399ff%d|r | SPD |cff00ff99%d|r",
        bs.hp, bs.atk, bs.def, bs.spd))

    rPanel.PassiveTitle:SetText(string.format("|cffffd100Passive:|r |cffffffff%s|r - %s", typeInfo.passiveName or "Trait", typeInfo.passiveDesc or ""))
    rPanel.MatchupInfo:SetText(string.format("|cff00ff00Strong vs:|r %s (150%%)   |cffff4444Weak vs:|r %s (Takes 150%%)", typeInfo.strongAgainst or "-", typeInfo.weakAgainst or "-"))

    local movesStr = ""
    if spec.moves then
        for _, mKey in ipairs(spec.moves) do
            local mData = C.ABILITIES[mKey]
            if mData then
                movesStr = movesStr .. string.format("[|cffffffff%s|r: %s]  ", mData.name, (mData.cooldown and mData.cooldown > 0) and (mData.cooldown .. "t CD") or "Instant")
            end
        end
    end
    rPanel.MovesList:SetText(movesStr ~= "" and movesStr or "Tackle")
end

-- =========================================================================
-- BOTTOM TEAM DOCK (WITH 3D MINI-PAPERDOLLS)
-- =========================================================================
function Journal:BuildTeamDock(parent)
    local dock = Theme:CreateCard(parent, 816, 52)
    dock:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 12, 6)
    parent.TeamDock = dock

    local dockLabel = dock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dockLabel:SetPoint("LEFT", dock, "LEFT", 10, 0)
    dockLabel:SetText("|cff00ff99Active Party|r\n(Slots 1-4)")

    parent.TeamSlots = {}
    for i = 1, 4 do
        local slot = Theme:CreateCard(dock, 168, 42)
        slot:SetPoint("LEFT", dockLabel, "RIGHT", 12 + ((i - 1) * 174), 0)
        slot.slotIndex = i

        -- Mini 3D Model Frame
        local model = CreateFrame("PlayerModel", "ForeverSafariParty3DModel" .. i, slot)
        model:SetSize(36, 36)
        model:SetPoint("LEFT", 4, 0)
        model:SetRotation(math.rad(20))
        slot.Model3D = model

        local sName = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sName:SetPoint("TOPLEFT", model, "TOPRIGHT", 6, -2)
        slot.Name = sName

        local sHp = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sHp:SetPoint("TOPLEFT", sName, "BOTTOMLEFT", 0, -2)
        slot.HP = sHp

        slot:EnableMouse(true)
        slot:SetScript("OnMouseDown", function(self, button)
            local team = DB:GetTeam()
            local member = team[i]
            if button == "RightButton" then
                if selectedMobId then
                    DB:SetTeamSlot(i, selectedMobId)
                    PlaySound(856)
                end
            else
                if member then
                    DB:SetActiveSlot(i)
                    selectedMobId = member.id
                    Journal:SetTab("SHOWCASE")
                    Journal:UpdateUI()
                    PlaySound(856)
                elseif selectedMobId then
                    DB:SetTeamSlot(i, selectedMobId)
                    DB:SetActiveSlot(i)
                    Journal:UpdateUI()
                    PlaySound(856)
                end
            end
        end)

        slot:SetScript("OnEnter", function(self)
            local team = DB:GetTeam()
            local member = team[i]
            local activeSlot = ForeverSafariDB.activeSlot or 1
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if member then
                local pName = member.nickname ~= "" and member.nickname or member.name
                GameTooltip:AddLine(string.format("Party Slot %d: %s", i, pName), 1, 1, 1)
                GameTooltip:AddLine(string.format("Level %d %s | %d/%d HP", member.level, member.creatureType, member.currentHP, member.maxHP), 0.8, 0.8, 0.8)
                if i == activeSlot then
                    GameTooltip:AddLine("|cff00ff00[Active Battle Leader]|r", 0, 1, 0)
                else
                    GameTooltip:AddLine("|cffaaaaaaLeft-Click: Set as Active Battle Leader|r", 0.7, 0.7, 0.7)
                end
                GameTooltip:AddLine("|cffaaaaaaRight-Click: Replace with Selected Companion|r", 0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine(string.format("Party Slot %d (Empty)", i), 1, 1, 1)
                GameTooltip:AddLine("|cffaaaaaaClick to assign selected companion to this slot|r", 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

        parent.TeamSlots[i] = slot
    end
end

-- =========================================================================
-- BEAST TRAINING GRIMOIRE DRAWER (VANILLA WOW PET SYSTEM)
-- =========================================================================
function Journal:BuildTrainingDrawer(parent)
    local drawer = CreateFrame("Frame", "ForeverSafariTrainingDrawer", parent, "BackdropTemplate")
    drawer:SetSize(290, 480)
    drawer:SetPoint("TOPLEFT", parent, "TOPRIGHT", 6, -68)
    drawer:SetFrameStrata("HIGH")

    Theme:ApplyFrameBackdrop(drawer, true)

    local title = drawer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("|cff00ff99Beast Training Grimoire|r")
    drawer.Title = title

    local sub = drawer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetPoint("TOPRIGHT", drawer, "TOPRIGHT", -10, -4)
    sub:SetJustifyH("LEFT")
    sub:SetText("Select a learned ability to teach to Slot 1.")
    sub:SetTextColor(0.7, 0.75, 0.8)
    drawer.Sub = sub

    local scroll = CreateFrame("ScrollFrame", "ForeverSafariTrainerScroll", drawer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -46)
    scroll:SetPoint("BOTTOMRIGHT", -26, 36)

    local content = CreateFrame("Frame", "ForeverSafariTrainerContent", scroll)
    content:SetSize(250, 420)
    scroll:SetScrollChild(content)
    drawer.Content = content

    local closeBtn = Theme:CreateButton(drawer, "Close", 100, 22)
    closeBtn:SetPoint("BOTTOM", drawer, "BOTTOM", 0, 8)
    closeBtn:SetScript("OnClick", function() drawer:Hide() end)

    drawer:Hide()
    parent.TrainingDrawer = drawer
end

function Journal:OpenTrainingDrawer(slotIndex)
    trainingSlotIndex = slotIndex or 1
    local drawer = frame.TrainingDrawer
    if not drawer then return end

    local mob = DB:GetMobById(selectedMobId)
    if not mob then return end

    local mName = mob.nickname ~= "" and mob.nickname or mob.name
    drawer.Title:SetText(string.format("|cff00ff99Training: Slot %d|r", trainingSlotIndex))
    drawer.Sub:SetText(string.format("Teach a learned ability to %s (Slot %d):", mName, trainingSlotIndex))

    local unlocked = DB:GetUnlockedAbilities()
    local content = drawer.Content
    local yOffset = 0
    local count = 0

    for moveKey, _ in pairs(unlocked) do
        local moveData = C.ABILITIES[moveKey]
        if moveData then
            local isCompatible = (moveData.type == mob.creatureType or moveData.type == "Humanoid" or moveKey == "Tackle")
            if isCompatible then
                count = count + 1
                local btn = trainerButtons[count]
                if not btn then
                    btn = CreateFrame("Button", nil, content, "BackdropTemplate")
                    btn:SetSize(245, 52)
                    btn:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                        edgeSize = 8,
                    })
                    btn:SetBackdropColor(0.1, 0.14, 0.20, 0.9)
                    btn:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)

                    local icon = btn:CreateTexture(nil, "ARTWORK")
                    icon:SetSize(32, 32)
                    icon:SetPoint("LEFT", 6, 0)
                    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    btn.Icon = icon

                    local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -2)
                    btn.NameText = nameText

                    local infoText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    infoText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
                    infoText:SetTextColor(0.7, 0.75, 0.8)
                    btn.InfoText = infoText

                    local teachBtn = Theme:CreateButton(btn, "TEACH", 60, 22, true)
                    teachBtn:SetPoint("RIGHT", -6, 0)
                    btn.TeachBtn = teachBtn

                    trainerButtons[count] = btn
                end

                btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
                btn.moveKey = moveKey
                btn.Icon:SetTexture(moveData.icon)
                btn.NameText:SetText(string.format("|cffffffff%s|r", moveData.name))
                local cdStr = (moveData.cooldown and moveData.cooldown > 0) and (moveData.cooldown .. "t CD") or "No CD"
                btn.InfoText:SetText(string.format("%s | %s uses", cdStr, moveData.maxUses or 10))

                btn.TeachBtn:SetScript("OnClick", function()
                    DB:SetMobAbility(selectedMobId, trainingSlotIndex, moveKey)
                    PlaySound(1194)
                    drawer:Hide()
                    Journal:UpdateShowcase()
                    Journal:UpdateUI()
                    if ForeverSafari.Toast then
                        ForeverSafari.Toast:ShowReward("Ability Learned!", string.format("Taught %s to %s!", moveData.name, mName))
                    end
                end)

                btn:Show()
                yOffset = yOffset - 56
            end
        end
    end

    for j = count + 1, #trainerButtons do
        trainerButtons[j]:Hide()
    end

    content:SetHeight(math.max(350, math.abs(yOffset) + 10))
    drawer:Show()
end

-- =========================================================================
-- CYCLING & ACTIONS
-- =========================================================================
function Journal:CycleSelectedMob(direction)
    local collection = DB:GetCollection()
    if #collection == 0 then return end

    local curIdx = 1
    for i, mob in ipairs(collection) do
        if mob.id == selectedMobId then
            curIdx = i
            break
        end
    end

    local nextIdx = curIdx + direction
    if nextIdx < 1 then nextIdx = #collection end
    if nextIdx > #collection then nextIdx = 1 end

    selectedMobId = collection[nextIdx].id
    Journal:UpdateUI()
    PlaySound(856)
end

function Journal:UseItemOnMob(itemId)
    if not selectedMobId then return end
    local mob = DB:GetMobById(selectedMobId)
    if not mob then return end

    if DB:GetItemCount(itemId) <= 0 then
        local itemData = C.SHOP_ITEMS[itemId] or {}
        ForeverSafari.Toast:ShowAlert("Out of Item", string.format("You have no %s! Buy more at the Safari Supplies.", itemData.name or "items"))
        return
    end

    if itemId == "az_treat" then
        DB:RemoveItem("az_treat", 1)
        SE:AddExperience(mob, 100)
        PlaySound(1194)
    elseif itemId == "healing_salve" then
        DB:RemoveItem("healing_salve", 1)
        local healAmt = math.floor(mob.maxHP * 0.50)
        mob.currentHP = math.min(mob.maxHP, mob.currentHP + healAmt)
        PlaySound(1194)
        ForeverSafari.Toast:ShowReward("Companion Healed", string.format("Restored %d HP to %s!", healAmt, mob.name))
    end

    Journal:UpdateUI()
end

-- =========================================================================
-- UPDATE LOGIC
-- =========================================================================
function Journal:UpdateList()
    local collection = DB:GetCollection()
    local search = string.lower((frame.ShowcaseContainer.SearchBox and frame.ShowcaseContainer.SearchBox:GetText()) or "")

    local filtered = {}
    for _, mob in ipairs(collection) do
        local match = true
        if search ~= "" then
            local nameMatch = string.find(string.lower(mob.name or ""), search)
            local typeMatch = string.find(string.lower(mob.creatureType or ""), search)
            if not nameMatch and not typeMatch then match = false end
        end
        if match then table.insert(filtered, mob) end
    end

    local content = frame.ShowcaseContainer.ListContent
    local yOffset = 0

    for i, mob in ipairs(filtered) do
        local btn = listButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, content, "BackdropTemplate")
            btn:SetSize(175, 42)
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 8,
            })
            btn:SetBackdropColor(0.1, 0.14, 0.20, 0.8)
            btn:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)

            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(28, 28)
            icon:SetPoint("LEFT", 6, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            btn.Icon = icon

            local title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -3)
            btn.Title = title

            local sub = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
            btn.Sub = sub

            btn:SetScript("OnClick", function(self)
                if IsShiftKeyDown() then
                    local mob = DB:GetMobById(self.mobId)
                    if mob and ChatEdit_InsertLink then
                        local dna = DB:ExportCompanionDNA(mob)
                        local link = string.format("|cffffd100|Hsafari:%s|h[Safari: %s Lv.%d (3D)]|h|r",
                            dna, mob.nickname ~= "" and mob.nickname or mob.name, mob.level)
                        if not ChatEdit_InsertLink(link) then
                            DEFAULT_CHAT_FRAME:AddMessage(string.format("%sShift-Click link: %s", C.PREFIX, link))
                        end
                        return
                    end
                end
                selectedMobId = self.mobId
                Journal:UpdateShowcase()
                PlaySound(856)
            end)

            listButtons[i] = btn
        end

        btn:SetPoint("TOPLEFT", content, "TOPLEFT", 4, yOffset)
        btn.mobId = mob.id

        local typeInfo = C.CREATURE_TYPES[mob.creatureType] or C.CREATURE_TYPES["Beast"]
        btn.Icon:SetTexture(typeInfo.icon)
        btn.Title:SetText(string.format("Lv %d %s", mob.level, mob.nickname ~= "" and mob.nickname or mob.name))
        btn.Sub:SetText(string.format("|cff%s%s|r (%d/%d)", typeInfo.color or "ffffff", mob.creatureType, mob.currentHP, mob.maxHP))

        if mob.id == selectedMobId then
            btn:SetBackdropBorderColor(0, 1, 0.6, 1)
        else
            btn:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)
        end

        btn:Show()
        yOffset = yOffset - 46
    end

    for j = #filtered + 1, #listButtons do
        listButtons[j]:Hide()
    end

    content:SetHeight(math.max(400, math.abs(yOffset) + 10))

    if not selectedMobId and #filtered > 0 then
        selectedMobId = filtered[1].id
    end
end

function Journal:UpdateShowcase()
    local cStage = frame.ShowcaseContainer.CenterStage
    local panel = frame.ShowcaseContainer.RightPanel
    local collection = DB:GetCollection()

    if not selectedMobId or #collection == 0 then
        panel.NameText:SetText("No Companion Selected")
        panel.TypeBadge:SetText("Type: -")
        panel.MetaText:SetText("Habitat: -\nNative: -")
        panel.HPBar:SetMinMaxValues(0, 1)
        panel.HPBar:SetValue(0)
        panel.HPBar.Text:SetText("HP: - / -")
        panel.XPBar:SetMinMaxValues(0, 1)
        panel.XPBar:SetValue(0)
        panel.XPBar.Text:SetText("Attunement: -")
        panel.StatSummary:SetText("ATK: -   DEF: -   SPD: -")
        panel.BattleRecord:SetText("Battle Record: -")
        panel.PassiveText:SetText("|cffffd100Rank Perk:|r None")
        panel.MatchupText:SetText("No active companion.")

        for i = 1, 4 do
            panel.MoveCards[i]:Hide()
        end

        if panel.AbandonBtn then panel.AbandonBtn:Disable() end
        if panel.SetActiveBtn then panel.SetActiveBtn:Disable() end
        if panel.FeedTreatBtn then panel.FeedTreatBtn:Disable() end
        if panel.HealBtn then panel.HealBtn:Disable() end
        if panel.TrainBtn then panel.TrainBtn:Disable() end

        cStage.MainModel:Hide()
        cStage.LeftModel:Hide()
        cStage.RightModel:Hide()
        cStage.Counter:SetText("0 Companions in Collection")
        return
    end

    if panel.AbandonBtn then panel.AbandonBtn:Enable() end
    if panel.SetActiveBtn then panel.SetActiveBtn:Enable() end
    if panel.FeedTreatBtn then panel.FeedTreatBtn:Enable() end
    if panel.HealBtn then panel.HealBtn:Enable() end
    if panel.TrainBtn then panel.TrainBtn:Enable() end

    local mob = DB:GetMobById(selectedMobId)
    if not mob then
        mob = collection[1]
        selectedMobId = mob and mob.id
    end
    if not mob then return end

    -- Find index of current mob for carousel flanking models & counter
    local curIdx = 1
    for i, m in ipairs(collection) do
        if m.id == selectedMobId then
            curIdx = i
            break
        end
    end

    cStage.Counter:SetText(string.format("Companion #%d of %d in Collection", curIdx, #collection))

    -- Center Main 3D Paperdoll Model
    local displayId = (mob.displayId and mob.displayId > 0) and mob.displayId or C.GetDefaultDisplayId(mob.creatureType, mob.name)
    SetModelCreature(cStage.MainModel, displayId)
    cStage.MainModel:SetRotation(cStage.MainModel.rotation or math.rad(25))
    cStage.MainModel:Show()

    -- Left Flanking 3D Model (Previous Mob)
    local leftIdx = curIdx - 1
    if leftIdx < 1 then leftIdx = #collection end
    local leftMob = collection[leftIdx]
    if leftMob and #collection > 1 then
        local leftDisp = (leftMob.displayId and leftMob.displayId > 0) and leftMob.displayId or C.GetDefaultDisplayId(leftMob.creatureType, leftMob.name)
        SetModelCreature(cStage.LeftModel, leftDisp)
        cStage.LeftModel:Show()
    else
        cStage.LeftModel:Hide()
    end

    -- Right Flanking 3D Model (Next Mob)
    local rightIdx = curIdx + 1
    if rightIdx > #collection then rightIdx = 1 end
    local rightMob = collection[rightIdx]
    if rightMob and #collection > 1 then
        local rightDisp = (rightMob.displayId and rightMob.displayId > 0) and rightMob.displayId or C.GetDefaultDisplayId(rightMob.creatureType, rightMob.name)
        SetModelCreature(cStage.RightModel, rightDisp)
        cStage.RightModel:Show()
    else
        cStage.RightModel:Hide()
    end

    -- Update Dossier
    local typeInfo = C.CREATURE_TYPES[mob.creatureType] or C.CREATURE_TYPES["Beast"]
    local typeColor = typeInfo.color or "ffffff"

    local rankData, curPts, reqPts, fraction = ForeverSafari.StatEngine:GetRankProgress(mob.attunement or 0)

    panel.NameText:SetText(string.format("|cff00ff99%s|r", mob.nickname ~= "" and mob.nickname or mob.name))
    panel.TypeBadge:SetText(string.format("Type: |cff%s[%s]|r  |cff%sRank %s: %s|r", typeColor, mob.creatureType, rankData.color, rankData.roman, rankData.title))
    panel.MetaText:SetText(string.format("Habitat: %s\nNative: %s", mob.caughtZone or "Azeroth", mob.family or "Beast"))

    panel.HPBar:SetMinMaxValues(0, mob.maxHP)
    panel.HPBar:SetValue(mob.currentHP)
    panel.HPBar.Text:SetText(string.format("HP: %d / %d", mob.currentHP, mob.maxHP))

    panel.XPBar:SetMinMaxValues(0, reqPts)
    panel.XPBar:SetValue(curPts)
    if rankData.rank >= 5 then
        panel.XPBar.Text:SetText("Attunement: Rank V (MAX - Metamorphosis Ready)")
    else
        panel.XPBar.Text:SetText(string.format("Attunement: %d / %d to Rank %s", curPts, reqPts, C.ATTUNEMENT_RANKS[rankData.rank + 1] and C.ATTUNEMENT_RANKS[rankData.rank + 1].roman or "V"))
    end

    panel.StatSummary:SetText(string.format("ATK: |cffffaa00%d|r   DEF: |cff3399ff%d|r   SPD: |cff00ff99%d|r  (%.2fx Stats)",
        mob.atk or 10, mob.def or 8, mob.spd or 12, rankData.statMult or 1.0))
    panel.BattleRecord:SetText(string.format("Battle Record: |cff00ff00%dW|r / |cffff4444%dL|r   Disobedience: |cffffaa00%d%%|r",
        mob.battlesWon or 0, (mob.battlesTotal or 0) - (mob.battlesWon or 0), math.floor(rankData.disobedience * 100)))

    panel.PassiveText:SetText(string.format("|cffffd100Rank Perk:|r |cffffffff%s|r", rankData.desc or ""))
    panel.MatchupText:SetText(string.format("|cff00ff00Strong vs:|r %s (150%%)   |cffff4444Weak vs:|r %s (Takes 150%%)", typeInfo.strongAgainst or "-", typeInfo.weakAgainst or "-"))

    local capacity = rankData.moveSlots or 1
    for i = 1, 4 do
        local mCard = panel.MoveCards[i]
        if i > capacity then
            mCard.Icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
            mCard.Name:SetText(string.format("|cff666666Slot %d Locked|r", i))
            local reqRoman = (i == 2 and "II" or (i == 3 and "III" or "IV"))
            mCard.Info:SetText(string.format("|cff888888Unlocks Rank %s|r", reqRoman))
            mCard:Show()
        else
            local moveKey = mob.abilities and mob.abilities[i]
            if moveKey and C.ABILITIES[moveKey] then
                local move = C.ABILITIES[moveKey]
                mCard.Icon:SetTexture(move.icon)
                mCard.Name:SetText(string.format("|cffffffff%s|r", move.name))
                local cdInfo = (move.cooldown and move.cooldown > 0) and string.format("CD: %dt", move.cooldown) or "Instant"
                local useInfo = (move.maxUses) and string.format("Uses: %d", move.maxUses) or "Pwr: " .. (move.power or 0)
                mCard.Info:SetText(string.format("%s | %s", cdInfo, useInfo))
                mCard:Show()
            else
                mCard.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                mCard.Name:SetText("|cff00ff99[+ Teach]|r")
                mCard.Info:SetText("|cffaaaaaaClick to train|r")
                mCard:Show()
            end
        end
    end

    if panel.SetActiveBtn then
        local inTeamSlot = nil
        for idx, id in ipairs(ForeverSafariDB.team or {}) do
            if id == mob.id then
                inTeamSlot = idx
                break
            end
        end
        local activeSlot = ForeverSafariDB.activeSlot or 1
        if inTeamSlot and inTeamSlot == activeSlot then
            panel.SetActiveBtn:SetText("|cff00ff00[Active Leader]|r")
            panel.SetActiveBtn:Disable()
        elseif inTeamSlot then
            panel.SetActiveBtn:SetText(string.format("Make Leader (Slot %d)", inTeamSlot))
            panel.SetActiveBtn:Enable()
        else
            panel.SetActiveBtn:SetText("+ Add to Party")
            panel.SetActiveBtn:Enable()
        end
    end
end

-- =========================================================================
-- VIEW 4: FIELD DIRECTIVES & BOUNTIES LOG
-- =========================================================================
local selectedBountyId = 1
local bountyButtons = {}

function Journal:BuildBountiesView(parent)
    -- Left Column: Directives List
    local leftPanel = Theme:CreateCard(parent, 250, 480)
    leftPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    parent.LeftPanel = leftPanel

    local listTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    listTitle:SetPoint("TOPLEFT", 12, -10)
    listTitle:SetText("|cffffd100Field Directives|r")

    local listSub = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listSub:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -2)
    listSub:SetText("Nesingwary Research Quests")
    listSub:SetTextColor(0.7, 0.75, 0.8)

    local scrollFrame = CreateFrame("ScrollFrame", "ForeverSafariBountiesScrollFrame", leftPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 6, -38)
    scrollFrame:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -26, 8)

    local listContent = CreateFrame("Frame", "ForeverSafariBountiesListContent", scrollFrame)
    listContent:SetSize(210, 440)
    scrollFrame:SetScrollChild(listContent)
    parent.ListContent = listContent

    local dispatches = C.NESINGWARY_DISPATCHES or {}
    for i, dispatch in ipairs(dispatches) do
        local btn = CreateFrame("Button", nil, listContent, "BackdropTemplate")
        btn:SetSize(210, 68)
        btn:SetPoint("TOPLEFT", 4, -((i - 1) * 74))
        btn.bountyId = dispatch.id

        Theme:ApplyCardBackdrop(btn)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("LEFT", 8, 0)
        icon:SetTexture(dispatch.icon or "Interface\\Icons\\INV_Box_01")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.Icon = icon

        local title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -4)
        title:SetPoint("RIGHT", -6, 0)
        title:SetJustifyH("LEFT")
        title:SetText(dispatch.title)
        btn.Title = title

        local status = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        status:SetPoint("RIGHT", -6, 0)
        status:SetJustifyH("LEFT")
        status:SetText("|cffaaaaaaIn Progress|r")
        btn.Status = status

        btn:SetScript("OnClick", function(self)
            selectedBountyId = self.bountyId
            Journal:UpdateBountiesView()
            PlaySound(856)
        end)

        bountyButtons[i] = btn
    end

    -- Right Column: Directive Dossier, Progress & Mailbox Instructions
    local rightPanel = Theme:CreateCard(parent, 556, 480)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 6, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    parent.RightPanel = rightPanel

    local crest = rightPanel:CreateTexture(nil, "ARTWORK")
    crest:SetSize(36, 36)
    crest:SetPoint("TOPRIGHT", -12, -10)
    crest:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
    crest:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    rightPanel.Crest = crest

    local docTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    docTitle:SetPoint("TOPLEFT", 14, -10)
    docTitle:SetPoint("TOPRIGHT", crest, "TOPLEFT", -10, 0)
    docTitle:SetJustifyH("LEFT")
    rightPanel.DocTitle = docTitle

    local senderText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    senderText:SetPoint("TOPLEFT", docTitle, "BOTTOMLEFT", 0, -4)
    rightPanel.SenderText = senderText

    -- Lore & Directive Description Scroll
    local descScroll = CreateFrame("ScrollFrame", nil, rightPanel, "UIPanelScrollFrameTemplate")
    descScroll:SetPoint("TOPLEFT", 14, -58)
    descScroll:SetPoint("BOTTOMRIGHT", -28, 200)

    local descContent = CreateFrame("Frame", nil, descScroll)
    descContent:SetSize(500, 200)
    descScroll:SetScrollChild(descContent)

    local bodyText = descContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bodyText:SetPoint("TOPLEFT", 0, 0)
    bodyText:SetPoint("TOPRIGHT", 0, 0)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetTextColor(0.88, 0.90, 0.92)
    rightPanel.BodyText = bodyText
    rightPanel.DescContent = descContent

    -- Objectives & Progress Card
    local objCard = Theme:CreateCard(rightPanel, 528, 108)
    objCard:SetPoint("BOTTOMLEFT", 14, 82)
    objCard:SetPoint("BOTTOMRIGHT", -14, 82)
    rightPanel.ObjCard = objCard

    local objHeader = objCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    objHeader:SetPoint("TOPLEFT", 10, -8)
    objHeader:SetText("|cffffd100Directive Objective:|r")
    objCard.Header = objHeader

    local objSummary = objCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    objSummary:SetPoint("TOPLEFT", objHeader, "BOTTOMLEFT", 0, -4)
    objSummary:SetPoint("RIGHT", -10, 0)
    objSummary:SetJustifyH("LEFT")
    objCard.Summary = objSummary

    local pBar = CreateFrame("StatusBar", nil, objCard)
    pBar:SetSize(320, 16)
    pBar:SetPoint("TOPLEFT", objSummary, "BOTTOMLEFT", 0, -6)
    pBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    pBar:SetStatusBarColor(0.0, 0.8, 0.4)
    objCard.ProgressBar = pBar

    local pBarBg = pBar:CreateTexture(nil, "BACKGROUND")
    pBarBg:SetAllPoints(pBar)
    pBarBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    pBarBg:SetVertexColor(0.1, 0.15, 0.2, 0.8)

    local pBarText = pBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pBarText:SetPoint("CENTER", 0, 0)
    objCard.ProgressText = pBarText

    local rewardText = objCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rewardText:SetPoint("TOPLEFT", pBar, "BOTTOMLEFT", 0, -6)
    rewardText:SetPoint("RIGHT", -10, 0)
    rewardText:SetJustifyH("LEFT")
    objCard.RewardText = rewardText

    -- Physical Town Mailbox Notice Box
    local noticeBox = Theme:CreateCard(rightPanel, 528, 64)
    noticeBox:SetPoint("BOTTOMLEFT", 14, 10)
    noticeBox:SetPoint("BOTTOMRIGHT", -14, 10)
    noticeBox:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.8)

    local noticeIcon = noticeBox:CreateTexture(nil, "ARTWORK")
    noticeIcon:SetSize(28, 28)
    noticeIcon:SetPoint("LEFT", 10, 0)
    noticeIcon:SetTexture("Interface\\Icons\\INV_Letter_15")
    noticeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local noticeTitle = noticeBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noticeTitle:SetPoint("TOPLEFT", noticeIcon, "TOPRIGHT", 8, 2)
    noticeTitle:SetText("|cffffd100📬 Physical Town Mailbox Required For Rewards & Letters|r")

    local noticeDesc = noticeBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noticeDesc:SetPoint("TOPLEFT", noticeTitle, "BOTTOMLEFT", 0, -2)
    noticeDesc:SetPoint("RIGHT", -10, 0)
    noticeDesc:SetJustifyH("LEFT")
    noticeDesc:SetText("|cffaaaaaaCompleted bounties and newly delivered dispatches are unboxed at an authentic Mailbox in town. Visit any town inn to collect your rewards!|r")
end

function Journal:UpdateBountiesView()
    local dispatches = C.NESINGWARY_DISPATCHES or {}
    local currentDispatch = dispatches[selectedBountyId] or dispatches[1]

    -- Update List Cards
    for i, btn in ipairs(bountyButtons) do
        local dispatch = dispatches[i]
        if dispatch then
            local isClaimed = DB:IsQuestClaimed(dispatch.id)
            local progress = DB:GetQuestProgress(dispatch.questType)
            local target = dispatch.targetCount or 1

            if dispatch.isStarter then
                if DB:IsStarterClaimed() then
                    btn.Status:SetText("|cff00ff00[Commission Active]|r")
                else
                    btn.Status:SetText("|cffffd100[Mailbox Parcel Waiting]|r")
                end
            else
                if isClaimed then
                    btn.Status:SetText("|cffaaaaaa[Bounty Completed]|r")
                elseif progress >= target then
                    btn.Status:SetText("|cff00ff99[✔ Ready for Mailbox Turn-In]|r")
                else
                    btn.Status:SetText(string.format("|cffffcc00[Progress: %d / %d]|r", progress, target))
                end
            end

            if dispatch.id == selectedBountyId then
                btn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                btn:SetBackdropColor(0.12, 0.18, 0.24, 0.95)
            else
                btn:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.6)
                btn:SetBackdropColor(0.08, 0.10, 0.14, 0.8)
            end
        end
    end

    -- Update Dossier Content
    local right = frame.BountiesContainer.RightPanel
    if not right or not currentDispatch then return end

    right.DocTitle:SetText(currentDispatch.title)
    right.SenderText:SetText(string.format("|cffaaaaaaFrom: %s (%s)|r", currentDispatch.sender, currentDispatch.location or "Expedition HQ"))
    right.BodyText:SetText(currentDispatch.body or "")
    right.DescContent:SetHeight(right.BodyText:GetStringHeight() + 20)

    local objCard = right.ObjCard
    objCard.Summary:SetText(currentDispatch.summary or "Field Research Task")

    if currentDispatch.isStarter then
        objCard.ProgressBar:SetMinMaxValues(0, 1)
        if DB:IsStarterClaimed() then
            objCard.ProgressBar:SetValue(1)
            objCard.ProgressBar:SetStatusBarColor(0.0, 0.8, 0.4)
            objCard.ProgressText:SetText("Commission Active — Starter Companion Unboxed")
            objCard.RewardText:SetText("|cff00ff00Starter crate collected from town mailbox.|r")
        else
            objCard.ProgressBar:SetValue(0)
            objCard.ProgressBar:SetStatusBarColor(1.0, 0.6, 0.0)
            objCard.ProgressText:SetText("0 / 1 — Parcel Waiting at Town Mailbox")
            objCard.RewardText:SetText("|cffffd100Rewards Waiting:|r Racial Starter Companion + 5x Copper Safari Nets")
        end
    else
        local progress = DB:GetQuestProgress(currentDispatch.questType)
        local target = currentDispatch.targetCount or 1
        local isClaimed = DB:IsQuestClaimed(currentDispatch.id)

        objCard.ProgressBar:SetMinMaxValues(0, target)
        objCard.ProgressBar:SetValue(math.min(progress, target))

        if isClaimed then
            objCard.ProgressBar:SetStatusBarColor(0.5, 0.5, 0.5)
            objCard.ProgressText:SetText(string.format("%d / %d (Bounty Completed & Claimed)", target, target))
            objCard.RewardText:SetText("|cffaaaaaaRewards already collected from town mailbox.|r")
        elseif progress >= target then
            objCard.ProgressBar:SetStatusBarColor(0.0, 1.0, 0.4)
            objCard.ProgressText:SetText(string.format("|cff00ff00%d / %d (Objective Complete! Ready to Turn In)|r", progress, target))
            objCard.RewardText:SetText(string.format("|cff00ff00Turn-In Reward:|r +%d Safari Tokens, Supplies (Claim at Mailbox)", currentDispatch.rewards and currentDispatch.rewards.tokens or 0))
        else
            objCard.ProgressBar:SetStatusBarColor(0.0, 0.7, 1.0)
            objCard.ProgressText:SetText(string.format("%d / %d (%d%%)", progress, target, math.floor((progress / target) * 100)))
            objCard.RewardText:SetText(string.format("|cffffd100Bounty Rewards:|r +%d Safari Tokens, Nets & Treats (Claim at Mailbox)", currentDispatch.rewards and currentDispatch.rewards.tokens or 0))
        end
    end
end

function Journal:UpdateTeamDock()
    local team = DB:GetTeam()
    local activeSlot = ForeverSafariDB.activeSlot or 1

    for i = 1, 4 do
        local slot = frame.TeamSlots[i]
        local mob = team[i]
        if mob then
            local displayId = (mob.displayId and mob.displayId > 0) and mob.displayId or C.GetDefaultDisplayId(mob.creatureType, mob.name)
            SetModelCreature(slot.Model3D, displayId)
            slot.Model3D:Show()

            slot.Name:SetText(string.format("Lv %d %s", mob.level, mob.nickname ~= "" and mob.nickname or mob.name))
            slot.HP:SetText(string.format("%d/%d HP", mob.currentHP, mob.maxHP))

            if i == activeSlot then
                slot:SetBackdropBorderColor(0, 1, 0.6, 1)
            else
                slot:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)
            end
        else
            slot.Model3D:Hide()
            slot.Name:SetText("|cff666666Empty Slot|r")
            slot.HP:SetText("-")
            slot:SetBackdropBorderColor(0.15, 0.2, 0.25, 0.5)
        end
    end
end

function Journal:UpdateUI()
    if not frame or not frame:IsShown() then return end
    if frame.Header then frame.Header:UpdateTokens() end

    if currentTab == "SHOWCASE" then
        Journal:UpdateList()
        Journal:UpdateShowcase()
    elseif currentTab == "GRID" then
        Journal:UpdateGridView()
    elseif currentTab == "BESTIARY" then
        Journal:UpdateBestiaryView()
    elseif currentTab == "BOUNTIES" then
        Journal:UpdateBountiesView()
    end

    Journal:UpdateTeamDock()
end

function Journal:ShowJournal()
    if not frame then Journal:Initialize() end
    frame:Show()
    Journal:UpdateUI()
    PlaySound(844)
end

function Journal:Toggle()
    if not frame then Journal:Initialize() end
    if frame:IsShown() then
        frame:Hide()
    else
        Journal:ShowJournal()
    end
end

function Journal:IsShown()
    return frame and frame:IsShown()
end
