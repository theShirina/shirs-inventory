-- Full-suite settings and junk-sale controls.

local settingsFrame
local hearthstoneItemsFrame
local categoryManagerFrame
local hearthstoneItemsPage = 1
local hearthstoneDraggedItemID
local SHIRS_INVENTORY_HEARTHSTONE_ROWS_PER_PAGE = 8
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

function ShirsInventory_SetCategoryModeAndReload(enabled, reloadFunc)
  enabled = enabled and true or false
  if ShirsInventory_GetCategoryMode() == enabled then return false end
  ShirsInventory_SetCategoryMode(enabled)
  reloadFunc = reloadFunc or ReloadUI
  if type(reloadFunc) == "function" then reloadFunc() end
  return true
end

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

function ShirsInventory_GetHearthstoneItemDisplayRows(page, pageSize)
  local items = ShirsInventory_GetHearthstoneItems()
  local total = table.getn(items)
  pageSize = math.max(1, math.floor(tonumber(pageSize) or SHIRS_INVENTORY_HEARTHSTONE_ROWS_PER_PAGE))
  local pageCount = math.max(1, math.ceil(total / pageSize))
  page = math.max(1, math.min(pageCount, math.floor(tonumber(page) or 1)))
  local rows = {}
  local firstIndex = (page - 1) * pageSize + 1
  local listIndex
  for listIndex = firstIndex, math.min(total, firstIndex + pageSize - 1) do
    local itemID = items[listIndex]
    local name, _, _, _, _, _, _, _, ninth, tenth = GetItemInfo(itemID)
    table.insert(rows, {
      itemID = itemID,
      name = name or ("Item " .. itemID),
      texture = tenth or ninth or "Interface\\Icons\\INV_Misc_QuestionMark",
      index = listIndex,
      canMoveTop = listIndex > 1,
      canMoveBottom = listIndex < total,
    })
  end
  return rows, page, pageCount, total
end

