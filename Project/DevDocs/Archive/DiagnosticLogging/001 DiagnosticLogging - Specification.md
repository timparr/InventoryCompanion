# Diagnostic logging: feature spec

Status: IMPLEMENTATION ACCEPTED as part of Scanning Refactor by Tim on
26 November 2026; this record is archived. Unperformed in-game checks remain
pending, and DEV/release diagnostic-log isolation remains a release prerequisite.
TODO item: None - requested directly by Tim, 24 November, during the FCO ItemSaver spike
Owner: @Tim-P
Updated: 24 November
Implementation plan: [002 DiagnosticLogging - Implementation Plan.md](<002 DiagnosticLogging - Implementation Plan.md>)

## Overview / proposed changelog text

- **Diagnostic logging.** A new **Enable Diagnostic Logging** option under
  Settings > Debugging records what InventoryCompanion is doing in the
  background: tracker refresh timings, tracker problems and AutoCategory
  synchronization failures. If you report a problem, turn it on, play until the
  problem happens, then `/reloadui` or log out and send the author your
  `SavedVariables\InventoryCompanion.lua` file. The log keeps only the newest
  entries, so it does not grow without limit. **Clear Diagnostic Log** removes
  every entry after a confirmation. Logging is off by default.

## Scope and non-goals

- In scope:
  - A general logging framework that any addon code can use: named events
    (kind, message, optional detail lines) and named sample streams
    (structured timing records).
  - An account-wide on/off setting and a clear button in the Debugging section.
  - Size limits: newest 1,000 events; newest 2,000 records per sample stream.
  - Initial logs: session start (addon/API version, ESO Plus, character),
    tracker refresh timings, tracker mismatches (DEV incremental tracker), and
    AutoCategory synchronization failures with the error trace.
  - Moving the FCO spike's existing DEV logs onto the framework.
  - Saving in-game `/ictest` reports through the framework instead of using
    deliberately raised errors as copyable report output.
- Out of scope:
  - In-game log viewer, export, upload, or chat output of log entries.
  - Per-category enable switches or adjustable size limits.
  - The FCO spike's benchmark runs (`/icfcodiagnostics`), which stay DEV-only
    and are not part of the user log.
  - A permanent or release-wide AutoCategory priority tripwire. Scanning
    Refactor temporarily retains DEV/debug priority-change diagnostics through
    this framework, only when logging is on; it must not enforce Deconstruct
    at rank 1. FCO Integration removes this temporary watcher.

## User experience and behavior

Settings > Debugging (existing expander):

```text
[x] Enable Debug Mode
    AutoCategory Editor Slow-Action Limit (ms)  [----o----]
[ ] Enable Diagnostic Logging                         (new)
    [ Clear Diagnostic Log ]                          (new)
```

- **Enable Diagnostic Logging** (checkbox, account-wide). Tooltip explains what
  is recorded, that it includes character names and IDs, that only the newest
  entries are kept, that the log is in `SavedVariables\InventoryCompanion.lua`,
  and that it is written to disk only on `/reloadui` or logout. Turning it on
  records a "logging enabled" event; turning it off records "logging disabled"
  before stopping. The change takes effect immediately; no reload is needed.
- **Clear Diagnostic Log** (button). Shows LibAddonMenu's confirmation dialog;
  on confirm removes every event and sample and prints a chat confirmation that
  the clear is saved on `/reloadui` or logout. Both controls are disabled when
  the stored log is unusable (see below).
- Default: off in release; on in DEV.
- While logging is off, background events and samples are not written and
  existing entries are retained. Explicitly invoked in-game test reports are
  saved independently of this setting (see below).
- The AutoCategory recovery panel's **Log error** action records the current
  failure, full traceback and available diagnostic context as an `acFailure`
  event even when background logging is off, without changing that setting.
  Explicit error details are chunked safely for ESO persistence and are not
  subject to the background event's detail-line limit. Feedback beside the
  button and in chat confirms recording or reports an unavailable store;
  `/reloadui` or logout writes it to disk.
