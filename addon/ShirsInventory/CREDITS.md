# Credits and source status

The combined inventory UI, junk marking, sale queue, tests, and 1.12 integration were written for Shir's Inventory.

Early private builds used a sorting engine derived from SortBags by shirsig. No redistribution license was found for that source, so it was removed. The current planner and WoW adapter were written for Shir's Inventory and do not include SortBags source or curated item tables.

The header/footer arrangement adapts the general OneBag window structure from Bagshui 1.0.5 by veechs/absir (MIT): compact header actions, footer bag slots and free-space status, and footer money placement. Shir's keeps its own flat-grid renderer, colors, controls, sorting, junk behavior, and item visuals. No Bagshui modules or assets are included. Bagshui's notice is preserved in `THIRD_PARTY_NOTICES.md`.

Bagnon by Tuller/Jaliborc and the McPewPew Vanilla 1.12 lineage were reviewed only as visible product references for a bag strip, compact controls, money display, and bag-provider coexistence. No Bagnon source or assets are included.

The pfUI bag module by Eric Mauser (Shagu) was reviewed as a behavior reference for item-border priority: quality-colored borders first, then a warm gold quest-item fallback. Shir's implementation uses its own thin edge renderer and tuple-safe Vanilla item-info parser; no pfUI code or artwork is included.

Inventorian was discussed only as a product reference. No Inventorian source, assets, or protected expression are included.
