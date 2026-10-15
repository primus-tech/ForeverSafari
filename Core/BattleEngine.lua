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
    -- Virtual Duo & Party Scaling
    isVirtualDuo = false,
    duoActive = nil,
    duoTurnCounter = 0,
    twinsEclipse = nil,
    squadQuota = 5,
    designatedSquad = nil,
    combatStarted = false,
    turnTimerRemaining = 15,
    turnTimerActive = false,
    logs = {},
    dialogueText = "What will you do?",
}

-- Calculate group squad quota based on challenger party size (4-5 players = 2 pets; 3 players = 3 pets; 1-2 players = 4 pets)
function BE:GetSquadQuota()
    if BE.State and BE.State.squadQuota then
        return BE.State.squadQuota
    end
    local pCount = (GetNumGroupMembers and GetNumGroupMembers() > 0 and GetNumGroupMembers()) or 1
    if pCount >= 4 then
        return 2
    elseif pCount == 3 then
        return 3
    else
        return 4
    end
end

-- 15-Second Turn Timeout System: Auto-casts Move 1 if no action taken
function BE:StartTurnTimer()
    BE:CancelTurnTimer()
    if not BE.State.inBattle or BE.State.turn ~= "player" then return end

    BE.State.turnTimerRemaining = 15
    BE.State.turnTimerActive = true

    if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.StartTurnCountdown then
        ForeverSafari.BattleFrame:StartTurnCountdown(15)
    end

    BE.turnTimerTicker = C_Timer.NewTicker(1.0, function()
        if not BE.State.inBattle or BE.State.turn ~= "player" then
            BE:CancelTurnTimer()
            return
        end

        BE.State.turnTimerRemaining = (BE.State.turnTimerRemaining or 15) - 1
        if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.UpdateTurnTimer then
            ForeverSafari.BattleFrame:UpdateTurnTimer(BE.State.turnTimerRemaining, 15)
        end

        if BE.State.turnTimerRemaining <= 0 then
            BE:CancelTurnTimer()
            BE:AddLog("|cffff9900[Turn Timeout]|r 15 seconds elapsed! Auto-executing primary move!|r")
            BE:ExecutePlayerMove(1)
        end
    end, 15)
end

function BE:CancelTurnTimer()
    if BE.turnTimerTicker then
        BE.turnTimerTicker:Cancel()
        BE.turnTimerTicker = nil
    end
    BE.State.turnTimerActive = false
    if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.HideTurnTimer then
        ForeverSafari.BattleFrame:HideTurnTimer()
    end
end

