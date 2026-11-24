# FCO ItemSaver diagnostic spike: feature spec

Archived 2026-11-24 from `spike/fco-itemsaver` at `16c31c2`. Approvals below
apply to historical diagnostic work, not the production feature.

Status: APPROVED for temporary diagnostic implementation; in-game acceptance pending
TODO item: None; user-requested feasibility spike, not the MVP feature
Owner: Copilot
Updated: 2026-11-22
Implementation plan: [diagnostic spike plan](<004 FCOItemSaver - Spike Implementation Plan.md>)

The original scope and acceptance criteria below describe the initial spike.
Tim subsequently authorized DEV-only real groups, scan-local preparation,
schema 13 protection and scan-time logging; see
[spike decisions and current verification](<002 FCOItemSaver - Results and Decisions.md>).
Those later changes are not an approval to release.

## Overview / proposed changelog text

- **DEV-only FCO diagnostics.** A temporary diagnostic command would inspect one
  FCO marker in the backpack, compare scan timings and observe slot events while
  the user manually changes a marker. It investigates the proposed integration;
  it does not add FCO conditions to IC groups.

This is draft wording; no released feature is claimed.

## Open questions

| ID | Question | Blocking phase and why |
|---|---|---|
| Q1 | Does FCO produce an observable slot event for a manual marker change in the installed game and addon configuration? | Investigation; requires the spike and in-game evidence. |
| Q2 | What performance limit should the eventual MVP meet? | MVP acceptance; this spike records measurements without choosing a limit. |
| Q3 | Is caching worth its maintenance cost and complexity? | Optimization decision; compare slot/tag and tag-list-driven scans, then assess reliable update cost. Ideal-cache timings alone do not settle it. |

## Scope and non-goals

- In scope: a read-only, DEV-only diagnostic for one marker and backpack slots;
  bounded event observation; a synthetic candidate count aggregation and
  synthetic timing exercise; offline validation of diagnostic behaviour.
- Out of scope: actual IC marker groups, new saved settings, FCO marker changes
  by IC, inventory movement, bank scans, notifications, AutoCategory changes,
  release work and claims of MVP acceptance.

## User experience and behavior

- `/icfcotest scan [markerId]` proposes a backpack scan, using FCO's guild-store
  marker when omitted. Show the marker ID, occupied-slot and matched-slot
  counts, matched quantity and item links/counts, plus separate baseline and
  FCO-query timing over ten iterations on the same captured slots.
  Timings use `GetGameTimeMilliseconds()` and are observations, not pass/fail;
  zero milliseconds means below the clock's resolution, not zero cost.
- `/icfcotest watch [markerId]` captures a marker snapshot and starts observing
  backpack slot-update events. The user manually changes one marker without
  moving the item, then `/icfcotest stop` reports event count and affected
  slots and compares the before/after marker state. Report no net marker change
  as inconclusive, not proof of no events. Repeated start is rejected; stop
  unregisters observation. Reload also ends it. No marker polling is required.
  A moved or replaced item, or an item without a usable unique ID, is reported
  as inconclusive for that slot rather than as a marker change.
- `/icfcotest synthetic` runs an isolated prototype with marked and unmarked
  synthetic slots sharing an item ID, and a bounded synthetic timing workload.
  Label its result as prototype evidence, not proof the existing tracker works.
- The DEV Debug Key (or `/ictest copy`) runs the synthetic prototype and, when
  FCO is ready with the default marker enabled, scans the backpack and starts
  the marker watcher. Pressing it again stops the watcher and reports the
  before/after comparison. Append all diagnostic output to the Debug Key's
  copyable error report. The synthetic prototype still runs if FCO is
  unavailable; the live scan/watch is reported as skipped.
- Invalid or FCO-disabled marker, invalid command, missing or unready FCO, unsupported gamepad mode,
  absent marker-query result and event-observer misuse produce explicit
  diagnostic messages. No API call is made in unsupported gamepad mode.
- Event counts are correlation evidence only: unrelated inventory activity can
  produce events and absence of events in one run does not prove all FCO
  marking paths behave alike.

## Preservation and compatibility

The diagnostic reads live backpack state but does not intentionally write IC or
FCO SavedVariables, set markers, modify inventory or change existing group
matching. The user may manually change markers for observation and should
restore them. It is registered only in DEV and must not require FCO to load IC.
External FCO API failures must be surfaced, not silently reported as unmarked.
FCO's query can change its own transient state; the diagnostic checks that its
settings are already available before calling it. No saved-data schema change
is proposed. The temporary runtime file, manifest entry and its offline test
harness wiring must be removed or deliberately redesigned before any release:
release packaging otherwise includes manifest files even when their commands
are DEV-gated.

## Acceptance criteria

