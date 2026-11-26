# Diagnostic logging: implementation plan

Status: IMPLEMENTATION ACCEPTED as part of Scanning Refactor by Tim on
26 November 2026; this plan is historical. Unperformed in-game checks remain
pending, and DEV/release diagnostic-log isolation remains a release prerequisite.
TODO item: None - requested directly by Tim
Spec: [001 DiagnosticLogging - Specification.md](<001 DiagnosticLogging - Specification.md>)
Owner: @Tim-P
Updated: 26 November

Process: [feature development](../../../Processes/FeatureDevelopment.md).

The full offline suite subsequently passed 352/352. Historical pending entries
below are not claims that those checks were performed. See the
[Scanning Refactor record](<../ScanningRefactor/002 ScanningRefactor - Implementation Plan.md>)
for the accepted shared implementation and final-acceptance limitations.

## In-game report-history verification (25 November, 23:52 UTC)

Tim ran the Debug Key twice with a bank transfer between runs and reloaded.
Read-only inspection of the flushed DEV SavedVariables found both reports,
sequences 3 and 4, timestamped 23:52:12 and 23:52:39 UTC respectively. Each
retains 224 contiguous text lines, the 89/89 summary and 89 PASS lines, with
no FAIL lines or invalid-string placeholders. Both survived the reload.
This verifies the two-report persistence/order scenario; it does not by itself
verify every verbosity option, logging-off routing, ten-report eviction, or
confirmed Clear in-game.

Documentation handoff, 24 November: implementation and test results below
refer to `spike/fco-itemsaver` (framework commit `383644c`, preserved in
`16c31c2`), not to code already merged into `main`. These documents are
carried forward for production review and promotion with Scanning Refactor;
the original spike-only coding authorization is retained as history.

Production scope addition, 24 November: persist `/ictest` reports instead of
raising copyable report errors (spec D6, AC9-AC10). This is new work beyond the
spike implementation and historical test results. Tim's later conditional GO
became effective after the independent focused design review passed.

## UAT correction: explicit AutoCategory error logging (25 November)

25 November, authorized UAT correction: replace AutoCategory recovery's
Show details error-window action with **Log error**. `LogRecoveryDetails`
records the complete current failure report through `DiagnosticLog.Event`
with explicit forced recording, without enabling background logging or
changing recovery state. Forced details reuse report chunking and retain the
full report; unavailable diagnostics are reported in chat. Focused tests cover
logging off, long UTF-8 details, reload, unavailable data, and both recovery
report paths. Validation: 76/76 focused AutoCategory/diagnostic tests PASS;
XML structure, all addon Lua syntax (5.1), and whitespace checks PASS.
Independent correction review: CLEARED by `dev-namespace-review`
(`dadb39b0-ddd8-4110-9c0f-0dce65309ade`, turn 2).
In-game verification, 25 November: Tim reproduced the bank failure, clicked
Log error and logged out. DEV SavedVariables flushed at 09:44:58 UTC with
the requested `acFailure` event and its 98 detail lines intact; no invalid
saved-string placeholders were found. Background logging was enabled for
this run, so logging-off behavior is verified offline only; that in-game
check remains pending. The recorded bank failure identifies missing bag/slot
arguments in the AC predicate's call to `ItemMatchesRuntimeRule`; fixing that
matching defect is separate from this logging correction.

## First acceptance blocker correction (25 November, 17:00 UTC)

Tim authorized automatic AC failure logging and visible feedback beside
Log error. `integration.Fail` now submits one non-forced `acFailure` event
with the current traceback/diagnostic context, preserving the existing fault
gate and recovery behavior. Pre-profile failures use the logger's pending
queue; normal and pending automatic events obey the logging setting.
Background event details now reuse the existing ESO-safe chunker before
applying the normal bounded detail limit.

`LogRecoveryDetails` still forces explicit recording regardless of that
setting, and now returns its chat feedback for the recovery panel to display
beside the controls. Both success and unavailable-store failures are shown;
refreshing the panel clears the previous result. No saved-data schema changes,
live-file edits, cache-recovery changes or tracker-mismatch changes.

