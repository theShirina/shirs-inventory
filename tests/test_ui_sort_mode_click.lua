local corePath, uiPath = arg[1], arg[2]
ShirsInventoryDB = { sortMode = "itemType" }
assert(loadfile(corePath))()
assert(loadfile(uiPath))()
assert(type(ShirsInventory_OnModeButtonClick) == "function", "mode button handler is missing")
local mode = ShirsInventory_OnModeButtonClick()
assert(mode == "rarity", "mode button did not switch to rarity")
assert(ShirsInventoryDB.sortMode == "rarity", "mode button did not persist rarity")
mode = ShirsInventory_OnModeButtonClick()
assert(mode == "itemType", "second click did not restore Item Type")
assert(ShirsInventoryDB.sortMode == "itemType", "second click did not persist Item Type")
print("UI_SORT_MODE_CLICK_TEST=PASS")
