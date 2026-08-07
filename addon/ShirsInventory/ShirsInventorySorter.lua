-- Shir's Inventory WoW 1.12 sort adapter
-- Original implementation. Planning and move selection live in
-- ShirsInventorySortEngine.lua and do not call the WoW API.

local AUCTION_CLASSES = {GetAuctionItemClasses()}
local tooltip = CreateFrame("GameTooltip", "ShirsInventorySortTooltip", nil, "GameTooltipTemplate")
local runner = CreateFrame("Frame", "ShirsInventorySortRunner", UIParent)
runner:Hide()

local activeContainers
local activeTargets
local pendingStateSignature
local deadline
local elapsed = 0
local running = false
local diagnostics = { reason = "idle", moves = 0, mismatches = 0, failedMoves = 0, history = {} }

local function Message(text)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Shir's Inventory:|r " .. text)
  end
end

local function FindIndex(values, wanted)
  local index
  for index = 1, table.getn(values) do
    if values[index] == wanted then return index end
  end
  return 0
end

local function ItemTypeKey(itemType)
  return FindIndex(AUCTION_CLASSES, itemType)
end

local function ItemSubTypeKey(itemType, itemSubType)
  local classIndex = ItemTypeKey(itemType)
  if classIndex == 0 or type(GetAuctionItemSubClasses) ~= "function" then return 0 end
  return FindIndex({GetAuctionItemSubClasses(classIndex)}, itemSubType)
end

local function ItemInvTypeKey(itemType, itemSubType, inventoryType)
  local classIndex = ItemTypeKey(itemType)
  local subClassIndex = ItemSubTypeKey(itemType, itemSubType)
  if classIndex == 0 or type(GetAuctionInvTypes) ~= "function" then return 0 end
  return FindIndex({GetAuctionInvTypes(classIndex, subClassIndex)}, inventoryType)
end

local function ReadTooltipText(line)
  local region = getglobal("ShirsInventorySortTooltipTextLeft" .. line)
  if region then return region:GetText() end
  return nil
end

function ShirsInventory_ExtractLocalizedCount(text, template)
  if type(text) ~= "string" or type(template) ~= "string" then return nil end
  local markerStart, markerEnd = string.find(template, "%%1%$d")
  if not markerStart then markerStart, markerEnd = string.find(template, "%%d") end
  if not markerStart then return nil end
  local prefix = string.sub(template, 1, markerStart - 1)
  local suffix = string.sub(template, markerEnd + 1)
  if string.sub(text, 1, string.len(prefix)) ~= prefix then return nil end
  if suffix ~= "" and string.sub(text, -string.len(suffix)) ~= suffix then return nil end
  local valueStart = string.len(prefix) + 1
  local valueEnd = string.len(text) - string.len(suffix)
  return tonumber(string.sub(text, valueStart, valueEnd))
end

local function TooltipFacts(container, position)
  if not tooltip or type(tooltip.SetOwner) ~= "function" then
    return 1, false, false, false, false
  end

  tooltip:SetOwner(UIParent, "ANCHOR_NONE")
  tooltip:ClearLines()
  if container == BANK_CONTAINER and type(tooltip.SetInventoryItem) == "function" then
    tooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(position))
  elseif type(tooltip.SetBagItem) == "function" then
    tooltip:SetBagItem(container, position)
  end

  local facts = {charges = 1, usable = false, soulbound = false, quest = false, conjured = false}
  local lineCount = tooltip:NumLines()
  local line
  for line = 1, lineCount do
    local text = ReadTooltipText(line)
    local count = ShirsInventory_ExtractLocalizedCount(text, ITEM_SPELL_CHARGES_P1)
    if count then facts.charges = count end
    if text and ITEM_SPELL_TRIGGER_ONUSE and string.find(text, "^" .. ITEM_SPELL_TRIGGER_ONUSE) then facts.usable = true end
    if text and ITEM_SOULBOUND and text == ITEM_SOULBOUND then facts.soulbound = true end
    if text and ITEM_BIND_QUEST and text == ITEM_BIND_QUEST then facts.quest = true end
    if text and ITEM_CONJURED and text == ITEM_CONJURED then facts.conjured = true end
  end
  return facts.charges, facts.usable, facts.soulbound, facts.quest, facts.conjured
