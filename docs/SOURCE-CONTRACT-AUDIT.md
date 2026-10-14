# Source and native construction audit

This independent audit starts from QuestBrief 0.1.2 (`721147c6311a3392f43483ec3b52f22803bf34f7`). It compares production constructors and test behavior with the actual installed addons and the official Forever 1.60.1.70374 source at `735496de78ebd30ce816a0637982c556987f258c`. This is source inspection and Lua 5.1 execution, not a claim of captured game behavior. Source evidence establishes the defects below without making live visual inspection a prerequisite.

## Reference evidence

The installed reference root is `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns`. These files were read without changing their source or SavedVariables:

| Installed source | SHA-256 |
| --- | --- |
| XPIsland/Options.lua | `92f6e43eaa4895f3353113756001e27184ce3ea0410bd3328c55634130521c63` |
| XPIsland/UI.lua | `fcf7f19de1f74568035ff66939c1a333bc86c80b5f76c53d9b1301ce84ca1958` |
| AsTheCrowFlies/Options.lua | `373493afde8df5f638b276e1e4ff83e01b1aef0a81da9b1464259b8cbca7b615` |
| AsTheCrowFlies/UI.lua | `0db47da1af7ce3ce4384ba7fe1f3ad6874454431669fd14533ae9255a1ef8aa0` |
| EllesmereUI/EllesmereUI_Panel.lua | `1b5899e410bb7ad7a5bf0380162b8e06efdc6b000545440f498ee7e6eca7c5c6` |
| EllesmereUIOptions/EllesmereUI_Widgets.lua | `80f820e475ef0b38d3b2168eaf3c41ffcdcc82d378ae927b8652458fea4dc717` |
| Questie/Modules/Tooltips/TooltipLayout.lua | `5ecfd8406dcbe521899e0ca254e583e59737da3f69ff47693db7c0c451444bfe` |
| Questie/Libs/AceGUI-3.0/widgets/AceGUIWidget-DropDown.lua | `42e2a9d9c41bc4f481af1721b6cc45988e2bc5573fd0282499e9bf3af8e8ec20` |

Additional native source was fetched by immutable revision and preserved byte-for-byte from GitHub's content base64 in `.work/source-contract-audit/`. `native-source-manifest.json` records fourteen source paths, Git blob IDs and SHA-256 hashes. This includes Classic menu XML/Lua, dropdown intrinsic XML/Lua, button-state mixin, input-box and checkbox templates, slider template/API and current `GameTooltip.xml`. The existing current tooltip mixin fixture was also read.

## Concrete findings in 0.1.2

### Range editing commits cancelled input through a native focus event

`QuestBrief/Search.lua:127` assigns `range()` to `OnEditFocusLost`, but its Escape handler only calls `ClearFocus()`. Native focus loss then runs the same commit handler. `Search.lua:142` similarly clears focused range fields when closing the window, applying an unfinished edit. In contrast, XPIsland's shared edit helper uses Escape to clear focus and refresh the stored setting; its percentage fields commit on Enter. ATCF's edit helper follows the same cancellation convention.

An isolated execution of shipped code with native focus-loss notification gives this counterexample:

| Action | Accepted range | Visible minimum |
| --- | --- | --- |
| Open finder at player level 20 | 15–23 | 15 |
| Focus minimum and type 16 | 15–23 | 16 |
| Press Escape | **16–23** | **16** |

The expected cancellation preserves 15–23 and restores the minimum field to 15. `.work/source-contract-audit/focus_probe.py` reproduces this under Lua 5.1. Tests that only flip a mock `focused` boolean cannot detect it. The repair must restore or suppress the draft before triggering focus loss, including dismissal, while preserving deliberate Enter commits.

### Vertical scrollbars retain horizontal thumb art

