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
  return id ~= nil and id >= 0 and id <= 4
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
  if ITEM_CLASS_QUEST and itemType == ITEM_CLASS_QUEST then return true end
  if type(AUCTION_CLASSES) == "table" and itemType == AUCTION_CLASSES[9] then return true end
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

function ShirsInventory_GetClampedTopLeft(left, top, width, height, screenWidth, screenHeight, margin, bottomMargin)
  margin = margin or 8
  bottomMargin = bottomMargin or margin
  if left < margin then left = margin end
  if left + width > screenWidth - margin then left = screenWidth - margin - width end
  if top > screenHeight - margin then top = screenHeight - margin end
  if top - height < bottomMargin then top = height + bottomMargin end
  return left, top
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

function ShirsInventory_HandleBagBarClick(button, mouseButton)
  local entry = button and button.bagEntry or nil
  if mouseButton ~= "LeftButton" or not entry or entry.bag == 0 or not entry.inventoryID then
    return false
  end
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
  local texture, count, locked, quality = GetContainerItemInfo(bag, slot)
  if not texture then
    if mouseButton == "LeftButton" then
      PickupContainerItem(bag, slot)
      if StackSplitFrame then StackSplitFrame:Hide() end
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
  }

  ToggleBackpack = function()
    local frame = ShirsInventory_GetFrame()
    if frame:IsShown() then frame:Hide() else frame:Show() end
  end

  OpenBackpack = function()
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

  ToggleBag = function(id)
    if ShirsInventory_IsNormalBag(id) then
      ToggleBackpack()
    elseif originalBagFunctions.ToggleBag then
      originalBagFunctions.ToggleBag(id)
    end
  end

  OpenBag = function(id)
    if ShirsInventory_IsNormalBag(id) then
      ShirsInventory_GetFrame():Show()
    elseif originalBagFunctions.OpenBag then
      originalBagFunctions.OpenBag(id)
    end
  end

  CloseBag = function(id)
    if ShirsInventory_IsNormalBag(id) then
      ShirsInventory_GetFrame():Hide()
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
    IsBagOpen ~= installedBagFunctions.IsBagOpen
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
local bankPurchaseButton
local saleElapsed = 0

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

function ShirsInventory_GetInventoryButtonSpecs()
  local mode = ShirsInventory_GetSortMode and ShirsInventory_GetSortMode() or "itemType"
  local direction = ShirsInventory_GetDirection and ShirsInventory_GetDirection() or "bottom"
  local iconSize = ShirsInventory_GetInventoryActionVisualModel().iconSize
  return {
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
  local specs = ShirsInventory_GetInventoryButtonSpecs()
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
end

function ShirsInventory_RefreshInventoryButtonStyles()
  ShirsInventory_RefreshActionButtonStyles(ShirsInventoryFrame, false)
end

function ShirsInventory_RefreshBankButtonStyles()
  ShirsInventory_RefreshActionButtonStyles(ShirsInventoryBankFrame, true)
end

function ShirsInventory_OnModeButtonClick()
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
  if MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 and not locked then
    if ShowContainerSellCursor then ShowContainerSellCursor(button.bag, button.slot) end
  elseif readable or (IsControlKeyDown and IsControlKeyDown() and button.hasItem) then
    if ShowInspectCursor then ShowInspectCursor() end
  elseif ResetCursor then
    ResetCursor()
  end
end

function ShirsInventory_SetItemTooltip(button)
  if not button then return nil end
  if button.bag == (BANK_CONTAINER or -1) and GameTooltip.SetInventoryItem and BankButtonIDToInvSlotID then
    GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(button.slot))
    return "bank"
  end
  GameTooltip:SetBagItem(button.bag, button.slot)
  return "bag"
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
  local _, _, locked, quality, readable = GetContainerItemInfo(button.bag, button.slot)
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
  button.junkBadge = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.junkBadge:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
  button.junkBadge:SetText("J")
  button.junkBadge:SetTextColor(1, 0.15, 0.15)
  button.junkBadge:Hide()

  button:SetScript("OnClick", function() ShirsInventory_HandleItemClick(this, arg1) end)
  button:SetScript("OnDragStart", function() ShirsInventory_HandleItemClick(this, "LeftButton", true) end)
  button:SetScript("OnReceiveDrag", function() ShirsInventory_HandleItemClick(this, "LeftButton", true) end)
  button:SetScript("OnEnter", function() ShirsInventory_OnItemEnter(this) end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
    ResetCursor()
  end)
  button:SetScript("OnUpdate", function()
    ShirsInventory_UpdateCooldownDisplay(this, arg1)
    if GameTooltip:IsOwned(this) then ShirsInventory_OnItemEnter(this) end
  end)
  buttons[index] = button
  return button
