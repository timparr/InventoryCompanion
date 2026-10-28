# Completed Work

Completed work is recorded here for project history and future release-note drafting. This is an internal record; summarize user-facing changes in a release changelog when publishing.

## Implemented - Awaiting In-Game Acceptance

- **Delta-only saved rules and lazy matching cache:** Built-in rules persist only edited names/flags and sorted pattern additions/removals. Group mutations and imports invalidate a shared compiled cache. Automated Lua 5.1 rule, editor-handler, persistence, performance, and packaging checks pass; native ESO UI/persistence acceptance is still pending. See the [subtask log and acceptance checklist](Tasks/DeltaOnlySavedVariables.md).

## Verified Addon Work

- **Tracker visibility and smart positioning:** Keeps the tracker visible during bank, store, fence, and inventory interactions and adjusts its position to avoid UI overlap. Implemented in `Core/Events.lua` and `Tracking/ItemTrackerPanel.lua`.
- **Item and group editor switching:** Provides dual-layer group management and window switching while preserving geometry and the last-active tab. Implemented in `Tracking/EditPanelTabManager.lua`, `Tracking/EditPanelItemsTab.lua`, and `Tracking/EditPanelGroupsTab.lua`.
- **Profile import and copy:** Copies profiles and rule overrides between characters or account-wide settings. Implemented in `Tracking/EditPanelItemsTab.lua`.
- **Context menu integration:** Supports tracked-item addition/removal and partial-stack banking transfers. Implemented in `Core/ContextMenus.lua`.
- **Currency and capacity panel:** Shows configurable ESO currencies and addon-defined capacity resources in a compact panel, with optional standalone progress bars. Implemented in `Tracking/CurrencyPanel.lua` and `Banking/ResourceProgressBars.lua`.
- **Tracker right-click options:** Toggles empty-item visibility and multiline/single-line view from the tracker context menu. Implemented in `Tracking/ItemTrackerPanel.lua`.
- **Group header quality aggregation:** Colors group headers based on stocked items in the relevant storage locations, so excluded bank items do not affect backpack-only groups. Implemented in `Tracking/ItemTrackerPanel.lua`.
- **Rule-slug keying:** Stores rule settings by their underlying slugs while allowing display-name overrides. Implemented in `Tracking/ItemDatabase.lua` and `Tracking/EditPanelGroupsTab.lua`.
- **Expandable group rows:** Adds expandable group summaries with individual item rows. See the retained [implementation specification](Completed/ExpandableGroupRows.md).
