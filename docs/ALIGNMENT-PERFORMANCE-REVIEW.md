# Alignment and settings performance review

Final result: **accepted for the reviewed source and offline lifecycle**, with
native-client limits below. The independent final run passed 40 workloads after
the production freeze at `2026-10-15T18:37:10Z`. All shipped Lua hashes matched
before and after execution. No earlier review totals were used as evidence.

## Scope and method

The review traced the actual initialization, slash/options constructors,
settings pages, profile application, finder query, appearance invalidation,
registered item/addon/display events, dropdown generation, copy dialog and
compact inspector entry points. It follows the current alignment, settings and
search/copy plans without changing their approved design.

The independent Lua 5.1 harness uses 200 published fixture quests, 200 shared
cached item records, 180 registered fonts, actual owned UI constructors and the
pinned 70374 DropdownButton `SetupMenu`, `OpenMenu`, `CloseMenu` and `IsMenuOpen`
procedures. Generated descriptions and native menu state are modeled separately.
It delivers native-style `OnSizeChanged`, programmatic `OnTextChanged` and focus
loss events that the portable fixture otherwise omits. It checks complete RGBA
arguments, finite frame levels, foreign backdrop/font ownership, parent-visible
updates and preserved NineSlice backgrounds.

Installed XPIsland 0.6.3 Options/UI and AsTheCrowFlies 0.1.4 UI/Settings were read
as construction and lifecycle references. Their hashes and the pinned dropdown
source hash are recorded in the final receipt. No game installation, user
settings or other addon's files were changed by this reviewer.

## Findings resolved during review

1. **Appearance changes queried the corpus.** Initially border, scale and font
   changes each caused one complete 200-record query through
   `AppearanceChanged -> DataChanged -> Refresh`. An unselected font registration
   also queried the corpus. The final appearance path restyles retained results;
   real dirty data and pending filter deadlines remain independently owned.
   Display/scale events and native size callbacks use this same layout boundary.

2. **Open font menus repeatedly scanned the registry.** One registry event while
   a menu remained open for 600 frames initially caused 601 HashTable scans,
   109,863 IsValid calls and 602 SetScript assignments with only 180 fonts.
   The final path prepares cached menu keys once and waits with one owned
   callback that checks only pending dropdown state. Registry entries and font
   resolution are cached by their actual dependencies. It neither replaces an
   open native menu nor retains the callback after release or hide.

3. **Late native font changes did not reflow the finder.** An actual
   `ADDON_LOADED` dispatch after changing the external game-tooltip font updated
   the owned title face and made 135 font writes, but caused no finder render or
   appearance invalidation. This independently failed its regression assertion.
   The final handler observes the changed family once and schedules finder
   appearance layout, with no corpus query.

The root's separately identified incomplete-RGBA backdrop call was also
challenged with strict setter preconditions. The fixed border paths pass those
checks and preserve the native NineSlice center/background.

## Final independent workload evidence

