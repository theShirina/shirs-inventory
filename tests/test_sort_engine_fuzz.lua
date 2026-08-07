local enginePath = arg[1]
assert(loadfile(enginePath))()
math.randomseed(41723)

local function cloneItem(value)
  if not value then return nil end
  return {
    key = value.key,
    count = value.count,
    maxStack = value.maxStack,
    sortKey = value.sortKey,
    class = value.class,
  }
end

local function complete(slots, targets)
  local index
  for index = 1, table.getn(slots) do
    local item = slots[index].item
    local target = targets[index]
    if target then
      if not item or item.key ~= target.key or item.count ~= target.count then return false end
    elseif item then
      return false
    end
  end
  return true
end

local function applyMove(slots, move)
  local source = slots[move.source]
  local destination = slots[move.destination]
  local moving = source.item
  local existing = destination.item
  assert(moving, "planner selected an empty source")
  if not existing then
    destination.item = moving
    source.item = nil
  elseif existing.key == moving.key then
    local room = existing.maxStack - existing.count
    local amount = math.min(room, moving.count)
    existing.count = existing.count + amount
    moving.count = moving.count - amount
    if moving.count == 0 then source.item = nil end
  else
    destination.item = moving
    source.item = existing
  end
end

local keys = {"A", "B", "C", "D"}
local caseCount = tonumber(arg[4]) or 250
local caseNumber
for caseNumber = 1, caseCount do
  local slots = {}
  local slotCount = math.random(5, 12)
  local index
  for index = 1, slotCount do slots[index] = { class = nil, item = nil, locked = false } end

  local occupied = math.random(1, slotCount - 1)
  for index = 1, occupied do
    local keyIndex = math.random(1, table.getn(keys))
    slots[index].item = {
      key = keys[keyIndex],
      count = math.random(1, 5),
      maxStack = 5,
      sortKey = {keyIndex},
      class = nil,
    }
  end

  -- Shuffle occupied and empty slots.
  for index = slotCount, 2, -1 do
    local other = math.random(1, index)
    slots[index].item, slots[other].item = slots[other].item, slots[index].item
  end

  local direction = math.mod(caseNumber, 2) == 0 and "bottom" or "top"
  local targets = ShirsInventory_SortEnginePlan(slots, direction)
  local step
  for step = 1, 200 do
    if complete(slots, targets) then break end
    local move = ShirsInventory_SortEngineChooseMove(slots, targets)
    assert(move, "case " .. caseNumber .. " deadlocked at step " .. step)
    applyMove(slots, move)
  end
  assert(complete(slots, targets), "case " .. caseNumber .. " did not converge")
end

print("SORT_ENGINE_FUZZ_TEST=PASS")
