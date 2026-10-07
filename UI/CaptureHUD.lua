--[[
    Forever Safari: Field Research Capture Radar HUD
    Real-time stalking distance radar, net selector, and snare channeling castbar.
    Operates with 0% live-mob damage, allowing peaceful coexistence with Hunters and world adventurers.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.CaptureHUD = ns.CaptureHUD or {}

local HUD = ns.CaptureHUD
local C = ns.Constants
local DB = ns.Database
local CE = ns.CaptureEngine
local Theme = ns.Theme

local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then
        return true
    end
    return false
end

local frame = nil
local selectedCageId = "copper_cage"
local lastRangeCheck = 0

function HUD:Initialize()
    if frame then return end

    frame = CreateFrame("Frame", "ForeverSafariCaptureHUDFrame", UIParent, "BackdropTemplate")
    frame:SetSize(365, 148)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -180)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")

    Theme:ApplyFrameBackdrop(frame, true)

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Header Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("|cffffd100Forever Safari|r Field Radar")
    frame.Title = title

    -- Quick Bag Button
    local bagBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    bagBtn:SetSize(22, 22)
    bagBtn:SetPoint("TOPRIGHT", -32, -6)
    bagBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bagBtn:SetBackdropColor(0.12, 0.16, 0.22, 0.9)
    bagBtn:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.7)

    local bagTex = bagBtn:CreateTexture(nil, "ARTWORK")
    bagTex:SetAllPoints()
    bagTex:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
    bagTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    bagBtn:SetScript("OnClick", function()
        if ForeverSafari.SafariBagFrame then
            ForeverSafari.SafariBagFrame:Toggle()
        end
    end)
    bagBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Safari Bag", 1, 0.82, 0)
        GameTooltip:AddLine("Open your 20-slot virtual safari satchel.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    bagBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        if CE:IsChanneling() then
            CE:CancelSnareChannel("HUD closed.")
        end
        frame:Hide()
    end)

    -- Target Name & Creature Type Text
    local targetText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    targetText:SetPoint("TOPLEFT", 12, -28)
    targetText:SetPoint("TOPRIGHT", -12, -28)
    targetText:SetJustifyH("LEFT")
    targetText:SetText("No Quarry")
    frame.TargetText = targetText

    -- Stalking Range / Channel CastBar (Dual Purpose StatusBar)
    local radarBar = CreateFrame("StatusBar", nil, frame)
    radarBar:SetSize(341, 20)
    radarBar:SetPoint("TOPLEFT", 12, -48)
    radarBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    radarBar:SetStatusBarColor(0.2, 0.8, 0.4)
    radarBar:SetMinMaxValues(0, 100)
    radarBar:SetValue(100)

    local barBg = radarBar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    barBg:SetColorTexture(0.08, 0.10, 0.14, 0.9)

    local barText = radarBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    barText:SetPoint("CENTER", 0, 0)
    barText:SetText("Stalking Range: Checking...")
    radarBar.Text = barText
    frame.RadarBar = radarBar

    -- Capture Probability Indicator
    local chanceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chanceText:SetPoint("TOPLEFT", 12, -73)
    chanceText:SetText("Snare Chance: |cff00ff00--|r")
    frame.ChanceText = chanceText

    -- Net Selection Container & Action Buttons
    frame.CageButtons = {}
    local cageTypes = { "copper_cage", "iron_cage", "mithril_cage", "thorium_trap" }
    local btnSize = 30
    local startX = 10

    for i, cageId in ipairs(cageTypes) do
        local cageData = C.CAGES[cageId] or {}
        local cBtn = CreateFrame("Button", "ForeverSafariHUDNet" .. i, frame, "BackdropTemplate")
        cBtn:SetSize(btnSize, btnSize)
        cBtn:SetPoint("BOTTOMLEFT", startX + (i - 1) * (btnSize + 5), 10)

        Theme:ApplyCardBackdrop(cBtn)

        local icon = cBtn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexture(cageData.icon or "Interface\\Icons\\INV_Misc_Rope_01")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        cBtn.Icon = icon

        local countText = cBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
        countText:SetPoint("BOTTOMRIGHT", -2, 2)
        countText:SetText("0")
        cBtn.Count = countText

        -- Selection Glow
        local glow = cBtn:CreateTexture(nil, "OVERLAY")
        glow:SetAllPoints()
        glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        glow:SetBlendMode("ADD")
        glow:Hide()
        cBtn.SelGlow = glow

        cBtn:SetScript("OnClick", function()
            selectedCageId = cageId
            HUD:UpdateUI()
            PlaySound(856)
        end)

        cBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(cageData.name or cageId, 1, 0.82, 0)
            GameTooltip:AddLine(string.format("Base Catch Power: |cff00ff99%.0f%%|r", (cageData.catchPower or 0.35) * 100), 1, 1, 1)
            GameTooltip:AddLine(string.format("Channel Time: |cffffd100%.1fs|r", cageData.channelTime or 5.0), 1, 1, 1)
            GameTooltip:AddLine(cageData.description or "", 0.8, 0.8, 0.8, true)
            local current = DB:GetItemCount(cageId)
            GameTooltip:AddLine(string.format("In Safari Bag: %d", current), 0, 1, 0.6)
            GameTooltip:Show()
        end)
        cBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        frame.CageButtons[cageId] = cBtn
    end

    -- Trainer Badge (Shown in place of net buttons during Humanoid Trainer target)
    local trainerBadge = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    trainerBadge:SetSize(135, 30)
    trainerBadge:SetPoint("BOTTOMLEFT", 10, 10)
    Theme:ApplyCardBackdrop(trainerBadge)
    local badgeIcon = trainerBadge:CreateTexture(nil, "ARTWORK")
    badgeIcon:SetSize(20, 20)
    badgeIcon:SetPoint("LEFT", 6, 0)
    badgeIcon:SetTexture("Interface\\Icons\\Achievement_PVP_A_01")
    badgeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local badgeText = trainerBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badgeText:SetPoint("LEFT", badgeIcon, "RIGHT", 6, 0)
    badgeText:SetText("|cffffd100Rival Trainer|r")
    trainerBadge.Text = badgeText
    trainerBadge:Hide()
    frame.TrainerBadge = trainerBadge

    -- Stalk & Observe Action Button (or Scout Trainer)
    local actionBtn = CreateFrame("Button", "ForeverSafariHUDActionBtn", frame, "UIPanelButtonTemplate")
    actionBtn:SetSize(100, 30)
    actionBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    actionBtn:SetText("🔭 OBSERVE")
    actionBtn:SetScript("OnClick", function()
        if frame.ActionBtn.isTrainerMode then
            local data = frame.ActionBtn.trainerData
            if data then
                local arch = data.archetype or {}
                local msg = string.format("|cffffd100[Trainer Scout]|r |cffffffff%s|r (%s): \"%s\" |cff00ff99[Bounty: +%d Tokens, %d Pet(s)]|r",
                    data.name, arch.title or "Rival Trainer", arch.intro or "Let's battle!", data.tokenReward or 8, data.numPets or 1)
                DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. msg)
                if ForeverSafari.Toast and ForeverSafari.Toast.ShowReward then
                    ForeverSafari.Toast:ShowReward(arch.title or "Rival AI Trainer", string.format("Bounty: +%d Tokens (%d Pets)", data.tokenReward or 8, data.numPets or 1))
                end
                PlaySound(856)
            end
        else
            if CE:IsChanneling() then
                CE:CancelSnareChannel("Cancelled by player.")
            else
                CE:AttemptCapture("target", selectedCageId)
            end
            HUD:UpdateUI()
        end
    end)
    actionBtn:SetScript("OnEnter", function(self)
        if frame.ActionBtn.isTrainerMode then
            local data = frame.ActionBtn.trainerData
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("🔍 Scout Rival Trainer", 1, 0.82, 0)
            GameTooltip:AddLine("Inspect this roaming humanoid trainer to reveal their squad size, battle dialogue, and token bounty.", 1, 1, 1, true)
            if data and data.archetype then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format("Faction Title: |cffffcc00%s|r", data.archetype.title or "Trainer"), 0.8, 0.9, 1)
                GameTooltip:AddLine(string.format("Rival Squad: |cffffffff%d Companion(s)|r", data.numPets or 1), 0.8, 0.9, 1)
                GameTooltip:AddLine(string.format("Defeat Bounty: |cff00ff99+%d Safari Tokens|r", data.tokenReward or 8), 0.8, 0.9, 1)
                GameTooltip:AddLine(string.format("Battle Cry: |cffffd100\"%s\"|r", data.archetype.intro or "Let's battle!"), 1, 0.82, 0, true)
            end
            GameTooltip:Show()
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("🔭 Field Stalking & Observation", 1, 0.82, 0)
        GameTooltip:AddLine("Quietly study this wild creature in its natural habitat to discover and learn its fighting techniques directly into your Trainer Grimoire!", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("• Discovers new family abilities for your companions", 0, 1, 0.6)
        GameTooltip:AddLine("• Awards +15 Attunement if all abilities are already mastered", 0.8, 0.9, 1)
        GameTooltip:AddLine("• Non-combat observation (quarry remains 100% untouched)", 0.8, 0.9, 1)
        GameTooltip:Show()
    end)
    actionBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.ActionBtn = actionBtn

    -- Turn-Based Battle Action Button
    local battleBtn = CreateFrame("Button", "ForeverSafariHUDBattleBtn", frame, "UIPanelButtonTemplate")
    battleBtn:SetSize(106, 30)
    battleBtn:SetPoint("BOTTOMRIGHT", actionBtn, "BOTTOMLEFT", -6, 0)
    battleBtn:SetText("⚔️ BATTLE")
    battleBtn:SetScript("OnClick", function()
        if CE:IsChanneling() then
            CE:CancelSnareChannel("Engaged in battle.")
        end
        if ForeverSafari.BattleEngine then
            ForeverSafari.BattleEngine:StartWildBattle("target")
        end
    end)
    battleBtn:SetScript("OnEnter", function(self)
        local isTrainer = ns.TrainerEngine and ns.TrainerEngine:IsHumanoidTrainer("target")
        if isTrainer then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("⚔️ Challenge Rival AI Trainer", 1, 0.82, 0)
            GameTooltip:AddLine("Initiate a turn-based 3D companion battle against this roaming humanoid rival trainer.", 1, 1, 1, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Trainer Battle Rules:", 0, 1, 0.6)
            GameTooltip:AddLine("• Win to earn Safari Tokens & Faction Bounties", 0.8, 0.9, 1)
            GameTooltip:AddLine("• Defeat their full 1-to-3 companion roster", 0.8, 0.9, 1)
            GameTooltip:AddLine("• Trainer pets cannot be captured with snares/cages", 1, 0.4, 0.4)
            GameTooltip:Show()
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("⚔️ Engage in Wild Battle", 1, 0.82, 0)
        GameTooltip:AddLine("Challenge this wild creature to a turn-based battle with your active companion.", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Victory Rewards:", 0, 1, 0.6)
        GameTooltip:AddLine("• +35 Attunement Loyalty for your active companion", 0.8, 0.9, 1)
        GameTooltip:AddLine("• Harvested Wild Family Meats / Diets", 0.8, 0.9, 1)
        GameTooltip:AddLine("• Quest objective & bestiary progress", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    battleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.BattleBtn = battleBtn

    -- Register Target Events & Distance Poller
    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_TARGET_CHANGED" then
            HUD:OnTargetChanged()
        elseif event == "PLAYER_REGEN_DISABLED" then
            if CE:IsChanneling() then
                CE:CancelSnareChannel("Combat interrupted stalking focus.")
            end
            if frame and frame:IsShown() then
                frame:Hide()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if UnitExists("target") then
                HUD:OnTargetChanged()
            end
        end
    end)

    -- Poller for smooth live proximity detection
    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        if InCombatLockdown and InCombatLockdown() then return end
        if not frame:IsShown() or not UnitExists("target") then return end
        
        lastRangeCheck = lastRangeCheck + elapsed
        if lastRangeCheck >= 0.25 and not CE:IsChanneling() then
            lastRangeCheck = 0
            HUD:UpdateUI()
        end
    end)

    frame:Hide()
end

function HUD:OnTargetChanged()
    if InCombatLockdown and InCombatLockdown() then
        if frame and frame:IsShown() then frame:Hide() end
        return
    end

    if not UnitExists("target") or UnitIsDead("target") or UnitIsPlayer("target") then
        if CE:IsChanneling() then
            CE:CancelSnareChannel("Target lost.")
        end
        frame:Hide()
        return
    end

    local classification = UnitClassification("target")
    if classification == "worldboss" then
        frame:Hide()
        return
    end

    local isTrainer = ns.TrainerEngine and ns.TrainerEngine:IsHumanoidTrainer("target")

    if isTrainer then
        frame:Show()
        HUD:UpdateUI()
        return
    end

    local reaction = UnitReaction("player", "target")
    if not isSecret(reaction) and type(reaction) == "number" and reaction > 4 then
        frame:Hide()
        return
    end

    local name = UnitName("target")
    if isSecret(name) or not name or name == "" then name = "Wild Creature" end

    local rawType = UnitCreatureType("target") or "Beast"
    if isSecret(rawType) then rawType = "Beast" end

    local creatureType = C.NormalizeCreatureType(rawType, name)

    -- If target is Giant, ineligible, or research locked, do not show the capture HUD!
    if rawType == "Giant" or (C.ELIGIBLE_CAPTURE_TYPES and not C.ELIGIBLE_CAPTURE_TYPES[creatureType]) or not DB:IsTypeUnlocked(creatureType) then
        if CE:IsChanneling() then
            CE:CancelSnareChannel("Target is ineligible or research is locked.")
        end
        frame:Hide()
        return
    end

    if DB and DB.DiscoverSpecies then
        DB:DiscoverSpecies(name, "seen")
    end

    frame:Show()
    HUD:UpdateUI()
end

function HUD:UpdateUI()
    if InCombatLockdown and InCombatLockdown() then return end
    if not frame:IsShown() or not UnitExists("target") then return end

    local name = UnitName("target")
    if isSecret(name) or not name or name == "" then name = "Wild Creature" end

    local level = UnitLevel("target")
    local levelStr = "Lv ??"
    if not isSecret(level) and level and level > 0 then
        levelStr = string.format("Lv %d", level)
    end

    local rawType = UnitCreatureType("target") or "Beast"
    if isSecret(rawType) then rawType = "Beast" end
    local creatureType = C.NormalizeCreatureType(rawType, name)

    local isTrainer = ns.TrainerEngine and ns.TrainerEngine:IsHumanoidTrainer("target")

    if isTrainer then
        frame.Title:SetText("|cffffd100Forever Safari|r Rival Battler Radar")

        local TrainerDB = ns.TrainerDB
        local zoneName = GetZoneText() or "Azeroth"
        local archetype = (TrainerDB and TrainerDB.GetArchetypeForUnit) and TrainerDB:GetArchetypeForUnit(name, rawType, zoneName) or (TrainerDB and TrainerDB.ARCHETYPES and TrainerDB.ARCHETYPES["Default"])
        local archetypeTitle = archetype and archetype.title or "Rival AI Trainer"
        local tokenReward = archetype and archetype.tokenReward or 8

        local numPets = 1
        if level and type(level) == "number" then
            if level >= 36 then
                tokenReward = math.floor(tokenReward * 2.0)
                numPets = 3
            elseif level >= 16 then
                tokenReward = math.floor(tokenReward * 1.5)
                numPets = 2
            end
        end

        frame.TargetText:SetText(string.format("|cffffffff%s|r  |cffaaaaaa%s|r  |cffffcc00[%s]|r", name, levelStr, archetypeTitle))

        frame.RadarBar:SetStatusBarColor(1.0, 0.75, 0.0)
        frame.RadarBar:SetMinMaxValues(0, 100)
        frame.RadarBar:SetValue(100)
        frame.RadarBar.Text:SetText(string.format("|cffffd100⚔️ Rival AI Trainer • Bounty: +%d Safari Tokens|r", tokenReward))

        frame.ChanceText:SetText(string.format("Rival Squad: |cffffd100%d Companion%s|r  •  Reward: |cff00ff99+%d Tokens|r", numPets, numPets > 1 and "s" or "", tokenReward))

        -- Show trainer badge and hide cage buttons
        if frame.TrainerBadge then
            frame.TrainerBadge:Show()
            frame.TrainerBadge.Text:SetText(string.format("|cffffd100%s|r", archetypeTitle))
        end
        for _, btn in pairs(frame.CageButtons) do
            btn:Hide()
        end

        -- Action Button -> Scout
        frame.ActionBtn:Enable()
        frame.ActionBtn:SetText("🔍 SCOUT")
        frame.ActionBtn.isTrainerMode = true
        frame.ActionBtn.trainerData = {
            name = name,
            archetype = archetype,
            level = level,
            tokenReward = tokenReward,
            numPets = numPets,
        }

        -- Battle Button -> Challenge
        if frame.BattleBtn then
            local activeMob = DB:GetActiveMob()
            if not activeMob then
                frame.BattleBtn:Disable()
                frame.BattleBtn:SetText("NO SQUAD")
            elseif (activeMob.currentHP or 0) <= 0 then
                frame.BattleBtn:Disable()
                frame.BattleBtn:SetText("FAINTED")
            else
                frame.BattleBtn:Enable()
                frame.BattleBtn:SetText("⚔️ CHALLENGE")
            end
        end
        return
    end

    -- Normal Wild Creature Mode
    frame.Title:SetText("|cffffd100Forever Safari|r Field Radar")
    if frame.ActionBtn then
        frame.ActionBtn.isTrainerMode = false
        frame.ActionBtn.trainerData = nil
    end
    if frame.TrainerBadge then
        frame.TrainerBadge:Hide()
    end
    for _, btn in pairs(frame.CageButtons) do
        btn:Show()
    end

    if rawType == "Humanoid" or rawType == "Giant" or creatureType == "Humanoid" or (C.ELIGIBLE_CAPTURE_TYPES and not C.ELIGIBLE_CAPTURE_TYPES[creatureType]) or not DB:IsTypeUnlocked(creatureType) then
        frame:Hide()
        return
    end

    local typeInfo = C.CREATURE_TYPES[creatureType] or C.CREATURE_TYPES["Beast"]
    local typeColor = typeInfo.color or "ffffff"

    frame.TargetText:SetText(string.format("|cffffffff%s|r  |cffaaaaaa%s|r  |cff%s[%s]|r", name, levelStr, typeColor, creatureType))

    -- Distance & Radar Gauge
    if not CE:IsChanneling() then
        local distTier, distMod, distText, distColor = CE:GetStalkingDistance("target")
        
        if distTier == "CLOSE" then
            frame.RadarBar:SetStatusBarColor(0.0, 1.0, 0.6)
            frame.RadarBar:SetMinMaxValues(0, 100)
            frame.RadarBar:SetValue(100)
            frame.RadarBar.Text:SetText("|cff00ff99Close Stalk (~10 yd) • Optimal Focus (+25% Catch)|r")
        elseif distTier == "PERIMETER" then
            frame.RadarBar:SetStatusBarColor(1.0, 0.82, 0.0)
            frame.RadarBar:SetMinMaxValues(0, 100)
            frame.RadarBar:SetValue(65)
            frame.RadarBar.Text:SetText("|cffffd100In Perimeter (15-28 yd) • Ready to Snare|r")
        else
            frame.RadarBar:SetStatusBarColor(0.9, 0.25, 0.25)
            frame.RadarBar:SetMinMaxValues(0, 100)
            frame.RadarBar:SetValue(20)
            frame.RadarBar.Text:SetText("|cffff4444Out of Range (>28 yd) • Close Distance!|r")
        end

        -- Calculate rate
        local rate, _ = CE:GetCaptureRate("target", selectedCageId)
        local ratePct = (rate or 0) * 100

        if distTier == "OUT_OF_RANGE" then
            frame.ChanceText:SetText("Snare Chance: |cffff44440.0% (Too Far)|r")
        else
            local rateColor = (ratePct >= 65) and "00ff99" or (ratePct >= 35 and "ffd100" or "ff8800")
            local bonusTag = (distTier == "CLOSE") and " |cff00ff99(+25% Bonus)|r" or ""
            frame.ChanceText:SetText(string.format("Snare Chance: |cff%s%.1f%%|r%s", rateColor, ratePct, bonusTag))
        end

        -- Action Button state
        local cageCount = DB:GetItemCount(selectedCageId)
        if cageCount <= 0 then
            frame.ActionBtn:Disable()
            frame.ActionBtn:SetText("NO NETS")
        elseif distTier == "OUT_OF_RANGE" then
            frame.ActionBtn:Disable()
            frame.ActionBtn:SetText("TOO FAR")
        else
            frame.ActionBtn:Enable()
            frame.ActionBtn:SetText("SNARE")
        end
    else
        -- Active Channeling mode
        frame.ActionBtn:Enable()
        frame.ActionBtn:SetText("|cffff4444CANCEL|r")
    end

    -- Battle Button state
    if frame.BattleBtn then
        local activeMob = DB:GetActiveMob()
        if not activeMob then
            frame.BattleBtn:Disable()
            frame.BattleBtn:SetText("NO SQUAD")
        elseif (activeMob.currentHP or 0) <= 0 then
            frame.BattleBtn:Disable()
            frame.BattleBtn:SetText("FAINTED")
        elseif CE:IsChanneling() then
            frame.BattleBtn:Disable()
            frame.BattleBtn:SetText("⚔️ BATTLE")
        else
            frame.BattleBtn:Enable()
            frame.BattleBtn:SetText("⚔️ BATTLE")
        end
    end

    -- Update Cage/Net buttons
    for cageId, btn in pairs(frame.CageButtons) do
        local count = DB:GetItemCount(cageId)
        btn.Count:SetText(count > 0 and string.format("x%d", count) or "|cffff44440|r")
        if cageId == selectedCageId then
            btn.SelGlow:Show()
        else
            btn.SelGlow:Hide()
        end
    end
end

-- Channel Progress Bar Callbacks from CaptureEngine
function HUD:StartChannelBar(targetName, duration, netName)
    if not frame then return end
    frame:Show()
    frame.RadarBar:SetStatusBarColor(0.2, 0.8, 1.0)
    frame.RadarBar:SetMinMaxValues(0, duration)
    frame.RadarBar:SetValue(0)
    frame.RadarBar.Text:SetText(string.format("Channeling %s: 0.0s / %.1fs [Stalking...]", netName, duration))
    frame.ChanceText:SetText(string.format("Stalking |cffffd100%s|r... Maintain Line of Sight!", targetName))
    HUD:UpdateUI()
end

function HUD:UpdateChannelProgress(elapsed, duration)
    if not frame or not frame:IsShown() then return end
    frame.RadarBar:SetValue(math.min(duration, elapsed))
    local pct = math.min(100, (elapsed / duration) * 100)
    frame.RadarBar.Text:SetText(string.format("Snaring: %.1fs / %.1fs (%.0f%%) [Stalking...]", elapsed, duration, pct))
end

function HUD:StopChannelBar(reason)
    if not frame then return end
    HUD:UpdateUI()
end

function HUD:ShowCaptureResult(success, targetName, chance)
    if not frame or not frame:IsShown() then return end
    if success then
        frame.RadarBar:SetStatusBarColor(0.0, 1.0, 0.6)
        frame.RadarBar:SetValue(100)
        frame.RadarBar.Text:SetText(string.format("|cff00ff99Success! %s Catalogued!|r", targetName))
    else
        frame.RadarBar:SetStatusBarColor(0.9, 0.25, 0.25)
        frame.RadarBar.Text:SetText(string.format("|cffff4444Snare Slipped! (Quarry Untouched)|r", targetName))
    end
    C_Timer.After(2.0, function()
        if frame and frame:IsShown() then
            HUD:UpdateUI()
        end
    end)
end

function HUD:SelectCage(cageId)
    if cageId and C.CAGES[cageId] then
        selectedCageId = cageId
        if frame and frame:IsShown() then
            HUD:UpdateUI()
        end
    end
end

function HUD:GetSelectedCage()
    return selectedCageId or "copper_cage"
end

function HUD:ShowHUD()
    if not frame then HUD:Initialize() end
    frame:Show()
    HUD:UpdateUI()
end

function HUD:ToggleHUD()
    if not frame then HUD:Initialize() end
    if frame:IsShown() then
        frame:Hide()
    else
        HUD:ShowHUD()
    end
end

function HUD:IsShown()
    return frame and frame:IsShown()
end


