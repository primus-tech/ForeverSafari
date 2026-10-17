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

    -- Highlander Law: Exactly 1 active instance of each species per trainer
    if DB and DB.HasSpecies and DB:HasSpecies(enemy.name or enemy.speciesId) then
        return false, string.format("Highlander Law: You already own a %s! You may only bond with one of each species.", enemy.name or "this species")
    end

    -- Total Vault Capacity Limit (2,006 unique species)
    if DB and DB.GetCollection and #DB:GetCollection() >= ((C and C.TOTAL_KENNEL_CAPACITY) or 2006) then
        return false, "Safari Reserve Vault is completely full (2,006/2,006 species captured)!"
    end

    if DB and not DB:IsTypeUnlocked(enemy.creatureType) then
        local permit = C.TYPE_RESEARCH_PERMITS and C.TYPE_RESEARCH_PERMITS[enemy.creatureType]
        local permitName = permit and permit.name or (enemy.creatureType .. " Research Permit")
        return false, string.format("Cannot capture %s! Requires research permit [%s]!", enemy.creatureType, permitName)
    end

    -- ⚡ Saurian Elemental Permit Gate: Thunder Lizards require Elemental Research Permit
    local isThunderLizard = (enemy.family == "Thunder Lizard" or enemy.subFamily == "Thunder Lizard")
    if isThunderLizard and DB and not DB:IsTypeUnlocked("Elemental") then
        local permit = C.TYPE_RESEARCH_PERMITS and C.TYPE_RESEARCH_PERMITS["Elemental"]
        local permitName = permit and permit.name or "Primal Attunement Permit"
        return false, string.format("Cannot capture Thunder Lizards! Requires research permit [%s]!", permitName)
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

-- Calculates capture rate based on HP curve, trap tier, level brackets, and Hunter beastmastery
function BattleCapture:CalculateCaptureRate(enemy, cageId)
    local cageData = (ItemDB and ItemDB:GetCage(cageId)) or { name = "Safari Snare", tier = 1, catchRate = 0.35, color = "ffffff" }
    local hpPct = ((enemy.currentHP or 1) / math.max(1, enemy.maxHP or 1)) * 100
    local targetLevel = enemy.level or 1

    -- 1. Target level bracket (15-level tiers: 1-15, 16-30, 31-45, 46-60)
    local targetBracket = math.max(1, math.min(4, math.ceil(targetLevel / 15)))
    local trapTier = cageData.tier or 1
    local baseCatchRate = cageData.catchRate or 0.35

    -- 2. Health Modifier (50% HP Pivot)
    -- Above 50% HP: 1:1 penalty (-1% per 1% HP above 50%)
    -- Below 50% HP: 2:1 reward (+1% per 2% HP below 50%)
    local hpMod = 0
    if hpPct >= 50 then
        hpMod = -((hpPct - 50.0) / 100.0)
    else
        hpMod = ((50.0 - hpPct) / 2.0) / 100.0
    end

    -- 3. Tier Bracket Mismatch
    -- Higher tier trap on lower bracket: +25% bonus per tier down
    -- Lower tier trap on higher bracket: halves (x0.5) per tier up
    local deltaTier = trapTier - targetBracket
    local tierMod = 0
    local tierUpPenalty = 1.0

    if deltaTier > 0 then
        tierMod = deltaTier * 0.25
    elseif deltaTier < 0 then
        tierUpPenalty = 0.5 ^ math.abs(deltaTier)
    end

    -- 4. Wild Rare Quarry Resistance (-10% flat across the board)
    local isRare = enemy.isRare or enemy.isRareSpawn or (enemy.classification == "rare" or enemy.classification == "rareelite")
    local rareMod = isRare and 0.10 or 0.0

    -- 5. Calculate Base Adjusted Rate before class perks
    local adjustedRate = (baseCatchRate + hpMod + tierMod - rareMod) * tierUpPenalty

    -- 6. Hunter Beastmastery Perk (+25% Multiplicative Multiplier)
    local CP = ns.ClassPassives
    local hunterMult = 1.0
    if CP and CP.GetHunterCaptureMultiplier then
        hunterMult = CP:GetHunterCaptureMultiplier()
    end
    adjustedRate = adjustedRate * hunterMult

    -- Clamped between 0% and 99%
    local finalRate = math.min(0.99, math.max(0.00, adjustedRate))
    return finalRate, cageData, hpPct, isRare
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

    local finalRate, cageData, hpPct, isRare = self:CalculateCaptureRate(enemy, cageId)
    BE.State.dialogueText = string.format("Threw a %s!", cageData.name)
    BE:AddLog(string.format("Threw |cff%s[%s]|r at wild %s!", cageData.color or "ffffff", cageData.name, enemy.name))

    local roll = math.random()

    if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end

    C_Timer.After(1.0, function()
        if finalRate > 0 and roll <= finalRate then
            PlaySound(1195)
            if DB and DB.DiscoverSpecies then
                DB:DiscoverSpecies(enemy.name, "caught")
            end

            local isSquadFull = (DB and DB:GetSquadCount() >= 4)
            local enemyQuality = enemy.quality or (enemy.isBoss and 4) or (enemy.isRareSpawn and 3) or (enemy.isElite and 2) or 1

            if isSquadFull then
                local ok, crateId, crateData = DB:ConsumeBestTransportCrate(enemyQuality)
                local targetBox = DB.GetNextAvailableBox and DB:GetNextAvailableBox() or 1
                enemy.boxId = targetBox
                DB:AddMob(enemy, false)
                local boxName = DB.GetBoxName and DB:GetBoxName(targetBox) or ("Enclosure " .. targetBox)
                local cName = crateData and crateData.name or "Transport Crate"
                BE.State.dialogueText = string.format("Gotcha! %s was caught & crated in %s!", enemy.name, cName)
                BE:AddLog(string.format("|cff00ff00Gotcha! Wild %s was captured, crated in [%s], and sent to %s!|r", enemy.name, cName, boxName))
                if ForeverSafari.Toast then
                    ForeverSafari.Toast:ShowAlert("Captured & Banked", string.format("%s crated & sent to %s!", enemy.name, boxName))
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
            if finalRate <= 0 then
                BE.State.dialogueText = string.format("%s was too healthy or strong for the %s!", enemy.name, cageData.name)
                BE:AddLog(string.format("|cffff4444Wild %s broke free! The %s could not hold it at %d%% HP!|r", enemy.name, cageData.name, math.floor(hpPct)))
            else
                BE.State.dialogueText = string.format("Oh no! %s broke free!", enemy.name)
                BE:AddLog(string.format("|cffff4444Wild %s broke free from the %s! (%d%% catch chance)|r", enemy.name, cageData.name, math.floor(finalRate * 100)))
            end
            if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
            C_Timer.After(1.2, function()
                BE:AdvanceToNextTurn()
            end)
        end
    end)
end
