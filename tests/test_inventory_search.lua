local uiPath = arg[1]

assert(loadfile(uiPath))()
assert(type(ShirsInventory_NormalizeSearchQuery) == "function",
  "inventory search query normalizer is missing")
assert(type(ShirsInventory_ItemMatchesSearch) == "function",
  "inventory item search predicate is missing")
assert(type(ShirsInventory_ApplySearchToButton) == "function",
  "inventory button search renderer is missing")
assert(type(ShirsInventory_GetSearchBoxLayout) == "function",
  "inventory search-box layout model is missing")

assert(ShirsInventory_NormalizeSearchQuery("  MOONcloth  ") == "mooncloth",
  "search query must trim outer spaces and ignore case")
assert(ShirsInventory_NormalizeSearchQuery("   ") == "",
  "whitespace-only searches must clear the filter")
assert(ShirsInventory_ItemMatchesSearch("moon", "Mooncloth", nil),
  "partial item-name searches must match without case sensitivity")
assert(ShirsInventory_ItemMatchesSearch("rune", nil, "|cffffffff|Hitem:1:0:0:0|h[Rune Thread]|h|r"),
  "search must fall back to the visible hyperlink name when item info is uncached")
assert(not ShirsInventory_ItemMatchesSearch("cloth", "Rune Thread", nil),
  "unrelated item names must not match")
assert(ShirsInventory_ItemMatchesSearch("", nil, nil),
  "an empty query must restore every slot")

local button = {
  alpha = nil,
  SetAlpha = function(self, value) self.alpha = value end,
}
assert(ShirsInventory_ApplySearchToButton(button, "moon", "Mooncloth", nil) and button.alpha == 1,
  "matching items must remain fully visible")
assert(not ShirsInventory_ApplySearchToButton(button, "rune", "Mooncloth", nil) and button.alpha == 0.2,
  "nonmatching items must dim without moving their slot")
assert(not ShirsInventory_ApplySearchToButton(button, "rune", nil, nil) and button.alpha == 0.2,
  "empty or uncached slots must dim safely while searching")
assert(ShirsInventory_ApplySearchToButton(button, "", nil, nil) and button.alpha == 1,
  "clearing search must restore every slot to full opacity")

assert(type(ShirsInventory_GetSearchQueryForButton) == "function",
  "shared item rendering needs an inventory-only search-query selector")
ShirsInventoryFrame = { searchQuery = "moon" }
local inventoryButton = {
  shirsInventorySearchEnabled = true,
  SetAlpha = function(self, value) self.alpha = value end,
}
local bankButton = {
  shirsInventorySearchEnabled = false,
  SetAlpha = function(self, value) self.alpha = value end,
}
local inventoryQuery = ShirsInventory_GetSearchQueryForButton(inventoryButton)
local bankQuery = ShirsInventory_GetSearchQueryForButton(bankButton)
assert(inventoryQuery == "moon" and bankQuery == "",
  "inventory search query must never leak into bank item rendering")
ShirsInventory_ApplySearchToButton(inventoryButton, inventoryQuery, "Rune Thread", nil)
ShirsInventory_ApplySearchToButton(bankButton, bankQuery, "Rune Thread", nil)
assert(inventoryButton.alpha == 0.2 and bankButton.alpha == 1,
  "active inventory search must dim only carried items and keep bank items fully visible")
ShirsInventoryFrame = nil

local layout = ShirsInventory_GetSearchBoxLayout()
assert(layout.height == 22 and layout.leftGap == 10 and layout.rightGap == 10,
  "search field must fit between the bag icons and action icons")
assert(layout.minimumWidth == 80 and layout.placeholder == "Search",
  "search field needs a useful minimum size and placeholder")

assert(type(ShirsInventory_CreateSearchBox) == "function",
  "search-box constructor must be exposed for exact runtime testing")

local created
function CreateFrame(frameType, name, parent, template)
  assert(frameType == "EditBox" and name == "ShirsInventorySearchBox" and template == "InputBoxTemplate",
    "inventory search must use the named Vanilla input-box template")
  local box = { scripts = {}, points = {}, text = "", focused = false, parent = parent }
  function box:SetHeight(value) self.height = value end
  function box:SetAutoFocus(value) self.autoFocus = value end
  function box:SetMaxLetters(value) self.maxLetters = value end
  function box:SetPoint(...) table.insert(self.points, arg) end
  function box:SetTextInsets(...) self.insets = arg end
  function box:CreateFontString()
    local label = { shown = true }
    function label:SetPoint(...) self.point = arg end
    function label:SetText(value) self.text = value end
    function label:Show() self.shown = true end
    function label:Hide() self.shown = false end
    return label
  end
  function box:SetScript(name, callback) self.scripts[name] = callback end
  function box:GetText() return self.text end
  function box:SetText(value)
    self.text = value
    if self.scripts.OnTextChanged then
      local oldThis = this
      this = self
      self.scripts.OnTextChanged()
      this = oldThis
    end
  end
  function box:ClearFocus() self.focused = false end
  created = box
  return box
