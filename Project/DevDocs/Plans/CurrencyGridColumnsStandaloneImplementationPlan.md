# Configurable currency columns and scene behavior: implementation plan

Status: PROVISIONAL - not approved; coding not authorized
TODO item: [D10.3 (formerly F1)](../../Tasks/TODO.md)
Spec: [Configurable currency grid columns](../FeatureSpecs/CurrencyGridColumnsFeatureSpec.md)
Owner: Copilot (draft author)
Updated: 2026-11-15

## Open questions

| ID | Question | Blocking phase and why |
|---|---|---|
| Q1 | Can the previous supported reader safely preserve both new data shapes? | Plan review: assess schema and downgrade protection. |
| Q2 | Which ZOS/LAM controls provide reliable bounds for each supported scene and relevant UI? | Plan review: trace scene and placement surfaces for Task 3. |
| Q3 | How do existing movement, profile, reset, and logout paths interact with per-scene positions? | Plan review: trace all panel types for Tasks 1, 3, and 4. |

Use the [feature development process](../../Processes/FeatureDevelopment.md).
The spec is authoritative for product behavior. This plan groups technical work
into tasks and is not yet complete for the newer scene requirements. Previous
settings-overlay-only assumptions do not override the spec.

## Current implementation and prior art

- [CurrencyPanel.lua](../../../Tracking/CurrencyPanel.lua) uses a fixed
  `COLUMN_COUNT = 3`. `RefreshCurrencyPanel()` measures variable-width columns,
  anchors cells row-major, sizes the panel, and preserves its top-left anchor.
  `GetCurrencyPanelSettingsControls()` and `ResetCurrencyPanelPreferences()`
  provide the existing settings and reset path.
- [ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) owns the profile
  preference inventory, preparation, selection, and copying.
  `CopyItemListProfile()` is also used to initialize a character profile.
- [Settings.lua](../../../Core/Settings.lua) registers the settings controls
  and LAM callbacks. [Events.lua](../../../Core/Events.lua) includes the
  `InitCutsceneTicker()` scene-transition behavior.
- [ItemTrackerPanel.lua](../../../Tracking/ItemTrackerPanel.lua) contains
  tracker-specific interaction positioning and restoration. Standalone-bar
  behavior is in [ResourceProgressBars.lua](../../../Banking/ResourceProgressBars.lua).
  These are starting points, not a complete scene-lifecycle design.
- The previous settings-overlay work was reviewed provisionally, but the newer
  scene visibility, placement, persistence, transition, and reset requirements
  need fresh source investigation and a complete design. The
  [historical plans](../Archive/HUDLayoutAndVisibility/README.md) are context,
  not current requirements or approval.

## Technical options and decisions

No new technical decisions have been agreed for the expanded scene behavior.
Discuss the design after tracing the current code and record agreed decisions
here. Product decisions belong in the spec.

## SavedVariables changes and migration

Assessment: PENDING investigation of the current data and previous supported
reader. Determine whether migration and a schema-version bump are required
before plan review; do not infer downgrade safety from the current reader.

Proposed changes within the active settings profile:

| Data | Current structure | Proposed structure |
|---|---|---|
| Grid columns | No `currencyGridColumns` preference. | Add a profile-level `currencyGridColumns` scalar; validation and effective reads are described below. |
| Scene positions | No per-character, per-scene position collection identified yet. | Add position data separated by character, scene, and panel; exact keys, representation, and ownership are PENDING source investigation and design. |

This is a provisional field-level sketch, not an approved schema. Document the
actual before-and-after structure and migration, preservation, and downgrade
evidence here when the investigation is complete.

## Data, compatibility, and failure contracts

- The provisional column implementation adds `currencyGridColumns` to the
  existing profile preference inventory and validates it during saved-data
  preparation. Render and settings reads use the effective value without
  overwriting the saved value.
- The scene-position representation, identity and lifecycle are not yet
  designed. Investigate every profile, copy, validation, migration, reset,
  logout, and older-reader path before selecting a representation.
