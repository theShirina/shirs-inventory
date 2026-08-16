-- Shir's Inventory combined bag frame runtime.

local bagHooksInstalled
local originalBagFunctions
local installedBagFunctions
local detectedBagAddons = {}
local detectedBagSignature = ""
local bagProviderScanComplete = not CreateFrame

function ShirsInventory_GetDetectedBagAddons()
  return detectedBagAddons
end

function ShirsInventory_GetDetectedBagSignature()
  return detectedBagSignature
end

function ShirsInventory_SetDetectedBagAddons(addons)
  detectedBagAddons = addons or {}
  detectedBagSignature = ShirsInventory_GetBagAddonSignature and ShirsInventory_GetBagAddonSignature(detectedBagAddons) or ""
  bagProviderScanComplete = true
end

function ShirsInventory_IsBagUIActive()
  return true
end

function ShirsInventory_ScanLoadedBagAddons()
  local addons = {}
  if GetNumAddOns and GetAddOnInfo then
    local count = GetNumAddOns() or 0
    local index
    for index = 1, count do
      local name, title = GetAddOnInfo(index)
      local loaded = IsAddOnLoaded and IsAddOnLoaded(name or index)
      table.insert(addons, { name = name, title = title, loaded = loaded and true or false })
    end
  end
  ShirsInventory_SetDetectedBagAddons(ShirsInventory_DetectBagAddons and ShirsInventory_DetectBagAddons(addons) or {})
  return detectedBagAddons
end

local function ShirsInventory_GetFrame()
  return ShirsInventoryFrame
end

local function ShirsInventory_IsNormalBag(id)
  if id == nil then return false end
  if id >= 0 and id <= 4 then return true end
  local keyring = ShirsInventory_GetKeyRingContainerID and ShirsInventory_GetKeyRingContainerID() or (KEYRING_CONTAINER or -2)
  return id == keyring
end

function ShirsInventory_GetBagBarLayout()
  return {
    buttonSize = 26,
    gap = 0,
    iconInset = 0,
    layeredBorder = false,
    anchorPoint = "TOPLEFT",
    topOffset = -32,
    freeTextPoint = "CLOSE_LEFT",
    freeTextGap = -2,
    freeTextYOffset = 0,
    gridTopOffset = -64,
    heightExtra = 32,
  }
end

function ShirsInventory_GetSearchBoxLayout()
  return {
    height = 22,
    leftGap = 10,
    rightGap = 10,
    minimumWidth = 80,
    placeholder = "Search",
    dimAlpha = 0.2,
  }
end

function ShirsInventory_NormalizeSearchQuery(query)
  local normalized = type(query) == "string" and query or ""
  normalized = string.gsub(normalized, "^%s+", "")
  normalized = string.gsub(normalized, "%s+$", "")
  return string.lower(normalized)
end

function ShirsInventory_ItemMatchesSearch(query, itemName, itemLink)
  local normalized = ShirsInventory_NormalizeSearchQuery(query)
  if normalized == "" then return true end
  local name = itemName
  if (not name or name == "") and type(itemLink) == "string" then
    local _, _, visibleName = string.find(itemLink, "|h%[(.-)%]|h")
    name = visibleName
  end
  if type(name) ~= "string" or name == "" then return false end
  return string.find(string.lower(name), normalized, 1, true) and true or false
end

function ShirsInventory_ApplySearchToButton(button, query, itemName, itemLink)
  local matches = ShirsInventory_ItemMatchesSearch(query, itemName, itemLink)
  if button and button.SetAlpha then
    button:SetAlpha(matches and 1 or ShirsInventory_GetSearchBoxLayout().dimAlpha)
  end
  return matches
end

function ShirsInventory_GetSearchQueryForButton(button)
  if not button then return "" end
  if button.shirsInventorySearchEnabled then
    return ShirsInventoryFrame and ShirsInventoryFrame.searchQuery or ""
  end
  if button.shirsInventorySearchFrame then
    return button.shirsInventorySearchFrame.searchQuery or ""
  end
  return ""
end

function ShirsInventory_IsCursorInsideFrame(frame)
  if not frame or type(GetCursorPosition) ~= "function" or
    not frame.GetLeft or not frame.GetRight or not frame.GetBottom or not frame.GetTop then
    return false
  end
  local left, right = frame:GetLeft(), frame:GetRight()
  local bottom, top = frame:GetBottom(), frame:GetTop()
  if not left or not right or not bottom or not top then return false end
  local cursorX, cursorY = GetCursorPosition()
  local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
  scale = tonumber(scale) or 1
  if scale <= 0 then scale = 1 end
  cursorX = cursorX / scale
  cursorY = cursorY / scale
  return cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top
end

function ShirsInventory_IsCursorInsideSearchWindows()
  local inventoryVisible = ShirsInventoryFrame and
    (not ShirsInventoryFrame.IsShown or ShirsInventoryFrame:IsShown())
  if inventoryVisible and ShirsInventory_IsCursorInsideFrame(ShirsInventoryFrame) then return true end
  local bankVisible = ShirsInventoryBankFrame and
    (not ShirsInventoryBankFrame.IsShown or ShirsInventoryBankFrame:IsShown())
  if bankVisible and ShirsInventory_IsCursorInsideFrame(ShirsInventoryBankFrame) then return true end
  return false
end

local function ShirsInventory_RefreshSearchFrame(frame)
  if frame and frame == ShirsInventoryBankFrame and ShirsInventory_RefreshBankSearchFilter then
    ShirsInventory_RefreshBankSearchFilter()
  elseif ShirsInventory_RefreshSearchFilter then
    ShirsInventory_RefreshSearchFilter()
  end
end

function ShirsInventory_ClearSearch(frame, force)
  if not frame or not frame.searchBox then return false end
  if not force and ShirsInventory_GetAutoClearSearch and not ShirsInventory_GetAutoClearSearch() then
    return false
  end
  local text = frame.searchBox.GetText and frame.searchBox:GetText() or ""
  local active = ShirsInventory_NormalizeSearchQuery(frame.searchQuery) ~= "" or
    ShirsInventory_NormalizeSearchQuery(text) ~= ""
  if not active then
    if frame.searchBox.placeholder then frame.searchBox.placeholder:Show() end
    return false
  end
  frame.searchQuery = ""
  if frame.searchBox.SetText and text ~= "" then
    frame.searchBox:SetText("")
  else
    ShirsInventory_RefreshSearchFrame(frame)
  end
  if frame.searchBox.placeholder then frame.searchBox.placeholder:Show() end
  return true
end

function ShirsInventory_ProcessDeferredSearchFocus(frame)
  if not frame or not frame.searchFocusReleasePending then return false end
  frame.searchFocusReleasePending = false
  if frame.searchBox and frame.searchBox.ClearFocus then frame.searchBox:ClearFocus() end
  return true
end

function ShirsInventory_InstallWorldFrameSearchHook()
  if not WorldFrame or not WorldFrame.GetScript or not WorldFrame.SetScript then return false end
  if WorldFrame.shirsInventorySearchHookInstalled then return true end
  WorldFrame.shirsInventorySearchHookInstalled = true
  local previousMouseDown = WorldFrame:GetScript("OnMouseDown")
  WorldFrame:SetScript("OnMouseDown", function()
    local button = arg1
    if previousMouseDown then previousMouseDown() end
    if button == "LeftButton" or button == "RightButton" then
      local frame = ShirsInventoryFrame
      if frame and frame.IsShown and frame:IsShown() then
        local cleared = ShirsInventory_ClearSearch(frame)
        if cleared or frame.searchFocused then frame.searchFocusReleasePending = true end
      end
      local bankFrame = ShirsInventoryBankFrame
      if bankFrame and bankFrame.IsShown and bankFrame:IsShown() then
        local cleared = ShirsInventory_ClearSearch(bankFrame)
        if cleared or bankFrame.searchFocused then bankFrame.searchFocusReleasePending = true end
      end
    end
  end)
  return true
end

local function ShirsInventory_PackReturns(...)
  local values = arg
  if values.n == nil then values.n = table.getn(values) end
  return values
end

function ShirsInventory_InstallSpecialFrameEscapeHook()
  if type(CloseSpecialWindows) ~= "function" then return false end
  if ShirsInventorySpecialFrameEscapeHook and CloseSpecialWindows == ShirsInventorySpecialFrameEscapeHook then
    return true
  end
  local previousCloseSpecialWindows = CloseSpecialWindows
  local wrapper = function()
    ShirsInventory_ClearSearch(ShirsInventoryFrame, true)
    ShirsInventory_ClearSearch(ShirsInventoryBankFrame, true)
    local results = ShirsInventory_PackReturns(previousCloseSpecialWindows())
    return unpack(results, 1, results.n)
  end
  ShirsInventorySpecialFrameEscapeHook = wrapper
  CloseSpecialWindows = wrapper
  return true
end

function ShirsInventory_GetOneBagLayout()
  return {
    singleInventory = true,
    freeSlots = "close-left",
    headerBags = "second-row-left",
    headerActions = "second-row-right",
    footerMoney = "right",
    keepShirsSkin = true,
  }
end

local SHIRS_INVENTORY_CATEGORY_DEFINITIONS = {
  { key = "quest", label = "Quest Items" },
  { key = "keys", label = "Keys" },
  { key = "mountsCompanions", label = "Mounts & Companions" },
  { key = "armor", label = "Armor" },
  { key = "weapons", label = "Weapons" },
  { key = "equipment", label = "Equipment" },
  { key = "bags", label = "Bags" },
  { key = "ammo", label = "Projectiles & Ammo" },
  { key = "recipes", label = "Recipes" },
  { key = "foodDrink", label = "Food & Drink" },
  { key = "potions", label = "Potions" },
  { key = "elixirs", label = "Elixirs & Buffs" },
  { key = "bandages", label = "Bandages" },
  { key = "scrolls", label = "Scrolls" },
  { key = "weaponBuffs", label = "Weapon Buffs" },
  { key = "consumables", label = "Other Consumables" },
  { key = "explosives", label = "Explosives" },
  { key = "tradeGoods", label = "Trade Goods & Materials" },
  { key = "junk", label = "Junk" },
  { key = "miscellaneous", label = "Miscellaneous" },
  { key = "empty", label = "Empty Slots" },
}

local SHIRS_INVENTORY_CATEGORY_EDIT_TARGETS = {
  quest = true,
  keys = true,
  mountsCompanions = true,
  armor = true,
  weapons = true,
  equipment = true,
  bags = true,
  ammo = true,
  recipes = true,
  foodDrink = true,
  potions = true,
  elixirs = true,
  bandages = true,
  scrolls = true,
  weaponBuffs = true,
  consumables = true,
  explosives = true,
  tradeGoods = true,
  junk = true,
  miscellaneous = true,
}
local shirsInventoryCategoryEditMode
local shirsInventoryCategoryEditItemID
local shirsInventoryCategoryEditHover
local categoryHeaders = {}
local categoryScrollOffset = 0
local categoryScrollMax = 0
local CATEGORY_SCROLLBAR_WIDTH = 16
local categoryLayoutCache
local categoryBagBarLayoutCache
local categoryScrollBar
local categoryScrollBarUpdating

function ShirsInventory_GetCategoryDefinitions()
  local definitions = {}
  local index
  for index = 1, table.getn(SHIRS_INVENTORY_CATEGORY_DEFINITIONS) - 1 do
    local definition = SHIRS_INVENTORY_CATEGORY_DEFINITIONS[index]
    table.insert(definitions, { key = definition.key, label = definition.label })
  end
  local custom = ShirsInventory_GetCustomCategories and ShirsInventory_GetCustomCategories() or {}
  for index = 1, table.getn(custom) do
    table.insert(definitions, { key = custom[index].key, label = custom[index].label, custom = true })
  end
  local empty = SHIRS_INVENTORY_CATEGORY_DEFINITIONS[table.getn(SHIRS_INVENTORY_CATEGORY_DEFINITIONS)]
  table.insert(definitions, { key = empty.key, label = empty.label })
  return definitions
end

function ShirsInventory_IsCategoryEditTarget(category)
  return SHIRS_INVENTORY_CATEGORY_EDIT_TARGETS[category] == true or
    (ShirsInventory_GetCustomCategoryLabel and ShirsInventory_GetCustomCategoryLabel(category) ~= nil)
end

function ShirsInventory_GetCategoryEditMode()
  return shirsInventoryCategoryEditMode and
    ShirsInventory_GetCategoryMode and ShirsInventory_GetCategoryMode() and true or false
end

function ShirsInventory_ClearCategoryEditDrag()
  shirsInventoryCategoryEditItemID = nil
  shirsInventoryCategoryEditHover = nil
  if SetCursor then SetCursor(nil) end
  return true
end

function ShirsInventory_HasCategoryEditDrag()
  return shirsInventoryCategoryEditItemID and true or false
end

function ShirsInventory_SetCategoryEditMode(enabled)
  if enabled and ShirsInventory_ShouldDeferCategoryRebuild and ShirsInventory_ShouldDeferCategoryRebuild() then
    return false
  end
  ShirsInventory_ClearCategoryEditDrag()
  shirsInventoryCategoryEditMode = enabled and
    ShirsInventory_GetCategoryMode and ShirsInventory_GetCategoryMode() and true or false
  return ShirsInventory_GetCategoryEditMode()
end

function ShirsInventory_ToggleCategoryEditMode()
  return ShirsInventory_SetCategoryEditMode(not ShirsInventory_GetCategoryEditMode())
end

function ShirsInventory_BeginCategoryEditDrag(value)
  if not ShirsInventory_GetCategoryEditMode() then return false end
  local itemID = ShirsInventory_ParseItemID and ShirsInventory_ParseItemID(value) or tonumber(value)
  if not itemID then return false end
  shirsInventoryCategoryEditItemID = itemID
  shirsInventoryCategoryEditHover = nil
  if SetCursor then SetCursor("CAST_CURSOR") end
  return true
end

function ShirsInventory_SetCategoryEditHover(category)
  if not shirsInventoryCategoryEditItemID or not ShirsInventory_IsCategoryEditTarget(category) then
    shirsInventoryCategoryEditHover = nil
    return false
  end
  shirsInventoryCategoryEditHover = category
  return category
end

function ShirsInventory_GetCategoryEditDropTarget(headers, cursorX, cursorY)
  if cursorX == nil or cursorY == nil then
    if not GetCursorPosition then return nil end
    cursorX, cursorY = GetCursorPosition()
  end
  local frames = headers or categoryHeaders
  local index
  for index = 1, table.getn(frames) do
    local header = frames[index]
    if header and ShirsInventory_IsCategoryEditTarget(header.categoryKey) and
      (not header.IsShown or header:IsShown()) then
      local left = header.GetLeft and header:GetLeft() or nil
      local right = header.GetRight and header:GetRight() or nil
      local bottom = header.GetBottom and header:GetBottom() or nil
      local top = header.GetTop and header:GetTop() or nil
      local scale = header.GetEffectiveScale and header:GetEffectiveScale() or 1
      if left and right and bottom and top and
        cursorX >= left * scale and cursorX <= right * scale and
        cursorY >= bottom * scale and cursorY <= top * scale then
        return header.categoryKey
      end
    end
  end
  return nil
end

function ShirsInventory_FinishCategoryEditDrag()
  local itemID = shirsInventoryCategoryEditItemID
  local category = shirsInventoryCategoryEditHover
  ShirsInventory_ClearCategoryEditDrag()
  if not itemID or not category or not ShirsInventory_SetCategoryAssignment then return false end
  local assigned = ShirsInventory_SetCategoryAssignment(itemID, category)
  if assigned and ShirsInventory_Update then ShirsInventory_Update() end
  return assigned
end

local shirsInventoryCategoryClasses

local function ShirsInventory_GetCategoryClasses()
  if shirsInventoryCategoryClasses then return shirsInventoryCategoryClasses end
  local classes = GetAuctionItemClasses and {GetAuctionItemClasses()} or {}
  if table.getn(classes) > 0 then
    shirsInventoryCategoryClasses = {
      weapon = classes[1],
      armor = classes[2],
      container = classes[3],
      consumable = classes[4],
      tradeGoods = classes[5],
      projectile = classes[6],
      quiver = classes[7],
      recipe = classes[8],
      miscellaneous = classes[10],
    }
    return shirsInventoryCategoryClasses
  end
  return {
    weapon = "Weapon",
    armor = "Armor",
    container = "Container",
    consumable = "Consumable",
    tradeGoods = "Trade Goods",
    projectile = "Projectile",
    quiver = "Quiver",
    recipe = "Recipe",
    miscellaneous = "Miscellaneous",
  }
end

local function ShirsInventory_CategoryTextSignalsEnabled()
  return type(GetLocale) ~= "function" or GetLocale() == "enUS"
end

local function ShirsInventory_CategoryContains(text, needle)
  if type(text) ~= "string" or type(needle) ~= "string" then return false end
  return string.find(string.lower(text), string.lower(needle), 1, true) ~= nil
end

local function ShirsInventory_ClassifyCategorySemanticText(item, classes)
  if not ShirsInventory_CategoryTextSignalsEnabled() then return nil end
  local name = string.lower(tostring(item.name or ""))
  local tooltip = string.lower(tostring(item.tooltipText or ""))
  local consumable = item.itemType == "Consumable" or item.itemType == classes.consumable
  local tradeGoods = item.itemType == "Trade Goods" or item.itemType == classes.tradeGoods
  local miscellaneous = item.itemType == "Miscellaneous" or
    item.itemType == classes.miscellaneous or item.itemType == nil
  if miscellaneous and (
    string.find(tooltip, "summons and dismisses a rideable", 1, true) or
    string.find(tooltip, "emits a high frequency sound", 1, true) or
    string.find(tooltip, "right click to summon and dismiss your", 1, true)
  ) then
    return "mountsCompanions"
  end
  if consumable and (
    string.find(tooltip, "must remain seated while eating", 1, true) or
    string.find(tooltip, "must remain seated while drinking", 1, true)
  ) then
    return "foodDrink"
  end
  if consumable and string.find(name, "potion", 1, true) then return "potions" end
  if consumable and (
    string.find(name, "elixir", 1, true) or string.find(name, "flask", 1, true)
  ) then return "elixirs" end
  if consumable and (
    string.find(name, "bandage", 1, true) or string.find(name, "anti-venom", 1, true) or
    string.find(name, "antivenom", 1, true)
  ) then return "bandages" end
  if consumable and string.sub(name, 1, 10) == "scroll of " then return "scrolls" end
  if (consumable or tradeGoods) and (
    string.find(name, "frost oil", 1, true) or string.find(name, "shadow oil", 1, true) or
    string.find(name, "mana oil", 1, true) or string.find(name, "wizard oil", 1, true) or
    string.find(name, "sharpening stone", 1, true) or string.find(name, "weightstone", 1, true)
  ) then return "weaponBuffs" end
  return nil
end

function ShirsInventory_ClassifyCategoryItem(item)
  if not item or not item.hasItem then return "empty" end
  if item.manualCategory then return item.manualCategory end
  local junkMarks = (ShirsInventoryDB and ShirsInventoryDB.junkItems) or nil
  if item.itemID and junkMarks and junkMarks[item.itemID] then return "junk" end
  local classes = ShirsInventory_GetCategoryClasses()
  if item.itemType == "Recipe" or item.itemType == classes.recipe then return "recipes" end
  if item.itemType == "Quest" or item.quest or
    (ShirsInventory_CategoryTextSignalsEnabled() and
      ShirsInventory_CategoryContains(item.tooltipText, "Quest Item")) then return "quest" end
  if item.itemType == "Key" then return "keys" end
  local semantic = ShirsInventory_ClassifyCategorySemanticText(item, classes)
  if semantic then return semantic end
  if item.itemType == "Armor" or item.itemType == classes.armor then return "armor" end
  if item.itemType == "Weapon" or item.itemType == classes.weapon then return "weapons" end
  if item.itemType == "Container" or item.itemType == "Quiver" or
    item.itemType == classes.container or item.itemType == classes.quiver then return "bags" end
  if item.itemType == "Projectile" or item.itemType == classes.projectile then return "ammo" end
  if item.itemSubType == "Explosives" then return "explosives" end
  if item.itemType == "Consumable" or item.itemType == classes.consumable then return "consumables" end
  if item.itemType == "Trade Goods" or item.itemType == classes.tradeGoods or
    item.materialCategory then return "tradeGoods" end
  if tonumber(item.quality) == 0 then return "junk" end
  return "miscellaneous"
end

