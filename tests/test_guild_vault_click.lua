-- Guild vault click routing for the combined bag buttons.
--
-- Microbot ships client-side guild banks inside Data/patch-3.mpq. Its patched
-- Interface\FrameXML\FrameXML.toc lists GuildBankFrame.xml, which loads GuildBankVault.lua (the
-- sibling GuildVaultFrame.lua is in the archive but is not in the manifest). GuildBankVault.lua
-- replaces ContainerFrameItemButton_OnClick with GuildVault_ContainerClick and owns two click-driven
-- paths on the stock bag buttons:
--   * plain right-click on a bag item      -> "DEP" deposits it into the open vault tab;
--   * plain left-click while a vault item is held -> "WDR" places that item into the clicked slot.
-- Shir's Inventory hides the native container frames and runs its own item buttons, so those clicks
-- never reach that wrapper. This test loads the addon with a stub that mirrors the loaded wrapper's
-- branch conditions (GuildBankVault.lua:646-670) and checks that the addon forwards exactly those
-- clicks, with bag and slot resolving correctly.
--
-- Usage: lua50 tests/test_guild_vault_click.lua <core> <junk> <ui>

local corePath, junkPath, uiPath = arg[1], arg[2], arg[3]
ShirsInventoryDB = { junkItems = {} }
local chatMessages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) table.insert(chatMessages, text) end }

local altDown, controlDown, shiftDown = false, false, false
local itemPresent = true
local itemCount = 1
local cursorHasItem = false
function IsAltKeyDown() return altDown end
function IsControlKeyDown() return controlDown end
function IsShiftKeyDown() return shiftDown end
function GetContainerItemInfo()
  if not itemPresent then return nil end
  return "texture", itemCount, nil, 2
end
function GetContainerItemLink()
  if not itemPresent then return nil end
  return "|Hitem:7076:0:0:0|h[Essence of Earth]|h"
end
local used, picked = 0, 0
function UseContainerItem() used = used + 1 end
function PickupContainerItem() picked = picked + 1 end
function CursorHasItem() return cursorHasItem end
function ClearCursor() end
function ToggleBackpack() end
MerchantFrame = { selectedTab = 1, IsShown = function() return false end }
function ShowContainerSellCursor() end
function ShowInspectCursor() end
function ResetCursor() end
local splitFrames = 0
function OpenStackSplitFrame() splitFrames = splitFrames + 1 end
-- Client global lookup. The vault and the addon both resolve dynamic names through it.
function getglobal(name) return getfenv(0)[name] end

assert(loadfile(corePath))()
assert(loadfile(junkPath))()
assert(loadfile(uiPath))()

local button = { bag = 0, slot = 1 }

-- Section A: no guild vault anywhere on this client. Behaviour must stay exactly as before.
assert(GuildVault_ContainerClick == nil and GuildBankFrame == nil,
  "the vault-free section must run before the vault stub is defined")
assert(ShirsInventory_HandleItemClick(button, "RightButton") and used == 1 and picked == 0,
  "without a guild vault a plain right-click must keep the native use behaviour")
altDown = true
assert(ShirsInventory_HandleItemClick(button, "RightButton") and ShirsInventoryDB.junkItems[7076],
  "without a guild vault Alt-right-click must still mark junk")
altDown = false
controlDown = true
assert(ShirsInventory_HandleItemClick(button, "RightButton") and ShirsInventory_GetHearthstoneItemIndex(7076) == 1,
  "without a guild vault Ctrl-right-click must still select beside Hearthstone")
controlDown = false
assert(ShirsInventory_HandleItemClick(button, "LeftButton") and picked == 1,
  "without a guild vault a plain left-click must keep the native pickup behaviour")
assert(ShirsInventory_GetHearthstoneItemIndex(7076) == 1,
  "the vault-free section changed the selected item list")
ShirsInventory_SetLockSelectedItemSlots(false)

-- Section B: the vault stub, mirroring the loaded GuildBankVault.lua wrapper.
GUILDVAULT_AUTO = 255
GUILDVAULT_EMPTY = "0:0:0:0"
GUILDVAULT_ERRORS = { [16] = "The guild vault is full." }

GuildVault = { current = 0, tabCount = 6, held = nil }
local vaultVisible = true
GuildBankFrame = {
  mode = "bank",
  IsVisible = function() return vaultVisible end,
}
function GuildVault_Mode() return GuildBankFrame and GuildBankFrame.mode or "bank" end
local sent, vaultErrors = {}, {}
function GuildVault_Send(text) table.insert(sent, text) end
function GuildVault_Error(text) table.insert(vaultErrors, text) end
function GuildVault_ClearHeld()
  if GuildVault.held then GuildVault.held = nil end
end
local originalCalls = 0
GuildVault_OriginalContainerClick = function() originalCalls = originalCalls + 1 end

