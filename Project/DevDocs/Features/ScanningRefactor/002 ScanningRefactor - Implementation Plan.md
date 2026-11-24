# Scanning Refactor: implementation plan

Status: PROVISIONAL - documentation split authorized; production coding not authorized
TODO item: None; promotion of the existing FCO spike backend
Spec: [feature spec](<001 ScanningRefactor - Specification.md>)
Owner: Copilot
Updated: 2026-11-24

Follow the [feature development process](../../../Processes/FeatureDevelopment.md).
This is an extraction/promotion plan, not a replacement algorithm proposal.

Documentation handoff, 24 November: the production feature documents are
carried onto `main` before creating `feature/scanning-refactor`. The reference
implementation remains on `spike/fco-itemsaver` at `16c31c2`; no spike runtime
code is included in this documentation handoff. Historical testing and
approvals are in the [spike archive](../../Archive/FCOItemSaver/Spike).

## Current implementation and prior art

Inspected baseline: `383644c`, `spike/fco-itemsaver`.

| Source | Existing mechanism to preserve |
|---|---|
| `Core\Scanning.lua` | `ReadSlot` returns one item record or nil for an empty slot; `GetBagContents` uses it and supports cooperative checkpoints. |
| `Core\FCOItemSaverSpike.lua` | `ValidateFCOReadiness`, `ValidateFCO`, `QueryMarker`, `SupportsMarkers`; four `markerGroups` registered as preloaded `slotMatcher` rules. |
| Same spike module | `CreateMatchingContext` and `GetPreparedMasterItemList` batch selected-marker answers per occupied slot, build marker candidate lists, and return a snapshot plus slot index. |
| Same spike module | `CaptureLiveSnapshot` already enumerates FCO's numeric marker range and calls `GetIconText`. Its diagnostic loop selects enabled markers; production must instead register all defined IDs. |
| `Tracking\ItemDatabase.lua` | `BuildMasterItemList` prepared matching/replay path; `EvaluateTrackerSlot`, `BuildTrackerSnapshotFromSlotIndex`, `GetTrackerContext`, runtime-rule cache and invalidation. |
| `Tracking\ItemTrackerPanel.lua` | `StartSlicedTrackerRefresh`, `QueueTrackerSlotUpdate`, `ApplyTrackerSlotUpdates`, `ApplySlotsToIndex`, `AdoptTrackerSlotIndex`, `NoteTrackerFullInventoryUpdate`, `PollTrackerMarkers`. |
| `Core\Events.lua` | Slot events queue incremental work and retain a 500 ms debounced refresh; DEV full-update listener requests top-ups without discarding the view. |
| `Tracking\EditPanelGroupsTab.lua` / `.xml` | Existing hidden-group handling, rename, Include/Exclude pattern editor, display overrides and built-in reset. No new marker UI needed. |
| `Tracking\AutoCategoryIntegration.lua` | Existing IC predicate, per-area participation/order, explicit failure/Retry Sync and AC item-hash clearing. |
| `Core\DiagnosticLog.lua` | General event/sample API, implemented separately in the [logging plan](<../DiagnosticLogging/002 DiagnosticLogging - Implementation Plan.md>). |

### Working algorithm, not proposed optimization

- `GetPreparedMasterItemList` uses
  `CreateMatchingContext("batched", false, markerIds, false)`: production
  preparation currently caches marker answers, **not** the experimental
  name/pattern caches. Do not enable benchmark alternatives during extraction.
- Snapshot state is `{items, groups, ruleIndex}`. Slot index state includes
  captured bag/slot order, item data, matched rule keys and marker keys.
  Rebuild aggregation preserves source-link/icon ordering and tracked-item
  rescue semantics instead of subtracting/adding mutable totals.
- Full scans yield after clock checks every 16 checkpoints: target 8 ms,
  requested inter-slice delay 10 ms. Completion replays dirty slots and flushes
  pending updates before verification/adoption, then schedules rendering
  separately with `zo_callLater(..., 0)`.
- Marker polling runs from a 1-second registered update, target 2 ms slices
  checked every 8 slots. Its gate uses actual tracker visibility and a
  non-`hud` scene. No scene-list rewrite or FCO marking hooks are required.
