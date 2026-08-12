-- Shir's Inventory - account-wide gold and item tracking.
--
-- Original clean-room implementation for Vanilla WoW 1.12.1 (Lua 5.0.3).
-- The per-character saved variable ShirsInventoryDB cannot hold account
-- data, so this module persists every character's copper and item totals on
-- this account+server in the separate account-wide saved variable
-- ShirsInventoryAccountDB, keyed by realm name and then character name.
--
-- Saved variable shape:
--   ShirsInventoryAccountDB = {
--     version = 2,
--     realms = {
--       ["RealmName"] = {
--         ["CharacterName"] = 1234567, -- copper
--       },
--     },
--     items = {
--       ["RealmName"] = {
--         ["CharacterName"] = {
--           bags = { [14342] = 6 },
--           bank = { [14342] = 12 },
--           bagsUpdated = 1234567890,
--           bankUpdated = 1234567890,
--         },
--       },
--     },
--   }
--
-- Gold refreshes on PLAYER_LOGIN and PLAYER_MONEY. Carried-item snapshots
-- refresh at login and on bag changes; bank snapshots refresh only while the
-- bank is open. Item tooltips show same-account totals by character. The
-- compact gold readout remains attached to the combined inventory frame.

function ShirsInventory_AccountEnsureDB()
  if type(ShirsInventoryAccountDB) ~= "table" then
    ShirsInventoryAccountDB = {}
  end
  if type(ShirsInventoryAccountDB.version) ~= "number" or ShirsInventoryAccountDB.version < 2 then
    ShirsInventoryAccountDB.version = 2
  end
  if type(ShirsInventoryAccountDB.realms) ~= "table" then
    ShirsInventoryAccountDB.realms = {}
  end
  if type(ShirsInventoryAccountDB.items) ~= "table" then
    ShirsInventoryAccountDB.items = {}
  end
  return ShirsInventoryAccountDB
end

-- The whole feature is gated on the full-suite bag UI option. Missing
-- gate API is treated as enabled, matching the rest of the addon.
function ShirsInventory_AccountIsEnabled()
  if not ShirsInventory_IsFeatureEnabled then
    return true
  end
  return ShirsInventory_IsFeatureEnabled("bagUI") and true or false
end

function ShirsInventory_AccountGetCurrentRealm()
  if type(GetRealmName) ~= "function" then
    return nil
  end
  local realm = GetRealmName()
  if type(realm) ~= "string" or realm == "" then
    return nil
  end
  return realm
end

function ShirsInventory_AccountGetCurrentCharacter()
  if type(UnitName) ~= "function" then
    return nil
  end
  local character = UnitName("player")
  if type(character) ~= "string" or character == "" then
    return nil
  end
  return character
end

local function ShirsInventory_AccountNow()
  if type(time) == "function" then return tonumber(time()) or 0 end
  return 0
end

local function ShirsInventory_AccountExtractItemID(link)
  if ShirsInventory_GetItemId then return ShirsInventory_GetItemId(link) end
  if type(link) ~= "string" then return nil end
  local _, _, rawItemID = string.find(link, "item:(%d+)")
  return tonumber(rawItemID)
end

local function ShirsInventory_AccountCountContainers(containers)
  local counts = {}
  if type(GetContainerNumSlots) ~= "function" or type(GetContainerItemLink) ~= "function" then
    return counts, 0
  end
  local _, container
  for _, container in ipairs(containers) do
    local keyring = ShirsInventory_GetKeyRingContainerID and
      ShirsInventory_GetKeyRingContainerID() or (KEYRING_CONTAINER or -2)
    local slots
    if container == keyring and ShirsInventory_GetKeyRingSize then
      slots = ShirsInventory_GetKeyRingSize()
    else
      slots = tonumber(GetContainerNumSlots(container)) or 0
    end
    local slot
    for slot = 1, slots do
      local itemID = ShirsInventory_AccountExtractItemID(GetContainerItemLink(container, slot))
      if itemID then
        local count = 1
        if type(GetContainerItemInfo) == "function" then
          local _, stackCount = GetContainerItemInfo(container, slot)
          count = tonumber(stackCount) or 1
        end
        if count > 0 then counts[itemID] = (counts[itemID] or 0) + count end
      end
    end
  end
  local distinct = 0
  local _
  for _ in pairs(counts) do distinct = distinct + 1 end
  return counts, distinct
end

