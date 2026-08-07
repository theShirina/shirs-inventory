local corePath = arg[1]
assert(loadfile(corePath))()

ShirsInventoryDB = nil

if not ShirsInventory_SetItemOverride(2770, "Herbs") then error("valid override was rejected") end
if ShirsInventory_GetMaterialCategory(2770, "Trade Goods", "Metal & Stone") ~= "Herbs" then error("manual override did not beat item subtype") end
if ShirsInventory_GetItemOverrideCount() ~= 1 then error("override count is wrong") end

if not ShirsInventory_SetItemOverride(2770, "General") then error("General override was rejected") end
if ShirsInventory_GetMaterialCategory(2770, "Trade Goods", "Metal & Stone") ~= nil then error("General override did not suppress automatic material grouping") end

if not ShirsInventory_ClearItemOverride(2770) then error("override clear failed") end
if ShirsInventory_GetMaterialCategory(2770, "Trade Goods", "Metal & Stone") ~= "Mining" then error("clearing override did not restore curated category") end
if ShirsInventory_GetItemOverrideCount() ~= 0 then error("cleared override remains counted") end

local itemID = ShirsInventory_ParseItemID("|cff1eff00|Hitem:12361:0:0:0|h[Blue Sapphire]|h|r")
if itemID ~= 12361 then error("item link parser failed") end
if ShirsInventory_ParseItemID(" 900123 ") ~= 900123 then error("numeric item parser failed") end
if ShirsInventory_SetItemOverride(0, "Mining") then error("invalid item ID was accepted") end
if ShirsInventory_SetItemOverride(900123, "Cooking") then error("invalid category was accepted") end

print("ITEM_OVERRIDE_TEST=PASS")
