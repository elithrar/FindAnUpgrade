# Fresh data review of PR #2

Reviewed independently against `75e88b03b6e8e97500af5ccbd3e7d28ea3424235`
on 2026-10-14. This is an offline source/data review, not observed Forever
behavior. Review-only changes are confined to this report.

The findings and checks below describe the original reviewed baseline. The
implementation closure at the end records the subsequent authorized fixes;
baseline counts and findings are retained as historical evidence.

The ATT pin is `d75383ccdbff1208b87cf4024fa425c0825a7ad6`; its config
identifies `1.60.1.69893`. QuestBrief targets official Forever interface
`16001`, build `1.60.1.70374`. The current Blizzard mirror
`735496de78ebd30ce816a0637982c556987f258c` and baseline detail fixture
`943764493e6b16d63ded3ab304150d1f05e58b57` are source evidence only.

## Findings

### D1 — P1: Direct authored item children include objective inputs and intermediates

Location: `tools/import_catalog.py:121-127`; propagated into
`data/catalog-source.json` and `QuestBrief/Data/Catalog.lua`.

Trigger: a quest contains a direct `i(...)` child which documents an objective
component, an item consumed while doing the quest, or an intermediate acquired
before completion. The importer treats every such child as a recorded reward,
and the compiled-pair intersection cannot distinguish these meanings.

Concrete pinned-source evidence:

- Quest 4763, The Blackwood Corrupted, `zones/kalimdor/darkshore.lua:702`.
  Objective 1's cost at lines 715-718 consumes item IDs 12347, 12341, 12342,
  and 12343. Their direct item nodes at lines 722, 726, 731, and 736 document
  how to obtain those inputs. The shipped row nevertheless lists all four as
  rewards alongside actual reward items 15202, 15203, and 15204.
- Quest 3924, Samophlange Manual, `zones/kalimdor/the barrens.lua:1899`.
  Objective 1 consumes item 11147 and five copies of 11148 at lines 1909-1910.
  Their direct nodes at lines 1915 and 1919 record the creatures dropping them.
  The catalog lists both as rewards alongside items 11854 and 11855.
- Quest 7509, The Forging of Quel'Serrar,
  `dungeons & raids/1.0 - onyxia's lair.lua:162`. Objective 1 consumes Heated
  Ancient Blade 18488 at line 173; that intermediate consumes Unfired Ancient
  Blade 18489 at line 178. The 18489 description explains obtaining a
  replacement by abandoning and accepting the quest. Both intermediates are
  listed as rewards alongside Quel'Serrar 18348.
- Quest 6022, To Kill With Purpose,
  `zzOLD/02 - Outdoor Zones/02 Eastern Kingdoms/Eastern Plaguelands.lua:916`.
  Objective 1 requires Coagulated Rot 15448. Its direct node at line 936 uses
  Mortar and Pestle 15454 as provider and seven Living Rot 15447 as cost.
  All three are the shipped row's entire reward list. This row has no
  source-established completion reward.

All paths above are beneath `.contrib/.db/forever/` in the pinned ATT source.
All listed pairs pass the current membership checker. Native reward hydration
may correct a visited record later, but cannot make the initial recorded reward
claims accurate.

Independent scan found 39 shipped quest/item pairs across 25 quests with
acquisition fields on the direct item node (`provider`, `providers`, `cost`,
`cr`, `crs`, `coord`, or `coords`). A separate scan found 30 shipped pairs across
17 quests also referenced as objective provider/cost IDs. These are candidate
sets, not a claim that every coordinate-bearing node is invalid. Their union
needs review. Excluding only attributed item nodes is insufficient: 18489 has
description only, and some objective inputs are bare `i(...)` children.

Required correction: preserve source semantics before calling a pair a reward.
Exclude objective/provider/cost components and transitive intermediates; review
ambiguous direct nodes conservatively. Add production-source regression cases
for the examples above, record pair omissions, and recompute coverage. The
current 2,311 association count is a count of retained children, not 2,311
validated reward associations.

### D2 — P2: Flattened prerequisite IDs turn optional breadcrumbs and alternatives into requirements

Location: `tools/import_catalog.py:155-165` and
`QuestBrief/SearchModel.lua:42-55`.

Trigger: a catalog quest's `sourceQuest` or `sourceQuests` points to a breadcrumb
or alternate quest. The importer stores positive IDs without the referenced
quests' `isBreadcrumb`/`altQuests` semantics. Many referenced helper quests have
no reward items and therefore never enter the catalog. The runtime then counts
every uncompleted ID against the required total. Its `previous.source.exclusive`
fallback is unreachable for these missing helpers, and no generated record has
that field.

Concrete evidence:

- Catalog quest 11, Riverpaw Gnoll Bounty, has `prerequisites={239}`. Source
  quest 239 at `zones/eastern kingdoms/elwynn forest.lua:1377` is explicitly a
  breadcrumb (`isBreadcrumb=true` at line 1382).