| Workload | Observed result |
| --- | --- |
| First settings construction | All three page trees construct together; subsequent navigation reuses them. |
| 40 complete page/reopen cycles | 120 page changes and 40 reopens; zero new owned frames, font strings or textures; zero extra menu generations. |
| 30 unchanged options refreshes | Zero LibStub, IsValid, Fetch, HashTable or SetFont calls; zero menu regeneration. |
| 20 warm selected-media font passes | Zero external media lookups and zero font writes. |
| Object-specific requested-font rejection | One rejected request; the complete owned family settles in a bounded second pass. Twenty following passes make no media lookups or font writes. |
| Border, scale and font changes | Zero queries, catalogue metadata hydration or identity/location/equipment captures. Existing visible reward rows redraw as needed. |
| 60 display/scale signals delivered in a burst | One retained-result render; zero queries. |
| 40 native size callbacks delivered in a burst | One retained-result render; zero queries or new UI objects. |
| Pending typed query plus appearance changes | Exactly one query; the intended exact quest remains selected. |
| Subtype-only item event plus appearance change | Exactly one query; newly verified gun metadata participates in matching. |
| Query clear with native text events | Exactly one query; edit text and filter clear together and input focus remains useful. |
| 20 repeated warm subclass queries | Zero full or instant item-info reads; existing item-type metadata is reused. Current reward-readiness checks retain their existing semantics. |
| 20 unchanged native font-menu open/close cycles | Exactly 20 native-required menu generations; intervening options refreshes cause no extras. |
| Unselected font registration | One registry scan and picker update; no finder query or render. |
| Registry update during 600 open-menu frames | One HashTable scan, 183 IsValid calls and one SetScript assignment; no menu regeneration while open. Only cheap pending-open-state checks repeat. |
| Deferred menu release | One pending menu generation and callback removal. Hiding during deferral and reopening also leave no active callback. |
| Late native game-tooltip family | One finder appearance invalidation and one retained-result render; zero queries. |
| 40 warmed copy/Escape cycles and parent close | Zero new frames, font strings or textures; focus is released on Escape and parent hide. First copy construction is measured separately. |
| 100 hidden quest-log/unrelated item-event bursts, then 3,600 frames | No instrumented work, queries, native metadata reads or active updates. |
| Hidden appearance edits | No finder query, render or hydration; no active update callback. Intentional settings binding refresh remains separate. |
| 30 reset/search-reopen cycles | No new owned frames, font strings or textures. Each opening performs its normal current-data query. |
| 5,000 distinct ranking records | Ranking and usability caches stay within 4,096 entries. |
| 100 repeated pending comparisons | One metadata read within the query; one new read recovers on the next query. No missing value becomes zero. |
| 100 compact-inspector border transitions after warmup | Zero new frames, font strings or textures; native center remains shown and its fill is preserved. |
| Source/pointer departure, then 3,600 frames | Zero recurring work and zero active update callbacks. |

Visible appearance redraws may reread the few displayed fallback reward icons;
the zero-hydration claims refer to corpus metadata and character captures, not
to the absence of every native getter. Similarly, deliberate native dropdown
opening always generates its description as required by the pinned source.
Neither behavior is hidden by the operation counts.

## Stable source identity

The final receipt is `.work/alignment-review/performance/results.json`; the
reproducible command is:

```text
python .work/alignment-review/performance/run.py results.json --strict
```

The strict runner rejects source changes during execution, failed modeled
lifecycles, unexpected appearance queries, repeated warm media lookups,
constructor growth, lost pending queries and extra native menu generations.
Exploratory failing receipts remain beside it as before/after evidence.

| Runtime file | SHA-256 |
| --- | --- |
| `UI.lua` | `317eed8208777b5dbbc5e1b02953c9f45e8bb83784c4c292e802a7ac753468e1` |
| `Options.lua` | `69ae45d516af7ee60cd862589a593b5dee4365766429029b605a10cad1a7719d` |
| `Core.lua` | `d98d51d57fd79100442ce9ae638c8ac9be3797ce2eadaaa336a7e6d06b103491` |
| `Search.lua` | `23a74d4b8af5beff3d45f64dec0c904ee14cdb3eedc711386bacddccfae20884` |
| `SearchModel.lua` | `78d2350efe963c3e83775c479f766a5b656c2d123b55f1f1e6114a89b61bec7a` |
| `Model.lua` | `a655186a304fe0365baf7f4e61b83fddc0c8be20ac51144dc5a4c0c1b43a0099` |
| `Stack.lua` | `6c97f99ebbdc7ec084fc5ab34536a3ce60c968283f54ba1be56fae9582e743bc` |
| `Ranking.lua` | `0d60ddb9d6df0c66f8e0c60926e15e3867b15d98ecb379c93a75e0252fe34a7a` |

The native dropdown source is Gethe
`735496de78ebd30ce816a0637982c556987f258c`, SHA-256
`3700afff438469414654a0293c0f18aef52f5e4bca11e0c12ee1d9a4a8dc55d6`.
The complete shipped-Lua hash manifest is in the receipt.

## Native-client limits

These are Lua operation counts and modeled lifecycle checks. They establish
owned constructor reuse, bounded caches/callbacks and the stated invalidation
boundaries. The fixture does not allocate Blizzard's real menu renderer or
NineSlice texture internals, so zero owned constructor calls do not prove zero
engine allocations. Interpreter timings and pre-collection heap deltas in the
private receipt are diagnostic, not native addon CPU or peak memory readings.

Official Forever 1.60.1.70374 still requires observed native font/layout and
fractional-scale appearance, physical resizing/menu/copy input, native item
comparison coexistence, combat/taint and whole-addon CPU/GC behavior. No remaining
source-identifiable performance defect was found in this reviewed freeze.