function ShirsInventory_AccountGetCharacterItems(realm, character, create)
  local db = ShirsInventory_AccountEnsureDB()
  if type(realm) ~= "string" or realm == "" or type(character) ~= "string" or character == "" then
    return nil
  end
  if type(db.items[realm]) ~= "table" then
    if not create then return nil end
    db.items[realm] = {}
  end
  if type(db.items[realm][character]) ~= "table" then
    if not create then return nil end
    db.items[realm][character] = { bags = {}, bank = {} }
  end
  local record = db.items[realm][character]
  if type(record.bags) ~= "table" then record.bags = {} end
  if type(record.bank) ~= "table" then record.bank = {} end
  return record
end

function ShirsInventory_AccountScanBags()
  if not ShirsInventory_AccountIsEnabled() then return nil end
  local realm = ShirsInventory_AccountGetCurrentRealm()
  local character = ShirsInventory_AccountGetCurrentCharacter()
  if not realm or not character then return nil end
  local bagContainers = {0, 1, 2, 3, 4}
  local keyring = ShirsInventory_GetKeyRingContainerID and ShirsInventory_GetKeyRingContainerID() or (KEYRING_CONTAINER or -2)
  table.insert(bagContainers, keyring)
  local counts, distinct = ShirsInventory_AccountCountContainers(bagContainers)
  local record = ShirsInventory_AccountGetCharacterItems(realm, character, true)
  record.bags = counts
  record.bagsUpdated = ShirsInventory_AccountNow()
  return distinct
end

function ShirsInventory_AccountScanBank()
  if not ShirsInventory_AccountIsEnabled() then return nil end
  local realm = ShirsInventory_AccountGetCurrentRealm()
  local character = ShirsInventory_AccountGetCurrentCharacter()
  if not realm or not character then return nil end
  local containers = {BANK_CONTAINER or -1}
  local bankBagCount = tonumber(NUM_BANKBAGSLOTS) or 6
  local index
  for index = 1, bankBagCount do table.insert(containers, 4 + index) end
  local counts, distinct = ShirsInventory_AccountCountContainers(containers)
  local record = ShirsInventory_AccountGetCharacterItems(realm, character, true)
  record.bank = counts
  record.bankUpdated = ShirsInventory_AccountNow()
  return distinct
end

function ShirsInventory_AccountBuildItemTooltipLines(realm, itemID, currentCharacter)
  local lines = {}
  local total = 0
  itemID = tonumber(itemID)
  if not itemID then return lines, total end
  local db = ShirsInventory_AccountEnsureDB()
  local characters = db.items[realm]
  if type(characters) ~= "table" then return lines, total end
  local name, record
  for name, record in pairs(characters) do
    if type(name) == "string" and type(record) == "table" then
      local bags = type(record.bags) == "table" and tonumber(record.bags[itemID]) or 0
      local bank = type(record.bank) == "table" and tonumber(record.bank[itemID]) or 0
      bags = bags or 0
      bank = bank or 0
      if bags + bank > 0 then
        table.insert(lines, {
          name = name,
          bags = bags,
          bank = bank,
          total = bags + bank,
          current = type(currentCharacter) == "string" and name == currentCharacter,
          bankKnown = type(record.bankUpdated) == "number",
          bagsUpdated = record.bagsUpdated,
          bankUpdated = record.bankUpdated,
        })
        total = total + bags + bank
      end
    end
  end
  table.sort(lines, function(left, right)
    return string.lower(left.name) < string.lower(right.name)
  end)
  return lines, total
end

local function ShirsInventory_AccountFormatItemLocation(line)
  local parts = {}
  if line.bags > 0 then table.insert(parts, "Bags: " .. line.bags) end
  if line.bank > 0 then table.insert(parts, "Bank: " .. line.bank) end
  if not line.bankKnown then table.insert(parts, "Bank: not scanned") end
  return table.concat(parts, " | ")
end

function ShirsInventory_AccountAddItemTooltip(targetTooltip, itemID)
  if not targetTooltip or type(targetTooltip.AddLine) ~= "function" or
    type(targetTooltip.AddDoubleLine) ~= "function" then return false end
  local realm = ShirsInventory_AccountGetCurrentRealm()
  local currentCharacter = ShirsInventory_AccountGetCurrentCharacter()
  if not realm then return false end
  local lines, total = ShirsInventory_AccountBuildItemTooltipLines(realm, itemID, currentCharacter)
  if total <= 0 then return false end
  targetTooltip:AddLine(" ")
  targetTooltip:AddDoubleLine("Owned on this account", tostring(total), 0.3, 0.8, 1, 1, 0.82, 0)
  local _, line
  for _, line in ipairs(lines) do
    local label = line.name
    if line.current then label = label .. " (current)" end
    targetTooltip:AddDoubleLine(label, ShirsInventory_AccountFormatItemLocation(line), 1, 1, 1, 0.8, 0.8, 0.8)
  end
  return true
