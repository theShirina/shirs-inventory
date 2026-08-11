local corePath = arg[1]
local chunk, loadError = loadfile(corePath)
if not chunk then
  error("ShirsInventory core missing: " .. tostring(loadError))
end
chunk()

if type(ShirsInventory_GetMaterialCategory) ~= "function" then
  error("ShirsInventory_GetMaterialCategory is missing")
end
if type(ShirsInventory_GetSortMaterialCategory) ~= "function" then
  error("ShirsInventory_GetSortMaterialCategory is missing")
end
if type(ShirsInventory_GetSortConsumable) ~= "function" then
  error("ShirsInventory_GetSortConsumable is missing")
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

local generalEnchantingMaterials = {
  {10940, "Strange Dust"}, {11083, "Soul Dust"}, {11137, "Vision Dust"},
  {11176, "Dream Dust"}, {16204, "Illusion Dust"},
  {10938, "Lesser Magic Essence"}, {10939, "Greater Magic Essence"},
  {10998, "Lesser Astral Essence"}, {11082, "Greater Astral Essence"},
  {11134, "Lesser Mystic Essence"}, {11135, "Greater Mystic Essence"},
  {11174, "Lesser Nether Essence"}, {11175, "Greater Nether Essence"},
  {16202, "Lesser Eternal Essence"}, {16203, "Greater Eternal Essence"},
  {10978, "Small Glimmering Shard"}, {11084, "Large Glimmering Shard"},
  {11138, "Small Glowing Shard"}, {11139, "Large Glowing Shard"},
  {11177, "Small Radiant Shard"}, {11178, "Large Radiant Shard"},
  {14343, "Small Brilliant Shard"}, {14344, "Large Brilliant Shard"},
}

for _, item in ipairs(generalEnchantingMaterials) do
  local itemID, itemName = item[1], item[2]
  local itemTypeCategory = ShirsInventory_GetSortMaterialCategory("itemType", itemID, "Localized name unavailable", nil)
  if itemTypeCategory ~= "Enchanting Materials" then
    error(itemName .. ": item-type mode expected Enchanting Materials, got " .. tostring(itemTypeCategory))
  end
  local rarityCategory = ShirsInventory_GetSortMaterialCategory("rarity", itemID, itemName, nil)
  if rarityCategory ~= nil then
    error(itemName .. ": rarity mode changed to " .. tostring(rarityCategory))
  end
end

local excludedOneOffMaterials = {
  {12811, "Righteous Orb"}, {7078, "Essence of Fire"}, {12808, "Essence of Undeath"},
  {22203, "Large Obsidian Shard"}, {5075, "Blood Shard"},
  {26120, "Eternal Swiftness Potion"}, {2454, "Elixir of Lion's Strength"},
  {4357, "Rough Dynamite"}, {7079, "Globe of Water"}, {1206, "Moss Agate"},
}

for _, item in ipairs(excludedOneOffMaterials) do
  local itemID, itemName = item[1], item[2]
  local actual = ShirsInventory_GetSortMaterialCategory("itemType", itemID, itemName, nil)
  if actual ~= nil then
    error(itemName .. ": one-off material was incorrectly grouped as " .. tostring(actual))
  end
end

if ShirsInventory_GetSortMaterialCategory("rarity", 10940, "Strange Dust", "Enchanting") ~= "Enchanting" then
  error("rarity mode discarded an existing runtime material category")
end

if ShirsInventory_GetSortMaterialCategory("itemType", 12811, "Righteous Orb", "Enchanting") ~= "Enchanting" then
  error("item-type mode changed an existing one-off enchanting classification")
end

if ShirsInventory_GetSortConsumable("itemType", "Enchanting Materials", true) then
  error("item-type mode still treats usable Lesser/Greater Essences as consumables")
end
if not ShirsInventory_GetSortConsumable("rarity", "Enchanting", true) then
  error("rarity mode changed usable Lesser/Greater Essence behavior")
end

local masteryAndRaidTokens = {
  {26039, "Token of Mastery"},
  {26040, "Token of Molten Core"},
  {26041, "Token of Blackwing Lair"},
  {26042, "Token of Ahn'Qiraj"},
  {26043, "Token of Naxxramas"},
}

for _, item in ipairs(masteryAndRaidTokens) do
  local itemTypeCategory = ShirsInventory_GetSortMaterialCategory("itemType", item[1], item[2], nil)
  if itemTypeCategory ~= "Raid Tokens" then
    error(item[2] .. ": expected Raid Tokens in item-type mode, got " .. tostring(itemTypeCategory))
  end
  local rarityCategory = ShirsInventory_GetSortMaterialCategory("rarity", item[1], item[2], nil)
  if rarityCategory ~= nil then
    error(item[2] .. ": rarity mode changed to " .. tostring(rarityCategory))
  end
end

if ShirsInventory_GetSortMaterialCategory("itemType", 12844, "Argent Dawn Valor Token", nil) ~= nil then
  error("Argent Dawn Valor Token was incorrectly grouped with Microbot raid tokens")
end

local standardEnchantingRank = ShirsInventory_GetPrimaryCategoryRank(
  nil, 2, false, false, false, false, "Enchanting Materials", false, false
)
local genericEnchantingRank = ShirsInventory_GetPrimaryCategoryRank(
  nil, 2, false, false, false, false, "Enchanting", false, false
)
local raidTokenRank = ShirsInventory_GetPrimaryCategoryRank(
  nil, 3, false, false, false, false, "Raid Tokens", false, false
)
if standardEnchantingRank ~= 15.25 or genericEnchantingRank ~= 15 or raidTokenRank ~= 18.25 then
  error("sort-only category ranks are not unique and deterministic")
end

print("MATERIAL_CATEGORY_TEST=PASS")
