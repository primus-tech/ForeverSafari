--[[
    Forever Safari: Safari Kennel & Lodge Sidecar (Innkeeper "Pokémon Bank")
    - Accessed exclusively when interacting with Innkeepers in towns.
    - Manages the player's 4 Active Squad members vs. Banked Enclosure Boxes (1..5, 20 pets each = 100 pets).
    - 100% Zero-Taint: Standalone frame parented strictly to UIParent.
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

-- Check if currently interacting with an Innkeeper
function Kennel:IsAtInnkeeper()
    if not GossipFrame or not GossipFrame:IsShown() then
        return false
    end
    local title = GossipFrameTitleText and GossipFrameTitleText:GetText() or ""
    local unitName = UnitName("npc") or UnitName("target") or ""
    local isInn = (title:find("Innkeeper") ~= nil or title:find("Tavern") ~= nil or unitName:find("Innkeeper") ~= nil)
    return isInn
end

function Kennel:Initialize()
    if frame then return end

    frame = CreateFrame("Frame", "ForeverSafariKennelFrame", UIParent, "BackdropTemplate")
    frame:SetSize(720, 520)
    frame:SetPoint("CENTER", UIParent, "CENTER", 60, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    Theme:ApplyWindowBackdrop(frame)

    -- Header
    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetSize(720, 44)
    header:SetPoint("TOP", 0, 0)
    Theme:ApplyHeaderBackdrop(header)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("LEFT", 16, 0)
    title:SetText("|cffffd100🏡 Safari Kennel & Lodge|r")
    header.Title = title

    local subTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subTitle:SetPoint("LEFT", title, "RIGHT", 12, 0)
    subTitle:SetText("|cff00ff99[ Innkeeper Boarding Stables ]|r")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", -6, 0)
    closeBtn:SetScript("OnClick", function() Kennel:Hide() end)

    -- Left Column: Active Squad (4 Slots)
    local squadTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    squadTitle:SetPoint("TOPLEFT", 16, -52)
    squadTitle:SetText("|cffffd100Active Squad (4 Max)|r")

    local squadDesc = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    squadDesc:SetPoint("TOPLEFT", 16, -68)
    squadDesc:SetText("Companions traveling with you in the field.")

    for i = 1, 4 do
        local card = CreateFrame("Button", "ForeverSafariKennelSquadCard" .. i, frame, "BackdropTemplate")
        card:SetSize(220, 78)
        card:SetPoint("TOPLEFT", 16, -88 - ((i - 1) * 84))
        Theme:ApplyCardBackdrop(card)
        card.slotIndex = i

        -- 3D Model
        local model = CreateFrame("PlayerModel", nil, card)
        model:SetSize(60, 60)
        model:SetPoint("LEFT", 6, 0)
        if model.SetPortraitZoom then model:SetPortraitZoom(0.85) end
        if model.SetRotation then model:SetRotation(math.rad(25)) end
        card.Model = model

        -- Name Text
        local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameText:SetPoint("TOPLEFT", model, "TOPRIGHT", 8, -4)
        nameText:SetJustifyH("LEFT")
        nameText:SetText("Empty Slot")
        card.NameText = nameText

        -- Info / Rank Text
        local infoText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        infoText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -3)
        infoText:SetText("")
        card.InfoText = infoText

        -- HP Status Bar
        local hpBar = CreateFrame("StatusBar", nil, card)
        hpBar:SetSize(130, 10)
        hpBar:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", 0, -4)
        hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        hpBar:SetStatusBarColor(0.2, 0.8, 0.4)
        hpBar:SetMinMaxValues(0, 100)
        hpBar:SetValue(100)
        card.HPBar = hpBar

        -- Deposit Button
        local depBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
        depBtn:SetSize(65, 18)
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
    boxTitle:SetPoint("TOPLEFT", 256, -52)
    boxTitle:SetText("|cffffd100Boarded Enclosures (Kennel Bank)|r")

    -- Box Tab Buttons (1 to 5)
    frame.BoxTabs = {}
    for b = 1, 5 do
        local tab = CreateFrame("Button", "ForeverSafariKennelTab" .. b, frame, "BackdropTemplate")
        tab:SetSize(84, 22)
        tab:SetPoint("TOPLEFT", 256 + ((b - 1) * 88), -72)
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

    -- Kennel 20-Slot Grid (4 columns x 5 rows)
    local gridContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    gridContainer:SetSize(448, 335)
    gridContainer:SetPoint("TOPLEFT", 256, -100)
    Theme:ApplyCardBackdrop(gridContainer)

    local tileSize = 48
    for row = 1, 4 do
        for col = 1, 5 do
            local idx = (row - 1) * 5 + col
            local tile = CreateFrame("Button", "ForeverSafariKennelTile" .. idx, gridContainer, "BackdropTemplate")
            tile:SetSize(tileSize, tileSize)
            tile:SetPoint("TOPLEFT", 12 + ((col - 1) * 86), -10 - ((row - 1) * 78))
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

    -- Bottom Bar
    local bottomBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bottomBar:SetSize(720, 48)
    bottomBar:SetPoint("BOTTOM", 0, 0)
    Theme:ApplyHeaderBackdrop(bottomBar)

    local healBtn = CreateFrame("Button", "ForeverSafariKennelTendBtn", bottomBar, "UIPanelButtonTemplate")
    healBtn:SetSize(190, 30)
    healBtn:SetPoint("LEFT", 16, 0)
    healBtn:SetText("💖 Tend & Rest All Pets")
    healBtn:SetScript("OnClick", function()
        for _, mob in ipairs(DB:GetCollection()) do
            mob.currentHP = mob.maxHP or mob.hp or 10
            mob.hp = mob.currentHP
        end
        PlaySound(1195)
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff00All active and boarded companions were tended and fully restored at the Inn!|r")
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Squad & Kennel Rested", "All companions restored to 100% HP!")
        end
        Kennel:UpdateUI()
    end)
    healBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("💖 Tend & Rest All Companions", 1, 0.82, 0)
        GameTooltip:AddLine("Fully heals and revives all active squad members and banked companions staying at the Inn.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    healBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local withdrawBtn = CreateFrame("Button", "ForeverSafariKennelWithdrawBtn", bottomBar, "UIPanelButtonTemplate")
    withdrawBtn:SetSize(160, 30)
    withdrawBtn:SetPoint("LEFT", healBtn, "RIGHT", 12, 0)
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

    local statusText = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("RIGHT", -16, 0)
    statusText:SetText("Boarded: 0 companions")
    frame.StatusText = statusText

    -- Auto-dismiss when closing Gossip
    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame:RegisterEvent("GOSSIP_CLOSED")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "GOSSIP_CLOSED" and frame and frame:IsShown() then
            frame:Hide()
        end
    end)
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
        local mob = team[i]
        if mob then
            card.mobId = mob.id
            local pName = mob.nickname ~= "" and mob.nickname or mob.name
            local rankData = SE:GetAttunementRank(mob.attunement or 0)
            card.NameText:SetText(string.format("|cff%s%s|r", rankData.color or "ffffff", pName))
            card.InfoText:SetText(string.format("Lv %d %s |cffffd100[Rank %s]|r", mob.level or 1, mob.creatureType or "Beast", rankData.roman))

            local curHP = mob.currentHP or mob.hp or 10
            local maxHP = mob.maxHP or mob.hp or 10
            card.HPBar:SetMinMaxValues(0, maxHP)
            card.HPBar:SetValue(curHP)
            if (curHP / maxHP) <= 0.25 then
                card.HPBar:SetStatusBarColor(0.9, 0.2, 0.2)
            else
                card.HPBar:SetStatusBarColor(0.2, 0.8, 0.4)
            end

            local dispId = tonumber(mob.displayId) or 181
            if card.Model and card.Model.SetCreatureByDisplayID then
                pcall(function() card.Model:SetCreatureByDisplayID(dispId) end)
            elseif card.Model and card.Model.SetDisplayInfo then
                pcall(function() card.Model:SetDisplayInfo(dispId) end)
            end
            card.Model:Show()
            card.DepositBtn:Show()
            card.DepositBtn:SetEnabled(#team > 1) -- Must keep at least 1 pet in squad
        else
            card.mobId = nil
            card.NameText:SetText("|cff666666Empty Squad Slot|r")
            card.InfoText:SetText("Select a banked pet to add")
            card.HPBar:SetValue(0)
            if card.Model then card.Model:Hide() end
            card.DepositBtn:Hide()
        end
    end

    -- Update Banked Grid (20 slots for current box)
    local kennelMobs = DB:GetKennelMobs(currentBox)
    for idx = 1, 20 do
        local tile = kennelTiles[idx]
        local mob = kennelMobs[idx]
        if mob then
            tile.mobId = mob.id
            local pName = mob.nickname ~= "" and mob.nickname or mob.name
            local rankData = SE:GetAttunementRank(mob.attunement or 0)
            tile.Label:SetText(string.format("|cff%s%s|r", rankData.color or "ffffff", pName:sub(1, 10)))

            local iconPath = "Interface\\Icons\\INV_Box_PetCarrier_01"
            if mob.creatureType == "Beast" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Wolf"
            elseif mob.creatureType == "Flying" then iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Bat"
            elseif mob.creatureType == "Undead" then iconPath = "Interface\\Icons\\Spell_Shadow_DeadofNight"
            elseif mob.creatureType == "Elemental" then iconPath = "Interface\\Icons\\Spell_Fire_Elemental_Totem"
            elseif mob.creatureType == "Mechanical" then iconPath = "Interface\\Icons\\INV_Misc_EngGizmos_17"
            elseif mob.creatureType == "Dragonkin" then iconPath = "Interface\\Icons\\INV_Misc_Head_Dragon_01"
            end
            tile.Icon:SetTexture(iconPath)
            tile.Icon:Show()

            if selectedKennelMobId == mob.id then
                tile.SelGlow:Show()
                tile:SetBackdropBorderColor(0, 1, 0.6, 1)
            else
                tile.SelGlow:Hide()
                tile:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
            end
        else
            tile.mobId = nil
            tile.Label:SetText("")
            tile.Icon:Hide()
            tile.SelGlow:Hide()
            tile:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.5)
        end
    end

    local totalBanked = #DB:GetKennelMobs()
    frame.StatusText:SetText(string.format("Boarded: |cffffd100%d companions|r across all Enclosures", totalBanked))
end

function Kennel:ShowKennel()
    if not frame then Kennel:Initialize() end
    frame:Show()
    Kennel:UpdateUI()
    PlaySound(844)
end

function Kennel:Hide()
    if frame then frame:Hide() end
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
