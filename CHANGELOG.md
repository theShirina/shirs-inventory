## Shir's Inventory 0.8.0

**Category View is the star this release.** Scrolling finally works everywhere over the window, junk and blocked recipes show their own clear marks, materials split into real groups, and the packing and list controls tightened up.

### Category View

- Mouse-wheel scrolling now works anywhere over the window (item slots, headings, scrollbar, footer), not just the thin scrollbar strip.
- Materials split into **Mining, Herbs, Cloth, Leather, Enchanting, Elemental, Engineering**, and **Gems** instead of one Trade Goods pile. It even reads item names when the client leaves subtype blank, so herbs, cloth, ores, dusts, and essences land in the right group.
- One-item headings keep seven letters (e.g. **Other C**, **Very Lo**); groups with two or more items keep the full name. Hover a short heading for the full name and count.
- Category Settings gained a **Category gap** slider: 1 empty slot between groups (default) or 0 to pack shelves tighter. Import status moved beside Close so nothing overlaps, and the duplicate Collapse Empty Slots checkbox was removed.
- The **Empty Slots** button on the inventory bar collapses or shows every empty slot without opening Settings.
- Junk-marked items land in a **Junk** group instead of their item type.

### Recipes and cooldowns

- Recipes you cannot learn stand out: **Already known** gets a bright-blue frame and glow; **skill too low** gets orange. Learnable recipes keep their normal border.
- "Already known" recipes are remembered account-wide, so another character with the skill sees the same blue mark; a character below the skill still gets orange. `/reload` once after learning.
- Cooldown numbers are larger.

### Selected-item list

- **Top** and **Bottom** buttons replace Up/Down, so you can jump an item to either end without dragging. Drag still reorders.
- Automatic Hearthstone anchoring still works, and Ctrl-right-click a carried item to add or remove it.

### Install

Download the ZIP from the v0.8.0 release page, extract `ShirsInventory` into `Interface/AddOns`, and restart the client.

Please report any issues on GitHub or Discord. Live testing happened on the Keybind Display Test client; the main client was not changed.
