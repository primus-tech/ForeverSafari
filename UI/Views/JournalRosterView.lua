--[[
    Forever Safari: View 1 - Squad Roster & 3D Spotlight (JournalRosterView.lua)
    Renders the single-companion 3D paperdoll spotlight stage with fluid mouse rotation,
    zoom, animation triggers, and actionable companion dossier (stats, moves, feeding tray).
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.JournalFrame = ns.JournalFrame or {}

local Journal = ns.JournalFrame
local Theme = ns.Theme
local DB = ns.Database
local C = ns.Constants

local selectedMobId = nil
local rosterSearchQuery = ""
local rosterListButtons = {}

function Journal:GetSelectedCompanion()
    if selectedMobId then
        local mob = DB:GetMobById(selectedMobId)
        if mob then return mob end
    end
    return DB:GetActiveMob() or (DB:GetCollection()[1])
end

function Journal:SelectCompanion(mobId)
    selectedMobId = mobId
    self:UpdateRosterView()
end

function Journal:BuildRosterView(parent)
    -- =========================================================================
    -- 1. LEFT COLUMN: COMPANION LIST & SQUAD SELECTOR
    -- =========================================================================
    local leftPanel = Theme:CreateCard(parent, 220, 480)
    leftPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    parent.LeftPanel = leftPanel

    local searchBg = CreateFrame("Frame", nil, leftPanel, "BackdropTemplate")
    searchBg:SetSize(200, 22)
    searchBg:SetPoint("TOPLEFT", 10, -10)
    Theme:ApplyCardBackdrop(searchBg)

    local searchBox = CreateFrame("EditBox", "ForeverSafariRosterSearchBox", searchBg)
    searchBox:SetSize(186, 18)
    searchBox:SetPoint("LEFT", 6, 0)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox:SetAutoFocus(false)

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 0, 0)
    searchPlaceholder:SetText("🔍 Filter squad & collection...")
    searchBox.Placeholder = searchPlaceholder

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        rosterSearchQuery = string.lower(strtrim(text))
        if rosterSearchQuery == "" then
            self.Placeholder:Show()
        else
            self.Placeholder:Hide()
        end
        Journal:UpdateRosterList()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    local scroll = CreateFrame("ScrollFrame", "ForeverSafariRosterScroll", leftPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", searchBg, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(180, 500)
    scroll:SetScrollChild(content)
    leftPanel.Content = content
    leftPanel.Scroll = scroll

    -- =========================================================================
    -- 2. CENTER COLUMN: SINGLE 3D PAPERDOLL SPOTLIGHT STAGE
    -- =========================================================================
    local centerStage = Theme:CreateCard(parent, 300, 480)
    centerStage:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 8, 0)
    parent.CenterStage = centerStage

    local stageTitle = centerStage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stageTitle:SetPoint("TOP", centerStage, "TOP", 0, -10)
    stageTitle:SetText("|cffffd100🐾 Squad Spotlight|r")
    centerStage.Title = stageTitle

    -- Luminous Pedestal Ground
    local pedestal = centerStage:CreateTexture(nil, "BACKGROUND")
    pedestal:SetSize(240, 56)
    pedestal:SetPoint("CENTER", centerStage, "CENTER", 0, -50)
    pedestal:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    pedestal:SetVertexColor(0.12, 0.28, 0.22, 0.85)
    centerStage.Pedestal = pedestal

    -- Primary Single-Pet 3D Model
    local mainModel = CreateFrame("PlayerModel", "ForeverSafariRoster3DModel", centerStage)
    mainModel:SetSize(280, 290)
    mainModel:SetPoint("BOTTOM", pedestal, "CENTER", 0, -20)
    mainModel:EnableMouse(true)
    mainModel:EnableMouseWheel(true)

    -- Mouse Drag Rotation & Zoom Controls
    local isDragging = false
    local prevMouseX = 0
    mainModel:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isDragging = true
            prevMouseX = GetCursorPosition()
        end
    end)
    mainModel:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            isDragging = false
        end
    end)
    mainModel:SetScript("OnUpdate", function(self)
        if isDragging then
            local currentX = GetCursorPosition()
            local delta = (currentX - prevMouseX) * 0.015
            prevMouseX = currentX
            local facing = self:GetFacing() or 0
            self:SetFacing(facing + delta)
        end
    end)
    mainModel:SetScript("OnMouseWheel", function(self, delta)
        local curScale = self.modelScale or 1.0
        curScale = math.max(0.5, math.min(2.5, curScale + (delta * 0.1)))
        self.modelScale = curScale
        if self.SetModelScale then
            self:SetModelScale(curScale)
        end
    end)
    centerStage.Model3D = mainModel

    -- 3D Action & Animation Controls Bar
    local animCard = Theme:CreateCard(centerStage, 280, 36)
    animCard:SetPoint("BOTTOM", centerStage, "BOTTOM", 0, 8)

    local btnRotL = Theme:CreateButton(animCard, 32, 22, "◄")
    btnRotL:SetPoint("LEFT", 6, 0)
    btnRotL:SetScript("OnClick", function()
        local facing = mainModel:GetFacing() or 0
        mainModel:SetFacing(facing - 0.4)
        PlaySound(856)
    end)

    local btnRotR = Theme:CreateButton(animCard, 32, 22, "►")
    btnRotR:SetPoint("LEFT", btnRotL, "RIGHT", 4, 0)
    btnRotR:SetScript("OnClick", function()
        local facing = mainModel:GetFacing() or 0
        mainModel:SetFacing(facing + 0.4)
        PlaySound(856)
    end)

    local btnAtk = Theme:CreateButton(animCard, 48, 22, "Attack")
    btnAtk:SetPoint("LEFT", btnRotR, "RIGHT", 6, 0)
    btnAtk:SetScript("OnClick", function()
        if mainModel.SetAnimation then mainModel:SetAnimation(16) end
        PlaySound(856)
    end)

    local btnRoar = Theme:CreateButton(animCard, 46, 22, "Roar")
    btnRoar:SetPoint("LEFT", btnAtk, "RIGHT", 4, 0)
    btnRoar:SetScript("OnClick", function()
        if mainModel.SetAnimation then mainModel:SetAnimation(26) end
        PlaySound(856)
    end)

    local btnVic = Theme:CreateButton(animCard, 46, 22, "Victory")
    btnVic:SetPoint("LEFT", btnRoar, "RIGHT", 4, 0)
    btnVic:SetScript("OnClick", function()
        if mainModel.SetAnimation then mainModel:SetAnimation(4) end
        PlaySound(856)
    end)

    -- =========================================================================
    -- 3. RIGHT COLUMN: ACTIONABLE COMPANION DOSSIER PANEL
    -- =========================================================================
    local rightPanel = Theme:CreateCard(parent, 272, 480)
    rightPanel:SetPoint("TOPLEFT", centerStage, "TOPRIGHT", 8, 0)
    parent.RightPanel = rightPanel

    -- Nickname EditBox & Save Button
    local nameEdit = CreateFrame("EditBox", "ForeverSafariNicknameEdit", rightPanel, "BackdropTemplate")
    nameEdit:SetSize(180, 24)
    nameEdit:SetPoint("TOPLEFT", 12, -12)
    nameEdit:SetFontObject("GameFontHighlightLarge")
    nameEdit:SetAutoFocus(false)
    nameEdit:SetMaxLetters(16)
    Theme:ApplyCardBackdrop(nameEdit)
    nameEdit:SetTextInsets(6, 6, 0, 0)
    rightPanel.NameEdit = nameEdit

    local renameBtn = Theme:CreateButton(rightPanel, 64, 24, "Save")
    renameBtn:SetPoint("LEFT", nameEdit, "RIGHT", 6, 0)
    renameBtn:SetScript("OnClick", function()
        local mob = Journal:GetSelectedCompanion()
        if mob then
            local success, msg = DB:SetMobNickname(mob.id, nameEdit:GetText())
            if msg then
                DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[Forever Safari]|r " .. msg)
            end
            Journal:UpdateRosterView()
            PlaySound(856)
        end
    end)

    -- Attunement Loyalty Progress Bar
    local attunementHeader = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    attunementHeader:SetPoint("TOPLEFT", nameEdit, "BOTTOMLEFT", 0, -6)
    attunementHeader:SetText("Attunement Loyalty: |cffffd100Rank I|r")
    rightPanel.AttunementHeader = attunementHeader

    local attunementBar = CreateFrame("StatusBar", nil, rightPanel)
    attunementBar:SetSize(250, 10)
    attunementBar:SetPoint("TOPLEFT", attunementHeader, "BOTTOMLEFT", 0, -4)
    attunementBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    attunementBar:SetStatusBarColor(1.0, 0.82, 0.0)
    local attBg = attunementBar:CreateTexture(nil, "BACKGROUND")
    attBg:SetAllPoints()
    attBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    local attText = attunementBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    attText:SetPoint("CENTER", 0, 0)
    attunementBar.Text = attText
    rightPanel.AttunementBar = attunementBar

    -- HP Bar
    local hpBar = CreateFrame("StatusBar", nil, rightPanel)
    hpBar:SetSize(250, 10)
    hpBar:SetPoint("TOPLEFT", attunementBar, "BOTTOMLEFT", 0, -6)
    hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hpBar:SetStatusBarColor(0.2, 0.8, 0.2)
    local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    local hpText = hpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hpText:SetPoint("CENTER", 0, 0)
    hpBar.Text = hpText
    rightPanel.HPBar = hpBar

    -- 4 Core Combat Stats Card (HP, ATK, DEF, SPD)
    local statsCard = Theme:CreateCard(rightPanel, 250, 48)
    statsCard:SetPoint("TOPLEFT", hpBar, "BOTTOMLEFT", 0, -6)
    rightPanel.StatsCard = statsCard

    local statSummary = statsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statSummary:SetPoint("TOPLEFT", 8, -6)
    statSummary:SetText("HP [ 60 ]  ATK [ 16 ]  DEF [ 12 ]  SPD [ 14 ]")
    rightPanel.StatSummary = statSummary

    local passiveText = statsCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    passiveText:SetPoint("TOPLEFT", statSummary, "BOTTOMLEFT", 0, -3)
    passiveText:SetText("|cff00ff99Passive:|r Enrage (+25% ATK < 50% HP)")
    rightPanel.PassiveText = passiveText

    -- Active Moveset (4 Clickable Slots)
    local movesHeader = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    movesHeader:SetPoint("TOPLEFT", statsCard, "BOTTOMLEFT", 0, -8)
    movesHeader:SetText("|cffffd100Active Moveset|r |cff888888(Click to Train)|r")

    rightPanel.MoveCards = {}
    for i = 1, 4 do
        local mCard = CreateFrame("Button", nil, rightPanel, "BackdropTemplate")
        mCard:SetSize(122, 38)
        local col = ((i - 1) % 2)
        local row = math.floor((i - 1) / 2)
        mCard:SetPoint("TOPLEFT", movesHeader, "BOTTOMLEFT", col * 128, -4 - (row * 42))
        mCard.slotIndex = i
        Theme:ApplyCardBackdrop(mCard)

        local mIcon = mCard:CreateTexture(nil, "ARTWORK")
        mIcon:SetSize(24, 24)
        mIcon:SetPoint("LEFT", 4, 0)
        mIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        mCard.Icon = mIcon

        local mName = mCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mName:SetPoint("TOPLEFT", mIcon, "TOPRIGHT", 4, -2)
        mName:SetPoint("TOPRIGHT", -2, -2)
        mName:SetJustifyH("LEFT")
        mCard.Name = mName

        local mInfo = mCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mInfo:SetPoint("TOPLEFT", mName, "BOTTOMLEFT", 0, -1)
        mInfo:SetPoint("TOPRIGHT", -2, -1)
        mInfo:SetJustifyH("LEFT")
        mCard.Info = mInfo

        mCard:SetScript("OnClick", function(self)
            Journal:OpenTrainingDrawer(self.slotIndex)
            PlaySound(856)
        end)
        mCard:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        end)
        mCard:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)
        end)

        rightPanel.MoveCards[i] = mCard
    end

    -- Direct Nourishment Feeding Tray
    local feedCard = Theme:CreateCard(rightPanel, 250, 48)
    feedCard:SetPoint("BOTTOM", rightPanel, "BOTTOM", 0, 8)
    rightPanel.FeedCard = feedCard

    local feedTitle = feedCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    feedTitle:SetPoint("TOPLEFT", 8, -5)
    feedTitle:SetText("|cffffd100Favorite Sustenance:|r Wolf Meat")
    rightPanel.FeedTitle = feedTitle

    local feedBtn = Theme:CreateButton(feedCard, 234, 20, "Feed Nourishment (+25 Attunement)")
    feedBtn:SetPoint("BOTTOM", 0, 4)
    feedBtn:SetScript("OnClick", function()
        local mob = Journal:GetSelectedCompanion()
        if mob then
            local diet = ns.ItemDB and ns.ItemDB:GetFamilyDiet(mob.family)
            local itemKey = diet and diet.item or "Wolf Flank"
            local success, isFav = DB:FeedCompanion(mob.id, itemKey)
            if success then
                if ns.Toast and ns.Toast.ShowReward then
                    ns.Toast:ShowReward("Nourished!", string.format("%s enjoyed %s (+%d Attunement)", mob.customNickname or mob.name, itemKey, isFav and 25 or 15))
                end
                Journal:UpdateRosterView()
                PlaySound(856)
            end
        end
    end)
    rightPanel.FeedBtn = feedBtn
