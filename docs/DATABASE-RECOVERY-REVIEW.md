# Independent recovery and sync review, 0.1.5

The recovery source, production reconciliation, adversarial probes and final
isolated full sync pass independent review. No actionable finding remains open.
This review covers database authority, starter/coordinate recovery, faction
filters, finder eligibility, acquisition freshness and staged replacement. It
does not establish native rendering, current server availability or taint safety.

The reviewer changed this report and isolated `.work/gap-review/` probes only.
No production implementation, another addon, game files or user configuration
was edited by this review. No Questie-derived data was exported. The sole new
reviewer acquisition was the specifically authorized pinned ATT resolver source;
all other investigation used retained inputs and mocked HTTP.

## Source evidence and recovered facts

ATT remains pinned to `d75383ccdbff1208b87cf4024fa425c0825a7ad6`.
The inspected `src/base.lua` resolver selects one faction branch and fills
absent/false/nil branch fields from common data; it does not union the branches.
Its SHA-256 is
`9d285d8dd3646b4db7c2cf58f9d91adeaa340a8f745925a7f08b7feac0e21396`.
The authoring/support acquisition covers 187 files; compiled categories and
input dependencies retain their pinned receipts. No upstream Lua was executed.

The independent audit partitioned all 1,315 starter gaps in the exact 0.1.4
baseline `083727c0`: 63 compiled NPC recoveries, 12 object recoveries, 48 explicit
starting-item recoveries, 11 additional faction resolver recoveries, six existing
hidden records, 200 unconfirmed public identities, three header-context cases
and 972 records without materialized starter evidence in the inspected inputs.
These are disjoint categories, with exact IDs retained in
`.work/gap-review/gap-category-reconciliation.json`.

The final production reconciliation independently reproduces these totals:

| Fact | 0.1.4 baseline | Recovery |
| --- | ---: | ---: |
| Exact quest identities | 5,669 | 5,672 |
| Compiled identities | 4,199 | 4,208 |
| Explicit starter records | 4,354 | 4,488 |
| Records with coordinates | 3,389 | 4,017 |
| Published item lists, including empty | 5,433 | 5,433 |
| Unknown item lists | 236 | 239 |

The recovery adds 134 starter records and 628 coordinate records. All previous
reward lists, groups, quantities and published amount fields remain unchanged.
The three additional identities, 93463/98289/98294, are explicit compiled hidden
quest trackers; they do not gain invented rewards or starters. The ordinary
public index still contains 5,633 exact IDs. All 39 candidates outside that
index have matching exact-URL HTTP 404 dispositions; absence is not evidence
that a quest was removed from the game.

Exact quest fields recover shared authored containers after compilation, without
guessing parent inheritance. Quest 687 preserves Alliance NPC 2786 and Horde
NPC 2787 with separate coordinates. Multi-NPC quest 8233 preserves its two
faction-specific NPC sets without zipping quest coordinates to NPC order.
`qs`/`qss` starting items remain separate from `qi`/`qis` use items and from
nested objective providers. A single explicit object-only starter can own its
direct coordinates. An inventory item activation has no assumed fixed point.
An independent NPC position joins only an already established NPC starter ID.

## Findings and dispositions

All listed implementation findings were reported with reproductions, corrected
by the implementation agent and independently retested.

| Finding | Reproducible consequence | Verified disposition |
| --- | --- | --- |
| Literal prefixes accepted as whole quest values | `q(id,{qgs={11}} and {qgs={22}})` incorrectly established NPC 11; resolver suffixes and branch expressions had the same risk | Complete literal/call/branch bounds required; unsupported expressions yield no metadata |
| Faction identity conflicts applied across branches | An Alliance NPC rejected a distinct valid Horde NPC; one branch's conflict could suppress the other branch using the same incoming ID | Conflicts compare overlapping faction scopes and are keyed by entity plus faction |
| Qualification/name lost while enriching bare records | A bare NPC stayed unqualified or lost its known name in the second branch | Exact qualifiers replace matching bare associations; original identity metadata survives each qualified point |
| Interrupted refresh forgot changed details | A second index refresh cleared a pending change, then reused a fresh but obsolete detail | Pending IDs persist until complete successful detail collection; concurrent index changes fail |
| Frozen row-count tests blocked valid sync updates | New identities or retained vanished IDs failed old fixed-count assertions | Membership tests reconcile current inputs and identity history |
| Absence/history evidence crossed trust boundaries | A mismatched quest URL became absence evidence; edited history or generated output could introduce an unsupported identity | Exact error URLs and prior frozen input hashes are checked before import; history derives from verified normalized inputs |
| Hidden tracker declarations were omitted | Published item-bearing hidden IDs 614/618 could pass static finder eligibility | All nine explicit `hqt` IDs enter identity/hidden metadata, including table-argument and end-of-file forms |
| Freshly parsed compiled IDs waited for a second refresh | Newly recognized exact compiled identities missed candidate URL checks on their first refresh | Candidate acquisition uses the freshly parsed pinned compiled cache |

