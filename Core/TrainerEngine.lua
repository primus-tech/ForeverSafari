--[[
    Forever Safari: Core Engine - NPC Rival Battler Engine (TrainerEngine.lua)
    Inspects targeted humanoid NPC mobs, resolves their faction/lore archetype,
    and dynamically constructs 1-to-3 companion battle rosters for roaming AI trainer battles.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.TrainerEngine = ns.TrainerEngine or {}

local TE = ns.TrainerEngine
local C = ns.Constants
local SE = ns.StatEngine
local TrainerDB = ns.TrainerDB

local function isSecret(v)
    if v == nil then return false end
    if issecretpassphrase and issecretpassphrase(v) then return true end
    if type(v) == "userdata" or type(v) == "table" then
        local mt = getmetatable(v)
        if mt and type(mt) == "string" and mt == "secret" then return true end
    end
    return false
end

function TE:IsHumanoidTrainer(unit)
    unit = unit or "target"
    if not UnitExists(unit) or UnitIsDead(unit) or UnitIsPlayer(unit) then
        return false
    end

    local rawType = UnitCreatureType(unit)
    if not isSecret(rawType) and rawType == "Humanoid" then
        return true
    end

    -- Name-based fallback for classic clients
    local name = UnitName(unit)
    if name and not isSecret(name) and type(name) == "string" then
        local lower = string.lower(name)
        if string.find(lower, "defias") or string.find(lower, "murloc") or string.find(lower, "kobold")
            or string.find(lower, "gnoll") or string.find(lower, "centaur") or string.find(lower, "scarlet")
            or string.find(lower, "dark iron") or string.find(lower, "pirate") or string.find(lower, "syndicate")
            or string.find(lower, "trogg") or string.find(lower, "cultist") or string.find(lower, "ogre") then
            return true
        end
    end

    return false
end

function TE:GenerateTrainerMatch(unit)
    unit = unit or "target"
    local unitName = UnitName(unit)
    if isSecret(unitName) or not unitName or unitName == "" or type(unitName) ~= "string" then unitName = "Rival Hunter" end

    local rawType = UnitCreatureType(unit)
    if isSecret(rawType) or not rawType or rawType == "" or type(rawType) ~= "string" then rawType = "Humanoid" end

    local level = UnitLevel(unit)
    if isSecret(level) or not level or level <= 0 or type(level) ~= "number" then level = 10 end

    local zoneName = GetZoneText and GetZoneText()
    if isSecret(zoneName) or not zoneName then zoneName = "Azeroth" end

    local archetype = (TrainerDB and TrainerDB.GetArchetypeForUnit) and TrainerDB:GetArchetypeForUnit(unitName, rawType, zoneName) or (TrainerDB and TrainerDB.ARCHETYPES and TrainerDB.ARCHETYPES["Default"])

    -- Determine team size based on NPC level
    local teamSize = 1
    if level >= 36 then
        teamSize = 3
    elseif level >= 16 then
        teamSize = 2
    end

    local pool = archetype.pool or {}
    local team = {}

    for i = 1, teamSize do
        local templateIdx = ((i - 1) % #pool) + 1
        local petTpl = pool[templateIdx] or pool[1]

        local baseStats = petTpl.baseStats or { hp = 40, atk = 22, def = 18, spd = 20 }
        local stats = SE:CalculateStats(petTpl.element or "Beast", 0, false, baseStats)

        local companion = {
            id = string.format("npc_trainer_pet_%d_%d", time(), i),
            name = petTpl.name,
            nickname = petTpl.name,
            customNickname = petTpl.name,
            family = petTpl.family or "Beast",
            element = petTpl.element or "Beast",
            creatureType = petTpl.element or "Beast",
            displayId = petTpl.displayId or 903,
            level = level,
            maxHP = stats.maxHP,
            currentHP = stats.maxHP,
            hp = stats.maxHP,
            attack = stats.atk,
            atk = stats.atk,
            defense = stats.def,
            def = stats.def,
            speed = stats.spd,
            spd = stats.spd,
            moves = { petTpl.moves[1] or 101, petTpl.moves[2] or 102 },
            attunementRank = 1,
            isTrainerPet = true,
        }

        table.insert(team, companion)
    end

    return {
        isTrainer = true,
        trainerName = unitName,
        trainerTitle = archetype.title or "Safari Rival",
        introQuote = archetype.intro or "Let's battle!",
        defeatQuote = archetype.defeat or "Well played...",
        tokenReward = (archetype.tokenReward or 8) + math.floor(level / 5),
        team = team,
        activeSlot = 1,
    }
end
