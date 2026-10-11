--[[
    Forever Safari: View 4 - Field Directives & Bounties (JournalBountiesView.lua)
    Nesingwary research quest log, objective tracking, mailbox parcel unboxing instructions,
    and reward collection interface.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.JournalFrame = ns.JournalFrame or {}

local Journal = ns.JournalFrame
local Theme = ns.Theme
local DB = ns.Database
local C = ns.Constants
local BountyDB = ns.BountyDB

local selectedBountyId = 1
local bountyButtons = {}

function Journal:BuildBountiesView(parent)
    -- Left Column: Directives List
    local leftPanel = Theme:CreateCard(parent, 250, 480)
    leftPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    parent.LeftPanel = leftPanel

    local listTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    listTitle:SetPoint("TOPLEFT", 12, -10)
    listTitle:SetText("|cffffd100Field Directives|r")

    local listSub = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listSub:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -2)
    listSub:SetText("Nesingwary Research Quests")
    listSub:SetTextColor(0.7, 0.75, 0.8)

    local scrollFrame = CreateFrame("ScrollFrame", "ForeverSafariBountiesScrollFrame", leftPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 6, -38)
    scrollFrame:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -26, 8)

    local listContent = CreateFrame("Frame", "ForeverSafariBountiesListContent", scrollFrame)
    listContent:SetSize(210, 440)
    scrollFrame:SetScrollChild(listContent)
    parent.ListContent = listContent

    local dispatches = ns.BountyDB and ns.BountyDB:GetAllDispatches() or {}
    for i, dispatch in ipairs(dispatches) do
        local btn = CreateFrame("Button", nil, listContent, "BackdropTemplate")
        btn:SetSize(210, 68)
        btn:SetPoint("TOPLEFT", 4, -((i - 1) * 74))
        btn.bountyId = dispatch.id

        Theme:ApplyCardBackdrop(btn)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("LEFT", 8, 0)
        icon:SetTexture(dispatch.icon or "Interface\\Icons\\INV_Box_01")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.Icon = icon

        local title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -4)
        title:SetPoint("RIGHT", -6, 0)
        title:SetJustifyH("LEFT")
        title:SetText(dispatch.title)
        btn.Title = title

        local status = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        status:SetPoint("RIGHT", -6, 0)
        status:SetJustifyH("LEFT")
        status:SetText("|cffaaaaaaIn Progress|r")
        btn.Status = status

        btn:SetScript("OnClick", function(self)
            selectedBountyId = self.bountyId
            Journal:UpdateBountiesView()
            PlaySound(856)
        end)

        bountyButtons[i] = btn
    end

    -- Right Column: Directive Dossier, Progress & Mailbox Instructions
    local rightPanel = Theme:CreateCard(parent, 556, 480)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 6, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    parent.RightPanel = rightPanel

    local crest = rightPanel:CreateTexture(nil, "ARTWORK")
    crest:SetSize(36, 36)
    crest:SetPoint("TOPRIGHT", -12, -10)
    crest:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
    crest:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    rightPanel.Crest = crest

    local docTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    docTitle:SetPoint("TOPLEFT", 14, -10)
    docTitle:SetPoint("TOPRIGHT", crest, "TOPLEFT", -10, 0)
    docTitle:SetJustifyH("LEFT")
    rightPanel.DocTitle = docTitle

    local senderText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    senderText:SetPoint("TOPLEFT", docTitle, "BOTTOMLEFT", 0, -4)
    rightPanel.SenderText = senderText

    -- Lore & Directive Description Scroll
    local descScroll = CreateFrame("ScrollFrame", nil, rightPanel, "UIPanelScrollFrameTemplate")
    descScroll:SetPoint("TOPLEFT", 14, -58)
    descScroll:SetPoint("BOTTOMRIGHT", -28, 200)

    local descContent = CreateFrame("Frame", nil, descScroll)
    descContent:SetSize(500, 200)
    descScroll:SetScrollChild(descContent)

    local bodyText = descContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bodyText:SetPoint("TOPLEFT", 0, 0)
    bodyText:SetPoint("TOPRIGHT", 0, 0)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetTextColor(0.88, 0.90, 0.92)
    rightPanel.BodyText = bodyText
    rightPanel.DescContent = descContent

    -- Objectives & Progress Card
    local objCard = Theme:CreateCard(rightPanel, 528, 108)
    objCard:SetPoint("BOTTOMLEFT", 14, 82)
    objCard:SetPoint("BOTTOMRIGHT", -14, 82)
    rightPanel.ObjCard = objCard

    local objHeader = objCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    objHeader:SetPoint("TOPLEFT", 10, -8)
    objHeader:SetText("|cffffd100Directive Objective:|r")
    objCard.Header = objHeader

    local objSummary = objCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    objSummary:SetPoint("TOPLEFT", objHeader, "BOTTOMLEFT", 0, -4)
    objSummary:SetPoint("RIGHT", -10, 0)
    objSummary:SetJustifyH("LEFT")
    objCard.Summary = objSummary

    local pBar = CreateFrame("StatusBar", nil, objCard)
    pBar:SetSize(320, 16)
    pBar:SetPoint("TOPLEFT", objSummary, "BOTTOMLEFT", 0, -6)
    pBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    pBar:SetStatusBarColor(0.0, 0.8, 0.4)
    objCard.ProgressBar = pBar

    local pBarBg = pBar:CreateTexture(nil, "BACKGROUND")
    pBarBg:SetAllPoints(pBar)
    pBarBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    pBarBg:SetVertexColor(0.1, 0.15, 0.2, 0.8)

    local pBarText = pBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pBarText:SetPoint("CENTER", 0, 0)
    objCard.ProgressText = pBarText

    local rewardText = objCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rewardText:SetPoint("TOPLEFT", pBar, "BOTTOMLEFT", 0, -6)
    rewardText:SetPoint("RIGHT", -10, 0)
    rewardText:SetJustifyH("LEFT")
    objCard.RewardText = rewardText

    -- Physical Town Mailbox Notice Box
    local noticeBox = Theme:CreateCard(rightPanel, 528, 64)
    noticeBox:SetPoint("BOTTOMLEFT", 14, 10)
    noticeBox:SetPoint("BOTTOMRIGHT", -14, 10)
    noticeBox:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.8)

    local noticeIcon = noticeBox:CreateTexture(nil, "ARTWORK")
    noticeIcon:SetSize(28, 28)
    noticeIcon:SetPoint("LEFT", 10, 0)
    noticeIcon:SetTexture("Interface\\Icons\\INV_Letter_15")
    noticeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local noticeTitle = noticeBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noticeTitle:SetPoint("TOPLEFT", noticeIcon, "TOPRIGHT", 8, 2)
    noticeTitle:SetText("|cffffd100📬 Physical Town Mailbox Required For Rewards & Letters|r")

    local noticeDesc = noticeBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noticeDesc:SetPoint("TOPLEFT", noticeTitle, "BOTTOMLEFT", 0, -2)
    noticeDesc:SetPoint("RIGHT", -10, 0)
    noticeDesc:SetJustifyH("LEFT")
    noticeDesc:SetText("|cffaaaaaaCompleted bounties and newly delivered dispatches are unboxed at an authentic Mailbox in town. Visit any town inn to collect your rewards!|r")
