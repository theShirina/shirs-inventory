local uiPath = arg[1]
assert(loadfile(uiPath))()

assert(type(ShirsInventory_GetRecipeLearnStatusFromLines) == "function",
  "recipe learn-status parser is missing")
assert(type(ShirsInventory_GetRecipeStatusVisual) == "function",
  "recipe status visual model is missing")
assert(type(ShirsInventory_GetItemVisualModel) == "function",
  "combined item visual model is missing")
assert(type(ShirsInventory_IsRequirementUnmetColor) == "function",
  "requirement-color helper is missing")

ITEM_SPELL_KNOWN = "Already known"
ITEM_MIN_SKILL = "Requires %s (%d)"
ITEM_REQ_SKILL = "Requires %s"

assert(ShirsInventory_IsRequirementUnmetColor(1, 0.125, 0.125),
  "Vanilla red requirement text must count as unmet")
assert(not ShirsInventory_IsRequirementUnmetColor(1, 0.82, 0),
  "gold tooltip text must not count as an unmet requirement")
assert(not ShirsInventory_IsRequirementUnmetColor(1, 1, 1),
  "white tooltip text must not count as an unmet requirement")

assert(ShirsInventory_GetRecipeLearnStatusFromLines({
  { text = "Recipe: Swiftness Potion" },
  { text = "Requires Alchemy (50)", r = 1, g = 0.82, b = 0 },
  { text = "Use: Teaches you how to make a Swiftness Potion." },
}) == nil, "a learnable recipe must stay unmarked")

assert(ShirsInventory_GetRecipeLearnStatusFromLines({
  { text = "Recipe: Greater Healing Potion" },
  { text = "Requires Alchemy (170)", r = 1, g = 0.125, b = 0.125 },
}) == "skill_too_low", "a red profession requirement must mark skill too low")

assert(ShirsInventory_GetRecipeLearnStatusFromLines({
  { text = "Recipe: Elixir of Fortitude" },
  { text = "Requires Alchemy (175)", r = 1, g = 0.82, b = 0 },
  { text = "Already known", r = 1, g = 0.125, b = 0.125 },
}) == "already_known", "Already known must win over a satisfied skill line")

assert(ShirsInventory_GetRecipeLearnStatusFromLines({
  { text = "Already known" },
  { text = "Requires Alchemy (1)", r = 1, g = 0.125, b = 0.125 },
}) == "already_known", "Already known must win when the skill line is also red")

assert(ShirsInventory_GetRecipeLearnStatusFromLines({
  { text = "Pattern: Runecloth Bag" },
  { text = "Requires Tailoring", r = 1, g = 0, b = 0 },
}) == "skill_too_low", "a red profession line without a number still means the recipe cannot be learned")

assert(ShirsInventory_GetRecipeLearnStatusFromLines(nil) == nil,
  "missing tooltip lines must not invent a recipe status")
assert(ShirsInventory_GetRecipeLearnStatusFromLines({}) == nil,
  "empty tooltip lines must not invent a recipe status")

local known = ShirsInventory_GetRecipeStatusVisual("already_known")
assert(known and known.kind == "recipeAlreadyKnown",
  "already-known recipes need their own visual kind")
assert(known.r == 0.05 and known.g == 0.55 and known.b == 1,
  "already-known edges must be bright blue, not teal that blends with uncommon green")
assert(known.fillR == 0.05 and known.fillG == 0.45 and known.fillB == 1 and known.fillA == 0.55,
  "already-known slots must tint the icon with a strong blue overlay")
assert(known.thickness == 3 and known.inset == 0,
  "blocked-recipe frames must be thicker than the one-pixel rarity edge")
assert(known.layer == "OVERLAY" and known.blend == "ADD",
  "the recipe wash must sit on the icon, not behind it")

local low = ShirsInventory_GetRecipeStatusVisual("skill_too_low")
assert(low and low.kind == "recipeSkillTooLow",
  "skill-too-low recipes need their own visual kind")
