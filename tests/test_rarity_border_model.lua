local uiPath = arg[1]
assert(loadfile(uiPath))()
assert(type(ShirsInventory_GetRarityBorderLayout) == "function", "rarity-border layout model is missing")
assert(type(ShirsInventory_ShouldShowRarityBorder) == "function", "rarity-border visibility model is missing")
assert(type(ShirsInventory_GetQualityColor) == "function", "Vanilla quality-color lookup helper is missing")
ITEM_QUALITY_COLORS = { [2] = {0.5, 0.5, 0.5} }
ITEM_QUALITY2_COLOR = nil
GetItemQualityColor = function() return 0.12, 1, 0 end
local vanillaColor = ShirsInventory_GetQualityColor(2)
assert(vanillaColor.r == 0.12 and vanillaColor.g == 1 and vanillaColor.b == 0,
  "rarity borders must prefer Vanilla's GetItemQualityColor values like PFUI")
GetItemQualityColor = nil
ITEM_QUALITY_COLORS = { [2] = {0.12, 1, 0} }
vanillaColor = ShirsInventory_GetQualityColor(2)
assert(vanillaColor.r == 0.12 and vanillaColor.g == 1 and vanillaColor.b == 0,
  "quality-color table fallback must normalize numeric Vanilla color entries")
ITEM_QUALITY_COLORS = nil
ITEM_QUALITY2_COLOR = { r = 0.2, g = 0.9, b = 0.1 }
function getglobal(name) if name == "ITEM_QUALITY2_COLOR" then return ITEM_QUALITY2_COLOR end end
vanillaColor = ShirsInventory_GetQualityColor(2)
assert(vanillaColor.r == 0.2 and vanillaColor.g == 0.9 and vanillaColor.b == 0.1,
  "quality-color lookup should retain compatibility with clients exposing numbered globals")
local layout = ShirsInventory_GetRarityBorderLayout()
assert(layout.thickness == 1 and layout.inset == 1,
  "item colors must use a one-pixel frame expanded one pixel toward the neutral inventory outline")
assert(layout.preserveOuterFrame and layout.cornerStyle == "square",
  "colored item edges must preserve the natural outer slot frame and use clean square corners")
assert(layout.texture == "Interface\\Buttons\\WHITE8X8", "rarity border must use a crisp solid texture")
assert(layout.minimumQuality == 2, "common and poor items must not receive rarity-colored borders")
assert(not ShirsInventory_ShouldShowRarityBorder(nil, 4, true), "empty slots must never show rarity borders")
assert(not ShirsInventory_ShouldShowRarityBorder("item", 1, true), "common items must keep the normal slot border")
assert(ShirsInventory_ShouldShowRarityBorder("item", 2, true), "uncommon items must show a green quality border")
assert(ShirsInventory_ShouldShowRarityBorder("item", 4, true), "epic items must show a purple quality border")
assert(not ShirsInventory_ShouldShowRarityBorder("item", 4, false), "disabled rarity borders must stay hidden")

assert(type(ShirsInventory_GetItemInfoFields) == "function", "shared Vanilla item-info parser is missing")
GetItemInfo = function()
  return "Quest Relic", "item:100", 1, 10, "Quest", "Quest", 1, "", "icon"
end
local info = ShirsInventory_GetItemInfoFields("item:100")
assert(info.quality == 1 and info.itemType == "Quest",
  "quest detection must read the target client's nine-value Vanilla tuple")
GetItemInfo = function()
  return "Quest Relic", "item:100", 1, 10, 5, "Quest", "Quest", 1, "", "icon"
end
info = ShirsInventory_GetItemInfoFields("item:100")
assert(info.itemType == "Quest", "quest detection must also support ten-value item-info tuples")
local requestedItem
GetItemInfo = function(item)
  requestedItem = item
  if item == "item:1210:0:0:0" then
    return "Shadowgem", "item:1210:0:0:0", 2, 20, "Miscellaneous", "Gem", 20, "", "icon"
  end
end
info = ShirsInventory_GetItemInfoFields("|cff1eff00|Hitem:1210:0:0:0|h[Shadowgem]|h|r")
assert(requestedItem == "item:1210:0:0:0" and info.quality == 2,
  "Vanilla item info must receive the item token extracted from a colored container hyperlink")
assert(type(ShirsInventory_GetItemBorderModel) == "function", "quest/rarity border model is missing")
assert(type(ShirsInventory_ResolveItemQuality) == "function", "container/item-info quality resolver is missing")
assert(ShirsInventory_ResolveItemQuality(0, 2) == 2,
  "Vanilla container quality zero must fall back to cached item quality like PFUI")
assert(ShirsInventory_ResolveItemQuality(nil, 4) == 4,
  "missing container quality must fall back to item quality")
assert(ShirsInventory_ResolveItemQuality(3, 4) == 3,
  "a positive container quality must remain authoritative")
ITEM_QUALITY_COLORS = { [2] = { r = 0.12, g = 1, b = 0 } }
local questBorder = ShirsInventory_GetItemBorderModel("item", 1, "Quest", true)
assert(questBorder and questBorder.kind == "quest" and questBorder.r == 1 and
  questBorder.g == 0.8 and questBorder.b == 0.2,
  "common quest items must receive PFUI-style warm gold borders")
local rarityBorder = ShirsInventory_GetItemBorderModel("item", 2, "Quest", true)
assert(rarityBorder and rarityBorder.kind == "rarity" and rarityBorder.g == 1,
  "uncommon-or-better quality color must take precedence like PFUI")
assert(not ShirsInventory_GetItemBorderModel("item", 1, "Miscellaneous", true),
  "ordinary common items must retain Shir's neutral slot edge")
assert(not ShirsInventory_GetItemBorderModel("item", 1, "Quest", false),
  "the colored item-border option must disable quest and rarity borders together")
print("RARITY_BORDER_MODEL_TEST=PASS")
