local corePath, uiPath = arg[1], arg[2]

KEYRING_CONTAINER = -2
ShirsInventoryDB = { setupComplete = true, junkItems = {} }
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local slotCounts = { [0] = 2, [1] = 1, [2] = 0, [3] = 0, [4] = 1 }
function GetContainerNumSlots(container) return slotCounts[container] or 0 end
function GetKeyRingSize() return 4 end
function ContainerIDToInventoryID(container) return 19 + container end
function GetInventoryItemTexture(_, inventoryID)
  if inventoryID == 20 then return "BagOne" end
  if inventoryID == 23 then return "BagFour" end
  return nil
end

local keyringClicks = {}
function KeyRingItemButton_OnClick(button)
  table.insert(keyringClicks, { button = button, owner = this })
end
categoryEmptyKeyring = false
function GetContainerItemInfo(bag, slot)
  if categoryEmptyKeyring and bag == KEYRING_CONTAINER then return nil, 0, false end
  if categoryEmptyKeyring and bag == 0 and slot ~= 1 then return nil, 0, false end
  return "texture", 1, nil, 1
end
function GetContainerItemLink() return "|Hitem:12382:0:0:0|h[Key]|h" end
function KeyRingButtonIDToInvSlotID(slot) return 68 + slot end
function IsAltKeyDown() return false end
function IsControlKeyDown() return false end
function IsShiftKeyDown() return false end
function CursorHasItem() return false end
function ResetCursor() end
local cursorUpdates = 0
function CursorUpdate() cursorUpdates = cursorUpdates + 1 end
MerchantFrame = { selectedTab = 1, IsShown = function() return false end }

local tooltipInventory, tooltipBag, tooltipSlot
GameTooltip = {}
function GameTooltip:SetInventoryItem(unit, inventory)
  assert(unit == "player", "keyring tooltip must target the player inventory")
  tooltipInventory = inventory
  return true
end
function GameTooltip:SetBagItem(bag, slot) tooltipBag, tooltipSlot = bag, slot end

local delegated = {}
function ToggleBackpack() table.insert(delegated, "toggleBackpack") end
function OpenBackpack() table.insert(delegated, "openBackpack") end
function CloseBackpack() table.insert(delegated, "closeBackpack") end
function OpenAllBags() table.insert(delegated, "openAll") end
function CloseAllBags() table.insert(delegated, "closeAll") end
function ToggleBag(id) table.insert(delegated, "toggle:" .. id) end
function OpenBag(id) table.insert(delegated, "open:" .. id) end
function CloseBag(id) table.insert(delegated, "close:" .. id) end
function IsBagOpen(id) table.insert(delegated, "isopen:" .. id); return nil end
function ToggleKeyRing() table.insert(delegated, "toggleKeyRing") end

local shown = false
ShirsInventoryFrame = {
  Show = function() shown = true end,
  Hide = function() shown = false end,
  IsShown = function() return shown end,
}

assert(loadfile(corePath))()
assert(loadfile(uiPath))()

assert(type(ShirsInventory_GetKeyRingContainerID) == "function", "keyring container helper is missing")
assert(ShirsInventory_GetKeyRingContainerID() == KEYRING_CONTAINER, "keyring container helper returned the wrong ID")
assert(type(ShirsInventory_GetKeyRingSize) == "function" and ShirsInventory_GetKeyRingSize() == 4,
  "keyring size must come from the native GetKeyRingSize API")
assert(type(ShirsInventory_GetInventorySlotCounts) == "function", "inventory slot-count helper is missing")
local liveCounts = ShirsInventory_GetInventorySlotCounts()
assert(liveCounts[0] == 2 and liveCounts[1] == 1 and liveCounts[4] == 1,
  "inventory slot-count helper lost a normal container")
assert(liveCounts[KEYRING_CONTAINER] == 4,
  "inventory slot-count helper did not query the native Keyring size")

