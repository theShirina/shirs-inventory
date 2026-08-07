local corePath, uiPath = arg[1], arg[2]
ShirsInventoryDB = { setupComplete = true, features = { bagUI = true, sorter = true, junk = true } }
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
local originalToggle = function() return "other-addon" end
ToggleBackpack = originalToggle
OpenBackpack = function() end
CloseBackpack = function() end
OpenAllBags = function() end
CloseAllBags = function() end
ToggleBag = function() end
OpenBag = function() end
CloseBag = function() end
IsBagOpen = function() return nil end
KEYRING_CONTAINER = -2
local shown = false
ShirsInventoryFrame = { Show = function() shown = true end, Hide = function() shown = false end, IsShown = function() return shown end }
assert(loadfile(corePath))()
assert(loadfile(uiPath))()
local promptCount = 0
ShirsInventory_ShowBagProviderChoice = function() promptCount = promptCount + 1 end
local conflicts = { { name = "Cleanup", title = "Cleanup" }, { name = "pfUI", title = "pfUI" } }
local signature = ShirsInventory_GetBagAddonSignature(conflicts)
ShirsInventory_SetDetectedBagAddons(conflicts)
ShirsInventory_ApplyFeatureSelection()
assert(ToggleBackpack == originalToggle, "pending choice must preserve the existing bag handler")
assert(promptCount == 1, "pending conflict should show one chooser")
assert(ShirsInventory_SaveBagProviderChoice("other", signature))
ShirsInventory_ApplyFeatureSelection()
assert(ToggleBackpack == originalToggle, "other choice must preserve the existing bag handler")
assert(promptCount == 1, "saved other choice should not re-prompt")
assert(ShirsInventory_SaveBagProviderChoice("shirs", signature))
ShirsInventory_ApplyFeatureSelection()
assert(ToggleBackpack ~= originalToggle, "Shir choice should install Shir's bag handler")
ShirsInventory_SetDetectedBagAddons({ { name = "OneBag", title = "OneBag" } })
ShirsInventory_ApplyFeatureSelection()
assert(ToggleBackpack == originalToggle, "changed conflict signature must restore the prior provider")
assert(promptCount == 2, "changed conflict signature should re-prompt")
print("BAG_ADDON_CONFLICT_RUNTIME_TEST=PASS")