| ID | Required observable result | Verification and environment |
|---|---|---|
| AC1 | Scan reports slot/quantity results and separate baseline/query timings for the selected marker; no match is explicit. | Offline stubbed tests; approved in-game check with FCO. |
| AC2 | Watch/stop reports before/after changes and backpack event evidence, unregistering on stop; invalid lifecycle actions are reported. | Offline event stubs; approved in-game manual marking. |
| AC3 | Synthetic prototype reports marked count separately from all copies sharing an item ID; timing is labelled diagnostic. | Offline tests and in-game diagnostic. |
| AC4 | Missing/unready FCO, invalid inputs, unsupported mode and nil query results are explicit; no live inventory or saved data is mutated by the diagnostic. | Offline tests; inspect runtime paths; approved in-game checks where applicable. |
| AC5 | Existing behaviour and release command surface remain unchanged; no schema migration is introduced. | Offline runner, manifest/load-order review and release-mode stub. |
| AC6 | The DEV Debug Key includes synthetic results, a real scan when FCO is available, and a two-invocation marker watch in its copyable error report. | Offline lifecycle/report tests and an in-game captured Debug Key report. |

## Options and product decisions

| ID | Options and trade-offs | Recommendation | Agreed decision and evidence |
|---|---|---|---|
| D1 | Standalone command vs extending `/ictest`: interactive observation needs a start/stop lifecycle. | Make the DEV Debug Key (or `/ictest copy`) the primary workflow: first invocation scans and starts the watch; the next stops it. Retain `/icfcotest` for focused manual diagnostics. | Tim directed that these diagnostics run from the Debug Key and be returned in its error report (2026-11-21). |
| D2 | Synthetic aggregation before feature implementation cannot test IC's real tracker. | Prototype only, explicitly labelled; real group regression waits for implementation. | PENDING |

## Feasibility notes

FCO exposes `FCOIS.IsMarked`; its API documents gamepad limitations. IC scans
slots but aggregates tracker records by item ID. The existing synthetic
[rule tests](../../../../../Core/RuleTests.lua) and read-only performance tests in
[Tests.lua](../../../../../Core/Tests.lua) are prior art. See the
[spike report](<002 FCOItemSaver - Results and Decisions.md>).

## Best-supported matching algorithm so far

