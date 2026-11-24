# Scanning Refactor: feature spec

Status: DRAFT - scope directed by Tim; independent review and approval PENDING
TODO item: None; production promotion of the FCO ItemSaver feasibility spike
Owner: Copilot
Updated: 2026-11-24
Implementation plan: [implementation plan](<002 ScanningRefactor - Implementation Plan.md>)

## Overview / proposed changelog text

- **Smoother item tracking.** Inventory Companion reuses its inventory and
  matching work, updates changed slots promptly, and spreads background
  inventory checks across frames. The aim is to eliminate scan-induced
  freezing, including when several groups match the same items.
- **Optional FCO marker groups.** With FCO ItemSaver installed, each defined
  marker has its own built-in group, initially hidden. Show the groups you
  want in Manage Groups; rename them and add Include/Exclude name patterns
  with the existing editor. Each group keeps its single underlying marker.
  Combining markers, such as Gear 1 through Gear N, comes later.

This is draft release wording, not a claim of publication or completed UAT.
Follow the [feature development process](../../../Processes/FeatureDevelopment.md).

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
- One built-in group for every marker defined by the installed FCO version,
  including its numbered/dynamic markers. All new groups start hidden.
- Existing name-pattern editing, rename, display settings, reset and
  AutoCategory participation for those built-ins.
- Preservation of user profiles, group edits and AutoCategory orders;
  migration/downgrade protection; production removal of spike-only coupling.

Out of scope:

- A marker picker or marker-condition rows in the group editor.
- Adding/changing marker conditions in custom groups or per-group overrides.
- Combining markers, marker ranges, or a Gear 1-to-N aggregate group.
- Marker exclusion conditions. Existing Exclude **name patterns** remain.
- Writing FCO marks, reading its private storage as the production matching
  algorithm, or hooking its marking functions.
- New automatic startup retry/deferral behavior, wider bag/gamepad support,
  or a rewrite of rendering/scheduling that has not been demonstrated.
- Reimplementing the [diagnostic logging framework](<../DiagnosticLogging/001 DiagnosticLogging - Specification.md>).

The deferred editor/composition work belongs to
[FCO Integration](<../FCOItemSaver/001 FCOItemSaver - Specification.md>).

## User experience and behavior

### Tracking

- Slot events are coalesced and applied on the next scheduled frame, without
  waiting for a full rescan.
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

### Single-marker built-in groups

- Each FCO marker ID has a stable IC group identity independent of its label.
  Dynamic marker 17 must not be universally called "PvP"; use the user's
  FCO marker label. Distinguish unlabeled markers by their marker ID.
- "Defined" includes disabled FCO markers, not just markers currently enabled
  or present on an item. A disabled marker remains unavailable for marker
  matching; showing an IC group does not enable that marker in FCO.
- New groups use the existing group hidden state. They remain discoverable
  through the editor's existing hidden-group controls. This does not reset
  visibility already selected by the user or overwrite an edited group.
- The user can show a group, rename it, add Include/Exclude name patterns,
  adjust ordinary display options, and reset its edits using existing UI.
  Reset returns a new FCO built-in to its hidden baseline.
- Matching remains: **any Include name pattern OR the group's one FCO
  marker**, vetoed by **any Exclude name pattern**. Renaming or replacing
  the name-pattern list does not remove/change the built-in marker.
- Markers match backpack, bank and subscriber-bank slots, as in the spike.
  Name patterns retain existing bag coverage, including the Craft Bag.
- AutoCategory participation remains separate from tracker visibility.
  New marker groups are not automatically included in AutoCategory; users
  opt in through Manage AutoCategory. Existing per-area inclusion, Display
  and Priority orders are preserved.

### Optional dependencies and errors

FCO and AutoCategory remain optional. Without FCO, ordinary name matching
continues and saved FCO-group edits are preserved. Unavailable markers do not
match; name patterns still do. Report availability changes at the external
boundary rather than claiming a successful marker read.

Preserve the tested empty-slot handling and explicit AutoCategory failure /
Retry Sync behavior, including cache clearing on retry. Do not promise
automatic recovery that is not implemented. Internal contract violations
must still throw near their cause.

## Preservation and compatibility

- Preserve names, patterns, exclusions, counts, item-source selection,
  tracked-item rescue behavior, profiles and ordinary non-FCO workflows.
- The index and scan-local caches are runtime state, never saved state.
  Do not introduce a persistent inventory cache.