function ShirsInventory_BuildCategoryGroups(items)
  local definitions = ShirsInventory_GetCategoryDefinitions()
  local groupsByKey = {}
  local definitionIndex
  for definitionIndex = 1, table.getn(definitions) do
    local definition = definitions[definitionIndex]
    groupsByKey[definition.key] = {
      key = definition.key,
      label = definition.label,
      custom = definition.custom,
      items = {},
    }
  end
  local itemIndex
  for itemIndex = 1, table.getn(items or {}) do
    local item = items[itemIndex]
    local key = ShirsInventory_ClassifyCategoryItem(item)
    table.insert(groupsByKey[key].items, item)
  end
  local emptyGroup = groupsByKey.empty
  if emptyGroup then
    emptyGroup.totalCount = table.getn(emptyGroup.items)
    if emptyGroup.totalCount > 1 and ShirsInventory_GetCollapseEmptySlots and
      ShirsInventory_GetCollapseEmptySlots() then
      local representative = {}
      local field, value
      for field, value in pairs(emptyGroup.items[1]) do representative[field] = value end
      representative.collapsedEmptyCount = emptyGroup.totalCount
      emptyGroup.items = { representative }
    end
  end
  local groups = {}
  for definitionIndex = 1, table.getn(definitions) do
    local definition = definitions[definitionIndex]
    local group = groupsByKey[definition.key]
    if table.getn(group.items) > 0 or group.custom then
      local buckets, bucketOrder = {}, {}
      local groupItemIndex
      for groupItemIndex = 1, table.getn(group.items) do
        local item = group.items[groupItemIndex]
        local bucketKey
        if item.hasItem and item.itemID then
          bucketKey = "item:" .. item.itemID
        else
          bucketKey = "slot:" .. tostring(item.bag) .. ":" .. tostring(item.slot)
        end
        if not buckets[bucketKey] then
          buckets[bucketKey] = {}
          table.insert(bucketOrder, bucketKey)
        end
        table.insert(buckets[bucketKey], item)
      end
      group.items = {}
      for groupItemIndex = 1, table.getn(bucketOrder) do
        local bucket = buckets[bucketOrder[groupItemIndex]]
        local copyIndex
        for copyIndex = 1, table.getn(bucket) do table.insert(group.items, bucket[copyIndex]) end
      end
      table.insert(groups, group)
    end
  end
  return groups
end

function ShirsInventory_GetCategoryGroupCount(group)
  if not group then return 0 end
  return group.totalCount or table.getn(group.items or {})
end

function ShirsInventory_GetCategoryHeaderText(group)
  if not group then return "" end
  if group.hideHeaderCount then return group.label or "" end
  return (group.label or "") .. " (" .. ShirsInventory_GetCategoryGroupCount(group) .. ")"
end

local SHIRS_INVENTORY_COMPACT_CATEGORY_LABELS = {
  quest = "Quest",
  keys = "Keys",
  mountsCompanions = "Pets",
  armor = "Armor",
  weapons = "Weap.",
  equipment = "Gear",
  bags = "Bags",
  ammo = "Ammo",
  recipes = "Recipe",
  foodDrink = "Food",
  potions = "Pots",
  elixirs = "Buffs",
  bandages = "Aid",
  scrolls = "Scroll",
  weaponBuffs = "W.Buff",
  consumables = "Other",
  explosives = "Bombs",
  tradeGoods = "Mats",
  junk = "Junk",
  miscellaneous = "Misc",
  empty = "Empty",
}

function ShirsInventory_GetCategoryHeaderTooltipText(group)
  if not group then return "" end
  if group.tooltipLabel then
    return group.tooltipLabel .. " (" .. ShirsInventory_GetCategoryGroupCount(group) .. ")"
  end
  return ShirsInventory_GetCategoryHeaderText(group)
end

local function ShirsInventory_EncodeCompactCategoryID(value)
  local digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  local number = math.floor(tonumber(value) or 0)
  if number <= 0 then return nil end
  local encoded = ""
  while number > 0 do
    local remainder = math.mod(number, 36)
    encoded = string.sub(digits, remainder + 1, remainder + 1) .. encoded
    number = math.floor(number / 36)
  end
  return encoded
end

function ShirsInventory_GetCategoryHeaderDisplayText(group)
  if not group then return "" end
  local fullText = ShirsInventory_GetCategoryHeaderText(group)
  local maximumCharacters = math.max(1, tonumber(group.columns) or 1) * 6
  if string.len(fullText) <= maximumCharacters then return fullText end
  local compact = SHIRS_INVENTORY_COMPACT_CATEGORY_LABELS[group.key]
  if not compact and type(group.key) == "string" then
    local _, _, customID = string.find(group.key, "^custom:(%d+)$")
    local encodedID = customID and ShirsInventory_EncodeCompactCategoryID(customID) or nil
    if encodedID then compact = "C" .. encodedID end
  end
  compact = compact or "Group"
  local compactWithCount = compact
  if not group.hideHeaderCount then
    compactWithCount = compact .. " (" .. ShirsInventory_GetCategoryGroupCount(group) .. ")"
  end
  if string.len(compactWithCount) <= maximumCharacters then return compactWithCount end
  if string.len(compact) <= maximumCharacters then return compact end
  return string.sub(compact, 1, maximumCharacters)
end

function ShirsInventory_BuildCategoryFreeStates(items)
  local states = {}
  local index
  for index = 1, table.getn(items or {}) do
    table.insert(states, { bag = items[index].bag, hasItem = items[index].hasItem })
  end
  return states
end

function ShirsInventory_BuildCategoryLayout(groups, columns)
  columns = math.max(10, math.min(20, math.floor(tonumber(columns) or 10)))
  local layout = {
    columns = columns,
    width = 28 + columns * 40,
    height = 0,
    groups = {},
  }
  local shelf = {}
  local shelfColumns = 0
  local shelfRows = 0

  local function FinishShelf()
    if table.getn(shelf) == 0 then return end
    local shelfHeight = 18 + shelfRows * 40 + 8
    local shelfIndex
    for shelfIndex = 1, table.getn(shelf) do
      local group = shelf[shelfIndex]
      group.labelY = layout.height
      group.itemY = layout.height + 18
      table.insert(layout.groups, group)
    end
    layout.height = layout.height + shelfHeight
    shelf = {}
    shelfColumns = 0
    shelfRows = 0
  end

  local groupIndex
  for groupIndex = 1, table.getn(groups or {}) do
    local source = groups[groupIndex]
    local itemCount = table.getn(source.items or {})
    local groupColumns = math.min(columns, math.max(1, itemCount))
    local collapsedEmpty = source.key == "empty" and itemCount == 1 and
      source.items[1] and source.items[1].collapsedEmptyCount
    local separatorColumns = shelfColumns > 0 and 1 or 0
    local columnX
    if collapsedEmpty then
      columnX = columns - 1
      if shelfColumns > 0 and shelfColumns + 1 > columnX then
        FinishShelf()
      end
      columnX = columns - 1
    else
      if shelfColumns > 0 and shelfColumns + separatorColumns + groupColumns > columns then
        FinishShelf()
        separatorColumns = 0
      end
      columnX = shelfColumns + separatorColumns
    end
    local rows = math.ceil(itemCount / groupColumns)
    local group = {
      key = source.key,
      label = collapsedEmpty and "Empty" or source.label,
      tooltipLabel = source.label,
      hideHeaderCount = collapsedEmpty and true or nil,
      items = source.items,
      totalCount = ShirsInventory_GetCategoryGroupCount(source),
      columnX = columnX,
      columns = groupColumns,
      rows = rows,
    }
    table.insert(shelf, group)
    if collapsedEmpty then
      shelfColumns = columns
    else
      shelfColumns = columnX + groupColumns
    end
    shelfRows = math.max(shelfRows, rows)
  end
  FinishShelf()
  return layout
end

function ShirsInventory_ShouldShowInventoryAction(action, bank)
  if bank or not (ShirsInventory_GetCategoryMode and ShirsInventory_GetCategoryMode()) then return true end
  return action == "sort" or action == "mode" or action == "settings"
end

function ShirsInventory_GetRarityBorderLayout()
  return {
    thickness = 1,
    inset = 1,
    texture = "Interface\\Buttons\\WHITE8X8",
    minimumQuality = 2,
    preserveOuterFrame = true,
    cornerStyle = "square",
  }
end

function ShirsInventory_ShouldShowRarityBorder(texture, quality, enabled)
  local layout = ShirsInventory_GetRarityBorderLayout()
  return texture and enabled and type(quality) == "number" and quality >= layout.minimumQuality and true or false
end

function ShirsInventory_GetQualityColor(quality)
  if type(quality) ~= "number" then return nil end
  if GetItemQualityColor then
    local r, g, b = GetItemQualityColor(quality)
    if r then return {r = r, g = g, b = b} end
  end
  local color = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[quality] or nil
  if not color then color = getglobal and getglobal("ITEM_QUALITY" .. quality .. "_COLOR") or nil end
  if type(color) == "table" then
    local r = color.r or color[1]
    local g = color.g or color[2]
    local b = color.b or color[3]
    if r and g and b then return {r = r, g = g, b = b} end
  end
  return nil
end

function ShirsInventory_GetItemInfoFields(item)
  if not item or not GetItemInfo then return {} end
  local query = item
  if type(item) == "string" then
    local _, _, itemToken = string.find(item, "(item:%d+:%d*:%d*:%d*)")
    if itemToken then query = itemToken end
  end
  local info = {GetItemInfo(query)}
  local itemType, itemSubType, maxStack, inventoryType
  if type(info[5]) == "string" then
    itemType = info[5]
    itemSubType = info[6]
    maxStack = info[7]
    inventoryType = info[8]
  else
    itemType = info[6]
    itemSubType = info[7]
    maxStack = info[8]
    inventoryType = info[9]
  end
  return {
    name = info[1],
    link = info[2],
    quality = info[3],
    itemType = itemType,
    itemSubType = itemSubType,
    maxStack = maxStack,
    inventoryType = inventoryType,
  }
end

function ShirsInventory_IsQuestItemType(itemType)
  if not itemType then return false end
  if itemType == "Quest" then return true end
  if type(ITEM_CLASS_QUEST) == "string" and itemType == ITEM_CLASS_QUEST then return true end
  return false
end

function ShirsInventory_IsQuestBorderItem(itemType, quality)
  if not ShirsInventory_IsQuestItemType(itemType) then return false end
  return not (type(quality) == "number" and
    quality >= ShirsInventory_GetRarityBorderLayout().minimumQuality)
end

function ShirsInventory_ResolveItemQuality(containerQuality, itemInfoQuality)
  if type(containerQuality) == "number" and containerQuality > 0 then return containerQuality end
  if type(itemInfoQuality) == "number" then return itemInfoQuality end
  return containerQuality
end

function ShirsInventory_GetItemBorderModel(texture, quality, itemType, enabled)
  if not texture or not enabled then return nil end
  if ShirsInventory_ShouldShowRarityBorder(texture, quality, true) then
    local color = ShirsInventory_GetQualityColor(quality)
    if color then return {kind = "rarity", r = color.r, g = color.g, b = color.b, a = 1} end
  end
  if ShirsInventory_IsQuestBorderItem(itemType, quality) then
    return {kind = "quest", r = 1, g = 0.8, b = 0.2, a = 0.8}
  end
  return nil
end

function ShirsInventory_IsRecipeItemType(itemType)
  if not itemType then return false end
  if itemType == "Recipe" then return true end
  if type(ITEM_CLASS_RECIPE) == "string" and itemType == ITEM_CLASS_RECIPE then return true end
  return false
end

function ShirsInventory_IsRequirementUnmetColor(r, g, b)
  if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return false end
  return r >= 0.85 and g <= 0.35 and b <= 0.35
end

local function ShirsInventory_TooltipTemplatePrefix(template)
  if type(template) ~= "string" or template == "" then return nil end
  local markerStart = string.find(template, "%%s")
  if not markerStart then markerStart = string.find(template, "%%d") end
  if not markerStart then return template end
  return string.sub(template, 1, markerStart - 1)
end

local function ShirsInventory_TextHasPrefix(text, prefix)
  if type(text) ~= "string" or type(prefix) ~= "string" or prefix == "" then return false end
  return string.sub(text, 1, string.len(prefix)) == prefix
end

local function ShirsInventory_IsProfessionRequirementText(text)
  if type(text) ~= "string" or text == "" then return false end
  local levelPrefix = ShirsInventory_TooltipTemplatePrefix(ITEM_MIN_LEVEL)
  if ShirsInventory_TextHasPrefix(text, levelPrefix or "Requires Level ") then return false end
  local skillPrefix = ShirsInventory_TooltipTemplatePrefix(ITEM_MIN_SKILL)
  local reqPrefix = ShirsInventory_TooltipTemplatePrefix(ITEM_REQ_SKILL)
  if ShirsInventory_TextHasPrefix(text, skillPrefix) then return true end
  if ShirsInventory_TextHasPrefix(text, reqPrefix) then return true end
  local lower = string.lower(text)
  return string.find(lower, "^requires ") ~= nil and string.find(lower, "^requires level ") == nil
end

function ShirsInventory_GetRecipeLearnStatusFromLines(lines)
  if type(lines) ~= "table" then return nil end
  local knownText = type(ITEM_SPELL_KNOWN) == "string" and ITEM_SPELL_KNOWN or "Already known"
  local alreadyKnown = false
  local skillTooLow = false
  local index
  for index = 1, table.getn(lines) do
    local line = lines[index]
    local text = line and line.text or nil
    if type(text) == "string" and text ~= "" then
      if text == knownText or string.lower(text) == "already known" then
        alreadyKnown = true
      elseif ShirsInventory_IsProfessionRequirementText(text) and
        ShirsInventory_IsRequirementUnmetColor(line.r, line.g, line.b) then
        skillTooLow = true
      end
    end
  end
  if alreadyKnown then return "already_known" end
  if skillTooLow then return "skill_too_low" end
  return nil
end

function ShirsInventory_GetRecipeStatusVisual(status)
  if status == "already_known" then
    return {
      kind = "recipeAlreadyKnown",
      r = 0.15, g = 0.72, b = 0.62, a = 1,
      fillR = 0.08, fillG = 0.28, fillB = 0.26, fillA = 0.42,
    }
  end
  if status == "skill_too_low" then
    return {
      kind = "recipeSkillTooLow",
      r = 0.95, g = 0.45, b = 0.08, a = 1,
      fillR = 0.42, fillG = 0.18, fillB = 0.02, fillA = 0.40,
    }
  end
  return nil
end

function ShirsInventory_GetItemVisualModel(texture, quality, itemType, enabled, recipeStatus)
  if not texture then return nil end
  if ShirsInventory_IsRecipeItemType(itemType) then
    local visual = ShirsInventory_GetRecipeStatusVisual(recipeStatus)
    if visual then return visual end
  end
  return ShirsInventory_GetItemBorderModel(texture, quality, itemType, enabled)
end

local recipeStatusTooltip

local function ShirsInventory_EnsureRecipeStatusTooltip()
  if recipeStatusTooltip or type(CreateFrame) ~= "function" then return recipeStatusTooltip end
  recipeStatusTooltip = CreateFrame("GameTooltip", "ShirsInventoryRecipeTooltip", nil, "GameTooltipTemplate")
  return recipeStatusTooltip
end

local function ShirsInventory_ReadNamedTooltipLine(prefix, line)
  if type(getglobal) ~= "function" then return nil end
  local region = getglobal(prefix .. line)
  if not region or type(region.GetText) ~= "function" then return nil end
  local text = region:GetText()
  if type(text) ~= "string" or text == "" then return nil end
  local r, g, b
  if type(region.GetTextColor) == "function" then
    r, g, b = region:GetTextColor()
  end
  return { text = text, r = r, g = g, b = b }
end

function ShirsInventory_CollectTooltipLines(bag, slot)
  local tooltip = ShirsInventory_EnsureRecipeStatusTooltip()
  if not tooltip or type(tooltip.SetOwner) ~= "function" then return nil end
  tooltip:SetOwner(UIParent, "ANCHOR_NONE")
  if type(tooltip.ClearLines) == "function" then tooltip:ClearLines() end
  if bag == BANK_CONTAINER and type(tooltip.SetInventoryItem) == "function" then
    tooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(slot))
  elseif type(tooltip.SetBagItem) == "function" then
    tooltip:SetBagItem(bag, slot)
  else
    return nil
  end
  local lineCount = type(tooltip.NumLines) == "function" and tooltip:NumLines() or 0
  local lines = {}
  local line
  for line = 1, lineCount do
    local entry = ShirsInventory_ReadNamedTooltipLine("ShirsInventoryRecipeTooltipTextLeft", line)
    if entry then table.insert(lines, entry) end
  end
  return lines
end

function ShirsInventory_GetRecipeLearnStatusForSlot(bag, slot, itemType)
  if not ShirsInventory_IsRecipeItemType(itemType) then return nil end
  return ShirsInventory_GetRecipeLearnStatusFromLines(ShirsInventory_CollectTooltipLines(bag, slot))
end

function ShirsInventory_GetClampedTopLeft(left, top, width, height, screenWidth, screenHeight,
  margin, bottomMargin, rightMargin, topMargin)
  margin = margin or 8
  bottomMargin = bottomMargin or margin
  if rightMargin == nil then rightMargin = margin end
  if topMargin == nil then topMargin = margin end
  local maximumLeft = screenWidth - rightMargin - width
  if maximumLeft < margin then maximumLeft = margin end
  if left < margin then left = margin end
  if left > maximumLeft then left = maximumLeft end
  local maximumTop = screenHeight - topMargin
  local minimumTop = height + bottomMargin
  if minimumTop > maximumTop then minimumTop = maximumTop end
  if top > maximumTop then top = maximumTop end
  if top < minimumTop then top = minimumTop end
  return left, top
end

function ShirsInventory_GetFittedWindowScale(width, height, requestedScale, screenWidth, screenHeight,
  margin, bottomMargin, rightMargin, topMargin)
  width = tonumber(width) or 0
  height = tonumber(height) or 0
  requestedScale = tonumber(requestedScale) or 1
  screenWidth = tonumber(screenWidth) or 0
  screenHeight = tonumber(screenHeight) or 0
  margin = tonumber(margin) or 8
  bottomMargin = tonumber(bottomMargin) or margin
  if rightMargin == nil then rightMargin = margin else rightMargin = tonumber(rightMargin) or margin end
  if topMargin == nil then topMargin = margin else topMargin = tonumber(topMargin) or margin end
  if width <= 0 or height <= 0 or screenWidth <= 0 or screenHeight <= 0 then
    return requestedScale
  end
  local fitted = requestedScale
  local widthScale = (screenWidth - margin - rightMargin) / width
  local heightScale = (screenHeight - topMargin - bottomMargin) / height
  if widthScale < fitted then fitted = widthScale end
  if heightScale < fitted then fitted = heightScale end
  if fitted < 0.1 then fitted = 0.1 end
  return fitted
end

-- Category View keeps the user's chosen window scale; when the packed layout is
-- taller than the screen it scrolls instead of shrinking. This pure function
-- returns the frame height to use and the maximum scroll offset in pixels.
function ShirsInventory_GetCategoryScrollModel(contentHeight, requestedScale, screenHeight,
  bottomMargin)
  contentHeight = tonumber(contentHeight) or 0
  requestedScale = tonumber(requestedScale) or 1
  screenHeight = tonumber(screenHeight) or 0
  bottomMargin = tonumber(bottomMargin) or 8
  if contentHeight <= 0 or requestedScale <= 0 or screenHeight <= 0 then
    return { frameHeight = contentHeight, maxScroll = 0, scrollable = false }
  end
  local availableHeight = (screenHeight - 8 - bottomMargin) / requestedScale
  if availableHeight <= 0 or contentHeight <= availableHeight then
    return { frameHeight = contentHeight, maxScroll = 0, scrollable = false }
  end
  return {
    frameHeight = availableHeight,
    maxScroll = contentHeight - availableHeight,
    scrollable = true,
  }
end

-- Pure geometry for a scrolled Category View element. offset is the current
-- scroll offset in pixels; positive offset moves content up (reveals lower
-- shelves). Returns the TOPLEFT y offset relative to the frame.
function ShirsInventory_GetCategoryScrollY(baseY, offset)
  baseY = tonumber(baseY) or 0
  offset = tonumber(offset) or 0
  return baseY + offset
end

