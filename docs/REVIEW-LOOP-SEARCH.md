# Fresh independent search/filter review

Reviewed initial candidate `75e88b03b6e8e97500af5ccbd3e7d28ea3424235` on
2026-10-14, followed by independent re-review of the corrected working tree.
This reviewer owns this document and ignored independent probes in `.work/`;
no implementation, checked-in test, data, installation, merge or publication
was changed. The initial three findings and one re-review residual were corrected
by the implementation owner and independently reproduced again. No concrete
search/filter blocker remains in the reviewed paths. The exact tested working
tree receipts appear below; this is not a claim about live behavior.

The review followed repository `AGENTS.md` and the user-provided
`wow-addon-development` skill, including its client/source and validation
references. It reviewed the shipped TOC load order, `Catalog.lua`,
`SearchModel.lua`, `Rewards.lua`, `Search.lua`, catalog source/coverage/provenance
and the current native quest contracts. The full verifier was intentionally not
run while the implementation owner and other reviewers share a moving branch.

## Initial findings, now resolved

### S1 — Failed item loads monopolize the bounded request window (P2)

`QuestBrief/SearchModel.lua:117` always chooses the first 128 pending items in
catalog order without consulting the search session's request/failure state.
`QuestBrief/Search.lua:137` then suppresses every previously requested ID.
`QuestBrief/Search.lua:85` clears item metadata on a matching load-result event,
including a failed result, but does not advance the request window past failure.

Reproduction uses the actual 1,267 shipped quest records, Alliance warrior
context, controlled native difficulty 20 and a broad 1–200 Head query. The first
128 distinct pending item IDs return no instant data and each reports a failed
load; later items remain loadable if requested. After 200 Tick calls and matching
failure events, only 128 distinct requests have occurred and **zero** later IDs
have been requested. There are 1,380 eligible later item associations outside
the failed first window in this controlled context.

Consequence: ordinary obsolete or unavailable early IDs can permanently prevent
other cold rewards in the same finder session from warming and becoming
discoverable. Keep work bounded, but advance past requested/failed items rather
than allowing them to occupy every new queue's capacity.

### S2 — Recorded restrictions override confirmed native quest-log membership (P2)

`QuestBrief/SearchModel.lua:16–27` rejects recorded faction, class and race
conflicts before reading `C_QuestLog.IsOnQuest` at line 34.

Independent conflict probes retain the real source restrictions on quest 6
(Alliance), quest 96 (SHAMAN) and quest 758 (race 6). Native `IsOnQuest` is true
for the exact ID, while the controlled player context disagrees with one older
recorded restriction. All three return false instead of an included result with
"In quest log" evidence. These inputs deliberately exercise a source/native
disagreement; they are not a claim that those restrictions have changed in the
live client.

Consequence: the source snapshot from build 69893 can hide an exact quest that
the target client's native API confirms the character already holds. Preserve
native disabled/completion handling, but give direct native quest-log membership
precedence over recorded eligibility restrictions.

### S3 — Native reward authority depends on earlier visible search results (P2)

`QuestBrief/SearchModel.lua:115` queries recorded/currently remembered
associations. Native rewards are read only by `SearchModel:Reward` at line 136,
called by `QuestBrief/Search.lua:188` while filling a matching visible card.
`QuestBrief/Search.lua:218` likewise requests reward data only for those cards.

Reproduction retains production quest 6 and its three recorded associations.
The controlled native API already has fully ready exact-ID quest data reporting
item 1359 with the test name "Review native helm", absent from quest 6's
recorded list. An initial query for that native reward name never includes quest
6 and performs **zero** native reward reads for quest 6. Querying its recorded
title first renders and promotes the row; returning to the exact same native
reward query now includes quest 6. Item 1359 also has a separate legitimate
production association, so the probe asserts target quest-ID membership rather
than assuming the whole initial result set is empty.

Consequence: a current reward absent from the older source catalog cannot be
found through its name or slot unless the user happens to render its quest by an
earlier broader query. Rows beyond the visible viewport have the same
history-dependent authority. Reconcile ready native reward associations in a
bounded search-owned path that can run before matching, and re-filter when that
reconciliation changes the searchable set.

## Independent correction re-review

The corrected production catalog at re-review contains 1,238 quests and 2,239
associations. `data/catalog-source.json` SHA-256 was
`c4d66bf7b218c1476b53f0a60cba4610366114e03b0e59774d4237aec3bd1660`.
These counts record the runtime review's exact data input while the data reviewer
was refining coverage; that reviewer owns the final source inclusion verdict.

`python .work/fresh_search_rereview.py` independently reruns the original triggers
using shipped production rows and controlled native inputs. Its machine-readable
receipt is `.work/fresh-search-rereview-results.json`.

| Finding | Independent corrected outcome |
| --- | --- |
| S1: failed first-window items starve later metadata | All 1,301 eligible distinct pending items are requested exactly once, including 1,173 IDs beyond the first failed 128. The idle update script is removed after work settles. |
| S2: recorded restrictions override quest-log membership | Real production quests 6, 96 and 758 remain included with "In quest log" evidence despite the controlled recorded faction/class/race conflicts. |
| S3: current native rewards require an earlier broad search | Quest 6 appears on the initial restrictive native reward-name query, with exact native associations promoted before literal matching. |
| S4: failed quest-data refresh retains stale native usability | A native unusable result for quest 6's recorded item 60, followed by unavailable native reward data and `QUEST_DATA_LOAD_RESULT(6,false)`, now clears per-quest usability and restores that recorded item as unconfirmed fallback. |

