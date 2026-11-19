# Post implementation bug fixes

Feature: [Currency grid columns and scene layouts](../../FeatureSpecs/CurrencyGridColumnsFeatureSpec.md)

Status: IMPLEMENTED AND RELEASED in 1.7.2; UAT passed 2026-11-19.
The release review records `/ictest verbose copy` passing 88/88, successful
schema-10 migration checks, and the author's confirmation of migrated settings,
normal positions, and normal transfer tests. The review is retained inside the
frozen 1.7.2 package.
This document supersedes the original plan's entry-only placement and immutable
user-position rules for these corrections.

## 1. Bank deposit hides panels

- **Reported by Tim, 2026-11-17:** bank withdrawal shows the panels, but deposit
  does not.
- **Expected:** normally visible panels remain visible on both bank tabs.
  Withdrawal and deposit share the same bank positions.
- **Original defect:** `Tracking\PanelLayout.lua` resolved the bank context only
  while `ZO_PlayerBank` is visible. Unlike merchant contexts, banking has no
  related-control mapping to recognize an inventory-based deposit view.
- **Investigation result:** public ESOUI source confirms withdrawal controls
  swap for inventory on deposit in bank, house bank and guild bank. Detection must
  retain the logical bank context across tab switches rather than reverting
  to the normal layout.
- **Verification:** open each bank tab directly, switch both ways, drag a panel,
  close/reopen the bank, and check shared bank positions, visibility and
  restoration of normal positions.

## 2. Wider settings windows overlap panels

- **Reported by Tim, 2026-11-17:** settings windows vary in size; the addons
  panel is substantially wider and can overlap IC panels.
- **Superseded contract:** automatic placement ran only on scene entry. The
  controller does not reconsider obstacles when settings windows change
  within the same logical settings visit. This implements the earlier agreed
  entry-only behavior, but does not meet the newly requested overlap response.
- **Requested adjustment:** move affected panels when a settings window would
  overlap them.
- **Implementation:** reuse the existing 100 ms ticker to detect relevant
  obstacle changes only while a supported scene is active. No additional
  listener or timer is required. Reposition only when a
  relevant change creates overlap, not on every tick.
- **Verification:** switch between narrow settings, the wider addons panel and
  addon settings; check overlap avoidance, no repeated movement when unchanged,
  dragging, and restoration on exit.

### Agreed behavior

- Tim authorized missing-scene fixes and live UI/panel-size overlap correction
  on 2026-11-17, confirming temporary correction of manually saved positions:
  "yes I think that works".
- Corrections never overwrite saved coordinates and never interrupt dragging.
- Keep unobstructed current positions rather than restoring them on narrowing;
  start from saved/default positions on the next visit. This avoids unnecessary
  movement and follows the existing leave-unobstructed-panels rule.

## 3. Furniture vault hides panels

- **Reported by Tim, 2026-11-17:** opening the furniture vault hides the panels.
- **Expected:** panels that would be visible normally remain visible while
  using the furniture vault.
- **Investigation result:** public ESOUI source identifies scene `furnitureVault`
  and withdrawal control `ZO_FurnitureVault`; deposit uses inventory. Keep its
  own layout identity rather than sharing bank or inventory positions.
- **Verification:** open/close the vault, exercise its available tabs, and check
  panel visibility, obstacle avoidance and restoration of normal positions.

## 4. Reopening scenes undoes deliberately stacked bars

- **Reported by Tim, 2026-11-18:** tightly stacked bars are repositioned when
  inventory is reopened because correction treats IC overlap/spacing as an
  obstruction.
- **Approved rule and GO:** "record that and do it". Leave existing IC-to-IC
  overlap and touching edges alone. A ZOS obstacle must actually overlap a
  panel, not merely approach within padding, to trigger correction. Retain
  existing screen-boundary safety and runtime-only correction.
