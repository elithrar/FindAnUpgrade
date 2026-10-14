# XPIsland and ATCF history review

Independent source review on 2026-10-14. Reviewed 37 XPIsland and 38 AsTheCrowFlies commit summaries through the GitHub connector and fetched the relevant fixes. The local reference checkouts are shallow, pinned at XPIsland `739dd09e14e3` and ATCF `433dbe289252`; neither reference repository was changed. QuestBrief runtime was not edited by this pass.

## Initial actionable findings

### H1: Existing stack text misses later font registration

**Location:** `QuestBrief/UI.lua:37`, `QuestBrief/Core.lua`'s secondary `ADDON_LOADED` path, and `QuestBrief/Stack.lua`'s text construction.

If options and a stack are constructed before Expressway becomes available, loading SharedMedia refreshes only the options. Existing stack labels retain the prior native face because they are assigned fonts only at construction. No SharedMedia registration callback repairs a registration that happens within an already-loaded library. The result is inconsistent typography and potentially stale card measurements.

**Reproduced with shipped Lua in the Lua 5.1 mock:** after opening options and a native quest pin, supply an Expressway library and dispatch `ADDON_LOADED`. The options heading reads `Expressway.ttf`; the existing card title still reads `Fonts\\FRIZQT__.TTF`.

This repeats the all-owned-text and late-registration bugs fixed by XPIsland's [057599646ace](https://github.com/elithrar/XPIsland/commit/057599646ace3b54d3e245d5316b393d089aa646) and recorded in ATCF's [afc98b4a40cd](https://github.com/elithrar/AsTheCrowFlies/commit/afc98b4a40cd6bf5939492d14691f06768a1d89c).

**Required regression:** construct options and cards before registration, trigger both late addon loading and a library font-registration callback, then assert that all existing owned text follows one checked face and visible card heights are remeasured safely. Preserve native quest text and any inspected reward identity.

### H2: Font downgrade does not settle or recover all owned text

**Location:** `QuestBrief/UI.lua:37` and `QuestBrief/Options.lua:58`.

A later control can reject a font that passed the probe and earlier controls. `U:Font` changes the shared path to the fallback, but `O:Refresh` does not replay the earlier objects. A single refresh returns with mixed faces. Separately, when the original requested path becomes usable again, the failed resolution is retained while the library instance and requested path remain the same; reopening or `ADDON_LOADED` does not retry it.

**Reproduced with shipped Lua in the Lua 5.1 mock:** make the final options label reject `Expressway.ttf`, then refresh. The heading remains Expressway and the final label becomes native. In a second fixture, fail the Expressway path during construction, restore it with the same library instance and requested path, and refresh; the native fallback remains cached.

XPIsland [057599646ace](https://github.com/elithrar/XPIsland/commit/057599646ace3b54d3e245d5316b393d089aa646) fixes this with a shared font revision, owner-driven replay after downgrade, and explicit retry on appearance changes. Both current reference addons carry equivalent protections.

**Required regression:** late per-object rejection, failure of both requested/default paths, recovery with the same library instance, and native replacement of an already-assigned font. Assert one settled family before measuring layout; do not retry fonts in per-frame hover work.

## Historical protections compared

| Prior issue and evidence | QuestBrief assessment |
| --- | --- |
| Fractional native height and void `SetFont` caused startup aborts: XPIsland [dddb693c393f](https://github.com/elithrar/XPIsland/commit/dddb693c393f4a626f902e5990ad8bb2ba29b945). | Current setter accepts a positive fractional readback and treats only explicit `false` as rejection. A focused void-return/fractional-height probe passed. Add failure/recovery coverage with H2. |
| Shared callback replacement and restricted API consumption: XPIsland [cb9f9f650283](https://github.com/elithrar/XPIsland/commit/cb9f9f650283569caa992cda9238a7ad9cc909c0). | Core uses secure post-hooks/additive script hooks. Tint ownership compares readback before restoring. ID/reward adapters distinguish unreadable values. Existing native-script, third-party tint and combat tests address this class. |
| Long values moved into other row slots after fitting: XPIsland [ff080b7f6223](https://github.com/elithrar/XPIsland/commit/ff080b7f6223eae6fb54479f1339a5f94a5dfd98). | Cards wrap and measure text instead of locally scaling FontStrings. Native font changes still require H1's remeasurement. Fixed-height options need the separate UI review's width/height checks. |
| Interrupted drag/resize persisted obsolete geometry: ATCF [cfde067df717](https://github.com/elithrar/AsTheCrowFlies/commit/cfde067df717). | Options stop movement on hide and do not persist drag positions. Native display/UI-scale changes during a drag remain a live check; no native rendering result is claimed. |
| Canceling a transient deadline and retaining coordinates from an old map: ATCF [23811a7fb7af](https://github.com/elithrar/AsTheCrowFlies/commit/23811a7fb7af2e17ecedeb7726a55e769f6f846b). | Hover generation and owner-specific teardown prevent late reward data from reopening a dismissed stack. Exact pin membership/data snapshots invalidate reuse. Existing map-close, pooled-source, unrelated-source-hide and late-data tests address the same stale-context class. |
| Malformed optional labels/waypoints caused provider errors: ATCF [21584c3fe10e](https://github.com/elithrar/AsTheCrowFlies/commit/21584c3fe10e). | QuestBrief guards list/entry types, exact numeric IDs, reciprocity and text. Focused probes with boolean, numeric, table and whitespace provider responses did not throw or fabricate quests. |
| Nearby samples produced duplicate destinations: ATCF [a2e74c7a66ee](https://github.com/elithrar/AsTheCrowFlies/commit/a2e74c7a66ee). | QuestBrief deduplicates exact quest IDs rather than titles or NPC proximity. Exact variants stay distinct; existing mixed-stack and reciprocal starter tests preserve this boundary. |
| Previously packaged development data and uncertain release retries: ATCF [23ab7ab8275a](https://github.com/elithrar/AsTheCrowFlies/commit/23ab7ab8275a). | Package/runtime data integrity and the new release workflow require the separate release pass. Never substitute sample classifications, move a published tag, or treat upload timeout as a safe retry. |

## Validation and limits

The focused probes executed current shipped code using Lua 5.1 via Lupa. H1 and H2 were confirmed before fixes; void font setter, fractional readback and malformed provider probes passed. The existing regression suites were inspected for historical coverage. This pass did not observe native rendering, live font registration, game input, frame taint, Questie visuals or client performance, and did not install or release the addon.

## Independent re-review

The first fix adds an all-owned-text registry, shared font revision/replay, protected optional-media lookup, one-time registration callbacks, and cache invalidation on font signals. A changed family dismisses the active inspection before any subsequent card layout. Independently executed `tests/font_test.lua`: all five scenarios pass. H1's late registration mismatch and H2's mixed-family/stable-library recovery reproductions are addressed.

One adjacent H2 layout defect remained in the first fix: `Stack:Refresh` measured each card before the final font replay. When a newly constructed later card rejects Expressway, the replay changes an earlier card's face after measuring it. A focused Lua 5.1 probe assigns the earlier title a 20-unit Expressway height and an 80-unit fallback height, then creates a second card whose first text rejects Expressway. The first refresh leaves the earlier card at height 94; the next identical refresh correctly measures 154. This can clip or overlap content. Card construction/font settlement must finish before measurement, or card measurement must replay after a revision change. The implementing agent was sent the reproduction; resolution remains pending at this checkpoint.

### Final history re-review: resolved

The follow-up fix performs bounded card measurement/anchor replay when the shared font revision changes, before setting child height and scroll limits. Re-ran the exact original late-card rejection probe against the updated shipped code: the first refresh now yields card height **154**, the repeat refresh remains **154**, and content height remains **254** across both. All six `tests/font_test.lua` scenarios also passed independently, including the new first-refresh wrapped-height regression.

H1 and H2, including the adjacent stale-measurement finding, are resolved in the inspected code and offline reproductions. This history pass has no remaining actionable finding. Native typography, live SharedMedia registration, interrupted native dragging and taint behavior remain client checks; the offline result does not establish them.
