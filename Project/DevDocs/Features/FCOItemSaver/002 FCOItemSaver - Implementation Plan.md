# FCO Integration: implementation plan

Status: DEFERRED PROVISIONAL - not approved; coding not authorized
TODO item: None; follows Scanning Refactor
Spec: [feature spec](<001 FCOItemSaver - Specification.md>)
Owner: Copilot
Updated: 2026-11-24

Follow the [feature development process](../../../Processes/FeatureDevelopment.md).

## Delivered backend baseline (26 November)

Scanning Refactor delivered the shared positive/negative marker-condition
framework and schema-15 storage, and Tim accepted its implementation. The
editor remains deferred. Earlier provisional references below to an
undecided backend model, single-marker built-ins, and new persistence as
necessarily unimplemented are historical assumptions; assess any editor
changes against the delivered contract before planning them. Final-acceptance
testing of migration from an actual older-schema DEV backup remains pending.

## Feature split

The backend tasks and their historical implementation/approval evidence have
moved to the [Scanning Refactor plan](<../../Archive/ScanningRefactor/002 ScanningRefactor - Implementation Plan.md>).
That plan owns prepared scans, slot indexes, incremental updates, sliced
top-ups, marker polling, single-marker built-ins and their production
migration. It replaces the backend stages in the old combined plan.

This plan is deliberately provisional: it does not prescribe an editor or
data model before Tim agrees their behavior. Existing spike approvals apply
to the spike work recorded in Scanning Refactor and the
[spike record](<../../Archive/FCOItemSaver/Spike/002 FCOItemSaver - Results and Decisions.md>), not this
deferred feature.

## Open questions

| ID | Question | What resolves it |
|---|---|---|
| Q1 | What marker conditions/operators and built-in override behavior are required? | **Behavior decision:** resolve spec Q1-Q4 before specifying representation or UI tasks in detail. |
| Q2 | How are the agreed conditions stored and migrated? | **Logic/data-design decision:** assess the delivered Scanning Refactor schema and supported older readers. The old proposed `markers` list was never approved. |
| Q3 | Is bag coverage changing? | **Behavior decision:** resolve spec Q5; do not expand beyond current supported marker bags implicitly. |

## Current implementation and prior art

- `Tracking\EditPanelGroupsTab.lua` and `.xml` already edit ordinary
  Include/Exclude name patterns and built-in overrides. This is the UI to
  extend after design approval, not a reason to create a parallel editor.
- `Tracking\ItemDatabase.lua` owns `GetRuntimeRules`, pattern compilation,
  saved-rule validation, profile migration and built-in normalization.
- Scanning Refactor will supply the production FCO boundary and prepared
  scan/index contracts. Its proposed paths are `Core\FCOItemSaver.lua` and
  `Tracking\PreparedScanning.lua`; verify delivered names before coding.
- `Tracking\AutoCategoryIntegration.lua` already calls IC's bag/slot rule
  predicate. New conditions must reuse the same matcher in tracker and AC.
- Diagnostic logging is a separate feature; do not reimplement it here.

## Technical options and decisions

Representation, operator support and UI wiring remain PENDING until product
decisions are made. Do not assume a `markers` array, reserved pattern tokens,
new wildcard syntax, AND/OR operators or a separate picker implementation.

## SavedVariables changes and migration

Assessment: new persisted conditions will need schema evolution, but the
shape/version is PENDING. Select them against the delivered Scanning Refactor
baseline rather than reusing spike schema 13 or the old provisional version
recommendation.

Before coding, specify validation of all profiles/backups, built-in override
and reset semantics, profile copy behavior, absent-FCO preservation and
actual older-reader downgrade refusal. Preserve existing built-in keys and
AC references.

## Data, compatibility, and failure contracts

- Reuse Scanning Refactor's validated FCO boundary.
- Compile the approved condition model once into the existing runtime-rule
  path; do not duplicate tracker/AC matching semantics.
- Treat saved conditions as external input, validate before use, preserve
  unrelated data, and fail fast on internal contract violations.
- Keep no-condition/name-only rules unchanged.
- Inherit the production FCO lifecycle actions and whole-group eligibility.
  Future marker exclusions cannot become a name-only fallback when FCO is
  suspended/unavailable; test this with the agreed condition representation.
  Extend confirmed Turn off cleanup to all newly representable dependent
  custom/mixed groups across profiles/backups, without deleting ordinary
  groups. Cancel/Suspend preserve groups; Enable cannot recover deleted edits.

