# Partial Craft Bag and Furniture Vault Withdrawals: combined specification and implementation plan

Status: IMPLEMENTATION IN PROGRESS - scope adapted during in-game testing
TODO item: [B5](../../Tasks/TODO.md)
Owner: Tim / Copilot
Updated: 2026-11-19

This compact document combines the product requirements and implementation plan
at Tim's request. The feature adds partial withdrawals from Craft Bag and
Furniture Vault stacks, plus partial Stow from eligible backpack stacks.

## User-facing behavior

For Craft Bag and Furniture Vault stacks containing more than one item, offer
**Withdraw 1** and **Withdraw N-1**. For stacks over 201, also offer
**Withdraw 200 (one stack)**; label N-1 with `ceil((N-1)/200)` stacks and
transfer it in requests of at most 200. Try Furniture Vault in game; if its
hook or transfer path proves problematic, drop it and retain Craft Bag.

When ESO offers its normal Craft Bag **Stow** action for an eligible backpack
stack, add **Stow 1**, **Stow N-1**, and **Stow N** for the full stack. Split
and stow only the selected quantity. Gemmable items use ESO's Stow confirmation
text and stow only after the player confirms. Do not add new actions while the
guild bank is open or change existing guild-bank behavior. No arbitrary
quantity entry, settings, saved data, or other transfer directions are added.

## Acceptance criteria

| ID | Required result | Verification |
|---|---|---|
| AC1 | Craft Bag and retained Furniture Vault stacks of N > 1 offer Withdraw 1 and N-1. For N > 201, they also offer Withdraw 200 and show N-1's `ceil((N-1)/200)` stack count. No new choices appear while the guild bank is open. | In game, inspect each included storage's stack menu, including while the standard bank is open. |
| AC2 | Withdraw 1, Withdraw 200, and batched N-1 move their exact labeled quantities to the backpack and leave the remainder in storage. Each request is at most 200. | In game, verify source/backpack counts for Craft Bag and, if retained, Furniture Vault, with enough room for the requested quantity. |
| AC3 | An eligible backpack stack with ESO Craft Bag access and a Stow action offers Stow 1, Stow N-1, and Stow N, moving only the chosen quantity into the Craft Bag without ESO's quantity prompt. Gemmable items retain ESO's confirmation before stowing. | In game, test all three choices and verify backpack/Craft Bag counts. |
| AC4 | One-item stacks have no partial choices, and partial Stow is hidden when Craft Bag access or item eligibility is absent. | Inspect available one-item and ineligible stacks; verify menu conditions offline. |
| AC5 | Existing bank, house-bank, and guild-bank partial-transfer behavior remains unchanged. | Offline guild-bank regression checks; in-game regression only for standard bank/house bank. Do not interact with the guild bank. |
| AC6 | If no backpack target can fit the next exact withdrawal batch, no oversized request is sent; errors clearly report a stopped partial transfer. | Focused offline tests for target selection and failure reporting. |
| AC7 | The authoritative working changelog describes partial withdrawals, Stow 1/N-1/N, and “Thanks Delena!” | Use the latest annotated `v<version>` release tag and its closeout records as the published baseline; this workflow creates the tag only after ESOUI accepts the upload and reports the intended version. Do not perform further online checks after that confirmation. Place the entry under `[unreleased]` until the release review agrees a version. Do not routinely ask again; stop if the evidence conflicts. |
| AC8 | The README's “Move one item or all but one” section describes partial and full-stack Craft Bag Stow and multi-stack withdrawals. | Inspect the revised opening paragraph in `Project/Publishing/Source Documents/ReadMe-Body.bbcode`. |
| AC9 | Context-menu actions reject a source stack that changed after the menu was built, while gemmable Stow confirmation was open, or between withdrawal batches, whether its item link or count changed. | Focused offline regression tests replace the source item link with the same count, change the expected count, and replace the item between batches; no wrong-item transfer starts. |

## Current implementation and prior art

