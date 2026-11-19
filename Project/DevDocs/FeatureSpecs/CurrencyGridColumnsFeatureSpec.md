# Configurable currency grid columns: feature spec

Status: IMPLEMENTED AND RELEASED in 1.7.2; accepted 2026-11-19
Completed work: [Currency grid and scene layouts](../Archive/CompletedWork.md)
Owner: Copilot (draft author)
Updated: 2026-11-19
Implementation plan: [Archived implementation plan](../Archive/CurrencyGridAndSceneLayouts/CurrencyGridColumnsStandaloneImplementationPlan.md)

Use the [feature development process](../../Processes/FeatureDevelopment.md).

## Overview and released user-facing summary

The release describes the feature as follows:

- **Choose your currency-panel layout.** Open IC settings and expand Currency Summary Panel to find the new Grid Columns slider. Use fewer columns for a taller, narrower panel, or more columns for a wider, shorter one. The panel updates immediately without a reload, keeping your resource order and formatting. The default remains three columns, and the maximum grows as more resources become available. Your selected settings profile remembers the choice.
- **Keep your information visible while using other screens.** The item tracker, currency panel, and resource gauges now remain visible while accessing inventory, banks (including house and guild banks), merchants, fences, the IC editor, and the main settings menu, including IC settings. Panels you have disabled, and panels with nothing to display, remain hidden.
- **Panels make room for the screen you open.** IC leaves panels where they are if they are not in the way. Displaced panels form a vertical stack beside the active window, preferring its right edge and otherwise using its left. This applies to settings, banks, merchants, and the IC editors as well as the other supported screens. Other addons' UI is not considered. If space is tight, avoiding overlap between IC panels has the lowest priority.
- **Arrange panels differently for each screen.** Move a panel while one of these screens is open, and IC remembers that position for that screen and character. For example, you can choose one position beside the bank and another beside your inventory. These positions survive logging out, and each character keeps its own arrangement even when using a shared settings profile. Closing the screen returns panels to their normal positions; IC's automatic moves do not overwrite your chosen positions.
- **Existing reset and copy behavior is preserved.** Reset Panel returns the currency grid to three columns without moving your panels. Any action that resets a panel's positions also resets its remembered screen positions. Copy Full Profile includes panel positions and their screen-specific variants.

## Scope and non-goals

- In scope: choose the currency grid's column count from the existing Currency
  Summary Panel settings; immediately preview the layout; preserve the choice
  with the selected settings profile; and show and position normally visible panels
  during scenes. The panels covered are the item tracker, currency panel, and
  standalone resource bars. Remember and restore panel positions moved by the
  user for each scene.
- Out of scope: a general HUD positioning mode or editor, threshold-based bar
  hiding, permanent position changes caused by opening settings, and moving
  this control into a future HUD editor. Detecting or avoiding other addons'
  UI is also out of scope. Gamepad support is preserved as it exists today;
  adding or repairing gamepad-specific behavior is deferred to the whole-addon
  gamepad review (TODO F14).

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
  `max(3, available resource cells)`. Determine available resources at addon
  initialization on logon/reload; no in-session rediscovery is required. The
  maximum reflects resource additions/removals on subsequent initialization;
  display filters do not change the range or saved choice. Available
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
   scene is active must remain visible, and must be positioned
   clear of scene elements wherever possible. Explicitly disabled panels stay
   hidden. This applies to all InventoryCompanion HUD panels: the tracking
   panel, currency panel, and every standalone resource progress bar, for:
   - Inventory, bank, store/merchant, and fence interactions.
   - House bank, guild bank, and furniture vault, including withdrawal/deposit tabs.
   - The InventoryCompanion editor.
   - The main settings menu, including InventoryCompanion settings.

   Use normal no-scene visibility, including its enabled/content preferences.
   Placeholder text counts as visible content: a tracker showing "No tracked
   items" normally must also show during supported scenes. Do not introduce
   stricter empty-panel suppression for this feature.

   The new scene behavior does not add gamepad-specific scene detection or
   placement. Preserve existing gamepad behavior; comprehensive gamepad testing
   and fixes are separate follow-up work.

   Each panel must remember its position separately for each scene. When a
   user moves a panel while a scene is open, remember its new position for
   that scene and restore it the next time that scene opens. Automatic
   adjustments must not be saved as user positions. Scene positions survive
   reloads and logout and are stored per character in the profile that character
   is using, not as account-wide positions, even when the profile is shared.
   Positions are remembered by screen/interaction type, not by individual
   visit or underlying ZOS scene name. The IC editor's tabs share one editor
   position set; inventory, bank, house bank, guild bank, furniture vault, merchant, fence, and
   settings each have their own position set.
   When the scene closes, restore each panel's non-scene position. On a direct
   transition to another supported scene, apply that scene's saved position or
   default placement without changing the non-scene position.
   Withdrawal and deposit tabs share their interaction's position set.
   Calculate placement when the scene opens and reconsider it when visible ZOS
   UI changes or IC panels change size. Move panels only where needed to
   correct actual ZOS overlap or an unsuitable on-screen fit, including panels with
   user-saved scene positions. These corrections are temporary and never
   overwrite saved positions. Do not reposition during a user drag.
   Leave an unobstructed corrected position alone when space becomes available;
   the next scene entry starts from the saved scene position, or normal
   position if none is saved. Automatic positions are not persisted.
   Existing IC panels may touch or overlap one another by user choice; do not
   move them merely to enforce spacing, including on scene re-entry or panel
   growth. Touching a ZOS edge without actual overlap is not an obstruction.
