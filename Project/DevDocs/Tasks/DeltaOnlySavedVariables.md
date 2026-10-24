# Delta-Only Saved Variables

**Status:** Planned

## Goal

Store only user-edited rule properties in saved variables. Keep built-in baseline rules separate so future addon updates can change defaults without being obscured by copied baseline data.

The relevant code is in `Tracking/ItemDatabase.lua` and `Tracking/EditPanelGroupsTab.lua`.

## Proposed mutation API

Route edits through focused mutation functions rather than having UI code construct saved-variable tables directly:

- `UpdateRuleFlag(ruleName, flagKey, value)` updates display flags such as `show`, `notify`, or `isHidden`.
- `UpdateRuleProperty(ruleName, propertyKey, value)` updates root-level metadata such as `displayName`.
- `UpdateRulePatterns(ruleName, uiPatterns)` reconciles the edited pattern list against the built-in baseline and stores only the necessary additions, removals, or changes.

Each mutation should invalidate and rebuild the affected runtime rule-cache entry.

For simple root-level updates, the initial proposal was a surgical setter that creates the rule override table only when needed and writes only the requested property. Pattern edits need the reconciliation behavior described above rather than blindly copying baseline patterns into saved variables.

## Read and runtime behavior

The existing read-side audit noted that `GetActiveTrackedRules` checks for non-`nil` saved `displayName` and `patterns` values before applying overrides, allowing absent properties to fall back to baseline data. Confirm this behavior while implementing and testing the write paths.

Keep compiled patterns and rule-cache structures in memory only. Saved variables should contain raw user overrides, not compiled Lua patterns or runtime cache data. Consumers such as item-list generation, scanning, and matching should use the compiled runtime cache where appropriate.

## UI write paths

- Group-name edits should update only the `displayName` override.
- Pattern edits should use full baseline reconciliation, clearing overrides when the edited list matches the baseline again.
- Display-flag changes should update only the selected flag.
- Preserve the group editor's current rows while an input loses focus; saving may refresh the HUD without forcing the editor list to rebuild.

## Verification scenarios

1. With default patterns `{a, b, c}`, verify no redundant baseline copy is written.
2. Add pattern `d`; verify only the required user override is stored and the runtime cache updates.
3. Change baseline pattern `a` to `a1`; verify the override represents the edit.
4. Change `a1` back to `a`; verify the override is cleared when the effective list matches baseline.
5. Rename a group and toggle a display flag; verify each operation changes only its own saved property.
6. Reload the UI and confirm saved overrides are applied while unmodified properties continue to use the baseline.
7. Edit a pattern and move focus; confirm the HUD refreshes without the group editor rows jumping or rebuilding unexpectedly.
