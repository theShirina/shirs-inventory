local corePath, enginePath, specialtyPath, sorterPath = arg[1], arg[2], arg[3], arg[4]

-- Mode x direction matrix: each cell must produce a DIFFERENT, mode-sensitive
-- layout. The fixture uses a quality-1 consumable (Elixir, id 2454) and a
-- quality-3 weapon (id 200):
--   itemType mode: consumable rank 8 sorts before weapon rank 10 -> 2454 first
--   rarity mode:   quality 3 sorts before quality 1           -> 200 first
-- So a wrong mode (or a mode that degenerates to itemID order) fails every cell.

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
local slotCount = 4
local bags = {
  [0] = {
    { id = 200, count = 1 },
    { id = 2454, count = 4 },
    { id = 2454, count = 4 },
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
  if itemID == 6948 then
    return "Hearthstone", "link", 1, 1, "Miscellaneous", "Junk", 1, "", "texture"
  end
  if itemID == 2454 then
    -- Nine-value Vanilla/WoW signature: max stack is field 7.
    return "Elixir of Lion's Strength", "link", 1, 1, "Consumable", "Consumable", 5, "", "texture"
  end
  if itemID == 200 then
    return "Epic Blade", "link", 3, 1, "Weapon", "One-Handed Swords", 1, "One-Hand", "texture"
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
  elseif current.id == cursorItem.id and current.count < 5 then
    local room = 5 - current.count
    local moved = math.min(room, cursorItem.count)
    current.count = current.count + moved
    cursorItem.count = cursorItem.count - moved
    if cursorItem.count == 0 then cursorItem = nil end
  else
    bags[container][position] = cursorItem
    cursorItem = current
  end
end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
BankFrame = NewFrame("BankFrame")

assert(loadfile(corePath))()
assert(loadfile(enginePath))()
assert(loadfile(specialtyPath))()
assert(loadfile(sorterPath))()
assert(type(runnerUpdate) == "function", "runtime update handler was not captured")

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

local function resetBags()
  bags[0] = {
    { id = 200, count = 1 },
    { id = 2454, count = 4 },
    { id = 2454, count = 4 },
    nil,
  }
end

local function sortedIds()
  local ids = {}
  local index
  for index = 1, slotCount do
    ids[index] = bags[0][index] and bags[0][index].id or nil
  end
  return ids
end

local function expect(prefix, ids)
  local actual = sortedIds()
  local index
  for index = 1, slotCount do
    if actual[index] ~= ids[index] then
      error(prefix .. " slot " .. index .. " is wrong: got "
        .. tostring(actual[index]) .. " want " .. tostring(ids[index]))
    end
  end
end

-- Cell 1: itemType + top. Consumable (rank 8) leads; 2+3 elixir stacks merge to 5+0.
resetBags()
ShirsInventory_SetSortMode("itemType")
ShirsInventory_SetDirection("top")
local ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "itemType/top did not start")
tickUntilDone()
local diagnostics = ShirsInventory_GetSortDiagnostics()
assert(diagnostics.reason == "complete", "itemType/top did not complete: " .. diagnostics.reason)
assert(not cursorItem, "itemType/top left the cursor occupied")
expect("itemType/top", { 2454, 2454, 200, nil })

-- Cell 2: itemType + bottom. Same order, packed into the trailing window.
resetBags()
ShirsInventory_SetDirection("bottom")
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "itemType/bottom did not start")
tickUntilDone()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(diagnostics.reason == "complete", "itemType/bottom did not complete: " .. diagnostics.reason)
assert(not cursorItem, "itemType/bottom left the cursor occupied")
expect("itemType/bottom", { nil, 2454, 2454, 200 })

-- Cell 3: rarity + top. Quality 3 weapon leads, elixir stacks follow.
resetBags()
ShirsInventory_SetSortMode("rarity")
ShirsInventory_SetDirection("top")
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "rarity/top did not start")
tickUntilDone()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(diagnostics.reason == "complete", "rarity/top did not complete: " .. diagnostics.reason)
assert(not cursorItem, "rarity/top left the cursor occupied")
expect("rarity/top", { 200, 2454, 2454, nil })

-- Cell 4: rarity + bottom. Lowest rarity leads the trailing window so the
-- highest-rarity item lands at the bottom edge.
resetBags()
ShirsInventory_SetDirection("bottom")
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "rarity/bottom did not start")
tickUntilDone()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(diagnostics.reason == "complete", "rarity/bottom did not complete: " .. diagnostics.reason)
assert(not cursorItem, "rarity/bottom left the cursor occupied")
expect("rarity/bottom", { nil, 2454, 2454, 200 })

-- Hearthstone is an absolute edge anchor regardless of rarity. Top places it
-- in the first inventory slot; bottom places it in the last inventory slot.
slotCount = 5
bags[0] = {
  { id = 200, count = 1 },
  { id = 2454, count = 4 },
  { id = 2454, count = 4 },
  { id = 6948, count = 1 },
  nil,
}
ShirsInventory_SetDirection("top")
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "hearthstone/top did not start")
tickUntilDone()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(diagnostics.reason == "complete", "hearthstone/top did not complete: " .. diagnostics.reason)
expect("hearthstone/top", { 6948, 200, 2454, 2454, nil })

bags[0] = {
  { id = 200, count = 1 },
  { id = 2454, count = 4 },
  { id = 2454, count = 4 },
  { id = 6948, count = 1 },
  nil,
}
ShirsInventory_SetDirection("bottom")
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "hearthstone/bottom did not start")
tickUntilDone()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(diagnostics.reason == "complete", "hearthstone/bottom did not complete: " .. diagnostics.reason)
expect("hearthstone/bottom", { nil, 2454, 2454, 200, 6948 })

-- Re-run the first cell to prove the run leaves no cross-cell state behind.
slotCount = 4
resetBags()
ShirsInventory_SetSortMode("itemType")
ShirsInventory_SetDirection("top")
ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "itemType/top rerun did not start")
tickUntilDone()
diagnostics = ShirsInventory_GetSortDiagnostics()
assert(diagnostics.reason == "complete", "itemType/top rerun did not complete: " .. diagnostics.reason)
expect("itemType/top rerun", { 2454, 2454, 200, nil })

print("SORT_ENGINE_MODE_DIRECTION_MATRIX_TEST=PASS")
