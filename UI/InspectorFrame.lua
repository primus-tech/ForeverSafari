--[[
    Forever Safari: 3D Companion Inspector Frame
    Opens when clicking an in-game [Safari: PetName (3D)] chat link.
    Renders live 3D rotatable models, stats, nickname, and 4-move loadout.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.InspectorFrame = ns.InspectorFrame or {}

local Inspector = ns.InspectorFrame
local C = ns.Constants

local frame = nil

function Inspector:Initialize()
    if frame then return end

    frame = CreateFrame("Frame", "ForeverSafariInspectorFrame", UIParent, "BackdropTemplate")
    frame:SetSize(420, 520)
    frame:SetPoint("CENTER", UIParent, "CENTER", 180, 40)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0.08, 0.08, 0.10, 0.96)

    -- Header Banner
    local header = frame:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(320, 64)
    header:SetPoint("TOP", frame, "TOP", 0, 12)

    local headerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerText:SetPoint("TOP", header, "TOP", 0, -14)
    headerText:SetText("|cffffd1003D Safari Inspector|r")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- 3D Model Stage Container
    local stageBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    stageBg:SetSize(380, 220)
    stageBg:SetPoint("TOP", frame, "TOP", 0, -50)
    stageBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    stageBg:SetBackdropColor(0.04, 0.05, 0.07, 0.90)
    stageBg:SetBackdropBorderColor(0.70, 0.55, 0.20, 0.8)

    -- 3D Model Frame
    local model = CreateFrame("PlayerModel", "ForeverSafariInspectorModel", stageBg)
    model:SetAllPoints(stageBg)
    model:SetRotation(0.3)
    model:EnableMouse(true)
    frame.model = model

    -- Mouse Drag Rotation
    local isDragging = false
    local prevMouseX = 0
    model:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isDragging = true
            prevMouseX = GetCursorPosition()
        end
    end)
    model:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then isDragging = false end
    end)
    model:SetScript("OnUpdate", function(self)
        if isDragging then
            local currentX = GetCursorPosition()
            local deltaX = (currentX - prevMouseX) * 0.015
            prevMouseX = currentX
            local rot = self:GetFacing() or 0
            self:SetFacing(rot + deltaX)
        end
    end)

    -- Animation Quick Buttons
    local function CreateAnimBtn(label, animId, xOff)
        local btn = CreateFrame("Button", nil, stageBg, "UIPanelButtonTemplate")
        btn:SetSize(60, 20)
        btn:SetPoint("BOTTOMLEFT", stageBg, "BOTTOMLEFT", xOff, 8)
        btn:SetText(label)
        btn:SetScript("OnClick", function()
            if model.SetAnimation then
                model:SetAnimation(animId)
            end
        end)
        return btn
    end
    CreateAnimBtn("Attack", 16, 12)
    CreateAnimBtn("Roar", 15, 76)
    CreateAnimBtn("Cheer", 4, 140)

    -- Companion Name & Nickname
    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    nameText:SetPoint("TOPLEFT", stageBg, "BOTTOMLEFT", 10, -12)
    nameText:SetText("|cffffd100Companion Name|r")
    frame.nameText = nameText

    local speciesText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    speciesText:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
    speciesText:SetText("(Species)")
    frame.speciesText = speciesText

    local levelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelText:SetPoint("TOPRIGHT", stageBg, "BOTTOMRIGHT", -10, -12)
    levelText:SetText("|cff00ff00Level 1|r")
    frame.levelText = levelText

    -- Stats Grid (HP, ATK, DEF, SPD)
    local statsContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    statsContainer:SetSize(380, 60)
    statsContainer:SetPoint("TOP", nameText, "BOTTOM", 0, -10)
    statsContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    statsContainer:SetBackdropColor(0.06, 0.06, 0.08, 0.70)
    statsContainer:SetBackdropBorderColor(0.4, 0.4, 0.5, 0.5)

    local function CreateStatString(label, xOff)
        local fs = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", statsContainer, "LEFT", xOff, 0)
        fs:SetText(label .. ": --")
        return fs
    end
    frame.hpStat = CreateStatString("|cffff5555HP|r", 15)
    frame.atkStat = CreateStatString("|cffff9900ATK|r", 105)
    frame.defStat = CreateStatString("|cff55aaffDEF|r", 195)
    frame.spdStat = CreateStatString("|cffffff55SPD|r", 285)

    -- Equipped 4-Move Loadout Slots
    local movesHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    movesHeader:SetPoint("TOPLEFT", statsContainer, "BOTTOMLEFT", 5, -12)
    movesHeader:SetText("|cffffd100Active Move Loadout:|r")

    frame.moveSlots = {}
    for i = 1, 4 do
        local slot = CreateFrame("Button", nil, frame, "BackdropTemplate")
        slot:SetSize(86, 75)
        slot:SetPoint("TOPLEFT", movesHeader, "BOTTOMLEFT", (i - 1) * 95, -8)
        slot:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        slot:SetBackdropColor(0.08, 0.08, 0.10, 0.8)
        slot:SetBackdropBorderColor(0.5, 0.5, 0.6, 0.6)

        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("TOP", slot, "TOP", 0, -6)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        slot.icon = icon

        local mName = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mName:SetPoint("BOTTOM", slot, "BOTTOM", 0, 6)
        mName:SetWidth(80)
        mName:SetJustifyH("CENTER")
        mName:SetText("Empty")
        slot.mName = mName

        frame.moveSlots[i] = slot
    end

    -- League Verification Signature Stamp & Rare Crest
    local sigText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sigText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)
    sigText:SetText("🔒 Nesingwary Safari League Verified DNA")
    frame.sigText = sigText

    local rareBadge = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rareBadge:SetPoint("TOP", stageBg, "TOP", 0, -8)
    rareBadge:SetText("|cffffd100★ [AUTHENTIC RARE SPAWN] ★|r")
    rareBadge:Hide()
    frame.rareBadge = rareBadge
