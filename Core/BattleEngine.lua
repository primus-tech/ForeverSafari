--[[
    Forever Safari: Battle Engine
    Turn-based combat simulation for battles against wild beasts, trainers, or other players.
    Governed by:
    - 4 Core Stats: Health, Attack, Defense, Speed
    - 9 Pet Types with passive traits & 150% closed-loop advantages
    - Ability Cooldowns (turns) and Limited Usages per battle
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.BattleEngine = ns.BattleEngine or {}

local BE = ns.BattleEngine
local C = ns.Constants
local DB = ns.Database
local SE = ns.StatEngine

local function isSecret(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return true end
    if issecretpassphrase and issecretpassphrase(v) then return true end
    if issecretvariable and issecretvariable(v) then return true end
    local ok = pcall(function() local _ = (v == "") end)
    if not ok then return true end
    return false
end

BE.State = {
    inBattle = false,
    playerMob = nil,
    enemyMob = nil,
    isPvP = false,
    isTrainerBattle = false,
    isOutpostBattle = false,
    outpostData = nil,
    turn = "player", -- "player" or "enemy"
    forcedSwitch = false,
    round = 1,
    turnCount = 0,
    actionMeters = {
        player = 0,
        enemy = 0,
    },
    buffs = {
        player = {},
        enemy = {},
    },
    passives = {
        dragonkinEnraged = { player = false, enemy = false },
        mechanicalRevived = { player = false, enemy = false },
        undeadImmortal = { player = 0, enemy = 0 },
        undeadTriggered = { player = false, enemy = false },
    },
    moveState = {
        player = {}, -- [moveKey] = { currentCD = 0, usesLeft = X }
        enemy = {},  -- [moveKey] = { currentCD = 0, usesLeft = X }
    },
    druidEclipse = {
        solar = 0,
        lunar = 0,
        hotTurns = 0,
        hotAmount = 0,
        brambleTurns = 0,
        bramblePercent = 0,
        bramblePoints = 0,
    },
    logs = {},
    dialogueText = "What will you do?",
}

-- Calculate effective speed considering Flying passive (+50% speed above 50% HP) and temporary spd buffs/debuffs
function BE:GetEffectiveSpeed(mob, side)
    if not mob then return 10 end
    local spd = mob.spd or 10
    if mob.creatureType == "Flying" and ((mob.currentHP or 0) / (mob.maxHP or 1)) >= 0.50 then
        spd = math.floor(spd * 1.50)
    end
    if side and BE.State.buffs and BE.State.buffs[side] and BE.State.buffs[side].spd then
        local mult = BE.State.buffs[side].spd.multiplier or 1.0
        spd = math.floor(spd * mult)
    end
    return math.max(1, spd)
end

-- Helper: Get dynamic Layer 1-5 resistances for a combatant
function BE:GetEffectiveResistances(mob, side)
    if not mob then
        return { physical = 0, fire = 0, frost = 0, nature = 0, arcane = 0, shadow = 0, holy = 0, dodge = 5, crit = 5, deflection = 0 }
    end
    local CP = ns.ClassPassives
    local pClass = nil
    if side == "player" then
        pClass = CP and CP:GetPlayerClass()
    elseif side == "enemy" then
        pClass = BE.State.opponentClass
    end
    local rank = mob.attunementRank or mob.rank or 1
    if SE and SE.CalculateResistances then
        return SE:CalculateResistances(mob, pClass, rank)
    end
    return { physical = 0, fire = 0, frost = 0, nature = 0, arcane = 0, shadow = 0, holy = 0, dodge = 5, crit = 5, deflection = 0 }
end

-- Helper: Resolve ability data directly from MoveDB
function BE:GetMoveData(moveKey)
    if not moveKey then return nil end
    local MoveDB = ns.MoveDB
    if not MoveDB then return nil end
    local numKey = tonumber(moveKey)
    if numKey and MoveDB[numKey] then
        return MoveDB[numKey]
    end
    if MoveDB[moveKey] then
        return MoveDB[moveKey]
    end
    return nil
end

-- Initialize move cooldowns & battle usages for a participant
function BE:InitMoveStates(mob, side)
    BE.State.moveState[side] = {}
    local moveList = mob.abilities or mob.moves or { "Tackle" }
    for _, moveKey in ipairs(moveList) do
        local m = BE:GetMoveData(moveKey)
        if m then
            BE.State.moveState[side][moveKey] = {
                currentCD = 0,
                usesLeft = m.maxUses or m.pp or 10,
                maxUses = m.maxUses or m.pp or 10,
                cooldown = m.cooldown or 0,
            }
        end
    end
end

-- Tick down cooldowns at end of round
function BE:TickCooldowns(side)
    local state = BE.State.moveState[side]
    if not state then return end
    for moveKey, data in pairs(state) do
        if data.currentCD > 0 then
            data.currentCD = data.currentCD - 1
        end
    end
end

-- Process turn-start ticks for acting combatant: cooldowns, HoTs, DoTs, and Buff decay
function BE:TickCombatantTurn(side)
    local mob = (side == "player") and BE.State.playerMob or BE.State.enemyMob
    local buffs = BE.State.buffs[side]
    if not mob or (mob.currentHP or 0) <= 0 or not buffs then return end

    -- Decrement move cooldowns for acting combatant
    BE:TickCooldowns(side)

    -- 1. HoT (Heal over Time, e.g. Frenzied Regeneration)
    if buffs.hot then
        local healAmount = math.max(1, math.floor(mob.maxHP * (buffs.hot.healPercent or 0.15)))
        mob.currentHP = math.min(mob.maxHP, mob.currentHP + healAmount)
        local mName = (side == "player" and mob.nickname ~= "" and mob.nickname) or mob.name
        BE:AddLog(string.format("|cff00ff99[Regeneration]|r %s restored %d HP! (%d rounds left)", mName, healAmount, buffs.hot.duration - 1))
        buffs.hot.duration = buffs.hot.duration - 1
        if buffs.hot.duration <= 0 then
            buffs.hot = nil
        end
    end

    -- 2. 🍃 Druid Class Passive: Ecliptic Tides HoT (Rejuvenating Bloom) & Brambles Decay
    if side == "player" then
        local eclipse = BE.State.druidEclipse
        if eclipse then
            if (eclipse.hotTurns or 0) > 0 and (mob.currentHP or 0) > 0 then
                local healAmount = eclipse.hotAmount or 0
                mob.currentHP = math.min(mob.maxHP, mob.currentHP + healAmount)
                local mName = (mob.nickname ~= "" and mob.nickname) or mob.name
                BE:AddLog(string.format("|cff00ff99[Solar Surge: Rejuvenating Bloom]|r %s restored %d HP! (%d rounds remaining)", mName, healAmount, eclipse.hotTurns - 1))
                eclipse.hotTurns = eclipse.hotTurns - 1
                if eclipse.hotTurns <= 0 then
                    eclipse.hotAmount = 0
                end
            end
            if (eclipse.brambleTurns or 0) > 0 then
                eclipse.brambleTurns = eclipse.brambleTurns - 1
                if eclipse.brambleTurns <= 0 then
                    eclipse.bramblePercent = 0
                    eclipse.bramblePoints = 0
                end
            end
        end
    end

    -- 3. Periodic DoTs with independent per-tick resistance & ward proc evaluation
    if buffs.dots and #buffs.dots > 0 then
        local CP = ns.ClassPassives
        local sideClass = (side == "player") and (CP and CP:GetPlayerClass()) or BE.State.opponentClass
        local rank = mob.attunementRank or mob.rank or 1
        local dStats = BE:GetEffectiveResistances(mob, side)
        local remainingDots = {}

        for _, dot in ipairs(buffs.dots) do
            local school = dot.school or "physical"
            local resistPct = dStats[school] or 0
            local tickDmg = math.max(1, dot.damage - math.floor(dot.damage * (resistPct / 100)))

            -- Independent Per-Tick Procced Ward Roll
            if CP and CP.RollWardProc then
                local wProcced, wAbsorbPct, wWardName = CP:RollWardProc(sideClass, school, rank)
                if wProcced then
                    local absorbed = math.max(1, math.floor(tickDmg * (wAbsorbPct / 100)))
                    tickDmg = math.max(0, tickDmg - absorbed)
                    BE:AddLog(string.format("|cffcc99ff[%s]|r Absorbed %d periodic damage on %s (%d%% ward)!|r", wWardName, absorbed, mob.name, wAbsorbPct))
                end
            end

            -- Apply damage (respecting Undead immortality)
            if BE.State.passives.undeadImmortal[side] > 0 then
                mob.currentHP = 1
            else
                mob.currentHP = math.max(0, mob.currentHP - tickDmg)
            end

            local mName = (side == "player" and mob.nickname ~= "" and mob.nickname) or mob.name
            BE:AddLog(string.format("|cffff6666[%s Tick]|r %s took %d periodic damage! (%d ticks left)|r", dot.name, mName, tickDmg, dot.duration - 1))

            dot.duration = dot.duration - 1
            if dot.duration > 0 and mob.currentHP > 0 then
                table.insert(remainingDots, dot)
            end

            if mob.currentHP <= 0 then
                break
            end
        end
        buffs.dots = remainingDots
    end

    -- 4. Bleed Vulnerability decay
    if buffs.bleedVuln then
        buffs.bleedVuln.turns = (buffs.bleedVuln.turns or 1) - 1
        if buffs.bleedVuln.turns <= 0 then
            buffs.bleedVuln = nil
        end
    end

    -- 5. Stat Buffs / Debuffs decay
    for _, statKey in ipairs({ "atk", "def", "spd" }) do
        if buffs[statKey] and buffs[statKey].turns then
            buffs[statKey].turns = buffs[statKey].turns - 1
            if buffs[statKey].turns <= 0 then
                buffs[statKey] = nil
            end
        end
    end
end

-- Backward-compatible wrapper for external round ticks
function BE:TickRoundBuffsAndHoTs()
    BE:TickCombatantTurn("player")
    BE:TickCombatantTurn("enemy")
end

-- Advance to next turn using the Action-Gauge 0-100 Speed Engine (with authentic 2:1 lapping)
function BE:AdvanceToNextTurn()
    if not BE.State.inBattle then return end
    local player = BE.State.playerMob
    local enemy = BE.State.enemyMob
    if not player or not enemy or (player.currentHP or 0) <= 0 or (enemy.currentHP or 0) <= 0 then return end

    local pSpd = BE:GetEffectiveSpeed(player, "player")
    local eSpd = BE:GetEffectiveSpeed(enemy, "enemy")
    local meters = BE.State.actionMeters
    if not meters then
        meters = { player = 0, enemy = 0 }
        BE.State.actionMeters = meters
    end

    -- Accumulate speed velocity into action meters until at least one reaches 100
    while meters.player < 100 and meters.enemy < 100 do
        meters.player = meters.player + pSpd
        meters.enemy = meters.enemy + eSpd
    end

    local nextTurn
    if meters.player >= 100 and meters.enemy >= 100 then
        -- Tie-breaker: higher effective speed acts first; secondary tie goes to player
        if pSpd >= eSpd then
            nextTurn = "player"
            meters.player = meters.player - 100
        else
            nextTurn = "enemy"
            meters.enemy = meters.enemy - 100
        end
    elseif meters.player >= 100 then
        nextTurn = "player"
        meters.player = meters.player - 100
    else
        nextTurn = "enemy"
        meters.enemy = meters.enemy - 100
    end

    BE.State.turn = nextTurn
    BE.State.turnCount = (BE.State.turnCount or 0) + 1
    BE.State.round = math.floor(((BE.State.turnCount or 1) - 1) / 2) + 1

    -- Process cooldowns, HoTs, DoTs, and buff decay for the acting combatant
    BE:TickCombatantTurn(nextTurn)

    -- Check if combatant fainted from turn-start effects (e.g. DoT)
    if (player.currentHP or 0) <= 0 then
        if not BE:CheckDefeatPassives(player, "player") then
            BE:HandlePlayerFaint()
            return
        end
    end
    if (enemy.currentHP or 0) <= 0 then
        if not BE:CheckDefeatPassives(enemy, "enemy") then
            BE:HandleEnemyFaint()
            return
        end
    end

    if nextTurn == "player" then
        local pName = (player.nickname ~= "" and player.nickname) or player.name
        BE.State.dialogueText = string.format("What will %s do?", pName)
        if ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:UpdateUI()
        end
    else
        BE.State.dialogueText = string.format("Wild %s is preparing an attack...", enemy.name)
        if ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:UpdateUI()
        end
        C_Timer.After(1.2, function()
            BE:ExecuteEnemyTurn()
        end)
    end
end

-- Cleanse 1 active negative status/debuff effect from player companion
function BE:CleansePlayerDebuff()
    if BE.State.buffs.player and BE.State.buffs.player.sleep then
        BE.State.buffs.player.sleep = nil
        return "Sleep"
    end
    if BE.State.flinch and BE.State.flinch.player then
        BE.State.flinch.player = false
        return "Flinch"
    end
    if BE.State.buffs.player and BE.State.buffs.player.bleedVuln then
        BE.State.buffs.player.bleedVuln = nil
        return "Bleed Vulnerability"
    end
    if BE.State.buffs.player then
        for _, stat in ipairs({ "atk", "def", "spd" }) do
            if BE.State.buffs.player[stat] and (BE.State.buffs.player[stat].multiplier or 1.0) < 1.0 then
                BE.State.buffs.player[stat] = nil
                return string.upper(stat) .. " Reduction"
            end
        end
    end
    return nil
end

-- Check if player has any conscious companion on team
function BE:HasConsciousTeamMember()
    local team = DB:GetTeam()
    for _, mobId in ipairs(team) do
        local mob = type(mobId) == "table" and mobId or DB:GetMobById(mobId)
        if mob and (mob.currentHP or 0) > 0 then
            return true
        end
    end
    return false
end

-- Handle Player Companion Faint
function BE:HandlePlayerFaint()
    local player = BE.State.playerMob
    local pName = (player and player.nickname ~= "" and player.nickname) or (player and player.name) or "Your companion"
    if player then
        player.currentHP = 0
    end

    if not BE:HasConsciousTeamMember() then
        BE:HandleDefeat()
        return
    end

    BE.State.forcedSwitch = true
    BE.State.turn = "player"
    BE.State.dialogueText = string.format("%s fainted! Choose your next companion!", pName)
    BE:AddLog(string.format("|cffff4444%s fainted! Choose your next companion!|r", pName))
    PlaySound(847)

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:SetMenuMode("PARTY")
        ForeverSafari.BattleFrame:UpdateUI()
    end
end

-- Handle Enemy Companion Faint (PvE ends immediately; Trainer switches; PvP prompts for next mob)
function BE:HandleEnemyFaint()
    local enemy = BE.State.enemyMob
    local eName = enemy and enemy.name or "Enemy target"
    if enemy then enemy.currentHP = 0 end

    -- 1. AI Trainer Battle: Check if trainer has remaining bench companions
    if BE.State.isTrainerBattle and BE.State.enemyTeam then
        local nextSlot = nil
        for slotIdx, mob in ipairs(BE.State.enemyTeam) do
            if (mob.currentHP or 0) > 0 then
                nextSlot = slotIdx
                break
            end
        end

        if nextSlot then
            local nextMob = BE.State.enemyTeam[nextSlot]
            BE.State.enemyActiveSlot = nextSlot
            BE.State.enemyMob = nextMob
            BE:InitMoveStates(nextMob, "enemy")

            local trainerTitle = BE.State.enemyTrainer and BE.State.enemyTrainer.trainerTitle or "Rival Trainer"
            BE.State.dialogueText = string.format("%s sent out %s!", trainerTitle, nextMob.name)
            local nRank = nextMob.attunementRank or nextMob.rank or 1
            local nRoman = type(nRank) == "number" and (C.ATTUNEMENT_RANKS[nRank] and C.ATTUNEMENT_RANKS[nRank].roman or "I") or tostring(nRank)
            BE:AddLog(string.format("|cffff6666%s sent out %s (Rank %s %s)!|r", trainerTitle, nextMob.name, nRoman, nextMob.creatureType))

            if ForeverSafari.BattleFrame then
                ForeverSafari.BattleFrame:UpdateModels()
                ForeverSafari.BattleFrame:UpdateUI()
            end
            return
        end

        -- All trainer companions defeated: Victory!
        BE:HandleVictory()
        return
    end

    -- 2. PvE Wild / Dungeon Encounter: Battle ends immediately with Victory!
    if not BE.State.isPvP then
        BE:HandleVictory()
        return
    end

    -- 3. PvP Duel: Check if opponent has remaining conscious team members
    local hasRemaining = false
    if BE.State.enemyTeam then
        for _, mob in ipairs(BE.State.enemyTeam) do
            if (mob.currentHP or 0) > 0 then
                hasRemaining = true
                break
            end
        end
    end

    if not hasRemaining then
        -- All opponent companions fainted: Victory!
        BE:HandleVictory()
        return
    end

    -- Opponent has remaining companions: Prompt for their next companion
    BE.State.turn = "enemy"
    BE.State.dialogueText = string.format("Opponent's %s fainted! Waiting for opponent's next companion...", eName)
    BE:AddLog(string.format("|cffff4444Opponent's %s fainted! Waiting for opponent to switch...|r", eName))

    if ForeverSafari.Comms and BE.State.opponentName then
        ForeverSafari.Comms:SendMessage("OPPONENT_FAINTED", "", BE.State.opponentName)
    end

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:UpdateUI()
    end
end

-- Switch enemy companion during PvP duel
function BE:SwitchEnemyMob(newMob)
    if not BE.State.inBattle or not BE.State.isPvP then return end
    if not newMob or (newMob.currentHP or 0) <= 0 then return end

    BE.State.enemyMob = newMob
    BE:InitMoveStates(newMob, "enemy")

    local eName = newMob.nickname ~= "" and newMob.nickname or newMob.name
    BE.State.dialogueText = string.format("Opponent sent out %s!", eName)
    local eRank = newMob.attunementRank or newMob.rank or 1
    local eRoman = type(eRank) == "number" and (C.ATTUNEMENT_RANKS[eRank] and C.ATTUNEMENT_RANKS[eRank].roman or "I") or tostring(eRank)
    BE:AddLog(string.format("Opponent sent out |cffff6666%s|r (Rank %s %s)!", eName, eRoman, newMob.creatureType))

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:UpdateModels()
        ForeverSafari.BattleFrame:UpdateUI()
    end

    BE.State.turn = "player"
end

-- Start a Wild Battle against targeted unit or generated mob
function BE:StartWildBattle(unit)
    unit = unit or "target"

    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType and instanceType ~= "none" then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Safari battles cannot be initiated inside instances, raids, or battlegrounds! Defeat mobs here for a chance at companion pup drops.|r")
        return false
    end

    local activeMob = DB:GetActiveMob()
    if not activeMob then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444You have no active companion ready for battle! Open your Field Guide to set one.|r")
        return false
    end

    if (activeMob.currentHP or 0) <= 0 then
        -- Attempt to auto-promote first conscious team member
        local team = DB:GetTeam()
        local foundConscious = nil
        for slotIdx, mobId in ipairs(team) do
            local mob = type(mobId) == "table" and mobId or DB:GetMobById(mobId)
            if mob and (mob.currentHP or 0) > 0 then
                foundConscious = mob
                DB:SetActiveSlot(slotIdx)
                activeMob = mob
                break
            end
        end
        if not foundConscious then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444All companions in your party have fainted! Visit an Innkeeper to revive and heal your squad, or use a Revival Crystal.|r")
            return false
        end
    end

    local name = UnitName(unit)
    if isSecret(name) or not name or name == "" then name = "Wild Creature" end

    local rawType = UnitCreatureType(unit)
    if isSecret(rawType) or not rawType or rawType == "" then rawType = "Beast" end

    local level = UnitLevel(unit)
    if isSecret(level) or not level or type(level) ~= "number" or level <= 0 then level = activeMob.level or 1 end

    local isElite = false
    local classification = UnitClassification(unit)
    if not isSecret(classification) and (classification == "elite" or classification == "rareelite") then
        isElite = true
    end

    local outpost = ns.OutpostDB and ns.OutpostDB:GetOutpostByUnit(unit)
    if outpost then
        return BE:StartOutpostBattle(unit, outpost)
    end

    local isTrainer = ns.TrainerEngine and ns.TrainerEngine:IsHumanoidTrainer(unit)
    if isTrainer then
        -- 🔒 Roaming AI Trainer GUID Anti-Farm Lockout (24-hour defeat cooldown)
        local guid = UnitGUID(unit)
        if guid and ForeverSafariDB and ForeverSafariDB.defeatedTrainers and ForeverSafariDB.defeatedTrainers[guid] then
            local lastDefeated = ForeverSafariDB.defeatedTrainers[guid]
            if (time() - lastDefeated) < 86400 then
                if ForeverSafari.Toast then
                    ForeverSafari.Toast:ShowAlert("Trainer Resting", "This trainer was recently bested and is resting their team. Return tomorrow!")
                else
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffffaa00This trainer was recently bested and is resting their team. Return tomorrow!|r", C.PREFIX or "[Safari] "))
                end
                return
            end
        end

        local match = ns.TrainerEngine:GenerateTrainerMatch(unit)
        local enemyMob = match.team[1]

        BE.State.inBattle = true
        BE.State.isTrainerBattle = true
        BE.State.enemyTrainer = match
        BE.State.enemyTrainerGUID = guid
        BE.State.enemyTeam = match.team
        BE.State.enemyActiveSlot = 1
        BE.State.playerMob = activeMob
        BE.State.enemyMob = enemyMob
        BE.State.isPvP = false
        BE.State.round = 1
        BE.State.buffs.player = {}
        BE.State.buffs.enemy = {}
        BE.State.passives.dragonkinEnraged = { player = false, enemy = false }
        BE.State.passives.mechanicalRevived = { player = false, enemy = false }
        BE.State.passives.undeadImmortal = { player = 0, enemy = 0 }
        BE.State.passives.undeadTriggered = { player = false, enemy = false }
        BE.State.shamanRevived = false
        BE.State.priestHealUses = 0
        BE.State.opponentClass = match.trainerClass
        BE.State.druidEclipse = {
            solar = 0,
            lunar = 0,
            hotTurns = 0,
            hotAmount = 0,
            brambleTurns = 0,
            bramblePercent = 0,
            bramblePoints = 0,
        }

        -- Initialize Move Cooldowns & Limits
        BE:InitMoveStates(activeMob, "player")
        BE:InitMoveStates(enemyMob, "enemy")

        BE.State.logs = {}
        local trainerTitle = match.trainerTitle or "Rival Trainer"
        BE.State.dialogueText = string.format("%s: \"%s\"", trainerTitle, match.introQuote or "Let's battle!")

        BE.State.actionMeters = { player = 0, enemy = 0 }
        BE.State.turnCount = 0

        BE:AddLog(string.format("|cffffcc00[Trainer Battle]|r %s challenged you to a battle!", trainerTitle))
        BE:AddLog(string.format("|cffffd100%s: \"%s\"|r", trainerTitle, match.introQuote or "Let's battle!"))
        local emRank = enemyMob.attunementRank or enemyMob.rank or 1
        local emRoman = type(emRank) == "number" and (C.ATTUNEMENT_RANKS[emRank] and C.ATTUNEMENT_RANKS[emRank].roman or "I") or tostring(emRank)
        BE:AddLog(string.format("|cffff6666%s sent out %s (Rank %s %s)!|r", trainerTitle, enemyMob.name, emRoman, enemyMob.creatureType))

        if ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:ShowBattle()
        end

        C_Timer.After(1.0, function()
            BE:AdvanceToNextTurn()
        end)

        return true
    end

    local displayId = C.GetDefaultDisplayId(rawType, name)

    local enemyMob = SE:CreateMobInstance(name, rawType, level, isElite, displayId)

    BE.State.inBattle = true
    BE.State.isTrainerBattle = false
    BE.State.enemyTrainer = nil
    BE.State.enemyTeam = nil
    BE.State.playerMob = activeMob
    BE.State.enemyMob = enemyMob
    BE.State.isPvP = false
    BE.State.round = 1
    BE.State.buffs.player = {}
    BE.State.buffs.enemy = {}
    BE.State.passives.dragonkinEnraged = { player = false, enemy = false }
    BE.State.passives.mechanicalRevived = { player = false, enemy = false }
    BE.State.passives.undeadImmortal = { player = 0, enemy = 0 }
    BE.State.passives.undeadTriggered = { player = false, enemy = false }
    BE.State.shamanRevived = false
    BE.State.priestHealUses = 0
    BE.State.opponentClass = nil
    BE.State.druidEclipse = {
        solar = 0,
        lunar = 0,
        hotTurns = 0,
        hotAmount = 0,
        brambleTurns = 0,
        bramblePercent = 0,
        bramblePoints = 0,
    }
    
    -- Initialize Move Cooldowns & Limits
    BE:InitMoveStates(activeMob, "player")
    BE:InitMoveStates(enemyMob, "enemy")

    BE.State.logs = {}
    BE.State.dialogueText = string.format("A wild %s appeared!", enemyMob.name)

    BE.State.actionMeters = { player = 0, enemy = 0 }
    BE.State.turnCount = 0

    local emRank = enemyMob.attunementRank or enemyMob.rank or 1
    local emRoman = type(emRank) == "number" and (C.ATTUNEMENT_RANKS[emRank] and C.ATTUNEMENT_RANKS[emRank].roman or "I") or tostring(emRank)
    BE:AddLog(string.format("|cffffff00Wild %s (Rank %s %s) appeared!|r", enemyMob.name, emRoman, enemyMob.creatureType))

    -- Bestiary / Pokédex Encounter Discovery
    if DB and DB.DiscoverSpecies then
        DB:DiscoverSpecies(enemyMob.name, "seen")
    end

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:ShowBattle()
    end

    C_Timer.After(1.0, function()
        BE:AdvanceToNextTurn()
    end)

    return true
end

-- Start a sanctioned Outpost Battle against a certified Stable Master Outpost Leader
function BE:StartOutpostBattle(unit, outpost)
    unit = unit or "target"
    outpost = outpost or (ns.OutpostDB and ns.OutpostDB:GetOutpostByUnit(unit))
    if not outpost then return false end

    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType and instanceType ~= "none" and outpost.zone ~= "Naxxramas" and outpost.zone ~= "Alterac Valley" then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Safari outpost battles cannot be initiated inside standard instances!|r")
        return false
    end

    local activeMob = DB:GetActiveMob()
    if not activeMob then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444You have no active companion ready for battle! Open your Field Guide to set one.|r")
        return false
    end

    if (activeMob.currentHP or 0) <= 0 then
        local team = DB:GetTeam()
        local foundConscious = nil
        for slotIdx, mobId in ipairs(team) do
            local mob = type(mobId) == "table" and mobId or DB:GetMobById(mobId)
            if mob and (mob.currentHP or 0) > 0 then
                foundConscious = mob
                DB:SetActiveSlot(slotIdx)
                activeMob = mob
                break
            end
        end
        if not foundConscious then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444All companions in your party have fainted! Visit an Innkeeper to revive and heal your squad, or use a Revival Crystal.|r")
            return false
        end
    end

    local match = ns.OutpostDB:GenerateOutpostMatch(outpost)
    if not match or not match.team or #match.team == 0 then return false end

    local enemyMob = match.team[1]

    BE.State.inBattle = true
    BE.State.isTrainerBattle = true
    BE.State.isOutpostBattle = true
    BE.State.outpostData = outpost
    BE.State.enemyTrainer = match
    BE.State.enemyTrainerGUID = UnitGUID(unit)
    BE.State.enemyTeam = match.team
    BE.State.enemyActiveSlot = 1
    BE.State.playerMob = activeMob
    BE.State.enemyMob = enemyMob
    BE.State.isPvP = false
    BE.State.round = 1
    BE.State.buffs.player = {}
    BE.State.buffs.enemy = {}
    BE.State.passives.dragonkinEnraged = { player = false, enemy = false }
    BE.State.passives.mechanicalRevived = { player = false, enemy = false }
    BE.State.passives.undeadImmortal = { player = 0, enemy = 0 }
    BE.State.passives.undeadTriggered = { player = false, enemy = false }
    BE.State.shamanRevived = false
    BE.State.priestHealUses = 0
    BE.State.opponentClass = nil
    BE.State.druidEclipse = {
        solar = 0,
        lunar = 0,
        hotTurns = 0,
        hotAmount = 0,
        brambleTurns = 0,
        bramblePercent = 0,
        bramblePoints = 0,
    }

    -- Initialize Move Cooldowns & Limits
    BE:InitMoveStates(activeMob, "player")
    BE:InitMoveStates(enemyMob, "enemy")

    BE.State.logs = {}
    BE.State.dialogueText = string.format("%s: \"%s\"", outpost.name, match.introQuote or "Let's battle!")
    BE.State.actionMeters = { player = 0, enemy = 0 }
    BE.State.turnCount = 0

    local badgeName = outpost.badge and outpost.badge.name or "Outpost Badge"
    BE:AddLog(string.format("|cffffcc00[Outpost League]|r Challenged Outpost Leader |cffffffff%s|r (%s)!", outpost.name, outpost.location or outpost.zone))
    BE:AddLog(string.format("|cffffd100%s: \"%s\"|r", outpost.name, match.introQuote or "Let's battle!"))
    BE:AddLog(string.format("|cff00ff99Regional Badge on the line: [%s]|r", badgeName))
    BE:AddLog(string.format("|cffff6666%s sent out %s (Rank %s %s)!|r", outpost.name, enemyMob.name, enemyMob.rankRoman or outpost.rankRoman or "I", enemyMob.creatureType))

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:ShowBattle()
    end

    C_Timer.After(1.0, function()
        BE:AdvanceToNextTurn()
    end)

    return true
end

function BE:AddLog(msg)
    table.insert(BE.State.logs, msg)
    if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame:IsShown() then
        ForeverSafari.BattleFrame:UpdateLog()
    end
end

-- Execute Player Selected Move
function BE:ExecutePlayerMove(moveKey)
    if not BE.State.inBattle or BE.State.turn ~= "player" then return end

    local move = BE:GetMoveData(moveKey)
    if not move then return end

    local player = BE.State.playerMob
    local enemy = BE.State.enemyMob
    local moveData = BE.State.moveState.player[moveKey]

    -- Cooldown & Uses Check
    if not moveData or moveData.usesLeft <= 0 then
        BE.State.dialogueText = string.format("No uses left for %s in this battle!", move.name)
        BE:AddLog(string.format("|cffff4444%s is exhausted! (0 uses remaining)|r", move.name))
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        return
    end

    if moveData.currentCD > 0 then
        BE.State.dialogueText = string.format("%s is on cooldown! (%d turns left)", move.name, moveData.currentCD)
        BE:AddLog(string.format("|cffff4444%s is on cooldown! (%d turns remaining)|r", move.name, moveData.currentCD))
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        return
    end

    local pName = player.nickname ~= "" and player.nickname or player.name

    -- Flinch check
    if BE.State.flinch and BE.State.flinch.player then
        BE.State.flinch.player = false
        BE.State.dialogueText = string.format("%s flinched and couldn't move!", pName)
        BE:AddLog(string.format("|cffffaa00%s flinched and could not attack!|r", pName))
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        C_Timer.After(1.2, function()
            BE:AdvanceToNextTurn()
        end)
        return
    end

    -- Sleep check
    if BE.State.buffs.player and BE.State.buffs.player.sleep and BE.State.buffs.player.sleep > 0 then
        BE.State.buffs.player.sleep = BE.State.buffs.player.sleep - 1
        BE.State.dialogueText = string.format("%s is fast asleep!", pName)
        BE:AddLog(string.format("|cff9966cc%s is fast asleep and cannot move!|r", pName))
        if BE.State.buffs.player.sleep <= 0 then
            BE.State.buffs.player.sleep = nil
            BE:AddLog(string.format("|cff00ff00%s woke up!|r", pName))
        end
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        C_Timer.After(1.2, function()
            BE:AdvanceToNextTurn()
        end)
        return
    end

    -- Disobedience Check based on Attunement Rank
    local isDisobedient, reason = SE:CheckDisobedience(player)
    if isDisobedient then
        player.disobediences = (player.disobediences or 0) + 1
        BE.State.dialogueText = string.format("%s %s", pName, reason)
        BE:AddLog(string.format("|cffffaa00[Disobedience]|r %s %s", pName, reason))
        PlaySound(847)
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end

        C_Timer.After(1.2, function()
            BE:AdvanceToNextTurn()
        end)
        return
    end

    -- Apply Move Cost: Deduct use & set cooldown
    moveData.usesLeft = moveData.usesLeft - 1
    moveData.currentCD = move.cooldown or 0

    local priorityText = (move.priority and move.priority > 0) and " |cffffcc00[Priority Strike!]|r" or ""
    BE.State.dialogueText = string.format("%s used %s!", pName, move.name)
    BE:AddLog(string.format("|cff00ff99%s|r used |cffffd100%s|r!%s (Uses: %d/%d)", pName, move.name, priorityText, moveData.usesLeft, moveData.maxUses))

    -- 🍃 Druid Class Passive: Ecliptic Tides (Solar / Lunar Tug-of-War & Surges)
    local CP = ns.ClassPassives
    local MoveDB = ns.MoveDB
    if CP and CP:GetPlayerClass() == "DRUID" and MoveDB then
        local moveRole = MoveDB:GetMoveRole(moveKey)
        local curRank = player.attunementRank or 1
        local oppClass = BE.State.opponentClass
        local eclipse = BE.State.druidEclipse

        if not eclipse then
            eclipse = { solar = 0, lunar = 0, hotTurns = 0, hotAmount = 0, brambleTurns = 0, bramblePercent = 0, bramblePoints = 0 }
            BE.State.druidEclipse = eclipse
        end

        local autoDischarge, surgeType, surgePoints = CP:UpdateEclipseMeter(eclipse, moveRole, curRank)

        if autoDischarge then
            -- 100% Guaranteed Automatic Discharge at Max Capacity
            if surgeType == "SOLAR" then
                local cleansed = BE:CleansePlayerDebuff()
                local hotAmount, hotDuration = CP:GetSolarHoT(player.maxHP, surgePoints)
                eclipse.hotTurns = hotDuration
                eclipse.hotAmount = hotAmount
                local cleanMsg = cleansed and string.format(" (cleansed %s)", cleansed) or ""
                BE:AddLog(string.format("|cffffcc00[Solar Surge - 100%% Discharge!]|r Rejuvenating Bloom restored! (+%d HP/round for %d rounds)%s", hotAmount, hotDuration, cleanMsg))
            elseif surgeType == "LUNAR" then
                local brambleTurns = surgePoints
                eclipse.brambleTurns = brambleTurns
                eclipse.bramblePoints = surgePoints
                BE:AddLog(string.format("|cff3399ff[Lunar Surge - 100%% Discharge!]|r Bramble Damage Shield active! (Reflecting %d%% Nature damage for %d rounds)", surgePoints * 5, brambleTurns))
            end
        else
            -- Check for Early Proc Roll on cast (5% per point on the cast side)
            local currentPoints = (moveRole == "Offensive") and eclipse.solar or eclipse.lunar
            if currentPoints > 0 and CP:RollEclipseSurge(currentPoints, oppClass) then
                if moveRole == "Offensive" then
                    local pts = eclipse.solar
                    eclipse.solar = 0
                    eclipse.lunar = 0
                    local cleansed = BE:CleansePlayerDebuff()
                    local hotAmount, hotDuration = CP:GetSolarHoT(player.maxHP, pts)
                    eclipse.hotTurns = hotDuration
                    eclipse.hotAmount = hotAmount
                    local cleanMsg = cleansed and string.format(" (cleansed %s)", cleansed) or ""
                    BE:AddLog(string.format("|cffffcc00[Solar Surge Procced (%d%% roll)!]|r Rejuvenating Bloom restored! (+%d HP/round for %d rounds)%s - Meter reset to 0.", pts * 5, hotAmount, hotDuration, cleanMsg))
                else
                    local pts = eclipse.lunar
                    eclipse.solar = 0
                    eclipse.lunar = 0
                    eclipse.brambleTurns = pts
                    eclipse.bramblePoints = pts
                    BE:AddLog(string.format("|cff3399ff[Lunar Surge Procced (%d%% roll)!]|r Bramble Damage Shield active! (Reflecting %d%% Nature damage for %d rounds) - Meter reset to 0.", pts * 5, pts * 5, pts))
                end
            else
                local roleCol = (moveRole == "Offensive") and "|cffffaa00Solar|r" or "|cff66ccffLunar|r"
                BE:AddLog(string.format("|cffffffff[Ecliptic Tides]|r %s move advanced meter: [☀️ Solar: %d/%d | 🌙 Lunar: %d/%d]", roleCol, eclipse.solar, curRank, eclipse.lunar, curRank))
            end
        end
    end

    -- Trigger Player Attack Animation in UI
    if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.TriggerAttackAnimation then
        ForeverSafari.BattleFrame:TriggerAttackAnimation(true)
    end

    -- Accuracy check
    local hitRoll = math.random(1, 100)
    if hitRoll > move.accuracy then
        BE.State.dialogueText = string.format("%s's attack missed!", pName)
        BE:AddLog("|cffff8800The attack missed!|r")
    else
        BE:ApplyMoveEffects(move, player, enemy, "player")
        if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.TriggerHitAnimation then
            ForeverSafari.BattleFrame:TriggerHitAnimation(false)
        end
    end

    -- Check if Undead immortality expired for player
    if BE.State.passives.undeadImmortal.player == 1 then
        BE.State.passives.undeadImmortal.player = 0
        player.currentHP = 0
        BE:AddLog(string.format("|cff9966cc%s's Unholy Immortality has expired!|r", pName))
        BE:HandlePlayerFaint()
        return
    end

    -- Check if enemy fainted
    if enemy.currentHP <= 0 then
        if not BE:CheckDefeatPassives(enemy, "enemy") then
            BE:HandleEnemyFaint()
            return
        end
    end

    -- Advance Action-Gauge to Next Turn (supports speed lapping)
    if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end

    C_Timer.After(1.2, function()
        BE:AdvanceToNextTurn()
    end)
end

-- Enemy AI Turn Execution
function BE:ExecuteEnemyTurn()
    if not BE.State.inBattle or BE.State.turn ~= "enemy" then return end

    local enemy = BE.State.enemyMob
    local player = BE.State.playerMob

    -- Flinch check
    if BE.State.flinch and BE.State.flinch.enemy then
        BE.State.flinch.enemy = false
        BE.State.dialogueText = string.format("Enemy %s flinched and couldn't move!", enemy.name)
        BE:AddLog(string.format("|cffffaa00Wild %s flinched and could not attack!|r", enemy.name))
        C_Timer.After(1.2, function()
            BE:AdvanceToNextTurn()
        end)
        return
    end

    -- Sleep check
    if BE.State.buffs.enemy and BE.State.buffs.enemy.sleep and BE.State.buffs.enemy.sleep > 0 then
        BE.State.buffs.enemy.sleep = BE.State.buffs.enemy.sleep - 1
        BE.State.dialogueText = string.format("Enemy %s is fast asleep!", enemy.name)
        BE:AddLog(string.format("|cff9966ccWild %s is fast asleep and cannot move!|r", enemy.name))
        if BE.State.buffs.enemy.sleep <= 0 then
            BE.State.buffs.enemy.sleep = nil
            BE:AddLog(string.format("|cff00ff00Wild %s woke up!|r", enemy.name))
        end
        C_Timer.After(1.2, function()
            BE:AdvanceToNextTurn()
        end)
        return
    end

    -- Pick best available move that is off cooldown and has uses left
    local availableMoves = {}
    local moveList = enemy.abilities or enemy.moves or { "Tackle" }
    for _, moveKey in ipairs(moveList) do
        local m = BE:GetMoveData(moveKey)
        local mState = BE.State.moveState.enemy[moveKey]
        if m and mState and mState.usesLeft > 0 and mState.currentCD == 0 then
            table.insert(availableMoves, { key = moveKey, move = m, state = mState })
        end
    end

    local chosen
    if #availableMoves > 0 then
        chosen = availableMoves[math.random(1, #availableMoves)]
    else
        -- Fallback to basic Tackle/Bite if all on cooldown
        local fallbackMove = BE:GetMoveData("Tackle") or BE:GetMoveData(101)
        chosen = { key = "Tackle", move = fallbackMove, state = BE.State.moveState.enemy["Tackle"] or { usesLeft = 10, currentCD = 0, maxUses = 10 } }
    end

    chosen.state.usesLeft = math.max(0, chosen.state.usesLeft - 1)
    chosen.state.currentCD = chosen.move.cooldown or 0

    -- Vanilla WoW Pet Learning Mechanic: Observe and learn higher-level abilities from wild mobs
    if chosen.key and not DB:IsAbilityUnlocked(chosen.key) then
        DB:UnlockAbility(chosen.key, enemy.name, false)
        BE:AddLog(string.format("|cff00ff00[Ability Learned!]|r You observed %s and learned |cffffd100[%s]|r!", enemy.name, chosen.move.name))
    end

    local priorityText = (chosen.move.priority and chosen.move.priority > 0) and " |cffffcc00[Priority Strike!]|r" or ""
    BE.State.dialogueText = string.format("Enemy %s used %s!", enemy.name, chosen.move.name)
    BE:AddLog(string.format("|cffff6666Wild %s|r used |cffffd100%s|r!%s", enemy.name, chosen.move.name, priorityText))

    -- Trigger Enemy Attack Animation in UI
    if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.TriggerAttackAnimation then
        ForeverSafari.BattleFrame:TriggerAttackAnimation(false)
    end

    local hitRoll = math.random(1, 100)
    local effectiveAccuracy = chosen.move.accuracy
    local CP = ns.ClassPassives
    if CP and CP.GetRogueMissBonus then
        local pClass = CP:GetPlayerClass()
        local pRank = player and player.attunementRank or 1
        local missPenalty = CP:GetRogueMissBonus(pClass, BE.State.opponentClass, pRank)
        effectiveAccuracy = math.max(1, effectiveAccuracy - missPenalty)
    end

    if hitRoll > effectiveAccuracy then
        BE.State.dialogueText = string.format("Enemy %s's attack missed!", enemy.name)
        local shadowMsg = (CP and CP:GetPlayerClass() == "ROGUE") and " |cff00ff99[Shadow Evasion]|r" or ""
        BE:AddLog(string.format("|cffff8800The attack missed!%s|r", shadowMsg))
    else
        BE:ApplyMoveEffects(chosen.move, enemy, player, "enemy")
        if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.TriggerHitAnimation then
            ForeverSafari.BattleFrame:TriggerHitAnimation(true)
        end
    end

    -- Check if Undead immortality expired for enemy
    if BE.State.passives.undeadImmortal.enemy == 1 then
        BE.State.passives.undeadImmortal.enemy = 0
        enemy.currentHP = 0
        BE:AddLog(string.format("|cff9966ccWild %s's Unholy Immortality has expired!|r", enemy.name))
        BE:HandleEnemyFaint()
        return
    end

    -- Check if enemy fainted (including from Bramble shield reflection)
    if enemy.currentHP <= 0 then
        if not BE:CheckDefeatPassives(enemy, "enemy") then
            BE:HandleEnemyFaint()
            return
        end
    end

    -- Check if player fainted
    if player.currentHP <= 0 then
        if not BE:CheckDefeatPassives(player, "player") then
            BE:HandlePlayerFaint()
            return
        end
    end

    -- Advance Action-Gauge to Next Turn (supports speed lapping)
    C_Timer.After(1.2, function()
        BE:AdvanceToNextTurn()
    end)
end

-- Check Defeat Passives (Mechanical 20% Revive & Undead 1-Round Immortality)
function BE:CheckDefeatPassives(mob, side)
    local cType = mob.creatureType
    local name = (side == "player" and (mob.nickname ~= "" and mob.nickname or mob.name)) or ("Wild " .. mob.name)

    -- 8. Mechanical Passive: Revives once per battle with 20% health
    if cType == "Mechanical" and not BE.State.passives.mechanicalRevived[side] then
        BE.State.passives.mechanicalRevived[side] = true
        mob.currentHP = math.max(1, math.floor(mob.maxHP * 0.20))
        BE.State.dialogueText = string.format("%s's Fail-Safe Reboot activated!", name)
        BE:AddLog(string.format("|cffffff00[Fail-Safe Reboot] %s revived with %d HP (20%%)!|r", name, mob.currentHP))
        PlaySound(1195)
        return true
    end

    -- 9. Undead Passive: Returns to life as immortal for one round after being defeated (-25% dmg)
    if cType == "Undead" and not BE.State.passives.undeadTriggered[side] then
        BE.State.passives.undeadTriggered[side] = true
        BE.State.passives.undeadImmortal[side] = 1
        mob.currentHP = 1
        BE.State.dialogueText = string.format("%s rose as Immortal for 1 round!", name)
        BE:AddLog(string.format("|cff9966cc[Unholy Immortality] %s is immortal for 1 round! (-25%% damage)|r", name))
        PlaySound(847)
        return true
    end

    return false
end

-- Apply damage, healing, buffs, and the 9 Pet Passives
function BE:ApplyMoveEffects(move, attacker, defender, side)
    local targetSide = (side == "player") and "enemy" or "player"
    local prevDefenderHP = defender.currentHP
    local isDefenderElemental = (defender.creatureType == "Elemental")
    local CP = ns.ClassPassives
    local pClass = CP and CP:GetPlayerClass()
    local oppClass = BE.State.opponentClass

    -- Instant Direct Heals
    if move.heal and (not move.power or move.power == 0) then
        local healAmount = math.floor(attacker.maxHP * move.heal)
        attacker.currentHP = math.min(attacker.maxHP, attacker.currentHP + healAmount)
        BE:AddLog(string.format("|cff00ff00%s restored %d HP!|r", attacker.name, healAmount))
    end

    -- Heal Over Time (HoT)
    if move.hot then
        BE.State.buffs[side].hot = {
            healPercent = move.hot.healPercent or 0.15,
            duration = move.hot.duration or 3,
            name = move.name,
        }
        BE:AddLog(string.format("|cff00ff99[Regeneration] %s began regenerating health over time!|r", attacker.name))
    end

    -- Stat Buffs / Debuffs
    if move.buff then
        if move.buff.multiplier < 1.0 and isDefenderElemental then
            BE:AddLog(string.format("|cff00e5ff[Primal Purity] %s ignored the debuff!|r", defender.name))
        else
            BE.State.buffs[side][move.buff.stat] = {
                multiplier = move.buff.multiplier,
                turns = move.buff.duration or 3
            }
            BE:AddLog(string.format("|cff33ccff%s's %s was modified!|r", attacker.name, string.upper(move.buff.stat)))
        end
    end

    -- Specific Debuffs (e.g. Bleed Vulnerability from Mangle)
    if move.debuff and move.debuff.bleedVuln then
        BE.State.buffs[targetSide].bleedVuln = {
            multiplier = move.debuff.bleedVuln,
            turns = move.debuff.duration or 3,
        }
        BE:AddLog(string.format("|cffff4444%s was mangled! Bleed damage taken increased by +50%%!|r", defender.name))
    end

    -- Stealth / Flight Reveal (Alarm Bark / Faerie Fire)
    if move.revealStealth then
        BE.State.buffs[targetSide].prowl = nil
        BE.State.buffs[targetSide].liftOff = nil
        BE:AddLog(string.format("|cffffcc00[Vigilance] %s revealed %s! Stealth and flight evasion broken!|r", attacker.name, defender.name))
    end

    -- Direct Damage & Combat Layer Resolution
    if move.power and move.power > 0 then
        local attackerStats = BE:GetEffectiveResistances(attacker, side)
        local defenderStats = BE:GetEffectiveResistances(defender, targetSide)

        local moveCategory = move.category or "Physical"
        local moveSchool = string.lower(move.element or move.type or "Physical")
        if moveSchool == "normal" or moveSchool == "beast" then
            moveSchool = "physical"
        end

        local dRank = defender and (defender.attunementRank or defender.rank or 1) or 1
        local aRank = attacker and (attacker.attunementRank or attacker.rank or 1) or 1
        local defenderClass = (targetSide == "player") and pClass or oppClass
        local attackerClass = (side == "player") and pClass or oppClass

        -- 🛡️ Avoidance: Dodge Check (Physical and direct attacks)
        if moveCategory == "Physical" or moveSchool == "physical" then
            local dodgeChance = defenderStats.dodge or 5
            local dodgeRoll = math.random(1, 100)
            if dodgeRoll <= dodgeChance then
                BE.State.dialogueText = string.format("%s dodged the attack!", defender.name)
                local rogueNote = (defenderClass == "ROGUE") and " |cff00ff99[Shadow Evasion]|r" or ""
                BE:AddLog(string.format("|cffffaa00%s dodged the attack!%s (%d%% dodge)|r", defender.name, rogueNote, dodgeChance))
                return
            end
        end

        -- Stat modifiers on attacker and defender
        local atkMod = 1.0
        if BE.State.buffs[side]["atk"] then
            atkMod = BE.State.buffs[side]["atk"].multiplier
        end

        local defMod = 1.0
        if BE.State.buffs[targetSide]["def"] then
            defMod = BE.State.buffs[targetSide]["def"].multiplier
        end

        -- Passive 2: Beast (+25% damage when dropping below 50% HP)
        local beastMod = 1.0
        if attacker.creatureType == "Beast" and (attacker.currentHP / attacker.maxHP) < 0.50 then
            beastMod = 1.25
        end

        -- Passive 3: Dragonkin (+50% damage on next round after dropping foe below 50% HP)
        local dragonkinMod = 1.0
        if attacker.creatureType == "Dragonkin" and BE.State.passives.dragonkinEnraged[side] then
            dragonkinMod = 1.50
            BE.State.passives.dragonkinEnraged[side] = false
            BE:AddLog(string.format("|cffff3333[Draconic Fury] %s unleashes +50%% bonus damage!|r", attacker.name))
        end

        -- Passive 9: Undead (-25% damage while in Unholy Immortality)
        local undeadMod = 1.0
        if attacker.creatureType == "Undead" and BE.State.passives.undeadImmortal[side] > 0 then
            undeadMod = 0.75
        end

        -- Bleed Synergy: Mangle vulnerability
        local bleedMod = 1.0
        if (move.dot or move.name == "Rip" or move.name == "Shred" or move.name == "Ravage") and BE.State.buffs[targetSide].bleedVuln then
            bleedMod = BE.State.buffs[targetSide].bleedVuln.multiplier or 1.50
        end

        -- Archetype Bonus: Ferocity (+5% damage)
        local ferocityMod = 1.0
        local attackerArchetype = SE and SE.FAMILY_ARCHETYPES and (SE.FAMILY_ARCHETYPES[attacker.family] or SE.FAMILY_ARCHETYPES[attacker.creatureType])
        if attackerArchetype == "Ferocity" then
            ferocityMod = 1.05
        end

        local atk = (attacker.atk or 10) * atkMod * beastMod * dragonkinMod * undeadMod * ferocityMod
        local def = (defender.def or 8) * defMod

        -- Closed-loop 150% Type Effectiveness
        local typeMult = 1.0
        if C.TYPE_ADVANTAGES[move.type] and C.TYPE_ADVANTAGES[move.type][defender.creatureType] then
            typeMult = C.TYPE_ADVANTAGES[move.type][defender.creatureType]
        end

        -- Critical Hit Roll (Base + Archetype Ferocity + Move Crit Bonus)
        local critChance = (attackerStats.crit or 5) + (move.critBonus or 0)
        local isCrit = (math.random(1, 100) <= critChance)
        local critMult = isCrit and 1.5 or 1.0

        local rawDmg = (((atk * move.power * 0.7) / (def * 0.75 + 15)) + math.random(2, 6)) * bleedMod
        local finalDmg = math.max(1, math.floor(rawDmg * typeMult * critMult))

        -- 🛡️ Archetype Cunning Bonus: Spell Deflection (50% damage reduction on special spells)
        if moveCategory ~= "Physical" and moveSchool ~= "physical" then
            local deflectChance = defenderStats.deflection or 0
            if deflectChance > 0 and math.random(1, 100) <= deflectChance then
                local deflectAmt = math.floor(finalDmg * 0.50)
                finalDmg = math.max(1, finalDmg - deflectAmt)
                BE:AddLog(string.format("|cff33ccff[Spell Deflected]|r %s deflected 50%% of the spell damage! (-%d damage)|r", defender.name, deflectAmt))
            end
        end

        -- 🛡️ Elemental Resistance Mitigation (Layers 1-4: Family + Weakness + Archetype + Class Attunement)
        local resistPct = defenderStats[moveSchool] or 0
        local mitigated = math.floor(finalDmg * (resistPct / 100))
        if mitigated > 0 then
            finalDmg = math.max(1, finalDmg - mitigated)
            local schoolDisplay = string.upper(string.sub(moveSchool, 1, 1)) .. string.sub(moveSchool, 2)
            BE:AddLog(string.format("|cff66ccff[%s Resistance]|r %s mitigated %d damage (%d%% resist).|r", schoolDisplay, defender.name, mitigated, resistPct))
        end

        -- 🛡️ Layer 5: Procced Wards (Mage, Shaman, Warlock, Priest, Paladin)
        if CP and CP.RollWardProc then
            local wProcced, wAbsorbPct, wWardName = CP:RollWardProc(defenderClass, moveSchool, dRank)
            if wProcced then
                local wardAbsorb = math.max(1, math.floor(finalDmg * (wAbsorbPct / 100)))
                finalDmg = math.max(1, finalDmg - wardAbsorb)
                BE:AddLog(string.format("|cffcc99ff[%s]|r Absorbed %d damage (%d%% ward)!|r", wWardName, wardAbsorb, wAbsorbPct))
            end
        end

        -- 🛡️ Layer 5: Paladin Aura of Light (Damage-to-Healing Conversion)
        if defenderClass == "PALADIN" and CP and CP.CalculatePaladinHealback then
            local healBack = CP:CalculatePaladinHealback(finalDmg, defenderClass, oppClass, dRank)
            if healBack > 0 then
                defender.currentHP = math.min(defender.maxHP, defender.currentHP + healBack)
                BE:AddLog(string.format("|cffffd100[Aura of Light]|r Converted %d damage into holy healing!|r", healBack))
            end
        end

        -- ❄️ Layer 5: Mage Chilling Tempo (Offense & Defense with Frost Resist Direct Subtraction)
        if CP and CP.RollChillingTempo then
            -- Offensive hit by Mage
            if attackerClass == "MAGE" then
                local targetFrostResist = defenderStats.frost or 0
                local chilled, slowTurns = CP:RollChillingTempo("offensive", aRank, targetFrostResist)
                if chilled then
                    BE.State.buffs[targetSide].spd = { multiplier = 0.5, turns = slowTurns }
                    BE:AddLog(string.format("|cff33ccff[Chilling Tempo]|r %s chilled %s! Speed halved for %d turns!|r", attacker.name, defender.name, slowTurns))
                end
            end
            -- Defensive impact on Mage
            if defenderClass == "MAGE" then
                local attackerFrostResist = attackerStats.frost or 0
                local chilled, slowTurns = CP:RollChillingTempo("defensive", dRank, attackerFrostResist)
                if chilled then
                    BE.State.buffs[side].spd = { multiplier = 0.5, turns = slowTurns }
                    BE:AddLog(string.format("|cff33ccff[Chilling Tempo]|r %s chilled %s on impact! Speed halved for %d turns!|r", defender.name, attacker.name, slowTurns))
                end
            end
        end

        -- 🍃 Druid Class Passive: Ecliptic Tides (Bramble Damage Shield Reflection)
        if defenderClass == "DRUID" and targetSide == "player" and BE.State.druidEclipse and (BE.State.druidEclipse.brambleTurns or 0) > 0 and finalDmg > 0 then
            local bramblePts = BE.State.druidEclipse.bramblePoints or dRank
            local reflectDmg = CP:GetLunarBrambles(finalDmg, bramblePts, oppClass)
            if reflectDmg > 0 and attacker and attacker.currentHP > 0 then
                attacker.currentHP = math.max(0, attacker.currentHP - reflectDmg)
                BE:AddLog(string.format("|cff33ff33[Lunar Surge: Brambles]|r Reflected %d Nature damage back to %s! (%d rounds remaining)", reflectDmg, attacker.name, BE.State.druidEclipse.brambleTurns))
            end
        end

        -- Passive 7: Magic (Cannot take more than 35% max HP from a single attack)
        if defender.creatureType == "Magic" then
            local maxCap = math.floor(defender.maxHP * 0.35)
            if finalDmg > maxCap then
                finalDmg = maxCap
                BE:AddLog(string.format("|cffcc33ff[Spell Ward] %s's damage was capped at 35%% max HP (%d)!|r", defender.name, maxCap))
            end
        end

        -- If defender is currently in Undead Immortality, lethal damage leaves them at 1 HP
        if BE.State.passives.undeadImmortal[targetSide] > 0 then
            defender.currentHP = 1
        else
            defender.currentHP = math.max(0, defender.currentHP - finalDmg)
        end

        -- ⚡ Shaman: Primal Rebirth (10% to 50% chance to revive at 50% max HP)
        if targetSide == "player" and defender.currentHP <= 0 and defenderClass == "SHAMAN" and not BE.State.shamanRevived then
            local canRevive = CP and CP:CanShamanRevive(defenderClass, BE.State.shamanRevived, oppClass, dRank)
            if canRevive then
                BE.State.shamanRevived = true
                local reviveHP = math.ceil(defender.maxHP * 0.5)
                defender.currentHP = reviveHP
                defender.isFainted = false
                PlaySound(1195)
                BE:AddLog(string.format("|cff0070dd[Primal Rebirth]|r %s's spirit returned with %d HP (50%%)!|r", defender.name, reviveHP))
            end
        end

        local effText = ""
        if typeMult >= 1.5 then
            effText = " |cff00ff00(Super Effective! 150%)|r"
        elseif typeMult <= 0.70 then
            effText = " |cffff8800(Resisted! 67%)|r"
        end

        local critText = isCrit and " |cffff0000[CRITICAL HIT!]|r" or ""
        BE:AddLog(string.format("Dealt |cffff3333%d|r damage!%s%s", finalDmg, effText, critText))

        -- Flinch Effect
        if move.flinchChance and math.random(1, 100) <= move.flinchChance then
            BE.State.flinch = BE.State.flinch or { player = false, enemy = false }
            BE.State.flinch[targetSide] = true
            BE:AddLog(string.format("|cffffcc00[Flinched!] %s flinched and lost focus!|r", defender.name))
        end

        -- Sleep Effect
        if move.sleepChance and math.random(1, 100) <= move.sleepChance then
            BE.State.buffs[targetSide].sleep = 2
            BE:AddLog(string.format("|cff9966cc[Sleep] %s succumbed to tranquilizing venom and fell asleep!|r", defender.name))
        end

        -- Drain Life effect
        if move.heal and move.heal > 0 and finalDmg > 0 then
            local drained = math.floor(finalDmg * move.heal)
            attacker.currentHP = math.min(attacker.maxHP, attacker.currentHP + drained)
            BE:AddLog(string.format("|cff00ff00%s drained %d health!|r", attacker.name, drained))
        end

        -- Periodic DoT Attachment
        if move.dot and move.dot.damage and move.dot.damage > 0 then
            BE.State.buffs[targetSide].dots = BE.State.buffs[targetSide].dots or {}
            table.insert(BE.State.buffs[targetSide].dots, {
                name = move.name,
                damage = move.dot.damage,
                duration = move.dot.duration or 3,
                school = moveSchool,
                source = attacker.name,
            })
            BE:AddLog(string.format("|cffff6666%s was afflicted with %s! (%d periodic damage for %d rounds)|r", defender.name, move.name, move.dot.damage, move.dot.duration or 3))
        end
    end
end

-- Use item from Bag in Battle
function BE:UseBagItem(itemId)
    if not BE.State.inBattle or BE.State.turn ~= "player" then return end
    local player = BE.State.playerMob
    if not player then return end

    if DB:GetItemCount(itemId) <= 0 then
        BE.State.dialogueText = "You don't have any left!"
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        return
    end

    if itemId == "healing_salve" then
        DB:RemoveItem("healing_salve", 1)
        local healAmt = math.floor(player.maxHP * 0.5)
        player.currentHP = math.min(player.maxHP, player.currentHP + healAmt)
        BE.State.dialogueText = string.format("Used Healing Salve! +%d HP", healAmt)
        BE:AddLog(string.format("|cff00ff00Used Healing Salve! Restored %d HP.|r", healAmt))
    elseif itemId == "az_treat" then
        DB:RemoveItem("az_treat", 1)
        SE:AddExperience(player, 100)
        BE.State.dialogueText = string.format("Fed %s a Safari Treat! (+100 XP)", player.nickname ~= "" and player.nickname or player.name)
    elseif ns.ItemDB and ns.ItemDB:GetCage(itemId) then
        if ns.BattleCapture then
            ns.BattleCapture:ExecuteCapture(itemId)
        end
        return
    end

    if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
    C_Timer.After(1.2, function()
        BE:AdvanceToNextTurn()
    end)
end

-- Switch active companion mid-battle
function BE:SwitchPlayerMob(mobId)
    if not BE.State.inBattle then return end
    if BE.State.turn ~= "player" and not BE.State.forcedSwitch then return end

    local newMob = DB:GetMobById(mobId)
    if not newMob or (newMob.currentHP or 0) <= 0 then
        BE.State.dialogueText = "That companion has fainted!"
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        return
    end

    if BE.State.playerMob and newMob.id == BE.State.playerMob.id and (BE.State.playerMob.currentHP or 0) > 0 then
        BE.State.dialogueText = "That companion is already in battle!"
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        return
    end

    BE.State.playerMob = newMob
    BE:InitMoveStates(newMob, "player")

    local pName = newMob.nickname ~= "" and newMob.nickname or newMob.name
    local pRank = newMob.attunementRank or 1
    local pRoman = (C.ATTUNEMENT_RANKS[pRank] and C.ATTUNEMENT_RANKS[pRank].roman) or "I"
    BE:AddLog(string.format("Switched to |cff00ff99%s|r (Rank %s %s)!", pName, pRoman, newMob.creatureType))

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:UpdateModels()
    end

    if BE.State.forcedSwitch then
        BE.State.forcedSwitch = false
        BE.State.turn = "player"
        BE.State.dialogueText = string.format("Go! %s! What will %s do?", pName, pName)
        if ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:SetMenuMode("MAIN")
        end
    else
        BE.State.dialogueText = string.format("Go! %s!", pName)
        if ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:SetMenuMode("MAIN")
        end
        C_Timer.After(1.2, function()
            BE:AdvanceToNextTurn()
        end)
    end
end

-- Handle Battle Victory
function BE:HandleVictory()
    local player = BE.State.playerMob
    local enemy = BE.State.enemyMob

    -- 0. Outpost Leader Battle Victory
    if BE.State.isOutpostBattle and BE.State.outpostData then
        local outpost = BE.State.outpostData
        local badge = outpost.badge
        local tokenReward = outpost.tokenReward or (15 + (outpost.tier or 1) * 5)
        local defeatQuote = outpost.defeatQuote or "Remarkable! You have earned our outpost badge!"
        local badgeName = badge and badge.name or "Outpost Badge"

        BE.State.dialogueText = string.format("%s: \"%s\" Outpost Cleared!", outpost.name, defeatQuote)
        BE:AddLog(string.format("|cffffd100%s: \"%s\"|r", outpost.name, defeatQuote))
        BE:AddLog(string.format("|cff00ff00Outpost Defeated! Earned [%s] and +%d Safari Tokens!|r", badgeName, tokenReward))
        PlaySound(1195)

        if player and (player.currentHP or 0) > 0 then
            DB:AddAttunement(player.id, 75, "Outpost Leader Defeat")
        end

        DB:AddTokens(tokenReward, "Outpost Leader Victory")

        player.battlesWon = (player.battlesWon or 0) + 1
        player.battlesTotal = (player.battlesTotal or 0) + 1
        ForeverSafariDB.stats.totalBattlesWon = (ForeverSafariDB.stats.totalBattlesWon or 0) + 1

        -- 🏆 Record Outpost Clear & Award Regional Badge
        ForeverSafariDB.defeatedOutposts = ForeverSafariDB.defeatedOutposts or {}
        ForeverSafariDB.defeatedOutposts[outpost.id] = time()

        if badge and badge.id then
            ForeverSafariDB.badges = ForeverSafariDB.badges or {}
            ForeverSafariDB.badges[badge.id] = {
                id = badge.id,
                name = badge.name,
                icon = badge.icon,
                desc = badge.desc,
                outpostId = outpost.id,
                outpostName = outpost.name,
                zone = outpost.zone,
                tier = outpost.tier,
                earnedAt = time(),
            }
        end

        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00★ OUTPOST CONQUERED!|r Defeated |cffffd100%s|r in %s! Earned |cffffcc00[%s]|r & +%d Tokens!",
            C.PREFIX or "[Safari] ", outpost.name, outpost.location or outpost.zone, badgeName, tokenReward))

        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowReward(string.format("Outpost Defeated: %s!", outpost.name), string.format("Badge: [%s] (+%d Tokens)", badgeName, tokenReward))
        end

        BE.State.inBattle = false
        if ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:UpdateUI()
        end
        if ForeverSafari.CaptureHUD and ForeverSafari.CaptureHUD.UpdateUI then
            ForeverSafari.CaptureHUD:UpdateUI()
        end
        return
    end

    -- 1. AI Trainer Battle Victory
    if BE.State.isTrainerBattle and BE.State.enemyTrainer then
        local trainer = BE.State.enemyTrainer
        local trainerTitle = trainer.trainerTitle or "Rival Trainer"
        local defeatQuote = trainer.defeatQuote or "Well played..."
        local tokenReward = trainer.tokenReward or 8

        BE.State.dialogueText = string.format("%s: \"%s\" Victory!", trainerTitle, defeatQuote)
        BE:AddLog(string.format("|cffffd100%s: \"%s\"|r", trainerTitle, defeatQuote))
        BE:AddLog(string.format("|cff00ff00Defeated %s! Victory!|r", trainerTitle))
        PlaySound(1195)

        if player and (player.currentHP or 0) > 0 then
            DB:AddAttunement(player.id, 50, "Trainer Battle Victory")
        end

        DB:AddTokens(tokenReward, "Trainer Battle Victory")
        BE:AddLog(string.format("|cffffd100Awarded %d Safari Tokens for trainer victory!|r", tokenReward))

        player.battlesWon = (player.battlesWon or 0) + 1
        player.battlesTotal = (player.battlesTotal or 0) + 1
        ForeverSafariDB.stats.totalBattlesWon = (ForeverSafariDB.stats.totalBattlesWon or 0) + 1

        -- 🔒 Record defeat timestamp for trainer GUID (24h anti-farm lockout)
        if BE.State.enemyTrainerGUID and ForeverSafariDB then
            ForeverSafariDB.defeatedTrainers = ForeverSafariDB.defeatedTrainers or {}
            ForeverSafariDB.defeatedTrainers[BE.State.enemyTrainerGUID] = time()
        end

        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowReward(string.format("%s Defeated!", trainerTitle), string.format("+%d Safari Tokens", tokenReward))
        end

        BE.State.inBattle = false
        if ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:UpdateUI()
        end
        return
    end

    -- 2. Wild / PvE Creature Victory
    BE.State.dialogueText = string.format("Wild %s fainted! Victory!", enemy.name)
    BE:AddLog(string.format("|cff00ff00Wild %s fainted! Victory!|r", enemy.name))
    PlaySound(1195)

    -- Award Attunement for surviving battle without fainting
    if player and (player.currentHP or 0) > 0 then
        DB:AddAttunement(player.id, 35, "Battle Resilience")
    end

    -- Harvest Ecosystem Sustenance from defeated wild creature
    local family = enemy.family or enemy.creatureType or "Beast"
    local ItemDB = ns.ItemDB
    local dietInfo = ItemDB and ItemDB.FAMILY_DIETS and (ItemDB.FAMILY_DIETS[family] or ItemDB.FAMILY_DIETS[enemy.creatureType] or ItemDB.FAMILY_DIETS["Beast"])
    local foodKey = dietInfo and dietInfo.favorite or "food_meat"
    local foodItem = ItemDB and ItemDB.DIET_ITEMS and ItemDB.DIET_ITEMS[foodKey]
    if foodItem then
        DB:AddItem(foodKey, 1)
        BE:AddLog(string.format("|cffffd100Looted [1x %s]!|r", foodItem.name or "Safari Meat"))
    end

    player.battlesWon = (player.battlesWon or 0) + 1
    player.battlesTotal = (player.battlesTotal or 0) + 1
    ForeverSafariDB.stats.totalBattlesWon = (ForeverSafariDB.stats.totalBattlesWon or 0) + 1

    -- Trigger Virtual Quest Progress & Boss Permits
    if ForeverSafari.QuestHooks and ForeverSafari.QuestHooks.OnBattleVictory then
        ForeverSafari.QuestHooks:OnBattleVictory(enemy)
    end

    BE.State.inBattle = false

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:UpdateUI()
    end
end

-- Handle Battle Defeat
function BE:HandleDefeat()
    local player = BE.State.playerMob
    local pName = player.nickname ~= "" and player.nickname or player.name
    BE.State.dialogueText = string.format("%s fainted! You lost the battle!", pName)
    BE:AddLog(string.format("|cffff4444%s fainted! You lost the battle!|r", pName))
    PlaySound(847)

    player.battlesTotal = (player.battlesTotal or 0) + 1
    ForeverSafariDB.stats.totalBattlesLost = (ForeverSafariDB.stats.totalBattlesLost or 0) + 1

    BE.State.inBattle = false

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:UpdateUI()
    end
end

-- Forfeit / Run away
function BE:RunAway()
    if not BE.State.inBattle then return end
    BE.State.dialogueText = "Got away safely!"
    BE:AddLog("|cffffaa00Escaped safely from battle!|r")
    BE.State.inBattle = false
    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:UpdateUI()
    end
end

-- 🌿 Priest Class Passive: Divine Grace Active Emergency Heal
function BE:UseDivineGrace()
    if not BE.State.inBattle or BE.State.turn ~= "player" then return false end
    local player = BE.State.playerMob
    if not player or player.currentHP <= 0 then return false end

    local CP = ns.ClassPassives
    local pClass = CP and CP:GetPlayerClass()
    if pClass ~= "PRIEST" then return false end

    local maxUses = CP:GetPriestMaxHeals(player.attunementRank or 1, pClass, BE.State.opponentClass)
    BE.State.priestHealUses = BE.State.priestHealUses or 0
    if BE.State.priestHealUses >= maxUses then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444No Divine Grace charges remaining this battle!|r")
        return false
    end

    BE.State.priestHealUses = BE.State.priestHealUses + 1
    local healAmt = CP:GetPriestHealAmount(player.maxHP, pClass, BE.State.opponentClass, player.attunementRank or 1)
    player.currentHP = math.min(player.maxHP, player.currentHP + healAmt)
    PlaySound(895)
    BE:AddLog(string.format("|cffffffff[Divine Grace]|r Restored |cff00ff00%d HP|r to %s! (%d/%d used)", healAmt, player.name, BE.State.priestHealUses, maxUses))

    BE.State.dialogueText = string.format("You channeled Divine Grace on %s!", player.name)
    if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.UpdateUI then
        ForeverSafari.BattleFrame:UpdateUI()
    end

    C_Timer.After(1.2, function()
        if BE.State.inBattle then
            BE:AdvanceToNextTurn()
        end
    end)
    return true
end
