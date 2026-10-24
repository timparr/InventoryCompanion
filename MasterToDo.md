# InventoryCompanion - Letter-Numbered Master To-Do List

## Section A: 🛠️ In Progress & Immediate Tasks

* **A1.** **Group Editor Height Constraints:**
* Implement a safeguard so that if expanding a group makes the editor window too tall, it automatically collapses other expanded groups to show only the active one.


* **A2.** **Refactor Rule Edits for Delta-Only Saved Variables (Explicit Surgical Setters):**
* Implement explicit, single-responsibility helpers (`SetRuleProperty` for root-level properties like `displayName` and `patterns`, alongside existing flag setters) so that group renames, pattern edits, and display toggles write *only* the modified data as clean delta overrides in saved variables without redundant duplication.


---

## Section B: 🐛 Bug Fixes (Pending)

* **B1.** **Group Color Determination:**
* Fix item quality color aggregation (currently picks the highest quality *anywhere*, e.g., gold in bank or purple in backpack, causing inaccurate group header text colors).


* **B2.** **Tracker Window Placement Persistence:**
* Save item tracker window placement on a per-character basis while keeping other settings account-wide.


* **B3.** **Item Transfer Edge Cases:**
* Audit and refine bank/chest transfer execution plans and stack merging helpers.



---

## Section C: ✨ Quality of Life (QOL) & Tweaks

* **C1.** **Tracker Panel UI Toolbar Additions:**
* Add dedicated toolbar buttons for **'all-bank' mode** and quick show/hide filters.


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
* Add support for AP, Tel Var, Writ Vouchers, Archival Fortunes, Undaunted Keys, and Transmute Crystals in a configurable grid.


* **D5.** **Global Panel Show/Hide Context Menu:**
* Right-click option on any panel to show/hide all HUD overlays collectively.


* **D6.** **Consolidated Gained Messages:**
* Buffer rapid-fire item pickups (<1s window) into a single summary chat/HUD message.


* **D7.** **World Chest Indicators:**
* Persistent floating icons over known house chests showing nicknames and stack states.


* **D8.** **Wizard's Wardrobe Integration:**
* Gear set checks, quick deposit keybinds, and inter-character gear sync.



---

## Section E: 🏗️ Post-V1 Refactoring Tickets

* **E1.** **Phase 1: Shared Utility Migration (`Core/Utils.lua`):**
* Extract string sanitization (`SanitizeText`), debounced action queues (`Debounce`), and wildcard pattern compilation (`CompileWildcards`) into centralized utility methods.


* **E2.** **Phase 2: Naming Convention Standardization:**
* Standardize file names (e.g., renaming `EditPanelItemsTab.lua` to `ItemEditorWindow.lua`), XML root control tags, and refresh methods (`RefreshItemEditor()` / `RefreshGroupEditor()`) while clearly separating data rules from UI groups.


* **E3.** **Rule-Matching Optimization:**
* Refactor `ItemMatchesRule` and `ItemMatchesAnyRule` to utilize pre-compiled pattern compilers rather than compiling on-the-fly during real-time inventory updates.



---

## Section F: ✅ Completed (Verified in Codebase)

* **F1.** **Tracker Visibility & Smart Positioning for Bank/Inventory:**
* Implemented in `Core/Events.lua` (`InitCutsceneTicker`) and `Tracking/ItemTrackerPanel.lua` (`AdjustTrackerPositionForInteraction`, `RestoreTrackerPosition`). The Item Tracker automatically remains visible during Bank, Store, Fence, and Inventory interactions and dynamically repositions to avoid UI overlap.


* **F2.** **Dual-Layer Group Management & Window Switching:**
* Fully operational in `Tracking/EditPanelTabManager.lua`, `EditPanelItemsTab.lua`, and `EditPanelGroupsTab.lua`. Seamlessly toggles between the item editor and group editor while matching window geometry and remembering last-active tabs.


* **F3.** **Profile Import / Copy System:**
* Fully implemented in `Tracking/EditPanelItemsTab.lua` (`InitCopyDropdown`, `ExecuteCopy`, and confirmation dialogs) allowing profile and rule overrides to be imported across characters or account-wide settings.


* **F4.** **Context Menu Integration:**
* Implemented in `Core/ContextMenus.lua` for quick addition/removal of tracked items and partial stack banking transfers.


* **F5.** **Currency & Standalone Progress Panels:**
* Gold, bag, and bank spaces, along with standalone backpack and bank progress bars with dynamic color gradients and warning thresholds, are fully coded and functional (`CurrencyPanel.lua`, `ProgressPanels.lua`).


* **F6.** **Tracker Right-Click Toggles:**
* Right-clicking the tracker header or container opens a context menu to toggle **Show/Hide Empty Items** and **Multiline / Single Line View** (`ItemTrackerPanel.lua`).


* **F7.** **Rule-Slug Keying Implementation:**
* Verified in `ItemDatabase.lua` and `EditPanelGroupsTab.lua`. Rules properly key off their underlying slugs (`ruleSlug`/`ruleName`) in saved variables while cleanly evaluating and displaying `displayName` overrides.