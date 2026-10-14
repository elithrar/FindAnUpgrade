# Quest identity and current availability correction

The live 0.1.1 screenshots showed an exact, named quest as “Possible quest — availability unconfirmed,” including a Questie tooltip that already identified the quest as available. The implementation confused two different facts: a reciprocal NPC starter association establishes the quest ID; it does not establish whether this character can accept it. It also discarded the current optional marker's available/complete type and replaced every provider observation with the same uncertainty sentence.

`Providers.lua` now owns a structured availability result, independent of quest identity and Forever classification. `id` and `title` remain the identified quest. `availability.state` is `available`, `active`, `ready`, `completed`, `blocked`, or `unknown`; `authority` identifies native gossip, native quest log/history/session, a current native map offer, current Questie render evidence, or a recorded constraint. A concise `evidence` label exists only when there is a meaningful current state or a specific named chain/level fact. A generic unknown state produces no boilerplate line.

The decision order is intentional:

1. Native active quests and their current objective-complete state establish “In quest log” or “Ready to turn in,” even when an older source has contradictory restrictions.
2. Exact current gossip active/ready entries establish the same states. A session-disabled quest is excluded.
3. Exact current native available gossip entries or IDs returned by `C_QuestLine.GetAvailableQuestLines(mapID)` establish “Available.” This current offer can supersede historical completion for a repeatable offer.
4. Native completion history excludes completed quests unless native repeatability or a fresh native offer permits another inspection. Repeatability alone says “Repeatable”; it does not say available now.
5. Fresh optional Questie available evidence can establish attributed “Available.” Native active/completed/disabled state still wins. Current provider evidence supersedes an older recorded faction/class/minimum snapshot.
6. Remaining static NPC associations are filtered by known faction, class, race, level and session constraints. Missing player data does not become a fabricated exclusion. Passing every known recorded constraint does not establish server availability.

The bundled exact NPC starter records now work without Questie. An optional LibQuestieDB Forever contract 3 reciprocal starter lookup supplements those identities. The addon neither modifies Questie state nor depends on Questie for startup, native gossip, native quest pins, or the bundled NPC records.

Recorded ATT `sourceQuest`/`sourceQuests` lists explicitly lack proven hard server prerequisite semantics. They may contain breadcrumbs, alternate paths, or character-dependent chains. Unfulfilled links are presented by exact named quest as “Quest chain: …,” with structured IDs retained for inspection; they do not become definitive rejection or “Available.” A completed single OR path takes precedence over a separate group. Group thresholds are counted accurately. A breadcrumb or unreadable completion cannot become a definitive hard failure. No new prerequisite claims were imported into the shipped catalogue.

## Current source evidence

Target native implementation: official Forever 1.60.1.70374, Gethe `wow-ui-source` snapshot `735496de78ebd30ce816a0637982c556987f258c`.

- `QuestDataProvider.lua:280` emits the exact quest ID in `MapCanvas.QuestPin.OnEnter`.
- `QuestOfferDataProvider.lua:77–118` filters offer pins, but `:178–185` also incorporates force-visible quest lines. A visible offer pin alone is therefore insufficient to assert availability. The adapter checks membership in the current native available quest-line list.
- `QuestOfferDataProvider.lua:456–474` associates exact quest IDs with hub offers. Their player availability is checked independently.
- Generated `GossipInfoDocumentation.lua` provides exact `questID`, `title`, `repeatable`, and `isComplete` fields. The current NPC GUID/session is required.
- Generated `QuestLogDocumentation.lua` provides `IsOnQuest`, `IsComplete`, `IsQuestFlaggedCompleted`, `IsRepeatableQuest`, and `IsQuestDisabledForSession`. Restricted or missing results remain unknown.

Optional provider inspected: the currently installed Forever Questie 12.1.0 on MONOLITH, read-only.

- `Modules/Tooltips/MapIconTooltip.lua:163–168` inserts `npcAndObjectOrder` entries exclusively from markers whose `data.Type` is `available` or `complete`.
- `MapIconTooltip.lua:205–208` publishes the grouped exact quest IDs; `:225` creates a new `_Rebuild` closure after successful collection. Alpha/throttle early returns do not produce a fresh render token.
- `MapIconTooltip.lua:506–557` formats the exact localized Complete tag or known available categories; `:560–565` attaches the exact quest ID. A localized Class/Daily/Event tag is a category, not an availability API.
- The hovered primary quest uses exact marker `data.Type`. Neighboring grouped rows require Questie's read-only localization to resolve the exact Complete or known available-category tag; known class/dungeon/etc. tags also require its exact known tag ID/name. An arbitrary non-Complete string is not interpreted as available. Missing/unreadable localization or category proof stays unknown.
- `Modules/Tooltips/Tooltip.lua:78–96` stores exact quest/starter IDs in the NPC tooltip registry. `Modules/Quest/AvailableQuests/AvailableQuests.lua:289` and `:761` register available NPC starters; item-drop and object starter types are separate and excluded from the direct NPC-offer adapter.
- `Modules/Tooltips/TooltipHandler.lua:18–66` appends the registry to the native tooltip and records its current unit/type. An additive secure post-hook checks the exact rendered unit GUID and an actual native tooltip line containing the specific Questie available/complete icon and exact colored quest-name suffix before admitting current NPC provider evidence. Header bookkeeping alone is insufficient: Questie's getter can omit quest lines, including raid suppression.

Native gossip/map proof callbacks re-read the current lists on refresh. Questie proofs retain the actual render token, marker data object, ID/type, owner and grouped entry; pooled replacement, in-place type changes, token replacement, hidden/unloaded markers, removed membership and tag mutation expire the proof. Current NPC registry evidence expires when its entry or whole registry is removed/replaced, its quest/starter/type changes, its module or profile is replaced, or its visible native tooltip switches GUID/content. A hidden native tooltip can retain the previously proved snapshot during sticky inspection; native quest-log/history/session changes still supersede it.

## Verification and limits

`tests/eligibility_test.lua` covers 39 focused Lua 5.1 regressions: exact identity without generic uncertainty; no-provider operation; active/ready/completed/repeatable/session states; recorded restrictions and unknown player context; single OR and threshold groups; breadcrumbs and alternate paths; current GUID/session gossip; fresh/removed native map offers; native precedence over contradictory provider observations; localized and unknown group tags; duplicate grouping; alpha/pool/token/type/membership lifetimes; omitted NPC render lines; registry/entry/profile replacement; restricted native text; sticky inspection of a previously proved optional NPC snapshot; and exact quest titles while native metadata is cold.

The local source probe `.work/eligibility-current-source.py` executes the actual installed Questie collection/getter implementation and full current `TooltipHandler.lua` in the offline Lua runtime. `dist/eligibility-current-source-probe.json` records its outcomes. The MapIconTooltip source SHA-256 is `2c3735d14312b86461ff1e800d05917b6811fe804204a6bd6058270256c0ebd0`; TooltipHandler is `34fcda046b4a4346decf4aac84c373a485486dda3de929e9e2bd0667757a0a7f`. The extracted collection probe replaces the later tooltip-layout closure with an inert render token, so it is a data-flow test and makes no visual claim.

Pending live checks: this patch must be tested against the user's exact NPC, minimap, and world-map screenshots; accept/abandon/turn-in and repeatable offer refresh timing; grouped localized categories; optional Questie enable/disable; native rendering, pointer transit, combat and coexistence. Source inspection and offline execution do not establish those client outcomes.
