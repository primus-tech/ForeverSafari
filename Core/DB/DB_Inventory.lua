--[[
    Forever Safari: Database - Safari Bag & Token Vault (DB_Inventory.lua)
    Manages Safari Tokens, bag slots, item stacks, and consumable usage.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.Database = ns.Database or {}

local DB = ns.Database

-- =========================================================================
-- 🪙 TOKEN VAULT
-- =========================================================================
function DB:GetTokens()
    if not ForeverSafariDB then return 0 end
    return ForeverSafariDB.tokens or 0
end

function DB:AddTokens(amount, reason)
    if not ForeverSafariDB then return end
    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    ForeverSafariDB.tokens = (ForeverSafariDB.tokens or 0) + amount
    ForeverSafariDB.stats = ForeverSafariDB.stats or {}
    ForeverSafariDB.stats.totalTokensEarned = (ForeverSafariDB.stats.totalTokensEarned or 0) + amount

    if ns.Toast and ns.Toast.ShowTokenGain then
        ns.Toast:ShowTokenGain(amount, reason)
    end
end

function DB:SpendTokens(amount)
    if not ForeverSafariDB then return false end
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end

    local current = ForeverSafariDB.tokens or 0
    if current >= amount then
        ForeverSafariDB.tokens = current - amount
        return true
    end
    return false
end

-- =========================================================================
-- 🎒 SAFARI BAG INVENTORY
-- =========================================================================
function DB:GetInventory()
    if not ForeverSafariDB or not ForeverSafariDB.inventory then return {} end
    return ForeverSafariDB.inventory
end

function DB:GetItemCount(itemId)
    local inv = self:GetInventory()
    return inv[itemId] or 0
end

function DB:AddItem(itemId, count)
    if not ForeverSafariDB then return end
    ForeverSafariDB.inventory = ForeverSafariDB.inventory or {}
    count = count or 1
    ForeverSafariDB.inventory[itemId] = (ForeverSafariDB.inventory[itemId] or 0) + count

    if ns.Toast and ns.Toast.ShowItemGain then
        ns.Toast:ShowItemGain(itemId, count)
    end
end

function DB:AddInventoryItem(itemId, count)
    self:AddItem(itemId, count)
end

function DB:RemoveItem(itemId, count)
    if not ForeverSafariDB or not ForeverSafariDB.inventory then return false end
    count = count or 1
    local cur = ForeverSafariDB.inventory[itemId] or 0
    if cur >= count then
        ForeverSafariDB.inventory[itemId] = cur - count
        return true
    end
    return false
end
