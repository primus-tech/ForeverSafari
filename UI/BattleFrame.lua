--[[
    Forever Safari: Retro Game Boy Style Battle Arena
    Features classic Pokémon battle layout with 3D paperdoll models,
    retro HP/EXP status boxes, animated battle sequences, and 2x2 command menus.
    Displays move cooldowns (CD) and limited battle usages (Uses: X/Y).
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.BattleFrame = ns.BattleFrame or {}

local BF = ns.BattleFrame
local C = ns.Constants
local DB = ns.Database
local BE = ns.BattleEngine
local Theme = ns.Theme

local frame = nil
local menuMode = "MAIN" -- "MAIN", "FIGHT", "BAG", "PARTY"
local moveButtons = {}
local bagButtons = {}
local partyButtons = {}

function BF:Initialize()
    -- Main Window Shell (Game Boy aspect ratio & retro slate styling)
    frame = CreateFrame("Frame", "ForeverSafariBattleFrame", UIParent, "BackdropTemplate")
    frame:SetSize(600, 460)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.08, 0.10, 0.14, 0.98)
    frame:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9)

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnHide", function(self)
        if BE and BE.State and BE.State.inBattle and BE.State.isPvP then
            if not BE.State.isPausedForWorldCombat then
                BE:ForfeitPvP("WINDOW_CLOSED")
            end
        end
    end)

    Theme:CreateCloseButton(frame)

    -- Top Header Banner
    local headerText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerText:SetPoint("TOPLEFT", 14, -10)
    headerText:SetText("|cffffd100Forever Safari|r  -  |cff00ff99WILD BATTLE|r")
    frame.HeaderText = headerText

    -- Battle Stage Arena Canvas (upper 300px)
    local stage = CreateFrame("Frame", "ForeverSafariBattleStage", frame)
    stage:SetSize(572, 300)
    stage:SetPoint("TOPLEFT", 14, -32)
    frame.Stage = stage

    -- =========================================================================
    -- TOP-LEFT: ENEMY STATUS BOX
    -- =========================================================================
    local enemyHUD = BF:CreateRetroStatusBox(stage, 230, 70, false)
    enemyHUD:SetPoint("TOPLEFT", stage, "TOPLEFT", 10, -10)
    frame.EnemyHUD = enemyHUD

    -- =========================================================================
    -- TOP-RIGHT: ENEMY 3D PAPERDOLL MODEL & PEDESTAL
    -- =========================================================================
    local enemyPedestal = stage:CreateTexture(nil, "BACKGROUND")
    enemyPedestal:SetSize(180, 50)
    enemyPedestal:SetPoint("CENTER", stage, "TOPRIGHT", -120, -170)
    enemyPedestal:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    enemyPedestal:SetVertexColor(0.15, 0.25, 0.20, 0.6)
    frame.EnemyPedestal = enemyPedestal

    local enemyModel = CreateFrame("PlayerModel", "ForeverSafariEnemy3DModel", stage)
    enemyModel:SetSize(190, 190)
    enemyModel:SetPoint("BOTTOM", enemyPedestal, "CENTER", 0, -15)
    enemyModel:SetRotation(math.rad(-35))
    frame.EnemyModel = enemyModel
    BF:SetupModelOverlay(enemyModel)

    local enemyIcon = stage:CreateTexture(nil, "ARTWORK")
    enemyIcon:SetSize(80, 80)
    enemyIcon:SetPoint("CENTER", enemyPedestal, "CENTER", 0, 30)
    enemyIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    enemyIcon:Hide()
    frame.EnemyIcon = enemyIcon

    -- =========================================================================
    -- BOTTOM-LEFT: PLAYER 3D PAPERDOLL MODEL & PEDESTAL
    -- =========================================================================
    local playerPedestal = stage:CreateTexture(nil, "BACKGROUND")
    playerPedestal:SetSize(210, 55)
    playerPedestal:SetPoint("CENTER", stage, "BOTTOMLEFT", 125, 45)
    playerPedestal:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    playerPedestal:SetVertexColor(0.12, 0.22, 0.18, 0.7)
    frame.PlayerPedestal = playerPedestal

    local playerModel = CreateFrame("PlayerModel", "ForeverSafariPlayer3DModel", stage)
    playerModel:SetSize(210, 210)
    playerModel:SetPoint("BOTTOM", playerPedestal, "CENTER", 0, -15)
    playerModel:SetRotation(math.rad(145))
    frame.PlayerModel = playerModel
    BF:SetupModelOverlay(playerModel)

    local playerIcon = stage:CreateTexture(nil, "ARTWORK")
    playerIcon:SetSize(80, 80)
    playerIcon:SetPoint("CENTER", playerPedestal, "CENTER", 0, 30)
    playerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    playerIcon:Hide()
    frame.PlayerIcon = playerIcon

    -- =========================================================================
    -- BOTTOM-RIGHT: PLAYER STATUS BOX (with EXP/HP)
    -- =========================================================================
    local playerHUD = BF:CreateRetroStatusBox(stage, 250, 86, true)
    playerHUD:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", -10, 15)
    frame.PlayerHUD = playerHUD

    -- =========================================================================
    -- LOWER CONSOLE: DIALOGUE BOX + COMMAND / FIGHT / BAG / PARTY PANELS
    -- =========================================================================
    local console = CreateFrame("Frame", "ForeverSafariBattleConsole", frame, "BackdropTemplate")
    console:SetSize(572, 115)
    console:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
    console:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    console:SetBackdropColor(0.05, 0.07, 0.10, 0.95)
    console:SetBackdropBorderColor(0.8, 0.85, 0.9, 0.8)
    frame.Console = console

    -- Turn Timeout Countdown Bar (15s Turn Timer)
    local turnTimerBar = CreateFrame("StatusBar", "ForeverSafariTurnTimerBar", console)
    turnTimerBar:SetSize(564, 7)
    turnTimerBar:SetPoint("BOTTOMLEFT", console, "TOPLEFT", 4, 3)
    turnTimerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    turnTimerBar:SetStatusBarColor(0.2, 0.8, 0.3)
    local timerBg = turnTimerBar:CreateTexture(nil, "BACKGROUND")
    timerBg:SetAllPoints()
    timerBg:SetColorTexture(0.06, 0.08, 0.10, 0.9)
    turnTimerBar.Bg = timerBg
    local timerText = turnTimerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerText:SetPoint("CENTER", turnTimerBar, "CENTER", 0, 0)
    timerText:SetFont(timerText:GetFont(), 9, "OUTLINE")
    timerText:SetText("")
    turnTimerBar.Text = timerText
    turnTimerBar:Hide()
    frame.TurnTimerBar = turnTimerBar

    -- Left: Scrolling Combat Log
    BF:BuildScrollingBattleLog(console)

    -- Right Panels Container (265px width)
    local menuContainer = CreateFrame("Frame", nil, console)
    menuContainer:SetSize(265, 105)
    menuContainer:SetPoint("RIGHT", console, "RIGHT", -10, 0)
    frame.MenuContainer = menuContainer

    -- Build Sub-Panels
    BF:BuildMainMenu(menuContainer)
    BF:BuildFightMenu(menuContainer)
    BF:BuildBagMenu(menuContainer)
    BF:BuildPartyMenu(menuContainer)
    BF:BuildEndBattleMenu(menuContainer)

    -- Build Left & Right Virtual Party Panels (hang off the sides of the arena)
    BF:BuildPartyPanels()

    frame:Hide()
end

-- =========================================================================
-- 3D MODEL VISUAL OVERLAYS (HIT FLASH & MISS FLICKER)
-- =========================================================================
function BF:SetupModelOverlay(model)
    if not model then return end
    local overlay = CreateFrame("Frame", nil, model)
    overlay:SetAllPoints(model)
    overlay:SetFrameLevel(model:GetFrameLevel() + 5)

    local tex = overlay:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(overlay)
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetBlendMode("ADD")
    tex:SetAlpha(0)
    tex:Hide()

    model.FlashOverlay = tex
    model.OverlayFrame = overlay
end

