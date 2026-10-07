--[[
    Forever Safari: Main Addon Bootstrap & Slash Commands
    Hemet Nesingwary's Junior Expeditionary League for World of Warcraft: Forever Beta.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns

local C = ns.Constants
local DB = ns.Database
local QH = ns.QuestHooks
local Comms = ns.Comms
local HUD = ns.CaptureHUD
local MB = ns.MinimapButton
local Journal = ns.JournalFrame
local Shop = ns.ShopFrame
local Battle = ns.BattleFrame
local Bag = ns.SafariBagFrame
local Mail = ns.SafariMailFrame

-- Main Event Listener
local eventFrame = CreateFrame("Frame", "ForeverSafariMainEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "ForeverSafari" then
        -- Initialize Persistence Layer
        DB:Initialize()
        
        -- Initialize Systems
        QH:Initialize()
        Comms:Initialize()
        
        -- Initialize UI Components
        HUD:Initialize()
        MB:Initialize()
        Journal:Initialize()
        Shop:Initialize()
        Battle:Initialize()
        if Bag and Bag.Initialize then
            Bag:Initialize()
        end
        if Mail and Mail.Initialize then
            Mail:Initialize()
        end

        -- Auto-fix / migrate display IDs for any existing collection mobs
        for _, mob in ipairs(DB:GetCollection()) do
            if not mob.displayId or mob.displayId == 0 or mob.displayId == 181 or mob.displayId == 380 or mob.displayId >= 1000 or mob.displayId == 890 or mob.displayId == 1098 then
                mob.displayId = C.GetDefaultDisplayId(mob.creatureType, mob.name)
            end
        end

        -- Initialize UI Modules
        if ForeverSafari.InspectorFrame and ForeverSafari.InspectorFrame.Initialize then
            ForeverSafari.InspectorFrame:Initialize()
        end

        -- First Login: Inform player of official Mailbox Dispatch
        if not DB:IsStarterClaimed() then
            C_Timer.After(1.5, function()
                DEFAULT_CHAT_FRAME:AddMessage(string.format("%s|cff00ff00✉️ Official Correspondence!|r Hemet Nesingwary has delivered your Starter Companion Parcel to the nearest mailbox. Visit any town mailbox and click the |cffffd100[Safari Dispatch]|r tab to claim!", C.PREFIX))
                if ForeverSafari.Toast then
                    ForeverSafari.Toast:ShowReward("Official Safari Dispatch!", "Visit any Mailbox tab to unbox your Starter Companion!")
                end
            end)
        end

        DEFAULT_CHAT_FRAME:AddMessage(string.format("%sLoaded successfully! Type |cffffd100/safari|r, |cffffd100/fsbag|r, |cffffd100/fsmail|r, or click the minimap icon.", C.PREFIX))
    end
end)

-- Slash Commands Handler
SLASH_FOREVERSAFARI1 = "/foreversafari"
SLASH_FOREVERSAFARI2 = "/safari"
SLASH_FOREVERSAFARI3 = "/fs"
SLASH_FSBAG1 = "/fsbag"
SLASH_FSBAG2 = "/safabag"
SLASH_FSSHOP1 = "/fsshop"
SLASH_FSMAIL1 = "/fsmail"
SLASH_FSMAIL2 = "/safamail"
SLASH_FSNET1 = "/fsnet"
SLASH_FSBATTLE1 = "/fsbattle"
SLASH_FSDUEL1 = "/fsduel"

local function HandleSlash(msg)
    local cmd, arg = strsplit(" ", msg or "", 2)
    cmd = string.lower(cmd or "")

    if cmd == "" or cmd == "guide" or cmd == "journal" or cmd == "dex" then
        Journal:Toggle()
    elseif cmd == "bag" or cmd == "pouch" or cmd == "inventory" or cmd == "items" or cmd == "backpack" then
        if ForeverSafari.SafariBagFrame then ForeverSafari.SafariBagFrame:Toggle() end
    elseif cmd == "shop" or cmd == "store" or cmd == "supplies" then
        if ForeverSafari.ShopFrame and ForeverSafari.ShopFrame.IsAtAuthorizedVendor and ForeverSafari.ShopFrame:IsAtAuthorizedVendor() then
            Shop:Toggle()
        else
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Store access is restricted! Speak with a Pet Trainer (for Safari Nets & Gear) or an Innkeeper (for Safari Treats & Food Provisions).|r")
            if ForeverSafari.Toast then
                ForeverSafari.Toast:ShowAlert("Vendor Required", "Speak to a Pet Trainer or Innkeeper!")
            end
            PlaySound(847)
        end
    elseif cmd == "bounties" or cmd == "quests" or cmd == "directives" or cmd == "tasks" then
        if ForeverSafari.JournalFrame then
            ForeverSafari.JournalFrame:ShowTab("BOUNTIES")
        end
    elseif cmd == "mail" or cmd == "letters" or cmd == "dispatch" then
        if MailFrame and MailFrame:IsShown() and ForeverSafari.SafariMailFrame then
            ForeverSafari.SafariMailFrame:SelectSafariTab()
        else
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffffcc00📬 Nesingwary Mailbox Hub:|r Turn in completed bounties and claim parcels at any physical town mailbox. Opening |cffffd100Field Directives|r in your Safari Journal...")
            if ForeverSafari.JournalFrame then
                ForeverSafari.JournalFrame:ShowTab("BOUNTIES")
            end
        end
    elseif cmd == "net" or cmd == "catch" or cmd == "snare" or cmd == "trap" then
        ForeverSafari.CaptureEngine:AttemptCapture("target")
    elseif cmd == "battle" or cmd == "fight" then
        ForeverSafari.BattleEngine:StartWildBattle("target")
    elseif cmd == "duel" then
        ForeverSafari.Comms:ChallengeTarget()
    elseif cmd == "tokens" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%sYou currently have |cffffd100%d Safari Tokens|r.", C.PREFIX, DB:GetTokens()))
    elseif cmd == "abandon" or cmd == "release" then
        local activeMob = DB:GetActiveMob()
        if not activeMob then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444No active companion to abandon.|r")
            return
        end
        local mName = activeMob.nickname ~= "" and activeMob.nickname or activeMob.name
        local dialog = StaticPopup_Show("FOREVERSAFARI_CONFIRM_ABANDON", string.format("|cffffd100%s|r (Lv %d %s)", mName, activeMob.level, activeMob.creatureType))
        if dialog then
            dialog.data = { mobId = activeMob.id }
        end
    elseif cmd == "give" or cmd == "add" then
        local itemKey, countStr = strsplit(" ", arg or "", 2)
        itemKey = string.lower(itemKey or "nets")
        local count = tonumber(countStr) or 10

        if itemKey == "nets" or itemKey == "net" or itemKey == "copper" or itemKey == "copper_cage" then
            DB:AddItem("copper_cage", count)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%sAdded |cffffffff[%dx Copper Safari Net]|r to your Safari Bag.", C.PREFIX, count))
        elseif itemKey == "iron" or itemKey == "iron_cage" then
            DB:AddItem("iron_cage", count)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%sAdded |cff1eff00[%dx Reinforced Iron Net]|r to your Safari Bag.", C.PREFIX, count))
        elseif itemKey == "mithril" or itemKey == "mithril_cage" then
            DB:AddItem("mithril_cage", count)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%sAdded |cff0070dd[%dx Mithril Safari Net]|r to your Safari Bag.", C.PREFIX, count))
        elseif itemKey == "arcanite" or itemKey == "arcanite_capsule" or itemKey == "capsule" then
            DB:AddItem("arcanite_capsule", count)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%sAdded |cffa335ee[%dx Arcanite Safari Capsule]|r to your Safari Bag.", C.PREFIX, count))
        elseif itemKey == "salve" or itemKey == "salves" or itemKey == "heal" or itemKey == "healing_salve" then
            DB:AddItem("healing_salve", count)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%sAdded |cffffffff[%dx Safari Healing Salve]|r to your Safari Bag.", C.PREFIX, count))
        elseif itemKey == "revive" or itemKey == "revives" or itemKey == "crystal" or itemKey == "revival_crystal" then
            DB:AddItem("revival_crystal", count)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%sAdded |cff00ffff[%dx Safari Revival Crystal]|r to your Safari Bag.", C.PREFIX, count))
        elseif itemKey == "treat" or itemKey == "treats" or itemKey == "az_treat" then
            DB:AddItem("az_treat", count)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%sAdded |cff1eff00[%dx Safari Treat]|r to your Safari Bag.", C.PREFIX, count))
        elseif itemKey == "token" or itemKey == "tokens" then
            DB:AddTokens(count, "Admin /give")
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%sAdded |cffffd100[%d Safari Tokens]|r to your balance.", C.PREFIX, count))
        else
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Usage: /fs give <nets|iron|mithril|arcanite|salves|revives|treats|tokens> [count]|r")
        end
        if ForeverSafari.SafariBagFrame and ForeverSafari.SafariBagFrame:IsShown() then
            ForeverSafari.SafariBagFrame:UpdateUI()
        end
    elseif cmd == "reset" then
        DB:ResetDB()
    elseif cmd == "help" then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff99Available Slash Commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/safari|r or |cffffd100/fs|r - Open Field Guide & Team Manager")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/safari give <item> [count]|r - Grant nets, salves, revives, treats, or tokens")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/safari bounties|r - View Active Field Directives & Quest Tracker")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fsbag|r or |cffffd100/safari bag|r - Open Virtual Safari Bag")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fsmail|r or |cffffd100/safari mail|r - View Nesingwary Dispatches (Turn in at Mailbox)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/safari abandon|r - Release active companion back into the wild")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fsnet|r - Throw selected safari net at target")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fsbattle|r - Engage targeted wild creature in turn-based battle")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fsduel|r - Challenge targeted player to a companion duel")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/safari tokens|r - Check current Safari Token balance")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/safari reset|r - Reset all progress back to a fresh new recruit")
    else
        Journal:Toggle()
    end
