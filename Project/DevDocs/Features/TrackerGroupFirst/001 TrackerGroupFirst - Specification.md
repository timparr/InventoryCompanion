# Tracker group-first scan: feature spec

Status: IMPLEMENTED; merged to main 2026-11-21; in-game behavior checks remain unrun
TODO item: None; user-requested work arising from the
[FCO spike](<../FCOItemSaver/003 FCOItemSaver - Spike Report.md>)
Owner: Copilot
Updated: 2026-11-21
Implementation plan: [Tracker group-first implementation plan](<../../Archive/TrackerGroupFirst/002 TrackerGroupFirst - Implementation Plan.md>)

## Overview / changelog entry

- **Item tracker group counts.** Count the quantities that match each group,
  while retaining a compact alphabetized item list when the number of visible
  items is small. Keep the source-specific counts and duplicate-row behavior
  available for same-ID item variants that match different rules. In grouped
  display, singleton groups retain their headers subject to the existing
  group-header visibility rule.

Tim selected the group-count bookkeeping solution after reviewing the
real-inventory A/B measurement. This does not establish a performance limit or
complete the remaining in-game behavior checks; see the
[consolidated test results](<../../Archive/TrackerGroupFirst/008 TrackerGroupFirst - Consolidated Test Results.md>).

Use the [feature development process](../../../Processes/FeatureDevelopment.md).

## Scope and non-goals

- In scope: group-first tracker scan results, group-specific per-item
  quantities, Miscellaneous and the small-list presentation.
- Out of scope: adding FCO marker conditions, FCO refresh triggers,
  AutoCategory changes, notifications, and unrelated tracker redesign.

## User experience and behavior

- A **tracker-visible rule** is an active rule whose `display.show` is true.
  A location-hidden row has no count at its selected backpack/bank locations;
  that does not make its rule tracker-invisible or remove it from raw-count
  comparison. Rules hidden by `display.isHidden` are excluded by
  `GetActiveTrackedRules()` before the scan, except Miscellaneous.
- The tracker continues to show an alphabetized list without group headers in
  the small-list case, derived from the group-first results. The small-list
  case is strictly fewer distinct visible item IDs than the threshold,
  counted from the deduplicated list; non-displayed entries do not count.
  This preserves the current boundary. The threshold remains configurable,
  defaulting to 8.
- Before flattening, compare each repeated item ID's raw backpack and bank-side
  counts across every tracker-visible rule source, including ungrouped sources
  that feed Miscellaneous, regardless of location visibility. The backpack
  count is `bagCount`; the bank-side count is `bankCount - bagCount`, matching
  the tracker's existing display semantics.
  `bankCount` includes every scanned non-backpack bag, including the subscriber
  bank and virtual craft bag. Compare the two location counts separately, not
  their combined total. Compare the counts present in the current scan
  snapshot; do not force bank availability or change bag-scanning behavior.
  If bank contents are unavailable while closed, the comparison reflects that
  existing scan result. Record the bank state in performance measurements.
  Consider each tracker-visible rule that matches the item, whether or not its
  `display.group` setting is
  true; matching members are compared even if their rows are hidden by
  location or zero-count filtering. Ignore rules with `display.show` false.
  Hidden rules are excluded by the current `GetActiveTrackedRules()` call
  before the tracker scan (except Miscellaneous); this feature does not change
  that boundary. An individually tracked item is also a comparison source
  when it would contribute its own Miscellaneous row; it does not count as a
  separate source when an eligible ungrouped rule already represents that
  item. This preserves existing precedence: an eligible ungrouped rule
  represents the item ID instead of the tracked-by-ID fallback, even when
  those sources cover different copies and have different raw counts.
  Miscellaneous uses the first eligible source when multiple sources are
  folded there.
  If all compared location counts agree, deduplicate rows without adding
  counts. If counts differ between multiple ungrouped rules, keep them
  ungrouped and replace the ordinary Miscellaneous row with one row per
  contributing ungrouped rule, using that rule's own counts, item link, and
  location settings. Do not add an extra undifferentiated row for the same
  item ID. Sort source-labeled rows by rendered label; ties use row identity.
  Label each row `[groupName]:Item`, with no space after the colon, using the
  rule's display name and that rule's representative item-link name. For
  example, a rule displayed as "Writs and Affordable" matching "Sealed Writ"
  produces `[Writs and Affordable]:Sealed Writ`; use the display name even
  when the source rule is ungrouped. Do not
  change saved `display.group` settings or add the duplicate row counts to the
  Miscellaneous header total; that total continues to use the first eligible
  source per distinct item ID. For a rule source, that aggregate uses its
  group-specific counts; use the shared overall item counts only when the
  individually tracked item is the eligible source. Any differing counts
  among sources included in the comparison set prevent flattening, even below
  the threshold. For long
  labels, use the existing wrapping behavior when enabled. When wrapping is
  disabled, truncate only the group-name prefix so the item name remains
  visible, and expose the full source name when hovering anywhere on that
  duplicate row's label. If the item name alone exceeds the available width,
  preserve the existing item-name ellipsis rather than truncating it further
  to make room for the source prefix.
