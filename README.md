# QuestBrief

Compact quest previews for **World of Warcraft: Forever**, interface **16001**.

- Inspect a vertical stack of quest cards from a known NPC or world-map marker, including Questie's world-map and minimap markers.
- See verified new quests in orange, modified quests in green, and existing quests without a tint. Text labels accompany the colors.
- Browse guaranteed and choose-one rewards separately, with small item icons, rarity borders and native item tooltips. Shift retains equipment comparison behavior.
- Adjust the reveal key, individual surfaces, reward details, quest colors, dialog tint and panel scale in settings.

Hold **Shift** while hovering, or press it after hovering, to reveal a stack. Release Shift to inspect rewards; the stack stays in place. **Escape** or moving away closes it, with a short grace interval for pointer travel. Long stacks scroll. Ctrl, Alt and hover without a modifier are available alternatives.

Use `/questbrief` or `/questbrief opts` for settings. `/questbrief on`, `off` and `status` are also available. Settings are account-wide in `QuestBriefDB`.

## Installation

Build the candidate ZIP using the development commands below. Copy its `QuestBrief` folder into the Forever client's `Interface/AddOns` folder, then restart WoW. `QuestBrief.toc` must be directly inside `QuestBrief`.

## Coverage

Classification uses exact quest variants from a verified 2026-10-14 snapshot: **1,194 IDs**, including **218 new IDs**. Unknown IDs remain untinted. Titles and group-level classifications are never used to infer a variant's status.

NPC previews require current gossip quest IDs or reciprocal starter records from a compatible Forever QuestieDB. Database associations are labelled **availability unconfirmed**. Native world-map pins and hubs must expose exact quest IDs. Native minimap markers are unsupported; minimap previews require Questie. The adapter targets Questie **12.1.0** and creates no map icons.

Money, XP and currencies appear when the client supplies usable reward data. Missing data is shown as unavailable, never assumed to be zero. Ambiguous mixed item/currency choices are withheld. Ordinary faction reputation amounts remain unavailable. Native quest contrast mode takes priority over dialog tint.

## Development

Run from the source root with Python 3. If needed, install Lupa locally first:

```powershell
python -m pip install --target .work/pydeps lupa==2.8
python tools/verify.py
```

The builder writes addon and source ZIPs, hashes and a receipt to `dist/`. It does not install or publish them. In the source checkout, `docs/VALIDATION.md` records checks and pending live scenarios, `docs/PROVENANCE.md` records data and API evidence, and `docs/RELEASING.md` documents CurseForge setup.

Source inspection and offline tests do not establish native rendering, event timing or combat/taint safety. In-game hover, reward comparison, scrolling and coexistence checks remain pending; no game installation or release has been performed.

## License

Original code and documentation: BSD 3-Clause. See [LICENSE](LICENSE); third-party attribution is retained in the addon's `NOTICES.md` and `XPISLAND-LICENSE.txt`.
