local corePath = arg[1]
assert(loadfile(corePath))()

if ShirsInventory_PlanRarityGroupSlots ~= nil then
  error("rarity mode still contains a per-bag boundary planner")
end

-- Shirbank has 71 occupied stack slots across five 16-slot containers.
-- Bottom must select one continuous trailing window without reversing it.
local occupied = ShirsInventory_SelectDenseSlotIndexes(80, 71, "bottom")
if table.getn(occupied) ~= 71 or occupied[1] ~= 10 or occupied[71] ~= 80 then
  error("whole-inventory Bottom window is wrong")
end

-- The real quality counts are 15 rare, 14 uncommon, and 42 common stacks.
-- Their transitions may occur inside a physical bag; no gaps or restarts.
local qualities = {}
local index
for index = 1, 15 do table.insert(qualities, 3) end
for index = 1, 14 do table.insert(qualities, 2) end
for index = 1, 42 do table.insert(qualities, 1) end

local qualityAtSlot = {}
for index = 1, table.getn(occupied) do
  qualityAtSlot[occupied[index]] = qualities[index]
end

if qualityAtSlot[10] ~= 3 or qualityAtSlot[24] ~= 3 then
  error("rare sequence is not first in the continuous inventory")
end
if qualityAtSlot[25] ~= 2 or qualityAtSlot[38] ~= 2 then
  error("uncommon sequence does not immediately follow rares")
end
if qualityAtSlot[39] ~= 1 or qualityAtSlot[80] ~= 1 then
  error("common sequence does not immediately follow uncommons")
end
if occupied[16 - 10 + 1] ~= 16 or occupied[16 - 10 + 2] ~= 17 then
  error("continuous sequence did not cross a bag boundary")
end

print("WHOLE_INVENTORY_SORT_TEST=PASS")
