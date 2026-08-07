local uiPath = arg[1]

local delegated = {}
function ToggleBackpack() table.insert(delegated, "toggleBackpack") end
function OpenBackpack() table.insert(delegated, "openBackpack") end
function CloseBackpack() table.insert(delegated, "closeBackpack") end
function OpenAllBags() table.insert(delegated, "openAll") end
function CloseAllBags() table.insert(delegated, "closeAll") end
function ToggleBag(id) table.insert(delegated, "toggle:" .. id) end
function OpenBag(id) table.insert(delegated, "open:" .. id) end
function CloseBag(id) table.insert(delegated, "close:" .. id) end
function IsBagOpen(id) table.insert(delegated, "isopen:" .. id); return 99 end
KEYRING_CONTAINER = -2

local shown = false
ShirsInventoryFrame = {
  Show = function() shown = true end,
  Hide = function() shown = false end,
  IsShown = function() return shown end,
}

assert(loadfile(uiPath))()
assert(type(ShirsInventory_InstallBagHooks) == "function", "UI should expose bag-hook installation")
ShirsInventory_InstallBagHooks()

ToggleBackpack()
assert(shown, "backpack toggle should show the combined frame")
assert(IsBagOpen(0) == 1 and IsBagOpen(4) == 1, "all normal bags should report as one open inventory")
ToggleBag(2)
assert(not shown, "an equipped-bag toggle should toggle the same combined frame")
OpenBag(3)
assert(shown, "opening one normal bag should show the combined frame")
CloseBag(1)
assert(not shown, "closing one normal bag should hide the combined frame")

ToggleBag(KEYRING_CONTAINER)
assert(delegated[1] == "toggle:-2", "keyring should stay on Blizzard's original handler")
assert(IsBagOpen(KEYRING_CONTAINER) == 99, "keyring open checks should delegate")

OpenAllBags()
assert(shown, "open-all should show the combined inventory")
CloseAllBags()
assert(not shown, "close-all should hide the combined inventory")

shown = true
delegated = {}
assert(type(ShirsInventory_DeactivateBagUI) == "function", "bag-provider handoff helper is missing")
assert(ShirsInventory_DeactivateBagUI(), "deactivating an open Shir's frame should reopen the restored provider")
assert(not shown, "provider handoff must close Shir's frame")
assert(delegated[1] == "openBackpack", "provider handoff must immediately open the restored PFUI/native bag provider")
delegated = {}
ToggleBackpack()
assert(delegated[1] == "toggleBackpack", "bag functions must remain restored after provider handoff")

ShirsInventory_InstallBagHooks()
local providerToggle = function() table.insert(delegated, "providerToggle") end
ToggleBackpack = providerToggle
shown = false
ShirsInventory_DeactivateBagUI()
assert(ToggleBackpack == providerToggle,
  "uninstall must not overwrite a newer bag provider hook installed after Shir's snapshot")

ShirsInventory_InstallBagHooks()
local lateProviderToggle = function() table.insert(delegated, "lateProviderToggle") end
ToggleBackpack = lateProviderToggle
shown = false
ShirsInventory_ActivateBagUI()
assert(ToggleBackpack ~= lateProviderToggle,
  "re-selecting Shir's at first login must reclaim globals replaced by a late-loading bag provider")
ToggleBackpack()
assert(shown, "reclaimed startup bag toggle must open Shir's combined inventory")
ShirsInventory_UninstallBagHooks()
assert(ToggleBackpack == lateProviderToggle,
  "reclaimed hooks must restore the late provider when Shir's ownership is later disabled")

print("BAG_HOOKS_TEST=PASS")
