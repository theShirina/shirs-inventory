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

assert(loadfile(corePath))()
assert(loadfile(sorterPath))()

local ok, status = ShirsInventory_SortBags()
assert(ok == false and status == "disabled", "disabled sorter should not start a bag sort")
ok, status = ShirsInventory_SortBank()
assert(ok == false and status == "disabled", "disabled sorter should not start a bank sort")

print("SORTER_FEATURE_GATE_TEST=PASS")
