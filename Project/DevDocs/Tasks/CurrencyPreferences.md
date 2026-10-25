# Feature Specification: Currency Preferences and Saved-Variable Maintenance

**Status:** In progress

## 1. Goal

Expand the existing gold/bag/bank overlay into a configurable currency panel. Discover supported currencies from ESO at runtime, display current amounts and optional cap information, and let users control which currencies appear and in what order.

The feature must tolerate currencies being added, removed, or renamed by ESO without treating localized display names as stable identifiers. It should clean up saved preferences for currency IDs ESO no longer considers valid, while preserving unrelated settings and item-tracker data.

## 2. Current State

- `Tracking/CurrencyPanel.lua` renders a compact three-column grid of discovered currency/location entries and addon-defined backpack/bank capacity entries. The grid is movable and its position is saved account-wide.
- `Banking/CurrencyHelper.lua` discovers currencies within `CURT_ITERATION_BEGIN` through `CURT_ITERATION_END`, filtering with `IsCurrencyValid` and `ShouldShowCurrencyInCurrencyPanel`. It exposes currency lists, current information, totals, cap information, and near-cap queries.
- Account-wide `currencyPreferences` and `capacityPreferences` control compact-grid visibility and ordering. Currency refreshes use `EVENT_CURRENCY_UPDATE` and `EVENT_CURRENCY_CAPS_CHANGED` while currency entries are visible.
- LibAddonMenu provides separate IN and OUT resource lists, with one row per currency type. Bankable currencies have independent Character and Bank checkboxes; account-wide currencies have no location checkbox. A row-level Show/Hide control is independent of the selected locations. Shown rows follow compact-grid order and can be reordered; hidden rows are alphabetical in OUT.
- Currency-level `showCompact` and `order` preferences control whether a currency row is in IN/OUT and its row order. Per-location `hidden` preferences independently select which values the compact cell displays. A shown currency with no selected value remains in IN, is marked red in settings, and contributes no HUD value until a location is selected.
- Hiding an entry removes its saved order. Showing it again appends it to the end of the IN list. The reset control restores gold, backpack space, and bank space as the only shown entries without changing the panel position or standalone bars.
- Standalone progress bars now use a reusable movable panel for backpack, bank, and capped-currency resources. Per-bar visibility, thresholds, and colors are being added in the progress-panel implementation plan. Currency notification preferences are stored separately from compact-grid visibility.
- `Core/Tests.lua` stores localized currency names by numeric ID in `currencyNamesById` and warns if a valid ID's observed name changes. That history is diagnostic metadata, separate from user preferences.

## 3. User Experience

1. Keep gold, backpack-space, and bank-space indicators, with their existing visibility behavior as the initial defaults. This feature is unreleased, so old panel-specific preference values do not need migration and may be reset.
2. Add a compact three-column grid for ESO currencies that are valid and eligible for display, matching the existing panel's compact inline presentation. Configurable items-per-row is a future consideration, not part of the initial implementation.
3. Let users configure currencies in separate IN and OUT lists with one settings row per currency type. Each bankable currency has independent Character and Bank checkboxes; account-wide currencies have no location checkbox. Clicking a checkbox or its label toggles that location. Row-level Show/Hide controls whether a currency is in IN or OUT, independently of its location choices. IN follows compact-grid order and has move-up/move-down controls that move selected locations for a currency together. OUT is alphabetical and has no ordering controls. A shown currency with no selected locations remains in IN with a red name and contributes no HUD value. New eligible currencies appear in IN unless explicitly hidden.
4. For currencies available in multiple storage locations, keep independent visibility preferences for each applicable location (for example, character and bank). In the compact panel, combine the selected character and bank values into one cell when both are visible; show only the selected location when just one is visible. Separate values with a middle dot and show each capped value with its rounded percentage of that location's cap. On hover, show the full resource name and a separate line for each displayed location, with full amount and cap details. The combined cell uses the earliest selected location's position in the grid order. Combined character-plus-bank totals (a summed amount) remain deferred beyond Phase 1.
5. Do not require an active bank interaction to read currency amounts. Do not perform currency transfers or other mutations.
6. New eligible currencies should be discoverable without an addon update. Unless the user has explicitly hidden them, new currencies should appear after existing ordered entries.
7. Add an account-wide `Show Empty Currencies` option, enabled by default, with a matching right-click panel-menu toggle. When disabled, show a currency cell only if at least one selected location has a balance greater than zero; retain both selected values in a combined cell if either one is positive. Apply the same rule to account-wide currencies, not to bag/bank capacity entries. Keep currency update listeners active for shown, selected locations even when their current balances are zero.
8. Provide an independent Notify option per currency. Notify on every nonzero balance change, including gains and spends; a transfer may notify for both the source decrease and destination increase. Currency notifications remain active when their currency is hidden from the HUD and reuse the addon's existing notification and duplicate-suppression behavior.

