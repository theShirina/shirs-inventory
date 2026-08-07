local corePath = arg[1]
assert(loadfile(corePath))()

if type(ShirsInventory_MoveCursorItem) ~= "function" then
  error("ShirsInventory_MoveCursorItem is missing")
end

local cursor = false
local occupied = { ["0:1"] = true, ["0:2"] = true }
local calls = {}

function CursorHasItem()
  return cursor
end

function ClearCursor()
  cursor = false
  table.insert(calls, "clear")
end

function PickupContainerItem(container, slot)
  local key = tostring(container) .. ":" .. tostring(slot)
  table.insert(calls, key)
  if not cursor then
    cursor = occupied[key] and true or false
    occupied[key] = false
  elseif occupied[key] then
    occupied[key] = true
    cursor = true
  else
    occupied[key] = true
    cursor = false
  end
end

if not ShirsInventory_MoveCursorItem(0, 1, 0, 2) then
  error("occupied-slot swap failed")
end
if cursor then
  error("occupied-slot swap left an item on the cursor")
end
if table.concat(calls, ",") ~= "0:1,0:2,0:1" then
  error("occupied-slot swap did not use source-destination-source: " .. table.concat(calls, ","))
end

calls = {}
cursor = true
if ShirsInventory_MoveCursorItem(0, 1, 0, 2) then
  error("sort started while cursor was already occupied")
end
if table.getn(calls) ~= 0 then
  error("busy-cursor guard touched a bag slot")
end

print("CURSOR_SAFETY_TEST=PASS")
