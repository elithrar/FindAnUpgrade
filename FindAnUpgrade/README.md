# FindAnUpgrade

💾 **[Download the latest version](https://www.curseforge.com/wow/addons/findanupgrade) on CurseForge**

A compact quest and reward browser for World of Warcraft: Forever.

- Find quests in your zone or level range. Search rewards and filter by equipment slot or usability.
- Compare guaranteed and choose-one rewards with native item tooltips and equipped-item comparisons.
- Spot new quests in orange and modified quests in green, with matching quest dialog colors.
- Save quests to your character's Shortlist and inspect quest chains.
- Choose fonts, borders, scale and preview settings in one Options window.

Open it with `/fau` or click the _FindAnUpgrade_ button on your minimap.

## Screenshot

<img width="600" alt="fau_overview" src="https://github.com/user-attachments/assets/f19cd5f8-11e8-41f1-8ec4-b8bbfe8f4839" />

## Installation

Install [FindAnUpgrade from CurseForge](https://www.curseforge.com/wow/addons/findanupgrade), then restart WoW. For a manual install, copy `FindAnUpgrade` into your Forever client's `Interface/AddOns` folder. `FindAnUpgrade.toc` must be directly inside `FindAnUpgrade`.

Use `/fau` or click the minimap book to open the browser. Hover rewards for item details, click a star to save a quest, and right-click a quest for copy and waypoint actions. Hold Shift over an NPC or supported map marker for a preview; release it to inspect rewards. Escape closes inspection. Questie adds minimap quest previews.

Use the cog or `/fau opts` for settings. Ctrl and Alt are available as alternative preview keys.

## Contributing

To help fill gaps in quest data, open `/fau opts`, scroll to **Contribute quest data**, and enable **Record encountered quests**. Recording is off by default. Pause with the same checkbox or `/fau off`; **Export** opens a manual JSON copy view. Save the text to a `.json` file and review it before sharing. **Clear**, then **Confirm clear**, removes the observations and pauses recording. Resetting appearance settings does not change this separate data store.

The recorder captures quests you encounter through native dialogs and gossip, with build/locale, NPC or item source, observer map position, faction/class/race/level, and player-visible reward slots and quantities. It omits player identity fields, GUIDs, account details, chat and quest prose; your name is redacted if it occurs in a canonical quest title. No data is uploaded automatically. Observations stop at 250 records, 256 KiB of JSON, or 12 variants per quest and stage; export and clear to resume. WoW saves these observations through its normal SavedVariables lifecycle.

Incomplete slots stay unknown. Listed, offered, accepted, completion-dialog and turned-in observations are distinct; offered choices do not identify the selected reward. Observer positions are not NPC spawn coordinates, and observer context does not establish availability for every character. Player-visible rewards may differ from published base rewards; other reward types remain unknown. Submissions require independent review before any catalog change.

Open an issue before submitting a PR. Unsolicited PRs may be closed.

## Development

Run `uv run --locked python -m fau_tools check` from the repository root for lint, formatting, tests and ZIPs in `dist/`.

Use `uv run --locked python -m fau_tools observations submission.json` to validate a manual export and print a read-only comparison with the bundled catalog. This accepts bounded JSON only, rejects unknown fields, and never executes SavedVariables Lua or updates catalog files. Treat the comparison as leads for source review, not proof of a current-build database change.

See [AGENTS.md](https://github.com/elithrar/FindAnUpgrade/blob/main/AGENTS.md) for setup, catalog imports and contributor guidance.

## License

BSD 3-Clause. See [LICENSE](LICENSE). Third-party attribution is in [NOTICES.md](https://github.com/elithrar/FindAnUpgrade/blob/main/FindAnUpgrade/NOTICES.md).
