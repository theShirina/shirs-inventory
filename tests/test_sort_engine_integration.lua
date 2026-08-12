local corePath, enginePath, specialtyPath, sorterPath = arg[1], arg[2], arg[3], arg[4]

BANK_CONTAINER = -1
UIParent = {}
ShirsInventoryDB = {
  direction = "top",
  sortMode = "itemType",
  setupComplete = true,
  features = { bagUI = false, sorter = true, junk = false },
}

local now = 10
local cursorItem = nil
local runnerUpdate
local slotCount = 5
local slotCounts = {}
local flipMetadata = false
local tooltipLines = {}
local bags = {
  [0] = {
    { id = 200, count = 10 },
    { id = 100, count = 5 },
    { id = 100, count = 20 },
    nil,
    nil,
  },
}

local function NewFrame(name)
  local frame = { visible = false }
  function frame:Hide() self.visible = false end
  function frame:Show() self.visible = true end
  function frame:IsShown() return self.visible end
  function frame:IsVisible() return self.visible end
  function frame:SetScript(scriptName, handler)
    if name == "ShirsInventorySortRunner" and scriptName == "OnUpdate" then runnerUpdate = handler end
  end
  function frame:SetOwner() end
  function frame:ClearLines() tooltipLines = {} end
  function frame:NumLines() return table.getn(tooltipLines) end
  function frame:SetBagItem(container, position)
    tooltipLines = {}
    local value = bags[container] and bags[container][position]
    if value and value.id == 600 then
      tooltipLines[1] = "Use: Summons your companion pet."
    end
    local line
    for line = 1, table.getn(tooltipLines) do
      local text = tooltipLines[line]
      getfenv(0)["ShirsInventorySortTooltipTextLeft" .. line] = {
        GetText = function() return text end,
      }
    end
  end
  function frame:SetInventoryItem() end
  function frame:RegisterEvent() end
  return frame
end

function CreateFrame(_, name)
  local frame = NewFrame(name)
  if name then getfenv(0)[name] = frame end
  return frame
end
function getglobal(name) return getfenv(0)[name] end
function GetAuctionItemClasses()
  return "Weapon", "Armor", "Container", "Consumable", "Trade Goods", "Projectile", "Quiver", "Recipe", "Reagent", "Miscellaneous"
end
function GetAuctionItemSubClasses() return "One-Handed Swords" end
function GetAuctionInvTypes() return "One-Hand" end
function GetContainerNumSlots(container)
  if slotCounts[container] then return slotCounts[container] end
  if container == 0 then return slotCount end
  return 0
end
function GetContainerItemInfo(container, position)
  local value = bags[container] and bags[container][position]
  if not value then return nil, 0, false end
  return "texture", value.count, false
end
function GetContainerItemLink(container, position)
  local value = bags[container] and bags[container][position]
  if not value then return nil end
  return "|cffffffff|Hitem:" .. value.id .. ":0:0:0|h[item]|h|r"
end
function GetItemInfo(itemID)
  if type(itemID) ~= "number" then return nil end
  if itemID == 2447 then
    return "Peacebloom", "link", 1, 5, "Trade Goods", "Trade Goods", 20, "", "texture"
  end
  if itemID == 10940 then
    return "Strange Dust", "link", 1, 10, "Trade Goods", "Trade Goods", 20, "", "texture"
  end
  if itemID == 3371 then
    return "Empty Vial", "link", 1, 1, "Trade Goods", "Trade Goods", 20, "", "texture"
  end
  if itemID == 400 then
    return "Gray Junk", "link", 0, 1, "Miscellaneous", "Junk", 1, "", "texture"
  end
  if itemID == 500 then
    return "Marked Junk", "link", 2, 1, "Miscellaneous", "Junk", 1, "", "texture"
  end
  if itemID == 600 then
    return "Clockwork Friend", "link", 1, 1, "Miscellaneous", "Custom", 1, "", "texture"
  end
  if itemID == 299 or itemID == 300 then
    local quality
    if flipMetadata then
      quality = itemID == 299 and 2 or 1
    else
      quality = itemID == 299 and 1 or 2
    end
    return "Item " .. itemID, "link", quality, 1, 1, "Weapon", "One-Handed Swords", 1, "One-Hand"
  end
  if itemID == 2454 then
    -- This Vanilla/Microbot client exposes the nine-value 1.12 signature:
    -- name, link, rarity, level, type, subtype, maxStack, equipLoc, texture.
    return "Elixir of Lion's Strength", "link", 1, 1, "Consumable", "Consumable", 5, "", "texture"
  end
  if itemID >= 100 and itemID <= 300 then
    return "Item " .. itemID, "link", 1, 1, 1, "Weapon", "One-Handed Swords", 20, "One-Hand"
  end
  return nil
