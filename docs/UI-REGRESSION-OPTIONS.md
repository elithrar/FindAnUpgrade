# Blank options regression

The user observed a completely blank bordered options window in QuestBrief 0.1.1. The supplied screenshot `libfile_f81cfff56a7c8191b0f96e6243f7cd42`, materialized as `.work/visual-fix-screenshots/image(20261014-223133).png`, contains neither a title nor a close button. It is the acceptance baseline for this fix; it is not a screenshot of the repaired build.

## Cause and missed coverage

At merge `418aac19d5c1fb4ea4edaeb7bdd8b5a53f5d5b93`, `Options:Label` created a bare FontString and called `SetText` before `UI:Font`. The first such call constructs the window title. XPIsland's installed `UI.Text` applies its font before its options label helper calls `SetText`.

The Forever 70374 generated [FontString API contract](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua) explicitly permits a nil `GetFont` font file. The relevant native templates supply their font through inheritance. Our old mock instead gave every uninitialized object FRIZQT by default and let every `SetText` call succeed. That fixture could not detect font-before-text errors.

The second defect was constructor lifetime: `Options.frame` was assigned before creating its first label. If construction failed, the shown shell remained cached. The next slash invocation toggled that incomplete frame instead of constructing controls.

An offline replay of the exact merged options source with a stricter font precondition produces `0.1.1/Options.lua:8: FontString:SetText(): Font not set`, zero registered labels, and a visible cached empty frame. The next invocation only hides that same frame. Evidence is recorded in `dist/options-live-regression-probe.json`. This is source execution under a native-precondition fixture, not a captured in-client error stack. No BugSack/BugGrabber SavedVariables files were present in the target client's WTF tree; the saved QuestBrief schema 3 settings were well formed and were read without modification.

## Repair

Labels inherit `GameFontNormal` and resolve their owned font before assigning text. Checkbox captions follow the same order. `UI.lua` already supports checked path assignment and a native Font object fallback; no shared Blizzard font object is changed.

Options are constructed under a hidden shell. `Options.frame` is published only after its content and handlers are complete. If construction throws, the partial content is hidden, event handlers are removed, and its owned font registrations are discarded; the original error is propagated. A subsequent invocation reuses the named shell and builds complete controls. Normal openings reuse the complete controls.

## Current XPIsland parity

The subsequent user instruction explicitly requires current XPIsland conventions. The installed reference is XPIsland 0.6.3, interface 16001, at `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\XPIsland`. Its actual source bytes were read without modification:

| Source | SHA-256 |
| --- | --- |
| `Options.lua` | `92f6e43eaa4895f3353113756001e27184ce3ea0410bd3328c55634130521c63` |
| `UI.lua` | `fcf7f19de1f74568035ff66939c1a333bc86c80b5f76c53d9b1301ce84ca1958` |

QuestBrief now uses the current reference's dialog border (16px edge, 4px insets, .94 background opacity), Appearance/Behavior sections at x=16/316 with 288px widths, contents at x=28/328 with 260px allocations, native 24px checkbox rows, and 22px buttons with centered bounded text. The reveal-key buttons are replaced by `WowStyle1DropdownTemplate` and native radio menu rows. Dropdown text uses the reference's centered 24px height, left inset of 9px, and width minus 31px for arrow clearance. Menus scroll at 220px and compositor rows receive an owned `QuestBriefMenuFont` through `SetFontObject`; the fixture rejects even a compositor `SetFont` method lookup.

Scale and tint retain their existing ranges but now use the reference's 180x16 sliders and 58x22 `InputBoxTemplate` fields. Enter clamps and commits a percentage and clears focus; Escape restores the current setting without a write. Hiding options closes dropdown menus and releases edit focus. The page has no scroll frame, matching XPIsland's small options page, and uses its .3-to-1 scale clamp. Bounded text uses the reference's unbounded native measurements, physical-pixel padding, and scale-adjusted anchors. A normal status footer is empty.

The UI font default now follows current XPIsland's native Game tooltip family (`GameTooltipTextLeft2` or `GameTooltipText`), rather than silently selecting Expressway whenever SharedMedia is present. This is a native default and checked fallback, with no added font selector or profile feature.

The explained adaptations are QuestBrief's existing field names/ranges, a single page without unrelated Profiles/Tracking tabs, a 620x398 content-sized shell instead of the reference's three-page 620x462 shell, Core-owned validated persistence/future-schema protection, and the hidden construction retry repair. No XPIsland data, profiles, configuration or source files were changed.

## Verification and boundary

`tests/options_test.lua` covers eleven entry-path scenarios: missing-font rejection and native inheritance, actual slash construction and caching, early failure retry, late failure cleanup/retry, native font fallback, refresh without writes/current-profile controls, future settings read-only preservation, reference control/layout semantics, numeric Enter/Escape handling, menu/focus cleanup, and long localized text at fractional scale. All eleven pass under Lua 5.1. The stricter FontString fixture applies to the other Lua suites as well. Font regressions additionally check that SharedMedia availability never overrides the native default, rejected locale font paths produce a consistent fallback, and later registration can recover the native family while preserving font readback and idle-write safeguards.

The root task owns the full required verification run after the concurrent tooltip changes settle. An actual `/questbrief opts` open, title/close/control rendering, input, Escape dismissal, and font fallback in Forever remain pending in-client checks. The game and user configuration were not altered or reloaded by this diagnosis.
