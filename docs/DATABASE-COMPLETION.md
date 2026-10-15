# Quest inventory and recovery, 0.1.7

The catalog contains **5,672 exact quest IDs**. Every acquired identity remains
accounted for; membership does not establish current availability. Classification,
published rewards, recorded starter metadata and current native player data have
separate authority. No unavailable field is inferred as zero.

## Current coverage

| Field | Published or recorded quests | Unknown quests |
| --- | ---: | ---: |
| Item list, including published-empty | 5,433 | 239 |
| Quest difficulty level | 5,402 | 270 |
| XP base amount | 4,399 | 1,273 |
| Money base reward | 1,130 | 4,542 |
| Named reputation source lists | 3,224 | 2,448 |
| Starter identity of any explicit type | 5,073 | 599 |
| Starter coordinates | 4,064 | 1,608 |
| Complete currency list | 0 | 5,672 |

The patch adds 585 previously absent starter records and 45 positioned quests.
There are 4,429 quests with NPC starters, 311 with object starters and 725 with
item starters; those sets overlap. The new reciprocal relationships retain
105 class restrictions and 351 race restrictions. The remaining starter gaps
are 389 absent source fields, 200 unconfirmed identities, nine hidden triggers
and one unproven header-inheritance case (78150). The other two historical
header cases now have exact starter proof; their history remains recorded.
Portable item activation is a supported start path without a fixed NPC point.

Eighteen published reputation lists repeat the same faction name. Raw source
observations are preserved, while runtime withholds the ambiguous faction's
amount instead of selecting or adding entries. Other explicit zero/negative
reputation amounts retain their meaning. Seventy money costs are stored as
costs, never converted into rewards or zero rewards. Six source lists gained
verified explicit reputation amounts; missing XP, money and currency amounts
remain unknown. See [amount audit](REWARD-AMOUNT-RECOVERY.md).

Of the 270 unknown difficulty levels, 239 belong to historical/unconfirmed
candidates and 31 have unsupported or explicit zero source values. Era-derived
XP/reputation tables have known Forever conflicts and are not substitutes.
No supported additional positive amount was found in the inspected public
corpus, retained primary pages or completed website artifacts.

## Exact classifications and categories

All 2,919 exact IDs in the completed website selection are represented, across
42 main and 16 ancillary categories. The selection is not comprehensive
all-Forever coverage. Its 2,355 grouped titles are not an exact-ID count.
The original baseline and website agree for all 1,182 shared IDs; another
1,737 IDs acquire exact classifications. Twelve baseline IDs excluded by the
website's Side: None display policy retain their previous exact status.

The resulting 2,931 classified IDs comprise 2,367 unchanged, 176 updated and
388 new. The other 2,741 catalog IDs remain unclassified and render unchanged.
Thirty title groups mix variant statuses; no variant inherits another's New
label. Only `data/primary-statuses.json` supplies runtime status. See
[classification reconciliation](CLASSIFICATION-RECONCILIATION.md).

## Acquired reward inventory

The public Forever vs Classic index reports 5,633 exact IDs across 113 pages.
Visible name-filter queries repaired eight omitted/tied IDs, with exact
membership and hashes retained. All detail pages were acquired. Of these,
5,433 have confirmed published item lists: 2,136 item-bearing and 3,297
explicitly empty. Two hundred are explicitly unconfirmed. Historical compiled
ATT contributes another 39 IDs absent from the public index.

The catalog preserves 3,606 item occurrences, 2,623 distinct items, guaranteed
versus choose-one groups, quantities and repeated slots. Quest 682's item 4741
occurs in both groups. Quests 9324/9331 each preserve Burning Blossom slots of
20 and 10. Published source ordinals are never native quest-loot ordinals.

The completed website reward evidence was read without modifying that checkout.
All 2,919 records agree with the catalog's exact item groups, quantities and
order. The 135 retained primary pages corroborate matching public groups;
a changed snapshot does not inherit that historical verification claim.
The original reward-subset correction added 84 associations and removed 89
across 134 quests; 50 previously item-bearing quests have explicit empty lists.
The old 1,250-row scope was an importer selection, not a hard record limit.

## Starter ownership and reproduction

The earlier ATT recovery added 134 starter records and 628 positioned quests;
the 0.1.6 immutable-alias audit then recovered 9388/9389. Its other 104 mixed
starter cases retain their exact unresolved ownership evidence. The new layer
uses pinned QuestieDB Forever facts, typed reciprocal associations and exact
primary start markers. Positive generated Forever points must survive the
final artifact, restrictions remain attached and namespaced IDs stay distinct.
Existing owned global NPC positions enrich only proven starters. Two historical
Mulgore points for 7662/7663 are withheld because their changed map frame lacks
current point proof. No inherited Era position, route, objective provider or
item acquisition point establishes a fixed quest start.

[Starter recovery](STARTER-COORDINATE-RECOVERY.md),
[coordinate binding](COORDINATE-BINDING-REVIEW.md) and
[independent final data review](DATABASE-FULL-RECOVERY-REVIEW.md) record proofs,
conflict rules, adversarial probes and per-source limits. The final independent
review passed 76 assertions, including cache-free pinned regeneration and
preservation of every canonical fact and attached primary position.

`data/catalog-complete-sources.json` hashes owned normalized inputs. Raw caches,
upstream implementation, downloaded databases and client files stay outside
packages. `python tools/sync_catalog.py check` reproduces tracked facts offline;
`reparse` reuses owned caches; `refresh` acquires pinned permitted inputs before
staging, diffing and full verification. No website checkout is needed after
import. See [database sync](DATABASE-SYNC.md) for options and safe recovery.

## Remaining source and live limits

The 239 unknown item lists are the 200 unconfirmed public records and 39
compiled-only historical candidates. Static titles/rewards, cached item data,
marker metadata and HTTP absence do not establish current obtainability or
removal. Runtime requires fresh native offer/log/map proof for such candidates.
Hidden triggers are excluded from static results unless current native proof
resolves them. Missing starter/coordinate causes are retained
per ID in `data/catalog-reconciliation.json`.

Current build 1.60.1.70374's local QuestV2 is encrypted; the reader stopped
without keys or partial rows. Four available plaintext quest tables contain
zero records. WDB caches prove framed identities only; their unverified reward
payload is not decoded. Retained cache inventories are preserved independently
of a smaller later session cache. Wowhead access restrictions were respected;
no challenge or encrypted-data workaround was attempted.

Source/mocked checks do not establish current offers, player-modified base
amounts, native item comparison, physical input, rendering, scrolling or
combat/taint safety. Pending live checks remain explicit in
[validation](VALIDATION.md). No forced reload is part of installation.
