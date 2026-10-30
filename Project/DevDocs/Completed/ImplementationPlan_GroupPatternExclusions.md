# Group pattern exclusions: implementation

Status: Completed on 2026-10-30. Core matching and persistence, editor
refinements, tests, and documentation are implemented. Includes appear first,
followed by an Exclusions divider when both kinds are present; toggling moves
the row immediately. The final editor uses 25-by-25 green deposit/IN and red
withdraw/OUT indicators before the pattern, with an 8-pixel textbox gap, and a
separate native textured swap button after it. Status, swap, and delete
tooltips explain each control. The final textures and spacing were approved
in game. The isolated Lua 5.1 suite passed 79/79 tests; XML, texture-path,
dimension, and whitespace checks passed. Feature changes are committed and
pushed on `feature/group-pattern-exclusions`, most recently as `6130ad0`;
merging and publishing are separate release steps.

Feature behavior and compatibility requirements are in the
[feature plan](GroupPatternExclusions.md). This document follows the
implementation process: saved representation, runtime interpretation and
matching, editor, then verification. Method-level changes are listed within
the process stage where they belong.

## 1. Save the row kind in the existing pattern strings

### Current behavior

Built-in group defaults are string arrays in
[Core/Constants.lua](../../../Core/Constants.lua). Saved user changes use the
existing `patterns`, `addedPatterns`, and `removedPatterns` fields. The
`UpdateRulePatterns()` path reconciles whole strings against the built-in
defaults; saved-rule validation, reset, and profile-copy logic also expect
string arrays.

### Representation

Keep the same fields, arrays, and string values. Use the exact case-sensitive
suffix ` {InventoryCompanion:exclude}` at the end of a stored string to mark
an exclusion:

```lua
patterns = {
    "*treasure map*",         -- include; current/default meaning
    "*cyrodiil* {InventoryCompanion:exclude}", -- marker is not matched
}
```

The visible editor control adds/removes the suffix. Users see and edit only the
pattern text. The long reserved marker is chosen to avoid collisions with
existing item names or practical user patterns. An old string ending in this
exact marker is interpreted as excluded; item names cannot contain the marker,
so such a pattern would have matched zero items before this feature. The editor
reserves the marker and does not allow it to be entered as literal pattern text.

### Saved-variable changes

- **No schema change:** no new saved fields or per-pattern tables. Keep strings
  in `patterns`, `addedPatterns`, and `removedPatterns`.
- **No migration/version bump:** existing strings without the suffix remain
  includes; `SettingsVersion` stays 2.
- **Built-in override example:** toggling a built-in include to Exclude removes
  its plain string from the effective list and adds the suffixed string.
  Existing sparse-delta reconciliation records this automatically.
- **Custom-group example:** the suffixed string is an ordinary entry in
  `addedPatterns`. Removing it uses the existing list update path.
- **Existing methods that remain unchanged:** in
  [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua),
  `ValidateSavedRules()`, `PrepareSavedVariables()`, `GetPatternList()`,
  `ReconcilePatterns()`, `NormalizeRule()`, `PruneRule()`,
  `UpdateRulePatterns()`, `HasResettableRuleOverrides()`, `ResetRule()`, and
  `CopyProfile()` continue operating on strings and need no exclusion-specific
  branch.

### Saved-data regression tests

- In `Core/RuleTests.lua`, add cases through `this.GetRuleTests()` to verify
  the existing sparse delta behavior when a string changes from plain to
  suffixed and back.
- In `Project/Tests/RulePersistenceTests.lua`, add a case through
  `this.GetRulePersistenceTests()` proving encoded strings survive serialize /
  reload and runtime compiled values are not saved. Update local
  `Serialize(value)` to reject `compiledExcludedPatterns` as well as
  `compiledPatterns`.
- In `Project/Tests/SavedVariablesTests.lua`, verify legacy plain strings stay
  includes and the existing schema version remains unchanged. No migration
  implementation is planned.

## 2. Interpret strings and match items

### Parse and compile

Change [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua):

- Add `RULE_PATTERN_EXCLUSION_SUFFIX` to
  [Core/Constants.lua](../../../Core/Constants.lua) and use that one shared
  value in the runtime parser and group editor.
- Add local `SplitStoredPatterns(patterns)`. It returns include and exclude
  text arrays, removing exactly the trailing
  ` {InventoryCompanion:exclude}` marker from excluded values. Plain strings
  go into includes.
- Modify `GetRuntimeRules()` to retain the encoded list as `rule.patterns`,
  call `SplitStoredPatterns()`, then use the existing `CompilePatterns()` on
  each resulting list. Runtime rules expose both `compiledPatterns` and
  `compiledExcludedPatterns`.
