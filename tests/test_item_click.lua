local corePath, junkPath, uiPath = arg[1], arg[2], arg[3]
ShirsInventoryDB = { junkItems = {} }
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local altDown = true
local shiftDown = false
local itemCount = 1
function IsAltKeyDown() return altDown end
function IsControlKeyDown() return false end
function IsShiftKeyDown() return shiftDown end
function GetContainerItemInfo() return "texture", itemCount, nil, 2 end
function GetContainerItemLink() return "|Hitem:7076:0:0:0|h[Essence of Earth]|h" end
local used, picked = 0, 0
function UseContainerItem() used = used + 1 end
function PickupContainerItem() picked = picked + 1 end
function CursorHasItem() return false end
function ClearCursor() end
MerchantFrame = { selectedTab = 1, IsShown = function() return false end }
local sellCursorBag, sellCursorSlot, inspectCursor, resetCursor
function ShowContainerSellCursor(bag, slot) sellCursorBag, sellCursorSlot = bag, slot end
function ShowInspectCursor() inspectCursor = true end
function ResetCursor() resetCursor = true end
local splitFrames = 0
function OpenStackSplitFrame() splitFrames = splitFrames + 1 end

assert(loadfile(corePath))()
assert(loadfile(junkPath))()
assert(loadfile(uiPath))()

local ownershipTooltip = {}
local ownershipTarget, ownershipItemID
local inCombat = false
function UnitAffectingCombat(unit) return unit == "player" and inCombat end
ShirsInventory_AccountAddItemTooltip = function(target, itemID)
  ownershipTarget, ownershipItemID = target, itemID
  return true
end
assert(ShirsInventory_AddAccountItemTooltip(ownershipTooltip, 14342),
  "inventory item tooltip did not call account ownership tracking")
assert(ownershipTarget == ownershipTooltip and ownershipItemID == 14342,
  "inventory item tooltip passed the wrong target or item ID")
assert(not ShirsInventory_GetHideItemOwnershipInCombat(),
  "item ownership details must remain visible in combat by default")
assert(ShirsInventory_SetHideItemOwnershipInCombat(true),
  "item ownership combat setting did not persist")
ownershipTarget, ownershipItemID = nil, nil
inCombat = true
assert(not ShirsInventory_AddAccountItemTooltip(ownershipTooltip, 14342) and
  ownershipTarget == nil and ownershipItemID == nil,
  "item ownership details were not suppressed in combat")
inCombat = false
assert(ShirsInventory_AddAccountItemTooltip(ownershipTooltip, 14342) and
  ownershipTarget == ownershipTooltip and ownershipItemID == 14342,
  "item ownership details stayed suppressed after combat")

local inventoryRefreshes, bankRefreshes = 0, 0
ShirsInventory_Update = function() inventoryRefreshes = inventoryRefreshes + 1 end
ShirsInventory_UpdateBank = function() bankRefreshes = bankRefreshes + 1 end
ShirsInventoryBankFrame = { IsShown = function() return true end }

local button = { bag = 0, slot = 1 }
local handled = ShirsInventory_HandleItemClick(button, "RightButton")
assert(handled and ShirsInventoryDB.junkItems[7076], "Alt-right-click should mark the item id")
assert(used == 0 and picked == 0, "marking junk must not use, move, or sell the item")
assert(inventoryRefreshes == 1 and bankRefreshes == 1,
  "junk marking must refresh both visible inventory and bank badges")

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

local wimLink
WIM_EditBoxInFocus = { Insert = function(_, link) wimLink = link end }
shiftDown = true
itemCount = 4
ShirsInventory_HandleItemClick(button, "LeftButton")
assert(wimLink == GetContainerItemLink(0, 1), "shift-click should insert the item link into WIM's focused whisper")
assert(splitFrames == 0, "shift-clicking into WIM must not open the stack split frame")
shiftDown = false
itemCount = 1
WIM_EditBoxInFocus = nil

MerchantFrame.IsShown = function() return true end
MerchantFrame.selectedTab = 1
ShirsInventory_UpdateItemCursor(button, false, false)
assert(sellCursorBag == 0 and sellCursorSlot == 1, "merchant hover should show the native sell cursor")

sellCursorBag, sellCursorSlot = nil, nil
MerchantFrame.selectedTab = 2
ShirsInventory_UpdateItemCursor(button, false, true)
assert(not sellCursorBag and inspectCursor, "buyback hover should not show a sell cursor")

inspectCursor, resetCursor = nil, nil
ShirsInventory_UpdateItemCursor(button, false, false)
assert(resetCursor, "ordinary item hover should reset the cursor when no special cursor applies")

print("ITEM_CLICK_TEST=PASS")
