--[[
    Forever Safari: Player Class Passives & Combat Mechanics Engine
    Evaluates persistent tactical and progression bonuses for companions based on UnitClass("player").
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
        desc = "Physical Damage Mitigation: All physical damage dealt to your companion by enemies is reduced by 25% (rounded up).",
    },
    ["PALADIN"] = {
        id = "PALADIN",
        name = "Aura of Light",
        icon = "Interface\\Icons\\Spell_Holy_AuraMastery",
        desc = "Damage-to-Healing Conversion: Exactly 25% of all incoming damage taken by your companion is converted back into healing HP (rounded up).",
    },
    ["SHAMAN"] = {
        id = "SHAMAN",
        name = "Primal Rebirth",
        icon = "Interface\\Icons\\Spell_Nature_Reincarnation",
        desc = "Ancestral Revive: Your companion has a flat 50% chance to revive at 50% health the first time it is knocked out in any turn-based battle.",
    },
    ["MAGE"] = {
        id = "MAGE",
        name = "Arcane Celerity & Ward",
        icon = "Interface\\Icons\\Spell_Arcane_Blast",
        desc = "Speed Suppression & Spell Ward: Enemy attackers suffer halved speed for turns equal to companion Attunement Rank (1-5). Companions gain permanent 25% resistance to non-physical damage (rounded up).",
    },
    ["ROGUE"] = {
        id = "ROGUE",
        name = "Shadow Evasion",
        icon = "Interface\\Icons\\Ability_Vanish",
        desc = "Phantom Footwork: All enemy companions suffer a flat +25% increase to their miss chance when targeting your companions.",
    },
    ["PRIEST"] = {
        id = "PRIEST",
        name = "Divine Grace",
        icon = "Interface\\Icons\\Spell_Holy_Renew",
        desc = "Rank-Scaled Active Emergency Healing: Your companion can be actively healed in battle a number of times equal to Attunement Rank (1-5 uses), restoring 25% Max HP (rounded up).",
    },
    ["HUNTER"] = {
        id = "HUNTER",
        name = "Pathfinder's Mastery",
        icon = "Interface\\Icons\\Ability_Hunter_BeastMastery",
        desc = "Enhanced Baseline Efficiency: Your companions' basic attack and defense values are 25% more effective across all combat calculations (rounded up).",
    },
    ["DRUID"] = {
        id = "DRUID",
        name = "Wild Symbiosis",
        icon = "Interface\\Icons\\Ability_Druid_Flourish",
        desc = "Accelerated Evolution & Bonding: Attunement rewards are increased by 25% (rounded up), and Attunement rank thresholds are reduced by 25% (rounded up).",
    },
    ["WARLOCK"] = {
        id = "WARLOCK",
        name = "Curse of Suppression",
        icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",
        desc = "Opposed Bonus Sabotage: When battling rival AI trainers or dueling players (/fsduel), passively decreases all opposed class bonuses by 50% (rounded up).",
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

-- Check if opponent is Warlock, reducing passive effectiveness by 50%
function CP:GetSuppressionMultiplier(opponentClass)
    if opponentClass and string.upper(opponentClass) == "WARLOCK" then
        return 0.5
    end
    return 1.0
end

-- 🛡️ Warrior: Physical Damage Mitigation
function CP:CalculatePhysicalDamageReduction(dmg, playerClass, opponentClass)
    if playerClass ~= "WARRIOR" or not dmg or dmg <= 0 then return 0 end
    local mult = 0.25 * self:GetSuppressionMultiplier(opponentClass)
    return math.ceil(dmg * mult)
end

-- 🛡️ Paladin: Damage-to-Healing Conversion
function CP:CalculatePaladinHealback(dmg, playerClass, opponentClass)
    if playerClass ~= "PALADIN" or not dmg or dmg <= 0 then return 0 end
    local mult = 0.25 * self:GetSuppressionMultiplier(opponentClass)
    return math.ceil(dmg * mult)
end

-- ⚡ Shaman: Primal Rebirth (Roll 50% revive at 50% max HP)
function CP:CanShamanRevive(playerClass, hasUsedRevive, opponentClass)
    if playerClass ~= "SHAMAN" or hasUsedRevive then return false, 0 end
    local chance = 50 * self:GetSuppressionMultiplier(opponentClass)
    local roll = math.random(1, 100)
    if roll <= chance then
        return true
    end
    return false
end

-- 🔮 Mage: Non-physical Damage Mitigation (Fire, Frost, Shadow, Nature, Arcane, Magic)
function CP:CalculateMageSpellReduction(dmg, element, playerClass, opponentClass)
    if playerClass ~= "MAGE" or not dmg or dmg <= 0 then return 0 end
    if element == "Physical" or element == "Normal" then return 0 end
    local mult = 0.25 * self:GetSuppressionMultiplier(opponentClass)
    return math.ceil(dmg * mult)
end

-- 🔮 Mage: Speed Suppression Duration (Rank turns)
function CP:GetMageSlowDuration(rank, opponentClass)
    local base = math.max(1, tonumber(rank) or 1)
    if opponentClass and string.upper(opponentClass) == "WARLOCK" then
        return math.max(1, math.ceil(base * 0.5))
    end
    return base
end

-- 🗡️ Rogue: Evasion Miss Bonus (+25% miss chance on attacker)
function CP:GetRogueMissBonus(playerClass, opponentClass)
    if playerClass ~= "ROGUE" then return 0 end
    local bonus = 25 * self:GetSuppressionMultiplier(opponentClass)
    return math.ceil(bonus)
end

-- 🌿 Priest: Divine Grace Max Uses (equal to Attunement Rank)
function CP:GetPriestMaxHeals(rank, playerClass, opponentClass)
    if playerClass ~= "PRIEST" then return 0 end
    local base = math.max(1, tonumber(rank) or 1)
    if opponentClass and string.upper(opponentClass) == "WARLOCK" then
        return math.max(1, math.ceil(base * 0.5))
    end
    return base
end

function CP:GetPriestHealAmount(maxHP, playerClass, opponentClass)
    if playerClass ~= "PRIEST" or not maxHP or maxHP <= 0 then return 0 end
    local mult = 0.25 * self:GetSuppressionMultiplier(opponentClass)
    return math.ceil(maxHP * mult)
end

-- 🏹 Hunter: Basic Attack & Defense Efficiency (+25%)
function CP:ApplyHunterStatBonus(statVal, statType, playerClass, opponentClass)
    if playerClass ~= "HUNTER" or not statVal or statVal <= 0 then return statVal end
    if statType == "atk" or statType == "def" then
        local bonus = 0.25 * self:GetSuppressionMultiplier(opponentClass)
        return statVal + math.ceil(statVal * bonus)
    end
    return statVal
end

-- 🍃 Druid: Wild Symbiosis Attunement Boost (+25%)
function CP:ApplyDruidAttunementGain(gain, playerClass)
    if playerClass ~= "DRUID" or not gain or gain <= 0 then return gain end
    return gain + math.ceil(gain * 0.25)
end

-- 🍃 Druid: Rank Threshold Discount (-25%)
function CP:GetDruidRankThreshold(baseThreshold, playerClass)
    if playerClass ~= "DRUID" or not baseThreshold or baseThreshold <= 0 then return baseThreshold end
    return math.max(1, math.ceil(baseThreshold * 0.75))
end