function ShirsInventory_GetStandaloneControlSpecs()
  return {
    {
      name = "sort", width = 18, height = 18,
      onClick = function() if ShirsInventory_OnSortButtonClick then return ShirsInventory_OnSortButtonClick(false) end end,
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
  frame:SetBackdropColor(0.012, 0.020, 0.035, 0.97)
  frame:SetBackdropBorderColor(0.22, 0.58, 0.95, 1)
  return frame
end

local function ShirsInventory_CreateSectionHeading(parent, label, y)
  local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
  heading:SetText(label)
  heading:SetTextColor(1, 0.78, 0.18)
  local rule = CreateFrame("Frame", nil, parent)
  rule:SetWidth(392)
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y - 17)
  rule:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
  rule:SetBackdropColor(0.18, 0.45, 0.72, 0.70)
  return heading, rule
end

local function ShirsInventory_UpdateCategoryImportControls(frame, resetConfirmation)
  if not frame or not frame.importSourceText then return false end
  local sources = frame.importSources or {}
  local count = table.getn(sources)
  if count == 0 then
    frame.importSourceIndex = 0
    frame.importSourceText:SetText("No other saved characters")
    if frame.importPrevious then frame.importPrevious:Disable() end
    if frame.importNext then frame.importNext:Disable() end
    if frame.importButton then frame.importButton:Disable() end
  else
    frame.importSourceIndex = math.max(1, math.min(count, frame.importSourceIndex or 1))
    frame.importSourceText:SetText(sources[frame.importSourceIndex].label)
    if frame.importPrevious then frame.importPrevious:Enable() end
    if frame.importNext then frame.importNext:Enable() end
    if frame.importButton then frame.importButton:Enable() end
  end
  if resetConfirmation then
    frame.importArmedRealm = nil
    frame.importArmedCharacter = nil
    if frame.importButton then frame.importButton:SetText("Import") end
    if frame.importStatus then frame.importStatus:SetText("") end
  end
  return true
end

function ShirsInventory_RefreshCategoryImportSources(frame)
  frame = frame or categoryManagerFrame
  if not frame then return false end
  local selected = frame.importSources and frame.importSources[frame.importSourceIndex or 0] or nil
  local currentRealm = ShirsInventory_AccountGetCurrentRealm and ShirsInventory_AccountGetCurrentRealm() or nil
  local currentCharacter = ShirsInventory_AccountGetCurrentCharacter and
    ShirsInventory_AccountGetCurrentCharacter() or nil
  frame.importSources = ShirsInventory_AccountGetCategoryImportSources and
    ShirsInventory_AccountGetCategoryImportSources(currentRealm, currentCharacter) or {}
  frame.importSourceIndex = 1
  if selected then
    local index
    for index = 1, table.getn(frame.importSources) do
      local source = frame.importSources[index]
      if source.realm == selected.realm and source.character == selected.character then
        frame.importSourceIndex = index
        break
      end
    end
  end
  return ShirsInventory_UpdateCategoryImportControls(frame, true)
end

function ShirsInventory_RefreshCategoryManager()
  if not categoryManagerFrame then return false end
  local categories = ShirsInventory_GetCustomCategories and ShirsInventory_GetCustomCategories() or {}
  categoryManagerFrame.countText:SetText(table.getn(categories) .. " / 12")
  if categoryManagerFrame.categoryGapSlider and ShirsInventory_GetCategoryGapSlots then
    local gap = ShirsInventory_GetCategoryGapSlots()
    categoryManagerFrame.categoryGapSlider:SetValue(gap)
    if categoryManagerFrame.categoryGapLabel then
      categoryManagerFrame.categoryGapLabel:SetText("Category gap: " .. gap .. " empty slot")
    end
  end
  local rowIndex
  for rowIndex = 1, table.getn(categoryManagerFrame.rows) do
    local row = categoryManagerFrame.rows[rowIndex]
    local category = categories[rowIndex]
    if category then
      row.categoryKey = category.key
      row.label:SetText(category.label)
      row:Show()
    else
      row.categoryKey = nil
      row:Hide()
    end
  end
  if table.getn(categories) == 0 then categoryManagerFrame.emptyText:Show() else categoryManagerFrame.emptyText:Hide() end
  ShirsInventory_RefreshCategoryImportSources(categoryManagerFrame)
  return true
end

function ShirsInventory_PositionCategoryManager(frame)
  if not frame then return false end
  frame:ClearAllPoints()
  local saved = ShirsInventory_GetCategorySettingsPosition and
    ShirsInventory_GetCategorySettingsPosition() or nil
  if saved then
    frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
  elseif ShirsInventoryFrame and ShirsInventoryFrame.sortButton then
    frame:SetPoint("TOPRIGHT", ShirsInventoryFrame.sortButton, "BOTTOMRIGHT", 0, -8)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
  end
  return true
end

function ShirsInventory_OnCategorySettingsDragStop(frame)
  if not frame then return false end
  if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
  if not ShirsInventory_SaveCategorySettingsFramePosition or
    not ShirsInventory_SaveCategorySettingsFramePosition(frame) then
    return false
  end
  return ShirsInventory_PositionCategoryManager(frame)
end

local function ShirsInventory_CreateCategoryManager()
  local frame = ShirsInventory_CreatePanel("ShirsInventoryCategoryManagerFrame", 440, 680, "DIALOG")
  categoryManagerFrame = frame
  ShirsInventory_PositionCategoryManager(frame)
  frame:SetScript("OnDragStop", function() ShirsInventory_OnCategorySettingsDragStop(frame) end)
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", frame, "TOP", 0, -18)
  frame.title:SetText("Category settings")
  frame.help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.help:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -45)
  frame.help:SetWidth(392)
  frame.help:SetHeight(34)
  frame.help:SetJustifyH("LEFT")
  frame.help:SetJustifyV("TOP")
  frame.help:SetTextColor(0.68, 0.74, 0.84)
  frame.help:SetText("Manage visual categories and how Category View displays carried inventory.")

  frame.customCategoriesHeading, frame.customCategoriesRule =
    ShirsInventory_CreateSectionHeading(frame, "CUSTOM CATEGORIES", -83)

  frame.nameInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  frame.nameInput:SetWidth(280)
  frame.nameInput:SetHeight(24)
  frame.nameInput:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -111)
  frame.nameInput:SetAutoFocus(false)
  frame.nameInput:SetMaxLetters(28)
  frame.create = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.create:SetWidth(96)
  frame.create:SetHeight(24)
  frame.create:SetPoint("LEFT", frame.nameInput, "RIGHT", 12, 0)
  frame.create:SetText("Create")
  frame.errorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.errorText:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -140)
  frame.errorText:SetWidth(392)
  frame.errorText:SetHeight(16)
  frame.errorText:SetJustifyH("LEFT")
  frame.errorText:SetTextColor(1, 0.35, 0.35)
  local function CreateCategoryFromInput()
    local key, reason = ShirsInventory_CreateCustomCategory(frame.nameInput:GetText())
    if key then
      frame.nameInput:SetText("")
      frame.errorText:SetText("")
      ShirsInventory_RefreshCategoryManager()
      if ShirsInventory_Update then ShirsInventory_Update() end
    elseif reason == "duplicate" then
      frame.errorText:SetText("That category already exists.")
    elseif reason == "full" then
      frame.errorText:SetText("The 12-category limit is full.")
    else
      frame.errorText:SetText("Enter a name from 1 to 28 characters.")
    end
  end
  frame.create:SetScript("OnClick", CreateCategoryFromInput)
  frame.nameInput:SetScript("OnEnterPressed", CreateCategoryFromInput)

  frame.rows = {}
  local rowIndex
  for rowIndex = 1, 12 do
    local row = CreateFrame("Frame", nil, frame)
    row:SetWidth(392)
    row:SetHeight(26)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -158 - ((rowIndex - 1) * 28))
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.label:SetWidth(288)
    row.label:SetHeight(24)
    row.label:SetJustifyH("LEFT")
    row.delete = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.delete:SetWidth(82)
    row.delete:SetHeight(22)
    row.delete:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.delete.row = row
    row.delete:SetText("Delete")
    row.delete:SetScript("OnClick", function()
      local targetRow = this.row
      if targetRow and targetRow.categoryKey and ShirsInventory_DeleteCustomCategory(targetRow.categoryKey) then
        ShirsInventory_RefreshCategoryManager()
        if ShirsInventory_Update then ShirsInventory_Update() end
      end
    end)
    table.insert(frame.rows, row)
  end
  frame.emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  frame.emptyText:SetPoint("TOP", frame, "TOP", 0, -282)
  frame.emptyText:SetText("No custom categories yet.")
  frame.displayHeading, frame.displayRule =
    ShirsInventory_CreateSectionHeading(frame, "DISPLAY", -505)
  frame.categoryGapLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.categoryGapLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -531)
  frame.categoryGapLabel:SetWidth(392)
  frame.categoryGapLabel:SetHeight(16)
  frame.categoryGapLabel:SetJustifyH("LEFT")
  frame.categoryGapSlider = CreateFrame("Slider", "ShirsInventoryCategoryGapSlider", frame, "OptionsSliderTemplate")
  frame.categoryGapSlider:SetWidth(240)
  frame.categoryGapSlider:SetHeight(16)
  frame.categoryGapSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -548)
  frame.categoryGapSlider:SetMinMaxValues(0, 1)
  frame.categoryGapSlider:SetValueStep(1)
  local categoryGapLow = getglobal and getglobal("ShirsInventoryCategoryGapSliderLow") or nil
  local categoryGapHigh = getglobal and getglobal("ShirsInventoryCategoryGapSliderHigh") or nil
  if categoryGapLow and categoryGapLow.SetText then categoryGapLow:SetText("0") end
  if categoryGapHigh and categoryGapHigh.SetText then categoryGapHigh:SetText("1") end
  frame.categoryGapSlider:SetScript("OnValueChanged", function()
    local applied = ShirsInventory_SetCategoryGapSlots(this:GetValue())
    if frame.categoryGapLabel then
      frame.categoryGapLabel:SetText("Category gap: " .. applied .. " empty slot")
    end
    if ShirsInventory_Update then ShirsInventory_Update() end
  end)

  frame.importHeading, frame.importRule =
    ShirsInventory_CreateSectionHeading(frame, "IMPORT FROM CHARACTER", -575)
  frame.importPrevious = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.importPrevious:SetWidth(28)
  frame.importPrevious:SetHeight(24)
  frame.importPrevious:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -603)
  frame.importPrevious:SetText("<")
  frame.importSourceText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.importSourceText:SetPoint("LEFT", frame.importPrevious, "RIGHT", 8, 0)
  frame.importSourceText:SetWidth(220)
  frame.importSourceText:SetHeight(24)
  frame.importSourceText:SetJustifyH("LEFT")
  frame.importNext = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.importNext:SetWidth(28)
  frame.importNext:SetHeight(24)
  frame.importNext:SetPoint("LEFT", frame.importSourceText, "RIGHT", 8, 0)
  frame.importNext:SetText(">")
  frame.importButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.importButton:SetWidth(86)
  frame.importButton:SetHeight(24)
  frame.importButton:SetPoint("LEFT", frame.importNext, "RIGHT", 8, 0)
  frame.importButton:SetText("Import")
  frame.importStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.importStatus:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 16)
  frame.importStatus:SetWidth(280)
  frame.importStatus:SetHeight(24)
  frame.importStatus:SetJustifyH("LEFT")
  frame.importStatus:SetTextColor(0.68, 0.74, 0.84)

  local function ChangeImportSource(step)
    local count = table.getn(frame.importSources or {})
    if count == 0 then return end
    frame.importSourceIndex = frame.importSourceIndex + step
    if frame.importSourceIndex < 1 then frame.importSourceIndex = count end
    if frame.importSourceIndex > count then frame.importSourceIndex = 1 end
    ShirsInventory_UpdateCategoryImportControls(frame, true)
  end
  frame.importPrevious:SetScript("OnClick", function() ChangeImportSource(-1) end)
  frame.importNext:SetScript("OnClick", function() ChangeImportSource(1) end)
  frame.importButton:SetScript("OnClick", function()
    local source = frame.importSources and frame.importSources[frame.importSourceIndex or 0] or nil
    if not source then return end
    if frame.importArmedRealm == source.realm and frame.importArmedCharacter == source.character then
      local label = source.label
      frame.importArmedRealm, frame.importArmedCharacter = nil, nil
      frame.importButton:SetText("Import")
      if ShirsInventory_AccountImportCategorySettings and
        ShirsInventory_AccountImportCategorySettings(source.realm, source.character) then
        ShirsInventory_RefreshCategoryManager()
        frame.importStatus:SetText("Imported category settings from " .. label .. ".")
        if ShirsInventory_Update then ShirsInventory_Update() end
      else
        frame.importStatus:SetText("Import failed; current settings were not changed.")
      end
    else
      frame.importArmedRealm = source.realm
      frame.importArmedCharacter = source.character
      frame.importButton:SetText("Confirm")
      frame.importStatus:SetText("Click Confirm to replace this character's category settings.")
    end
  end)

  frame.countText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.countText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -82)
  frame.close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.close:SetWidth(90)
  frame.close:SetHeight(24)
  frame.close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 16)
  frame.close:SetText("Close")
  frame.close:SetScript("OnClick", function() frame:Hide() end)
  frame:SetScript("OnHide", function()
    if frame.nameInput.ClearFocus then frame.nameInput:ClearFocus() end
    ShirsInventory_UpdateCategoryImportControls(frame, true)
  end)
  frame:Hide()
  table.insert(UISpecialFrames, "ShirsInventoryCategoryManagerFrame")
  return frame