local forwardCalls, forwardedButton, forwardedIgnore, forwardedBag, forwardedSlot = 0
function GuildVault_ContainerClick(clickButton, ignoreMods)
  forwardCalls = forwardCalls + 1
  forwardedButton, forwardedIgnore = clickButton, ignoreMods
  if GuildBankFrame:IsVisible() and GuildVault_Mode() == "bank" then
    local bag = this:GetParent():GetID()
    local slot = this:GetID()
    forwardedBag, forwardedSlot = bag, slot
    local modified = not ignoreMods and (IsShiftKeyDown() or IsControlKeyDown())
    if GuildVault.held then
      local held = GuildVault.held
      GuildVault_ClearHeld()
      if not modified then
        if clickButton == "LeftButton" then
          GuildVault_Send("WDR " .. held.tab .. " " .. held.slot .. " " .. held.count .. " " .. bag .. " " .. slot .. " " .. held.seen)
        end
        return
      end
    elseif clickButton == "RightButton" and not modified and not CursorHasItem() then
      if GuildVault.current >= GuildVault.tabCount then
        GuildVault_Error(GUILDVAULT_ERRORS[16])
      elseif GetContainerItemInfo(bag, slot) then
        GuildVault_Send("DEP " .. bag .. " " .. slot .. " 0 " .. GuildVault.current .. " " .. GUILDVAULT_AUTO .. " " .. GUILDVAULT_EMPTY)
      end
      return
    end
  end
  GuildVault_OriginalContainerClick(clickButton, ignoreMods)
end
local vaultHandler = GuildVault_ContainerClick

local function resetCounters()
  sent, vaultErrors = {}, {}
  forwardCalls, forwardedButton, forwardedIgnore, forwardedBag, forwardedSlot = 0
  originalCalls = 0
end

-- Plain right-click while the vault is open must deposit the carried item.
resetCounters()
used, picked = 0, 0
button.bag, button.slot = 0, 1
assert(ShirsInventory_HandleItemClick(button, "RightButton"),
  "right-click on a carried item was not handled while the guild vault was open")
assert(forwardCalls == 1, "right-click did not reach the guild vault click handler")
assert(forwardedBag == 0 and forwardedSlot == 1,
  "the guild vault received the wrong bag and slot for a right-click deposit")
assert(forwardedButton == "RightButton",
  "the guild vault received the wrong mouse button for a right-click deposit")
assert(forwardedIgnore == nil,
  "the guild vault received a modifier flag the click did not carry")
assert(sent[1] == "DEP 0 1 0 0 255 0:0:0:0",
  "right-click did not ask the guild vault to deposit the item (got '" .. tostring(sent[1]) .. "')")
assert(originalCalls == 0,
  "a deposit must not fall through to GuildVault_OriginalContainerClick")
assert(used == 0 and picked == 0,
  "a deposit must not also use or pick up the item")

-- A second bag and slot must resolve through the same path.
resetCounters()
button.bag, button.slot = 3, 12
assert(ShirsInventory_HandleItemClick(button, "RightButton") and
  forwardedBag == 3 and forwardedSlot == 12 and
  sent[1] == "DEP 3 12 0 0 255 0:0:0:0",
  "the guild vault received the wrong bag and slot for a later deposit")
button.bag, button.slot = 0, 1

-- Left-click while a vault item is held must place it into the clicked bag slot.
resetCounters()
GuildVault.held = { tab = 2, slot = 40, count = 0, seen = "seen-40" }
used, picked = 0, 0
button.bag, button.slot = 4, 9
assert(ShirsInventory_HandleItemClick(button, "LeftButton"),
  "left-click on a carried slot was not handled while a withdrawn vault item was held")
assert(forwardCalls == 1 and forwardedButton == "LeftButton",
  "placing a withdrawn vault item did not reach the guild vault click handler as a left-click")
assert(forwardedBag == 4 and forwardedSlot == 9,
  "the guild vault received the wrong bag and slot when placing a withdrawn item")
assert(sent[1] == "WDR 2 40 0 4 9 seen-40",
  "left-click did not ask the vault to place the withdrawn item (got '" .. tostring(sent[1]) .. "')")
assert(GuildVault.held == nil, "placing a withdrawn item must clear the vault held state")
assert(originalCalls == 0,
  "placing a withdrawn item must not fall through to GuildVault_OriginalContainerClick")
assert(picked == 0, "placing a withdrawn item must not also pick up the bag item")
button.bag, button.slot = 0, 1

-- A withdrawn item can land in an empty carried slot.
resetCounters()
GuildVault.held = { tab = 1, slot = 3, count = 0, seen = "seen-3" }
itemPresent = false
assert(ShirsInventory_HandleItemClick(button, "LeftButton") and
  sent[1] == "WDR 1 3 0 0 1 seen-3",
  "a withdrawn vault item could not be placed into an empty bag slot")
assert(GuildVault.held == nil, "placing into an empty slot must clear the vault held state")
itemPresent = true

-- Shift or Ctrl held must never deposit or place; the addon keeps its own meaning.
resetCounters()
used, picked = 0, 0
shiftDown = true
assert(ShirsInventory_HandleItemClick(button, "RightButton") and forwardCalls == 0 and used == 1,
  "Shift+right-click while the vault was open did not keep the addon's own behaviour")
shiftDown = false
controlDown = true
assert(ShirsInventory_HandleItemClick(button, "RightButton") and forwardCalls == 0,
  "Ctrl+right-click while the vault was open did not keep the addon's own behaviour")
