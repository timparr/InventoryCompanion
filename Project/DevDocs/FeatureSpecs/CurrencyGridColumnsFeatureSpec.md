# Configurable currency grid columns: feature spec

Status: DRAFT - not approved
TODO item: [D10.3 (formerly F1)](../../Tasks/TODO.md)
Owner: Copilot (draft author)
Updated: 2026-11-15
Implementation plan: [Currency grid columns](../Plans/CurrencyGridColumnsStandaloneImplementationPlan.md)

Use the [feature development process](../../Processes/FeatureDevelopment.md).

## Overview / proposed changelog text

Draft wording for when the feature is delivered:

- **Choose your currency-panel layout.** Open IC settings and expand Currency Summary Panel to find the new Grid Columns slider. Use fewer columns for a taller, narrower panel, or more columns for a wider, shorter one. The panel updates immediately without a reload, keeping your resource order and formatting. The default remains three columns, and the maximum grows as more resources become available. Your selected settings profile remembers the choice.
- **Keep your information visible while using other screens.** The item tracker, currency panel, and resource gauges now remain visible while accessing inventory, banks (including house and guild banks), merchants, fences, the IC editor, and the main settings menu, including IC settings. Panels you have disabled, and panels with nothing to display, remain hidden.
- **Panels make room for the screen you open.** IC leaves panels where they are if they are not in the way. Otherwise, it moves them the shortest distance to free space on-screen, avoiding the open screen and other UI wherever possible. If space is tight, avoiding overlap between IC panels has the lowest priority.
- **Arrange panels differently for each screen.** Move a panel while one of these screens is open, and IC remembers that position for that screen and character. For example, you can choose one position beside the bank and another beside your inventory. These positions survive logging out, and each character keeps its own arrangement even when using a shared settings profile. Closing the screen returns panels to their normal positions; IC's automatic moves do not overwrite your chosen positions.
- **Existing reset and copy behavior is preserved.** Reset Panel returns the currency grid to three columns without moving your panels. Any action that resets a panel's positions also resets its remembered screen positions. Copy Full Profile includes panel positions and their screen-specific variants.

## Scope and non-goals

- In scope: choose the currency grid's column count from the existing Currency
  Summary Panel settings; immediately preview the layout; preserve the choice
  with the selected settings profile; and show and position non-empty panels
  during scenes. The panels covered are the item tracker, currency panel, and
  standalone resource bars. Remember and restore panel positions moved by the
  user for each scene.
- Out of scope: a general HUD positioning mode or editor, threshold-based bar
  hiding, permanent position changes caused by opening settings, and moving
  this control into a future HUD editor.

## User experience and behavior

Proposed addition to the existing Currency Summary Panel settings (other
settings are omitted):

```text
Currency Summary Panel
+----------------------------------------------------+
| Show Empty Currencies                         [x]  |
|                                                    |
| Grid Columns: 3                                    |
|                   1 [-------o------------] max     |
|                                                    |
| [Reset Panel]                                      |
|                                                    |
| Existing currency and resource settings ...        |
+----------------------------------------------------+
```

The slider shows a value of 3 in this example. Its maximum depends on the
available resources; the sketch is illustrative, not a new settings window.

- Add a **Grid Columns** integer slider to the existing Currency Summary Panel
  settings. Changes apply and persist immediately; there is no Done/Cancel
  session for this control.
- The default is three columns. The slider range is 1 through
  `max(3, available resource cells)`. Its maximum grows when resource discovery
  adds cells; display filters do not change the range or saved choice. Available
  cells are determined before zero-balance and visibility filtering, using the
  existing combined-location grouping.
- Changing the count reflows cells left-to-right, then top-to-bottom, without
  changing their order, formatting, grouping, or the panel's saved position.
  Use only occupied columns when fewer cells are displayed.
- If the available-cell maximum later shrinks below the saved choice, use the
  current maximum as the effective count without overwriting the saved choice.
- The existing immediate **Reset Panel** action resets columns to three along
  with its existing currency/capacity preferences and ordering, while
  preserving the currency panel's current position and standalone bars.

## Dynamic Panel Behaviour in Response to scenes

1. When particular scenes are open, panels that would normally show when no
   scene is active must remain visible unless empty, and must be positioned
   clear of scene elements wherever possible. Explicitly disabled panels stay
   hidden. This applies to all InventoryCompanion HUD panels: the tracking
   panel, currency panel, and every standalone resource progress bar, for:
   - Inventory, bank, store/merchant, and fence interactions.
   - House bank and guild bank.
   - Gamepad inventory, bank, and store.
   - The InventoryCompanion editor.
   - The main settings menu, including InventoryCompanion settings.

   Each panel must remember its position separately for each scene. When a
   user moves a panel while a scene is open, remember its new position for
   that scene and restore it the next time that scene opens. Automatic
   adjustments must not be saved as user positions. Scene positions survive
   reloads and logout and are stored per character in the profile that character
   is using, not as account-wide positions, even when the profile is shared.
   When the scene closes, restore each panel's non-scene position. On a direct
   transition to another supported scene, apply that scene's saved position or
   default placement without changing the non-scene position.
