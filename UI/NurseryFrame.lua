--[[
    Forever Safari: Moonglade Cenarion Nursery (NurseryFrame.lua)
    Endgame Co-op Breeding Program & Sacred Ritual Sanctuary.
    Requires two Rank V (Bestial Symbiosis) companions of the exact same family:
    One Sire (♂) and One Dam (♀).
    Executes The Ultimate Sacrifice (permanent vault consumption of parents)
    and distributes guaranteed purebred Safari Eggs (with 20% bonus 3rd egg roll).
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.NurseryFrame = ns.NurseryFrame or {}

local Nursery = ns.NurseryFrame
local C = ns.Constants
local DB = ns.Database
local Theme = ns.Theme
local Crypto = ns.Crypto
local ItemDB = ns.ItemDB
local StatEngine = ns.StatEngine

local frame = nil
local cand1 = nil -- Candidate 1 (Local Player)
local cand2 = nil -- Candidate 2 (Mate / Partner in co-op or 2nd pet in solo)
local isCoopMode = false
local partnerName = nil
local partnerReady = false
local myReady = false
local isAtNurseryNPC = false
local selectionTargetSlot = 1 -- 1 or 2

-- Helper for secret strings
local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return true end
    if issecretpassphrase and issecretpassphrase(v) then return true end
    if issecretvariable and issecretvariable(v) then return true end
    local ok = pcall(function() local _ = (v == "") end)
    if not ok then return true end
    return false
end

-- =========================================================================
-- 🌿 1. FRAME INITIALIZATION
-- =========================================================================
function Nursery:Initialize()
    if frame then return end

    frame = CreateFrame("Frame", "ForeverSafariNurseryFrame", UIParent, "BackdropTemplate")
    frame:SetSize(660, 560)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = false, tileSize = 16, edgeSize = 20,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    frame:SetBackdropColor(0.05, 0.08, 0.06, 0.96)
    frame:SetBackdropBorderColor(0.2, 0.8, 0.4, 0.95)

    -- Header Title
    local headerTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    headerTitle:SetPoint("TOP", frame, "TOP", 0, -14)
    headerTitle:SetText("|cffffd100🌿 Moonglade Cenarion Nursery|r")
    frame.HeaderTitle = headerTitle

    local headerSub = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerSub:SetPoint("TOP", headerTitle, "BOTTOM", 0, -3)
    headerSub:SetText("|cff88ddaaEndgame Co-op Breeding Program & Sacred Rebirth Sanctuary|r")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() Nursery:Hide() end)

    -- Mode Toggle Bar
    local modeBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    modeBar:SetSize(624, 30)
    modeBar:SetPoint("TOP", frame, "TOP", 0, -42)
    Theme:ApplyCardBackdrop(modeBar)

    local btnSolo = Theme:CreateButton(modeBar, "Solo Vault Breeding", 160, 22)
    btnSolo:SetPoint("LEFT", 8, 0)

    local btnCoop = Theme:CreateButton(modeBar, "Co-op Partner Breeding", 160, 22)
    btnCoop:SetPoint("LEFT", btnSolo, "RIGHT", 8, 0)

    local partnerLabel = modeBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    partnerLabel:SetPoint("RIGHT", -12, 0)
    partnerLabel:SetText("|cffaaaaaaPartner: None (Solo Mode)|r")
    modeBar.PartnerLabel = partnerLabel

    btnSolo:SetScript("OnClick", function()
        isCoopMode = false
        partnerName = nil
        partnerReady = false
        myReady = false
        cand2 = nil
        partnerLabel:SetText("|cffaaaaaaPartner: None (Solo Mode)|r")
        btnSolo:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        btnCoop:SetBackdropBorderColor(0.3, 0.4, 0.5, 0.8)
        Nursery:UpdateUI()
    end)

    btnCoop:SetScript("OnClick", function()
        if UnitExists("target") and UnitIsPlayer("target") then
            local tName = UnitName("target")
            if not isSecret(tName) and tName ~= "" and tName ~= UnitName("player") then
                partnerName = tName
                isCoopMode = true
                partnerReady = false
                myReady = false
                cand2 = nil
                partnerLabel:SetText(string.format("|cff00ff00Partner: %s|r", partnerName))
                btnCoop:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                btnSolo:SetBackdropBorderColor(0.3, 0.4, 0.5, 0.8)
                if ns.Comms and ns.Comms.SendNurseryMessage then
                    ns.Comms:SendNurseryMessage("NURSERY_INVITE", "", partnerName)
                end
                DEFAULT_CHAT_FRAME:AddMessage(string.format("%sSent Moonglade Nursery invitation to |cffffd100%s|r!", C.PREFIX, partnerName))
                Nursery:UpdateUI()
                return
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Target another player to invite them to Co-op Breeding!|r")
    end)
    frame.BtnSolo = btnSolo
    frame.BtnCoop = btnCoop

    -- =========================================================================
    -- 2. DUAL 3D PEDESTALS (CANDIDATE 1 & CANDIDATE 2)
    -- =========================================================================
    local function CreatePedestalCard(xOffset, titleText)
        local card = Theme:CreateCard(frame, 306, 230)
        card:SetPoint("TOPLEFT", frame, "TOPLEFT", xOffset, -80)

        local title = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", card, "TOP", 0, -8)
        title:SetText(titleText)
        card.Title = title

        -- 3D Model Frame
        local model = CreateFrame("PlayerModel", nil, card)
        model:SetSize(290, 130)
        model:SetPoint("TOP", card, "TOP", 0, -28)
        model:EnableMouse(true)
        model:SetRotation(0.3)
        card.Model = model

        -- Rotation drag
        local isDragging = false
        local prevX = 0
        model:SetScript("OnMouseDown", function(self, btn)
            if btn == "LeftButton" then isDragging = true; prevX = GetCursorPosition() end
        end)
        model:SetScript("OnMouseUp", function() isDragging = false end)
        model:SetScript("OnUpdate", function(self)
            if isDragging then
                local curX = GetCursorPosition()
                local delta = (curX - prevX) * 0.015
                prevX = curX
                local facing = self:GetFacing() or 0
                self:SetFacing(facing + delta)
            end
        end)

        -- Info string
        local info = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        info:SetPoint("TOP", model, "BOTTOM", 0, -4)
        info:SetWidth(290)
        info:SetJustifyH("CENTER")
        info:SetText("|cff888888[No Companion Chosen]|r")
        card.Info = info

        -- Select button
        local selectBtn = Theme:CreateButton(card, "Choose Companion", 160, 22)
        selectBtn:SetPoint("BOTTOM", card, "BOTTOM", 0, 8)
        card.SelectBtn = selectBtn

        return card
    end

    frame.Pedestal1 = CreatePedestalCard(18, "|cffffd100Candidate 1 (Trainer)|r")
    frame.Pedestal2 = CreatePedestalCard(336, "|cffffd100Candidate 2 (Mate / Partner)|r")

    frame.Pedestal1.SelectBtn:SetScript("OnClick", function()
        selectionTargetSlot = 1
        Nursery:OpenPickerDrawer()
    end)

    frame.Pedestal2.SelectBtn:SetScript("OnClick", function()
        if isCoopMode then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffffcc00Candidate 2 is chosen by your partner trainer.|r")
        else
            selectionTargetSlot = 2
            Nursery:OpenPickerDrawer()
        end
    end)

    -- =========================================================================
    -- 3. VERIFICATION CHECKLIST CARD
    -- =========================================================================
    local checkCard = Theme:CreateCard(frame, 624, 75)
    checkCard:SetPoint("TOP", frame, "TOP", 0, -320)
    frame.CheckCard = checkCard

    local line1 = checkCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line1:SetPoint("TOPLEFT", checkCard, "TOPLEFT", 14, -10)
    line1:SetText("1. Family Harmony: |cffff4444✘ Pending Selection|r")
    checkCard.Line1 = line1

    local line2 = checkCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line2:SetPoint("TOPLEFT", checkCard, "TOPLEFT", 14, -30)
    line2:SetText("2. Apex Attunement: |cffff4444✘ Both Must Be Rank V (1000 Loyalty)|r")
    checkCard.Line2 = line2

    local line3 = checkCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line3:SetPoint("TOPLEFT", checkCard, "TOPLEFT", 14, -50)
    line3:SetText("3. Biological Designation: |cffff4444✘ Requires 1x Sire (♂) and 1x Dam (♀)|r")
    checkCard.Line3 = line3

    -- =========================================================================
    -- 4. THE ULTIMATE SACRIFICE WARNING CARD
    -- =========================================================================
    local warnCard = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    warnCard:SetSize(624, 60)
    warnCard:SetPoint("TOP", checkCard, "BOTTOM", 0, -8)
    warnCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 8, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    warnCard:SetBackdropColor(0.20, 0.04, 0.04, 0.85)
    warnCard:SetBackdropBorderColor(1.0, 0.2, 0.2, 0.9)

    local warnTitle = warnCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warnTitle:SetPoint("TOP", warnCard, "TOP", 0, -8)
    warnTitle:SetText("|cffff3333⚠ THE ULTIMATE SACRIFICE ⚠|r")

    local warnDesc = warnCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    warnDesc:SetPoint("TOP", warnTitle, "BOTTOM", 0, -3)
    warnDesc:SetText("|cffffcc00Both parent companions will merge their life forces and be PERMANENTLY consumed from your vault.|r\n|cff00ff00Offspring Guarantee: 1 purebred Safari Egg to each trainer (+20% chance for a 3rd bonus egg).|r")

    -- =========================================================================
    -- 5. BOTTOM ACTION BAR & BREED BUTTON
    -- =========================================================================
    local bottomBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bottomBar:SetSize(624, 40)
    bottomBar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)
    Theme:ApplyCardBackdrop(bottomBar)

    local breedBtn = Theme:CreateButton(bottomBar, "Commence Sacred Breeding Ritual", 280, 26)
    breedBtn:SetPoint("CENTER", bottomBar, "CENTER", 0, 0)
    breedBtn:Disable()
    frame.BreedBtn = breedBtn

    breedBtn:SetScript("OnClick", function()
        Nursery:PromptSacrificeConfirmation()
    end)

    -- =========================================================================
    -- 6. COMPANION SELECTION POPUP DRAWER
    -- =========================================================================
    local picker = CreateFrame("Frame", "ForeverSafariNurseryPicker", frame, "BackdropTemplate")
    picker:SetSize(340, 360)
    picker:SetPoint("CENTER", frame, "CENTER", 0, 0)
    picker:SetFrameStrata("TOOLTIP")
    picker:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = false, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    picker:SetBackdropColor(0.06, 0.09, 0.08, 0.98)
    picker:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
    picker:Hide()

    local pickerTitle = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pickerTitle:SetPoint("TOP", picker, "TOP", 0, -10)
    pickerTitle:SetText("|cffffd100Select Candidate Companion|r")

    local pickerClose = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    pickerClose:SetSize(20, 20)
    pickerClose:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -4, -4)
    pickerClose:SetScript("OnClick", function() picker:Hide() end)

    local pickerScroll = CreateFrame("ScrollFrame", "ForeverSafariNurseryPickerScroll", picker, "UIPanelScrollFrameTemplate")
    pickerScroll:SetPoint("TOPLEFT", 10, -36)
    pickerScroll:SetPoint("BOTTOMRIGHT", -26, 10)

    local pickerContent = CreateFrame("Frame", nil, pickerScroll)
    pickerContent:SetSize(300, 400)
    pickerScroll:SetScrollChild(pickerContent)
    picker.Content = pickerContent
    frame.Picker = picker

    -- Gossip & Zone Events
    Nursery:RegisterGossipEvents()