Regression evidence: 0/3 before correction, 3/3 after; 76/76 focused tests
and 318/318 full offline tests PASS. The automatic-recording test executes
the actual logger/failure handler with logging on/off, including failures
before the profile loads, duplicate failures and oversized trace lines.
Python syntax, addon Lua 5.1 syntax, XML structure and whitespace checks PASS.
Independent correction review CLEARED by `dev-namespace-review`
(`dadb39b0-ddd8-4110-9c0f-0dce65309ade`, turn 4).
In-game results for this correction are recorded below.

In-game automatic-recording check, 25 November: Tim invoked the runtime-only
failure command without pressing Log error, then logged out. DEV SavedVariables
flushed at 17:20:38 UTC with diagnostic logging enabled and an `acFailure`
event containing "IC acceptance test: automatic logging" plus 15 traceback
detail lines. Automatic recording/persistence with logging enabled PASS.
Logging-off follow-up: DEV SavedVariables flushed at 17:22:33 UTC with
`diagnosticLoggingEnabled = false`. The event sequence ends with
`loggingDisabled`, then a manually requested `acFailure`, with no intervening
automatic failure event. The retained report uses the earlier "automatic
logging" test text rather than the suggested "logging off" text, but its
manual-event message, later timestamp and disabled setting establish the
requested routing. Tim confirmed the visible message appeared.
Automatic suppression, explicit recording with logging off, visible button
feedback and disk persistence PASS. This first acceptance blocker is resolved;
full feature acceptance and the other blockers remain open.

## Open questions

None currently. Independent review resolved Q1: use diagnostic format 3;
format-2 Clear does not clear an unrecognized report-history field, so adding
history under format 2 would violate downgrade/clear guarantees.

## Current implementation and prior art

The spike-specific facts below refer to preserved source, not files already
present on this branch. Production promotion creates the framework and ports
the relevant callers/tests without importing the spike runtime.

- `Core\FCOItemSaverSpike.lua` (DEV-only; returns at load outside DEV) owns
  `InventoryCompanion_Diagnostics` (schema 1): `runs`/`nextRunId` for
  `/icfcodiagnostics` benchmarks, `scanSamples` (tracker timings) and
  `playEvents` (background events), each a rolling log (2,000 / 1,000 since
  commit `ebecf46`). `Notify` writes an event and optionally a throttled HUD alert.
- Callers: `Tracking\ItemTrackerPanel.lua` (DEV incremental tracker:
  `RecordScanTime`, `LogPlayEvent`, `ReportTrackerDifferences`) and
  `Tracking\AutoCategoryIntegration.lua` `integration.Fail` (calls
  `FCOItemSaverSpike.ReportAutoCategoryFailure` when the spike exists).
- Release tracker refreshes go through `this.RefreshItemTrackerPanel` →
  `this.GetTrackerDisplayList` → `RenderTrackerDisplayList` and are not timed.
- The spike manifest declares `InventoryCompanion_Diagnostics`; the current
  branch does not. Add that declaration during promotion.
  `PackageRelease.ps1` copies the declaration into the release manifest.
- Account-wide booleans follow the `guildBankPartialWithdrawEnabled` pattern:
  default in `Core\Constants.lua`, type check in `PrepareSavedVariables`
  (`Tracking\ItemDatabase.lua`), normalization in `Core\Init.lua`.
- `Core\Tests.lua` `RunTests` already assembles `reportLines` containing the
  summary, discovery and results, with optional AutoCategory diagnostics.
  The `copy`/failed-test path raises the assembled text with `error`; the
  asynchronous `RunTrackerPerformanceTest` callback does likewise after
  appending its report. These output paths, not assertion handling, change.

## Technical options and decisions

