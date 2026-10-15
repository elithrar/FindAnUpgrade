# Quest inventory and reward reconciliation, 0.1.6

The old 1,250-quest catalog was a reward-association subset, not a quest
inventory. Its importer required a nonempty direct authored item list and a
compiled pair intersection, then discarded rewardless rows. There was no hard
1,250-row limit. This patch separates quest identity, published reward lists,
historical metadata and native player data.

The 0.1.5 recovery adds 134 source-backed starter records and 628 coordinate
records to the 0.1.4 baseline. It preserves faction-specific resolver branches,
explicit starting items and coordinate ownership. A standalone incremental
acquisition/import/sync workflow is documented in `DATABASE-SYNC.md`.

The 0.1.6 patch audits all 106 previously mixed-starter coordinate gaps and
recovers two exact quests, 9388/9389, with six owned points each. Singleton
quest declarations bind each immutable coordinate alias to its NPC; the target
quests reference those same aliases in fresh-destination appendGroups calls.
The other 104 cases remain unknown: 60 unpaired literal lists, six ambiguous
faction branches and 38 without direct coordinate fields. Source expressions,
anchor lines, frozen scope and dispositions are retained in the hashed metadata
and reconciliation report. This supersedes the earlier review conclusion that
no actionable coordinate recovery remained. See `COORDINATE-BINDING-REVIEW.md`.

## Acquired scope

The ordinary public Forever vs Classic index with its visible `all` option
reports 5,633 exact IDs across 113 pages. Tied sorting duplicated eight IDs and
omitted eight during pagination; visible name-filter queries repaired the
membership. Every repaired ID and index source hash is retained. All 5,633
detail pages were collected, with zero fetch failures. Earlier site-task pages
were reused read-only; that checkout was not modified.

The public index includes 200 explicitly unconfirmed records whose item lists
remain unknown. There are 5,433 confirmed published lists: 2,136 item-bearing
and 3,297 published-empty. Historical compiled ATT contributes 39 additional
IDs absent from the index. The union contains **5,672 IDs**, including all
707 exact identities in the current 70374 quest cache, all 1,194 approved
classification IDs, and the earlier catalog. Authoring-only candidates absent
from these current/public/compiled identity sources are separately enumerated;
they are not silently accepted as currently available quests.

The output preserves 3,606 item occurrences, 2,623 distinct items, guaranteed
versus choose-one groups and explicit quantities. Quest 682's item 4741 occurs
in both groups. Quests 9324/9331 each list Burning Blossom in two guaranteed
slots, quantities 20 and 10; both source slots remain separate. These source
ordinals are never treated as native quest-loot ordinals.

The correction changes 134 old catalog quests: **84 quest/item associations
added and 89 removed**. Fifty previously item-bearing quests have published
empty item lists. The earlier site-task scope independently primary-checked
85 affected quests; the remaining corrections rely on the newly collected
public source. The frozen 135 retained primary pages agree with every matching
public group/quantity list. Two old rows, 9522/9536, lack public reward evidence
and now remain explicitly unknown rather than retaining unverified items.

## Field coverage and authority

| Field | Recorded/published quests | Unknown quests |
| --- | ---: | ---: |
| Item list, including published-empty | 5,433 | 239 |
| Quest difficulty level | 5,402 | 270 |
| XP base amount | 4,399 | 1,273 |
| Money base amount | 1,130 | 4,542 |
| Named reputation base amounts | 3,218 | 2,454 |
| Giver identity of any explicit type | 4,488 | 1,184 |
| Giver coordinates | 4,019 | 1,653 |
| Complete currency list | 0 | 5,672 |

Giver records include 4,040 quests with NPC starters, 295 with object starters
and 543 with item starters; those sets overlap. Explicit exact quest
`qg`/`qgs`, typed `provider`/`providers`, starting-item `qs`/`qss` fields and
compiled faction-qualified resolver branches supply the associations.
Nested objective providers are not starters. Item/object IDs never enter the
NPC hover index, and their item-source coordinates are not promoted into a
giver location. Separately recorded NPC positions enrich only already proved
starter IDs. Retained primary start markers preserve typed NPC/object names;
their AreaTable coordinates are not guessed into UI-map IDs.

