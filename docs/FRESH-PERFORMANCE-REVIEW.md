# Fresh performance and ownership review

Reviewed baseline: FindAnUpgrade 0.1.9, commit `ac2485ad2f1af451879cbccd08a67bc1c5064306`.

This review independently traced initialization, finder construction, indexing,
querying, filtering, rendering, scrolling, resizing, menus, item inspection,
profile changes and registered event delivery. It did not reuse previous test
totals as evidence. The independent probe executes the shipped modules in Lua
5.1 against the complete bundled 5,672-ID catalogue, with controlled native
identity, item and character responses. Its comparison workload executes the
pinned 70374 tooltip handler procedures and comparison manager; line services,
frame geometry and item responses remain simulated.

## Finding: pending equipment repeats work across every ranked quest

At the reviewed baseline, `Ranking:Gear` declines to reuse `self.gear` whenever
`gearPending` is true, despite an unchanged character snapshot. `Ranking:Quest`
calls it before considering whether a row has any equipment rewards. A broad
level-range query with one equipped head whose metadata is partially ready made
2,933 repeated full item-info and uniqueness reads for that same link. The
otherwise identical warm ready-equipment query made no ranking item-info reads.
An uncached occupied head similarly caused 2,933 readiness checks and repeated
19-slot table construction. This amplifies ordinary loading uncertainty into
work proportional to the number of quests in one synchronous query.

The same retry policy applies to a partially ready candidate shared by several
quests. A controlled partial response for a candidate occurring in 50 associations
caused 50 full metadata/uniqueness reads in one query. The item used to demonstrate
the corpus association count was ID 21100; its simulated equippable response is
an adversarial fixture, not a claim that this actual coin is equipment.

The appropriate boundary is a single query plus the exact snapshot and item
invalidation state: repeated associations can share the pending observation,
while a later query, context change or authoritative item event must permit
recovery. A permanent negative cache would conceal readiness changes. The root
agent owns the fix and regression tests; final re-review is recorded below.

## Fresh workload observations

These numbers are operation counts from the independent harness, not client CPU
or renderer timings. All warm repeat workloads start after construction and
hydration.

| Workload | Observation |
| --- | --- |
| Initial finder opening | 64 catalogue rows per indexing step; 5,672 title and difficulty reads overall; one identity/location/equipment capture; settled with zero active updates. |
| Settled visible finder, 3,600 delivered frames | Zero native getter calls, queries, frame/font/texture creation or active updates. |
| Hidden finder, 1,000 quest-log, item, zone and equipment event bursts plus 3,600 frames | Zero native quest/item/character reads and queries; zero active updates. Dirty facts wait for an interested consumer. |
| 50 reopen cycles | No new frames, font strings or textures; one bounded quest-log prime and result query per opening. |
| Warm mixed repeat: 200 scrolls, 50 reopens, 50 menu generations | No new frames, font strings or textures; pool plateau of 101 mock frames, 159 font strings and eight reusable cards. |
| 80 separated size changes | 80 debounced refreshes; existing cards/icons reused. Continuous native sizing cadence is not established by the mock. |
| 30 enable/open/disable cycles | No new frames, font strings or textures; zero active updates when disabled. |
| 60 options/default-profile cycles after options construction | No new frames, font strings or textures; options and finder keep their existing owned objects. |
| Stationary inspected item, 3,600 frames with comparison held | One comparison metadata read, one comparison-delta read, two hyperlink reads; one owner update remains active for pointer/modifier transit. |
| 100 item-hover/departure cycles | No new frames, font strings or textures and no result queries. Once departure settles, another 3,600 frames perform no work. |
| 1,000 visible unchanged quest-log events | 1,000 bounded log captures and native map-offer reads; zero result queries or object creation. This work is event-driven but not coalesced at the baseline. |
| 2,000 duplicate item events for one tracked ready item | Zero result queries; 4,000 item-info, 2,000 uniqueness pairs and 2,000 usability reads. Unrelated item IDs do not cause those reads. |
| Pointer over an exact source without the inspection modifier, 600 frames | One pointer/modifier watcher; no query, catalogue hydration or frame creation. It stops after source departure, followed by 3,600 frames with no work. |

The visible event flood counts deliberately expose event work without inferring
the live client's event rate. They are distinct from the pending-gear finding:
the latter amplifies one user query, while these costs follow actual delivered
events. The event/cache reviewers assess their ownership and coalescing changes.

## Source and mock challenges

