--[[
    Forever Safari: Nesingwary Mailbox Dispatch & Quest Hub
    Adds an authentic custom tab to the Blizzard MailFrame ("Safari Dispatch").
    Distributes official Nesingwary Junior Safari League correspondence, the first-load starter companion crate,
    and field research quest bounties.
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
local standaloneFrame = nil
local mailTabBtn = nil
local selectedLetterId = 1

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
end

function Mail:OnMailboxOpen()
    if not MailFrame then return end

    -- Create or attach custom Tab 3 to MailFrame
    if not mailTabBtn then
        local ok, btn = pcall(CreateFrame, "Button", "ForeverSafariMailTab", MailFrame, "PanelTabButtonTemplate")
        if not ok or not btn then
            btn = CreateFrame("Button", "ForeverSafariMailTab", MailFrame, "BackdropTemplate")
            Theme:ApplyButtonBackdrop(btn)
        end
        mailTabBtn = btn
        mailTabBtn:SetText("Safari Dispatch")
        if PanelTemplates_TabResize then
            pcall(PanelTemplates_TabResize, mailTabBtn, 0)
        end
        
        -- Anchor tab to MailFrameTab2
        if MailFrameTab2 then
            mailTabBtn:SetPoint("LEFT", MailFrameTab2, "RIGHT", -14, 0)
        elseif MailFrameTab1 then
            mailTabBtn:SetPoint("LEFT", MailFrameTab1, "RIGHT", -14, 0)
        else
            mailTabBtn:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 130, -30)
        end

        mailTabBtn:SetScript("OnClick", function()
            Mail:SelectSafariTab()
        end)

        -- Hook standard Blizzard tabs to hide our Safari Mail pane
        if MailFrameTab1 then
            MailFrameTab1:HookScript("OnClick", function()
                if mailContainer then mailContainer:Hide() end
                Mail:UpdateTabVisuals(1)
            end)
        end
        if MailFrameTab2 then
            MailFrameTab2:HookScript("OnClick", function()
                if mailContainer then mailContainer:Hide() end
                Mail:UpdateTabVisuals(2)
            end)
        end
    end

    -- Create inner Mail Container inside MailFrame
    if not mailContainer then
        mailContainer = CreateFrame("Frame", "ForeverSafariMailContainer", MailFrame, "BackdropTemplate")
        mailContainer:SetSize(338, 390)
        mailContainer:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 16, -65)
        mailContainer:SetFrameLevel(MailFrame:GetFrameLevel() + 5)
        mailContainer:Hide()

        Mail:BuildMailContent(mailContainer)
    end

    mailTabBtn:Show()
    Mail:UpdateTabBadge()

    -- Auto-select Safari Dispatch tab if starter kit is waiting to be unboxed!
    if not DB:IsStarterClaimed() then
        C_Timer.After(0.1, function()
            if MailFrame:IsShown() and not DB:IsStarterClaimed() then
                Mail:SelectSafariTab()
            end
        end)
    end
end

function Mail:OnMailboxClose()
    if mailContainer then
        mailContainer:Hide()
    end
end

function Mail:SelectSafariTab()
    if not MailFrame or not mailContainer then return end

    -- Hide Blizzard standard mail panes
    if InboxFrame then InboxFrame:Hide() end
    if SendMailFrame then SendMailFrame:Hide() end
    if OpenMailFrame then OpenMailFrame:Hide() end

    mailContainer:Show()
    Mail:UpdateTabVisuals(3)
    Mail:UpdateUI()
    PlaySound(844) -- SOUNDKIT.IG_SPELLBOOK_OPEN
end

function Mail:UpdateTabVisuals(selectedTab)
    if not mailTabBtn then return end
    if selectedTab == 3 then
        if PanelTemplates_SelectTab then
            pcall(PanelTemplates_SelectTab, mailTabBtn)
        end
        if MailFrameTab1 and PanelTemplates_DeselectTab then pcall(PanelTemplates_DeselectTab, MailFrameTab1) end
        if MailFrameTab2 and PanelTemplates_DeselectTab then pcall(PanelTemplates_DeselectTab, MailFrameTab2) end
    else
        if PanelTemplates_DeselectTab then
            pcall(PanelTemplates_DeselectTab, mailTabBtn)
        end
    end
end

function Mail:UpdateTabBadge()
    if not mailTabBtn then return end
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
        mailTabBtn:SetText("|cff00ff00* Safari Dispatch *|r")
    else
        mailTabBtn:SetText("Safari Dispatch")
    end
    if PanelTemplates_TabResize then
        pcall(PanelTemplates_TabResize, mailTabBtn, 0)
    end
end

