local uiPath = arg[1]
assert(loadfile(uiPath))()
assert(type(ShirsInventory_GetClampedTopLeft) == "function", "frame clamp helper is missing")

local left, top = ShirsInventory_GetClampedTopLeft(710, 458, 414, 457, 1280, 720, 8)
assert(left == 710 and top == 465, "frame bottom must be raised above the screen edge")
left, top = ShirsInventory_GetClampedTopLeft(710, 458, 414, 457, 1280, 720, 8, 70)
assert(left == 710 and top == 527, "frame bottom must stay above the action-bar bag controls")
left, top = ShirsInventory_GetClampedTopLeft(-20, 900, 414, 457, 1280, 720, 8)
assert(left == 8 and top == 712, "frame top and left must clamp to screen margins")
left, top = ShirsInventory_GetClampedTopLeft(1100, 500, 414, 457, 1280, 720, 8)
assert(left == 858 and top == 500, "frame right edge must clamp without changing valid height")

print("FRAME_CLAMP_TEST=PASS")
