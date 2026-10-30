# Item tracker editor flags and row options

Status: Planned; implement this editor improvement before AutoCategory integration. No runtime changes made by this plan.

Related feature: [AutoCategory integration](todo_plan_autocategoryIntegration.md).

## Goal

Make the item tracking editor easier to understand and leave room for additional per-row settings without continually adding columns or shrinking text.

Replace the existing Group / Totals / Show / Notify row controls with quick Show and Notify toggles plus one discoverable Options control. Keep current behaviour and saved values intact while improving their presentation.

## Proposed layout

```text
Item or group name                     Show   Notify   Options...
```

Show and Notify remain one-click toggles. Options opens a compact checkbox panel anchored to that row's button, rather than a second full editor window.

Initial panel:

```text
Options for <item or group name>

Tracker
[ ] Include banked items
[ ] Group items together       (group rows only)
```

- Rename **Totals** to **Include banked items**.
- Rename **Group** to **Group items together**.
- Show the grouping option only on group/rule rows, preserving the existing individual-item restriction.
- Use normal readable fonts; do not reduce font size to squeeze more columns into the row.
- Use an explicit Options label/button rather than a changing summary as the sole entry point. A tooltip may summarize current settings.
- Treat wording and exact dimensions as a mockup to verify before implementation, not a reason to redesign unrelated editor layout.

## Scope of the first implementation

- Move the existing `bank` and `group` flags into the panel using the existing mutation/persistence paths.
- Preserve the existing Show and Notify semantics, defaults, inheritance/overrides, filters, and account/character selection.
- Changes take effect immediately, consistent with current flag toggles; do not add an Apply/save transaction.
- Preserve existing group-selection/bulk-edit behaviour. Investigate how current row actions propagate before wiring popup actions; do not accidentally change their target set.
- No new saved fields or schema changes are necessary for moving/renaming these controls.
- Do not change bank scanning, item matching, tracker layout/height policy, or saved expansion preferences.

## Future panel sections, not initial functionality

### AutoCategory

When the [integration](todo_plan_autocategoryIntegration.md) works, add:

```text
Inventory categories
[ ] Create AutoCategory group  (group rows only)
```

The author has confirmed AutoCategory participation is group-row-only. Its flag is independent of tracker Show, Group items together, and expansion state. Do not display a working-looking checkbox or persist a placeholder flag before the integration is implemented.

### Notification destinations

A later change may add:

```text
Notifications
[ ] Notify to chat
[ ] Notify to screen
```

Keep the existing quick Notify toggle for now. Per-row destinations are a separate feature requiring real delivery support and decisions about master toggle behaviour, defaults, and any global settings. Prefer one Options panel with sections over separate competing popups for Show and Notify.

## Popup lifecycle and interaction contracts

- At most one row-options panel open at a time; opening another row retargets it.
- Identify the target by row type and stable item/rule key plus active profile context, not a pooled control or mutable list index.
- Close or safely retarget on list rebuild, scrolling/recycling, filter changes, deletion, profile switch/import/reset, tab change, or editor hide. Never apply a stale panel action to a different item/profile.
- Show the target name in the panel. Keep labels clickable with their checkbox and make enabled/disabled state clear.
- Decide and verify click-outside, Escape, focus, anchoring, and screen-edge behaviour using existing ESO/addon popup patterns before introducing a new custom mechanism.
- Avoid click propagation that toggles row selection or triggers a second flag action unintentionally.
- Popup visibility/state is transient; do not save it.
- Preserve fail-fast internal contracts; only validate external controls/APIs/data at their boundaries where appropriate.

## Implementation investigation

Start with:

- [Editor Lua](../../../Tracking/EditPanelItemsTab.lua): `ToggleState`, row label styling/handlers, group-only visibility, selection and bulk actions, list refresh, and filters.
- [Editor XML](../../../Tracking/EditPanelItemsTab.xml): virtual row anchors and existing Group/Totals/Show/Notify label widths.
- [Rule database](../../../Tracking/ItemDatabase.lua): rule flag setters, active profile changes, runtime-rule cache invalidation, and individual tracked-item persistence paths.
- [Tab manager](../../../Tracking/EditPanelTabManager.lua): close/tab-switch lifecycle.
- Existing context menus/dialogs in maintained code and ESO controls: reuse a suitable checkbox popup pattern where possible.

Keep shared row-options logic in the existing editor module unless the concrete implementation warrants a small focused helper. Do not build a generic settings framework for two existing flags.

## Work plan

- [ ] Inspect existing row, selection, bulk mutation, persistence, refresh, and popup patterns.
- [ ] Produce a small layout mockup and confirm wording/interaction before substantive UI work.
- [ ] Recommend a branch for substantive editor changes and obtain approval before switching.
- [ ] Implement Options entry point and popup lifecycle.
- [ ] Wire existing bank/group setters without changing selection or saved-data semantics.
- [ ] Preserve quick Show/Notify and current filter behaviour.
- [ ] Add targeted isolated regression tests for writes, profile context, and stale/recycled-row safety.
- [ ] Verify actual ESO UI rendering/positioning, mouse behaviour, and reload persistence.
- [ ] Update user documentation and the working Unreleased changelog; keep AutoCategory and notification delivery implementation separate.

## Acceptance and tests

1. Both item and group rows expose Show, Notify, and Options clearly at the existing supported window size.
2. Items offer Include banked items but no Group items together option; groups offer both.
3. Each option changes the same underlying value and target set as before, with no unrelated writes.
4. Turning bank inclusion on/off preserves existing tracker totals/count behaviour; changing grouping preserves existing grouping behaviour.
5. Show and Notify remain quick toggles and existing filters continue to work.
6. Popup values reflect the current target/profile, including after another edit or refresh.
7. Row recycling, filtering, deletion, tab/editor close, and profile switches cannot cause stale writes.
8. Reopening/reloading preserves settings but not an open popup.
9. No AutoCategory checkbox or destination control appears functional before its implementation exists.
10. Offline tests count writes/refreshes as well as checking values; in-game tests confirm popup usability, edge anchoring, and readable labels. Avoid unrelated full-suite runs unless focused results require escalation.

## Ordering

This is the next editor task ahead of AutoCategory integration, not proof that the integration's unresolved technical questions are solved. The AutoCategory plan can then add a group-only checkbox to the completed panel rather than introducing a fifth column.
