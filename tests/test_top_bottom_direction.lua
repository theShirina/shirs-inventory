local corePath = arg[1]
assert(loadfile(corePath))()

local top = ShirsInventory_SelectDenseSlotIndexes(8, 4, "top")
local bottom = ShirsInventory_SelectDenseSlotIndexes(8, 4, "bottom")

local function joined(values)
  return table.concat(values, ",")
end

if joined(top) ~= "1,2,3,4" then
  error("top occupied window is wrong: " .. joined(top))
end
if joined(bottom) ~= "5,6,7,8" then
  error("bottom occupied window is wrong: " .. joined(bottom))
end
if bottom[1] > bottom[2] or bottom[2] > bottom[3] or bottom[3] > bottom[4] then
  error("bottom destination reversed the sort sequence")
end

print("TOP_BOTTOM_DIRECTION_TEST=PASS")
