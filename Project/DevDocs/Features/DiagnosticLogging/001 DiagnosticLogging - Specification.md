# Diagnostic logging: feature spec

Status: DRAFT - Tim's direction agreed in chat; formal spec approval PENDING
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
- Out of scope:
  - In-game log viewer, export, upload, or chat output of log entries.
  - Per-category enable switches or adjustable size limits.
  - The FCO spike's benchmark runs (`/icfcodiagnostics`), which stay DEV-only
    and are not part of the user log.
  - The AutoCategory priority tripwire for the FCO deconstruct group, which is
    specific to the spike and stays DEV-only (but writes through the framework).

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
- While logging is off, nothing is written and existing entries are retained.
- Problems found while saved settings load (before the logging setting itself
  is known, such as an AutoCategory data error) are held and written after the
  session marker if logging is on, or discarded if it is off.
- If the stored log is malformed (users can edit saved variables), logging is
  disabled for the session, the stored data is left unchanged, and chat explains
  why. Other addon features continue.

## Preservation and compatibility

- The log is stored in the separate `InventoryCompanion_Diagnostics` saved
  variable, not in settings profiles; profile copying does not touch it.
- The setting is account-wide like Debug Mode and is not copied between profiles.
- The setting ships with the planned schema 13 bump for the FCO work.
- Releases older than this feature do not declare the diagnostic saved variable;
  if a user downgrades, ESO may discard the log. The log is disposable, so this
  is acceptable.
- Tim's existing DEV diagnostic data (spike format) is migrated without loss:
  events and tracker scan samples move into the new layout; benchmark runs stay.
- DEV builds from before this change must refuse the new diagnostic layout
  without changing it.

## Acceptance criteria

| ID | Required observable result | Verification and environment |
|---|---|---|
| AC1 | With logging on, events and stream samples are written to `InventoryCompanion_Diagnostics`; with it off, nothing is written and existing entries remain. | Offline; in-game check of the saved file |
| AC2 | Events keep the newest 1,000 and each sample stream the newest 2,000, dropping the oldest. | Offline |
| AC3 | Clear Diagnostic Log asks for confirmation, then empties events and samples and reports it in chat. | Offline (action); in-game (dialog) |
| AC4 | The setting appears under Debugging, defaults off in release and on in DEV, and persists account-wide. | Offline; in-game |
| AC5 | Session start, release tracker refresh timings, DEV tracker mismatches and AutoCategory failures are logged when enabled. | Offline; in-game |
| AC6 | A malformed stored log disables logging for the session, is left unchanged, and is reported in chat; the addon otherwise loads. | Offline |
| AC7 | Existing spike-format DEV data migrates without loss; older DEV builds refuse the new layout without changing it. | Offline; in-game reload on Tim's DEV data |
| AC8 | Any addon code can log an event or a sample through one documented API. | Offline / code review |

## Options and product decisions

| ID | Options and trade-offs | Recommendation | Agreed decision and evidence |
|---|---|---|---|
| D1 | Gate logging by addon name, or by a user setting. A setting lets users capture evidence for bug reports. | Setting | Tim, 24 November: "maybe we have a setting 'logging enabled' and expose it in the debug section ... also put a 'clear log' button in there." |
| D2 | Which logs ship. | Session, tracker refresh timings, tracker mismatches, AC failures; FCO priority tripwire stays DEV | Tim: "your suggestions seem fine ... the implementation can have the framework plus some useful logs (your suggested list) for now" |
| D3 | Default state. | Off in release, on in DEV | Tim: "your suggestions seem fine" |
| D4 | Addon-name checks. | Remove the load-time folder check; keep the spike's own DEV-name check | Tim: "your suggestions seem fine" |
| D5 | Where to build it. | On `spike/fco-itemsaver`, cherry-picked to `main` later | Tim: "implement it here (might as well) then when we are back on main, we can cherry pick." |

## Feasibility notes

- The current rolling logs live in `Core\FCOItemSaverSpike.lua`, which never
  loads in release. The framework moves to a new release file; see the plan.
- LibAddonMenu buttons support `isDangerous` with a `warning`, which shows a
  confirmation dialog before the action runs.

## Independent spec review

Reviewer: PENDING
Reviewed document revision/source identity: PENDING

| Finding | Evidence | Tim's decision | Resolution / re-review |
|---|---|---|---|
| PENDING | PENDING | PENDING | PENDING |

## Approvals and acceptance

- Product discussion agreement: Tim, 24 November (D1-D5).
- Explicit spec approval: PENDING
- Feature acceptance: PENDING
- Actual acceptance evidence and disclosed limitations: PENDING

Process: [feature development](../../../Processes/FeatureDevelopment.md).
