local corePath, uiPath, settingsPath = arg[1], arg[2], arg[3]
local settings = assert(io.open(settingsPath, "rb")):read("*a")

ShirsInventoryDB = {}
assert(loadfile(corePath))()
assert(loadfile(uiPath))()
assert(loadfile(settingsPath))()

assert(type(ShirsInventory_GetItemsPerRow) == "function" and
  type(ShirsInventory_SetItemsPerRow) == "function",
  "items-per-row option API is missing")
assert(ShirsInventory_GetItemsPerRow() == 10,
  "items per row must keep the current ten-column default")
assert(ShirsInventory_SetItemsPerRow(9) == 10 and
  ShirsInventory_SetItemsPerRow(21) == 20 and
  ShirsInventory_SetItemsPerRow(14.6) == 15,
  "items-per-row setter must round and clamp to 10-20")
assert(ShirsInventory_GetBankFrameLayout().maximumColumns == 15,
  "bank and inventory must share the items-per-row setting")

assert(type(ShirsInventory_GetWindowScale) == "function" and
  type(ShirsInventory_SetWindowScale) == "function",
  "inventory scale option API is missing")
assert(ShirsInventory_GetWindowScale() == 1,
  "inventory scale must default to 100 percent")
assert(ShirsInventory_SetWindowScale(0.5) == 0.65 and
  ShirsInventory_SetWindowScale(2) == 1 and
  ShirsInventory_SetWindowScale(0.83) == 0.85,
  "inventory scale setter must round and clamp to 65-100 percent")

UIParent = {}
function UIParent:GetWidth() return 1024 end
function UIParent:GetHeight() return 768 end
local inventoryFrame = { shown = true, left = 500, top = 700, width = 828, height = 252 }
function inventoryFrame:SetScale(value) self.scale = value end
function inventoryFrame:GetScale() return self.scale end
function inventoryFrame:GetEffectiveScale() return self.scale end
function inventoryFrame:IsShown() return self.shown end
function inventoryFrame:GetLeft() return self.left end
function inventoryFrame:GetTop() return self.top end
function inventoryFrame:GetWidth() return self.width end
function inventoryFrame:GetHeight() return self.height end
function inventoryFrame:ClearAllPoints() end
function inventoryFrame:SetPoint(_, _, _, x, y)
  if self.deferGeometry then
    self.pendingLeft, self.pendingTop = x, y
  else
    self.left, self.top = x, y
  end
end
local bankFrame = { shown = true, left = 700, bottom = 50, width = 500, height = 300 }
function bankFrame:SetScale(value) self.scale = value end
function bankFrame:GetScale() return self.scale end
function bankFrame:GetEffectiveScale() return self.scale end
function bankFrame:IsShown() return self.shown end
function bankFrame:GetLeft() return self.left end
function bankFrame:GetBottom() return self.bottom end
function bankFrame:GetWidth() return self.width end
function bankFrame:GetHeight() return self.height end
function bankFrame:ClearAllPoints() end
function bankFrame:SetPoint(_, _, _, x, y)
  if self.deferGeometry then
    self.pendingLeft, self.pendingBottom = x, y
  else
    self.left, self.bottom = x, y
  end
end
ShirsInventoryFrame = inventoryFrame
ShirsInventoryBankFrame = bankFrame
local inventoryUpdates, bankUpdates = 0, 0
ShirsInventory_Update = function() inventoryUpdates = inventoryUpdates + 1 end
ShirsInventory_UpdateBank = function() bankUpdates = bankUpdates + 1 end
assert(ShirsInventory_ApplyLayoutSettings(),
  "layout settings did not apply to the visible windows")
assert(inventoryFrame.scale == 0.85 and bankFrame.scale == 0.85 and
  inventoryUpdates == 1 and bankUpdates == 1,
  "layout settings did not rescale and rebuild both visible windows")

assert(type(ShirsInventory_ApplyWindowScaleSetting) == "function",
  "lightweight window-scale apply path is missing")
local inventoryUpdatesBeforeScale = inventoryUpdates
local bankUpdatesBeforeScale = bankUpdates
ShirsInventory_SetWindowScale(0.75)
assert(ShirsInventory_ApplyWindowScaleSetting(),
  "lightweight window-scale apply path failed")
assert(inventoryFrame.scale == 0.75 and bankFrame.scale == 0.75,
  "lightweight window-scale apply path did not rescale both windows")
