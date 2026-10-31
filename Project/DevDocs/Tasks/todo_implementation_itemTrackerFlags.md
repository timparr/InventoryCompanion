# Item tracker editor flags and row options: implementation

Status: Planned; current code inspected on 2026-10-30. No runtime changes or
in-game approval recorded. This is the implementation companion for the
extended Show/Notify editor work, not a completed implementation record.

Feature behavior and compatibility requirements are in the
[feature plan](todo_plan_itemTrackerFlags.md). This document follows the
implementation process: saved values and mutation, editor presentation, popup
lifecycle, then verification. Recommend a separate branch before substantive
editor work and obtain approval before switching.

## 1. Preserve saved values and mutation targets

### Current behavior

In [Tracking/EditPanelItemsTab.lua](../../../Tracking/EditPanelItemsTab.lua):

- `CollectTrackedItems()`, `CollectWildcardRules()`, and
  `CollectUntrackedItems()` produce individual, group, and untracked row entries.
- `ToggleState(entry, flagKey, refreshCallback)` changes one entry's flag.
  Group rows call `SetRuleFlag()`; tracked items write their active saved
  `display` table; untracked items become tracked with their link, icon, and
  current four display flags.
- There is no selected-row or bulk mutation in this row-toggle path. A group
  toggle changes the group flag, not its members' individual saved flags.
- Each row action's callback refreshes the item editor and tracker panel.

In [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua):

- `GetActiveTrackedRules()` returns editor view copies. Do not persist edits
  by modifying those copies alone or mutate the cached runtime display table.
- `SetRuleFlag` aliases `UpdateRuleFlag()`, which validates the key/value,
  prunes overrides matching defaults, and invalidates the rule cache.
- `SetUseCharacterItemList()` changes profile selection and increments the
  tracker context revision. `CopyProfile()` replaces active data and increments
  it too. `GetTrackerContext()` returns the saved-rules table and revision.

### Saved-variable changes

- **No schema change:** retain `display.show`, `display.notify`,
  `display.bank`, and `display.group`; do not save popup state.
- **No migration/version bump:** preserve existing defaults and legacy/import
  handling. Group flags continue using sparse deltas; individual items retain
  their existing stored representation.
- Leave rule normalization, reset, profile copy, and bank/count calculation
  unchanged unless a concrete regression requires a directly related fix.

### Mutation changes

Keep a small shared write path in the existing item-editor module for quick
toggles and popup checkboxes. If factoring `ToggleState()`, use an explicit
boolean setter so a checkbox applies its requested state rather than toggling
twice through both label and checkbox handlers.

- Resolve the current entry by stable key, row kind, and captured profile
  context before writing; do not retain a pooled row or stale `entry.data`
  as the authority.
- For groups, read effective values and write through `UpdateRuleFlag()`.
- For tracked items, write through the current `GetActiveTrackedItems()` table.
- For untracked items, retain current promotion semantics and all other flag,
  link, and icon values. Opening Options must not promote an item.
- Preserve the effective Show default (`show ~= false`) when calculating the
  new state, including an absent optional saved flag.
- Apply one logical mutation, then one editor refresh and one tracker refresh.
  Do not add an inventory scan or notification merely for opening the popup.

### Saved-data regression tests

Use the existing rule and persistence suites in
[Core/RuleTests.lua](../../../Core/RuleTests.lua) and
[Project/Tests/RulePersistenceTests.lua](../../Tests/RulePersistenceTests.lua):

- Editing bank/group creates only the necessary sparse group override;
  restoring the default prunes it without losing unrelated settings.
- Individual edits change only the intended key and flag.
- Untracked promotion preserves the other flags, link, and icon.
- Account and character profiles remain isolated; import/reload preserves
  values and never serializes popup target/control state.

## 2. Present quick toggles and the Options panel

### Row layout

Change [Tracking/EditPanelItemsTab.xml](../../../Tracking/EditPanelItemsTab.xml):

- In `InventoryCompanion_TrackedItemRow_Template`, retain the item label,
  Show, Notify, and remove control.
- Replace the Group/Totals row labels with a discoverable Options button.
  Re-anchor right-to-left controls so Show / Notify / Options / Remove fit
  without reducing the existing readable font.
- Add one initially hidden options panel with a target heading and Tracker
  section. Use existing ESO backdrop/button/checkbox patterns; verify a
  suitable native popup pattern before choosing its dismissal mechanism.
- Offer Include banked items for all row kinds and Group items together only
  for groups. Do not add functional destination or AutoCategory placeholders.

Change [Tracking/EditPanelItemsTab.lua](../../../Tracking/EditPanelItemsTab.lua):

- Update `ConfigureRowStateStyles()` and `ConfigureRowClickHandlers()` to
  retain quick Show/Notify and open Options for the current entry.
- Move the group-only visibility responsibility out of
  `ConfigureRowTextAndRemoval()` and into options-panel binding.
- On opening, read current effective settings and display the target name.
  Bind label/checkbox actions to the same explicit-value write path.
- Preserve `ShouldIncludeEntry()` filter/search semantics and row removal.
  Do not change tracker visibility policy as part of an editor relabeling.

