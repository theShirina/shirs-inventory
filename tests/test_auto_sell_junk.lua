local corePath, junkPath = arg[1], arg[2]
ShirsInventoryDB = {
  setupComplete = true,
  features = { bagUI = true, sorter = false, junk = true },
  junkItems = { [7076] = true },
}
MerchantFrame = { selectedTab = 1, IsShown = function() return true end }
function GetMoney() return 1000 end
function GetContainerNumSlots(bag) if bag == 0 then return 2 end return 0 end
local items = {
  ["0:1"] = { texture = "gray", quality = 0, link = "|Hitem:111:0:0:0|h[Gray]|h" },
  ["0:2"] = { texture = "marked", quality = 2, link = "|Hitem:7076:0:0:0|h[Marked]|h" },
}
function GetContainerItemInfo(bag, slot)
  local item = items[bag .. ":" .. slot]
  if not item then return nil end
  return item.texture, 1, nil, item.quality
end
function GetContainerItemLink(bag, slot)
  local item = items[bag .. ":" .. slot]
  return item and item.link
end
function UseContainerItem() end

assert(loadfile(corePath))()
assert(loadfile(junkPath))()
assert(ShirsInventory_GetAutoSellJunk() == false, "auto-sell must default off")
local count, status = ShirsInventory_StartAutoJunkSale()
assert(count == 0 and status == "disabled", "vendor open must do nothing while opt-in is off")
assert(ShirsInventory_SetAutoSellJunk(true), "auto-sell setting should accept true")
assert(ShirsInventory_GetAutoSellJunk() == true, "auto-sell opt-in was not saved")
count, status = ShirsInventory_StartAutoJunkSale()
assert(count == 2 and status == "started", "opt-in should queue gray and manually marked junk")
ShirsInventory_CancelJunkSale()
ShirsInventory_SetFeatureEnabled("junk", false)
count, status = ShirsInventory_StartAutoJunkSale()
assert(count == 0 and status == "disabled", "disabled Junk feature must block automatic sale")
ShirsInventory_SetFeatureEnabled("junk", true)
MerchantFrame.selectedTab = 2
count, status = ShirsInventory_StartAutoJunkSale()
assert(count == 0 and status == "merchant", "Buyback must block automatic sale")
assert(ShirsInventory_SetAutoSellJunk(false), "auto-sell setting should accept false")
assert(ShirsInventory_GetAutoSellJunk() == false, "auto-sell opt-out was not saved")
print("AUTO_SELL_JUNK_TEST=PASS")
