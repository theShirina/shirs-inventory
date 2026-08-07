local corePath = arg[1]
assert(loadfile(corePath))()
assert(type(ShirsInventory_GetSortDelay) == "function", "sort delay API is missing")
assert(ShirsInventory_GetSortDelay() == 0.35, "normal sort delay should be 0.35 seconds")
assert(ShirsInventory_GetSortTimeout() == 15, "slower sorting needs a longer completion timeout")
print("SORT_DELAY_TEST=PASS")
