# FindAnUpgrade sidebar visual review

## Review state

Independent adversarial review of the sidebar design iteration and `plan.md`.
Final renamed and integrated UI freeze: **34/34 independent execution scenarios
and 110 scenarios across five focused regression suites passed**. Relevant source
hashes matched between these runs and did not change during either run. No
remaining source-reproducible visual finding was identified.
This reviewer made no production-code edits, commits, installs, or user-setting
changes. Review fixtures are isolated under `.work/sidebar-visual-review/`.

## Evidence inspected

Read the current WoW addon skill and its UI/settings, layout and validation
references. Compared the actual controls and font ownership with
`references/XPIsland/XPIsland/Options.lua` and the ATCF `UI.lua` / `Options.lua`
constructors. Inspected all five supplied screenshots at their original local
resolution, including the repeated middle capture and the final width reference.

| Screenshot | Bytes | SHA-256 |
| --- | ---: | --- |
| `image(20261015-135549).png` | 1,001,534 | `a26887b2a2cd228bcf38c607b19aa49d6dc20f8732442a23e47955c9068f58d2` |
| `image(20261015-135550).png` | 818,244 | `20ed04569f2216f1d4f7c85e05e322deaa88956f423a073c842a3382630979d4` |
| `image(20261015-135551).png` | 818,244 | `20ed04569f2216f1d4f7c85e05e322deaa88956f423a073c842a3382630979d4` |
| `image(20261015-135553).png` | 137,512 | `b7688fd7613ccd8b5e04d02a85730e889583e3006e8f61a5eeeb1afa42f3cd06` |
| `image(20261015-135555).png` | 1,203,318 | `85c36f94def14a76e9cc30b047425232bace00b161162ebe48afc52ae35fc4e4` |

The screenshots show short-height/full-width search, detached checkbox text,
small icons, white quest titles, repetitive source terminology and custom text
hover obscuring nearby controls. The accepted design is a 476 by 680 logical
unit sidebar (15% narrower than 560), a 30-unit search/slot row, a Same zone /
Level range scope with always-editable interval, usable/dungeon checkboxes, a
result/status line beside the 28x26 native red/yellow sort control, 37.333-unit
reward icons,
yellow quest titles and measured information blocks. Native rarity borders and
item comparison hover remain. The cog uses the native `GEAR_64GREY` artwork in a
26-unit hit target, separate from both drag and close targets.

## Findings and resolution

1. **Malformed visible separators.** During the rewrite, count, zone and location
   strings contained the actual Unicode sequence `U+00C2 U+00B7`, displaying an
   extra A-circumflex before each separator. Confirmed using byte-aware Python
   reads, reported to the UI owner, replaced with spaced ASCII separators and
   checked again. This was a source defect, independent of native rendering.
2. **Reward-label width estimated from byte count.** Group labels used
   `#label * 5.5` while the displayed font was selected from the game's runtime
   tooltip font. A wider font could clip or overlap the reward column. The owner
   now measures an owned FontString using the same group font. Re-review covers
   normal and wide-glyph metric envelopes and checks each label's actual assigned
   bounds against its measured text width.
3. **Narrow filter controls overlapped.** At a 400 by 350 UIParent viewport with
   addon scale 1.2, fitting produced a 313.333-unit frame, while the fixed
   hide-unusable caption and Quest level controls remained on the same baseline.
   The independently resolved anchors overlapped. The owner now tests the
   measured caption widths and allocated checkbox hit width, reflows level inputs
   to an extra line and shifts count, sort, scroll and rail together. The original
   failing scenario now passes.
4. **Copy popup could exceed a fitted viewport.** The fixed 380-unit popup inherited
   scale 1.2 in the same narrow scenario, becoming 456 screen units wide. The owner
   now fits its width and edit field to the sidebar on open and later relayout,
   retaining native clamping. The independent popup, field, focus and Escape
   scenario passes.

5. **Wider scope selection clipped.** The narrow scope control allocated 81 text
   units within a 112-unit button, insufficient for a representative translated
   selection. The owner now measures the actual selection FontString, reserves
   arrow clearance and relayouts after selection/context refresh. A stronger
   current-English test under a wide-font envelope also passes when switching
   Same zone to Level range; checkbox captions and the level interval reflow.
6. **Native numeric overlays could collide.** The pinned Roman native numeric
   family is 12 pixels, while the earlier broad fixture supplied 10. Correcting
   the independent fixture exposed intersecting three-digit level/quantity labels
   under conservative digit metrics. The source had no collision guard. The
   renderer now measures both actual FontStrings and moves only a crowded quantity
   to top-right, preserving item level bottom-left and native fonts. Normal and
   reused rows restore quantity bottom-right. This identifies and repairs a
   missing construction guard; it does not claim measured native glyph advances.

The wrapped count/status now clears its previous fixed height before measuring,
following ATCF's `WrappedHeight` construction. Result viewport and scrollbar
move together as status grows, and shrink again when it clears. The sort menu
plainly says the score is estimated stat gain and weapons/effects are not rated;
the count separately marks unrated results or unavailable scoring context. No
fabricated zero, percentage or DPS increase is added to the rows.