end

function Journal:UpdateBountiesView()
    local dispatches = ns.BountyDB and ns.BountyDB:GetAllDispatches() or {}
    local currentDispatch = dispatches[selectedBountyId] or dispatches[1]

    -- Update List Cards
    for i, btn in ipairs(bountyButtons) do
        local dispatch = dispatches[i]
        if dispatch then
            local isClaimed = DB:IsQuestClaimed(dispatch.id)
            local progress = DB:GetQuestProgress(dispatch.questType)
            local target = dispatch.targetCount or 1

            if dispatch.isStarter then
                if DB:IsStarterClaimed() then
                    btn.Status:SetText("|cff00ff00[Commission Active]|r")
                else
                    btn.Status:SetText("|cffffd100[Mailbox Parcel Waiting]|r")
                end
            else
                if isClaimed then
                    btn.Status:SetText("|cffaaaaaa[Bounty Completed]|r")
                elseif progress >= target then
                    btn.Status:SetText("|cff00ff99[✔ Ready for Mailbox Turn-In]|r")
                else
                    btn.Status:SetText(string.format("|cffffcc00[Progress: %d / %d]|r", progress, target))
                end
            end

            if dispatch.id == selectedBountyId then
                btn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                btn:SetBackdropColor(0.12, 0.18, 0.24, 0.95)
            else
                btn:SetBackdropBorderColor(0.2, 0.3, 0.4, 0.6)
                btn:SetBackdropColor(0.08, 0.10, 0.14, 0.8)
            end
        end
    end

    -- Update Dossier Content
    local right = self.BountiesContainer and self.BountiesContainer.RightPanel
    if not right or not currentDispatch then return end

    right.DocTitle:SetText(currentDispatch.title)
    right.SenderText:SetText(string.format("|cffaaaaaaFrom: %s (%s)|r", currentDispatch.sender, currentDispatch.location or "Expedition HQ"))
    right.BodyText:SetText(currentDispatch.body or "")
    if right.DescContent then
        right.DescContent:SetHeight(right.BodyText:GetStringHeight() + 20)
    end

    local objCard = right.ObjCard
    objCard.Summary:SetText(currentDispatch.summary or "Field Research Task")

    if currentDispatch.isStarter then
        objCard.ProgressBar:SetMinMaxValues(0, 1)
        if DB:IsStarterClaimed() then
            objCard.ProgressBar:SetValue(1)
            objCard.ProgressBar:SetStatusBarColor(0.0, 0.8, 0.4)
            objCard.ProgressText:SetText("Commission Active — Starter Companion Unboxed")
            objCard.RewardText:SetText("|cff00ff00Starter crate collected from town mailbox.|r")
        else
            objCard.ProgressBar:SetValue(0)
            objCard.ProgressBar:SetStatusBarColor(1.0, 0.6, 0.0)
            objCard.ProgressText:SetText("0 / 1 — Parcel Waiting at Town Mailbox")
            objCard.RewardText:SetText("|cffffd100Rewards Waiting:|r Racial Starter Companion + 10x Copper Snares")
        end
    else
        local progress = DB:GetQuestProgress(currentDispatch.questType)
        local target = currentDispatch.targetCount or 1
        local isClaimed = DB:IsQuestClaimed(currentDispatch.id)

        objCard.ProgressBar:SetMinMaxValues(0, target)
        objCard.ProgressBar:SetValue(math.min(progress, target))

        if isClaimed then
            objCard.ProgressBar:SetStatusBarColor(0.5, 0.5, 0.5)
            objCard.ProgressText:SetText(string.format("%d / %d (Bounty Completed & Claimed)", target, target))
            objCard.RewardText:SetText("|cffaaaaaaRewards already collected from town mailbox.|r")
        elseif progress >= target then
            objCard.ProgressBar:SetStatusBarColor(0.0, 1.0, 0.4)
            objCard.ProgressText:SetText(string.format("|cff00ff00%d / %d (Objective Complete! Ready to Turn In)|r", progress, target))
            objCard.RewardText:SetText(string.format("|cff00ff00Turn-In Reward:|r +%d Safari Tokens, Supplies (Claim at Mailbox)", currentDispatch.rewards and currentDispatch.rewards.tokens or 0))
        else
            objCard.ProgressBar:SetStatusBarColor(0.0, 0.7, 1.0)
            objCard.ProgressText:SetText(string.format("%d / %d (%d%%)", progress, target, math.floor((progress / target) * 100)))
            objCard.RewardText:SetText(string.format("|cffffd100Bounty Rewards:|r +%d Safari Tokens, Nets & Treats (Claim at Mailbox)", currentDispatch.rewards and currentDispatch.rewards.tokens or 0))
        end
    end
end