- Problems found while saved settings load (before the logging setting itself
  is known, such as an AutoCategory data error) are held and written after the
  session marker if logging is on, or discarded if it is off.
- If the stored log is malformed (users can edit saved variables), logging is
  disabled for the session, the stored data is left unchanged, and chat explains
  why. Other addon features continue.

### In-game test reports

- Explicitly invoking `/ictest` records its completed report in the
  diagnostic log: summary, discovery/context, individual results and requested
  optional diagnostics. `verbose` / `veryverbose` retain their existing detail
  and chat behavior; `copy` remains accepted but now saves through the log
  rather than opening an error report.
- Failed tests and completion of asynchronous `trackerperf` diagnostics use
  the same report destination. Keep the summary and failures visible in chat;
  never raise a deliberate Lua error merely to display the assembled report.
  Actual test assertions and failures must still be detected and reported.
- Retain the latest **10 complete test reports** in a dedicated section of
  the diagnostic SavedVariables, separate from rolling events and timings.
  Each report has a timestamp and sequence number. Preserve every report's
  lines and their order; when full, remove only the oldest complete report.
  Background activity cannot evict reports. Clear Diagnostic Log also removes
  the retained test reports.
- Each Debug Key press / `/ictest` run adds its own report, supporting sequences
  such as test, move an item into the bank, test again, then compare both reports.
- Chat confirms that a report was recorded in memory and explains that
  `/reloadui` or logout is needed before reading it from SavedVariables.
  Reports save even when background logging is disabled, without enabling it
  or recording unrelated events. If the diagnostic store is unavailable,
  explicitly report that the report was not saved; do not claim successful
  recording.
- Reading the saved diagnostic data after that flush replaces manual copying
  from the error window. No in-game file reader or new external runner is
  required. Offline unit-test execution remains unchanged.

## Preservation and compatibility

- The log is stored in the separate `InventoryCompanion_Diagnostics` saved
  variable, not in settings profiles; profile copying does not touch it.
- The setting is account-wide like Debug Mode and is not copied between profiles.
- The setting ships with Scanning Refactor's agreed settings schema 14 for
  both DEV and release; spike DEV settings schema 13 is historical, not a
  required recovery source or the production target. Diagnostic-log format
  schema 3 remains independent. Logging and Scanning Refactor ship together;
  do not deploy the new setting on an intermediate schema-11 build.
- Releases older than this feature do not declare the diagnostic saved variable;
  if a user downgrades, ESO may discard the log. The log is disposable, so this
  is acceptable.
- Existing diagnostic formats 1 and 2 migrate to format 3 without loss:
  events and tracker scan samples move into the current layout when needed;
  benchmark runs and unrelated fields stay. Format 3 adds the separate report
  history and its sequence counter. Throw-away spike settings/group recovery
  remains out of scope; diagnostic-store compatibility is independent.
- DEV builds from before this change must refuse the new diagnostic layout
  without changing it.

## Acceptance criteria

| ID | Required observable result | Verification and environment |
|---|---|---|
| AC1 | With logging on, background events and stream samples are written to `InventoryCompanion_Diagnostics`; with it off, no background entries are written and existing entries remain. Explicit test reports save independently. | Offline; in-game check of the saved file |
| AC2 | Events keep the newest 1,000 and each sample stream the newest 2,000, dropping the oldest. | Offline |
| AC3 | Clear Diagnostic Log asks for confirmation, then empties events, samples and retained test reports and reports it in chat. | Offline (action); in-game (dialog) |
| AC4 | The setting appears under Debugging, defaults off in release and on in DEV, and persists account-wide. | Offline; in-game |
| AC5 | Session start, release tracker refresh timings, DEV tracker mismatches and AutoCategory failures are logged when enabled. | Offline; in-game |
| AC6 | A malformed stored log disables logging for the session, is left unchanged, and is reported in chat; the addon otherwise loads. | Offline |
| AC7 | Diagnostic formats 1 and 2 migrate to 3 without losing events, samples, runs or unrelated fields; actual older format-1/2 readers refuse format 3 unchanged. | Offline migration/older-reader tests; approved in-game reload/file check |
| AC8 | Any addon code can log an event or a sample through one documented API. | Offline / code review |
| AC9 | `/ictest` reports, including `copy`, failures and asynchronous `trackerperf` completion, save even with background logging off, without changing that setting or deliberately raising report-output errors; existing verbosity and visible failure summaries are preserved. A separate history retains the latest 10 complete reports with timestamps and sequence numbers, evicting only the oldest complete report. Background activity does not affect that history. An unavailable store is reported explicitly. | Focused offline report-routing tests; in-game command checks |
| AC10 | After testing, moving an item into the bank and testing again, then `/reloadui` or logout, both reports can be read in sequence from the diagnostic SavedVariables with their summaries, results and requested details intact. | In-game before/after runs, flush and saved-file inspection |

