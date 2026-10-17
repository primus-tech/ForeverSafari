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
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGOUT" then
        if ns.BattleEngine and ns.BattleEngine.State and ns.BattleEngine.State.inBattle and ns.BattleEngine.State.isPvP then
            ns.BattleEngine:ForfeitPvP("LOGGED_OUT")
        end
        if DB and DB.FlushVault then
            DB:FlushVault()
            ForeverSafariDB = nil -- Ensure plaintext is never written to SavedVariables on disk
        end
        return
    elseif event == "PLAYER_LEAVING_WORLD" then
        if DB and DB.FlushVault then
            DB:FlushVault() -- Pre-emptively serialize vault before loading screen, keeping in-memory state alive
        end
        return
    elseif event == "PLAYER_LOGIN" then
        if MB and MB.Initialize then
            MB:Initialize()
        end
        if MB and MB.UpdatePosition then
            MB:UpdatePosition()
        end
        C_Timer.After(0.5, function()
            if MB and MB.UpdatePosition then MB:UpdatePosition() end
        end)
        C_Timer.After(2.0, function()
            if MB and MB.UpdatePosition then MB:UpdatePosition() end
        end)
        return
    end

    if event == "ADDON_LOADED" and arg1 == "ForeverSafari" then
        -- Initialize Persistence Layer
        DB:Initialize()
        
        -- Initialize Systems
        QH:Initialize()
        Comms:Initialize()
        if ForeverSafari.WarBridge and ForeverSafari.WarBridge.Initialize then
            ForeverSafari.WarBridge:Initialize()
        end
        
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

        DEFAULT_CHAT_FRAME:AddMessage(string.format("%sLoaded successfully! Type |cffffd100/fs|r, |cffffd100/fs duel|r, |cffffd100/fs war|r, or click the minimap icon.", C.PREFIX))
    end
end)

-- Slash Commands (Canonical Zero-Alias Registrations — Strictly /fs)
SLASH_FS1 = "/fs"
SLASH_FSBAG1 = "/fsbag"
SLASH_FSMAIL1 = "/fsmail"
SLASH_FSKENNEL1 = "/fskennel"
SLASH_FSSHOP1 = "/fsshop"
SLASH_FSNET1 = "/fsnet"
SLASH_FSBATTLE1 = "/fsbattle"
SLASH_FSDUEL1 = "/fsduel"
SLASH_FSRESET1 = "/fsreset"
SLASH_FSWAR1 = "/fswar"