-- An element (header or item button) is visible when it sits entirely inside
-- the scrollable band: below the content-area top edge (gridTop, default the
-- frame top) and above the frame's bottom edge. Strict bounds avoid drawing
-- over the bag bar or below the frame.
function ShirsInventory_IsCategoryScrollElementVisible(displayY, height, frameHeight, gridTop)
  displayY = tonumber(displayY) or 0
  height = tonumber(height) or 0
  frameHeight = tonumber(frameHeight) or 0
  gridTop = gridTop == nil and 0 or (tonumber(gridTop) or 0)
  if frameHeight <= 0 then return true end
  return displayY <= gridTop and displayY >= -frameHeight + height
end

function ShirsInventory_BuildBagBarModel()
  local result = {}
  local nextInventoryIndex = 1
  local bag
  for bag = 0, 4 do
    local inventoryID
    local texture
    if bag == 0 then
      texture = "Interface\\Icons\\INV_Misc_Bag_08"
    else
      if ContainerIDToInventoryID then
        inventoryID = ContainerIDToInventoryID(bag)
      else
        inventoryID = 19 + bag
      end
      if GetInventoryItemTexture then texture = GetInventoryItemTexture("player", inventoryID) end
    end
    local slots = GetContainerNumSlots and (GetContainerNumSlots(bag) or 0) or 0
    table.insert(result, {
      bag = bag,
      inventoryID = inventoryID,
      texture = texture or "Interface\\Icons\\INV_Misc_Bag_10",
      slots = slots,
      empty = (bag > 0 and (not texture or slots == 0)) and true or false,
      firstInventoryIndex = slots > 0 and nextInventoryIndex or nil,
      lastInventoryIndex = slots > 0 and (nextInventoryIndex + slots - 1) or nil,
    })
    nextInventoryIndex = nextInventoryIndex + slots
  end
  local keyring = ShirsInventory_GetKeyRingContainerID and ShirsInventory_GetKeyRingContainerID() or (KEYRING_CONTAINER or -2)
  local keyringSlots
  if ShirsInventory_GetKeyRingSize then
    keyringSlots = ShirsInventory_GetKeyRingSize()
  elseif type(GetKeyRingSize) == "function" then
    keyringSlots = tonumber(GetKeyRingSize()) or 0
  else
    keyringSlots = 0
  end
  local keyringShown = not ShirsInventory_GetKeyRingSlotsShown or ShirsInventory_GetKeyRingSlotsShown()
  table.insert(result, {
    bag = keyring,
    texture = "Interface\\ContainerFrame\\KeyRing-Bag-Icon",
    slots = keyringSlots,
    empty = false,
    keyring = true,
    fixed = true,
    collapsed = not keyringShown,
    firstInventoryIndex = keyringShown and keyringSlots > 0 and nextInventoryIndex or nil,
    lastInventoryIndex = keyringShown and keyringSlots > 0 and (nextInventoryIndex + keyringSlots - 1) or nil,
  })
  return result
end

function ShirsInventory_ShouldHighlightBagSlot(button, bag)
  return button and button.bag == bag and true or false
end

function ShirsInventory_HandleBagBarDrop(button)
  local entry = button and button.bagEntry or nil
  if not entry or entry.bag == 0 or not entry.inventoryID or type(PutItemInBag) ~= "function" then
    return false
  end
  PutItemInBag(entry.inventoryID)
  return true
end

function ShirsInventory_HandleBagBarDragStart(button)
  local entry = button and button.bagEntry or nil
  if not entry or entry.fixed then return false end
  return ShirsInventory_HandleBagBarClick(button, "LeftButton")
end

function ShirsInventory_HandleBagBarReceiveDrag(button)
  local entry = button and button.bagEntry or nil
  if not entry or entry.fixed then return false end
  return ShirsInventory_HandleBagBarDrop(button)
end

function ShirsInventory_HandleBagBarClick(button, mouseButton)
  local entry = button and button.bagEntry or nil
  if mouseButton ~= "LeftButton" or not entry then
    return false
  end
  if entry.keyring then
    if not ShirsInventory_ToggleKeyRingSlots then return false end
    ShirsInventory_ToggleKeyRingSlots()
    if ShirsInventory_Update then ShirsInventory_Update() end
    return true
  end
  if entry.bag == 0 or not entry.inventoryID then return false end
  -- A release after dragging a bag can arrive through the click path on these
  -- custom buttons. Match the stock BagSlotButton cursor path instead of
  -- picking up the equipped bag and undoing the drop.
  if type(CursorHasItem) == "function" and CursorHasItem() then
    return ShirsInventory_HandleBagBarDrop(button)
  end
  if type(PickupBagFromSlot) ~= "function" then return false end
  PickupBagFromSlot(entry.inventoryID)
  return true
end

function ShirsInventory_GetBagBarActionHint(entry)
  if not entry or entry.bag == 0 then return "Built-in Backpack; it cannot be removed." end
  if entry.keyring then
    if entry.collapsed then return "Left-click to show Keyring slots." end
    return "Left-click to hide Keyring slots."
  end
  if entry.empty then return "Drop a bag here." end
  return "Left-click or drag to remove or swap this bag."
end

function ShirsInventory_Message(text)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff68ccefShir's Inventory:|r " .. text)
  end
end

function ShirsInventory_HandleItemClick(button, mouseButton, ignoreModifiers)
  local bag, slot = button.bag, button.slot
  local keyring = ShirsInventory_GetKeyRingContainerID and ShirsInventory_GetKeyRingContainerID() or (KEYRING_CONTAINER or -2)
  if bag == keyring then
    if type(KeyRingItemButton_OnClick) ~= "function" then return false end
    KeyRingItemButton_OnClick(mouseButton)
    return true
  end
  local texture, count, locked, quality = GetContainerItemInfo(bag, slot)
  if ShirsInventory_GetCategoryEditMode and ShirsInventory_GetCategoryEditMode() then
    if not texture then return true end
    local itemID = ShirsInventory_GetItemId(GetContainerItemLink(bag, slot))
    if mouseButton == "RightButton" and not ignoreModifiers then
      ShirsInventory_ClearCategoryEditDrag()
      local cleared = ShirsInventory_ClearCategoryAssignment and ShirsInventory_ClearCategoryAssignment(itemID)
      if cleared and ShirsInventory_Message then
        ShirsInventory_Message("Returned this item type to automatic category placement.")
      end
      if cleared and ShirsInventory_Update then ShirsInventory_Update() end
      return true
    end
    if mouseButton == "LeftButton" then
      return ShirsInventory_BeginCategoryEditDrag and ShirsInventory_BeginCategoryEditDrag(itemID) or false
    end
    return true
  end
  if not texture then
    if mouseButton == "LeftButton" then
      PickupContainerItem(bag, slot)
      if StackSplitFrame then StackSplitFrame:Hide() end
    end
    return true
  end

  if mouseButton == "RightButton" and not ignoreModifiers and bag >= 0 and bag <= 4 and
    not (ShirsInventory_GetCategoryMode and ShirsInventory_GetCategoryMode()) and
    IsControlKeyDown and IsControlKeyDown() and not (IsAltKeyDown and IsAltKeyDown()) then
    local itemId = ShirsInventory_GetItemId(GetContainerItemLink(bag, slot))
    local ok, status = ShirsInventory_ToggleHearthstoneItem(itemId)
    if status == "added" then
      if ShirsInventory_GetLockSelectedItemSlots() then
        ShirsInventory_Message("Added this item type to the selected list. Its carried slots will stay locked during sorting.")
      elseif ShirsInventory_GetAutomaticHearthstoneItems() then
        ShirsInventory_Message("Added this item type to the selected list. Switch to Selected mode to use it.")
      else
        ShirsInventory_Message("Added this item type beside Hearthstone.")
      end
    elseif status == "removed" then
      ShirsInventory_Message("Removed this item type from the selected list.")
    elseif status == "fixed" then
      ShirsInventory_Message("Hearthstone is always fixed at the selected edge.")
    elseif status == "full" then
      ShirsInventory_Message("The selected item list is full (30).")
    elseif not ok then
      ShirsInventory_Message("This item could not be added to the selected list.")
    end
    if type(ShirsInventory_RefreshHearthstoneItemsFrame) == "function" then
      ShirsInventory_RefreshHearthstoneItemsFrame()
    end
    if ShirsInventory_Update then ShirsInventory_Update() end
    if ShirsInventoryBankFrame and ShirsInventoryBankFrame.IsShown and
      ShirsInventoryBankFrame:IsShown() and ShirsInventory_UpdateBank then
      ShirsInventory_UpdateBank()
    end
    return true
  end

  if mouseButton == "RightButton" and not ignoreModifiers and
    (not ShirsInventory_IsFeatureEnabled or ShirsInventory_IsFeatureEnabled("junk")) and
    IsAltKeyDown and IsAltKeyDown() then
    local itemId = ShirsInventory_GetItemId(GetContainerItemLink(bag, slot))
    local marked, reason = ShirsInventory_ToggleJunk(itemId, quality)
    if reason == "automatic" then
      ShirsInventory_Message("Gray items are always junk.")
    elseif marked then
      ShirsInventory_Message("Marked this item type as junk.")
    elseif reason == "unmarked" then
      ShirsInventory_Message("Removed this item type from junk.")
    end
    if ShirsInventory_Update then ShirsInventory_Update() end
    if ShirsInventoryBankFrame and ShirsInventoryBankFrame.IsShown and
      ShirsInventoryBankFrame:IsShown() and ShirsInventory_UpdateBank then
      ShirsInventory_UpdateBank()
    end
    return true
  end

  if mouseButton == "LeftButton" then
    if not ignoreModifiers and IsControlKeyDown and IsControlKeyDown() then
      if DressUpItemLink then DressUpItemLink(GetContainerItemLink(bag, slot)) end
    elseif not ignoreModifiers and IsShiftKeyDown and IsShiftKeyDown() then
      if WIM_EditBoxInFocus and WIM_EditBoxInFocus.Insert then
        WIM_EditBoxInFocus:Insert(GetContainerItemLink(bag, slot))
      elseif ChatFrameEditBox and ChatFrameEditBox:IsShown() then
        ChatFrameEditBox:Insert(GetContainerItemLink(bag, slot))
      elseif not locked and count and count > 1 and OpenStackSplitFrame then
        button.SplitStack = function(_, split)
          SplitContainerItem(bag, slot, split)
        end
        OpenStackSplitFrame(count, button, "BOTTOMRIGHT", "TOPRIGHT")
      end
    else
      PickupContainerItem(bag, slot)
      if StackSplitFrame then StackSplitFrame:Hide() end
    end
    return true
  end

  if not ignoreModifiers and IsControlKeyDown and IsControlKeyDown() then
    return true
  end
  if MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 2 then
    return true
  end

  UseContainerItem(bag, slot)
  if StackSplitFrame then StackSplitFrame:Hide() end
  return true
end

function ShirsInventory_InstallBagHooks()
  if bagHooksInstalled then return end
  bagHooksInstalled = true

  originalBagFunctions = {
    ToggleBackpack = ToggleBackpack,
    OpenBackpack = OpenBackpack,
    CloseBackpack = CloseBackpack,
    OpenAllBags = OpenAllBags,
    CloseAllBags = CloseAllBags,
    ToggleBag = ToggleBag,
    OpenBag = OpenBag,
    CloseBag = CloseBag,
    IsBagOpen = IsBagOpen,
    ToggleKeyRing = ToggleKeyRing,
  }

  local function CanOpenIntegratedBags()
    if type(CanOpenPanels) == "function" and not CanOpenPanels() then
      if type(UnitIsDead) == "function" and UnitIsDead("player") and type(NotWhileDeadError) == "function" then
        NotWhileDeadError()
      end
      return false
    end
    return true
  end

  ToggleBackpack = function()
    if type(IsOptionFrameOpen) == "function" and IsOptionFrameOpen() then return end
    local frame = ShirsInventory_GetFrame()
    if frame:IsShown() then frame:Hide() else frame:Show() end
  end

  OpenBackpack = function()
    if not CanOpenIntegratedBags() then return end
    local frame = ShirsInventory_GetFrame()
    frame.shirsWasOpen = frame:IsShown()
    frame:Show()
  end

  CloseBackpack = function()
    local frame = ShirsInventory_GetFrame()
    if not frame.shirsWasOpen then frame:Hide() end
    frame.shirsWasOpen = nil
  end

  OpenAllBags = function()
    local frame = ShirsInventory_GetFrame()
    -- pfUI intentionally wires its bag-space and money panels to OpenAllBags
    -- as a toggle. Preserve that provider contract while keeping stock
    -- OpenAllBags open-only when pfUI is absent.
    if pfUI and frame:IsShown() then
      frame:Hide()
    else
      frame:Show()
    end
  end

  CloseAllBags = function()
    ShirsInventory_GetFrame():Hide()
    if originalBagFunctions.CloseAllBags then
      originalBagFunctions.CloseAllBags()
    end
  end

  function ShirsInventory_OnInventoryVisibilityChanged()
    if type(UpdateMicroButtons) == "function" then UpdateMicroButtons() end
  end

  ToggleBag = function(id)
    if ShirsInventory_IsNormalBag(id) then
      ToggleBackpack()
    elseif originalBagFunctions.ToggleBag then
      originalBagFunctions.ToggleBag(id)
    end
  end

  OpenBag = function(id)
    if ShirsInventory_IsNormalBag(id) then
      if not CanOpenIntegratedBags() then return end
      local frame = ShirsInventory_GetFrame()
      frame:Show()
    elseif originalBagFunctions.OpenBag then
      originalBagFunctions.OpenBag(id)
    end
  end

  CloseBag = function(id)
    if ShirsInventory_IsNormalBag(id) then
      local frame = ShirsInventory_GetFrame()
      frame:Hide()
    elseif originalBagFunctions.CloseBag then
      originalBagFunctions.CloseBag(id)
    end
  end

  IsBagOpen = function(id)
    if ShirsInventory_IsNormalBag(id) then
      return ShirsInventory_GetFrame():IsShown() and 1 or nil
    elseif originalBagFunctions.IsBagOpen then
      return originalBagFunctions.IsBagOpen(id)
    end
    return nil
  end

  ToggleKeyRing = function()
    if type(IsOptionFrameOpen) == "function" and IsOptionFrameOpen() then return end
    ToggleBackpack()
    local frame = ShirsInventory_GetFrame()
    local opened = frame and frame.IsShown and frame:IsShown()
    if opened and type(SetButtonPulse) == "function" and KeyRingButton then
      SetButtonPulse(KeyRingButton, 0, 1)
    end
  end

  installedBagFunctions = {
    ToggleBackpack = ToggleBackpack,
    OpenBackpack = OpenBackpack,
    CloseBackpack = CloseBackpack,
    OpenAllBags = OpenAllBags,
    CloseAllBags = CloseAllBags,
    ToggleBag = ToggleBag,
    OpenBag = OpenBag,
    CloseBag = CloseBag,
    IsBagOpen = IsBagOpen,
    ToggleKeyRing = ToggleKeyRing,
  }
end

function ShirsInventory_UninstallBagHooks()
  if not bagHooksInstalled or not originalBagFunctions then return end
  if ToggleBackpack == installedBagFunctions.ToggleBackpack then ToggleBackpack = originalBagFunctions.ToggleBackpack end
  if OpenBackpack == installedBagFunctions.OpenBackpack then OpenBackpack = originalBagFunctions.OpenBackpack end
  if CloseBackpack == installedBagFunctions.CloseBackpack then CloseBackpack = originalBagFunctions.CloseBackpack end
  if OpenAllBags == installedBagFunctions.OpenAllBags then OpenAllBags = originalBagFunctions.OpenAllBags end
  if CloseAllBags == installedBagFunctions.CloseAllBags then CloseAllBags = originalBagFunctions.CloseAllBags end
  if ToggleBag == installedBagFunctions.ToggleBag then ToggleBag = originalBagFunctions.ToggleBag end
  if OpenBag == installedBagFunctions.OpenBag then OpenBag = originalBagFunctions.OpenBag end
  if CloseBag == installedBagFunctions.CloseBag then CloseBag = originalBagFunctions.CloseBag end
  if IsBagOpen == installedBagFunctions.IsBagOpen then IsBagOpen = originalBagFunctions.IsBagOpen end
  if ToggleKeyRing == installedBagFunctions.ToggleKeyRing then ToggleKeyRing = originalBagFunctions.ToggleKeyRing end
  bagHooksInstalled = nil
  originalBagFunctions = nil
  installedBagFunctions = nil
end

function ShirsInventory_ActivateBagUI()
  local external = pfUI and pfUI.bag and pfUI.bag.right or nil
  if not external and getglobal then external = getglobal("pfBag") end
  local wasOpen = external and external.IsShown and external:IsShown()
  local hooksStale = bagHooksInstalled and installedBagFunctions and (
    ToggleBackpack ~= installedBagFunctions.ToggleBackpack or
    OpenBackpack ~= installedBagFunctions.OpenBackpack or
    CloseBackpack ~= installedBagFunctions.CloseBackpack or
    OpenAllBags ~= installedBagFunctions.OpenAllBags or
    CloseAllBags ~= installedBagFunctions.CloseAllBags or
    ToggleBag ~= installedBagFunctions.ToggleBag or
    OpenBag ~= installedBagFunctions.OpenBag or
    CloseBag ~= installedBagFunctions.CloseBag or
    IsBagOpen ~= installedBagFunctions.IsBagOpen or
    ToggleKeyRing ~= installedBagFunctions.ToggleKeyRing
  )
  local genericWasOpen = false
  if not wasOpen and (not bagHooksInstalled or hooksStale) and type(IsBagOpen) == "function" then
    genericWasOpen = IsBagOpen(0) and true or false
    wasOpen = genericWasOpen
  end
  if wasOpen and external and external.Hide then
    external:Hide()
  elseif genericWasOpen and type(CloseAllBags) == "function" then
    CloseAllBags()
  end
  if hooksStale then
    ShirsInventory_UninstallBagHooks()
  end
  ShirsInventory_InstallBagHooks()
  local frame = ShirsInventory_GetFrame()
  if wasOpen and frame and frame.Show then frame:Show() end
  return wasOpen and true or false
end

function ShirsInventory_DeactivateBagUI()
  local frame = ShirsInventory_GetFrame()
  local wasOpen = frame and frame.IsShown and frame:IsShown()
  if wasOpen then frame:Hide() end
  ShirsInventory_UninstallBagHooks()
  if wasOpen and type(OpenBackpack) == "function" then
    OpenBackpack()
    return true
  end
  return false
end

function ShirsInventory_ApplyFeatureSelection()
  ShirsInventory_ActivateBagUI()

  local frame = ShirsInventory_GetFrame()
  if frame and frame.sortButton then
    frame.sortButton:Show()
    frame.modeButton:Show()
    frame.directionButton:Show()
  end
  if ShirsInventory_Update then ShirsInventory_Update() end
  if ShirsInventory_UpdateStandaloneControls then ShirsInventory_UpdateStandaloneControls() end
end

local inventoryButtons = {}
local bagBarButtons = {}
local bankButtons = {}
local bankBagButtons = {}
local categoryRebuildPending
local bankPurchaseButton
local saleElapsed = 0

function ShirsInventory_RefreshSearchFilter()
  local query = ShirsInventoryFrame and ShirsInventoryFrame.searchQuery or ""
  local index
  for index = 1, table.getn(inventoryButtons) do
    local button = inventoryButtons[index]
    if button and button.IsShown and button:IsShown() then
      local link = button.hasItem and GetContainerItemLink and GetContainerItemLink(button.bag, button.slot) or nil
      local itemName = link and ShirsInventory_GetItemInfoFields(link).name or nil
      ShirsInventory_ApplySearchToButton(button, query, itemName, link)
    end
  end
end

function ShirsInventory_RefreshBankSearchFilter()
  local query = ShirsInventoryBankFrame and ShirsInventoryBankFrame.searchQuery or ""
  local index
  for index = 1, table.getn(bankButtons) do
    local button = bankButtons[index]
    if button and button.IsShown and button:IsShown() then
      local link = button.hasItem and GetContainerItemLink and GetContainerItemLink(button.bag, button.slot) or nil
      local itemName = link and ShirsInventory_GetItemInfoFields(link).name or nil
      ShirsInventory_ApplySearchToButton(button, query, itemName, link)
    end
  end
end

local function ShirsInventory_SetBagChecks(checked)
  if MainMenuBarBackpackButton then MainMenuBarBackpackButton:SetChecked(checked) end
  for bag = 1, 4 do
    local button = getglobal("CharacterBag" .. (bag - 1) .. "Slot")
    if button then button:SetChecked(checked) end
  end
