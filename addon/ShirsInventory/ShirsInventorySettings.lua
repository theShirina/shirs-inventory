-- Per-character feature chooser, settings, and standalone controls.

local settingsFrame
local setupFrame
local bagConflictFrame
local standaloneSortButton
local standaloneModeButton
local standaloneDirectionButton
local standaloneSettingsButton
local merchantSellButton
local sellerElapsed = 0
local standaloneLayoutElapsed = 0
local originalContainerItemClick
local nativeJunkHookInstalled

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
  if merchantSellButton then
    ShirsInventory_ApplyButtonStyle(merchantSellButton, {
      text = "Sell Junk",
      icon = "Interface\\Icons\\INV_Misc_Coin_01",
    })
  end
  if type(ShirsInventory_RefreshInventoryButtonStyles) == "function" then
    ShirsInventory_RefreshInventoryButtonStyles()
  end
end

local function ShirsInventory_GetBagAddonTitles(addons)
  local titles = {}
  local _, addon
  for _, addon in ipairs(addons or {}) do table.insert(titles, addon.title or addon.name) end
  return table.concat(titles, ", ")
end

local function ShirsInventory_RefreshSettings()
  if not settingsFrame then return end
  settingsFrame.bagUI:SetChecked(ShirsInventory_IsFeatureEnabled("bagUI") and 1 or nil)
  settingsFrame.sorter:SetChecked(ShirsInventory_IsFeatureEnabled("sorter") and 1 or nil)
  settingsFrame.ignoreJunkSorting:SetChecked(ShirsInventory_GetIgnoreJunkSorting() and 1 or nil)
  settingsFrame.questItemsOppositeEdge:SetChecked(ShirsInventory_GetQuestItemsOppositeEdge() and 1 or nil)
  settingsFrame.junk:SetChecked(ShirsInventory_IsFeatureEnabled("junk") and 1 or nil)
  settingsFrame.autoSellJunk:SetChecked(ShirsInventory_GetAutoSellJunk() and 1 or nil)

  settingsFrame.showRarityBoxes:SetChecked(ShirsInventory_GetShowRarityBoxes() and 1 or nil)
  settingsFrame.useCoinIcons:SetChecked(ShirsInventory_GetUseCoinIcons() and 1 or nil)
  if ShirsInventory_IsFeatureEnabled("sorter") then
    settingsFrame.ignoreJunkSorting:Enable()
    settingsFrame.ignoreJunkSorting.label:SetTextColor(1, 0.82, 0)
    settingsFrame.questItemsOppositeEdge:Enable()
    settingsFrame.questItemsOppositeEdge.label:SetTextColor(1, 0.82, 0)
  else
    settingsFrame.ignoreJunkSorting:Disable()
    settingsFrame.ignoreJunkSorting.label:SetTextColor(0.5, 0.5, 0.5)
    settingsFrame.questItemsOppositeEdge:Disable()
    settingsFrame.questItemsOppositeEdge.label:SetTextColor(0.5, 0.5, 0.5)
  end
  if ShirsInventory_IsFeatureEnabled("junk") then
    settingsFrame.autoSellJunk:Enable()
    settingsFrame.autoSellJunk.label:SetTextColor(1, 0.82, 0)
  else
    settingsFrame.autoSellJunk:Disable()
    settingsFrame.autoSellJunk.label:SetTextColor(0.5, 0.5, 0.5)
  end
  local addons = ShirsInventory_GetDetectedBagAddons and ShirsInventory_GetDetectedBagAddons() or {}
  if table.getn(addons) > 0 then
    local signature = ShirsInventory_GetDetectedBagSignature()
    local choice = ShirsInventory_GetBagProviderChoice(signature)
    local provider = choice == "shirs" and "Shir's Inventory" or
      (choice == "other" and ShirsInventory_GetBagAddonTitles(addons) or "choice required")
    settingsFrame.bagProviderText:SetText("Bag UI provider: " .. provider)
    settingsFrame.bagProviderButton:Enable()
  else
    settingsFrame.bagProviderText:SetText("Bag UI provider: Shir's Inventory (no conflict detected)")
    settingsFrame.bagProviderButton:Disable()
  end
