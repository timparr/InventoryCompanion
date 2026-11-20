# Tracker group-first scan: feature spec

Status: DRAFT - not approved
TODO item: None; user-requested work arising from the
[FCO spike](../../Tasks/Proposals/FCOItemSaverIntegrationSpike.md)
Owner: Copilot
Updated: 2026-11-20
Implementation plan: [TrackerGroupFirstImplementationPlan.md](../Plans/TrackerGroupFirstImplementationPlan.md)

## Overview / proposed changelog text

- **Item tracker group counts.** Prepare the tracker to count the quantities
  that actually match each group, while retaining a compact alphabetized item
  list when the number of visible items is small.

This is draft wording; the change is not implemented.

## Open questions

| ID | Question | Blocking phase and why |
|---|---|---|
| Q5 | How many real-inventory scans should the Debug Key performance check run, and what elapsed-time limit should it assert? | Spec: choose 100, 1,000 or another count and a measurable limit using in-game baseline evidence. |

Use the [feature development process](../../Processes/FeatureDevelopment.md).

## Scope and non-goals

- In scope: group-first tracker scan results, group-specific per-item
  quantities, Miscellaneous and the small-list presentation.
- Out of scope: adding FCO marker conditions, FCO refresh triggers,
  AutoCategory changes, notifications, and unrelated tracker redesign.

## User experience and behavior

- The tracker continues to show an alphabetized list without group headers in
  the small-list case, derived from the group-first results. The small-list
  case is strictly fewer visible items than the threshold, preserving the
  current boundary. The threshold remains configurable, defaulting to 8.
- Before flattening, compare the backpack and bank counts for each item ID
  represented in multiple groups. If its counts agree in all those groups,
  deduplicate its rows without adding counts. If any item's counts differ
  between groups, keep the entire display grouped even below the threshold.
- In the grouped case, group headers and child rows show the matching
  quantities for their group, subject to the existing location settings.
- Single-item groups retain their own headers in grouped display rather than
  being folded into Miscellaneous. This intentionally changes current behavior.
- Individually tracked items are represented in Miscellaneous. An item can
  also match other groups.
- When duplicate rows have different backpack/bank display settings, preserve
  the current first-eligible-source behavior; do not force grouping solely
  because those settings differ.
- When multiple sources contribute the same item to Miscellaneous, use the
  first eligible source's count rather than adding counts. Ungrouped groups
  are considered before individually tracked items; group iteration order is
  not guaranteed.
- Add a real-inventory tracker scan performance test to the existing Debug
  Key diagnostics. Repeat the scan and assert that total elapsed time is
  below an agreed limit; the iteration count and limit are pending Q5.

## Preservation and compatibility

Retain name-pattern OR and exclusion behavior, existing tracked-item and group
configuration, location visibility, show-empty behavior, profiles, expansion
preferences and tracker layout except where explicitly agreed otherwise.
No new saved data is proposed; retain existing settings. No FCO dependency is
introduced.

## Acceptance criteria

| ID | Required observable result | Verification and environment |
|---|---|---|
| AC1 | Each group's header and child rows use that group's matching stack quantities by location; a slot matching multiple patterns in one group contributes once. | Synthetic offline scan and tracker tests; in-game verification where feasible. |
| AC2 | Below the threshold, show alphabetized deduplicated child rows without headers only when repeated item IDs have equal counts across groups; otherwise show the grouped display. Never add duplicate rows' counts. | Offline boundary and overlap tests; in-game display. |
| AC3 | Larger sets, Miscellaneous, singleton groups and individually tracked items behave according to the agreed decisions, including first-source counts, location and zero-count settings. | Offline tracker tests; in-game display. |
| AC4 | Existing matching, profiles, layout and saved configuration remain compatible except for explicitly approved changes. | Existing targeted regression tests and in-game checks. |
| AC5 | Debug Key diagnostics repeatedly scan real inventory and assert elapsed time is below the agreed limit. Investigate repeatable regressions using comparable before-and-after measurements. Synthetic tests must not write live inventory or saved variables. | Offline and in-game synthetic checks plus approved Debug Key performance test. |

## Options and product decisions

| ID | Options and trade-offs | Recommendation | Agreed decision and evidence |
|---|---|---|---|
| D1 | Group-first scan vs extending the current item-first snapshot. | Group-first, as requested, with per-item counts in each group. | User requested group-first planning; detailed contract PENDING. |
| D2 | Keep the current threshold boundary vs make the threshold inclusive. | Preserve the current strict boundary and configurable setting. | Tim: "yes configurable" and "yes make it strictly < then". |
| D3 | Fold singleton groups vs retain headers. | Retain their own headers. | Tim: "yes - this is a change in behaviour I know, but it always looks odd to see a writ in 'misc'". |
| D4 | Flatten overlapping groups vs preserve headers when their counts differ. | Deduplicate equal counts without adding; otherwise keep the entire display grouped. | Tim: "if the item counts are the same in all groups where that itemid is represented then just dedupe (don't add) otherwise, don't flatten at all". |
| D5 | Preserve existing location-setting precedence vs change the display of overlapping sources. | Preserve first-eligible-source behavior. | Tim confirmed preserving the existing behavior. |
| D6 | Choose a Miscellaneous count when multiple sources contribute the same item. | Use the first eligible source's count without adding. | Tim: "do it the same way - just take the first one encountered". |

## Feasibility notes

The current scan returns shared item records and group indexes; the tracker
currently builds its flat list before applying grouping and singleton folding.
See the [implementation plan](../Plans/TrackerGroupFirstImplementationPlan.md)
for call paths and the proposed data flow.

Equal counts do not prove that the same physical copies matched each group.
The agreed flat-view rule compares counts, not copy identity, so a deduplicated
row is not guaranteed to represent the union of different equal-sized sets.
Current Miscellaneous rows use a shared item total; selecting the first
source's group-specific count can change that quantity when sources differ.

## Independent spec review

Reviewer and reviewed revision/source identity: PENDING

Findings, Tim's decisions and any re-review: PENDING

## Approvals and acceptance

- Product discussion agreement: PENDING
- Explicit spec approval: PENDING
- Feature acceptance and actual evidence: PENDING

Spec approval does not authorize coding.
