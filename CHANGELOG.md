# Changelog

## 0.8.5

### Fixed

- Right-clicking a bag item while the guild vault is open now deposits it into the open vault tab.
- A vault item you withdraw can now be placed into a bag slot by left-clicking that slot or dragging the item onto it.

Alt+right-click junk marking and Ctrl+right-click pinning do not apply to slots inside the guild vault. That is intended: the vault uses the client's own click handling for its slots. Both clicks still work on your bags.

## 0.8.4

### Fixed

- Holding Shift while a banker dialogue is open now leaves the standard dialogue available instead of selecting the deposit-box option automatically.

## 0.8.3

### Added

- Opening a profession book now records its learned crafts account-wide, allowing matching recipe items on other characters to show **Already known on this account**.
- The selected-item list now supports up to 50 item types instead of 30.

## 0.8.2

### Added

- Shift-click bag items to search in AUX or the stock Auction House while preserving chat-link and stack-split behaviour.
- A separate setting to hide the blue and orange blocked-recipe glows without disabling normal rarity or quest borders.
- Adjustable background opacity and frame layer controls for the inventory and bank, applied immediately.
- A bank-only Category View mode that keeps carried bags in the standard view with their normal sorting and search behaviour.
- Automatic inventory opening when the AUX window opens.

## 0.8.1

### Fixed

- Gray armor and weapons marked as junk now go to Junk instead of staying in their main category.
- Empty Keyring capacity is no longer counted as Empty Slots in Category View.

## 0.8.0

### Added

- Name-based material grouping for Category View, including herbs, cloth, leather, ores, enchanting materials, elementals, engineering parts, and gems when item subtype data is missing.
- A Category gap setting and an Empty Slots button for tighter shelf packing.
- Seven-letter one-item headings and full headings for groups with two or more items.
- Top and Bottom controls for the selected-item list; drag-and-drop reordering remains available.

### Fixed

- Removed the duplicate Collapse Empty Slots option from Category Settings.
- Separated Import status from the Close control.
