# Finder scope and eligibility

Design for the accepted second phase in `plan.md`, official Forever
1.60.1.70374, interface 16001. This audit changes no classification, rewards or
availability facts. Implementation follows the full addon identity rename.

## Controls and set membership

Use one scope control with two choices, **Same zone** (default) and **Level
range**. Keep the existing minimum/maximum values when switching modes. Include
dungeon quests is a separate default-off checkbox. Both modes use the selected
level interval; Same zone additionally restricts membership to the resolved
current primary category. A dungeon addition must also pass the interval.

Let Z be exact quest IDs assigned to the current primary category, L the IDs
whose verified/native quest difficulty lies in the inclusive selected interval,
D the IDs explicitly identified as dungeon quests, and E the IDs passing the
quest, starter, completion and chain rules below. Then:

| Scope | Include dungeon quests off | Include dungeon quests on |
| --- | --- | --- |
| Same zone | Z intersect L intersect E, excluding known dungeon quests | (Z union D) intersect L intersect E |
| Level range | L intersect E, excluding known dungeon quests | L intersect E, including D |

Turning the checkbox off removes explicitly known dungeon quests, including
those with an outdoor primary category. Unknown type is not a proven dungeon
and never supplies an out-of-zone addition. A nil native tag is unknown, not a
normal-quest declaration. Raid, Group, Heroic, Scenario and PvP tags are distinct;
do not silently broaden the checkbox to those categories.

Other controls (reward slot, usable rewards and text query) intersect this set.
Ordering, including Biggest upgrade, never adds or removes a quest.

## Resolving Same zone

The owned classification source assigns 2,919 exact IDs to 58 primary categories:
42 outdoor and 16 city/subzone/transit categories. Twelve preserved classified
exclusions have no website-display category; the broader catalog contains 5,672
IDs. Classification status and primary category are independent: an unclassified
ID does not inherit a category from its title, reward, giver or coordinates.

Category `sourceZoneID` is an AreaTable/Wowhead zone identity, not a UiMapID.
Resolve it with `C_Map.GetAreaInfo` and match the localized name against the
current native zone/dungeon map and its bounded, cycle-checked parent hierarchy.
Accept only an unambiguous identity. Current `Catalog:CurrentCategories` supplies
this machinery; the phase-two query must use it for membership, not just sort
priority. Never compare an AreaTable ID numerically to a UiMapID.

The eight ancillary subzones lacking an owned AreaTable identity cannot be
independently resolved from an English label. Their exact primary membership is
not folded into the parent by geographic guess. Add a separately sourced mapping
before supporting that equivalence. Parent-zone resolution may select the owned
parent category, with only that category's exact IDs.

No resolved category means an honest empty zone set with recoverable copy such
as `Zone unavailable — choose Level range`. Do not silently show all world quests.
If dungeon inclusion is explicitly enabled, separately identified in-range
dungeon results may remain, with the missing-zone state still visible. Entering
a dungeon with no owned primary category is the same missing-context case;
an entrance/giver map does not identify the dungeon's quest category.

## Dungeon evidence and durable import

The pinned current `QuestLogDocumentation.lua` contract declares
`C_QuestLog.GetQuestTagInfo(questID)` returning nullable `QuestTagInfo`, whose
`tagID` is numeric. `Enum.QuestTag.Dungeon` is 81. Use the enum and validated,
non-secret native fields; a localized tag name is display copy, not identity.
This establishes a source contract, not observed client coverage.

The existing owned normalized catalog contains no dungeon/tag/type field. Its
`questKind` occurs on nine hidden triggers and is not a dungeon taxonomy.
The classification source deliberately covers outdoor/city/subzone/transit
categories, so it cannot supply comprehensive dungeon membership.

A targeted audit of the 135 already retained exact-ID Forever Wowhead primary
pages found explicit `type` on 36 records: 27 Group (1), seven Dungeon (81),
two Raid (62). The seven Dungeon IDs are 6922, 8908, 8920, 8940, 8958, 9009 and
9022. All 135 exact quest objects carry signed primary category IDs. Absent
`type` remains absent; the page's HTML, URL and SHA-256 are already receipted.
The approved implementation stores these 36 explicit facts in
`data/quest-taxonomy.json`, independently of the catalog and classifications:

- Exact ID and explicit numeric tag/type, tied to its exact Forever
  `g_quests[id]` object and existing source receipt. Signed categories were
  audited but are not imported into zone membership by this change.
- Generated `N.QuestTags` appended by `generate_data.py`; status authority stays solely in
  `data/primary-statuses.json`.
- Import on explicit primary-cache reparse and preserve the normalized input
  when that optional cache is absent. Validate exact ID/environment, duplicate
  objects, numeric types, hashes, conflicts and deterministic generation.
- Native non-secret exact type wins for the current session. Native nil does
  not erase a published explicit type. Conflicting explicit observations stay
  diagnostic rather than guessed. Conflicting or disappeared explicit source
  types abort a reparse for review; partial caches preserve previous exact IDs.

