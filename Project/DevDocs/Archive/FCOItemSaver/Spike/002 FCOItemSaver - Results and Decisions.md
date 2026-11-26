# FCO ItemSaver spike: results and decisions

Archived 2026-11-24 from `spike/fco-itemsaver` at `16c31c2`. Measurements,
approvals and pending checks below are historical spike evidence, not fresh
production acceptance.

Status: DEV spike works in ordinary crafting; responsiveness and FCO readiness follow-ups pending
Branch: `spike/fco-itemsaver`
Updated: 2026-11-23
Governing work list: [step by step](<001 FCOItemSaver - Step by Step.md>)

This record consolidates spike results and decisions from the former report
and checklist. On 24 November the production documents were split into
[Scanning Refactor](<../../../Features/ScanningRefactor/001 ScanningRefactor - Specification.md>)
(backend and hidden single-marker built-ins;
[plan](<../../ScanningRefactor/002 ScanningRefactor - Implementation Plan.md>))
and [FCO Integration](<../../../Features/FCOItemSaver/001 FCOItemSaver - Specification.md>)
(later custom marker conditions and overrides;
[plan](<../../../Features/FCOItemSaver/002 FCOItemSaver - Implementation Plan.md>)).
Historical diagnostic contracts and approvals are summarized below for
reference, not replaced or extended.
They are not fresh approval for the proposed built-in group. Add evidence under
the matching test ID and decisions to the register.

## Results

| Test | Evidence / result | Limitations and next action |
|---|---|---|
| T01 | 20 November 2026: initial backpack scan showed no matching slots. Ten FCO-query passes took 22 ms; baseline iteration measured 0 ms. Watch/stop detected slot 57 changing from false to true, with zero observed backpack slot events. | Marker change was detected by the stop snapshot, not an automatic event. One observation does not cover every FCO path. Occupied-slot count was not visible. Zero is below timer resolution, not zero cost. Do not repeat this as a prerequisite. |
| T02 | Isolated mixed-copy candidate passed offline. Tim reports running the synthetic command; in-game output was not captured. | Candidate-only evidence, not a production tracker regression or real FCO-call timing. On 21 November Tim confirmed marking one item marks all similar items; the live mixed-mark same-ID case is unavailable in this configuration. |
| T03 | On 22 November Tim confirms the proper group works, appears in the group editor and exposes the Bank yes/no toggle. | Setup confirmed in game, not blanket acceptance of all agreed tests or profile/migration preservation checks. |
| T04 | Initial counts looked right visually. Controlled follow-up shows Possessed Shred x2 losing Sell and leaving the vendor group: backpack 100 -> 98, combined 242 -> 240, matching IDs 37 -> 36. | Replacement/removal case verified after manual Debug refresh; broader nonmatch/count checks remain pending. |
| T05 | Tim reports switching off the vendor mark does not update the tracker until something else changes in inventory, and confirms this is expected. | Expected current limitation, not a failed implemented refresh policy. Existing inventory-triggered refresh picks up the changed mark; a marker-only trigger is still to be determined under T13. |
| T06, T08, T13 | No new scene-refresh policy, notification behavior or polling implemented. | These remain later steps; current Debug Key refresh is manual. |
| T09 calibration | Two live runs, six measured pairs. First overhead +7/+10/+17 ms; unchanged repeat +6/+4/+4 ms. All 557 slot rows are identical between runs. | Positive whole-group cost observed, but magnitude varies. Six-pair median +6.5 ms, range +4 to +17 ms; no approved acceptance limit. Not isolated FCO API cost. |
| T09 preparation | Tim supplied the complete 902-line Debug Key report on 22 November. Footer confirms 557 slot rows and 17 enabled markers; parsed detail agrees with all aggregate slot/quantity totals. Enumeration 2 ms, FCO queries/validation 14 ms. | First live snapshot analysed. This is not the paired full-tracker benchmark or evidence for performance limits. |
| T07 | After the bank extension, Tim reports on 22 November: "it all looks good." Bag-specific queries and counts also passed offline tests. | Basic retest accepted as visual evidence, not proof of transfers/stack changes, exact location counts, mark retention or separate subscriber-bank coverage. Housing storage is excluded. |
| T12 | On 22 November Tim reports testing a name pattern in the same group and that it looks good. The implementation uses marker OR name, with offline matching cases passed. | Observed case confirmed; exact patterns/items and numerical results not supplied. Detailed marker-only/name-only/both/neither and duplicate-count edge checks remain pending. |
| T16 | On 22 November Tim reports testing an exclude name pattern in the same group and that it looks good. Offline exclusions veto marker and name routes. | Observed case confirmed; separate live veto checks across marker/name/both routes remain pending. No marker-picker UI added. |
| T10 | On 22 November Tim confirms AC visibility and priority/display ordering work in the backpack. The standard IC predicate passes actual item bag/slot to the shared matcher. | Bank, combined/exclusion and cache/refresh tests remain pending; no switch to AC's native FCO integration has been made. On 23-24 November the deconstruct group failed to beat AC's set/BoE categories on Ja'Vazzir: that character's IC profile had it at backpack matching #28 (bank #1), and AC runs `bag.rules` in array order with the first match winning. Tim moved it back to #1 and it works; he believes it was #1 before. D41 adds a tripwire. On 24 November on Arvani, bank items reverted to their set categories mid-deposit: the tripwire showed every position still at 1, but the integration had failed with "marker query failed (bag 6, slot 159)" because AC asked about a slot just emptied by the deposit, FCO returned nil for it, and a failed integration matches nothing until Resync. After Resync the bank still showed stale categories because AC re-runs rules only when an item's hash (which includes FCO markers) changes or 20 s pass. D42 fixes all three. |
| T11 | Full Lua 5.1 offline suite passed 286/286 after synchronization with main and Debug Key diagnostic wiring. Syntax compilation and `git diff --check` passed. | Historical diagnostic validation, not acceptance of the proposed group. Spike and MVP acceptance remain pending. |

### Historical diagnostic output and workflow (superseded by D25)

- `Core/FCOItemSaverSpike.lua` implements scan, synthetic and marker observation.
  `Core/Tests.lua` appends its output to the DEV Debug Key's copyable error report.
- Historical Debug Key wiring at `e463146`: first invocation ran the synthetic check and, if the default
  guild-store marker is enabled and FCO is ready, scans and starts the watcher.
  The next invocation stops it and reports snapshots/events. Reload ends it.
  Standalone tooling remains available, but the Debug Key no longer starts the
  watcher or prototype automatically.
- The current Debug Key reports the built-in vendor group, matching item IDs
  and backpack/combined quantities and manually refreshes the tracker. Missing/unready
  FCO or a disabled vendor marker is explicitly UNAVAILABLE. Query failures
  are ERROR, not an empty successful result.
- Standalone `/icfcotest scan [markerId]`, `watch [markerId]`, `stop` and
  `synthetic` remain available and print to chat. Future spike checks should
  use the Debug Key/error report as the primary evidence path.
- Debug Key group reporting passed offline tests; a captured in-game report for
  the new group is still absent. In DEV copy reports, the old long generic timing
  run is paused for this first setup step; performance comparison is step 2.
  Standalone non-copy tracker timing remains available.

### Verification and review history

- Before merging main:
  `python Project\Tests\Run-RuleTests.py --test-filter 'FCO spike|Scanning and notifications|Cached synthetic'`
  passed 8/8. After merging main, `python Project\Tests\Run-RuleTests.py`
  passed 286/286, including DEV-only registration checks.
- Initial independent spec reviewer: `spike-spec-review` (`rubber-duck`).
  Reviewed spec blob `1d51c14b9c3b698ef09fe12a1a6d6054309e1980` and provisional
  plan blob `618fd4d553dcf7eb0310f9d244538fecdab30bb8`.
- Independent plan/focused reviewers: `spike-plan-review`,
  `spike-focused-review`, `marker-guard-review`. Resolved findings covered
  packaging, external readiness/return shapes, gamepad safety, marker range,
  disabled-marker storage and reliable before/after item identity.
- Independent code reviewer `fco-spike-code-review` found no significant issues.
  Reviewed runtime blob `acfbcaf4a77d10dcd5d651551d2d2aa7a6ea916d`,
  tests `76b2a399d4693706b315c245db3db58d98ddfc72`,
  runner `797a6891d72726589e5e13af13454b7dabc1370c`,
  manifest `c171a287dd417fc912679bffeddcc9a1bb144027`.
- Follow-up independent `code-review` agent `FCO Debug Key review` assessed
  the Debug Key/watch worktree diff on 21 November 2026; no significant issues.

## Decision register

