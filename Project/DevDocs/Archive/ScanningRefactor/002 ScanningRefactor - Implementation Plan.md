For future ai note:
this plan is NOT the sort of thing we want to produce. It went wil

# Scanning Refactor: implementation plan

> **WARNING: DO NOT USE THIS DOCUMENT AS A TEMPLATE FOR A GOOD IMPLEMENTATION
> PLAN IN ANY WAY.** It contains excessive planning, review and historical
> detail that obscured the actual work.

## Overall plan

1. Create a framework that allows our normal custom groups to include FCO pattern matching.
2. Update the scanning mechanics to be performant.
3. Update logging.
4. Create mechanisms to turn FCO on, off, suspend and resume it.

Status: IMPLEMENTATION ACCEPTED by Tim on 26 November 2026; this plan is
historical. Final acceptance must still exercise schema-15 migration using an
actual older-schema DEV backup with the required safeguards. The marker editor
is deferred.
TODO item: None; promotion of the existing FCO spike backend
Spec: [feature spec](<001 ScanningRefactor - Specification.md>)
Owner: Copilot
Updated: 2026-11-26

Follow the [feature development process](../../../Processes/FeatureDevelopment.md).
This is an extraction/promotion plan, not a replacement algorithm proposal.

## Shared FCO condition framework (26 November)

Tim directed the four objectives above and authorized implementation. The
marker editor remains future work. Earlier tasks and tables below are
historical where they conflict with this section.

1. Add positive and negative FCO marker conditions to normal saved custom
   groups. Positive name patterns and markers are ORed; any negative name
   pattern or marker vetoes the match. A group with no positive match does
   not match. A group with an unavailable required marker or suspended FCO
   is inactive as a whole. Preserve the existing virtual Miscellaneous group.
2. Feed those conditions through the existing common matcher, prepared
   scanner, tracker index and polling, notifications and AutoCategory. Batch
   marker reads where the current scanner does; preserve slice budgets and
   the 333 ms redraw cadence. Test multiple groups sharing markers and
   multiple positive and negative markers in a group. Detect FCO/marker
   availability changes even when the tracker is hidden or no markers are
   active, and invalidate affected rules.
3. Bump the settings schema and validate/migrate every profile and retained
   backup before publishing changes. Convert the three existing FCO test
   groups into normal custom groups while preserving their names, edits,
   display settings and AutoCategory positions, including when FCO is absent.
   Verify older readers reject the newer schema without changing saved data.
4. Extend the existing Enable, Suspend, Resume and confirmed Turn off paths
   to use actual marker conditions. Turn off removes every FCO-dependent
   group and its owned references across profiles and backups, preserving
   unrelated groups, individually tracked items and FCO marks. If a built-in
   is made FCO-dependent, deletion must not silently restore its baseline.
   Reuse AutoCategory's cache clearing and forced refresh for availability
   and lifecycle changes. Clean up deleted groups' owned AC templates without
   removing entries still needed by surviving profiles.
5. Replace the old Debugging Add/Remove pair with two confirmed actions:
   one creates the three single-marker custom groups; the other creates the
   mixed, multiple-marker, negative-marker and per-enabled-marker groups.
   Preserve user data and do not duplicate or overwrite groups on repeat.
6. Run focused Lua 5.1 tests for matching parity, migration, lifecycle,
   polling and both actions; independently review the code. Tim's in-game
   check exercises the real groups and normal tracker/rendering path, including
   smoothness. Migration UAT uses a real schema-14 backup with the established
   safeguards. Do not claim unperformed UAT or full-suite results.

Implementation: schema-14 groups now migrate to custom marker
conditions, and the two Debugging actions create real custom groups. Turn off
removes marker-dependent groups across profiles and backups. Availability is
monitored even with the tracker hidden or no groups. The current Lua 5.1
offline suite passed 352/352; independent review identified migration,
collision, monitoring and backup-validation corrections. Focused re-review
cleared the corrections (`fco-framework-review`, final turn). Tim accepted the
implemented feature on 26 November; real-backup migration is deferred to final
acceptance testing, not marked as passed.

In-game check, 26 November: Tim reported that it all seemed to work, with no
slowness noticed; Turn Off removed the groups, Suspend suspended them, and
the three test groups seemed to work. The saved log after `/reloadui` has no
new tracker-mismatch or AutoCategory-failure events since 01:10 UTC. It
contains two completed sliced scans with up to 17 marker IDs and 961 entries;
their maximum observed slice was 11 ms. The latest saved `/ictest` report
predates this session, so no new automated in-game result is claimed.
The specific overlapping-group cases have not been independently evidenced.
Migration from a real schema-14 backup remains pending final acceptance; no
backup was restored for this test.

The pre-test DEV backup held 11 schema-14 profiles, and the later DEV save held
the same 11 profile identities at schema 15. Non-excluded top-level fields
were unchanged. Rules, AutoCategory orders, retained backups and FCO
lifecycle/test fields were excluded because subsequent testing changed them;
this comparison is not a controlled restoration and migration test.

The existing tracker mismatch remains an accepted, logging-monitored risk;
DEV/release diagnostic-log isolation remains a release prerequisite. The
pre-change focused baseline passed 105/105. A portable test uses captured
schema-14 reader sources to verify rejection of schema-15 data before
constructors in three profile locations.

Documentation handoff, 24 November: the production feature documents are
carried onto `main` before creating `feature/scanning-refactor`. The reference
implementation remains on `spike/fco-itemsaver` at `16c31c2`; no spike runtime
code is included in this documentation handoff. Historical testing and
approvals are in the [spike archive](../../Archive/FCOItemSaver/Spike).

## UAT bank/FCO correction, 25 November

The explicit error report captured after bank opening showed that AutoCategory
supplied bag 2 / slot 155, but IC's registered predicate passed only the item
link to `ItemMatchesRuntimeRule`. Marker-only matching correctly rejected the
missing slot context. This is distinct from the spike's empty-slot query
failure. Tim authorized the fix.

Both predicate paths now forward AutoCategory's current `checkingItemBagId`
and `checkingItemSlotIndex` unchanged. A focused regression runs the actual
registered predicate and runtime matcher across marked/unmarked bank slots,
backpack and subscriber bank (including slot zero), and preserves link-only
name matching. It failed before the fix (0/1) and passes afterward.
AutoCategory/FCO/error-recording validation: 79/79 PASS, all addon Lua syntax
(5.1), XML structure and whitespace checks PASS. Independent review and
in-game bank retest were pending at implementation. Independent correction
review is now CLEARED by `dev-namespace-review`
(`dadb39b0-ddd8-4110-9c0f-0dce65309ade`, turn 3).
In-game bank retest, 25 November at 10:45 UTC: Tim reported "no error now-
seems to be working" after the requested DEV/FCO bank-opening check.
This resolves the reported bank-opening failure; broader FCO/scanning
acceptance remains open. No saved-data changes or recovery-cache
changes are part of this correction.

## Acceptance readiness (25 November)

Acceptance readiness, 25 November: the complete production offline suite
passed 317/317, including XML structure and all addon Lua syntax (5.1).
Acceptance is not yet granted. Automatic AC failure logging was subsequently
corrected with visible Log error feedback (318/318 offline tests PASS;
independent correction review CLEARED and in-game enabled/disabled recording,
button feedback and persistence verified; see the linked logging plan).
The first acceptance blocker is resolved. The spike's explicit item-cache invalidation
on AC recovery has now been restored under Tim's separate authorization
(see below); review and in-game verification remain pending. The recorded tracker-count mismatch remains
unexplained and must be resolved rather than waived by smoothness.
Further code corrections require discussion/authorization; this acceptance
pass has not changed runtime code. Remaining heavy-workload, logging-off,
lifecycle/profile and migration evidence must be completed or verified.
Tim also flagged the FCO on/off panel's appearance for the subsequent UI
design discussion, alongside the marker/group editor.

## Tracker mismatch investigation (25 November, evening)

Status: cause unresolved; Tim accepted the risk on 25 November and chose
to proceed with the logging-gated canary, investigating if it reports another
mismatch. The saved log holds seven `trackerMismatch` events. Six
predate the notification-matcher correction (around 19:23 UTC): 08:37
(item 44879, indexed one higher), 18:51 (bank counts), and the 18:57-19:09
cluster of items missing from the incremental index. The 19:09 cluster is
consistent with updates lost when the matcher threw before
`QueueTrackerSlotUpdate`, which is a lead, not proof. The seventh occurred at
22:28:55 UTC after the correction and Tim's interrupted bank transfers: item
33271 indexed 200/1169, fresh 200/1168. The incremental index was one too
high. Cause is not yet established; no raw slot data was retained.

The logged "dirty slot replay count" printed `#dirty` on a table keyed by bag
id, which is a table border, not a slot count. It is unreliable for bank-only
changes. The 22:28:55 value of 2 means bags 1 and 2 both had changes during
the scan.

Authorized, logging-only change: a mismatch now records, per differing slot
(up to 20), the previous-index, fresh-index and live record, whether the
slot was replayed, the correct replayed-slot count, bank-open state, scan
wall time, slice count and full-update flag. Behaviour is unchanged. A
regression test forces a mismatch and checks the detail. Authorized
addition: when the mismatch is actually recorded (diagnostic logging on), a
chat/HUD error reads "Tracker mismatch logged - see TODO F16" and the chat line
tells Tim to reload and ask Copilot to analyse the log; nothing is shown with
logging off, and the existing message limiter applies. Tested for both
cases. Focused suite 85/85
PASS (Lua 5.1, XML, whitespace). Independent review CLEARED
(`mismatch-diagnostic-review`, no issues). The next
mismatch captured in-game may help identify whether the cause is a lost event,
a stale read or a comparison artifact. The known cause remains unresolved;
Tim no longer requires a root-cause fix before acceptance.

## Migration evidence from the real older-schema save (25 November, 22:55)

Read-only comparison of the pre-migration schema-11 backup
(`InventoryCompanion_DEV-20261124-220243457Z.lua`, 11 profiles at version 11)
with the current DEV save (`InventoryCompanion_SavedVariables_dev`, 11 profiles
at version 14). No files were modified.
- Every profile, account-wide and per-character, was migrated to 14; none
  remained at 11.
- No data was lost. The only removed leaf is one tracker group's expanded flag
  (`treasure_maps`), and the same kind of flag was added for two other groups,
  so these are tracker collapse/expand UI changes made since migration, not
  migration loss.
- All 42 AutoCategory order lists keep every old entry in its original
  relative order; the new FCO test groups were inserted at the top of each
  list (`fcoTestGroupsCreated`, the three `__ic_fco_*` groups).
- Added fields are the expected FCO/logging ones (`fcoIntegrationState`,
  `fcoTestGroupsCreated`, `diagnosticLoggingEnabled`, the three groups'
  `autoCategoryEnabled`/`showBackpack`). Window offsets and `trackerMaxRows`
  also differ, consistent with Tim's later in-game panel moves and the
  position restore earlier that day; they are not attributed to migration.
Caveat: the comparison includes Tim's DEV use after migration, so it shows no
loss rather than an exact migration diff. Together with Tim's in-game
confirmation after the restore ("everything looked fine") and the offline
older-reader refusal tests against actual v1.8.1, this supports AC9's real
older-backup migration evidence. Tim's explicit acceptance is still required.

## FCO acceptance UI correction (25 November)

Status: spec amendment discussed and agreed; independent spec/plan review
cleared; implementation underway following Tim's GO. Tim confirmed
that unavailable Enable/Resume actions should be hidden with a textual
reason, and inactive groups cannot be edited in the two filtered views.

