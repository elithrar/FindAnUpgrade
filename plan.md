# FindAnUpgrade approved iteration 0.1.12

Implement native equipped comparison lifecycle, per-character Quests/Shortlist navigation, compact source-backed chain disclosure, safe `/fau slot <slot>` and platform-correct native copy input followed by guarded deferred dismissal. The mockups are directional: reuse Options/XPIsland construction, shared grid, content-sized cards and a full-size native star fill beneath the unchanged outline. Preserve unrelated addons and SavedVariables.

Audit Forever-authored prerequisite corrections against the pinned final database; preserve group semantics, optional links and provenance, keep inherited metadata nonblocking and never convert unknown availability to false. No Questie runtime requirement. Independent implementation, design and performance reviews must pass before full checks, patch commit, main CI and exact-build MONOLITH installation. No CurseForge publication. Physical client rendering/input/taint remain explicit live checks.

## Historical direction

# FindAnUpgrade sidebar iteration

## Correctness review, 0.1.10

Preserve the approved sidebar and minimal item-level heuristic. A fresh independent
review covers architecture/state ownership, events/lifecycle, cache invalidation,
complete hot/hidden workloads, Forever native contracts/taint boundaries and
packaging/persistence. Fix reproduced defects, add distinguishing regressions,
re-review stable bytes, then verify/commit/CI/install an exact patch under the
user's ongoing authorization. Review reports and receipts record unresolved
live-client observations; offline metrics are not native performance claims.

## Current direction: 0.1.9

The user's latest instruction supersedes detailed stat scoring: use usable
slots and item-level gain as a minimal heuristic. Remove specialization weights
and scoring-style settings. Do not estimate precise damage, healing or practical
power. Preserve class/faction/usability, exact variants, uniqueness, paired-slot
and hand-configuration guards; missing facts stay unknown. A two-handed reward
compares with the mean of occupied current hands; no bag partner is invented.

Create a faithful high-resolution reconstruction of the current 476 by 680
sidebar from the actual Lua layout, prior five screenshots, native artwork,
the verified screenshot font and real quest/item records. Label it as a mock,
distinguish illustrative character/equipment state from game observations and
save the PNGs as native Library images. Deliver them independently of unrelated
patch validation. Keep the underlying sidebar geometry and compact controls.

## Scope and evidence

Implement the accepted FindAnUpgrade name and the compact reward finder design.
The five supplied Library screenshots are inspected locally under
`.work/sidebar-ui-feedback/`: `135549`, `135550`, `135551`, `135553`, and
`135555`. The middle two show the same captured state. They demonstrate a
wide search field with too little vertical room, separated checkbox text,
small reward icons, uneven text/icon alignment, white quest titles, repeated
source terminology, and no direct options button. The last screenshot is the
width reference. Source geometry is 560 logical pixels; the new default is
476, a 15% reduction, with a tall sidebar shape and viewport fitting.

Target official Forever 1.60.1.70374 / interface 16001. Use the current addon
skill, byte-current XPIsland/ATCF constructors and matching native contracts.
The exact quest classification and reward database remains unchanged.

## Layout and hierarchy

1. Use a shared layout specification for 476-pixel default width, useful narrow
   resize bounds, insets, control spacing, viewport and row geometry. Default
   to the right side with reachable drag/resize controls. Fit small viewports
   without shrinking individual text to hide layout problems.
2. Build a deliberate header grid: title on the left; native settings cog and
   close button on the right; a taller 30-pixel search field in the main column
   with the slot menu beside it; aligned hide-unusable and level-range controls;
   count/current-zone summary and sort on the next baseline. Clear inherited
   checkbox/dropdown font anchors before applying explicit alignment.
3. Give every row a yellow quest title, consistent readable body typography,
   restrained neutral surface and measured height. Keep title, location and
   amounts optically aligned with a right-aligned natural-width reward area.
   Wrap useful long content rather than hiding it behind added tooltips.
4. Increase the existing 28-pixel reward icons by one third (approximately
   37.3 logical pixels), retain native rarity borders and quantity bottom-right,
   and show a verified item level bottom-left. Unknown item levels stay absent.
   Distinguish guaranteed and choose-one groups and retain expansion/scrolling.
5. Preserve native item/comparison hover. Remove custom explanatory/provenance
   hover additions and repeated `Recorded ...` / `(base)` copy from finder rows.
   Retain useful human requirements where necessary, without source jargon.

## Classification and eligibility

Classification remains exact-ID only: ordinary quests neutral, modified quests
subtly green, new quests subtly orange. A corner badge may read `New in Forever`.
The existing default-on Quest colors option controls the finder tint and badge;
turning it off preserves the yellow title and removes classification decoration.
No new classification data or title-group inference is introduced.

Check both quest faction and the actual eligible starter path. A generic/native
metadata cache or optional marker cannot admit an opposing-faction quest/NPC.
Keep NPC, object and item namespaces separate, preserve neutral/multiple valid
starters, and distinguish fresh native log/gossip proof from static records.
Test contradictory metadata and unknown identity explicitly rather than inventing
availability. The finder filters opportunities. Its ordering estimates item-level gain
against equipped gear; it does not promise mathematically proven upgrades.

## Name and migration

Rename shipped folder/TOC, runtime namespace/frame identities, SavedVariables,
package/workflow references and current documentation to FindAnUpgrade. Public
commands are `/fau` and `/findanupgrade` with the existing subcommands; drop
`/questbrief` and other old public aliases. All finder entry points use the same
panel. Preserve historical evidence and source receipts under their real names.