end
local equippedBagLink
function GetBagName(container)
  if container == 1 and equippedBagLink then
    if string.find(equippedBagLink, "22252", 1, true) then return "Satchel of Cenarius" end
    if string.find(equippedBagLink, "22249", 1, true) then return "Big Bag of Enchantment" end
    return "Ribbly's Quiver"
  end
  return nil
end
function ContainerIDToInventoryID(container) return 19 + container end
function GetInventoryItemLink(_, inventoryID)
  if inventoryID == 20 then return equippedBagLink end
  return nil
end
function CursorHasItem() return cursorItem ~= nil end
function ClearCursor() cursorItem = nil end
function UnitAffectingCombat() return false end
function GetTime() return now end
function PickupContainerItem(container, position)
  local current = bags[container][position]
  if not cursorItem then
    if current then
      cursorItem = current
      bags[container][position] = nil
    end
    return
  end
  if not current then
    bags[container][position] = cursorItem
    cursorItem = nil
  elseif current.id == cursorItem.id and current.count < (current.id == 2454 and 5 or 20) then
    local room = (current.id == 2454 and 5 or 20) - current.count
    local moved = math.min(room, cursorItem.count)
    current.count = current.count + moved
    cursorItem.count = cursorItem.count - moved
    if cursorItem.count == 0 then cursorItem = nil end
  else
    bags[container][position] = cursorItem
    cursorItem = current
    flipMetadata = not flipMetadata
  end
end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
BankFrame = NewFrame("BankFrame")

assert(loadfile(corePath))()
assert(loadfile(enginePath))()
assert(loadfile(specialtyPath))()
assert(loadfile(sorterPath))()
assert(type(runnerUpdate) == "function", "runtime update handler was not captured")
assert(ShirsInventory_ExtractLocalizedCount("12 Charges", "%d Charges") == 12,
  "plain localized charge count was not parsed")
assert(ShirsInventory_ExtractLocalizedCount("12 Charges", "%1$d Charges") == 12,
  "positional localized charge count was not parsed")
assert(ShirsInventory_ExtractLocalizedCount("12 Charge(s)", "%d Charge(s)") == 12,
  "literal punctuation in localized charge text was not parsed")
assert(ShirsInventory_GetSpecialtyItemClass(2512, "Sharp Arrow", "Projectile", "Arrow") == "arrow",
  "arrow subtype was not recognized")
assert(ShirsInventory_GetSpecialtyItemClass(2519, "Heavy Shot", "Projectile", "Bullet") == "bullet",
  "bullet subtype was not recognized")
assert(ShirsInventory_GetSpecialtyItemClass(6265, "Soul Shard", "Reagent", "Reagent") == "soul",
  "soul shard name was not recognized")
assert(ShirsInventory_GetSpecialtyItemClass(10940, "Strange Dust", "Trade Goods", "Trade Goods") == "enchanting",
  "BagFamily 7 enchanting material was not recognized from its item ID")
assert(ShirsInventory_GetSpecialtyItemClass(2447, "Peacebloom", "Trade Goods", "Trade Goods") == "herb",
  "BagFamily 6 herb was not recognized from its item ID")
assert(ShirsInventory_GetSpecialtyItemClass(5173, "Deathweed", "Trade Goods", "Trade Goods") == "herb",
  "Microbot cache-only herb was not recognized")
assert(ShirsInventory_GetSpecialtyItemClass(20725, "Nexus Crystal", "Trade Goods", "Trade Goods") == "enchanting",
  "Nexus Crystal was not recognized as an enchanting material")
