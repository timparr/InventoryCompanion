# Tracker group-first scan: implementation plan

Status: PROVISIONAL - not approved; coding not authorized
TODO item: None; user-requested work arising from the
[FCO spike](../../Tasks/Proposals/FCOItemSaverIntegrationSpike.md)
Spec: [TrackerGroupFirstFeatureSpec.md](../FeatureSpecs/TrackerGroupFirstFeatureSpec.md) - DRAFT
Owner: Copilot
Updated: 2026-11-20

## Open questions

| ID | Question | What is needed to resolve it |
|---|---|---|
| Q5 | How many real-inventory tracker scans and what elapsed-time limit should the Debug Key test use? | **Investigation and decision:** measure in-game baseline timings and agree an iteration count such as 100 or 1,000 and an explicit limit. |

Follow the [feature development process](../../Processes/FeatureDevelopment.md).

## Current implementation and prior art

- `Core/Scanning.lua` `Scanning.GetBagContents` returns occupied slot records
  with bag, slot, item ID, link, icon and stack quantity.
- `Tracking/ItemDatabase.lua` `GetMasterItemList` checks each slot against
  compiled active group rules and individual item IDs. It accumulates one
  item record per ID, with boolean `matchedRules`, plus `ruleIndex` lists.
  `bankCount` is the combined count for all scanned bags; `bagCount` is
  incremented only for `BAG_BACKPACK`. The scan currently treats
  `BAG_VIRTUAL` as non-backpack; do not silently change this while refactoring.
- `Tracking/ItemTrackerPanel.lua` `GetTrackerDisplayList` obtains the snapshot;
  `BuildDisplayList` first builds a deduplicated visible list. It returns that
  flat list when its length is **less than** `trackerGroupThreshold` (default
  8); otherwise it folds ungrouped entries, individually tracked items and
  singleton groups into Miscellaneous and builds group/member rows.
- `RefreshItemTrackerPanel` builds the layout and renders the selected rows;
  `Core/Events.lua` queues tracker refreshes on inventory updates. The group
  snapshot itself is transient.
- Production uses of `GetMasterItemList` found are in the tracker; tests in
  `Core/RuleTests.lua`, `Core/Tests.lua` and
  `Project/Tests/TrackerPanelTests.lua` use or stub its existing result.
  `HandleTrackedItemInventoryUpdate` and AutoCategory have separate matching
  paths; they are not consumers of this snapshot.
- The archived [row-options spec](../Archive/ItemTracker/RowOptionsSpecification.md)
  documents independent location options and Miscellaneous preservation.
- `/ictest` includes synthetic scan timing and a live read-only
  `Scanning.GetBagContents` timing. The live timing alone does not measure
  group matching, tracker row construction or rendering.
- Retained in-game diagnostics show the existing 500 ms synthetic group-scan
  limit against measurements of 50-71 ms, and the 500 ms live bag-scan limit
  against measurements of 278-332 ms, with the bank closed. See
  [1.3.0 diagnostics](../../Tests/Evidence/1.3.0-20261028-client-tests.txt),
  [1.6.3 diagnostics](../../Tests/Evidence/1.6.3-20261106-uat-diagnostics.txt)
  and [1.8.1 diagnostics](../../Tests/Evidence/1.8.1-20261120-hotfix-dev-diagnostics.txt).

## Background: case study - master writs

Group configuration:

| Group | Conditions |
|---|---|
| Master Writs | Name matches `master * writ` |
| All Writs | Name matches `*writ*` |
| Writs and Affordable | Name matches `master * writ` **OR** FCO marker is Affordable |

If two master writs share an item ID and only one is marked affordable, **both**
match the name pattern. The tracker correctly counts 2 in each group; it does
not count the marked writ twice.

### Where a counting problem could still occur

Suppose two backpack items are both named `Sealed Writ` and share item ID
`123`. Neither matches `master * writ`; both match All Writs. Only the second
has the Affordable marker. If FCO can distinguish the copies, Writs and
Affordable should count only one.

IC builds a shared item record and a list of item IDs for each group. With the
proposed FCO matching added, scanning the first, unmarked copy would produce:

```lua
snapshot = {
    items = {
        [123] = {
            bagCount = 1,
            bankCount = 1, -- combined backpack + bank count
            matchedRules = { allWrits = true },
            -- itemId, link and icon also stored
        },
    },
    ruleIndex = {
        allWrits = { 123 },
    },
}
```

For the second, marked copy, the scan temporarily finds:

```lua
matchedRules = { allWrits = true, affordable = true }
```

