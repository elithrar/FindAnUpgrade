# QuestBrief

Quest previews and a reward finder for **World of Warcraft: Forever**, interface **16001**. Version **0.1.3** follows the installed working UI references, fixes native comparison preferences and styling, vertical scrollbars, cancelled range edits, bounded options retries and classification fill hues.

- Search quest and item names, filter equipment or empty slots, and narrow results by item usability and native quest level.
- Inspect a vertical stack of quest cards from a known NPC or world-map marker, including Questie's world-map and minimap markers.
- See verified new quests in orange, modified quests in green, and existing quests without a tint. Text labels accompany the colors.
- Browse guaranteed and choose-one rewards separately, with small item icons, rarity borders and native item tooltips. Shift retains equipment comparison behavior.
- Adjust the reveal key, individual surfaces, reward details, quest colors, dialog tint and panel scale in settings.

## Reward finder

Open with `/questbrief search` or `/questbrief s`, or click the book icon on the minimap. Drag the icon to reposition it; `/questbrief minimap` or `/questbrief mm` toggles its visibility. Sort results by level fit or quest level. Expand cards to inspect rewards and choose among recorded giver locations when available; their menus offer location and quest-page copy actions.

The finder ships its own partial catalog derived from MIT-licensed AllTheThings Forever authoring data. Search does not require Questie or QuestieDB. The catalog records exact quest/item associations and selected giver/restriction metadata; it does not establish current availability, reward quantities or guaranteed-versus-choice groups. Native data supplies those details when available. Missing names, levels, usability or rewards can limit results and are never treated as zero.

## Hover previews and settings

Hold **Shift** while hovering, or press it after hovering, to reveal a stack. Release Shift to inspect rewards; the stack stays in place. **Escape** or moving away closes it, with a short grace interval for pointer travel. Long stacks scroll. Ctrl, Alt and hover without a modifier are available alternatives.

Use `/questbrief` or `/questbrief opts` for settings. `/questbrief on`, `off` and `status` are also available. Settings are account-wide in `QuestBriefDB`.

## Installation

Build the candidate ZIP using the development commands below. Copy its `QuestBrief` folder into the Forever client's `Interface/AddOns` folder, then restart WoW. `QuestBrief.toc` must be directly inside `QuestBrief`.

## Coverage

Classification uses exact quest variants from a verified 2026-10-14 snapshot: **1,194 IDs**, including **218 new IDs**. Unknown IDs remain untinted. Titles and group-level classifications are never used to infer a variant's status.

The catalog's source build **1.60.1.69893** predates the current **70374** API contracts. Locations and reward coverage still need live verification. The source checkout's `data/catalog-coverage.json` records the measured subset; this is not a complete Forever quest database or an upgrade-score calculation.

NPC previews use exact bundled starter records, current gossip IDs, or reciprocal starter records from an optional compatible Forever QuestieDB. Exact identity is separate from current availability: native quest log/gossip/available map offers and freshly rendered Questie markers can establish a current state. Static associations cannot establish availability; known completed, disabled or ineligible rows are excluded, and specific recorded chain links can be shown without claiming a server requirement. Native world-map pins and hubs must expose exact quest IDs. Native minimap markers are unsupported; minimap previews require Questie. The adapter targets Questie **12.1.0** and creates no quest map icons.

Money, XP and currencies appear when the client supplies usable reward data. Hover cards omit unavailable fields and empty rows; missing data never becomes zero. Money uses the current native coin renderer. Ambiguous mixed item/currency choices are withheld. Ordinary faction reputation amounts remain unverified and are omitted. Native quest contrast mode takes priority over dialog tint.

## Development

Run from the source root with Python 3. If needed, install Lupa locally first:

```powershell
python -m pip install --target .work/pydeps lupa==2.8
python tools/verify.py
```

The builder writes addon and source ZIPs, hashes and a receipt to `dist/`; it does not install or publish them. The source checkout includes `docs/VALIDATION.md` for pending live scenarios, `docs/PROVENANCE.md` for classification/API evidence, `data/catalog-sources.json` for catalog provenance, and `docs/RELEASING.md` for development/release workflow and CurseForge setup.

Before the first CurseForge publication, user-authorized iterations primarily use patch version bumps and direct commits to `main` after the required review and checks. Branch protections still apply; use a reviewed PR when required. Publication, release tags, credentials and game installation need their own authorization.

Source inspection and offline tests do not establish native rendering, event timing or combat/taint safety. In-game finder, hover, reward comparison, scrolling and coexistence checks remain pending.

## License

Original code and documentation: BSD 3-Clause. See [LICENSE](LICENSE). The ATT-derived catalog retains its separate MIT grant in the addon's `Data/ATT-LICENSE.txt`; other attribution remains in `NOTICES.md` and `XPISLAND-LICENSE.txt`.