assert(ShirsInventory_GetSpecialtyItemClass(3371, "Empty Vial", "Trade Goods", "Trade Goods") == nil,
  "an Alchemy reagent with BagFamily 0 was allowed into herb bags")
assert(ShirsInventory_GetSpecialtyItemClass(2840, "Copper Bar", "Trade Goods", "Trade Goods") == nil,
  "an Enchanting reagent with BagFamily 0 was allowed into enchanting bags")
assert(ShirsInventory_GetSpecialtyBagClass("Ribbly's Quiver", "Quiver") == "arrow",
  "quiver metadata was not recognized")
assert(ShirsInventory_GetSpecialtyBagClass("Small Shot Pouch", "Ammo Pouch") == "bullet",
  "ammo pouch metadata was not recognized")
assert(ShirsInventory_GetSpecialtyBagClass("Felcloth Bag", "Soul Bag") == "soul",
  "soul bag subtype was not recognized")
assert(ShirsInventory_GetSpecialtyBagClass("Enchanted Mageweave Pouch", "Bag") == nil,
  "normal bag display name caused false specialty classification")
assert(ShirsInventory_GetEdgeAnchorRank(6948) == 1, "Hearthstone edge rank is wrong")
local fieldItemIDs = {26061, 26063, 26064, 26065}
local fieldIndex
for fieldIndex = 1, table.getn(fieldItemIDs) do
  assert(ShirsInventory_GetEdgeAnchorRank(fieldItemIDs[fieldIndex]) == 2,
    "requested field item was not placed between Hearthstone and profession tools")
end
assert(ShirsInventory_IsPetOrMountItem("Miscellaneous", "Pet", nil),
  "standard pet subtype was not recognized")
assert(ShirsInventory_IsPetOrMountItem("Miscellaneous", "Companion Pet", nil),
  "custom companion-pet subtype was not recognized")
assert(ShirsInventory_IsPetOrMountItem("Miscellaneous", "Mount", nil),
  "mount subtype was not recognized")
assert(ShirsInventory_IsPetOrMountItem("Miscellaneous", "Custom", "Summon Tiny Dragon"),
  "Microbot custom summon spell was not recognized as a pet")
assert(ShirsInventory_IsPetOrMountTooltipText("Use: Summons and dismisses your companion."),
  "Microbot custom companion tooltip was not recognized")
assert(ShirsInventory_IsPetOrMountTooltipText("Use: Teaches you how to summon this mount."),
  "mount tooltip was not recognized")
assert(ShirsInventory_IsPetOrMountTooltipText("Use: Summons and dismisses a rideable Dire Wolf."),
  "classic rideable mount tooltip was not recognized")
assert(ShirsInventory_GetEdgeAnchorRank(
  5665, "Horn of the Dire Wolf", "Miscellaneous", "Junk", nil,
  ShirsInventory_IsPetOrMountTooltipText("Use: Summons and dismisses a rideable Dire Wolf.")
) == 3, "Horn of the Dire Wolf was not grouped near Hearthstone")
assert(not ShirsInventory_IsPetOrMountTooltipText("Use: Summons a temporary guardian."),
  "unrelated summon tooltip became a pet or mount")
assert(ShirsInventory_IsPetOrMountItem("Miscellaneous", "Custom", nil, true),
  "Microbot custom pet tooltip flag was ignored")
assert(not ShirsInventory_IsPetOrMountItem("Weapon", "Sword", "Summon Tiny Dragon", true),
  "non-miscellaneous summon item became a pet anchor")
assert(ShirsInventory_GetEdgeAnchorRank(90001, "Tiny Dragon", "Miscellaneous", "Custom", "Summon Tiny Dragon") == 3,
  "Microbot custom pet was not grouped directly with mounts")
assert(ShirsInventory_GetEdgeAnchorRank(90002, "Clockwork Friend", "Miscellaneous", "Custom", nil, true) == 3,
  "tooltip-only Microbot custom pet was not grouped directly with mounts")