| ID | Decision / question | State and evidence |
|---|---|---|
| D01 | Keep this spike governed by two documents: expandable steps/tests, and results/decisions, separate from the feature. | Agreed by Tim on 21 November 2026; consolidated into the feature's `Spike` subfolder. Feature spec/plan retained in the parent folder; only spike links updated. |
| D02 | Collect spike checks through the DEV Debug Key and its copyable error report. | Directed by Tim on 21 November; historical transport superseded by D25 for B. Synchronous collectors remain available. |
| D03 | Do not rely on a slot-update event for marker-only changes. Investigate a refresh when returning from inventory to the main scene. | No event observed in T01; scene refresh is a proposal, not implemented. Exact scene coverage remains open. |
| D04 | First test a built-in marker-only group for speed and correctness, then add a name pattern, then test AutoCategory. | Tim directed this sequence and subsequently requested conversion to a proper editable group. It uses normal include-any/exclude-none behavior; AC reuse remains open. |
| D05 | Marker and group name. | Agreed: group **sell to vendor**, using `FCOIS_CON_ICON_SELL` (installed FCO constant 5), not Guild Store (11). |
| D06 | Treat marked/unmarked same-ID copies as synthetic coverage in this configuration. | Tim reports FCO marks all similar items together. Live case unavailable; do not claim synthetic coverage proves production integration. |
| D07 | Preserve per-group quantities and slot-specific matching. | Group-first bookkeeping implemented on main and included in this branch. FCO production matching still required. |
| D08 | Test visible tracker display and notifications with the temporary group. | Proposed noisy group; exact chat/HUD settings and notification semantics OPEN. |
| D09 | Supported locations, bank availability, refresh points, group persistence and unavailable-FCO behavior. | On 22 November Tim authorizes backpack and bank marker matching, including ESO Plus bank; housing chests/furniture vault excluded. Normal saved overrides (schema 12), name-pattern locations and explicit unavailable reporting remain unchanged. Refresh policy remains OPEN. |
| D10 | Measurable full-tracker performance limit and scan count. | OPEN; determine from comparable in-game measurements. Existing API timing is not certification. |
| D11 | Follow-on name pattern and AutoCategory; no marker-writing or transfers. | Tim requested a pattern, then exclusion, then AC checks. Proper-group conversion reuses ordinary include-any/exclude-none matching. AC native-integration reuse versus independence remains OPEN. |
| D12 | Release inclusion of temporary diagnostic code. | Remove or deliberately redesign runtime/manifest/test wiring before release; DEV flag alone is insufficient. |
| D13 | Determine scan triggers through a separate test, including storage scene changes and automatic tagging. | Tim requested T13 on 21 November 2026. Scene change remains a candidate; automatic-tagging/event/API coverage is not established. |
| D14 | Keep the current test plan high-level and distinguish agreed tests from suggestions. | Tim initially requested PENDING beside his tests and PROPOSED beside Copilot's additions; he then agreed all additions on 21 November 2026. They are consolidated into one logically ordered PENDING list. No detailed implementation/test workload is agreed. |
| D15 | After the group is a normal editable group, Tim will add a normal name pattern, then an exclusion. | Requested on 21 November 2026; Tim reports both tested successfully on 22 November. Detailed edge-case and combined AutoCategory checks remain pending. |
| D16 | How should users choose FCO markers in IC's pattern interface? | OPEN. A marker-selection UI is needed; decide its presentation and how marker conditions appear alongside normal patterns and exclusions. No UI design or implementation is agreed yet. |
| D17 | Convert sell to vendor from a tracker-only virtual group to an ordinary built-in group. | Explicitly requested by Tim on 21 November 2026. Make it visible in Manage Groups and the AutoCategory list; use normal persisted name-pattern/exclusion/display overrides. The fixed vendor marker remains built-in until D16 is resolved. |
| D18 | Consider once-per-second polling as a T13 scan-trigger option. | Proposed by Tim: poll only while the item tracker is visible AND the scene is non-standard. Compare with scene-change/event approaches for freshness and cost. This is a test candidate, not an approved polling implementation. |
| D19 | Capture a read-only live inventory/marker snapshot before choosing semi-automatic tests. | Tim explicitly authorizes this on 22 November: Debug Key, results in the existing copyable error. Analyse his returned snapshot before requesting specific item/tag changes; do not inspect the FCO save file or manufacture live inventory. |
| D20 | Make the DEV Debug Key a lightweight FCO runner and add a short paired group-cost comparison. | Tim explicitly authorizes implementation on 22 November: "make the changes and tell me what game actions you need". Keep `/ictest` and release Debug behavior unchanged. No additional item/tag changes are required for this measurement. |
| D21 | Focus on repeated FCO/name work, with Craft Bag included; add decimal tests without renumbering. | Tim agrees and authorizes setup on 22 November. T09.1 compares marker-group scaling/batching; T09.2 tracker name reuse; T09.3 shared per-rule name reuse. These are diagnostic prototypes, not approval to change production matching/caching. |
| D22 | Include no-FCO baseline, current-style naive queries and candidate strategies; test Craft Bag PvP marks. | Tim explicitly requests all three comparison levels and reports marking Craft Bag items with PvP. Diagnostic groups and snapshot now query Craft Bag too; live vendor-group matching is not extended by this test. |
| D23 | Test one group/category for every enabled marker, rather than stopping at five. | Tim explicitly requests the worst case on 22 November. Next run replaces the smaller levels with all enabled IDs (17 in the current capture, not a hard-coded limit). Include marker-only rules in the shared editor/AutoCategory full-sweep model; no saved groups or AC settings changes. |
| D24 | Include combined-tag categories; distinguish checks from matches. | Tim requests combinations and gives GO on 22 November. Add AND probes for each adjacent pair in the sorted enabled-ID list. Evaluate both operands deliberately, even when the first is false, to measure a fixed upper-bound workload. This is not a production short-circuit policy or every possible marker combination. |
| D25 | Record DEV diagnostics in separate saved variables, yielding between passes; never reload automatically. | Tim approves the proposed recording workflow and gives GO on 22 November. B records a run; repeated presses during a run must not overlap it. Completion uses HUD and chat messages saying `reloadui now`; Tim reloads manually. Keep normal profile data untouched and provide an explicit clear command. |
| D26 | Switch B to normal autotests only, retaining the recorded-run transport. | Explicitly requested and authorized by Tim on 22 November after reporting a roughly 60-second stress run. No all-marker workload, live FCO snapshot, optional AutoCategory report or optional tracker benchmark on B. Preserve the normal suite's existing tests/checks and ordinary `/ictest` behavior. |
| D27 | Compare the current best tracker strategy, named `safe`, with direct FCO marker-table reads. | Tim explicitly requests setup on 22 November. Keep B on normal autotests. Use an explicit recorded comparison, without the naive-query workload or full inventory snapshot. |
| D28 | Measure a hypothetical perfect slot/tag cache against `safe`. | Tim explicitly requests setup on 22 November. Populate the cache outside measured scan timers; do not implement or claim a live cache-maintenance policy. |
| D29 | Compare `safe` with tag-list-driven group matching, not merely a reversed lookup table. | Tim corrects the proposed algorithm and explicitly authorizes setup on 22 November: tag OR name inclusion, exclusion vetoes, and virtual tag-heavy/mixed/excluded groups. Preparation is separate; no production cache or saved-rule changes. Whether maintaining a cache is worthwhile remains OPEN. |
| D30 | Measure whole scan-local preparation and matching against a no-FCO baseline. | Tim explicitly authorizes setup on 23 November, then specifies four variants: no FCO, safe, prepare FCO only, prepare names AND FCO. Keep identical groups/name conditions; remove tag conditions for the baseline, leaving tag-only groups empty without dummy patterns. Include all preparation in operation timing; retain no cache between scans. Avoid reintroducing pickup lag; actual pickup-path measurement and a performance budget remain OPEN. |
| D31 | Run heavy and representative checks together with repeated, explicitly reversed order. | Tim authorizes setup on 23 November and asks for all checks in one command. `/icfcodiagnostics checks [pairs]` runs each workload forward and reverse per pair; default one pair means four comparisons/sixteen operations. Order does not depend on saved run IDs. |
| D32 | Include temporary test groups for items to deconstruct and PvP items. | Tim clarifies on 23 November: "just set them up for the test". Use Deconstruction tag 9 and the previously tested PvP dynamic tag 17 in both paired workloads. These are diagnostic-only groups, not live editable built-ins. No saved overrides, schema changes or migration. Disabled markers are reported explicitly and their groups omitted. |
| D33 | Try scan-local FCO-only preparation and four editable built-ins in the DEV spike. | Tim authorizes implementation on 23 November: deconstruction (9), sell to vendor (5), sell at guild store (11), and PvP (his dynamic marker 17), with optional name patterns. Tim subsequently approves schema 13. Tag inclusion uses backpack/bank/subscriber bank; name matching also uses Craft Bag, and exclusions veto either route. This is not a production or release acceptance. |
| D34 | Record actual tracker scan durations during normal play. | Tim requests logging during crafting on alts, 23 November. Automatically record successful DEV prepared tracker scans to the separate diagnostics SavedVariables. No item identities or character names are recorded. Persist on logout or manual `/reloadui`. |
| D35 | Test time-sliced inventory refreshes in DEV and compare the next alt. | Tim authorizes setup on 23 November after reporting stutter. Keep the current alt on the already-loaded synchronous version; the next login loads the sliced version. Inventory changes cancel unfinished work; the previous completed display stays visible until a replacement is ready. This is a spike, not production acceptance. |
| D36 | Increase the slice target from 4 ms to 8 ms; keep the requested 10 ms gap. | Tim reports smoother play but noticeable tracker delay and authorizes tuning on 23 November. The change seeks fewer scheduling gaps without asserting an 8 ms hard maximum. New records include the target and requested delay for comparison. |
| D37 | Investigate faster tracker updates and FCO/AutoCategory startup readiness. | Tim requests these as next test-plan steps on 23 November. Investigate changed-slot updates and batching, and the reported FCO-not-ready initialization failure. Tim reports Retry Sync fixed it, suggesting a temporary readiness/timing issue; deferring FCO-dependent AutoCategory work until FCO is ready is a possible approach, not an agreed fix. FCO is already an optional DEV dependency. Tim considers the current spike in a good place even if work stops here; further implementation and acceptance remain separate decisions. |
| D38 | Incremental tracker updates: retain the sliced top-up scan, add per-slot incremental updates and poll FCO markers while an inventory is open. | Tim agrees the plan on 23 November: instant updates on item moves, quick updates while tagging, never choppy. Adopted refinements: non-restarting top-up with dirty-slot replay, top-up only on specific triggers, marker-only polling, separate-frame rendering, DEV verification. See [T09.11](#t0911-incremental-tracker-updates-agreed-plan). Implementation requires a separate GO. |
| D39 | Build T09.11 stage 1 in the spike branch; consolidate findings into a new feature spec and plan. | Tim gives GO on 23 November: "start the plan and implementation, but mark objective 1 as 'not tested'. then we stay in the spike". Stage 1 rebuilds the snapshot from a per-slot index instead of subtracting and adding counts, so first-source links and icons cannot drift. Offline suite 336/336; in-game NOT TESTED. Stages 2 and 3 keep their in-game gates. The backend documents are now the [Scanning Refactor spec](<../../../Features/ScanningRefactor/001 ScanningRefactor - Specification.md>) and [plan](<../../ScanningRefactor/002 ScanningRefactor - Implementation Plan.md>) following the 24 November split. |
| D40 | Build T09.11 stages 2 and 3 together in the spike branch, with commit `e4d668b` as the rollback point. | Tim, 23 November, before a heavy crafting session: the whole thing may be more stable than stage 1 alone, which pauses incremental updates after full inventory updates. "ok - do it that way. if it goes horribly wrong we roll back to where we were beffore this latest work, and then try again, more slowly with testing". Slot events no longer cancel top-ups, full updates keep the index, and FCO markers are polled once a second outside the HUD scene. Offline suite 337/337; in-game NOT TESTED. |
| D41 | DEV tripwire: on every recorded tracker scan, log the deconstruct group's AC matching position for the backpack and bank (saved IC order, live AC index and run-priority rank) plus the integration status, as an `acPriority` play event at session baseline and on every change; HUD alert when any position is not 1. | Tim, 24 November: "if it moves (for any character) away from #1 in priority (display may change) then we'll know its a bug"; "it should check on every scan. Its cheap". In-memory comparison only, no saved-data schema change. Offline suite 339/339; in-game NOT TESTED. |
| D42 | (1) An empty slot (FCO returns nil and IC's slot read finds no item) is unmarked, not a failure; an occupied slot with no FCO answer still fails. (2) In DEV, every integration failure is also logged as an `acFailure` play event with the reconcile reason, character and traceback lines, plus a HUD alert "AutoCategory sync stopped". (3) Retry and assignment repair clear AC's per-item `AC_hash` in `PLAYER_INVENTORY` slot data so every item re-runs rules on its next sort. | Tim, 24 November: "it didn't really fail loudly did it? yes go". The AC cache clear is an external boundary and is type-guarded; no saved-data schema change. Offline suite 340/340; in-game NOT TESTED. |
| D43 | DEV tracker diff reports now add per-slot detail: for every slot whose grouped contents differ, what the incremental view last read (empty, item/count/groups, or never read), how many incremental reads and how long ago, what the full scan read, and whether the slot changed during the top-up. | 24 November on Ghaz'Narok while crafting: 2 of 216 verified top-ups missed a newly arrived Crafting Rewards item type (121301, 121299), probably writ reward containers; the following top-up corrected the display within about a second. The cause (no slot event vs an incremental read that came too early) cannot be told from item-level diffs. Tim: "yes". Offline suite 340/340; in-game NOT TESTED. |
| D44 | DEV diagnostic logs are rolling: the scan log keeps the newest 2,000 samples and the play-event log the newest 1,000, dropping the oldest (the old stop-when-full alerts are removed). `/icfcodiagnostics clear runs` removes only old benchmark runs. Diagnostics refuse to load unless the add-on is `InventoryCompanion_DEV`: the spike asserts its add-on name, and initialization asserts that ESO loaded the `InventoryCompanion_DEV` folder. | 24 November: the DEV saved-variables file had reached 2.48 MB (1.38 MB scan samples, 0.85 MB from 24 old `/icfcotest` runs). Tim: "yes do that. Also can we only log when the name of the addon matches dev? so that we never log in a release version?" Pre-trim backup kept in the session folder. Offline suite 340/340; in-game NOT TESTED. |
| D45 | Spike logging moves onto the general diagnostic log ([DiagnosticLogging](../../../Features/DiagnosticLogging/001%20DiagnosticLogging%20-%20Specification.md)): play events → `events`, scan samples → `samples.trackerScan` (diagnostic schema 2, migrated automatically from schema 1; benchmark runs stay in the same saved variable). Logging is controlled by the account-wide Enable Diagnostic Logging setting (on by default in DEV) instead of an add-on name check; the load-time `InventoryCompanion_DEV` folder assertion is removed, while the spike keeps its own DEV-name assertion. AutoCategory failures are logged by the integration itself; the spike only adds the HUD alert. | Tim, 24 November: "maybe we don't check the name then. maybe we have a setting 'logging enabled' ... then users could potentially turn it on, and send me their sv file"; "your suggestions seem fine". Older DEV builds refuse diagnostic schema 2 unchanged. Offline suite 343/343; in-game NOT TESTED. |

### T09.10: sliced inventory refresh

**Implemented; 4 ms and 8 ms live captures analysed below. The 8 ms
adjustment passed 91/91 selected offline tests.**
The first 4 ms capture contained 28 attempts: 10 completed, 18 cancelled.
Completed scans reported a maximum slice of 4 ms, 33–46 slices, 1,087–1,725 ms
wall time and 0–2 ms rendering. Tim reported smoother play but noticeable
tracker update delay. Approximate inter-slice waits inferred from wall minus
active time were much longer than the requested 10 ms; actual gaps were not
recorded directly.

On 23 November Tim completed crafting on all alts and reported the 8 ms
configuration still felt smooth and initially that updates were OK; he later
said the tracker delay was a bit annoying. He considers the spike in a good
place if work must stop here. The 8 ms saved samples have not yet been analysed;
this is qualitative feedback, not final responsiveness or correctness acceptance.

DEV inventory-triggered tracker refreshes run the scan-local prepared-FCO
algorithm as a coroutine. Bag traversal (including empty and sparse Craft Bag
slots), tag preparation, matching, aggregation and tracked-item rescue include
cooperative checkpoints. Approximately every 16 checkpoints, the worker
checks whether 8 ms has elapsed in its current slice; if so, it yields and
schedules the next slice after 10 ms. The limit is a target, not a guarantee:
one operation, scheduling and work between checks can exceed it. The existing
500 ms inventory debounce remains in place.

Single-slot and full inventory events cancel an in-progress scan immediately;
the debounced refresh starts over. A changed rules/profile context, bank state
or subscription state also invalidates a job. Completed snapshots alone
replace the displayed rows; the old display remains while work is pending.
Frequent changes can delay completion through repeated cancellations.
Other explicit tracker refreshes (including settings and expansion actions)
still use the synchronous path and cancel any pending sliced refresh.

The diagnostic scan log distinguishes new `algorithm = "sliced"` from
`"synchronous"`; earlier samples have no algorithm field and were synchronous.
Sliced records have `status = "completed"` or `"cancelled"`, total active
`elapsedMs`, `maxSliceMs`, `sliceCount` and `wallMs` including pauses.
New records also report `targetSliceMs = 8` and `requestedDelayMs = 10`;
earlier sliced records without these fields used the 4 ms target.
Completed samples also have `renderMs`: display-list construction and
rendering remain synchronous and are not included in the slice budget.
Cancelled entries may have zero captured entries because a bag read was
interrupted. Logs do not identify characters or inventory triggers.

Once the latest results are saved by logout or `/reloadui`, compare worst slice
and rendering times as well as cumulative work, completion latency and
cancellations. Continue using the disposable DEV saved-data file.

**8 ms capture analysed (saved 23 November 20:24).** 520 attempts: 298
completed, 222 cancelled. Maximum slice 12 ms (median 8 ms); active work
103–264 ms, median 127 ms; 13–34 slices, median 16; render 0–8 ms, median
1.5 ms. Wall time from job start to display was 425 ms–19.3 s, median 550 ms,
excluding the 500 ms debounce. The 19.3 s outlier is unexplained; a loading
screen or pause is plausible but unverified. Rendering runs in the same frame
as the final slice, so that frame may reach roughly slice + render time; the
combined value is not logged. Compared with 4 ms (19 completed, 41 cancelled,
median wall 1,335 ms) the 8 ms target halved latency while staying smooth in
Tim's experience. The 115 synchronous samples ranged 73–133 ms in one frame.

### T09.11: incremental tracker updates (agreed plan)

Tim agreed this direction on 23 November (D38). It is a plan, not yet
implemented; each stage needs Tim's GO and in-game check before the next.

**Model.** Keep the sliced full scan as the authoritative **top-up scan**, add
**incremental slot updates** for instant reaction to item changes, and **poll
FCO markers** while an inventory scene is open to pick up tagging changes,
which produce no slot event (T01).

**Design.**

1. *Slot index.* After a full scan, retain per occupied slot (backpack, bank,
   subscriber bank, Craft Bag): item ID, link, count, matched groups and FCO
   marker set.
2. *Incremental update.* On a single-slot event, subtract the slot's old
   contribution from master items and groups, re-read it, re-evaluate name and
   marker rules for that slot only, and add the new contribution. Remove items
   reaching zero unless individually tracked. Coalesce a burst (stack merges,
   moves) into one apply on the next frame.
3. *Top-up scan does not restart.* Slot events during a running top-up mark
   their slots dirty instead of cancelling; on completion, replace the
   snapshot and re-apply dirty slots. This removes repeated cancellation and
   prevents a stale scan overwriting newer slot data.
4. *Top-up triggers only.* Rule/profile/group changes, ESO Plus or bank-access
   changes, `EVENT_INVENTORY_FULL_UPDATE`, inventory-scene close and initial
   load. Ordinary slot events no longer schedule a full scan.
5. *Marker polling.* While the tracker is visible and an inventory, bank or
   crafting scene is open, periodically re-read FCO markers for backpack and
   bank slots, compare with the slot index and incrementally apply only
   changed slots. Poll work is sliced. Hooking FCO's marking calls is a later
   alternative, not part of this plan.
6. *Rendering.* Render at most once per frame, in a separate frame from the
   final scan slice.
7. *DEV verification.* After each top-up, compare the incremental snapshot it
   replaces with the fresh result and log differences to diagnostics.

**Known limitation.** Which same-ID copy supplies a row's link/icon may differ
from full-scan order until the next top-up.

**Levers and starting values.**

| Lever | Current | Starting value |
|---|---|---|
| Slice budget, user-facing work | 8 ms | 8 ms |
| Slice budget, top-up and polling | 8 ms | 4 ms |
| Clock check interval | every 16 checkpoints | every 8 checkpoints |
| Gap between slices | 10 ms | next frame (user-facing); short gap (top-up) |
| Incremental coalescing | n/a | next frame, at most ~50 ms |
| Top-up debounce | 500 ms after every change | 500 ms–1 s, top-up triggers only |
| Render throttle | after each scan | at most once per frame, separate frame |
| Marker poll interval | n/a | 1 s |
| Marker poll scope | n/a | markers only; backpack and bank |
| Marker poll condition | n/a | tracker visible and inventory/bank/crafting scene open |

**Staged implementation.** (1) slot index, incremental updates and DEV
verification; (2) non-restarting top-up with dirty-slot replay and reduced
triggers; (3) marker polling. Measure worst frame time, update latency, poll
cost and verification differences at each stage.

### T09.9: live spike implementation and timing log

**Implemented; 329/329 offline tests passed. Initial live timing capture
received; correctness and performance acceptance remain pending.**
The first saved capture contained 74 scans from 02:28:42 to 02:35:56 UTC:
median 91 ms, mean 92.6 ms, maximum 133 ms; 18 exceeded 100 ms. Tim reported
stuttering while opening many items. Repeated scans are a plausible contributor,
but these timings exclude rendering and cannot identify the trigger or prove
the cause. More synchronous samples may be recorded before the next login.
The DEV tracker uses the scan-local prepared-tag/group-first matcher after
spike initialization. It captures each bag once, batches available requested
marker answers by slot, constructs group slot lists, matches ordinary compiled
names/exclusions, and replays original scan order for counts and first sources.
No eager name/pattern matrix or cross-scan tag cache is used. Individual
rule matching still uses the established slot matcher. Missing/unavailable FCO
markers are reported; name-based inclusion remains usable. Marker-only
changes still need the existing refresh triggers: event/refresh policy is not
settled by this test.

The four groups are normal DEV built-ins with saved editable name/display
overrides. PvP marker 17 is this user's configured dynamic marker, not a
universal FCO PvP marker. Tracker group marker matching excludes Craft Bag,
as in the prior scoped vendor implementation; name patterns can match there.
The tracker also continues to include individually tracked items.
The older synthetic comparison commands still select only the real vendor
group, plus their own diagnostic probes, and explicitly report that they omit
the other real FCO groups and their name patterns. Use the actual scan log to
measure the current live workload instead.

DEV profile schema is 13; release-mode source retains schema 12 so it rejects
DEV's incompatible data. Migration validates all profiles and new-key collisions
before publishing changes, retaining schema-12 vendor overrides. The offline
tests cover migration, collision rejection, and rejection without mutation
using the current release-mode schema-12 reader, as well as the actual
released schema-11 reader. An actual older-schema SavedVariables backup
migration test remains required before release; the current run is explicitly
against disposable test data. Older DEV builds must not load schema-13 data.

The original synchronous prepared tracker scan appends an entry to
`InventoryCompanion_Diagnostics.samples.trackerScan` (`scanSamples` before
D45): completion timestamp, elapsed
milliseconds, occupied entries, available marker IDs, active group count,
bank-open and ESO Plus state. The measured interval includes readiness, bag
reads, tag preparation, matching and counts; writing the log entry and tracker
rendering are outside it. Timestamps let us order scans; they do not identify
characters or establish whether a scan was specifically triggered by pickup.
The newest 2,000 samples are retained; each new sample drops the oldest beyond
that limit (D44). Samples are written only while Enable Diagnostic Logging is
on (D45). Invalid stored diagnostics
disable recording with a warning and are left unchanged.

For the in-game capture, ensure DEV is using the agreed disposable saved-data
file, then reload to load the new code. No logging command is needed. Normal
logout or `/reloadui` saves samples; a crash or force-quit does not.
Offline evidence does not establish in-game correctness or pickup responsiveness.

### T09.8: paired heavy and representative checks

**Implemented; 76/76 selected offline tests passed. Live runs 7-10 passed;
performance acceptance remains pending.**

Received 23 November after the paired batch and manual reload. All four runs
completed with baseline preservation and both prepared-output checks passed.
Forward/reverse inventory and marker evidence remained stable.

| Run/workload/order | No FCO | Safe | Prepare FCO only | Prepare names + FCO |
|---|---:|---:|---:|---:|
| 7 / heavy / forward | 289 ms | 439 ms (+51.9%) | 301 ms (+4.2%) | 293 ms (+1.4%) |
| 8 / heavy / reverse | 277 ms | 415 ms (+49.8%) | 300 ms (+8.3%) | 307 ms (+10.8%) |
| 9 / representative / forward | 82 ms | 121 ms (+47.6%) | 120 ms (+46.3%) | 117 ms (+42.7%) |
| 10 / representative / reverse | 89 ms | 110 ms (+23.6%) | 94 ms (+5.6%) | 108 ms (+21.3%) |

All times include preparation. Heavy used 62 groups, 17 markers and 1,020
occupied entries. Representative used 23 groups (21 ordinary/vendor plus
two temporary groups), markers 5/9/17 and the same 1,020 entries; FCO queries
covered 557 supported-bag slots. Both requested groups were present:
Deconstruction was empty in this capture; PvP contained 11 item IDs, backpack
quantity 68 and combined supported-bag quantity 439. No-FCO versions were empty.
An empty Deconstruction result does not validate positive live membership;
positive overlap/location cases passed offline.

Pattern execution counts were identical between paired orders for each
strategy/workload. Heavy baseline/safe/FCO-only/names+FCO:
715,251 / 716,667 / 532,123 / 112,404.
Representative: 168,416 / 168,484 / 168,416 / 107,882.
Timing differences therefore do not reflect different recorded matching
workloads within these pairs, but their cause is not isolated.

Interpretation, not an adoption decision: scan-local FCO preparation still
substantially improves heavy matching. Eager name preparation is not a reliable
additional benefit: it saves 8 ms in heavy forward but costs 7 ms in reverse;
representative saves 3 ms forward but costs 14 ms reverse. Recommendation is
FCO-only preparation as the simpler design direction, not unconditional eager
name preparation. Representative FCO-only overhead is +5 to +38 ms
(+5.6% to +46.3%), so these results do not establish negligible cost at light
workloads. Two samples per workload are insufficient to quantify a consistent
order effect. Actual pickup-event/rendering latency remains unmeasured.

Recorded diagnostic elapsed times were 5,915 / 6,866 / 1,555 / 1,317 ms,
including untimed validation/reporting and pauses; these are not individual
scan times. Total measured operations summed to 3,462 ms.

`/icfcodiagnostics checks` runs four recorded comparisons in one batch:

1. Heavy workload, forward: baseline, safe, FCO preparation, names+FCO preparation.
2. Heavy workload, reverse.
3. Representative workload, forward.
4. Representative workload, reverse.

All four algorithms are timed end-to-end in each comparison. Default one
pair means two samples per workload, sixteen total operations. `checks 2`
collects two pairs per workload (eight comparisons). Explicit order is
independent of recorded IDs, so a normal-autotest run cannot defeat reversal.
There are pauses between operations/comparisons and one final manual-reload
notification. Individual measured operations still block the UI.

Heavy checks retain the T09.7 virtual groups and all enabled markers. The
paired suite appends ordinary include patterns in sorted group-key order,
preserving each group's pattern order and the initial six shared probes;
this stabilizes the heavy pattern workload within a batch. Its inclusion
priority may differ from earlier captures built through unordered group
iteration, so retain and compare actual execution counts.

Both workloads also include the temporary "Items to deconstruct" (tag 9) and
"PvP items" (user's dynamic tag 17) groups when those markers are enabled.
They have tag-only inclusion, no dummy name patterns, and use the same
backpack/bank/subscriber-bank tag scope as the vendor group. Their counts
are saved separately as `testGroupResults` for all four algorithms; the
no-FCO versions remain present and empty. During these historical captures,
the temporary groups were not added to the live tracker or persisted.

Representative checks use actual active ordinary/vendor groups plus those two
lightweight test groups: no all-marker, AND or mixed stress groups.
Only the required tags (5/9/17 when their groups are included) are selected.
Tag preparation queries backpack/bank/
subscriber-bank slots, not Craft Bag, while normal name matching still includes
Craft Bag. Safe may avoid a tag query when name inclusion already succeeds.
Compare complete outputs and every tag answer safe actually requested; do not
force extra safe API calls merely to fill a diagnostic answer table.
If neither the actual vendor nor either requested test group is available,
representative evidence is PENDING and the batch stops.

Save each sample as kind `checks`, with configuration workload/forced order,
four measurements, percentages and existing output checks. Across the batch,
verify unchanged profile/rules/enabled markers, captured inventory and relevant
tag answers. Verify each repeated workload has identical selected markers and
virtual pattern definitions. Changes fail explicitly and stop later samples,
retaining completed evidence. All caches remain operation-local.

Validation: `python Project\Tests\Run-RuleTests.py --test-filter
"FCO spike|DEV Debug Key|[Gg]roup|[Ss]cann"` passed 76/76, with Lua 5.1
compilation, XML assertions and `git diff --check` passing. Three new tests cover
forced order even when initial IDs have opposite parity, both workload levels,
needed-tag/bag filtering, name-included safe-query skips, Craft Bag name
semantics, one completion notice, configurable repeats, no mutation, changed
sample rejection and unavailable representative evidence. The added-group
test verifies overlapping counts and supported bags in all three FCO
algorithms, empty no-FCO results and unchanged profiles/live built-ins.

### T09.7: end-to-end preparation with a no-FCO baseline

**Implemented; 73/73 selected offline tests passed. Two live four-way comparisons passed and persisted.**

Saved run 4 (23 November, 00:15 UTC; addon 1.8.2). All three FCO variants'
snapshots and slot/tag answers agreed; baseline name-only preservation and
empty tag-only groups passed. The workload retained 1,020 slots, 17 markers,
60 groups and 172 shared include patterns in each mixed/name-only virtual group.

| Variant | Whole operation | Added over no FCO | Percentage overhead |
|---|---:|---:|---:|
| No FCO | 263 ms | - | - |
| Safe | 412 ms | +149 ms | +56.7% |
| Prepare FCO only | 289 ms | +26 ms | +9.9% |
| Prepare names AND FCO | 281 ms | +18 ms | +6.8% |

Every prepared cost is **included** in these totals. Tag-only preparation
after bag capture took 85 ms; name+tag preparation took 147 ms. Both made
1,020 FCO calls, exclusively in preparation, and captured bags once. Names+FCO
prepared 646 normalized names against 174 distinct patterns: 112,404 actual
pattern executions. Matching used those answers without additional executions.
By comparison, tag-only preparation's matching executed 502,962 patterns;
safe executed 656,951 and the no-FCO baseline 655,535. Names+FCO reduced name
lookups from 1,020 to 766 and normalizations from 1,020 to 646.

Names+FCO saved 131 ms (about 32%) against safe. Most observed timing benefit
was already present with tag preparation: adding name preparation improved
289 -> 281 ms, only 8 ms (about 3%). This single run does not establish that
small extra improvement as stable, despite the large reduction in actual
pattern executions. Preparation was rebuilt inside every operation, so these
results require no maintained cache.

Order: names+FCO, FCO-only preparation, safe, no FCO. Whole diagnostic elapsed
time was 5,853 ms, versus 1,245 ms summed measured operations; untimed harness
checks/reporting and pauses also consume time. Do not treat diagnostic elapsed
time as one scan or attribute the entire difference to pauses.

Percentages above show overall overhead relative to the current no-FCO
baseline, including different admitted-item/group bookkeeping. For prepared
variants they combine FCO additions and matching optimizations, not isolated
FCO API cost. These are stress captures, not ordinary pickup latency, a fixed
performance budget or approval to change production.

Repeat run 6 (23 November, 00:19 UTC; addon 1.8.2) also completed and passed
all three output/baseline checks:

| Variant | Run 4 | Run 6 | Run 6 overhead over no FCO |
|---|---:|---:|---:|
| No FCO | 263 ms | 292 ms | - |
| Safe | 412 ms | 445 ms | +153 ms / +52.4% |
| Prepare FCO only | 289 ms | 298 ms | +6 ms / +2.1% |
| Prepare names AND FCO | 281 ms | 292 ms | 0 ms / 0.0% |

All preparation remains included. Run 6's FCO-only preparation took 81 ms
after bag capture; names+FCO preparation took 150 ms. Whole diagnostic time
was 5,879 ms, versus 1,327 ms summed operations.

The same 60-group/1,020-slot/17-marker stress setup was reported, but actual
pattern workloads differed: safe executed 729,359 patterns and baseline
727,943, versus 656,951/655,535 in run 4. FCO-only matching executed 536,883,
versus 502,962. Names+FCO still executed exactly 112,404 prepared pairs,
although subsequent cached pattern requests increased. Do not describe this
as an identical execution-count workload or attribute all timing differences
to clock noise.

Both captures ran names+FCO, FCO-only preparation, safe, no FCO. Run 5 was
normal autotests (89/89 passed), not a performance repeat; its consumed run ID
means run 6 again used reverse order. Opposite-order live evidence is still
absent.

Across these two captures, safe's overhead was +149/+153 ms; FCO-only
preparation's net overhead +26/+6 ms; names+FCO +18/0 ms. Name preparation
provided only 8/6 ms extra improvement over FCO-only preparation. The broad
benefit repeats, but neither an exact 0% FCO cost nor a stable small name-
preparation advantage is established: optimization gains can offset FCO costs,
and both captures share the same measured order.

Reload the updated DEV code and run `/icfcodiagnostics total` once. Keep
inventory, tags and settings steady through four operations. Wait for
`reloadui now`, reload manually and ask Copilot to read the saved results.
`total 2` optionally repeats with the complete order reversed; begin with one.
B remains normal autotests.

Use the same ordinary/vendor groups, single-tag/AND probes and six virtual
stress groups from T09.6. All four operations have identical group keys,
display names, compiled name includes/exclusions, tracked items and bag scope.

| Variant | Measured operation |
|---|---|
| No FCO (`baseline`) | Current scanner, with every tag/slot condition removed. Zero FCO calls/readiness/tag queries. |
| Safe (`safe`) | Current scanner and batched FCO context, unchanged name-first inclusion and exclusion semantics. |
| Prepare FCO only (`prepared_tags`) | Read bags once, query tags, build tag/group unions/intersections, then indexed matching and normal name checks. |
| Prepare names AND FCO (`prepared`) | Read bags once, query tags/build lists, prepare shared normalized-name/pattern answers, then indexed matching and counting using those answers. |

Tag-only baseline groups remain defined but have no inclusion conditions:
they match nothing. Mixed groups become name-only, retaining exclusions.
Do not substitute `wontmatchanything`: that would add artificial name-pattern
work and would not be guaranteed to miss every external item name.

Implementation and timing:

1. `Core/FCOItemSaverSpike.lua`'s `StartFCOItemSaverTotalComparison()` records
   kind `total`, using the existing scheduler and common T09.6 rule setup.
   `RunScan()` starts the total timer before strategy-specific context/rule
   setup, readiness and bag capture. Shared workload assembly, correctness
   checks, reports, pauses and UI rendering remain outside the operation timer.
2. `Tracking/ItemDatabase.lua`'s
   `GetMasterItemListForPreparedMatchingDiagnostics()` captures each bag only
   once, calls `PrepareGroupSlotLists()` and reuses indexed matching/counting
   and original-order source handling. Both prepared variants include every
   FCO query and group union/intersection construction in their total.
3. For `prepared`, `PrepareNameMatches()` reads/normalizes slot names with
   scan-local link/name sharing, deduplicates all already-compiled include and
   exclude patterns, and evaluates each distinct normalized-name/pattern pair
   once. Matching reads cached true/false answers, never executes another
   pattern match. This is eager preparation and can do unused combinations;
   actual total time, not reduced execution counts alone, decides its value.
   No repeated pattern compilation is introduced.
4. All state is local to each operation. Both prepared variants must make zero
   additional tag queries after preparation; the names+FCO variant must execute
   zero additional regex matches after preparation. Preparation subtimes are
   counters **inside**, never deducted from, the total.
5. Outside timers, compare complete snapshots and all selected slot/tag
   answers for the three FCO variants. Confirm baseline name-only groups are
   unchanged, tag-only groups are empty, and baseline group memberships/counts
   are preserved when adding OR tag conditions. Retain inventory/profile/
   enabled-marker invalidation and explicit error/partial-result recording.

Saved comparison fields: `baselineMs`, `safeMs`, `preparedTagsMs`,
`preparedMs`, `savedMs` (safe minus names+FCO), order, and each FCO variant's
`AddedMs`/`AddedPercent`. Percentage overhead is
`(variant - baseline) / baseline * 100`. If the baseline is below timer
resolution, retain its zero time but leave percentages absent and report why.
Per-strategy virtual group totals are recorded under
`virtualGroupResults[strategy]`.

The safe percentage measures total cost of adding FCO conditions to the
current algorithm, including additional admitted-item/group bookkeeping.
Prepared percentages are the **net effect of FCO plus matching optimizations**
relative to the same current no-FCO baseline, not isolated FCO API costs.
Negative measured overhead is retained, not clamped. These remain instrumented
stress tests, not measurement of the real inventory-event/rendering path or
proof that normal pickup latency has changed.

Focused tests verify four identical group/name workloads, a genuinely marker-
free baseline, empty tag-only groups, preserved mixed-name/exclusion behavior,
single bag capture, inclusion of simulated bag/tag/name/preparation costs,
percentage denominators, complete FCO-output equality, same-ID/cross-bag/
sparse Craft Bag counting, one regex execution per prepared pair, reversed
order, fresh data on subsequent runs, explicit failures and zero-resolution/
missing-name/no-enabled-tag handling. No production matching behavior, scan trigger,
normal saved schema, profile settings or release installation is changed.

Validation: `python Project\Tests\Run-RuleTests.py --test-filter
"FCO spike|DEV Debug Key|[Gg]roup|[Ss]cann"` passed 73/73, including the three
new total-comparison tests and shared scan/notification/group-count regressions.
Lua 5.1 compilation, XML assertions and `git diff --check` passed.

### T09.6: safe versus tag-list-driven group matching

**Implemented; 70/70 selected offline tests passed. First live comparison passed and persisted.**

Saved run 3 (22 November, 23:55 UTC; addon 1.8.2), safe first:
**safe 420 ms; indexed 212 ms**, saving **208 ms (about 50%)** in the measured
scan. Preparation was **92 ms** separately, including 1,020 FCO queries and
tag/group-list construction. Preparation plus indexed scanning was **304 ms**,
116 ms (about 28%) less than safe alone in this capture. Whole recorded-run
elapsed time was 3,213 ms, including both scans, preparation, pauses and
untimed comparison/report work.

All slot/tag evidence, complete group/master quantities, memberships and
first-source links/icons agreed. Workload: 1,020 slots, 17 enabled markers,
21 ordinary/vendor groups, 17 single-tag probes, 16 AND probes and six virtual
stress groups: **60 groups total**. Mixed/name-only virtual groups each used
172 shared include-name patterns.

| Measured work | Safe | Indexed |
|---|---:|---:|
| Logical tag requests | 106,240 | 0 |
| FCO API calls | 1,020 | 0 |
| Name/pattern executions | 708,775 | 516,446 |

Indexed matching traversed 3,364 prepared group/tag-list entries, checked
22,771 other-slot names and processed 4,462 candidates with 538 exclusion
vetoes across the whole workload. It made zero identity-helper or slot-to-tag
cache reads. Name lookups/normalizations remained 1,020 each.

| Virtual group | Matching item IDs | Backpack quantity | Combined quantity |
|---|---:|---:|---:|
| Many tags | 193 | 6,725 | 29,690 |
| Many tags + exclusion | 168 | 6,725 | 29,567 |
| Tags OR names | 274 | 6,859 | 183,680 |
| Tags OR names + exclusion | 249 | 6,859 | 183,557 |
| Tags OR names + two exclusions | 249 | 6,859 | 183,557 |
| Names only + two exclusions | 125 | 5,068 | 167,037 |

The second exclusion (`junk`) made no additional removals in this live
capture; its independent veto behavior is covered offline. This is one
safe-first pair, not a stable timing budget or cache-maintenance acceptance.
The stronger observed benefit includes avoiding tag predicates and skipping
inclusion-name checks on tagged candidates. Do not attribute the entire
208 ms to FCO calls alone, or compare it directly with T09.5's smaller
workload. Whether reliable ongoing caching is worthwhile remains OPEN.

Reload the updated DEV code, then run `/icfcodiagnostics index` once. Keep
inventory, marks and settings steady. Wait for `reloadui now`, reload manually,
then ask Copilot to read the saved results. B remains normal autotests.
`index 2` optionally records a second comparison with reversed order.

Both measured scans receive identical temporary groups. Keep ordinary groups
and the visible vendor group, single-tag probes and adjacent-tag AND probes.
Add these six virtual stress groups, never persisted to a profile:

| Virtual group | Tag inclusion | Name inclusion | Name exclusion |
|---|---|---|---|
| Many tags | OR of every enabled tag | None | None |
| Many tags + exclusion | OR of every enabled tag | None | `writ` |
| Tags OR names | OR of every enabled tag | Shared include patterns | None |
| Tags OR names + exclusion | OR of every enabled tag | Shared include patterns | `writ` |
| Tags OR names + two exclusions | OR of every enabled tag | Shared include patterns | `writ`, `junk` |
| Names only + two exclusions | None | Shared include patterns | `writ`, `junk` |

Shared includes start with Lua patterns `writ`, `ore`, `wood`, `cloth`, `rune`,
`item`, then append ordinary groups' compiled includes. Reuse the same list in
mixed groups to exercise repeated strings and overlapping membership. These
are substring checks, corresponding to wildcard forms such as `*writ*`, not
literal asterisk-containing Lua patterns. Captures record each group's exact
tags/patterns and actual item/quantity totals; exclusion hits and pattern work
are measured, not assumed.

Implementation and measurement sequence:

1. `Core/FCOItemSaverSpike.lua`'s `StartFCOItemSaverIndexComparison()` records
   kind `index` through the existing scheduler. Prepare temporary tag-to-bag/slot
   lists with batched FCO reads, then each group's OR union or AND intersection.
   Deduplicate unions by **bag + slot**, never item ID. Include this preparation
   cost separately, outside the two scan timers.
2. `safe` uses the current scanner and batched tag context with those same rules.
   OR-tag predicates stop at the first match when name inclusion misses, rather
   than inflating safe's work. Existing adjacent AND probes still check both
   operands deliberately, as agreed for that bounded stress workload.
3. `indexed` calls `Tracking/ItemDatabase.lua`'s
   `GetMasterItemListForIndexedMatchingDiagnostics()`. Read current bags, then
   `MatchIndexedGroups()` adds prepared tagged candidates, evaluates name
   includes only for other slots, and applies name exclusions to every
   candidate. No slot-to-tag lookup, FCO predicate or identity-helper call
   occurs in this measured scan. Name-only groups still scan their name inputs.
4. Reuse normal master/group bookkeeping, replaying original bag/slot scan
   order to preserve first-source links/icons. Count each admitted slot once
   in master totals and once in every matching group. Preserve zero-stock
   tracked-item rescue. The real vendor group's tag still excludes Craft Bag;
   diagnostic tag groups intentionally include it.
5. Outside timers, compare complete snapshots and tag-list evidence with safe
   answers. Also compare measured inputs against preparation, and retain
   existing inventory/profile/enabled-marker invalidation. Missing/duplicate
   candidates, changed inputs/tags and API failures must fail explicitly.

The saved comparison records `safeMs`, `indexedMs`, `savedMs`, order,
preparation cost and counters. Indexed counters include tag-list entries,
other-slot name checks, candidates and exclusion vetoes; logical tag requests
must be zero. Group totals are stored in `virtualGroupResults`. This workload
has additional virtual groups: do not compare its raw times directly with
T09.4/T09.5's smaller workload.

This estimates matching benefit given maintained tag/group lists. It does not
solve cache invalidation, price ongoing maintenance/memory, measure display
time or approve a production algorithm.

Validation: `python Project\Tests\Run-RuleTests.py --test-filter
"FCO spike|DEV Debug Key|[Gg]roup|[Ss]cann"` passed 70/70, including shared
scanner/notification/counting regressions. Three focused indexed tests cover
OR union deduplication, AND intersection, name-only inclusion, both exclusion
vetoes, differently marked same-ID copies, overlapping groups, cross-bag and
sparse Craft Bag slots, first-source preservation, zero-stock rescue, all 42
enabled tags, empty lists/missing names, reversed order, zero indexed tag/API
calls, preparation exclusion and explicit stale/missing/duplicate/error
failures. Lua 5.1 compilation, XML assertions and `git diff --check` passed.

### T09.5: safe versus ideal slot/tag cache

**Implemented; 34/34 focused tests passed. First live pair passed and persisted.**

Saved run 2 (22 November, 23:10 UTC), cached first: **safe 216 ms; cached
130 ms**, saving **86 ms (about 40%)** for the measured scan. All slot/tag
answers, full snapshots and probe totals agreed across 1,020 slots and 17
enabled markers. The cached scan made zero FCO API/identity-helper calls,
using 1,020 slot-cache reads; logical name/pattern and marker workloads stayed
unchanged. Cache preparation cost **91 ms** and 1,020 FCO calls outside timers.
Whole recorded-run elapsed time was 2,661 ms, including preparation, both scans,
pauses and comparison/report work.

This supports a possible benefit from an already-maintained cache, not from
rebuilding it before every scan: preparation plus one cached scan was 221 ms
in this capture, versus 216 ms for safe alone. Reuse/incremental maintenance
must be cheaper than the saved scan work. This single cached-first pair does
not establish a stable performance limit or a correct maintenance policy.

After reloading the updated DEV code, run `/icfcodiagnostics cache`.
Keep inventory, marks and settings steady. Wait for `reloadui now`, reload
manually when safe, then ask Copilot to read the saved comparison. B remains
normal autotests; no automatic reload is used.

First populate a temporary bag/slot-to-tag-answer cache using the existing safe
batched API context. This adds one enumeration/query pass with no group matching.
Its setup time, API-call count and occupied-slot count are recorded separately,
**outside the measured scan timers**. This is not free total-run work and is
not a maintained production cache.

Then measure two full tracker scans using identical groups, single/AND probes
and counting:

- `safe`: batched FCO API queries as before.
- `cached`: read prepared answers by bag/slot, with no measured FCO queries,
  identity-helper calls or FCO readiness checks. Normal name matching, logical
  tag checks, group counting and diagnostic instrumentation still run.

Compare every queried slot/tag and complete snapshots/probe totals outside
timers. Missing or stale cache data fails explicitly; changed inventory/profile
context invalidates the run. No direct-storage path, naive workload, editor/AC
sweep or live inventory report is added. Store `safeMs`, `cachedMs`, signed
`savedMs`, cache-preparation details and per-strategy counters in the existing
diagnostic history.

One pause follows preparation and another separates measured scans.
`/icfcodiagnostics cache 2` optionally reverses measured order across two
recorded comparisons; begin with one. The result estimates the benefit of
already-available, correct tag answers. Cache maintenance, update detection,
memory cost and display time are not measured or solved by this test.

Focused tests prove that preparation is separate from measured passes, cached
scans make zero FCO/identity calls, the logical workload and outputs agree,
order reverses, and stale tags/preparation failures are rejected. Existing
Lua 5.1 compilation, XML checks and `git diff --check` passed.

### T09.4: safe versus direct FCO reads

**Implemented; first in-game comparison passed equality and persisted.**

Recorded run 1 (22 November, 23:03 UTC): **safe 186 ms; direct 191 ms**.
All 1,020 slots' queried tags and complete group/item results agreed.
Safe used 1,020 `IsMarked` calls; direct used 1,020 identity-helper calls and
17,340 table reads. Whole recorded-run elapsed time was 2,316 ms, including
pauses and untimed work. Both coarse per-scan wall readings were below the
one-second resolution. This single safe-first comparison shows no direct-read
speed advantage; the 5 ms difference is not sufficient to establish a reliable
regression. Retain `safe` as the preferred candidate for now.

Completion then raised an error because the HUD call used `ShowAlertSmall` on
the addon rather than `Utils.ShowAlertSmall`. The completed comparison and its
passed check were already recorded; Tim's manual reload persisted them.
Corrected the call and the fixture namespace; **8/8 focused completion/routing
tests passed**, with Lua 5.1/XML checks and whitespace validation passing.
No repeat comparison is needed to recover this result. The corrected HUD
notification still needs in-game confirmation.

Run `/icfcodiagnostics compare` after reloading the updated DEV code. Keep
inventory, marks, profile and scene steady; the bank can remain closed.
Wait for the HUD/chat `reloadui now` message, then manually reload when safe
and ask Copilot to read the saved diagnostics. Nothing reloads automatically.
B remains normal autotests only.

One comparison contains **two full tracker scans**, separated by a pause:

- **safe:** batch all requested enabled marker IDs through `FCOIS.IsMarked`
  once per queried bag/slot; no additional name-result cache.
- **direct:** use FCO's exported `MyGetItemInstanceIdNoControl(bag, slot, true)`
  helper once per queried slot to obtain its signed/unique identity, then read
  the active in-memory marker table selected by `GetSavedVarsMarkedItemsTableName`.
  Resolve all requested tags into the same scan-local bag/slot cache.
  An absent entry means unmarked; malformed storage/values or unavailable
  identity helpers fail explicitly. This is an experimental dependency on
  FCO internals, not an alternative public container API.

Both use identical normal groups, individually tracked items, storage traversal,
all enabled single-marker probes and adjacent AND pairs. They share the same
matching/counting implementation and instrumentation. No naive scans, normal-only
calibration, editor/AC sweep or extra live snapshot is included.
Compare every queried slot/tag boolean as well as complete item/group snapshots,
quantities, source data, indexes and probe totals outside the timers. Changed
inputs invalidate the run; mismatches retain partial evidence with failed status.
Neither strategy changes FCO marks or normal saved profiles. FCO's identity
helper may update its existing transient identity cache, as the public API does.

Results store each scan's instrumented milliseconds, coarse wall seconds,
API-call/identity-helper/table-read counters and `safe_direct` check result.
The summary reports safe/direct milliseconds and signed milliseconds saved.
Wall seconds have coarse resolution; printed milliseconds are not yet a
responsiveness guarantee. No performance acceptance limit is implied.
Success means equality, not that direct reads were faster.

`/icfcodiagnostics compare 2` optionally records two comparisons, reversing
safe/direct order between runs using the numbered history IDs. Start with one
comparison, not the old `run` stress command. History clearing remains explicit.

Implementation reuses `ReportMatchingDiagnostics`' private probe construction,
two-scan branch and recorded-run scheduling. Direct lookup is a diagnostic-only
`CreateMatchingContext` strategy; live matching is unchanged. Focused tests
cover negative signed IDs, string identities, same slot numbers in different
bags, Craft Bag, absent marks, exact work counts, reversed order, output equality,
no marks/profile writes, and failed direct reads/mismatches. Existing Lua 5.1
syntax/XML checks and `git diff --check` passed. Real installed-FCO equality and
timing results remain pending; no commit, merge or release was performed.

### Normal-autotest transport refinement

- `Core/Tests.lua`: add an internal collection mode and
  `CollectAutoTestReport()` wrapper around the normal `RunTests` suite with no
  optional flags. Return structured pass/total counts and report lines before
  optional diagnostics or chat/error emission. Normal `/ictest` and release B
  behavior remain unchanged. This does not rewrite the normal suite or remove
  its existing built-in performance checks.
- Reuse the separate diagnostics history, scheduler, completion messages and
  clear/status workflow. Add a run kind (`autotests` or `matching`) and
  `StartAutoTestDiagnostics()` entry point; DEV B selects autotests only.
  The normal suite runs once and stores its report/counts/timing. Failed checks
  remain failed and retain their complete report; no error dialog is required.
  Skip FCO selection, stress scans, snapshots and mixed-state listener setup
  for this kind, because the normal suite manages its own temporary test state.
  Explicit `/icfcodiagnostics run [count]` continues to select matching tests;
  do not use it for the short transport acceptance test.
- Validate normal-result storage and failure handling without any FCO calls;
  update the existing DEV/release routing test. Independently review the bounded
  plan and code. Live completion and persistence remain pending.

Implemented D26: B selects `StartAutoTestDiagnostics`; normal-suite collection
returns counts/report before optional diagnostics or emission. One focused
recording test verifies pass/fail and missing-report cases without FCO available.
**30/30 targeted tests passed**, including DEV/release routing; Lua 5.1 syntax,
XML checks and `git diff --check` passed. A bounded plan check found no blockers.
Tim requested proportionate spike verification rather than reviewing everything.
Normal-autotest transport completion/persistence remains pending in game.

### Algorithm implications of the two all-marker captures

The main specification contains the
[candidate algorithm and pseudocode](<003 FCOItemSaver - Spike Specification.md#best-supported-matching-algorithm-so-far>).

- Prefer scan-local batching of the requested enabled FCO IDs: 49,980 scalar
  API calls/readiness checks became 1,020 batched calls and 17 readiness checks.
  Tracker timings were 567 -> 192 ms and 605 -> 187 ms with identical outputs.
  Query only requested IDs; retain bag/slot identity and reset on every scan.
- Name/pattern reuse is workload-sensitive, not a blanket tracker optimization.
  Normal tracker scans already resolve each slot name once; reuse lowered
  actual pattern executions 167,273 -> 105,950, but combined tracker time
  changed 192 -> 193 ms and 187 -> 203 ms. Current evidence does not justify
  promising a tracker time saving from that extra cache.
- The shared full per-rule sweep repeats name work much more: reuse lowered
  name calls 54,060 -> 766 and batched timings 267 -> 219 ms and 275 -> 228 ms.
  This supports investigating shared scan/sweep-local reuse for editor/AC
  matching, keyed by full link and normalized-name/compiled-pattern pair, with
  false-result caching. Actual UI/AC early-exit lifecycle remains unmeasured.
- Overlapping groups and AND matches agreed across every strategy. Reuse may
  share predicate results, not collapse per-group membership or quantities.
  Keep inclusion/exclusion precedence and all group-specific counting intact.
- The roughly 60-second reported freeze is not explained by the printed
  per-pass figures alone. Investigate wall-clock/report costs before treating
  those timings as responsiveness evidence or adopting any acceptance budget.

### Recorded-run refinement: specification and implementation plan

D25 supersedes the Debug Key/error-copy transport only. Existing synchronous
collectors and `/ictest` remain available; marker/name workloads, production
matching, and normal saved-data schema 12 remain unchanged.

- Declare `InventoryCompanion_Diagnostics` in the DEV manifest only. Initialize
  its independent schema 1 at DEV startup, outside the normal account/character
  profiles. Validate imported history before changing it; reject unknown newer
  schemas without resetting data. An external-data validation failure disables
  recording/clearing and reports its reason, without aborting normal addon
  initialization or modifying the rejected table. Mark imported unfinished runs `interrupted`
  explicitly. No automatic history eviction; clearing removes only run history.
- `Core/FCOItemSaverSpike.lua`: add an asynchronous recorded-run entry point.
  Each run stores a monotonic ID, timestamp, addon version, status, configuration,
  structured measured-pass counters/timings, checks, full text report and
  structured live snapshot. Errors retain partial evidence and a failed status.
  A missing enabled-marker workload is pending, not successful performance proof.
- Reuse `ReportMatchingDiagnostics` with optional recording/pause hooks. Yield
  only outside measured operations, between full scans/per-rule passes and before
  snapshot capture. Drive the coroutine with `zo_callLater`, using
  `coroutine.resume` as the error boundary (Lua 5.1 cannot yield through `pcall`).
  Keep synchronous collectors unchanged. Individual scans still block; elapsed
  whole-run wall time includes pauses, while individual timings do not.
- Invalidate a run if inventory events, rule/profile context, selected markers,
  bank-open state or subscription change between passes. Compare captured
  bag/slot input identities/counts across full scans outside timers as well.
  Stop explicitly rather than reporting mixed-state measurements as valid.
  Register single-slot and full inventory update listeners during each run,
  flag changes and check on every resume; unregister on every terminal status.
  The async sequence calls the matcher directly, never via `TryDebugKeyAction`.
  Per-rule sweeps replay captured inputs; subsequent changes invalidate the
  run's relation to live state, not the deterministic replay itself.
- `Core/Init.lua`: initialize the separate store before enabling the spike;
  DEV B calls the recorded-run entry point and returns without an error dialog.
  An active run rejects extra presses with a chat message rather than queuing.
  `/icfcodiagnostics run [count]` optionally starts a sequential batch;
  `/icfcodiagnostics clear` clears history only when idle; `status` reports the
  active run/history count. Completion/failure emits chat and existing
  `Utils.ShowAlertSmall` HUD notifications with `reloadui now`. Never call `ReloadUI`.
- Extend the existing fixture with a queued scheduler, HUD capture and separate
  save table. Focused tests cover async/sync output parity, exact work counts,
  nonoverlapping repeated presses, appended runs, structured export, clear,
  partial failure, interrupted import, malformed/newer saved data preservation,
  and changes between passes. Independently review this bounded refinement
  before code and again after focused validation.

First all-marker capture (22 November, 10:08 UTC): all three equality checks
passed with 1,020 slots, 17 markers, 16 AND groups and 20 normal groups.
Tracker baseline/naive/batched/batched+names: **83/567/192/193 ms**.
Normal name-reuse scan: **86 ms**. Shared per-rule baseline/naive/batched/
batched+names: **109/528/267/219 ms**. Exact worst-case work: 49,980 tag
checks and 33,660 probe evaluations; batching used 1,020 FCO calls instead
of 49,980. Pattern executions fell 167,273 -> 105,950; this capture did not
show tracker wall-time savings from name reuse. Craft Bag PvP: 2 slots/x3,511.
One AND 7+8 match was present. Output and footer were complete.
The subsequent paste was byte-identical and is not a second measurement.
Tim reports the entire synchronous test made the game unresponsive; server
timeout causation is unproven. This motivates D25, not performance acceptance.
Second all-marker capture (22 November, received during this refinement):
tracker baseline/naive/batched/combined **88/605/187/203 ms**; normal name-reuse
**80 ms**. Per-rule baseline/naive/batched/combined **113/593/275/228 ms**.
All equality checks and both completion footers passed again, with identical
work counts and marker totals. Batching remains promising; tracker name reuse
has not consistently improved the combined timing. No performance budget or
production cache adoption is approved. Asynchronous UX acceptance remains pending.

Recorded-run refinement validation: **29/29 focused tests passed** (28 FCO
spike cases plus DEV/release Debug routing) with real
Lua 5.1 coroutine scheduling, including four new focused behavior cases;
all-addon Lua syntax, existing XML checks and `git diff --check` passed.
Independent `fco-recording-plan-review` found no blockers; its saved-store
disable-state and explicit async/listener-boundary clarifications were included.
Independent `fco-recording-code-review` found no significant issues.
Recorded-run persistence and HUD/chat behavior still require in-game acceptance.
No commit, merge or release was performed.

### Matching-work diagnostics: specification and plan

Run T09.1-T09.3 from the DEV Debug Key instead of repeating the old T09
calibration. Keep the old collector/paired comparison available and `/ictest`
unchanged. Return one generated error report; Tim must not prune it manually.
No new marks, inventory changes, saved groups, UI options or schema are needed.
Production matching uses its existing path unless a diagnostic context is
explicitly passed.

- `Tracking/ItemDatabase.lua`: extend the maintained matcher internals with an
  optional diagnostic context (`GetName`, `NormalizeName`, `MatchPattern`, `OnBagRead`).
  `GetMasterItemListForMatchingDiagnostics` requires that context and reuses the
  actual scan/matching/count pipeline. `ItemMatchesRuntimeRule` accepts the same
  optional context for the per-rule test. Normal callers remain unchanged.
  Insert `OnBagRead` directly after each `GetBagContents` call in the builder;
  do not patch the scanner or claim to count its item-link/icon API calls.
  Record actual bag entries after reading, and perform includes/marker/excludes
  in their existing order. No duplicate matching algorithm or global monkeypatch.
- `Core/FCOItemSaverSpike.lua`: create scan-local counters and optional caches.
  Name lookup cache keys are full item links, never item ID. Pattern cache keys
  are normalized name plus compiled pattern; cached false results are valid.
  Cache normalization by the actual name; count lowercasing requests/calls too.
  Count lookup/comparison requests, executed work, unique keys and reusable
  repeats. Each run starts fresh; no cross-scan or global slot cache.
- T09.1: first measure the no-FCO baseline (current normal groups/tracked items,
  no marker group). Hold those groups/items constant; replace the live
  marker group only in private rule maps with one marker-only group for every
  enabled marker. Enumerate the full FCO range in ID order, without a five-ID
  cap. Report enabled count/range/IDs; mark an empty enabled set PENDING.
  Add one AND rule per adjacent enabled-ID pair, using the same private rule-map
  constructor for tracker and per-rule sweeps. Each AND probe checks both tags
  before combining their booleans; do not silently reduce worst-case work with
  short-circuit queries. Report selected pairs, logical marker checks, actual
  API calls, positive-check events, probe evaluations and successful probes.
  For N enabled IDs and S slots, the fixed maximum is S*(N+2*(N-1)) marker
  requests and S*(2*N-1) probe evaluations when item names are available.
  Do not create saved/editor/AC groups. Compare a per-group query/readiness model
  with one batched requested-ID query cached by bag/slot within the scan, then
  batching plus name reuse. The worst case reports baseline/naive/batched/combined
  timings and actual work. Baseline has zero FCO calls. Naive follows current
  independent per-group query/readiness behavior, not an invented free lookup.
  Check each queried marker boolean and aggregate; never use unqueried false
  entries as evidence. Diagnostic groups include Craft Bag as explicitly
  requested; preserve the live vendor group's backpack/bank/subscriber scope.
- T09.2: compare uncached and cached name work in the real tracker pipeline
  using current normal groups. T09.3: capture a normal-only per-rule baseline,
  then evaluate normal groups plus every enabled marker-only rule through the
  real `ItemMatchesRuntimeRule` entry point in naive, batched and combined modes.
  This is an upper-bound full sweep without category early exits, not actual
  AutoCategory dispatch/UI cost. Do not register temporary categories.
- Maximum five measured full scans (one baseline, three all-marker strategies
  and one normal name-cached scan) and four per-rule passes (normal baseline plus
  three all-marker strategies). Keep the earlier smaller-level captures as
  history, not extra Debug Key work. Timing includes counter/cache overhead and is
  exploratory, not a production performance certification. All full scans and
  per-rule inputs include Craft Bag when subscribed. Print per-bag footprint,
  including Craft Bag. Extend the diagnostic snapshot to query/display its
  marks too, using virtual slot IDs from the existing iterator rather than
  assuming contiguous slots or a finite bag capacity.
- Deep-compare baseline/candidate snapshots and per-slot/rule match results
  outside timers, including group-specific/shared counts and matching metadata.
  Every marker mode must also preserve the baseline's normal groups, their
  source/count/membership/index data, and individually tracked items. Untracked
  shared records may legitimately gain additional copies or an earlier source
  when a probe admits a non-name match; compare those complete records against
  the corresponding naive mode, not an invalid baseline projection.
  Changed context, failed queries or mismatches are explicit ERROR with no
  success footer for the failed test. Report empty/no-duplicate cases honestly.
- `RunFCOItemSaverScalingDebugKey` selects the new test set and reuses the
  snapshot only. It does not run the old vendor refresh/report builds or paired
  scans. `Core/Init.lua` DEV Debug calls it; release and the existing collector
  retain their routing. Both snapshot routes now include subscribed Craft Bag.
- `CreateMatchingContext`: extract shared bag-input recording; `OnBagRead`
  alone increments actual read counters. `SeedCapturedInputs` groups previously
  captured records by bag and seeds fresh marker maps without any scanner call
  or invented bag reads. Seed before per-rule timers; readiness stays timed.
  A shared private rule-map constructor serves tracker and per-rule cases.
  Compare full per-rule results between strategies and normal keys to baseline.
  Keep per-marker slot/quantity totals distinct by bag/slot/marker despite
  repeated requests from AND probes; report each AND probe's matched slots and
  quantities separately. Missing-name per-rule early returns retain existing
  matcher behavior and are not claimed to exercise all marker checks.
- Focused tests cover the complete 42-ID fixture range, exact all-marker query
  counts in tracker and per-rule modes, separate same-slot bags,
  fresh caches per run, duplicate/false name results and item-link variants,
  full Craft Bag footprint, failed/malformed batched results, output equality
  and unchanged profiles. Independently review plan/code before in-game use.
  Tim's actions: reload, change nothing, press Debug Key once and paste all output.

#### All-marker worst-case gate

D23 explicitly authorizes setup; earlier blanket gate approval still applies.
D24's explicit GO covers the combined-tag diagnostic workload too.
Independent `fco-all-markers-plan-review` found no blocking plan issues and
confirmed N+2*(N-1) tag checks and 2*N-1 probe evaluations per named slot.
Implementation and tests now cover the complete 42-ID fixture, both operands
when false, distinct per-marker totals, true/false AND results, small/empty N,
and tracker/shared per-rule equality and exact query counts.
Diagnostic readiness and the read-only snapshot accept nil per-marker storage
as legitimate empty FCO data, following installed `FCOIS_API.lua:693-722`;
malformed non-table storage still fails, and live vendor readiness is unchanged.
Final validation: **27/27 focused tests passed**, all-addon Lua 5.1 compilation
and existing XML checks passed, and `git diff --check` passed.
Independent code reviewer `fco-all-markers-code-review` found no significant
issues in runtime blob `47069bccc6494b2e858a883609398cd590f6fc8f` and test blob
`df26e03d92b174ff261fe1e073138abd62cdf892`.
Ready for the authorized in-game capture; actual all-marker/AND timings and
performance acceptance remain pending. No production cache adoption, saved
groups, AutoCategory registration, schema change, commit or merge.
Disabled markers are not selected: report this scope honestly
and support the full API range whenever those markers are enabled.

### Matching-work implementation and review evidence

- Tim's D21/D22 setup authorization covers these diagnostic prototypes, not
  production cache adoption. No product change or saved-schema change arose.
- Independent plan reviewer `fco-scaling-plan-review` identified the bag-hook
  placement, query-model parity, exact output comparison, virtual capacity,
  cache-key/counter definitions and FCO's existing last-slot cache.
  Resolved technically: hook after the builder's scanner return; separate
  diagnostic callbacks; naive per-query readiness versus timed batched
  once-per-marker readiness; full-link/name+pattern/bag+slot keys; separate
  normalization counters; complete dictionary/index comparison; sparse virtual
  slots and subscriber gating. No scanner patch or production cache was added.
- Implemented the explicit context in the maintained builder/shared matcher.
  Each mode gets fresh counters/caches; cached false comparisons and missing
  names are preserved. Normal calls retain uncached behavior.
- Added five focused regression cases covering the eleven-scan bound, exact
  query counts, per-bag keys, full-link variants, exclusion/false reuse, fresh
  caches, virtual PvP probes/capacity, unsupported marker levels, missing names,
  context changes, malformed queries, count/source/membership/index mismatches
  and immutable settings/inventory. DEV routing and legacy collectors remain
  covered.
- Validation: **26/26 focused tests passed**; **305/305 full offline tests
  passed**, including all-addon Lua 5.1 compilation and the existing XML checks.
  `git diff --check` passed. Full regression is relevant because the optional
  context touches the shared rule engine, not just the DEV runner.
- Independent focused plan-resolution/code reviewer `fco-scaling-code-review`
  identified one verification gap: strategies compared with one another did
  not independently prove preservation of the ordinary baseline. Added
  `AssertBaselinePreserved` outside timers for every marker strategy.
  Normal groups/indexes and normal `matchedRules` must remain exact; tracked
  shared records remain exact after removing only probe memberships.
  Do not require untracked shared quantities/source to equal baseline: added
  marker groups can legitimately admit extra same-ID copies and earlier source
  links. The regression fixture exercises that valid case as well as a common
  normal-count or tracked-count corruption across all strategies.
  **26/26 focused tests passed** after the final correction.
  Independent correction reviewer `fco-scaling-baseline-fix-review` found no
  significant issues. The full review raised no other issue with the technical
  plan resolutions or implementation.
- Reviewed runtime/test blobs: `Core/FCOItemSaverSpike.lua`
  `93391db99726b6224af344fb7fe057d6f83b5d5a`;
  `Tracking/ItemDatabase.lua` `913a3e14d5b3322ad08018b68d785e4cc82a0937`;
  `Core/Init.lua` `17de09ea9406b0805ef117a822892d7b55cd1ef4`;
  `Project/Tests/FCOItemSaverSpikeTests.lua`
  `689db314b5e114405ab8c564682dd4efc9ad4047`;
  `Project/Tests/SavedVariablesTests.lua`
  `82108e5596ebd7781a7710cc04d00ad805922a4a`.
  Ready for the authorized in-game capture; this is not performance acceptance.
- First in-game T09.1/T09.2/T09.3 measurements and live Craft Bag PvP
  verification received below. Repeatability, performance budget and production
  strategy decision remain pending. No commit, merge, push or release authorized.

### First matching-work capture received 2026-11-22 02:51 UTC

Retained [complete capture](../../../../Tests/Evidence/FCO-Scaling-20261122-025148.txt)
is hash-verified against Tim's read-only attachment.

Complete report: `MATCHING DIAGNOSTICS COMPLETE` and `LIVE SNAPSHOT END` both
present; no ERROR or unsupported-level PENDING. All mode-equality checks and
ordinary-baseline preservation checks passed on this inventory. This proves
the tested outputs agree, not performance acceptance or full feature acceptance.

Full scans covered **1,020 occupied entries**: backpack 162, bank 240,
subscriber bank 155, Craft Bag **463**. Bank was closed; ESO Plus was enabled.
The snapshot covered the same 1,020 rows, 993,721 total quantity and 17 enabled
markers. Craft Bag PvP (17) was confirmed on **Blessed Thistle x2,897**
(slot/item 30157) and **Beetle Scuttle x614** (77583), totaling 3,511.

| Diagnostic marker groups | Naive ms / FCO calls | Batched ms / FCO calls | Batched + names ms / FCO calls | Observed batching saving |
|---|---|---|---|---|
| 1 | 110 / 1,020 | 104 / 1,020 | 111 / 1,020 | 6 ms |
| 2 | 126 / 2,040 | 117 / 1,020 | 121 / 1,020 | 9 ms |
| 5 | 139 / 5,100 | 122 / 1,020 | 122 / 1,020 | 17 ms |

No-FCO instrumented baseline was **85 ms**. Naive overhead against that sample
was +25/+41/+54 ms for 1/2/5 groups; batched overhead was +19/+32/+37 ms.
These are single samples, not averages or directly comparable to the earlier
uninstrumented vendor-group calibration. Diagnostic marker groups query every
occupied slot, including Craft Bag, without name-inclusion short circuits.

Naive readiness checks grew with slot/group requests: 1,020/2,040/5,100.
Batched checks were 1/2/5 per scan. One group has the same 1,020 API queries in
both strategies: its observed saving is not query deduplication. With two/five
groups batching halves/reduces by 80% the API calls, but requested marker work
still grows within each array query. FCO's existing last-slot identity cache
also benefits successive naive queries; do not equate API calls with identity
rebuilds or assume batching becomes constant-time for any number of markers.

Name-work evidence:

- Full tracker name lookups: **1,020 -> 766**; normalization executions
  **1,020 -> 646**. Pattern requests remained **167,273**, but actual Lua
  matches fell to **105,950** (61,323 fewer, approximately 36.7%).
- No-FCO name reuse: **85 -> 76 ms**, a 9 ms observed saving.
- In the marker scans, adding name reuse to batching was **7 ms slower** with
  one group, **4 ms slower** with two, and equal with five. Reduced work is
  established; a consistent combined timing benefit is not.
- Captured per-rule sweep: **114 -> 98 ms**; name calls **20,400 -> 766**,
  normalization **20,400 -> 646**, and the same pattern-work reduction.
  This is a 20-rule full sweep over captured inputs, not actual editor/AC
  dispatch, early-exit behavior or UI time.

Next measurement: repeat the current Debug Key once with inventory, settings
and scene unchanged; paste the complete report. No additional marking, bank
visit, code change or production caching is needed. Confirm whether the timing
direction repeats before selecting a strategy; performance budget remains open.

### Historical lightweight Debug Key and paired timing plan

This earlier route is retained through `RunFCOItemSaverSpikeDebugKey(true)`;
the current DEV key selects the matching-work runner described above.

- `Core/Init.lua`, `Debug`: DEV directly collects
  `RunFCOItemSaverSpikeDebugKey(true)` lines and raises their concatenated copyable
  error, bypassing `RunTests`. Release keeps the existing general-suite call.
  Required internal functions are called directly; no fallback to the slow suite.
- `Core/FCOItemSaverSpike.lua`, `ReportVendorComparison`: use the existing real
  `GetMasterItemList` pipeline and `GetTrackerBagIdList`. Capture active tracked
  items/rules once; make a separate rule map omitting only the vendor group.
  Never toggle its actual saved flags, patterns, exclusions or AC state.
- Use **three paired samples, six measured scans**, alternating which variant
  runs first. Initial count is deliberately small based on the measured
  39-41 ms tracker builds. This is calibration, not an approved performance limit.
  Both variants include the same live bags, including craft bag when subscribed.
  Require vendor availability and visibility; failed scans are explicit ERROR,
  hidden group is explicit PENDING. Do not publish success-shaped unavailable
  timings. Detect bank/subscriber context changes across the measured scans.
- Time only `GetMasterItemList`: bag enumeration, rule matching and bookkeeping,
  not display/layout construction, rendering or report formatting. Report each
  pair, with/without min/median/max and paired additional ms/scan, including
  negative/noisy differences without clamping. Explain that omitted-group cost
  includes its normal name patterns/exclusions, not just the FCO API.
- `RunDebugKey` retains the vendor-group/manual-refresh and live snapshot
  sections; add the timing through the existing explicit-error diagnostic
  wrapper only when its optional `includeComparison` argument is true.
  Existing `/ictest` calls omit that argument, preserving their current work.
  The full suite and 3,000-iteration benchmark do not run from DEV
  Debug. Existing snapshot/refresh scans are additional to the six timed scans.
  Clarify the closed-bank message: report exposed contents without requiring an
  unnecessary trip to the bank.
- `Project/Tests/FCOItemSaverSpikeTests.lua`: verify exactly six measured calls
  in alternating order, unchanged actual rules/settings, realistic timer
  arithmetic, unavailable/hidden/failed comparison behavior and preserved
  snapshot output. `Project/Tests/SavedVariablesTests.lua`: exercise the actual
  DEV/release Debug routing and copyable error, proving DEV never calls RunTests.
- Independent focused spec/plan and code review plus focused Lua 5.1 tests
  precede handoff. In-game actions: reload, keep inventory/settings/scene steady,
  press Debug Key once and return the complete report. Bank may remain closed.
  Performance acceptance and broader automatic edge checks remain pending.

### Lightweight runner verification

- Independent `fco-lightweight-timing-plan-review` approved the focused
  spec/plan. Its `/ictest` call-site observation is addressed by an explicit
  comparison argument passed only by DEV Debug. Required internal helpers
  remain direct fail-fast calls, not optional fallbacks.
- `python Project\Tests\Run-RuleTests.py --test-filter "FCO spike|DEV Debug Key|AutoCategory passes item bag and slot|untracked rows exclude IDs"`
  passed **21/21**; all addon Lua sources compiled as Lua 5.1 and
  `git diff --check` passed. Tests verify actual Debug routing, six measured
  scans in alternating order, unchanged settings/rules, negative differences,
  failed/hidden/unavailable/context-changed measurements and retained snapshots.
- Independent `fco-lightweight-timing-code-review` found no significant issues.
- In-game measurements remain pending. Reload, leave inventory/settings/scene
  steady, press Debug once and provide its complete error report. Bank opening
  and additional marking are unnecessary. No commit, merge or push.

### First paired live timing result

Tim's 22 November report has 676 lines and both `PAIRED TIMING COMPLETE` and
`LIVE SNAPSHOT END`. The lightweight FCO-only header is present; no general
suite output appears.

| Pair / first variant | Group included | Group omitted | Additional per scan |
|---|---:|---:|---:|
| 1 / included | 43 ms | 36 ms | +7 ms |
| 2 / omitted | 46 ms | 36 ms | +10 ms |
| 3 / included | 65 ms | 48 ms | +17 ms |

Included median is 46 ms, omitted median 36 ms, paired-difference median
**+10 ms** (about **28%** of the median baseline). Six measured scans total
274 ms. Both sides of pair 3 are slower; the cause is not established and the
small sample does not certify a stable overhead or acceptance threshold.
This measures the entire added group, including name-pattern/exclusion matching
and bookkeeping, not only `FCOIS.IsMarked`.

The snapshot remains 557 slots, quantity 26,357, 17 enabled markers and 12
multi-marker slots; bank closed and ESO Plus active. Compared every slot row
with the preceding capture: only Possessed Shred x2 changes `[17] -> []`,
confirming Tim's cleanup. All other 556 slot rows are unchanged. Vendor group
backpack/combined quantities stay **98/240**. Snapshot enumeration is 3 ms,
FCO query/validation 15 ms.

The requested unchanged repeat is recorded below. Tim should provide the entire
generated report, never manually prune it; extract relevant lines during analysis.
Performance acceptance and broader edge cases stay pending.

### Unchanged repeat: second paired live timing result

Tim supplied the complete 676-line repeat report on 22 November. Both completion
footers are present. All 557 slot-detail lines are identical to the first paired
run, including no marks on Possessed Shred. Vendor group quantities remain 98
backpack / 240 combined; bank closed and ESO Plus active.

| Pair / first variant | Group included | Group omitted | Additional per scan |
|---|---:|---:|---:|
| 1 / included | 39 ms | 33 ms | +6 ms |
| 2 / omitted | 35 ms | 31 ms | +4 ms |
| 3 / included | 38 ms | 34 ms | +4 ms |

Repeat included min/median/max is 35/38/39 ms, omitted 31/33/34 ms, and paired
differences 4/4/6 ms. The paired-difference median is **+4 ms**; it is not the
difference of the independently calculated medians (38 - 33 = 5 ms).
Across both runs the six paired differences have median **+6.5 ms**, range
**+4 to +17 ms**. The group adds measurable cost, but the first run's +10 ms
median is not a stable certified estimate. The cause of run-to-run variation
is unproven. Snapshot enumeration/query timing is 2/12 ms.

This completes the initial unchanged repeat; no further identical dump is
needed merely for this calibration. Performance acceptance remains pending
without an agreed budget. Existing stacks, marker combinations and normal
patterns/exclusions can support the next correctness checks without new marks.

### Live snapshot: agreed scope and implementation plan

This is preparation for T09 and the detailed edge checks, not a performance
pass/fail benchmark. Add the snapshot to the existing DEV Debug Key report;
keep the current vendor-group report/manual refresh and standalone commands.
Capture backpack, bank and subscriber-bank slots exposed by ZOS, not housing
or craft-bag slots. Report bank-open/subscriber context and warn that closed-bank
results do not certify complete bank inventory.

- `Core/FCOItemSaverSpike.lua`: extract common FCO readiness validation from
  `ValidateFCO`; preserve its per-marker enable/storage checks. Enumerate
  enabled IDs in numeric order and validate each once before querying slots.
  Disabled markers are not queried. Require `GetIconText`; its documented nil
  result means no custom label, reported explicitly alongside the numeric ID.
- Reuse `QueryMarker` for one FCO query per occupied slot with the enabled-ID
  array. Return its marker table as well as the existing boolean, validate
  queried entries as booleans and check agreement with the aggregate result.
  Invalid/failed results are explicit errors, never unmarked successful slots.
- `CaptureLiveSnapshot` collects scanner results and separate snapshot records
  without changing inventory, marks, profiles or scanner records. Sort by
  bag/slot. Accumulate per-bag occupied slots/quantities, per-marker slot and
  quantity totals per location, multi-marker slots and same-ID copies crossing
  locations. Include every occupied slot (also unmarked ones), item ID/name,
  quantity and numeric marker combination so follow-up instructions can name
  actual items. No output cap or silent omission; print an end/count footer.
- `ReportLiveSnapshot` formats the captured data after measuring enumeration
  and FCO-query phases separately. Timings cover one live pass, not the complete
  tracker pipeline or report formatting; zero is below clock resolution.
  Empty bags and no enabled markers are explicit legitimate results.
- `RunDebugKey` invokes the snapshot through `TryDebugKeyAction`, independently
  of vendor visibility/readiness. Snapshot failures retain explicit ERROR output
  and do not conceal the existing report. No automatic marking or transfers,
  new refresh policy, saved schema, new files, commit or push.
- Extend `Project/Tests/FCOItemSaverSpikeTests.lua` with API/metadata stubs and
  focused cases: enabled/disabled and multi-marker counts, unmarked slots,
  same IDs across bags, empty data, vendor-disabled snapshot, malformed results,
  repeatability and unchanged source inventory/settings. Existing scan/watch
  tests must still prove their backpack-only behavior.
- Independent focused spec/plan review, offline tests and code review precede
  Tim's capture. Analyse only his returned report; follow-up item/tag requests
  and performance limits remain pending.

### Live snapshot verification

- Independent `fco-live-snapshot-plan-review` approved the focused spec/plan
  against the installed FCO API. Technical notes are reflected in enabled-only
  wording, explicit bag/slot query failures, summary-first output, count/footer
  completeness checks and separate query/validation timing.
- `python Project\Tests\Run-RuleTests.py --test-filter "FCO spike|AutoCategory passes item bag and slot|untracked rows exclude IDs"`
  passed **18/18**; all addon sources compiled as Lua 5.1 and
  `git diff --check` passed. Tests include read-only source/settings/storage
  comparisons and unchanged-data repeatability.
- Independent `fco-live-snapshot-code-review` found no significant issues.
- Initial live-capture handoff requested a report including `LIVE SNAPSHOT END`.
  Subsequent received captures and analysis are recorded below; the observed
  bank-closed data removes the need for that initial bank-opening instruction.

### First live snapshot and selected next case

Source: Tim's pasted Debug Key report, 22 November 2026 (902 lines). The complete
snapshot ends with 557 slot rows and 17 enabled markers. Parsed every slot row:
557 distinct bag/slot pairs, quantity 26,357, 12 multi-marker slots and 26 item
IDs crossing locations; all agree with the printed summaries.

| Location | Occupied slots | Total quantity | Vendor Sell slots / quantity |
|---|---:|---:|---:|
| Backpack | 162 | 6,859 | 22 / 100 |
| Bank | 240 | 10,702 | 17 / 17 |
| Subscriber bank | 155 | 8,796 | 30 / 30 |

- The bank was closed and ESO Plus active. ZOS exposed 395 bank/subscriber-bank
  occupied slots, and FCO queries succeeded. This confirms closed-bank scanning
  for the captured state; no opening is required merely to repeat this snapshot.
- Snapshot enumeration/sort took **2 ms**; FCO queries/validation took **14 ms**.
  Formatting and aggregation are excluded. The general suite reported **89/89**
  passed, **312 ms for 100 inventory scans**, and tracker-build samples
  **41/41/39 ms**. These are observations, not paired FCO overhead certification.
- At this capture the Debug Key still invoked the full general suite before
  appending the snapshot. The lightweight routing was subsequently authorized
  under D20 and implemented above, leaving `/ictest` unchanged.
- Raw Sell marks total **147** items. The editable group's report totals **242**
  combined, backpack **100**. Its name patterns/exclusions must be accounted for;
  do not use raw marker totals as the expected group total.
- There are already stacked items and cross-location copies suitable for later
  count tests, plus multiple gear-tag combinations. Avoid changing gear marks
  merely to manufacture a multi-marker example.
- First controlled case: **Possessed Shred**, item **199137**, backpack slot 4
  at capture, quantity **2**, currently only Sell (5). Add **PvP (17)** while
  retaining Sell, with no movement/sale. If FCO supports that combination, expect
  one `[5+17]` slot of quantity 2, PvP quantity **439 -> 441**, multi-marker slots
  **12 -> 13**, and unchanged Sell/group quantities (assuming other data/settings
  stay unchanged). FCO replacing/denying Sell is a policy observation to report,
  not a reason to force marks. Follow-up capture is recorded below.

### Controlled follow-up: Sell replaced by PvP

Tim's second report on 22 November has 901 lines and a complete footer:
557 slot rows, 17 enabled markers. Compared every slot-detail line with the
baseline; the only changed row is backpack slot 4, item 199137, quantity 2,
**Possessed Shred**, whose tags change **[5] -> [17]**, not `[5+17]`.
This proves the API-visible result without relying on the UI's displayed icon.

| Check | Before | After |
|---|---:|---:|
| Vendor group matching item IDs | 37 | 36 |
| Vendor group backpack quantity | 100 | 98 |
| Vendor group combined quantity | 242 | 240 |
| Raw Sell-marked quantity, all three bags | 147 | 145 |
| Raw PvP-marked quantity, all three bags | 439 | 441 |
| Multi-marker slots | 12 | 12 |

All other slot-detail rows, item quantities and locations are unchanged.
Enumeration took 1 ms and FCO queries/validation 14 ms. The forced Debug Key
refresh correctly removed the item/counts from the vendor group. Automatic
marker-only refresh is still unimplemented and is not certified by this result.

The observed FCO operation replaced Sell with PvP for this item and configuration;
it does not establish exclusivity for all marker pairs. This is a successful
replacement/removal counting case, not the proposed coexistence case. Tim
confirms the original Sell mark was only test data and need not be restored;
Tim subsequently reports removing PvP as well. The follow-up baseline is now
neither Sell nor PvP, confirmed by the subsequent paired-run snapshot.
Existing real multi-marker examples
remain available without changing valuable gear merely to create another.

### Bank extension: agreed scope and implementation plan

Tim's 22 November request authorizes implementation and retesting. Extend the
fixed vendor marker to `BAG_BANK` and `BAG_SUBSCRIBER_BANK` as well as
`BAG_BACKPACK`. Other bags remain excluded from marker matching. Normal name
includes/exclusions, saved settings, the Bank action flag and refresh policy do
not change; no new schema or UI is needed.

- `Core/FCOItemSaverSpike.lua`: give `QueryMarker` an explicit bag argument and
  pass it directly to `FCOIS.IsMarked`. `MatchVendorMarker` allows only those
  three bags. Keep readiness checks and invalid-result errors unchanged.
- Preserve standalone backpack scan/watch diagnostics by explicitly supplying
  `BAG_BACKPACK` at their existing query call sites.
- Extend Debug Key group and per-item reports with the combined quantity and
  use location-neutral empty-result wording. Existing counting contracts are
  unchanged: combined totals can include craft-bag name matches, so do not label
  combined-minus-backpack as bank-only.
- `Project/Tests/FCOItemSaverSpikeTests.lua`: model markers by bag/slot, keeping
  existing backpack fixtures. Test same-slot different marks across backpack,
  bank and subscriber bank; verify group-specific location totals, ordinary
  groups, shared runtime matching and exclusions. Assert unsupported bags never
  query FCO and failed bank queries still throw.
- Existing tracker bag enumeration and AutoCategory bag/slot propagation already
  cover bank. No banking transfer or housing-storage changes are included.
- Focused offline tests and independent review precede the in-game handoff.
  Live bank behavior remains pending until Tim retests. Semi-automatic
  performance and edge-case diagnostics are a subsequent step.

### Bank extension verification

- Independent `fco-bank-plan-review` approved the focused scope/plan. Its
  non-blocking reporting observation is addressed by backpack/combined
  quantities and location-neutral empty-result wording.
- Independent `fco-bank-code-review` found a diagnostic-label error:
  combined-minus-backpack could count craft-bag name matches as bank items.
  Corrected the report to show the existing combined count, with a focused
  craft-bag/name-pattern regression. No extra inventory scan was added.
- `python Project\Tests\Run-RuleTests.py --test-filter "FCO spike|AutoCategory passes item bag and slot|untracked rows exclude IDs"`
  passed **15/15** and all addon sources compiled as Lua 5.1.
  `git diff --check` passed. Independent `fco-bank-report-fix-review` verified
  the correction with no new finding. Tim subsequently reports the basic bank
  retest looks good; detailed storage edge checks remain pending.
  No new performance workload or refresh trigger was added. No commit or push.

### Proper-group conversion plan

- Register the DEV-only baseline group in `Core/FCOItemSaverSpike.lua`, under
  the existing stable key, with name **sell to vendor**, empty name patterns,
  vendor Sell marker matching and ordinary grouped/backpack display defaults.
  Do not keep the old tracker-only injection or transient expansion path.
- `Tracking/ItemDatabase.lua`: preserve the baseline marker callback in runtime
  and active rules. Reuse the compiled name matcher for all consumers:
  name includes OR the vendor marker admit an item, then normal exclusions veto
  either route. No double counting. Expansion, pattern edits, reset and display
  choices use existing saved-rule helpers.
- Add bag/slot context to `ItemMatchesRuntimeRule` and its notification,
  untracked-item and AutoCategory callers. `Tracking/AutoCategoryIntegration.lua`
  passes AC's verified `checkingItemBagId` and `checkingItemSlotIndex`, without
  switching to AC's native FCO implementation. Architecture reuse remains OPEN.
  Initial conversion was backpack-only; the approved bank extension above now
  adds bank and subscriber bank. Name matching retains ordinary location behavior.
- FCO absence/readiness is explicitly reported; normal name includes may still
  match. A failed query throws. Validate at the external query boundary;
  startup matching must not incorrectly require IC's final loaded flag.
- Remove `GetTrackerActiveRules` and use the ordinary accessor in the tracker
  and Debug Key. Keep the first-stage Debug Key report and timing pause; update
  its wording to describe the real group.
- Increase SavedVariables schema **11 -> 12**: older builds do not know the new
  baseline identity referenced in persisted AC orders. Extend the explicit
  migration gate to schema 12, retaining all existing fields and panel-schema
  migration rules. Validate every profile before constructors; reject a legacy
  saved custom rule colliding with the new key before changing data.
- Use the actual `v1.8.1` schema-11 reader in downgrade regression tests.
  Test schema-11 migration across profiles and preservation of group overrides,
  AC references, unrelated fields and backups; older reader rejects schema 12
  before constructors or writes. The hash-verified 256-file backup is the
  rollback point for in-game migration; keep the release installation disabled
  while testing DEV and do not restore files during an active character session.
- Focused tests cover proper baseline/editor/AC visibility, persisted expansion,
  name/marker OR and exclusions, unavailability, slot-context call sites and
  migration/downgrade behavior. Independent plan/code review precedes handoff.
- No marker picker, scan-trigger policy, new notification behavior, performance
  workload, commit, merge or release is included.

### Proper-group review and verification

- Independent plan reviewer `fco-proper-group-plan-review` found no blockers.
  Registration is at module-load before saved-data preparation. Runtime and
  active rule tables preserve the callback. Display-name collisions retain the
  existing built-in promotion rules; conflicting legacy private keys are rejected.
- Verified the on-disk files are separate `InventoryCompanion_DEV.lua` and
  `InventoryCompanion.lua`; both use the same in-game global. A review's inference
  of one on-disk file was incorrect. Schema protection is still mandatory.
- Independent code reviewer `fco-proper-group-code-review` found two issues:
  same-ID unmarked copies could incorrectly create an Untracked editor row, and
  absent FCO could go unreported when no slot matcher ran.
- Corrected the editor to consider all scanned copies before declaring an ID
  untracked, preserving first-encounter data for wholly untracked IDs. Added
  unconditional startup readiness reporting, independent of slot matching.
  Focused `fco-proper-group-fixes-review` verified both corrections.
- `python Project\Tests\Run-RuleTests.py` passed **291/291**; all addon Lua
  sources compiled as Lua 5.1 and `git diff --check` passed.
- The actual released `v1.8.1` reader at
  `491c5fc26d5e0f870c4318243a87e2a30f3070a4` rejects migrated schema 12 before
  constructors or mutation. Tests preserve all profiles, overrides, AC references
  and unrelated data. Existing migration assertions now expect schema 12.
- In-game schema migration, proper-group editor visibility and subsequent tests
  remain pending. No real SavedVariables file was changed by offline tests.

## Implementation baseline and safety contracts

These preserve the implemented diagnostic design. Tim agreed the high-level
tests and explicitly requested setup of the first test on 21 November 2026.

### Historical tracker-only setup plan (superseded by proper-group conversion)

Retained as implementation/approval history, not current instructions.

- Create a temporary DEV tracker group named exactly **sell to vendor**, using
  FCO's built-in vendor Sell marker (`FCOIS_CON_ICON_SELL`). For this spike stage,
  keep the group and its expansion state in memory, outside saved profiles,
  group editors and AutoCategory. This avoids introducing production saved-data
  changes for a temporary test; editor/AC support comes in later steps.
- `Core/FCOItemSaverSpike.lua` owns the group, validates external FCO readiness
  and the enabled marker, and supplies a backpack slot matcher. Unavailability
  is explicitly reported and omits the test group; failed queries throw rather
  than being counted as unmarked. The first stage only queries backpack slots.
- `Tracking/ItemDatabase.lua` adds `GetTrackerActiveRules`, which copies ordinary
  active rules and adds the transient group after DEV initialization. Only
  `ItemTrackerPanel.GetTrackerDisplayList` and the spike report use this view;
  editors and AutoCategory retain their existing accessors. Preserve an optional slot matcher in the
  scan's compiled rule data, invoking it with the actual slot record; ordinary
  rules keep compiled name matching and existing group-count bookkeeping.
  Supply empty compiled pattern tables and a complete resolved display with
  backpack Show/Group/Expanded true, Bank/Notify false. The slot matcher replaces
  name matching for this rule; empty ordinary patterns still match nothing.
  Route expansion changes for this group to transient state, never saved rules;
  reject a collision with the private rule key rather than modifying saved data.
- `Core/Init.lua` initializes the spike after `state.isLoaded = true` and refreshes
  the existing tracker. Add FCO as an optional DEV manifest dependency. Missing
  FCO must not prevent IC loading.
- The Debug Key's FCO section now reports the configured vendor marker, group
  presence, matching item links and backpack quantities. It does not start the
  completed watcher by default. Keep standalone diagnostic commands available.
  Report absent matches explicitly. Do not add timing workloads or new scene
  triggers in this setup; those belong to later agreed tests.
- Extend the existing isolated FCO tests using the actual ItemDatabase scan for
  marker selection, per-group same-ID quantities, bank exclusion, transient
  expansion, unavailable/failed FCO, DEV-only behavior and Debug Key reporting.
  Run the focused suite and independent code review before in-game handoff.
- Spike acceptance and later test/design decisions remain pending. This request
  does not authorize commit, merge or push.

### First-test independent plan review

- Reviewer: `fco-first-test-plan-review` (`rubber-duck`), 21 November 2026,
  worktree at branch HEAD `e46314660d1df2b41181c0df5b47e6427119d951`.
- Shared editor accessor finding resolved by the separate tracker-only view.
  Compiled callback/display/expansion contracts clarified above.
- Readiness is re-evaluated every tracker operation, not only at initialization.
  External unavailability is reported explicitly; recovery retries naturally.
  Validate once per operation; non-backpack slots never query FCO.
- Focused plan re-review `fco-tracker-boundaries-review` found no unresolved
  corrected-boundary blockers. Complete raw/compiled pattern and display fields
  were included in the implementation.
- Recommendation to catch failed per-slot queries and retry normal-only scans
  is rejected: it would mask a failed scan and conflicts with project fail-fast
  rules. Query failure remains an explicit error, including in Debug Key output.
- Optional dependency verified from the installed `FCOItemSaver` folder and
  manifest. Existing slash-command defaults remain Guild Store for compatibility;
  the new group and Debug Key report explicitly use vendor Sell.
- Expansion resets on reload and notifications remain off for this temporary
  first stage; persistence and notification checks remain later work.

### First-test implementation review and verification

- Independent `fco-vendor-first-test-code-review` identified hidden saved-key
  collisions bypassing an active-only check. Focused follow-up
  `fco-hidden-collision-fix-review` identified enabling the spike before the
  collision check. `fco-initialization-preflight-review` confirmed the flag-order
  fix but found that calling the runtime getter could normalize saved fields.
- Resolved at the boundary: check the raw selected profile and built-in rule
  keys before enabling the spike, without calling the normalizing runtime
  getter. Repeat that check when adding the group. Regression tests verify
  hidden data/fields remain intact, no spike flag is set on rejection, and
  normal tracking still works afterward.
- User's "ok set up the first test" authorizes this T03 implementation only.
  No marker writing, saved schema change, AutoCategory modification, new scene
  trigger, name condition or timing workload was added.
- Final focused validation:
  `python Project\Tests\Run-RuleTests.py --test-filter 'FCO spike|Scanning and notifications|Cached synthetic|tracker'`
  passed **51/51**. All addon Lua sources compiled under Lua 5.1 and
  `git diff --check` passed. No in-game result is claimed.

### AutoCategory prior art for the later discussion

- Installed `AutoCategory\plugins\FCOIS_Plugin.lua` supplies native FCO rules.
  `AutoCategory\Hooks_Keyboard.lua` queries all markers and includes the result
  in its per-item hash for invalidation.
- IC's current AC predicate in `Tracking/AutoCategoryIntegration.lua` passes
  only `checkingItemLink` to `ItemMatchesRuntimeRule`. Marker support needs
  actual bag/slot context; sharing names alone is insufficient.
- Compare reuse of native AC predicates/cache behavior versus calling the
  validated IC marker matcher with AC's bag/slot context. No installed AC/FCO
  source changes and no second name-pattern matcher are planned.

- `Core/Scanning.lua` supplies bag, slot, item ID, link and count.
  `Core/Events.lua` owns the normal inventory listener. The diagnostic uses a
  separate namespace and backpack event filter. Its manifest entry follows
  scanning; registration and the Debug Key collector are DEV-only.
- `ValidateFCO(markerId)` checks external readiness and query contracts.
  Require `gAddonLoaded`, `libsLoadedProperly`, `settingsVars.settings`, enabled
  marker and its storage. Check settings before resolving storage with
  `GetSavedVarsMarkedItemsTableName`; check the named table in both settings and
  `FCOIS`. Do not call `CheckIfFCOISSettingsWereLoaded` as a readiness probe:
  it can load settings.
- Require an integer marker from 1 through
  `FCOIS.numVars.gFCONumFilterIcons`; default is
  `FCOIS_CON_ICON_SELL_AT_GUILDSTORE`. Disabled markers and missing storage are
  explicit failures, not unmarked items. Resolve storage without an override
  before each synchronous operation. These are installed-version signals,
  not a stable public readiness contract.
- `IsMarked` must return a boolean first value and table second value.
  Bare false or nil means unavailable/failed, not a valid negative result.
  Gamepad mode requires `CheckIfADCUIAndIsNotUsingGamepadMode()` to return
  true; a missing predicate or unsupported mode is explicitly reported.
- `CaptureBackpack` reads snapshots. `RunScan` times ten baseline and ten
  query passes over identical captured slots using
  `GetGameTimeMilliseconds`. Measurements have no arbitrary pass threshold.
- `StartWatch` snapshots and registers; `StopWatch` unregisters before final
  validation/snapshot, including on mode changes or failures. Only the same
  nonempty, nonzero safe unique ID at the same slot with unchanged item details
  and count permits a candidate marker-change report. Movement, replacement,
  changed stack, missing identity or no net marker change is inconclusive.
  Events are correlation evidence only.
- `RunSynthetic` uses a local candidate accumulator and fabricated slot data,
  independently measuring marked-only and all-copy quantities. It does not
  replace production tracker state or mutate live inventory/SavedVariables.
  `Project/Tests/FCOItemSaverSpikeTests.lua` runs in an isolated runtime through
  `Project/Tests/Run-RuleTests.py` with FCO, ESO, clock and event stubs.
- Diagnostic state is transient. IC does not write markers or SavedVariables.
  Manual test marks must be restored. Surface external failures; do not guard
  required addon-owned contracts or disguise errors as successful empty data.
  Any future persisted change must follow schema/migration/downgrade safeguards.
- Proposed group matching checks the slot's FCO marker alongside the existing
  scan and adds its quantity to that group once. Group-first bookkeeping
  resolves the shared-ID representation issue but does not implement FCO.
  See the [tracker specification](<../../../Features/TrackerGroupFirst/001 TrackerGroupFirst - Specification.md>)
  and [master-writ background](<../../TrackerGroupFirst/002 TrackerGroupFirst - Implementation Plan.md#background-case-study-master-writs>).

## Approval and branch history

### SavedVariables backup for further spike testing

- On 21 November 2026 Tim requested a backup so the group need not remain
  tracker-only. Backed up the entire on-disk `live\SavedVariables` folder to
  `live\SavedVariablesBackups\FCO-spike-20261121-235630783Z`, outside the repository.
- All **256 files** were SHA-256 verified against the source before and after
  copying; the file set was checked for changes. No live save files were modified.
- This is the last-on-disk snapshot, not unflushed in-game state. Restore only
  after logout to character selection or with ESO closed, never over an active
  character's session.
- Backup provides rollback, not permission to bypass schema/migration/downgrade
  safeguards. Making the group visible in editors and AutoCategory remains a
  runtime/configuration change to implement; backup alone does not expose it.

- Original temporary diagnostic: Tim said "ok I'm approveing both" for spec
  and plan and separately "go" for coding. Independent findings were resolved.
  These approvals apply to diagnostics, not the unimplemented built-in group.
- Group-first work was merged into local main; main was then merged into
  `spike/fco-itemsaver` at `f116347`. Diagnostic/document synchronization was
  committed as `e1175a6`; Debug Key wiring as `e463146`. No push was made.
- This document consolidation is authorized; it does not change runtime code,
  approve release work or authorize another commit/merge/push.
- First-test focused plan reviews and explicit coding GO: recorded above.
- Agreed live group test scope and approval: PENDING.
- Explicit spike/MVP acceptance: PENDING.

## New result entry format

For each added result, record test ID, date, source revision, configuration,
actions, expected versus actual behavior, exact measurements/output,
limitations, restoration and any resulting decision. Keep unresolved questions
explicit and leave unperformed checks pending.
