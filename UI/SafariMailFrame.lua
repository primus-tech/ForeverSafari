--[[
    Forever Safari: Nesingwary Mailbox Dispatch & Quest Hub
    Adds an authentic custom tab to the Blizzard MailFrame ("Safari").
    Acts like a standard WoW Mail Inbox with a full-width column of received dispatches.
    Clicking any dispatch opens a secondary sidecar window ("Open Mail") with custom Nesingwary styling,
    parchment letter body, and attachment unbox/claim tray.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.SafariMailFrame = ns.SafariMailFrame or {}

local Mail = ns.SafariMailFrame
local C = ns.Constants
local DB = ns.Database
local Theme = ns.Theme

local mailContainer = nil
local openMailFrame = nil
local mailTabBtn = nil
local selectedLetterId = 1
local listButtons = {}

local hooksInitialized = false

function Mail:Initialize()
    -- Register Blizzard Mailbox Events
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

    if not hooksInitialized and hooksecurefunc then
        hooksInitialized = true
        if MailFrameTab_OnClick then
            hooksecurefunc("MailFrameTab_OnClick", function(tab)
                if mailContainer then mailContainer:Hide() end
                if openMailFrame then openMailFrame:Hide() end
                Mail:UpdateTabVisuals(false)
            end)
        end
    end
end

function Mail:OnMailboxOpen()
    if not MailFrame then return end

    -- Create custom Safari Tab button attached to MailFrame
    if not mailTabBtn then
        mailTabBtn = CreateFrame("Button", "ForeverSafariMailTab", MailFrame, "BackdropTemplate")
        mailTabBtn:SetSize(72, 28)
        Theme:ApplyCardBackdrop(mailTabBtn, true)
        mailTabBtn:SetBackdropColor(0.10, 0.14, 0.20, 0.95)
        mailTabBtn:SetBackdropBorderColor(0.3, 0.4, 0.5, 0.8)

        local tabLabel = mailTabBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tabLabel:SetPoint("CENTER", 0, 0)
        tabLabel:SetText("|cffffd100Safari|r")
        mailTabBtn.Label = tabLabel
        
        -- Anchor tab to MailFrameTab2 or MailFrame
        if MailFrameTab2 then
            mailTabBtn:SetPoint("LEFT", MailFrameTab2, "RIGHT", 4, 0)
        elseif MailFrameTab1 then
            mailTabBtn:SetPoint("LEFT", MailFrameTab1, "RIGHT", 4, 0)
        else
            mailTabBtn:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 130, -30)
        end

        mailTabBtn:SetScript("OnClick", function()
            Mail:SelectSafariTab()
        end)

        mailTabBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Nesingwary Safari Dispatches", 1, 0.82, 0)
            GameTooltip:AddLine("View official expedition directives, bounties, and unbox reward parcels.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        mailTabBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    -- Create inner Mail Container inside MailFrame (covering the main Inbox area)
    if not mailContainer then
        mailContainer = CreateFrame("Frame", "ForeverSafariMailContainer", MailFrame, "BackdropTemplate")
        local inset = (MailFrame and (MailFrame.Inset or MailFrameInset))
        if inset then
            mailContainer:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
            mailContainer:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -4, 4)
        else
            mailContainer:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 14, -62)
            mailContainer:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -14, 28)
        end
        mailContainer:SetFrameLevel(MailFrame:GetFrameLevel() + 20)
        mailContainer:Hide()

        Mail:BuildInboxList(mailContainer)
    end

    -- Create secondary sidecar OpenMail window
    if not openMailFrame then
        Mail:BuildOpenMailFrame()
    end

    mailTabBtn:Show()
    Mail:UpdateTabVisuals(false)
    Mail:UpdateTabBadge()

    -- Auto-select Safari Dispatch tab if starter kit is waiting to be unboxed!
    if not DB:IsStarterClaimed() then
        C_Timer.After(0.1, function()
            if MailFrame and MailFrame:IsShown() and not DB:IsStarterClaimed() then
                Mail:SelectSafariTab()
                Mail:OpenLetter(1)
            end
        end)
    end
end

function Mail:OnMailboxClose()
    if mailContainer then
        mailContainer:Hide()
    end
    if openMailFrame then
        openMailFrame:Hide()
    end
    Mail:UpdateTabVisuals(false)
end

