local corePath = arg[1]
ShirsInventoryDB = {
  setupComplete = false,
  features = { bagUI = false, sorter = false, junk = false },
  bagProviderChoice = "other",
  bagProviderSignature = "pfui",
}
assert(loadfile(corePath))()

assert(ShirsInventory_IsFeatureSelectionComplete(),
  "the full suite must not wait for a per-character feature chooser")
assert(ShirsInventory_IsFeatureEnabled("bagUI"), "full bag UI must always be enabled")
assert(ShirsInventory_IsFeatureEnabled("sorter"), "sorter must always be enabled")
assert(ShirsInventory_IsFeatureEnabled("junk"), "junk tools must always be enabled")
assert(not ShirsInventory_IsFeatureEnabled("unknown"), "unknown feature became enabled")

assert(not ShirsInventory_SetFeatureEnabled("bagUI", false),
  "legacy callers must not be able to disable the full bag UI")
assert(not ShirsInventory_SaveFeatureSelection(true, false, true),
  "partial legacy feature selections must be rejected")
assert(ShirsInventory_SetFullAddon(), "full-suite compatibility helper failed")
assert(ShirsInventory_IsFeatureEnabled("bagUI") and
  ShirsInventory_IsFeatureEnabled("sorter") and
  ShirsInventory_IsFeatureEnabled("junk"),
  "legacy helpers changed the full-suite feature state")

assert(ShirsInventory_GetBagProviderChoice("pfui") == "shirs",
  "Shir's Inventory must always own the bag UI")
assert(not ShirsInventory_SaveBagProviderChoice("other", "pfui"),
  "legacy provider API still accepts external bag ownership")
assert(ShirsInventory_SaveBagProviderChoice("shirs", "pfui"),
  "legacy provider API rejected Shir's ownership")

assert(ShirsInventoryDB.setupComplete == nil, "obsolete setup completion state was not removed")
assert(ShirsInventoryDB.features == nil, "obsolete feature flags were not removed")
assert(ShirsInventoryDB.bagProviderChoice == nil, "obsolete provider choice was not removed")
assert(ShirsInventoryDB.bagProviderSignature == nil, "obsolete provider signature was not removed")

print("FEATURE_SELECTION_MODEL_TEST=PASS")
