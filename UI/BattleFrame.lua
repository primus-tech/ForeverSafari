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

    local enemyModel = CreateFrame("PlayerModel", "ForeverSafariEnemy3DModel", stage)
    enemyModel:SetSize(190, 190)
    enemyModel:SetPoint("BOTTOM", enemyPedestal, "CENTER", 0, -15)
    enemyModel:SetRotation(math.rad(-35))
    frame.EnemyModel = enemyModel

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

    local playerModel = CreateFrame("PlayerModel", "ForeverSafariPlayer3DModel", stage)
    playerModel:SetSize(210, 210)
    playerModel:SetPoint("BOTTOM", playerPedestal, "CENTER", 0, -15)
    playerModel:SetRotation(math.rad(145))
    frame.PlayerModel = playerModel

    local playerIcon = stage:CreateTexture(nil, "ARTWORK")
    playerIcon:SetSize(80, 80)
    playerIcon:SetPoint("CENTER", playerPedestal, "CENTER", 0, 30)
    playerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    playerIcon:Hide()
    frame.PlayerIcon = playerIcon

    -- =========================================================================
    -- BOTTOM-RIGHT: PLAYER STATUS BOX (with EXP/HP)
    -- =========================================================================
    local playerHUD = BF:CreateRetroStatusBox(stage, 250, 80, true)
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

    -- Left: Dialogue Text Box
    local dialogueBox = CreateFrame("Frame", nil, console)
    dialogueBox:SetSize(275, 105)
    dialogueBox:SetPoint("LEFT", console, "LEFT", 10, 0)

    local dialogueText = dialogueBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    dialogueText:SetPoint("TOPLEFT", 6, -10)
    dialogueText:SetPoint("BOTTOMRIGHT", -6, 10)
    dialogueText:SetJustifyH("LEFT")
    dialogueText:SetJustifyV("TOP")
    dialogueText:SetText("What will you do?")
    frame.DialogueText = dialogueText

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

    frame:Hide()
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

    -- Level (:L xx)
    local levelText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    levelText:SetPoint("TOPRIGHT", -8, -6)
    levelText:SetText(":L 5")
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

-- Switch Menu Sub-Panels
function BF:SetMenuMode(mode)
    if BE.State.forcedSwitch and mode ~= "PARTY" then
        return
    end

    menuMode = mode
    frame.MainMenu:Hide()
    frame.FightMenu:Hide()
    frame.BagMenu:Hide()
    frame.PartyMenu:Hide()

    if mode == "FIGHT" then
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
        if frame.EnemyModel.ClearModel then frame.EnemyModel:ClearModel() end
        if frame.EnemyModel.SetDisplayInfo then
            frame.EnemyModel:SetDisplayInfo(enemyDisplay)
        elseif frame.EnemyModel.SetCreatureByDisplayID then
            frame.EnemyModel:SetCreatureByDisplayID(enemyDisplay)
        end
        if frame.EnemyModel.SetPortraitZoom then frame.EnemyModel:SetPortraitZoom(0) end
        if frame.EnemyModel.SetCamDistanceScale then frame.EnemyModel:SetCamDistanceScale(1.0) end
        frame.EnemyModel:SetRotation(math.rad(-35))
        frame.EnemyModel:SetAnimation(0)
        frame.EnemyModel:Show()
    end

    local player = BE.State.playerMob
    if player and frame.PlayerModel then
        local playerDisplay = (player.displayId and player.displayId > 0) and player.displayId or C.GetDefaultDisplayId(player.creatureType, player.name)
        if frame.PlayerModel.ClearModel then frame.PlayerModel:ClearModel() end
        if frame.PlayerModel.SetDisplayInfo then
            frame.PlayerModel:SetDisplayInfo(playerDisplay)
        elseif frame.PlayerModel.SetCreatureByDisplayID then
            frame.PlayerModel:SetCreatureByDisplayID(playerDisplay)
        end
        if frame.PlayerModel.SetPortraitZoom then frame.PlayerModel:SetPortraitZoom(0) end
        if frame.PlayerModel.SetCamDistanceScale then frame.PlayerModel:SetCamDistanceScale(1.0) end
        frame.PlayerModel:SetRotation(math.rad(145))
        frame.PlayerModel:SetAnimation(0)
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
    if model and model:IsShown() then
        model:SetAnimation(13)
        PlaySound(847)
        C_Timer.After(0.7, function()
            if model:IsShown() then model:SetAnimation(0) end
        end)
    end
end

function BF:UpdateLog()
    BF:UpdateUI()
end

-- Main Refresh Loop
function BF:UpdateUI()
    if not frame or not frame:IsShown() then return end

    local player = BE.State.playerMob
    local enemy = BE.State.enemyMob

    -- Update Dialogue Text
    frame.DialogueText:SetText(BE.State.dialogueText or "What will you do?")

    -- Update Enemy Status Box (Top-Left)
    if enemy then
        frame.EnemyHUD.NameText:SetText(string.upper(enemy.name))
        frame.EnemyHUD.LevelText:SetText(string.format(":L%d", enemy.level))

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
    end

    -- Update Player Status Box (Bottom-Right)
    if player then
        local pName = string.upper(player.nickname ~= "" and player.nickname or player.name)
        frame.PlayerHUD.NameText:SetText(pName)
        frame.PlayerHUD.LevelText:SetText(string.format(":L%d", player.level))

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
        for i = 1, 4 do
            local btn = moveButtons[i]
            local moveKey = player.abilities and player.abilities[i]
            if moveKey and C.ABILITIES[moveKey] then
                local m = C.ABILITIES[moveKey]
                local mState = BE.State.moveState.player and BE.State.moveState.player[moveKey]
                local usesLeft = mState and mState.usesLeft or m.maxUses or 10
                local maxUses = mState and mState.maxUses or m.maxUses or 10
                local currentCD = mState and mState.currentCD or 0

                btn.moveKey = moveKey
                btn.Title:SetText(string.format("|cffffffff%s|r", m.name))

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
    end

    -- Update Bag Buttons
    for i, btn in ipairs(bagButtons) do
        local id = btn.itemId
        local count = DB:GetItemCount(id)
        local itemData = C.CAGES[id] or C.SHOP_ITEMS[id]
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

    -- Update Party Buttons
    local team = DB:GetTeam()
    for i = 1, 4 do
        local btn = partyButtons[i]
        local mob = team[i]
        if mob then
            btn.mobId = mob.id
            local pName = mob.nickname ~= "" and mob.nickname or mob.name
            if player and mob.id == player.id then
                btn:Disable()
                if (mob.currentHP or 0) <= 0 then
                    btn.Title:SetText(string.format("|cffff4444%s (KO'd)|r", pName))
                else
                    btn.Title:SetText(string.format("|cff00ff00%s (Active)|r", pName))
                end
            elseif (mob.currentHP or 0) <= 0 then
                btn:Disable()
                btn.Title:SetText(string.format("|cffff4444%s (KO'd)|r", pName))
            else
                btn:Enable()
                btn.Title:SetText(string.format("|cffffffff%s|r |cff00ff99Lv%d (%d/%d)|r", pName, mob.level, mob.currentHP, mob.maxHP))
            end
            btn:Show()
        else
            btn.mobId = nil
            btn:Hide()
        end
    end
end

function BF:ShowBattle()
    if not frame then BF:Initialize() end
    frame:Show()
    BF:SetMenuMode("MAIN")
    BF:UpdateModels()
    BF:UpdateUI()
    PlaySound(1194)
end

function BF:Hide()
    if frame then frame:Hide() end
end

function BF:IsShown()
    return frame and frame:IsShown()
end
