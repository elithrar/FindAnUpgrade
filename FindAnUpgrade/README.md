# FindAnUpgrade

A quest and reward browser with compact previews for World of Warcraft: Forever.

- Browse the current zone by default, or switch to a level range. Filter quest and reward names, weapon types, usability and equipment slots, including empty slots. Dungeon quests are an optional addition where their identity is known.
- Browse guaranteed and choose-one rewards separately, with small item icons, rarity borders and native item tooltips and comparisons. XP, money and reputation appear when known.
- See verified new quests in orange, modified quests in green and existing quests without a tint. Quest dialogs can use the same subtle colors.
- Save up to 20 quests per character in Shortlist. Saved quests stay visible across zones, including completed quests.
- Inspect quest chains where source evidence exists, with optional paths and requirement groups kept distinct.
- Choose fonts, borders, scale, preview behavior and saved search defaults in settings.

## Installation

Copy `FindAnUpgrade` into your Forever client's `Interface/AddOns` folder, then restart WoW. `FindAnUpgrade.toc` must be directly inside `FindAnUpgrade`.

## Usage

Use `/fau` or `/findanupgrade`, or click the book icon on the minimap, to open the browser. The `search` and `s` subcommands also work. Hover reward icons for native item details and comparisons. Right-click a quest title or starter location for its Wowhead link, quest ID, starter name or coordinates, or to set a waypoint where supported. Copy actions select the requested text in a small dialog. Press Ctrl+C on Windows or Command+C on Mac; the popup dismisses after native copy input. Editing, changing focus or reopening cancels an older pending dismissal. This observes your copy gesture and does not report clipboard success.

Quests and Shortlist retain separate session queries and scroll positions. Shortlist uses saved order and keeps quests visible regardless of the Quests tab's zone, level or usability filters. Clicking a star changes this character's list; settings resets do not erase it. Future saved-data schemas stay read-only. Use `/fau slot ring` (or head, trinket, weapon, offhand, all) to open Quests with that reward filter while retaining scope, query and sort.

Quest chain details distinguish all-of, any-of, count thresholds and optional links. Unknown requirements never prove a quest unavailable. Bundled Forever-authored evidence can identify incomplete requirements; current native quest-log and gossip evidence takes precedence. Coverage is incomplete and no Questie runtime dependency is required for chain data.

The sort menu defaults to Biggest upgrade. It estimates item-level gain against usable equipped slots; paired rings, trinkets and hands respect equipment rules. It is a simple gear-level hint, not a prediction of damage or healing. Unknown item levels, variants or equipment legality stay unranked. Guaranteed and choose-one rewards remain separate.

Hold **Shift** over an NPC with known quests or a supported world-map marker for a compact preview in the existing game tooltip. Release Shift to inspect rewards in a persistent panel; it also handles sources without a matching game tooltip. **Escape** or moving away closes inspection. Long stacks scroll.

Questie is optional. FindAnUpgrade can preview its existing world-map and minimap markers; minimap quest previews require Questie. Search works without it.

Use the cog, `/fau opts` or `/findanupgrade options` for settings. Ctrl, Alt and hovering without a modifier are alternatives to Shift.

Settings keeps Appearance, Inspection, Quest previews, Surfaces and Search defaults together in one window. On shorter screens, scroll to reach the remaining controls; Reset stays at the bottom. Font choices include the game tooltip family, native fonts and installed SharedMedia fonts. A missing font uses the native fallback while preserving the preference. Border choices apply to owned preview/search panels; item rarity borders retain their meaning.

Saved search defaults apply each time the browser opens: Hide unusable starts enabled, dungeon quests disabled, and the level window spans five levels below through three above your current level. Temporary query, slot, scope and sort choices persist during the session. Editing defaults leaves an open search's filters intact until its next opening. New sessions start in the current zone. Reset restores saved preferences with the same next-opening rule for search defaults.

Version **0.1.13** uses the FindAnUpgrade folder and commands. When replacing QuestBrief, preserve its saved files and migrate them using the validated development installer before removing the old active folder. Existing FindAnUpgrade settings take priority. Unsupported future settings remain read-only and are preserved.

## Development

Run `python tools/verify.py` from the repository root with Python 3.11 or newer and Lupa. It runs the checks and builds ZIPs in `dist/`.

See [AGENTS.md](https://github.com/elithrar/QuestBrief/blob/main/AGENTS.md) for development rules, [database sync](https://github.com/elithrar/QuestBrief/blob/main/docs/DATABASE-SYNC.md) for dependency setup and data maintenance, and [validation coverage](https://github.com/elithrar/QuestBrief/blob/main/docs/VALIDATION.md) for checks and pending in-game validation.

## License

BSD-3-Clause. See [LICENSE](LICENSE). Third-party data licenses and attribution are in [NOTICES.md](https://github.com/elithrar/QuestBrief/blob/main/FindAnUpgrade/NOTICES.md).
