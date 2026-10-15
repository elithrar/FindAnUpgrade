# FindAnUpgrade rename and migration review

Independent read-only production review for the `0.1.7` QuestBrief to `0.1.8`
FindAnUpgrade iteration. Production fixes were made by the implementation owner;
this review owns only its evidence under `.work/rename-review/` and this record.
No actual client installation, user settings write, tag or publication occurred
in these probes.

## Findings fixed and independently checked

1. Source packaging now includes `plan.md`, but the initial standalone sync
   staging inventory omitted it. A staged reparse would fail packaging after
   otherwise successful validation. The root staging inventory now copies it;
   the independent stage probe checks its exact bytes and the absence of the
   legacy shipped folder.
2. The initial data-only migration grammar accepted non-finite numbers,
   malformed quoted strings, unclosed long comments and reserved bare keys.
   Further compile-only comparison found Lua 5.1 rejects unary `+` numeric
   literals, Unicode digits and several whitespace characters that Python's
   broad character classes accepted. The parser now uses finite decimal
   literals, ASCII lexical classes, supported quoted escapes and explicit
   structure/depth/value bounds. No saved input is evaluated.
3. An interrupted target write initially left a partial new settings file.
   Cleanup now removes only the newly created file with the captured identity.
   An injected partial write independently confirms old bytes remain intact and
   no incomplete new file survives.
4. The installer initially omitted a final hash comparison for created settings
   and reported an unmeasured zero running-client count. It now rechecks every
   created settings file and measures the final process count. A client that
   starts after completed mutations is reported without being closed or falsely
   described as absent. Changed new settings are preserved during rollback.
5. The migration helper originally allocated the complete source before checking
   its size. File reads are now bounded before data validation, including
   preflight mode.

## Runtime and source probes

`probe.py`: **15/15 checks passed** on the reviewed integration state:

- Valid legacy choices, explicit false fields and modifier/scale values migrate
  without mutating the original legacy table.
- Existing FindAnUpgrade settings take priority over contradictory old data.
- Future schemas, whether current or legacy, retain their original table and
  nested values; runtime editing/default reset remains read-only.
- Repeated initialization cannot reapply old choices over newer edits.
- Only `/fau` and `/findanupgrade` public commands register. Legacy public
  command handlers are absent.
- Malformed data is rejected; partial writes are cleaned up.
- Staged source inventory includes the plan and the renamed payload, with no
  `QuestBrief/` payload. Runtime/TOC version metadata agrees.

`lexical_probe.py`: **46 synthetic chunks compared**, with **zero invalid Lua
chunks accepted** after fixes. Synthetic strings were compiled with Lua 5.1 to
check grammar and were never executed. Conservative rejection of unsupported
valid Lua syntax is intentional; this tool accepts bounded saved data, not
general Lua. Production migration tests also passed their four test methods.

## Installer execution against fake directories

`installer_probe.py`: **12/12 scenarios passed**. It copied an immutable
installer/helper snapshot into isolated fake workspaces and used inert fake
client payloads. Process/version observations and deliberate failure points were
mocked; all file operations were confined to those explicit fake directories.
The actual game directory and settings were never touched.

Success confirms a verified old payload moves to the owned backup, only the new
payload remains active, old settings remain byte-identical, new settings are an
exact copy, and unrelated addon/settings bytes remain unchanged. A simulated
late client launch is recorded as one running process, without a forced client
action.

Preflight rejects an already running client, existing new settings/payload,
changed old payload, disabled addon entry, malformed settings or changed archive.
Injected copy failure and installed-byte corruption restore the old payload and
remove only unchanged newly created settings. An externally changed migrated
file causes failure and survives rollback; its unexpected contents are not
overwritten or deleted.

Installer snapshot SHA-256:
`f3279c433b59fd4ba4f28f8a19093260f4c431bd2e7cf70aad292498f31b40a1`.
Helper snapshot SHA-256:
`c82c0fe7c960dcfc93c2bd9f6d9105862fc02dee610ff76a012a509065a23fe4`.
Machine-readable outcomes are `results.json`, `lexical-results.json` and
`installer-results.json` in `.work/rename-review/`.

## Package and repository boundary review

The additional `package_boundary_probe.py` pass completed **6/6 checks** after
Character and Ranking were integrated. `package.validate()` independently
returned `0.1.8`. The TOC, mock loader and package share the exact 21-module load
order: Character follows Adapter and precedes UI; Ranking follows Catalog and
precedes SearchModel. The exact shipped inventory is 27 files.

Current runtime/TOC, root and shipped README, release notes, installer metadata
and release asset names agree on FindAnUpgrade `0.1.8`. The only legacy runtime
identity is the explicitly declared, read-only `QuestBriefDB` migration seed.
Public commands are only `/fau` and `/findanupgrade`. The former payload folder
is absent from the source inventory. The source inventory includes the plan,
installer/migration tools and public receipts, while excluding actual saved
settings, `WTF`, `.work`, dependencies, references, build outputs and Git data.

The source archive now carries public metadata receipts at
[`sidebar-native-contract-receipts.json`](sidebar-native-contract-receipts.json)
and [`ranking-native-contract-receipts.json`](ranking-native-contract-receipts.json).
The independent pass compared all 14 sidebar and 24 ranking raw source files
with the exact pinned Git blob IDs, byte lengths and SHA-256 values. Four
installed constructor hashes identify reference code only; they contain no
account, character or SavedVariables content. Raw source caches and private
execution results remain outside the source inventory.

The root's current GitHub API observation still identifies
`elithrar/QuestBrief` as canonical. README links, the release workflow gate and
publisher guard consistently retain it. No repository rename or publication was
performed. Changing the product name alone must not change that external
identity without an observed user rename.

## Final archive pass

The rename/package boundary is **accepted** on the frozen candidate. The final
independent archive probe built both archives twice with identical bytes, checked
all 27 addon members and all 177 source members against their source bytes, then
extracted the source archive into an isolated directory. Running that extracted
source's own package tool reproduced both identical archives without another
project checkout or any raw source cache. Lupa was supplied as the documented
external Python dependency. Public receipt files are included verbatim; no old
payload, actual saved settings, private cache, dependency directory or Git data
is included.

TOC/mock/package load order, version `0.1.8`, both public commands, root/shipped
README equality and metadata boundaries passed again. Source hashes were stable
before and after the complete archive check. Machine-readable final candidate
archive hashes and all source hashes are in
`.work/rename-review/final-archive-results.json`.

Frozen runtime SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `Search.lua` | `519eedec7cb801a97d2c68b9a1d11413cd2624465987bf98ea39cc349787ae15` |
| `Ranking.lua` | `839e4a72fe799db08bcb0ec30564fb242ec140ae46261c7eec55d10fa006327f` |
| `Character.lua` | `de02774f17b75214d4cd739bcab246471b37ed94999ee0e32235a0099d44914b` |
| `Core.lua` | `9fefaa97609fd74d21b56ef0fd11ff383f7e76df46c169cd153c31027a486137` |

## Completion boundary

Package/release tests have passed in the implementation owner's full checks;
this independent pass also verified the final archive and identity boundaries
above. This acceptance does not replace the final full verifier, exact-commit
build, CI or installation receipt, and does not establish visual or ranking
acceptance beyond this review's scope. Historical evidence/source filenames
retain their original names. Repository URLs must follow the observed canonical
repository if the user renames it later.

The installer must stop before mutation while the client has unsaved in-memory
settings, rather than infer them from disk. It does not force logout, reload or
closure. Source and offline probes do not establish live SavedVariables engine
timing, native appearance, physical input or combat/taint safety.