- Modify `GetActiveTrackedRules(includeHidden)` to expose both compiled lists
  to its callers.
- Do not modify `CompilePatterns(patterns)`; it remains the common compiler
  and receives marker-free pattern text.
- Preserve existing empty-pattern behavior: the compiler omits empty pattern
  strings, so an empty include or tagged empty exclusion matches nothing. Keep
  empty rows allowed in both kinds and test this explicitly.

### Match consistently

In [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua):

- Modify `ItemMatchesRuntimeRule(itemLink, rule)`: return true only if at least
  one compiled include matches and no compiled exclusion matches, by calling
  the shared compiled-name matcher below.
- Modify `GetMasterItemList(trackedItems, activeRules, bagIdList)` to pass both
  compiled lists per rule into the scan matcher.
- Add local `ItemNameMatchesCompiledRule(lowerName, compiledIncludes,
  compiledExcludes)` as the single source of truth for compiled matching. It
  returns true only for any include match and no exclusion match.
- Define the local matcher before `ItemMatchesRuntimeRule()` so both that
  method and the later `findMatchingRulesCompiled()` close over the same local
  function; do not accidentally resolve it as a global due to Lua declaration
  order.
- Modify local `findMatchingRulesCompiled(lowerName, compiledRules)` to call
  `ItemNameMatchesCompiledRule()` for every rule before adding it to the match
  set and index. Do not retain a second independent matching loop.
- Update fixtures that construct runtime rules directly to provide an empty
  `compiledExcludedPatterns` list where needed.
- Leave notification and untracked-item call sites unchanged: they already use
  `ItemMatchesRuntimeRule()`, so they inherit its exclusion behavior.
- The scope remains group-local: a false rule match removes only that group's
  membership. Do not remove the item from the scan snapshot, suppress other
  matching groups, or change individual tracking.

In [Tracking/ItemTrackerPanel.lua](../../../Tracking/ItemTrackerPanel.lua), do
not modify `RuleSignature(rule)`: it already includes the full stored strings,
so changing the suffix changes the signature.

### Runtime regression tests

- In `Core/RuleTests.lua`, add cases through `this.GetRuleTests()` for
  include-only compatibility, include-plus-exclude, no includes, empty
  include/exclude rows, exclusions matching only their own group, and scan
  `ruleIndex` results.
- Verify that an individually tracked item remains individually tracked when
  an exclusion prevents membership in one rule; the existing rescue/display
  behavior must not be changed by this feature.
- Verify direct notification and untracked-item filtering use the same
  exclusion veto. Add coverage through the existing diagnostic/test path in
  `Core/Tests.lua` only if its current fixtures do not already exercise these
  call sites.
- `RuleSignature(rule)` in `Tracking/ItemTrackerPanel.lua` remains unchanged;
  it already includes the full stored pattern strings, including the suffix.
  The rule-matching and editor tests verify the encoded kind changes behavior
  and persists without changing the displayed text.

## 3. Present and edit the kind in the group editor

Change [Tracking/EditPanelGroupsTab.lua](../../../Tracking/EditPanelGroupsTab.lua):

- Add local `DecodePatternRows(patterns)` to convert encoded strings into
  editor-only `{ pattern, isExclusion }` row records. Preserve each kind's
  existing sorted order, but return all Include rows before all Exclude rows.
- Add local `GetOrCreatePatternExclusionDivider(scrollChild)` and a virtual
  divider template in `Tracking/EditPanelGroupsTab.xml`. Render the divider
  only when the group has at least one Include and one Exclude; position
  Exclude rows below it. Include-only and exclusion-only lists have no
  inter-section divider.
- Add local `EncodePatternRows(rows)` to serialize those records back into
  plain or suffixed strings for the existing `UpdateRulePatterns()` API.
- Modify `PopulateSingleGroupPane(activeRules)` to build the row records,
  display marker-free text, bind the kind control, and keep the special
  `miscellaneous` group without pattern rows.
- Add local `SetPatternKindLabel(label, isExclusion)` to color a green/red
  status dot with the existing UI label control.
- Add local `ShowPatternKindTooltip(control, row)` to identify the current
  kind, state the inverse action, and explain the resulting move between
  sections.
- Modify `HandlePatternKindToggle(label, row, rows, targetGroup)` to flip the
  row kind, save via `SaveRulePatterns()`, and refresh the editor so the row
  immediately moves into the newly selected section. Also refresh the HUD.
