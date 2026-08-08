local uiPath, settingsPath = arg[1], arg[2]
local ui = assert(io.open(uiPath, "rb")):read("*a")
local settings = assert(io.open(settingsPath, "rb")):read("*a")

assert(string.find(ui, 'RegisterEvent("PLAYER_LOGIN")', 1, true),
  "late bag-provider reclaim scan is missing")
assert(not string.find(settings, "Choose Your Bag Inventory", 1, true),
  "bag-provider chooser still exists")
assert(not string.find(settings, "Use Shir's Bag UI", 1, true),
  "Shir provider selection button still exists")
assert(not string.find(settings, "Keep Other Bag Addon", 1, true),
  "external provider selection button still exists")
assert(not string.find(ui, 'command == "bagui"', 1, true),
  "/si bagui still exposes provider selection")
assert(not string.find(settings, "Choose Bag UI...", 1, true),
  "settings still expose provider selection")

print("BAG_ADDON_CONFLICT_UI_TEST=PASS")
