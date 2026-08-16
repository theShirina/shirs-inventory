local corePath, uiPath, settingsPath = arg[1], arg[2], arg[3]
local settings = assert(io.open(settingsPath, "rb")):read("*a")

ShirsInventoryDB = {}
assert(loadfile(corePath))()
assert(loadfile(uiPath))()
assert(loadfile(settingsPath))()

assert(type(ShirsInventory_GetCategoryMode) == "function" and
  type(ShirsInventory_SetCategoryMode) == "function",
  "category-view setting API is missing")
assert(not ShirsInventory_GetCategoryMode(),
  "category view must default off")
assert(ShirsInventory_SetCategoryMode(true) and ShirsInventory_GetCategoryMode(),
  "category view did not persist on")
assert(not ShirsInventory_SetCategoryMode(false) and not ShirsInventory_GetCategoryMode(),
  "category view did not persist off")
ShirsInventoryDB.categoryMode = "invalid"
assert(not ShirsInventory_GetCategoryMode() and ShirsInventoryDB.categoryMode == false,
  "invalid saved category-view values must repair to off")
assert(type(ShirsInventory_GetCollapseEmptySlots) == "function" and
  type(ShirsInventory_SetCollapseEmptySlots) == "function",
  "collapsed Empty Slots setting API is missing")
assert(not ShirsInventory_GetCollapseEmptySlots(),
  "Empty Slots must default to showing every real empty slot")
assert(ShirsInventory_SetCollapseEmptySlots(true) and ShirsInventory_GetCollapseEmptySlots(),
  "collapsed Empty Slots setting did not persist on")
assert(not ShirsInventory_SetCollapseEmptySlots(false) and not ShirsInventory_GetCollapseEmptySlots(),
  "collapsed Empty Slots setting did not persist off")
ShirsInventoryDB.collapseEmptySlots = "invalid"
assert(not ShirsInventory_GetCollapseEmptySlots() and ShirsInventoryDB.collapseEmptySlots == false,
  "invalid collapsed Empty Slots values must repair to off")
assert(type(ShirsInventory_GetCategorySettingsPosition) == "function" and
  type(ShirsInventory_SaveCategorySettingsFrameCoordinates) == "function" and
  type(ShirsInventory_SaveCategorySettingsFramePosition) == "function",
  "Category Settings position API is missing")
assert(ShirsInventory_GetCategorySettingsPosition() == nil,
  "Category Settings must use its default position before the user moves it")
assert(ShirsInventory_SaveCategorySettingsFrameCoordinates("TOPLEFT", "BOTTOMLEFT", 321, 654),
  "Category Settings coordinates did not save")
local savedCategorySettingsPosition = ShirsInventory_GetCategorySettingsPosition()
assert(savedCategorySettingsPosition.point == "TOPLEFT" and
  savedCategorySettingsPosition.relativePoint == "BOTTOMLEFT" and
  savedCategorySettingsPosition.x == 321 and savedCategorySettingsPosition.y == 654,
  "Category Settings coordinates did not persist per character")
assert(not ShirsInventory_SaveCategorySettingsFrameCoordinates("CENTER", "CENTER", 10, 20),
  "Category Settings accepted noncanonical anchors")
assert(not ShirsInventory_SaveCategorySettingsFrameCoordinates(
  "TOPLEFT", "BOTTOMLEFT", 1 / 0, 20
), "Category Settings accepted a non-finite coordinate")
ShirsInventoryDB.categorySettingsPosition = {
  point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 1 / 0, y = 0 / 0,
}
assert(ShirsInventory_GetCategorySettingsPosition() == nil and
  ShirsInventoryDB.categorySettingsPosition == nil,
  "non-finite Category Settings coordinates did not fail closed")
ShirsInventoryDB.categorySettingsPosition = { point = false, x = "bad", y = 4 }
assert(ShirsInventory_GetCategorySettingsPosition() == nil and
  ShirsInventoryDB.categorySettingsPosition == nil,
  "malformed Category Settings coordinates did not fail closed")
assert(type(ShirsInventory_GetCategoryAssignment) == "function" and
  type(ShirsInventory_SetCategoryAssignment) == "function" and
  type(ShirsInventory_ClearCategoryAssignment) == "function",
  "manual category-assignment APIs are missing")
assert(ShirsInventory_GetCategoryAssignment(12361) == nil,
  "manual category assignments did not start empty")
assert(ShirsInventory_SetCategoryAssignment(12361, "equipment") == "equipment" and
  ShirsInventory_GetCategoryAssignment(12361) == "equipment",
  "manual category assignment did not persist by item ID")
assert(ShirsInventory_SetCategoryAssignment(12361, "mountsCompanions") == "mountsCompanions" and
  ShirsInventory_SetCategoryAssignment(12361, "weaponBuffs") == "weaponBuffs" and
  ShirsInventory_SetCategoryAssignment(12361, "equipment") == "equipment",
  "manual category assignment did not accept the broader built-in targets")
assert(not ShirsInventory_SetCategoryAssignment(12361, "empty") and
  ShirsInventory_GetCategoryAssignment(12361) == "equipment",
  "manual category assignment accepted the non-item Empty Slots group")
assert(ShirsInventory_ClearCategoryAssignment(12361) and
  ShirsInventory_GetCategoryAssignment(12361) == nil,
  "manual category assignment did not return to automatic classification")
assert(type(ShirsInventory_CreateCustomCategory) == "function" and
  type(ShirsInventory_DeleteCustomCategory) == "function" and
  type(ShirsInventory_GetCustomCategories) == "function",
  "custom category model APIs are missing")
ShirsInventoryDB.customCategories = {
  { key = "custom:1", label = "  Engineering  " },
  { key = "custom:1", label = "Duplicate key" },
  { key = "custom:2", label = "engineering" },
  { key = "empty", label = "Reserved" },
  { key = "custom:3", label = string.rep("x", 29) },
  { key = "custom:" .. string.rep("9", 400), label = "Oversized ID" },
  "invalid",
}
ShirsInventoryDB.nextCustomCategoryID = "invalid"
local repairedCustomCategories = ShirsInventory_GetCustomCategories()
assert(table.getn(repairedCustomCategories) == 1 and
  repairedCustomCategories[1].key == "custom:1" and repairedCustomCategories[1].label == "Engineering",
  "malformed, duplicate, reserved, or overlong custom categories were not repaired")
local repairedSecondKey = ShirsInventory_CreateCustomCategory("Second")
assert(repairedSecondKey == "custom:2", "repaired custom-category sequence did not resume safely")
assert(ShirsInventory_DeleteCustomCategory("custom:1") and
  ShirsInventory_DeleteCustomCategory(repairedSecondKey),
  "repaired custom categories could not be deleted")
local malformedNextIDs = { 1 / 0, 0 / 0, 1e20 }
local malformedIndex
for malformedIndex = 1, table.getn(malformedNextIDs) do
  ShirsInventoryDB.customCategories = {}
  ShirsInventoryDB.nextCustomCategoryID = malformedNextIDs[malformedIndex]
  local safeKey = ShirsInventory_CreateCustomCategory("Safe " .. malformedIndex)
  local safeCategories = ShirsInventory_GetCustomCategories()
  assert(safeKey == "custom:1" and table.getn(safeCategories) == 1 and
    safeCategories[1].key == "custom:1",
    "malformed numeric custom-category sequence did not repair to a stable bounded key: " ..
      tostring(malformedIndex) .. "/" .. tostring(safeKey) .. "/" .. tostring(table.getn(safeCategories)))
end
ShirsInventoryDB.customCategories = {}
ShirsInventoryDB.nextCustomCategoryID = 1
local customCategoryKey = ShirsInventory_CreateCustomCategory("Engineering Supplies")
local customCategories = ShirsInventory_GetCustomCategories()
assert(customCategoryKey == "custom:1" and table.getn(customCategories) == 1 and
  customCategories[1].key == customCategoryKey and customCategories[1].label == "Engineering Supplies",
  "custom category creation did not preserve its key, name, and display order")
assert(not ShirsInventory_CreateCustomCategory(" engineering supplies ") and
  not ShirsInventory_CreateCustomCategory("   ") and
  not ShirsInventory_CreateCustomCategory("Bad\nName") and
  not ShirsInventory_CreateCustomCategory("|cffff0000Spoofed|r"),
  "custom categories accepted a duplicate, blank, control character, or WoW markup name")
assert(ShirsInventory_SetCategoryAssignment(12361, customCategoryKey) == customCategoryKey,
  "manual category assignment rejected a valid custom category")
local customDefinitions = ShirsInventory_GetCategoryDefinitions()
assert(customDefinitions[table.getn(customDefinitions) - 1].key == customCategoryKey and
  customDefinitions[table.getn(customDefinitions)].key == "empty",
  "custom category was not placed immediately before Empty Slots")
local emptyCustomGroups = ShirsInventory_BuildCategoryGroups({})
assert(table.getn(emptyCustomGroups) == 1 and emptyCustomGroups[1].key == customCategoryKey and
  table.getn(emptyCustomGroups[1].items) == 0,
  "new empty custom category did not remain visible as an item-drop target")
assert(ShirsInventory_DeleteCustomCategory(customCategoryKey) and
  ShirsInventory_GetCategoryAssignment(12361) == nil and
  table.getn(ShirsInventory_GetCustomCategories()) == 0,
  "deleting a custom category did not remove it and restore assigned items to automatic placement")
assert(type(ShirsInventory_GetCategorySettingsSnapshot) == "function" and
  type(ShirsInventory_ApplyCategorySettingsSnapshot) == "function",
  "category settings snapshot APIs are missing")
local importedCategorySnapshot = {
  version = 1,
  customCategories = { { key = "custom:7", label = "Imported supplies" } },
  nextCustomCategoryID = 8,
  categoryAssignments = {
    [51001] = "custom:7",
    [51002] = "potions",
    [51003] = "empty",
    [51004.5] = "weapons",
    [1e309] = "armor",
    ["999999999999999999999"] = "junk",
  },
  collapseEmptySlots = true,
}
assert(ShirsInventory_ApplyCategorySettingsSnapshot(importedCategorySnapshot),
  "valid same-account category settings snapshot was rejected")
local appliedSnapshot = ShirsInventory_GetCategorySettingsSnapshot()
assert(appliedSnapshot.version == 1 and appliedSnapshot.collapseEmptySlots and
  table.getn(appliedSnapshot.customCategories) == 1 and
  appliedSnapshot.customCategories[1].key == "custom:7" and
  appliedSnapshot.customCategories[1].label == "Imported supplies" and
  appliedSnapshot.categoryAssignments[51001] == "custom:7" and
  appliedSnapshot.categoryAssignments[51002] == "potions" and
  appliedSnapshot.categoryAssignments[51003] == nil and
  appliedSnapshot.categoryAssignments[51004.5] == nil and
  appliedSnapshot.categoryAssignments[1e309] == nil and
  appliedSnapshot.categoryAssignments["999999999999999999999"] == nil,
  "category settings snapshot did not import custom categories, valid assignments, and display choice safely")
appliedSnapshot.customCategories[1].label = "Mutated copy"
appliedSnapshot.categoryAssignments[51001] = nil
assert(ShirsInventory_GetCustomCategoryLabel("custom:7") == "Imported supplies" and
  ShirsInventory_GetCategoryAssignment(51001) == "custom:7",
  "category settings snapshot getter leaked mutable SavedVariable references")
local beforeRejectedImport = ShirsInventory_GetCategorySettingsSnapshot()
assert(not ShirsInventory_ApplyCategorySettingsSnapshot({
  version = 1, customCategories = "bad", categoryAssignments = {}, collapseEmptySlots = false,
}) and ShirsInventory_GetCustomCategoryLabel("custom:7") == "Imported supplies" and
  ShirsInventory_GetCollapseEmptySlots(),
  "malformed category settings import overwrote the current character")
ShirsInventoryDB.customCategories = {}
ShirsInventoryDB.categoryAssignments = {}
ShirsInventoryDB.nextCustomCategoryID = 1
ShirsInventory_SetCollapseEmptySlots(false)
assert(type(ShirsInventory_GetCategoryEditMode) == "function" and
  type(ShirsInventory_SetCategoryEditMode) == "function" and
  type(ShirsInventory_BeginCategoryEditDrag) == "function" and
  type(ShirsInventory_SetCategoryEditHover) == "function" and
  type(ShirsInventory_FinishCategoryEditDrag) == "function",
  "category edit-mode virtual-drag APIs are missing")
ShirsInventory_SetCategoryMode(true)
assert(ShirsInventory_SetCategoryEditMode(true) and ShirsInventory_GetCategoryEditMode(),
  "category edit mode did not turn on inside category view")
assert(ShirsInventory_BeginCategoryEditDrag(12361) and
  ShirsInventory_SetCategoryEditHover("equipment") and
  ShirsInventory_FinishCategoryEditDrag() == "equipment" and
  ShirsInventory_GetCategoryAssignment(12361) == "equipment",
  "virtual category drag did not assign the item ID to the hovered category")
local scaledCategoryHeader = { categoryKey = "quest" }
function scaledCategoryHeader:IsShown() return true end
function scaledCategoryHeader:GetLeft() return 100 end
function scaledCategoryHeader:GetRight() return 200 end
function scaledCategoryHeader:GetBottom() return 80 end
function scaledCategoryHeader:GetTop() return 120 end
function scaledCategoryHeader:GetEffectiveScale() return 0.5 end
assert(ShirsInventory_GetCategoryEditDropTarget({scaledCategoryHeader}, 75, 50) == "quest" and
  ShirsInventory_GetCategoryEditDropTarget({scaledCategoryHeader}, 30, 20) == nil,
  "scaled cursor hit-testing did not resolve a category-heading drag target")
