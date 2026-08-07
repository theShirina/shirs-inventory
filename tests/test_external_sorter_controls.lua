local settingsPath = arg[1]
local calls = {}
function ShirsInventory_SortBags() table.insert(calls, "sort"); return true end
function ShirsInventory_OnModeButtonClick() table.insert(calls, "mode"); return "rarity" end
function ShirsInventory_ToggleDirection() table.insert(calls, "direction"); return "top" end
function ShirsInventory_ShowSettings() table.insert(calls, "settings") end
function ShirsInventory_RefreshButtonStyles() table.insert(calls, "refresh") end

assert(loadfile(settingsPath))()
ShirsInventory_RefreshButtonStyles = function() table.insert(calls, "refresh") end
ShirsInventory_ShowSettings = function() table.insert(calls, "settings") end
assert(type(ShirsInventory_GetStandaloneControlSpecs) == "function",
  "standalone Sort, Grouping, Direction, and Settings model is missing")
local specs = ShirsInventory_GetStandaloneControlSpecs()
assert(table.getn(specs) == 4, "external bag providers must expose all four standalone controls")
assert(specs[1].name == "sort" and specs[2].name == "mode" and
  specs[3].name == "direction" and specs[4].name == "settings",
  "standalone control order must match the full bag UI")
local index
for index = 1, table.getn(specs) do
  assert(specs[index].width == 18 and specs[index].height == 18,
    "all standalone controls must use the same compact square size")
  assert(type(specs[index].onClick) == "function", specs[index].name .. " must have a live click handler")
end

specs[1].onClick()
specs[2].onClick()
specs[3].onClick()
specs[4].onClick()
assert(calls[1] == "sort" and calls[2] == "mode" and calls[3] == "refresh" and
  calls[4] == "direction" and calls[5] == "refresh" and calls[6] == "settings",
  "standalone controls must execute sorter and sorter-setting actions, not inert UI helpers")

print("EXTERNAL_SORTER_CONTROLS_TEST=PASS")