end

local function ShirsInventory_UpdateItemButton(button)
  local texture, count, locked, quality, readable = GetContainerItemInfo(button.bag, button.slot)
  SetItemButtonTexture(button, texture)
  SetItemButtonCount(button, count)
  SetItemButtonDesaturated(button, locked, 0.5, 0.5, 0.5)
  button.count = count or 0
  button.readable = readable
  button.hasItem = texture and true or nil

  local normal = button:GetNormalTexture()
  if normal then normal:SetVertexColor(1, 1, 1) end

  if button.rarityEdges then
    local link = texture and GetContainerItemLink and GetContainerItemLink(button.bag, button.slot) or nil
    local itemInfo = ShirsInventory_GetItemInfoFields(link)
    local border = ShirsInventory_GetItemBorderModel(
      texture,
      ShirsInventory_ResolveItemQuality(quality, itemInfo.quality),
      itemInfo.itemType,
      ShirsInventory_GetShowRarityBoxes and ShirsInventory_GetShowRarityBoxes()
    )
    button.shirsBorderKind = border and border.kind or nil
    local edgeIndex
    for edgeIndex = 1, table.getn(button.rarityEdges) do
      local edge = button.rarityEdges[edgeIndex]
      if border then
        edge:SetVertexColor(border.r, border.g, border.b, border.a)
        edge:Show()
      else
        edge:Hide()
      end
    end
  end

  if texture then
    ShirsInventory_UpdateCooldown(button)
    local itemId = ShirsInventory_GetItemId(GetContainerItemLink(button.bag, button.slot))
    if (not ShirsInventory_IsFeatureEnabled or ShirsInventory_IsFeatureEnabled("junk")) and
      ShirsInventory_IsJunk(itemId, quality, ShirsInventory_GetJunkItems()) then
      button.junkBadge:Show()
    else
      button.junkBadge:Hide()
    end
  else
    button.cooldown:Hide()
    button.junkBadge:Hide()
  end
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
  for index = 1, 5 do
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
    button:SetScript("OnDragStart", function() ShirsInventory_HandleBagBarClick(this, "LeftButton") end)
    button:SetScript("OnReceiveDrag", function() ShirsInventory_HandleBagBarDrop(this) end)
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
      if entry.empty then
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

function ShirsInventory_ClampInventoryFrame(frame, preserveSavedPosition)
  frame = frame or ShirsInventoryFrame
  if not frame then return false end
  if preserveSavedPosition and ShirsInventory_GetInventoryFramePosition and
    ShirsInventory_GetInventoryFramePosition() then
    return true
  end
  if not UIParent or not frame.GetLeft or not frame.GetTop or not frame.GetWidth or
    not frame.GetHeight or not UIParent.GetWidth or not UIParent.GetHeight then
    return true
  end
  local left = frame:GetLeft()
  local top = frame:GetTop()
  if not left or not top then return true end
  local bottomMargin = 8
  if MainMenuBarBackpackButton and MainMenuBarBackpackButton.GetTop then
    bottomMargin = (MainMenuBarBackpackButton:GetTop() or 0) + 8
  end
  local newLeft, newTop = ShirsInventory_GetClampedTopLeft(
    left, top, frame:GetWidth(), frame:GetHeight(),
    UIParent:GetWidth(), UIParent:GetHeight(), 8, bottomMargin
  )
  if newLeft == left and newTop == top then return true end
  return ShirsInventory_SetInventoryFrameAnchor(
    frame, "TOPLEFT", UIParent, "BOTTOMLEFT", newLeft, newTop, true
  )
end

local function ShirsInventory_RebuildGrid()
  local counts = {}
  local free = 0
  for bag = 0, 4 do counts[bag] = GetContainerNumSlots(bag) or 0 end
  local slots = ShirsInventory_BuildInventorySlots(counts)
  local layout = ShirsInventory_GetGridLayout(table.getn(slots), 10)
  local bagBarLayout = ShirsInventory_GetBagBarLayout()
  ShirsInventoryFrame:SetWidth(layout.width)
  ShirsInventoryFrame:SetHeight(layout.height + bagBarLayout.heightExtra)
  ShirsInventory_ClampInventoryFrame(ShirsInventoryFrame, true)
  ShirsInventory_UpdateBagBar()

  for index, address in ipairs(slots) do
    local button = inventoryButtons[index] or ShirsInventory_CreateItemButton(index)
    button.bag = address.bag
    button.slot = address.slot
    button:SetID(address.slot)
    button:ClearAllPoints()
    local column = math.mod(index - 1, layout.columns)
    local row = math.floor((index - 1) / layout.columns)
    button:SetPoint("TOPLEFT", ShirsInventoryFrame, "TOPLEFT", 14 + column * 40, bagBarLayout.gridTopOffset - row * 40)
    button:Show()
    ShirsInventory_UpdateItemButton(button)
    if not button.hasItem then free = free + 1 end
  end
  for index = table.getn(slots) + 1, table.getn(inventoryButtons) do
    inventoryButtons[index]:Hide()
  end
  ShirsInventoryFrame.freeText:SetText(free .. " free")
