# Validation

QuestBrief is a review candidate for official WoW Forever, interface **16001**.
The installed Forever beta on MONOLITH is **1.60.1.70374**, established from
`.build.info` and the installed Camelot addon manifests. This is installation
evidence, not a running client's `GetBuildInfo()` observation.

## Checks performed

`python tools/verify.py` runs the Lua, classification, packaging and release
tests, builds reproducible archives, and checks source whitespace. Its full
receipt is `dist/validation-evidence.json`; Lua counts are in
`dist/test-results.json`, and payload/archive hashes are in
`dist/package-receipt.json` and `dist/SHA256SUMS`.

- **112 Lua 5.1 scenarios**: 10 model, 38 runtime, 6 earlier independent tint
  regressions, 41 inspection, 9 Questie, 6 font and 2 current native-source cases.
- **Five data tests** verify all 1,194 exact ID/status records, the frozen source
  checksum, 998 title groups, 18 zones and 218 new IDs. The snapshot contains
  880 unchanged, 96 modified and 218 new variants; no title status propagation.
- **Six package tests** check deterministic bytes, exact addon/source payload,
  licenses, exclusions, interface/load order, versions, Lua syntax and generated
  data freshness.
- **30 release tests** use disposable Git repositories and mocked HTTP/GitHub calls.
  They do not publish a release or contact CurseForge.

The older native detail renderer/material setter is executed against pinned
source `943764493e6b16d63ded3ab304150d1f05e58b57` (1.60.1.70338). Current native
comparison-manager methods and the actual quest-hub tooltip entry point execute
against `735496de78ebd30ce816a0637982c556987f258c` (1.60.1.70374). Fixture hashes
are checked against `client-contracts.json` before execution. Missing fixtures
are explicitly reported by the portable runner; GitHub Actions checks out both
pinned sources. Surrounding client services remain mocked.

Independent reviewers examined UI against XPIsland, XPIsland/ATCF commit history,
API/performance and lifecycle, README, licensing, and release handling. Findings
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
| NPCs | Current gossip exact IDs tied to the NPC session; optional Forever QuestieDB contract 3 reciprocal starters with availability-unconfirmed labels | Current NPC token/gossip payloads, availability, provider coverage and multiple-quest NPCs |
| World map | Native objective/offer exact-ID callbacks and hub tooltip construction | Real offers/active/hub payloads, teardown and pin-pool timing |
| Questie | Installed 12.1.0 source inspected; fresh rendered quest IDs on both surfaces; no icons created; pooled/reassigned/faded/early-return guards | Actual enabled/disabled, visibility, grouped pins, load order and coexistence |
| Native minimap | Unsupported payloads leave native UI unchanged; Questie markers can supply identified quests | Native isolated/overlapping marker payloads have no proved exact-ID contract |
| Reputation | Exact exposed major-faction rows retained within that scope; ordinary reputation explicitly unavailable | Ordinary Classic faction amounts, player bonuses and spillover are not verified |
| Dialog tint | Subtle green/orange, exact variants, texture ownership restoration and native contrast priority | Real materials/skins, protected/secret behavior and combat/taint |

## Remaining live acceptance

No game files or user configuration were changed, and no in-game observations
were made. This session exposes browser control with native Windows control
disabled; the native JavaScript entry point required by Computer Use is not
available. No native action was attempted or denied, and screen lock state was
not observed. Run the checklist manually with the candidate, or use a session
with native Windows control enabled.

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
