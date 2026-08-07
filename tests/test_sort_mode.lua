local corePath = arg[1]

CursorHasItem = function() return false end
PickupContainerItem = function() end
ClearCursor = function() end

assert(loadfile(corePath))()

local function LT(a, b)
  local fields = a.mode == "rarity" and
    {"rarity", "category", "itemType", "itemSubType", "inventoryType", "itemID", "charges", "suffixID", "enchantID", "uniqueID"} or
    {"category", "itemType", "itemSubType", "inventoryType", "rarity", "itemID", "charges", "suffixID", "enchantID", "uniqueID"}
  local _, field
  for _, field in ipairs(fields) do
    if a[field] ~= b[field] then
      if a[field] == nil then return true end
      if b[field] == nil then return false end
      return a[field] < b[field]
    end
  end
  return false
end

ShirsInventoryDB = nil
if ShirsInventory_GetSortMode() ~= "itemType" then error("fresh default must be itemType") end
if ShirsInventory_GetIgnoreJunkSorting() then error("ignore-junk sorting must default off") end
if not ShirsInventory_SetIgnoreJunkSorting(true) then error("ignore-junk setting rejected true") end
if not ShirsInventoryDB.ignoreJunkSorting then error("ignore-junk setting did not persist") end
if not ShirsInventory_GetIgnoreJunkSorting() then error("ignore-junk getter lost the saved value") end
ShirsInventory_SetIgnoreJunkSorting(false)
if ShirsInventory_GetIgnoreJunkSorting() then error("ignore-junk setting rejected false") end
if not ShirsInventory_SetSortMode("rarity") then error("rarity mode was rejected") end
if ShirsInventoryDB.sortMode ~= "rarity" then error("rarity mode did not persist") end
if not ShirsInventory_SetSortMode("itemType") then error("itemType mode was rejected") end
if ShirsInventory_ToggleSortMode() ~= "rarity" then error("toggle did not switch itemType to rarity") end
if ShirsInventory_GetSortMode() ~= "rarity" then error("toggle did not persist rarity") end
if ShirsInventory_ToggleSortMode() ~= "itemType" then error("toggle did not switch rarity to itemType") end
if ShirsInventory_SetSortMode("name") then error("invalid sort mode was accepted") end
if ShirsInventory_GetSortMode() ~= "itemType" then error("invalid mode changed saved state") end

-- A common consumable sorts before an epic weapon in item-type mode.
local commonConsumableType = ShirsInventory_BuildGeneralSortKey("itemType", 1, 8, 4, 1, 1, 100)
local epicWeaponType = ShirsInventory_BuildGeneralSortKey("itemType", 4, 30, 1, 1, 1, 200)
if not LT(commonConsumableType, epicWeaponType) then error("itemType mode did not prioritize category") end

-- The same pair reverses in rarity mode because quality is the first key.
local commonConsumableRarity = ShirsInventory_BuildGeneralSortKey("rarity", 1, 8, 4, 1, 1, 100)
local epicWeaponRarity = ShirsInventory_BuildGeneralSortKey("rarity", 4, 30, 1, 1, 1, 200)
if not LT(epicWeaponRarity, commonConsumableRarity) then error("rarity mode did not prioritize quality") end

-- Profession groups remain deterministic under both modes.
local miningType = ShirsInventory_BuildGeneralSortKey("itemType", 1, 11, 7, 1, 1, 2770)
local herbType = ShirsInventory_BuildGeneralSortKey("itemType", 1, 12, 7, 2, 1, 765)
local miningRarity = ShirsInventory_BuildGeneralSortKey("rarity", 1, 11, 7, 1, 1, 2770)
local herbRarity = ShirsInventory_BuildGeneralSortKey("rarity", 1, 12, 7, 2, 1, 765)
if not LT(miningType, herbType) or not LT(miningRarity, herbRarity) then
  error("profession material order is not deterministic")
end

-- Binding status must not act like a quality tier.
local whiteBoundRank = ShirsInventory_GetPrimaryCategoryRank(nil, 1, false, false, false, false, nil, true)
local whiteUnboundRank = ShirsInventory_GetPrimaryCategoryRank(nil, 1, false, false, false, false, nil, false)
local greenBoundRank = ShirsInventory_GetPrimaryCategoryRank(nil, 2, false, false, false, false, nil, true)
local rareUnboundRank = ShirsInventory_GetPrimaryCategoryRank(nil, 3, false, false, false, false, nil, false)
if whiteBoundRank ~= 19 or whiteBoundRank ~= whiteUnboundRank then
  error("white soulbound items still receive a special primary rank")
end
if greenBoundRank ~= 10 or rareUnboundRank ~= 10 then
  error("uncommon/rare quality fallback ranks changed unexpectedly")
end
local whiteBoundKey = ShirsInventory_BuildGeneralSortKey("itemType", 1, whiteBoundRank, 2, 1, 1, 300)
local greenBoundKey = ShirsInventory_BuildGeneralSortKey("itemType", 2, greenBoundRank, 2, 1, 1, 301)
if not LT(greenBoundKey, whiteBoundKey) then
  error("white soulbound gear still sorts ahead of uncommon gear")
end

print("SORT_MODE_TEST=PASS")