assert(ShirsInventory_GetEdgeAnchorRank(6218) == 4, "Runed Copper Rod was not classified as a profession tool")
assert(ShirsInventory_GetEdgeAnchorRank(15846) == 4, "Salt Shaker was not classified as a profession tool")
assert(ShirsInventory_GetEdgeAnchorRank(9149) == 4, "Philosopher's Stone was not classified as a profession tool")
assert(ShirsInventory_GetEdgeAnchorRank(19727, "Blood Scythe", "Trade Goods", "Herb") == 4,
  "Blood Scythe was not classified as a profession tool")
assert(ShirsInventory_GetEdgeAnchorRank(19022, "Nat Pagle's Extreme Angler FC-5000", "Weapon", "Fishing Pole") == 4,
  "fishing-pole subtype was not classified as a profession tool")
assert(ShirsInventory_GetEdgeAnchorRank(3567, "Dwarven Fishing Pole", "Weapon", "Two-Handed Axes") == 4,
  "Microbot fishing-pole name fallback was not classified as a profession tool")
assert(ShirsInventory_GetEdgeAnchorRank(26471, "Apprentice Mining Pick", "Weapon", "Miscellaneous") == 4,
  "Microbot apprentice mining pick was not classified as a profession tool")
assert(ShirsInventory_GetEdgeAnchorRank(26474, "Artisan Mining Pick", "Weapon", "Miscellaneous") == 4,
  "Microbot artisan mining pick was not classified as a profession tool")
assert(ShirsInventory_GetAdjacencyGroup(26085) == "world-buff-scrolls" and
  ShirsInventory_GetAdjacencyGroup(26086) == "world-buff-scrolls" and
  ShirsInventory_GetAdjacencyGroup(26087) == "world-buff-scrolls" and
  ShirsInventory_GetAdjacencyGroup(26088) == "world-buff-scrolls",
  "world-buff scroll adjacency group is incomplete")
assert(ShirsInventory_GetAdjacencyGroup(26084) == nil,
  "unrelated item entered the world-buff scroll adjacency group")
assert(ShirsInventory_GetEdgeAnchorRank(2454, "Elixir of Lion's Strength", "Consumable", "Consumable") == nil,
  "ordinary item became an edge anchor")
assert(ShirsInventory_IsQuestBorderItem("Quest", 1),
  "common native Quest item was not matched to the visible quest border")
assert(not ShirsInventory_IsQuestBorderItem("Quest", 2),
  "uncommon Quest item with a rarity border was treated as quest-bordered")
assert(not ShirsInventory_IsQuestBorderItem("Weapon", 1),
  "tooltip-only or ordinary item was treated as quest-bordered")

equippedBagLink = "|cffffffff|Hitem:2101:0:0:0|h[Light Quiver]|h|r"
local originalGetItemInfo = GetItemInfo
GetItemInfo = function(query)
  -- Microbot does not resolve a colored hyperlink passed directly to
  -- GetItemInfo. The adapter must extract the item ID first.
  if query == 2101 then
    return "Light Quiver", equippedBagLink, 1, 1, "Quiver", "Quiver", 6, "INVTYPE_BAG", "texture"
  end
  return originalGetItemInfo(query)
end
assert(ShirsInventory_GetSpecialtyClassForContainer(1) == "arrow",
  "equipped quiver link was not used to reserve its slots for arrows")
GetItemInfo = originalGetItemInfo
equippedBagLink = nil

local function tickUntilDone()
  local tick
  for tick = 1, 100 do
    now = now + 0.35
    arg1 = 0.35
    runnerUpdate()
    if not ShirsInventory_IsRunning() then return tick end
  end
  error("sort did not finish within 100 moves")
end

local function tickOnce()
  now = now + 0.35
  arg1 = 0.35
  runnerUpdate()
end

-- Full movement regression with the exact generic item metadata exposed by
-- Microbot. Item IDs must carry specialty compatibility, just as Projectile
-- subtype carries arrow/quiver compatibility. A normal reagent must stay out.
slotCount = 3
slotCounts[1] = 2
bags[0] = {
  { id = 2447, count = 1 },
  { id = 3371, count = 1 },
  nil,
}
bags[1] = { nil, nil }
equippedBagLink = "|cffffffff|Hitem:22252:0:0:0|h[Satchel of Cenarius]|h|r"
GetItemInfo = function(query)
  if query == 22252 then
    return "Satchel of Cenarius", equippedBagLink, 2, 70, "Container", "Herb Bag", 1, "INVTYPE_BAG", "texture"
  end
  return originalGetItemInfo(query)
