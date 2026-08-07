local uiPath = arg[1]
local shirsShown = false
local pfShown = true
ShirsInventoryFrame = {
  Show = function() shirsShown = true end,
  Hide = function() shirsShown = false end,
  IsShown = function() return shirsShown end,
}
pfUI = { bag = { right = {
  Show = function() pfShown = true end,
  Hide = function() pfShown = false end,
  IsShown = function() return pfShown end,
} } }
function ToggleBackpack() if pfShown then pfShown = false else pfShown = true end end
function OpenBackpack() pfShown = true end
function CloseBackpack() pfShown = false end
function OpenAllBags() pfShown = true end
function CloseAllBags() pfShown = false end
function ToggleBag() end
function OpenBag() end
function CloseBag() end
function IsBagOpen() return pfShown and 1 or nil end

assert(loadfile(uiPath))()
assert(type(ShirsInventory_ActivateBagUI) == "function", "provider activation helper is missing")
assert(ShirsInventory_ActivateBagUI(), "activating Shir's while PFUI is open should transfer visibility")
assert(shirsShown and not pfShown, "Shir's provider selection must close PFUI and open Shir's immediately")
assert(ShirsInventory_DeactivateBagUI(), "external provider handoff should transfer visibility back")
assert(not shirsShown and pfShown, "PFUI provider selection must close Shir's and reopen PFUI immediately")

-- Providers without a known frame name still expose the bag globals. Use
-- those globals to close the old window and carry its open state to Shir's.
pfUI = nil
local genericShown = true
local genericCloseCalls = 0
function ToggleBackpack() genericShown = not genericShown end
function OpenBackpack() genericShown = true end
function CloseBackpack() genericShown = false end
function OpenAllBags() genericShown = true end
function CloseAllBags() genericCloseCalls = genericCloseCalls + 1; genericShown = false end
function ToggleBag() end
function OpenBag() end
function CloseBag() end
function IsBagOpen() return genericShown and 1 or nil end

assert(ShirsInventory_ActivateBagUI(), "generic open provider should transfer visibility")
assert(shirsShown and not genericShown and genericCloseCalls == 1,
  "generic provider must close before Shir's opens")
print("PROVIDER_HANDOFF_VISIBILITY_TEST=PASS")
