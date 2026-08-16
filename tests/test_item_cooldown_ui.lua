local uiPath = arg[1]
CreateFrame = nil
assert(loadfile(uiPath))()

assert(ShirsInventory_FormatCooldownRemaining(20 * 60 * 60) == "20h",
  "long item cooldown should use compact hours")
assert(ShirsInventory_FormatCooldownRemaining(90 * 60) == "2h",
  "partial hours should round up")
assert(ShirsInventory_FormatCooldownRemaining(125) == "3m",
  "partial minutes should round up")
assert(ShirsInventory_FormatCooldownRemaining(9.1) == "10",
  "short cooldown should round up to whole seconds")
assert(ShirsInventory_FormatCooldownRemaining(0) == nil,
  "expired cooldown should have no label")

assert(type(ShirsInventory_GetCooldownTextLayout) == "function",
  "cooldown text layout helper is missing")
local cooldownText = ShirsInventory_GetCooldownTextLayout()
assert(cooldownText.font == "GameFontNormalLarge",
  "item cooldown numbers must use GameFontNormalLarge, two stock steps above GameFontNormalSmall")
assert(cooldownText.r == 1 and cooldownText.g == 0.82 and cooldownText.b == 0,
  "cooldown numbers must keep the gold remaining-time color")

local timerCalls = {}
CooldownFrame_SetTimer = function(frame, start, duration, enable)
  table.insert(timerCalls, {frame = frame, start = start, duration = duration, enable = enable})
end

local cooldown = { shown = false }
function cooldown:Show() self.shown = true end
function cooldown:Hide() self.shown = false end

local text = { shown = false, value = nil }
function text:SetText(value) self.value = value end
function text:Show() self.shown = true end
function text:Hide() self.shown = false end

local button = { cooldown = cooldown, cooldownText = text }
ShirsInventory_ApplyItemCooldown(button, 100, 20 * 60 * 60, 1, 100)
assert(table.getn(timerCalls) == 1 and timerCalls[1].start == 100 and
  timerCalls[1].duration == 20 * 60 * 60 and timerCalls[1].enable == 1,
  "active cooldown was not sent to the native cooldown frame")
assert(cooldown.shown and text.shown and text.value == "20h",
  "active cooldown did not show both native overlay and compact label")

local timerWrapSeconds = (2 ^ 32) / 1000
local wrappedNow = 1000
local wrappedDuration = 3 * 24 * 60 * 60
local wrappedRemaining = 19 * 60 * 60
local wrappedStart = timerWrapSeconds + wrappedNow - wrappedDuration + wrappedRemaining
ShirsInventory_ApplyItemCooldown(button, wrappedStart, wrappedDuration, 1, wrappedNow)
assert(text.value == "19h",
  "wrapped Vanilla cooldown start should show 19h instead of about 51d")
assert(button.cooldownEnd == wrappedNow + wrappedRemaining,
  "wrapped cooldown should normalize to the current GetTime clock")

ShirsInventory_ApplyItemCooldown(button, 100, 20 * 60 * 60, 1, 100)
ShirsInventory_UpdateCooldownDisplay(button, 0.10, 100 + 19 * 60 * 60)
assert(text.value == "20h", "cooldown text refreshed before the throttle elapsed")
ShirsInventory_UpdateCooldownDisplay(button, 0.11, 100 + 19 * 60 * 60)
assert(text.value == "1h", "cooldown text did not refresh after the throttle elapsed")

ShirsInventory_UpdateCooldownDisplay(button, 0.21, 100 + 20 * 60 * 60)
assert(not cooldown.shown and not text.shown and button.cooldownEnd == nil,
  "expired cooldown overlay did not clear")

ShirsInventory_ApplyItemCooldown(button, 0, 0, 0, 200)
assert(not cooldown.shown and not text.shown,
  "ready item showed a cooldown overlay")

print("ITEM_COOLDOWN_UI_TEST=PASS")
