--[[
    Forever Safari: Junior Safari Reserve (In-Frame Bank Vault)
    - Embedded single-window view inside Blizzard's native BankFrame (738 x 460).
    - Dedicated vertical side tab mounted on BankFrame's right border with paw icon 🐾.
    - Zero bag collision: Player bags on the right remain 100% visible and unobstructed.
    - Zero-Taint: Swaps view cleanly with BankPanel without modifying secure Blizzard tables.
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
local sideTab = nil
local activeCards = {}
local kennelTiles = {}
local currentBox = 1
local selectedKennelMobId = nil
local selectedSquadSlot = nil
local isReserveActive = false
local nativeHooked = false

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
                        if string.find(lower, "banker", 1, true) then
                            return true
                        end
                    end
                end
            end
        end
        local unitName = UnitName(unit)
        if unitName and string.find(string.lower(unitName), "banker", 1, true) then
            return true
        end
    end
    return false
end

function Kennel:Initialize()
    if frame then return end
    local parent = BankFrame or UIParent

    frame = CreateFrame("Frame", "ForeverSafariBankReservePanel", parent, "BackdropTemplate")
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -42)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 32)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:Hide()

    Theme:ApplyFrameBackdrop(frame)

    -- Subheader
    local header = CreateFrame("Frame", nil, frame)
    header:SetSize(710, 24)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -6)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    title:SetPoint("LEFT", 4, 0)
    title:SetText("|cffffd100🐾 Junior Safari Reserve|r")
    header.Title = title

    local subTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subTitle:SetPoint("LEFT", title, "RIGHT", 10, 0)
    subTitle:SetText("|cff00ff99[ Banked Companion Vault ]|r")

    -- Left Column: Active Squad (4 Slots)
    local squadTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    squadTitle:SetPoint("TOPLEFT", 14, -34)
    squadTitle:SetText("|cffffd100Active Squad (4 Max)|r")

    for i = 1, 4 do
        local card = CreateFrame("Button", "ForeverSafariKennelSquadCard" .. i, frame, "BackdropTemplate")
        card:SetSize(218, 68)
        card:SetPoint("TOPLEFT", 14, -54 - ((i - 1) * 72))
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

        -- Info / Rank Text
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
                -- Swap selected banked pet with this squad slot
                DB:SwapSquadAndKennel(i, selectedKennelMobId)
                selectedKennelMobId = nil
                PlaySound(856)
                Kennel:UpdateUI()
            end
        end)

        activeCards[i] = card
    end

    -- Right Area: Enclosure Boxes (Bank)
    local boxTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    boxTitle:SetPoint("TOPLEFT", 246, -34)
    boxTitle:SetText("|cffffd100Reserve Enclosures (Bank)|r")

    -- Box Tab Buttons (1 to 5)
    frame.BoxTabs = {}
    for b = 1, 5 do
        local tab = CreateFrame("Button", "ForeverSafariKennelTab" .. b, frame, "BackdropTemplate")
        tab:SetSize(84, 20)
        tab:SetPoint("TOPLEFT", 246 + ((b - 1) * 88), -52)
        Theme:ApplyCardBackdrop(tab)
        tab.boxId = b

        local tText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tText:SetPoint("CENTER", 0, 0)
        tText:SetText(string.format("Enclosure %d", b))
        tab.Text = tText

        tab:SetScript("OnClick", function()
            currentBox = b
            selectedKennelMobId = nil
            PlaySound(844)
            Kennel:UpdateUI()
        end)

        frame.BoxTabs[b] = tab
    end

    -- Kennel 20-Slot Grid (4 rows x 5 columns)
    local gridContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    gridContainer:SetSize(448, 252)
    gridContainer:SetPoint("TOPLEFT", 246, -74)
    Theme:ApplyCardBackdrop(gridContainer)

    local tileSize = 42
    for row = 1, 4 do
        for col = 1, 5 do
            local idx = (row - 1) * 5 + col
            local tile = CreateFrame("Button", "ForeverSafariKennelTile" .. idx, gridContainer, "BackdropTemplate")
            tile:SetSize(tileSize, tileSize)
            tile:SetPoint("TOPLEFT", 12 + ((col - 1) * 86), -6 - ((row - 1) * 60))
            Theme:ApplyCardBackdrop(tile)

            local icon = tile:CreateTexture(nil, "ARTWORK")
            icon:SetSize(tileSize - 6, tileSize - 6)
            icon:SetPoint("CENTER", 0, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            tile.Icon = icon

            local label = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("TOP", tile, "BOTTOM", 0, -2)
            label:SetWidth(84)
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
                        local rankData = SE:GetAttunementRank(mob.attunement or 0)
                        GameTooltip:AddLine(string.format("|cff%s%s|r", rankData.color or "ffffff", mob.nickname ~= "" and mob.nickname or mob.name), 1, 1, 1)
                        GameTooltip:AddLine(string.format("Level %d %s — Rank %s (%s)", mob.level or 1, mob.creatureType or "Beast", rankData.roman, rankData.title), 0.8, 0.8, 0.8)
                        GameTooltip:AddLine(string.format("HP: %d / %d", mob.currentHP or mob.hp or 10, mob.maxHP or mob.hp or 10), 0.2, 1, 0.4)
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

    -- Bottom Bar Controls
    local withdrawBtn = CreateFrame("Button", "ForeverSafariKennelWithdrawBtn", frame, "UIPanelButtonTemplate")
    withdrawBtn:SetSize(150, 24)
    withdrawBtn:SetPoint("BOTTOMLEFT", 246, 10)
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
    statusText:SetPoint("BOTTOMRIGHT", -16, 14)
    statusText:SetText("Reserved: 0 companions")
    frame.StatusText = statusText
end

function Kennel:UpdateUI()
    if not frame or not frame:IsShown() then return end

    -- Update Tab Styling
    for b = 1, 5 do
        local tab = frame.BoxTabs[b]
        if tab then
            if b == currentBox then
                tab:SetBackdropBorderColor(1, 0.82, 0, 1)
                tab.Text:SetTextColor(1, 0.82, 0, 1)
            else
                tab:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
                tab.Text:SetTextColor(0.7, 0.7, 0.7, 1)
            end
        end
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

            local rankData = SE:GetAttunementRank(mob.attunement or 0)
            card.InfoText:SetText(string.format("Lv.%d %s — |cff%s%s|r", mob.level or 1, mob.creatureType or "Beast", rankData.color or "ffffff", rankData.roman))

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

            -- Model Display
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

    -- Update Enclosure 20 Tiles
    local boxMobs = DB:GetKennelBox(currentBox)
    for idx = 1, 20 do
        local tile = kennelTiles[idx]
        local mobId = boxMobs[idx]
        local mob = mobId and (type(mobId) == "table" and mobId or DB:GetMobById(mobId)) or nil

        if mob then
            tile.mobId = mob.id
            local iconTex = mob.icon or "Interface\\Icons\\INV_Box_PetCarrier_01"
            tile.Icon:SetTexture(iconTex)
            tile.Icon:Show()

            local name = mob.nickname ~= "" and mob.nickname or mob.name
            if string.len(name) > 10 then
                name = string.sub(name, 1, 9) .. "…"
            end
            local rankData = SE:GetAttunementRank(mob.attunement or 0)
            tile.Label:SetText(string.format("|cff%s%s|r\n|cffaaaaaaLv.%d|r", rankData.color or "ffffff", name, mob.level or 1))

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
            tile.Label:SetText("")
            tile.SelGlow:Hide()
            tile:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.5)
        end
    end

    local totalBanked = #DB:GetKennelMobs()
    frame.StatusText:SetText(string.format("Reserved: |cffffd100%d companions|r across all Enclosures", totalBanked))
