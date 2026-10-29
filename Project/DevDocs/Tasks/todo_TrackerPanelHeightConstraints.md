# A1: Tracker Panel Height Constraints

**Status:** Proposed; planning only, no runtime changes.

**First-round implementation map:** [Implementation plan](ImplementationPlan_TrackerPanleHeightConstraints.md).
Sections F and G are outside the first round; their decisions are deferred and
do not block base A1 implementation.

> [!IMPORTANT]
> **DECISIONS NEEDED:** Outstanding product choices are marked
> **🔴 [DECISION NEEDED]** below. Confirmed choices are marked **[AGREED]**.
> Decisions in sections F and G are deferred beyond the first round.
> Implementation/test checkboxes track work, not product approval.

## A. Goal

When expanding a group would make the item tracker taller than a configurable
limit, collapse the other expanded groups and keep the active group open.
Preserve normal multi-group expansion when the resulting panel fits.

## B. Current Behavior and Relevant Code

- [Tracker rendering and interaction](../../../Tracking/ItemTrackerPanel.lua):
  group clicks save `isExpanded` through `SetRuleFlag`, then refresh the panel.
  `BuildDisplayList` chooses flat or grouped presentation and folds single-member
  and ungrouped entries into Miscellaneous.
- `RenderPopulatedRows` lays out count columns and name widths before determining
  row heights. Wrapped names can make rows taller than the usual 22 UI units.
- `ApplyBoundedPosition` moves the finished panel upward to avoid the screen
  bottom, but cannot make an oversized panel fit.
- [Tracker XML](../../../Tracking/ItemTrackerPanel.xml): the panel and container
  use `resizeToFitDescendents`; there is currently no scroll viewport.
- [Account defaults](../../../Core/Constants.lua) and
  [LAM settings](../../../Core/Settings.lua) own tracker preferences.
- [Rule mutations](../../../Tracking/ItemDatabase.lua) provide delta-only
  persistence and cache invalidation. `GetActiveTrackedRules` returns view copies;
  changing those copies does not persist expansion state.
- [Initialization](../../../Core/Init.lua) loads saved variables before creating
  the tracker. Validate the new preference at this boundary.

## C. UX Contract

**[AGREED FOR NOW]** Keep the suggestions in this section as the working policy.
The optional follow-inventory-changes idea formerly discussed under C5 (C5b) is
deferred to extension G, not included in the base behavior.

- **C1.** Add an account-wide **Tracker Maximum Height** slider to the existing
   **Item Tracker Panel** settings submenu.
   - **[AGREED] Default for now: 600 UI units.**
   - **[AGREED] Maximum: allow the full current screen height**, using
     `GuiRoot:GetHeight()`, rather than a fixed 1200-unit ceiling.
   - **[AGREED FOR NOW]** Minimum: **200 UI units**, with **20-unit** steps. The exact
     full-screen endpoint must remain selectable even when the screen height
     is not a multiple of the step.
   - Use ESO's resolution-independent UI coordinates, not physical display
     pixels: a height of 200 remains 200 UI units regardless of PC resolution.
     Do not convert or rescale the saved height when resolution changes; the
     game handles resolution scaling.
   - Effective limit: the smaller of the configured value and `GuiRoot` height.
   - Explain in the tooltip that the limit triggers group collapsing; it is not
     a hard clipping boundary.
- **C2. [AGREED FOR NOW]** Keep multiple groups expanded when the full rendered height is at or below
   the effective limit. Equality must not trigger collapsing.
- **C3. [AGREED FOR NOW]** If an expansion exceeds the limit, keep the clicked group expanded and
   collapse **all other currently rendered expanded groups**, not just enough
   groups to fit. Leave hidden/non-rendered groups' saved flags unchanged.
- **C4. [AGREED FOR NOW]** Persist automatic collapses using the same rule setter as manual collapses.
   They remain collapsed after refresh/reload and do not reopen automatically
   when inventory shrinks or the limit increases.
