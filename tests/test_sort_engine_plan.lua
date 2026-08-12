local enginePath = arg[1]
assert(loadfile(enginePath))()

local function item(key, count, maxStack, sortKey, class, edgeRank, oppositeEdge, adjacencyGroup)
  return {
    key = key,
    count = count,
    maxStack = maxStack,
    sortKey = sortKey,
    class = class,
    edgeAnchor = edgeRank and true or false,
    edgeRank = edgeRank,
    oppositeEdgeAnchor = oppositeEdge and true or false,
    oppositeEdgeRank = type(oppositeEdge) == "number" and oppositeEdge or (oppositeEdge and 1 or nil),
    adjacencyGroup = adjacencyGroup,
  }
end

local function slot(container, position, class, value)
  return { container = container, position = position, class = class, item = value }
end

local function target(plan, index)
  local value = plan[index]
  if not value or not value.key then return "empty" end
  return value.key .. ":" .. value.count
end

local source = {
  slot(0, 1, nil, item("B", 10, 20, {2, 1})),
  slot(0, 2, nil, item("A", 5, 20, {1, 1})),
  slot(1, 1, nil, item("A", 20, 20, {1, 1})),
  slot(1, 2, nil, nil),
  slot(1, 3, nil, nil),
}

local top = ShirsInventory_SortEnginePlan(source, "top")
assert(target(top, 1) == "A:20", "top slot 1 should hold the first full A stack")
assert(target(top, 2) == "A:5", "top slot 2 should hold the partial A stack")
assert(target(top, 3) == "B:10", "top slot 3 should hold B")
assert(target(top, 4) == "empty" and target(top, 5) == "empty", "top should leave trailing slots empty")

local tieBreakers = {
  slot(0, 1, nil, item("lexical-first", 1, 1, {
    mode = "itemType", category = 1, itemType = 1, itemSubType = 1,
    inventoryType = 1, rarity = -1, itemID = 1, charges = 1,
    suffixID = 2, enchantID = 0, uniqueID = 0,
  })),
  slot(0, 2, nil, item("lexical-last", 1, 1, {
    mode = "itemType", category = 1, itemType = 1, itemSubType = 1,
    inventoryType = 1, rarity = -1, itemID = 1, charges = 1,
    suffixID = 1, enchantID = 0, uniqueID = 0,
  })),
}
local tiePlan = ShirsInventory_SortEnginePlan(tieBreakers, "top")
assert(target(tiePlan, 1) == "lexical-last:1", "named suffix tie-breaker was ignored")

local bottom = ShirsInventory_SortEnginePlan(source, "bottom")
assert(target(bottom, 1) == "empty" and target(bottom, 2) == "empty", "bottom should leave leading slots empty")
assert(target(bottom, 3) == "A:20", "bottom must keep forward sort order")
assert(target(bottom, 4) == "A:5", "bottom partial stack order changed")
assert(target(bottom, 5) == "B:10", "bottom must end with B")

local specialty = {
  slot(0, 1, nil, item("stone", 3, 20, {3}, nil)),
  slot(2, 1, "herb", item("peacebloom", 7, 20, {1}, "herb")),
  slot(2, 2, "herb", nil),
  slot(3, 1, "ammo", item("arrow", 200, 200, {2}, "ammo")),
  slot(3, 2, "ammo", nil),
  slot(1, 1, nil, item("peacebloom", 20, 20, {1}, "herb")),
}
local planned = ShirsInventory_SortEnginePlan(specialty, "top")
assert(target(planned, 2) == "peacebloom:20" and target(planned, 3) == "peacebloom:7", "herbs were not packed into herb slots")
assert(target(planned, 4) == "arrow:200", "ammo was not kept in its specialty slot")
assert(target(planned, 5) == "empty", "ammo slot received an incompatible item")
assert(target(planned, 1) == "stone:3", "normal item did not remain available to normal slots")
assert(target(planned, 6) == "empty", "specialty items leaked into normal slots while specialty capacity remained")
local plannedBottom = ShirsInventory_SortEnginePlan(specialty, "bottom")
assert(target(plannedBottom, 4) == "arrow:200" and target(plannedBottom, 5) == "empty",
  "bottom sort moved arrows out of their specialty bag")
assert(target(plannedBottom, 6) == "stone:3" and target(plannedBottom, 1) == "empty",
  "bottom sort tried to place a normal item in a specialty bag")