`Stack.lua:48` and `Search.lua:134` construct `UISliderTemplate`, set orientation to vertical, then resize the thumb to 12×22. The pinned [UISliderTemplate](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml#L330) supplies a 32×32 `UI-SliderBar-Button-Horizontal` texture. Setting the slider's orientation does not replace its assigned texture. The result is horizontal artwork compressed into the vertical allocation.

Installed Questie's `AceGUIWidget-DropDown.lua:308` explicitly uses `Interface\\Buttons\\UI-SliderBar-Button-Vertical` for its vertical slider. QuestBrief should likewise select the vertical thumb asset and explicitly account for the inherited horizontal track and expanded hit rectangle. The existing fixture models only the thumb's dimensions; it cannot distinguish correct vertical art from a stretched horizontal texture.

### Private comparison headers omit native label construction

`Stack.lua` manually creates comparison headers at height 20 and y=0, without the native label background or explicit label color. The current [ShoppingTooltipTemplate](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.xml#L109) uses a 22px header, `BOTTOMLEFT` to tooltip `TOPLEFT` at y=-1, a `tooltip-compare-label` background atlas, and `GameTooltipText` colored with `NORMAL_FONT_COLOR`.

Using private `SharedTooltipTemplate` tooltips is justified by their isolated cleanup. It does not require omitting the native header artwork. The visual construction can be reproduced without invoking `ShoppingTooltipTemplate`'s `GameTooltip_OnLoad` and global comparison/battle-pet ownership paths. The current manager tests prove the manager can consume `CompareHeader`, but do not verify its actual native art or sizing.

### Clamped item tooltips can sit below their own reward cards

The 0.1.2 private tooltips are parented directly to `UIParent` and do not raise their frame level above the stack's nested scroll/card/icon hierarchy. The stack also uses TOOLTIP strata. On a narrow viewport, native tooltip clamping can overlap the inspected reward card; the deeper card and icon frame levels can then draw over the item tooltip.

Replaying the exact 0.1.2 `Stack.lua` under the independent native-inheritance fixture gives stack/card/icon/item-tooltip levels **2/5/6/2**. The reviewed patch raises private primary and comparison tooltips above this owned hierarchy and keeps comparison headers one level beneath their tooltip. Its source-derived regression resolves overlapping rectangles and checks relative levels, without asserting a particular numeric offset.

## Constructions that match their contracts

| Construction | Source evidence and assessment |
| --- | --- |
| Options shell | Same XPIsland dialog backdrop, opacity, insets, DIALOG strata, centered initial anchor, movable/clamped frame and native close button. QuestBrief hides its shell before construction and publishes it after successful completion, retaining the concrete 0.1.1 startup repair. |
| Options sections and controls | Same two-column allocations, native checkbox/control sizes, numeric `InputBoxTemplate` fields, font-before-text order and menu-owned Font object approach. Core-validated profile replacement differs intentionally from direct reference profile mutation. |
| Dropdown selected text | Classic `WowStyle1DropdownTemplate` supplies a 10px high text box with TOP anchors. QuestBrief correctly clears those anchors, centers a 24px box with 9px left inset and leaves width minus 31px for the arrow, as current XPIsland does. The independent resolved-anchor probe confirms containment at fractional effective scale. |
| Native menu rows | `button.fontString:SetFontObject(ownedFont)` matches XPIsland and avoids forbidden compositor `SetFont` lookup. Blizzard owns menu row generation, selection, dismissal and scrolling. Menu descriptions and a real open menu are different lifetimes; tests must not conflate them. |
| Native inherited dropdown scripts | The pinned `WowStyle1DropdownMixin` uses `ButtonStateBehaviorMixin`; its `OnShow` clears down/over state, and its enabled-state handler changes text color and arrow art. It does not reset this dropdown's selected font. ATCF's deferred font repair is not, by itself, evidence that this QuestBrief dropdown requires one. |
| Tooltip card background | `TooltipBorderedFrameTemplate` inherits `TooltipBackdropTemplate`, supplies alpha .8, and runs `TooltipBackdropOnLoad`. Its `SetBackdropColor` is a supported mixin method delegating to `NineSlice:SetCenterColor`. This is a valid native template; a claimed missing-backdrop-method defect would be incorrect. The new probe executes those actual pinned methods. |
| Tooltip text | Card titles inherit `GameTooltipHeaderText`, and other content inherits `GameTooltipText`. SharedMedia cannot silently replace the card font. Native font objects are not modified. |
| Private item rendering | Private shared tooltips plus the pinned native data-handler and comparison-manager methods retain native item lines while isolating comparison state. Existing suites meaningfully exercise delayed data, stale row/generation cancellation, callback reentry and bounded retries. These protections should be retained when correcting art. |
| Effective pointer visibility | `Adapter.Visible` correctly prefers native `IsVisible` over `IsShown`. Hidden ancestors therefore exclude pointer targets in production. The old fixture does not expose `IsVisible`, so that correct production branch was previously untested. |

QuestBrief's single options page, shorter shell, absence of unrelated XPIsland profile/tracking tabs, and separate validated configuration owner are required functional adaptations. Interactive quest cards need owned frames and a scroll container, so their use of `TooltipBorderedFrameTemplate` rather than noninteractive `GameTooltip` text rows is explained. The native edge, font objects and background APIs remain reusable. Ellesmere's larger custom panel and AceGUI's broader framework are evidence for lifecycle and control behavior, not a requirement to add those addon dependencies.

## Regression fidelity

`tests/reference_ui_test.lua` is an independent stricter fixture, separate from the broad legacy mock. It resolves multiple relative anchors and local scale offsets, models `SetAllPoints`, adds ancestor-dependent `IsVisible`, propagates parent show/hide to descendants, fires `OnEditFocusLost`, clamps native slider values, and initializes relevant Classic dropdown/checkbox/slider defaults. It executes the actual pinned tooltip backdrop methods rather than granting all frames an invented backdrop API.

The twelve scenarios cover hidden-ancestor pointer rejection; complete options child lifecycle; actual intrinsic dropdown `SetupMenu` under a hidden shell; fractional-scale dropdown containment; checkbox caption containment; slider clamping; native backdrop mixin dispatch; correct vertical thumb art; native comparison header art/geometry; clamped item-tooltip overlap and relative levels; range Escape cancellation; and unfinished range dismissal. The dropdown scenario executes the actual pinned method: `IsShown` reflects a child's own shown state, so `SetupMenu` can generate its selected text before the hidden shell becomes visible. It does not rely on the old fixture's lazy `SetupMenu`.

All twelve scenarios pass after the source findings were repaired. The exact 0.1.2 source is preserved in `.work/corrected-721147c6/QuestBrief/`; `.work/source-contract-audit/baseline_probes.py` independently replays it and confirms these counterexamples:

| Probe on exact 0.1.2 source | Result |
| --- | --- |
| Vertical thumb asset | `UI-SliderBar-Button-Horizontal` |
| Comparison header | height 20; native label atlas absent |
| Inherited stack/card/icon/item-tooltip levels | 2/5/6/2 |
| Escape after changing minimum from 15 to 16 | accepted minimum becomes 16 |

Re-review also caught an incomplete intermediate fix: removing the focus-loss commit preserved the accepted range but left cancelled text visible. The final Escape handler restores both accepted range values before releasing focus, and closing restores them as well. This matters because the displayed filter must agree with the filter actually applied. The independent fixture coerces numeric `SetText` input to a string, matching native text readback rather than confusing this check with a mock type discrepancy.

Existing geometry scenarios frequently assign `.x`/`.y` manually because legacy `GetRect()` ignores `SetPoint` and `SetAllPoints`. Existing `SetMinMaxValues`, orientation and hit-rectangle methods were no-ops, and parent visibility did not affect descendants. These are coverage limitations, not evidence that every production behavior is wrong. The new suite exercises native-derived state transitions and resolved geometry without declaring its approximate glyph widths to be native rendering.

The audit supplies source-established repairs and focused regression checks. Native glyph rasterization, actual physical input and combat/taint behavior remain supplementary client confirmation; their absence does not weaken the concrete source findings or prevent fixing them. The game, installed reference addons and user configuration were not changed by this audit.
