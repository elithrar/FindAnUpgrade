# Standalone reward catalog: client-source feasibility

Read-only investigation on MONOLITH, 2026-10-14. No game file, addon, configuration, reference tool or runtime code was changed. No private endpoint, client process, network extraction or encrypted content was accessed.

## Available current evidence

The installed product is `wow_classic_beta`, flavor `_classic_beta_`, version **1.60.1.70374**, build key **25822068f8fce8b21bc714e7e3210481**. The corresponding local `Data/config/25/82/25822068f8fce8b21bc714e7e3210481` MD5 matches the build key and identifies `ForeverBeta`. This is installed-file evidence, not running-client verification.

Under `C:/Program Files (x86)/World of Warcraft/_classic_beta_/Cache/WDB/enUS/`:

| File | Bytes | Header build | Exact ID records |
| --- | ---: | ---: | ---: |
| `questcache.wdb` | 30,304 | 70374 | 30 |
| `creaturecache.wdb` | 14,143 | 70374 | 102 |
| `gameobjectcache.wdb` | 24,169 | 70374 | 129 |
| `npccache.wdb` | 32 | 70374 | 0 |

Counts come from a bounded walk after the 24-byte header: each ID/length pair must fit entirely in the file, the zero terminator is handled, and the walk must end at the file boundary. This verifies record identity and framing only. Reward arrays, conditions and other payload fields were **not** decoded from an assumed older query-packet layout.

The 30 cached quest IDs are `7, 15, 18, 20, 33, 34, 91, 116, 122, 124, 125, 127, 161, 168, 169, 178, 180, 297, 302, 391, 2158, 3103, 91741, 91743, 92124, 95999, 96139, 96395, 98386, 98387`. Twenty-six occur in the current approved classification snapshot. Seven of those have primary `New`: 91741, 91743, 92124, 95999, 96139, 98386, 98387. Missing cached IDs are not evidence of missing quests or zero rewards.

Under `Cache/ADB/enUS/`, `DBCache.bin` is **3,036,821 bytes**, `XFTH` format/version 9, header build **70374**. `DBCache.bin22444.tmp` is **3,126,630 bytes** and has header build **70338**, so it must not be mixed into a current-build catalog. `ItemSparse22444.tmp` is 1,544,309 bytes but is a temporary cache without an independently validated current-build record map. Hotfix/table payload decoding remains to be established; filenames alone do not prove current completeness.

Useful exact hashes:

- `questcache.wdb`: `f5e5563e02e442b1d3ffa36fd0f4d4cd3dc6291dd281195e771750c9557bc424`
- `creaturecache.wdb`: `ce653169b03d7020bf43c226fd0a5756672e9389b4caefcc03e902041d9aaf6c`
- `gameobjectcache.wdb`: `18b957ba611b71039ea67a7c77083039ee5757515a6ce5b854091b1d667785e0`
- Current `DBCache.bin`: `0087cb2e42b45ca315a8bcc67eeb2f281eb821e398d8052f0f72edc5027417b8`

## Existing independent extraction tools

`C:/Users/matt/Documents/Codex/2026-10-10/task-2/tools/` contains `casc_extract.exe`, a read-only/offline CascLib build, `community-listfile.csv`, `WoWDBDefs/definitions/`, and the `wow.export` WDC/DBD reader. The narrow Node adapters are in that task's `decode_tables.cjs` and the ATCF reference's `tools/decode_tables.cjs`; the latter already checks matched layout/build, source hashes and full row counts.

The extractor source is `C:/Users/matt/Documents/Codex/2026-10-10/task-2/importer/azeroth-windows-handoff/scripts/casc_extract.cpp`. Its current executable is hard-pinned to **70338**, build key `f6e309c700cea095978aeb5d85210df4`. It must be adapted in this workspace before using it for 70374. Do not relabel an old-build extraction. The inspected CascLib patch hard-disables writes, online storage, HTTP/sockets and key loading, and `CascReadFile.cpp` explicitly rejects every encrypted BLTE frame. Preserve those boundaries and exclude encrypted WDC sections rather than filling them with invented or zero records.