- [`Core/ContextMenus.lua`](../../../Core/ContextMenus.lua), `AddContextMenuItems`,
  currently adds partial-transfer choices for bank and guild-bank contexts.
  The choices already calculate 1 and N-1 and route ordinary transfers through
  `TransferContextItem`.
- [`Banking/BankTransfers.lua`](../../../Banking/BankTransfers.lua),
  `TransferContextItem`, chooses a backpack target and submits
  `RequestMoveItem`. Virtual-storage requests are capped at 200 and large
  withdrawals proceed sequentially without weakening the standard-bank guard
  for other source bags.
- The existing transfer helper finds a matching backpack stack or an empty
  slot, reports a full backpack, and sends a user message on success.
- ESO's normal Stow path accepts a selected amount via
  `PickupInventoryItem` followed by `PlaceInInventory(BAG_VIRTUAL, 0)`.
  Partial Stow must keep the normal Craft Bag eligibility checks and display
  ESO's confirmation before stowing gemmable items.
- `BAG_FURNITURE_VAULT` and the `ZO_FurnitureVault` UI are present, but no
  Furniture Vault partial-transfer implementation or existing focused
  transfer test was found in this checkout. It remains to verify that vault
  rows invoke `ZO_InventorySlot_ShowContextMenu` with `BAG_FURNITURE_VAULT` and
  their slot index, and that `RequestMoveItem` can withdraw those items.
  Pass the row's slot index through unchanged.
- Each Craft Bag/Furniture Vault withdrawal request is capped at 200. Large
  N-1 withdrawals issue sequential requests and may create multiple backpack
  stacks. Each request must fit one target stack or an empty slot; if no target
  can fit the next exact batch, report the partial amount already moved.

## Implementation plan

### Task 1: Add batched withdrawals and partial Craft Bag Stow

- Depends on: None.
- Spec coverage: AC1-AC6.
- Files/methods:
  - Modify `AddContextMenuItems` in `Core/ContextMenus.lua`.
  - Modify `TransferContextItem` and `StowContextItem` in
    `Banking/BankTransfers.lua`.
- Changes and contracts:
  1. For `BAG_VIRTUAL` and `BAG_FURNITURE_VAULT`, keep **Withdraw 1** and
     **Withdraw N-1**. When N > 201, also offer **Withdraw 200 (one stack)**;
     label N-1 with `ceil((N-1)/200)` stacks.
  2. Route both source bags to `BAG_BACKPACK`. Keep each
     `RequestMoveItem` at or below 200, confirm each batch by comparing source
     and backpack counts, and find a target that can fit that exact batch. Send
     batches sequentially. If progress cannot be confirmed or no target fits,
     stop and report the amount already moved.
  3. Add **Stow 1**, **Stow N-1**, and **Stow N** to eligible backpack rows
     when ESO's Stow action is available. Preserve ESO's `HasCraftBagAccess`,
     `CanItemBeVirtual`, and stolen-item checks. Allow the full stack amount.
     Split the selected amount with `PickupInventoryItem`, then stow it with
     `PlaceInInventory(BAG_VIRTUAL, 0)`.
     Gemmable items must display ESO's Stow confirmation and transfer only on
     confirmation.
  4. Do not add these actions while the guild bank is open. Keep existing bank
     and guild-bank paths unchanged; do not perform guild-bank in-game tests.
  5. Furniture Vault is still optional. If its hook or transfer path is
     problematic or unavailable to verify with a multi-item stack, drop it and
     update tests, documentation, and acceptance criteria to retain Craft Bag.
- State and data: No SavedVariables, schema, profile, or manifest changes.
- Preservation: Existing bank and guild-bank action selection and transfer
  paths remain unchanged.

### Task 2: Update the changelog and README

- Depends on: Task 1 and the recorded outcome of Furniture Vault testing.
- Spec coverage: AC7, AC8.
- Files:
  - Update `Project/Publishing/Source Documents/Changelog.bbcode`.
  - Update `Project/Publishing/Source Documents/ReadMe-Body.bbcode`.
