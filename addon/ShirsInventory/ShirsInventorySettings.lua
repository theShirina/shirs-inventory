-- Full-suite settings and junk-sale controls.

local settingsFrame
local standaloneSortButton
local standaloneModeButton
local standaloneDirectionButton
local standaloneSettingsButton
local merchantSellButton
local sellerElapsed = 0
local standaloneLayoutElapsed = 0
local originalContainerItemClick
local nativeJunkHookInstalled
local refreshingSettings

function ShirsInventory_ApplyItemsPerRowSliderValue(value)
  local applied = ShirsInventory_SetItemsPerRow(value)
  if ShirsInventory_ApplyLayoutSettings then ShirsInventory_ApplyLayoutSettings() end
  return applied
end

function ShirsInventory_ApplyWindowScaleSliderValue(value)
  local applied = ShirsInventory_SetWindowScale(value)
  if ShirsInventory_ApplyWindowScaleSetting then ShirsInventory_ApplyWindowScaleSetting() end
  return applied
end

function ShirsInventory_GetStandaloneControlSpecs()
  return {
    {
      name = "sort", width = 18, height = 18,
      onClick = function() if ShirsInventory_SortBags then return ShirsInventory_SortBags() end end,
    },
    {
      name = "mode", width = 18, height = 18,
      onClick = function()
        local result
        if ShirsInventory_OnModeButtonClick then result = ShirsInventory_OnModeButtonClick() end
        ShirsInventory_RefreshButtonStyles()
        return result
      end,
    },
    {
      name = "direction", width = 18, height = 18,
      onClick = function()
        local result
        if ShirsInventory_ToggleDirection then result = ShirsInventory_ToggleDirection() end
        ShirsInventory_RefreshButtonStyles()
        return result
      end,
    },
    {
      name = "settings", width = 18, height = 18,
      onClick = function() return ShirsInventory_ShowSettings() end,
    },
  }
end

