# Catalog acquisition and sync

Run these commands from a FindAnUpgrade source checkout after the locked uv
setup in [DEVELOPMENT.md](DEVELOPMENT.md). No website checkout, game installation,
credentials or upstream Lua execution is required.

```powershell
uv sync --locked
uv run --locked python tools/sync_catalog.py check
```

`check` works offline from tracked normalized inputs. It reproduces the data,
runs all required tests and builds both archives in `dist/`. Optional pinned
Blizzard fixtures add source integration tests when present; the receipt says
which ran. Neither mocks nor inspected source establish in-game behavior.

## Refresh and reuse

```powershell
uv run --locked python tools/sync_catalog.py refresh
```

This acquires the pinned QuestieDB Forever artifact and ATT authoring and compiled files, refreshes the whole
public index, revalidates changed or expired details, and checks historical
candidate URLs absent from the index. It then imports into a unique staging
directory, generates the catalog, writes `dist/catalog-sync-diff.json` and runs
the full verifier there. Only a passing candidate replaces the explicitly
listed owned catalog files. Review the exact IDs/fields and cause counts before
committing. The command never commits, pushes, installs, tags or publishes.

The default cache is `.work/catalog-cache/`: `att-source/`, `att-generated/`,
`questie/` and `public/`. Index/detail manifests and per-page `.receipts/` bind URL, bytes,
SHA-256, check time and HTTP validators when supplied. ATT `ACQUISITION.json`
also binds each Git blob. Warm details are reused for at most 24 hours without
extending their check time. Changed index rows remain pending across interrupted
runs until detail collection succeeds. Unreceipted files are fetched again;
receipt mismatches fail instead of trusting altered bytes.

```powershell
uv run --locked python tools/sync_catalog.py refresh --refresh-details
uv run --locked python tools/sync_catalog.py refresh --max-age-hours 6
```

The first forces detail revalidation, including changes not visible in index
rows. Expiry is the fallback for those changes on ordinary incremental runs.
ETag/Last-Modified validators permit 304 reuse only with a verified cached body.
A cold full acquisition is substantially slower than a warm refresh. There is
no fixed record cap: counts, page coverage, exact membership and duplicate
dispositions must reconcile. Ordinary visible name filters repair pagination
ties; an unresolved count or changed row during collection stops the refresh.

To reparse existing owned caches without network:

```powershell
uv run --locked python tools/sync_catalog.py reparse
```

For caches acquired before this default layout, provide their paths explicitly:

```powershell
uv run --locked python tools/sync_catalog.py reparse --public-root .work/comprehensive-source --authoring-root .work/att-source --compiled-root .work/att-generated
```

The same three overrides work with `refresh`. Optional `--questie-root PATH`
selects the pinned numeric metadata cache. A reparse without that cache retains
the owned normalized supplemental input; a refresh acquires it. Optional `--primary-cache PATH`
reads retained exact primary HTML only; it makes no new primary-site requests.
Optional `--client-cache PATH` reads a 70374 WDB cache only to validate identities
and framing. Omit both to retain the tracked normalized evidence. Neither is
required for standalone refresh, and the WDB payload is not decoded as rewards.
Previously attached exact primary coordinates retain their URL/hash and mapping
proof when the raw primary cache is omitted. Supplemental facts are regenerated
against a fresh base without that provider, so they survive repeated imports.

## Source contracts and ownership

- ATT is pinned to `d75383ccdbff1208b87cf4024fa425c0825a7ad6`, source config
  `1.60.1.69893`, with its complete MIT notice retained. The acquirer rejects a
  different revision until the parser/build contracts and pin are reviewed.
  Recursive API trees marked truncated are rejected. Every Forever authoring
  Lua file, required helper/config and XML-loaded compiled category is acquired.
- Forever vs Classic ordinary `/quests` pages supply explicitly labelled
  Forever rewards and base values. Classic columns, objectives, provider items
  and change summaries do not become rewards. Robots policy is checked on each
  collection. `/api/` and `/search` are not used; 401/403/429 or a challenge stop
  acquisition. No workaround, credential or encrypted-data bypass is attempted.
- Retained primary pages challenge matching exact item groups and quantities.
  A primary/public conflict stops staging. Different metadata fields are
  diagnosed separately; conflicting eligibility is suppressed. A changed
  snapshot does not inherit a claim of fresh primary verification.
