local corePath = arg[1]
BANK_CONTAINER = -1
NUM_BANKBAGSLOTS = 6
assert(loadfile(corePath))()

assert(type(ShirsInventory_BuildBankSlots) == "function", "combined bank slot builder is missing")
local slots = ShirsInventory_BuildBankSlots({
  [BANK_CONTAINER] = 24,
  [5] = 8,
  [6] = 0,
  [7] = 12,
  [8] = 0,
  [9] = 4,
  [10] = 0,
})
assert(table.getn(slots) == 48, "bank should combine the main bank and all six Vanilla bank bags")
assert(slots[1].bag == BANK_CONTAINER and slots[1].slot == 1,
  "combined bank should begin at the first main bank slot")
assert(slots[24].bag == BANK_CONTAINER and slots[24].slot == 24,
  "main bank slots should stay contiguous")
assert(slots[25].bag == 5 and slots[25].slot == 1,
  "first equipped bank bag should follow the main bank")
assert(slots[33].bag == 7 and slots[33].slot == 1,
  "empty bank bags must not create fake slots")
assert(slots[45].bag == 9 and slots[45].slot == 1 and slots[48].slot == 4,
  "later equipped bank bags should keep their container addresses")


assert(type(ShirsInventory_GetBankFrameLayout) == "function", "bank frame layout model is missing")
local layout = ShirsInventory_GetBankFrameLayout()
assert(layout.maximumColumns == 10 and layout.itemSize == 36 and layout.itemStep == 40,
  "bank frame should reuse the combined inventory grid sizing")
assert(layout.gridTopOffset == -64 and layout.footerHeight == 14,
  "bank frame must reuse the compact inventory header and bottom padding")
assert(layout.bankBagButtonSize == 26 and layout.bankBagButtonGap == 0 and
  layout.bankBagIconInset == 0 and not layout.bankBagLayeredBorder,
  "bank bag buttons must use the inventory's single-layer geometry")
assert(layout.bankBagAnchorPoint == "TOPLEFT" and layout.bankBagTopOffset == -32,
  "bank bag buttons must share the inventory header row")

assert(type(ShirsInventory_GetBankFrameAnchor) == "function", "bank frame anchor model is missing")
local anchor = ShirsInventory_GetBankFrameAnchor()
assert(anchor.point == "BOTTOMLEFT" and anchor.relativePoint == "BOTTOMLEFT" and
  anchor.x == 20 and anchor.y == 20,
  "bank frame must grow from the bottom-left of the screen")

assert(type(ShirsInventory_BuildBankBagBarModel) == "function", "bank bag bar model is missing")
local bagBar = ShirsInventory_BuildBankBagBarModel(4, 6, {
  [1] = "bag-one", [2] = "bag-two", [3] = "bag-three", [4] = "bag-four",
}, {
  [BANK_CONTAINER] = 24, [5] = 16, [6] = 18, [7] = 20, [8] = 12,
})
assert(table.getn(bagBar) == 5, "bank bag bar should show bought slots followed by one purchase button")
assert(bagBar[1].bag == 5 and bagBar[1].inventoryIndex == 1 and bagBar[1].texture == "bag-one",
  "first bank bag button has the wrong bag address")
assert(bagBar[4].bag == 8 and bagBar[4].inventoryIndex == 4 and bagBar[4].texture == "bag-four",
  "last bought bank bag button has the wrong bag address")
assert(bagBar[1].slots == 16 and bagBar[1].firstCombinedIndex == 25 and
  bagBar[1].lastCombinedIndex == 40,
  "first bank bag does not describe its represented combined-bank slots")
assert(bagBar[2].slots == 18 and bagBar[2].firstCombinedIndex == 41 and
  bagBar[2].lastCombinedIndex == 58,
  "later bank bag ranges do not follow the preceding bank slots")
assert(bagBar[4].firstCombinedIndex == 79 and bagBar[4].lastCombinedIndex == 90,
  "last purchased bank bag has the wrong combined-bank range")
assert(bagBar[5].purchase and bagBar[5].inventoryIndex == 5,
  "next unbought bank slot should be a purchase button")
local fullBagBar = ShirsInventory_BuildBankBagBarModel(6, 6, {})
assert(table.getn(fullBagBar) == 6 and fullBagBar[6].bag == 10 and not fullBagBar[6].purchase,
  "a fully bought bank should not show a purchase button")

NUM_BANKBAGSLOTS = 7
local extendedSlots = ShirsInventory_BuildBankSlots({ [11] = 2 })
assert(table.getn(extendedSlots) == 2 and extendedSlots[1].bag == 11,
  "patched clients with seven bank bags should include container 11")
NUM_BANKBAGSLOTS = 6

local queried = {}
function GetContainerNumSlots(bag)
  queried[bag] = (queried[bag] or 0) + 1
  return ({ [BANK_CONTAINER] = 24, [5] = 8, [6] = 0, [7] = 12, [8] = 0, [9] = 4, [10] = 0 })[bag] or 0
end
assert(type(ShirsInventory_GetBankSlotCounts) == "function", "bank slot count reader is missing")
local counts = ShirsInventory_GetBankSlotCounts()
assert(counts[BANK_CONTAINER] == 24 and counts[5] == 8 and counts[7] == 12 and counts[9] == 4,
  "bank slot count reader lost a bank container")
assert(queried[BANK_CONTAINER] == 1 and queried[5] == 1 and queried[10] == 1 and not queried[11],
  "bank slot count reader did not scan exactly the six Vanilla bank bags")

print("BANK_MODEL_TEST=PASS")