end

function ShirsInventory_ShowCategoryManager()
  if ShirsInventory_ClearCategoryEditDrag then ShirsInventory_ClearCategoryEditDrag() end
  if not categoryManagerFrame then ShirsInventory_CreateCategoryManager() end
  ShirsInventory_PositionCategoryManager(categoryManagerFrame)
  ShirsInventory_RefreshCategoryManager()
  categoryManagerFrame:Show()
  return true
end

function ShirsInventory_ToggleCategoryManager()
  if categoryManagerFrame and categoryManagerFrame:IsShown() then
    categoryManagerFrame:Hide()
    return true
  end
  return ShirsInventory_ShowCategoryManager()
end

local function ShirsInventory_RefreshHearthstoneManagerButton()
  if settingsFrame and settingsFrame.hearthstoneItemsButton then
    settingsFrame.hearthstoneItemsButton:SetText(
      "Manage selected item list (" .. ShirsInventory_GetHearthstoneItemCount() .. ")"
    )
  end
end

local function ShirsInventory_ClearHearthstoneDrag()
  hearthstoneDraggedItemID = nil
  if not hearthstoneItemsFrame or not hearthstoneItemsFrame.rows then return end
  local rowIndex
  for rowIndex = 1, table.getn(hearthstoneItemsFrame.rows) do
    local row = hearthstoneItemsFrame.rows[rowIndex]
    if row.dragHighlight then row.dragHighlight:Hide() end
  end