- `Core\Settings.lua`: replace the four full-width LAM button widgets with
  one full-width custom row. Create the existing dialog actions as two
  horizontally laid-out buttons, reassign their action, text and tooltip
  on refresh based on state/readiness and hide unused buttons. Place the
  first visible button at the left of the row and a second to its right;
  when there is only one, leave it in the first position. Use a fixed-height
  reason label below the buttons, populated from
  `FCOItemSaver.GetReadinessReason()` when Enable/Resume is unavailable.
  Fix the custom row's height to accommodate both controls and reason text.
  Each refresh clears and reapplies visible-button anchors, text and click
  handlers so no hidden action leaves a gap.
  Keep the lifecycle confirmation dialogs; the Turn Off dialog was corrected
  to the two-button form after in-game testing exposed the ESO button limit.
  LAM's installed button widget has no dynamic visibility or reflow API;
  its custom widget supports `createFunc`/`refreshFunc`. Existing
  `RefreshProfileSettings` invokes `RefreshAutoCategoryUI`, which fires
  `LAM-RefreshPanel` after lifecycle dialog actions. The same
  `RefreshAutoCategoryUI` call directly refreshes both editors. Refresh the
  custom row on panel opening through LAM's normal refresh callback.
- `Tracking\EditPanelGroupsTab.lua`: filter inactive rules from the displayed
  list, not the underlying rule accessor. Explicitly check whether the
  current selection is inactive, since it remains in `activeRules`; choose
  the first displayed group or clear the selection. When no group remains,
  hide the details and action controls, and do not call `SetActionButtons`
  with a nil selection. Preserve existing behavior for search-only filtering.
  Continue to consider inactive names in uniqueness checks; do not alter
  saved definitions or hide flags.
- `Tracking\EditPanelItemsTab.lua`: omit inactive group entries from the
  tracked-items list while retaining matching and Untracked semantics. Restore
  entries through existing refresh on reactivation; leave AutoCategory's
  editor, row ordering and inactive style unchanged.
- Tests: exercise each lifecycle state with FCO ready and unavailable,
  visibility, horizontal layout without gaps, reason text and confirmation
  callbacks; exercise the open editor refreshing after a lifecycle change,
  editor
  filtering, inactive-selection reset and reactivation while verifying
  search-only selection behavior, saved preferences and AutoCategory order
  remain unchanged. Run focused
  Lua 5.1 tests, XML checks and whitespace checks; perform independent code
  review and ask Tim to verify the visual layout in-game. No schema change
  or migration is intended.

Independent spec/plan review identified the selection-reset, layout and
readiness-reason details above. The editor refresh path was verified in
`RefreshProfileSettings` and `RefreshAutoCategoryUI`. The Turn Off warning
does not include a group preview. Focused
independent re-review found no remaining blockers.

Implementation: the FCO action row and both editor filters are in place.
Focused editor/FCO tests passed 38/38; a follow-up including the Debug Key
change passed 5/5. Both runs compiled addon Lua as 5.1 and checked XML.
Independent code review found no significant issues. In-game visual
verification remains pending.

The Debug Key no longer starts the 3,000-iteration tracker benchmark after
Tim observed severe frame-rate loss. The benchmark remains available through
`/ictrackperf` or `/ictest trackerperf`.

In-game UAT: Tim confirmed the Suspend/Resume behavior and horizontal button
layout. Turn Off failed when ESO attempted to render the third dialog button;
ESO's standard keyboard dialog supports two. Tim supplied revised warning
wording and Yes/No choices. Implementation changed accordingly; retest pending.
Focused confirmation/FCO tests passed 6/6; independent follow-up review found
no significant issues. In-game dialog retest remains pending.

Tim supplied new Enable confirmation text describing marker conditions for
custom groups. That editor remains unimplemented; Tim intends to add it
before release, so the wording must not ship ahead of that feature.

25 November, 23:50 UTC: Tim tested the Turn On/Off and Suspend/Resume workflow
and reported that it is all good. This supersedes the pending Turn Off dialog
retest above; separate inactive-editor visibility evidence is not implied.

Current full offline suite: **340/340 PASS** on 25 November, including Lua 5.1
compilation and XML checks. It includes synthetic 128-group/seven-context
burst, confirmed Repair rollback and preservation, report history and Clear
coverage. It does not replace the remaining in-game evidence.

25 November, 23:59 UTC: Tim confirmed AutoCategory Repair was thoroughly
tested during the earlier bug work and works, and accepted that prior testing
plus the current offline regressions instead of another in-game Repair test.
The specific detached-cache repair scenario was not separately retested
in-game after the correction.

At 23:52 UTC Tim ran the Debug Key twice with a bank transfer between runs,
then reloaded. Both reports survived in sequence (3 and 4), each showing
89/89 in-game tests passed; the report-history detail is recorded in the
Diagnostic Logging plan.

## FCO lifecycle and logging-off verification (25 November, 23:10)

In-game Suspend/Resume and suspended-reload check: **PASS, accepted by Tim**,
25 November. Tim reported "it works" and subsequently instructed that the
tests be marked accepted. This does not constitute acceptance of the full
feature or of the remaining lifecycle/profile and logging criteria.

AC11/AC12/AC16 offline evidence reviewed against the production code:
- Code: `GetActiveMarkerIds` returns no markers unless the state is `enabled`
  and FCO is ready, and prepared scanning skips marker reads when there are
  none. Inactive groups are skipped entirely in matching (both marker and
  name conditions), while name-only groups continue.
- Gap found: no test exercised marker-query counts through a real scan or the
  whole-group inactivity of a group with both marker and name conditions. Added
  one focused test, "FCO Suspend, unavailable dependency and Turn Off make mixed
  groups wholly inactive with no marker queries". It scans with an enabled
  group (queries > 0, marker and name both match), then Suspend, Resume,
  unavailable dependency and Turn Off: zero marker queries and no group
  matches, while name-only groups still match. No runtime code changed.
- Existing coverage: marker poll timer lifecycle across Suspend/Resume/Off,
  profile and visibility transitions; and the AC16 logging-gated watcher with
  zero revision/status/order queries while logging is off.
- Full offline suite after these changes: **336/336 PASS** (Lua 5.1, XML,
  all-addon syntax); `git diff --check` clean. This replaces the historical
  318/318 figure as the current full-suite result.
- Further lifecycle/profile and logging-off evidence remains PENDING. The log shows watcher baselines
  with logging on and the `loggingDisabled` marker, but cannot show query
  counts while off.

## Second acceptance blocker: recovery item-cache invalidation (25 November)

Tim authorized restoring the missing recovery behavior. The shared
`ClearAutoCategoryItemCache` helper from the working spike is now called by
`RetrySynchronization` after successful preflight, and by
`RepairAffectedAssignments` after confirmation/candidate validation, immediately
before projecting and refreshing AC assignments. It clears only `AC_hash` on
ZOS inventory slot records, including hidden inventories. Guards apply only
to the external ZOS inventory shapes. No saved-data schema changes, inventory
actions or live-file edits are involved.

The installed AutoCategory keyboard contract treats a missing `AC_hash` as
an item change and re-executes classification on refresh. Hidden inventories
remain lazy: their next normal refresh rechecks their items instead of forcing
all bags to render during recovery. Ordinary retries rejected by validation,
and repair previews, leave cached hashes unchanged.

Two focused cases failed before the change (0/2). Afterward all 69 selected
AutoCategory tests PASS, including existing repair rollback cases.
The new retry regression verifies invalidation before the first refresh across
visible/hidden/shared slot records, unrelated metadata preservation, unchanged
saved orders/priorities and no cache changes on failed preflight. The extended
confirmed-repair regression verifies the same hash-only invalidation while
retaining its all-context order/assignment/profile preservation checks.
All addon Lua 5.1 syntax, XML structure and whitespace checks PASS.
Independent correction review CLEARED by `dev-namespace-review`
(`dadb39b0-ddd8-4110-9c0f-0dce65309ade`, turn 5).
In-game recovery/reclassification check FAIL, 25 November at 17:44 UTC:
Tim reported the group did not return immediately after Retry; repeated bank
openings restored it after approximately ten seconds, without any further
repair action. Immediate recovery is therefore not verified and this blocker
remains open despite the offline tests and review.

Read-only follow-up confirmed installed AutoCategory's bank sorting uses
cached per-item classifications and has a fallback recheck after more than
20 seconds since the previous classification. That fallback is consistent
with delayed recovery but is not a proven explanation of this occurrence.
The existing spike helper was recorded as in-game NOT TESTED in decision D42;
restoring it is not proof of correct recovery in this bank path. The exact
missed invalidation/refresh path remained unproven at that point.

Follow-up, 25 November at 18:46 UTC: Tim authorized continued investigation.
A concrete missing case was reproduced offline: bank item records can remain
in ZOS's shared bag cache while absent from `PLAYER_INVENTORY`'s current UI
slot tables. The old helper never invalidated those records. Public ZOS
`GenerateSingleSlotData` returns existing records from that shared cache, and
the bank refresh rebuilds its slots through that function. Installed AC
reuses their `AC_hash`, so a matching hash can suppress reclassification until
its timeout. This reproducer establishes a recovery gap; it does not prove
that Tim's particular delayed run took this path.

The helper now also visits each inventory's `backingBags` using the existing
public `SHARED_INVENTORY:GetBagCache` API and clears only those existing
records' `AC_hash`. It does not create shared caches, request inventory data
or force hidden lists to render. UI-only records are still invalidated.
The new missing-shared-record regression failed before this change (0/1);
all 70 selected AutoCategory tests pass afterward. The confirmed-repair case
also covers detached shared records, alongside its preservation checks.
An additional isolated Lua 5.1 probe executed the installed AutoCategory
`detectItemChanges` function with a fixed clock and unchanged item hash.
Using the original spike helper, the rehydrated shared bank record did not
reclassify (`false`); using the corrected helper, it reclassified immediately
(`true`). No timeout elapsed and no live inventory or saved variables were used.
Lua 5.1 syntax, XML structure and whitespace checks PASS.
Independent follow-up review CLEARED by `dev-namespace-review`
(`dadb39b0-ddd8-4110-9c0f-0dce65309ade`, turn 7), including the controlled
probe evidence. Fresh immediate-recovery bank retest PASS, 25 November at
18:58 UTC: after the requested DEV reload, runtime-only failure and Retry,
Tim confirmed the FCO group appeared on the first bank opening without
waiting or repeated reopening. This resolves the second acceptance blocker
for Retry. Confirmed Repair has offline regression coverage; its separate
in-game check remains pending. The tracker-count mismatch remains open.

Public ZOS reference inspected:
- https://github.com/esoui/esoui/blob/master/esoui/ingame/inventory/sharedinventory.lua
  (`GenerateSingleSlotData`, non-creating `GetBagCache`).
- https://github.com/esoui/esoui/blob/master/esoui/ingame/inventory/inventory.lua
  (`AddInventoryItem`, `RefreshAllInventorySlots`, `UpdateList`).
The tracker-count mismatch is outside this correction.

## Missed inventory updates with FCO notifications (25 November)

Tim reported no tracker updates while Unboxer opened containers, slow visible
countdown during another addon's bank deposits, and stale counts after manual
withdrawals even after closing the bank. Splitting alone did not recover the
tracker after waits of ten and fifteen seconds; Stack All Items recovered it
after another one to two seconds. IC's own transfer-delay setting does not
establish the timing of transfers performed by another addon.

An isolated probe using the actual notification matcher and inventory-event
handler reproduced an error before `QueueTrackerSlotUpdate`: notification
matching omitted the item's bag and slot when invoking `ItemMatchesRuntimeRule`.
An enabled FCO notification therefore raised the missing-context assertion
for occupied backpack slots. Empty source slots and bank-side slot events
could still reach the tracker queue. The saved DEV settings had Chat/HUD
notifications enabled for two FCO groups. This establishes a relevant missed
update path, not proof of the live event sequence or the extra recovery delay.

