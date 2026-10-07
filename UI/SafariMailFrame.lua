--[[
    Forever Safari: Nesingwary Mailbox Dispatch & Quest Hub
    Zero-Taint Standalone Sidecar Window (Parented strictly to UIParent).
    Opens docked alongside Blizzard's MailFrame on MAIL_SHOW without injecting
    frames or tabs into MailFrame, preventing all ADDON_ACTION_BLOCKED taint errors.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.SafariMailFrame = ns.SafariMailFrame or {}

local Mail = ns.SafariMailFrame
local C = ns.Constants
local DB = ns.Database
local Theme = ns.Theme

local mailFrame = nil
local openMailFrame = nil
local selectedLetterId = 1
local listButtons = {}

function Mail:Initialize()
    if mailFrame then return end

    -- 1. Create Main Standalone Dispatch Inbox Sidecar (UIParent)
    mailFrame = CreateFrame("Frame", "ForeverSafariMailSidecarFrame", UIParent, "BackdropTemplate")
    mailFrame:SetSize(320, 440)
    mailFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    mailFrame:SetFrameStrata("HIGH")
    mailFrame:SetMovable(true)
    mailFrame:EnableMouse(true)
    mailFrame:RegisterForDrag("LeftButton")
    mailFrame:SetClampedToScreen(true)

    Theme:ApplyFrameBackdrop(mailFrame, true)

    mailFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mailFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Header Title & Icon
    local headIcon = mailFrame:CreateTexture(nil, "ARTWORK")
    headIcon:SetSize(24, 24)
    headIcon:SetPoint("TOPLEFT", 12, -10)
    headIcon:SetTexture("Interface\\Icons\\INV_Letter_15")
    headIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local headTitle = mailFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headTitle:SetPoint("LEFT", headIcon, "RIGHT", 8, 0)
    headTitle:SetText("|cffffd100Safari Dispatches|r")

    local countText = mailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOPRIGHT", mailFrame, "TOPRIGHT", -34, -14)
    mailFrame.CountText = countText

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, mailFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        mailFrame:Hide()
        if openMailFrame then openMailFrame:Hide() end
    end)

    -- Subheader
    local subBar = CreateFrame("Frame", nil, mailFrame, "BackdropTemplate")
    subBar:SetSize(296, 24)
    subBar:SetPoint("TOPLEFT", 12, -38)
    subBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    subBar:SetBackdropColor(0.06, 0.08, 0.12, 0.9)
    subBar:SetBackdropBorderColor(0.0, 0.9, 0.5, 0.7)

    local subText = subBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subText:SetPoint("LEFT", 8, 0)
    subText:SetText("Hemet Nesingwary's Official Directives")
    subText:SetTextColor(0.0, 1.0, 0.6)

    -- Scrollable Container for Full-Width Dispatch Rows
    local scrollFrame = CreateFrame("ScrollFrame", "ForeverSafariMailScrollFrame", mailFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", subBar, "BOTTOMLEFT", 0, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", mailFrame, "BOTTOMRIGHT", -28, 12)

    local scrollChild = CreateFrame("Frame", "ForeverSafariMailScrollChild", scrollFrame)
    scrollChild:SetSize(280, 400)
    scrollFrame:SetScrollChild(scrollChild)
    mailFrame.ScrollChild = scrollChild

    -- Build row buttons
    listButtons = {}
    local dispatches = C.NESINGWARY_DISPATCHES or {}

    for i, dispatch in ipairs(dispatches) do
        local btn = CreateFrame("Button", "ForeverSafariMailItem" .. i, scrollChild, "BackdropTemplate")
        btn:SetSize(276, 52)
        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((i - 1) * 56))
        btn.letterId = dispatch.id

        Theme:ApplyCardBackdrop(btn)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
        hl:SetVertexColor(1, 0.82, 0, 0.25)
        btn.Highlight = hl

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", 6, 0)
        icon:SetTexture(dispatch.icon or "Interface\\Icons\\INV_Box_01")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.Icon = icon

        local iconBorder = btn:CreateTexture(nil, "OVERLAY")
        iconBorder:SetSize(38, 38)
        iconBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
        iconBorder:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
        iconBorder:SetVertexColor(0.8, 0.7, 0.3, 0.8)

        local sender = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sender:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
        sender:SetPoint("TOPRIGHT", -8, -2)
        sender:SetJustifyH("LEFT")
        sender:SetText("|cffffd100" .. (dispatch.sender or "Expedition") .. "|r")
        btn.Sender = sender

        local title = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", sender, "BOTTOMLEFT", 0, -2)
        title:SetPoint("TOPRIGHT", -8, -2)
        title:SetJustifyH("LEFT")
        title:SetText(dispatch.title or "Safari Dispatch")
        btn.Title = title

        local statusText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
        statusText:SetJustifyH("LEFT")
        btn.StatusText = statusText

        btn:SetScript("OnClick", function(self)
            Mail:OpenLetter(self.letterId)
        end)

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        end)

        btn:SetScript("OnLeave", function(self)
            if self.letterId == selectedLetterId and openMailFrame and openMailFrame:IsShown() then
                self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
            else
                self:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
            end
        end)

        listButtons[i] = btn
    end

    scrollChild:SetHeight(#dispatches * 56 + 10)
    mailFrame:Hide()

    -- 2. Build Secondary OpenMail Reading Pane
    Mail:BuildOpenMailFrame()

    -- 3. Register Blizzard Mailbox Events (Zero Taint Event Handlers)
    local eventFrame = CreateFrame("Frame", "ForeverSafariMailEventFrame")
    eventFrame:RegisterEvent("MAIL_SHOW")
    eventFrame:RegisterEvent("MAIL_CLOSED")

    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "MAIL_SHOW" then
            Mail:OnMailboxOpen()
        elseif event == "MAIL_CLOSED" then
            Mail:OnMailboxClose()
        end
    end)
