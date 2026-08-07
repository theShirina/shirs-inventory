local settingsPath = arg[1]
assert(loadfile(settingsPath))()
local layout = ShirsInventory_GetStandaloneControlLayout("native")
assert(layout.count == 4 and layout.buttonWidth == 18 and layout.buttonHeight == 18 and layout.gap == 3,
  "native bags must use four equal compact controls")
assert(layout.anchorPoint == "TOPRIGHT" and layout.relativePoint == "TOPRIGHT" and
  layout.x == -32 and layout.y == -33,
  "native control strip must remain clear of the Backpack close button and first row")
local source = assert(io.open(settingsPath, "rb")):read("*a")
for _, name in ipairs({
  "ShirsInventoryStandaloneSortButton",
  "ShirsInventoryStandaloneModeButton",
  "ShirsInventoryStandaloneDirectionButton",
  "ShirsInventoryStandaloneSettingsButton",
}) do
  assert(string.find(source, name, 1, true), name .. " must be created")
end
assert(string.find(source, 'driver:RegisterEvent("BAG_UPDATE")', 1, true),
  "layout must refresh as native or external bag ownership changes")
print("NATIVE_BACKPACK_GEOMETRY_TEST=PASS")
