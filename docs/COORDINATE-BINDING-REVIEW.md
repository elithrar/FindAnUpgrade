# Independent coordinate-binding review, 0.1.6

The bounded patch passes independent review. All reported findings were fixed
and rechecked. The final canonical output matches the independent expected diff:
only quests 9388 and 9389 change, and only their `locations` and coordinate
`fieldStates` change. No actionable finding remains open in this review scope.

## Frozen scope and evidence

The review examined every one of the 106 mixed-starter coordinate gaps in
commit `83083fb`. Its baseline canonical SHA-256 is
`5a27d323fee0cc5ea7005bade919eae992d0f97ebb7a1ea73679236d775020ba`.
All 106 have retained authored occurrences; 101 also have compiled quest
occurrences. The audit checked retained ATT inputs at
`d75383ccdbff1208b87cf4024fa425c0825a7ad6`, verifying their acquisition hashes.
It acquired no new source and used no Questie export or upstream Lua execution.

| Source evidence among the frozen 106 | Quests |
| --- | ---: |
| Explicit coordinate-alias ownership recovered | 2 |
| Top-level coordinates without per-starter ownership | 60 |
| Faction branches with multiple unpaired NPCs and points | 6 |
| No direct coordinate field | 38 |

The six branch cases are 1718, 2861, 7562, 8151, 8250 and 8417. The exact ID
partition and inspected source occurrences are retained in
`.work/binding-review/partition.json` and `binding-evidence.json`.
All 104 unresolved records remain unchanged. Equal coordinates, array order,
alias names, objective providers and general NPC-position propagation do not
establish the missing ownership relation.

## The two supported recoveries

In `.contrib/.db/forever/holidays/midsummer fire festival.lua`, quests
9389 at line 161 and 9388 at line 193 reference the same nested
`appendGroups` expression. Its two coordinate aliases have independent exact
singleton-starter anchors in that file:

| Coordinate alias | Explicit NPC owner | Anchor quests and lines |
| --- | ---: | --- |
| `FESTIVAL_LOREMASTER_COORDS` | 16817 | 9365:131, 9367:292 |
| `FESTIVAL_TALESPINNER_COORDS` | 16818 | 9339:146, 9368:315 |

Both target quests already identify those NPCs as starters. Each gains these
six explicitly owned points:

| NPC | Native map | X | Y |
| ---: | ---: | ---: | ---: |
| 16817 | 1453 | 38.5 | 61.1 |
| 16817 | 1455 | 63.6 | 24.7 |
| 16817 | 1438 | 56.6 | 92.3 |
| 16818 | 1454 | 46.8 | 38.0 |
| 16818 | 1456 | 21.3 | 26.4 |
| 16818 | 1458 | 67.6 | 8.3 |

Pinned `Shortcuts.lua:588–606` appends into its final argument. The parser
accepts only reviewed compositions whose destination is fresh, including
nested fresh compositions. It does not execute the helper or mutate aliases.
Each referenced alias must have one consistent explicit owner, valid literal
points, and a matching NPC in both the target declaration and frozen starter
scope. Contradictory or unsupported expressions remain unassigned.

The integration retains the frozen 106 IDs and starter identities in hashed
`metadata.coordinateRecovery`, together with baseline hashes, per-ID audit
causes, alias proofs and anchor paths/lines. Subsequent imports reuse that
scope. Existing direct points remain authoritative. No new starter association
or runtime logic is introduced.

## Adversarial findings and fixes

Three concrete findings were reported and independently rechecked:

- A dotted `_G.appendGroups` assignment or declaration escaped the initial
  helper-rebinding guard. Such mutations now prevent use of the pinned helper
  contract for recovery.
- A target with contradictory `qg` and `qgs` fields could prefer one field.
  Conflicting targets now remain unassigned, as conflicting anchors already did.
- The audit initially recognized only compiled `aqd`/`hqd` keys. It now also
  recognizes authored `allianceQuestData`/`hordeQuestData`, correctly recording
  the six unresolved branch cases.

The final independent suite also checks reversed alias names and starter order,
missing/conflicting ownership anchors, repeated consistent anchors, mutations,
escapes, unsupported calls, nonfresh destinations, expression suffixes,
malformed coordinate components, conflicting coordinate fields, stale target
scope, entity namespaces, equal inline points and nested objective providers.

## Final verification and limits

All 24 independent scenarios pass: 18 parser/ownership probes and six final-data
checks. Reproduction commands in this workspace are:

```powershell
python .work/binding-review/test_bindings.py
python .work/binding-review/check_final_data.py
```

The result receipt is `.work/binding-review/independent-test-results.json`.
It records each command, exit code, scenario count, output and source/data
fingerprints. The source audit and independent expected diff are also retained
under `.work/binding-review/`.

The final checks reproduce canonical data, reconciliation and generated Lua;
verify all twelve NPC/map/point associations against source values; confirm the
frozen scope and anchor receipts; and compare every row with `83083fb`.
All rewards, quantities, groups, amounts, classifications, restrictions and
starter identities remain unchanged. Coordinate coverage increases from 4,017
to 4,019 quests; the remaining mixed-starter gap count becomes 104. Identity and
starter counts remain 5,672 and 4,488.

| Final artifact | SHA-256 |
| --- | --- |
| `data/catalog-complete-source.json` | `f39ccf629d4d8dc42cb075bd375f78c190b3cdae350ccf89e16b794e84ced01a` |
| `data/catalog-complete-sources.json` | `b33c269138c9493e558508de812d9e85af5681a4699aafcaa62d7966f4607498` |
| `data/catalog-reconciliation.json` | `1a0b603c5d8f5dbfce1a2f5d094195d4d41d89e78f037ba0cf4358025129d517` |
| `QuestBrief/Data/Catalog.lua` | `34765370512ea28f8df501a0432f665d465ecc7623750a6efc4b00bddd416e6b` |

This conclusion covers the frozen 106 cases and retained pinned sources.
Historical source coordinates do not establish current quest availability or
live map/waypoint behavior. Native rendering and combat/taint checks remain
pending as documented in `VALIDATION.md`. The reviewer changed only isolated
audit/probe evidence and this report, and performed no game installation,
publication or production implementation edit.