- **C5. [AGREED FOR NOW]** Apply the same check after inventory/filter/wrapping changes, lowering the
   limit, initial load, and tracked-list/profile changes.
   - Prefer the last explicitly expanded group if it is still rendered and
     expanded in the current profile.
   - Otherwise retain the first rendered expanded group in existing display
     order. Never use unordered table iteration to choose it.
   - Expansion priority is transient and scoped to the current tracked-list
     context; switching/importing/resetting profiles must not inherit stale
     priority. No new saved "active group" field is needed.
- **C6. [AGREED FOR NOW]** Manual collapse never forces a different group open. Flat-list mode has no
   groups to collapse and retains its current behavior.
- **C7. [AGREED FOR NOW]** Preserve existing screen clamping, drag behavior, saved position, editor
   avoidance, and interaction positioning.

### C8. Limit That Collapsing Cannot Satisfy

> [!NOTE]
> **[AGREED FOR NOW]** Allow remaining overflow in Collapse categories mode.
> Scrolling is a separate extension, not an automatic fallback in this mode.

A single expanded group, the remaining group headers, or a flat list may already
exceed the limit. Working A1 scope: keep the active group and every item
accessible as today, allow residual overflow, and document this limitation.
Do not silently truncate rows, hide other group headers, reject the expansion,
or repeatedly collapse/reopen the active group.

The requested scrolling extension is recorded in section F. The collapse
behavior above remains the base A1 policy; Scroll mode would provide a strict
maximum instead. Collapse categories mode allows irreducible overflow under the
current working policy.

## D. Implementation Checklist

### D1. Confirm Settings and Overflow Policy

- [x] Accept the section C suggestions as the working policy for now, including
      slider range, persistence, passive refresh, and residual overflow.
- [ ] Check the branch/worktree before implementation. This touches rendering,
      persisted rule flags, and settings; recommend a separate branch and obtain
      approval before switching. Planning alone does not require a branch.

### D2. Add the Preference

- [ ] Add `trackerMaxHeight` to account defaults and a LAM slider alongside the
      existing tracker display settings. Refresh immediately when it changes.
- [ ] Validate externally editable saved values once during initialization:
      require a finite numeric value in the agreed persisted range. Store UI
      units directly, without resolution-specific conversion or migration.
      Missing values use the documented default; malformed values must produce
      an explicit diagnostic rather than a silent fallback. Preserve unrelated
      saved data and follow the project's fail-fast boundary policy.
- [ ] Do not change the saved-variable version or migrate tracked rules merely
      to introduce this independent account-wide preference.

### D3. Track the Expansion Intent

- [ ] Pass the clicked rule identity into the refresh/layout operation when
      expanding; keep existing no-argument refresh callers working.
- [ ] Remember the last explicit expansion only within the current tracked-list
      context. Clear/invalidate it for profile switches/imports/resets, or use a
      context identity/revision that makes stale priority impossible.
- [ ] Resolve the retained group from the actual grouped display list, including
      Miscellaneous, rather than raw rules that may not render.
- [ ] Reuse `SetRuleFlag` for both manual and automatic expansion changes. Do
      not write saved tables or cached/view rules as a substitute.

### D4. Enforce the Threshold in One Bounded Layout Pass

- [ ] Build the inventory snapshot and candidate display list once per refresh.
- [ ] Lay out candidate rows using the existing count-width, name-width,
      wrapping, spacing, and row-height calculations.
- [ ] Measure the full panel, including title, first-row gap, inter-row gaps,
      container offsets, and backdrop extents. Verify ESO's
      `resizeToFitDescendents` measurement timing in game; do not assume hidden
      controls or a just-updated parent report final dimensions.
- [ ] If the candidate exceeds the effective limit and other rendered expanded
      groups exist, select the retained group and collapse the others.
