--[[
    Forever Safari: In-Battle Capture Engine (BattleCapture.lua)
    Handles capture mechanics during active turn-based combat:
    - Snare/Net/Trap tier bonuses and capture probability curves
    - Permit verification for locked creature types (Mechanical, Elemental, Undead, Dragonkin)
    - Transport Crate gating when active squad is at capacity (4/4)
    - Species catalog auto-discovery and kennel shipping
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.BattleCapture = ns.BattleCapture or {}

local BattleCapture = ns.BattleCapture
local C = ns.Constants
local DB = ns.Database
local ItemDB = ns.ItemDB

-- Checks whether an enemy can be legally snared/captured
function BattleCapture:CanCapture(enemy, isTrainerBattle)
    if not enemy then
        return false, "No valid target in battle."
    end

    if isTrainerBattle or enemy.isTrainerPet then
        return false, "You cannot capture another hunter's companion!"
    end

    if enemy.creatureType == "Humanoid" or (C.ELIGIBLE_CAPTURE_TYPES and not C.ELIGIBLE_CAPTURE_TYPES[enemy.creatureType]) then
        return false, "Humanoids and civilized targets cannot be captured!"
    end

    if DB and not DB:IsTypeUnlocked(enemy.creatureType) then
        local permit = C.TYPE_RESEARCH_PERMITS and C.TYPE_RESEARCH_PERMITS[enemy.creatureType]
        local permitName = permit and permit.name or (enemy.creatureType .. " Research Permit")
        return false, string.format("Cannot capture %s! Requires research permit [%s]!", enemy.creatureType, permitName)
    end

    local isSquadFull = (DB and DB:GetSquadCount() >= 4)
    local enemyQuality = enemy.quality or (enemy.isBoss and 4) or (enemy.isRareSpawn and 3) or (enemy.isElite and 2) or 1
    if isSquadFull and DB and not DB:HasTransportCrate(enemyQuality) then
        local crateKey = enemyQuality == 4 and "crate_thorium" or enemyQuality == 3 and "crate_mithril" or enemyQuality == 2 and "crate_iron" or "crate_copper"
        local crateData = ItemDB and ItemDB:GetCrate(crateKey)
        local crateName = crateData and crateData.name or "Transport Crate"
        return false, string.format("Active squad is full (4/4)! You need a %s (or higher) to ship wild catches to the Safari Kennel!", crateName)
    end

    return true, "Eligible"
end

-- Calculates capture rate based on HP curve and snare tier
function BattleCapture:CalculateCaptureRate(enemy, cageId)
    local cageData = (ItemDB and ItemDB:GetCage(cageId)) or { name = "Safari Snare", rateMultiplier = 1.0, color = "ffffff" }
    local hpPct = (enemy.currentHP / math.max(1, enemy.maxHP)) * 100

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

    local mult = cageData.rateMultiplier or 1.0
    local finalRate = math.min(0.99, math.max(0.01, baseRate * mult))
    return finalRate, cageData, hpPct
end

-- Executes the throw action during battle
function BattleCapture:ExecuteCapture(cageId)
    local BE = ns.BattleEngine
    if not BE or not BE.State then return end

    local enemy = BE.State.enemyMob
    if not enemy then return end

    local canCapture, reason = self:CanCapture(enemy, BE.State.isTrainerBattle)
    if not canCapture then
        BE.State.dialogueText = reason
        BE:AddLog("|cffff4444" .. reason .. "|r")
        if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
        return
    end

    -- Deduct snare from Safari Bag
    if DB then DB:RemoveItem(cageId, 1) end

    local finalRate, cageData, hpPct = self:CalculateCaptureRate(enemy, cageId)
    BE.State.dialogueText = string.format("Threw a %s!", cageData.name)
    BE:AddLog(string.format("Threw |cff%s[%s]|r at wild %s!", cageData.color or "ffffff", cageData.name, enemy.name))

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

            local isSquadFull = (DB and DB:GetSquadCount() >= 4)
            local enemyQuality = enemy.quality or (enemy.isBoss and 4) or (enemy.isRareSpawn and 3) or (enemy.isElite and 2) or 1

            if isSquadFull then
                local ok, crateId, crateData = DB:ConsumeBestTransportCrate(enemyQuality)
                DB:AddMob(enemy, false)
                local cName = crateData and crateData.name or "Transport Crate"
                BE.State.dialogueText = string.format("Gotcha! %s was caught & crated in %s!", enemy.name, cName)
                BE:AddLog(string.format("|cff00ff00Gotcha! Wild %s was captured, crated in [%s], and sent to the Safari Kennel!|r", enemy.name, cName))
                if ForeverSafari.Toast then
                    ForeverSafari.Toast:ShowAlert("Captured & Banked", string.format("%s was crated & sent to Banker's Kennel!", enemy.name))
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
