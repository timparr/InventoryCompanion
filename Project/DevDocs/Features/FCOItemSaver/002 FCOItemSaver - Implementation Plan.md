# FCO ItemSaver diagnostic spike: implementation plan

Status: Implemented on spike branch; in-game testing and acceptance pending
TODO item: None; user-requested feasibility spike
Spec: [diagnostic spike spec](<001 FCOItemSaver - Specification.md>)
Owner: Copilot
Updated: 2026-11-20

## Open questions

| ID | Question | What is needed to resolve it |
|---|---|---|
| Q1 | Which FCO marker-change paths emit inventory events? | **Investigation:** approved in-game before/after observations; no assumption that one result covers every path. |
| Q2 | What should the MVP performance limit be? | **Behavior decision:** discuss measurements and agree a measurable limit before MVP acceptance. |

## Current implementation and prior art

`Core/Scanning.lua` returns `bagId`, `slotIndex`, item ID, link and count.
`Core/Events.lua` listens for slot updates under its own name; the diagnostic
must use a separate event registration. `Core/RuleTests.lua` uses isolated
synthetic state and restores replaced globals. `Core/Tests.lua` contains
read-only scans and synthetic timing. FCO's installed API documents
`IsMarked` and gamepad restrictions. The DEV flag is set by
`Core/Development.lua`, which release packaging removes.

## Technical options and decisions

| ID | Alternatives and trade-offs | Recommendation | Agreed choice and evidence |
|---|---|---|---|
| D1 | One-shot scans vs a watcher for the event question. | Explicit start/stop observer with snapshot comparison; no persistent hook. | PENDING |
| D2 | Synthetic prototype vs claiming a tracker regression before support exists. | Test a separate candidate accumulator and clearly label it. | PENDING |

## SavedVariables changes and migration

No persisted fields or migration are proposed. All diagnostic state is local
and transient. FCO's read API is external; inspect its readiness and do not call
marker-writing APIs. The diagnostic must not use normal saved profiles as
synthetic fixtures.

## Data, compatibility, and failure contracts

Validate external addon/API availability, readiness, mode, marker ID and query
returns. FCO's `gAddonLoaded`, `libsLoadedProperly`, `settingsVars.settings`
and its marker storage table must exist before a query. Check the settings table
before calling `GetSavedVarsMarkedItemsTableName`; then check both the named
table inside settings and `FCOIS[name]`. Do not call FCO's
`CheckIfFCOISSettingsWereLoaded` as a readiness probe, as it can load settings.
Require `settings.isIconEnabled[markerId] == true` and a marker storage
subtable at `FCOIS[name][markerId]`; report disabled markers and missing
storage explicitly rather than treating them as unmarked. This spike rejects
disabled markers even if FCO is configured to check deactivated icons.
Resolve the storage name without an override immediately before each
synchronous query operation, using the same settings as `IsMarked`.
These are installed-version signals, not a promise
of a stable public readiness API. Accept a query only when its first return is
boolean and second return is a table; bare `false` or `nil` is unavailable or
failed, not an unmarked result. Require marker ID to be an integer from 1
through `FCOIS.numVars.gFCONumFilterIcons`; the default is
`FCOIS_CON_ICON_SELL_AT_GUILDSTORE`. In keyboard mode query normally; when
`IsInGamepadPreferredMode()` is true, call FCO's
`CheckIfADCUIAndIsNotUsingGamepadMode` and proceed
only when it returns true. Missing predicate is an explicit failure.
Surface failures. An observer uses its own event namespace and is
unregistered on stop, including when snapshot/reporting fails. No broad catch
may turn a failure into success. Counts and timings are evidence, not a
performance certification. Gamepad support follows FCO's documented boundary.
The branch-only diagnostic file, manifest entry and offline test harness
wiring must be removed or deliberately redesigned before any release; a DEV
flag alone does not exclude the runtime file from the staged package.

## Implementation tasks

### Task 1: DEV-only live diagnostic

- Depends on: spec approval, plan approval and GO to code.
- Spec coverage: AC1, AC2, AC4, AC5.
- Files/methods and affected callers: add `Core/FCOItemSaverSpike.lua`; add it
  after `Core/Scanning.lua` in `InventoryCompanion_DEV.txt`. The file registers
  `/icfcotest` only when `InventoryCompanion.IsDevelopment` is true.
- Method contracts: local `ValidateFCO(markerId)` validates external
  readiness, supported mode and marker ID; local `CaptureBackpack(markerId)`
  returns occupied slot snapshots and marker results or explicitly fails.
  `RunScan` measures ten baseline iterations and ten FCO-query iterations on
  the same captured slots with `GetGameTimeMilliseconds` and reports
  counts/timings. `StartWatch` captures a
  snapshot and registers a separate backpack slot listener; `StopWatch`
  unregisters it before capturing/reporting the final snapshot and event
  evidence. `RunCommand` validates arguments and dispatches these operations.
- Caller wiring and state: slash command calls dispatcher after addon load;
  watch state stays local in memory. Reject an already-active watch; stop and
  reload end it. Validate FCO at every operation that calls it. Report
  inconclusive before/after comparisons when item identities or marker state
  cannot establish a changed slot. Capture the ESO item unique ID using
  `zo_getSafeId64Key(GetItemUniqueId(bag, slot))`; only a nonempty, nonzero
  unchanged ID at the same slot permits reporting a candidate marker change.
  An added, removed, replaced or moved item is inconclusive. The listener
  filters for backpack events using `REGISTER_FILTER_BAG_ID` and observes raw
  events, not IC's debounced refresh count. Stop unregisters before checking
  the current mode, so a mode change cannot strand a listener.
