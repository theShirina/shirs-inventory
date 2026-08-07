local uiPath = arg[1]

local slotCounts = { [0] = 16, [1] = 12, [2] = 10, [3] = 0, [4] = 14 }
function GetContainerNumSlots(bag) return slotCounts[bag] end
function ContainerIDToInventoryID(bag) return 19 + bag end
function GetInventoryItemTexture(_, inventoryID)
  if inventoryID == 20 then return "BagOne" end
  if inventoryID == 21 then return "BagTwo" end
  if inventoryID == 23 then return "BagFour" end
  return nil
end

assert(loadfile(uiPath))()
assert(type(ShirsInventory_BuildBagBarModel) == "function", "bag-bar model helper is missing")
assert(type(ShirsInventory_GetBagBarLayout) == "function", "bag-bar geometry helper is missing")

local entries = ShirsInventory_BuildBagBarModel()
assert(table.getn(entries) == 5, "bag bar must contain Backpack plus four equipped bag positions")
assert(entries[1].bag == 0 and entries[1].inventoryID == nil and entries[1].slots == 16,
  "Backpack entry is incorrect")
assert(entries[2].bag == 1 and entries[2].inventoryID == 20 and entries[2].texture == "BagOne",
  "first equipped bag entry is incorrect")
assert(entries[1].firstInventoryIndex == 1 and entries[1].lastInventoryIndex == 16,
  "Backpack ownership range is incorrect")
assert(entries[2].firstInventoryIndex == 17 and entries[2].lastInventoryIndex == 28,
  "first equipped bag ownership range is incorrect")
assert(entries[4].bag == 3 and entries[4].inventoryID == 22 and entries[4].slots == 0 and entries[4].empty,
  "empty equipped bag position must remain visible")
assert(entries[5].bag == 4 and entries[5].inventoryID == 23 and entries[5].texture == "BagFour",
  "fourth equipped bag entry is incorrect")

local layout = ShirsInventory_GetBagBarLayout()
assert(layout.buttonSize == 26 and layout.gap == 0, "header bag buttons must touch with no anchor spacing")
assert(layout.iconInset == 0 and not layout.layeredBorder,
  "each bag button must render one full-size icon without a nested Quickslot layer")
assert(layout.anchorPoint == "TOPLEFT" and layout.topOffset == -32,
  "bag bar must sit on the second header row below the name")
assert(layout.gridTopOffset == -64 and layout.heightExtra == 32,
  "one-inventory grid must retain a stable header and footer")
assert(layout.freeTextPoint == "CLOSE_LEFT" and layout.freeTextGap == -2 and layout.freeTextYOffset == 0,
  "free-space status must sit immediately left of the close button")
assert(type(ShirsInventory_ShouldHighlightBagSlot) == "function" and
  ShirsInventory_ShouldHighlightBagSlot({bag = 1}, 1) and
  not ShirsInventory_ShouldHighlightBagSlot({bag = 2}, 1),
  "bag hover must select only slots owned by that physical bag")

local pickedSlot
local putSlot
function PickupBagFromSlot(slot) pickedSlot = slot end
function PutItemInBag(slot) putSlot = slot end
assert(type(ShirsInventory_HandleBagBarClick) == "function", "bag-slot click handler is missing")
assert(type(ShirsInventory_HandleBagBarDrop) == "function", "bag-slot drop handler is missing")
assert(ShirsInventory_HandleBagBarClick({bagEntry = entries[2]}, "LeftButton") and pickedSlot == 20,
  "clicking an equipped bag must use the Vanilla bag-slot pickup API")
pickedSlot = nil
putSlot = nil
function CursorHasItem() return true end
assert(ShirsInventory_HandleBagBarClick({bagEntry = entries[2]}, "LeftButton") and
  pickedSlot == 20 and putSlot == nil,
  "drag completion must not re-equip the picked-up bag through the click path")
function CursorHasItem() return false end
assert(ShirsInventory_HandleBagBarDrop({bagEntry = entries[2]}) and putSlot == 20,
  "dropping a cursor bag onto an equipped slot must use Vanilla PutItemInBag")
putSlot = nil
assert(ShirsInventory_HandleBagBarDrop({bagEntry = entries[4]}) and putSlot == 22,
  "dropping a cursor bag onto an empty equipped position must equip it there")
pickedSlot = nil
assert(not ShirsInventory_HandleBagBarClick({bagEntry = entries[1]}, "LeftButton") and pickedSlot == nil,
  "the fixed Backpack must not be removable")
assert(not ShirsInventory_HandleBagBarDrop({bagEntry = entries[1]}),
  "the fixed Backpack must not accept equipped-bag drops")
assert(type(ShirsInventory_GetBagBarActionHint) == "function", "bag tooltip action model is missing")
assert(not string.find(ShirsInventory_GetBagBarActionHint(entries[2]), "equip", 1, true),
  "an already equipped bag tooltip must not tell the player to equip it")
assert(ShirsInventory_GetBagBarActionHint(entries[4]) == "Drop a bag here.",
  "an empty equipped-bag position should explain its drop target without misleading wording")

print("BAG_BAR_UI_TEST=PASS")
