local corePath = arg[1]
assert(loadfile(corePath))()

local slots = ShirsInventory_BuildInventorySlots({ [0] = 16, [1] = 4, [2] = 0, [3] = 2, [4] = 1 })
assert(table.getn(slots) == 23, "all normal bag slots should form one list")
assert(slots[1].bag == 0 and slots[1].slot == 1, "combined inventory should begin at backpack slot 1")
assert(slots[16].bag == 0 and slots[16].slot == 16, "backpack should remain contiguous")
assert(slots[17].bag == 1 and slots[17].slot == 1, "first equipped bag should continue without a boundary gap")
assert(slots[21].bag == 3 and slots[21].slot == 1, "empty bags should add no fake slots")
assert(slots[23].bag == 4 and slots[23].slot == 1, "last bag should end the same list")

assert(ShirsInventory_GetItemId("|cffffffff|Hitem:7076:0:0:0|h[Essence of Earth]|h|r") == 7076, "item id should parse from a Vanilla link")
assert(ShirsInventory_GetItemId(nil) == nil, "nil links should stay nil")

local marks = { [7076] = true }
assert(ShirsInventory_IsJunk(111, 0, marks), "gray quality should always count as junk")
assert(ShirsInventory_IsJunk(7076, 2, marks), "manually marked item ids should count as junk")
assert(not ShirsInventory_IsJunk(222, 2, marks), "unmarked non-gray items should not count as junk")

local queue = ShirsInventory_BuildJunkQueue({
  { bag = 0, slot = 1, itemId = 111, quality = 0, locked = nil },
  { bag = 0, slot = 2, itemId = 7076, quality = 2, locked = nil },
  { bag = 1, slot = 1, itemId = 222, quality = 0, locked = 1 },
  { bag = 1, slot = 2, itemId = 333, quality = 1, locked = nil },
}, marks)
assert(table.getn(queue) == 2, "queue should include unlocked gray and manually marked stacks only")
assert(queue[1].bag == 0 and queue[1].slot == 1 and queue[1].itemId == 111, "queue order should follow the combined inventory")
assert(queue[2].bag == 0 and queue[2].slot == 2 and queue[2].itemId == 7076, "manual junk should follow gray junk in slot order")

print("INVENTORY_MODEL_TEST=PASS")