end

function ShirsInventory_AccountGetRealmGold(realm)
  local db = ShirsInventory_AccountEnsureDB()
  if type(realm) ~= "string" or realm == "" then
    return {}
  end
  local characters = db.realms[realm]
  if type(characters) ~= "table" then
    return {}
  end
  return characters
end

function ShirsInventory_AccountGetGold(realm, character)
  local characters = ShirsInventory_AccountGetRealmGold(realm)
  if type(character) ~= "string" or character == "" then
    return 0
  end
  local copper = characters[character]
  if type(copper) ~= "number" then
    return 0
  end
  return copper
end

-- Records the current character's copper. Returns the recorded amount,
-- or nil when the feature is gated off or identity is unavailable.
function ShirsInventory_AccountRecordCurrentGold()
  if not ShirsInventory_AccountIsEnabled() then
    return nil
  end
  local realm = ShirsInventory_AccountGetCurrentRealm()
  local character = ShirsInventory_AccountGetCurrentCharacter()
  if not realm or not character then
    return nil
  end
  local money = 0
  if type(GetMoney) == "function" then
    money = GetMoney() or 0
  end
  local db = ShirsInventory_AccountEnsureDB()
  if type(db.realms[realm]) ~= "table" then
    db.realms[realm] = {}
  end
  db.realms[realm][character] = money
  return money
end

function ShirsInventory_AccountGetRealmTotal(realm)
  local total = 0
  local _, copper
  for _, copper in pairs(ShirsInventory_AccountGetRealmGold(realm)) do
    if type(copper) == "number" then
      total = total + copper
    end
  end
  return total
end

-- Builds the tooltip content: one entry per known character on the realm,
-- sorted by name, with the current character flagged, plus the summed
-- total. Returns the line list and the total in copper.
function ShirsInventory_AccountBuildTooltipLines(realm, currentCharacter)
  local lines = {}
  local characters = ShirsInventory_AccountGetRealmGold(realm)
  local name, copper
  for name, copper in pairs(characters) do
    if type(name) == "string" and type(copper) == "number" then
      table.insert(lines, {
        name = name,
        copper = copper,
        current = (type(currentCharacter) == "string" and name == currentCharacter),
      })
    end
  end
  table.sort(lines, function(left, right)
    return string.lower(left.name) < string.lower(right.name)
  end)
  local total = 0
  local _, line
  for _, line in ipairs(lines) do
    total = total + line.copper
  end
  return lines, total
end

-- Compact gold formatting: 1234567 -> "123g 45s 67c". Leading empty units
-- are dropped (2345 -> "23s 45c", 45 -> "45c"); zero is "0c".
function ShirsInventory_AccountFormatGold(copper)
  copper = tonumber(copper) or 0
  if copper < 0 then
    copper = 0
  end
  local gold = math.floor(copper / 10000)
  local silver = math.floor(math.mod(copper, 10000) / 100)
  local bronze = math.mod(copper, 100)
  if gold > 0 then
    return gold .. "g " .. silver .. "s " .. bronze .. "c"
  elseif silver > 0 then
    return silver .. "s " .. bronze .. "c"
  end
  return bronze .. "c"
end

function ShirsInventory_GetCoinWidgetModel(copper)
  copper = tonumber(copper) or 0
  if copper < 0 then copper = 0 end
  local gold = math.floor(copper / 10000)
  local silver = math.floor(math.mod(copper, 10000) / 100)
  local bronze = math.mod(copper, 100)
  local goldText = tostring(gold)
  local silverText = tostring(silver)
  local copperText = tostring(bronze)
  return {
    gold = gold,
    silver = silver,
    copper = bronze,
    goldText = goldText,
    silverText = silverText,
    copperText = copperText,
    width = 52 + (string.len(goldText) + string.len(silverText) + string.len(copperText)) * 7,
    texture = "Interface\\MoneyFrame\\UI-MoneyIcons",
    goldTexCoord = {0, 0.25, 0, 1},
    silverTexCoord = {0.25, 0.5, 0, 1},
    copperTexCoord = {0.5, 0.75, 0, 1},
  }