end

function ShirsInventory_GetSpecialtyItemClass(itemName, itemType, itemSubType, material)
  local name = string.lower(itemName or "")
  local subType = string.lower(itemSubType or "")
  if itemType == AUCTION_CLASSES[6] then
    if string.find(subType, "arrow", 1, true) then return "arrow" end
    if string.find(subType, "bullet", 1, true) then return "bullet" end
  end
  if string.find(name, "soul shard", 1, true) then return "soul" end
  if material == "Enchanting" then return "enchanting" end
  if material == "Herbs" then return "herb" end
  return nil
end

function ShirsInventory_GetSpecialtyBagClass(bagName, itemSubType)
  local description = string.lower(itemSubType or "")
  if string.find(description, "quiver", 1, true) then return "arrow" end
  if string.find(description, "ammo pouch", 1, true) or string.find(description, "shot pouch", 1, true) then return "bullet" end
  if string.find(description, "soul", 1, true) then return "soul" end
  if string.find(description, "enchant", 1, true) then return "enchanting" end
  if string.find(description, "herb", 1, true) then return "herb" end
  return nil
end

local function SpecialtyClassForContainer(container)
  if container == 0 or container == BANK_CONTAINER or type(GetBagName) ~= "function" then return nil end
  local bagName = GetBagName(container)
  if not bagName then return nil end
  local info = {GetItemInfo(bagName)}
  local itemSubType = type(info[5]) == "string" and info[6] or info[7]
  return ShirsInventory_GetSpecialtyBagClass(bagName, itemSubType)
end

local function FixedRank(itemID)
  if itemID == 6948 then return 1 end
  return nil
end

local function ReadItem(container, position, count)
  local link = GetContainerItemLink(container, position)
  if not link then return nil, "item-link" end
  local _, _, rawItemID, enchantID, suffixID, uniqueID = string.find(link, "item:(%d+):(%d*):(%d*):(%d*)")
  local itemID = tonumber(rawItemID)
  if not itemID then return nil, "item-id" end

  local itemInfo = {GetItemInfo(itemID)}
  local quality = itemInfo[3]
  local itemType
  local itemSubType
  local maxStack
  local inventoryType
  if type(itemInfo[5]) == "string" then
    -- Vanilla/Microbot nine-value signature omits the required-level field.
    itemType = itemInfo[5]
    itemSubType = itemInfo[6]
    maxStack = itemInfo[7]
    inventoryType = itemInfo[8]
  else
    -- Ten-value signature used by clients that include required level.
    itemType = itemInfo[6]
    itemSubType = itemInfo[7]
    maxStack = itemInfo[8]
    inventoryType = itemInfo[9]
  end
  if quality == nil or itemType == nil or maxStack == nil then return nil, "item-info" end
  local charges, usable, soulbound, quest, conjured = TooltipFacts(container, position)
  local material = ShirsInventory_GetMaterialCategory(itemID, itemType, itemSubType)
  local specialtyClass = ShirsInventory_GetSpecialtyItemClass(itemInfo[1], itemType, itemSubType, material)
  local isConsumable = (usable and itemType ~= AUCTION_CLASSES[1] and itemType ~= AUCTION_CLASSES[2] and itemType ~= AUCTION_CLASSES[8]) or itemType == AUCTION_CLASSES[4]
  local categoryRank = ShirsInventory_GetPrimaryCategoryRank(
    FixedRank(itemID), quality, specialtyClass == "soul", conjured,
    itemType == AUCTION_CLASSES[9], quest, material, soulbound, isConsumable
  )
  local sortKey = ShirsInventory_BuildGeneralSortKey(
    ShirsInventory_GetSortMode(), quality, categoryRank,
    ItemTypeKey(itemType), ItemSubTypeKey(itemType, itemSubType),
    ItemInvTypeKey(itemType, itemSubType, inventoryType), itemID,
    ShirsInventory_GetDirection()
  )
  sortKey.charges = charges
  sortKey.suffixID = tonumber(suffixID) or 0
  sortKey.enchantID = tonumber(enchantID) or 0
  sortKey.uniqueID = tonumber(uniqueID) or 0

  local stackSize = math.max(tonumber(maxStack) or 1, 1)
  local instanceKey = table.concat({itemID, enchantID or "", suffixID or "", uniqueID or "", charges, soulbound and 1 or 0}, ":")
  local mergeKey = instanceKey
  if stackSize > 1 and (tonumber(enchantID) or 0) == 0 and (tonumber(suffixID) or 0) == 0 then
    mergeKey = table.concat({itemID, 0, 0, charges, soulbound and 1 or 0}, ":")
  end

  local ignoreSort = ShirsInventory_GetIgnoreJunkSorting() and
    ShirsInventory_IsJunk(itemID, quality, ShirsInventoryDB and ShirsInventoryDB.junkItems)

  return {
    key = mergeKey,
    mergeKey = mergeKey,
    instanceKey = instanceKey,
    count = count,
    maxStack = stackSize,
    sortKey = sortKey,
    class = specialtyClass,
    edgeAnchor = itemID == 6948,
    ignoreSort = ignoreSort and true or false,
  }
