# Tracker group-first scan: implementation plan

Status: IMPLEMENTED; merged to main 2026-11-21; remaining in-game behavior checks are documented as pending
TODO item: None; user-requested work arising from the
[FCO spike](<../../Features/FCOItemSaver/003 FCOItemSaver - Spike Report.md>)
Spec: [Tracker group-first specification](<../../Features/TrackerGroupFirst/001 TrackerGroupFirst - Specification.md>) - APPROVED
Owner: Copilot
Updated: 2026-11-21

Follow the [feature development process](../../../Processes/FeatureDevelopment.md).

## Current implementation and prior art

- `Core/Scanning.lua` `Scanning.GetBagContents` returns occupied slot records
  with bag, slot, item ID, link, icon and stack quantity.
- `Tracking/ItemDatabase.lua` `GetMasterItemList` checks each slot against
  compiled active group rules and individual item IDs. It accumulates one
  item record per ID, with boolean `matchedRules`, plus `ruleIndex` lists.
  `bankCount` is the combined count for all scanned bags; `bagCount` is
  incremented only for `BAG_BACKPACK`. The scan currently treats
  `BAG_VIRTUAL` as non-backpack; do not silently change this while refactoring.
  `GetActiveTrackedRules()` excludes rules with `display.isHidden == true`
  before the tracker scan, except Miscellaneous; the group-first comparison
  uses that same active set.
- `Tracking/ItemTrackerPanel.lua` `GetTrackerDisplayList` obtains the snapshot;
  `BuildDisplayList` first builds a deduplicated visible list. It returns that
  flat list when its length is **less than** `trackerGroupThreshold` (default
  8); otherwise it folds ungrouped entries, individually tracked items and
  builds Miscellaneous and named-group/member rows. Single-item named groups
  retain their headers in grouped display.
- `RefreshItemTrackerPanel` builds the layout and renders the selected rows;
  `Core/Events.lua` queues tracker refreshes on inventory updates. The group
  snapshot itself is transient.
- Production uses of `GetMasterItemList` found are in the tracker; tests in
  `Core/RuleTests.lua`, `Core/Tests.lua` and
  `Project/Tests/TrackerPanelTests.lua` use or stub its existing result.
  `HandleTrackedItemInventoryUpdate` and AutoCategory have separate matching
  paths; they are not consumers of this snapshot.
- The archived [row-options spec](../../Archive/ItemTracker/RowOptionsSpecification.md)
  documents independent location options and Miscellaneous preservation.
- `/ictest` includes synthetic scan timing and a live read-only
  `Scanning.GetBagContents` timing. The live timing alone does not measure
  group matching, tracker row construction or rendering.
- `InventoryCompanion_DEV.txt` loads `Tracking/ItemDatabase.lua` and
  `Tracking/ItemTrackerPanel.lua` before `Core/Tests.lua`; all modules share
  the global `InventoryCompanion` table. `GetTrackerDisplayList()` and
  `BuildDisplayList()` construct data only and do not touch UI controls.
- Retained in-game diagnostics show the existing 500 ms synthetic group-scan
  limit against measurements of 50-71 ms, and the 500 ms live bag-scan limit
  against measurements of 278-332 ms, with the bank closed. See
  [1.3.0 diagnostics](../../../Tests/Evidence/1.3.0-20261028-client-tests.txt),
  [1.6.3 diagnostics](../../../Tests/Evidence/1.6.3-20261106-uat-diagnostics.txt)
  and [1.8.1 diagnostics](../../../Tests/Evidence/1.8.1-20261120-hotfix-dev-diagnostics.txt).

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

The group-first structure is the requested authoritative representation. Keep
the current shared `items` and `ruleIndex` fields as additive compatibility
data while consumers migrate; do not force unrelated scan fixtures and tests
to change contracts. Each group item also retains the first item link and icon
that matched that group, so same-ID variants can display the source-specific
item name. Name-based matching can produce different rule membership for
same-ID variants with different item-link names; FCO-specific marker matching
remains out of scope.

