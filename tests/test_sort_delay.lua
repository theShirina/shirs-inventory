local corePath = arg[1]
assert(loadfile(corePath))()
assert(type(ShirsInventory_GetSortDelay) == "function", "sort delay API is missing")
assert(ShirsInventory_GetSortDelay() == 0.29, "release-candidate sort delay should be 0.29 seconds")
assert(type(ShirsInventory_GetSortAcknowledgementDelay) == "function",
  "sort acknowledgement pacing API is missing")
assert(ShirsInventory_GetSortAcknowledgementDelay() == 0.01,
  "acknowledged moves should be polled at most every 0.01 seconds")
assert(ShirsInventory_GetSortMovesPerUpdate() == 4,
  "disjoint sorting should retain its bounded four-move hard frame cap")
assert(type(ShirsInventory_GetSortBurstLimit) == "function", "sort burst pacing API is missing")
assert(ShirsInventory_GetSortBurstLimit(1) == 4 and
  ShirsInventory_GetSortBurstLimit(2) == 4 and
  ShirsInventory_GetSortBurstLimit(3) == 4 and
  ShirsInventory_GetSortBurstLimit(4) == 3 and
  ShirsInventory_GetSortBurstLimit(5) == 4 and
  ShirsInventory_GetSortBurstLimit(8) == 3,
  "sort burst pacing should repeat the 4/4/4/3 safety cycle")
assert(ShirsInventory_GetSortTimeout() == 15, "slower sorting needs a longer completion timeout")
print("SORT_DELAY_TEST=PASS")
