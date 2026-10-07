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
function Journal:SetModelCreature(modelFrame, displayId)
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
        { id = "ROSTER",   text = "3D Spotlight" },
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

    -- Top Right Quick Access Buttons
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
        GameTooltip:AddLine("Open your 20-slot container for snares, traps, cages, family diets, catalysts, and balms.", 0.8, 0.8, 0.8, true)
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
    -- Backwards compatibility aliases
    if tabId == "SHOWCASE" then tabId = "ROSTER" end
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
