# Estimated item-level ranking

The current FindAnUpgrade iteration uses a small, transparent **item-level
heuristic**. This supersedes the earlier proposed stat weights and effect scanner.
There are no scoring styles, specialization presets, weight settings or estimated
DPS/healing gains.

## Meaning of the sort

`Biggest upgrade` orders the greatest estimated item-level gain among the quest's
eligible individual equipment rewards. The sort menu explicitly names an
item-level estimate; rows show verified reward item levels rather than a
performance score or a numerical gain badge. Higher item level does not establish
better performance, appropriate secondary stats, a stronger proc or a better set
bonus. Native item/comparison hover remains the way to inspect those differences.

This is ordering, not an extra availability filter. The finder still applies its
existing exact quest/NPC faction, class/race, level, completion, current-zone or
level-range, dungeon and starter/chain eligibility checks. A positive rating
cannot authorize an opposing-faction or otherwise unavailable quest.

Guaranteed and choose-one groups remain distinct. The quest score is its best
single legal equipment replacement, without summing choices, item quantities or
items duplicated across both groups. If an unresolved equipment option could
change that best result, the quest remains unranked. Non-gear and cosmetic shirt
or tabard rewards do not acquire an equipment score.

## Equipment comparison rules

| Candidate | Estimated comparison |
| --- | --- |
| Ordinary armor slot, ranged or relic | Candidate item level minus that actual equipped slot's item level. Forever ranged/relic equipment uses slot 18. |
| Ring or trinket | Test both replacements, retaining the other item; use the greatest legal difference. Enforce exact-item and category limits over the resulting whole outfit. |
| Two-handed weapon | Compare with the mean item level of **occupied** current main/off-hand equipment, removing both when forming the proposed outfit. An equipped two-hander counts once. |
| Main-hand one-handed weapon | Compare with the equipped main hand while retaining a coherent legal off hand. Switching from a two-hander remains unranked without an established companion configuration. |
| Generic one-handed weapon | Consider both hands only with proved dual-wield context. An actual equipped pair can prove the existing dual-wield configuration. Missing capability is unknown, not false. |
| Shield, held item or off-hand weapon | Require a coherent remaining main hand; never invent a bag/future reward partner. A two-handed main hand prevents the proposed off-hand replacement. Off-hand weapons additionally need dual-wield proof. |

For example, a level-35 two-hander has an estimated gain of 10 against a level-30
main hand plus level-20 shield: `35 - ((30 + 20) / 2)`. Against a level-30 main
hand with an explicitly empty off hand, the gain is 5. Against an equipped
level-30 two-hander, the gain is also 5. An empty off hand never halves the
baseline. Contradictory two-handed-plus-off-hand configurations remain unknown.

Native explicit empty-slot evidence establishes a zero baseline. A missing link,
uncached occupied item, absent item level or failed API call does not. Empty
slots have finite absolute gain; the model produces no percentage or infinity.
Unknown legality, uniqueness, proficiency, player class/faction, item identity or
metadata remains unranked. Worn shirts and tabards retain uniqueness metadata
when checking the resulting outfit, even though their rewards have no score.
No equipment is moved or equipped by the addon.

Results sort into three deterministic tiers:

1. Comparable positive estimated gain, largest first.
2. Pending, unsupported or otherwise incomparable gear, and non-gear rewards.
3. Comparable zero or negative gain, largest first.

The finder supplies stable level/title/exact quest-ID tie breaks. The ranker
uses exact item ID when two reward options have equal gain. Unknown is never
converted to zero or silently advertised as a downgrade.

## Verified source contracts

Target: official Forever 1.60.1.70374 / interface 16001, Gethe mirror of
Blizzard-authored source at `735496de78ebd30ce816a0637982c556987f258c`.

- [C_Item contracts](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua):
  `GetItemInfo` supplies item level, minimum level, equipment location and
  class/subclass. Uniqueness calls separately supply item/category limits.
- [Character usability](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerInfoDocumentation.lua):
  `C_PlayerInfo.CanUseItem(itemID)` supplies a native boolean. It is consumed only
  with cached identity, and is shared with the finder's lightweight usability
  filter. It does not prove an invented paired outfit.