| ID | Alternatives and trade-offs | Recommendation | Agreed choice and evidence |
|---|---|---|---|
| T1 | Keep the schema-1 field names, or move to a generic layout (`events`, `samples[stream]`) with schema 2. Generic names suit "any code can log anything"; schema 2 also makes older DEV builds refuse the new layout. | Schema 2 with migration | Within Tim's GO for the framework |
| T2 | Store the setting in the diagnostic store or in the account-wide profile. The profile is where users' settings live. | Account-wide profile field; production promotion uses settings schema 14 with Scanning Refactor (spike DEV used 13) | Spec D1/D3; Tim's schema-14 decision, 24 November |
| T3 | Validate every sample field per stream, or validate generically (scalar values, dense lists, required timestamp). Streams are open-ended. | Generic | - |
| T4 | Gate explicit test reports on the background logging switch, or save independently. | Independent report-recording API | AGREED: Tim, 24 November: "yes it should save when logging is off". Storage representation and format compatibility remain proposed under Task 4. |
| T5 | Single report slot, shared rolling events, or separate bounded history. | Dedicated test-report history, latest 10 complete reports | AGREED: spec D8. Each report has a timestamp and sequence number; background log activity cannot evict reports. Format 3 compatibility is resolved in T6. |
| T6 | Keep diagnostic format 2 or advance for report history. | Format 3; migrate formats 1 and 2 | Independent design review: schema-2 readers accept unknown fields and Clear ignores them. Advancing ensures those readers refuse the report-bearing format unchanged. Q1 resolved as a technical correction authorized by Tim. |

## SavedVariables changes and migration

Settings profile (`InventoryCompanion_SavedVariables`, `$AccountWide`):
added `diagnosticLoggingEnabled` (boolean; default `false`, DEV `true`).
Production promotion is Task 0 of the
[Scanning Refactor plan](<../../Archive/ScanningRefactor/002 ScanningRefactor - Implementation Plan.md>)
and ships with settings schema **14 for both DEV and release**. Validate and
migrate it alongside the other schema-14 changes; verify older readers refuse
the new profiles unchanged. The original spike used DEV schema 13 /
release-mode schema 12; those are historical source formats, not the target.

Historical spike migration (`InventoryCompanion_Diagnostics`), schema 1 → 2:

```text
Before (DEV spike, schema 1)          After (schema 2)
schemaVersion = 1                     schemaVersion = 2
nextRunId, runs        (DEV)          nextRunId, runs        (DEV, unchanged)
playEvents = { event... }       →     events = { event... }
scanSamples = { sample... }     →     samples = { trackerScan = { sample... } }
                                      samples.trackerRefresh (new release stream)
```

Production target is **diagnostic format 3**:
- Missing store: create `{schemaVersion = 3, events = {}, samples = {},
  testReports = {}, nextTestReportSequence = 1}`.
- Format 1: validate first, stage the event/sample moves shown above and add
  report history/counter. Format 2: validate existing events/samples and add
  report history/counter. Preserve `runs`, `nextRunId` and unrelated fields.
  Commit only after the complete staged result validates.
- Format 3: validate dense report history (at most 10 complete reports),
  timestamp/positive sequence/string-line contracts, ascending report sequence
  and a positive next counter greater than retained sequence values.
- Unsupported formats or malformed stores: report explicitly, leave the
  original unchanged, and make both logging and report persistence unavailable.
- Test actual preserved format-1 and format-2 readers reject format 3 without
  mutation. Settings schema 14 is a separate, settled decision.

## Data, compatibility, and failure contracts

- Boundary: the stored log and the saved setting are validated at load.
- Internal: `Event`/`Sample` assert their argument contracts and that the
  framework is initialized; callers do not guard calls.
- ZOS calls used only for context text (`GetUnitName`, `GetAPIVersion`, etc.)
  are wrapped in `tostring`.

## Implementation tasks

### Task 1: Logging framework

- Depends on: None. Spec: AC1, AC2, AC6, AC7, AC8.
- Create `Core\DiagnosticLog.lua`, loaded in the manifest after `Core\Utils.lua`.
  Declare `InventoryCompanion_Diagnostics` in the DEV manifest; retain the
  existing release-packaging declaration-copy mechanism.
  Owns `this.DiagnosticLog`:
  - `Initialize()`: validates/migrates/creates the store (above). Called first
    in `Core\Init.lua` `Initialize`, before `PrepareSavedVariables`, because
    saved-variable preflight can raise AutoCategory failures. Events raised
    before `Start()` are held in memory (newest 1,000).
  - `Start()`: called immediately after the account setting is validated,
    before AutoCategory initializes. Logs a `session` event (addon
    name/version, API version, ESO Plus, character name and ID), then appends
    the held events if enabled or discards them if not.
  - `IsAvailable()`: store usable this session. `IsEnabled()`: started,
    available and `accountWide.diagnosticLoggingEnabled`.
  - `Event(kind, message, details)`: kind/message strings, details nil or list
    of strings (capped at 100 lines). Appends `{timestamp, gameTimeMs, kind,
    message, details}`; keeps the newest 1,000. No-op when disabled.
  - `Sample(stream, entry)`: stream string, entry table; adds `timestamp`;
    keeps the newest 2,000 per stream. No-op when disabled; must not be called
    before `Start()`.
  - `SetEnabled(value)`: logs `loggingDisabled` before or `loggingEnabled`
    after changing the setting.
  - `Clear()`: empties events and samples; Task 4 extends it to remove the
    retained test-report history too. Chat confirmation.
  - `GetStore()`: the validated store for DEV-only owners (spike runs).
