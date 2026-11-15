# Vanishing progress bars: implementation plan

Status: ARCHIVED - ABANDONED 2026-11-15; no longer pursuing
TODO item: [D10.2 Vanishing Progress Bars](../../../Tasks/TODO.md)
Spec: [Shared HUD layout and visibility specification](HUDLayoutAndVisibility.md)
Archive index: [HUD layout and visibility archive](README.md)
Owner: Copilot (draft author)
Updated: 2026-11-08

Follow the [feature development process](../../../Processes/FeatureDevelopment.md).
Implement after [D10.1 HUD Positioning](HUDPositioningImplementationPlan.md)
and before [D10.3 Currency Grid Columns](CurrencyGridColumnsImplementationPlan.md).
D10.2 wires threshold-based visibility into the presentation-only controls
created by D10.1 in Manage HUD; it does not add a second settings surface.

## Current implementation and prior art

- [ProgressBarResources.lua](../../../../Banking/ProgressBarResources.lua) owns
  resource discovery, profile preferences, defaults, and setting accessors.
- [ResourceProgressBars.lua](../../../../Banking/ResourceProgressBars.lua) owns
  bar creation, rendering, position saves, and cutscene visibility. Its current
  `UpdateProgressBar` hides only for missing values, disabled bars, or cutscenes.
- [Events.lua](../../../../Core/Events.lua) registers currency/capacity/inventory
  listeners according to enabled resources and refreshes bars through existing
  debounced handlers. Below-threshold bars must remain monitored.
- [ItemDatabase.lua](../../../../Tracking/ItemDatabase.lua) validates every
  profile and copies resource preference tables. [Settings.lua](../../../../Core/Settings.lua)
  currently owns the LAM controls that D10.1 moves into Manage HUD.
- The [D10.1 plan](HUDPositioningImplementationPlan.md) owns persisted snapshots,
  editor controls, position handling, and Done/Cancel/reset behavior.

## Data, compatibility, and failure contracts

Use the existing account/character profile switch. Agreed stored deviations
are per-resource `hideBelowThreshold` (fraction, default 0) and `hideWhenEmpty`
(boolean, default true); missing values inherit defaults. Preserve `showBar`,
warning/danger thresholds, colors, positions, unknown unrelated fields, and
other preferences. Include all-profile validation and full-profile-copy coverage.
Malformed explicit values must be reported at the saved-data boundary.
Follow the existing storage convention, confirmed by Tim on 2026-11-08:
store thresholds as 0-1 fractions, display integer percentages in the UI, and
save only deviations. Omit threshold 0 and empty-hiding true; retain explicit
`hideWhenEmpty = false`.

Assess whether supported older builds preserve new fields safely. Apply the
schema-version rule if they do not; plan non-destructive migration and actual
older-build no-mutation refusal tests before normal SavedVariables UAT. Do not
select a schema number in this provisional plan.

Visibility is enabled, not cutscene-suppressed, and has available resource
values; in addition, zero amount is hidden when Hide When Empty is on, and a
positive amount must meet the inclusive percentage threshold. Compare the
unrounded fill fraction. A zero/nonpositive cap retains the existing 0%
calculation. Hidden enabled bars remain subscribed and refreshable. Positioning
temporarily overrides bar visibility without changing saved preferences and is
owned by D10.1's session transaction.
Monitoring is a correctness requirement, confirmed by Tim on 2026-11-08:
event predicates must use enabled state, not current on-screen visibility.
Use exact crossing through the existing event/debounce pipeline, as agreed in
the spec; add no polling, hysteresis, or extra visibility debounce.

## Ordered implementation

### Step 1: Establish saved-preference boundaries

- Depends on: D10.1 accepted and implemented; D10.2 plan approved and explicit
  GO to code.
- Spec coverage: AC1, AC7, AC11.
- Add defaults/getters/setters for per-resource preferences, preserving current
  `progressBarPreferences` structure. Validate every saved profile before use;
  verify full-copy independence and unknown/unrelated-data preservation.
- Determine downgrade/schema behavior from supported older readers. Add focused
  tests for omitted defaults, values 0/1 endpoints, invalid type/range/nonfinite
  data, explicit false, default-removal behavior, every profile, and migration/
  refusal behavior as applicable.

### Step 2: Apply visibility without disabling monitoring

- Depends on: Step 1.
- Spec coverage: AC1-AC6, AC11.
- Centralize the final rendering decision in `UpdateProgressBar`; ensure
  initialization, refresh, settings changes, profile changes, cutscene exit,
  and positioning exit reevaluate current values through it.
- Keep event registration and refresh decisions based on enabled resources,
  including bars currently hidden by threshold/empty state. Audit inventory,
  currency cap discovery, and capacity changes; do not add polling.
- Preserve colors, labels, saved positions, and other bars. Do not add stacking,
  animations, hysteresis, or notifications.
- Test below/equal/above boundaries, fractional rounding, 0/100, over-cap,
  empty/nonempty, unavailable values, zero cap, master-off, cutscene exit,
  profile changes, positioning override, and hidden-bar refresh with other
  consumers disabled.

