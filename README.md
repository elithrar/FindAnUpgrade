# FindAnUpgrade

A quest and reward browser with compact previews for World of Warcraft: Forever.

- Browse the current zone by default, or switch to a level range. Filter quest and reward names, usability and equipment slots, including empty slots. Dungeon quests are an optional addition where their identity is known.
- Browse guaranteed and choose-one rewards separately, with small item icons, rarity borders and native item tooltips and comparisons. XP, money and reputation appear when known.
- See verified new quests in orange, modified quests in green and existing quests without a tint. Quest dialogs can use the same subtle colors.
- Choose the reveal key, preview layout and position, surfaces, reward details, tint strength and scale in settings.

## Installation

Copy `FindAnUpgrade` into your Forever client's `Interface/AddOns` folder, then restart WoW. `FindAnUpgrade.toc` must be directly inside `FindAnUpgrade`.

## Usage

Use `/fau` or `/findanupgrade`, or click the book icon on the minimap, to open the browser. The `search` and `s` subcommands also work. Hover reward icons for native item details and comparisons. Right-click a quest title or starter location to copy its Wowhead link or coordinates, or set a waypoint where supported.

The sort menu defaults to Biggest upgrade. It estimates item-level gain against usable equipped slots; paired rings, trinkets and hands respect equipment rules. It is a simple gear-level hint, not a prediction of damage or healing. Unknown item levels, variants or equipment legality stay unranked. Guaranteed and choose-one rewards remain separate.

Hold **Shift** over an NPC with known quests or a supported world-map marker for a compact preview in the existing game tooltip. Release Shift to inspect rewards in a persistent panel; it also handles sources without a matching game tooltip. **Escape** or moving away closes inspection. Long stacks scroll.

Questie is optional. FindAnUpgrade can preview its existing world-map and minimap markers; minimap quest previews require Questie. Search works without it.

Use the cog, `/fau opts` or `/findanupgrade options` for settings. Ctrl, Alt and hovering without a modifier are alternatives to Shift.

Version **0.1.9** uses the FindAnUpgrade folder and commands. When replacing QuestBrief, preserve its saved files and migrate them using the validated development installer before removing the old active folder. Existing FindAnUpgrade settings take priority. Unsupported future settings remain read-only and are preserved.

## Development

Run `python tools/verify.py` from the repository root with Python 3.11 or newer and Lupa. It runs the checks and builds ZIPs in `dist/`.

See [AGENTS.md](https://github.com/elithrar/QuestBrief/blob/main/AGENTS.md) for development rules, [database sync](https://github.com/elithrar/QuestBrief/blob/main/docs/DATABASE-SYNC.md) for dependency setup and data maintenance, and [validation coverage](https://github.com/elithrar/QuestBrief/blob/main/docs/VALIDATION.md) for checks and pending in-game validation.

## License

BSD-3-Clause. See [LICENSE](LICENSE). Third-party data licenses and attribution are in [NOTICES.md](https://github.com/elithrar/QuestBrief/blob/main/FindAnUpgrade/NOTICES.md).
