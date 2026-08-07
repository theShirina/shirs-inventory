local corePath, junkPath, uiPath = arg[1], arg[2], arg[3]
ShirsInventoryDB = { junkItems = {} }
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local altDown = true
function IsAltKeyDown() return altDown end
function IsControlKeyDown() return false end
function IsShiftKeyDown() return false end
function GetContainerItemInfo() return "texture", 1, nil, 2 end
function GetContainerItemLink() return "|Hitem:7076:0:0:0|h[Essence of Earth]|h" end
local used, picked = 0, 0
function UseContainerItem() used = used + 1 end
function PickupContainerItem() picked = picked + 1 end
function CursorHasItem() return false end
function ClearCursor() end
MerchantFrame = { selectedTab = 1, IsShown = function() return false end }

assert(loadfile(corePath))()
assert(loadfile(junkPath))()
assert(loadfile(uiPath))()

local button = { bag = 0, slot = 1 }
local handled = ShirsInventory_HandleItemClick(button, "RightButton")
assert(handled and ShirsInventoryDB.junkItems[7076], "Alt-right-click should mark the item id")
assert(used == 0 and picked == 0, "marking junk must not use, move, or sell the item")

altDown = false
ShirsInventory_HandleItemClick(button, "RightButton")
assert(used == 1, "plain right-click should preserve native use behavior")

MerchantFrame.IsShown = function() return true end
MerchantFrame.selectedTab = 2
ShirsInventory_HandleItemClick(button, "RightButton")
assert(used == 1, "right-click should not sell while buyback is selected")

MerchantFrame.IsShown = function() return false end
ShirsInventory_HandleItemClick(button, "LeftButton")
assert(picked == 1, "plain left-click should preserve native pickup behavior")

print("ITEM_CLICK_TEST=PASS")
