local corePath, uiPath = arg[1], arg[2]
BANK_CONTAINER = -1
UIParent = { name = "UIParent" }
ShirsInventoryDB = { junkItems = {} }
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local tooltipBag, tooltipSlot, tooltipInventory
local tooltipLines = {}
GameTooltip = {}
function GameTooltip:SetOwner() end
function GameTooltip:SetBagItem(bag, slot) tooltipBag, tooltipSlot = bag, slot end
function GameTooltip:SetInventoryItem(unit, inventory) tooltipInventory = inventory return true end
function GameTooltip:AddLine(text) table.insert(tooltipLines, text) end
function GameTooltip:Show() end
function GameTooltip:Hide() end
function GameTooltip:IsOwned() return false end
function BankButtonIDToInvSlotID(slot) return 39 + slot end
function GetScreenWidth() return 1920 end
function GetContainerItemInfo() return "texture", 1, nil, 2, nil end
function GetContainerItemLink() return "|Hitem:7076:0:0:0|h[Essence of Earth]|h" end
function IsAltKeyDown() return false end
function IsControlKeyDown() return false end
function IsShiftKeyDown() return false end
function ResetCursor() end

local pickedBag, pickedSlot, usedBag, usedSlot
function PickupContainerItem(bag, slot) pickedBag, pickedSlot = bag, slot end
function UseContainerItem(bag, slot) usedBag, usedSlot = bag, slot end

assert(loadfile(corePath))()
assert(loadfile(uiPath))()

assert(type(ShirsInventory_GetBankTitle) == "function", "bank title helper is missing")
assert(ShirsInventory_GetBankTitle("Shir") == "Shir's Bank", "bank title should use the character name")

assert(type(ShirsInventory_SetItemTooltip) == "function", "shared bank tooltip path is missing")
local bankButton = { bag = BANK_CONTAINER, slot = 7, hasItem = true }
function bankButton:GetRight() return 100 end
assert(ShirsInventory_SetItemTooltip(bankButton) == "bank", "main bank slot should use the bank tooltip path")
assert(tooltipInventory == 46 and tooltipBag == nil, "main bank tooltip used the wrong inventory slot")

tooltipInventory, tooltipBag, tooltipSlot = nil, nil, nil
local bankBagButton = { bag = 5, slot = 2, hasItem = true }
assert(ShirsInventory_SetItemTooltip(bankBagButton) == "bag", "equipped bank bag should use the container tooltip path")
assert(tooltipBag == 5 and tooltipSlot == 2 and tooltipInventory == nil,
  "equipped bank bag tooltip used the wrong container address")

assert(ShirsInventory_HandleItemClick(bankButton, "LeftButton"), "bank left click was not handled")
assert(pickedBag == BANK_CONTAINER and pickedSlot == 7, "bank left click did not pick up the bank item")
assert(ShirsInventory_HandleItemClick(bankButton, "RightButton"), "bank right click was not handled")
assert(usedBag == BANK_CONTAINER and usedSlot == 7, "bank right click did not use the bank container address")

local frame = { visible = false }
function frame:Show() self.visible = true end
function frame:Hide() self.visible = false end
function frame:IsShown() return self.visible end
local updates = 0
ShirsInventory_UpdateBank = function(got)
  assert(got == frame, "bank event updated the wrong frame")
  updates = updates + 1
  return true
end
assert(type(ShirsInventory_HandleBankEvent) == "function", "bank event handler is missing")
assert(ShirsInventory_HandleBankEvent("BANKFRAME_OPENED", frame), "bank open event was not handled")
assert(frame.visible and updates == 1, "bank open event did not show and populate the combined bank")
assert(ShirsInventory_HandleBankEvent("PLAYERBANKSLOTS_CHANGED", frame), "bank slot update was not handled")
assert(updates == 2, "visible bank did not refresh after a bank slot change")
assert(ShirsInventory_HandleBankEvent("BANKFRAME_CLOSED", frame), "bank close event was not handled")
assert(not frame.visible and updates == 2, "bank close event did not hide the combined bank")
assert(not ShirsInventory_HandleBankEvent("PLAYERBANKSLOTS_CHANGED", frame),
  "hidden bank should ignore slot refreshes")
assert(updates == 2, "hidden bank refreshed unexpectedly")
assert(type(ShirsInventory_CreateBankFrame) == "function", "combined bank frame constructor is missing")

local popup
function StaticPopup_Show(name) popup = name end
assert(type(ShirsInventory_RequestBankSlotPurchase) == "function", "bank slot purchase prompt is missing")
assert(ShirsInventory_RequestBankSlotPurchase(), "bank slot purchase request was rejected")
assert(popup == "CONFIRM_BUY_BANK_SLOT", "plus button did not use the native bank-slot purchase prompt")

