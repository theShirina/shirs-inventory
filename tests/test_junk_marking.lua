local corePath = arg[1]
local junkPath = arg[2]

ShirsInventoryDB = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

assert(loadfile(corePath))()
assert(loadfile(junkPath))()

local marked, reason = ShirsInventory_ToggleJunk(7076, 2)
assert(marked == true and reason == "marked", "first toggle should mark a non-gray item")
assert(ShirsInventoryDB.junkItems[7076] == true, "mark should persist by item id")
assert(ShirsInventory_IsJunk(7076, 2, ShirsInventoryDB.junkItems), "every copy of the marked item id should be junk")

marked, reason = ShirsInventory_ToggleJunk(7076, 2)
assert(marked == false and reason == "unmarked", "second toggle should remove the manual mark")
assert(ShirsInventoryDB.junkItems[7076] == nil, "unmark should remove the saved key")

marked, reason = ShirsInventory_ToggleJunk(111, 0)
assert(marked == true and reason == "automatic", "gray items should report automatic junk")
assert(ShirsInventoryDB.junkItems[111] == nil, "gray items should not need a saved manual mark")

marked, reason = ShirsInventory_ToggleJunk(nil, 2)
assert(marked == false and reason == "invalid", "items without an id should not be marked")

print("JUNK_MARKING_TEST=PASS")
