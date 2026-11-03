# Settings and Editor UI/UX Mockup

**Status:** Design proposal for discussion; no runtime changes or approved
implementation scope.

## 1. Direction

Keep the ESO addon-settings page as the discoverable entry point for general
preferences. Use a consistent custom configuration window for detailed editing.
Extend the existing Items and Groups editors rather than replacing their
working behavior.

The proposed window has four destinations:

- **Items:** Explicitly tracked items and existing rule/display controls.
- **Groups:** Group names, matching patterns, and group lifecycle operations.
- **Resources:** Currency/capacity selection, ordering, notifications, and
  selected-resource bar settings.
- **Tracker:** Item-tracker presentation preferences.

Mockups are wireframes, not pixel-accurate layouts. Values and resource names
are examples. `[x]` denotes a checkbox, `[Label]` a button, and `v` a dropdown.
**NEW** marks proposed behavior beyond relocating existing controls.

## 2. New Game Settings Page

Retain LibAddonMenu. Make the first screen short and understandable without
requiring users to open an editor for basic tracker visibility.

```text
+--------------------------------------------------------------------+
| Inventory Companion                                                |
|                                                                    |
| TRACKING AND ON-SCREEN INDICATORS                                   |
| [x] Show Item Tracker                                              |
|                                                                    |
| [ Configure Items...                    ]                          |
|   Choose individual items to display or receive notifications for.  |
| [ Configure Groups...                   ]                          |
|   Edit matching patterns and group definitions.                     |
| [ Configure Resources and Bars...       ]                          |
|   Choose currencies, capacity indicators, and standalone bars.      |
| [ Configure Tracker Appearance...       ]                          |
|   Layout, wrapping, empty entries, and title size.                   |
|                                                                    |
| BANK AND CHEST OPERATIONS                                          |
| Item transfer delay (ms)       --------o--------  100               |
| [x] Auto-Merge Chest Stacks                                         |
|                                                                    |
| > Diagnostics                                                      |
|   [ ] Enable Debug Mode                                            |
+--------------------------------------------------------------------+
```

- Each configure button opens the corresponding destination directly, not just
  whichever editor happened to be open last.
- Keep Show Item Tracker here as the single authoritative configuration
  checkbox. The existing keybinding and HUD actions continue to use the same
  preference.
- Remove the duplicated currency list and per-bar advanced submenus from LAM
  when the Resources replacement is ready.
- Move tracker presentation controls to Tracker. Keep banking controls here;
  no new Banking editor is proposed.
- Keep transfer-delay guidance, including the disconnect warning, in its tooltip.
- **NEW navigation:** Leave the game-settings scene before presenting the
  custom editor; provide an explicit return route. Exact ESO scene handling
  needs an implementation spike, not simultaneous overlapping windows.

## 3. Shared Custom-Window Shell

```text
+----------------------------------------------------------------------------+
| Inventory Companion                           [Game Settings]          [X] |
| [ Items ] [ Groups ] [ Resources ] [ Tracker ]                              |
|----------------------------------------------------------------------------|
| Destination-specific content                                               |
|                                                                            |
|                                                                            |
|----------------------------------------------------------------------------|
| Changes apply immediately.                                         [Close] |
+----------------------------------------------------------------------------+
```

- Shared position and dimensions across destinations, following the current
  Items/Groups geometry behavior. No forced rewrite into one physical control
  tree is required.
- Preserve existing item/group focus-loss commits. Finish the active edit
  before navigating away; do not introduce a misleading global Save button.
- Remember search, selection, and scroll position within a session where
  practical. A stale selection must be cleared when its underlying data changes.
- Keep character/account scope visible on Items and Groups. Resources and
  tracker presentation remain account-wide.
- Close/Escape dismisses the editor; Game Settings explicitly returns to LAM.
  Settings opened from LAM must not leave the editor behind it.
- Use ESO controls and existing addon styling, with readable labels, tooltips,
  keyboard focus, and independently scrolling list/detail areas.

## 4. Items Panel

