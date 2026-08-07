local accountPath = arg[1]
assert(loadfile(accountPath))()
assert(type(ShirsInventory_GetCoinWidgetModel) == "function",
  "real-texture coin widget model is missing")
local model = ShirsInventory_GetCoinWidgetModel(123456)
assert(model.gold == 12 and model.silver == 34 and model.copper == 56,
  "coin widget amounts are incorrect")
assert(model.goldText == "12" and model.silverText == "34" and model.copperText == "56",
  "coin widget text must not contain unsupported inline texture escapes")
assert(not string.find(model.goldText .. model.silverText .. model.copperText, "|T", 1, true),
  "coin widget must use texture regions, not inline texture markup")
assert(model.width == 94, "coin widget width must reserve even space for three real texture regions")
assert(model.texture == "Interface\\MoneyFrame\\UI-MoneyIcons",
  "Vanilla coin mode must use the real UI-MoneyIcons sprite")
assert(model.goldTexCoord[1] == 0 and model.goldTexCoord[2] == 0.25 and
  model.silverTexCoord[1] == 0.25 and model.silverTexCoord[2] == 0.5 and
  model.copperTexCoord[1] == 0.5 and model.copperTexCoord[2] == 0.75,
  "coin denominations must select the correct Vanilla sprite quarters")
print("CURRENCY_WIDGET_MODEL_TEST=PASS")