-- =========================================================================
-- LOWER CONSOLE: SCROLLING COMBAT LOG WINDOW
-- =========================================================================
function BF:BuildScrollingBattleLog(console)
    local logBox = CreateFrame("Frame", "ForeverSafariBattleLogContainer", console, "BackdropTemplate")
    logBox:SetSize(275, 105)
    logBox:SetPoint("LEFT", console, "LEFT", 10, 0)
    logBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    logBox:SetBackdropColor(0.03, 0.04, 0.06, 0.95)
    logBox:SetBackdropBorderColor(0.45, 0.50, 0.60, 0.75)
    frame.LogBox = logBox

    local logFrame = CreateFrame("ScrollingMessageFrame", "ForeverSafariBattleLogFrame", logBox)
    logFrame:SetSize(250, 95)
    logFrame:SetPoint("TOPLEFT", logBox, "TOPLEFT", 6, -5)
    logFrame:SetFontObject("GameFontHighlightSmall")
    logFrame:SetJustifyH("LEFT")
    logFrame:SetFading(false)
    logFrame:SetMaxLines(200)
    logFrame:SetSpacing(2)
    logFrame:EnableMouseWheel(true)
    frame.LogFrame = logFrame

    -- Backward-compatibility dummy FontString for dialogueText
    local dialogueText = logBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dialogueText:Hide()
    frame.DialogueText = dialogueText

    -- Scroll Controls
    local upBtn = CreateFrame("Button", nil, logBox)
    upBtn:SetSize(14, 14)
    upBtn:SetPoint("TOPRIGHT", logBox, "TOPRIGHT", -3, -5)
    local upText = upBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    upText:SetPoint("CENTER")
    upText:SetText("▲")
    upBtn:SetScript("OnClick", function()
        logFrame:ScrollUp()
        BF:UpdateLogScrollControls()
    end)
    frame.LogUpBtn = upBtn

    local downBtn = CreateFrame("Button", nil, logBox)
    downBtn:SetSize(14, 14)
    downBtn:SetPoint("BOTTOMRIGHT", logBox, "BOTTOMRIGHT", -3, 20)
    local downText = downBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    downText:SetPoint("CENTER")
    downText:SetText("▼")
    downBtn:SetScript("OnClick", function()
        logFrame:ScrollDown()
        BF:UpdateLogScrollControls()
    end)
    frame.LogDownBtn = downBtn

    local btmBtn = CreateFrame("Button", nil, logBox)
    btmBtn:SetSize(14, 14)
    btmBtn:SetPoint("BOTTOMRIGHT", logBox, "BOTTOMRIGHT", -3, 5)
    local btmText = btmBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btmText:SetPoint("CENTER")
    btmText:SetText("⤓")
    btmBtn:SetScript("OnClick", function()
        logFrame:ScrollToBottom()
        BF:UpdateLogScrollControls()
    end)
    frame.LogBtmBtn = btmBtn

    logFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
        else
            self:ScrollDown()
        end
        BF:UpdateLogScrollControls()
    end)
end

local function IsLogAtBottom(logFrame)
    if not logFrame then return true end
    if logFrame.AtBottom then
        local ok, val = pcall(logFrame.AtBottom, logFrame)
        if ok then return val end
    elseif logFrame.IsAtBottom then
        local ok, val = pcall(logFrame.IsAtBottom, logFrame)
        if ok then return val end
    end
    return true
end

function BF:UpdateLogScrollControls()
    if not frame or not frame.LogFrame then return end
    local isAtBottom = IsLogAtBottom(frame.LogFrame)
    if frame.LogBtmBtn then
        if isAtBottom then
            frame.LogBtmBtn:SetAlpha(0.3)
        else
            frame.LogBtmBtn:SetAlpha(1.0)
        end
    end
end

function BF:AddLogMessage(msg)
    if not frame or not frame.LogFrame then return end
    local wasAtBottom = IsLogAtBottom(frame.LogFrame)
    frame.LogFrame:AddMessage(msg)
    if wasAtBottom and frame.LogFrame.ScrollToBottom then
        pcall(frame.LogFrame.ScrollToBottom, frame.LogFrame)
    end
    BF:UpdateLogScrollControls()
end

function BF:ClearLog()
    if frame and frame.LogFrame then
        frame.LogFrame:Clear()
        BF:UpdateLogScrollControls()
    end
end