Preserve the existing item-editor workflow and row-level controls.

```text
+----------------------------------------------------------------------------+
| Inventory Companion                           [Game Settings]          [X] |
| [ ITEMS ] [ Groups ] [ Resources ] [ Tracker ]                              |
|----------------------------------------------------------------------------|
| Active list: [Account-wide v]       [Import from... v] [Import]             |
| Search [________________________]                                          |
| Filter: [x] Show  [x] Notify  [ ] Inactive  [ ] Untracked                   |
|----------------------------------------------------------------------------|
| Item / rule                        Notify   Show    Totals    Group         |
| Iron Ore                             [x]     [x]    [Bag v]     -      [X] |
| Rubedite Ingots                      [ ]     [x]    [All v]     -      [X] |
| Crafting Materials                   [ ]     [x]    [All v]    [x]         |
| ...                                                                        |
|----------------------------------------------------------------------------|
| Changes apply immediately.                                         [Close] |
+----------------------------------------------------------------------------+
```

- Scope selection maps to the existing character-list switch; changing scope
  does not copy data. The label treatment is proposed, not a new profile system.
- Import preserves current source selection, preview, confirmation, and copy
  semantics. Do not silently import merely by choosing a source.
- The wireframe's Totals labels stand for existing storage choices, not a new
  transfer or bank-fetch feature.
- Preserve the current meaning of Group and the distinction between explicit
  items and rule entries. Removing an explicit item is not deleting a group.
- Untracked remains the existing discovery/filter workflow, not a new sharing
  feature.

## 5. Groups Panel

Retain the existing list/detail design.

```text
+----------------------------------------------------------------------------+
| Inventory Companion                           [Game Settings]          [X] |
| [ Items ] [ GROUPS ] [ Resources ] [ Tracker ]                              |
|----------------------------------------------------------------------------|
| Active list: Account-wide                                                  |
| Search [____________________]                       [+ New Group]          |
|--------------------------------|-------------------------------------------|
| Groups                         | Crafting Materials               [Rename] |
| > Crafting Materials           |                                           |
|   Alchemy                      | Matching patterns                         |
|   Enchanting                   | [*ore_________________________]       [X] |
|   My Custom Group              | [*ingot_______________________]       [X] |
|                                | [+ Add Pattern]                           |
|                                |                                           |
|                                | Group description / guidance              |
|                                |                                           |
|                                | [Reset Name and Patterns] [Hide Group]   |
|                                | [Delete Group] (custom groups only)       |
|--------------------------------|-------------------------------------------|
| Changes apply immediately.                                         [Close] |
+----------------------------------------------------------------------------+
```

- Reset restores only name and patterns, retaining display flags and hidden
  state. Preserve the existing confirmation.
- Hide and Delete remain different operations. Delete is only offered where
  currently supported.
- Preserve add/delete row behavior and focus-loss editing without rebuilding
  rows while typing.
- Do not add a second copy of item-editor Show/Notify/Totals controls here as
  part of this proposal.

## 6. Resources Panel

This replaces the long currency settings list and repeated bar submenus.
Select one resource to configure its details.

```text
+----------------------------------------------------------------------------+
| Inventory Companion                           [Game Settings]          [X] |
| [ Items ] [ Groups ] [ RESOURCES ] [ Tracker ]                              |
|----------------------------------------------------------------------------|
| Account-wide                 Search resources [____________________]       |
| [Summary layout] [Shared bar colors]                                       |
|--------------------------------|-------------------------------------------|
| IN SUMMARY                     | Backpack Space                            |
| > Backpack Space       [^][v]  |                                           |
|   Bank Space           [^][v]  | [x] Show in Currency Summary               |
|   Gold                 [^][v]  | [ ] Notify on changes                     |
|                                |                                           |
| OUT OF SUMMARY                 | [x] Show standalone bar                   |
|   Alliance Points              |                                           |
|   Transmute Crystals           | > Bar appearance and visibility           |
|   Writ Vouchers                |                                           |
|   ...                          | [Preview and Position Bar]                |
|--------------------------------|-------------------------------------------|
| Changes apply immediately.                                         [Close] |
+----------------------------------------------------------------------------+
```

