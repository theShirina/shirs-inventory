-- AUX window auto-opens Shir's combined inventory without replacing AUX's
-- own OnShow handler or toggling an already-open bag.
local uiPath = arg[1]

local openCalls = 0
local toggleCalls = 0
function OpenBackpack() openCalls = openCalls + 1 end
function ToggleBackpack() toggleCalls = toggleCalls + 1 end

assert(loadfile(uiPath))()
assert(type(ShirsInventory_InstallAuxAutoOpenHook) == "function",
  "AUX auto-open hook installer is missing")

aux_frame = nil
assert(not ShirsInventory_InstallAuxAutoOpenHook(),
  "AUX auto-open hook must fail closed before aux_frame exists")

local previousCalls = 0
local scripts = {
  OnShow = function() previousCalls = previousCalls + 1 end,
}
aux_frame = {
  GetScript = function(_, name) return scripts[name] end,
  SetScript = function(_, name, callback) scripts[name] = callback end,
}

assert(ShirsInventory_InstallAuxAutoOpenHook(),
  "AUX auto-open hook did not install on aux_frame")
assert(aux_frame.shirsInventoryAutoOpenHookInstalled == true,
  "AUX auto-open hook marker was not stored on its exact owner frame")
local installed = scripts.OnShow
assert(type(installed) == "function", "AUX OnShow wrapper is missing")
assert(ShirsInventory_InstallAuxAutoOpenHook() and scripts.OnShow == installed,
  "AUX auto-open hook was not idempotent")

this = aux_frame
scripts.OnShow()
assert(previousCalls == 1,
  "AUX's original OnShow handler must run exactly once")
assert(openCalls == 1,
  "showing AUX must open Shir's combined inventory exactly once")
assert(toggleCalls == 0,
  "AUX auto-open must use open-only behavior, never toggle the bag")

-- ADDON_LOADED must install the hook after aux-addon creates aux_frame.
local secondScripts = { OnShow = function() previousCalls = previousCalls + 1 end }
aux_frame = {
  GetScript = function(_, name) return secondScripts[name] end,
  SetScript = function(_, name, callback) secondScripts[name] = callback end,
}
ShirsInventory_HandleLoaderEvent("ADDON_LOADED", "aux-addon")
assert(aux_frame.shirsInventoryAutoOpenHookInstalled == true,
  "aux-addon load did not install the AUX auto-open hook")
this = aux_frame
secondScripts.OnShow()
assert(previousCalls == 2 and openCalls == 2,
  "loader-installed AUX hook did not preserve OnShow and open the inventory")

print("AUX_AUTO_OPEN_TEST=PASS")
