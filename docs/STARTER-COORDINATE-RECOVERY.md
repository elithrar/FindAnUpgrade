# Starter and coordinate recovery

This layer records exact source relationships. It does not establish that a
quest is currently offered or that a position was observed in the live client.
The existing runtime availability rules and native waypoint capability checks
still apply. Classification is independently owned by `primary-statuses.json`.

## Repeatable inputs

`tools/questie_metadata.py` acquires the public **QuestieDB 1.0.6 Forever**
artifact at revision `36ca1ca86f6c1838de479c7c7452eb0a57d5c135`. The release
ZIP SHA-256 is
`d78b066c362eaf28258d9e2d041c0a7b03d6943a2dfc741dec70c6bfd8e1fc27`.
It reads definite-length CBOR metadata as data; it never loads upstream Lua.
Every cache reparse checks the archive hash, cached member bytes, source Git
blobs and per-file SHA-256/size receipts. Raw code and archives stay in `.work/`;
only selected facts and receipts enter normalized inputs.

```powershell
python tools/questie_metadata.py acquire --source-root .work/catalog-cache/questie
python tools/questie_metadata.py reparse --source-root .work/catalog-cache/questie --catalog PATH_TO_FRESH_BASE.json --output .work/questie-metadata.json
```

The base must be rebuilt **without** this supplemental provider. Reading the
already enriched catalog as the base would make recovered fields appear to
belong to another source and suppress them on the next reparse. The normalized
receipt records the base quest-facts hash. The sync workflow owns generation,
merging and atomic replacement; see [DATABASE-SYNC.md](DATABASE-SYNC.md).

An optional `--primary-cache PATH` reads the retained exact Wowhead Forever
pages bound by `--primary-records PATH`. It makes no new Wowhead requests.
Primary marker positions have separate exact URL, SHA-256 and byte receipts;
`attach_primary_coordinates()` freezes them into the owned primary input with
exact NPC/map/x/y proofs and canonical mapping receipts. A Questie-only point
sharing the same NPC and map does not receive primary authority. Omitting the
raw primary cache on a later refresh retains those frozen positions
independently of regeneration of the Questie input.

## Source authority and ownership

The final baked artifact includes Static Corrections and Derived Passes.
Positive fields in the pinned generated Forever providers identify a separate
October 10 source refresh. The importer checks those positive facts against
the final artifact instead of assuming every inherited field is current.
See the upstream [field policy](https://github.com/Questie/QuestieDB/blob/36ca1ca86f6c1838de479c7c7452eb0a57d5c135/docs/forever-delta-base.md)
and [historical coordinate limitations](https://github.com/Questie/QuestieDB/blob/36ca1ca86f6c1838de479c7c7452eb0a57d5c135/docs/forever-data.md).

- A quest's typed `startedBy` must agree with the same entity's `questStarts`,
  or an item's scalar `startQuest`. NPC, object and item IDs remain separate
  namespaces. Objective, finisher, drop and provider-item lists cannot supply
  this proof. Existing conflicting starters are retained and diagnosed.
- Inherited reciprocal starter relationships are labelled historical recorded
  evidence. A source relationship never promotes an unconfirmed quest ID into
  the published inventory. Declared hidden triggers remain excluded.
- New relationships carry the artifact's exact race/class masks. The pinned
  enum maps race IDs 95/96 to bits 32/33; `raceID - 1` is invalid here. Unknown
  bits suppress the entire provider record. Explicit zero does not erase a
  restriction recorded by another source. Conflicts must fail closed when
  merging. Dynamic writes to these fields also suppress the frozen record.
- New coordinates require a positive generated Forever spawn point that
  survives final composition. Inherited Era positions are withheld. Movement
  paths, phase-qualified points, instance sentinels and changed map frames
  without independent point proof are withheld.
- Map conversion uses only canonical reciprocal AreaID/UiMap pairs. Parent
  routes, compatibility dungeon-floor aliases and continent overrides do not
  establish a coordinate frame. No coordinate is projected or rounded again.
- Retained primary positions require the **same quest's** explicit NPC start
  marker and an already established matching NPC starter. Objective/end markers
  and object/item acquisition positions are not promoted. Existing points and
  faction qualifiers survive enrichment.
- Item starts remain portable activation paths. A book, corpse or container
  that yields a starting item does not establish a fixed activation point for
  that item. Quest 1100's journal is intentionally not used as such a point.

The original import order also lost positions for starters first established
by retained primary pages. Position enrichment now follows that identity
merge. Quest 8586/NPC 8125 provides the regression: its exact compiled Tanaris
point enriches the primary-established giver without a new association.

## Recovery evidence and remaining limits

Against the pre-recovery 5,672-ID base, the supplemental source supplies
**585 previously absent starter records**: 388 NPC-only, 181 item-only,
15 object-only and one mixed record. Of those quests, 105 carry class limits
and 351 carry race limits. The fixed-position subset is deliberately smaller:
12 quests have qualifying generated Forever points. Retained primary markers
add six further quest positions. Applying existing independently owned global
NPC points after all starter identity merges adds 29. Two historical Mulgore
points (7662/7663) are withheld because their changed coordinate frame lacks
current point proof, for **45** additional positioned quests overall.
These are source-level recoveries, not live placement results.

Examples include the exact Shattered Orb start for quest 78093, Alonso's
recorded positions for 78132/78133/78134 and Shen'dralas NPC positions for
92844/92846/93035/93037/93041/93128. Shadowguard 5642 retains Troll race
and Priest class constraints; its new NPC relationship does not apply to an
Orc Warlock.

Remaining missing locations still include portable item starts, records with
no exact source relationship, unconfirmed historical IDs, hidden trackers,
unproven parent-header inheritance and source points whose ownership/frame or
conditional applicability is unresolved. Inherited converted positions were
not relabelled as current observations to improve coverage. Current primary
page acquisition is separately limited by source access policy/challenges;
normal blocked access is not bypassed.

`tests/starter_coordinate_recovery_test.py` checks typed reciprocal identities,
malformed CBOR/receipts, nil holes, selected-expression rejection, exact
race/class masks and Skyborne bits, dynamic restriction writes, unknown-bit
failure, source point survival, source conflicts, preserved faction scopes,
mobile/phase/map rejection, retained primary marker ownership and repeat
imports from a fresh base. Broader canonical, package and runtime checks run
through `python tools/verify.py`. Native rendering, physical input, actual
map placement and combat/taint behavior require client observations.
