local corePath = arg[1]
local junkPath = arg[2]

ShirsInventoryDB = { junkItems = { [7076] = true } }
local merchantOpen = true
MerchantFrame = { selectedTab = 1, IsShown = function() return merchantOpen end }
local money = 10000
function GetMoney() return money end
function GetContainerNumSlots(bag)
  if bag == 0 then return 3 end
  if bag == 1 then return 1 end
  return 0
end
local items = {
  ["0:1"] = { texture = "gray", count = 2, locked = nil, quality = 0, link = "|Hitem:111:0:0:0|h[Gray]|h" },
  ["0:2"] = { texture = "earth", count = 1, locked = nil, quality = 2, link = "|Hitem:7076:0:0:0|h[Essence of Earth]|h" },
  ["0:3"] = { texture = "white", count = 1, locked = nil, quality = 1, link = "|Hitem:333:0:0:0|h[Keep]|h" },
  ["1:1"] = { texture = "locked", count = 1, locked = 1, quality = 0, link = "|Hitem:444:0:0:0|h[Locked Gray]|h" },
}
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
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

assert(loadfile(corePath))()
assert(loadfile(junkPath))()

local count, status = ShirsInventory_StartJunkSale()
assert(count == 2 and status == "started", "sale should queue gray and manually marked stacks")

local acted, tickStatus = ShirsInventory_SellNextJunk()
assert(acted and tickStatus == "sold", "first tick should sell one stack")
assert(table.getn(sold) == 1 and sold[1] == "0:1", "first tick should sell only the first gray stack")

acted, tickStatus = ShirsInventory_SellNextJunk()
assert(acted and tickStatus == "sold", "second tick should sell the next stack")
assert(table.getn(sold) == 2 and sold[2] == "0:2", "manual junk should sell on its own tick")

acted, tickStatus = ShirsInventory_SellNextJunk()
assert(not acted and tickStatus == "complete", "queue should complete after its last candidate")
assert(table.getn(sold) == 2, "unmarked and locked items should never sell")

count, status = ShirsInventory_StartJunkSale()
assert(count == 2 and status == "started", "a new merchant sale should be startable")
merchantOpen = false
acted, tickStatus = ShirsInventory_SellNextJunk()
assert(not acted and tickStatus == "cancelled", "merchant close should cancel before another sale")
assert(table.getn(sold) == 2, "cancelled sale should perform no action")

merchantOpen = true
MerchantFrame.selectedTab = 2
count, status = ShirsInventory_StartJunkSale()
assert(count == 0 and status == "merchant", "buyback tab should block bulk selling")

print("JUNK_SALE_QUEUE_TEST=PASS")