## Technical options and decisions

| ID | Alternatives and trade-offs | Recommendation | Agreed choice and evidence |
|---|---|---|---|
| D1 | Extend per-item boolean tags (Option 1) vs add per-group aggregate and per-item records alongside shared item data (Option 2). | Choose Option 2: it directly supplies grouped header and member counts while preserving shared item data for individually tracked items. | Tim requested group-first results; the transient representation adds the required group records without breaking the existing shared `items` and `ruleIndex` consumers. |
| D2 | Deduplicate equal group counts vs preserve group headers for differing counts. | Compare raw backpack and bank-side counts independently of location visibility; deduplicate equal counts without adding, otherwise keep the entire display grouped. Backpack is `bagCount`; bank-side is `bankCount - bagCount`, including all scanned non-backpack bags as in the existing display semantics. Compare both values separately, not the combined total. | Tim: "if the item counts are the same in all groups where that itemid is represented then just dedupe (don't add) otherwise, don't flatten at all"; "if the counts are different in either location, they are different items". |
| D3 | Preserve the strict configurable threshold and retain singleton group headers. | Test the existing threshold boundary and changed singleton behavior. | Tim: "yes configurable", "yes make it strictly < then", and confirmed singleton groups retain their own headers. |
| D4 | Preserve existing location-setting precedence vs force grouping or change location visibility. | Preserve first-eligible-source behavior, including the existing ungrouped-group-before-individual order for Miscellaneous. | Tim confirmed preserving existing behavior. |
| D5 | Select a Miscellaneous count for an item with multiple sources. | Use the first eligible source's count without adding. | Tim: "do it the same way - just take the first one encountered". |
| D6 | Change existing diagnostic timing limits or keep them unchanged. | Re-measure after the group-first change; do not change a limit without a measured value and Tim's agreement. Treat the live bag-scan limit cautiously because inventory size and hardware affect it. | Tim agreed to re-measure; exact limits remain undecided. |
| D7 | Count visible deduplicated items vs non-displayed entries for the flat-view threshold. | Count only the deduplicated list of distinct item IDs. | Tim: "only the dedupe list would be counted to determine if flattening". |
| D8 | When different counts for the same item come from ungrouped rules, retain only the first source in Miscellaneous; show source-specific duplicate rows in Miscellaneous; or temporarily promote the contributing rules to groups. | Show one Miscellaneous row per contributing ungrouped rule, labeled `[groupName]:Item` with no space after the colon. For example, "Writs and Affordable" matching "Sealed Writ" displays `[Writs and Affordable]:Sealed Writ`; use the rule's display name, counts and location settings. Keep the header non-additive and saved settings unchanged. | Tim: "lets go with duplicated rows, and change the display name to [groupName]:Item." |
| D9 | Keep long source labels readable without hiding item names. | Wrap the full label when enabled; otherwise truncate only the group-name prefix and expose its full name on hover. | Tim: "I think so." |
| D10 | Whether to retain group-count bookkeeping after the A/B test shows a scan cost, and whether that measurement settles acceptance of the comparison/duplicate-row behavior. | Keep per-group bookkeeping in production because it is required for group-specific counts. Keep the no-bookkeeping path diagnostic-only. Treat display behavior and performance acceptance as separate in-game gates; the timing does not itself establish acceptance. | Tim: "I think we implement the bookkeeping solution." (2026-11-21) |
| D11 | Whether to add separate behavior for the rare case where an ungrouped rule matches some copies of an item ID that is also individually tracked. | Do not add a new tracked-item row/comparison path for this hypothetical case; preserve existing ungrouped-rule precedence over the tracked-by-ID fallback. | Tim: "this is NEVER GOING TO HAPPEN. i don['t care - just get it coded". |

