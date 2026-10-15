# FindAnUpgrade sidebar native contracts

Read-only construction audit for the sidebar iteration in `plan.md`. Inspected
all five supplied screenshots (`135549`, `135550`, `135551`, `135553`, `135555`)
and the installed MONOLITH XPIsland/AsTheCrowFlies constructors. The two middle
full-window captures are identical. Their checkbox separation, shallow search
border, white quest names and small icons match the reported defects.

Target: official Forever 1.60.1.70374, interface 16001, Gethe UI-source commit
`735496de78ebd30ce816a0637982c556987f258c`. Newly retrieved definitions were
byte-checked against their Git blob IDs in that exact tree. The local source and
installed-reference SHA-256 receipt is
[`sidebar-native-contract-receipts.json`](sidebar-native-contract-receipts.json).
This is inspected source, not live rendering, physical input or taint verification.

## Cog and native sorting artwork

Installed `AsTheCrowFlies/UI.lua:183–219` uses
`Interface\WorldMap\GEAR_64GREY`, a 64-pixel source centered at 20 pixels, with
the verified `OptionsIcon-Brown` atlas as an 18-pixel fallback. Its header uses a
26-by-26 holder beside the other action and raises it above the drag header
(`483–487`). Reuse that proven texture construction, avoiding a guessed settings
template. Clicking the new cog should close finder menus/clear edit focus and
open the existing options entry point. Keep its hit box separate from dragging
and closing. Check texture load success and retain a visible fallback action.

The pinned [BankAutoSortButtonTemplate](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrameTemplates.xml#L262)
is 28 by 26 pixels. Its normal/pushed atlases are
`bags-button-autosort-up` / `bags-button-autosort-down`; the highlight is
`Interface\Buttons\ButtonHilight-Square`, centered at 24 by 23 with additive
blending. These are complete native sorting-button artwork, not separately
defined red-background/yellow-icon layers. The
[UI module TOC](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_UIPanels_Game/Blizzard_UIPanels_Game.toc#L137)
loads this shared Mainline bank template for Camelot/Forever.

Apply the artwork to the addon's intrinsic `DropdownButton`; retain native
`SetupMenu` ownership and the addon's sort selection. Do not inherit the bank
template itself: its
[BankAutoSortButtonMixin](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrameTemplates.lua#L1839)
expects bank-parent state and its click handler sorts the bank. No inventory or
bank action belongs to the finder control. Final atlas color/visual acceptance
still requires the client.

## Header controls and typography

- Installed XPIsland `Options.lua:72–96` and ATCF `UI.lua:383–394` use
  `WowStyle1DropdownTemplate`, `SetupMenu`, native radio rows, bounded scrolling
  and an owned menu Font via `SetFontObject`. Both explicitly clear inherited
  selection-text points, anchor `LEFT` at 9,0, reserve 31–36 pixels for the arrow,
  and vertically center text across the full control height. Preserve that
  construction and the existing menu lifecycle fix.
- The pinned [Classic menu template](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Menu/Classic/MenuTemplates.xml#L23)
  gives dropdown text two top anchors and a 10-pixel height. Merely enlarging the
  font or dropdown without clearing those anchors causes clipping/misalignment.
- The pinned [InputBoxVisualTemplate](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml#L43)
  fixes `Left`, `Right` and `Middle` texture heights to 20. **Setting the EditBox
  height to 30 alone leaves its visible border at 20.** Resize the owned three
  regions to the chosen 30-pixel height while preserving cap widths/anchors, or
  deliberately adopt a separately verified larger input template. Keep the
  current input scripts/focus behavior and symmetric text insets.
- The pinned [UICheckButtonTemplate](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml#L50)
  starts at 32 by 32; its `Text` starts at the button's right edge minus 2.
  Resize the holder to 24, clear/reanchor the caption explicitly, allocate its
  width/height and center vertically. Limit the caption hit extension to its
  allocated grid cell so it cannot cover the neighboring level input.
- Existing `UI:Font` correctly follows the native tooltip face with locale-safe
  fallback. Keep body/control type consistent, use an explicit yellow quest-title
  color, and wrap useful row content. Do not shrink text or mutate global fonts
  to make the narrower sidebar fit.

## Item levels and native item hover

The pinned [C_Item.GetItemInfo contract](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua#L590)
may return nothing. Return 4 is item level; return 5 is minimum usable character
level. They are distinct. The pre-iteration `SearchModel:Item` already caches
the fourth return as `itemLevel` and receives item-data completion events.
Use that resolved field, never quest level/minimum level or a guessed zero.
No per-frame item-info polling is necessary for an overlay.

Use a locally owned `NumberFontNormalSmall` FontString for the bottom-left item
level, leaving quantity bottom-right. The native
[GameFontStyles definition](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Fonts_Shared/Shared/GameFontStyles.xml#L18)
is white and inherits the outlined number family; its
[Mainline family](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Fonts_Shared/Mainline/GameFonts.xml#L59)
uses a 12-pixel roman number face with locale members. Keep this separate from
the body's `UI:Font` registry so later font refresh does not erase its native
outline. Clear/hide the overlay whenever a pooled icon is reused for pending or
missing item metadata; show only a positive readable number. Verify level and
quantity cannot overlap on the enlarged 37.3-pixel icons.

Retain the current native item/comparison tooltip path. Remove custom finder
explanation/provenance hovers and repeated `Recorded ...` / `(base)` copy; the
overlay needs no added explanatory tooltip. Row reuse, async completion, native
item hover after scrolling, fractional-scale bounds and visible control layering
are required focused checks. Native glyph metrics and final appearance remain
live-client checks.
