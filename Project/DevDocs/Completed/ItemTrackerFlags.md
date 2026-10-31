# Item tracker editor flags and row options

Status: Implementation completed and archived at the user's request on
2026-10-31. Two-line layout approved; independent
display locations, notification destinations, and editor popups implemented.
Automated checks passed (99/99 isolated tests); user confirmed the in-game
acceptance tests passed on 2026-10-31. AutoCategory integration is separate work.

## Goal

Make the extended Show/Notify row settings easier to understand and leave room
for additional options without adding columns or shrinking text. Replace the
existing Group / Totals / Show / Notify controls with aligned, two-line Show
and Notify controls that open compact checkbox boxes.

## User experience and behavior

```text
Item or group name          Show                  Notify        AutoCategory
                           Backpack, grouped     Both

Show box                         Notify box
[ ] Display items together       [ ] Notify Chat
[ ] Show backpack                [ ] Notify HUD
[ ] Show bank
```

- Show and Notify each open their own box anchored to the clicked control.
  Only one live box opens at a time. No heading, explanatory section, Done,
  confirmation tick, or separate Options button.
- Display items together is group-row-only. Show backpack and Show bank are
  independent: backpack-only, bank-only, both, or neither. Backpack includes
  craft-bag holdings with ESO Plus, matching the existing carried-item scope.
- Location counts have native bank/bag icons. Both shows separate bank-only
  and carried counts, bank first, with no separator or combined total. Neither
  hides that item/group from the tracker.
- Notify Chat and Notify HUD independently request pickup delivery. There is
  no additional master Notify checkbox. Neither disables notifications.
- Show's detail is Backpack, Bank, Both, or None, followed by ", grouped" for
  a shown grouped rule. Notify's detail is Chat, HUD, Both, or None.
- Fixed-width columns align labels and detail lines across row types.
  Disabled controls use the existing warm color at reduced opacity, not a
  literal grey palette, and remain clickable. Do not use parentheses.
- Apply changes immediately using the current mutation paths; no Apply/save
  transaction. Opening or closing a box alone must not track or modify an item.
  Keep the box open for another edit by rebinding after refresh when the target
  still appears under the active filters.
- Preserve each action's current target set, including promotion of an
  untracked item when one of its flags is changed. Do not introduce bulk editing.
- Keep the existing readable fonts and window width. Make checkbox labels
  clickable without triggering another row action.
- Close on list rebuild, scrolling, filter changes, deletion, profile
  switch/import/reset, tab change, or editor hide. Never apply an old callback
  to a recycled row or another profile.
- Clicking away or the same control closes the box. Escape, focus, anchoring,
  and screen-edge behavior must be verified in ESO. Popup state is transient
  and never saved.

## Compatibility

- Add optional `showBackpack`, `showBank`, `notifyChat`, and `notifyHud` flags;
  retain legacy `show`, `bank`, `notify`, and `group` data. Absent new flags
  inherit the old effective behavior without eagerly rewriting profiles.
- Old Show off maps to neither location; Show on maps to backpack and optionally
  bank through Totals. Old Notify on maps to both destinations, off to neither.
- Group overrides remain sparse. Saved-variable version increases to 3 because
  older builds cannot safely interpret/preserve these fields. Validate every
  profile before publishing any upgrade, and update versions before ZOS
  constructors can reset data. Version 2 needs only a version-marker upgrade;
  version 1 also follows the existing sparse-rule conversion.
- Schema 2 builds reject version 3 before inspecting new flags, preserving
  data but refusing to initialize. Downgrading requires a compatible backup
  restored with ESO closed; DEV and release share saved variables.
- In-game downgrade test on 2026-10-31: user confirmed the older release throws
  after loading DEV. The user subsequently confirmed the acceptance tests passed,
  including reload and settings preservation.
- Preserve defaults, sparse group overrides, account/character selection,
  profile import, and reload persistence.
- Preserve Show/Notify/Mute/Untracked filters, search, individual tracking,
  group overlap, include/exclude matching, and Miscellaneous behavior.
- Union notification destinations requested by individual items and all visible
  matching groups, emitting at most one message per gain. Hidden groups and
  local pattern exclusions do not contribute. Display remains independent.
- Keep notification listeners active when notifications are enabled even with
  the tracker hidden. Existing gain detection and duplicate/burst suppression
  remain; suppression must never redirect to an unselected destination.
- Preserve bank scanning, tracker layout/height policy, saved expansion
  preferences, and currency/capacity notification behavior.
- Required addon functions and established internal state remain fail-fast.
  Validate externally controlled data at the loading/import boundary rather
  than concealing broken internal contracts with fallback values.

## Later extensions, not initial functionality

### AutoCategory

After the separate [integration](../Tasks/todo_plan_autocategoryIntegration.md) works,
add the full **AutoCategory** label last, after Notify, as a group-only toggle.
Participation is independent of Show, grouping, and expansion. The column has
zero width when integration is disabled or unavailable (including now), giving
the space back to item names. When enabled, reserve the same column width across
all row types to preserve alignment, even for groups not participating.
Do not display a working-looking control or save a placeholder flag before
integration exists.

## Implementation details

See the separate [implementation record](ImplementationPlan_ItemTrackerFlags.md)
for examined code paths, saved fields, ordered changes, regression tests, and
in-game acceptance checks. Implementation and user-facing verification are
complete; these documents are archived in Completed.