These plan decision IDs are local to the technical-options table. Map them to
the product decisions in the spec as follows: plan D1 -> spec D1; plan D2 ->
spec D4; plan D3 -> spec D2 and D3; plan D4 -> spec D5; plan D5 -> spec D6;
plan D6 is technical measurement guidance only (spec AC5 governs the
performance limit and spec D10 governs keep/remove); and plan D7-D11 -> spec
D7-D11 respectively.

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

Keep item links, icons and location/display data available to row builders.
Each group item uses the first link and icon that matched that rule, while the
shared item record continues to represent individually tracked IDs. Totals
and item counts use stack quantities, with existing combined `bankCount`
semantics. Do not increment a group twice for multiple matching include
patterns. For flat display, compare each repeated item ID's raw backpack
`bagCount` and bank-side `bankCount - bagCount` separately across every
tracker-visible rule (`display.show == true`), whether grouped or ungrouped,
regardless of location visibility. `bankCount` includes all scanned
non-backpack bags, including subscriber bank and virtual craft bag. Matching
members are included even when location or zero-count filtering hides their
rows. Exclude rules with `display.show == false`. Hidden rules are excluded by
`GetActiveTrackedRules()` before the scan (except Miscellaneous); do not
broaden that source set. Include an individually tracked source only when it
would contribute its own Miscellaneous row; when an eligible ungrouped rule
already represents that ID, the tracked source is shadowed and is not an
additional comparison source. Equal pairs are displayed once without adding;
any differing value prevents flattening for the entire display.
The threshold uses the deduplicated count of distinct visible item IDs.
Equal counts do not establish that the groups matched the same copies or that
the flat count represents their union. For Miscellaneous, use only the first
eligible source's item counts and location options for its aggregate. A source
is eligible when its tracker `display.show` is true and it contributes the
item ID; ungrouped groups precede individually tracked items. When multiple
ungrouped rules contribute different values, replace the ordinary
Miscellaneous detail row with one row per contributing rule, labeled
`[groupName]:Item`, using that rule's per-location counts, item link and
display settings. Do not retain an additional undifferentiated row for the ID.
Keep the saved `display.group` settings unchanged. The Miscellaneous header
total remains non-additive: count each distinct item ID using the first
eligible source. When that source is a rule, use its group-specific count;
use the shared item total only when the individually tracked source supplies
the Miscellaneous row.
When the relevant ungrouped source counts agree, retain one item row using the
first eligible source's count and display settings. An individually tracked
source contributes overall item counts, but an earlier ungrouped group may
supply narrower group counts. The first-source aggregate remains subject to
the existing encounter order; do not introduce a sorted tie-break. Row
identity and layout signatures include the source rule and rendered label
as well as item ID, so duplicate rows do not collide. Labels use a separate
display field from the underlying item link. Truncation operates only on the
plain source-name prefix, never on item-link markup. Duplicate detail rows
count as rows for the existing row budget and overflow count.
The threshold includes zero-count rows when `showEmptyTrackedItems` is true
and otherwise excludes them through existing visibility rules. A singleton
group has exactly one distinct matching item ID, independent of row
visibility. It retains its header in grouped display when the header otherwise
qualifies; the member row still follows existing location and zero-count
filtering. Existing expanded-group row-budget and scrolling behavior remains
unchanged; overflow counts reflect detail rows, including duplicate source
rows.

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
  `addRescuePassForTrackedItems`, new `this.GetTrackerBagIdList()` and its
  helper logic; tracker caller `GetTrackerDisplayList`; existing scan consumers in
  `Core/RuleTests.lua` and `Core/Tests.lua`.
- Method contracts: modify `GetMasterItemList(trackedItems, activeRules,
  bagIdList)` to return a fresh snapshot with authoritative per-group item and
  aggregate counts, while retaining the existing shared `items` and
  `ruleIndex` fields. Each per-group item record contains its stack counts and
  first matching link/icon. Modify the scan helpers to evaluate each slot once
  against the compiled rules, add its stack to every matching rule once, and
  maintain an O(1) per-rule membership set while preserving the ordered
  `ruleIndex` lists. Represent tracked-only IDs through existing shared item
  data; resolve their Miscellaneous source after scanning, including
  zero-count entries when needed. Preserve compiled includes/excludes and the
  existing bag-count convention.