The owner also reserves measured width for multiple-location controls, allowing
long location text beside zero, one or several rewards. Mixed guaranteed/choice
reward groups use a natural horizontal arrangement when they fit, otherwise
separate labeled rows. These complete paths passed independent review.

## Independent execution

`python .work/sidebar-visual-review/run.py` loads the shipped Lua 5.1 modules in
fresh native API fixtures. The reviewer added a separate anchor resolver that
retains independent anchors, relative frame geometry, inherited effective scale
and scroll-child positions. It validates resolved bounds rather than merely
asserting that SetResizable or SetSize was called. An initial solver sanity check
uses two independently constrained corners and checks the resulting rectangle.
Font measurements use normal and conservative wide-glyph envelopes; these are
explicit substitute metrics, not a claim to reproduce native game fonts.

The 34 independent scenarios cover:

- Six viewports: 1920x1080, 1280x720, 800x600, 500x350, 400x350 and 3440x1440,
  including 0.8 and 1.2 scales; search/menu separation, check/level alignment,
  count/sort separation, cog/close/drag reachability and viewport fitting.
- Viewport and scale changes in both orders, restoring requested dimensions.
- Copy popup and edit fitting, focus ownership and Escape; actual cog and close
  callbacks, unfinished range cancellation and hidden OnUpdate removal.
- Six long mixed-reward rows at widths 420, 476 and 680 under two glyph envelopes;
  title/location/evidence/amount containment, 37.333-unit icons, group label sizing
  and absence of extra text/amount hover callbacks.
- Classification decoration off while keeping yellow titles and neutral surfaces.
- Multiple location picker bounds with zero, one and two items.
- Guaranteed/choice combinations 1/1, 1/3, 3/1, 0/8, 8/0 and 1/20, including
  separate group ownership, expansion/collapse and bounded visible items.
- Recycled icons clearing absent item levels, quantities, group labels and stale
  hover rows, then invoking the actual current native inspection entry callback.

- Real scope selection, always-editable range preservation, dungeon toggle and
  native sort callbacks; the default is Same zone / Biggest upgrade, without
  implying that item level alone proves an upgrade.
- Context updates while a native menu is open, range commit without premature
  dismissal, measured translated captions and longer scope selection changes.
- Twelve-pixel native-number collision/reuse handling, wrapped status expansion
  and contraction, and a previously open copy popup after later resize.

The five focused suites exercise the actual native primary/comparison renderer
fixtures, dropdown ownership, asynchronous item updates, hidden/no-op scheduling,
row/tooltip recycling and the complete changed sidebar construction:

| Suite | Scenarios |
| --- | ---: |
| `sidebar_design_test.lua` | 15 |
| `search_test.lua` | 49 |
| `search_runtime_test.lua` | 16 |
| `search_lifecycle_test.lua` | 22 |
| `reference_widgets_test.lua` | 8 |

All **110** passed in one run. The baseline renderer and current-source fixture
checks establish source integration; their mocked services do not establish
physical game input or live rendering. All production Lua, the native mock and
these five suites were hashed before and after; those hashes were unchanged.
The full inventory and timing are in `.work/sidebar-visual-review/suites.json`.

Machine-readable results and rectangles: `.work/sidebar-visual-review/results.json`.

Final relevant source hashes:

- `Search.lua`: `519eedec7cb801a97d2c68b9a1d11413cd2624465987bf98ea39cc349787ae15`
- `SearchModel.lua`: `ccb08d2f4d4d346300934f33fc901fdfcee360902ee2c2d975af4391eddf5c86`
- `UI.lua`: `82ab0084ba17f372da8858431a0d360449aee9a0cfb83ea0aa0034b2ef8ad6d5`
- `Core.lua`: `9fefaa97609fd74d21b56ef0fd11ff383f7e76df46c169cd153c31027a486137`
- `Character.lua`: `de02774f17b75214d4cd739bcab246471b37ed94999ee0e32235a0099d44914b`
- `Ranking.lua`: `839e4a72fe799db08bcb0ec30564fb242ec140ae46261c7eec55d10fa006327f`
- `Model.lua`: `4509ee01f7b9c97bc08f0f0802cdbf7c75b7e80ece72aefcef088b644349ba4d`
- `Providers.lua`: `ca147aca8c7d25df0846ef67a5a17a9cccce5e1324ec9710abbc69cbd3c981f3`

## Boundary and remaining review

No native game rendering, physical mouse input, live performance or combat/taint
verification was performed by this reviewer. Final perceived optical balance,
actual native glyph metrics, dropdown input and comparison layering remain
specific client checks. Eligibility, database provenance and migration correctness
are covered by separate independent reviewers. The full identity rename and
final scope/sort-control integration are included in this completed review.

The stress viewport cases establish contained controls and scroll navigation,
not a guarantee that a complete quest row fits every artificially small viewport.
The default sidebar retains its 680-unit tall form when the viewport permits it.