- In the grouped case, group headers and child rows show the matching
  quantities and representative item link for their group, subject to the
  existing location settings.
- Single-item groups retain their own headers in grouped display rather than
  being folded into Miscellaneous. This intentionally changes current behavior.
- Individually tracked items are represented in Miscellaneous. An item can
  also match other groups.
- When duplicate rows have different backpack/bank display settings, preserve
  the current first-eligible-source behavior; do not force grouping solely
  because those settings differ. Keep that encounter-order precedence rather
  than introducing a new sorted tie-break.
- For Miscellaneous, a source is eligible when its tracker `display.show`
  setting is true and it contributes the item ID; individually tracked items
  are considered only when no eligible ungrouped rule already represents that
  item. Location visibility and nonzero stock do not affect source eligibility.
  Ungrouped rules take precedence over tracked items; within the ungrouped
  rules, preserve the existing first-encountered source without imposing a
  new deterministic tie-break. Because that iteration uses `pairs()`, the
  winning source among equal-count rules with different location flags is not
  guaranteed; tests must assert only order-independent behavior in this case.
  If multiple ungrouped
  sources have different raw counts, show one source-labeled Miscellaneous row
  per contributing ungrouped group, using its own counts and location
  settings. Do not add these duplicate rows to the Miscellaneous header total.
  If a source-specific row has no visible count under its location settings,
  omit it when empty items are hidden; still suppress the ordinary row for
  that item ID. When empty items are shown, keep the source row with its
  selected zero counts.
  If their counts agree, keep one row using the first eligible source's count
  and location settings. An individually tracked item does not add another
  row when an ungrouped source already represents it.
- `showEmptyTrackedItems` continues to determine whether zero-count rows are
  visible and therefore included in the deduplicated item count for the
  threshold.
- A singleton group has exactly one distinct matching item ID, regardless
  of location visibility or zero-count filtering. In grouped display, its
  header is retained subject to the existing group-header visibility rule:
  show it when the group has visible stock or `showEmptyTrackedItems` is
  enabled. Its member row continues to obey the existing location and
  zero-count rules. Thus a
  hidden-location or zero-count singleton has no header when empty items are
  hidden, and has its header when empty items are shown.
- Add a real-inventory tracker-build performance test to the existing Debug
  Key diagnostics. It measures repeated snapshot construction and tracker
  display-list building, not UI rendering. Record inventory size, bank state,
  differing-count item IDs, and per-run timing samples. Use the first in-game
  run to measure the candidate and discuss the result with Tim. Determine the
  acceptance iteration count and limit from those measurements; do not treat
  performance as passing until the values are agreed and the assertion is
  rerun. If the measured behavior appears slow, decide with Tim after the test
  whether to keep or remove the additional source-comparison/duplicate-row
  behavior; do not remove it automatically. Group-specific counts remain
  required for the core group-first behavior.
- During in-game checks, compare behavior with the bank closed and open, record
  whether existing refresh events update the panel when bank availability
  changes, and confirm the Miscellaneous header remains non-additive when its
  duplicate detail rows are visible. Each rebuild uses only its current scan
  snapshot, so a change in bank-side raw counts can change whether the
  displayed list is flat or grouped. Do not add a new bank refresh event as
  part of this feature without discussing the observed behavior first. Until
  an existing refresh causes a rebuild, the displayed panel may continue to
  show its prior snapshot; that is accepted behavior for this feature.

## Preservation and compatibility

Retain name-pattern OR and exclusion behavior, existing tracked-item and group
configuration, location visibility, show-empty behavior, profiles, expansion
preferences and tracker layout except where explicitly agreed otherwise.
Retain the existing row budget, overflow indication, scrolling and zero-count
visibility rules; singleton headers can increase the number of rows. Do not
drop headers or add a new row-dropping policy to meet the row budget; existing
group expansion and scrolling behavior applies.
No new saved data is proposed; retain existing settings. No FCO dependency is
introduced.

## Acceptance criteria

