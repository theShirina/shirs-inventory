local corePath, uiPath, settingsPath = arg[1], arg[2], arg[3]
local settings = assert(io.open(settingsPath, "rb")):read("*a")

ShirsInventoryDB = {}
assert(loadfile(corePath))()
assert(loadfile(uiPath))()

assert(ShirsInventory_GetShowRarityBoxes(),
  "colored rarity boxes must default on")
ShirsInventory_SetShowRarityBoxes(false)
assert(not ShirsInventory_GetShowRarityBoxes(),
  "colored rarity boxes must remain optional")
assert(ShirsInventory_GetUseCoinIcons(),
  "coin-art currency mode must default on")
ShirsInventory_SetUseCoinIcons(false)
assert(not ShirsInventory_GetUseCoinIcons(),
  "plain g/s/c currency mode must remain selectable")
assert(not string.find(settings, "Use icons for inventory header + action buttons", 1, true),
  "inventory text-style toggle must be removed now that bag controls are icon-only")
assert(string.find(settings, "Use coin icons for currency (off = g/s/c text)", 1, true),
  "currency option must explain the text fallback")
assert(string.find(settings, "/si mark <item ID or item link>", 1, true),
  "external bag UI fallback for manual junk marks is not explained")

print("INVENTORY_OPTIONS_UI_TEST=PASS")
