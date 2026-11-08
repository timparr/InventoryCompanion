# Configurable currency grid columns: implementation plan

Status: PROVISIONAL - not approved; coding not authorized
TODO item: [D10.3 (formerly F1)](../../Tasks/TODO.md)
Spec: [Shared HUD layout and visibility specification](../FeatureSpecs/HUDLayoutAndVisibility.md)
Owner: Copilot (draft author)
Updated: 2026-11-08

Follow the [feature development process](../../Processes/FeatureDevelopment.md).
This plan covers D10.3 only. Criterion references below use the shared spec's
CG1-CG6 (the former column-only AC1-AC6), not its bar-visibility AC criteria.
Delivery follows [D10.1 HUD Positioning](HUDPositioningImplementationPlan.md)
and [D10.2 Vanishing Progress Bars](VanishingProgressBarsImplementationPlan.md).
The column control is created as a presentation-only placeholder in D10.1's
Manage HUD currency section; this ticket wires its behavior, removes its
not-yet-available indication, and extends the section reset. Reuse the shared session,
preference, and refresh paths rather than creating a second editor/settings path.

## Current implementation and prior art

- [CurrencyPanel.lua](../../../Tracking/CurrencyPanel.lua): fixed column constant,
  width accumulation and row-major anchors in RefreshCurrencyPanel;
  GetCurrencyPanelSettingsControls and ResetCurrencyPanelPreferences own its UI.
- [ItemDatabase.lua](../../../Tracking/ItemDatabase.lua): preferenceFields,
  preferenceDefaults, PrepareProfilePreferences, full copy, RefreshProfileSettings.
- [Constants.lua](../../../Core/Constants.lua): account defaults.
- [SavedVariablesTests.lua](../../Tests/SavedVariablesTests.lua) and
  [Core tests](../../../Core/Tests.lua): existing profile and grid cases.

## Data, compatibility, and failure contracts

After D10.1, Manage HUD has Done/Cancel and per-section reset. Column changes
render live through the original profile protected by D10.1's persisted snapshot:
Cancel restores the starting column preference; Done keeps edits. Reset currency
section restores 3 columns and is itself reversible with Cancel. Coordinate
transaction handling with the shared editor; do not create another commit path.

Store `currencyGridColumns` directly in the existing profile, confirmed by Tim
on 2026-11-08; do not introduce a layout table or reorganize existing settings.
Agreed: positive finite integer, missing legacy value defaults to 3. Slider maximum
is the available resource-cell count before visibility/zero filtering, using normal
combined-cell grouping, and at least 3. Do not enforce that dynamic count as a
saved-data upper bound: retain valid choices if discovery later shrinks.
Wire account
defaults, every-profile preparation, full-copy ownership, reset, and active-profile
refresh. Explicit malformed values must fail at the loading boundary.
Before coding, verify whether supported older readers preserve this scalar during
profile operations; apply the project's schema rule whenever safe preservation
cannot be established. Plan migration and actual older-build no-mutation refusal
tests before normal saved-data UAT. Do not choose a schema number in this draft.
Internal rendering consumes validated state directly. No runtime/XML file or
manifest addition is expected.

## Ordered implementation

### Step 1: Establish the saved-data contract

- Depends on: D10.1 accepted and implemented; D10.3 plan approved and explicit
  GO to code. D10.2 precedes this ticket in the requested delivery order but is
  not a technical prerequisite for column data.
- Coverage: CG1, CG5, CG6.
- Update defaults, preference list/range validation, copying and necessary schema
  migration/downgrade gates in Constants, ItemDatabase and initialization surfaces.
- Test missing values, legal integers, fractional/nonpositive/nonfinite/wrong
  types, inactive profiles, unrelated-data preservation and actual older readers.

### Step 2: Wire settings and layout