end

local function ShirsInventory_StopHearthstoneItemDrag()
  local sourceItemID = hearthstoneDraggedItemID
  local focus = GetMouseFocus and GetMouseFocus() or nil
  local targetRow = focus and focus.hearthstoneRow or nil
  ShirsInventory_ClearHearthstoneDrag()
  if sourceItemID and targetRow and targetRow.itemID then
    ShirsInventory_MoveHearthstoneItemToItem(sourceItemID, targetRow.itemID)
  end
  ShirsInventory_RefreshHearthstoneItemsFrame()
end

function ShirsInventory_RefreshHearthstoneItemsFrame()
  ShirsInventory_RefreshHearthstoneManagerButton()
  ShirsInventory_ClearHearthstoneDrag()
  if not hearthstoneItemsFrame then return end
  local rows, page, pageCount, total = ShirsInventory_GetHearthstoneItemDisplayRows(
    hearthstoneItemsPage, SHIRS_INVENTORY_HEARTHSTONE_ROWS_PER_PAGE
  )
  hearthstoneItemsPage = page
  hearthstoneItemsFrame.pageText:SetText("Page " .. page .. " / " .. pageCount)
  if total == 0 then
    hearthstoneItemsFrame.emptyText:Show()
  else
    hearthstoneItemsFrame.emptyText:Hide()
  end
  local rowIndex
  for rowIndex = 1, SHIRS_INVENTORY_HEARTHSTONE_ROWS_PER_PAGE do
    local row = hearthstoneItemsFrame.rows[rowIndex]
    local data = rows[rowIndex]
    if data then
      row.itemID = data.itemID
      row.icon:SetTexture(data.texture)
      row.name:SetText(data.name .. "  |cff777777#" .. data.itemID .. "|r")
      if data.canMoveTop then row.top:Enable() else row.top:Disable() end
      if data.canMoveBottom then row.bottom:Enable() else row.bottom:Disable() end
      row:Show()
    else
      row.itemID = nil
      row:Hide()
    end
  end
  if page > 1 then hearthstoneItemsFrame.previous:Enable() else hearthstoneItemsFrame.previous:Disable() end
  if page < pageCount then hearthstoneItemsFrame.next:Enable() else hearthstoneItemsFrame.next:Disable() end
end

