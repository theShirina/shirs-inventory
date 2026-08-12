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
function ToggleKeyRing() table.insert(delegated, "toggleKeyRing") end
KEYRING_CONTAINER = -2
KeyRingButton = { name = "KeyRingButton" }
local pulseCalls = {}
local microbuttonUpdates = 0
function SetButtonPulse(button, duration, pulse)
  table.insert(pulseCalls, { button = button, duration = duration, pulse = pulse })
end
function UpdateMicroButtons() microbuttonUpdates = microbuttonUpdates + 1 end
local optionFrameOpen = false
function IsOptionFrameOpen() return optionFrameOpen end
local canOpenPanels = true
local playerDead = false
local deadErrors = 0
function CanOpenPanels() return canOpenPanels end
function UnitIsDead(unit) return unit == "player" and playerDead end
function NotWhileDeadError() deadErrors = deadErrors + 1 end

local shown = false
ShirsInventoryFrame = {
  Show = function()
    if not shown then
      shown = true
      if ShirsInventory_OnInventoryVisibilityChanged then ShirsInventory_OnInventoryVisibilityChanged() end
    end
  end,
  Hide = function()
    if shown then
      shown = false
      if ShirsInventory_OnInventoryVisibilityChanged then ShirsInventory_OnInventoryVisibilityChanged() end
    end
  end,
  IsShown = function() return shown end,
}

assert(loadfile(uiPath))()
assert(type(ShirsInventory_InstallBagHooks) == "function", "UI should expose bag-hook installation")
ShirsInventory_InstallBagHooks()

ToggleBackpack()
assert(shown, "backpack toggle should show the combined frame")
assert(microbuttonUpdates == 1,
  "opening through Backpack must refresh the integrated Keyring microbutton")
assert(IsBagOpen(0) == 1 and IsBagOpen(4) == 1, "all normal bags should report as one open inventory")
ToggleBag(2)
assert(not shown, "an equipped-bag toggle should toggle the same combined frame")
assert(microbuttonUpdates == 2,
  "closing through a normal bag must refresh the integrated Keyring microbutton")
OpenBag(3)
assert(shown, "opening one normal bag should show the combined frame")
assert(microbuttonUpdates == 3,
  "opening through a normal bag must refresh the integrated Keyring microbutton")
CloseBag(1)
assert(not shown, "closing one normal bag should hide the combined frame")
assert(microbuttonUpdates == 4,
  "closing through a normal bag must refresh the integrated Keyring microbutton")

ToggleBag(KEYRING_CONTAINER)
assert(shown, "keyring bag toggle should open the combined inventory")
assert(IsBagOpen(KEYRING_CONTAINER) == 1, "integrated keyring should report the combined inventory state")
assert(microbuttonUpdates == 5 and table.getn(pulseCalls) == 0,
  "generic Keyring toggle must refresh the microbutton without stopping the new-key pulse")
optionFrameOpen = true
ToggleBag(KEYRING_CONTAINER)
assert(shown and microbuttonUpdates == 5 and table.getn(pulseCalls) == 0,
  "generic Keyring toggle must do nothing while an option frame is open")
optionFrameOpen = true
ToggleKeyRing()
assert(shown and microbuttonUpdates == 5 and table.getn(pulseCalls) == 0,
  "native Keyring toggle must do nothing while an option frame is open")
optionFrameOpen = false
ToggleKeyRing()
assert(not shown, "Blizzard Keyring button should toggle the combined inventory")
assert(microbuttonUpdates == 6,
  "closing the integrated Keyring must refresh the stock microbutton state")
ToggleKeyRing()
assert(shown, "Blizzard Keyring button should reopen the combined inventory")
assert(microbuttonUpdates == 7,
  "opening the integrated Keyring must refresh the stock microbutton state")
assert(table.getn(pulseCalls) == 1 and pulseCalls[1].button == KeyRingButton and
  pulseCalls[1].duration == 0 and pulseCalls[1].pulse == 1,
  "opening the integrated Keyring must stop the stock Keyring button pulse")
ToggleKeyRing()
assert(not shown, "Blizzard Keyring button should close after the native-state checks")
assert(microbuttonUpdates == 8 and table.getn(pulseCalls) == 1,
  "closing must refresh the microbutton without restarting or stopping the pulse again")
OpenBag(KEYRING_CONTAINER)
assert(shown and microbuttonUpdates == 9 and table.getn(pulseCalls) == 1,
  "generic Keyring open must refresh the microbutton without changing pulse state")
OpenBag(KEYRING_CONTAINER)
assert(shown and microbuttonUpdates == 9,
  "reopening an already-open integrated Keyring must not duplicate the native show refresh")
CloseBag(KEYRING_CONTAINER)
assert(not shown and microbuttonUpdates == 10 and table.getn(pulseCalls) == 1,
  "generic Keyring close must refresh the microbutton without changing pulse state")
CloseBag(KEYRING_CONTAINER)
assert(not shown and microbuttonUpdates == 10,
  "reclosing an already-closed integrated Keyring must not duplicate the native hide refresh")
canOpenPanels = false
playerDead = true
OpenBag(KEYRING_CONTAINER)
assert(not shown and microbuttonUpdates == 10 and deadErrors == 1,
  "generic Keyring open must preserve the native dead-player panel guard")
playerDead = false
OpenBag(KEYRING_CONTAINER)
assert(not shown and microbuttonUpdates == 10 and deadErrors == 1,
  "generic Keyring open must stay blocked when panels cannot open")
canOpenPanels = true
assert(table.getn(delegated) == 0, "integrated keyring routes should not open Blizzard's separate frame")

OpenAllBags()
assert(shown, "open-all should show the combined inventory")
OpenAllBags()
assert(shown, "stock open-all semantics must keep an already-open combined inventory shown")
CloseAllBags()
assert(not shown, "close-all should hide the combined inventory")

pfUI = { bag = {} }
ShirsInventory_UninstallBagHooks()
ShirsInventory_InstallBagHooks()
OpenAllBags()
assert(shown, "pfUI's money-datatext OpenAllBags callback should open the combined inventory")
OpenAllBags()
assert(not shown, "pressing pfUI's money datatext again should close the combined inventory")
ToggleBackpack()
assert(shown, "the stock backpack toggle should still open the combined inventory with pfUI loaded")
OpenAllBags()
assert(not shown, "pfUI's money datatext must close inventory opened through another bag control")
pfUI = nil

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