- Catalog quests 1882 and 1884 store `{1881,1883}` with no count override.
  Quest 1881 at
  `zzOLD/02 - Outdoor Zones/02 Eastern Kingdoms/1 - Undercity.lua:618` has
  `altQuests={1883}` and is a breadcrumb; quest 1883 at
  `zones/kalimdor/durotar.lua:1103` has the reciprocal alternate and is also a
  breadcrumb. Neither helper is in the reward catalog.
- ATT's own pinned `src/Classes/Quests.lua:1677-1712` treats breadcrumbs,
  alternate completion, character filters, lock criteria, and quests currently
  in the log specially when interpreting these source links. It does not
  equate every uncompleted source ID with an unmet prerequisite.

Reproduction using shipped Lua 5.1 code and production catalog data:
`IsQuestFlaggedCompleted(1881)=true`, other IDs false; quests are not in the log.
For a level-20 Horde Undead Mage, quest 1882 returns
`true, "Requires earlier quests"`. Quest 11 similarly returns that message with
239 incomplete for a level-20 Alliance character. These are offline execution
results, not assertions about server availability.

Independent source scan found 61 shipped prerequisite edges referencing authored
breadcrumbs and 25 referencing quests with authored alternates (sets overlap).
Required correction: preserve supporting prerequisite semantics even for helper
quests without rewards, or keep these relationships unconfirmed and avoid a
definitive requirements message. Test the actual shipped rows, not only a
synthetic runtime row with a field the generator never emits.

### D3 — P2: Unsupported prerequisite thresholds silently become all-of groups

Location: `tools/import_catalog.py:130-137,155-164`.

Trigger: `sourceQuestNumRequired` is a selected nonliteral expression. The
unsupported-field loop deletes that property, but retains the source quest
list. Runtime defaulting then requires every list member, even though the
discarded threshold may have meant one of them.

Minimal independent parser probe:

```lua
q(9, {sourceQuests={1,2}, sourceQuestNumRequired=ComputeRequired(), groups={i(123)}})
```

Actual output is `prerequisites=[1,2]`, no count, and
`eligibilityUnknown=true`, plus a field-omission diagnostic. The uncertainty flag
does not prevent `SearchModel:Eligibility` from returning the stronger
`Requires earlier quests` message when only one source quest is complete.
This is a malformed/unsupported-input defect; no such expression was found in
the currently shipped threshold fields.

Required correction: drop or explicitly invalidate the prerequisite group when
its threshold cannot be established, rather than assigning the all-of default.

### D4 — P2: Literal but unresolved restrictions bypass the advertised record-omission guard

Location: `tools/import_catalog.py:145-154`.

Trigger: a class/race constraint tokenizes as a literal but cannot be resolved
to the supported class/race schema. The nonliteral guard does not run. The
parser instead ships an unrestricted row with `eligibilityUnknown=true` and
does not record an omission.

Independent probes:

- `q(9,{races={FUTURE_RACE},groups={i(123)}})` with no matching race constant
  yields a row without `races` and no omission.
- `q(9,{classes=17,groups={i(123)}})` yields a row without `classTokens` and no
  omission.

The runtime keeps either row for every player race/class. This conflicts with
the documented fail-closed rule for unsupported race/class restrictions. No
current production row was established to exercise these probes.

Required correction: omit the entire record with a diagnostic whenever an
explicit class/race constraint cannot be resolved and validated, regardless of
whether tokenization classified the expression as a literal.

### D5 — P3: Generator accepts an internally impossible level range

Location: `tools/generate_catalog.py:33-34`.

Independent mutation of an otherwise valid source row to `minimum=60` and
`maximum=5` passes `validate`. The importer rejects that shape when parsing a
literal pair, but the owned input snapshot is independently editable and the
generator's validation is intended to guard it. Such a row can misleadingly
show a level requirement below 60 and disappear above its maximum.

Required correction: require `minimum <= maximum` whenever both exist. No
shipped row currently has an inverted range.

## Baseline checks completed

- Read `AGENTS.md` and the user's WoW add-on skill and validation reference.
- Inspected exact raw ATT authoring files, shared shortcut field documentation,
  ATT prerequisite interpretation, Forever config, and XML-loaded compiled
  categories. Did not execute upstream Lua.
- Reproduced the importer into a temporary review directory: both owned source
  JSON and provenance JSON matched byte-for-byte. The source JSON SHA-256 was
  `38922860008a8b123157ebc6b5c95d4e07eb970b8b8957a8d73c7cfc8d1e5316`;
  provenance was
  `dfa51a10fb4b5ec27601a6997d6180df78d31c4539752011e73e2480a461e27f`.