- `"inventory"` refreshes are sliced; other refresh reasons currently remain
  synchronous. Slot events do not restart an active top-up. Full updates can
  request one further top-up.

## Technical options and decisions

| ID | Alternatives | Direction |
|---|---|---|
| T1 | Rebuild from the slot index vs incremental arithmetic totals. | Retain the tested slot-index rebuild. Agreed during spike stage 1. |
| T2 | Move existing prepared matching vs introduce a new cache/index design. | Move existing code, preserve contracts and budgets. Tim's scope direction. |
| T3 | Put all production code into one renamed spike vs separate scanner and optional FCO boundary. | Proposed: `Tracking\PreparedScanning.lua` owns prepared matching; `Core\FCOItemSaver.lua` owns FCO readiness/registry/API access. Keep tracker scheduling where it is. Independent plan approval PENDING. |
| T4 | Keep four hard-coded marker groups vs generate one per defined ID. | Generate the registry using the observed range/name API; stable keys based on marker ID, all new baselines hidden. Tim's scope direction. |
| T5 | Reuse an experimental settings schema vs a distinct production schema. | AGREED: schema 14 for both DEV and release. Tim, 24 November: "14 then". Preserve supported older migrations, including normal schema 11 and spike schemas 12/13; verify older-reader refusal. |
| T6 | Register groups during IC startup vs delay initialization or introduce retries. | AGREED: initialize diagnostic logging, register stable FCO built-in identities and available names, then preflight/migrate saved data, construct profiles and initialize AC/tracker. Retain the optional FCO dependency and separate identity from marker readiness. Tim, 24 November: "update the plan then". |

### Startup ordering and FCO readiness

The installed FCO source was inspected on 24 November:

- `FCOItemSaver\FCOIS_Constants.lua:690` defines the marker-range maximum
  during file loading.
- `FCOItemSaver\src\EventsHooks\FCOIS_Events.lua:1119-1254` handles FCO's
  own `EVENT_ADD_ON_LOADED`, loads user settings synchronously and sets
  `gAddonLoaded = true` on successful supported-mode initialization.
- `FCOItemSaver\FCOIS_API.lua:1621` implements `GetIconText`; it accesses
  settings and may return nil. Read names only when the FCO boundary is
  ready, not as a way to force FCO settings to load early.

Keep `FCOItemSaver` in `OptionalDependsOn`, so its normal addon-loaded
initialization precedes IC's. In `Core\Init.lua` `Initialize`, use this order:

1. `DiagnosticLog.Initialize()`.
2. `FCOItemSaver.RegisterBuiltInGroups()`: establish stable group identities
   and obtain the defined marker range/names when FCO metadata is available.
3. `PrepareSavedVariables()`: validate/migrate all profiles and references.
4. ZOS saved-variable constructors, settings validation and
   `DiagnosticLog.Start()`.
5. Runtime-rule/profile validation, then existing AC and tracker initialization.
6. Start the existing marker-poll timer after tracker initialization.

Group identity does not depend on successful marker reads. With FCO
absent/not ready, preserve recognized saved FCO identities, overrides and
AC references through preflight; do not reinterpret them as custom groups
or normalize away their edits. Report unavailability, keep ordinary name
matching usable and do not query markers until the boundary is ready.
Disabled markers remain defined groups, not registration failures.

No arbitrary startup delay, `EVENT_PLAYER_ACTIVATED` deferral or new retry
framework is introduced. This establishes normal startup wiring, not a
diagnosis of the earlier unconfirmed AC readiness incident. Regression tests
must exercise successful dependency ordering, absent/not-ready FCO and
saved-identity preservation; inspection is not an in-game test result.

## SavedVariables changes and migration

Runtime index/caches are not persisted. No arbitrary saved `markers` list is
introduced: a built-in's marker comes from its registered baseline, as its
`slotMatcher` does today.

Proposed production identities: `__ic_fco_marker_<id>`. A normal saved built-in
override retains the existing shape:

```text
trackedRules[productionKey] = {
    displayName = optional user name,
    patterns = optional existing Include/Exclude pattern list,
    display = optional ordinary display overrides
}
```