- **Implementation:** give the shared rectangle intersection helper explicit
  padding: zero for deciding whether ZOS obstructs an existing position, five
  for finding new automatic positions. Remove IC-to-IC obstruction as a reason
  to displace an existing panel. Still reserve retained IC panels when placing
  a panel displaced by ZOS or screen bounds.
- **Verification:** overlapping saved layouts survive scene re-entry and panel
  growth; exact edge contact and sub-5px ZOS gaps stay untouched. Actual new
  ZOS overlap still triggers correction without overwriting saved coordinates.
- Focused layout tests passed. Final full suite passed 243/243, including Lua 5.1
  compilation/XML checks; `git diff --check` passed.
- Independent `stacking-correction-review` found a related fallback defect:
  new automatic positions ignored retained IC panels when checking fallback
  candidates. Fixed by preferring candidates clear of both ZOS and retained
  panels, then ZOS-clear candidates if IC overlap is unavoidable. Added both
  regression cases. Focused independent `stacking-fallback-check` found no
  significant issues in the correction.
- In-game stacking retest: Tim confirmed "that works nicely" on 2026-11-18
  after retesting the stacking correction. This does not certify the full
  feature acceptance checklist.

## Related idea: shared layout groups

Tim is considering sharing inventory and bank positions, potentially grouping
screens by left-side versus right-side ZOS UI instead of individual scenes.
This is not yet an agreed requirement or a confirmed bug.

Before changing the feature spec, agree which screens share a group and how
existing differing scene positions are preserved or selected. Keep bank
withdrawal/deposit sharing distinct from this broader proposal.

## Focused implementation plan

1. **Scene detection:** extend `Tracking\PanelLayout.lua`'s related-control map
   for bank, house bank and guild bank with their withdrawal control and
   `ZO_PlayerInventory`, plus their menu controls. Both tabs retain the same
   logical key. Add `furnitureVault` with `ZO_FurnitureVault`,
   `ZO_PlayerInventory` and `ZO_FurnitureVaultMenu`; use its own
   `Layout_FurnitureVaultScene` position set.
   Public ESOUI `inventory.lua` confirms all four interactions swap their
   withdrawal fragment for `INVENTORY_FRAGMENT` on deposit while retaining the
   same scene. `inventory.xml` confirms `ZO_PlayerBankMenu`,
   `ZO_HouseBankMenu`, `ZO_GuildBankMenu` and `ZO_FurnitureVaultMenu`.
   Include `ZO_AddOns` in settings obstacle collection/detection:
   public `zo_addonmanager.lua` creates that control from the wider
   `ZO_AddOnManagerTemplate`, distinct from the LAM addon-settings window.
2. **Shared geometry observation:** extract visible-obstacle collection from
   `EnterContext`. During supported scenes, `UpdateContext` uses the existing
   100 ms ticker to compare a runtime snapshot of ZOS obstacle identities/bounds,
   screen dimensions, and normally visible registered panels' dimensions.
   No geometry scanning in normal context and no new listener/timer.
3. **Correction:** separate placement from scene entry. On entry, load
   saved/default positions; on geometry changes, use current runtime positions.
   Retain unobstructed panels and move only obstructed/off-screen panels using
   existing deterministic right/left/stagger geometry. Include other visible IC
   panels as placement obstacles, not reasons to displace existing positions.
   Use actual unpadded ZOS overlap for the correction trigger. Saved scene positions participate in correction rather
   than being exempt. Apply anchors only where coordinates actually change.
   Do not reapply every panel's anchors on unchanged ticks.
4. **Drag/profile/reset lifecycle:** skip same-context geometry correction while
   dragging, leaving changed geometry pending until drag completion. Actual
   context/profile transitions still cancel the drag as before. Move-stop alone
   persists coordinates. Normal restoration and profile changes retain their
   existing ownership. Position resets use the same complete obstacle collection
   as ordinary placement, without resetting or saving other panels' positions.
