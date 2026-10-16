# Release readiness, 2026-10-16

Repository: `elithrar/FindAnUpgrade`. This audit does not publish a release.
PR #4 merge and local installation were explicitly approved separately.

## Configuration and remaining requirement

GitHub metadata confirms `CF_API_KEY` exists (updated 2026-10-16T03:02:59Z).
Only its name and update timestamp were read; its encrypted value, validity and
CurseForge project permissions were not accessed or tested. The workflow now
passes this exact secret to the upload step under the same environment name.

**Required before CurseForge publication: set the repository Actions variable
`CF_PROJECT_ID` to FindAnUpgrade's exact positive numeric project ID.** Its
metadata endpoint returned 404 while repository ADMIN access and secret metadata
reads succeeded. No ID is inferred from a name, slug or another addon.
See [RELEASING.md](RELEASING.md) for the setup and publication procedure.

## Contracts checked

- The workflow and Python publisher allow only `elithrar/FindAnUpgrade`.
  Current README links and Git origin use the renamed repository. Legacy
  SavedVariables and historical source/review provenance retain their identity.
- Branch pushes, PRs and merging do not trigger publication. Release requires an
  explicitly authorized annotated `vX.Y.Z` tag push, or manual dispatch naming
  an existing matching annotated tag reachable from main. No tag or dispatch
  was created by this audit.
- Validation uses `contents: read`; only the publish job requests
  `contents: write` for GitHub draft assets and final publication. The repository
  has Actions enabled, allows the pinned actions and defaults to read-only token
  permissions. Its workflow can request the publish job's explicit permission;
  hosted publication with that token remains unexecuted.
- ZIP layout is `FindAnUpgrade/FindAnUpgrade.toc`, interface 16001. Addon/source
  manifests, licenses, Lua 5.1 syntax, checksums and exact tagged Git bytes are
  verified before upload. Source ZIP and receipts are separate GitHub assets;
  CurseForge receives the addon ZIP.
- The only supported release client is official Forever **1.60.1**, interface
  **16001**. The uploader resolves exactly one version named 1.60.1 with game
  version type **88568**, and uploads its concrete returned version ID. It
  rejects missing/duplicate/wrong-flavor responses and never falls back to a
  different patch. The mapping and WoW version endpoint are source-backed by
  [pinned BigWigs packager](https://github.com/BigWigsMods/packager/blob/e50a250f8705041e40f2fa1ddcb280a686d65aa0/release.sh#L2656-L2693).
- Header authentication, multipart metadata/file fields, release type and
  accepted file ID agree with the current [CurseForge Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api),
  checked 2026-10-16. No authenticated live version lookup or upload was made.
  Secret validity, API access, moderation and public visibility remain unknown.
- Existing append-only upload intent and acceptance receipts prevent an uncertain
  upload retry from silently creating duplicate files. No upload helper was run
  against a live project.

The full verifier and independent readiness review cover code and mocked
publication behavior. Main CI, exact-commit installation and preservation hashes
are recorded in the final delivery receipts. Native rendering/input and
combat/taint checks remain pending; installation does not establish them.
