BINDING_HEADER_SHIRSINVENTORY = "Shir's Inventory"
BINDING_NAME_SHIRSINVENTORY_TOGGLE = "Toggle combined inventory"
BINDING_NAME_SHIRSINVENTORY_SORT = "Sort bags"
BINDING_NAME_SHIRSINVENTORY_SELL_JUNK = "Sell junk at merchant"

function ShirsInventory_BindingToggle()
  ToggleBackpack()
end

function ShirsInventory_BindingSort()
  ShirsInventory_SortBags()
end

function ShirsInventory_BindingSellJunk()
  ShirsInventory_StartJunkSale()
end
