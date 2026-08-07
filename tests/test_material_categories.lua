local corePath = arg[1]
local chunk, loadError = loadfile(corePath)
if not chunk then
  error("ShirsInventory core missing: " .. tostring(loadError))
end
chunk()

if type(ShirsInventory_GetMaterialCategory) ~= "function" then
  error("ShirsInventory_GetMaterialCategory is missing")
end

local cases = {
  {2770, "Trade Goods", "Metal & Stone", "Mining"},
  {765, "Trade Goods", "Herb", "Herbs"},
  {2589, "Trade Goods", "Cloth", "Cloth"},
  {2318, "Trade Goods", "Leather", "Leather"},
  {10940, "Trade Goods", "Enchanting", "Enchanting"},
  {7067, "Trade Goods", "Elemental", "Elemental"},
  {4357, "Trade Goods", "Parts", "Engineering"},
  {12359, nil, nil, nil},
  {999999, "Trade Goods", "Metal & Stone", "Mining"},
  {999998, "Armor", "Plate", nil},
}

for _, case in ipairs(cases) do
  local actual = ShirsInventory_GetMaterialCategory(case[1], case[2], case[3])
  if actual ~= case[4] then
    error("item " .. tostring(case[1]) .. ": expected " .. tostring(case[4]) .. ", got " .. tostring(actual))
  end
end

print("MATERIAL_CATEGORY_TEST=PASS")