end

-- =========================================================================
-- 🔍 2. COMPATIBILITY VALIDATION
-- =========================================================================
function Nursery:ValidatePair()
    if not cand1 or not cand2 then
        return false, "Incomplete Selection", "Incomplete Selection", "Incomplete Selection"
    end

    -- 1. Family Match
    local fam1 = cand1.family or cand1.creatureType or "Beast"
    local fam2 = cand2.family or cand2.creatureType or "Beast"
    local familyMatch = (string.lower(fam1) == string.lower(fam2))

    -- 2. Both Rank V (Bestial Symbiosis / 1000 Loyalty)
    local r1 = cand1.attunementRank or (StatEngine and StatEngine:GetAttunementRank(cand1.attunement or 0).rank) or 1
    local r2 = cand2.attunementRank or (StatEngine and StatEngine:GetAttunementRank(cand2.attunement or 0).rank) or 1
    local rankMatch = (r1 >= 5 and r2 >= 5)

    -- 3. One Sire and One Dam
    local a1 = cand1.anatomy or "Sire"
    local a2 = cand2.anatomy or "Dam"
    local anatomyMatch = ((a1 == "Sire" and a2 == "Dam") or (a1 == "Dam" and a2 == "Sire"))

    local allPass = (familyMatch and rankMatch and anatomyMatch)
    return allPass, familyMatch, rankMatch, anatomyMatch
