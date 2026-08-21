-- Direct production probe for the bank category renderer.
local corePath, uiPath = arg[1], arg[2]
BANK_CONTAINER = -1
UIParent = {}
ShirsInventoryDB = {
  categoryMode = true,
  categoryBankOnly = true,
  itemsPerRow = 10,
  collapseEmptySlots = false,
}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
GameTooltip = { SetOwner = function() end, SetText = function() end, Show = function() end, Hide = function() end }
function GetAuctionItemClasses()
  return "Weapon", "Armor", "Container", "Consumable", "Trade Goods", "Projectile", "Quiver", "Recipe", "Reagent", "Miscellaneous"
end
function GetContainerItemInfo(bag, slot)
  if bag == -1 and slot == 1 then return "texture", 1, nil, 2, nil end
  return nil, nil, nil, nil, nil
end
function GetContainerItemLink(bag, slot)
  if bag == -1 and slot == 1 then return "|Hitem:7076:0:0:0|h[Essence of Earth]|h" end
end
function GetItemInfo()
  return "Essence of Earth", "item:7076:0:0:0", 2, 55, "Trade Goods", "Elemental", 20, "", "texture"
end
function GetKeyRingSize() return 0 end
function GetScreenWidth() return 1280 end
function GetScreenHeight() return 800 end
function SetItemButtonCount(button, value) button.countText = value end

assert(loadfile(corePath))()
assert(loadfile(uiPath))()
assert(type(ShirsInventory_RebuildBankCategoryGrid) == "function",
  "bank category renderer is missing")

local createdHeaders = {}
local function NewRegion()
  local region = {}
  function region:SetAllPoints() end
  function region:SetText(value) self.text = value end
  function region:SetTextColor() end
  function region:SetJustifyH() end
  return region
end
function CreateFrame(frameType)
  local header = { scripts = {}, visible = false }
  function header:SetHeight(value) self.height = value end
  function header:SetWidth(value) self.width = value end
  function header:CreateFontString() self.text = NewRegion() return self.text end
  function header:SetScript(name, callback) self.scripts[name] = callback end
  function header:EnableMouseWheel(value) self.mouseWheel = value end
  function header:ClearAllPoints() end
  function header:SetPoint(...) self.point = arg end
  function header:Show() self.visible = true end
  function header:Hide() self.visible = false end
  function header:SetOrientation(value) self.orientation = value end
  function header:SetValueStep(value) self.valueStep = value end
  function header:SetThumbTexture(value) self.thumbTexture = value end
  function header:SetMinMaxValues(low, high) self.low = low self.high = high end
  function header:SetValue(value) self.value = value end
  if frameType ~= "Slider" then table.insert(createdHeaders, header) end
  return header
end

local createdButtons = {}
local function CreateProbeItemButton(index, parent, prefix, collection)
  local button = { visible = false }
  function button:SetID(value) self.id = value end
  function button:ClearAllPoints() end
  function button:SetPoint(...) self.point = arg end
  function button:SetScript(name, callback) self[name] = callback end
  function button:EnableMouseWheel(value) self.mouseWheel = value end
  function button:Show() self.visible = true end
  function button:Hide() self.visible = false end
  collection[index] = button
  createdButtons[index] = button
  return button
end

local savedBuildCategoryLayout = ShirsInventory_BuildCategoryLayout
ShirsInventory_BuildCategoryLayout = function(groups, columns)
  local layout = savedBuildCategoryLayout(groups, columns)
  layout.height = 1254
  return layout
end

-- Replace only the private visual renderer; this probe tests category model,
-- address binding, ownership context, geometry, and dispatch.
local upvalueIndex
for upvalueIndex = 1, 30 do
  local name, value = debug.getupvalue(ShirsInventory_RebuildBankCategoryGrid, upvalueIndex)
  if name == "ShirsInventory_CreateItemButton" then
    debug.setupvalue(ShirsInventory_RebuildBankCategoryGrid, upvalueIndex, CreateProbeItemButton)
  elseif name == "ShirsInventory_UpdateItemButton" then
    debug.setupvalue(ShirsInventory_RebuildBankCategoryGrid, upvalueIndex, function(button)
      button.hasItem = button.slot == 1
    end)
  end
end

local freeText = { SetText = function(self, value) self.text = value end }
local frame = { visible = true, freeText = freeText, scripts = {} }
function frame:IsShown() return self.visible end
function frame:SetWidth(value) self.width = value end
function frame:SetHeight(value) self.height = value end
function frame:GetHeight() return self.height end
function frame:SetScale(value) self.scale = value end
function frame:EnableMouseWheel(value) self.mouseWheel = value end
function frame:SetScript(name, callback) self.scripts[name] = callback end
ShirsInventoryBankFrame = frame

local recovered, bagBarUpdated, stylesRefreshed = 0, 0, 0
ShirsInventory_RecoverBankViewport = function(got) assert(got == frame) recovered = recovered + 1 return true end
ShirsInventory_UpdateBankBagBar = function(got) assert(got == frame) bagBarUpdated = bagBarUpdated + 1 end
ShirsInventory_RefreshBankButtonStyles = function() stylesRefreshed = stylesRefreshed + 1 end

local slotCounts = { [-1] = 2 }
local slots = { { bag = -1, slot = 1 }, { bag = -1, slot = 2 } }
assert(ShirsInventory_RebuildBankCategoryGrid(frame, slotCounts, slots),
  "bank category renderer rejected a valid bank model")
assert(frame.width and frame.width > 0 and frame.height and frame.height > 0,
  "bank category renderer did not size the bank frame")
assert(frame.height < 800 and ShirsInventory_GetBankCategoryScrollMax() > 0,
  "oversized bank category layout must use a bounded viewport and positive scroll range")
assert(frame.mouseWheel and type(frame.scripts.OnMouseWheel) == "function",
  "scrollable bank category view must bind mouse-wheel scrolling")
assert(table.getn(createdHeaders) >= 1 and createdHeaders[1].visible,
  "bank category renderer did not create a visible heading")
assert(table.getn(createdButtons) == 2 and createdButtons[1].visible and createdButtons[2].visible,
  "bank category renderer did not bind both physical bank slots")
assert(createdButtons[1].bag == -1 and createdButtons[1].slot == 1 and
  createdButtons[2].bag == -1 and createdButtons[2].slot == 2,
  "bank category renderer changed physical bank addresses")
assert(createdButtons[1].shirsInventorySearchEnabled == false and
  createdButtons[1].shirsInventorySearchFrame == frame,
  "bank category renderer leaked carried search ownership")
assert(freeText.text == "1 free",
  "bank category renderer reported the wrong free-slot total")
assert(recovered == 1 and bagBarUpdated == 1 and stylesRefreshed == 1,
  "bank category renderer skipped viewport, bag-bar, or control refresh")

local openingY = createdButtons[1].point[5]
this = frame
arg1 = -1
frame.scripts.OnMouseWheel()
assert(ShirsInventory_GetBankCategoryScrollOffset() == 40 and
  createdButtons[1].point[5] == openingY + 40,
  "bank category mouse wheel must move the bounded content by one item row")

print("BANK_CATEGORY_RENDER_TEST=PASS")
