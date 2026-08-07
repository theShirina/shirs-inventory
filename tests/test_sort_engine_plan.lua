local enginePath = arg[1]
assert(loadfile(enginePath))()

local function item(key, count, maxStack, sortKey, class)
  return { key = key, count = count, maxStack = maxStack, sortKey = sortKey, class = class }
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

print("SORT_ENGINE_PLAN_TEST=PASS")
