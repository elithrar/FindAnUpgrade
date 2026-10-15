# Weapon search and copy contracts

Contract and implementation plan for the post-0.1.10 feedback iteration. This records source inspection,
not native-client execution. The target is official Forever 1.60.1.70374,
interface 16001, Gethe revision `735496de78ebd30ce816a0637982c556987f258c`.

## Weapon-type search

`SearchModel:Query` currently matches quest title, exact quest ID and the names
of reward items that survive slot, player and usability filtering. The new match
belongs at that same filtered-item point: a sword excluded by the Head filter
must not cause a different head reward to match `sword`.

The pinned [C_Item contract](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua)
declares localized item type and subclass text from both reads:

| Read | Type / subclass text | Class / subclass IDs |
| --- | --- | --- |
| `C_Item.GetItemInfo` | returns 6 / 7 | returns 12 / 13 |
| `C_Item.GetItemInfoInstant` | returns 2 / 3 | returns 6 / 7 |

Both may return nothing; their arguments are allowed when untainted. The
existing search uses owned numeric item IDs. Full info remains gated on
`IsItemDataCachedByID(id) == true`. Instant info supplies available subclass
evidence while names, links and full metadata are cold. Neither call proves
player eligibility or item usability, and the search change must not replace
the existing Character/Providers/Ranking checks.

The pinned [item constants](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemConstantsDocumentation.lua)
identify weapons as class 2, with Guns 3, Sword1H 7, Sword2H 8, Wand 19, and
the other explicit weapon subclasses. Localized subclass text already makes
`gun` match `Guns`, `sword` match either sword subtype, and `wand` match `Wands`
on an English client. No title-based classification or guessed item type is
needed. If English singular aliases are provided, derive them only from these
verified class/subclass pairs, never from item names. Unknown IDs receive no
alias.

Store readable `itemType`, `itemSubType`, `classID` and `subclassID` with the
existing `SearchModel.cache[id]` row. Precompute only stable normalized text;
do not introduce a second catalogue-wide index or per-query native subclass
scan. Existing cache lifetime is bounded by the owned catalogue/reward item
IDs. `Search:ItemData` must compare the new search fields along with the
existing visual fields, so metadata arriving without a name/icon change still
marks relevant rows dirty. Hidden callbacks invalidate without hydrating.
Matching `ITEM_DATA_LOAD_RESULT` / `GET_ITEM_INFO_RECEIVED` events retain the
existing owned request and relevance rules; no new event subscription is
necessary.

Pending subtype evidence stays absent. Do not label unknown items as weapons,
show a false match, bypass slot/class restrictions, or infer missing data as
zero. A later matching item callback must recover the match.

## Copy actions

All current context-menu actions enter `Search:Copy(value)`: coordinates,
quest ID, starter name and the exact Forever Wowhead URL. The existing owned
EditBox is the appropriate fallback. Reuse it, set the requested text, focus
it and call `HighlightText()`; Enter/Escape hide it, closing the finder hides
it, and hide clears keyboard focus. Never write to chat or simulate Ctrl+C.
Copy is explicitly user-initiated and does not modify a waypoint.

The pinned [EditBox contract](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua)
declares `HighlightText(start=0, stop=-1)`, selecting all text by default.
`SetFocus` checks the frame's ScriptedInput forbidden aspect. This is an
addon-owned ordinary EditBox; Blizzard frames are not repurposed.

A global `CopyToClipboard` appears in the pinned native
[TooltipUtil.DebugCopyGameTooltip](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua).
That debug implementation does not establish an addon-callable contract or
caller privileges. The inspected System, Platform, FrameScript, GameUI, Glue,
UIShared, UIManager and Console generated contracts expose no clipboard
operation. Therefore direct clipboard copying is **not verified for addons on
the supported client**, and the addon must not call or probe that debug global
or claim success. The user copies the selected text with Ctrl+C through the
native EditBox. Keep the dialog instruction short (`Ctrl+C to copy`); explain
this engine boundary in documentation rather than every menu label.

