--[[
    Forever Safari: Database - Azeroth Pokédex Bestiary Tracker (DB_Bestiary.lua)
    Tracks 3-tier discovery states (unseen -> seen -> caught), Pokédex completion rates,
    and automatic collection backfilling.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Database = ns.Database or {}

local DB = ns.Database

-- =========================================================================
-- 📖 BESTIARY POKÉDEX DISCOVERY & STATUS
-- =========================================================================
function DB:GetBestiary()
    if not ForeverSafariDB then return {} end
    if not ForeverSafariDB.bestiary then
        ForeverSafariDB.bestiary = {}
    end
    return ForeverSafariDB.bestiary
end

function DB:GetBestiaryEntry(speciesId)
    local bestiary = self:GetBestiary()
    return bestiary[speciesId]
end

function DB:DiscoverSpecies(nameOrId, status)
    if not nameOrId then return nil end
    local BestiaryDB = ns.BestiaryDB
    if not BestiaryDB then return nil end

    local spec = nil
    if type(nameOrId) == "number" then
        spec = BestiaryDB:GetSpecies(nameOrId)
    else
        spec = BestiaryDB:FindSpeciesByName(nameOrId)
    end

    if not spec then return nil end

    local bestiary = self:GetBestiary()
    local existing = bestiary[spec.id]
    local now = time and time() or 0

    if not existing then
        bestiary[spec.id] = {
            id = spec.id,
            name = spec.name,
            status = status or "seen",
            firstSeen = now,
            firstCaught = (status == "caught") and now or nil,
            caughtCount = (status == "caught") and 1 or 0,
        }
        if ns.Toast and ns.Toast.ShowBestiaryDiscovery then
            ns.Toast:ShowBestiaryDiscovery(spec, status or "seen")
        end
        return bestiary[spec.id]
    else
        if status == "caught" then
            if existing.status ~= "caught" then
                existing.status = "caught"
                existing.firstCaught = now
                if ns.Toast and ns.Toast.ShowBestiaryDiscovery then
                    ns.Toast:ShowBestiaryDiscovery(spec, "caught")
                end
            end
            existing.caughtCount = (existing.caughtCount or 0) + 1
        end
        return existing
    end
end

function DB:GetBestiaryStats()
    local BestiaryDB = ns.BestiaryDB
    local all = BestiaryDB and BestiaryDB:GetAllSpecies() or {}
    local total = #all
    local seen = 0
    local caught = 0

    local bestiary = self:GetBestiary()
    for _, entry in pairs(bestiary) do
        if entry.status == "caught" then
            caught = caught + 1
            seen = seen + 1
        elseif entry.status == "seen" then
            seen = seen + 1
        end
    end

    return {
        total = total,
        seen = seen,
        caught = caught,
        pctCaught = total > 0 and math.floor((caught / total) * 100) or 0,
        pctSeen = total > 0 and math.floor((seen / total) * 100) or 0,
    }
end

function DB:BackfillBestiaryFromCollection()
    local collection = self:GetCollection()
    for _, mob in ipairs(collection) do
        if mob.speciesId then
            self:DiscoverSpecies(mob.speciesId, "caught")
        elseif mob.name then
            self:DiscoverSpecies(mob.name, "caught")
        end
    end
end
