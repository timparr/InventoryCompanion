# Scanning Refactor: feature spec

Status: IMPLEMENTATION ACCEPTED by Tim, 26 November 2026. Real-backup schema
15 migration remains pending final acceptance testing; the marker editor is
deferred.
TODO item: None; production promotion of the FCO ItemSaver feasibility spike
Owner: Copilot
Updated: 2026-11-26
Implementation plan: [archived implementation record](<002 ScanningRefactor - Implementation Plan.md>)

## Acceptance UI amendment (25 November)

Tim requested horizontal FCO lifecycle actions, with inapplicable actions
invisible rather than disabled. Inactive FCO-dependent groups should be
hidden in Manage Groups and Manage Tracking, but retained in their saved
positions in Manage AutoCategory with their existing inactive appearance.
Their configuration must remain intact and become visible again when active.
When FCO is unavailable, hide Enable/Resume and show the reason as text.
Inactive groups cannot be edited in the two other editors until active again.
Tim agreed these consequences and authorized proceeding on 25 November.
The implemented feature was accepted on 26 November, subject to the pending
final-acceptance migration check above.

## Overview / proposed changelog text

- **Smoother item tracking.** Inventory Companion reuses its inventory and
  matching work, updates changed slots promptly, and spreads background
  inventory checks across frames. The aim is to eliminate scan-induced
  freezing, including when several groups match the same items.
- **Optional FCO support.** Select **Enable FCO** in Settings without creating
  any groups automatically. Two temporary Debugging actions create real
  custom single-marker and overlapping test groups. Normal marker-condition
  editing UI comes later. **Suspend FCO** retains your groups
  and settings for later; **Resume FCO** restores their participation.
  **Turn off FCO** permanently removes FCO-dependent groups after
  confirmation.

This is draft release wording, not a claim of publication or completed final UAT.
Follow the [feature development process](../../../Processes/FeatureDevelopment.md).

## Shared FCO condition framework amendment (26 November)

Status: implemented, independently reviewed and accepted by Tim on 26 November.
Final-acceptance migration UAT remains pending. This amendment supersedes the
earlier split that deferred the shared custom-group marker backend. The marker
editing UI remains later work.

- Use the same group condition framework for name patterns and FCO markers.
  Any positive condition may include an item; any negative condition vetoes
  that inclusion. For example, `(writ OR PvP) AND NOT (master OR sell OR
  deconstruct)`. Marker conditions must follow the same group-level
  availability, suspension and confirmed Turn off behavior as other FCO
  conditions.
- The three existing test groups must be real custom groups with single
  marker conditions, not special marker-matching built-ins.
- Provide two Debugging actions: one adds the three test groups, and one
  adds overlapping real custom groups including a mixed name/marker group,
  a multiple-marker group, a negative-marker group and one group per user's
  marker. They must use the same production framework as user groups.
- Exercise the normal tracker scan and rendering path with these groups.
  Visible slideshow-like performance is a failure. Suspend, Resume and
  confirmed Turn off must work for all dependent groups; Turn off removes
  dependent groups and their owned references across profiles and backups,
  preserving unrelated groups and FCO marks.
- Preserve existing user configuration and protect saved-data migrations and
  downgrade compatibility. Existing fixed-group acceptance evidence does
  not establish correctness for the new shared framework.

The historical fixed-built-in and test-button decisions below are
superseded where they conflict with this amendment. The editor remains
deferred. Tim previously agreed that test creation requires Enabled/ready
FCO and affects the selected profile, not other/new profiles.

## Scope and non-goals

The aim is **eliminating freezing and laying the groundwork for FCO-driven
group changes**, by promoting the proven spike algorithms rather than
redesigning them.

In scope:

- Prepared inventory matching, scan-local reuse of FCO answers, and a
  per-slot inventory/membership index.
- Incremental slot updates, time-sliced full top-ups that continue through
  slot events, and time-sliced detection of FCO mark/unmark changes.
- Normal name-only tracking, with or without FCO installed.
- Real custom test groups created by the two Debugging actions, including
  Deconstruct, Sell to vendor and Sell at guild store.
