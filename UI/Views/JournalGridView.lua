--[[
    Forever Safari: View 2 - 3D Menagerie Gallery Grid (JournalGridView.lua)
    Renders the 6-companion 3D paperdoll gallery grid with 9-type filter ribbon,
    pagination, real-time HP gauges, 3D interaction support, and party leader assignment.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.JournalFrame = ns.JournalFrame or {}

local Journal = ns.JournalFrame
local Theme = ns.Theme
local DB = ns.Database
local C = ns.Constants
local Crypto = ns.Crypto

local gridPage = 1
local gridTypeFilter = "ALL"

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
        if Journal.Setup3DModelInteractions then
            Journal:Setup3DModelInteractions(model)
        end
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
        local inspectBtn = Theme:CreateButton(card, "3D Spotlight", 120, 20, true)
        inspectBtn:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 8, 8)
        inspectBtn:SetScript("OnClick", function()
            if card.mobId then
                if IsShiftKeyDown() then
                    local mob = DB:GetMobById(card.mobId)
                    if mob and ChatEdit_InsertLink then
                        local dna = Crypto and Crypto:ExportCompanionDNA(mob) or ""
                        local link = string.format("|cffffd100|Hsafari:%s|h[Safari: %s Lv.%d (3D)]|h|r",
                            dna, mob.nickname ~= "" and mob.nickname or mob.name, mob.level)
                        if not ChatEdit_InsertLink(link) then
                            DEFAULT_CHAT_FRAME:AddMessage(string.format("%sShift-Click link: %s", C.PREFIX, link))
                        end
                        return
                    end
                end
                if Journal.SelectCompanion then
                    Journal:SelectCompanion(card.mobId)
                end
                Journal:SetTab("ROSTER")
                PlaySound(856)
            end
        end)
        card.InspectBtn = inspectBtn

        local leaderBtn = Theme:CreateButton(card, "Make Leader", 120, 20)
        leaderBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 8)
        leaderBtn:SetScript("OnClick", function()
            if card.mobId then
                local inTeamSlot = nil
                local team = (ForeverSafariDB and ForeverSafariDB.team) or {}
                for idx, id in ipairs(team) do
                    if id == card.mobId then
                        inTeamSlot = idx
                        break
                    end
                end
                if inTeamSlot then
                    DB:SetActiveSlot(inTeamSlot)
                else
                    if #team < 4 then
                        table.insert(team, card.mobId)
                        DB:SetActiveSlot(#team)
                    else
                        local activeSlot = ForeverSafariDB.activeSlot or 1
                        team[activeSlot] = card.mobId
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
    local parent = self.GridContainer
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

    local selectedMob = self.GetSelectedCompanion and self:GetSelectedCompanion()
    local selectedMobId = selectedMob and selectedMob.id

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
            if self.SetModelCreature then
                self:SetModelCreature(card.Model3D, displayId)
            else
                card.Model3D:SetDisplayInfo(displayId)
            end
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