-- Calculate effective speed considering Flying passive (+50% speed above 50% HP) and temporary spd buffs/debuffs
function BE:GetEffectiveSpeed(mob, side)
    if not mob then return 10 end
    local spd = mob.spd or 10
    if mob.creatureType == "Flying" and ((mob.currentHP or 0) / (mob.maxHP or 1)) >= 0.50 then
        spd = math.floor(spd * 1.50)
    end
    if mob.resurrectionSickness then
        spd = math.max(1, math.floor(spd * 0.75))
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
    local res = (SE and SE.CalculateResistances and SE:CalculateResistances(mob, pClass, rank)) or { physical = 0, fire = 0, frost = 0, nature = 0, arcane = 0, shadow = 0, holy = 0, dodge = 5, crit = 5, deflection = 0 }
    if side and BE.State.buffs and BE.State.buffs[side] and BE.State.buffs[side].dodgeBonus then
        res.dodge = (res.dodge or 5) + (BE.State.buffs[side].dodgeBonus.dodgeAdd or 25)
    end
    return res
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

    -- 🌟 Spirit Healer Boss Encounter Mechanics (Argent Dawn Guide at Light's Hope Chapel)
    if BE.State.isOutpostBattle then
        -- 1. Mass Resurrection Check (ticks when Spirit Healer is the active enemy)
        if side == "enemy" and mob and mob.isSpiritHealer and not BE.State.spiritHealerMassRezUsed then
            BE.State.spiritHealerActiveTurns = (BE.State.spiritHealerActiveTurns or 0) + 1
            if BE.State.spiritHealerActiveTurns == 3 then
                BE:AddLog("|cffffd100[Divine Warning]|r The Spirit Healer begins channeling the souls of the fallen!|r")
            elseif BE.State.spiritHealerActiveTurns >= 5 then
                BE:TriggerSpiritHealerMassResurrection()
            end
        end

        -- 2. Backline Regeneration: Heals 5% Max HP per turn on the bench while player grinds through rezzed mobs
        if BE.State.spiritHealerBenchHealing and BE.State.enemyTeam then
            for slotIdx, member in ipairs(BE.State.enemyTeam) do
                if member.isSpiritHealer and slotIdx ~= BE.State.enemyActiveSlot and (member.currentHP or 0) > 0 then
                    local heal = math.max(1, math.floor(member.maxHP * 0.05))
                    member.currentHP = math.min(member.maxHP, member.currentHP + heal)
                    BE:AddLog(string.format("|cff00ff99[Spirit Communion]|r The Spirit Healer restores %d HP on the bench! (%d/%d HP)|r", heal, member.currentHP, member.maxHP))
                    break
                end
            end
        end

        -- 3. Divine Pendulum Passive Pulse: Every other turn, Shadow and suppression effects are halved
        if side == "enemy" and mob and (mob.hasDivinePendulum or mob.isSpiritHealer) and BE:IsDivinePendulumActive("enemy") then
            BE:AddLog("|cffffd100[Divine Pendulum]|r The Spirit Healer's divine pendulum swings! Shadow and suppression effects are halved this turn!|r")
        end
    end

    -- 1. HoT (Heal over Time, e.g. Frenzied Regeneration)
    if buffs.hot then
        local healAmount = math.max(1, math.floor(mob.maxHP * (buffs.hot.healPercent or 0.15)))
        mob.currentHP = math.min(mob.maxHP, mob.currentHP + healAmount)
        local mName = (side == "player" and mob.nickname ~= "" and mob.nickname) or mob.name
        BE:AddLog(string.format("|cff00ff99[Regeneration]|r %s restored %d HP! (%d rounds left)", mName, healAmount, buffs.hot.duration - 1))
        if side == "enemy" and BE.State.isVirtualDuo and healAmount > 0 then
            local otherPet = BE:GetOtherDuoActivePet(mob)
            if otherPet and (otherPet.currentHP or 0) > 0 and otherPet.currentHP < otherPet.maxHP then
                local sharedHeal = math.max(1, math.floor(healAmount * 0.50))
                otherPet.currentHP = math.min(otherPet.maxHP, otherPet.currentHP + sharedHeal)
                local oName = otherPet.nickname ~= "" and otherPet.nickname or otherPet.name
                BE:AddLog(string.format("|cff00ff99[Sympathetic Healing]|r %s resonated with %s's regeneration and recovered %d HP (50%%)!|r", oName, mName, sharedHeal))
            end
        end
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
                local wProcced, wAbsorbPct = CP:RollWardProc(sideClass, rank, school, oppClass)
                if wProcced then
                    local absorbed = math.max(1, math.floor(tickDmg * (wAbsorbPct / 100)))
                    tickDmg = math.max(0, tickDmg - absorbed)
                    local wardName = (sideClass == "PALADIN" and "Aegis of Light") or (sideClass == "PRIEST" and "Divine Ward") or (sideClass == "WARLOCK" and "Shadow Ward") or (sideClass == "SHAMAN" and "Elemental Shielding") or "Arcane Ward"
                    BE:AddLog(string.format("|cffcc99ff[%s]|r Absorbed %d periodic damage on %s (%d%% ward)!|r", wardName, absorbed, mob.name, wAbsorbPct))
                end
            end

            -- 🌟 Divine Pendulum Passive: Halves Shadow DoT ticks every other turn
            if school == "shadow" and BE:IsDivinePendulumActive(side) then
                local reduced = math.floor(tickDmg * 0.50)
                tickDmg = math.max(1, tickDmg - reduced)
                BE:AddLog(string.format("|cffffd100[Divine Pendulum]|r Halved incoming Shadow periodic damage on %s (-%d damage)!|r", mob.name, reduced))
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

    -- 6. Damage Reduction (Barkskin Aegis) decay
    if buffs.damageReduction then
        buffs.damageReduction.turns = (buffs.damageReduction.turns or 1) - 1
        if buffs.damageReduction.turns <= 0 then
            buffs.damageReduction = nil
        end
    end

    -- 7. Evasive Agility (Dodge Bonus) decay
    if buffs.dodgeBonus then
        buffs.dodgeBonus.turns = (buffs.dodgeBonus.turns or 1) - 1
        if buffs.dodgeBonus.turns <= 0 then
            buffs.dodgeBonus = nil
        end
    end

    -- 8. Magic / Spell Vulnerability (Faerie Fire) decay
    if buffs.magicVuln then
        buffs.magicVuln.turns = (buffs.magicVuln.turns or 1) - 1
        if buffs.magicVuln.turns <= 0 then
            buffs.magicVuln = nil
        end
    end

    -- 9. ☀️ Cenarion Twins Dual-Line Ecliptic HoT (Solar Bloom) & Cycle-Based Ticking
    if side == "enemy" and BE.State.isVirtualDuo and BE.State.twinsEclipse then
        local te = BE.State.twinsEclipse
        if (te.hotTurns or 0) > 0 and (te.hotAmount or 0) > 0 then
            if BE.State.enemyTeam then
                for _, ally in ipairs(BE.State.enemyTeam) do
                    if (ally.currentHP or 0) > 0 then
                        ally.currentHP = math.min(ally.maxHP, ally.currentHP + te.hotAmount)
                    end
                end
            end
            BE:AddLog(string.format("|cff00ff99[Solar Surge: Rejuvenating Bloom]|r The Cenarion Twins restored %d HP across their squad! (%d rounds remaining)|r", te.hotAmount, te.hotTurns))
        end

        -- Cycle-Based Buff Duration Ticking: Decays shared buffs only when a full timeline cycle elapses (every 2 enemy turns)
        BE.State.duoTurnCounter = (BE.State.duoTurnCounter or 0) + 1
        if BE.State.duoTurnCounter % 2 == 0 then
            if te.hotTurns and te.hotTurns > 0 then
                te.hotTurns = te.hotTurns - 1
                if te.hotTurns <= 0 then te.hotAmount = 0 end
            end
            if te.brambleTurns and te.brambleTurns > 0 then
                te.brambleTurns = te.brambleTurns - 1
                if te.brambleTurns <= 0 then te.bramblePoints = 0 end
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
        BE:StartTurnTimer()
    else
        BE:CancelTurnTimer()
        local eTitle = (BE.State.isTrainerBattle or BE.State.isOutpostBattle) and "" or "Wild "
        local eName = enemy.nickname ~= "" and enemy.nickname or enemy.name
        BE.State.dialogueText = string.format("%s%s is preparing an attack...", eTitle, eName)
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
    BE:CancelTurnTimer()
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
        ForeverSafari.BattleFrame:UpdatePartyFrames()
        ForeverSafari.BattleFrame:UpdateUI()
    end
end

-- Handle Enemy Companion Faint (PvE ends immediately; Trainer switches; PvP prompts for next mob)
function BE:HandleEnemyFaint()
    BE:CancelTurnTimer()
    local enemy = BE.State.enemyMob
    local eName = enemy and (enemy.nickname ~= "" and enemy.nickname or enemy.name) or "Enemy target"
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

            if nextMob.isSpiritHealer and BE.State.spiritHealerBenchHealing then
                BE.State.spiritHealerBenchHealing = false
                BE:AddLog("|cffffd100[Final Judgment]|r The Spirit Healer returns to the battlefield with recovered power!|r")
            end

            local trainerTitle = BE.State.enemyTrainer and BE.State.enemyTrainer.trainerTitle or "Rival Trainer"
            local bossOwner = nextMob.ownerName or trainerTitle
            local nName = nextMob.nickname ~= "" and nextMob.nickname or nextMob.name
            BE.State.dialogueText = string.format("%s sent out %s!", bossOwner, nName)
            local nRank = nextMob.attunementRank or nextMob.rank or 1
            local nRoman = type(nRank) == "number" and (C.ATTUNEMENT_RANKS[nRank] and C.ATTUNEMENT_RANKS[nRank].roman or "I") or tostring(nRank)
            BE:AddLog(string.format("|cffff6666%s sent out %s (Rank %s %s)!|r", bossOwner, nName, nRoman, nextMob.creatureType))

            if BE.State.isVirtualDuo then
                BE.State.selectedTargetIndex = nextSlot
            end

            if ForeverSafari.BattleFrame then
                ForeverSafari.BattleFrame:UpdateModels()
                ForeverSafari.BattleFrame:UpdatePartyFrames()
                ForeverSafari.BattleFrame:UpdateTargetSelection()
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

-- 🌟 Spirit Healer Innate Passive: Divine Pendulum
-- Every other turn, Shadow damage and suppression effects against the Spirit Healer are halved.
function BE:IsDivinePendulumActive(side)
    side = side or "enemy"
    local mob = (side == "enemy") and BE.State.enemyMob or BE.State.playerMob
    if not mob or (not mob.hasDivinePendulum and not mob.isSpiritHealer) then
        return false
    end
    local turnIndex = (side == "enemy") and (BE.State.spiritHealerActiveTurns or BE.State.turnCount or 1) or (BE.State.turnCount or 1)
    return (turnIndex > 0 and (turnIndex % 2 == 1))
end

-- 🌟 Spirit Healer Mass Resurrection Event
function BE:TriggerSpiritHealerMassResurrection()
    BE.State.spiritHealerMassRezUsed = true
    BE.State.spiritHealerBenchHealing = true

    BE:AddLog("|cffffd100[Mass Resurrection]|r The Spirit Healer channels divine Light, reviving the fallen pack with 50% HP!|r")
    BE:AddLog("|cffff4444[Resurrection Sickness]|r All revived beasts suffer -25% to all attributes and damage dealt!|r")
    PlaySound(8959)

    local firstRevived = nil
    local firstSlot = nil

    if BE.State.enemyTeam then
        for slotIdx, pet in ipairs(BE.State.enemyTeam) do
            if not pet.isSpiritHealer then
                pet.currentHP = math.max(1, math.floor(pet.maxHP * 0.5))
                pet.resurrectionSickness = true
                if not firstRevived then
                    firstRevived = pet
                    firstSlot = slotIdx
                end
            end
        end
    end

    if firstRevived and firstSlot then
        BE.State.enemyActiveSlot = firstSlot
        BE.State.enemyMob = firstRevived
        BE:InitMoveStates(firstRevived, "enemy")
        BE.State.dialogueText = string.format("The Spirit Healer retreats to the backline! %s enters the arena!", firstRevived.name)
        BE:AddLog(string.format("|cff00e5ffThe Spirit Healer retreats to the backline to commune with the spirits! %s takes the field!|r", firstRevived.name))
        if ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:UpdateModels()
            ForeverSafari.BattleFrame:UpdateUI()
        end
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

    BE:CancelTurnTimer()

    BE.State.inBattle = true
    BE.State.isTrainerBattle = false
    BE.State.isOutpostBattle = false
    BE.State.isVirtualDuo = false
    BE.State.duoActive = nil
    BE.State.duoTurnCounter = 0
    BE.State.twinsEclipse = nil
    BE.State.squadQuota = 5
    BE.State.designatedSquad = nil
    BE.State.combatStarted = false
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

    local pCount = (GetNumGroupMembers and GetNumGroupMembers() > 0 and GetNumGroupMembers()) or 1
    local match = ns.OutpostDB:GenerateOutpostMatch(outpost, pCount)
    if not match or not match.team or #match.team == 0 then return false end

    local enemyMob = match.team[1]

    BE:CancelTurnTimer()

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
    BE.State.opponentClass = match.trainerClass or outpost.trainerClass or outpost.class
    BE.State.spiritHealerActiveTurns = 0
    BE.State.spiritHealerMassRezUsed = false
    BE.State.spiritHealerBenchHealing = false
    BE.State.druidEclipse = {
        solar = 0,
        lunar = 0,
        hotTurns = 0,
        hotAmount = 0,
        brambleTurns = 0,
        bramblePercent = 0,
        bramblePoints = 0,
    }

    -- Virtual Duo & Party Scaling Setup
    BE.State.isVirtualDuo = match.isVirtualDuo or outpost.isVirtualDuo or false
    if BE.State.isVirtualDuo then
        BE.State.isPartyBattle = true
        BE.State.disparity = match.disparity or 0
        BE.State.partyMultiplier = match.partyMultiplier or 1.0
        BE.State.duoActive = { jarund = 1, layo = 2 }
        BE.State.duoTurnCounter = 0
        BE.State.twinsEclipse = {
            solar = 0,
            lunar = 0,
            hotTurns = 0,
            hotAmount = 0,
            brambleTurns = 0,
            bramblePoints = 0,
        }
    else
        BE.State.isPartyBattle = false
        BE.State.disparity = 0
        BE.State.partyMultiplier = 1.0
        BE.State.duoActive = nil
        BE.State.duoTurnCounter = 0
        BE.State.twinsEclipse = nil
    end

    -- Squad Quota & Pre-Battle Pet Designation
    local quota = BE:GetSquadQuota()
    BE.State.squadQuota = quota
    BE.State.combatStarted = false
    BE.State.designatedSquad = {}
    local dCount = 0
    local team = DB:GetTeam() or {}
    for _, mobId in ipairs(team) do
        local m = type(mobId) == "table" and mobId or DB:GetMobById(mobId)
        if m and (m.currentHP or 0) > 0 and dCount < quota then
            BE.State.designatedSquad[m.id] = true
            dCount = dCount + 1
        end
    end

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

    if BE.State.isVirtualDuo then
        if (BE.State.disparity or 0) > 0 then
            BE:AddLog(string.format("|cffffaa00[Party Scaling]|r Disparity +%d! Opponents scaled by |cffff4444%.4fx|r base stats!|r", BE.State.disparity, BE.State.partyMultiplier or 1.0))
        end
        BE:AddLog(string.format("|cff00ccff[Squad Capacity]|r Group size quota: %d companions deployed.|r", BE.State.squadQuota))
    end

    local eName = enemyMob.nickname ~= "" and enemyMob.nickname or enemyMob.name
    BE:AddLog(string.format("|cffff6666%s sent out %s (Rank %s %s)!|r", outpost.name, eName, enemyMob.rankRoman or outpost.rankRoman or "I", enemyMob.creatureType))

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:ShowBattle()
    end

    C_Timer.After(1.0, function()
        BE:AdvanceToNextTurn()
    end)

    return true
end

-- Directly challenge the Cenarion Twins Virtual Duo
function BE:StartVirtualDuoBattle(duoKey, playerCount)
    duoKey = duoKey or "cenarion_silithus_duo"
    local duoData = ns.OutpostDB and ns.OutpostDB.VIRTUAL_PARTIES and ns.OutpostDB.VIRTUAL_PARTIES[duoKey]
    if not duoData then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Virtual Duo encounter not found: " .. tostring(duoKey) .. "|r")
        return false
    end
    return BE:StartOutpostBattle("target", duoData)
end

-- Find the other active companion for the Cenarion Twins Virtual Duo
function BE:GetOtherDuoActivePet(sourcePet)
    if not (BE.State.isVirtualDuo and BE.State.enemyTeam and sourcePet) then return nil end
    local isJarund = (sourcePet.ownerName == "Jarund Stoutstrider" or sourcePet.ownerNpcId == 11805 or sourcePet.duoGuide == "jarund")
    local targetOwner = isJarund and "Layo Starstrike" or "Jarund Stoutstrider"

    for _, ally in ipairs(BE.State.enemyTeam) do
        if ally.ownerName == targetOwner and (ally.currentHP or 0) > 0 then
            return ally
        end
    end

    -- Fallback: any other conscious ally in the duo squad
    for _, ally in ipairs(BE.State.enemyTeam) do
        if ally ~= sourcePet and (ally.currentHP or 0) > 0 then
            return ally
        end
    end
    return nil
end

function BE:AddLog(msg)
    table.insert(BE.State.logs, msg)
    if ForeverSafari and ForeverSafari.BattleFrame then
        if ForeverSafari.BattleFrame.AddLogMessage then
            ForeverSafari.BattleFrame:AddLogMessage(msg)
        end
        if ForeverSafari.BattleFrame:IsShown() then
            ForeverSafari.BattleFrame:UpdateLog()
        end
    end
end

-- Select Target Opponent in Multi-Combatant / Party Battles
function BE:SelectTarget(index)
    if not BE.State.inBattle then return end
    local team = BE.State.enemyTeam
    if team and team[index] and (team[index].currentHP or 0) > 0 then
        BE.State.selectedTargetIndex = index
        BE.State.enemyMob = team[index]
        if ForeverSafari and ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:UpdateTargetSelection()
            ForeverSafari.BattleFrame:UpdateModels()
            ForeverSafari.BattleFrame:UpdateUI()
        end
        local tName = team[index].nickname ~= "" and team[index].nickname or team[index].name
        BE:AddLog(string.format("|cffffcc00[Target Selected]|r Focused on |cffff6666%s|r!", tName))
    end
end

function BE:ExecutePlayerMove(moveKey)
    if not BE.State.inBattle then return end
    if BE.State.isPvP then
        BE:CommitPvPAction("MOVE", moveKey)
        return
    end
    if BE.State.turn ~= "player" then return end

    BE:CancelTurnTimer()
    BE.State.combatStarted = true

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

    local eName = enemy.nickname ~= "" and enemy.nickname or enemy.name
    local priorityText = (move.priority and move.priority > 0) and " |cffffcc00[Priority Strike!]|r" or ""
    BE.State.dialogueText = string.format("%s used %s on %s!", pName, move.name, eName)
    BE:AddLog(string.format("|cff00ff99%s|r unleashes |cffffd100%s|r on |cffff6666%s|r!%s (Uses: %d/%d)", pName, move.name, eName, priorityText, moveData.usesLeft, moveData.maxUses))

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
        BE.State.dialogueText = string.format("%s's %s missed %s!", pName, move.name, eName)
        BE:AddLog(string.format("|cffffcc00💨 %s's %s swung wide and missed %s!|r", pName, move.name, eName))
        if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.TriggerMissAnimation then
            ForeverSafari.BattleFrame:TriggerMissAnimation(false)
        end
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

    local eTitle = (BE.State.isTrainerBattle or BE.State.isOutpostBattle) and "" or "Wild "
    local eName = enemy.nickname ~= "" and enemy.nickname or enemy.name
    local pName = player.nickname ~= "" and player.nickname or player.name
    local priorityText = (chosen.move.priority and chosen.move.priority > 0) and " |cffffcc00[Priority Strike!]|r" or ""
    BE.State.dialogueText = string.format("%s%s used %s!", eTitle, eName, chosen.move.name)
    BE:AddLog(string.format("|cffff6666%s%s|r used |cffffd100%s|r against |cff00ff99%s|r!%s", eTitle, eName, chosen.move.name, pName, priorityText))

    -- Dual-Line Druid Ecliptic Meter: Advance Solar or Lunar track for the Cenarion Twins
    if BE.State.isVirtualDuo and BE.State.twinsEclipse then
        local isJarund = (enemy.duoGuide == "jarund" or enemy.ownerNpcId == 11805)
        local isLayo = (enemy.duoGuide == "layo" or enemy.ownerNpcId == 13220)
        local te = BE.State.twinsEclipse

        if isJarund then
            te.solar = (te.solar or 0) + 1
            if te.solar >= 5 then
                te.solar = 0
                te.hotTurns = 3
                te.hotAmount = math.max(1, math.floor((enemy.maxHP or 160) * 0.15))
                BE:AddLog("|cffffaa00[Solar Surge - 100% Discharge!]|r Rejuvenating Bloom envelops the Cenarion Twins! (+15% HP/round for 3 rounds)|r")
            else
                BE:AddLog(string.format("|cffffaa00[Solar Balance]|r Jarund's %s charged Solar Energy: [☀️ %d/5]|r", eName, te.solar))
            end
        elseif isLayo then
            te.lunar = (te.lunar or 0) + 1
            if te.lunar >= 5 then
                te.lunar = 0
                te.brambleTurns = 3
                te.bramblePoints = math.max(1, math.floor((enemy.attack or 35) * 0.40))
                BE:AddLog("|cff66ccff[Lunar Surge - 100% Discharge!]|r Bramble Damage Shield crowns the Cenarion Twins! (Reflecting 40% damage for 3 rounds)|r")
            else
                BE:AddLog(string.format("|cff66ccff[Lunar Balance]|r Layo's %s charged Lunar Energy: [🌙 %d/5]|r", eName, te.lunar))
            end
        end
    end

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
        BE.State.dialogueText = string.format("%s%s's %s missed %s!", eTitle, eName, chosen.move.name, pName)
        local shadowMsg = (CP and CP:GetPlayerClass() == "ROGUE") and " |cff00ff99[Shadow Evasion]|r" or ""
        BE:AddLog(string.format("|cffffcc00💨 %s%s's %s swung wide and missed %s!%s|r", eTitle, eName, chosen.move.name, pName, shadowMsg))
        if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.TriggerMissAnimation then
            ForeverSafari.BattleFrame:TriggerMissAnimation(true)
        end
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

    -- Instant Direct Heals & Spectral Mend
    if move.healLowestAlly or (move.heal and (not move.power or move.power == 0)) then
        local healTarget = attacker
        local healAmount = math.floor(attacker.maxHP * (move.healLowestAlly or move.heal or 0.25))
        if move.healLowestAlly and BE.State.enemyTeam then
            local lowestAlly = attacker
            local lowestPct = (attacker.currentHP / attacker.maxHP)
            for _, ally in ipairs(BE.State.enemyTeam) do
                if (ally.currentHP or 0) > 0 then
                    local pct = ally.currentHP / ally.maxHP
                    if pct < lowestPct then
                        lowestPct = pct
                        lowestAlly = ally
                    end
                end
            end
            healTarget = lowestAlly
            healAmount = math.floor(healTarget.maxHP * move.healLowestAlly)
        end
        healTarget.currentHP = math.min(healTarget.maxHP, healTarget.currentHP + healAmount)
        local hName = healTarget.nickname ~= "" and healTarget.nickname or healTarget.name
        BE:AddLog(string.format("|cff00ff00%s restored %d HP!|r", hName, healAmount))

        -- Sympathetic Healing for Virtual Duo:
        if side == "enemy" and BE.State.isVirtualDuo and healAmount > 0 then
            local otherPet = BE:GetOtherDuoActivePet(healTarget)
            if otherPet and (otherPet.currentHP or 0) > 0 and otherPet.currentHP < otherPet.maxHP then
                local sharedHeal = math.max(1, math.floor(healAmount * 0.50))
                otherPet.currentHP = math.min(otherPet.maxHP, otherPet.currentHP + sharedHeal)
                local oName = otherPet.nickname ~= "" and otherPet.nickname or otherPet.name
                BE:AddLog(string.format("|cff00ff99[Sympathetic Healing]|r %s resonated with %s's heal and recovered %d HP (50%%)!|r", oName, hName, sharedHeal))
            end
        end
    end

    -- Heal Over Time (HoT)
    if move.hot then
        BE.State.buffs[side].hot = {
            healPercent = move.hot.healPercent or 0.15,
            duration = move.hot.duration or 3,
            name = move.name,
        }
        local aName = attacker.nickname ~= "" and attacker.nickname or attacker.name
        BE:AddLog(string.format("|cff00ff99[Regeneration] %s began regenerating health over time!|r", aName))
        if side == "enemy" and BE.State.isVirtualDuo then
            BE:AddLog("|cffffcc00[Sympathetic Buffing]|r The Cenarion Twins share all party buffs! [REGENERATION] mirrored across the Twins!|r")
        end
    end

    -- Stat Buffs / Debuffs
    if move.buff then
        if move.buff.multiplier < 1.0 and isDefenderElemental then
            BE:AddLog(string.format("|cff00e5ff[Primal Purity] %s ignored the debuff!|r", defender.nickname ~= "" and defender.nickname or defender.name))
        else
            BE.State.buffs[side][move.buff.stat] = {
                multiplier = move.buff.multiplier,
                turns = move.buff.duration or 3
            }
            local aName = attacker.nickname ~= "" and attacker.nickname or attacker.name
            BE:AddLog(string.format("|cff33ccff%s's %s was modified!|r", aName, string.upper(move.buff.stat)))
            if side == "enemy" and BE.State.isVirtualDuo then
                local pctChange = math.floor((move.buff.multiplier - 1.0) * 100)
                local sign = pctChange >= 0 and "+" or ""
                BE:AddLog(string.format("|cffffcc00[Sympathetic Buffing]|r The Cenarion Twins share all party buffs! [%s%d%% %s] mirrored across the Twins!|r", sign, pctChange, string.upper(move.buff.stat)))
            end
        end
    end

    -- Damage Reduction Buff (Barkskin Aegis)
    if move.damageReduction then
        BE.State.buffs[side].damageReduction = {
            multiplier = move.damageReduction,
            turns = move.duration or 2,
        }
        local aName = attacker.nickname ~= "" and attacker.nickname or attacker.name
        BE:AddLog(string.format("|cff33ccff%s gained Barkskin Aegis (-30%% damage taken)!|r", aName))
        if side == "enemy" and BE.State.isVirtualDuo then
            BE:AddLog("|cffffcc00[Sympathetic Buffing]|r The Cenarion Twins share all party buffs! [-30% DAMAGE TAKEN] mirrored across the Twins!|r")
        end
    end

    -- Evasive Agility Buff (Tranquil Breeze Dodge Bonus)
    if move.dodgeBonus then
        BE.State.buffs[side].dodgeBonus = {
            multiplier = 1.0 + (move.dodgeBonus or 0.25),
            dodgeAdd = math.floor((move.dodgeBonus or 0.25) * 100),
            turns = move.duration or 2,
        }
        local aName = attacker.nickname ~= "" and attacker.nickname or attacker.name
        BE:AddLog(string.format("|cff33ccff%s gained evasive agility (+%d%% Dodge)!|r", aName, math.floor((move.dodgeBonus or 0.25) * 100)))
        if side == "enemy" and BE.State.isVirtualDuo then
            BE:AddLog("|cffffcc00[Sympathetic Buffing]|r The Cenarion Twins share all party buffs! [+25% DODGE] mirrored across the Twins!|r")
        end
    end

    -- Cleanse Debuffs (Tranquil Breeze)
    if move.cleanseDebuffs then
        local b = BE.State.buffs[side]
        if b then
            for statKey, statData in pairs(b) do
                if type(statData) == "table" and statData.multiplier and statData.multiplier < 1.0 then
                    b[statKey] = nil
                end
            end
            b.dots = nil
            b.sleep = nil
        end
        local aName = attacker.nickname ~= "" and attacker.nickname or attacker.name
        BE:AddLog(string.format("|cff00ff99[Tranquil Breeze]|r Cleansed all negative afflictions from %s!|r", aName))
    end

    -- AoE Debuffs against Player Squad (Static Jolt / Disorienting Screech / Faerie Fire)
    if move.aoeDebuff and side == "enemy" then
        local debuff = move.aoeDebuff
        if debuff.stat == "spd" then
            BE.State.buffs.player.spd = { multiplier = debuff.multiplier or 0.75, turns = debuff.duration or 3 }
            BE:AddLog("|cffff4444[Static Jolt]|r AoE static shock slowed your entire squad! (-25% Speed for 3 rounds)|r")
        elseif debuff.stat == "atk" then
            BE.State.buffs.player.atk = { multiplier = debuff.multiplier or 0.75, turns = debuff.duration or 3 }
            BE:AddLog("|cffff4444[Disorienting Screech]|r Piercing screech disoriented your squad! (-25% Attack for 3 rounds)|r")
        elseif debuff.magicVuln then
            BE.State.buffs.player.magicVuln = { multiplier = debuff.magicVuln or 1.30, turns = debuff.duration or 3 }
            BE:AddLog("|cffff4444[Faerie Fire]|r Luminescent dust exposed your squad! (+30% Magic damage taken for 3 rounds)|r")
        end
    end

    -- Specific Debuffs (e.g. Bleed Vulnerability from Mangle or Def debuff from Faerie Rend)
    if move.debuff and move.debuff.bleedVuln then
        BE.State.buffs[targetSide].bleedVuln = {
            multiplier = move.debuff.bleedVuln,
            turns = move.debuff.duration or 3,
        }
        BE:AddLog(string.format("|cffff4444%s was mangled! Bleed damage taken increased by +50%%!|r", defender.nickname ~= "" and defender.nickname or defender.name))
    end
    if move.debuff and move.debuff.stat then
        BE.State.buffs[targetSide][move.debuff.stat] = {
            multiplier = move.debuff.multiplier,
            turns = move.debuff.duration or 3,
        }
        BE:AddLog(string.format("|cffff4444%s's %s was reduced by %d%%!|r", defender.nickname ~= "" and defender.nickname or defender.name, string.upper(move.debuff.stat), math.floor((1.0 - move.debuff.multiplier) * 100)))
    end

    -- Stealth / Flight Reveal (Alarm Bark / Faerie Fire / Faerie Rend)
    if move.revealStealth then
        BE.State.buffs[targetSide].prowl = nil
        BE.State.buffs[targetSide].liftOff = nil
        BE:AddLog(string.format("|cffffcc00[Vigilance] %s revealed %s! Stealth and flight evasion broken!|r", attacker.nickname ~= "" and attacker.nickname or attacker.name, defender.nickname ~= "" and defender.nickname or defender.name))
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
                BE.State.dialogueText = string.format("%s dodged %s's attack!", defender.name, attacker.name)
                local rogueNote = (defenderClass == "ROGUE") and " |cff00ff99[Shadow Evasion]|r" or ""
                BE:AddLog(string.format("|cffffaa00⚡ %s anticipates the blow and swiftly dodges %s's attack!%s (%d%% dodge)|r", defender.name, attacker.name, rogueNote, dodgeChance))
                if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.TriggerMissAnimation then
                    ForeverSafari.BattleFrame:TriggerMissAnimation(targetSide == "player")
                end
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

        local atk = (attacker.atk or 10) * atkMod * beastMod * dragonkinMod * undeadMod * ferocityMod * (attacker.resurrectionSickness and 0.75 or 1.0)
        local def = (defender.def or 8) * defMod * (defender.resurrectionSickness and 0.75 or 1.0)

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

        if attacker.resurrectionSickness then
            finalDmg = math.max(1, math.floor(finalDmg * 0.75))
        end

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

        -- 🌟 Divine Pendulum Passive: Halves direct Shadow damage every other turn
        if moveSchool == "shadow" and BE:IsDivinePendulumActive(targetSide) then
            local reduced = math.floor(finalDmg * 0.50)
            finalDmg = math.max(1, finalDmg - reduced)
            BE:AddLog(string.format("|cffffd100[Divine Pendulum]|r Divine pendulum resonance halved incoming Shadow damage on %s (-%d damage)!|r", defender.name, reduced))
        end

        -- 🛡️ Layer 5: Procced Wards (Mage, Shaman, Warlock, Priest, Paladin)
        if CP and CP.RollWardProc then
            local wProcced, wAbsorbPct = CP:RollWardProc(defenderClass, dRank, moveSchool, attackerClass)
            if wProcced then
                local wardAbsorb = math.max(1, math.floor(finalDmg * (wAbsorbPct / 100)))
                finalDmg = math.max(1, finalDmg - wardAbsorb)
                local wardName = (defenderClass == "PALADIN" and "Aegis of Light") or (defenderClass == "PRIEST" and "Divine Ward") or (defenderClass == "WARLOCK" and "Shadow Ward") or (defenderClass == "SHAMAN" and "Elemental Shielding") or "Arcane Ward"
                BE:AddLog(string.format("|cffcc99ff[%s]|r Absorbed %d damage (%d%% ward)!|r", wardName, wardAbsorb, wAbsorbPct))
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

        -- Damage Reduction Buff (Barkskin Aegis)
        if BE.State.buffs and BE.State.buffs[targetSide] and BE.State.buffs[targetSide].damageReduction then
            local redMult = BE.State.buffs[targetSide].damageReduction.multiplier or 0.30
            local reduced = math.floor(finalDmg * redMult)
            finalDmg = math.max(1, finalDmg - reduced)
            BE:AddLog(string.format("|cff33ccff[Barkskin Aegis]|r Absorbed %d incoming damage on %s (-30%%)!|r", reduced, defender.nickname ~= "" and defender.nickname or defender.name))
        end

        -- Magic / Spell Vulnerability (Faerie Fire)
        if BE.State.buffs and BE.State.buffs[targetSide] and BE.State.buffs[targetSide].magicVuln and moveCategory ~= "Physical" then
            local bonus = math.floor(finalDmg * ((BE.State.buffs[targetSide].magicVuln.multiplier or 1.30) - 1.0))
            finalDmg = finalDmg + bonus
            BE:AddLog(string.format("|cffff4444[Faerie Fire Vulnerability]|r %s took +%d amplified magic damage!|r", defender.nickname ~= "" and defender.nickname or defender.name, bonus))
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

        -- 🍃 Cenarion Twins Dual-Line Ecliptic: Brambles Reflection
        if targetSide == "enemy" and BE.State.isVirtualDuo and BE.State.twinsEclipse and (BE.State.twinsEclipse.brambleTurns or 0) > 0 and finalDmg > 0 then
            local reflectDmg = math.max(1, math.floor(finalDmg * 0.40))
            if attacker and attacker.currentHP > 0 then
                attacker.currentHP = math.max(0, attacker.currentHP - reflectDmg)
                local aName = attacker.nickname ~= "" and attacker.nickname or attacker.name
                BE:AddLog(string.format("|cff33ff33[Twins Brambles]|r Thorny brambles reflected %d Nature damage back to %s! (%d rounds remaining)", reflectDmg, aName, BE.State.twinsEclipse.brambleTurns))
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
            effText = " |cff00ff00(Super Effective! +50%)|r"
        elseif typeMult <= 0.70 then
            effText = " |cffff8800(Resisted! -33%)|r"
        end

        local moveCat = moveCategory or "Physical"
        local dName = defender.nickname ~= "" and defender.nickname or defender.name
        if isCrit then
            BE:AddLog(string.format("|cffff0000💥 CRITICAL HIT!|r %s strikes %s for |cffff2222%d %s damage|r!%s", move.name, dName, finalDmg, moveCat, effText))
        else
            BE:AddLog(string.format("|cffffffff%s|r strikes %s for |cffff3333%d %s damage|r!%s", move.name, dName, finalDmg, moveCat, effText))
        end

        -- 🌪️ Boss AoE Cleave Resolution (Cenarion Twins collateral shockwave)
        if side == "enemy" and BE.State.isVirtualDuo and move.power and move.power > 0 then
            local squad = DB:GetTeam() or {}
            local cleavePower = math.max(10, math.floor(move.power * 0.50))
            for _, sMobId in ipairs(squad) do
                local sMob = type(sMobId) == "table" and sMobId or DB:GetMobById(sMobId)
                if sMob and sMob.id ~= defender.id and (sMob.currentHP or 0) > 0 then
                    if not BE.State.designatedSquad or BE.State.designatedSquad[sMob.id] then
                        local sStats = BE:GetEffectiveResistances(sMob, "player")
                        local sResistPct = sStats[moveSchool] or 0
                        local sDef = sStats.def or sMob.defense or 20
                        local aAtk = attackerStats.atk or attacker.attack or 30
                        local cleaveDmg = math.max(1, math.floor((cleavePower * aAtk / (sDef * 2)) * (1 - sResistPct / 100)))
                        sMob.currentHP = math.max(0, sMob.currentHP - cleaveDmg)
                        local sName = sMob.nickname ~= "" and sMob.nickname or sMob.name
                        BE:AddLog(string.format("|cffff6666[Boss Cleave]|r Collateral shockwave swept through your squad, dealing %d %s damage to %s! (%d/%d HP)|r", cleaveDmg, moveCat, sName, sMob.currentHP, sMob.maxHP))
                        if sMob.currentHP <= 0 then
                            sMob.isFainted = true
                            BE:AddLog(string.format("|cffff2222%s fainted on the bench from the collateral blast!|r", sName))
                        end
                    end
                end
            end
            if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.UpdatePartyFrames then
                ForeverSafari.BattleFrame:UpdatePartyFrames()
            end
        end

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
            if side == "enemy" and BE.State.isVirtualDuo and drained > 0 then
                local otherPet = BE:GetOtherDuoActivePet(attacker)
                if otherPet and (otherPet.currentHP or 0) > 0 and otherPet.currentHP < otherPet.maxHP then
                    local sharedHeal = math.max(1, math.floor(drained * 0.50))
                    otherPet.currentHP = math.min(otherPet.maxHP, otherPet.currentHP + sharedHeal)
                    local oName = otherPet.nickname ~= "" and otherPet.nickname or otherPet.name
                    BE:AddLog(string.format("|cff00ff99[Sympathetic Healing]|r %s resonated with %s's drain and recovered %d HP (50%%)!|r", oName, attacker.name, sharedHeal))
                end
            end
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
    BE:CancelTurnTimer()
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

function BE:SwitchPlayerMob(mobId)
    if not BE.State.inBattle then return end
    if BE.State.isPvP and not BE.State.forcedSwitch then
        BE:CommitPvPAction("SWITCH", mobId)
        return
    end
    if BE.State.turn ~= "player" and not BE.State.forcedSwitch then return end

    BE:CancelTurnTimer()

    local newMob = DB:GetMobById(mobId)
    if not newMob or (newMob.currentHP or 0) <= 0 then
        BE.State.dialogueText = "That companion has fainted!"
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        return
    end

    if BE.State.designatedSquad and not BE.State.designatedSquad[newMob.id] then
        BE.State.dialogueText = "That companion was benched for this battle!"
        local bName = newMob.nickname ~= "" and newMob.nickname or newMob.name
        BE:AddLog(string.format("|cffff4444[Safari Battle]|r %s was benched for this battle and cannot enter combat!|r", bName))
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
        ForeverSafari.BattleFrame:UpdatePartyFrames()
    end

    if BE.State.forcedSwitch then
        BE.State.forcedSwitch = false
        BE.State.turn = "player"
        BE.State.dialogueText = string.format("Go! %s! What will %s do?", pName, pName)
        if ForeverSafari.BattleFrame then
            ForeverSafari.BattleFrame:SetMenuMode("MAIN")
        end
        BE:StartTurnTimer()
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
    BE:CancelTurnTimer()
    local player = BE.State.playerMob
    local enemy = BE.State.enemyMob

    -- 0. Outpost Leader Battle Victory
    if BE.State.isOutpostBattle and BE.State.outpostData then
        local outpost = BE.State.outpostData
        local badge = outpost.badge
        local tokenReward = outpost.tokenReward or (15 + (outpost.tier or 1) * 5)
        local defeatQuote = outpost.defeatQuote or "Remarkable! You have earned our outpost badge!"
        local badgeName = badge and badge.name or "Outpost Badge"

        BE.State.dialogueText = string.format("%s: \"%s\" Guide Cleared!", outpost.name, defeatQuote)
        BE:AddLog(string.format("|cffffd100%s: \"%s\"|r", outpost.name, defeatQuote))
        BE:AddLog(string.format("|cff00ff00Guide Defeated! Earned [%s] and +%d Safari Tokens!|r", badgeName, tokenReward))
        PlaySound(1195)

        if player and (player.currentHP or 0) > 0 then
            DB:AddAttunement(player.id, 75, "Guide Defeat")
        end

        DB:AddTokens(tokenReward, "Guide Victory")

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

        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00★ GUIDE CONQUERED!|r Defeated |cffffd100%s|r in %s! Earned |cffffcc00[%s]|r & +%d Tokens!",
            C.PREFIX or "[Safari] ", outpost.name, outpost.location or outpost.zone, badgeName, tokenReward))

        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowReward(string.format("Guide Defeated: %s!", outpost.name), string.format("Badge: [%s] (+%d Tokens)", badgeName, tokenReward))
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

        -- 🌟 Track Roaming Battler defeat by Tier for Guide unlock quota
        local trainerTier = trainer.tier or 1
        ForeverSafariDB.stats = ForeverSafariDB.stats or {}
        ForeverSafariDB.stats.battlersDefeatedByTier = ForeverSafariDB.stats.battlersDefeatedByTier or {}
        ForeverSafariDB.stats.battlersDefeatedByTier[trainerTier] = (ForeverSafariDB.stats.battlersDefeatedByTier[trainerTier] or 0) + 1

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
    BE:CancelTurnTimer()
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

