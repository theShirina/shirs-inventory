local corePath, enginePath, specialtyPath, sorterPath = arg[1], arg[2], arg[3], arg[4]

ShirsInventoryDB = { setupComplete = true, features = { bagUI = false, sorter = true, junk = false } }
local cursor = false
local combat = false
local now = 100
local updateHandler

local function NewFrame()
  local frame = { shown = false }
  function frame:Hide() self.shown = false end
  function frame:Show() self.shown = true end
  function frame:IsShown() return self.shown end
  function frame:IsVisible() return self.shown end
  function frame:SetScript(name, handler) if name == "OnUpdate" then updateHandler = handler end end
  function frame:SetOwner() end
  function frame:ClearLines() end
  function frame:NumLines() return 0 end
  function frame:SetBagItem() end
  function frame:SetInventoryItem() end
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
function GetContainerNumSlots() return 0 end
function CursorHasItem() return cursor end
function ClearCursor() cursor = false end
function UnitAffectingCombat() return combat end
function GetTime() return now end
function GetBagName() return nil end
function GetContainerItemInfo() return nil, 0, false end
function GetContainerItemLink() return nil end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
BankFrame = NewFrame()

assert(loadfile(corePath))()
assert(loadfile(enginePath))()
assert(loadfile(specialtyPath))()
assert(loadfile(sorterPath))()

assert(ShirsInventory_GetSortEngineVersion() == 1, "new sorter engine marker is missing")
assert(type(ShirsInventory_GetSortDiagnostics) == "function", "sort diagnostics API is missing")

cursor = true
local ok, status = ShirsInventory_SortBags()
assert(ok == false and status == "cursor", "busy cursor should reject sorting before reporting started")
cursor = false

combat = true
ok, status = ShirsInventory_SortBags()
assert(ok == false and status == "combat", "combat should reject sorting before reporting started")
combat = false

ok, status = ShirsInventory_SortBags()
assert(ok == true and status == "started" and ShirsInventory_IsRunning(), "empty bag sort did not enter running state")
ok, status = ShirsInventory_SortBags()
assert(ok == false and status == "running", "second sort should not start while one is active")
assert(type(updateHandler) == "function", "sort update handler was not installed")
arg1 = 0.35
updateHandler()
assert(not ShirsInventory_IsRunning(), "empty bag sort did not finish on its first tick")

ok, status = ShirsInventory_SortBank()
assert(ok == false and status == "bank", "closed bank should reject sorting")
BankFrame:Show()
ok, status = ShirsInventory_SortBank()
assert(ok == true and status == "started", "open bank sort did not start")
arg1 = 0.35
updateHandler()
assert(not ShirsInventory_IsRunning(), "empty bank sort did not finish")

ok, status = ShirsInventory_SortBags()
assert(ok and status == "started", "timeout diagnostic sort did not start")
now = now + 16
arg1 = 0.35
updateHandler()
local diagnostics = ShirsInventory_GetSortDiagnostics()
assert(diagnostics.reason == "timeout" and diagnostics.moves == 0, "timeout diagnostics were not retained")
assert(type(diagnostics.history) == "table" and diagnostics.bestMismatches == 0, "progress diagnostics were not retained")

print("SORT_ENGINE_RUNTIME_TEST=PASS")