end

function Journal:UpdateRosterList()
    local frame = self.Frame
    if not frame or not frame.RosterContainer then return end
    local leftPanel = frame.RosterContainer.LeftPanel
    if not leftPanel then return end

    local content = leftPanel.Content
    local collection = DB:GetCollection()
    local team = DB:GetTeam()
    local selected = self:GetSelectedCompanion()

    -- Filter list by query
    local filtered = {}
    for _, mob in ipairs(collection) do
        if rosterSearchQuery == "" then
            table.insert(filtered, mob)
        else
            local nameMatch = string.find(string.lower(mob.name or ""), rosterSearchQuery, 1, true)
            local nickMatch = string.find(string.lower(mob.customNickname or ""), rosterSearchQuery, 1, true)
            local famMatch = string.find(string.lower(mob.family or ""), rosterSearchQuery, 1, true)
            if nameMatch or nickMatch or famMatch then
                table.insert(filtered, mob)
            end
        end
    end

    -- Hide all existing buttons
    for _, btn in ipairs(rosterListButtons) do
        btn:Hide()
    end

    local yOffset = 0
    for i, mob in ipairs(filtered) do
        local btn = rosterListButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, content, "BackdropTemplate")
            btn:SetSize(180, 42)
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
                Journal:SelectCompanion(self.mobId)
                PlaySound(856)
            end)

            rosterListButtons[i] = btn
        end

        btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
        btn.mobId = mob.id

        local inSquad = DB:IsMobInSquad(mob.id)
        local squadTag = inSquad and " |cffffd100[Squad]|r" or ""
        btn.Title:SetText((mob.customNickname or mob.name) .. squadTag)
        btn.Sub:SetText(string.format("Rank %s | %s", mob.attunementRank or 1, mob.family or "Beast"))

        local iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Wolf"
        if mob.family == "Feline" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Cat"
        elseif mob.family == "Bear" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Bear"
        elseif mob.family == "Boar" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Boar"
        elseif mob.family == "Raptor" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Raptor"
        elseif mob.family == "Mechanical" then iconPath = "Interface\\Icons\\INV_Misc_EngGizmos_17"
        elseif mob.family == "Undead" then iconPath = "Interface\\Icons\\Spell_Shadow_DeadofNight"
        elseif mob.family == "Elemental" then iconPath = "Interface\\Icons\\Spell_Fire_Elemental_Totem"
        end
        btn.Icon:SetTexture(iconPath)

        if selected and selected.id == mob.id then
            btn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
            btn:SetBackdropColor(0.18, 0.15, 0.08, 0.95)
        else
            btn:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)
            btn:SetBackdropColor(0.12, 0.16, 0.22, 0.85)
        end

        btn:Show()
        yOffset = yOffset - 46
    end

    content:SetHeight(math.max(450, math.abs(yOffset) + 10))