-- Stackable copies can have different instance IDs while the client still
-- accepts them in one stack. The shared merge key must drive consolidation.
local duplicates = {
  slot(0, 1, nil, { key = "elixir-instance-1", mergeKey = "elixir", count = 3, maxStack = 5, sortKey = {1} }),
  slot(0, 2, nil, { key = "elixir-instance-2", mergeKey = "elixir", count = 4, maxStack = 5, sortKey = {1} }),
  slot(0, 3, nil, nil),
}
local merged = ShirsInventory_SortEnginePlan(duplicates, "top")
assert(target(merged, 1) == "elixir:5", "duplicate stackable instances did not merge into a full stack")
assert(target(merged, 2) == "elixir:2", "duplicate stackable remainder is wrong")
assert(target(merged, 3) == "empty", "duplicate stackables consumed an extra slot")

-- Ignored junk stays in its exact physical slot and does not participate in
-- stacking or ordering. Sortable items pack around those fixed obstacles.
local gray = item("gray-junk", 1, 1, {0})
gray.ignoreSort = true
local marked = item("marked-junk", 1, 1, {9})
marked.ignoreSort = true
local ignored = {
  slot(0, 1, nil, gray),
  slot(0, 2, nil, item("B", 1, 1, {2})),
  slot(0, 3, nil, marked),
  slot(0, 4, nil, item("A", 1, 1, {1})),
  slot(0, 5, nil, nil),
}
local ignoredTop = ShirsInventory_SortEnginePlan(ignored, "top")
assert(target(ignoredTop, 1) == "gray-junk:1", "top moved ignored gray junk")
assert(target(ignoredTop, 2) == "A:1", "top did not pack around ignored junk")
assert(target(ignoredTop, 3) == "marked-junk:1", "top moved manually marked junk")
assert(target(ignoredTop, 4) == "B:1" and target(ignoredTop, 5) == "empty", "top free-slot order is wrong")
local ignoredBottom = ShirsInventory_SortEnginePlan(ignored, "bottom")
assert(target(ignoredBottom, 1) == "gray-junk:1", "bottom moved ignored gray junk")
assert(target(ignoredBottom, 2) == "empty", "bottom did not leave the leading free slot empty")
assert(target(ignoredBottom, 3) == "marked-junk:1", "bottom moved manually marked junk")
assert(target(ignoredBottom, 4) == "A:1" and target(ignoredBottom, 5) == "B:1", "bottom free-slot order is wrong")

-- Edge ranks keep Onyxia Scale Cloak directly beside Hearthstone, followed by
-- field items, pets and mounts, and profession tools at either selected edge.
local edgeAnchors = {
  slot(0, 1, nil, item("ordinary", 1, 1, {1}, nil, nil)),
  slot(0, 2, nil, item("salt-shaker", 1, 1, {4}, nil, 4)),
  slot(0, 3, nil, item("hearthstone", 1, 1, {3}, nil, 1)),
  slot(0, 4, nil, item("runed-rod", 1, 1, {2}, nil, 4)),
  slot(0, 5, nil, item("field-item", 1, 1, {2.5}, nil, 2)),
  slot(0, 6, nil, item("custom-pet", 1, 1, {3.5}, nil, 3)),
  slot(0, 7, nil, item("custom-mount", 1, 1, {3}, nil, 3)),
  slot(0, 8, nil, item("onyxia-scale-cloak", 1, 1, {2.8}, nil, 1.5)),
  slot(0, 9, nil, nil),
}
local edgeTop = ShirsInventory_SortEnginePlan(edgeAnchors, "top")
assert(target(edgeTop, 1) == "hearthstone:1", "Top did not put Hearthstone first")
assert(target(edgeTop, 2) == "onyxia-scale-cloak:1", "Top did not put Onyxia Scale Cloak beside Hearthstone")
assert(target(edgeTop, 3) == "field-item:1", "Top did not place field items after Onyxia Scale Cloak")
assert(target(edgeTop, 4) == "custom-mount:1" and target(edgeTop, 5) == "custom-pet:1",
  "Top did not keep pets directly beside mounts")
assert(target(edgeTop, 6) == "runed-rod:1" and target(edgeTop, 7) == "salt-shaker:1",
  "Top did not place profession tools after pets and mounts")
assert(target(edgeTop, 8) == "ordinary:1" and target(edgeTop, 9) == "empty",
  "Top edge anchors displaced the normal window incorrectly")
local edgeBottom = ShirsInventory_SortEnginePlan(edgeAnchors, "bottom")
assert(target(edgeBottom, 1) == "empty" and target(edgeBottom, 2) == "ordinary:1",
  "Bottom did not preserve the leading empty slot and normal item")
