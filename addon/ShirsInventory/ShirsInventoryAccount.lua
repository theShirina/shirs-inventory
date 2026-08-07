-- Shir's Inventory - account-wide gold tracking.
--
-- Original clean-room implementation for Vanilla WoW 1.12.1 (Lua 5.0.3).
-- The per-character saved variable ShirsInventoryDB cannot hold account
-- data, so this module persists every character's copper on this
-- account+server in the separate account-wide saved variable
-- ShirsInventoryAccountDB, keyed by realm name and then character name.
--
-- Saved variable shape:
--   ShirsInventoryAccountDB = {
--     version = 1,
--     realms = {
--       ["RealmName"] = {
--         ["CharacterName"] = 1234567, -- copper
--       },
--     },
--   }
--
-- The current character's entry is refreshed on PLAYER_LOGIN and on every
-- PLAYER_MONEY change. A compact gold readout is attached to the combined
-- inventory frame (ShirsInventoryFrame) and only appears while the full
-- suite bag UI feature (bagUI) is enabled; hovering it opens a tooltip
-- listing every known character on the realm with a running total.

function ShirsInventory_AccountEnsureDB()
  if type(ShirsInventoryAccountDB) ~= "table" then
    ShirsInventoryAccountDB = {}
  end
  if ShirsInventoryAccountDB.version == nil then
    ShirsInventoryAccountDB.version = 1
  end
  if type(ShirsInventoryAccountDB.realms) ~= "table" then
    ShirsInventoryAccountDB.realms = {}
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
  accountEvents:RegisterEvent("ADDON_LOADED")
  accountEvents:RegisterEvent("PLAYER_LOGIN")
  accountEvents:RegisterEvent("PLAYER_MONEY")
  accountEvents:RegisterEvent("BAG_UPDATE")
  accountEvents:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
      if arg1 == "ShirsInventory" then
        ShirsInventory_AccountAttachDisplay(ShirsInventoryFrame)
      end
    elseif event == "PLAYER_LOGIN" then
      ShirsInventory_AccountRecordCurrentGold()
      ShirsInventory_AccountAttachDisplay(ShirsInventoryFrame)
      ShirsInventory_AccountUpdateDisplay()
    elseif event == "PLAYER_MONEY" then
      ShirsInventory_AccountRecordCurrentGold()
      ShirsInventory_AccountUpdateDisplay()
    elseif event == "BAG_UPDATE" then
      ShirsInventory_AccountAttachDisplay(ShirsInventoryFrame)
      ShirsInventory_AccountUpdateDisplay()
    end
  end)
end
