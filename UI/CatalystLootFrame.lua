--[[
    Forever Safari: Secondary Boss Catalyst Loot Roll Window
    Pops up when defeating a dungeon boss or catalyst-dropping encounter.
    Players can only GREED or PASS (NEED is permanently disabled).
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.CatalystLootFrame = ns.CatalystLootFrame or {}

local Loot = ns.CatalystLootFrame
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
local activeRoll = nil
local partyRolls = {}

function Loot:Initialize()
    if frame then return end

    frame = CreateFrame("Frame", "ForeverSafariCatalystLootFrame", UIParent, "BackdropTemplate")
    frame:SetSize(360, 96)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -180)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.06, 0.08, 0.12, 0.95)

    -- Item Icon
    local itemIcon = frame:CreateTexture(nil, "ARTWORK")
    itemIcon:SetSize(44, 44)
    itemIcon:SetPoint("LEFT", frame, "LEFT", 12, 6)
    itemIcon:SetTexture("Interface\\Icons\\Spell_Shadow_GatherShadows")
    frame.itemIcon = itemIcon

    -- Item Name
    local itemName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    itemName:SetPoint("TOPLEFT", itemIcon, "TOPRIGHT", 10, -2)
    itemName:SetText("|cffa335ee[Shadowfang Essence]|r")
    frame.itemName = itemName

    -- Item Subtitle / Source
    local itemSub = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemSub:SetPoint("TOPLEFT", itemName, "BOTTOMLEFT", 0, -3)
    itemSub:SetText("|cffffd100Evolution Catalyst|r — Shadowfang Keep")
    frame.itemSub = itemSub

    -- Roll Timer Progress Bar
    local statusBar = CreateFrame("StatusBar", nil, frame)
    statusBar:SetSize(336, 6)
    statusBar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    statusBar:SetStatusBarColor(0.9, 0.7, 0.1, 1)
    statusBar:SetMinMaxValues(0, 60)
    statusBar:SetValue(60)
    frame.statusBar = statusBar

    local bgBar = statusBar:CreateTexture(nil, "BACKGROUND")
    bgBar:SetAllPoints()
    bgBar:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -- 1. NEED BUTTON (PERMANENTLY DISABLED - No one can Need on League Catalysts)
    local needBtn = CreateFrame("Button", nil, frame)
    needBtn:SetSize(28, 28)
    needBtn:SetPoint("RIGHT", frame, "RIGHT", -76, 8)
    needBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
    needBtn:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Down")
    needBtn:SetDisabledTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight")
    needBtn:Disable()
    if needBtn:GetNormalTexture() then
        needBtn:GetNormalTexture():SetDesaturated(true)
        needBtn:GetNormalTexture():SetAlpha(0.35)
    end

    needBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffff2020Need Unavailable|r", 1, 0.2, 0.2)
        GameTooltip:AddLine("Safari League Evolution Catalysts are shared discoveries and cannot be Needed!", 0.9, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    needBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 2. GREED BUTTON (ENABLED - Roll 1-100)
    local greedBtn = CreateFrame("Button", nil, frame)
    greedBtn:SetSize(28, 28)
    greedBtn:SetPoint("RIGHT", frame, "RIGHT", -44, 8)
    greedBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
    greedBtn:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Down")
    greedBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Highlight")

    greedBtn:SetScript("OnClick", function()
        Loot:RollGreed()
    end)
    greedBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cff00ff00Greed Roll|r", 0, 1, 0)
        GameTooltip:AddLine("Roll 1-100 for this rare Evolution Catalyst.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    greedBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.greedBtn = greedBtn

    -- 3. PASS BUTTON (ENABLED - Pass on Roll)
    local passBtn = CreateFrame("Button", nil, frame)
    passBtn:SetSize(28, 28)
    passBtn:SetPoint("RIGHT", frame, "RIGHT", -12, 8)
    passBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    passBtn:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
    passBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")

    passBtn:SetScript("OnClick", function()
        Loot:PassRoll()
    end)
    passBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Pass", 1, 1, 1)
        GameTooltip:AddLine("Pass on this Evolution Catalyst.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    passBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Update Timer Loop
    local elapsedTimer = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        if not activeRoll then return end
        elapsedTimer = elapsedTimer + elapsed
        local remaining = math.max(0, activeRoll.duration - elapsedTimer)
        statusBar:SetValue(remaining)

        if remaining <= 0 then
            Loot:ResolveRoll()
        end
    end)
end

function Loot:StartRoll(catalystId, bossName)
    if not frame then Loot:Initialize() end

    local evo = ForeverSafari:GetEvolution(catalystId)
    if not evo then return end

    activeRoll = {
        catalystId = catalystId,
        evo = evo,
        bossName = bossName or "Dungeon Boss",
        duration = 60,
        startTime = GetTime(),
        playerRolled = false,
        playerRollValue = 0,
    }
    wipe(partyRolls)

    frame.itemIcon:SetTexture("Interface\\Icons\\" .. evo.itemIcon)
    frame.itemName:SetText(string.format("|cffa335ee[%s]|r", evo.name))
    frame.itemSub:SetText(string.format("|cffffd100Catalyst Drop:|r %s (%s Lv %d+)", evo.source, evo.requiredFamily, evo.minLevel))

    frame.statusBar:SetMinMaxValues(0, 60)
    frame.statusBar:SetValue(60)
    frame.greedBtn:Enable()

    PlaySound(895) -- SOUNDKIT.AUCTION_WINDOW_OPEN
    frame:Show()
end

function Loot:RollGreed()
    if not activeRoll or activeRoll.playerRolled then return end
    activeRoll.playerRolled = true
    frame.greedBtn:Disable()

    local rollVal = math.random(1, 100)
    activeRoll.playerRollValue = rollVal

    local playerName = UnitName("player")
    if isSecret(playerName) or not playerName or playerName == "" then playerName = "Player" end
    partyRolls[playerName] = rollVal

    DEFAULT_CHAT_FRAME:AddMessage(string.format("%sYou rolled |cffffd100%d|r (Greed) for |cffa335ee[%s]|r.",
        C.PREFIX, rollVal, activeRoll.evo.name))

    -- If in party/raid, broadcast roll
    if IsInGroup() and ForeverSafari.Comms and ForeverSafari.Comms.SendCommMessage then
        local msg = string.format("CATALYST_ROLL:%d:%d", activeRoll.catalystId, rollVal)
        ForeverSafari.Comms:SendCommMessage(msg, IsInRaid() and "RAID" or "PARTY")
    else
        -- Solo play: instant win!
        Loot:ResolveRoll()
    end
end

function Loot:PassRoll()
    if not activeRoll then return end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%sYou passed on |cffa335ee[%s]|r.", C.PREFIX, activeRoll.evo.name))
    frame:Hide()
    activeRoll = nil
end

function Loot:ReceivePeerRoll(sender, catalystId, rollVal)
    if not activeRoll or activeRoll.catalystId ~= catalystId then return end
    partyRolls[sender] = rollVal
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffffd100%s|r rolled |cffffff00%d|r (Greed) for |cffa335ee[%s]|r.",
        C.PREFIX, sender, rollVal, activeRoll.evo.name))
end

function Loot:ResolveRoll()
    if not activeRoll then return end

    local highestRoll = -1
    local localName = UnitName("player")
    if isSecret(localName) or not localName or localName == "" then localName = "Player" end
    local winner = localName

    for name, rollVal in pairs(partyRolls) do
        if rollVal > highestRoll then
            highestRoll = rollVal
            winner = name
        end
    end

    local evoName = activeRoll.evo.name
    local catId = activeRoll.catalystId

    if winner == localName and highestRoll > 0 then
        -- Player won the catalyst!
        DB:AddInventoryItem("catalyst_" .. catId, 1)
        PlaySound(1195) -- SOUNDKIT.IG_QUEST_LOG_COMPLETE

        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00You won the roll (%d) for |cffa335ee[%s]|r! Added to Safari Bag.|r",
            C.PREFIX, highestRoll, evoName))

        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowReward(
                "Catalyst Loot Won!",
                string.format("Won [%s] with a roll of %d!", evoName, highestRoll)
            )
        end
    elseif highestRoll > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffffd100%s|r won |cffa335ee[%s]|r with a roll of %d.",
            C.PREFIX, winner, evoName, highestRoll))
    end

    frame:Hide()
    activeRoll = nil
end
