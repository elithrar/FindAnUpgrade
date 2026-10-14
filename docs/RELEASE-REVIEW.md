# Independent release workflow review

Reviewed `.github/workflows/check.yml`, `.github/workflows/release.yml`,
`tools/release.py`, `tools/publish_github.py`, `tools/publish_curseforge.py`,
`tests/release_test.py`, `tools/verify.py` integration and `docs/RELEASING.md`.
The reviewer changed no workflow or publishing helper. The release agent fixed
findings and the reviewer reran independent counterexamples. No hosted workflow,
tag push, release creation, credential operation or real upload was performed.

## Findings and resolution

1. **Private repository ref reads lacked authentication.** Checkout opted out of
   persisted credentials, but subsequent raw `git fetch` commands had no token.
   Ref refresh now receives the job-scoped GitHub token and passes authentication
   only through a copied Git subprocess environment. It does not persist a token,
   place it in command arguments or copy credential-bearing diagnostics to logs.
   This follows the pinned [checkout credential contract](https://github.com/actions/checkout/blob/3d3c42e5aac5ba805825da76410c181273ba90b1/README.md).

2. **Moved remote tags escaped local-ref validation.** The initial gate inspected
   cached tag refs. The helper now refreshes remote main and the exact tag before
   publication side effects, compares the annotated tag object and peeled commit,
   and confirms ancestry, checkout HEAD and source bytes. A changed annotation on
   the same commit and a move to another commit both fail the regression.

3. **Artifacts could contain code absent from the tag.** A dirty Core.lua could be
   packaged and its checksums regenerated while HEAD still matched an annotated
   tag. Porcelain cleanliness now rejects modified/untracked source. That alone
   missed ignored files such as `docs/.work/untracked-fixture.env`: the package
   walker included them while Git reported a clean tree. The added tagged-blob
   check now requires every packaged source member to be a tracked regular Git
   blob with exactly matching bytes. Both counterexamples now fail closed.

4. **Unexpected release assets were accepted.** Existing GitHub releases could
   carry an extra unverified ZIP or executable alongside the checked files. The
   verifier now allows only the exact five base assets and the two explicit
   CurseForge pending/receipt records. Unknown or duplicate names fail validation.

5. **A receipt filename could bypass unresolved upload state.** Removing the
   CurseForge settings caused the upload step to skip; finalization previously
   trusted the presence of any receipt. A malformed or foreign receipt could then
   publish a draft with an unresolved upload. Finalization now validates record
   contents independently of token availability, including project, tag, commit,
   ZIP hash, flavor/version, file ID, version ID and matching pending intent. Its
   workflow step receives CF_PROJECT_ID. Missing project context or unresolved
   intent blocks publication.

6. **Release tests failed on a normal release preparation.** The artifact fixture
   assumed there were no real release-note directories and that the repository
   version stayed 0.1.0. Required real notes or a future 0.2.0 version would fail
   the suite. The fixture now normalizes only its disposable copy to a fixed test
   version and creates its notes with an existing-directory-safe operation. A
   regression includes a 0.2.0 source and existing real note directory.

Release regressions are included in `tools/verify.py`, so both CI and release
validation execute them. All findings above are resolved in the reviewed files.

## Publication and API checks

- Merging and branch pushes do not invoke publication. The release workflow uses
  stable annotated vX.Y.Z tags or an explicit manual run for an existing tag.
  Version and interface checks reject mismatches and other client flavors.
- Validation has contents:read permission. Only the publish job has
  contents:write. CurseForge's token is limited to its upload step. The workflow
  avoids pull_request_target and serializes runs for the same tag without
  cancelling an active upload. Actions are pinned to exact commit hashes.
- The pinned [download action](https://github.com/actions/download-artifact/blob/3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c/action.yml)
  supports digest-mismatch:error. The downloaded ZIPs are also checked against
  exact checksum names, archive members, source bytes, package receipt and release
  asset hashes. Existing release asset bytes are downloaded and verified before
  reuse; uploads do not overwrite assets.
- Forever **88568 is a game-version type**, not the concrete uploaded version ID.
  The pinned [BigWigs packager source](https://github.com/BigWigsMods/packager/blob/e50a250f8705041e40f2fa1ddcb280a686d65aa0/release.sh#L2656-L2693)
  establishes the WoW version endpoint and type mapping. The uploader resolves
  exactly one 1.60.1 row of that type, then sends the row's distinct numeric id in
  gameVersions. Missing, duplicate, malformed or wrong-flavor rows fail closed.
- The multipart body preserves the verified addon ZIP bytes. Header-based token
  authentication, upload fields, releaseType and successful file-ID response
  match the [CurseForge Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api).
  Error handling does not print token-bearing headers or response bodies and
  refuses redirects. No upload POST is automatically retried.
- A confirmed append-only pending record precedes the single CurseForge POST.
  A matching accepted-upload receipt permits a resume without duplicating the
  upload. Timeouts, malformed responses and unconfirmed receipt writes leave the
  pending record for manual reconciliation. Acceptance is explicitly distinct
  from moderation approval and public visibility.
- GitHub platform release immutability is documented as an optional repository
  setting. Application checks are revalidation guards; they do not establish that
  platform immutability is enabled or prevent unrelated administrators changing
  mutable assets outside this workflow.

## Evidence and remaining checks

`python tests/release_test.py` passed 30 offline regression tests after the fixes.
They use disposable Git repositories and mocked publication/network calls.
The remote-ref regression uses real Git objects, refs, annotation and ancestry
checks with simulated transport; it does not establish private hosted fetches.

The reviewer's `.work/reviewer/release_probes.py` independently reproduced dirty
tagged source, ignored untracked payload, unexpected GitHub assets and a malformed
receipt with missing settings. All four counterexamples now fail closed. The
probes remain excluded from shipped and source release archives.

No remaining concrete defect was identified in the revised release paths.
Hosted Actions execution, real private-repository authentication, live CurseForge
version lookup, upload acceptance, GitHub release publication and moderation are
untested. CF_API_TOKEN and CF_PROJECT_ID have not been supplied for an actual
upload. First publication also needs approved live-client checks, committed
version-specific notes and an explicit approved tag or manual release request.
