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

left, top = ShirsInventory_GetClampedTopLeft(900, 768, 124, 300, 1024, 768, 8, 70, 0, 0)
assert(left == 900 and top == 768,
  "inventory-specific right and top margins must allow the frame to reach those viewport edges")
left, top = ShirsInventory_GetClampedTopLeft(-20, 300, 124, 200, 1024, 768, 8, 70, 0, 0)
assert(left == 8 and top == 300,
  "relaxed right/top margins must preserve the left safety margin")

assert(type(ShirsInventory_GetFittedWindowScale) == "function",
  "scale-aware viewport fitting helper is missing")
local fitted = ShirsInventory_GetFittedWindowScale(828, 252, 1, 1024, 768, 8, 8)
assert(fitted == 1,
  "twenty columns at the maximum supported scale must fit a 1024-pixel viewport")
fitted = ShirsInventory_GetFittedWindowScale(828, 700, 1, 1024, 768, 8, 70)
assert(fitted < 1 and fitted > 0.65,
  "a tall window must reduce its effective scale enough to remain accessible")
fitted = ShirsInventory_GetFittedWindowScale(1016, 698, 1, 1024, 768, 8, 70, 0, 0)
assert(fitted == 1,
  "inventory-specific right/top margins must use the extra edge space when fitting")

left, top = ShirsInventory_GetClampedTopLeft(500, 700, 828, 252, 1024, 768, 8)
assert(left >= 8 and left + 828 <= 1016 and top <= 760 and top - 252 >= 8,
  "scale-aware dimensions did not keep the full window inside the viewport")

print("FRAME_CLAMP_TEST=PASS")
