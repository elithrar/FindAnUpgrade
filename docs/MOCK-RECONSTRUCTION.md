# Current sidebar reconstruction

The October 15, 2026 design images are **code-driven reconstructions, not in-game captures**. They illustrate the current sidebar after the FindAnUpgrade rename and the simplified item-level ranking iteration. They do not establish native rendering, quest availability, equipment legality, input behavior or taint safety.

## Images

- `dist/FindAnUpgrade-current-sidebar-4x.png`: 2200 × 3040 pixels, containing the actual default 476 × 680 logical-unit panel at four pixels per unit. Its SHA-256 is `aaa69fa7e508d30113b9e095fbfdf72c14ddefd9041ee4fc44e4a853cb5ea6a0`.
- `dist/FindAnUpgrade-current-sidebar-sort-menu-4x.png`: the same frozen base image with the current executed sort menu description, including its four choices and the checked Biggest upgrade option. Its SHA-256 is `158a66600d4c0f49c5ceb4e8db71542696ee19a38f3753456c557e142145a166`.
- Adjacent JSON receipts record source hashes, fixture hashes, artwork and explicit reconstruction limits. Native Library version-zero copies are recorded in `dist/FindAnUpgrade-mock-library-receipt.json`: main `libfile_240bc97d80608191b18ba92b3f8b27d5`, sort `libfile_aac9289930b88191b06cec26bc197acc`. These local image outputs remain outside the shipped addon.

Both images visibly identify themselves as reconstructions. The first files are frozen after delivery; subsequent rendering defaults to a separate `FindAnUpgrade-current-sidebar-reconstruction-v2` basename.

## How the images were constructed

`tools/render_sidebar_mock.py` executes the shipped `Search.lua` constructor, control layout, card filling and scroll layout using the existing Lua 5.1 mock. It replaces the mock's approximate string measurements with Pillow measurements of the observed configured Expressway font. The adapter receives Lua-function wrappers around those measurements, preserving its callable-type guard. The renderer supplies the scroll child's engine-managed attachment explicitly because the small mock does not model that implicit attachment.

The five earlier user screenshots were inspected for context. The installed EllesmereUI configuration names Expressway as the global game text face with `applyToAllGameText=true`. A read-only copy of that installed font is used solely under `.work/mock-reconstruction-assets`; the actual runtime tooltip font remains a live-client question. Native number strings are approximated with Windows Arial because the native number font file was unavailable. Font rasterization and line-height behavior remain reconstructions.

The example intentionally selects **Level range, 14–22**, allowing the mixed zones shown in the earlier screenshots. It shows seven exact Alliance quest records: 150, 95250, 98028, 256, 97005, 963 and 96393. Their reward groups, quantities, XP, money and reputation values come from the owned catalog. Item quality, item level and icon identity come from exact Forever item tooltip responses. Quest 256 is the exact primary Updated variant; 98028 and 97005 are New. IDs absent from primary classification authority remain plain. No title-group status is propagated.

The character, usability and result membership are illustrative. No equipment comparison was performed, so the visible count explicitly reports all seven as not rated. The image does not assert that those seven quests are currently obtainable by the user's character. Rows use the current source's natural reward layout, including vertical separation when Guaranteed and Choose one labels do not fit side by side.

## Artwork and remaining differences

The first delivered image uses retrieved native dialog/tooltip borders, cog, close button, checkbox art, item rarity border, scrollbar thumb and exact item icon imagery. Source and hash receipts are in the private `.work/mock-reconstruction-assets/receipts.json` input. These assets are not shipped with the addon.

The first image approximates the input-box border, dropdown border/arrow, silver coin and red/yellow sort glyph. Native backdrop composition, rounding, transparency, frame clipping and scrollbar track rendering are also reconstructed rather than produced by the WoW renderer. The companion's popup placement, title sizing, radio art and menu layout are estimated from its current executed description. It preserves the actual menu copy and choices, with no scoring-style submenu.

## Reproduction

The utility requires the locally staged private fixture, asset manifest and fonts in `.work/mock-reconstruction-assets`, plus the existing `.work/pydeps` Pillow/Lupa dependencies. It deliberately does not download proprietary fonts or bundle game art.

```powershell
python tools/render_sidebar_mock.py
python tools/render_sidebar_mock.py --sort-menu-only
```

The first command creates the separate v2 output; it does not overwrite the delivered base image. The second command reads the frozen base image and reconstructs the current sort description. Source changes can make that companion inconsistent with its base, so compare the JSON source hashes before presenting a newly generated companion as one settled design.
