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

-- Item-type grouping must treat enchanting dust, essences, and shards as one
-- material group instead of splitting that group by auction subtype.
local dustType = ShirsInventory_BuildGeneralSortKey("itemType", 1, 15.25, 7, 1, 1, 10940, "top", "Enchanting Materials")
local essenceType = ShirsInventory_BuildGeneralSortKey("itemType", 2, 15.25, 9, 2, 2, 10938, "top", "Enchanting Materials")
local shardType = ShirsInventory_BuildGeneralSortKey("itemType", 3, 15.25, 5, 3, 3, 11139, "top", "Enchanting Materials")
if dustType.itemType ~= essenceType.itemType or essenceType.itemType ~= shardType.itemType or
  dustType.itemSubType ~= essenceType.itemSubType or essenceType.itemSubType ~= shardType.itemSubType or
  dustType.inventoryType ~= essenceType.inventoryType or essenceType.inventoryType ~= shardType.inventoryType then
  error("item-type mode still separates enchanting materials by runtime type fields")
end

local righteousOrbType = ShirsInventory_BuildGeneralSortKey("itemType", 2, 15, 7, 6, 4, 12811, "top", "Enchanting")
if righteousOrbType.itemType ~= 7 or righteousOrbType.itemSubType ~= 6 or righteousOrbType.inventoryType ~= 4 then
  error("item-type mode changed one-off enchanting runtime fields")
end

-- Rarity grouping must retain its existing subtype keys; quality remains the
-- primary field and this item-type-only adjustment must not alter that mode.
local dustRarity = ShirsInventory_BuildGeneralSortKey("rarity", 1, 15, 7, 1, 1, 10940, "top", "Enchanting")
local essenceRarity = ShirsInventory_BuildGeneralSortKey("rarity", 2, 15, 9, 2, 2, 10938, "top", "Enchanting")
local shardRarity = ShirsInventory_BuildGeneralSortKey("rarity", 3, 15, 5, 3, 3, 11139, "top", "Enchanting")
if dustRarity.itemType ~= 7 or essenceRarity.itemType ~= 9 or shardRarity.itemType ~= 5 or
  dustRarity.itemSubType ~= 1 or essenceRarity.itemSubType ~= 2 or shardRarity.itemSubType ~= 3 or
  dustRarity.inventoryType ~= 1 or essenceRarity.inventoryType ~= 2 or shardRarity.inventoryType ~= 3 then
  error("rarity mode changed enchanting runtime type fields")
end
if not LT(shardRarity, essenceRarity) or not LT(essenceRarity, dustRarity) then
  error("rarity mode no longer prioritizes enchanting-material quality")
end

local masteryTokenType = ShirsInventory_BuildGeneralSortKey("itemType", 3, 18.25, 7, 4, 2, 26039, "top", "Raid Tokens")
local naxxTokenType = ShirsInventory_BuildGeneralSortKey("itemType", 3, 18.25, 9, 8, 6, 26043, "top", "Raid Tokens")
if masteryTokenType.itemType ~= naxxTokenType.itemType or
  masteryTokenType.itemSubType ~= naxxTokenType.itemSubType or
  masteryTokenType.inventoryType ~= naxxTokenType.inventoryType then
  error("item-type mode still separates Mastery and raid tokens by runtime type fields")
end

local masteryTokenRarity = ShirsInventory_BuildGeneralSortKey("rarity", 3, 19, 7, 4, 2, 26039, "top", "Raid Tokens")
local naxxTokenRarity = ShirsInventory_BuildGeneralSortKey("rarity", 3, 19, 9, 8, 6, 26043, "top", "Raid Tokens")
if masteryTokenRarity.itemType ~= 7 or naxxTokenRarity.itemType ~= 9 or
  masteryTokenRarity.itemSubType ~= 4 or naxxTokenRarity.itemSubType ~= 8 or
  masteryTokenRarity.inventoryType ~= 2 or naxxTokenRarity.inventoryType ~= 6 then
  error("rarity mode changed Mastery or raid token runtime fields")
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

if ShirsInventory_GetOppositeEdgeRank(true, false, true) ~= 1 then
  error("grouped quest item did not receive the inner opposite-edge rank")
end
if ShirsInventory_GetOppositeEdgeRank(false, true, true) ~= 2 then
  error("conjured item did not receive the outer opposite-edge rank")
end
if ShirsInventory_GetOppositeEdgeRank(true, true, true) ~= 1 then
  error("quest-outlined conjured item lost quest precedence")
end
if ShirsInventory_GetOppositeEdgeRank(true, false, false) ~= nil then
  error("disabled quest grouping still assigned an opposite-edge rank")
end
if ShirsInventory_GetOppositeEdgeRank(false, true, false) ~= 2 then
  error("conjured grouping incorrectly depends on the quest setting")
end

print("SORT_MODE_TEST=PASS")