end

function Mail:OnMailboxOpen()
    if not mailFrame then Mail:Initialize() end

    -- Dock cleanly to the right of MailFrame if MailFrame exists
    if MailFrame and MailFrame:IsShown() then
        mailFrame:ClearAllPoints()
        mailFrame:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 10, 0)
    else
        mailFrame:ClearAllPoints()
        mailFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    mailFrame:Show()
    Mail:UpdateUI()
    Mail:UpdateTabBadge()

    -- Auto-open starter parcel letter if unclaimed
    if not DB:IsStarterClaimed() then
        C_Timer.After(0.1, function()
            if mailFrame and mailFrame:IsShown() and not DB:IsStarterClaimed() then
                Mail:OpenLetter(1)
            end
        end)
    end
end

function Mail:OnMailboxClose()
    if mailFrame then
        mailFrame:Hide()
    end
    if openMailFrame then
        openMailFrame:Hide()
    end
end

function Mail:SelectSafariTab()
    if not mailFrame then Mail:Initialize() end
    if mailFrame:IsShown() then
        mailFrame:Hide()
        if openMailFrame then openMailFrame:Hide() end
    else
        Mail:OnMailboxOpen()
    end
end

function Mail:UpdateTabVisuals(isSelected)
    -- Maintained for API compatibility
end

function Mail:UpdateTabBadge()
    local hasUnclaimedOrUnread = false
    if not DB:IsStarterClaimed() then
        hasUnclaimedOrUnread = true
    end

    for _, dispatch in ipairs(C.NESINGWARY_DISPATCHES or {}) do
        if not DB:IsLetterRead(dispatch.id) then
            hasUnclaimedOrUnread = true
            break
        end
        if not dispatch.isStarter then
            local progress = DB:GetQuestProgress(dispatch.questType)
            if dispatch.targetCount and progress >= dispatch.targetCount and not DB:IsQuestClaimed(dispatch.id) then
                hasUnclaimedOrUnread = true
                break
            end
        end
    end

    if mailFrame and mailFrame.CountText then
        local count = #(C.NESINGWARY_DISPATCHES or {})
        if hasUnclaimedOrUnread then
            mailFrame.CountText:SetText(string.format("|cff00ff00Dispatches: %d (!)|r", count))
        else
            mailFrame.CountText:SetText(string.format("|cffaaaaaaDispatches: %d|r", count))
        end
    end
end