local function ShirsInventory_CreatePanel(name, width, height, strata)
  local frame = CreateFrame("Frame", name, UIParent)
  frame:SetWidth(width)
  frame:SetHeight(height)
  frame:SetFrameStrata(strata or "DIALOG")
  frame:SetToplevel(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  frame:SetBackdropColor(0.025, 0.035, 0.055, 0.98)
  frame:SetBackdropBorderColor(0.3, 0.6, 0.9, 1)
  return frame
end

local function ShirsInventory_CreateFeatureCheck(parent, label, feature, y)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetWidth(24)
  check:SetHeight(24)
  check:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
  check.feature = feature
  check.label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  check.label:SetPoint("LEFT", check, "RIGHT", 5, 1)
  check.label:SetText(label)
  return check
end

-- Icon-mode button styling lives in ShirsInventoryUI.lua (loaded before this
-- file) as ShirsInventory_ApplyButtonStyle / tooltip helpers.

function ShirsInventory_RefreshButtonStyles()
  local actionSpecs = ShirsInventory_GetInventoryButtonSpecs and ShirsInventory_GetInventoryButtonSpecs() or nil
  local function applyStandalone(button, name)
    if not button or not actionSpecs or not actionSpecs[name] then return end
    local spec = actionSpecs[name]
    spec.forceIcon = true
    spec.iconSize = 14
    ShirsInventory_ApplyButtonStyle(button, spec)
  end
  applyStandalone(standaloneSortButton, "sort")
  applyStandalone(standaloneModeButton, "mode")
  applyStandalone(standaloneDirectionButton, "direction")
  applyStandalone(standaloneSettingsButton, "settings")

  if type(ShirsInventory_RefreshInventoryButtonStyles) == "function" then
    ShirsInventory_RefreshInventoryButtonStyles()
  end
end

local function ShirsInventory_RefreshSettings()
  if not settingsFrame then return end
  settingsFrame.ignoreJunkSorting:SetChecked(ShirsInventory_GetIgnoreJunkSorting() and 1 or nil)
  settingsFrame.questItemsOppositeEdge:SetChecked(ShirsInventory_GetQuestItemsOppositeEdge() and 1 or nil)
  settingsFrame.autoSellJunk:SetChecked(ShirsInventory_GetAutoSellJunk() and 1 or nil)
  settingsFrame.showRarityBoxes:SetChecked(ShirsInventory_GetShowRarityBoxes() and 1 or nil)
  settingsFrame.useCoinIcons:SetChecked(ShirsInventory_GetUseCoinIcons() and 1 or nil)
  settingsFrame.hideItemOwnershipInCombat:SetChecked(
    ShirsInventory_GetHideItemOwnershipInCombat() and 1 or nil
  )
  refreshingSettings = true
  settingsFrame.itemsPerRowSlider:SetValue(ShirsInventory_GetItemsPerRow())
  settingsFrame.windowScaleSlider:SetValue(ShirsInventory_GetWindowScale())
  settingsFrame.itemsPerRowSliderText:SetText("Items per row: " .. ShirsInventory_GetItemsPerRow())
  settingsFrame.windowScaleSliderText:SetText(
    "Window scale: " .. math.floor(ShirsInventory_GetWindowScale() * 100 + 0.5) .. "%"
  )
  refreshingSettings = false
end

function ShirsInventory_ShowSettings()
  if not settingsFrame then return end
  ShirsInventory_RefreshSettings()
  settingsFrame:Show()
end

function ShirsInventory_CreateLayoutSliders(frame)
  if not frame or not CreateFrame then return false end
  frame.itemsPerRowSlider = CreateFrame(
    "Slider", "ShirsInventoryItemsPerRowSlider", frame, "OptionsSliderTemplate"
  )
  frame.itemsPerRowSlider:SetWidth(300)
  frame.itemsPerRowSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 45, -280)
  frame.itemsPerRowSlider:SetMinMaxValues(10, 20)
  frame.itemsPerRowSlider:SetValueStep(1)
  frame.itemsPerRowSliderText = getglobal("ShirsInventoryItemsPerRowSliderText")
  getglobal("ShirsInventoryItemsPerRowSliderLow"):SetText("10")
  getglobal("ShirsInventoryItemsPerRowSliderHigh"):SetText("20")
  frame.itemsPerRowSlider:SetScript("OnValueChanged", function()
    if refreshingSettings then return end
    ShirsInventory_ApplyItemsPerRowSliderValue(this:GetValue())
    ShirsInventory_RefreshSettings()
  end)

  frame.windowScaleSlider = CreateFrame(
    "Slider", "ShirsInventoryWindowScaleSlider", frame, "OptionsSliderTemplate"
  )
  frame.windowScaleSlider:SetWidth(300)
  frame.windowScaleSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 45, -345)
  frame.windowScaleSlider:SetMinMaxValues(0.65, 1)
  frame.windowScaleSlider:SetValueStep(0.05)
  frame.windowScaleSliderText = getglobal("ShirsInventoryWindowScaleSliderText")
  getglobal("ShirsInventoryWindowScaleSliderLow"):SetText("65%")
  getglobal("ShirsInventoryWindowScaleSliderHigh"):SetText("100%")
  frame.windowScaleSlider:SetScript("OnValueChanged", function()
    if refreshingSettings then return end
    local applied = ShirsInventory_ApplyWindowScaleSliderValue(this:GetValue())
    frame.windowScaleSliderText:SetText(
      "Window scale: " .. math.floor(applied * 100 + 0.5) .. "%"
    )
  end)
  return true
end

