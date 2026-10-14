# Reward finder packaging and release review

## Current 0.1.1 candidate

The unpublished finder iteration now uses **0.1.1** in its TOC, runtime metadata
and README. The earlier **0.2.0** label and review below are superseded. The user
has authorized merging PR #2 and then installing its final verified candidate;
no release, tag, CurseForge publication or credential setup is authorized.
Those permissions do not establish that the merge or installation happened.

The fresh independent packaging pass is recorded in
[REVIEW-LOOP-RELEASE.md](REVIEW-LOOP-RELEASE.md). It found that duplicate or foreign
SavedVariables declarations, per-character declarations, and duplicate metadata
could pass the candidate build. The validator now requires the single
`QuestBriefDB` owner, sole interface 16001 and one matching version, with
regressions exercising rejection before package output. Current coverage comes
from `data/catalog-coverage.json`; earlier coverage totals below apply only to
their historical snapshot. The final full verification and package receipts
must describe the completed 0.1.1 source before merge or installation.

Future publication still requires its own authorization, the reviewed commit
on `origin/main`, an annotated tag matching the selected version, version-specific
release notes and live acceptance. The existing release helpers derive their version and
archive names from the TOC; changing the local candidate label does not publish.

## Historical 0.2.0 review

The remaining sections preserve the earlier pass's evidence and conclusions,
including its test and coverage counts. References to `dist/` below describe
that earlier run; subsequent verifier/build runs replace those receipt files.
They do not certify the freshly corrected candidate.

Historical scope: local development candidate 0.2.0 on `feature/reward-finder`; no merge, tag, release, upload or installation was performed by that pass.

### Integration

- `QuestBrief.toc` and `Core.lua` agree on version 0.2.0 and retain Forever interface 16001 and `QuestBriefDB` ownership.
- `Data/Catalog.lua` loads immediately after `Data/Quests.lua`. The runtime modules retain the order `Hover.lua`, `Catalog.lua`, `SearchModel.lua`, `Search.lua`, `Launcher.lua`, `Options.lua`, `Core.lua`.
- The confirmed exact shipped allowlist contains 23 files: the prior payload, four reward-finder modules, generated `Data/Catalog.lua`, and full `Data/ATT-LICENSE.txt`. No Questie database/runtime, Blizzard source, dependency, credential or ignored reference checkout is bundled.

The catalog derives selected numeric associations/metadata and short identification labels from AllTheThings' MIT-licensed Forever authoring data at `d75383ccdbff1208b87cf4024fa425c0825a7ad6`. The complete copyright, permission and disclaimer are pinned by SHA-256 `955281b9174e0f66b08c8e83d31e0f38b2fcaa247ca3af92d1723d81a13cddfb` and retained in both archives. Original code remains BSD-3-Clause. [SEARCH-DATA-LICENSE-REVIEW.md](SEARCH-DATA-LICENSE-REVIEW.md) records the chosen source and limits; packaging does not expand that grant to another dataset.

The source package retains `data/catalog-source.json`, `data/catalog-sources.json`, `data/catalog-coverage.json`, `data/catalog-compiled-membership.json`, and the import/generation/reproduction tools, including `tools/check_membership.py`. Package validation regenerates the expected catalog and coverage in memory, applies the recorded compiled-membership gate, rejects stale bytes and refuses a substituted MIT notice even if provenance is rewritten. It does not execute ATT authoring code or acquire upstream inputs. Source build 1.60.1.69893 is distinct from the current 70374 contracts; neither build labels nor offline checks establish live accuracy.

At the final expanded snapshot, coverage records 1,267 quests, 1,977 item IDs and 2,311 associations. The compiled-membership input contains 2,742 exact pairs and 988 consistent constraints. Independent source and adversarial reviewers reproduced it without executing upstream Lua and traced every shipped pair to authored evidence. These are separate measurements of a curated subset, not complete or current live coverage.

### Release compatibility

The existing workflow and release helpers derive versions and archive names from the TOC. They accept the matching stable `v0.2.0` shape, and continue to reject mismatched versions, unsupported interfaces, dirty/untracked source, source members absent from tagged Git blobs, unexpected assets and unresolved upload records. Package tests derive their candidate version; release tests intentionally normalize a disposable fixture to 0.1.0 and include a later-version/real-notes regression.

A future release still requires explicit authorization, a reviewed commit reachable from `origin/main`, an annotated matching tag, version-specific `docs/releases/0.2.0.md`, live verification and CurseForge configuration if an upload is wanted. Neither the feature branch nor this version bump triggers publishing. Release validation expects a clean output directory containing only the two archives for the selected version; CI supplies a fresh checkout and output directory. Older local development archives are not evidence of a release.

### Validation

The completed final `python tools/verify.py` run passed all seven commands: 150 Lua scenarios (including 38 finder scenarios), 5 primary-data tests, deterministic catalog verification, 12 catalog tests, 8 package tests, 31 release tests and the final 0.2.0 build. `dist/validation-evidence.json` records the exact run time; `dist/test-results.json` records both baseline and current native-source fixture integration. These are offline/source results, not live-client observations.

This packaging pass independently repeated the 8 package tests and 31 release tests against the completed snapshot; both passed. It also inspected the actual 0.2.0 ZIPs: the addon has exactly 23 members; the source ZIP includes the compiled-membership input, reproduction tool, canonical catalog/provenance inputs and complete MIT notice with bytes matching the checkout. The MIT hash matches the pinned full grant. Root and shipped README copies are byte-identical, omit mutable catalog counts, and describe exact commands, partial coverage, separate optional preview providers and current-map/live limitations.

An earlier direct build correctly refused stale generated catalog bytes during data work. The owner regenerated the completed catalog; final checks and build passed. No data was changed by this packaging pass to bypass the guard.

The first full integration check found a search hide-handler collision: `maximum` was used as an input after scrolling replaced it with a number. The runtime owner separated the level-input fields; the completed finder suite now passes. No placeholder module was introduced to bypass validation.

No remaining package, README or release-compatibility defect was identified. Documentation and review changes made after a build require the final source ZIP to be rebuilt before sharing the candidate. The installed 0.1.0 addon remains untouched; 0.2.0 has not been installed, merged or released.

Offline checks cannot establish native rendering, item tooltip behavior, combat/taint safety, hosted workflow execution or upload success. These remain separate from package verification.