function Mail:SelectSafariTab()
    if not MailFrame or not mailContainer then return end

    mailContainer:Show()
    Mail:UpdateTabVisuals(true)
    Mail:UpdateUI()
    PlaySound(844) -- SOUNDKIT.IG_SPELLBOOK_OPEN
end

function Mail:UpdateTabVisuals(isSelected)
    if not mailTabBtn then return end
    if isSelected then
        mailTabBtn:SetBackdropBorderColor(0.0, 1.0, 0.6, 1.0)
        mailTabBtn:SetBackdropColor(0.06, 0.16, 0.12, 0.98)
    else
        mailTabBtn:SetBackdropBorderColor(0.3, 0.4, 0.5, 0.8)
        mailTabBtn:SetBackdropColor(0.10, 0.14, 0.20, 0.95)
    end
end

function Mail:UpdateTabBadge()
    if not mailTabBtn or not mailTabBtn.Label then return end
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

    if hasUnclaimedOrUnread then
        mailTabBtn.Label:SetText("|cff00ff00Safari (!)|r")
    else
        mailTabBtn.Label:SetText("|cffffd100Safari|r")
    end
end

-- =========================================================================
-- 📬 VIEW 1: FULL-WIDTH INBOX COLUMN (Drives MailFrame Interior)
-- =========================================================================
function Mail:BuildInboxList(parent)
    Theme:ApplyCardBackdrop(parent)

    -- Header Banner
    local headerBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    headerBar:SetHeight(38)
    headerBar:SetPoint("TOPLEFT", 4, -4)
    headerBar:SetPoint("TOPRIGHT", -4, -4)
    Theme:ApplyCardBackdrop(headerBar, true)

    local headIcon = headerBar:CreateTexture(nil, "ARTWORK")
    headIcon:SetSize(24, 24)
    headIcon:SetPoint("LEFT", 8, 0)
    headIcon:SetTexture("Interface\\Icons\\INV_Letter_15")
    headIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local headTitle = headerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headTitle:SetPoint("LEFT", headIcon, "RIGHT", 8, 0)
    headTitle:SetText("|cffffd100Hemet's Expedition Dispatches|r")

    local countText = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("RIGHT", -10, 0)
    headerBar.CountText = countText
    parent.HeaderBar = headerBar

    -- Scrollable Container for Full-Width Dispatch Rows
    local scrollFrame = CreateFrame("ScrollFrame", "ForeverSafariMailScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 6)

    local scrollChild = CreateFrame("Frame", "ForeverSafariMailScrollChild", scrollFrame)
    scrollChild:SetSize(280, 400)
    scrollFrame:SetScrollChild(scrollChild)
    parent.ScrollChild = scrollChild

    listButtons = {}
    local dispatches = C.NESINGWARY_DISPATCHES or {}

    for i, dispatch in ipairs(dispatches) do
        local btn = CreateFrame("Button", "ForeverSafariMailItem" .. i, scrollChild, "BackdropTemplate")
        btn:SetSize(280, 52)
        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((i - 1) * 56))
        btn.letterId = dispatch.id

        Theme:ApplyCardBackdrop(btn)

        -- Highlight Texture
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
        hl:SetVertexColor(1, 0.82, 0, 0.25)
        btn.Highlight = hl

        -- Icon (Left)
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

        -- Sender Name (Top Line)
        local sender = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sender:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
        sender:SetPoint("TOPRIGHT", -8, -2)
        sender:SetJustifyH("LEFT")
        sender:SetText("|cffffd100" .. (dispatch.sender or "Expedition") .. "|r")
        btn.Sender = sender

        -- Subject Title (Middle Line)
        local title = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", sender, "BOTTOMLEFT", 0, -2)
        title:SetPoint("TOPRIGHT", -8, -2)
        title:SetJustifyH("LEFT")
        title:SetText(dispatch.title or "Safari Dispatch")
        btn.Title = title

        -- Status Badge (Bottom Line / Right)
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
    scrollChild:SetWidth(parent:GetWidth() > 50 and (parent:GetWidth() - 30) or 280)
end

