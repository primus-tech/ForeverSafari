--[[
    Forever Safari: UI Component - Active Squad Team Dock (JournalTeamDock.lua)
    Renders the bottom 4-slot team dock with mini 3D paperdoll pedestals,
    health bars, and active companion switching.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.JournalFrame = ns.JournalFrame or {}

local Journal = ns.JournalFrame
local Theme = ns.Theme
local DB = ns.Database
local C = ns.Constants

function Journal:BuildTeamDock(parent)
    local dock = Theme:CreateCard(parent, 816, 52)
    dock:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 12, 6)
    parent.TeamDock = dock

    local dockLabel = dock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dockLabel:SetPoint("LEFT", dock, "LEFT", 10, 0)
    dockLabel:SetText("|cff00ff99Active Squad|r\n(Slots 1-4)")

    parent.TeamSlots = {}
    for i = 1, 4 do
        local slot = Theme:CreateCard(dock, 168, 42)
        slot:SetPoint("LEFT", dockLabel, "RIGHT", 12 + ((i - 1) * 174), 0)
        slot.slotIndex = i

        -- Mini 3D Model Pedestal
        local miniModel = CreateFrame("PlayerModel", nil, slot)
        miniModel:SetSize(36, 36)
        miniModel:SetPoint("LEFT", 4, 0)
        miniModel:EnableMouse(false)
        slot.MiniModel = miniModel

        local slotName = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        slotName:SetPoint("TOPLEFT", miniModel, "TOPRIGHT", 6, -2)
        slotName:SetPoint("TOPRIGHT", -4, -2)
        slotName:SetJustifyH("LEFT")
        slotName:SetText("Empty Slot")
        slot.Name = slotName

        local slotInfo = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slotInfo:SetPoint("TOPLEFT", slotName, "BOTTOMLEFT", 0, -2)
        slotInfo:SetPoint("TOPRIGHT", -4, -2)
        slotInfo:SetJustifyH("LEFT")
        slotInfo:SetText("---")
        slot.Info = slotInfo

        -- Health Gauge
        local hpBar = CreateFrame("StatusBar", nil, slot)
        hpBar:SetSize(118, 4)
        hpBar:SetPoint("BOTTOMLEFT", miniModel, "BOTTOMRIGHT", 6, 2)
        hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        hpBar:SetStatusBarColor(0.2, 0.8, 0.2)
        hpBar:SetMinMaxValues(0, 100)
        hpBar:SetValue(100)
        local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
        hpBg:SetAllPoints()
        hpBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        slot.HPBar = hpBar

        slot:EnableMouse(true)
        slot:SetScript("OnMouseDown", function(self, button)
            local team = DB:GetTeam()
            local mobId = team[self.slotIndex]
            if mobId then
                DB:SetActiveSlot(self.slotIndex)
                if Journal.SelectCompanion then
                    Journal:SelectCompanion(mobId)
                end
                Journal:UpdateUI()
                PlaySound(856)
            end
        end)

        slot:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.0, 1.0, 0.6, 1.0)
            local team = DB:GetTeam()
            local mobId = team[self.slotIndex]
            local mob = mobId and DB:GetMobById(mobId)
            if mob then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(mob.customNickname or mob.name, 1, 0.82, 0)
                GameTooltip:AddLine(string.format("Family: %s | Rank %s", mob.family or "Beast", mob.attunementRank or 1), 1, 1, 1)
                GameTooltip:AddLine("Click to deploy as active companion.", 0.6, 0.8, 1.0)
                GameTooltip:Show()
            end
        end)

        slot:SetScript("OnLeave", function(self)
            local team = DB:GetTeam()
            local mobId = team[self.slotIndex]
            local isActive = (self.slotIndex == (ForeverSafariDB and ForeverSafariDB.activeSlot or 1))
            if isActive then
                self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
            else
                self:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)
            end
            GameTooltip:Hide()
        end)

        parent.TeamSlots[i] = slot
    end
end

function Journal:UpdateTeamDock()
    local frame = self.frame or self
    local teamSlots = frame.TeamSlots or (self.frame and self.frame.TeamSlots)
    if not teamSlots then return end

    local team = DB:GetTeam()
    local activeSlot = ForeverSafariDB and ForeverSafariDB.activeSlot or 1

    for i = 1, 4 do
        local slotBtn = frame.TeamSlots[i]
        local mobId = team[i]
        local mob = mobId and DB:GetMobById(mobId)

        if mob then
            slotBtn.Name:SetText(mob.customNickname or mob.name)
            slotBtn.Info:SetText(string.format("Rank %s | %s", mob.attunementRank or 1, mob.family or "Beast"))
            if slotBtn.MiniModel then
                slotBtn.MiniModel:Show()
                slotBtn.MiniModel:SetDisplayInfo(mob.displayId or 903)
                slotBtn.MiniModel:SetRotation(math.rad(15))
            end

            local curHP = mob.currentHP or mob.hp or 60
            local maxHP = mob.maxHP or mob.hp or 60
            slotBtn.HPBar:SetMinMaxValues(0, maxHP)
            slotBtn.HPBar:SetValue(curHP)
            if curHP <= (maxHP * 0.25) then
                slotBtn.HPBar:SetStatusBarColor(1.0, 0.2, 0.2)
            else
                slotBtn.HPBar:SetStatusBarColor(0.2, 0.8, 0.2)
            end
            slotBtn.HPBar:Show()

            if i == activeSlot then
                slotBtn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                slotBtn:SetBackdropColor(0.18, 0.15, 0.08, 0.95)
            else
                slotBtn:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)
                slotBtn:SetBackdropColor(0.12, 0.16, 0.22, 0.85)
            end
        else
            slotBtn.Name:SetText("|cff666666(Empty Slot)|r")
            slotBtn.Info:SetText("|cff444444No companion|r")
            if slotBtn.MiniModel then
                slotBtn.MiniModel:ClearModel()
                slotBtn.MiniModel:Hide()
            end
            slotBtn.HPBar:Hide()
            slotBtn:SetBackdropBorderColor(0.15, 0.18, 0.22, 0.5)
            slotBtn:SetBackdropColor(0.06, 0.08, 0.10, 0.6)
        end
    end
end
