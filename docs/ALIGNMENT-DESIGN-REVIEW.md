# Independent alignment and settings design review

Status: accepted for the frozen source/offline design scope after the global production freeze and a fresh 30-scenario independent rerun. No unresolved source-identifiable design finding remains in the reviewed interaction. This does not establish native rendering or input acceptance.

## Scope and independence

The review traces the actual `Search`, `Options` and `UI` constructors, their measurement and reuse paths, and the requested changes. It does not rely on previous patch test counts. The reviewer owns this report and private probes under `.work/alignment-review/design/`; implementation changes remain with the authors.

Read references include the current repository instructions; the installed WoW addon skill's UI/settings and layout references; the accepted alignment/settings plans; installed XPIsland `Options.lua` dropdown, section, tab, edit and refresh constructors; installed AsTheCrowFlies `UI.lua` intrinsic dropdown/filter constructors; and the cached Forever 70374 input/dropdown XML and Lua at Gethe revision `735496de78ebd30ce816a0637982c556987f258c`.

The exact latest screenshot bytes have not been available to this reviewer. Parent-observed findings cover the first two main images and the query-clear image: unequal visible control edges/heights, low reward alignment and choice-label offset, bag-like sort art, and unnecessary rating diagnostics. An inspected local October 14 screenshot was identified as historical compact-inspector feedback and excluded. No claim of independent inspection of the new pixels is made.

## Findings and dispositions

1. **Saved-default copy implied the current scope reset on reopening.** The settings page originally said “Current zone remains the default,” while the agreed lifecycle preserves the transient scope within a session. The author changed this to “New sessions start in the current zone.” The normal initial current-zone scope and session-retained scope are now described separately.
2. **Texture bounds alone do not prove visible dropdown-border alignment.** The pinned native template gives the classic textholder asymmetric outsets of 9/8 horizontally and 8/9 vertically. Replacing them with `SetAllPoints` proved region allocations but did not establish the opaque artwork edge when atlas transparency was unknown. The author now matches the input's exact native left/middle/right search-border slices on the owned dropdown background while retaining the intrinsic dropdown, arrow, menu and input scripts. Independent probes verify identical assets, dimensions and allocations; apparent native pixels remain a client check.
3. **Long media-font names must remain readable.** A validated media name may be up to 128 bytes. Scaling an arbitrarily long selected label through the reference bounded-text helper could reduce it to unreadable type. The selected font caption is now shortened at UTF-8 boundaries using measured available width at scale 1, while retaining the full saved identity and full native-menu label. The independent real-width probe verifies abbreviation, native menu regeneration, exact identity and stable reopen object counts.
4. **Locale-dependent control classification rejected valid UTF-8 font names.** The new long-name scenario exposed that Lua `%c` on this Windows runtime classified byte 173 inside UTF-8 `中` as a control. The exact 104-byte font preference became the 12-byte default, independently reproduced by this reviewer and the author. Validation now checks explicit ASCII controls and pipes, preserving Unicode preference names. The independent long-name constructor probe passes after the change.
5. **Specialized item numerals must preserve their native role.** A broad font preference initially overrode the `NumberFontNormalSmall` face and outline on quantities and item levels. Root confirmed the accepted plan's specialized-number exception; the authors removed those overrides. The independent probe verifies native face, 12-unit size and outline under both the default and an explicit body-font choice, without global font writes.

## Independent execution

The private runner executes the actual addon constructors under Lua 5.1 and replaces the fixture's byte-count glyph approximation with Pillow measurements from the existing Expressway font asset. This improves the check of real string advance widths without pretending to reproduce game font shaping or physical pixel rounding. The font is a test asset only, not a packaged dependency.

The current 30 scenarios pass:

- Default 420, 476 and 680-unit sidebar widths: left/right control allocations, primary row heights and gaps, range midlines, clear target and text inset, selected-text/arrow clearance, and count/sort spacing.
- Fractional 0.8, 0.85 and 1.2 scale configurations, small and large viewports, translated French control captions and retained 12-unit control roles. Logical viewport fitting and reflow are checked; native effective-scale pixel rounding is not simulated.
- The 620-by-462 settings shell: readable tabs, font/border paired controls and independently aligned lower/upper offset edits.
- Long Unicode media-font selection: exact preference/menu identity, measured selected-label abbreviation without font shrinking, native menu regeneration and repeated refresh object counts.
- Native item-level/quantity numeral role under default and explicit body-font choices.
- First reward top alignment across guaranteed-only and choice-only rows, with captions below the icons.
- Eighteen combinations of widths and 1/0, 0/1, 0/4, 1/3, 2/2 and expanded 4/4 reward groups: wrapped title/location, multiple locations, left/right content separation, fixed icon size, quantity/item-level collision handling, caption bounds, preserved `In quest log`, and pooled-row cleanup.
- Query-clear visibility/state and the native selected-text copy dialog's bounds/focus.

The final rerun used `python .work/alignment-review/design/run.py` after root confirmed the global production freeze. All 30 independent scenarios passed. The result is retained at `.work/alignment-review/design/results.json`; the reviewed LF source hashes match the authors' stable artifacts.

| Reviewed file | SHA-256 |
| --- | --- |
| `FindAnUpgrade/Search.lua` | `23a74d4b8af5beff3d45f64dec0c904ee14cdb3eedc711386bacddccfae20884` |
| `FindAnUpgrade/UI.lua` | `317eed8208777b5dbbc5e1b02953c9f45e8bb83784c4c292e802a7ac753468e1` |
| `FindAnUpgrade/Options.lua` | `69ae45d516af7ee60cd862589a593b5dee4365766429029b605a10cad1a7719d` |
| `FindAnUpgrade/Model.lua` | `a655186a304fe0365baf7f4e61b83fddc0c8be20ac51144dc5a4c0c1b43a0099` |
| `FindAnUpgrade/Core.lua` | `d98d51d57fd79100442ce9ae638c8ac9be3797ce2eadaaa336a7e6d06b103491` |
| `FindAnUpgrade/Stack.lua` | `6c97f99ebbdc7ec084fc5ab34536a3ce60c968283f54ba1be56fae9582e743bc` |
| `tests/wow_mock.lua` | `0a60bdda438a11d9d94bc1b8d02168ad72a90a0d8c2823ab6cd7dc16a2b9eb97` |

The private independent runner SHA-256 is `8d6524a27e7cb898efd161ab9ca440e5a097987fe16f7cc6e3193eedfbcd6da2`; its Lua probe is `f075d5f75900d5761923f82ed419f5d88555ee967ea6846bfd653380218aafdd`. The Expressway fixture SHA-256 is `06a2106170c2b5b736955cc749ed755f3757d103230645158f0bd5b5b91c386b`. These private assets are not packaged addon dependencies.

## Remaining client checks

Native apparent border alignment, glyph rendering and locale shaping, physical dropdown/clear input, effective-scale rounding, item/comparison tooltip transit, selected-text Ctrl+C operation, and combat/taint behavior require the actual supported client. Offline constructors and source checks do not establish those outcomes.
