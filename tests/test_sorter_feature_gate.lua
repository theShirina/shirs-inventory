local corePath, sorterPath = arg[1], arg[2]
ShirsInventoryDB = { setupComplete = true, features = { bagUI = false, sorter = false, junk = true } }
NUM_BANKBAGSLOTS = 6

local function NewFrame()
  local frame = { scripts = {} }
  function frame:Hide() end
  function frame:Show() end
  function frame:IsShown() return false end
  function frame:IsVisible() return self.visible and true or false end
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  return frame
end
function CreateFrame(_, name)
  local frame = NewFrame()
  if name then getfenv(0)[name] = frame end
  return frame
end
function GetAuctionItemClasses()
  return "Weapon", "Armor", "Container", "Consumable", "Trade Goods", "Projectile", "Quiver", "Recipe", "Reagent", "Miscellaneous"
end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
BankFrame = NewFrame()
function CursorHasItem() return false end
function GetCursorInfo() return nil end
function GetContainerNumSlots() return 0 end
function GetTime() return 0 end

assert(loadfile(corePath))()
assert(loadfile(sorterPath))()

assert(type(ShirsInventory_SortBags) == "function" and type(ShirsInventory_SortBank) == "function",
  "full-suite sorter entry points are missing")
assert(type(ShirsInventory_GetBagSortContainers) == "function", "normal bag sorter scope helper is missing")
local bagContainers = ShirsInventory_GetBagSortContainers()
local expectedBagContainers = {0, 1, 2, 3, 4}
assert(table.getn(bagContainers) == table.getn(expectedBagContainers),
  "normal bag sorting must exclude the Keyring")
local bagIndex
for bagIndex = 1, table.getn(expectedBagContainers) do
  assert(bagContainers[bagIndex] == expectedBagContainers[bagIndex],
    "normal bag sorting skipped, reordered, or added a container")
end
assert(ShirsInventory_IsFeatureEnabled("sorter"), "full-suite sorter is disabled")
assert(not ShirsInventory_SetFeatureEnabled("sorter", false),
  "obsolete feature API disabled the sorter")

ShirsInventory_SetCategoryMode(true)
local categoryStarted, categoryReason = ShirsInventory_SortBags()
assert(not categoryStarted and categoryReason == "category-mode",
  "category view must block physical bag sorting")
ShirsInventory_SetCategoryMode(false)

assert(type(ShirsInventory_GetBankSortContainers) == "function", "bank sorter scope is missing")
local bankContainers = ShirsInventory_GetBankSortContainers()
local expectedBankContainers = {-1, 5, 6, 7, 8, 9, 10}
assert(table.getn(bankContainers) == table.getn(expectedBankContainers),
  "bank sorting is not using the full bank scope")
local index
for index = 1, table.getn(expectedBankContainers) do
  assert(bankContainers[index] == expectedBankContainers[index],
    "bank sorting skipped or reordered a bank container")
end

BankFrame.visible = true
local started, reason = ShirsInventory_SortBank()
assert(started and reason == "started", "bank sorter did not start through the shared engine")
BankFrame.visible = false
arg1 = 1
ShirsInventorySortRunner.scripts.OnUpdate()
assert(ShirsInventory_GetSortDiagnostics().reason == "bank-closed",
  "bank sorting did not fail closed when access to the bank ended")

print("SORTER_FEATURE_GATE_TEST=PASS")
