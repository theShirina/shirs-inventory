# Credits and source status

The combined inventory UI, junk marking, sale queue, tests, and 1.12 integration were written for Shir's Inventory.

Early private builds used a sorting engine derived from SortBags by shirsig. No redistribution license was found for that source, so it was removed. The current planner and WoW adapter were written for Shir's Inventory and do not include SortBags source or inherited item tables. Small item-ID mappings cover profession tools, WoW field services, WoW's four world-buff scrolls, and specialty-bag eligibility for herbs and enchanting materials. The specialty data is checked against pinned WoW cache evidence and the MIT-licensed WoW Classic Items database; every shipped ID is tested in this repository.

The header/footer arrangement, virtual category-edit interaction, and broader category concepts adapt general ideas from Bagshui 1.0.5 by veechs/absir (MIT): compact header actions, footer bag slots and free-space status, footer money placement, an edit mode that assigns item IDs without picking up physical bag slots, and deterministic visual groups for common item kinds. Shir's uses its own small classifier over runtime item metadata plus conservative enUS name/tooltip signals. It does not include Bagshui modules, rules, profiles, category lists, item catalogues, data, or assets. Bagshui's notice is preserved in `THIRD_PARTY_NOTICES.md`.

Bagnon by Tuller/Jaliborc and the McPewPew Vanilla 1.12 lineage were reviewed only as visible product references for a bag strip, compact controls, money display, and bag-provider coexistence. No Bagnon source or assets are included.

The pfUI bag module by Eric Mauser (Shagu) was reviewed as a behavior reference for item-border priority: quality-colored borders first, then a warm gold quest-item fallback. Shir's implementation uses its own thin edge renderer and tuple-safe Vanilla item-info parser; no pfUI code or artwork is included.

Inventorian was discussed only as a product reference. No Inventorian source, assets, or protected expression are included.