end

local function ShirsInventory_HideNativeNormalBags()
  for index = 1, 12 do
    local native = getglobal("ContainerFrame" .. index)
    if native and native:IsShown() then
      local id = native:GetID()
      if ShirsInventory_IsNormalBag(id) then native:Hide() end
    end
  end
end

local function ShirsInventory_UpdateControlLabels()
  if ShirsInventoryFrame then ShirsInventory_RefreshInventoryButtonStyles() end
  if ShirsInventoryBankFrame and ShirsInventoryBankFrame:IsShown() and ShirsInventory_RefreshBankButtonStyles then
    ShirsInventory_RefreshBankButtonStyles()
  end
end

-- Icon-mode button styling. Text mode keeps the UIPanelButtonTemplate chrome;
-- icon mode hides the template visuals, shows a small texture, and exposes the
-- label through a GameTooltip instead. Defined in UI (loaded before Settings)
-- so both standalone and combined-frame buttons can share it.
local function ShirsInventory_StyleButtonTooltip(button)
  GameTooltip:SetOwner(button, button.shirsTooltipAnchor or "ANCHOR_LEFT")
  GameTooltip:SetText(button.shirsTooltipTitle or "", 1, 0.82, 0)
  if button.shirsTooltipDescription and button.shirsTooltipDescription ~= "" then
    GameTooltip:AddLine(button.shirsTooltipDescription, 0.9, 0.9, 0.9, 1)
  end
  if button.shirsTooltipHint and button.shirsTooltipHint ~= "" then
    GameTooltip:AddLine(button.shirsTooltipHint, 0.45, 0.75, 1, 1)
  end
  GameTooltip:Show()
end

function ShirsInventory_RefreshOwnedActionTooltip(button)
  if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then
    ShirsInventory_StyleButtonTooltip(button)
    return true
  end
  return false
end

local function ShirsInventory_AttachButtonTooltip(button, spec)
  button.shirsTooltipTitle = spec.tooltipTitle or spec.text or ""
  button.shirsTooltipDescription = spec.tooltipDescription
  button.shirsTooltipHint = spec.tooltipHint
  button.shirsTooltipAnchor = spec.tooltipAnchor or "ANCHOR_LEFT"
  button:SetScript("OnEnter", function()
    ShirsInventory_SetActionFeedback(this, "hover")
    ShirsInventory_StyleButtonTooltip(this)
  end)
  button:SetScript("OnLeave", function()
    ShirsInventory_SetActionFeedback(this, nil)
    GameTooltip:Hide()
  end)
  button:SetScript("OnMouseDown", function() ShirsInventory_SetActionFeedback(this, "pressed") end)
  button:SetScript("OnMouseUp", function() ShirsInventory_SetActionFeedback(this, "hover") end)
end

function ShirsInventory_GetInventoryActionVisualModel()
  return {
    buttonSize = 24,
    iconSize = 18,
    gap = 4,
    rightInset = 14,
    topOffset = -33,
    hover = true,
    hoverStyle = "blue-border",
    hoverColor = {0.15, 0.45, 1, 0.32},
    pressedStyle = "blue-border",
    pressedColor = {0.08, 0.3, 1, 0.42},
  }
end

local function ShirsInventory_CreateActionFeedbackEdges(button)
  if button.shirsFeedbackEdges then return button.shirsFeedbackEdges end
  local edges = {}
  local top = button:CreateTexture(nil, "OVERLAY")
  top:SetTexture("Interface\\Buttons\\WHITE8X8")
  top:SetHeight(2)
  top:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
  top:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
  table.insert(edges, top)
  local bottom = button:CreateTexture(nil, "OVERLAY")
  bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
  bottom:SetHeight(2)
  bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
  bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
  table.insert(edges, bottom)
  local left = button:CreateTexture(nil, "OVERLAY")
  left:SetTexture("Interface\\Buttons\\WHITE8X8")
  left:SetWidth(2)
  left:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
  left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
  table.insert(edges, left)
  local right = button:CreateTexture(nil, "OVERLAY")
  right:SetTexture("Interface\\Buttons\\WHITE8X8")
  right:SetWidth(2)
  right:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
  right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
  table.insert(edges, right)
  button.shirsFeedbackEdges = edges
  return edges
end

function ShirsInventory_SetActionFeedback(button, state)
  if not button then return end
  local edges = ShirsInventory_CreateActionFeedbackEdges(button)
  local visual = ShirsInventory_GetInventoryActionVisualModel()
  local color = state == "pressed" and visual.pressedColor or visual.hoverColor
  local index
  for index = 1, table.getn(edges) do
    if state then
      edges[index]:SetVertexColor(color[1], color[2], color[3], color[4])
      edges[index]:Show()
    else
      edges[index]:Hide()
    end
  end
end

function ShirsInventory_NeutralizeActionStateTextures(button)
  if not button then return end
  local states = {"Normal", "Pushed", "Highlight", "Disabled"}
  local index
  for index = 1, table.getn(states) do
    local name = states[index]
    local setter = button["Set" .. name .. "Texture"]
    local getter = button["Get" .. name .. "Texture"]
    if setter then setter(button, "Interface\\Buttons\\WHITE8X8") end
    local texture = getter and getter(button) or nil
    if texture and texture.SetVertexColor then texture:SetVertexColor(0, 0, 0, 0) end
    if texture and texture.SetAlpha then texture:SetAlpha(0) end
  end
end

function ShirsInventory_ApplyButtonStyle(button, spec)
  if not button then return end
  -- The UIPanelButtonTemplate chrome lives on three named sub-textures plus
  -- the Normal/Highlight/Pushed set. Icon mode must hide all of them or the
  -- button keeps its pressed-looking raised border. Note: an `and`-guarded
  -- call would collapse the multi-return to its first value, so call plainly.
  local regions = {}
  if button.GetRegions then
    regions = { button:GetRegions() }
  end
  local useIcon = spec.forceIcon or
    (ShirsInventory_GetUseIconButtons and ShirsInventory_GetUseIconButtons())
  if useIcon and spec.icon then
    button:SetText("")
    local i
    for i = 1, table.getn(regions) do
      local region = regions[i]
      if region and region.Hide then region:Hide() end
    end
    if not button.shirsIcon then
      button.shirsIcon = button:CreateTexture(nil, "ARTWORK")
    end
    -- Keep the icon square and centered: wide text buttons would otherwise
    -- stretch the artwork horizontally.
    local visual = ShirsInventory_GetInventoryActionVisualModel()
    local height = button.GetHeight and button:GetHeight() or visual.buttonSize
    local size = spec.iconSize or visual.iconSize or math.floor(height * 0.72)
    if size < 10 then size = 10 end
    button.shirsIcon:ClearAllPoints()
    button.shirsIcon:SetWidth(size)
    button.shirsIcon:SetHeight(size)
    button.shirsIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.shirsIcon:SetTexture(spec.icon)
    if spec.texCoord then
      button.shirsIcon:SetTexCoord(spec.texCoord[1], spec.texCoord[2], spec.texCoord[3], spec.texCoord[4])
    else
      button.shirsIcon:SetTexCoord(0, 1, 0, 1)
    end
    button.shirsIcon:Show()
    if not button.shirsBackground then
      button.shirsBackground = button:CreateTexture(nil, "BACKGROUND")
      button.shirsBackground:SetAllPoints(button)
      button.shirsBackground:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
      button.shirsBackground:SetVertexColor(0.08, 0.11, 0.16, 0.9)
    end
    button.shirsBackground:Show()
    ShirsInventory_NeutralizeActionStateTextures(button)
    ShirsInventory_CreateActionFeedbackEdges(button)
    ShirsInventory_AttachButtonTooltip(button, spec)
    ShirsInventory_RefreshOwnedActionTooltip(button)
  else
    if button.shirsIcon then button.shirsIcon:Hide() end
    if button.shirsBackground then button.shirsBackground:Hide() end
    local i
    for i = 1, table.getn(regions) do
      local region = regions[i]
      if region and region.Show then region:Show() end
    end
    button:SetText(spec.text or "")
    button:SetScript("OnEnter", nil)
    button:SetScript("OnLeave", nil)
    button.shirsTooltipTitle = nil
    button.shirsTooltipDescription = nil
    button.shirsTooltipHint = nil
  end
end

function ShirsInventory_InventoryUsesIconControls()
  return true
end

function ShirsInventory_GetInventoryButtonSpecs(bank)
  local mode = ShirsInventory_GetSortMode and ShirsInventory_GetSortMode() or "itemType"
  local direction = ShirsInventory_GetDirection and ShirsInventory_GetDirection() or "bottom"
  local iconSize = ShirsInventory_GetInventoryActionVisualModel().iconSize
  local specs = {
    sort = {
      text = "Sort",
      icon = "Interface\\Icons\\INV_Misc_Bag_08",
      iconSize = iconSize,
      texCoord = {0.14, 0.86, 0.14, 0.86},
      tooltipTitle = "Sort inventory",
      tooltipDescription = "Arrange all movable items with the selected grouping and direction.",
      tooltipHint = "Click to begin sorting.",
    },
    mode = {
      text = mode == "rarity" and "Rarity" or "Item Type",
      icon = mode == "rarity" and "Interface\\Icons\\INV_Misc_Gem_02" or "Interface\\Icons\\INV_Misc_Book_09",
      iconSize = iconSize,
      texCoord = {0.08, 0.92, 0.08, 0.92},
      tooltipTitle = mode == "rarity" and "Grouping: Rarity" or "Grouping: Item Type",
      tooltipDescription = mode == "rarity" and
        "Group items by quality, from poor through legendary." or
        "Group items by type, such as equipment, consumables, and materials.",
      tooltipHint = mode == "rarity" and "Click to use item-type grouping." or "Click to use rarity grouping.",
    },
    direction = {
      text = direction == "top" and "Top" or "Bottom",
      icon = direction == "top" and "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up" or "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",
      iconSize = iconSize,
      texCoord = {0.25, 0.75, 0.25, 0.75},
      tooltipTitle = direction == "top" and "Direction: Top" or "Direction: Bottom",
      tooltipDescription = direction == "top" and
        "Fill the sorted inventory from the top edge." or
        "Fill the sorted inventory toward the bottom edge.",
      tooltipHint = direction == "top" and "Click to sort toward the bottom." or "Click to sort from the top.",
    },
    settings = {
      text = "Settings",
      icon = "Interface\\Icons\\INV_Misc_Gear_01",
      iconSize = iconSize,
      texCoord = {0.08, 0.92, 0.08, 0.92},
      tooltipTitle = "Inventory settings",
      tooltipDescription = "Open bag, sorting, junk, rarity-border, and currency options.",
      tooltipHint = "Click to open Settings.",
    },
  }
  if not bank and ShirsInventory_GetCategoryMode and ShirsInventory_GetCategoryMode() then
    local editing = ShirsInventory_GetCategoryEditMode()
    specs.sort = {
      text = "Manage",
      icon = "Interface\\Icons\\INV_Misc_Note_01",
      iconSize = iconSize,
      texCoord = {0.08, 0.92, 0.08, 0.92},
      tooltipTitle = "Category settings",
      tooltipDescription = "Show or hide Category Settings to create or delete visual categories and choose how Empty Slots appear.",
      tooltipHint = "Click to show or hide Category Settings.",
    }
    specs.mode = {
      text = editing and "Done" or "Edit",
      icon = editing and "Interface\\Icons\\INV_Misc_Note_05" or "Interface\\Icons\\INV_Misc_Note_03",
      iconSize = iconSize,
      texCoord = {0.08, 0.92, 0.08, 0.92},
      tooltipTitle = editing and "Finish category editing" or "Edit categories",
      tooltipDescription = editing and
        "Return item dragging to normal physical bag movement." or
        "Make item dragging assign item types to category headings without moving bag slots.",
      tooltipHint = editing and "Click to leave category edit mode." or
        "Click, then drag an item onto a category heading.",
    }
  end
  return specs
end

function ShirsInventory_LayoutInventoryControls(frame)
  if not frame then return end
  local visual = ShirsInventory_GetInventoryActionVisualModel()
  local buttons = {frame.sortButton, frame.modeButton, frame.directionButton, frame.settingsButton}
  local index
  -- Clear the old left-to-right anchor family before reversing the chain. Doing
  -- this in the same loop would briefly make Sort and Mode anchor to each other,
  -- which Vanilla rejects and leaves the controls at their old sizes.
  for index = 1, table.getn(buttons) do
    local button = buttons[index]
    if button then
      button:ClearAllPoints()
      button:SetWidth(visual.buttonSize)
      button:SetHeight(visual.buttonSize)
    end
  end
  if buttons[4] then
    buttons[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -visual.rightInset, visual.topOffset)
  end
  for index = 3, 1, -1 do
    if buttons[index] and buttons[index + 1] then
      buttons[index]:SetPoint("RIGHT", buttons[index + 1], "LEFT", -visual.gap, 0)
    end
  end
end

function ShirsInventory_RefreshActionButtonStyles(frame, bank)
  if not frame or type(ShirsInventory_ApplyButtonStyle) ~= "function" then return end
  ShirsInventory_LayoutInventoryControls(frame)
  local specs = ShirsInventory_GetInventoryButtonSpecs(bank)
  if bank then
    specs.sort.tooltipTitle = "Sort bank"
    specs.sort.tooltipDescription = "Arrange the main bank and all equipped bank bags with Shir's sorting engine."
  end
  specs.sort.forceIcon = true
  specs.mode.forceIcon = true
  specs.direction.forceIcon = true
  specs.settings.forceIcon = true
  ShirsInventory_ApplyButtonStyle(frame.sortButton, specs.sort)
  ShirsInventory_ApplyButtonStyle(frame.modeButton, specs.mode)
  ShirsInventory_ApplyButtonStyle(frame.directionButton, specs.direction)
  ShirsInventory_ApplyButtonStyle(frame.settingsButton, specs.settings)
  local actions = {
    { name = "sort", button = frame.sortButton },
    { name = "mode", button = frame.modeButton },
    { name = "direction", button = frame.directionButton },
    { name = "settings", button = frame.settingsButton },
  }
  local actionIndex
  for actionIndex = 1, table.getn(actions) do
    local action = actions[actionIndex]
    if ShirsInventory_ShouldShowInventoryAction(action.name, bank) then
      action.button:Show()
    else
      action.button:Hide()
    end
  end
end

function ShirsInventory_RefreshInventoryButtonStyles()
  ShirsInventory_RefreshActionButtonStyles(ShirsInventoryFrame, false)
end

function ShirsInventory_RefreshBankButtonStyles()
  ShirsInventory_RefreshActionButtonStyles(ShirsInventoryBankFrame, true)
end

function ShirsInventory_OnSortButtonClick(bank)
  if not bank and ShirsInventory_GetCategoryMode and ShirsInventory_GetCategoryMode() then
    if ShirsInventory_ToggleCategoryManager then return ShirsInventory_ToggleCategoryManager() end
    return false
  end
  if bank then
    if ShirsInventory_SortBank then return ShirsInventory_SortBank() end
  elseif ShirsInventory_SortBags then
    return ShirsInventory_SortBags()
  end
  return false
end

function ShirsInventory_OnModeButtonClick(bank)
  if not bank and ShirsInventory_GetCategoryMode and ShirsInventory_GetCategoryMode() then
    local wasEditing = ShirsInventory_GetCategoryEditMode()
    local editing = ShirsInventory_ToggleCategoryEditMode()
    if not wasEditing and not editing and ShirsInventory_Message then
      ShirsInventory_Message("Finish the current item move before editing categories.")
    end
    if ShirsInventory_Update then ShirsInventory_Update() end
    ShirsInventory_UpdateControlLabels()
    return editing
  end
  local mode
  if ShirsInventory_ToggleSortMode then mode = ShirsInventory_ToggleSortMode() end
  ShirsInventory_UpdateControlLabels()
  return mode
end

function ShirsInventory_GetInventoryTitle(playerName)
  if type(playerName) ~= "string" or playerName == "" then return "Player's Inventory" end
  return playerName .. "'s Inventory"
end

function ShirsInventory_GetBankTitle(playerName)
  if type(playerName) ~= "string" or playerName == "" then return "Player's Bank" end
  return playerName .. "'s Bank"
end

function ShirsInventory_RefreshInventoryTitle(frame, playerName)
  if not frame or not frame.title or not frame.title.SetText then return nil end
  local title = ShirsInventory_GetInventoryTitle(playerName)
  frame.title:SetText(title)
  return title
end

function ShirsInventory_SetInventoryFrameAnchor(frame, point, relativeTo, relativePoint, x, y, save)
  if not frame or not point or not relativePoint then return false end
  frame:ClearAllPoints()
  frame:SetPoint(point, relativeTo or UIParent, relativePoint, x or 0, y or 0)
  if save and ShirsInventory_SaveInventoryFramePosition then
    return ShirsInventory_SaveInventoryFramePosition(frame)
  end
  return true
end

function ShirsInventory_OnInventoryDragStop(frame)
  if not frame then return false end
  if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
  if ShirsInventory_SaveInventoryFramePosition then
    local saved = ShirsInventory_SaveInventoryFramePosition(frame)
    if not saved then return false end
    local position = ShirsInventory_GetInventoryFramePosition and
      ShirsInventory_GetInventoryFramePosition() or nil
    if position then
      ShirsInventory_SetInventoryFrameAnchor(
        frame, position.point, UIParent, position.relativePoint, position.x, position.y, false
      )
    end
    return true
  end
  return false
end

function ShirsInventory_ConfigureInventoryFrameMovement(frame)
  if not frame then return false end
  if frame.SetMovable then frame:SetMovable(true) end
  if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
  return true
end

function ShirsInventory_GetInventoryViewportSize()
  local width
  local height
  if type(GetScreenWidth) == "function" then width = tonumber(GetScreenWidth()) end
  if type(GetScreenHeight) == "function" then height = tonumber(GetScreenHeight()) end
  if (not width or width <= 0) and UIParent and UIParent.GetWidth then
    width = tonumber(UIParent:GetWidth())
  end
  if (not height or height <= 0) and UIParent and UIParent.GetHeight then
    height = tonumber(UIParent:GetHeight())
  end
  if not width or width <= 0 or not height or height <= 0 then return nil, nil end
  return width, height
end

function ShirsInventory_BindInventoryDragHandle(frame, handle)
  if not frame or not handle then return false end
  handle:RegisterForDrag("LeftButton")
  handle:SetScript("OnDragStart", function()
    if frame.StartMoving then frame:StartMoving() end
  end)
  handle:SetScript("OnDragStop", function()
    ShirsInventory_OnInventoryDragStop(frame)
  end)
  return true
end