assert(inventoryUpdates == inventoryUpdatesBeforeScale and bankUpdates == bankUpdatesBeforeScale,
  "window-scale adjustment rebuilt item grids on every slider event")

ShirsInventory_SetItemsPerRow(20)
ShirsInventory_SetWindowScale(1)
inventoryFrame.left, inventoryFrame.top = 500, 700
bankFrame.left, bankFrame.bottom = 700, 50
assert(ShirsInventory_ApplyLayoutSettings(),
  "extreme layout settings were not applied")
assert(inventoryFrame.left * inventoryFrame.scale >= 8 and
  (inventoryFrame.left + inventoryFrame.width) * inventoryFrame.scale <= 1024 and
  inventoryFrame.top * inventoryFrame.scale <= 768 and
  (inventoryFrame.top - inventoryFrame.height) * inventoryFrame.scale >= 8,
  "inventory was not recovered from an inaccessible saved edge position")
assert(bankFrame.left * bankFrame.scale >= 8 and
  (bankFrame.left + bankFrame.width) * bankFrame.scale <= 1016 and
  bankFrame.bottom * bankFrame.scale >= 8 and
  (bankFrame.bottom + bankFrame.height) * bankFrame.scale <= 760,
  "bank was not recovered from an inaccessible saved edge position")

local inventorySaved, bankSaved = 0, 0
local originalSaveInventory = ShirsInventory_SaveInventoryFramePosition
local originalSaveBank = ShirsInventory_SaveBankFramePosition
ShirsInventory_SaveInventoryFramePosition = function(frame)
  inventorySaved = inventorySaved + 1
  return originalSaveInventory(frame)
end
ShirsInventory_SaveBankFramePosition = function(frame)
  bankSaved = bankSaved + 1
  return originalSaveBank(frame)
end
ShirsInventory_SetWindowScale(0.65)
inventoryFrame:SetScale(0.65)
bankFrame:SetScale(0.65)
inventoryFrame.left, inventoryFrame.top = 700, 900
bankFrame.left, bankFrame.bottom = 700, 100
assert(ShirsInventory_RecoverInventoryViewport(inventoryFrame) and
  ShirsInventory_RecoverBankViewport(bankFrame),
  "accessible small-scale windows failed viewport recovery")
assert(inventoryFrame.left == 700 and inventoryFrame.top == 900 and
  bankFrame.left == 700 and bankFrame.bottom == 100 and
  inventorySaved == 0 and bankSaved == 0,
  "accessible 65-percent windows were moved or their saved positions overwritten")

assert(type(ShirsInventory_RecoverInventoryViewport) == "function" and
  type(ShirsInventory_RecoverBankViewport) == "function",
  "show-time viewport recovery helpers are missing")
inventoryFrame.shown, bankFrame.shown = false, false
inventoryFrame.left, inventoryFrame.top = 500, 700
bankFrame.left, bankFrame.bottom = 700, 50
ShirsInventory_ApplyItemsPerRowSliderValue(20)
ShirsInventory_ApplyWindowScaleSliderValue(1)
assert(inventoryFrame.left == 500 and bankFrame.left == 700,
  "hidden windows were unexpectedly moved while changing layout settings")
inventoryFrame.shown, bankFrame.shown = true, true
assert(ShirsInventory_RecoverInventoryViewport(inventoryFrame) and
  ShirsInventory_RecoverBankViewport(bankFrame),
  "hidden windows were not recovered when reopened")
assert(inventoryFrame.left * inventoryFrame.scale >= 8 and
  (inventoryFrame.left + inventoryFrame.width) * inventoryFrame.scale <= 1024,
  "reopened inventory kept an inaccessible saved edge position")
assert(bankFrame.left * bankFrame.scale >= 8 and
  (bankFrame.left + bankFrame.width) * bankFrame.scale <= 1016,
  "reopened bank kept an inaccessible saved edge position")

ShirsInventory_SetWindowScale(1)
inventoryFrame:SetScale(1)
bankFrame:SetScale(1)
inventoryFrame.left, inventoryFrame.top = 700, 700
bankFrame.left, bankFrame.bottom = 700, 50
inventoryFrame.deferGeometry, bankFrame.deferGeometry = true, true
assert(ShirsInventory_RecoverInventoryViewport(inventoryFrame) and
  ShirsInventory_RecoverBankViewport(bankFrame),
  "deferred-geometry windows failed viewport recovery")