-- =========================================================================
-- VIRTUAL PARTY PANELS (PLAYER LEFT & OPPONENT RIGHT)
-- =========================================================================
function BF:BuildPartyPanels()
    -- -------------------------------------------------------------------------
    -- LEFT: VIRTUAL PLAYER PARTY FRAME
    -- -------------------------------------------------------------------------
    local playerParty = CreateFrame("Frame", "ForeverSafariPlayerParty", frame, "BackdropTemplate")
    playerParty:SetSize(155, 275)
    playerParty:SetPoint("TOPRIGHT", frame, "TOPLEFT", -8, -25)
    playerParty:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    playerParty:SetBackdropColor(0.06, 0.08, 0.12, 0.95)
    playerParty:SetBackdropBorderColor(0.2, 0.6, 1.0, 0.85)
    playerParty:Hide()
    frame.PlayerPartyFrame = playerParty

    local pTitle = playerParty:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pTitle:SetPoint("TOP", playerParty, "TOP", 0, -8)
    pTitle:SetText("|cff00ccffPLAYER PARTY|r")
    playerParty.Title = pTitle

    playerParty.slots = {}
    for i = 1, 5 do
        local slot = CreateFrame("Button", nil, playerParty, "BackdropTemplate")
        slot:SetSize(143, 46)
        slot:SetPoint("TOPLEFT", playerParty, "TOPLEFT", 6, -24 - (i - 1) * 49)
        slot:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        slot:SetBackdropColor(0.10, 0.13, 0.18, 0.9)
        slot:SetBackdropBorderColor(0.3, 0.35, 0.45, 0.8)

        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("LEFT", slot, "LEFT", 4, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot.Icon = icon

        local activeGlow = slot:CreateTexture(nil, "OVERLAY")
        activeGlow:SetSize(36, 36)
        activeGlow:SetPoint("CENTER", icon, "CENTER")
        activeGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        activeGlow:SetBlendMode("ADD")
        activeGlow:Hide()
        slot.ActiveGlow = activeGlow

        local nameText = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -1)
        nameText:SetPoint("RIGHT", slot, "RIGHT", -26, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        slot.NameText = nameText

        local rankText = slot:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        rankText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -1)
        rankText:SetJustifyH("LEFT")
        slot.RankText = rankText

        local hpBar = CreateFrame("StatusBar", nil, slot)
        hpBar:SetSize(95, 7)
        hpBar:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 6, 2)
        hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        hpBar:SetStatusBarColor(0.18, 0.80, 0.44)
        local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
        hpBg:SetAllPoints()
        hpBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        hpBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
        slot.HPBar = hpBar

        local hpVal = hpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hpVal:SetPoint("CENTER", hpBar, "CENTER", 0, 0)
        hpVal:SetFont(hpVal:GetFont(), 8, "OUTLINE")
        slot.HPVal = hpVal

        local koText = slot:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
        koText:SetPoint("CENTER", icon, "CENTER")
        koText:SetText("KO")
        koText:Hide()
        slot.KOText = koText

        -- Pre-Battle Designation Checkbox & Squad Status Badge
        local check = CreateFrame("CheckButton", nil, slot, "UICheckButtonTemplate")
        check:SetSize(18, 18)
        check:SetPoint("RIGHT", slot, "RIGHT", -2, 0)
        check.slotIndex = i
        check:SetScript("OnClick", function(self)
            BF:ToggleSlotDesignation(self.slotIndex)
        end)
        slot.DeployCheck = check

        local squadBadge = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        squadBadge:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -22, -3)
        squadBadge:SetFont(squadBadge:GetFont(), 7, "OUTLINE")
        squadBadge:SetText("")
        slot.SquadBadge = squadBadge

        slot.slotIndex = i
        slot:SetScript("OnClick", function(self)
            if not BE.State.combatStarted then
                BF:ToggleSlotDesignation(self.slotIndex)
            else
                local team = DB:GetTeam() or {}
                local mobId = team[self.slotIndex]
                if mobId then
                    local mob = type(mobId) == "table" and mobId or DB:GetMobById(mobId)
                    if mob then
                        if BE.State.designatedSquad and not BE.State.designatedSquad[mob.id] then
                            BE:AddLog(string.format("|cffff4444[Safari Battle]|r %s was benched for this match and cannot enter combat!|r", mob.nickname ~= "" and mob.nickname or mob.name))
                        elseif BE.State.turn == "player" then
                            BE:SwitchPlayerMob(mob.id)
                        end
                    end
                end
            end
        end)

        playerParty.slots[i] = slot
    end

    -- -------------------------------------------------------------------------
    -- RIGHT: VIRTUAL OPPONENT PARTY FRAME
    -- -------------------------------------------------------------------------
    local oppParty = CreateFrame("Frame", "ForeverSafariOpponentParty", frame, "BackdropTemplate")
    oppParty:SetSize(155, 275)
    oppParty:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, -25)
    oppParty:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    oppParty:SetBackdropColor(0.06, 0.08, 0.12, 0.95)
    oppParty:SetBackdropBorderColor(1.0, 0.35, 0.2, 0.85)
    oppParty:Hide()
    frame.OpponentPartyFrame = oppParty

    local oTitle = oppParty:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    oTitle:SetPoint("TOP", oppParty, "TOP", 0, -8)
    oTitle:SetText("|cffff5533OPPONENT SQUAD|r")
    oppParty.Title = oTitle

    oppParty.slots = {}
    for i = 1, 5 do
        local slot = CreateFrame("Button", nil, oppParty, "BackdropTemplate")
        slot:SetSize(143, 46)
        slot:SetPoint("TOPLEFT", oppParty, "TOPLEFT", 6, -24 - (i - 1) * 49)
        slot:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        slot:SetBackdropColor(0.14, 0.09, 0.10, 0.9)
        slot:SetBackdropBorderColor(0.5, 0.3, 0.3, 0.8)

        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("LEFT", slot, "LEFT", 4, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot.Icon = icon

        -- Target Selection Reticle / Golden Border
        local targetGlow = slot:CreateTexture(nil, "OVERLAY")
        targetGlow:SetAllPoints(slot)
        targetGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        targetGlow:SetBlendMode("ADD")
        targetGlow:SetVertexColor(1.0, 0.82, 0.0, 0.8)
        targetGlow:Hide()
        slot.TargetGlow = targetGlow

        local activeGlow = slot:CreateTexture(nil, "OVERLAY")
        activeGlow:SetSize(36, 36)
        activeGlow:SetPoint("CENTER", icon, "CENTER")
        activeGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        activeGlow:SetBlendMode("ADD")
        activeGlow:Hide()
        slot.ActiveGlow = activeGlow

        local nameText = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -1)
        nameText:SetPoint("RIGHT", slot, "RIGHT", -4, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        slot.NameText = nameText

        local rankText = slot:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        rankText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -1)
        rankText:SetJustifyH("LEFT")
        slot.RankText = rankText

        local hpBar = CreateFrame("StatusBar", nil, slot)
        hpBar:SetSize(95, 7)
        hpBar:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 6, 2)
        hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        hpBar:SetStatusBarColor(0.18, 0.80, 0.44)
        local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
        hpBg:SetAllPoints()
        hpBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        hpBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
        slot.HPBar = hpBar

        local hpVal = hpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hpVal:SetPoint("CENTER", hpBar, "CENTER", 0, 0)
        hpVal:SetFont(hpVal:GetFont(), 8, "OUTLINE")
        slot.HPVal = hpVal

        local koText = slot:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
        koText:SetPoint("CENTER", icon, "CENTER")
        koText:SetText("KO")
        koText:Hide()
        slot.KOText = koText

        -- Clicking an opponent slot selects them as active target
        slot.slotIndex = i
        slot:SetScript("OnClick", function(self)
            if BE.SelectTarget then
                BE:SelectTarget(self.slotIndex)
            end
        end)

        slot:SetScript("OnEnter", function(self)
            local oppTeam = BE.State.enemyTeam or {}
            local eMob = oppTeam[self.slotIndex]
            if eMob then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local eName = eMob.nickname ~= "" and eMob.nickname or eMob.name
                GameTooltip:AddLine(eName, 1, 0.82, 0)
                GameTooltip:AddLine(string.format("Rank %s %s", eMob.attunementRank or eMob.rank or 1, eMob.creatureType or "Beast"), 0.8, 0.8, 0.8)
                GameTooltip:AddLine(string.format("Health: %d / %d", eMob.currentHP or eMob.hp or 10, eMob.maxHP or eMob.hp or 10), 0.2, 1, 0.2)
                GameTooltip:AddLine("|cffffd100Click to focus target|r", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

        oppParty.slots[i] = slot
    end
end

-- Helper: Get squad capacity quota based on group size
function BF:GetSquadQuota()
    if BE.State and BE.State.squadQuota then
        return BE.State.squadQuota
    end
    if BE.GetSquadQuota then
        return BE:GetSquadQuota()
    end
    return 5
end

-- Pre-Battle Squad Designation Toggle
function BF:ToggleSlotDesignation(slotIndex)
    if BE.State.combatStarted then return end
    local team = DB:GetTeam() or {}
    local mobId = team[slotIndex]
    if not mobId then return end
    local mob = type(mobId) == "table" and mobId or DB:GetMobById(mobId)
    if not mob or (mob.currentHP or 0) <= 0 then
        BE:AddLog("|cffff4444[Squad Designation]|r You cannot deploy a fainted companion!|r")
        return
    end

    BE.State.designatedSquad = BE.State.designatedSquad or {}
    local quota = BF:GetSquadQuota()
    local mName = mob.nickname ~= "" and mob.nickname or mob.name

    if BE.State.designatedSquad[mob.id] then
        local count = 0
        for _ in pairs(BE.State.designatedSquad) do count = count + 1 end
        if count <= 1 then
            BE:AddLog("|cffffaa00[Squad Designation]|r You must have at least 1 companion deployed!|r")
            return
        end
        BE.State.designatedSquad[mob.id] = nil
        BE:AddLog(string.format("|cffaaaaaa[Squad Designation]|r Benched %s.|r", mName))
    else
        local count = 0
        for _ in pairs(BE.State.designatedSquad) do count = count + 1 end
        if count >= quota then
            BE:AddLog(string.format("|cffffcc00[Squad Designation]|r Squad quota reached! (Maximum %d companions for this encounter)|r", quota))
            return
        end
        BE.State.designatedSquad[mob.id] = true
        BE:AddLog(string.format("|cff00ff99[Squad Designation]|r Deployed %s to active squad!|r", mName))
    end

    -- If activePlayerMob was un-designated, switch active to first designated
    if BE.State.playerMob and not BE.State.designatedSquad[BE.State.playerMob.id] then
        for _, id in ipairs(team) do
            local m = type(id) == "table" and id or DB:GetMobById(id)
            if m and BE.State.designatedSquad[m.id] and (m.currentHP or 0) > 0 then
                BE.State.playerMob = m
                BE:InitMoveStates(m, "player")
                BF:UpdateModels()
                break
            end
        end
    end

    BF:UpdatePartyFrames()
    BF:UpdateUI()
end

-- Turn Timer Visual Methods
function BF:StartTurnCountdown(duration)
    if not frame or not frame.TurnTimerBar then return end
    duration = duration or 15
    local bar = frame.TurnTimerBar
    bar:SetMinMaxValues(0, duration)
    bar:SetValue(duration)
    bar:SetStatusBarColor(0.2, 0.8, 0.3)
    bar.Text:SetText(string.format("Turn Timer: %ds", duration))
    bar:Show()
end

function BF:UpdateTurnTimer(remaining, total)
    if not frame or not frame.TurnTimerBar then return end
    total = total or 15
    local bar = frame.TurnTimerBar
    bar:SetValue(math.max(0, remaining))
    local pct = remaining / total
    if pct > 0.5 then
        bar:SetStatusBarColor(0.2, 0.8, 0.3)
    elseif pct > 0.25 then
        bar:SetStatusBarColor(0.9, 0.7, 0.1)
    else
        bar:SetStatusBarColor(0.9, 0.2, 0.2)
    end
    bar.Text:SetText(string.format("Turn Timer: %ds", math.max(0, math.ceil(remaining))))
end

function BF:UpdateTimerBar(remaining, total)
    BF:UpdateTurnTimer(remaining, total or 15)
end

function BF:HideTurnTimer()
    if frame and frame.TurnTimerBar then
        frame.TurnTimerBar:Hide()
    end
end

function BF:UpdatePartyFrames()
    if not frame or not frame:IsShown() then return end

    -- Update Player Party Slots (up to 5)
    local team = DB:GetTeam() or {}
    local activePlayerMob = BE.State.playerMob
    local isCombatStarted = BE.State.combatStarted

    if frame.PlayerPartyFrame and frame.PlayerPartyFrame.Title then
        if not isCombatStarted then
            local count = 0
            if BE.State.designatedSquad then
                for _ in pairs(BE.State.designatedSquad) do count = count + 1 end
            end
            local quota = BF:GetSquadQuota()
            frame.PlayerPartyFrame.Title:SetText(string.format("|cff00ccffDEPLOY SQUAD (%d/%d)|r", count, quota))
        else
            frame.PlayerPartyFrame.Title:SetText("|cff00ccffPLAYER PARTY|r")
        end
    end

    for i = 1, 5 do
        local slot = frame.PlayerPartyFrame and frame.PlayerPartyFrame.slots[i]
        local mobId = team[i]
        local mob = mobId and (type(mobId) == "table" and mobId or DB:GetMobById(mobId))
        if mob and slot then
            local pName = mob.nickname ~= "" and mob.nickname or mob.name
            slot.NameText:SetText(pName)
            local mRank = mob.attunementRank or 1
            local mRoman = (C.ATTUNEMENT_RANKS[mRank] and C.ATTUNEMENT_RANKS[mRank].roman) or "I"
            slot.RankText:SetText(string.format("Rank %s %s", mRoman, mob.creatureType or "Beast"))

            local curHP = mob.currentHP or mob.hp or 10
            local maxHP = mob.maxHP or mob.hp or 10
            slot.HPBar:SetMinMaxValues(0, maxHP)
            slot.HPBar:SetValue(curHP)
            slot.HPVal:SetText(string.format("%d/%d", curHP, maxHP))

            local pct = maxHP > 0 and (curHP / maxHP) * 100 or 0
            if pct > 50 then
                slot.HPBar:SetStatusBarColor(0.18, 0.80, 0.44)
            elseif pct > 25 then
                slot.HPBar:SetStatusBarColor(0.95, 0.75, 0.10)
            else
                slot.HPBar:SetStatusBarColor(0.90, 0.20, 0.20)
            end

            local iconPath = mob.icon or C.GetDefaultIcon(mob.family or mob.creatureType) or "Interface\\Icons\\INV_Box_PetCarrier_01"
            slot.Icon:SetTexture(iconPath)

            local isDesignated = (not BE.State.designatedSquad) or BE.State.designatedSquad[mob.id]

            if slot.DeployCheck then
                slot.DeployCheck:Show()
                if not isCombatStarted then
                    slot.DeployCheck:Enable()
                    slot.DeployCheck:SetChecked(isDesignated)
                else
                    slot.DeployCheck:Disable()
                    slot.DeployCheck:SetChecked(isDesignated)
                end
            end

            if curHP <= 0 then
                slot.Icon:SetDesaturated(true)
                slot.KOText:Show()
                slot.ActiveGlow:Hide()
                slot:SetAlpha(0.50)
                slot:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.4)
                if slot.SquadBadge then
                    slot.SquadBadge:SetText("|cffff2222[FAINTED]|r")
                end
            else
                slot.Icon:SetDesaturated(false)
                slot.KOText:Hide()

                if not isCombatStarted then
                    if isDesignated then
                        slot:SetAlpha(1.0)
                        slot:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                        if slot.SquadBadge then
                            slot.SquadBadge:SetText("|cff00ff99[DEPLOYED]|r")
                        end
                    else
                        slot:SetAlpha(0.60)
                        slot:SetBackdropBorderColor(0.25, 0.3, 0.4, 0.6)
                        if slot.SquadBadge then
                            slot.SquadBadge:SetText("|cff888888[BENCH]|r")
                        end
                    end
                else
                    if not isDesignated then
                        slot:SetAlpha(0.40)
                        slot:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.4)
                        slot.ActiveGlow:Hide()
                        if slot.SquadBadge then
                            slot.SquadBadge:SetText("|cff777777[BENCH]|r")
                        end
                    else
                        slot:SetAlpha(1.0)
                        if activePlayerMob and mob.id == activePlayerMob.id then
                            slot.ActiveGlow:Show()
                            slot:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                            if slot.SquadBadge then
                                slot.SquadBadge:SetText("|cffffcc00[ACTIVE]|r")
                            end
                        else
                            slot.ActiveGlow:Hide()
                            slot:SetBackdropBorderColor(0.3, 0.6, 0.9, 0.8)
                            if slot.SquadBadge then
                                slot.SquadBadge:SetText("|cff00ccff[RESERVE]|r")
                            end
                        end
                    end
                end
            end
            slot:Show()
        elseif slot then
            slot:Hide()
        end
    end

    -- Update Opponent Party Slots (up to 5)
    local oppTeam = BE.State.enemyTeam or {}
    if #oppTeam == 0 and BE.State.enemyMob then
        oppTeam = { BE.State.enemyMob }
    end
    local activeEnemyMob = BE.State.enemyMob
    local selectedTargetIdx = BE.State.selectedTargetIndex or 1

    for i = 1, 5 do
        local slot = frame.OpponentPartyFrame and frame.OpponentPartyFrame.slots[i]
        local eMob = oppTeam[i]
        if eMob and slot then
            local eName = eMob.nickname ~= "" and eMob.nickname or eMob.name
            slot.NameText:SetText(eName)
            local eRank = eMob.attunementRank or eMob.rank or 1
            local eRoman = type(eRank) == "number" and (C.ATTUNEMENT_RANKS[eRank] and C.ATTUNEMENT_RANKS[eRank].roman or "I") or tostring(eRank)
            slot.RankText:SetText(string.format("Rank %s %s", eRoman, eMob.creatureType or "Beast"))

            local curHP = eMob.currentHP or eMob.hp or 10
            local maxHP = eMob.maxHP or eMob.hp or 10
            slot.HPBar:SetMinMaxValues(0, maxHP)
            slot.HPBar:SetValue(curHP)
            slot.HPVal:SetText(string.format("%d/%d", curHP, maxHP))

            local pct = maxHP > 0 and (curHP / maxHP) * 100 or 0
            if pct > 50 then
                slot.HPBar:SetStatusBarColor(0.18, 0.80, 0.44)
            elseif pct > 25 then
                slot.HPBar:SetStatusBarColor(0.95, 0.75, 0.10)
            else
                slot.HPBar:SetStatusBarColor(0.90, 0.20, 0.20)
            end

            local iconPath = eMob.icon or C.GetDefaultIcon(eMob.family or eMob.creatureType) or "Interface\\Icons\\INV_Box_PetCarrier_01"
            slot.Icon:SetTexture(iconPath)

            if curHP <= 0 then
                slot.Icon:SetDesaturated(true)
                slot.KOText:Show()
                slot.ActiveGlow:Hide()
                slot.TargetGlow:Hide()
                slot:SetAlpha(0.6)
            else
                slot.Icon:SetDesaturated(false)
                slot.KOText:Hide()
                slot:SetAlpha(1.0)
                if activeEnemyMob and (eMob == activeEnemyMob or eMob.name == activeEnemyMob.name) then
                    slot.ActiveGlow:Show()
                else
                    slot.ActiveGlow:Hide()
                end

                if i == selectedTargetIdx then
                    slot.TargetGlow:Show()
                    slot:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                else
                    slot.TargetGlow:Hide()
                    slot:SetBackdropBorderColor(0.5, 0.3, 0.3, 0.8)
                end
            end
            slot:Show()
        elseif slot then
            slot:Hide()
        end
    end