Tim approved the bounded correction plan and gave GO at 19:14 UTC. The
notification call now forwards its existing `bagId` and `slotIndex` unchanged.
There is no debounce, transfer, scan-scheduling, schema or saved-data change.

Two regressions use the actual event registry/handler, notification handler,
FCO adapter/runtime matcher, slot reader and incremental tracker rendering.
Only external inventory/FCO APIs and UI controls are synthetic. Both failed
before the correction with the missing bag/slot assertion (0/2). They verify:

- Withdrawal source/destination events share one queued update, render the
  carried count without another action, and preserve a single Chat-only notice.
- Splitting a marked stack updates the original marked group's rendered count
  without Stack All Items; the synthetic unmarked destination neither matches
  that group nor produces an FCO notification.

After correction, all 59 selected tracker/FCO/notification tests PASS, including
these two regressions and existing name-only notification coverage. The runner
also validates XML structure and compiles all addon Lua under Lua 5.1.
Whitespace validation PASS. Independent correction review CLEARED by
`notification-update-review`; its evidence limitation is that synthetic
inventory/FCO events do not establish the live event sequence or prove all
reported delays fixed. Fresh in-game manual-withdrawal retest PASS,
25 November at 19:23 UTC: after the requested reload and withdrawal check
without splitting or Stack All Items, Tim reported "it updates straight away".
This resolves that manual-withdrawal observation only. Single-stack deposit
retest PASS at 19:25 UTC: Tim reported it updates straight away. Multiple
stacks/items update automatically but sequentially, with a panel redraw after
each one. This remains an open bulk-rendering concern, not evidence by itself
that updates lag behind the actual transfers. Split remains PENDING. Unboxer
retest is PENDING/unavailable: at 19:26 UTC Tim confirmed he has no large
batch of unopened treasure maps. Do not require acquiring more maps or
substitute transfer/synthetic tests as proof of Unboxer behavior. Bulk-transfer
rendering churn, the earlier recovery delay and indexed-versus-fresh mismatch
remain unresolved.

## Bulk redraw follow-up (25 November)

Historical first attempt, superseded by the 300 ms correction below.

Tim asked to continue without stopping between individual acceptance steps.
The agreed direction is to keep internal inventory counts current while
batching only visual refreshes. Investigation confirmed the pre-refactor
`Core\Events.lua` used a 500 ms trailing debounce for tracker refreshes; the
current incremental path renders immediately for every next-frame slot batch.
The spike also rendered each incremental batch, so that behavior is not a
production-extraction omission. Restoring a trailing quiet-period wait would
hide all progress during sustained activity and is not the proposed correction.

Bounded implementation:

- Keep `QueueTrackerSlotUpdate`/`ApplySlotsToIndex` on their next-frame path,
  including dirty replay and notification handling.
- Separate the snapshot/display-list construction and render from
  `ApplyTrackerSlotUpdates`. Keep one pending incremental-render callback and
  accumulate its slot-evaluation time/count for the existing refresh sample.
- Use the established 500 ms refresh interval as a minimum gap between
  incremental renders. Later updates join the same callback without resetting
  its deadline. Build from the latest current index/rules at execution, not a
  snapshot captured at the first event.
- Record the most recent render time for both ordinary synchronous refreshes
  and deferred/full renders. A full/settings/profile/hide cancellation cancels
  a pending incremental render as well; full-scan completion retains its
  existing separate-frame rendering and remains outside this incremental cap.
  An incremental apply during an active sliced job updates the index but leaves
  rendering to that job's completion. A completed full render cancels a pending
  incremental render because it already displays the current index.
- Own pending render state in one object (index, existing refresh generation,
  accumulated metrics and handle). Cancellation clears the object before
  removing its timer. Recheck object/index/generation identity, tracker
  enablement, absence of a sliced job and current profile/rules at execution.
  Invalid current context follows the existing full-refresh path rather than
  displaying stale data. Reuse the synchronous-`zo_callLater` started/handle
  pattern, detach pending metrics before rendering, and clamp the timer delay
  to 0..500 ms at the external game-clock boundary.
- Preserve `trackerRefresh` samples with actual accumulated update time and
  render cost; do not add configuration, saved-data fields, inventory actions
  or changes to transfer pacing.

Verification before deployment: virtual-clock events across multiple frames
(including 50 ms transfers) must apply immediately to the index but coalesce
visible renders to the stated interval, progress during a sustained burst and
display the final exact count without another event. Check a quiet-period
change renders promptly, and exercise the shared marker-poll queue path.
Pending work must cancel on inventory/settings refresh/hide and not redraw
stale index/profile/rule state. Cover a slot event during a sliced job and the
existing synchronous scheduler stubs. Adapt the directly dependent event-handler
tests to drain separate index/render callbacks. A full render can make the next
incremental render wait up to 500 ms; it cannot extend that deadline on each
subsequent item change.

Independent design review by `bulk-render-review` initially requested explicit
cancellation/identity checks, active-job suppression, timestamp/deadline and
synchronous-stub ordering, plus matching virtual-clock regressions. These
requirements are incorporated above. Focused design re-review CLEARED by
`bulk-render-corrections-review`
(`bfd6ee81-c0b2-47db-883c-2c8a148cefb6`, turn 0), with the explicit requirement
to cancel pending incremental work in the shared actual-render function to
cover a full-completion interleaving.

Implementation now separates next-frame index evaluation from display work
using `QueueIncrementalTrackerRender`. The pending object owns its fixed
deadline, existing index/generation identity and aggregate metrics. Both
`StartSlicedTrackerRefresh` (including direct reruns) and
`CancelSlicedTrackerRefresh` cancel it; `RenderTrackerDisplayList` also cancels
it before drawing a newer full result. The ordinary synchronous render and
shared renderer both stamp completion time. No unrequested full-scan timer,
new settings or saved-data changes were added.

Regression evidence:

- Before implementation, a virtual 50 ms burst produced 21 renders by one
  second, where the proposed display cap requires two (FAIL). The four initial
  pending-render cancellation cases also failed before the new render queue.
- After implementation, 41 changes spaced 50 ms apart update slot evaluation
  immediately but produce five renders at 500, 1000, 1500, 2000 and 2500 ms.
  The ongoing burst shows progress before it finishes, all 41 applied slots
  remain represented in render samples, and the final displayed count is exact
  without another inventory action. A subsequent isolated change renders on
  its next callback without an extra 500 ms wait.
- Pending-render tests cover inventory/settings refresh, hidden tracker,
  rules/profile changes and replacement index identity. A synchronous scheduler
  regression preserves a reentrant slot update. The existing sliced-scan test
  now also verifies that a slot event during a yielded job does not render the
  superseded index. Existing real FCO marker-poll tests use the shared queue.
- A controlled callback-order regression applies a slot event after adoption
  but before a full completion render. The full render displays the latest
  exact count and cancels the otherwise duplicate pending incremental render.
- The actual event-handler/FCO notification regressions now drain one index
  callback plus one separate display callback; their rendered counts and
  notification-destination checks still pass.

All 81 selected tracker/FCO/notification/sliced/index tests PASS, including
XML structure and all-addon Lua 5.1 compilation. Whitespace validation PASS.
Independent source review CLEARED by `bulk-render-corrections-review`
(`bfd6ee81-c0b2-47db-883c-2c8a148cefb6`, turn 1). The reviewer inspected
production scheduling/rendering code; it relied on the author's test evidence
and did not inspect or rerun the tests. It confirmed current-index rendering,
fixed deadlines, cancellation, full-render interleaving and synchronous-stub
state ordering. In-game bulk-transfer retest remains PENDING.
Unboxer remains unavailable for live retesting, not replaced by these tests.

## Trailing-edge redraw debounce correction (25 November, superseded)

At 19:42 UTC Tim reported the 500 ms throttle was quicker but still showed
intermediate carried counts (42, 39, 38, ...) after the transferred stacks had
gone. That UAT FAIL supersedes the first attempt's favorable offline/review
results: its test contract was wrong for the requested behavior. The missing
FCO notification-update correction remains separate and retained.

Tim explicitly authorized a 300 ms trailing-edge debounce at 19:44 UTC and
will try automated and manual transfers. Every supported tracker inventory
update must restart the display deadline. Next-frame slot/index updates still
run immediately; only inventory-driven display waits. There must be no
intermediate redraw during a continuous burst, and one latest-count redraw
300 ms after its last event. Gaps longer than 300 ms between manual moves can
produce separate redraws by design; author UAT will assess that interval.
The scope is the shared tracker update path, not a bank-only condition or new
bag support. Pickups, splits, stacking, container loot and crafting updates
use the same path. Explicit settings/profile refreshes remain immediate.

Bounded implementation:

- Replace `lastTrackerRenderAt`/the 500 ms minimum interval with one shared
  latest-inventory-update deadline. Update it in `QueueTrackerSlotUpdate` and
  `NoteTrackerFullInventoryUpdate`, not at scan completion.
- Share the deadline-aware timer scheduling between incremental and completed
  full-scan render requests. Each request owns its callback, handle and a
  per-scheduling identity token; restarting invalidates a canceled callback
  even if it was already ready to run. Retain the synchronous scheduler pattern.
- Later slot events reschedule both kinds of pending inventory render.
  Continue to apply dirty slots on the next frame and build the final snapshot
  from the latest current index. A pending full render owns display work instead
  of scheduling a duplicate incremental render.
- Keep existing index/generation/context/visibility checks and cancellation
  on settings/profile/hide/full refresh. Do not debounce direct editor/settings
  actions or add transfer behavior, saved-data fields or configuration.
- Replace the fixed-window tests with exact virtual-clock quiet-period checks:
  no redraw at last-event +299 ms, one exact latest-count redraw at +300 ms,
  deadline extension by another event just before expiry, and pending full
  completion postponed by a slot update. Exercise manual gaps greater than the
  interval, all existing cancellation cases and FCO notification regression.

Focused design review CLEARED by `bulk-render-corrections-review`
(`bfd6ee81-c0b2-47db-883c-2c8a148cefb6`, turn 2). It specifically required
setting the deadline before cold-index/active-job early returns, retaining the
full-completion closure when rearming its timer, and suppressing duplicate
incremental work while a full render is pending.

Implementation now uses one shared `inventoryRenderDeadline` and
`ScheduleTrackerRender` for both render types. Its per-scheduling identity
invalidates old ready callbacks when an update restarts the timer. Slot
evaluation remains next-frame, including during sliced jobs; only rendering
waits. The former last-render timestamp and 500 ms minimum-gap code are removed.

Before correction the three focused debounce regressions FAIL (0/3) against the
throttle. After correction all 83 selected tracker/FCO/notification/sliced/index
tests PASS, with XML structure, all-addon Lua 5.1 compilation and whitespace
validation PASS. Exact virtual-clock evidence:

- 41 events at 50 ms intervals (0..2000 ms) cause no intermediate redraw.
  At 2299 ms there is still none; at 2300 ms one render shows the final count
  42, with all 41 evaluated slots represented in its diagnostic sample.
- An isolated event at 3100 ms waits until 3400 ms. Two further updates at
  3500 and 3799 ms produce one render at 4099 ms, not the obsolete 3800 ms
  deadline; manually invoking the canceled ready callback cannot draw.
- A slot event postpones a completed full scan's pending render, and a full
  inventory event restarts an incremental render's quiet period. Neither path
  bypasses the debounce or draws a duplicate incremental result.
- An event during a yielded scan extends its completion's remaining quiet
  period. Existing cancellation, profile/rule/index freshness, synchronous
  callbacks and real FCO notification regressions remain green.