end

local function ScanSlots()
  local slots = {}
  local containerIndex
  for containerIndex = 1, table.getn(activeContainers) do
    local container = activeContainers[containerIndex]
    local containerClass = SpecialtyClassForContainer(container)
    local position
    for position = 1, GetContainerNumSlots(container) do
      local texture, count, locked = GetContainerItemInfo(container, position)
      local slot = {
        container = container,
        position = position,
        class = containerClass,
        locked = locked and true or false,
      }
      if texture then
        count = tonumber(count) or 1
        if count < 1 then count = 1 end
        local item, reason = ReadItem(container, position, count)
        if not item then return nil, reason end
        slot.item = item
      end
      table.insert(slots, slot)
    end
  end
  return slots, nil
end

local function IsComplete(slots, targets)
  return ShirsInventory_SortEngineCountMismatches(slots, targets) == 0
end

function ShirsInventory_SortEngineCountMismatches(slots, targets)
  local mismatches = 0
  local index
  for index = 1, table.getn(slots) do
    local item = slots[index].item
    local target = targets[index]
    if target then
      if not item or item.key ~= target.key or item.count ~= target.count then mismatches = mismatches + 1 end
    elseif item then
      mismatches = mismatches + 1
    end
  end
  return mismatches
end

local function Stop(reason, message)
  running = false
  activeContainers = nil
  activeTargets = nil
  pendingStateSignature = nil
  runner:Hide()
  diagnostics.reason = reason
  if message then Message(message) end
end

local function Start(containers)
  if running then return false, "running" end
  if CursorHasItem() then
    Message("Clear the cursor before sorting.")
    return false, "cursor"
  end
  if UnitAffectingCombat and UnitAffectingCombat("player") then
    Message("Sorting is disabled during combat.")
    return false, "combat"
  end
  activeContainers = containers
  activeTargets = nil
  pendingStateSignature = nil
  deadline = GetTime() + ShirsInventory_GetSortTimeout()
  elapsed = ShirsInventory_GetSortDelay()
  running = true
  diagnostics = { reason = "running", moves = 0, mismatches = 0, failedMoves = 0, history = {}, seenStates = {} }
  runner:Show()
  return true, "started"
end

function ShirsInventory_GetSortEngineVersion()
  return 1
end

function ShirsInventory_GetSortDiagnostics()
  local history = {}
  local index
  for index = 1, table.getn(diagnostics.history) do history[index] = diagnostics.history[index] end
  return {
    reason = diagnostics.reason,
    moves = diagnostics.moves,
    mismatches = diagnostics.mismatches,
    failedMoves = diagnostics.failedMoves,
    bestMismatches = diagnostics.bestMismatches or 0,
    history = history,
  }
end

function ShirsInventory_IsRunning()
  return running
end

