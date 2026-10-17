--[[
    Forever Safari: View 5 - Badges & Credentials Showcase (JournalBadgesView.lua)
    Displays the 4 official Nesingwary Research Licenses and all 54 Regional Outpost
    Badges won by challenging Stable Master Outpost Leaders across Azeroth.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.JournalFrame = ns.JournalFrame or {}

local Journal = ns.JournalFrame
local Theme = ns.Theme
local DB = ns.Database
local C = ns.Constants
local OutpostDB = ns.OutpostDB

local licenseCards = {}
local badgeCards = {}
local sortedOutposts = {}

local LICENSES_METADATA = {
    {
        type = "Mechanical",
        name = "Clockwork Engineering",
        icon = "Interface\\Icons\\INV_Gizmo_02",
        source = "Deadmines (Sneed's Shredder / Foe Reaper)",
        specimen = "Grinded Gears",
        desc = "Authorizes field research, stalking, and containment of mechanical fauna and clockwork constructs.",
    },
    {
        type = "Elemental",
        name = "Primal Attunement",
        icon = "Interface\\Icons\\Spell_Fire_Elemental_Devastation",
        source = "BFD (Baron Aquanis) / Gnomeregan (Viscous Fallout)",
        specimen = "Puddle of Mud",
        desc = "Authorizes field research, containment, and bonding with primal elemental spirits and Saurians.",
    },
    {
        type = "Undead",
        name = "Necrotic Containment",
        icon = "Interface\\Icons\\Spell_Shadow_DeadofNight",
        source = "Razorfen Downs (Amnennar the Coldbringer)",
        specimen = "Cold Bones",
        desc = "Authorizes safe containment, purification, and training of reanimated beasts and undead fauna.",
    },
    {
        type = "Dragonkin",
        name = "Draconic Sanctuary",
        icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        source = "Sunken Temple (Shade of Eranikus / Morphaz)",
        specimen = "Poisonous Scales",
        desc = "Authorizes tracking, research, and capture of dragonkin whelps, drakes, and fey dragons.",
    },
}

function Journal:BuildBadgesView(parent)
    local masterCard = Theme:CreateCard(parent, 816, 492)
    masterCard:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    masterCard:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    parent.MasterCard = masterCard

    -- =========================================================================
    -- 1. TOP SHELF: THE 4 RESEARCH LICENSES
    -- =========================================================================
    local licHeader = masterCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    licHeader:SetPoint("TOPLEFT", 14, -10)
    licHeader:SetText("|cffffd100Official Nesingwary Research Licenses|r")

    local licSub = masterCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    licSub:SetPoint("TOPLEFT", licHeader, "BOTTOMLEFT", 0, -2)
    licSub:SetText("Authorizes field observation and capture of specialized non-beast creature types.")
    licSub:SetTextColor(0.7, 0.75, 0.8)

    local cardWidth = 192
    local cardHeight = 62
    local cardSpacing = 6

    licenseCards = {}
    for i, licData in ipairs(LICENSES_METADATA) do
        local card = CreateFrame("Button", nil, masterCard, "BackdropTemplate")
        card:SetSize(cardWidth, cardHeight)
        card:SetPoint("TOPLEFT", masterCard, "TOPLEFT", 12 + (i - 1) * (cardWidth + cardSpacing), -42)
        Theme:ApplyCardBackdrop(card)

        local icon = card:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", 8, 0)
        icon:SetTexture(licData.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        card.Icon = icon

        local iconBorder = card:CreateTexture(nil, "OVERLAY")
        iconBorder:SetSize(40, 40)
        iconBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
        iconBorder:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
        iconBorder:SetVertexColor(0.8, 0.7, 0.3, 0.8)
        card.IconBorder = iconBorder

        local name = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -6)
        name:SetPoint("RIGHT", -6, 0)
        name:SetJustifyH("LEFT")
        name:SetText(licData.name)
        card.Name = name

        local status = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        status:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
        status:SetPoint("RIGHT", -6, 0)
        status:SetJustifyH("LEFT")
        card.Status = status

        card.licData = licData

        card:SetScript("OnEnter", function(self)
            local data = self.licData
            local unlocked = DB and DB:IsTypeUnlocked(data.type)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(data.name .. " Permit", 1, 0.82, 0)
            GameTooltip:AddLine(data.desc, 0.85, 0.85, 0.85, true)
            GameTooltip:AddLine(" ")
            if unlocked then
                GameTooltip:AddDoubleLine("Status:", "|cff00ff00✔ CERTIFIED & ACTIVE|r")
                GameTooltip:AddLine("Certified by Hemet Nesingwary Sr. Authorized across all Azeroth.", 0.6, 1, 0.6, true)
            else
                GameTooltip:AddDoubleLine("Status:", "|cffaaaaaa🔒 LOCKED (Specimen Required)|r")
                GameTooltip:AddLine("How to Unlock:", 1, 0.82, 0)
                GameTooltip:AddLine("1. Slay boss in " .. data.source .. " to recover [" .. data.specimen .. "].", 0.9, 0.9, 0.9, true)
                GameTooltip:AddLine("2. Dispatch specimen to Hemet Nesingwary at any town mailbox.", 0.9, 0.9, 0.9, true)
            end
            GameTooltip:Show()
            self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        end)

        card:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            local unlocked = DB and DB:IsTypeUnlocked(self.licData.type)
            if unlocked then
                self:SetBackdropBorderColor(0.0, 0.8, 0.4, 0.8)
            else
                self:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
            end
        end)

        licenseCards[i] = card
    end

    -- =========================================================================
    -- 2. MAIN CABINET: THE 54 REGIONAL OUTPOST BADGES
    -- =========================================================================
    local div = masterCard:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", masterCard, "TOPLEFT", 12, -114)
    div:SetPoint("TOPRIGHT", masterCard, "TOPRIGHT", -12, -114)
    div:SetColorTexture(0.25, 0.32, 0.42, 0.6)

    local badgeHeader = masterCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    badgeHeader:SetPoint("TOPLEFT", div, "BOTTOMLEFT", 2, -8)
    badgeHeader:SetText("|cffffd100Regional Circuit Badges|r")

    local badgeCountText = masterCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badgeCountText:SetPoint("TOPRIGHT", div, "BOTTOMRIGHT", -4, -8)
    badgeCountText:SetText("|cffffd100Badges Earned:|r |cff00ff000 / 54 (0%)|r")
    masterCard.BadgeCountText = badgeCountText

    local badgeSub = masterCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badgeSub:SetPoint("TOPLEFT", badgeHeader, "BOTTOMLEFT", 0, -2)
    badgeSub:SetText("Won by defeating Stable Master Outpost Leaders across the zones of Kalimdor and the Eastern Kingdoms.")
    badgeSub:SetTextColor(0.7, 0.75, 0.8)

    local scrollFrame = CreateFrame("ScrollFrame", "ForeverSafariBadgesScrollFrame", masterCard, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", badgeSub, "BOTTOMLEFT", 0, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", masterCard, "BOTTOMRIGHT", -26, 8)

    local scrollChild = CreateFrame("Frame", "ForeverSafariBadgesScrollChild", scrollFrame)
    scrollChild:SetSize(760, 800)
    scrollFrame:SetScrollChild(scrollChild)
    masterCard.ScrollChild = scrollChild

    -- Prepare sorted list of outposts by Tier then Zone
    sortedOutposts = {}
    if OutpostDB and OutpostDB.OUTPOSTS then
        for _, outpost in pairs(OutpostDB.OUTPOSTS) do
            if outpost.badge and outpost.badge.id then
                table.insert(sortedOutposts, outpost)
            end
        end
        table.sort(sortedOutposts, function(a, b)
            local tierA = a.tier or 1
            local tierB = b.tier or 1
            if tierA ~= tierB then return tierA < tierB end
            return (a.zone or "") < (b.zone or "")
        end)
    end

    badgeCards = {}
    local bCols = 4
    local bWidth = 184
    local bHeight = 52
    local bPadX = 6
    local bPadY = 6

    for i, outpost in ipairs(sortedOutposts) do
        local col = (i - 1) % bCols
        local row = math.floor((i - 1) / bCols)

        local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        btn:SetSize(bWidth, bHeight)
        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", col * (bWidth + bPadX), -(row * (bHeight + bPadY)))
        Theme:ApplyCardBackdrop(btn)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("LEFT", 6, 0)
        icon:SetTexture(outpost.badge.icon or "Interface\\Icons\\INV_Misc_Horn_02")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.Icon = icon

        local bBorder = btn:CreateTexture(nil, "OVERLAY")
        bBorder:SetSize(36, 36)
        bBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
        bBorder:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
        btn.Border = bBorder

        local bName = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bName:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -3)
        bName:SetPoint("RIGHT", -4, 0)
        bName:SetJustifyH("LEFT")
        bName:SetText(outpost.badge.name or "Outpost Badge")
        btn.Name = bName

        local bZone = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bZone:SetPoint("TOPLEFT", bName, "BOTTOMLEFT", 0, -2)
        bZone:SetPoint("RIGHT", -4, 0)
        bZone:SetJustifyH("LEFT")
        bZone:SetText(outpost.zone or "Azeroth")
        bZone:SetTextColor(0.65, 0.7, 0.75)
        btn.Zone = bZone

        local bStatus = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bStatus:SetPoint("TOPLEFT", bZone, "BOTTOMLEFT", 0, -2)
        bStatus:SetPoint("RIGHT", -4, 0)
        bStatus:SetJustifyH("LEFT")
        btn.Status = bStatus

        btn.outpost = outpost

        btn:SetScript("OnEnter", function(self)
            local op = self.outpost
            local b = op and op.badge
            local isEarned, earnedData = false, nil
            if ForeverSafariDB and ForeverSafariDB.badges and b and b.id then
                earnedData = ForeverSafariDB.badges[b.id]
                isEarned = (earnedData ~= nil)
            end

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if isEarned then
                GameTooltip:AddLine(b.name, 1, 0.82, 0)
                GameTooltip:AddLine(b.desc or "Official Outpost Badge", 0.85, 0.85, 0.85, true)
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Status:", "|cff00ff00✔ Conquered|r")
                GameTooltip:AddDoubleLine("Outpost Guide:", op.name .. " (" .. (op.location or op.zone) .. ")", 1, 1, 1, 0.8, 0.9, 1)
                GameTooltip:AddDoubleLine("Circuit Tier:", string.format("Tier %d (Rank %s)", op.tier or 1, op.rankRoman or "I"), 1, 1, 1, 1, 0.82, 0)
                if op.defeatQuote then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(string.format("\"%s\"", op.defeatQuote), 0.2, 1, 0.6, true)
                end
            else
                GameTooltip:AddLine(b.name, 0.7, 0.7, 0.7)
                GameTooltip:AddLine(b.desc or "Regional Outpost Badge", 0.6, 0.6, 0.6, true)
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Status:", "|cffaaaaaaUnchallenged|r")
                GameTooltip:AddDoubleLine("Outpost Guide:", op.name, 1, 1, 1, 0.9, 0.9, 0.9)
                GameTooltip:AddDoubleLine("Location:", (op.location or "") .. ", " .. (op.zone or "Azeroth"), 1, 1, 1, 0.8, 0.9, 1)
                GameTooltip:AddDoubleLine("Circuit Tier:", string.format("Tier %d (Rank %s)", op.tier or 1, op.rankRoman or "I"), 1, 1, 1, 1, 0.82, 0)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Target this Stable Master in the field and challenge them to earn this badge!", 1, 0.82, 0, true)
            end
            GameTooltip:Show()
            self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        end)

        btn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            local b = self.outpost and self.outpost.badge
            local isEarned = ForeverSafariDB and ForeverSafariDB.badges and b and b.id and ForeverSafariDB.badges[b.id]
            if isEarned then
                self:SetBackdropBorderColor(0.0, 0.8, 0.4, 0.8)
            else
                self:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
            end
        end)

        badgeCards[i] = btn
    end

    local totalRows = math.ceil(#sortedOutposts / bCols)
    scrollChild:SetHeight(math.max(1, totalRows * (bHeight + bPadY) + 20))
end

function Journal:UpdateBadgesView()
    local master = self.BadgesContainer and self.BadgesContainer.MasterCard
    if not master then return end

    -- 1. Refresh the 4 Licenses
    for _, card in ipairs(licenseCards) do
        local data = card.licData
        local unlocked = DB and DB:IsTypeUnlocked(data.type)

        if unlocked then
            card.Icon:SetDesaturated(false)
            card.Icon:SetAlpha(1.0)
            card.IconBorder:SetVertexColor(0.0, 1.0, 0.5, 1.0)
            card.Name:SetTextColor(1, 0.82, 0)
            card.Status:SetText("|cff00ff00✔ CERTIFIED|r")
            card:SetBackdropBorderColor(0.0, 0.8, 0.4, 0.8)
            card:SetBackdropColor(0.08, 0.16, 0.12, 0.9)
        else
            card.Icon:SetDesaturated(true)
            card.Icon:SetAlpha(0.4)
            card.IconBorder:SetVertexColor(0.4, 0.4, 0.4, 0.6)
            card.Name:SetTextColor(0.6, 0.6, 0.6)
            card.Status:SetText("|cff888888🔒 LOCKED|r")
            card:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
            card:SetBackdropColor(0.08, 0.10, 0.14, 0.85)
        end
    end

    -- 2. Refresh the 54 Regional Badges
    local earnedCount = 0
    local totalBadges = #sortedOutposts

    for _, btn in ipairs(badgeCards) do
        local op = btn.outpost
        local b = op and op.badge
        local isEarned = false

        if ForeverSafariDB and ForeverSafariDB.badges and b and b.id and ForeverSafariDB.badges[b.id] then
            isEarned = true
            earnedCount = earnedCount + 1
        end

        if isEarned then
            btn.Icon:SetDesaturated(false)
            btn.Icon:SetAlpha(1.0)
            btn.Border:SetVertexColor(1.0, 0.82, 0.0, 1.0)
            btn.Name:SetTextColor(1, 0.85, 0.2)
            btn.Status:SetText("|cff00ff00✔ Claimed|r")
            btn:SetBackdropBorderColor(0.0, 0.8, 0.4, 0.8)
            btn:SetBackdropColor(0.08, 0.14, 0.12, 0.9)
        else
            btn.Icon:SetDesaturated(true)
            btn.Icon:SetAlpha(0.35)
            btn.Border:SetVertexColor(0.3, 0.35, 0.4, 0.6)
            btn.Name:SetTextColor(0.55, 0.55, 0.55)
            btn.Status:SetText("|cff666666Unchallenged|r")
            btn:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.7)
            btn:SetBackdropColor(0.07, 0.08, 0.11, 0.85)
        end
    end

    if master.BadgeCountText then
        local pct = totalBadges > 0 and math.floor((earnedCount / totalBadges) * 100) or 0
        master.BadgeCountText:SetText(string.format("|cffffd100Badges Earned:|r |cff00ff00%d / %d (%d%%)|r", earnedCount, totalBadges, pct))
    end
end