Independent code/test review CLEARED by `bulk-render-corrections-review`
(`bfd6ee81-c0b2-47db-883c-2c8a148cefb6`, turn 3). The reviewer inspected
the production runtime and all four focused regression bodies, relying on
the author's actual test-run results rather than rerunning them. It confirmed
deadline rearming, ready-callback invalidation, next-frame index updates, both
render paths and the active-job deadline extension. Fresh in-game automated/
manual transfer checks remain PENDING. Unboxer UAT remains unavailable, not
covered by synthetic or transfer results.

## Bulk-dump timing investigation (25 November)

At 20:02 UTC Tim reported manual transfers improved, but wanted some progress
during sustained activity. Bulk deposits redrew in one hit only after an
apparently multi-second delay. At 20:10 he clarified the underlying transfers
may actually be sequential rather than instant. Do not infer native-event
timing from perceived UI timing. Tim prioritized measuring the bulk dump
before further manual-transfer/Unboxer tuning and explicitly described periodic
full rescans as musing, not an instruction to implement them.

The DEV diagnostics flushed at 20:10:41 UTC contain a large bank-open batch
completed at 20:09:24: 118 slot evaluations, 25 ms accumulated index-update work
and 3 ms rendering. The evaluation count is consistent with 59 source/destination
pairs, but is not a recorded raw-event count. No full scan is recorded for that
batch. An earlier scan completed at 20:08:34 with 250 ms scan work spread over
2237 ms elapsed time; it must not be attributed to the later batch.

Existing samples timestamp completion only to whole seconds and do not record
individual native inventory callbacks, so they cannot distinguish a long event
stream from a delayed debounce callback or establish the last-event-to-render
gap. Recorded processing cost alone is not total user-visible latency.

Next capture uses three temporary, user-run diagnostic commands: timestamp a
copy of each diagnostic sample with the game millisecond clock, and register
slot/full inventory observers into a `bulkEvents` sample stream. They use the
existing enabled-logging gate and bounded retention, print no per-event chat,
perform no inventory actions and change no scan/debounce timing or addon files.
Reload removes the observers/wrapper and flushes the capture normally. Commands
were compiled/exercised with synthetic callbacks under Lua 5.1, including slot
zero, negative deltas, full events and preservation of caller sample tables.
The event-level capture is now collected and preserved as
[timing evidence](../../../Tests/Evidence/ScanningRefactor-BulkTransfer-20261125.json).
It contains only event/sample metadata, with no item names or account data.

Results from the file flushed at 20:15:03 UTC:

| Phase | Observed slot callbacks | Source decreases / destination increases | Callback span | Median source-update interval |
|---|---:|---:|---:|---:|
| Manual bank-to-bag | 118 | 59 / 59 | 13952 ms | 226 ms |
| Automated bag-to-bank | 118 | 59 / 59 | 12147 ms | 204 ms |

Each phase moved 70 inventory units across those 59 stack transfers. There
were zero full-inventory callbacks and no full-scan samples during capture.
These are observed native callbacks, not timestamps of the other addon's
transfer requests; the trace does not identify which component sets the pace.

For the automated deposit, the longest gap between consecutive callbacks was
264 ms: the stream never became quiet for the configured 300 ms until it
finished. Its final callback was at game time 294998271 ms and its only redraw
sample at 294998587 ms: 316 ms later, including 3 ms rendering. Accumulated
index evaluation was 21 ms for 118 evaluated slots. Thus the captured delay
was a 12.147-second stream of sequential updates followed by approximately
the requested quiet period, not seconds of IC rendering or a full scan.

Manual withdrawals had one callback gap of 386 ms, allowing a redraw near
the end of the sequence; the final redraw followed the last callback by
328 ms. Most events arrived less than 300 ms apart, so a trailing debounce
naturally suppressed progress through most of that sequence as well.

Running the first timestamp-wrapper command twice does not double-record
events: each wrapper delegates once to the previous function. Reload removes
all temporary observers/wrappers. No refresh policy was changed during this
investigation. The data supports considering the original next-frame display
path while retaining the notification fix; it does not justify adding a
periodic full scan. Any policy change awaits author agreement.

## Measured-transfer redraw throttle (25 November)

After reviewing the capture, Tim requested redraws every approximately 333 ms
rather than waiting for quiet. The agreed behavior is an immediate first ready
redraw, at most one inventory redraw per 333 ms during activity, no postponement
by subsequent events, and a final latest-count redraw without another event.
No timer continues once there is no pending display work. Tim explicitly
authorized implementation at 20:24 UTC. This supersedes both timing experiments
above; the notification fix and immediate next-frame slot evaluation remain.

Implementation sequence:

1. In `Tracking\ItemTrackerPanel.lua`, replace the quiet deadline with a
   last-inventory-render timestamp and a 333 ms interval. `ScheduleTrackerRender`
   schedules the first ready request immediately, or the remainder of that
   interval after the last inventory draw. `RenderTrackerDisplayList`, shared
   by completed full scans and incremental draws, records the timestamp before
   drawing. Preserve timer identity, generation, visibility and index checks.
2. `QueueTrackerSlotUpdate` still schedules slot evaluation next-frame and
   records dirty slots, but never rearms display callbacks. Full updates also
   stop setting a quiet deadline. Pending full-scan display owns the draw;
   adoption/replay behavior and scan slice budgets remain unchanged.
3. Keep the timestamp across inventory-triggered cancellation/replacement so
   a new full scan cannot bypass the interval. Reset it on explicit
   non-inventory refreshes, which remain immediate and invalidate stale work.
   No saved-data, listener, banking or notification changes.
4. Revise the existing virtual-clock cases for immediate first/isolated
   changes, exact 333 ms progress during a sustained burst, latest final counts,
   updates just before expiry, no idle redraw loop, shared full/incremental
   cadence and yielded-scan dirty replay. Extend existing stale-callback cases
   without weakening lifecycle or synchronous/reentrant coverage. Run the
   focused tracker/FCO/notification/sliced/index suite and independently review
   the runtime and changed test bodies before asking for the in-game retest.

Independent plan revision review is CLEARED by
`bulk-render-corrections-review` (`bfd6ee81-c0b2-47db-883c-2c8a148cefb6`,
turn 4); the follow-up spec/AC2 review is CLEARED in turn 5. Tim's explicit
implementation instruction covers the agreed revision. The baseline focused
suite passed 83/83. The ten revised timing/lifecycle cases then failed 0/10
against the old debounce, as expected. Implementation follows the reviewed plan.

Post-change validation:

- The focused suite first passed 83/83. An additional explicit-refresh reset
  regression and a slow-scan completion case then brought validation to
  **84/84 PASS** using
  `python Project\Tests\Run-RuleTests.py --test-filter 'Tracker|FCO|notification|Sliced|Incremental|Sparse'`.
- XML structure, all addon Lua 5.1 compilation and scoped whitespace checks PASS.
- Forty-one updates at 0..2000 ms evaluate immediately and render at
  0/333/666/999/1332/1665/1998/2331 ms, showing the latest counts each time.
  All 41 evaluated slots remain represented in diagnostic samples. No extra
  full scan occurs.
- An isolated update at 3100 ms renders immediately. Updates at 3200 and
  3432 ms render together at 3433 ms with the latest count; the latter does not
  postpone the callback. No idle redraw timer remains.
- Full and incremental draws share the interval; changes during a yielded scan
  replay into its completion draw. A scan completing at 800 ms, after the next
  eligible redraw time, renders immediately rather than waiting another interval.
- Explicit settings refresh resets the interval. Existing lifecycle tests now
  also invoke canceled/stale callbacks directly; none overwrites the new view.
  Notification withdrawal/split, synchronous reentrancy, marker polling and
  dirty replay regressions remain green.

Independent source/test review is CLEARED by
`bulk-render-corrections-review` (`bfd6ee81-c0b2-47db-883c-2c8a148cefb6`,
turn 6), which inspected the affected runtime methods and changed test bodies
and found no blocking defect. It relied on the executions reported above,
rather than rerunning the suite.

Automated/manual transfer UAT for this revision remains PENDING. Reload the
UI, test the bulk deposit first for ongoing progress and a prompt final count,
then repeat manual transfers. The virtual-clock results do not substitute for
the author's in-game assessment. Unboxer remains unavailable for a live retest;
this change does not convert it to a pass.

In-game follow-up at 22:07 UTC: Tim reported "that seems to work", but asked
whether closing the bank early had stopped updates until reopening it. Preserve
this as a positive initial timing observation, not completed acceptance of all
transfer cases or proof of the remaining bank count.

The SavedVariables file flushed at 22:06:48 UTC contains
[the close/reopen evidence](../../../Tests/Evidence/ScanningRefactor-BankCloseReopen-20261125.json):

- 22:06:07-22:06:17: 27 incremental redraws, 100 evaluated slots, 25 ms
  accumulated evaluation and 158 ms accumulated rendering. The last redraw
  records the bank as closed.
- 22:06:30-22:06:33: another 10 incremental redraws, 30 evaluated slots,
  6 ms accumulated evaluation and 68 ms accumulated rendering, with the bank
  open throughout. There is an approximately 13-second gap between bursts.
- No full-scan samples or diagnostic events are recorded in this window.
  The second burst is therefore not merely a logged full refresh on reopening.
- Raw inventory observation ended with the earlier capture at 20:14:58;
  reload removed that temporary instrumentation. These newer samples do not
  identify bags, transfer direction, deltas or remaining quantities. Their
  evaluated-slot totals are not item/transfer counts. Incremental work can also
  originate from marker polling, so two processing bursts alone cannot prove
  two transfer batches or how many items remained in the bank.

The timing is consistent with transfers pausing on bank close and resuming on
reopen, but that interpretation remains unconfirmed. The trace does show a
redraw after bank closure; it does not establish a tracker freeze.

## Open questions

None currently. Tim agreed Q7-Q8 on 24 November: Add requires Enabled/ready
FCO, and Add/Remove configure only the selected profile across all its AC
containers. No automatic test setup in other/new profiles.

Resolved decisions do not replace overall plan approval or the separate GO
to start development.

## Agreed delivery scope

- Promote the existing logging framework before wiring scanner callers.
- Preserve the tested prepared/indexed, incremental, time-sliced scan/poll
  algorithms and budgets; do not activate experimental cache variants.
- Enable creates no groups. A temporary Debugging **Add test FCO groups**
  button explicitly creates Deconstruct, Sell to vendor and Sell at guild
  store, non-hidden and included at the top of both AC Priority and Display
  in every container. No bulk generation or marker picker.
- Suspend/Resume preserve configuration; confirmed Turn off deletes dependent
  groups and references account-wide and prevents automatic regeneration.
- Retained inactive groups have explicit pale-grey reasons in all three
  editors, preserving user filters/order/settings and editable controls.
- Settings schema 14, all-profile migration and older-reader refusal remain
  prerequisites for real-data testing. Deferred marker composition/editor
  work is not part of this delivery.

## Current implementation and prior art

Inspected baseline: `383644c`, `spike/fco-itemsaver`.

