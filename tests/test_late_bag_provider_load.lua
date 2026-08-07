local corePath, uiPath = arg[1], arg[2]
ShirsInventoryDB = { setupComplete = true, features = { bagUI = true, sorter = true, junk = true } }
assert(loadfile(corePath))()
assert(loadfile(uiPath))()
assert(type(ShirsInventory_HandleLoaderEvent) == "function", "loader event handler is missing")

local initialized = 0
local scans = 0
local applied = 0
local unregistered = {}
ShirsInventory_InitializeUI = function() initialized = initialized + 1 end
ShirsInventory_ScanLoadedBagAddons = function() scans = scans + 1 end
ShirsInventory_ApplyFeatureSelection = function() applied = applied + 1 end
local loader = { UnregisterEvent = function(_, name) unregistered[name] = true end }

ShirsInventory_HandleLoaderEvent("PLAYER_LOGIN", nil, loader)
assert(initialized == 1 and scans == 1 and applied == 1, "login initialization was not preserved")
assert(unregistered.PLAYER_LOGIN and not unregistered.ADDON_LOADED,
  "ADDON_LOADED must remain registered for load-on-demand Bagnon modules")
ShirsInventory_HandleLoaderEvent("ADDON_LOADED", "Bagnon", loader)
assert(scans == 2 and applied == 2, "late Bagnon load did not refresh provider ownership")
ShirsInventory_HandleLoaderEvent("ADDON_LOADED", "Bagnon_Core", loader)
assert(scans == 3 and applied == 3, "late Bagnon core load did not refresh provider ownership")
ShirsInventory_HandleLoaderEvent("ADDON_LOADED", "Bagshui", loader)
assert(scans == 4 and applied == 4, "late Bagshui load did not refresh provider ownership")
ShirsInventory_HandleLoaderEvent("ADDON_LOADED", "AtlasLoot", loader)
assert(scans == 4 and applied == 4, "unrelated load-on-demand addon triggered a provider rescan")

print("LATE_BAG_PROVIDER_LOAD_TEST=PASS")