- Changes:
  - Add the AC7 BBCode bullet for the retained scope, including the agreed
    attribution, to the authoritative working changelog under the next
    unpublished heading. Use the latest annotated release tag and its
    closeout records as the published baseline; stop if that evidence conflicts.
    Do not assign a release version before the release review agrees it.
  - Revise the opening of the README's “Move one item or all but one” section
    to describe partial Craft Bag Stow and multi-stack withdrawals from Craft
    Bag, and Furniture Vault if retained.
  - Preserve the existing BBCode conventions. Release packaging and publication
    remain outside this feature task.

### Task 3: Verify behavior and documentation

- Depends on: Tasks 1 and 2.
- Spec coverage: AC1-AC8.
- Checks:
  - Add `Project\Tests\CraftBagAndFurnitureVaultWithdrawalTests.lua` and wire
    it into `Project\Tests\Run-RuleTests.py`. Test Furniture Vault only if it
    is retained under D1c. Exercise the hooked context-menu
    callback by calling `this.InitContextMenus()` after stubbing `ZO_PreHook`; make
    `zo_callLater` synchronous and define the bag and UI constants in the test
    runtime, including `BAG_BACKPACK`, `BAG_BANK`, `BAG_VIRTUAL`,
    `BAG_FURNITURE_VAULT`, and `ZO_FurnitureVault`. Stub the reached inventory,
    tracking, bank, and menu globals, including
    `ZO_Inventory_GetBagAndIndex`, `GetItemId`,
    `GetItemLink`, `GetItemLinkIcon`, `GetItemInfo`, `IsBankOpen`,
    `IsGuildBankOpen`, `IsHouseBankBag`, `this.GetActiveTrackedItems`,
    `this.CanUseGuildBankPartialDeposits`,
    `this.CanUseGuildBankPartialWithdrawals`, `AddCustomMenuItem`,
    `MENU_ADD_OPTION_LABEL`, and `ShowMenu`. Capture `this.TransferContextItem`
    in the menu test; for each retained source bag, verify both labels and
    amounts for N > 1 and no partial choices for N = 1, including the approved
    behavior while a standard bank is open. Verify no new choices are added
    when the guild bank is open.
  - In the focused test, verify large withdrawal menu labels and the
    `ceil((N-1)/200)` batch count; simulate delayed source/target count updates
    and assert each request amount, target slot, final source remainder, and
    timeout/no-space errors. Exercise `StowContextItem` with `PickupInventoryItem`
    and `PlaceInInventory(BAG_VIRTUAL, 0)` stubs, including ESO eligibility and
    gemmable confirmation. Do not call the local target-slot helper directly.
    Do not mutate real inventory or SavedVariables.
  - Run `python Project\Tests\Run-RuleTests.py` for Lua compilation and the
    existing offline regression suite.
  - Tim manually verifies the one-item choice, one-stack 200 choice, batched
    N-1, Stow 1, Stow N-1, and full-stack Stow, checking source and backpack
    counts. Repeat the
    withdrawal checks for Furniture Vault if a multi-item stack is available;
    otherwise record it as unavailable. Do not interact with the guild bank.
  - Confirm the changelog and README wording meet AC7 and AC8, including the
    README sentence placement.

## Decisions and open technical verification

