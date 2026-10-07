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
    local collection = self:GetCollection()
    local healedCount = 0
    for _, mob in ipairs(collection) do
        mob.currentHP = nil -- Full HP reset
        mob.isFainted = false
        healedCount = healedCount + 1
    end
    return healedCount
end
