local settingsPath = arg[1]
local source = assert(io.open(settingsPath, "rb")):read("*a")
assert(string.find(source, 'event == "MERCHANT_SHOW"', 1, true), "settings driver does not handle MERCHANT_SHOW")
assert(string.find(source, "ShirsInventory_StartAutoJunkSale", 1, true), "merchant event does not dispatch auto-sell")
assert(string.find(source, "Auto-sell gray + manually marked items at vendors", 1, true), "settings UI is missing the explicit auto-sell option")
print("AUTO_SELL_VENDOR_EVENT_TEST=PASS")