end

-- =========================================================================
-- 🔄 3. UI REFRESH
-- =========================================================================
function Nursery:UpdateUI()
    if not frame or not frame:IsShown() then return end

    -- Render Candidate 1
    if cand1 then
        local dispId = cand1.displayId or 903
        if frame.Pedestal1.Model.SetDisplayInfo then
            frame.Pedestal1.Model:SetDisplayInfo(dispId)
        elseif frame.Pedestal1.Model.SetCreatureByDisplayID then
            frame.Pedestal1.Model:SetCreatureByDisplayID(dispId)
        end
        local anatBadge = cand1.anatomy == "Dam" and "|cffff99cc♀ Dam|r" or "|cff66ccff♂ Sire|r"
        frame.Pedestal1.Info:SetText(string.format("|cffffd100%s|r (%s)\nRank %d | %s | %s",
            cand1.nickname or cand1.name or "Companion",
            cand1.family or "Beast",
            cand1.attunementRank or 1,
            anatBadge,
            cand1.isRare and "|cffffd100★ Rare|r" or "|cffaaaaaaStandard|r"
        ))
        frame.Pedestal1.SelectBtn:SetText("Change Candidate")
    else
        frame.Pedestal1.Model:ClearModel()
        frame.Pedestal1.Info:SetText("|cff888888[No Companion Chosen]|r")
        frame.Pedestal1.SelectBtn:SetText("Choose Candidate 1")
    end

    -- Render Candidate 2
    if cand2 then
        local dispId = cand2.displayId or 903
        if frame.Pedestal2.Model.SetDisplayInfo then
            frame.Pedestal2.Model:SetDisplayInfo(dispId)
        elseif frame.Pedestal2.Model.SetCreatureByDisplayID then
            frame.Pedestal2.Model:SetCreatureByDisplayID(dispId)
        end
        local anatBadge = cand2.anatomy == "Dam" and "|cffff99cc♀ Dam|r" or "|cff66ccff♂ Sire|r"
        frame.Pedestal2.Info:SetText(string.format("|cffffd100%s|r (%s)\nRank %d | %s | %s",
            cand2.nickname or cand2.name or "Partner Mate",
            cand2.family or "Beast",
            cand2.attunementRank or 1,
            anatBadge,
            cand2.isRare and "|cffffd100★ Rare|r" or "|cffaaaaaaStandard|r"
        ))
        frame.Pedestal2.SelectBtn:SetText(isCoopMode and "Partner's Pick" or "Change Candidate")
    else
        frame.Pedestal2.Model:ClearModel()
        frame.Pedestal2.Info:SetText(isCoopMode and "|cff888888[Waiting for Partner to Select...]|r" or "|cff888888[No Mate Chosen]|r")
        frame.Pedestal2.SelectBtn:SetText(isCoopMode and "Waiting..." or "Choose Candidate 2")
    end

    -- Validation Checklist
    local allPass, famOk, rankOk, anatOk = Nursery:ValidatePair()

    if famOk == true then
        local fam = cand1.family or "Beast"
        frame.CheckCard.Line1:SetText(string.format("1. Family Harmony: |cff00ff00✔ Exact Match (%s)|r", fam))
    elseif famOk == false then
        local f1 = cand1 and cand1.family or "None"
        local f2 = cand2 and cand2.family or "None"
        frame.CheckCard.Line1:SetText(string.format("1. Family Harmony: |cffff4444✘ Mismatch (%s vs %s)|r", f1, f2))
    else
        frame.CheckCard.Line1:SetText("1. Family Harmony: |cffffaa00⏳ Pending Selection|r")
    end

    if rankOk == true then
        frame.CheckCard.Line2:SetText("2. Apex Attunement: |cff00ff00✔ Both Rank V: Bestial Symbiosis|r")
    elseif rankOk == false then
        local r1 = cand1 and (cand1.attunementRank or 1) or 0
        local r2 = cand2 and (cand2.attunementRank or 1) or 0
        frame.CheckCard.Line2:SetText(string.format("2. Apex Attunement: |cffff4444✘ Requires Rank V (Current: R%d / R%d)|r", r1, r2))
    else
        frame.CheckCard.Line2:SetText("2. Apex Attunement: |cffffaa00⏳ Both Must Be Rank V (1000 Loyalty)|r")
    end

    if anatOk == true then
        frame.CheckCard.Line3:SetText("3. Biological Designation: |cff00ff00✔ Compatible Pair (1x Sire ♂ + 1x Dam ♀)|r")
    elseif anatOk == false then
        local a1 = cand1 and (cand1.anatomy or "Sire") or "?"
        local a2 = cand2 and (cand2.anatomy or "Sire") or "?"
        frame.CheckCard.Line3:SetText(string.format("3. Biological Designation: |cffff4444✘ Incompatible (%s + %s; Need 1 Sire & 1 Dam)|r", a1, a2))
    else
        frame.CheckCard.Line3:SetText("3. Biological Designation: |cffffaa00⏳ Requires 1x Sire (♂) and 1x Dam (♀)|r")
    end

    -- Action Button State
    if allPass then
        frame.BreedBtn:Enable()
        frame.BreedBtn:SetText("|cffffd100Commence Sacred Breeding Ritual|r")
    else
        frame.BreedBtn:Disable()
        frame.BreedBtn:SetText("Breeding Requirements Unmet")
    end
