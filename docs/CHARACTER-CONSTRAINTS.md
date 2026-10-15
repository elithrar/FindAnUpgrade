# Character constraints

`FindAnUpgrade/Character.lua` owns the session character facts. Filter scope,
level-range selection, sort order and scoring-style preferences remain separate.
Eligibility, the finder and reward ranking receive the same character snapshot.
This is a Lua 5.1 table/type, not a general event framework.

## Published facts

`Character:Get()` returns the current snapshot. Changed captures replace its
top-level table and changed nested tables; earlier snapshots retain their values.
Consumers treat those tables as read-only.

| Family | Fields and meaning |
| --- | --- |
| Identity | `guid`, `level`, `faction`, `classID`, `classToken`, `raceID`, `specID`, `talentGroup`, `combatConfigID`. Forever specialization IDs identify classes, not Retail roles. |
| Location | `mapID`, up to eight `mapHierarchy` entries, `zoneName`, `instanceType`, `instanceID`. No giver coordinates are used to invent quest-zone membership. |
| Quests | Copied `quests.active[id] = completionBoolean` and `quests.offers[id] = proof`, also exposed as `nativeOffers`. Exact NPC proof remains scoped to the current native source. |
| Equipment | `equipment[slot] = {slot, itemID, link, state}`, `emptySlots[slot]`, `inventorySlots[name]`. Links preserve the equipped suffix/enchantment identity. Only a native empty item location establishes `state = "empty"`; an absent link is pending. |

`revision` and the identity/location/quest/equipment/item family revisions are
dependency keys. Equipment identity, explicit emptiness and metadata readiness
share `equipmentRevision`, so the empty-slot filter and comparison model cannot
keep conflicting equipment assumptions.

`capabilityRevision` is deliberately an evidence-invalidation counter for native
spell/proficiency change signals. It does not claim to snapshot or compare the
entire spellbook. Those signals coalesce once per burst, invalidate derived
item-use legality and stay dirty while hidden. They do not introduce a second
Search event owner or weaken exact quest-log equality/no-op behavior.

Native per-ID quest facts use `Character:Quest(id)`, which caches active,
complete, completed, repeatable and disabled observations. False and unknown are
distinct. This bounded private cache avoids copying thousands of entries into
every published snapshot. `QuestTag(id)` similarly caches an exact native tag or
explicit unknown; it does not infer a dungeon from an unverified title or map.

## Ownership and refresh

The existing `QuestState` owner alone registers quest-log, accepted, removed and
turned-in events and observes a bounded log. Its Track/Prime/Dispatch bridge
publishes copied maps and invalidates only changed quest facts before consumers
receive the transition. A hidden quest event marks that owner stale. Reopening
primes once and clears old completion/prerequisite observations, even when the
active log happens to be unchanged. Collapsed headers are not expanded.

Character owns world, zone, level, equipment, talent-group and relevant item-data
events. It marks only the affected families, captures once on the next frame and
compares their values before advancing revisions or notifying visible consumers.
The level-up event's explicit level handles the interval before UnitLevel changes.
Hidden events defer capture; there are no item requests, log scans or recurring
hidden refreshes. `Ensure(true)` is the show/hover boundary that captures dirty
facts and primes quest state once. `Sleep()` removes a pending updater after the
last interested surface closes.

World entry also invalidates the already-observed quest evidence even when all
non-quest families compare equal. Completion history can change outside the active
log. A visible burst primes the existing QuestState owner once, clears the bounded
native-fact observation cache, advances its quest dependency and dispatches the
observed IDs through the existing coalesced result path. It does not scan the
catalogue or mistake an unchanged empty log for unchanged completion history.
Hidden world-entry bursts remain dirty until reopening and perform no native
hydration or queries.

Ranking owns full item-stat/effect parsing. When a relevant exact equipped
metadata fingerprint changes, it can call
`EquipmentMetadata(itemID, stamp, expectedEquipmentRevision)`. Character accepts
only a current equipped ID at the expected revision, coalesces changed stamps
and advances the shared equipment/item dependency. A stale response cannot restore
an old equipped item. Duplicate ready-item responses and unchanged stamps do not
publish another result invalidation. No second item-stat acquisition lives here.

Targeted native quest metadata results call `QuestMetadata(id)`. Hidden results
only invalidate the cached tag; visible results compare the new exact tag before
notifying the finder through its existing result scheduling path.

## Evidence

`tests/character_constraints_test.lua` exercises registered character handlers,
stable old snapshots, equal-value bursts, hidden capture deferral, level payload
timing, cyclic map bounds, occupied uncached slots, exact-link replacement,
stale item responses, metadata revision guards, targeted quest facts and unknown
tag caching. The integrated quest-state, inspection and finder suites cover the
consumer paths. These are source and Lua mock checks, not live input, rendering,
combat/taint or native frame-time observations.

The matching native sources are pinned to Forever 1.60.1.70374 at
`735496de78ebd30ce816a0637982c556987f258c`; specialization/paper-doll/item source
receipts are recorded by [the ranking design](UPGRADE-RANKING-DESIGN.md).