end

function Journal:UpdateRosterView()
    local frame = self.Frame
    if not frame or not frame.RosterContainer then return end
    local container = frame.RosterContainer
    if not container:IsShown() then return end

    local mob = self:GetSelectedCompanion()
    self:UpdateRosterList()
    self:UpdateTeamDock()

    if not mob then return end

    -- Update Center 3D Spotlight Stage
    local centerStage = container.CenterStage
    if centerStage and centerStage.Model3D then
        centerStage.Model3D:Show()
        centerStage.Model3D:SetDisplayInfo(mob.displayId or 903)
        centerStage.Model3D:SetRotation(math.rad(15))
    end

    -- Update Right Dossier Panel
    local rPanel = container.RightPanel
    if not rPanel then return end

    rPanel.NameEdit:SetText(mob.customNickname or mob.name or "Companion")

    local rank = mob.attunementRank or 1
    local rankInfo = C.ATTUNEMENT_RANKS and C.ATTUNEMENT_RANKS[rank] or { title = "Wild", maxPoints = 250, roman = "I" }
    rPanel.AttunementHeader:SetText(string.format("Attunement: |cffffd100Rank %s (%s)|r", rankInfo.roman or rank, rankInfo.title or "Wild"))

    local curPts = mob.attunementPoints or 0
    local maxPts = rankInfo.maxPoints or 250
    rPanel.AttunementBar:SetMinMaxValues(0, maxPts)
    rPanel.AttunementBar:SetValue(math.min(curPts, maxPts))
    rPanel.AttunementBar.Text:SetText(string.format("%d / %d Loyalty", curPts, maxPts))

    local curHP = mob.currentHP or mob.hp or 60
    local maxHP = mob.maxHP or mob.hp or 60
    rPanel.HPBar:SetMinMaxValues(0, maxHP)
    rPanel.HPBar:SetValue(curHP)
    rPanel.HPBar.Text:SetText(string.format("Health: %d / %d", curHP, maxHP))

    local atk = mob.attack or mob.atk or 16
    local def = mob.defense or mob.def or 12
    local spd = mob.speed or mob.spd or 14
    rPanel.StatSummary:SetText(string.format("HP [ |cff33ff33%d|r ]  ATK [ |cffffaa00%d|r ]  DEF [ |cff3399ff%d|r ]  SPD [ |cff00ff99%d|r ]", maxHP, atk, def, spd))

    -- Update Active Move Cards
    local MoveDB = ns.MoveDB or {}
    for i = 1, 4 do
        local mCard = rPanel.MoveCards[i]
        local moveId = mob.moves and mob.moves[i]
        local move = moveId and (MoveDB[moveId] or (C.ABILITIES and C.ABILITIES[moveId]))

        if move then
            mCard.Icon:SetTexture(move.icon or "Interface\\Icons\\Ability_GhoulFrenzy")
            mCard.Name:SetText(move.name)
            local pwrText = (move.power and move.power > 0) and string.format("Pwr %d", move.power) or "Status"
            mCard.Info:SetText(pwrText)
            mCard:Show()
        else
            mCard.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            mCard.Name:SetText("|cff666666(Empty)|r")
            mCard.Info:SetText("Click to teach")
            mCard:Show()
        end
    end

    -- Update Feeding Tray
    local diet = ns.ItemDB and ns.ItemDB:GetFamilyDiet(mob.family)
    rPanel.FeedTitle:SetText(string.format("|cffffd100Favorite Sustenance:|r %s", diet and diet.item or "Fresh Meat"))
end