end

function BF:UpdateTargetSelection()
    if not frame or not frame.OpponentPartyFrame then return end
    local selectedTargetIdx = BE.State.selectedTargetIndex or 1
    for i = 1, 5 do
        local slot = frame.OpponentPartyFrame.slots[i]
        if slot and slot:IsShown() then
            if i == selectedTargetIdx then
                slot.TargetGlow:Show()
                slot:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
            else
                slot.TargetGlow:Hide()
                slot:SetBackdropBorderColor(0.5, 0.3, 0.3, 0.8)
            end
        end
    end
end

function BF:UpdatePartyFramesVisibility()
    if not frame or not frame:IsShown() then return end
    local enemyTeam = BE.State.enemyTeam or {}
    local playerTeam = DB:GetTeam() or {}
    local isMulti = (#enemyTeam > 1) or (#playerTeam > 1) or BE.State.isPartyBattle or BE.State.isTrainerBattle or BE.State.isOutpostBattle
    if isMulti then
        if frame.PlayerPartyFrame then frame.PlayerPartyFrame:Show() end
        if frame.OpponentPartyFrame then frame.OpponentPartyFrame:Show() end
        BF:UpdatePartyFrames()
    else
        if frame.PlayerPartyFrame then frame.PlayerPartyFrame:Hide() end
        if frame.OpponentPartyFrame then frame.OpponentPartyFrame:Hide() end
    end
end

-- Helper: Create Status HUD Box
function BF:CreateRetroStatusBox(parent, width, height, isPlayer)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    box:SetBackdropColor(0.07, 0.09, 0.12, 0.90)
    box:SetBackdropBorderColor(0.9, 0.9, 0.9, 0.85)

    -- Creature Name
    local nameText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("TOPLEFT", 8, -6)
    nameText:SetText(isPlayer and "COMPANION" or "ENEMY")
    box.NameText = nameText

    -- Attunement Rank badge
    local levelText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    levelText:SetPoint("TOPRIGHT", -8, -6)
    levelText:SetText("")
    box.LevelText = levelText

    -- HP Bar Label
    local hpLabel = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hpLabel:SetPoint("TOPLEFT", 8, -26)
    hpLabel:SetText("|cffffcc00HP:|r")
    box.HPLabel = hpLabel

    -- HP Bar
    local hpBar = CreateFrame("StatusBar", nil, box)
    hpBar:SetSize(width - 45, 10)
    hpBar:SetPoint("LEFT", hpLabel, "RIGHT", 6, 0)
    hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hpBar:SetStatusBarColor(0.18, 0.80, 0.44)

    local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    box.HPBar = hpBar

    -- Numeric HP & EXP display (Player only)
    if isPlayer then
        local hpValText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hpValText:SetPoint("TOPRIGHT", hpBar, "BOTTOMRIGHT", 0, -2)
        hpValText:SetText("100 / 100")
        box.HPValText = hpValText

        local expLabel = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        expLabel:SetPoint("TOPLEFT", 8, -50)
        expLabel:SetText("|cffaa44ffXP:|r")

        local expBar = CreateFrame("StatusBar", nil, box)
        expBar:SetSize(width - 45, 6)
        expBar:SetPoint("LEFT", expLabel, "RIGHT", 6, 0)
        expBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        expBar:SetStatusBarColor(0.65, 0.30, 0.90)
        local expBg = expBar:CreateTexture(nil, "BACKGROUND")
        expBg:SetAllPoints()
        expBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
        box.ExpBar = expBar

        local eclipseText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        eclipseText:SetPoint("TOPLEFT", 8, -66)
        eclipseText:SetText("")
        box.EclipseText = eclipseText
    else
        -- Virtual Duo Dual-Line Ecliptic Indicators
        local solarText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        solarText:SetPoint("TOPLEFT", 8, -40)
        solarText:SetText("")
        solarText:Hide()
        box.TwinsSolarText = solarText

        local lunarText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lunarText:SetPoint("TOPLEFT", 8, -56)
        lunarText:SetText("")
        lunarText:Hide()
        box.TwinsLunarText = lunarText
    end

    return box
end

-- =========================================================================
-- MENU 1: MAIN 2x2 COMMAND MENU (FIGHT | BAG / TEAM | RUN)
-- =========================================================================
function BF:BuildMainMenu(parent)
    local p = CreateFrame("Frame", "ForeverSafariBattleMainMenu", parent)
    p:SetAllPoints()
    frame.MainMenu = p

    local btnFight = Theme:CreateButton(p, "FIGHT", 124, 36, true)
    btnFight:SetPoint("TOPLEFT", 4, -8)
    btnFight:SetScript("OnClick", function() BF:SetMenuMode("FIGHT") end)

    local btnBag = Theme:CreateButton(p, "BAG", 124, 36)
    btnBag:SetPoint("TOPRIGHT", -4, -8)
    btnBag:SetScript("OnClick", function() BF:SetMenuMode("BAG") end)

    local btnParty = Theme:CreateButton(p, "TEAM", 124, 36)
    btnParty:SetPoint("BOTTOMLEFT", 4, 12)
    btnParty:SetScript("OnClick", function() BF:SetMenuMode("PARTY") end)

    local btnRun = Theme:CreateButton(p, "RUN", 124, 36)
    btnRun:SetPoint("BOTTOMRIGHT", -4, 12)
    btnRun:SetScript("OnClick", function()
        BE:RunAway()
    end)

    -- 🌿 Priest Class Passive: Divine Grace Action Button
    local btnGrace = CreateFrame("Button", "ForeverSafariBattleGraceBtn", p, "BackdropTemplate")
    btnGrace:SetSize(256, 18)
    btnGrace:SetPoint("BOTTOM", p, "BOTTOM", 0, -8)
    btnGrace:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    btnGrace:SetBackdropColor(0.18, 0.12, 0.22, 0.95)
    btnGrace:SetBackdropBorderColor(1.0, 0.85, 0.4, 0.9)

    local graceText = btnGrace:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    graceText:SetPoint("CENTER", 0, 0)
    graceText:SetText("|cffffd100💖 Divine Grace (Heal 25%)|r")
    btnGrace.Text = graceText

    btnGrace:SetScript("OnClick", function()
        BE:UseDivineGrace()
    end)
    p.GraceBtn = btnGrace
    btnGrace:Hide()
end

-- =========================================================================
-- MENU 2: FIGHT MENU (4 Moves with Cooldowns & Uses Left)
-- =========================================================================
function BF:BuildFightMenu(parent)
    local p = CreateFrame("Frame", "ForeverSafariBattleFightMenu", parent)
    p:SetAllPoints()
    frame.FightMenu = p

    for i = 1, 4 do
        local btn = CreateFrame("Button", nil, p, "BackdropTemplate")
        btn:SetSize(124, 36)
        local col = ((i - 1) % 2)
        local row = math.floor((i - 1) / 2)
        btn:SetPoint("TOPLEFT", 4 + (col * 130), -4 - (row * 40))

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
        })
        btn:SetBackdropColor(0.12, 0.16, 0.22, 0.9)
        btn:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.8)

        local title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        title:SetPoint("TOPLEFT", 5, -3)
        title:SetPoint("TOPRIGHT", -5, -3)
        title:SetJustifyH("LEFT")
        btn.Title = title

        local info = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        info:SetPoint("BOTTOMLEFT", 5, 3)
        info:SetTextColor(0.7, 0.75, 0.8)
        btn.Info = info

        btn:SetScript("OnClick", function(self)
            if self.moveKey then
                BE:ExecutePlayerMove(self.moveKey)
                BF:SetMenuMode("MAIN")
            end
        end)

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(1.0, 1.0, 1.0, 1.0)
            if self.moveKey then
                local mState = BE.State.moveState.player and BE.State.moveState.player[self.moveKey]
                Theme:ShowAbilityTooltip(self, self.moveKey, "ANCHOR_TOP", mState, BE.State.enemyMob)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.8)
            Theme:HideAbilityTooltip()
        end)

        moveButtons[i] = btn
    end

    -- Back Button
    local backBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    backBtn:SetSize(65, 18)
    backBtn:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -4, 0)
    backBtn:SetText("< BACK")
    backBtn:SetScript("OnClick", function() BF:SetMenuMode("MAIN") end)

    p:Hide()
