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
        desc = "Physical Damage Mitigation: Reduces incoming physical damage by 5% per Attunement Rank, up to 25% at Rank V (rounded up).",
    },
    ["PALADIN"] = {
        id = "PALADIN",
        name = "Aura of Light",
        icon = "Interface\\Icons\\Spell_Holy_AuraMastery",
        desc = "Damage-to-Healing Conversion: Converts 5% per Attunement Rank of incoming damage back into healing HP, up to 25% at Rank V (rounded up).",
    },
    ["SHAMAN"] = {
        id = "SHAMAN",
        name = "Primal Rebirth",
        icon = "Interface\\Icons\\Spell_Nature_Reincarnation",
        desc = "Ancestral Revive: Your companion has a 10% per Attunement Rank chance (up to 50% at Rank V) to revive at 50% health on first knockout.",
    },
    ["MAGE"] = {
        id = "MAGE",
        name = "Arcane Celerity & Ward",
        icon = "Interface\\Icons\\Spell_Arcane_Blast",
        desc = "Speed Suppression & Spell Ward: Enemy attackers suffer halved speed for turns equal to Attunement Rank (1-5). Companions gain 5% per Attunement Rank (up to 25% at Rank V) resistance to non-physical damage (rounded up).",
    },
    ["ROGUE"] = {
        id = "ROGUE",
        name = "Shadow Evasion",
        icon = "Interface\\Icons\\Ability_Vanish",
        desc = "Phantom Footwork: Enemy companions suffer a +5% per Attunement Rank increase to their miss chance (up to +25% at Rank V).",
    },
    ["PRIEST"] = {
        id = "PRIEST",
        name = "Divine Grace",
        icon = "Interface\\Icons\\Spell_Holy_Renew",
        desc = "Rank-Scaled Active Emergency Healing: Your companion can be actively healed in battle up to Rank uses (1-5), restoring 5% Max HP per Rank (up to 25% at Rank V, rounded up).",
    },
    ["HUNTER"] = {
        id = "HUNTER",
        name = "Pathfinder's Mastery",
        icon = "Interface\\Icons\\Ability_Hunter_BeastMastery",
        desc = "Enhanced Baseline Efficiency: Your companions' attack and defense values are boosted by 5% per Attunement Rank (up to +25% at Rank V, rounded up).",
    },
    ["DRUID"] = {
        id = "DRUID",
        name = "Wild Symbiosis",
        icon = "Interface\\Icons\\Ability_Druid_Flourish",
        desc = "Accelerated Evolution & Bonding: Attunement rewards are boosted by 5% per Attunement Rank (up to +25% at Rank V, rounded up), and Attunement rank thresholds are reduced by 5% per Rank (up to -25% at Rank V, rounded up).",
    },
    ["WARLOCK"] = {
        id = "WARLOCK",
        name = "Curse of Suppression",
        icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",
        desc = "Opposed Bonus Sabotage: Decreases opposed class bonuses by 10% per Attunement Rank (up to 50% at Rank V, rounded up) in trainer battles and duels.",
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

-- 🍃 Druid: Wild Symbiosis Attunement Boost (+5% per Rank, up to +25% at Rank V)
function CP:ApplyDruidAttunementGain(gain, playerClass, rank)
    if playerClass ~= "DRUID" or not gain or gain <= 0 then return gain end
    local rankMult = self:GetRankScale(rank)
    local bonus = 0.25 * rankMult
    return gain + math.ceil(gain * bonus)
end

-- 🍃 Druid: Rank Threshold Discount (-5% per Rank, up to -25% at Rank V)
function CP:GetDruidRankThreshold(baseThreshold, playerClass, targetRank)
    if playerClass ~= "DRUID" or not baseThreshold or baseThreshold <= 0 then return baseThreshold end
    local r = tonumber(targetRank) or 5
    local rankMult = self:GetRankScale(r)
    local discount = 0.25 * rankMult
    return math.max(1, math.ceil(baseThreshold * (1 - discount)))
end
