# Runtime recovery and reward-browser review

Reviewed against official Forever 1.60.1.70374, interface 16001. Source inspection and Lua 5.1 execution below are offline evidence. They do not establish native rendering, actual server availability, game CPU time or combat/taint safety.

## Concrete defects repaired

### Historical NPC records bypassed finder availability protection

Before the repair, `Providers.ForNPC(17093)` returned historical quest 9431 from the bundled starter association. With a suitable recorded faction and minimum level it had `unknown` availability, which `ResolveRows` admitted. Cached titles and rewards could not make it appear in the finder, but the NPC entry point lacked the corresponding guard.

`Providers.Resolve` now requires current native log, gossip or available-map evidence for historical/unconfirmed records and hidden trackers. Static starter records and optional Questie markers cannot supply that proof. Ordinary published exact starter associations remain inspectable without claiming server availability. Native proof is checked again when rows refresh; an expired offer cannot fall back to the old static association.

### Cold published metadata triggered catalog-wide background loads

`Catalog.Metadata` used published titles and quest levels for rendering but still required a native title before considering metadata ready. A cold default-range query consequently queued all 5,672 IDs, including historical candidates and hidden trackers. At the existing request limit this represented several minutes of background work.

Valid published exact titles and integer quest levels now satisfy readiness. Native values retain priority when available; quest-data events and level changes invalidate the cache. Minimum levels, missing values, zero levels and scaling markers never become quest difficulty. Hidden and historical records do not enter the hydration queue without current native proof.

An actual-catalog offline probe with cold native quest metadata reduced queued quest IDs from **5,672 to 31**. These remaining records lack a supported positive published difficulty. After ten modeled seconds the 31 requests were drained and the owned `OnUpdate` stopped. This measures modeled request ownership, not server responses or in-game frame time.

## Browser eligibility and ordering

The default browser requires a known start path and a useful known reward. A typed NPC, object or item starter qualifies without requiring coordinates; current native offers and logged quests can supply a missing start path. Faction-specific starters are filtered. Missing starter metadata does not become a guessed NPC, and nonfixed item starts remain valid.

All rewards can include positive verified XP, money or unambiguous named reputation, as well as items and positive named native currencies. Unknown fields, zero values, costs and reputation losses alone do not qualify. Duplicate published reputation faction names use the same withholding policy as the reward renderer. Equipment filters still require matching items. A ready native empty/zero reward set replaces the published fallback; ambiguous native item choices are not repopulated from static data.

`ZONE` sorting prioritizes exact reconciled quest-category membership, followed by level fit, title and ID. `FIT` and `LEVEL` retain their independent meanings. Category Area IDs are **not** native UI map IDs. The adapter compares localized native area names with the current native map and its bounded parent hierarchy. Missing or ambiguous matches fall back to level fit. Giver coordinates do not determine quest category. The model performs this work per query, never per hover frame.

The current pinned [C_Map contract](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua) defines `GetAreaInfo(areaID)`, `GetBestMapForUnit("player")` and `GetMapInfo(uiMapID)`. Existing location actions continue to require a validated native zone map, finite recorded coordinates, explicit user action, waypoint permission and successful native setting. Phase/conflict guards remain in the menu owner. No acceptance, completion, native protected layout or other-addon's saved data is changed.

## Regression evidence

`tests/provider_recovery_test.lua` covers thirteen scenarios: all static entry points, hidden/history restrictions, native proof and its expiry, cached-data nonproof, published metadata readiness, valid difficulty bounds, native metadata arrival, candidate hydration, idle shutdown with 5,000 published records, targeted per-quest reward invalidation, forced comparison of only the target quest's visible metadata and refusal to borrow another host's proof after an explicit association expires.

`tests/reward_browser_model_test.lua` covers eleven scenarios: NPC/object/item starts, missing starts, positive amount-only rewards, slot filters, costs/losses/zero, duplicate reputation names, native empty/zero authority, current native start evidence and expiry, named native reputation, faction qualifiers, localized parent-map category ordering, ambiguity, cycles/restricted names and one native-offer snapshot per query rather than per catalog row.