local function ShirsInventory_CreateSettingsFrame()
  local frame = ShirsInventory_CreatePanel("ShirsInventorySettingsFrame", 390, 460, "DIALOG")
  settingsFrame = frame
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", frame, "TOP", 0, -18)
  frame.title:SetText("Shir's Inventory Settings")
  frame.help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.help:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -48)
  frame.help:SetWidth(340)
  frame.help:SetJustifyH("LEFT")
  frame.help:SetText("The full inventory, sorter, and junk tools are always enabled. Settings are saved for this character.")

  frame.ignoreJunkSorting = ShirsInventory_CreateFeatureCheck(frame, "Ignore gray + manually marked junk while sorting", "ignoreJunkSorting", -82)
  frame.questItemsOppositeEdge = ShirsInventory_CreateFeatureCheck(frame, "Keep quest items at the opposite end of sorted items", "questItemsOppositeEdge", -112)
  frame.autoSellJunk = ShirsInventory_CreateFeatureCheck(frame, "Auto-sell gray + manually marked items at vendors", "autoSellJunk", -142)
  frame.showRarityBoxes = ShirsInventory_CreateFeatureCheck(frame, "Show quest and rarity borders on items", "showRarityBoxes", -172)
  frame.useCoinIcons = ShirsInventory_CreateFeatureCheck(frame, "Use coin icons for currency (off = g/s/c text)", "useCoinIcons", -202)
  frame.hideItemOwnershipInCombat = ShirsInventory_CreateFeatureCheck(
    frame, "Hide item ownership details while in combat", "hideItemOwnershipInCombat", -232
  )
  frame.ignoreJunkSorting:SetScript("OnClick", function()
    ShirsInventory_SetIgnoreJunkSorting(this:GetChecked() and true or false)
    ShirsInventory_RefreshSettings()
  end)
  frame.questItemsOppositeEdge:SetScript("OnClick", function()
    ShirsInventory_SetQuestItemsOppositeEdge(this:GetChecked() and true or false)
    ShirsInventory_RefreshSettings()
  end)

  frame.autoSellJunk:SetScript("OnClick", function()
    ShirsInventory_SetAutoSellJunk(this:GetChecked() and true or false)
    ShirsInventory_RefreshSettings()
  end)

  frame.showRarityBoxes:SetScript("OnClick", function()
    ShirsInventory_SetShowRarityBoxes(this:GetChecked() and true or false)
    if type(ShirsInventory_RefreshRarityBoxes) == "function" then
      ShirsInventory_RefreshRarityBoxes()
    end
    ShirsInventory_RefreshSettings()
  end)
  frame.useCoinIcons:SetScript("OnClick", function()
    ShirsInventory_SetUseCoinIcons(this:GetChecked() and true or false)
    if type(ShirsInventory_AccountUpdateDisplay) == "function" then
      ShirsInventory_AccountUpdateDisplay()
    end
    ShirsInventory_RefreshSettings()
  end)
  frame.hideItemOwnershipInCombat:SetScript("OnClick", function()
    ShirsInventory_SetHideItemOwnershipInCombat(this:GetChecked() and true or false)
    ShirsInventory_RefreshSettings()
  end)

  ShirsInventory_CreateLayoutSliders(frame)

  frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.closeButton:SetWidth(86)
  frame.closeButton:SetHeight(24)
  frame.closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
  frame.closeButton:SetText("Close")
  frame.closeButton:SetScript("OnClick", function() settingsFrame:Hide() end)
  frame:Hide()
  table.insert(UISpecialFrames, "ShirsInventorySettingsFrame")
  return frame
end

local function ShirsInventory_StartSaleFromButton()
  local count, status = ShirsInventory_StartJunkSale()
  if status == "started" then
    ShirsInventory_Message("Selling " .. count .. " junk stack(s)...")
    sellerElapsed = 0
  elseif status == "empty" then
    ShirsInventory_Message("No junk to sell.")
  end
end

function ShirsInventory_HandleAutoSellMerchant()
  local count, status = ShirsInventory_StartAutoJunkSale()
  if status == "started" then
    ShirsInventory_Message("Auto-selling " .. count .. " junk stack(s)...")
    sellerElapsed = 0
  end
  return count, status
end