end

function ShirsInventory_ShowSettings()
  if not settingsFrame then return end
  ShirsInventory_RefreshSettings()
  settingsFrame.errorText:SetText("")
  settingsFrame:Show()
end

local function ShirsInventory_ApplySettingCheck(check)
  local enabled = check:GetChecked() and true or false
  if not ShirsInventory_SetFeatureEnabled(check.feature, enabled) then
    settingsFrame.errorText:SetText("Keep at least one feature enabled.")
    ShirsInventory_RefreshSettings()
    return
  end
  settingsFrame.errorText:SetText("")
  ShirsInventory_ApplyFeatureSelection()
  ShirsInventory_RefreshSettings()
end

local function ShirsInventory_CreateSettingsFrame()
  local frame = ShirsInventory_CreatePanel("ShirsInventorySettingsFrame", 390, 490, "DIALOG")
  settingsFrame = frame
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", frame, "TOP", 0, -18)
  frame.title:SetText("Shir's Inventory Settings")
  frame.help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.help:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -48)
  frame.help:SetWidth(340)
  frame.help:SetJustifyH("LEFT")
  frame.help:SetText("Choose any one feature or any combination. Settings are saved for this character.")

  frame.bagUI = ShirsInventory_CreateFeatureCheck(frame, "Full Bag UI", "bagUI", -82)
  frame.sorter = ShirsInventory_CreateFeatureCheck(frame, "Bag Sorter", "sorter", -122)
  frame.ignoreJunkSorting = ShirsInventory_CreateFeatureCheck(frame, "Ignore gray + manually marked junk while sorting", "ignoreJunkSorting", -152)
  frame.questItemsOppositeEdge = ShirsInventory_CreateFeatureCheck(frame, "Keep quest items at the opposite end of sorted items", "questItemsOppositeEdge", -182)
  frame.junk = ShirsInventory_CreateFeatureCheck(frame, "Sell Junk + manual junk marks", "junk", -212)
  frame.autoSellJunk = ShirsInventory_CreateFeatureCheck(frame, "Auto-sell gray + manually marked items at vendors", "autoSellJunk", -252)
  frame.showRarityBoxes = ShirsInventory_CreateFeatureCheck(frame, "Show quest and rarity borders on items", "showRarityBoxes", -282)
  frame.useCoinIcons = ShirsInventory_CreateFeatureCheck(frame, "Use coin icons for currency (off = g/s/c text)", "useCoinIcons", -312)
  frame.bagUI:SetScript("OnClick", function() ShirsInventory_ApplySettingCheck(this) end)
  frame.sorter:SetScript("OnClick", function() ShirsInventory_ApplySettingCheck(this) end)
  frame.ignoreJunkSorting:SetScript("OnClick", function()
    ShirsInventory_SetIgnoreJunkSorting(this:GetChecked() and true or false)
    ShirsInventory_RefreshSettings()
  end)
  frame.questItemsOppositeEdge:SetScript("OnClick", function()
    ShirsInventory_SetQuestItemsOppositeEdge(this:GetChecked() and true or false)
    ShirsInventory_RefreshSettings()
  end)
  frame.junk:SetScript("OnClick", function() ShirsInventory_ApplySettingCheck(this) end)
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

  frame.bagProviderText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.bagProviderText:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -372)
  frame.bagProviderText:SetWidth(340)
  frame.bagProviderText:SetJustifyH("LEFT")
  frame.bagProviderButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.bagProviderButton:SetWidth(128)
  frame.bagProviderButton:SetHeight(22)
  frame.bagProviderButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -397)
  frame.bagProviderButton:SetText("Choose Bag UI...")
  frame.bagProviderButton:SetScript("OnClick", function()
    ShirsInventory_ShowBagProviderChoice(ShirsInventory_GetDetectedBagAddons())
  end)

  frame.errorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.errorText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 53)
  frame.errorText:SetTextColor(1, 0.25, 0.25)

  frame.fullButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.fullButton:SetWidth(118)
  frame.fullButton:SetHeight(24)
  frame.fullButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 20)
  frame.fullButton:SetText("Use Full Addon")
  frame.fullButton:SetScript("OnClick", function()
    ShirsInventory_SetFullAddon()
    ShirsInventory_ApplyFeatureSelection()
    ShirsInventory_RefreshSettings()
  end)

  frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.closeButton:SetWidth(86)
  frame.closeButton:SetHeight(24)
  frame.closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 20)
  frame.closeButton:SetText("Close")
  frame.closeButton:SetScript("OnClick", function() settingsFrame:Hide() end)
  frame:Hide()
  table.insert(UISpecialFrames, "ShirsInventorySettingsFrame")
  return frame
