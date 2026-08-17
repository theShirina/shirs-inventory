# Bag-sort speed precedents

Date: 14/08/2026
Target: World of Warcraft 1.12.1, Interface 11200, Lua 5.0.3, WoW

## Scope

This review traced cursor scheduling, private-state updates, event gates, delays, slot locks, and post-move checks in other bag sorters. It used pinned source rather than feature lists. No inspected implementation grants a permissive licence for source reuse, so Shir's Inventory uses an original clean-room scheduler.

## Evidence matrix

| Add-on | Pinned evidence | Client fit | Move scheduler | Acknowledgement and failure handling | Licence / use |
|---|---|---|---|---|---|
| SortBags-vanilla | `shirsig/SortBags-vanilla@1b59767ca41749e70d72f2991c27054beebcdfcd`; the installed Interface 11200 `SortBags.lua` matches repository commit `8f7bf57d91a2935600cd5857b29237dcdf9718cf` after line-ending normalisation | Exact Interface 11200 source; installed in the isolated client, but not runtime proof | A throttled `OnUpdate` pass updates a private model and may submit several sort and stack moves in one callback | No `BAG_UPDATE` or `ITEM_LOCK_CHANGED` acknowledgement and no exact final-state gate. Fast, but optimistic. | No licence grant in the pinned tree. Study-only. |
| Cleanup | `shirsig/Cleanup@349434340ecc2b6ec301d7b302032452be05d086` | Exact Interface 11200 historical state | UI and bag-selection layer over SortBags; it does not add a separate executor | Inherits SortBags scheduling and risks | No licence grant in the exact pin. Study-only. |
| Clean_Up | `redshadowz/Clean_Up@5609e8cd349baf43a6c0ad6259cc6f134ec9ba51` | Interface 11200 source; no WoW runtime proof | Builds a private model, runs on `OnUpdate` at 0.25-second intervals, and limits work by passes and attempted submissions | Its README claims timeout protection, but the sorter has no elapsed-time deadline and does not require an exact physical postcondition before later moves | No licence grant in the pinned tree. Study-only. |
| Bag Sort revision 18 | Local archived Interface 11200 source: `Furyswipes_5mmb_Vanilla-main/.../Bag_Sort` | Exact manifest, inactive bundled source only | Attempts the whole swap grid in one callback | No exact acknowledgement, cursor postcondition, or bounded recovery | TOC permits only whole, unaltered redistribution. Study-only. |
| MrPlow | WowAce changeset `9ac91074021c`, version `a/R.4.7.3` | Canonical Interface 11200 source | Coroutine-style queue. A bag-update gate and a fixed delay must both complete before the next swap | Guards cursor pickup/drop and tries rollback, but has no slot-lock polling, exact source/target postcondition, timeout, or bounded retry | WowAce lists All Rights Reserved. Study-only. |
| MrPlow Vanilla mirror | `McPewPew/MrPlow@5c94bceb1a75cfc735b69f34bcaeb252f96a06e0` | TOC is labelled 11200, but the payload comes from later source and has weaker provenance | Removes the fixed timer floor and runs attempts from `OnUpdate` | Shows the throughput value of frame scheduling, but still lacks reliable post-drop validation | No permissive grant found. Architectural evidence only. |
| BankStack | Initial `kemayo/wow-bankstack@de0faf50afbca3f5b2e6185a2e601e3019760a62`; later target-validation design at tag `v12` / commit `a26d66d81a7674600bf6483662a74b83292100f0` | Interface 20200 and 30000; wrong client | Private move queue driven by periodic `OnUpdate`. Later code tracks an expected target, checks locks, and may process several logical moves until a lock or cursor state forces a pause | Expected-target validation is useful precedent, but later APIs and retry assumptions do not fit 1.12 | No licence file; project is listed as All Rights Reserved. Architectural evidence only. |

## Chosen design

