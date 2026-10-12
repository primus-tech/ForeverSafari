-- Forever Safari — Instance Companion Pup Drops
-- Listens for creature deaths inside Instances, Raids, and Battlegrounds.
-- Awards companion pups based on the creature's pupDropRate from CreatureDB.

local addonName, FS = ...
FS = FS or {}
ForeverSafari = FS

local C = FS.Constants or {}
local DB = FS.DB or FS.Database

local InstancePupDrops = CreateFrame("Frame", "FS_InstancePupDropsFrame")
FS.InstancePupDrops = InstancePupDrops

local function OnCombatLogEvent(self)
    local inInstance, instanceType = IsInInstance()
    if not inInstance or not instanceType or instanceType == "none" then
        return
    end

    local timestamp, eventType, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    if eventType ~= "UNIT_DIED" then return end
    if not destGUID or destGUID == "" then return end

    -- Extract creature NPC ID from destGUID
    -- Format: Creature-0-XXXX-XXXX-XXXX-NPCID-XXXX
    local npcIdStr = strmatch(destGUID, "Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    local npcId = tonumber(npcIdStr)
    if not npcId then return end

    local creature = FS:GetCreature(npcId)
    if not creature then return end

    -- Check if creature qualifies for a pup drop
    local dropRate = creature.pupDropRate
    if not dropRate or dropRate <= 0 then
        -- Default fallback drop rates if in instance
        if creature.isBoss or creature.classification == 3 then
            dropRate = 0.20
        elseif creature.classification == 1 or creature.classification == 2 then
            dropRate = 0.05
        else
            dropRate = 0.02
        end
    end

    -- Roll drop chance
    local roll = math.random()
    if roll > dropRate then return end

    -- Drop awarded! Generate companion pup
    local pupName = creature.pupName or (creature.name .. " Pup")
    local moves = creature.moves or {101, 118}
    local baseStats = creature.baseStats or { hp = 50, atk = 16, def = 14, spd = 12 }

    local newPup = {
        name = pupName,
        speciesId = creature.name,
        family = creature.family or "Beast",
        element = creature.element or "Beast",
        spec = creature.spec or "Ferocity",
        level = 1,
        exp = 0,
        maxExp = 100,
        currentHP = baseStats.hp,
        maxHP = baseStats.hp,
        moves = { moves[1], moves[2] }, -- Exactly 2 starter instincts
        moveStates = {
            [moves[1]] = { usesLeft = 15, maxUses = 15 },
            [moves[2]] = { usesLeft = 10, maxUses = 10 },
        },
        origin = string.format("Rescued in %s", GetInstanceInfo() or "Dungeon"),
        ivs = {
            hp = math.random(10, 31),
            atk = math.random(10, 31),
            def = math.random(10, 31),
            spd = math.random(10, 31),
        },
        evs = { hp = 0, atk = 0, def = 0, spd = 0 },
        stats = {
            hp = baseStats.hp,
            atk = baseStats.atk,
            def = baseStats.def,
            spd = baseStats.spd,
        },
    }

    if DB and DB.AddMob then
        DB:AddMob(newPup, false)
    end

    -- Visual & sound fanfare
    PlaySound(1195) -- SOUNDKIT.IG_QUEST_LOG_COMPLETE
    if ForeverSafari.Toast and ForeverSafari.Toast.ShowAlert then
        ForeverSafari.Toast:ShowAlert("Companion Offspring Rescued!", string.format("You rescued a %s!", pupName))
    end

    local prefix = C.PREFIX or "|cff00ffcc[Forever Safari]|r "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "|cff00ff00[PUP DROP]|r You rescued a |cffffcc00" .. pupName .. "|r from " .. (destName or creature.name) .. "!")
end

InstancePupDrops:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
InstancePupDrops:SetScript("OnEvent", OnCombatLogEvent)