local function HandleSlash(msg)
    local cmd, arg = strsplit(" ", msg or "", 2)
    cmd = string.lower(cmd or "")

    if cmd == "" or cmd == "journal" then
        Journal:Toggle()
    elseif cmd == "bag" then
        if SlashCmdList["FSBAG"] then SlashCmdList["FSBAG"]() end
    elseif cmd == "mail" then
        if SlashCmdList["FSMAIL"] then SlashCmdList["FSMAIL"]() end
    elseif cmd == "kennel" or cmd == "reserve" then
        if SlashCmdList["FSKENNEL"] then SlashCmdList["FSKENNEL"]() end
    elseif cmd == "shop" then
        if SlashCmdList["FSSHOP"] then SlashCmdList["FSSHOP"]() end
    elseif cmd == "net" or cmd == "capture" then
        if SlashCmdList["FSNET"] then SlashCmdList["FSNET"]() end
    elseif cmd == "battle" then
        if SlashCmdList["FSBATTLE"] then SlashCmdList["FSBATTLE"]() end
    elseif cmd == "duel" then
        ForeverSafari.Comms:ChallengeTarget(arg)
    elseif cmd == "nursery" or cmd == "breed" then
        if ForeverSafari.NurseryFrame then ForeverSafari.NurseryFrame:Toggle() end
    elseif cmd == "errors" or cmd == "bugs" then
        if SlashCmdList["FSERRORS"] then SlashCmdList["FSERRORS"]() end
    elseif cmd == "taint" or cmd == "diag" then
        if SlashCmdList["FSTAINT"] then SlashCmdList["FSTAINT"]() end
    elseif cmd == "war" then
        if ForeverSafari.WarBridge then ForeverSafari.WarBridge:HandleSlash(arg) end
    elseif cmd == "bounties" then
        if ForeverSafari.JournalFrame then
            ForeverSafari.JournalFrame:ShowTab("BOUNTIES")
        end
    elseif cmd == "minimap" or cmd == "icon" then
        if ForeverSafari.MinimapButton then
            if arg == "reset" then
                ForeverSafari.MinimapButton:ResetPosition()
            else
                ForeverSafari.MinimapButton:Toggle()
            end
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
    elseif cmd == "benchmark" or cmd == "testvault" then
        DB:RunBenchmark()
    elseif cmd == "help" then
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cff00ff99Available Slash Commands (Strictly /fs):|r")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs|r - Toggle Safari Journal (Field Guide & Menagerie)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs duel [2v2]|r - Challenge target to 1v1 or 2v2 companion duel")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs war|r - Open Territory War / Node Control match controls")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs battle|r - Engage targeted wild creature in battle")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs net|r - Attempt live field observation/capture on target")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs bag|r - Toggle Virtual Safari Bag")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs mail|r - Open Safari Mail tab at any town mailbox")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs kennel|r - Open Safari Kennel at any town Banker")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs shop|r - Open Safari Outfitter at any Pet Trainer")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs nursery|r - Open 2-Player Co-op Nursery breeding chamber")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs bounties|r - Open Bounties & Research Directives")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs tokens|r - Display current Safari Token balance")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs syncquests|r - Retroactively claim tokens for completed quests")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs abandon|r - Release active companion back into the wild")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs reset|r - Reset all progress back to a fresh recruit")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs minimap [reset]|r - Toggle or reset minimap icon to default position")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs benchmark|r - Run persistence vault crypto performance tests")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs errors|r - View session Lua bug tracker modal (/fserrors)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/fs taint|r - Inspect combat taint & action block events (/fstaint)")
    else
        Journal:Toggle()
    end
end

SlashCmdList["FS"] = HandleSlash
SlashCmdList["FSBAG"] = function() if ForeverSafari.SafariBagFrame then ForeverSafari.SafariBagFrame:Toggle() end end
SlashCmdList["FSKENNEL"] = function()
    if ForeverSafari.KennelFrame and ForeverSafari.KennelFrame.IsAtBanker and ForeverSafari.KennelFrame:IsAtBanker() then
        ForeverSafari.KennelFrame:ShowKennel()
    else
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Safari Kennel access restricted! Speak with a Banker at any bank vault to manage your companion bank.|r")
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Banker Required", "Speak to a Banker to access the Safari Kennel!")
        end
        PlaySound(847)
    end
end
SlashCmdList["FSSHOP"] = function()
    if ForeverSafari.ShopFrame and ForeverSafari.ShopFrame.IsAtAuthorizedVendor and ForeverSafari.ShopFrame:IsAtAuthorizedVendor() then
        Shop:Toggle()
    else
        DEFAULT_CHAT_FRAME:AddMessage(C.PREFIX .. "|cffff4444Store access is restricted! Speak with a Pet Trainer to purchase capture gear, crates, diet provisions, and supplies.|r")
        if ForeverSafari.Toast then
            ForeverSafari.Toast:ShowAlert("Pet Trainer Required", "Speak to a Pet Trainer to access the Safari Outfitter!")
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
SlashCmdList["FSDUEL"] = function(msg) ForeverSafari.Comms:ChallengeTarget(msg) end
SlashCmdList["FSRESET"] = function() DB:ResetDB() end
SlashCmdList["FSWAR"] = function(msg) if ForeverSafari.WarBridge then ForeverSafari.WarBridge:HandleSlash(msg) end end
SLASH_FSMINIMAP1 = "/fsminimap"
SLASH_FSICON1 = "/fsicon"
SlashCmdList["FSMINIMAP"] = function(msg)
    if ForeverSafari.MinimapButton then
        if msg == "reset" then
            ForeverSafari.MinimapButton:ResetPosition()
        else
            ForeverSafari.MinimapButton:Toggle()
        end
    end
end
SlashCmdList["FSICON"] = SlashCmdList["FSMINIMAP"]

-- Innkeeper healing is handled on-demand via Junior Safari League gossip button (SafariGossip.lua)