local function ShirsInventory_CreateHearthstoneItemsFrame()
  local frame = ShirsInventory_CreatePanel("ShirsInventoryHearthstoneItemsFrame", 440, 470, "DIALOG")
  hearthstoneItemsFrame = frame
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", frame, "TOP", 0, -18)
  frame.title:SetText("Selected item list")
  frame.help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.help:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -46)
  frame.help:SetWidth(392)
  frame.help:SetHeight(30)
  frame.help:SetJustifyH("LEFT")
  frame.help:SetJustifyV("TOP")
  frame.help:SetTextColor(0.68, 0.74, 0.84)
  frame.help:SetText("Ctrl-right-click a carried item to add or remove it.\nDrag by the :: grip, or use Top/Bottom.")

  frame.selectedItemHeading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.selectedItemHeading:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -81)
  frame.selectedItemHeading:SetText("SELECTED ITEM")
  frame.selectedItemHeading:SetTextColor(1, 0.78, 0.18)
  frame.orderActionHeading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.orderActionHeading:SetPoint("TOPLEFT", frame, "TOPLEFT", 254, -81)
  frame.orderActionHeading:SetText("ORDER / ACTION")
  frame.orderActionHeading:SetTextColor(1, 0.78, 0.18)
  frame.columnRule = CreateFrame("Frame", nil, frame)
  frame.columnRule:SetWidth(392)
  frame.columnRule:SetHeight(1)
  frame.columnRule:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -97)
  frame.columnRule:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
  frame.columnRule:SetBackdropColor(0.18, 0.45, 0.72, 0.70)

  frame.rows = {}
  local rowIndex
  for rowIndex = 1, SHIRS_INVENTORY_HEARTHSTONE_ROWS_PER_PAGE do
    local row = CreateFrame("Frame", nil, frame)
    row:SetWidth(392)
    row:SetHeight(32)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -102 - ((rowIndex - 1) * 36))
    row:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    if math.mod(rowIndex, 2) == 0 then
      row:SetBackdropColor(0.05, 0.08, 0.13, 0.44)
    else
      row:SetBackdropColor(0.03, 0.05, 0.09, 0.34)
    end
    row.dragHighlight = row:CreateTexture(nil, "OVERLAY")
    row.dragHighlight:SetAllPoints(row)
    row.dragHighlight:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.dragHighlight:SetVertexColor(0.15, 0.5, 1, 0.22)
    row.dragHighlight:Hide()
    row.dragArea = CreateFrame("Button", nil, row)
    row.dragArea:SetWidth(222)
    row.dragArea:SetHeight(32)
    row.dragArea:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.dragArea:EnableMouse(true)
    row.dragArea:RegisterForDrag("LeftButton")
    row.dragArea.hearthstoneRow = row
    row.dragArea:SetScript("OnDragStart", function()
      local dragRow = this.hearthstoneRow
      if not dragRow or not dragRow.itemID then return end
      ShirsInventory_ClearHearthstoneDrag()
      hearthstoneDraggedItemID = dragRow.itemID
      dragRow.dragHighlight:SetVertexColor(0.15, 0.5, 1, 0.28)
      dragRow.dragHighlight:Show()
    end)
    row.dragArea:SetScript("OnDragStop", function()
      ShirsInventory_StopHearthstoneItemDrag()
    end)
    row.dragArea:SetScript("OnEnter", function()
      local dragRow = this.hearthstoneRow
      if hearthstoneDraggedItemID and dragRow and dragRow.itemID and
        dragRow.itemID ~= hearthstoneDraggedItemID then
        dragRow.dragHighlight:SetVertexColor(1, 0.78, 0.18, 0.28)
        dragRow.dragHighlight:Show()
      end
    end)
    row.dragArea:SetScript("OnLeave", function()
      local dragRow = this.hearthstoneRow
      if dragRow and dragRow.itemID ~= hearthstoneDraggedItemID then
        dragRow.dragHighlight:Hide()
      end
    end)
    row.grip = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.grip:SetWidth(18)
    row.grip:SetHeight(32)
    row.grip:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.grip:SetJustifyH("CENTER")
    row.grip:SetTextColor(0.35, 0.68, 1)
    row.grip:SetText("::")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(28)
    row.icon:SetHeight(28)
    row.icon:SetPoint("LEFT", row, "LEFT", 20, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row, "LEFT", 56, 0)
    row.name:SetWidth(166)
    row.name:SetHeight(30)
    row.name:SetJustifyH("LEFT")
    row.name:SetJustifyV("MIDDLE")

    row.top = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.top:SetWidth(48)
    row.top:SetHeight(24)
    row.top:SetPoint("LEFT", row, "LEFT", 230, 0)
    row.top:SetText("Top")
    row.top.row = row
    row.top:SetScript("OnClick", function()
      if this.row.itemID then ShirsInventory_MoveHearthstoneItemToEdge(this.row.itemID, "top") end
      ShirsInventory_RefreshHearthstoneItemsFrame()
    end)

    row.bottom = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.bottom:SetWidth(58)
    row.bottom:SetHeight(24)
    row.bottom:SetPoint("LEFT", row, "LEFT", 282, 0)
    row.bottom:SetText("Bottom")
    row.bottom.row = row
    row.bottom:SetScript("OnClick", function()
      if this.row.itemID then ShirsInventory_MoveHearthstoneItemToEdge(this.row.itemID, "bottom") end
      ShirsInventory_RefreshHearthstoneItemsFrame()
    end)

    row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.remove:SetWidth(68)
    row.remove:SetHeight(24)
    row.remove:SetPoint("LEFT", row, "LEFT", 344, 0)
    row.remove:SetText("Remove")
    row.remove.row = row
    row.remove:SetScript("OnClick", function()
      if this.row.itemID then ShirsInventory_SetHearthstoneItem(this.row.itemID, false) end
      ShirsInventory_RefreshHearthstoneItemsFrame()
    end)
    table.insert(frame.rows, row)
  end

  frame.emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  frame.emptyText:SetPoint("TOP", frame, "TOP", 0, -226)
  frame.emptyText:SetWidth(392)
  frame.emptyText:SetHeight(20)
  frame.emptyText:SetJustifyH("CENTER")
  frame.emptyText:SetText("No items selected yet.")

  frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.pageText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 61)
  frame.pageText:SetWidth(90)
  frame.pageText:SetHeight(14)
  frame.pageText:SetJustifyH("CENTER")
  frame.previous = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.previous:SetWidth(46)
  frame.previous:SetHeight(22)
  frame.previous:SetPoint("RIGHT", frame.pageText, "LEFT", -10, 0)
  frame.previous:SetText("<")
  frame.previous:SetScript("OnClick", function()
    hearthstoneItemsPage = hearthstoneItemsPage - 1
    ShirsInventory_RefreshHearthstoneItemsFrame()
  end)
  frame.next = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.next:SetWidth(46)
  frame.next:SetHeight(22)
  frame.next:SetPoint("LEFT", frame.pageText, "RIGHT", 10, 0)
  frame.next:SetText(">")
  frame.next:SetScript("OnClick", function()
    hearthstoneItemsPage = hearthstoneItemsPage + 1
    ShirsInventory_RefreshHearthstoneItemsFrame()
  end)

  frame.clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.clear:SetWidth(90)
  frame.clear:SetHeight(24)
  frame.clear:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 16)
  frame.clear:SetText("Clear All")
  frame.clear:SetScript("OnClick", function()
    ShirsInventory_ClearHearthstoneItems()
    hearthstoneItemsPage = 1
    ShirsInventory_RefreshHearthstoneItemsFrame()
  end)
  frame.close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.close:SetWidth(90)
  frame.close:SetHeight(24)
  frame.close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 16)
  frame.close:SetText("Close")
  frame.close:SetScript("OnClick", function() frame:Hide() end)
  frame:SetScript("OnHide", function() ShirsInventory_ClearHearthstoneDrag() end)
  frame:Hide()
  table.insert(UISpecialFrames, "ShirsInventoryHearthstoneItemsFrame")
  return frame
