local settingsPath = arg[1]
local settings = assert(io.open(settingsPath, "rb")):read("*a")

assert(string.find(settings, "Ignore gray + manually marked junk while sorting", 1, true),
  "ignore-junk sorting checkbox is missing")
assert(string.find(settings,
  "settingsFrame.ignoreJunkSorting:SetChecked(ShirsInventory_GetIgnoreJunkSorting() and 1 or nil)",
  1, true), "ignore-junk checkbox does not refresh from saved state")
assert(string.find(settings,
  "ShirsInventory_SetIgnoreJunkSorting(this:GetChecked() and true or false)",
  1, true), "ignore-junk checkbox does not persist clicks")
assert(string.find(settings, "settingsFrame.ignoreJunkSorting:Enable()", 1, true),
  "ignore-junk checkbox is not enabled with the sorter")
assert(string.find(settings, "settingsFrame.ignoreJunkSorting:Disable()", 1, true),
  "ignore-junk checkbox is not disabled without the sorter")
assert(string.find(settings, "Keep quest items at the opposite end of sorted items", 1, true),
  "quest opposite-edge checkbox is missing")
assert(string.find(settings,
  "settingsFrame.questItemsOppositeEdge:SetChecked(ShirsInventory_GetQuestItemsOppositeEdge() and 1 or nil)",
  1, true), "quest opposite-edge checkbox does not refresh from saved state")
assert(string.find(settings,
  "ShirsInventory_SetQuestItemsOppositeEdge(this:GetChecked() and true or false)",
  1, true), "quest opposite-edge checkbox does not persist clicks")
assert(string.find(settings, "settingsFrame.questItemsOppositeEdge:Enable()", 1, true),
  "quest opposite-edge checkbox is not enabled with the sorter")
assert(string.find(settings, "settingsFrame.questItemsOppositeEdge:Disable()", 1, true),
  "quest opposite-edge checkbox is not disabled without the sorter")

print("IGNORE_JUNK_SETTING_UI_TEST=PASS")
