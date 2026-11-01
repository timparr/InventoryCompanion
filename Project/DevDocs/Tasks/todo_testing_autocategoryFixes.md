# AutoCategory fixes: deferred test work

Test updates and execution are deferred until the end of the current
AutoCategory fix batch. This is a work list, not acceptance evidence.

## Safety boundary

- Do not release or treat the implementation as verified until the tests below
  pass and the relevant in-game behavior is confirmed.
- Complete synthetic migration and downgrade checks before testing the new
  schema on normal saved variables. DEV and release share saved data.
- In-game classification checks and synthetic inventory-burst checks must not
  transfer items or mutate live inventory.
- Preserve unrelated existing work and test coverage.

## Current state

The first-enable implementation introduces schema 6 and the per-profile
`autoCategorySetupComplete` flag. Initial setup offers Prefer IC groups first
as the default, or Prefer AutoCategory groups, and seeds participation from
effective Show/Notify settings. Both Display and Priority lists are initialized
for all seven contexts. Later re-enablement preserves choices.

Test edits have already been started in
[AutoCategoryIntegrationTests.lua](../../Tests/AutoCategoryIntegrationTests.lua),
[SavedVariablesTests.lua](../../Tests/SavedVariablesTests.lua), and
[Run-RuleTests.py](../../Tests/Run-RuleTests.py). Keep these edits as draft work;
they are not a completed verification pass.

The last run reported **120/126 passing**. Six new setup tests failed because
the new setup functions had accidentally been defined inside the projection
function. That placement has since been corrected, but no subsequent run has
verified the correction. A passing preflight-failure test from that run also
needs rechecking: it could have passed for the wrong failure reason.

## First-enable regression coverage

- [ ] Confirm the actual settings checkbox opens setup rather than immediately
  publishing enablement.
- [ ] Confirm the shorter setup copy and radio labels "Near the top (default)"
  and "At the bottom" map to the IC-first and AC-first presets respectively.
- [ ] Confirm the settings button "Open AutoCategory Editor" opens IC's
  AutoCategory tab and is disabled whenever integration is off, unavailable,
  or faulted. Recheck its state after enabling, disabling, and profile changes.
- [ ] Confirm setup confirmation immediately enables the editor button and
  updates the checkbox/status without reopening settings. Verify refresh uses
  `LAM-RefreshPanel` with the actual registered settings panel; the installed
  LibAddonMenu has no `RefreshAddonPanel` method. Check cancellation and
  integration failure refresh the disabled states immediately too.
- [ ] Verify both choices, with Prefer IC groups as the default. Check actual
  ESO keyboard/default-button behavior, not only button text or array order.
- [ ] Update draft dialog fixtures and callbacks for two radio choices plus
  Confirm/Cancel, not three action buttons. Model `radioButtonGroup` and
  `GetClickedButton()`, assert exactly two action buttons, and exercise each
  selection through Confirm. The three-button version failed in ESO at
  `ZO_Dialog.lua:560` when trying to access Cancel's nonexistent button control;
  the implementation now reuses the earlier native radio-dialog pattern.
- [ ] Cancel and dialog dismissal preserve enablement, participation, saved
  ordering, and native assignments.
- [ ] Verify each effective flag independently: Show Backpack, Show Bank,
  Notify Chat, and Notify HUD. Include legacy flag resolution.
- [ ] Groups with none of those flags remain nonparticipants. Individually
  tracked items and Miscellaneous are never exported.
- [ ] Hidden tracker groups with Show/Notify enabled still participate.
- [ ] Prefer IC groups places participating groups alphabetically after the
  localized, visible New assignment, or at the top when New is absent/hidden.
- [ ] Use distinct mock values for ESO's `SI_ITEMFILTERTYPE_NEW` and
  AutoCategory's `SI_AC_DEFAULT_CATEGORY_NEW`; resolve the heading using only
  AutoCategory's localized string. The ESO test found groups incorrectly
  placed first because the implementation used ESO's unrelated filter label.
  Update the draft fixture, whose GetString stub currently returns "New" for
  every string ID and would conceal this defect. Check missing/empty external
  string data reports an integration error rather than silently using top.
- [ ] Prefer AutoCategory groups places participating groups after all native
  assignments, including hidden native assignments.
- [ ] Verify both presets against all seven contexts and both independent
  lists, including native Display/Priority orders that differ.
- [ ] Preserve native names, visibility, metadata, membership, and relative
  ordering while applying the current integer-priority ordering contract.
- [ ] Later Show/Notify changes do not change participation.
- [ ] Disable/re-enable, reload, and account/character profile switches preserve
  completed setup and subsequent manual ordering/participation edits.
- [ ] A setup with no participating groups, including entirely empty native
  lists, is still remembered.
- [ ] Changing profiles while the dialog is open applies nothing to either
  profile and reports cancellation.
- [ ] Invalid preset values and unexpected internal contracts fail explicitly.
- [ ] A preflight error in the last context publishes no initial participation,
  enablement, setup-complete marker, order changes, or managed assignments.
  Assert the expected capacity/boundary error, not merely any failure.
- [ ] Projection or refresh failures report the cause and disable integration;
  they must not mark incomplete setup as successful.

## Saved-data coverage

- [ ] Validate the new marker in every profile, including inactive characters
  and other account buckets; malformed values are preserved and reported.
- [ ] Verify non-destructive schema 1-5 migration before ZOS constructors.
- [ ] Schema-5 profiles with existing manual participation or IC ordering retain
  their arrangement and migrate as already configured.
