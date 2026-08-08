# Shir's Inventory

A standalone bag addon made and tested for Microbot's WoW 1.12.1 client. It should also work on other WoW 1.12.x clients and private servers, but those have not been tested.

Current release: **0.3.25** — keeps profession tools beside the Hearthstone, handles specialty bags from native metadata, restores the merchant sell cursor, and can group quest-bordered items at the opposite end of the occupied sorted block.

## What it does

- Combines the Backpack and equipped bags into one continuous grid.
- Sorts bags and the bank by item type or rarity.
- Sorts from the top or bottom and merges partial stacks.
- Keeps quest-bordered items at the opposite end of the occupied sorted block by default: last when sorting from the top, or first when sorting from the bottom. This can be disabled in settings.
- Keeps specialty-bag items in compatible bags using the client's item and bag metadata.
- Shows quest and rarity borders, cooldowns, stack counts, money, and normal item tooltips.
- Marks items as junk and sells gray or marked junk through a guarded merchant queue.
- Tracks gold across characters on the same account.
- Lets each character use Shir's full bag window or keep another bag addon and use only the sorting and junk tools.
- Coexists with pfUI, Bagnon, Bagshui, and other replacement bag providers without editing them.

## Download and install

1. Download the ZIP from the [latest release](https://github.com/theShirina/shirs-inventory/releases/latest).
2. Extract the `ShirsInventory` folder into your client's `Interface/AddOns` folder.
3. Restart the client.

The first login asks which parts of the addon to use and which bag UI should own the bag bar if another provider is loaded.

## Commands

- `/si` — toggle the combined inventory.
- `/si sort` — sort carried bags.
- `/si junk` — start a junk sale while a merchant's main tab is open.
- `/si mark <item ID or item link>` — mark an item type as junk.
- `/si unmark <item ID or item link>` — remove a manual junk mark.
- `/si bagui` — reopen the bag-provider choice.
- `/si settings` — open Shir's Inventory settings.

## Source and license

Shir's Inventory is released under the MIT License. See [`CREDITS.md`](addon/ShirsInventory/CREDITS.md) and [`THIRD_PARTY_NOTICES.md`](addon/ShirsInventory/THIRD_PARTY_NOTICES.md) for source and attribution details.
