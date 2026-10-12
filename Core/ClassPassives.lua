--[[
    Forever Safari: Player Class Passives & Combat Mechanics Engine
    Evaluates persistent tactical and progression bonuses for companions based on UnitClass("player").
    Percentages scale with companion Attunement Rank (Rank 1 = 1/5 of listed, Rank 2 = 2/5 ... Rank 5 = 5/5).
    All modifications strictly round up via math.ceil().
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.ClassPassives = ns.ClassPassives or {}

local CP = ns.ClassPassives
local C = ns.Constants

CP.PASSIVES = {
    ["WARRIOR"] = {
        id = "WARRIOR",
        name = "Marshal's Tenacity",
        icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
        desc = "Static Slice: Reduces incoming physical damage by 5% per Attunement Rank (5% at Rank 1 to 25% at Rank V).",
    },
    ["PALADIN"] = {
        id = "PALADIN",
        name = "Aegis of Light",
        icon = "Interface\\Icons\\Spell_Holy_AuraMastery",
        desc = "Procced Ward (Physical & Holy): 5% per Rank proc chance to absorb 10% per Rank damage (rolled per hit and per DoT tick). Aura of Light converts 5% to 25% of absorbed damage back into healing HP.",
    },
    ["SHAMAN"] = {
        id = "SHAMAN",
        name = "Elemental Shielding & Rebirth",
        icon = "Interface\\Icons\\Spell_Nature_Reincarnation",
        desc = "Procced Ward (Fire, Frost, Nature): 5% per Rank proc to absorb 10% per Rank damage (rolled per hit and per DoT tick). Primal Rebirth grants a flat 50% chance to resurrect companion once per battle.",
    },
    ["MAGE"] = {
        id = "MAGE",
        name = "Arcane Ward & Chilling Tempo",
        icon = "Interface\\Icons\\Spell_Arcane_Blast",
        desc = "Procced Ward (Arcane, Fire, Frost): 5% per Rank proc to absorb 10% per Rank damage (rolled per hit and per DoT tick). Chilling Tempo procs on offense (5%/rank) or defense (10%/rank) to inflict Chilled (-50% SPD for 2 turns), proportionally reduced by target Frost Resistance % (e.g. 50% frost resist lowers a 50% proc chance to 25%).",
    },
    ["ROGUE"] = {
        id = "ROGUE",
        name = "Shadow Evasion",
        icon = "Interface\\Icons\\Ability_Vanish",
        desc = "Static Slice: +5% per Attunement Rank Dodge Chance (5% at Rank 1 to 25% at Rank V). Fully synergizes with Cunning's +5% Dodge for up to 30% total Dodge Chance.",
    },
    ["PRIEST"] = {
        id = "PRIEST",
        name = "Ward of the Heavens & Grace",
        icon = "Interface\\Icons\\Spell_Holy_Renew",
        desc = "Procced Ward (Shadow & Holy): 5% per Rank proc to absorb 10% per Rank damage (rolled per hit and per DoT tick). Divine Grace provides an active emergency heal command usable Rank times per battle, restoring 25% Max HP.",
    },
    ["HUNTER"] = {
        id = "HUNTER",
        name = "Aspect of the Wild & Pathfinder",
        icon = "Interface\\Icons\\Ability_Hunter_BeastMastery",
        desc = "Static Slice: +5% per Attunement Rank Nature Resistance (5% to 25%). Pathfinder's Mastery boosts baseline Attack and Defense by +5% to +25%.",
    },
    ["DRUID"] = {
        id = "DRUID",
        name = "Gift of the Wild & Ecliptic Tides",
        icon = "Interface\\Icons\\Spell_Arcane_Starfall",
        desc = "Static Slice: +2% per Attunement Rank Omni-Resist across all 6 magic schools (2% to 10%). Ecliptic Tides celestial pendulum builds Solar on offensive moves and Lunar on non-offensive moves, triggering early proc surges or guaranteed 100% capacity discharges.",
    },
    ["WARLOCK"] = {
        id = "WARLOCK",
        name = "Fel Infusion & Suppression",
        icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",
        desc = "Procced Ward (Shadow & Fire): 5% per Rank proc to absorb 10% per Rank damage (rolled per hit and per DoT tick). Curse of Suppression halves opposed class passives by 50% in trainer battles and duels.",
    },
}

function CP:GetPlayerClass()
    local _, classFilename = UnitClass("player")
    return classFilename or "WARRIOR"
end

function CP:GetPassive(classFilename)
    if not classFilename then
        classFilename = self:GetPlayerClass()
    end
    return self.PASSIVES[string.upper(classFilename)]
end

function CP:GetActivePassive()
    return self:GetPassive(self:GetPlayerClass())
end

-- Attunement Rank Scaling: Rank 1 = 1/5 (0.2), Rank 2 = 2/5 (0.4) ... Rank 5 = 5/5 (1.0)
function CP:GetRankScale(rank)
    local r = tonumber(rank) or 1
    r = math.max(1, math.min(5, r))
    return r / 5
end

-- Check if opponent is Warlock, reducing passive effectiveness by up to 50% (scaled by opponent rank / 5)
function CP:GetSuppressionMultiplier(opponentClass, opponentRank)
    if opponentClass and string.upper(opponentClass) == "WARLOCK" then
        local oppRank = tonumber(opponentRank) or 5
        local rankMult = self:GetRankScale(oppRank)
        local suppression = 0.50 * rankMult
        return 1.0 - suppression
    end
    return 1.0
end

-- =========================================================================
-- 🛡️ Procced Wards (Mage, Shaman, Warlock, Priest, Paladin)
-- =========================================================================
CP.WARD_AFFINITIES = {
    ["MAGE"] = { ["Arcane"] = true, ["Fire"] = true, ["Frost"] = true },
    ["SHAMAN"] = { ["Fire"] = true, ["Frost"] = true, ["Nature"] = true },
    ["WARLOCK"] = { ["Shadow"] = true, ["Fire"] = true },
    ["PRIEST"] = { ["Shadow"] = true, ["Holy"] = true },
    ["PALADIN"] = { ["Physical"] = true, ["Normal"] = true, ["Holy"] = true },
}

--- Checks and rolls for a reactive Ward proc against an incoming damage strike or DoT tick.
-- Proc chance = (5 * rank)%. Mitigation = (10 * rank)% damage absorbed.
-- Returns: didProc (bool), mitigationPercent (number)
function CP:RollWardProc(playerClass, rank, damageSchool, opponentClass)
    if not playerClass then return false, 0 end
    local classKey = string.upper(playerClass)
    local affinities = self.WARD_AFFINITIES[classKey]
    if not affinities or not affinities[damageSchool] then
        return false, 0
    end

    local r = math.max(1, math.min(5, tonumber(rank) or 1))
    local procChance = (5 * r) * self:GetSuppressionMultiplier(opponentClass)
    local roll = math.random(1, 100)

    if roll <= procChance then
        local mitPct = 10 * r
        return true, mitPct
    end
    return false, 0
end

--- Rolls for Mage Chilling Tempo proc on attack or defense with Frost Resist Proportional Reduction.
-- Offense: 5% * rank. Defense: 10% * rank.
-- Proportional scaling: at 50% frost resist, a 50% proc chance lowers to 25%.
-- effectiveChance = baseChance * (1 - (targetFrostResist / 100))
-- Returns: didProc (bool), slowTurns (number)
function CP:RollChillingTempo(isDefense, rank, targetFrostResist, opponentClass)
    local r = math.max(1, math.min(5, tonumber(rank) or 1))
    local isDef = (isDefense == true) or (isDefense == "defensive")
    local baseChance = isDef and (10 * r) or (5 * r)
    local frostResist = math.max(0, math.min(100, tonumber(targetFrostResist) or 0))
    local effectiveChance = math.max(0, baseChance * (1.0 - (frostResist / 100))) * self:GetSuppressionMultiplier(opponentClass)

    if effectiveChance <= 0 then return false, r end
    local roll = math.random(1, 100)
    return (roll <= effectiveChance), r
end

--- Evaluates Shaman Primal Rebirth on companion defeat (flat 50% chance once per battle).
-- Returns: didRevive (bool)
function CP:RollAnkh(playerClass, hasUsedRevive, opponentClass)
    if not playerClass or string.upper(playerClass) ~= "SHAMAN" or hasUsedRevive then
        return false
    end
    local chance = 50 * self:GetSuppressionMultiplier(opponentClass)
    local roll = math.random(1, 100)
    return roll <= chance
end

--- Priest Divine Grace: Heals companion for 25% Max HP (rounded up).
function CP:GetPriestHealAmount(maxHP, playerClass, opponentClass)
    if not playerClass or string.upper(playerClass) ~= "PRIEST" or not maxHP or maxHP <= 0 then
        return 0
    end
    local heal = math.ceil(maxHP * 0.25)
    return heal
end

--- Priest Divine Grace: Usable rank times per battle.
function CP:GetPriestMaxHeals(rank, playerClass, opponentClass)
    if not playerClass or string.upper(playerClass) ~= "PRIEST" then return 0 end
    local base = math.max(1, math.min(5, tonumber(rank) or 1))
    if opponentClass and string.upper(opponentClass) == "WARLOCK" then
        return math.max(1, math.ceil(base * 0.5))
    end
    return base
end

-- 🛡️ Warrior: Physical Damage Mitigation (5% per Rank, up to 25% at Rank V)
function CP:CalculatePhysicalDamageReduction(dmg, playerClass, opponentClass, rank)
    if playerClass ~= "WARRIOR" or not dmg or dmg <= 0 then return 0 end
    local rankMult = self:GetRankScale(rank)
    local mult = (0.25 * rankMult) * self:GetSuppressionMultiplier(opponentClass)
    return math.ceil(dmg * mult)
end

-- 🛡️ Paladin: Damage-to-Healing Conversion (5% per Rank, up to 25% at Rank V)
function CP:CalculatePaladinHealback(dmg, playerClass, opponentClass, rank)
    if playerClass ~= "PALADIN" or not dmg or dmg <= 0 then return 0 end
    local rankMult = self:GetRankScale(rank)
    local mult = (0.25 * rankMult) * self:GetSuppressionMultiplier(opponentClass)
    return math.ceil(dmg * mult)
end

-- ⚡ Shaman: Primal Rebirth (10% per Rank, up to 50% at Rank V chance to revive at 50% HP)
function CP:CanShamanRevive(playerClass, hasUsedRevive, opponentClass, rank)
    if playerClass ~= "SHAMAN" or hasUsedRevive then return false end
    local rankMult = self:GetRankScale(rank)
    local chance = (50 * rankMult) * self:GetSuppressionMultiplier(opponentClass)
    local roll = math.random(1, 100)
    if roll <= chance then
        return true
    end
    return false
end

-- 🔮 Mage: Non-physical Damage Mitigation (5% per Rank, up to 25% at Rank V)
function CP:CalculateMageSpellReduction(dmg, element, playerClass, opponentClass, rank)
    if playerClass ~= "MAGE" or not dmg or dmg <= 0 then return 0 end
    if element == "Physical" or element == "Normal" then return 0 end
    local rankMult = self:GetRankScale(rank)
    local mult = (0.25 * rankMult) * self:GetSuppressionMultiplier(opponentClass)
    return math.ceil(dmg * mult)
end

-- 🔮 Mage: Speed Suppression Duration (Rank turns, 1-5)
function CP:GetMageSlowDuration(rank, opponentClass)
    local base = math.max(1, math.min(5, tonumber(rank) or 1))
    if opponentClass and string.upper(opponentClass) == "WARLOCK" then
        return math.max(1, math.ceil(base * 0.5))
    end
    return base
end

-- 🗡️ Rogue: Evasion Miss Bonus (+5% per Rank, up to +25% at Rank V)
function CP:GetRogueMissBonus(playerClass, opponentClass, rank)
    if playerClass ~= "ROGUE" then return 0 end
    local rankMult = self:GetRankScale(rank)
    local bonus = (25 * rankMult) * self:GetSuppressionMultiplier(opponentClass)
    return math.ceil(bonus)
end

-- 🌿 Priest: Divine Grace Max Uses (equal to Attunement Rank, 1-5)
function CP:GetPriestMaxHeals(rank, playerClass, opponentClass)
    if playerClass ~= "PRIEST" then return 0 end
    local base = math.max(1, math.min(5, tonumber(rank) or 1))
    if opponentClass and string.upper(opponentClass) == "WARLOCK" then
        return math.max(1, math.ceil(base * 0.5))
    end
    return base
end

-- 🌿 Priest: Divine Grace Heal Amount (5% Max HP per Rank, up to 25% at Rank V)
function CP:GetPriestHealAmount(maxHP, playerClass, opponentClass, rank)
    if playerClass ~= "PRIEST" or not maxHP or maxHP <= 0 then return 0 end
    local rankMult = self:GetRankScale(rank)
    local mult = (0.25 * rankMult) * self:GetSuppressionMultiplier(opponentClass)
    return math.ceil(maxHP * mult)
end

-- 🏹 Hunter: Basic Attack & Defense Efficiency (+5% per Rank, up to +25% at Rank V)
function CP:ApplyHunterStatBonus(statVal, statType, playerClass, opponentClass, rank)
    if playerClass ~= "HUNTER" or not statVal or statVal <= 0 then return statVal end
    if statType == "atk" or statType == "def" then
        local rankMult = self:GetRankScale(rank)
        local bonus = (0.25 * rankMult) * self:GetSuppressionMultiplier(opponentClass)
        return statVal + math.ceil(statVal * bonus)
    end
    return statVal
end

-- =========================================================================
-- 🍃 Druid: Ecliptic Tides (In-Combat Celestial Pendulum & Surges)
-- =========================================================================

--- Advances the Druid Eclipse meter based on move role and companion Attunement Rank.
-- Capped at companion rank (1-5). Once full, points are siphoned from the opposite side.
-- Returns: didAutoDischarge (bool), surgeType ("SOLAR"|"LUNAR"|nil), surgePoints (number)
function CP:UpdateEclipseMeter(meter, moveRole, maxRank)
    if not meter then return false, nil, 0 end
    maxRank = math.max(1, math.min(5, tonumber(maxRank) or 1))
    meter.solar = meter.solar or 0
    meter.lunar = meter.lunar or 0

    if moveRole == "Offensive" then
        if (meter.solar + meter.lunar) < maxRank then
            meter.solar = meter.solar + 1
        else
            -- Pool is at max capacity: siphon from Lunar
            if meter.lunar > 0 then
                meter.lunar = meter.lunar - 1
            end
            meter.solar = math.min(maxRank, meter.solar + 1)
        end
    else
        -- Non-Offensive: Defensive, Healing, Utility -> Lunar
        if (meter.solar + meter.lunar) < maxRank then
            meter.lunar = meter.lunar + 1
        else
            -- Pool is at max capacity: siphon from Solar
            if meter.solar > 0 then
                meter.solar = meter.solar - 1
            end
            meter.lunar = math.min(maxRank, meter.lunar + 1)
        end
    end

    -- Automatic 100% discharge if meter is filled to either end
    if meter.solar >= maxRank then
        local pts = meter.solar
        meter.solar = 0
        meter.lunar = 0
        return true, "SOLAR", pts
    elseif meter.lunar >= maxRank then
        local pts = meter.lunar
        meter.solar = 0
        meter.lunar = 0
        return true, "LUNAR", pts
    end

    return false, nil, 0
end

--- Rolls chance for an early Eclipse surge on cast (5% per point on the cast side).
-- If opponent is Warlock, applies suppression multiplier.
-- Returns: didProc (bool)
function CP:RollEclipseSurge(points, opponentClass)
    points = tonumber(points) or 0
    if points <= 0 then return false end
    local chance = (points * 5) * self:GetSuppressionMultiplier(opponentClass)
    local roll = math.random(1, 100)
    return roll <= chance
end

--- Calculates Rejuvenating Bloom HoT amount (5% Max HP per Solar point).
-- Duration equals Solar points (1-5 rounds).
-- Returns: healPerRound (number), duration (number)
function CP:GetSolarHoT(maxHP, points)
    points = math.max(1, math.min(5, tonumber(points) or 1))
    local percent = points * 0.05
    local amount = math.ceil((tonumber(maxHP) or 100) * percent)
    return amount, points
end

--- Calculates Bramble Damage Shield reflected damage (5% per Lunar point).
-- Reflects Nature damage back to attacker.
-- Returns: reflectDamage (number)
function CP:GetLunarBrambles(incomingDmg, points, opponentClass)
    points = math.max(1, math.min(5, tonumber(points) or 1))
    if not incomingDmg or incomingDmg <= 0 then return 0 end
    local mult = (points * 0.05) * self:GetSuppressionMultiplier(opponentClass)
    return math.ceil(incomingDmg * mult)
end

-- Backwards-compatibility stubs
function CP:ApplyDruidAttunementGain(gain, playerClass, rank)
    return gain
end

function CP:GetDruidRankThreshold(baseThreshold, playerClass, targetRank)
    return baseThreshold
end

