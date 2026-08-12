local addonPath = arg[1]

local originalSortBags = function() return "original-bags" end
local originalSortBank = function() return "original-bank" end
SortBags = originalSortBags
SortBankBags = originalSortBank

local function NewFrame()
  local scripts = {}
  local frame = {}
  function frame:Hide() self.visible = false end
  function frame:Show() self.visible = true end
  function frame:IsShown() return self.visible and true or false end
  function frame:IsVisible() return self.visible and true or false end
  function frame:SetScript(name, callback) scripts[name] = callback end
  return frame
end

function CreateFrame(frameType, name)
  local frame = NewFrame()
  if name then getfenv(0)[name] = frame end
  return frame
end

function GetAuctionItemClasses()
  return "Weapon", "Armor", "Container", "Consumable", "Trade Goods", "Projectile", "Quiver", "Recipe", "Reagent", "Miscellaneous"
end

DEFAULT_CHAT_FRAME = { AddMessage = function() end }
BANK_CONTAINER = -1
BankFrame = NewFrame()
SlashCmdList = {}

assert(loadfile(addonPath .. "/ShirsInventoryCore.lua"))()
assert(loadfile(addonPath .. "/ShirsInventorySortEngine.lua"))()
assert(loadfile(addonPath .. "/ShirsInventorySpecialtyItems.lua"))()
assert(loadfile(addonPath .. "/ShirsInventorySorter.lua"))()
assert(loadfile(addonPath .. "/ShirsInventoryJunk.lua"))()
CreateFrame = nil
assert(loadfile(addonPath .. "/ShirsInventoryUI.lua"))()
assert(loadfile(addonPath .. "/ShirsInventorySettings.lua"))()
assert(loadfile(addonPath .. "/Bindings.lua"))()

if SortBags ~= originalSortBags or SortBankBags ~= originalSortBank then
  error("ShirsInventory overwrote original SortBags globals")
end
if type(ShirsInventory_SortBags) ~= "function" or type(ShirsInventory_SortBank) ~= "function" then
  error("sorter entry points are missing")
end
if type(ShirsInventory_InitializeUI) ~= "function" or type(ShirsInventory_HandleItemClick) ~= "function" then
  error("combined inventory UI entry points are missing")
end
if type(ShirsInventory_StartJunkSale) ~= "function" then
  error("junk seller entry point is missing")
end
if type(ShirsInventory_CreateSettingsUI) ~= "function" or type(ShirsInventory_ShowSettings) ~= "function" then
  error("feature chooser/settings entry points are missing")
end
if BINDING_HEADER_SHIRSINVENTORY ~= "Shir's Inventory" or BINDING_NAME_SHIRSINVENTORY_SORT ~= "Sort bags" then
  error("binding labels did not load")
end

ShirsInventory_SortBank()
print("RUNTIME_LOAD_TEST=PASS")
