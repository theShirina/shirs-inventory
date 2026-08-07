local corePath, uiPath = arg[1], arg[2]

ShirsInventoryDB = { useIconButtons = true }
assert(loadfile(corePath))()
assert(loadfile(uiPath))()

local function NewButton()
  return {
    ClearAllPoints = function(self) self.point = nil end,
    SetWidth = function(self, value) self.width = value end,
    SetHeight = function(self, value) self.height = value end,
    SetPoint = function(self, point, relative, relativePoint, x, y)
      assert(not (relative and relative.point and relative.point[2] == self),
        "layout created a temporary reciprocal anchor cycle")
      self.point = { point, relative, relativePoint, x, y }
    end,
  }
end

local frame = {
  sortButton = NewButton(),
  modeButton = NewButton(),
  directionButton = NewButton(),
  settingsButton = NewButton(),
  bagBarButtons = {NewButton(), NewButton(), NewButton(), NewButton(), NewButton()},
}
frame.sortButton.point = {"BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 13}
frame.modeButton.point = {"LEFT", frame.sortButton, "RIGHT", 4, 0}
frame.directionButton.point = {"LEFT", frame.modeButton, "RIGHT", 4, 0}
frame.settingsButton.point = {"LEFT", frame.directionButton, "RIGHT", 4, 0}

assert(type(ShirsInventory_LayoutInventoryControls) == "function",
  "bottom-toolbar layout helper is missing")
assert(type(ShirsInventory_InventoryUsesIconControls) == "function" and
  ShirsInventory_InventoryUsesIconControls(),
  "inventory controls must be permanently icon-only")
ShirsInventory_LayoutInventoryControls(frame)

local buttons = { frame.sortButton, frame.modeButton, frame.directionButton, frame.settingsButton }
local index
for index = 1, table.getn(buttons) do
  assert(buttons[index].width == 24 and buttons[index].height == 24,
    "icon-mode bottom controls must use equal compact dimensions")
end
assert(frame.settingsButton.point[1] == "TOPRIGHT" and frame.settingsButton.point[2] == frame and
  frame.settingsButton.point[3] == "TOPRIGHT" and frame.settingsButton.point[4] == -14 and
  frame.settingsButton.point[5] == -33,
  "Settings must anchor the action group at the inventory's right edge")
assert(frame.directionButton.point[1] == "RIGHT" and frame.directionButton.point[2] == frame.settingsButton and
  frame.directionButton.point[3] == "LEFT" and frame.directionButton.point[4] == -4,
  "direction must sit immediately left of Settings")
assert(frame.modeButton.point[2] == frame.directionButton and frame.sortButton.point[2] == frame.modeButton,
  "Sort, grouping, direction, and Settings must form one right-aligned chain")

assert(type(ShirsInventory_GetInventoryActionVisualModel) == "function",
  "inventory action visual model is missing")
local visual = ShirsInventory_GetInventoryActionVisualModel()
assert(visual.buttonSize == 24 and visual.iconSize == 18 and visual.hover,
  "inventory actions need equal 24px tiles, equal 18px artwork, and hover feedback")
assert(visual.hoverStyle == "blue-border" and visual.hoverColor[3] == 1,
  "hover feedback must use a neutral blue border rather than the red Blizzard square")
assert(visual.pressedStyle == "blue-border" and visual.pressedColor[3] == 1,
  "pressed feedback must replace the template's red tint with a blue border")
assert(type(ShirsInventory_GetInventoryButtonSpecs) == "function",
  "inventory tooltip specification is missing")
local specs = ShirsInventory_GetInventoryButtonSpecs()
assert(specs.direction.icon == "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up" or
  specs.direction.icon == "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up",
  "direction control must use transparent Vanilla chat-arrow artwork, not a full red scrollbar tile")
assert(specs.direction.texCoord[1] >= 0.20 and specs.direction.texCoord[2] <= 0.80 and
  specs.direction.texCoord[3] >= 0.20 and specs.direction.texCoord[4] <= 0.80,
  "direction artwork must crop its large transparent margins so the arrow matches peer glyph scale")
for _, name in ipairs({"sort", "mode", "direction", "settings"}) do
  assert(specs[name].iconSize == visual.iconSize,
    name .. " artwork must use the same explicit size as every other action glyph")
  assert(specs[name].tooltipTitle and string.len(specs[name].tooltipTitle) > 4,
    name .. " needs a useful tooltip title")
  assert(specs[name].tooltipDescription and string.len(specs[name].tooltipDescription) > 20,
    name .. " needs a useful tooltip description")
end

local renderedTitle
GameTooltip = {
  IsOwned = function() return true end,
  SetOwner = function() end,
  SetText = function(_, title) renderedTitle = title end,
  AddLine = function() end,
  Show = function() end,
}
local tooltipButton = {
  shirsTooltipTitle = "Grouping: Item Type",
  shirsTooltipDescription = "Current grouping description",
  shirsTooltipHint = "Click to switch.",
}
assert(type(ShirsInventory_RefreshOwnedActionTooltip) == "function" and
  ShirsInventory_RefreshOwnedActionTooltip(tooltipButton) and renderedTitle == "Grouping: Item Type",
  "owned action tooltip must render its current state")
tooltipButton.shirsTooltipTitle = "Grouping: Rarity"
assert(ShirsInventory_RefreshOwnedActionTooltip(tooltipButton) and renderedTitle == "Grouping: Rarity",
  "owned tooltip must refresh immediately after a control changes")

ShirsInventory_SetUseIconButtons(false)
ShirsInventory_LayoutInventoryControls(frame)
assert(frame.sortButton.width == 24, "saved legacy text preference must not widen inventory Sort")
assert(frame.modeButton.width == 24, "saved legacy text preference must not widen inventory mode")
assert(frame.directionButton.width == 24, "saved legacy text preference must not widen inventory direction")
assert(frame.settingsButton.width == 24, "saved legacy text preference must not widen inventory Settings")
assert(frame.settingsButton.point[1] == "TOPRIGHT" and frame.settingsButton.point[2] == frame,
  "legacy preference must not move the right-aligned inventory controls")

print("ICON_BUTTON_LAYOUT_TEST=PASS")
