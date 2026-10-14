# Independent options source audit

Reviewed QuestBrief **0.1.2**, commit `721147c6311a3392f43483ec3b52f22803bf34f7`, against the actual installed XPIsland 0.6.3, AsTheCrowFlies 0.1.3, EllesmereUI 9.5.4 and EllesmereUIOptions 9.5.4. The installed addons were read only. This review changed only this report; implementation fixes belong to the root task.

The options construction now follows XPIsland's working implementation in its material visual and interaction choices. I found **one P2 ownership defect in failed-construction retry**, detailed below. The evidence does not support another blank-window error in the normal constructor. Different page counts, field ranges and persistence ownership are explained by QuestBrief's functionality; importing Ellesmere's larger custom framework would be an unnecessary additional dependency.

## Sources and identity

`I` below means `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns`. `Q` means the repository's `QuestBrief` directory. Line evidence refers to the captured 0.1.2 source; later fixes may move lines.

| Read-only source | SHA-256 |
| --- | --- |
| `I\XPIsland\Options.lua` | `92f6e43eaa4895f3353113756001e27184ce3ea0410bd3328c55634130521c63` |
| `I\XPIsland\UI.lua` | `fcf7f19de1f74568035ff66939c1a333bc86c80b5f76c53d9b1301ce84ca1958` |
| `I\XPIsland\Core.lua` | `4f8ff47f78f1e578487b8843e451c31a260356bc0c5b793eae17026250b6e0f1` |
| `I\XPIsland\XPIsland.toc` | `9b73b5c3ca8db7ce437e36623df5f7a51086c622045fcbe824355609b070336f` |
| `I\AsTheCrowFlies\Options.lua` | `373493afde8df5f638b276e1e4ff83e01b1aef0a81da9b1464259b8cbca7b615` |
| `I\AsTheCrowFlies\UI.lua` | `0db47da1af7ce3ce4384ba7fe1f3ad6874454431669fd14533ae9255a1ef8aa0` |
| `I\AsTheCrowFlies\Core.lua` | `9fee6c4d3a2ada64fa7c023b46562623639ce62040dcc008f0b9179f5b5b17cf` |
| `I\AsTheCrowFlies\AsTheCrowFlies.toc` | `a7f892a5c4029b63763d0941153477483d83e11d310da81a1b791a4db0378802` |
| `I\EllesmereUI\EllesmereUI_Panel.lua` | `1b5899e410bb7ad7a5bf0380162b8e06efdc6b000545440f498ee7e6eca7c5c6` |
| `I\EllesmereUI\EllesmereUI_Fonts.lua` | `892c8332c8ba0f5babfcb4f442bef46ecd86e0184a96633a50824223f150384e` |
| `I\EllesmereUI\EllesmereUI.lua` | `fff87172e2e6d7fc8e46049a00948071bd068f40cc25cb193cfbf1ae697da402` |
| `I\EllesmereUIOptions\EllesmereUI_Widgets.lua` | `80f820e475ef0b38d3b2168eaf3c41ffcdcc82d378ae927b8652458fea4dc717` |
| `Q\Options.lua` | `16f10d8b1ad4e5062b162309e25102eb483f29dbd5a8a650ed80d32ff5c62a5a` |
| `Q\UI.lua` | `3f45424068649ac7461bd40ab28ffe3dd948324248be8ba4f0fc5122f25c5e41` |
| `Q\Core.lua` | `5041d59e505c3492bd02000bc50ab38d8acb8de1327993825c1c07031ce02464` |
| `tests/options_test.lua` | `43fc4c2eb7b7313c5d54206d240d2dca0be5f30593fde3ad9a7b5054f0f6ef2b` |
| `tests/wow_mock.lua` | `3eec15fee7965a43ccee0809b7d7cd43c2a271d95273f716aad91f4c41947b49` |