| ID | Decision / question | Status |
|---|---|---|
| D1a | Craft Bag and Furniture Vault rows invoke the existing context-menu hook with their correct bag IDs and source slots. | Verify during implementation; Furniture Vault is unverified in this checkout. |
| D1b | `RequestMoveItem` supports partial withdrawals from `BAG_VIRTUAL` to the backpack. | Live test: Withdraw 1 succeeds; N-1 transfers at most 200, motivating the batching change. Verify the revised path in game. |
| D1c | `RequestMoveItem` supports partial withdrawals from `BAG_FURNITURE_VAULT` to the backpack. | Tim reports the original Furniture Vault test worked flawlessly; retest the revised batched path. If problematic or unavailable to verify with a multi-item stack, drop it and retain Craft Bag. |
| D2 | Use fixed quantities 1 and N-1, plus a 200-item option for stacks over 201; no arbitrary quantity UI. | Agreed by Tim in chat on 2026-11-19. |
| D3 | Keep the partial-withdrawal options available while the standard bank is open. Guild-bank behavior remains untouched. | Agreed by Tim in chat on 2026-11-19. |
| D4 | Keep “Thanks Delena!” in the changelog entry. | Agreed by Tim in chat on 2026-11-19: yes. |
| D5 | For N-1, use `ceil((N-1)/200)` sequential transfers; a 450-item stack withdraws 200 + 200 + 49 and leaves one. | Confirmed by Tim in chat on 2026-11-19. |
| D6 | Backpack stacks with an ESO Stow action offer Stow 1 and Stow N-1, splitting only the selected quantity; retain ESO's gemmable-item confirmation. | Confirmed by Tim in chat on 2026-11-19. |
| D8 | Add a third custom Stow option for the full stack so ESO does not prompt for a quantity. | Requested by Tim on 2026-11-19. |
| D7 | Guild-bank behavior remains out of scope; the guild-bank implementation is reference only and must not be changed. | Reconfirmed by Tim in chat on 2026-11-19. |

## Review, approvals, implementation, and acceptance

- Combined document review: Independent reviewer found no blocking issues on
  2026-11-19; final wording refinements applied.
- Explicit plan approval: Tim, 2026-11-19.
- Explicit GO to code: Tim, 2026-11-19.
- Implementation-phase evidence and decisions:
  - Tim tested the original code in game: Craft Bag Withdraw 1 worked; N-1
    moved at most 200; the backpack menu showed ESO's Stow action but no
    partial-stow options. Tim reports Furniture Vault worked flawlessly.
  - Per D5, large N-1 withdrawals now use sequential requests capped at 200;
    for 450 items, the requested amount is 449, sent as 200 + 200 + 49.
  - Per D6, eligible backpack stacks now offer partial Stow using the normal
    `PickupInventoryItem` / `PlaceInInventory(BAG_VIRTUAL, 0)` path. Guild-bank
    code and behavior remain unchanged.
- Implementation record:
  - Added 1, 200, and batched N-1 choices for large Craft Bag and Furniture
    Vault stacks; partial Craft Bag Stow choices and the gemmable-item
    confirmation path; and focused offline regression coverage.
  - Tim reports the implemented withdrawal and partial-Stow behavior works
    nicely. Added a third custom Stow choice for the full stack, allowing the
    existing helper to transfer N items without ESO's quantity-entry prompt;
    gemmable items still require ESO's yes/no confirmation.
  - Updated the README source wording for partial and full-stack Stow.
  - Initial implementation verification, before the stale-slot guard: 17/17
    focused feature tests and 264/264 full offline tests passed; all addon Lua
    syntax was checked with Lua 5.1.
  - Current release-review filter: 25/25 selected isolated addon tests passed,
    including all 21 Craft Bag/Furniture Vault transfer tests; all addon Lua
    syntax was checked with Lua 5.1. The full suite was not rerun after the
    focused stale-slot guard.
  - Independent review found that a fully withdrawn stack was reported as a
    failure after its source slot emptied. The poll now treats only a missing
    source item ID with a zero count as empty, then requires exact source-loss
    and backpack-gain counts; a full-stack regression test covers Craft Bag and
    Furniture Vault.
  - Release source review found that a stale context-menu slot could refer to a
    different item when selected or after gemmable confirmation. Callbacks now
    carry the expected item link and count, and batched withdrawals recheck the
    link before continuing.
  - Changelog entry was drafted under `[unreleased]`; the release review must
    agree a version before the heading changes.
- Independent code review of the empty-source correction: no significant
  issues found.
- Independent review of the added full-stack Stow option: no significant issues
  found.
- In-game verification of the full-stack Stow option: PENDING.
- Explicit feature acceptance: PENDING.
- Release work: Not included; follows the separate release process.
