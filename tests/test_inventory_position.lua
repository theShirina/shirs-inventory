local corePath, uiPath = arg[1], arg[2]
ShirsInventoryDB = {}
UIParent = { name = "UIParent" }
MainMenuBarBackpackButton = { name = "MainMenuBarBackpackButton" }
assert(loadfile(corePath))()
assert(loadfile(uiPath))()

assert(type(ShirsInventory_GetInventoryTitle) == "function",
  "player inventory title helper is missing")
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

assert(ShirsInventory_ResetInventoryFramePosition(), "position reset failed")
assert(ShirsInventory_GetInventoryFramePosition() == nil, "position reset left saved state")
print("INVENTORY_POSITION_TEST=PASS")