function Mail:BuildMailContent(parent)
    -- Left Panel: Dispatches List
    local leftPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    leftPanel:SetSize(130, 380)
    leftPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    leftPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
    })
    leftPanel:SetBackdropColor(0.06, 0.08, 0.12, 0.9)
    leftPanel:SetBackdropBorderColor(0.3, 0.4, 0.5, 0.7)
    parent.LeftPanel = leftPanel

    local listTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listTitle:SetPoint("TOPLEFT", 8, -8)
    listTitle:SetText("|cffffd100Dispatches|r")

    parent.letterButtons = {}
    local dispatches = C.NESINGWARY_DISPATCHES or {}
    for i, dispatch in ipairs(dispatches) do
        local btn = CreateFrame("Button", nil, leftPanel, "BackdropTemplate")
        btn:SetSize(116, 64)
        btn:SetPoint("TOPLEFT", 7, -24 - ((i - 1) * 68))
        btn.letterId = dispatch.id

        Theme:ApplyCardBackdrop(btn)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("TOPLEFT", 6, -6)
        icon:SetTexture(dispatch.icon or "Interface\\Icons\\INV_Box_01")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.Icon = icon

        local title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        title:SetPoint("TOPLEFT", 34, -6)
        title:SetPoint("TOPRIGHT", -4, -6)
        title:SetJustifyH("LEFT")
        title:SetText(dispatch.title)
        btn.Title = title

        local statusText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("BOTTOMLEFT", 6, 6)
        statusText:SetText("|cffaaaaaaLetter|r")
        btn.StatusText = statusText

        btn:SetScript("OnClick", function(self)
            selectedLetterId = self.letterId
            DB:MarkLetterRead(self.letterId)
            Mail:UpdateUI()
            PlaySound(844)
        end)

        parent.letterButtons[i] = btn
    end

    -- Right Panel: Antique Parchment Reader & Reward Tray
    local rightPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rightPanel:SetSize(202, 380)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 6, 0)
    rightPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    rightPanel:SetBackdropColor(0.08, 0.09, 0.12, 0.95)
    rightPanel:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.8)
    parent.RightPanel = rightPanel

    -- Wax Seal Crest
    local seal = rightPanel:CreateTexture(nil, "ARTWORK")
    seal:SetSize(36, 36)
    seal:SetPoint("TOPRIGHT", -10, -10)
    seal:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
    seal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    rightPanel.Seal = seal

    -- Letter Header
    local docTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    docTitle:SetPoint("TOPLEFT", 10, -10)
    docTitle:SetPoint("TOPRIGHT", -50, -10)
    docTitle:SetJustifyH("LEFT")
    rightPanel.DocTitle = docTitle

    local senderText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    senderText:SetPoint("TOPLEFT", docTitle, "BOTTOMLEFT", 0, -4)
    rightPanel.SenderText = senderText

    -- Parchment Body Text (Scrollable)
    local bodyScroll = CreateFrame("ScrollFrame", nil, rightPanel, "UIPanelScrollFrameTemplate")
    bodyScroll:SetPoint("TOPLEFT", 10, -56)
    bodyScroll:SetPoint("BOTTOMRIGHT", -26, 110)

    local bodyContent = CreateFrame("Frame", nil, bodyScroll)
    bodyContent:SetSize(166, 300)
    bodyScroll:SetScrollChild(bodyContent)

    local bodyText = bodyContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bodyText:SetPoint("TOPLEFT", 0, 0)
    bodyText:SetPoint("TOPRIGHT", 0, 0)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetTextColor(0.9, 0.9, 0.9)
    rightPanel.BodyText = bodyText
    rightPanel.BodyContent = bodyContent

    -- Bottom Tray: Attachment / Quest Objective & Action Button
    local tray = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    tray:SetSize(190, 96)
    tray:SetPoint("BOTTOMLEFT", 6, 6)
    Theme:ApplyCardBackdrop(tray)
    rightPanel.Tray = tray

    local trayTitle = tray:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    trayTitle:SetPoint("TOPLEFT", 8, -6)
    trayTitle:SetText("Parcel Attachment / Objective:")
    tray.Title = trayTitle

    local progressText = tray:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("TOPLEFT", 8, -22)
    progressText:SetText("Progress: 0/3")
    tray.ProgressText = progressText

    local actionBtn = Theme:CreateButton(tray, "CLAIM", 174, 28, true)
    actionBtn:SetPoint("BOTTOM", 0, 8)
    tray.ActionBtn = actionBtn
end