Authored metadata is parsed independently of rewards. Unsupported restriction
expressions preserve literal giver facts but require separately normalized
compiled restrictions before static eligibility is usable. This recovers 792,
1049 and 8767. Contradictory metadata remains rejected across later duplicate
occurrences. Conflicting current/public versus historical faction facts for
9339, 9365 and 9368 suppress static eligibility until current native offer/log
evidence resolves the interaction. Recorded metadata never proves availability.

Current native reward readiness owns its item set, including an empty set or
ambiguous choices. The search model cannot reintroduce published choices around
that guard. Native item metadata caches do not own another quest's group or
quantity. Published XP/money/reputation fill unknown fields and show `(base)`;
native player amounts take precedence. A partial native major-faction result
does not erase other published ordinary factions. Equal reputation amounts or
source ordering are never used to invent faction IDs. Missing fields are not
displayed as zero. Classification still uses only `data/primary-statuses.json`.
The exact-name lookup uses the current pinned
[70374 reputation contract](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/ReputationInfoDocumentation.lua),
which supplies optional faction data with its name; unavailable identity stays
unresolved.

## Reproduction

`data/catalog-complete-sources.json` binds all normalized inputs by SHA-256.
`tools/generate_catalog.py --check` reproduces the canonical reconciliation and
generated Lua from those inputs without network access. The source package
includes normalized facts, receipts and unknown-field accounting, not raw pages
or client files. Each public detail row carries its exact URL, byte count and
SHA-256; ATT dependencies include map/race constants and their receipts.

To acquire a fresh public snapshot, use ordinary allowed pages:

```powershell
python tools/sync_catalog.py check
python tools/sync_catalog.py refresh
```

The ATT acquisition roots retain `ACQUISITION.json` at revision
`d75383ccdbff1208b87cf4024fa425c0825a7ad6`; raw source acquisition is described
in `DATABASE-SYNC.md`. The owned normalized primary/client evidence is reused
by default, without another checkout or game installation. Optional raw-cache
overrides read existing files only. A changed snapshot requires reconciliation
rather than
silently claiming the historical 135-page check still covers new records.

The collector checks the actual domain's robots policy, identifies itself,
uses bounded requests and stops on access/rate restrictions or challenges.
Forever vs Classic allows ordinary quest pages but disallows `/api/` and
`/search`; neither restricted route is used. Wowhead returned a verification
challenge and its policy disallows GPTBot, so this pass made no new Wowhead
requests and performed no challenge workaround.

## Current client investigation and remaining checks

The installed build is 1.60.1.70374. A read-only, offline local-CASC reader
rejected encrypted QuestV2 (FileDataID 1139443), without keys or partial rows.
Current plaintext QuestV2CliTask, QuestPackageItem, QuestObjective and QuestHub
tables contain zero records. The current WDB cache supplies 707 framed exact
identities; its reward payload layout is not verified and is not decoded into
invented rewards. These files cannot establish complete starters/rewards.

All 5,433 confirmed public item lists are accounted for as published; the
remaining 239 candidates are 200 explicitly unconfirmed public records and 39
compiled-only URLs that return 404. None is present in the 707-ID native cache.
They are not asserted to be current obtainable Forever quests. The finder
requires current native offer/log/map availability to admit an unconfirmed or
historical candidate. A cached title, reward or item alone is insufficient.
HTTP absence and explicit placeholder labels do not prove removal from the game.

The 1,184 remaining starter gaps partition into nine declared hidden triggers,
200 unconfirmed identities, three library quests with unproven parent-header
starter inheritance, and 972 without materialized starter metadata in the
inspected pinned sources. Item starts are recovered content; missing fixed
activation coordinates are distinct from missing NPC metadata. Per-ID coordinate
causes distinguish those item starts, mixed/multiple starters without owned
points, unresolved starters and absent source positions. This is a bounded
source inventory, not a claim that no further source can ever add data.

`data/catalog-reconciliation.json` enumerates every missing field, historical
ID, source disagreement and excluded candidate. This completes accounting of
the acquired inventory; it does not claim every official Forever quest or
every giver/amount is independently verified. No new native rendering or taint
verification was performed. Live checks remain for published/native transitions,
current class-filtered choices, source-empty quests, ordinary reputation with
player modifiers, NPC cards, scrolling/tooltips and combat/coexistence.