- Verification: framework tests in `Project\Tests\SavedVariablesTests.lua`
  (loaded through the real startup path) and the spike tests.

### Task 2: Setting and controls

- Depends on: Task 1. Spec: AC3, AC4.
- `Core\Constants.lua`: `defaultsAccount.diagnosticLoggingEnabled = this.IsDevelopment == true`.
- `Tracking\ItemDatabase.lua` `PrepareSavedVariables`: `$AccountWide` field must
  be nil or boolean. `Core\Init.lua`: `ValidateDiagnosticLoggingSetting` normalizes.
- `Core\Settings.lua` Debugging submenu: checkbox (`SetEnabled`) and dangerous
  button with warning (`Clear`, disabled unless `IsAvailable`).
- `Project\Publishing\Source Documents\UserManual.bbcode` and `Changelog.bbcode`.

### Task 3: Promote initial production logs

- Depends on: Task 1. Spec: AC5.
- `Tracking\ItemTrackerPanel.lua` `RefreshItemTrackerPanel` synchronous path:
  `Sample("trackerRefresh", {reason, scanMs, renderMs, rows, bankOpen})`.
- `Tracking\AutoCategoryIntegration.lua` `integration.Fail`: `Event("acFailure",
  failure + reconcile reason + character, traceback lines)`, preserving
  existing user-visible failure reporting.
- Task 0 delivers session, synchronous trackerRefresh and AC-failure logs.
  Scanning Refactor Tasks 3-4 wire trackerScan and mismatch events while
  promoting the scanner; shared code calls DiagnosticLog directly, not the
  spike's Notify/RecordScanTime helpers.
- Do not port benchmark commands or edit the preserved spike module. Spec D4's
  folder-check removal is historical spike work; this branch has no such
  assertion to remove. Initial production logging and schema-14 settings
  migration are one combined deployment, not independently shippable builds.

### Task 4: Persist in-game test reports

- Depends on: Task 1. Spec: AC9, AC10.
- `Core\Tests.lua`: extract a shared local report-finalization helper used by
  normal `RunTests` completion and its asynchronous `trackerperf` callback.
  Keep report construction, test assertions, restoration and result accounting
  unchanged. Remove the deliberate assembled-report `error` calls, including
  the failed-test output branch; do not suppress genuine test failures.
- Proposed representation/API, pending plan approval: add
  `DiagnosticLog.RecordTestReport(reportLines)`, independent of `IsEnabled`
  but requiring an initialized, available store. Validate/copy the complete
  ordered string list, then append the complete report to a dedicated
  `testReports` section alongside background events/samples. Retain the latest
  10 reports in completion sequence, each with a timestamp and sequence number;
  allocate both inside RecordTestReport at finalization so overlapping
  asynchronous runs are ordered by completion, not invocation. On the
  eleventh completion evict only the oldest complete report. Validate the
  history and sequence metadata at the saved-data loading boundary. Do not
  apply the 100-line event limit or background event eviction to these reports.
  `Clear` also removes the report history. Background `Event`/`Sample` gating is
  unchanged; explicitly running tests never enables background logging.
- Use format 3 and the reviewed migration contract above. Report lines are
  complete ordered lists, without silently truncating verbose reports.
- Preserve `verbose` / `veryverbose` report content and chat behavior, retain
  `copy` as a compatible option, and show summary/failures in chat. Check the
  framework's availability before confirming recording; background logging
  being off must not prevent saving. When the store is unavailable explicitly
  say the report was not saved. Successful recording reports the reload/logout
  flush requirement, not an already-written disk file.