function ShirsInventory_ApplyInventoryFramePosition(frame)
  if not frame then return end
  local position = ShirsInventory_GetInventoryFramePosition and ShirsInventory_GetInventoryFramePosition() or nil
  if position then
    ShirsInventory_SetInventoryFrameAnchor(frame, position.point, UIParent, position.relativePoint, position.x, position.y, false)
  elseif MainMenuBarBackpackButton then
    ShirsInventory_SetInventoryFrameAnchor(frame, "BOTTOMRIGHT", MainMenuBarBackpackButton, "TOPRIGHT", 0, 8, false)
  else
    ShirsInventory_SetInventoryFrameAnchor(frame, "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -16, 84, false)
  end
end

function ShirsInventory_PrepareInventoryFrameForShow(frame, playerName)
  if not frame then return false end
  ShirsInventory_RefreshInventoryTitle(frame, playerName)
  ShirsInventory_ApplyInventoryFramePosition(frame)
  return true
end

function ShirsInventory_FormatCooldownRemaining(remaining)
  if type(remaining) ~= "number" or remaining <= 0 then return nil end
  if remaining >= 86400 then return math.ceil(remaining / 86400) .. "d" end
  if remaining >= 3600 then return math.ceil(remaining / 3600) .. "h" end
  if remaining >= 60 then return math.ceil(remaining / 60) .. "m" end
  return tostring(math.ceil(remaining))
end

function ShirsInventory_GetCooldownRemaining(start, duration, now)
  start = tonumber(start) or 0
  duration = tonumber(duration) or 0
  now = tonumber(now) or 0
  local remaining = start + duration - now
  if start > now then
    -- Vanilla stores cooldown starts in an unsigned 32-bit millisecond timer.
    -- After that timer wraps, its converted start can sit ahead of GetTime().
    remaining = remaining - ((2 ^ 32) / 1000)
  end
  return remaining
end

function ShirsInventory_ApplyItemCooldown(button, start, duration, enable, now)
  if not button or not button.cooldown then return end
  start = tonumber(start) or 0
  duration = tonumber(duration) or 0
  now = tonumber(now) or (GetTime and GetTime()) or 0
  if CooldownFrame_SetTimer then
    CooldownFrame_SetTimer(button.cooldown, start, duration, enable or 0)
  end
  local remaining = ShirsInventory_GetCooldownRemaining(start, duration, now)
  if start > 0 and duration > 0 and remaining > 0 then
    button.cooldownEnd = now + remaining
    button.cooldownDuration = duration
    button.cooldownElapsed = 0
    button.cooldown:Show()
    local label = duration > 1.5 and ShirsInventory_FormatCooldownRemaining(remaining) or nil
    if button.cooldownText and label then
      button.cooldownText:SetText(label)
      button.cooldownText:Show()
    elseif button.cooldownText then
      button.cooldownText:Hide()
    end
  else
    button.cooldownEnd = nil
    button.cooldownDuration = nil
    button.cooldownElapsed = 0
    button.cooldown:Hide()
    if button.cooldownText then button.cooldownText:Hide() end
  end
end

function ShirsInventory_UpdateCooldownDisplay(button, elapsed, now)
  if not button or not button.cooldownEnd then return end
  button.cooldownElapsed = (button.cooldownElapsed or 0) + (elapsed or 0)
  if button.cooldownElapsed < 0.20 then return end
  button.cooldownElapsed = 0
  now = tonumber(now) or (GetTime and GetTime()) or 0
  local remaining = button.cooldownEnd - now
  if remaining <= 0 then
    button.cooldownEnd = nil
    button.cooldownDuration = nil
    button.cooldown:Hide()
    if button.cooldownText then button.cooldownText:Hide() end
    return
  end
  local label = (button.cooldownDuration or 0) > 1.5 and
    ShirsInventory_FormatCooldownRemaining(remaining) or nil
  if button.cooldownText and label then
    button.cooldownText:SetText(label)
    button.cooldownText:Show()
  elseif button.cooldownText then
    button.cooldownText:Hide()
  end
end

local function ShirsInventory_UpdateCooldown(button)
  if not button.cooldown then return end
  local start, duration, enable = GetContainerItemCooldown(button.bag, button.slot)
  ShirsInventory_ApplyItemCooldown(button, start, duration, enable)
end

function ShirsInventory_UpdateItemCursor(button, locked, readable)
  local keyring = ShirsInventory_GetKeyRingContainerID and ShirsInventory_GetKeyRingContainerID() or (KEYRING_CONTAINER or -2)
  if button and button.bag == keyring then
    if CursorUpdate then CursorUpdate(button) elseif ResetCursor then ResetCursor() end
    return
  end
  if MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 and not locked then
    if ShowContainerSellCursor then ShowContainerSellCursor(button.bag, button.slot) end
  elseif readable or (IsControlKeyDown and IsControlKeyDown() and button.hasItem) then
    if ShowInspectCursor then ShowInspectCursor() end
  elseif ResetCursor then
    ResetCursor()
  end
end

function ShirsInventory_ShouldShowJunkHint(button)
  if not button then return false end
  local keyring = ShirsInventory_GetKeyRingContainerID and ShirsInventory_GetKeyRingContainerID() or (KEYRING_CONTAINER or -2)
  return button.bag ~= keyring
end

function ShirsInventory_ShouldShowJunkBadge(button, itemId, quality)
  if not ShirsInventory_ShouldShowJunkHint(button) then return false end
  if ShirsInventory_IsFeatureEnabled and not ShirsInventory_IsFeatureEnabled("junk") then return false end
  return ShirsInventory_IsJunk(itemId, quality, ShirsInventory_GetJunkItems()) and true or false
end

function ShirsInventory_SetItemTooltip(button)
  if not button then return nil end
  local keyring = ShirsInventory_GetKeyRingContainerID and ShirsInventory_GetKeyRingContainerID() or (KEYRING_CONTAINER or -2)
  if button.bag == keyring and GameTooltip.SetInventoryItem and KeyRingButtonIDToInvSlotID then
    GameTooltip:SetInventoryItem("player", KeyRingButtonIDToInvSlotID(button.slot))
    return "keyring"
  end
  if button.bag == (BANK_CONTAINER or -1) and GameTooltip.SetInventoryItem and BankButtonIDToInvSlotID then
    GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(button.slot))
    return "bank"
  end
  GameTooltip:SetBagItem(button.bag, button.slot)
  return "bag"
end

function ShirsInventory_AddAccountItemTooltip(targetTooltip, itemId)
  if ShirsInventory_GetHideItemOwnershipInCombat and
    ShirsInventory_GetHideItemOwnershipInCombat() and
    UnitAffectingCombat and UnitAffectingCombat("player") then
    return false
  end
  if ShirsInventory_AccountAddItemTooltip then
    return ShirsInventory_AccountAddItemTooltip(targetTooltip, itemId)
  end
  return false
end

local function ShirsInventory_OnItemEnter(button)
  if not button.hasItem then return end
  if button:GetRight() >= GetScreenWidth() / 2 then
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  else
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  end
  ShirsInventory_SetItemTooltip(button)
  local itemId = ShirsInventory_GetItemId(GetContainerItemLink(button.bag, button.slot))
  ShirsInventory_AddAccountItemTooltip(GameTooltip, itemId)
  if ShirsInventory_GetCategoryEditMode and ShirsInventory_GetCategoryEditMode() then
    GameTooltip:AddLine("Drag onto a category heading to place this item type there", 0.4, 0.85, 1, true)
    if ShirsInventory_GetCategoryAssignment and ShirsInventory_GetCategoryAssignment(itemId) then
      GameTooltip:AddLine("Right-click to restore automatic placement", 0.65, 0.85, 1, true)
    end
    GameTooltip:Show()
    if ShirsInventory_HasCategoryEditDrag() and SetCursor then SetCursor("CAST_CURSOR") end
    return
  end
  local _, _, locked, quality, readable = GetContainerItemInfo(button.bag, button.slot)
  if ShirsInventory_ShouldShowJunkHint(button) then
    if (not ShirsInventory_IsFeatureEnabled or ShirsInventory_IsFeatureEnabled("junk")) and
      ShirsInventory_IsJunk(itemId, quality, ShirsInventory_GetJunkItems()) then
      if quality == 0 then
        GameTooltip:AddLine("Junk: gray item", 1, 0.35, 0.35)
      else
        GameTooltip:AddLine("Junk: manually marked", 1, 0.35, 0.35)
      end
    else
      GameTooltip:AddLine("Alt-right-click to mark as junk", 0.55, 0.8, 1)
    end
  end
  if button.bag >= 0 and button.bag <= 4 then
    local selectedItem = ShirsInventory_GetHearthstoneItemIndex(itemId) ~= nil
    if ShirsInventory_GetLockSelectedItemSlots() then
      if selectedItem then
        GameTooltip:AddLine("Ctrl-right-click to unlock this item type's slots", 0.55, 0.8, 1)
      elseif itemId ~= 6948 then
        GameTooltip:AddLine("Ctrl-right-click to lock this item type's slots", 0.55, 0.8, 1)
      end
    elseif ShirsInventory_GetAutomaticHearthstoneItems() then
      if selectedItem then
        GameTooltip:AddLine("Ctrl-right-click to remove from selected list", 0.55, 0.8, 1)
      elseif itemId ~= 6948 then
        GameTooltip:AddLine("Ctrl-right-click to add to selected list", 0.55, 0.8, 1)
      end
    elseif selectedItem then
      GameTooltip:AddLine("Ctrl-right-click to remove from beside Hearthstone", 0.55, 0.8, 1)
    elseif itemId ~= 6948 then
      GameTooltip:AddLine("Ctrl-right-click to keep beside Hearthstone", 0.55, 0.8, 1)
    end
  end
  GameTooltip:Show()
  ShirsInventory_UpdateItemCursor(button, locked, readable)
end

local function ShirsInventory_CreateItemButton(index, ownerFrame, namePrefix, collection)
  local frame = ownerFrame or ShirsInventoryFrame
  local buttons = collection or inventoryButtons
  local prefix = namePrefix or "ShirsInventoryItem"
  local button = CreateFrame("Button", prefix .. index, frame, "ItemButtonTemplate")
  button:SetWidth(36)
  button:SetHeight(36)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")

  button.cooldown = CreateFrame("Model", button:GetName() .. "Cooldown", button, "CooldownFrameTemplate")
  button.cooldown:SetAllPoints(button)
  if button.cooldown.SetFrameLevel and button.GetFrameLevel then
    button.cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
  end
  button.cooldownText = button.cooldown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.cooldownText:SetPoint("CENTER", button.cooldown, "CENTER", 0, 0)
  button.cooldownText:SetTextColor(1, 0.82, 0)
  if button.cooldownText.SetShadowColor then button.cooldownText:SetShadowColor(0, 0, 0, 1) end
  if button.cooldownText.SetShadowOffset then button.cooldownText:SetShadowOffset(1, -1) end
  button.cooldownText:Hide()
  button.bagRangeHighlight = button:CreateTexture(nil, "OVERLAY")
  button.bagRangeHighlight:SetAllPoints(button)
  button.bagRangeHighlight:SetTexture("Interface\\Buttons\\WHITE8X8")
  button.bagRangeHighlight:SetVertexColor(0.15, 0.5, 1, 0.28)
  if button.bagRangeHighlight.SetBlendMode then button.bagRangeHighlight:SetBlendMode("ADD") end
  button.bagRangeHighlight:Hide()
  local rarityLayout = ShirsInventory_GetRarityBorderLayout()
  local inset = rarityLayout.inset
  local thickness = rarityLayout.thickness
  button.rarityEdges = {}
  local top = button:CreateTexture(nil, "OVERLAY")
  top:SetTexture(rarityLayout.texture)
  top:SetHeight(thickness)
  top:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
  top:SetPoint("TOPRIGHT", button, "TOPRIGHT", -inset, -inset)
  table.insert(button.rarityEdges, top)
  local bottom = button:CreateTexture(nil, "OVERLAY")
  bottom:SetTexture(rarityLayout.texture)
  bottom:SetHeight(thickness)
  bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", inset, inset)
  bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
  table.insert(button.rarityEdges, bottom)
  local left = button:CreateTexture(nil, "OVERLAY")
  left:SetTexture(rarityLayout.texture)
  left:SetWidth(thickness)
  left:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
  left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", inset, inset)
  table.insert(button.rarityEdges, left)
  local right = button:CreateTexture(nil, "OVERLAY")
  right:SetTexture(rarityLayout.texture)
  right:SetWidth(thickness)
  right:SetPoint("TOPRIGHT", button, "TOPRIGHT", -inset, -inset)
  right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
  table.insert(button.rarityEdges, right)
  local edgeIndex
  for edgeIndex = 1, table.getn(button.rarityEdges) do
    button.rarityEdges[edgeIndex]:Hide()
  end
  button.junkBadgeBack = button:CreateTexture(nil, "OVERLAY")
  button.junkBadgeBack:SetWidth(16)
  button.junkBadgeBack:SetHeight(16)
  button.junkBadgeBack:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  button.junkBadgeBack:SetTexture("Interface\\Buttons\\WHITE8X8")
  button.junkBadgeBack:SetVertexColor(0, 0, 0, 0.7)
  button.junkBadgeBack:Hide()
  button.junkBadge = button:CreateTexture(nil, "OVERLAY")
  button.junkBadge:SetWidth(14)
  button.junkBadge:SetHeight(14)
  button.junkBadge:SetPoint("CENTER", button.junkBadgeBack, "CENTER", 0, 0)
  button.junkBadge:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  button.junkBadge:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.junkBadge:Hide()
  button.recipeStatusFill = button:CreateTexture(nil, "BACKGROUND")
  button.recipeStatusFill:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
  button.recipeStatusFill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
  button.recipeStatusFill:SetTexture("Interface\\Buttons\\WHITE8X8")
  button.recipeStatusFill:Hide()

  button:SetScript("OnClick", function() ShirsInventory_HandleItemClick(this, arg1) end)
  button:SetScript("OnDragStart", function() ShirsInventory_HandleItemClick(this, "LeftButton", true) end)
  button:SetScript("OnDragStop", function()
    if ShirsInventory_GetCategoryEditMode and ShirsInventory_GetCategoryEditMode() then
      ShirsInventory_SetCategoryEditHover(ShirsInventory_GetCategoryEditDropTarget())
      ShirsInventory_FinishCategoryEditDrag()
    end
  end)
  button:SetScript("OnReceiveDrag", function()
    if not (ShirsInventory_GetCategoryEditMode and ShirsInventory_GetCategoryEditMode()) then
      ShirsInventory_HandleItemClick(this, "LeftButton", true)
    end
  end)
  button:SetScript("OnEnter", function() ShirsInventory_OnItemEnter(this) end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
    if ShirsInventory_HasCategoryEditDrag and ShirsInventory_HasCategoryEditDrag() then
      if SetCursor then SetCursor("CAST_CURSOR") end
    else
      ResetCursor()
    end
  end)
  button:SetScript("OnUpdate", function()
    ShirsInventory_UpdateCooldownDisplay(this, arg1)
    if GameTooltip:IsOwned(this) then ShirsInventory_OnItemEnter(this) end
  end)
  ShirsInventory_EnableCategoryWheel(button)
  buttons[index] = button
  return button
end

local function ShirsInventory_UpdateItemButton(button)
  local texture, count, locked, quality, readable = GetContainerItemInfo(button.bag, button.slot)
  local link = texture and GetContainerItemLink and GetContainerItemLink(button.bag, button.slot) or nil
  local itemInfo = ShirsInventory_GetItemInfoFields(link)
  SetItemButtonTexture(button, texture)
  SetItemButtonCount(button, count)
  SetItemButtonDesaturated(button, locked, 0.5, 0.5, 0.5)
  button.count = count or 0
  button.readable = readable
  button.hasItem = texture and true or nil

  local normal = button:GetNormalTexture()
  if normal then normal:SetVertexColor(1, 1, 1) end

  if button.rarityEdges then
    local recipeStatus = texture and
      ShirsInventory_GetRecipeLearnStatusForSlot(button.bag, button.slot, itemInfo.itemType) or nil
    local visual = ShirsInventory_GetItemVisualModel(
      texture,
      ShirsInventory_ResolveItemQuality(quality, itemInfo.quality),
      itemInfo.itemType,
      ShirsInventory_GetShowRarityBoxes and ShirsInventory_GetShowRarityBoxes(),
      recipeStatus
    )
    button.shirsBorderKind = visual and visual.kind or nil
    button.shirsRecipeStatus = recipeStatus
    local edgeIndex
    for edgeIndex = 1, table.getn(button.rarityEdges) do
      local edge = button.rarityEdges[edgeIndex]
      if visual then
        edge:SetVertexColor(visual.r, visual.g, visual.b, visual.a)
        edge:Show()
      else
        edge:Hide()
      end
    end
    if button.recipeStatusFill then
      if visual and visual.fillA then
        button.recipeStatusFill:SetVertexColor(visual.fillR, visual.fillG, visual.fillB, visual.fillA)
        button.recipeStatusFill:Show()
      else
        button.recipeStatusFill:Hide()
      end
    end
  end

  if texture then
    ShirsInventory_UpdateCooldown(button)
    local itemId = ShirsInventory_GetItemId(GetContainerItemLink(button.bag, button.slot))
    if ShirsInventory_ShouldShowJunkBadge(button, itemId, quality) then
      if button.junkBadgeBack then button.junkBadgeBack:Show() end
      button.junkBadge:Show()
    else
      if button.junkBadgeBack then button.junkBadgeBack:Hide() end
      button.junkBadge:Hide()
    end
  else
    button.cooldown:Hide()
    if button.junkBadgeBack then button.junkBadgeBack:Hide() end
    button.junkBadge:Hide()
  end
  local query = ShirsInventory_GetSearchQueryForButton(button)
  ShirsInventory_ApplySearchToButton(button, query, itemInfo.name, link)
end

function ShirsInventory_CreateSearchBox(frame)
  local layout = ShirsInventory_GetSearchBoxLayout()
  frame.searchQuery = ""
  frame.searchFocused = false
  frame.searchBox = CreateFrame("EditBox", "ShirsInventorySearchBox", frame, "InputBoxTemplate")
  frame.searchBox:SetHeight(layout.height)
  frame.searchBox:SetAutoFocus(false)
  frame.searchBox:SetMaxLetters(64)
  frame.searchBox:SetPoint("LEFT", frame.bagBarButtons[6], "RIGHT", layout.leftGap, 0)
  frame.searchBox:SetPoint("RIGHT", frame.sortButton, "LEFT", -layout.rightGap, 0)
  if frame.searchBox.SetTextInsets then frame.searchBox:SetTextInsets(6, 6, 0, 0) end
  frame.searchBox.placeholder = frame.searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.searchBox.placeholder:SetPoint("LEFT", frame.searchBox, "LEFT", 7, 0)
  frame.searchBox.placeholder:SetText(layout.placeholder)
  frame.searchBox:SetScript("OnTextChanged", function()
    frame.searchQuery = ShirsInventory_NormalizeSearchQuery(this:GetText())
    if this.placeholder then
      if frame.searchQuery == "" and not frame.searchFocused then this.placeholder:Show() else this.placeholder:Hide() end
    end
    ShirsInventory_RefreshSearchFilter()
  end)
  frame.searchBox:SetScript("OnEditFocusGained", function()
    frame.searchFocused = true
    if this.placeholder then this.placeholder:Hide() end
  end)
  frame.searchBox:SetScript("OnEditFocusLost", function()
    frame.searchFocused = false
    if not ShirsInventory_IsCursorInsideSearchWindows() then ShirsInventory_ClearSearch(frame) end
  end)
  frame.searchBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  frame.searchBox:SetScript("OnEscapePressed", function()
    ShirsInventory_ClearSearch(frame, true)
    this:ClearFocus()
    if this.placeholder then this.placeholder:Show() end
  end)
  ShirsInventory_EnableCategoryWheel(frame.searchBox)
  return frame.searchBox
end

function ShirsInventory_CreateBankSearchBox(frame)
  local layout = ShirsInventory_GetSearchBoxLayout()
  frame.searchQuery = ""
  frame.searchFocused = false
  frame.searchBox = CreateFrame("EditBox", "ShirsInventoryBankSearchBox", frame, "InputBoxTemplate")
  frame.searchBox:SetHeight(layout.height)
  frame.searchBox:SetAutoFocus(false)
  frame.searchBox:SetMaxLetters(64)
  frame.searchBox:SetPoint("LEFT", frame, "TOPLEFT", 206, -45)
  frame.searchBox:SetPoint("RIGHT", frame.sortButton, "LEFT", -layout.rightGap, 0)
  if frame.searchBox.SetTextInsets then frame.searchBox:SetTextInsets(6, 6, 0, 0) end
  frame.searchBox.placeholder = frame.searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.searchBox.placeholder:SetPoint("LEFT", frame.searchBox, "LEFT", 7, 0)
  frame.searchBox.placeholder:SetText(layout.placeholder)
  frame.searchBox:SetScript("OnTextChanged", function()
    frame.searchQuery = ShirsInventory_NormalizeSearchQuery(this:GetText())
    if this.placeholder then
      if frame.searchQuery == "" and not frame.searchFocused then this.placeholder:Show() else this.placeholder:Hide() end
    end
    ShirsInventory_RefreshBankSearchFilter()
  end)
  frame.searchBox:SetScript("OnEditFocusGained", function()
    frame.searchFocused = true
    if this.placeholder then this.placeholder:Hide() end
  end)
  frame.searchBox:SetScript("OnEditFocusLost", function()
    frame.searchFocused = false
    if not ShirsInventory_IsCursorInsideSearchWindows() then ShirsInventory_ClearSearch(frame) end
  end)
  frame.searchBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  frame.searchBox:SetScript("OnEscapePressed", function()
    ShirsInventory_ClearSearch(frame, true)
    this:ClearFocus()
    if this.placeholder then this.placeholder:Show() end
  end)
  return frame.searchBox
end

function ShirsInventory_RefreshRarityBoxes()
  local index
  for index = 1, table.getn(inventoryButtons) do
    local button = inventoryButtons[index]
    if button:IsShown() then ShirsInventory_UpdateItemButton(button) end
  end
  if ShirsInventoryBankFrame and ShirsInventoryBankFrame:IsShown() and ShirsInventory_UpdateBank then
    ShirsInventory_UpdateBank(ShirsInventoryBankFrame)
  end
