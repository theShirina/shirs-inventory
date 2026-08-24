ShirsInventory_MaterialRanks = {
  Mining = 1,
  Herbs = 2,
  Cloth = 3,
  Leather = 4,
  Enchanting = 5,
  ["Enchanting Materials"] = 5.25,
  Elemental = 6,
  Engineering = 7,
  Gems = 8,
  ["Raid Tokens"] = 8.25,
}

local materialCategoryAliases = {
  mining = "Mining",
  ore = "Mining",
  herbs = "Herbs",
  herb = "Herbs",
  cloth = "Cloth",
  leather = "Leather",
  enchanting = "Enchanting",
  enchant = "Enchanting",
  elemental = "Elemental",
  engineering = "Engineering",
  engineer = "Engineering",
  gems = "Gems",
  gem = "Gems",
  general = "General",
}

local professionCategories = {
  alchemy = "Herbs",
  blacksmithing = "Mining",
  mining = "Mining",
  tailoring = "Cloth",
  leatherworking = "Leather",
  enchanting = "Enchanting",
  engineering = "Engineering",
}

local SHIRS_INVENTORY_MAX_HEARTHSTONE_ITEMS = 30
local SHIRS_INVENTORY_MAX_CUSTOM_CATEGORIES = 12
local SHIRS_INVENTORY_MAX_CUSTOM_CATEGORY_NAME = 28
local SHIRS_INVENTORY_MAX_CUSTOM_CATEGORY_ID = 999999

local function ShirsInventory_NormalizeCustomCategoryName(value)
  if type(value) ~= "string" then return nil end
  if string.find(value, "[%c|]") then return nil end
  local name = string.gsub(string.gsub(value, "^%s+", ""), "%s+$", "")
  if string.len(name) == 0 or string.len(name) > SHIRS_INVENTORY_MAX_CUSTOM_CATEGORY_NAME then return nil end
  return name
end

local function ShirsInventory_NormalizeCustomCategories(values)
  local normalized, seenKeys, seenNames, highestID = {}, {}, {}, 0
  if type(values) ~= "table" then return normalized, highestID end
  local index
  for index = 1, table.getn(values) do
    local entry = values[index]
    local key = type(entry) == "table" and entry.key or nil
    local label = type(entry) == "table" and ShirsInventory_NormalizeCustomCategoryName(entry.label) or nil
    local idText
    if type(key) == "string" then
      local _, _, foundID = string.find(key, "^custom:(%d+)$")
      idText = foundID
    end
    local id = tonumber(idText)
    local nameKey = label and string.lower(label) or nil
    if id and id >= 1 and id <= SHIRS_INVENTORY_MAX_CUSTOM_CATEGORY_ID and
      id == math.floor(id) and label and not seenNames[nameKey] and
      table.getn(normalized) < SHIRS_INVENTORY_MAX_CUSTOM_CATEGORIES then
      key = "custom:" .. id
      if not seenKeys[key] then
        seenKeys[key], seenNames[nameKey] = true, true
        table.insert(normalized, { key = key, label = label })
        if id > highestID then highestID = id end
      end
    end
  end
  return normalized, highestID
end

local function ShirsInventory_NormalizeHearthstoneItems(values)
  local normalized = {}
  local seen = {}
  if type(values) ~= "table" then return normalized end
  local index
  for index = 1, table.getn(values) do
    local itemID = tonumber(values[index])
    if itemID then itemID = math.floor(itemID) end
    if itemID and itemID > 0 and itemID ~= 6948 and not seen[itemID] and
      table.getn(normalized) < SHIRS_INVENTORY_MAX_HEARTHSTONE_ITEMS then
      seen[itemID] = true
      table.insert(normalized, itemID)
    end
  end
  return normalized
end

local function ShirsInventory_EnsureDB()
  if type(ShirsInventoryDB) ~= "table" then
    ShirsInventoryDB = {}
  end
  if ShirsInventoryDB.direction ~= "top" and ShirsInventoryDB.direction ~= "bottom" then
    ShirsInventoryDB.direction = "bottom"
  end
  if ShirsInventoryDB.sortMode ~= "itemType" and ShirsInventoryDB.sortMode ~= "rarity" then
    ShirsInventoryDB.sortMode = "itemType"
  end
  if type(ShirsInventoryDB.learnedReagents) ~= "table" then
    ShirsInventoryDB.learnedReagents = {}
  end
  if type(ShirsInventoryDB.itemOverrides) ~= "table" then
    ShirsInventoryDB.itemOverrides = {}
  end
  ShirsInventoryDB.hearthstoneItems = ShirsInventory_NormalizeHearthstoneItems(
    ShirsInventoryDB.hearthstoneItems
  )
  if type(ShirsInventoryDB.automaticHearthstoneItems) ~= "boolean" then
    ShirsInventoryDB.automaticHearthstoneItems = true
  end
  if type(ShirsInventoryDB.lockSelectedItemSlots) ~= "boolean" then
    ShirsInventoryDB.lockSelectedItemSlots = false
  end
  if type(ShirsInventoryDB.categoryMode) ~= "boolean" then
    ShirsInventoryDB.categoryMode = false
  end
  if type(ShirsInventoryDB.collapseEmptySlots) ~= "boolean" then
    ShirsInventoryDB.collapseEmptySlots = false
  end
  local categoryGapSlots = tonumber(ShirsInventoryDB.categoryGapSlots)
  if categoryGapSlots ~= 0 and categoryGapSlots ~= 1 then
    ShirsInventoryDB.categoryGapSlots = 1
  else
    ShirsInventoryDB.categoryGapSlots = categoryGapSlots
  end
  if type(ShirsInventoryDB.categoryAssignments) ~= "table" then
    ShirsInventoryDB.categoryAssignments = {}
  end
  local customCategories, highestCustomCategoryID = ShirsInventory_NormalizeCustomCategories(
    ShirsInventoryDB.customCategories
  )
  ShirsInventoryDB.customCategories = customCategories
  local nextCustomCategoryID = ShirsInventoryDB.nextCustomCategoryID
  local validNextCustomCategoryID = type(nextCustomCategoryID) == "number" and
    nextCustomCategoryID >= 1 and nextCustomCategoryID <= SHIRS_INVENTORY_MAX_CUSTOM_CATEGORY_ID
  if validNextCustomCategoryID then
    validNextCustomCategoryID = nextCustomCategoryID == math.floor(nextCustomCategoryID)
  end
  if not validNextCustomCategoryID or nextCustomCategoryID <= highestCustomCategoryID then
    nextCustomCategoryID = highestCustomCategoryID + 1
  end
  if nextCustomCategoryID > SHIRS_INVENTORY_MAX_CUSTOM_CATEGORY_ID then nextCustomCategoryID = 1 end
  ShirsInventoryDB.nextCustomCategoryID = nextCustomCategoryID
  if type(ShirsInventoryDB.junkItems) ~= "table" then
    ShirsInventoryDB.junkItems = {}
  end
  -- 0.3.26 and later ship only as the full suite. Drop obsolete per-character
  -- feature/provider choices so an old partial install cannot disable anything.
  ShirsInventoryDB.features = nil
  ShirsInventoryDB.setupComplete = nil
  ShirsInventoryDB.bagProviderChoice = nil
  ShirsInventoryDB.bagProviderSignature = nil
  if ShirsInventoryDB.professionLearning == nil then
    ShirsInventoryDB.professionLearning = true
  end
  if ShirsInventoryDB.useIconButtons == nil then
    ShirsInventoryDB.useIconButtons = false
  end
  if ShirsInventoryDB.showRarityBoxes == nil then
    ShirsInventoryDB.showRarityBoxes = true
  end
  if ShirsInventoryDB.showRecipeGlow == nil then
    ShirsInventoryDB.showRecipeGlow = true
  end
  local backgroundAlpha = tonumber(ShirsInventoryDB.backgroundAlpha)
  if not backgroundAlpha then
    backgroundAlpha = 0.96
  elseif backgroundAlpha ~= 0.96 then
    backgroundAlpha = math.floor(backgroundAlpha * 20 + 0.5) / 20
    backgroundAlpha = math.max(0.20, math.min(1, backgroundAlpha))
  end
  ShirsInventoryDB.backgroundAlpha = backgroundAlpha
  local frameStrata = ShirsInventoryDB.frameStrata
  if frameStrata ~= "LOW" and frameStrata ~= "MEDIUM" and frameStrata ~= "HIGH" and
    frameStrata ~= "DIALOG" and frameStrata ~= "TOOLTIP" then
    frameStrata = "HIGH"
  end
  ShirsInventoryDB.frameStrata = frameStrata
  if type(ShirsInventoryDB.categoryBankOnly) ~= "boolean" then
    ShirsInventoryDB.categoryBankOnly = false
  end
  if ShirsInventoryDB.useCoinIcons == nil then
    ShirsInventoryDB.useCoinIcons = true
  end
  if ShirsInventoryDB.hideItemOwnershipInCombat == nil then
    ShirsInventoryDB.hideItemOwnershipInCombat = false
  end
  if ShirsInventoryDB.autoClearSearch == nil then
    ShirsInventoryDB.autoClearSearch = true
  end
  if ShirsInventoryDB.questItemsOppositeEdge == nil then
    ShirsInventoryDB.questItemsOppositeEdge = true
  end
  local itemsPerRow = tonumber(ShirsInventoryDB.itemsPerRow)
  if not itemsPerRow then itemsPerRow = 10 end
  itemsPerRow = math.floor(itemsPerRow + 0.5)
  ShirsInventoryDB.itemsPerRow = math.max(10, math.min(20, itemsPerRow))
  local windowScale = tonumber(ShirsInventoryDB.windowScale)
  if not windowScale then windowScale = 1 end
  windowScale = math.floor(windowScale * 20 + 0.5) / 20
  ShirsInventoryDB.windowScale = math.max(0.65, math.min(1, windowScale))
  return ShirsInventoryDB
