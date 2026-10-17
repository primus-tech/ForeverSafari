--[[
    Forever Safari: In-Battle Capture Engine (BattleCapture.lua)
    Handles capture mechanics during active turn-based combat:
    - Snare/Net/Trap tier bonuses and capture probability curves
    - Permit verification for locked creature types (Mechanical, Elemental, Undead, Dragonkin)
    - Transport Crate gating when active squad is at capacity (4/4)
    - Species catalog auto-discovery and kennel shipping
    - Highlander Law: Player chooses whether to replace existing owned companion or release wild quarry
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.BattleCapture = ns.BattleCapture or {}

local BattleCapture = ns.BattleCapture
local C = ns.Constants
local DB = ns.Database
local ItemDB = ns.ItemDB

-- =========================================================================
-- ⚖️ HIGHLANDER LAW: SPECIES REPLACEMENT CONFIRMATION DIALOG
-- =========================================================================
StaticPopupDialogs["FOREVER_SAFARI_REPLACE_SPECIES"] = {
    text = "%s",
    button1 = "Replace Existing",
    button2 = "Release Wild",
    OnAccept = function(self, data)
        local d = data or self.data
        if d and d.oldMob and d.newMob then
            BattleCapture:ConfirmReplaceSpecies(d.oldMob, d.newMob)
        end
    end,
    OnCancel = function(self, data)
        local d = data or self.data
        if d and d.oldMob and d.newMob then
            BattleCapture:DeclineReplaceSpecies(d.oldMob, d.newMob)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

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

    -- Check if species is already owned (Highlander Law allows capturing to prompt replacement)
    local isOwned, existingMob = false, nil
    if DB and DB.HasSpecies then
        isOwned, existingMob = DB:HasSpecies(enemy.name or enemy.speciesId)
    end

    -- Total Vault Capacity Limit (2,006 unique species)
    -- If already owned, replacing will not increase total collection count
    local totalCap = (C and C.TOTAL_KENNEL_CAPACITY) or 2006
    if not isOwned and DB and DB.GetCollection and #DB:GetCollection() >= totalCap then
        return false, string.format("Safari Reserve Vault is completely full (%d/%d species captured)!", totalCap, totalCap)
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
    local isOwnedInSquad = isOwned and existingMob and DB and DB:IsMobInSquad(existingMob.id)
    local enemyQuality = enemy.quality or (enemy.isBoss and 4) or (enemy.isRareSpawn and 3) or (enemy.isElite and 2) or 1

    -- If replacing an owned squad companion, no transport crate is needed!
    if isSquadFull and not isOwnedInSquad and DB and not DB:HasTransportCrate(enemyQuality) then
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

            -- Check if species is already owned: Highlander Law Prompt
            local isOwned, existingMob = false, nil
            if DB and DB.HasSpecies then
                isOwned, existingMob = DB:HasSpecies(enemy.name or enemy.speciesId)
            end

            if isOwned and existingMob then
                BE.State.inBattle = false
                BE.State.dialogueText = string.format("Captured wild %s! Choose whether to replace your existing companion.", enemy.name)
                BE:AddLog(string.format("|cffffcc00Captured wild %s! You already have an attuned %s. Choose whether to replace or release.|r", enemy.name, existingMob.customNickname or existingMob.name))
                if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end

                BattleCapture:PromptSpeciesReplacement(existingMob, enemy)
                return
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

-- =========================================================================
-- 🐾 HIGHLANDER LAW: SPECIES COMPARISON & REPLACEMENT PROMPT
-- =========================================================================

function BattleCapture:PromptSpeciesReplacement(oldMob, newMob)
    local SE = ns.StatEngine
    local oldSex = oldMob.anatomy or oldMob.gender or "Sire"
    local newSex = newMob.anatomy or newMob.gender or (SE and SE.GetBiologicalSex and SE:GetBiologicalSex(newMob.creatureType or newMob.family)) or "Sire"
    newMob.anatomy = newSex
    newMob.gender = newSex

    local function formatSex(s)
        if s == "Dam" then return "|cffff99cc♀ Dam (Female)|r"
        elseif s == "Sire" then return "|cff66ccff♂ Sire (Male)|r"
        else return "|cffa0a0a0⚙ Genderless|r" end
    end

    local function formatAttunement(mob)
        local pts = tonumber(mob.attunementPoints or mob.attunement) or 0
        local rank = tonumber(mob.attunementRank) or 1
        local title = mob.rank or (C.ATTUNEMENT_RANKS and C.ATTUNEMENT_RANKS[rank] and C.ATTUNEMENT_RANKS[rank].title) or "Untamed"
        return string.format("Rank %d %s (%d pts)", rank, title, pts)
    end

    local function formatMoves(mob)
        local moves = mob.moves or mob.abilities or { 101 }
        local names = {}
        for _, mId in ipairs(moves) do
            local mData = ns.MoveDB and ns.MoveDB:GetMove(mId)
            local mName = mData and mData.name or ("Move #" .. tostring(mId))
            table.insert(names, mName)
        end
        return (#names > 0) and table.concat(names, ", ") or "Basic Attacks"
    end

    local oldName = oldMob.customNickname and string.format("%s (\"%s\")", oldMob.name, oldMob.customNickname) or oldMob.name
    local newName = newMob.name or "Wild Specimen"

    local oldStatsStr = string.format("HP: %d | ATK: %d | DEF: %d | SPD: %d", oldMob.maxHP or oldMob.hp or 0, oldMob.atk or oldMob.attack or 0, oldMob.def or oldMob.defense or 0, oldMob.spd or oldMob.speed or 0)
    local newStatsStr = string.format("HP: %d | ATK: %d | DEF: %d | SPD: %d", newMob.maxHP or newMob.hp or 0, newMob.atk or newMob.attack or 0, newMob.def or newMob.defense or 0, newMob.spd or newMob.speed or 0)

    local promptText = string.format(
        "|cffffd100[HIGHLANDER LAW: DUPLICATE SPECIES]|r\n\n" ..
        "You captured a wild |cffffffff%s|r, but you already own one!\n\n" ..
        "|cffff9900[CURRENT COMPANION]|r\n" ..
        "• Specimen: |cffffffff%s|r\n" ..
        "• Gender: %s\n" ..
        "• Attunement: |cff00ff99%s|r\n" ..
        "• Stats: |cffffffff%s|r\n" ..
        "• Attacks: |cff00ccff%s|r\n\n" ..
        "|cff00ff00[NEW WILD CAPTURE]|r\n" ..
        "• Specimen: |cffffffff%s|r\n" ..
        "• Gender: %s\n" ..
        "• Attunement: |cff00ff99%s|r\n" ..
        "• Stats: |cffffffff%s|r\n" ..
        "• Attacks: |cff00ccff%s|r\n\n" ..
        "Do you want to |cffff4444REPLACE|r your existing companion with this new specimen?",
        newMob.name,
        oldName, formatSex(oldSex), formatAttunement(oldMob), oldStatsStr, formatMoves(oldMob),
        newName, formatSex(newSex), formatAttunement(newMob), newStatsStr, formatMoves(newMob)
    )

    local dialog = StaticPopup_Show("FOREVER_SAFARI_REPLACE_SPECIES", promptText)
    if dialog then
        dialog.data = { oldMob = oldMob, newMob = newMob }
    end
end

function BattleCapture:ConfirmReplaceSpecies(oldMob, newMob)
    if not oldMob or not newMob then return end
    local BE = ns.BattleEngine

    -- If existing mob was in kennel and squad is full, consume transport crate
    local isSquadFull = (DB and DB:GetSquadCount() >= 4)
    local wasInSquad = DB and DB:IsMobInSquad(oldMob.id)
    if isSquadFull and not wasInSquad and DB and DB.ConsumeBestTransportCrate then
        local enemyQuality = newMob.quality or (newMob.isBoss and 4) or (newMob.isRareSpawn and 3) or (newMob.isElite and 2) or 1
        DB:ConsumeBestTransportCrate(enemyQuality)
    end

    local ok, replaced = DB:ReplaceMob(oldMob.id, newMob)
    if ok then
        local oldDispName = oldMob.customNickname and string.format("%s (\"%s\")", oldMob.name, oldMob.customNickname) or oldMob.name
        local msg = string.format("%s|cff00ff00[Highlander Replacement]|r Replaced |cffffd100%s|r with wild |cff00ff99%s|r!", C.PREFIX, oldDispName, newMob.name)
        DEFAULT_CHAT_FRAME:AddMessage(msg)

        if BE and BE.State then
            BE.State.dialogueText = string.format("Replaced %s with wild %s!", oldDispName, newMob.name)
            BE:AddLog(string.format("|cff00ff00[Highlander Replacement]|r Replaced %s with wild %s!|r", oldDispName, newMob.name))
        end

        if ForeverSafari.Toast and ForeverSafari.Toast.ShowReward then
            ForeverSafari.Toast:ShowReward("Species Replaced", string.format("Swapped %s for %s", oldMob.name, newMob.name))
        end
    end

    if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
end

function BattleCapture:DeclineReplaceSpecies(oldMob, newMob)
    if not oldMob or not newMob then return end
    local BE = ns.BattleEngine
    local oldDispName = oldMob.customNickname and string.format("%s (\"%s\")", oldMob.name, oldMob.customNickname) or oldMob.name

    local msg = string.format("%s|cffffcc00[Highlander Retained]|r Retained existing |cffffd100%s|r. Wild |cffffffff%s|r was released back into the wild.", C.PREFIX, oldDispName, newMob.name)
    DEFAULT_CHAT_FRAME:AddMessage(msg)

    if BE and BE.State then
        BE.State.dialogueText = string.format("Released wild %s back into the wild. Kept %s.", newMob.name, oldDispName)
        BE:AddLog(string.format("|cffffcc00[Highlander Retained]|r Kept existing %s. Released wild %s.|r", oldDispName, newMob.name))
    end

    if ForeverSafari.BattleFrame then ForeverSafari.BattleFrame:UpdateUI() end
end