- [ ] Rebuild the final row list from the already collected display data and
      relayout it once. Recompute shared column/name widths: removing rows can
      change wrapping and therefore final height.
- [ ] Do not call `RefreshItemTrackerPanel` recursively, rescan inventory once
      per collapsed group, or use an unbounded shrink-until-fit loop.
- [ ] Persist only actual flag changes. Finish positioning using the final
      height, not the pre-collapse height.
- [ ] Verify pooled hidden rows stop contributing to measured size and that
      click handlers reflect the final row's group and expansion state.
- [ ] Keep helpers local to the tracker unless tests or existing consumers
      genuinely require a shared API; avoid a general-purpose layout framework.

### D5. Verify Automatically Without Live Data

- [ ] Add isolated layout/expansion tests using synthetic display data and
      mocked controls. Follow the existing Lua 5.1/Lupa test setup in
      [Run-RuleTests.py](../../Tests/Run-RuleTests.py), using a focused tracker
      suite rather than loading ESO-dependent behavior unnecessarily.
- [ ] Cover below/equal/above threshold and multiple groups fitting normally.
- [ ] Cover overflowing expansion retaining the clicked group and collapsing
      every other rendered expanded group; preserve non-rendered flags.
- [ ] Cover manual collapse, no expanded groups, Miscellaneous, flat-list
      threshold transitions, empty state, and an active group that disappears.
- [ ] Cover passive growth, lowered/increased limits, profile switches/imports,
      and reload selection without stale expansion priority.
- [ ] Cover multiline rows, spacing/title/padding, count-width changes, screen
      height below the configured limit, and irreducible overflow.
- [ ] Verify the slider permits the exact full screen height, including heights
      above 1200 UI units and heights not divisible by the slider step.
- [ ] Assert correct persisted deltas and unchanged unrelated profile/rule data.
- [ ] Assert bounded work: one snapshot acquisition and at most two layout
      passes per synchronous refresh. Use safe synthetic large inventories;
      never mutate live inventory or live saved variables for performance tests.
- [ ] Test malformed/missing preference values and slider-triggered refresh.
- [ ] Run the focused suite, existing rule/persistence regression tests, and Lua
      5.1 syntax validation for touched runtime files.

### D6. In-Game Acceptance and Documentation

- [ ] Test long groups in single-line and multiline modes at more than one UI
      scale. Confirm real measured height, not just row-count estimates.
- [ ] Expand two groups that fit, then a group that exceeds the limit. Confirm
      only that active group remains expanded and other headers stay clickable.
- [ ] Test wrapped names/count changes near the exact threshold and check for
      flicker, repeated refreshes, oscillation, or stale +/- icons.
- [ ] Test near the bottom of the screen and during bank, chest, store, fence,
      inventory, and editor interactions; preserve drag and position behavior.
- [ ] Test zero filters, group threshold changes, Miscellaneous, profile
      switching/import, `/reloadui`, and hide/show of the panel.
- [ ] Confirm residual overflow matches the agreed policy, or verify scrolling
      separately if a strict cap was selected.
- [ ] Update [UserManual.bbcode](../../../UserManual.bbcode) with the setting, automatic
      collapse persistence, and any overflow limitation. Update the A1 entry and
      completion record only after implementation and recorded verification.

## E. Completion Criteria

A1 is complete when the selected overflow contract is implemented, fitting
multi-group layouts retain their behavior, overflowing expansions retain the
intended active group, persistence remains delta-only and profile-correct, and
both isolated regression tests and real-client layout acceptance have passed.
Until client acceptance, record implementation and automated results separately
from final verification.

## F. Extension: Choose Large-Panel Behavior

**Status:** Requested extension to the plan; not yet implemented.

### F1. Settings and Mode Behavior

- **F1a. [AGREED] Setting:** Add an account-wide **What to do when the panel is large**
  choice alongside **Tracker Maximum Height**, with **Collapse categories** and
  **Scroll** options.
