# Fresh delivery and persistence review

Reviewed on 2026-10-15 independently of earlier review/test totals. The frozen
baseline is FindAnUpgrade 0.1.9, commit
`ac2485ad2f1af451879cbccd08a67bc1c5064306`, tree
`b2145b8410390654b0fa740be876b4f223ef7819`. This review preserves the approved
design. It makes no claim about a running client.

## Findings from the frozen baseline

1. **Historical rename installer can fail after committing its mutations.** In
   `tools/install_local.ps1`, `$installed=$true` occurs before the rollback
   `finally`, while creation of `FindAnUpgrade-installation-receipt.json` occurs
   afterward. An injected failure of that receipt write returns failure with
   QuestBrief moved to backup, FindAnUpgrade and its copied settings present,
   and no new installation receipt. The current updater does not share this
   defect. The historical helper is pinned to 0.1.7-to-0.1.8, but the README
   still directs rename migrations through the validated development installer.
   Fix its transaction boundary or explicitly retire that workflow.
2. **Publication checks omit six current contract fixtures.** The current-source
   sparse checkout in `.github/workflows/release.yml` includes three of the
   nine files required by `tests/run.py`'s `currentNativeSourceIntegration`
   predicate. It omits `SharedTooltipTemplates.xml`, `SharedTooltipTemplates.lua`,
   `CurrencyInfoDocumentation.lua`, `DropdownButton.lua`, `GameTooltip.xml` and
   `TooltipUtil.lua`. The release verifier therefore disables that integration
   block and portions of the source-derived UI checks fall back or skip, while
   `check.yml` acquires all nine. Match their contract inputs and protect parity
   against later drift. No publication was attempted.
3. **Font notice describes the superseded selection policy.**
   `FindAnUpgrade/NOTICES.md` says Expressway is selected only through an
   installed LibSharedMedia registration. `UI.lua:Font` instead inherits the
   native tooltip family, with the standard game-font fallback. Update this
   attribution description; no font or artwork was found bundled.

These were reported to the implementation owner with their triggers and
reproductions. The baseline and fix evidence are separated below.

## Fix re-review

The workflow and font-notice fixes were independently re-read. An AST-derived
enumeration of the nine required current contract paths confirms both workflow
sparse checkouts now include every path. The revised notice matches native
tooltip inheritance and optional media notifications. `followup-results.json`
records their current bytes and the comparison.

The historical rename helper now validates `SOURCE-TREE` before mutation,
rejects existing new-name final/pending receipts, writes a pending receipt and
atomically moves it to the final path inside the rollback boundary before
marking installation complete. Twelve fresh executions of the revised script
pass, including missing/malformed tree evidence, pre-existing receipts, partial
pending writes and an actual `File.Move` destination collision. Failed cases
restore old addon/settings, remove their pending receipt and preserve
pre-existing or collision-created receipts. Success produces real boolean and
version fields in console JSON. Reviewed installer SHA-256:
`cef825437ac3d4126cf32339d262953fe1c12e21b96287d1125d9a2bc0b357ca`.
Evidence: `rename-followup-results.json`.

Follow-up found one additional copier cleanup defect: a one-shot failure of the
first `target.stat()` after exclusive creation occurred before `identity` was
assigned. Its exception handler then raised `UnboundLocalError`, leaving an
empty target that the PowerShell caller had not recorded as created. This is
preserved in `migration-failure-baseline-results.json`. The minimal fix obtains
identity from the already-open descriptor with `os.fstat`, initializes the local
identity and guards ownership-based cleanup. The original path-stat fault now
produces a complete, verified copy without any target path-stat call, recorded
in `migration-failure-fixed-results.json`. Eight other real copier executions
pass again against the revised implementation: success, direct/partial
write failure, short write, close failure, verification-read failure, an
existing target and a replacement race. They preserve originals and remove
only the copier's own partial target. All twelve historical installer cases
also pass again with the revised copier. Evidence: `migration-io-results.json`
and `rename-followup-results.json`.

The persisted regressions pass: six migration tests, including unavailable
target-path stat and partial-write cleanup; and two workflow tests, including
the AST-derived nine-file contract parity check. The final accepted copier
SHA-256 is `00a405c2045d1e16b146cbb602428dbf1e57ee655497a864b382ff4ae183dd99`.
`final-source-hashes.json` records the fixed scripts, workflows, notice and
persisted regression bytes. All findings in this review area are resolved;
the native/client boundaries below remain.

The final 0.1.10 working payload was re-executed through the actual TOC and all
36 late-restoration startup cases described below; they pass again with the
same absent/present/malformed dependency combinations. Its 27 payload hashes
are recorded in `current-startup-results.json`. Final Git/CI/installation and
archive checks belong to the implementation owner's exact-commit delivery;
the archive hashes later in this report identify only the frozen 0.1.9 baseline.

## Fresh execution

Scratch evidence is under `.work/fresh-review/delivery/`; none of its fixtures,
fake settings or extracted dependencies belongs to the shipped payload.