end

-- =========================================================================
-- 🐾 IN-FRAME VIEW SWAPPING & SIDE TAB INTEGRATION
-- =========================================================================
local function UpdateSideTabPosition()
    if not sideTab or not BankFrame then return end

    local lastTab = nil
    local maxRank = -1

    -- 1. Logical detection: rank active tabs by bankType and pageNumber (Frame 0 reliable)
    if BankFrame.bankPageTabPool and BankFrame.bankPageTabPool.EnumerateActive then
        for pageTab in BankFrame.bankPageTabPool:EnumerateActive() do
            if pageTab:IsShown() and pageTab ~= sideTab then
                local bType = (pageTab.bankType == (Enum.BankType and Enum.BankType.Account)) and 100 or 0
                local pNum = pageTab.pageNumber or 1
                local rank = bType + pNum
                if rank > maxRank then
                    maxRank = rank
                    lastTab = pageTab
                end
            end
        end
    end

    -- 2. Screen geometry verification: if GetBottom() is valid, verify lowest screen point
    if BankFrame.bankPageTabPool and BankFrame.bankPageTabPool.EnumerateActive then
        local minBottom = math.huge
        local lowestByCoord = nil
        for pageTab in BankFrame.bankPageTabPool:EnumerateActive() do
            if pageTab:IsShown() and pageTab ~= sideTab then
                local b = pageTab:GetBottom()
                if b and b < minBottom then
                    minBottom = b
                    lowestByCoord = pageTab
                end
            end
        end
        if lowestByCoord then
            lastTab = lowestByCoord
        end
    end

    sideTab:ClearAllPoints()
    if lastTab then
        sideTab:SetPoint("TOPLEFT", lastTab, "BOTTOMLEFT", 0, -2)
    else
        -- If no page tab is detected yet, anchor 55px below Page 1 to NEVER collide with Page 1 at (3, -60)
        sideTab:SetPoint("TOPLEFT", BankFrame, "TOPRIGHT", 3, -115)
    end
    sideTab:Show()