end

function ShirsInventory_ShowHearthstoneItems()
  if not hearthstoneItemsFrame then ShirsInventory_CreateHearthstoneItemsFrame() end
  hearthstoneItemsPage = 1
  ShirsInventory_RefreshHearthstoneItemsFrame()
  hearthstoneItemsFrame:Show()
  return hearthstoneItemsFrame
end

local function ShirsInventory_CreateFeatureCheck(parent, label, feature, y)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetWidth(24)
  check:SetHeight(24)
  check:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
  check.feature = feature
  check.label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  check.label:SetPoint("LEFT", check, "RIGHT", 6, 0)
  check.label:SetWidth(362)
  check.label:SetHeight(28)
  check.label:SetJustifyH("LEFT")
  check.label:SetJustifyV("MIDDLE")
  check.label:SetTextColor(0.95, 0.96, 1)
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
  settingsFrame.showRecipeGlow:SetChecked(ShirsInventory_GetShowRecipeGlow() and 1 or nil)
  settingsFrame.useCoinIcons:SetChecked(ShirsInventory_GetUseCoinIcons() and 1 or nil)
  settingsFrame.hideItemOwnershipInCombat:SetChecked(
    ShirsInventory_GetHideItemOwnershipInCombat() and 1 or nil
  )
  settingsFrame.autoClearSearch:SetChecked(ShirsInventory_GetAutoClearSearch() and 1 or nil)
  settingsFrame.automaticHearthstoneItems:SetChecked(
    ShirsInventory_GetAutomaticHearthstoneItems() and 1 or nil
  )
  settingsFrame.lockSelectedItemSlots:SetChecked(
    ShirsInventory_GetLockSelectedItemSlots() and 1 or nil
  )
  settingsFrame.categoryMode:SetChecked(ShirsInventory_GetCategoryMode() and 1 or nil)
  ShirsInventory_RefreshHearthstoneManagerButton()
  refreshingSettings = true
  settingsFrame.itemsPerRowSlider:SetValue(ShirsInventory_GetItemsPerRow())
  settingsFrame.windowScaleSlider:SetValue(ShirsInventory_GetWindowScale())
  settingsFrame.itemsPerRowSliderText:SetText("Items per row: " .. ShirsInventory_GetItemsPerRow())
  settingsFrame.windowScaleSliderText:SetText(
    "Window scale: " .. math.floor(ShirsInventory_GetWindowScale() * 100 + 0.5) .. "%"
  )
  if settingsFrame.backgroundAlphaSlider then
    settingsFrame.backgroundAlphaSlider:SetValue(ShirsInventory_GetBackgroundAlpha())
    settingsFrame.backgroundAlphaSliderText:SetText(
      "Background opacity: " .. math.floor(ShirsInventory_GetBackgroundAlpha() * 100 + 0.5) .. "%"
    )
  end
  if settingsFrame.frameStrataButton then
    settingsFrame.frameStrataButton:SetText("Frame layer: " .. ShirsInventory_GetFrameStrata())
  end
  if settingsFrame.categoryBankOnly then
    settingsFrame.categoryBankOnly:SetChecked(ShirsInventory_GetCategoryBankOnly() and 1 or nil)
  end
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
  frame.itemsPerRowSlider:SetWidth(320)
  frame.itemsPerRowSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -529)
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
  frame.windowScaleSlider:SetWidth(320)
  frame.windowScaleSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -572)
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

