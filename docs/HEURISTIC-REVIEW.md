# Independent item-level heuristic review

Reviewed the simplified 0.1.9 implementation on 2026-10-15 for official Forever
1.60.1.70374 / interface 16001. The user explicitly replaced stat-weight scoring
with an estimated item-level ordering. The earlier
[stat-ranking review](RANKING-ADVERSARIAL-REVIEW.md) is historical and does not
establish this implementation.

The independent source and Lua 5.1 review passes. No unresolved source-level
defect was found in the reviewed implementation. Production files were read only
to this reviewer; isolated probes are in `.work/heuristic-review/review.py` and
their output is `.work/heuristic-review/results.json`.

## Checks performed

- Read the adapter, pure comparison, shared usability/cache ownership, central
  metadata bridge, SearchModel eligibility/query ordering, native sort controls,
  authored regressions and current design against the revised requirements.
- Executed 2,000 independent ring/trinket value combinations, 128 whole-outfit
  uniqueness combinations and 200 two-handed comparisons against an independent
  mean-of-occupied-hands oracle. Empty offhands did not halve the baseline.
- Overflowed the actual 4,096-entry retention limit. An evicted equipped item
  remained an invalidation dependency and its changed level updated gain to -10.
  A warm repeated 600-item working set added zero native metadata reads.
- Executed actual registered event delivery and finder entry points. A stats-only
  change caused zero queries and no equipment revision change. An item-level-only
  change with the same equipped ID and exact link advanced the central equipment
  revision once and queried once, changing gain from +5 to -5.
- Delivered 2,000 unchanged metadata callbacks: zero queries and stable central
  equipment revision. Delivered 2,000 callbacks while hidden: zero item-info,
  usability, query or request calls, followed by a fresh -5 result on reopening.
- Held a native-menu fixture open during metadata delivery: no query until menu
  release, then exactly one query. Opposing-faction and completed quests remained
  excluded through the finder, including the quest-turn-in event path.
- Reran the 45 authored ranking scenarios and seven shared usability scenarios.
  They cover native adapter entry, cold and unknown data, explicit false versus
  unknown usability, absent one-hand/two-hand partners, unknown dual-wield
  capability, exact variants, deterministic choices, bounded caches and context
  changes. Fixture stat and tooltip getters fail immediately if the heuristic
  attempts to use them.

The minimal adapter retains exact equipped links and withholds generic modified
reward variants. Candidate and retained-outfit limits are checked separately from
the item-level arithmetic. Missing data remains unranked. The sort menu describes
an item-level estimate and makes no DPS, healing, stat, proc or set value claim.
Ranking owns no event frame, timer, item request or tooltip mutation.

## Reviewed source identity

All shipped Lua and shared fixture dependencies remained unchanged throughout the
independent probe execution. These hashes identify the final reviewed files:

| File | SHA-256 |
| --- | --- |
| `FindAnUpgrade/Ranking.lua` | `d6b66e89d75f6554171b227dc3a1e7a557603a2640101275b3e216ae0821e9c9` |
| `FindAnUpgrade/SearchModel.lua` | `b1dc4f1f0deb5b60043150245f67f1252c88faedf5394e7f70c589bb22ad5358` |
| `FindAnUpgrade/Search.lua` | `2e2b9b7beb5efe07bfb378fbe08697c23cef7d2382fab891b6a12c51fb8cc2ee` |
| `FindAnUpgrade/Character.lua` | `de02774f17b75214d4cd739bcab246471b37ed94999ee0e32235a0099d44914b` |
| `tests/ranking_test.lua` | `1b0a7eb441c58f9ca62dbbc4bcb3112cf1ec6614f4dee27d02fd759096c93d48` |

## Remaining native checks

Source and mocks do not establish actual client item-level/usability values,
complete equip/category behavior, random-variant semantics, frame/event ordering,
native comparison coexistence, combat/taint, appearance/input or native CPU.
Those remain live-client checks. Item level is an explicitly approximate ordering;
a positive number does not prove a performance upgrade. No live observations are
claimed by this review.
