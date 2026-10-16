# Validation

FindAnUpgrade targets official WoW Forever, interface **16001**. Run `uv run --locked fau check` for the maintained lint, formatting, Lua 5.1, Python, deterministic data, package and release checks. `dist/validation-evidence.json` records the exact commands, active Python version, outputs and result; `dist/test-results.json` records Lua suite results. Reports describe the tree actually checked and are deliberately untracked.

The current source contract is Forever **1.60.1.70425**, revision `b401e0332adfbf0460d319b06d8ea29279a941f1`. The native quest-detail fixture remains pinned to 70338; the prior 70374 snapshot is retained in `client-contracts.json`. See [CLIENT-CONTRACTS.md](CLIENT-CONTRACTS.md). Matching optional native fixtures add source integration coverage when present; the Lua receipt distinguishes executed and skipped fixtures. A fresh checkout can run the offline checks without a client installation or another repository.

## Evidence boundaries

Tests exercise production modules, registered handlers, pooling, state ownership, retry bounds and the native contracts reproduced by the fixtures. They establish behavior under those modeled conditions. Source inspection, substitute-font mockups, package installation and passing CI do not establish native rendering, physical input, client event ordering, combat/taint safety or in-game CPU.

| Interaction | Source and offline coverage | Pending live acceptance |
| --- | --- | --- |
| Quest cards and previews | Exact-ID cards, classification, guaranteed/choice groups, persistent Shift/Ctrl/Alt/None inspection, Escape suppression, leave grace and scrolling | Native typography, density, fractional scales, screen edges, physical modifier/Escape ordering and pointer transit |
| NPC and map identity | Session-bound gossip IDs, exact starters, optional reciprocal Forever providers, native map callbacks and Questie pooled-pin guards | Actual NPC offers, multi-quest hubs, pin reuse/load order and availability; native minimap payloads without reliable quest IDs remain unsupported |
| Reward data | Unknown remains unknown; explicit item groups/quantities, base XP/money/reputation and provenance remain distinct from native player rewards | Player bonuses, ordinary faction reputation, class-hidden choices, exact item variants and native comparison output |
| Finder and Shortlist | Search/filter/ranking, character constraints, async completion, persistence, stars, chain disclosure, options and owned copy lifecycle | Native fonts/atlas appearance, scroll/drag/copy input, map geometry/waypoints, clipboard ordering and live restrictions |
| Tooltip/dialog integration | Owned native comparison state, additive hooks, texture restoration, bounded retries and cleanup | Native tooltip addons/skins, protected/secret values, combat transitions and coexistence with XPIsland, ATCF and Questie |

Hold and toggle inspection were considered and deferred because their input/tooltip transit behavior needs live verification. The maintained interaction persists after releasing the selected modifier. No global game binding is replaced.

## Live checklist

1. Compare exact guaranteed/choice rewards and cold/warm native queries on the same character. Check money, XP, currencies, reputation, quantities and item variants separately.
2. Inspect single/multiple NPC quests, native world-map offers/active pins/hubs and Questie markers on both maps. Reassign/fade pooled pins, close maps and invalidate interactions; verify tooltip cleanup and no duplicate markers.
3. Move from source into the first/last card and item/comparison tooltips. Release modifiers, expand/scroll, press Escape while held, leave/re-enter and switch focus. Test both physical modifier keys, small screens, screen edges and fractional scales.
4. Exercise Quests/Shortlist, chain groups, async item data, options reopen/scroll/reset, native dropdowns, minimap drag-release and native copy on Windows/Mac. Check first-run and restored settings.
5. Repeat in combat and through combat transitions with the user's usual addons. Capture the first Lua/security error, exact build and relevant native payload. Measure in-game CPU before making native performance claims.

Repository cleanup and tooling refactors add no new live-client evidence. Historical plans, review logs and delivery records remain recoverable through Git; current contracts, source receipts, tests and pending acceptance are maintained here. Release configuration and its unverified API boundary are in [RELEASING.md](RELEASING.md).
