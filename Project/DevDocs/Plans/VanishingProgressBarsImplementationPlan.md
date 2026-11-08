# Vanishing progress bars: implementation plan

Status: PROVISIONAL - not approved; coding not authorized
TODO item: [D10.2 Vanishing Progress Bars](../../Tasks/TODO.md)
Spec: [Shared HUD layout and visibility specification](../FeatureSpecs/HUDLayoutAndVisibility.md)
Owner: Copilot (draft author)
Updated: 2026-11-08

Follow the [feature development process](../../Processes/FeatureDevelopment.md).
Implement after [D10.1 HUD Positioning](HUDPositioningImplementationPlan.md)
and before [D10.3 Currency Grid Columns](CurrencyGridColumnsImplementationPlan.md).
D10.2 wires threshold-based visibility into the presentation-only controls
created by D10.1 in Manage HUD; it does not add a second settings surface.

## Current implementation and prior art

- [ProgressBarResources.lua](../../../Banking/ProgressBarResources.lua) owns
  resource discovery, profile preferences, defaults, and setting accessors.
- [ResourceProgressBars.lua](../../../Banking/ResourceProgressBars.lua) owns
  bar creation, rendering, position saves, and cutscene visibility. Its current
  `UpdateProgressBar` hides only for missing values, disabled bars, or cutscenes.
- [Events.lua](../../../Core/Events.lua) registers currency/capacity/inventory
  listeners according to enabled resources and refreshes bars through existing
  debounced handlers. Below-threshold bars must remain monitored.
- [ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) validates every
  profile and copies resource preference tables. [Settings.lua](../../../Core/Settings.lua)
  currently owns the LAM controls that D10.1 moves into Manage HUD.
- The [D10.1 plan](HUDPositioningImplementationPlan.md) owns session staging,
  editor controls, position handling, and Done/Cancel/reset behavior.

## Technical options and decisions

| ID | Alternatives and trade-offs | Recommendation | Agreed choice and evidence |
|---|---|---|---|
| D1 | Store raw percentages or fractions; store every default or only deviations. | Store a 0-1 fraction and only non-default values in each resource's existing `progressBarPreferences` table. | Recommendation based on existing threshold fields; plan approval pending. |
| D2 | Change enabled-state queries to mean visible-now, or keep monitoring semantics distinct from rendering. | Keep event predicates based on enabled resources; calculate display visibility in the renderer. | Existing event design; plan approval pending. |
| D3 | Add polling/hysteresis or use the existing event refresh pipeline. | Exact crossing with existing refresh/debounce only; no polling or extra visibility debounce. | Agreed in spec. |

## Data, compatibility, and failure contracts

Use the existing account/character profile switch. Proposed stored deviations
are per-resource `hideBelowThreshold` (fraction, default 0) and `hideWhenEmpty`
(boolean, default true); missing values inherit defaults. Preserve `showBar`,
warning/danger thresholds, colors, positions, unknown unrelated fields, and
other preferences. Include all-profile validation and full-profile-copy coverage.
Malformed explicit values must be reported at the saved-data boundary.

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
- Route edits through D10.1 staging. Done commits; Cancel/reset/automatic exits
  follow its session contract. Positioning reveals actual bars without changing
  showBar or visibility preferences.

### Step 4: Document and verify

- Depends on: Step 3.
- Coverage: all D10.2 criteria.
- Update the user manual and plan with actual decisions, focused test output, and
  approved in-game crossing, cutscene, profile, and positioning results.
- No release/version/commit work is authorized.

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