## Options and product decisions

| ID | Options and trade-offs | Recommendation | Agreed decision and evidence |
|---|---|---|---|
| D1 | Gate logging by addon name, or by a user setting. A setting lets users capture evidence for bug reports. | Setting | Tim, 24 November: "maybe we have a setting 'logging enabled' and expose it in the debug section ... also put a 'clear log' button in there." |
| D2 | Which logs ship. | Session, tracker refresh timings, tracker mismatches, AC failures; FCO priority tripwire stays DEV | Tim: "your suggestions seem fine ... the implementation can have the framework plus some useful logs (your suggested list) for now" |
| D3 | Default state. | Off in release, on in DEV | Tim: "your suggestions seem fine" |
| D4 | Addon-name checks. | Remove the load-time folder check; keep the spike's own DEV-name check | Tim: "your suggestions seem fine" |
| D5 | Where to build it. | On `spike/fco-itemsaver`, cherry-picked to `main` later | Tim: "implement it here (might as well) then when we are back on main, we can cherry pick." |
| D6 | Copyable in-game test reports via deliberately raised errors or persistent diagnostics. | Diagnostic log | Tim, 24 November: "add it into the logging framework - move existing verbose copy (or just copy) out of error messages and into the log". Added for production; not implemented by the historical spike framework. |
| D7 | Gate explicit test reports on background logging? | Save independently | Tim, 24 November: "yes it should save when logging is off". |
| D8 | One report slot, rolling log entries, or a separate bounded report history? | Dedicated section holding the latest 10 complete reports, with timestamps and sequence numbers | Tim, 24 November, approved the separate 10-report history: "that's good. record it". Supports repeated Debug Key runs before and after a bank action. |

## Feasibility notes

- The current rolling logs live in `Core\FCOItemSaverSpike.lua`, which never
  loads in release. The framework moves to a new release file; see the plan.
- Those code/manifest references describe the preserved spike, not the current
  production branch. Its framework and manifest declaration must be promoted.
- LibAddonMenu buttons support `isDangerous` with a `warning`, which shows a
  confirmation dialog before the action runs.

## Independent spec review

Focused independent re-review: `focused-design-check` rubber-duck agent,
24 November: PASS for spec and plan after corrections. Tim's conditional
approval and GO are effective; feature acceptance remains pending.

Reviewer: independent `design-review` rubber-duck agent, 24 November
Reviewed document revision/source identity: working documents on
`feature/scanning-refactor`, base `69596b0`; preserved spike `16c31c2`.

| Finding | Evidence | Tim's decision | Resolution / re-review |
|---|---|---|---|
| Format 3 needed for report-history downgrade/clear guarantees; separate spike source from current branch wiring | First independent review T4-T5 | Technical corrections authorized by review GO | Spec/plan corrected; focused re-review PENDING |

## Approvals and acceptance

- Product discussion agreement: Tim, 24 November (D1-D5).
- Explicit spec approval: Tim's conditional approval effective after independent
  focused re-review PASS, 24 November.
- Feature acceptance: PENDING
- Actual acceptance evidence and disclosed limitations: PENDING

Process: [feature development](../../../Processes/FeatureDevelopment.md).
