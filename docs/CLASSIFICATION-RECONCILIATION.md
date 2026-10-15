# Classification and primary quest categories

The addon now carries every exact classified variant in the completed website
snapshot. The website checkout is an acquisition input only; normal validation
and catalog refresh use the owned frozen inputs below.

## Sources and regeneration

- `data/classification-source.json`: normalized exact variants, primary category
  membership, assigned faction, and all 65 deliberately excluded website variants.
  It retains byte lengths and SHA-256 receipts for the completed
  `quests/provenance/forever-confirmed-chart-data.json` and
  `quests/provenance/forever-confirmed-change-ledger.json` inputs. Those upstream
  snapshots were read without modifying the website checkout.
- `data/classification-baseline.json`: the original 1,194-ID authority, preserved
  byte for byte with SHA-256
  `64017ae90fe4e16323044064b0ac5ba6102fba147446660fb1fd863eaf8e9ae5`.
- `data/primary-statuses.json`: reconciled exact-ID authority. Runtime tinting
  still reads only its generated per-ID labels; title labels never supply an ID's
  status.
- `data/classification-reconciliation.json`: all 58 category comparisons, faction
  projections, the 30 mixed-status title groups, and retained website exclusions.

From the repository root:

```text
python tools/import_classifications.py --check
python tools/generate_data.py --check
```

Omit `--check` to regenerate owned outputs from the normalized source and baseline.
For an explicit replacement with a completed website snapshot, use
`python tools/import_classifications.py --website-root <checkout>` first, inspect
the source receipts and reconciliation, then regenerate the Lua table and run
the normal verifier. No source checkout is needed after import. A changed shared
ID status, unexplained missing baseline ID, duplicate primary category, wrong
aggregate, or excluded variant re-entering website totals fails validation.

The website's 42 main and 16 ancillary categories are a published selection, not
a comprehensive inventory of all Forever quests. Zephras Isle's category remains
partial. Some categories are cities, subzones, or transit categories. Abyssal
Sands is retained as an explicitly empty category. A primary category and its
Wowhead source zone ID are not a giver coordinate or a native UiMapID.

## Reconciled counts

| Counting unit | Unchanged / Same | Updated / Modified | New | Total |
| --- | ---: | ---: | ---: | ---: |
| Website exact quest IDs | 2,359 | 176 | 384 | 2,919 |
| Website titles grouped within category | 1,846 | 155 | 354 | 2,355 |
| Retained website-excluded baseline IDs | 8 | 0 | 4 | 12 |
| Addon classified exact IDs | 2,367 | 176 | 388 | 2,931 |

All 2,919 website IDs already exist in the broader addon catalog. The original
baseline and website share 1,182 IDs, with no exact-ID status disagreements.
The reconciliation supplies classifications for another 1,737 website IDs.
Previously unknown catalog IDs remain unknown; catalog membership, reward data,
faction assignment, or a matching title cannot classify them.

Representative category comparisons use **Unchanged / Updated / New**:

| Primary category | Exact quest IDs | Grouped titles |
| --- | ---: | ---: |
| Dun Morogh | 39 / 1 / 20 | 37 / 1 / 16 |
| Wetlands | 24 / 16 / 25 | 22 / 12 / 24 |
| Elwynn Forest | 44 / 3 / 26 | 44 / 3 / 25 |
| Duskwood | 86 / 10 / 3 | 66 / 7 / 3 |
| Zephras Isle | 0 / 0 / 109 | 0 / 0 / 96 |

Each website ID occurs in exactly one primary category in this snapshot. Equal
titles can occur in different categories, and remain different groups. Matching
titles within a category are grouped only for comparison totals: the highest
remaining status wins (`New > Updated > Unchanged`). Thirty groups contain
different exact-variant statuses; none of their older variants inherit New.

Faction filters first retain variants (`Alliance + Both`, `Horde + Both`, or only
`Both` for Neutral), then regroup titles and recalculate status. Alliance has
1,979 exact IDs, Horde 1,765, and Neutral 825. Both-faction IDs intentionally
overlap the Alliance and Horde views; adding those views double-counts Neutral.
For example, Desolace's **Khan Hratha** is a New title in the unfiltered/Horde view
because of ID 96222, while the Alliance view retains only Updated IDs 1380/1381.

## Twelve retained exclusions

The website excludes these exact variants because their detail pages explicitly
say **Side: None**. This is a display/faction policy, not evidence that their
previously verified primary status is wrong or that they are obtainable now.
They retain their old exact-ID tint classification, with `websiteDisplay: false`,
unknown faction, and the source exclusion reasons. They do not enter the 2,919-ID
website membership or any website category/faction total.

| ID | Title | Primary category | Retained status |
| ---: | --- | --- | --- |
| 785 | A Strategic Alliance | Durotar | Unchanged |
| 787 | The New Horde | Durotar | Unchanged |
| 908 | Amongst the Ruins | Ashenvale | Unchanged |
| 934 | Crown of the Earth | Teldrassil | Unchanged |
| 1099 | Goblins Win! | Thousand Needles | Unchanged |
| 1174 | Gnomes Win! | Thousand Needles | Unchanged |
| 7961 | Waskily Wabbits! | Elwynn Forest | Unchanged |
| 7962 | Wabbit Pelts | Elwynn Forest | Unchanged |
| 95771 | A Taste of Darkness | Elwynn Forest | New |
| 95816 | Sign Me Up! | Redridge Mountains | New |
| 95819 | Sign Me Up! | The Barrens | New |
| 98447 | The Valor Family | Duskwood | New |

Applejack Still 91736 is now classified New. Ashenvale variants 79090 and 79098
are now classified Unchanged. The matching numeric count of New titles in some
old/new category comparisons therefore does not establish matching membership.

## Shipped representation and validation boundary

`QuestBrief/Data/Quests.lua` carries `statusById`, `categoryById`, 58 compact
`categories` summaries, and a distinct `websiteExcludedById` table for the 12
retained exclusions. The membership table maps exact IDs to category indices;
it adds no per-hover scans, timers, or callbacks. Category summaries include
separate exact-ID and title-group status counts. `sourceZoneID` is explicitly
the upstream zone identifier, never a location-action target.

`tests/data_test.py` compares every shipped status and membership, every category
total, mixed variants, faction regrouping, source receipts, baseline exclusions,
and deterministic standalone generation. It rejects conflicting/shared statuses
and duplicate categories. These are offline data/Lua checks. They do not prove
native rendering, beta quest availability, input behavior, or combat/taint safety.