The working XPIsland and AsTheCrowFlies installations contain no direct
clipboard operation. ATCF's native EditBox lifecycle clears selection on
focus loss (`UI.lua`, `U:Edit`); neither reference establishes broader system
clipboard access.

## Related text and lifecycle checks

- Render recorded minimum-level evidence as `Req. lvl {X}` without replacing
  quest difficulty or inventing an absent requirement.
- Location text uses `{zone} â€¢ {starter} â€¢ {x, y}` with U+2022 separators and
  omits missing parts. Keep the existing item-starter wording and phase/mobile
  evidence; never fabricate coordinates or an NPC identity.
- Query clear uses the existing OnTextChanged/Changed path, closes owned
  menus/comparisons consistently, cancels stale queued rendering through the
  normal query lifecycle, and does not reset unrelated filters.
- Add actual-entrypoint regressions for gun/sword/wand terms with neutral item
  names, slot/class/usability exclusions, cold metadata, subtype-only item
  callbacks, repeated warm queries, and unrelated/hidden callbacks.
- Spy on the actual copy EditBox's `HighlightText` and focus methods. Test all
  menu values, reopen/reuse, native hide, Enter/Escape, parent close, long URL
  retention and absence of any clipboard/debug call. Mock selection is not
  proof of physical Ctrl+C.

## Source receipts

Existing verified source cache:
`.work/upgrade-ranking-research/gethe-receipts.json` and `gethe-tree.json`.
The item contract SHA-256 is
`59c5dd2f70757cdb9bc4511cb0fafe6287bbfb51d58a7389097dcbb485785af0`;
item constants SHA-256 is
`ae3b654c4d551234e97562552e6aeb9736672f2458945efe19645b387f4b092e`.
Fresh selected generated contracts are in
`.work/search-copy-research/receipts.json`; each downloaded byte stream was
checked against its pinned Git blob SHA-1. The EditBox contract SHA-256 is
`aa932f643f66a880c6191043f7597b59d0c9f45df86f229c0322013d533a1aa8`.

Native clipboard permissions, physical copy input, final font/layout rendering,
combat taint and other-addon coexistence remain client checks. No gameplay,
configuration, game installation or unrelated-addon file was changed by this
research pass.

`SearchModel.lua` now retains those metadata fields and normalized search text
in the existing cache. Eight new subtype scenarios pass inside the actual
57-scenario `search_test.lua` suite under Lua 5.1. They exercise native item
callbacks through the registered event handlers, subtype-only changes,
unchanged events, hidden invalidation, missing/secret evidence, localized
subclass text, class-guarded English aliases, cold instant metadata, neutral
quest/item names and the existing player/slot restrictions. Eight repeated
warm queries over shared item associations perform no additional item-info
reads. This is offline call-count evidence, not a native CPU measurement.

## Sorting symbol

The pinned native auction-house table header uses
`atlas="auctionhouse-ui-sortarrow"` on its `Arrow` texture:
[Blizzard_AuctionHouseTableBuilder.xml:207](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseTableBuilder.xml#L207).
Its owning template is `AuctionHouseTableHeaderStringTemplate`. This is a
verified native sorting symbol, with no bag-cleanup action attached to the
addon-owned control. Paired normal and rotated copies can express ascending
and descending sorting inside the retained native DropdownButton; the actual
sort choices and scripts remain the existing four supported modes. This is a
small composition using native assets, not a claim that Blizzard supplies a
single combined arrows-and-lines atlas. No such combined atlas was verified
in this pass.

The table-builder source SHA-256 is
`38aeccf8578534950f9cf99599b81c3b5300fb877595dcf6726ca804debc2cd7`,
Git blob `875b7a87c3e96870d9459fc4e56ad798204df4ca`. Fresh native source
receipts are `.work/search-copy-research/sort-source-receipts.json`.