- Exact authored/compiled starters and `qs`/`qss` starting items are separate
  namespaces. Resolver branches preserve faction qualifiers. Direct coordinates
  require an unambiguous owner. A global NPC position can enrich an already
  proven starter, never create a new quest association. Parent context,
  objectives and item acquisition locations are insufficient starter proof.
  The 0.1.6 coordinate layer retains the frozen 106-case mixed-starter scope
  inside hashed metadata. It recovers only immutable coordinate aliases with
  explicit singleton NPC ownership and exact target references. Reviewed
  `appendGroups` compositions require fresh destinations. Mutations, escapes,
  helper rebinding, contradictory owners and list-order/point-equality guesses
  fail closed. The reconciliation report retains all scope IDs, expressions,
  anchor lines and dispositions, including the 104 still-unassigned cases.
- Classification remains exclusively `data/primary-statuses.json`.
  `classification-source.json` and the byte-preserved original baseline own the
  frozen website comparison. Staging regenerates exact statuses and categories
  from them without requiring the website checkout. A category's source AreaID
  is not a coordinate or UiMapID. See `CLASSIFICATION-RECONCILIATION.md`.
- Supplemental typed starters and restrictions use QuestieDB Forever 1.0.6 at
  `36ca1ca86f6c1838de479c7c7452eb0a57d5c135`. Archive/member hashes and generated
  source Git blobs are checked. Reciprocal relationships, class/race masks,
  positive Forever points and exact primary map proofs have separate authority.
  Upstream Lua is never executed. Inherited Era points and changed map frames
  are withheld. See `STARTER-COORDINATE-RECOVERY.md`.

`data/catalog-complete-sources.json` hashes normalized public, metadata,
compiled, primary, client, supplemental, legacy, identity-history and gap-evidence inputs.
`catalog-identity-history.json` preserves every previously accepted exact ID;
vanished source rows do not silently erase identities or preserve stale reward
claims. `catalog-gap-evidence.json` retains explicit unconfirmed/404/410
dispositions and limited header-context evidence. An HTTP absence is not proof
that a quest was removed from the game. Explicit placeholder labels are
diagnostic only; ordinary words such as “testing” are not a deprecated flag.

`catalog-reconciliation.json` partitions missing fields by actual cause,
including hidden triggers, unconfirmed identity, unproven parent inheritance,
unsupported expressions, missing materialized metadata, item starts without a
fixed activation point, mixed starters without owned points and absent fields.
It distinguishes the confirmed published inventory from historical/unconfirmed
candidates. The finder excludes candidates unless current native offer/log/map
evidence establishes availability; cached item data alone is insufficient.

## Failure and review

Prerequisite facts are owned by `data/catalog-chain-records.json`. The importer
uses the pinned QuestieDB Forever final artifact and matching authored
corrections, preserves per-field authority and stronger optional-link overrides,
and withholds self references. Inherited group semantics remain nonblocking.
`tools/quest_chains.py --source-root .work/starter-recovery/questie-source`
rebuilds from the owned cache. Only explicit refresh acquisition uses its
`--acquire` switch; offline reparse fails clearly if the pinned authored cache
is missing. Runtime and ordinary offline checks use frozen normalized inputs
without another addon or checkout. Classification and reward facts remain
separate. `SHORTLIST-CHAIN-CONTRACTS.md` records coverage and remaining limits.

Acquisition errors, missing receipts, changed bytes, unsupported pins,
incomplete membership, primary conflicts, failed tests or concurrent catalog
edits prevent replacement. Frozen classification and parser inputs are hashed
when staging and checked again before replacement. Staged candidates remain in `.work/catalog-sync/`
for diagnosis. Applying a validated candidate prewrites all replacements and
rolls back a failed replacement; it touches only the listed owned files.
Run one sync per checkout at a time. Raw caches, staging data, client files and
dependencies never enter source or addon ZIPs.

Review `dist/catalog-sync-diff.json`, `data/catalog-reconciliation.json` and
`data/catalog-coverage.json`; require independent review for parser or authority
changes. Fix concrete findings, bump the patch version for an authorized
iteration, and run `uv run --locked python tools/verify.py` again before commit/push. Follow
`RELEASING.md` and applicable authorization for CI and any exact-commit install.
This sync workflow itself grants no release, installation or game-action
permission. Pending native rendering, transitions and combat/taint checks stay
explicit in `VALIDATION.md`.