| Source | Existing mechanism to preserve |
|---|---|
| `Core\Scanning.lua` | `ReadSlot` returns one item record or nil for an empty slot; `GetBagContents` uses it and supports cooperative checkpoints. |
| `Core\FCOItemSaverSpike.lua` | `ValidateFCOReadiness`, `ValidateFCO`, `QueryMarker`, `SupportsMarkers`; four `markerGroups` registered as preloaded `slotMatcher` rules. |
| Same spike module | `CreateMatchingContext` and `GetPreparedMasterItemList` batch selected-marker answers per occupied slot, build marker candidate lists, and return a snapshot plus slot index. |
| Same spike module | `CaptureLiveSnapshot` enumerates FCO's numeric marker range for diagnostics. Production defaults instead reuse only the three fixed marker constants; full-range enumeration is not group creation. |
| `Tracking\ItemDatabase.lua` | `BuildMasterItemList` prepared matching/replay path; `EvaluateTrackerSlot`, `BuildTrackerSnapshotFromSlotIndex`, `GetTrackerContext`, runtime-rule cache and invalidation. |
| `Tracking\ItemTrackerPanel.lua` | `StartSlicedTrackerRefresh`, `QueueTrackerSlotUpdate`, `ApplyTrackerSlotUpdates`, `ApplySlotsToIndex`, `AdoptTrackerSlotIndex`, `NoteTrackerFullInventoryUpdate`, `PollTrackerMarkers`. |
| `Core\Events.lua` | Slot events queue incremental work and retain a 500 ms debounced refresh; DEV full-update listener requests top-ups without discarding the view. |
| `Tracking\EditPanelGroupsTab.lua` / `.xml` | Existing hidden-group handling, rename, Include/Exclude pattern editor, display overrides and built-in reset. No new marker UI needed. |
| `Tracking\AutoCategoryIntegration.lua` | Existing IC predicate, per-area participation/order, explicit failure/Retry Sync and AC item-hash clearing. |
| `Core\DiagnosticLog.lua` | General event/sample API, implemented separately in the [logging plan](<../DiagnosticLogging/002 DiagnosticLogging - Implementation Plan.md>). |

### Working algorithm, not proposed optimization

- `GetPreparedMasterItemList` uses
  `CreateMatchingContext("batched", false, markerIds, false)`: production
  preparation currently caches marker answers, **not** the experimental
  name/pattern caches. Do not enable benchmark alternatives during extraction.
- Snapshot state is `{items, groups, ruleIndex}`. Slot index state includes
  captured bag/slot order, item data, matched rule keys and marker keys.
  Rebuild aggregation preserves source-link/icon ordering and tracked-item
  rescue semantics instead of subtracting/adding mutable totals.
- Full scans yield after clock checks every 16 checkpoints: target 8 ms,
  requested inter-slice delay 10 ms. Completion replays dirty slots and flushes
  pending updates before verification/adoption, then schedules rendering
  separately with `zo_callLater(..., 0)`.
- Marker polling runs from a 1-second registered update, target 2 ms slices
  checked every 8 slots. Its gate uses actual tracker visibility and a
  non-`hud` scene. No scene-list rewrite or FCO marking hooks are required.
- `"inventory"` refreshes are sliced; other refresh reasons currently remain
  synchronous. Slot events do not restart an active top-up. Full updates can
  request one further top-up.

## Technical options and decisions

| ID | Alternatives | Direction |
|---|---|---|
| T1 | Rebuild from the slot index vs incremental arithmetic totals. | Retain the tested slot-index rebuild. Agreed during spike stage 1. |
| T2 | Move existing prepared matching vs introduce a new cache/index design. | Move existing code, preserve contracts and budgets. Tim's scope direction. |
| T3 | Put all production code into one renamed spike vs separate scanner and optional FCO boundary. | AGREED: separate modules. `Tracking\PreparedScanning.lua` owns prepared matching; `Core\FCOItemSaver.lua` owns FCO readiness/registry/API access. Keep tracker scheduling where it is. Tim, 24 November: "separate." Overall plan review/approval and GO remain PENDING. |
| T4 | Automatic defaults vs explicit test-group creation. | AGREED: no groups on Enable. Temporary Debugging Create test groups creates only Deconstruct, Sell to vendor and Sell at guild store using fixed FCO constants, non-hidden and included at the top of AC Priority and Display in every container. No bulk marker registry or universal PvP mapping. Spec D12-D13 supersede earlier automatic/AC-excluded defaults. |
| T5 | Reuse an experimental settings schema vs a distinct production schema. | AGREED: schema 14 for both DEV and release. Tim, 24 November: "14 then". Preserve supported released-settings migrations, including normal schema 11; verify older-reader refusal. Spike settings recovery is excluded by T9. |
| T6 | Register groups during IC startup vs delay initialization or introduce retries. | AGREED: initialize diagnostic logging, register stable FCO built-in identities and available names, then preflight/migrate saved data, construct profiles and initialize AC/tracker. Retain the optional FCO dependency and separate identity from marker readiness. Tim, 24 November: "update the plan then". |
| T7 | Checkbox vs separate lifecycle actions. | AGREED: Enable, Suspend/Resume and confirmed destructive Turn off with Delete/Cancel/Suspend instead. Persist three distinct states; do not regenerate deleted groups until explicit Enable. |
| T8 | Hide inactive configuration rows vs retain them. | AGREED: retain under the existing editor filters/positions, use `#B0B0B0` labels with reasons, preserve interactive controls, and exclude inactive membership from Untracked suppression. |
| T9 | Recover spike groups vs discard throw-away spike data. | AGREED: no spike SavedVariables recovery or PvP/edit/reference migration. Q4 closed as inapplicable. Creation is a separate explicit test action under T4, never an Enable side effect. |
| T10 | Retain/adapt spike diagnostics/tests vs leave experimental tools on the spike branch. | AGREED: retain/adapt production-ready synthetic unit tests and built-in in-game correctness/performance tests, not redesign them. Leave experimental benchmark commands/comparison harness on the preserved spike. Retain the temporary logging-gated DEV/debug priority-change watcher under spec D16. Tim, 24 November: "q5 agreed", following the test-retention clarification. Q5 closed. |
| T11 | Enable/Resume while FCO unavailable vs disable those actions. | AGREED: disable Enable/Resume with an explanation until FCO is installed and ready. Suspend, confirmed Turn off and removal of existing test groups remain usable without FCO. Dependency absence alone does not change saved state or delete groups. Tim, 24 November: "can't enable it if not there. can suspend/remove it at any time". Q6 closed. |

### Startup ordering and FCO readiness

The installed FCO source was inspected on 24 November:

- `FCOItemSaver\FCOIS_Constants.lua:690` defines the marker-range maximum
  during file loading.
- `FCOItemSaver\src\EventsHooks\FCOIS_Events.lua:1119-1254` handles FCO's
  own `EVENT_ADD_ON_LOADED`, loads user settings synchronously and sets
  `gAddonLoaded = true` on successful supported-mode initialization.
- `FCOItemSaver\FCOIS_API.lua:1621` implements `GetIconText`; it accesses
  settings and may return nil. Read names only when the FCO boundary is
  ready, not as a way to force FCO settings to load early.

Keep `FCOItemSaver` in `OptionalDependsOn`, so its normal addon-loaded
initialization precedes IC's. In `Core\Init.lua` `Initialize`, use this order:

1. `DiagnosticLog.Initialize()`.
2. `FCOItemSaver.RegisterBuiltInGroups()`: read raw
   `InventoryCompanion_SavedVariables.Default[account]["$AccountWide"].fcoIntegrationState`
   and each profile's `fcoTestGroupsCreated` before constructors or mutation.
   Missing legacy fields mean Off/false. Validate enums/booleans and reject Off
   with created groups/references. Register the three stable identities only
   if an existing profile (including retained list backups) records creation;
   FCO availability must not affect those identities. Obtain names only when
   ready. New creation occurs only through the Add action.
3. `PrepareSavedVariables()`: validate/migrate all profiles and references.
4. ZOS saved-variable constructors, settings validation and
   `DiagnosticLog.Start()`.
5. Runtime-rule/profile validation, then existing AC and tracker initialization.
6. Start the existing marker-poll timer after tracker initialization.

Group identity does not depend on successful marker reads. With FCO
absent/not ready, preserve recognized saved FCO identities, overrides and
AC references through preflight; do not reinterpret them as custom groups
or normalize away their edits. Report unavailability and keep pure name-only
groups usable. Do not query markers until integration is enabled and the
boundary is ready. Disabled markers remain defined groups, not registration
failures, but their dependent groups are inactive as a whole.

No arbitrary startup delay, `EVENT_PLAYER_ACTIVATED` deferral or new retry
framework is introduced. This establishes normal startup wiring, not a
diagnosis of the earlier unconfirmed AC readiness incident. Regression tests
must exercise successful dependency ordering, absent/not-ready FCO and
saved-identity preservation; inspection is not an in-game test result.

## SavedVariables changes and migration

Runtime index/caches are not persisted. No arbitrary saved `markers` list is
introduced: a built-in's marker comes from its registered baseline, as its
`slotMatcher` does today.

Proposed production identities: `__ic_fco_marker_<id>`. A normal saved built-in
override retains the existing shape:

```text
trackedRules[productionKey] = {
    displayName = optional user name,
    patterns = optional existing Include/Exclude pattern list,
    display = optional ordinary display overrides
}
```

Untouched new baselines need no copied saved definition. Existing profile
copy/normalization code remains responsible for ordinary overrides.

- Add account-wide `fcoIntegrationState` in schema 14, with exactly
  `"off"`, `"enabled"` or `"suspended"` accepted. New installations default
  to `"off"`; supported released-settings migrations also initialize Off.
  Explicit Enable creates no groups and enters Enabled; no spike-group
  state inference or recovery is required.
  Validate the state at load and preserve it across profile copying and
  switching. Do not introduce the earlier proposed boolean; it was not
  implemented and cannot distinguish suspension from permanent removal.
- Read/validate raw lifecycle state before registration, without invoking
  constructors or normalizing profiles. Off suppresses baseline generation;
  preserve metadata/identity validation separately from creating usable
  groups. In a valid Off state, no dependent groups/references may remain:
  reject contradictory saved data explicitly rather than deleting it at load
  or silently recreating groups. Only confirmed Turn off performs deletion.
- Use settings schema **14 in both DEV and release**, agreed by Tim on
  24 November. Preserve existing supported older migration paths and migrate
  normal schema 11 into 14. Spike settings schemas 12/13 are not supported
  recovery sources for this delivery. This is separate from
  diagnostic format 3 (spike formats 1/2 migrate independently).
- Verified source baseline: `main` and published tag `v1.8.1` use settings
  schema 11 and reject newer versions before migration; the spike uses
  release-mode 12 / DEV 13. Actual downgrade tests against those readers
  remain required; source inspection alone is not a test result.
- `PrepareSavedVariables` in `Tracking\ItemDatabase.lua` performs staged
  preflight/migration on every profile and retained list backup before the
  ZOS constructors in `Core\Init.lua`.
  Rewrite its current `SettingsVersion <= 11` migration assertion/whitelist
  and the schema-11 PanelSettings branches, rather than only changing the
  version constant. Preserve supported <=10 migration steps before adding the
  11-to-14 fields; schema 11 needs only additive production changes. Reject
  unsupported spike settings versions 12/13 before any mutation. Test <=10
  and 11 sources, unchanged rejection of 12/13, and actual schema-11 reader
  refusal of 14.
- Do not map or recover spike group keys, edits, marker-17 PvP or their AC
  references. The throw-away spike settings are outside migration scope.
- Add profile-local `fcoTestGroupsCreated` (boolean, absent defaults false).
  Add sets it true only for the selected item-list profile; Remove clears that
  profile's flag/groups/references. Include it in normal explicit list/profile
  copy and retained account-wide list backups, but default false for fresh
  profiles. Turn off clears it across every profile/backup.
  Runtime/editor enumeration must not expose global FCO baselines in profiles
  whose flag is false: make `GetRuntimeRules` resolution profile-aware, including
  candidate-profile validation/copy callers. Keep baseline identities available
  for validation of inactive profiles without leaking groups into other views.
  Reject dependent references inconsistent with the owning profile's flag at
  load. Lifecycle Enabled alone never implies creation.
  Update `ValidateAccountWideListBackup`'s allowed fields,
  `BuildAccountWideListBackup`, RestoreAccountWideListBackup and profile-copy
  paths for this flag. Invalidate runtime rules whenever the flag changes,
  even if the trackedRules table identity is unchanged. Raw preflight walks
  all accounts, account/character profiles and retained list backups without
  mutation, including when a later schema-version check will reject a profile.