## 4. Currency Discovery and Identity

- Treat the ESO currency type integer plus storage location as the runtime and saved-preference identity for location-specific entries. Never key preferences by localized currency name, texture path, or a mined constant's text name.
- Use the helper's dynamic currency list as the source for entries the panel can display.
- Distinguish “not currently eligible for display” from “invalid/removed”: hiding a currency in the panel must not erase its preference.
- Currency name history is diagnostic only. A change in the localized name for the same numeric ID should produce a warning, not fail the test suite or silently reset that currency's preferences.
- `GetCurrencyName` is localized. A client-language change can therefore look like an ID rename. Document this caveat in warning output. Do not delete preferences or name history solely because a name changed.
- Keep history entries for IDs that are currently invalid so a later reuse of an ID can be detected. History is small and is not a preference-pruning target.

## 5. Saved-Variable Design

Store currency display choices account-wide, consistent with existing overlay settings. Store only deviations from defaults:

```lua
currencyPreferences = {
    [currencyType] = {
        showCompact = true, -- absent means default-visible; false means row is in OUT
        order = 3,          -- row order shared by its selected locations
        notify = true,      -- absent/false disables gain notifications
        locations = {
            [location] = {
                hidden = true, -- absent/false means visible
            },
        },
    },
}
```

Requirements:

- Top-level keys are numeric ESO currency type IDs; nested location keys are ESO currency storage locations.
- Do not write entries for default row visibility or automatic ordering. A location's selection does not change the currency row's IN/OUT state; hiding a whole row stores `showCompact = false` and clears its row order. Per-location preferences only store deviations from selected-by-default visibility.
- Treat missing, malformed, or obsolete preference entries defensively. A malformed entry should be reported and skipped or normalized without discarding unrelated saved variables.
- Apply explicit order values first; append visible entries with no saved order in deterministic ESO currency discovery and location order. Resolve duplicate or invalid order values deterministically.
- Continue to use `currencyNamesById` only for diagnostics; do not copy names into `currencyPreferences`.

## 6. Pruning and Migration

- During `/icclean`, remove preference entries whose numeric IDs are no longer `IsCurrencyValid`. Report the count and IDs removed.
- Do not prune preferences merely because `ShouldShowCurrencyInCurrencyPanel` currently excludes an otherwise valid ID.
- Prune only known addon-owned preference entries. Preserve unrelated saved variables, item/rule data, and unknown top-level keys.
- Preserve currency ID name history even when an ID is invalid, for possible future ID-reuse warnings.
- Keep targeted cleanup for known diagnostic leftovers (such as `currencyInfo` and `lastquery`) as distinct logic from currency preference pruning, even though both run through `/icclean`.
- Do not infer that an old currency preference is invalid from its display name, texture, or the absence of a matching mined constant.

## 7. Settings UI and Integration

- Add a currency-preferences section to the existing settings panel using current LibAddonMenu patterns.
- Initialize currency discovery before building the settings controls. ESO currency definitions are stable during a logged-in session, so settings can use the startup-discovered list; no in-session currency-list watcher is required.
- Provide separate IN and OUT lists with one row per currency type. Bankable currencies have independent Character and Bank checkboxes; account-wide currencies have no location checkbox. Clicking either a checkbox or its label toggles that location. A separate Show/Hide control moves the row between IN and alphabetized OUT without changing location choices. IN follows grid order and has move-up/move-down controls that move the currency row and its selected locations together; OUT has no ordering controls. A shown currency with no selected locations stays in IN, with its name colored red, and contributes no value to the panel. Capacity resources have their own rows with compact-panel controls. Include a reset control that restores only gold, backpack space, and bank space to IN while preserving the panel position and standalone-bar preferences.
- Refresh the currency panel immediately after a preference changes.
- The zero-balance filter is independent of currency row visibility and location selection. Keep the currency update listener active while any shown row has a selected location, even if the filter currently hides all currency cells.
- Replace the unreleased panel-specific visibility controls with resource preferences; no compatibility migration for `showGold`, `showBag`, or `showBank` is required.
- Keep currency discovery, preference normalization/pruning, and rendering separate: the helper supplies live ESO data; saved variables supply user choices; the panel combines them.

## 8. Verification

### Synthetic checks

