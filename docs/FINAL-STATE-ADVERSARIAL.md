# Independent state, search and runtime-data review

This review independently exercised the integrated production modules through
their registered event handlers. The reviewer did not edit production Lua.
The source target is official Forever 1.60.1.70374, interface 16001, pinned at
`735496de78ebd30ce816a0637982c556987f258c`. Results below are offline operation
counts and source evidence, not observed game CPU, native rendering or taint
certification.

## Actual event and request ownership

Receiving `QUEST_LOG_UPDATE` does not request a server refresh. `QuestState`
reads the current shown log IDs and their membership/completion booleans, then
compares them with its previous snapshot. It retains previously observed
collapsed entries until `IsOnQuest` confirms removal. It never expands headers
or reads objective counters: those counters are not displayed by this browser.
When neither search nor inspection is visible, observation marks the baseline
stale without reading the log. Opening either surface primes its baseline.

| Owner and input | Reason and resulting work |
| --- | --- |
| `QuestState`: `QUEST_LOG_UPDATE` | Detect actual added/removed IDs, completion transitions and changed current native offers. Unchanged snapshots dispatch nothing. |
| `QuestState`: `QUEST_ACCEPTED` | Update the accepted exact ID promptly. The 70374 contract supplies quest ID as the first payload, not a log index. Repeated explicit signals are bounded and deduplicated. |
| `QuestState`: `QUEST_REMOVED`, `QUEST_TURNED_IN` | Reconsider the removed quest and dependent chains; turn-in also changes completion history. |
| Sources/Core: gossip, marker and zone changes | Recheck current native offer proof. Repeating the same source/offer map does not dispatch a change. An expired fresh checker cannot revive an old raw proof. |
| Search: `QUEST_DATA_LOAD_RESULT` | Recheck only that record's native title/difficulty and relevant reward signature. Compare before/after relevance so a newly hydrated level can enter the range. Identical data does not rebuild results. |
| Search: item-data callbacks | Recover pending or changed item metadata used by reward filters and icons; preserve native tooltip-data handling as a separate owner. |
| Search: level and zone events | Compare level/map context separately. Level changes update an automatic range; zone changes affect current-zone ordering and offer proof. A manual level range is preserved. |
| Search: equipment, spell and skill events | Reconsider class/skill usability and equipment-slot filters. Bursts coalesce; background changes do not close a native menu. |
| Search: scale/display events | Refit owned UI without replacing Blizzard scripts or protected layout. |

Only `Rewards.Request` and Search's owned request queue call
`RequestLoadQuestByID`, `RequestPreloadRewardData` or item-data load APIs. These
hydrate missing metadata; they do not accept, abandon, complete or refresh the
player's quest log. Search serves at most two item requests and two alternating
quest/reward requests per 0.1-second step. Requests are deduplicated per opening;
the queue and updater stop while hidden. Dirty results coalesce for 0.15 seconds
and wait for an open menu or active item inspection to finish.

## Findings and re-review

1. **Missed dependent unlock:** the first reverse index passed numeric ID arrays
   to a helper for quest-row objects, silently discarding dependencies. A single
   reverse hop also missed verified alternative prerequisite paths. The owner
   changed this to validated numeric lists and bounded reverse traversal. The
   independent saved-module probe leaves the dependent quest absent after the
   alternate is turned in; manual refresh reveals it. The repaired module
   reveals it with one scheduled query.
2. **Broad quest-data rebuilds:** identical callbacks for a warm, out-of-range
   quest still invalidated caches and rebuilt the entire finder. The owner added
   single-record metadata comparison, before/after relevance and reward
   signatures. Re-review covers an unchanged in-range quest, an out-of-range
   quest, native zero rewards, positive XP arriving later and changing XP amounts.
3. **Expired native proof:** Lua's `check and result or oldProof` expression
   resurrected `native-map-available` when a checker returned nil/false while
   its owner remained valid. Both `QuestState` consumers now use an explicit
   checker branch. The independent failure probe passes for nil and false.
   Current native pin constructors generally create checker-only rows; this
   establishes the dual-field proof contract, not a claimed live stale marker.
4. **Duplicate item callbacks:** repeated ready item callbacks still rebuilt
   results, and an older sustained-burst test expected that churn. The owner
   added per-item metadata comparison and affected-quest relevance checks.
   Re-review confirms identical paired callbacks preserve the cached object
   and do no finder work; changed slot/name/quality metadata still refreshes
   the matching filter once. Hidden callbacks do not query native item getters.