assert(target(edgeBottom, 3) == "runed-rod:1" and target(edgeBottom, 4) == "salt-shaker:1",
  "Bottom did not put profession tools first inside the selected-edge block")
assert(target(edgeBottom, 5) == "custom-mount:1" and target(edgeBottom, 6) == "custom-pet:1",
  "Bottom did not keep pets directly beside mounts")
assert(target(edgeBottom, 7) == "field-item:1",
  "Bottom did not keep field items between pets and Onyxia Scale Cloak")
assert(target(edgeBottom, 8) == "onyxia-scale-cloak:1",
  "Bottom did not put Onyxia Scale Cloak beside Hearthstone")
assert(target(edgeBottom, 9) == "hearthstone:1", "Bottom did not put Hearthstone last")

-- Quest items occupy the inner opposite-edge group and conjured items the
-- outer group. Top reads quest then conjured; Bottom reads conjured then quest.
local oppositeAnchors = {
  slot(0, 1, nil, item("ordinary-B", 1, 1, {2}, nil, nil, false)),
  slot(0, 2, nil, item("quest-D", 1, 1, {4}, nil, nil, 1)),
  slot(0, 3, nil, item("hearthstone", 1, 1, {0}, nil, 1, false)),
  slot(0, 4, nil, item("ordinary-A", 1, 1, {1}, nil, nil, false)),
  slot(0, 5, nil, item("quest-C", 1, 1, {3}, nil, nil, 1)),
  slot(0, 6, nil, item("profession-tool", 1, 1, {5}, nil, 4, false)),
  slot(0, 7, nil, item("conjured-E", 1, 1, {6}, nil, nil, 2)),
  slot(0, 8, nil, nil),
}
local oppositeTop = ShirsInventory_SortEnginePlan(oppositeAnchors, "top")
assert(target(oppositeTop, 1) == "hearthstone:1" and target(oppositeTop, 2) == "profession-tool:1",
  "Top selected-edge anchors moved away from the top")
assert(target(oppositeTop, 3) == "ordinary-A:1" and target(oppositeTop, 4) == "ordinary-B:1" and
  target(oppositeTop, 5) == "quest-C:1" and target(oppositeTop, 6) == "quest-D:1" and
  target(oppositeTop, 7) == "conjured-E:1",
  "Top did not place conjured items after quest-outlined items")
assert(target(oppositeTop, 8) == "empty",
  "Top placed empty slots inside the occupied sorted block")
local oppositeBottom = ShirsInventory_SortEnginePlan(oppositeAnchors, "bottom")
assert(target(oppositeBottom, 1) == "empty",
  "Bottom placed opposite-edge groups at the physical top instead of bottom-aligning the sorted block")
assert(target(oppositeBottom, 2) == "conjured-E:1" and
  target(oppositeBottom, 3) == "quest-C:1" and target(oppositeBottom, 4) == "quest-D:1",
  "Bottom did not place conjured items before quest-outlined items")
assert(target(oppositeBottom, 5) == "ordinary-A:1" and target(oppositeBottom, 6) == "ordinary-B:1",
  "Bottom did not place ordinary items directly after quest items")
assert(target(oppositeBottom, 7) == "profession-tool:1" and target(oppositeBottom, 8) == "hearthstone:1",
  "Bottom selected-edge anchors moved away from the bottom")

-- All four world-buff scrolls remain contiguous even when rarity or item-type
-- keys would interleave ordinary items. Two 26085 stacks also prove that stack
-- consolidation does not break the group.
local groupedScrolls = {
  slot(0, 1, nil, item("ordinary-epic", 1, 1,
    { mode = "rarity", rarity = -4, category = 10, itemType = 2, itemID = 1 })),
  slot(0, 2, nil, item("scroll-26085", 2, 5,
    { mode = "rarity", rarity = -3, category = 8, itemType = 4, itemID = 26085 }, nil, nil, nil, "world-buff-scrolls")),
  slot(0, 3, nil, item("ordinary-uncommon", 1, 1,
    { mode = "rarity", rarity = -2, category = 10, itemType = 2, itemID = 2 })),
  slot(0, 4, nil, item("scroll-26086", 1, 1,
    { mode = "rarity", rarity = -1.8, category = 8, itemType = 4, itemID = 26086 }, nil, nil, nil, "world-buff-scrolls")),
  slot(0, 5, nil, item("scroll-26087", 1, 1,
    { mode = "rarity", rarity = -1.6, category = 8, itemType = 4, itemID = 26087 }, nil, nil, nil, "world-buff-scrolls")),
  slot(0, 6, nil, item("ordinary-common", 1, 1,
    { mode = "rarity", rarity = -1, category = 10, itemType = 2, itemID = 3 })),
  slot(0, 7, nil, item("scroll-26088", 1, 1,
    { mode = "rarity", rarity = 0, category = 8, itemType = 4, itemID = 26088 }, nil, nil, nil, "world-buff-scrolls")),
  slot(0, 8, nil, item("scroll-26085", 3, 5,
    { mode = "rarity", rarity = -3, category = 8, itemType = 4, itemID = 26085 }, nil, nil, nil, "world-buff-scrolls")),
  slot(0, 9, nil, nil),
}