end

local function ShirsInventory_SaveSetup(fullAddon)
  local ok
  if fullAddon then
    ok = ShirsInventory_SetFullAddon()
  else
    ok = ShirsInventory_SaveFeatureSelection(
      setupFrame.bagUI:GetChecked() and true or false,
      setupFrame.sorter:GetChecked() and true or false,
      setupFrame.junk:GetChecked() and true or false
    )
  end
  if not ok then
    setupFrame.errorText:SetText("Select at least one feature.")
    return
  end
  setupFrame.errorText:SetText("")
  setupFrame:Hide()
  ShirsInventory_ApplyFeatureSelection()
  ShirsInventory_RefreshSettings()
end

local function ShirsInventory_CreateSetupFrame()
  local frame = ShirsInventory_CreatePanel("ShirsInventorySetupFrame", 430, 330, "FULLSCREEN_DIALOG")
  setupFrame = frame
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 45)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", frame, "TOP", 0, -20)
  frame.title:SetText("Choose Shir's Inventory Features")
  frame.help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.help:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -55)
  frame.help:SetWidth(374)
  frame.help:SetJustifyH("LEFT")
  frame.help:SetText("This appears once for each character. Use the full addon or choose individual features. You can change this later with /si settings.")

  frame.bagUI = ShirsInventory_CreateFeatureCheck(frame, "Full Bag UI", "bagUI", -108)
  frame.sorter = ShirsInventory_CreateFeatureCheck(frame, "Bag Sorter", "sorter", -148)
  frame.junk = ShirsInventory_CreateFeatureCheck(frame, "Sell Junk + manual junk marks", "junk", -188)
  frame.bagUI:SetChecked(1)
  frame.sorter:SetChecked(1)
  frame.junk:SetChecked(1)

  frame.errorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.errorText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 62)
  frame.errorText:SetTextColor(1, 0.25, 0.25)

  frame.fullButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.fullButton:SetWidth(130)
  frame.fullButton:SetHeight(26)
  frame.fullButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 28, 25)
  frame.fullButton:SetText("Use Full Addon")
  frame.fullButton:SetScript("OnClick", function() ShirsInventory_SaveSetup(true) end)

  frame.customButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.customButton:SetWidth(145)
  frame.customButton:SetHeight(26)
  frame.customButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 25)
  frame.customButton:SetText("Save Custom Choice")
  frame.customButton:SetScript("OnClick", function() ShirsInventory_SaveSetup(false) end)
  frame:Hide()
  return frame
end

function ShirsInventory_ChooseBagProvider(choice)
  local signature = ShirsInventory_GetDetectedBagSignature()
  if not ShirsInventory_SaveBagProviderChoice(choice, signature) then return false end
  if choice == "shirs" and ShirsInventory_IsFeatureSelectionComplete() then
    ShirsInventory_SetFeatureEnabled("bagUI", true)
  end
  if bagConflictFrame then bagConflictFrame:Hide() end
  ShirsInventory_ApplyFeatureSelection()
  ShirsInventory_RefreshSettings()
  return true
end

