# FindAnUpgrade

Official WoW Forever addon, interface **16001**. This is the canonical contributor/agent guide; keep README user-facing and root/shipped README and LICENSE copies byte-identical.

## Repository

- `FindAnUpgrade/` ships exactly; its TOC owns load order and the shared namespace.
- `data/` owns normalized facts, receipts, classification authority, identity history and gap evidence.
- `fau_tools/` is repository-local Python tooling, invoked as a module; `context.py` owns shared paths/source/staging inventory. `tests/` holds Python/Lua regressions and the minimal native source fixture manifest.
- `.work/` holds ignored raw sources, environments, managed Python, caches and stages. `dist/` holds ignored packages, diffs and validation/review records.
- Keep legal attribution in [NOTICES.md](FindAnUpgrade/NOTICES.md), release notes in [CHANGELOG.md](CHANGELOG.md). Add no script wrappers, path injection, tracked generated logs or replacement docs tree.

## Setup and commands

Run from the checkout root. Use uv required by `pyproject.toml`, Python in `.python-version` and dependencies in `uv.lock`; change declarations with `uv lock`, then check again. No global installs or old `.work/pydeps` wheels.

Before the first uv command on MONOLITH, set absolute private paths in PowerShell (CI supplies equivalent environment settings):

```powershell
$env:UV_CACHE_DIR = "$PWD/.work/uv-cache"
$env:UV_PYTHON_INSTALL_DIR = "$PWD/.work/uv-python"
$env:UV_PYTHON_BIN_DIR = "$PWD/.work/uv-bin"
$env:UV_PROJECT_ENVIRONMENT = "$PWD/.work/venv"
```

Lupa supplies Lua 5.1. Python 3.15 x64 needs a compiler for Lupa 2.8; Windows without MSVC can use its ABI3 wheel with `$env:UV_PYTHON = 'cpython-3.15.0-windows-x86-none'`. Review compatibility when updating pins.

| Command | Purpose |
| --- | --- |
| `uv run --locked python -m fau_tools check` | Ruff lint/format, deterministic data, Python/Lua/package/release tests, both ZIPs |
| `uv run --locked python -m fau_tools import` | Stage/diff/check owned caches without replacing facts |
| `uv run --locked python -m fau_tools sync reparse` | Validate an offline stage, then apply owned outputs |
| `uv run --locked python -m fau_tools sync refresh` | Acquire pinned sources, stage/diff/check, then apply |
| `uv run --locked python -m fau_tools --help` | Other commands and per-command help |

## Data and imports