end

-- =========================================================================
-- 📋 4. CANDIDATE SELECTION DRAWER
-- =========================================================================
local pickerButtons = {}
function Nursery:OpenPickerDrawer()
    if not frame then Nursery:Initialize() end
    local picker = frame.Picker
    local content = picker.Content

    local col = DB:GetCollection()
    local yOffset = 0
    local count = 0

    for i, mob in ipairs(col) do
        -- Exclude if already selected in the other slot
        local otherSelected = (selectionTargetSlot == 1 and cand2 and cand2.id == mob.id) or
                              (selectionTargetSlot == 2 and cand1 and cand1.id == mob.id)

        if not otherSelected then
            count = count + 1
            local btn = pickerButtons[count]
            if not btn then
                btn = Theme:CreateButton(content, "", 290, 42)
                btn.Title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.Title:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -6)
                btn.Sub = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                btn.Sub:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 8, 6)
                pickerButtons[count] = btn
            end

            btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
            btn.mob = mob

            local anatBadge = mob.anatomy == "Dam" and "|cffff99cc♀ Dam|r" or "|cff66ccff♂ Sire|r"
            local rankColor = (mob.attunementRank or 1) >= 5 and "00ff00" or "ff8888"

            btn.Title:SetText(string.format("|cffffd100%s|r (%s)  %s", mob.customNickname or mob.name, mob.family or "Beast", anatBadge))
            btn.Sub:SetText(string.format("Loyalty: |cff%sRank %d%s|r | %s",
                rankColor,
                mob.attunementRank or 1,
                (mob.attunementRank or 1) >= 5 and " (Eligible!)" or " (Need Rank V)",
                mob.isRare and "|cffffd100Rare|r" or "Common"
            ))

            btn:SetScript("OnClick", function()
                if selectionTargetSlot == 1 then
                    cand1 = mob
                    if isCoopMode and partnerName and ns.Comms and ns.Comms.SendNurseryMessage then
                        -- Serialize and transmit Candidate 1 to partner
                        local payload = string.format("%s;%s;%s;%d;%d;%d;%d;%d",
                            mob.name or "Companion",
                            mob.family or "Beast",
                            mob.anatomy or "Sire",
                            mob.attunementRank or 1,
                            mob.level or 1,
                            mob.hp or 10,
                            mob.displayId or 903,
                            mob.isRare and 1 or 0
                        )
                        ns.Comms:SendNurseryMessage("NURSERY_CANDIDATE", payload, partnerName)
                    end
                else
                    cand2 = mob
                end
                picker:Hide()
                Nursery:UpdateUI()
            end)

            btn:Show()
            yOffset = yOffset - 46
        end
    end

    -- Hide unused buttons
    for j = count + 1, #pickerButtons do
        pickerButtons[j]:Hide()
    end

    content:SetHeight(math.max(340, math.abs(yOffset) + 20))
    picker:Show()