The relevant Blizzard source files were fetched **read only** from revision `735496de78ebd30ce816a0637982c556987f258c` (Forever 1.60.1.70374). Previously materialized menu, checkbox and slider files were compared byte for byte with those current pinned bytes, rather than assumed current from their filenames.

| Current native file under `Interface/AddOns/` | SHA-256 |
| --- | --- |
| `Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml` | `a52e29e44750e81154ce423e1b16f1d2c8126ce893275c8d22070240d55eab4e` |
| `Blizzard_Menu/Classic/MenuTemplates.xml` | `cf11b6890901c28f908e2bef2df64fa54f4d7a0573b2e8fe79f797cef72ce87e` |
| `Blizzard_Menu/Classic/MenuTemplates.lua` | `b3b2862dfdd223fe826ef256bf87f658d73c5232a9b0207f8d532b4d31b0eadd` |
| `Blizzard_Menu/DropdownButton.lua` | `3700afff438469414654a0293c0f18aef52f5e4bca11e0c12ee1d9a4a8dc55d6` |
| `Blizzard_Menu/DropdownButton.xml` | `12446692db6210e5690effcf1bae81945afb6f572b6880cc712312ae81f55720` |
| `Blizzard_Menu/MenuTemplates.lua` | `a26c548ae8d3c90c298c61ac27a3ce4c7533d934c3004f61359d61e944fc81a2` |
| `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml` | `a3f2ce48b1081ea73de3e9fa01549fa3377a2c60443026b3349a1957ff252e49` |
| `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml` | `84850646eeffb435d47a8eadcc62dd6c8fba109b2418cc730db5cbf9fda21a03` |
| `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.lua` | `6b2ba13dc5c78bdefbe3d5e2dfe7ddcc72f6436280790ac9f8fce9d049b570e3` |

## Material comparison