end

SlashCmdList["FOREVERSAFARI"] = HandleSlash
SlashCmdList["FSBAG"] = function() if ForeverSafari.SafariBagFrame then ForeverSafari.SafariBagFrame:Toggle() end end
SlashCmdList["FSSHOP"] = function()
    if ForeverSafari.ShopFrame and ForeverSafari.ShopFrame.IsAtAuthorizedVendor and ForeverSafari.ShopFrame:IsAtAuthorizedVendor() then
        Shop:Toggle()
    else
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Store access is restricted! Speak with a Pet Trainer (for Safari Nets & Gear) or an Innkeeper (for Safari Treats & Food Provisions).|r")
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Vendor Required", "Speak to a Pet Trainer or Innkeeper!")
        end
        PlaySound(847)
    end
end
SlashCmdList["FSMAIL"] = function()
    if MailFrame and MailFrame:IsShown() and ForeverSafari.SafariMailFrame then
        ForeverSafari.SafariMailFrame:SelectSafariTab()
    else
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffffcc00📬 Nesingwary Mailbox Hub:|r Turn in completed bounties and claim parcels at any physical town mailbox. Opening |cffffd100Field Directives|r in your Safari Journal...")
        if ForeverSafari.JournalFrame then
            ForeverSafari.JournalFrame:ShowTab("BOUNTIES")
        end
    end
end
SlashCmdList["FSNET"] = function() ForeverSafari.CaptureEngine:AttemptCapture("target") end
SlashCmdList["FSBATTLE"] = function() ForeverSafari.BattleEngine:StartWildBattle("target") end
SlashCmdList["FSDUEL"] = function() ForeverSafari.Comms:ChallengeTarget() end