end

-- Text formatting is reserved for chat and tooltips. The compact icon mode
-- uses real Texture regions because this Vanilla client prints inline |T tags.
function ShirsInventory_AccountFormatMoney(copper)
  return ShirsInventory_AccountFormatGold(copper)
end

-- Keeps the readout on the combined frame current. The display is a child
-- of ShirsInventoryFrame, so it can only ever be seen in full-suite mode;
-- the bagUI gate additionally hides it when the option is turned off.
function ShirsInventory_AccountUpdateDisplay()
  if not ShirsInventoryFrame then
    return
  end
  local button = ShirsInventoryFrame.shirsGoldButton
  if not button then
    return
  end
  if not ShirsInventory_AccountIsEnabled() then
    button:Hide()
    return
  end
  local realm = ShirsInventory_AccountGetCurrentRealm()
  local character = ShirsInventory_AccountGetCurrentCharacter()
  local copper = 0
  if realm and character then
    copper = ShirsInventory_AccountGetGold(realm, character)
  end
  local useIcons = ShirsInventory_GetUseCoinIcons and ShirsInventory_GetUseCoinIcons()
  local hasCoinWidget = button.coinGoldText and button.coinSilverText and button.coinCopperText
  if useIcons and hasCoinWidget then
    local model = ShirsInventory_GetCoinWidgetModel(copper)
    if button.goldText and button.goldText.Hide then button.goldText:Hide() end
    button.coinGoldText:SetText(model.goldText)
    button.coinSilverText:SetText(model.silverText)
    button.coinCopperText:SetText(model.copperText)
    local _, region
    for _, region in ipairs(button.coinRegions or {}) do region:Show() end
    if button.SetWidth then button:SetWidth(model.width) end
  else
    local text = ShirsInventory_AccountFormatGold(copper)
    local _, region
    for _, region in ipairs(button.coinRegions or {}) do region:Hide() end
    if button.goldText then
      button.goldText:SetText(text)
      if button.goldText.Show then button.goldText:Show() end
    end
    if button.SetWidth then button:SetWidth(12 + string.len(text) * 9) end
  end
  button:Show()
end