end

function ShirsInventory_IsFeatureSelectionComplete()
  ShirsInventory_EnsureDB()
  return true
end

function ShirsInventory_IsFeatureEnabled(feature)
  ShirsInventory_EnsureDB()
  return feature == "bagUI" or feature == "sorter" or feature == "junk"
end

function ShirsInventory_SaveFeatureSelection(bagUI, sorter, junk)
  ShirsInventory_EnsureDB()
  return bagUI and sorter and junk and true or false
end

function ShirsInventory_SetFullAddon()
  return ShirsInventory_SaveFeatureSelection(true, true, true)
end

function ShirsInventory_SetFeatureEnabled(feature, enabled)
  if feature ~= "bagUI" and feature ~= "sorter" and feature ~= "junk" then
    return false
  end
  ShirsInventory_EnsureDB()
  return enabled and true or false
end

function ShirsInventory_GetCategoryMode()
  return ShirsInventory_EnsureDB().categoryMode and true or false
end

function ShirsInventory_SetCategoryMode(enabled)
  ShirsInventory_EnsureDB().categoryMode = enabled and true or false
  return ShirsInventoryDB.categoryMode
end

function ShirsInventory_GetCollapseEmptySlots()
  return ShirsInventory_EnsureDB().collapseEmptySlots and true or false
end

function ShirsInventory_SetCollapseEmptySlots(enabled)
  ShirsInventory_EnsureDB().collapseEmptySlots = enabled and true or false
  if ShirsInventory_AccountSaveCurrentCategorySettings then
    ShirsInventory_AccountSaveCurrentCategorySettings()
  end
  return ShirsInventoryDB.collapseEmptySlots
end

function ShirsInventory_GetCategoryGapSlots()
  local value = ShirsInventory_EnsureDB().categoryGapSlots
  if value == 0 then return 0 end
  return 1
end

function ShirsInventory_SetCategoryGapSlots(value)
  value = tonumber(value)
  if value ~= 0 then value = 1 end
  ShirsInventory_EnsureDB().categoryGapSlots = value
  return value
end

local function ShirsInventory_IsValidCategorySettingsCoordinate(value)
  return type(value) == "number" and value >= -1000000 and value <= 1000000
end

function ShirsInventory_GetCategorySettingsPosition()
  local position = ShirsInventory_EnsureDB().categorySettingsPosition
  if type(position) ~= "table" or position.point ~= "TOPLEFT" or
    position.relativePoint ~= "BOTTOMLEFT" or
    not ShirsInventory_IsValidCategorySettingsCoordinate(position.x) or
    not ShirsInventory_IsValidCategorySettingsCoordinate(position.y) then
    ShirsInventoryDB.categorySettingsPosition = nil
    return nil
  end
  return position
end

function ShirsInventory_SaveCategorySettingsFrameCoordinates(point, relativePoint, x, y)
  if point ~= "TOPLEFT" or relativePoint ~= "BOTTOMLEFT" or
    not ShirsInventory_IsValidCategorySettingsCoordinate(x) or
    not ShirsInventory_IsValidCategorySettingsCoordinate(y) then
    return false
  end
  ShirsInventory_EnsureDB().categorySettingsPosition = {
    point = point,
    relativePoint = relativePoint,
    x = x,
    y = y,
  }
  return true
end

function ShirsInventory_SaveCategorySettingsFramePosition(frame)
  if not frame then return false end
  local left = type(frame.GetLeft) == "function" and frame:GetLeft() or nil
  local top = type(frame.GetTop) == "function" and frame:GetTop() or nil
  if type(left) == "number" and type(top) == "number" then
    return ShirsInventory_SaveCategorySettingsFrameCoordinates(
      "TOPLEFT", "BOTTOMLEFT", left, top
    )
  end
  if type(frame.GetPoint) ~= "function" then return false end
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  return ShirsInventory_SaveCategorySettingsFrameCoordinates(point, relativePoint, x, y)
end

local SHIRS_INVENTORY_ASSIGNABLE_CATEGORIES = {
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
  mining = true,
  herbs = true,
  cloth = true,
  leather = true,
  enchanting = true,
  elemental = true,
  engineering = true,
  gems = true,
  tradeGoods = true,
  junk = true,
  miscellaneous = true,
}

function ShirsInventory_GetCustomCategories()
  local source = ShirsInventory_EnsureDB().customCategories
  local copy = {}
  local index
  for index = 1, table.getn(source) do
    table.insert(copy, { key = source[index].key, label = source[index].label })
  end
  return copy
end

function ShirsInventory_GetCustomCategoryLabel(key)
  local categories = ShirsInventory_EnsureDB().customCategories
  local index
  for index = 1, table.getn(categories) do
    if categories[index].key == key then return categories[index].label end
  end
  return nil
end

