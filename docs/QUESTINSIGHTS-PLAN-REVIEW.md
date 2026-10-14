# QuestInsights: independent review of the interactive plan

Planning only, reviewed 14 October 2026. Reviewed plan: `docs/QUESTINSIGHTS-PLAN.md`, SHA-256 `e370c2b5c7f44dd1c2c13a4f2c9a9dc09f4aa8343df39524e92e94fe102cbd2d`.

**Verdict: no remaining material planning contradiction after the accepted exact-ID deduplication repair.** This accepts a proposed contract with explicit feasibility gates; it does not establish implemented behavior, native rendering or taint safety. This review supersedes all earlier noninteractive-stack and immediate-Shift-release recommendations.

## Current interaction contract

Shift-hover opens a small vertical stack of condensed, interactive cards, one per exact quest ID. Each has compact guaranteed-item icons, a separately labeled Choose one row, native rarity colors and quantities, and money/reputation where known. Existing/unknown cards retain native skin; Modified is green and New orange. Mixed NPCs get separate card accents and a neutral outer container. Unknown IDs are not labeled verified unchanged.

The stack latches: releasing Shift does not close it during pointer transit or inspection. Source, viewport, cards/scrollbar and attributable native item/comparison tooltip geometry form the retained interaction area. Escape or leaving that area dismisses. Native item content is used rather than recreated stats. Long lists remain reachable through a bounded scrolling viewport and per-card overflow expansion; cards do not all grow to fit every reward.

## Challenges and disposition

| Challenge | Current plan and review result |
| --- | --- |
| Duplicate cards for one quest | **Repaired.** Earlier ID-plus-evidence-class wording could show an offer and candidate as two cards. Cards now deduplicate solely by exact ID; strongest current evidence controls the card, with lesser provenance retained within it. |
| Original hover ends during transit | **Addressed.** NPC/pin leave and base-tooltip hide/clear start transit checks rather than destroy captured cards. Pin release/reuse, map/world changes and interaction teardown are distinct structural invalidations. Loss of the mouseover token alone is expected when entering addon UI. |
| Accidental persistence or early close | **Addressed as a testable design.** A narrow nonblocking corridor, 250 ms outside-area grace and directional journey extension up to one second bound transit. These are provisional UX timings, not native facts. A frozen origin point cannot keep the stack alive indefinitely. |
| Escape reopening while Shift is held | **Addressed.** An opening-gesture latch requires a fresh qualified gesture/entry. Repeated minimap refresh is not a new entry. Native Escape/special-frame ordering remains a client check; no global keyboard catcher or forced map visibility is proposed. |
| Long stacks, scrolling and pooled icons | **Addressed.** All known cards/items/choices remain reachable; viewport-only wheel handling prevents map zoom leakage. Scroll/recycle invalidates the old item target. Reserved loading slots, stable placement and per-target generations prevent asynchronous data from substituting another reward under the pointer. |
| Unrelated NPC encountered in the corridor | **Addressed.** The open stack retains captured identity; a passing new hover cannot silently replace IDs. A later fresh source can open after dismissal. |
| Native tooltip ownership | **Required Stage 0 gate.** A uniquely named native-template frame is not automatically isolated from global item/comparison/battle-pet cleanup. Current plan explicitly requires a supported owned rendering/cleanup setup before shipping. |

## Distinct native ownership gate

The pinned `GameTooltipTemplate` inherits `GameTooltip_OnHide`. If `GameTooltipDataMixin:OnLoad` is invoked, it assigns global shopping tooltips and calls a global battle-pet hide; native OnHide also calls that global hide. Dedicated frames alone therefore do not prove cleanup isolation. Global GameTooltip, ShoppingTooltip1/2, BattlePetTooltip and another addon's newer content must not be borrowed, reanchored, cleared or hidden.