end
ShirsInventory_SetSortMode("itemType")
ShirsInventory_SetDirection("top")
local specialtyOk, specialtyStatus = ShirsInventory_SortBags()
assert(specialtyOk and specialtyStatus == "started", "herb-bag movement sort did not start")
tickUntilDone()
assert(bags[1][1] and bags[1][1].id == 2447,
  "Peacebloom with generic Trade Goods metadata did not move into the Herb Bag")
assert(not bags[1][2], "an incompatible item entered the second Herb Bag slot")
assert(bags[0][1] and bags[0][1].id == 3371,
  "Empty Vial did not remain in a normal bag")
assert(not cursorItem, "herb-bag movement left an item on the cursor")
GetItemInfo = originalGetItemInfo
equippedBagLink = nil
slotCounts[1] = nil
bags[1] = nil

-- Exercise the complete tooltip path: named tooltip text region -> TooltipFacts
-- -> ReadItem -> edge rank. Metadata alone is deliberately too weak here.
slotCount = 2
bags[0] = {
  { id = 100, count = 1 },
  { id = 600, count = 1 },
}
ShirsInventory_SetSortMode("itemType")
ShirsInventory_SetDirection("top")
local ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "tooltip-only pet sort did not start")
tickUntilDone()
assert(bags[0][1] and bags[0][1].id == 600 and bags[0][2] and bags[0][2].id == 100,
  "tooltip-only custom pet did not propagate into selected-edge placement")

-- Confirmed-move sorting must submit only one cursor transaction, then wait
-- until the exact result is visible in a fresh bag scan.
slotCount = 3
bags[0] = {
  { id = 103, count = 1 },
  { id = 101, count = 1 },
  { id = 102, count = 1 },
}
ShirsInventory_SetSortMode("itemType")
ShirsInventory_SetDirection("top")
local realBatchMoveCursorItem = ShirsInventory_MoveCursorItem
local batchSubmissions = 0
ShirsInventory_MoveCursorItem = function(srcContainer, srcSlot, dstContainer, dstSlot)
  batchSubmissions = batchSubmissions + 1
  return realBatchMoveCursorItem(srcContainer, srcSlot, dstContainer, dstSlot)
end
local ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "confirmed-move sort did not start")
tickOnce()
assert(batchSubmissions == 1, "runner submitted a second move before the first was acknowledged")
tickUntilDone()
assert(not cursorItem, "confirmed-move sort left an item on the cursor")
assert(bags[0][1] and bags[0][1].id == 101 and bags[0][2].id == 102 and bags[0][3].id == 103,
  "confirmed-move sort produced the wrong final order")
ShirsInventory_MoveCursorItem = realBatchMoveCursorItem

slotCount = 5
bags[0] = {
  { id = 200, count = 10 },
  { id = 100, count = 5 },
  { id = 100, count = 20 },
  nil,
  nil,
}
ShirsInventory_SetDirection("top")

ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "top sort did not start")
tickUntilDone()
assert(not cursorItem, "top sort left an item on the cursor")
assert(bags[0][1] and bags[0][1].id == 100 and bags[0][1].count == 20, "top slot 1 is wrong")
assert(bags[0][2] and bags[0][2].id == 100 and bags[0][2].count == 5, "top slot 2 is wrong")
assert(bags[0][3] and bags[0][3].id == 200 and bags[0][3].count == 10, "top slot 3 is wrong")
assert(not bags[0][4] and not bags[0][5], "top sort did not clear trailing slots")

