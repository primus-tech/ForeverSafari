--[[
    Forever Safari: Database - Kennel Storage & Transport Logistics (DB_Kennel.lua)
    Handles Enclosure Storage Boxes (1-10), transfers between squad and kennel,
    transport crate consumption, and squad resting at Inns.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Database = ns.Database or {}

local DB = ns.Database
local C = ns.Constants

-- =========================================================================
-- 📦 KENNEL ENCLOSURE BOXES & SQUAD SWAPPING
-- =========================================================================
function DB:GetKennelMobs(boxId)
    local collection = self:GetCollection()
    local team = self:GetTeam()
    local teamMap = {}
    for _, id in ipairs(team) do
        teamMap[id] = true
    end

    local kennelMobs = {}
    for _, mob in ipairs(collection) do
        if not teamMap[mob.id] then
            if not boxId or (mob.boxId or 1) == boxId then
                table.insert(kennelMobs, mob)
            end
        end
    end
    return kennelMobs
end

function DB:GetBoxName(boxId)
    boxId = tonumber(boxId) or 1
    if ForeverSafariDB and ForeverSafariDB.boxNames and ForeverSafariDB.boxNames[boxId] then
        return ForeverSafariDB.boxNames[boxId]
    end
    return string.format("Enclosure %d", boxId)
end

function DB:SetBoxName(boxId, name)
    boxId = tonumber(boxId) or 1
    if not ForeverSafariDB then return end
    ForeverSafariDB.boxNames = ForeverSafariDB.boxNames or {}
    ForeverSafariDB.boxNames[boxId] = (name and name ~= "") and name or nil
    self:MarkDirty()
end

function DB:GetBoxCapacity(boxId)
    boxId = tonumber(boxId) or 1
    local maxBoxes = (C and C.MAX_KENNEL_BOXES) or 101
    local maxPerBox = (C and C.SLOTS_PER_BOX) or 20
    local totalCap = (C and C.TOTAL_KENNEL_CAPACITY) or 2006
    if boxId >= maxBoxes then
        local remainder = totalCap - ((maxBoxes - 1) * maxPerBox)
        return (remainder > 0) and remainder or maxPerBox
    end
    return maxPerBox
end

function DB:GetNextAvailableBox(preferredBox)
    local maxBoxes = (C and C.MAX_KENNEL_BOXES) or 101

    if preferredBox and preferredBox >= 1 and preferredBox <= maxBoxes then
        local count = #self:GetKennelMobs(preferredBox)
        local cap = self:GetBoxCapacity(preferredBox)
        if count < cap then
            return preferredBox
        end
    end

    for b = 1, maxBoxes do
        local count = #self:GetKennelMobs(b)
        local cap = self:GetBoxCapacity(b)
        if count < cap then
            return b
        end
    end

    return 1
end

function DB:GetFilteredKennelMobs(boxId, searchQuery, familyFilter, sexFilter, rarityFilter)
    local mobs = self:GetKennelMobs(boxId)
    local hasQuery = searchQuery and searchQuery ~= ""
    local hasFam = familyFilter and familyFilter ~= "ALL"
    local hasSex = sexFilter and sexFilter ~= "ALL"
    local hasRare = rarityFilter and rarityFilter ~= "ALL"

    if not hasQuery and not hasFam and not hasSex and not hasRare then
        return mobs
    end

    local filtered = {}
    local q = hasQuery and string.lower(strtrim(searchQuery)) or ""

    for _, mob in ipairs(mobs) do
        local pass = true

        if q ~= "" then
            local nameMatch = mob.name and string.find(string.lower(mob.name), q, 1, true)
            local nickMatch = mob.nickname and string.find(string.lower(mob.nickname), q, 1, true)
            if not nameMatch and not nickMatch then
                pass = false
            end
        end

        if pass and hasFam then
            local matchType = (mob.creatureType == familyFilter)
            local matchFam = (mob.family == familyFilter)
            if not matchType and not matchFam then
                pass = false
            end
        end

        if pass and hasSex then
            local anat = mob.anatomy or "Sire"
            if anat ~= sexFilter then
                pass = false
            end
        end

        if pass and hasRare then
            if rarityFilter == "RARE" and not mob.isRare and not mob.isElite then
                pass = false
            elseif rarityFilter == "COMMON" and (mob.isRare or mob.isElite) then
                pass = false
            end
        end

        if pass then
            table.insert(filtered, mob)
        end
    end

    return filtered
end

DB.GetKennelBox = DB.GetKennelMobs

function DB:MoveToSquad(mobId, targetSlot)
    local team = self:GetTeam()
    if #team >= 4 and not targetSlot then
        return false, "Your active squad is full (4/4)!"
    end

    -- Check if already in squad
    for _, id in ipairs(team) do
        if id == mobId then
            return false, "Companion is already in your active squad."
        end
    end

    if targetSlot and targetSlot >= 1 and targetSlot <= 4 then
        team[targetSlot] = mobId
    else
        table.insert(team, mobId)
    end
    self:MarkDirty()
    return true
end

function DB:MoveToKennel(mobId, targetBox)
    local mob = self:GetMobById(mobId)
    if not mob then return false, "Companion not found." end

    local team = self:GetTeam()
    if #team <= 1 and self:IsMobInSquad(mobId) then
        return false, "You must keep at least 1 companion in your active squad!"
    end

    self:RemoveTeamSlot(mobId)
    mob.boxId = targetBox or 1
    self:MarkDirty()
    return true
end

function DB:SwapSquadAndKennel(squadSlot, kennelMobId)
    local team = self:GetTeam()
    local currentSquadMobId = team[squadSlot]
    local kennelMob = self:GetMobById(kennelMobId)

    if not kennelMob then return false, "Kennel companion not found." end

    if currentSquadMobId then
        local squadMob = self:GetMobById(currentSquadMobId)
        if squadMob then
            squadMob.boxId = kennelMob.boxId or 1
        end
    end

    team[squadSlot] = kennelMobId
    self:MarkDirty()
    return true
end

-- =========================================================================
-- 🚚 TRANSPORT CRATE LOGISTICS
-- =========================================================================
function DB:HasTransportCrate(requiredQuality)
    local req = requiredQuality or 1
    local inventory = self:GetInventory()

    if req <= 1 and (inventory["copper_crate"] or 0) > 0 then return true, "copper_crate" end
    if req <= 2 and (inventory["iron_crate"] or 0) > 0 then return true, "iron_crate" end
    if req <= 3 and (inventory["mithril_crate"] or 0) > 0 then return true, "mithril_crate" end
    if req <= 4 and (inventory["thorium_crate"] or 0) > 0 then return true, "thorium_crate" end

    return false, nil
end

function DB:ConsumeBestTransportCrate(requiredQuality)
    local hasCrate, crateKey = self:HasTransportCrate(requiredQuality)
    if hasCrate and crateKey then
        self:RemoveItem(crateKey, 1)
        return true, crateKey
    end
    return false, nil
end

-- =========================================================================
-- 💖 INNKEEPER REST & TEND
-- =========================================================================
function DB:RestAllPets()
    if self.HealAllPets then
        return self:HealAllPets(false)
    end
    local collection = self:GetCollection()
    local healedCount = 0
    for _, mob in ipairs(collection) do
        mob.currentHP = mob.maxHP or mob.hp or 40
        mob.isFainted = false
        healedCount = healedCount + 1
    end
    return healedCount
end

-- =========================================================================
-- 🗄️ 20-CHUNK KENNEL STORAGE INTERFACE (19 x 100 + 1 x 106 = 2,006 SLOTS)
-- =========================================================================
function DB:GetKennelChunk(chunkId)
    chunkId = tonumber(chunkId) or 1
    if ForeverSafariKennel and ForeverSafariKennel[chunkId] then
        return ForeverSafariKennel[chunkId]
    end
    if ForeverSafariDB and ForeverSafariDB.kennelChunks and ForeverSafariDB.kennelChunks[chunkId] then
        return ForeverSafariDB.kennelChunks[chunkId]
    end
    return {}
end

function DB:GetKennelChunkCount()
    return (C and C.KENNEL_CHUNKS_COUNT) or 20
end

function DB:GetKennelChunkCapacity(chunkId)
    chunkId = tonumber(chunkId) or 1
    if chunkId == 20 then
        return (C and C.KENNEL_FINAL_CHUNK_SIZE) or 106
    end
    return (C and C.KENNEL_CHUNK_SIZE) or 100
end

function DB:GetKennelChunkMob(chunkId, slot)
    local chunk = self:GetKennelChunk(chunkId)
    return chunk and chunk[slot] or nil
end

