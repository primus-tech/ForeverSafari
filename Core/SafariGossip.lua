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

    Stacked Hierarchy Guarantee:
    If another addon (e.g. Olympus's "Bones!: Teach me Bones") modifies the greeting panel,
    Junior Safari League dynamically detects the external row and anchors directly below it,
    guaranteeing it is always the lowest option on the screen without overlapping.
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
local buttonPool = {}
local hookedFrames = setmetatable({}, { __mode = "k" })
local generation = 0

-- Hidden scanner tooltip for 100% reliable unit subtitle / title inspection (<Innkeeper>, <Pet Trainer>)
local scanTooltip = CreateFrame("GameTooltip", "ForeverSafariGossipScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

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

function SG.IsOurButton(frame)
    return frame and frame.isSafariGossipButton == true
end

-- =========================================================================
-- 🔍 NPC CLASSIFICATION HELPERS
-- =========================================================================
local function GetGossipUnit()
    if UnitExists("target") then return "target" end
    if UnitExists("npc") then return "npc" end
    return nil
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

-- Reads all text lines from the unit's tooltip cleanly without failing on plain strings
local function GetNPCLines(unit)
    unit = unit or GetGossipUnit()
    if not unit or not UnitExists(unit) then return {} end
    local lines = {}

    -- 1. Modern WoW Tooltip API (C_TooltipInfo)
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and data and data.lines then
            for _, l in ipairs(data.lines) do
                if l.leftText and l.leftText ~= "" then
                    table.insert(lines, l.leftText)
                end
            end
            if #lines > 0 then return lines end
        end
    end

    -- 2. Fallback: GameTooltip line scanner
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    local ok = pcall(scanTooltip.SetUnit, scanTooltip, unit)
    if ok then
        for i = 1, scanTooltip:NumLines() do
            local fontString = _G["ForeverSafariGossipScanTooltipTextLeft" .. i]
            local text = fontString and fontString:GetText()
            if text and text ~= "" then
                table.insert(lines, text)
            end
        end
    end

    return lines
end

-- Strict Guard Disqualification: Guards only give directions and have ZERO safari functionality
function SG:IsGuard(unit)
    unit = unit or GetGossipUnit()
    local guardKeywords = {
        "guard", "grunt", "sentinel", "watchman", "sentry",
        "peacekeeper", "bruiser", "bodyguard", "bluffwatcher", "infantry",
        "enforcer", "protector", "patrol", "city watch"
    }

    local lines = GetNPCLines(unit)
    for _, line in ipairs(lines) do
        if MatchesKeyword(line, guardKeywords) then
            return true
        end
    end

    if unit then
        local name = UnitName(unit)
        if name and MatchesKeyword(name, guardKeywords) then
            return true
        end
    end

    if GossipFrameTitleText and GossipFrameTitleText:GetText() then
        if MatchesKeyword(GossipFrameTitleText:GetText(), guardKeywords) then
            return true
        end
    end

    return false
end

function SG:IsPetTrainer(unit)
    if self:IsGuard(unit) then return false end
    unit = unit or GetGossipUnit()
    local keywords = { "pet trainer", "beast trainer", "pet master" }

    local lines = GetNPCLines(unit)
    for _, line in ipairs(lines) do
        -- Exclude hunter class trainers (Hunter Trainers have no connection to Forever Safari)
        if string.find(string.lower(line), "hunter trainer", 1, true) then
            return false
        end
        if MatchesKeyword(line, keywords) then
            return true
        end
    end

    if unit then
        local name = UnitName(unit)
        if name and MatchesKeyword(name, keywords) then
            return true
        end
    end

    return false
end

function SG:IsInnkeeper(unit)
    if self:IsGuard(unit) then return false end
    unit = unit or GetGossipUnit()
    local keywords = { "innkeeper", "tavernkeeper", "bartender" }

    -- 1. Tooltip lines check (<Innkeeper>)
    local lines = GetNPCLines(unit)
    for _, line in ipairs(lines) do
        if MatchesKeyword(line, keywords) then
            return true
        end
    end

    -- 2. Unit Name check
    if unit then
        local name = UnitName(unit)
        if name and MatchesKeyword(name, keywords) then
            return true
        end
    end
    if GossipFrameTitleText and GossipFrameTitleText:GetText() and MatchesKeyword(GossipFrameTitleText:GetText(), keywords) then
        return true
    end

    -- 3. Native Gossip Options check: ONLY authentic hearthstone binder options (Guards NEVER offer this)
    if C_GossipInfo and C_GossipInfo.GetOptions then
        local ok, opts = pcall(C_GossipInfo.GetOptions)
        if ok and opts then
            for _, opt in ipairs(opts) do
                local name = opt.name or opt.title
                if name and MatchesKeyword(name, { "make this inn your home", "bind your soul", "hearthstone" }) then
                    return true
                end
                -- Modern enum check (Enum.GossipOptionRecType.Binder = 6) or legacy string
                if opt.type == "binder" or opt.type == 6 then
                    return true
                end
            end
        end
    end
    if GetGossipOptions then
        local ok, opts = pcall(function() return { GetGossipOptions() } end)
        if ok and opts then
            for i = 1, #opts, 2 do
                local title = opts[i]
                local gType = opts[i+1]
                if gType == "binder" or (title and MatchesKeyword(title, { "make this inn your home", "bind your soul", "hearthstone" })) then
                    return true
                end
            end
        end
    end

    return false
end

function SG:IsBanker(unit)
    if self:IsGuard(unit) then return false end
    unit = unit or GetGossipUnit()
    local keywords = { "banker", "vault keeper" }

    -- 1. Tooltip lines check (<Banker>)
    local lines = GetNPCLines(unit)
    for _, line in ipairs(lines) do
        if MatchesKeyword(line, keywords) then
            return true
        end
    end

    -- 2. Unit Name check
    if unit then
        local name = UnitName(unit)
        if name and MatchesKeyword(name, keywords) then
            return true
        end
    end
    if GossipFrameTitleText and GossipFrameTitleText:GetText() and MatchesKeyword(GossipFrameTitleText:GetText(), keywords) then
        return true
    end

    -- 3. Native Gossip Options check: authentic deposit box inquiry (Guards NEVER offer "deposit box")
    if C_GossipInfo and C_GossipInfo.GetOptions then
        local ok, opts = pcall(C_GossipInfo.GetOptions)
        if ok and opts then
            for _, opt in ipairs(opts) do
                local name = opt.name or opt.title
                if name and MatchesKeyword(name, { "deposit box", "check my deposit", "access the bank" }) then
                    return true
                end
                -- Modern enum check (Enum.GossipOptionRecType.Banker = 7) or legacy string
                if opt.type == "banker" or opt.type == 7 then
                    return true
                end
            end
        end
    end
    if GetGossipOptions then
        local ok, opts = pcall(function() return { GetGossipOptions() } end)
        if ok and opts then
            for i = 1, #opts, 2 do
                local title = opts[i]
                local gType = opts[i+1]
                if gType == "banker" or (title and MatchesKeyword(title, { "deposit box", "check my deposit", "access the bank" })) then
                    return true
                end
            end
        end
    end

    return false
end

function SG:IsCenarionKeeper(unit)
    if self:IsGuard(unit) then return false end
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

    local keywords = { "cenarion", "keeper", "remulos", "loganaar", "nursery", "keeper of the grove", "dryad" }
    if inMoonglade then return true end

    local lines = GetNPCLines(unit)
    for _, line in ipairs(lines) do
        if MatchesKeyword(line, keywords) then
            return true
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

-- Restore native ScrollBox dimensions cleanly and recycle buttons
function SG.Park()
    generation = generation + 1
    for _, btn in ipairs(activeButtons) do
        btn:Hide()
        btn:ClearAllPoints()
        table.insert(buttonPool, btn)
    end
    activeButtons = {}

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
local function AcquireButton(parent, width, caption, iconTexture, onClick)
    local b = table.remove(buttonPool)
    if not b then
        b = CreateFrame("Button", nil, parent, "GossipTitleButtonTemplate")
        b.label, b.icon = b:GetFontString(), b.Icon
        b.isSafariGossipButton = true
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

-- Strictly identify addon-injected gossip rows (any third-party addon), excluding GoodbyeButton / ScrollBars / CloseButtons
local function IsAddonGossipRow(child, scroll, panel)
    if not child or not child:IsShown() then return false end
    if child == scroll then return false end
    if SG.IsOurButton(child) then return false end
    if not child.GetObjectType or child:GetObjectType() ~= "Button" then return false end

    -- Exclude native Blizzard close/goodbye buttons
    if panel and (child == panel.GoodbyeButton or child == panel.CloseButton) then
        return false
    end
    local name = (child.GetName and child:GetName()) or ""
    if string.find(name, "Goodbye", 1, true) or string.find(name, "Close", 1, true)
        or string.find(name, "ScrollBar", 1, true) or string.find(name, "Thumb", 1, true) then
        return false
    end
    local text = (child.GetText and child:GetText()) or ""
    if text == "Goodbye" or text == "Cancel" or text == "Close" then
        return false
    end

    -- Position filter: native window footer buttons sit at the very bottom (within 22px of panel bottom)
    if panel and panel.GetBottom and child.GetBottom then
        local pBottom = panel:GetBottom()
        local cBottom = child:GetBottom()
        if pBottom and cBottom and cBottom < (pBottom + 22) then
            return false
        end
    end

    return true
end

-- Detect lowest external addon row on GreetingPanel
local function FindLowestExternalButton(panel, scroll, bar)
    local lowestBtn = nil
    local minBottom = math.huge

    if panel and panel.GetChildren then
        for _, child in ipairs({ panel:GetChildren() }) do
            if child ~= bar and IsAddonGossipRow(child, scroll, panel) then
                local bottom = child:GetBottom()
                if bottom and bottom < minBottom then
                    minBottom = bottom
                    lowestBtn = child
                end
            end
        end
    end
    return lowestBtn
end

-- =========================================================================
-- 📜 INJECT JUNIOR SAFARI LEAGUE OPTIONS
-- =========================================================================
function SG:BuildOptionsForCurrentNPC()
    local unit = GetGossipUnit()
    local options = {}

    -- Strict Guard Disqualification: Guards have zero gameplay interaction in Forever Safari
    if self:IsGuard(unit) then
        return options
    end

    -- 1. Pet Trainers: Outfitters, Healers & City Breeders (Rank I Untamed)
    if self:IsPetTrainer(unit) then
        table.insert(options, {
            text = "Junior Safari League: Visit Outfitter",
            icon = SG.ICON_SHOP,
            onClick = function()
                CloseGossipWindow()
                C_Timer.After(0.05, function()
                    if ns.ShopFrame and ns.ShopFrame.ShowShop then
                        ns.ShopFrame:ShowShop(true)
                    end
                end)
            end,
        })
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
        table.insert(options, {
            text = "Junior Safari League: Breed Companions (City Nursery)",
            icon = SG.ICON_BREED,
            onClick = function()
                CloseGossipWindow()
                C_Timer.After(0.05, function()
                    local nursery = ns.NurseryFrame or ns.Nursery
                    if nursery and nursery.Show then
                        nursery:Show("CITY")
                    end
                end)
            end,
        })

    -- 2. Innkeepers: Merely Healers
    elseif self:IsInnkeeper(unit) then
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

    -- 3. Bankers: Kennelers (Companion Reserve)
    elseif self:IsBanker(unit) then
        table.insert(options, {
            text = "Junior Safari League: Access Companion Reserve",
            icon = SG.ICON_SHOP,
            onClick = function()
                CloseGossipWindow()
                C_Timer.After(0.05, function()
                    local k = ns.KennelFrame or ns.Kennel
                    if k and k.ShowKennel then
                        k:ShowKennel()
                    end
                end)
            end,
        })

    -- 4. Cenarion Keepers: Sacred Sanctuary Breeders (Moonglade Sacred Grove - Rank III Attuned)
    elseif self:IsCenarionKeeper(unit) then
        table.insert(options, {
            text = "Junior Safari League: Sacred Breeding Ritual",
            icon = SG.ICON_BREED,
            onClick = function()
                CloseGossipWindow()
                C_Timer.After(0.05, function()
                    local nursery = ns.NurseryFrame or ns.Nursery
                    if nursery and nursery.Show then
                        nursery:Show("SACRED")
                    end
                end)
            end,
        })
    end

    -- Note: Stable Masters (Outpost Leaders) receive ZERO native gossip injection.
    -- The WoW: Forever server kills gossip on Stable Masters for non-Hunters.
    -- All Outpost battles are launched cleanly through CaptureHUD ("⚔️ BATTLE").

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

    -- Recycle previous buttons without wiping saved original scroll height
    for _, btn in ipairs(activeButtons) do
        btn:Hide()
        btn:ClearAllPoints()
        table.insert(buttonPool, btn)
    end
    activeButtons = {}

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

    if not saved then
        saved = {
            scroll = scroll,
            bar = bar,
            height = scrollHeight,
            scrollShown = scroll:IsShown(),
            barShown = bar:IsShown(),
        }
    end
    host = f

    -- Check if another addon (like Olympus) has added a row to GreetingPanel
    local lowestExternal = FindLowestExternalButton(panel, scroll, bar)

    if lowestExternal then
        -- 🌟 Another addon modified the screen!
        -- Anchor directly below the lowest external button so we are guaranteed to be lowest.
        local curH = scroll:GetHeight()
        local newH = math.max(60, curH - totalRowHeight)
        scroll:SetHeight(newH)

        local prevAnchor = lowestExternal
        for _, item in ipairs(created) do
            local btn = item.btn
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -SG.ROW_GAP)
            btn:SetWidth(scrollWidth)
            btn:Show()
            table.insert(activeButtons, btn)
            prevAnchor = btn
        end

        -- Synchronize visibility if external addon shows its own modal/dialog (e.g. Olympus Farkle dialog)
        if not lowestExternal.safariHooked then
            lowestExternal.safariHooked = true
            lowestExternal:HookScript("OnHide", function()
                for _, btn in ipairs(activeButtons) do
                    btn:Hide()
                end
            end)
            lowestExternal:HookScript("OnShow", function()
                for _, btn in ipairs(activeButtons) do
                    btn:Show()
                end
            end)
        end
    else
        -- Native screen only (no third-party modifications)
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
            btn:SetWidth(scrollWidth)
            btn:Show()
            table.insert(activeButtons, btn)
            currentOffsetY = currentOffsetY - (item.height + SG.ROW_GAP)
        end
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

        -- Frame 0 layout pass: show immediately
        C_Timer.After(0, function()
            if curGen == generation and GossipFrame and GossipFrame:IsShown() then
                SG.ShowGossip()
            end
        end)

        -- Frame 2 re-anchor pass (0.025s): if another addon (like Olympus) added a row,
        -- smoothly adjust our position so we are guaranteed to sit directly beneath it.
        C_Timer.After(0.025, function()
            if curGen == generation and GossipFrame and GossipFrame:IsShown() then
                SG.ShowGossip()
            end
        end)
    elseif event == "GOSSIP_CLOSED" or event == "PLAYER_REGEN_DISABLED" then
        SG.Park()
    end
end)