local function UpdateFramePanel(parent)
    if not parent or not parent:IsShown() then return end

    local dispatches = C.NESINGWARY_DISPATCHES or {}
    local currentDispatch = dispatches[selectedLetterId] or dispatches[1]

    -- Update Left List
    if parent.letterButtons then
        for i, btn in ipairs(parent.letterButtons) do
            local dispatch = dispatches[i]
            if dispatch then
                local isRead = DB:IsLetterRead(dispatch.id)
                if dispatch.isStarter then
                    if DB:IsStarterClaimed() then
                        btn.StatusText:SetText("|cff00ff00[Archived]|r")
                    else
                        btn.StatusText:SetText("|cffffd100[UNOPENED]|r")
                    end
                else
                    local progress = DB:GetQuestProgress(dispatch.questType)
                    if DB:IsQuestClaimed(dispatch.id) then
                        btn.StatusText:SetText("|cff00ff00[Archived]|r")
                    elseif dispatch.targetCount and progress >= dispatch.targetCount then
                        btn.StatusText:SetText("|cff00ff99[Ready!]|r")
                    elseif not isRead then
                        btn.StatusText:SetText("|cffffd100[NEW]|r")
                    else
                        btn.StatusText:SetText(string.format("|cffffcc00%d/%d (Read)|r", progress, dispatch.targetCount or 1))
                    end
                end

                if dispatch.id == selectedLetterId then
                    btn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                else
                    btn:SetBackdropBorderColor(0.3, 0.4, 0.5, 0.6)
                end
            end
        end
    end

    -- Update Right Parchment Reader
    local right = parent.RightPanel
    if not right or not currentDispatch then return end

    right.DocTitle:SetText("|cffffd100" .. currentDispatch.title .. "|r")
    right.SenderText:SetText(string.format("|cffaaaaaaFrom: %s (%s)|r", currentDispatch.sender, currentDispatch.location or "Expedition"))
    right.BodyText:SetText(currentDispatch.body or "")
    right.BodyContent:SetHeight(right.BodyText:GetStringHeight() + 20)

    -- Update Tray & Actions
    local tray = right.Tray
    if currentDispatch.isStarter then
        tray.Title:SetText("|cffffd100Starter Parcel Attachment:|r")
        if DB:IsStarterClaimed() then
            tray.ProgressText:SetText("|cff00ff00Starter companion & nets unboxed!|r")
            tray.ActionBtn:Disable()
            tray.ActionBtn:SetText("CRATE UNBOXED")
        else
            tray.ProgressText:SetText("|cffffff00Contains racial companion & 5 Nets|r")
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

        tray.Title:SetText(string.format("|cffffd100Objective: %s|r", currentDispatch.summary or "Field Directive"))
        
        if isClaimed then
            tray.ProgressText:SetText("|cff00ff00Rewards claimed! Bounty completed.|r")
            tray.ActionBtn:Disable()
            tray.ActionBtn:SetText("BOUNTY CLAIMED")
        elseif progress >= target then
            tray.ProgressText:SetText(string.format("|cff00ff00Progress: %d / %d (Complete!)|r", progress, target))
            tray.ActionBtn:Enable()
            tray.ActionBtn:SetText("🎁 CLAIM REWARDS")
            tray.ActionBtn:SetScript("OnClick", function()
                DB:ClaimQuestReward(currentDispatch.id)
                Mail:UpdateUI()
                Mail:UpdateTabBadge()
            end)
        else
            tray.ProgressText:SetText(string.format("|cffff4444Progress: %d / %d (Incomplete)|r", progress, target))
            tray.ActionBtn:Disable()
            tray.ActionBtn:SetText("INCOMPLETE")
        end
    end
end

function Mail:UpdateUI()
    if mailContainer and mailContainer:IsShown() then
        UpdateFramePanel(mailContainer)
    end
    if standaloneFrame and standaloneFrame:IsShown() then
        UpdateFramePanel(standaloneFrame)
    end
end

function Mail:IsShown()
    return (mailContainer and mailContainer:IsShown()) or (standaloneFrame and standaloneFrame:IsShown())
end

-- Standalone Field Dispatch Reader (Accessible via /safari mail, /fsmail, or Field Guide)
function Mail:ShowStandalone()
    if not standaloneFrame then
        standaloneFrame = CreateFrame("Frame", "ForeverSafariStandaloneMailFrame", UIParent, "BackdropTemplate")
        standaloneFrame:SetSize(360, 440)
        standaloneFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        standaloneFrame:SetMovable(true)
        standaloneFrame:EnableMouse(true)
        standaloneFrame:RegisterForDrag("LeftButton")
        standaloneFrame:SetClampedToScreen(true)
        standaloneFrame:SetFrameStrata("HIGH")

        Theme:ApplyFrameBackdrop(standaloneFrame, true)
        standaloneFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        standaloneFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

        local closeBtn = CreateFrame("Button", nil, standaloneFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -2, -2)
        closeBtn:SetScript("OnClick", function() standaloneFrame:Hide() end)

        local title = standaloneFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 12, -10)
        title:SetText("|cffffd100Nesingwary Field Correspondence|r")

        local sub = standaloneFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sub:SetPoint("TOPLEFT", 12, -28)
        sub:SetText("Official Safari League dispatches & active bounties.")
        sub:SetTextColor(0.7, 0.8, 0.9)

        local innerContent = CreateFrame("Frame", nil, standaloneFrame)
        innerContent:SetSize(338, 380)
        innerContent:SetPoint("TOPLEFT", 10, -48)
        standaloneFrame.Inner = innerContent

        Mail:BuildMailContent(innerContent)
        standaloneFrame.letterButtons = innerContent.letterButtons
        standaloneFrame.RightPanel = innerContent.RightPanel
    end

    standaloneFrame:Show()
    Mail:UpdateUI()
    PlaySound(844)
end

function Mail:ToggleStandalone()
    if standaloneFrame and standaloneFrame:IsShown() then
        standaloneFrame:Hide()
    else
        Mail:ShowStandalone()
    end
end
