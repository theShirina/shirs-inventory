-- Per-character recipe-glow toggle: disables ONLY the glowing visuals for
-- recipes you already know or cannot learn yet. Ordinary rarity borders,
-- quest borders, and learnable recipes stay unchanged.
local corePath, uiPath, settingsPath = arg[1], arg[2], arg[3]
ShirsInventoryDB = {}

assert(loadfile(corePath))()
assert(loadfile(uiPath))()

assert(type(ShirsInventory_GetShowRecipeGlow) == "function",
  "recipe-glow getter is missing")
assert(type(ShirsInventory_SetShowRecipeGlow) == "function",
  "recipe-glow setter is missing")
assert(type(ShirsInventory_GetItemVisualModel) == "function",
  "item visual model is missing")

-- Default is on (matches existing release behavior).
assert(ShirsInventory_GetShowRecipeGlow(),
  "recipe glow must default to on")

-- Turning it off must persist per character.
assert(ShirsInventory_SetShowRecipeGlow(false) == false,
  "recipe-glow toggle did not persist off")
assert(ShirsInventory_GetShowRecipeGlow() == false,
  "recipe-glow toggle did not report off")
assert(ShirsInventory_SetShowRecipeGlow(true) == true,
  "recipe-glow toggle did not restore on")

ITEM_QUALITY_COLORS = { [2] = { r = 0.12, g = 1, b = 0 } }

-- Toggle ON: both blocked recipe reasons get their glow visuals.
ShirsInventory_SetShowRecipeGlow(true)
local knownGlow = ShirsInventory_GetItemVisualModel("item", 2, "Recipe", true, "already_known")
assert(knownGlow and knownGlow.kind == "recipeAlreadyKnown",
  "already-known recipes must keep their glow while the toggle is on")
local lowGlow = ShirsInventory_GetItemVisualModel("item", 1, "Recipe", true, "skill_too_low")
assert(lowGlow and lowGlow.kind == "recipeSkillTooLow",
  "skill-too-low recipes must keep their glow while the toggle is on")

-- Toggle OFF: blocked recipes fall back to the ordinary border model, never
-- the glow wash. Uncommon recipes keep their rarity border.
ShirsInventory_SetShowRecipeGlow(false)
local knownPlain = ShirsInventory_GetItemVisualModel("item", 2, "Recipe", true, "already_known")
assert(knownPlain and knownPlain.kind == "rarity" and not knownPlain.fillA and not knownPlain.fillR,
  "already-known recipes must lose only the glow, keeping the rarity border")
local lowPlain = ShirsInventory_GetItemVisualModel("item", 2, "Recipe", true, "skill_too_low")
assert(lowPlain and lowPlain.kind == "rarity" and not lowPlain.fillA and not lowPlain.fillR,
  "skill-too-low recipes must lose only the glow, keeping the rarity border")
-- A common blocked recipe has no rarity color either; it returns to the
-- neutral slot edge instead of an invented glow.
local commonPlain = ShirsInventory_GetItemVisualModel("item", 1, "Recipe", true, "skill_too_low")
assert(not commonPlain,
  "common blocked recipes must return to the neutral slot edge with the glow off")

-- A learnable recipe never glows; it keeps its rarity border either way.
local learnableOff = ShirsInventory_GetItemVisualModel("item", 2, "Recipe", true, nil)
assert(learnableOff and learnableOff.kind == "rarity" and not learnableOff.fillA,
  "learnable recipes must keep the rarity border with the toggle off")
ShirsInventory_SetShowRecipeGlow(true)
local learnableOn = ShirsInventory_GetItemVisualModel("item", 2, "Recipe", true, nil)
assert(learnableOn and learnableOn.kind == "rarity" and not learnableOn.fillA,
  "learnable recipes must never receive a blocked-recipe glow")

-- Quest and rarity borders survive the toggle in both directions.
local quest = ShirsInventory_GetItemVisualModel("item", 1, "Quest", true, nil)
assert(quest and quest.kind == "quest",
  "quest border must remain visible with recipe glow on")
ShirsInventory_SetShowRecipeGlow(false)
local uncommon = ShirsInventory_GetItemVisualModel("item", 2, "Miscellaneous", true, nil)
assert(uncommon and uncommon.kind == "rarity",
  "rarity border must remain visible with recipe glow off")
assert(ShirsInventory_GetItemVisualModel("item", 1, "Quest", true, nil).kind == "quest",
  "quest border must remain visible with recipe glow off")

-- The option label must say it only affects blocked recipes.
if settingsPath then
  local settings = assert(io.open(settingsPath, "rb")):read("*a")
  assert(string.find(settings, "already know or can", 1, true) or
    string.find(settings, "can't learn", 1, true) or
    string.find(settings, "cannot learn", 1, true),
    "settings label must state the glow only covers known or unlearnable recipes")
end

-- The toggle is per character: a fresh DB keeps the default.
ShirsInventoryDB = {}
assert(ShirsInventory_GetShowRecipeGlow(),
  "per-character recipe glow must default to on for a fresh character")

print("RECIPE_GLOW_TOGGLE_TEST=PASS")
