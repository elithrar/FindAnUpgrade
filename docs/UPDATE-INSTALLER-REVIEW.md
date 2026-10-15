# FindAnUpgrade update installer review

Independent review of `tools/update_local.ps1` for the authorized `0.1.8` to
`0.1.9` iteration. The updater replaces the existing FindAnUpgrade folder; it
does not migrate, normalize or write SavedVariables. The historical rename
installer and its review remain separate.

Status: **accepted on the tested source hash**, with **28/28 independent
fake-client scenarios passing**. Production repairs were made by the
implementation owner. This reviewer edited only its private probes and this
record. No actual game folder, user settings, commit, tag or publication was
touched by the review.

Tested updater SHA-256:
`8fc5382f3552d65252d70b7fbe088d2520867152f4654fad0c2fc2d0d86aaf9f`.
Independent runner and machine-readable outcomes are
`.work/update-review/probe.py` and `.work/update-review/results.json`.

## Findings fixed and rechecked

1. The first version accepted equal or older semantic versions. The updater now
   requires a strict increase over the recorded installed version; numeric
   version comparison also accepts a later `0.1.10` correctly.
2. `SOURCE-TREE` was originally read after the payload transaction completed.
   A missing stamp could update files and then fail to create the receipt. The
   stamp is now read and validated as a 40-digit lowercase hexadecimal identity
   during preflight. Missing and malformed stamps leave the old installation
   and receipt intact.
3. The final receipt write was originally outside rollback. It now writes an
   owned pending receipt and atomically replaces the current receipt before
   marking the update complete. Pending-write and replacement failures restore
   the previous payload and receipt.
4. Real PowerShell execution showed that passing `$null` as the third argument
   to `File.Replace` becomes an empty string and makes otherwise successful
   updates fail. A direct scratch-file test proved `[NullString]::Value` passes
   the required null backup argument. All success and replacement-failure
   scenarios were rerun using the repaired production call.
5. A read-only existing receipt exposed an unnecessary rollback rewrite that
   could mask the original failure and skip pending-file cleanup. Rollback now
   compares the previous/current receipt bytes before writing and guarantees
   pending cleanup in a nested `finally`. Both read-only and real Windows
   sharing-violation cases restore the old state without a pending receipt.

## Executed scenarios

The runner snapshots the actual updater into isolated fixture workspaces and
invokes it with explicit fake client roots. Fake executable version/process
observations replace only client discovery; ordinary file operations execute
against the fixtures. No fake executable is launched. Every fixture path is
checked to remain inside `.work/update-review/fixtures/`.

| Group | Scenarios and asserted result |
| --- | --- |
| Successful updates | `0.1.8` to `0.1.9`, later numeric patch version, and a client starting after payload copying. New bytes and receipt match; old payload remains in the owned backup; final running count is measured. |
| Client/build identity | Already running client, wrong client build, wrong source commit, failed validation, missing/malformed source tree. Refused before installation mutation. |
| Package/version identity | Wrong addon, wrong interface, equal/older versions, archive hash mismatch, staged member hash mismatch. Old payload/settings/receipt remain intact. |
| Path/prior state | Build path outside the owned staging boundary, wrong previous installation identity, changed or unrecorded old file, existing staging or backup. No unreviewed replacement occurs. |
| Transaction failures | Injected payload copy failure and corruption after copying. Previous payload and receipt restored; no unexpected active files remain. |
| External owner changes | Settings or unrelated addon bytes deliberately change after the copy. Update fails and rolls back its payload; the external owner's changed bytes are preserved. |
| Receipt failures | Partial pending write, read-only current receipt, and an open file handle denying replacement. Previous payload/receipt restored; pending receipt removed. |

For every scenario, the runner checks the original settings file, unrelated
settings and unrelated addon content. The updater contains no settings writer;
successful receipts explicitly record `settingsWritten=false`. It neither
reloads nor closes the client. Any client observed running after mutations is
reported as observed rather than replaced with an assumed zero.

## Boundary

These checks establish the updater's file transaction and modeled client guards
on the recorded source hash. They do not establish live game rendering, physical
input, combat/taint, or that a specific build has been installed. Final full
validation, exact-commit build/CI and the actual installation receipt remain
required in the parent task. Installation must be performed only under the
user's existing explicit authorization and the updater's fresh preflight checks.
