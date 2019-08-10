------------------------------------------------------------------
--FCOItemSaver.lua
--Author: Baertram
----------------------------------------------------------
--Check filename FCOIS_API.lua for global API functions!
----------------------------------------------------------
--[[
	Allows you to mark items with an icon so you know that you meant to save it for some reason.
	Prevent items from beeing destroyed/extracted/traded/mailed/deconstructed/improved or sold somehow.
	Including filters on/off/show only marked items inside inventories, crafting stations, banks, guild banks, guild stores, player 2 player trading, sending mail, fence, launder and craftbag
]]


------------------------------------------------------------------
-- [Error/bug & feature messages to check] --
---------------------------------------------------------------------
--[ToDo list] --
-- Current max bugs: 17
-- 1) 2019-01-14 - Bugfix - Baertram
--Right clicking an item to show the context menu, and then left clicking somewhere else does not close the context menu on first click, but on 2nd click
--> Bug within LibCustomMenu -> To be fixed by Votan?

-- 13) 2019-08-09 - Bugfix - Baertram
-- If the same items are available at the crafting stations deconstruct panel (each item got it's own row for own bagId and slotIndex) and both are not protected.
-- Slot one of the item in the deconstruction slot
-- Add the marker icon to protect it to the other "sane" item. Due to the different bagId and slotIndex the item in the slot won't get protected and not removed!
---> Need to scan the whole inventory list as an item get's marked at the deconstruction/improvement/retrait panel in order to remove all items which are protected from the
---> slot!
----> See file src/FCOIS_Protection.lua, function FCOIS.IsItemProtectedAtASlotNow(bagId, slotIndex, bulkMark)
-----> Should get another parameter "scanOtherInvItemsIfSlotted"

-- 17) 2019-08-09 - Bugfix - Baertram
-- Drag&drop -> Destroy works at Vendor repair panel for marked  & protected items!


------------------------------------------------------------------
-- Currently worked on [Added/Fixed/Changed]
---------------------------------------------------------------------

--
--Fixed:
--  Bug #2: Updating keybinds at the InventoryInsightFromAshes UI won't update the marker icons shown.
--          They will show the changed amrker icons now on the IIfA UI and the normal inventories (if both are open at the same time),
--          and they will also update the marker icons for non-logged in characters in the IIfA UI properly now.
--  Bug #3: Bank keybind triggers lua error about insecure call
--          Replaced PreHook of ZO_InventorySlot_ShowContextMenu with LibCustomMenu:RegisterContextMenu(...)
--  Bug #5: Filtering for items will recognize all filter buttons now and will hide items which are hidden via a green filter button 1 to 3 even if button 4 says "only show"
--  Bug #10: The destroy selection handler did not work properly for dynamic icons if you have used drag&drop. It should now recognize if you got the settings for the dynamic
--           icon for anti-destroy enabled or not AND if you currentld disabled them via the additonal inventory flag icon (if the dynamic icon got the setting to support the
--           temporary disabling of the icon protection, via the additional flag icon, enabled!)
--  Bug #11: Item tooltips protection state is shown for normal and gear/dynamic gear items now in red/green too. And the state will update if you use the additional inventory
--           flag buttons "right click" option to change the protection state at the current filterPanel.
--  Bug #12: Changing the protection state with the right click on an additional inventory flag icon now checks if items are slotted to a craft/mail/trade... panel and unslots them
--           if they are protected again now
--  Bug #14: Multicraft support for Scalebreaker (PTS). Enchanting panel was not recognized correctly anymore (function SetEnchantingMode was removed by ZOs)
--  Bug #15: Keybindings and SHIFT+right mouse did not work at the refine panel of crafting stations, and not at retrait station
--  Bug #16: Double clicking with SHIFT+right mouse button (to remove/readd marker icons) will trigger the protective checks at the crafting stations e.g.
--  Bug #17: At vendor repair -> Drag&Drop enabled, keybind enabled, SHIFT+right mouse enabled, Fixed protection variables settings.blockVendorBu, blockVendorBuyback, blockVendorRepair,
--           fixed Anti-Destroy protection by drag&drop

--
--Added:
--Copy & delete SavedVariables from server, account, character (SavedVariables copy & delete is a new settings submenu at the bottom, next to backup & restore)
--Item count next to name sort header can be enabled in the "filter" settings. This count will update if you change filters within FCOItemSaver or AdvancedFilters.
--->If you are using AdvancedFilters as well you should either disable the item count setting in AdvancedFilters or FCOItemSaver to increase the performance.
--Add feature request #4 Setting to automatic marks->set items->non wished: Mark non-wished set items if character level below 50 and item below max level or max CP level
--API function FCOIS.isDynamicGearIcon(iconId)
--
--Added on request:
--SavedVariables can be enabled for all acounts the same
--Settings for tooltips at the context menu entries
--Settings to add the protected panel information to the context menu item entries
--->These tooltips only work if using LibCustomMenu 3.8.0!


