# Item tracker editor flags and row options

Status: Planned; reviewed on 2026-10-30. No runtime changes made. Complete
this editor improvement before AutoCategory integration.

## Goal

Make the extended Show/Notify row settings easier to understand and leave room
for additional options without adding columns or shrinking text. Replace the
existing Group / Totals / Show / Notify controls with quick Show and Notify
toggles plus one discoverable Options control.

## User experience and behavior

```text
Item or group name                     Show   Notify   Options...

Options for <item or group name>

Tracker
[ ] Include banked items
[ ] Group items together       (group rows only)
```

- Show and Notify remain one-click toggles with their current behavior.
- Options opens a compact checkbox panel anchored to that row's button, not a
  second full editor window. Use an explicit label/button; a settings summary
  may appear in its tooltip but must not replace the entry point.
- Rename **Totals** to **Include banked items** and **Group** to **Group items
  together**. Grouping remains available only on group/rule rows.
- Apply changes immediately using the current mutation paths; no Apply/save
  transaction. Opening or closing Options alone must not track or modify an item.
- Preserve each action's current target set, including promotion of an
  untracked item when one of its flags is changed. Do not introduce bulk editing.
- Use normal readable fonts at the existing supported window size. Confirm
  wording, dimensions, and popup interaction before substantive UI work.
- Only one Options panel may be open. Show its target name and make checkbox
  labels clickable without triggering another row action.
- Close on list rebuild, scrolling, filter changes, deletion, profile
  switch/import/reset, tab change, or editor hide. Never apply an old callback
  to a recycled row or another profile.
- Escape and click-outside dismissal, focus, anchoring, and screen-edge
  behavior must be verified in ESO. Popup state is transient and never saved.

## Compatibility

- Reuse the existing `show`, `notify`, `bank`, and `group` display flags.
  Moving/renaming controls requires no new saved fields or schema/version bump.
- Preserve defaults, sparse group overrides, account/character selection,
  profile import, and reload persistence.
- Preserve Show/Notify/Mute/Untracked filters, search, individual tracking,
  group overlap, include/exclude matching, and Miscellaneous behavior.
- Do not change bank scanning, notification delivery, tracker layout/height
  policy, or saved expansion preferences.
- Required addon functions and established internal state remain fail-fast.
  Validate externally controlled data at the loading/import boundary rather
  than concealing broken internal contracts with fallback values.

## Later extensions, not initial functionality

### AutoCategory

After the separate [integration](todo_plan_autocategoryIntegration.md) works,
add a group-only **Create AutoCategory group** checkbox under an Inventory
categories section. Participation is independent of Show, grouping, and
expansion. Do not display a working-looking control or save a placeholder flag
before delivery exists.

### Notification destinations

A later Notifications section may offer **Notify to chat** and **Notify to
screen**, using this same Options panel rather than separate Show/Notify
popups. This is not yet an approved delivery design. Decide quick Notify/master
toggle behavior, destination defaults and inheritance, interaction with global
settings, and overlapping item/group requests before adding saved fields or
functional controls. Preserve current quick Notify behavior in the first stage.

## Implementation details

See the separate [implementation plan](todo_implementation_itemTrackerFlags.md)
for examined code paths, saved fields, ordered changes, regression tests, and
in-game acceptance checks. Keep these documents in Tasks until implementation
and user-facing verification are complete.