end

function Inspector:InspectCompanion(companionData)
    if not frame then Inspector:Initialize() end
    if not companionData then return end

    local isRare = companionData.isRareSpawn or ForeverSafari.Database:IsReservedRareName(companionData.name)

    local rankData = ForeverSafari.StatEngine:GetAttunementRank(companionData.attunement or 0)

    if isRare then
        frame.rareBadge:Show()
        frame.nameText:SetText(string.format("|cffffd100★ %s ★|r", companionData.nickname or companionData.name or "Rare Spawn"))
        frame.speciesText:SetText(string.format("(%s - |cffffd100Rare %s|r)", companionData.name or "Rare Beast", companionData.creatureType or "Beast"))
    else
        frame.rareBadge:Hide()
        frame.nameText:SetText(string.format("|cffffd100%s|r", companionData.nickname or companionData.name or "Unknown"))
        frame.speciesText:SetText(string.format("(%s - %s)", companionData.name or "Wild Fauna", companionData.creatureType or "Beast"))
    end
    frame.levelText:SetText(string.format("|cff%sRank %s: %s|r", rankData.color, rankData.roman, rankData.title))

    -- 3D Model Display
    local dispId = companionData.displayId or 903
    if frame.model.SetDisplayInfo then
        frame.model:SetDisplayInfo(dispId)
    elseif frame.model.SetCreatureByDisplayID then
        frame.model:SetCreatureByDisplayID(dispId)
    end
    if frame.model.SetPortraitZoom then frame.model:SetPortraitZoom(0) end
    if frame.model.SetCamDistanceScale then frame.model:SetCamDistanceScale(1.0) end
    frame.model:SetRotation(0.3)

    -- Stats
    frame.hpStat:SetText(string.format("|cffff5555HP:|r %d", companionData.hp or companionData.maxHp or 10))
    frame.atkStat:SetText(string.format("|cffff9900ATK:|r %d", companionData.attack or 5))
    frame.defStat:SetText(string.format("|cff55aaffDEF:|r %d", companionData.defense or 5))
    frame.spdStat:SetText(string.format("|cffffff55SPD:|r %d", companionData.speed or 5))

    -- Moves (respect rank move capacity)
    local abilities = companionData.abilities or {}
    local capacity = rankData.moveSlots or 1
    for i = 1, 4 do
        local slot = frame.moveSlots[i]
        if i > capacity then
            slot.icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
            slot.mName:SetText(string.format("|cff666666Locked|r"))
        else
            local moveKey = abilities[i]
            if moveKey then
                local moveData = ForeverSafari.Constants.ABILITIES[moveKey]
                local mName = moveData and moveData.name or moveKey
                local mIcon = moveData and moveData.icon or "Ability_Hunter_Pet_Wolf"
                slot.icon:SetTexture("Interface\\Icons\\" .. mIcon)
                slot.mName:SetText("|cffffd100" .. mName .. "|r")
            else
                slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                slot.mName:SetText("|cff888888Empty|r")
            end
        end
    end

    -- Verify signature
    local expectedSig = ForeverSafari.Database:GenerateSignature(companionData)
    if companionData.sig and companionData.sig == expectedSig then
        if isRare then
            frame.sigText:SetText("|cffffd100🔒 Authentic Nesingwary League Verified Rare Spawn (Protected)|r")
        else
            frame.sigText:SetText("|cff00ff00🔒 Authentic Nesingwary League Companion (Signed)|r")
        end
    else
        frame.sigText:SetText("|cffaaaaaa🐾 Wild Companion DNA Verified|r")
    end

    PlaySound(844) -- SOUNDKIT.IG_SPELLBOOK_OPEN
    frame:Show()
end

-- Secure Chat Link Hook
if hooksecurefunc then
    hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
        if link and link:find("^safari:") then
            local dnaStr = link:sub(8)
            local mob = ForeverSafari.Database:ImportCompanionDNA(dnaStr)
            if mob then
                Inspector:InspectCompanion(mob)
            end
        end
    end)
end
