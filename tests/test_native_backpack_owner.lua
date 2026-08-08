local settingsPath = arg[1]
ShirsInventoryDB = {}
assert(loadfile(settingsPath))()
ShirsInventory_IsBagUIActive = function() return false end
ShirsInventory_IsFeatureEnabled = function() return true end
assert(type(ShirsInventory_ShouldUseStandaloneControls) == "function" and
  not ShirsInventory_ShouldUseStandaloneControls(),
  "full suite still enables standalone controls on another bag UI")
local frames = {
  ContainerFrame1 = { visible = true, id = 2 },
  ContainerFrame2 = { visible = true, id = 0 },
  ContainerFrame3 = { visible = false, id = 0 },
}
for _, frame in pairs(frames) do
  frame.IsShown = function(self) return self.visible end
  frame.GetID = function(self) return self.id end
end
NUM_CONTAINER_FRAMES = 3
function getglobal(name) return frames[name] end
assert(ShirsInventory_FindVisibleBackpackFrame() == frames.ContainerFrame2, "controls must follow the visible frame that owns bag 0")
frames.ContainerFrame2.visible = false
assert(ShirsInventory_FindVisibleBackpackFrame() == nil, "hidden bag-0 frames must not own visible controls")
frames.ContainerFrame3.visible = true
assert(ShirsInventory_FindVisibleBackpackFrame() == frames.ContainerFrame3, "a newly visible bag-0 owner must be found")

frames.ContainerFrame3.visible = false
pfUI = { bag = { right = {
  visible = true,
  IsShown = function(self) return self.visible end,
} } }
assert(type(ShirsInventory_FindVisibleExternalBagFrame) == "function",
  "external bag-frame discovery is missing")
assert(ShirsInventory_FindVisibleExternalBagFrame() == pfUI.bag.right,
  "visible PFUI bags must own Shir's standalone controls")
assert(type(ShirsInventory_GetStandaloneControlHost) == "function",
  "standalone control-host selection is missing")
local host, provider = ShirsInventory_GetStandaloneControlHost()
assert(host == pfUI.bag.right and provider == "pfui",
  "PFUI must be selected when it is the visible external bag provider")
assert(type(ShirsInventory_GetStandaloneControlLayout) == "function",
  "standalone control layout model is missing")
local pfLayout = ShirsInventory_GetStandaloneControlLayout("pfui")
assert(pfLayout.count == 4 and pfLayout.buttonWidth == pfLayout.buttonHeight,
  "PFUI must receive equal Sort, Grouping, Direction, and Settings controls")
assert(pfLayout.anchorPoint == "BOTTOMRIGHT" and pfLayout.relativePoint == "TOPRIGHT",
  "PFUI controls must sit above its frame instead of colliding with PFUI's header")

pfUI.bag.right.visible = false
frames.ContainerFrame2.visible = true
host, provider = ShirsInventory_GetStandaloneControlHost()
assert(host == frames.ContainerFrame2 and provider == "native",
  "visible native backpack must remain the fallback standalone host")
local nativeLayout = ShirsInventory_GetStandaloneControlLayout("native")
assert(nativeLayout.count == 4 and nativeLayout.buttonWidth == nativeLayout.buttonHeight,
  "native bags must receive the same four equal controls")
print("NATIVE_BACKPACK_OWNER_TEST=PASS")