| Area | Actual working reference | QuestBrief 0.1.2 and disposition |
| --- | --- | --- |
| Shell/chrome | XPIsland `Options.lua:163-175`: 620x462 `BackdropTemplate`, centered, DIALOG, dialog border edge 16/insets 4, background `.045,.045,.05,.94`, border `.65,.65,.65,1`. ATCF `Options.lua:43-50` repeats it. | `Options.lua:98-103`: same shell, border, colors, strata, clamping and drag handlers. Height 398 is a deliberate reduction for one settings page. No native tooltip border substituted for the options dialog border. |
| Sections/spacing | XPIsland `Options.lua:50-56,191-193`: section x=16/316, width 288, content x=28/328, tooltip-border edge 10/insets 2, quiet box colors; title sits over the box border. | `Options.lua:38-43,108-123`: exact section geometry/chrome pattern. Sections start at y=-58 instead of -80 because no tab strip is needed. Eight checkbox rows, two slider/input pairs and one dropdown fit inside two sections; bottom launcher row ends above the section bottom. |
| Labels and font initialization | XPIsland `UI.lua:124-132` applies font before text; `Options.lua:29-34` adds text afterward. ATCF `Options.lua:6-9` does the same. | `Options.lua:21-28`: inherits `GameFontNormal`, applies owned font before `SetText`, and uses the reference's white/gold/muted colors and shadow. The inherited font is an additional construction safeguard, not a different selected face. The first title no longer uses a bare fontless string. |
| Native font default | XPIsland `UI.lua:172-187` resolves `GameTooltipTextLeft2` or `GameTooltipText`; its default is not the mere presence of Expressway in SharedMedia. `UI.lua:19-65` validates actual font readback, tolerating positive native rounded sizes. | `UI.lua:29-63`: same native default and checked path assignment/readback, positive native height, fallback path then native Font object. Controls remain 12px, hints 11px, title 16px. No shared native Font object is changed. A font selector/profile font preference is omitted to keep QuestBrief's approved settings small. |
| Font changes after construction | XPIsland checks actual path/size/flags before using its assignment cache (`UI.lua:29-39`), and reapplies control fonts before measurement (`Options.lua:339-351`). ATCF `Core.lua:44-57` repairs fonts around control refresh. | `UI.lua:48-62`, `Options.lua:156-175`: also checks actual readback and replays owned fonts after fallback; bounds are measured after repair. `WatchFonts` and `ADDON_LOADED` refresh existing options. Separate global state for owned controls is required because QuestBrief has its own namespace and no runtime XPIsland dependency. |
| Checkbox/template anchors | XPIsland `Options.lua:106-118`: `UICheckButtonTemplate`, 24x24, inherited caption, width 250, extended hit rect. Native `CheckButtonTemplates.xml:50-63` supplies `Text` at LEFT relative to RIGHT with x=-2. ATCF reanchors explicitly for its 230px caption variant (`Options.lua:36-41`). | `Options.lua:67-74`: follows XPIsland's 250px allocation and inherited anchor. This is an explained choice between the two working references, not an omitted text anchor. Bound text is one line, and its height fits the 24px row. |
| Dropdown art/text allocation | XPIsland `Options.lua:71-99` uses `DropdownButton`/`WowStyle1DropdownTemplate`, 24px height, left inset 9, width minus 31 for arrow clearance; clears inherited TOP anchors. Native Classic XML `MenuTemplates.xml:3-41` starts with 10px Text and TOP anchors. | `Options.lua:45-62`: same frame type, template, size, anchor reset, text alignment and arrow clearance. This directly prevents the previous native-top-anchor/large-font clipping class of defect. |
| Menu semantics and font API | XPIsland builds native radio descriptions, scroll height 220, checked predicate over current state and owned menu Font via compositor `SetFontObject`. Native `DropdownButton.lua:237-268` generates the description; native menu manager owns opening, closing, row pooling and selection. Ellesmere custom menus instead own UIParent overlays and hide/scroll guards (`EllesmereUI_Widgets.lua:499-504,1273-1376`). | `Options.lua:52-65`: same native-radio/menu-font/scroll API as XPIsland. Four fixed reveal-key entries are a static list, so a list-provider function is unnecessary. No custom popup overlay or simulated dropdown-row buttons are introduced. |
| Native dropdown construction/show timing | Native `SetupMenu` immediately generates if `IsShown()` is true; native `DropdownSelectionTextMixin:OnShow` generates again as needed (`Blizzard_Menu/MenuTemplates.lua:869-873`). | `menuFont` is created before the dropdown and its menu initializer (`Options.lua:104,116`). The complete `Options.frame` is published before the hidden shell opens (`153,179`), so parent refresh runs against complete controls. The mock currently defers `SetupMenu` unconditionally; independent execution of the native method did not reveal an ordering failure. |
| Buttons | XPIsland `Options.lua:37-47`: 22px custom `BackdropTemplate` button, bounded centered label, subdued border with gold hover. | `Options.lua:29-36,124`: same Reset button constructor. Reset changes QuestBrief's validated profile through Core. There is no unrelated Profiles/Tracking navigation. |
| Sliders/numeric fields | XPIsland `Options.lua:59-67,216-229`: `UISliderTemplate` 180x16, horizontal, stepped drag, `InputBoxTemplate` 58x22, 6px text insets, no autofocus, max 48 letters, Enter commit/clamp, Escape refresh. Native `SharedUIPanelTemplates.xml:330-343` provides the horizontal 32x32 thumb, hit extension and slider art. | `Options.lua:76-96`: same control types/sizes/insets/focus conventions. Scale 80-120% and strength 10-100%, 5-point drag step are QuestBrief's existing product ranges. Retaining native horizontal thumb is consistent with XPIsland's scale slider; the unrelated vertical stack scrollbar uses its own dimensions. |
| Input inherited scripts | Current `InputBoxTemplates.xml:3-9,39-66` supplies focus highlight/clear, Tab navigation and Chat font inheritance; it supplies **no OnShow font assignment**. ATCF queues a next-frame refresh in `Options.lua:138-142` as an additional repair. | QuestBrief preserves focus scripts while replacing only Enter/Escape for its numeric setting behavior. Its parent OnShow refresh applies the desired owned fonts. Absence of ATCF's extra deferred pass is not a proven defect from the current native input template; no unsupported blanket claim about every child template resetting fonts is needed. |
| Opening/cache/lifecycle | XPIsland `Options.lua:308-311,374-377`: lazy construction, OnShow refresh, toggle shown state, cached controls, `UISpecialFrames` Escape. ATCF builds once at addon initialize and opens explicitly (`Core.lua:292`, `Options.lua:215-229`). Ellesmere hides its root before construction, caches pages and opens after construction (`EllesmereUI_Panel.lua:183-223,5230-5245`). | `Options.lua:132-179`: lazy cached opening matches XPIsland; hidden shell prevents incomplete display and successful publication registers Escape once. The failed-construction adaptation has the ownership defect below. No persistent per-frame options work is introduced. |
| Closing/focus/moving | XPIsland OnHide closes dropdowns and clears profile-copy confirmation; ATCF additionally clears edits and owned color picker. Ellesmere's OnHide callback chain closes panel-owned popups; cached page trees survive closing. | `Options.lua:127-129`: closes native dropdowns, releases both numeric fields and stops movement for every Hide path. Explicit close uses the same Hide path; native Escape registration reaches it. QuestBrief has no color picker, unsaved profile-copy confirmation or other transient editor to restore. |
| Fitting/scrolling/placement | XPIsland uses fixed page allocations and `.3..1` fitting to usable UIParent dimensions (`Options.lua:358`), native unbounded measurement with physical-pixel padding and fit-adjusted offsets (`UI.lua:71-98`). No options scroll frame. ATCF uses comparable fitting; Ellesmere uses a larger sidebar/scroll framework. | `Options.lua:9-20,170`, `UI.lua:65-82`: same XPIsland fitting and inset compensation. A scroll frame, resize handle or stored options-window coordinates would add functionality that the chosen small reference does not have. Dragged options placement lasts for the session as in XPIsland. This does not affect separately persisted launcher position. |
| Configuration/init ownership | XPIsland controls use current owner profile and a refreshing guard around programmatic SetValue. ATCF's model/settings module owns profiles; core initializes after restored variables. | `Core.lua:19-38,77-94`, `Options.lua:73,86-94,169-175`: Core loads/validates after matching ADDON_LOADED, controls read current profile rather than an old replaced table, Change/Defaults own writes and runtime apply. Future schemas remain read-only. This additional model protection is justified by QuestBrief's migration contract, not an alternate UI framework. |