assert(low.r == 1 and low.g == 0.28 and low.b == 0,
  "skill-too-low edges must be bright orange")
assert(low.fillR == 1 and low.fillG == 0.28 and low.fillB == 0 and low.fillA == 0.52,
  "skill-too-low slots must tint the icon with a strong orange overlay")
assert(low.thickness == 3 and low.inset == 0,
  "skill-too-low frames must use the same thick geometry")
assert(low.layer == "OVERLAY" and low.blend == "ADD",
  "the skill-too-low wash must also sit on the icon")

assert(known.r ~= low.r or known.g ~= low.g or known.b ~= low.b,
  "the two blocked-recipe reasons must use different edge colors")
assert(known.fillR ~= low.fillR or known.fillG ~= low.fillG or known.fillB ~= low.fillB,
  "the two blocked-recipe reasons must use different background washes")
assert(not ShirsInventory_GetRecipeStatusVisual(nil),
  "learnable recipes must not receive a blocked-recipe wash")
assert(not ShirsInventory_GetRecipeStatusVisual("learnable"),
  "unknown recipe statuses must not invent a wash")

ITEM_QUALITY_COLORS = { [2] = { r = 0.12, g = 1, b = 0 } }
local knownVisual = ShirsInventory_GetItemVisualModel(
  "item", 2, "Recipe", true, "already_known")
assert(knownVisual and knownVisual.kind == "recipeAlreadyKnown" and knownVisual.fillA == 0.55,
  "already-known recipes must replace the rarity edge with the blue blocked look")

local lowVisual = ShirsInventory_GetItemVisualModel(
  "item", 1, "Recipe", true, "skill_too_low")
assert(lowVisual and lowVisual.kind == "recipeSkillTooLow" and lowVisual.fillA == 0.52,
  "skill-too-low recipes must show the orange blocked look")

local learnable = ShirsInventory_GetItemVisualModel("item", 2, "Recipe", true, nil)
assert(learnable and learnable.kind == "rarity" and not learnable.fillA,
  "a learnable uncommon recipe must keep its normal rarity border")

assert(not ShirsInventory_GetItemVisualModel("item", 1, "Miscellaneous", true, "already_known"),
  "non-recipe items must ignore a leftover recipe status")

assert(type(ShirsInventory_ResolveRecipeLearnStatus) == "function",
  "account-aware recipe resolver is missing")
assert(ShirsInventory_ResolveRecipeLearnStatus("already_known", 6452) == "already_known",
  "a locally known recipe must stay known")
assert(ShirsInventory_ResolveRecipeLearnStatus("skill_too_low", 6452) == "skill_too_low",
  "skill-too-low must stay orange even if another character already knows the recipe")
assert(ShirsInventory_ResolveRecipeLearnStatus(nil, 6452) == nil,
  "a learnable recipe with no account memory must stay unmarked")

local remembered = {}
function ShirsInventory_AccountRememberKnownRecipe(itemId)
  if type(itemId) ~= "number" or itemId <= 0 then return false end
  remembered[itemId] = true
  return true
end
function ShirsInventory_AccountKnowsRecipe(itemId)
  return remembered[itemId] and true or false
end
assert(ShirsInventory_ResolveRecipeLearnStatus("already_known", 6452) == "already_known" and remembered[6452],
  "seeing Already known must record the recipe on the account")
assert(ShirsInventory_ResolveRecipeLearnStatus(nil, 6452) == "already_known",
  "another character with the skill must inherit the account-known recipe")
assert(ShirsInventory_ResolveRecipeLearnStatus("skill_too_low", 6452) == "skill_too_low",
  "a character below the recipe skill must keep the orange mark")
assert(ShirsInventory_ResolveRecipeLearnStatus(nil, 929) == nil,
  "an unknown recipe ID must stay unmarked")
assert(ShirsInventory_ResolveRecipeLearnStatus("already_known", nil) == "already_known",
  "a known recipe without an item ID must still show as known")

print("RECIPE_LEARN_STATUS_TEST=PASS")
