# Release readiness review

Independent source and offline review on 2026-10-16 of the unpublished 0.1.13 candidate's repository-rename and CurseForge setting contract. Read the applicable AGENTS.md and current installed wow-addon-development packaging guidance. This review changed only this report; the earlier UI spacing review is unchanged.

## Result

No unresolved P1 or P2 finding was identified in the reviewed change. The active release repository guard, publishing allowlist, workflow setting name and uploader setting reader now agree on `elithrar/FindAnUpgrade` and `CF_API_KEY`. This establishes source consistency and tested offline behavior, not successful hosted publication or CurseForge authentication.

CurseForge publication is still blocked by the missing `CF_PROJECT_ID` repository variable reported by the delivery worker's read-only metadata audit. That audit reports the `CF_API_KEY` secret name exists; neither its value, validity, project ownership nor upload permission was read or tested by this review. Use the exact existing FindAnUpgrade numeric project ID when completing setup; no ID was inferred. No tag, release, upload, setting or credential was created or changed by this review.

## Inspected behavior

- `.github/workflows/release.yml` triggers on `v*` tag pushes or an explicit manual dispatch for an existing tag. It has no branch-push or pull-request event, so merging PR #4 alone does not start this release workflow. The renamed repository guard skips validation outside `elithrar/FindAnUpgrade`; the publish job requires successful validation. Both GitHub publication entry points independently enforce the same repository allowlist.
- Validation has workflow-level `contents: read`. Only the dependent publish job requests `contents: write`, for draft creation, asset upload and final publication. Checkout credentials are not persisted, actions remain pinned to full commit SHAs, and the CurseForge secret is exposed only to its upload step. The variable is also passed to finalization so retained upload records can be checked without exposing the secret again.
- `CF_API_KEY` is the GitHub secret/environment contract; the HTTP API header remains `X-Api-Token`. The obsolete `CF_API_TOKEN` environment name is not accepted by the settings reader. The change does not migrate or reset addon SavedVariables.
- Missing either CurseForge setting returns an explicit skipped-upload summary before network or GitHub calls. A supplied project ID must be a canonical positive decimal integer. CurseForge is optional in this existing workflow: on a future authorized release run, a settings skip can still allow the GitHub draft to publish unless an unresolved upload intent blocks it. Documentation states that behavior.
- Release metadata still requires a stable annotated matching version tag, interface 16001, a clean exact tagged checkout and origin/main ancestry. The package/source assets, release notes and checksums are verified; remote tag identity is rechecked before publication side effects. Existing differing assets are rejected rather than overwritten.
- CurseForge version selection still requires exactly one positive version ID whose name is `1.60.1` and whose `gameVersionTypeID` is `88568`; wrong patches/flavors, ambiguous responses and invalid IDs fail closed. Upload intent is recorded and verified before the single upload POST. A matching receipt prevents duplication, and unresolved intent blocks automatic retry and final draft publication. Upload acceptance is explicitly separate from moderation or public visibility.

## Checks performed

`python tests/release_test.py -v` passed all 33 tests in a fresh process. The suite uses disposable local Git repositories and mocked publishing/network operations; no real publishing command is invoked. It covers the renamed allowlist and supplied-secret contract, unchanged tag/manual trigger scope, least job permissions, exact Forever selection, artifact integrity, tag identity/ancestry, missing settings, upload intent/receipt recovery and duplicate prevention.

Additional independent lightweight probes passed: an isolated dummy `CF_API_KEY` with missing project ID made zero CurseForge or GitHub calls; only the renamed exact repository passed the allowlist; metadata retained 1.60.1/type88568; wrong-flavor and wrong-patch version rows were rejected and the sole exact row was accepted. `git diff --check` passed after the reviewed edits.

## Remaining readiness limits

Set and verify the exact existing `CF_PROJECT_ID` only under the user's applicable setup authorization. A future authorized hosted release must confirm the actual CurseForge versions response includes one matching current entry, the supplied token can upload to that project, and the accepted file ID corresponds to the exact addon archive. No live API response, token validation, hosted release job, real upload, moderation outcome or public visibility was observed in this review. The game-side live checks recorded in VALIDATION.md also remain separate from release tooling checks. Approval to merge/install this candidate does not authorize publication.

## Reviewed file identity

SHA-256 below uses file bytes with CRLF normalized to LF, matching repository normalization. `tools/release.py` was inspected as an unchanged dependency of the new contract. Changes after this review require checking the affected conclusions again.

| File | SHA-256 (LF) |
| --- | --- |
| `.github/workflows/release.yml` | `4b06c5950871889bb3e8d103679e1994de5ba3e934867159543d72f462f1d395` |
| `tools/publish_github.py` | `4da76592fd001296dbaf81953aac9ae14966c68a429b7cbeb507691117e1e516` |
| `tools/publish_curseforge.py` | `d45b01a159b0860dec035e3330e8903ba4d71814511082a01ac9f5d837128936` |
| `tools/release.py` | `b3eb92974dfb37f7038642a7d3b7de964d4ecae7fc0a3a357a4e3457c60b909f` |
| `tests/release_test.py` | `82f2eeac428c7b4caffa4a45dc08a7a48d8ac443f331c91de2cf53f97bf66528` |