- [Paper-doll contracts](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/PaperDollInfoDocumentation.lua)
  and [loaded Camelot paper doll](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua):
  native slot identities, equipped links and equipment-change events supply the
  central Character snapshot.

The source receipts under `.work/upgrade-ranking-research/` record paths, Git
blob identities, SHA-256 and sizes. Source inspection and offline execution do
not establish observed native API values, appearance, physical input or taint.

Exact equipped hyperlinks retain their suffix/enchant identities. Generic
`GetItemInfo(itemID)` hydration does not establish a quest's random roll; generic
reward links containing modified enchant/gem/suffix fields remain unranked.
Returned item identity must match the requested item. Unconfirmed variants never
borrow a cached equipped or best-roll variant. The heuristic does not parse stats,
sets, proc/use effects, talent trees or rendered tooltip text.

## Ownership and bounded work

`FindAnUpgrade/Ranking.lua` owns a read-only metadata adapter, bounded caches and
pure comparison functions. `Character.lua` owns coherent identity, equipment,
capability and item revisions. The finder owns eligibility, queries, item request
scheduling and visible rows. The ranking module owns no events, frames, timers,
network requests, protected actions or native tooltip mutations.

Metadata retention is bounded to 4,096 records in one current identity/level/
capability context. The owned corpus currently has 2,623 distinct reward item IDs,
so those plus 19 equipped variants fit. Changing contexts discards prior contexts.
The native usability memo has the same finite bound and additionally depends on
the equipment revision. A cache keyed by complete links preserves item variants.
Current equipped dependencies remain invalidatable even after FIFO eviction.

A visible item event refreshes only previously observed records for that ID and
compares semantic metadata. Changed currently equipped exact-link metadata sends
a bounded canonical stamp through `Character:EquipmentMetadata` with the expected
equipment revision. The central owner rejects stale/replaced responses and
coalesces the resulting visible refresh. Equal events do not advance revisions;
stat-only changes are irrelevant to this item-level heuristic. Hidden events only
mark retained data dirty, with no API reads or scheduled work.

Queries consume the latest snapshot once. Sorting comparators use precomputed
results and perform no API reads. Ready warm records do not reload on repeated
queries. Pending observations retry on a later real query/reopen or relevant item
event; there is no idle polling. Non-upgrade sorts need no ranking hydration.

## Runtime API

- `Ranking:Usable(itemID, snapshot)` returns true, false or nil.
- `Ranking:Quest(items, snapshot, slotFilter)` returns `tier`, `state`, optional
  `gain`, `itemID`, `reason`, and fixed `estimated=true`, `metric="item-level"`.
- `Ranking.Compare(candidate, normalizedGear, snapshot)` is pure and returns the
  same result shape. Normalized ready records include item level, equipment
  location, usability and uniqueness.
- `Ranking:Interested(itemID)` performs a bounded-index lookup.
- `Ranking:InvalidateItem(itemID, snapshot, visible)` returns `changed` and
  `forwardedToCharacter`. Hidden delivery performs no native hydration. A true
  second return lets the UI defer its refresh to the central owner.

## Verification and remaining observations

The focused Lua 5.1 suite currently has 45 scenarios covering native adapter entry,
ordinary/paired slots, uniqueness across the retained outfit, occupied-hand
averages, absent partners, unknown dual-wield capability, exact variants, unknown
levels and usability, group/quantity preservation, deterministic ordering, cache
bounds, central metadata forwarding, stale responses and hidden event bursts.
It also verifies that stats/tooltip APIs are never used, 600 eligible reward
records have zero warm native reads, and 1,000 warm comparisons perform no native
reads or item requests.

The [independent heuristic review](HEURISTIC-REVIEW.md) passes against this
simplified implementation: 2,328 independent paired-slot, uniqueness and occupied-
hand oracle cases; six registered-event scenarios; actual 4,096-entry overflow;
and a repeated 600-item working set with zero added native reads. The reviewer
also reran the 45 focused ranking scenarios and seven shared usability scenarios.
The historical stat-score review does not establish this heuristic.

Actual item-level and usability values, equip/category restrictions, variant
behavior, native event ordering, final appearance/input and combat/taint remain
live-client checks. The accepted behavior is an explicitly approximate item-level
ordering, not a claim of mathematically proven character upgrades.
