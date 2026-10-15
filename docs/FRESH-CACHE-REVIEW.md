# Fresh cache and asynchronous data review

Reviewed 2026-10-15 from `ac2485ad2f1af451879cbccd08a67bc1c5064306` before relying on earlier test reports. The source review covers Ranking, Character, Rewards, Providers, Sources, Catalog, SearchModel, Search, QuestState, Questie and NativeTooltip. Independent probes are under `.work/fresh-review/cache/`; their JSON receipt binds the exact source bytes. This is an offline review, not live client verification.

## Ownership and validity

| Owner | Cached state and validity | Lifetime/bound |
| --- | --- | --- |
| Ranking | Exact link plus level, identity/capability revision, GUID and reward/equipped role. Item events dirty reverse-indexed links; equipment and item revisions gate the coherent gear set. Usability also keys equipment revision. | Item and usability FIFO caches each cap at 4,096. Eviction removes reverse indexes and dirty entries. Context changes replace the caches. The gear snapshot holds at most 19 rows. |
| Character | Published snapshots carry separate identity, location, quest, equipment, item and capability revisions. Equipment metadata is accepted only for the expected current equipment revision. Old snapshot tables are not mutated. | Quest facts/tags cap at 12,000 each; metadata stamps are pruned to currently equipped identities. Pending equipment metadata is coalesced by ID, then discarded after flush. |
| Catalog / Providers | The owned catalog table identity gates the normalized record, starter and dependency indexes. Location caches also key faction; current categories key location revision and category table. Quest metadata keys player level and explicit invalidation. | Finite indexes over the owned catalog. Replacing data resets derived caches. No per-hover history. |
| SearchModel / Search | Generic item metadata is keyed by item ID. Native reward membership and usability are per quest and invalidated by quest/character evidence. Relevant item events clear metadata before comparing fresh values. Request queues and deduplication maps belong to one opening. | Result and metadata state follows catalog/current reward identities; queues reset on reopening. Cards/icons are pooled at their observed high-water, not recreated per query. |
| Hover / Rewards | A hover generation owns its requested IDs and current reward signature. Stale responses may warm native caches but cannot repopulate a dismissed generation. Reward groups are read from exact native identities or their explicitly labelled published fallback. | One current hover/session request set; dismissal drops session references. No callback closure is scheduled for every item. |
| Sources / Questie / NativeTooltip | Current owner, GUID, exact grouped IDs, data identity and native rebuild token establish the source. Native tooltip ownership additionally checks epoch, data fields, owner and exact owned text before cleanup. | Current source/session only. Hook and identity registries use weak frame keys. Native font strings are reused; tooltip frames are a fixed owned set. |
| QuestState | Active/offer snapshots and explicit event de-duplication are distinct. Quest and world transitions invalidate Character evidence before consumers re-query. | Log/active and signal windows cap at 512; no growing event history. |

## Fresh execution

The initial 15 scenarios passed 2,123 assertions through the real shipped modules. These are deliberately separate from the repository's existing suites:

- 12,000 item identities retain exactly 4,096 ranking rows, 4,096 usability rows and corresponding reverse indexes; evicted IDs cease being interested and can be reinserted.
- An equipped row evicted from the item FIFO still invalidates through the current gear snapshot, and a subsequent comparison uses its new item level.
- GUID, capability and equipment revisions cannot reuse another context's usability. Exact equipped hyperlinks do not share a ranking entry merely because their base ID matches.
- Pending items and unavailable uniqueness metadata recover after real invalidation; equal item delivery does not dirty search. Hidden invalidation makes no cache/info/use/uniqueness API calls and the next query consumes fresh metadata.
- Across 800 equipment configurations, stale revisions are rejected and the stamp table retains only the current item. Quest facts cap at 12,000 and explicit quest transitions invalidate an observed negative fact.
- A full 90-quest permanently cold finder requests each item once, leaves unknown gains unset and removes its updater after the queue/deadline settle. Five hundred unrelated item responses do not wake it.
- A hidden late item response clears metadata without scheduling finder work; reopening hydrates the current item and ranks it.
- Forty finder open/close and multi-offset scroll cycles retain exactly the warm frame/card high-water; retained Lua memory after collection changes by less than 64 KiB. This checks modeled retained objects, not native allocation or game CPU.