function BE:RunAway()
    if not BE.State.inBattle then return end
    if BE.State.isPvP then
        BE:ForfeitPvP("RUN_AWAY")
        return
    end
    BE:CancelTurnTimer()
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
    BE:CancelTurnTimer()
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

-- =========================================================================
-- ⚔️ DETERMINISTIC PVP BATTLE ENGINE (Zero-Trust Simulation Protocol)
-- =========================================================================

-- Deterministic PRNG Initialization (Seeded by SHA-256 MatchSeed)
function BE:InitBattleRNG(seedStr)
    seedStr = tostring(seedStr or "00000000")
    local h1 = string.sub(seedStr, 1, 8)
    local s1 = tonumber(h1, 16) or 123456789
    if s1 <= 0 then s1 = 123456789 end
    BE.State.rngState = s1 % 2147483647
    BE.State.rngIndex = 0
end

-- Deterministic PRNG Generator (Lehmer LCG: X_{n+1} = (16807 * X_n) % 2147483647)
function BE:NextRNG()
    BE.State.rngState = (BE.State.rngState * 16807) % 2147483647
    BE.State.rngIndex = (BE.State.rngIndex or 0) + 1
    return (BE.State.rngState - 1) / 2147483646
end

-- Start PvP Companion Duel
function BE:StartPvPDuel(opponentName, opponentTeam, ruleset, matchSeed, isAttacker, opts)
    local activeMob = DB:GetActiveMob()
    if not activeMob or (activeMob.currentHP or 0) <= 0 then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444No active companion ready for battle!|r")
        return false
    end

    if not opponentTeam or #opponentTeam == 0 then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Opponent team is empty!|r")
        return false
    end

    BE.State.inBattle = true
    BE.State.isPvP = true
    BE.State.isTrainerBattle = false
    BE.State.isOutpostBattle = false
    BE.State.opponentName = opponentName
    BE.State.ruleset = ruleset or "1v1"
    BE.State.isDoubles = (ruleset == "2v2" or ruleset == "2v2_sympathy")
    BE.State.sympathy = (ruleset == "2v2_sympathy")
    BE.State.matchSeed = matchSeed
    BE.State.isAttacker = isAttacker
    BE.State.ambushOpts = opts or {}
    BE.State.round = 1
    BE.State.turnCount = 0
    BE.State.turn = "player"
    BE.State.combatStarted = true
    BE.State.dialogueText = string.format("PvP Duel against %s! Choose your move!", opponentName)
    BE.State.logs = {}

    -- Initialize deterministic PRNG
    BE:InitBattleRNG(matchSeed)

    -- Setup Combatants
    BE.State.playerMob = activeMob
    BE.State.enemyMob = opponentTeam[1]
    BE.State.enemyTeam = opponentTeam
    BE.State.enemyActiveSlot = 1

    -- Reset Buffs, Cooldowns & Passives
    BE.State.buffs.player = {}
    BE.State.buffs.enemy = {}
    BE.State.passives.dragonkinEnraged = { player = false, enemy = false }
    BE.State.passives.mechanicalRevived = { player = false, enemy = false }
    BE.State.passives.undeadImmortal = { player = 0, enemy = 0 }
    BE.State.passives.undeadTriggered = { player = false, enemy = false }

    BE:InitMoveStates(activeMob, "player")
    BE:InitMoveStates(opponentTeam[1], "enemy")

    -- Reset Commit-Reveal state
    BE.State.myActionType = nil
    BE.State.myActionParam = nil
    BE.State.myActionStr = nil
    BE.State.myCommitTag = nil
    BE.State.myRevealed = false
    BE.State.peerCommitTag = nil
    BE.State.peerActionStr = nil
    BE.State.pvpActionTimer = 15.0

    BE:AddLog(string.format("|cffffd100[PvP Duel Initiated]|r Facing |cffff6666%s|r (%s)! Seed: |cff00e5ff%s...|r", opponentName, ruleset, string.sub(matchSeed, 1, 8)))

    -- Open Battle Frame
    if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.OpenBattle then
        ForeverSafari.BattleFrame:OpenBattle(opponentTeam[1], false)
    elseif ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:UpdateModels()
        ForeverSafari.BattleFrame:UpdateUI()
    end

    -- Start 15s Action Countdown & Tether Monitor
    BE:StartPvPActionTimer()
    return true
