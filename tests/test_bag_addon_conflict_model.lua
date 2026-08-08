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
assert(ShirsInventory_GetBagProviderChoice(signature) == "shirs",
  "full suite did not claim bag ownership automatically")
assert(not ShirsInventory_SaveBagProviderChoice("invalid", signature), "invalid provider choice was accepted")
assert(not ShirsInventory_SaveBagProviderChoice("other", signature),
  "external bag ownership is still selectable")
assert(ShirsInventory_GetBagProviderChoice(signature) == "shirs",
  "rejected external choice changed bag ownership")
assert(ShirsInventory_IsFeatureEnabled("bagUI") and ShirsInventory_IsFeatureEnabled("sorter") and
  ShirsInventory_IsFeatureEnabled("junk"), "the full suite is not fully enabled")
assert(ShirsInventory_GetBagProviderChoice("bagnon|bagnon_core|bagshui|cleanup|onebag|pfui") == "shirs",
  "changed provider set stopped automatic Shir ownership")
assert(ShirsInventory_SaveBagProviderChoice("shirs", signature), "Shir ownership compatibility call failed")
print("BAG_ADDON_CONFLICT_MODEL_TEST=PASS")
