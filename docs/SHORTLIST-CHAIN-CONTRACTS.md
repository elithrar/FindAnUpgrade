# Shortlist, chains and comparison contracts, 0.1.13

Target: official Forever 1.60.1.70374, interface 16001. Native source revision:
`735496de78ebd30ce816a0637982c556987f258c`. Source inspection and mock execution
are distinct from observed client behavior.

## Native controls and input

`UI:Tab` owns the Quests/Shortlist tabs; Options uses one scrolling window.
The tabs retain the installed XPIsland-style
owned Button, native tooltip edge, 12-unit text and one-unit active underline.
The sidebar remains 476 by 680, with a common 16-unit control inset. Cards are
content-measured; the 24-unit star target reserves title/badge space and the
reward baseline follows the measured title. Icons retain their numeric and
rarity roles. All game textures remain runtime references, not bundled art.

The [native favorite template](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSharedTemplates.xml#L165)
uses `auctionhouse-icon-favorite` and `auctionhouse-icon-favorite-off`, 20 by 18.
The [native favorite state implementation](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSharedTemplates.lua#L779)
swaps this pair on one normal texture. Its inspected source SHA-256 is
`cc41ec3d23e4be14d3e117f5403e1e6310e52f698d8c9c0ced8386a4ed5794b9`.
Version 0.1.13 follows that construction at 17 by 15.3, retaining the 24-unit
hit target. The prior extra foreground outline is removed. An offline texture
inspection used Gethe/wow-ui-textures revision
`d23deaf8f44a7d280dc974a5c9d5321c013db59b`; alternative ReputationStar,
PetJournal, FriendsListFavorite and installed addon candidates offered no
better paired silhouette. The chosen pair retains slight antialias fringe
differences. Source and offline resampling do not prove exact final pixel-alpha
contour equality or native visual acceptance. No extracted game art ships.

[BuildDocumentation.lua:75](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/BuildDocumentation.lua#L75)
declares `IsMacClient`; the Windows discriminator is at line 112.
[InputDocumentation.lua:87](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/InputDocumentation.lua#L87)
declares `IsControlKeyDown`, with `IsMetaKeyDown` at line 148.
[UI.xsd:442](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_SharedXML/UI.xsd#L442)
declares key-down/up scripts. [SimpleScriptRegionAPIDocumentation.lua:365](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua#L365)
declares additive `HookScript`; [UITimerDocumentation.lua:11](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua#L11)
declares `C_Timer.After`. Native InputBox focus gain highlights text; focus loss
clears highlighting. No selected-range getter is invented.

Copy records the focused field's valid platform copy chord, preserves native
processing through key-up, then defers dismissal. Generation, revision, owner,
text, focus and visibility guards reject stale work. A user-selected subrange
uses the same native gesture. Any subsequent selection/edit/focus/owner change
cancels pending dismissal. This detects intent, not OS clipboard success.
Direct `CopyToClipboard` is not called. Engine-internal copy ordering and
physical Windows/Mac copying remain unobserved; tests establish callback and
ownership behavior only.

## Comparison ownership

The existing owned native comparison-manager clone calls
`C_TooltipComparison.GetItemComparisonInfo` and `GetItemComparisonDelta`.
[TooltipComparisonManager.lua:148](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua#L148)
and its paired-hand branches own ring/trinket and two-hand results. Equipment,
comparison-CVar and exact relevant item-data changes invalidate the active
inspection. Cold retries and late revival are bounded; duplicate or unrelated
item events cannot create a retry flood. Physical client output is unobserved.

## Prerequisite evidence

`data/catalog-chain-records.json` owns exact normalized groups, typed relations,
field provenance, source receipts, override evidence and omissions. The pinned
[QuestieDB Forever corrections](https://github.com/Questie/QuestieDB/blob/36ca1ca86f6c1838de479c7c7452eb0a57d5c135/src/corrections/Forever/foreverQuestFixes.lua)
are checked against the same pinned release's final composed Baked artifact.
Authored source SHA-256:
`6c70ec8c17a116ab141ad930c4a7095fabcd25493af04b31f146a937a2baa5fe`.
The source grant does not change the ownership of game facts or third-party
datasets; no Questie implementation or raw source is bundled.

Coverage is 3,694 of 5,672 catalog IDs, with 247 verified prerequisite groups
and 767 verified typed relations. Inherited artifact and ATT links retain soft
provenance. Three self-referential source fields (1516, 1519 and 8414) are
withheld with evidence. Strong verified optional-breadcrumb evidence overrides
11 weaker ATT mandatory groups without erasing their original receipts.

All/any/count use three-valued completion. Missing prior metadata, optional paths,
unknown completion, conflicts and malformed groups cannot prove a lock. Repeated
completion is not final completion without known nonrepeatability. Current native
log/gossip offers take precedence; satisfied known prerequisites alone do not
prove every server condition. No title-group inference, Classic fallback,
account-completion substitution or fabricated zero is used.

`Chains` owns the reverse index per catalog identity. Disclosures cap at 32
entries/depth 8, label group owners and thresholds, avoid ancestor-return cycles
and scroll at 320 units. Search and hover share affected-dependent invalidation.
No per-row ticker or full-catalog scan is added to idle updates. Incomplete
Forever coverage and actual server availability remain explicit limitations.
