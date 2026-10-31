new ideas - not sorted
info panels - how to guide built into the addon - instead of the manual. - (i) buttons that pop up info about how to use each element and what it does

# InventoryCompanion - Letter-Numbered Master To-Do List

## Section A: 🛠️ In Progress & Immediate Tasks

---

## Section B: 🐛 Bug Fixes (Pending)

- **B3. Item Transfer Edge Cases:** Audit and refine bank/chest transfer
  execution plans and stack merging helpers.

---

## Section C: ✨ Quality of Life (QOL) & Tweaks

- **C1. Tracker Panel UI Toolbar Additions:** Add dedicated toolbar buttons
  for **all-bank** mode and quick show/hide-zero filters.
- **C3. Interaction Settings Control:** Add LAM options to individually
  configure whether the tracker snaps, hides, stays, or shifts on overlap for
  each interaction type (bank, store, inventory, fence).

---

## Section D: 🚀 Features Roadmap (Pending)

- **D11. AutoCategory Integration:** Optional inventory partitions driven by
  Inventory Companion groups. See the [plan](Tasks/todo_plan_autocategoryIntegration.md)
  and [implementation investigation](Tasks/todo_implementation_autocategoryIntegration.md).
- **D1. Auto-Restock & Stack Balancer:** Add `targetCount` settings and
  `autoBalance` toggles to tracked items to automatically queue
  deposits/withdrawals upon opening a bank or chest.
- **D2. Tamriel Trade Centre (TTC) Integration:** Integrate TTC pricing data
  and set a "valuable" item threshold for chat notifications.
- **D3. Tracked Item List Sharing & Untracked Filter:** Expand the editor
  filter view to inspect all owned untracked items.
- **D5. Global Panel Show/Hide Context Menu:** Add a right-click option on any
  panel to show/hide all HUD overlays collectively.
- **D6. Consolidated Gained Messages:** Buffer rapid-fire item pickups (under
  one second) into a single summary chat/HUD message.
- **D7. World Chest Indicators:** Add persistent floating icons over known
  house chests showing nicknames and stack states.
- **D8. Wizard's Wardrobe Integration:** Add gear set checks, quick deposit
  keybinds, and inter-character gear sync.
- **D9. Additional Virtual Groups & Summary Panel:** Explore virtual groups
  for self-crafted writ items, stolen items, and junk/sellable items, and allow
  groups to be summarized in the Currency Panel. Inspect the existing
  Miscellaneous virtual group before implementation and reuse or extend its
  behavior where appropriate. Consider renaming the Currency Panel to Summary
  Panel if it includes broader item/group summaries.
- **D10. Progress Bar Visibility:** Allow progress bars to be hidden below a
  configurable percentage.

---

## Section E: 🏗️ Post-V1 Refactoring Tickets

- **E1. Phase 1: Shared Utility Migration (`Core/Utils.lua`):** Extract string
  sanitization (`SanitizeText`), debounced action queues (`Debounce`), and
  wildcard pattern compilation (`CompileWildcards`) into centralized utility
  methods.
- **E2. Phase 2: Naming Convention Standardization:** Standardize file names
  (e.g., renaming `EditPanelItemsTab.lua` to `ItemEditorWindow.lua`), XML root
  control tags, and refresh methods (`RefreshItemEditor()` /
  `RefreshGroupEditor()`) while clearly separating data rules from UI groups.
- **E3. Rule-Matching Optimization:** Refactor `ItemMatchesRule` and
  `ItemMatchesAnyRule` to use pre-compiled pattern compilers rather than
  compiling on the fly during real-time inventory updates.
- **E4. Modular Settings Panel:** Review the currency panel settings UI,
  which is already partially owned by `Tracking/CurrencyPanel.lua`, as a
  template. Discuss whether and how to modularize the remaining settings
  sections so the panel can be assembled from modules.

---

## Section F: Tweaks and Improvement Ideas

Ideas considered during earlier planning but not included in the final release,
plus low-priority observations worth revisiting.
These are optional candidates for discussion, not committed implementation
tasks. Superseded approaches and closed proposals are not carried forward.
Entries are self-contained so useful ideas survive removal of the old plans.
They may be refined or discarded during future triage.

- **F1. Configurable Currency Grid Columns:** Allow users to choose the number
  of columns instead of the released three-column layout.
- **F2. Summed Character and Bank Currency Balances:** Offer a combined total
  for currencies held in both locations, distinct from the existing combined
  cell that displays the two balances separately.
- **F3. Dedicated Resource Editor Tab:** Consider configuring currencies and
  capacity resources in a dedicated Resources tab in the custom editor rather
  than only through LibAddonMenu.
- **F4. Currency Panel Overlap and Visibility:** Consider temporarily moving
  the currency panel to avoid covering settings or editors, and configurable
  visibility during inventory, bank, and cutscene interactions. Preserve its
  saved position when a temporary adjustment ends.
- **F5. Currency Storage-Location Badges:** Explore small character/bank badges
  over currency icons, provided they remain readable at the compact grid size.
- **F6. Tracker Pickup Highlighting:** Briefly highlight the tracked item or
  category receiving new inventory without changing category expansion.
- **F7. Optional Open-on-Pickup Behavior:** Consider an opt-in setting to open
  the category receiving an item. Respect filters and manual choices, and
  handle multi-category pickup bursts without disruptive switching.
- **F8. Collapse Categories on Login:** Consider an optional startup preference
  to begin with categories collapsed instead of restoring their saved expansion.
- **F9. Editor Font-Size Adjustment:** Consider adjustable text size for item
  and group editor inputs if the corrected standard fonts are insufficient.
  The existing tracker title-size setting is already implemented and is not
  part of this idea.
- **F10. Craft-Bag Stow Tracker Refresh:** Consider investigating the observation
  that backpack-to-craft-bag stowing produced no logged slot event or immediate
  tracker refresh. Harvesting directly into the craft bag and withdrawing to
  the backpack worked. Stowing was not tested against the older code, so this
  is not an established event-filter regression. Impact is minor, and another
  event may refresh the tracker shortly afterward.
- **F11. Search Input Debounce:** Consider a short debounce (150-200ms) for the
  item editor's `FindBox` `OnTextChanged` handler only if a responsiveness issue
  is observed. No search performance problem has been reported.
- **F12. Per-Character Tracker Placement:** Consider saving the item tracker
  window position separately for each character while keeping other settings
  account-wide.

Source design history: [Currency Preferences](Completed/CurrencyPreferences.md)
and [Currency Panel Implementation Plan](Completed/CurrencyPanelImplementationPlan.md),
plus [Adaptive Tracker Sizing](Completed/ImplementationPlan_TrackerPanelHeightConstraints.md).