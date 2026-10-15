# Notices

QuestBrief's original implementation, tests, tooling and documentation are copyright (c) 2026 Matt Silverlock and licensed under BSD-3-Clause. The complete license is in [LICENSE](LICENSE). This grant does not license third-party software, artwork, fonts or source datasets.

Font validation, settings, native-control presentation and release tooling follow patterns from [XPIsland](https://github.com/elithrar/XPIsland), copyright (c) 2026 Matt Silverlock, BSD-3-Clause. Its complete copyright, conditions and disclaimer are preserved in [XPISLAND-LICENSE.txt](XPISLAND-LICENSE.txt). Owner-authorized [AsTheCrowFlies](https://github.com/elithrar/AsTheCrowFlies) conventions also informed the font and UI components; its separate repository and assets are not included or relicensed by QuestBrief.

Blizzard textures, atlases, controls and game fonts are referenced from the installed client. No Blizzard source or artwork is bundled. Expressway is selected only through an installed LibSharedMedia registration; no font files, LibSharedMedia or LibStub implementation are bundled. Their providers retain their own licenses.

Questie and QuestieDB are optional installed runtime providers. QuestBrief reads exposed quest identities and associations without bundling their code or database. Their separate packages retain their own licenses.

The bundled classification table contains only exact quest IDs and normalized primary status labels from the user-approved version-1 evidence. The source package preserves that extract's identity, version and mapping rules in `data/primary-statuses.json` and `docs/PROVENANCE.md`. The original dataset is not included, and no third-party redistribution license is inferred for it. QuestBrief's BSD-3-Clause grant covers the extraction/generation code, not rights in underlying game content or source evidence.
## Bundled reward catalogue

`Data/Catalog.lua` contains numeric quest/reward/giver/coordinate facts and short
identification labels. Historical giver/restriction metadata is derived from ATTWoWAddon/AllTheThings at commit
`d75383ccdbff1208b87cf4024fa425c0825a7ad6`, under its MIT license. The complete
copyright, permission and warranty notice is in `Data/ATT-LICENSE.txt`.

The ATT source snapshot targets `1.60.1.69893`; QuestBrief targets official Forever
`1.60.1.70374` / interface `16001`. Public item groups, quantities, base amounts
and identification labels come from the explicitly labelled Forever columns of
[Forever vs Classic](https://www.forevervsclassic.com/quests), collected on
2026-10-15. Previously retained exact Forever Wowhead pages independently
corroborate 135 records; no new Wowhead requests were made for this pass.
Only factual numeric fields and short identification labels are bundled, with
URL/SHA-256 provenance in the source package. Raw HTML, quest prose, website
scripts, artwork and client files are excluded. The repository's BSD license
does not license underlying game content or third-party source evidence.

Published facts and current native player rewards are separate. Missing fields
remain unknown; a published empty item list is explicit. Native data takes
precedence when ready. Current availability and live behavior are not established
by these sources. Classification remains a separate exact-ID source.

Matching preferred source, source-file hashes and deterministic generation tools
are in the repository's `data/catalog-complete-source.json`,
`data/catalog-complete-sources.json`, `data/catalog-reconciliation.json`,
`data/catalog-coverage.json`, `tools/import_complete_catalog.py` and
`tools/generate_catalog.py`. No ATT runtime, artwork, lore or raw harvest outputs
are included. Original QuestBrief code retains the repository's BSD-3-Clause
license; this attribution does not claim BSD authorship of the ATT-derived data.
