local corePath, junkPath, uiPath = arg[1], arg[2], arg[3]
ShirsInventoryDB = { setupComplete = true, features = { bagUI = false, sorter = true, junk = false }, junkItems = {} }
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local originalToggleCalls = 0
local originalToggle = function() originalToggleCalls = originalToggleCalls + 1 end
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
local used = 0
function UseContainerItem() used = used + 1 end
function PickupContainerItem() end
MerchantFrame = { selectedTab = 1, IsShown = function() return false end }

assert(loadfile(corePath))()
assert(loadfile(junkPath))()
assert(loadfile(uiPath))()

local marked, reason = ShirsInventory_ToggleJunk(7076, 2)
assert(not marked and reason == "disabled", "disabled junk module should reject manual marks")
local count, saleStatus = ShirsInventory_StartJunkSale()
assert(count == 0 and saleStatus == "disabled", "disabled junk module should reject bulk selling")

ShirsInventory_HandleItemClick({ bag = 0, slot = 1 }, "RightButton")
assert(used == 1, "disabled junk module should leave Alt-right-click as normal item use")
assert(ShirsInventoryDB.junkItems[7076] == nil, "disabled junk module should not change saved marks")

ShirsInventory_ApplyFeatureSelection()
assert(ToggleBackpack == originalToggle, "disabled bag UI should preserve Blizzard's backpack handler")
ToggleBackpack()
assert(originalToggleCalls == 1 and not shown, "disabled bag UI should use the original frame")

assert(ShirsInventory_SetFeatureEnabled("bagUI", true))
ShirsInventory_ApplyFeatureSelection()
ToggleBackpack()
assert(shown, "enabled bag UI should install the combined-frame handler")

assert(ShirsInventory_SetFeatureEnabled("bagUI", false))
ShirsInventory_ApplyFeatureSelection()
assert(ToggleBackpack == originalToggle, "turning bag UI off in settings should restore Blizzard handlers immediately")

print("FEATURE_GATING_TEST=PASS")
