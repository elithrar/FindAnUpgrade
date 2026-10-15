# Validation

FindAnUpgrade **0.1.8** is the current candidate for official WoW Forever, interface
**16001**. Its earlier unpublished **0.2.0** label was superseded before merge.
The installed Forever beta on MONOLITH is **1.60.1.70374**, established from
`.build.info` and the installed Camelot addon manifests. This is installation
evidence, not a running client's `GetBuildInfo()` observation.

## Current sidebar, constraints and rename review, 0.1.8

`plan.md` records the accepted sidebar, identity, scope and ranking behavior.
`SIDEBAR-NATIVE-CONTRACTS.md`, `SIDEBAR-VISUAL-REVIEW.md`,
`SIDEBAR-STATE-REVIEW.md`, `RENAME-MIGRATION-REVIEW.md`,
`FILTERING-DESIGN.md` and `UPGRADE-RANKING-DESIGN.md` distinguish implemented
behavior, independently executed probes and pending native checks. The final
verifier, exact-commit build, CI and installation receipts establish delivered
bytes and final test counts. In-progress documents do not establish completion.

The final local verifier passed all **17 commands**, **505 Lua 5.1 scenarios** and
**168 Python tests**. Independent acceptance covers **77 state probes**,
**34 visual probes**, **1,070 ranking oracle/tooltip cases**, migration/installer
failure cases and an extracted-source rebuild of both identical archives.
Review records bind their exact runtime hashes and preserve specific live limits.

Character facts have one snapshot owner; preferences are separate. Equipment
identity and readiness, item data, quest membership, location and talent context
are invalidated only by their relevant event families. Hidden work is deferred.
Settings migration validates Lua data without executing it, preserves old files,
refuses to overwrite existing new-name files and retains future schema data.

## Historical recovery and UI review, 0.1.7

Current evidence is in `CLASSIFICATION-RECONCILIATION.md`,
`STARTER-COORDINATE-RECOVERY.md`, `REWARD-AMOUNT-RECOVERY.md`,
`RUNTIME-RECOVERY-REVIEW.md`, `UI-FINDER-REVIEW.md` and
`UI-TOOLTIP-RECOVERY.md`. Full independent review and final receipts establish
which checks passed on the exact committed build. The verifier also runs
classification regeneration, supplemental source, malformed-input and
integration regressions. No source/mocked check establishes live rendering,
physical input, combat/taint or client CPU timing.

The native quick preview preserves other addons' tooltip content. A persistent
inspector owns interactive item hover. Native tooltip height after clearing its
single appended text block and physical dropdown input still require an updated
client session; the development workflow does not force a reload.

## Historical database review, 0.1.6


`DATABASE-COMPLETION.md` records the complete acquired inventory, corrected old
associations, field coverage, reproduction commands and concrete source limits.
`COORDINATE-BINDING-REVIEW.md` records the current explicit ownership review.
`DATABASE-RECOVERY-REVIEW.md` records the earlier recovery/sync review.
`DATABASE-INDEPENDENT-REVIEW.md` records the earlier inventory review,
failure probes, fixes and final dispositions. Frozen input reconciliation
retains all 5,633 public IDs in a 5,672-ID union, without inventing empty item
lists for the 239 unknown records. Published guaranteed/choice groups,
quantities and repeated slots remain separate from current native ordinals.

New runtime scenarios cover cold metadata, published/native authority,
reputation merging, per-occurrence item metadata, confirmed-empty versus
unknown rewards, search fallback suppression and class restrictions. Import
tests challenge full-inventory omission, source truncation, Classic-column
leakage, explicit units, provider types, metadata salvage, restriction merges
and current native cache framing. The full verifier's current receipts, exact
commit CI and installation receipt are the authority for final test counts
and delivered bytes.

The current source/client inspection is not live verification. Published base
amounts versus current player modifiers, class-filtered native choices, source
empty quests, recovered NPC cards, scrolling/tooltips, combat/taint and addon
coexistence remain pending in-client checks. The installation does not reload
or close the game.

## Historical source review, 0.1.3

The current patch compares actual working installed sources against every
material construction difference. `SOURCE-UI-REVIEW.md` and its three independent
reports contain concrete evidence, explained functional adaptations, defects,
corrections and re-review results. Source construction and meaningful regression
coverage are the primary confidence basis; live testing is supplementary.
The corrected candidate records 279 Lua 5.1 scenarios and 69 Python tests. Use the
exact-commit build, main CI and installation receipts for final byte identity.

## Live regression correction, 0.1.2

The user supplied six actual 0.1.1 screenshots showing oversized hover panels,
blank settings and discarded current provider availability. Those screenshots
are failure evidence for the previous build. Its passing source/mocks did not
establish native layout or successful first-open settings construction.

The correction uses content-height native tooltip frames, native tooltip fonts,
inline coin/XP values, omitted unavailable fields, bounded long stacks and
structured current availability with fresh proof checks. Options now follow the
byte-current installed XPIsland 0.6.3 rather than an earlier recollection.
Regression diagnosis and review are in `UI-REGRESSION-OPTIONS.md`,
`UI-REGRESSION-ELIGIBILITY.md` and `UI-REGRESSION-LAYOUT.md`.