local function assertGroupedPlan(plan, first, label)
  assert(target(plan, first) == "ordinary-epic:1" and
    target(plan, first + 1) == "scroll-26085:5" and
    target(plan, first + 2) == "scroll-26086:1" and
    target(plan, first + 3) == "scroll-26087:1" and
    target(plan, first + 4) == "scroll-26088:1" and
    target(plan, first + 5) == "ordinary-uncommon:1" and
    target(plan, first + 6) == "ordinary-common:1",
    label .. " split or reordered the complete world-buff scroll group")
end

local function assertIdempotentPlan(sourceSlots, plan, direction, label)
  local prototypes = {}
  local index
  for index = 1, table.getn(sourceSlots) do
    local value = sourceSlots[index].item
    if value then prototypes[value.key] = value end
  end
  local plannedSlots = {}
  for index = 1, table.getn(sourceSlots) do
    local planned = plan[index]
    local prototype = planned and prototypes[planned.key]
    local value
    if planned and prototype then
      value = item(prototype.key, planned.count, prototype.maxStack, prototype.sortKey,
        prototype.class, prototype.edgeRank, prototype.oppositeEdgeRank, prototype.adjacencyGroup)
    end
    plannedSlots[index] = slot(0, index, nil, value)
  end
  local replanned = ShirsInventory_SortEnginePlan(plannedSlots, direction)
  for index = 1, table.getn(sourceSlots) do
    assert(target(replanned, index) == target(plan, index), label .. " was not idempotent at slot " .. index)
  end
end

local groupedRarityTop = ShirsInventory_SortEnginePlan(groupedScrolls, "top")
assertGroupedPlan(groupedRarityTop, 1, "rarity Top")
assert(target(groupedRarityTop, 8) == "empty" and target(groupedRarityTop, 9) == "empty",
  "rarity Top did not leave trailing slots empty")
local groupedRarityBottom = ShirsInventory_SortEnginePlan(groupedScrolls, "bottom")
assert(target(groupedRarityBottom, 1) == "empty" and target(groupedRarityBottom, 2) == "empty",
  "rarity Bottom did not align the occupied block to the bottom")
assertGroupedPlan(groupedRarityBottom, 3, "rarity Bottom")
assertIdempotentPlan(groupedScrolls, groupedRarityBottom, "bottom", "rarity Bottom")

local itemTypeCategories = {1, 2, 3, 4, 6, 5, 8, 2}
local groupedItemIDs = {
  ["scroll-26085"] = 26085,
  ["scroll-26086"] = 26086,
  ["scroll-26087"] = 26087,
  ["scroll-26088"] = 26088,
}
local groupedIndex
for groupedIndex = 1, 8 do
  local value = groupedScrolls[groupedIndex].item
  value.sortKey = {
    mode = "itemType",
    category = itemTypeCategories[groupedIndex],
    itemType = value.adjacencyGroup and 4 or 2,
    rarity = value.sortKey.rarity,
    itemID = groupedItemIDs[value.key] or groupedIndex,
  }
end
local groupedItemTypeTop = ShirsInventory_SortEnginePlan(groupedScrolls, "top")
assertGroupedPlan(groupedItemTypeTop, 1, "item-type Top")
local groupedItemTypeBottom = ShirsInventory_SortEnginePlan(groupedScrolls, "bottom")
assert(target(groupedItemTypeBottom, 1) == "empty" and target(groupedItemTypeBottom, 2) == "empty",
  "item-type Bottom did not align the occupied block to the bottom")
assertGroupedPlan(groupedItemTypeBottom, 3, "item-type Bottom")
assertIdempotentPlan(groupedScrolls, groupedItemTypeBottom, "bottom", "item-type Bottom")

print("SORT_ENGINE_PLAN_TEST=PASS")