- Validate collisions and all migrated references before committing changes.
  Report incompatible/ambiguous data and preserve the original on failure.
- Preserve saved edits when FCO is absent/unavailable; metadata availability
  must not cause custom-group reinterpretation, deletion or validation loss.
  Apply the identity/readiness separation in the startup contract above.
- Test refusal by actual supported older readers without any mutation.

## Data, compatibility, and failure contracts

- Registry keys are stable per marker ID, not derived from translated/custom
  labels. Disabled markers remain registered. Group eligibility is resolved
  before name/marker matching: an FCO-dependent group is wholly inactive
  while suspended or any required marker is unavailable. Off suppresses
  group creation following permanent removal or before first Enable.
  Active scans query only markers required by eligible groups.
- The FCO adapter validates external readiness/API answers. Empty slots are
  unmarked; invalid occupied-slot answers are explicit boundary failures.
  Pure name-pattern groups remain usable when markers are unavailable;
  mixed FCO/name groups must not fall back to their name patterns.
- A slot index is usable only for its captured profile, tracker revision,
  runtime rules, active rule names and marker availability. Existing job
  context checks additionally protect bank/ESO Plus transitions.
- Required internal methods/state are called directly and fail fast.
  Do not add nil guards as substitutes for correct initialization.
- Retain existing synchronous callers and return shapes. Do not make banking,
  notifications or AutoCategory predicate calls asynchronous.
- General events/timings use `DiagnosticLog`; disabled logging must not
  disable scanning or leave required methods owned by the spike.

## Implementation tasks

### Task 0: promote the diagnostic logging framework first

- Depends on: approved Scanning Refactor and Diagnostic Logging documents,
  required independent reviews and separate GO to code.
- Spec coverage: the [Diagnostic Logging specification](<../DiagnosticLogging/001 DiagnosticLogging - Specification.md>);
  prerequisite for Scanning Refactor startup and production diagnostics.
- Promote the working framework from spike commit `383644c`, preserved in
  `16c31c2`, following the [logging implementation plan](<../DiagnosticLogging/002 DiagnosticLogging - Implementation Plan.md>).
  This task is explicitly part of the production delivery, not an assumed
  dependency already present on `main`.
- Files/methods:
  - Add `Core\DiagnosticLog.lua` and its manifest entry after `Core\Utils.lua`;
    declare `InventoryCompanion_Diagnostics` as a saved variable.
  - Promote `defaultsAccount.diagnosticLoggingEnabled` in
    `Core\Constants.lua`, boundary validation in
    `Tracking\ItemDatabase.lua` `PrepareSavedVariables`, and
    `ValidateDiagnosticLoggingSetting` in `Core\Init.lua`.
  - Wire `DiagnosticLog.Initialize` before saved-data preflight and
    `DiagnosticLog.Start` after setting validation, retaining pre-start
    event buffering.
  - Promote the Debugging checkbox and confirmed clear button in
    `Core\Settings.lua`, plus session, synchronous tracker-refresh and
    AutoCategory failure logging at their existing call sites.
  - Port the focused saved-variable/startup, tracker and AC logging tests
    into the existing `Project\Tests` fixtures and runner. Adapt fixtures
    without importing the whole spike module.
  - Implement the logging plan's new Task 4: route complete `/ictest` reports
    (including `copy`, failures and asynchronous performance completion) to
    persistent reports instead of deliberate report-output errors, even with
    background logging off. Preserve complete reports, verbosity and visible
    failures; verify reload/logout persistence and diagnostic-format compatibility.
- Data/preservation: the setting joins the agreed settings schema 14
  migration; use diagnostic format 3 with format-1/2 migration as specified
  in the logging plan.
  Task 0 prepares the framework and uses isolated test fixtures;
  Task 2 owns the combined schema-14 migration/version change. Do not
  deploy/load intermediate task builds against normal saved data. A real-data
  build must include the complete migration, not merely the new log setting.
- Verification: framework API, rolling limits, logging on/off, malformed
  store preservation, early-event buffering, controls and startup tests.
  Re-run the logging plan's acceptance checks on the production code;
  historical spike passes are not fresh production results.

### Task 1: extract the working production scanner and FCO API boundary

- Depends on: Task 0.
- Spec coverage: AC1, AC4, AC8, AC10.
- Files/methods:
  - Create `Core\FCOItemSaver.lua`, exposing `this.FCOItemSaver` with the
    existing readiness/marker availability, single/batched read,
    `GetActiveMarkerIds` and `ReadSlotMarkerKey` contracts.
  - Create `Tracking\PreparedScanning.lua`, exposing
    `this.PreparedScanning.GetPreparedMasterItemList` by moving the working
    preparation/context/capture path out of `Core\FCOItemSaverSpike.lua`.
  - Modify `Tracking\ItemDatabase.lua` `GetMasterItemList` to use that path
    in DEV and release, including a zero-marker/name-only scan. Reuse
    `BuildMasterItemList`, `EvaluateTrackerSlot` and
    `BuildTrackerSnapshotFromSlotIndex`; retain existing test entry points.
  - Update `InventoryCompanion_DEV.txt`: load the FCO adapter after
    `Core\Scanning.lua`, and prepared scanning after
    `Tracking\ItemDatabase.lua`, before tracker use, following agreed T3.
    Preserve optional FCO dependency ordering. Do not import the
    spike module wholesale just to satisfy production callers.
- Contracts/data flow: tracked items + active rules + bag IDs + optional work
  checkpoints produce the same snapshot and captured slot index. FCO calls
  stay behind the adapter; per-scan caches die with their scan.
- Preservation: do not switch to experimental direct/private-storage reads,
  name caches or new matching semantics.
- Verification: run existing prepared/baseline and incremental equivalence
  tests against extracted code; add no-FCO and zero-marker coverage where
  missing. Run the same code in a release-mode fixture.

### Task 2: explicit test-group creation, integration controls and migration

- Depends on: Task 1.
- Spec coverage: AC6-AC9, AC11-AC14.
- Files/methods:
  - `Core\FCOItemSaver.lua`: create `RegisterBuiltInGroups`, using
    `FCOIS_CON_ICON_DECONSTRUCTION`, `FCOIS_CON_ICON_SELL` and
    `FCOIS_CON_ICON_SELL_AT_GUILDSTORE` with the existing per-baseline
    `slotMatcher` approach. Bind each closure to one fixed marker ID.
    Do not generate groups for other defined/enabled/custom markers.
    Preserve saved identities independently of FCO readiness; only read FCO
    metadata when available, following the startup contract above.
    Restore only explicitly created definitions, respecting Off and persisted
    creation data so deleted or never-created groups cannot regenerate.
  - `Core\Init.lua` `Initialize`: call `RegisterBuiltInGroups` immediately
    after `DiagnosticLog.Initialize`, before `PrepareSavedVariables` and
    runtime-rule/AC validation. Keep the optional manifest dependency.
    Start polling later (Task 3).
  - `Tracking\ItemDatabase.lua` `PrepareSavedVariables`: stage/validate the
    migration above; retain `GetRuntimeRules`, existing `UpdateRulePatterns`,
    `UpdateRuleProperty` and built-in reset/display handling.
  - `Core\Init.lua` `SettingsVersion`: complete the schema-14 migration for
    both DEV and release, coordinated with Task 0's new logging setting.
  - `Core\Constants.lua`, `Tracking\ItemDatabase.lua` `PrepareSavedVariables`
    and `Core\Init.lua`: default, validate and normalize account-wide
    `fcoIntegrationState` with the three states and migration above.
  - `Core\Settings.lua`: replace the disabled planned FCO control with
    state-dependent **Enable FCO**, **Suspend FCO** / **Resume FCO**, and
    **Turn off FCO** buttons. Use the spec's destructive confirmation with
    **Yes, delete groups**, **No, cancel**, and **Suspend instead** actions.
    Dialog dismissal is cancellation. Keep state outside copied profiles;
    Disable Enable/Resume with a visible reason while FCO is absent/not ready,
    and enforce that boundary in the state-transition method too. Keep
    Suspend, confirmed Turn off and removal of existing test groups usable
    without FCO; neither dependency loss nor an unavailable enable attempt
    may delete groups or silently change saved lifecycle state.
    Add the temporary **Add test FCO groups** button under Debugging, calling
    a separate proposed `CreateTestGroups()` method in `Core\FCOItemSaver.lua`.
    Disable Add unless integration is Enabled and FCO ready; validate this
    boundary again inside CreateTestGroups. Add/Remove operate only on
    `GetAutoCategoryProfile()` / the selected item-list profile, not every
    existing or future profile. Explicit list copies retain their source data.
    Validate/stage creation and persist explicit creation data before refreshing
    runtime rules, tracker and AC. Create the three non-hidden definitions and
    include their references at the top of both saved Priority and Display
    lists in every supported AC container, preserving unrelated relative order.
    Map Priority to `autoCategoryOrder.contexts[context].matching`, Display to `.display`,
    inclusion to `.hidden`, and preserve `.displayPositions` consistency.
    For newly added references use Deconstruct, Sell to vendor, Sell at guild
    store order. Preserve existing reference positions/hidden choices on
    repeated Add rather than clobbering user edits. AC initialization must
    retain explicit saved placement; later explicit AC Reset/preset actions
    keep their existing intentional reorder semantics, not a forced top rule.
    Reuse existing AC reconciliation/cache invalidation; do not enable AC
    globally. Repeated use must not duplicate groups or overwrite existing edits.
    Missing optional AC must not prevent group creation; saved container
    configuration must be ready for subsequent AC initialization.
    Set all three tracker defaults to Show on, backpack only, grouped and
    Notify off using existing display-setting fields.
    Add **Remove test FCO groups** alongside it, calling a separate proposed
    `RemoveTestGroups()` method. Stage removal of test-created identities and
    all their owned tracking/AC references, registered definitions and creation
    metadata; refresh runtime rules/tracker and reconcile live AC/cache.
    Reuse the relevant owned-reference cleanup from Turn off without changing
    integration state or removing unrelated groups. Clear affected editor
    undo/selection state so it cannot resurrect removed test groups.
    Both buttons use the repository's confirmation-dialog mechanism with the
    effect text in the spec and **Yes** / **No** actions. Call the proposed
    add/remove method only from Yes; No/dismissal must leave saved data, AC
    orders, registered groups and runtime/editor state untouched. Verify both
    cancellation paths and both confirmed actions offline and in-game (AC15).
  - `Core\FCOItemSaver.lua`: propose `SetFCOIntegrationState(state)` for
    Enable/Suspend/Resume, and a distinct `TurnOffFCOIntegration()` for
    confirmed destructive removal. The generic setter must not erase groups.
    Enable from Off changes lifecycle state only, creating no definitions;
    Resume preserves user visibility and other edits.
  - `Tracking\ItemDatabase.lua`: resolve whole-group eligibility before
    matching in prepared scans, one-slot evaluation, tracked-item
    notifications, Untracked browsing and the AC rule predicate. Inactive
    FCO groups cannot match name patterns. Keep editor enumeration separate
    from effective matching, preserving the complete configured rule list.
  - `Tracking\EditPanelGroupsTab.lua`, `Tracking\EditPanelItemsTab.lua` and
    `Tracking\EditPanelAutoCategoryTab.lua`: retain configured rows under
    each view's existing filters/order, render inactive names/prefixes and
    reason suffixes in `#B0B0B0`, and keep permitted controls interactive.
    Inactive styling overrides label colour only, not selection backgrounds.
    Restore normal styling on reactivation and row reuse; never persist
    status suffixes or change hidden/inclusion/Show/Notify flags implicitly.
  - `Tracking\EditPanelItemsTab.lua` `CollectUntrackedItems`: exclude only
    active group matches from Untracked browsing; inactive memberships must
    not conceal otherwise untracked items. Keep independent tracked items
    and matches to other active groups excluded as before.
  - State transitions invalidate affected runtime rules, index and unfinished
    scans/polls, refresh the tracker and reconcile AC using the existing
    assignment/cache-repair path. Suspend/Off perform no marker reads.
    Availability changes use the same eligibility/invalidation contract.
  - `TurnOffFCOIntegration`: enumerate dependent groups across every saved
    account/character profile and retained profile/list backup, stage removal
    of groups/overrides and all IC references in AC Display/Priority, hidden
    maps and remembered positions, and validate preservation before commit.
    Remove registered dependent baselines and owned live AC assignments/
    definitions, persist Off and refresh affected views/caches. Preserve
    unrelated relative ordering, custom/name-only groups and individual items.
    Do not access or modify FCO's marks/settings. Failed validation is explicit
    and must not commit a partial cleanup or success-shaped Off state.
    Do not recreate missing profile definitions during normalization.
    Clear affected in-memory editor selections and undo snapshots as part of
    the successful transition so the current editor visit cannot resurrect
    deleted definitions/references; Cancel leaves these untouched.