Untouched new baselines need no copied saved definition. Existing profile
copy/normalization code remains responsible for ordinary overrides.

- Use settings schema **14 in both DEV and release**, agreed by Tim on
  24 November. Preserve existing supported older migration paths and migrate
  normal schema 11 and spike schemas 12/13 into 14. This is separate from
  diagnostic schema 2.
- Verified source baseline: `main` and published tag `v1.8.1` use settings
  schema 11 and reject newer versions before migration; the spike uses
  release-mode 12 / DEV 13. Actual downgrade tests against those readers
  remain required; source inspection alone is not a test result.
- `PrepareSavedVariables` in `Tracking\ItemDatabase.lua` performs staged
  preflight/migration on every profile and retained list backup before the
  ZOS constructors in `Core\Init.lua`.
- Map the four known spike keys (vendor, deconstruct, guild store and marker
  17) to their corresponding production IDs. Preserve user-edited fields,
  explicit visibility and all per-context `ic:<key>` references in Display,
  Priority, hidden maps and remembered positions.
- Unedited spike baselines can become the new hidden defaults; never treat
  a user's explicit Show/Hide choice as an unedited default.
- Validate collisions and all migrated references before committing changes.
  Report incompatible/ambiguous data and preserve the original on failure.
- Preserve saved edits when FCO is absent/unavailable; metadata availability
  must not cause custom-group reinterpretation, deletion or validation loss.
  Apply the identity/readiness separation in the startup contract above.
- Test refusal by actual supported older readers without any mutation.

## Data, compatibility, and failure contracts

- Registry keys are stable per marker ID, not derived from translated/custom
  labels. Disabled markers remain registered; active scans query only
  available markers required by active rules.
- The FCO adapter validates external readiness/API answers. Empty slots are
  unmarked; invalid occupied-slot answers are explicit boundary failures.
  Ordinary name matching remains usable when markers are unavailable.
- A slot index is usable only for its captured profile, tracker revision,
  runtime rules, active rule names and marker availability. Existing job
  context checks additionally protect bank/ESO Plus transitions.
- Required internal methods/state are called directly and fail fast.
  Do not add nil guards as substitutes for correct initialization.
- Retain existing synchronous callers and return shapes. Do not make banking,
  notifications or AutoCategory predicate calls asynchronous.
- General events/timings use `DiagnosticLog`; disabled logging must not
  disable scanning or leave required methods owned by the spike.

## Implementation tasks

### Task 1: extract the working production scanner and FCO API boundary

- Depends on: approved spec/plan and separate GO to code.
- Spec coverage: AC1, AC4, AC8, AC10.
- Files/methods:
  - Create `Core\FCOItemSaver.lua`, exposing `this.FCOItemSaver` with the
    existing readiness/marker availability, single/batched read,
    `GetActiveMarkerIds` and `ReadSlotMarkerKey` contracts.
  - Create `Tracking\PreparedScanning.lua`, exposing
    `this.PreparedScanning.GetPreparedMasterItemList` by moving the working
    preparation/context/capture path out of `Core\FCOItemSaverSpike.lua`.
  - Modify `Tracking\ItemDatabase.lua` `GetMasterItemList` to use that path
    in DEV and release, including a zero-marker/name-only scan. Reuse
    `BuildMasterItemList`, `EvaluateTrackerSlot` and
    `BuildTrackerSnapshotFromSlotIndex`; retain existing test entry points.
  - Update `InventoryCompanion_DEV.txt`: load the FCO adapter after
    `Core\Scanning.lua`, and prepared scanning after
    `Tracking\ItemDatabase.lua`, before tracker use. The spike may load
    earlier but may call extracted methods only after all files load.
- Contracts/data flow: tracked items + active rules + bag IDs + optional work
  checkpoints produce the same snapshot and captured slot index. FCO calls
  stay behind the adapter; per-scan caches die with their scan.
- Preservation: do not switch to experimental direct/private-storage reads,
  name caches or new matching semantics.
- Verification: run existing prepared/baseline and incremental equivalence
  tests against extracted code; add no-FCO and zero-marker coverage where
  missing. Run the same code in a release-mode fixture.

