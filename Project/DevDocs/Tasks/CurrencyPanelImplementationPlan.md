# Currency and Capacity Panel Implementation Plan

**Status:** Proposed

## Goal

Unify the panel's resource discovery, preferences, and presentation so ESO currencies and addon-defined capacities can be configured in one place, without conflating their identities or changing existing defaults.

The existing currency-specific requirements, including ESO validity checks and diagnostic name history, remain in [Currency Preferences](./CurrencyPreferences.md). This plan adds the broader resource UX and implementation approach.

## UX Decisions

- Use the existing LibAddonMenu settings panel for Phase 1 resource configuration.
- Provide one **Resources** settings section with one row per currency type. Bankable currencies have separate Character and Bank checkboxes; account-wide currencies have no location checkbox. Clicking an option's label toggles that checkbox. Every resource row has a separate visibility control; backpack and bank capacity resources have their own rows.
- Keep the resource name and checkbox labels as the clickable targets. Lay out the row from the right edge: align visibility and reorder controls at the right, place the Bank checkbox near visibility with a larger gap before Character, then Notify; let the resource name use the remaining width. Use compact `+`/`−` visibility buttons with tooltips and truncate long resource names to a single line with an ellipsis. Try this spacing first without reducing the font; adjust after visual review if still crowded.
- Provide an independent notification option for each currency, following the tracked-item notification behavior. Notification preferences do not depend on whether the currency is shown in the compact panel or has a standalone bar.
- Bag and bank space notifications follow the Transmute Crystals model: report used slots out of total slots, the percentage used, and use the corresponding progress bar's thresholds and colours for the balance.
- For bag-space changes other than bank transfers, notify only about the bag: use “Freed up X Bag Space” when used slots decrease and “Used an additional X Bag Space” when used slots increase. X is the change in used slots, not necessarily the number of items.
- Treat moves between bag and bank as one transfer notification, not separate bag and bank change notifications. State the direction and number of items moved, then show the updated used/total and percentage for both bag and bank, each with its own icon and progress-bar colour. The movement wording need not claim an exact number of slots freed; the displayed balances must be the actual current values.
- Keep notification controls for bag and bank independently configurable. Every resource row, including Backpack and Bank space, has a Notify checkbox, stored as `capacityPreferences.<bag|bank>.notify`. Notify is the rightmost checkbox column, nearest the +/- button (25 px gap), with Bank then Character to its left (20 px gaps).
- Keep the compact HUD panel for glanceable values. Resources can be shown there, in a standalone progress bar, in both, or hidden.
- Use a compact three-column grid for the initial HUD layout, matching the existing inline panel's compact feel.
- Keep standalone bars optional rather than automatically creating a bar for every capped currency. This avoids clutter as ESO adds currencies.
- Preserve current defaults: gold, backpack space, and bank space continue to appear as they do today, including the existing standalone backpack and bank bars.
- Keep each enabled progress bar as an independently movable window with its own saved position. This preserves current bag/bank behavior; additional currency bars follow the same independent-window model in Phase 1.
- Render gold once, sourced from ESO currency discovery.
- Preserve each currency/storage-location pair as an independent saved value-selection preference (for example, character and bank); the single currency settings row exposes those preferences as separate checkboxes, while the compact display combines selected locations. Keep row-level Show/Hide and order separate from the location selections.
- Represent each account-wide currency with one account entry.
- Display the amount and cap for the same location on each entry.
- Order compact-grid resources with move-up/move-down controls in settings. A currency's IN/OUT state is separate from its location choices. A shown currency with no locations selected remains in IN, is marked red, and contributes no grid cell. Moving a currency row moves its selected locations together. Hidden rows are listed alphabetically in OUT. Only IN rows have move controls. New eligible currencies appear in IN unless explicitly hidden.
- Provide a reset control that restores the compact grid to gold, backpack space, and bank space only, clears resource ordering, and preserves the panel position and standalone-bar preferences.
- For capped resources, make amount and cap available to the presentation and allow a progress bar.
- Retain the existing bag and bank warning/danger thresholds as per-bar defaults (bag: 75% warning / 90% danger; bank: 80% warning / 95% danger). Let users configure warning and danger thresholds independently for each progress bar. When a change crosses the other threshold, the setter adjusts the other threshold to match, preserving the selected value.
- **Bar colours (decided):** Let users choose each bar's normal/base fill colour, with optional global warning (amber) and danger (red) colours shared by all bars. This keeps resource identity visible in normal use while making alert semantics consistent.
- Keep each bar's advanced settings collapsed by default, with an independent expand/collapse control per bar. Allow multiple bars' settings to remain expanded simultaneously so users can compare or synchronize values.
- Refresh affected HUD presentations immediately after preference changes.