end

local function ShirsInventory_OnBagBarEnter(button)
  local index
  local hoveredBag = button.bagEntry and button.bagEntry.bag or nil
  for index = 1, table.getn(inventoryButtons) do
    local itemButton = inventoryButtons[index]
    if itemButton.bagRangeHighlight then
      if itemButton:IsShown() and ShirsInventory_ShouldHighlightBagSlot(itemButton, hoveredBag) then
        itemButton.bagRangeHighlight:Show()
      else
        itemButton.bagRangeHighlight:Hide()
      end
    end
  end
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  if button.bagEntry and button.bagEntry.inventoryID and GetInventoryItemLink and
    GetInventoryItemLink("player", button.bagEntry.inventoryID) then
    GameTooltip:SetInventoryItem("player", button.bagEntry.inventoryID)
  elseif button.bagEntry and button.bagEntry.keyring then
    GameTooltip:SetText("Keyring", 1, 1, 1)
  elseif button.bagEntry and button.bagEntry.bag == 0 then
    GameTooltip:SetText("Backpack", 1, 1, 1)
  else
    GameTooltip:SetText("Empty bag slot", 1, 1, 1)
  end
  if button.bagEntry then
    GameTooltip:AddLine(button.bagEntry.slots .. " slots", 0.65, 0.8, 1)
    if button.bagEntry.firstInventoryIndex then
      GameTooltip:AddLine(
        "Combined slots " .. button.bagEntry.firstInventoryIndex .. "-" .. button.bagEntry.lastInventoryIndex,
        0.35, 0.7, 1
      )
    end
    GameTooltip:AddLine(ShirsInventory_GetBagBarActionHint(button.bagEntry), 0.45, 0.8, 1, 1)
  end
  GameTooltip:Show()
end

local function ShirsInventory_OnBagBarLeave()
  local index
  for index = 1, table.getn(inventoryButtons) do
    local itemButton = inventoryButtons[index]
    if itemButton.bagRangeHighlight then itemButton.bagRangeHighlight:Hide() end
  end
  GameTooltip:Hide()
end

local function ShirsInventory_CreateBagBar(frame)
  local layout = ShirsInventory_GetBagBarLayout()
  local index
  for index = 1, 6 do
    local button = CreateFrame("Button", "ShirsInventoryBagBar" .. index, frame)
    button:SetWidth(layout.buttonSize)
    button:SetHeight(layout.buttonSize)
    if index == 1 then
      button:SetPoint(layout.anchorPoint, frame, layout.anchorPoint, 14, layout.topOffset)
    else
      button:SetPoint("LEFT", bagBarButtons[index - 1], "RIGHT", layout.gap, 0)
    end
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetVertexColor(0.15, 0.5, 1, 0.28) end
    button.slotText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.slotText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button:SetScript("OnEnter", function() ShirsInventory_OnBagBarEnter(this) end)
    button:SetScript("OnLeave", function() ShirsInventory_OnBagBarLeave() end)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function() ShirsInventory_HandleBagBarClick(this, arg1) end)
    button:SetScript("OnDragStart", function() ShirsInventory_HandleBagBarDragStart(this) end)
    button:SetScript("OnReceiveDrag", function() ShirsInventory_HandleBagBarReceiveDrag(this) end)
    ShirsInventory_EnableCategoryWheel(button)
    bagBarButtons[index] = button
  end
  frame.bagBarButtons = bagBarButtons
  if frame.freeText then
    frame.freeText:ClearAllPoints()
    frame.freeText:SetPoint("RIGHT", frame.closeButton, "LEFT", layout.freeTextGap, layout.freeTextYOffset)
  end
end

local function ShirsInventory_UpdateBagBar()
  local entries = ShirsInventory_BuildBagBarModel()
  local index
  for index = 1, table.getn(entries) do
    local button = bagBarButtons[index]
    if button then
      local entry = entries[index]
      button.bagEntry = entry
      button.icon:SetTexture(entry.texture)
      if entry.collapsed then
        button.icon:SetVertexColor(0.45, 0.45, 0.45)
        button.slotText:SetText(entry.slots)
      elseif entry.empty then
        button.icon:SetVertexColor(0.4, 0.4, 0.4)
        button.slotText:SetText("")
      else
        button.icon:SetVertexColor(1, 1, 1)
        button.slotText:SetText(entry.slots)
      end
      button:Show()
    end
  end
end

local function ShirsInventory_GetInventoryBottomMargin()
  local bottomMargin = 8
  if MainMenuBarBackpackButton and MainMenuBarBackpackButton.GetTop then
    bottomMargin = (MainMenuBarBackpackButton:GetTop() or 0) + 8
  end
  return bottomMargin
end

function ShirsInventory_ApplyViewportScale(frame, bottomMargin)
  if not frame or not frame.SetScale then return 1 end
  local requested = ShirsInventory_GetWindowScale and ShirsInventory_GetWindowScale() or 1
  local fitted = requested
  if UIParent and UIParent.GetWidth and UIParent.GetHeight and frame.GetWidth and frame.GetHeight then
    fitted = ShirsInventory_GetFittedWindowScale(
      frame:GetWidth(), frame:GetHeight(), requested,
      UIParent:GetWidth(), UIParent:GetHeight(), 8, bottomMargin or 8, 0, 0
    )
  end
  frame:SetScale(fitted)
  return fitted
end

function ShirsInventory_GetFrameToParentScale(frame)
  if not frame then return 1 end
  local frameScale
  local parentScale
  if frame.GetEffectiveScale then frameScale = frame:GetEffectiveScale() end
  if UIParent and UIParent.GetEffectiveScale then parentScale = UIParent:GetEffectiveScale() end
  if not frameScale and frame.GetScale then frameScale = frame:GetScale() end
  frameScale = tonumber(frameScale) or 1
  parentScale = tonumber(parentScale) or 1
  if frameScale <= 0 or parentScale <= 0 then return 1 end
  return frameScale / parentScale
end

function ShirsInventory_ClampInventoryFrame(frame, preserveSavedPosition)
  frame = frame or ShirsInventoryFrame
  if not frame then return false end
  if preserveSavedPosition and ShirsInventory_GetInventoryFramePosition and
    ShirsInventory_GetInventoryFramePosition() then
    return true
  end
  if not UIParent or not frame.GetLeft or not frame.GetTop or not frame.GetWidth or
    not frame.GetHeight then
    return true
  end
  local viewportWidth, viewportHeight = ShirsInventory_GetInventoryViewportSize()
  if not viewportWidth or not viewportHeight then return true end
  local left = frame:GetLeft()
  local top = frame:GetTop()
  if not left or not top then return true end
  local scale = ShirsInventory_GetFrameToParentScale(frame)
  local screenLeft = left * scale
  local screenTop = top * scale
  local newLeft, newTop = ShirsInventory_GetClampedTopLeft(
    screenLeft, screenTop, frame:GetWidth() * scale, frame:GetHeight() * scale,
    viewportWidth, viewportHeight, 8, ShirsInventory_GetInventoryBottomMargin(), 0, 0
  )
  if newLeft == screenLeft and newTop == screenTop then return true end
  local localLeft, localTop = newLeft / scale, newTop / scale
  if not ShirsInventory_SetInventoryFrameAnchor(
    frame, "TOPLEFT", UIParent, "BOTTOMLEFT", localLeft, localTop, false
  ) then
    return false
  end
  if ShirsInventory_SaveInventoryFrameCoordinates then
    return ShirsInventory_SaveInventoryFrameCoordinates("TOPLEFT", "BOTTOMLEFT", localLeft, localTop)
  end
  return true
end

function ShirsInventory_ClampBankFrame(frame, preserveSavedPosition)
  frame = frame or ShirsInventoryBankFrame
  if not frame then return false end
  if preserveSavedPosition and ShirsInventory_GetBankFramePosition and
    ShirsInventory_GetBankFramePosition() then
    return true
  end
  if not UIParent or not frame.GetLeft or not frame.GetBottom or not frame.GetWidth or
    not frame.GetHeight or not UIParent.GetWidth or not UIParent.GetHeight then
    return true
  end
  local left, bottom = frame:GetLeft(), frame:GetBottom()
  if not left or not bottom then return true end
  local scale = ShirsInventory_GetFrameToParentScale(frame)
  local width, height = frame:GetWidth() * scale, frame:GetHeight() * scale
  local maximumLeft = UIParent:GetWidth() - 8 - width
  local maximumBottom = UIParent:GetHeight() - 8 - height
  if maximumLeft < 8 then maximumLeft = 8 end
  if maximumBottom < 8 then maximumBottom = 8 end
  local screenLeft, screenBottom = left * scale, bottom * scale
  local newLeft = math.max(8, math.min(maximumLeft, screenLeft))
  local newBottom = math.max(8, math.min(maximumBottom, screenBottom))
  if newLeft == screenLeft and newBottom == screenBottom then return true end
  frame:ClearAllPoints()
  local localLeft, localBottom = newLeft / scale, newBottom / scale
  frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", localLeft, localBottom)
  if ShirsInventory_SaveBankFrameCoordinates then
    return ShirsInventory_SaveBankFrameCoordinates(localLeft, localBottom)
  end
  return true
end

function ShirsInventory_RecoverInventoryViewport(frame)
  frame = frame or ShirsInventoryFrame
  if not frame then return false end
  if ShirsInventory_GetCategoryMode and ShirsInventory_GetCategoryMode() then
    return ShirsInventory_RecoverCategoryViewport(frame)
  end
  ShirsInventory_ApplyViewportScale(frame, ShirsInventory_GetInventoryBottomMargin())
  return ShirsInventory_ClampInventoryFrame(frame, false)
end

-- Category View keeps the user's chosen window scale; the frame height is
-- capped by the scroll model, so this only re-applies the scale, recomputes
-- the scroll bounds from the cached layout, and keeps the frame on screen.
function ShirsInventory_RecoverCategoryViewport(frame)
  frame = frame or ShirsInventoryFrame
  if not frame then return false end
  local requested = ShirsInventory_GetWindowScale and ShirsInventory_GetWindowScale() or 1
  if frame.SetScale then frame:SetScale(requested) end
  local layout = categoryLayoutCache
  local bagBarLayout = categoryBagBarLayoutCache
  if layout and bagBarLayout and frame.SetHeight then
    local contentHeight = layout.height + 92 + bagBarLayout.heightExtra
    local viewportWidth, viewportHeight = ShirsInventory_GetInventoryViewportSize()
    local scrollModel = ShirsInventory_GetCategoryScrollModel(
      contentHeight, requested, viewportHeight or 0, ShirsInventory_GetInventoryBottomMargin()
    )
    categoryScrollMax = scrollModel.maxScroll
    if scrollModel.scrollable then
      if categoryScrollOffset > categoryScrollMax then categoryScrollOffset = categoryScrollMax end
      if categoryScrollOffset < 0 then categoryScrollOffset = 0 end
    else
      categoryScrollOffset = 0
    end
    frame:SetWidth(layout.width + (scrollModel.scrollable and CATEGORY_SCROLLBAR_WIDTH or 0))
    frame:SetHeight(scrollModel.frameHeight)
    ShirsInventory_ApplyCategoryScroll()
  end
  ShirsInventory_UpdateCategoryScrollbar()
  return ShirsInventory_ClampInventoryFrame(frame, false)
end

function ShirsInventory_RecoverBankViewport(frame)
  frame = frame or ShirsInventoryBankFrame
  if not frame then return false end
  ShirsInventory_ApplyViewportScale(frame, 8)
  return ShirsInventory_ClampBankFrame(frame, false)
end

function ShirsInventory_ApplyLayoutSettings()
  local requested = ShirsInventory_GetWindowScale and ShirsInventory_GetWindowScale() or 1
  if ShirsInventoryFrame and ShirsInventoryFrame.SetScale then ShirsInventoryFrame:SetScale(requested) end
  if ShirsInventoryBankFrame and ShirsInventoryBankFrame.SetScale then ShirsInventoryBankFrame:SetScale(requested) end
  if ShirsInventoryFrame and ShirsInventoryFrame.IsShown and ShirsInventoryFrame:IsShown() and
    ShirsInventory_Update then
    ShirsInventory_Update()
    ShirsInventory_RecoverInventoryViewport(ShirsInventoryFrame)
  end
  if ShirsInventoryBankFrame and ShirsInventoryBankFrame.IsShown and ShirsInventoryBankFrame:IsShown() and
    ShirsInventory_UpdateBank then
    ShirsInventory_UpdateBank(ShirsInventoryBankFrame)
    ShirsInventory_RecoverBankViewport(ShirsInventoryBankFrame)
  end
  return true
end

function ShirsInventory_ApplyWindowScaleSetting()
  local scale = ShirsInventory_GetWindowScale and ShirsInventory_GetWindowScale() or 1
  if ShirsInventoryFrame and ShirsInventoryFrame.SetScale then
    ShirsInventoryFrame:SetScale(scale)
    if not ShirsInventoryFrame.IsShown or ShirsInventoryFrame:IsShown() then
      ShirsInventory_RecoverInventoryViewport(ShirsInventoryFrame)
    end
  end
  if ShirsInventoryBankFrame and ShirsInventoryBankFrame.SetScale then
    ShirsInventoryBankFrame:SetScale(scale)
    if not ShirsInventoryBankFrame.IsShown or ShirsInventoryBankFrame:IsShown() then
      ShirsInventory_RecoverBankViewport(ShirsInventoryBankFrame)
    end
  end
  return true
end

local function ShirsInventory_HideCategoryHeaders()
  local index
  for index = 1, table.getn(categoryHeaders) do categoryHeaders[index]:Hide() end
end

function ShirsInventory_RebuildStandardGrid()
  ShirsInventory_HideCategoryHeaders()
  categoryScrollOffset = 0
  categoryScrollMax = 0
  categoryLayoutCache = nil
  categoryBagBarLayoutCache = nil
  ShirsInventory_UpdateCategoryScrollbar()
  local counts = ShirsInventory_GetInventorySlotCounts()
  local freeStates = {}
  local slots = ShirsInventory_BuildInventorySlots(counts)
  local layout = ShirsInventory_GetGridLayout(table.getn(slots), ShirsInventory_GetItemsPerRow())
  local bagBarLayout = ShirsInventory_GetBagBarLayout()
  ShirsInventoryFrame:SetWidth(layout.width)
  ShirsInventoryFrame:SetHeight(layout.height + bagBarLayout.heightExtra)
  ShirsInventory_RecoverInventoryViewport(ShirsInventoryFrame)
  ShirsInventory_UpdateBagBar()

  for index, address in ipairs(slots) do
    local button = inventoryButtons[index] or ShirsInventory_CreateItemButton(index)
    button.shirsInventorySearchEnabled = true
    button.shirsInventorySearchFrame = nil
    button.bag = address.bag
    button.slot = address.slot
    button:SetID(address.slot)
    button:ClearAllPoints()
    local column = math.mod(index - 1, layout.columns)
    local row = math.floor((index - 1) / layout.columns)
    button:SetPoint("TOPLEFT", ShirsInventoryFrame, "TOPLEFT", 14 + column * 40, bagBarLayout.gridTopOffset - row * 40)
    button:Show()
    ShirsInventory_UpdateItemButton(button)
    table.insert(freeStates, { bag = address.bag, hasItem = button.hasItem and true or false })
  end
  for index = table.getn(slots) + 1, table.getn(inventoryButtons) do
    inventoryButtons[index]:Hide()
  end
  ShirsInventoryFrame.freeText:SetText(ShirsInventory_CountFreeInventorySlots(freeStates) .. " free")
end

local shirsInventoryCategoryScanTooltip

function ShirsInventory_GetCategoryTooltipText(bag, slot)
  if type(CreateFrame) ~= "function" or type(getglobal) ~= "function" then return "" end
  if not shirsInventoryCategoryScanTooltip then
    shirsInventoryCategoryScanTooltip = CreateFrame(
      "GameTooltip", "ShirsInventoryCategoryScanTooltip", UIParent, "GameTooltipTemplate"
    )
    if shirsInventoryCategoryScanTooltip.SetOwner then
      shirsInventoryCategoryScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
  end
  local tooltip = shirsInventoryCategoryScanTooltip
  if tooltip.ClearLines then tooltip:ClearLines() end
  if not tooltip.SetBagItem then return "" end
  tooltip:SetBagItem(bag, slot)
  local lines = {}
  local lineCount = tooltip.NumLines and tooltip:NumLines() or 0
  local lineIndex
  for lineIndex = 1, lineCount do
    local left = getglobal("ShirsInventoryCategoryScanTooltipTextLeft" .. lineIndex)
    local right = getglobal("ShirsInventoryCategoryScanTooltipTextRight" .. lineIndex)
    local leftText = left and left.GetText and left:GetText() or nil
    local rightText = right and right.GetText and right:GetText() or nil
    if type(leftText) == "string" and leftText ~= "" then table.insert(lines, leftText) end
    if type(rightText) == "string" and rightText ~= "" then table.insert(lines, rightText) end
  end
  if tooltip.Hide then tooltip:Hide() end
  return table.concat(lines, "\n")
end

local function ShirsInventory_ShouldScanCategoryTooltip(itemType, quality)
  if not ShirsInventory_CategoryTextSignalsEnabled() then return false end
  return itemType == "Consumable" or itemType == "Miscellaneous" or tonumber(quality) == 0
end

function ShirsInventory_BuildCategoryInventoryItems(slots)
  local items = {}
  local index
  for index = 1, table.getn(slots) do
    local address = slots[index]
    local texture, count, locked, quality, readable = GetContainerItemInfo(address.bag, address.slot)
    local link = texture and GetContainerItemLink and GetContainerItemLink(address.bag, address.slot) or nil
    local info = ShirsInventory_GetItemInfoFields(link)
    local itemID = link and ShirsInventory_GetItemId and ShirsInventory_GetItemId(link) or nil
    local resolvedQuality = ShirsInventory_ResolveItemQuality(quality, info.quality)
    local materialCategory = itemID and ShirsInventory_GetMaterialCategory and
      ShirsInventory_GetMaterialCategory(itemID, info.itemType, info.itemSubType) or nil
    local tooltipText = ""
    if texture and ShirsInventory_ShouldScanCategoryTooltip(info.itemType, resolvedQuality) then
      tooltipText = ShirsInventory_GetCategoryTooltipText(address.bag, address.slot)
    end
    table.insert(items, {
      bag = address.bag,
      slot = address.slot,
      itemID = itemID,
      hasItem = texture and true or false,
      texture = texture,
      count = count,
      locked = locked,
      readable = readable,
      quality = resolvedQuality,
      itemType = info.itemType,
      itemSubType = info.itemSubType,
      materialCategory = materialCategory,
      manualCategory = itemID and ShirsInventory_GetCategoryAssignment and
        ShirsInventory_GetCategoryAssignment(itemID) or nil,
      quest = ShirsInventory_IsQuestItemType(info.itemType),
      name = info.name,
      tooltipText = tooltipText,
    })
  end
  return items
end

function ShirsInventory_ShouldDeferCategoryRebuild()
  if ShirsInventory_HasCategoryEditDrag and ShirsInventory_HasCategoryEditDrag() then return true end
  if CursorHasItem and CursorHasItem() then return true end
  if GetCursorInfo then
    local cursorType = GetCursorInfo()
    if cursorType == "item" then return true end
  end
  if GetContainerItemInfo and ShirsInventory_GetInventorySlotCounts and ShirsInventory_BuildInventorySlots then
    local slots = ShirsInventory_BuildInventorySlots(ShirsInventory_GetInventorySlotCounts())
    local index
    for index = 1, table.getn(slots) do
      local address = slots[index]
      local _, _, locked = GetContainerItemInfo(address.bag, address.slot)
      if locked then return true end
    end
  end
  return false
end

function ShirsInventory_HasPendingCategoryRebuild()
  return categoryRebuildPending and true or false
end

