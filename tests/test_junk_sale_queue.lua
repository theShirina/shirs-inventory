local corePath = arg[1]
local junkPath = arg[2]
local accountPath = arg[3]

ShirsInventoryDB = { junkItems = { [7076] = true } }
local merchantOpen = true
MerchantFrame = { selectedTab = 1, IsShown = function() return merchantOpen end }
local money = 10000
function GetMoney() return money end
function GetContainerNumSlots(bag)
  if bag == 0 then return 4 end
  if bag == 1 then return 1 end
  return 0
end
local items = {
  -- Vanilla may report -1 here for stackable items even when GetItemInfo
  -- has the real quality. Cracked Bill reproduces the user's merchant bug.
  ["0:1"] = { texture = "gray", count = 2, locked = nil, quality = -1, link = "|Hitem:111:0:0:0|h[Cracked Bill]|h" },
  ["0:2"] = { texture = "earth", count = 1, locked = nil, quality = 2, link = "|Hitem:7076:0:0:0|h[Essence of Earth]|h" },
  ["0:3"] = { texture = "white", count = 1, locked = nil, quality = -1, link = "|Hitem:333:0:0:0|h[Keep]|h" },
  ["0:4"] = { texture = "transient", count = 1, locked = nil, quality = -1, link = nil },
  ["1:1"] = { texture = "locked", count = 1, locked = 1, quality = 0, link = "|Hitem:444:0:0:0|h[Locked Gray]|h" },
}
local itemQualities = { [111] = 0, [333] = 1, [444] = 0, [7076] = 2 }
function GetItemInfo(value)
  assert(value ~= nil, "GetItemInfo must not receive nil")
  local itemId = tonumber(value)
  if not itemId and type(value) == "string" then
    local _, _, rawItemId = string.find(value, "item:(%d+)")
    itemId = tonumber(rawItemId)
  end
  return "Item", value, itemQualities[itemId]
end
function GetContainerItemInfo(bag, slot)
  local item = items[bag .. ":" .. slot]
  if not item then return nil end
  return item.texture, item.count, item.locked, item.quality
end
function GetContainerItemLink(bag, slot)
  local item = items[bag .. ":" .. slot]
  return item and item.link
end
local sold = {}
function UseContainerItem(bag, slot)
  table.insert(sold, bag .. ":" .. slot)
end
local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) table.insert(messages, text) end }

assert(loadfile(corePath))()
assert(loadfile(junkPath))()
assert(loadfile(accountPath))()

local count, status = ShirsInventory_StartJunkSale()
assert(count == 2 and status == "started", "sale should queue gray and manually marked stacks")

local acted, tickStatus = ShirsInventory_SellNextJunk()
assert(acted and tickStatus == "sold", "first tick should sell one stack")
assert(table.getn(sold) == 1 and sold[1] == "0:1", "first tick should sell only the first gray stack")

acted, tickStatus = ShirsInventory_SellNextJunk()
assert(acted and tickStatus == "sold", "second tick should sell the next stack")
assert(table.getn(sold) == 2 and sold[2] == "0:2", "manual junk should sell on its own tick")

-- Vanilla can update GetMoney after the final bag sale has been submitted.
acted, tickStatus = ShirsInventory_SellNextJunk()
assert(not acted and tickStatus == "waiting", "summary should wait for the delayed money update")
assert(table.getn(messages) == 0, "summary printed before money changed")
acted, tickStatus = ShirsInventory_SellNextJunk()
assert(not acted and tickStatus == "waiting", "summary should keep waiting while money remains stale")

money = 12868
acted, tickStatus = ShirsInventory_SellNextJunk()
assert(not acted and tickStatus == "waiting", "summary should observe the money change before settling")
acted, tickStatus = ShirsInventory_SellNextJunk()
assert(not acted and tickStatus == "waiting", "summary should require a stable post-sale money value")
acted, tickStatus = ShirsInventory_SellNextJunk()
assert(not acted and tickStatus == "complete", "summary should complete after money settles")
assert(table.getn(messages) == 1 and string.find(messages[1], "28s 68c.", 1, true),
  "summary should convert the settled 2868-copper gain into silver and copper")
assert(table.getn(sold) == 2, "unmarked, unresolved, and locked items should never sell")

-- A legitimate zero-value or missing money update must still end after 12 checks.
count, status = ShirsInventory_StartJunkSale()
assert(count == 2 and status == "started", "a zero-change sale should start")
assert(ShirsInventory_SellNextJunk() == true, "zero-change sale should submit the first stack")
assert(ShirsInventory_SellNextJunk() == true, "zero-change sale should submit the second stack")
local check
for check = 1, 11 do
  acted, tickStatus = ShirsInventory_SellNextJunk()
  assert(not acted and tickStatus == "waiting", "zero-change summary ended before its bounded timeout")
end
acted, tickStatus = ShirsInventory_SellNextJunk()
assert(not acted and tickStatus == "complete", "zero-change summary should end on its twelfth check")
assert(table.getn(messages) == 2 and string.find(messages[2], "0c.", 1, true),
  "zero-change timeout should report a formatted zero total")
assert(table.getn(sold) == 4, "zero-change timeout should not resubmit items")

count, status = ShirsInventory_StartJunkSale()
assert(count == 2 and status == "started", "a new merchant sale should be startable")
merchantOpen = false
acted, tickStatus = ShirsInventory_SellNextJunk()
assert(not acted and tickStatus == "cancelled", "merchant close should cancel before another sale")
assert(table.getn(sold) == 4, "cancelled sale should perform no action")

merchantOpen = true
MerchantFrame.selectedTab = 2
count, status = ShirsInventory_StartJunkSale()
assert(count == 0 and status == "merchant", "buyback tab should block bulk selling")

print("JUNK_SALE_QUEUE_TEST=PASS")