end

function ShirsInventory_Update()
  if not ShirsInventoryFrame or not ShirsInventoryFrame:IsShown() then return end
  ShirsInventory_RebuildGrid()
  ShirsInventory_UpdateControlLabels()
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
  frame.sortButton:SetScript("OnClick", function()
    if ShirsInventory_SortBank then ShirsInventory_SortBank() end
  end)

  frame.modeButton = CreateFrame("Button", nil, frame)
  frame.modeButton:SetWidth(80)
  frame.modeButton:SetHeight(22)
  frame.modeButton:SetScript("OnClick", function() ShirsInventory_OnModeButtonClick() end)

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

  local index, address
  for index, address in ipairs(slots) do
    local button = bankButtons[index] or ShirsInventory_CreateItemButton(
      index, frame, "ShirsInventoryBankItem", bankButtons
    )
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

  frame:SetScript("OnShow", function()
    ShirsInventory_ApplyBankFrameAnchor(this)
    this.title:SetText(ShirsInventory_GetBankTitle(UnitName and UnitName("player")))
    ShirsInventory_SuppressOtherBankFrames()
    ShirsInventory_RefreshBankButtonStyles()
  end)
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() ShirsInventory_OnBankDragStop(this) end)
  frame:SetScript("OnEvent", function()
    ShirsInventory_HandleBankEvent(event, this)
  end)
  frame:SetScript("OnUpdate", function()
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
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
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

  frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)

  ShirsInventory_CreateBagBar(frame)

  frame.sortButton = CreateFrame("Button", nil, frame)
  frame.sortButton:SetWidth(64)
  frame.sortButton:SetHeight(22)
  frame.sortButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 13)
  frame.sortButton:SetText("Sort")
  frame.sortButton:SetScript("OnClick", function()
    if ShirsInventory_SortBags then ShirsInventory_SortBags() end
  end)

  frame.modeButton = CreateFrame("Button", nil, frame)
  frame.modeButton:SetWidth(80)
  frame.modeButton:SetHeight(22)
  frame.modeButton:SetPoint("LEFT", frame.sortButton, "RIGHT", 4, 0)
  frame.modeButton:SetScript("OnClick", function() ShirsInventory_OnModeButtonClick() end)

  frame.directionButton = CreateFrame("Button", nil, frame)
  frame.directionButton:SetWidth(64)
  frame.directionButton:SetHeight(22)
  frame.directionButton:SetPoint("LEFT", frame.modeButton, "RIGHT", 4, 0)
  frame.directionButton:SetScript("OnClick", function()
    if ShirsInventory_ToggleDirection then ShirsInventory_ToggleDirection() end
    ShirsInventory_UpdateControlLabels()
  end)

  frame.settingsButton = CreateFrame("Button", nil, frame)
  frame.settingsButton:SetWidth(72)
  frame.settingsButton:SetHeight(22)
  frame.settingsButton:SetPoint("LEFT", frame.directionButton, "RIGHT", 4, 0)
  frame.settingsButton:SetText("Settings")
  frame.settingsButton:SetScript("OnClick", function() ShirsInventory_ShowSettings() end)

  frame:SetScript("OnShow", function()
    ShirsInventory_PrepareInventoryFrameForShow(this, UnitName and UnitName("player"))
    ShirsInventory_HideNativeNormalBags()
    ShirsInventory_SetBagChecks(1)
    ShirsInventory_Update()
    PlaySound("igBackPackOpen")
  end)
  frame:SetScript("OnHide", function()
    ShirsInventory_SetBagChecks(0)
    if GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
    PlaySound("igBackPackClose")
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
  frame:Hide()

  table.insert(UISpecialFrames, "ShirsInventoryFrame")
  ShirsInventory_UpdateControlLabels()
  ShirsInventory_RefreshInventoryButtonStyles()
  return frame
end

function ShirsInventory_HandleSlashCommand(message)
  local _, _, command, value = string.find(message or "", "^%s*(%S*)%s*(.-)%s*$")
  command = string.lower(command or "")
  if command == "mark" or command == "unmark" then
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
