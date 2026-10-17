--[[
    Forever Safari: Field Guide Journal & 3D Paperdoll Showcase (JournalFrame.lua)
    Modular master window frame shell and view router.
    Deconstructed into sub-views and components:
      - UI/Components/JournalTeamDock.lua
      - UI/Components/JournalTrainingDrawer.lua
      - UI/Views/JournalRosterView.lua
      - UI/Views/JournalGridView.lua
      - UI/Views/JournalBestiaryView.lua
      - UI/Views/JournalBountiesView.lua
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.JournalFrame = ns.JournalFrame or {}

local Journal = ns.JournalFrame
local C = ns.Constants
local DB = ns.Database
local Theme = ns.Theme

local frame = nil
local currentTab = "ROSTER" -- "ROSTER", "GRID", "BESTIARY", "BOUNTIES"

-- =========================================================================
-- SHARED 3D MODEL UTILITIES
-- =========================================================================
function Journal:SetModelCreature(modelFrame, displayId, npcId)
    if not modelFrame then return end
    if modelFrame.ClearModel then pcall(modelFrame.ClearModel, modelFrame) end
    local loaded = false
    if displayId and displayId > 0 then
        if modelFrame.SetDisplayInfo then
            local ok = pcall(modelFrame.SetDisplayInfo, modelFrame, displayId)
            if ok then loaded = true end
        elseif modelFrame.SetCreatureByDisplayID then
            local ok = pcall(modelFrame.SetCreatureByDisplayID, modelFrame, displayId)
            if ok then loaded = true end
        end
    end
    if not loaded and npcId and npcId > 0 and modelFrame.SetCreature then
        local ok = pcall(modelFrame.SetCreature, modelFrame, npcId)
        if ok then loaded = true end
    end
    if not loaded and not displayId and not npcId then return end

    local function applyModelTransforms(mf)
        pcall(function()
            if mf.SetCustomCamera then mf:SetCustomCamera(0) end
            if mf.SetPortraitZoom then mf:SetPortraitZoom(0) end
            if mf.SetCamDistanceScale then mf:SetCamDistanceScale(1.0) end
            if mf.SetModelScale then mf:SetModelScale(mf.zoom or 1.0) end
            if mf.SetRotation then mf:SetRotation(mf.rotation or math.rad(25)) end
            if mf.SetAnimation then mf:SetAnimation(0) end
        end)
    end

    if modelFrame.SetScript and not modelFrame._hasModelLoadedHook then
        modelFrame._hasModelLoadedHook = true
        modelFrame:HookScript("OnModelLoaded", function(self)
            applyModelTransforms(self)
        end)
    end
    applyModelTransforms(modelFrame)
end

function Journal:Setup3DModelInteractions(modelFrame)
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

-- =========================================================================
-- INITIALIZATION
-- =========================================================================
function Journal:Initialize()
    if frame then return end

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
    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetSize(540, 28)
    tabContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -38)
    frame.TabContainer = tabContainer

    local tabs = {
        { id = "ROSTER",   text = "3D Spotlight", width = 116 },
        { id = "GRID",     text = "3D Gallery",   width = 116 },
        { id = "BESTIARY", text = "Bestiary",     width = 116 },
        { id = "BOUNTIES", text = "Directives",   width = 116 },
        { id = "BADGES",   text = "Badges & Licenses", width = 138 },
    }

    frame.TabButtons = {}
    local currentLeft = 0
    for i, tabInfo in ipairs(tabs) do
        local btnWidth = tabInfo.width or 120
        local btn = CreateFrame("Button", nil, tabContainer, "BackdropTemplate")
        btn:SetSize(btnWidth, 24)
        btn:SetPoint("LEFT", tabContainer, "LEFT", currentLeft, 0)
        currentLeft = currentLeft + btnWidth + 4
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

    -- Top Right Quick Access Button (Safari Bag)
    local bagBtn = CreateFrame("Button", "ForeverSafariJournalBagBtn", frame, "BackdropTemplate")
    bagBtn:SetSize(114, 24)
    bagBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -38)
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
        GameTooltip:AddLine("Open your 20-slot container for snares, traps, cages, family diets, catalysts, and balms.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    bagBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.BagBtn = bagBtn

    -- View 1: 3D Spotlight Roster Container
    local rosterContainer = CreateFrame("Frame", "ForeverSafariRosterContainer", frame)
    rosterContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
    rosterContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 60)
    frame.RosterContainer = rosterContainer
    self.RosterContainer = rosterContainer

    if Journal.BuildRosterView then
        Journal:BuildRosterView(rosterContainer)
    end

    -- View 2: 3D Paperdoll Gallery Grid Container
    local gridContainer = CreateFrame("Frame", "ForeverSafariGridContainer", frame)
    gridContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
    gridContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 60)
    frame.GridContainer = gridContainer
    self.GridContainer = gridContainer

    if Journal.BuildGridView then
        Journal:BuildGridView(gridContainer)
    end

    -- View 3: Azeroth Bestiary Container
    local bestiaryContainer = CreateFrame("Frame", "ForeverSafariBestiaryContainer", frame)
    bestiaryContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
    bestiaryContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 60)
    frame.BestiaryContainer = bestiaryContainer
    self.BestiaryContainer = bestiaryContainer

    if Journal.BuildBestiaryView then
        Journal:BuildBestiaryView(bestiaryContainer)
    end

    -- View 4: Field Directives & Quest Log Container
    local bountiesContainer = CreateFrame("Frame", "ForeverSafariBountiesContainer", frame)
    bountiesContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
    bountiesContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 60)
    frame.BountiesContainer = bountiesContainer
    self.BountiesContainer = bountiesContainer

    if Journal.BuildBountiesView then
        Journal:BuildBountiesView(bountiesContainer)
    end

    -- View 5: Badges & Credentials Showcase Container
    local badgesContainer = CreateFrame("Frame", "ForeverSafariBadgesContainer", frame)
    badgesContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
    badgesContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 60)
    frame.BadgesContainer = badgesContainer
    self.BadgesContainer = badgesContainer

    if Journal.BuildBadgesView then
        Journal:BuildBadgesView(badgesContainer)
    end

    -- Bottom Team Roster Dock with 3D Mini-Paperdolls
    if Journal.BuildTeamDock then
        Journal:BuildTeamDock(frame)
    end

    -- Training Grimoire Drawer (Popout)
    if Journal.BuildTrainingDrawer then
        Journal:BuildTrainingDrawer(frame)
    end

    self.frame = frame
    Journal:SetTab("ROSTER")
    frame:Hide()
