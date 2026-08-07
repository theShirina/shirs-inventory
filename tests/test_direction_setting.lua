local corePath = arg[1]
assert(loadfile(corePath))()

ShirsInventoryDB = nil
if type(ShirsInventory_GetDirection) ~= "function" then
  error("ShirsInventory_GetDirection is missing")
end
if type(ShirsInventory_SetDirection) ~= "function" then
  error("ShirsInventory_SetDirection is missing")
end
if type(ShirsInventory_ToggleDirection) ~= "function" then
  error("ShirsInventory_ToggleDirection is missing")
end

if ShirsInventory_GetDirection() ~= "bottom" then
  error("default direction must be bottom")
end
if ShirsInventory_SetDirection("top") ~= true or ShirsInventory_GetDirection() ~= "top" then
  error("top direction was not persisted")
end
if ShirsInventory_ToggleDirection() ~= "bottom" or ShirsInventory_GetDirection() ~= "bottom" then
  error("toggle did not change top to bottom")
end
if ShirsInventory_SetDirection("sideways") ~= false then
  error("invalid direction must be rejected")
end
if ShirsInventory_GetDirection() ~= "bottom" then
  error("invalid direction changed saved state")
end

print("DIRECTION_SETTING_TEST=PASS")