- Keep IN/OUT grouping: IN follows saved summary order; OUT is alphabetical.
  Only IN entries offer move-up/down, with unavailable moves disabled.
- Selection and Show in Currency Summary are separate. Selecting an OUT entry
  does not enable it. Hiding/re-enabling preserves current ordering semantics.
- Keep selected-resource location choices visible for bankable currencies:

```text
| Gold                                                                      |
| [x] Show in Currency Summary                                               |
| Include balances: [x] Character  [x] Bank                                  |
| [ ] Notify on changes                                                     |
| This currency does not support a standalone capped progress bar.           |
```

- Account-wide currencies show their account scope without fictitious
  Character/Bank checkboxes. Capacity resources do not offer currency-location
  choices.
- A shown currency with no selected location remains in IN, with a text warning
  as well as the existing red-name cue; no HUD value is rendered.
- Notifications remain independent of summary and bar visibility.
- Only supported capped resources offer a standalone bar.
- **NEW preview action:** Temporarily show the selected bar so it can be
  positioned even when disabled or below the proposed display threshold.
  Preview must not enable the bar or write synthetic balances.

### 6a. Selected Bar Detail

Expands inside the right-hand pane, not a separate top-level tab or one submenu
per resource.

```text
| Backpack Space                                                            |
| [x] Show in Currency Summary                                               |
| [ ] Notify on changes                                                     |
| [x] Show standalone bar                                                    |
| v Bar appearance and visibility                                           |
|   Show only when at least (%)   --------o------  75       NEW (D10)         |
|     0 means always show. This controls visibility, not alert colors.        |
|   Warning threshold (%)         --------o------  75                        |
|   Danger threshold (%)          ------------o--  90                        |
|   Normal bar color              [ color swatch ]                           |
|   Warning/danger colors are shared. [Shared bar colors]                    |
| [Preview and Position Bar]                                                 |
```

- D10 is a proposed new per-bar preference, default 0%, range 0-100%.
  Visibility uses percentage used, matching the existing capacity/cap model.
  At the selected percentage the bar is visible; below it the bar is hidden.
- Keep visibility independent of warning/danger thresholds. Preserve the
  existing coupled threshold behavior when warning would exceed danger.
- Disabled bars do not show normally. Their detail values remain editable;
  preview is explicitly temporary.
- Below-threshold enabled bars still need relevant updates so they reappear.
- Preview ends on explicit completion, resource/destination change, or editor
  close; restore real visibility and values. Persist only intentional dragging
  of the real bar's position, not temporary visibility.
- Do not introduce multiple visibility modes or an extra enable-threshold
  checkbox in this first design.

### 6b. Summary Layout Detail

An in-panel detail view opened by Summary layout; Back to Resource returns to
the selection without losing list position.

```text
| Currency Summary Layout                           [Back to Resource]       |
| [x] Show Empty Currencies                                                  |
| Grid: three columns (current behavior)                                     |
| [Reset Summary Contents...]                                               |
|   Restore Gold, Backpack Space, and Bank Space only.                       |
|   Keep panel position and standalone-bar settings.                        |
```

Configurable columns and summed character/bank totals remain separate optional
ideas, not implied features of this UI migration.

### 6c. Shared Bar Colors Detail

```text
| Shared Bar Colors                                 [Back to Resource]       |
| Warning color                 [ amber swatch ]                            |
| Danger color                  [ red swatch   ]                            |
| Applies to every standalone bar's alert colors.                           |
| Each bar keeps its own normal color and alert thresholds.                 |
```

## 7. Tracker Panel

This configures the item-tracker HUD; it is not another inventory list.

