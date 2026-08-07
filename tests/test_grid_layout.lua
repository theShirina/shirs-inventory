local corePath = arg[1]
assert(loadfile(corePath))()

local layout = ShirsInventory_GetGridLayout(80, 10)
assert(layout.columns == 10 and layout.rows == 8, "80 slots should use a 10 by 8 grid")
assert(layout.width == 428 and layout.height == 412, "80-slot frame should have stable dimensions")

layout = ShirsInventory_GetGridLayout(23, 10)
assert(layout.columns == 10 and layout.rows == 3, "partial final row should round up")
assert(layout.width == 428 and layout.height == 212, "height should grow by complete rows")

layout = ShirsInventory_GetGridLayout(4, 10)
assert(layout.columns == 4 and layout.rows == 1, "small inventories should not leave fake columns")
assert(layout.width == 188 and layout.height == 132, "small frame should shrink to used columns")

print("GRID_LAYOUT_TEST=PASS")
