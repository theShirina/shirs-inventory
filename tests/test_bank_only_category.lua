-- Bank-only category-mode option: category view may scope to the bank while
-- carried bags stay on the standard grid, and bank state never leaks into
-- sorting, selection, or the carried window's search.
local corePath, sorterPath, uiPath, settingsPath = arg[1], arg[2], arg[3], arg[4]
ShirsInventoryDB = {}
NUM_BANKBAGSLOTS = 6

local function NewFrame()
  local frame = { scripts = {} }
  function frame:Hide() end
  function frame:Show() end
  function frame:IsShown() return false end
  function frame:IsVisible() return self.visible and true or false end
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  function frame:RegisterEvent() end
  function frame:UnregisterEvent() end
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
ShirsInventoryFrame = NewFrame()
ShirsInventoryBankFrame = NewFrame()

assert(loadfile(corePath))()
assert(loadfile(sorterPath))()
assert(loadfile(uiPath))()

assert(type(ShirsInventory_GetCategoryBankOnly) == "function",
  "bank-only category getter is missing")
assert(type(ShirsInventory_SetCategoryBankOnly) == "function",
  "bank-only category setter is missing")
assert(type(ShirsInventory_IsCategoryViewEnabled) == "function",
  "category-view scope resolver is missing")

-- Safe defaults: category mode off, bank-only off.
assert(not ShirsInventory_GetCategoryMode(),
  "category view must default to off")
assert(not ShirsInventory_GetCategoryBankOnly(),
  "bank-only category option must default to off")

-- Persistence and validation of the bank-only flag.
assert(ShirsInventory_SetCategoryBankOnly(true),
  "bank-only category toggle did not persist on")
assert(ShirsInventory_GetCategoryBankOnly(),
  "bank-only category toggle did not report on")
ShirsInventoryDB.categoryBankOnly = "invalid"
assert(not ShirsInventory_GetCategoryBankOnly(),
  "malformed bank-only flag must repair to false")
assert(ShirsInventory_SetCategoryBankOnly(false) == false,
  "bank-only category toggle did not persist off")

-- With category mode on and bank-only off, the carried window uses category view.
ShirsInventory_SetCategoryMode(true)
assert(ShirsInventory_IsCategoryViewEnabled(false),
  "carried bags must use category view when bank-only is off")

-- With bank-only on, the carried window must stay on the standard grid.
ShirsInventory_SetCategoryBankOnly(true)
assert(not ShirsInventory_IsCategoryViewEnabled(false),
  "carried bags must stay on the standard grid in bank-only mode")

-- Category mode off disables the carried category view regardless of bank-only.
ShirsInventory_SetCategoryMode(false)
assert(not ShirsInventory_IsCategoryViewEnabled(false),
  "carried category view must be off when category mode is off")

-- Bank-only mode must never block carried-bag sorting.
ShirsInventory_SetCategoryMode(true)
ShirsInventory_SetCategoryBankOnly(true)
assert(type(ShirsInventory_SortBags) == "function",
  "bag sorter entry point is missing")
local started, reason = ShirsInventory_SortBags()
assert(started and reason == "started",
  "bank-only category mode must keep carried-bag sorting on its normal path")

-- Sorter scope stays exactly {0..4} in bank-only mode.
local containers = ShirsInventory_GetBagSortContainers()
local expected = {0, 1, 2, 3, 4}
assert(table.getn(containers) == table.getn(expected),
  "bank-only category mode changed the carried-bag sorter scope")
local index
for index = 1, table.getn(expected) do
  assert(containers[index] == expected[index],
    "bank-only category mode leaked a bank container into bag sorting")
end

-- Hearthstone selection must not be suppressed by bank-only category view.
local itemId = 7076
ShirsInventoryDB.hearthstoneItems = {}
assert(ShirsInventory_ToggleHearthstoneItem and
  ShirsInventory_GetHearthstoneItemIndex(itemId) == nil,
  "hearthstone selection model is missing")
local ok, status = ShirsInventory_ToggleHearthstoneItem(itemId)
assert(ok and ShirsInventory_GetHearthstoneItemIndex(itemId) == 1,
  "bank-only category mode must not block carried-item selection")

-- The carried window's search model stays independent of bank state.
assert(type(ShirsInventory_GetSearchQueryForButton) == "function",
  "search-query selector is missing")
ShirsInventoryFrame = { searchQuery = "moon" }
ShirsInventoryBankFrame = { searchQuery = "rune" }
local carriedButton = { shirsInventorySearchEnabled = true }
local bankButton = {
  shirsInventorySearchEnabled = false,
  shirsInventorySearchFrame = ShirsInventoryBankFrame,
}
assert(ShirsInventory_GetSearchQueryForButton(carriedButton) == "moon",
  "carried search must read the carried window, not the bank")
assert(ShirsInventory_GetSearchQueryForButton(bankButton) == "rune",
  "bank search must read the bank window")

-- The real bank update dispatcher must select an actual category renderer.
assert(type(ShirsInventory_GetBankRenderMode) == "function",
  "bank render-mode resolver is missing")
assert(type(ShirsInventory_RebuildBankCategoryGrid) == "function",
  "bank category renderer is missing")
ShirsInventory_SetCategoryMode(true)
ShirsInventory_SetCategoryBankOnly(true)
assert(ShirsInventory_GetBankRenderMode() == "category",
  "bank-only mode did not select the bank category renderer")
local categoryRenderCalls = 0
local savedCategoryRenderer = ShirsInventory_RebuildBankCategoryGrid
ShirsInventory_RebuildBankCategoryGrid = function(frame)
  categoryRenderCalls = categoryRenderCalls + 1
  return frame == ShirsInventoryBankFrame
end
ShirsInventoryBankFrame.IsShown = function() return true end
assert(ShirsInventory_UpdateBank(ShirsInventoryBankFrame) and categoryRenderCalls == 1,
  "the real bank update path did not dispatch to category rendering")
ShirsInventory_RebuildBankCategoryGrid = savedCategoryRenderer
ShirsInventory_SetCategoryMode(false)
assert(ShirsInventory_GetBankRenderMode() == "standard",
  "disabling category mode did not restore the standard bank renderer")

-- The settings panel must expose the bank-only option.
if settingsPath then
  local settings = assert(io.open(settingsPath, "rb")):read("*a")
  assert(string.find(settings, "categoryBankOnly", 1, true) and
    string.find(settings, "ShirsInventory_SetCategoryBankOnly", 1, true) and
    string.find(settings, "ShirsInventory_UpdateBank(ShirsInventoryBankFrame)", 1, true),
    "settings must expose and persist the bank-only category option")
end

ShirsInventory_SetCategoryBankOnly(false)
ShirsInventory_SetCategoryMode(false)
print("BANK_ONLY_CATEGORY_TEST=PASS")
