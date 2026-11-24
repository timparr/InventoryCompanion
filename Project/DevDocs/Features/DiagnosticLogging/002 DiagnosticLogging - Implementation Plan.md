# Diagnostic logging: implementation plan

Status: Coding authorized by Tim in chat (24 November: "Write the spec doc (and implementation) for it then implement it here"); independent review PENDING
TODO item: None - requested directly by Tim
Spec: [001 DiagnosticLogging - Specification.md](<001 DiagnosticLogging - Specification.md>)
Owner: @Tim-P
Updated: 24 November

Process: [feature development](../../../Processes/FeatureDevelopment.md).

Documentation handoff, 24 November: implementation and test results below
refer to `spike/fco-itemsaver` (framework commit `383644c`, preserved in
`16c31c2`), not to code already merged into `main`. These documents are
carried forward for production review and promotion with Scanning Refactor;
the original spike-only coding authorization is retained as history.

## Current implementation and prior art

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
- `InventoryCompanion_DEV.txt` already declares `InventoryCompanion_Diagnostics`;
  `PackageRelease.ps1` copies that line into the release manifest.
- Account-wide booleans follow the `guildBankPartialWithdrawEnabled` pattern:
  default in `Core\Constants.lua`, type check in `PrepareSavedVariables`
  (`Tracking\ItemDatabase.lua`), normalization in `Core\Init.lua`.

## Technical options and decisions

| ID | Alternatives and trade-offs | Recommendation | Agreed choice and evidence |
|---|---|---|---|
| T1 | Keep the schema-1 field names, or move to a generic layout (`events`, `samples[stream]`) with schema 2. Generic names suit "any code can log anything"; schema 2 also makes older DEV builds refuse the new layout. | Schema 2 with migration | Within Tim's GO for the framework |
| T2 | Store the setting in the diagnostic store or in the account-wide profile. The profile is where users' settings live and ships with the schema 13 bump. | Account-wide profile field | Spec D1/D3 |
| T3 | Validate every sample field per stream, or validate generically (scalar values, dense lists, required timestamp). Streams are open-ended. | Generic | - |

## SavedVariables changes and migration

Settings profile (`InventoryCompanion_SavedVariables`, `$AccountWide`):
added `diagnosticLoggingEnabled` (boolean; default `false`, DEV `true`). Ships
with the planned schema 13 bump. Older 1.8.x readers ignore and preserve unknown
account fields; on this branch the release-mode reader is still schema 12, and
the field is a harmless additive boolean there.

Diagnostic store (`InventoryCompanion_Diagnostics`), schema 1 → 2:

```text
Before (DEV spike, schema 1)          After (schema 2)
schemaVersion = 1                     schemaVersion = 2
nextRunId, runs        (DEV)          nextRunId, runs        (DEV, unchanged)
playEvents = { event... }       →     events = { event... }
scanSamples = { sample... }     →     samples = { trackerScan = { sample... } }
                                      samples.trackerRefresh (new release stream)
```

- Missing store: created as `{ schemaVersion = 2, events = {}, samples = {} }`.
- Schema 1: validated, then fields moved (no data dropped); `runs` untouched.
- Any other schema or malformed data: logging disabled for the session, store
  unchanged, chat report. Older DEV builds accept only schema 1, so they refuse
  schema 2 without change (existing spike behavior).

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
  - `Clear()`: empties events and samples; chat confirmation.
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

### Task 3: Initial logs and spike migration

- Depends on: Task 1. Spec: AC5.
- `Tracking\ItemTrackerPanel.lua` `RefreshItemTrackerPanel` synchronous path:
  `Sample("trackerRefresh", {reason, scanMs, renderMs, rows, bankOpen})`.
- `Tracking\AutoCategoryIntegration.lua` `integration.Fail`: `Event("acFailure",
  failure + reconcile reason + character, traceback lines)`; the spike then
  only shows its HUD alert (`AlertAutoCategoryFailure`).
- `Core\FCOItemSaverSpike.lua`: `Notify` writes through `Event`;
  `RecordScanTime` through `Sample("trackerScan", ...)`; the spike's own store
  creation, schema-1 event/sample validation, session event and rolling-log
  code are removed; it keeps runs validation (creating `runs`/`nextRunId` if
  missing), the DEV-name assertion and the HUD throttle. `/icfcodiagnostics
  clear` clears runs and calls `Clear`; `clear runs` keeps working.
- `Core\Init.lua`: remove the load-time folder-name assertion (spec D4).

## Verification and acceptance mapping

| Spec criterion | Task | Test / command | Required evidence | Actual result |
|---|---|---|---|---|
| AC1, AC2, AC8 | 1 | `SavedVariablesTests.lua` diagnostic tests; spike scan-log test | Writes when enabled, none when disabled, rolling limits, details cap | PASS offline |
| AC3, AC4 | 1, 2 | Tests + in-game Settings | Clear empties log; default/persistence; dialog shown | PASS offline; in-game PENDING |
| AC5 | 3 | Tracker/AC/spike/saved-variable tests + in-game file check | Session, trackerRefresh, acFailure (including pre-profile), verifyDiff entries | PASS offline; in-game PENDING |
| AC6, AC7 | 1 | `SavedVariablesTests.lua`; `FCOItemSaverSpikeTests.lua` | Malformed unchanged; schema 1 migrated; schema 3 refused | PASS offline; in-game migration PENDING |

Full suite: `python Project\Tests\Run-RuleTests.py`. In-game: `/reloadui` on
Tim's DEV data (pre-change backup in the session folder), check the migrated
file after the next reload.

## Independent plan review

Reviewer: PENDING
Reviewed plan/spec revision and source identity: PENDING

| Finding | Evidence | Tim's decision | Resolution / re-review |
|---|---|---|---|
| PENDING | PENDING | PENDING | PENDING |

## Approvals

- Explicit spec approval and revision: PENDING (direction agreed in chat)
- Explicit plan approval and revision: PENDING
- Explicit GO to code: Tim, 24 November - "Write the spec doc (and implementation) for it then implement it here"

## Implementation record and deviations

- Implemented on `spike/fco-itemsaver` as planned (tasks 1-3).
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
- Offline result: `python Project\Tests\Run-RuleTests.py` 343/343;
  `git diff --check` clean.

## Independent code review and verification

- Reviewer and reviewed diff/source identity: PENDING
- Findings, agreed corrections, and re-review: PENDING
- Actual test results and retained evidence: PENDING
- Unavailable checks and remaining limitations: PENDING

## Acceptance and handoff

- Approved in-game test scope: PENDING
- Actual Tim-reported results: PENDING
- Explicit feature acceptance: PENDING
- Current spec, user docs, TODO, completed-work index, and archive links updated: PENDING
- Commit/merge authorization and outcome: PENDING
- Release: separate process; not authorized by feature acceptance.