local function ShirsInventory_GetCategoryHeader(index)
  local header = categoryHeaders[index]
  if header then return header end
  header = CreateFrame("Button", nil, ShirsInventoryFrame)
  header:SetHeight(18)
  header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  header.text:SetAllPoints(header)
  header.text:SetTextColor(1, 0.78, 0.18)
  header.text:SetJustifyH("LEFT")
  header:SetScript("OnEnter", function()
    if GameTooltip and GameTooltip.SetOwner and this.shirsFullCategoryText then
      GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
      GameTooltip:SetText(this.shirsFullCategoryText, 1, 0.82, 0)
      GameTooltip:Show()
    end
    if ShirsInventory_GetCategoryEditMode() and ShirsInventory_SetCategoryEditHover(this.categoryKey) then
      this.text:SetTextColor(0.25, 1, 0.35)
    end
  end)
  header:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
    ShirsInventory_SetCategoryEditHover(nil)
    if ShirsInventory_GetCategoryEditMode() and this.categoryKey ~= "empty" then
      this.text:SetTextColor(0.4, 0.85, 1)
    else
      this.text:SetTextColor(1, 0.78, 0.18)
    end
    if ShirsInventory_HasCategoryEditDrag() and SetCursor then SetCursor("CAST_CURSOR") end
  end)
  header:SetScript("OnClick", function()
    if arg1 == "LeftButton" and ShirsInventory_HasCategoryEditDrag() then
      ShirsInventory_SetCategoryEditHover(this.categoryKey)
      ShirsInventory_FinishCategoryEditDrag()
    end
  end)
  ShirsInventory_EnableCategoryWheel(header)
  categoryHeaders[index] = header
  return header
end

function ShirsInventory_RebuildCategoryGrid()
  if ShirsInventory_ShouldDeferCategoryRebuild() then
    categoryRebuildPending = true
    return false, "deferred"
  end
  categoryRebuildPending = nil
  local counts = ShirsInventory_GetInventorySlotCounts()
  local slots = ShirsInventory_BuildInventorySlots(counts)
  local items = ShirsInventory_BuildCategoryInventoryItems(slots)
  local groups = ShirsInventory_BuildCategoryGroups(items)
  local layout = ShirsInventory_BuildCategoryLayout(groups, ShirsInventory_GetItemsPerRow())
  local bagBarLayout = ShirsInventory_GetBagBarLayout()
  local freeStates = ShirsInventory_BuildCategoryFreeStates(items)
  local buttonIndex = 0
  local groupIndex

  local contentHeight = layout.height + 92 + bagBarLayout.heightExtra
  local viewportWidth, viewportHeight = ShirsInventory_GetInventoryViewportSize()
  local requestedScale = ShirsInventory_GetWindowScale() or 1
  local scrollModel = ShirsInventory_GetCategoryScrollModel(
    contentHeight, requestedScale, viewportHeight or 0, ShirsInventory_GetInventoryBottomMargin()
  )
  categoryScrollMax = scrollModel.maxScroll
  if scrollModel.scrollable then
    if categoryScrollOffset > categoryScrollMax then categoryScrollOffset = categoryScrollMax end
    if categoryScrollOffset < 0 then categoryScrollOffset = 0 end
  else
    categoryScrollOffset = 0
  end
  ShirsInventoryFrame:SetScale(requestedScale)
  ShirsInventoryFrame:SetWidth(layout.width + (scrollModel.scrollable and CATEGORY_SCROLLBAR_WIDTH or 0))
  ShirsInventoryFrame:SetHeight(scrollModel.frameHeight)
  categoryLayoutCache = layout
  categoryBagBarLayoutCache = bagBarLayout
  ShirsInventory_RecoverCategoryViewport(ShirsInventoryFrame)
  ShirsInventory_UpdateBagBar()

  for groupIndex = 1, table.getn(layout.groups) do
    local group = layout.groups[groupIndex]
    local header = ShirsInventory_GetCategoryHeader(groupIndex)
    header:SetWidth(group.columns * 40)
    header.categoryKey = group.key
    header.shirsFullCategoryText = ShirsInventory_GetCategoryHeaderTooltipText(group)
    header.text:SetText(ShirsInventory_GetCategoryHeaderDisplayText(group))
    if ShirsInventory_GetCategoryEditMode() then
      if group.key == "empty" then
        header.text:SetTextColor(0.55, 0.55, 0.55)
      else
        header.text:SetTextColor(0.4, 0.85, 1)
      end
    else
      header.text:SetTextColor(1, 0.78, 0.18)
    end
    local itemIndex
    for itemIndex = 1, table.getn(group.items) do
      local item = group.items[itemIndex]
      buttonIndex = buttonIndex + 1
      local button = inventoryButtons[buttonIndex] or ShirsInventory_CreateItemButton(buttonIndex)
      item.shirsScrollButton = button
      button.shirsInventorySearchEnabled = true
      button.shirsInventorySearchFrame = nil
      button.bag = item.bag
      button.slot = item.slot
      button:SetID(item.slot)
      ShirsInventory_UpdateItemButton(button)
      if item.collapsedEmptyCount then SetItemButtonCount(button, item.collapsedEmptyCount) end
    end
  end
  local headerIndex
  for headerIndex = table.getn(layout.groups) + 1, table.getn(categoryHeaders) do
    categoryHeaders[headerIndex]:Hide()
  end
  for buttonIndex = buttonIndex + 1, table.getn(inventoryButtons) do
    inventoryButtons[buttonIndex]:Hide()
  end
  ShirsInventory_ApplyCategoryScroll()
  ShirsInventoryFrame.freeText:SetText(ShirsInventory_CountFreeInventorySlots(freeStates) .. " free")
  return true
end

function ShirsInventory_ApplyCategoryScroll()
  local layout = categoryLayoutCache
  local bagBarLayout = categoryBagBarLayoutCache
  if not layout or not bagBarLayout or not ShirsInventoryFrame then return end
  local frameHeight = ShirsInventoryFrame.GetHeight and ShirsInventoryFrame:GetHeight() or 0
  local offset = categoryScrollOffset or 0
  local groupIndex
  for groupIndex = 1, table.getn(layout.groups) do
    local group = layout.groups[groupIndex]
    local header = categoryHeaders[groupIndex]
    if header then
      local displayY = ShirsInventory_GetCategoryScrollY(
        bagBarLayout.gridTopOffset - group.labelY, offset
      )
      header:ClearAllPoints()
      header:SetPoint(
        "TOPLEFT", ShirsInventoryFrame, "TOPLEFT", 14 + group.columnX * 40, displayY
      )
      if ShirsInventory_IsCategoryScrollElementVisible(displayY, 18, frameHeight,
        bagBarLayout.gridTopOffset) then
        header:Show()
      else
        header:Hide()
      end
    end
    local itemIndex
    for itemIndex = 1, table.getn(group.items) do
      local item = group.items[itemIndex]
      local button = item.shirsScrollButton
      if button then
        local column = math.mod(itemIndex - 1, group.columns)
        local row = math.floor((itemIndex - 1) / group.columns)
        local displayY = ShirsInventory_GetCategoryScrollY(
          bagBarLayout.gridTopOffset - group.itemY - row * 40, offset
        )
        button:ClearAllPoints()
        button:SetPoint(
          "TOPLEFT", ShirsInventoryFrame, "TOPLEFT",
          14 + (group.columnX + column) * 40, displayY
        )
        if ShirsInventory_IsCategoryScrollElementVisible(displayY, 40, frameHeight,
          bagBarLayout.gridTopOffset) then
          button:Show()
        else
          button:Hide()
        end
      end
    end
  end
end

function ShirsInventory_GetCategoryScrollOffset()
  return categoryScrollOffset or 0
end

function ShirsInventory_GetCategoryScrollMax()
  return categoryScrollMax or 0
end

function ShirsInventory_GetCategoryScrollable()
  return categoryScrollMax > 0 and ShirsInventory_GetCategoryMode() and true or false
end

-- Shared category wheel handler. Attached to the frame, scrollbar, item
-- buttons, and headers because wheel events over child buttons do not reach
-- the parent frame in every client. The parent guard keeps bank buttons
-- (parented to the bank frame) from scrolling the carried category view.
function ShirsInventory_CategoryWheelHandler()
  if not (ShirsInventory_GetCategoryMode and ShirsInventory_GetCategoryMode()) then return end
  if categoryScrollMax <= 0 then return end
  local owner = this and this.GetParent and this:GetParent() or nil
  if this ~= ShirsInventoryFrame and owner and owner ~= ShirsInventoryFrame then return end
  local delta = tonumber(arg1) or 0
  if delta == 0 then return end
  ShirsInventory_ScrollCategoryBy(-delta * 40)
end

-- Vanilla ignores OnMouseWheel unless EnableMouseWheel(true) is set on that
-- exact frame. Child buttons also swallow the event, so every interactive
-- surface over the category window must enable the wheel itself.
function ShirsInventory_EnableCategoryWheel(frame)
  if not frame then return false end
  if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
  if frame.SetScript then frame:SetScript("OnMouseWheel", ShirsInventory_CategoryWheelHandler) end
  return true
end

function ShirsInventory_UpdateCategoryScrollbar()
  local frame = ShirsInventoryFrame
  if not frame then return end
  if categoryScrollMax > 0 and ShirsInventory_GetCategoryMode() then
    if not categoryScrollBar then
      if type(CreateFrame) ~= "function" then return end
      categoryScrollBar = CreateFrame("Slider", nil, frame)
      categoryScrollBar:SetOrientation("VERTICAL")
      categoryScrollBar:SetValueStep(40)
      categoryScrollBar:SetWidth(CATEGORY_SCROLLBAR_WIDTH)
      categoryScrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
      categoryScrollBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
      })
      categoryScrollBar:SetBackdropColor(0.1, 0.12, 0.18, 0.6)
      categoryScrollBar:SetBackdropBorderColor(0.35, 0.45, 0.6, 0.8)
      categoryScrollBar:SetPoint("TOPLEFT", frame, "TOPRIGHT", -CATEGORY_SCROLLBAR_WIDTH - 4, -34)
      categoryScrollBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -CATEGORY_SCROLLBAR_WIDTH - 4, 34)
      categoryScrollBar:SetScript("OnValueChanged", function()
        if categoryScrollBarUpdating then return end
        local value = tonumber(this:GetValue()) or 0
        if value < 0 then value = 0 end
        if value > categoryScrollMax then value = categoryScrollMax end
        categoryScrollOffset = value
        ShirsInventory_ApplyCategoryScroll()
      end)
      ShirsInventory_EnableCategoryWheel(categoryScrollBar)
    end
    categoryScrollBarUpdating = true
    categoryScrollBar:SetMinMaxValues(0, categoryScrollMax)
    categoryScrollBar:SetValue(categoryScrollOffset)
    categoryScrollBarUpdating = false
    categoryScrollBar:Show()
  elseif categoryScrollBar then
    categoryScrollBar:Hide()
  end
end

function ShirsInventory_ScrollCategoryBy(delta)
  delta = tonumber(delta) or 0
  if delta == 0 or categoryScrollMax <= 0 then return false end
  local value = categoryScrollOffset + delta
  if value < 0 then value = 0 end
  if value > categoryScrollMax then value = categoryScrollMax end
  if value == categoryScrollOffset then return false end
  categoryScrollOffset = value
  ShirsInventory_ApplyCategoryScroll()
  if categoryScrollBar and categoryScrollBar.SetValue then
    categoryScrollBarUpdating = true
    categoryScrollBar:SetValue(value)
    categoryScrollBarUpdating = false
  end
  return true
end

function ShirsInventory_Update()
  if not ShirsInventoryFrame or not ShirsInventoryFrame:IsShown() then return end
  if ShirsInventory_GetCategoryMode and ShirsInventory_GetCategoryMode() then
    if ShirsInventory_ShouldDeferCategoryRebuild() then
      categoryRebuildPending = true
    else
      categoryRebuildPending = nil
      ShirsInventory_RebuildCategoryGrid()
    end
  else
    categoryRebuildPending = nil
    ShirsInventory_RebuildStandardGrid()
  end
  ShirsInventory_UpdateControlLabels()
end

function ShirsInventory_ProcessDeferredCategoryRebuild()
  if not categoryRebuildPending then return false end
  if not ShirsInventoryFrame or not ShirsInventoryFrame:IsShown() then return false end
  if ShirsInventory_ShouldDeferCategoryRebuild() then return false end
  ShirsInventory_Update()
  return not categoryRebuildPending
end

function ShirsInventory_RequestBankSlotPurchase()
  if type(StaticPopup_Show) ~= "function" then return false end
  StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
  return true
end

function ShirsInventory_SuppressOtherBankFrames(nativeBank, extraFrames)
  nativeBank = nativeBank or BankFrame
  if nativeBank then
    if nativeBank.SetScale then nativeBank:SetScale(0.001) end
    if nativeBank.SetAlpha then nativeBank:SetAlpha(0) end
    if nativeBank.EnableMouse then nativeBank:EnableMouse(false) end
  end
  local frames = extraFrames or {}
  if not extraFrames then
    local names = {"pfBank", "OneBankFrame", "BagnonBankFrame", "BagnonFramebank", "ArkInventory_Bank"}
    local index
    for index = 1, table.getn(names) do
      local other = getglobal and getglobal(names[index]) or nil
      if other then table.insert(frames, other) end
    end
    if pfUI and pfUI.bag and pfUI.bag.left then table.insert(frames, pfUI.bag.left) end
  end
  local index
  for index = 1, table.getn(frames) do
    local other = frames[index]
    if other and other ~= ShirsInventoryBankFrame and other.Hide then other:Hide() end
  end
  return true
end

function ShirsInventory_CreateBankActionButtons(frame)
  if not frame or not CreateFrame then return false end
  frame.sortButton = CreateFrame("Button", nil, frame)
  frame.sortButton:SetWidth(64)
  frame.sortButton:SetHeight(22)
  frame.sortButton:SetText("Sort")
  frame.sortButton:SetScript("OnClick", function() ShirsInventory_OnSortButtonClick(true) end)

  frame.modeButton = CreateFrame("Button", nil, frame)
  frame.modeButton:SetWidth(80)
  frame.modeButton:SetHeight(22)
  frame.modeButton:SetScript("OnClick", function() ShirsInventory_OnModeButtonClick(true) end)

  frame.directionButton = CreateFrame("Button", nil, frame)
  frame.directionButton:SetWidth(64)
  frame.directionButton:SetHeight(22)
  frame.directionButton:SetScript("OnClick", function()
    if ShirsInventory_ToggleDirection then ShirsInventory_ToggleDirection() end
    ShirsInventory_UpdateControlLabels()
  end)

  frame.settingsButton = CreateFrame("Button", nil, frame)
  frame.settingsButton:SetWidth(72)
  frame.settingsButton:SetHeight(22)
  frame.settingsButton:SetText("Settings")
  frame.settingsButton:SetScript("OnClick", function()
    if ShirsInventory_ShowSettings then ShirsInventory_ShowSettings() end
  end)
  return true
end

function ShirsInventory_HandleBankBagClick(button, mouseButton)
  if not button or not button.bag then return false end
  if IsShiftKeyDown and IsShiftKeyDown() and type(BankFrameItemButtonBag_OnShiftClick) == "function" then
    BankFrameItemButtonBag_OnShiftClick()
    return true
  end
  if type(BankFrameItemButtonBag_OnClick) == "function" then
    BankFrameItemButtonBag_OnClick(mouseButton)
    return true
  end
  local inventoryID = BankButtonIDToInvSlotID and BankButtonIDToInvSlotID(button.bag, 1) or nil
  if not inventoryID then return false end
  if IsShiftKeyDown and IsShiftKeyDown() and PickupBagFromSlot then
    PickupBagFromSlot(inventoryID)
    return true
  end
  if CursorHasItem and CursorHasItem() then
    if PutItemInBag then PutItemInBag(inventoryID) end
  elseif ToggleBag then
    ToggleBag(button.bag)
  end
  return true
end

function ShirsInventory_HandleBankBagDrop(button, mouseButton)
  if not button or not button.bag then return false end
  if type(BankFrameItemButtonBag_OnClick) == "function" then
    BankFrameItemButtonBag_OnClick(mouseButton or "LeftButton")
    return true
  end
  local inventoryID = BankButtonIDToInvSlotID and BankButtonIDToInvSlotID(button.bag, 1) or nil
  if not inventoryID then return false end
  if PutItemInBag then PutItemInBag(inventoryID) end
  return true
end

function ShirsInventory_BindBankBagButtonScripts(button)
  if not button or not button.SetScript then return false end
  button:SetScript("OnClick", function() ShirsInventory_HandleBankBagClick(this, arg1) end)
  button:SetScript("OnDragStart", function()
    if PickupBagFromSlot and this.inventoryID then PickupBagFromSlot(this.inventoryID) end
  end)
  button:SetScript("OnReceiveDrag", function() ShirsInventory_HandleBankBagDrop(this, "LeftButton") end)
  return true
end

function ShirsInventory_ApplyBankBagButtonVisuals(button, purchase)
  if not button then return false end
  local layout = ShirsInventory_GetBankFrameLayout()
  button:SetWidth(layout.bankBagButtonSize)
  button:SetHeight(layout.bankBagButtonSize)
  if button.SetNormalTexture then button:SetNormalTexture(nil) end
  if not button.icon and button.CreateTexture then
    button.icon = button:CreateTexture(nil, "ARTWORK")
  end
  if button.icon then
    button.icon:ClearAllPoints()
    button.icon:SetAllPoints(button)
    if purchase then
      button.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
      button.icon:SetVertexColor(0.45, 0.45, 0.45, 1)
    end
  end
  button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
  local highlight = button:GetHighlightTexture()
  if highlight then
    if highlight.ClearAllPoints then highlight:ClearAllPoints() end
    highlight:SetAllPoints(button)
    highlight:SetVertexColor(0.15, 0.5, 1, 0.28)
  end
  return true
end

function ShirsInventory_SetBankBagRangeHighlight(bag, buttons)
  buttons = buttons or bankButtons
  local index
  for index = 1, table.getn(buttons) do
    local itemButton = buttons[index]
    if itemButton.bagRangeHighlight then
      if bag ~= nil and itemButton:IsShown() and ShirsInventory_ShouldHighlightBagSlot(itemButton, bag) then
        itemButton.bagRangeHighlight:Show()
      else
        itemButton.bagRangeHighlight:Hide()
      end
    end
  end
  return true
end

function ShirsInventory_OnBankBagEnter(button, buttons)
  if not button or not button.bagEntry then return false end
  local entry = button.bagEntry
  ShirsInventory_SetBankBagRangeHighlight(entry.bag, buttons)
  local inventoryID = button.inventoryID or entry.inventoryID
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  if button.texture and inventoryID and GameTooltip.SetInventoryItem then
    GameTooltip:SetInventoryItem("player", inventoryID)
  else
    GameTooltip:SetText(BANK_BAG or "Bank Bag", 1, 0.82, 0)
  end
  GameTooltip:AddLine((entry.slots or 0) .. " slots", 0.65, 0.8, 1)
  if entry.firstCombinedIndex then
    GameTooltip:AddLine(
      "Combined slots " .. entry.firstCombinedIndex .. "-" .. entry.lastCombinedIndex,
      0.35, 0.7, 1
    )
  end
  GameTooltip:AddLine("Left-click or drag to remove or swap this bag.", 0.45, 0.8, 1, 1)
  GameTooltip:Show()
  return true
end

function ShirsInventory_OnBankBagLeave(buttons)
  ShirsInventory_SetBankBagRangeHighlight(nil, buttons)
  GameTooltip:Hide()
  return true
end

function ShirsInventory_ApplyBankFrameAnchor(frame)
  if not frame then return false end
  local anchor = ShirsInventory_GetBankFramePosition and ShirsInventory_GetBankFramePosition() or nil
  if not anchor then anchor = ShirsInventory_GetBankFrameAnchor() end
  frame:ClearAllPoints()
  frame:SetPoint(anchor.point, UIParent, anchor.relativePoint, anchor.x, anchor.y)
  return true
end

function ShirsInventory_OnBankDragStop(frame)
  if not frame then return false end
  if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
  if not ShirsInventory_SaveBankFramePosition or not ShirsInventory_SaveBankFramePosition(frame) then
    return false
  end
  return ShirsInventory_ApplyBankFrameAnchor(frame)
end

local function ShirsInventory_CreateBankBagButton(frame, index)
  local button = CreateFrame("Button", "ShirsInventoryBankBag" .. index, frame)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button.isBag = 1
  button.GetInventorySlot = function(self)
    return BankButtonIDToInvSlotID and BankButtonIDToInvSlotID(self:GetID(), 1) or nil
  end
  ShirsInventory_ApplyBankBagButtonVisuals(button, false)
  ShirsInventory_BindBankBagButtonScripts(button)
  button:SetScript("OnEnter", function() ShirsInventory_OnBankBagEnter(this) end)
  button:SetScript("OnLeave", function() ShirsInventory_OnBankBagLeave() end)
  bankBagButtons[index] = button
  return button
end