IC increments the **same** item-ID record and adds Affordable to its matching
rule keys and group index. It has not stored the first copy's
`affordable = false` result separately. The index contains each item ID only
once:

```lua
snapshot = {
    items = {
        [123] = {
            bagCount = 2,
            bankCount = 2,
            matchedRules = { allWrits = true, affordable = true },
            -- itemId, link and icon omitted here
        },
    },
    ruleIndex = {
        allWrits = { 123 },
        affordable = { 123 },
    },
}
```

The Affordable list still contains `123` once, but a naive implementation
would read its quantity from the shared record:

| Tracker group | Expected count | Naive shared-record count |
|---|---:|---:|
| Writs and Affordable | 1 | 2 |

The FCO match is hypothetical: this is a potential implementation issue, not
an observed result. FCO's identity settings and support for the item type
determine whether it can distinguish the copies.

### Possible solutions

Both options record each copy's contribution to its matching groups during
the scan. Counts use stack quantities, not slot counts. The examples below
show the data after both copies have been scanned; `bankCount` follows the
current convention of a combined backpack-plus-bank total.

**Option 1: Add group counts to each item record.**

```lua
items[123] = {
    bagCount = 2,
    bankCount = 2,
    matchedRules = {
        allWrits = { bagCount = 2, bankCount = 2 },
        affordable = { bagCount = 1, bankCount = 1 },
    },
    -- itemId, link and icon omitted
}
ruleIndex = {
    allWrits = { 123 },
    affordable = { 123 },
}
```

After the first copy, only `allWrits` has a count, of 1. The second increments
`allWrits` to 2 and adds `affordable` with a count of 1. Overall item counts
remain available for individually tracked items.

**Option 2: Build group records alongside the shared item records.**

```lua
items[123] = {
    bagCount = 2,
    bankCount = 2,
    -- itemId, link and icon omitted
}
groups = {
    allWrits = {
        name = "All Writs",
        bagCount = 2,
        bankCount = 2,
        items = {
            [123] = { bagCount = 2, bankCount = 2 },
        },
    },
    affordable = {
        name = "Writs and Affordable",
        bagCount = 1,
        bankCount = 1,
        items = {
            [123] = { bagCount = 1, bankCount = 1 },
        },
    },
}
```

The per-item counts within each group are needed for expanded rows; group
totals alone are not enough. Shared item records retain overall counts and
item details for individually tracked items.

The group-first structure may be cleaner for assembling the tracker because
its data is already organized by group, but it changes the current scan result
and its consumers more. The first option is a smaller change to the existing
structure. The agreed flat-view and Miscellaneous rules are documented below.
The group-first approach is the direction requested for this plan, but its
details remain provisional; neither design is implemented.

## Technical options and decisions

| ID | Alternatives and trade-offs | Recommendation | Agreed choice and evidence |
|---|---|---|---|
| D1 | Extend per-item boolean tags vs return group-first data with per-item counts. | Group-first: maps directly to grouped rows; retain only the additional transient information needed for deduplication. | Group-first plan requested; final representation PENDING. |
| D2 | Deduplicate equal group counts vs preserve group headers for differing counts. | Compare each repeated item's backpack and bank counts; deduplicate equal counts without adding, otherwise keep the entire display grouped. | Tim: "if the item counts are the same in all groups where that itemid is represented then just dedupe (don't add) otherwise, don't flatten at all". |
| D3 | Preserve the strict configurable threshold and retain singleton group headers. | Test the existing threshold boundary and changed singleton behavior. | Tim: "yes configurable", "yes make it strictly < then", and confirmed singleton groups retain their own headers. |
| D4 | Preserve existing location-setting precedence vs force grouping or change location visibility. | Preserve first-eligible-source behavior, including the existing ungrouped-group-before-individual order for Miscellaneous. | Tim confirmed preserving existing behavior. |
| D5 | Select a Miscellaneous count for an item with multiple sources. | Use the first eligible source's count without adding. | Tim: "do it the same way - just take the first one encountered". |
| D6 | Tighten existing diagnostic timing limits vs leave them unchanged. | Re-measure after the group-first change; consider tightening the synthetic limit, but treat the live bag-scan limit cautiously because inventory size and hardware affect it. | Tim agreed; exact limits remain undecided. |

## SavedVariables changes and migration

The proposed scan snapshot is transient. Retain `trackerGroupThreshold`,
tracked item/group data, display flags and expansion preferences unchanged;
therefore no schema bump or migration is expected for this design.

## Data, compatibility, and failure contracts

Provisional result after scanning two backpack copies with item ID 123, one
matching only All Writs and one matching both groups:

