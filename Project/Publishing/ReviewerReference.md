# InventoryCompanion reviewer reference

This is a navigation and evidence-discovery aid, not a completed review or an additional checklist. Apply the [generic ESOUI review template](ReleaseReviewTemplate.md) to the frozen candidate. Verify this guide against that candidate's source: development tests and fixes do not establish coverage in an older release.

## Fast starting point

1. Follow the [release checklist](ReleaseChecklist.md) to identify the installed candidate, reproduce its file-set SHA-256, and locate the intended listing and existing evidence. Inspect its manifest and complete runtime code, not just DEV or changed files.
2. Read the candidate's copy of [the test harness](../../Core/Tests.lua) before requesting a run. Links here point to DEV for navigation; use the corresponding candidate files for review.
3. After staging finishes, switch to release-only and reload the UI, then request one `/ictest verbose copy` report on **Live**. Compare installation/runtime version, DEV=false, integer AddOnVersion, and enabled installations against the staged candidate; DEV=false alone does not exclude an older loaded release. Independently verify disk hashes. ESO need not close; do not reload or change characters while staging/cancelling. Additional isolation or bank-state runs are conditional on specific findings, not routine requirements. Default to no PTS testing unless reported; record any PTS evidence separately. PTS is not required and compatibility is not claimed without evidence.
4. Reference the actual case results under the template's relevant sections. Use the short transfer check below for routine manual testing; do not ask the tester to repeat automated pattern/message assertions or expand every coverage gap into a manual test.

