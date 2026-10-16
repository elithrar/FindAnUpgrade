# Validation

FindAnUpgrade **0.1.14** is the current candidate for official WoW Forever, interface
**16001**. Its earlier unpublished **0.2.0** label was superseded before merge.
The installed Forever beta on MONOLITH is **1.60.1.70425**, established from
`.build.info` and the installed Camelot addon manifests. This is installation
evidence, not a running client's `GetBuildInfo()` observation.

## Python tooling, README and current client, 0.1.14

The README follows the current XPIsland README's download-first structure,
short feature list, installation/usage and contributor/development/license
sections. Its CurseForge link is supplied by the user; public-listing visibility
was not verified. User-facing copy omits implementation history and versions.

Development uses uv 0.13.1, Python 3.15.0, Lupa 2.8 and Ruff 0.17.1 from a
locked environment. The full local verifier passes all 21 checks, including
612 Lua scenarios across 32 suites and 187 Python tests. Ruff lint and format
checks are separate from the actual
Lua/data/import/sync/package/release tests. No normalized quest facts or source
hashes changed. Exact final verifier counts and runtime architecture are in
current delivery receipts; setup and dependency pins are in DEVELOPMENT.md.

The current client contract matches 70425 at source revision
`b401e0332adfbf0460d319b06d8ea29279a941f1`. The 70338 detail-renderer fixture
remains pinned, and the prior 70374 snapshot is retained in client-contracts.json.
See CLIENT-70425-REVIEW.md for compared source behavior and installation guard.
An attempted 0.1.13 installation stopped at the changed-build guard before
writes; the installed 0.1.12 payload was preserved.

Release setup now uses `elithrar/FindAnUpgrade`, the `CF_API_KEY` secret name
and the user-supplied/read-back `CF_PROJECT_ID=1747486`. No secret value was read.
The initial release audit's missing-variable finding has been resolved in
repository configuration. Live token/project access and exact-version lookup
remain untested; no tag, release dispatch or public upload was performed.

## Star spacing and unified Options, 0.1.13

All three user-supplied screenshots were downloaded by Library identity and
inspected as pixels. They show the prior installed layout; no screenshot of
this patch in the native client has been observed.

The star now swaps one native auction-house favorite texture between empty and
filled states, without an added outline. Its visual bounds are 17 by 15.3 UI
units (15% smaller), retaining the 24 by 24 click target. Rewards start below
the complete header/star target with a six-unit minimum clearance. Captions
have five units above and eight below their measured line boxes; adjacent
horizontal groups have fourteen units between caption bounds. Item size and
native item/comparison behavior are unchanged. Native asset provenance and
independent geometry/lifecycle results are in `UI-SPACING-OPTIONS-REVIEW.md`.

Options is one window with five sections and no navigation tabs. Short screens
use a native thumb and wheel, keeping title, close, Reset and status fixed.
Scrolling cancels incomplete numeric edits and closes native menus; no settings
schema or saved values change. Quests/Shortlist retain their separate tabs.

The full verifier passes all 18 commands: 612 Lua scenarios across 32 suites
and 183 Python tests. Exact-commit build/CI/installation receipts establish
delivered bytes. Native glyphs, subpixel star rendering, physical
scroll/drag input, pointer transit, item comparisons, combat/taint and coexistence
remain live checks. Installation alone does not verify those outcomes.

## Shortlist, chains and comparisons, 0.1.12

The approved iteration adds per-character shortlist storage, Quests/Shortlist
navigation using the shared Options tab constructor, bounded grouped chain
disclosure, an owned slot command and guarded deferred native-copy dismissal.
The native comparison manager remains the authority for equipped items and
stat deltas. Exact source contracts, imported authority and known coverage
limits are in `SHORTLIST-CHAIN-CONTRACTS.md`.

Independent implementation, design and performance review findings are tracked
in this iteration's three review reports. Final full-verifier counts and
exact-commit installation/CI receipts are authoritative for delivered bytes.
The 0.1.12 Lua suite passed 606 scenarios across 32 suites. Independent
implementation, design and performance re-reviews passed after fixing optional
breadcrumb precedence, grouped disclosure, changed-selection dismissal and
Options popup cleanup. Stress retained 89 frames through 1,400 view switches
and 200 reopen sessions, with zero hidden update handlers. These are offline
call/frame counts, not native CPU measurements.

No offline preview or mock establishes physical clipboard ordering, actual
engine comparison output, native rendering, taint safety or coexistence.

## Alignment and settings review, 0.1.11