end

-- 15-Second Action Countdown & Spatial Tether Monitor
function BE:StartPvPActionTimer()
    if BE.pvpTimerTicker and BE.pvpTimerTicker.Cancel then
        BE.pvpTimerTicker:Cancel()
    end

    BE.State.pvpActionTimer = 15.0
    if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.StartTurnCountdown then
        ForeverSafari.BattleFrame:StartTurnCountdown(15)
    end

    BE.pvpTimerTicker = C_Timer.NewTicker(1.0, function()
        if not BE.State.inBattle or not BE.State.isPvP then
            if BE.pvpTimerTicker and BE.pvpTimerTicker.Cancel then
                BE.pvpTimerTicker:Cancel()
            end
            return
        end

        -- Check Ambush Spatial Tethers if active
        if BE.State.ambushOpts and BE.State.ambushOpts.isAmbush then
            BE:CheckPvPAmbushTether()
        end

        -- Decrement action timer if awaiting local player action
        if not BE.State.myActionCommit then
            BE.State.pvpActionTimer = BE.State.pvpActionTimer - 1.0
            if BE.State.pvpActionTimer <= 0 then
                BE:ForfeitPvP("ACTION_TIMEOUT")
            end
        end

        if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.UpdateTimerBar then
            ForeverSafari.BattleFrame:UpdateTimerBar(BE.State.pvpActionTimer)
        end
    end)