- `GetTrackerBagIdList()` returns backpack, bank and subscriber-bank bag IDs,
  adding the virtual craft bag only for ESO Plus. It preserves current scan
  scope regardless of bank-open state. `GetMasterItemList` requires an
  explicit bag-ID list; `nil` is not a supported default.
- Caller wiring and execution order: `GetTrackerDisplayList` supplies active
  tracked items, active rules and a shared `GetTrackerBagIdList()` result;
  `Core/Tests.lua` uses the same helper. `GetMasterItemList` calls
  `Scanning.GetBagContents`, evaluates slot matches, accumulates group records,
  then resolves any post-scan membership needed for Miscellaneous. Update only
  consumers that need group counts; preserve compatibility for existing
  shared-item consumers and fixtures.
- State and preservation: data is owned by the refresh and discarded after
  use; scan and matching do not modify saved configuration. Do not assume
  equal group counts identify the same contributing copies.
- Verification: focused synthetic cases for same ID with different matching
  results, overlapping patterns, stack quantities, separate locations,
  tracked-only/zero items and exclusions. Compare synthetic scan/burst timing;
  collect real-inventory timing through the Debug Key display-list diagnostic.

### Task 2: Build and render group-first rows

- Depends on: Task 1.
- Spec coverage: AC1-AC4.
- Files/methods and affected callers: `Tracking/ItemTrackerPanel.lua`
  `BuildDisplayList`, `CollectAllVisibleItems`,
  `FoldSingleMemberAndUngroupedIntoMisc`, `CollectSortedGroupNames`,
  `ProcessGroupsAndMembers`, `GetItemLocations`, `PopulateBaseRow`,
  `MeasureWrappedRows`, `BuildLayoutModel`, `SelectRows`, and row-level
  source-tooltip handlers; make the existing tracker builder available as
  `this.GetTrackerDisplayList()`; `Core/Settings.lua` only if a
  threshold change is explicitly approved. Update
  `Project/Tests/TrackerPanelTests.lua` fixtures.
- Method contracts: `BuildDisplayList` consumes the group-first snapshot and
  applies visibility and location rules. Below the threshold of distinct
  visible item IDs, compare raw `bagCount` and `bankCount - bagCount`
  separately for repeated IDs across every tracker-visible rule, grouped or
  ungrouped, regardless of location flags or row visibility. Hidden rules are
  excluded by `GetActiveTrackedRules()` before the scan (except
  Miscellaneous). An individually tracked source participates only when it
  would contribute its own Miscellaneous row; an eligible ungrouped rule
  shadows that tracked source. If multiple ungrouped rules contribute the same
  item ID and their raw count pairs differ, replace the ordinary Miscellaneous
  detail row with one source-specific row per contributing rule, using that
  rule's counts, link and location settings. Label each row
  `[groupName]:Item` with no space after the colon (for example,
  `[Writs and Affordable]:Sealed Writ`), using the rule's display name and its
  representative matching link's item name. If those counts agree, deduplicate to one row
  using the first eligible source and preserve its location settings. The
  threshold is based on distinct visible item IDs, not the number of source
  rows. Preserve the underlying item link separately from the rendered label.
  Do not mutate saved group settings or add duplicate detail rows to the
  Miscellaneous header total, which remains first-source-per-distinct-item.
  `ProcessGroupsAndMembers` uses each named group's own item counts and
  aggregate totals, not another group's or the shared item's totals. Rework
  existing collection/folding helpers rather than maintaining two independent
  scans. Give duplicate rows distinct row identities based on source rule and
  item ID, and include source and label in the layout signature. Sort duplicate
  rows by rendered label for stable presentation while preserving existing
  encounter-order precedence for first-source choices. When wrapping is
  enabled, show the full label and grow the row; otherwise truncate only the
  plain source-name prefix to keep the item name visible, never item-link
  markup, and show the full source name in an `InformationTooltip` on hover
  anywhere on the duplicate row label. If the item name alone exceeds the
  available width, preserve its existing ellipsis behavior instead of
  truncating it further to fit the source prefix. Reset tooltip handlers when
  pooled rows are reused.
