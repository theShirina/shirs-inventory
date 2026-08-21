-- Bounded adjustable background opacity and validated adjustable FrameStrata
-- for the inventory and bank frames, applied live to both.
local corePath, uiPath, settingsPath = arg[1], arg[2], arg[3]
ShirsInventoryDB = {}

local appliedStrata = {}
local appliedAlpha = {}
local function NewFrame(name)
  return {
    name = name,
    SetFrameStrata = function(_, value) appliedStrata[name] = value end,
    SetBackdropColor = function(_, r, g, b, a) appliedAlpha[name] = a end,
    SetScale = function() end,
  }
end
ShirsInventoryFrame = NewFrame("ShirsInventoryFrame")
ShirsInventoryBankFrame = NewFrame("ShirsInventoryBankFrame")

assert(loadfile(corePath))()
assert(loadfile(uiPath))()

assert(type(ShirsInventory_GetBackgroundAlpha) == "function",
  "background alpha getter is missing")
assert(type(ShirsInventory_SetBackgroundAlpha) == "function",
  "background alpha setter is missing")
assert(type(ShirsInventory_GetFrameStrata) == "function",
  "frame strata getter is missing")
assert(type(ShirsInventory_SetFrameStrata) == "function",
  "frame strata setter is missing")
assert(type(ShirsInventory_ApplyAppearanceSettings) == "function",
  "live appearance applier is missing")

-- Defaults match the proven v0.8.1 frames.
assert(ShirsInventory_GetBackgroundAlpha() == 0.96,
  "background alpha must default to the proven 0.96")
assert(ShirsInventory_GetBackgroundAlpha() == 0.96 and ShirsInventoryDB.backgroundAlpha == 0.96,
  "repeated load validation must preserve the exact 0.96 default")
assert(ShirsInventory_GetFrameStrata() == "HIGH",
  "frame strata must default to HIGH")

ShirsInventoryDB.backgroundAlpha = "invalid"
ShirsInventoryDB.frameStrata = "FULLSCREEN"
assert(ShirsInventory_GetBackgroundAlpha() == 0.96,
  "malformed saved background alpha must repair to 0.96 on load")
assert(ShirsInventory_GetFrameStrata() == "HIGH",
  "malformed saved frame strata must repair to HIGH on load")
ShirsInventoryDB.backgroundAlpha = 0.96
assert(ShirsInventory_GetBackgroundAlpha() == 0.96 and ShirsInventoryDB.backgroundAlpha == 0.96,
  "persisted default alpha 0.96 must not round down to 0.95")

-- Alpha bounds: clamped to 0.20-1.00 and rounded to 0.05 steps.
local clamped = ShirsInventory_SetBackgroundAlpha(0.01)
assert(clamped == 0.20 and ShirsInventory_GetBackgroundAlpha() == 0.20,
  "alpha must clamp to the 0.20 floor")
clamped = ShirsInventory_SetBackgroundAlpha(2.5)
assert(clamped == 1 and ShirsInventory_GetBackgroundAlpha() == 1,
  "alpha must clamp to the 1.00 ceiling")
clamped = ShirsInventory_SetBackgroundAlpha(0.63)
assert(clamped == 0.65,
  "alpha must round to the nearest 0.05 step")
clamped = ShirsInventory_SetBackgroundAlpha("garbage")
assert(clamped == 0.96,
  "invalid alpha input must restore the safe default")

-- Strata validation: only the proven Vanilla strata names survive.
assert(ShirsInventory_SetFrameStrata("DIALOG") == "DIALOG",
  "DIALOG strata must be accepted")
assert(ShirsInventory_SetFrameStrata("TOOLTIP") == "TOOLTIP",
  "TOOLTIP strata must be accepted")
assert(ShirsInventory_SetFrameStrata("MEDIUM") == "MEDIUM",
  "MEDIUM strata must be accepted")
assert(ShirsInventory_SetFrameStrata("LOW") == "LOW",
  "LOW strata must be accepted")
assert(ShirsInventory_SetFrameStrata("HIGH") == "HIGH",
  "HIGH strata must be accepted")
assert(ShirsInventory_SetFrameStrata("FULLSCREEN") == "HIGH",
  "invalid strata must fail closed to HIGH")
assert(ShirsInventory_SetFrameStrata("BOGUS") == "HIGH",
  "unknown strata must fail closed to HIGH")

-- Live application reaches both frames together.
ShirsInventory_SetFrameStrata("TOOLTIP")
ShirsInventory_SetBackgroundAlpha(0.45)
assert(ShirsInventory_ApplyAppearanceSettings(),
  "live appearance application did not report success")
assert(appliedStrata.ShirsInventoryFrame == "TOOLTIP",
  "inventory frame did not receive the applied strata")
assert(appliedStrata.ShirsInventoryBankFrame == "TOOLTIP",
  "bank frame did not receive the applied strata")
assert(appliedAlpha.ShirsInventoryFrame == 0.45,
  "inventory frame did not receive the applied alpha")
assert(appliedAlpha.ShirsInventoryBankFrame == 0.45,
  "bank frame did not receive the applied alpha")

-- Persisted values survive a fresh DB (per character) only with new defaults;
-- the setter path is what stores the chosen values.
ShirsInventoryDB = {}
assert(ShirsInventory_GetBackgroundAlpha() == 0.96 and ShirsInventory_GetFrameStrata() == "HIGH",
  "fresh per-character defaults must be 0.96 and HIGH")

-- The settings panel must expose both appearance controls and reapply live.
if settingsPath then
  local settings = assert(io.open(settingsPath, "rb")):read("*a")
  assert(string.find(settings, "backgroundAlphaSlider", 1, true) and
    string.find(settings, "SetMinMaxValues(0.2, 1)", 1, true) and
    string.find(settings, "SetValueStep(0.05)", 1, true),
    "settings must expose a bounded 0.20-1.00 background-opacity slider")
  assert(string.find(settings, "ShirsInventory_SetBackgroundAlpha", 1, true) and
    string.find(settings, "ShirsInventory_ApplyAppearanceSettings", 1, true),
    "the opacity slider must persist and reapply appearance live")
  assert(string.find(settings, "frameStrataButton", 1, true) and
    string.find(settings, "Frame layer", 1, true) and
    string.find(settings, "ShirsInventory_SetFrameStrata", 1, true),
    "settings must expose a validated frame-layer control")
end

print("FRAME_APPEARANCE_TEST=PASS")