2. Default panel positions, used until the user chooses a position for that scene.
   - Leave panels in their current positions wherever scene elements do not
     overlap them.
   - Arrange panels that must move in a vertical stack beside the active
     window. Prefer its right edge when space permits, otherwise use its left.
     Apply this shared rule to every supported screen, not just settings.
     If neither side fits, use the insufficient-space fallback below.
   - When finding a new position for a displaced panel, automatic placement
     must leave at least 5 px between InventoryCompanion
     panels when space permits. This spacing follows the same lowest-priority
     constraint as avoiding overlap between our panels when space is insufficient.
   - Avoid overlapping InventoryCompanion panels or ZOS UI elements wherever
     possible. Avoiding overlap between InventoryCompanion panels is the lowest
     priority: if space is insufficient, allow our panels to overlap one
     another before compromising their on-screen placement or avoidance of
     ZOS scene elements and other ZOS UI. Other addons' UI is not considered
     for placement.
   - In insufficient space, overlapping IC panels use staggered top-left
     corners so they can be grabbed and moved apart. Prefer keeping panels
     on-screen over avoiding unavoidable ZOS overlap. If a panel is larger
     than the screen, keep its top-left accessible. This rare fallback need
     not find an optimal packing.

Placement algorithms and panel processing order belong in the implementation
plan.

## Snap on release

- Drag freely. Releasing normally aligns the panel with a nearby visible
  InventoryCompanion panel or docks it with a 5 px gap. Hold Shift at release
  to keep the exact drop, including intentional overlap. Only the dragged
  panel moves.
- An overlapping drop can snap farther than the normal range: use the
  nearest clear side. Keep the exact drop if no suitable position exists.
  Do not snap to hidden panels or move a panel into ZOS UI or off-screen.
- Save the resulting drop position through the existing normal/scene rules.
  Reopening a scene does not run snapping again. No settings toggle, grid, or
  live preview.
- Acceptance: ordinary drops align or dock nearby bars, Shift drops preserve
  exact placement, and reopening inventory restores the saved drop position.

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
  Preserve normal no-scene content visibility, including placeholders.
- Scene-position reset behavior follows the existing reset actions' scope.
  Any mechanism that resets a panel's positions must also clear that panel's
  saved scene positions, returning it to default scene placement. Settings-only
  resets that preserve panel positions must also preserve scene positions.
  Do not add a separate scene-position reset action.

## Acceptance criteria

| ID | Required observable result | Verification and environment |
|---|---|---|
| CG1 | Default and migrated profiles use three columns; selecting any supported integer applies immediately and reflows visible cells in their existing order without overlap or phantom columns. | Offline layout/default tests and in-game settings preview, including 1 and maximum columns. |
| CG2 | The selectable maximum is at least three, reflects resources discovered at logon/reload initialization, and is unaffected by display filtering. A saved value above a later reduced maximum is effectively capped without being overwritten. No in-session rediscovery is required. | Offline range/initialization/filter tests and in-game logon/reload checks. |
| CG3 | Changing columns preserves the panel anchor, resource order, formatting, combined-location cells, standalone bars, and existing filtering behavior. | Offline state and geometry assertions; in-game layout checks. |
| CG4 | Reload and profile switching preserve the specified ownership. Full-profile copying includes grid columns, panel positions, and saved scene-position variants consistently with existing full-profile replacement behavior. Reset Panel returns columns to three without changing the currency panel position, saved scene positions, or standalone bars. Any panel-position reset also resets that panel's scene positions. | Offline profile/copy/reset tests and backed-up in-game UAT. |
| CG5 | Malformed saved values are reported at the saved-data boundary, unrelated data is preserved, and an incompatible older build refuses newer saved data without mutation. | Offline saved-data tests, previous-reader inspection, and guarded older-build verification if schema changes. |
| CG6 | Supported scenes, including bank deposit/withdrawal and furniture vault, show normally visible panels, including placeholders; disabled panels stay hidden. Retain unobstructed positions and stack displaced panels beside the active window, right then left then the insufficient-space fallback. Consider only ZOS and IC UI, not third-party UI. Existing IC panels may touch or overlap; touching ZOS edges or small gaps do not trigger correction. New automatic positions use at least 5 px IC spacing where possible, subject to on-screen placement and ZOS avoidance taking priority. Relevant UI and panel-size changes correct actual ZOS overlap or off-screen placement without repeated movement when unchanged or movement during dragging. Corrections can move saved scene positions temporarily but never overwrite them. | Offline visibility, tab transitions, stacking preservation, edge contact, side-stack, spacing, fallback, geometry-change, drag and persistence tests for all panel types; in-game scene, resize, re-entry and overlap checks. |
| CG7 | User-chosen scene positions survive reload and logout, remain separate for each character within the profile in use, and are restored on scene re-entry. Closing the scene restores non-scene positions; switching scenes applies the destination scene's saved or default positions. | Offline persistence, character isolation and transition tests; in-game scene re-entry, logout and character-switch checks. |