- Shared name and marker matching, including multiple markers and negative
  marker conditions, for the test groups and user groups.
- Account-wide Enable, Suspend/Resume and confirmed Turn off FCO controls;
  whole-group inactivity while suspended or required markers are unavailable.
- Preservation of user profiles, group edits and AutoCategory orders;
  migration/downgrade protection; production removal of spike-only coupling.

Out of scope:

- A marker picker or marker-condition rows in the group editor.
- Marker-condition editing controls and their picker workflow.
- Writing FCO marks, reading its private storage as the production matching
  algorithm, or hooking its marking functions.
- New automatic startup retry/deferral behavior, wider bag/gamepad support,
  or a rewrite of rendering/scheduling that has not been demonstrated.
- Reimplementing the [diagnostic logging framework](<../DiagnosticLogging/001 DiagnosticLogging - Specification.md>).

The existing logging framework is promoted as the first delivery prerequisite,
not reimplemented. Its setting, controls and initial logs are included in the
production handoff; the linked logging specification owns their behavior.

The deferred marker-editor work belongs to
[FCO Integration](<../../Features/FCOItemSaver/001 FCOItemSaver - Specification.md>).

## User experience and behavior

### Tracking

- Slot events are coalesced and applied on the next scheduled frame, without
  waiting for a full rescan.
- Inventory-burst display work is coalesced separately from slot evaluation.
  Use a 333 ms throttle: the first ready update after an idle period renders
  on the next scheduled frame, then inventory redraws are at least 333 ms
  apart. Further events do not postpone a pending redraw. Render the latest
  index at the next eligible frame, including a final update without another
  event; do not keep scheduling redraws when nothing changed. This applies to
  all supported tracker inventory changes, not just bank transfers, including
  full-scan completion. A running scan must still finish before its result
  renders; completion uses the same remaining redraw interval, not a fresh
  quiet-period wait.
  Explicit settings/profile refreshes remain synchronous and obsolete pending
  inventory renders must not overwrite them or redraw a disabled tracker.
- A slot event does not cancel a running full top-up. Changed slots are
  replayed before its result replaces the current index.
- A full inventory update retains the current view while starting a top-up,
  or requests a further pass if one is already running.
- Context/rule/profile changes invalidate incompatible work. Results from an
  old context must not replace the new context.
- Keep the working 8 ms target scan slices and separate-frame completion
  rendering. These are cooperative budgets, not hard frame-time guarantees.
- Marker polling uses the working 1-second timer and 2 ms target slices,
  only while the tracker is actually visible and the scene is not `hud`.
  A poll may take multiple slices; do not promise a hard 1-second display
  deadline.
- Preserve the current synchronous paths for other refresh reasons. Do not
  claim that all addon work is now time-sliced.

### FCO custom groups and test actions

- Enable, Resume, login and reload create no groups by default. The two
  Debugging actions add the three single-marker groups or the overlapping
  workload described in the amendment. Both operate on the selected item
  profile, require Enabled/ready FCO, and explain their effects before
  changing data. Cancel or dismissal leaves everything unchanged.
- Match if any positive name pattern or marker matches, unless any negative
  name pattern or marker matches. Without a positive match there is no match.
  The existing virtual Miscellaneous catch-all does not expose editable name
  patterns and does not accept marker conditions; it remains available for
  independently tracked items.
  Markers cover backpack, bank and subscriber-bank slots; name patterns
  retain their existing bag coverage, including the Craft Bag.
- Referenced markers, positive or negative, must all be available for the
  group to be active. A missing marker makes the entire group inactive even
  when another positive condition could match. Never change FCO's settings.
- Preserve existing groups, edits and unrelated AutoCategory ordering.
  The original three test groups keep their established visible defaults
  and AutoCategory positioning. Repeated creation must not overwrite edits
  or duplicate groups. The overlapping test groups remain available for
  lifecycle tests and confirmed Turn off removes all FCO-dependent groups,
  including existing user groups, across profiles and backups.
- The heavy workload uses one group for each enabled marker FCO reports,
  plus the requested mixed, multiple-marker and negative-marker groups.
  Report disabled or unavailable markers rather than treating them as
  successfully tested. The marker editing UI remains deferred.

