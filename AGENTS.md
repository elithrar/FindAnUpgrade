# QuestBrief

- Target official WoW Forever interface 16001. Current contracts: 1.60.1.70374 at Gethe/wow-ui-source 735496de78ebd30ce816a0637982c556987f258c; the baseline detail-renderer fixture remains pinned at 943764493e6b16d63ded3ab304150d1f05e58b57 (70338). Do not claim live verification from source/mocks.
- `QuestBrief/` ships; the TOC owns load order and the shared namespace. Model, client adapter, appearance, options, and event ownership are separate.
- Classify quest IDs only from `data/primary-statuses.json`. Only per-variant primary `New` maps to `verifiedNew`; never propagate title-group status or use databaseNEW. Unknown IDs remain unchanged.
- Keep Lua 5.1 syntax. Preserve Blizzard scripts with secure post-hooks and additive HookScript. Never accept/complete quests, alter protected layout or visibility, or write to another addon's data.
- Run `python tools/verify.py` (Lua, data, package, release tests and build). Install Lupa only into `.work/pydeps` if needed. Outputs stay in `dist/`.
- Offline tests do not establish native rendering or taint safety. Record pending live checks. The implementation PR in the user-provided elithrar/QuestBrief repository is authorized; no merge, release or game installation is authorized by this development workflow. User instructions can authorize later work.
