local corePath, accountPath, uiPath = arg[1], arg[2], arg[3]
assert(loadfile(corePath))()
assert(loadfile(accountPath))()
if uiPath then assert(loadfile(uiPath))() end

assert(type(ShirsInventory_NormalizeCraftName) == "function",
  "craft-name normalizer is missing")
assert(type(ShirsInventory_RecipeItemCraftName) == "function",
  "recipe-item craft-name extractor is missing")

local function expect(actual, expected, label)
  assert(actual == expected, label .. ": got " .. tostring(actual) .. ", want " .. tostring(expected))
end

expect(ShirsInventory_NormalizeCraftName("Swiftness Potion"), "swiftness potion", "plain craft")
expect(ShirsInventory_NormalizeCraftName("  Copper Bracers  "), "copper bracers", "trim")
expect(ShirsInventory_NormalizeCraftName(nil), nil, "nil craft")
expect(ShirsInventory_NormalizeCraftName(""), nil, "empty craft")

expect(ShirsInventory_RecipeItemCraftName("Recipe: Swiftness Potion"), "swiftness potion", "Recipe")
expect(ShirsInventory_RecipeItemCraftName("Pattern: Runecloth Bag"), "runecloth bag", "Pattern")
expect(ShirsInventory_RecipeItemCraftName("Formula: Enchant Boots - Minor Stamina"), "enchant boots - minor stamina", "Formula")
expect(ShirsInventory_RecipeItemCraftName("Plans: Solid Iron Maul"), "solid iron maul", "Plans")
expect(ShirsInventory_RecipeItemCraftName("Schematic: EZ-Thro Dynamite"), "ez-thro dynamite", "Schematic")
expect(ShirsInventory_RecipeItemCraftName("Manual: Strong Anti-Venom"), "strong anti-venom", "Manual")
expect(ShirsInventory_RecipeItemCraftName("Recipe:Swiftness Potion"), "swiftness potion", "no space after colon")
expect(ShirsInventory_RecipeItemCraftName("Swiftness Potion"), nil, "plain item is not a recipe scroll")
expect(ShirsInventory_RecipeItemCraftName("Recipe:"), nil, "prefix only")
expect(ShirsInventory_RecipeItemCraftName(nil), nil, "nil recipe name")

ShirsInventoryAccountDB = nil
assert(type(ShirsInventory_AccountRememberKnownCraft) == "function",
  "account craft remember is missing")
assert(type(ShirsInventory_AccountKnowsCraftName) == "function",
  "account craft lookup is missing")

assert(ShirsInventory_AccountRememberKnownCraft("Swiftness Potion") == true,
  "remembering a craft name must succeed")
assert(ShirsInventory_AccountKnowsCraftName("Swiftness Potion") == true,
  "remembered craft must match the same name")
assert(ShirsInventory_AccountKnowsCraftName("  SWIFTNESS POTION ") == true,
  "lookup must use the same normalizer")
assert(ShirsInventory_AccountKnowsCraftName("Greater Healing Potion") == false,
  "unknown craft must stay unknown")
assert(ShirsInventory_AccountRememberKnownCraft("") == false, "empty name must be rejected")
assert(ShirsInventory_AccountRememberKnownCraft(nil) == false, "nil name must be rejected")
assert(type(ShirsInventory_AccountEnsureDB().knownCraftNames) == "table",
  "account DB must grow a knownCraftNames table")
assert(ShirsInventory_AccountEnsureDB().knownCraftNames["swiftness potion"] == true,
  "stored key must be the normalized craft name")
assert(ShirsInventory_AccountKnowsRecipe(6452) == false,
  "craft-name memory must not write recipe-scroll IDs")

function GetTradeSkillLine() return "Alchemy" end
function GetNumTradeSkills() return 3 end
function GetTradeSkillInfo(index)
  if index == 1 then return "Potions", "header" end
  if index == 2 then return "Swiftness Potion", "optimal" end
  return "Elixir of Fortitude", "trivial"
end
function GetTradeSkillNumReagents() return 0 end
function GetTradeSkillReagentItemLink() return nil end

ShirsInventoryDB = nil
ShirsInventoryAccountDB = nil
assert(type(ShirsInventory_LearnProfessionCrafts) == "function",
  "profession-book craft scanner is missing")
local added = ShirsInventory_LearnProfessionCrafts("TRADE_SKILL_SHOW")
assert(added == 2, "book scan must record two Alchemy crafts and skip the header")
assert(ShirsInventory_AccountKnowsCraftName("Swiftness Potion"), "first craft missing")
assert(ShirsInventory_AccountKnowsCraftName("Elixir of Fortitude"), "second craft missing")
assert(ShirsInventory_LearnProfessionCrafts("TRADE_SKILL_SHOW") == 0,
  "a second scan of the same book must not recount stored crafts")
assert(ShirsInventory_LearnProfessionCrafts("TRADE_SKILL_UPDATE") == 0,
  "an update event must reuse the trade-skill scan")

function GetCraftDisplaySkillLine() return "Enchanting" end
function GetNumCrafts() return 2 end
function GetCraftInfo(index)
  if index == 1 then return "Boot Enchants", nil, "header" end
  return "Enchant Boots - Minor Stamina", nil, "optimal"