end

-- =========================================================================
-- ⚡ 5. THE ULTIMATE SACRIFICE & EGG DISTRIBUTION
-- =========================================================================
StaticPopupDialogs["FOREVER_SAFARI_SACRIFICE_CONFIRM"] = {
    text = "|cffff3333THE ULTIMATE SACRIFICE|r\n\nAre you absolutely certain? Both parent companions will merge their life forces and be |cffff4444PERMANENTLY CONSUMED|r from your vault!\n\n1 purebred Safari Egg will be placed in your Safari Bag (/fsbag), with a 20%% chance of producing a 3rd bonus egg!\n\nThis action CANNOT be undone.",
    button1 = "Sacrifice & Breed",
    button2 = "Cancel",
    OnAccept = function()
        Nursery:ExecuteSacrifice()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function Nursery:PromptSacrificeConfirmation()
    local ok = Nursery:ValidatePair()
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Cannot commence: breeding prerequisites are not satisfied.|r")
        return
    end

    StaticPopup_Show("FOREVER_SAFARI_SACRIFICE_CONFIRM")
end

function Nursery:ExecuteSacrifice()
    local ok, famOk, rankOk, anatOk = Nursery:ValidatePair()
    if not ok then return end

    local fam = cand1.family or cand2.family or "Beast"
    local eggItemId = "safari_egg_" .. string.lower(fam)

    -- 20% Bonus Egg Roll
    local bonusRoll = (math.random(1, 100) <= 20)

    if not isCoopMode then
        -- Solo Mode: Both candidates consumed from local vault
        local name1 = cand1.customNickname or cand1.name or "Sire"
        local name2 = cand2.customNickname or cand2.name or "Dam"

        DB:RemoveMob(cand1.id)
        DB:RemoveMob(cand2.id)

        -- Guaranteed 2 eggs + 1 bonus if rolled
        local totalEggs = bonusRoll and 3 or 2
        DB:AddItem(eggItemId, totalEggs)

        PlaySound(1195) -- SOUNDKIT.UI_GARRISON_TOAST
        local bonusMsg = bonusRoll and " |cffffd100★ Lucky Clutch! A 3rd bonus Safari Egg was produced!|r" or ""

        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffa335ee[Sacred Breeding Complete!]|r %s and %s made the Ultimate Sacrifice! Awarded %d [Safari Eggs] (%s) to your Safari Bag (/fsbag)!%s",
            C.PREFIX, name1, name2, totalEggs, fam, bonusMsg))

        if ForeverSafari.Toast and ForeverSafari.Toast.ShowReward then
            ForeverSafari.Toast:ShowReward("Sacred Breeding Complete!", string.format("Produced %d purebred [%s Safari Eggs]!", totalEggs, fam))
        end

        cand1 = nil
        cand2 = nil
        Nursery:UpdateUI()
    else
        -- Co-op Mode: Local candidate consumed
        local myName = cand1.customNickname or cand1.name or "Companion"
        DB:RemoveMob(cand1.id)

        -- In co-op, guaranteed 1 egg to local player (+1 bonus if local player wins the 20% roll)
        local myEggs = 1
        local bonusWon = false
        if bonusRoll then
            -- 50/50 roll between local player and partner for the 3rd egg
            if math.random(1, 2) == 1 then
                myEggs = 2
                bonusWon = true
            end
        end

        DB:AddItem(eggItemId, myEggs)

        -- Notify partner via comms
        if partnerName and ns.Comms and ns.Comms.SendNurseryMessage then
            ns.Comms:SendNurseryMessage("NURSERY_CONFIRM", string.format("%s;%d", fam, bonusWon and 1 or (bonusRoll and 2 or 1)), partnerName)
        end

        PlaySound(1195)
        local bonusMsg = bonusWon and " |cffffd100★ Lucky Clutch! You received the 3rd bonus egg!|r" or ""
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffa335ee[Co-op Breeding Complete!]|r Your companion %s made the Ultimate Sacrifice! You received %d [%s Safari Egg(s)] in your Safari Bag (/fsbag)!%s",
            C.PREFIX, myName, myEggs, fam, bonusMsg))

        if ForeverSafari.Toast and ForeverSafari.Toast.ShowReward then
            ForeverSafari.Toast:ShowReward("Co-op Breeding Complete!", string.format("Received %d [%s Safari Egg(s)]!", myEggs, fam))
        end

        cand1 = nil
        cand2 = nil
        isCoopMode = false
        partnerName = nil
        Nursery:UpdateUI()
    end
