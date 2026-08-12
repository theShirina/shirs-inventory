# Shir's Inventory

A standalone bag addon made and tested for Microbot's WoW 1.12.1 client.

Current release: **0.6.1**.

## What it does

- Combines the Backpack and equipped bags into one continuous grid.
- Replaces the normal or pfUI bank window with one combined view of the main bank and equipped bank bags.
- Shows the native bank-bag slots and the next bank-slot purchase button.
- Gives the bank the same Sort, grouping, direction, and Settings controls as the inventory.
- Sorts bags and the bank by item type or rarity.
- Keeps standard enchanting dust, essences, and shards together when sorting by item type.
- Keeps Token of Mastery and the four Microbot raid tokens together when sorting by item type.
- Inserts Shift-clicked item links into the focused WIM whisper.
- Sorts from the top or bottom and merges partial stacks.
- Waits for each exact bag-state update before submitting the next cursor move.
- Keeps quest-bordered items at the opposite end of the occupied sorted block by default, with conjured items directly outside them.
- Keeps Hearthstone, field services, adjacent pets and mounts, and profession tools together at the selected edge.
- Keeps the four Microbot world-buff scrolls next to each other in either sort mode and direction.
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
- Ships as one full suite: combined bags, sorting, and junk tools stay enabled together.
- Reclaims the bag bar from other loaded bag replacements; running two bag UIs together is not supported.

## Download and install

1. Download the ZIP from the [v0.6.1 release page](https://github.com/theShirina/shirs-inventory/releases/tag/v0.6.1).
2. Extract the `ShirsInventory` folder into your client's `Interface/AddOns` folder.
3. Restart the client.

Shir's Inventory takes ownership of the bag bar when it loads.

## Commands

- `/si` — toggle the combined inventory.
- `/si sort` — sort carried bags.
- `/si junk` — start a junk sale while a merchant's main tab is open.
- `/si mark <item ID or item link>` — mark an item type as junk.
- `/si unmark <item ID or item link>` — remove a manual junk mark.
- `/si settings` — open Shir's Inventory settings.
- `/si bank` — reopen the combined bank window while the normal bank is open.

## Source and license

Shir's Inventory is released under the MIT License. See [`CREDITS.md`](addon/ShirsInventory/CREDITS.md) and [`THIRD_PARTY_NOTICES.md`](addon/ShirsInventory/THIRD_PARTY_NOTICES.md) for source and attribution details.