local SHIRS_INVENTORY_FRAME_STRATA_ORDER = { "LOW", "MEDIUM", "HIGH", "DIALOG", "TOOLTIP" }

function ShirsInventory_CreateAppearanceControls(frame)
  if not frame or not CreateFrame then return false end
  frame.appearanceHeading, frame.appearanceRule = ShirsInventory_CreateSectionHeading(
    frame, "WINDOW APPEARANCE", -614
  )

  frame.backgroundAlphaSlider = CreateFrame(
    "Slider", "ShirsInventoryBackgroundAlphaSlider", frame, "OptionsSliderTemplate"
  )
  frame.backgroundAlphaSlider:SetWidth(320)
  frame.backgroundAlphaSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -643)
  frame.backgroundAlphaSlider:SetMinMaxValues(0.2, 1)
  frame.backgroundAlphaSlider:SetValueStep(0.05)
  frame.backgroundAlphaSliderText = getglobal("ShirsInventoryBackgroundAlphaSliderText")
  getglobal("ShirsInventoryBackgroundAlphaSliderLow"):SetText("20%")
  getglobal("ShirsInventoryBackgroundAlphaSliderHigh"):SetText("100%")
  frame.backgroundAlphaSlider:SetScript("OnValueChanged", function()
    if refreshingSettings then return end
    ShirsInventory_SetBackgroundAlpha(this:GetValue())
    if type(ShirsInventory_ApplyAppearanceSettings) == "function" then
      ShirsInventory_ApplyAppearanceSettings()
    end
    frame.backgroundAlphaSliderText:SetText(
      "Background opacity: " .. math.floor(ShirsInventory_GetBackgroundAlpha() * 100 + 0.5) .. "%"
    )
  end)

  frame.frameStrataButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.frameStrataButton:SetWidth(300)
  frame.frameStrataButton:SetHeight(24)
  frame.frameStrataButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -686)
  frame.frameStrataButton:SetText("Frame layer: " .. ShirsInventory_GetFrameStrata())
  frame.frameStrataButton:SetScript("OnClick", function()
    local current = ShirsInventory_GetFrameStrata()
    local order = SHIRS_INVENTORY_FRAME_STRATA_ORDER
    local index = 1
    while index <= table.getn(order) and order[index] ~= current do index = index + 1 end
    if index > table.getn(order) then index = 1 end
    local nextValue = order[math.mod(index, table.getn(order)) + 1]
    ShirsInventory_SetFrameStrata(nextValue)
    if type(ShirsInventory_ApplyAppearanceSettings) == "function" then
      ShirsInventory_ApplyAppearanceSettings()
    end
    frame.frameStrataButton:SetText("Frame layer: " .. ShirsInventory_GetFrameStrata())
    ShirsInventory_RefreshSettings()
  end)

  frame.categoryBankOnly = ShirsInventory_CreateFeatureCheck(
    frame, "Use category view for the bank only", "categoryBankOnly", -715
  )
  frame.categoryBankOnly:SetScript("OnClick", function()
    ShirsInventory_SetCategoryBankOnly(this:GetChecked() and true or false)
    if ShirsInventoryFrame and ShirsInventoryFrame.IsShown and ShirsInventoryFrame:IsShown() and
      type(ShirsInventory_Update) == "function" then
      ShirsInventory_Update()
    end
    if ShirsInventoryBankFrame and ShirsInventoryBankFrame.IsShown and ShirsInventoryBankFrame:IsShown() and
      type(ShirsInventory_UpdateBank) == "function" then
      ShirsInventory_UpdateBank(ShirsInventoryBankFrame)
    end
    if type(ShirsInventory_RefreshBankButtonStyles) == "function" then
      ShirsInventory_RefreshBankButtonStyles()
    end
    if type(ShirsInventory_UpdateControlLabels) == "function" then
      ShirsInventory_UpdateControlLabels()
    end
    ShirsInventory_RefreshSettings()
  end)
  return true