- Update command documentation in
  `Project\Publishing\Source Documents\UserManual.bbcode` and the working
  changelog when implementing this addition.
- Verification: focused tests in the existing offline test harness for normal
  and `copy`/verbose output, failed results, asynchronous completion, ordered
  reports exceeding 100 lines, saving with background logging off without
  enabling it, unavailable-store reporting, two successive runs preserving
  both outputs, exact 10-report retention/oldest-whole-report eviction on run
  11, timestamp/sequence metadata, preservation through background event
  eviction, and clearing the report history.
  Test overlapping asynchronous runs completing in reverse invocation order,
  and a failed-test run routed through the same finalizer without hiding failure.
  Confirm genuine failures remain visible and no report-only Lua error occurs.
  In-game, press the Debug Key, move an item into the bank, press the key again,
  then flush with reload/logout and inspect both complete reports in the
  diagnostic saved file. The bank action is a manual acceptance step, not a
  synthetic inventory mutation. No live settings or inventory mutation is
  added to synthetic tests.

## Verification and acceptance mapping

| Spec criterion | Task | Test / command | Required evidence | Actual result |
|---|---|---|---|---|
| AC1, AC2, AC8 | 1 | `SavedVariablesTests.lua` diagnostic tests; spike scan-log test | Writes when enabled, none when disabled, rolling limits, details cap | PASS offline |
| AC3, AC4 | 1, 2 | Tests + in-game Settings | Clear empties log; default/persistence; dialog shown | PASS offline; in-game PENDING |
| AC5 | 3 | Tracker/AC/spike/saved-variable tests + in-game file check | Session, trackerRefresh, acFailure (including pre-profile), verifyDiff entries | Automatic AC correction review CLEARED; actual logger/failure-handler regressions PASS for on/off and pre-profile failures. In-game automatic AC failure/traceback persistence PASS, 25 November at 17:20:38 UTC; manual Log error persistence already passed. Other event-type evidence remains to be reconciled before full criterion closeout. |
| AC6, AC7 | 1, 4 | Existing startup tests plus promoted diagnostic fixtures and actual old-reader checks | Formats 1/2 migrate to 3; unknown/malformed unchanged; older readers refuse 3 | PASS offline; approved in-game migration/file check PENDING |
| AC9 | 4 | Focused offline report-routing tests; in-game `/ictest` options | Separate latest-10 complete-report history, exact oldest-report eviction, timestamps/sequences, independent of background logging/eviction, preserved failures/verbosity, explicit unavailable-store behavior | PASS offline; in-game command checks PENDING |
| AC10 | 4 | Debug Key run, manual bank action, second run, reload/logout and saved-file inspection | Both saved reports remain in sequence with summaries/results/requested details intact | PENDING - new production scope |

Full suite: `python Project\Tests\Run-RuleTests.py`. In-game: `/reloadui` on
Tim's DEV data (pre-change backup in the session folder), check the migrated
file after the next reload.

## Independent plan review

Focused independent re-review: `focused-design-check` rubber-duck agent,
24 November: PASS for this spec and plan. Tim's conditional approval and GO
are effective after that result; in-game acceptance remains pending.

Reviewer: independent `design-review` rubber-duck agent, 24 November
Reviewed plan/spec revision and source identity: uncommitted feature documents
on `feature/scanning-refactor`, base `69596b0`; spike source `16c31c2`.

| Finding | Evidence | Tim's decision | Resolution / re-review |
|---|---|---|---|
| Format-2 Clear ignores additive report history; production/spike call sites conflated; async report completion order unspecified | First independent review T4, T5, T7 | Technical corrections authorized by Tim's review GO | Revised to format 3, explicit promotion wiring and completion-ordered reports; focused re-review PENDING |

## Approvals

- Explicit spec approval and revision: Tim's conditional approval effective
  after independent focused re-review PASS, 24 November.
- Explicit plan approval and revision: same conditional approval, now effective.
- Explicit GO to code: Tim, 24 November - "Write the spec doc (and implementation) for it then implement it here"

## Implementation record and deviations