5. **Saved data:** add the vault key to `knownSceneLayouts` in
   `Tracking\ItemDatabase.lua` so existing validation, character-specific helpers
   and panel resets cover it. Keep schema 11: the supported released schema-10
   reader already rejects it, and schema-11 handling preserves unknown layout
   tables during preparation/full copying. No structural migration is needed
   for this additional sparse scene key; test preservation and vault reset.
6. **Verification/documentation:** update `Project\Tests\PanelLayoutTests.lua`
   for bank/vault tab transitions, missing scenes, settings obstacle switching,
   panel growth, no anchor writes when unchanged, drag deferral, saved-position
   preservation and normal restoration. Extend existing saved-layout tests for
   vault validation/copy/reset. Run focused tests, then the full existing runner
   and `git diff --check`. Update the user manual's entry-only claims.
   Obtain independent code review before requesting client retesting.

## Follow-up trial: Snap on release

Baseline: `523c7ff`. Tim requested a clean-branch prototype on
`test/shift-snap-on-drop`. After in-game feedback, the follow-up switched to
snapping by default, Shift for exact positioning, and overlap correction
beyond the regular snap range. On 2026-11-18 Tim said "this is really good now"
and authorized committing and merging the result into `main`. This does not
certify unrelated in-game checks or migration UAT.

- In `Tracking\PanelLayout.lua`, keep `OnMoveStart` and the cancellation
  path unchanged. In `OnMoveStop`, after validating the drag context, read
  `IsShiftKeyDown()` once. If held, preserve the raw drop. Otherwise consider
  only other visible registered panels' actual bounds. In
  `Banking\ResourceProgressBars.xml`, the bar rectangle now covers the
  full icon, gap, and track (234 px rather than 228 px).
- Try matching edges or 5 px docking,
  optionally aligning the perpendicular edge to the same target. Start with
  a 12 px maximum Euclidean displacement for the trial. For alignment-only
  candidates, require the rectangles to be within that distance on the
  other axis too, so distant panels with matching edges do not attract a
  drop. Prefer aligned docking, then plain docking, then alignment alone, so
  a nearby perpendicular edge does not prevent stacking. Within each
  preference choose the closest valid candidate, breaking target ties by
  existing panel order. Reject off-screen candidates and actual ZOS overlap
  by measuring the current scene's visible obstacles at release, not using
  a potentially stale ticker snapshot. For a drop already overlapping IC,
  compare the four sides of each overlapped panel without the 12 px cap
  or secondary-axis realignment. Choose the shortest move that clears all
  visible panels and ZOS UI while staying on-screen. If none fits, retain the
  drop. Shift bypasses correction for intentional stacking.
- Apply the selected position to the dragged control only and save it once
  through `SavePanelLayout`. No new handler, ticker, persisted option, or
  schema change.
- In `Project\Tests\PanelLayoutTests.lua`, cover exact Shift drops, default
  alignment and docking, overlap beyond the regular snap range, alternate
  edges when blocked, ineligible targets, canceled drags, and layout saves.
  The full offline suite passed 246/246, including these snapping tests.

## Implementation and review

- Addon changes: scene mappings, shared obstacle collection, geometry snapshots,
  temporary overlap correction and vault layout validation/reset implemented.
- Focused independent spec/plan review: `scene-amendment-review`, 2026-11-17,
  current working-tree amendment and spec; no blocking findings. Its optional
  request to resolve stale investigation bullets has been incorporated.
- Amendment approval and separate GO: Tim, 2026-11-17, "start", following the
  explanation that updated spec/plan approval and GO were the remaining gates.
- Regression tests: focused 10/10 passed; final full
  `python Project\Tests\Run-RuleTests.py` passed 240/240, including Lua 5.1
  compilation and XML checks. `git diff --check` passed.
- Independent code review: `scene-fixes-code-review`, 2026-11-17, current
  controller, vault-key addition, related tests and user documentation;
  no significant issues found.
- No live SavedVariables files were modified and no client reload performed.
- In-game acceptance: pending.
- This record does not authorize release work.
