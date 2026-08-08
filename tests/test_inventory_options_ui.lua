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
assert(not string.find(settings, "Full Bag UI", 1, true),
  "full-suite settings still expose the old bag UI feature switch")
assert(not string.find(settings, "Bag Sorter", 1, true),
  "full-suite settings still expose the old sorter feature switch")
assert(not string.find(settings, "Sell Junk + manual junk marks", 1, true),
  "full-suite settings still expose the old junk feature switch")
assert(not string.find(settings, "Choose Bag UI", 1, true),
  "full-suite settings still expose the old provider chooser")
assert(not string.find(settings, "Save Custom Choice", 1, true),
  "first-run custom feature selection still exists")
assert(not string.find(settings, "settingsFrame.errorText", 1, true),
  "settings still reference the removed feature-selection error label")
assert(string.find(settings, 'merchantSellButton:SetWidth(36)', 1, true) and
  string.find(settings, 'merchantSellButton:SetHeight(36)', 1, true),
  "merchant Sell Junk is not repair-button sized")
assert(string.find(settings,
  'merchantSellButton:SetPoint("RIGHT", MerchantRepairItemButton, "LEFT", -2, 0)', 1, true),
  "merchant Sell Junk is not immediately left of Repair an Item")
assert(string.find(settings,
  'CreateFrame("Button", "ShirsInventoryMerchantSellButton", MerchantFrame, "ItemButtonTemplate")', 1, true),
  "merchant Sell Junk does not use the standard bordered item-button frame")
assert(string.find(settings, 'sellJunkTexture:SetTexture("Interface\\\\Icons\\\\INV_Misc_Coin_01")', 1, true),
  "merchant Sell Junk does not use the coin icon")
assert(string.find(settings, 'sellJunkTexture:SetTexCoord(0, 1, 0, 1)', 1, true),
  "merchant Sell Junk icon remains zoom-cropped")
assert(not string.find(settings, 'merchantSellButton:SetText("Sell Junk")', 1, true),
  "merchant Sell Junk still uses the wide text button")
assert(string.find(settings, "MerchantRepairText:Hide()", 1, true),
  "merchant repair label remains visible behind the icon row")

print("INVENTORY_OPTIONS_UI_TEST=PASS")