- Caller wiring and execution order: `RefreshItemTrackerPanel` calls
  the new non-rendering `this.GetTrackerDisplayList()` method (replacing the
  current local function), which obtains the new snapshot through
  `this.GetTrackerBagIdList()` and invokes `BuildDisplayList`; existing layout
  selection and rendering consume its row list. Keep the display-list method
  non-rendering so the Debug Key can measure it without creating UI rows.
  Preserve expansion preferences, row budget, scrolling, sorting, location
  icons and zero-count visibility. No manifest, XML, event registration or
  profile lifecycle change is expected.
- State and preservation: retain current saved settings and their profile
  ownership unless separately approved. Use the `GetActiveTrackedRules()`
  copy for the tracker build; do not use `GetRuntimeRules()` directly or
  mutate cached/saved rule settings. The small-list mode changes row
  presentation, not group membership or stored group settings.
- Verification: test threshold minus one as flat when counts agree, and as
  grouped when they differ; threshold and threshold plus one as grouped;
  alphabetical ordering and equal-count item-ID deduplication without adding;
  equal combined totals with different per-location counts; differing raw
  counts in a hidden location force grouping; differing display flags alone
  do not; for equal-count sources with different flags, assert one deduplicated
  row without asserting which unordered ungrouped source wins; overlapping
  groups; first-source Miscellaneous counts including an
  ungrouped source preceding an individually tracked source; individual
  membership; individually tracked counts participate when they contribute
  their own   Miscellaneous row, but not when shadowed by an ungrouped source, even when
  their tracked-by-ID total differs from the narrower rule match;
  `display.isHidden` rules remain excluded; same-ID variants retain
  source-specific links;
  differing counts across ungrouped sources produce one
  `[groupName]:Item` Miscellaneous row per contributing source, with correct
  per-location counts, replacing the ordinary row; omit a duplicate hidden by
  both location flags when empty items are disabled; the header remains
  non-additive; equal counts deduplicate to one row without an extra ordinary
  row; source display flags apply to each duplicate, but
  different flags alone do not create duplicates; long labels preserve the
  item name in wrapped and unwrapped modes and expose the full source name on
  hover over the whole duplicate label; pooled rows clear stale source
  tooltips; singleton headers use the existing group-header rule (visible
  stock or show-empty enabled), including expected hidden-location and
  zero-count cases; zero-count
  threshold boundaries with `showEmptyTrackedItems`; independent location
  flags; expanded/collapsed counts; existing overflow, row-budget, scrolling
  and layout regressions; inspect a real same-ID/different-name variant in
  game if one is available, otherwise record that case as synthetic-only.

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
  to claim actual FCO integration. Expose the non-rendering
  `GetTrackerDisplayList()` path for the existing `Core/Tests.lua` `RunTests`
  diagnostic; it exercises snapshot construction and `BuildDisplayList`
  together. Reuse the shared `GetTrackerBagIdList()` helper so tracker and
  diagnostic scan the same bags. The first in-game run makes three exploratory
  per-call samples without an assertion and reports bag reads, occupied
  entries, unique IDs, differing-count IDs, display rows and bank state. Use
  those measurements to choose the acceptance iteration count and elapsed-time
  limit; report PENDING until those values are agreed and the assertion is
  rerun. No same-session pre-change baseline is available; compare candidate
  samples with historical measurements only as context, not as a controlled
  before/after result.
  The Debug Key and `/ictest` run the same suite. Choose the count and limit
  from in-game measurements, not an arbitrary value. The offline tracker
  suite also builds 100 same-ID duplicate source pairs five times and reports
  the elapsed display-list time without imposing a performance limit.
