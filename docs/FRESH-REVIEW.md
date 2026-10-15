# Fresh correctness review, 0.1.10

The user approved the design and requested a fresh structural, performance,
caching, event-subscription and addon-practice review. Six separate reviewers
traced the actual implementation and challenged its mocks against matching
Forever native source and installed XPIsland, AsTheCrowFlies and Questie.
Historical test totals were not accepted as fresh evidence. No game was launched
for these reviews, and reviewers did not write game files or user configuration.

## Findings fixed

| Finding and trigger | Consequence before this patch | Final behavior |
| --- | --- | --- |
| Disabled native/Questie source callbacks resolved rows before the enabled guard. | Gossip/map/tooltip activity could capture character facts and scan the quest log while disabled. | A shared global readiness/support/enabled guard runs before source resolution. Cheap subscriptions and dirty evidence remain; finder gossip proof still works when NPC previews are off. |
| A partially known equipped item was retried for every ranked quest; repeated candidate associations had the same mechanism. | The broad owned catalog caused 2,933 repeated ranking metadata reads for one partial equipped item in one query. | One opaque query token shares retryable metadata. The measured equipped case is one read; the repeated candidate case falls from 50 to one. New queries retry. Equipment/item revisions and dirty invalidation override reuse. |
| Unknown usability and unavailable uniqueness remained cached across deliberate queries. | Without an accompanying event, a later ready item could remain unranked or retain unknown capability. | Unknown values retry once in a later query. They remain unknown until verified, and known booleans stay warm. Query references remain inside existing bounded record caches. |
| Release validation omitted six current native fixtures required by the test runner. | Future release verification could silently lack the full native-source integration exercised by main CI. | Both workflows provide all nine required files from the same pinned revision; a regression derives the dependency list from the executing runner. |
| Historical rename receipt creation happened after the rollback boundary. | Receipt-write failure could leave a completed rename and copied settings without a success receipt. | Source-tree and receipt state are checked before mutation. An owned pending receipt is atomically renamed inside the transaction; failure restores the addon/settings and removes the pending receipt. |
| The migration copier looked up the newly created file's identity by path. | A failed lookup could mask the original failure with an uninitialized identity and retain an empty copy. | Identity is captured from the open descriptor; cleanup requires established ownership. Path-lookup, partial-write, close/read failure and replacement cases were rechecked. |
| The font notice described obsolete SharedMedia face selection. | Documentation disagreed with the approved font behavior. | The notice describes inheritance from the native tooltip font family. |

No design, layout, control, filter or ranking-formula change was introduced.

## Independent evidence

- [Architecture](FRESH-ARCHITECTURE-REVIEW.md): independent full-TOC initialization,
  constraints, snapshot publication and provider-ownership execution without
  `wow_mock`, plus all 2,931 exact primary classifications.
- [Events](FRESH-EVENTS-REVIEW.md): 16 new probes and 189 retained lifecycle cases
  freshly executed; all disabled/unsupported source callbacks perform zero state
  reads. Two hundred populated browser cycles retain 28 frames and no idle updater.
- [Caches](FRESH-CACHE-REVIEW.md): 23 independent scenarios and 2,699 assertions,
  including eviction, stale revisions, nil recovery, token retention and baseline
  replay. Two hundred fifty shared partial associations fell from 251 to two total
  item-info reads in its independent fixture.
- [Performance](FRESH-PERFORMANCE-REVIEW.md): 23 complete workloads, real owned
  catalog, warm repeated UI/profile cycles and actual pinned comparison code.
  Warm cycles create no additional frames, strings or textures. Hidden/settled
  finder and departed inspections retain no recurring work.
- [Native safety](FRESH-NATIVE-SAFETY-REVIEW.md): 28 native source files verified,
  12 new probes and 106 retained cases freshly executed, including actual current
  tooltip-handler/comparison implementations and foreign singleton preservation.
- [Delivery](FRESH-DELIVERY-REVIEW.md): frozen 0.1.9 archives matched Git and rebuilt
  identically; current 0.1.10 startup/settings probes, current-updater failure
  cases, 12 repaired historical-installer cases, eight copier I/O/ownership cases
  and six persisted migration tests passed.

Each report records its source hashes and evidence limits. Final full-verifier,
exact-commit build, CI and installation receipts in `dist/` establish delivered
bytes; intermediate workspace builds are not the authoritative installed package.

## Remaining observations

Source and offline execution do not establish native frame time, rendering,
physical input, secret-value behavior, engine event timing or combat/taint.
Those remain specific live-client checks. No release/tag/publication or repository
rename is part of this correctness patch.