## Reference and fixture challenges

Inspected the installed XPIsland `Progression.lua` snapshot refresh ownership, AsTheCrowFlies `Model.lua` query-local bounded matcher cache and Questie journey lookup/work scheduling. Their responsibilities differ: XPIsland snapshots replace current facts; ATCF's 4,096-entry matcher belongs to one query. These references support explicit cache/session lifetimes, not copying a particular timer or data contract into FindAnUpgrade.

The portable fixture does not prove actual engine event ordering. The probes therefore supply strict item readiness functions that reject full reads of cold items, exercise real registered item delivery for the integrated finder, deliberately preserve exact hyperlinks, test missed/hidden delivery and count frames separately from Lua memory. Pinned Forever quest API declarations identify completion/repeatability as booleans and `QUEST_DATA_LOAD_RESULT` as a synchronous event; they do not establish when item metadata becomes ready in a live session.

## Findings fixed and independently re-reviewed

The separate fresh performance review identified repeated rebuilding of partially ready equipped metadata for every ranked quest. This review confirmed two adjacent retry gaps: `Ranking:Usable` retained `{value=nil}` until explicit invalidation/context change, and an equipped `limits-unavailable` row was treated as permanently settled. Either could keep a later deliberate query unranked after native readiness improved without a matching event.

The fix shares one opaque token across a `SearchModel:Query` and memoizes incomplete item, gear and usability reads for that query. A new query retries missing metadata. Dirty/context/equipment/item revisions override relevant pending memoization, including a reused token across a new snapshot. `limits-unavailable` uses the same retryable predicate. Ready item rows discard all query fields. Tokens are values on existing bounded rows, never keys of a growing query-history map.

The final stable-file pass passed **23 scenarios / 2,699 assertions**. Eight additional cases cover 250 shared partial associations, next-query uniqueness recovery, nil usability retry, explicit dirty override, context and snapshot revisions, and token retention after repeated queries and eviction. After 800 query generations for one pending item, at most two tokens remain; a 16-entry stress cache with 1,000 distinct generations also stays within its cache-derived bound.

An independent before/after replay loads the baseline files directly from Git into isolated `.work/` staging. It establishes these results without relying on the production regression assertions:

| Workload | Baseline 0.1.9 | Reviewed fix |
| --- | --- | --- |
| Full item-info reads for 250 associations sharing one partial equipped head | 251 | 2 |
| Unknown usability recovers on a later query without an item event | No | Yes |
| Unavailable equipped uniqueness recovers on a later query | No | Yes |

The final 40-session integration pass retained **92 frames / 8 cards**, with **0.140625 KiB** retained Lua memory delta after collection. This is fixture evidence, not a client performance measurement.

The runner checks source hashes both before and after execution and rejects a run if production files changed during it. Exact working-tree SHA-256 bindings for the cache fix are:

| File | SHA-256 |
| --- | --- |
| `FindAnUpgrade/Ranking.lua` | `0d60ddb9d6df0c66f8e0c60926e15e3867b15d98ecb379c93a75e0252fe34a7a` |
| `FindAnUpgrade/SearchModel.lua` | `4f3885b418ad4103d8270d891936a8f4e80e8507d4462d4f81bbd38a457af0c9` |
| `FindAnUpgrade/Character.lua` | `de02774f17b75214d4cd739bcab246471b37ed94999ee0e32235a0099d44914b` |

The receipt `.work/fresh-review/cache/results.json` also binds the other eight inspected modules; `.work/fresh-review/cache/before-after.json` contains the baseline replay. No additional cache defect remains open from this review.

## Live boundary

Still pending: native item-event timing and missed-event behavior, physical tooltip/pointer interaction, combat/taint, actual client CPU/GC and engine allocation behavior with the user's enabled addons. No client was launched and no installed addon or settings were modified by this review.
