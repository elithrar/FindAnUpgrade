# QuestBrief

A reward finder and compact quest previews for World of Warcraft: Forever.

- Search quest and reward names. Filter by quest level, class usability and equipment slot, including empty slots.
- Browse guaranteed and choose-one rewards separately, with small item icons, rarity borders and native item tooltips and comparisons. XP, money and reputation appear when known.
- See verified new quests in orange, modified quests in green and existing quests without a tint. Quest dialogs can use the same subtle colors.
- Choose the reveal key, preview surfaces, reward details, tint strength and scale in settings.

## Installation

Copy `QuestBrief` into your Forever client's `Interface/AddOns` folder, then restart WoW. `QuestBrief.toc` must be directly inside `QuestBrief`.

## Usage

Use `/questbrief search` or click the book icon on the minimap to open the reward finder. Expand cards to see more rewards and choose among recorded giver locations when available. Right-click a quest title or location to copy its Wowhead link or coordinates, or set a waypoint where supported.

Hold **Shift** over an NPC with known quests or a supported world-map marker to show a stack of quest cards. Release Shift to inspect rewards; **Escape** or moving away closes it. Long stacks scroll.

Questie is optional. QuestBrief can preview its existing world-map and minimap markers; minimap quest previews require Questie. Search works without it.

Use `/questbrief` or `/questbrief opts` for settings. Ctrl, Alt and hovering without a modifier are alternatives to Shift.

## Development

Run `python tools/verify.py` from the repository root with Python 3.11 or newer and Lupa. It runs the checks and builds ZIPs in `dist/`.

See [AGENTS.md](https://github.com/elithrar/QuestBrief/blob/main/AGENTS.md) for development rules, [database sync](https://github.com/elithrar/QuestBrief/blob/main/docs/DATABASE-SYNC.md) for dependency setup and data maintenance, and [validation coverage](https://github.com/elithrar/QuestBrief/blob/main/docs/VALIDATION.md) for checks and pending in-game validation.

## License

BSD-3-Clause. See [LICENSE](LICENSE). Third-party data licenses and attribution are in [NOTICES.md](https://github.com/elithrar/QuestBrief/blob/main/QuestBrief/NOTICES.md).