end
local frame = {
  bagBarButtons = {{}, {}, {}, {}, {}, {}},
  sortButton = {},
  left = 100,
  right = 300,
  bottom = 100,
  top = 300,
}
function frame:GetLeft() return self.left end
function frame:GetRight() return self.right end
function frame:GetBottom() return self.bottom end
function frame:GetTop() return self.top end
function frame:GetEffectiveScale() return 2 end
local cursorX, cursorY = 400, 400
function GetCursorPosition() return cursorX, cursorY end
local autoClear = true
ShirsInventory_GetAutoClearSearch = function() return autoClear end
local refreshCalls = 0
ShirsInventory_RefreshSearchFilter = function() refreshCalls = refreshCalls + 1 end
assert(ShirsInventory_CreateSearchBox(frame) == created and frame.searchBox == created,
  "search-box constructor must attach and return the EditBox")
assert(created.height == 22 and created.autoFocus == false and created.maxLetters == 64,
  "search EditBox has incorrect Vanilla input settings")
assert(created.points[1][1] == "LEFT" and created.points[1][2] == frame.bagBarButtons[6] and
  created.points[1][3] == "RIGHT" and created.points[1][4] == 10,
  "search field must begin after the sixth bag icon")
assert(created.points[2][1] == "RIGHT" and created.points[2][2] == frame.sortButton and
  created.points[2][3] == "LEFT" and created.points[2][4] == -10,
  "search field must end before the leftmost action icon")
assert(created.placeholder.text == "Search" and created.placeholder.shown,
  "empty search field must display its placeholder")
created:SetText("Moon")
assert(frame.searchQuery == "moon" and refreshCalls == 1 and not created.placeholder.shown,
  "typing must normalize the query, refresh item states, and hide the placeholder")
assert(type(created.HasFocus) == "nil",
  "search regression must model Microbot's EditBox without HasFocus")
local oldThis = this
this = created
created.focused = true
created.scripts.OnEnterPressed()
assert(not created.focused,
  "Enter must release keyboard focus")
created.scripts.OnEditFocusLost()
assert(frame.searchQuery == "moon" and created.text == "Moon" and refreshCalls == 1,
  "losing focus inside the inventory must preserve the search")
cursorX, cursorY = 800, 400
created.scripts.OnEditFocusLost()
assert(frame.searchQuery == "" and created.text == "" and refreshCalls == 2 and created.placeholder.shown,
  "losing focus outside the inventory must clear the query and restore every item")
created:SetText("Rune")
assert(frame.searchQuery == "rune" and refreshCalls == 3,
  "search must remain usable after an outside-focus clear")
autoClear = false
created.scripts.OnEditFocusLost()
assert(frame.searchQuery == "rune" and created.text == "Rune" and refreshCalls == 3,
  "disabling automatic clear must preserve search after focus loss")
created.focused = true
created.scripts.OnEscapePressed()
this = oldThis
assert(frame.searchQuery == "" and created.text == "" and refreshCalls == 4 and not created.focused,
  "Escape must always clear the query, restore item states, and release focus")
assert(created.placeholder.shown, "cleared unfocused search must restore its placeholder")

assert(type(ShirsInventory_ClearSearch) == "function",
  "inventory hide path needs one reusable search-clear helper")
assert(type(ShirsInventory_IsCursorInsideFrame) == "function" and
  ShirsInventory_IsCursorInsideFrame(frame) == false,
  "outside-click detection must use the inventory's scaled bounds")
cursorX, cursorY = 400, 400
assert(ShirsInventory_IsCursorInsideFrame(frame) == true,
  "inside-click detection must preserve searches within the inventory")
created:SetText("Thread")
assert(frame.searchQuery == "thread" and refreshCalls == 5,
  "bag-hide regression setup did not activate search")
assert(not ShirsInventory_ClearSearch(frame) and frame.searchQuery == "thread" and created.text == "Thread" and
  refreshCalls == 5,
  "disabling automatic clear must preserve search when the inventory hides")
