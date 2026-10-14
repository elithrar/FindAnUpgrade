# Releases

Merging does not publish. The workflow publishes only after an explicitly requested annotated `vX.Y.Z` tag push or a manual **Release addon** run for an existing tag. This implementation has not been released or uploaded.

Before a release, complete the live checks in [VALIDATION.md](VALIDATION.md), align `QuestBrief/QuestBrief.toc` and `QuestBrief/Core.lua`, add `docs/releases/<version>.md`, and pass **Check addon**. The tagged commit must be reachable from `origin/main`. The first release still needs its version-specific notes and live verification. Only stable semantic versions are supported by this workflow.

After release approval, create and push an annotated matching tag. Never move a published tag; corrections need a new version. A manual run for the same tag resumes a partial upload without overwriting existing assets. A dirty or untracked checkout is rejected; every packaged source member must also match a tracked blob in the tag, including files hidden by ignore rules.

Validation runs with read-only permissions, Python 3.12 and Lupa 2.8. It checks Forever interface 16001, Lua 5.1 syntax, classifications, tests, licenses, load order and exact package/source manifests. CI checks both the pinned 70338 quest-frame source and current 70374 comparison/map source. The publish job rechecks SHA256SUMS, receipts, payload bytes and remote tag identity before using its job-scoped `GITHUB_TOKEN` with `contents: write`. Ref reads use that token through ephemeral Git configuration so private repositories work; credentials are not persisted or passed as command arguments. No PAT is required. Checkout and artifact actions are pinned. Runs for the same tag are serialized.

GitHub receives the addon ZIP, source ZIP, SHA256SUMS, package receipt and release metadata. Existing asset bytes are verified and never replaced. The package receipt describes the local build; it does not claim an upload or installation. The draft is published after the optional CurseForge step completes or explicitly reports it was skipped.

## Development before publication

Before the first CurseForge publication, subsequent user-authorized iterations
primarily use direct `main` commits and patch bumps (for example, `0.1.0` to
`0.1.3`). Complete independent review when requested, fix findings and pass
`python tools/verify.py` before committing and pushing; verify main CI afterward.
Use a reviewed PR when branch protection requires one and never bypass required
checks. An existing PR still needs applicable merge authorization. This iteration
workflow does not authorize publication, credentials, release tags or installation.
PR #2's unpublished finder candidate uses `0.1.1`; its earlier `0.2.0` build label
was replaced before merge to follow this workflow.

Merge and installation may be authorized separately from this default workflow.
An authorized installation must use the final validated package and record the
copied payload separately from pending in-game acceptance. Neither action
authorizes a release, tag, CurseForge publication or credential setup.

## CurseForge setup

Create or use the QuestBrief WoW project, then configure these in the repository's **Settings → Secrets and variables → Actions**:

| Setting | Kind | Value |
| --- | --- | --- |
| `CF_API_TOKEN` | Secret | Upload token from [CurseForge API Tokens](https://authors.curseforge.com/#/api-tokens) |
| `CF_PROJECT_ID` | Variable | QuestBrief's exact positive numeric project ID from its author-dashboard URL |

No project ID or token has been supplied. Missing either setting produces an explicit “CurseForge upload NOT attempted” summary while GitHub publication can complete. A malformed project ID, invalid token, unavailable exact game version or rejected upload fails the job. Secrets are supplied only to the upload step and are never sent through command arguments or printed.

The uploader resolves one exact `1.60.1` game-version ID with Forever type `88568`; it never substitutes another patch or flavor. The flavor mapping is verified in [BigWigs packager 2.6.1 source](https://github.com/BigWigsMods/packager/blob/e50a250f8705041e40f2fa1ddcb280a686d65aa0/release.sh#L2656-L2693). The returned game-version ID remains a runtime API lookup. It sends the same addon ZIP bytes using the documented [CurseForge Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api). Upload acceptance confirms a file ID, not moderation approval or public visibility.

Before the single upload POST, `curseforge-upload-pending.json` is appended to the GitHub release and verified. Success appends `curseforge-receipt.json`; both records are retained. A matching receipt prevents duplicate uploads. An unresolved pending record blocks a retry and draft publication: inspect the author dashboard first. If the file exists, reconcile a receipt with its actual file ID, project, checksum and game version. Remove pending intent only after confirming that no file was created. Timeouts, malformed responses and receipt-write failures are never automatically retried. Existing upload records are validated even when the token is later removed; retain `CF_PROJECT_ID` for those checks.

[GitHub platform immutable releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository#editing-a-release) can be enabled separately. Configure CurseForge before the first publication if using that setting: the draft receives all upload records before publication locks its assets. A previously locked release without a CurseForge receipt cannot record new intent and fails safely; a new version is required. Application-level checks also refuse tag moves and differing existing assets when platform immutability is disabled.

## Offline verification

```sh
python -m pip install --target .work/pydeps lupa==2.8
python tests/release_test.py
python tools/verify.py
```

Release tests use disposable local Git repositories and mocked network calls. They exercise tag ancestry, exact artifact checks, receipts, uncertain retries and missing settings without contacting GitHub or CurseForge. Adding workflows does not establish that a hosted run or real upload succeeded; both remain untested until a future authorized run.