local function ShirsInventory_CreateBankPurchaseButton(frame)
  local button = CreateFrame("Button", "ShirsInventoryBankPurchaseButton", frame)
  ShirsInventory_ApplyBankBagButtonVisuals(button, true)
  button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  button.text:SetPoint("CENTER", button, "CENTER", 0, 1)
  button.text:SetText("+")
  button.text:SetTextColor(0.45, 0.65, 1, 1)
  button:SetScript("OnClick", function() ShirsInventory_RequestBankSlotPurchase() end)
  button:SetScript("OnEnter", function()
    this.text:SetTextColor(1, 1, 1, 1)
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(BANK_BAG_PURCHASE or "Purchase Bank Bag Slot", 1, 0.82, 0)
    GameTooltip:AddLine("Click to review the price and buy the next bank bag slot.", 0.9, 0.9, 0.9, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    this.text:SetTextColor(0.45, 0.65, 1, 1)
    GameTooltip:Hide()
  end)
  bankPurchaseButton = button
  return button
end

function ShirsInventory_UpdateBankBagBar(frame, slotCounts)
  if not frame then return false end
  local purchased = 0
  if GetNumBankSlots then purchased = GetNumBankSlots() or 0 end
  local textures = {}
  local index
  for index = 1, purchased do
    local bag = index + 4
    local inventoryID = BankButtonIDToInvSlotID and BankButtonIDToInvSlotID(bag, 1) or nil
    textures[index] = inventoryID and GetInventoryItemTexture and GetInventoryItemTexture("player", inventoryID) or nil
  end
  slotCounts = slotCounts or ShirsInventory_GetBankSlotCounts()
  local entries = ShirsInventory_BuildBankBagBarModel(
    purchased, ShirsInventory_GetBankBagSlotLimit(), textures, slotCounts
  )
  local layout = ShirsInventory_GetBankFrameLayout()
  for index = 1, table.getn(bankBagButtons) do bankBagButtons[index]:Hide() end
  if bankPurchaseButton then bankPurchaseButton:Hide() end
  local buttonIndex = 0
  local entry
  for index, entry in ipairs(entries) do
    local button
    if entry.purchase then
      button = bankPurchaseButton or ShirsInventory_CreateBankPurchaseButton(frame)
    else
      buttonIndex = buttonIndex + 1
      button = bankBagButtons[buttonIndex] or ShirsInventory_CreateBankBagButton(frame, buttonIndex)
      button.bag = entry.bag
      button.bagEntry = entry
      button.inventoryID = BankButtonIDToInvSlotID and BankButtonIDToInvSlotID(entry.bag, 1) or nil
      button.texture = entry.texture
      button.icon:SetTexture(entry.texture or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
      if entry.texture then button.icon:SetVertexColor(1, 1, 1) else button.icon:SetVertexColor(0.45, 0.45, 0.45) end
      button:SetID(entry.bag)
    end
    button:ClearAllPoints()
    button:SetPoint(
      layout.bankBagAnchorPoint, frame, layout.bankBagAnchorPoint,
      14 + (index - 1) * (layout.bankBagButtonSize + layout.bankBagButtonGap), layout.bankBagTopOffset
    )
    button:Show()
  end
  return true
end

function ShirsInventory_IsDepositBoxGossipOption(optionText, optionType)
  if optionType ~= "banker" then return false end
  return optionText == "I would like to check my deposit box." or
    optionText == "I would like to check my deposit box"
end

function ShirsInventory_TryOpenBankFromGossip()
  if type(GetGossipOptions) ~= "function" or type(SelectGossipOption) ~= "function" then
    return false
  end
  local options = {GetGossipOptions()}
  local rawIndex
  for rawIndex = 1, table.getn(options), 2 do
    if ShirsInventory_IsDepositBoxGossipOption(options[rawIndex], options[rawIndex + 1]) then
      SelectGossipOption((rawIndex + 1) / 2)
      return true
    end
  end
  return false
end

function ShirsInventory_HandleBankEvent(eventName, frame)
  if not frame then return false end
  if eventName == "GOSSIP_SHOW" then
    return ShirsInventory_TryOpenBankFromGossip()
  elseif eventName == "BANKFRAME_OPENED" then
    ShirsInventory_SuppressOtherBankFrames()
    frame:Show()
    if ShirsInventory_UpdateBank then ShirsInventory_UpdateBank(frame) end
    return true
  elseif eventName == "BANKFRAME_CLOSED" then
    frame:Hide()
    return true
  elseif eventName == "PLAYERBANKSLOTS_CHANGED" or eventName == "PLAYERBANKBAGSLOTS_CHANGED" or
    eventName == "BAG_UPDATE" or eventName == "BAG_UPDATE_COOLDOWN" or eventName == "ITEM_LOCK_CHANGED" then
    if frame:IsShown() then
      if ShirsInventory_UpdateBank then ShirsInventory_UpdateBank(frame) end
      return true
    end
  end
  return false
end

function ShirsInventory_UpdateBank(frame)
  frame = frame or ShirsInventoryBankFrame
  if not frame or not frame:IsShown() then return false end
  local bankLayout = ShirsInventory_GetBankFrameLayout()
  local slotCounts = ShirsInventory_GetBankSlotCounts()
  local slots = ShirsInventory_BuildBankSlots(slotCounts)
  local grid = ShirsInventory_GetGridLayout(table.getn(slots), bankLayout.maximumColumns)
  local free = 0
  frame:SetWidth(grid.width)
  frame:SetHeight(grid.rows * bankLayout.itemStep + bankLayout.gridTopOffset * -1 + bankLayout.footerHeight)
  ShirsInventory_RecoverBankViewport(frame)

  local index, address
  for index, address in ipairs(slots) do
    local button = bankButtons[index] or ShirsInventory_CreateItemButton(
      index, frame, "ShirsInventoryBankItem", bankButtons
    )
    button.shirsInventorySearchEnabled = false
    button.shirsInventorySearchFrame = frame
    button.bag = address.bag
    button.slot = address.slot
    button:SetID(address.slot)
    button:ClearAllPoints()
    local column = math.mod(index - 1, grid.columns)
    local row = math.floor((index - 1) / grid.columns)
    button:SetPoint(
      "TOPLEFT", frame, "TOPLEFT",
      14 + column * bankLayout.itemStep,
      bankLayout.gridTopOffset - row * bankLayout.itemStep
    )
    button:Show()
    ShirsInventory_UpdateItemButton(button)
    if not button.hasItem then free = free + 1 end
  end
  for index = table.getn(slots) + 1, table.getn(bankButtons) do
    bankButtons[index]:Hide()
  end
  frame.freeText:SetText(free .. " free")
  ShirsInventory_UpdateBankBagBar(frame, slotCounts)
  ShirsInventory_RefreshBankButtonStyles()
  return true
end

function ShirsInventory_CreateBankFrame()
  if ShirsInventoryBankFrame then return ShirsInventoryBankFrame end
  local frame = CreateFrame("Frame", "ShirsInventoryBankFrame", UIParent)
  ShirsInventoryBankFrame = frame
  frame:SetScale(ShirsInventory_GetWindowScale())
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  ShirsInventory_ApplyBankFrameAnchor(frame)
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  frame:SetBackdropColor(0.035, 0.045, 0.065, 0.96)
  frame:SetBackdropBorderColor(0.3, 0.55, 0.8, 1)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -13)
  frame.title:SetText(ShirsInventory_GetBankTitle(UnitName and UnitName("player")))
  frame.freeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

  frame.dragHandle = CreateFrame("Button", nil, frame)
  frame.dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -5)
  frame.dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -150, -5)
  frame.dragHandle:SetHeight(25)
  frame.dragHandle:RegisterForDrag("LeftButton")
  frame.dragHandle:SetScript("OnDragStart", function() frame:StartMoving() end)
  frame.dragHandle:SetScript("OnDragStop", function() ShirsInventory_OnBankDragStop(frame) end)

  frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
  frame.freeText:SetPoint("RIGHT", frame.closeButton, "LEFT", -2, 0)
  frame.closeButton:SetScript("OnClick", function()
    if CloseBankFrame then CloseBankFrame() else ShirsInventoryBankFrame:Hide() end
  end)

  ShirsInventory_CreateBankActionButtons(frame)
  ShirsInventory_CreateBankSearchBox(frame)

  frame:SetScript("OnShow", function()
    ShirsInventory_ApplyBankFrameAnchor(this)
    this.title:SetText(ShirsInventory_GetBankTitle(UnitName and UnitName("player")))
    ShirsInventory_SuppressOtherBankFrames()
    ShirsInventory_RefreshBankButtonStyles()
  end)
  frame:SetScript("OnHide", function()
    ShirsInventory_ClearSearch(frame)
    if frame.searchBox and frame.searchBox.ClearFocus then frame.searchBox:ClearFocus() end
  end)
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() ShirsInventory_OnBankDragStop(this) end)
  frame:SetScript("OnEvent", function()
    ShirsInventory_HandleBankEvent(event, this)
  end)
  frame:SetScript("OnUpdate", function()
    ShirsInventory_ProcessDeferredSearchFocus(this)
    this.suppressElapsed = (this.suppressElapsed or 0) + arg1
    if this.suppressElapsed >= 0.10 then
      this.suppressElapsed = 0
      ShirsInventory_SuppressOtherBankFrames()
    end
  end)
  frame:RegisterEvent("BANKFRAME_OPENED")
  frame:RegisterEvent("GOSSIP_SHOW")
  frame:RegisterEvent("BANKFRAME_CLOSED")
  frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
  frame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
  frame:RegisterEvent("BAG_UPDATE")
  frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
  frame:RegisterEvent("ITEM_LOCK_CHANGED")
  frame:Hide()
  return frame
end

local function ShirsInventory_CreateMainFrame()
  local frame = CreateFrame("Frame", "ShirsInventoryFrame", UIParent)
  ShirsInventoryFrame = frame
  frame:SetScale(ShirsInventory_GetWindowScale())
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  ShirsInventory_ConfigureInventoryFrameMovement(frame)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  ShirsInventory_ApplyInventoryFramePosition(frame)
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  frame:SetBackdropColor(0.035, 0.045, 0.065, 0.96)
  frame:SetBackdropBorderColor(0.3, 0.55, 0.8, 1)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -13)
  ShirsInventory_RefreshInventoryTitle(frame, UnitName and UnitName("player"))
  frame.freeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.freeText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -35, -16)

  frame.dragHandle = CreateFrame("Button", nil, frame)
  frame.dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -5)
  frame.dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -150, -5)
  frame.dragHandle:SetHeight(25)
  ShirsInventory_BindInventoryDragHandle(frame, frame.dragHandle)
  ShirsInventory_EnableCategoryWheel(frame.dragHandle)

  frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)

  ShirsInventory_CreateBagBar(frame)

  frame.sortButton = CreateFrame("Button", nil, frame)
  frame.sortButton:SetWidth(64)
  frame.sortButton:SetHeight(22)
  frame.sortButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 13)
  frame.sortButton:SetText("Sort")
  frame.sortButton:SetScript("OnClick", function() ShirsInventory_OnSortButtonClick(false) end)
  ShirsInventory_EnableCategoryWheel(frame.sortButton)

  frame.modeButton = CreateFrame("Button", nil, frame)
  frame.modeButton:SetWidth(80)
  frame.modeButton:SetHeight(22)
  frame.modeButton:SetPoint("LEFT", frame.sortButton, "RIGHT", 4, 0)
  frame.modeButton:SetScript("OnClick", function() ShirsInventory_OnModeButtonClick(false) end)
  ShirsInventory_EnableCategoryWheel(frame.modeButton)

  frame.directionButton = CreateFrame("Button", nil, frame)
  frame.directionButton:SetWidth(64)
  frame.directionButton:SetHeight(22)
  frame.directionButton:SetPoint("LEFT", frame.modeButton, "RIGHT", 4, 0)
  frame.directionButton:SetScript("OnClick", function()
    if ShirsInventory_ToggleDirection then ShirsInventory_ToggleDirection() end
    ShirsInventory_UpdateControlLabels()
  end)
  ShirsInventory_EnableCategoryWheel(frame.directionButton)

  frame.settingsButton = CreateFrame("Button", nil, frame)
  frame.settingsButton:SetWidth(72)
  frame.settingsButton:SetHeight(22)
  frame.settingsButton:SetPoint("LEFT", frame.directionButton, "RIGHT", 4, 0)
  frame.settingsButton:SetText("Settings")
  frame.settingsButton:SetScript("OnClick", function() ShirsInventory_ShowSettings() end)
  ShirsInventory_EnableCategoryWheel(frame.settingsButton)

  ShirsInventory_CreateSearchBox(frame)

  frame:SetScript("OnShow", function()
    if ShirsInventory_OnInventoryVisibilityChanged then ShirsInventory_OnInventoryVisibilityChanged() end
    ShirsInventory_PrepareInventoryFrameForShow(this, UnitName and UnitName("player"))
    ShirsInventory_HideNativeNormalBags()
    ShirsInventory_SetBagChecks(1)
    ShirsInventory_Update()
    PlaySound("igBackPackOpen")
  end)
  frame:SetScript("OnHide", function()
    if ShirsInventory_OnInventoryVisibilityChanged then ShirsInventory_OnInventoryVisibilityChanged() end
    ShirsInventory_SetCategoryEditMode(false)
    ShirsInventory_ClearSearch(frame)
    if frame.searchBox and frame.searchBox.ClearFocus then frame.searchBox:ClearFocus() end
    ShirsInventory_SetBagChecks(0)
    if GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
    PlaySound("igBackPackClose")
  end)
  frame:SetScript("OnUpdate", function()
    ShirsInventory_ProcessDeferredSearchFocus(this)
    ShirsInventory_ProcessDeferredCategoryRebuild()
  end)
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function()
    ShirsInventory_OnInventoryDragStop(this)
  end)

  frame:SetScript("OnEvent", function()
    if event == "BAG_UPDATE" or event == "BAG_UPDATE_COOLDOWN" or event == "ITEM_LOCK_CHANGED" or event == "UPDATE_INVENTORY_ALERTS" then
      ShirsInventory_Update()
    elseif event == "MERCHANT_SHOW" then
      ShirsInventory_Update()
    elseif event == "MERCHANT_CLOSED" then
      ShirsInventory_CancelJunkSale()
    end
  end)
  frame:RegisterEvent("BAG_UPDATE")
  frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
  frame:RegisterEvent("ITEM_LOCK_CHANGED")
  frame:RegisterEvent("UPDATE_INVENTORY_ALERTS")
  frame:RegisterEvent("MERCHANT_SHOW")
  frame:RegisterEvent("MERCHANT_CLOSED")
  ShirsInventory_EnableCategoryWheel(frame)
  frame:Hide()

  table.insert(UISpecialFrames, "ShirsInventoryFrame")
  ShirsInventory_UpdateControlLabels()
  ShirsInventory_RefreshInventoryButtonStyles()
  return frame
end

function ShirsInventory_HandleSlashCommand(message)
  local _, _, command, value = string.find(message or "", "^%s*(%S*)%s*(.-)%s*$")
  command = string.lower(command or "")
  if command == "pin" or command == "unpin" then
    local ok, status, itemId = ShirsInventory_SetHearthstoneItem(value, command == "pin")
    if ok then
      if status == "added" then
        if ShirsInventory_GetLockSelectedItemSlots() then
          ShirsInventory_Message("Added item " .. itemId .. " to the selected list. Its carried slots will stay locked during sorting.")
        elseif ShirsInventory_GetAutomaticHearthstoneItems() then
          ShirsInventory_Message("Added item " .. itemId .. " to the selected list. Switch to Selected mode to use it.")
        else
          ShirsInventory_Message("Added item " .. itemId .. " beside Hearthstone.")
        end
      elseif status == "removed" then
        ShirsInventory_Message("Removed item " .. itemId .. " from the selected list.")
      elseif status == "present" then
        if ShirsInventory_GetLockSelectedItemSlots() then
          ShirsInventory_Message("Item " .. itemId .. " is already in the selected list. Its carried slots stay locked during sorting.")
        elseif ShirsInventory_GetAutomaticHearthstoneItems() then
          ShirsInventory_Message("Item " .. itemId .. " is already in the selected list. Switch to Selected mode to use it.")
        else
          ShirsInventory_Message("Item " .. itemId .. " is already beside Hearthstone.")
        end
      elseif status == "absent" then
        ShirsInventory_Message("Item " .. itemId .. " is not in the selected list.")
      end
    elseif status == "fixed" then
      ShirsInventory_Message("Hearthstone is always fixed at the selected edge.")
    elseif status == "full" then
      ShirsInventory_Message("The selected item list is full (30).")
    else
      ShirsInventory_Message("Use /si " .. command .. " <item ID or item link>.")
    end
    if type(ShirsInventory_RefreshHearthstoneItemsFrame) == "function" then
      ShirsInventory_RefreshHearthstoneItemsFrame()
    end
    return ok
  elseif command == "mark" or command == "unmark" then
    local ok, status, itemId = ShirsInventory_SetJunkMark(value, command == "mark")
    if ok then
      ShirsInventory_Message((status == "marked" and "Marked item " or "Removed junk mark from item ") .. itemId .. ".")
    elseif status == "disabled" then
      ShirsInventory_Message("Junk tools are disabled for this character.")
    else
      ShirsInventory_Message("Use /si " .. command .. " <item ID or item link>.")
    end
    return ok
  elseif command == "sort" then
    ShirsInventory_SortBags()
  elseif command == "junk" then
    ShirsInventory_StartJunkSale()
  elseif command == "settings" or command == "options" then
    ShirsInventory_ShowSettings()
  elseif command == "bank" then
    if BankFrame and BankFrame.IsVisible and BankFrame:IsVisible() and ShirsInventoryBankFrame then
      ShirsInventoryBankFrame:Show()
      ShirsInventory_UpdateBank(ShirsInventoryBankFrame)
    else
      ShirsInventory_Message("Open a bank before using the combined bank window.")
    end
  else
    ToggleBackpack()
  end
  return true
end

function ShirsInventory_InitializeUI()
  if ShirsInventoryFrame then return ShirsInventoryFrame end
  local frame = ShirsInventory_CreateMainFrame()
  ShirsInventory_InstallWorldFrameSearchHook()
  ShirsInventory_InstallSpecialFrameEscapeHook()
  ShirsInventory_CreateBankFrame()
  if ShirsInventory_CreateSettingsUI then ShirsInventory_CreateSettingsUI() end
  ShirsInventory_ApplyFeatureSelection()

  SLASH_SHIRSINVENTORY1 = "/si"
  SLASH_SHIRSINVENTORY2 = "/shirsinventory"
  SlashCmdList["SHIRSINVENTORY"] = ShirsInventory_HandleSlashCommand
  return frame
end

function ShirsInventory_HandleLoaderEvent(eventName, addonName, loader)
  if eventName == "ADDON_LOADED" then
    if addonName == "ShirsInventory" then ShirsInventory_InitializeUI() end
    if ShirsInventory_IsBagAddonProviderName and ShirsInventory_IsBagAddonProviderName(addonName) then
      ShirsInventory_ScanLoadedBagAddons()
      ShirsInventory_ApplyFeatureSelection()
    end
  elseif eventName == "PLAYER_LOGIN" then
    ShirsInventory_InitializeUI()
    ShirsInventory_ScanLoadedBagAddons()
    ShirsInventory_ApplyFeatureSelection()
    if loader and loader.UnregisterEvent then loader:UnregisterEvent("PLAYER_LOGIN") end
  elseif eventName == "PLAYER_ENTERING_WORLD" then
    -- Another bag addon can install its handlers during this same event. Reapply
    -- on the next update so Shir's full-suite ownership wins after every
    -- handler for PLAYER_ENTERING_WORLD has finished.
    if loader and loader.SetScript then
      loader:SetScript("OnUpdate", function()
        this:SetScript("OnUpdate", nil)
        ShirsInventory_ScanLoadedBagAddons()
        ShirsInventory_ApplyFeatureSelection()
      end)
    else
      ShirsInventory_ScanLoadedBagAddons()
      ShirsInventory_ApplyFeatureSelection()
    end
  end
end

if CreateFrame then
  local loader = CreateFrame("Frame")
  loader:RegisterEvent("ADDON_LOADED")
  loader:RegisterEvent("PLAYER_LOGIN")
  loader:RegisterEvent("PLAYER_ENTERING_WORLD")
  loader:SetScript("OnEvent", function()
    ShirsInventory_HandleLoaderEvent(event, arg1, this)
  end)
end