The prefix and combined faction failures were synthetic supported-boundary
tests; no corresponding malformed expression or conflicting branch restriction
was found among the 67 real pinned quest resolver wrappers. The hidden-tracker
omission affected actual production records. No unsupported source relationship
was added to resolve a gap.

The finder independently rejects historical/unconfirmed records and declared
hidden trackers under static or optional rendered-provider evidence. Current
native offer, quest-log or map availability can admit them. Warm titles, item
data or recorded rewards alone cannot establish availability. Tests cover
unknown faction, Alliance/Horde changes, cache invalidation, per-point filtering
and one quest card when one NPC has multiple locations.

## Verification and remaining limits

All 35 independent probes pass: nine ownership/recovery, 13 faction/runtime/
finder, six acquisition/apply and seven importer trust cases. Commands:

```powershell
python .work/gap-review/review_recovery.py
python .work/gap-review/review_factions.py
python .work/gap-review/review_sync.py
python .work/gap-review/review_import_trust.py
```

The receipt is `.work/gap-review/independent-test-results.json`. The repository's
15 sync regression tests also pass. Independent failure inputs verify cache
tamper rejection, conditional 304 reuse, interrupted refresh recovery,
concurrent-edit protection and rollback after partial replacement.

The documented `reparse` command was independently exercised in a disposable
copied checkout, reading the owned raw caches without network acquisition.
The final run passed import, generation, all nine verifier commands, 292 Lua
scenarios, package/release checks and safe apply. Its diff contains zero added,
removed or changed IDs, and every applied catalog output matches production.
The summary receipt is `.work/gap-review/final-standalone-review.json`; the
copied command's own receipt is
`.work/gap-review/final-standalone-checkout/dist/catalog-sync-diff.json`.

The final production data separately reproduce from the frozen normalized
inputs. The independent fingerprint is
`.work/gap-review/final-recovery-review.json`; its key SHA-256 values are:

| File | SHA-256 |
| --- | --- |
| `data/catalog-complete-source.json` | `5a27d323fee0cc5ea7005bade919eae992d0f97ebb7a1ea73679236d775020ba` |
| `data/catalog-complete-sources.json` | `c439c9c27c4715818ed957da9024595946d2b2be030d0abb426f0d854c995cf9` |
| `data/catalog-reconciliation.json` | `3c6a9e447a7cd4b956f61ecc1bf8416084a1dc4f90e7af33224bf36adf752ff3` |
| `QuestBrief/Data/Catalog.lua` | `8362f4302d5f24fbeb7cce078fb57b0f53ef4dfeda5b6ea2942e5bf1a6cb93a7` |

The remaining missing starter fields are bounded source gaps: nine hidden
trackers, 200 unconfirmed identities, three Library quests with unproven parent
inheritance and 972 without inspected materialized starter metadata. Coordinates
separately distinguish item activation, mixed/multiple ownership and absent
positions. Missing reward fields remain unknown, including the complete currency
list. The encrypted client table and 707 framed cache identities do not supply
decoded reward or starter proof.

Current native rendering, published/native transitions, class-filtered choices,
player-modified reputation, NPC hover, scrolling, tooltips and combat/coexistence
remain live checks recorded in `VALIDATION.md`. This review performed no game
installation, release, merge or new primary-site acquisition.