- Verification: run
  `python Project\\Tests\\Run-RuleTests.py --test-filter "<focused regex>"`
  using the actual relevant test names; expand to the full runner if targeted
  failures or shared contracts warrant it. Record Lua 5.1 compilation and
  focused test results. Measure the actual tracker scan and display-list build.
  In game, observe whether existing refresh events update the panel when bank
  availability changes; each rebuild must use the current scan snapshot, so
  different bank-side raw counts can change flat/grouped presentation. Do not
  add a new bank refresh trigger in this feature. If no existing event causes
  a rebuild at the transition, the old display may remain until a later
  existing refresh; the next rebuild must use the current snapshot. Confirm
  the Miscellaneous
  header does not add source-labeled detail rows into its total. Record per-run samples and
  summarize min/median/max. Existing
  `/ictest` live bag-scan timing is supplemental, not a proxy for the full
  tracker. If the measured behavior appears slow, present the samples and
  decide with Tim after testing whether to keep or remove the source-specific
  path; do not remove it automatically. After
  independent code review and separate approval, run
  the candidate in-game display and performance checks. Repeat comparable
  measurements as needed to make the decision. Do not switch branches or
  installations for this measurement. Reassess the
  existing synthetic timing limit using the new measurements; be cautious
  with the live bag-scan limit. Do not change any limit until a specific
  value is agreed. The new assertion uses the agreed limit for this test.

## Verification and acceptance mapping

| Spec criterion | Task | Required evidence | Actual result |
|---|---|---|---|
| AC1 | 1-3 | Exact per-group and per-item location counts, including overlapping patterns and mixed same-ID copies; verify one representative group's header and child counts in game. | PENDING |
| AC2 | 2-3 | At N-1, equal per-location counts deduplicate without addition. Differing counts among ungrouped sources prevent flattening and produce source-labeled Miscellaneous rows using each source's counts; the header remains non-additive. Grouped at N and N+1. | PENDING |
| AC3 | 1-3 | First-source Miscellaneous counts, the visible non-additive header consequence, individual items, singleton groups, location flags and zero-count behavior. | PENDING |
| AC4 | 1-3 | Existing rule, tracker and profile regressions; each rebuild uses the current scan, bank transitions do not add a new refresh trigger, and current event behavior is observed in game. | PENDING |
| AC5 | 1, 3 | Debug Key makes three initial real-inventory snapshot/display-list probe samples without rendering; record bag reads, inventory size, unique and differing IDs, display rows and bank state. Agree iteration count and limit, then rerun the assertion. | PENDING: populated feature and main runs plus the bookkeeping comparison are recorded in [consolidated test results](<008 TrackerGroupFirst - Consolidated Test Results.md>); differing-source coverage and an acceptance limit remain pending. |

Offline tests cannot establish actual ESO rendering or real inventory behavior.
In-game tests require separate approval and the project's normal safeguards;
synthetic tests must not mutate live inventory or saved variables.

## Independent plan review

Independent reviewer `tracker-doc-review-final` reviewed plan SHA-256
`72503907D3B197BBAAEFBB356A030AAD0097A620AABD7E2989ECB8807E6B67F7`
and spec SHA-256
`B2296C5A38B16DA360C37B1473E919493BBF539B1A468D4018F6D05A0E152A79`.
The review identified comparison, hidden-rule, display-list performance,
baseline/fallback, singleton, helper-export and test-contract clarifications.
The documents were revised to resolve these and Tim directed implementation
now, initially deferring the performance decision until the in-game test.
After reviewing the A/B result, Tim chose to retain group-count bookkeeping;
the numeric performance limit and remaining in-game behavior checks remain
pending.
Tim instructed not to conduct another review after the remaining tracked-item
fallback question was raised. That question is resolved by preserving existing
ungrouped-rule precedence in D11; no additional independent plan review was
performed after this clarification.

