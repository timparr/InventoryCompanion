# Feature Specification: Currency Preferences and Saved-Variable Maintenance

**Status:** In progress

## 1. Goal

Expand the existing gold/bag/bank overlay into a configurable currency panel. Discover supported currencies from ESO at runtime, display current amounts and optional cap information, and let users control which currencies appear and in what order.

The feature must tolerate currencies being added, removed, or renamed by ESO without treating localized display names as stable identifiers. It should clean up saved preferences for currency IDs ESO no longer considers valid, while preserving unrelated settings and item-tracker data.

## 2. Current State

- `Tracking/CurrencyPanel.lua` renders a compact three-column grid of discovered currency/location entries and addon-defined backpack/bank capacity entries. The grid is movable and its position is saved account-wide.
- `Banking/CurrencyHelper.lua` discovers currencies within `CURT_ITERATION_BEGIN` through `CURT_ITERATION_END`, filtering with `IsCurrencyValid` and `ShouldShowCurrencyInCurrencyPanel`. It exposes currency lists, current information, totals, cap information, and near-cap queries.
- Account-wide `currencyPreferences` and `capacityPreferences` control compact-grid visibility and ordering. Currency refreshes use `EVENT_CURRENCY_UPDATE` and `EVENT_CURRENCY_CAPS_CHANGED` while currency entries are visible.
- LibAddonMenu provides visibility and ordering controls for each discovered entry. Existing standalone backpack and bank progress bars remain unchanged.
- This first implementation slice does not yet add currency progress bars, advanced per-bar settings, separate enabled/hidden settings lists, or invalid-ID preference pruning.
- `Core/Tests.lua` stores localized currency names by numeric ID in `currencyNamesById` and warns if a valid ID's observed name changes. That history is diagnostic metadata, separate from user preferences.

## 3. User Experience

1. Keep gold, backpack-space, and bank-space indicators, with their existing visibility behavior as the initial defaults. This feature is unreleased, so old panel-specific preference values do not need migration and may be reset.
2. Add a compact three-column grid for ESO currencies that are valid and eligible for display, matching the existing panel's compact inline presentation. Configurable items-per-row is a future consideration, not part of the initial implementation.
3. Let users enable/disable individual currency/location entries. In settings, show enabled and disabled entries in separate lists. Use move-up/move-down controls to order enabled compact-grid entries. Preserve an entry's order when disabled so it returns to the same position when re-enabled; append new eligible entries after existing ordered entries.
4. For currencies available in multiple storage locations, show separate entries for each applicable location (for example, character and bank entries). Each entry displays the amount and cap for that same location and can be shown, hidden, and ordered independently. Account-wide currencies have a single account entry. Combined character-plus-bank totals are deferred beyond Phase 1.
5. Do not require an active bank interaction to read currency amounts. Do not perform currency transfers or other mutations.
6. New eligible currencies should be discoverable without an addon update. Unless the user has explicitly hidden them, new currencies should appear after existing ordered entries.

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
        locations = {
            [location] = {
                hidden = true, -- absent/false means visible
                order = 3,     -- optional user-selected order
            },
        },
    },
}
```

Requirements:

- Top-level keys are numeric ESO currency type IDs; nested location keys are ESO currency storage locations.
- Do not write entries for default visibility or automatic ordering.
- Treat missing, malformed, or obsolete preference entries defensively. A malformed entry should be reported and skipped or normalized without discarding unrelated saved variables.
- Apply explicit order values first; append entries with no saved order in deterministic ESO currency discovery and location order. Preserve ordering for disabled entries so re-enabling restores their position. Resolve duplicate or invalid order values deterministically.
- Continue to use `currencyNamesById` only for diagnostics; do not copy names into `currencyPreferences`.

## 6. Pruning and Migration

- During `/ictest`, remove preference entries whose numeric IDs are no longer `IsCurrencyValid`. Report the count and IDs removed.
- Do not prune preferences merely because `ShouldShowCurrencyInCurrencyPanel` currently excludes an otherwise valid ID.
- Prune only known addon-owned preference entries. Preserve unrelated saved variables, item/rule data, and unknown top-level keys.
- Preserve currency ID name history even when an ID is invalid, for possible future ID-reuse warnings.
- Keep the existing targeted cleanup for known diagnostic leftovers (such as `currencyInfo` and `lastquery`) separate from currency preference pruning.
- Do not infer that an old currency preference is invalid from its display name, texture, or the absence of a matching mined constant.

## 7. Settings UI and Integration

- Add a currency-preferences section to the existing settings panel using current LibAddonMenu patterns.
- Initialize currency discovery before building the settings controls. ESO currency definitions are stable during a logged-in session, so settings can use the startup-discovered list; no in-session currency-list watcher is required.
- Provide separate enabled and disabled entry lists. Use move-up/move-down controls to order enabled compact-grid entries, preserving positions when entries are disabled and re-enabled.
- Refresh the currency panel immediately after a preference changes.
- Replace the unreleased panel-specific visibility controls with resource preferences; no compatibility migration for `showGold`, `showBag`, or `showBank` is required.
- Keep currency discovery, preference normalization/pruning, and rendering separate: the helper supplies live ESO data; saved variables supply user choices; the panel combines them.

## 8. Verification

### Synthetic checks

1. Missing preferences show all eligible currency/location entries in ESO discovery and location order.
2. Hiding a currency/location entry omits only that entry; other locations and currencies remain visible.
3. Explicit order values are respected; new currency/location entries without an order are appended.
4. Duplicate, missing, or malformed order values produce deterministic output.
5. Pruning removes an invalid currency ID but preserves valid hidden/order entries for every location.
6. A valid currency omitted by `ShouldShowCurrencyInCurrencyPanel` retains its preferences.
7. Unrelated account settings, character settings, tracked items, and tracked rules are unchanged by pruning.
8. A currency name change for the same ID warns without deleting preferences; an unchanged name does not warn again.

### In-game checks

1. Verify eligible currency/location entries, amounts, and location-matched caps against ESO's UI/API.
2. Hide, reorder, and restore currency/location entries; verify immediate panel refresh and persistence after `/reloadui`.
3. Verify an ESO-added currency appears without adding a hand-maintained preference entry.
4. Simulate or inspect an invalid/removed currency ID and verify only its preference is pruned.
5. Verify the gold, bag-space, and bank-space defaults and independent preferences behave as specified after reload.

## 9. Product Decisions Deferred Beyond Phase 1

Combined character-plus-bank totals are deferred beyond Phase 1. Standalone progress bars remain independent movable windows with separately saved positions, preserving the existing bag/bank behavior. Compact-grid entries use move-up/move-down ordering in the settings panel; disabled entries retain their position, while newly discovered entries append. For remaining investigations, see [Currency Panel Implementation Plan](./CurrencyPanelImplementationPlan.md).