end

-- =========================================================================
-- MENU 3: BAG MENU (Nets & Consumables)
-- =========================================================================
function BF:BuildBagMenu(parent)
    local p = CreateFrame("Frame", "ForeverSafariBattleBagMenu", parent)
    p:SetAllPoints()
    frame.BagMenu = p

    local bagItems = { "copper_cage", "iron_cage", "mithril_cage", "thorium_trap", "healing_salve", "az_treat" }
    for i, id in ipairs(bagItems) do
        local btn = Theme:CreateButton(p, "", 124, 24)
        local col = ((i - 1) % 2)
        local row = math.floor((i - 1) / 2)
        btn:SetPoint("TOPLEFT", 4 + (col * 130), -2 - (row * 26))
        btn.itemId = id

        btn:SetScript("OnClick", function(self)
            BE:UseBagItem(self.itemId)
            BF:SetMenuMode("MAIN")
        end)

        bagButtons[i] = btn
    end

    -- Back Button
    local backBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    backBtn:SetSize(65, 18)
    backBtn:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -4, 0)
    backBtn:SetText("< BACK")
    backBtn:SetScript("OnClick", function() BF:SetMenuMode("MAIN") end)

    p:Hide()
end

-- =========================================================================
-- MENU 4: PARTY MENU (Switch Companion)
-- =========================================================================
function BF:BuildPartyMenu(parent)
    local p = CreateFrame("Frame", "ForeverSafariBattlePartyMenu", parent)
    p:SetAllPoints()
    frame.PartyMenu = p

    for i = 1, 4 do
        local btn = CreateFrame("Button", nil, p, "BackdropTemplate")
        btn:SetSize(124, 32)
        local col = ((i - 1) % 2)
        local row = math.floor((i - 1) / 2)
        btn:SetPoint("TOPLEFT", 4 + (col * 130), -6 - (row * 36))

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
        })
        btn:SetBackdropColor(0.12, 0.16, 0.22, 0.9)
        btn:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)

        local title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        title:SetPoint("LEFT", 6, 0)
        btn.Title = title

        btn:SetScript("OnClick", function(self)
            if self.mobId then
                BE:SwitchPlayerMob(self.mobId)
                BF:SetMenuMode("MAIN")
            end
        end)

        partyButtons[i] = btn
    end

    -- Back Button
    local backBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    backBtn:SetSize(80, 18)
    backBtn:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -4, 0)
    backBtn:SetText("< BACK")
    backBtn:SetScript("OnClick", function()
        if not BE.State.forcedSwitch then
            BF:SetMenuMode("MAIN")
        end
    end)
    p.BackBtn = backBtn

    p:Hide()