end

-- Check Ambush Spatial Tether
function BE:CheckPvPAmbushTether()
    local opts = BE.State.ambushOpts
    if not opts or not opts.originX or not opts.originY then return end

    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local x, y = pos:GetXY()

    local dx = (x - opts.originX) * 1000
    local dy = (y - opts.originY) * 1000
    local distSq = dx*dx + dy*dy

    if BE.State.isAttacker then
        -- Attacker must remain within ~25 yards (625 units)
        if distSq > 625 then
            BE:ForfeitPvP("ABANDONED_AMBUSH_PERIMETER")
        end
    else
        -- Defender must be within ~30 yards (900 units) when timer hits 0
        if distSq > 900 and BE.State.pvpActionTimer <= 1.0 then
            BE:ForfeitPvP("FLED_AMBUSH_PERIMETER")
        end
    end
end

-- Commit Player Action (Move or Switch)
function BE:CommitPvPAction(actionType, param)
    if not BE.State.inBattle or not BE.State.isPvP then return end
    if BE.State.myActionCommit then return end -- Already committed

    local actionStr = string.format("%s,%s", actionType, tostring(param))
    local salt = tostring(math.random(100000, 999999))
    local commitTag = Crypto:SHA256(actionStr .. ";" .. salt)

    BE.State.myActionType = actionType
    BE.State.myActionParam = param
    BE.State.myActionStr = actionStr
    BE.State.mySalt = salt
    BE.State.myActionCommit = commitTag

    -- Transmit Commit to Opponent
    if ForeverSafari.Comms and BE.State.opponentName then
        ForeverSafari.Comms:SendTurnCommit(BE.State.opponentName, commitTag)
    end

    BE.State.dialogueText = "Action locked! Awaiting opponent..."
    BE:AddLog("|cff00e5ff[Action Committed]|r Awaiting opponent move selection...|r")

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:UpdateUI()
    end

    -- If opponent commit already received, automatically reveal
    if BE.State.peerCommitTag and not BE.State.myRevealed then
        BE.State.myRevealed = true
        if ForeverSafari.Comms and BE.State.opponentName then
            ForeverSafari.Comms:SendTurnReveal(BE.State.opponentName, actionStr, salt)
        end
    end
