--[[
    Forever Safari: Nesingwary Dispatch Parchment Onboarding Modal
    Delivers the official first-login welcome letter from Hemet Nesingwary Sr.
    and the starter companion crate unboxing sequence.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.DispatchFrame = ns.DispatchFrame or {}

local Dispatch = ns.DispatchFrame
local C = ns.Constants
local DB = ns.Database

local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then
        return true
    end
    return false
end

local frame = nil

function Dispatch:Initialize()
    if frame then return end

    frame = CreateFrame("Frame", "ForeverSafariDispatchFrame", UIParent, "BackdropTemplate")
    frame:SetSize(480, 560)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()

    -- Antique Parchment Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\QuestFrame\\QuestBG",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = false, tileSize = 0, edgeSize = 32,
        insets = { left = 10, right = 10, top = 10, bottom = 10 }
    })

    -- Nesingwary Golden Seal Ribbon
    local seal = frame:CreateTexture(nil, "ARTWORK")
    seal:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
    seal:SetSize(48, 48)
    seal:SetPoint("TOP", frame, "TOP", 0, -20)

    -- Dispatch Title
    local title = frame:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    title:SetPoint("TOP", seal, "BOTTOM", 0, -10)
    title:SetText("EXPEDITIONARY DISPATCH")
    title:SetTextColor(0.35, 0.20, 0.05, 1)

    local subTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subTitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
    subTitle:SetText("— Nesingwary Junior Safari League —")
    subTitle:SetTextColor(0.60, 0.40, 0.10, 1)

    -- Parchment Letter Body
    local letterBody = frame:CreateFontString(nil, "OVERLAY", "QuestFont")
    letterBody:SetPoint("TOPLEFT", frame, "TOPLEFT", 35, -120)
    letterBody:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -35, 140)
    letterBody:SetJustifyH("LEFT")
    letterBody:SetJustifyV("TOP")
    letterBody:SetSpacing(4)
    letterBody:SetTextColor(0.20, 0.12, 0.05, 1)

    local letterText = "Greetings, recruit!\n\n"
        .. "Hemet Nesingwary here. Slaying beasts is fine and dandy, but any amateur with a blunderbuss can shoot a raptor. The REAL test of a true outdoorsman is taming the wild beasts of Azeroth, raising 'em from cubs, and testing their mettle in battle!\n\n"
        .. "I had my boys ship a hardy wild companion native to your homeland along with a set of my patent Safari Nets and your official 3D Field Guide.\n\n"
        .. "Raise it well, discover wild moves in the field, and make the Safari League proud!\n\n"
        .. "— Hemet Nesingwary Sr."
    letterBody:SetText(letterText)

    -- Starter Rewards Crate Box
    local crateBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    crateBox:SetSize(410, 60)
    crateBox:SetPoint("BOTTOM", frame, "BOTTOM", 0, 70)
    crateBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    crateBox:SetBackdropColor(0.12, 0.08, 0.04, 0.85)
    crateBox:SetBackdropBorderColor(0.70, 0.55, 0.20, 0.9)

    local rewardsLabel = crateBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rewardsLabel:SetPoint("TOPLEFT", crateBox, "TOPLEFT", 10, -6)
    rewardsLabel:SetText("|cffffd100Safari League Starter Kit Includes:|r")

    local rewardsList = crateBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rewardsList:SetPoint("TOPLEFT", rewardsLabel, "BOTTOMLEFT", 0, -4)
    rewardsList:SetText("🐾 Native Level 1 Companion   •   🕸️ 5x Safari Nets   •   📖 3D Field Guide")

    -- Claim & Unbox Button
    local claimBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    claimBtn:SetSize(220, 34)
    claimBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 24)
    claimBtn:SetText("Claim Safari Starter Kit!")
    claimBtn:SetScript("OnClick", function()
        Dispatch:ClaimStarterKit()
        frame:Hide()
    end)
end

function Dispatch:ShowDispatch()
    if not frame then Dispatch:Initialize() end
    PlaySound(844) -- SOUNDKIT.IG_SPELLBOOK_OPEN
    frame:Show()
end

function Dispatch:ClaimStarterKit()
    local _, playerRace = UnitRace("player")
    if isSecret(playerRace) or not playerRace or playerRace == "" then
        playerRace = "Human"
    end

    local starterConfig = {
        ["Human"]     = { name = "Mangy Wolf",       type = "Beast", displayId = 903,  family = "Canine" },
        ["Dwarf"]     = { name = "Young Black Bear", type = "Beast", displayId = 8843, family = "Bear" },
        ["Gnome"]     = { name = "Crag Boar",        type = "Beast", displayId = 138623, family = "Boar" },
        ["NightElf"]  = { name = "Young Nightsaber", type = "Beast", displayId = 11454, family = "Cat" },
        ["Orc"]       = { name = "Scorpid Worker",   type = "Beast", displayId = 2485, family = "Scorpid" },
        ["Troll"]     = { name = "Bloodtalon Raptor",type = "Beast", displayId = 1960, family = "Raptor" },
        ["Tauren"]    = { name = "Kodo Calf",        type = "Beast", displayId = 1451, family = "Kodo" },
        ["Scourge"]   = { name = "Mangy Duskbat",    type = "Beast", displayId = 9535, family = "Bat" },
        ["Undead"]    = { name = "Mangy Duskbat",    type = "Beast", displayId = 9535, family = "Bat" },
    }

    local starterData = starterConfig[playerRace] or starterConfig["Human"]
    local starterMob = ForeverSafari.StatEngine:CreateMobInstance(starterData.name, starterData.type, 1, false, starterData.displayId)
    starterMob.nickname = "Starter " .. starterData.name
    starterMob.family = starterData.family
    DB:AddMob(starterMob)

    -- Grant 5x Safari Nets
    DB:AddInventoryItem("copper_cage", 5)

    PlaySound(1195) -- SOUNDKIT.IG_QUEST_LOG_COMPLETE
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00[Starter Kit Claimed!]|r You received |cffffd100%s (Lv 1)|r and 5x |cffffd100[Nesingwary Safari Net]|r!",
        C.PREFIX, starterMob.name))

    if ForeverSafari.Toast then
        ForeverSafari.Toast:ShowReward(
            "Welcome to the Safari League!",
            string.format("Received %s and 5x Safari Nets!", starterMob.name)
        )
    end
end