`dist/hover-layout-fixture.png` executes shipped Lua with real Georgia substitute
glyph metrics and approximate borders/icons. It is an offline layout fixture,
not WoW pixels or native rendering acceptance. Its JSON explicitly records
`nativeRenderingVerified=false`. No in-game control tools were exposed for this
iteration. The game is not closed or forcibly reloaded by the installation.

The corrected patch records **259 Lua 5.1 scenarios** plus **69 Python tests** (5 classification, 22 catalog, 11 packaging, 31 release), deterministic generation/build and no trailing whitespace. Exact final-commit and installation receipts remain the authority for built bytes.

Native first-open/reopen settings, mouse/keyboard controls, tooltip transit,
scroll clipping, reward comparisons, current availability, combat/taint and
coexistence remain live checks after the user chooses to reload the corrected
build. Do not treat older review verdicts or 0.1.1 offline counts as acceptance of
this new build.

## Current verification evidence

`python tools/verify.py` runs the Lua, classification, packaging and release
tests, builds reproducible archives, and checks source whitespace. Its full
receipt is `dist/validation-evidence.json`; Lua counts are in
`dist/test-results.json`, and payload/archive hashes are in
`dist/package-receipt.json` and `dist/SHA256SUMS`.

Use those receipts for the exact current snapshot's test counts and result.
Catalog coverage is authoritative in `data/catalog-coverage.json`; its source and
output hashes bind each measurement to the generated table. Earlier counts do
not establish that a changed candidate passed. Fresh review reports are
`REVIEW-LOOP-RELEASE.md`, `REVIEW-LOOP-DATA.md`, `REVIEW-LOOP-RUNTIME.md`,
`REVIEW-LOOP-LIFECYCLE.md`, `REVIEW-LOOP-SEARCH.md` and `REVIEW-LOOP-UI.md`.
Independent cross-checks are in `REVIEW-LOOP-DATA-CROSS.md`,
`REVIEW-LOOP-CROSS.md` and `REVIEW-LOOP-ADVERSARIAL.md`.
After corrections, run the full verifier and rebuild both archives before
merging, sharing or an authorized installation.

The historical 0.1.1 code passed `python tools/verify.py`: **193 Lua 5.1
scenarios**, **five classification tests**, **22 catalog tests**, **11 package
tests** and **31 release tests**, with deterministic generation/build and no
trailing whitespace. The native-source scenarios include the pinned tooltip
handler's callback/render ordering; engine services remain mocked. The catalog
contains **1,250 quests, 1,934 items and 2,266 recorded associations**. Independent
compiled reproduction verified **2,742 pairs and 988 constraints** without
executing upstream Lua. Current receipts bind the final build bytes separately
from merge and installation outcomes.

## Historical 0.2.0 snapshot

The completed verifier at the superseded 0.2.0 snapshot recorded the following
results. These remain historical evidence rather than counts or acceptance of
that historical 0.1.1 candidate:

- **150 Lua 5.1 scenarios**: 10 model, 38 runtime, 6 earlier independent tint
  regressions, 41 inspection, 9 Questie, 6 font, 2 current native-source cases
  and 38 reward-finder cases.
- **Five data tests** verify all 1,194 exact ID/status records, the frozen source
  checksum, 998 title groups, 18 zones and 218 new IDs. The snapshot contains
  880 unchanged, 96 modified and 218 new variants; no title status propagation.
- **12 catalogue tests** check conservative authoring parsing, source/license
  hashes, exact compiled membership, unknown counts/groups and deterministic data.
- **Eight package tests** check deterministic bytes, exact addon/source payload,
  licenses, exclusions, interface/load order, versions, Lua syntax and generated
  data freshness.
- **31 release tests** use disposable Git repositories and mocked HTTP/GitHub calls.
  They do not publish a release or contact CurseForge.

The older native detail renderer/material setter is executed against pinned
source `943764493e6b16d63ded3ab304150d1f05e58b57` (1.60.1.70338). Current native
comparison-manager methods and the actual quest-hub tooltip entry point execute
against `735496de78ebd30ce816a0637982c556987f258c` (1.60.1.70374). Fixture hashes
are checked against `client-contracts.json` before execution. Missing fixtures
are explicitly reported by the portable runner; GitHub Actions checks out both
pinned sources. Surrounding client services remain mocked.

At that earlier snapshot, independent reviewers examined UI against XPIsland,
XPIsland/ATCF commit history, API/performance and lifecycle, README, licensing,
and release handling. Findings
were fixed and re-reviewed; see `REVIEW.md` and its linked reports.

## Implemented behavior and empirical limits

Settings use persistent inspection with Shift by default, plus Ctrl, Alt or no
modifier, individual surfaces, reward details, colors/dialog tint, tint strength
and compact scale. Hold mode would prevent inspecting reward icons after release;
toggle mode would require an additional activation gesture or global binding.
Both were considered and deferred pending live input verification. The current
interaction stays consistent across surfaces and preserves native game bindings.