local nativeBank = { shown = true }
function nativeBank:SetScale(value) self.scale = value end
function nativeBank:SetAlpha(value) self.alpha = value end
function nativeBank:EnableMouse(value) self.mouse = value end
local pfBank = { shown = true }
function pfBank:IsShown() return self.shown end
function pfBank:Hide() self.shown = false end
assert(type(ShirsInventory_SuppressOtherBankFrames) == "function", "bank provider suppression is missing")
assert(ShirsInventory_SuppressOtherBankFrames(nativeBank, {pfBank}), "bank provider suppression failed")
assert(nativeBank.scale == 0.001 and nativeBank.alpha == 0 and nativeBank.mouse == false,
  "default World of Warcraft bank interface was not suppressed safely")
assert(not pfBank.shown, "another add-on bank interface remained visible")

local created = {}
function CreateFrame()
  local button = { scripts = {} }
  function button:SetWidth(value) self.width = value end
  function button:SetHeight(value) self.height = value end
  function button:SetPoint(...) self.point = arg end
  function button:SetText(value) self.text = value end
  function button:SetScript(name, callback) self.scripts[name] = callback end
  table.insert(created, button)
  return button
end
local bankSortCalls = 0
ShirsInventory_SortBank = function() bankSortCalls = bankSortCalls + 1 end
assert(type(ShirsInventory_CreateBankActionButtons) == "function", "bank action-button builder is missing")
local actionFrame = {}
assert(ShirsInventory_CreateBankActionButtons(actionFrame), "bank action buttons were not created")
assert(actionFrame.sortButton and actionFrame.modeButton and actionFrame.directionButton and actionFrame.settingsButton,
  "bank is missing one or more inventory action buttons")
actionFrame.sortButton.scripts.OnClick()
assert(bankSortCalls == 1, "bank Sort button did not call Shir's bank sorting engine entry point")

local normalBagClicks, shiftBagClicks = 0, 0
BankFrameItemButtonBag_OnClick = function() normalBagClicks = normalBagClicks + 1 end
BankFrameItemButtonBag_OnShiftClick = function() shiftBagClicks = shiftBagClicks + 1 end
IsShiftKeyDown = function() return true end
assert(ShirsInventory_HandleBankBagClick({bag = 5}, "LeftButton"), "bank bag Shift-click was rejected")
assert(shiftBagClicks == 1 and normalBagClicks == 0,
  "bank bag Shift-click did not use the native bag-removal handler")
IsShiftKeyDown = function() return false end
assert(ShirsInventory_HandleBankBagClick({bag = 5}, "LeftButton"), "bank bag click was rejected")
assert(normalBagClicks == 1, "bank bag click did not use the native bag handler")
IsShiftKeyDown = function() return true end
assert(type(ShirsInventory_HandleBankBagDrop) == "function", "bank bag drop handler is missing")
assert(ShirsInventory_HandleBankBagDrop({bag = 5}, "LeftButton"), "bank bag drop was rejected")
assert(normalBagClicks == 2 and shiftBagClicks == 1,
  "Shift held during a bank bag drop used the removal path instead of the drop path")

local boundBag = { bag = 5, inventoryID = 69, scripts = {} }
function boundBag:SetScript(name, callback) self.scripts[name] = callback end
assert(type(ShirsInventory_BindBankBagButtonScripts) == "function",
  "bank bag exact-handler binding helper is missing")
assert(ShirsInventory_BindBankBagButtonScripts(boundBag), "bank bag handlers were not bound")
this = boundBag
local beforeBoundDrop, beforeBoundShift = normalBagClicks, shiftBagClicks
boundBag.scripts.OnReceiveDrag()
assert(normalBagClicks == beforeBoundDrop + 1 and shiftBagClicks == beforeBoundShift,
  "bound OnReceiveDrag used Shift-removal instead of native drop handling")

local function NewRangeButton(bag)
  local highlight = { visible = false }
  function highlight:Show() self.visible = true end
  function highlight:Hide() self.visible = false end
  local button = { bag = bag, bagRangeHighlight = highlight }
  function button:IsShown() return true end
  return button
