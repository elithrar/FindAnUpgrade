# Fresh architecture and constraints review

Reviewed 2026-10-15 against FindAnUpgrade 0.1.9, baseline commit
`ac2485ad2f1af451879cbccd08a67bc1c5064306`, then independently re-reviewed the
stable 0.1.10 patch described below. This review did not use earlier
test totals or review conclusions as evidence. No production changes were made
by this reviewer, and no substantive structural or eligibility defect was found
in the paths examined.

## Ownership traced through actual entry points

| Entry point | State owner and downstream behavior checked |
| --- | --- |
| TOC and matching `ADDON_LOADED` | The TOC creates the shared namespace and loads prerequisites before their consumers. `Core:Initialize` reads restored settings, applies a rename seed only when the current profile is absent, and initializes one Character and one QuestState owner. File loading creates only Core's event frame; UI construction remains lazy. Later cross-module references resolve through `N` at invocation time. |
| Character identity/location/equipment capture | Character publishes a replacement snapshot before notifying Search or Hover. Snapshot copies separate active/offer maps from QuestState's mutable capture tables. Runtime character facts and finder preferences have separate owners. |
| Quest transitions | QuestState alone registers the four log-state events and owns log scanning. Dispatch invalidates Character quest facts and publishes membership before either consumer runs. Character does not create a second log scanner. |
| NPC/map/provider rows | Sources owns observed associations and marker identity; Providers owns eligibility. Providers returns owned row objects and does not add availability/evidence fields to catalog source records or QuestieDB records. |
| Eligibility | Current native log/gossip observations take precedence over contradictory static constraints. Map and optional Questie observations still pass faction, typed starter, class, race, level, completion and prerequisite checks. Historical and hidden candidates require the configured stronger native proof. Unavailable completion evidence remains unknown. |
| Finder and hover consumers | SearchModel and Hover consume Providers' availability rather than implementing separate faction/class rules. Search starts from Character's snapshot; the finder keeps above-minimum rewards inspectable with the recorded requirement visible. Hover re-resolves its exact associations after relevant character/quest changes. |
| Classification | `Model.Status` reads only generated exact-ID status data. Every authority ID was compared directly against `data/primary-statuses.json`; unknown and string IDs remain unclassified. |

No quest acceptance, abandonment, completion or reward-claim action was found in
these paths. Optional integrations read provider data and add post-hooks; they do
not write another addon's saved data. Native reward getters with names containing
`GetQuestReward` were inspected as getters rather than mistaken for quest actions.

## Independent execution

The private reproducible harness is
`.work/fresh-review/architecture/probe.py`; its receipt is
`.work/fresh-review/architecture/results.json`. It executes actual shipped modules
under Lua 5.1 and does **not** import `tests/wow_mock.lua` or any existing suite.

- Full TOC bootstrap, delayed restoration, initialization idempotence and sole
  event ownership: 48 executed assertions, including the module-loading checks.
- Direct provider proof/constraint matrix and future-profile boundaries:
  69 executed assertions.
- Snapshot alias isolation, publication-before-notification, targeted fact
  invalidation and read-only external provider consumption: 24 executed assertions.
- Unready, unsupported and disabled entry-point guards, plus re-enable recovery:
  31 executed assertions using frame/native getter inputs that error on access.
- Actual SearchModel-to-Ranking query execution over 200 repeated associations,
  separately exercising unknown usability and unknown uniqueness: 34 executed
  assertions. In each case hydration occurred once per distinct item/equipped
  link in the query, the next query recovered, ready rows released their query
  tokens, and a third warm query added no item-info or usability reads.
- All 2,931 primary status IDs matched exactly, plus three unknown/type checks.

The harness deliberately rejects eager non-Frame construction and supplies no
native UI templates. It establishes Lua initialization and state behavior; it
does not establish native constructor, rendering or taint behavior.

## Stable 0.1.10 patch re-review

Inspected the complete Sources, Questie, SearchModel and Ranking diffs. The shared
`Sources:Enabled` guard executes before native identity reads, frame access or
provider resolution in NPC, gossip, pin and hub ingress and the two Questie render
ingress paths. Gossip clears its own prior session when disabled. Re-enabling
permits fresh resolution; no game input or provider record is changed.

