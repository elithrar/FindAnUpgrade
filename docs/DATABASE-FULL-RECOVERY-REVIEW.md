# Independent full recovery review

The reviewed data/source changes pass the independent checks below. This review
read production files and retained evidence; implementation agents applied the
fixes. Reviewer changes are limited to this report and isolated probes under
`.work/full-recovery-review/`. No network corpus, website checkout, installed
addon or user configuration was changed by this review. UI review is separate.

## Exact classification authority

An independent flattening of the retained website chart matches every imported
variant's ID, title, primary status, faction, level, required level, category and
source URLs. All 232 category/faction projections and all 65 exclusion-ledger
entries agree. Faction projection filters variants before regrouping titles.

The website contributes 2,919 exact IDs in 58 categories, with 30 mixed-status
title groups. The 1,182 shared baseline IDs have no status disagreement. Adding
1,737 classifications and retaining the 12 old Side: None exclusions produces
2,931 classified IDs: 2,367 Unchanged, 176 Updated and 388 New. Excluded IDs do
not enter website category totals; titles never propagate status between IDs.

The preserved baseline matches the committed former authority byte for byte.
Both raw chart/ledger SHA-256 and byte-count receipts match the read-only site
checkout. Owned normalized/baseline hashes match the reconciled authority.
Importer and Lua generation checks also pass in an isolated minimal snapshot
with no website checkout. See [classification reconciliation](CLASSIFICATION-RECONCILIATION.md).

## Findings and verified repairs

| Reproduction | Consequence before repair | Verified disposition |
| --- | --- | --- |
| Retained exclusion `reasons=[]`; two copies of the chart receipt | Unsupported retention or missing ledger provenance passed import | Nonempty string reasons and one valid receipt per expected file are required. |
| Delete the Forever title's closing tag while retaining `</html>` | Damaged rewards became a published empty list | Structural closure/recovery checks reject the panel before staging. Valid empty lists and void tags still work. |
| Recover Shadowguard 5642 for a Horde warlock/orc | Its explicit priest/troll limits were omitted | All 105 class-restricted and 351 race-restricted new starter records retain exact final masks, including actual Skyborne IDs 95/96. Unknown bits suppress the whole provider; dynamic restriction writes are withheld. |
| Boolean primary marker type; contradictory `coord`/`coords` | Unsupported marker data supplied a navigation point | Exact numeric entity type and consistent coordinate representations are required. |
| Merge a secondary point with a primary point on the same NPC/map | Secondary coordinates could acquire primary authority | Primary proof binds exact x/y; the unrelated secondary point remains outside the primary document. |
| Rebuild supplemental metadata without raw primary HTML | Attached primary points disappeared; an initial repair added an unqualified faction duplicate | Proven primary points persist through canonical merging while preserving faction scopes and conflicts. |
| Edit frozen classification input during copy or staged verification | Old outputs could replace data after their source changed | Snapshot and pre-apply input/tool hashes reject both races. |
| Join Harb Clawhoof's old Mulgore position to 7662/7663 | A known changed frame became actionable through the global NPC channel | The two points remain unknown, their exact starter IDs remain, and `withheldGlobalPositions` records the reason. |

The last check examined every proposed newly mapped quest and all 18 ATT NPC
owners used by the global joins. Known uncertain legacy frames are UiMaps 1433,
1423, 1412 and 1453, corresponding to Areas 44, 139, 215 and 1519 in the pinned
mapping source. Filtering applies to that legacy/global enrichment channel;
independently explicit Forever quest or primary points retain their evidence.

## Final data results

The exact inventory remains 5,672 IDs. Starter coverage rises from 4,488 to
5,073; mapped coverage rises from 4,019 to 4,064. All 585 newly supplied starter
sets have exact typed reciprocal links in the pinned Forever artifact. The 45
newly mapped quests have same-quest starter ownership and matching source
points. Prior starter identities, mapped points and faction scopes survive.

All 3,606 item occurrences, quantities, group distinctions and slot ordinals
are unchanged. This includes 682's same item in both groups and separate
within-group repeated slots. Native complete empty groups cannot refill from
recorded groups. All 239 unknown item lists remain unknown; historical/hidden
records still require current native availability proof.

Reparsing all 5,633 retained public pages independently found 4,399 XP values,
1,130 money rewards, 70 separate money costs, 3,224 reputation lists and 64
explicit zero-reputation observations across 55 quests. The final 55 reputation
edits only add those zero observations; six previously absent lists become
known. Missing `reprewards` remains absent on 48 retained primary records.
Ambiguous repeated faction slots remain evidence rather than an invented sum;
runtime probes retain an independent native effective award.

XP/money reward knownness and all currency unknown states are unchanged.
Canonical reconciliation reproduces every owned input hash and exact output.
A fresh pinned-source reparse with network disabled and no primary HTML cache
produces identical canonical facts, including all six attached primary-point
quests. Repeated reparses are deterministic.

## Reproduction and limits

Run `python .work/full-recovery-review/run_review.py` in this review workspace.
Its `independent-test-results.json` receipt records **76 passing assertions in
10 isolated probe scripts**, commands, exit codes and final fingerprints.
`python tools/generate_catalog.py --check`, 12 data tests, 23 sync tests and 22
starter tests also passed in direct reviewer reruns. The normal full verifier,
packaging, commit and CI evidence belong to the implementation workflow.

Reviewed canonical SHA-256:
`28b01fdddfd7df67725ba7f054a73fc333b2c382bf20c11f8645a1307f1ef527`.
Classification authority SHA-256:
`5dc15220f63997c3bcf37d0fdfbc7b869b32ed24367df53789119faa402285eb`.
Supplemental input SHA-256:
`e40f0a5b7d9f4e0dfc00d3f8c5a4203b9a30b6ffd4038ac3823ac62bcfc6a4a2`.

No actionable data/source finding remains in this reviewed snapshot. The 599
unresolved starter records, 1,608 unmapped records, omitted amounts and currency
lists remain explicit gaps. Recorded source data and offline execution do not
establish native offer availability, effective player rewards, map rendering,
pointer/input behavior or combat/taint safety; those require live checks.

## Documentation follow-up

The revised completion, sync, starter-recovery and shipped notices were checked
against final data, sync/provider code, pinned archive and retained site facts.
Three wording findings were corrected: only 78150 remains an unresolved header
case (79536/82208 now have exact starter proof); hidden runtime records can pass
with current native proof; and failed access attempts do not mean new primary
pages were acquired. Coverage and source/reparse descriptions now agree.

An independent read-only comparison also confirms all 2,919 completed website
reward records match exact guaranteed/choice item IDs, quantities and per-group
order. Its bytes and SHA-256 match `dist/reward-site-coordination-check.json`.
The pinned Questie archive has no license/copying/copyright file; the notices
accurately avoid assigning it the repository's BSD grant. No concrete
documentation discrepancy remains after these corrections.
