# Python tooling review

Independent review of the 0.1.14 working changes against `ab4347ad`, performed
2026-10-16. Scope: Python tools and tests, locked uv dependencies, source and
sync staging, verification evidence, and check/release workflows. Read the
current AGENTS instructions and the installed WoW addon development skill's
packaging and validation references. No production changes were made by the
reviewer.

## Result

No blocking defect found in the reviewed changes. The large Python diff is
primarily Ruff formatting and import/UTC modernization. An AST comparison
separated those edits from changes in behavior. The catalog parsers,
classification rules, generators, recovery logic and source receipts retain
their previous behavior; the two assignment lambdas became equivalent local
functions. All **24 tracked files under `data/` and `FindAnUpgrade/Data/` remain
byte-identical** to the baseline.

The intentional behavior changes are confined to:

- Removing explicit `.work/pydeps` injection so locked dependencies own imports.
- Adding Ruff lint/format checks and a separate behavioral verifier test suite.
  The verifier runs children with the active interpreter, stops on a failed
  child, preserves diagnostics, and records the Python version and failure.
- Including `pyproject.toml`, `uv.lock` and `.python-version` in source packages
  and staged catalog candidates, without copying the private environment.
- Moving optional renderer execution behind `main` guards and providing hover
  renderer arguments; both remain useful documented development utilities.
- Selecting the same pinned uv/Python toolchain in validation and publishing
  jobs. The dependency lock and exact build constraints remain checked in.

## Independent execution

Executed through locked uv with the private CPython **3.15.0 x86** environment:

- Verifier evidence/failure suite: **3 tests passed**, including real child
  execution, stopping before a later write, and preserving source whitespace.
- Catalog sync suite: **24 tests passed**, including staged dependency metadata,
  cache trust, exact ownership and rollback behavior.
- Release suite: **33 tests passed**; publishing operations were mocked.
- Ruff lint and format checks passed for **37 Python files**.

Additional private probes checked that an unmodified metadata copy passes
`uv lock --check --offline`, changing the Ruff pin makes that check fail, and a
fresh source/staging copy retains all three uv metadata files while excluding a
sentinel under `.work/venv`. A child launched from that staged copy imports Lupa
from the locked parent environment and reports **Lua 5.1**. Direct imports of
both Lupa and Ruff resolve under `.work/venv`, rather than the retained legacy
wheels. Probe receipt: `.work/tooling-review-probe.json`.

## Release boundary

The workflow still permits publication only for `v*` tag pushes or explicit
manual dispatch. Validation is restricted to `elithrar/FindAnUpgrade`, has
`contents: read`, and receives no CurseForge secret. Only the dependent publish
job has `contents: write`; checkout credentials are not persisted. Publication
scripts retain the annotated tag/main ancestry, unchanged tag object, exact
archive, Git blob, receipt and idempotent upload checks. CurseForge receives
`secrets.CF_API_KEY` and `vars.CF_PROJECT_ID` only in its upload step. The game
version selector still requires exact Forever `1.60.1`, type `88568`, and rejects
ambiguous or different flavors.

This review neither read secret values nor triggered a publication. Ubuntu's
Python 3.15 source build of Lupa and the complete changed workflow still require
the new CI run. The reviewer did not repeat the root's complete verifier or
observe native game rendering, input, installation, or taint behavior.

## Reviewed file identities

SHA-256 over canonical LF bytes, suitable for comparison with Git blobs:

| File | SHA-256 |
| --- | --- |
| `pyproject.toml` | `6c794f82760b39f65120831caacbe6f591b9cf571443c0e8f5d288dd5641ec5d` |
| `uv.lock` | `00d42b94934e4fc33fa5773bcfeae9b7034302eeb87cd439daa1813b6bdc4f80` |
| `.python-version` | `8effb955f195345405c0cf4d0fb35f65165b59f444ad1a5fd9ff1ca9194fde29` |
| `.github/workflows/check.yml` | `7b24df5838b9ef0b6fc4ffc40d7ddd3b7ab96de15044dea95f6bf52f9450b88a` |
| `.github/workflows/release.yml` | `9a137d4fd66fbb7f1f9c0a4e99246c4c3c0eaba9c23983af20048a949b980a61` |
| `tools/verify.py` | `bf23e7675dd08a641efeed2b7c368d4394eae7d61b4908210bc497c0aaab8818` |
| `tools/sync_catalog.py` | `cc0ed4c1a43750ba279b2132ca993e15105f5836726c30eedf3133e4283bc2a4` |
| `tools/package.py` | `41052cbb1e4ccf2d68ec3a9ad42c59db3a756a57a60c3b496787e972def40f7f` |
| `tools/release.py` | `9f87e445c321219e8453792874b8a9f12f91ba615e58e95c9b88ad4a583b3c8e` |
| `tools/publish_curseforge.py` | `9a4e048025d8bcbf679be9628539813680963849b8d25d7a69a1b00be7d24a5e` |
| `tools/publish_github.py` | `0f3125440c27672c7cc9c18df5400b6d1fd2b6213487945af691e298223f4f6e` |
| `tests/run.py` | `1157dd50d287de85c16de9b2f94a733af9e7eb2147b0e93a52202d521c071497` |
| `tests/tooling_test.py` | `7167e88a5cddc651ae5fadc3e70abbd0efab2946891937367c330ffb0385ea7e` |
