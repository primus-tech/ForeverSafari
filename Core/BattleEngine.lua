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
    if issecretvalue and issecretvalue(v) then
        return true
    end
    return false
end

BE.State = {
    inBattle = false,
    playerMob = nil,
    enemyMob = nil,
    isPvP = false,
    turn = "player", -- "player" or "enemy"
    forcedSwitch = false,
    round = 1,
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
    logs = {},
    dialogueText = "What will you do?",
}

-- Calculate effective speed considering Flying passive (+50% speed above 50% HP)
function BE:GetEffectiveSpeed(mob)
    if not mob then return 10 end
    local spd = mob.spd or 10
    if mob.creatureType == "Flying" and ((mob.currentHP or 0) / (mob.maxHP or 1)) >= 0.50 then
        spd = math.floor(spd * 1.50)
    end
    return spd
end

-- Helper: Resolve ability data from either C.ABILITIES or MoveDB
function BE:GetMoveData(moveKey)
    if not moveKey then return nil end
    if C.ABILITIES and C.ABILITIES[moveKey] then
        return C.ABILITIES[moveKey]
    end
    local numKey = tonumber(moveKey)
    if numKey and ForeverSafari.MoveDB and ForeverSafari.MoveDB[numKey] then
        return ForeverSafari.MoveDB[numKey]
    end
    if ForeverSafari.MoveDB and ForeverSafari.MoveDB[moveKey] then
        return ForeverSafari.MoveDB[moveKey]
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

-- Process HoTs, DoTs, and Buff durations at end of round
function BE:TickRoundBuffsAndHoTs()
    for _, side in ipairs({ "player", "enemy" }) do
        local mob = (side == "player") and BE.State.playerMob or BE.State.enemyMob
        local buffs = BE.State.buffs[side]
        if mob and mob.currentHP > 0 and buffs then
            -- HoT (Heal over Time, e.g. Frenzied Regeneration)
            if buffs.hot then
                local healAmount = math.max(1, math.floor(mob.maxHP * (buffs.hot.healPercent or 0.15)))
                mob.currentHP = math.min(mob.maxHP, mob.currentHP + healAmount)
                local mName = (side == "player" and mob.nickname ~= "" and mob.nickname) or mob.name
                BE:AddLog(string.format("|cff00ff99[Regeneration]|r %s restored %d HP! (Duration: %d rounds left)", mName, healAmount, buffs.hot.duration - 1))
                buffs.hot.duration = buffs.hot.duration - 1
                if buffs.hot.duration <= 0 then
                    buffs.hot = nil
                end
            end

            -- Bleed Vulnerability decay
            if buffs.bleedVuln then
                buffs.bleedVuln.turns = (buffs.bleedVuln.turns or 1) - 1
                if buffs.bleedVuln.turns <= 0 then
                    buffs.bleedVuln = nil
                end
            end

            -- Stat Buffs / Debuffs decay
            for _, statKey in ipairs({ "atk", "def", "spd" }) do
                if buffs[statKey] and buffs[statKey].turns then
                    buffs[statKey].turns = buffs[statKey].turns - 1
                    if buffs[statKey].turns <= 0 then
                        buffs[statKey] = nil
                    end
                end
            end
        end
    end
end

-- Check if player has any conscious companion on team
function BE:HasConsciousTeamMember()
    local team = DB:GetTeam()
    for _, mob in ipairs(team) do
        if (mob.currentHP or 0) > 0 then
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
            BE:AddLog(string.format("|cffff6666%s sent out %s (Lv %d %s)!|r", trainerTitle, nextMob.name, nextMob.level, nextMob.creatureType))

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
    BE:AddLog(string.format("Opponent sent out |cffff6666%s|r (Level %d %s)!", eName, newMob.level, newMob.creatureType))

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:UpdateModels()
        ForeverSafari.BattleFrame:UpdateUI()
    end

    BE.State.turn = "player"
end