`python tools/quest_taxonomy.py --check` validates the owned facts offline.
An explicit `--primary-cache <directory>` imports only pages whose exact URL,
bytes and SHA-256 match `catalog-primary-records.json`. No download or JavaScript
execution occurs. Staged catalog sync imports taxonomy after the optional primary
reparse and regenerates its runtime lookup before validation and atomic apply.

Targeted cached Forever panels for 166/168/214 label The Deadmines, 388/391 label
The Stockade, and 1486 labels Wailing Caverns. That is category evidence, not an
explicit Dungeon tag. A page-wide search for `Dungeon` is contaminated by shared
navigation and comments. Neither these names, a giver map, an objective, nor an
item acquisition source establishes quest type.

Pinned ATT `dungeons & raids` authoring is a useful lead, but includes raids,
prequests, vendors and objective records. A file path or any nested `q(...)`
occurrence is not an exact Dungeon declaration. Do not import it as one without
an independent source-defined instance/type contract and precise record scope.

## Eligible starter and chain meaning

Retain the phase-one repair: generic map or optional Questie availability cannot
bypass known quest faction, exact starter faction, class/race, disabled-session,
completion or verified prerequisite constraints. An unqualified duplicate of a
typed entity cannot erase its explicit faction qualifier. NPC, object and item
IDs occupy separate namespaces. Any valid neutral/faction-correct alternative
can supply a start path; an opposing hovered NPC cannot borrow another giver.

Current native log membership and fresh exact native gossip are stronger
evidence of this player's actual quest than an older static restriction. Scope
membership still applies: an active quest outside the zone is not a zone result
unless it qualifies as an explicitly included dungeon quest. Fresh current map
offers may fill missing starter identity but cannot authorize an explicitly
opposing known path.

There are 5,073 catalog IDs with typed starters; 599 have no recorded starter.
Only 154 of 5,022 NPC location records carry an explicit starter-faction
qualifier (164 typed qualifiers overall, on 67 quests). Unknown is not proven
neutral. Do not manufacture faction from unit race, reaction or map. A static
published starter establishes an inspectable route, not a current server offer.

The catalog has 2,497 prerequisite lists and **zero** `prerequisitesVerified`
facts. Their source may contain breadcrumbs and alternatives. Existing runtime
hard-gates only a verified unsatisfied dependency, preserving all-of/any-of,
threshold, verified exclusive alternatives and unknown completion distinctions.
Completing an unverified list does not prove the chain is complete or that no
other gate exists. Do not relabel these rows `Available`.

For the requested obtainable-path guard on dungeon additions in either mode, use
the conservative rule: a current native log/gossip offer is sufficient; otherwise
require a published non-hidden exact quest, a valid typed faction-correct starter,
and no unresolved prerequisite branch. Known incomplete verified prerequisites
are blocked. Incomplete/unreadable unverified lists are unresolved and must not
be promoted into the dungeon extension as obtainable. This is a
withheld opportunity, not a claim that the quest is impossible. Normal zone/level
browsing can keep the useful known reward with its concise chain requirement,
without claiming server availability. A stricter global current-opportunities
policy would be a separate explicit choice because the source cannot prove it.

Historical/unconfirmed candidates and hidden triggers retain their existing
requirement for current native proof. Published title/reward hydration, item
cache presence, a static association and optional markers never supply it.
Negative payment costs and missing reward amounts remain separate from rewards.

## Ownership, events and verification

Take scope, current map/category, player constraints and native offers from one
query snapshot. Resolve category once per query. Cache per-ID native tag facts;
do not poll or issue catalog-wide requests while the finder is hidden. A visible
zone change recomputes membership once; identical zone/context events are no-ops.
`Character:Get`, `:Quest` and `:QuestTag` own the cached context/facts; empty-slot
filtering uses its `inventorySlots` and explicit `emptySlots` snapshot. Targeted
quest metadata arrival invalidates only its type/metadata fact. Native
quest transitions invalidate relevant eligibility/dependencies. Scope, range and
checkbox changes coalesce a query and preserve scroll/selection when possible.

Any tag hydration uses the existing bounded request owner and attempt limits.
Unknown tag after a completed attempt is not an endless retry condition. Filter
category and level before scheduling optional taxonomy work. No scan of remote
maps, quest-log header expansion, new markers or gameplay actions is needed.

Required regression cases cover exact zone membership versus giver location,
city/parent/cycle/ambiguous/unavailable context, excluded/unknown primary category,
zone-to-range switching and retained interval, dungeon toggle and tags 81/1/62,
unknown/conflicting tags, range bounds, native overrides, opposing NPC and quest
factions, alternate typed starters, incomplete/unknown chain branches and hidden
candidate guards. Exercise the visible controls plus unchanged/hidden event
bursts, queue exhaustion and metadata arrival. Independent review should rerun
the original bypass cases after the rename and model integration.

Native glyphs, physical controls, actual tag availability, engine event timing
and combat/taint remain live-client checks. This design makes no live claim.