function ShirsInventory_ShowBagProviderChoice(addons)
  addons = addons or (ShirsInventory_GetDetectedBagAddons and ShirsInventory_GetDetectedBagAddons()) or {}
  if table.getn(addons) == 0 then
    ShirsInventory_Message("No other loaded bag inventory addon was detected.")
    return false
  end
  if not bagConflictFrame then return false end
  bagConflictFrame.detected:SetText("Detected: " .. ShirsInventory_GetBagAddonTitles(addons))
  bagConflictFrame:Show()
  return true
end

local function ShirsInventory_CreateBagConflictFrame()
  local frame = ShirsInventory_CreatePanel("ShirsInventoryBagConflictFrame", 455, 290, "FULLSCREEN_DIALOG")
  bagConflictFrame = frame
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 55)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", frame, "TOP", 0, -20)
  frame.title:SetText("Choose Your Bag Inventory")
  frame.help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.help:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -58)
  frame.help:SetWidth(399)
  frame.help:SetJustifyH("LEFT")
  frame.help:SetText("Another bag inventory addon is loaded. Choose which addon owns the bag bar. Sorter and Junk stay independent; with an external bag UI, use /si sort, /si junk, and /si mark <item ID or item link>.")
  frame.detected = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.detected:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -132)
  frame.detected:SetWidth(399)
  frame.detected:SetJustifyH("LEFT")

  frame.shirsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.shirsButton:SetWidth(165)
  frame.shirsButton:SetHeight(28)
  frame.shirsButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 28, 26)
  frame.shirsButton:SetText("Use Shir's Bag UI")
  frame.shirsButton:SetScript("OnClick", function() ShirsInventory_ChooseBagProvider("shirs") end)

  frame.otherButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.otherButton:SetWidth(185)
  frame.otherButton:SetHeight(28)
  frame.otherButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 26)
  frame.otherButton:SetText("Keep Other Bag Addon")
  frame.otherButton:SetScript("OnClick", function() ShirsInventory_ChooseBagProvider("other") end)
  frame:Hide()
  table.insert(UISpecialFrames, "ShirsInventoryBagConflictFrame")
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
  if ShirsInventory_IsBagUIActive then return not ShirsInventory_IsBagUIActive() end
  return not ShirsInventory_IsFeatureEnabled("bagUI")
end

function ShirsInventory_UpdateStandaloneControls()
  if not standaloneSortButton then return end
  if not ShirsInventory_IsFeatureSelectionComplete() then
    standaloneSortButton:Hide()
    standaloneModeButton:Hide()
    standaloneDirectionButton:Hide()
    standaloneSettingsButton:Hide()
    merchantSellButton:Hide()
    return
  end
  local useStandalone = ShirsInventory_ShouldUseStandaloneControls()
  local host, provider
  if useStandalone then host, provider = ShirsInventory_GetStandaloneControlHost() end
  if host then ShirsInventory_AttachStandaloneControls(host, provider) end
  if ShirsInventory_IsFeatureEnabled("sorter") and host then
    standaloneSortButton:Show()
    standaloneModeButton:Show()
    standaloneDirectionButton:Show()
  else
    standaloneSortButton:Hide()
    standaloneModeButton:Hide()
    standaloneDirectionButton:Hide()
  end
  if host then standaloneSettingsButton:Show() else standaloneSettingsButton:Hide() end
  if ShirsInventory_IsFeatureEnabled("junk") then merchantSellButton:Show() else merchantSellButton:Hide() end
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

  merchantSellButton = CreateFrame("Button", "ShirsInventoryMerchantSellButton", MerchantFrame, "UIPanelButtonTemplate")
  merchantSellButton:SetWidth(86)
  merchantSellButton:SetHeight(24)
  merchantSellButton:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMRIGHT", -30, 88)
  merchantSellButton:SetText("Sell Junk")
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
  ShirsInventory_CreateSetupFrame()
  ShirsInventory_CreateBagConflictFrame()
  ShirsInventory_CreateStandaloneControls()
  ShirsInventory_InstallNativeJunkHook()
  ShirsInventory_RefreshSettings()
  ShirsInventory_UpdateStandaloneControls()
  if not ShirsInventory_IsFeatureSelectionComplete() then setupFrame:Show() end
end