local counts = { [0] = 2, [1] = 1, [2] = 0, [3] = 0, [4] = 1, [KEYRING_CONTAINER] = 4 }
local slots = ShirsInventory_BuildInventorySlots(counts)
assert(table.getn(slots) == 8, "combined inventory must include normal bags plus every keyring slot")
assert(slots[4].bag == 4 and slots[4].slot == 1, "normal bags must remain contiguous before the keyring")
assert(slots[5].bag == KEYRING_CONTAINER and slots[5].slot == 1,
  "keyring must begin immediately after normal bags")
assert(slots[8].bag == KEYRING_CONTAINER and slots[8].slot == 4,
  "combined inventory must include the final keyring slot")
assert(type(ShirsInventory_ShouldCountFreeInventorySlot) == "function", "free-slot scope helper is missing")
assert(ShirsInventory_ShouldCountFreeInventorySlot(0), "normal empty bag slots must count as free")
assert(not ShirsInventory_ShouldCountFreeInventorySlot(KEYRING_CONTAINER),
  "empty keyring slots must not inflate the normal free-space total")
assert(ShirsInventory_CountFreeInventorySlots({
  { bag = 0, hasItem = false },
  { bag = 1, hasItem = true },
  { bag = KEYRING_CONTAINER, hasItem = false },
  { bag = KEYRING_CONTAINER, hasItem = true },
}) == 1, "free-space total must ignore empty Keyring slots")

local entries = ShirsInventory_BuildBagBarModel()
assert(table.getn(entries) == 6, "bag bar must include Backpack, four equipped bags, and Keyring")
local keyring = entries[6]
assert(keyring.bag == KEYRING_CONTAINER and keyring.keyring and keyring.fixed,
  "sixth bag-bar entry must be the fixed Keyring")
assert(keyring.texture == "Interface\\ContainerFrame\\KeyRing-Bag-Icon" and keyring.slots == 4,
  "Keyring bag-bar icon or slot count is wrong")
assert(keyring.firstInventoryIndex == 5 and keyring.lastInventoryIndex == 8,
  "Keyring bag-bar ownership range is wrong")
assert(string.find(ShirsInventory_GetBagBarActionHint(keyring), "Keyring", 1, true),
  "Keyring bag-bar tooltip must identify the fixed container")

assert(type(ShirsInventory_GetKeyRingSlotsShown) == "function",
  "persistent Keyring visibility getter is missing")
assert(type(ShirsInventory_ToggleKeyRingSlots) == "function",
  "persistent Keyring visibility toggle is missing")
assert(ShirsInventory_GetKeyRingSlotsShown(), "Keyring slots must default to shown")
local gridUpdates = 0
ShirsInventory_Update = function() gridUpdates = gridUpdates + 1 end
local keyringBarButton = { bagEntry = keyring }
assert(ShirsInventory_HandleBagBarClick(keyringBarButton, "LeftButton"),
  "clicking Shir's Keyring icon did not handle the visibility toggle")
assert(not ShirsInventory_GetKeyRingSlotsShown() and ShirsInventoryDB.keyringSlotsShown == false,
  "hidden Keyring state was not saved per character")
assert(gridUpdates == 1, "Keyring visibility toggle did not refresh the combined inventory")
local collapsedSlots = ShirsInventory_BuildInventorySlots(counts)
assert(table.getn(collapsedSlots) == 4 and collapsedSlots[4].bag == 4,
  "collapsed Keyring must remove only Keyring slots from the combined grid")
local collapsedEntries = ShirsInventory_BuildBagBarModel()
assert(collapsedEntries[6].keyring and collapsedEntries[6].collapsed,
  "Keyring icon must remain present and expose its collapsed state")
assert(collapsedEntries[6].firstInventoryIndex == nil and collapsedEntries[6].lastInventoryIndex == nil,
  "collapsed Keyring icon must not claim a visible slot range")
assert(string.find(ShirsInventory_GetBagBarActionHint(collapsedEntries[6]), "show", 1, true),
  "collapsed Keyring tooltip must explain that clicking shows the slots")