### FCO lifecycle controls and inactive groups

Enable/Resume require FCO to be installed and ready; otherwise omit those
actions and show the reason as text. Suspend and confirmed Turn off remain usable
without FCO. Dependency absence
alone never deletes groups or changes the saved lifecycle state.

Replace the planned FCO settings placeholder with account-wide actions, not
a simple checkbox. Keep these actions in the existing **FCO ItemSaver (planned)**
submenu, which must no longer be disabled; marker editing remains future
development. The two test-group creation buttons stay under Debugging.
The state is independent of the selected profile and is
not changed by copying a profile.

Display applicable actions horizontally without gaps; hide the others. If
only one action is available, place it first. When Enable/Resume is unavailable,
show the dependency readiness reason as text. The Turn Off warning does not
preview the affected groups.
| State | Settings actions | Group behavior |
|---|---|---|
| Off (initial default, or after confirmed permanent turn-off) | Enable FCO | No FCO-dependent groups are created automatically, including on Enable. Deleted groups/edits/orders are not recovered. |
| Enabled | Suspend FCO; Turn off FCO | Eligible groups operate according to their saved visibility and AC participation. Missing/unready FCO still makes dependent groups inactive, not deleted. |
| Suspended | Resume FCO; Turn off FCO | Retain groups and all their settings, but make them wholly inactive. Resume uses the retained configuration rather than fresh defaults. |

- Suspend and Off stop FCO marker queries and polling; neither turns off
  prepared scanning, incremental updates or time-sliced top-ups for
  ordinary groups.
- If integration is suspended, FCO is absent/not ready, or a required marker
  is unavailable, **every group depending on that condition is inactive as
  a whole**. Neither its FCO conditions nor its ordinary name patterns may
  produce matches. This applies to tracker counts/display and AutoCategory
  classification, not just one consumer.
- Inactive groups remain identifiable and configurable in AutoCategory,
  but are omitted from Manage Groups and Manage Tracking until active.
  Do not silently turn them into name-only groups or
  change their saved hidden state. Preserve names, patterns, display edits,
  expansion preferences, and AC inclusion/Display/Priority configuration.
- A lifecycle change invalidates affected cached results and unfinished work,
  refreshes tracking and reconciles AC classification/cache. Previously
  classified items must not stay in an inactive IC category merely because
  AC cached their result. Resuming integration with FCO ready
  restores participation according to the user's retained settings; it does
  not unhide groups or opt them into AC.
- Pure name-pattern groups remain active. Individually tracked items remain
  tracked independently of membership in an inactive FCO group.
- This safety rule also governs future custom marker conditions and marker
  exclusions. For example, a future group including `*writ*` but excluding
  FCO Sell at Guild Store must become inactive when FCO is suspended, not
  broaden to all writs. Marker-exclusion UI itself remains deferred.

**Turn off confirmation**

```text
This turns off FCO ItemSaver integration. Any groups containing FCO marker
conditions will be deleted from all profiles. If you re-enable FCO ItemSaver
integration in the future, you will have to rebuild these groups and reorder
them in AutoCategory.

You could suspend the integration instead, which marks all the groups inactive
without deleting them. Do you want to proceed?

[Yes, delete my groups]  [No]
```

- **Yes, delete my groups** removes all FCO-dependent groups and their overrides,
  tracker preferences and IC-owned AC references across account/character
  profiles and retained profile/list backups. This includes hidden and
  custom/mixed groups with any FCO condition.
  Do not remove ordinary groups or individually tracked items.
- Remove affected IC-managed AC assignments/definitions through the existing
  ownership rules; preserve native/unrelated categories and their relative
  ordering. Refresh classification so removed groups do not survive in cache.
- Record Off durably and suppress automatic group regeneration on reload,
  dependency availability changes or later logins, even if FCO remains
  installed. Profile switching/resetting a group must not recreate them.
- **No** (or dismissing the dialog) makes no changes. The separate Suspend
  action performs the non-destructive transition.