assert(ShirsInventory_ClearSearch(frame, true) and frame.searchQuery == "" and created.text == "" and
  refreshCalls == 6 and created.placeholder.shown,
  "forced clearing must ignore the automatic-clear setting")
autoClear = true
created:SetText("Cloth")
assert(ShirsInventory_ClearSearch(frame) and frame.searchQuery == "" and refreshCalls == 8,
  "enabled automatic clear must clear the query when the inventory hides")
assert(not ShirsInventory_ClearSearch(frame) and refreshCalls == 8,
  "clearing an already empty search must be a no-op")

assert(type(ShirsInventory_InstallWorldFrameSearchHook) == "function",
  "world clicks need a chained WorldFrame OnMouseDown hook")
local priorCalls = 0
local worldScripts = {
  OnMouseDown = function() priorCalls = priorCalls + 1 end,
}
WorldFrame = {
  GetScript = function(self, name) return worldScripts[name] end,
  SetScript = function(self, name, handler) worldScripts[name] = handler end,
}
ShirsInventoryFrame = frame
function frame:IsShown() return self.shown ~= false end
assert(ShirsInventory_InstallWorldFrameSearchHook() and
  WorldFrame.shirsInventorySearchHookInstalled,
  "WorldFrame search hook did not install")
local installedHandler = worldScripts.OnMouseDown
assert(ShirsInventory_InstallWorldFrameSearchHook() and worldScripts.OnMouseDown == installedHandler,
  "WorldFrame search hook must be idempotent")

created:SetText("Potion")
created.focused = true
local oldArg1 = arg1
arg1 = "LeftButton"
installedHandler()
assert(priorCalls == 1 and frame.searchQuery == "" and created.text == "" and
  refreshCalls == 10 and created.focused and frame.searchFocusReleasePending,
  "left-clicking WorldFrame must clear text immediately and defer keyboard-focus release")
assert(type(ShirsInventory_ProcessDeferredSearchFocus) == "function",
  "outside clicks need a next-frame keyboard-focus release helper")
assert(ShirsInventory_ProcessDeferredSearchFocus(frame) and not created.focused and
  not frame.searchFocusReleasePending,
  "next-frame processing must release search keyboard focus")
assert(not ShirsInventory_ProcessDeferredSearchFocus(frame),
  "deferred focus release must run exactly once")
created:SetText("Elixir")
created.focused = true
arg1 = "RightButton"
installedHandler()
assert(priorCalls == 2 and frame.searchQuery == "" and refreshCalls == 12 and
  created.focused and frame.searchFocusReleasePending,
  "right-clicking WorldFrame must also defer keyboard-focus release")
assert(ShirsInventory_ProcessDeferredSearchFocus(frame) and not created.focused,
  "right-click deferred processing must release keyboard focus")
created:SetText("Rune")
autoClear = false
arg1 = "LeftButton"
installedHandler()
assert(priorCalls == 3 and frame.searchQuery == "rune" and refreshCalls == 13,
  "WorldFrame clicks must preserve search when automatic clearing is disabled")
autoClear = true
frame.shown = false
arg1 = "RightButton"
installedHandler()
assert(priorCalls == 4 and frame.searchQuery == "rune" and refreshCalls == 13,
  "WorldFrame clicks must ignore hidden inventory")
arg1 = "MiddleButton"
frame.shown = true
installedHandler()
arg1 = oldArg1
assert(priorCalls == 5 and frame.searchQuery == "rune" and refreshCalls == 13,
  "non-left/right WorldFrame buttons must preserve search")

local uiFile = assert(io.open(uiPath, "rb"))
local uiSource = uiFile:read("*a")
uiFile:close()
assert(not string.find(uiSource, ":HasFocus()", 1, true),
  "Interface 11200 search code must not call the unavailable EditBox HasFocus method")
assert(string.find(uiSource, "ShirsInventory_ClearSearch(frame)", 1, true),
  "inventory OnHide must clear the active search")
assert(string.find(uiSource, "ShirsInventory_ClearSearch(frame, true)", 1, true),
  "Escape must force clear independently of the automatic-clear setting")
assert(string.find(uiSource, 'WorldFrame:GetScript("OnMouseDown")', 1, true) and
  string.find(uiSource, 'WorldFrame:SetScript("OnMouseDown"', 1, true),
  "outside-click behavior must chain the proven WorldFrame OnMouseDown path")
assert(not string.find(uiSource, 'IsMouseButtonDown("LeftButton")', 1, true),
  "failed mouse-state polling path must be removed")

print("INVENTORY_SEARCH_TEST=PASS")
