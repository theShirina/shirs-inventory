local corePath = arg[1]
assert(loadfile(corePath))()
assert(type(ShirsInventory_GetSortDelay) == "function", "sort delay API is missing")
assert(ShirsInventory_GetSortDelay() == 0.29, "release-candidate sort delay should be 0.29 seconds")
assert(ShirsInventory_GetSortMovesPerUpdate() == 1,
  "cursor-safe sorting must allow only one unacknowledged move")
assert(ShirsInventory_GetSortTimeout() == 15, "slower sorting needs a longer completion timeout")
print("SORT_DELAY_TEST=PASS")