- Inspect the previous supported reader's schema guard, normalization, and
  copy behavior for both new data shapes. If older builds cannot safely
  preserve the data, bump the schema, validate and migrate every profile before
  constructors, and verify that the older build refuses the new schema without
  mutation. The previous draft identified schema 10 as current; verify it and
  the supported previous reader rather than treating that observation as a
  completed compatibility assessment.
- Malformed saved data must be reported at the boundary, with unrelated data
  preserved and no partial migration published. Internal code consumes validated
  state and fails at broken internal contracts.
- If the schema changes, migration UAT requires an actual older-schema backup
  and the project's backup, logout, restore, verification, and recovery
  safeguards. Synthetic tests alone are insufficient.

## Implementation tasks

All tasks depend on an approved spec, an approved plan, and a separate GO to
code. The tasks below are planning drafts, not authorization to implement.

### Task 1: Prepare profile data and compatibility

- Depends on: completed data design and previous-reader assessment.
- Spec coverage: CG1, CG4, CG5, CG7.
- Files/methods and affected callers: `Core\Constants.lua.defaultsAccount`;
  `Core\Init.lua.SettingsVersion` if required;
  `Tracking\ItemDatabase.lua.preferenceFields`, `preferenceDefaults`,
  `PrepareProfilePreferences()`, `CopyItemListProfile()`,
  `SetUseCharacterItemList()`, and `CopyProfile()`;
  `Project\Tests\SavedVariablesTests.lua`.
- Provisional column design: add the scalar to the profile preference inventory;
  validate a finite positive integer without a resource-count upper bound.
  Prepare legacy profiles and include the value in the existing copy path.
- Scene-position representation, all-profile validation, copy behavior,
  migration, profile switching, and downgrade protection still require concrete
  contracts and caller tracing before plan review.
- Verification: exercise valid, missing, malformed, and above-current-maximum
  column values; inactive profiles; copying; preservation; and the actual
  older-reader refusal where a schema change is required. Add corresponding
  scene-position, character-isolation, and migration cases after design.

### Task 2: Reflow the currency grid and wire its settings

- Depends on: Task 1's validated column preference.
- Spec coverage: CG1-CG4.
- Files/methods and affected callers: `Tracking\CurrencyPanel.lua`:
  `RefreshCurrencyPanel()`, `GetCurrencyPanelSettingsControls()`,
  `ResetCurrencyPanelPreferences()`; `Core\Settings.lua` settings registration;
  inventory, currency, discovery, and profile-refresh callers.
- Provisional contracts: derive the available-cell count using the existing
  combined-location grouping before display filtering. Measure and anchor using
  the same effective count, retaining variable column widths and existing
  pooled-cell cleanup. The settings setter validates the selected range,
  updates the active profile, and refreshes the panel.
- For a growing LAM slider maximum, the earlier analysis proposed updating the
  option descriptor and live control's `data.max`, `slider:SetMinMax()`,
  `UpdateValue()` without an explicit value, and `maxText`, in that order.
  Installed LAM source was inspected for these members and software-event
  behavior; runtime compatibility remains to be verified.
- Trace discovery and profile-refresh callers to ensure both the grid and live
  slider range update without callback recursion. Extend the existing reset
  path rather than adding a second reset.
- Verification: production geometry and settings tests for empty and populated
  layouts, variable widths, ordering, grouping, filters, discovery changes,
  effective caps without writes, profile changes, slider refresh, and reset.

### Task 3: Coordinate scene visibility and placement

- Depends on: scene-lifecycle and placement design.
- Spec coverage: CG6, CG7.
- Investigation targets: `Core\Events.lua.InitCutsceneTicker()`,
  `Core\Settings.lua.CreateSettingsPanel()`, scene and interaction paths in
  `Tracking\ItemTrackerPanel.lua`, `Tracking\CurrencyPanel.lua`, and
  `Banking\ResourceProgressBars.lua`, plus the associated XML and ZOS/LAM
  controls. Trace all spec-listed scenes and all panel types.
- Design required: identify actual scene entry, exit, direct-transition, and
  visibility callers; panel roots and content/enable checks; scene and other UI
  bounds; panel processing order; placement algorithm and constrained-space
  fallback; and dynamically created panels. Specify exact methods, state,
  caller wiring, and cleanup before independent plan review.
