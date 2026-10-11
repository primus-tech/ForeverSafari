--[[
    Forever Safari: Cryptographic Integrity & Anti-Tamper Engine
    Manages HMAC-style hash signatures, anti-cheat validation,
    and Base64 DNA compression for in-game link sharing.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Crypto = ns.Crypto or {}

local Crypto = ns.Crypto

local SECRET_SALT = "ForeverSafari_Nesingwary_League_2026_Secure"
local B64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function Crypto:Hash(str)
    local hash = 2166136261
    local prime = 16777619
    local combined = tostring(str) .. ":" .. SECRET_SALT
    for i = 1, #combined do
        local byte = string.byte(combined, i)
        hash = (hash + byte) * prime
        hash = hash % 4294967296
    end
    return string.format("%08x", hash)
end

function Crypto:GenerateSignature(mob)
    if not mob then return "" end
    local str = string.format("%s:%s:%d:%d:%d:%d:%d:%s",
        tostring(mob.id or 0),
        tostring(mob.name or ""),
        tonumber(mob.level or 1),
        tonumber(mob.hp or 10),
        tonumber(mob.attack or 5),
        tonumber(mob.defense or 5),
        tonumber(mob.speed or 5),
        tostring(mob.displayId or 0)
    )
    return self:Hash(str)
end

function Crypto:SignMob(mob)
    if not mob then return end
    mob.sig = self:GenerateSignature(mob)
    return mob
end

function Crypto:ValidateSignature(mob)
    if not mob or not mob.sig then return false end
    return mob.sig == self:GenerateSignature(mob)
end

function Crypto:ValidateAndRepairSignatures(collection)
    if not collection then return end

    for _, mob in ipairs(collection) do
        -- Ensure default moves
        if not mob.moves or #mob.moves == 0 then
            mob.moves = { 101, 107, 102, 118 }
        end

        -- Promote starter companion to Rank 3 (Trusting) baseline if below threshold
        if (mob.isStarter or (mob.customNickname and string.find(mob.customNickname, "^Starter"))) and (mob.attunementRank or 1) < 3 then
            mob.attunementRank = 3
            mob.attunementPoints = math.max(mob.attunementPoints or 0, 600)
            mob.rank = "Trusting"
            mob.isStarter = true
            local SE = ns.StatEngine
            if SE and mob.baseStats then
                local calc = SE:CalculateStats(mob.element or mob.creatureType or "Beast", 600, false, mob.baseStats)
                mob.maxHP = calc.maxHP
                mob.currentHP = calc.maxHP
                mob.hp = calc.maxHP
                mob.atk = calc.atk
                mob.attack = calc.atk
                mob.def = calc.def
                mob.defense = calc.def
                mob.spd = calc.spd
                mob.speed = calc.spd
            end
        end

        local expectedSig = self:GenerateSignature(mob)
        if not mob.sig or mob.sig ~= expectedSig then
            if not mob.maxHP or mob.maxHP <= 0 then
                mob.maxHP = mob.hp or 60
            end
            if not mob.currentHP or mob.currentHP > mob.maxHP then
                mob.currentHP = mob.maxHP
            end
            mob.hp = mob.currentHP
            self:SignMob(mob)
        else
            if not mob.maxHP or mob.maxHP <= 0 then
                mob.maxHP = mob.hp or 60
            end
            if mob.currentHP == nil then
                mob.currentHP = mob.maxHP
            end
            mob.hp = mob.currentHP
        end
    end
end

function Crypto:EncodeBase64(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return B64_CHARS:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function Crypto:DecodeBase64(data)
    data = string.gsub(data, '[^'..B64_CHARS..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(B64_CHARS:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function Crypto:ExportCompanionDNA(mob)
    if not mob then return "" end
    local movesStr = table.concat(mob.moves or {}, ",")
    local raw = string.format("%s~%s~%d~%d~%d~%d~%d~%d~%s~%s~%s",
        tostring(mob.name or "Wild Mob"),
        tostring(mob.customNickname or mob.name or "Wild Mob"),
        tonumber(mob.level or 1),
        tonumber(mob.hp or 10),
        tonumber(mob.attack or 5),
        tonumber(mob.defense or 5),
        tonumber(mob.speed or 5),
        tonumber(mob.displayId or 903),
        tostring(mob.family or "Canine"),
        movesStr,
        tostring(mob.sig or "")
    )
    return "!FS:" .. self:EncodeBase64(raw)
end

function Crypto:ImportCompanionDNA(dnaStr)
    if not dnaStr or not dnaStr:find("^!FS:") then return nil end
    local b64 = dnaStr:sub(5)
    local raw = self:DecodeBase64(b64)
    if not raw or raw == "" then return nil end

    local parts = {}
    for part in string.gmatch(raw, "[^~]+") do
        table.insert(parts, part)
    end
    if #parts < 8 then return nil end

    local moves = {}
    if parts[10] and parts[10] ~= "" then
        for mv in string.gmatch(parts[10], "[^,]+") do
            table.insert(moves, tonumber(mv) or mv)
        end
    end

    return {
        name = parts[1],
        customNickname = parts[2],
        level = tonumber(parts[3]) or 1,
        hp = tonumber(parts[4]) or 10,
        maxHp = tonumber(parts[4]) or 10,
        attack = tonumber(parts[5]) or 5,
        defense = tonumber(parts[6]) or 5,
        speed = tonumber(parts[7]) or 5,
        displayId = tonumber(parts[8]) or 903,
        family = parts[9] or "Canine",
        moves = moves,
        sig = parts[11] or ""
    }
end