## Concrete finding

**P2 — repeated failed construction retains unbounded hidden options subtrees.**

- **Location:** `Options.lua:137-151`, especially creation of a fresh `parent` at line 138 on every retry.
- **Trigger:** a persistent exception in `Build`, including after controls have already been allocated; the player repeats the options slash command while the exception remains.
- **Consequence:** the shell stays hidden, but the parent content and all its child frames/FontStrings remain permanently allocated. Hiding them and removing entries from `U.fontSizes`/`U.fontApplications` does not destroy native UI objects. The next retry constructs another full tree. A successful eventual retry leaves all prior failed trees attached and hidden.
- **Independent reproducer:** under Lua 5.1, temporarily replace `O.Build` with a function that calls its actual `Label` constructor once, then throws. Invoke actual `SlashCmdList.QUESTBRIEF("opts")` through `pcall` twenty times. Measured **20 hidden content frames**, **21 new frames including the reused shell**, and **21 FontStrings including the font probe**. Restore Build and open successfully: **21 content frames retained**. No production edit was required to reproduce it.
- **Reference comparison:** Ellesmere explicitly retains and reuses page trees because native frames cannot be freed (`EllesmereUI_Panel.lua:221-223`). XPIsland constructs once on the normal path. QuestBrief's retry-specific allocation is an unexplained ownership deviation; it is not needed to prevent the previous blank shell.
- **Requested correction:** bound failed-construction ownership. Reuse/resume a retained partial construction, or otherwise prevent repeated persistent failures from allocating another full hidden subtree indefinitely. Preserve the hidden shell, propagate the original error, and permit recovery after the fault is removed. A production fix should have a repeated-failure regression, not merely one failure followed by success.

