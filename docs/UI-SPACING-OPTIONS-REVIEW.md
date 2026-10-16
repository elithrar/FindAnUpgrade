# Star spacing and single-window Options review

Independent adversarial review on 2026-10-16 of the 0.1.13 UI patch for official Forever interface 16001. Read the applicable AGENTS.md, current installed wow-addon-development skill and layout/UI/validation references. Inspected the actual Search, SearchViews, Options and shared scrollbar constructors, the installed XPIsland and AsTheCrowFlies Options patterns, all three supplied PNG screenshots as pixels, and the native star research receipts and comparison crop.

## Result

No unresolved P1 or P2 finding remains in the reviewed implementation. This conclusion covers source and fresh Lua 5.1 offline fixtures. It does not certify native rendering, physical input or combat/taint behavior. Full repository verification, archive identity, CI and installation are separate delivery checks.

## Concrete finding and resolution

**P2, fixed: permanent scrollbar leaked after a failed Options constructor.** The initial single-window implementation assigned `self.bar` only after `U:VerticalBar(parent)` returned. An error during native thumb setup left its already-created permanent slider uncached. Two injected `SetThumbTexture` failures followed by a successful open produced 38 frames versus 36 for clean construction, with two abandoned sliders parented to the now-visible Options content.

Options now reserves its slider through the same deterministic `O:Frame` pool as its other controls before calling shared setup. `U:VerticalBar` accepts that existing owned slider while keeping unchanged default construction for its other callers. Independent re-execution with the same two thumb failures now produces one reserved scrollbar and 36 total frames, equal to clean construction. The ordinary first-label, late-event and repeated-construction recovery scenarios also pass. Failed shells remain hidden and successful retries publish complete controls once.

## Geometry and behavior inspected

- Search preserves Quests and Shortlist tabs. Options has one content canvas and no page/tab navigation. All existing ten checkboxes, five dropdowns, two sliders and four numeric fields remain state-backed, with no schema change.
- The star uses one texture that swaps `auctionhouse-icon-favorite-off` and `auctionhouse-icon-favorite`, on the same center anchor. Art changes from 20 by 18 to 17 by 15.3 logical units, a 15 percent reduction on each axis; its hit target remains 24 by 24. No second outline is composited over the saved state. The pinned Blizzard favorite-state implementation also swaps these atlas identities; the inspected offline crop shows the intended hollow/yellow pair. Atlas antialias fringes and physical subpixel rendering remain client checks.
- Reward icons reserve the full star target plus six logical units. Measured title and classification-badge extents also contribute to header clearance. At the tested minimum/fractional-scale layouts, icon targets do not overlap the star, title or badge. Long titles increase the header rather than covering rewards.
- Guaranteed and Choose one remain distinct. Captions have five logical units below their final icon row, measured line height, eight units before the following vertical group or location control, and fourteen units between horizontal groups. Expanded mixed reward groups fit the allocated card height. A fixture with 24-unit caption height expands the actual allocation.
- Options retains the installed-reference dialog border, tooltip section boxes, native radio dropdowns, owned menu Font object, checkbox templates, numeric input insets, fixed footer and 12-unit control text roles. Its 572-unit scroll child matches its viewport width. Five two-column sections and control bounds remain disjoint; checkbox hit rectangles stay inside their columns.
- At a 960 by 360 logical viewport, Options is 620 by 336 at scale one, with a 246-unit viewport and a 384-unit range. Wheel and native-slider callbacks clamp both ends. Returning to a tall display resets the range/offset and hides the unneeded bar. Scrolling or a geometry change closes menus and clears unfinished numeric focus without committing a replacement setting. Window hide stops dragging and clears its deferred menu updater.
- Reopen, repeated scrolling and appearance refresh reuse controls. Future saved schemas stay read-only while scrolling remains available. Native item/comparison ownership and pooled reward-row lifecycle suites still pass; no protected Blizzard layout or global font is changed by this patch.

## Fresh checks performed

Each suite ran in a fresh Lua 5.1 runtime through Lupa using the real shipped module entry points, including the repository's available pinned native-control fixtures:

| Suite | Scenarios |
| --- | ---: |
| options_test.lua | 19 |
| shortlist_ui_test.lua | 10 |
| sidebar_design_test.lua | 27 |
| font_test.lua | 12 |
| reference_ui_test.lua | 13 |
| reference_widgets_test.lua | 8 |
| search_lifecycle_test.lua | 22 |
| Total | 111 |

Additionally ran the independent repeated native-thumb failure reproducer before and after the fix. Reviewed default and narrow viewports, requested scales 0.85 and 1.2, scaled parents, long titles and captions, tall caption metrics, expanded mixed reward groups, multiple location controls, open/closed menus, focus cancellation, future read-only settings, pooled star states and hidden/reopened owners. Approximate font metrics and declared bounds are offline evidence, not screenshots of the patched addon running in game.

## Pending native checks

Inspect the patched addon in the actual 1.60.1.70374 client for final atlas silhouettes/antialiasing, typography, clipping and perceived caption spacing at the user's UI scale. Exercise physical wheel propagation over child controls, scrollbar dragging, Options window dragging and display changes, Escape, pointer transit between star/items, native item and comparison tooltips, combat/taint safety, and coexistence with the user's other addons. The supplied screenshots establish the previous reported appearance; they do not observe this patch. No game was launched for this review.

## Reviewed file identity

SHA-256 uses UTF-8 file bytes with CRLF normalized to LF, matching repository normalization. A later change requires checking its affected conclusions again.

| File | SHA-256 (LF) |
| --- | --- |
| `FindAnUpgrade/Search.lua` | `65f4f9e96baf2d8f99fa19e3353f1dcab43ffd68277a7606c0ded24d33395ba1` |
| `FindAnUpgrade/SearchViews.lua` | `72ed062d81a37ed7308f8cd6de72e40244835a91527403ceedebafffe3b966f6` |
| `FindAnUpgrade/Options.lua` | `1e604cf393d0ada877895564edeca33c370975053d50eb6231f5fb17ad35c1cb` |
| `FindAnUpgrade/UI.lua` | `3b5b3471f66d7e050ba2a0ba09cf83206c411c3a75cca9ed827322c391acedd8` |