end

-- Receive Peer Commit
function BE:OnPeerTurnCommit(sender, commitTag)
    if not BE.State.inBattle or not BE.State.isPvP or sender ~= BE.State.opponentName then return end
    BE.State.peerCommitTag = commitTag

    -- If player already committed, reveal now
    if BE.State.myActionStr and not BE.State.myRevealed then
        BE.State.myRevealed = true
        if ForeverSafari.Comms and BE.State.opponentName then
            ForeverSafari.Comms:SendTurnReveal(BE.State.opponentName, BE.State.myActionStr, BE.State.mySalt)
        end
    end
end

-- Receive Peer Reveal
function BE:OnPeerTurnReveal(sender, data)
    if not BE.State.inBattle or not BE.State.isPvP or sender ~= BE.State.opponentName then return end

    local actionStr, salt = strsplit(";", data, 2)
    local computedHash = Crypto:SHA256(actionStr .. ";" .. salt)

    if computedHash ~= BE.State.peerCommitTag then
        BE:AddLog("|cffff4444[DESYNC ALERT]|r Opponent action hash mismatch! Verification failed.|r")
        return
    end

    BE.State.peerActionStr = actionStr

    -- Both revealed: execute turn resolution
    if BE.State.myRevealed and BE.State.peerActionStr then
        BE:ResolvePvPTurn()
    end