local function ShirsInventory_InstallNativeJunkHook()
  if nativeJunkHookInstalled or not ContainerFrameItemButton_OnClick then return end
  nativeJunkHookInstalled = true
  originalContainerItemClick = ContainerFrameItemButton_OnClick
  ContainerFrameItemButton_OnClick = function(button, ignoreModifiers)
    if ShirsInventory_IsFeatureSelectionComplete() and ShirsInventory_IsFeatureEnabled("junk") and
      button == "RightButton" and not ignoreModifiers and IsAltKeyDown and IsAltKeyDown() then
      local bag = this:GetParent():GetID()
      if bag >= 0 and bag <= 4 then
        local texture, _, _, quality = GetContainerItemInfo(bag, this:GetID())
        if texture then
          local itemId = ShirsInventory_GetItemId(GetContainerItemLink(bag, this:GetID()))
          local marked, reason = ShirsInventory_ToggleJunk(itemId, quality)
          if reason == "automatic" then
            ShirsInventory_Message("Gray items are always junk.")
          elseif marked then
            ShirsInventory_Message("Marked this item type as junk.")
          else
            ShirsInventory_Message("Removed this item type from junk.")
          end
          ContainerFrame_Update(this:GetParent())
          return
        end
      end
    end
    originalContainerItemClick(button, ignoreModifiers)
  end
end

function ShirsInventory_FindVisibleBackpackFrame()
  local maximum = NUM_CONTAINER_FRAMES or 12
  local index
  for index = 1, maximum do
    local frame = getglobal and getglobal("ContainerFrame" .. index)
    if frame and frame.IsShown and frame:IsShown() and frame.GetID and frame:GetID() == 0 then return frame end
  end
  return nil
end

function ShirsInventory_FindVisibleExternalBagFrame()
  local frame = pfUI and pfUI.bag and pfUI.bag.right or nil
  if frame and frame.IsShown and frame:IsShown() then return frame, "pfui" end
  frame = getglobal and getglobal("pfBag") or nil
  if frame and frame.IsShown and frame:IsShown() then return frame, "pfui" end
  return nil
end

function ShirsInventory_GetStandaloneControlHost()
  local external, provider = ShirsInventory_FindVisibleExternalBagFrame()
  if external then return external, provider end
  local native = ShirsInventory_FindVisibleBackpackFrame()
  if native then return native, "native" end
  return nil
end

function ShirsInventory_GetStandaloneControlLayout(provider)
  if provider == "pfui" then
    return {
      count = 4,
      buttonWidth = 18,
      buttonHeight = 18,
      gap = 3,
      anchorPoint = "BOTTOMRIGHT",
      relativePoint = "TOPRIGHT",
      x = 0,
      y = 3,
    }
  end
  return {
    count = 4,
    buttonWidth = 18,
    buttonHeight = 18,
    gap = 3,
    anchorPoint = "TOPRIGHT",
    relativePoint = "TOPRIGHT",
    x = -32,
    y = -33,
  }
end

local function ShirsInventory_AttachStandaloneControls(host, provider)
  if not host then return false end
  local layout = ShirsInventory_GetStandaloneControlLayout(provider)
  local buttons = {
    standaloneSortButton,
    standaloneModeButton,
    standaloneDirectionButton,
    standaloneSettingsButton,
  }
  local index
  for index = 1, table.getn(buttons) do
    local button = buttons[index]
    button:SetParent(host)
    button:ClearAllPoints()
    button:SetWidth(layout.buttonWidth)
    button:SetHeight(layout.buttonHeight)
  end
  standaloneSettingsButton:SetPoint(
    layout.anchorPoint, host, layout.relativePoint, layout.x, layout.y
  )
  for index = 3, 1, -1 do
    buttons[index]:SetPoint("RIGHT", buttons[index + 1], "LEFT", -layout.gap, 0)
  end
  if host.GetFrameLevel then
    local level = host:GetFrameLevel() + 3
    for index = 1, table.getn(buttons) do buttons[index]:SetFrameLevel(level) end
  end
  return true
