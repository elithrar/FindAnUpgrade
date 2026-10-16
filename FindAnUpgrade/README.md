# FindAnUpgrade

💾 **[Download the latest version](https://www.curseforge.com/wow/addons/findanupgrade) on CurseForge**

A compact quest and reward browser for World of Warcraft: Forever.

- Find quests in your zone or level range. Search rewards and filter by equipment slot or usability.
- Compare guaranteed and choose-one rewards with native item tooltips and equipped-item comparisons.
- Spot new quests in orange and modified quests in green, with matching quest dialog colors.
- Save quests to your character's Shortlist and inspect quest chains.
- Choose fonts, borders, scale and preview settings in one Options window.

## Installation

Install [FindAnUpgrade from CurseForge](https://www.curseforge.com/wow/addons/findanupgrade), then restart WoW. For a manual install, copy `FindAnUpgrade` into your Forever client's `Interface/AddOns` folder. `FindAnUpgrade.toc` must be directly inside `FindAnUpgrade`.

Use `/fau` or click the minimap book to open the browser. Hover rewards for item details, click a star to save a quest, and right-click a quest for copy and waypoint actions. Hold Shift over an NPC or supported map marker for a preview; release it to inspect rewards. Escape closes inspection. Questie adds minimap quest previews.

Use the cog or `/fau opts` for settings. Ctrl and Alt are available as alternative preview keys.

## Contributing

Open an issue before submitting a PR. Unsolicited PRs may be closed.

## Development

Run `uv run --locked fau check` from the repository root for lint, formatting, tests and a local ZIP in `dist/`.

See [development setup](https://github.com/elithrar/FindAnUpgrade/blob/main/docs/DEVELOPMENT.md), [database sync](https://github.com/elithrar/FindAnUpgrade/blob/main/docs/DATABASE-SYNC.md) and [validation coverage](https://github.com/elithrar/FindAnUpgrade/blob/main/docs/VALIDATION.md).

## License

BSD 3-Clause. See [LICENSE](LICENSE). Third-party attribution is in [NOTICES.md](https://github.com/elithrar/FindAnUpgrade/blob/main/FindAnUpgrade/NOTICES.md).