-- =========================================================================
-- ✉️ VIEW 2: SECONDARY WOW-STYLE OPEN MAIL WINDOW (Attached Sidecar)
-- =========================================================================
function Mail:BuildOpenMailFrame()
    if openMailFrame then return end

    openMailFrame = CreateFrame("Frame", "ForeverSafariOpenMailFrame", UIParent, "BackdropTemplate")
    openMailFrame:SetSize(340, 440)
    openMailFrame:SetFrameStrata("HIGH")
    openMailFrame:SetMovable(true)
    openMailFrame:EnableMouse(true)
    openMailFrame:RegisterForDrag("LeftButton")
    openMailFrame:SetClampedToScreen(true)

    Theme:ApplyFrameBackdrop(openMailFrame, true)

    openMailFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    openMailFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local closeBtn = CreateFrame("Button", nil, openMailFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        openMailFrame:Hide()
        Mail:UpdateUI()
    end)
    openMailFrame.CloseButton = closeBtn

    local seal = openMailFrame:CreateTexture(nil, "ARTWORK")
    seal:SetSize(30, 30)
    seal:SetPoint("TOPLEFT", 12, -10)
    seal:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
    seal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    openMailFrame.Seal = seal

    local winTitle = openMailFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    winTitle:SetPoint("TOPLEFT", seal, "TOPRIGHT", 8, 2)
    winTitle:SetText("|cffffd100Nesingwary Expedition Mail|r")

    local winSubtitle = openMailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    winSubtitle:SetPoint("TOPLEFT", winTitle, "BOTTOMLEFT", 0, -2)
    winSubtitle:SetText("Official Safari League Correspondence")
    winSubtitle:SetTextColor(0.7, 0.8, 0.9)

    -- Header Info Card
    local headerCard = Theme:CreateCard(openMailFrame, 316, 52)
    headerCard:SetPoint("TOPLEFT", 12, -44)
    headerCard:SetPoint("TOPRIGHT", -12, -44)
    openMailFrame.HeaderCard = headerCard

    local senderText = headerCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    senderText:SetPoint("TOPLEFT", 8, -6)
    senderText:SetPoint("TOPRIGHT", -8, -6)
    senderText:SetJustifyH("LEFT")
    headerCard.SenderText = senderText

    local subjectText = headerCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subjectText:SetPoint("TOPLEFT", senderText, "BOTTOMLEFT", 0, -4)
    subjectText:SetPoint("TOPRIGHT", -8, -4)
    subjectText:SetJustifyH("LEFT")
    headerCard.SubjectText = subjectText

    -- Letter Body Scroll Area
    local bodyCard = Theme:CreateCard(openMailFrame, 316, 210)
    bodyCard:SetPoint("TOPLEFT", headerCard, "BOTTOMLEFT", 0, -6)
    bodyCard:SetPoint("BOTTOMRIGHT", -12, 114)
    bodyCard:SetBackdropColor(0.05, 0.07, 0.09, 0.95)

    local bodyScroll = CreateFrame("ScrollFrame", "ForeverSafariOpenMailScroll", bodyCard, "UIPanelScrollFrameTemplate")
    bodyScroll:SetPoint("TOPLEFT", 8, -8)
    bodyScroll:SetPoint("BOTTOMRIGHT", -24, 8)

    local bodyContent = CreateFrame("Frame", nil, bodyScroll)
    bodyContent:SetSize(280, 200)
    bodyScroll:SetScrollChild(bodyContent)

    local bodyText = bodyContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bodyText:SetPoint("TOPLEFT", 0, 0)
    bodyText:SetPoint("TOPRIGHT", 0, 0)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetTextColor(0.88, 0.90, 0.92)
    bodyText:SetSpacing(3)
    openMailFrame.BodyText = bodyText
    openMailFrame.BodyContent = bodyContent

    -- Bottom Attachment & Claim Tray
    local tray = Theme:CreateCard(openMailFrame, 316, 96)
    tray:SetPoint("BOTTOMLEFT", 12, 10)
    tray:SetPoint("BOTTOMRIGHT", -12, 10)
    tray:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.8)
    openMailFrame.Tray = tray

    local itemSlot = CreateFrame("Button", nil, tray, "BackdropTemplate")
    itemSlot:SetSize(40, 40)
    itemSlot:SetPoint("TOPLEFT", 8, -8)
    Theme:ApplyCardBackdrop(itemSlot, true)

    local itemIcon = itemSlot:CreateTexture(nil, "ARTWORK")
    itemIcon:SetAllPoints()
    itemIcon:SetTexture("Interface\\Icons\\INV_Box_01")
    itemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    itemSlot.Icon = itemIcon

    local itemBorder = itemSlot:CreateTexture(nil, "OVERLAY")
    itemBorder:SetSize(42, 42)
    itemBorder:SetPoint("CENTER", itemSlot, "CENTER", 0, 0)
    itemBorder:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    itemBorder:SetVertexColor(1.0, 0.82, 0.0, 0.9)
    tray.ItemSlot = itemSlot

    local trayHeader = tray:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    trayHeader:SetPoint("TOPLEFT", itemSlot, "TOPRIGHT", 8, 0)
    trayHeader:SetPoint("TOPRIGHT", -8, 0)
    trayHeader:SetJustifyH("LEFT")
    tray.Header = trayHeader

    local traySummary = tray:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    traySummary:SetPoint("TOPLEFT", trayHeader, "BOTTOMLEFT", 0, -2)
    traySummary:SetPoint("TOPRIGHT", -8, -2)
    traySummary:SetJustifyH("LEFT")
    tray.Summary = traySummary

    local actionBtn = Theme:CreateButton(tray, "CLAIM", 180, 26, true)
    actionBtn:SetPoint("BOTTOMLEFT", 8, 8)
    actionBtn:SetPoint("BOTTOMRIGHT", -8, 8)
    tray.ActionBtn = actionBtn

    openMailFrame:Hide()