## Independent execution and regression gaps

I executed source-focused checks under Lua 5.1 with the repository fixture and additional inherited defaults taken from the exact native XML. These are offline checks of control construction and state transitions, not estimates of whether a screenshot looks good.

- Seeded native dropdown Text with TOPLEFT x=9/y=-7 and 10px height, and checkbox Text with LEFT/RIGHT x=-2 before running the actual slash constructor. The dropdown changed to the intended centered LEFT anchor and 24px allocation; the checkbox retained the expected XPIsland inherited anchor.
- Executed the exact pinned `DropdownButtonMixin:SetupMenu` and `OnMouseDown_Intrinsic` methods against the real options constructor. Immediate generation selected Shift correctly; native Shift-held mouse-down left the menu closed, and normal mouse-down toggled it. This checks behavior the fixture's deferred `SetupMenu` omits.
- Changed the constructed title's font height/flags to 33/OUTLINE, then refreshed. The readback check repaired it to the requested title family/rounded 16px height/empty flags. Exact native font height need not equal an integer; the fixture returns 15.984 for a 16px assignment and the assertion accepts valid readback.
- Entered uncommitted numeric text, closed through the actual close-button handler and reopened through the slash entry. Focus cleared, the saved value was restored and SavedVariables identity was unchanged.
- Opened and closed the completed options thirty times; frame count stayed constant.
- Repeated-failure reproduction above did grow permanent allocations and is the sole actionable production finding from this options review.

The eleven existing options scenarios protect font-before-text, the initial blank-shell bug, one early and one late failure/retry, current profile binding, native font fallback, future schema read-only state, the selected XPIsland layout constants, Enter/Escape editing, close/menu/focus cleanup and approximate bounded text fitting. Their coverage needs strengthening at these specific boundaries:

1. **Repeated constructor failure:** missing and demonstrably fails in production, as above.
2. **Inherited template defaults:** `CreateFrame` synthesizes `.Text` with no real checkbox anchor and treats native menu setup as deferred. A wrong or missing anchor reset could pass generic geometry assertions. Seed the current XML defaults and use pinned native menu methods where relevant.
3. **Actual Escape dispatch:** testing a direct `frame:Hide()` plus membership in `UISpecialFrames` establishes registration and cleanup separately. It does not exercise the native Escape/menu precedence dispatcher; an integration fixture can exercise that source path if changed. Current code uses the same registration pattern as XPIsland.
4. **Menu initializer timing:** the current mock calls the row initializer during description generation rather than pooled menu-row acquisition. It correctly rejects compositor SetFont lookup, but should preserve native deferred initializer timing if menu ownership is changed.
5. **Geometry fidelity:** generic mock `SetAllPoints`, hit rectangles and drag methods do not resolve or record their actual behavior. Constants/assertion counts do not independently prove reachable controls. Source comparison and the independent inherited-anchor checks supply evidence for the present choices; later changes should use resolved bounds rather than overwrite test rectangles with the desired result.

## Assessment and remaining confirmation

Source establishes the first-title font precondition, correct current native dropdown construction, familiar XPIsland chrome and widget allocations, complete publication before opening, current-profile persistence, proper programmatic refresh guards, close-time popup/focus cleanup and normal frame caching. These are concrete reasons to trust those parts of the corrected options implementation. The failed-retry allocation finding still needs a production fix and re-review.