bags[0] = {
  { id = 200, count = 10 },
  { id = 100, count = 5 },
  { id = 100, count = 20 },
  nil,
  nil,
}
ShirsInventory_SetDirection("bottom")
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "bottom sort did not start")
tickUntilDone()
assert(not cursorItem, "bottom sort left an item on the cursor")
assert(not bags[0][1] and not bags[0][2], "bottom sort did not clear leading slots")
assert(bags[0][3] and bags[0][3].id == 100 and bags[0][3].count == 20, "bottom slot 3 is wrong")
assert(bags[0][4] and bags[0][4].id == 100 and bags[0][4].count == 5, "bottom slot 4 is wrong")
assert(bags[0][5] and bags[0][5].id == 200 and bags[0][5].count == 10, "bottom slot 5 is wrong")


-- Live regression: two Elixir of Lion's Strength stacks (2 and 5) used to
-- oscillate because the nine-value GetItemInfo result was read as maxStack 1.
slotCount = 5
bags[0] = {
  { id = 2454, count = 2 },
  { id = 2454, count = 5 },
  nil,
  nil,
  nil,
}
ShirsInventory_SetDirection("top")
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "duplicate elixir sort did not start")
tickUntilDone()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(diagnostics.reason == "complete", "duplicate elixir stacks entered a cycle")
assert(bags[0][1] and bags[0][1].count == 5, "duplicate elixir full stack is wrong")
assert(bags[0][2] and bags[0][2].count == 2, "duplicate elixir remainder is wrong")

-- Ignore-junk sorting pins both automatic gray junk and manually marked junk
-- to their exact slots while sortable items pack around them.
slotCount = 5
bags[0] = {
  { id = 400, count = 1 },
  { id = 200, count = 1 },
  { id = 500, count = 1 },
  { id = 100, count = 1 },
  nil,
}
ShirsInventoryDB.junkItems = { [500] = true }
ShirsInventory_SetIgnoreJunkSorting(true)
ShirsInventory_SetSortMode("itemType")
ShirsInventory_SetDirection("top")
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "ignore-junk sort did not start")
tickUntilDone()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(diagnostics.reason == "complete", "ignore-junk sort did not complete")
assert(bags[0][1] and bags[0][1].id == 400, "gray junk moved while ignored")
assert(bags[0][2] and bags[0][2].id == 100, "sortable item did not pack around gray junk")
assert(bags[0][3] and bags[0][3].id == 500, "manually marked junk moved while ignored")
assert(bags[0][4] and bags[0][4].id == 200 and not bags[0][5], "sortable tail around ignored junk is wrong")

-- With the setting off, the same two junk items participate normally.
bags[0] = {
  { id = 400, count = 1 },
  { id = 200, count = 1 },
  { id = 500, count = 1 },
  { id = 100, count = 1 },
  nil,
}
ShirsInventory_SetIgnoreJunkSorting(false)
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "normal junk-inclusive sort did not start")
tickUntilDone()
assert(bags[0][1] and bags[0][1].id == 500, "marked junk did not rejoin normal sorting")
assert(bags[0][2] and bags[0][2].id == 100 and bags[0][3].id == 200, "normal item order changed")
assert(bags[0][4] and bags[0][4].id == 400 and not bags[0][5], "gray junk did not rejoin normal sorting")

-- A sort run owns one immutable target plan. If item metadata changes while
-- cursor moves are being acknowledged, rebuilding the plan can reverse the
-- desired order and return to a prior physical layout.
slotCount = 2
bags[0] = {
  { id = 299, count = 1 },
  { id = 300, count = 1 },
}
flipMetadata = false
ShirsInventory_SetSortMode("rarity")
ShirsInventory_SetDirection("top")
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "immutable-plan sort did not start")
tickUntilDone()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(diagnostics.reason == "complete", "metadata drift rebuilt the target plan and caused a cycle")
assert(bags[0][1] and bags[0][1].id == 300, "immutable rarity target changed during execution")
assert(bags[0][2] and bags[0][2].id == 299, "immutable rarity tail changed during execution")
flipMetadata = false