end

-- =========================================================================
-- 🥚 6. EGG HATCHING & OFFSPRING GENERATION
-- =========================================================================
function Nursery:HatchEgg(eggItemId, itemData)
    local rawFam = itemData and itemData.family or eggItemId:match("^safari_egg_(.+)$") or "Beast"
    local famTitle = rawFam:gsub("^%l", string.upper)

    -- Consume 1 egg from bag
    if not DB:RemoveItem(eggItemId, 1) then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Failed to incubate: egg missing from bag.|r")
        return
    end

    -- Determine creature type
    local cType = "Beast"
    if famTitle == "Mechanical" then cType = "Mechanical"
    elseif famTitle == "Undead" then cType = "Undead"
    elseif famTitle == "Elemental" then cType = "Elemental"
    elseif famTitle == "Dragonkin" then cType = "Dragonkin"
    end

    -- Assign Anatomy (50% Sire, 50% Dam)
    local newbornAnatomy = (math.random(1, 2) == 1) and "Sire" or "Dam"

    -- High-pedigree purebred stats
    local newborn = {
        name = string.format("Purebred %s Offspring", famTitle),
        family = famTitle,
        creatureType = cType,
        level = 1,
        attunement = 0,
        attunementRank = 1,
        anatomy = newbornAnatomy,
        isPurebred = true,
        hp = 75,
        maxHp = 75,
        attack = 18,
        defense = 16,
        speed = 16,
        displayId = 903,
        abilities = {},
    }

    -- Populate 4 initial family-aligned abilities from MoveDB
    if ns.MoveDB and ns.MoveDB.MOVES then
        local found = 0
        for mKey, mData in pairs(ns.MoveDB.MOVES) do
            if mData.family == famTitle or mData.element == famTitle or mData.family == "Beast" then
                table.insert(newborn.abilities, mKey)
                found = found + 1
                if found >= 4 then break end
            end
        end
    end
    if #newborn.abilities == 0 then
        newborn.abilities = { "claw", "bite" }
    end

    -- Sign and store in collection
    if Crypto then Crypto:SignMob(newborn) end
    DB:AddMob(newborn, true)

    PlaySound(1195)
    local anatBadge = newborn.anatomy == "Dam" and "|cffff99cc♀ Dam|r" or "|cff66ccff♂ Sire|r"
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[Safari Egg Hatched!]|r A newborn purebred %s (%s) was born into your squad!",
        C.PREFIX, newborn.name, anatBadge))

    if ForeverSafari.Toast and ForeverSafari.Toast.ShowReward then
        ForeverSafari.Toast:ShowReward("Egg Hatched!", string.format("A newborn purebred %s (%s) was born!", famTitle, anatBadge))
    end

    -- Open 3D Inspector Frame to spotlight newborn
    if ForeverSafari.InspectorFrame and ForeverSafari.InspectorFrame.InspectCompanion then
        ForeverSafari.InspectorFrame:InspectCompanion(newborn)
    end
