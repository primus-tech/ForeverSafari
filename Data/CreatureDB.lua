-- Forever Safari — Master Creature Database
-- Target: World of Warcraft Forever Beta (1.60.1)
-- Integrates partitioned registries (Beasts, Dragonkin, Elementals, Mechanicals, Undead, Other)
-- with Master Zone classification and Encounter / Pup Drop taxonomy.

local _, FS = ...
FS = FS or {}
ForeverSafari = FS

FS.CreatureDB = FS.CreatureDB or {}
FS.ZoneIndex = FS.ZoneIndex or {}
FS.FamilyIndex = FS.FamilyIndex or {}
FS.ElementIndex = FS.ElementIndex or {}
FS.AcquisitionIndex = FS.AcquisitionIndex or { BATTLE = {}, PUP_DROP = {}, HYBRID = {} }

-- 1. Merge Partition Registries into Master CreatureDB
local partitions = {
    FS.Creatures_Beasts,
    FS.Creatures_Dragonkin,
    FS.Creatures_Elementals,
    FS.Creatures_Mechanicals,
    FS.Creatures_Undead,
    FS.Creatures_Other,
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
    wipe(self.ElementIndex)
    self.AcquisitionIndex = { BATTLE = {}, PUP_DROP = {}, HYBRID = {} }

    for npcId, entry in pairs(self.CreatureDB) do
        if entry.family then
            self.FamilyIndex[entry.family] = self.FamilyIndex[entry.family] or {}
            table.insert(self.FamilyIndex[entry.family], npcId)
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
