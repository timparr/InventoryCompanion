# FCO Integration: feature spec

Status: DEFERRED DRAFT - not approved; editor/product decisions remain open
TODO item: None; follows Scanning Refactor
Owner: Copilot
Updated: 2026-11-24
Implementation plan: [implementation plan](<002 FCOItemSaver - Implementation Plan.md>)

## Overview / proposed changelog text

- **Choose FCO markers in your own groups.** Extend the group editor so
  custom groups and built-in group overrides can use chosen FCO ItemSaver
  marker conditions alongside name patterns.
- **Combine markers.** Support groups such as Gear 1 through Gear N once
  the marker-combination behavior and UI are agreed.

These are deferred draft notes, not implemented or released behavior.
Follow the [feature development process](../../../Processes/FeatureDevelopment.md).

## Feature split and ownership

Tim split the former combined FCO feature on 24 November:

1. [Scanning Refactor](<../ScanningRefactor/001 ScanningRefactor - Specification.md>)
   owns production promotion of prepared matching, slot indexing,
   incremental updates, time-sliced top-ups/polling, and **one hidden built-in
   group per defined FCO marker**. Users can show/rename those groups and
   edit their ordinary Include/Exclude name patterns with existing UI.
2. **FCO Integration** (this document) owns the later marker-condition UI
   for custom groups and overrides, including marker composition.

Built-in group creation has moved to Scanning Refactor so it need not wait
for this editor. Do not implement it a second time here. Ordinary **name**
pattern editing already exists and is not new marker-condition UI.

Historical evidence and original approvals remain in the
[spike results and decisions](<../../Archive/FCOItemSaver/Spike/002 FCOItemSaver - Results and Decisions.md>)
and [step-by-step record](<../../Archive/FCOItemSaver/Spike/001 FCOItemSaver - Step by Step.md>).
The old combined plan is superseded by these two feature packages.

## Open questions

| ID | Question | Blocking phase and why |
|---|---|---|
| Q1 | Should marker conditions support Include only, or Include and Exclude? | Spec: defines matching and editor controls. |
| Q2 | What combinations are offered: any selected marker, all selected markers, ranges, or a subset? | Spec: Gear 1-to-N is Tim's example, not approval of every Boolean operator or range syntax. |
| Q3 | How does an override interact with a built-in's fixed marker: retain it, replace it, or reset it independently? | Spec: affects existing groups, reset semantics and migration. |
| Q4 | What is the marker-row/picker workflow, including disabled/unavailable markers? | Spec: user-facing UI is not designed or approved. |
| Q5 | Should marker conditions extend to the Craft Bag? | Spec: Scanning Refactor retains the spike's backpack/bank/subscriber-bank marker coverage. |

## Scope and non-goals

In scope for later design:

- Adding/removing marker conditions on custom groups.
- Marker-condition overrides on built-ins.
- Marker combinations, including the requested Gear 1-to-N use case.
- FCO labels/icons and unavailable-marker presentation in the editor.
- Validation, persistence, profile copy/reset and downgrade protection for
  those new saved conditions.
- Reusing the scanning backend and existing AutoCategory IC predicate.

Out of scope:

- Rebuilding the scanner, slot index, top-up scheduler or polling mechanism.
- Regenerating the single-marker built-ins owned by Scanning Refactor.
- Changing/writing marks in FCO or introducing a new logging framework.
- Promising automatic FCO/AC startup recovery as part of this UI feature.

## User experience and behavior

The user will be able to choose markers rather than being limited to each
built-in's fixed single marker. The exact controls and combination semantics
are intentionally undecided under Q1-Q4.

Preserve existing name Include/Exclude semantics. A group using no new marker
conditions continues to behave exactly as it did after Scanning Refactor.
Do not silently remove, reinterpret or broaden a built-in's fixed marker
when editing its name patterns or changing its display name.

## Preservation and compatibility

- Use the production backend delivered by Scanning Refactor.
- Preserve existing built-in IDs, user edits, profiles, counts and AC orders.
- New persisted marker conditions require a reviewed schema bump and
  all-profile migration/downgrade tests. No saved representation is selected
  by this draft.
- FCO and AutoCategory remain optional; saved marker choices must survive
  missing/disabled dependencies.

## Acceptance criteria

These are a starting checklist, not an approved complete acceptance contract.
Finalize observable UI and combination cases when Q1-Q5 are resolved.

| ID | Required observable result | Verification and environment |
|---|---|---|
| AC1 | Users can add/remove the agreed marker conditions on a custom group and reload without losing them. | Offline editor/persistence tests and in-game UAT. |
| AC2 | Marker overrides and reset on built-ins follow the agreed Q3 behavior without losing unrelated name/display edits. | Offline and in-game. |
| AC3 | The agreed combination can express Tim's Gear 1-to-N group and matches exactly the intended marked items. | Offline truth-table examples and in-game marked items. |
| AC4 | Name exclusions and marker conditions interact exactly as agreed; ordinary groups remain unchanged. | Offline equivalence cases and in-game counts. |
| AC5 | IC tracker and AC backpack/bank classification use the same new conditions. | Offline matcher tests and in-game sorting. |
| AC6 | Every profile migrates non-destructively; older readers refuse the newer schema unchanged; saved choices survive unavailable FCO. | Offline migration/downgrade tests and actual older-backup UAT. |

## Options and product decisions

| ID | Decision | Evidence / status |
|---|---|---|
| D1 | Separate editor/condition work from proven backend promotion. | Tim, 24 November: "fco integration proper" and "ui to add patterns to custom groups an overrides". |
| D2 | Do not delay Scanning Refactor for marker combinations. | Tim, 24 November: Gear 1-to-N "has to wait". |
| D3 | Marker representation, operators, overrides and UI. | PENDING; do not carry the old combined plan's recommendations forward as approvals. |

## Feasibility notes

The spike proved marker reading and prepared matching, not a production
marker editor or persisted arbitrary combinations. The backend is covered by
Scanning Refactor; this feature starts from that delivered contract.
No new research or aspirational performance targets are assigned to the
backend by this document.

## Independent spec review

Reviewer: PENDING
Reviewed document revision/source identity: PENDING
Findings and Tim's decisions: PENDING

## Approvals and acceptance

- Split/deferred scope direction: Tim, 24 November.
- Explicit spec approval: PENDING
- Feature acceptance: PENDING
- Actual acceptance evidence and limitations: PENDING

Spec approval does not authorize coding.