if CreateFrame then
  local function ShirsInventory_AccountRenderTooltip(button)
    local realm = ShirsInventory_AccountGetCurrentRealm()
    local currentCharacter = ShirsInventory_AccountGetCurrentCharacter()
    local lines, total = ShirsInventory_AccountBuildTooltipLines(realm, currentCharacter)
    if not GameTooltip then
      return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText("Gold on current realm", 1, 0.82, 0)
    local _, line
    for _, line in ipairs(lines) do
      if line.current then
        GameTooltip:AddDoubleLine(
          line.name .. " (current)",
          ShirsInventory_AccountFormatGold(line.copper),
          1, 0.82, 0,
          1, 0.82, 0
        )
      else
        GameTooltip:AddDoubleLine(
          line.name,
          ShirsInventory_AccountFormatGold(line.copper),
          1, 1, 1,
          1, 1, 1
        )
      end
    end
    if table.getn(lines) > 0 then
      GameTooltip:AddLine(" ")
    end
    GameTooltip:AddDoubleLine("Total", ShirsInventory_AccountFormatGold(total), 0.3, 0.55, 0.8, 1, 0.82, 0)
    GameTooltip:Show()
  end

  -- Shir's compact footer keeps money at the right; bags live in the header.
  local function ShirsInventory_AccountAttachDisplay(frame)
    if not frame or frame.shirsGoldButton then
      return
    end
    local button = CreateFrame("Button", "ShirsInventoryGoldButton", frame)
    button:SetHeight(16)
    button:SetWidth(60)
    button.goldText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.goldText:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    button.coinGoldText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.coinGoldText:SetPoint("LEFT", button, "LEFT", 2, 0)
    button.coinGoldIcon = button:CreateTexture(nil, "ARTWORK")
    button.coinGoldIcon:SetWidth(12)
    button.coinGoldIcon:SetHeight(12)
    button.coinGoldIcon:SetPoint("LEFT", button.coinGoldText, "RIGHT", 1, 0)
    local coinVisual = ShirsInventory_GetCoinWidgetModel(0)
    button.coinGoldIcon:SetTexture(coinVisual.texture)
    button.coinGoldIcon:SetTexCoord(coinVisual.goldTexCoord[1], coinVisual.goldTexCoord[2], coinVisual.goldTexCoord[3], coinVisual.goldTexCoord[4])
    button.coinSilverText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.coinSilverText:SetPoint("LEFT", button.coinGoldIcon, "RIGHT", 3, 0)
    button.coinSilverIcon = button:CreateTexture(nil, "ARTWORK")
    button.coinSilverIcon:SetWidth(12)
    button.coinSilverIcon:SetHeight(12)
    button.coinSilverIcon:SetPoint("LEFT", button.coinSilverText, "RIGHT", 1, 0)
    button.coinSilverIcon:SetTexture(coinVisual.texture)
    button.coinSilverIcon:SetTexCoord(coinVisual.silverTexCoord[1], coinVisual.silverTexCoord[2], coinVisual.silverTexCoord[3], coinVisual.silverTexCoord[4])
    button.coinCopperText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.coinCopperText:SetPoint("LEFT", button.coinSilverIcon, "RIGHT", 3, 0)
    button.coinCopperIcon = button:CreateTexture(nil, "ARTWORK")
    button.coinCopperIcon:SetWidth(12)
    button.coinCopperIcon:SetHeight(12)
    button.coinCopperIcon:SetPoint("LEFT", button.coinCopperText, "RIGHT", 1, 0)
    button.coinCopperIcon:SetTexture(coinVisual.texture)
    button.coinCopperIcon:SetTexCoord(coinVisual.copperTexCoord[1], coinVisual.copperTexCoord[2], coinVisual.copperTexCoord[3], coinVisual.copperTexCoord[4])
    button.coinRegions = {
      button.coinGoldText, button.coinGoldIcon,
      button.coinSilverText, button.coinSilverIcon,
      button.coinCopperText, button.coinCopperIcon,
    }
    button:SetScript("OnEnter", function()
      ShirsInventory_AccountRenderTooltip(this)
    end)
    button:SetScript("OnLeave", function()
      if GameTooltip then
        GameTooltip:Hide()
      end
    end)
    button:SetScript("OnUpdate", function()
      if GameTooltip and GameTooltip:IsOwned(this) then
        ShirsInventory_AccountRenderTooltip(this)
      end
    end)
    button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 18)
    frame.shirsGoldButton = button
    ShirsInventory_AccountUpdateDisplay()
  end

  local accountEvents = CreateFrame("Frame", "ShirsInventoryAccountEvents")
  local bankOpen = false
  accountEvents:RegisterEvent("ADDON_LOADED")
  accountEvents:RegisterEvent("PLAYER_LOGIN")
  accountEvents:RegisterEvent("PLAYER_MONEY")
  accountEvents:RegisterEvent("BAG_UPDATE")
  accountEvents:RegisterEvent("BANKFRAME_OPENED")
  accountEvents:RegisterEvent("BANKFRAME_CLOSED")
  accountEvents:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
  accountEvents:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
  accountEvents:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
      if arg1 == "ShirsInventory" then
        ShirsInventory_AccountAttachDisplay(ShirsInventoryFrame)
      end
    elseif event == "PLAYER_LOGIN" then
      ShirsInventory_AccountRecordCurrentGold()
      ShirsInventory_AccountScanBags()
      ShirsInventory_AccountAttachDisplay(ShirsInventoryFrame)
      ShirsInventory_AccountUpdateDisplay()
    elseif event == "PLAYER_MONEY" then
      ShirsInventory_AccountRecordCurrentGold()
      ShirsInventory_AccountUpdateDisplay()
    elseif event == "BAG_UPDATE" then
      local changedContainer = tonumber(arg1)
      local keyring = ShirsInventory_GetKeyRingContainerID and ShirsInventory_GetKeyRingContainerID() or (KEYRING_CONTAINER or -2)
      if changedContainer == nil or (changedContainer >= 0 and changedContainer <= 4) or changedContainer == keyring then
        ShirsInventory_AccountScanBags()
      end
      if bankOpen and (changedContainer == nil or changedContainer == (BANK_CONTAINER or -1) or changedContainer >= 5) then
        ShirsInventory_AccountScanBank()
      end
      ShirsInventory_AccountAttachDisplay(ShirsInventoryFrame)
      ShirsInventory_AccountUpdateDisplay()
    elseif event == "BANKFRAME_OPENED" then
      bankOpen = true
      ShirsInventory_AccountScanBank()
    elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
      if bankOpen then ShirsInventory_AccountScanBank() end
    elseif event == "BANKFRAME_CLOSED" then
      bankOpen = false
    end
  end)
end
