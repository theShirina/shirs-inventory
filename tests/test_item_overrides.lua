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

-- User-selected items beside Hearthstone are stored as an ordered, per-character
-- item-ID list. Hearthstone itself stays the fixed anchor and cannot be added.
if not ShirsInventory_GetAutomaticHearthstoneItems() then
  error("automatic Hearthstone items must remain enabled for existing users")
end
if ShirsInventory_SetAutomaticHearthstoneItems(false) then
  error("automatic Hearthstone item setting did not persist off")
end
if ShirsInventory_GetLockSelectedItemSlots() then
  error("selected-item slot locking must default off for existing characters")
end
if not ShirsInventory_SetLockSelectedItemSlots(true) then
  error("selected-item slot locking did not persist on")
end
local ok, status, selectedID = ShirsInventory_SetHearthstoneItem(
  "|cff0070dd|Hitem:15138:0:0:0|h[Onyxia Scale Cloak]|h|r", true
)
if not ok or status ~= "added" or selectedID ~= 15138 then
  error("linked item was not added beside Hearthstone")
end
ok, status, selectedID = ShirsInventory_SetHearthstoneItem(12361, true)
if not ok or status ~= "added" or selectedID ~= 12361 then
  error("numeric item was not added beside Hearthstone")
end
if ShirsInventory_GetHearthstoneItemCount() ~= 2 or
  ShirsInventory_GetHearthstoneItemIndex(15138) ~= 1 or
  ShirsInventory_GetHearthstoneItemIndex(12361) ~= 2 then
  error("selected Hearthstone item order is wrong")
end
if not ShirsInventory_IsSelectedItemSlotLocked(15138, 0) or
  not ShirsInventory_IsSelectedItemSlotLocked(12361, 4) or
  ShirsInventory_IsSelectedItemSlotLocked(15138, -1) or
  ShirsInventory_IsSelectedItemSlotLocked(15138, 5) or
  ShirsInventory_IsSelectedItemSlotLocked(99999, 0) then
  error("selected-item slot locking did not stay scoped to selected carried items")
end
if ShirsInventory_SetLockSelectedItemSlots(false) or
  ShirsInventory_IsSelectedItemSlotLocked(15138, 0) then
  error("disabling selected-item slot locking did not release carried slots")
end
local moved, movedIndex = ShirsInventory_MoveHearthstoneItem(12361, -1)
if not moved or movedIndex ~= 1 or
  ShirsInventory_GetHearthstoneItemIndex(12361) ~= 1 or
  ShirsInventory_GetHearthstoneItemIndex(15138) ~= 2 then
  error("selected Hearthstone item could not move up")
end
ok, status = ShirsInventory_SetHearthstoneItem(22222, true)
if not ok or status ~= "added" then error("drag-order fixture item 22222 was rejected") end
ok, status = ShirsInventory_SetHearthstoneItem(33333, true)
if not ok or status ~= "added" then error("drag-order fixture item 33333 was rejected") end
moved, movedIndex = ShirsInventory_MoveHearthstoneItemToItem(12361, 22222)
local dragOrder = ShirsInventory_GetHearthstoneItems()
if not moved or movedIndex ~= 3 or dragOrder[1] ~= 15138 or dragOrder[2] ~= 22222 or
  dragOrder[3] ~= 12361 or dragOrder[4] ~= 33333 then
  error("selected Hearthstone item did not move down to the drop target position")
end
moved, movedIndex = ShirsInventory_MoveHearthstoneItemToItem(33333, 15138)
dragOrder = ShirsInventory_GetHearthstoneItems()
if not moved or movedIndex ~= 1 or dragOrder[1] ~= 33333 or dragOrder[2] ~= 15138 or
  dragOrder[3] ~= 22222 or dragOrder[4] ~= 12361 then
  error("selected Hearthstone item did not move up to the drop target position")
end
moved, movedIndex = ShirsInventory_MoveHearthstoneItemToItem(33333, 33333)
if not moved or movedIndex ~= 1 or ShirsInventory_GetHearthstoneItems()[1] ~= 33333 then
  error("dropping a selected Hearthstone item on itself was not a stable no-op")
end
ok, status = ShirsInventory_ToggleHearthstoneItem(15138)
if not ok or status ~= "removed" or ShirsInventory_GetHearthstoneItemIndex(15138) then
  error("selected Hearthstone item did not toggle off")
end
ok, status = ShirsInventory_SetHearthstoneItem(6948, true)
if ok or status ~= "fixed" then
  error("fixed Hearthstone anchor was accepted as a user selection")
end
ShirsInventoryDB.hearthstoneItems = {12361, "bad", 12361, 0, 15138}
local normalized = ShirsInventory_GetHearthstoneItems()
if table.getn(normalized) ~= 2 or normalized[1] ~= 12361 or normalized[2] ~= 15138 then
  error("malformed or duplicate selected Hearthstone items were not repaired")
end
if ShirsInventory_ClearHearthstoneItems() ~= 2 or ShirsInventory_GetHearthstoneItemCount() ~= 0 then
  error("selected Hearthstone items were not cleared")
end

local selectionIndex
for selectionIndex = 1, 30 do
  ok, status = ShirsInventory_SetHearthstoneItem(80000 + selectionIndex, true)
  if not ok or status ~= "added" then error("selected Hearthstone item limit rejected a valid entry") end
end
ok, status = ShirsInventory_SetHearthstoneItem(90000, true)
if ok or status ~= "full" or ShirsInventory_GetHearthstoneItemCount() ~= 30 then
  error("selected Hearthstone item limit did not stop at 30 entries")
end
ShirsInventory_ClearHearthstoneItems()
local oversizedSelection = {}
for selectionIndex = 1, 35 do table.insert(oversizedSelection, 91000 + selectionIndex) end
ShirsInventoryDB.hearthstoneItems = oversizedSelection
normalized = ShirsInventory_GetHearthstoneItems()
if table.getn(normalized) ~= 30 or normalized[1] ~= 91001 or normalized[30] ~= 91030 then
  error("oversized saved Hearthstone item list did not normalize to the first 30 valid IDs")
end
ShirsInventory_ClearHearthstoneItems()

ShirsInventoryDB.automaticHearthstoneItems = "malformed"
if not ShirsInventory_GetAutomaticHearthstoneItems() or
  type(ShirsInventoryDB.automaticHearthstoneItems) ~= "boolean" then
  error("malformed automatic Hearthstone setting was not repaired to the safe default")
end
ShirsInventoryDB.lockSelectedItemSlots = "malformed"
if ShirsInventory_GetLockSelectedItemSlots() or
  type(ShirsInventoryDB.lockSelectedItemSlots) ~= "boolean" then
  error("malformed selected-item slot locking was not repaired off")
end

print("ITEM_OVERRIDE_TEST=PASS")
