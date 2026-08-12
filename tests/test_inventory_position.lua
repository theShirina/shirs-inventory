local corePath, uiPath = arg[1], arg[2]
ShirsInventoryDB = {}
UIParent = { name = "UIParent" }
MainMenuBarBackpackButton = { name = "MainMenuBarBackpackButton" }
assert(loadfile(corePath))()
assert(loadfile(uiPath))()

assert(type(ShirsInventory_GetInventoryTitle) == "function",
  "player inventory title helper is missing")
assert(type(ShirsInventory_ConfigureInventoryFrameMovement) == "function",
  "inventory movement configuration helper is missing")
local movementFrame = {}
function movementFrame:SetMovable(value) self.movable = value end
function movementFrame:SetClampedToScreen(value) self.nativeClamp = value end
assert(ShirsInventory_ConfigureInventoryFrameMovement(movementFrame),
  "inventory movement configuration failed")
assert(movementFrame.movable == true,
  "inventory movement configuration did not keep the frame movable")
assert(movementFrame.nativeClamp == true,
  "inventory movement configuration did not restore stable native clamping")
assert(ShirsInventory_GetInventoryTitle("Shir") == "Shir's Inventory",
  "inventory title does not use the player name")
local titleFrame = { title = {} }
function titleFrame.title:SetText(text) self.text = text end
assert(ShirsInventory_RefreshInventoryTitle(titleFrame, "Shir") == "Shir's Inventory" and
  titleFrame.title.text == "Shir's Inventory", "inventory frame title was not refreshed")

local frame = { points = {} }
function frame:ClearAllPoints() self.cleared = true end
function frame:SetPoint(point, relativeTo, relativePoint, x, y)
  self.points = { point, relativeTo, relativePoint, x, y }
end
function frame:GetPoint()
  return "CENTER", UIParent, "CENTER", 123, -45
end
function frame:StopMovingOrSizing() self.stopped = true end

ShirsInventory_ApplyInventoryFramePosition(frame)
assert(frame.points[1] == "BOTTOMRIGHT", "default inventory point should attach above the bag bar")
assert(frame.points[2] == MainMenuBarBackpackButton, "default inventory anchor should be the Backpack bag-bar button")
assert(frame.points[3] == "TOPRIGHT" and frame.points[4] == 0 and frame.points[5] == 8, "default bag-bar offset changed")

assert(ShirsInventory_SaveInventoryFramePosition(frame), "dragged position was not saved")
local saved = ShirsInventory_GetInventoryFramePosition()
assert(saved.point == "CENTER" and saved.relativePoint == "CENTER", "saved point is wrong")
assert(saved.x == 123 and saved.y == -45, "saved offsets are wrong")

assert(ShirsInventory_OnInventoryDragStop(frame), "manual drag stop did not persist the position")
assert(frame.stopped, "manual drag stop did not stop frame movement")

local realDrag = {}
function realDrag:StopMovingOrSizing() self.stopped = true end
function realDrag:GetPoint() return "BOTTOMRIGHT", MainMenuBarBackpackButton, "TOPRIGHT", 0, 8 end
function realDrag:GetLeft() return 333 end
function realDrag:GetTop() return 777 end
function realDrag:ClearAllPoints() self.cleared = true end
function realDrag:SetPoint(point, relativeTo, relativePoint, x, y)
  self.points = {point, relativeTo, relativePoint, x, y}
end
assert(ShirsInventory_OnInventoryDragStop(realDrag), "real drag stop did not save a canonical screen position")
saved = ShirsInventory_GetInventoryFramePosition()
assert(saved.point == "TOPLEFT" and saved.relativePoint == "BOTTOMLEFT" and
  saved.x == 333 and saved.y == 777,
  "drag stop kept a transient anchor instead of the frame's absolute top-left position")
