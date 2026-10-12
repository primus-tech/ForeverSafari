-- Forever Safari — Master Creature Database
-- Target: World of Warcraft Forever Beta (1.60.1)
-- Integrates partitioned registries (Beast Subfamilies, Dragonkin, Elementals, Mechanicals, Undead, Other)
-- with Master Zone classification and Encounter / Pup Drop taxonomy.

local _, FS = ...
FS = FS or {}
ForeverSafari = FS

FS.CreatureDB = FS.CreatureDB or {}
FS.ZoneIndex = FS.ZoneIndex or {}
FS.FamilyIndex = FS.FamilyIndex or {}
FS.SubFamilyIndex = FS.SubFamilyIndex or {}
FS.ElementIndex = FS.ElementIndex or {}
FS.AcquisitionIndex = FS.AcquisitionIndex or { BATTLE = {}, PUP_DROP = {}, HYBRID = {} }

-- 1. Merge Partition Registries into Master CreatureDB
local partitions = {
    -- Beast Subfamilies
    FS.Creatures_Beasts_Aquatic,
    FS.Creatures_Beasts_Basilisk,
    FS.Creatures_Beasts_Bat,
    FS.Creatures_Beasts_Bear,
    FS.Creatures_Beasts_BirdofPrey,
    FS.Creatures_Beasts_Boar,
    FS.Creatures_Beasts_CarrionBird,
    FS.Creatures_Beasts_Cat,
    FS.Creatures_Beasts_Chimaera,
    FS.Creatures_Beasts_CoreHound,
    FS.Creatures_Beasts_Crab,
    FS.Creatures_Beasts_Crocolisk,
    FS.Creatures_Beasts_Devilsaur,
    FS.Creatures_Beasts_Dinosaur,
    FS.Creatures_Beasts_Fox,
    FS.Creatures_Beasts_Gorilla,
    FS.Creatures_Beasts_Hydra,
    FS.Creatures_Beasts_Hyena,
    FS.Creatures_Beasts_Kodo,
    FS.Creatures_Beasts_Raptor,
    FS.Creatures_Beasts_Scorpid,
    FS.Creatures_Beasts_Serpent,
    FS.Creatures_Beasts_Silithid,
    FS.Creatures_Beasts_Spider,
    FS.Creatures_Beasts_Stag,
    FS.Creatures_Beasts_Tallstrider,
    FS.Creatures_Beasts_Turtle,
    FS.Creatures_Beasts_WindSerpent,
    FS.Creatures_Beasts_Wolf,
    FS.Creatures_Beasts_Worm,

    -- Other Families
    FS.Creatures_Dragonkin,
    FS.Creatures_Elementals,
    FS.Creatures_Mechanicals,
    FS.Creatures_Undead,
}

for _, partition in ipairs(partitions) do
    if partition then
        for npcId, entry in pairs(partition) do
            FS.CreatureDB[npcId] = entry
        end
    end
end

-- 2. Build In-Memory Search & Location Indexes
function FS:BuildDatabaseIndexes()
    wipe(self.ZoneIndex)
    wipe(self.FamilyIndex)
    wipe(self.SubFamilyIndex)
    wipe(self.ElementIndex)
    self.AcquisitionIndex = { BATTLE = {}, PUP_DROP = {}, HYBRID = {} }

    for npcId, entry in pairs(self.CreatureDB) do
        -- Backwards compatibility for abilities / moves
        if entry.moves and not entry.abilities then
            entry.abilities = entry.moves
        end
        if entry.family then
            self.FamilyIndex[entry.family] = self.FamilyIndex[entry.family] or {}
            table.insert(self.FamilyIndex[entry.family], npcId)
        end
        if entry.subFamily then
            self.SubFamilyIndex[entry.subFamily] = self.SubFamilyIndex[entry.subFamily] or {}
            table.insert(self.SubFamilyIndex[entry.subFamily], npcId)
        end
        if entry.element then
            self.ElementIndex[entry.element] = self.ElementIndex[entry.element] or {}
            table.insert(self.ElementIndex[entry.element], npcId)
        end
        if entry.acquisition and self.AcquisitionIndex[entry.acquisition] then
            table.insert(self.AcquisitionIndex[entry.acquisition], npcId)
        end
        if entry.zones then
            for _, zoneId in ipairs(entry.zones) do
                self.ZoneIndex[zoneId] = self.ZoneIndex[zoneId] or {}
                table.insert(self.ZoneIndex[zoneId], npcId)
            end
        end
    end
end

FS:BuildDatabaseIndexes()

-- 3. Public Query & Encounter APIs

function FS:GetCreature(npcId)
    return self.CreatureDB and self.CreatureDB[npcId]
end

function FS:GetCreaturesInZone(zoneId)
    return (self.ZoneIndex and self.ZoneIndex[zoneId]) or {}
end

function FS:GetCreaturesByFamily(family)
    return (self.FamilyIndex and self.FamilyIndex[family]) or {}
end

function FS:GetCreaturesBySubFamily(subFamily)
    return (self.SubFamilyIndex and self.SubFamilyIndex[subFamily]) or {}
end

function FS:GetCreaturesByElement(element)
    return (self.ElementIndex and self.ElementIndex[element]) or {}
end

function FS:IsInstanceOnly(npcId)
    local creature = self:GetCreature(npcId)
    return creature and (creature.isInstanceOnly == true or creature.acquisition == "PUP_DROP")
end

function FS:CanEncounterInBattle(npcId)
    local creature = self:GetCreature(npcId)
    return creature and (creature.allowBattle == true or creature.acquisition == "BATTLE" or creature.acquisition == "HYBRID")
end

function FS:CanObserve(npcId)
    local creature = self:GetCreature(npcId)
    return creature and (creature.allowObservation == true)
end

function FS:GetPupDropInfo(npcId)
    local creature = self:GetCreature(npcId)
    if not creature or not creature.pupDropRate or creature.pupDropRate <= 0 then
        return nil
    end
    return {
        dropRate = creature.pupDropRate,
        pupName = creature.pupName or (creature.name .. " Pup"),
        isBoss = creature.isBoss or (creature.classification == 3),
        family = creature.family,
        subFamily = creature.subFamily,
        spec = creature.spec,
        moves = creature.moves,
    }
end

function FS:GetZoneInfo(zoneId)
    return self.ZoneRegistry and self.ZoneRegistry[zoneId]
end

function FS:IsInstanceZone(zoneId)
    local z = self:GetZoneInfo(zoneId)
    return z and (z.isInstance == true)
end
