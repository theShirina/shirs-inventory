local corePath, enginePath, sorterPath = arg[1], arg[2], arg[3]

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
local flipMetadata = false
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
  function frame:ClearLines() end
  function frame:NumLines() return 0 end
  function frame:SetBagItem() end
  function frame:SetInventoryItem() end
  function frame:RegisterEvent() end
  return frame
end

function CreateFrame(_, name)
  local frame = NewFrame(name)
  if name then getfenv(0)[name] = frame end
  return frame
end
function GetAuctionItemClasses()
  return "Weapon", "Armor", "Container", "Consumable", "Trade Goods", "Projectile", "Quiver", "Recipe", "Reagent", "Miscellaneous"
end
function GetAuctionItemSubClasses() return "One-Handed Swords" end
function GetAuctionInvTypes() return "One-Hand" end
function GetContainerNumSlots(container)
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
  if itemID == 400 then
    return "Gray Junk", "link", 0, 1, "Miscellaneous", "Junk", 1, "", "texture"
  end
  if itemID == 500 then
    return "Marked Junk", "link", 2, 1, "Miscellaneous", "Junk", 1, "", "texture"
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
function GetBagName() return nil end
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
assert(loadfile(sorterPath))()
assert(type(runnerUpdate) == "function", "runtime update handler was not captured")
assert(ShirsInventory_ExtractLocalizedCount("12 Charges", "%d Charges") == 12,
  "plain localized charge count was not parsed")
assert(ShirsInventory_ExtractLocalizedCount("12 Charges", "%1$d Charges") == 12,
  "positional localized charge count was not parsed")
assert(ShirsInventory_ExtractLocalizedCount("12 Charge(s)", "%d Charge(s)") == 12,
  "literal punctuation in localized charge text was not parsed")
assert(ShirsInventory_GetSpecialtyItemClass("Sharp Arrow", "Projectile", "Arrow", nil) == "arrow",
  "arrow subtype was not recognized")
assert(ShirsInventory_GetSpecialtyItemClass("Heavy Shot", "Projectile", "Bullet", nil) == "bullet",
  "bullet subtype was not recognized")
assert(ShirsInventory_GetSpecialtyItemClass("Soul Shard", "Reagent", "Reagent", nil) == "soul",
  "soul shard name was not recognized")
assert(ShirsInventory_GetSpecialtyItemClass("Dust", "Trade Goods", "Enchanting", "Enchanting") == "enchanting",
  "enchanting material was not recognized")
assert(ShirsInventory_GetSpecialtyItemClass("Peacebloom", "Trade Goods", "Herb", "Herbs") == "herb",
  "herb material was not recognized")
assert(ShirsInventory_GetSpecialtyBagClass("Ribbly's Quiver", "Quiver") == "arrow",
  "quiver metadata was not recognized")
assert(ShirsInventory_GetSpecialtyBagClass("Small Shot Pouch", "Ammo Pouch") == "bullet",
  "ammo pouch metadata was not recognized")
assert(ShirsInventory_GetSpecialtyBagClass("Felcloth Bag", "Soul Bag") == "soul",
  "soul bag subtype was not recognized")
assert(ShirsInventory_GetSpecialtyBagClass("Enchanted Mageweave Pouch", "Bag") == nil,
  "normal bag display name caused false specialty classification")

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

local ok, status = ShirsInventory_SortBags()
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
-- cursor transaction. Cursor-empty means the command was safely submitted;
-- it does not prove that the bag state has changed yet.
slotCount = 2
bags[0] = {
  { id = 200, count = 1 },
  { id = 100, count = 1 },
}
ShirsInventory_SetSortMode("itemType")
ShirsInventory_SetDirection("top")
local realMoveCursorItem = ShirsInventory_MoveCursorItem
local submittedMove
ShirsInventory_MoveCursorItem = function(srcContainer, srcSlot, dstContainer, dstSlot)
  submittedMove = {srcContainer, srcSlot, dstContainer, dstSlot}
  return true
end
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "delayed-acknowledgement sort did not start")
tickOnce()
assert(submittedMove and ShirsInventory_IsRunning(), "cursor transaction was not submitted")
tickOnce()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(ShirsInventory_IsRunning(), "unchanged first scan was misclassified as a cycle")
assert(diagnostics.moves == 0, "unacknowledged cursor transaction counted as progress")
local sourceSlot = bags[submittedMove[1]][submittedMove[2]]
bags[submittedMove[1]][submittedMove[2]] = bags[submittedMove[3]][submittedMove[4]]
bags[submittedMove[3]][submittedMove[4]] = sourceSlot
tickOnce()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(not ShirsInventory_IsRunning() and diagnostics.reason == "complete", "delayed move was not acknowledged")
assert(diagnostics.moves == 1, "confirmed delayed move was not counted once")
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
