# Configurable currency grid columns: implementation plan

Status: PROVISIONAL - not approved; coding not authorized
TODO item: [D10.3 (formerly F1)](../../Tasks/TODO.md)
Spec: [Shared HUD layout and visibility specification](../FeatureSpecs/HUDLayoutAndVisibility.md)
Owner: Copilot (draft author)
Updated: 2026-11-06

Follow the [feature development process](../../Processes/FeatureDevelopment.md).
This plan covers D10.3 only. Criterion references below use the shared spec's
CG1-CG6 (the former column-only AC1-AC6), not its bar-visibility AC criteria.
Agreed trial: full Manage HUD editor owns the column control, with LAM navigation
rather than a duplicate slider. Coordinate relocation with the feature-branch and
pre-trial checkpoint gate in the positioning plan. Coordinate the shared panel;
reuse one preference/setter and refresh path across any retained entry surfaces.

## Current implementation and prior art

- [CurrencyPanel.lua](../../../Tracking/CurrencyPanel.lua): fixed column constant,
  width accumulation and row-major anchors in RefreshCurrencyPanel;
  GetCurrencyPanelSettingsControls and ResetCurrencyPanelPreferences own its UI.
- [ItemDatabase.lua](../../../Tracking/ItemDatabase.lua): preferenceFields,
  preferenceDefaults, PrepareProfilePreferences, full copy, RefreshProfileSettings.
- [Constants.lua](../../../Core/Constants.lua): account defaults.
- [SavedVariablesTests.lua](../../Tests/SavedVariablesTests.lua) and
  [Core tests](../../../Core/Tests.lua): existing profile and grid cases.

## Technical options and decisions

| ID | Alternatives and trade-offs | Recommendation | Agreed choice |
|---|---|---|---|
| D1 | Single profile scalar versus a new layout table. | `currencyGridColumns` scalar; no new abstraction. | PENDING |
| D2 | Arbitrary column widths versus count-sized width array. | Initialize widths for the validated selected limit; reuse existing sizing. | PENDING |

## Data, compatibility, and failure contracts

Manage HUD now has Done/Cancel and per-section reset (agreed 2026-11-06).
Column changes render live but participate in the editor session snapshot:
Cancel restores the starting column preference; Done keeps edits. Reset currency
section restores 3 columns and is itself reversible with Cancel. Coordinate
transaction handling with the shared editor; do not persist independently of it.

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

- Depends on: approved spec/plan and explicit GO.
- Coverage: CG1, CG5, CG6.
- Update defaults, preference list/range validation, copying and necessary schema
  migration/downgrade gates in Constants, ItemDatabase and initialization surfaces.
- Test missing values, legal integers, fractional/nonpositive/nonfinite/wrong
  types, inactive profiles, unrelated-data preservation and actual older readers.

### Step 2: Wire settings and layout

- Depends on: Step 1.
- Coverage: CG1-CG5.
- Replace fixed-count layout math and width table in RefreshCurrencyPanel.
  Add LAM slider with available-resource maximum and immediate refresh; preserve
  range/choice across filtering and handle discovery shrinkage without overwriting
  saved choices. Finalize LAM representation of a retained above-current-range
  value during detailed planning. Implement the agreed Reset Panel policy
  and disclose it in reset text. Preserve anchor and current cell ordering.
- Add focused grid tests for 0/1/7 cells across all limits, hidden/reordered cells,
  combined locations, widths, row counts, unused controls and profile refresh.

### Step 3: Verify and document

- Depends on: Step 2.
- Coverage: all criteria.
- Update the [manual](../../Publishing/Source%20Documents/UserManual.bbcode) after
  implementation; record actual focused tests and obtain approved in-game checks.
- No release/version/commit work is authorized.

## Verification and acceptance mapping

| Criteria | Step | Test / command | Required evidence | Actual result |
|---|---|---|---|---|
| CG1-CG4 | 2 | Focused grid cases via `python Project\Tests\Run-RuleTests.py --test-filter "<final test names>"`; in-game layouts including positioning. | Exact dimensions/anchors/order plus readable rendering. | PENDING |
| CG5-CG6 | 1-3 | Focused profile/migration cases; actual older-build refusal; approved reload/copy/reset UAT. | Unrelated-data preservation and stated defaults/reset. | PENDING |

Final test selectors await test naming. Back up shared saved variables before
approved in-game tests; if schema changes, use an actual older-schema backup under
release-process migration safeguards. Offline geometry does not prove readability.

## Open questions and risks

- Spec range and Reset Panel policy agreed: reset columns to 3, disclose in reset
  text, preserve position and standalone bars.
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