S4 was found during re-review at `Search.lua`'s exact-ID quest-data invalidation:
the initial correction cleared `currentItems` and `currentStamp` but left an old
`usability[id][itemID] == false`. The implementation owner now clears all three
per-quest values together at `QuestBrief/Search.lua:149`. The independent rerun
reports `stale_false_after_quest_failure=false` and
`recorded_fallback_item_after_quest_failure=true`.

Additional independent production-rate probes exercise the registered update
script at 30, 60, 144 and 240 FPS. The first two seconds issue 34, 34, 36 and 36
item requests respectively, with no duplicate requests. Hiding the finder stops
requests. Ready quest metadata is read once for all 1,238 rows and incurs zero
title reads across ten subsequent refilters. An exact-ID data event wakes a
settled visible finder. These are offline request-count and ownership checks,
not in-client CPU measurements.

The tested runtime file SHA-256 receipts are:

```text
Catalog.lua     180a195c29f69e0141ba1784971c5335793877b4b765461d44d2292616420dbc
SearchModel.lua fcb381c6466b58f6363b30dee2d9d524640c097926a80e6ad88b95c29f86e3b6
Search.lua      ccae82943935c6011c02ad3c7684c1047132f4dc91e359fe3b2a89c347925e2c
```

The independent provenance scanner was rerun on this corrected input: all 2,239
shipped associations still trace to direct authored children and compiled
membership, all 95 source receipts pass, and all nine retained current native
receipts pass. Prerequisite failure labels now remain "Prerequisites unconfirmed"
and below-minimum evidence reads "Recorded minimum level"; neither claims current
native quest availability from incompletely interpreted older source fields.

## Independent evidence

Run the focused probes with:

```powershell
python .work/fresh_search_probe.py
python .work/fresh_provenance_probe.py
```

The Lua probe runs shipped modules through Lupa's Lua 5.1 runtime. Its scenarios
and assertions are independently authored; `tests/wow_mock.lua` supplies the
existing UI objects and event dispatch only. Native difficulty, item slots and
reward changes in these scenarios are controlled fixtures, not observed current
game facts. Machine-readable receipts are
`.work/fresh-search-probe-results.json` and
`.work/fresh-provenance-probe-results.json`.

The initial reviewed catalog contained 1,267 exact quest IDs, 1,977 unique item IDs and 2,311
associations. Its source JSON SHA-256 is
`38922860008a8b123157ebc6b5c95d4e07eb970b8b8957a8d73c7cfc8d1e5316`.
The independent lexical provenance scanner imports no implementation parser or
generator code and executes no upstream Lua. It checks the original source
constructor and exact line for every source reference, identifies only immediate
quest-group item children, and verifies **all 2,311** shipped pairs against both
those direct children and compiled numeric membership. It verifies all **95**
source file SHA-256/Git-blob receipts and all **8** retained current native
snapshot receipts.

Additional passing focused checks include 924 known production
class/race/faction rejection cases; 2,534 completed/nonrepeatable and
completed/repeatable cases; 12 threshold/unknown-completion cases across all four
production prerequisite thresholds; and 187 exact quest IDs belonging to
duplicate source-title groups. Unknown context restrictions stay unconfirmed
rather than fabricated. A matching successful item-load event transitions a
cold item to ready. Recorded cold rewards retain unknown quantity and group.

Source inspection confirms literal substring matching with stable exact-ID
tie-breaking, slot-specific reward-name exclusion, chest/robe and weapon/ranged
families, readable item minimum-level checks, and explicit native usability false
separate from unavailable usability. The code reports only verified difficulty
distance as Level fit. It does not calculate DPS, role suitability, proc value,
or sum exclusive reward choices. Guaranteed and choose-one native groups remain
distinct; incomplete native groups preserve a recorded fallback.

The empty-slot probe confirms native equipment-slot identity, strict false item
existence and fail-shut missing data. The current pinned
[ItemLocation implementation](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_ObjectAPI/Mainline/ItemLocation.lua)
defines `IsValid` as `C_Item.DoesItemExist`; requiring `IsValid` before detecting
an empty slot would incorrectly eliminate empty locations. Slot existence and
class/training compatibility must not be inferred from that method.

## Evidence boundary and pending live checks

The native contract target is official Forever interface 16001,
1.60.1.70374, Gethe/wow-ui-source
`735496de78ebd30ce816a0637982c556987f258c`. The retained detail-renderer baseline
remains 70338 at `943764493e6b16d63ded3ab304150d1f05e58b57`. The catalog source
is ATT `d75383ccdbff1208b87cf4024fa425c0825a7ad6`, build 1.60.1.69893.

No source inspection or mock execution establishes live reward correctness,
quest eligibility, rendering or taint safety. Pending official-client checks:
arbitrary unloaded quest difficulty hydration, load success/failure timing and
recovery, actual item/class/training usability, generic one-hand/off-hand and
ranged slot behavior, current reward/source conflicts, repeatable/completed
availability, native tooltip/comparison coexistence, physical menu/scroll/resize
input, combat taint and search CPU/frame budget.
