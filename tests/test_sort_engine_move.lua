local enginePath = arg[1]
assert(loadfile(enginePath))()

local function item(key, count, class)
  return { key = key, count = count, maxStack = 20, sortKey = {string.byte(key)}, class = class }
end

local function slot(class, value, locked)
  return { class = class, item = value, locked = locked and true or false }
end

local slots = {
  slot(nil, item("B", 1)),
  slot(nil, item("A", 1)),
}
local targets = {
  { key = "A", count = 1 },
  { key = "B", count = 1 },
}
local move = ShirsInventory_SortEngineChooseMove(slots, targets)
assert(move and move.source == 2 and move.destination == 1 and move.reason == "target", "simple swap move was not selected")
assert(type(ShirsInventory_SortEngineApplyMove) == "function", "optimistic move model is missing")
assert(ShirsInventory_SortEngineApplyMove(slots, move), "optimistic swap was rejected")
assert(slots[1].item and slots[1].item.key == "A" and slots[2].item and slots[2].item.key == "B",
  "optimistic swap produced the wrong model")

local mergeSlots = {
  slot(nil, item("A", 10)),
  slot(nil, item("A", 15)),
}
assert(ShirsInventory_SortEngineApplyMove(mergeSlots, { source = 1, destination = 2 }),
  "optimistic stack merge was rejected")
assert(mergeSlots[1].item and mergeSlots[1].item.count == 5,
  "optimistic partial merge lost the source remainder")
assert(mergeSlots[2].item and mergeSlots[2].item.count == 20,
  "optimistic partial merge did not fill the destination")

slots = {
  slot(nil, item("B", 1)),
  slot(nil, item("A", 1)),
}

slots[2].locked = true
assert(ShirsInventory_SortEngineChooseMove(slots, targets) == nil, "locked source was selected")
slots[2].locked = false
slots[1].locked = true
assert(ShirsInventory_SortEngineChooseMove(slots, targets) == nil, "locked destination was selected")

-- A herb source cannot receive the stone displaced from a normal destination.
-- The engine must first move that stone into a compatible empty normal buffer.
local blocked = {
  slot(nil, item("stone", 1, nil)),
  slot("herb", item("herb", 1, "herb")),
  slot(nil, nil),
}
local blockedTargets = {
  { key = "herb", count = 1 },
  nil,
  { key = "stone", count = 1 },
}
move = ShirsInventory_SortEngineChooseMove(blocked, blockedTargets)
assert(move and move.source == 1 and move.destination == 3, "specialty deadlock did not use the normal buffer")

local done = {
  slot(nil, item("A", 20)),
  slot(nil, item("B", 1)),
}
assert(ShirsInventory_SortEngineChooseMove(done, targets) == nil, "completed layout still produced a move")

-- An overfilled same-key target supplies another deficit; it must never receive
-- another stack merely because an earlier deficit is temporarily locked.
local overfilledSlots = {
  { class = nil, locked = true, item = nil },
  { class = nil, locked = false, item = item("A", 3, nil) },
  { class = nil, locked = false, item = item("A", 1, nil) },
}
local overfilledTargets = {
  { key = "A", count = 3, class = nil },
  { key = "A", count = 1, class = nil },
  nil,
}
local overfilledMove = ShirsInventory_SortEngineChooseMove(overfilledSlots, overfilledTargets)
assert(not overfilledMove or overfilledMove.destination ~= 2, "engine tried to add to an overfilled same-key target")

print("SORT_ENGINE_MOVE_TEST=PASS")
