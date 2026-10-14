# Reward finder data feasibility

Reviewed 2026-10-14. The user requires a **bundled, addon-owned Forever catalog without a Questie dependency**. The selected source is a narrow numeric extract from the MIT-licensed **AllTheThings Forever authoring data**, pinned at `d75383ccdbff1208b87cf4024fa425c0825a7ad6`. Neither the earlier Wowhead captures nor a Questie export is the selected bundled input. Their investigations below are retained as comparison evidence.

This investigator changed this document and, after explicit delegation, the numeric `data/catalog-compiled-membership.json` cross-check; no runtime or README was changed during the data investigation. The selected authoring files support a curated association catalog and source-reported metadata, but do not establish every reward quantity/group, quest difficulty level, current availability, player usability or an upgrade score. Native observations remain distinct. QuestBrief's existing exact classifications continue to come only from `data/primary-statuses.json`.

## Final guarded catalogue audit

The final guarded importer snapshot contains **1,267 quests, 1,977 item IDs and 2,311 quest/item associations**. Every shipped pair independently appears in direct authoring `q`→`i` evidence and the frozen compiled membership cross-check. All 95 provenance file receipts were independently checked against retained exact bytes, including Git blob and SHA-256 hashes. `tools/check_membership.py` reproduces the compiled facts without executing upstream Lua. The investigation's `.work/final-catalog-audit.py` also checks canonical pair boundaries, class/faction constraints, representative objective exclusions and unknown prerequisites. The implementation owner's generator records the same final scope in `data/catalog-coverage.json`.

| Final source-reported minimum player level | Quest IDs |
| --- | ---: |
| 1–10 | 256 |
| 11–20 | 192 |
| 21–30 | 177 |
| 31–40 | 144 |
| 41–50 | 199 |
| 51–60 | 177 |
| 61+ | 0 |
| Unknown | 122 |

Final exact classification membership is **New 48, Updated 60, Unchanged 255 and Unknown 904**. Direct or compiled faction constraints are Alliance 409, Horde 362 and no recorded faction 496; 27 records separately preserve specific race lists. The catalogue flags 311 records with incomplete eligibility metadata. Unknown classification, faction, level or eligibility must not become a fabricated status or positive availability claim.

There are **zero static quest-difficulty levels, verified quantities, guaranteed/choice groups or money/XP/currency/reputation amounts** in this source scope. These zeros count known fields in the build report; they do not establish zero in-game rewards and are not reward values to display. Native observations may supplement them separately. The catalogue is partial: inherited common quest containers, unsupported race/class expressions, plain objective item tables and opaque constructor transformations are not broadened by guesswork. Only reviewed item-backed factory metadata and the explicitly typed toy mapping supplement the initial `i`/`s` output shape. The final three records excluded from the 1,270-ID pair intersection are 792, 8767 and 1049, whose selected class/race expressions were unsupported.

Duplicate quest **96875 is shipped after the reviewed factory extension**: its direct authored item 277716 compiles as `r(1302604,{itemID=277716,...})`. The importer merges its compatible authoring records, retaining minimum 6, both giver coordinates, incomplete eligibility and the location-conflict flag. Both the canonical row and the pure merge function were independently checked. It is the catalogue's single flagged location disagreement, which prevents selecting either coordinate as a confirmed waypoint. The earlier `i`/`s`-only cross-check conservatively excluded it; the explicit retained item ID and original authored association justify its inclusion.

No upstream Lua was executed and no live client evidence was obtained for this audit. Current native map geometry, item cache/tooltips, reward groups, availability and taint behavior remain pending live verification. The source build is 69893; the targeted API contract is 70374. The pinned compiled output has no embedded build stamp.

## Expanded Forever source and compiled cross-check