-- Start a Wild Battle against targeted unit or generated mob
function BE:StartWildBattle(unit)
    unit = unit or "target"
    local activeMob = DB:GetActiveMob()
    if not activeMob then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444You have no active companion ready for battle! Open your Field Guide to set one.|r")
        return false
    end

    if (activeMob.currentHP or 0) <= 0 then
        -- Attempt to auto-promote first conscious team member
        local team = DB:GetTeam()
        local foundConscious = nil
        for slotIdx, mob in ipairs(team) do
            if (mob.currentHP or 0) > 0 then
                foundConscious = mob
                DB:SetActiveSlot(slotIdx)
                activeMob = mob
                break
            end
        end
        if not foundConscious then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444All companions in your party have fainted! Visit an Innkeeper, Pet Trainer, or use a Revival Crystal.|r")
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

    local isTrainer = ns.TrainerEngine and ns.TrainerEngine:IsHumanoidTrainer(unit)
    if isTrainer then
        local match = ns.TrainerEngine:GenerateTrainerMatch(unit)
        local enemyMob = match.team[1]

        BE.State.inBattle = true
        BE.State.isTrainerBattle = true
        BE.State.enemyTrainer = match
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

        -- Initialize Move Cooldowns & Limits
        BE:InitMoveStates(activeMob, "player")
        BE:InitMoveStates(enemyMob, "enemy")

        BE.State.logs = {}
        local trainerTitle = match.trainerTitle or "Rival Trainer"
        BE.State.dialogueText = string.format("%s: \"%s\"", trainerTitle, match.introQuote or "Let's battle!")

        local pSpd = BE:GetEffectiveSpeed(activeMob)
        local eSpd = BE:GetEffectiveSpeed(enemyMob)
        BE.State.turn = (pSpd >= eSpd) and "player" or "enemy"

        BE:AddLog(string.format("|cffffcc00[Trainer Battle]|r %s challenged you to a battle!", trainerTitle))
        BE:AddLog(string.format("|cffffd100%s: \"%s\"|r", trainerTitle, match.introQuote or "Let's battle!"))
        BE:AddLog(string.format("|cffff6666%s sent out %s (Lv %d %s)!|r", trainerTitle, enemyMob.name, enemyMob.level, enemyMob.creatureType))

        if ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:ShowBattle()
        end

        if BE.State.turn == "enemy" then
            C_Timer.After(1.4, function()
                BE:ExecuteEnemyTurn()
            end)
        else
            C_Timer.After(1.2, function()
                BE.State.dialogueText = string.format("What will %s do?", activeMob.nickname ~= "" and activeMob.nickname or activeMob.name)
                if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
            end)
        end

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
    
    -- Initialize Move Cooldowns & Limits
    BE:InitMoveStates(activeMob, "player")
    BE:InitMoveStates(enemyMob, "enemy")

    BE.State.logs = {}
    BE.State.dialogueText = string.format("A wild %s appeared!", enemyMob.name)

    -- Flying speed comparison
    local pSpd = BE:GetEffectiveSpeed(activeMob)
    local eSpd = BE:GetEffectiveSpeed(enemyMob)

    if pSpd >= eSpd then
        BE.State.turn = "player"
    else
        BE.State.turn = "enemy"
    end

    BE:AddLog(string.format("|cffffff00Wild %s (Lv %d %s) appeared!|r", enemyMob.name, enemyMob.level, enemyMob.creatureType))

    -- Bestiary / Pokédex Encounter Discovery
    if DB and DB.DiscoverSpecies then
        local isNew, sp = DB:DiscoverSpecies(enemyMob.name, "seen")
        if isNew and ForeverSafari.Toast then
            ForeverSafari.Toast:ShowReward("Bestiary Sighted!", string.format("Added %s to your Field Catalog!", sp.name))
        end
    end

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:ShowBattle()
    end

    if BE.State.turn == "enemy" then
        C_Timer.After(1.2, function()
            BE:ExecuteEnemyTurn()
        end)
    else
        C_Timer.After(1.0, function()
            BE.State.dialogueText = string.format("What will %s do?", activeMob.nickname ~= "" and activeMob.nickname or activeMob.name)
            if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        end)
    end

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
        BE.State.turn = "enemy"
        C_Timer.After(1.2, function()
            BE:ExecuteEnemyTurn()
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
        BE.State.turn = "enemy"
        C_Timer.After(1.2, function()
            BE:ExecuteEnemyTurn()
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

        BE.State.turn = "enemy"
        C_Timer.After(1.4, function()
            BE:ExecuteEnemyTurn()
        end)
        return
    end

    -- Apply Move Cost: Deduct use & set cooldown
    moveData.usesLeft = moveData.usesLeft - 1
    moveData.currentCD = move.cooldown or 0

    local priorityText = (move.priority and move.priority > 0) and " |cffffcc00[Priority Strike!]|r" or ""
    BE.State.dialogueText = string.format("%s used %s!", pName, move.name)
    BE:AddLog(string.format("|cff00ff99%s|r used |cffffd100%s|r!%s (Uses: %d/%d)", pName, move.name, priorityText, moveData.usesLeft, moveData.maxUses))

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

    -- Enemy Turn
    BE.State.turn = "enemy"
    if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end

    C_Timer.After(1.4, function()
        BE:ExecuteEnemyTurn()
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
        -- Complete round
        BE:TickCooldowns("player")
        BE:TickCooldowns("enemy")
        BE:TickRoundBuffsAndHoTs()
        BE.State.round = BE.State.round + 1
        BE.State.turn = "player"
        C_Timer.After(1.2, function()
            local pName = player.nickname ~= "" and player.nickname or player.name
            BE.State.dialogueText = string.format("What will %s do?", pName)
            if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
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
        -- Complete round
        BE:TickCooldowns("player")
        BE:TickCooldowns("enemy")
        BE:TickRoundBuffsAndHoTs()
        BE.State.round = BE.State.round + 1
        BE.State.turn = "player"
        C_Timer.After(1.2, function()
            local pName = player.nickname ~= "" and player.nickname or player.name
            BE.State.dialogueText = string.format("What will %s do?", pName)
            if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
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
        -- Fallback to basic Tackle if all on cooldown
        local fallbackMove = BE:GetMoveData("Tackle") or (C.ABILITIES and C.ABILITIES["Tackle"])
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
    if hitRoll > chosen.move.accuracy then
        BE.State.dialogueText = string.format("Enemy %s's attack missed!", enemy.name)
        BE:AddLog("|cffff8800The attack missed!|r")
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

    -- Check if player fainted
    if player.currentHP <= 0 then
        if not BE:CheckDefeatPassives(player, "player") then
            BE:HandlePlayerFaint()
            return
        end
    end

    -- Round Complete: Decrement Cooldowns & Buffs for both combatants
    BE:TickCooldowns("player")
    BE:TickCooldowns("enemy")
    BE:TickRoundBuffsAndHoTs()

    BE.State.round = BE.State.round + 1
    BE.State.turn = "player"

    C_Timer.After(1.2, function()
        local pName = player.nickname ~= "" and player.nickname or player.name
        BE.State.dialogueText = string.format("What will %s do?", pName)
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
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

    -- Instant Direct Heals
    if move.heal then
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

    -- Direct Damage Calculation
    if move.power and move.power > 0 then
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

        local atk = (attacker.atk or 10) * atkMod * beastMod * dragonkinMod * undeadMod
        local def = (defender.def or 8) * defMod

        -- Closed-loop 150% Type Effectiveness
        local typeMult = 1.0
        if C.TYPE_ADVANTAGES[move.type] and C.TYPE_ADVANTAGES[move.type][defender.creatureType] then
            typeMult = C.TYPE_ADVANTAGES[move.type][defender.creatureType]
        end

        local critChance = 0.12 + ((move.critBonus or 0) / 100)
        local isCrit = (math.random() < critChance)
        local critMult = isCrit and 1.5 or 1.0

        local rawDmg = (((atk * move.power * 0.7) / (def * 0.75 + 15)) + math.random(2, 6)) * bleedMod
        local finalDmg = math.max(1, math.floor(rawDmg * typeMult * critMult))

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
    elseif C.CAGES[itemId] then
        BE:ThrowCageInCombat(itemId)
        return
    end

    BE.State.turn = "enemy"
    if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
    C_Timer.After(1.4, function()
        BE:ExecuteEnemyTurn()
    end)
end

-- Throw net during battle
function BE:ThrowCageInCombat(cageId)
    local enemy = BE.State.enemyMob
    if not enemy then return end

    if BE.State.isTrainerBattle or (enemy and enemy.isTrainerPet) then
        BE.State.dialogueText = "You cannot capture another hunter's companion!"
        BE:AddLog("|cffff4444You cannot capture another hunter's companion!|r")
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        return
    end

    if enemy.creatureType == "Humanoid" or (C.ELIGIBLE_CAPTURE_TYPES and not C.ELIGIBLE_CAPTURE_TYPES[enemy.creatureType]) then
        BE.State.dialogueText = "Humanoids cannot be captured!"
        BE:AddLog("|cffff4444Humanoids and civilized targets cannot be captured!|r")
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        return
    end

    if not DB:IsTypeUnlocked(enemy.creatureType) then
        local permit = C.TYPE_RESEARCH_PERMITS and C.TYPE_RESEARCH_PERMITS[enemy.creatureType]
        local permitName = permit and permit.name or (enemy.creatureType .. " Research Permit")
        BE.State.dialogueText = string.format("%s research locked! Requires [%s]!", enemy.creatureType, permitName)
        BE:AddLog(string.format("|cffff4444Cannot capture %s! Requires research permit [%s]!|r", enemy.creatureType, permitName))
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        return
    end

    -- Check squad capacity and transport crate requirement
    local isSquadFull = (DB:GetSquadCount() >= 4)
    local enemyQuality = enemy.quality or (enemy.isBoss and 4) or (enemy.isRareSpawn and 3) or (enemy.isElite and 2) or 1
    if isSquadFull and not DB:HasTransportCrate(enemyQuality) then
        local crateData = C.TRANSPORT_CRATES and C.TRANSPORT_CRATES[enemyQuality == 4 and "crate_thorium" or enemyQuality == 3 and "crate_mithril" or enemyQuality == 2 and "crate_iron" or "crate_copper"]
        local crateName = crateData and crateData.name or "Transport Crate"
        BE.State.dialogueText = string.format("Active squad full (4/4)! Need %s!", crateName)
        BE:AddLog(string.format("|cffff4444Active squad is full (4/4)! You need a %s (or higher) to ship wild catches to the Safari Kennel!|r", crateName))
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        return
    end

    DB:RemoveItem(cageId, 1)
    local cageData = C.CAGES[cageId] or C.CAGES["copper_cage"]
    local hpPct = (enemy.currentHP / enemy.maxHP) * 100

    BE.State.dialogueText = string.format("Threw a %s!", cageData.name)
    BE:AddLog(string.format("Threw |cff%s[%s]|r at wild %s!", cageData.color or "ffffff", cageData.name, enemy.name))

    -- Calculate capture probability based on requirements (2% at 50% HP -> 50% at 25% HP)
    local baseRate = 0
    if hpPct > 50 then
        baseRate = 0.0
    elseif hpPct >= 25 then
        local t = (hpPct - 25.0) / 25.0
        baseRate = 0.50 - (t * 0.48)
    else
        local t = (25.0 - hpPct) / 25.0
        baseRate = 0.50 + (t * 0.45)
    end

    local finalRate = math.min(0.99, math.max(0.01, baseRate * (cageData.rateMultiplier or 1.0)))
    local roll = math.random()

    if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end

    C_Timer.After(1.0, function()
        if hpPct > 50 then
            BE.State.dialogueText = "The creature was too strong! Weaken it below 50% HP!"
            BE:AddLog("|cffff4444Creature was too healthy to catch! Weaken below 50% HP!|r")
            BE.State.turn = "enemy"
            if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
            C_Timer.After(1.4, function() BE:ExecuteEnemyTurn() end)
        elseif roll <= finalRate then
            PlaySound(1195)
            if DB and DB.DiscoverSpecies then
                DB:DiscoverSpecies(enemy.name, "caught")
            end
            if isSquadFull then
                local ok, crateId, crateData = DB:ConsumeBestTransportCrate(enemyQuality)
                DB:AddMob(enemy, false)
                local cName = crateData and crateData.name or "Transport Crate"
                BE.State.dialogueText = string.format("Gotcha! %s was caught & crated in %s!", enemy.name, cName)
                BE:AddLog(string.format("|cff00ff00Gotcha! Wild %s was captured, crated in [%s], and sent to the Safari Kennel!|r", enemy.name, cName))
                if ForeverSafari.Toast then
                    ForeverSafari.Toast:ShowAlert("Captured & Banked", string.format("%s was crated & sent to Innkeeper's Kennel!", enemy.name))
                end
            else
                DB:AddMob(enemy, true)
                BE.State.dialogueText = string.format("Gotcha! %s joined your squad!", enemy.name)
                BE:AddLog(string.format("|cff00ff00Gotcha! Wild %s was captured and joined your active squad!|r", enemy.name))
                if ForeverSafari.Toast then ForeverSafari.Toast:ShowCapture(enemy) end
            end
            BE.State.inBattle = false
            if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        else
            BE.State.dialogueText = string.format("Oh no! %s broke free!", enemy.name)
            BE:AddLog(string.format("|cffff4444Wild %s broke free from the net!|r", enemy.name))
            BE.State.turn = "enemy"
            if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
            C_Timer.After(1.4, function() BE:ExecuteEnemyTurn() end)
        end
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
    BE:AddLog(string.format("Switched to |cff00ff99%s|r (Level %d %s)!", pName, newMob.level, newMob.creatureType))

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
        BE.State.turn = "enemy"
        BE.State.dialogueText = string.format("Go! %s!", pName)
        if ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:SetMenuMode("MAIN")
        end
        C_Timer.After(1.4, function()
            BE:ExecuteEnemyTurn()
        end)
    end
end

-- Handle Battle Victory
function BE:HandleVictory()
    local player = BE.State.playerMob
    local enemy = BE.State.enemyMob

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

    -- Harvest Family Nourishment Resource from defeated wild creature
    local family = enemy.family or enemy.creatureType or "Beast"
    local foodData = C.FAMILY_NOURISHMENT[family]
    if foodData then
        local foodKey = "food_" .. string.lower(family)
        DB:AddItem(foodKey, 1)
        BE:AddLog(string.format("|cffffd100Looted [1x %s] for nourishing %s companions!|r", foodData.item, foodData.yield))
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
    C_Timer.After(1.0, function()
        if ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:Hide()
        end
    end)
end