- [ ] Previously enabled but unconfigured profiles containing only native
  references remain eligible for first-enable setup.
- [ ] Confirm setup markers survive reload and profile import/copy without
  aliasing source data.
- [ ] Explicit integration cleanup removes the marker along with integration
  settings while preserving unrelated settings and other accounts.
- [ ] Test actual schema-5 downgrade rejection using the pinned source from
  commit `3e1afd6faf202769229add36dc148ade5b6a6912`, with no constructors or
  mutations. Retain the existing actual schema-4 downgrade regression.
- [ ] Keep future-version rejection and unimplemented-migration tests ahead
  of the new supported schema.

## Final validation and documentation

- [ ] Review the draft tests for accurate fixtures and false-positive assertions.
- [ ] Run `python Project\Tests\Run-RuleTests.py`; fix failures and confirm Lua
  5.1 syntax checks pass.
- [ ] Run only additional focused suites required by later fixes in this batch.
- [ ] Confirm the dialog, default choice, both presets, and re-enable behavior
  in ESO. Report in-game checks separately from synthetic results.
- [ ] Reconcile the spec, ordering plan, implementation report, user manual,
  reviewed documentation copies, and working changelog with first-enable
  behavior and schema 6. Record measured results, not assumed passes.

Add test requirements for subsequent fixes here as the batch continues.

## Reorder responsiveness

The user reported over two seconds for setup and a large delay on each reorder
click. Inspection found unconditional full rule-registry rebuilds and
`CompileAll`, duplicate preflights for moves, and status refreshes that rebuilt
the other IC editors even when the status had not changed.

The implementation now compares desired definitions against the plugin,
predefined registry, and runtime registry before rebuilding; a move reuses its
preflight and adjusts only the two swapped priorities; unchanged status does
not trigger a global IC UI refresh. These changes have not yet been measured
or verified in ESO.

- [ ] Instrument synthetic counters: once definitions are synchronized,
  repeated moves must invoke neither `cacheRuleInitialize` nor `CompileAll`.
- [ ] Ensure first projection still installs missing definitions, and
  add/remove/rename operations and externally missing/altered owned definitions
  still trigger synchronization. Adjust cache-failure fixtures to require an
  actual definition change rather than expecting unnecessary rebuilds.
- [ ] Each move preflights once, swaps only two priorities in the selected mode,
  and preserves every other context and ordering mode.
- [ ] Only changed bags rebuild their assignment cache and refresh inventory;
  no-op boundary moves perform no writes or rebuilds.
- [ ] Repeated moves with unchanged integration status do not rebuild hidden
  Items/Groups editors or refresh the entire settings panel. Actual status
  transitions, including failures, still update controls immediately.
- [ ] Measure click-to-editor-update and inventory-refresh time with realistic
  synthetic category/group counts and in ESO; record timings and agree an
  explicit responsiveness threshold before claiming the delay is resolved.
- [ ] Include rapid repeated clicks, both ordering modes, native and IC rows,
  external edits between clicks, and profile switches. Preserve immediate
  editor updates and existing failure reporting.

### Five-second deferred projection (removed)

This queue was removed once the hang and slow-matcher fixes made projection
fast. Moves and copy actions now project to AutoCategory immediately, as before.
In-game measurement with the slow-action limit at 50 ms produced no reports.
The checklist below is obsolete and kept only for history.

The user subsequently requested in-memory ordering with projection five
seconds after the last move. This supersedes the earlier immediate-projection
performance expectations above. Moves and both copy actions now update a
detached in-memory order without preflight, definition sync, native writes, or
inventory refresh during the click. The idle callback performs a single
preflight and projection for the accumulated edits.

- [ ] Update existing synchronous move/copy tests to inspect the immediate
  editor order separately from saved and native state, then advance a fake
  clock. No native writes, cache rebuilds, preflights, or compilation may occur
  in the click path.
- [ ] At 4999 ms since the latest edit, nothing is projected; at 5000 ms, one
  projection applies all accumulated edits. Older scheduled callbacks do
  nothing. Test rapid moves, mixed modes, contexts, and both copy actions.
- [ ] Changes in unedited modes/contexts from AC remain authoritative.
  Added/deleted native entries merge into queued lists at projection; renamed
  native entries update pending references as well as saved/snapshot references.
- [ ] Ordinary external reconciliation callbacks must not apply queued moves
  before the five-second deadline.
- [ ] Check the pending notice appears immediately and clears after successful
  projection, including when the overall integration status text is unchanged.
- [ ] Closing/reopening the editor retains the pending order.
- [ ] Flush pending work before IC profile selection, profile import, disabling,
  group participation/pattern/delete/reset edits, and before AC changes its
  current saved profile. Model ESO's `ZO_PreHook` without accidentally
  suppressing the original AC function. Compare AC bag-table identity, because
  AC's `saved` wrapper itself is reused across profile changes.
- [ ] Verify `EVENT_PLAYER_DEACTIVATED` flushes pending edits before normal
  reload/logout saves. No new saved fields/schema changes are introduced by
  the queue. An abnormal game termination can lose unprojected in-memory edits.
- [ ] Integration failure and explicit integration cleanup invalidate all old
  callbacks and discard the pending queue. A deferred failure must show the
  actual error, restore the editor from committed data, and disable integration.
- [ ] Update test runtimes with new queue APIs, the pre-hook boundary, and
  deactivation event. Keep existing failure isolation and startup tests.
- [ ] Measure immediate click latency separately from the eventual projection
  pause. Five-second batching does not establish that the expensive projection
  itself is fast; report these timings separately.
