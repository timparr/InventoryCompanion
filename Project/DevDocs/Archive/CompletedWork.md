# Completed Work

Completed work is recorded here for project history and future release-note drafting. This is an internal record; summarize user-facing changes in a release changelog when publishing.

Supporting documents are grouped by feature in this archive. They preserve
design decisions, implementation details, failed approaches, and dated evidence,
not independent current requirements or outstanding tasks. Current authoritative
specifications live in [FeatureSpecs](../FeatureSpecs); active work lives in the
[master TODO](../../Tasks/TODO.md).

## Verified Addon Work

- **AutoCategory integration and settings/editor polish (D11):** Closed by the
  author on 2026-11-04. Includes per-area Display/Priority orders and Hide/Show,
  movable Display-only Other, full profiles, centralized settings/profile tools,
  aligned editor navigation, Manage Tracking Show/Notify columns and visit-scoped
  Undo changes. The [master feature specification](../FeatureSpecs/AutoCategoryIntegration.md)
  owns final behavior and documentation handoff; supporting plans, snag lists,
  screenshots and dated evidence are in the
  [AutoCategory archive](<AutoCategory>).
  Release approval and candidate evidence follow the publishing checklist
  separately; historical pending checks do not reopen this implementation.

- **Item tracker flags / row options (C4):** Implemented and archived at the
  user's request on 2026-10-31. Aligned two-line Show/Notify controls open compact
  boxes for independent backpack/bank display, grouping, and Chat/HUD delivery.
  AutoCategory space collapses while integration is off. Schema 3 migrates
  existing profiles non-destructively and blocks incompatible older builds.
  All 99 isolated Lua 5.1 tests pass; the user confirmed downgrade rejection
  and the in-game acceptance tests passed on 2026-10-31.
  See the [feature plan](ItemTracker/RowOptionsSpecification.md) and
  [implementation and verification record](ItemTracker/RowOptionsImplementation.md).

- **Group pattern exclusions (C5):** Groups match at least one Include pattern
  and no Exclude patterns, without vetoing other groups or individual tracking.
  Includes appear before an Exclusions section, with native IN/OUT indicators,
  a separate swap button, and explanatory tooltips. Automated checks passed
  79/79 isolated Lua 5.1 tests, and the final editor visuals were approved in
  game on 2026-10-30. See the [feature plan](GroupMatching/PatternExclusionsSpecification.md) and
  [implementation and refinement record](GroupMatching/PatternExclusionsImplementation.md).
- **Inventory slot event filtering:** Filtered backpack, craft-bag, bank, and
  subscriber-bank listeners have automated coverage for lifecycle transitions,
  bag filters, duplicate prevention, and refresh debounce. See the retained
  [manual QA and diagnostic history](InventoryEvents/SlotEventFilterQA.md). The
  separate craft-bag stow observation is retained as optional idea F10 in the
  [master TODO tweaks section](../../Tasks/TODO.md#section-f-tweaks-and-improvement-ideas).
- **Adaptive tracker sizing:** The item area uses a configurable visible-row
  budget, switches to single-line names before collapsing categories, and
  scrolls any remaining overflow while keeping the title fixed. This feature
  shipped in reviewed code and is considered verified. The isolated Lua 5.1
  runner passed 71/71 tests. See the
  [requirements](ItemTracker/HeightConstraintsOriginalProposal.md) and
  [implementation and verification record](ItemTracker/AdaptiveSizingImplementation.md).
- **Delta-only saved rules and lazy matching cache:** Built-in rules persist
  only edited names/flags and sorted pattern additions/removals. Group
  mutations and imports invalidate a shared compiled cache. Implementation,
  automated regression checks, and in-game acceptance are complete. See the
  [subtask log and implementation record](SavedVariables/DeltaOnlySavedVariables.md).
- **Adaptive tracker layout regression coverage:** The isolated Lua 5.1 suite
  exercises row-budget layout, wrapping fallback, category collapse, scrolling,
  profile/context changes, and bounded synthetic workloads. The full runner
  passed 71/71 tests on 2026-10-30.
- **Tracker visibility and smart positioning:** Keeps the tracker visible during bank, store, fence, and inventory interactions and adjusts its position to avoid UI overlap. Implemented in `Core/Events.lua` and `Tracking/ItemTrackerPanel.lua`.
- **Item and group editor switching:** Provides dual-layer group management and window switching while preserving geometry and the last-active tab. Implemented in `Tracking/EditPanelTabManager.lua`, `Tracking/EditPanelItemsTab.lua`, and `Tracking/EditPanelGroupsTab.lua`.
- **Profile selection and full copy:** Main Settings selects retained account/character profiles and replaces complete profile content after confirmation. See the [current profile contract](../FeatureSpecs/AutoCategoryIntegration.md#main-settings-and-full-profiles); this supersedes the earlier item-editor list-copy workflow.
- **Context menu integration:** Supports tracked-item addition/removal and partial-stack banking transfers. Implemented in `Core/ContextMenus.lua`.
- **Currency and capacity panel:** Shows configurable ESO currencies and addon-defined capacity resources in a compact panel, with optional standalone progress bars. Implemented in `Tracking/CurrencyPanel.lua` and `Banking/ResourceProgressBars.lua`. See the completed [currency preferences specification](CurrencyPanel/CurrencyPreferences.md) and [implementation plan](CurrencyPanel/ImplementationPlan.md); optional improvements are retained in the [master TODO, Section F](../../Tasks/TODO.md#section-f-tweaks-and-improvement-ideas).
- **Tracker right-click options:** Toggles empty-item visibility and multiline/single-line view from the tracker context menu. Implemented in `Tracking/ItemTrackerPanel.lua`.
- **Group header quality aggregation:** Colors group headers based on stocked items in the relevant storage locations, so excluded bank items do not affect backpack-only groups. Implemented in `Tracking/ItemTrackerPanel.lua`.
- **Rule-slug keying:** Stores rule settings by their underlying slugs while allowing display-name overrides. Implemented in `Tracking/ItemDatabase.lua` and `Tracking/EditPanelGroupsTab.lua`.
- **Expandable group rows:** Adds expandable group summaries with individual item rows. See the retained [implementation specification](ItemTracker/ExpandableGroupRows.md).
