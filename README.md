# Shir's Inventory

A standalone bag addon for WoW 1.12 clients.

Current release: **0.8.1**.

## What's new in 0.8.1

- Improved junk and Keyring categorization in Category View.
- Kept junk-marked items in the intended Junk group and handled Keyring items more reliably.

## What's new in 0.8.0


- One-item Category View headings now keep seven letters, such as **Other C** or **Very Lo**. Groups with two or more items still keep the full name.
- The selected-item list uses **Top** and **Bottom** instead of Up/Down. Drag still reorders.
- Category Settings has a **Category gap** slider: 1 empty slot between groups, or 0 to pack them tighter.

## What's new in 0.7.9

- Category View now splits herbs, cloth, leather, ores, enchanting dusts/essences, gems, and elementals even when the client leaves item subtype blank. Those used to stay in Trade Goods & Materials.
- Category View has an Empty Slots button on the inventory bar. It collapses or shows every empty slot without opening Category Settings.

## What's new in 0.7.8

- Category headings keep their full name once a group has two or more items. A one-item custom category now shows the first word of its name instead of a `C3` code; hover still shows the full name.
- Default Category View materials now split into Mining, Herbs, Cloth, Leather, Enchanting, Elemental, Engineering, and Gems. Unclassified trade goods stay in Trade Goods & Materials.

## What's new in 0.7.7

- Item cooldown numbers use `GameFontNormalLarge`, one more stock font step than 0.7.6.
- Recipes marked **Already known** on any character are remembered on the account. Another character with the skill sees the same blue known mark; a character below the skill still gets the orange **skill too low** mark. Live testing still needs a `/reload` on the WoW 1.12 client after learning a recipe on one character and opening bags on another.

## What's new in 0.7.6

- Item cooldown numbers use `GameFontNormal` instead of `GameFontNormalSmall`, one stock font step larger.

## What's new in 0.7.5

- Unlearnable recipe marks are stronger: **Already known** is a thick bright-blue frame with a blue glow over the icon; **skill too low** is a thick orange frame with an orange glow. The old 1-pixel teal/amber look blended into green rarity.

## What's new in 0.7.4

- Recipes you cannot learn now stand out in the bags: **Already known** uses a teal wash and teal edges; **skill too low** uses an amber wash and amber edges.
- Learnable recipes keep their normal rarity or quest border. Live testing still needs a `/reload` on the WoW 1.12 client with one known recipe and one too-high skill recipe in bags.

## What's new in 0.7.3

- Category View now turns mouse-wheel events on for the window, scrollbar, item slots, headings, bag bar, search box, and footer buttons. Vanilla ignores the wheel unless that flag is set, which is why scrolling still felt dead after the last pass.
- Junk-marked items now show a gold coin in the top-left of the slot instead of a small red **J**.

## What's new in 0.7.2

- Mouse-wheel scrolling now works anywhere over the Category View, not just on the thin scrollbar strip: item slots and category headings forward the wheel to the same scroll path.
- Items you mark as junk with the junk function now land in the **Junk** category instead of their item type; clearing the mark restores the normal category.

## What's new in 0.7.1

- Category View keeps the window at your chosen scale instead of shrinking when the packed shelves are taller than the screen, and gains a vertical scrollbar plus mouse-wheel scrolling for tall layouts.
- Expanding or collapsing Empty Slots no longer changes the rendered size, only the scroll range.
- Live testing covered the scrollbar and wheel with the current inventory; the full overflow range could not be exercised with the items on hand. Please report any issues on GitHub.

## What it does