Supplementary client checks are the settled appearance under the player's exact fonts/UI scale, physical drag and keyboard/menu input, and simultaneous interference from other addons' later hooks. No game actions, native frame mutations, SavedVariables writes, unrelated addon edits or reloads were performed by this audit. Lack of a live capture is not a substitute for source review and is not used here as a gate on the identified fixes.

## Final re-review of the source fixes

The root task repaired the P2 failed-construction ownership finding. This final disposition supersedes the baseline finding's open status above: **resolved; no remaining actionable finding in the reviewed options scope**.

Reviewed bytes after the repair:

| Source | SHA-256 |
| --- | --- |
| `QuestBrief/Options.lua` | `c07faa256d7d97ff460727104b7df2208be5cb297a6d32ede7ecf26c10e06459` |
| `QuestBrief/UI.lua` | `b4275dd473fd3fd1ba38006215b902d5f34322bd788d9ea45b8b80c5642536a4` |
| `tests/reference_widgets_test.lua` | `f1cfdbdb93cbf8c3da2661872ec0351cb45c1d57a28499c7c273cb9766cfaf12` |

`Options:Create` now retains **one content parent**. `Frame` and `Text` retain deterministic constructor slots; retries reset the indices and use the same objects. The frame slot verifies type, parent and template before reuse, and the text slot verifies parent. The fixed Build sequence contains no profile-dependent constructor branches, so the same slot cannot silently switch widget type or owner on retry. Native inherited controls and their caption FontStrings remain attached to the same retained widget. FontString construction is recorded in its slot before label font application, so the original font failure can recover without allocating another title.

The shell remains hidden until complete publication. Failed content is hidden, option event registrations and OnShow/OnEvent handlers are cleared, transient menu/focus cleanup still belongs to the shell, and owned font registrations are removed. Successful reconstruction replaces owned control handlers and dropdown generators through the same setters used for initial construction; it does not add duplicate native hooks or rerun native OnLoad for reused frames. Recovered controls receive current profile values through the existing guarded OnShow refresh. Escape registration still occurs once after successful construction. Normal openings never run Build again.

The added `UI:Dialog` helper contains the exact XPIsland/ATCF options-shell backdrop and colors already audited above. Options passes its existing `BackdropTemplate` shell. Sharing those constants does not add a different frame type, skin or lifecycle. The new vertical scrollbar helper is outside this options finding; horizontal options sliders still use XPIsland's `UISliderTemplate` construction unchanged.

Executed checks:

- All **11 options scenarios** and all **7 reference-widget scenarios** passed in fresh Lua 5.1 runtimes.
- The new regression suite repeats an early failure 30 times and a late event-registration failure 30 times; retained frame/FontString counts stop growing after the first attempt, no incomplete frame is published, font/event registrations are cleaned, recovery opens successfully and warm toggles reuse completed objects.
- Independently injected persistent errors **after actual font application** at six different constructor positions (calls 2, 5, 9, 14, 18 and 23), twelve failed slash invocations per position. These exercise early labels and progressively later widgets rather than only throwing after the first label. Every position retained stable frame/FontString counts, kept shell/content hidden, preserved SavedVariables identity, retained no option event registrations or owned font registrations, and registered no Escape frame before success.
- After removing each of those six independent faults, successful construction used unique frame/text slots and registered Escape once. Actual recovered checkbox, radio selection and numeric Enter handlers updated the current profile correctly; numeric focus cleared, closing/reopening worked, and no stale handler or owner binding was observed in the inspected source or executed fixture.

The original reproduction now remains bounded instead of accumulating a hidden subtree per attempt. The correction is confined to construction recovery and shared dialog chrome; no new option or unrelated addon dependency was introduced. Source review and the focused regressions support closing this finding. Supplementary client checks remain as described above and do not reopen an established source-level ownership defect.