- Permanent turn-off requires this explicit confirmation; absence of FCO
  never deletes saved groups. A later explicit **Enable FCO** creates no groups
  and does not recover deleted edits or AC participation. Test groups require
  a separate explicit use of **Add test FCO groups**.
- The confirmation can be used without FCO installed. It removes only IC's
  configuration, never FCO's own saved data, marks or addon files.

### Inactive groups in the three editors

Inactivity is a runtime availability state, separate from saved Hide/Show,
Notify and AC inclusion settings. Omission applies only to the two specified
editor views, not to rule accessors or saved configuration.

| View | Inactive FCO-dependent group behavior |
|---|---|
| Manage Groups | Omit inactive groups, including those marked hidden. Restore them when active, retaining names, patterns, hidden state and other preferences. Editing is unavailable while inactive. |
| Manage AutoCategory | Keep the row in its saved Display/Priority position and its existing included/excluded section for each context. Keep participation and movement controls usable to configure it for later. Do not move it under Excluded or rewrite priorities just because FCO is suspended/unavailable. It performs no classification while inactive. |
| Manage Tracking (item tracker editor) | Omit inactive group rows regardless of filters, without changing saved Show/Notify/location/grouping preferences. Restore them when active; inactive groups produce no HUD rows or notifications. |

If the selected group becomes inactive, Manage Groups selects another
available group or clears its selection and details. It must not leave the
inactive group's editable details or actions visible.

Items that match only an inactive group are eligible for the existing
**Untracked** browsing view, unless independently tracked or matched by
another active group. Individually tracked items remain unaffected.
Resuming integration restores ordinary runtime participation using the
latest retained settings, without moving rows or resetting editor filters.

**Appearance in Manage AutoCategory:**

- Render the inactive group's row name, any group-type prefix and appended
  status in **pale grey `#B0B0B0`** (RGB 176, 176, 176), at full opacity.
  Do not fade the whole row or give editable controls a disabled appearance.
- Append a presentation-only status to the name:
  `Group name (Inactive - FCO suspended)`. Use the applicable reason
  instead when FCO is unavailable/not ready or a required marker is disabled
  or unavailable. Never save the suffix as part of the group name.
- The label remains pale grey while hovered or selected; preserve the
  existing selection background/focus indication. Buttons and inputs retain
  their normal interactive styling and tooltips.
- Inactive styling takes precedence over ordinary group-type/hidden label
  colours, but retain explicit hidden text where the view normally shows
  it. Inactive and hidden must remain distinguishable without colour alone.
- Restore the view's normal active styling when eligibility returns. Row
  reuse must not leave unrelated groups grey or strip their normal styling.
- Permanently deleted groups do not appear in any editor; pale-grey retained
  rows represent suspension/unavailability, not permanent turn-off.

### Optional dependencies and errors

FCO and AutoCategory remain optional. Without FCO, pure name-pattern groups
continue and saved FCO-dependent groups/edits are preserved but inactive.
Report availability changes and explain inactivity rather than claiming a
successful marker read or evaluating only part of a group's conditions.

Preserve the tested empty-slot handling and explicit AutoCategory failure /
Retry Sync behavior, including cache clearing on retry. Do not promise
automatic recovery that is not implemented. Internal contract violations
must still throw near their cause.

## Preservation and compatibility

- Preserve names, patterns, exclusions, counts, item-source selection,
  tracked-item rescue behavior, profiles and ordinary non-FCO workflows.
- The index and scan-local caches are runtime state, never saved state.
  Do not introduce a persistent inventory cache.
- Migrate all affected supported profiles and retained backups before ZOS
  constructors, preserving unrelated data. Spike SavedVariables were
  throw-away test data: no recovery of spike groups, edits or AC references
  is required. Enable creates no groups; explicitly created test groups are
  active when FCO/markers are available, non-hidden and included at the top of
  AC Priority and Display in every container.
- Use a new production settings schema for both DEV and release, with
  downgrade refusal before mutation. Preserve supported older migrations,
  including schema 14 and normal schema 11; spike settings schemas 12/13
  are not migration sources. This is separate from diagnostic-log format 3.
- Test migration of a real schema-14 backup containing the existing FCO
  groups and edits before release, with the established backup safeguards.

## Acceptance criteria

