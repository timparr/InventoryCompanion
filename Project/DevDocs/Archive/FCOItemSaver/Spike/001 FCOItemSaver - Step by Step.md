# FCO ItemSaver spike: step by step

Archived 2026-11-24 from `spike/fco-itemsaver` at `16c31c2`. Historical test
instructions and pending items below are not the current production work list.

Status: DEV spike works in ordinary crafting; responsiveness and FCO readiness follow-ups pending
Branch: `spike/fco-itemsaver`
Updated: 2026-11-23
Details: [results and decisions](<002 FCOItemSaver - Results and Decisions.md>)

## Governing this spike

Keep the expandable test list and brief outcomes here; put detailed evidence,
measurements and decisions in the linked record. Production work is split into
[Scanning Refactor](<../../../Features/ScanningRefactor/001 ScanningRefactor - Specification.md>)
(backend and hidden single-marker built-ins) and
[FCO Integration](<../../../Features/FCOItemSaver/001 FCOItemSaver - Specification.md>)
(later custom marker conditions and overrides), separate from this spike.

**PENDING** means Tim agreed the test and it has not been completed.
**PROPOSED** means an additional test suggested by Copilot, not yet agreed.
**DONE** records completed work, not blanket feature acceptance.
Keep stable test IDs when adding or changing tests.

This is a temporary DEV investigation, not a released feature. Follow the
[feature process](../../../../Processes/FeatureDevelopment.md) for applicable
review and approval gates. The first-test group and T09.1-T09.3 diagnostic
prototypes are implemented; uncaptured in-game results remain pending.

## What we already learned

| ID | Test | Result | What happened |
|---|---|---|---|
| T01 | Read FCO marks and check for inventory events when a mark changes | DONE (tested case) | The changed mark was readable, but no backpack slot event was detected. Do not repeat this as a prerequisite. |
| T02 | Check counting of differently marked copies sharing an item ID | DONE offline; live case unavailable | Candidate counting passed offline. Tim's FCO marks all similar copies together, so the differing-mark live case cannot be created. |

T02 is prototype evidence, not proof of the real group's behavior. Prior
measurements and the uncaptured in-game synthetic result remain in the detail
record, not as extra high-level test steps.

## Agreed tests, in working order

