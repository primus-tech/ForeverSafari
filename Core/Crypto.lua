--[[
    Forever Safari: Cryptographic Integrity, Vault Cipher & Anti-Tamper Engine
    Provides:
      - Pure-Lua SHA-256 and HMAC-SHA256 (RFC 2104) with WoW bit-library acceleration
      - Context-separated HMAC Key Derivation (K_encrypt, K_mac)
      - XXTEA 32-bit Block Obfuscation/Encryption
      - Base64 ASCII Armoring for Blizzard SavedVariables compatibility
      - Authenticated Envelope generation & verification (Encrypt-then-MAC)
      - Companion DNA import/export & signature verification
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Crypto = ns.Crypto or {}

local Crypto = ns.Crypto

local SECRET_SALT = "ForeverSafari_Nesingwary_League_2026_Secure"
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- Cache native bit functions for maximum performance
local band   = bit.band
local bor    = bit.bor
local bxor   = bit.bxor
local bnot   = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift

-- 32-bit rotate right helper (WoW native bit table does not implement bit.ror)
local function ror(x, n)
    return bor(rshift(x, n), lshift(x, 32 - n))
end

local function bxor3(a, b, c)
    return bxor(bxor(a, b), c)
end

-- =========================================================================
-- 🔐 SHA-256 & HMAC-SHA256 ENGINE (Pure Lua 5.1 + bit)
-- =========================================================================

local SHA256_K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

local function sha256_core(msg)
    local msgLen = #msg
    local bitLen = msgLen * 8

    -- Padding: Append 0x80, then zeros until len % 64 == 56
    local padLen = (56 - (msgLen + 1) % 64) % 64
    local padParts = { msg, "\128", string.rep("\0", padLen) }

    -- Append 64-bit big-endian length (upper 32 bits = 0 for messages under 512MB)
    local highBits = math.floor(bitLen / 4294967296) % 4294967296
    local lowBits  = bitLen % 4294967296
    table.insert(padParts, string.char(
        band(rshift(highBits, 24), 0xFF),
        band(rshift(highBits, 16), 0xFF),
        band(rshift(highBits, 8), 0xFF),
        band(highBits, 0xFF),
        band(rshift(lowBits, 24), 0xFF),
        band(rshift(lowBits, 16), 0xFF),
        band(rshift(lowBits, 8), 0xFF),
        band(lowBits, 0xFF)
    ))

    local padded = table.concat(padParts)
    local totalLen = #padded

    local H0 = 0x6a09e667
    local H1 = 0xbb67ae85
    local H2 = 0x3c6ef372
    local H3 = 0xa54ff53a
    local H4 = 0x510e527f
    local H5 = 0x9b05688c
    local H6 = 0x1f83d9ab
    local H7 = 0x5be0cd19

    local W = {}
    for i = 1, 64 do W[i] = 0 end

    for chunkStart = 1, totalLen, 64 do
        -- Read 16 32-bit big-endian words
        for t = 1, 16 do
            local idx = chunkStart + (t - 1) * 4
            local b1, b2, b3, b4 = string.byte(padded, idx, idx + 3)
            W[t] = bor(lshift(b1, 24), lshift(b2, 16), lshift(b3, 8), b4)
        end

        -- Extend the first 16 words into the remaining 48 words
        for t = 17, 64 do
            local w15 = W[t - 15]
            local s0 = bxor3(ror(w15, 7), ror(w15, 18), rshift(w15, 3))
            local w2 = W[t - 2]
            local s1 = bxor3(ror(w2, 17), ror(w2, 19), rshift(w2, 10))
            W[t] = (W[t - 16] + s0 + W[t - 7] + s1) % 4294967296
        end

        local a = H0
        local b = H1
        local c = H2
        local d = H3
        local e = H4
        local f = H5
        local g = H6
        local h = H7

        for t = 1, 64 do
            local S1 = bxor3(ror(e, 6), ror(e, 11), ror(e, 25))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local temp1 = (h + S1 + ch + SHA256_K[t] + W[t]) % 4294967296
            local S0 = bxor3(ror(a, 2), ror(a, 13), ror(a, 22))
            local maj = bxor3(band(a, b), band(a, c), band(b, c))
            local temp2 = (S0 + maj) % 4294967296

            h = g
            g = f
            f = e
            e = (d + temp1) % 4294967296
            d = c
            c = b
            b = a
            a = (temp1 + temp2) % 4294967296
        end

        H0 = (H0 + a) % 4294967296
        H1 = (H1 + b) % 4294967296
        H2 = (H2 + c) % 4294967296
        H3 = (H3 + d) % 4294967296
        H4 = (H4 + e) % 4294967296
        H5 = (H5 + f) % 4294967296
        H6 = (H6 + g) % 4294967296
        H7 = (H7 + h) % 4294967296
    end

    return H0, H1, H2, H3, H4, H5, H6, H7
end

function Crypto:SHA256(str)
    local H0, H1, H2, H3, H4, H5, H6, H7 = sha256_core(tostring(str or ""))
    return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", H0, H1, H2, H3, H4, H5, H6, H7)
end

function Crypto:SHA256_Bytes(str)
    local H0, H1, H2, H3, H4, H5, H6, H7 = sha256_core(tostring(str or ""))
    local words = { H0, H1, H2, H3, H4, H5, H6, H7 }
    local bytes = {}
    for i = 1, 8 do
        local w = words[i]
        table.insert(bytes, string.char(
            band(rshift(w, 24), 0xFF),
            band(rshift(w, 16), 0xFF),
            band(rshift(w, 8), 0xFF),
            band(w, 0xFF)
        ))
    end
    return table.concat(bytes)
end

function Crypto:HMAC_SHA256(key, message)
    key = tostring(key or "")
    message = tostring(message or "")

    if #key > 64 then
        key = self:SHA256_Bytes(key)
    end
    if #key < 64 then
        key = key .. string.rep("\0", 64 - #key)
    end

    local ipadParts = {}
    local opadParts = {}
    for i = 1, 64 do
        local kb = string.byte(key, i)
        table.insert(ipadParts, string.char(bxor(kb, 0x36)))
        table.insert(opadParts, string.char(bxor(kb, 0x5C)))
    end

    local inner = self:SHA256_Bytes(table.concat(ipadParts) .. message)
    return self:SHA256(table.concat(opadParts) .. inner)
end

-- =========================================================================
-- 🔑 CONTEXT-SEPARATED KEY DERIVATION (KDF)
-- =========================================================================

function Crypto:DeriveKeys(playerGUID, realmName)
    local guid = tostring(playerGUID or "Player")
    local realm = tostring(realmName or "Forever")

    -- 1. Master Key Material (Domain separated)
    local masterContext = string.format("ForeverSafari/v2|%s|%s", guid, realm)
    local K_master = self:HMAC_SHA256(SECRET_SALT, masterContext)

    -- 2. Domain-Separated Subkeys (Cryptographic key separation)
    local K_encrypt_hex = self:HMAC_SHA256(K_master, "encryption")
    local K_mac         = self:HMAC_SHA256(K_master, "integrity")

    -- Convert K_encrypt_hex (first 32 hex chars = 16 bytes = 4 x 32-bit words) for XXTEA
    local key4 = {}
    for i = 1, 32, 8 do
        local chunk = K_encrypt_hex:sub(i, i + 7)
        local val = tonumber(chunk, 16) or 0
        table.insert(key4, val)
    end

    return {
        key4 = key4,
        k_mac = K_mac
    }
end

-- =========================================================================
-- 📦 XXTEA 32-BIT BLOCK OBFUSCATION / ENCRYPTION (Pure Lua 5.1 + bit)
-- =========================================================================

local XXTEA_DELTA = 0x9E3779B9

local function xxtea_mx(z, y, sum, p, e, k)
    local part1 = bxor(rshift(z, 5), lshift(y, 2))
    local part2 = bxor(rshift(y, 3), lshift(z, 4))
    local term1 = (part1 + part2) % 4294967296

    local keyIdx = bxor(band(p, 3), e)
    local term2 = (bxor(sum, y) + bxor(k[keyIdx + 1], z)) % 4294967296

    return bxor(term1, term2)
end

local function str_to_words(str)
    local len = #str
    local words = { len }
    local word = 0
    local shift = 0
    for i = 1, len do
        local b = string.byte(str, i)
        word = bor(word, lshift(b, shift))
        shift = shift + 8
        if shift == 32 then
            table.insert(words, word)
            word = 0
            shift = 0
        end
    end
    if shift > 0 then
        table.insert(words, word)
    end
    if #words < 2 then
        table.insert(words, 0)
    end
    return words
end

local function words_to_str(words)
    if not words or #words < 1 then return "" end
    local origLen = words[1]
    local chars = {}
    local extracted = 0
    for i = 2, #words do
        local w = words[i]
        for byteIdx = 0, 3 do
            if extracted < origLen then
                local b = band(rshift(w, byteIdx * 8), 0xFF)
                table.insert(chars, string.char(b))
                extracted = extracted + 1
            else
                break
            end
        end
        if extracted >= origLen then break end
    end
    return table.concat(chars)
end

function Crypto:XXTEA_Encrypt(data, key4)
    if not data or data == "" then return "" end
    key4 = key4 or { 0x12345678, 0x9ABCDEF0, 0x0FEDCBA9, 0x87654321 }

    local v = str_to_words(data)
    local n = #v
    if n < 2 then return data end

    local rounds = math.floor(6 + 52 / n)
    local sum = 0
    local z = v[n]

    for cycle = 1, rounds do
        sum = (sum + XXTEA_DELTA) % 4294967296
        local e = band(rshift(sum, 2), 3)
        for p = 0, n - 2 do
            local y = v[p + 2]
            z = (v[p + 1] + xxtea_mx(z, y, sum, p, e, key4)) % 4294967296
            v[p + 1] = z
        end
        local y = v[1]
        z = (v[n] + xxtea_mx(z, y, sum, n - 1, e, key4)) % 4294967296
        v[n] = z
    end

    -- Pack ciphertext words into binary string
    local outParts = {}
    for i = 1, n do
        local w = v[i]
        table.insert(outParts, string.char(
            band(w, 0xFF),
            band(rshift(w, 8), 0xFF),
            band(rshift(w, 16), 0xFF),
            band(rshift(w, 24), 0xFF)
        ))
    end
    return table.concat(outParts)
end

function Crypto:XXTEA_Decrypt(data, key4)
    if not data or #data < 8 then return nil end
    key4 = key4 or { 0x12345678, 0x9ABCDEF0, 0x0FEDCBA9, 0x87654321 }

    local numWords = math.floor(#data / 4)
    local v = {}
    for i = 1, numWords do
        local idx = (i - 1) * 4 + 1
        local b1, b2, b3, b4 = string.byte(data, idx, idx + 3)
        v[i] = bor(b1, lshift(b2, 8), lshift(b3, 16), lshift(b4, 24))
    end

    local n = #v
    if n < 2 then return nil end

    local rounds = math.floor(6 + 52 / n)
    local sum = (rounds * XXTEA_DELTA) % 4294967296
    local y = v[1]

    for cycle = 1, rounds do
        local e = band(rshift(sum, 2), 3)
        for p = n - 1, 1, -1 do
            local z = v[p]
            y = (v[p + 1] - xxtea_mx(z, y, sum, p, e, key4)) % 4294967296
            v[p + 1] = y
        end
        local z = v[n]
        y = (v[1] - xxtea_mx(z, y, sum, 0, e, key4)) % 4294967296
        v[1] = y
        sum = (sum - XXTEA_DELTA) % 4294967296
    end

    return words_to_str(v)
end

-- =========================================================================
-- 🔠 BASE64 ASCII ARMORING
-- =========================================================================

function Crypto:EncodeBase64(data)
    if not data or data == "" then return "" end
    return ((data:gsub('.', function(x) 
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i - 1) > 0 and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2^(6 - i) or 0) end
        return B64_CHARS:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

function Crypto:DecodeBase64(data)
    if not data or data == "" then return "" end
    data = string.gsub(data, '[^' .. B64_CHARS .. '=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (B64_CHARS:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i - 1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2^(8 - i) or 0) end
        return string.char(c)
    end))
end

-- =========================================================================
-- 🛡️ AUTHENTICATED VAULT ENVELOPE (Encrypt-then-MAC)
-- =========================================================================

function Crypto:CreateVaultEnvelope(schemaVersion, generation, playerGUID, payloadStr, key_mac, key_encrypt)
    local encryptedBinary = self:XXTEA_Encrypt(payloadStr, key_encrypt)
    local armoredPayload = self:EncodeBase64(encryptedBinary)

    -- Authenticate the complete metadata envelope (prevents payload or gen swapping)
    local envelopeMsg = string.format("%d:%d:%s:%s", schemaVersion, generation, playerGUID, armoredPayload)
    local integrity = self:HMAC_SHA256(key_mac, envelopeMsg)

    return {
        generation = generation,
        timestamp = time(),
        playerGUID = playerGUID,
        payload = armoredPayload,
        integrity = integrity
    }
end

function Crypto:VerifyVaultEnvelope(record, key_mac, expectedSchemaVersion)
    if not record or not record.generation or not record.playerGUID or not record.payload or not record.integrity then
        return false, "Missing envelope metadata"
    end

    local envelopeMsg = string.format("%d:%d:%s:%s", expectedSchemaVersion or 2, record.generation, record.playerGUID, record.payload)
    local expectedIntegrity = self:HMAC_SHA256(key_mac, envelopeMsg)

    if record.integrity ~= expectedIntegrity then
        return false, "HMAC envelope signature mismatch"
    end
    return true
end

function Crypto:DecryptVaultRecord(record, key_encrypt)
    local binaryData = self:DecodeBase64(record.payload)
    local decryptedStr = self:XXTEA_Decrypt(binaryData, key_encrypt)
    if not decryptedStr or decryptedStr == "" then
        return nil, "XXTEA decryption failed"
    end
    return decryptedStr
end

-- =========================================================================
-- 🐾 COMPANION SIGNATURES & DNA EXPORT (Compatibility Layer)
-- =========================================================================

function Crypto:Hash(str)
    return self:HMAC_SHA256(SECRET_SALT, tostring(str or "")):sub(1, 16)
end

function Crypto:GenerateLegacySignature(mob)
    if not mob then return "" end
    local str = string.format("%s:%s:%d:%d:%d:%d:%d:%s:%s",
        tostring(mob.id or 0),
        tostring(mob.name or ""),
        tonumber(mob.level or 1),
        tonumber(mob.hp or 10),
        tonumber(mob.attack or 5),
        tonumber(mob.defense or 5),
        tonumber(mob.speed or 5),
        tostring(mob.displayId or 0),
        tostring(mob.anatomy or "Sire")
    )
    return self:HMAC_SHA256(SECRET_SALT, str):sub(1, 16)
end

function Crypto:GenerateSignature(mob)
    if not mob then return "" end
    local movesCSV = ""
    if mob.moves and type(mob.moves) == "table" then
        movesCSV = table.concat(mob.moves, ",")
    elseif mob.abilities and type(mob.abilities) == "table" then
        movesCSV = table.concat(mob.abilities, ",")
    end

    local str = string.format("%s:%s:%s:%s:%d:%d:%d:%d:%s:%d:%d:%d:%d:%d:%d",
        tostring(mob.id or 0),
        tostring(mob.speciesId or mob.displayId or 0),
        tostring(mob.name or ""),
        tostring(mob.anatomy or mob.gender or "Sire"),
        tonumber(mob.maxHP or mob.hp or 40),
        tonumber(mob.atk or mob.attack or 22),
        tonumber(mob.def or mob.defense or 18),
        tonumber(mob.spd or mob.speed or 20),
        movesCSV,
        tonumber(mob.attunementPoints or mob.attunement or 0),
        tonumber(mob.attunementRank or 1),
        tonumber(mob.chunkId or 0),
        tonumber(mob.chunkSlot or 0),
        tonumber(mob.ivSeed or 0),
        mob.isRare and 1 or 0
    )
    return self:HMAC_SHA256(SECRET_SALT, str):sub(1, 16)
end

function Crypto:SignMob(mob)
    if not mob then return end
    local C = ns.Constants
    local isGenderless = (mob.creatureType and C and C.GENDERLESS_TYPES and C.GENDERLESS_TYPES[mob.creatureType]) or (mob.anatomy == "Genderless")
    if isGenderless then
        mob.anatomy = "Genderless"
    elseif not mob.anatomy or (mob.anatomy ~= "Sire" and mob.anatomy ~= "Dam") then
        mob.anatomy = (math.random(1, 2) == 1 and "Sire" or "Dam")
    end
    mob.gender = mob.anatomy
    local sig = self:GenerateSignature(mob)
    mob.sig = sig
    mob.signature = sig
    return mob
end

function Crypto:ValidateSignature(mob)
    if not mob then return false end
    local testSig = mob.sig or mob.signature
    if not testSig or testSig == "" then return false end

    -- 1. Test against canonical coordinate-bound exhaustive signature
    if testSig == self:GenerateSignature(mob) then
        return true, "canonical"
    end

    -- 2. Test without chunk coordinates (for active squad companions in transit)
    local unanchored = CopyTable(mob)
    unanchored.chunkId = 0
    unanchored.chunkSlot = 0
    if testSig == self:GenerateSignature(unanchored) then
        return true, "unanchored"
    end

    -- 3. Fallback test against legacy 9-field signature
    if testSig == self:GenerateLegacySignature(mob) then
        return true, "legacy"
    end

    return false, "mismatch"
end

function Crypto:ValidateAndRepairSignatures(collection)
    if not collection then return end

    for _, mob in ipairs(collection) do
        local isGenderless = (mob.creatureType and C.GENDERLESS_TYPES and C.GENDERLESS_TYPES[mob.creatureType]) or (mob.anatomy == "Genderless")
        if isGenderless then
            mob.anatomy = "Genderless"
        elseif not mob.anatomy or (mob.anatomy ~= "Sire" and mob.anatomy ~= "Dam") then
            local hashVal = self:Hash(tostring(mob.id or math.random(1, 1000)))
            local lastChar = string.byte(hashVal, #hashVal) or 0
            mob.anatomy = (lastChar % 2 == 0) and "Sire" or "Dam"
        end

        if not mob.moves or #mob.moves == 0 then
            mob.moves = { 101, 107, 102, 118 }
        end

        mob.attunementPoints = mob.attunementPoints or mob.attunement or 0
        mob.attunement = mob.attunementPoints

        if (mob.isStarter or (mob.customNickname and string.find(mob.customNickname, "^Starter"))) and (mob.attunementRank or 1) < 3 then
            mob.attunementRank = 3
            mob.attunementPoints = math.max(mob.attunementPoints or 0, 600)
            mob.attunement = mob.attunementPoints
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

        if not mob.maxHP or mob.maxHP <= 0 then
            mob.maxHP = mob.hp or 60
        end
        if mob.currentHP == nil or mob.currentHP > mob.maxHP then
            mob.currentHP = mob.maxHP
        end
        mob.hp = mob.currentHP

        mob.sig = self:GenerateSignature(mob)
    end
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
