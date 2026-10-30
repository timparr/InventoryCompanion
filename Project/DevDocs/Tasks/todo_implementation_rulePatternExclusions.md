# Group pattern exclusions: implementation

Status: Implementation in progress; runtime matching and group-editor controls
are implemented and covered by the isolated Lua test suite. In-game verification
and final documentation/release checks remain.

Feature behavior and compatibility requirements are in the
[feature plan](todo_plan_rulePatternExclusions.md). This document follows the
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
  editor-only `{ pattern, isExclusion }` row records.
- Add local `EncodePatternRows(rows)` to serialize those records back into
  plain or suffixed strings for the existing `UpdateRulePatterns()` API.
- Modify `PopulateSingleGroupPane(activeRules)` to build the row records,
  display marker-free text, bind the kind control, and keep the special
  `miscellaneous` group without pattern rows.
- Add local `SetPatternKindLabel(label, isExclusion)` to update the visible
  Include/Exclude text and green/red state using the existing `ZoFontGame` UI
  font.
- Add local `HandlePatternKindToggle(label, row, rows, targetGroup)` to flip
  the row kind, save via `SaveRulePatterns()`, and update the row label
  without rebuilding the list or losing focus.
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

- Modify `InventoryCompanion_PatternEditRow_Template` to add a clickable
  Include/Exclude label: green for Include and red for Exclude, styled like the
  existing state labels rather than a button.
- Resize/re-anchor the edit field and delete button to fit the existing row
  and pane; verify the pattern text remains readable.
- Update the editor instruction label to describe include-any / exclude-none
  behavior.

### Editor regression tests

- In `Project/Tests/GroupEditorTests.lua`, add cases through
  `this.GetGroupEditorTests()` proving toggle leaves visible text unchanged,
  applies green/red label colors, edits preserve kind, empty include/exclude
  rows both match nothing, and add/delete after toggling save the expected
  strings.
- Extend the headless control mock only as needed for the clickable label.

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