Follow the [preparation and review sequence](ReleaseChecklist.md#preparation-and-review-sequence) for early pre-review, rollback readiness, one consolidated testing handoff, impact-based retesting, and approval/package/upload milestones. Use this guide's coverage map to select the handoff and affected retests, not to create a second release workflow. The handoff should distinguish checks required now from conditional scenarios; do not present every hotspot below as a mandatory manual test.

## Test access and safety

| Entry point | Purpose and cautions |
|---|---|
| `/ictest verbose copy` | Preferred complete report. Intentionally raises a copyable Lua error even if all cases pass; inspect PASS/FAIL/WARN content, not the mere existence of the window. Retain the whole report and disclose truncation. |
| `/ictest verbose` | Prints cases/report in chat on success; failures still raise the report. Useful if copying the full error output is awkward. |
| `/ictest` | Summary, discovery where implemented, and failures/warnings; insufficient by itself to establish named-case coverage. |
| Debug Key | Runs the same suite as `/ictest verbose copy` through [the debug endpoint](../../Core/Init.lua). |
| `/icbankitems [1-20]` | Optional read-only samples of standard/subscriber bank contents; requires an open bank/chest. Not a transfer test. |
| `/icclean` | **Not a review prerequisite.** Intentionally prunes diagnostic saved data and updates currency-name history. |
| `/icclearoverrides` | **Do not use as a diagnostic test.** Clears rule overrides for the active account/character mode. |

The suite combines read-only real inventory/API queries with synthetic matching, messaging, preference, and event tests. Synthetic tests temporarily substitute runtime tables/helpers; the listener case also changes real event registrations before restoring them. It is not a wholly mocked/offline suite and must run in ESO, not during active transfers or a dual-loaded session. It does not intentionally transfer items or write persistent preferences. Back up saved variables before state-changing human tests; inspect restoration paths and report unexpected errors rather than assuming cleanup succeeded.

Current DEV discovery includes the Unix UTC timestamp, game build/API, server/language, installation/runtime version, DEV flag, ESO Plus/bank state, enabled add-ons and their integer `AddOnVersion`, and conditional currency coverage. It does not prove candidate identity or newest published versions.

## Existing coverage map

Names below describe the current DEV harness; check which cases and assertions actually exist in the frozen release.

| Review area | Test names/families and scope | Important boundary |
|---|---|---|
| Environment/dependencies | `Runtime and dependency discovery`; `Live currency helper API` | Discovery is absent from the older v1.01 release. Runtime metadata is not a file hash. |
| Rules and overrides | `Case-insensitive substring matching`, `Wildcard matching`, `Literal punctuation and missing names`, `Any-pattern matching`, `Baseline and saved-rule override resolution`, `Display-flag writes preserve other overrides` | Synthetic logic coverage, not editor input/rendering or live transfer selection. |
| Profiles/data preservation | `Profile import copies tracked items and rule overrides`; `Prune known saved-variable diagnostic keys only` | Fixture tests, not live cleanup, disk persistence, or a general schema-migration test. |
| Inventory scope/counting | `Tracked item count respects backpack and craft-bag scope`; `100-item backpack and craft-bag scan`; `Live read-only scan` | Live scans report occupied entries and bank state; inaccessible storage is not proven exercised. |
| Lifecycle/debounce | `Event listener transitions and refresh debounce` | Exercises feature-condition queries and real registry calls, with captured scheduling and synthetic callback invocation. DEV additionally asserts registration/filter success, repeated-call stability, shared-consumer retention, and matching event IDs. Does not prove settings-UI wiring or game filter delivery. |
| Preferences/resources | `Progress bar resource model and preferences`, `Currency panel resource preferences`, `Currency notification preferences and changes`, `Capacity notification preferences` | Models/preferences/API values, not visual layout or persistence after reload. |
| Notifications | All `Currency messages:` and `Capacity messages:` cases | Exact captured chat/HUD formatting, gains/spending/transfers, burst merging/cancellation, suppression, disabled settings, and threshold colours. Synthetic transfer messages do not move inventory. Currency availability/storage/caps affect generated coverage; conditional returns can pass without running assertions. |
| Performance | `Repeated 100-item inventory scan performance`, `100 repeated slot-rule matches`, `100 synthetic tracked-item slot updates`, `Live read-only scan` | Timing samples are not proof of sustained-event responsiveness, transfer-queue safety, or every inventory size. |

Do not hard-code an expected total: currency-dependent cases and harness versions change it. Include missing/conditional coverage rather than treating a reported total as universal proof.

### Performance workloads and version differences

| Workload | Current DEV limit | Older v1.01 limit |
|---|---:|---:|
| 20 synthetic scans of 100 items across 20 rules | 500 ms | 2,000 ms |
| 100 slot-rule matches | 100 ms | 1,000 ms |
| 100 synthetic tracked-item slot updates | 200 ms | 2,000 ms |
| 100 live read-only scans | 500 ms | 1,000 ms |

Timing uses `GetGameTimeMilliseconds`. Record the candidate's actual embedded limits, measured values, occupied entries, bank state, and subscription availability. Preserve timing-only FAIL results and investigate comparable reruns/gameplay impact; do not impose DEV limits retroactively or silently reclassify failures.

## Review hotspots and known coverage limits

These are areas requiring scrutiny, **not declarations of confirmed bugs**. Record any newly established defect separately with candidate-relative evidence.

| Location | What to trace | Existing mitigation/evidence and remaining questions |
|---|---|---|
| [Event registry and debounce](../../Core/Events.lua) | Listener ownership/conditions, shared consumers, filter results, repeated calls, stale state, and sustained bursts | Conditional registrations, per-bag filters, keyed refresh coalescing, and a 500 ms trailing delay; suite covers selected transitions and a short burst. Check whether sustained events can postpone work unacceptably and whether disabled features can leave pending refreshes. |
| [Visibility ticker](../../Core/Events.lua) | `InitCutsceneTicker`, its 100 ms update, cost and necessity while displays are hidden | Separate always-on path; not established by the listener-transition case. Assess actual cost and any author rationale before demanding debounce or conditional registration. |
| [Transfer queue/context moves](../../Banking/BankTransfers.lua) | Eligibility/planning, protected calls and results, queued item/slot validity, repeated invocations, capacity, bank close/reopen, and interruption | Queue checks `IsBankOpen` per step and delays operations by `bankItemDelay` (default 100 ms). Message tests are not execution tests; inspect actual queue identity/cancellation and state revalidation rather than assuming those guards prove all safety. |
| [Matching/count construction](../../Tracking/ItemDatabase.lua), [scanner](../../Core/Scanning.lua) | Compiled rules, saved overrides, per-item/per-rule work, repeated reconstruction and scope | Synthetic functional/burst tests plus live read-only timings. Broader scaling or continuous-load claims need separate evidence only when risk warrants it. |
| [Currency/capacity notifications and UI](../../Tracking/CurrencyPanel.lua) | Pending timers, baselines, suppression windows, location/reason handling, settings changes, disable/re-enable, and refresh paths | Captured-message scenarios cover many sequences, not rendering or real settings input. Additional human checks require a specific relevant change, finding, or reported problem. |
| [Initialization](../../Core/Init.lua), [settings](../../Core/Settings.lua), [load collision warning](../../Core/LoadCheck.lua) | Matching load event, saved-variable scope, defaults, persistence, duplicate installations and warning behavior | Reload/persistence, collision, and migration testing is conditional on specific relevant changes/findings, not routine release testing or deliberate double-loading. |

A specific code comment explaining why instrumentation, debounce, or another mitigation is inappropriate can be recorded as the author's rationale. Cite and assess it against the implementation; it is not measured proof and does not override contradictory evidence. This guide does not assert that every hotspot already has such a comment.

## Short human transfer check

Ask the tester to perform a few normal transfers between bank and bag, involving the craft bag if available, and between bag and house chests, using intended items and supported transfer paths. Ask whether any problems occurred; note unavailable storage. Ask for environment exceptions only: ESO Plus was not enabled, or PTS was tested. Otherwise use ESO Plus enabled and no PTS testing as reporting defaults, not independently verified observations; explicit reports and diagnostics override them. Do not infer transfer success from silence. Do not require an exhaustive transfer matrix or separate quantity-update, settings-toggle, visual, or reload/persistence checks. Expand only for a specific relevant change, finding, or reported problem. The [release checklist](ReleaseChecklist.md#short-human-transfer-check) contains the copyable request and handling of unavailable storage.

For author-only certifications, [the project checklist](ReleaseChecklist.md) records Tim-P's standing assertion about malicious/stolen code and submission rights. Attribute it correctly and ask one consolidated confirmation only for remaining facts. It is not a substitute for source review or contradictory license evidence.

## Offline packaging checks

Run `.\Project\Publishing\Test-PackageRelease.ps1` from the DEV root when packaging/template integration needs validation. It uses temporary fixtures and does not mutate live installations or saved variables; it is not an in-game functional test. Use [the packaging script](PackageRelease.ps1) only through the documented workflow: Stage/Cancel change installations and must not be run merely to inspect the existing release.

Keep this reference synchronized when commands, coverage, or architecture change. It remains development-only documentation and is not added to the runtime manifest.