end

-- =========================================================================
-- MENU 5: END BATTLE MENU (Close / Return to Field)
-- =========================================================================
function BF:BuildEndBattleMenu(parent)
    local p = CreateFrame("Frame", "ForeverSafariBattleEndMenu", parent)
    p:SetAllPoints()
    frame.EndMenu = p

    local btnClose = Theme:CreateButton(p, "CLOSE BATTLE", 250, 48, true)
    btnClose:SetPoint("CENTER", p, "CENTER", 0, 0)
    btnClose:SetScript("OnClick", function()
        BF:Hide()
        PlaySound(856)
    end)
    p.CloseBtn = btnClose

    p:Hide()
end

-- Switch Menu Sub-Panels
function BF:SetMenuMode(mode)
    if not BE.State.inBattle then
        mode = "END"
    elseif BE.State.forcedSwitch and mode ~= "PARTY" then
        return
    end

    menuMode = mode
    frame.MainMenu:Hide()
    frame.FightMenu:Hide()
    frame.BagMenu:Hide()
    frame.PartyMenu:Hide()
    if frame.EndMenu then frame.EndMenu:Hide() end

    if mode == "END" or mode == "CLOSE" then
        if frame.EndMenu then frame.EndMenu:Show() end
    elseif mode == "FIGHT" then
        frame.FightMenu:Show()
    elseif mode == "BAG" then
        frame.BagMenu:Show()
    elseif mode == "PARTY" then
        frame.PartyMenu:Show()
    else
        frame.MainMenu:Show()
    end
    BF:UpdateUI()
    PlaySound(856)
end

-- Update 3D Models and Paperdoll Views
function BF:UpdateModels()
    if not frame or not frame:IsShown() then return end

    local enemy = BE.State.enemyMob
    if enemy and frame.EnemyModel then
        local enemyDisplay = (enemy.displayId and enemy.displayId > 0) and enemy.displayId or C.GetDefaultDisplayId(enemy.creatureType, enemy.name)
        if frame.EnemyModel.ClearModel then pcall(frame.EnemyModel.ClearModel, frame.EnemyModel) end
        if frame.EnemyModel.SetDisplayInfo then
            pcall(frame.EnemyModel.SetDisplayInfo, frame.EnemyModel, enemyDisplay)
        elseif frame.EnemyModel.SetCreatureByDisplayID then
            pcall(frame.EnemyModel.SetCreatureByDisplayID, frame.EnemyModel, enemyDisplay)
        end
        pcall(function()
            if frame.EnemyModel.SetCustomCamera then frame.EnemyModel:SetCustomCamera(0) end
            if frame.EnemyModel.SetPortraitZoom then frame.EnemyModel:SetPortraitZoom(0) end
            if frame.EnemyModel.SetCamDistanceScale then frame.EnemyModel:SetCamDistanceScale(1.0) end
            frame.EnemyModel:SetRotation(math.rad(-35))
            frame.EnemyModel:SetAnimation(0)
        end)
        frame.EnemyModel:Show()
    end

    local player = BE.State.playerMob
    if player and frame.PlayerModel then
        local playerDisplay = (player.displayId and player.displayId > 0) and player.displayId or C.GetDefaultDisplayId(player.creatureType, player.name)
        if frame.PlayerModel.ClearModel then pcall(frame.PlayerModel.ClearModel, frame.PlayerModel) end
        if frame.PlayerModel.SetDisplayInfo then
            pcall(frame.PlayerModel.SetDisplayInfo, frame.PlayerModel, playerDisplay)
        elseif frame.PlayerModel.SetCreatureByDisplayID then
            pcall(frame.PlayerModel.SetCreatureByDisplayID, frame.PlayerModel, playerDisplay)
        end
        pcall(function()
            if frame.PlayerModel.SetCustomCamera then frame.PlayerModel:SetCustomCamera(0) end
            if frame.PlayerModel.SetPortraitZoom then frame.PlayerModel:SetPortraitZoom(0) end
            if frame.PlayerModel.SetCamDistanceScale then frame.PlayerModel:SetCamDistanceScale(1.0) end
            frame.PlayerModel:SetRotation(math.rad(145))
            frame.PlayerModel:SetAnimation(0)
        end)
        frame.PlayerModel:Show()
    end
end

-- Animation Triggers
function BF:TriggerAttackAnimation(isPlayer)
    local model = isPlayer and frame.PlayerModel or frame.EnemyModel
    if model and model:IsShown() then
        model:SetAnimation(4)
        C_Timer.After(0.8, function()
            if model:IsShown() then model:SetAnimation(0) end
        end)
    end
end