The review read installed XPIsland and AsTheCrowFlies constructors, scheduling
and refresh paths, plus Questie's frame-pool acquisition/release code. The finder
follows the same principle of owned reusable UI and delayed search preparation.
Questie's pool explicitly reuses engine frames and defers recycling while queued
draws still own them; hiding a frame does not destroy it. The measured plateau is
therefore separated from temporary Lua garbage and from Blizzard menu objects.

The portable frame fixture does not automatically deliver `OnSizeChanged` from
every native layout mutation and does not allocate Blizzard's real menu frames.
The resizing probe explicitly delivers the size event, and menu-generation
counts establish owned Lua work only. The pinned DropdownButton source confirms
that generation and intrinsic menu lifetime remain Blizzard-owned. The review
does not claim the mock proves the native menu allocator's behavior.

The tooltip probe loads the current pinned source rather than trusting a no-op
comparison stub. It still substitutes native line processing and item payloads.
Stable comparison getter counts establish that the addon does not rebuild the
comparison every frame; they do not establish native text-rendering cost.

## Evidence and limits

Private reproducible probes and raw operation counts are under
`.work/fresh-review/performance/`. `run_probe.py` records reviewed source SHA-256s,
pinned native source hashes and the workloads. `reference-hashes.json` identifies
the read-only installed reference files. This review writes no game files or
user settings and launches no client.

`final-results.json` captures the complete pre-fix baseline workloads;
`stable-fixed-results.json` captures the fixed workloads and rejects any source
change between its initial and final hash snapshots. `run_token.py --baseline`
reads the committed baseline ranker without changing the working tree and
demonstrates the distinguishing regression failure; the same probe passes
against the fixed ranker. Its results are `token-baseline-results.json` and
`token-results.json`.

Baseline key file hashes:

| File | SHA-256 |
| --- | --- |
| `Ranking.lua` | `d6b66e89d75f6554171b227dc3a1e7a557603a2640101275b3e216ae0821e9c9` |
| `SearchModel.lua` | `b1dc4f1f0deb5b60043150245f67f1252c88faedf5394e7f70c589bb22ad5358` |
| `Search.lua` | `2e2b9b7beb5efe07bfb378fbe08697c23cef7d2382fab891b6a12c51fb8cc2ee` |

Lua wall/CPU timings and pre-collection heap deltas are diagnostic measurements
of this interpreter and fixture, not native addon CPU, allocation peaks or user
frame time. Engine allocations, garbage collector behavior in the actual addon
set, map/NPC hover cadence, physical resizing/input, combat/taint and rendering
remain pending live-client checks on official Forever 1.60.1.70374.

## Stable-file re-review

The root-owned fix passes an opaque query token through finder usability,
candidate-item and equipped-item ranking. Pending observations are shared only
inside that query and matching equipment/item revisions. Dirty item evidence
overrides the memo. Unknown uniqueness information remains retryable rather than
becoming a permanent unsupported result.

The independent complete-catalogue pass now reads the partial equipped head once
per query, instead of 2,933 times. The query makes five total full item-info reads:
one for ranking and four for the visible fallback reward icons. The cold-head
case similarly makes one ranking readiness observation, and the repeated partial
candidate drops from 50 full metadata/uniqueness reads to one. The result remains
unrated while required facts are unknown.

The independent minimal probe makes 100 calls for the same pending gear or
candidate. Against the committed baseline both perform 100 reads and fail the
regression assertion; against the fix both perform one read. A new query, changed
equipment revision and dirty item signal each allow a fresh read and ready-state
recovery. One hundred unknown-usability associations share one observation; an
item revision change retries it and recovers the verified boolean. This verifies
the cache boundary as well as the reduced call count.

The fixed workload retained the same idle behavior, UI pool plateau and native
comparison getter counts above. No further substantive performance finding was
identified in these source traces and modeled workloads.

Stable reviewed runtime hashes (working-file bytes, before Git line-ending
normalization):

| File | SHA-256 |
| --- | --- |
| `Ranking.lua` | `0d60ddb9d6df0c66f8e0c60926e15e3867b15d98ecb379c93a75e0252fe34a7a` |
| `SearchModel.lua` | `4f3885b418ad4103d8270d891936a8f4e80e8507d4462d4f81bbd38a457af0c9` |
| `Search.lua` | `2e2b9b7beb5efe07bfb378fbe08697c23cef7d2382fab891b6a12c51fb8cc2ee` |
| `Character.lua` | `de02774f17b75214d4cd739bcab246471b37ed94999ee0e32235a0099d44914b` |
| `QuestState.lua` | `3582cdf8f9706b2155eebb0eecc5466f7366067c33cdac5abb4a69fa2966a86d` |

These checks establish the owned Lua operation counts and modeled lifecycle.
They do not close the live-client CPU, renderer, physical-input or taint checks.