function ShirsInventory_IsAssignableCategory(category)
  return SHIRS_INVENTORY_ASSIGNABLE_CATEGORIES[category] == true or
    ShirsInventory_GetCustomCategoryLabel(category) ~= nil
end

function ShirsInventory_ValidateCategorySettingsSnapshot(snapshot)
  if type(snapshot) ~= "table" or snapshot.version ~= 1 or
    type(snapshot.customCategories) ~= "table" or
    type(snapshot.categoryAssignments) ~= "table" or
    type(snapshot.collapseEmptySlots) ~= "boolean" then
    return nil
  end
  local categories, highestID = ShirsInventory_NormalizeCustomCategories(snapshot.customCategories)
  local allowed = {}
  local category
  for category in pairs(SHIRS_INVENTORY_ASSIGNABLE_CATEGORIES) do allowed[category] = true end
  local index
  for index = 1, table.getn(categories) do allowed[categories[index].key] = true end
  local assignments = {}
  local itemID, assignedCategory
  for itemID, assignedCategory in pairs(snapshot.categoryAssignments) do
    if type(itemID) == "number" and itemID >= 1 and itemID <= 2147483647 and
      itemID == math.floor(itemID) and allowed[assignedCategory] then
      assignments[itemID] = assignedCategory
    end
  end
  local nextID = highestID + 1
  if nextID > SHIRS_INVENTORY_MAX_CUSTOM_CATEGORY_ID then nextID = 1 end
  return {
    version = 1,
    customCategories = categories,
    nextCustomCategoryID = nextID,
    categoryAssignments = assignments,
    collapseEmptySlots = snapshot.collapseEmptySlots,
  }
end

function ShirsInventory_GetCategorySettingsSnapshot()
  local db = ShirsInventory_EnsureDB()
  return ShirsInventory_ValidateCategorySettingsSnapshot({
    version = 1,
    customCategories = db.customCategories,
    categoryAssignments = db.categoryAssignments,
    collapseEmptySlots = db.collapseEmptySlots,
  })
end

function ShirsInventory_ApplyCategorySettingsSnapshot(snapshot)
  local normalized = ShirsInventory_ValidateCategorySettingsSnapshot(snapshot)
  if not normalized then return false end
  local db = ShirsInventory_EnsureDB()
  db.customCategories = normalized.customCategories
  db.nextCustomCategoryID = normalized.nextCustomCategoryID
  db.categoryAssignments = normalized.categoryAssignments
  db.collapseEmptySlots = normalized.collapseEmptySlots
  return true
end

function ShirsInventory_CreateCustomCategory(value)
  local name = ShirsInventory_NormalizeCustomCategoryName(value)
  if not name then return false, "invalid" end
  local db = ShirsInventory_EnsureDB()
  if table.getn(db.customCategories) >= SHIRS_INVENTORY_MAX_CUSTOM_CATEGORIES then return false, "full" end
  local nameKey = string.lower(name)
  local index
  for index = 1, table.getn(db.customCategories) do
    if string.lower(db.customCategories[index].label) == nameKey then return false, "duplicate" end
  end
  local usedIDs = {}
  for index = 1, table.getn(db.customCategories) do
    local _, _, idText = string.find(db.customCategories[index].key, "^custom:(%d+)$")
    local usedID = tonumber(idText)
    if usedID then usedIDs[usedID] = true end
  end
  local id = db.nextCustomCategoryID
  local attempts = 0
  while usedIDs[id] and attempts <= SHIRS_INVENTORY_MAX_CUSTOM_CATEGORIES do
    id = id + 1
    if id > SHIRS_INVENTORY_MAX_CUSTOM_CATEGORY_ID then id = 1 end
    attempts = attempts + 1
  end
  if usedIDs[id] then return false, "full" end
  local key = "custom:" .. id
  db.nextCustomCategoryID = id + 1
  if db.nextCustomCategoryID > SHIRS_INVENTORY_MAX_CUSTOM_CATEGORY_ID then db.nextCustomCategoryID = 1 end
  table.insert(db.customCategories, { key = key, label = name })
  if ShirsInventory_AccountSaveCurrentCategorySettings then
    ShirsInventory_AccountSaveCurrentCategorySettings()
  end
  return key
end

function ShirsInventory_DeleteCustomCategory(key)
  local db = ShirsInventory_EnsureDB()
  local deleteIndex
  local index
  for index = 1, table.getn(db.customCategories) do
    if db.customCategories[index].key == key then deleteIndex = index break end
  end
  if not deleteIndex then return false end
  table.remove(db.customCategories, deleteIndex)
  for itemID, category in pairs(db.categoryAssignments) do
    if category == key then db.categoryAssignments[itemID] = nil end
  end
  if ShirsInventory_AccountSaveCurrentCategorySettings then
    ShirsInventory_AccountSaveCurrentCategorySettings()
  end
  return true
end

function ShirsInventory_GetCategoryAssignment(value)
  local itemID = ShirsInventory_ParseItemID and ShirsInventory_ParseItemID(value) or tonumber(value)
  if not itemID then return nil end
  local category = ShirsInventory_EnsureDB().categoryAssignments[itemID]
  if not ShirsInventory_IsAssignableCategory(category) then
    ShirsInventoryDB.categoryAssignments[itemID] = nil
    return nil
  end
  return category
end

function ShirsInventory_SetCategoryAssignment(value, category)
  local itemID = ShirsInventory_ParseItemID and ShirsInventory_ParseItemID(value) or tonumber(value)
  if not itemID or not ShirsInventory_IsAssignableCategory(category) then return false end
  ShirsInventory_EnsureDB().categoryAssignments[itemID] = category
  if ShirsInventory_AccountSaveCurrentCategorySettings then
    ShirsInventory_AccountSaveCurrentCategorySettings()
  end
  return category
end

function ShirsInventory_ClearCategoryAssignment(value)
  local itemID = ShirsInventory_ParseItemID and ShirsInventory_ParseItemID(value) or tonumber(value)
  if not itemID or not ShirsInventory_GetCategoryAssignment(itemID) then return false end
  ShirsInventoryDB.categoryAssignments[itemID] = nil
  if ShirsInventory_AccountSaveCurrentCategorySettings then
    ShirsInventory_AccountSaveCurrentCategorySettings()
  end
  return true
end

function ShirsInventory_GetAutoSellJunk()
  return ShirsInventory_EnsureDB().autoSellJunk and true or false
end

function ShirsInventory_ShouldShowMerchantSellButton()
  return MerchantFrame and type(MerchantFrame.IsShown) == "function" and
    MerchantFrame:IsShown() and MerchantFrame.selectedTab ~= 2
end

function ShirsInventory_SetAutoSellJunk(enabled)
  ShirsInventory_EnsureDB().autoSellJunk = enabled and true or false
  return true
end

local ShirsInventory_KnownBagAddons = {
  adibags = true,
  arkinventory = true,
  bagnon = true,
  bagnon_core = true,
  bagshui = true,
  baudbag = true,
  cleanup = true,
  combuctor = true,
  engbags = true,
  mybags = true,
  onebag = true,
  onebag3 = true,
  pfui = true,
  ["pfui-master"] = true,
  shagubags = true,
  tbag = true,
  vbagnon = true,
}

function ShirsInventory_IsBagAddonProviderName(name)
  return type(name) == "string" and ShirsInventory_KnownBagAddons[string.lower(name)] == true
end

