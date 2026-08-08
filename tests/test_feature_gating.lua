local corePath, junkPath, uiPath = arg[1], arg[2], arg[3]
ShirsInventoryDB = {
  setupComplete = true,
  features = { bagUI = false, sorter = false, junk = false },
  junkItems = {},
}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local originalToggle = function() end
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
ShirsInventoryFrame = {
  Show = function() shown = true end,
  Hide = function() shown = false end,
  IsShown = function() return shown end,
}

function IsAltKeyDown() return true end
function IsControlKeyDown() return false end
function IsShiftKeyDown() return false end
function GetContainerItemInfo() return "texture", 1, nil, 2 end
function GetContainerItemLink() return "|Hitem:7076:0:0:0|h[Essence of Earth]|h" end
function GetContainerNumSlots() return 0 end
function GetMoney() return 0 end
function UseContainerItem() end
function PickupContainerItem() end
MerchantFrame = { selectedTab = 1, IsShown = function() return false end }

assert(loadfile(corePath))()
assert(loadfile(junkPath))()
assert(loadfile(uiPath))()

assert(ShirsInventory_IsFeatureEnabled("bagUI") and
  ShirsInventory_IsFeatureEnabled("sorter") and
  ShirsInventory_IsFeatureEnabled("junk"),
  "legacy disabled flags survived the full-suite migration")
local marked, reason = ShirsInventory_ToggleJunk(7076, 2)
assert(marked and reason == "marked", "full-suite junk marking is unavailable")
assert(ShirsInventoryDB.junkItems[7076] == true, "full-suite junk mark was not saved")

ShirsInventory_ApplyFeatureSelection()
assert(ToggleBackpack ~= originalToggle, "full suite did not install the combined bag handler")
ToggleBackpack()
assert(shown, "combined bag handler did not open Shir's Inventory")

assert(not ShirsInventory_SetFeatureEnabled("bagUI", false),
  "obsolete feature API disabled the full bag UI")
assert(not ShirsInventory_SetFeatureEnabled("sorter", false),
  "obsolete feature API disabled the sorter")
assert(not ShirsInventory_SetFeatureEnabled("junk", false),
  "obsolete feature API disabled junk tools")
assert(ToggleBackpack ~= originalToggle, "legacy disable attempt released bag ownership")

print("FEATURE_GATING_TEST=PASS")