end

-- Deterministic Turn Resolution
function BE:ResolvePvPTurn()
    local myAction = BE.State.myActionStr
    local peerAction = BE.State.peerActionStr
    if not myAction or not peerAction then return end

    local myType, myParam = strsplit(",", myAction)
    local peerType, peerParam = strsplit(",", peerAction)

    local player = BE.State.playerMob
    local enemy = BE.State.enemyMob

    -- 1. Handle Switches First (Switches always have top priority)
    if myType == "SWITCH" then
        local newMob = DB:GetMobById(myParam)
        if newMob and (newMob.currentHP or 0) > 0 then
            BE.State.playerMob = newMob
            BE:InitMoveStates(newMob, "player")
            BE:AddLog(string.format("|cff00ff00[Player Switch]|r Sent out %s!|r", newMob.name))
        end
    end

    if peerType == "SWITCH" then
        -- Find in enemy team
        for _, pet in ipairs(BE.State.enemyTeam or {}) do
            if tostring(pet.id) == peerParam and (pet.currentHP or 0) > 0 then
                BE.State.enemyMob = pet
                BE:InitMoveStates(pet, "enemy")
                BE:AddLog(string.format("|cffff6666[Opponent Switch]|r Opponent sent out %s!|r", pet.name))
                break
            end
        end
    end

    -- 2. Determine Action Speed Priority
    local playerSpd = BE:GetEffectiveSpeed(BE.State.playerMob, "player")
    local enemySpd = BE:GetEffectiveSpeed(BE.State.enemyMob, "enemy")
    local playerFirst = (playerSpd >= enemySpd)

    local function executeAction(isPlayer, aType, aParam)
        if aType == "MOVE" then
            local moveKey = tonumber(aParam) or aParam
            local attacker = isPlayer and BE.State.playerMob or BE.State.enemyMob
            local defender = isPlayer and BE.State.enemyMob or BE.State.playerMob
            local side = isPlayer and "player" or "enemy"
            if attacker and (attacker.currentHP or 0) > 0 and defender and (defender.currentHP or 0) > 0 then
                BE:ExecutePvPMove(attacker, defender, side, moveKey)
            end
        end
    end

    if playerFirst then
        executeAction(true, myType, myParam)
        executeAction(false, peerType, peerParam)
    else
        executeAction(false, peerType, peerParam)
        executeAction(true, myType, myParam)
    end

    -- 3. End-of-Turn Checks & Ticking
    BE:TickRoundBuffsAndHoTs()
    BE.State.turnCount = BE.State.turnCount + 1

    -- Periodic Checkpoint (Every 5 turns)
    if (BE.State.turnCount % 5) == 0 then
        local stateStr = string.format("%d:%d:%d:%d", BE.State.turnCount, BE.State.playerMob.currentHP or 0, BE.State.enemyMob.currentHP or 0, BE.State.rngIndex or 0)
        local stateHash = Crypto:SHA256(stateStr)
        if ForeverSafari.Comms and BE.State.opponentName then
            ForeverSafari.Comms:SendStateCheckpoint(BE.State.opponentName, BE.State.turnCount, stateHash)
        end
    end

    -- Reset Commit-Reveal state for next turn
    BE.State.myActionType = nil
    BE.State.myActionParam = nil
    BE.State.myActionStr = nil
    BE.State.myCommitTag = nil
    BE.State.myRevealed = false
    BE.State.peerCommitTag = nil
    BE.State.peerActionStr = nil
    BE.State.pvpActionTimer = 15.0
    if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.StartTurnCountdown then
        ForeverSafari.BattleFrame:StartTurnCountdown(15)
    end

    if ForeverSafari.BattleFrame then
        ForeverSafari.BattleFrame:UpdateModels()
        ForeverSafari.BattleFrame:UpdateUI()
    end