function ShirsInventory_SortBags()
  if ShirsInventory_IsFeatureEnabled and not ShirsInventory_IsFeatureEnabled("sorter") then
    Message("Bag Sorter is disabled in settings.")
    return false, "disabled"
  end
  return Start({0, 1, 2, 3, 4})
end

function ShirsInventory_SortBank()
  if ShirsInventory_IsFeatureEnabled and not ShirsInventory_IsFeatureEnabled("sorter") then
    Message("Bag Sorter is disabled in settings.")
    return false, "disabled"
  end
  if not BankFrame or not BankFrame:IsVisible() then
    Message("Open the bank before sorting bank slots.")
    return false, "bank"
  end
  return Start({-1, 5, 6, 7, 8, 9, 10})
end

runner:SetScript("OnUpdate", function()
  if not running then return end
  elapsed = elapsed + arg1
  if elapsed < ShirsInventory_GetSortDelay() then return end
  elapsed = 0

  if GetTime() > deadline then
    Stop("timeout", "Sorting stopped after the safety timeout (" .. diagnostics.moves .. " moves, " .. diagnostics.mismatches .. " slots left).")
    return
  end
  if CursorHasItem() then
    Stop("cursor", "Sorting stopped because the cursor is holding an item.")
    return
  end
  if UnitAffectingCombat and UnitAffectingCombat("player") then
    Stop("combat", "Sorting stopped because combat started.")
    return
  end

  local slots, scanError = ScanSlots()
  if not slots then
    if scanError ~= "item-info" then Stop("scan", "Sorting stopped because an item could not be read.") end
    return
  end
  if not activeTargets then
    activeTargets = ShirsInventory_SortEnginePlan(slots, ShirsInventory_GetDirection())
  end
  local targets = activeTargets
  diagnostics.mismatches = ShirsInventory_SortEngineCountMismatches(slots, targets)
  if not diagnostics.bestMismatches or diagnostics.mismatches < diagnostics.bestMismatches then
    diagnostics.bestMismatches = diagnostics.mismatches
  end

  local signatureParts = {}
  local signatureIndex
  for signatureIndex = 1, table.getn(slots) do
    local signatureItem = slots[signatureIndex].item
    if signatureItem then
      signatureParts[signatureIndex] = signatureItem.key .. "=" .. signatureItem.count
    else
      signatureParts[signatureIndex] = "-"
    end
  end
  local stateSignature = table.concat(signatureParts, "|")

  -- Cursor-empty only confirms that the click sequence ended safely. The bag
  -- snapshot must change before the command counts as progress; legacy clients
  -- can expose the old snapshot for one or more update ticks.
  if pendingStateSignature then
    if stateSignature == pendingStateSignature then return end
    pendingStateSignature = nil
    diagnostics.moves = diagnostics.moves + 1
    deadline = GetTime() + ShirsInventory_GetSortTimeout()
  end

  if IsComplete(slots, targets) then
    Stop("complete", nil)
    return
  end

  if diagnostics.seenStates[stateSignature] then
    Stop("cycle", "Sorting stopped because the same inventory state repeated.")
    return
  end

  local move = ShirsInventory_SortEngineChooseMove(slots, targets)
  if not move then
    Stop("deadlock", "Sorting stopped because no safe move was available.")
    return
  end

  local source = slots[move.source]
  local destination = slots[move.destination]
  local sourceKey = source.item and source.item.key or "empty"
  local destinationKey = destination.item and destination.item.key or "empty"
  local moveText = source.container .. ":" .. source.position .. ">" .. destination.container .. ":" .. destination.position ..
    " " .. sourceKey .. " / " .. destinationKey
  table.insert(diagnostics.history, moveText)
  if table.getn(diagnostics.history) > 8 then table.remove(diagnostics.history, 1) end
  if ShirsInventory_MoveCursorItem(source.container, source.position, destination.container, destination.position) then
    diagnostics.seenStates[stateSignature] = true
    pendingStateSignature = stateSignature
  else
    diagnostics.failedMoves = diagnostics.failedMoves + 1
  end
end)