```lua
groups = {
    allWrits = {
        bagCount = 2, bankCount = 2,
        items = { [123] = { bagCount = 2, bankCount = 2 } },
    },
    affordable = {
        bagCount = 1, bankCount = 1,
        items = { [123] = { bagCount = 1, bankCount = 1 } },
    },
    miscellaneous = { items = {} },
}
```

Keep the item link/icon and location/display data available to row builders;
the exact placement is provisional. Totals and item counts use stack
quantities, with existing combined `bankCount` semantics. Do not increment a
group twice for multiple matching include patterns. For flat display, compare
the counts across groups for each repeated item ID. Equal counts are displayed
once without adding; any differing counts prevent flattening for the entire
display. Equal counts do not establish that the groups matched the same copies
or that the flat count represents their union. For Miscellaneous, use the
first eligible source's item count and location options; ungrouped groups
precede individually tracked items, and group iteration order is unspecified.
An individually tracked source represents all scanned copies of its item ID,
but an earlier ungrouped group may supply the displayed count instead. This
first-source count can differ from today's shared item total.
Singleton groups retain their own headers rather than being folded into
Miscellaneous.

Keep data transient and rebuild on refresh. Required internal contracts fail
fast; retain existing validation at external ESO and saved-data boundaries.
No migration, external addon calls, inventory writes or notification changes
are planned. Rollback is reverting the implementation; no persistent snapshot
cleanup is needed.

## Implementation tasks

### Task 1: Produce group-first scan results

- Depends on: spec approval, plan approval and separate GO to code.
- Spec coverage: AC1, AC3, AC4, AC5.
- Files/methods and affected callers: `Tracking/ItemDatabase.lua`
  `GetMasterItemList`, `evaluateAndRecordItem`, `registerItemRules`,
  `addRescuePassForTrackedItems` and their helpers; tracker caller
  `GetTrackerDisplayList`; existing scan consumers in `Core/RuleTests.lua`
  and `Core/Tests.lua`.
- Method contracts: modify `GetMasterItemList(trackedItems, activeRules,
  bagIdList)` to return a fresh group-first snapshot with per-group item and
  aggregate counts and metadata, plus the source counts needed for
  Miscellaneous. Modify the existing scan helpers to evaluate each
  slot once against each group, add the stack to every matching group once,
  and represent individually tracked IDs in Miscellaneous, including
  zero-count entries when needed. Preserve compiled includes/excludes and
  the existing bag-count convention.
- Caller wiring and execution order: `GetTrackerDisplayList` supplies active
  tracked items, active rules and the existing bag list; `GetMasterItemList`
  calls `Scanning.GetBagContents`, evaluates slot matches, accumulates group
  records, then resolves any post-scan membership needed for Miscellaneous. Update all
  callers and test fixtures to the new contract together.
- State and preservation: data is owned by the refresh and discarded after
  use; scan and matching do not modify saved configuration. Do not assume
  equal group counts identify the same contributing copies.
- Verification: focused synthetic cases for same ID with different matching
  results, overlapping patterns, stack quantities, separate locations,
  tracked-only/zero items and exclusions. Compare synthetic scan/burst timing
  and approved in-game measurements against the pre-change baseline.

### Task 2: Build and render group-first rows

- Depends on: Task 1.
- Spec coverage: AC1-AC4.
- Files/methods and affected callers: `Tracking/ItemTrackerPanel.lua`
  `BuildDisplayList`, `CollectAllVisibleItems`,
  `FoldSingleMemberAndUngroupedIntoMisc`, `CollectSortedGroupNames`,
  `ProcessGroupsAndMembers`, `GetTrackerDisplayList`,
  `BuildLayoutModel` and `SelectRows`; `Core/Settings.lua` only if a threshold
  change is explicitly approved. Update
  `Project/Tests/TrackerPanelTests.lua` fixtures.
- Method contracts: `BuildDisplayList` consumes the group-first snapshot and
  applies visibility and location rules. Below the threshold, compare counts
  of repeated item IDs across groups: if all match, deduplicate without
  adding and emit alphabetized child rows without headers; if any differ,
  emit the grouped display instead. At or above the threshold, emit the
  grouped display. Retain singleton group headers. `ProcessGroupsAndMembers`
  uses each group's own item counts and appropriate group totals, not another
  group's or the shared item's totals. Rework existing collection/folding
  helpers rather than maintaining two independent scans. Miscellaneous uses
  the first eligible source's count and preserves existing first-eligible-source
  location settings, including source precedence.