- Implemented on `spike/fco-itemsaver` as planned (tasks 1-3).
- Production promotion now implements Tasks 1-4, including diagnostic format 3
  and retained in-game reports. The spike results below remain historical,
  separate from the current production validation.
- Deviation: `Initialize()` was split into `Initialize()` + `Start()`. Offline
  tests showed `PrepareSavedVariables` can call `AutoCategoryIntegration.Fail`
  before profiles (and so the setting) exist; those events are now held and
  written after the session marker when logging is on.
- Deviation: no separate `DiagnosticLogTests.lua`; framework tests run through
  the real startup path in `SavedVariablesTests.lua`. The tracker and
  AutoCategory test runtimes use a no-op log stub, with one recording-stub test
  each for the `trackerRefresh` sample and the `acFailure` event.
- Spike: the old `ReportAutoCategoryFailure` became `AlertAutoCategoryFailure`
  (HUD only); `RecordScanTime` still runs the AutoCategory priority tripwire on
  every scan, then samples only when logging is on.
- That watcher behavior is historical, not the promotion contract: Scanning
  Refactor T10 requires its replacement to gate all watcher work on logging
  and DEV/debug eligibility, watch changing priorities rather than enforce
  Deconstruct first, and remain removable during FCO Integration.
- Offline result: `python Project\Tests\Run-RuleTests.py` 343/343;
  `git diff --check` clean.

## Independent code review and verification

Production logging checkpoint, 24 November:
- Independent `logging-code-review` agent: no significant issues in
  `Core\DiagnosticLog.lua`, report finalization changes in `Core\Tests.lua`,
  and `Project\Tests\DiagnosticLogTests.lua`.
- Isolated Lua 5.1 diagnostic/report suite: 11/11 PASS, including actual
  preserved format-1/2 readers refusing format 3 unchanged, logging-off
  report persistence, complete latest-10 retention and visible failed reports.
- Combined parent-run suite: **310/310 PASS** with Lua 5.1, including the
  diagnostic tests, startup/migration tests and production scanner integration.
  All Lua syntax and `git diff --check` pass. No live saved data or inventory
  was touched.
- Shared settings/startup corrections are included in the independent
  production review recorded in the Scanning Refactor plan.
- Remaining checks: actual ESO command/dialog rendering and event delivery,
  reload/logout file flush, and approved older-backup migration UAT. These
  offline results are not feature acceptance.
- Actual UAT, 25 November: report sequence 1 reached disk, but ESO replaced
  oversized line 111 with nil and a 2000-character-limit comment. Summary is
  88/89 passed; 88 PASS lines survive, and the failed detail is lost. Complete
  report persistence FAIL. Stop for discussion/correction; no automatic live
  saved-data repair. Offline fixtures did not simulate this ESO serializer limit.
- Authorized corrections, 25 November: use space-separated manifest saved-global
  names; split oversized report lines into consecutive chunks of at most
  1900 bytes without splitting UTF-8 characters or dropping text. No new saved
  fields or diagnostic format change are needed. Malformed existing history
  remains rejected unchanged; recovery uses explicitly approved file restoration,
  not silent normalization of lost test results.
- New regressions reproduce both failures before the fix and verify manifest
  loading/saving plus report reloading through an ESO-limit serializer simulation.
  Focused suite **26/26 PASS**; after the DEV namespace correction, full suite
  **313/313 PASS**. Independent focused `dev-namespace-review` cleared the
  report serializer and namespace/publishing corrections. Actual UAT retest
  remains PENDING.
- Actual post-rename UAT, 25 November, 08:52 UTC: the verbose report saved on
  logout, including the previously oversized failure detail split across
  consecutive chunks. No invalid-string placeholders remained. It identified
  the separate listener diagnostic failure (**88/89 PASS**) now tracked in
  the Scanning Refactor plan. Normal verbose-report disk persistence passes;
  logging-off, history/clear UI and remaining in-game variants are still PENDING.

## Acceptance and handoff

- Approved in-game test scope: PENDING
- Actual Tim-reported results: PENDING
- Explicit feature acceptance: PENDING
- Current spec, user docs, TODO, completed-work index, and archive links updated: PENDING
- Commit/merge authorization and outcome: PENDING
- Release: separate process; not authorized by feature acceptance.