end

local function SchedulePositionUpdate()
    UpdateSideTabPosition()
    C_Timer.After(0.02, UpdateSideTabPosition)
    C_Timer.After(0.08, UpdateSideTabPosition)
end

local function EnsureSideTab()
    if sideTab then return sideTab end
    if not BankFrame then return nil end

    local tab = nil
    local ok, res = pcall(CreateFrame, "Frame", "ForeverSafariBankReserveSideTab", BankFrame, "LargeSideTabButtonTemplate")
    if ok and res then
        tab = res
        if tab.OnLoad then tab:OnLoad() end
        tab:SetFrameStrata(BankFrame:GetFrameStrata() or "DIALOG")
        tab:SetFrameLevel((BankFrame:GetFrameLevel() or 10) + 25)
        tab:EnableMouse(true)

        if tab.Icon then
            tab.Icon:ClearAllPoints()
            tab.Icon:SetPoint("CENTER", -4, 0)
            tab.Icon:SetSize(32, 32)
            tab.Icon:SetTexture("Interface\\Icons\\Ability_Hunter_Pet_Cat")
            tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            tab.Icon:Show()
        end

        tab.tooltipText = "|cffffd100Junior Safari Reserve|r\n|cffaaaaaaManage your active squad and banked companion enclosures.|r"

        if tab.SetCustomOnMouseUpHandler then
            tab:SetCustomOnMouseUpHandler(function(self, button, upInside)
                if button == "LeftButton" and upInside then
                    if Kennel:IsReserveActive() then
                        Kennel:DeactivateReserve()
                    else
                        Kennel:ActivateReserve()
                    end
                end
            end)
        end
    else
        tab = CreateFrame("Button", "ForeverSafariBankReserveSideTab", BankFrame, "BackdropTemplate")
        tab:SetSize(40, 40)
        tab:SetFrameStrata(BankFrame:GetFrameStrata() or "DIALOG")
        tab:SetFrameLevel((BankFrame:GetFrameLevel() or 10) + 25)
        Theme:ApplyCardBackdrop(tab)

        local icon = tab:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("CENTER", 0, 0)
        icon:SetTexture("Interface\\Icons\\Ability_Hunter_Pet_Cat")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tab.Icon = icon

        local glow = tab:CreateTexture(nil, "OVERLAY")
        glow:SetAllPoints()
        glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        glow:SetBlendMode("ADD")
        glow:Hide()
        tab.Glow = glow

        tab:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cffffd100Junior Safari Reserve|r", 1, 1, 1)
            GameTooltip:AddLine("Manage your active squad and banked companion enclosures.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        tab:SetScript("OnLeave", function() GameTooltip:Hide() end)

        tab:SetScript("OnClick", function()
            if Kennel:IsReserveActive() then
                Kennel:DeactivateReserve()
            else
                Kennel:ActivateReserve()
            end
        end)
    end

    sideTab = tab
    SchedulePositionUpdate()
    return sideTab
end

function Kennel:IsReserveActive()
    return isReserveActive
end

function Kennel:ActivateReserve()
    if not BankFrame or not BankFrame:IsShown() then
        if BankFrame then
            if BankFrame_Open then
                BankFrame_Open()
            else
                ShowUIPanel(BankFrame)
            end
        end
    end
    if not BankFrame or not BankFrame:IsShown() then return end
    if not frame then Kennel:Initialize() end
    if not frame then return end

    isReserveActive = true

    -- Hide native BankPanel and AutoDepositFrame
    if BankFrame.BankPanel and BankFrame.BankPanel:IsShown() then
        BankFrame.BankPanel:Hide()
    end
    if BankFrame.AutoDepositFrame and BankFrame.AutoDepositFrame:IsShown() then
        BankFrame.AutoDepositFrame:Hide()
    end

    frame:Show()
    Kennel:UpdateUI()

    -- Highlight side tab
    if sideTab then
        if sideTab.SetChecked then
            sideTab:SetChecked(true)
        elseif sideTab.Glow then
            sideTab.Glow:Show()
            sideTab:SetBackdropBorderColor(1, 0.82, 0, 1)
        end
    end

    -- Uncheck Blizzard page tabs
    if BankFrame.bankPageTabPool and BankFrame.bankPageTabPool.EnumerateActive then
        for pageTab in BankFrame.bankPageTabPool:EnumerateActive() do
            if pageTab.SetChecked then pageTab:SetChecked(false) end
        end
    end

    PlaySound(844)
end

function Kennel:DeactivateReserve()
    isReserveActive = false

    if frame and frame:IsShown() then
        frame:Hide()
    end

    -- Unhighlight side tab
    if sideTab then
        if sideTab.SetChecked then
            sideTab:SetChecked(false)
        elseif sideTab.Glow then
            sideTab.Glow:Hide()
            sideTab:SetBackdropBorderColor(0.25, 0.35, 0.45, 0.8)
        end
    end

    -- Restore native BankPanel
    if BankFrame then
        if BankFrame.BankPanel and not BankFrame.BankPanel:IsShown() then
            BankFrame.BankPanel:Show()
        end
        if BankFrame.AutoDepositFrame and not BankFrame.AutoDepositFrame:IsShown() then
            BankFrame.AutoDepositFrame:Show()
        end
    end
end

function Kennel:ShowKennel()
    if BankFrame and BankFrame:IsShown() then
        Kennel:ActivateReserve()
    end
end

function Kennel:Hide()
    Kennel:DeactivateReserve()
end

function Kennel:IsShown()
    return isReserveActive
end

function Kennel:Toggle()
    if isReserveActive then
        Kennel:DeactivateReserve()
    else
        Kennel:ActivateReserve()
    end
end

-- =========================================================================
-- ⚡ EVENT LISTENERS & SECURE TAB HOOKS
-- =========================================================================
local function HookNativeBankTabs()
    if nativeHooked then return end
    nativeHooked = true

    -- Hook BankFrame:SetTab so clicking native tabs restores bank items
    if BankFrame and BankFrame.SetTab then
        hooksecurefunc(BankFrame, "SetTab", function()
            if isReserveActive then
                Kennel:DeactivateReserve()
            end
        end)
    end

    if BankFrameTab1 and not BankFrameTab1.safariHooked then
        BankFrameTab1.safariHooked = true
        BankFrameTab1:HookScript("OnClick", function()
            if isReserveActive then Kennel:DeactivateReserve() end
        end)
    end
    if BankFrameTab2 and not BankFrameTab2.safariHooked then
        BankFrameTab2.safariHooked = true
        BankFrameTab2:HookScript("OnClick", function()
            if isReserveActive then Kennel:DeactivateReserve() end
        end)
    end

    -- Hook BankFrame OnHide to clean up state
    if BankFrame and not BankFrame.safariHideHooked then
        BankFrame.safariHideHooked = true
        BankFrame:HookScript("OnHide", function()
            Kennel:DeactivateReserve()
            if sideTab then sideTab:Hide() end
        end)
    end
end

local function SetupBankIntegration()
    if not BankFrame then return end

    EnsureSideTab()
    HookNativeBankTabs()

    if not BankFrame.safariTabsHooked then
        BankFrame.safariTabsHooked = true

        -- Secure hook RefreshPageTabs to always stack our tab below the lowest active page tab
        if BankFrame.RefreshPageTabs then
            hooksecurefunc(BankFrame, "RefreshPageTabs", function()
                SchedulePositionUpdate()
                if isReserveActive then
                    if BankFrame.bankPageTabPool and BankFrame.bankPageTabPool.EnumerateActive then
                        for pageTab in BankFrame.bankPageTabPool:EnumerateActive() do
                            if pageTab.SetChecked then pageTab:SetChecked(false) end
                        end
                    end
                    if sideTab and sideTab.SetChecked then sideTab:SetChecked(true) end
                end
            end)
        end

        -- Hook EventRegistry for page selections
        if EventRegistry and EventRegistry.RegisterCallback then
            EventRegistry:RegisterCallback("BankPanelMixin.PageSelected", function()
                if isReserveActive then
                    Kennel:DeactivateReserve()
                end
            end, "ForeverSafariKennel")
        end
    end

    if not BankFrame.safariShowHooked then
        BankFrame.safariShowHooked = true
        BankFrame:HookScript("OnShow", function()
            EnsureSideTab()
            HookNativeBankTabs()
            SchedulePositionUpdate()
        end)
    end

    if BankFrame:IsShown() then
        SchedulePositionUpdate()
    end
end

local bankEvents = CreateFrame("Frame", "ForeverSafariKennelBankEvents")
bankEvents:RegisterEvent("PLAYER_LOGIN")
bankEvents:RegisterEvent("BANKFRAME_OPENED")
bankEvents:RegisterEvent("BANKFRAME_CLOSED")
if Enum and Enum.PlayerInteractionType then
    bankEvents:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    bankEvents:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
end
bankEvents:RegisterEvent("GOSSIP_CLOSED")

bankEvents:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        SetupBankIntegration()
    elseif event == "BANKFRAME_OPENED" then
        SetupBankIntegration()
        SchedulePositionUpdate()
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...
        local pit = Enum and Enum.PlayerInteractionType
        if pit and (
            interactionType == pit.Banker or
            interactionType == pit.CharacterBanker or
            interactionType == pit.AccountBanker
        ) then
            SetupBankIntegration()
            SchedulePositionUpdate()
        end
    elseif event == "BANKFRAME_CLOSED" then
        Kennel:DeactivateReserve()
        if sideTab then sideTab:Hide() end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        local pit = Enum and Enum.PlayerInteractionType
        if pit and (
            interactionType == pit.Banker or
            interactionType == pit.CharacterBanker or
            interactionType == pit.AccountBanker
        ) then
            Kennel:DeactivateReserve()
            if sideTab then sideTab:Hide() end
        end
    elseif event == "GOSSIP_CLOSED" then
        if not (BankFrame and BankFrame:IsShown()) then
            Kennel:DeactivateReserve()
        end
    end
end)

-- Run immediate setup on load
SetupBankIntegration()
