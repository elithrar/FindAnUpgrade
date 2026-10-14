# Review outcome

The QuestBrief candidate has separate adversarial review passes for each
requested area. Source/offline evidence is distinct from native-client acceptance.

| Area | Finding and resolution | Evidence |
| --- | --- | --- |
| UI/UX against XPIsland | Fixed high-scale narrow-screen overflow, oversized vertical thumb, stale pooled fonts and missed Shift comparison release. Native checkbox anchors and the small button-based reveal selector were checked; no dropdown/menu is implemented. | Six font/layout tests; independent `.work/ui-review` probes; README re-review |
| XPIsland/ATCF history | Examined 75 commit summaries and relevant diffs. Fixed late media refresh, consistent fallback/recovery and final card measurement after a later object rejects the font. | [History review](HISTORY-REVIEW.md) |
| APIs/performance/lifecycle | Fixed first-open constructor dismissal, clipped reward hit tests, unrelated marker teardown, reused-marker activation, hub callback, comparison anchoring, tooltip update scope/transit and Questie early returns. Mixed choices preserve both index types and withhold shifted duplicate or incomplete metadata; fractional item counts are rejected. Hidden rewards do no work; pending reads/preloads are bounded. | [API/performance review](API-PERFORMANCE-REVIEW.md); inspection/Questie/current-source tests |
| README | Replaced the tint-only prototype description and removed obsolete presets. Followed XPIsland's concise interaction/install/coverage/development structure, without fabricated screenshots or live claims. | Identical root/shipped README, independently re-reviewed against XPIsland |
| BSD-3-Clause | Added matching original-code grants, corrected contradictory notice and retained upstream license/provenance boundaries. Independently inspected both archive payloads. | [License review](LICENSE-REVIEW.md) |
| Releases | Prepared pinned-action, guarded GitHub/CurseForge release flow and 30 mocked release checks; independent review fixed private-repo authentication, moved tags, dirty/untracked source, unexpected assets, malformed receipts and future-version fixtures. | [Release instructions](RELEASING.md); [independent release review](RELEASE-REVIEW.md) |

Earlier `INDEPENDENT-REVIEW.md` and `QUESTINSIGHTS-PLAN-REVIEW.md` remain historical
records for the tint prototype and approved planning stage. Current validation
and limitations are in [VALIDATION.md](VALIDATION.md). Neither review nor mocks
establish observed rendering, physical input, taint safety or game performance.
