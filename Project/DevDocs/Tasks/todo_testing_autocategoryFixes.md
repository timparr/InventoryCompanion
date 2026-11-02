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

All seven contexts ship with schema 6, the per-profile `autoCategorySetupComplete`
flag, and the native radio setup dialog (Near the top (default) / At the bottom
with Confirm/Cancel). The author confirmed in-game acceptance on 2026-11-01:
the implementation has met its acceptance criteria; the remaining work was the
ongoing automated test coverage below.

The offline suite was updated on 2026-11-01 and passes **145/145**
(`python Project\Tests\Run-RuleTests.py`, Lua 5.1 syntax checked):

- The dialog fixture models the native radio dialog: exactly two radio choices
  with `radioButtonGroup`/`GetClickedButton()`, exactly Confirm/Cancel action
  buttons, first-radio default selection, and an explicit failure when Confirm
  runs with no selection.
- `SI_ITEMFILTERTYPE_NEW` and `SI_AC_DEFAULT_CATEGORY_NEW` use distinct mock IDs
  and distinct strings, so insertion must resolve AutoCategory's localized New
  heading; missing or empty external string data faults the integration.
- New counter tests assert the reorder-responsiveness contract (no registry
  rebuild/recompile once synchronized, changed-bag-only refreshes, no-op moves
  write nothing, unchanged status never refreshes the hidden editors).
- `/ictest` gained in-game AutoCategory performance checks (see below).

## First-enable regression coverage

- [x] Confirm the actual settings checkbox opens setup rather than immediately
  publishing enablement. (In-game: author-confirmed 2026-11-01. Offline: the
  first-enable test asserts enabling shows the dialog and publishes nothing.)
- [x] Confirm the shorter setup copy and radio labels "Near the top (default)"
  and "At the bottom" map to the IC-first and AC-first presets respectively.
  (Offline: radio text/data asserted.)
- [x] Confirm the settings button "Open AutoCategory Editor" opens IC's
  AutoCategory tab and is disabled whenever integration is off, unavailable,
  or faulted. Recheck its state after enabling, disabling, and profile changes.
  (In-game: author-confirmed 2026-11-01.)
- [x] Confirm setup confirmation immediately enables the editor button and
  updates the checkbox/status without reopening settings, via `LAM-RefreshPanel`
  with the actual registered settings panel. (In-game: author-confirmed
  2026-11-01.)
- [x] Verify both choices, with Prefer IC groups as the default, including
  actual ESO keyboard/default-button behavior. (In-game: author-confirmed
  2026-11-01. Offline: the fixture models first-radio default selection.)
- [x] Update draft dialog fixtures and callbacks for two radio choices plus
  Confirm/Cancel. The fixture models `radioButtonGroup`/`GetClickedButton()`,
  asserts exactly two radio choices and exactly Confirm/Cancel action buttons,
  exercises each selection through Confirm, and asserts Confirm with no
  selection fails explicitly. (The three-button version failed in ESO at
  `ZO_Dialog.lua:560`; the implementation reuses the native radio-dialog
  pattern.)
- [x] Cancel and dialog dismissal preserve enablement, participation, saved
  ordering, and native assignments.
- [x] Verify each effective flag independently: Show Backpack, Show Bank,
  Notify Chat, and Notify HUD, including legacy `show`/`bank`/`notify`
  resolution ("Legacy Show and Notify flags seed participation during setup").
- [x] Groups with none of those flags remain nonparticipants. Individually
  tracked items and Miscellaneous are never exported (seeds test includes a
  tracked item and asserts the exact seven-context orders).
- [x] Hidden tracker groups with Show/Notify enabled still participate.
- [x] Prefer IC groups places participating groups alphabetically after the
  localized, visible New assignment, or at the top when New is absent/hidden.