Temporary DEV-only diagnostics (`this.IsDevelopment == true`): retain an AC
priority-change watcher for the explicitly created test groups only while
diagnostic logging is enabled. Record a fresh baseline on each enable period and subsequent changes
to saved and actual matching priority, with context and previous/current
positions, including mismatches and recovery. Observe legitimate user changes
without treating them as faults; do not require Deconstruct to remain first
or repair/reorder anything. The earlier bug's root cause remains unconfirmed.
Remove this temporary watcher during FCO Integration.

| ID | Required observable result | Verification and environment |
|---|---|---|
| AC1 | With FCO absent and with no FCO groups shown, existing name-only rules, tracked items, group counts and profile behavior remain correct. | Offline snapshot comparisons and in-game smoke checks. |
| AC2 | A burst of slot events produces one coalesced next-frame index update; an active top-up continues and replays dirty slots before adoption. The first ready inventory redraw after idle is next-frame; subsequent inventory redraws are at least 333 ms apart, including full-scan completion. New events do not postpone a pending redraw; its latest ready index renders without another event, and scheduling stops when clean. | Offline virtual-clock burst/interval/cancellation tests; in-game automated and manual transfers and pickup/move/crafting observations. |
| AC3 | Top-ups use the existing cooperative 8 ms target and deferred rendering; polling uses the existing 2 ms target. Heavy overlapping-group activity causes no observed scan-induced freezing or performance regression against the working spike. | Offline scheduling checks; paired in-game observations/timing logs on the same workload. Record actual maxima, including finish and render costs; no unagreed hard 16 ms guarantee. |
| AC4 | Index rebuilds match fresh prepared scans for removals, gains, count changes, overlapping rules and marks; stale-context jobs never replace current results. | Offline equivalence/context tests and investigation of in-game mismatch logs. Tim accepted the unresolved observed mismatch as a known risk on 25 November, with the logging-gated canary and follow-up investigation if it recurs. |
| AC5 | Mark/unmark changes without slot events reach the tracker through polling; polling stops when hidden/in `hud` and resumes in eligible scenes. | Offline and in-game tests; include an external marking UI when available. |
| AC6 | Enable/Resume/login/reload create no groups. The explicit test actions create real custom groups as specified by the 26 November amendment. Preserve unrelated edits and order; unavailable required markers yield inactive groups. The old Add/Remove button contract is superseded. | Offline creation, preservation, profile and unavailable-marker tests; in-game actions and reload checks. |
| AC7 | Existing name-pattern editing and profile behavior remain correct for ordinary and FCO-dependent groups. | Offline editor/profile tests and in-game checks. No marker-composition control is present. |
| AC8 | Optional-dependency failures are reported without breaking ordinary name matching; empty-slot queries are unmarked; Retry Sync repairs AC assignments/cache without changing saved priority. | Offline boundary tests and in-game backpack/bank checks. |
| AC9 | Every affected saved profile migrates without lost edits/orders; malformed data and identity collisions are reported; older readers refuse the new schema unchanged. | Offline migration/downgrade tests and actual older-backup UAT with approved safeguards. |
| AC10 | Production scanning runs without the spike module or DEV flags; benchmark commands/tripwire code are not production dependencies. | Offline release-mode runtime tests and manifest/source review. |
| AC11 | Account-wide Enable/Suspend/Resume/Turn off controls implement the state table, default Off, and persist independently of profile copy/switch. Suspend/Off stop marker queries/polling without disabling faster name-only scanning. | Offline state-transition/persistence/query-count tests and in-game settings checks. |
| AC12 | An FCO-dependent group with both marker and name conditions is wholly inactive while suspended or a required marker is unavailable: no tracker rows/counts/notifications or AC matches, and AutoCategory shows why. Suspend preserves configuration; Resume with FCO ready restores only retained participation. | Offline mixed-condition eligibility and cache-invalidation tests; in-game suspend/resume/AC reclassification/reload checks. Individually tracked items and pure name groups remain unaffected. |
| AC13 | Manage Groups and Manage Tracking omit inactive groups; AutoCategory retains their saved positions, pale-grey labels and reasons. Saved flags are preserved, active groups reappear, and Untracked browsing ignores inactive membership. | Offline editor/filter/selection/reactivation tests and in-game visual checks for active and inactive groups, including unavailable FCO. |
| AC14 | Confirmed Turn off removes every FCO-dependent group and owned references across all profiles/backups without touching unrelated data or FCO marks; reload and later Enable regenerate nothing. No leaves everything unchanged; the separate Suspend action preserves groups. Explicit test-group creation remains a separate action. | Offline all-profile cleanup, cancellation, retained-backup and reload/re-enable tests; in-game two-choice confirmation and editor/AC cleanup checks. |
| AC15 | Both test-group actions explain their effects before changing saved groups. Cancellation changes nothing. The new actions and cleanup behavior supersede the former add/remove pair. | Offline action/cancellation tests and in-game checks. |
| AC16 | The temporary DEV/debug priority watcher runs only with diagnostic logging on, records baseline and subsequent saved/actual priority changes, mismatches and recovery, and never enforces rank 1 or changes matching/order. With logging off it performs no watcher queries or alerts. | Focused logging-gate/change-detection tests and in-game reorder/recovery checks. |
| AC17 | Real custom groups exercise single, multiple and negative FCO markers and mixed name/marker conditions with OR inclusion and exclusion vetoes. They use the normal tracker scan/render paths; visible slideshow behavior fails. | Offline truth-table, scan/index/notification/AutoCategory equivalence and group lifecycle tests; in-game counts, Suspend/Resume/Turn off and smoothness observations. |