controlDown = false
shiftDown = true
itemCount = 3
GuildVault.held = { tab = 1, slot = 3, count = 0, seen = "seen-3" }
local splitsBefore = splitFrames
assert(ShirsInventory_HandleItemClick(button, "LeftButton") and forwardCalls == 0 and
  splitFrames == splitsBefore + 1,
  "Shift+left-click must keep the addon's own stack-split behaviour, not place a withdrawn vault item")
shiftDown = false
itemCount = 1
assert(GuildVault.held ~= nil, "a blocked click must leave the vault held state untouched")
GuildVault.held = nil

-- A right-click while a vault item is held keeps the stock wrapper's clear-and-return behaviour.
resetCounters()
GuildVault.held = { tab = 5, slot = 2, count = 0, seen = "seen-2" }
used, picked = 0, 0
assert(ShirsInventory_HandleItemClick(button, "RightButton") and forwardCalls == 1 and
  table.getn(sent) == 0 and GuildVault.held == nil,
  "a right-click while a vault item was held did not keep the stock wrapper's own behaviour")
assert(used == 0 and picked == 0,
  "clearing a held vault item must not use or pick up the bag item")

-- Alt+right-click stays the addon's junk marking even while the vault is open.
resetCounters()
ShirsInventoryDB.junkItems[7076] = nil
altDown = true
assert(ShirsInventory_HandleItemClick(button, "RightButton") and forwardCalls == 0 and
  ShirsInventoryDB.junkItems[7076],
  "Alt-right-click marking was swallowed by the guild vault deposit path")
altDown = false
ShirsInventoryDB.junkItems[7076] = nil

-- A cursor-held item must fall through to the addon path, not to a deposit.
resetCounters()
cursorHasItem = true
assert(ShirsInventory_HandleItemClick(button, "RightButton") and forwardCalls == 0,
  "a right-click with an item already on the cursor must not deposit")
cursorHasItem = false

-- A client that does not expose CursorHasItem must never be routed into the vault.
resetCounters()
local savedCursorHasItem = CursorHasItem
CursorHasItem = nil
assert(ShirsInventory_HandleItemClick(button, "RightButton") and forwardCalls == 0,
  "a click path without CursorHasItem must not reach the guild vault")
CursorHasItem = savedCursorHasItem

-- A vault that is hidden or not showing its item tab must leave every click alone.
resetCounters()
used, picked = 0, 0
vaultVisible = false
assert(ShirsInventory_HandleItemClick(button, "RightButton") and forwardCalls == 0 and used == 1,
  "a hidden guild vault must not claim bag clicks")
vaultVisible = true
GuildBankFrame.mode = "tabinfo"
assert(ShirsInventory_HandleItemClick(button, "RightButton") and forwardCalls == 0 and used == 2,
  "the guild vault must not claim bag clicks outside its bank item view")
GuildBankFrame.mode = "bank"
GuildVault = nil
assert(ShirsInventory_HandleItemClick(button, "RightButton") and forwardCalls == 0 and used == 3,
  "a partial guild vault without its state table must not claim bag clicks")
GuildVault = { current = 0, tabCount = 6, held = nil }

-- Bank slots never belong to the vault deposit path.
resetCounters()
button.bag, button.slot = -1, 4
assert(ShirsInventory_HandleItemClick(button, "RightButton") and forwardCalls == 0 and used == 4,
  "a bank item click must not be forwarded to the guild vault")
button.bag, button.slot = 0, 1

-- A full vault tab keeps the addon's own path free of the vault's error line.
resetCounters()
GuildVault.current = 6
assert(ShirsInventory_HandleItemClick(button, "RightButton") and forwardCalls == 1 and
  table.getn(vaultErrors) == 1 and used == 4,
  "a full vault tab must still route the deposit click to the vault's own refusal")
GuildVault.current = 0

-- The addon must never replace the vault's globals.
assert(GuildVault_ContainerClick == vaultHandler,
  "the addon replaced the guild vault click handler instead of chaining to it")
assert(GuildVault_OriginalContainerClick ~= nil,
  "the addon removed the guild vault's original click handler")

-- A deposit that fails inside the vault must not corrupt the addon's `this`.
resetCounters()
local savedOriginal = GuildVault_OriginalContainerClick
GuildVault_ContainerClick = function() error("vault failure") end
local previousThis = this
this = "saved-this"
assert(ShirsInventory_HandleItemClick(button, "RightButton"),
  "a failing vault handler must not abort the addon click path")
assert(this == "saved-this", "a failing vault handler must restore the global this")
this = previousThis
GuildVault_ContainerClick = vaultHandler

local uiSource = assert(io.open(uiPath, "rb")):read("*a")
assert(string.find(uiSource, "GuildVault_ContainerClick", 1, true) and
  string.find(uiSource, "GuildBankFrame", 1, true) and
  string.find(uiSource, "GuildVault_Mode", 1, true),
  "the item click path does not resolve the guild vault globals")

print("GUILD_VAULT_CLICK_TEST=PASS")