| Step | ID | Test | Result | What happened |
|---|---|---|---|---|
| 1 | T03 | Make a built-in group called **sell to vendor**, filtered by FCO's vendor Sell marker | DONE (setup) | Tim confirms the proper group works, appears in the group editor and exposes the Bank yes/no toggle. Broader tests remain pending. |
| 2 | T09 | Performance-test the **sell to vendor** group: compare scan speed and responsiveness with and without it | PENDING (two calibration runs received) | First paired overhead +7/+10/+17 ms; unchanged repeat +6/+4/+4 ms. Six-pair median +6.5 ms, range +4 to +17 ms. Extra cost is observed, but magnitude varies; acceptance limit remains pending. Whole-group cost, not isolated FCO API cost. |
| 2.1 | T09.1 | Check every enabled marker as a group plus combined-tag AND groups; compare naive/shared strategies | PENDING (two worst-case captures passed; budget pending) | 17 markers, 16 AND groups, 1,020 slots. Baseline/naive/batched/combined: 83/567/192/193 ms, then 88/605/187/203 ms. Exact 49,980 tag checks and 1,020 batched API calls. All output comparisons passed. |
| 2.2 | T09.2 | Measure duplicated name lookups and pattern checks in the tracker scan, then compare scan-local reuse | PENDING (four captures passed; budget pending) | Earlier no-FCO 85 -> 76 ms and 95 -> 73 ms; all-marker captures 83 -> 86 ms and 88 -> 80 ms. Name calls 1,020 -> 766, pattern executions 167,273 -> 105,950. Identical outputs; timing savings remain variable. |
| 2.3 | T09.3 | Check repeated marker/name work through the shared per-rule matcher used by the editor and AutoCategory | PENDING (two worst-case captures passed; budget pending) | Baseline/naive/batched/combined: 109/528/267/219 ms, then 113/593/275/228 ms. Every per-rule result agreed. Full-sweep upper bound, not actual UI/AC early-exit lifecycle. |
| 2.4 | T09.4 | Compare the `safe` batched tracker algorithm with direct FCO marker-table reads | PENDING (first live pair passed; timing acceptance pending) | Saved run 1: safe 186 ms, direct 191 ms; every slot/tag and complete snapshot agreed. No direct-read advantage shown. Completion HUD namespace error fixed; results persisted after manual reload. B remains normal autotests. |
| 2.5 | T09.5 | Compare `safe` with a hypothetical perfect slot/tag cache | PENDING (first live pair passed; maintenance/acceptance pending) | Saved run 2: safe 216 ms, cached 130 ms; all results agreed. Cache preparation was 91 ms separately. Rebuilding before every scan would negate the saving; live maintenance is not implemented. |
| 2.6 | T09.6 | Compare `safe` with tag-list-driven group matching, using virtual stress groups | PENDING (first live pair passed; performance/maintenance acceptance pending) | Saved run 3: safe 420 ms, indexed 212 ms; all outputs agreed. Preparation 92 ms separately; preparation + indexed 304 ms. Six virtual stress groups, 60 groups total; zero indexed tag/API queries. Name/pattern executions fell 708,775 -> 516,446. Second exclusion added no removals in this capture; independent behavior passed offline. |
| 2.7 | T09.7 | Time the whole operation: no FCO, safe, prepare FCO only, prepare names AND FCO | PENDING (two live four-way comparisons passed; performance acceptance pending) | Runs 4/6: no FCO 263/292 ms; safe 412/445 ms; FCO-only preparation 289/298 ms; names+FCO 281/292 ms. All preparation included, no maintained cache, FCO outputs agreed in each run. Names added only 8/6 ms improvement. Both runs used the same order and pattern execution counts differed; actual pickup latency remains unmeasured. |
| 2.8 | T09.8 | Run paired forward/reverse checks for heavy and representative workloads in one command | PENDING (runs 7-10 passed; performance acceptance pending) | Heavy forward/reverse: no FCO 289/277 ms; safe 439/415; FCO-only 301/300; names+FCO 293/307. Representative: no FCO 82/89; safe 121/110; FCO-only 120/94; names+FCO 117/108. Eager names do not reliably help; lighter overhead is not uniformly negligible. Both temporary groups included; PvP matched, Deconstruction empty. |
| 2.9 | T09.9 | Run real DEV scans during ordinary crafting with timing logging | PENDING (live captures received; performance acceptance pending) | DEV schema 13; four editable DEV built-ins and scan-local FCO-only preparation. Logging uses separate diagnostics and persists on logout or `/reloadui`. See D33/D34 and T09.9 for fields, scope and limitations. |
| 2.10 | T09.10 | Compare sliced inventory refresh during crafting | DONE (8 ms analysed) | 8 ms: max slice 12 ms, render up to 8 ms, median 550 ms to display (4 ms: 1,335 ms); 222 of 520 attempts cancelled. Smooth, but update delay still noticeable. |
| 2.11 | T09.11 | Incremental tracker updates: top-up scan, slot updates and marker polling | IN PROGRESS (stage 1 built, offline 336/336; in-game NOT TESTED) | Three stages: slot index and incremental updates with DEV verification; non-restarting top-up with dirty-slot replay; marker polling while an inventory is open. See [T09.11 plan](<002 FCOItemSaver - Results and Decisions.md#t0911-incremental-tracker-updates-agreed-plan>). |
| 3 | T04 | Check that the group shows the right items and quantities, excluding items without that marker | PENDING (partial controlled confirmation) | Possessed Shred x2 changed from Sell to PvP only. After Debug Key refresh it left the vendor group and counts fell by exactly 2. Broader nonmatch/count cases remain pending. |
| 4 | T15 | Check ordinary name-only groups and individually tracked items alongside the FCO group | PENDING | Ensure adding marker matching does not change existing membership or counts. |
| 5 | T07 | Check quantities as marked items move between supported storage locations or their stacks change | PENDING (partial live confirmation) | Tim reports the bank extension looks good. Transfer/stack changes, exact location counts and mark retention remain to be checked; housing storage is excluded. |
| 6 | T13 | Determine when a new scan is needed: storage marking, scene changes, automatic tagging and conditional polling | PENDING | Also consider once-per-second polling only while the item tracker is visible AND the scene is non-standard; compare update delay and scan cost. |
| 7 | T05 | Check that adding or removing a mark updates the group without moving the item | PENDING | Removing a mark leaves the display stale until another inventory change, as expected for the current setup. New refresh triggers are not implemented. |
| 8 | T14 | Remove the last matching mark/item, then add a match again | PENDING | Check empty-group behavior, stale rows/counts and reappearance. |
| 9 | T06 | Check notifications if enabled for the test group | PENDING | Check intended notifications and absence of duplicates on unchanged scene returns. |
| 10 | T08 | Check reload and recovery when FCO or the chosen marker is unavailable | PENDING | Check group recreation without duplicates, explicit unavailable behavior and recovery when FCO is ready again. |
| 11 | T12 | Add a name pattern alongside the marker and check that the combined filter works | DONE (observed case) | Tim tested a name pattern in the same group and reports it looks good. Detailed marker-only/name-only/both/neither and duplicate-count edge checks remain pending. |
| 12 | T16 | Add an exclusion to the same group and check which items it removes | DONE (observed case) | Tim tested an exclude name pattern in the same group and reports it looks good. Detailed veto checks across marker/name/both routes remain pending. |
| 13 | T10 | Check the marker-only, combined and exclusion-filtered groups in AutoCategory | PENDING (partial live confirmation) | Tim confirms backpack AC visibility and priority/display ordering work. Bank retest, combined/exclusion behavior and refresh remain pending. Discuss AC's existing FCO integration. |
| 13.1 | T10.1 | Investigate AutoCategory initialization failure when FCO is not ready | PENDING (retry succeeded; cause unconfirmed) | Tim reports **Retry Sync** fixed it, suggesting temporary readiness/timing. Capture the exact error/traceback and startup circumstances. FCO is already an optional DEV dependency; check actual initialization order and readiness. Consider deferring FCO-dependent AutoCategory work until FCO is ready, without assuming that is the fix. |

Tim agreed the additional tests on 2026-11-21. Test IDs are unchanged; step
numbers show the working order. Recheck relevant earlier behavior if adding the
name pattern or AutoCategory support changes it.

## Evidence and closeout

### Current capture step

**Next steps:** in-game test of T09.11 stages 1-3 together (D39, D40), in
normal play and then tomorrow's crafting burst:
- the tracker should update on the next frame during item moves and unboxing;
- FCO mark/unmark in the inventory, bank or Inventory Insight should appear
  within about 1 s;
- the scan log should show `incremental`, completed top-ups with
  `dirtySlots`/`verifyDiffs`, and `poll` samples;
- HUD alerts and Bug Catcher should stay quiet.

Watch for the D41 HUD alert "Deconstruct group is not #1 in AutoCategory
matching"; the `acPriority` events in the play log show what changed and the
last projection reason.

If it goes badly, roll back to `e4d668b` (with Tim's approval) and retry the
stages more slowly. Then investigate the reported FCO/AutoCategory readiness
failure (T10.1). See the
[Scanning Refactor implementation plan](<../../../Features/ScanningRefactor/002 ScanningRefactor - Implementation Plan.md>). Tim considers the spike
in a good place even if work stops here; these remain follow-ups, not a claim
of feature or release acceptance. Use the agreed disposable DEV saved-data file.
See [T09.10 details](<002 FCOItemSaver - Results and Decisions.md#t0910-sliced-inventory-refresh>).

**Latest comparisons received:** runs 7-10 passed the heavy/representative,
forward/reverse batch, including temporary Deconstruction/PvP groups.
Heavy FCO-only totals were 301/300 ms versus no FCO 289/277 ms.
Representative FCO-only totals were 120/94 ms versus no FCO 82/89 ms.
Eager name preparation did not consistently improve either workload.
Preparation is included, and no maintained cache is required.
The real scan implementation is now being tested; B still runs normal autotests.

See [T09.8 details](<002 FCOItemSaver - Results and Decisions.md#t098-paired-heavy-and-representative-checks>).

Earlier run 3 passed safe/tag-list-driven equality: 420 -> 212 ms, with
92 ms preparation separately. The performance decision remains open;
T09.7 now counts preparation inside total time and adds the marker-free baseline.

**B now runs normal autotests only**, to check the saved-result transport without
another FCO stress run (D26). The matching workload below is retained for later,
explicit use; `/icfcodiagnostics run [count]` still selects that workload and
must not be used for this short transport check.

The earlier snapshots and two three-pair calibration runs are received.
Two smaller-level T09.1-T09.3 captures passed all equality checks and confirmed
both Craft Bag PvP items. Two all-enabled-marker/AND captures also passed.
The workload uses one single-marker probe per
enabled ID and one AND probe per adjacent sorted pair (17 singles + 16 pairs
for the last captured configuration), in tracker and shared per-rule paths.
Both AND operands are checked deliberately; this tests fixed worst-case work,
not a proposed production short-circuit policy or all possible combinations.
No new marks or actual saved groups/categories are needed.
The retained matching runner selects T09.1-T09.3: **no FCO, naive per-group FCO,
batched FCO, and batching plus name reuse**, followed by the live snapshot.
It runs at most five full scans and four captured per-rule passes.
It does not add the old manual refresh/group-report builds, six calibration
scans, general suite or long benchmark. The old collector/comparison remains
available; `/ictest` does not acquire the new scaling workload.

The Debug Key now records results instead of opening a copyable error:

1. Reload the UI to load the updated DEV code/manifest.
2. Press B (Debug Key) to run the normal autotests once. No marker stress
   workload, FCO snapshot or optional tracker benchmark is added. Normal
   built-in checks remain unchanged. Extra presses while busy are ignored.
3. Wait for the HUD and chat completion message saying **reloadui now**.
   A failure is labelled explicitly and retains partial evidence.
4. Manually run `/reloadui` when safe, then tell Copilot to read the diagnostic
   table in the DEV SavedVariables file. The addon never reloads automatically.

For another normal-suite recording, press B again after completion.
The explicit `/icfcodiagnostics run 2` command is a two-run **matching stress**
batch, not the normal-autotest transport check.
`/icfcodiagnostics status` reports history/activity;
`/icfcodiagnostics clear` removes diagnostic history only, when idle.
Clearing also needs a manual reload/logout to persist.
No automatic history eviction is performed.
The separate `InventoryCompanion_Diagnostics` table has its own schema 1 and
stores numbered run status, timestamp, configuration, measured-pass data,
checks, full report and structured snapshot. It does not alter normal profiles.
Interrupted runs are labelled on the next load; unsupported/malformed diagnostic
data disables recording/clearing with an explicit message and stays untouched.
The former synchronous collector is retained, but is not the B workflow.
Tim's existing Craft Bag PvP marks are sufficient.
No preparation marks or item moves are needed. Timings include diagnostic
overhead, not UI rendering, and do not establish an acceptance limit.
The snapshot is one additional enumeration/query pass, now including Craft Bag
when subscribed; virtual capacity is reported as not applicable.
The snapshot reports enabled
marker IDs/custom labels, per-bag slots and quantities, per-marker totals,
combinations, same-ID copies across locations, every occupied slot's item
ID/name/quantity/tags, and one-pass timings. Disabled marks are not queried.
An absent custom label is identified explicitly; the numeric marker ID remains.

Check that the footer contains the slot-row and enabled-marker counts. A missing
footer means incomplete output or a failed capture, not a complete inventory
snapshot. Closed-bank results are explicitly qualified. Analyse Tim's returned
data before requesting specific item/tag changes. Performance limits and all
uncaptured edge cases remain pending.

First controlled case completed: **Possessed Shred** (item 199137), backpack x2,
changed from Sell `[5]` to PvP `[17]`. FCO replaced Sell rather than adding a
second mark in this case. Only that slot row changed; vendor group backpack
quantity fell 100 -> 98 and combined 242 -> 240 after the manual Debug refresh.
This confirms replacement/removal counting, not a `[5+17]` coexistence test.
Tim confirms the Sell mark was only test data and does not need restoring.
Tim subsequently removed PvP as well; the first paired-run snapshot verifies
`tags[]`, with all other slot rows unchanged. Use neither Sell nor PvP for this
item in follow-up tests.
Do not infer general FCO marker exclusivity from this single pair/configuration.

### Existing group diagnostics and safeguards

The earlier group-test runner manually refreshed the tracker and included the
group report in the copyable error. That collector is retained; the current
Debug Key selects the recorded normal autotests instead.
The report now includes backpack and combined quantities. Combined counts follow
the tracker's existing contract, including craft-bag name matches where applicable.
Marker matching supports backpack, bank and ESO Plus bank slots; housing storage
remains excluded.
The group now appears in Manage Groups and the AutoCategory list. Normal name
patterns, exclusions and display/expansion overrides are saved; the vendor marker
is fixed until the marker-picker UI question is resolved. Name includes OR the
marker admit an item, then exclusions veto either route. Existing grouping and
visibility settings still apply, so a compact flat list may not show a header.

This DEV conversion upgrades saved-data schema 11 to 12. The entire on-disk save
folder has a hash-verified backup outside Git. Keep release disabled for testing;
after reload, confirm existing groups/profile settings are preserved as well as
the new group's editor visibility. Actual in-game migration remains pending.

Use the DEV Debug Key and manually persisted diagnostic history for new
evidence. Restore intentional test marks, including similar copies changed
together. Do not mutate live inventory or saved data as synthetic fixtures.

T11 (review, cleanup and acceptance) remains pending as closeout work, not a
behavior test. Proposed tests are not approved merely by appearing here.
Commit, merge, push and release require their own authorization.