```text
+----------------------------------------------------------------------------+
| Inventory Companion                           [Game Settings]          [X] |
| [ Items ] [ Groups ] [ Resources ] [ TRACKER ]                              |
|----------------------------------------------------------------------------|
| Item Tracker Appearance                         Applies account-wide       |
|                                                                            |
| Group threshold                  -----o----------   8                      |
| Maximum visible rows             --------o-------  20                      |
| Title size                       ------o---------  20                      |
| [x] Multiline item names                                                   |
| [x] Show empty tracked items                                               |
|                                                                            |
| Large lists use single-line names, category collapsing, then scrolling.    |
| The saved multiline preference is restored when the content fits.          |
|                                                                            |
| Tracker hidden? Enable it in [Game Settings] or use its existing shortcut.  |
|----------------------------------------------------------------------------|
| Changes apply immediately.                                         [Close] |
+----------------------------------------------------------------------------+
```

- Preserve current slider ranges: group threshold 1-30, maximum rows 5-50,
  title size 16-28.
- Keep adaptive layout policy unchanged. Do not revive the superseded
  pixel-height or separate Collapse/Scroll modes.
- The existing character-list switch belongs in Items, not in presentation
  settings. Groups reflects that same active scope.

## 8. Behavior and Implementation Boundaries

- One owner for every preference. Existing setters, normalization, cache
  invalidation, event registration, and refresh paths remain authoritative.
  UI relocation must not change rule storage or profile-import semantics.
- No saved-variable version change merely to rearrange controls. D10 would
  need a documented optional default and boundary validation of stored input.
- Do not offer a global destructive Reset All. Keep existing scoped defaults:
  summary contents versus group name/pattern reset. Preserve unrelated data.
- Opening an editor must not silently enable HUD displays or notifications.
  Any temporary preview is separate from persisted settings.
- Preserve normal HUD positioning and interaction behavior. General overlap
  redesign, per-character placement, font scaling, and pickup behaviors remain
  separate ideas.
- Avoid keeping two permanent copies of the advanced configuration UI. During
  migration, retain the old controls until their replacement is complete, then
  remove them in the same delivered change.
- A substantial implementation should be developed on a separately approved
  branch; this document alone requires no branch switch.

## 9. Suggested Delivery and Validation

1. Review the wireframes and wording before implementation.
2. Prototype navigation and Resources list/detail using current preference
   APIs. Confirm scene transitions, keyboard focus, and minimum usable size.
3. Relocate currency and standalone-bar controls with behavioral parity;
   preserve Items/Groups functionality and add direct LAM launch buttons.
4. Relocate tracker appearance controls. Keep general banking/debug options
   in LAM and verify existing keybindings/context-menu routes.
5. Add D10 and temporary bar preview as separately testable behavior.

Required checks for a future implementation:

- Every existing setting still has an appropriate reachable home.
- Navigating with an active pattern/name edit preserves its committed value.
- Character/account switching and imports update both item/group destinations.
- Resource selection does not toggle visibility; reorder and reset semantics
  remain unchanged; currency/capacity/account scopes are distinguished.
- Disabling, filtering, and previewing bars preserve correct listener needs.
- D10 tests below/equal/above threshold, 0% and 100%, reload persistence, invalid
  saved values, and automatic reappearance without opening settings.
- Preview exits cleanly on every navigation/close path without saved-state
  changes other than deliberate position edits.
- In-game checks target the changed UI: scaling, text clipping, scrolling,
  tooltips, color picker, focus, scene transitions, and HUD preview placement.
- Run existing focused regression suites and the standard release workflow.
  Use synthetic data for performance checks, never mutate live inventory or
  saved variables for test fixtures.

## 10. Current Implementation References

- [LAM settings](../../../Core/Settings.lua)
- [Items editor layout](../../../Tracking/EditPanelItemsTab.xml)
- [Groups editor layout](../../../Tracking/EditPanelGroupsTab.xml)
- [Editor navigation](../../../Tracking/EditPanelTabManager.lua)
- [Currency/resource settings and presentation](../../../Tracking/CurrencyPanel.lua)
- [Progress-bar preferences](../../../Banking/ProgressBarResources.lua)
- [Master TODO](../TODO.md): D10, E4, and F3 provide related context; this
  proposal does not approve or implement those tasks.