local savedGetCursorPosition = GetCursorPosition
GetCursorPosition = function() return 0, 0 end
local noHeaderLookupOk, noHeaderLookupResult = pcall(ShirsInventory_GetCategoryEditDropTarget)
GetCursorPosition = savedGetCursorPosition
assert(noHeaderLookupOk and noHeaderLookupResult == nil,
  "real no-argument category drop lookup crashed before category headers existed")
assert(ShirsInventory_BeginCategoryEditDrag(12361) and
  not ShirsInventory_SetCategoryEditHover("empty") and
  not ShirsInventory_FinishCategoryEditDrag() and
  ShirsInventory_GetCategoryAssignment(12361) == "equipment",
  "virtual category drag accepted Empty Slots or changed the saved assignment")
ShirsInventory_ClearCategoryAssignment(12361)
ShirsInventory_SetCategoryEditMode(false)
ShirsInventory_SetCategoryMode(false)

assert(type(ShirsInventory_ClassifyCategoryItem) == "function" and
  type(ShirsInventory_BuildCategoryGroups) == "function",
  "category-view model API is missing")
local categoryItems = {
  { bag = 0, slot = 1, hasItem = true, itemType = "Quest", name = "Quest Relic" },
  { bag = 0, slot = 2, hasItem = true, itemType = "Key", name = "Dungeon Key" },
  { bag = 0, slot = 3, hasItem = true, itemType = "Miscellaneous", quality = 0,
    name = "Swift Steed", tooltipText = "Use: Summons and dismisses a rideable mount." },
  { bag = 0, slot = 4, hasItem = true, itemType = "Armor", name = "Cloth Robe" },
  { bag = 0, slot = 5, hasItem = true, itemType = "Weapon", name = "Steel Sword" },
  { bag = 0, slot = 6, hasItem = true, itemType = "Armor", name = "Old Manual Gear",
    manualCategory = "equipment" },
  { bag = 1, slot = 1, hasItem = true, itemType = "Container", name = "Traveler's Bag" },
  { bag = 1, slot = 2, hasItem = true, itemType = "Projectile", name = "Sharp Arrow" },
  { bag = 1, slot = 3, hasItem = true, itemType = "Recipe", name = "Recipe: Soup" },
  { bag = 1, slot = 4, hasItem = true, itemType = "Consumable", name = "Roasted Boar",
    tooltipText = "Must remain seated while eating." },
  { bag = 1, slot = 5, hasItem = true, itemType = "Consumable", name = "Major Healing Potion" },
  { bag = 1, slot = 6, hasItem = true, itemType = "Consumable", name = "Elixir of Wisdom" },
  { bag = 2, slot = 1, hasItem = true, itemType = "Consumable", name = "Heavy Runecloth Bandage" },
  { bag = 2, slot = 2, hasItem = true, itemType = "Consumable", name = "Scroll of Strength" },
  { bag = 2, slot = 3, hasItem = true, itemType = "Trade Goods", name = "Dense Sharpening Stone" },
  { bag = 2, slot = 4, hasItem = true, itemType = "Consumable", name = "Mysterious Tonic" },
  { bag = 2, slot = 5, hasItem = true, itemType = "Trade Goods", itemSubType = "Explosives",
    name = "Thorium Grenade" },
  { bag = 2, slot = 6, hasItem = true, itemType = "Trade Goods",
    itemSubType = "Metal & Stone", materialCategory = "Mining", name = "Copper Ore" },
  { bag = 3, slot = 1, hasItem = true, quality = 0, itemType = "Miscellaneous", name = "Broken Buckle" },
  { bag = 3, slot = 2, hasItem = true, itemType = "Miscellaneous", name = "Odd Rock" },
  { bag = 3, slot = 3, hasItem = false },
}
local categoryGroups = ShirsInventory_BuildCategoryGroups(categoryItems)
local groupedCopies = ShirsInventory_BuildCategoryGroups({
  { bag = 0, slot = 1, hasItem = true, itemID = 100, itemType = "Miscellaneous" },
  { bag = 0, slot = 2, hasItem = true, itemID = 200, itemType = "Miscellaneous" },
  { bag = 0, slot = 3, hasItem = true, itemID = 100, itemType = "Miscellaneous" },
  { bag = 0, slot = 4, hasItem = true, itemID = 300, itemType = "Miscellaneous" },
  { bag = 0, slot = 5, hasItem = true, itemID = 200, itemType = "Miscellaneous" },
})
local groupedMisc = groupedCopies[1]
assert(groupedMisc.items[1].itemID == 100 and groupedMisc.items[2].itemID == 100 and
  groupedMisc.items[3].itemID == 200 and groupedMisc.items[4].itemID == 200 and
  groupedMisc.items[5].itemID == 300,
  "identical item types were not kept adjacent inside their visual category")
local emptySlotItems = {
  { bag = 0, slot = 6, hasItem = false },
  { bag = 1, slot = 2, hasItem = false },
  { bag = 3, slot = 9, hasItem = false },
}
ShirsInventory_SetCollapseEmptySlots(false)
local expandedEmptyGroup = ShirsInventory_BuildCategoryGroups(emptySlotItems)[1]
assert(expandedEmptyGroup.key == "empty" and table.getn(expandedEmptyGroup.items) == 3 and
  expandedEmptyGroup.totalCount == 3,
  "expanded Empty Slots did not retain every real empty slot")
local expandedEmptyLayout = ShirsInventory_BuildCategoryLayout({expandedEmptyGroup}, 10)
assert(expandedEmptyLayout.groups[1].label == "Empty Slots" and
  ShirsInventory_GetCategoryHeaderText(expandedEmptyLayout.groups[1]) == "Empty Slots (3)",
  "expanded Empty Slots heading was shortened even though it has normal width")
ShirsInventory_SetCollapseEmptySlots(true)
local collapsedEmptyGroup = ShirsInventory_BuildCategoryGroups(emptySlotItems)[1]
assert(collapsedEmptyGroup.key == "empty" and table.getn(collapsedEmptyGroup.items) == 1 and
  collapsedEmptyGroup.totalCount == 3 and collapsedEmptyGroup.items[1].collapsedEmptyCount == 3 and
  collapsedEmptyGroup.items[1].bag == 0 and collapsedEmptyGroup.items[1].slot == 6,
  "collapsed Empty Slots did not keep one real representative while preserving the total count")
assert(ShirsInventory_GetCategoryGroupCount(collapsedEmptyGroup) == 3,
  "collapsed Empty Slots render helper lost the heading total")
local collapsedFreeStates = ShirsInventory_BuildCategoryFreeStates(emptySlotItems)
assert(ShirsInventory_CountFreeInventorySlots(collapsedFreeStates) == 3,
  "collapsed Empty Slots lost the full footer free-slot total")
local collapsedEmptyLayout = ShirsInventory_BuildCategoryLayout({collapsedEmptyGroup}, 10)
assert(collapsedEmptyLayout.groups[1].totalCount == 3 and collapsedEmptyLayout.groups[1].rows == 1 and
  collapsedEmptyLayout.groups[1].columnX == 9 and collapsedEmptyLayout.groups[1].label == "Empty" and
  ShirsInventory_GetCategoryHeaderText(collapsedEmptyLayout.groups[1]) == "Empty",
  "collapsed Empty Slots layout lost its count, one-slot height, right alignment, or exact short heading")
assert(ShirsInventory_GetCategoryHeaderTooltipText and
  ShirsInventory_GetCategoryHeaderTooltipText(collapsedEmptyLayout.groups[1]) == "Empty Slots (3)",
  "collapsed Empty heading tooltip lost the full category name or true free-slot count")
assert(type(ShirsInventory_GetCategoryHeaderDisplayText) == "function" and
  type(ShirsInventory_GetCategoryHeaderTooltipText) == "function",
  "category headings are missing compact display and full tooltip models")
local narrowOtherLayout = ShirsInventory_BuildCategoryLayout({
  { key = "consumables", label = "Other Consumables", items = { {} } },
}, 10)
assert(ShirsInventory_GetCategoryHeaderDisplayText(narrowOtherLayout.groups[1]) == "Other" and
  ShirsInventory_GetCategoryHeaderTooltipText(narrowOtherLayout.groups[1]) == "Other Consumables (1)",
  "one-column Other Consumables heading was not shortened without losing its full tooltip")
local twoColumnOtherLayout = ShirsInventory_BuildCategoryLayout({
  { key = "consumables", label = "Other Consumables", items = { {}, {} } },
}, 10)
assert(ShirsInventory_GetCategoryHeaderDisplayText(twoColumnOtherLayout.groups[1]) == "Other Consumables (2)",
  "two-or-more item headings must keep the full category name")
local wideOtherLayout = ShirsInventory_BuildCategoryLayout({
  { key = "consumables", label = "Other Consumables", items = { {}, {}, {}, {}, {}, {}, {} } },
}, 10)
assert(ShirsInventory_GetCategoryHeaderDisplayText(wideOtherLayout.groups[1]) == "Other Consumables (7)",
  "wide category heading was shortened even though its full label fits")
local narrowCustomLayout = ShirsInventory_BuildCategoryLayout({
  { key = "custom:123", label = "Very Long Custom Category", custom = true, items = { {} } },
}, 10)
assert(ShirsInventory_GetCategoryHeaderDisplayText(narrowCustomLayout.groups[1]) == "Very" and
  ShirsInventory_GetCategoryHeaderTooltipText(narrowCustomLayout.groups[1]) == "Very Long Custom Category (1)",
  "one-item custom category must show the first word of its name, not a C-code")
local twoItemCustomLayout = ShirsInventory_BuildCategoryLayout({
  { key = "custom:123", label = "Very Long Custom Category", custom = true, items = { {}, {} } },
}, 10)
assert(ShirsInventory_GetCategoryHeaderDisplayText(twoItemCustomLayout.groups[1]) == "Very Long Custom Category (2)",
  "custom categories with two or more items must keep their full name")
local largeCustomLayout = ShirsInventory_BuildCategoryLayout({
  { key = "custom:99999", label = "Alpha Custom A", custom = true, items = { {} } },
  { key = "custom:999999", label = "Beta Custom B", custom = true, items = { {} } },
}, 10)
assert(ShirsInventory_GetCategoryHeaderDisplayText(largeCustomLayout.groups[1]) == "Alpha" and
  ShirsInventory_GetCategoryHeaderDisplayText(largeCustomLayout.groups[2]) == "Beta" and
  ShirsInventory_GetCategoryHeaderDisplayText(largeCustomLayout.groups[1]) ~=
    ShirsInventory_GetCategoryHeaderDisplayText(largeCustomLayout.groups[2]),
  "one-item custom categories must keep distinct first-word headings")
local rightAlignedEmptyLayout = ShirsInventory_BuildCategoryLayout({
  { key = "junk", label = "Junk", items = { {}, {} } },
  collapsedEmptyGroup,
}, 10)
assert(rightAlignedEmptyLayout.groups[1].columnX == 0 and
  rightAlignedEmptyLayout.groups[2].columnX == 9 and
  rightAlignedEmptyLayout.groups[1].labelY == rightAlignedEmptyLayout.groups[2].labelY,
  "single Empty Slots indicator did not use the right edge of its shared shelf")
ShirsInventory_SetCollapseEmptySlots(false)
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Consumable", quality = 1, manualCategory = "equipment"
}) == "equipment", "manual category assignment did not override automatic metadata")
ShirsInventoryDB.junkItems = { [4242] = true }
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemID = 4242, itemType = "Weapon", quality = 3
}) == "junk", "manually junk-marked items must classify as junk")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemID = 4242, itemType = "Consumable", quality = 2,
  name = "Major Healing Potion", tooltipText = "Must remain seated while drinking."
}) == "junk", "junk mark must win over semantic food-and-drink signals")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemID = 4242, itemType = "Quest", quest = true
}) == "junk", "junk mark must win over quest identity")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemID = 4242, itemType = "Weapon", quality = 3,
  manualCategory = "equipment"
}) == "equipment", "explicit manual category must still win over a junk mark")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemID = 4243, itemType = "Weapon", quality = 3
}) == "weapons", "unmarked items must keep their normal category")
ShirsInventoryDB.junkItems = nil
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemID = 4242, itemType = "Weapon", quality = 3
}) == "weapons", "clearing junk marks must restore normal classification")
local junkMarkedGroups = ShirsInventory_BuildCategoryGroups({
  { bag = 0, slot = 1, hasItem = true, itemID = 4242, itemType = "Weapon", quality = 3 },
  { bag = 0, slot = 2, hasItem = true, itemID = 4243, itemType = "Weapon", quality = 3 },
})
ShirsInventoryDB.junkItems = { [4242] = true }
junkMarkedGroups = ShirsInventory_BuildCategoryGroups({
  { bag = 0, slot = 1, hasItem = true, itemID = 4242, itemType = "Weapon", quality = 3 },
  { bag = 0, slot = 2, hasItem = true, itemID = 4243, itemType = "Weapon", quality = 3 },
})
local junkMarkedGroupIndex
for junkMarkedGroupIndex = 1, table.getn(junkMarkedGroups) do
  local group = junkMarkedGroups[junkMarkedGroupIndex]
  if group.key == "junk" then
    assert(table.getn(group.items) == 1 and group.items[1].itemID == 4242,
      "junk group must contain only the manually marked item")
  elseif group.key == "weapons" then
    assert(table.getn(group.items) == 1 and group.items[1].itemID == 4243,
      "weapons group must contain only the unmarked weapon")
  end