Confirm a small layout mockup and wording before substantive UI implementation.
Keep the implementation local; two existing flags do not justify a generic
settings framework or another full editor window.

## 3. Bind popup lifetime to its target and profile

Use one transient target record containing row kind, stable item/rule key, and
both values returned by `GetTrackerContext()`. Read current data when applying
an action. Never identify the target by list index or a pooled control.

In [Tracking/EditPanelItemsTab.lua](../../../Tracking/EditPanelItemsTab.lua):

- Close the panel at the start of `RefreshTrackedItemsEditor()`, before
  `HideAllRows()` and row rebinding. This covers edits, search/filter changes,
  deletion, and normal profile-switch/import refreshes.
- Close on editor `OnEffectivelyHidden` as well as relevant scene hiding;
  the current editor already uses effective-visibility hooks because scene
  callbacks alone have not been reliable.
- Close on scrolling and anchor invalidation. Inspect the actual scroll
  control callbacks before wiring them; do not assume row virtualization
  or an API name based only on the pooled-row design.
- Opening another row closes/retargets the same panel. A successful edit may
  close it through the existing refresh; reopening shows the new value.
- Invalidate old callbacks when closing or retargeting. Expected dismissal
  must never write. If an action reaches the write path with an invalid
  maintained target/context, assert the violated contract rather than silently
  writing to the new profile or returning success.

Review [Tracking/EditPanelTabManager.lua](../../../Tracking/EditPanelTabManager.lua)
for group-tab, settings, and toggle-close transitions. Reuse effective-hide
cleanup where it fully covers these paths; add an explicit close call only
where needed. Do not replace existing handlers or discard layout/camera work.

Verify Escape, click-outside dismissal, focus, edge clamping, and event
propagation in ESO. Do not treat XML validity as proof of native popup behavior.

## 4. Reserve later extensions without implementing them

AutoCategory remains governed by its separate
[plan](todo_plan_autocategoryIntegration.md) and
[implementation investigation](todo_implementation_autocategoryIntegration.md).
It can add a group-only section after this panel is working.

For a later chat/screen destination stage, inspect:

- `HandleTrackedItemInventoryUpdate()` in
  [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua): today it
  checks the individual Notify flag, then visible matching rules if needed,
  and emits one `Utils.UserWarning(chat, hud)` for a positive gain.
- Notification helpers and duplicate suppression in
  [Core/Utils.lua](../../../Core/Utils.lua): destination routing must not
  accidentally change currency/capacity messages or diagnostic/error delivery.

Before implementation, settle master-toggle meaning, destination
defaults/inheritance, global-setting interaction, overlap resolution, and
saved-data compatibility. Then extend matching, delivery, loading/import,
editor filters, and tests together. Do not infer an approved destination model
from the two proposed checkbox labels.

## 5. Documentation and completion checks

### Automated regression checks

Extend the isolated Lua 5.1 harness in
[Project/Tests/Run-RuleTests.py](../../Tests/Run-RuleTests.py) with item-editor
control mocks and focused tests when implementing this feature. It currently
loads the group editor, not the item editor; existing passing suites alone
cannot verify this popup.

Test exact writes and refresh counts alongside values:

1. Quick Show/Notify preserve defaults, filters, and one-click behavior.
2. Bank/group checkbox and label clicks perform exactly one requested change.
3. Group-only controls are absent on tracked and untracked item rows.
4. Opening, retargeting, and closing the panel perform zero saved writes.
5. Rebuild, scroll, delete, import, profile switch, tab switch, and hide
   invalidate old actions before any write; recycled rows cannot redirect them.
6. An edit refreshes editor/tracker once each and reopening shows current values.
7. Include/exclude matching, independent item overrides, and Miscellaneous
   display remain unchanged.

Run the smallest existing test command covering the changes. Extend mocks only
for required control interactions; keep fixtures isolated from live inventory
and saved variables. Run whitespace/XML checks for changed files and relevant
in-game diagnostic tests; escalate broader suites only if focused results
require it.

### In-game acceptance

- Both item and group rows clearly show Show / Notify / Options at the existing
  supported window size; labels are readable and do not overlap Remove.
- Items offer bank inclusion; groups offer bank inclusion and grouping.
  Counts and grouping behavior match the previous controls.
- Popup name/values match the active row/profile. Scrolling, filtering,
  importing, deleting, switching tabs/profiles, and closing cannot cause a
  stale action, orphan popup, or write to another target.
- Escape, outside clicks, edge anchoring, and label/checkbox interaction work
  without duplicate toggles or accidental row actions.
- Reload preserves flags but not popup state. No later-extension control
  appears functional before its implementation exists.

Update [UserManual.bbcode](../../../UserManual.bbcode) for the visible renamed
controls and Options interaction, plus the authoritative working changelog
from actual implemented changes. Follow the
[release checklist](../../Publishing/ReleaseChecklist.md) for version
recommendation and release steps. Mark both documents completed and move them
to Completed only after automated checks and final in-game approval.

## Dependencies

Stage 1 establishes the shared mutation contract required by stages 2 and 3.
Presentation and lifecycle must ship together: do not expose a popup without
stale-target protection. Stage 5 follows implementation and verification.
Stage 4 records follow-on scope, not a dependency or permission to add it now.