assert(realDrag.cleared and realDrag.points[1] == "TOPLEFT" and
  realDrag.points[2] == UIParent and realDrag.points[3] == "BOTTOMLEFT" and
  realDrag.points[4] == 333 and realDrag.points[5] == 777,
  "drag stop did not normalize both the live x-axis and y-axis to the saved screen anchor")
local realReopen = { points = {}, title = {} }
function realReopen:ClearAllPoints() end
function realReopen:SetPoint(point, relativeTo, relativePoint, x, y)
  self.points = {point, relativeTo, relativePoint, x, y}
end
function realReopen.title:SetText() end
assert(ShirsInventory_PrepareInventoryFrameForShow(realReopen, "Shir"),
  "real dragged position was not restored on reopen")
assert(realReopen.points[1] == "TOPLEFT" and realReopen.points[2] == UIParent and
  realReopen.points[3] == "BOTTOMLEFT" and realReopen.points[4] == 333 and realReopen.points[5] == 777,
  "reopening bags reset the canonical dragged position")

function UIParent:GetWidth() return 1024 end
function UIParent:GetHeight() return 819 end
function MainMenuBarBackpackButton:GetTop() return 100 end
local clampedDrag = { left = 451, top = 934, width = 416, height = 600 }
function clampedDrag:StopMovingOrSizing() self.stopped = true end
function clampedDrag:GetLeft() return self.left end
function clampedDrag:GetTop() return self.top end
function clampedDrag:GetWidth() return self.width end
function clampedDrag:GetHeight() return self.height end
function clampedDrag:ClearAllPoints() self.cleared = true end
function clampedDrag:SetPoint(point, relativeTo, relativePoint, x, y)
  self.points = {point, relativeTo, relativePoint, x, y}
  if point == "TOPLEFT" and relativePoint == "BOTTOMLEFT" then
    self.left, self.top = x, y
  end
end
assert(ShirsInventory_OnInventoryDragStop(clampedDrag),
  "drag stop rejected a freely moved inventory position")
saved = ShirsInventory_GetInventoryFramePosition()
assert(saved.x == 451 and saved.y == 934,
  "stable drag-stop did not save the native position unchanged")
assert(clampedDrag.points[1] == "TOPLEFT" and clampedDrag.points[2] == UIParent and
  clampedDrag.points[3] == "BOTTOMLEFT" and clampedDrag.points[4] == 451 and clampedDrag.points[5] == 934,
  "stable drag-stop altered the native position before reopen recovery")

-- Stable native dragging can move beyond UIParent's legacy safe rectangle.
-- Reopen recovery must preserve that position when the scaled frame still
-- fits inside the actual GetScreenWidth/GetScreenHeight viewport.
function UIParent:GetWidth() return 1365 end
function UIParent:GetHeight() return 768 end
function UIParent:GetEffectiveScale() return 1 end
GetScreenWidth = function() return 1680 end
GetScreenHeight = function() return 945 end
local dragFrame = {
  left = 1600, top = 1100, width = 400, height = 500,
  scripts = {}, effectiveScale = 0.8,
}
function dragFrame:StartMoving() self.nativeStarted = true end
function dragFrame:StopMovingOrSizing() self.nativeStopped = true end
function dragFrame:GetLeft() return self.left end
function dragFrame:GetTop() return self.top end
function dragFrame:GetWidth() return self.width end
function dragFrame:GetHeight() return self.height end
function dragFrame:GetEffectiveScale() return self.effectiveScale end
function dragFrame:GetScript(name) return self.scripts[name] end
function dragFrame:SetScript(name, callback) self.scripts[name] = callback end
function dragFrame:ClearAllPoints() self.cleared = true end
function dragFrame:SetPoint(point, relativeTo, relativePoint, x, y)
  self.points = {point, relativeTo, relativePoint, x, y}
  self.left, self.top = x, y
