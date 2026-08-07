-- Shir's Inventory junk marking and merchant sale runtime.

local function ShirsInventory_EnsureJunkItems()
  if type(ShirsInventoryDB) ~= "table" then
    ShirsInventoryDB = {}
  end
  if type(ShirsInventoryDB.junkItems) ~= "table" then
    ShirsInventoryDB.junkItems = {}
  end
  return ShirsInventoryDB.junkItems
end

function ShirsInventory_ToggleJunk(itemId, quality)
  if ShirsInventory_IsFeatureEnabled and not ShirsInventory_IsFeatureEnabled("junk") then
    return false, "disabled"
  end
  if not itemId then
    return false, "invalid"
  end
  if quality == 0 then
    return true, "automatic"
  end

  local marks = ShirsInventory_EnsureJunkItems()
  if marks[itemId] then
    marks[itemId] = nil
    return false, "unmarked"
  end

  marks[itemId] = true
  return true, "marked"
end

function ShirsInventory_GetJunkItems()
  return ShirsInventory_EnsureJunkItems()
end

function ShirsInventory_SetJunkMark(value, enabled)
  if ShirsInventory_IsFeatureEnabled and not ShirsInventory_IsFeatureEnabled("junk") then
    return false, "disabled"
  end
  local itemId = ShirsInventory_ParseItemID and ShirsInventory_ParseItemID(value) or tonumber(value)
  if not itemId then return false, "invalid" end
  local marks = ShirsInventory_EnsureJunkItems()
  if enabled then
    marks[itemId] = true
    return true, "marked", itemId
  end
  marks[itemId] = nil
  return true, "unmarked", itemId
end

local saleState

local function ShirsInventory_MerchantCanSell()
  return MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab ~= 2
end

local function ShirsInventory_CollectBagItems()
  local counts = {}
  for bag = 0, 4 do
    counts[bag] = GetContainerNumSlots(bag) or 0
  end

  local result = {}
  local slots = ShirsInventory_BuildInventorySlots(counts)
  for _, address in ipairs(slots) do
    local texture, count, locked, quality = GetContainerItemInfo(address.bag, address.slot)
    if texture then
      table.insert(result, {
        bag = address.bag,
        slot = address.slot,
        itemId = ShirsInventory_GetItemId(GetContainerItemLink(address.bag, address.slot)),
        quality = quality,
        locked = locked,
        count = count,
      })
    end
  end
  return result
end

function ShirsInventory_StartJunkSale()
  if ShirsInventory_IsFeatureEnabled and not ShirsInventory_IsFeatureEnabled("junk") then
    saleState = nil
    return 0, "disabled"
  end
  if not ShirsInventory_MerchantCanSell() then
    saleState = nil
    return 0, "merchant"
  end

  local queue = ShirsInventory_BuildJunkQueue(
    ShirsInventory_CollectBagItems(),
    ShirsInventory_EnsureJunkItems()
  )
  if table.getn(queue) == 0 then
    saleState = nil
    return 0, "empty"
  end

  saleState = {
    queue = queue,
    index = 1,
    sold = 0,
    startMoney = GetMoney and GetMoney() or 0,
  }
  return table.getn(queue), "started"
end

function ShirsInventory_StartAutoJunkSale()
  if ShirsInventory_IsFeatureSelectionComplete and not ShirsInventory_IsFeatureSelectionComplete() then
    return 0, "disabled"
  end
  if not ShirsInventory_GetAutoSellJunk or not ShirsInventory_GetAutoSellJunk() then
    return 0, "disabled"
  end
  return ShirsInventory_StartJunkSale()
end

function ShirsInventory_CancelJunkSale()
  saleState = nil
end

function ShirsInventory_GetJunkSaleState()
  return saleState
end

function ShirsInventory_SellNextJunk()
  if not saleState then
    return false, "idle"
  end
  if not ShirsInventory_MerchantCanSell() then
    saleState = nil
    return false, "cancelled"
  end

  local entry = saleState.queue[saleState.index]
  if not entry then
    local sold = saleState.sold
    local gained = (GetMoney and GetMoney() or saleState.startMoney) - saleState.startMoney
    saleState = nil
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff68ccefShir's Inventory:|r sold " .. sold .. " junk stack(s) for " .. gained .. " copper.")
    end
    return false, "complete"
  end
  saleState.index = saleState.index + 1

  local texture, _, locked, quality = GetContainerItemInfo(entry.bag, entry.slot)
  local itemId = ShirsInventory_GetItemId(GetContainerItemLink(entry.bag, entry.slot))
  if not texture or locked or itemId ~= entry.itemId or not ShirsInventory_IsJunk(itemId, quality, ShirsInventory_EnsureJunkItems()) then
    return false, "skipped"
  end

  UseContainerItem(entry.bag, entry.slot)
  saleState.sold = saleState.sold + 1
  return true, "sold"
end
