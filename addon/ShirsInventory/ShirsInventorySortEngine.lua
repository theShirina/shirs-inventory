-- Shir's Inventory deterministic sort planner
-- Original implementation for Lua 5.0.3. This module contains no WoW API calls.

local itemTypeFields = {"category", "itemType", "itemSubType", "inventoryType", "rarity", "itemID", "charges", "suffixID", "enchantID", "uniqueID"}
local rarityFields = {"rarity", "category", "itemType", "itemSubType", "inventoryType", "itemID", "charges", "suffixID", "enchantID", "uniqueID"}

local function CompareValues(left, right)
  if left == right then return 0 end
  if left == nil then return -1 end
  if right == nil then return 1 end
  if left < right then return -1 end
  return 1
end

local function CompareKeys(left, right)
  local fields
  if left.mode or right.mode then
    fields = left.mode == "rarity" and rarityFields or itemTypeFields
  end
  local count = fields and table.getn(fields) or math.max(table.getn(left), table.getn(right))
  local position
  for position = 1, count do
    local field = fields and fields[position] or position
    local comparison = CompareValues(left[field], right[field])
    if comparison ~= 0 then return comparison end
  end
  return 0
end

local function ItemLess(left, right)
  local comparison = CompareKeys(left.sortKey, right.sortKey)
  if comparison ~= 0 then return comparison < 0 end
  return tostring(left.key) < tostring(right.key)
end

local function SlotAccepts(slot, item)
  if not item then return true end
  return slot.class == nil or slot.class == item.class
end

local function TargetMatches(item, target)
  if not target then return item == nil end
  return item ~= nil and item.key == target.key and item.count == target.count
end

local function TargetNeedsInput(item, target)
  if not target then return false end
  if not item or item.key ~= target.key then return true end
  return item.count < target.count
end

local function AssignTarget(plan, slotIndex, item, count)
  plan[slotIndex] = {
    key = item.key,
    count = count,
    class = item.class,
  }
end

function ShirsInventory_SortEnginePlan(slots, direction)
  local totals = {}
  local itemsByKey = {}
  local itemKeys = {}
  local plan = {}
  local slotIndex

  for slotIndex = 1, table.getn(slots) do
    local value = slots[slotIndex].item
    if value and value.ignoreSort then
      AssignTarget(plan, slotIndex, value, value.count)
    elseif value and value.key and value.count and value.count > 0 then
      local groupKey = value.mergeKey or value.key
      if not itemsByKey[groupKey] then
        itemsByKey[groupKey] = {
          key = groupKey,
          maxStack = math.max(tonumber(value.maxStack) or 1, 1),
          sortKey = value.sortKey or {},
          class = value.class,
          edgeAnchor = value.edgeAnchor and true or false,
          edgeRank = value.edgeRank,
          oppositeEdgeAnchor = value.oppositeEdgeAnchor and true or false,
        }
        table.insert(itemKeys, groupKey)
      end
      totals[groupKey] = (totals[groupKey] or 0) + value.count
    end
  end

  table.sort(itemKeys, function(leftKey, rightKey)
    return ItemLess(itemsByKey[leftKey], itemsByKey[rightKey])
  end)

  local edgeKeys = {}
  local oppositeEdgeKeys = {}
  local regularKeys = {}
  local orderedKeyIndex
  for orderedKeyIndex = 1, table.getn(itemKeys) do
    local orderedKey = itemKeys[orderedKeyIndex]
    if itemsByKey[orderedKey].edgeAnchor then
      table.insert(edgeKeys, orderedKey)
    elseif itemsByKey[orderedKey].oppositeEdgeAnchor then
      table.insert(oppositeEdgeKeys, orderedKey)
    else
      table.insert(regularKeys, orderedKey)
    end
  end

  table.sort(edgeKeys, function(leftKey, rightKey)
    local left = itemsByKey[leftKey]
    local right = itemsByKey[rightKey]
    local leftRank = left.edgeRank or 999
    local rightRank = right.edgeRank or 999
    if leftRank ~= rightRank then
      if direction == "bottom" then return leftRank > rightRank end
      return leftRank < rightRank
    end
    return ItemLess(left, right)
  end)

  local function assign(slotNumber, item)
    local remaining = totals[item.key] or 0
    if remaining <= 0 then return false end
    local count = math.min(remaining, item.maxStack)
    AssignTarget(plan, slotNumber, item, count)
    totals[item.key] = remaining - count
    return true
  end

  -- Specialty slots own compatible items before the shared normal-bag window.
  for slotIndex = 1, table.getn(slots) do
    local slot = slots[slotIndex]
    if slot.class ~= nil and not (slot.item and slot.item.ignoreSort) then
      local keyIndex
      for keyIndex = 1, table.getn(itemKeys) do
        local item = itemsByKey[itemKeys[keyIndex]]
        if item.class == slot.class and assign(slotIndex, item) then break end
      end
    end
  end

  local normalSlots = {}
  for slotIndex = 1, table.getn(slots) do
    if slots[slotIndex].class == nil and not (slots[slotIndex].item and slots[slotIndex].item.ignoreSort) then
      table.insert(normalSlots, slotIndex)
    end
  end

  local function countStacks(keys)
    local count = 0
    local keyIndex
    for keyIndex = 1, table.getn(keys) do
      local item = itemsByKey[keys[keyIndex]]
      local remaining = totals[item.key] or 0
      if remaining > 0 then count = count + math.ceil(remaining / item.maxStack) end
    end
    return count
  end

  local normalIndex = 1

  local function assignKeyList(keys)
    local listIndex
    for listIndex = 1, table.getn(keys) do
      local item = itemsByKey[keys[listIndex]]
      while (totals[item.key] or 0) > 0 and normalIndex <= table.getn(normalSlots) do
        assign(normalSlots[normalIndex], item)
        normalIndex = normalIndex + 1
      end
    end
  end

  if direction == "bottom" then
    normalIndex = table.getn(normalSlots) - countStacks(oppositeEdgeKeys) -
      countStacks(regularKeys) - countStacks(edgeKeys) + 1
    if normalIndex < 1 then normalIndex = 1 end
    assignKeyList(oppositeEdgeKeys)
    assignKeyList(regularKeys)
    assignKeyList(edgeKeys)
  else
    normalIndex = 1
    assignKeyList(edgeKeys)
    assignKeyList(regularKeys)
    assignKeyList(oppositeEdgeKeys)
  end

  return plan