- **F1b. [AGREED FOR NOW, per C3] Collapse categories:** use the base A1 behavior in section C, keeping the
  active group expanded and collapsing the other rendered expanded groups when
  the height exceeds the threshold.
- **F1c. 🔴 [DECISION NEEDED] Scroll preserves expansion:** Keep existing group expansion choices
  unchanged by height enforcement; do not automatically collapse groups.
- **F1d. 🔴 [DECISION NEEDED] Scroll height:** Grow the panel naturally up to the configured maximum,
  then scroll the item area.
- **F1e. 🔴 [DECISION NEEDED] Maximum measures the whole panel:** The maximum
  includes the fixed header and panel padding, not just the scroll viewport.
- **F1f. 🔴 [DECISION NEEDED] Manual controls:** Manual group expansion/collapse continues to work in
  either mode.
- **F1g. 🔴 [DECISION NEEDED] Switching to Scroll:** Selecting Scroll must not restore groups
  previously collapsed manually or automatically.
- **F1h. [AGREED] Default:** Collapse categories, preserving the
  base A1 policy.
- **F1i. [AGREED FOR NOW, per C8] Collapse-mode overflow:** Allow residual overflow in Collapse
  categories mode; a scrolling fallback is not implied by
  selecting that mode.

### F2. Scroll Layout and Interaction

> [!IMPORTANT]
> **🔴 [DECISION NEEDED]** The UX details below are proposed, not yet confirmed.

- Keep the title and edit button fixed outside the scrolling item area.
- Reuse ESO's `ZO_ScrollContainer` pattern already used in
  [the item editor](../../../Tracking/EditPanelItemsTab.xml) and
  [the group editor](../../../Tracking/EditPanelGroupsTab.xml).
- Replace unrestricted panel auto-height with natural sizing capped at the
  configured maximum in Scroll mode. Keep shorter panels compact.
- Support scrollbar dragging and mouse-wheel scrolling without breaking group
  clicks, the context menu, or panel dragging.
- Account for scrollbar width when laying out counts and wrapped item names.
- Keep the clicked group header visible after expansion; preserve the scroll
  position on routine refreshes where possible and clamp it when content shrinks.
- Reset inappropriate scroll state on profile changes and handle mode switching
  without stale anchors, clipped rows, or unintended expansion-flag writes.

### F3. Extension Implementation and Acceptance

- [x] Confirm the default mode: **Collapse categories** (F1h).
- [x] Accept residual overflow in Collapse categories mode for now (C8).
- [ ] Add and boundary-validate the account-wide mode preference, and refresh
      immediately when the setting changes.
- [ ] Separate the collapse policy from the common row layout so Scroll mode
      does not run automatic-collapse mutations.
- [ ] Implement the capped viewport and fixed header using existing ESO controls.
- [ ] Add isolated tests for both modes, switching modes, short/tall content,
      wrapping with a scrollbar, and scroll-offset clamping after removals.
- [ ] Verify in game that a single oversized group and an oversized flat list
      remain fully accessible in Scroll mode without exceeding the maximum.
- [ ] Test wheel/scrollbar input, panel dragging, header/edit/context-menu access,
      clicked-group visibility, profile switches, and interaction positioning.
- [ ] Document the two modes and their differing treatment of oversized content.

## G. Extension: Follow Inventory Changes (Formerly C5b)

**Status:** Deferred option to consider; not part of base A1.

- **G1. 🔴 [DECISION NEEDED] Optional setting:** "Follow inventory changes" could
  open the group containing an added or removed item and give it priority over
  the last explicitly expanded group.
- **G2. 🔴 [DECISION NEEDED] Burst handling:** Decide how changes affecting
  multiple groups select a winner and avoid disruptive repeated
  opening/collapsing.
- **G3. Proposed visibility constraint:** Respect existing visibility and
  zero-item filters; do not reopen a group that is no longer rendered.
