local corePath = arg[1]
ShirsInventoryDB = {}
assert(loadfile(corePath))()
local detected = ShirsInventory_DetectBagAddons({
  { name = "SortBags", title = "SortBags", loaded = true },
  { name = "pfUI", title = "pfUI", loaded = true },
  { name = "Cleanup", title = "Cleanup", loaded = true },
  { name = "Bagnon", title = "Bagnon", loaded = true },
  { name = "Bagnon_Core", title = "Bagnon Core", loaded = true },
  { name = "Bagshui", title = "Bagshui", loaded = true },
  { name = "ShirsInventory", title = "Shir's Inventory", loaded = true },
})
assert(table.getn(detected) == 5, "all loaded replacement bag providers should be detected")
assert(detected[1].name == "Bagnon" and detected[2].name == "Bagnon_Core" and
  detected[3].name == "Bagshui" and detected[4].name == "Cleanup" and detected[5].name == "pfUI",
  "providers should be stable and sorted")
local signature = ShirsInventory_GetBagAddonSignature(detected)
assert(signature == "bagnon|bagnon_core|bagshui|cleanup|pfui", "conflict signature should be deterministic")
assert(ShirsInventory_GetBagProviderChoice(signature) == nil, "fresh conflict should require a choice")
assert(not ShirsInventory_SaveBagProviderChoice("invalid", signature), "invalid provider choice was accepted")
assert(ShirsInventory_SaveBagProviderChoice("other", signature), "other provider choice was rejected")
assert(ShirsInventory_GetBagProviderChoice(signature) == "other", "other provider choice was not saved")
assert(ShirsInventory_IsFeatureEnabled("sorter") and ShirsInventory_IsFeatureEnabled("junk"),
  "keeping Bagnon or Bagshui must not disable the independent sorter or junk tools")
assert(ShirsInventory_GetBagProviderChoice("bagnon|bagnon_core|bagshui|cleanup|onebag|pfui") == nil,
  "changed provider set should require a new choice")
assert(ShirsInventory_SaveBagProviderChoice("shirs", signature), "Shir provider choice was rejected")
assert(ShirsInventory_GetBagProviderChoice(signature) == "shirs", "Shir provider choice was not saved")
print("BAG_ADDON_CONFLICT_MODEL_TEST=PASS")