-- WoW may expose the old bag snapshot for one or more update ticks after a
-- cursor move. Never submit a second cursor transaction until the first move's
-- exact predicted state is visible. This models the live rarity-to-item-type
-- failure where only the first move landed before an optimistic burst desynced.
slotCount = 3
bags[0] = {
  { id = 103, count = 1 },
  { id = 101, count = 1 },
  { id = 102, count = 1 },
}
ShirsInventory_SetSortMode("itemType")
ShirsInventory_SetDirection("top")
local realMoveCursorItem = ShirsInventory_MoveCursorItem
local submittedMoves = {}
ShirsInventory_MoveCursorItem = function(srcContainer, srcSlot, dstContainer, dstSlot)
  table.insert(submittedMoves, {srcContainer, srcSlot, dstContainer, dstSlot})
  return true
end
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "delayed-burst sort did not start")
tickOnce()
assert(table.getn(submittedMoves) == 1 and ShirsInventory_IsRunning(),
  "runner did not submit exactly one cursor move")
tickOnce()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(ShirsInventory_IsRunning(), "unchanged move snapshot was misclassified as a cycle")
assert(diagnostics.moves == 0, "unacknowledged move counted as progress")
assert(table.getn(submittedMoves) == 1, "unchanged legacy bag snapshot caused a second move")
local submittedMove = submittedMoves[1]
local sourceSlot = bags[submittedMove[1]][submittedMove[2]]
local destinationSlot = bags[submittedMove[3]][submittedMove[4]]
bags[submittedMove[1]][submittedMove[2]] = nil
tickOnce()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(ShirsInventory_IsRunning() and diagnostics.moves == 0,
  "intermediate partial snapshot stopped or acknowledged the submitted move")
assert(table.getn(submittedMoves) == 1,
  "intermediate partial snapshot caused a second cursor transaction")
bags[submittedMove[1]][submittedMove[2]] = destinationSlot
bags[submittedMove[3]][submittedMove[4]] = sourceSlot
tickOnce()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(ShirsInventory_IsRunning(), "confirmed first move stopped the sort")
assert(diagnostics.moves == 1 and table.getn(submittedMoves) == 2,
  "confirmed first move did not unlock exactly one next move")
submittedMove = submittedMoves[2]
sourceSlot = bags[submittedMove[1]][submittedMove[2]]
bags[submittedMove[1]][submittedMove[2]] = bags[submittedMove[3]][submittedMove[4]]
bags[submittedMove[3]][submittedMove[4]] = sourceSlot
tickOnce()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(not ShirsInventory_IsRunning() and diagnostics.reason == "complete", "delayed moves were not acknowledged")
assert(diagnostics.moves == 2, "confirmed delayed move count is wrong")

-- A changed state that never becomes the exact predicted state must fail
-- closed after the grace period and must never submit another transaction.
slotCount = 3
bags[0] = {
  { id = 103, count = 1 },
  { id = 101, count = 1 },
  { id = 102, count = 1 },
}
submittedMoves = {}
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "persistent-wrong-state sort did not start")
tickOnce()
assert(table.getn(submittedMoves) == 1, "persistent-wrong-state setup did not submit one move")
submittedMove = submittedMoves[1]
bags[submittedMove[1]][submittedMove[2]] = nil
tickOnce()
local wrongTick
for wrongTick = 1, 7 do tickOnce() end
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(not ShirsInventory_IsRunning() and diagnostics.reason == "desync",
  "persistent wrong state did not stop with desync")
assert(table.getn(submittedMoves) == 1,
  "persistent wrong state caused a second cursor transaction")
ShirsInventory_MoveCursorItem = realMoveCursorItem

-- A large inventory can require more than 15 seconds at the safe 0.35-second
-- move cadence. Continuous confirmed progress must keep the run alive.
slotCount = 160
bags[0] = {}
local index
for index = 1, 80 do bags[0][index] = { id = 180 - index, count = 1 } end
ShirsInventory_SetDirection("bottom")
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "large sort did not start")
tickUntilDone()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(diagnostics.reason == "complete", "large progressing sort hit the safety timeout")
for index = 1, 80 do assert(not bags[0][index], "large bottom sort left an item before the target window") end
for index = 81, 160 do
  assert(bags[0][index] and bags[0][index].id == index + 19, "large bottom sort order is wrong at slot " .. index)
end

print("SORT_ENGINE_INTEGRATION_TEST=PASS")