end

function ShirsInventory_ShouldUseStandaloneControls()
  return false
end

function ShirsInventory_UpdateStandaloneControls()
  if not standaloneSortButton then return end
  standaloneSortButton:Hide()
  standaloneModeButton:Hide()
  standaloneDirectionButton:Hide()
  standaloneSettingsButton:Hide()
  if ShirsInventory_ShouldShowMerchantSellButton() then
    merchantSellButton:Show()
    if MerchantRepairText then MerchantRepairText:Hide() end
  else
    merchantSellButton:Hide()
  end
end

local function ShirsInventory_CreateStandaloneControls()
  local specs = ShirsInventory_GetStandaloneControlSpecs()
  standaloneSortButton = CreateFrame("Button", "ShirsInventoryStandaloneSortButton", UIParent)
  standaloneModeButton = CreateFrame("Button", "ShirsInventoryStandaloneModeButton", UIParent)
  standaloneDirectionButton = CreateFrame("Button", "ShirsInventoryStandaloneDirectionButton", UIParent)
  standaloneSettingsButton = CreateFrame("Button", "ShirsInventoryStandaloneSettingsButton", UIParent)
  local buttons = {
    standaloneSortButton,
    standaloneModeButton,
    standaloneDirectionButton,
    standaloneSettingsButton,
  }
  local index
  for index = 1, table.getn(buttons) do
    buttons[index]:SetWidth(specs[index].width)
    buttons[index]:SetHeight(specs[index].height)
    buttons[index]:SetScript("OnClick", specs[index].onClick)
    buttons[index]:Hide()
  end

  merchantSellButton = CreateFrame("Button", "ShirsInventoryMerchantSellButton", MerchantFrame, "ItemButtonTemplate")
  merchantSellButton:SetWidth(36)
  merchantSellButton:SetHeight(36)
  merchantSellButton:SetPoint("RIGHT", MerchantRepairItemButton, "LEFT", -2, 0)
  local sellJunkTexture = getglobal("ShirsInventoryMerchantSellButtonIconTexture")
  sellJunkTexture:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  sellJunkTexture:SetTexCoord(0, 1, 0, 1)
  merchantSellButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Sell Junk")
    GameTooltip:AddLine("Sell gray and manually marked junk.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  merchantSellButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  merchantSellButton:SetScript("OnClick", function() ShirsInventory_StartSaleFromButton() end)
  merchantSellButton:Hide()

  ShirsInventory_RefreshButtonStyles()

  local driver = CreateFrame("Frame")
  driver:RegisterEvent("MERCHANT_SHOW")
  driver:RegisterEvent("MERCHANT_CLOSED")
  driver:RegisterEvent("BAG_UPDATE")
  driver:SetScript("OnEvent", function()
    if event == "MERCHANT_SHOW" then
      ShirsInventory_HandleAutoSellMerchant()
    elseif event == "MERCHANT_CLOSED" then
      ShirsInventory_CancelJunkSale()
    end
    ShirsInventory_UpdateStandaloneControls()
  end)
  driver:SetScript("OnUpdate", function()
    standaloneLayoutElapsed = standaloneLayoutElapsed + arg1
    if standaloneLayoutElapsed >= 0.20 then
      standaloneLayoutElapsed = 0
      ShirsInventory_UpdateStandaloneControls()
    end
    if ShirsInventory_GetJunkSaleState() then
      sellerElapsed = sellerElapsed + arg1
      if sellerElapsed >= 0.25 then
        sellerElapsed = 0
        ShirsInventory_SellNextJunk()
      end
    end
  end)
end

function ShirsInventory_CreateSettingsUI()
  if settingsFrame then return end
  ShirsInventory_CreateSettingsFrame()
  ShirsInventory_CreateStandaloneControls()
  ShirsInventory_InstallNativeJunkHook()
  ShirsInventory_RefreshSettings()
  ShirsInventory_UpdateStandaloneControls()
end