2. Default panel positions, used until the user chooses a position for that scene.
   - Leave panels in their current positions wherever scene elements do not
     overlap them.
   - Where a panel must move, move it the shortest distance to a free position
     within the screen.
   - Avoid overlapping InventoryCompanion panels or other UI elements wherever
     possible. Avoiding overlap between InventoryCompanion panels is the lowest
     priority: if space is insufficient, allow our panels to overlap one
     another before compromising their on-screen placement or avoidance of
     scene elements and other UI.

Placement algorithms and panel processing order belong in the implementation
plan.

## Preservation and compatibility

- The selected account-wide or character profile owns the grid-column setting
  according to the existing settings-profile switch. Full-profile copying
  includes it. Scene positions are per-character data within the profile in
  use; characters must not overwrite one another's positions in a shared
  profile.
- Copy Full Profile copies the whole profile consistently with its existing
  behavior, including panel positions and their saved per-scene variants.
  Scene positions have no special exclusion or destination-preservation rule
  during an explicit full-profile copy; their per-character separation must
  remain intact.
- A missing value defaults to three. Explicit values must be finite positive
  integers; do not treat a value above the currently available-cell maximum as
  malformed.
- Preserve unrelated profile data. Determine whether a saved-schema change is
  needed only after inspecting the previous supported reader's validation and
  copy behavior. If older builds cannot safely preserve the new value, they
  must reject the newer schema without modifying saved data.
- Automatic scene position adjustments do not overwrite user-saved positions.
  Empty panels remain hidden.
- Scene-position reset behavior follows the existing reset actions' scope.
  Any mechanism that resets a panel's positions must also clear that panel's
  saved scene positions, returning it to default scene placement. Settings-only
  resets that preserve panel positions must also preserve scene positions.
  Do not add a separate scene-position reset action.

## Acceptance criteria

| ID | Required observable result | Verification and environment |
|---|---|---|
| CG1 | Default and migrated profiles use three columns; selecting any supported integer applies immediately and reflows visible cells in their existing order without overlap or phantom columns. | Offline layout/default tests and in-game settings preview, including 1 and maximum columns. |
| CG2 | The selectable maximum is at least three, grows when resource discovery adds cells, and is unaffected by display filtering. A saved value above a later reduced maximum is effectively capped without being overwritten. | Offline range/discovery/filter tests and in-game resource discovery. |
| CG3 | Changing columns preserves the panel anchor, resource order, formatting, combined-location cells, standalone bars, and existing filtering behavior. | Offline state and geometry assertions; in-game layout checks. |
| CG4 | Reload and profile switching preserve the specified ownership. Full-profile copying includes grid columns, panel positions, and saved scene-position variants consistently with existing full-profile replacement behavior. Reset Panel returns columns to three without changing the currency panel position, saved scene positions, or standalone bars. Any panel-position reset also resets that panel's scene positions. | Offline profile/copy/reset tests and backed-up in-game UAT. |
| CG5 | Malformed saved values are reported at the saved-data boundary, unrelated data is preserved, and an incompatible older build refuses newer saved data without mutation. | Offline saved-data tests, previous-reader inspection, and guarded older-build verification if schema changes. |
| CG6 | Supported scenes show the non-empty tracking panel, currency panel, and standalone resource progress bars that would normally show outside scenes; disabled panels stay hidden. Default placement retains unobstructed positions or moves panels the shortest distance to free on-screen space. Avoiding overlap between our panels has lower priority than avoiding scene elements and other UI or keeping panels on-screen. Automatic movement does not overwrite user positions. | Offline visibility and constrained-placement tests for all panel types; in-game scene and overlap checks. |
| CG7 | User-chosen scene positions survive reload and logout, remain separate for each character within the profile in use, and are restored on scene re-entry. Closing the scene restores non-scene positions; switching scenes applies the destination scene's saved or default positions. | Offline persistence, character isolation and transition tests; in-game scene re-entry, logout and character-switch checks. |

## Independent spec review

Reviewer: PENDING
Reviewed document revision/source identity: PENDING

| Finding | Evidence | Tim's decision | Resolution / re-review |
|---|---|---|---|
| PENDING | PENDING | PENDING | PENDING |

## Approvals and acceptance

- Explicit spec approval: PENDING
- Feature acceptance: PENDING
- Actual acceptance evidence and disclosed limitations: PENDING

Spec approval does not authorize coding. Record plan approval and GO to code in
the implementation plan.

## Historical background

This standalone proposal originated as D10.3 in the broader HUD layout and
visibility work. The separate HUD editor, bar-visibility work, and integrated
HUD-editor path are not part of this specification. See the
[HUD layout and visibility archive](../Archive/HUDLayoutAndVisibility/HUDLayoutAndVisibility.md)
for historical material.