-- =========================================================================
-- ✉️ VIEW 2: SECONDARY WOW-STYLE OPEN MAIL WINDOW (Attached Sidecar)
-- =========================================================================
function Mail:BuildOpenMailFrame()
    openMailFrame = CreateFrame("Frame", "ForeverSafariOpenMailFrame", UIParent, "BackdropTemplate")
    openMailFrame:SetSize(340, 440)
    openMailFrame:SetFrameStrata("HIGH")
    openMailFrame:SetMovable(true)
    openMailFrame:EnableMouse(true)
    openMailFrame:RegisterForDrag("LeftButton")
    openMailFrame:SetClampedToScreen(true)

    -- Anchor sidecar directly to the right of MailFrame (Classic WoW OpenMail layout)
    openMailFrame:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", -32, 0)

    Theme:ApplyFrameBackdrop(openMailFrame, true)

    openMailFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    openMailFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Standard Close Button
    local closeBtn = CreateFrame("Button", nil, openMailFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        openMailFrame:Hide()
        Mail:UpdateUI()
    end)
    openMailFrame.CloseButton = closeBtn

    -- Decorative Crest / Wax Seal
    local seal = openMailFrame:CreateTexture(nil, "ARTWORK")
    seal:SetSize(30, 30)
    seal:SetPoint("TOPLEFT", 12, -10)
    seal:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
    seal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    openMailFrame.Seal = seal

    -- Window Title
    local winTitle = openMailFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    winTitle:SetPoint("TOPLEFT", seal, "TOPRIGHT", 8, 2)
    winTitle:SetText("|cffffd100Nesingwary Expedition Mail|r")

    local winSubtitle = openMailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    winSubtitle:SetPoint("TOPLEFT", winTitle, "BOTTOMLEFT", 0, -2)
    winSubtitle:SetText("Official Safari League Correspondence")
    winSubtitle:SetTextColor(0.7, 0.8, 0.9)

    -- Header Info Card (Sender & Subject)
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

    -- Letter Body Scroll Area (Antique Parchment Style)
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

    -- Bottom Attachment & Claim Tray (Styled like WoW OpenMail package box)
    local tray = Theme:CreateCard(openMailFrame, 316, 96)
    tray:SetPoint("BOTTOMLEFT", 12, 10)
    tray:SetPoint("BOTTOMRIGHT", -12, 10)
    tray:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.8)
    openMailFrame.Tray = tray

    -- Item / Parcel Slot Button (Left side of tray)
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

    -- Attachment / Directive Details
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

    -- Claim / Unbox Action Button
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

    -- Anchor smoothly to MailFrame
    if MailFrame and MailFrame:IsShown() then
        openMailFrame:ClearAllPoints()
        openMailFrame:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", -32, 0)
    end

    openMailFrame:Show()
    Mail:UpdateUI()
    PlaySound(844) -- SOUNDKIT.IG_SPELLBOOK_OPEN
end

function Mail:UpdateUI()
    if not mailContainer or not mailContainer:IsShown() then return end

    local dispatches = C.NESINGWARY_DISPATCHES or {}
    local currentDispatch = dispatches[selectedLetterId] or dispatches[1]

    -- Update Inbox Header
    if mailContainer.HeaderBar and mailContainer.HeaderBar.CountText then
        mailContainer.HeaderBar.CountText:SetText(string.format("|cffaaaaaaTotal Dispatches: %d|r", #dispatches))
    end

    -- Update Inbox Column Rows
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

    -- Update Secondary OpenMail Sidecar Window
    if openMailFrame and openMailFrame:IsShown() and currentDispatch then
        local headerCard = openMailFrame.HeaderCard
        headerCard.SenderText:SetText(string.format("|cffaaaaaaFrom:|r |cffffd100%s|r (|cff00ff99%s|r)", currentDispatch.sender or "Expedition HQ", currentDispatch.location or "Azeroth"))
        headerCard.SubjectText:SetText(string.format("|cffaaaaaaSubject:|r |cffffffff%s|r", currentDispatch.title or "Dispatch"))

        openMailFrame.BodyText:SetText(currentDispatch.body or "")
        openMailFrame.BodyContent:SetHeight(openMailFrame.BodyText:GetStringHeight() + 24)

        local tray = openMailFrame.Tray
        tray.ItemSlot.Icon:SetTexture(currentDispatch.icon or "Interface\\Icons\\INV_Box_01")

        -- Tooltip for attached rewards
        tray.ItemSlot:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if currentDispatch.isStarter then
                GameTooltip:AddLine("Safari League Starter Kit", 1, 0.82, 0)
                GameTooltip:AddLine("Enclosed Items:", 1, 1, 1)
                GameTooltip:AddLine("• Racial Level 1 Companion Crate", 0, 1, 0.6)
                GameTooltip:AddLine("• 10x Copper Safari Nets", 0, 1, 0.6)
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
    return mailContainer and mailContainer:IsShown()
end