end
ShirsInventoryDB.junkItems = nil
assert(ShirsInventory_ClassifyCategoryItem({ hasItem = true, itemType = "Quest", quality = 0 }) == "quest",
  "quest identity must win over poor quality so quest items never appear as junk")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Recipe", quality = 1, tooltipText = "Quest Item"
}) == "recipes", "recipe metadata did not win over a quest-tooltip signal")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Miscellaneous", quality = 0,
  tooltipText = "Right Click to summon and dismiss your companion"
}) == "mountsCompanions", "companion tooltip did not win over gray-quality junk")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Consumable", name = "Potion Scroll"
}) == "potions", "deterministic consumable precedence did not put Potions before Scrolls")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Armor", name = "Potion Bandolier", quality = 2
}) == "armor", "consumable name signals overrode authoritative Armor metadata")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Weapon", name = "Elixir Blade", quality = 3
}) == "weapons", "consumable name signals overrode authoritative Weapon metadata")
GetLocale = function() return "deDE" end
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Consumable", name = "Healing Potion",
  tooltipText = "Must remain seated while eating."
}) == "consumables", "English semantic signals leaked into an unsupported client locale")
GetLocale = nil
GetAuctionItemClasses = function()
  return "Waffe", "Ruestung", "Behaelter", "Verbrauchbar", "Handwerkswaren",
    "Projektil", "Kocher", "Rezept", "Reagenz", "Verschiedenes"
end
assert(ShirsInventory_ClassifyCategoryItem({ hasItem = true, itemType = "Waffe", quality = 2 }) == "weapons" and
  ShirsInventory_ClassifyCategoryItem({ hasItem = true, itemType = "Ruestung", quality = 2 }) == "armor" and
  ShirsInventory_ClassifyCategoryItem({ hasItem = true, itemType = "Behaelter", quality = 1 }) == "bags" and
  ShirsInventory_ClassifyCategoryItem({ hasItem = true, itemType = "Projektil", quality = 1 }) == "ammo" and
  ShirsInventory_ClassifyCategoryItem({ hasItem = true, itemType = "Rezept", quality = 1 }) == "recipes" and
  ShirsInventory_ClassifyCategoryItem({ hasItem = true, itemType = "Verbrauchbar", quality = 1 }) == "consumables" and
  ShirsInventory_ClassifyCategoryItem({ hasItem = true, itemType = "Handwerkswaren", quality = 1 }) == "tradeGoods",
  "broader category classification must honor localized auction item classes")
ITEM_CLASS_QUEST = "Aufgabe"
assert(ShirsInventory_IsQuestItemType("Aufgabe") and
  ShirsInventory_ClassifyCategoryItem({ hasItem = true, itemType = "Aufgabe", quest = true, quality = 0 }) == "quest",
  "category classification must honor the localized quest-item constant")
ITEM_CLASS_QUEST = nil
assert(ShirsInventory_ClassifyCategoryItem({ hasItem = true, itemType = nil, quality = nil }) == "miscellaneous",
  "unavailable item metadata must fail safely into Miscellaneous")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", itemSubType = "Metal & Stone",
  materialCategory = "Mining", name = "Copper Ore"
}) == "mining", "mining materials must leave the generic Trade Goods group")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", itemSubType = "Enchanting",
  materialCategory = "Enchanting", name = "Strange Dust"
}) == "enchanting", "enchanting materials must leave the generic Trade Goods group")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", itemSubType = "Herb",
  materialCategory = "Herbs", name = "Peacebloom"
}) == "herbs", "herbs must leave the generic Trade Goods group")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", itemSubType = "Cloth",
  materialCategory = "Cloth", name = "Linen Cloth"
}) == "cloth", "cloth must leave the generic Trade Goods group")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", name = "Odd Trade Good"
}) == "tradeGoods", "unclassified trade goods must stay in Trade Goods")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", name = "Purple Lotus"
}) == "herbs", "herb names must split out of Trade Goods when subtype is missing")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", name = "Runecloth"
}) == "cloth", "cloth names must split out of Trade Goods when subtype is missing")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", name = "Light Leather"
}) == "leather", "leather names must split out of Trade Goods when subtype is missing")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", name = "Strange Dust"
}) == "enchanting", "enchanting dust names must split out of Trade Goods when subtype is missing")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", name = "Greater Magic Essence"
}) == "enchanting", "essence names must split out of Trade Goods when subtype is missing")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", name = "Copper Ore"
}) == "mining", "ore names must split out of Trade Goods when subtype is missing")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", name = "Tigerseye"
}) == "gems", "gem names must split out of Trade Goods when subtype is missing")
assert(ShirsInventory_ClassifyCategoryItem({
  hasItem = true, itemType = "Trade Goods", name = "Elemental Fire"
}) == "elemental", "elemental names must split out of Trade Goods when subtype is missing")
local expectedKeys = {
  "quest", "keys", "mountsCompanions", "armor", "weapons", "equipment", "bags", "ammo",
  "recipes", "foodDrink", "potions", "elixirs", "bandages", "scrolls", "weaponBuffs",
  "consumables", "explosives", "mining", "junk", "miscellaneous", "empty",
}
assert(table.getn(categoryGroups) == table.getn(expectedKeys),
  "broader category view must expose each non-empty fixed group exactly once")
local groupIndex
for groupIndex = 1, table.getn(expectedKeys) do
  assert(categoryGroups[groupIndex].key == expectedKeys[groupIndex],
    "broader category groups are not in the fixed display order")
  assert(table.getn(categoryGroups[groupIndex].items) == 1,
    "broader category group lost or duplicated an item")
end
assert(categoryGroups[1].items[1].bag == 0 and categoryGroups[1].items[1].slot == 1 and
  categoryGroups[19].items[1].bag == 3 and categoryGroups[19].items[1].slot == 1,
  "broader category view must preserve each item's real bag and slot address")
assert(type(ShirsInventory_BuildCategoryLayout) == "function" and
  type(ShirsInventory_ShouldShowInventoryAction) == "function",
  "category-view layout and control APIs are missing")
local categoryLayout = ShirsInventory_BuildCategoryLayout(categoryGroups, 10)
assert(categoryLayout.columns == 10 and categoryLayout.width == 428,
  "category view must retain the selected inventory width")
assert(table.getn(categoryLayout.groups) == 21 and categoryLayout.groups[1].label == "Quest Items" and
  categoryLayout.groups[3].label == "Mounts & Companions" and
  categoryLayout.groups[16].label == "Other Consumables",
  "category layout did not retain the broader fixed group labels")
assert(categoryLayout.groups[1].items[1].bag == 0 and categoryLayout.groups[1].items[1].slot == 1,
  "category layout lost the real slot address")
assert(categoryLayout.groups[1].columnX == 0 and categoryLayout.groups[2].columnX == 2 and
  categoryLayout.groups[5].columnX == 8 and categoryLayout.groups[6].columnX == 0 and
  categoryLayout.groups[1].labelY == categoryLayout.groups[5].labelY and
  categoryLayout.groups[6].labelY > categoryLayout.groups[5].labelY,
  "small category groups did not retain one blank item-space separator while shelf packing")