end

local function ShirsInventory_CreateSettingsFrame()
  local frame = ShirsInventory_CreatePanel("ShirsInventorySettingsFrame", 440, 790, "DIALOG")
  settingsFrame = frame
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", frame, "TOP", 0, -18)
  frame.title:SetText("Shir's Inventory Settings")
  frame.help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.help:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -46)
  frame.help:SetWidth(392)
  frame.help:SetHeight(30)
  frame.help:SetJustifyH("LEFT")
  frame.help:SetJustifyV("TOP")
  frame.help:SetTextColor(0.68, 0.74, 0.84)
  frame.help:SetText("Standard mode includes sorting tools. Category view groups slots visually without moving items. Settings are saved per character.")

  frame.behaviorHeading, frame.behaviorRule = ShirsInventory_CreateSectionHeading(frame, "BEHAVIOR", -82)
  frame.itemsHeading, frame.itemsRule = ShirsInventory_CreateSectionHeading(frame, "ITEMS & DISPLAY", -228)
  frame.layoutHeading, frame.layoutRule = ShirsInventory_CreateSectionHeading(frame, "WINDOW LAYOUT", -500)

  frame.ignoreJunkSorting = ShirsInventory_CreateFeatureCheck(
    frame, "Ignore gray + manually marked junk while sorting", "ignoreJunkSorting", -107
  )
  frame.questItemsOppositeEdge = ShirsInventory_CreateFeatureCheck(
    frame, "Keep quest items at the opposite end of sorted items", "questItemsOppositeEdge", -136
  )
  frame.autoSellJunk = ShirsInventory_CreateFeatureCheck(
    frame, "Auto-sell gray + manually marked items at vendors", "autoSellJunk", -165
  )
  frame.autoClearSearch = ShirsInventory_CreateFeatureCheck(
    frame, "Clear search when inventory or bank closes, or you click outside", "autoClearSearch", -194
  )
  frame.showRarityBoxes = ShirsInventory_CreateFeatureCheck(
    frame, "Show quest and rarity borders on items", "showRarityBoxes", -253
  )
  frame.showRecipeGlow = ShirsInventory_CreateFeatureCheck(
    frame, "Glow recipes you already know or cannot learn yet", "showRecipeGlow", -282
  )
  frame.useCoinIcons = ShirsInventory_CreateFeatureCheck(
    frame, "Use coin icons for currency (off = g/s/c text)", "useCoinIcons", -311
  )
  frame.hideItemOwnershipInCombat = ShirsInventory_CreateFeatureCheck(
    frame, "Hide item ownership details while in combat", "hideItemOwnershipInCombat", -340
  )
  frame.automaticHearthstoneItems = ShirsInventory_CreateFeatureCheck(
    frame, "Hearthstone mode: Automatic (off = selected list)", "automaticHearthstoneItems", -369
  )
  frame.lockSelectedItemSlots = ShirsInventory_CreateFeatureCheck(
    frame, "Lock selected item slots while sorting (bags only)", "lockSelectedItemSlots", -398
  )
  frame.hearthstoneItemsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.hearthstoneItemsButton:SetWidth(300)
  frame.hearthstoneItemsButton:SetHeight(24)
  frame.hearthstoneItemsButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -430)
  frame.hearthstoneItemsButton:SetText("Manage selected item list (0)")
  frame.categoryMode = ShirsInventory_CreateFeatureCheck(
    frame, "Use category view (reloads UI; bag sorting is disabled)", "categoryMode", -459
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
  frame.showRecipeGlow:SetScript("OnClick", function()
    ShirsInventory_SetShowRecipeGlow(this:GetChecked() and true or false)
    if type(ShirsInventory_RefreshRarityBoxes) == "function" then ShirsInventory_RefreshRarityBoxes() end
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
  frame.autoClearSearch:SetScript("OnClick", function()
    ShirsInventory_SetAutoClearSearch(this:GetChecked() and true or false)
    ShirsInventory_RefreshSettings()
  end)
  frame.automaticHearthstoneItems:SetScript("OnClick", function()
    ShirsInventory_SetAutomaticHearthstoneItems(this:GetChecked() and true or false)
    ShirsInventory_RefreshSettings()
  end)
  frame.lockSelectedItemSlots:SetScript("OnClick", function()
    ShirsInventory_SetLockSelectedItemSlots(this:GetChecked() and true or false)
    ShirsInventory_RefreshSettings()
  end)
  frame.categoryMode:SetScript("OnClick", function()
    ShirsInventory_SetCategoryModeAndReload(this:GetChecked() and true or false)
    ShirsInventory_RefreshSettings()
  end)
  frame.hearthstoneItemsButton:SetScript("OnClick", function()
    ShirsInventory_ShowHearthstoneItems()
  end)

  ShirsInventory_CreateLayoutSliders(frame)
  ShirsInventory_CreateAppearanceControls(frame)

  frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.closeButton:SetWidth(96)
  frame.closeButton:SetHeight(24)
  frame.closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
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
