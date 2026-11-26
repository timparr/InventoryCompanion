new ideas - not sorted
info panels - how to guide built into the addon - instead of the manual. - (i) buttons that pop up info about how to use each element and what it does

# InventoryCompanion - Letter-Numbered Master To-Do List

Selecting, specifying, planning, implementing, and accepting an item follows the
[feature development process](../Processes/FeatureDevelopment.md).

Completed AutoCategory and settings/editor work is documented in the
[master feature specification](../DevDocs/FeatureSpecs/AutoCategoryIntegration.md),
with supporting plans and evidence in the
[AutoCategory archive](../DevDocs/Archive/AutoCategory). It is no longer a
pending roadmap item.

Unapproved designs are kept in [Proposals](Proposals), including the
[settings/editor UI mockup](Proposals/SettingsUIUXMockup.md). They are discussion
material, not approved implementation scope.

## Section A: 🛠️ In Progress & Immediate Tasks

- **Final acceptance: schema-15 migration:** Exercise migration using an
  actual older-schema DEV SavedVariables backup, with the required backup,
  logout, restore, verification and recovery safeguards. This was deferred by
  Tim on 2026-11-26; it is not yet a passed test. See the
  [Scanning Refactor implementation record](<../DevDocs/Archive/ScanningRefactor/002 ScanningRefactor - Implementation Plan.md>).

---

## Section B: 🐛 Bug Fixes (Pending)

- **B3. Item Transfer Edge Cases:** Audit and refine bank/chest transfer
  execution plans and stack merging helpers.
- **B4. Account-Wide AutoCategory Initial Setup Choice:** Make the initial
  setup choice/completion account-wide rather than prompting separately for
  character profiles. During 1.6.3 migration UAT, Ja'Vazzir's integration worked
  while his character profile's `autoCategorySetupComplete` remained unset;
  Tyelron Radiantmantle also had initialized rules, items, and context orders
  without that flag. Preserve independent profile arrangements and hydrate
  newly initialized character profiles without reapplying a preset over
  existing choices. Include saved-schema/downgrade protection and migration
  tests if the stored contract changes.
- **B5. Partial Craft Bag and Furniture Vault Transfers:** Add context-menu
  actions to withdraw one item, one 200-item stack, or all but one item from
  Craft Bag and Furniture Vault stacks into the backpack, plus Stow 1, N-1,
  or the full stack from eligible backpack stacks into the Craft Bag. See the
  [combined specification and implementation plan](../DevDocs/Plans/CraftBagAndFurnitureVaultWithdrawalsPlan.md).
---

## Section C: ✨ Quality of Life (QOL) & Tweaks

- **C1. Tracker Panel UI Toolbar Additions:** Add dedicated toolbar buttons
  for **all-bank** mode and quick show/hide-zero filters.
- **C3. Interaction Settings Control:** Add LAM options to individually
  configure whether the tracker snaps, hides, stays, or shifts on overlap for
  each interaction type (bank, store, inventory, fence).

---

## Section D: 🚀 Features Roadmap (Pending)

- **D1. Auto-Restock & Stack Balancer:** Add `targetCount` settings and
  `autoBalance` toggles to tracked items to automatically queue
  deposits/withdrawals upon opening a bank or chest.
- **D2. Tamriel Trade Centre (TTC) Integration:** Integrate TTC pricing data
  and set a "valuable" item threshold for chat notifications.
- **D3. Tracked Item List Sharing & Remaining Untracked Storage Coverage:**
  Discuss list-sharing requirements and whether untracked browsing should cover
  storage beyond backpack, bank, subscriber bank, and the optional craft bag.
  The existing Untracked filter already covers those bags; do not reimplement it.
  "All owned" storage beyond that scope is not established by the current scan.
- **D5. Global Panel Show/Hide Context Menu:** Add a right-click option on any
  panel to show/hide all HUD overlays collectively.
- **D6. Consolidated Gained Messages:** Buffer rapid-fire item pickups (under
  one second) into a single summary chat/HUD message.
- **D7. World Chest Indicators:** Add persistent floating icons over known
  house chests showing nicknames and stack states.
- **D8. Wizard's Wardrobe Integration:** Add gear set checks, quick deposit
  keybinds, and inter-character gear sync.
