local corePath = arg[1]
assert(loadfile(corePath))()

ShirsInventoryDB = nil

local tradeName = "Blacksmithing"
function GetTradeSkillLine() return tradeName end
function GetNumTradeSkills() return 2 end
function GetTradeSkillInfo(index)
  if index == 1 then return "Armor", "header" end
  return "Copper Bracers", "optimal"
end
function GetTradeSkillNumReagents(index) return index == 2 and 2 or 0 end
function GetTradeSkillReagentItemLink(index, reagent)
  if reagent == 1 then return "|cffffffff|Hitem:900001:0:0:0|h[Custom Ore]|h|r" end
  return "|cffffffff|Hitem:900002:0:0:0|h[Custom Flux]|h|r"
end

local learned = ShirsInventory_LearnProfessionReagents("TRADE_SKILL_SHOW")
if learned ~= 2 then error("expected two newly learned Blacksmithing reagents") end
if ShirsInventory_GetMaterialCategory(900001, nil, nil) ~= "Mining" then error("Blacksmithing reagent was not learned as Mining") end
if ShirsInventory_GetLearnedReagentCount() ~= 2 then error("learned reagent count is wrong") end

tradeName = "Alchemy"
function GetNumTradeSkills() return 1 end
function GetTradeSkillInfo() return "Custom Potion", "optimal" end
function GetTradeSkillNumReagents() return 1 end
function GetTradeSkillReagentItemLink() return "|Hitem:900001:0:0:0|h[Shared Reagent]|h" end
if ShirsInventory_LearnProfessionReagents("TRADE_SKILL_SHOW") ~= 1 then error("shared profession association was not learned") end
if ShirsInventory_GetMaterialCategory(900001, nil, nil) ~= "Mining" then error("multi-profession selection is not deterministic by material rank") end

function GetCraftDisplaySkillLine() return "Enchanting" end
function GetNumCrafts() return 1 end
function GetCraftInfo() return "Enchant Boots", nil, "optimal" end
function GetCraftNumReagents() return 1 end
function GetCraftReagentItemLink() return "|Hitem:900003:0:0:0|h[Custom Dust]|h" end
if ShirsInventory_LearnProfessionReagents("CRAFT_SHOW") ~= 1 then error("Enchanting reagent was not learned") end
if ShirsInventory_GetMaterialCategory(900003, nil, nil) ~= "Enchanting" then error("Craft API reagent was not mapped to Enchanting") end

ShirsInventory_SetProfessionLearning(false)
tradeName = "Engineering"
function GetTradeSkillReagentItemLink() return "|Hitem:900004:0:0:0|h[Custom Part]|h" end
if ShirsInventory_LearnProfessionReagents("TRADE_SKILL_SHOW") ~= 0 then error("disabled learning still changed state") end
if ShirsInventory_GetMaterialCategory(900004, nil, nil) ~= nil then error("disabled learning stored a reagent") end

ShirsInventory_ResetLearnedReagents()
if ShirsInventory_GetLearnedReagentCount() ~= 0 then error("learned reagent reset failed") end

print("PROFESSION_LEARNING_TEST=PASS")