- `probe.py` extracts the immutable exact-commit archives from
  `.work/corrected-ac2485ad/dist`, checks unique safe archive paths, SHA-256s,
  all 27 addon files and all 183 source files against Git, then independently
  rebuilds both archives from extracted source. Both resulting archive hashes
  are identical to the original exact-commit build. TOC entries, their case,
  order and optional dependency declarations were inspected separately.
- The same probe removes the broad API shell's hard-coded addon loader and
  executes the extracted TOC entries through a shared namespace. SavedVariables
  are absent while chunks load and restored only afterward, before the matching
  `ADDON_LOADED`. It runs 36 cases: twelve settings states with optional
  dependencies absent, present or malformed. These cover first run, every
  explicit boolean opt-out, valid/false/malformed current-data precedence,
  legacy seeding, future current/legacy schemas, invalid nested values,
  non-finite numbers, ranges and obsolete scoring preferences. It exercises
  unrelated/matching/repeated `ADDON_LOADED`, login/world entry, actual minimap
  launcher construction, options opening/closing, status, writable changes and
  future-schema write rejection. No startup or settings-loss defect was found
  in these modeled paths.
- Data-only migration directly copies two valid Unicode/escaped/false settings
  inputs byte-for-byte, refuses replacement of existing new settings and rejects
  ten executable, malformed, excessive-depth or non-finite inputs without
  evaluating their Lua. `results.json` records these and the package checks:
  87 checks plus the 36 startup cases.
- `updater_probe.py` executes the actual unchanged `tools/update_local.ps1` in
  isolated fake workspaces/clients. Fifteen cases cover success, client-open
  checks including opening before mutation, wrong client/source/tree/validation,
  wrong interface/version, edited/unrecorded old files, corrupt/unexpected ZIP
  contents, partial-copy failure and receipt-write failure. Each failure preserves
  or restores the prior addon and receipt. Success retains the old payload as
  backup. All cases preserve unrelated addon/settings bytes.
- `rename_probe.py` executes the actual historical rename script with the actual
  data-only Python copier. Six cases cover success, invalid old data, existing
  new data, disabled-addon opt-out, copy rollback and the receipt failure above.
  The first five behave as expected; the sixth reproduces the finding.

No game installation, launch, reload, release, tag or external write was
performed by this review.

## Reference comparison and byte identity

Read-only installed references were XPIsland 0.6.3, AsTheCrowFlies 0.1.4 and
Questie 12.1.0 (Forever/Camelot). The older local reference checkout was not
treated as the installed ATCF version. FindAnUpgrade follows their explicit
manifest prerequisites and shared namespace pattern; its SavedVariables are
initialized after restoration, as in ATCF's matching `ADDON_LOADED` and
Questie's `OnInitialize`. XPIsland defers character/session initialization to
world entry. These differences were inspected rather than copied mechanically.
FindAnUpgrade's simple flat preferences do not need their profile/session state.

Exact baseline archive SHA-256s:

| Artifact | SHA-256 |
| --- | --- |
| Addon ZIP | `65525307b5d4d156109374e077501ceec2d0cfc57ca45df0417e8189d26902fa` |
| Source ZIP | `291fbe8bfcf54f72f62a93218dad4ee8b417e35c8a252868424c8cf9490413f3` |

Critical reviewed source SHA-256s, also recorded with the reference hashes in
`source-hashes.json`:

| File | SHA-256 |
| --- | --- |
| `Model.lua` | `cfb0fad44b2f108b9f8510a18fde1c03713afede1d4b5189d50404a7ac2fc42b` |
| `Core.lua` | `fcfe1ba0221b1b0a9b77e740b840e3b53c957583cca8d53bfde3abb24202786c` |
| `migrate_settings.py` | `c82c0fe7c960dcfc93c2bd9f6d9105862fc02dee610ff76a012a509065a23fe4` |
| `install_local.ps1` | `f3279c433b59fd4ba4f28f8a19093260f4c431bd2e7cf70aad292498f31b40a1` |
| `update_local.ps1` | `8fc5382f3552d65252d70b7fbe088d2520867152f4654fad0c2fc2d0d86aaf9f` |

During review, a verifier run regenerated the workspace's ignored `dist/` ZIPs
from checkout bytes. They differed from the immutable Git-derived artifacts;
the reviewer therefore froze the latter and reported the mismatch. Final
delivery must restore or replace `dist/` from its exact reviewed commit/build,
with matching receipts, rather than reuse an intermediate workspace build.

## Remaining boundaries

The fake client substitutes only process/build reporting for installer tests;
it does not exercise actual client files or Windows game-process races. The Lua
fixture models API availability and lifecycle, not the native frame engine.
Physical input, native font/control rendering, combat/taint, live optional-addon
interactions, client event ordering and persistence to disk across actual
logout/reload remain unverified. Static provenance and offline execution do not
establish current quest availability or live reward values.
