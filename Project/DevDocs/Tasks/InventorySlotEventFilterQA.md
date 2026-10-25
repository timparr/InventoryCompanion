# Inventory Slot Event Filter QA

## Scope

Verify that `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` registrations are restricted to the backpack, craft bag, bank, and subscriber bank; that tracker and capacity behavior still updates; and that listener registrations follow enabled features.

The tests below require in-game verification. Use only items you already intend to move; do not discard items or alter saved variables for testing. Do not run `/icclean`. `/ictest` performs live read-only inventory scans but is not a test of event-filter delivery.

## Setup

1. Load the add-on with no Lua errors. Enable the tracked-item panel, and track a test item that has a known count in the backpack and/or bank. Enable at least one standalone bag or bank bar for the capacity checks.
2. Run `/script InventoryCompanion.DebugAudit()` in chat. Confirm it lists separate active `SlotUpdate_Backpack`, `SlotUpdate_Virtual`, `SlotUpdate_Bank`, and `SlotUpdate_SubscriberBank` listeners. There is no dedicated slash command for this audit. It confirms registrations only; it does not prove the game delivered or filtered events.
3. For event-delivery evidence, use a local development-only log inside `OnInventorySlotUpdate` that prints the received `bagId`. Remove the instrumentation before release. Do not leave diagnostic logging in the release ZIP.

## Test cases

### 1. Backpack updates

- Pick up, move, or stack the tracked test item in the backpack using normal in-game actions.
- Expected: the tracked count and any configured notification update; the slot-update log reports `BAG_BACKPACK`.
- If bag-space displays are enabled, verify the backpack capacity display refreshes when a slot becomes occupied or empty.

### 2. Craft-bag updates

- With ESO Plus and an eligible material already in the backpack, use the game's normal deposit/withdraw action to move it to/from the craft bag.
- Expected: the tracker reflects the backpack count change, and the slot-update log reports `BAG_VIRTUAL`.
- Skip this case if ESO Plus or an eligible material is unavailable.

### 3. Standard bank updates

- With the bank open, move an existing tracked item between backpack and standard bank using the game's normal UI.
- Expected: the tracker refreshes to reflect the new backpack/bank totals; the slot-update log reports `BAG_BACKPACK` and/or `BAG_BANK` for the affected slots.
- If the bank capacity display is enabled, verify it refreshes when bank slot usage changes.

### 4. Subscriber bank updates

- If ESO Plus is active and an existing tracked item can be moved to/from the subscriber bank, use the game's normal UI.
- Expected: the tracker refreshes; the slot-update log reports `BAG_SUBSCRIBER_BANK`. Verify the bank capacity display remains correct.
- Skip if ESO Plus or an appropriate item is unavailable.

### 5. Unregistered container bags

- If practical, move an existing tracked item into or out of a house chest using its normal UI.
- Expected: no slot-update callback for `BAG_HOUSE_BANK_ONE` through `BAG_HOUSE_BANK_TEN`, because those bags are not part of the tracker's displayed bag list or the registered filters. Other house-chest features may still react to their own bank-open event.
- Do not infer success from no visible panel change alone. Confirm with the temporary development-only `bagId` log, then remove the instrumentation.

### 6. Listener enable/disable lifecycle

- Disable the tracked-item panel and all standalone bag/bank bars; hide backpack/bank capacity resources in the currency panel too. Wait longer than the 500 ms event debounce, then run the event audit.
- Expected: all four `SlotUpdate_*` registrations are inactive. Any remaining currency or capacity event listeners should match their own enabled features.
- Re-enable one feature that requires slot updates.
- Expected: all four filtered registrations become active again, without duplicate registration warnings or errors.
- Repeat with tracker-only, bag-bar-only, and bank-bar-only configurations if practical. Verify the tracker panel setting calls `UpdateEventRegistry` when changed.

## Record results

| Case | Result | Notes |
|---|---|---|
| Backpack | Not run | |
| Craft bag | Not run / N/A | |
| Standard bank | Not run | |
| Subscriber bank | Not run / N/A | |
| House chest excluded | Not run / N/A | |
| Listener disable/re-enable | Not run | |
| Lua errors or duplicate listeners | Not run | |

If an included bag stops refreshing or an excluded bag still invokes the handler, record the bag ID, operation, active settings, and event log. Do not remove a filter or add another bag until confirming whether that bag contributes to data currently shown by the tracker or capacity displays.