The initial 87-file selection was incomplete. The exact pinned [Parser input loader](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/src/Parser/Program.cs#L457) recursively enumerates every `*.lua` beneath the selected `root-data`; lines 523–528 parse every non-`.config` file. It does **not** exclude a folder named `zzOLD`. The acquired scope now includes **44 legacy authoring files** there and **two expansion-feature files**, making 133 selected authoring files. These are original Forever-root inputs, not an assumption that the standard/Retail catalog inherits. Every acquired byte has a Git blob/SHA-256 receipt in `.work/att-source/ACQUISITION.json`.

Many legacy records use `["groups"]`, `["lvl"]` and other literal quoted keys. Normalizing those keys and applying the pinned preprocessor identifies **1,566 candidate reward-bearing quest IDs, 2,701 unique immediate quest/item pairs and 2,338 item IDs**. All 2,702 immediate item constructor occurrences are `i`; no direct authoring `s` constructor supplies additional rewards. The initial files also contain quoted-key records missed by the first narrow shape. These counts precede timeline, inherited restrictions, `_drop` and selected-field checks; they are not final importer or live coverage.

| Candidate minimum player level | Quest IDs |
| --- | ---: |
| 1–9 | 185 |
| 10–19 | 202 |
| 20–29 | 169 |
| 30–39 | 161 |
| 40–49 | 206 |
| 50+ | 349 |
| Unknown / unsupported expression | 294 |

Direct candidate faction metadata is Alliance 413, Horde 370, specific race lists 27 and unrecorded 756. Exact existing classification membership is New 48, Updated 60, Unchanged 256 and Unknown 1,202. A missing faction is not evidence of both-faction eligibility. These are source-reported **minimum player levels**, not quest difficulty levels. `.work/att-expanded-summary.json` retains the count procedure and representative source locations.

The pinned [preprocessor](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/src/Parser/Program.cs#L894) compares named expansions by release phase, and numeric patch strings by release version. Its [phase table](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/src/Parser/Framework/Framework.cs#L59) sets FOREVER to **16**, TBC 17, WRATH 30 and CATA 40. The source build is 1.60.1.69893. Unknown directives must fail explicitly; numeric `1.60` must not be interpreted as expansion 60. The shared `lvlsquish(original, cata, shadowlands)` helper returns the original value for Forever; resolving a literal call is defensible only with that explicit helper contract. Timeline fields still need separate processing after conditional preprocessing.

### Why compiled membership is a cross-check

The acquisition owner retained the exact pinned `db/Camelot/Database.xml` and all of its category files in `.work/att-generated/`, with hashes in `ACQUISITION.json`. The XML loads LocalizationDB plus Character, Craftables, ExpansionFeatures, HiddenQuestTriggers, Holidays, Instances, NeverImplemented, Professions, PVP, WorldDrops and Zones. The numeric probe excludes HiddenQuestTriggers, NeverImplemented and WorldDrops, imports no localization/lore, and inspects only literal quest constructors with immediate item children. Alias declarations bind `q` to CreateQuest, `i` to CreateItem and `s` to CreateItemSource; the pinned [ItemSource exporter](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/src/Parser/Export/Object%20Data/ItemSourceData.cs#L24) explicitly writes **itemID as the second `s` argument**. The first argument is an appearance-source ID. The reviewed extension also accepts immediate `r`/`mnt`/`p`/`toy` constructors when their second argument is a literal table containing a direct positive numeric `itemID`. Header aliases must bind those names to CreateRecipe/CreateMount/CreateSpecies/CreateToy. The [recipe](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/src/Parser/Export/Object%20Data/RecipeData.cs) and [mount](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/src/Parser/Export/Object%20Data/MountData.cs) exporters distinguish their spell/recipe identifiers from a retained `itemID` field. A typed `toy(itemID)` first argument is also supported: the pinned [shared root configuration](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/.db/shared/.config/root.config#L117) defines CreateToy's object type `toyID` and converted key `itemID`. This explicit mapping adds items 276236 on quest 96339 and 21540 on quest 8868. No arbitrary nested field or plain objective item table is traversed.

| XML-loaded compiled category | Item-associated quest IDs | Immediate supported item pairs |
| --- | ---: | ---: |
| ExpansionFeatures | 18 | 22 |
| Holidays | 110 | 193 |
| Instances | 298 | 619 |
| PVP | 28 | 36 |
| Zones | 1,049 | 1,872 |
| Other included categories | 0 | 0 |
| Unique union | **1,503** | **2,742** |

Compiled direct children are **not sufficient reward evidence**. For example, [Moonglade's Trial of the Sea Lion authoring](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/.db/forever/zzOLD/02%20-%20Outdoor%20Zones/01%20Kalimdor/Moonglade.lua#L422) places raw `itemID` tables for collected components 15882 and 15883 under the shared Alliance/Horde quest container; the generated output promotes them to immediate `i` children on quests 30/272. Those items are not established completion rewards. The 422 compiled pairs without a direct authored `q`→`i` trace are therefore rejected, even when their generated IDs and folder are clear. Conversely, 381 direct authoring pairs are absent from this supported compiled shape: causes include future timelines, `_drop`, other constructor shapes and possible generation differences. Absence is a conservative exclusion, not proof that the original association is false. The earlier `i`/`s`-only rule had 401 untraced and 468 absent pairs; explicit item-backed factory metadata and the typed toy mapping recovered 87 independently authored associations without accepting the compiled-only objective examples.

The conservative **intersection is 1,270 quest IDs, 2,320 pairs and 1,984 item IDs** before importer metadata guards. It contains 48 existing New IDs, 60 Updated, 256 Unchanged and 906 Unknown. This provides a broader independently traceable source gate. `data/catalog-compiled-membership.json` stores all 2,742 sorted compiled membership pairs, ten exact input receipts (XML, eight selected category files and the shared root configuration), and 988 consistent numeric class/faction constraints; the importer must still require a separate authored pair. Its compact canonical pair-list SHA-256 is `1c7bbbf23adf95c8616e6ca16d05b54dbfa41b0c118630cb80ec370fef2519a8`. No reward quantity, guarantee/choice group, native ordinal or live availability is supplied.

The pinned [field normalizer](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/src/Parser/Framework/Framework.cs#L1152) maps `classes` to `c`; the shared class constants and runtime membership check identify numeric class restrictions. [Faction normalization](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/src/Parser/Framework/Framework.Objects.cs#L1139) maps full Horde/Alliance race lists to **`r=1` Horde / `r=2` Alliance**. Absent constraints remain unknown. The compiled extract has no conflicting overlapping class/faction values. It has no embedded client build stamp: 69893 is the source configuration's declared build, not a reproduced generated build or a live 70374 observation.

Concrete duplicate check: quest **96875**, Beasts of Thunder Ridge, occurs in Durotar and the legacy Orgrimmar file with the same giver 5811, Horde restriction, Leatherworking requirement and direct item 277716. Durotar records minimum 6; Orgrimmar omits it. Labels differ by a `(RECIPE!)` comment. Giver coordinates differ slightly (63.0/45.0 versus 63.2/44.4 on the same Orgrimmar map). Preserve both provenance and location alternatives, mark the disagreement, and do not let missing values override recorded minimums or silently pick one coordinate. A genuinely conflicting known eligibility field requires an explicit diagnostic and conservative resolution.

Suitable low/middle/high offline fixtures are **87 Goldtooth** (minimum 5, Alliance, item 1359), **231 A Daughter's Love** (minimum 28, Alliance, items 2000/270051) and **7491 For All To See** (minimum 60, Horde, items 18403/18404/18406). A Forever-specific source fixture is **98372 An Unfortunate End** (item 280612; no direct minimum), and **98403 Twisted Hatred** tests preservation of an exact New variant plus exclusion of objective item 281023. Source snapshots do not establish native item cache hydration, native tooltip rendering, reward quantities, present offers or map geometry.

An earlier suspicion that library-book IDs indicated Season of Discovery contamination was disproved by the original [Forever library-books file](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/.db/forever/expansion%20features/library%20books.lua), whose parent timeline explicitly adds them in 1.60.1. Shared IDs alone cannot identify a variant or exclude it. Its inherited faction-specific giver data and named prerequisite list require their own normalization before claiming a complete starter/availability record.

Ignored `.work/att-generated-probe.py`, `.work/att-generated-probe.json`, `.work/att-expanded-summary.py` and `.work/att-membership-export.py` retain the read-only counting and export procedure. Final shipped counts belong to the implementation owner's guarded importer and `data/catalog-coverage.json`, not the candidate audit totals above.

## Selected ATT source: initial schema and coverage review

The acquisition owner retained exact pinned files and hashes in `.work/att-source/ACQUISITION.json`, with its [MIT license](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/LICENSE). The initial review read **87 selected authoring Lua files** under `.contrib/.db/forever/`, excluding `.config` support files from the authoring count. Selected folders were zones, dungeons/raids, character, professions, holidays, PvP and world events. `zzOLD`, expansion features, `.nyi`, `.hqt`, Missing DB, raw harvesters and assets were initially excluded. The expanded review above corrects that initial source selection; it does not imply all possible Forever content is covered.

The read-only lexical probe `.work/att-schema-probe.py` identifies literal positive `q(id, {...})` records and immediate `i(id)` children in their `groups`/legacy `g` array. It skips nested constructors/tables wholesale, so items beneath objectives, costs or providers are not misclassified as direct rewards. It does **not** execute the authoring code, resolve every wrapper/inherited field, apply all preprocessors or reproduce the upstream compiler. The resulting raw authoring counts are therefore candidate coverage, not final generated or live coverage:

| Measurement | Initial selected authoring scope |
| --- | ---: |
| Literal quest records / unique quest IDs | 2,343 / 2,343 |
| Direct quest/item association pairs | 1,273 |
| Quests with a direct item association | 688 |
| Distinct directly associated item IDs | 1,130 |
| Existing classified IDs with a quest record | 706 of 1,194 |
| Existing classified IDs with an item association | 254 |
| Existing New IDs with a quest record | 146 of 218 |
| Existing New IDs with an item association | 43 |

Absence from this selected scope does not establish that a quest has no reward, is unavailable, or changed classification. `.work/att-schema-counts.json` records the measured scope and field counts. Focused checks retain both immediate items for quest 3522 and retain item 282284 for quest 98403 while excluding its objective item 281023.

### Field meaning and concrete boundaries

The pinned [shared shortcuts/schema](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/.db/shared/functions/Shortcuts.lua) defines `q` as a `questID` object, `i` as an `itemID` object, and `groups` as nested parser objects. The selected files have no explicit assignments for reward quantity, guaranteed/choice type or `questLevel`. An immediate item child is association evidence; its array position, number of siblings or omitted fields do not establish a native ordinal, quantity of one, or reward choice status. `_drop` and other authoring modifications must be respected before final generation.

The schema explicitly defines **`lvl` as minimum player level**, or a `{minimum, optional maximum}` tuple. It is present directly on 1,858 quest records. No direct `questLevel` field was found. Do not reuse `lvl` for a quest-difficulty band or a claimed level-fit/upgrade score; an absent difficulty level remains unknown until a distinct reliable source supplies it.

`qg`/`qgs` mean single/multiple NPC quest givers; direct fields occur on 2,017 and 22 quests respectively. `coord`/`coords` are map-coordinate tuples, present directly on 2,002/119 quests; `maps` occurs on 346. Match locations to their represented giver/source, preserve all alternatives and unknowns, and do not describe the first tuple as nearest. Objective coordinates belong to objectives, not the starter. `qi` is an associated/provided quest item, and typed `provider`/`providers` can describe an item/object source; none is a reward substitute. Exact recorded giver IDs do not establish current offers or player availability.

The pinned Forever map constants explicitly include `MAP.TELDRASSIL = 1438`, Darnassus 1457 and the Classic-style UI map namespace; they also have a `_G` fallback for unknown symbols. Do not execute that fallback with guessed globals or convert an unresolved symbol to a number. The shared shortcut schema's lines 74–75 explicitly define both axes as percentages, so dividing a resolved coordinate by 100 is supported. The source config targets **1.60.1.69893**, while QuestBrief's current native contract is 70374. Native map identity and coordinate geometry still need verification; copying percentages through a different map/area namespace or automatically applying an Era transform is unsupported.

Direct `races` fields occur on 1,729 quests and `classes` on 392, with the shared `r`/`c` aliases also defined. They are ID lists, not Questie bitmasks. The pinned [race constants](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/.db/shared/constants/raceIDs.lua) explicitly include Forever Skyborne Alliance **95** and Horde **96** under a FOREVER condition. Alliance/Horde arrays also contain nested retail expansion conditions; an unconditional flatten would introduce incorrect races. The pinned [class constants](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/.db/shared/constants/classIDs.lua) similarly contain expansion-gated class collections. A quest class restriction still says nothing about item usability.

`sourceQuest` occurs on 1,143 quests, `sourceQuests` on 90, and `altQuests` on 143. **Seven Zephras records explicitly set `sourceQuestNumRequired = 1`**. Preserve this threshold: the pinned runtime `src/Classes/Quests.lua` uses `sqreq` or the list length, with additional breadcrumb/alternate/locked/current-character policy. Do not copy that runtime policy into a simple availability claim or silently turn every list into ALL. `sourceQuest` on **quest 3522 points to 3522 itself**, despite its comment naming the preceding step. Flag the self-loop as uncertain source metadata; do not guess the corrected ID or let it permanently exclude the quest.

### Shared configuration and preprocessing

The pinned [Forever build command](https://github.com/ATTWoWAddon/AllTheThings/blob/d75383ccdbff1208b87cf4024fa425c0825a7ad6/.contrib/.db/build%20-%20forever.bat) starts with `standard/.config/retail/retail.config` as **base configuration**, then overrides with `forever/.config/forever.config`. The latter selects root-data Forever, Camelot output, DataPhase FOREVER, build 69893 and tags ANYCLASSIC, FOREVER, CAMELOT, CLASSIC, CRIEVE, EXPLORATION, OBJECTIVES and NOSIMPLIFY. This does not authorize importing the standard/retail quest catalog.

Shared helper/schema files live under `.contrib/.db/shared/`, including `functions/Shortcuts.lua`, `constants/classIDs.lua`/`raceIDs.lua`, and `.main.lua`; Forever overrides maps/timelines/currencies and supplies profession structures. A targeted importer needs explicit symbol and helper semantics plus parent inheritance. Its source count must be recomputed after preprocessing, wrappers, `_drop`, alias normalization and supported parent restrictions are handled. Observed selected-source directives include BEFORE 4.0.3, SEASON_OF_DISCOVERY, AFTER TBC/CATA/10.1.7 and NOT OBJECTIVES. Do not ignore them, evaluate retail arrays wholesale, or create an arbitrary nil-global metatable.

The inherited retail base config also names auto-localization, Wago, JSON and field-adjustment stages. The selected Forever config replaces input paths, but this review did not reproduce their complete merge/execution behavior. Running network harvesters or copying raw caches is outside this chosen narrow authoring-source scope. The final generator should expose unsupported DSL constructs and unresolved symbols as diagnostics, preserve exact numeric evidence/provenance, and avoid silently dropping relevant records.

See [SEARCH-DATA-LICENSE-REVIEW.md](SEARCH-DATA-LICENSE-REVIEW.md) for the exact license/notice scope. Initial source/schema findings justify an addon-owned curated catalog with native supplements; they do not justify a completeness, guaranteed-reward, current-coordinate or live-taint claim. Final importer/output coverage and the implementation tests remain the implementation owner's integration step.

## Earlier Wowhead acquisition: not selected for bundling

The original project is `C:/Users/matt/Documents/Codex/2026-10-13/task-4/quests/`. Its evidence was collected from public Wowhead Forever pages for the chart, independently of Questie. The following files were inspected without modifying the earlier project:

| File relative to the earlier project | Usable content | Limits |
| --- | --- | --- |
| `provenance/forever-confirmed-chart-data.json` | 2,919 confirmed exact variants under `zones` and `ancillaryZones`; each `quests[category][].variants[]` retains ID, name, level, requiredLevel, faction, per-ID status and `wowheadForeverUrl` | Final projection omits reward IDs; status scope is independent of QuestBrief's existing frozen classification input |
| `provenance/forever-outdoor-verified-evidence.zip` | 31 raw JSON entries with 3,280 captured rows and 3,080 distinct IDs, including original18, Kalimdor expansion, new outdoor and Eastern Kingdoms captures | Raw scope includes excluded/unavailable-category captures and duplicates; filter against confirmed membership and preserve conflicts before producing a catalog |
| `provenance/forever-all-outdoor-data.json` | Per-variant `sourceCells`, primary URLs, region/category context and the earlier 2,984-ID projection | Superseded membership; no reliable per-item quantities or starter coordinates |
| `provenance/forever-faction-resolution.json` | 62 exact detail-page faction checks and focused rendered Quick Facts evidence | Focused AX evidence omits reward/starter detail; Side: None must not become Both |
| `../qa-tools/tooltip-smoke.json` | Seven original official-widget quest tooltip response bodies, under `examples[].entities.forever.data` | Quest bodies contain objectives/requirements, not rewards, level/minimum level, NPC IDs or coordinates |
| `provenance/wowhead-tooltip-integration.md` | Official widget route/environment verification: Forever is dataEnv 16, locale 0 | Integration support is not a blanket redistribution grant for a database |

The ZIP SHA-256 is `95cc5283a2b1506441cd13f4f4642475dc3587700c955d8932c6219908dfb618`. Important contained entries are `forever-original18-refreshed-raw.json` (19 page captures, 1,207 rows), `forever-kalimdor-expansion-raw.json` (16 keyed zone captures, 728 rows), `forever-new-outdoor-raw.json` (`pages[]`, 146 rows), `forever-ek-raw-*.json` (25 files, 1,033 rows), and separate Felwood, Un'Goro and Silithus page-two captures.

Most raw row shapes are `{cells, faction, links}` with optional `changesHtml`/`sideHtml`; some use normalized `{id,name,level,requiredLevel,faction,url,sourceCells}` and have lost the item links. Pages may be a list, a zone-keyed dictionary, or a `pages[]` container. A collector must traverse those declared shapes rather than assume one flat `rows` array.

In linked rows, exact quest/item IDs occur in public `/forever/quest=ID` and `/forever/item=ID` URLs. Captured cells retain status, title, quest level, minimum level, reward text, XP and a rendered money cell. Currency units and per-item stack counts were often lost with icon markup; a bare money cell such as `40` is not evidence for 40 copper, silver or gold. Empty cells are not verified zero.

| Association scope | Reward-linked quests | Distinct items | Unique quest/item pairs |
| --- | ---: | ---: | ---: |
| All raw captures, before membership review | 1,081 | 1,617 | 2,049 |
| Only the confirmed 2,919-ID snapshot | 1,054 | 1,569 | 1,994 |
| Only QuestBrief's existing 1,194 classification IDs | 435 | 782 | 872 |

Every confirmed ID and every existing classification ID has a raw row. Twelve existing classification IDs are absent from the newer confirmed membership; this does not authorize changing their established classification. Counts above deduplicate association IDs only, **not reward group records**. A source importer still needs a conflict and completeness audit.

Concrete group ambiguity: quest **682** has reward cell `Pick one: / Also get: Stromgarde Cavalry Leggings`. Item **4741** occurs twice in the row links, once among blank-text choice icons and once as a named guaranteed link; globally deduplicating links would lose the distinction. Quest **738** has three item links and a reward cell containing only `2`; that count cannot safely be assigned to an item after flattening. Preserve source order and explicit named group evidence, and keep ambiguous group/count fields unknown. Do not manufacture a quantity of one or treat all links following a mixed label as choices.

### Fresh public widget checks

The [official Wowhead tooltip guidance](https://www.wowhead.com/tooltips) documents the widget script and supported entity links. The earlier project retained its public script in `../qa-tools/wowhead-tooltips-current.js`, with actual Forever widget request receipts. This investigation used those public routes without private endpoints or challenge bypass:

- `https://nether.wowhead.com/tooltip/quest/1203?dataEnv=16&locale=0` and quest 95534 returned only `name` and HTML `tooltip` objectives/requirements. They provide no reward or starter schema.
- `https://nether.wowhead.com/tooltip/item/277206?dataEnv=16&locale=0` returned `name`, `quality`, `icon`, HTML `tooltip`, and `spells`. The sample supplies Back slot text, item level 41, armor 27, stamina 5, intellect 5 and a spell-power effect of 6. These are source-reported facts, not observed native stats or a player-specific score. The endpoint sample is retained in ignored `.work/wowhead-forever-item-277206.json`.

Other fresh response samples are `.work/wowhead-forever-quest-1203.json` and `.work/wowhead-forever-quest-95534.json`. No HTML, objectives, descriptions or icon assets are proposed for the shipped payload. An independent factual item extract should retain source URL/date/hash and exact parse evidence for each numerical/slot field, leave unsupported effect/stat semantics unknown, and continue using native textures/tooltips at runtime.

Public quest detail pages for 95534 and 504 challenged the text reader; an ordinary HTTP read of 95534 returned an empty body. The CUA browser could not initialize because its required Windows platform directory was absent. No challenge bypass was attempted. **Full primary reward groups, quantities and starter/map coordinates remain acquisition gaps**. A usable association/metadata catalog can be built from the retained captures; claiming a complete guaranteed/choice database or working starter waypoints from them would be unsupported. Publication rights/terms for the selected narrow factual extract need their own review; official website widget integration does not settle that question.

Ignored `.work/primary-capture-complete.py`, `.work/primary-capture-summary.json` and `.work/primary-membership-probe.py` retain the counting procedure and membership audit. They are investigation artifacts, not a generated addon dataset.

## Earlier optional-provider research

The remaining sections explain the independently inspected Questie provider and why its existing UI is not equivalent to the requested finder. They are retained as comparison evidence; Questie is not the chosen catalog dependency or bundled input.

## Sources and scope

Inspected read-only on MONOLITH under `C:/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/`:

- Questie **12.1.0**, Camelot/Forever interface 16001, declared build commit `91fb7e2a457e74fe05f02570e7e45f93794d9305`.
- QuestieDB **1.0.6**, Forever flavor, baked mode, contract **4**, declared build commit `36ca1ca86f6c1838de479c7c7452eb0a57d5c135`.
- QuestBrief's `data/primary-statuses.json`, the independently retained per-variant classification evidence.

The database is the separate [Questie/QuestieDB project](https://github.com/Questie/QuestieDB). Its [import provenance](https://github.com/Questie/QuestieDB/blob/36ca1ca86f6c1838de479c7c7452eb0a57d5c135/PROVENANCE.md) distinguishes the historical Questie migration reference from current maintained source ownership. Do not treat the migration commit as the database's current build pin.

Current official-client API contracts are Forever 1.60.1.70374 / interface 16001 at Gethe/wow-ui-source `735496de78ebd30ce816a0637982c556987f258c`. This is source evidence, not an observed live API response. No client UI was operated, installed file modified, or game configuration changed for this review.

## What Questie's installed UI already provides

`Modules/Journey/QuestieJourney.lua:133` builds a resizable **1000 x 650** AceGUI window with My Journey, Quests by Zone, Quests by Faction and Advanced Search. The default Journey binding is semicolon, applied once only when neither the Journey action nor that key already has a binding.

The loaded search implementation is `QuestieSearch.lua` plus `QuestieSearchResults.lua`; the alternate `tabs/Search/` files are commented out in the Camelot TOC. It searches quests, NPCs, objects and items by name or ID, offers partial matches and quoted exact matches, accepts cached item links, and separates results into entity tabs. Selecting a result shows entity details. It does not filter a quest-reward catalog by equipment slot, player usability, or a player-relative quest level band.

`QuestieSearchResults.lua:406` requests an item through Questie's scanning tooltip, then polls its cache before drawing details. The item detail view contains a native item tooltip, NPC drops, object drops and vendors, with manual Show/Remove on Map buttons. **No Journey Lua module reads `questRewards`** in the inspected installed package. Its item source view does not join an item to the quests that reward it.

`QuestDetailsFrame.lua:293` shows quest level/minimum level, race/faction and class requirements, profession requirements, reputation estimates, prerequisites, starter locations and Questie's completion/hidden/doable state. Some controls write Questie's hidden state; the doable helpers use Questie's policy and can update its blacklist. QuestBrief should implement its own read-only presentation rather than invoke those policy/action paths. This finding concerns inspected source, not the usability of a running Journey window.

## Measured Forever coverage

The raw TOC field counts and the composed counts were measured separately. An isolated Lua 5.1 runtime executed **every Lua file listed in the installed Forever TOC**, in order, using metadata, Base64, CBOR and compression stand-ins. It then enumerated the public `Item.GetAllIds(false)` and `Quest.GetAllIds(false)` methods and read `Item.Get(id, "questRewards")`.

Two explicit offline personas were tested: Alliance/Human/Warrior and Horde/Orc/Warrior, enUS, Forever interface 16001. They loaded the provider's own dynamic corrections and both produced the following results. This does not cover all classes/races/locales, additional consumers' registered corrections, or server correctness.

| Measurement | Baked base metadata | Composed provider, each tested persona |
| --- | ---: | ---: |
| Quest entities | 5,226 scalar rows | 5,226 IDs |
| Item entities | 21,279 scalar rows | 21,279 IDs |
| Items with an item-to-quest reward list | 2,438 fields | 2,438 items |
| Unique item/quest reward associations | 3,360 | 3,360 |
| Distinct associated quest IDs | 2,006 | 2,006 |
| Associated quest IDs with an existing Quest row | 2,001 | 2,001 |
| Associations whose quest has an existing Quest row | 3,355 | 3,355 |

Both composed association sets exactly matched the base set. Installed static correction bodies are stripped because their results are already baked into the metadata. The inspected legacy item dynamic corrections change names/drop/related-quest fields, and the Forever item dynamic correction is empty; neither rewrites reward associations for these personas.

Five recorded reward quest IDs lack a Quest entity: **9353, 79090, 84395, 84400 and 84401**. Do not invent their names, levels, availability or starters from the association alone. A future importer should retain a diagnostic or an explicitly incomplete record, rather than silently claim a complete catalog.

Of QuestBrief's 1,194 classified IDs, **1,166** have base Quest rows, including **216 of 218 New IDs**. New IDs **95771** and **98447** have no row. Only **397** classified IDs have a recorded item reward association: 281 Unchanged, 59 Updated and **57 New**. The remaining classified quests cannot be described as having no item rewards: reverse-index absence is not verified reward absence, and not every quest needs an item reward.

For the 2,001 associated quests with rows, composed reads returned nonempty starter structures for 1,740, `preQuestSingle` for 977, `preQuestGroup` for 34, `exclusiveTo` for 71, and reputation pairs for 1,251 in both personas. These are field-presence counts, not completed eligibility checks. Provider numeric getters reconstruct **zero defaults** for omitted known-entity scalars; all 2,001 therefore return level/mask values even when the baked scalar omitted them. **33** associated quests have a nonpositive/default quest level. Missing/default levels must not become a verified level-band match.

## What the schema can and cannot establish

| Source | Useful information | Boundary |
| --- | --- | --- |
| `Item.questRewards` | Exact item ID / quest ID association | No count, choice group, native reward index or quest-specific item link |
| Item name, level, required level, class/subclass | Search text and broad item category | No equip slot, allowed player-class mask, stats, specialization weights or upgrade estimate |
| Quest level and minimum/maximum player levels | Separate quest difficulty and entry-level constraints | Defaults and unknown levels are not availability evidence |
| Quest race/class masks | A recorded quest restriction, using active provider enums | A quest's class restriction says nothing about whether its reward gear is usable |
| Prerequisite/exclusion fields | Exact dependency IDs | Preserve ANY-single versus ALL-group semantics, signed IDs and exclusive alternatives; profession, reputation, parent, spell, rank, phase and current-log conditions can still be unresolved |
| Starter structures and spawn coordinates | NPC/object/item starters and candidate locations | NPC association alone is not availability; AreaTable IDs are not UI map IDs, and phase/sentinel points need validation |
| `Quest.reputationReward` | Recorded faction/value pairs | Database base values are not an observed current-player award; racial/buff/other modifiers and missing coverage remain separate |

These are the installed [Item declarations](https://github.com/Questie/QuestieDB/blob/36ca1ca86f6c1838de479c7c7452eb0a57d5c135/Types/Item.t.lua) and [Quest declarations](https://github.com/Questie/QuestieDB/blob/36ca1ca86f6c1838de479c7c7452eb0a57d5c135/Types/Quest.t.lua). `GetAll` results are packed with `.n`; nullable fields can create holes. `GetAllIds` lists are shared and read-only. Copies belong to QuestBrief; never sort a provider-owned index or register QuestBrief corrections into another addon's database.

## Feasible owned-data pipeline

1. Pin the separate QuestieDB repository revision, flavor Forever, contract/schema version and generator version. Prefer an upstream-supported export through its own loader/emulator to a handwritten interpretation of its tables. Record source hashes and the exact static/dynamic policy; a package's declared build commit alone is not a content hash.
2. Produce a neutral static association layer by reversing **only** `Item.questRewards`. Deduplicate exact `(questID, itemID)` pairs and sort both levels deterministically. Never infer rewards from `relatedQuests`, item drops, quest-start items, names, or title groups. Do not freeze one character's dynamic correction results into a universal dataset.
3. If independence needs more than association discovery, retain only the relevant quest/item metadata and prerequisite endpoints, with typed unknowns and source-field provenance. Preserve starter groups, signed prerequisite IDs, race/class enums and coordinate identity. Keep character-dependent facts in runtime adapters; document omitted fields and unresolved graph endpoints.
4. Generate a versioned compact Lua payload plus a machine-readable manifest: source repository/revision/hash, interface/build, schema version, collection date, counts, missing references and per-field origin. Validate source-to-output equality, deterministic bytes, unique/sorted pairs, metadata references, corrupt/unknown values, flavor isolation and classification separation in CI. Reject silent coverage regressions.
5. Overlay bounded official-client observations at runtime without changing the source snapshot. Keep confirmed data and database-only associations visibly distinct. Any persisted observations need their own schema/build/context identity; never interpret an absent observation as zero or guaranteed absence.

The numeric reverse mapping alone measures **39,367 bytes** as a minimal Lua table and **12,516 bytes** with DEFLATE level 9. This is an in-memory estimate, not a generated/shipped dataset; it excludes metadata, provenance, indexing overhead and Lua runtime memory. It makes a small association snapshot plausible. It does not justify copying the whole provider database or promise a particular frame-time budget.

Redistribution scope is unresolved for a bundled QuestieDB-derived snapshot. The inspected installed package has no license file; this investigation did not establish an upstream grant. The separate [data licensing review](SEARCH-DATA-LICENSE-REVIEW.md) records stronger upstream evidence and the architecture choices. Before bundling, identify the source/data license or applicable ownership authorization and retain required notices independently of QuestBrief's BSD-3-Clause original-code license. No provider code/database was copied into the shipped addon here.

## Official-client supplements

The current [C_Item contract](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua) exposes cached item info, equip location, inventory type, icons, item-load events and nullable item-stat/stat-delta tables. Use exact IDs/links, readable values and bounded requests for relevant candidates. Do not preload the entire catalog. Missing cache data must remain pending/unknown and can recover on a matching load event. Native equippability and general usability do not by themselves prove class-only admissibility or a role-specific upgrade.

The existing exact-ID reward reader can confirm item reward indices, counts and guaranteed versus choose-one grouping when native reward data is ready. It also reads XP, money and currency groups. Match the returned native item identity before using a tooltip or comparison. Such observations are client/context evidence, not a global server catalog or proof that an unobserved quest has no rewards.

The [C_QuestLog contract](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua) supplies exact-ID current/completed state and quest-data requests; false completion is not permission to accept a quest. Its native reputation reward API is limited to major factions. Ordinary Forever faction amounts remain unverified. Item-level distance and known quest-level fit can support labelled ordering; a numerical role score needs an explicit validated scoring model and usable stat coverage. Native comparisons remain useful without that score.

Source extraction from future official client tables would need its own build-specific schema and provenance investigation. No full quest-reward enumeration or complete server reward dataset was established from the inspected APIs, and no unofficial/private-server database is proposed as a Forever substitute.

## Reproduction evidence and remaining checks

Ignored local probes `.work/search-data-counts.py`, `.work/search-data-detail.py` and `.work/search-data-counts.json` retain the counting procedure/results; they are not shipped code or public dataset artifacts. The procedure reads installed files and executes them in an isolated offline Lua runtime. Installed source SHA-256s:

| Installed file | SHA-256 |
| --- | --- |
| `QuestieDB/QuestieDB_Forever.toc` | `954c5cfbd6ffb812efef338b4c9a42c964b785485b6f9ab4a458679fbb4707d0` |
| `QuestieDB/Types/Item.t.lua` | `c73f1d2fcd2546599d1eac54797a60f3d872c5b092f22813471517f5b74d4e1f` |
| `QuestieDB/Types/Quest.t.lua` | `b39bb8fe5ba15e3a21dfe52e40214275c8ab4846ada479a1cd574555f212da9e` |
| `QuestieDB/src/api.lua` | `4208f7e2a8cc490bfc1e73ff794fc736d807fde0fb3fee29971bfe9b49f16923` |
| `QuestieDB/src/read/shared.lua` | `0483683b71fe572f1033b878eaf90af68e61093cfd260942c9b77be4433a9921` |
| `Questie/Questie_Camelot.toc` | `2bd4388a11fcb4f7165fc101393ebb080e489d2dfe5948cc6b3ea1a6fe86c964` |
| `Questie/Modules/Journey/QuestieJourney.lua` | `7360a8b48b1b365949a14fac4885cc8a5e82f9414f3cd28384369e80ea66be3c` |
| `Questie/Modules/Journey/QuestieSearch.lua` | `5da86c03a56ccfbadd699fa7fcc4679214ccf4c92b0d01e67f85d06ae5921537` |
| `Questie/Modules/Journey/QuestieSearchResults.lua` | `57c7dc44ea6639e0b19e21ec79dfbe7212d14711535f8d4ee4f7735fd52244a6` |
| `Questie/Modules/Journey/QuestDetailsFrame.lua` | `59f51bcc0f2b827d89b52b68641ced66d40a731d36d7f744bd069b3bfa0addef` |

Pending: architecture/redistribution decision; upstream export equivalence and multi-persona/consumer corrections if a snapshot is authorized; official native reward/item loading for representative old/modified/new variants; real slot/usability/stat behavior; available versus unavailable prerequisites; ordinary reputation; UI performance, cache timing, comparison, menus, waypoint identity, combat/taint and coexistence. These offline counts do not establish live rendering, live data correctness or taint safety.