end

-- =========================================================================
-- 📡 7. CO-OP MULTIPLAYER COMMS DISPATCHERS
-- =========================================================================
function Nursery:ReceiveInvite(sender)
    isCoopMode = true
    partnerName = sender
    partnerReady = false
    myReady = false
    cand2 = nil

    Nursery:Show()
    if frame and frame.ModeBar and frame.ModeBar.PartnerLabel then
        frame.ModeBar.PartnerLabel:SetText(string.format("|cff00ff00Partner: %s|r", sender))
    end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffffd100%s|r invited you to the Moonglade Cenarion Nursery!", C.PREFIX, sender))
    Nursery:UpdateUI()
end

function Nursery:ReceivePartnerCandidate(sender, payload)
    if not isCoopMode or sender ~= partnerName then return end

    local name, fam, anatomy, rank, lvl, hp, dispId, isRare = strsplit(";", payload)
    cand2 = {
        name = name or "Partner Mate",
        family = fam or "Beast",
        anatomy = anatomy or "Dam",
        attunementRank = tonumber(rank) or 1,
        level = tonumber(lvl) or 1,
        hp = tonumber(hp) or 10,
        displayId = tonumber(dispId) or 903,
        isRare = (tonumber(isRare) == 1),
    }

    DEFAULT_CHAT_FRAME:AddMessage(string.format("%sPartner |cffffd100%s|r placed Candidate: |cffffd100%s|r (%s - %s) on the breeding pedestal.",
        C.PREFIX, sender, cand2.name, cand2.family, cand2.anatomy))
    Nursery:UpdateUI()