The current patch follows the source-backed `ALIGNMENT-DESIGN-PLAN.md` and
`SETTINGS-DESIGN-PLAN.md`, using the installed XPIsland 0.6.3 and AsTheCrowFlies
0.1.4 constructors. Search inputs and dropdowns share native border slices;
reward icons have a common first-row baseline with group captions below.
The native auction sorting arrow, weapon subclass returns and selected-EditBox
copy boundary are documented in `SEARCH-COPY-CONTRACTS.md`.

The settings schema advances to 4 with font, panel-border and saved search
defaults. Temporary filters remain separate; defaults apply on every next
opening. Native numeric item overlays and native tooltip/comparison content
retain their specialized font roles. Appearance changes restyle retained
results without querying the corpus. Media choices and native menu updates
are cached and driven by relevant changes.

Independent reports are `ALIGNMENT-DESIGN-REVIEW.md`,
`ALIGNMENT-BEHAVIOR-REVIEW.md` and `ALIGNMENT-PERFORMANCE-REVIEW.md`. Their final
stable-file reruns and hashes establish review acceptance. The complete
local verifier passes all 17 commands, 543 Lua 5.1 scenarios across 27 suites
and 171 Python tests. Exact-commit build receipts establish delivered bytes;
intermediate snapshots do not establish completion.

The parent reviewer observed three of the eight latest screenshots and reported
their concrete alignment findings. Library metadata/OCR for all eight were
accessible here, but their latest image bytes were not materialized in this
worker. Source inspection and independent measured-glyph constructor probes
support these corrections; no native screenshot of 0.1.11 was observed.
Physical controls, Ctrl+C, glyphs, apparent borders, fractional scaling,
item/comparison transit, native CPU, combat/taint and coexistence remain live
checks. Installation alone does not verify those outcomes.

## Fresh correctness review, 0.1.10

Six independent reviews traced the current structural owners, registered event
entrypoints, cache dependencies and stale-response guards, complete warmed and
cold workloads, matching Forever native implementations, and extracted delivery
artifacts. Prior reports and case counts were not accepted as fresh evidence.
The reports are `FRESH-ARCHITECTURE-REVIEW.md`, `FRESH-EVENTS-REVIEW.md`,
`FRESH-CACHE-REVIEW.md`, `FRESH-PERFORMANCE-REVIEW.md`,
`FRESH-NATIVE-SAFETY-REVIEW.md` and `FRESH-DELIVERY-REVIEW.md`.

The patch adds early global callback guards, query-scoped retryable metadata
reuse with revision checks, and recovery for unknown usability/uniqueness. It
repairs release fixture coverage, historical rename receipt rollback and
migration file-identity capture, and corrects font-inheritance documentation.
The approved appearance, filters and item-level heuristic remain unchanged.
The final local verifier passes all 17 commands, 511 Lua 5.1 scenarios across
27 suites and 171 Python tests. Exact-commit build, CI and installation receipts
establish the settled delivery independently of intermediate workspace archives. Measurements
are offline call/allocation evidence; native CPU, rendering, input, secret-value
behavior and combat/taint remain unobserved.

## Item-level heuristic, 0.1.9

The user's simplified direction supersedes the stat-weight system. Biggest
upgrade now means a transparent usable-slot/item-level estimate. It has no
specialization weights or scoring-style preferences and makes no prediction
of damage, healing or practical performance. Equipment legality, paired slots,
hand configuration and unknown data retain explicit guards.

`UPGRADE-RANKING-DESIGN.md` describes the current contract. Independent review in
[HEURISTIC-REVIEW.md](HEURISTIC-REVIEW.md) passed 2,328 independent comparison
cases and six registered-event scenarios, including bounded-cache overflow,
zero-work hidden events and equal-metadata no-ops. The current complete verifier
passes all 17 commands, 503 Lua 5.1 scenarios across 27 suites and 168 Python tests.

[UPDATE-INSTALLER-REVIEW.md](UPDATE-INSTALLER-REVIEW.md) records 28 successful
independent PowerShell success/failure probes. The updater requires an increased
version, verified exact source/build/payload, a closed matching client and an
unchanged prior installation; it restores the payload and receipt on failure.
It does not write SavedVariables or other addons.

The two high-resolution sidebar PNGs were saved to native Library before patch
installation. They execute the current constructor/row/menu code against verified
quest/item fixtures and reconstruct pixels with Expressway. Their illustrative
character context, numeric font and several controls are explicitly limited in
[MOCK-RECONSTRUCTION.md](MOCK-RECONSTRUCTION.md). They are not game captures or
live rendering verification. Exact-commit build, CI and installation receipts in
`dist/` establish the final delivered bytes independently of these images.

## Historical sidebar, constraints and rename review, 0.1.8

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
