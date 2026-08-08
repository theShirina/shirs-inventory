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
assert(ToggleBackpack ~= originalToggle, "full suite did not claim the existing bag handler")
assert(promptCount == 0, "full suite still opened a provider chooser")
assert(not ShirsInventory_SaveBagProviderChoice("other", signature),
  "external bag ownership is still selectable")
ShirsInventory_ApplyFeatureSelection()
assert(ToggleBackpack ~= originalToggle, "rejected external choice released Shir's bag handler")

local latePfToggle = function() return "late-pfui" end
local latePfOpen = function() end
local latePfClose = function() end
ToggleBackpack = latePfToggle
OpenBackpack = latePfOpen
CloseBackpack = latePfClose
OpenAllBags = latePfOpen
CloseAllBags = latePfClose
ToggleBag = latePfToggle
OpenBag = latePfOpen
CloseBag = latePfClose
IsBagOpen = function() return nil end
local deferredOwnershipRefresh
local loader = {
  SetScript = function(_, scriptName, handler)
    if scriptName == "OnUpdate" then deferredOwnershipRefresh = handler end
  end,
}
ShirsInventory_HandleLoaderEvent("PLAYER_ENTERING_WORLD", nil, loader)
assert(ToggleBackpack == latePfToggle, "ownership refresh should wait until late provider event handlers finish")
assert(type(deferredOwnershipRefresh) == "function", "first character entry should queue a deferred ownership refresh")
this = loader
deferredOwnershipRefresh()
this = nil
assert(ToggleBackpack ~= latePfToggle, "deferred ownership refresh should reclaim the bag handler from late pfUI setup")

ShirsInventory_SetDetectedBagAddons({ { name = "OneBag", title = "OneBag" } })
ShirsInventory_ApplyFeatureSelection()
assert(ToggleBackpack ~= latePfToggle, "changed provider set released Shir's full-suite ownership")
assert(promptCount == 0, "changed provider set opened a chooser")
print("BAG_ADDON_CONFLICT_RUNTIME_TEST=PASS")