| ID | Required observable result | Verification and environment |
|---|---|---|
| AC1 | Each group's header and child rows use that group's matching stack quantities by location; a slot matching multiple patterns in one group contributes once. | Offline scan/tracker tests; in game, confirm one representative multi-location group's header and child counts. |
| AC2 | Below the threshold of distinct visible item IDs, show alphabetized deduplicated rows only when repeated IDs have equal raw backpack and bank-side counts separately across tracker-visible rules and any individually tracked source that contributes its own Miscellaneous row. An eligible ungrouped rule shadows the tracked-by-ID fallback. Differing counts between multiple ungrouped rules prevent flattening and produce one source-labeled Miscellaneous row per differing ungrouped rule, without changing saved settings or adding duplicate counts to the header. | Offline threshold, hidden-rule, location-hidden, equal-total/different-location, ungrouped-source, tracked-source, and overlap tests; in game, inspect one displayed list below the threshold. Equal-count sources with different location flags use the existing first-encountered source; tests assert only order-independent results. |
| AC3 | Larger sets, Miscellaneous, singleton groups and tracked items follow the specified source precedence, including the non-additive Miscellaneous header, location and zero-count filtering, row budget, overflow, and scrolling. | Offline tracker tests; in game, confirm a singleton header and observe that the Miscellaneous header does not sum duplicate details. If a real same-ID/different-name variant is available, check it; otherwise record the synthetic coverage as the available evidence. |
| AC4 | Existing matching, profile, expansion, and layout behavior remains unchanged except for the documented singleton-header and source-specific row changes. Each rebuild compares the current scan snapshot; bank-open/closed transitions do not add a new refresh trigger in this feature. Until an existing event causes a rebuild, the prior display may remain visible. | Focused and full offline regressions; in game, inspect the tracker with the bank open and closed, record whether existing events cause a rebuild, and confirm that the next rebuild reflects the current scan. |
| AC5 | Debug Key diagnostics build the real-inventory snapshot and display list without rendering, recording per-run timing, bag reads, occupied entries, unique IDs, differing-count IDs, and bank state. | First in-game run is a measurement probe only. Agree iteration count and limit with Tim, then rerun the assertion; do not claim performance acceptance before that rerun. Synthetic tests do not write live inventory or saved variables. |

## Options and product decisions

| ID | Options and trade-offs | Recommendation | Agreed decision and evidence |
|---|---|---|---|
| D1 | Group-first scan vs extending the current item-first snapshot. | Group-first, as requested, with per-item counts in each group. | Tim requested group-first results; the scan representation remains an implementation detail of the plan. |
| D2 | Keep the current threshold boundary vs make the threshold inclusive. | Preserve the current strict boundary and configurable setting. | Tim: "yes configurable" and "yes make it strictly < then". |
| D3 | Fold singleton groups vs retain headers. | Retain their own headers. | Tim: "yes - this is a change in behaviour I know, but it always looks odd to see a writ in 'misc'". |
| D4 | Flatten overlapping group sources vs preserve per-source counts when their quantities differ. | Compare raw counts in both locations; equal counts deduplicate without addition, while differing counts prevent flattening. | Tim: "if the item counts are the same in all groups where that itemid is represented then just dedupe (don't add) otherwise, don't flatten at all"; "if the counts are different in either location, they are different items". |
| D5 | Preserve existing location-setting precedence vs use each source's display settings for duplicate rows. | Different display flags alone do not cause duplicate rows. When counts differ and source-specific rows are shown, each row uses that source's location settings; a deduplicated row keeps the first eligible source's settings. | Tim confirmed preserving the existing behavior. |
| D6 | Choose a Miscellaneous aggregate count when multiple sources contribute the same item. | Keep the first eligible source's count for each distinct item ID in the Miscellaneous header; source-labeled duplicate detail rows are not added to that total. | Tim: "do it the same way - just take the first one encountered". |
| D7 | Count visible deduplicated items vs non-displayed entries for the flat-view threshold. | Count only the deduplicated list. | Tim: "only the dedupe list would be counted to determine if flattening". |
| D8 | When different counts for the same item come from ungrouped rules, retain only the first source in Miscellaneous; show source-specific duplicate rows in Miscellaneous; or temporarily promote the contributing rules to groups. | Show one Miscellaneous row per contributing ungrouped rule, labeled `[groupName]:Item` with no space after the colon (for example, `[Writs and Affordable]:Sealed Writ`). Use that rule's counts and location settings. Do not change saved settings or add duplicate counts to the Miscellaneous header. | Tim: "lets go with duplicated rows, and change the display name to [groupName]:Item." |
| D9 | Keep long source labels readable without hiding item names. | Wrap the full label when wrapping is enabled; otherwise truncate only the source-name prefix and expose its full name on hover. | Tim: "I think so." |
| D10 | Whether to retain group-count bookkeeping after the A/B test shows a scan cost, and whether that measurement settles acceptance of the comparison/duplicate-row behavior. | Keep per-group bookkeeping in production because it is required for group-specific counts. Keep the no-bookkeeping path diagnostic-only. Treat display behavior and performance acceptance as separate in-game gates; the timing does not itself establish acceptance. | Tim: "I think we implement the bookkeeping solution." (2026-11-21) |

