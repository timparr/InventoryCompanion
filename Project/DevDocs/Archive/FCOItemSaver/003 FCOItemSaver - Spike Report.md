# FCO ItemSaver Integration Spike

Archived 2026-11-24: original preliminary report from `main`, superseded by
the [consolidated spike record](<Spike/002 FCOItemSaver - Results and Decisions.md>).
The implementation statements and proposed next steps below are historical.

The temporary diagnostic is on `spike/fco-itemsaver`, not `main`. FCO group
matching has not been implemented.

## What we discovered

- FCO provides an API to check whether an item has a particular marker, such
  as **Sell at Guild Store**.
- IC can check that marker during its existing tracker scan, alongside its
  name-pattern checks. Counts must distinguish marked and unmarked copies of
  the same item.
- One in-game backpack test detected a marker change but **no slot-change
  event**. Ten passes of FCO queries took **22 ms**; this was not a full
  tracker-refresh measurement.
- AutoCategory asks IC about individual items, and could use the same group
  condition. This still needs testing.

The [master writ case study](<../TrackerGroupFirst/002 TrackerGroupFirst - Implementation Plan.md#background-case-study-master-writs>)
and possible counting structures are now background in the tracker plan.

## Proposed solution

- Update the scan to check each item's name against name patterns and use the
  FCO API to check marker conditions, adding matches to the appropriate groups.

  ```text
  for each item in each scanned bag:
      for each group:
          if any name pattern OR any FCO marker pattern matches:
              add the item's count to that group once
  ```

- Trigger the existing tracker scan on the relevant scene change back to the
  main scene, so marker-only changes are picked up.

  ```text
  when returning to the main scene from an inventory scene:
      refresh the tracker using the existing scan
  ```

- Update the AutoCategory interaction to pass the item's bag and slot into IC's
  group check, so marker groups can query FCO without scanning the whole bag.

  ```text
  when AutoCategory asks whether an item matches an IC group:
      return true if a name pattern OR an FCO marker pattern matches
  ```

- Count only the copies that match each group.

## What we plan to do next

- Propose a temporary, noisy pre-built **Sell at Guild Store** group to test
  tracker display and notifications with real items.
- Test scene coverage and bank availability.
- Make test output copyable, then run the
  [in-game MVP checklist](<004 FCOItemSaver - MVP Test Checklist.md>), including moves,
  counts and performance.

The group and refresh approach are proposals, not yet implemented or approved.
The [diagnostic record](<Spike/002 FCOItemSaver - Results and Decisions.md>)
contains the detailed results.