### Task 2: generate hidden built-ins and migrate their identities

- Depends on: Task 1.
- Spec coverage: AC6-AC9.
- Files/methods:
  - `Core\FCOItemSaver.lua`: create `RegisterBuiltInGroups`, using the known
    marker range/name APIs and the existing per-baseline `slotMatcher`
    approach. Bind each closure to one marker ID; sort registry by ID.
    Preserve saved identities independently of FCO readiness; only read FCO
    metadata when available, following the startup contract above.
  - `Core\Init.lua` `Initialize`: call `RegisterBuiltInGroups` immediately
    after `DiagnosticLog.Initialize`, before `PrepareSavedVariables` and
    runtime-rule/AC validation. Keep the optional manifest dependency.
    Start polling later (Task 3).
  - `Tracking\ItemDatabase.lua` `PrepareSavedVariables`: stage/validate the
    migration above; retain `GetRuntimeRules`, existing `UpdateRulePatterns`,
    `UpdateRuleProperty` and built-in reset/display handling.
  - `Core\Init.lua` `SettingsVersion`: set 14 for both DEV and release.
- State: registered baselines have no name patterns, a single marker matcher,
  and `display.isHidden = true`; user overrides continue to resolve normally.
  New AC references are not automatically opted in.
- Wiring: registry -> saved preflight -> constructors -> runtime rules ->
  tracker and AC. No new marker fields, picker or XML controls.
- Preservation/errors: keep disabled definitions, edited labels/patterns,
  explicit visibility and AC orders; reject collisions before mutation.
- Verification: all-ID/disabled-ID registry tests, hidden defaults, ID-bound
  closure tests, rename/pattern/reset/profile tests, startup order with ready
  FCO, absent/not-ready FCO identity preservation without marker queries,
  and migration/downgrade tests.

### Task 3: enable the existing scheduling paths in production

- Depends on: Task 1 and Task 2's startup wiring.
- Spec coverage: AC1-AC5, AC10.
- Files/methods:
  - `Tracking\ItemTrackerPanel.lua`: replace spike calls in index validation,
    `StartSlicedTrackerRefresh`, `ApplySlotsToIndex`, `PollTrackerMarkers`,
    and logging with their production owners. Remove DEV/spike gating from
    `RefreshItemTrackerPanel`; keep its reason-dependent behavior.
  - `Core\Events.lua`: make slot queuing and the full-update listener
    production paths, preserving existing listener conditions and debounce.
  - `Core\Init.lua`: initialize the normal scan lifecycle and register the
    existing 1-second marker poll after tracker initialization; keep DEV
    benchmark initialization separate. Use one timer per installation.
- Flow: slot event -> queue/dirty set -> scheduled slot re-evaluation ->
  rebuild/render; full update -> top-up/rerun; timer -> eligible sliced
  marker pass -> queue changed slots through the same path.
- State/errors: tracker owns jobs/index/pending slots; profile/rule/context
  changes invalidate obsolete work. Preserve cancellation and coroutine
  error propagation, deferred rendering, 8/2 ms budgets and 10 ms delay.
- Verification: reuse next-frame, dirty-replay, full-update, context-change,
  hidden/HUD and poll tests with release-mode fixtures; test without FCO.

### Task 4: separate diagnostics and verify integration boundaries

- Depends on: Tasks 1-3 and the separately reviewed logging framework.
- Spec coverage: AC4, AC8, AC10.
- Files/methods:
  - `Core\FCOItemSaverSpike.lua`: retain DEV benchmarks, comparison probes,
    slash commands and priority tripwire only; have them call production
    helpers, not own required production behavior.
  - `Tracking\ItemTrackerPanel.lua`: route production timing/mismatch events
    to `DiagnosticLog.Sample` / `Event`. Move shared snapshot comparison out
    of the spike if still needed by normal verification.
  - `Tracking\AutoCategoryIntegration.lua` `Fail` and retry/cache-clear path:
    preserve current failure reporting, empty-slot handling, assignment
    repair and saved Priority/Display separation. No new deferral engine.
  - `Core\Tests.lua`, `Project\Tests\Run-RuleTests.py` and affected existing
    Lua test fixtures: separate production tests from DEV diagnostic tests.