- Migrate all affected profiles and retained backups before ZOS constructors.
  Preserve spike group edits and AutoCategory references when assigning
  production identities. Do not silently drop collisions or unrelated data.
- Use production settings schema **14 for both DEV and release**, with
  downgrade refusal before mutation. Preserve supported older migrations,
  including normal schema 11 and spike schemas 12/13. This is separate from
  diagnostic-log schema 2; see the plan for migration and reader checks.
- A real older-schema backup migration test is required before release.

## Acceptance criteria

| ID | Required observable result | Verification and environment |
|---|---|---|
| AC1 | With FCO absent and with no FCO groups shown, existing name-only rules, tracked items, group counts and profile behavior remain correct. | Offline snapshot comparisons and in-game smoke checks. |
| AC2 | A burst of slot events produces one coalesced next-frame update; an active top-up continues and replays dirty slots before adoption. | Offline scheduler tests; in-game pickup/move/crafting observations. |
| AC3 | Top-ups use the existing cooperative 8 ms target and deferred rendering; polling uses the existing 2 ms target. Heavy overlapping-group activity causes no observed scan-induced freezing or performance regression against the working spike. | Offline scheduling checks; paired in-game observations/timing logs on the same workload. Record actual maxima, including finish and render costs; no unagreed hard 16 ms guarantee. |
| AC4 | Index rebuilds match fresh prepared scans for removals, gains, count changes, overlapping rules and marks; stale-context jobs never replace current results. | Offline equivalence/context tests and investigation of in-game mismatch logs. Known crafting/full-update discrepancies are not waived by smoothness. |
| AC5 | Mark/unmark changes without slot events reach the tracker through polling; polling stops when hidden/in `hud` and resumes in eligible scenes. | Offline and in-game tests; include an external marking UI when available. |
| AC6 | The installed FCO marker range produces exactly one stable built-in per ID, all new groups hidden and not automatically included in AC. Disabled markers remain represented but unavailable. | Offline generated-registry/default tests and in-game editor checks. |
| AC7 | Showing, renaming, editing Include/Exclude name patterns and resetting a built-in work through existing UI; each retains only its own marker and survives profile copy/switch/reload. | Offline editor/profile tests and in-game checks. No marker-composition control is present. |
| AC8 | Optional-dependency failures are reported without breaking ordinary name matching; empty-slot queries are unmarked; Retry Sync repairs AC assignments/cache without changing saved priority. | Offline boundary tests and in-game backpack/bank checks. |
| AC9 | Every affected saved profile migrates without lost edits/orders; malformed data and identity collisions are reported; older readers refuse the new schema unchanged. | Offline migration/downgrade tests and actual older-backup UAT with approved safeguards. |
| AC10 | Production scanning runs without the spike module or DEV flags; benchmark commands/tripwire code are not production dependencies. | Offline release-mode runtime tests and manifest/source review. |

## Options and product decisions

| ID | Decision | Evidence / status |
|---|---|---|
| D1 | Promote the demonstrated implementation with minimal algorithm changes, rather than implement the old aspirational combined plan. | Tim, 24 November: "back end - the proven stuff we have done"; "Don't spec anything we don't know how to do already". |
| D2 | Name this feature Scanning Refactor; eliminate freezing and prepare for FCO-driven group changes. | Tim's direction, 24 November. |
| D3 | Include every defined FCO marker as a separate hidden built-in, editable through ordinary name/display overrides. | Tim, 24 November: "all fco markers defined", "start hidden", "change the names etc." |
| D4 | Defer arbitrary marker conditions and combinations, including Gear 1-to-N. | Tim, 24 November: "they won't be able to combine them". |
| D5 | Preserve existing independent tracker hiding and AC participation, rather than introduce a new visibility mechanism. | Existing editor/AC contract; independent spec review PENDING. |
| D6 | Settings schema 14 for both DEV and release, preserving supported older migrations and verifying downgrade refusal. | Tim, 24 November: "14 then". |

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
- The current registry has four visible spike groups. All-marker generation,
  hidden defaults, production extraction and migration remain work to do.
- The last recorded combined offline run passed 343/343 tests at the spike
  baseline. No production-promotion tests or independent reviews have run.

## Independent spec review

Reviewer: PENDING
Reviewed document revision/source identity: PENDING
Findings and Tim's decisions: PENDING

## Approvals and acceptance

- Product scope direction: Tim, 24 November; this document records the split.
- Explicit spec approval: PENDING
- Feature acceptance: PENDING
- Production acceptance evidence: PENDING

Spec approval does not authorize coding; see the plan's separate gates.
