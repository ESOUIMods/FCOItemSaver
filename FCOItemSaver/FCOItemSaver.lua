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
-- 1) 2019-01-14 - Bugfix - Baertram
--Right clicking an item to show the context menu, and then left clicking somewhere else does not close the context menu on first click, but on 2nd click
--> Bug within LibCustomMenu -> >To be fixed by Votan?

-- 2) 2019-03-11 - Bugfix - Baertram
--Todo: IIfA UI: Set FCOIS marker icons by keybind for items without bagId and slotIndex (non-logged in chars!), by help of the itemLink and itemInstanceOrUniqueIdIIfA
--> See file src/FCOIS_functions.lua, function FCOIS.GetBagAndSlotFromControlUnderMouse(), at --IIfA support
--> marking via bagId and slotIndex does work BUT the list of IIfA is not refreshed until scrolling! SO this needs a fix as well.

-- 3) 2019-04-10 - Bugfix -  Reported by Kyoma on gitter.im
--Kyoma: Go to bank withdraw tab and use the keybind to mark with lock icon, then use keybind again to demark it.
--> Will produce an called by insecure code.
--> Why?
--Votan: item saver does ZO_PreHook("ZO_InventorySlot_ShowContextMenu",
-- Recomment to use libCustomMenu RegisterContextMenu
-- Should be a following error

-- 4) 2019-06-19 - Feature - Baertram
--SavedVariables should be saveable for all accounts, if settings to use accountwide are enabled, and copy/delete functions are needed within the settings
--> See file src/FCOIS_Settings.lua

-- 5) 2019-06-23 - Bugfix - Baertram
--Split slotCount on mail/trade panels should not do the antimail/trade checks chat output or right upper corner error messages anymore!
--> e.g. split 20 food marked with the lock icon to 2x10 food -> error message in chat and upper right corner is raised.
--> See file src/FCOIS_Events.lua, OnInventorySlotLocker and OnInventorySlotUnlocked must check if the split process is used and set a variable to "NOT" show the error messages.

------------------------------------------------------------------
--Global array with all data of this addon
if FCOIS == nil then FCOIS = {} end
local FCOIS = FCOIS

-- =====================================================================================================================
--  Gamepad functions
-- =====================================================================================================================
--Is the gamepad mode enabled in the ESO settings?
function FCOIS.FCOItemSaver_CheckGamePadMode()
    FCOIS.preventerVars = FCOIS.preventerVars or {}
    --Gamepad enabled?
    if IsInGamepadPreferredMode() then
        --Gamepad enabled but addon AdvancedDisableControllerUI is enabled and is not showing the gamepad mode for the inventory,
        --but the normal inventory
        if FCOIS.checkIfADCUIAndIsNotUsingGamepadMode() then
            return false
        else
            if FCOIS.preventerVars.noGamePadModeSupportTextOutput == false then
                FCOIS.preventerVars.noGamePadModeSupportTextOutput = true
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
