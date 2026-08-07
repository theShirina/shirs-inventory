local corePath = arg[1]
ShirsInventoryDB = {}
assert(loadfile(corePath))()

assert(not ShirsInventory_IsFeatureSelectionComplete(), "new characters should require one setup prompt")
assert(ShirsInventory_IsFeatureEnabled("bagUI"), "new chooser should begin with Full Bag UI selected")
assert(ShirsInventory_IsFeatureEnabled("sorter"), "new chooser should begin with Bag Sorter selected")
assert(ShirsInventory_IsFeatureEnabled("junk"), "new chooser should begin with Sell Junk selected")

local ok = ShirsInventory_SaveFeatureSelection(true, false, true)
assert(ok, "a non-empty custom selection should save")
assert(ShirsInventory_IsFeatureSelectionComplete(), "saved selection should suppress future login prompts")
assert(ShirsInventory_IsFeatureEnabled("bagUI"), "saved bag UI selection should persist")
assert(not ShirsInventory_IsFeatureEnabled("sorter"), "disabled sorter should persist")
assert(ShirsInventory_IsFeatureEnabled("junk"), "saved junk selection should persist")

ok = ShirsInventory_SaveFeatureSelection(false, false, false)
assert(not ok, "the chooser should reject disabling every feature")
assert(ShirsInventory_IsFeatureEnabled("bagUI") and ShirsInventory_IsFeatureEnabled("junk"), "rejected empty selection should not alter saved settings")

ShirsInventory_SetFullAddon()
assert(ShirsInventory_IsFeatureEnabled("bagUI") and ShirsInventory_IsFeatureEnabled("sorter") and ShirsInventory_IsFeatureEnabled("junk"), "Full Addon should enable all three features")

ShirsInventory_SetFeatureEnabled("bagUI", false)
assert(not ShirsInventory_IsFeatureEnabled("bagUI"), "settings should change one feature without resetting the others")
assert(ShirsInventory_IsFeatureEnabled("sorter") and ShirsInventory_IsFeatureEnabled("junk"), "single-feature settings changes should preserve other features")

local oldDB = ShirsInventoryDB
assert(oldDB.setupComplete == true, "selection completion must be stored in the per-character database")
assert(type(oldDB.features) == "table", "feature flags must be stored in the per-character database")

print("FEATURE_SELECTION_MODEL_TEST=PASS")