- Depends on: Step 1.
- Coverage: CG1-CG5.
- Replace fixed-count layout math and width table in RefreshCurrencyPanel.
  Preserve existing measured, variable-width columns: initialize a width array
  for the effective column count, measure visible cells, and size each column
  to its widest cell. Use only occupied columns in the final dimensions. Do not
  introduce uniform or fixed widths; neither provides a demonstrated benefit
  for this work (discussion with Tim, 2026-11-08).
  Wire the existing Manage HUD currency-section slider with available-resource
  maximum and immediate preview; preserve range/choice across filtering and
  handle discovery shrinkage without overwriting saved choices. Finalize the
  editor representation of a retained above-current-range value during detailed
  planning. Extend the agreed currency Reset Section to restore 3 columns and
  disclose it in reset text. Preserve anchor and current cell ordering.
- Add focused grid tests for 0/1/7 cells across all limits, hidden/reordered cells,
  combined locations, widths, row counts, unused controls and profile refresh.

### Step 3: Verify and document

- Depends on: Step 2.
- Coverage: all criteria.
- Update the [manual](../../Publishing/Source%20Documents/UserManual.bbcode) after
  implementation; record actual focused tests and obtain approved in-game checks.
- No release/version/commit work is authorized.

## Code blueprint for Steps 1-2

#### Step 1: Saved scalar and recovery coverage

- Add `currencyGridColumns = 3` to `Core\Constants.lua.defaultsAccount` and
  `Tracking\ItemDatabase.lua.preferenceDefaults`; append the key to existing
  `preferenceFields`. Modify `PrepareProfilePreferences(profile, source)` to
  assert a finite positive integer without a discovery-based upper limit.
  Missing fields use the documented default through existing profile preparation.
- Existing `CopyItemListProfile(source, destination)` copies this scalar via
  `preferenceFields`; `SetUseCharacterItemList` and `RefreshProfileSettings`
  apply the selected profile through existing paths. Do not add separate
  character ownership or store it in `currencyPreferences`.
- Extend `Tracking\HUDSettingsSession.lua` snapshot inventory and recovery
  validation to include the scalar; extend
  `ResetHUDSettingsSection("currency")` to restore 3 with all currency-section
  defaults. Preserve original valid values above the current discovery maximum.
- Extend `PrepareSavedVariables` migration gates and
  `Core\Init.lua.SettingsVersion` if required by the previous release's reader.
  Assess actual `CopyItemListProfile` behavior in that reader: a field omitted
  from its copy list is not proven safe merely because normal load preserves it.
- Add scalar/migration/recovery/copy tests to
  `Project\Tests\SavedVariablesTests.lua` and `HUDSettingsSessionTests.lua`.
  Test nil, 1, 3, a valid above-current-maximum integer, 0, fractions, infinity,
  NaN and wrong types; bad inactive profiles stop before any migration publishes.

#### Step 2: Column accessors, row-major geometry and editor callback

Create these methods in existing `Tracking\CurrencyPanel.lua`:

- `GetCurrencyGridColumnMaximum()` returns `max(3, availableCellCount)`.
  Count groups using existing `GetResourceEntries` and
  `GetResourceSettingsRows` grouping before visibility/zero/location filtering;
  character/bank entries of one currency use normal combined-cell grouping.
  Verify capacity groups match the actual rendered-cell model. Do not base the
  maximum on `GetVisibleGridEntries`, which would change it with filtering.
- `GetCurrencyGridColumns()` returns the effective integer
  `min(profile.currencyGridColumns, GetCurrencyGridColumnMaximum())`;
  rely on load validation and do not overwrite the retained saved value.
- `SetCurrencyGridColumns(columns)` asserts an integer within the current
  selectable range and writes `GetSettingsProfile().currencyGridColumns`.
  Refresh is the UI caller's responsibility; this setter adds no reload, scene
  transition, or automatic anchor fitting.

Modify existing `RefreshCurrencyPanel()` to call `GetCurrencyGridColumns` once
per refresh, initialize a zero width entry for each effective column, and use
that count in both measuring and anchoring passes. The measuring pass uses
`GetOrCreateCell` and existing `GetEntryText`; column index is
`(index - 1) % effectiveColumns + 1`. The anchor pass uses the same index/count,
row `floor((index - 1) / effectiveColumns)` and accumulated prior widths/gaps.
Use only `min(effectiveColumns, visibleCellCount)` occupied columns for panel
width and `ceil(visibleCellCount / effectiveColumns)` rows for height. Retain
current padding, fonts, ordering, pooled-cell cleanup and zero-entry hiding.
Do not clear or replace the top-level panel anchor when choosing columns.