5. **Cleared sole marker proof:** clearing the current source did not notify
   the state observer, leaving a finder row visible until an unrelated event
   triggered a query. The source owner now notifies only when it actually clears
   the current source. Independent re-review confirms that a quest with no
   recorded start path appears with the native marker proof and promptly leaves
   the finder when that sole proof is cleared. A further registered combat-event
   probe caught Core bypassing that notification with a direct assignment.
   Core settings, mouseover and event teardowns now use the shared clear path;
   the combat probe verifies removal without waiting for another quest event.

The installed XPIsland and AsTheCrowFlies dropdown constructors were inspected
alongside the pinned native `DropdownButton` implementation. Native mouse-down
owns opening/toggling and the menu manager owns dismissal. A modeled owned menu
closes under the previous log-event handler; the integrated handler leaves it
open and refreshes once after deliberate release. No custom mouse-up toggle is
needed.

## Measured operation counts

The same five-record fixture, Lua 5.1 runtime and event sequence were applied to
the previous committed modules and the integrated modules. Metadata calls count
record checks, including inexpensive warm cache checks; they are not server
requests. Each scenario starts from a settled browser.

| Input | Previous queries/renders | Integrated queries/renders |
| --- | ---: | ---: |
| 200 unchanged log events | 200 / 200 | 0 / 0 |
| 200 ordinary progress events with unchanged completion | 200 / 200 | 0 / 0 |
| 100 repeated accept, remove, completion or turn-in signals | 1 / 1 per burst, with repeated broad invalidation | 1 / 1 per burst, one affected-ID invalidation |
| 100 identical out-of-range quest-data events | 100 / 100 | 0 / 0; 100 single-record metadata checks |
| 100 identical visible quest-data events | 100 / 100 | 0 / 0 |
| 100 identical native XP-data events | 100 / 100 | 0 / 0 |
| 100 identical paired item-data callbacks | 100 / 100 | 0 / 0 |
| Late native difficulty entering the level range | 1 / 1 | 1 / 1; quest appears |
| Native zero reward becoming positive XP, then XP amount changing | 1 / 1 each; old browser did not admit amount-only quests | 1 / 1 each; meaningful changes remain visible |
| 200 repeated unchanged source observations | Not part of the old state observer | 0 / 0 |

Hidden log/explicit-state event bursts cause no log reads, requests, query or
render. Hidden metadata arrival invalidates the affected record once without
starting UI work; reopening consumes current data. Source hashes and exact
operation counts are recorded in the private probe receipt.

With the actual 5,672-record catalog and cold native quest metadata, the browser
requested 31 unsupported quest difficulties and 12 visible reward records,
returned 252 default-range candidates in this modeled player context, and
stopped its updater. Two hundred later unchanged log events caused no query or
render. Two thousand out-of-catalog explicit signals retained at most 512 signal
entries/slots; hidden bursts performed no log reads or metadata requests.

## Runtime constraints and authority

All 5,672 generated records were independently compared with normalized source
fields. The 4,919 present faction/class/race/conflict fields match. Incompatible
contexts are rejected for all 798 class-restricted, 617 race-restricted and
3,498 faction-restricted records; all three explicit eligibility conflicts block.
All 245 historical/unconfirmed/hidden candidates fail static-only resolution and
can pass with current native proof. This checks the runtime guard, not whether
the server presently offers those quests. Nonfixed typed item starts retain a
start path without fabricated coordinates.

## Reproduction and remaining checks

Independent probes and receipts remain under `.work/final-state-adversarial/`:

```text
python .work/final-state-adversarial/review.py
python .work/final-state-adversarial/constraints.py
python .work/final-state-adversarial/full-catalog.py
```

`probe.lua` drives registered handlers; `Search-before.lua` captures the missed
dependency behavior; `operation-counts.json` includes final source hashes.
`proof-expiry.lua` is the separate nil/false checker regression.
`source-clear.lua` checks removal of a result whose sole start proof was the
cleared native marker.
`constraint-results.json` and `full-catalog-results.json` record the actual-data
checks. Durable regressions live in `tests/quest_state_test.lua`,
`tests/search_runtime_test.lua`, `tests/search_lifecycle_test.lua`,
`tests/provider_recovery_test.lua` and `tests/reward_browser_model_test.lua`.

The final independent run passed its assertions and confirmed identical start
and end hashes for all shipped Lua files. No unresolved source-identifiable
finding remains in this review's state/search/data-runtime scope.

Remaining client checks concern physical dropdown clicks, native glyph/tooltip
geometry at Matt's UI scale, reward pointer transit, actual quest transitions,
zone mapping, other-addon ordering, combat/taint and game CPU. No reload, game
installation or publication was performed by this review.