## Product decisions

- **Preserve user stacking - Tim, 2026-11-18:** IC-to-IC overlap and proximity
  do not trigger correction. Use actual ZOS rectangle overlap without padding
  when deciding whether to move an existing position. Spacing still applies
  when finding new automatic positions. Tim approved recording and implementing
  this refinement: "record that and do it".

- **Normal-view visibility - clarified by Tim, 2026-11-15:** supported scenes
  unhide anything that would show in the normal no-scene view. Placeholder
  text counts; this supersedes any stricter empty-panel interpretation.

- **Live overlap correction - agreed by Tim, 2026-11-17:** show panels in missing
  bank-deposit and furniture-vault views. Reconsider placement when the visible
  UI or panel sizes change, reusing existing observation rather than requiring
  another listener. Temporary corrections may move manually positioned panels
  without overwriting their saved positions or interfering during dragging.
  Separate scene position sets remain; broader inventory/bank layout sharing
  is not part of this change. This supersedes the following entry-only and
  user-position-precedence decisions.
- **Historical entry-only automatic placement - Tim, 2026-11-15; superseded:** calculate
  default scene positions on entry, then leave them alone for that visit.
  Panel-size or UI-geometry changes do not trigger repositioning. Calculate
  afresh on the next entry rather than persisting automatic positions. This
  supersedes the earlier live-recalculation decision.
- **Historical user-position precedence - Tim, 2026-11-15; superseded:** do not automatically
  correct saved scene positions after obstruction, panel resizing, or other
  geometry changes. Users adjust their own arrangements; automatic placement
  remains responsible only for panels without a user-chosen scene position.
- **Side-stack placement - agreed by Tim, 2026-11-15:** leave unobstructed
  panels alone and stack displaced panels vertically beside the active window,
  right side preferred, left otherwise, then the agreed fallback. This applies
  across all supported screens and supersedes shortest-distance placement.
- **Resource discovery timing - agreed by Tim, 2026-11-15:** discover available
  currencies at logon/reload initialization only. Currency roster changes occur
  through patches between sessions; no new event listeners or live slider-range
  rediscovery mechanism is required for this feature.
- **Placement algorithm and spacing - Tim, 2026-11-15:** algorithm selection is
  delegated to the implementer and may be refined during testing within the
  agreed behavior. Automatic placement must provide a minimum 5 px gap between
  IC panels, subject to the existing insufficient-space priorities.
- **Gamepad scope - agreed by Tim, 2026-11-15:** replicate current gamepad
  behavior rather than adding or repairing gamepad handling in this feature.
  A whole-addon gamepad review and subsequent fixes are deferred to TODO F14.
  This intentionally supersedes the earlier explicit gamepad-scene requirement.
- **Scene-position identity - agreed by Tim, 2026-11-15:** save locations per
  scene type. Use the user-facing screen/interaction type rather than treating
  each underlying ZOS scene name as a separate position set.
- **Placement obstacle scope - agreed by Tim, 2026-11-15:** avoid only ZOS UI
  and InventoryCompanion panels, not other addons' UI. This intentionally
  narrows the earlier "other UI" wording; third-party UI avoidance is excluded,
  not missing implementation coverage. Tim's direction: "yes narrow the spec
  so it only avoids zos ui and our own".

## Independent spec review

The independent `scene-amendment-review` reviewed the amended spec and plan on
2026-11-17 and found no blocking issues. Its optional request to resolve stale
investigation notes was incorporated in the archived implementation record.

## Approvals and acceptance

- Explicit spec approval: Tim, 2026-11-15, conditional on focused independent
  review; reviewer confirmed revised spec clear and prior findings resolved.
- Feature acceptance: Tim, 2026-11-19, after 1.7.2 UAT passed.
- Actual acceptance evidence: `/ictest verbose copy` passed 88/88; Tim confirmed
  migrated tracked groups, panel settings, and normal positions looked correct
  after reload, and all normal transfer tests passed. The release review is
  retained inside the frozen 1.7.2 package.

Spec approval did not authorize coding; subsequent plan approval and GO to code
are recorded in the archived implementation plan.

## Historical background

This standalone proposal originated as D10.3 in the broader HUD layout and
visibility work. The separate HUD editor, bar-visibility work, and integrated
HUD-editor path are not part of this specification. See the
[HUD layout and visibility archive](../Archive/HUDLayoutAndVisibility/HUDLayoutAndVisibility.md)
for historical material.