`0.6.5-test.6` keeps Shir's immutable target plan and guarded cursor adapter. It uses bounded disjoint progress for clients whose bag APIs remain stale until the Lua callback returns:

1. Submit one complete guarded cursor transaction.
2. Apply it to the private model.
3. Record both physical endpoints as touched for the rest of that rendered frame.
4. Consider another move only when neither endpoint overlaps any accepted move in the burst.
5. Freshly read that candidate's untouched source and destination, and require the expected identity, count, and unlocked state.
6. Stop after four accepted moves, on a shared or changed endpoint, or when the cursor adapter rejects a transaction.
7. Keep the burst's opening signature and combined predicted final signature pending. No later burst starts until a full physical scan matches that exact final state.
8. Repeat burst limits `4, 4, 4, 3`. This lowers theoretical peak submissions by 6.25% without adding a frame-rate-sensitive timer threshold.

The full safety contract stays in force:

- Each later move's own source and destination must still match the private model and be unlocked.
- The cursor must be empty before and after each transaction; cursor transactions do not overlap.
- No physical slot may occur in two accepted transactions in one burst.
- The configured non-pending and rejected-submission interval remains 0.29 seconds; starting a run primes the first update immediately.
- Full pending-state checks retain the 0.01-second minimum interval.
- Unchanged state waits; unexpected state stops as desynchronised after the bounded settling window.
- Combat, bank session, cycle, model, selected-slot, specialty-bag, and 15-second timeout gates remain.

This design takes the throughput lesson from optimistic batch sorters without accepting their unbounded queue or allowing one accepted move to feed another before acknowledgement. It also avoids using `BAG_UPDATE` alone as proof: the event identifies a changed container, not the exact expected postcondition.

## Deterministic result

A 21-slot reverse-order fixture requiring ten cursor moves held physical bag reads at their pre-callback state, then settled accepted moves at each rendered-frame boundary. It compared the installed `0.6.5-test.4` scheduler with the clean-room candidate under Lua 5.0.3 at simulated 60 FPS:

- `0.6.5-test.4`: 11 frames, 0.183 seconds, ten moves, maximum one move per frame.
- `0.6.5-test.5`: 4 frames, 0.067 seconds, ten moves, maximum four moves per frame.
- Frame reduction: 63.64%.
- Repetition: 20/20 identical runs.

This is a scheduler benchmark, not a promise of the same in-game wall-clock gain. A real client may reject a later transaction or produce dependent moves; either condition safely shortens the burst. Isolated-client testing remains required.

The `test.6` safety-pacing fixture uses 79 slots and 39 independent cursor moves with the same delayed physical visibility. At simulated 60 FPS, installed `test.5` completes in 11 frames and `test.6` in 12, a 9.09% increase. The 30, 60, 144, and 240 FPS matrix stays within 9.09–9.68%. Short or dependency-heavy real inventories may change less because cursor moves and rendered frames are discrete.

## Primary sources

- https://github.com/shirsig/SortBags-vanilla/tree/1b59767ca41749e70d72f2991c27054beebcdfcd
- https://github.com/shirsig/Cleanup/tree/349434340ecc2b6ec301d7b302032452be05d086
- https://github.com/redshadowz/Clean_Up/tree/5609e8cd349baf43a6c0ad6259cc6f134ec9ba51
- https://repos.wowace.com/wow/mr-plow/rev/9ac91074021c
- https://repos.wowace.com/wow/mr-plow/raw-file/9ac91074021c/MrPlow.lua
- https://github.com/McPewPew/MrPlow/tree/5c94bceb1a75cfc735b69f34bcaeb252f96a06e0
- https://github.com/kemayo/wow-bankstack/commit/de0faf50afbca3f5b2e6185a2e601e3019760a62
- https://github.com/kemayo/wow-bankstack/tree/a26d66d81a7674600bf6483662a74b83292100f0
- https://raw.githubusercontent.com/shagu/wow-vanilla-api/master/events.md
- https://www.lua.org/manual/5.0/manual.html#5.2
