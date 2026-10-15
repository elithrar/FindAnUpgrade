# Independent ranking review

Review date: 2026-10-15. Target: official Forever 1.60.1.70374,
interface 16001. This review uses pinned source and Lua 5.1 execution; it does
not establish in-game rendering, API values, combat/taint behavior or native CPU.

Status: the independent source/model review passes on the hashes below. All
reproduced findings were fixed by their production owners and the original
probes were rerun. Production files were read only to this reviewer. Isolated
probes and measured outputs live under `.work/ranking-adversarial/`.

## Reproduced findings

1. **Shield-style legality:** a Paladin using Shield tank could receive a positive
   score for replacing its shield with a held offhand. The actual adapter entry
   returned `ready`, gain 37, for stamina 40 replacing stamina 3. The author added
   an offhand shield-style guard; the original probe now returns unranked.
2. **Cache working-set churn:** 600 distinct ready rewards exceeded the original
   512-entry FIFO. A second identical pass made 2,400 native item reads. The author
   enlarged and context-bounded retention; the original 600-item probe now makes
   zero further reads. SearchModel now skips full ranking for every sort except
   Biggest upgrade. A 600-row Title query makes zero ranking calls; its initial
   600 item-info reads belong to displayed metadata, with zero additional reads
   on the identical warm query.
3. **Evicted equipment dependency:** a retained gear snapshot can outlive its
   corresponding normalized FIFO entry. With a deliberately small cache limit,
   an equipped item's metadata event was ignored after eviction. Its old +5
   comparison survived even though the updated equipped stats require -10.
   The ranker now tracks current gear dependencies independently of FIFO
   admission. Both the deliberately small-cache reproduction and eviction beyond
   the actual 4,096-entry bound refresh the comparison to -10 and retain the
   configured bound.
4. **Reward variant provenance:** a generic reward link carrying an unverified
   random suffix could receive a numeric score. The author now rejects modified
   generic reward links while retaining exact equipped variants. The original
   suffix probe is now unranked, including modified generic links returned by
   item lookup.
5. **Shared metadata revisions:** stats becoming available while an equipped
   item's ID, exact link and ready state stayed unchanged originally refreshed
   ranking through a private cache invalidation without advancing the character
   snapshot. Ranking now forwards a stable semantic stamp to
   `Character:EquipmentMetadata`, guarded by exact current identity and expected
   equipment revision. The independent state reviewer executed actual registered
   event delivery and observed equipment revision 1 to 2 with exactly one query.
   Its unchanged and hidden event bursts also pass; see
   [the state review](SIDEBAR-STATE-REVIEW.md).

The adapter also hides vendor prices explicitly and accepts the native cosmetic
SellPrice line rather than treating an otherwise ordinary item as an effect.

## Checks performed

- Read the TOC, ranking adapter and pure model, Character owner, SearchModel query,
  sidebar sort controls and metadata event entry points, and ranking scenarios.
- Read the addon skill's client/source, performance/ownership and validation
  references and the current `AGENTS.md`.
- Executed an independent 1,000-case ring replacement oracle covering unequal,
  equal, positive, zero and negative normalized intellect comparisons.
- Executed 64 independent unique-category/same-item configuration cases,
  including retained matching equipment outside the paired ring slots.
- Executed six independent structured-tooltip cases: partial, unknown, enchant,
  equip-effect and restricted lines stay unranked; cosmetic vendor-price data is
  accepted and the native hide-vendor-price argument is true.
- Exercised actual `SearchModel:Query` with 600 eligible published quest records,
  exact full links, a stable shared character snapshot and Title sorting.
- Repeated the 600-item upgrade working set without further native item reads;
  overflowed the actual 4,096-record bound and verified both bounded retention
  and refreshed equipped metadata after eviction.
- Reran all 47 authored ranking Lua 5.1 scenarios, including context changes,
  native-adapter entry, pending baseline retry, effects, hand configurations,
  metadata invalidation and absence of native reads from the pure comparator.
- Inspected pinned Blizzard item, uniqueness, tooltip-line and talent contracts;
  independently verified all 24 source receipts against SHA-256 and Git blob
  identities, including
  [C_PlayerInfo.CanUseItem](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerInfoDocumentation.lua).

The final execution asserted that all shipped Lua and shared fixture dependencies
were unchanged for the duration of the probes. Evidence:
`results-latest.json`, `dependency-hashes.json` and `focused-results.json` under
`.work/ranking-adversarial/`. Full source hashes:

| File | SHA-256 |
| --- | --- |
| `FindAnUpgrade/Ranking.lua` | `839e4a72fe799db08bcb0ec30564fb242ec140ae46261c7eec55d10fa006327f` |
| `FindAnUpgrade/SearchModel.lua` | `ccb08d2f4d4d346300934f33fc901fdfcee360902ee2c2d975af4391eddf5c86` |
| `FindAnUpgrade/Search.lua` | `98f94ba1c87644bfad55008aa2cc8c37030a46903f8257ec64336b90c63d71e8` |
| `FindAnUpgrade/Character.lua` | `de02774f17b75214d4cd739bcab246471b37ed94999ee0e32235a0099d44914b` |
| `tests/ranking_test.lua` | `4c7a33c297bd2598e34d57bbf8c055e2c7082572188f2de403513cb8fa1a42f1` |

## Native checks remain pending

Observe actual `GetItemStats` keys/units and structured tooltip completeness,
uniqueness/equip restrictions, initialized Forever talent groups and event timing,
random-reward variants, metadata callbacks, comparison-tooltip coexistence,
combat/secret behavior, and client CPU with a populated finder. Unsupported
weapons/effects must remain available for native inspection without numeric claims.

The implementation deliberately does not listen broadly to tooltip updates to
recompute rankings. Tooltip-only readiness without a relevant item event recovers
on the next real query or reopening; unsupported data remains unranked until
then. This recovery boundary is recorded in the ranking design. Initial native
query cost and event timing still need a populated-client measurement; mock call
counts do not establish smooth in-game performance.
