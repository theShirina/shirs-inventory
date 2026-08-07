ShirsInventory_MaterialRanks = {
  Mining = 1,
  Herbs = 2,
  Cloth = 3,
  Leather = 4,
  Enchanting = 5,
  Elemental = 6,
  Engineering = 7,
  Gems = 8,
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
  if type(ShirsInventoryDB.junkItems) ~= "table" then
    ShirsInventoryDB.junkItems = {}
  end
  if type(ShirsInventoryDB.features) ~= "table" then
    ShirsInventoryDB.features = {}
  end
  if ShirsInventoryDB.features.bagUI == nil then ShirsInventoryDB.features.bagUI = true end
  if ShirsInventoryDB.features.sorter == nil then ShirsInventoryDB.features.sorter = true end
  if ShirsInventoryDB.features.junk == nil then ShirsInventoryDB.features.junk = true end
  if ShirsInventoryDB.professionLearning == nil then
    ShirsInventoryDB.professionLearning = true
  end
  if ShirsInventoryDB.useIconButtons == nil then
    ShirsInventoryDB.useIconButtons = false
  end
  if ShirsInventoryDB.showRarityBoxes == nil then
    ShirsInventoryDB.showRarityBoxes = true
  end
  if ShirsInventoryDB.useCoinIcons == nil then
    ShirsInventoryDB.useCoinIcons = true
  end
  return ShirsInventoryDB
end

function ShirsInventory_IsFeatureSelectionComplete()
  return ShirsInventory_EnsureDB().setupComplete and true or false
end

function ShirsInventory_IsFeatureEnabled(feature)
  local features = ShirsInventory_EnsureDB().features
  return features[feature] and true or false
end

function ShirsInventory_SaveFeatureSelection(bagUI, sorter, junk)
  if not bagUI and not sorter and not junk then
    return false
  end
  local db = ShirsInventory_EnsureDB()
  db.features.bagUI = bagUI and true or false
  db.features.sorter = sorter and true or false
  db.features.junk = junk and true or false
  db.setupComplete = true
  return true
end

function ShirsInventory_SetFullAddon()
  return ShirsInventory_SaveFeatureSelection(true, true, true)
end

function ShirsInventory_SetFeatureEnabled(feature, enabled)
  if feature ~= "bagUI" and feature ~= "sorter" and feature ~= "junk" then
    return false
  end
  local db = ShirsInventory_EnsureDB()
  if not enabled then
    local otherEnabled = false
    for name, value in pairs(db.features) do
      if name ~= feature and value then otherEnabled = true end
    end
    if not otherEnabled then return false end
  end
  db.features[feature] = enabled and true or false
  db.setupComplete = true
  return true
end

function ShirsInventory_GetAutoSellJunk()
  return ShirsInventory_EnsureDB().autoSellJunk and true or false
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
  local db = ShirsInventory_EnsureDB()
  if type(signature) ~= "string" or signature == "" or db.bagProviderSignature ~= signature then return nil end
  if db.bagProviderChoice == "shirs" or db.bagProviderChoice == "other" then return db.bagProviderChoice end
  return nil
end

function ShirsInventory_SaveBagProviderChoice(choice, signature)
  if choice ~= "shirs" and choice ~= "other" then return false end
  if type(signature) ~= "string" or signature == "" then return false end
  local db = ShirsInventory_EnsureDB()
  db.bagProviderChoice = choice
  db.bagProviderSignature = signature
  return true
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
  if eventName == "CRAFT_SHOW" then
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

if CreateFrame then
  local professionLearner = CreateFrame("Frame", "ShirsInventoryProfessionLearner", UIParent)
  if professionLearner and professionLearner.RegisterEvent then
    professionLearner:RegisterEvent("TRADE_SKILL_SHOW")
    professionLearner:RegisterEvent("CRAFT_SHOW")
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
        if scanEvent then ShirsInventory_LearnProfessionReagents(scanEvent) end
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

function ShirsInventory_GetSortDelay()
  return 0.35
end

function ShirsInventory_GetSortTimeout()
  return 15
end

function ShirsInventory_GetInventoryFramePosition()
  local position = ShirsInventory_EnsureDB().inventoryPosition
  if type(position) ~= "table" then return nil end
  return position
end

function ShirsInventory_SaveInventoryFramePosition(frame)
  if not frame or type(frame.GetPoint) ~= "function" then return false end
  local point, _, relativePoint, x, y = frame:GetPoint(1)
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

function ShirsInventory_ResetInventoryFramePosition()
  ShirsInventory_EnsureDB().inventoryPosition = nil
  return true
end

function ShirsInventory_BuildGeneralSortKey(mode, quality, categoryRank, typeKey, subTypeKey, invTypeKey, itemID, direction)
  local rarityOrder = -quality
  if mode == "rarity" and direction == "bottom" then rarityOrder = quality end
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

function ShirsInventory_BuildInventorySlots(slotCounts)
  local result = {}
  for bag = 0, 4 do
    local count = slotCounts[bag] or 0
    for slot = 1, count do
      table.insert(result, { bag = bag, slot = slot })
    end
  end
  return result
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