- `python tools/check_membership.py --source-root .work/att-generated` passed:
  2,742 compiled exact pairs and 988 consistent constraints.
- `python -m unittest discover -s tests -p catalog_test.py` passed all 12 tests.
  Passing tests do not cover the findings above.
- The coverage report's arithmetic matches the snapshot: 1,267 quests, 1,977
  item IDs, 2,311 retained pairs, 363 classified quests, and 48 classified New
  quests. Reward membership does not alter the sole classification authority,
  `data/primary-statuses.json`. Quantities/groups/static amount fields remain
  correctly unknown. The report explicitly records no live-client verification.
- Inspected compiled ancestor faction/class restrictions: the three matching
  catalog quests with constrained parents also carry the same own faction
  constraint. No additional inherited-restriction defect was established.

## Pending live checks

After source corrections, on official Forever build 70374: compare completion
rewards and choices against native detail data for quests 4763, 3924, 7509, and
6022; check breadcrumb and alternate quest availability for 11, 1882, and 1884;
observe cache-cold native hydration and correction of recorded items; verify
current race/class eligibility, questgiver coordinates/phasing, native controls,
combat and taint behavior. No source/mocks in this review establish those facts.

## Baseline review status

Changes required for D1-D4 before accepting the catalog's claimed reward and
eligibility semantics. D5 is a validation hardening gap. No implementation,
test, or owned-data files were edited by this review.

## Implementation closure — 2026-10-14

The subsequently authorized fix task changed only `tools/import_catalog.py`,
`tools/generate_catalog.py`, `tests/catalog_test.py`, `data/catalog-source.json`,
`data/catalog-sources.json`, `data/catalog-coverage.json`, and
`QuestBrief/Data/Catalog.lua`. No commit was created by this task. This closure
does not replace the separate independent review or required full verifier.

| Finding | Correction and focused evidence |
| --- | --- |
| D1 | The importer excludes objective/issued-item/provider/cost component IDs throughout the quest subtree, including inputs to intermediate item nodes, and direct item nodes with acquisition facts. Every excluded exact pair has a path, line, item ID, and reason. A repeated source occurrence cannot reintroduce an excluded pair, and the generator rejects such reintroduction. Production regression cases preserve quest 4763's items 15202/15203/15204, quest 3924's 11854/11855, and quest 7509's 18348. Unsupported item claims for 6022 and 1016 are removed. |
| D2 | Imported source quest links explicitly retain `eligibilityUnknown`. The separately owned runtime fix uses `Prerequisites unconfirmed`, so source breadcrumbs/alternatives no longer become a definitive server requirement claim. A production Lua 5.1 probe for 1882, with 1881 completed and 1883 incomplete, returns `true, "Prerequisites unconfirmed"`. Exact native availability remains unverified. |
| D3 | An unresolved or invalid prerequisite threshold omits the entire group and records a diagnostic. Tests cover an expression threshold, zero, and a count larger than the known list. |
| D4 | Explicit class/race restrictions that cannot resolve to the supported schema omit the record and diagnose each removed pair. Tests cover unknown tokens, empty lists, nonpositive races, and scalar invalid classes. The known `SKYBORNE_ALLIANCE` constant is resolved to race 95; the pinned compiled quest 93963 row independently contains `races={95}`. |
| D5 | The generator rejects `minimum > maximum`. Tests also check invalid parsed level constraints and diagnostic uncertainty. |

Immutable file-prefix literal aliases are resolved without executing Lua.
Resolution rejects reassignment, indexed mutation, mutation calls, alias escape,
shadow declarations/parameters, and unsupported expressions. This safely
preserves the Lunar Festival's numeric `COIN_OF_ANCESTRY=21100` constant and
quest 78150's recorded 10-of-17 library links. The pinned library source requests
20 and 25 completions against the same incomplete 17-entry list for quests
79536 and 82208; those groups stay unconfirmed with explicit diagnostics.

The conservative rule also omits acquisition-bearing or conditionally acquired
items whose completion-reward role is ambiguous, including the two direct
children of hunter quest 7636. Such omissions can reduce coverage and require
better exact-ID evidence before restoration; they are not claims that those
items can never be obtained through the wider quest chain.

Final generated coverage is **1,250 quests, 1,934 distinct item IDs, and 2,266
retained associations**. Against the original baseline, 45 pairs and 17 quest
rows are removed and no pairs are added. Every removed baseline pair has an
omission diagnostic, and no excluded pair remains in the generated catalog.
There are 360 classified catalog quests and 48 classified New catalog quests.
The unchanged classification authority still has 1,194 exact IDs and 218
per-variant `verifiedNew` records. Reward quantities, choice groups, static amounts, and
live-client verification remain unknown/false as before.

The provenance retains 95 pinned input hashes and the unchanged MIT license
reference. Its 454 diagnostics include **435 distinct excluded exact pairs**:

- 381 absent from the pinned compiled membership;
- 36 objective, issued-item, or acquisition components;
- nine direct item nodes with acquisition facts;
- nine pairs belonging to unresolved class/race records.

The remaining 19 diagnostics concern selected fields, whole-record restrictions,
and invalid/self-referential prerequisite groups. Membership input hashes and
the exact 69893 source versus 70374 target boundary remain recorded.

| Final artifact | SHA-256 |
| --- | --- |
| `data/catalog-source.json` | `2d83e341171aa2e405f486049bc1a2070e797061bb367e7bdda0f40d25e5bbec` |
| `data/catalog-sources.json` | `53cf81bd351863093658f951896800302dd4c477a784db8b6e4917acf2fe2cb3` |
| `data/catalog-compiled-membership.json` | `eb58d691560e6bf265ed77b16afe9e08e529de828860a6a153eb4da1c1e3147e` |
| `QuestBrief/Data/Catalog.lua` | `f515679e1640eb28246c837d4950d3be6f17f05474b96ad9b2bc403ca8377318` |

Focused closure checks actually performed:

- All 20 catalog parser/generator/provenance tests pass.
- All five classification/data tests pass; primary evidence SHA-256 remains
  `64017ae90fe4e16323044064b0ac5ba6102fba147446660fb1fd863eaf8e9ae5`.
- The numeric compiled-membership checker still verifies 2,742 exact pairs and
  988 consistent constraints without executing upstream Lua.
- A separate temporary-directory import reproduces the final source and
  provenance byte-for-byte; generating from those reproduced files matches the
  final Lua byte-for-byte.
- Shipped Lua 5.1 loads all 1,250 catalog rows, retains the three reviewed reward
  sets above, excludes 6022/1016, and returns the uncertainty note for 1882.

D1-D5 have implementation and focused-test closure. The final independent
cross-review and full `python tools/verify.py` results belong to the parent
integration task. All specific live checks recorded above remain pending;
these source, Python, and Lua-mock results do not establish native rewards,
server availability, rendering, input coexistence, coordinates/phasing, or
combat/taint safety.

## Additional independent cross-review closure — 2026-10-14

### D6 — P2: An unresolved restriction could survive on another item occurrence

The independent aggregation probe found that a valid `q(9,{groups={i(1561)}})`
and a second occurrence
`q(9,{classes=ComputeClasses(),groups={i(3578)}})` left quest 9/item 1561
unrestricted. Both pairs are in the pinned compiled membership. The original
guard excluded the invalid occurrence's pair, but eligibility belongs to the
quest ID; a different item pair could survive.

The importer now validates class/race constraints on every exact quest
occurrence, including helpers with no groups or no accepted reward items.
It reads all source occurrences before aggregation and rejects the quest ID
whenever any occurrence has an unresolved class/race restriction. The final
aggregation removes every candidate pair for that ID and records diagnostics
for otherwise valid distinct pairs. Unsupported or conflicting compiled
eligibility constraints also reject the whole quest ID.

A regression runs the actual importer `main()` against temporary hashed source
inputs and the real compiled membership. It covers computed classes, computed
races, and unknown literal classes; both source-file orders; distinct item IDs
1561 and 3578; and invalid helper occurrences without reward groups. All cases
produce no quest 9 row, while every removed candidate pair has provenance.

### D7 — P3: Constraint maps could bypass runtime list filtering

The independent generator probe replaced actual quest 96's class list with
`classTokens={"SHAMAN":true}` in the owned JSON. Iterating that dictionary's
valid key passed the earlier validator, but rendering it as a Lua map gave it
list length zero, so the runtime skipped the class filter.

The generator now requires nonempty lists for `classTokens`, `races`, and
`prerequisites`, supported string tokens or positive exact IDs as appropriate,
and no duplicates. Regression cases mutate quest 96 to dictionaries, scalars,
empty lists, and duplicate lists. Parser tests also establish that legitimate
repeated source values normalize to unique lists.

Both additional findings have implementation and focused-test closure. All
22 catalog tests, five classification tests, and the 2,742-pair/988-constraint
compiled checker pass. Temporary-directory regeneration again reproduces
source JSON, provenance JSON, and Lua byte-for-byte. Coverage, the retained
1,250/1,934/2,266 counts, 435 excluded pairs, and 454 diagnostics are unchanged.
The source JSON and Lua hashes above are unchanged; diagnostic ordering changes
the provenance hash from
`76dfab2363f64f123cc4ef77ad0a471f9dbfa855bc5c19a3dc115623f82d093f`
to the current `53cf81bd351863093658f951896800302dd4c477a784db8b6e4917acf2fe2cb3`.
Independent cross-review confirmation and parent integration checks remain
separate from these author-performed checks. The pending live checks are
unchanged.