end

function Nursery:ReceivePartnerReady(sender, isReady)
    partnerReady = (isReady == "1")
    Nursery:UpdateUI()
end

function Nursery:ReceivePartnerSacrifice(sender, payload)
    local fam, bonusCount = strsplit(";", payload or "")
    local eggs = tonumber(bonusCount) or 1
    local eggItemId = "safari_egg_" .. string.lower(fam or "beast")

    DB:AddItem(eggItemId, eggs)
    PlaySound(1195)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffa335ee[Co-op Breeding Complete!]|r Partner confirmed ritual! You received %d [%s Safari Egg(s)] in your Safari Bag (/fsbag)!",
        C.PREFIX, eggs, fam or "Beast"))

    cand1 = nil
    cand2 = nil
    isCoopMode = false
    partnerName = nil
    Nursery:UpdateUI()
end

function Nursery:ReceivePartnerCancel(sender)
    cand2 = nil
    partnerReady = false
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%sPartner %s canceled the breeding session.", C.PREFIX, sender))
    Nursery:UpdateUI()
end

-- =========================================================================
-- 🏛️ 8. MOONGLADE CENARION NPC GOSSIP ANCHOR
-- =========================================================================
function Nursery:IsAtMoongladeCenarionNPC()
    local zone = GetZoneText and GetZoneText()
    local subzone = GetSubZoneText and GetSubZoneText()
    local inMoonglade = false

    if zone and (string.find(string.lower(zone), "moonglade", 1, true) or string.find(string.lower(zone), "nighthaven", 1, true)) then
        inMoonglade = true
    elseif subzone and (string.find(string.lower(subzone), "moonglade", 1, true) or string.find(string.lower(subzone), "nighthaven", 1, true)) then
        inMoonglade = true
    end

    local unit = UnitExists("npc") and "npc" or (UnitExists("target") and "target" or nil)
    if not unit then return inMoonglade end

    local function isCenarion(text)
        if not text then return false end
        local l = string.lower(text)
        return string.find(l, "cenarion", 1, true) ~= nil or
               string.find(l, "keeper", 1, true) ~= nil or
               string.find(l, "remulos", 1, true) ~= nil or
               string.find(l, "loganaar", 1, true) ~= nil or
               string.find(l, "nursery", 1, true) ~= nil or
               string.find(l, "druid", 1, true) ~= nil
    end

    if inMoonglade then return true end

    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, info = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and info and info.lines then
            for _, line in ipairs(info.lines) do
                if line.leftText and isCenarion(line.leftText) then
                    return true
                end
            end
        end
    end

    local name = UnitName(unit)
    if name and isCenarion(name) then
        return true
    end

    return false
end

function Nursery:RegisterGossipEvents()
    local eventFrame = CreateFrame("Frame", "ForeverSafariNurseryGossipEvents")
    eventFrame:RegisterEvent("GOSSIP_SHOW")
    eventFrame:RegisterEvent("GOSSIP_CLOSED")

    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "GOSSIP_CLOSED" then
            isAtNurseryNPC = false
            if frame and frame:IsShown() and not isCoopMode then
                frame:Hide()
            end
        end
    end)
end

-- =========================================================================
-- 🖥️ 9. OPEN / CLOSE / SLASH COMMANDS
-- =========================================================================
function Nursery:Show()
    if not frame then Nursery:Initialize() end
    frame:Show()
    Nursery:UpdateUI()
    PlaySound(844) -- SOUNDKIT.IG_SPELLBOOK_OPEN
end

function Nursery:Hide()
    if frame and frame:IsShown() then
        frame:Hide()
        PlaySound(845)
    end
end

function Nursery:Toggle()
    if not frame then Nursery:Initialize() end
    if frame:IsShown() then
        Nursery:Hide()
    else
        Nursery:Show()
    end
end

-- Slash Commands
SLASH_FSNURSERY1 = "/fsnursery"
SLASH_FSNURSERY2 = "/fsbreed"
SLASH_FSNURSERY3 = "/safarinursery"
SlashCmdList["FSNURSERY"] = function()
    Nursery:Toggle()
end