The prior tool hashes are `73071f4089de9bc076ce825edf5b8e35154f3b64cfe79e0206221f0d4ddd7736` for `casc_extract.exe` and `9550c5d40606ec79ed43ab3762a4da4132be30ed9ba34572569b4e39e748c840` for `community-listfile.csv`. The installed definitions have matching **70338** blocks; no inspected candidate has an explicit **70374** block. Current table layout hashes and compatible definitions need verification before semantic extraction.

## Candidate tables and semantic limits

File IDs below are resolved from the existing community listfile. They are discovery candidates; this pass did not extract them from current CASC storage or claim readable/full current-table coverage.

| Table / FileDataID | Known baseline fields | What it does not establish by itself |
| --- | --- | --- |
| `QuestV2` / 1139443 | ID, unique bit, UI theme | Quest title, rewards or starters. |
| `QuestV2CliTask` / 1028735 | Title; class/race, quest, reputation and skill filters; condition/content-tuning IDs | All ordinary quests, precise playable eligibility or guaranteed/choice rewards. Opaque conditions remain unknown. |
| `QuestPackageItem` / 801743 | Package ID, item ID, quantity, display type | Quest-to-package link, or native guaranteed/choice meaning without verified mapping. |
| `QuestXP` / 1139378 | Ten difficulty values per row | Quest-to-difficulty/level link or player-scaled reward XP. |
| `QuestMoneyReward` / 1139047 | Ten difficulty values per row | Per-quest money without the query's index/multiplier/context. |
| `QuestFactionReward` / 1282622 | Ten difficulty values per row | Per-quest faction ID, index, multiplier or final reputation amount. |
| `QuestPOIBlob` / 1251882; `QuestPOIPoint` / 1251883 | Quest/objective IDs, map identifiers, conditions, XYZ points | Quest-starter NPC identity or spawn coordinates. Objective POIs cannot be converted into giver locations. |
| `QuestObjective` / 1251960; `QuestHub` / 5905413 | Objective/hub candidates | Current offer state or arbitrary NPC-to-quest association. |
| `Item` / 841626; `ItemSparse` / 1572924 | Item templates and localized properties | Reverse quest-reward associations without independent quest records. |
| `Creature` / 841631; `CreatureDifficulty` / 879282 | Creature/template properties | Quest starters or actual NPC spawn coordinates. |
| `GameObjects` / 841620 | Names, positions, owner/phase/type and properties | A verified quest-starting object relationship from position alone. |
| `Faction` / 1361972; `PlayerCondition` / 1045411 | Supporting labels/conditions | Full quest reputation/eligibility semantics without verified relationships. |
| `RewardPack` / 1307156; `RewardPackXItem` / 1307155 | Reward-pack candidates | Association with a particular ordinary quest. |

## Existing quests project

`C:/Users/matt/Documents/Codex/2026-10-13/task-4/quests/provenance/` retains original, expanded and confirmed classification snapshots plus exact-ID metadata/source audits. The JSON schemas were recursively inspected for reward, XP, money, reputation, currency, item, NPC, starter and coordinate fields. The classification snapshots have **no structured reward/NPC/coordinate catalog**. Their title/status/level/faction/zone evidence can seed identity and provenance within its approved scope, but text such as “3 reward items” cannot establish item IDs, grouping, counts or amounts. Classification continues to come only from this repository's approved `data/primary-statuses.json`.

## Concrete next step and blocker

A standalone owned database is feasible as a generated, versioned factual catalog; Questie need not be its runtime dependency. Current local caches provide only 30 quest payloads and cannot establish a complete reward finder. The current-build cache reward layout, available plaintext quest/condition tables, and an independent source for ordinary quest reward associations/starters still need verification. Curve/package/objective tables must not be joined using guessed relationships.

Reuse the offline reader in a workspace-local current-build adaptation, hash every raw input and definition, reject unknown/partial records, and preserve per-field availability/provenance. Keep raw client files and third-party tooling outside shipped archives. Bundle only the deliberately generated fact catalog; retain third-party tool notices where applicable and do not claim BSD rights in raw game content. Source/mocks do not establish current quest availability or native correctness.