assert(ShirsInventory_HandleBagBarClick(keyringBarButton, "LeftButton"),
  "second Keyring icon click did not restore the slots")
assert(ShirsInventory_GetKeyRingSlotsShown() and ShirsInventoryDB.keyringSlotsShown == true,
  "shown Keyring state was not saved per character")
assert(gridUpdates == 2 and table.getn(ShirsInventory_BuildInventorySlots(counts)) == 8,
  "second Keyring icon click did not restore the integrated slots")
assert(string.find(ShirsInventory_GetBagBarActionHint(ShirsInventory_BuildBagBarModel()[6]), "hide", 1, true),
  "shown Keyring tooltip must explain that clicking hides the slots")

-- Category View must not turn empty Keyring capacity into an Empty category.
local categorySlots = {
  { bag = 0, slot = 1 },
  { bag = KEYRING_CONTAINER, slot = 1 },
}
categoryEmptyKeyring = true
local categoryItems = ShirsInventory_BuildCategoryInventoryItems(categorySlots)
categoryEmptyKeyring = false
assert(table.getn(categoryItems) == 1 and categoryItems[1].bag == 0,
  "empty Keyring capacity was counted as an Empty category item")

local keyButton = { bag = KEYRING_CONTAINER, slot = 3, hasItem = true }
this = keyButton
assert(ShirsInventory_HandleItemClick(keyButton, "LeftButton"), "keyring click was not handled")
assert(table.getn(keyringClicks) == 1 and keyringClicks[1].button == "LeftButton" and keyringClicks[1].owner == keyButton,
  "keyring click must use Blizzard's native KeyRingItemButton_OnClick path")
this = nil
assert(ShirsInventory_SetItemTooltip(keyButton) == "keyring", "keyring tooltip did not use its native inventory path")
assert(tooltipInventory == 71 and tooltipBag == nil and tooltipSlot == nil,
  "keyring tooltip used a normal bag address instead of KeyRingButtonIDToInvSlotID")
local sellCursorCalls = 0
function ShowContainerSellCursor() sellCursorCalls = sellCursorCalls + 1 end
MerchantFrame.IsShown = function() return true end
ShirsInventory_UpdateItemCursor(keyButton, false, false)
assert(cursorUpdates == 1 and sellCursorCalls == 0,
  "keyring hover must preserve native CursorUpdate behavior and never show a merchant sell cursor")
assert(not ShirsInventory_ShouldShowJunkHint(keyButton),
  "keyring tooltip must not offer the add-on's junk-mark action")
assert(type(ShirsInventory_ShouldShowJunkBadge) == "function",
  "keyring-aware junk-badge policy helper is missing")
assert(not ShirsInventory_ShouldShowJunkBadge(keyButton, 12382, 0),
  "gray or marked Keyring items must never display Shir's junk badge")

ShirsInventory_InstallBagHooks()
ToggleKeyRing()
assert(shown, "native Keyring button must open the combined inventory")
assert(IsBagOpen(KEYRING_CONTAINER) == 1, "open combined inventory must report the Keyring as open")
ToggleBag(KEYRING_CONTAINER)
assert(not shown, "native ToggleBag(KEYRING_CONTAINER) must toggle the combined inventory")
OpenBag(KEYRING_CONTAINER)
assert(shown, "native OpenBag(KEYRING_CONTAINER) must open the combined inventory")
CloseBag(KEYRING_CONTAINER)
assert(not shown, "native CloseBag(KEYRING_CONTAINER) must close the combined inventory")
assert(table.getn(delegated) == 0, "combined Keyring routes must not open Blizzard's separate keyring frame")

ShirsInventory_UninstallBagHooks()
ToggleKeyRing()
assert(delegated[1] == "toggleKeyRing", "uninstall must restore Blizzard's original Keyring toggle")

print("KEYRING_INTEGRATION_TEST=PASS")