SearchModel creates one opaque query token and passes it through usability,
quest, gear and item lookups. Retryable metadata is reused only for that query
and its equipment/item revisions, while later queries retry it. Ready item rows
drop their token references. Dirty-item handling and the existing central
equipment publication path remain separate from the query token. Core and the
TOC change only the version to 0.1.10; Character, QuestState, Providers and the
approved UI geometry are unchanged. No new structural issue was found. All
independent probes were rerun on the file hashes below: 206 Lua assertions total,
plus the exact classification comparisons.

## Reference comparison

Inspected local XPIsland at `739dd09e14e3c30dafec90ea743e48c00f6950ab`
and AsTheCrowFlies at `433dbe2892527d9afb198d15e3b7023ec828589b`.
Both use explicit TOC ordering, a shared private namespace, separated settings/model
and client/UI responsibilities, and initialization after restored variables are
available. XPIsland additionally waits for world entry before character capture;
FindAnUpgrade's registration is lazy and its first consumer captures character
facts, so it does not assume identity is ready during addon loading.

Read the installed Questie `Modules/Tooltips/MapIconTooltip.lua`: its successful
renderer replaces `_Rebuild` and publishes `questOrder`/`npcAndObjectOrder` before
showing the tooltip. FindAnUpgrade's adapter observes that successful render and
reads exact IDs, without assigning those tables or icon data. Current pinned
70374 QuestLog declarations and QuestOfferDataProvider implementation corroborate
the quest identity/getter paths; the matching source contract is source evidence,
not a live-client observation.

## Reviewed file hashes

SHA-256 of the working files actually inspected/executed:

| File | SHA-256 |
| --- | --- |
| `FindAnUpgrade/FindAnUpgrade.toc` | `30ce3879d7d0e36f962b750d6a047ced9410f937385639410fca643a7736935b` |
| `FindAnUpgrade/Model.lua` | `cfb0fad44b2f108b9f8510a18fde1c03713afede1d4b5189d50404a7ac2fc42b` |
| `FindAnUpgrade/Adapter.lua` | `6e5bd98bd38aa991c955f9debee4e509e484fd4f4604bbe1affb79d67477da09` |
| `FindAnUpgrade/Character.lua` | `de02774f17b75214d4cd739bcab246471b37ed94999ee0e32235a0099d44914b` |
| `FindAnUpgrade/QuestState.lua` | `3582cdf8f9706b2155eebb0eecc5466f7366067c33cdac5abb4a69fa2966a86d` |
| `FindAnUpgrade/Catalog.lua` | `0506313b3849c7e327a6263553fa82422a8e446956f7fe1c172ee658993fc268` |
| `FindAnUpgrade/Providers.lua` | `ca147aca8c7d25df0846ef67a5a17a9cccce5e1324ec9710abbc69cbd3c981f3` |
| `FindAnUpgrade/Sources.lua` | `a75be894f9aa31fc0caef71526db9698255260f455089a48b2dc7657783ab494` |
| `FindAnUpgrade/SearchModel.lua` | `4f3885b418ad4103d8270d891936a8f4e80e8507d4462d4f81bbd38a457af0c9` |
| `FindAnUpgrade/Ranking.lua` | `0d60ddb9d6df0c66f8e0c60926e15e3867b15d98ecb379c93a75e0252fe34a7a` |
| `FindAnUpgrade/Search.lua` | `2e2b9b7beb5efe07bfb378fbe08697c23cef7d2382fab891b6a12c51fb8cc2ee` |
| `FindAnUpgrade/Core.lua` | `4a90e5fc7507b25fe6340d412bfdc8d231f00848c70b9e2d1c2b4c9f08ab4621` |
| `FindAnUpgrade/Questie.lua` | `552277315e82bce02a77d054f9d8320554670caf60666e9662e149ba15b3e572` |
| `FindAnUpgrade/Hover.lua` | `9b8174180bc5b6c78c8de6928346d3774baf68dc7649bd64bc80b8f2218b1d13` |

## Remaining evidence limits

No game was launched or changed by this reviewer. Native rendering, physical
input, tooltip coexistence, combat/taint, engine event delivery and client CPU
remain live checks. This focused review does not replace the independent cache,
event scheduling, hot-path, native UI or packaging reviews requested in parallel.