### Step 3: Wire the existing Manage HUD placeholders

- Depends on: Step 2 and D10.1's approved editor/session implementation.
- Spec coverage: AC1, AC5-AC7, AC11-AC13.
- Wire the per-resource hide-below and hide-when-empty controls created in
  D10.1, removing their not-yet-available indication. Keep Hide Below above
  Warning Threshold. Both new controls are disabled when the bar's existing
  master switch is off; toggling the master preserves the new preferences.
- Evaluate the agreed list-item layouts and inclusive label in-game; preserve
  equality visibility. Hide When Empty may share the slider row only if feasible;
  a separate checkbox is acceptable. If hidden above threshold 0, retain its
  saved setting.
- Write edits through existing setters under D10.1's persisted snapshot. Done
  keeps edits; Cancel/reset/automatic exits
  follow its session contract. Positioning reveals actual bars without changing
  showBar or visibility preferences.

### Step 4: Document and verify

- Depends on: Step 3.
- Coverage: all D10.2 criteria.
- Update the user manual and plan with actual decisions, focused test output, and
  approved in-game crossing, cutscene, profile, and positioning results.
- No release/version/commit work is authorized.

## Code blueprint for Steps 1-3

#### Step 1: Extend existing preference contracts

- In `Banking\ProgressBarResources.lua`, modify existing
  `GetProgressBarSettings(resourceKey)` to return `hideBelowThreshold` and
  `hideWhenEmpty`, resolving missing values to 0 and true. Extend existing
  `SetProgressBarSetting(resourceKey, setting, value)` accepted keys and
  validation: threshold is finite 0-1; empty hiding is boolean. Use existing
  `StoreDeviation` with defaults 0/true; do not let the current danger-threshold
  `else` branch handle these new keys or modify alert thresholds accidentally.
  Remove empty resource preference tables exactly as existing setters do.
- In `Tracking\ItemDatabase.lua`, extend existing local
  `ValidateResourcePreference(preference, context)`/`PrepareProfilePreferences`
  for these fields in bar preferences. Validate all profiles before constructors
  through `PrepareSavedVariables`; extend version/migration gates and
  `Core\Init.lua.SettingsVersion` if the previous reader cannot preserve them.
  Existing `CopyItemListProfile` must deep-copy them with `progressBarPreferences`.
- Extend `Tracking\HUDSettingsSession.lua.ValidateHUDRecoveryRecord` to validate
  new nested bar fields; its captured `progressBarPreferences` already covers
  them. `ResetHUDSettingsSection("bars")` removes their overrides so getters
  restore defaults, while Cancel restores original overrides from the snapshot.
- Add `Project\Tests\ProgressBarVisibilityTests.lua` loading actual resource
  setters/getters in a stubbed Lua 5.1 runtime; expose
  `GetProgressBarVisibilityTests()` and add it to the suite tuple in
  `Project\Tests\Run-RuleTests.py`, loading dependencies in manifest order.
  Extend `SavedVariablesTests.lua` for inactive profiles, explicit false,
  malformed fractions/types, copying, record validation and older-reader refusal.

#### Step 2: Rendering and all refresh callers

- Keep one local `UpdateProgressBar(resource, control, settings)` in
  `Banking\ResourceProgressBars.lua`; no new cross-module visibility predicate.
  Obtain external values through existing `GetProgressBarResourceValues`, retain
  unavailable-value hiding, compute unrounded fraction once, update fill/color/
  label, then set whole-control visibility from cutscene, positioning override,
  showBar, threshold and zero-amount policy. Positioning overrides enable/threshold/
  empty hiding only, never unavailable values or cutscene suppression.
- Existing `InitResourceProgressBars` and `RefreshResourceProgressBars` call
  `UpdateProgressBar` with resolved settings; keep their control reuse/anchors.
  Modify existing `SetProgressBarsHidden(hidden)` to store cutscene state and
  call `UpdateProgressBar` for each existing control on both entry and return.
  Do not reveal a below-threshold control solely because the cutscene ended.
- Preserve enabled-state semantics of `HasVisibleProgressBars`,
  `IsProgressBarVisible`, `HasVisibleCurrencyProgressBars`,
  `IsCurrencyProgressBarVisible`, and `HasVisibleCappedProgressBars`.
  Their names are historical; document their monitoring contract rather than
  rename all callers for this ticket.
- In `Core\Events.lua`, trace `ShouldListenSlotUpdate`,
  `ShouldListenCurrencyUpdates`, `ShouldListenCurrencyCapUpdates`,
  `ShouldListenBagCapacity` and `ShouldListenBankCapacity` to those enabled-state
  APIs. Existing `OnInventorySlotUpdate`, `OnCurrencyUpdate` and
  `OnCapacityChanged` retain their 500ms Enqueue refreshes.
  `OnCurrencyCapsChanged` calls existing `RefreshProgressBarResourceDiscovery`;
  its inspected definition rebuilds discovery and calls
  `RefreshResourceProgressBars`; the event callback then calls
  `UpdateEventRegistry`. Keep this chain so a cap change can reveal a hidden bar.