- State: the three test baselines have no name patterns, a single marker
  matcher, `isHidden = false`, and tracker defaults Show on, backpack only,
  grouped, Notify off;
  user overrides continue to resolve normally. No bulk range enumeration or
  new marker-selection panel is required.
  Only the explicit test button sets initial AC inclusion/top positions;
  startup and lifecycle actions never create groups or reset AC choices.
- Wiring: registry -> saved preflight -> constructors -> runtime rules ->
  tracker and AC. No arbitrary saved marker lists or marker-picker controls.
  Historical plan: the original three-choice dialog was superseded by the
  two-button confirmation described in the current correction above.
- Preservation/errors: keep disabled definitions, edited labels/patterns,
  explicit visibility and AC orders; reject collisions before mutation.
- Verification: exact three-marker/default-visibility tests, disabled-marker
  inactivity, zero creation on Enable/Resume/login/reload, explicit button
  creation/idempotency, exact top inclusion in Priority and Display for every
  AC container, absent-AC persistence, no extra groups despite many enabled/custom markers, ID-bound
  closure tests, rename/pattern/reset/profile tests, startup order with ready
  FCO, absent/not-ready FCO identity preservation without marker queries,
  and migration/downgrade tests. Add lifecycle default/persistence/profile-copy
  tests, mixed marker/name whole-group inactivity, editor filters/reasons/
  colour reset, Untracked eligibility, no-query assertions and AC
  stale-classification checks on transitions. Test destructive cleanup across
  inactive profiles/backups, cancellation, Suspend instead, absent-FCO removal,
  no automatic regeneration on Enable, explicit test-group recreation and
  preservation of unrelated data.
  Verify all four tracker settings, removal of only test-created groups and
  owned references/cache, unchanged lifecycle state, absence after reload and
  subsequent explicit recreation without duplicate assignments.

### Task 3: enable the existing scheduling paths in production

- Depends on: Task 1 and Task 2's startup wiring.
- Spec coverage: AC1-AC5, AC10-AC12.
- Files/methods:
  - `Tracking\ItemTrackerPanel.lua`: replace spike calls in index validation,
    `StartSlicedTrackerRefresh`, `ApplySlotsToIndex`, `PollTrackerMarkers`,
    and logging with their production owners. Remove DEV/spike gating from
    `RefreshItemTrackerPanel`; keep its reason-dependent behavior.
  - `Core\Events.lua`: make slot queuing and the full-update listener
    production paths, preserving existing listener conditions and debounce.
  - `Core\Init.lua`: initialize the normal scan lifecycle and register the
    existing 1-second marker poll after tracker initialization; keep DEV
    benchmark initialization separate. Use one timer per installation.
    Suspend/Off stop marker polling, not ordinary scanning.
- Flow: slot event -> queue/dirty set -> scheduled slot re-evaluation ->
  rebuild/render; full update -> top-up/rerun; timer -> eligible sliced
  marker pass -> queue changed slots through the same path.
- State/errors: tracker owns jobs/index/pending slots; profile/rule/context
  changes invalidate obsolete work. Preserve cancellation and coroutine
  error propagation, deferred rendering, 8/2 ms budgets and 10 ms delay.
- Verification: reuse next-frame, dirty-replay, full-update, context-change,
  hidden/HUD and poll tests with release-mode fixtures; test without FCO.

### Task 4: separate diagnostics and verify integration boundaries

- Depends on: Tasks 0-3.
- Spec coverage: AC4, AC8, AC10.
- Files/methods:
  - Leave experimental benchmark commands and the comparison harness in
    `Core\FCOItemSaverSpike.lua` on the preserved spike branch. Do not import
    the spike runtime module to satisfy production dependencies.
  - `Tracking\ItemTrackerPanel.lua`: route production timing/mismatch events
    to `DiagnosticLog.Sample` / `Event`. Move shared snapshot comparison out
    of the spike if still needed by normal verification.
  - `Tracking\AutoCategoryIntegration.lua` `Fail` and retry/cache-clear path:
    preserve current failure reporting, empty-slot handling, assignment
    repair and saved Priority/Display separation. No new deferral engine.
    Adapt the spike priority watcher into this production-owned module as a
    temporary DEV-only diagnostic (`this.IsDevelopment == true`), watching
    the explicitly created test groups with existing matching-position accessors.
    Gate before any watcher query on this DEV eligibility and
    `DiagnosticLog.IsEnabled()`. Record a baseline on activation and subsequent
    changes to saved/actual positions with previous/current values and context;
    log mismatches and recovery without repeating unchanged observations.
    Remove the hard-coded Deconstruct-rank-1 requirement. Do not repair orders
    or alert merely because a user legitimately reorders a group. Keep scanner
    completion sampling as the observation point, but separate it from timing
    recording so neither depends on the spike module.
    Reset the in-memory baseline on logging disable/re-enable; the next enabled
    observation records a fresh baseline rather than inventing an unseen change.
  - `Core\Tests.lua`, `Project\Tests\Run-RuleTests.py` and affected existing
    Lua test fixtures: retain and adapt the spike's production-ready synthetic
    unit tests and built-in in-game correctness/performance tests. Update
    references for the production module split and remove spike-only runtime
    dependencies rather than redesigning the tests. Keep synthetic tests
    isolated from live inventory/settings, route reports through the agreed
    test-report history, and add focused cases for newly agreed behavior.
    Rerun against the promoted code; historical passes are not fresh evidence.
- Verification: no normal call requires `FCOItemSaverSpike`; logging on/off
  has identical matching results. Check mark/unmark and AC priority in
  backpack/bank, including Retry Sync. Present findings before fixes outside
  approved scope.
  Add focused AC16 tests for logging-off zero watcher queries/alerts, baseline
  and changed priorities, mismatch/recovery, unchanged-state suppression and
  legitimate user reordering without mutation or a rank-1 requirement.

### Task 5: independent review, acceptance and handoff

- Depends on: Tasks 0-4.
- Spec coverage: AC1-AC16 and the logging specification.
- Independently review the exact production diff and migration against the
  approved documents; discuss findings before changes.
- Run `python Project\Tests\Run-RuleTests.py`, then approved focused in-game
  acceptance with appropriate backups. Synthetic tests never mutate live
  inventory or normal saved data. Older-backup UAT follows release safeguards.
- Update BBCode source manual/changelog to describe delivered behavior, not
  deferred marker UI. Record actual results/limitations before acceptance.
- Keep baseline `383644c` available for rollback/comparison. Do not restore
  newer saved data into an older reader; rollback includes an appropriate
  pre-migration backup.
- Before normal-profile testing, identify and preserve an actual pre-spike
  schema-11 backup, and separately back up the latest spike data/logs.
  Restore only with explicit approval while logged out/at character select
  or with ESO closed, never while a character is logged in. The current
  branch starts at schema 11; do not reload it against schema-13 spike data.
  Once the complete schema-14 migration and downgrade tests pass, use the
  older backup for the approved real-data migration test. Spike 12/13
  settings recovery is not required; do not use throw-away spike settings
  as the production migration source.
- Branch switch, merge to `main`, push and release need their own authorization.

## Verification and acceptance mapping

| Criteria | Tasks | Required evidence | Production result |
|---|---|---|---|
| Logging spec AC1-AC10 | 0, 4, 5 | Re-run logging framework, startup, settings, migration, retained test-report and in-game acceptance checks from the linked logging plan | PENDING |
| AC15 | 2, 5 | Both test-group confirmations: Yes applies the stated action; No/dismissal changes nothing | PENDING |
| AC16 | 4, 5 | Logging-gated DEV/debug priority baseline/change/mismatch/recovery checks, no watcher queries with logging off, no forced rank or mutation | PENDING |
| AC1, AC4 | 1, 3, 4 | Fresh/indexed equivalence, correct ordinary tracking, context isolation, explained mismatch logs | PENDING |
| AC2 | 3 | Next-frame batching, uninterrupted top-up and dirty replay tests; crafting/pickup UAT | PENDING |
| AC3 | 3, 5 | Preserved cooperative budgets/deferred render; comparable before/after heavy-workload logs and smoothness observations | PENDING |
| AC5 | 3 | Marker changes without slot events, visibility/HUD gate, resumed polling | PENDING |
| AC6, AC7 | 2 | No automatic groups; explicit button creates three non-hidden groups at the top of both AC lists in every container; idempotency, unrelated-order preservation and editor/reload tests | PENDING |
| AC8 | 1, 2, 4 | No-FCO/not-ready/disabled marker and empty-slot tests; AC backpack/bank/retry UAT | PENDING |
| AC9 | 0, 2, 5 | All-profile migration including the logging setting, real older-reader refusal, older-backup UAT | PENDING |
| AC10 | 1, 3, 4 | Release-mode tests and manifest/call-site review without spike dependencies | PENDING |
| AC11, AC12 | 2, 3, 4, 5 | Account-wide lifecycle state/actions, profile independence, no FCO reads/polls during Suspend/Off, whole-group inactivity/editor reasons and tracker/AC cache invalidation | PENDING |
| AC13 | 2, 5 | Three-editor visibility/order/filter preservation, pale-grey labels and explicit reasons, interactive controls, reactivation/reused-row styling and Untracked membership checks | PENDING |
| AC14 | 2, 5 | Three-choice destructive confirmation, all-profile/backup cleanup, unrelated-data preservation, no regeneration on reload or Enable, separate explicit test creation | PENDING |

## Independent plan review

Reviewer: independent `design-review` rubber-duck agent, 24 November
Reviewed plan/spec revision and source identity: working documents based on
`69596b0`, preserved spike source `16c31c2`.
Findings: Q7-Q8 required Tim (now agreed); migration whitelist, explicit created-state/raw
startup contract, all-context placement/reset behavior, watcher eligibility
and report-completion ordering require technical clarification.
Resolution: named migration branches, placement mapping/order/preservation,
DEV/logging gating and report ordering corrected in plans. Profile-local
creation data and raw startup/runtime-enumeration contracts now specified.
Focused re-review: independent `focused-design-check` rubber-duck agent,
24 November, PASS for both spec and plan after Q7-Q8 and technical corrections.
Non-blocking implementation reminders: backup whitelist/copy paths; complete
raw-profile enumeration; cross-profile flag isolation/cache invalidation tests;
consistent Add test FCO groups label. Incorporated into implementation scope.

## Approvals

- Explicit spec approval and revision: Tim's conditional approval effective
  after independent focused re-review PASS, 24 November.
- Explicit plan approval and revision: same conditional approval, now effective.
- Explicit GO to production code: conditional authorization from Tim on
  24 November after independent review clears without unresolved decisions.