| Behavior from the approved plan | Implemented and checked offline | Still needs the client |
| --- | --- | --- |
| Compact vertical cards | 320 units wide; 28-unit rarity-bordered icons; one exact quest per card; plain/green/orange classification with labels | Actual native rendering, density and the four image mockups' visual match |
| Persistent inspection | Shift held before hover or pressed during hover; Ctrl/Alt/None; release persists; frozen position; Escape suppression and 200 ms leave grace | Physical pointer movement, Escape ordering, both physical modifier keys, focus switching |
| Rewards and comparison | Guaranteed versus choose-one groups, overflow expansion, native exact-ID item data rendering, separate owned comparison state/frames | Actual item variants, native comparison rules and cleanup isolation alongside other tooltip addons |
| Long stacks | Wheel and scrollbar, all identified cards reachable, capped viewport, narrow-screen fitting, clipped-icon rejection | Native clipping, scrollbar appearance, wheel/map-zoom behavior, screen edges and fractional scales |
| NPCs | Current gossip exact IDs tied to the NPC session; bundled exact starter IDs; optional Forever QuestieDB reciprocal starters; fresh native/Questie availability proofs | Current NPC token/gossip payloads, availability, provider coverage and multiple-quest NPCs |
| World map | Native objective/offer exact-ID callbacks and hub tooltip construction | Real offers/active/hub payloads, teardown and pin-pool timing |
| Questie | Installed 12.1.0 source inspected; fresh rendered quest IDs on both surfaces; no icons created; pooled/reassigned/faded/early-return guards | Actual enabled/disabled, visibility, grouped pins, load order and coexistence |
| Native minimap | Unsupported payloads leave native UI unchanged; Questie markers can supply identified quests | Native isolated/overlapping marker payloads have no proved exact-ID contract |
| Reputation | Exact exposed major-faction rows retained within that scope; ordinary reputation explicitly unavailable | Ordinary Classic faction amounts, player bonuses and spillover are not verified |
| Dialog tint | Subtle green/orange, exact variants, texture ownership restoration and native contrast priority | Real materials/skins, protected/secret behavior and combat/taint |

## Remaining live acceptance

The user has authorized merging PR #2 and then installing the verified 0.1.1
candidate. This authorization does not establish that either action occurred;
the merge result and installation receipt must record their outcomes separately.
The earlier 0.1.0 PR was separately merged and installed with user authorization.
Copying a package into the game directory is distinct from observing it in the
running client, and does not complete the acceptance checks below.

The current session exposes browser control with native Windows control disabled.
No native action or current-candidate in-game observation was made by this
packaging review, and screen lock state was not observed. Run the checklist
manually with the candidate, or use a session with native Windows control enabled.

1. Compare one unaccepted offer, guaranteed-item quest, choice quest and cold/warm
   query against the same character's native rewards. Check money/XP/currencies,
   class-hidden choices, exact item variants and ordinary reputation separately.
2. Inspect single/multiple NPC quests, native map offers/active pins/hubs and
   Questie markers on both maps. Toggle Questie, reuse pooled pins, close maps and
   invalidate current interactions. Verify no duplicate QuestBrief markers.
3. Travel from source to first/last cards and through item/comparison tooltips;
   release the reveal key, scroll/expand, press Escape while held, leave/re-enter
   and switch focus. Cover small screens, each screen edge and fractional scales.
4. Repeat in combat and through combat transitions with XPIsland, ATCF, Questie
   and the user's usual dialogue/tooltip addons. Capture the first Lua/security
   error, native tooltip ownership, frame work and in-game CPU before claiming
   taint safety or performance.

The release workflow is prepared but no release/tag/CurseForge upload has run.
CurseForge project ID and API token are still required for a future approved
upload. Acceptance remains pending where the table above names live checks.
## Reward finder 0.1.1

The standalone finder and bundled source pipeline have offline scenarios with
Questie and QuestieDB absent, including representative low-, mid- and high-level
queries using simulated native difficulty levels. The current verification
receipts record which scenarios passed after the fresh-review fixes. Source
coordinates and rewards are a partial ATT snapshot; no current-client observation
is implied.

Pending live checks on official Forever 1.60.1.70374/interface 16001:

- Cold exact-ID quest requests must populate native difficulty levels, item
  metadata and reward groups; invalid levels remain excluded. Verify failure and
  successful callbacks, cache timing, large-catalog request cost and recovery.
- Inspect default 560×600 layout, fractional UI scale, long names, four complete
  cards, resizing, expansion/collapse, wheel/bar scrolling and small screens.
- Confirm native item/comparison tooltips and safe pointer transit; data arriving
  for other rows must not dismiss inspection. Check menu/dropdown/copy-dialog
  Escape order and right-click hit clipping.
- Compare recorded questgiver coordinates against current native map geometry
  and actual NPC positions. Check unavailable/dungeon maps and waypoint failures.
- Exercise class training, equipment/level changes, completed/repeatable quests,
  missing prerequisite facts, minimap drag-release and persistent launcher hide.
- Check combat transitions, taint logs, native tooltips, Questie, XPIsland and
  AsTheCrowFlies together. Installation and merge receipts do not establish
  these live outcomes.