- Caller chains: initialization -> `InitResourceProgressBars` -> local updater;
  profile refresh -> `InitializeProgressBarResources` ->
  `RefreshResourceProgressBars` -> updater; amount/capacity events -> Enqueue ->
  refresh -> updater; cutscene ticker -> `SetProgressBarsHidden` -> updater;
  editor setting/reset/exit -> `RefreshHUDSettingsPresentation` -> refresh -> updater.
- Test actual controls' hidden state at 74/100, 75/100, 76/100, 749/1000,
  0/100, over-cap, zero cap and unavailable values. Invoke actual event handlers
  with tracker/summary/notifications off and prove listeners still refresh
  hidden enabled bars; do not test only a standalone percentage helper.

#### Step 3: Activate placeholders, callbacks and reset

- In `Tracking\HUDSettingsPanel.lua.BuildBarsSection`, activate the existing
  Hide Below and Hide When Empty controls. Slider callback converts integer
  percent to fraction -> `SetProgressBarSetting(key, "hideBelowThreshold", value)`
  -> `RefreshHUDSettingsPresentation` -> `RefreshHUDSettingsPanel`.
  Checkbox callback follows the same chain with `hideWhenEmpty`.
- `RefreshHUDSettingsPanel` reads `GetProgressBarSettings` for slider/checkbox
  values and disabled state. Existing showBar checkbox and resource-label click
  use one toggle callback; test each toggles exactly once and retains visibility
  preferences. If the optional hide-empty row is hidden above zero, its value
  is untouched. Final presentation is evaluated in the visual trial.
- All callbacks edit the original profile protected by `hudEditRecovery`;
  `FinishHUDSettingsSession("cancel")` restores the nested preference snapshot.
  Reset uses the D10.1 reset chain, not a second transaction implementation.
- Run `python Project\Tests\Run-RuleTests.py --test-filter
  "ProgressBarVisibility|HUDSession|HUDRecovery"` with named production-method
  tests; extend runner stubs/XML assertions only for newly exercised APIs.
  Offline results and real event/UI observations remain PENDING.

## Verification and acceptance mapping

| Spec criterion | Step | Test / command | Required evidence | Actual result |
|---|---|---|---|---|
| AC1-AC3 | 1-2 | Focused preference/render tests with synthetic values. | Correct defaults and exact inclusive thresholds; no rounded-label comparison. | PENDING |
| AC4-AC6 | 2-3 | Event registry/handler tests; approved in-game resource crossing and cutscene return. | Hidden enabled bars refresh and reappear; unrelated panels, alerts and colors remain unchanged. | PENDING |
| AC7 | 1, 4 | All-profile/copy/migration tests and actual older-build refusal as applicable. | Preferences persist; malformed data reports; unsafe older builds refuse without mutation. | PENDING |
| AC11 | 1-3 | Empty/one-unit, combined-threshold, profile-copy and positioning tests. | Defaults hide empty bars; positive amount at threshold zero shows; positive thresholds apply with empty rule; editor override is transient. | PENDING |
| AC10, AC12-AC13 | 3 | D10.1 session tests and in-game Done/Cancel/reset. | New bar settings commit or roll back with the same editor session; reset scope is preserved. | PENDING |

Run the existing focused offline test runner with isolated resource/profile
fixtures. Never mutate live inventory or SavedVariables in synthetic tests.
Back up shared SavedVariables before approved in-game tests; schema changes also
require an actual older-schema backup and the release-process safeguards.

## Open questions and risks

| ID | Question / risk | Blocking phase and mitigation | Resolution |
|---|---|---|---|
| Q1 | Whether older supported readers preserve these preference deviations safely. | Step 1; inspect supported reader behavior and test downgrade before normal UAT. | PENDING |
| Q2 | Final UI wording/layout for the inclusive threshold and optional Hide When Empty placement. | Step 3; verify LAM/window fit and accessibility; behavior remains fixed. | PENDING |
| Q3 | Main regression risk is treating below-threshold as disabled and unregistering required updates. | Step 2; retain showBar-based event predicates and test isolated listeners. | PENDING |

## Independent plan review

Reviewer: PENDING
Reviewed plan/spec revision and source identity: PENDING

| Finding | Evidence | Tim's decision | Resolution / re-review |
|---|---|---|---|
| PENDING | PENDING | PENDING | PENDING |

## Approvals

- Explicit spec approval and revision: PENDING
- Explicit plan approval and revision: PENDING
- Explicit GO to code: PENDING

## Implementation record and deviations

None - planning only.

## Independent code review and verification

- Reviewer and reviewed diff/source identity: PENDING
- Findings, agreed corrections, and re-review: PENDING
- Actual test results and retained evidence: PENDING
- Unavailable checks and remaining limitations: PENDING

## Acceptance and handoff

- Approved in-game test scope and Tim-reported results: PENDING
- Explicit feature acceptance: PENDING
- Current spec, user docs, TODO, completed index, and archive links updated: PENDING
- Commit/merge authorization and outcome: PENDING
- Release: separate process; not authorized by feature acceptance.