## Options and product decisions

| ID | Decision | Evidence / status |
|---|---|---|
| D1 | Promote the demonstrated implementation with minimal algorithm changes, rather than implement the old aspirational combined plan. | Tim, 24 November: "back end - the proven stuff we have done"; "Don't spec anything we don't know how to do already". |
| D2 | Name this feature Scanning Refactor; eliminate freezing and prepare for FCO-driven group changes. | Tim's direction, 24 November. |
| D3 | Original proposal: every defined FCO marker as a hidden built-in. Superseded ultimately by D12-D13; not a current generation requirement. | Tim's initial direction, 24 November; revised during defaults discussion. |
| D4 | Historical deferral of arbitrary marker conditions and combinations; superseded for the backend by the 26 November amendment. Marker editing UI remains deferred. | Tim, 24 November: "they won't be able to combine them"; revised 26 November. |
| D5 | Preserve existing independent tracker hiding and AC participation, rather than introduce a new visibility mechanism. | Existing editor/AC contract; independent focused spec review passed. |
| D6 | Historical settings schema 14 decision; the 26 November shared-condition amendment requires a newer schema and retains downgrade protection. | Tim, 24 November: "14 then". |
| D7 | Whole-group inactivity, never partial evaluation of FCO/name conditions. The original simple checkbox is superseded by D9. | Tim, 24 November: "add that to the spec, and the on/off switch", following the mixed writ/name and future marker-exclusion examples. |
| D8 | Historically retained inactive rows in all three editors; superseded by the 25 November acceptance UI amendment, which omits them from Manage Groups and Manage Tracking. | Tim, 24 November: "good. put that in the spec as well. Also define what they look like when 'inactive' I suggest a pale grey colour?" |
| D9 | Replace the checkbox with Enable, non-destructive Suspend/Resume, and destructive Turn off; persist removal until explicit Enable. The original three-choice confirmation was superseded by the two-button warning agreed on 25 November. | Tim, 24 November: "maybe 'suspend fco' button, and 'Turn off'" and "yes - update that", agreeing the all-profile deletion warning. |
| D10 | Historical three-visible-defaults-on-Enable proposal; creation behavior superseded by D12. | Earlier defaults discussion, 24 November. |
| D11 | No spike-group recovery migration. Do not recover spike PvP or its settings/references. Q4 is closed as inapplicable; fresh creation is governed by D12. | Tim, 24 November: "the spike was a throw-away sv file we don't need to recover from it". |
| D12 | Create no groups by default or on Enable. Add a temporary Create test groups button under Debugging; remove it when FCO Integration delivers its creation UI. | Tim, 24 November: "create no groups by default put a button in debug to 'create test groups'. add removing this button to the spec of the fco integration section". |
| D13 | The explicit test button creates the three groups non-hidden and includes them at the top of AC Priority and Display in every container; this supersedes earlier AC-excluded test defaults. | Tim, 24 November: "the button will create the three groups, as non-hidden and at the top of the ac priority and display for all ac containers". |
| D14 | All three test groups start shown in the tracker, backpack only, grouped, Notify off. Add a temporary Remove test groups Debugging button to remove test groups and their owned references without turning integration off. | Tim, 24 November: "with item tracker - show in backpack, grouped no notify"; "we can have a 'remove test groups' button as well to strip them out". |
| D15 | Label the paired buttons Add test FCO groups and Remove test FCO groups. Each explains its effects in a Yes/No confirmation; No/dismissal changes nothing. These labels supersede earlier shorthand. | Tim, 24 November: "(add test FCO groups)" and "each with a dialog This will..... [yes][no]". |
| D16 | Temporarily retain DEV/debug AC priority-change diagnostics, gated by logging, not a hard-coded Deconstruct-first assertion. Remove with FCO Integration. | Tim, 24 November: "yes, only when logging is on, and watch priority changing". The original priority bug remains unexplained. |
| D17 | Enable/Resume require available FCO; Suspend and removal remain usable without it. Q6 closed. | Tim, 24 November: "can't enable it if not there. can suspend/remove it at any time". |
| D18 | Add requires Enabled/ready FCO; test-group actions affect the currently selected profile only, across all its AC containers, without automatic changes to other/new profiles. Q7-Q8 closed. | Tim, 24 November: "agreed on both", accepting the two review clarifications. |