The existing complete-catalog, search-runtime and search-lifecycle suites were also executed after the model changes. Normal-quest fixtures now state their typed starter explicitly. The native metadata replacement regression invalidates its cache before simulating later data, matching the registered event path.

## Independent quest-event review

The pinned `QuestLogDocumentation.lua` confirms that `QUEST_LOG_UPDATE` has no payload; `QUEST_ACCEPTED` supplies the quest ID as its **first** argument, not a legacy log index. `QUEST_REMOVED` supplies quest ID and replay flag, and `QUEST_TURNED_IN` supplies quest ID, XP and money. `IsComplete(id)` is a boolean completion-state accessor. Objective counters are not part of QuestBrief's displayed quest progress.

The first `GetNumQuestLogEntries` result is the number of shown entries. The selected [Mainline quest-map implementation](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua), loaded with Camelot overrides by its TOC, expands headers in `QuestSearcher:SaveHeaderStates` to search all entries. QuestBrief does not alter those headers. Its bounded state owner retains known active IDs omitted by collapsed headers and confirms removal with `IsOnQuest`; provider observations seed initially hidden active IDs.

Before the event repair, an independent registered-handler probe delivered 1,000 unchanged quest-log updates: the finder performed 1,000 whole-catalog metadata invalidations and 125 queries. The same number while hidden still performed 1,000 invalidations.

After the repair, eight independent registered-handler probes produced:

| Input | Finder queries | Whole/targeted metadata invalidations | Per-quest reward invalidations |
| --- | ---: | ---: | ---: |
| 1,000 unchanged visible log updates | 0 | 0 | 0 |
| Completion flip followed by unchanged updates | 1 | 0 | 1 |
| 1,000 duplicate acceptance signals | 1 | 0 | 1 |
| 1,000 duplicate abandonment signals | 1 | 0 | 1 |
| Header collapse and expansion | 0 | 0 | 0 |
| Removal plus turn-in sequence | 1 | 0 | 2 |
| Reacceptance after turn-in | 1 | 0 | 1 |
| 2,000 quest signals with all owned inspection UI hidden | 0 | 0 | 0 |

Hidden signals also caused zero `GetInfo`, `IsComplete` or `IsOnQuest` calls and left no owned update script. A removal/turn-in pair can invalidate the same small reward snapshot twice while sharing one deferred query; unrelated metadata remains ready. These counts establish offline event ownership and bounded work, not engine event ordering or game CPU time.

Further adversarial checks found and repaired three interaction defects:

- The reverse dependency index initially passed numeric prerequisite arrays through a helper for `{id=...}` rows, leaving the index empty. Exact numeric IDs and bounded transitive traversal now allow an out-of-range prerequisite, or its verified exclusive alternate, to unlock an in-range quest. Both cases passed independently.
- NPC rows could inherit a native gossip offer for a different NPC with the same quest ID. Static NPC rows now retain their exact NPC identity; native offer proof is scoped to it. An expired explicit association does not borrow a separate global offer. The existing 39-case eligibility suite passed after this repair.
- A newly unlocked NPC card appeared during pointer transit but never requested its cold rewards. The hover owner now requests newly added exact IDs with its existing deduplication and generation guards. An independent registered-event probe measured one card refresh, one new quest reward preload and one item preload; repeating the event made no additional requests.

The hover probe also delivered 1,000 unchanged log updates with zero card refreshes. A completion-state change updated eligibility without rebuilding a compact hover card whose visible content did not change. A native map offer's expiry removed a conflicting quest with no recorded start path; a fresh offer restored it, and 1,000 unchanged offer updates caused zero finder queries.

## Remaining client checks

- Observe zone priority and fallback on actual Forever maps, including subzones, dungeons, localization and zone changes with the finder open.
- Observe native availability, scaled difficulty and late reward metadata for the remaining unsupported static levels. A cache request or a published page is not live availability proof.
- Inspect new and modified exact-ID tinting and amount-only cards, then repeat pointer transit, scroll, comparison-tooltip ownership and dismissal with Questie and native tooltips.
- Exercise explicit location actions and menu dismissal in combat. Offline mocks and client source cannot certify absence of taint.
- Measure the complete finder workload in the client before making game CPU or memory claims.