- Verification: no normal call requires `FCOItemSaverSpike`; logging on/off
  has identical matching results. Check mark/unmark and AC priority in
  backpack/bank, including Retry Sync. Present findings before fixes outside
  approved scope.

### Task 5: independent review, acceptance and handoff

- Depends on: Tasks 1-4.
- Spec coverage: AC1-AC10.
- Independently review the exact production diff and migration against the
  approved documents; discuss findings before changes.
- Run `python Project\Tests\Run-RuleTests.py`, then approved focused in-game
  acceptance with appropriate backups. Synthetic tests never mutate live
  inventory or normal saved data. Older-backup UAT follows release safeguards.
- Update BBCode source manual/changelog to describe delivered behavior, not
  deferred marker UI. Record actual results/limitations before acceptance.
- Keep baseline `383644c` available for rollback/comparison. Do not restore
  newer saved data into an older reader; rollback includes an appropriate
  pre-migration backup.
- Branch switch, merge to `main`, push and release need their own authorization.

## Verification and acceptance mapping

| Criteria | Tasks | Required evidence | Production result |
|---|---|---|---|
| AC1, AC4 | 1, 3, 4 | Fresh/indexed equivalence, correct ordinary tracking, context isolation, explained mismatch logs | PENDING |
| AC2 | 3 | Next-frame batching, uninterrupted top-up and dirty replay tests; crafting/pickup UAT | PENDING |
| AC3 | 3, 5 | Preserved cooperative budgets/deferred render; comparable before/after heavy-workload logs and smoothness observations | PENDING |
| AC5 | 3 | Marker changes without slot events, visibility/HUD gate, resumed polling | PENDING |
| AC6, AC7 | 2 | Full ID registry, hidden/AC defaults, edits/reset/profile/reload tests | PENDING |
| AC8 | 1, 2, 4 | No-FCO/not-ready/disabled marker and empty-slot tests; AC backpack/bank/retry UAT | PENDING |
| AC9 | 2, 5 | All-profile migration, real older-reader refusal, older-backup UAT | PENDING |
| AC10 | 1, 3, 4 | Release-mode tests and manifest/call-site review without spike dependencies | PENDING |

## Independent plan review

Reviewer: PENDING
Reviewed plan/spec revision and source identity: PENDING
Findings, Tim's decisions and re-review: PENDING

## Approvals

- Explicit spec approval and revision: PENDING
- Explicit plan approval and revision: PENDING
- Explicit GO to production code: PENDING
- Tim authorized this documentation split on 24 November, not a branch switch
  or merge.

## Implementation record and historical evidence

This split changes documents only. No production extraction has been done.

- Stage 1 was authorized on 23 November with disposable DEV saved data.
  The slot-index rebuild replaced arithmetic deltas; offline 336/336 passed.
- Stages 2-3 were authorized together on 23 November, rollback `e4d668b`;
  implemented in `fbe1660`. Offline 337/337 passed. The working implementation
  retained 8 ms slices, 500 ms debounce and a visible non-`hud` poll gate.
- A Tasks 2-3 spike code review found polling used the tracker setting rather
  than actual visibility; Tim approved the fix. That limited review is not
  a review of this production plan.
- Subsequent priority/AC/mismatch/logging work is recorded in spike D41-D45.
  Baseline `383644c` has a recorded 343/343 offline pass.
- Tim, 24 November: the system is "very smooth and faster than it was before
  fco with the new cache/timeslice tecnology". Preserve this observed benefit.
- Crafting/full-update discrepancies were investigated during play; correct
  production results still require AC4 verification, not just smoothness.

## Independent code review and verification

- Production reviewer and reviewed source identity: PENDING
- Production findings/corrections/re-review: PENDING
- Fresh production test results: PENDING
- Limits: all-marker generation/hidden defaults and extraction are not yet
  implemented; current non-inventory refresh paths are synchronous.

## Acceptance and handoff

- Approved production in-game test scope: PENDING
- Actual production results and explicit feature acceptance: PENDING
- User docs, archive/index/TODO closeout: PENDING
- Commit/merge authorization and outcome: PENDING
- Release: separate process; not authorized here.