## Currency Panel Refinement

The first refinement is to restore a super-compact, single-line grid treatment: each cell shows its icon and abbreviated value, without a text title or location abbreviations. Use the addon's existing big-number formatter (for example, `1.3k` or `32m`) and keep the three-column layout and existing resource defaults and preference behavior unchanged. Capped values include their rounded percentage of cap. Hovering a cell shows a tooltip with the full resource name and a separate line for each location currently shown, using full amounts and cap information when available.

When both character and bank entries for a currency are visible, render them in one cell as values divided by a middle dot; when only one is visible, show only that location's value. Account-wide currencies show a single value. Preserve separate visibility and ordering preferences for each location. Place a combined cell at the earlier of its selected locations' positions in the grid order.

Size each occupied grid column to fit its widest displayed value, without a fixed minimum cell width. Leave unused trailing columns out of the grid dimensions. Combined amounts and cap percentages therefore expand columns as needed, while short values keep the panel compact. Review in game whether column-width changes as amounts update remain acceptable. Character and bank remain independent saved visibility options, shown as checkboxes in one currency settings row; their selected values combine in the compact display.

## Implemented Refinement: Hide Zero-Balance Currencies

The Currency Summary Panel has a `Show Empty Currencies` setting, defaulting to enabled, following the item-tracking panel's `showEmptyTrackedItems` pattern. The panel's right-click menu also toggles between showing and hiding zero-balance currencies. When disabled, a currency cell appears only if at least one selected location has a balance greater than zero; a combined character/bank cell remains as a whole when either selected location has a positive balance. Account-wide currencies follow the same rule. The filter is independent of row Show/Hide and location selection, and does not affect bag/bank capacity indicators. Currency update listeners remain active while any shown currency location is selected, including when all of those balances are zero, so a later positive balance appears without requiring another settings change.

## Settings Panel Mockup

The resource names and amounts below are illustrative. Three of the eight example resources are capped. The mockup shows one bar's advanced settings expanded; each bar can be expanded independently, and multiple sections may remain open at once.

```text
Inventory Companion — Currency & Capacity Panel

COMPACT GRID (3 columns)

IN — Shown in grid
  [icon] Currency A             [Character ✓] [Bank ✓] [Hide][↑][↓]
       12,450 (25%) · 8,200 (16%)
             Warning at 75%   [────────●──]
             Danger at  90%   [──────────●]
             Normal colour   [colour picker]
  [icon] Currency B             [Character ✓] [Bank  ] [Hide][↑][↓]
       8,120
  [icon] Currency C                                      [Hide][↑][↓]
       950

OUT — Hidden from grid (alphabetical)
  [icon] Currency G             [Character ✓] [Bank  ] [Show]
  [icon] Currency H                                      [Show]

  [Reset Currency Panel Preferences]

GLOBAL BAR ALERT COLOURS
  Warning / amber                  [colour picker]
  Danger / red                     [colour picker]
```

Each checkbox controls one storage location; clicking the checkbox text toggles the same option. Account-wide currencies have no location checkbox. Show/Hide controls whether a resource row is in IN or OUT, independently of currency location selections. If a shown currency has no selected locations, its name is red in settings and it contributes no value to the HUD until a location is selected. IN resource rows follow grid order and move as a unit; capacity rows use Show/Hide. The reset returns the grid to gold, backpack space, and bank space, without changing the panel position or standalone-bar preferences. `Bar` independently controls the standalone progress bar; its advanced settings expose per-bar warning/danger thresholds and normal colour only when that bar is enabled. Bars are independently movable, so they have no ordering controls.

## Needs Decision

- **Currency panel placement and visibility overrides:** The panel stays at its saved position and is forced visible while this addon's LibAddonMenu settings panel is open. Decide whether it should move temporarily to avoid covering settings, and which other interactions (such as the item/group editors, inventory or bank interactions, and cutscenes) should override its normal visibility rules.

## Decided, Needs Investigation

