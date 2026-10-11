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
        if ForeverSafari.KennelFrame and ForeverSafari.KennelFrame.Initialize then
            ForeverSafari.KennelFrame:Initialize()
        end
        if Bag and Bag.Initialize then
            Bag:Initialize()
        end
        if Mail and Mail.Initialize then
            Mail:Initialize()
        end
        if QH and QH.Initialize then
            QH:Initialize()
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

-- Slash Commands (Canonical Zero-Alias Registrations)
SLASH_SAFARI1 = "/safari"
SLASH_FSBAG1 = "/fsbag"
SLASH_FSMAIL1 = "/fsmail"
SLASH_FSKENNEL1 = "/fskennel"
SLASH_FSSHOP1 = "/fsshop"
SLASH_FSNET1 = "/fsnet"
SLASH_FSBATTLE1 = "/fsbattle"
SLASH_FSDUEL1 = "/fsduel"

local function HandleSlash(msg)
    local cmd, arg = strsplit(" ", msg or "", 2)
    cmd = string.lower(cmd or "")

    if cmd == "" or cmd == "journal" then
        Journal:Toggle()
    elseif cmd == "bounties" then
        if ForeverSafari.JournalFrame then
            ForeverSafari.JournalFrame:ShowTab("BOUNTIES")
        end
    elseif cmd == "tokens" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%sYou currently have |cffffd100%d Safari Tokens|r.", C.PREFIX, DB:GetTokens()))
    elseif cmd == "syncquests" then
        if QH and QH.SyncCompletedQuests then
            QH:SyncCompletedQuests(true)
        end
    elseif cmd == "abandon" then
        local activeMob = DB:GetActiveMob()
        if not activeMob then
            DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444No active companion to abandon.|r")
            return
        end
        if ForeverSafari.JournalFrame and ForeverSafari.JournalFrame.ShowAbandonConfirmation then
            ForeverSafari.JournalFrame:ShowAbandonConfirmation(activeMob.id)
        end
    elseif cmd == "reset" then
        DB:ResetDB()
    elseif cmd == "help" then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff99Available Slash Commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/safari|r - Toggle Safari Journal (Field Guide)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/safari bounties|r - Open Bounties & Research Directives")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/safari tokens|r - Display current Safari Token balance")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/safari syncquests|r - Retroactively claim tokens for completed quests")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/safari abandon|r - Release active companion back into the wild")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/safari reset|r - Reset all progress back to a fresh recruit")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fsbag|r - Toggle Virtual Safari Bag")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fsmail|r - Open Safari Mail tab at any town mailbox")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fskennel|r - Open Safari Kennel at any town Innkeeper")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fsshop|r - Open Safari Outfitter at Pet Trainers / Innkeepers")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fsnet|r - Attempt live field observation/capture on target")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fsbattle|r - Engage targeted wild creature in battle")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fsduel|r - Challenge targeted player to a companion duel")
    else
        Journal:Toggle()
    end
end

SlashCmdList["SAFARI"] = HandleSlash
SlashCmdList["FSBAG"] = function() if ForeverSafari.SafariBagFrame then ForeverSafari.SafariBagFrame:Toggle() end end
SlashCmdList["FSKENNEL"] = function()
    if ForeverSafari.ShopFrame and ForeverSafari.ShopFrame.IsAtAuthorizedVendor and ForeverSafari.ShopFrame:IsAtAuthorizedVendor() and ForeverSafari.ShopFrame.vendorType == "Innkeeper" then
        if ForeverSafari.KennelFrame then ForeverSafari.KennelFrame:ShowKennel() end
    else
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Safari Kennel access restricted! Speak with an Innkeeper at any inn to manage your companion bank.|r")
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Innkeeper Required", "Speak to an Innkeeper to access the Safari Kennel!")
        end
        PlaySound(847)
    end
end
SlashCmdList["FSSHOP"] = function()
    if ForeverSafari.ShopFrame and ForeverSafari.ShopFrame.IsAtAuthorizedVendor and ForeverSafari.ShopFrame:IsAtAuthorizedVendor() then
        Shop:Toggle()
    else
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Store access is restricted! Speak with a Pet Trainer (for Capture Gear & Supplies) or an Innkeeper (for Safari Treats & Food Provisions).|r")
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