local packedCategoryLayout = ShirsInventory_BuildCategoryLayout({
  { key = "potions", label = "Potions", items = { {}, {} } },
  { key = "elixirs", label = "Elixirs & Buffs", items = { {}, {} } },
  { key = "consumables", label = "Other Consumables", items = { {}, {}, {}, {}, {}, {}, {} } },
  { key = "tradeGoods", label = "Trade Goods & Materials", items = {
    {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {},
  } },
}, 10)
assert(packedCategoryLayout.groups[1].columnX == 0 and packedCategoryLayout.groups[1].columns == 2 and
  packedCategoryLayout.groups[2].columnX == 3 and packedCategoryLayout.groups[2].columns == 2 and
  packedCategoryLayout.groups[1].labelY == packedCategoryLayout.groups[2].labelY,
  "two small categories did not share a shelf with one blank item-space between them")
assert(packedCategoryLayout.groups[3].columnX == 0 and
  packedCategoryLayout.groups[3].labelY > packedCategoryLayout.groups[2].labelY,
  "a category that did not fit was not moved intact to the next shelf")
assert(packedCategoryLayout.groups[4].columns == 10 and packedCategoryLayout.groups[4].rows == 2 and
  packedCategoryLayout.groups[4].labelY > packedCategoryLayout.groups[3].labelY,
  "a large category did not span the available width and wrap within its own group")
assert(packedCategoryLayout.height == 238,
  "packed category shelf height did not use the tallest group in each shelf exactly once")
ShirsInventory_SetCategoryMode(true)
assert(ShirsInventory_ShouldShowInventoryAction("sort", false) and
  ShirsInventory_ShouldShowInventoryAction("mode", false) and
  ShirsInventory_ShouldShowInventoryAction("direction", false) and
  ShirsInventory_ShouldShowInventoryAction("settings", false),
  "category view must keep Sort/Manage, Edit, Empty Slots, and Settings")
local categoryActionSpecs = ShirsInventory_GetInventoryButtonSpecs(false)
assert(categoryActionSpecs.sort.text == "Manage" and
  categoryActionSpecs.sort.tooltipTitle == "Category settings" and
  string.find(categoryActionSpecs.sort.tooltipDescription or "", "create", 1, true),
  "category view did not present its Categories replacement as a settings manager")
assert(categoryActionSpecs.direction.text == "Hide Empty" and
  categoryActionSpecs.direction.tooltipTitle == "Empty Slots: shown",
  "category view must reuse the unused direction button as Empty Slots")
ShirsInventory_SetCollapseEmptySlots(true)
local collapsedEmptySpecs = ShirsInventory_GetInventoryButtonSpecs(false)
assert(collapsedEmptySpecs.direction.text == "Show Empty" and
  collapsedEmptySpecs.direction.tooltipTitle == "Empty Slots: collapsed",
  "the Empty Slots button must show the current collapsed state")
local emptyToggles = 0
local savedSetCollapseEmptySlots = ShirsInventory_SetCollapseEmptySlots
ShirsInventory_SetCollapseEmptySlots = function(enabled)
  emptyToggles = emptyToggles + 1
  return savedSetCollapseEmptySlots(enabled)
end
assert(ShirsInventory_OnDirectionButtonClick and ShirsInventory_OnDirectionButtonClick(false)
  and emptyToggles == 1 and not ShirsInventory_GetCollapseEmptySlots(),
  "category-view Empty Slots button must toggle collapse instead of sort direction")
ShirsInventory_SetCollapseEmptySlots = savedSetCollapseEmptySlots
ShirsInventory_SetCollapseEmptySlots(false)
local categoryManagerOpens, physicalSorts = 0, 0
local savedToggleCategoryManager = ShirsInventory_ToggleCategoryManager
local savedSortBags = ShirsInventory_SortBags
ShirsInventory_ToggleCategoryManager = function() categoryManagerOpens = categoryManagerOpens + 1 return true end
ShirsInventory_SortBags = function() physicalSorts = physicalSorts + 1 return true end
assert(ShirsInventory_OnSortButtonClick(false) and categoryManagerOpens == 1 and physicalSorts == 0,
  "Categories button invoked physical sorting instead of the custom-category manager")
assert(ShirsInventory_ShouldShowInventoryAction("sort", true),
  "category view must not change the bank's standard controls")
assert(string.find(ShirsInventory_GetInventoryButtonSpecs(true).mode.tooltipTitle or "", "Grouping", 1, true),
  "category view replaced the bank's grouping control with the inventory Edit control")
ShirsInventory_SetCategoryMode(false)
assert(ShirsInventory_OnSortButtonClick(false) and physicalSorts == 1,
  "standard-mode Sort button did not retain physical sorting")
ShirsInventory_ToggleCategoryManager = savedToggleCategoryManager
ShirsInventory_SortBags = savedSortBags
assert(ShirsInventory_ShouldShowInventoryAction("sort", false),
  "standard inventory mode must keep sorting controls")

assert(type(ShirsInventory_RebuildStandardGrid) == "function" and
  type(ShirsInventory_RebuildCategoryGrid) == "function",
  "inventory renderer entry points are missing")
assert(type(ShirsInventory_ShouldDeferCategoryRebuild) == "function" and
  type(ShirsInventory_ProcessDeferredCategoryRebuild) == "function" and
  type(ShirsInventory_HasPendingCategoryRebuild) == "function",
  "category renderer is missing its cursor-safety deferral APIs")
CursorHasItem = function() return true end
local directCategoryRebuild, directCategoryReason = ShirsInventory_RebuildCategoryGrid()
assert(not directCategoryRebuild and directCategoryReason == "deferred" and
  ShirsInventory_HasPendingCategoryRebuild(),
  "direct category rebuild did not fail closed during a cursor transaction")
CursorHasItem = function() return false end
GetCursorInfo = function() return "item" end
assert(ShirsInventory_ShouldDeferCategoryRebuild(),
  "category renderer did not recognize an item cursor through GetCursorInfo")
GetCursorInfo = function() return nil end
local originalGetContainerNumSlots = GetContainerNumSlots
local originalGetContainerItemInfo = GetContainerItemInfo
GetContainerNumSlots = function(bag) if bag == 0 then return 1 end return 0 end
GetContainerItemInfo = function() return "locked-texture", 1, true, 1 end
assert(ShirsInventory_ShouldDeferCategoryRebuild(),
  "category renderer did not defer while a carried slot was locked")
GetContainerNumSlots = originalGetContainerNumSlots
GetContainerItemInfo = originalGetContainerItemInfo
local standardRebuilds, categoryRebuilds = 0, 0
local originalStandardRebuild = ShirsInventory_RebuildStandardGrid
local originalCategoryRebuild = ShirsInventory_RebuildCategoryGrid
ShirsInventory_RebuildStandardGrid = function() standardRebuilds = standardRebuilds + 1 end
ShirsInventory_RebuildCategoryGrid = function() categoryRebuilds = categoryRebuilds + 1 end
local originalRefreshInventoryStyles = ShirsInventory_RefreshInventoryButtonStyles
ShirsInventory_RefreshInventoryButtonStyles = function() end
ShirsInventoryFrame = { IsShown = function() return true end }
ShirsInventory_SetCategoryMode(false)
ShirsInventory_Update()
ShirsInventory_SetCategoryMode(true)
CursorHasItem = function() return true end
ShirsInventory_Update()
assert(categoryRebuilds == 0 and ShirsInventory_HasPendingCategoryRebuild(),
  "category update rebound display buttons while the cursor held an item")
CursorHasItem = function() return false end
GetCursorInfo = function() return nil end
ShirsInventory_ProcessDeferredCategoryRebuild()
assert(standardRebuilds == 1 and categoryRebuilds == 1 and
  not ShirsInventory_HasPendingCategoryRebuild(),
  "inventory update did not select the saved standard/category renderer")
ShirsInventory_RebuildStandardGrid = originalStandardRebuild
ShirsInventory_RebuildCategoryGrid = originalCategoryRebuild
ShirsInventory_RefreshInventoryButtonStyles = originalRefreshInventoryStyles
ShirsInventoryFrame = nil
ShirsInventory_SetCategoryMode(false)

assert(type(ShirsInventory_SetCategoryModeAndReload) == "function",
  "category-view reload trigger is missing")
local categoryReloads = 0
local function CountCategoryReload() categoryReloads = categoryReloads + 1 end
assert(ShirsInventory_SetCategoryModeAndReload(true, CountCategoryReload) and
  ShirsInventory_GetCategoryMode() and categoryReloads == 1,
  "enabling category view must save the setting and trigger one UI reload")
assert(not ShirsInventory_SetCategoryModeAndReload(true, CountCategoryReload) and categoryReloads == 1,
  "choosing the active category mode must not reload again")
assert(ShirsInventory_SetCategoryModeAndReload(false, CountCategoryReload) and
  not ShirsInventory_GetCategoryMode() and categoryReloads == 2,
  "disabling category view must save the setting and trigger one UI reload")

assert(type(ShirsInventory_GetItemsPerRow) == "function" and
  type(ShirsInventory_SetItemsPerRow) == "function",
  "items-per-row option API is missing")
assert(ShirsInventory_GetItemsPerRow() == 10,
  "items per row must keep the current ten-column default")
assert(ShirsInventory_SetItemsPerRow(9) == 10 and
  ShirsInventory_SetItemsPerRow(21) == 20 and
  ShirsInventory_SetItemsPerRow(14.6) == 15,
  "items-per-row setter must round and clamp to 10-20")
assert(ShirsInventory_GetBankFrameLayout().maximumColumns == 15,
  "bank and inventory must share the items-per-row setting")

assert(type(ShirsInventory_GetWindowScale) == "function" and
  type(ShirsInventory_SetWindowScale) == "function",
  "inventory scale option API is missing")
assert(ShirsInventory_GetWindowScale() == 1,
  "inventory scale must default to 100 percent")
assert(ShirsInventory_SetWindowScale(0.5) == 0.65 and
  ShirsInventory_SetWindowScale(2) == 1 and
  ShirsInventory_SetWindowScale(0.83) == 0.85,
  "inventory scale setter must round and clamp to 65-100 percent")

UIParent = {}
function UIParent:GetWidth() return 1024 end
function UIParent:GetHeight() return 768 end
local inventoryFrame = { shown = true, left = 500, top = 700, width = 828, height = 252 }
function inventoryFrame:SetScale(value) self.scale = value end
function inventoryFrame:GetScale() return self.scale end
function inventoryFrame:GetEffectiveScale() return self.scale end
function inventoryFrame:IsShown() return self.shown end
function inventoryFrame:GetLeft() return self.left end
function inventoryFrame:GetTop() return self.top end
function inventoryFrame:GetWidth() return self.width end
function inventoryFrame:GetHeight() return self.height end
function inventoryFrame:ClearAllPoints() end
function inventoryFrame:SetPoint(_, _, _, x, y)
  if self.deferGeometry then
    self.pendingLeft, self.pendingTop = x, y
  else
    self.left, self.top = x, y
  end
end
local bankFrame = { shown = true, left = 700, bottom = 50, width = 500, height = 300 }
function bankFrame:SetScale(value) self.scale = value end
function bankFrame:GetScale() return self.scale end
function bankFrame:GetEffectiveScale() return self.scale end
function bankFrame:IsShown() return self.shown end
function bankFrame:GetLeft() return self.left end
function bankFrame:GetBottom() return self.bottom end
function bankFrame:GetWidth() return self.width end
function bankFrame:GetHeight() return self.height end
function bankFrame:ClearAllPoints() end
function bankFrame:SetPoint(_, _, _, x, y)
  if self.deferGeometry then
    self.pendingLeft, self.pendingBottom = x, y
  else
    self.left, self.bottom = x, y
  end
end
ShirsInventoryFrame = inventoryFrame
ShirsInventoryBankFrame = bankFrame
local inventoryUpdates, bankUpdates = 0, 0
ShirsInventory_Update = function() inventoryUpdates = inventoryUpdates + 1 end
ShirsInventory_UpdateBank = function() bankUpdates = bankUpdates + 1 end
assert(ShirsInventory_ApplyLayoutSettings(),
  "layout settings did not apply to the visible windows")
assert(inventoryFrame.scale == 0.85 and bankFrame.scale == 0.85 and
  inventoryUpdates == 1 and bankUpdates == 1,
  "layout settings did not rescale and rebuild both visible windows")

assert(type(ShirsInventory_ApplyWindowScaleSetting) == "function",
  "lightweight window-scale apply path is missing")
local inventoryUpdatesBeforeScale = inventoryUpdates
local bankUpdatesBeforeScale = bankUpdates
ShirsInventory_SetWindowScale(0.75)
assert(ShirsInventory_ApplyWindowScaleSetting(),
  "lightweight window-scale apply path failed")
assert(inventoryFrame.scale == 0.75 and bankFrame.scale == 0.75,
  "lightweight window-scale apply path did not rescale both windows")
assert(inventoryUpdates == inventoryUpdatesBeforeScale and bankUpdates == bankUpdatesBeforeScale,
  "window-scale adjustment rebuilt item grids on every slider event")

ShirsInventory_SetItemsPerRow(20)
ShirsInventory_SetWindowScale(1)
inventoryFrame.left, inventoryFrame.top = 500, 700
bankFrame.left, bankFrame.bottom = 700, 50
assert(ShirsInventory_ApplyLayoutSettings(),
  "extreme layout settings were not applied")
assert(inventoryFrame.left * inventoryFrame.scale >= 8 and
  (inventoryFrame.left + inventoryFrame.width) * inventoryFrame.scale <= 1024 and
  inventoryFrame.top * inventoryFrame.scale <= 768 and
  (inventoryFrame.top - inventoryFrame.height) * inventoryFrame.scale >= 8,
  "inventory was not recovered from an inaccessible saved edge position")
assert(bankFrame.left * bankFrame.scale >= 8 and
  (bankFrame.left + bankFrame.width) * bankFrame.scale <= 1016 and
  bankFrame.bottom * bankFrame.scale >= 8 and
  (bankFrame.bottom + bankFrame.height) * bankFrame.scale <= 760,
  "bank was not recovered from an inaccessible saved edge position")

local inventorySaved, bankSaved = 0, 0
local originalSaveInventory = ShirsInventory_SaveInventoryFramePosition
local originalSaveBank = ShirsInventory_SaveBankFramePosition
ShirsInventory_SaveInventoryFramePosition = function(frame)
  inventorySaved = inventorySaved + 1
  return originalSaveInventory(frame)
end
ShirsInventory_SaveBankFramePosition = function(frame)
  bankSaved = bankSaved + 1
  return originalSaveBank(frame)
end
ShirsInventory_SetWindowScale(0.65)
inventoryFrame:SetScale(0.65)
bankFrame:SetScale(0.65)
inventoryFrame.left, inventoryFrame.top = 700, 900
bankFrame.left, bankFrame.bottom = 700, 100
assert(ShirsInventory_RecoverInventoryViewport(inventoryFrame) and
  ShirsInventory_RecoverBankViewport(bankFrame),
  "accessible small-scale windows failed viewport recovery")
assert(inventoryFrame.left == 700 and inventoryFrame.top == 900 and
  bankFrame.left == 700 and bankFrame.bottom == 100 and
  inventorySaved == 0 and bankSaved == 0,
  "accessible 65-percent windows were moved or their saved positions overwritten")

assert(type(ShirsInventory_RecoverInventoryViewport) == "function" and
  type(ShirsInventory_RecoverBankViewport) == "function",
  "show-time viewport recovery helpers are missing")
inventoryFrame.shown, bankFrame.shown = false, false
inventoryFrame.left, inventoryFrame.top = 500, 700
bankFrame.left, bankFrame.bottom = 700, 50
ShirsInventory_ApplyItemsPerRowSliderValue(20)
ShirsInventory_ApplyWindowScaleSliderValue(1)
assert(inventoryFrame.left == 500 and bankFrame.left == 700,
  "hidden windows were unexpectedly moved while changing layout settings")
inventoryFrame.shown, bankFrame.shown = true, true
assert(ShirsInventory_RecoverInventoryViewport(inventoryFrame) and
  ShirsInventory_RecoverBankViewport(bankFrame),
  "hidden windows were not recovered when reopened")
assert(inventoryFrame.left * inventoryFrame.scale >= 8 and
  (inventoryFrame.left + inventoryFrame.width) * inventoryFrame.scale <= 1024,
  "reopened inventory kept an inaccessible saved edge position")
assert(bankFrame.left * bankFrame.scale >= 8 and
  (bankFrame.left + bankFrame.width) * bankFrame.scale <= 1016,
  "reopened bank kept an inaccessible saved edge position")

ShirsInventory_SetWindowScale(1)
inventoryFrame:SetScale(1)
bankFrame:SetScale(1)
inventoryFrame.left, inventoryFrame.top = 700, 700
bankFrame.left, bankFrame.bottom = 700, 50
inventoryFrame.deferGeometry, bankFrame.deferGeometry = true, true
assert(ShirsInventory_RecoverInventoryViewport(inventoryFrame) and
  ShirsInventory_RecoverBankViewport(bankFrame),
  "deferred-geometry windows failed viewport recovery")
local delayedInventory = ShirsInventory_GetInventoryFramePosition()
local delayedBank = ShirsInventory_GetBankFramePosition()
assert(inventoryFrame.left == 700 and bankFrame.left == 700,
  "deferred-geometry probe updated Region getters too early")
assert(delayedInventory.x == inventoryFrame.pendingLeft and delayedInventory.y == inventoryFrame.pendingTop and
  delayedInventory.x ~= inventoryFrame.left,
  "inventory recovery persisted stale Region geometry")
assert(delayedBank.x == bankFrame.pendingLeft and delayedBank.y == bankFrame.pendingBottom and
  delayedBank.x ~= bankFrame.left,
  "bank recovery persisted stale Region geometry")
inventoryFrame.deferGeometry, bankFrame.deferGeometry = false, false

local layoutApplied, scaleApplied = 0, 0
ShirsInventory_ApplyLayoutSettings = function() layoutApplied = layoutApplied + 1 return true end
ShirsInventory_ApplyWindowScaleSetting = function() scaleApplied = scaleApplied + 1 return true end
assert(ShirsInventory_ApplyItemsPerRowSliderValue(18) == 18 and layoutApplied == 1,
  "items-per-row slider handler did not persist and apply its value")
assert(ShirsInventory_ApplyWindowScaleSliderValue(0.75) == 0.75 and
  layoutApplied == 1 and scaleApplied == 1,
  "scale slider handler rebuilt the full layout instead of using the lightweight path")

local sliderLabels = {}
local createdSliders = {}
function getglobal(name)
  if not sliderLabels[name] then
    sliderLabels[name] = { SetText = function(self, value) self.text = value end }
  end
  return sliderLabels[name]
end
function CreateFrame(frameType, name, parent, template)
  assert(frameType == "Slider" and template == "OptionsSliderTemplate",
    "layout controls must use the Vanilla options slider template")
  local slider = { scripts = {}, parent = parent }
  function slider:SetWidth(value) self.width = value end
  function slider:SetPoint(...) self.point = arg end
  function slider:SetMinMaxValues(low, high) self.low, self.high = low, high end
  function slider:SetValueStep(value) self.step = value end
  function slider:SetValue(value) self.value = value end
  function slider:GetValue() return self.value end
  function slider:SetScript(eventName, handler) self.scripts[eventName] = handler end
  createdSliders[name] = slider
  return slider
end
local sliderHost = {}
assert(ShirsInventory_CreateLayoutSliders(sliderHost),
  "settings did not construct the two layout sliders")
assert(sliderHost.itemsPerRowSlider.low == 10 and sliderHost.itemsPerRowSlider.high == 20 and
  sliderHost.itemsPerRowSlider.step == 1 and sliderHost.itemsPerRowSlider.width == 320,
  "items-per-row slider has the wrong bounds, step, or premium width")
assert(sliderHost.windowScaleSlider.low == 0.65 and sliderHost.windowScaleSlider.high == 1 and
  sliderHost.windowScaleSlider.step == 0.05 and sliderHost.windowScaleSlider.width == 320,
  "window-scale slider has the wrong bounds, step, or premium width")
local oldThis = this
this = sliderHost.itemsPerRowSlider
this:SetValue(17)
this.scripts.OnValueChanged()
assert(ShirsInventory_GetItemsPerRow() == 17,
  "bound items-per-row slider did not persist its selected value")
this = sliderHost.windowScaleSlider
this:SetValue(0.7)
this.scripts.OnValueChanged()
assert(ShirsInventory_GetWindowScale() == 0.7,
  "bound window-scale slider did not persist its selected value")
this = oldThis

assert(ShirsInventory_GetShowRarityBoxes(),
  "colored rarity boxes must default on")
ShirsInventory_SetShowRarityBoxes(false)
assert(not ShirsInventory_GetShowRarityBoxes(),
  "colored rarity boxes must remain optional")
assert(ShirsInventory_GetUseCoinIcons(),
  "coin-art currency mode must default on")
ShirsInventory_SetUseCoinIcons(false)
assert(not ShirsInventory_GetUseCoinIcons(),
  "plain g/s/c currency mode must remain selectable")
assert(type(ShirsInventory_GetHideItemOwnershipInCombat) == "function" and
  type(ShirsInventory_SetHideItemOwnershipInCombat) == "function" and
  not ShirsInventory_GetHideItemOwnershipInCombat(),
  "item ownership combat option API is missing or has the wrong default")
assert(ShirsInventory_SetHideItemOwnershipInCombat(true) and
  ShirsInventory_GetHideItemOwnershipInCombat(),
  "item ownership combat option did not persist")
assert(type(ShirsInventory_GetAutoClearSearch) == "function" and
  type(ShirsInventory_SetAutoClearSearch) == "function" and
  ShirsInventory_GetAutoClearSearch(),
  "automatic search clearing option is missing or must default on")
assert(not ShirsInventory_SetAutoClearSearch(false) and
  not ShirsInventory_GetAutoClearSearch(),
  "automatic search clearing option did not persist off")

function GetItemInfo(itemID)
  if itemID == 15138 then
    return "Onyxia Scale Cloak", "link", 4, 60, "Armor", "Cloth", 1, "INVTYPE_CLOAK", "cloak-texture"
  end
  if itemID == 12361 then
    return "Blue Sapphire", "link", 2, 50, "Trade Goods", "Gem", 20, "", "gem-texture"
  end
  return nil
end
ShirsInventory_ClearHearthstoneItems()
assert(ShirsInventory_SetHearthstoneItem(15138, true))
assert(ShirsInventory_SetHearthstoneItem(12361, true))
local selectedRows, selectedPage, selectedPages, selectedTotal =
  ShirsInventory_GetHearthstoneItemDisplayRows(1, 8)
assert(selectedPage == 1 and selectedPages == 1 and selectedTotal == 2 and
  table.getn(selectedRows) == 2,
  "Hearthstone item manager returned the wrong page model")
assert(selectedRows[1].itemID == 15138 and selectedRows[1].name == "Onyxia Scale Cloak" and
  selectedRows[1].texture == "cloak-texture" and not selectedRows[1].canMoveUp and
  selectedRows[1].canMoveDown,
  "first Hearthstone manager row has the wrong item data or movement state")
assert(selectedRows[2].itemID == 12361 and selectedRows[2].name == "Blue Sapphire" and
  selectedRows[2].texture == "gem-texture" and selectedRows[2].canMoveUp and
  not selectedRows[2].canMoveDown,
  "second Hearthstone manager row has the wrong item data or movement state")
ShirsInventory_ClearHearthstoneItems()

assert(not string.find(settings, "Use icons for inventory header + action buttons", 1, true),
  "inventory text-style toggle must be removed now that bag controls are icon-only")
assert(string.find(settings, "Use coin icons for currency (off = g/s/c text)", 1, true),
  "currency option must explain the text fallback")
assert(string.find(settings, "Hide item ownership details while in combat", 1, true) and
  string.find(settings, "ShirsInventory_SetHideItemOwnershipInCombat", 1, true),
  "settings panel is missing the item ownership combat checkbox")
assert(string.find(settings, "Clear search when inventory or bank closes, or you click outside", 1, true) and
  string.find(settings, "ShirsInventory_SetAutoClearSearch", 1, true),
  "settings must expose one per-character automatic-clear option for both search fields")
assert(string.find(settings, "Hearthstone mode: Automatic (off = selected list)", 1, true) and
  string.find(settings, '"automaticHearthstoneItems"', 1, true) and
  string.find(settings, "ShirsInventory_SetAutomaticHearthstoneItems", 1, true),
  "settings must expose the exclusive automatic/selected Hearthstone mode")
assert(string.find(settings, "Lock selected item slots while sorting (bags only)", 1, true) and
  string.find(settings, '"lockSelectedItemSlots"', 1, true) and
  string.find(settings, "ShirsInventory_SetLockSelectedItemSlots", 1, true),
  "settings must expose the carried-only selected-slot lock option")
assert(string.find(settings, "Use category view (reloads UI; bag sorting is disabled)", 1, true) and
  string.find(settings, '"categoryMode"', 1, true) and
  string.find(settings, "ShirsInventory_SetCategoryModeAndReload", 1, true),
  "settings must expose the reload-gated category view")
assert(string.find(settings, "Manage selected item list", 1, true) and
  string.find(settings, "ShirsInventory_ShowHearthstoneItems", 1, true) and
  string.find(settings, 'SetText("Up")', 1, true) and
  string.find(settings, 'SetText("Down")', 1, true) and
  string.find(settings, 'SetText("Remove")', 1, true),
  "settings are missing the selected-item manager and its ordering controls")
assert(not string.find(settings, ":SetShown", 1, true),
  "selected-item manager uses SetShown, which is not part of the Interface 11200 API floor")
assert(string.find(settings, 'ShirsInventory_CreatePanel("ShirsInventorySettingsFrame", 440, 610, "DIALOG")', 1, true) and
  string.find(settings, 'frame.help:SetWidth(392)', 1, true) and
  string.find(settings, 'check.label:SetWidth(362)', 1, true) and
  string.find(settings, 'check.label:SetHeight(28)', 1, true),
  "premium settings frame does not reserve exact safe text widths")
assert(string.find(settings, 'ShirsInventory_CreateSectionHeading(frame, "BEHAVIOR", -82)', 1, true) and
  string.find(settings, 'ShirsInventory_CreateSectionHeading(frame, "ITEMS & DISPLAY", -228)', 1, true) and
  string.find(settings, 'ShirsInventory_CreateSectionHeading(frame, "WINDOW LAYOUT", -466)', 1, true),
  "premium settings section headings are missing or misplaced")
assert(string.find(settings, 'frame, "Ignore gray + manually marked junk while sorting", "ignoreJunkSorting", -107', 1, true) and
  string.find(settings, 'frame, "Clear search when inventory or bank closes, or you click outside", "autoClearSearch", -194', 1, true) and
  string.find(settings, 'frame, "Show quest and rarity borders on items", "showRarityBoxes", -253', 1, true) and
  string.find(settings, 'frame, "Hearthstone mode: Automatic (off = selected list)", "automaticHearthstoneItems", -340', 1, true) and
  string.find(settings, 'frame, "Lock selected item slots while sorting (bags only)", "lockSelectedItemSlots", -369', 1, true),
  "premium settings rows do not use the bounded section layout")
assert(string.find(settings, 'frame.hearthstoneItemsButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -401)', 1, true) and
  string.find(settings, 'frame.hearthstoneItemsButton:SetWidth(300)', 1, true) and
  string.find(settings, 'frame, "Use category view (reloads UI; bag sorting is disabled)", "categoryMode", -430', 1, true) and
  string.find(settings, 'frame.itemsPerRowSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -495)', 1, true) and
  string.find(settings, 'frame.windowScaleSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -538)', 1, true),
  "premium settings actions and sliders do not align to the shared grid")
assert(string.find(settings, 'ShirsInventory_CreatePanel("ShirsInventoryHearthstoneItemsFrame", 440, 470, "DIALOG")', 1, true) and
  string.find(settings, 'row:SetWidth(392)', 1, true) and
  string.find(settings, 'row:SetHeight(32)', 1, true) and
  string.find(settings, '24, -102 - ((rowIndex - 1) * 36)', 1, true) and
  string.find(settings, 'row.grip:SetText("::")', 1, true) and
  string.find(settings, 'row.name:SetWidth(166)', 1, true) and
  string.find(settings, 'row.name:SetHeight(30)', 1, true),
  "premium selected-item manager geometry is missing")
assert(string.find(settings, '"Items per row: "', 1, true) and
  string.find(settings, 'SetMinMaxValues(10, 20)', 1, true) and
  string.find(settings, 'SetValueStep(1)', 1, true),
  "settings panel is missing the 10-20 items-per-row slider")
assert(string.find(settings, '"Window scale: "', 1, true) and
  string.find(settings, 'SetMinMaxValues(0.65, 1)', 1, true) and
  string.find(settings, 'SetValueStep(0.05)', 1, true),
  "settings panel is missing the 65-100 percent scale slider")
assert(not string.find(settings, "Full Bag UI", 1, true),
  "full-suite settings still expose the old bag UI feature switch")
assert(not string.find(settings, "Bag Sorter", 1, true),
  "full-suite settings still expose the old sorter feature switch")
assert(not string.find(settings, "Sell Junk + manual junk marks", 1, true),
  "full-suite settings still expose the old junk feature switch")
assert(not string.find(settings, "Choose Bag UI", 1, true),
  "full-suite settings still expose the old provider chooser")
assert(not string.find(settings, "Save Custom Choice", 1, true),
  "first-run custom feature selection still exists")
assert(not string.find(settings, "settingsFrame.errorText", 1, true),
  "settings still reference the removed feature-selection error label")
assert(string.find(settings, 'merchantSellButton:SetWidth(36)', 1, true) and
  string.find(settings, 'merchantSellButton:SetHeight(36)', 1, true),
  "merchant Sell Junk is not repair-button sized")
assert(string.find(settings,
  'merchantSellButton:SetPoint("RIGHT", MerchantRepairItemButton, "LEFT", -2, 0)', 1, true),
  "merchant Sell Junk is not immediately left of Repair an Item")
assert(string.find(settings,
  'CreateFrame("Button", "ShirsInventoryMerchantSellButton", MerchantFrame, "ItemButtonTemplate")', 1, true),
  "merchant Sell Junk does not use the standard bordered item-button frame")
assert(string.find(settings, 'sellJunkTexture:SetTexture("Interface\\\\Icons\\\\INV_Misc_Coin_01")', 1, true),
  "merchant Sell Junk does not use the coin icon")
assert(string.find(settings, 'sellJunkTexture:SetTexCoord(0, 1, 0, 1)', 1, true),
  "merchant Sell Junk icon remains zoom-cropped")
assert(not string.find(settings, 'merchantSellButton:SetText("Sell Junk")', 1, true),
  "merchant Sell Junk still uses the wide text button")
assert(string.find(settings, "MerchantRepairText:Hide()", 1, true),
  "merchant repair label remains visible behind the icon row")

-- Construct the real settings frame under an Interface 11200-style mock. Source
-- strings alone cannot prove the created controls receive bounded geometry.
local constructedFrames = {}
local constructedGlobals = {}
local function NewRegion()
  local region = { visible = true, scripts = {} }
  function region:SetWidth(value) self.width = value end
  function region:SetHeight(value) self.height = value end
  function region:SetPoint(point, relative, relativePoint, x, y)
    self.point = { point = point, relative = relative, relativePoint = relativePoint, x = x, y = y }
  end
  function region:SetText(value) self.text = value end
  function region:GetText() return self.text or "" end
  function region:SetAutoFocus(value) self.autoFocus = value end
  function region:SetMaxLetters(value) self.maxLetters = value end
  function region:ClearFocus() self.focused = false end
  function region:SetTextColor(...) self.textColor = arg end
  function region:SetJustifyH(value) self.justifyH = value end
  function region:SetJustifyV(value) self.justifyV = value end
  function region:SetTexture(value) self.texture = value end
  function region:SetTexCoord(...) self.texCoord = arg end
  function region:SetVertexColor(...) self.vertexColor = arg end
  function region:SetAllPoints(target) self.allPoints = target or true end
  function region:SetBackdrop(value) self.backdrop = value end
  function region:SetBackdropColor(...) self.backdropColor = arg end
  function region:SetBackdropBorderColor(...) self.backdropBorderColor = arg end
  function region:SetFrameStrata(value) self.strata = value end
  function region:SetFrameLevel(value) self.frameLevel = value end
  function region:GetFrameLevel() return self.frameLevel or 1 end
  function region:SetToplevel(value) self.toplevel = value end
  function region:EnableMouse(value) self.mouseEnabled = value end
  function region:EnableMouseWheel(value) self.mouseWheelEnabled = value and true or false end
  function region:SetMovable(value) self.movable = value end
  function region:SetClampedToScreen(value) self.clamped = value end
  function region:RegisterForDrag(...) self.dragButtons = arg end
  function region:RegisterEvent(value) self.event = value end
  function region:SetScript(name, handler) self.scripts[name] = handler end
  function region:SetParent(value) self.parent = value end
  function region:ClearAllPoints() self.point = nil end
  function region:StartMoving() end
  function region:StopMovingOrSizing() end
  function region:Show() self.visible = true end
  function region:Hide() self.visible = false end
  function region:IsShown() return self.visible end
  function region:IsVisible() return self.visible end
  function region:SetChecked(value) self.checked = value end
  function region:GetChecked() return self.checked end
  function region:SetMinMaxValues(low, high) self.low, self.high = low, high end
  function region:SetValueStep(value) self.step = value end
  function region:SetValue(value) self.value = value end
  function region:GetValue() return self.value end
  function region:Enable() self.enabled = true end
  function region:Disable() self.enabled = false end
  function region:CreateFontString()
    local child = NewRegion()
    child.parent = self
    return child
  end
  function region:CreateTexture()
    local child = NewRegion()
    child.parent = self
    return child
  end
  function region:SetID(value) self.id = value end
  function region:GetID() return self.id end
  function region:GetName() return self.name or self.frameType or "mockregion" end
  function region:RegisterForClicks(...) self.clicks = arg end
  function region:RegisterForDrag(...) self.dragButtons = arg end
  function region:SetScale(value) self.scale = value end
  function region:GetScale() return self.scale or 1 end
  function region:GetEffectiveScale() return self.scale or 1 end
  function region:SetAlpha(value) self.alpha = value end
  function region:GetAlpha() return self.alpha or 1 end
  function region:GetWidth() return self.width or 0 end
  function region:GetHeight() return self.height or 0 end
  function region:GetLeft() return self.left or 0 end
  function region:SetLeft(value) self.left = value end
  function region:GetTop() return self.top or 0 end
  function region:SetTop(value) self.top = value end
  function region:GetRight() return (self.left or 0) + (self.width or 0) end
  function region:GetBottom() return (self.top or 0) - (self.height or 0) end
  function region:GetNormalTexture() return nil end
  function region:SetNormalTexture() end
  function region:SetHighlightTexture() end
  function region:SetPushedTexture() end
  function region:SetOrientation(value) self.orientation = value end
  function region:SetThumbTexture(value) self.thumbTexture = value end
  function region:SetBlendMode(value) self.blendMode = value end
  function region:SetShadowColor() end
  function region:SetShadowOffset() end
  function region:SetTextInsets() end
  return region
end

UIParent = NewRegion()
MerchantFrame = NewRegion()
MerchantRepairItemButton = NewRegion()
MerchantRepairText = NewRegion()
GameTooltip = NewRegion()
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
UISpecialFrames = {}
function CreateFrame(frameType, name, parent, template)
  local frame = NewRegion()
  frame.frameType, frame.name, frame.parent, frame.template = frameType, name, parent, template
  if name == "ShirsInventoryCategoryScanTooltip" then
    function frame:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
    function frame:ClearLines() end
    function frame:SetBagItem(bag, slot) self.scannedBag, self.scannedSlot = bag, slot end
    function frame:NumLines() return 2 end
    local firstLine = NewRegion()
    firstLine:SetText("Roasted Boar")
    local secondLine = NewRegion()
    secondLine:SetText("Must remain seated while eating.")
    constructedGlobals.ShirsInventoryCategoryScanTooltipTextLeft1 = firstLine
    constructedGlobals.ShirsInventoryCategoryScanTooltipTextLeft2 = secondLine
  end
  table.insert(constructedFrames, frame)
  if name then
    constructedGlobals[name] = frame
    getfenv(0)[name] = frame
  end
  return frame
end
function getglobal(name)
  if constructedGlobals[name] then return constructedGlobals[name] end
  local region = NewRegion()
  constructedGlobals[name] = region
  return region
end
local scannedCategoryTooltip = ShirsInventory_GetCategoryTooltipText(2, 7)
local categoryScanTooltip = constructedGlobals.ShirsInventoryCategoryScanTooltip
assert(categoryScanTooltip and categoryScanTooltip.template == "GameTooltipTemplate" and
  categoryScanTooltip.scannedBag == 2 and categoryScanTooltip.scannedSlot == 7 and
  string.find(scannedCategoryTooltip, "Must remain seated while eating", 1, true),
  "broader category tooltip scanner did not use the real bag/slot or collect legacy tooltip lines")
ShirsInventory_RefreshButtonStyles = function() end
ShirsInventory_UpdateStandaloneControls = function() end
local settingsReloads = 0
function ReloadUI() settingsReloads = settingsReloads + 1 end
ShirsInventory_CreateSettingsUI()
local builtSettings = constructedGlobals.ShirsInventorySettingsFrame
assert(builtSettings and builtSettings.width == 440 and builtSettings.height == 610 and
  builtSettings.point.point == "CENTER" and builtSettings.point.y == 20,
  "real settings constructor did not build the premium frame geometry")
assert(type(ShirsInventory_ShowCategoryManager) == "function" and
  type(ShirsInventory_ToggleCategoryManager) == "function" and
  type(ShirsInventory_PositionCategoryManager) == "function" and
  type(ShirsInventory_RefreshCategoryManager) == "function",
  "custom category manager UI APIs are missing")
local categoryImportCalls = {}
ShirsInventory_AccountGetCurrentRealm = function() return "CurrentRealm" end
ShirsInventory_AccountGetCurrentCharacter = function() return "Currentchar" end
ShirsInventory_AccountGetCategoryImportSources = function()
  return {
    { realm = "AlphaRealm", character = "Altsmith", label = "Altsmith - AlphaRealm" },
    { realm = "BetaRealm", character = "Banktoon", label = "Banktoon - BetaRealm" },
  }
end
ShirsInventory_AccountImportCategorySettings = function(realm, character)
  table.insert(categoryImportCalls, realm .. ":" .. character)
  return true
end
local categoryManagerAnchor = NewRegion()
ShirsInventoryFrame = { sortButton = categoryManagerAnchor }
local categoryManagerPositionProbe = NewRegion()
assert(ShirsInventory_PositionCategoryManager(categoryManagerPositionProbe) and
  categoryManagerPositionProbe.point.point == "TOPRIGHT" and
  categoryManagerPositionProbe.point.relative == categoryManagerAnchor and
  categoryManagerPositionProbe.point.relativePoint == "BOTTOMRIGHT",
  "category manager did not stay below the Categories button so the button remains clickable")
assert(ShirsInventory_SaveCategorySettingsFrameCoordinates("TOPLEFT", "BOTTOMLEFT", 275, 725),
  "Category Settings test position did not save")
assert(ShirsInventory_PositionCategoryManager(categoryManagerPositionProbe) and
  categoryManagerPositionProbe.point.point == "TOPLEFT" and
  categoryManagerPositionProbe.point.relative == UIParent and
  categoryManagerPositionProbe.point.relativePoint == "BOTTOMLEFT" and
  categoryManagerPositionProbe.point.x == 275 and categoryManagerPositionProbe.point.y == 725,
  "Category Settings did not restore its saved per-character position")
assert(ShirsInventory_ShowCategoryManager(), "custom category manager did not open")
local builtCategoryManager = constructedGlobals.ShirsInventoryCategoryManagerFrame
assert(builtCategoryManager:IsShown() and ShirsInventory_ToggleCategoryManager() and
  not builtCategoryManager:IsShown() and ShirsInventory_ToggleCategoryManager() and
  builtCategoryManager:IsShown(),
  "Categories button did not toggle the category manager closed and open")
assert(builtCategoryManager and builtCategoryManager.width == 440 and builtCategoryManager.height == 680 and
  builtCategoryManager.title.text == "Category settings" and
  builtCategoryManager.customCategoriesHeading and
  builtCategoryManager.customCategoriesHeading.text == "CUSTOM CATEGORIES" and
  builtCategoryManager.displayHeading and builtCategoryManager.displayHeading.text == "DISPLAY" and
  builtCategoryManager.importHeading and builtCategoryManager.importHeading.text == "IMPORT FROM CHARACTER" and
  builtCategoryManager.importSourceText and
  builtCategoryManager.importSourceText.text == "Altsmith - AlphaRealm" and
  builtCategoryManager.importPrevious and builtCategoryManager.importNext and builtCategoryManager.importButton and
  builtCategoryManager.nameInput.maxLetters == 28 and table.getn(builtCategoryManager.rows) == 12 and
  builtCategoryManager.collapseEmptySlots and
  builtCategoryManager.collapseEmptySlots.label.text == "Collapse Empty Slots to one slot",
  "custom category manager did not build its bounded create/delete and Empty Slots layout")
assert(builtCategoryManager.point.point == "TOPLEFT" and builtCategoryManager.point.x == 275 and
  builtCategoryManager.point.y == 725,
  "Category Settings constructor ignored its saved position")
builtCategoryManager.GetLeft = function() return 411 end
builtCategoryManager.GetTop = function() return 688 end
builtCategoryManager.scripts.OnDragStop()
local draggedCategorySettingsPosition = ShirsInventory_GetCategorySettingsPosition()
assert(draggedCategorySettingsPosition.x == 411 and draggedCategorySettingsPosition.y == 688,
  "dragging Category Settings did not save its new position")
ShirsInventory_ToggleCategoryManager()
ShirsInventory_ToggleCategoryManager()
assert(builtCategoryManager.point.point == "TOPLEFT" and builtCategoryManager.point.x == 411 and
  builtCategoryManager.point.y == 688,
  "Category Settings snapped back after reopening")
local categoryManagerThis = this
this = builtCategoryManager.collapseEmptySlots
this:SetChecked(1)
this.scripts.OnClick()
assert(ShirsInventory_GetCollapseEmptySlots(),
  "category manager did not enable one-slot Empty Slots display")
this:SetChecked(nil)
this.scripts.OnClick()
assert(not ShirsInventory_GetCollapseEmptySlots(),
  "category manager did not restore all Empty Slots")
this = builtCategoryManager.importNext
this.scripts.OnClick()
assert(builtCategoryManager.importSourceText.text == "Banktoon - BetaRealm" and
  table.getn(categoryImportCalls) == 0,
  "category import source selector did not advance without importing")
this = builtCategoryManager.importButton
this.scripts.OnClick()
assert(table.getn(categoryImportCalls) == 0 and builtCategoryManager.importButton.text == "Confirm",
  "first category import click did not arm a safe confirmation")
this.scripts.OnClick()
assert(table.getn(categoryImportCalls) == 1 and categoryImportCalls[1] == "BetaRealm:Banktoon" and
  builtCategoryManager.importButton.text == "Import",
  "confirmed category import did not use the selected same-account character exactly once")
local savedCategoryImportSources = ShirsInventory_AccountGetCategoryImportSources
ShirsInventory_AccountGetCategoryImportSources = function() return {} end
ShirsInventory_RefreshCategoryManager()
assert(builtCategoryManager.importSourceText.text == "No other saved characters" and
  builtCategoryManager.importButton.enabled == false and
  builtCategoryManager.importPrevious.enabled == false and builtCategoryManager.importNext.enabled == false,
  "category import controls did not fail closed when no other character snapshot exists")
ShirsInventory_AccountGetCategoryImportSources = savedCategoryImportSources
ShirsInventory_RefreshCategoryManager()
this = builtCategoryManager.create
builtCategoryManager.nameInput:SetText("Explosives")
this.scripts.OnClick()
assert(table.getn(ShirsInventory_GetCustomCategories()) == 1 and
  builtCategoryManager.rows[1].label.text == "Explosives" and builtCategoryManager.rows[1].visible,
  "custom category manager Create button did not add and refresh a category")
this = builtCategoryManager.rows[1].delete
this.scripts.OnClick()
assert(table.getn(ShirsInventory_GetCustomCategories()) == 0 and not builtCategoryManager.rows[1].visible,
  "custom category manager Delete button did not remove and refresh a category")
this = categoryManagerThis
assert(builtSettings.help and builtSettings.help.width == 392 and builtSettings.help.height == 30,
  "real settings constructor did not bound the help copy")
assert(builtSettings.behaviorHeading and builtSettings.behaviorRule and
  builtSettings.behaviorRule.width == 392 and builtSettings.behaviorRule.height == 1 and
  builtSettings.itemsHeading and builtSettings.itemsRule and
  builtSettings.layoutHeading and builtSettings.layoutRule,
  "real settings constructor did not build the section hierarchy")
assert(builtSettings.autoClearSearch.label.width == 362 and
  builtSettings.autoClearSearch.label.height == 28 and
  builtSettings.autoClearSearch.label.justifyH == "LEFT" and
  builtSettings.autoClearSearch.label.justifyV == "MIDDLE",
  "long checkbox labels are not constrained inside the settings margin")
assert(builtSettings.lockSelectedItemSlots and
  builtSettings.lockSelectedItemSlots.label.width == 362 and
  builtSettings.lockSelectedItemSlots.label.height == 28 and
  builtSettings.lockSelectedItemSlots.point.y == -369 and
  builtSettings.hearthstoneItemsButton.width == 300 and
  builtSettings.hearthstoneItemsButton.point.y == -401 and
  builtSettings.categoryMode and builtSettings.categoryMode.point.y == -430 and
  builtSettings.itemsPerRowSlider.width == 320 and builtSettings.windowScaleSlider.width == 320 and
  builtSettings.itemsPerRowSlider.point.x == 60 and builtSettings.itemsPerRowSlider.point.y == -495 and
  builtSettings.windowScaleSlider.point.x == 60 and builtSettings.windowScaleSlider.point.y == -538 and
  builtSettings.closeButton.width == 96 and builtSettings.closeButton.point.y == 14,
  "real settings constructor produced misaligned action or slider geometry")

local settingsThis = this
assert(not ShirsInventory_GetLockSelectedItemSlots(),
  "selected-slot lock option did not construct from its safe default")
this = builtSettings.lockSelectedItemSlots
this:SetChecked(1)
this.scripts.OnClick()
assert(ShirsInventory_GetLockSelectedItemSlots(),
  "selected-slot lock checkbox did not persist on")
this:SetChecked(nil)
this.scripts.OnClick()
assert(not ShirsInventory_GetLockSelectedItemSlots(),
  "selected-slot lock checkbox did not persist off")
assert(not ShirsInventory_GetCategoryMode(),
  "constructed category-view checkbox did not start from the safe default")
this = builtSettings.categoryMode
this:SetChecked(1)
this.scripts.OnClick()
assert(ShirsInventory_GetCategoryMode() and settingsReloads == 1,
  "category-view checkbox did not persist on and reload the UI")
this = settingsThis

-- The count must refresh even before the selected-item manager is constructed.
local controlDown, altDown = true, false
function IsControlKeyDown() return controlDown end
function IsAltKeyDown() return altDown end
function GetContainerItemInfo() return "gem-texture", 1, nil, 2 end
function GetContainerItemLink() return "|Hitem:12361:0:0:0|h[Blue Sapphire]|h" end
local liveItemButton = { bag = 0, slot = 1 }
local categoryEditPhysicalPickups = 0
PickupContainerItem = function() categoryEditPhysicalPickups = categoryEditPhysicalPickups + 1 end
controlDown = false
assert(ShirsInventory_SetCategoryEditMode(true) and
  ShirsInventory_HandleItemClick(liveItemButton, "LeftButton", true) and
  ShirsInventory_SetCategoryEditHover("quest") and
  ShirsInventory_FinishCategoryEditDrag() == "quest" and
  ShirsInventory_GetCategoryAssignment(12361) == "quest" and
  categoryEditPhysicalPickups == 0,
  "category edit drag touched the physical cursor or failed to save the visual assignment")
assert(ShirsInventory_HandleItemClick(liveItemButton, "RightButton") and
  ShirsInventory_GetCategoryAssignment(12361) == nil,
  "category edit right-click did not restore automatic classification")
ShirsInventory_SetCategoryEditMode(false)
controlDown = true
ShirsInventory_ClearHearthstoneItems()
assert(ShirsInventory_HandleItemClick(liveItemButton, "RightButton") and
  ShirsInventory_GetHearthstoneItemCount() == 0,
  "category view must not intercept Ctrl-right-click for selected-item sorting")
ShirsInventory_SetCategoryMode(false)
assert(ShirsInventory_HandleItemClick(liveItemButton, "RightButton") and
  builtSettings.hearthstoneItemsButton.text == "Manage selected item list (1)",
  "live Ctrl-right-click add did not refresh the count before manager construction")
assert(ShirsInventory_HandleItemClick(liveItemButton, "RightButton") and
  builtSettings.hearthstoneItemsButton.text == "Manage selected item list (0)",
  "live Ctrl-right-click remove did not refresh the count before manager construction")

builtSettings.hearthstoneItemsButton.scripts.OnClick()
local builtManager = constructedGlobals.ShirsInventoryHearthstoneItemsFrame
assert(builtManager and builtManager.width == 440 and builtManager.height == 470 and
  builtManager.point.point == "CENTER" and builtManager.point.y == 10,
  "real selected-item manager constructor has the wrong frame geometry")
assert(builtManager.title.text == "Selected item list",
  "selected-item manager title does not cover both edge and lock uses")
assert(builtManager.help.width == 392 and builtManager.help.height == 30 and
  string.find(builtManager.help.text or "", "Drag by the :: grip", 1, true) and
  builtManager.selectedItemHeading and builtManager.orderActionHeading and
  builtManager.columnRule and builtManager.columnRule.width == 392,
  "selected-item manager is missing its bounded header hierarchy")
assert(table.getn(builtManager.rows) == 8,
  "selected-item manager did not construct exactly eight paginated rows")
local constructedRowIndex
for constructedRowIndex = 1, table.getn(builtManager.rows) do
  local row = builtManager.rows[constructedRowIndex]
  assert(row.width == 392 and row.height == 32 and row.point.x == 24 and
    row.point.y == -102 - ((constructedRowIndex - 1) * 36),
    "selected-item manager row geometry is wrong")
  assert(row.grip and row.grip.text == "::" and row.grip.width == 18 and row.grip.height == 32 and
    row.grip.point.x == 0 and
    row.icon.width == 28 and row.icon.height == 28 and row.icon.point.x == 20 and
    row.name.width == 166 and row.name.height == 30 and row.name.point.x == 56 and
    row.dragArea and row.dragArea.width == 222 and row.dragArea.height == 32 and
    row.dragArea.dragButtons and row.dragArea.dragButtons[1] == "LeftButton" and
    row.dragArea.scripts.OnDragStart and row.dragArea.scripts.OnDragStop and
    row.dragArea.scripts.OnEnter and row.dragArea.scripts.OnLeave and
    row.dragHighlight and not row.dragHighlight.visible and
    row.up.width == 38 and row.up.point.x == 230 and
    row.down.width == 48 and row.down.point.x == 272 and
    row.remove.width == 68 and row.remove.point.x == 324,
    "selected-item row content or drag target exceeds its identity or action column")
end
assert(builtManager.pageText.width == 90 and builtManager.pageText.height == 14 and
  builtManager.previous.width == 46 and builtManager.next.width == 46 and
  builtManager.clear.width == 90 and builtManager.close.width == 90,
  "selected-item manager footer geometry is incomplete")

ShirsInventory_ClearHearthstoneItems()
assert(ShirsInventory_SetHearthstoneItem(15138, true) and
  ShirsInventory_SetHearthstoneItem(12361, true))
ShirsInventory_RefreshHearthstoneItemsFrame()
assert(builtManager.rows[1].itemID == 15138 and not builtManager.rows[1].up.enabled and
  builtManager.rows[1].down.enabled,
  "manager refresh did not preserve first-row movement state")
local constructorThis = this
this = builtManager.rows[1].down
this.scripts.OnClick()
local reorderedItems = ShirsInventory_GetHearthstoneItems()
assert(reorderedItems[1] == 12361 and reorderedItems[2] == 15138 and
  builtManager.rows[1].itemID == 12361,
  "manager Down action did not reorder and refresh immediately")
this = builtManager.rows[1].remove
this.scripts.OnClick()
assert(ShirsInventory_GetHearthstoneItemCount() == 1 and builtManager.rows[1].itemID == 15138,
  "manager Remove action did not update and refresh immediately")
this = builtManager.clear
this.scripts.OnClick()
assert(ShirsInventory_GetHearthstoneItemCount() == 0 and builtManager.emptyText.visible,
  "manager Clear All action did not empty and refresh the manager")

assert(ShirsInventory_SetHearthstoneItem(15138, true) and
  ShirsInventory_SetHearthstoneItem(12361, true) and
  ShirsInventory_SetHearthstoneItem(22222, true) and
  ShirsInventory_SetHearthstoneItem(33333, true))
ShirsInventory_RefreshHearthstoneItemsFrame()
local mouseFocus
function GetMouseFocus() return mouseFocus end
local dragSource = builtManager.rows[1].dragArea
this = dragSource
dragSource.scripts.OnDragStart()
assert(builtManager.rows[1].dragHighlight.visible,
  "starting a selected-item drag did not show source feedback")
local dragTarget = builtManager.rows[3].dragArea
this = dragTarget
dragTarget.scripts.OnEnter()
assert(builtManager.rows[3].dragHighlight.visible and
  builtManager.rows[3].dragHighlight.vertexColor[1] == 1,
  "hovering a selected-item drop target did not show distinct target feedback")
dragTarget.scripts.OnLeave()
assert(not builtManager.rows[3].dragHighlight.visible,
  "leaving a selected-item drop target did not clear target feedback")
dragTarget.scripts.OnEnter()
mouseFocus = dragTarget
dragSource.scripts.OnDragStop()
local draggedItems = ShirsInventory_GetHearthstoneItems()
assert(draggedItems[1] == 12361 and draggedItems[2] == 22222 and
  draggedItems[3] == 15138 and draggedItems[4] == 33333 and
  builtManager.rows[1].itemID == 12361 and builtManager.rows[3].itemID == 15138 and
  not builtManager.rows[1].dragHighlight.visible,
  "dragging a selected item onto another row did not persist and refresh the new order")
local stableDragOrder = table.concat(draggedItems, ",")
dragSource = builtManager.rows[1].dragArea
this = dragSource
mouseFocus = dragSource
dragSource.scripts.OnDragStart()
dragSource.scripts.OnDragStop()
assert(table.concat(ShirsInventory_GetHearthstoneItems(), ",") == stableDragOrder,
  "dropping a selected item on itself changed the order")
mouseFocus = nil
dragSource.scripts.OnDragStart()
dragSource.scripts.OnDragStop()
assert(table.concat(ShirsInventory_GetHearthstoneItems(), ",") == stableDragOrder,
  "dropping a selected item outside another selected row changed the order")
ShirsInventory_ClearHearthstoneItems()
ShirsInventory_RefreshHearthstoneItemsFrame()
local pageItemIndex
for pageItemIndex = 1, 30 do
  assert(ShirsInventory_SetHearthstoneItem(92000 + pageItemIndex, true),
    "30-item manager paging setup rejected a valid selection")
end
ShirsInventory_RefreshHearthstoneItemsFrame()
assert(builtManager.pageText.text == "Page 1 / 4" and builtManager.next.enabled,
  "30 selected items did not produce four manager pages")
this = builtManager.next
builtManager.next.scripts.OnClick()
builtManager.next.scripts.OnClick()
builtManager.next.scripts.OnClick()
assert(builtManager.pageText.text == "Page 4 / 4" and
  builtManager.rows[1].itemID == 92025 and builtManager.rows[6].itemID == 92030 and
  builtManager.rows[7].itemID == nil and not builtManager.next.enabled and builtManager.previous.enabled,
  "the fourth selected-item manager page did not expose entries 25 through 30")
ShirsInventory_ClearHearthstoneItems()
ShirsInventory_RefreshHearthstoneItemsFrame()
this = constructorThis

-- Reproduce the live path: keep both settings surfaces open, then mutate the
-- selection from a carried item. Neither surface may require close/reopen.
assert(ShirsInventory_HandleItemClick(liveItemButton, "RightButton"),
  "live Ctrl-right-click add path was not handled")
assert(ShirsInventory_GetHearthstoneItemCount() == 1 and
  builtSettings.hearthstoneItemsButton.text == "Manage selected item list (1)" and
  builtManager.rows[1].itemID == 12361 and not builtManager.emptyText.visible,
  "live Ctrl-right-click add did not refresh the open manager and count immediately")
assert(ShirsInventory_HandleItemClick(liveItemButton, "RightButton"),
  "live Ctrl-right-click remove path was not handled")
assert(ShirsInventory_GetHearthstoneItemCount() == 0 and
  builtSettings.hearthstoneItemsButton.text == "Manage selected item list (0)" and
  builtManager.rows[1].itemID == nil and builtManager.emptyText.visible,
  "live Ctrl-right-click remove did not refresh the open manager and count immediately")

assert(ShirsInventory_HandleSlashCommand("pin 12361"),
  "slash pin path did not add the selected item")
assert(ShirsInventory_GetHearthstoneItemCount() == 1 and
  builtSettings.hearthstoneItemsButton.text == "Manage selected item list (1)" and
  builtManager.rows[1].itemID == 12361 and not builtManager.emptyText.visible,
  "slash pin did not refresh the open manager and count immediately")
assert(ShirsInventory_HandleSlashCommand("unpin 12361"),
  "slash unpin path did not remove the selected item")
assert(ShirsInventory_GetHearthstoneItemCount() == 0 and
  builtSettings.hearthstoneItemsButton.text == "Manage selected item list (0)" and
  builtManager.rows[1].itemID == nil and builtManager.emptyText.visible,
  "slash unpin did not refresh the open manager and count immediately")
this = constructorThis

local settingsSpecialCount, managerSpecialCount = 0, 0
local specialIndex
for specialIndex = 1, table.getn(UISpecialFrames) do
  if UISpecialFrames[specialIndex] == "ShirsInventorySettingsFrame" then settingsSpecialCount = settingsSpecialCount + 1 end
  if UISpecialFrames[specialIndex] == "ShirsInventoryHearthstoneItemsFrame" then managerSpecialCount = managerSpecialCount + 1 end
end
assert(settingsSpecialCount == 1 and managerSpecialCount == 1,
  "settings frames were not registered exactly once for Escape handling")

-- Category View scaling regression: the same window-scale percentage must not
-- render smaller in category mode just because the packed layout is tall.
-- The viewport fitter must not shrink the frame; the scroll model instead caps
-- the frame height and reports a scroll range.
assert(type(ShirsInventory_GetCategoryScrollModel) == "function",
  "category scroll model API is missing")
local scrollFit = ShirsInventory_GetCategoryScrollModel(300, 1.0, 1080, 50)
assert(scrollFit.frameHeight == 300 and scrollFit.maxScroll == 0 and not scrollFit.scrollable,
  "short category content must keep its full height without scrolling")
local scrollTall = ShirsInventory_GetCategoryScrollModel(900, 1.0, 1080, 50)
assert(scrollTall.frameHeight == 900 and scrollTall.maxScroll == 0 and not scrollTall.scrollable,
  "tall category content within the viewport must not scroll")
local scrollOverflow = ShirsInventory_GetCategoryScrollModel(1500, 1.0, 1080, 50)
assert(scrollOverflow.frameHeight == 1022 and scrollOverflow.maxScroll == 478 and scrollOverflow.scrollable,
  "tall category content past the viewport must cap the frame and report the scroll range")
local scrollScaled = ShirsInventory_GetCategoryScrollModel(1500, 0.8, 1080, 50)
assert(scrollScaled.frameHeight == 1277.5 and scrollScaled.maxScroll == 222.5 and scrollScaled.scrollable,
  "a lower window scale must widen the visible height budget")
local scrollInvalid = ShirsInventory_GetCategoryScrollModel(nil, 1.0, 1080, 50)
assert(scrollInvalid.frameHeight == 0 and scrollInvalid.maxScroll == 0 and not scrollInvalid.scrollable,
  "missing category content height must fail closed without scrolling")
local scrollZeroScreen = ShirsInventory_GetCategoryScrollModel(500, 1.0, 0, 50)
assert(scrollZeroScreen.frameHeight == 500 and scrollZeroScreen.maxScroll == 0 and
  not scrollZeroScreen.scrollable,
  "missing screen height must fail closed without scrolling")
local scrollBadScale = ShirsInventory_GetCategoryScrollModel(500, 0, 1080, 50)
assert(scrollBadScale.frameHeight == 500 and scrollBadScale.maxScroll == 0 and
  not scrollBadScale.scrollable,
  "invalid window scale must fail closed without scrolling")
assert(type(ShirsInventory_GetCategoryScrollY) == "function" and
  type(ShirsInventory_IsCategoryScrollElementVisible) == "function",
  "category scroll geometry APIs are missing")
assert(ShirsInventory_GetCategoryScrollY(-64, 0) == -64 and
  ShirsInventory_GetCategoryScrollY(-64, 478) == 414 and
  ShirsInventory_GetCategoryScrollY(nil, 10) == 10,
  "category scroll offset did not shift content upward")
assert(ShirsInventory_IsCategoryScrollElementVisible(-64, 40, 600) and
  ShirsInventory_IsCategoryScrollElementVisible(-560, 40, 600) and
  not ShirsInventory_IsCategoryScrollElementVisible(-580, 40, 600) and
  not ShirsInventory_IsCategoryScrollElementVisible(20, 40, 600) and
  ShirsInventory_IsCategoryScrollElementVisible(-64, 18, 600),
  "category scroll visibility did not respect the capped frame height")
assert(ShirsInventory_IsCategoryScrollElementVisible(-64, 40, 600, -64) and
  not ShirsInventory_IsCategoryScrollElementVisible(-60, 40, 600, -64) and
  not ShirsInventory_IsCategoryScrollElementVisible(-600, 40, 600, -64) and
  ShirsInventory_IsCategoryScrollElementVisible(-560, 40, 600, -64),
  "category scroll visibility must not climb above the bag-bar grid top")
assert(ShirsInventory_IsCategoryScrollElementVisible(-64, 40, 600, nil) and
  ShirsInventory_IsCategoryScrollElementVisible(-60, 40, 600, nil) and
  ShirsInventory_IsCategoryScrollElementVisible(-64, 40, 600, -64) and
  not ShirsInventory_IsCategoryScrollElementVisible(-60, 40, 600, -64),
  "default and explicit grid tops must agree on the strict top bound")

-- The user's exact report: at the same percentage, category mode used to be
-- smaller than normal mode because the auto-fit shrank the whole frame. With
-- the scroll model the frame keeps the requested scale and gains a scrollbar
-- instead, and expanding Empty Slots changes the scroll range, not the scale.
local scrollNumSlotsBackup = GetContainerNumSlots
local scrollItemInfoBackup = GetContainerItemInfo
local scrollItemLinkBackup = GetContainerItemLink
GetContainerNumSlots = function(bag)
  if bag == 0 then return 16 end
  if bag >= 1 and bag <= 4 then return 16 end
  return 0
end
local scrollItemTypes = { "Quest", "Key", "Miscellaneous", "Armor", "Weapon", "Container",
  "Projectile", "Recipe", "Consumable", "Consumable", "Trade Goods", "Miscellaneous" }
GetContainerItemInfo = function(bag, slot)
  local index = math.mod((bag * 16) + slot, table.getn(scrollItemTypes)) + 1
  return "texture", 1, nil, 1, scrollItemTypes[index]
end
GetContainerItemLink = function() return "|Hitem:12361:0:0:0|h[Blue Sapphire]|h" end
local scrollSlotCounts = ShirsInventory_GetInventorySlotCounts()
assert(type(scrollSlotCounts) == "table" and (scrollSlotCounts[1] or 0) > 0,
  "inventory slot counts are unavailable for the scroll regression")
local scrollSlots = ShirsInventory_BuildInventorySlots(scrollSlotCounts)
local scrollItems = ShirsInventory_BuildCategoryInventoryItems(scrollSlots)
local scrollGroups = ShirsInventory_BuildCategoryGroups(scrollItems)
local scrollLayout = ShirsInventory_BuildCategoryLayout(scrollGroups, 10)
local scrollContentHeight = scrollLayout.height + 92 + 32
local scrollModel = ShirsInventory_GetCategoryScrollModel(scrollContentHeight, 1.0, 768, 110)
assert(scrollModel.scrollable == (scrollModel.maxScroll > 0) and
  (not scrollModel.scrollable or scrollModel.frameHeight < scrollContentHeight),
  "category scroll model must only cap the frame when content exceeds the viewport")
ShirsInventoryDB.collapseEmptySlots = true
local scrollCollapsedGroups = ShirsInventory_BuildCategoryGroups(scrollItems)
local scrollCollapsedLayout = ShirsInventory_BuildCategoryLayout(scrollCollapsedGroups, 10)
local scrollCollapsedModel = ShirsInventory_GetCategoryScrollModel(
  scrollCollapsedLayout.height + 92 + 32, 1.0, 768, 110
)
ShirsInventoryDB.collapseEmptySlots = false
GetContainerNumSlots = scrollNumSlotsBackup
GetContainerItemInfo = scrollItemInfoBackup
GetContainerItemLink = scrollItemLinkBackup
assert(scrollLayout.height >= scrollCollapsedLayout.height and
  scrollModel.maxScroll >= scrollCollapsedModel.maxScroll,
  "expanded Empty Slots must not produce a shorter layout or a smaller scroll range")
assert(type(ShirsInventory_ScrollCategoryBy) == "function" and
  type(ShirsInventory_GetCategoryScrollOffset) == "function" and
  type(ShirsInventory_GetCategoryScrollMax) == "function" and
  type(ShirsInventory_GetCategoryScrollable) == "function",
  "category scroll interaction APIs are missing")
ShirsInventory_GetCategoryMode = function() return true end
assert(ShirsInventory_ScrollCategoryBy(40) == false or
  ShirsInventory_GetCategoryScrollOffset() >= 0,
  "category scroll step must stay inside its bounds")
ShirsInventory_GetCategoryMode = function() return false end

-- Runtime probe: drive the real category rebuild under the mock UI and prove
-- the user-visible bug is fixed. With the same percentage, category mode must
-- keep the requested scale and scroll, not shrink like normal mode's fitter.
local runtimeModeBackup = ShirsInventory_GetCategoryMode
local runtimeScaleBackup = ShirsInventory_GetWindowScale
local runtimeNumSlotsBackup = GetContainerNumSlots
local runtimeItemInfoBackup = GetContainerItemInfo
local runtimeItemLinkBackup = GetContainerItemLink
local runtimeBottomBar = NewRegion()
runtimeBottomBar:SetTop(104)
local runtimeBottomBackup = MainMenuBarBackpackButton
MainMenuBarBackpackButton = runtimeBottomBar
ShirsInventory_GetCategoryMode = function() return true end
ShirsInventory_GetWindowScale = function() return 1 end
ShirsInventoryDB.itemsPerRow = 10
GetContainerNumSlots = function(bag)
  if bag >= 0 and bag <= 4 then return 16 end
  return 0
end
GetContainerItemInfo = function(bag, slot)
  local index = math.mod((bag * 16) + slot, table.getn(scrollItemTypes)) + 1
  return "texture", 1, nil, 1, scrollItemTypes[index]
end
GetContainerItemLink = function() return "|Hitem:12361:0:0:0|h[Blue Sapphire]|h" end
function SetItemButtonTexture() end
function SetItemButtonCount() end
function SetItemButtonDesaturated() end
function GetContainerItemCooldown() return 0, 0, 0 end
ShirsInventory_GetJunkItems = function() return {} end
local runtimeFrame = CreateFrame("Frame", "ShirsInventoryRuntimeFrame", UIParent)
runtimeFrame.freeText = runtimeFrame:CreateFontString()
runtimeFrame.searchQuery = ""
UIParent.width = 1024
UIParent.height = 400
ShirsInventoryFrame = runtimeFrame
assert(ShirsInventory_EnableCategoryWheel(runtimeFrame) == true,
  "runtime probe must enable the category wheel on the mock frame")
local runtimeBuilt = ShirsInventory_RebuildCategoryGrid()
local runtimeScale = runtimeFrame.scale
local runtimeHeight = runtimeFrame.height
local runtimeScrollbar = nil
local constructedIndex
for constructedIndex = 1, table.getn(constructedFrames) do
  local candidate = constructedFrames[constructedIndex]
  if candidate and candidate.frameType == "Slider" and candidate.parent == runtimeFrame then
    runtimeScrollbar = candidate
  end
end
assert(runtimeBuilt == true, "category rebuild did not run under the mock UI")
assert(runtimeScale == 1, "category mode must keep the requested scale instead of shrinking")
assert(runtimeScrollbar and runtimeScrollbar.visible == true,
  "category mode must show the scrollbar when content overflows the viewport")
assert(runtimeHeight and runtimeHeight > 0 and runtimeHeight < 900,
  "category frame height must be capped by the scroll model, not left at full layout height")
local runtimeMax = ShirsInventory_GetCategoryScrollMax()
assert(runtimeMax > 0, "overflowing category content must report a positive scroll range")
assert(runtimeScrollbar.low == 0 and runtimeScrollbar.high == runtimeMax,
  "scrollbar min/max must match the category scroll model")
assert(ShirsInventory_ScrollCategoryBy(40) == true,
  "scroll step inside the range must move the category offset")
assert(ShirsInventory_GetCategoryScrollOffset() == 40,
  "scroll step must move the offset by exactly its delta")
ShirsInventory_ScrollCategoryBy(-10000)
assert(ShirsInventory_GetCategoryScrollOffset() == 0,
  "negative overflow must clamp the category offset to zero")
ShirsInventory_ScrollCategoryBy(10000)
assert(ShirsInventory_GetCategoryScrollOffset() == runtimeMax,
  "positive overflow must clamp the category offset to the scroll max")
local runtimeOffsetBeforeRebuild = ShirsInventory_GetCategoryScrollOffset()
local runtimeRebuiltAgain = ShirsInventory_RebuildCategoryGrid()
assert(runtimeRebuiltAgain == true and
  ShirsInventory_GetCategoryScrollOffset() == runtimeOffsetBeforeRebuild,
  "category rebuild must preserve the scroll offset when it stays in range")
assert(ShirsInventory_ScrollCategoryBy(-runtimeMax) == true, "scroll home must move the offset back")
local runtimeWheelBar = runtimeScrollbar
local runtimeWheelUp = false
local runtimeWheelDown = false
local runtimeWheelBackup = ShirsInventory_ScrollCategoryBy
ShirsInventory_ScrollCategoryBy = function(delta)
  if delta < 0 then runtimeWheelUp = true end
  if delta > 0 then runtimeWheelDown = true end
  return runtimeWheelBackup(delta)
end
if runtimeWheelBar and runtimeWheelBar.scripts and runtimeWheelBar.scripts.OnMouseWheel then
  arg1 = 1
  runtimeWheelBar.scripts.OnMouseWheel()
  arg1 = -1
  runtimeWheelBar.scripts.OnMouseWheel()
end
assert(runtimeWheelUp and runtimeWheelDown,
  "scrollbar wheel handler must scroll both directions")
ShirsInventory_ScrollCategoryBy = runtimeWheelBackup
assert(runtimeFrame.mouseWheelEnabled == true,
  "category frame must enable mouse-wheel events or Vanilla never fires OnMouseWheel")
assert(runtimeScrollbar.mouseWheelEnabled == true,
  "category scrollbar must enable mouse-wheel events")
-- Item buttons and category headers must forward wheel events to the same
-- category scroll path, because wheel over a child button does not reach the
-- parent frame handler in every client. Vanilla also ignores OnMouseWheel
-- unless EnableMouseWheel(true) is set on that exact child.
local runtimeButtonWheelCount = 0
local runtimeButtonWheelHandler
local runtimeHeaderWheelCount = 0
local runtimeHeaderWheelHandler
local runtimeItemWheelHandler
for constructedIndex = 1, table.getn(constructedFrames) do
  local candidate = constructedFrames[constructedIndex]
  if candidate and candidate.frameType == "Button" and candidate.parent == runtimeFrame and
    candidate.scripts and candidate.scripts.OnMouseWheel then
    if candidate.text then
      runtimeHeaderWheelCount = runtimeHeaderWheelCount + 1
      runtimeHeaderWheelHandler = runtimeHeaderWheelHandler or candidate
    else
      runtimeButtonWheelCount = runtimeButtonWheelCount + 1
      runtimeButtonWheelHandler = runtimeButtonWheelHandler or candidate
      if candidate.junkBadge then
        runtimeItemWheelHandler = runtimeItemWheelHandler or candidate
      end
    end
  end
end
assert(runtimeButtonWheelCount > 0,
  "category item buttons must expose a wheel handler")
assert(runtimeHeaderWheelCount > 0,
  "category headers must expose a wheel handler")
assert(runtimeButtonWheelHandler.mouseWheelEnabled == true,
  "category item buttons must EnableMouseWheel or Vanilla never fires their handler")
assert(runtimeHeaderWheelHandler.mouseWheelEnabled == true,
  "category headers must EnableMouseWheel or Vanilla never fires their handler")
assert(runtimeItemWheelHandler and runtimeItemWheelHandler.junkBadge and
  runtimeItemWheelHandler.junkBadge.texture == "Interface\\Icons\\INV_Misc_Coin_01" and
  runtimeItemWheelHandler.junkBadgeBack,
  "junk-marked items must show a gold coin badge instead of a red J")
arg1 = 1
runtimeItemWheelHandler.scripts.OnMouseWheel()
assert(ShirsInventory_GetCategoryScrollOffset() == 0,
  "wheel up on a category item button must scroll toward the top")
arg1 = -1
runtimeItemWheelHandler.scripts.OnMouseWheel()
assert(ShirsInventory_GetCategoryScrollOffset() > 0,
  "wheel down on a category item button must scroll down")
arg1 = 1
runtimeHeaderWheelHandler.scripts.OnMouseWheel()
assert(ShirsInventory_GetCategoryScrollOffset() == 0,
  "wheel up on a category header must scroll toward the top")
arg1 = nil
assert(ShirsInventory_GetCategoryScrollOffset() == 0,
  "wheel handler must not move the offset for a missing delta")
ShirsInventoryDB.collapseEmptySlots = true
local runtimeCollapsed = ShirsInventory_RebuildCategoryGrid()
local runtimeCollapsedMax = ShirsInventory_GetCategoryScrollMax()
local runtimeCollapsedScale = runtimeFrame.scale
ShirsInventoryDB.collapseEmptySlots = false
local runtimeExpandedMax = runtimeMax
assert(runtimeCollapsed == true,
  "category rebuild must succeed with collapsed Empty Slots")
assert(runtimeCollapsedScale == 1 and runtimeCollapsedMax <= runtimeExpandedMax,
  "collapsing Empty Slots must keep the scale and only shrink the scroll range")
ShirsInventory_GetCategoryMode = runtimeModeBackup
ShirsInventory_GetWindowScale = runtimeScaleBackup
GetContainerNumSlots = runtimeNumSlotsBackup
GetContainerItemInfo = runtimeItemInfoBackup
GetContainerItemLink = runtimeItemLinkBackup
MainMenuBarBackpackButton = runtimeBottomBackup

print("INVENTORY_OPTIONS_UI_TEST=PASS")