end

local function SourceHasSurplus(slots, targets, sourceIndex, desiredKey)
  local item = slots[sourceIndex].item
  if not item or item.key ~= desiredKey then return false end
  local ownTarget = targets[sourceIndex]
  if ownTarget and ownTarget.key == desiredKey and item.count <= ownTarget.count then return false end
  return true
end

function ShirsInventory_SortEngineChooseMove(slots, targets)
  local destination
  for destination = 1, table.getn(slots) do
    local dstSlot = slots[destination]
    local target = targets[destination]
    if not dstSlot.locked and TargetNeedsInput(dstSlot.item, target) then
      local source
      for source = 1, table.getn(slots) do
        local srcSlot = slots[source]
        if source ~= destination and not srcSlot.locked and
          SourceHasSurplus(slots, targets, source, target.key) and
          SlotAccepts(srcSlot, dstSlot.item)
        then
          return { source = source, destination = destination, reason = "target" }
        end
      end
    end
  end

  -- A specialty source may be unable to accept the item displaced by a swap.
  -- Move that blocker to an empty compatible slot, then plan again next tick.
  for destination = 1, table.getn(slots) do
    local dstSlot = slots[destination]
    local target = targets[destination]
    if not dstSlot.locked and dstSlot.item and target and dstSlot.item.key ~= target.key then
      local source
      for source = 1, table.getn(slots) do
        local srcSlot = slots[source]
        if source ~= destination and not srcSlot.locked and
          SourceHasSurplus(slots, targets, source, target.key) and
          not SlotAccepts(srcSlot, dstSlot.item)
        then
          local buffer
          for buffer = 1, table.getn(slots) do
            local bufferSlot = slots[buffer]
            if buffer ~= destination and buffer ~= source and not bufferSlot.locked and
              not bufferSlot.item and SlotAccepts(bufferSlot, dstSlot.item)
            then
              return { source = destination, destination = buffer, reason = "buffer" }
            end
          end
        end
      end
    end
  end

  return nil
end