The `safe` algorithm below is a top-level candidate for discussion, not a
production implementation. A separate direct-read comparison is described under
[T09.4](<002 FCOItemSaver - Results and Decisions.md#t094-safe-versus-direct-fco-reads>).
Measurements and open decisions remain in the
[results and decisions record](<002 FCOItemSaver - Results and Decisions.md>).

A `*` beside a bold line number marks a likely matching hot spot, not an
individually timed line.

### OneScan()

<pre>
001  -- Run one complete scan and update the tracker.
002  BeforeScan()
003  Scan()
004  BuildList()
005  Display()
</pre>

### BeforeScan()

<pre>
006  -- Read the current profile and settings.
007  Create <strong>ActiveGroups</strong>       -- Groups to check in this scan, keyed by group ID.
008  Create <strong>TrackedItems</strong>       -- Individually tracked items, keyed by item ID.
009  Create <strong>StorageLocations</strong>   -- Ordered list of bag IDs to scan.
010
011  -- Prepare name matching.
012  Create <strong>PreparedNameRules</strong> -- Each active group's prepared include and exclude patterns.
013  For each group in <strong>ActiveGroups</strong>:
014      Reuse its compiled name patterns if the group's rules have not changed.
015      Otherwise, compile its current include and exclude patterns.
016      Add the prepared patterns to <strong>PreparedNameRules</strong>, keyed by group ID.
017  Next group
018
019  -- Prepare tag matching.
020  Create <strong>OverallTagList</strong>     -- Distinct FCO tags needed by <strong>ActiveGroups</strong>.
021  Check FCO and the tags in <strong>OverallTagList</strong> are available.
022
023  -- Start fresh results for this scan.
024  Create <strong>OverallItemResults</strong> -- Empty overall item counts.
025  Create <strong>GroupResults</strong>       -- Empty counts for each group.
026  Create <strong>SlotTagResults</strong>     -- Empty tag answers, remembered only during this scan.
</pre>

### Scan()

<pre>
027  -- Read the occupied slots in the selected storage locations.
028  For each location in <strong>StorageLocations</strong>:
029      For each occupied slot:
030          Create <strong>SlotItem</strong>       -- Item ID, link, name, quantity, bag ID and slot.
031          Create <strong>MatchingGroups</strong> -- Empty list of groups matching this slot.
032          Read the slot's item information into <strong>SlotItem</strong> once.
033
034          -- Check each group's inclusion and exclusion rules.
035          For each group in <strong>ActiveGroups</strong>:
<strong>036 *</strong>            Check <strong>SlotItem</strong>'s name against the group's includes in <strong>PreparedNameRules</strong>.
037              If the name did not include it, and the group has a tag condition:
038                  Check that the group allows tag matching in this location.
039                  If allowed, look for this bag and slot in <strong>SlotTagResults</strong>.
040                  If no tag answers have been stored:
<strong>041 *</strong>                    Fetch the tags in <strong>OverallTagList</strong> together in one FCO query.
042                      Validate the returned answers and store them in <strong>SlotTagResults</strong>.
043                  Check the group's tag condition using those stored answers.
<strong>044 *</strong>            If included by name or tags, check the group's name exclusions.
045              If included and not excluded, add the group to <strong>MatchingGroups</strong> once.
046          Next group
047
048          -- Record quantities without counting overlapping matches twice.
049          If <strong>SlotItem</strong> is in <strong>TrackedItems</strong> or <strong>MatchingGroups</strong> is not empty:
050              Find or create its item-ID entry in <strong>OverallItemResults</strong>.
051              Keep the first encountered item's link and icon.
052              Add this slot's quantity once to its appropriate location totals.
053          For each group in <strong>MatchingGroups</strong>:
054              Find or create the group's entry and item-ID entry in <strong>GroupResults</strong>.
055              Add this slot's quantity once to that group's item and location totals.
056          Next group
057      Next slot
058  Next location
059
060  -- Keep individually tracked items that are not currently present.
061  For each item in <strong>TrackedItems</strong> missing from <strong>OverallItemResults</strong>:
062      Add an item entry with zero quantities.
063  Next item
</pre>

### BuildList()

<pre>
064  -- Read the settings that control which results are shown.
065  Create <strong>DisplaySettings</strong> -- Visibility, locations, empty items, grouping and expansion.
066  Read the current tracker display settings into <strong>DisplaySettings</strong>.
067
068  -- Identify the items and groups eligible for display.
069  Create <strong>VisibleItems</strong> -- Candidate rows with their source group and quantities.
070  Use <strong>GroupResults</strong> for group members and <strong>OverallItemResults</strong> for individually tracked items.
071  Apply <strong>DisplaySettings</strong> to omit hidden rows and unwanted empty items.
072  Keep each group's quantities separate when the same item appears in several groups.
073
074  -- Choose a flat list or grouped presentation.
075  Create <strong>DisplayList</strong> -- Ordered item rows and, where needed, group headers.
076  Compare overlapping items' backpack and stored-location quantities.
077  If the deduplicated visible item count is below the grouping threshold
078  and overlapping quantities agree:
079      Put the deduplicated items into <strong>DisplayList</strong>.
080  Otherwise:
081      Build group headers and member rows using the existing grouping rules.
082      Preserve separate rows where quantities differ.
083  Apply the existing sorting and expansion settings to <strong>DisplayList</strong>.
</pre>

### Display()

<pre>
084  -- Work out where the visible rows will go.
085  Create <strong>LayoutRows</strong> -- Row positions, sizes and visibility for <strong>DisplayList</strong>.
086  Calculate the layout using the current panel dimensions and <strong>DisplaySettings</strong>.
087
088  -- Update the tracker without checking inventory or matching rules again.
089  Update the panel's rows from <strong>DisplayList</strong> and <strong>LayoutRows</strong>.
090  Show the item names, icons, quantities and group headers.
091  Hide panel rows that are no longer needed.
092
093  -- Finish this scan.
094  Discard <strong>SlotTagResults</strong> and temporary per-slot working data.
095  Keep prepared name rules available for reuse until the group rules change.
</pre>

The strongest optimization so far is fetching tags together and sharing those
answers across groups. Reusing repeated name checks is a separate detail to
zoom into later; it has not consistently improved full tracker scans.

## Independent spec review

Reviewer: independent `rubber-duck` agent, `spike-spec-review`
Reviewed document identity before clarification: Git blob `1d51c14b9c3b698ef09fe12a1a6d6054309e1980`;
provisional plan blob `618fd4d553dcf7eb0310f9d244538fecdab30bb8`.

| Finding | Evidence | Tim's decision | Resolution / re-review |
|---|---|---|---|
| Release packaging includes manifest files even when their command is DEV-gated. | `Project/Publishing/PackageRelease.ps1` manifest handling | Temporary branch-only diagnostic. | Remove file and manifest entry before release; focused review found approach workable. |
| Define how FCO readiness and `IsMarked` return shapes distinguish failure from an unmarked item. | Installed `FCOIS_API.lua`, `IsMarked` | Use explicit checks. | Detailed in plan; focused reviews resolved return, disabled marker and missing storage cases. |
| Specify and test the exact gamepad/ADCUI safety checks. | Installed `FCOIS_API.lua`, API limitations | Use explicit checks. | Detailed in plan; focused review verified gate. |
| Define scan iteration counts, manual evidence procedure, watcher edge cases and offline harness wiring. | Spec/plan wording | Clarify without expanding scope. | Updated here and in plan; plan review led to unique-ID and marker-range checks. |

## Approvals and acceptance

- Product discussion agreement: user requested a temporary branch-only spike.
- Explicit spec approval: user stated "ok I'm approveing both"; subsequent
  focused reviews resolved the documented technical findings.
- Feature acceptance: PENDING
- Actual acceptance evidence and disclosed limitations: PENDING

Spec approval does not authorize coding; plan approval and a separate GO are
recorded in the implementation plan.