- Verification: production visibility and geometry tests for scene transitions,
  panel types, disabled/empty panels, unobstructed placement, minimum movement,
  competing obstacles, screen bounds, dynamic bars, and no persistence of
  automatic moves. In-game checks are required for real scene geometry and
  event delivery.

### Task 4: Persist scene positions and integrate resets

- Depends on: Task 1's profile data design and Task 3's scene lifecycle.
- Spec coverage: CG4, CG7.
- Investigation targets: existing position writers, drag-stop handlers,
  profile switching and copying, all panel-position reset actions, and
  logout/reload behavior for the tracker, currency panel, and standalone bars.
- Design required: stable character, scene, and panel identifiers; per-profile
  saved representation; distinguish user moves from automatic placement;
  restore non-scene anchors; direct transitions; reset scope; and persistence
  without relying on a scene-close event before logout. Specify named methods,
  callers, ownership, and ordering after tracing the source.
- Verification: user drag versus automatic movement, re-entry, scene-to-scene
  transitions, non-scene restoration, logout/reload, shared-profile character
  isolation, profile copy/switch, and each position-reset path. Verify actual
  logout behavior in game with appropriate backups.

### Task 5: Complete regression coverage and user documentation

- Depends on: Tasks 1-4 for the corresponding tests and documentation.
- Spec coverage: CG1-CG7.
- Files: existing `Project\Tests\Run-RuleTests.py` and focused Lua suites;
  `Project\Publishing\Source Documents\UserManual.bbcode`.
- Register focused tests using production methods and ESO stubs; do not mutate
  live inventory or normal SavedVariables. Update user documentation to describe
  delivered behavior without treating unperformed checks as passing.
- Verification: run the smallest relevant offline selectors, then separately
  approved in-game checks with required backups. Exact test names and commands
  will be recorded as the design is completed.

## Verification and acceptance mapping

| Spec criterion | Implementation task | Test / evidence | Actual result |
|---|---|---|---|
| CG1 | 1, 2, 5 | Default, layout, and settings preview | PENDING |
| CG2 | 2, 5 | Discovery, filtering, and range tests | PENDING |
| CG3 | 2, 5 | Layout and preservation tests | PENDING |
| CG4 | 1, 2, 4, 5 | Profile, copy, and reset tests | PENDING |
| CG5 | 1, 5 | Saved-data and older-reader safety tests | PENDING |
| CG6 | 3, 5 | Visibility and placement tests; in-game scene checks | PENDING |
| CG7 | 1, 3, 4, 5 | Persistence, isolation, transition, and logout tests | PENDING |

Offline tests cannot establish actual scene geometry, event delivery, or logout
persistence. In-game checks and any required backed-up migration UAT remain
pending separate approval.

## Verification risks

- Revalidate the installed LAM slider refresh contract and runtime event behavior
  during implementation and in-game testing.
- Verify that programmatic placement and restoration do not trigger saved
  position handlers or conflict with scene visibility updates.

## Independent plan review

Earlier provisional settings-overlay reviews identified anchor restoration,
multi-panel placement, LAM slider refresh, schema safety, and reset coverage as
areas requiring explicit contracts. Those reviews assessed an older plan and
do not establish coverage of the newer scene requirements.

Final reviewer and reviewed plan/spec revision and source identity: PENDING.
Findings, decisions, and focused re-review: PENDING.

## Approvals

- Explicit spec approval and revision: PENDING
- Explicit plan approval and revision: PENDING
- Explicit GO to code: PENDING

## Implementation record and deviations

Planning only. No addon code, tests, migration, or in-game behavior has been
changed or verified.

## Independent code review and verification

- Reviewer and reviewed diff/source identity: PENDING
- Findings, agreed corrections, and re-review: PENDING
- Actual test results and retained evidence: PENDING
- Unavailable checks and remaining limitations: PENDING

## Acceptance and handoff

- Approved in-game test scope and required backups: PENDING
- Actual Tim-reported results: PENDING
- Explicit feature acceptance: PENDING
- Current spec, user docs, TODO, completed-work index, and archive links updated: PENDING
- Commit/merge authorization: PENDING
- Release follows the separate release process and is not authorized here.
