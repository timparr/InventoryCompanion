# InventoryCompanion - Letter-Numbered Master To-Do List

## Section A: 🛠️ In Progress & Immediate Tasks

* **A1.** **Group Editor Height Constraints:**
* Implement a safeguard so that if expanding a group makes the editor window too tall, it automatically collapses other expanded groups to show only the active one.


* **A2.** **Refactor Rule Edits for Delta-Only Saved Variables (Explicit Surgical Setters):**
* Implement explicit, single-responsibility helpers (`SetRuleProperty` for root-level properties like `displayName` and `patterns`, alongside existing flag setters) so that group renames, pattern edits, and display toggles write *only* the modified data as clean delta overrides in saved variables without redundant duplication.
* Detailed design and verification notes: [Delta-Only Saved Variables](Tasks/DeltaOnlySavedVariables.md).


---

## Section B: 🐛 Bug Fixes (Pending)

* **B1.** **Group Color Determination:**
* Fix item quality color aggregation so the group header reflects the scanned items, not the best quality anywhere in the account (for example, gold in the bank can incorrectly color a group when only purple items are in the backpack).


* **B2.** **Tracker Window Placement Persistence:**
* Save item tracker window placement on a per-character basis while keeping other settings account-wide.


* **B3.** **Item Transfer Edge Cases:**
* Audit and refine bank/chest transfer execution plans and stack merging helpers.


* **B4.** **Low Priority — Craft-Bag Stow Tracker Refresh:**
* Investigate why stowing an item from the backpack into the craft bag did not produce a logged slot event or immediately refresh the tracker in the current code. Harvesting directly into the craft bag works both before and after the event-filter change. Stowing/retrieving was not tested against the old code, so do not assume the filter change caused this behavior. Minor impact: users rarely take tracked items out of the craft bag, and the tracker may refresh shortly afterward through another event.


---

## Section C: ✨ Quality of Life (QOL) & Tweaks

* **C1.** **Tracker Panel UI Toolbar Additions:**
* Add dedicated toolbar buttons for **'all-bank' mode** and quick show/hide-zero filters.


* **C2.** **Search Input Debounce:**
* Route the `FindBox` `OnTextChanged` handler in the item editor through a short debounce queue (150–200ms).


* **C3.** **Interaction Settings Control:**
* Add LAM options to let users individually configure whether the tracker snaps, hides, stays, or shifts on overlap for each interaction type (bank, store, inventory, fence).



---

## Section D: 🚀 Features Roadmap (Pending)

* **D1.** **Auto-Restock & Stack Balancer:**
* Add `targetCount` settings and `autoBalance` toggles to tracked items to automatically queue deposits/withdrawals upon opening a bank or chest.


* **D2.** **Tamriel Trade Centre (TTC) Integration:**
* Integrate TTC pricing data and set a 'valuable' item threshold for chat notifications.


* **D3.** **Tracked Item List Sharing & Untracked Filter:**
* Expand the editor filter view to inspect all owned untracked items.


* **D4.** **Expanded Currency Panel:**
* Unify configurable ESO currencies and addon-defined capacity resources, with compact and optional progress-bar presentations. See [Currency Panel Implementation Plan](Tasks/CurrencyPanelImplementationPlan.md) for the proposed UX, resource identities, migration, and phases, and [Currency Preferences](Tasks/CurrencyPreferences.md) for currency-specific saved-variable, pruning, and compatibility requirements.


* **D5.** **Global Panel Show/Hide Context Menu:**
* Right-click option on any panel to show/hide all HUD overlays collectively.


* **D6.** **Consolidated Gained Messages:**
* Buffer rapid-fire item pickups (<1s window) into a single summary chat/HUD message.


* **D7.** **World Chest Indicators:**
* Persistent floating icons over known house chests showing nicknames and stack states.


* **D8.** **Wizard's Wardrobe Integration:**
* Gear set checks, quick deposit keybinds, and inter-character gear sync.


* **D9.** **Additional Virtual Groups & Summary Panel:**
* Explore virtual groups for self-crafted writ items and sellable items (junk), and allow groups to be summarized in the Currency Panel. Inspect the existing Miscellaneous virtual group before implementation and reuse or extend its behavior where appropriate. Consider renaming the Currency Panel to Summary Panel if it includes broader item/group summaries.



---

## Section E: 🏗️ Post-V1 Refactoring Tickets

* **E1.** **Phase 1: Shared Utility Migration (`Core/Utils.lua`):**
* Extract string sanitization (`SanitizeText`), debounced action queues (`Debounce`), and wildcard pattern compilation (`CompileWildcards`) into centralized utility methods.


* **E2.** **Phase 2: Naming Convention Standardization:**
* Standardize file names (e.g., renaming `EditPanelItemsTab.lua` to `ItemEditorWindow.lua`), XML root control tags, and refresh methods (`RefreshItemEditor()` / `RefreshGroupEditor()`) while clearly separating data rules from UI groups.


* **E3.** **Rule-Matching Optimization:**
* Refactor `ItemMatchesRule` and `ItemMatchesAnyRule` to utilize pre-compiled pattern compilers rather than compiling on-the-fly during real-time inventory updates.


* **E4.** **Modular Settings Panel:**
* Review the currency panel settings UI, which is already partially owned by `Tracking/CurrencyPanel.lua`, as a template. Discuss whether and how to modularize the remaining settings sections so the panel can be assembled from modules.