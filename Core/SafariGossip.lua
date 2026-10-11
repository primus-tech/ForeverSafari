--[[
    Forever Safari: Junior Safari League NPC Gossip Integration (SafariGossip.lua)
    Modeled after Olympus's zero-taint GossipFrame injection architecture.
    Appends custom, addon-owned GossipTitleButtonTemplate rows to native NPC conversations:
    - Pet Trainers:
      * "Junior Safari League: Challenge Outpost Leader"
      * "Junior Safari League: Visit Outfitter"
    - Innkeepers:
      * "Junior Safari League: Rest and Revive Squad"
    - Cenarion Keepers (Moonglade):
      * "Junior Safari League: Breed My Pet"
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.SafariGossip = ns.SafariGossip or {}

local SG = ns.SafariGossip
local C = ns.Constants
local DB = ns.Database
local BE = ns.BattleEngine

SG.ROW_GAP = 4
SG.ICON_LEAGUE = "Interface\\Icons\\Ability_Hunter_KillCommand"
SG.ICON_SHOP = "Interface\\Icons\\INV_Box_PetCarrier_01"
SG.ICON_HEAL = "Interface\\Icons\\Spell_Holy_Renew"
SG.ICON_BREED = "Interface\\Icons\\Ability_Druid_Flourish"

local host, saved
local activeButtons = {}
local hookedFrames = setmetatable({}, { __mode = "k" })
local generation = 0

local function Method(obj, key)
    return obj and type(obj[key]) == "function"
end

local function CloseGossipWindow()
    if C_GossipInfo and C_GossipInfo.CloseGossip then
        pcall(C_GossipInfo.CloseGossip)
    elseif CloseGossip then
        pcall(CloseGossip)
    end
end

-- =========================================================================
-- 🔍 NPC CLASSIFICATION HELPERS
-- =========================================================================
local function GetGossipUnit()
    return UnitExists("npc") and "npc" or (UnitExists("target") and "target" or nil)
end

local function MatchesKeyword(text, keywords)
    if not text or type(text) ~= "string" then return false end
    local lower = string.lower(text)
    for _, kw in ipairs(keywords) do
        if string.find(lower, kw, 1, true) then
            return true
        end
    end
    return false
end

function SG:IsPetTrainer(unit)
    unit = unit or GetGossipUnit()
    if not unit then return false end
    local keywords = { "pet trainer", "beast trainer", "pet master", "hunter trainer" }

    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, info = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and info and info.lines then
            for _, line in ipairs(info.lines) do
                if line.leftText and MatchesKeyword(line.leftText, keywords) then
                    return true
                end
            end
        end
    end

    local name = UnitName(unit)
    if name and MatchesKeyword(name, keywords) then
        return true
    end

    return false
end

function SG:IsInnkeeper(unit)
    unit = unit or GetGossipUnit()
    if not unit then return false end
    local keywords = { "innkeeper", "tavern", "bartender" }

    if GossipFrameTitleText and GossipFrameTitleText:GetText() and MatchesKeyword(GossipFrameTitleText:GetText(), keywords) then
        return true
    end

    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, info = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and info and info.lines then
            for _, line in ipairs(info.lines) do
                if line.leftText and MatchesKeyword(line.leftText, keywords) then
                    return true
                end
            end
        end
    end

    local name = UnitName(unit)
    if name and MatchesKeyword(name, keywords) then
        return true
    end

    return false
end

function SG:IsCenarionKeeper(unit)
    local zone = GetZoneText and GetZoneText()
    local subzone = GetSubZoneText and GetSubZoneText()
    local inMoonglade = false

    if zone and (string.find(string.lower(zone), "moonglade", 1, true) or string.find(string.lower(zone), "nighthaven", 1, true)) then
        inMoonglade = true
    elseif subzone and (string.find(string.lower(subzone), "moonglade", 1, true) or string.find(string.lower(subzone), "nighthaven", 1, true)) then
        inMoonglade = true
    end

    unit = unit or GetGossipUnit()
    if not unit then return inMoonglade end

    local keywords = { "cenarion", "keeper", "remulos", "loganaar", "nursery", "druid" }
    if inMoonglade then return true end

    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, info = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and info and info.lines then
            for _, line in ipairs(info.lines) do
                if line.leftText and MatchesKeyword(line.leftText, keywords) then
                    return true
                end
            end
        end
    end

    local name = UnitName(unit)
    if name and MatchesKeyword(name, keywords) then
        return true
    end

    return false
end

-- =========================================================================
-- 🏛️ NATIVE GOSSIP FRAME GEOMETRY INSPECTION
-- =========================================================================
local function Native()
    if InCombatLockdown and InCombatLockdown() then return nil end
    local f = rawget(_G, "GossipFrame")
    local panel = f and f.GreetingPanel
    local scroll, bar = panel and panel.ScrollBox, panel and panel.ScrollBar

    if not Method(f, "IsShown") or not f:IsShown() or not Method(f, "HookScript")
        or not Method(f, "RegisterFontStrings") or not Method(f, "UpdateFontStrings")
        or not Method(f, "IsProtected")
        or not panel or not Method(scroll, "GetHeight") or not Method(scroll, "SetHeight")
        or not Method(scroll, "GetDerivedExtent")
        or not Method(scroll, "IsProtected")
        or not Method(scroll, "GetWidth") or not Method(scroll, "IsShown")
        or not Method(scroll, "Show") or not Method(scroll, "Hide")
        or not Method(bar, "IsShown") or not Method(bar, "Show") or not Method(bar, "Hide")
        or not Method(bar, "IsProtected") then
        return nil
    end

    -- Security checks: never borrow geometry from protected native regions
    local checked, protected = pcall(f.IsProtected, f)
    if not checked or protected ~= false then return nil end
    checked, protected = pcall(scroll.IsProtected, scroll)
    if not checked or protected ~= false then return nil end
    checked, protected = pcall(bar.IsProtected, bar)
    if not checked or protected ~= false then return nil end

    return f, panel, scroll, bar
end

-- Restore native ScrollBox dimensions cleanly
function SG.Park()
    generation = generation + 1
    for _, btn in ipairs(activeButtons) do
        btn:Hide()
    end
    if saved then
        saved.scroll:SetHeight(saved.height)
        if saved.scrollShown then saved.scroll:Show() else saved.scroll:Hide() end
        if saved.barShown then saved.bar:Show() else saved.bar:Hide() end
    end
    saved, host = nil, nil
end

-- =========================================================================
-- 🔘 BUTTON FACTORY
-- =========================================================================
local buttonPool = {}

local function AcquireButton(parent, width, caption, iconTexture, onClick)
    local b = table.remove(buttonPool)
    if not b then
        b = CreateFrame("Button", nil, parent, "GossipTitleButtonTemplate")
        b.label, b.icon = b:GetFontString(), b.Icon
    end

    b:SetParent(parent)
    b:SetWidth(width)
    if b.label and Method(b.label, "SetWidth") then
        b.label:SetWidth(width - 30)
    end
    if Method(b, "SetTextAndResize") then
        b:SetTextAndResize(caption)
    else
        b:SetText(caption)
    end
    if b.icon and Method(b.icon, "SetTexture") and iconTexture then
        b.icon:SetTexture(iconTexture)
    end
    b:SetScript("OnClick", onClick)
    b:Show()

    return b
end

-- =========================================================================
-- 📜 INJECT JUNIOR SAFARI LEAGUE OPTIONS
-- =========================================================================
function SG:BuildOptionsForCurrentNPC()
    local unit = GetGossipUnit()
    local options = {}

    if self:IsPetTrainer(unit) then
        -- 1. Challenge Outpost Leader
        table.insert(options, {
            text = "Junior Safari League: Challenge Outpost Leader",
            icon = SG.ICON_LEAGUE,
            onClick = function()
                CloseGossipWindow()
                C_Timer.After(0.05, function()
                    local trainerUnit = UnitExists("npc") and "npc" or "target"
                    if ns.BattleEngine and ns.BattleEngine.StartWildBattle then
                        ns.BattleEngine:StartWildBattle(trainerUnit)
                    end
                end)
            end,
        })
        -- 2. Visit Outfitter
        table.insert(options, {
            text = "Junior Safari League: Visit Outfitter",
            icon = SG.ICON_SHOP,
            onClick = function()
                CloseGossipWindow()
                C_Timer.After(0.05, function()
                    if ns.Shop and ns.Shop.Show then
                        ns.Shop:Show()
                    end
                end)
            end,
        })
    elseif self:IsInnkeeper(unit) then
        -- 3. Rest and Revive Squad
        table.insert(options, {
            text = "Junior Safari League: Rest and Revive Squad",
            icon = SG.ICON_HEAL,
            onClick = function()
                if DB and DB.HealAllPets then
                    DB:HealAllPets(false)
                end
                CloseGossipWindow()
            end,
        })
    elseif self:IsCenarionKeeper(unit) then
        -- 4. Breed My Pet
        table.insert(options, {
            text = "Junior Safari League: Breed My Pet",
            icon = SG.ICON_BREED,
            onClick = function()
                CloseGossipWindow()
                C_Timer.After(0.05, function()
                    if ns.Nursery and ns.Nursery.Show then
                        ns.Nursery:Show()
                    end
                end)
            end,
        })
    end

    return options
end

function SG.ShowGossip()
    if InCombatLockdown and InCombatLockdown() then return false end
    local f, panel, scroll, bar = Native()
    if not f or not scroll then return false end

    local options = SG:BuildOptionsForCurrentNPC()
    if #options == 0 then
        SG.Park()
        return false
    end

    SG.Park()

    local scrollWidth = scroll:GetWidth()
    local scrollHeight = scroll:GetHeight()
    local measured, extent = pcall(scroll.GetDerivedExtent, scroll)
    if not measured or type(extent) ~= "number" or extent ~= extent or extent <= 0 then
        extent = scrollHeight
    end

    -- Pre-create buttons to calculate total added height
    local created = {}
    local totalRowHeight = 0
    local fontStringsToRegister = {}

    for _, opt in ipairs(options) do
        local btn = AcquireButton(panel, scrollWidth, opt.text, opt.icon, opt.onClick)
        local rH = btn:GetHeight() or 24
        totalRowHeight = totalRowHeight + rH + SG.ROW_GAP
        table.insert(created, { btn = btn, height = rH })
        if btn.label then
            table.insert(fontStringsToRegister, btn.label)
        end
    end

    saved = {
        scroll = scroll,
        bar = bar,
        height = scrollHeight,
        scrollShown = scroll:IsShown(),
        barShown = bar:IsShown(),
    }
    host = f

    -- Borrow geometry from bottom of ScrollBox
    local availableHeight = math.max(60, scrollHeight - totalRowHeight)
    local rowTop = math.min(extent, availableHeight)
    if extent > rowTop then
        scroll:SetHeight(rowTop)
    end

    local currentOffsetY = -(rowTop + SG.ROW_GAP)
    for _, item in ipairs(created) do
        local btn = item.btn
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, currentOffsetY)
        btn:Show()
        table.insert(activeButtons, btn)
        currentOffsetY = currentOffsetY - (item.height + SG.ROW_GAP)
    end

    -- Register with Blizzard's contrast & accessibility engine
    if #fontStringsToRegister > 0 and Method(f, "RegisterFontStrings") and Method(f, "UpdateFontStrings") then
        pcall(f.RegisterFontStrings, f, unpack(fontStringsToRegister))
        pcall(f.UpdateFontStrings, f)
    end

    -- Hook OnHide once
    if not hookedFrames[f] then
        hookedFrames[f] = true
        f:HookScript("OnHide", function()
            SG.Park()
        end)
    end

    return true
end

-- =========================================================================
-- ⚡ EVENT HOOKS
-- =========================================================================
local eventFrame = CreateFrame("Frame", "ForeverSafariSafariGossipEvents")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("GOSSIP_CLOSED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "GOSSIP_SHOW" then
        SG.Park()
        local curGen = generation
        -- Wait 0 frames for Blizzard's layout to complete
        C_Timer.After(0, function()
            if curGen == generation then
                SG.ShowGossip()
            end
        end)
    elseif event == "GOSSIP_CLOSED" or event == "PLAYER_REGEN_DISABLED" then
        SG.Park()
    end
end)