function BF:TriggerHitAnimation(isPlayer)
    local model = isPlayer and frame.PlayerModel or frame.EnemyModel
    if not model or not model:IsShown() then return end

    model:SetAnimation(13)
    PlaySound(847)

    -- Model horizontal jolt / shake
    local origPoint, origRelTo, origRelPoint, origX, origY = model:GetPoint()
    local shakeElapsed = 0
    local shakeDuration = 0.25
    model:SetScript("OnUpdate", function(self, elapsed)
        shakeElapsed = shakeElapsed + elapsed
        if shakeElapsed < shakeDuration then
            local offset = math.sin(shakeElapsed * 45) * 5
            self:SetPoint(origPoint, origRelTo, origRelPoint, origX + offset, origY)
        else
            self:SetPoint(origPoint, origRelTo, origRelPoint, origX, origY)
            self:SetScript("OnUpdate", nil)
        end
    end)

    -- Luminous Crimson Red Flash Overlay
    local tex = model.FlashOverlay
    if tex and model.OverlayFrame then
        tex:SetVertexColor(1.0, 0.12, 0.12, 0.85)
        tex:Show()
        local flashElapsed = 0
        local flashDuration = 0.35
        model.OverlayFrame:SetScript("OnUpdate", function(self, elapsed)
            flashElapsed = flashElapsed + elapsed
            if flashElapsed < flashDuration then
                local a = (1.0 - (flashElapsed / flashDuration)) * 0.85
                tex:SetAlpha(a)
            else
                tex:SetAlpha(0)
                tex:Hide()
                self:SetScript("OnUpdate", nil)
            end
        end)
    end

    -- 3D Mesh Lighting Tint (crimson flash with neutral restore)
    pcall(model.SetLight, model, 1, 0, 0, 0, -1, 1, 1.0, 0.15, 0.15, 1.0, 1.0, 0.2, 0.2)
    C_Timer.After(0.35, function()
        if model:IsShown() then
            pcall(model.SetLight, model, 1, 0, 0, 0, -1, 1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
            model:SetAnimation(0)
        end
    end)
end

function BF:TriggerMissAnimation(isPlayer)
    local model = isPlayer and frame.PlayerModel or frame.EnemyModel
    if not model or not model:IsShown() then return end

    PlaySound(849)

    -- Evasion slip sideways
    local origPoint, origRelTo, origRelPoint, origX, origY = model:GetPoint()
    local slipDir = isPlayer and -8 or 8
    local slipElapsed = 0
    local slipDuration = 0.35
    model:SetScript("OnUpdate", function(self, elapsed)
        slipElapsed = slipElapsed + elapsed
        if slipElapsed < slipDuration then
            local p = slipElapsed / slipDuration
            local offset = math.sin(p * math.pi) * slipDir
            self:SetPoint(origPoint, origRelTo, origRelPoint, origX + offset, origY)
        else
            self:SetPoint(origPoint, origRelTo, origRelPoint, origX, origY)
            self:SetScript("OnUpdate", nil)
        end
    end)

    -- Arcade Yellow Flicker Strobe (rapid 3-pulse alpha oscillation)
    local tex = model.FlashOverlay
    if tex and model.OverlayFrame then
        tex:SetVertexColor(1.0, 0.90, 0.15, 0.85)
        tex:Show()
        local flickElapsed = 0
        local flickDuration = 0.40
        model.OverlayFrame:SetScript("OnUpdate", function(self, elapsed)
            flickElapsed = flickElapsed + elapsed
            if flickElapsed < flickDuration then
                local wave = math.abs(math.sin(flickElapsed * 24))
                tex:SetAlpha(wave * 0.9)
                model:SetAlpha(1.0 - (wave * 0.7))
            else
                tex:SetAlpha(0)
                tex:Hide()
                model:SetAlpha(1.0)
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end

function BF:UpdateLog()
    BF:UpdateUI()
end

-- Main Refresh Loop
function BF:UpdateUI()
    if not frame or not frame:IsShown() then return end

    -- Automatically switch to End Menu if battle is over
    if not BE.State.inBattle and menuMode ~= "END" then
        BF:SetMenuMode("END")
        return
    end

    local player = BE.State.playerMob
    local enemy = BE.State.enemyMob

    -- Update Header Banner Text
    if frame.HeaderText then
        if BE.State.isTrainerBattle and BE.State.enemyTrainer then
            local tTitle = BE.State.enemyTrainer.trainerTitle or "Rival Trainer"
            frame.HeaderText:SetText(string.format("|cffffd100Forever Safari|r  -  |cffffcc00TRAINER BATTLE: %s|r", tTitle))
        elseif BE.State.isPvP then
            frame.HeaderText:SetText("|cffffd100Forever Safari|r  -  |cffff8800PVP DUEL|r")
        else
            frame.HeaderText:SetText("|cffffd100Forever Safari|r  -  |cff00ff99WILD BATTLE|r")
        end
    end

    -- Update Dialogue Text
    frame.DialogueText:SetText(BE.State.dialogueText or "What will you do?")

    if enemy then
        frame.EnemyHUD.NameText:SetText(string.upper(enemy.name))
        local eRank = enemy.attunementRank or enemy.rank or 1
        local eRoman = type(eRank) == "number" and (C.ATTUNEMENT_RANKS[eRank] and C.ATTUNEMENT_RANKS[eRank].roman or "I") or tostring(eRank)
        frame.EnemyHUD.LevelText:SetText(string.format("Rank %s", eRoman))

        frame.EnemyHUD.HPBar:SetMinMaxValues(0, enemy.maxHP)
        frame.EnemyHUD.HPBar:SetValue(enemy.currentHP)

        local hpPct = (enemy.currentHP / enemy.maxHP) * 100
        if hpPct > 50 then
            frame.EnemyHUD.HPBar:SetStatusBarColor(0.18, 0.80, 0.44)
        elseif hpPct > 25 then
            frame.EnemyHUD.HPBar:SetStatusBarColor(0.95, 0.75, 0.10)
        else
            frame.EnemyHUD.HPBar:SetStatusBarColor(0.90, 0.20, 0.20)
        end

        -- Dual-Line Druid Ecliptic Meter for Virtual Duo
        if BE.State.isVirtualDuo and BE.State.twinsEclipse then
            frame.EnemyHUD:SetSize(230, 76)
            local te = BE.State.twinsEclipse
            if frame.EnemyHUD.TwinsSolarText then
                local sSurge = ""
                if (te.hotTurns or 0) > 0 then
                    sSurge = string.format(" |cff00ff99[Bloom: %dr]|r", te.hotTurns)
                end
                frame.EnemyHUD.TwinsSolarText:SetText(string.format("|cffffaa00☀️ Jarund Solar: %d/5|r%s", te.solar or 0, sSurge))
                frame.EnemyHUD.TwinsSolarText:Show()
            end
            if frame.EnemyHUD.TwinsLunarText then
                local lSurge = ""
                if (te.brambleTurns or 0) > 0 then
                    lSurge = string.format(" |cff3399ff[Brambles: %dr]|r", te.brambleTurns)
                end
                frame.EnemyHUD.TwinsLunarText:SetText(string.format("|cff66ccff🌙 Layo Lunar: %d/5|r%s", te.lunar or 0, lSurge))
                frame.EnemyHUD.TwinsLunarText:Show()
            end
        else
            frame.EnemyHUD:SetSize(230, 50)
            if frame.EnemyHUD.TwinsSolarText then frame.EnemyHUD.TwinsSolarText:Hide() end
            if frame.EnemyHUD.TwinsLunarText then frame.EnemyHUD.TwinsLunarText:Hide() end
        end
    end

    if player then
        local pName = string.upper(player.nickname ~= "" and player.nickname or player.name)
        frame.PlayerHUD.NameText:SetText(pName)
        local pRank = player.attunementRank or 1
        local pRoman = (C.ATTUNEMENT_RANKS[pRank] and C.ATTUNEMENT_RANKS[pRank].roman) or "I"
        frame.PlayerHUD.LevelText:SetText(string.format("Rank %s", pRoman))

        frame.PlayerHUD.HPBar:SetMinMaxValues(0, player.maxHP)
        frame.PlayerHUD.HPBar:SetValue(player.currentHP)
        frame.PlayerHUD.HPValText:SetText(string.format("%d/ %d", player.currentHP, player.maxHP))

        local phpPct = (player.currentHP / player.maxHP) * 100
        if phpPct > 50 then
            frame.PlayerHUD.HPBar:SetStatusBarColor(0.18, 0.80, 0.44)
        elseif phpPct > 25 then
            frame.PlayerHUD.HPBar:SetStatusBarColor(0.95, 0.75, 0.10)
        else
            frame.PlayerHUD.HPBar:SetStatusBarColor(0.90, 0.20, 0.20)
        end

        frame.PlayerHUD.ExpBar:SetMinMaxValues(0, player.maxXP or 100)
        frame.PlayerHUD.ExpBar:SetValue(player.xp or 0)

        -- Update Fight Menu Move Buttons (Uses: X/Y & CD status)
        local isPlayerTurn = (BE.State.turn == "player" and BE.State.inBattle)
        local playerMoves = player.abilities or player.moves or {}
        for i = 1, 4 do
            local btn = moveButtons[i]
            local moveKey = playerMoves[i]
            local m = (BE.GetMoveData and BE:GetMoveData(moveKey)) or (moveKey and ns.MoveDB and (ns.MoveDB[moveKey] or (tonumber(moveKey) and ns.MoveDB[tonumber(moveKey)])))
            if moveKey and m then
                local mState = BE.State.moveState.player and BE.State.moveState.player[moveKey]
                local maxU = m.maxUses or m.pp or 10
                local usesLeft = mState and mState.usesLeft or maxU
                local maxUses = mState and mState.maxUses or maxU
                local currentCD = mState and mState.currentCD or 0

                btn.moveKey = moveKey
                local role = m.role or (ns.MoveDB and ns.MoveDB:GetMoveRole(m)) or "Utility"
                local roleCol = (role == "Offensive") and "ffaa00" or ((role == "Defensive") and "66ccff" or ((role == "Healing") and "00ff99" or "d188ff"))
                local roleBadge = string.format("|cff%s[%s]|r", roleCol, string.sub(role, 1, 3))
                btn.Title:SetText(string.format("%s |cffffffff%s|r", roleBadge, m.name))

                -- Info line: CD status & remaining uses
                local cdText = (currentCD > 0) and string.format("|cffff4444CD:%d|r", currentCD) or "|cff00ff99READY|r"
                local usesColor = (usesLeft > 0) and "ffffff" or "ff4444"
                btn.Info:SetText(string.format("%s  |cff%s%d/%d|r", cdText, usesColor, usesLeft, maxUses))

                if isPlayerTurn and usesLeft > 0 and currentCD == 0 then
                    btn:Enable()
                    btn:SetAlpha(1.0)
                else
                    btn:Disable()
                    btn:SetAlpha(0.5)
                end
                btn:Show()
            else
                btn:Hide()
            end
        end

        -- Update Druid Ecliptic Tides status text
        if frame.PlayerHUD and frame.PlayerHUD.EclipseText then
            local CP = ns.ClassPassives
            if CP and CP:GetPlayerClass() == "DRUID" and BE.State.druidEclipse then
                local e = BE.State.druidEclipse
                local r = player.attunementRank or 1
                local surgeStatus = ""
                if (e.hotTurns or 0) > 0 then
                    surgeStatus = string.format(" |cff00ff99[Bloom: %dr]|r", e.hotTurns)
                elseif (e.brambleTurns or 0) > 0 then
                    surgeStatus = string.format(" |cff3399ff[Brambles: %dr]|r", e.brambleTurns)
                end
                frame.PlayerHUD.EclipseText:SetText(string.format("|cffffaa00☀️ %d/%d|r  |cff66ccff🌙 %d/%d|r%s", e.solar or 0, r, e.lunar or 0, r, surgeStatus))
                frame.PlayerHUD.EclipseText:Show()
            else
                frame.PlayerHUD.EclipseText:Hide()
            end
        end
    end

    -- Update Bag Buttons
    for i, btn in ipairs(bagButtons) do
        local id = btn.itemId
        local count = DB:GetItemCount(id)
        local ItemDB = ns.ItemDB
        local itemData = ItemDB and ((ItemDB.CAGES and ItemDB.CAGES[id]) or (ItemDB.ITEMS and ItemDB.ITEMS[id]))
        if itemData then
            btn:SetText(string.format("%s (x%d)", itemData.name, count))
            if count > 0 and BE.State.turn == "player" and BE.State.inBattle then
                btn:Enable()
            else
                btn:Disable()
            end
        end
    end

    -- Update Party Menu Back Button
    if frame.PartyMenu and frame.PartyMenu.BackBtn then
        if BE.State.forcedSwitch then
            frame.PartyMenu.BackBtn:Disable()
            frame.PartyMenu.BackBtn:SetText("SELECT PET")
        else
            frame.PartyMenu.BackBtn:Enable()
            frame.PartyMenu.BackBtn:SetText("< BACK")
        end
    end

    -- Priest Divine Grace Action Refresh
    local CP = ns.ClassPassives
    if CP and CP:GetPlayerClass() == "PRIEST" and frame.MainMenu and frame.MainMenu.GraceBtn then
        local maxUses = CP:GetPriestMaxHeals(player and player.attunementRank or 1, "PRIEST", BE.State.opponentClass)
        local used = BE.State.priestHealUses or 0
        local left = math.max(0, maxUses - used)
        frame.MainMenu.GraceBtn.Text:SetText(string.format("|cffffd100💖 Divine Grace (%d/%d left)|r", left, maxUses))
        frame.MainMenu.GraceBtn:SetShown(left > 0 and BE.State.turn == "player" and menuMode == "MAIN")
    elseif frame.MainMenu and frame.MainMenu.GraceBtn then
        frame.MainMenu.GraceBtn:Hide()
    end

    -- Update Party Buttons
    local team = DB:GetTeam()
    for i = 1, 4 do
        local btn = partyButtons[i]
        local mobId = team[i]
        local mob = mobId and (type(mobId) == "table" and mobId or DB:GetMobById(mobId))
        if mob then
            btn.mobId = mob.id
            local pName = mob.nickname ~= "" and mob.nickname or mob.name
            local isDesignated = (not BE.State.designatedSquad) or BE.State.designatedSquad[mob.id]
            if player and mob.id == player.id then
                btn:Disable()
                if (mob.currentHP or 0) <= 0 then
                    btn.Title:SetText(string.format("|cffff4444%s (KO'd)|r", pName))
                else
                    btn.Title:SetText(string.format("|cff00ff00%s (Active)|r", pName))
                end
            elseif not isDesignated then
                btn:Disable()
                btn.Title:SetText(string.format("|cff888888%s (Benched)|r", pName))
            elseif (mob.currentHP or 0) <= 0 then
                btn:Disable()
                btn.Title:SetText(string.format("|cffff4444%s (KO'd)|r", pName))
            else
                btn:Enable()
                local mRank = mob.attunementRank or 1
                local mRoman = (C.ATTUNEMENT_RANKS[mRank] and C.ATTUNEMENT_RANKS[mRank].roman) or "I"
                btn.Title:SetText(string.format("|cffffffff%s|r |cff00ff99Rank %s (%d/%d)|r", pName, mRoman, mob.currentHP or mob.hp or 10, mob.maxHP or mob.hp or 10))
            end
            btn:Show()
        else
            btn.mobId = nil
            btn:Hide()
        end
    end

    BF:UpdatePartyFramesVisibility()
end

function BF:ShowBattle()
    if not frame then BF:Initialize() end
    BF:ClearLog()
    if BE.State and BE.State.logs then
        for _, logLine in ipairs(BE.State.logs) do
            BF:AddLogMessage(logLine)
        end
    end
    frame:Show()
    BF:SetMenuMode("MAIN")
    BF:UpdateModels()
    BF:UpdateUI()
    BF:UpdatePartyFramesVisibility()
    PlaySound(1194)
end

function BF:Hide()
    if frame then frame:Hide() end
end

function BF:IsShown()
    return frame and frame:IsShown()
end
