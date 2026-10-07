--[[
    Forever Safari: UI Component - Training & Move Learning Drawer (JournalTrainingDrawer.lua)
    Allows players to inspect learned family abilities and assign them to companion move slots.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.JournalFrame = ns.JournalFrame or {}

local Journal = ns.JournalFrame
local Theme = ns.Theme
local DB = ns.Database
local C = ns.Constants

function Journal:BuildTrainingDrawer(parent)
    local drawer = Theme:CreateCard(parent, 280, 480)
    drawer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -68)
    drawer:SetFrameStrata("DIALOG")
    drawer:Hide()
    parent.TrainingDrawer = drawer

    local header = drawer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetPoint("TOPLEFT", 12, -12)
    header:SetText("|cffffd100⚡ Trainer Grimoire|r")
    drawer.Header = header

    local subHeader = drawer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subHeader:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
    subHeader:SetText("Select an ability to teach:")
    subHeader:SetTextColor(0.8, 0.85, 0.9)
    drawer.SubHeader = subHeader

    local closeBtn = Theme:CreateCloseButton(drawer)
    closeBtn:SetScript("OnClick", function()
        drawer:Hide()
        PlaySound(856)
    end)

    local scroll = CreateFrame("ScrollFrame", "ForeverSafariTrainingScroll", drawer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -48)
    scroll:SetPoint("BOTTOMRIGHT", -26, 10)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(240, 400)
    scroll:SetScrollChild(content)
    drawer.Content = content
    drawer.MoveButtons = {}
end

function Journal:OpenTrainingDrawer(slotIndex)
    local frame = self.frame or self
    local drawer = self.TrainingDrawer or (frame and frame.TrainingDrawer)
    if not drawer then return end
    local mob = self:GetSelectedCompanion()
    if not mob then return end

    drawer.targetSlot = slotIndex
    drawer.Header:SetText(string.format("|cffffd100⚡ Teach Move [Slot %d]|r", slotIndex))

    -- Populate learned moves for companion's family
    local content = drawer.Content
    local MoveDB = ns.MoveDB or {}
    local unlocked = DB:GetUnlockedAbilities()

    -- Hide all existing buttons
    for _, btn in ipairs(drawer.MoveButtons) do
        btn:Hide()
    end

    local btnIdx = 1
    local yOffset = 0

    for moveId, move in pairs(MoveDB) do
        if type(move) == "table" and move.name then
            local isUnlocked = unlocked[tostring(moveId)] or (move.family == mob.family) or (move.element == mob.element) or (move.family == "Beast")
            if isUnlocked then
                local btn = drawer.MoveButtons[btnIdx]
                if not btn then
                    btn = CreateFrame("Button", nil, content, "BackdropTemplate")
                    btn:SetSize(236, 44)
                    Theme:ApplyCardBackdrop(btn)

                    local icon = btn:CreateTexture(nil, "ARTWORK")
                    icon:SetSize(30, 30)
                    icon:SetPoint("LEFT", 6, 0)
                    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    btn.Icon = icon

                    local title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -2)
                    title:SetPoint("TOPRIGHT", -4, -2)
                    title:SetJustifyH("LEFT")
                    btn.Title = title

                    local sub = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
                    sub:SetPoint("TOPRIGHT", -4, -2)
                    sub:SetJustifyH("LEFT")
                    btn.Sub = sub

                    btn:SetScript("OnClick", function(self)
                        DB:SetMobAbility(mob.id, drawer.targetSlot, self.moveId)
                        drawer:Hide()
                        Journal:UpdateRosterView()
                        PlaySound(856)
                    end)

                    btn:SetScript("OnEnter", function(self)
                        self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                        if self.moveId then
                            Theme:ShowAbilityTooltip(self, self.moveId, "ANCHOR_LEFT")
                        end
                    end)
                    btn:SetScript("OnLeave", function(self)
                        self:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.8)
                        Theme:HideAbilityTooltip()
                    end)

                    drawer.MoveButtons[btnIdx] = btn
                end

                btn:SetPoint("TOPLEFT", content, "TOPLEFT", 2, yOffset)
                btn.moveId = moveId
                btn.Icon:SetTexture(move.icon or "Interface\\Icons\\Ability_GhoulFrenzy")
                btn.Title:SetText(string.format("%s |cffffd100[%s]|r", move.name, move.element or "Physical"))
                local pwrText = (move.power and move.power > 0) and string.format("Pwr: %d | ", move.power) or ""
                local cdText = (move.cooldown and move.cooldown > 0) and string.format("%dt CD", move.cooldown) or "Instant"
                btn.Sub:SetText(pwrText .. cdText)

                btn:Show()
                yOffset = yOffset - 48
                btnIdx = btnIdx + 1
            end
        end
    end

    content:SetHeight(math.max(400, math.abs(yOffset) + 10))
    drawer:Show()
    PlaySound(856)
end