end
function GetCraftNumReagents() return 0 end
function GetCraftReagentItemLink() return nil end
assert(ShirsInventory_LearnProfessionCrafts("CRAFT_SHOW") == 1,
  "Enchanting book must record the non-header craft")
assert(ShirsInventory_AccountKnowsCraftName("Enchant Boots - Minor Stamina"),
  "craft API name must be stored")
assert(ShirsInventory_LearnProfessionCrafts("CRAFT_UPDATE") == 0,
  "an update event must reuse the craft scan")

function GetCraftDisplaySkillLine() return "Beast Training" end
function GetNumCrafts() return 1 end
function GetCraftInfo() return "Growl", nil, "optimal" end
assert(ShirsInventory_LearnProfessionCrafts("CRAFT_SHOW") == 0,
  "Beast Training must not be stored as a profession book")
assert(not ShirsInventory_AccountKnowsCraftName("Growl"),
  "Beast Training leaked a craft name")

ShirsInventory_SetProfessionLearning(false)
function GetTradeSkillLine() return "Engineering" end
function GetNumTradeSkills() return 1 end
function GetTradeSkillInfo() return "Minor Healing Potion", "optimal" end
assert(ShirsInventory_LearnProfessionCrafts("TRADE_SKILL_SHOW") == 0,
  "disabled learning must not write crafts")
assert(not ShirsInventory_AccountKnowsCraftName("Minor Healing Potion"),
  "disabled learning leaked a craft")

ITEM_SPELL_KNOWN = "Already known"
ITEM_MIN_SKILL = "Requires %s (%d)"
ITEM_REQ_SKILL = "Requires %s"

ShirsInventory_SetProfessionLearning(true)
ShirsInventoryAccountDB = {
  version = 3,
  knownRecipes = {},
  knownCraftNames = { ["swiftness potion"] = true },
}

assert(ShirsInventory_ResolveRecipeLearnStatus(nil, 2555, "Recipe: Swiftness Potion") == "already_known",
  "a learnable scroll whose craft was seen in a book must show as known")
assert(ShirsInventory_ResolveRecipeLearnStatus("skill_too_low", 2555, "Recipe: Swiftness Potion") == "skill_too_low",
  "skill-too-low must stay orange even when the account knows the craft")
assert(ShirsInventory_ResolveRecipeLearnStatus(nil, 929, "Recipe: Healing Potion") == nil,
  "an unknown craft name must stay unmarked")
assert(ShirsInventory_ResolveRecipeLearnStatus("already_known", 6452, "Recipe: Poison") == "already_known",
  "local Already known must still win")
assert(ShirsInventory_ResolveRecipeLearnStatus(nil, 2555) == nil,
  "a learnable scroll without a name and without a stored recipe ID must stay unmarked")

-- Tooltip line model: account-known crafts get an explicit informational line.
assert(type(ShirsInventory_GetAccountKnownCraftTooltipLine) == "function",
  "account-known craft tooltip-line helper is missing")
local knownLine = ShirsInventory_GetAccountKnownCraftTooltipLine("Pattern: Swiftness Potion")
assert(knownLine and knownLine.text == "Already known on this account",
  "a scroll matching an account-known craft must produce the tooltip line")
assert(knownLine.r == 0.3 and knownLine.g == 0.8 and knownLine.b == 1,
  "the account-known craft line must use the account-info blue")
assert(not ShirsInventory_GetAccountKnownCraftTooltipLine("Pattern: Healing Potion"),
  "an unknown craft must not produce the tooltip line")
assert(not ShirsInventory_GetAccountKnownCraftTooltipLine(nil),
  "a missing name must not produce the tooltip line")
assert(not ShirsInventory_GetAccountKnownCraftTooltipLine("Swiftness Potion"),
  "a non-recipe item name must not produce the tooltip line")

-- Line placement: the account-known line must land directly under the
-- profession requirement line instead of at the tooltip's bottom.
local function makeLine(text)
  return { text = text }
end
local sampleLines = {
  makeLine("Pattern: Swiftness Potion"),
  makeLine("Requires Alchemy (50)"),
  makeLine("Use: Teaches you how to make a Swiftness Potion."),
}
local inserted = ShirsInventory_InsertKnownCraftIntoLines(sampleLines,
  "Pattern: Swiftness Potion")
assert(inserted and table.getn(inserted) == 4,
  "the inserted line list must grow by exactly one line")
assert(inserted[3].text == "Already known on this account",
  "the account-known line must sit directly under the requirement line")
assert(inserted[2].text == "Requires Alchemy (50)",
  "the requirement line must stay above it")
assert(inserted[4].text == "Use: Teaches you how to make a Swiftness Potion.",
  "later lines must follow unchanged")

local noRequirement = ShirsInventory_InsertKnownCraftIntoLines({
  makeLine("Pattern: Swiftness Potion"),
}, "Pattern: Swiftness Potion")
assert(noRequirement[2].text == "Already known on this account",
  "without a requirement line the mark falls back to the end")

assert(ShirsInventory_InsertKnownCraftIntoLines(sampleLines,
  "Pattern: Healing Potion") == nil,
  "an unknown craft must leave the original list untouched")
assert(ShirsInventory_InsertKnownCraftIntoLines(nil,
  "Pattern: Green Silk Armor") == nil,
  "missing lines must not crash placement")

print("PROFESSION_BOOK_RECIPES_TEST=PASS")
