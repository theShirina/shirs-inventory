local corePath, sorterPath = arg[1], arg[2]
ShirsInventoryDB = { setupComplete = true, features = { bagUI = false, sorter = false, junk = true } }

local function NewFrame()
  local frame = {}
  function frame:Hide() end
  function frame:Show() end
  function frame:IsShown() return false end
  function frame:IsVisible() return false end
  function frame:SetScript() end
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

assert(loadfile(corePath))()
assert(loadfile(sorterPath))()

assert(type(ShirsInventory_SortBags) == "function" and type(ShirsInventory_SortBank) == "function",
  "full-suite sorter entry points are missing")
assert(ShirsInventory_IsFeatureEnabled("sorter"), "full-suite sorter is disabled")
assert(not ShirsInventory_SetFeatureEnabled("sorter", false),
  "obsolete feature API disabled the sorter")

print("SORTER_FEATURE_GATE_TEST=PASS")