- [x] Use distinct mock values for ESO's `SI_ITEMFILTERTYPE_NEW` and
  AutoCategory's `SI_AC_DEFAULT_CATEGORY_NEW`; the fixture now maps them to
  distinct strings so insertion must resolve AutoCategory's localized string.
  Missing/empty external string data faults the integration without publishing
  ("Missing or empty AutoCategory New string fails setup without publishing
  anything").
- [x] Prefer AutoCategory groups places participating groups after all native
  assignments, including hidden native assignments.
- [x] Verify both presets against all seven contexts and both independent
  lists, including native Display/Priority orders that differ.
- [x] Preserve native names, visibility, metadata, membership, and relative
  ordering while applying the current integer-priority ordering contract.
- [x] Later Show/Notify changes do not change participation (re-enable must not
  reseed; participation is a saved per-rule flag only).
- [x] Disable/re-enable, reload, and account/character profile switches preserve
  completed setup and subsequent manual ordering/participation edits.
- [x] A setup with no participating groups, including entirely empty native
  lists, is still remembered.
- [x] Changing profiles while the dialog is open applies nothing to either
  profile and reports cancellation.
- [x] Invalid preset values and unexpected internal contracts fail explicitly
  and fault the integration ("Setup contract violations and projection failures
  fail explicitly without completing setup").
- [x] A preflight error in the last context publishes no initial participation,
  enablement, setup-complete marker, order changes, or managed assignments.
  The test now asserts the expected 999-capacity error text.
- [x] Projection or refresh failures report the cause and disable integration;
  they must not mark incomplete setup as successful (post-preflight projection
  failure covered by a synthetic cache failure).

## Saved-data coverage

- [x] Validate the new marker in every profile, including inactive characters
  and other account buckets; malformed values are preserved and reported.
- [x] Verify non-destructive schema 1-5 migration before ZOS constructors.
- [x] Schema-5 profiles with existing manual participation or IC ordering retain
  their arrangement and migrate as already configured.
- [x] Previously enabled but unconfigured profiles containing only native
  references remain eligible for first-enable setup.
- [x] Confirm setup markers survive reload and profile import/copy without
  aliasing source data (import test now covers the marker, enablement,
  participation, and deep-copied orders).
- [x] Explicit integration cleanup removes the marker along with integration
  settings while preserving unrelated settings and other accounts.
- [x] Test actual schema-5 downgrade rejection using the pinned source from
  commit `3e1afd6faf202769229add36dc148ade5b6a6912`, with no constructors or
  mutations. The actual schema-4 downgrade regression is retained.
- [x] Keep future-version rejection and unimplemented-migration tests ahead
  of the new supported schema.

## Final validation and documentation

- [x] Review the draft tests for accurate fixtures and false-positive assertions
  (stale three-button dialog fixture, universal "New" GetString stub, and the
  rebuild-expecting cache-failure fixture were all corrected).
- [x] Run `python Project\Tests\Run-RuleTests.py`; 145/145 passing with Lua 5.1
  syntax checks on 2026-11-01.
- [x] Run only additional focused suites required by later fixes in this batch.
- [x] Confirm the dialog, default choice, both presets, and re-enable behavior
  in ESO (author-confirmed acceptance, 2026-11-01).
- [ ] Reconcile the spec, ordering plan, implementation report, user manual,
  reviewed documentation copies, and working changelog with first-enable
  behavior and schema 6. Record measured results, not assumed passes.
- [ ] Run `/ictest verbose copy` in ESO with the new AutoCategory performance
  checks (below) and record the evidence alongside the existing client-test
  evidence files.

Add test requirements for subsequent fixes here as the batch continues.

## Reorder responsiveness

The user reported over two seconds for setup and a large delay on each reorder
click. Inspection found unconditional full rule-registry rebuilds and
`CompileAll`, duplicate preflights for moves, and status refreshes that rebuilt
the other IC editors even when the status had not changed.

The implementation compares desired definitions against the plugin, predefined
registry, and runtime registry before rebuilding; projection writes only
changed priorities and refreshes only changed bags; unchanged status does not
trigger a global IC UI refresh. (An earlier draft of this section described a
"reuse the preflight, swap two priorities" move path; the final implementation
runs a full plan build per move with delta-only writes, which the tests below
verify by its observable effects.) The author confirmed in-game responsiveness
acceptance on 2026-11-01 with the slow-action limit at 50 ms producing no
reports.

- [x] Instrument synthetic counters: once definitions are synchronized,
  repeated moves must invoke neither `cacheRuleInitialize` nor `CompileAll`
  ("Synchronized moves skip registry rebuilds and refresh only the changed
  bag").
- [x] Ensure first projection still installs missing definitions, and renames
  and externally missing/altered owned definitions still trigger
  synchronization. The cache-failure fixture now requires an actual definition
  change (a group rename) and first asserts that an unchanged reconcile does
  not rebuild.
- [x] Each move preflights once and preserves every other context and ordering
  mode; projection writes only changed priorities (covered by the move
  isolation and counter tests).
- [x] Only changed bags rebuild their assignment cache and refresh inventory;
  no-op boundary moves perform no writes or rebuilds.
- [x] Repeated moves with unchanged integration status do not rebuild hidden
  Items/Groups editors or refresh the entire settings panel. Actual status
  transitions, including failures, still update controls immediately.
- [x] In-game responsiveness confirmed by the author (2026-11-01); the 50 ms
  slow-action limit produced no reports across rapid repeated clicks, both
  ordering modes, native and IC rows, external edits between clicks, and
  profile switches.
- [ ] Ongoing: `/ictest` now includes AutoCategory performance checks — five
  read-only reorder preflights (limit 250 ms total), one real
  `cacheRuleInitialize` + `CompileAll` pass (limit 250 ms), and 2000 synthetic
  classifications across 20 participating groups (limit 100 ms). Run
  `/ictest verbose copy` in ESO to record the first measured baseline and
  confirm or adjust these limits.

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
