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
    frame:SetSize(330, 148)
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
    radarBar:SetSize(306, 20)
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
    local cageTypes = { "copper_cage", "iron_cage", "mithril_cage", "arcanite_capsule" }
    local btnSize = 32
    local startX = 12

    for i, cageId in ipairs(cageTypes) do
        local cageData = C.CAGES[cageId] or {}
        local cBtn = CreateFrame("Button", "ForeverSafariHUDNet" .. i, frame, "BackdropTemplate")
        cBtn:SetSize(btnSize, btnSize)
        cBtn:SetPoint("BOTTOMLEFT", startX + (i - 1) * (btnSize + 6), 10)

        Theme:ApplyCardBackdrop(cBtn)

        local icon = cBtn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexture(cageData.icon or "Interface\\Icons\\INV_Misc_Net_01")
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

    -- Stalk & Snare Action Button
    local actionBtn = CreateFrame("Button", "ForeverSafariHUDActionBtn", frame, "UIPanelButtonTemplate")
    actionBtn:SetSize(136, 32)
    actionBtn:SetPoint("BOTTOMRIGHT", -12, 10)
    actionBtn:SetText("STALK & SNARE")
    actionBtn:SetScript("OnClick", function()
        if CE:IsChanneling() then
            CE:CancelSnareChannel("Cancelled by player.")
        else
            CE:AttemptCapture("target", selectedCageId)
        end
        HUD:UpdateUI()
    end)
    frame.ActionBtn = actionBtn

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
        end
    end)

    -- Poller for smooth live proximity detection
    eventFrame:SetScript("OnUpdate", function(self, elapsed)
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
    if not UnitExists("target") or UnitIsDead("target") or UnitIsPlayer("target") then
        if CE:IsChanneling() then
            CE:CancelSnareChannel("Target lost.")
        end
        frame:Hide()
        return
    end

    local reaction = UnitReaction("player", "target")
    if not isSecret(reaction) and reaction and reaction > 4 then
        frame:Hide()
        return
    end

    local name = UnitName("target")
    if isSecret(name) or not name or name == "" then name = "Wild Creature" end

    local rawType = UnitCreatureType("target") or "Beast"
    if isSecret(rawType) then rawType = "Beast" end

    local creatureType = C.NormalizeCreatureType(rawType, name)
    DB:RecordSeenMob(name, creatureType)

    frame:Show()
    HUD:UpdateUI()
end

function HUD:UpdateUI()
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
            frame.ActionBtn:SetText("OUT OF RANGE")
        else
            frame.ActionBtn:Enable()
            frame.ActionBtn:SetText("STALK & SNARE")
        end
    else
        -- Active Channeling mode
        frame.ActionBtn:Enable()
        frame.ActionBtn:SetText("|cffff4444CANCEL SNARE|r")
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