- Combines the Backpack and equipped bags into one continuous grid.
- Offers an optional reload-gated category view that groups carried slots into Quest Items, Keys, Mounts & Companions, Armor, Weapons, Bags, Projectiles & Ammo, Recipes, Food & Drink, Potions, Elixirs & Buffs, Bandages, Scrolls, Weapon Buffs, Other Consumables, Explosives, Mining, Herbs, Cloth, Leather, Enchanting, Elemental, Engineering, Gems, Trade Goods & Materials, Junk, Miscellaneous, and Empty Slots without moving items. Small consecutive groups share horizontal shelf rows with one blank item-space between categories and flow into unused space on the right; groups that do not fit move intact to the next shelf, while large groups wrap within the full selected inventory width. The window keeps the chosen scale and gains a vertical scrollbar when the packed shelves are taller than the screen, so a tall layout scrolls instead of shrinking. Groups with two or more items keep their full heading. A one-item group may use a short heading such as **Other**, **Mats**, or **Pets**, and a one-item custom category uses the first word of its name instead of a `C3` code; hovering any shortened heading shows its full category name and count. When Empty Slots is collapsed to one representative, that indicator sits at the far right of its shelf and its narrow heading reads only **Empty**; the full free-slot count remains on the indicator and footer. English-only name and tooltip signals drive the fine consumable and collectible groups; unsupported locales fall back to localized client item types and broader groups instead of matching English text. Copies of the same item ID stay next to each other inside a visual category. Its Edit button lets each character drag an item type onto a heading to override its visual group; right-clicking that item in edit mode restores automatic placement. The Manage button toggles a movable Category Settings panel with separate Custom Categories, Display, and Import from Character sections. It creates or deletes up to 12 per-character custom categories, can show every real empty slot or collapse Empty Slots to one representative slot with the full count, and remembers its screen position per character. A two-click confirmed account import can replace the current character's custom categories, item assignments, and Empty Slots display choice with a validated snapshot from another character that has logged in with this build; it does not move items or import the source character's panel position or Category View enabled state. Deleting a category returns its items to automatic placement. These controls do not sort slots or mark items as junk. The bank keeps its normal layout.
- Adds Keyring slots to that grid with a fixed Keyring button in the add-on's bag bar.
- Filters the visible inventory by item name without moving slots; nonmatching items dim until the search is cleared.
- Can clear either search when its window closes or the player clicks outside; Escape always clears it.
- Lets each character click the Keyring button to hide or show Keyring slots.
- Replaces the normal or pfUI bank window with one combined view of the main bank and equipped bank bags.
- Gives the bank its own item-name search; nonmatching bank items dim without moving slots.
- Keeps the bank query when clicking inside either Shir's Inventory window; Escape or an enabled outside/close clear removes it.
- Shows the native bank-bag slots and the next bank-slot purchase button.
- Gives the bank the same Sort, grouping, direction, and Settings controls as the inventory.
- Sorts bags and the bank by item type or rarity.
- Keeps standard enchanting dust, essences, and shards together when sorting by item type.
- Keeps Token of Mastery and the four WoW raid tokens together when sorting by item type.
- Inserts Shift-clicked item links into the focused WIM whisper.
- Sorts from the top or bottom and merges partial stacks.
- Can submit pairwise-disjoint cursor moves in a repeating `4, 4, 4, 3` safety cycle. Each later move needs fresh identity, count, and lock checks on its own untouched endpoints; dependent moves wait for the prior burst's combined exact bag signature with a 0.01-second minimum check interval.
- Keeps quest-bordered items at the opposite end of the occupied sorted block by default, with conjured items directly outside them.
- Always anchors Hearthstone; Automatic mode adds Onyxia Scale Cloak, field services, pets and mounts, and profession tools at the same edge.
- Lets each character switch to Selected mode and Ctrl-right-click up to 30 carried item types to place them directly beside Hearthstone. The manager has a visible `::` drag grip, source and drop-target feedback, Up/Down controls, remove, clear-all, and paging. Bank sorting stays unchanged.
- Can instead lock every carried slot occupied by a selected item type. Locked slots and stacks stay fixed while all other slots sort around them; bank sorting stays unchanged.
- Keeps the four WoW world-buff scrolls next to each other in either sort mode and direction.
- Sorts herbs and enchanting materials into their matching specialty bags while keeping incompatible profession reagents in normal bags.
- Keeps quiver, ammo-pouch, and soul-bag items in compatible bags.
- Shows quest and rarity borders, native cooldown sweeps with compact remaining-time labels, stack counts, money, and normal item tooltips.
- Marks items as junk and sells gray or marked junk through a guarded merchant queue.
- Adds a bordered Sell Junk icon beside the merchant repair buttons.
- Tracks gold across characters on the same account.
- Tracks every carried and banked item across characters on the same account and shows the location totals in item tooltips.
- Can hide same-account owned-item details while the player is in combat.
- Refreshes carried items at login and on bag changes; bank snapshots refresh whenever each character opens the bank.
- Lets each character choose 10–20 items per row and scale the inventory and bank windows from 65% to 100%, with automatic viewport fitting.
- Keeps valid inventory positions near the top and right screen edges after closing and reopening the bags.
- Ships as one full suite: combined bags, sorting, and junk tools stay enabled together.
- Reclaims the bag bar from other loaded bag replacements; running two bag UIs together is not supported.

## Download and install

1. Download the ZIP from the [v0.8.1 release page](https://github.com/theShirina/shirs-inventory/tree/v0.8.1).
2. Extract the `ShirsInventory` folder into your client's `Interface/AddOns` folder.
3. Restart the client.

Shir's Inventory takes ownership of the bag bar when it loads.

## Commands

- `/si` — toggle the combined inventory.
- `/si sort` — sort carried bags while standard inventory view is active.
- `/si junk` — start a junk sale while a merchant's main tab is open.
- `/si mark <item ID or item link>` — mark an item type as junk.
- `/si unmark <item ID or item link>` — remove a manual junk mark.
- `/si pin <item ID or item link>` — add an item type to the selected list.
- `/si unpin <item ID or item link>` — remove an item type from the selected list.

Selected mode places listed item types beside Hearthstone. When selected-slot locking is enabled, matching carried slots stay fixed instead.
- `/si settings` — open Shir's Inventory settings.
- `/si bank` — reopen the combined bank window while the normal bank is open.

## Source and license

Shir's Inventory is released under the MIT License. See [`CREDITS.md`](addon/ShirsInventory/CREDITS.md) and [`THIRD_PARTY_NOTICES.md`](addon/ShirsInventory/THIRD_PARTY_NOTICES.md) for source and attribution details.
