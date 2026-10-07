--[[
    Forever Safari: Database - Pet Collection & Squad Manager (DB_Pets.lua)
    Handles companion collection CRUD, party/squad slots, nicknames, attunement progression,
    and trainer grimoire ability unlocks.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Database = ns.Database or {}

local DB = ns.Database
local C = ns.Constants

-- =========================================================================
-- 🐾 COLLECTION & COMPANION LOOKUPS
-- =========================================================================
function DB:GetCollection()
    if not ForeverSafariDB or not ForeverSafariDB.collection then return {} end
    return ForeverSafariDB.collection
end

function DB:GetMobById(id)
    if not ForeverSafariDB or not ForeverSafariDB.collection then return nil end
    for _, mob in ipairs(ForeverSafariDB.collection) do
        if mob.id == id then
            return mob
        end
    end
    return nil
end

function DB:IsReservedRareName(name)
    if not name or not C.RESERVED_RARE_NAMES then return false end
    local lowerName = string.lower(strtrim(name))
    for reserved, _ in pairs(C.RESERVED_RARE_NAMES) do
        if string.lower(reserved) == lowerName then
            return true
        end
    end
    return false
end

function DB:SetMobNickname(mobId, newNickname)
    local mob = self:GetMobById(mobId)
    if not mob then return false, "Companion not found." end

    newNickname = strtrim(newNickname or "")
    if newNickname == "" then
        mob.customNickname = nil
        self:SignMob(mob)
        return true, "Reset to default name."
    end

    if self:IsReservedRareName(newNickname) and not mob.isRare then
        return false, "That name is reserved for authentic wild World Rares!"
    end

    mob.customNickname = string.sub(newNickname, 1, 16)
    self:SignMob(mob)
    return true, "Nickname updated!"
end

function DB:AddMob(mobData, toSquad)
    if not ForeverSafariDB then return nil end
    ForeverSafariDB.collection = ForeverSafariDB.collection or {}

    local newId = #ForeverSafariDB.collection + 1
    mobData.id = newId

    -- Default Attunement values
    mobData.attunementRank = mobData.attunementRank or 1
    mobData.attunementPoints = mobData.attunementPoints or 0
    mobData.acclimationZones = mobData.acclimationZones or {}

    -- Sign companion DNA
    self:SignMob(mobData)
    table.insert(ForeverSafariDB.collection, mobData)

    -- Auto-assign to squad if space is available
    if toSquad or #self:GetSquad() < 4 then
        self:MoveToSquad(newId)
    end

    -- Automatically discover in Bestiary
    if self.DiscoverSpecies then
        self:DiscoverSpecies(mobData.speciesId or mobData.name, "caught")
    end

    return mobData
end

function DB:RemoveMob(id)
    if not ForeverSafariDB or not ForeverSafariDB.collection then return false end
    for i, mob in ipairs(ForeverSafariDB.collection) do
        if mob.id == id then
            -- Remove from team if present
            self:RemoveTeamSlot(id)
            table.remove(ForeverSafariDB.collection, i)
            return true
        end
    end
    return false
end

function DB:AbandonMob(id)
    return self:RemoveMob(id)
end

-- =========================================================================
-- 🌟 ATTUNEMENT & LOYALTY PROGRESSION
-- =========================================================================
function DB:AddAttunement(mobId, points, reason)
    local mob = self:GetMobById(mobId)
    if not mob then return end

    mob.attunementPoints = (mob.attunementPoints or 0) + points
    local curRank = mob.attunementRank or 1
    local rankInfo = C.ATTUNEMENT_RANKS[curRank]

    if curRank < 5 and mob.attunementPoints >= (rankInfo and rankInfo.maxPoints or 1600) then
        mob.attunementRank = curRank + 1
        if ns.Toast and ns.Toast.ShowAttunementUp then
            ns.Toast:ShowAttunementUp(mob, mob.attunementRank)
        end
    end

    self:SignMob(mob)
end

function DB:FeedCompanion(mobId, foodKey)
    local mob = self:GetMobById(mobId)
    if not mob then return false, "not_found", 0 end

    if not foodKey or self:GetItemCount(foodKey) <= 0 then
        return false, "out_of_stock", 0
    end

    local canEat, isFav = false, false
    if ns.ItemDB and ns.ItemDB.CanEatFood then
        canEat, isFav = ns.ItemDB:CanEatFood(mob.family, mob.creatureType, foodKey)
    else
        canEat, isFav = true, true
    end

    if not canEat then
        return false, "refused", 0
    end

    -- Consume 1 item from inventory
    self:RemoveItem(foodKey, 1)

    local bonus = isFav and 25 or 15
    local reason = isFav and "Favorite Safari Diet" or "Safari Sustenance"
    self:AddAttunement(mobId, bonus, reason)

    return true, isFav and "favorite" or "accepted", bonus
end

-- =========================================================================
-- ⚔️ SQUAD & PARTY MANAGEMENT (SLOTS 1 TO 4)
-- =========================================================================
function DB:GetTeam()
    if not ForeverSafariDB then return {} end
    ForeverSafariDB.team = ForeverSafariDB.team or {}
    return ForeverSafariDB.team
end

function DB:GetSquad()
    return self:GetTeam()
end

function DB:GetSquadCount()
    return #self:GetSquad()
end

function DB:IsMobInSquad(mobId)
    local team = self:GetTeam()
    for _, id in ipairs(team) do
        if id == mobId then return true end
    end
    return false
end

function DB:GetActiveMob()
    local team = self:GetTeam()
    local slot = ForeverSafariDB and ForeverSafariDB.activeSlot or 1
    local mobId = team[slot]
    if mobId then
        return self:GetMobById(mobId)
    end
    return nil
end

function DB:SetActiveSlot(slot)
    if not ForeverSafariDB then return end
    ForeverSafariDB.activeSlot = math.max(1, math.min(4, slot or 1))
end

function DB:SetTeamSlot(slotIndex, mobId)
    if not ForeverSafariDB then return end
    ForeverSafariDB.team = ForeverSafariDB.team or {}
    ForeverSafariDB.team[slotIndex] = mobId
end

function DB:SwapTeamSlots(slot1, slot2)
    if not ForeverSafariDB or not ForeverSafariDB.team then return end
    local temp = ForeverSafariDB.team[slot1]
    ForeverSafariDB.team[slot1] = ForeverSafariDB.team[slot2]
    ForeverSafariDB.team[slot2] = temp
end

function DB:RemoveTeamSlot(slotIndexOrMobId)
    if not ForeverSafariDB or not ForeverSafariDB.team then return end
    if type(slotIndexOrMobId) == "number" and slotIndexOrMobId <= 4 then
        table.remove(ForeverSafariDB.team, slotIndexOrMobId)
    else
        for i, id in ipairs(ForeverSafariDB.team) do
            if id == slotIndexOrMobId then
                table.remove(ForeverSafariDB.team, i)
                break
            end
        end
    end
end

function DB:ValidateTeam()
    if not ForeverSafariDB or not ForeverSafariDB.team then return end
    local validTeam = {}
    for _, id in ipairs(ForeverSafariDB.team) do
        if self:GetMobById(id) then
            table.insert(validTeam, id)
        end
    end
    ForeverSafariDB.team = validTeam
end

-- =========================================================================
-- 📜 TRAINER GRIMOIRE & RESEARCH PERMITS
-- =========================================================================
function DB:UnlockAbility(moveKey, sourceMobName, silent)
    if not ForeverSafariDB then return false end
    ForeverSafariDB.unlockedAbilities = ForeverSafariDB.unlockedAbilities or {}

    local key = tostring(moveKey)
    if not ForeverSafariDB.unlockedAbilities[key] then
        ForeverSafariDB.unlockedAbilities[key] = true
        if not silent and ns.Toast and ns.Toast.ShowMoveLearned then
            ns.Toast:ShowMoveLearned(moveKey, sourceMobName)
        end
        return true
    end
    return false
end

function DB:IsAbilityUnlocked(moveKey)
    if not ForeverSafariDB or not ForeverSafariDB.unlockedAbilities then return false end
    return ForeverSafariDB.unlockedAbilities[tostring(moveKey)] == true
end

function DB:GetUnlockedAbilities()
    if not ForeverSafariDB then return {} end
    return ForeverSafariDB.unlockedAbilities or {}
end

function DB:SetMobAbility(mobId, slotIndex, moveKey)
    local mob = self:GetMobById(mobId)
    if not mob then return false, "Companion not found." end
    mob.moves = mob.moves or { 101 }
    mob.moves[slotIndex] = moveKey
    self:SignMob(mob)
    return true
end

function DB:IsTypeUnlocked(creatureType)
    if not ForeverSafariDB or not ForeverSafariDB.unlockedTypes then return false end
    return ForeverSafariDB.unlockedTypes[creatureType] == true
end

function DB:UnlockType(creatureType, silent)
    if not ForeverSafariDB then return false end
    ForeverSafariDB.unlockedTypes = ForeverSafariDB.unlockedTypes or {}
    if not ForeverSafariDB.unlockedTypes[creatureType] then
        ForeverSafariDB.unlockedTypes[creatureType] = true
        if not silent and ns.Toast and ns.Toast.ShowPermitUnlocked then
            ns.Toast:ShowPermitUnlocked(creatureType)
        end
        return true
    end
    return false
end