end
local bankRangeButtons = {NewRangeButton(BANK_CONTAINER), NewRangeButton(5), NewRangeButton(5), NewRangeButton(6)}
local hoveredBankBag = {
  texture = "bag-texture",
  inventoryID = 44,
  bagEntry = {
    bag = 5,
    inventoryID = 44,
    slots = 16,
    firstCombinedIndex = 25,
    lastCombinedIndex = 40,
  },
}
tooltipLines = {}
assert(type(ShirsInventory_OnBankBagEnter) == "function", "bank bag hover handler is missing")
assert(ShirsInventory_OnBankBagEnter(hoveredBankBag, bankRangeButtons),
  "bank bag hover was not handled")
assert(not bankRangeButtons[1].bagRangeHighlight.visible and
  bankRangeButtons[2].bagRangeHighlight.visible and bankRangeButtons[3].bagRangeHighlight.visible and
  not bankRangeButtons[4].bagRangeHighlight.visible,
  "bank bag hover did not highlight exactly the represented bank container")
assert(tooltipLines[1] == "16 slots" and tooltipLines[2] == "Combined slots 25-40",
  "bank bag tooltip does not describe its represented combined slots")
assert(type(ShirsInventory_OnBankBagLeave) == "function", "bank bag leave handler is missing")
assert(ShirsInventory_OnBankBagLeave(bankRangeButtons), "bank bag leave was not handled")
assert(not bankRangeButtons[2].bagRangeHighlight.visible and not bankRangeButtons[3].bagRangeHighlight.visible,
  "bank bag slot highlights remained after hover ended")

local selectedGossip
GetGossipOptions = function()
  return "Browse your goods", "vendor", "I would like to check my deposit box.", "banker"
end
SelectGossipOption = function(index) selectedGossip = index end
assert(type(ShirsInventory_TryOpenBankFromGossip) == "function", "banker gossip bypass is missing")
assert(ShirsInventory_HandleBankEvent("GOSSIP_SHOW", frame), "banker gossip event was not selected")
assert(selectedGossip == 2, "banker gossip bypass selected the wrong option")
selectedGossip = nil
GetGossipOptions = function() return "Tell me a story", "gossip" end
assert(not ShirsInventory_HandleBankEvent("GOSSIP_SHOW", frame) and selectedGossip == nil,
  "non-banker gossip was selected automatically")
selectedGossip = nil
GetGossipOptions = function() return "Browse your goods", "banker", "Tell me a story", "gossip" end
assert(not ShirsInventory_HandleBankEvent("GOSSIP_SHOW", frame) and selectedGossip == nil,
  "banker-typed gossip without the explicit deposit-box dialogue was selected automatically")
selectedGossip = nil
GetGossipOptions = function() return "I WOULD LIKE TO CHECK MY DEPOSIT BOX.", "banker" end
assert(not ShirsInventory_HandleBankEvent("GOSSIP_SHOW", frame) and selectedGossip == nil,
  "case-changed banker text was accepted instead of the exact deposit-box dialogue")
selectedGossip = nil
GetGossipOptions = function() return " I would like to check my deposit box.", "banker" end
assert(not ShirsInventory_HandleBankEvent("GOSSIP_SHOW", frame) and selectedGossip == nil,
  "whitespace-prefixed banker text was accepted instead of the exact deposit-box dialogue")
selectedGossip = nil
GetGossipOptions = function() return "I would like  to check my deposit box.", "banker" end
assert(not ShirsInventory_HandleBankEvent("GOSSIP_SHOW", frame) and selectedGossip == nil,
  "whitespace-changed banker text was accepted instead of the exact deposit-box dialogue")
selectedGossip = nil
GetGossipOptions = function() return "I would like to check my deposit box", "banker" end
assert(ShirsInventory_HandleBankEvent("GOSSIP_SHOW", frame) and selectedGossip == 1,
  "explicit deposit-box dialogue without terminal punctuation was not selected")

frame:Show()
ShirsInventoryBankFrame = frame
local beforeRarityRefresh = updates
ShirsInventory_RefreshRarityBoxes()
assert(updates == beforeRarityRefresh + 1,
  "changing rarity borders did not refresh the visible bank")

local function NewVisualButton()
  local highlight = {}
  function highlight:ClearAllPoints() self.cleared = true end
  function highlight:SetAllPoints(owner) self.allPoints = owner end
  function highlight:SetVertexColor(r, g, b, a) self.color = {r, g, b, a} end
  local icon = {}
  function icon:ClearAllPoints() self.cleared = true end
  function icon:SetAllPoints(owner) self.allPoints = owner end
  function icon:SetTexture(value) self.texture = value end
  function icon:SetVertexColor(r, g, b, a) self.color = {r, g, b, a} end
  local button = { highlight = highlight, createdIcon = icon }
  function button:SetWidth(value) self.width = value end
  function button:SetHeight(value) self.height = value end
  function button:CreateTexture(_, layer) self.iconLayer = layer return self.createdIcon end
  function button:SetNormalTexture(value) self.normalTexture = value end
  function button:SetHighlightTexture(path, blend) self.highlightPath, self.highlightBlend = path, blend end
  function button:GetHighlightTexture() return self.highlight end
  return button
