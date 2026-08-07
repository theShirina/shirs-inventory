local uiPath, settingsPath = arg[1], arg[2]
local ui = assert(io.open(uiPath, "rb")):read("*a")
local settings = assert(io.open(settingsPath, "rb")):read("*a")
for _, needle in ipairs({
  'frame.sortButton = CreateFrame("Button", nil, frame)',
  'frame.modeButton = CreateFrame("Button", nil, frame)',
  'frame.directionButton = CreateFrame("Button", nil, frame)',
  'frame.settingsButton = CreateFrame("Button", nil, frame)',
}) do
  assert(string.find(ui, needle, 1, true), "full-suite actions must use plain Buttons without template state artwork")
end
for _, name in ipairs({
  "ShirsInventoryStandaloneSortButton",
  "ShirsInventoryStandaloneModeButton",
  "ShirsInventoryStandaloneDirectionButton",
  "ShirsInventoryStandaloneSettingsButton",
}) do
  local plain = 'CreateFrame("Button", "' .. name .. '", UIParent)'
  assert(string.find(settings, plain, 1, true), name .. " must use a plain Button without red template state artwork")
end
assert(loadfile(uiPath))()
assert(type(ShirsInventory_NeutralizeActionStateTextures) == "function",
  "action state-texture neutralizer is missing")
local states = {}
local function texture(name)
  return {
    SetVertexColor = function(self, r, g, b, a) states[name .. "Color"] = {r,g,b,a} end,
    SetAlpha = function(self, a) states[name .. "Alpha"] = a end,
  }
end
local button = {}
for _, name in ipairs({"Normal", "Pushed", "Highlight", "Disabled"}) do
  local stateName = name
  local tex = texture(stateName)
  button["Set" .. stateName .. "Texture"] = function(self, path) states[stateName .. "Path"] = path end
  button["Get" .. stateName .. "Texture"] = function(self) return tex end
end
ShirsInventory_NeutralizeActionStateTextures(button)
ShirsInventory_NeutralizeActionStateTextures(button)
for _, name in ipairs({"Normal", "Pushed", "Highlight", "Disabled"}) do
  assert(states[name .. "Path"] == "Interface\\Buttons\\WHITE8X8",
    name .. " state must use deterministic neutral artwork")
  assert(states[name .. "Alpha"] == 0 and states[name .. "Color"][4] == 0,
    name .. " state must stay transparent after repeated clicks/restyles")
end
print("ACTION_BUTTON_STATE_TEST=PASS")