end

function Mail:OpenLetter(letterId)
    selectedLetterId = letterId or 1
    DB:MarkLetterRead(selectedLetterId)

    if not openMailFrame then
        Mail:BuildOpenMailFrame()
    end

    if mailFrame and mailFrame:IsShown() then
        openMailFrame:ClearAllPoints()
        openMailFrame:SetPoint("TOPLEFT", mailFrame, "TOPRIGHT", 10, 0)
    elseif MailFrame and MailFrame:IsShown() then
        openMailFrame:ClearAllPoints()
        openMailFrame:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 10, 0)
    end

    openMailFrame:Show()
    Mail:UpdateUI()
    PlaySound(844) -- SOUNDKIT.IG_SPELLBOOK_OPEN
end

function Mail:UpdateUI()
    if not mailFrame or not mailFrame:IsShown() then return end

    local dispatches = C.NESINGWARY_DISPATCHES or {}
    local currentDispatch = dispatches[selectedLetterId] or dispatches[1]

    for i, btn in ipairs(listButtons) do
        local dispatch = dispatches[i]
        if dispatch then
            local isRead = DB:IsLetterRead(dispatch.id)

            if dispatch.isStarter then
                if DB:IsStarterClaimed() then
                    btn.StatusText:SetText("|cff888888[Archived]|r")
                else
                    btn.StatusText:SetText("|cffffd100[ 📦 Unopened Parcel ]|r")
                end
            else
                local progress = DB:GetQuestProgress(dispatch.questType)
                local target = dispatch.targetCount or 1
                local isClaimed = DB:IsQuestClaimed(dispatch.id)

                if isClaimed then
                    btn.StatusText:SetText("|cff888888[Archived]|r")
                elseif progress >= target then
                    btn.StatusText:SetText("|cff00ff99[ ✔ Ready to Claim ]|r")
                elseif not isRead then
                    btn.StatusText:SetText("|cffffd100[ ✉️ New ]|r")
                else
                    btn.StatusText:SetText(string.format("|cffffcc00[ Progress: %d / %d ]|r", progress, target))
                end
            end

            if dispatch.id == selectedLetterId and openMailFrame and openMailFrame:IsShown() then
                btn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                btn:SetBackdropColor(0.14, 0.18, 0.24, 0.95)
            else
                btn:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
                btn:SetBackdropColor(0.08, 0.10, 0.14, 0.85)
            end
        end
    end

    if openMailFrame and openMailFrame:IsShown() and currentDispatch then
        local headerCard = openMailFrame.HeaderCard
        headerCard.SenderText:SetText(string.format("|cffaaaaaaFrom:|r |cffffd100%s|r (|cff00ff99%s|r)", currentDispatch.sender or "Expedition HQ", currentDispatch.location or "Azeroth"))
        headerCard.SubjectText:SetText(string.format("|cffaaaaaaSubject:|r |cffffffff%s|r", currentDispatch.title or "Dispatch"))

        openMailFrame.BodyText:SetText(currentDispatch.body or "")
        openMailFrame.BodyContent:SetHeight(openMailFrame.BodyText:GetStringHeight() + 24)

        local tray = openMailFrame.Tray
        tray.ItemSlot.Icon:SetTexture(currentDispatch.icon or "Interface\\Icons\\INV_Box_01")

        tray.ItemSlot:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if currentDispatch.isStarter then
                GameTooltip:AddLine("Safari League Starter Kit", 1, 0.82, 0)
                GameTooltip:AddLine("Enclosed Items:", 1, 1, 1)
                GameTooltip:AddLine("• Racial Level 1 Companion Crate", 0, 1, 0.6)
                GameTooltip:AddLine("• 10x Copper Snares", 0, 1, 0.6)
                GameTooltip:AddLine("• 5x Safari Healing Salves (Full Restore)", 0, 1, 0.6)
                GameTooltip:AddLine("• 1x Revival Crystal (Full Revive)", 0, 1, 0.6)
                GameTooltip:AddLine("• Forever Safari Field Guide", 0, 1, 0.6)
            else
                GameTooltip:AddLine(currentDispatch.title, 1, 0.82, 0)
                GameTooltip:AddLine(currentDispatch.summary or "Field Directive", 1, 1, 1)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Turn-in Rewards:", 1, 0.82, 0)
                if currentDispatch.rewards and currentDispatch.rewards.tokens and currentDispatch.rewards.tokens > 0 then
                    GameTooltip:AddDoubleLine("Safari Tokens:", string.format("+%d", currentDispatch.rewards.tokens), 1, 1, 1, 1, 0.82, 0)
                end
                if currentDispatch.rewards and currentDispatch.rewards.items then
                    for _, itm in ipairs(currentDispatch.rewards.items) do
                        local itemsDB = C.SAFARI_ITEMS or C.ITEMS or {}
                        local cagesDB = C.CAGES or {}
                        local itmData = itemsDB[itm.id] or cagesDB[itm.id] or {}
                        GameTooltip:AddDoubleLine(itmData.name or itm.id, string.format("x%d", itm.count), 0.8, 0.9, 1, 1, 1, 1)
                    end
                end
            end
            GameTooltip:Show()
        end)
        tray.ItemSlot:SetScript("OnLeave", function() GameTooltip:Hide() end)

        if currentDispatch.isStarter then
            tray.Header:SetText("|cffffd100Attached Parcel:|r Starter Companion Kit")
            if DB:IsStarterClaimed() then
                tray.Summary:SetText("|cff00ff00Starter crate collected and unboxed.|r")
                tray.ActionBtn:Disable()
                tray.ActionBtn:SetText("✔ CRATE UNBOXED")
            else
                tray.Summary:SetText("|cffffff00Contains: Companion + 10x Nets + 5x Salves + 1x Revive Shard|r")
                tray.ActionBtn:Enable()
                tray.ActionBtn:SetText("📦 UNBOX STARTER CRATE")
                tray.ActionBtn:SetScript("OnClick", function()
                    DB:ClaimStarterKit()
                    Mail:UpdateUI()
                    Mail:UpdateTabBadge()
                end)
            end
        else
            local progress = DB:GetQuestProgress(currentDispatch.questType)
            local target = currentDispatch.targetCount or 1
            local isClaimed = DB:IsQuestClaimed(currentDispatch.id)

            tray.Header:SetText(string.format("|cffffd100Directive:|r %s", currentDispatch.summary or "Field Bounty"))

            if isClaimed then
                tray.Summary:SetText("|cff888888Rewards claimed! Bounty archived.|r")
                tray.ActionBtn:Disable()
                tray.ActionBtn:SetText("✔ REWARDS CLAIMED")
            elseif progress >= target then
                tray.Summary:SetText(string.format("|cff00ff00Progress: %d / %d (Objective Complete!)|r", progress, target))
                tray.ActionBtn:Enable()
                tray.ActionBtn:SetText("🎁 CLAIM BOUNTY REWARDS")
                tray.ActionBtn:SetScript("OnClick", function()
                    DB:ClaimQuestReward(currentDispatch.id)
                    Mail:UpdateUI()
                    Mail:UpdateTabBadge()
                end)
            else
                tray.Summary:SetText(string.format("|cffff4444Progress: %d / %d (Incomplete in field)|r", progress, target))
                tray.ActionBtn:Disable()
                tray.ActionBtn:SetText(string.format("INCOMPLETE (%d / %d)", progress, target))
            end
        end
    end
end

function Mail:IsShown()
    return mailFrame and mailFrame:IsShown()
end
