# Finder and tooltip review — 2026-10-15

## Evidence

Reviewed the five hover-preview screenshots, the filter-dropdown screenshot,
and the five finder screenshots (including the website row reference),
materialized under `.work/ui-feedback/`. The screenshots establish the reported
appearance and controls, not the cause of an engine event.

The installed XPIsland and AsTheCrowFlies constructors use native
`DropdownButton` / `WowStyle1DropdownTemplate`, radio menu descriptions, owned
menu fonts and additive focus cleanup. The matching Forever 70374
[`DropdownButton.lua`](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Menu/DropdownButton.lua)
opens on mouse-down; native menu management owns outside-click dismissal.
Regenerating a menu description explicitly reinitializes an open menu without
closing it. An unsupported rendering explanation was therefore insufficient.

## Finder changes and regression

The previous finder used fixed 118-pixel item chips with truncated names,
reserved three footer columns even when values were unavailable, and repeated
availability/usability diagnostics. The revised rows place quest information
and known amounts on the left and 28-pixel reward icons on the right. Guaranteed
and choose-one groups remain separate, with quantities and native rarity borders.
Full item details and comparison tooltips remain on hover. Class usability
uncertainty appears on the owned item tooltip instead of on every result.
Rows measure visible text and reward rows; absent amounts create no empty cells.
Typed item/object starters retain their identities in location labels and copy
actions. Missing coordinates never create a waypoint.

Current-zone ordering uses the model's classification-category membership and
native zone context. It does not infer a quest's zone from its giver position.
The default is **Current zone**, followed by level fit; **Level fit** and
**Quest level** remain explicit alternatives. Unknown mapping falls back to level
fit. Background zone events update the ordering after an open menu is released.

A reproducible closure path was found in `Search.lua`: registered background
`QUEST_LOG_UPDATE`, equipment, spell, skill and world/level events called
`Changed()`, which immediately called `CloseMenu()`. They now mark the results
dirty without closing the menu; the scheduler defers layout until native menu
release. User edits, option selection, scrolling and owner dismissal still close
menus deliberately. No mouse-up toggle or custom global-click handler was added.

The focused Lua regression executes the pinned native mouse-down handler, opens
both filter menus, delivers background events, selects an option and exercises
deliberate/owner dismissal. Against the preceding `Search.lua`, it fails with
`QUEST_LOG_UPDATE dismissed native menu`; against the fix, it passes. The
before/after receipt is `.work/ui-tooltip-review/dropdown-regression.json`.

## Quest and metadata event ownership

`QuestState.lua` now owns the four quest-state events. The Forever 70374
[`QuestLogDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)
declares `QUEST_ACCEPTED(questId)`, `QUEST_REMOVED(questID, wasReplayQuest)`,
`QUEST_TURNED_IN(questID, xpReward, moneyReward)` and payload-free
`QUEST_LOG_UPDATE`. Acceptance uses its first exact ID, with no legacy log-index
argument. Explicit events de-duplicate by quest and semantic event. Generic log
updates compare known membership, completion flags and current native offers.
Objective counters are not displayed by QuestBrief and do not invalidate its UI.

The active-quest snapshot is bounded to 512 identities. Because collapsed headers
hide entries from `GetInfo`, previous IDs are retained until `IsOnQuest` confirms
their removal. Explicit acceptance and the provider's existing active-quest reads
seed missing identities. No header is expanded or changed. Hidden event bursts
only mark the snapshot stale; opening a view captures current state. They perform
no native log/offer scans, catalogue queries, requests or rendering.

Search invalidates native reward/usability snapshots for changed quest IDs only.
It follows reverse prerequisite, alternate-prerequisite and verified exclusive
chains, including alternatives outside the selected level range. Events for an
unrelated out-of-range quest do not query the browser. Hover independently checks
its source and known dependencies, then compares visible fields before layout.
Level, zone, equipment and skill context remain separate from quest progress.

Quest metadata callbacks compare only the affected quest's title/difficulty and
relevant reward fields. Repeated unchanged callbacks do not query or render; a
new native level can still bring a quest into range. Out-of-range reward caches
are marked dirty for future filter changes. Item callbacks compare readiness,
name, link, rarity, levels, slot and texture; unchanged callbacks retain the same
cache object. Hidden metadata callbacks mark only their target stale without
reading native metadata. Tooltip-data events retain their separate inspection
owner and lifecycle.

Tracked regressions are in `tests/quest_state_test.lua`. Independent operation
counts in `.work/final-state-adversarial/operation-counts.json` and
`.work/runtime-recovery-review/event-metrics.json` establish:

| Input | Previous behavior | Revised behavior |
| --- | --- | --- |
| 200 unchanged visible quest-log events | 200 queries, renders and catalogue invalidations | Zero |
| Real membership/completion event burst | Broad cache invalidation | One coalesced query and targeted invalidation |
| 100 unchanged out-of-range quest-data callbacks | 100 full queries/renders | Target metadata comparisons; zero queries/renders |
| 100 identical item callback pairs | Repeated full queries | Zero queries/renders/cache replacements |
| Actual item readiness/slot/rarity change | Repeated callbacks rebuild | One query for the changed relevant state |
| 2,000 hidden quest-state events | Hidden broad invalidation | Zero native log reads, queries, clears or active updater |

Fresh native proof checkers take precedence over recorded proof fields. An expired
checker cannot fall back to an older raw proof. NPC proof is restricted to the
matching current gossip NPC; the finder can separately consume current native map
or gossip availability without inventing a giver association.

## Independent review

The separate native-tooltip implementer reviewed the finder interaction and found
an unlabeled guaranteed currency when mixed with choose-one rewards; this was
fixed. The runtime/source reviewer independently found that item/object names
could be copied through an action labeled “Copy NPC name”; copy labels now follow
the verified starter type and unknown types disable that action.

The finder reviewer separately examined the native-tooltip implementation and
reported asynchronous reward invalidation, same-title variant identity,
classification/title duplication, owner/generation checks and native cleanup
geometry. Those findings and fixes belong to the native-tooltip workstream.
Re-review of the fixes included three independent Lua 5.1 failure probes:
reentrant dismissal during `AddLine`, reentrant dismissal during `Show`, and a
quest becoming completed during native preview. Each leaves the original native
NPC/addon text intact and closes the stale inspection. The probe and receipt are
under `.work/ui-tooltip-review/native-failure-probes.*`.

## Validation boundary

Focused source execution covers search filtering/scheduling, virtual row reuse,
scroll geometry, long title access, native item/comparison lifecycle, typed
location actions and the menu event regression. These checks do not establish
native glyph rendering, physical click timing, tooltip cleanup height, combat
taint safety or in-game CPU. Targeted client acceptance remains necessary for
the reported dropdown click, compact appearance at Matt's actual UI scale,
tooltip-to-inspector pointer transit and native tooltip cleanup geometry.