local delayedInventory = ShirsInventory_GetInventoryFramePosition()
local delayedBank = ShirsInventory_GetBankFramePosition()
assert(inventoryFrame.left == 700 and bankFrame.left == 700,
  "deferred-geometry probe updated Region getters too early")
assert(delayedInventory.x == inventoryFrame.pendingLeft and delayedInventory.y == inventoryFrame.pendingTop and
  delayedInventory.x ~= inventoryFrame.left,
  "inventory recovery persisted stale Region geometry")
assert(delayedBank.x == bankFrame.pendingLeft and delayedBank.y == bankFrame.pendingBottom and
  delayedBank.x ~= bankFrame.left,
  "bank recovery persisted stale Region geometry")
inventoryFrame.deferGeometry, bankFrame.deferGeometry = false, false

local layoutApplied, scaleApplied = 0, 0
ShirsInventory_ApplyLayoutSettings = function() layoutApplied = layoutApplied + 1 return true end
ShirsInventory_ApplyWindowScaleSetting = function() scaleApplied = scaleApplied + 1 return true end
assert(ShirsInventory_ApplyItemsPerRowSliderValue(18) == 18 and layoutApplied == 1,
  "items-per-row slider handler did not persist and apply its value")
assert(ShirsInventory_ApplyWindowScaleSliderValue(0.75) == 0.75 and
  layoutApplied == 1 and scaleApplied == 1,
  "scale slider handler rebuilt the full layout instead of using the lightweight path")

local sliderLabels = {}
local createdSliders = {}
function getglobal(name)
  if not sliderLabels[name] then
    sliderLabels[name] = { SetText = function(self, value) self.text = value end }
  end
  return sliderLabels[name]
end
function CreateFrame(frameType, name, parent, template)
  assert(frameType == "Slider" and template == "OptionsSliderTemplate",
    "layout controls must use the Vanilla options slider template")
  local slider = { scripts = {}, parent = parent }
  function slider:SetWidth(value) self.width = value end
  function slider:SetPoint(...) self.point = arg end
  function slider:SetMinMaxValues(low, high) self.low, self.high = low, high end
  function slider:SetValueStep(value) self.step = value end
  function slider:SetValue(value) self.value = value end
  function slider:GetValue() return self.value end
  function slider:SetScript(eventName, handler) self.scripts[eventName] = handler end
  createdSliders[name] = slider
  return slider
end
local sliderHost = {}
assert(ShirsInventory_CreateLayoutSliders(sliderHost),
  "settings did not construct the two layout sliders")
assert(sliderHost.itemsPerRowSlider.low == 10 and sliderHost.itemsPerRowSlider.high == 20 and
  sliderHost.itemsPerRowSlider.step == 1 and sliderHost.itemsPerRowSlider.width == 300,
  "items-per-row slider has the wrong bounds, step, or width")
assert(sliderHost.windowScaleSlider.low == 0.65 and sliderHost.windowScaleSlider.high == 1 and
  sliderHost.windowScaleSlider.step == 0.05 and sliderHost.windowScaleSlider.width == 300,
  "window-scale slider has the wrong bounds, step, or width")
local oldThis = this
this = sliderHost.itemsPerRowSlider
this:SetValue(17)
this.scripts.OnValueChanged()
assert(ShirsInventory_GetItemsPerRow() == 17,
  "bound items-per-row slider did not persist its selected value")
this = sliderHost.windowScaleSlider
this:SetValue(0.7)
this.scripts.OnValueChanged()
assert(ShirsInventory_GetWindowScale() == 0.7,
  "bound window-scale slider did not persist its selected value")
this = oldThis

assert(ShirsInventory_GetShowRarityBoxes(),
  "colored rarity boxes must default on")
ShirsInventory_SetShowRarityBoxes(false)
assert(not ShirsInventory_GetShowRarityBoxes(),
  "colored rarity boxes must remain optional")
assert(ShirsInventory_GetUseCoinIcons(),
  "coin-art currency mode must default on")
ShirsInventory_SetUseCoinIcons(false)
assert(not ShirsInventory_GetUseCoinIcons(),
  "plain g/s/c currency mode must remain selectable")
assert(type(ShirsInventory_GetHideItemOwnershipInCombat) == "function" and
  type(ShirsInventory_SetHideItemOwnershipInCombat) == "function" and
  not ShirsInventory_GetHideItemOwnershipInCombat(),
  "item ownership combat option API is missing or has the wrong default")