- Modify `SaveRulePatterns(groupName, rows)` to encode rows and call the
  existing `this.UpdateRulePatterns()`.
- Modify `HandlePatternTextChanged(self, row)` and
  `HandlePatternFocusLost(self, row, rows, targetGroup)` to update/commit the
  row's visible text without changing its kind.
- Modify `HandlePatternDelete(rows, rowIndex, targetGroup)` and
  `HandleAddRule(rows, targetGroup)` to preserve row kinds; new rows default
  to Include.
- Preserve current HUD refresh, group-editor refresh, and Reset-button
  behavior for edit, add, delete, and toggle.

Change [Tracking/EditPanelGroupsTab.xml](../../../Tracking/EditPanelGroupsTab.xml):

- Modify `InventoryCompanion_PatternEditRow_Template` to show a green/red
  IN/OUT status icon before the pattern field, a compact swap-icon button
  after the pattern with no default square button chrome, and the delete
  control at the end. Use ESO's native CharacterWindow `swap_button` textures
  for the normal, hover, pressed, and disabled states instead of the interim
  ASCII `<>` font label, so the control uses native textured-button styling
  like the delete X. After the interim radio-button indicator, use ESO's Bank
  `bank_tabicon_deposit_up.dds` for Include (IN) and
  `bank_tabicon_withdraw_up.dds` for Exclude (OUT), still tinted green/red.
  Update the texture whenever a row is rebound or toggled; retain the separate
  swap button rather than making the status icon the action.
  In-game refinement: reduce the indicator from 22 to 20 pixels and increase
  the gap before the edit field from 4 to 8 pixels. The swap button remained
  invisible with the attempted XML texture block; remove that block and assign
  all four states through the native button texture setters during row binding.
  Test those assignments directly rather than treating well-formed XML as proof
  that ESO recognizes the button-state markup.
  After in-game approval of the textures and spacing, increase the IN/OUT
  indicators by 25% from 20 to 25 pixels, retaining the 8-pixel textbox gap.
  The earlier `radioButton_checked.dds` path was invalid and caused the indicator
  to disappear. Use the repository's
  [ESO-Game-Textures.md](../../Resources/ESO-Game-Textures.md) as the first
  reference for known-good texture paths. Both Bank indicator textures and all
  four CharacterWindow swap states are listed there. XML parsing alone does not
  establish asset existence or correct ESO button-state markup.
  Add a tooltip to the delete X identifying
  that it removes this Include or Exclude rule. The status-icon tooltip
  names the current kind and describes its matching effect. The button
  tooltip names the action and explains the row's destination.
- Resize/re-anchor the edit field and delete button to fit the existing row
  and pane; verify the pattern text remains readable.
- Update the editor instruction label to describe include-any / exclude-none
  behavior.
- User-facing refinement: show all Include rows first, then an "Exclusions"
  divider, then Exclude rows. Toggling a row refreshes the group editor so the
  row moves immediately; the divider appears only when both kinds are present.

### Editor regression tests

- In `Project/Tests/GroupEditorTests.lua`, add cases through
  `this.GetGroupEditorTests()` proving toggle leaves visible text unchanged,
  applies green/red icon colors and deposit/withdraw textures in both toggle
  directions, validates both tooltips, edits preserve kind,
  empty include/exclude
  rows both match nothing, add/delete after toggling save the expected strings,
  and Exclude rows render after Include rows with the divider between them.
- Verify the divider and immediate row movement in game at different scroll
  positions and with Include-only / Exclude-only groups.
- Extend the headless control mock only as needed for the dot, icon button,
  tooltip, and row/divider positioning assertions.

## 4. Documentation and completion checks

- Update [UserManual.bbcode](../../../UserManual.bbcode) with the visible
  Include/Exclude behavior, group-local veto semantics, and a Treasure Maps /
  Cyrodiil example. Do not document the internal suffix as user syntax.
- At implementation start, update the authoritative working changelog from
  actual changes and recommend a version increment before staging; this is a
  backward-compatible feature.
- Run the focused existing headless suites for rule matching, saved-variable
  persistence, group editor, and tracker panel. Then run the normal ESO
  diagnostic test command.
- In ESO, verify the control is readable and clickable, a Cyrodiil map is
  excluded only from Treasure Maps, other groups may still match the item, and
  the setting persists after reload.

## Dependencies

Stage 1 defines the stored-string interpretation needed by both runtime
matching and editor display. Implement and test runtime matching before wiring
the editor control, so the control cannot save a behavior that matching does
not yet support. Stage 4 follows the completed runtime and editor work.
