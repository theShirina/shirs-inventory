-- Shift-click item search routing for aux and stock Auction House.
local corePath, junkPath, uiPath = arg[1], arg[2], arg[3]
ShirsInventoryDB = { junkItems = {} }
local chatMessages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) table.insert(chatMessages, text) end }

local altDown = false
local controlDown = false
local shiftDown = false
local itemCount = 4
local currentLink = "|Hitem:7076:0:0:0|h[Essence of Earth]|h"
function IsAltKeyDown() return altDown end
function IsControlKeyDown() return controlDown end
function IsShiftKeyDown() return shiftDown end
function GetContainerItemInfo() return "texture", itemCount, nil, 2 end
function GetContainerItemLink() return currentLink end
local used, picked, auxUse, auxClick = 0, 0, 0, 0
function UseContainerItem(bag, slot)
  used = used + 1
  if aux and aux.get_tab and aux.get_tab().USE_ITEM then
    aux.get_tab().USE_ITEM(bag, slot)
  end
end
function PickupContainerItem() picked = picked + 1 end
function CursorHasItem() return false end
function ClearCursor() end
function ToggleBackpack() end
MerchantFrame = { selectedTab = 1, IsShown = function() return false end }
function OpenStackSplitFrame()
  if SHIRS_INVENTORY_SPLIT_COUNTER then SHIRS_INVENTORY_SPLIT_COUNTER.value = SHIRS_INVENTORY_SPLIT_COUNTER.value + 1 end
end
local splitCount = { value = 0 }
SHIRS_INVENTORY_SPLIT_COUNTER = splitCount

-- Stock Auction House harness
local browseShown = false
local searchCalled = 0
local searchBoxText = ""
AuctionFrame = {
  IsShown = function() return true end,
  IsVisible = function() return true end,
}
AuctionFrameBrowse = { IsShown = function() return browseShown end }
BrowseName = {
  SetText = function(_, text) searchBoxText = text end,
  GetText = function() return searchBoxText end,
}
function AuctionFrameBrowse_Search() searchCalled = searchCalled + 1 end

-- aux harness: aux module state is only reachable through the guarded table
-- path used by the addon, so a nil global must fail closed.
local auxFrameShown = false
aux_frame = {
  IsShown = function() return auxFrameShown end,
  IsVisible = function() return auxFrameShown end,
}
local auxModule = {
  get_tab = function()
    return {
      CLICK_LINK = function(item) auxClick = auxClick + 1 end,
      USE_ITEM = function() auxUse = auxUse + 1 end,
    }
  end,
}
-- aux's exact Vanilla loader exposes the module through require("aux").
-- The global aux name is only its SavedVariables table and has no get_tab.
aux = { account = {}, realm = {}, faction = {}, character = {} }
function require(name)
  if name == "aux" then return auxModule end
  return nil
end

assert(loadfile(corePath))()
assert(loadfile(junkPath))()
assert(loadfile(uiPath))()

assert(type(ShirsInventory_GetAuctionSearchTarget) == "function",
  "auction search target resolver is missing")
assert(type(ShirsInventory_RouteShiftClickSearch) == "function",
  "shift-click auction search router is missing")

local button = { bag = 0, slot = 1 }

-- 1. Shift-click with no auction house open must preserve chat and stack fallback.
shiftDown = true
browseShown = false
auxFrameShown = false
local handled = ShirsInventory_HandleItemClick(button, "LeftButton")
assert(handled and splitCount.value == 1,
  "shift-click with no auction house must keep the stock stack-split fallback")
assert(used == 0 and picked == 0,
  "shift-click stack fallback must not use or move the item")
splitCount.value = 0

-- 2. Stock Auction House browse tab: shift-click fills the box and searches.
browseShown = true
handled = ShirsInventory_HandleItemClick(button, "LeftButton")
assert(handled, "shift-click on a stock auction item was not handled")
assert(searchCalled == 1, "stock Auction House shift-click did not run a search")
assert(searchBoxText == "Essence of Earth",
  "stock Auction House shift-click did not fill BrowseName with the item name")
assert(splitCount.value == 0, "stock Auction House shift-click must not open stack split")
assert(used == 0 and picked == 0,
  "stock Auction House shift-click must not use or move the item")
searchCalled = 0
browseShown = false

-- 3. aux frame shown: shift-click routes to aux, not the stock browse path.
auxFrameShown = true
searchBoxText = ""
handled = ShirsInventory_HandleItemClick(button, "LeftButton")
assert(handled, "shift-click with aux open was not handled")
assert(searchCalled == 0 and auxClick == 1 and auxUse == 0,
  "aux shift-click must route through aux's active CLICK_LINK hook, not stock search")
assert(used == 0, "aux shift-click must not fall through to UseContainerItem")
assert(splitCount.value == 0, "aux shift-click must not open stack split")
auxFrameShown = false

-- 4. Chat edit box must win over an open auction house (preserved fallback).
browseShown = true
local wimLink
WIM_EditBoxInFocus = { Insert = function(_, link) wimLink = link end }
handled = ShirsInventory_HandleItemClick(button, "LeftButton")
assert(handled and wimLink == GetContainerItemLink(0, 1),
  "shift-click must insert the item link into a focused whisper even with an auction house open")
assert(searchCalled == 0, "focused chat must win over auction search")
wimLink = nil
WIM_EditBoxInFocus = nil
browseShown = false
searchCalled = 0

-- Missing AUX module APIs must fail into the normal stack-split path.
auxFrameShown = true
local savedRequire = require
require = function() return nil end
splitCount.value = 0
handled = ShirsInventory_HandleItemClick(button, "LeftButton")
assert(handled and splitCount.value == 1 and auxClick == 1,
  "missing AUX module APIs must preserve stack splitting")
require = savedRequire
auxFrameShown = false
splitCount.value = 0

-- Missing stock search APIs must also preserve stack splitting.
browseShown = true
local savedAuctionSearch = AuctionFrameBrowse_Search
AuctionFrameBrowse_Search = nil
handled = ShirsInventory_HandleItemClick(button, "LeftButton")
assert(handled and splitCount.value == 1,
  "missing stock Auction House search API must preserve stack splitting")
AuctionFrameBrowse_Search = savedAuctionSearch
browseShown = false
splitCount.value = 0

-- 5. Right-click is never hijacked by the auction router.
browseShown = true
shiftDown = true
handled = ShirsInventory_HandleItemClick(button, "RightButton")
assert(used == 1, "shift right-click with the auction house open must preserve native use (used=" .. used .. ")")
used = 0
browseShown = false

-- 6. A shifted left-click on an uncached item fails closed into the chat fallback.
currentLink = nil
browseShown = true
searchBoxText = ""
local chatEditShown = true
ChatFrameEditBox = {
  IsShown = function() return chatEditShown end,
  Insert = function(_, text) wimLink = text end,
}
handled = ShirsInventory_HandleItemClick(button, "LeftButton")
assert(handled and wimLink == nil and searchBoxText == "",
  "an unreadable item must fail closed without searching or opening chat")
wimLink = nil
ChatFrameEditBox = nil
currentLink = "|Hitem:7076:0:0:0|h[Essence of Earth]|h"
browseShown = false

print("AUCTION_SEARCH_ROUTING_TEST=PASS")