assert(ShirsInventory_SetHideItemOwnershipInCombat(true) and
  ShirsInventory_GetHideItemOwnershipInCombat(),
  "item ownership combat option did not persist")
assert(type(ShirsInventory_GetAutoClearSearch) == "function" and
  type(ShirsInventory_SetAutoClearSearch) == "function" and
  ShirsInventory_GetAutoClearSearch(),
  "automatic search clearing option is missing or must default on")
assert(not ShirsInventory_SetAutoClearSearch(false) and
  not ShirsInventory_GetAutoClearSearch(),
  "automatic search clearing option did not persist off")
assert(not string.find(settings, "Use icons for inventory header + action buttons", 1, true),
  "inventory text-style toggle must be removed now that bag controls are icon-only")
assert(string.find(settings, "Use coin icons for currency (off = g/s/c text)", 1, true),
  "currency option must explain the text fallback")
assert(string.find(settings, "Hide item ownership details while in combat", 1, true) and
  string.find(settings, "ShirsInventory_SetHideItemOwnershipInCombat", 1, true),
  "settings panel is missing the item ownership combat checkbox")
assert(string.find(settings, "Clear search when bags close or you click outside", 1, true) and
  string.find(settings, "ShirsInventory_SetAutoClearSearch", 1, true),
  "settings panel is missing the automatic search clearing checkbox")
assert(string.find(settings, 'frame, "Clear search when bags close or you click outside", "autoClearSearch", -262', 1, true) and
  string.find(settings, 'frame.itemsPerRowSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 45, -310)', 1, true) and
  string.find(settings, 'frame.windowScaleSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 45, -375)', 1, true),
  "automatic search checkbox and layout sliders need separate vertical rows")
assert(string.find(settings, '"Items per row: "', 1, true) and
  string.find(settings, 'SetMinMaxValues(10, 20)', 1, true) and
  string.find(settings, 'SetValueStep(1)', 1, true),
  "settings panel is missing the 10-20 items-per-row slider")
assert(string.find(settings, '"Window scale: "', 1, true) and
  string.find(settings, 'SetMinMaxValues(0.65, 1)', 1, true) and
  string.find(settings, 'SetValueStep(0.05)', 1, true),
  "settings panel is missing the 65-100 percent scale slider")
assert(not string.find(settings, "Full Bag UI", 1, true),
  "full-suite settings still expose the old bag UI feature switch")
assert(not string.find(settings, "Bag Sorter", 1, true),
  "full-suite settings still expose the old sorter feature switch")
assert(not string.find(settings, "Sell Junk + manual junk marks", 1, true),
  "full-suite settings still expose the old junk feature switch")
assert(not string.find(settings, "Choose Bag UI", 1, true),
  "full-suite settings still expose the old provider chooser")
assert(not string.find(settings, "Save Custom Choice", 1, true),
  "first-run custom feature selection still exists")
assert(not string.find(settings, "settingsFrame.errorText", 1, true),
  "settings still reference the removed feature-selection error label")
assert(string.find(settings, 'merchantSellButton:SetWidth(36)', 1, true) and
  string.find(settings, 'merchantSellButton:SetHeight(36)', 1, true),
  "merchant Sell Junk is not repair-button sized")
assert(string.find(settings,
  'merchantSellButton:SetPoint("RIGHT", MerchantRepairItemButton, "LEFT", -2, 0)', 1, true),
  "merchant Sell Junk is not immediately left of Repair an Item")
assert(string.find(settings,
  'CreateFrame("Button", "ShirsInventoryMerchantSellButton", MerchantFrame, "ItemButtonTemplate")', 1, true),
  "merchant Sell Junk does not use the standard bordered item-button frame")
assert(string.find(settings, 'sellJunkTexture:SetTexture("Interface\\\\Icons\\\\INV_Misc_Coin_01")', 1, true),
  "merchant Sell Junk does not use the coin icon")
assert(string.find(settings, 'sellJunkTexture:SetTexCoord(0, 1, 0, 1)', 1, true),
  "merchant Sell Junk icon remains zoom-cropped")
assert(not string.find(settings, 'merchantSellButton:SetText("Sell Junk")', 1, true),
  "merchant Sell Junk still uses the wide text button")
assert(string.find(settings, "MerchantRepairText:Hide()", 1, true),
  "merchant repair label remains visible behind the icon row")

print("INVENTORY_OPTIONS_UI_TEST=PASS")