end

-- =========================================================================
-- ROUTING & NAVIGATION
-- =========================================================================
function Journal:SetTab(tabId)
    currentTab = tabId

    if frame and frame.TabButtons then
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
    end

    if frame then
        if frame.RosterContainer then frame.RosterContainer:SetShown(tabId == "ROSTER") end
        if frame.GridContainer then frame.GridContainer:SetShown(tabId == "GRID") end
        if frame.BestiaryContainer then frame.BestiaryContainer:SetShown(tabId == "BESTIARY") end
        if frame.BountiesContainer then frame.BountiesContainer:SetShown(tabId == "BOUNTIES") end
        if frame.BadgesContainer then frame.BadgesContainer:SetShown(tabId == "BADGES") end
    end

    Journal:UpdateUI()
end

function Journal:UpdateUI()
    if not frame or not frame:IsShown() then return end
    if frame.Header then frame.Header:UpdateTokens() end

    if currentTab == "ROSTER" then
        if Journal.UpdateRosterView then Journal:UpdateRosterView() end
    elseif currentTab == "GRID" then
        if Journal.UpdateGridView then Journal:UpdateGridView() end
    elseif currentTab == "BESTIARY" then
        if Journal.UpdateBestiaryView then Journal:UpdateBestiaryView() end
    elseif currentTab == "BOUNTIES" then
        if Journal.UpdateBountiesView then Journal:UpdateBountiesView() end
    elseif currentTab == "BADGES" then
        if Journal.UpdateBadgesView then Journal:UpdateBadgesView() end
    end

    if Journal.UpdateTeamDock then
        Journal:UpdateTeamDock()
    end
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

function Journal:SelectMob(mobId)
    if self.SelectCompanion then
        self:SelectCompanion(mobId)
    end
    if frame and frame:IsShown() then
        self:UpdateUI()
    end
end
