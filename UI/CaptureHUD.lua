--[[
    Forever Safari: Field Research Stalking & Rival Radar HUD (CaptureHUD.lua)
    Real-time stalking distance radar, field observation channeling, and rival battler challenge launcher.
    0% Live-Mob Damage: Wild quarry remains completely untouched in the game world.
    Captures occur strictly during turn-based battle via the in-combat [BAG] menu.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.CaptureHUD = ns.CaptureHUD or {}

local HUD = ns.CaptureHUD
local C = ns.Constants
local DB = ns.Database
local CE = ns.CaptureEngine
local TE = ns.TrainerEngine
local Theme = ns.Theme

local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return true end
    if issecretpassphrase and issecretpassphrase(v) then return true end
    if issecretvariable and issecretvariable(v) then return true end
    local ok = pcall(function() local _ = (v == "") end)
    if not ok then return true end
    return false
end

local frame = nil
local lastRangeCheck = 0

function HUD:Initialize()
    if frame then return end

    frame = CreateFrame("Frame", "ForeverSafariCaptureHUDFrame", UIParent, "BackdropTemplate")
    frame:SetSize(350, 126)
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
    title:SetText("|cffffd100Forever Safari|r Field Research Radar")
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

    -- Stalking / Observation CastBar (Dual Purpose StatusBar)
    local radarBar = CreateFrame("StatusBar", nil, frame)
    radarBar:SetSize(326, 18)
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
    barText:SetText("Observation Range: Checking...")
    radarBar.Text = barText
    frame.RadarBar = radarBar

    -- Subtitle / Research Info Text
    local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", 12, -70)
    infoText:SetPoint("TOPRIGHT", -12, -70)
    infoText:SetJustifyH("LEFT")
    infoText:SetText("Field Study: |cff00ff99Discover Abilities for Grimoire (+15 Attunement)|r")
    frame.InfoText = infoText

    -- Mode Badge (Bottom-Left)
    local modeBadge = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    modeBadge:SetSize(110, 26)
    modeBadge:SetPoint("BOTTOMLEFT", 10, 8)
    Theme:ApplyCardBackdrop(modeBadge)

    local badgeIcon = modeBadge:CreateTexture(nil, "ARTWORK")
    badgeIcon:SetSize(18, 18)
    badgeIcon:SetPoint("LEFT", 4, 0)
    badgeIcon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
    badgeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    modeBadge.Icon = badgeIcon

    local badgeText = modeBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badgeText:SetPoint("LEFT", badgeIcon, "RIGHT", 4, 0)
    badgeText:SetText("Field Study")
    modeBadge.Text = badgeText
    frame.ModeBadge = modeBadge

    -- Observe / Scout Action Button
    local actionBtn = CreateFrame("Button", "ForeverSafariHUDActionBtn", frame, "UIPanelButtonTemplate")
    actionBtn:SetSize(104, 26)
    actionBtn:SetPoint("BOTTOMRIGHT", -10, 8)
    actionBtn:SetText("🔭 OBSERVE")
    actionBtn:SetScript("OnClick", function()
        if frame.ActionBtn.isOutpostMode then
            local outpost = frame.ActionBtn.outpostData
            if outpost then
                local badge = outpost.badge or {}
                local isDefeated = ns.OutpostDB and ns.OutpostDB:IsOutpostDefeated(outpost.id)
                local msg = string.format("|cffffd100[Safari Guide]|r |cffffffff%s|r (%s, Tier %d): \"%s\" |cff00ff99[Badge: %s, Squad: %d Pets]|r%s",
                    outpost.name, outpost.location or outpost.zone, outpost.tier or 1,
                    outpost.introQuote or "Challenge me!", badge.name or "Regional Badge",
                    #(outpost.team or {}), isDefeated and " |cff00ff00[CLEARED]|r" or "")
                DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. msg)
                if ForeverSafari.Toast and ForeverSafari.Toast.ShowReward then
                    ForeverSafari.Toast:ShowReward(string.format("Guide: %s", outpost.name), string.format("Badge: [%s] (%s)", badge.name or "Badge", isDefeated and "Cleared" or "Undefeated"))
                end
                PlaySound(856)
            end
        elseif frame.ActionBtn.isTrainerMode then
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
                CE:CancelSnareChannel("Observation cancelled by player.")
            else
                CE:AttemptCapture("target", "copper_cage")
            end
            HUD:UpdateUI()
        end
    end)
    actionBtn:SetScript("OnEnter", function(self)
        if frame.ActionBtn.isOutpostMode then
            local outpost = frame.ActionBtn.outpostData
            if outpost then
                local badge = outpost.badge or {}
                local isDefeated = ns.OutpostDB and ns.OutpostDB:IsOutpostDefeated(outpost.id)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(string.format("📜 Guide Intelligence: %s", outpost.name), 1, 0.82, 0)
                GameTooltip:AddLine(string.format("Title: |cffffffff%s|r", outpost.title or "<Safari Guide>"), 0.8, 0.9, 1)
                GameTooltip:AddLine(string.format("Location: |cffffcc00%s (%s)|r", outpost.location or outpost.zone, outpost.zone), 0.8, 0.9, 1)
                GameTooltip:AddLine(string.format("Guide Circuit: |cff00ccffTier %d • Attunement Rank %s (%s)|r", outpost.tier or 1, outpost.rankRoman or "I", outpost.rankTitle or "Circuit"), 0.8, 0.9, 1)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format("Regional Trophy: |cffffd100[%s]|r", badge.name or "Regional Badge"), 1, 0.82, 0)
                if badge.desc then
                    GameTooltip:AddLine(string.format("  \"%s\"", badge.desc), 0.7, 0.7, 0.7, true)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format("Status: %s", isDefeated and "|cff00ff00✅ CLEARED (Badge Earned)|r" or "|cffffaa00⚔️ UNDEFEATED (Challenge Ready)|r"))
                GameTooltip:AddLine(string.format("Bounty: |cff00ff99+%d Safari Tokens & +75 Pet Attunement|r", outpost.tokenReward or 20))
                if outpost.team and #outpost.team > 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Guide Squad Roster:", 1, 0.82, 0)
                    for _, pet in ipairs(outpost.team) do
                        GameTooltip:AddLine(string.format("  • %s (Rank %s %s)", pet.name, pet.rankRoman or outpost.rankRoman or "I", pet.family or pet.element or "Beast"), 0.9, 0.9, 0.9)
                    end
                end
                GameTooltip:Show()
                return
            end
        end

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
        GameTooltip:AddLine("• Captures happen during turn-based battle via [BAG]", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    actionBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.ActionBtn = actionBtn

    -- Turn-Based Battle Action Button
    local battleBtn = CreateFrame("Button", "ForeverSafariHUDBattleBtn", frame, "UIPanelButtonTemplate")
    battleBtn:SetSize(104, 26)
    battleBtn:SetPoint("BOTTOMRIGHT", actionBtn, "BOTTOMLEFT", -6, 0)
    battleBtn:SetText("⚔️ BATTLE")
    battleBtn:SetScript("OnClick", function()
        if CE:IsChanneling() then
            CE:CancelSnareChannel("Engaged in battle.")
        end
        if frame.BattleBtn.isOutpostMode then
            local outpost = frame.BattleBtn.outpostData
            if outpost and ns.OutpostDB then
                local canChallenge, reason = ns.OutpostDB:CanChallengeGuide(outpost, "target")
                if not canChallenge then
                    UIErrorsFrame:AddMessage(reason or "Challenge Locked", 1.0, 0.2, 0.2, 1.0)
                    DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444" .. (reason or "Challenge Locked") .. "|r")
                    return
                end
            end
            if ForeverSafari.BattleEngine and outpost then
                ForeverSafari.BattleEngine:StartOutpostBattle("target", outpost)
            end
            return
        end
        if ForeverSafari.BattleEngine then
            ForeverSafari.BattleEngine:StartWildBattle("target")
        end
    end)
    battleBtn:SetScript("OnEnter", function(self)
        if frame.BattleBtn.isOutpostMode then
            local outpost = frame.BattleBtn.outpostData
            local isDefeated = outpost and ns.OutpostDB and ns.OutpostDB:IsOutpostDefeated(outpost.id)
            local canChallenge, lockReason = outpost and ns.OutpostDB and ns.OutpostDB:CanChallengeGuide(outpost, "target")
            local badge = outpost and outpost.badge or {}
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(isDefeated and "⚔️ Rematch Guide" or "⚔️ Challenge Guide", 1, 0.82, 0)
            GameTooltip:AddLine(string.format("Challenge %s to a sanctioned 3D turn-based Safari Guide match.", outpost and outpost.name or "Guide"), 1, 1, 1, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Guide Battle Rules:", 0, 1, 0.6)
            GameTooltip:AddLine(string.format("• Defeat their entire %d-companion squad (Attunement Rank %s)", outpost and outpost.team and #outpost.team or 2, outpost and (outpost.rankRoman or "I") or "I"), 0.8, 0.9, 1)
            GameTooltip:AddLine(string.format("• First victory claims the |cffffd100[%s]|r!", badge.name or "Regional Badge"), 1, 0.82, 0)
            GameTooltip:AddLine(string.format("• Awards +%d Safari Tokens & +75 Attunement", outpost and outpost.tokenReward or 20), 0.8, 0.9, 1)
            if not canChallenge and not isDefeated then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format("🔒 Requirement: %s", lockReason or "Locked"), 1, 0.2, 0.2, true)
            elseif isDefeated then
                GameTooltip:AddLine("• |cff00ff00[Already Cleared - Friendly Practice Rematch]|r", 0, 1, 0)
            end
            GameTooltip:Show()
            return
        end

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
        GameTooltip:AddLine("Battle & Capture Rules:", 0, 1, 0.6)
        GameTooltip:AddLine("• Throw Snares, Traps, and Cages from in-battle [BAG]", 0.8, 0.9, 1)
        GameTooltip:AddLine("• Victory awards Wild Family Meats / Diets & Attunement", 0.8, 0.9, 1)
        GameTooltip:AddLine("• Advances research bounties & Bestiary records", 1, 0.82, 0)
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

    -- Suppress HUD completely inside dungeons, raids, and PvP instances
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "pvp" or instanceType == "arena") then
        if CE:IsChanneling() then
            CE:CancelSnareChannel("Inside instance.")
        end
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

    -- 🌟 1. Check for Outpost League Leader (54 Authentic Stable Masters)
    local outpost = ns.OutpostDB and ns.OutpostDB:GetOutpostByUnit("target")
    if outpost then
        frame:Show()
        HUD:UpdateUI()
        return
    end

    local classification = UnitClassification("target")
    if not isSecret(classification) and classification == "worldboss" then
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

function HUD:RenderOutpostMode(outpost)
    frame.Title:SetText("|cffffd100Forever Safari|r Guide Circuit")

    local isDefeated = ns.OutpostDB and ns.OutpostDB:IsOutpostDefeated(outpost.id)
    local canChallenge, lockReason = ns.OutpostDB and ns.OutpostDB:CanChallengeGuide(outpost, "target")
    local badge = outpost.badge or {}
    local badgeName = badge.name or "Regional Badge"
    local badgeIcon = badge.icon or "Interface\\Icons\\INV_Misc_MonsterClaw_04"
    local tokenReward = outpost.tokenReward or (15 + (outpost.tier or 1) * 5)
    local teamSize = (outpost.team and #outpost.team) or 2

    frame.TargetText:SetText(string.format("|cffffffff%s|r  |cffffcc00<%s>|r  |cff00ccff[Tier %d • %s]|r",
        outpost.name, outpost.title or "Safari Guide", outpost.tier or 1, outpost.location or outpost.zone))

    if isDefeated then
        frame.RadarBar:SetStatusBarColor(0.1, 0.8, 0.4)
        frame.RadarBar:SetMinMaxValues(0, 100)
        frame.RadarBar:SetValue(100)
        frame.RadarBar.Text:SetText(string.format("|cff00ff99✅ Cleared • [%s] Earned!|r", badgeName))
        frame.InfoText:SetText(string.format("Guide Conquered • |cffffd100[%s]|r Registered in League Records", badgeName))
    elseif not canChallenge then
        frame.RadarBar:SetStatusBarColor(0.8, 0.2, 0.2)
        frame.RadarBar:SetMinMaxValues(0, 100)
        frame.RadarBar:SetValue(100)
        frame.RadarBar.Text:SetText("|cffff4444🔒 Challenge Locked|r")
        frame.InfoText:SetText(string.format("|cffff4444%s|r", lockReason or "Challenge Locked"))
    else
        frame.RadarBar:SetStatusBarColor(1.0, 0.75, 0.0)
        frame.RadarBar:SetMinMaxValues(0, 100)
        frame.RadarBar:SetValue(100)
        frame.RadarBar.Text:SetText(string.format("|cffffd100⚔️ Guide Battle • Prize: [%s]|r", badgeName))
        frame.InfoText:SetText(string.format("Squad: |cffffd100%d Companions (Rank %s)|r  •  Prize: |cff00ff99+%d Tokens & [%s]|r",
            teamSize, outpost.rankRoman or "I", tokenReward, badgeName))
    end

    -- Mode Badge (bottom left)
    if frame.ModeBadge then
        frame.ModeBadge.Icon:SetTexture(badgeIcon)
        frame.ModeBadge.Text:SetText(isDefeated and "|cff00ff00Cleared|r" or string.format("|cffffd100Tier %d|r", outpost.tier or 1))
    end

    -- Action Button -> Inspect / Scout Guide
    frame.ActionBtn:Enable()
    frame.ActionBtn:SetText("🔍 GUIDE")
    frame.ActionBtn.isTrainerMode = false
    frame.ActionBtn.isOutpostMode = true
    frame.ActionBtn.outpostData = outpost

    -- Battle Button -> Challenge Guide
    if frame.BattleBtn then
        frame.BattleBtn.isOutpostMode = true
        frame.BattleBtn.outpostData = outpost

        local activeMob = DB:GetActiveMob()
        if not activeMob then
            frame.BattleBtn:Disable()
            frame.BattleBtn:SetText("NO SQUAD")
        elseif (activeMob.currentHP or 0) <= 0 then
            frame.BattleBtn:Disable()
            frame.BattleBtn:SetText("FAINTED")
        elseif not canChallenge and not isDefeated then
            frame.BattleBtn:Disable()
            frame.BattleBtn:SetText("🔒 LOCKED")
        else
            frame.BattleBtn:Enable()
            if isDefeated then
                frame.BattleBtn:SetText("⚔️ REMATCH")
            else
                frame.BattleBtn:SetText("⚔️ BATTLE")
            end
        end
    end
end

function HUD:UpdateUI()
    if InCombatLockdown and InCombatLockdown() then return end
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "pvp" or instanceType == "arena") then
        local outpost = ns.OutpostDB and ns.OutpostDB:GetOutpostByUnit("target")
        if not outpost or (outpost.zone ~= "Naxxramas" and outpost.zone ~= "Alterac Valley") then
            if frame and frame:IsShown() then frame:Hide() end
            return
        end
    end
    if not frame:IsShown() or not UnitExists("target") then return end

    -- 🌟 1. Check for Outpost League Leader
    local outpost = ns.OutpostDB and ns.OutpostDB:GetOutpostByUnit("target")
    if outpost then
        HUD:RenderOutpostMode(outpost)
        return
    end

    -- Clear Outpost Mode Flags
    if frame.ActionBtn then
        frame.ActionBtn.isOutpostMode = false
        frame.ActionBtn.outpostData = nil
    end
    if frame.BattleBtn then
        frame.BattleBtn.isOutpostMode = false
        frame.BattleBtn.outpostData = nil
    end

    local name = UnitName("target")
    if isSecret(name) or not name or name == "" then name = "Wild Creature" end

    local level = UnitLevel("target")

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

        frame.TargetText:SetText(string.format("|cffffffff%s|r  |cffffcc00[%s]|r", name, archetypeTitle))

        frame.RadarBar:SetStatusBarColor(1.0, 0.75, 0.0)
        frame.RadarBar:SetMinMaxValues(0, 100)
        frame.RadarBar:SetValue(100)
        frame.RadarBar.Text:SetText(string.format("|cffffd100⚔️ Rival AI Trainer Ready • Bounty: +%d Safari Tokens|r", tokenReward))

        frame.InfoText:SetText(string.format("Rival Squad: |cffffd100%d Companion%s|r  •  Reward: |cff00ff99+%d Tokens|r", numPets, numPets > 1 and "s" or "", tokenReward))

        -- Mode Badge
        if frame.ModeBadge then
            frame.ModeBadge.Icon:SetTexture("Interface\\Icons\\Achievement_PVP_A_01")
            frame.ModeBadge.Text:SetText("|cffffd100Rival Trainer|r")
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
    frame.Title:SetText("|cffffd100Forever Safari|r Field Research Radar")
    if frame.ActionBtn then
        frame.ActionBtn.isTrainerMode = false
        frame.ActionBtn.trainerData = nil
    end

    -- Mode Badge
    if frame.ModeBadge then
        frame.ModeBadge.Icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
        frame.ModeBadge.Text:SetText("Field Study")
    end

    if rawType == "Humanoid" or rawType == "Giant" or creatureType == "Humanoid" or (C.ELIGIBLE_CAPTURE_TYPES and not C.ELIGIBLE_CAPTURE_TYPES[creatureType]) or not DB:IsTypeUnlocked(creatureType) then
        frame:Hide()
        return
    end

    local typeInfo = C.CREATURE_TYPES[creatureType] or C.CREATURE_TYPES["Beast"]
    local typeColor = typeInfo.color or "ffffff"

    local guid = UnitGUID("target")
    local isScanned = guid and ForeverSafariDB and ForeverSafariDB.scannedGuids and ForeverSafariDB.scannedGuids[guid]
    local isDiscovered = DB and DB.IsSpeciesDiscovered and DB:IsSpeciesDiscovered(name)
    local SE = ns.StatEngine
    local sex = SE and SE.GetBiologicalSex and SE:GetBiologicalSex(creatureType, "target") or "Sire"
    local sexBadge = ""

    if creatureType == "Mechanical" or creatureType == "Elemental" or sex == "Genderless" then
        sexBadge = " |cffa0a0a0[⚙ Genderless]|r"
    elseif isScanned or isDiscovered then
        if sex == "Dam" then
            sexBadge = " |cffff99cc[♀ Dam]|r"
        else
            sexBadge = " |cff66ccff[♂ Sire]|r"
        end
    else
        sexBadge = " |cff888888[❓ Sex: Unknown]|r"
    end

    local isOwned = DB and DB.HasSpecies and DB:HasSpecies(name)
    local ownedBadge = isOwned and " |cffffd100[🐾 Owned]|r" or ""

    frame.TargetText:SetText(string.format("|cffffffff%s|r  |cff%s[%s]|r%s%s", name, typeColor, creatureType, sexBadge, ownedBadge))

    -- Distance & Radar Gauge
    if not CE:IsChanneling() then
        local distTier, distMod, distText, distColor = CE:GetStalkingDistance("target")
        
        if distTier == "CLOSE" then
            frame.RadarBar:SetStatusBarColor(0.0, 1.0, 0.6)
            frame.RadarBar:SetMinMaxValues(0, 100)
            frame.RadarBar:SetValue(100)
            frame.RadarBar.Text:SetText("|cff00ff99Close Stalk (~10 yd) • Optimal Observation Focus|r")
        elseif distTier == "PERIMETER" then
            frame.RadarBar:SetStatusBarColor(1.0, 0.82, 0.0)
            frame.RadarBar:SetMinMaxValues(0, 100)
            frame.RadarBar:SetValue(65)
            frame.RadarBar.Text:SetText("|cffffd100In Perimeter (15-28 yd) • Ready to Observe|r")
        else
            frame.RadarBar:SetStatusBarColor(0.9, 0.25, 0.25)
            frame.RadarBar:SetMinMaxValues(0, 100)
            frame.RadarBar:SetValue(20)
            frame.RadarBar.Text:SetText("|cffff4444Out of Range (>28 yd) • Close Distance!|r")
        end

        frame.InfoText:SetText("Field Study: |cff00ff99Study Quarry for Moves (+15 Attunement)|r • |cffffd100Capture in Battle|r")

        -- Action Button state
        if distTier == "OUT_OF_RANGE" then
            frame.ActionBtn:Disable()
            frame.ActionBtn:SetText("TOO FAR")
        else
            frame.ActionBtn:Enable()
            frame.ActionBtn:SetText("🔭 OBSERVE")
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
end

-- Channel Progress Bar Callbacks from CaptureEngine
function HUD:StartChannelBar(targetName, duration, netName)
    if not frame then return end
    frame:Show()
    frame.RadarBar:SetStatusBarColor(0.2, 0.8, 1.0)
    frame.RadarBar:SetMinMaxValues(0, duration)
    frame.RadarBar:SetValue(0)
    frame.RadarBar.Text:SetText(string.format("Observing %s: 0.0s / %.1fs [Studying...]", targetName, duration))
    frame.InfoText:SetText(string.format("Stalking |cffffd100%s|r... Maintain Line of Sight!", targetName))
    HUD:UpdateUI()
end

function HUD:UpdateChannelProgress(elapsed, duration)
    if not frame or not frame:IsShown() then return end
    frame.RadarBar:SetValue(math.min(duration, elapsed))
    local pct = math.min(100, (elapsed / duration) * 100)
    frame.RadarBar.Text:SetText(string.format("Observing: %.1fs / %.1fs (%.0f%%) [Studying...]", elapsed, duration, pct))
end

function HUD:StopChannelBar(reason)
    if not frame then return end
    HUD:UpdateUI()
end

function HUD:ShowCaptureResult(success, resultText, chance)
    if not frame or not frame:IsShown() then return end
    if success then
        frame.RadarBar:SetStatusBarColor(0.0, 1.0, 0.6)
        frame.RadarBar:SetValue(100)
        frame.RadarBar.Text:SetText(string.format("|cff00ff99%s|r", resultText or "Research Complete!"))
    else
        frame.RadarBar:SetStatusBarColor(0.9, 0.25, 0.25)
        frame.RadarBar.Text:SetText(string.format("|cffff4444Observation Slipped! (Quarry Untouched)|r"))
    end
    C_Timer.After(2.5, function()
        if frame and frame:IsShown() then
            HUD:UpdateUI()
        end
    end)
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