- Verification: stub FCO, mode, inventory, clock and event manager in focused
  offline tests; exercise success, errors, lifecycle and cleanup. In-game
  observations require separate approval.

### Task 2: Synthetic candidate and timing exercise

- Depends on: Task 1 command wiring.
- Spec coverage: AC3, AC4, AC5.
- Files/methods and affected callers: in `Core/FCOItemSaverSpike.lua`, local
  `RunSynthetic` uses fabricated slot records and a local candidate
  accumulator; it never replaces or invokes production tracker state. Add
  `Project/Tests/FCOItemSaverSpikeTests.lua` and load that suite in a separate
  Lua runtime in `Project/Tests/Run-RuleTests.py`, explicitly supplying the
  spike source and stubbing the slash registry, clock, ESO events, inventory,
  FCO readiness/API and gamepad boundaries.
- Contract: same item ID with one marked and one unmarked must produce the
  marked-only quantity and independent all-copy quantity. Include a bounded
  synthetic repeated scan/burst with recorded elapsed time; clearly report it
  as prototype timing, with no arbitrary pass threshold.
- Verification: assert exact synthetic counts and failure reporting offline;
  run in-game after approval. This does not certify tracker aggregation.

## Verification and acceptance mapping

| Spec criterion | Task | Test / command | Required evidence | Actual result |
|---|---|---|---|---|
| AC1 | 1 | Offline stubs; `/icfcotest scan` | Correct output/counts/timings; live FCO observation | Offline PASS; one in-game scan observed, broader cases PENDING |
| AC2 | 1 | Offline event stubs; `watch` then `stop` | Separate listener cleanup, snapshots and event report | Offline PASS; one in-game marker change observed, broader paths PENDING |
| AC3 | 2 | Offline prototype cases; `synthetic` | Exact mixed-copy counts and diagnostic timing | Offline PASS; in-game PENDING |
| AC4 | 1-2 | Offline invalid-input/error cases; code inspection | Explicit failures and no live writes | Offline PASS; in-game PENDING |
| AC5 | 1-2 | Focused `Run-RuleTests.py` and release-mode stub | Related tests pass; DEV-only registration | Focused offline PASS; full suite not run |

## Independent plan review

Reviewer: independent `rubber-duck` agent, `spike-plan-review`
Reviewed plan/spec: draft before marker-range and identity clarifications;
`spike-focused-review` and `marker-guard-review` reviewed the corrections.

| Finding | Evidence | Tim's decision | Resolution / re-review |
|---|---|---|---|
| Require an in-range integer marker ID and explicit default. | FCO `IsMarked` can return false for an unknown marker. | Clarify validation. | Added range/default; focused review verified. |
| Define a reliable item identity for watch comparisons. | IC scan records do not include unique ID. | Identify same item or report inconclusive. | Added ESO unique-ID capture and replacement handling; focused review verified. |
| FCO can return false for disabled markers. | FCO `CheckIfItemIsProtected` | Avoid misleading negative results. | Reject disabled marker and missing marker storage; focused review verified. |

## Approvals

- User expressed spec and plan approval: "ok I'm approveing both".
- User separately authorized coding: "go".
- Independent plan and focused reviews: `spike-plan-review`,
  `spike-focused-review`, `marker-guard-review`; documented blockers resolved.

## Implementation record and deviations

- Added `Core/FCOItemSaverSpike.lua` and its DEV manifest entry, plus isolated
  `Project/Tests/FCOItemSaverSpikeTests.lua` and runner wiring.
- The watcher additionally treats changed item details or counts as
  inconclusive, preventing stack changes from being presented as marker changes.
- The synthetic exercise is a standalone candidate, not an actual IC group or
  a measurement of real FCO calls.

## Independent code review and verification

- Reviewer: independent `code-review` agent `fco-spike-code-review`; no
  significant issues found. Reviewed Git blob identities: runtime
  `acfbcaf4a77d10dcd5d651551d2d2aa7a6ea916d`, offline tests
  `76b2a399d4693706b315c245db3db58d98ddfc72`, runner
  `797a6891d72726589e5e13af13454b7dabc1370c`, manifest
  `c171a287dd417fc912679bffeddcc9a1bb144027`.
- Offline: `python Project\Tests\Run-RuleTests.py --test-filter 'FCO spike|Scanning and notifications|Cached synthetic'`
  passed 8/8; Lua 5.1 syntax compilation passed.
- In-game, 20 November 2026: screenshot showed an initial backpack scan with no
  matching slots, 22 ms for ten FCO-query passes and 0 ms baseline iteration.
  Watch/stop detected slot 57 changing from false to true with zero backpack
  slot events. This is one observation, not a general event guarantee.
- The user reports running the synthetic command, but its output was not
  captured. Complete MVP behaviour and further in-game checks remain PENDING.
- The diagnostic prints to chat; the user identified that copyable error-report
  output is needed for future evidence. No such output was implemented.

## Acceptance and handoff

- Approved in-game test scope and actual results: PENDING
- Explicit spike acceptance: PENDING
- Archive and links: PENDING
- Commit/merge: not authorized
- Release: separate process; not authorized.