end

assert(type(ShirsInventory_ApplyBankBagButtonVisuals) == "function",
  "shared bank bag visual helper is missing")
local equippedVisual = NewVisualButton()
assert(ShirsInventory_ApplyBankBagButtonVisuals(equippedVisual, false),
  "equipped bank bag visuals were not applied")
assert(equippedVisual.width == 26 and equippedVisual.height == 26,
  "equipped bank bag button does not match inventory bag dimensions")
assert(equippedVisual.icon and equippedVisual.icon.allPoints == equippedVisual,
  "equipped bank bag icon is inset instead of filling the button")
assert(equippedVisual.normalTexture == nil,
  "equipped bank bag has a permanent second slot-frame layer")
assert(equippedVisual.highlightPath == "Interface\\Buttons\\WHITE8X8" and
  equippedVisual.highlightBlend == "ADD" and equippedVisual.highlight.allPoints == equippedVisual,
  "equipped bank bag hover does not match the exact icon bounds")

local purchaseVisual = NewVisualButton()
assert(ShirsInventory_ApplyBankBagButtonVisuals(purchaseVisual, true),
  "purchasable bank bag visuals were not applied")
assert(purchaseVisual.width == 26 and purchaseVisual.height == 26 and
  purchaseVisual.highlight.allPoints == purchaseVisual,
  "purchasable bank bag hover is larger than its icon")
assert(purchaseVisual.icon.texture == "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag",
  "purchasable bank bag does not use the same single-layer bag-slot art")

local anchorFrame = { pointsCleared = false }
function anchorFrame:ClearAllPoints() self.pointsCleared = true end
function anchorFrame:SetPoint(point, relativeTo, relativePoint, x, y)
  self.anchor = {point, relativeTo, relativePoint, x, y}
end
assert(type(ShirsInventory_ApplyBankFrameAnchor) == "function", "bank anchor helper is missing")
assert(ShirsInventory_ApplyBankFrameAnchor(anchorFrame), "bank bottom-left anchor was not applied")
assert(anchorFrame.pointsCleared and anchorFrame.anchor[1] == "BOTTOMLEFT" and
  anchorFrame.anchor[2] == UIParent and anchorFrame.anchor[3] == "BOTTOMLEFT" and
  anchorFrame.anchor[4] == 20 and anchorFrame.anchor[5] == 20,
  "bank frame is not anchored to the screen's bottom-left by default")

local movedBank = {}
function movedBank:StopMovingOrSizing() self.stopped = true end
function movedBank:GetLeft() return 145 end
function movedBank:GetBottom() return 275 end
function movedBank:ClearAllPoints() self.cleared = true end
function movedBank:SetPoint(point, relativeTo, relativePoint, x, y)
  self.anchor = {point, relativeTo, relativePoint, x, y}
end
assert(type(ShirsInventory_GetBankFramePosition) == "function", "bank saved-position getter is missing")
assert(type(ShirsInventory_OnBankDragStop) == "function", "bank drag-stop handler is missing")
assert(ShirsInventory_OnBankDragStop(movedBank), "moved bank position was not saved")
local savedBank = ShirsInventory_GetBankFramePosition()
assert(savedBank and savedBank.point == "BOTTOMLEFT" and savedBank.relativePoint == "BOTTOMLEFT" and
  savedBank.x == 145 and savedBank.y == 275,
  "bank position was not stored in the per-character SavedVariables table")
assert(movedBank.stopped and movedBank.cleared and movedBank.anchor[4] == 145 and movedBank.anchor[5] == 275,
  "bank drag stop did not immediately normalize the saved anchor")
local restoredBank = {}
function restoredBank:ClearAllPoints() self.cleared = true end
function restoredBank:SetPoint(point, relativeTo, relativePoint, x, y)
  self.anchor = {point, relativeTo, relativePoint, x, y}
end
assert(ShirsInventory_ApplyBankFrameAnchor(restoredBank), "saved bank anchor was not restored")
assert(restoredBank.anchor[1] == "BOTTOMLEFT" and restoredBank.anchor[2] == UIParent and
  restoredBank.anchor[3] == "BOTTOMLEFT" and restoredBank.anchor[4] == 145 and restoredBank.anchor[5] == 275,
  "recreated bank frame did not restore the per-character saved position")

print("BANK_UI_TEST=PASS")