## Approvals

- Explicit spec and plan approval: Tim pre-approved discussion/approval gates for this feature branch and said "ok go" (2026-11-21).
- Explicit GO to code: Tim: "no - just make it now, and then I'll test it then we will decide together." (2026-11-21).
- Implementation direction: Tim chose to retain group-count bookkeeping after reviewing the A/B measurement (2026-11-21).
- Closeout/merge: Tim requested finalization and merge (2026-11-21); remaining in-game checks and a numeric performance limit are not claimed as passed.

## Implementation record and deviations

- `Tracking/ItemDatabase.lua`: scan snapshot now includes per-rule totals and
  per-rule item counts with first-matching links/icons, while retaining shared
  `items` and `ruleIndex`; membership deduplication uses per-rule sets.
- `Tracking/ItemTrackerPanel.lua`: flat threshold compares raw backpack and
  bank-side counts before flattening; grouped rows use group counts; singleton
  headers remain; differing ungrouped sources become labeled Miscellaneous
  rows with source-aware layout identity, truncation and hover tooltip. The
  non-rendering `this.GetTrackerDisplayList()` returns the built rows and
  snapshot for diagnostics.
- `Core/RuleTests.lua` and `Project/Tests/TrackerPanelTests.lua`: added
  source-specific scan, threshold, singleton, overlap, tracked-source,
  duplicate-row, non-additive-header, location and label coverage.
- `Core/Tests.lua`: `/ictest` uses the shared bag helper and records three
  exploratory real-inventory tracker-build samples. The initial probe has no
  time limit; the acceptance iteration count and limit remain pending.
- `Core/ScanPerformance.lua`: `/ictrackperf` performs three runs of 1,000
  real-inventory iterations. It separately times `GetMasterItemList`, display
  list construction from each fresh scan snapshot, and layout-model
  construction; callbacks yield between iterations, rendering is excluded,
  and one multiline error report is raised at completion for clipboard capture.
  The same diagnostic is available on main for branch comparison. The measured
  functions have no acceptance limit yet. `/ictrackperfcompare` separately
  compares three runs of 1,000 paired scans with group bookkeeping enabled and
  disabled, alternating variant order and timing only the scan. The disabled
  path also uses the pre-feature list-based rule-index deduplication; it is
  diagnostic-only, while production `GetMasterItemList` always builds groups.
- The manifest adds this diagnostic module. No saved-variable schema, XML, or
  FCO integration change was made. Tim chose to keep group-count bookkeeping
  on 2026-11-21; the performance limit, display acceptance and bank-transition
  refresh behavior remain pending.
- Offline and in-game test results, per-scan rankings, paired bookkeeping
  differences, branch-phase comparisons, historical tracker-build probes, and
  links to all raw reports are consolidated in the
  [Tracker Group-First test results](<008 TrackerGroupFirst - Consolidated Test Results.md>).
  The full Lua 5.1 runner passed 278/278 on feature; the A/B stub confirms
  3,000 scans per mode. Real-inventory timing is observational only. Differing-
  source coverage, the acceptance limit and feature acceptance remain pending.

## Independent code review and verification

The independent code review identified a medium UTF-8 prefix-truncation issue
in `Tracking/ItemTrackerPanel.lua`. The implementation now truncates at UTF-8
character boundaries, and the focused regression plus full Lua 5.1 suite pass.
Tim instructed not to conduct another review, so this correction was not
independently re-reviewed. In-game rendering and performance acceptance remain
pending.

## Acceptance and handoff

- In-game behavior checks: PENDING where not run; see the consolidated results.
- Closeout and merge: merged to main on 2026-11-21.
- Documentation, completed-work index and archive updates: completed for this closeout.
- Commit/merge authorization: granted by Tim's closeout request.
- Numeric performance limit: not set; the recorded timing comparison is observational.
- Release follows a separate process and is not authorized by feature closeout.
