# Fresh packaging and release review

Reviewed the reward-finder candidate independently from commit
`75e88b03b6e8e97500af5ccbd3e7d28ea3424235`. The initial pass owned this report;
the follow-up added package regression tests and current documentation. The
parent development task corrected the validator and runtime metadata. No game
installation, release, tag, credentials or publication was performed by this
review pass.

## Scope and evidence

The addon's manifest resolves to exactly 23 shipped files and 17 Lua modules.
`Model.lua` creates the shared namespace member before its consumers; primary
classification and catalog data precede the adapters and finder model; the UI,
finder and launcher precede `Options.lua` and `Core.lua`. `QuestBrief.toc` declares
interface 16001, the account-wide `QuestBriefDB` variable and optional providers.
The current source initializes saved settings from the matching `ADDON_LOADED`
handler. Existing quest scripts use additive `HookScript` and secure post-hooks.

The source package preserves the preferred canonical catalog JSON, provenance,
compiled-membership input, coverage, classification input and generation/import
tools. The complete ATT MIT notice has pinned SHA-256
`955281b9174e0f66b08c8e83d31e0f38b2fcaa247ca3af92d1723d81a13cddfb` in both
packages. Original code retains BSD-3-Clause and the separate XPIsland notice;
the notices distinguish ATT-derived records from original QuestBrief code.
Reference repositories, `.work`, dependency installs, Git metadata and Library
transfer directories are excluded. Release verification additionally rejects
packaged source files that do not match tracked blobs of the selected tag,
including ignored files accidentally placed below a packaged source directory.

The release path requires an annotated version tag on `origin/main`, matching
TOC metadata, clean tracked source, exact addon/source payloads, checksums,
receipts and version-specific notes. Publishing reads and validates existing
release assets instead of overwriting differing bytes. A CurseForge upload
records and confirms intent before its single POST; unresolved intent blocks a
retry and GitHub draft publication. Missing CurseForge configuration is reported
without an upload. The CI actions and client fixtures are pinned; validation
has read-only permissions, and publishing follows successful validation.

Fresh focused execution at the starting snapshot:

- `python tests/package_test.py`: eight tests passed.
- `python tests/release_test.py`: 31 tests passed, using local Git fixtures and
  mocked external services.
- Independent TOC mutation probes in a disposable source copy recorded
  `dist/fresh-release-metadata-probes.json` without invoking any publisher.

## Corrected metadata guard

`tools/package.py` checks for one matching SavedVariables declaration with
`re.search`. Appending `## SavedVariables: QuestieDB` or
`## SavedVariablesPerCharacter: QuestieDB` was nevertheless accepted. Release
verification reuses this validator and does not add a SavedVariables check.
The current TOC declares only `QuestBriefDB`, so this probe does not establish
that the reviewed runtime writes another addon's data. It demonstrates a gap
in the build guard's stated single-owner contract. The recommended correction
is an exact declaration check that rejects duplicate account-wide declarations
and any per-character declarations.

The same local validator also accepted duplicate incompatible Interface and
mismatched Version declarations. `tools/release.py` rejects these later, but
candidate packaging should apply the same exact metadata rule. The parent
replaced the presence checks with normalized metadata collection and exact
declaration checks. It now rejects additional account-wide owners, every
per-character declaration, duplicate/flavored interfaces and duplicate versions.

Fresh re-review against the 0.1.1 working candidate passed:

- `python tests/package_test.py`: 11 tests passed. Three new regression methods
  exercise 14 metadata variants, including case/spacing forms and duplicate
  correct values. Each verifies rejection before any package output exists;
  restoration of the normal TOC validates successfully.
- `python tests/release_test.py`: all 31 tests passed again.
- The four original independent mutation probes now reject each alteration.
  `dist/fresh-release-metadata-probes-0.1.1.json` records the result and exact
  validator/TOC hashes; the earlier receipt preserves the original failure.

The current TOC, Core and both README copies agree on 0.1.1. Current coverage and
verification use their authoritative receipts rather than relabeling the older
0.2.0 measurements. `VALIDATION.md` and `SEARCH-RELEASE-REVIEW.md` explicitly retain
those earlier results as historical evidence. `RELEASING.md` separates the
prepublication patch/direct-main workflow from CurseForge setup and preserves
required checks, review and branch protections. The user has separately
authorized merge and installation; neither action establishes live acceptance
or authorizes publication, credentials or a release tag.

No unresolved packaging or release guard finding remains from this pass. The
final full verification and rebuilt package receipts remain the integration
owner's responsibility after all other fixes and source changes settle.

## Verification boundary

The ATT source configuration is 1.60.1.69893; the current API contracts are
1.60.1.70374 at `735496de78ebd30ce816a0637982c556987f258c`. The baseline detail
renderer remains 1.60.1.70338 at
`943764493e6b16d63ded3ab304150d1f05e58b57`. Package inclusion and matching hashes
do not establish native rendering, current-world data accuracy, taint safety,
hosted workflow execution or a successful upload. The live checks in
`VALIDATION.md` remain pending. Any documentation or code changes after a build
require rebuilding the final source package.