## Provisional implementation tasks

### Task 1: agree and review the marker-condition design

- Depends on: Scanning Refactor's delivered contract and spec open questions.
- Spec coverage: AC1-AC7.
- Produce approved matching examples, editor flow and persistence/reset
  contracts, then revise this plan with exact methods, data shape and wiring.
- Independent spec/plan reviews and explicit approvals remain required.

### Task 2: persist and evaluate the approved conditions

- Depends on: Task 1 and separate GO to code.
- Spec coverage: AC2-AC7.
- Expected files: `Tracking\ItemDatabase.lua`, `Core\Init.lua`, production
  FCO/prepared scanning modules and existing rule/profile tests.
- Exact changed methods and new fields: PENDING Task 1. Reuse runtime-rule
  compilation, index invalidation and AC predicate integration.
- Verify truth-table cases, ordinary-rule equivalence, migration and
  downgrade refusal before normal-data in-game use.

### Task 3: add the approved editor controls

- Depends on: Task 2's validated representation/contracts.
- Spec coverage: AC1-AC4.
- Expected files: `Tracking\EditPanelGroupsTab.lua` / `.xml` and existing
  item-editor tests. Exact callbacks, labels and controls: PENDING Task 1.
- Verify add/remove/edit/cancel/reset, custom and built-in groups,
  unavailable markers, profile copy/switch and reload persistence.
- Remove the temporary Debugging **Add test FCO groups** and **Remove test FCO groups** controls and their confirmation-dialog registrations from
  `Core\Settings.lua` when the normal creation UI is delivered (spec AC8).
  Remove its obsolete callback only if no remaining caller needs it; preserve
  all existing test-created definitions, edits and AC inclusion/orders.
  Verify Enable still creates no groups and existing groups survive reload.

### Task 4: independently review and accept the feature

- Depends on: Tasks 2-3.
- Remove the temporary priority-change watcher and its scanner observation
  hooks before review (spec AC9), preserving general logging, position-reporting
  helpers still in use, matching behavior and saved/actual AC priority order.
- Spec coverage: AC1-AC7.
- Test the agreed combinations in tracker and AutoCategory backpack/bank;
  confirm Scanning Refactor performance has not regressed.
- Run the existing offline runner and approved older-backup/in-game UAT;
  record real evidence. Update BBCode user docs only for delivered behavior.

## Verification and acceptance mapping

| Criteria | Task | Evidence | Actual result |
|---|---|---|---|
| AC1 | 2, 3 | Approved editor workflow and saved-condition reload tests | PENDING |
| AC2 | 2, 3 | Built-in override/reset preservation cases | PENDING |
| AC3, AC4 | 2 | Agreed combination/name-exclusion truth tables and UAT | PENDING |
| AC5 | 2, 4 | Shared matcher results and tracker/AC sorting UAT | PENDING |
| AC6 | 2, 4 | All-profile migration, older-reader refusal and real backup UAT | PENDING |
| AC7 | 2, 3, 4 | Suspend/unavailable whole-group inactivity, destructive all-profile cleanup and non-destructive confirmation choices for custom/mixed conditions, including approved marker exclusions | PENDING |
| AC8 | 3, 4 | Both temporary buttons absent; normal creation available; existing groups/edits/AC orders preserved and no automatic groups on Enable | PENDING |
| AC9 | 4 | Temporary watcher/hooks absent; ordinary logging, matching and priority-order preservation regressions pass | PENDING |

## Independent plan review

Reviewer: PENDING
Reviewed plan/spec revision and source identity: PENDING
Findings and Tim's decisions: PENDING

## Approvals

- Explicit spec approval and revision: PENDING
- Explicit plan approval and revision: PENDING
- Explicit GO to code: PENDING

## Implementation record and deviations

24 November: split the original combined documents at Tim's request.
No marker editor, persisted custom marker conditions or combinations have
been implemented by this documentation change.

## Independent code review and verification

- Reviewer/source identity and findings: PENDING
- Actual feature test results: PENDING
- Known limitation: Tasks 2-3 require the product/data/UI decisions above.

## Acceptance and handoff

- Approved in-game test scope/results: PENDING
- Explicit feature acceptance: PENDING
- User docs and archive/index/TODO closeout: PENDING
- Commit/merge authorization and outcome: PENDING
- Release: separate process; not authorized here.
