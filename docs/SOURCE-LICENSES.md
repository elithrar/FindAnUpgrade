# Source licenses and redistribution boundaries

This document preserves the reviewed attribution, source selection and redistribution boundaries. Historical acquisition counts describe those snapshots; current owned facts and hashes are in `data/` and [PROVENANCE.md](PROVENANCE.md).

# Implementation and convention reuse

Originally reviewed 2026-10-14 against the local addon payload, the pinned XPIsland/AsTheCrowFlies references in [PROVENANCE.md](PROVENANCE.md), and the [OSI BSD-3-Clause text](https://opensource.org/license/bsd-3-clause).

## Findings and fixes

| Finding | Fix | Verification |
| --- | --- | --- |
| FindAnUpgrade had no original-code license. | Added root `LICENSE` and shipped `FindAnUpgrade/LICENSE`, copyright 2026 Matt Silverlock, BSD-3-Clause. | Both files must be byte-identical and contain all three conditions and the complete disclaimer. |
| The prototype notice reserved original-code rights unless separately granted, contradicting the requested BSD-3-Clause grant. | Replaced that statement with the original-code grant and an explicit third-party scope boundary. | Reviewed `FindAnUpgrade/NOTICES.md` for contradictory claims. |
| Reused font/settings patterns needed a clear attribution scope. | Named XPIsland, retained its complete `XPISLAND-LICENSE.txt`, and identified the owner-authorized ATCF conventions without claiming a license for its whole repository. | XPIsland notice text matches the reference license after newline normalization. |
| Optional fonts/providers and game assets could be mistaken for bundled BSD components. | Named runtime dependencies, stated that their code/data/assets are not bundled, and limited the classification notice to the exact-ID factual extract. | Inspected addon inventory, TOC and package allowlist; no font, media, native source, library or provider database payload present. |

## Scope and provenance

- The root license covers original FindAnUpgrade implementation, tests, tooling and documentation; the shipped copy keeps the grant with the installable addon.
- `FindAnUpgrade/XPISLAND-LICENSE.txt` preserves XPIsland's original copyright, redistribution conditions and disclaimer. XPIsland remains BSD-3-Clause. Release helpers (`fau_tools/release.py`, `fau_tools/publishing.py`, `fau_tools/publishing.py`), `tests/release_test.py` and `.github/workflows/check.yml`/`release.yml` follow its release conventions with fresh implementation; the attribution covers these conventions too.
- ATCF was supplied by the same owner for convention reuse. Its font readback/fallback behavior and native UI conventions informed FindAnUpgrade. That authorization does not establish an open-source redistribution license for ATCF; its repository, runtime payload, assets and derived flight data are excluded.
- FindAnUpgrade references Blizzard APIs/templates/textures/fonts and optionally installed Expressway, LibSharedMedia, LibStub, Questie and QuestieDB. It bundles none of their source, font, artwork or database payloads.
- The classification payload is a normalized factual ID/status extract from user-approved evidence. Its source identity/version and exact mapping remain recorded. No broader license or rights in the original evidence or game content are asserted.
- Ignored development-only references and `.work/` may contain third-party sources or Lupa. They are excluded from source/installable archives and retain their own licenses.

## Integration validation

The package allowlist must include `FindAnUpgrade/LICENSE`; the source archive must include the root `LICENSE`. Packaging should reject mismatched root/shipped licenses and missing XPIsland attribution. Rebuild and inspect both archives after those checks are integrated. This review does not authorize an upstream release or bundle additional third-party files.

Independent second review checked both license copies, the complete XPIsland license against its reference and the OSI text, the notice scope, and the actual payload inventory. It found no remaining contradictory grant or attribution defect.

After packaging integration, `uv run --locked python -m unittest discover -s tests -p package_test.py` passed all 6 tests and `uv run --locked fau build` succeeded. Archive inspection verified that both ZIPs contain `FindAnUpgrade/LICENSE`, `FindAnUpgrade/NOTICES.md` and `FindAnUpgrade/XPISLAND-LICENSE.txt` byte-for-byte; the source ZIP also contains the root `LICENSE` and provenance document. The root/shipped grant SHA-256 is `b03f4b5dbfddcbc8bbc636cc238ccc7934dc34c0c60eccc055b1265f10487e5f`. The separate reviewer repeated the integrated archive checks and found no new licensing defect. Neither archive contains ignored reference/dependency directories, font files, native artwork or compiled libraries. A final rebuild is needed after concurrent implementation changes finish.

The independent history reviewer repeated the licensing review on 2026-10-14 after runtime changes. Root/shipped grants remain byte-identical and match the pinned XPIsland BSD-3-Clause text after newline normalization; the retained XPIsland notice also matches. A Python inspection of both current ZIPs confirmed all three shipped grant/notice files against their current source bytes, the root grant in the source ZIP, and exclusion of reference/dependency directories, fonts, artwork and compiled libraries. `NOTICES.md` distinguishes original-code rights, user-authorized convention reuse, optional providers, native resources and factual classification provenance. No new contradictory grant or missing attribution was found. This review makes no broader claim about rights in unbundled third-party datasets or resources.

# Catalog source licensing

Reviewed 2026-10-14. Pinned upstream source was acquired into ignored `.work/att-source/` for read-only inspection. No runtime data, project license or installable payload was changed by this review.

The user requires FindAnUpgrade to ship its own database. The strongest permissive candidate found is a targeted numeric extract from **AllTheThings' dedicated Forever authoring data**, under its actual MIT grant, with provenance and the complete MIT notice preserved. Original FindAnUpgrade code can retain BSD-3-Clause. This is a concrete source route, not evidence of complete or live-verified reward coverage.

Do not label a bundled Questie-derived database BSD-3-Clause or assume the CurseForge GPLv3 label supplies a clear grant. Its installed packages lack a project-wide license, and the upstream licensing discussion remains unresolved. Attribution does not itself grant copying permission.

## Candidate route for the bundled database

[AllTheThings' LICENSE](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/LICENSE) grants MIT terms, copyright 2026 AllTheThings WoW Addon. The inspected commit is `d75383ccdbff1208b87cf4024fa425c0825a7ad6`; license Git blob SHA is `8c87dc3b43c3fa36652093b325fbbc0910cd57d8`.

Its [Forever configuration](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/.db/forever/.config/forever.config) selects `.contrib/.db/forever`, phase FOREVER, Camelot output and build 1.60.1.69893. The [Teldrassil authoring file](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/.db/forever/zones/kalimdor/teldrassil.lua) (Git blob `97b149b1013d43e5ca0c50fb592f6e56b0d04ab3`) contains exact quests 98046, 98065 and 98403; quest 98403 has a direct item child 282284. Its numeric quest/starter/item records are a material input for an independently generated FindAnUpgrade catalog. No Questie, VMaNGOS or narrower-license attribution was found in that inspected zone file.

Scope matters: the repository also includes Wowhead-backed harvesters and expressive lore. Do not copy the repository wholesale, run its network harvesters, copy borrowed lore, or treat raw harvest output as independently authored data. Limit an initial import to selected numeric authoring fields and review provenance per source file; use FindAnUpgrade's approved title/classification snapshot where available. Short identification labels immediately attached to exact `q`/`qg`/`i` IDs may be retained with the MIT attribution, distinct from copying full comments or expressive descriptions. Strip phase/chain/markup annotations, preserve provenance and prefer verified native names when available. Labels must never infer identities or variant classification. Runtime Questie comparison features found in ATT do not themselves prove a selected authoring record came from Questie. MIT grants rights held by its licensors, not a guarantee about every upstream game/content right.

If adopted, retain the full ATT MIT copyright/permission/disclaimer in the source and addon packages, identify the derived Data component and pinned input files in notices, and preserve original FindAnUpgrade BSD notices. MIT does not require relicensing original FindAnUpgrade implementation as MIT. No license or data file was changed by this review.

**Technical limits to verify before generation:** parser preprocessor tags, `zzOLD` exclusions, actual reward-group semantics, item children versus objectives/costs/providers, exact IDs, and build differences. Direct item children alone do not establish quantity or guaranteed versus choose-one status. A curated snapshot can be bundled while absent fields remain unknown. Measure input/output coverage; never claim all Forever quests from one inspected zone.

### Local acquisition receipt

`.work/att-source/ACQUISITION.json` records every input path, upstream URL, Git blob SHA, SHA-256 and byte count at the exact pin. GitHub's read-only file API returned base64, decoded without newline transformation; every Git blob SHA was recomputed and matched. The first 89 files comprise LICENSE/config plus 87 Lua authoring files: zones 25, dungeons/raids 20, character 11, professions 7, holidays 11, PvP 9, world events 4. Twenty supporting config/helper/class-definition files were also acquired, forming the initial **109 byte-exact inputs**. That initial subset conservatively excluded `zzOLD`; the later expansion review below establishes that it contains actual build inputs and acquires them separately. `.nyi`, `.hqt`, missing-database placeholders, assets and raw harvesters remain excluded. No ATT runtime or network harvester was executed. This ignored reference copy must not be included in FindAnUpgrade packages. ATT's full license SHA-256 is `955281b9174e0f66b08c8e83d31e0f38b2fcaa247ca3af92d1723d81a13cddfb`.

The subset still needs semantic filtering; inclusion in the local inspection copy is not approval to import every nested value. A separate reviewer is checking the exact constructor hierarchy and field contracts.

The Forever map constant file uses IDs such as TELDRASSIL 1438 and DARNASSUS 1457, and explicit new Forever IDs. That is upstream annotation, not verification of current native map identity or coordinate geometry. Its `_G` fallback must not be executed by the parser. Validate the exact namespace/geometry against current official client evidence before navigation or map placement; valid numeric IDs alone are insufficient.

Supporting source paths are `.contrib/.db/shared/constants/classIDs.lua`, `raceIDs.lua` and `lvl.lua`; `.contrib/.db/shared/functions/Shortcuts.lua`; `.contrib/.db/shared/.main.lua`; `.contrib/.db/build - forever.bat`; `.contrib/.db/standard/.config/retail/retail.config`; and `src/Classes/Quests.lua`/`base.lua`, plus Forever `.config` definitions. The build script uses retail base configuration followed by the Forever override; treating either alone as the complete input contract is incorrect.

`Shortcuts.lua` defines `q` as the quest constructor assigning `questID`, `i` as the item constructor assigning `itemID`, and `maproot` as outer-to-inner UI-map nesting. These constructors do not encode guaranteed-versus-choice or item quantity merely from an item's child position. Shared race/class arrays contain retail conditionals and Forever Skyborne race entries; resolve the configured preprocessor conditions rather than flattening all arrays. Quest prerequisites can include `sourceQuests` and `sqreq`, not simply an unconditional list. The separate schema review should determine the generator's supported subset; omitted restrictions must not become positive availability claims.

### Integrated catalog and compiled expansion review

The implementation now includes a separate MIT-derived catalog. A targeted re-review checked `fau_tools/att.py`, `fau_tools/catalog.py`, `data/catalog-source.json`, `data/catalog-sources.json`, the generated Lua header, notices and package allowlist. The root and shipped original-code BSD grants remain byte-identical. `FindAnUpgrade/Data/ATT-LICENSE.txt` is byte-identical to the pinned upstream LICENSE, with SHA-256 `955281b9174e0f66b08c8e83d31e0f38b2fcaa247ca3af92d1723d81a13cddfb`; packaging checks that exact hash and includes the full notice in both payloads. The notices identify the source pin, MIT Data component, source/target build difference and unknown quantities/choice membership. No contradictory BSD claim was found for the ATT-derived component.

For the inspected authoring-derived snapshot, every listed provenance record matched its exact acquisition metadata, every source hash matched, and every quest source line contained the recorded exact `q(ID, ...)`. The generator rejects assumed counts or guaranteed/choice groups. Retained identification labels must still exclude alternate expansion titles and phase annotations: examples in immediate comments include quest 923's `Tumors / Mossy Tumors [CATA+]` and quest 935's composite Classic/Cata title. Omit an ambiguous label rather than choose an unverified variant name. This is an identity-quality finding, not a change to the upstream license.

Additional read-only expansion evidence is in ignored `.work/att-generated/ACQUISITION.json`: 20 byte-exact files, including all 14 files under [the pinned `db/Camelot` tree](https://github.com/ATTWoWAddon/AllTheThings/tree/d75383ccdbff1208b87cf4024fa425c0825a7ad6/db/Camelot), the MIT license, build/config files, shared root configuration and Forever `ItemDB.lua` export. Every original Git blob SHA and SHA-256 was recomputed. The Camelot database XML loads 11 category files; `Zones.lua` and `Instances.lua` are the substantial quest-bearing candidates. Its category aliases explicitly map `q` to `CreateQuest`, `i` to `CreateItem`, and `g` supplies child groups. A nonexecuting semantic parser can inspect those compiled literals without recursively treating objective/vendor/drop descendants as rewards. No ATT runtime was executed, and none of this reference copy is automatically approved for distribution.

No embedded current-client build stamp was found in the acquired generated categories. The configuration at the same pin declares Forever/Camelot build 1.60.1.69893; this is source configuration evidence, not proof that the compiled files were live-tested on 1.60.1.70374. The retail base configuration is followed by the Forever override: Forever selects its own root-data and empty JSON directories. That does not establish that Standard/retail quest rows are a valid Forever overlay. Inspect actual Camelot records before expanding coverage, preserve source identity and conflicts, and keep classification solely in the approved exact-ID status extract.

The coverage investigation found a material acquisition omission, rather than evidence that the dedicated Forever authoring ends at the initial subset. Its `expansion features` category had not been acquired; `library books.lua` explicitly records quest 78145 and direct item 211779 under `TIMELINE.ADDED_1_60_1`. The same IDs occurring in SoD does not disqualify their explicit Forever record. The pinned [Parser Program.cs](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/src/Parser/Program.cs) selects all recursive `*.lua` files under the configured root-data, parsing configuration files first and then every non-configuration file. It has no `zzOLD` directory exclusion in that enumeration. All 44 Lua blobs under Forever's `zzOLD` tree and both `expansion features` files, plus Parser source as build-input evidence, were subsequently acquired and hash-verified; the authoring inspection receipt now has **156 files**. These remain read-only candidates until the generator audits preprocessors, exact quest variants, inherited restrictions and conflict handling. Their numeric/short-label reuse follows the same scoped MIT notice route as other selected ATT records; the folder name alone neither proves nor disproves current availability.

The [shared root configuration](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/.db/shared/.config/root.config) includes aliases such as `qg`/`qgs` and `sourceQuest`/`sourceQuests`, plus WAGO item merge fields. The [Forever ItemDB export](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/.db/forever/.config/exports/ItemDB.lua) is guarded by `CAMELOT` and contains numeric item class/subclass, inventory type, quality and level plus short names. It provides metadata for already-established exact item IDs, not new quest reward associations. Its `equippable=1` also appears on item 117, Tough Jerky, which has no inventory type; this flag alone must not classify an item as equipment. Preserve the authoring/export origin and game-content boundary when using such fields. ATT's MIT notice remains necessary; it is not a blanket grant for separately acquired game/Wago/Wowhead content.

Integrated package checks passed all eight package tests and a candidate rebuild. A separate ZIP inspection confirmed that both archives contain the current BSD license, XPIsland license, notices, catalog and byte-exact full ATT MIT notice; the source archive also includes the root BSD grant. Both exclude `.work/att-source`, `.work/att-generated` and other ignored references. The full verifier at this intermediate stage failed `tests/search_test.lua:151` because its fixed `>=688` production-count assertion did not reflect six recently excluded eligibility-sensitive source rows. This finding was reported to the parent implementation agent; a final full verification is needed after coverage/parser work settles. These checks do not establish live-client accuracy or authorize publication.

### Existing primary Forever evidence

The earlier quests workspace contains `C:/Users/matt/Documents/Codex/2026-10-13/task-4/quests/provenance/forever-outdoor-verified-evidence.zip`, SHA-256 `95cc5283a2b1506441cd13f4f4642475dc3587700c955d8932c6219908dfb618`. This review verified the existing file/hash and its 46-member inventory, including raw regional JSON rows, normalized data, independent validation and an evidence manifest. No archive payload was copied into the addon.

Those existing public-page observations are a material source of exact quest-ID/reward-item facts and current Forever evidence, separately from Questie. Their recorded origin should remain Wowhead observations, not MIT ATT data or independently authored upstream content. A narrowly reviewed factual extract is a different acquisition/provenance path from a new bulk scrape; it still needs explicit content/terms scope and cannot be represented as a general Wowhead redistribution grant. No new Wowhead harvest was performed. Distinguish prior evidence from newly acquired ATT fields and validate conflicts per exact variant.

## Other source acquisition findings

| Source | Actual grant / lineage evidence | Acquisition result |
| --- | --- | --- |
| [pfQuest](https://github.com/shagu/pfQuest/blob/master/LICENSE) | Actual MIT grant, copyright 2017-2021 Eric Mauser (Shagu). [Extractor setup](https://github.com/shagu/pfQuest/blob/master/toolbox/README.md) imports VMaNGOS, CMaNGOS and client DBCs; [VMaNGOS LICENSE](https://github.com/vmangos/core/blob/development/LICENSE) is GPLv2. | Public pinned `db/quests.lua`/`db/items.lua` exist, but imported data cannot be advertised as wholly permissive just from the MIT code label. Current `toolbox/extractor.lua` has no reward/choice column extraction, making it a weak reward source too. |
| [ClassicCodex](https://github.com/SwimmingTiger/ClassicCodex/blob/1846cea7c5fbbc4ef2392a059531368489c8e301/LICENSE) | Actual MIT grant to Shagu/Pgarneau. README identifies pfQuest/ShaguDB lineage. [Loader tooling](https://github.com/SwimmingTiger/ClassicCodex/blob/1846cea7c5fbbc4ef2392a059531368489c8e301/tools/lua/load-db.lua) applies Questie and Wowhead patches; locale tooling imports Questie lookups. | Its Classic database is not a clean alternative for the entire imported payload without distinguishing origins. It is not current Forever data. |
| [Wowhead tooltips](https://www.wowhead.com/tooltips) | Publicly documented website tooltip embedding. Governing [Fanbyte/ZAM terms](https://corp.fanbyte.com/legal/terms), updated May 2025, section 4 grants limited internal API/site use and restricts redistribution; section 8 restricts data mining and non-browser extraction. | Public access/embedding is not a published offline export grant. A separate permission could enable a future export route; no bulk scraper or private endpoint was used. |
| Official client observations | FindAnUpgrade already has exact-ID native reward readers; independently recorded numeric observations can feed its own canonical input and generator. | A concrete enrichment route, subject to client readiness, collection terms and measured coverage. Static client files alone do not prove a complete quest-reward dataset; the public Blizzard developer documentation could not be retrieved to establish a current Forever export endpoint. |

The [U.S. Copyright Office's Circular 33](https://www.copyright.gov/circs/circ33.pdf) distinguishes unprotected names, titles and methods from protected expression/creative arrangement. It does not establish that every fictional game database or every extraction is unrestricted across jurisdictions. Keep copied expressions and substantial source compilations distinct from independently verified numeric observations.

## Inspected packages and upstream evidence

Installed under `C:/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns`:

| Package | Recorded version / provenance | License evidence |
| --- | --- | --- |
| Questie | 12.1.0; `Questie_Camelot.toc`; interface 16001; `X-BUILD-COMMIT` `91fb7e2a457e74fe05f02570e7e45f93794d9305` | No project-wide LICENSE/COPYING/NOTICE file found. Limited icon/library licenses below. |
| QuestieDB | 1.0.6; contract 4; Forever baked artifact; `X-BUILD-COMMIT` `36ca1ca86f6c1838de479c7c7452eb0a57d5c135` | No license/notice file found anywhere in the installed package; no copyright/GPL/MIT/BSD grant found in its inspected Lua sources. |

The Questie TOC SHA-256 is `2bd4388a11fcb4f7165fc101393ebb080e489d2dfe5948cc6b3ea1a6fe86c964`; the QuestieDB Forever TOC SHA-256 is `954c5cfbd6ffb812efef338b4c9a42c964b785485b6f9ab4a458679fbb4707d0`.

[Questie's CurseForge listing](https://www.curseforge.com/wow/addons/questie/files/8975641) names GPLv3, but [upstream issue #4447](https://github.com/Questie/Questie/issues/4447) explains that the historical listing was not supported by contributor-wide consent. A maintainer's May 2024 update says the project should be treated as all rights reserved; February 2026 comments still discuss obtaining consent. The [licensing proposal #4660](https://github.com/Questie/Questie/pull/4660) is still open, proposes a contributor agreement and chiefly MIT terms, and is not a merged grant. Current public [Questie](https://github.com/Questie/Questie) and [QuestieDB](https://github.com/Questie/QuestieDB) file listings show no project-wide license. These facts prevent an unqualified claim that either inspected database is GPL-licensed or freely redistributable.

QuestieDB's [provenance at the installed commit](https://github.com/Questie/QuestieDB/blob/36ca1ca86f6c1838de479c7c7452eb0a57d5c135/PROVENANCE.md) traces raw entity tables, corrections, schema, translations and support tables to Questie, with historical migration reference `454b9d072965ee8f1a881429260fcf1fac8d60f7`. Its descriptions of owned build inputs concern maintenance and generation; they are not an explicit license or proof of permission from all original contributors. A baked or transformed table retains that provenance question.

The only installed Questie license files found were:

- `Icons/LICENSE.md`: named pfQuest-derived icons are MIT with permission; other icons have unclear licensing. [Upstream icon notice](https://github.com/Questie/Questie/blob/master/Icons/LICENSE.md).
- `Libs/LICENSE.txt`: the Ace3 Development Team's license, including its specific standalone-redistribution restriction.
- `Libs/Krowi_WorldMapButtons/LICENSE`: all rights reserved unless separately stated.

None grants rights to Questie/QuestieDB quest, NPC, item or reward tables. No icons or library implementations are needed for a compact data extract.

## If a source is confirmed GPLv3

The following is conditional, from the [FSF-authored GPLv3 text, reproduced by OSI](https://opensource.org/license/gpl-3.0):

- Sections 1–2: running a generator does not automatically license all output; its content determines coverage. Renaming, reducing, reordering or compressing copied covered material is not a permission bypass.
- Sections 4–5: keep copyright/license/warranty notices, supply the GPL, identify modifications and their date, and license a covered modified work as a whole under GPLv3. Separate independent aggregation is an exception, not established merely by different filenames.
- Sections 1 and 6: non-source distributions require corresponding source through a permitted delivery route, including the preferred modification form and necessary generation scripts. A moving upstream link alone does not establish delivery of the matching source.

**Architecture inference:** a generated Lua table loaded directly into FindAnUpgrade's namespace should not be assumed an independent aggregate. Original BSD grants can remain, but a covered combined distribution may require GPL terms. Review the selected input and resulting work; attribution and optional dependency labels give no blanket compatibility guarantee.

Direct GNU FAQ requests failed with rate limits/timeouts; this review relies on the license text rather than claiming a verified FAQ interpretation.

## Official Forever files and factual records

Blizzard-origin content is a separate rights boundary. The [official EULA search result](https://www.blizzard.com/legal/fba4d00f-c7e4-4883-b8b9-1b4500a402ea/blizzard-end-user-license-agreement) references restrictions on reverse engineering and derivative works; full-page retrieval was blocked, so this is not a complete EULA review. Access to an installed client does not itself establish a redistribution grant for extracted tables, text, textures or other content. Technical extractability and user authorization to inspect local files are separate from publication rights.

Numeric IDs and measured reward facts can have a different analysis from authored descriptions, translations, corrections, selection/arrangement and protected databases. This review does not presume that an entire game database is unprotected merely because some columns contain facts. Do not include game artwork or prose in a proposed owned numeric cache without a separate justification.

The existing `data/primary-statuses.json` classification snapshot keeps its own provenance and exact-variant rules. It is not a license for Questie rewards or client data and must not silently become the provenance for those fields.

## Practical paths

1. Generate FindAnUpgrade's owned bundled schema from reviewed, pinned ATT numeric records with full MIT attribution, then enrich and correct it with verified current Forever observations. Preserve unknown fields and exact variants. Keep source-specific provenance rather than merging everything into an unqualified BSD data claim.
2. For any Questie-derived additions, establish a grant for the exact input files and contributor-origin data first. If that grant is GPL, document the distribution architecture and matching-source delivery; if permissive, preserve its notices. A general maintainer statement may not resolve every contributor's rights.
3. Runtime providers may supplement the owned catalog but do not satisfy the user's bundled-database requirement. Independently collected numeric data needs documented collection/terms and cannot be described as independently authored if actually exported from Questie or Wowhead.

Before generating anything distributable, record input project/revision/file hashes, exact included fields, correction/localization policy, license/permission evidence, generator revision, output hashes, and recipients' matching source access. Keep unknown rewards unknown, and distinguish static base values from character-dependent rewards. Permission evidence and data accuracy are separate requirements.