function ShirsInventory_DetectBagAddons(addons)
  local result, seen = {}, {}
  local _, addon
  for _, addon in ipairs(addons or {}) do
    local name = addon and addon.name
    local key = type(name) == "string" and string.lower(name) or nil
    if addon and addon.loaded and key and ShirsInventory_IsBagAddonProviderName(name) and not seen[key] then
      seen[key] = true
      table.insert(result, { name = name, title = addon.title or name })
    end
  end
  table.sort(result, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
  return result
end

function ShirsInventory_GetBagAddonSignature(addons)
  local names = {}
  local _, addon
  for _, addon in ipairs(addons or {}) do
    if addon and type(addon.name) == "string" then table.insert(names, string.lower(addon.name)) end
  end
  table.sort(names)
  return table.concat(names, "|")
end

function ShirsInventory_GetBagProviderChoice(signature)
  ShirsInventory_EnsureDB()
  return "shirs"
end

function ShirsInventory_SaveBagProviderChoice(choice, signature)
  ShirsInventory_EnsureDB()
  return choice == "shirs"
end

local function ShirsInventory_NormalizeMaterialCategory(category)
  if type(category) ~= "string" then return nil end
  return materialCategoryAliases[string.lower(category)]
end

function ShirsInventory_ParseItemID(value)
  if type(value) == "number" then
    if value > 0 then return math.floor(value) end
    return nil
  end
  if type(value) ~= "string" then return nil end
  local _, _, linkedID = string.find(value, "item:(%d+)")
  local itemID = tonumber(linkedID or string.gsub(value, "%s", ""))
  if itemID and itemID > 0 then return math.floor(itemID) end
  return nil
end

ShirsInventory_RecipeNamePrefixes = {
  "recipe:",
  "pattern:",
  "formula:",
  "plans:",
  "schematic:",
  "manual:",
}

function ShirsInventory_NormalizeCraftName(name)
  if type(name) ~= "string" then return nil end
  local trimmed = string.gsub(name, "^%s+", "")
  trimmed = string.gsub(trimmed, "%s+$", "")
  if trimmed == "" then return nil end
  return string.lower(trimmed)
end

function ShirsInventory_RecipeItemCraftName(itemName)
  local normalized = ShirsInventory_NormalizeCraftName(itemName)
  if not normalized then return nil end
  local prefixes = ShirsInventory_RecipeNamePrefixes
  local index
  for index = 1, table.getn(prefixes) do
    local prefix = prefixes[index]
    if string.sub(normalized, 1, string.len(prefix)) == prefix then
      local remainder = string.sub(normalized, string.len(prefix) + 1)
      remainder = string.gsub(remainder, "^%s+", "")
      if remainder == "" then return nil end
      return remainder
    end
  end
  return nil
end

function ShirsInventory_GetAutomaticHearthstoneItems()
  return ShirsInventory_EnsureDB().automaticHearthstoneItems and true or false
end

function ShirsInventory_SetAutomaticHearthstoneItems(enabled)
  ShirsInventory_EnsureDB().automaticHearthstoneItems = enabled and true or false
  return ShirsInventory_GetAutomaticHearthstoneItems()
end

function ShirsInventory_GetLockSelectedItemSlots()
  return ShirsInventory_EnsureDB().lockSelectedItemSlots and true or false
end

function ShirsInventory_SetLockSelectedItemSlots(enabled)
  ShirsInventory_EnsureDB().lockSelectedItemSlots = enabled and true or false
  return ShirsInventory_GetLockSelectedItemSlots()
end

function ShirsInventory_IsSelectedItemSlotLocked(itemID, container)
  if not ShirsInventory_GetLockSelectedItemSlots() then return false end
  if type(container) ~= "number" or container < 0 or container > 4 then return false end
  return ShirsInventory_GetHearthstoneItemIndex(itemID) ~= nil
end

function ShirsInventory_GetHearthstoneItems()
  local source = ShirsInventory_EnsureDB().hearthstoneItems
  local copy = {}
  local index
  for index = 1, table.getn(source) do copy[index] = source[index] end
  return copy
end

function ShirsInventory_GetHearthstoneItemIndex(value)
  local itemID = ShirsInventory_ParseItemID(value)
  if not itemID then return nil end
  local values = ShirsInventory_EnsureDB().hearthstoneItems
  local index
  for index = 1, table.getn(values) do
    if values[index] == itemID then return index end
  end
  return nil
end

function ShirsInventory_GetHearthstoneItemCount()
  return table.getn(ShirsInventory_EnsureDB().hearthstoneItems)
end

function ShirsInventory_SetHearthstoneItem(value, selected)
  local itemID = ShirsInventory_ParseItemID(value)
  if not itemID then return false, "invalid", nil end
  if itemID == 6948 then return false, "fixed", itemID end
  local values = ShirsInventory_EnsureDB().hearthstoneItems
  local index
  local candidateIndex
  for candidateIndex = 1, table.getn(values) do
    if values[candidateIndex] == itemID then
      index = candidateIndex
      break
    end
  end
  if selected then
    if index then return true, "present", itemID end
    if table.getn(values) >= SHIRS_INVENTORY_MAX_HEARTHSTONE_ITEMS then
      return false, "full", itemID
    end
    table.insert(values, itemID)
    return true, "added", itemID
  end
  if not index then return true, "absent", itemID end
  table.remove(values, index)
  return true, "removed", itemID
end

function ShirsInventory_ToggleHearthstoneItem(value)
  return ShirsInventory_SetHearthstoneItem(
    value, ShirsInventory_GetHearthstoneItemIndex(value) == nil
  )
end

function ShirsInventory_MoveHearthstoneItemToEdge(value, edge)
  local itemID = ShirsInventory_ParseItemID(value)
  local index = ShirsInventory_GetHearthstoneItemIndex(itemID)
  if not itemID or not index or (edge ~= "top" and edge ~= "bottom") then
    return false, index
  end
  local values = ShirsInventory_EnsureDB().hearthstoneItems
  local destination = edge == "top" and 1 or table.getn(values)
  if destination == index then return true, index end
  table.remove(values, index)
  table.insert(values, destination, itemID)
  return true, destination
end

function ShirsInventory_MoveHearthstoneItem(value, offset)
  local itemID = ShirsInventory_ParseItemID(value)
  local index = ShirsInventory_GetHearthstoneItemIndex(itemID)
  offset = tonumber(offset)
  if not itemID or not index or not offset then return false, index end
  if offset < 0 then offset = -1 elseif offset > 0 then offset = 1 else return true, index end
  local values = ShirsInventory_EnsureDB().hearthstoneItems
  local destination = math.max(1, math.min(table.getn(values), index + offset))
  if destination == index then return true, index end
  table.remove(values, index)
  table.insert(values, destination, itemID)
  return true, destination
end

function ShirsInventory_MoveHearthstoneItemToItem(value, targetValue)
  local itemID = ShirsInventory_ParseItemID(value)
  local targetID = ShirsInventory_ParseItemID(targetValue)
  local index = ShirsInventory_GetHearthstoneItemIndex(itemID)
  local targetIndex = ShirsInventory_GetHearthstoneItemIndex(targetID)
  if not itemID or not targetID or not index or not targetIndex then return false, index end
  if index == targetIndex then return true, index end
  local values = ShirsInventory_EnsureDB().hearthstoneItems
  table.remove(values, index)
  table.insert(values, targetIndex, itemID)
  return true, targetIndex
end

function ShirsInventory_ClearHearthstoneItems()
  local db = ShirsInventory_EnsureDB()
  local removed = table.getn(db.hearthstoneItems)
  db.hearthstoneItems = {}
  return removed
end

local function ShirsInventory_GetProfessionCategory(professionName)
  if type(professionName) ~= "string" then return nil end
  local lowered = string.lower(professionName)
  local profession, category
  for profession, category in pairs(professionCategories) do
    if string.find(lowered, profession, 1, true) then return category end
  end
  return nil
end

function ShirsInventory_LearnProfessionReagents(eventName)
  if not ShirsInventory_GetProfessionLearning() then return 0 end

  local getSkillLine, getNumSkills, getSkillInfo, getNumReagents, getReagentLink
  if eventName == "CRAFT_SHOW" or eventName == "CRAFT_UPDATE" then
    getSkillLine = GetCraftDisplaySkillLine
    getNumSkills = GetNumCrafts
    getSkillInfo = function(index)
      local name, _, craftType = GetCraftInfo(index)
      return name, craftType
    end
    getNumReagents = GetCraftNumReagents
    getReagentLink = GetCraftReagentItemLink
  else
    getSkillLine = GetTradeSkillLine
    getNumSkills = GetNumTradeSkills
    getSkillInfo = GetTradeSkillInfo
    getNumReagents = GetTradeSkillNumReagents
    getReagentLink = GetTradeSkillReagentItemLink
  end

  if type(getSkillLine) ~= "function" or type(getNumSkills) ~= "function" or
    type(getSkillInfo) ~= "function" or type(getNumReagents) ~= "function" or
    type(getReagentLink) ~= "function" then
    return 0
  end

  local category = ShirsInventory_GetProfessionCategory(getSkillLine())
  if not category then return 0 end

  local learnedReagents = ShirsInventory_EnsureDB().learnedReagents
  local added = 0
  local skillIndex, reagentIndex
  local skillCount = tonumber(getNumSkills()) or 0
  for skillIndex = 1, skillCount do
    local skillName, skillType = getSkillInfo(skillIndex)
    if skillName and skillType ~= "header" then
      local reagentCount = tonumber(getNumReagents(skillIndex)) or 0
      for reagentIndex = 1, reagentCount do
        local itemID = ShirsInventory_ParseItemID(getReagentLink(skillIndex, reagentIndex))
        if itemID then
          if type(learnedReagents[itemID]) ~= "table" then learnedReagents[itemID] = {} end
          if not learnedReagents[itemID][category] then
            learnedReagents[itemID][category] = true
            added = added + 1
          end
        end
      end
    end
  end

  if added > 0 and type(ShirsInventory_UpdateUI) == "function" then ShirsInventory_UpdateUI() end
  return added
end

function ShirsInventory_LearnProfessionCrafts(eventName)
  if not ShirsInventory_GetProfessionLearning() then return 0 end
  if type(ShirsInventory_AccountRememberKnownCraft) ~= "function" then return 0 end

  local getSkillLine, getNumSkills, getSkillInfo
  if eventName == "CRAFT_SHOW" or eventName == "CRAFT_UPDATE" then
    getSkillLine = GetCraftDisplaySkillLine
    getNumSkills = GetNumCrafts
    getSkillInfo = function(index)
      local name, _, craftType = GetCraftInfo(index)
      return name, craftType
    end
  else
    getSkillLine = GetTradeSkillLine
    getNumSkills = GetNumTradeSkills
    getSkillInfo = GetTradeSkillInfo
  end

  if type(getSkillLine) ~= "function" or type(getNumSkills) ~= "function" or
    type(getSkillInfo) ~= "function" then
    return 0
  end
  if not ShirsInventory_GetProfessionCategory(getSkillLine()) then return 0 end

  local added = 0
  local skillIndex
  local skillCount = tonumber(getNumSkills()) or 0
  for skillIndex = 1, skillCount do
    local skillName, skillType = getSkillInfo(skillIndex)
    if skillName and skillType ~= "header" then
      if ShirsInventory_AccountRememberKnownCraft(skillName) then
        added = added + 1
      end
    end
  end
  if added > 0 and type(ShirsInventory_UpdateUI) == "function" then ShirsInventory_UpdateUI() end
  return added
end

if CreateFrame then
  local professionLearner = CreateFrame("Frame", "ShirsInventoryProfessionLearner", UIParent)
  if professionLearner and professionLearner.RegisterEvent then
    professionLearner:RegisterEvent("TRADE_SKILL_SHOW")
    professionLearner:RegisterEvent("CRAFT_SHOW")
    professionLearner:RegisterEvent("TRADE_SKILL_UPDATE")
    professionLearner:RegisterEvent("CRAFT_UPDATE")
    professionLearner:Hide()
    local pendingEvent, elapsed = nil, 0
    professionLearner:SetScript("OnEvent", function()
      pendingEvent = event
      elapsed = 0
      professionLearner:Show()
    end)
    professionLearner:SetScript("OnUpdate", function()
      elapsed = elapsed + arg1
      if elapsed >= 0.75 then
        professionLearner:Hide()
        local scanEvent = pendingEvent
        pendingEvent = nil
        if scanEvent then
          ShirsInventory_LearnProfessionReagents(scanEvent)
          ShirsInventory_LearnProfessionCrafts(scanEvent)
        end
      end
    end)
  end
end

function ShirsInventory_SetItemOverride(itemID, category)
  itemID = ShirsInventory_ParseItemID(itemID)
  category = ShirsInventory_NormalizeMaterialCategory(category)
  if not itemID or not category then return false end
  ShirsInventory_EnsureDB().itemOverrides[itemID] = category
  return true
end

function ShirsInventory_ClearItemOverride(itemID)
  itemID = ShirsInventory_ParseItemID(itemID)
  if not itemID then return false end
  local overrides = ShirsInventory_EnsureDB().itemOverrides
  if overrides[itemID] == nil then return false end
  overrides[itemID] = nil
  return true
end

local function ShirsInventory_CountKeys(values)
  local count = 0
  local _
  for _ in pairs(values) do count = count + 1 end
  return count
end

function ShirsInventory_GetItemOverrideCount()
  return ShirsInventory_CountKeys(ShirsInventory_EnsureDB().itemOverrides)
end

function ShirsInventory_GetLearnedReagentCount()
  return ShirsInventory_CountKeys(ShirsInventory_EnsureDB().learnedReagents)
end

function ShirsInventory_GetProfessionLearning()
  return ShirsInventory_EnsureDB().professionLearning and true or false
end

function ShirsInventory_SetProfessionLearning(enabled)
  ShirsInventory_EnsureDB().professionLearning = enabled and true or false
  return ShirsInventory_GetProfessionLearning()
end

function ShirsInventory_ResetLearnedReagents()
  local db = ShirsInventory_EnsureDB()
  local removed = ShirsInventory_CountKeys(db.learnedReagents)
  db.learnedReagents = {}
  return removed
end

local subTypeCategories = {
  ["Metal & Stone"] = "Mining",
  ["Herb"] = "Herbs",
  ["Cloth"] = "Cloth",
  ["Leather"] = "Leather",
  ["Enchanting"] = "Enchanting",
  ["Elemental"] = "Elemental",
  ["Parts"] = "Engineering",
  ["Devices"] = "Engineering",
  ["Explosives"] = "Engineering",
  ["Gem"] = "Gems",
  ["Gems"] = "Gems",
}

local enchantingDustFamilies = {
  Strange = true,
  Soul = true,
  Vision = true,
  Dream = true,
  Illusion = true,
}

local enchantingEssenceFamilies = {
  Magic = true,
  Astral = true,
  Mystic = true,
  Nether = true,
  Eternal = true,
}

local enchantingShardFamilies = {
  Glimmering = true,
  Glowing = true,
  Radiant = true,
  Brilliant = true,
}

local generalEnchantingMaterialIDs = {
  [10940] = true, [11083] = true, [11137] = true, [11176] = true, [16204] = true,
  [10938] = true, [10939] = true, [10998] = true, [11082] = true,
  [11134] = true, [11135] = true, [11174] = true, [11175] = true,
  [16202] = true, [16203] = true,
  [10978] = true, [11084] = true, [11138] = true, [11139] = true,
  [11177] = true, [11178] = true, [14343] = true, [14344] = true,
}

local masteryAndRaidTokenIDs = {
  [26039] = true,
  [26040] = true,
  [26041] = true,
  [26042] = true,
  [26043] = true,
}

function ShirsInventory_IsGeneralEnchantingMaterial(itemName)
  if type(itemName) ~= "string" then return false end

  local _, _, dustFamily = string.find(itemName, "^(%a+) Dust$")
  if dustFamily and enchantingDustFamilies[dustFamily] then return true end

  local _, _, essenceSize, essenceFamily = string.find(itemName, "^(%a+) (%a+) Essence$")
  if (essenceSize == "Lesser" or essenceSize == "Greater") and
    essenceFamily and enchantingEssenceFamilies[essenceFamily] then
    return true
  end

  local _, _, shardSize, shardFamily = string.find(itemName, "^(%a+) (%a+) Shard$")
  if (shardSize == "Small" or shardSize == "Large") and
    shardFamily and enchantingShardFamilies[shardFamily] then
    return true
  end

  return false
end

function ShirsInventory_GetSortMaterialCategory(mode, itemID, itemName, materialCategory)
  if mode == "itemType" and generalEnchantingMaterialIDs[tonumber(itemID)] then
    return "Enchanting Materials"
  end
  if mode == "itemType" and masteryAndRaidTokenIDs[tonumber(itemID)] then
    return "Raid Tokens"
  end
  return materialCategory
end

function ShirsInventory_GetSortConsumable(mode, materialCategory, isConsumable)
  if mode == "itemType" and
    (materialCategory == "Enchanting Materials" or materialCategory == "Raid Tokens") then
    return false
  end
  return isConsumable and true or false
end

function ShirsInventory_GetMaterialCategory(itemID, itemType, itemSubType)
  local db = ShirsInventory_EnsureDB()
  local override = db.itemOverrides[itemID]
  if override then
    if override == "General" then return nil end
    return override
  end

  local learned = db.learnedReagents[itemID]
  if type(learned) == "string" then
    return learned
  elseif type(learned) == "table" then
    local learnedCategory, learnedRank
    local candidate
    for candidate in pairs(learned) do
      local rank = ShirsInventory_MaterialRanks[candidate]
      if rank and (not learnedRank or rank < learnedRank) then
        learnedCategory, learnedRank = candidate, rank
      end
    end
    if learnedCategory then return learnedCategory end
  end

  if itemType == "Trade Goods" then
    return subTypeCategories[itemSubType]
  end

  return nil
end

function ShirsInventory_GetSortMode()
  return ShirsInventory_EnsureDB().sortMode
end

function ShirsInventory_SetSortMode(mode)
  if mode ~= "itemType" and mode ~= "rarity" then
    return false
  end
  ShirsInventory_EnsureDB().sortMode = mode
  return true
end

function ShirsInventory_ToggleSortMode()
  local mode = ShirsInventory_GetSortMode()
  if mode == "itemType" then mode = "rarity" else mode = "itemType" end
  ShirsInventory_SetSortMode(mode)
  return mode
end

function ShirsInventory_GetIgnoreJunkSorting()
  return ShirsInventory_EnsureDB().ignoreJunkSorting and true or false
end

function ShirsInventory_SetIgnoreJunkSorting(enabled)
  ShirsInventory_EnsureDB().ignoreJunkSorting = enabled and true or false
  return true
end

function ShirsInventory_GetQuestItemsOppositeEdge()
  return ShirsInventory_EnsureDB().questItemsOppositeEdge and true or false
end

function ShirsInventory_SetQuestItemsOppositeEdge(enabled)
  ShirsInventory_EnsureDB().questItemsOppositeEdge = enabled and true or false
  return ShirsInventory_GetQuestItemsOppositeEdge()
end

function ShirsInventory_GetSortDelay()
  return 0.29
end

function ShirsInventory_GetSortAcknowledgementDelay()
  -- Poll quickly when the last move is not yet visible through the bag APIs.
  return 0.01
end

function ShirsInventory_GetSortMovesPerUpdate()
  -- Hard ceiling for pairwise-disjoint cursor transactions in one callback.
  return 4
end

function ShirsInventory_GetSortBurstLimit(burstNumber)
  burstNumber = math.floor(tonumber(burstNumber) or 1)
  if burstNumber < 1 then burstNumber = 1 end
  if math.mod(burstNumber, 4) == 0 then return 3 end
  return ShirsInventory_GetSortMovesPerUpdate()
end

function ShirsInventory_GetSortTimeout()
  return 15
end

function ShirsInventory_GetInventoryFramePosition()
  local position = ShirsInventory_EnsureDB().inventoryPosition
  if type(position) ~= "table" then return nil end
  return position
end

function ShirsInventory_SaveInventoryFrameCoordinates(point, relativePoint, x, y)
  if type(point) ~= "string" or type(relativePoint) ~= "string" or
    type(x) ~= "number" or type(y) ~= "number" then
    return false
  end
  ShirsInventory_EnsureDB().inventoryPosition = {
    point = point,
    relativePoint = relativePoint,
    x = x,
    y = y,
  }
  return true
end

function ShirsInventory_SaveInventoryFramePosition(frame)
  if not frame then return false end
  local point, relativePoint, x, y
  if type(frame.GetLeft) == "function" and type(frame.GetTop) == "function" then
    x, y = frame:GetLeft(), frame:GetTop()
    if type(x) == "number" and type(y) == "number" then
      point = "TOPLEFT"
      relativePoint = "BOTTOMLEFT"
    end
  end
  if not point and type(frame.GetPoint) == "function" then
    point, _, relativePoint, x, y = frame:GetPoint(1)
  end
  return ShirsInventory_SaveInventoryFrameCoordinates(point, relativePoint, x, y)
end

function ShirsInventory_ResetInventoryFramePosition()
  ShirsInventory_EnsureDB().inventoryPosition = nil
  return true
end

function ShirsInventory_GetBankFramePosition()
  local position = ShirsInventory_EnsureDB().bankPosition
  if type(position) ~= "table" then return nil end
  return position
end

function ShirsInventory_SaveBankFrameCoordinates(left, bottom)
  if type(left) ~= "number" or type(bottom) ~= "number" then return false end
  ShirsInventory_EnsureDB().bankPosition = {
    point = "BOTTOMLEFT",
    relativePoint = "BOTTOMLEFT",
    x = left,
    y = bottom,
  }
  return true
end

function ShirsInventory_SaveBankFramePosition(frame)
  if not frame or type(frame.GetLeft) ~= "function" or type(frame.GetBottom) ~= "function" then
    return false
  end
  local left, bottom = frame:GetLeft(), frame:GetBottom()
  return ShirsInventory_SaveBankFrameCoordinates(left, bottom)
end

function ShirsInventory_ResetBankFramePosition()
  ShirsInventory_EnsureDB().bankPosition = nil
  return true
end

function ShirsInventory_BuildGeneralSortKey(mode, quality, categoryRank, typeKey, subTypeKey, invTypeKey, itemID, direction, materialCategory)
  local rarityOrder = -quality
  if mode == "rarity" and direction == "bottom" then rarityOrder = quality end
  if mode == "itemType" and
    (materialCategory == "Enchanting Materials" or materialCategory == "Raid Tokens") then
    typeKey = 0
    subTypeKey = 0
    invTypeKey = 0
  end
  return {
    mode = mode,
    category = categoryRank,
    rarity = rarityOrder,
    itemType = typeKey,
    itemSubType = subTypeKey,
    inventoryType = invTypeKey,
    itemID = itemID,
  }
end

function ShirsInventory_GetOppositeEdgeRank(isQuest, isConjured, groupQuestItems)
  if isQuest and groupQuestItems then return 1 end
  if isConjured then return 2 end
  return nil
end

function ShirsInventory_GetPrimaryCategoryRank(fixedRank, quality, isSoulShard, isConjured, isReagent, isQuest, materialCategory, soulbound, isConsumable)
  -- Binding status is intentionally not a primary category. It remains part of
  -- the stack identity so bound and unbound instances cannot merge incorrectly.
  if fixedRank then
    return fixedRank
  elseif isSoulShard then
    return 21
  elseif isConjured then
    return 22
  elseif isReagent then
    return 7
  elseif isQuest then
    return 9
  elseif isConsumable then
    return 8
  elseif materialCategory then
    return 10 + ShirsInventory_MaterialRanks[materialCategory]
  elseif quality > 1 then
    return 10
  elseif quality == 1 then
    return 19
  elseif quality == 0 then
    return 20
  end
  return 30
end

function ShirsInventory_SelectDenseSlotIndexes(slotCount, itemCount, direction)
  local selected = {}
  local first = 1
  if direction == "bottom" then first = slotCount - itemCount + 1 end
  if first < 1 then first = 1 end
  local index
  for index = first, math.min(slotCount, first + itemCount - 1) do
    table.insert(selected, index)
  end
  return selected
end

function ShirsInventory_GetDirection()
  return ShirsInventory_EnsureDB().direction
end

function ShirsInventory_SetDirection(direction)
  if direction ~= "top" and direction ~= "bottom" then
    return false
  end
  ShirsInventory_EnsureDB().direction = direction
  return true
end

function ShirsInventory_ToggleDirection()
  local direction = ShirsInventory_GetDirection()
  if direction == "top" then
    direction = "bottom"
  else
    direction = "top"
  end
  ShirsInventory_SetDirection(direction)
  return direction
end

function ShirsInventory_GetUseIconButtons()
  return ShirsInventory_EnsureDB().useIconButtons and true or false
end

function ShirsInventory_SetUseIconButtons(enabled)
  ShirsInventory_EnsureDB().useIconButtons = enabled and true or false
  return ShirsInventory_GetUseIconButtons()
end

function ShirsInventory_ToggleUseIconButtons()
  local enabled = not ShirsInventory_GetUseIconButtons()
  ShirsInventory_SetUseIconButtons(enabled)
  return enabled
end

function ShirsInventory_GetShowRarityBoxes()
  return ShirsInventory_EnsureDB().showRarityBoxes and true or false
end

function ShirsInventory_SetShowRarityBoxes(enabled)
  ShirsInventory_EnsureDB().showRarityBoxes = enabled and true or false
  return ShirsInventory_GetShowRarityBoxes()
end

function ShirsInventory_ToggleShowRarityBoxes()
  local enabled = not ShirsInventory_GetShowRarityBoxes()
  ShirsInventory_SetShowRarityBoxes(enabled)
  return enabled
end

function ShirsInventory_GetShowRecipeGlow()
  return ShirsInventory_EnsureDB().showRecipeGlow and true or false
end

function ShirsInventory_SetShowRecipeGlow(enabled)
  ShirsInventory_EnsureDB().showRecipeGlow = enabled and true or false
  return ShirsInventory_GetShowRecipeGlow()
end

function ShirsInventory_GetBackgroundAlpha()
  return ShirsInventory_EnsureDB().backgroundAlpha
end

function ShirsInventory_SetBackgroundAlpha(value)
  value = tonumber(value)
  if not value then
    ShirsInventory_EnsureDB().backgroundAlpha = 0.96
    return 0.96
  end
  value = math.floor(value * 20 + 0.5) / 20
  value = math.max(0.20, math.min(1, value))
  ShirsInventory_EnsureDB().backgroundAlpha = value
  return value
end

function ShirsInventory_GetFrameStrata()
  return ShirsInventory_EnsureDB().frameStrata
end

function ShirsInventory_SetFrameStrata(value)
  if value ~= "LOW" and value ~= "MEDIUM" and value ~= "HIGH" and value ~= "DIALOG" and value ~= "TOOLTIP" then
    value = "HIGH"
  end
  ShirsInventory_EnsureDB().frameStrata = value
  return value
end

function ShirsInventory_GetCategoryBankOnly()
  return ShirsInventory_EnsureDB().categoryBankOnly and true or false
end

function ShirsInventory_SetCategoryBankOnly(enabled)
  ShirsInventory_EnsureDB().categoryBankOnly = enabled and true or false
  return ShirsInventory_GetCategoryBankOnly()
end

function ShirsInventory_IsCategoryViewEnabled(isBank)
  if not ShirsInventory_GetCategoryMode() then return false end
  return not ShirsInventory_GetCategoryBankOnly() or isBank and true or false
end

function ShirsInventory_GetUseCoinIcons()
  return ShirsInventory_EnsureDB().useCoinIcons and true or false
end

function ShirsInventory_SetUseCoinIcons(enabled)
  ShirsInventory_EnsureDB().useCoinIcons = enabled and true or false
  return ShirsInventory_GetUseCoinIcons()
end

function ShirsInventory_ToggleUseCoinIcons()
  local enabled = not ShirsInventory_GetUseCoinIcons()
  ShirsInventory_SetUseCoinIcons(enabled)
  return enabled
end

function ShirsInventory_GetHideItemOwnershipInCombat()
  return ShirsInventory_EnsureDB().hideItemOwnershipInCombat and true or false
end

function ShirsInventory_SetHideItemOwnershipInCombat(enabled)
  ShirsInventory_EnsureDB().hideItemOwnershipInCombat = enabled and true or false
  return ShirsInventory_GetHideItemOwnershipInCombat()
end

function ShirsInventory_GetAutoClearSearch()
  return ShirsInventory_EnsureDB().autoClearSearch and true or false
end

function ShirsInventory_SetAutoClearSearch(enabled)
  ShirsInventory_EnsureDB().autoClearSearch = enabled and true or false
  return ShirsInventory_GetAutoClearSearch()
end

function ShirsInventory_GetItemsPerRow()
  return ShirsInventory_EnsureDB().itemsPerRow
end

function ShirsInventory_SetItemsPerRow(value)
  value = tonumber(value) or 10
  value = math.floor(value + 0.5)
  value = math.max(10, math.min(20, value))
  ShirsInventory_EnsureDB().itemsPerRow = value
  return value
end

function ShirsInventory_GetWindowScale()
  return ShirsInventory_EnsureDB().windowScale
end

function ShirsInventory_SetWindowScale(value)
  value = tonumber(value) or 1
  value = math.floor(value * 20 + 0.5) / 20
  value = math.max(0.65, math.min(1, value))
  ShirsInventory_EnsureDB().windowScale = value
  return value
end

function ShirsInventory_MoveCursorItem(srcContainer, srcSlot, dstContainer, dstSlot)
  if CursorHasItem() then
    return false
  end

  PickupContainerItem(srcContainer, srcSlot)
  if not CursorHasItem() then
    return false
  end

  PickupContainerItem(dstContainer, dstSlot)
  if CursorHasItem() then
    PickupContainerItem(srcContainer, srcSlot)
  end

  if CursorHasItem() then
    ClearCursor()
    return false
  end

  return true
end

function ShirsInventory_GetKeyRingContainerID()
  return KEYRING_CONTAINER or -2
end

function ShirsInventory_GetKeyRingSize()
  if type(GetKeyRingSize) == "function" then
    return tonumber(GetKeyRingSize()) or 0
  end
  return 0
end

function ShirsInventory_GetKeyRingSlotsShown()
  return ShirsInventory_EnsureDB().keyringSlotsShown ~= false
end

function ShirsInventory_ToggleKeyRingSlots()
  local db = ShirsInventory_EnsureDB()
  db.keyringSlotsShown = not ShirsInventory_GetKeyRingSlotsShown()
  return db.keyringSlotsShown
end

function ShirsInventory_ShouldCountFreeInventorySlot(container)
  return container ~= ShirsInventory_GetKeyRingContainerID()
end

function ShirsInventory_GetInventorySlotCounts()
  local counts = {}
  local bag
  for bag = 0, 4 do
    counts[bag] = GetContainerNumSlots and (GetContainerNumSlots(bag) or 0) or 0
  end
  counts[ShirsInventory_GetKeyRingContainerID()] = ShirsInventory_GetKeyRingSize()
  return counts
end

function ShirsInventory_CountFreeInventorySlots(slotStates)
  local free = 0
  local index
  for index = 1, table.getn(slotStates or {}) do
    local state = slotStates[index]
    if state and not state.hasItem and ShirsInventory_ShouldCountFreeInventorySlot(state.bag) then
      free = free + 1
    end
  end
  return free
end

function ShirsInventory_BuildInventorySlots(slotCounts)
  local result = {}
  for bag = 0, 4 do
    local count = slotCounts[bag] or 0
    for slot = 1, count do
      table.insert(result, { bag = bag, slot = slot })
    end
  end
  local keyring = ShirsInventory_GetKeyRingContainerID()
  local keyringCount = ShirsInventory_GetKeyRingSlotsShown() and (slotCounts[keyring] or 0) or 0
  for slot = 1, keyringCount do
    table.insert(result, { bag = keyring, slot = slot })
  end
  return result
end

function ShirsInventory_GetBankBagSlotLimit()
  return tonumber(NUM_BANKBAGSLOTS) or 6
end

function ShirsInventory_GetBankContainerIDs()
  local containers = {BANK_CONTAINER or -1}
  local bag
  for bag = 5, 4 + ShirsInventory_GetBankBagSlotLimit() do
    table.insert(containers, bag)
  end
  return containers
end

function ShirsInventory_BuildBankSlots(slotCounts)
  local result = {}
  local containers = ShirsInventory_GetBankContainerIDs()
  local containerIndex
  for containerIndex = 1, table.getn(containers) do
    local bag = containers[containerIndex]
    local count = slotCounts[bag] or 0
    local slot
    for slot = 1, count do
      table.insert(result, { bag = bag, slot = slot })
    end
  end
  return result
end

function ShirsInventory_GetBankFrameLayout()
  return {
    maximumColumns = ShirsInventory_GetItemsPerRow(),
    itemSize = 36,
    itemStep = 40,
    gridTopOffset = -64,
    footerHeight = 14,
    bankBagButtonSize = 26,
    bankBagButtonGap = 0,
    bankBagIconInset = 0,
    bankBagLayeredBorder = false,
    bankBagAnchorPoint = "TOPLEFT",
    bankBagTopOffset = -32,
  }
end

function ShirsInventory_GetBankFrameAnchor()
  return {
    point = "BOTTOMLEFT",
    relativePoint = "BOTTOMLEFT",
    x = 20,
    y = 20,
  }
end

function ShirsInventory_BuildBankBagBarModel(purchasedSlots, maximumSlots, textures, slotCounts)
  local entries = {}
  maximumSlots = tonumber(maximumSlots) or ShirsInventory_GetBankBagSlotLimit()
  purchasedSlots = math.max(0, math.min(tonumber(purchasedSlots) or 0, maximumSlots))
  textures = textures or {}
  slotCounts = slotCounts or {}
  local nextCombinedIndex = (slotCounts[BANK_CONTAINER or -1] or 0) + 1
  local index
  for index = 1, purchasedSlots do
    local bag = index + 4
    local slots = slotCounts[bag] or 0
    table.insert(entries, {
      inventoryIndex = index,
      bag = bag,
      texture = textures[index],
      purchase = false,
      slots = slots,
      firstCombinedIndex = slots > 0 and nextCombinedIndex or nil,
      lastCombinedIndex = slots > 0 and (nextCombinedIndex + slots - 1) or nil,
    })
    nextCombinedIndex = nextCombinedIndex + slots
  end
  if purchasedSlots < maximumSlots then
    table.insert(entries, {
      inventoryIndex = purchasedSlots + 1,
      bag = purchasedSlots + 5,
      purchase = true,
    })
  end
  return entries
end

function ShirsInventory_GetBankSlotCounts()
  local counts = {}
  local containers = ShirsInventory_GetBankContainerIDs()
  local index
  for index = 1, table.getn(containers) do
    local bag = containers[index]
    counts[bag] = GetContainerNumSlots and (GetContainerNumSlots(bag) or 0) or 0
  end
  return counts
end

function ShirsInventory_GetGridLayout(slotCount, maximumColumns)
  local columns = math.min(math.max(slotCount, 1), maximumColumns)
  local rows = math.ceil(slotCount / columns)
  if rows < 1 then rows = 1 end
  return {
    columns = columns,
    rows = rows,
    width = columns * 40 + 28,
    height = rows * 40 + 92,
  }
end

function ShirsInventory_GetItemId(link)
  if not link then
    return nil
  end
  local _, _, itemId = string.find(link, "item:(%d+)")
  return tonumber(itemId)
end

function ShirsInventory_IsJunk(itemId, quality, marks)
  if quality == 0 then
    return true
  end
  return itemId and marks and marks[itemId] and true or false
end

function ShirsInventory_BuildJunkQueue(items, marks)
  local result = {}
  for _, item in ipairs(items) do
    if not item.locked and ShirsInventory_IsJunk(item.itemId, item.quality, marks) then
      table.insert(result, {
        bag = item.bag,
        slot = item.slot,
        itemId = item.itemId,
      })
    end
  end
  return result
end