- Tim authorized the documentation handoff and branch creation on 24 November:
  spike `16c31c2`, main documentation commit `69596b0`, then
  `feature/scanning-refactor`. Tim subsequently authorized independent review,
  autonomous non-product corrections, and implementation if review clears:
  "If it needs me tell me. If it doesnt you are clear to build the first two
  features". Tim agreed Q7-Q8; independent focused re-review passed. Conditional
  GO is satisfied for implementation, not in-game deployment/acceptance.

## Implementation record and historical evidence

Production extraction is implemented on this branch under Tim's conditional
GO. Initial combined offline validation passed 295/295, then 296/296 after a
Craft Bag/FCO regression fix. These counts do not establish completeness:
the first code review found defects and omitted agreed spike regression tests,
which are being corrected/ported before final verification.

Historical spike evidence:

- Stage 1 was authorized on 23 November with disposable DEV saved data.
  The slot-index rebuild replaced arithmetic deltas; offline 336/336 passed.
- Stages 2-3 were authorized together on 23 November, rollback `e4d668b`;
  implemented in `fbe1660`. Offline 337/337 passed. The working implementation
  retained 8 ms slices, 500 ms debounce and a visible non-`hud` poll gate.
- A Tasks 2-3 spike code review found polling used the tracker setting rather
  than actual visibility; Tim approved the fix. That limited review is not
  a review of this production plan.
- Subsequent priority/AC/mismatch/logging work is recorded in spike D41-D45.
  Baseline `383644c` has a recorded 343/343 offline pass.
- Tim, 24 November: the system is "very smooth and faster than it was before
  fco with the new cache/timeslice tecnology". Preserve this observed benefit.
- Crafting/full-update discrepancies were investigated during play; correct
  production results still require AC4 verification, not just smoothness.

## Independent code review and verification

- Production reviewer: independent `production-code-review` agent,
  24 November; uncommitted implementation on base `69596b0`.
- First review: NOT CLEARED. Technical findings (no product decision needed):
  1. Turn off must stage cleanup across uninitialized profiles/backups before
     committing; absent optional item-list data must not cause partial deletion.
  2. AutoCategory completeness validation must respect profile-local test-group
     creation rather than require every globally registered baseline.
  3. Lifecycle/group changes must start/stop marker polling and active work.
  4. Separate lifecycle actions must allow Suspend/Turn off without FCO;
     readiness gating cannot disable their only settings entry point.
  5. Full-inventory event handler must be module-scoped and registered as an
     actual callback, not nested inside the slot-update handler.
- Integration also found Craft Bag capture incorrectly demanding FCO marker
  answers for unsupported bags. Corrected with a mixed-bag regression; supported
  occupied slots must still reject missing/invalid marker answers.
- Omitted production-ready spike scheduler/index regressions must be ported,
  retaining original intent (not replaced by unrelated suite counts).
- Corrections implemented for all five findings; the independent focused
  re-review cleared those five. It identified one additional issue in the
  newly restored third confirmation choice: Suspend instead must be harmless
  when already suspended. `FCOItemSaver.Suspend` now accepts that documented
  idempotent transition, with a real-adapter regression while FCO is absent.
  Final confirmation: independent `production-code-review` agent CLEARED the
  correction and actual schema-11 downgrade test on 24 November; no remaining
  coupled blockers. The reviewer did not execute tests; parent-run evidence is
  recorded below.

### Production UAT preparation, 24 November, 22:02 UTC

- Tim authorized testing ("lets go") and confirmed logged out before backup.
- DEV-only feature acceptance; no release staging or release approval implied.
- `PackageRelease.ps1 -Action Backup` created and SHA-256 verified both
  `SavedVariables\InventoryCompanion-20261124-220243457Z.lua` and
  `SavedVariables\InventoryCompanion_DEV-20261124-220243457Z.lua`.
  Both hashes: `8E44218FA4036DBF0AB68481A1F547AA020D76FD741CB754E8E3CA08F8553320`.
  These private backups are git-ignored.
- The post-logout DEV backup contains actual schema-11 profiles and is the
  migration source already in place; no restore or saved-data edit was needed.
  The released installation and saved data remain untouched.
- First check: load only DEV, observe migration and preserved normal
  configuration, then run `/ictest verbose`. Actual results, persistence after
  reload, and the remaining agreed acceptance checks are PENDING.

### UAT findings, 25 November

- Tim reported lifecycle controls belonged in the existing FCO future-development
  panel. Corrected the implementation to match the approved placeholder-replacement
  requirement: Enable/Suspend/Resume/Turn Off are now under `FCO ItemSaver (planned)`;
  Add/Remove test-group actions remain under Debugging. TTC stays disabled.
  Existing actual-settings regression extended: **1/1 PASS**, all Lua syntax and
  whitespace checks PASS. Independent focused `production-code-review`: CLEARED.
  In-game placement confirmation after reload remains PENDING.
- The persisted format-3 report, sequence 1, has summary **88/89 passed** and
  88 actual PASS lines. Report line 111 was serialized as
  `nil, -- invalid string value (was your string larger than 2000 characters?)`.
  Thus a report was written to disk, but not completely: the failed outcome's
  detail is unavailable from this saved file. Do not treat this as a passed run.
  Report persistence is FAIL; UAT is paused for discussion and correction.
  No live saved-file edits or automatic recovery have been performed.
- Tim also reported all currencies enabled, empty tracker groups shown and
  changed window positions. Inspection found DEV's saved file contained only
  diagnostics while the release-named file contained schema-14 settings.
  Promotion had changed the manifest's space-separated saved-global declaration
  to a comma-separated declaration; the original working spike used spaces.
  Corrected the declaration, with a regression exercising ESO-style load/save
  tokenization and ownership of both globals.
- Tim authorized both fixes, 25 November. Long report lines are now stored as
  consecutive UTF-8-safe chunks of at most 1900 bytes, preserving all text and
  staying below ESO's observed 2000-byte saved-string limit. Report format 3
  and its existing dense `lines` representation remain unchanged.
- Both regressions failed before their fixes; focused post-fix suite:
  **26/26 PASS**; full suite **312/312 PASS**, all addon Lua syntax and whitespace
  checks PASS. Independent re-review and fresh in-game verification are PENDING.
  Do not infer preservation or complete disk persistence from the offline result.
- Tim explicitly confirmed logged out and authorized restoration, 25 November.
  Both current files were preserved and hash-verified at `20261125-082749918Z`
  before the later request not to make further current-file backups.
  Both live installation saves were restored byte-for-byte from the exact
  `FCO-spike-20261121-235630783Z` snapshots: schema 11, 213058 bytes each,
  verified SHA-256 `8D12656937F93B2512EAA3E0E449A100A4187924D71796317F4604160A4BA716`.
- After that restore Tim confirmed DEV positions were back and everything
  looked fine. Tim then authorized isolating DEV's settings global with `_dev`
  and updating staging to remove the suffix for release. DEV now uses
  `InventoryCompanion_SavedVariables_dev`; release keeps its original global.
  `Core\Init.lua` selects the name from the existing development flag, and Stage
  transforms the manifest without changing or staging the installed release.
- Tim confirmed logged out. Converted only the current DEV save's root name
  by inserting four bytes: 250035 to 250039 bytes. Reversing that insertion
  reproduced every original byte, including settings, positions and diagnostics.
  Release save hash remained unchanged by this operation. No data/schema fields
  changed; schema remains 14.
- At Tim's request, created the first isolated-namespace DEV backup:
  `SavedVariables\InventoryCompanion_DEV-SV14-dev-20261125-084739051Z.lua`,
  SHA-256 `B3B03E57C1B9F5A977213FEDFC0912BBB890ADD7FD363EF16EA4C793F3972C11`.
  No release files were copied or modified for this backup. Future script
  backups use explicit DEV/RELEASE labels; old backups are not relabelled.
- Focused namespace/startup preservation tests: **8/8 PASS**, addon Lua syntax
  checked. Executed the actual Stage manifest AST pipeline without staging:
  PASS, release global restored and DEV title/loader removed. Actual backup-label
  expression tested for DEV and RELEASE: PASS. Final full suite **313/313 PASS**,
  addon Lua syntax and whitespace checks PASS. One existing DEV-only slash-test
  fixture needed the new explicit development-mode argument; corrected its caller.
  Independent focused `dev-namespace-review`: CLEARED. Post-rename in-game
  preservation/persistence remain PENDING; release saved-data recovery is outside
  this DEV-only correction and must not be performed without explicit approval.
- Post-rename UAT, 25 November, 08:52 UTC: Tim reported everything looked fine.
  DEV persisted the isolated settings global and a verbose report on logout.
  The oversized failure trace survived as consecutive chunks without serializer
  holes. The run was **88/89 PASS**: Event listener transitions and refresh
  debounce failed (four expected unregistrations, five observed).
- Source inspection identified an unnecessary full-update listener retained by
  non-tracker slot consumers, plus stale in-game debounce assertions.
  Tim explicitly authorized correction. Full updates now depend only on the
  tracker setting; capacity/item consumers retain their four shared slot
  listeners independently. The diagnostic checks full-update identity/code,
  mocks and restores the tracker queue to avoid touching live scan state, and
  verifies one shared currency/progress timer rather than the old tracker timer.
- Extended the existing offline event test to execute the actual in-game
  diagnostic body against production event code and stubbed ESO APIs. The
  full-update demand regression failed before the correction; focused suite
  **4/4 PASS** afterwards, Lua syntax/whitespace and Python syntax PASS.
  Final full suite **313/313 PASS**; independent focused `dev-namespace-review`
  CLEARED the listener/diagnostic correction. In-game rerun remains PENDING.
  No live saved files or inventory were modified by this correction.
- Isolation observation: the release-named save's hash and 08:37 UTC last-write
  timestamp stayed unchanged through the post-rename DEV login, verbose test
  and 08:52 logout. This verifies current installed-build settings isolation.
- Before staging the new logging feature into release, also isolate DEV's
  diagnostic saved-global name: the existing release does not declare diagnostics,
  but the future staged release would otherwise share that second global.
  This publication-safety issue is unresolved; no staging is authorized here.
- Fresh parent-run validation: `python Project\Tests\Run-RuleTests.py`,
  **310/310 PASS**, Lua 5.1, all addon Lua syntax checked; `git diff --check`
  PASS. The runner also has no Python syntax errors per Pylance.
- Actual released `v1.8.1` schema-11 source is exercised against schema-14 data
  in account-wide, inactive-character and other-account locations: rejects
  before constructors or any saved-data mutation. Diagnostic format-1/2
  readers similarly reject format 3 unchanged.
- Retained production regression coverage now exercises slice/yield parity,
  sparse virtual bags, fresh/index equivalence, dirty replay and completion
  flush, cancellation/deferred rendering, full-update coalescing, marker
  polling budgets/visibility/lifecycle, and logging-gated priority changes.
  Experimental comparison/cache/scaling harnesses remain on the spike.
- Listener review: conditional per-bag slot listeners have distinct namespaces
  and bag filters; shared consumers retain ownership until the last consumer
  stops; delayed refreshes cancel/prune stale demand; the visibility ticker and
  marker timer prevent duplicate registrations and follow relevant transitions.
  `EVENT_PLAYER_ACTIVATED` remains always-on for currency-notification
  suppression; the matching addon-loaded callback unregisters after init.
  Code inspection and captured real-implementation registration/filter tests
  support these statements, not actual ESO event delivery.
- In-game observation, actual older-backup migration acceptance and smoothness
  checks remain pending. Non-inventory refresh paths remain synchronous by design.

## Acceptance and handoff

- Approved production in-game test scope: PENDING
- Actual production results and explicit feature acceptance: PENDING
- User docs, archive/index/TODO closeout: PENDING
- Commit/merge authorization and outcome: PENDING
- Release: separate process; not authorized here.