- Caller wiring and execution order: `RefreshItemTrackerPanel` calls
  `GetTrackerDisplayList`, which obtains the new snapshot and invokes
  `BuildDisplayList`; existing layout selection and rendering consume its row
  list. Preserve expansion preferences, row budget, scrolling, sorting,
  location icons and zero-count visibility. No manifest, XML, event
  registration or profile lifecycle change is expected.
- State and preservation: retain current saved settings and their profile
  ownership unless separately approved. The small-list mode changes row
  presentation, not group membership or stored group settings.
- Verification: test threshold minus one as flat when counts agree, and as
  grouped when they differ; threshold and threshold plus one as grouped;
  alphabetical ordering and equal-count item-ID deduplication without adding;
  overlapping groups; first-source Miscellaneous counts, individual membership
  and singleton headers;
  independent location flags; expanded and collapsed group counts; empty and
  zero items; existing layout regression cases.

### Task 3: Verify and document

- Depends on: Tasks 1-2.
- Spec coverage: AC1-AC5.
- Files/methods and affected callers: `Core/RuleTests.lua` and
  `Core/Tests.lua` scan tests, including `RunTests`; the Debug Key invokes
  `this.RunTests` via `Core/Init.lua`. Update
  `Project/Tests/TrackerPanelTests.lua` display tests and use the existing
  `Project/Tests/Run-RuleTests.py` runner. Update directly affected user
  documentation only for behavior actually approved and delivered.
- Contracts and wiring: tests use fabricated bag contents, stubbed APIs and
  isolated saved state, restore replaced globals, and exercise the real scan
  and tracker builders where applicable. Do not use a fabricated FCO result
  to claim actual FCO integration. Add a read-only real-inventory tracker scan
  and group-building test to `Core/Tests.lua` `RunTests`: run the agreed
  number of scans, assert total elapsed time is below the agreed limit, and
  report actual measurements and any unavailable coverage. The Debug Key and
  `/ictest` run the same suite. Choose the iteration count and limit using
  in-game baseline evidence (Q5), not an arbitrary value.
- Verification: run
  `python Project\\Tests\\Run-RuleTests.py --test-filter "<focused regex>"`
  using the actual relevant test names; expand to the full runner if targeted
  failures or shared contracts warrant it. Record Lua 5.1 compilation and
  focused test results. With separate approval, capture a baseline in game
  before implementation and compare it with the candidate using the same
  representative inventory, active rules, locations and tracker settings.
  Measure the actual tracker scan/group-building path and observe tracker
  refresh responsiveness during normal use, not only synthetic scans.
  Existing `/ictest` live bag-scan timing is supplemental, not a proxy for
  the full tracker. After independent code review and separate approval, run
  the   candidate in-game display and performance checks. Repeat comparable
  measurements and investigate any repeatable regression. Reassess the
  existing synthetic timing limit using the new measurements; be cautious
  with the live bag-scan limit. Do not change any limit until a specific
  value is agreed. The new assertion uses the agreed limit for this test.

## Verification and acceptance mapping

| Spec criterion | Task | Required evidence | Actual result |
|---|---|---|---|
| AC1 | 1-3 | Exact per-group and per-item location counts, including overlapping patterns and mixed same-ID copies. | PENDING |
| AC2 | 2-3 | At N-1, equal counts deduplicate without addition and differing counts force grouping; grouped at N and N+1. | PENDING |
| AC3 | 1-3 | First-source Miscellaneous counts, individual items, singleton groups, location flags and zero-count behavior. | PENDING |
| AC4 | 1-3 | Existing rule, tracker and profile regressions; in-game layout observations. | PENDING |
| AC5 | 1, 3 | Debug Key repeatedly scans real inventory and asserts the agreed elapsed-time limit; compare baseline/candidate evidence and investigate repeatable regressions. | PENDING |

Offline tests cannot establish actual ESO rendering or real inventory behavior.
In-game tests require separate approval and the project's normal safeguards;
synthetic tests must not mutate live inventory or saved variables.

## Independent plan review

Reviewer and reviewed plan/spec revision and source identity: PENDING

Findings, Tim's decisions, resolutions and re-review: PENDING

## Approvals

- Explicit spec approval and revision: PENDING
- Explicit plan approval and revision: PENDING
- Explicit GO to code: PENDING

## Implementation record and deviations

PENDING - no implementation authorized.

## Independent code review and verification

Reviewer, reviewed diff, findings, test results and limitations: PENDING

## Acceptance and handoff

- Approved in-game test scope and actual results: PENDING
- Explicit feature acceptance: PENDING
- Documentation, TODO, completed-work index and archive updates: PENDING
- Commit/merge authorization: PENDING
- Release follows a separate process and is not authorized by acceptance.