The pinned **`Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua`** owns one shared `self.tooltip` session. Initialize switches that session and operates on its shoppingTooltips. `Clear(tooltip)` is identity-guarded; unqualified `Clear()` clears the currently managed session, and CompareItem with missing comparisonItem calls that unqualified clear. A valid CompareItem switches/refreshes the singleton without itself clearing the previous tooltip. Cleanup must not clear a newer unrelated session. Replacing global manager tables or shopping pointers is not an acceptable shortcut.

Native inspection retains exact reward kind/index/quest ID or a matching captured item link; a bare generic ID must not erase bonus/scaled context. Native alwaysCompareItems/COMPAREITEMS rules remain meaningful after Shift release. Preview icons must not call `QuestInfoItem_OnClick`: in the pinned source it changes `QuestInfoFrame.itemChoice`. Overflow expansion only reveals information and does not select/accept a quest or choose its reward.

## Source/data boundaries remain honest

The snapshot remains 880 unchanged, 96 updated and 218 new IDs: 1,194 IDs, 998 title groups, 18 zones. Per-variant primary status is authoritative; no title-group propagation or secondary databaseNEW classification is introduced.

World-map pins expose exact IDs and native additive hover events. Plain NPC identity does not establish a complete current offer list; optional provider associations remain Possible quests - availability unconfirmed. Current gossip offers are valid only for their verified interaction/session. Native minimap exact identity remains an empirical gate, with no name/icon/proximity matching.

Explicit-ID item/money reward calls exist in pinned native code, but metadata readiness does not prove reward readiness or arbitrary unaccepted Forever coverage. Guaranteed and choice rewards stay separate; missing/restricted data is not zero. Ordinary Classic reputation amounts remain unverified, with explicit unavailable states and static estimates off by default. QuestieDB's reviewed 36-field schema has associations and static reputation, but no guaranteed/choice-item or gold rewards. It cannot fill those gaps or prove current availability.

The bounded Stage 0 checks, single-copy rename/migration plan, opt-out preservation and future-schema protection remain coherent. No all-world reward/NPC/minimap support promise is made.

## Acceptance evidence still required

Test source-to-first/last-card and icon-to-tooltip/comparison transit at every screen edge, slow/paused paths, card gaps and the scrollbar. Test both Shift keys, release while inspecting, Escape while Shift remains held, re-entry and modifier alternatives. Test long/localized titles, many cards/choices/factions, individual expansion, fractional scales and small screens. Membership must use guarded visible geometry in one normalized coordinate space: GetRect and IsMouseOver can return secrets under secret anchoring.

Test unrelated global item/shopping/battle-pet tooltips already visible, native comparison session changes, missing item data, and shutdown after another tooltip takes ownership. Test stale callbacks after dismissal/pool reuse, player-context reward changes, scroll/expansion during item hover, map closure and current-offer invalidation. Compare surfaced rewards and item variants against native offers for the same character. Native rendering, pointer flow, Escape ordering, cleanup isolation and taint/coexistence remain pending.

This pass edited only this review document. No runtime implementation, installation, candidate/source package rebuild or Library operation was performed by the reviewer.

## Pinned evidence

All Blizzard links use revision `943764493e6b16d63ded3ab304150d1f05e58b57` for Forever interface 16001 / 1.60.1.70338:

- [Native template scripts](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.xml#L4), [hide cleanup](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua#L404), [mixin initialization](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua#L960).
- [Shared comparison manager](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua#L23), [native comparison input](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua#L4), [quest-choice click side effect](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.lua#L13), [restricted geometry](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua#L193).
- [ID-scoped reward/choice helper](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua#L765), [reward readiness](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/WorldMapFrame.lua#L24), [minimap refresh](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_Minimap/Mainline/Minimap.lua#L269).
- [QuestieDB schema](https://github.com/Questie/QuestieDB/blob/e0a6eaa86f181ac99262e34126bcd2ed1a1712d6/src/meta/questMeta.lua#L16) and [Forever provenance](https://github.com/Questie/QuestieDB/blob/e0a6eaa86f181ac99262e34126bcd2ed1a1712d6/docs/forever-data.md) use the ATCF-documented revision `e0a6eaa86f181ac99262e34126bcd2ed1a1712d6`.
