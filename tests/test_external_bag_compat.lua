local corePath, junkPath, uiPath = arg[1], arg[2], arg[3]

ShirsInventoryDB = {
  setupComplete = true,
  features = { bagUI = false, sorter = true, junk = true },
  junkItems = {},
}
local messages = {}
DEFAULT_CHAT_FRAME = {
  AddMessage = function(_, text) table.insert(messages, text) end,
}
SlashCmdList = {}

assert(loadfile(corePath))()
assert(loadfile(junkPath))()
assert(loadfile(uiPath))()

assert(type(ShirsInventory_HandleSlashCommand) == "function",
  "provider-independent slash-command handler is missing")
assert(ShirsInventory_HandleSlashCommand("mark 2454"),
  "manual mark command was rejected")
assert(ShirsInventory_GetJunkItems()[2454] == true,
  "manual mark command did not persist the item ID")
assert(ShirsInventory_HandleSlashCommand("unmark |cff1eff00|Hitem:2454:0:0:0|h[Elixir]|h|r"),
  "manual unmark command rejected an item link")
assert(ShirsInventory_GetJunkItems()[2454] == nil,
  "manual unmark command did not clear the item ID")
assert(not ShirsInventory_HandleSlashCommand("mark not-an-item"),
  "invalid manual mark command must fail")
assert(table.getn(messages) > 0,
  "slash-command fallback should report its result in chat")

print("EXTERNAL_BAG_COMPAT_TEST=PASS")