end

-- Deterministic PvP Move Execution
function BE:ExecutePvPMove(attacker, defender, side, moveKey)
    local move = BE:GetMoveData(moveKey)
    if not move then return end

    local aName = attacker.nickname ~= "" and attacker.nickname or attacker.name
    local dName = defender.nickname ~= "" and defender.nickname or defender.name

    -- 1. Accuracy Roll (PRNG Step 1)
    local accRoll = (BE:NextRNG() * 100)
    local accuracy = move.accuracy or 100
    if accRoll > accuracy then
        BE:AddLog(string.format("%s used %s, but it MISSED!", aName, move.name))
        return
    end

    -- 2. Critical Roll (PRNG Step 2)
    local critRoll = (BE:NextRNG() * 100)
    local critChance = (attacker.resists and attacker.resists.crit) or 5
    local isCrit = (critRoll <= critChance)
    local critMult = isCrit and 1.5 or 1.0

    -- 3. Damage Variance (PRNG Step 3: 85% to 100%)
    local varRoll = 0.85 + (BE:NextRNG() * 0.15)

    -- 4. Status Proc (PRNG Step 4)
    local statusProc = (BE:NextRNG() * 100)

    -- 5. Secondary Mechanic (PRNG Step 5)
    local secondaryRoll = (BE:NextRNG() * 100)

    -- Base Damage Calculation
    local atkStat = attacker.attack or attacker.atk or 20
    local defStat = defender.defense or defender.def or 15
    local movePower = move.power or 15
    local typeAdv = C.GetDamageMultiplier and C.GetDamageMultiplier(move.element or attacker.element or "Beast", defender.element or defender.creatureType or "Beast") or 1.0

    local rawDmg = ((2 * 20 / 5 + 2) * movePower * (atkStat / math.max(1, defStat)) / 50 + 2)
    local finalDmg = math.max(1, math.floor(rawDmg * typeAdv * critMult * varRoll))

    defender.currentHP = math.max(0, (defender.currentHP or defender.maxHP) - finalDmg)
    defender.hp = defender.currentHP

    local critStr = isCrit and " |cffff0000[CRITICAL HIT!]|r" or ""
    BE:AddLog(string.format("%s used |cffffd100%s|r on %s for |cffff4444%d damage|r!%s", aName, move.name, dName, finalDmg, critStr))

    -- Check Faint
    if defender.currentHP <= 0 then
        if side == "player" then
            BE:HandleEnemyFaint()
        else
            BE:HandlePlayerFaint()
        end
    end
end

-- Peer State Checkpoint Verification
function BE:OnPeerCheckpoint(sender, data)
    if not BE.State.inBattle or not BE.State.isPvP or sender ~= BE.State.opponentName then return end
    local turnIndex, peerHash = strsplit(";", data, 2)
    local myStateStr = string.format("%d:%d:%d:%d", tonumber(turnIndex) or 0, BE.State.playerMob.currentHP or 0, BE.State.enemyMob.currentHP or 0, BE.State.rngIndex or 0)
    local myHash = Crypto:SHA256(myStateStr)

    if myHash ~= peerHash then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cffff4444[DESYNC DETECTED]|r Battle simulation diverged at Turn %s! Please resync.|r", C.PREFIX, turnIndex or "5"))
    end
end

-- Forfeit Battle (15s timeout, window closed, or runaway)
function BE:ForfeitPvP(reason)
    if not BE.State.inBattle or not BE.State.isPvP then return end

    if BE.pvpTimerTicker and BE.pvpTimerTicker.Cancel then
        BE.pvpTimerTicker:Cancel()
        BE.pvpTimerTicker = nil
    end
    if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.HideTurnTimer then
        ForeverSafari.BattleFrame:HideTurnTimer()
    end

    local player = BE.State.playerMob
    if player then
        player.currentHP = 0
        player.hp = 0
        player.isFainted = true
    end

    if ForeverSafari.Comms and BE.State.opponentName then
        ForeverSafari.Comms:SendForfeit(BE.State.opponentName, reason)
    end

    BE:AddLog(string.format("|cffff4444[FORFEIT: %s]|r You forfeited the match! Your companion has fainted.|r", reason or "FORFEIT"))
    BE:HandleDefeat()
end

-- Peer Forfeited Match
function BE:OnPeerForfeit(sender, reason)
    if not BE.State.inBattle or not BE.State.isPvP or sender ~= BE.State.opponentName then return end

    if BE.pvpTimerTicker and BE.pvpTimerTicker.Cancel then
        BE.pvpTimerTicker:Cancel()
        BE.pvpTimerTicker = nil
    end
    if ForeverSafari.BattleFrame and ForeverSafari.BattleFrame.HideTurnTimer then
        ForeverSafari.BattleFrame:HideTurnTimer()
    end

    BE:AddLog(string.format("|cff00ff00[OPPONENT FORFEIT]|r %s forfeited the duel (%s)! Victory!|r", sender, reason or "Disconnected"))
    BE:HandleVictory()
end