------------------------------------------------------------------
--Global array with all data of this addon
if FCOIS == nil then FCOIS = {} end
local FCOIS = FCOIS

-- =====================================================================================================================
--  Gamepad functions
-- =====================================================================================================================
function FCOIS.resetPreventerVariableAfterTime(eventRegisterName, preventerVariableName, newValue, resetAfterTimeMS)
    local eventNameStart = "FCOIS_PreventerVariableReset_"
    if eventRegisterName == nil or eventRegisterName == "" or preventerVariableName == nil or preventerVariableName == "" or resetAfterTimeMS == nil then return end
    local eventName = eventNameStart .. tostring(eventRegisterName)
    EVENT_MANAGER:UnregisterForUpdate(eventName)
    EVENT_MANAGER:RegisterForUpdate(eventName, resetAfterTimeMS, function()
        EVENT_MANAGER:UnregisterForUpdate(eventName)
        if FCOIS.preventerVars == nil or FCOIS.preventerVars[preventerVariableName] == nil then return end
        FCOIS.preventerVars[preventerVariableName] = newValue
    end)
end

--Is the gamepad mode enabled in the ESO settings?
function FCOIS.FCOItemSaver_CheckGamePadMode(showChatOutputOverride)
    showChatOutputOverride = showChatOutputOverride or false
    FCOIS.preventerVars = FCOIS.preventerVars or {}
    --Gamepad enabled?
    if IsInGamepadPreferredMode() then
        --Gamepad enabled but addon AdvancedDisableControllerUI is enabled and is not showing the gamepad mode for the inventory,
        --but the normal inventory
        if FCOIS.checkIfADCUIAndIsNotUsingGamepadMode() then
            return false
        else
            if showChatOutputOverride or FCOIS.preventerVars.noGamePadModeSupportTextOutput == false then
                FCOIS.preventerVars.noGamePadModeSupportTextOutput = true
                --Reset the anti-chat spam variable FCOIS.preventerVars.noGamePadModeSupportTextOutput again after 3 seconds
                FCOIS.resetPreventerVariableAfterTime("noGamePadModeSupportTextOutput", "noGamePadModeSupportTextOutput", false, 3000)
                --Normal gamepad mode is enabled -> Abort with error message "not supported!"
                local noGamepadModeSupportedLanguageTexts = {
                    ["en"]	=	"FCO ItemSaver does not support the gamepad mode! Please change the mode to keyboard at the settings.",
                    ["de"]	=	"FCO ItemSaver unterstützt den Gamepad Modus nicht! Bitte wechsel in den Optionen zum Tastatur Modus.",
                    ["fr"]	=	"FCO ItemSaver ne prend pas en charge le mode de gamepad! S'il vous plaît changer le mode de clavier au niveau des réglages.",
                    ["es"]	=	"FCO ItemSaver no es compatible con el modo de mando de juegos! Por favor, cambie el modo de teclado en la configuración.",
                    ["it"]	=	"FCO ItemSaver non supporta la modalità di gamepad! Si prega di cambiare la modalità di tastiera con le impostazioni.",
                    ["jp"]	=	"FCO ItemSaverはゲームパッドモードをサポートしません！設定でキーボードモードに変更してください。",
                    ["ru"]	=	"FCO ItemSaver нe пoддepживaeт peжим гeймпaдa! Пoжaлуйcтa, cмeнитe в нacтpoйкax peжим нa клaвиaтуpу.",
                }
                local lang = GetCVar("language.2")
                local noGamepadModeSupportedText = noGamepadModeSupportedLanguageTexts[lang] or noGamepadModeSupportedLanguageTexts["en"]
                d(FCOIS.preChatVars.preChatTextRed .. noGamepadModeSupportedText)
            end
            return true
        end
    else
        --Gamepad not enabled
        return false
    end
end

-- =====================================================================================================================
--  Addon initialization
-- =====================================================================================================================
FCOIS.currentlyLoggedInCharName = ""

-- Register the event "addon loaded" for this addon
local function FCOItemSaver_Initialized()
    --Set the event callback functions -> file FCOIS_Events.lua
    FCOIS.setEventCallbackFunctions()
end

--------------------------------------------------------------------------------
--- Call the start function for this addon, so the initialization is done
--------------------------------------------------------------------------------
FCOItemSaver_Initialized()