## Feasibility and actual evidence

Inspected source baseline: `383644c` on `spike/fco-itemsaver`.
The [spike results](<../../Archive/FCOItemSaver/Spike/002 FCOItemSaver - Results and Decisions.md>)
retain benchmark history, decisions D38-D45, mismatch investigations and
earlier approvals.

- Prepared batched marker reads, slot-index rebuilding, dirty replay and
  sliced polling are implemented. They are not new research tasks.
- Tim reports on 24 November that the system is "very smooth and faster than
  it was before fco". This is positive spike evidence, not formal production
  acceptance or proof that all correctness cases pass.
- The spike registry had four visible groups. Production uses ordinary custom
  groups created by the explicit test actions, not fixed-marker built-ins;
  the spike's marker-17 PvP mapping is not a universal default.
- Spike SavedVariables are disposable and are not a group-recovery source.
  Custom marker creation in the normal group editor remains deferred.
- The last recorded combined offline run passed 343/343 tests at the spike
  baseline. This is historical evidence; current production verification and
  independent review results are recorded in the implementation plan.

## Independent spec review

Reviewer: independent `design-review` rubber-duck agent, 24 November
Reviewed document revision/source identity: working documents on
`feature/scanning-refactor`, base `69596b0`; preserved spike `16c31c2`.
Findings: Add lifecycle eligibility and profile scope needed Tim (plan Q7-Q8),
resolved by D18.
Technical corrections: precise schema migration, saved/actual AC ordering,
DEV-only watcher eligibility and completion-ordered reports are recorded in
the plans, including profile-local created-state storage.
Status: focused independent re-review PASS (`focused-design-check`,
24 November); Tim's conditional approval/implementation GO is effective.

## Approvals and acceptance

- Product scope direction: Tim, 24 November; this document records the split.
- Explicit spec approval: Tim's conditional approval effective after the
  independent focused design review passed, 24 November.
- Implementation acceptance: Tim, 26 November; accepted as done.
- Production evidence: 352/352 offline tests and independent review passed;
  Tim reported the in-game groups and lifecycle checks worked without noticed
  slowness. Specific overlapping cases lack explicit evidence; the known
  tracker mismatch remains a logging-monitored risk.
- Final-acceptance schema-15 migration from an actual older-schema DEV backup:
  PENDING, deferred by Tim to final acceptance testing.

Spec approval does not authorize coding; see the plan's separate gates.
