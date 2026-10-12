--[[
    Forever Safari: Junior Safari Reserve (Custom Standalone Vault)
    - Standalone window accessible from Banker gossip ("Junior Safari League: Access Companion Reserve")
    - Zero Taint: Independent top-level window parented to UIParent.
    - Zero Bag Collisions: Movable, centered, supports ESC to close via UISpecialFrames.
    - Squad Management: 4 active slots with 3D model, rank badge, level, HP status, and quick Deposit.
    - Enclosures: 5 Reserve Boxes (20 companions each = 100 total storage capacity) with Swap / Withdraw.
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
    frame:SetSize(730, 420)
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

    -- Subheader
    local header = CreateFrame("Frame", nil, frame)
    header:SetSize(660, 24)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    title:SetPoint("LEFT", 4, 0)
    title:SetText("|cffffd100🐾 Junior Safari Reserve|r")
    header.Title = title

    local subTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subTitle:SetPoint("LEFT", title, "RIGHT", 10, 0)
    subTitle:SetText("|cff00ff99[ Banked Companion Vault ]|r")

    -- Left Column: Active Squad (4 Slots)
    local squadTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    squadTitle:SetPoint("TOPLEFT", 14, -36)
    squadTitle:SetText("|cffffd100Active Squad (4 Max)|r")

    for i = 1, 4 do
        local card = CreateFrame("Button", "ForeverSafariKennelSquadCard" .. i, frame, "BackdropTemplate")
        card:SetSize(218, 68)
        card:SetPoint("TOPLEFT", 14, -56 - ((i - 1) * 72))
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
    boxTitle:SetPoint("TOPLEFT", 246, -36)
    boxTitle:SetText("|cffffd100Reserve Enclosures (Bank)|r")

    -- Box Tab Buttons (1 to 5)
    frame.BoxTabs = {}
    for b = 1, 5 do
        local tab = CreateFrame("Button", "ForeverSafariKennelTab" .. b, frame, "BackdropTemplate")
        tab:SetSize(84, 20)
        tab:SetPoint("TOPLEFT", 246 + ((b - 1) * 88), -54)
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
    gridContainer:SetPoint("TOPLEFT", 246, -76)
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
    withdrawBtn:SetPoint("BOTTOMLEFT", 246, 12)
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
    local boxMobs = DB:GetKennelMobs(currentBox)
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
    end
end)