| D11 | Whether to add separate behavior for the rare case where an ungrouped rule matches some copies of an item ID that is also individually tracked. | Do not add a new tracked-item row/comparison path for this hypothetical case; preserve existing ungrouped-rule precedence over the tracked-by-ID fallback. | Tim: "this is NEVER GOING TO HAPPEN. i don['t care - just get it coded". |

## Feasibility notes

The current matcher applies name-pattern includes and excludes to each
occupied item's link name, so same-ID variants with different link names can
match different rules today. It does not evaluate per-copy FCO markers, and
FCO integration remains out of scope. The current scan returns
shared item records and group indexes; the tracker currently builds its flat
list before applying grouping and singleton folding.
See the [implementation plan](<../../Archive/TrackerGroupFirst/002 TrackerGroupFirst - Implementation Plan.md>)
for call paths and the proposed data flow.

Equal counts do not prove that the same physical copies matched each group.
The agreed flat-view rule compares counts, not copy identity, so a deduplicated
row is not guaranteed to represent the union of different equal-sized sets.
For raw count comparison, use backpack `bagCount` and bank-side
`bankCount - bagCount`; the latter includes all scanned non-backpack bags as it
does in the existing tracker. For duplicate rows, preserve each ungrouped
source's per-group counts; the Miscellaneous header remains non-additive and
uses the first eligible source per distinct ID. The existing unordered group
iteration can select the first source for that aggregate; source-labeled rows
are sorted by display label so their detail order is stable.

## Independent spec review

Reviewer: independent `rubber-duck` agent `tracker-spec-review`.
Reviewed working-tree spec blob `e5de724`, plan blob `4528d34`, on HEAD
`8ccae42`.

- Blocking clarification: compare raw counts in both locations and retain
  the current threshold based on distinct visible item IDs. Tim agreed the
  raw-count rule; the spec now states both explicitly. Focused re-review:
  resolved in the clarified pre-relocation revision; the subsequent focused
  re-review is recorded below.
- The reviewer suggested sorting sources to make first-source choices
  deterministic. This is not adopted: Tim chose to preserve the existing
  first-encountered behavior.
- The in-game performance assertion needs an agreed limit; the larger-scan
  comparison and limit are intentionally deferred to acceptance.
- The reviewer described differing group counts as FCO-only. That is not
  assumed: same-ID items with different names or other future conditions
  can potentially match different groups.

Focused reviews by independent agent `tracker-doc-review-final` identified
comparison-set, hidden-rule, performance-measurement and current-matcher
clarifications. Those were incorporated. After reviewing the in-game A/B
measurement, Tim chose to keep group-count bookkeeping in production. The
no-bookkeeping path remains diagnostic-only. This decision does not establish
performance acceptance or resolve the visual acceptance checks for
source-comparison/duplicate-row behavior. Bank state continues to follow the
current scan snapshot. Tim approved implementation on 2026-11-21.

Independent reviewer `tracker-doc-review` reviewed the working-tree spec
SHA-256 `92748B43CD6F5135634DC3BB09DF28418442E7D753E0DF8A4B16989456B4843A`
and plan SHA-256
`1EA91123F478F9F42B2E38C606E5347D51EB35E91681377D31A133ED5FDDBDBE`
on HEAD `8ccae42`. The review found no blocking issue. Its status-record and
D10 wording findings are corrected in this revision. The source-comparison
scope is clarified to exclude the required per-group counts; the performance
probe records differing-count IDs; bank open/closed behavior and the
non-additive header are now explicit in the in-game checks. Candidate
measurements are recorded in the consolidated test results; display acceptance,
refresh behavior and a numeric performance limit remain pending.

## Approvals and acceptance

- Product discussion agreement: RECORDED in D1-D10 and the behavior above
- Explicit spec approval: Tim: "ok go" (2026-11-21); implementation authorized.
- Closeout and merge: merged to main on 2026-11-21.
- Remaining in-game behavior checks: PENDING and explicitly not claimed as
  passed; see the [consolidated test results](<../../Archive/TrackerGroupFirst/008 TrackerGroupFirst - Consolidated Test Results.md>).

The closeout request records the implementation direction; it does not convert
unrun checks into passes or establish a numeric performance limit.