- **Value refresh lifecycle and listener strategy:** Use event-driven refreshes and keep listeners active only while relevant displays are enabled. The [ESO API declarations](https://github.com/Flat-Badger-1971/eso-api/blob/01973824df2bb303d1a148c5ab350cf50405bd0b/library/events.lua) specify `EVENT_CURRENCY_UPDATE(eventId, currencyType, currencyLocation, newAmount, oldAmount, reason, reasonSupplementaryInfo)`. [ESOUI shared inventory](https://github.com/esoui/esoui/blob/86832f7b492a5bd3e2774fe187caf1cc527735df/esoui/ingame/inventory/sharedinventory.lua) filters by currency type and storage location, and [ESOUI currency input](https://github.com/esoui/esoui/blob/86832f7b492a5bd3e2774fe187caf1cc527735df/esoui/ingame/zo_currencyinput/zo_currencyinput.lua) listens to the event for `CURT_MONEY` (gold). In-game testing confirmed the event fires for Writ Vouchers, Alliance Points, Tel Var Stones, and gold when transferring currency between character and bank; it also fires for gold when buying from or selling to a merchant. The event API is generic across currency types, so treat `EVENT_CURRENCY_UPDATE` as the update source for all ESO currencies, including gameplay gains, rather than requiring individual verification of every currency. A separate `EVENT_MONEY_UPDATE` listener is not currently indicated. Also listen for `EVENT_CURRENCY_CAPS_CHANGED` while displayed currencies use cap data; it has no currency/location payload, so refresh affected cap-dependent displays. In the panel, register currency listeners only while at least one currency/location entry is displayed and filter updates against enabled entries. Keep bag/bank capacity refreshes on their capacity and inventory-slot events. Avoid polling unless later testing demonstrates that no event-driven approach is sufficient.
- **Currency notifications implementation:** Each currency has an independent Notify checkbox in the Currency Summary Panel settings row. Notification preferences do not depend on compact-panel or bar visibility. Reuse `Core/Utils.lua`'s `UserWarning` presentation and duplicate suppression. Notify on every nonzero balance change, including gains and spends; the HUD uses abbreviated amounts while chat uses exact amounts. Both identify the resulting Bag and Bank balances (or Account balance for account-wide currencies). Rapid changes are held and merged, and one net notification is sent after one second with no further change (a net-zero burst sends nothing). Bank deposit and withdrawal reasons are combined into one directional transfer notification instead of separate gain and spend messages. Keep `EVENT_CURRENCY_UPDATE` registered while any currency notification is enabled, even when that currency is otherwise hidden from HUD displays. ESO reports login balances as changes from zero, so compare each event against a last-known balance per currency and location, seeded silently at startup and when notifications are enabled; the first observation of a balance never notifies. The debug key's delayed formatting demo calls the shared presentation helpers with virtual balances and does not exercise event detection; `/ictest` separately feeds paired bank/character updates through the currency notification handler to verify transfer interpretation. Preserve existing tracked-item notification behavior.
- **Currency event diagnostic:** The temporary `/iccurrencyevents start|stop` diagnostic was used to confirm representative currencies and transactions, then removed from the shipped addon. Coverage of every currency individually is not required because the event is generic by currency type and location. To repeat the test, temporarily add this block to `Core/Init.lua`; it displays currency, location, old/new amounts, and reason as HUD messages. Cap-change event behavior remains to be verified if a suitable in-game test becomes available.

```lua
local currencyEventDiagnosticName = this.Name .. "_CurrencyEventDiagnostic"
local currencyEventDiagnosticActive = false

local function OnDiagnosticCurrencyUpdate(_, currencyType, currencyLocation, newAmount, oldAmount, reason)
    local currencyName = GetCurrencyName(currencyType, false, false)
    local locationName = GetString("SI_CURRENCYLOCATION", currencyLocation)
    this.Utils.UserMessage(nil, string.format(
        "%s (ID %s, %s): %s -> %s, reason %s",
        tostring(currencyName),
        tostring(currencyType),
        tostring(locationName),
        tostring(oldAmount),
        tostring(newAmount),
        tostring(reason)
    ))
end

local function OnDiagnosticCurrencyCapsChanged()
    this.Utils.UserMessage(nil, "Currency caps changed")
end

SLASH_COMMANDS["/iccurrencyevents"] = function(arguments)
    local action = tostring(arguments or ""):lower():match("^%s*(%S+)%s*$")

    if action == "start" then
        if currencyEventDiagnosticActive then
            this.Utils.UserMessage("Currency event diagnostics are already running.")
            return
        end
        EVENT_MANAGER:RegisterForEvent(currencyEventDiagnosticName, EVENT_CURRENCY_UPDATE, OnDiagnosticCurrencyUpdate)
        EVENT_MANAGER:RegisterForEvent(currencyEventDiagnosticName, EVENT_CURRENCY_CAPS_CHANGED, OnDiagnosticCurrencyCapsChanged)
        currencyEventDiagnosticActive = true
        this.Utils.UserMessage("Currency event diagnostics started.", "Listening for currency changes")
    elseif action == "stop" then
        if currencyEventDiagnosticActive then
            EVENT_MANAGER:UnregisterForEvent(currencyEventDiagnosticName, EVENT_CURRENCY_UPDATE)
            EVENT_MANAGER:UnregisterForEvent(currencyEventDiagnosticName, EVENT_CURRENCY_CAPS_CHANGED)
            currencyEventDiagnosticActive = false
        end
        this.Utils.UserMessage("Currency event diagnostics stopped.")
    else
        this.Utils.UserMessage("Use /iccurrencyevents start or /iccurrencyevents stop.")
    end
end
```
- **Storage-location marker:** First prototype layering a small location badge over the existing currency icon and inspect it in game at the compact grid size. Check that the layering is reliable and the result remains clear across icons/backgrounds. If it is brittle or visually poor, compare against a small addon-owned texture before choosing the final treatment.

## Resource Identity

Keep `GetCurrencyList()` and currency helper APIs limited to real ESO currency type IDs, because callers may pass those IDs to ESO APIs such as `IsCurrencyValid`, `GetCurrencyName`, or `GetCurrencyAmount`.

Instead, create a presentation-facing resource descriptor list that combines:

- ESO currencies, identified by their numeric currency type.
- Addon-defined capacity resources, such as backpack and bank slots, identified by stable addon-owned keys (for example, `capacity:bag` and `capacity:bank`).

Each descriptor should state its kind and identity explicitly and supply the values and capabilities needed by the presentation. Currency discovery remains in the currency helper; capacity values remain sourced from bag APIs. Gold is an ordinary discovered currency and must not have a second synthetic entry.

## Preference Model

Keep preferences account-wide in separate `currencyPreferences` and `capacityPreferences` tables. This keeps ESO currency ID/location pruning separate from addon-defined capacity settings while the Resources UI combines both domains. Persist only deviations from default visibility and automatic ordering.

Conceptual example:

```lua
currencyPreferences = {
    [ESO_CURRENCY_TYPE] = {
        locations = {
            [CURRENCY_LOCATION_CHARACTER] = { hidden = true },
            [CURRENCY_LOCATION_BANK] = { order = 2 },
        },
    },
}

capacityPreferences = {
    bag = { showCompact = false },
    bank = { showBar = false },
}
```

The exact nested fields should be finalized during implementation. Do not clear or alter unrelated account, character, item, or rule settings.

Order compact-grid entries deterministically: explicit valid order first, then unspecified entries in stable discovery and location order. Progress bars have no ordering preference because each is independently movable.

Threshold preferences apply only to bar-capable resources and should be omitted when equal to defaults. When a setter changes warning above danger, set danger to warning; when it changes danger below warning, set warning to danger. Equal thresholds are valid and the existing danger-first rendering makes the bar switch directly to danger at that point. Validate and normalize malformed preferences without discarding unrelated saved variables. The current implementation's bag and bank warning/danger colors are fixed code constants, not user-settable options. LibAddonMenu color-picker controls can support the proposed per-bar normal colour and shared global warning/danger colours.

## Implementation Phases

1. **Resource model:** Define a presentation-facing resource descriptor contract. Adapt ESO currency helper results and bag/bank capacity APIs without changing currency-only API semantics.
2. **Preference normalization:** Add stable identities, default resolution, and deterministic ordering. Initialize preferences using the planned defaults and keep diagnostic currency-name history separate.
3. **HUD presentation:** Render the compact resource panel from descriptors and preferences. Implement generalized standalone bars in new `Banking/ResourceProgressBars.lua` and `Banking/ResourceProgressBars.xml` files, using one reusable panel template and separate movable instances for selected capped resources. Preserve the current appearance and backpack/bank defaults, then remove the old progress-panel files after the replacement is integrated and verified. Existing saved bar positions do not need migration; this feature is unreleased, so new default positions are acceptable.
4. **Settings UI:** Initialize currency discovery before creating the settings controls so resource rows use the session's discovered currency set. Add one row per currency type with independent location checkboxes whose labels are clickable; order shown currency rows as units. Keep capacity rows independently toggleable, add an independent notification option per currency, and add per-resource thresholds only for standalone bars.
5. **Currency notifications:** Add a per-currency Notify checkbox and connect positive `EVENT_CURRENCY_UPDATE` deltas to the existing `UserWarning` notification path. Keep the currency listener active for notification-only preferences, independently of HUD visibility.
6. **Bag and bank space notifications (implemented):** Add independent notification preferences and event-driven change tracking for bag and bank capacity. Bag-only changes use the agreed “Freed up” / “Used an additional” wording; a bag-bank move produces one directional transfer message showing both updated balances. Use the respective progress-bar thresholds and colours, and keep load-screen updates silent. Implementation notes: the slot-update listener is registered whenever either Notify setting is on; each slot update compares used slots with a baseline, and changes merge over the same 1 s quiet period as currency. A bag change and an opposite bank change while the bank is open count as a transfer (items moved = the smaller change in used slots); any remainder is announced as a bag change. Bank-only changes away from the bank are not announced. Messages are in `Tracking/CurrencyPanel.lua` (`NotifyCapacityChange`); tests are the “Capacity messages” scenarios, the colour test, “Capacity notification preferences” and the listener-transition test in `Core/Tests.lua`; the debug demo includes virtual capacity examples.
7. **Pruning and diagnostics:** Extend `/icclean` to prune only invalid ESO currency preference IDs, preserve valid but currently undisplayable currencies, and leave addon capacity preferences and name history intact.
8. **Verification:** Add synthetic checks for identity separation, defaults, ordering, malformed preferences, pruning, and preservation of unrelated data. Use the confirmed `EVENT_CURRENCY_UPDATE` path for currency refreshes; verify cap-change behavior if practical and that disabled entries do not keep unnecessary panel listeners active. Then verify currency and capacity notification preferences and event behavior, settings persistence, and HUD behavior.

## Acceptance Checks

- Gold is discovered and rendered once; its amount matches ESO.
- Bag and bank remain addon-defined capacity resources and use the planned defaults after reload; old panel positions may reset, while unrelated saved variables remain unchanged.
- Each applicable currency/location entry displays its matching amount and cap; account-wide currencies have one account entry.
- A capped ESO currency can be displayed compactly and optionally as a standalone bar; uncapped currencies do not offer bar-only threshold controls.
- Hiding, ordering, or configuring a resource does not change another resource's preferences.
- Each currency has exactly one settings row; each location checkbox and its label changes only that location, and moving the row reorders its selected locations together.
- A shown currency with no selected locations remains in IN, is marked red, and contributes no cell or currency-listener requirement to the HUD.
- All nonzero currency changes produce notifications only for currencies with notification enabled, independently of compact-panel and standalone-bar visibility. Unchanged balances do not notify; transfers notify for both changed locations.
- Invalid ESO currency preferences are pruned; valid but currently ineligible currency preferences and capacity preferences remain.
- Unknown saved-variable keys and unrelated account, character, item, and rule data are preserved.
- A newly eligible ESO currency appears automatically with defaults and no addon update.

## Out of Scope for Phase 1

- Configurable grid column count; use three columns.
- Combined character-plus-bank currency totals; display separate location entries instead.
- A dedicated Resources tab in the custom tracking editor; use LibAddonMenu.
- Synthetic negative IDs for addon-defined capacities; use explicit resource descriptors and addon-owned keys instead.
- Compatibility migration of the unreleased panel's visibility, threshold, or position settings. Initialize new preferences from defaults; resetting old panel positions is acceptable.
- In-session currency-discovery watchers or reload prompts; ESO currency definitions are stable during a login session, so use the startup-discovered set.
- Ordering standalone progress bars; each bar is independently movable.
- Polling as a currency-refresh mechanism unless event investigation demonstrates that no suitable event-driven approach exists.

## Appendix: Superseded Original Ordering Requirements

The following wording was part of the original plan before the IN/OUT workflow was chosen. It is retained for decision history; the current UX decisions above take precedence.

- “Order compact-grid entries with move-up/move-down controls in settings. Show enabled and disabled resources in separate lists/sections so users only need to order the entries they currently display. Keep each entry's saved order when disabled; when re-enabled, return it to that position. Append new eligible entries after existing ordered entries.”

## Appendix: Superseded Original Location-Selection Requirement

The following wording is retained for decision history; the current UX decisions above take precedence.

- “A currency with no locations selected is one OUT row, listed alphabetically. Account-wide currencies have an Account checkbox.”
- “`Grid` controls compact-panel visibility; `Bar` independently controls the standalone progress bar. Bar settings expose per-bar warning/danger thresholds and normal colour only when that bar is enabled. Grid ordering controls apply to shown entries; disabled entries retain their positions for when they are re-enabled. Bars are independently movable, so they have no ordering controls.”