- **D9. Additional Virtual Groups:** Add virtual groups based on the game's
  item classifications or flags, such as items marked as junk. Other candidates
  include stolen items, self-crafted writ items, and sellable items. Inspect the existing
  Miscellaneous virtual group before implementation and reuse or extend its
  behavior where appropriate. Currency Panel group totals are tracked separately
  under D11.
- **D11. Group Totals on the Currency Panel:** Show item-group counts as
  totals only, without individual item rows. Requested locations: "backpack/bag";
  clarify the intended location split when specifying this feature. Consider
  renaming the Currency Panel to Summary Panel if it includes broader item/group
  summaries.
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
- **E3. Standalone Matching Helper Review:** Production scanning, notifications,
  editor filtering, and AutoCategory already use precompiled runtime rules.
  `ItemMatchesRule` and `ItemMatchesAnyRule` still compile raw patterns for
  standalone calls; assess whether changing those helpers has any demonstrated
  benefit before refactoring. Do not repeat the completed runtime-cache work.
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

- **F1. Configurable Currency Grid Columns:** Promoted to active standalone
  task D10.3 after a fresh discussion; the integrated HUD-editor path remains
  abandoned.
- **F2. Summed Character and Bank Currency Balances:** Offer a combined total
  for currencies held in both locations, distinct from the existing combined
  cell that displays the two balances separately.
- **F3. Dedicated Resource Editor Tab:** Consider configuring currencies and
  capacity resources in a dedicated Resources tab in the custom editor rather
  than only through LibAddonMenu.
- **F4. Currency Panel Overlap and Visibility:** Broader panel repositioning
  and mode-specific visibility remain shelved beyond D10.3's settings-open
  overlay. Any additional behavior needs a fresh discussion. See the
  [D10 archive](../DevDocs/Archive/HUDLayoutAndVisibility/README.md).
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
- **F13. Combat HUD and Notification Controls:** Optional combat suppression,
  configurable independently by panel and notification area/type (for example,
  mute notifications while leaving panels visible). Detect combat entry/exit;
  restore normal visibility and notification behavior on exit without changing
  saved preferences. Discuss which areas are independently configurable and
  whether suppressed notifications are discarded or summarized afterward.
  Separate future idea, not part of D10's current implementation scope.

- **F14. Whole-Addon Gamepad Review:** Test the entire addon in gamepad mode,
  including scene visibility, panel positioning, settings/editors, and banking
  interactions. Identify and discuss fixes as separate follow-up work. D10.3
  preserves existing gamepad behavior; it does not add or repair gamepad support.

- **F15. Currency Summary Panel Master Toggle (Quick Candidate):** Add a quick
  show/hide toggle for the entire panel without changing which currency and
  capacity cells are selected. Keep standalone resource bars and notifications
  independent.

- **F16. Tracker Drift Verification (Idea):** Two linked options arising from the
  unexplained 25 November tracker mismatch (see the Scanning Refactor plan).
  (a) Visible alert: IMPLEMENTED in DEV 25 November for the acceptance pass.
  A chat/HUD error "Tracker mismatch logged - see TODO F16" appears only when
  logging is on and the mismatch was recorded; the item-detail log entry holds
  the evidence. Decide later whether it stays, becomes DEV-only, or is removed
  for release. The addon already detects drift, because every completed
  full scan is compared with the incremental index.
  (b) Post-burst verification scan:
  one full scan shortly after a transfer or crafting burst settles, which gives
  more comparisons and a meaningful clean result. A scan that also replaces the
  index would hide the fault from the display, so decide deliberately whether it
  verifies and logs only or also heals; this needs a root-cause finding first
  and a spec change. Not started.

Source design history: [Currency Preferences](../DevDocs/Archive/CurrencyPanel/CurrencyPreferences.md)
and [Currency Panel Implementation Plan](../DevDocs/Archive/CurrencyPanel/ImplementationPlan.md),
plus [Adaptive Tracker Sizing](../DevDocs/Archive/ItemTracker/AdaptiveSizingImplementation.md).

## Section G: Abandoned / Not Pursuing

- **D10. HUD Layout and Visibility:** D10.1 positioning, D10.2 bar visibility,
  and the integrated HUD-editor-dependent D10.3 approach were abandoned
  2026-11-15. Standalone D10.3 currency columns have since resumed as an active
  draft, separate from that HUD work. Historical documents remain in the
  [D10 archive](../DevDocs/Archive/HUDLayoutAndVisibility/README.md); the active
  standalone plan and spec are linked under D10.3 above.