Do not rename the GitHub repository. Verify its canonical identity/redirect and
adapt links/remote configuration only when the user's rename is observed.

Migrate existing saved settings through validated data-only file copying and a
bounded, one-time legacy profile seed. Preserve current valid values, explicit
false and unsupported future-schema data. Never execute saved Lua as tooling.
Install one active addon: back up the verified QuestBrief payload, install only
FindAnUpgrade, and retain original saved files. New-name saved files that already
exist must not be overwritten silently. A running client's unsaved settings cannot
be read by an offline installer; check and explain that limitation before moving
the old addon or creating the final migrated settings snapshot. No forced reload,
game closure, release tag or CurseForge publication.

## Implementation and review

1. Audit native cog/control/item-level contracts and faction/start-path behavior.
2. Implement sidebar geometry/typography/icons and separate eligibility repairs.
3. Apply the complete identity rename and safe migration/packaging changes.
4. Independently review layout, typography, controls, eligibility, lifecycle,
   performance and regressions. Review the full interaction against all five
   screenshots, execute original failure cases, fix findings and re-review stable
   files. Exercise narrow/large viewports, fractional scale, long localized text,
   one/many reward groups, missing item levels, reused rows, menus, item hover,
   resize/reopen, options, slash/minimap entry points and hidden event bursts.
5. Run `python tools/verify.py`, bump the patch version consistently, commit to
   main under the iteration authorization and verify CI for the exact commit.
   Build from that commit, perform the settings-safe rename installation on
   MONOLITH, and verify payload and unrelated-addon/settings hashes.

Source and offline execution establish construction, logic and modeled lifecycle.
Native glyph metrics, physical input, final perceived appearance and combat/taint
remain live-client observations; they do not block source-identifiable fixes.
Deliver the exact commit/version, plan/review records, artifacts, CI and install
receipt, migration result and specific remaining client checks.

## Accepted second phase: filtering and upgrade ordering

Complete the layout/UX repairs first, then add these requested model/control changes.
Same zone is the default **filter**, not merely a preference in sorting. A mode
switch selects an explicit level range instead. Including dungeon quests extends
the selected scope with correctly identified dungeon quests and valid obtainable
starter/chain paths; it does not admit every historical or remotely related quest.
Keep class usability, quest/starter faction, completion and level guards intact.
Unavailable category/native context must produce an honest recoverable state,
not silently replace a requested zone filter with an all-world list.

Use a verified native red-button background and yellow sort icon with a native
menu. Default ordering is Biggest upgrade. Existing level/fit choices can remain
useful alternatives without a separate large dropdown. The header grid must
still remain readable and reachable with filter/dungeon controls.

Biggest upgrade compares eligible rewards with actual equipped configurations,
using verified item-level gain as a deliberately simple heuristic. It needs no
style or specialization choice. Define slot-family comparisons,
replacement alternatives, two-hand/off-hand/dual-wield combinations, unique/equip
restrictions, empty equipment and missing metadata before coding the estimate.
Effects are not modeled or claimed as performance. Do not sum choose-one alternatives or claim a precise DPS gain.
Unknown/incomparable candidates remain useful visible results with distinct
ordering and no fabricated zero/percentage. Record the interpretation and
limitations in the scoring design and user-facing menu where relevant, using
minimal copy and avoiding extra explanatory hover layers.

Research matching Forever contracts and working primary addon patterns. Independently
review scoring correctness, configuration comparisons, filter membership, events,
request bounds and regressions. Preserve native reward authority and all prior
no-op/hidden-work protections. No added publication or repository rename authority.

## Character constraints foundation

Use one owned CharacterConstraints snapshot as the common input to eligibility,
filtering, ranking and visible controls. Its table/type carries revisioned facts:
current faction, class, Forever specialization/talent-group context, level,
zone/instance identity, known quest/log/completion/offer state, and equipment
links/IDs/readiness/verified empty slots. Unknown facts remain explicit. Search
query, scope/range, dungeon inclusion and sort choices are user
preferences, never character facts.

Reuse the existing bounded QuestState observation/deduplication bridge rather
than adding a second full-log scanner. World/instance load, zone, level, quest
membership/completion/turn-in, equipment and relevant item-data events update
only their fact families. Compare values before advancing family/global revisions;
publish affected dependencies and coalesce visible result work. Unchanged noisy
log/cache events do no rebuild. Equipment identity and empty-state changes
invalidate both slot filtering and upgrade comparisons together. Reject stale
asynchronous item data for replaced equipment. Centralize lazy native reads and
cache ownership rather than querying the same character fact independently in
each provider/model/UI path. Hidden metadata bursts do no expensive hydration,
rendering or queries; fresh snapshots reconcile dirty facts when needed.

Test the actual event-to-fact-to-result path, old-snapshot stability, equal-value
events, equipment replacement/empty-slot changes, stale item responses, source
proof expiry, reopen and bounded requests. Keep the implementation a small clear
owner and typed Lua table, without introducing an unrelated framework.

## Implementation evidence

The accepted layout, complete identity migration, Character owner, real scope
filters and the earlier 0.1.8 stat ranking were implemented. That historical
verifier passed 17 commands, 505 Lua scenarios and 168 Python tests. Independent
visual, state, ranking and rename/package reviews are accepted and linked from
`docs/VALIDATION.md`. Delivery receipts in `dist/` bind the final source commit,
CI, exact-commit build, installation and settings preservation. Native appearance,
physical input, actual API coverage and combat/taint remain live checks.