end
local dragHandle = { scripts = {} }
function dragHandle:RegisterForDrag(button) self.dragButton = button end
function dragHandle:SetScript(name, callback) self.scripts[name] = callback end
assert(type(ShirsInventory_BindInventoryDragHandle) == "function", "inventory drag handle binder is missing")
assert(ShirsInventory_BindInventoryDragHandle(dragFrame, dragHandle), "inventory drag handle was not bound")
assert(dragHandle.dragButton == "LeftButton", "inventory drag handle did not register left-button dragging")
dragHandle.scripts.OnDragStart()
assert(dragFrame.nativeStarted, "inventory drag handle did not restore stable native movement")
dragHandle.scripts.OnDragStop()
assert(dragFrame.nativeStopped, "inventory drag handle did not stop native movement")
saved = ShirsInventory_GetInventoryFramePosition()
assert(saved.x == 1600 and saved.y == 1100,
  "native drag did not save the position beyond UIParent's hidden boundary")
assert(ShirsInventory_ClampInventoryFrame(dragFrame, false),
  "reopen recovery rejected a position inside the actual screen")
saved = ShirsInventory_GetInventoryFramePosition()
assert(saved.x == 1600 and saved.y == 1100 and
  dragFrame.left == 1600 and dragFrame.top == 1100,
  "reopen recovery snapped a valid native position back to UIParent's hidden boundary")

local moved = { points = {} }
function moved:ClearAllPoints() self.cleared = true end
function moved:SetPoint(point, relativeTo, relativePoint, x, y)
  self.points = { point, relativeTo, relativePoint, x, y }
end
function moved:GetPoint()
  return self.points[1], self.points[2], self.points[3], self.points[4], self.points[5]
end

assert(ShirsInventory_SetInventoryFrameAnchor(
  moved, "TOPLEFT", UIParent, "BOTTOMLEFT", 44, 500, true
), "programmatic anchor move was not saved")
saved = ShirsInventory_GetInventoryFramePosition()
assert(saved.point == "TOPLEFT" and saved.relativePoint == "BOTTOMLEFT",
  "programmatic anchor save used the wrong points")
assert(saved.x == 44 and saved.y == 500, "programmatic anchor offsets were not saved")

local restored = { points = {} }
function restored:ClearAllPoints() self.cleared = true end
function restored:SetPoint(point, relativeTo, relativePoint, x, y)
  self.points = { point, relativeTo, relativePoint, x, y }
end
ShirsInventory_ApplyInventoryFramePosition(restored)
assert(restored.points[1] == "TOPLEFT" and restored.points[2] == UIParent,
  "saved frame position should restore against UIParent")
assert(restored.points[4] == 44 and restored.points[5] == 500, "restored frame offsets are wrong")

local reopened = { points = {}, title = {} }
function reopened:ClearAllPoints() self.cleared = true end
function reopened:SetPoint(point, relativeTo, relativePoint, x, y)
  self.points = { point, relativeTo, relativePoint, x, y }
end
function reopened.title:SetText(text) self.text = text end
reopened:SetPoint("BOTTOMRIGHT", MainMenuBarBackpackButton, "TOPRIGHT", 0, 8)
assert(type(ShirsInventory_PrepareInventoryFrameForShow) == "function",
  "inventory reopen position helper is missing")
assert(ShirsInventory_PrepareInventoryFrameForShow(reopened, "Shir"),
  "inventory reopen did not restore the saved character position")
assert(reopened.points[1] == "TOPLEFT" and reopened.points[2] == UIParent and
  reopened.points[3] == "BOTTOMLEFT" and reopened.points[4] == 44 and reopened.points[5] == 500,
  "closing and reopening the inventory reset its saved anchor")
assert(reopened.title.text == "Shir's Inventory", "reopen did not refresh the inventory title")

assert(ShirsInventory_ResetInventoryFramePosition(), "position reset failed")
assert(ShirsInventory_GetInventoryFramePosition() == nil, "position reset left saved state")
print("INVENTORY_POSITION_TEST=PASS")
