-- Regression suite for account-wide gold tracking (ShirsInventoryAccount.lua).
-- Runs under Lua 5.0.3 with the addon's Core loaded for the feature gate.

local corePath, accountPath = arg[1], arg[2]

-- Per-character DB preset so the Core feature gate works without any UI.
ShirsInventoryDB = {
  setupComplete = true,
  features = { bagUI = true, sorter = false, junk = false },
  junkItems = {},
}

local currentRealm = "TestRealm"
local currentCharacter = "Altsmith"
local currentMoney = 1234567

function UnitName(unit)
  assert(unit == "player", "only the player unit is stubbed")
  return currentCharacter
end

function GetRealmName()
  return currentRealm
end

function GetMoney()
  return currentMoney
end

assert(loadfile(corePath))()
assert(loadfile(accountPath))()

local function expectFormat(copper, expected)
  local actual = ShirsInventory_AccountFormatGold(copper)
  assert(actual == expected, "format " .. tostring(copper) .. ": got " .. actual .. ", want " .. expected)
end

-- Gold formatting.
expectFormat(0, "0c")
expectFormat(45, "45c")
expectFormat(100, "1s 0c")
expectFormat(2345, "23s 45c")
expectFormat(10000, "1g 0s 0c")
expectFormat(1234567, "123g 45s 67c")
expectFormat(-5, "0c")
expectFormat(nil, "0c")

-- Account DB shape and login recording.
assert(type(ShirsInventory_AccountEnsureDB()) == "table", "account DB should be created")
assert(ShirsInventory_AccountEnsureDB().version == 1, "account DB should carry a version")
local recorded = ShirsInventory_AccountRecordCurrentGold()
assert(recorded == 1234567, "login record should return the current copper")
assert(ShirsInventoryAccountDB.realms["TestRealm"]["Altsmith"] == 1234567,
  "login should record the current character under realm and name")

-- PLAYER_MONEY freshness.
currentMoney = 2345678
assert(ShirsInventory_AccountRecordCurrentGold() == 2345678, "money change should refresh the entry")
assert(ShirsInventory_AccountGetGold("TestRealm", "Altsmith") == 2345678,
  "re-read should see the refreshed amount")

-- Per-realm separation.
currentRealm = "OtherRealm"
assert(ShirsInventory_AccountRecordCurrentGold() == 2345678, "second realm should record independently")
assert(ShirsInventoryAccountDB.realms["OtherRealm"]["Altsmith"] == 2345678, "second realm entry missing")
assert(ShirsInventoryAccountDB.realms["TestRealm"]["Altsmith"] == 2345678,
  "recording on another realm must not overwrite the first realm")
currentRealm = "TestRealm"

-- Unknown character / realm lookups.
assert(ShirsInventory_AccountGetGold("TestRealm", "Nobody") == 0, "unknown character should read 0")
assert(ShirsInventory_AccountGetGold("MissingRealm", "Altsmith") == 0, "unknown realm should read 0")

-- Tooltip lines and total.
ShirsInventoryAccountDB.realms["TestRealm"] = {
  Altsmith = 1000000,
  Banktoon = 500000,
  Auctionmule = 2500,
}
local lines, total = ShirsInventory_AccountBuildTooltipLines("TestRealm", "Altsmith")
assert(table.getn(lines) == 3, "tooltip should list every known character on the realm")
assert(lines[1].name == "Altsmith" and lines[1].current == true,
  "current character should be flagged and sort first")
assert(lines[2].name == "Auctionmule", "lines should be sorted by name")
assert(lines[3].name == "Banktoon", "lines should be sorted by name")
assert(total == 1502500, "tooltip total should sum every character's copper")

local linesCurrentMissing = ShirsInventory_AccountBuildTooltipLines("TestRealm", "Nobody")
local flagged = 0
local _, line
for _, line in ipairs(linesCurrentMissing) do
  if line.current then flagged = flagged + 1 end
end
assert(flagged == 0, "no line should be flagged current when the character is not listed")

local linesEmpty, totalEmpty = ShirsInventory_AccountBuildTooltipLines("MissingRealm", "Altsmith")
assert(table.getn(linesEmpty) == 0 and totalEmpty == 0, "unknown realm should yield no lines and zero total")

-- Full-suite account display cannot be disabled by obsolete feature state.
local hidden = false
local shownCount = 0
local displayText
local displayWidth
local coinShown = false
local coinGoldText
local coinSilverText
local coinCopperText
local function CoinText(setter)
  return {
    SetText = function(_, value) setter(value) end,
    Show = function() coinShown = true end,
    Hide = function() coinShown = false end,
  }
end
local function CoinIcon()
  return {
    Show = function() coinShown = true end,
    Hide = function() coinShown = false end,
  }
end
local fakeButton = {
  Hide = function() hidden = true end,
  Show = function() hidden = false shownCount = shownCount + 1 end,
  SetWidth = function(_, value) displayWidth = value end,
  goldText = {
    SetText = function(_, value) displayText = value end,
    Show = function() end,
    Hide = function() end,
  },
}
fakeButton.coinGoldText = CoinText(function(value) coinGoldText = value end)
fakeButton.coinGoldIcon = CoinIcon()
fakeButton.coinSilverText = CoinText(function(value) coinSilverText = value end)
fakeButton.coinSilverIcon = CoinIcon()
fakeButton.coinCopperText = CoinText(function(value) coinCopperText = value end)
fakeButton.coinCopperIcon = CoinIcon()
fakeButton.coinRegions = {
  fakeButton.coinGoldText, fakeButton.coinGoldIcon,
  fakeButton.coinSilverText, fakeButton.coinSilverIcon,
  fakeButton.coinCopperText, fakeButton.coinCopperIcon,
}
ShirsInventoryFrame = { shirsGoldButton = fakeButton }

assert(not ShirsInventory_SetFeatureEnabled("bagUI", false),
  "obsolete feature API disabled the full-suite account display")
assert(ShirsInventory_AccountIsEnabled() == true,
  "account display is not enabled with the full suite")
currentMoney = 7770000
assert(ShirsInventory_AccountRecordCurrentGold() == 7770000,
  "full-suite account recording did not update")
assert(ShirsInventory_AccountGetGold("TestRealm", "Altsmith") == 7770000,
  "full-suite account recording saved the wrong value")
ShirsInventory_AccountUpdateDisplay()
assert(hidden == false and shownCount > 0,
  "full-suite account display did not remain visible")

-- Currency supports both compact coin artwork and explicit g/s/c text. Text
-- mode needs the wider character estimate or the readout clips on large sums.
ShirsInventory_SetUseCoinIcons(false)
ShirsInventory_AccountUpdateDisplay()
assert(displayText == "777g 0s 0c", "plain-text currency display was not selected")
assert(displayWidth == 12 + string.len(displayText) * 9,
  "plain-text currency display width must use the text-mode estimate")
ShirsInventory_SetUseCoinIcons(true)
ShirsInventory_AccountUpdateDisplay()
assert(coinShown and coinGoldText == "777" and coinSilverText == "0" and coinCopperText == "0",
  "real-texture coin currency display was not restored")
assert(displayWidth == ShirsInventory_GetCoinWidgetModel(7770000).width,
  "coin widget width did not match its three-texture model")

print("GOLD_TRACKING_TEST=PASS")