- Classify exact IDs **only** from `data/primary-statuses.json`, regenerated from `classification-source.json` and byte-preserved `classification-baseline.json`. Only exact-variant primary `New` maps to `verifiedNew`; never propagate title-group status or `databaseNEW`. Unknown IDs stay plain. Category selection is not all Forever quests; AreaIDs are not UiMapIDs.
- Preserve source-specific facts/hashes, accepted identities and gap evidence. Never silently drop IDs, infer missing values as zero or turn historical/unconfirmed evidence into current availability. Keep explicit empty/zero, guaranteed/choice groups, quantities, costs and published base versus native player rewards distinct.
- ATT pin: [d75383ccdbff1208b87cf4024fa425c0825a7ad6](https://github.com/ATTWoWAddon/AllTheThings/tree/d75383ccdbff1208b87cf4024fa425c0825a7ad6), Forever config **1.60.1.69893**. Preserve configuration/preprocessor/complete source contracts; reject truncated trees/unsupported pins. Never execute upstream Lua/harvesters.
- [Forever vs Classic](https://www.forevervsclassic.com/quests): parse only explicit Forever rewards/base values; exclude Classic columns, objectives, provider items and change summaries. Exact primary HTML needs URL/hash/byte receipts; conflicts abort staging.
- Supplemental pin: [QuestieDB Forever 1.0.6](https://github.com/Questie/QuestieDB/tree/36ca1ca86f6c1838de479c7c7452eb0a57d5c135). Verify archive/member/blob receipts, reciprocal typed starters, restrictions and coordinate owner/map frame. Never infer associations from parent context/titles/points; unknown restrictions fail closed and unverified chains remain nonblocking. Rebuild supplemental facts from a fresh base without that provider; retain independent primary proofs when raw caches are omitted.
- Respect robots/access rules; stop on 401/403/429, challenges, encryption or disallowed access. No restricted `/api/`/`/search` use or bypass. Preserve full BSD/XPIsland/ATT grants and scoped factual attribution; bundle no third-party implementation/database, raw pages, prose, artwork, fonts or client files.

Offline checks need no other checkout, game or credentials. Default caches are `.work/catalog-cache/{att-source,att-generated,questie,public}`; use help for overrides. Run one sync per checkout. Review `dist/catalog-sync-diff.json`, `dist/catalog-reconciliation.json` and `dist/catalog-coverage.json`; parser/authority changes need independent review. Never hand-patch generated Lua.

Missing receipts, changed bytes, incomplete membership, conflicts, failed checks or concurrent edits prevent replacement. Keep failed `.work/catalog-sync/` stages, fix the cause and rerun; never force-copy them. Apply prewrites listed owned files and rolls back failed replacements. Sync never commits, pushes, installs or publishes.

## Addon and validation

Keep Lua 5.1 and separate model/adapter/appearance/options/event owners. Preserve Blizzard scripts with secure post-hooks/additive `HookScript`; never accept/complete quests, alter protected layout/visibility or write another addon's data. Guard secret/forbidden values. Restore validated SavedVariables in `ADDON_LOADED`; never evaluate imported Lua. Reuse XPIsland/ATCF conventions, defer hidden work, bound async retries and reject stale callbacks; unsupported identities fail safely.

Current contracts: [1.60.1.70425](https://github.com/Gethe/wow-ui-source/tree/b401e0332adfbf0460d319b06d8ea29279a941f1). Baseline detail renderer: [70338](https://github.com/Gethe/wow-ui-source/tree/943764493e6b16d63ded3ab304150d1f05e58b57). `tests/native-source-fixtures.json` pins only sources exercised by optional integration tests. Test outputs identify executed/skipped cases. Before commit/push run the full check and inspect `dist/validation-evidence.json`, `dist/test-results.json` and package manifests. Preserve deterministic facts/projections.

Source/mocks/CI/install hashes do **not** establish native rendering, input, API values, CPU, combat/taint or addon coexistence. Keep live checks pending until observed with actual build/payload.

## Versioning

Use a **patch bump by default** for current non-breaking fixes, UI refinements, data updates, tooling and documentation changes. Use a **minor bump** when a substantial backward-compatible feature or behavior expansion warrants it. Continue forward from the latest published version; do not repeat the initial public-release version reset.

Every change set entering `main` (a merged PR or direct commit) must have a matching version bump and annotated `vX.Y.Z` tag on the resulting main commit. Include the aligned TOC, runtime Core, `pyproject.toml`, `uv.lock` and current CHANGELOG version before merge; verify main CI before pushing the matching tag. Never reuse or move a published tag. Reconcile an existing untagged change with a new versioned follow-up commit rather than rewriting published history.

Keep the current CHANGELOG version first; retained historical versions must be unique and strictly descending. Only the current section is published, while the full tracked file remains hash-bound. Normal CI must validate the actual checked-in changelog, not only normalized test fixtures. To recover an unchanged older tag after a tooling fix, dispatch the release workflow from reviewed `main` with that tag as input. Release tooling is pinned to the workflow commit and receives the separate tagged payload via `--root`; every existing source, archive, tag, ancestry and upload check still applies. Never dispatch unreviewed recovery tooling or edit a tagged payload to pass a check.

Pushing a `v*` tag starts [the release workflow](.github/workflows/release.yml), which can publish GitHub and CurseForge releases; dispatching it also publishes or resumes an existing tag. Obtain applicable merge, tag and release authorization before proceeding with this sequence. If authorization is missing, keep the change pending and report the blocker rather than silently leaving main unversioned or treating a tag as bookkeeping. A version/tag does not authorize installation.

## Authorization

Respect branch protection/review requirements and verify main CI. Merge, credentials, tags, publication and installation require applicable user authorization; later explicit instructions can authorize them. Cleanup grants no release/install permission.

After release approval, finish required live acceptance and checks; use an annotated matching stable `vX.Y.Z` tag reachable from `origin/main` on a clean tracked tree. Never move published tags/replace differing assets or expose secrets. CurseForge requires exact Forever **1.60.1/type 88568**. Unresolved upload-pending receipts block retries until dashboard reconciliation. Merge/build does not publish or verify API rights/moderation/public visibility.