In `Tracking\HUDSettingsPanel.lua.BuildCurrencySection`, activate the existing
columns placeholder. Slider callback -> `SetCurrencyGridColumns` ->
`RefreshHUDSettingsPresentation` -> `RefreshHUDSettingsPanel`.
The panel refresh sets slider range from `GetCurrencyGridColumnMaximum` and
display value from the effective getter, without invoking its change callback.
If saved count exceeds current maximum, display the effective capped value
with a tooltip explaining the retained saved choice; this presentation proposal
needs confirmation during the layout trial. Refresh must not clamp-write.
Reset callback follows D10.1's reset/presentation chain; Done clears recovery,
Cancel restores original scalar and positions. No standalone LAM slider.

Existing amount/location/ordering/profile refreshes already call
`RefreshCurrencyPanel`; each automatically uses the new count. Discovery changes
also refresh the editor's range if open. Trace
`Core\Events.lua.OnCurrencyCapsChanged`/`RefreshProgressBarResourceDiscovery`
and profile refresh to both HUD reflow and editor-value refresh without recursion.

Add `Project\Tests\CurrencyGridColumnsTests.lua` using actual
`RefreshCurrencyPanel` with measured-label/control stubs; register it in
`Project\Tests\Run-RuleTests.py` via a new `GetCurrencyGridColumnsTests()` suite
in an isolated Lua 5.1 runtime, loading actual session/currency dependencies.
For 0/1/7 cells and every supported count, assert exact
anchors, row counts, accumulated widths/gaps, unchanged top-left anchor,
hidden unused controls and combined-cell order. Exercise scalar setters,
discovery shrinkage without writes, filtering-independent range,
slider refresh without callbacks, and reset/Cancel/Done through real session
methods. Run `python Project\Tests\Run-RuleTests.py --test-filter
"CurrencyGridColumns|HUDSession|HUDRecovery"` plus relevant saved-variable
selectors once named. These are planned tests, not completed geometry evidence.

## Verification and acceptance mapping

| Criteria | Step | Test / command | Required evidence | Actual result |
|---|---|---|---|---|
| CG1-CG4 | 2 | Focused grid cases via `python Project\Tests\Run-RuleTests.py --test-filter "<final test names>"`; in-game layouts including positioning. | Exact dimensions/anchors/order plus readable rendering. | PENDING |
| CG5-CG6 | 1-3 | Focused profile/migration cases; actual older-build refusal; approved reload/copy/reset UAT. | Unrelated-data preservation and stated defaults/reset. | PENDING |

Final test selectors await test naming. Back up shared saved variables before
approved in-game tests; if schema changes, use an actual older-schema backup under
release-process migration safeguards. Offline geometry does not prove readability.

## Open questions and risks

- Spec range and Reset Section policy agreed: reset columns to 3 and all currency
  section settings/position to defaults; disclose this in reset text. Leave
  tracker and standalone bars unchanged. Position reset supersedes the earlier
  position-preserving policy (Tim, 2026-11-08).
- Older-reader preservation/schema decision: PENDING; blocks coding.
- Wide layouts can extend off-screen: disclosed non-goal, not automatic movement.

## Independent plan review

Reviewer and reviewed spec/plan/source identity: PENDING
Findings, Tim's decisions, resolutions and re-review: PENDING

## Approvals

- Explicit spec approval and revision: PENDING
- Explicit plan approval and revision: PENDING
- Explicit GO to code: PENDING

## Implementation record and deviations

None - planning only.

## Independent code review and verification

Reviewer, diff identity, findings, corrections and re-review: PENDING
Actual test results, retained evidence and unavailable checks: PENDING

## Acceptance and handoff

Approved in-game scope, Tim-reported results and explicit acceptance: PENDING
Current spec/user docs/TODO/completed index/archive updates: PENDING
Commit/merge authorization: PENDING
Release follows its separate process.
