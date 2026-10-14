# Independent adversarial review

Reviewed on 2026-10-14 by a distinct review agent, independently of the implementation owner. This review was confined to QuestTint and read-only reference material. Production Lua was not edited by the reviewer.

## Scope and evidence

Read `AGENTS.md`, provenance, the TOC, all six shipped runtime modules, generated exact-ID data, generator, Lua mock/runtime/model tests, data checks, and package tooling. Read XPIsland and AsTheCrowFlies repository guidance. Inspected the pinned Mainline quest event, detail renderer, material setter, template regions and texture color API contracts from Gethe/wow-ui-source revision `943764493e6b16d63ded3ab304150d1f05e58b57`.

The native detail renderer sets material before `QuestInfo_Display(QUEST_TEMPLATE_DETAIL, QuestDetailScrollChildFrame, ...)`. The secure display post-hook and additive panel OnShow hook therefore observe the native offer path without replacing scripts. The source integration executed the exact `QuestFrame.lua` blob `2fb8847426d6cb3f4e72f9f788ed9d840ed697ce` under mocked supporting APIs.

## Finding 1 — P2: recovery did not retry retained restoration state

Original location: `QuestTint/Core.lua`, PLAYER_LOGIN/PLAYER_REGEN_ENABLED branch; related ownership behavior in `QuestTint/UI.lua:5`.

Trigger: tint a new offer (92124), temporarily block the background setter or make its color readback secret, then display an old offer (783). Reset clears `Core.questId` but correctly retains `UI.owned` because it cannot safely restore. Restore access, then dispatch PLAYER_REGEN_ENABLED. The original event branch called only `Attach`, which returned because hooks were already installed. The old offer retained the previous tint until another reset or render occurred.

The two focused Lua 5.1 reproductions failed before repair. Minimal setter reproduction using the repository mock:

```lua
W.Init(); W.Offer(92124)
local bg = QuestFrameDetailPanel.Bg
bg.failWrite = true; W.combat = true; W.Offer(783)
bg.failWrite = false; W.combat = false
W.Event("PLAYER_REGEN_ENABLED")
assert(bg.color[1] == 1 and not W.N.UI.owned[bg])
```

For the unreadable-color reproduction, use `bg.colorSecret = true/false` in place of `bg.failWrite`.

**Resolved and independently rechecked.** The event branch now calls `Attach` followed by `Refresh`, independently of existing hook attachment. Both reproductions pass. The implementation owner added dedicated regressions for both cases. Ownership remains conditional: if another skin changes the color before recovery, its color is preserved and QuestTint relinquishes ownership.

## Compatibility and documentation notes

An additional probe showed that newer read-only saved settings with `enabled=false` initially used the enabled default profile. This was raised as a compatibility-policy concern. The owner chose to preserve an explicit readable opt-out without mutating the newer saved table; the focused probe and strengthened regression pass.

The shipped README initially linked to `docs/` files that are present only in the source package. This minor delivery-documentation issue is **resolved and independently rechecked**: both identical READMEs now identify explicit source-package paths, and those documentation files exist in the source tree. It did not affect runtime behavior.

## Checks completed

- `python tests/run.py`: 48 passing Lua 5.1 scenarios (10 model, 38 runtime), with the exact pinned native-source integration present.
- `python tests/data_test.py`: five passing checks. Every generated classification matches the retained per-variant primary status: 1,194 IDs, 218 verifiedNew, 18 zones and 998 title groups. Mixed-title older/updated variants remain non-new; unknown IDs are absent. The frozen primary-evidence SHA-256 matches `64017ae90fe4e16323044064b0ac5ba6102fba147446660fb1fd863eaf8e9ae5`.
- `python tests/package_test.py`: six passing guards for reproducibility, exact addon payload, source exclusions, manifest/client/order/version enforcement, Lua syntax and stale classification rejection.
- Six focused independent probes pass after repair: setter recovery, secret-readback recovery, mixed-title/material transition, unavailable/throwing contrast API, delayed restore with a later skin color, and future-schema opt-out.

No other concrete runtime or exact-ID classification defect was found in the inspected scope after repair. Classification was checked against the retained normalized version-1 evidence; this review did not repeat all 56,251 original Library source lines.

## Remaining live checks and limits

Offline mocks do not reproduce the native renderer, texture output, actual event ordering, security model or third-party skin behavior in a running client. No native screenshot, in-game acceptance result or taint-free claim is made. The temporary failure/secret probes establish recovery behavior when those conditions occur; they do not establish that ordinary Forever quest textures become restricted during combat.

Pending approved live checks include new-to-old/unknown transitions, close/reopen and progress/reward/gossip transitions, combat/reload recovery, native parchment and alternate materials, contrast light/dark modes, quest text fade and unchanged native geometry, presets/strength legibility, settings at small and fractional scales, font fallback, taint logs and coexistence with XPIsland, ATCF and dialogue skins. No live installation, upstream merge, public repository or release was performed by this reviewer.