1. First initialization shows gold plus backpack and bank space; other currently discovered currencies start in OUT. A currency first discovered later appears in IN unless explicitly hidden.
2. When both character and bank locations are visible, the panel renders one combined cell with both values separated by a middle dot; when only one is visible, it renders only that location's value.
3. Capped currency values show a rounded percentage based on the matching location's amount and cap; uncapped values omit the percentage.
4. Hovering a compact cell shows the full resource name and lines only for its displayed locations, with full amounts and cap details where available.
5. Toggling a location checkbox or its label changes only that location; unchecking all locations on a shown row marks its name red but does not move the row to OUT, and it contributes no value to the HUD.
6. Show/Hide moves the whole currency row between IN and OUT without clearing its location choices. Showing an OUT currency appends it to IN; moving an IN currency updates settings and HUD order, moving its selected locations together.
7. Reset restores only gold, backpack space, and bank space to IN, resets their order, and preserves the panel position and standalone bars.
8. Duplicate, missing, or malformed order values produce deterministic output.
9. Pruning removes an invalid currency ID but preserves valid hidden/order entries for every location.
10. A valid currency omitted by `ShouldShowCurrencyInCurrencyPanel` retains its preferences.
11. Unrelated account settings, character settings, tracked items, and tracked rules are unchanged by pruning.
12. A currency name change for the same ID warns without deleting preferences; an unchanged name does not warn again.

### In-game checks

1. Verify eligible currency/location entries, amounts, and location-matched caps against ESO's UI/API.
2. Hide, reorder, and restore currency/location entries; verify immediate panel refresh and persistence after `/reloadui`.
3. Verify an ESO-added currency appears without adding a hand-maintained preference entry.
4. Simulate or inspect an invalid/removed currency ID and verify only its preference is pruned.
5. Verify the gold, bag-space, and bank-space defaults and independent preferences behave as specified after reload.
6. Hover cells to verify the full resource name and only the displayed location lines appear; confirm hovering does not interfere with moving the panel.
7. In settings, verify each currency has one row, each location checkbox and its label toggle only that location, and moving a currency reorders its selected locations together.
8. Verify a shown currency with no selected locations remains in IN with a red name, has no HUD cell, and does not keep currency update listeners active by itself.
9. With `Show Empty Currencies` disabled, verify zero-balance currencies are omitted, a combined cell remains if either selected location is positive, account-wide zero balances are omitted, and capacity indicators are unaffected. Verify a currency that changes from zero to positive appears without toggling settings.

## 9. Product Decisions Deferred Beyond Phase 1

Combined character-plus-bank totals are deferred beyond Phase 1. Standalone progress bars remain independent movable windows with separately saved positions, preserving the existing bag/bank behavior. Compact-grid entries use move-up/move-down ordering in the IN list; OUT entries are alphabetical and return to the bottom of IN when shown. For remaining investigations, see [Currency Panel Implementation Plan](./CurrencyPanelImplementationPlan.md).

## Appendix: Superseded Original Ordering Requirements

The following wording was part of the original specification before the IN/OUT workflow was chosen. It is retained for decision history; the current requirements above take precedence.

- “Let users enable/disable individual currency/location entries. In settings, show enabled and disabled entries in separate lists. Use move-up/move-down controls to order enabled compact-grid entries. Preserve an entry's order when disabled so it returns to the same position when re-enabled; append new eligible entries after existing ordered entries.”
- “Apply explicit order values first; append entries with no saved order in deterministic ESO currency discovery and location order. Preserve ordering for disabled entries so re-enabling restores their position. Resolve duplicate or invalid order values deterministically.”
- “Provide separate enabled and disabled entry lists. Use move-up/move-down controls to order enabled compact-grid entries, preserving positions when entries are disabled and re-enabled.”
- “Missing preferences show all eligible currency/location entries in ESO discovery and location order.”

## Appendix: Superseded Original Compact-Display Requirement

The following location-by-location display wording predates the compact combined-cell treatment above. Separate settings preferences remain current; the compact presentation rule in Section 3 takes precedence.

- “For currencies available in multiple storage locations, show separate entries for each applicable location (for example, character and bank entries). Each entry displays the amount and cap for that same location and can be shown, hidden, and ordered independently. Account-wide currencies have a single account entry. Combined character-plus-bank totals are deferred beyond Phase 1.”

## Appendix: Superseded Original Settings-Row Requirement

The following wording predates the independent row-level Show/Hide control and is retained for decision history. The current requirements above take precedence.

- “A currency is IN when at least one location is selected and OUT only when all applicable locations are hidden. Account-wide currencies have one Account checkbox.”
