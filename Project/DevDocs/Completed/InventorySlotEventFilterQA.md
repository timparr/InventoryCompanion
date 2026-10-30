# Inventory Slot Event Filter QA

**Status:** Completed; event-filter implementation reviewed, released, and verified.

This document preserves the original manual in-game QA checklist and diagnostic
observations, not an outstanding unit-test specification. Results below reflect
what was recorded during that investigation; "Not run" entries are historical,
not current release blockers.

Automated coverage in [Core/Tests.lua](../../../Core/Tests.lua), under
**Event listener transitions and refresh debounce**, checks registration and bag
filters, feature transitions, shared consumers, duplicate prevention, and
debounce behavior. Current release verification follows the
[short human transfer check](../../Publishing/ReleaseChecklist.md#short-human-transfer-check).
The separate craft-bag stow refresh observation is retained as optional idea
**F10** in the [master TODO tweaks section](../TODO.md#section-f-tweaks-and-improvement-ideas).

## Scope

Verify that `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` registrations are restricted to the backpack, craft bag, bank, and subscriber bank; that tracker and capacity behavior still updates; and that listener registrations follow enabled features.

The historical scenarios below exercise real in-game event delivery, which
mocked automated tests cannot establish. If repeating a diagnostic, use only
items you already intend to move; do not discard items or alter saved variables
for testing. Do not run `/icclean`.

## Setup

1. Load the add-on with no Lua errors. Enable the tracked-item panel, and track a test item that has a known count in the backpack and/or bank. Enable at least one standalone bag or bank bar for the capacity checks.
2. Run `/script InventoryCompanion.DebugAudit()` in chat. It intentionally raises a Lua error containing the full audit report, like the debug key's copyable test report. Read or copy the report from the error output and confirm it lists separate active `SlotUpdate_Backpack`, `SlotUpdate_Virtual`, `SlotUpdate_Bank`, and `SlotUpdate_SubscriberBank` listeners. This diagnostic error is expected. The audit confirms registrations only; it does not prove the game delivered or filtered events.
3. Open a standard bank and run `/icbankitems 10`. The command reports sample item names, counts, IDs, and slots separately for the standard bank and ESO Plus subscriber bank. Pick an item clearly listed under one bank to use for that bank's transfer test. This command is read-only and requires a bank or house chest to be open; the optional limit is 1-20 items per bank.

## Test cases

### 1. Backpack updates

- Pick up, move, or stack the tracked test item in the backpack using normal in-game actions.
- Expected: the tracked count and any configured notification update.
- If bag-space displays are enabled, verify the backpack capacity display refreshes when a slot becomes occupied or empty.

### 2. Craft-bag updates

- With ESO Plus and an eligible material already in the backpack, use the game's normal deposit/withdraw action to move it to/from the craft bag.
- Expected: the tracker reflects the backpack count change.
- Skip this case if ESO Plus or an eligible material is unavailable.
- **Observed issue:** moving one item from the backpack into the craft bag produced no logged slot event in the temporary diagnostic watcher, and the tracker panel did not update.
- **Observed working paths:** harvesting materials directly into the craft bag worked before and after the event-filter change. Withdrawing an item from the craft bag into the backpack updates the tracker normally in the current code; its watcher payload has not been recorded.
- **Historical limitation:** backpack-to-craft-bag stowing and craft-bag-to-backpack retrieval were not tested against the old code. The current stow result therefore does not establish that event filtering caused a regression.
- **Next diagnostic:** if investigating the current stow behavior further, temporarily reintroduce local-only event instrumentation and capture the actual event payload. Compare with old code only if available and safe to test.

### 3. Standard bank updates

- With the bank open, move an existing tracked item between backpack and standard bank using the game's normal UI.
- Use `/icbankitems 10` first to select an item shown under the standard bank.
- Expected: the tracker refreshes to reflect the new backpack/bank totals.
- If the bank capacity display is enabled, verify it refreshes when bank slot usage changes.

### 4. Subscriber bank updates

- If ESO Plus is active and an existing tracked item can be moved to/from the subscriber bank, use the game's normal UI.
- Use `/icbankitems 10` first to select an item shown under the subscriber bank.
- Expected: the tracker refreshes. Verify the bank capacity display remains correct.
- Skip if ESO Plus or an appropriate item is unavailable.

### 5. Unregistered container bags

- If practical, move an existing tracked item into or out of a house chest using its normal UI.
- Expected: no slot-update callback for `BAG_HOUSE_BANK_ONE` through `BAG_HOUSE_BANK_TEN`, because those bags are not part of the tracker's displayed bag list or the registered filters. Other house-chest features may still react to their own bank-open event.
- The temporary unfiltered event watcher used during diagnosis has been removed. If event-delivery evidence is needed later, use temporary local-only instrumentation and remove it after testing.

### 6. Listener enable/disable lifecycle

- Disable the tracked-item panel and all standalone bag/bank bars; hide backpack/bank capacity resources in the currency panel too. Wait longer than the 500 ms event debounce, then run the event audit.
- Expected: all four `SlotUpdate_*` registrations are inactive. Any remaining currency or capacity event listeners should match their own enabled features.
- Re-enable one feature that requires slot updates.
- Expected: all four filtered registrations become active again, without duplicate registration warnings or errors.
- Repeat with tracker-only, bag-bar-only, and bank-bar-only configurations if practical. Verify the tracker panel setting calls `UpdateEventRegistry` when changed.

## Record results

| Case | Result | Notes |
|---|---|---|
| Listener audit | Pass | `/script InventoryCompanion.DebugAudit()` reported 9/9 active listeners, including all four filtered slot-update listeners. |
| Backpack | Not run | |
| Backpack-to-craft-bag stow | No event observed (current code) | Temporary watcher logged no slot event for one transfer and the tracker panel did not update. Not tested against old code; filtering is not established as the cause. |
| Harvest directly into craft bag | Pass (before and after change) | Works in both old and current code. |
| Craft bag to backpack withdrawal | Pass (current code) | Tracker updates normally; watcher payload not recorded. Not tested against old code. |
| Standard bank | Pass | Moved all stacks both ways; tracker panel updated. Individual item identity was difficult to distinguish because items were stacked. |
| Subscriber bank | Pass | Moved all stacks both ways; tracker panel updated. Individual item identity was difficult to distinguish because items were stacked. |
| House chest excluded | Not run / N/A | |
| Listener disable/re-enable | Not run | |
| Lua errors or duplicate listeners | Not run | |

If an included bag stops refreshing or an excluded bag still invokes the handler, record the bag ID, operation, active settings, and event log. Do not remove a filter or add another bag until confirming whether that bag contributes to data currently shown by the tracker or capacity displays.
