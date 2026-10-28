# Delta-Only Saved Variables

**Status:** Implemented; automated verification complete; in-game acceptance pending

## Goal

Store only user-edited rule properties in saved variables. Keep built-in baseline rules separate so future addon updates can change defaults without being obscured by copied baseline data.

The relevant code is in `Tracking/ItemDatabase.lua` and `Tracking/EditPanelGroupsTab.lua`.

## Proposed mutation API

Route edits through focused mutation functions rather than having UI code construct saved-variable tables directly:

- `UpdateRuleFlag(ruleName, flagKey, value)` updates display flags such as `show`, `notify`, or `isHidden`.
- `UpdateRuleProperty(ruleName, propertyKey, value)` updates root-level metadata such as `displayName`.
- `UpdateRulePatterns(ruleName, uiPatterns)` reconciles the edited pattern list against the built-in baseline and stores only the necessary additions, removals, or changes.

Each mutation should invalidate the shared runtime rule cache. The cache is rebuilt lazily on the next access.

For simple root-level updates, the initial proposal was a surgical setter that creates the rule override table only when needed and writes only the requested property. Pattern edits need the reconciliation behavior described above rather than blindly copying baseline patterns into saved variables.

## Pattern edit algorithm

The Added and Removed collections contain unique pattern values and are kept mutually consistent. `GetList()` returns the default patterns with Removed values excluded and Added values included, sorted before returning.

### GetList()

1. Copy the default pattern list.
2. Remove each pattern in the Removed collection from the copy.
3. Add each pattern in the Added collection that is not already present.
4. Sort the resulting list and return it.

### Add a pattern

1. Get the current effective list with `GetList()`.
2. If the pattern is already in that list, stop without changing either collection.
3. If the pattern is in Removed, remove it from Removed.
4. Otherwise, if the pattern is not in the default list, add it to Added if it is not already there.
5. If either collection becomes empty, it may be stored as absent rather than as an empty collection.

### Remove a pattern

1. Get the current effective list with `GetList()`.
2. If the pattern is not in that list, stop without changing either collection.
3. If the pattern is in Added, remove it from Added.
4. Otherwise, if the pattern is in the default list, add it to Removed if it is not already there.
5. If either collection becomes empty, it may be stored as absent rather than as an empty collection.

### Modify a pattern

Remove the old pattern, then add the new pattern, using the procedures above in that order.

Patterns are treated as unique values in the effective list. If an edited pattern is changed to a value that is already present, the add operation makes no change, so the duplicate is not introduced. For example, changing `b` to `a` in `{a, b, c, d}` produces `{a, c, d}`.

## Read and runtime behavior

At runtime, resolve each rule from its built-in baseline and saved root-property and display-flag overrides. Resolve patterns by applying that rule's Removed and Added collections to the baseline through `GetList()`. Missing overrides fall back to the baseline. Confirm the read behavior while implementing and testing the write paths.

Keep compiled patterns and rule-cache structures in memory only. Saved variables should contain raw user overrides, not compiled Lua patterns or runtime cache data. Consumers such as item-list generation, scanning, and matching should use the compiled runtime cache where appropriate.

### Lazy runtime rule cache

Maintain one in-memory cache containing all effective rule sets, including hidden groups, and their compiled Lua pattern strings. Build each rule's effective pattern list from its built-in defaults and saved Added/Removed collections, then compile it when rebuilding the cache. Consumers that need to exclude hidden groups filter them when using the cache. Use this shared cache for scans, inventory-update notifications, and other rule consumers instead of independently resolving or compiling patterns.

Use a `cacheInvalid` state flag for lazy rebuilding:

1. Initialize `cacheInvalid` to `true`.
2. Whenever a consumer requests runtime rules, check `cacheInvalid`.
3. If invalid, build a complete replacement cache from the current built-in rules and saved-variable overrides. Publish the replacement only after it has been built successfully, then set `cacheInvalid` to `false`.
4. Return the valid cache to the consumer.
5. When rule state changes, mark the cache invalid. Rebuild on the next cache access, not only on the next inventory scan, because notification and other paths may need the rules first.

Rule mutation setters invalidate the cache after changing saved rule state:

- `UpdateRuleFlag` (currently implemented as `SetRuleFlag`) invalidates after changing a display flag.
- `UpdateRuleProperty` (also referred to as `SetRuleProperty`) invalidates after changing a root-level property.
- `UpdateRulePatterns` invalidates after changing the Added/Removed pattern collections.

Other rule-state changes that invalidate the cache:

- Switching between the account-wide and character-specific rule lists.
- Successfully copying/importing a profile, which replaces the active list's saved rule overrides.
- Creating a custom group.
- Deleting a group.
- Resetting a group, which clears only its saved name and pattern overrides and retains all display settings.
- Unhiding a group. Route this through `UpdateRuleFlag`/`SetRuleFlag` where possible rather than writing the flag directly.
- Clearing all rule overrides with `/icclearoverrides`.

These operations should invalidate after changing the effective rule state. Where practical, route individual rule edits through the mutation setters instead of writing saved rule data directly. Initializing a missing saved-rule table does not need separate invalidation when the cache starts invalid.

## UI write paths

- Group-name edits should update only the `displayName` override.
- Pattern edits should use full baseline reconciliation, clearing overrides when the edited list matches the baseline again.
- Display-flag changes should update only the selected flag.
- Preserve the group editor's current rows while an input loses focus; saving may refresh the HUD without forcing the editor list to rebuild.

## Verification scenarios

1. With default patterns `{a, b, c}`, verify no redundant baseline copy is written.
2. Add pattern `d`; verify only the required user override is stored and the runtime cache updates.
3. Change baseline pattern `a` to `a1`; verify the override represents the edit.
4. Change `a1` back to `a`; verify the override is cleared when the effective list matches baseline.
4.1 change d to d1; verify the resulting output from the get
4.2 remove c; again verify the resulting output from the get

### Expected pattern state for the sequential scenarios

Start with default patterns `{a, b, c}` and empty Added and Removed collections. Apply scenarios 2 through 4.2 in order. `GetList()` starts with the default list minus Removed entries, then appends Added entries, sorts the final list, and returns it.

| Step | Operation | Added | Removed | `GetList()` |
|---|---|---|---|---|
| 1 | No edits | `{}` | `{}` | `{a, b, c}` |
| 2 | Add `d` | `{d}` | `{}` | `{a, b, c, d}` |
| 3 | Modify `a` to `a1` | `{d, a1}` | `{a}` | `{a1, b, c, d}` |
| 4 | Modify `a1` back to `a` | `{d}` | `{}` | `{a, b, c, d}` |
| 4.1 | Modify `d` to `d1` | `{d1}` | `{}` | `{a, b, c, d1}` |
| 4.2 | Remove `c` | `{d1}` | `{c}` | `{a, b, d1}` |

5. Rename a group and toggle a display flag; verify each operation changes only its own saved property.
6. Reload the UI and confirm saved overrides are applied while unmodified properties continue to use the baseline.
7. Edit a pattern and move focus; confirm the HUD refreshes without the group editor rows jumping or rebuilding unexpectedly.

## Implementation subtasks and work log

For the detailed per-subtask file/method inventory, implementation decisions, and corrections, see the separate [implementation and decision review](Don_DeltaOnlySavedVariables.md).

Each numbered subtask is committed separately, with its results appended here.
All implementation remains on the existing branch unless a branch switch is approved.

- [x] 0. Checkpoint the existing work and record this implementation breakdown.
- [x] 1. Implement delta storage, focused setters, legacy conversion, and isolated rule unit tests.
- [x] 2. Add the lazy compiled runtime cache and wire scanning, notifications, profile copying, and list switching; extend tests.
- [x] 3. Route group-editor mutations through the new APIs, including create/delete/reset/unhide; preserve focus-loss behavior and test editor paths.
- [x] 4. Run final regression checks, document the storage contract and in-game verification steps, and update task tracking.

### Subtask 0 - checkpoint and breakdown

- Committed the pre-existing documentation changes before implementation (`d5eaf6a`).
- Inspected rule resolution, group editing, profile copying, matching, and existing synthetic tests.
- Existing full pattern lists will be reconciled against the installed baseline on first use; explicit edits are preserved, redundant baseline values are removed. Historical intent cannot be recovered when an older release copied a default that has since changed.
- Additional tests will use isolated fixtures, never live inventory or saved variables. Native ESO UI behavior and real-client timings still require in-game verification.

### Subtask 1 - delta storage and focused setters

- Added `UpdateRuleProperty`, `UpdateRuleFlag` (with the existing `SetRuleFlag` alias), and `UpdateRulePatterns`.
- Persist sorted unique `addedPatterns`/`removedPatterns` arrays; baseline-equivalent values and empty baseline overrides are removed. Empty custom groups remain valid.
- Resolve defaults plus deltas without sharing baseline pattern/display tables. Convert legacy `patterns` lists on read and prune redundant legacy names/flags.
- Added five isolated unit tests covering every sequential specification state, duplicate edits, empty/custom groups, surgical writes, reversion, migration, baseline updates, and invalid input.
- Added a reusable Lua 5.1 runner at `Project/Tests/Run-RuleTests.py` (requires Python package `lupa`) and included the same cases in `/ictest`.
- Validation: `python Project\Tests\Run-RuleTests.py` passed 5/5 cases and syntax-checked all addon Lua sources under Lua 5.1; `git diff --check` passed.

### Subtask 2 - lazy cache and runtime consumers

- Added one lazy runtime cache containing all effective rules (including hidden ones) and compiled Lua patterns. Replacement caches publish only after successful construction.
- Scans reuse cached compiled patterns; notifications and the untracked-items filter match compiled rules directly. Normal views still exclude hidden groups.
- `GetActiveTrackedRules` returns private name/pattern/display views so existing editor toggles and HUD-only miscellaneous-group adjustments cannot corrupt cached state.
- Wired list switching in both settings/editor controls, successful profile imports, and `/icclearoverrides` to invalidation.
- Profile import now copies only explicit override fields, converts legacy lists, avoids source-array/display aliases, and snapshots before clearing so self-copy is safe.
- Added five more isolated cases for lazy reuse/invalidation, editor-view isolation, hidden groups/list switching, failed cache builds, profile copying, and real scanning/notification paths.
- Validation: 10/10 isolated cases pass; all addon Lua syntax checks and `git diff --check` pass. In-game timing and UI verification remain pending.

### Subtask 3 - editor mutations and group lifecycle

- Group renaming and pattern editing now call the focused setters; pattern edits no longer overwrite a renamed group or copy display defaults.
- Creation, deletion, reset, and both built-in/custom unhide paths use invalidating mutation APIs. New custom groups persist only their edited name.
- The initial implementation incorrectly cleared display flags on Reset. The post-implementation correction below restores the required name-and-pattern-only behavior; display-only overrides do not offer Reset.
- Focus-loss saves refresh the HUD and action buttons without rebuilding/reanchoring group or pattern rows.
- Added one shared lifecycle unit test and five headless tests that exercise the actual group-editor handlers using fake ESO controls. Fake controls are never loaded by the addon.
- Validation: 16/16 isolated rule/editor cases pass under Lua 5.1; all addon Lua syntax checks and `git diff --check` pass. Native ESO focus/event ordering still needs the in-game check below.

### Subtask 4 - regression checks and documentation

- Extended shared tests to cover untouched-default storage, updated baseline inheritance, all 64 subsets of a six-pattern input (including duplicate inputs), stable matcher identity, and cached synthetic performance thresholds.
- Added headless serialization/reinitialization and actual `/icclearoverrides` handler checks in an isolated Lua state.
- Final code review corrected matcher declaration scope and ensured `/ictest` invalidates the synthetic cache after restoring live runtime references; added a regression assertion for matcher stability.
- Updated the user manual's reset/default-inheritance behavior and project task tracking. Kept in-game acceptance explicitly pending rather than claiming client testing.
- Validation: 21/21 headless cases pass; all addon Lua sources parse under Lua 5.1; `git diff --check` passes. The existing isolated packaging suite passes 187 assertions, including the new manifest entry.
- Synthetic reference timings: 20 scans of 100 items across 20 rules took 41 ms (limit 500 ms), 100 cached matches took 1 ms (limit 100 ms), and 100 inventory updates took less than 1 ms at millisecond clock resolution (limit 200 ms). Host timings are not ESO-client evidence.

## Implemented storage contract

The active account/character `trackedRules` table stores rule slugs with these optional fields:

```lua
trackedRules = {
    default_group = {
        displayName = "My name",
        display = { notify = false },
        addedPatterns = { "new pattern" },
        removedPatterns = { "removed default pattern" },
    },
    custom_group = {
        displayName = "My custom group",
        addedPatterns = { "custom*" },
    },
}
```

- Missing fields inherit the installed built-in baseline; custom groups inherit the standard custom display defaults and have no baseline patterns.
- Patterns are unique, case-preserving values sorted for display/storage; matching remains case-insensitive, with the existing wildcard and literal-substring behavior.
- Baseline-equivalent edits and empty collections are absent. An empty built-in override is removed; an empty custom-rule table remains because its key defines the group.
- `UpdateRulePatterns` reconciles the complete edited list. `UpdateRuleProperty` accepts `displayName`; `UpdateRuleFlag` accepts existing display flags. `SetRuleFlag` remains a compatibility alias.
- `GetRuntimeRules` exposes the shared read-only-by-contract cache, including hidden rules. `GetActiveTrackedRules` returns filtered private pattern/display views; its compiled arrays are shared and must not be modified.
- Legacy full `patterns` arrays are converted against the installed baseline on first resolution/import without changing the source profile during import. Only the active profile is converted on read. Equal legacy name/display values are pruned.
- Conversion preserves the old effective list at migration time, but cannot distinguish an intentional old override from a default copied by an older editor. Once converted, subsequent baseline additions appear unless explicitly removed.
- No compiled patterns or cache fields are saved. The saved-variable namespace/version is unchanged; older addon builds do not understand the new delta fields. Back up saved variables before client testing or downgrading; restore that backup when reverting to an older build.
- Reset clears only the selected built-in group's name and pattern overrides (including legacy full-pattern lists). All display settings, including hidden state, are retained. Empty rule entries are pruned only when no overrides remain. Display-only overrides do not offer Reset. Deletion is restricted to custom rules. Both operations affect only the active profile.

## Repeatable automated verification

From the development checkout:

```powershell
python -m pip install lupa
python Project\Tests\Run-RuleTests.py
& .\Project\Publishing\Test-PackageRelease.ps1
git diff --check
```

The headless runner now executes 20 shared rule cases, six actual group-editor handler cases with fake controls, and three production-baseline/persistence/command cases under Lua 5.1. The packaging suite uses its own temporary installation fixture. Neither reads or modifies live saved-variable files or live inventory. In game, `/ictest verbose` includes the 20 shared cases alongside the existing suite; synthetic fixtures restore the original runtime references even on test failure.

## In-game acceptance checklist (not yet executed)

Back up saved variables before testing migration. The existing publishing script's `-Action Backup` copies and hash-verifies the last-on-disk snapshot; it does not capture ESO's unsaved in-memory state.

- [ ] Run `/ictest verbose`; confirm shared rule tests and real-client timing thresholds pass.
- [ ] Rename a built-in group, edit a pattern, and toggle flags. Confirm each persists independently and pattern editing never resets the name.
- [ ] Follow the sequential pattern scenarios above, including reversion, duplicate edits, and removing all patterns. Confirm the effective HUD/matching results.
- [ ] Move focus between pattern rows; confirm text/rows do not jump and Reset becomes available without a list rebuild. Confirm explicit add/delete operations rebuild normally.
- [ ] Hide/unhide built-in and custom groups, create/delete a custom group, and reset a built-in group. Confirm Reset restores only the name and patterns while retaining all display settings, including hidden state, and that its confirmation explains this.
- [ ] Switch account/character lists through both settings and the editor; import a profile and confirm no stale matches or lost partial defaults.
- [ ] Reload the UI, inspect the saved rule fields, and confirm only raw deltas remain while unmodified values still follow defaults.
- [ ] On a disposable test profile only, verify `/icclearoverrides` clears the active list, restores baseline behavior immediately, and leaves the other list unchanged.

## Post-implementation correction - group Reset

- Requirement clarified: Reset must restore only a built-in group's name and pattern list. Display settings must be retained, including `show`, `notify`, `bank`, `group`, `isExpanded`, and `isHidden`.
- Corrected `ResetRule` to remove only name/pattern fields, preserve the display override table, prune an otherwise empty rule, and invalidate the runtime cache.
- Reset availability now checks only name/pattern overrides; display-only changes do not expose an ineffective Reset button.
- Updated the confirmation and user manual. Extended shared and actual editor-handler tests to cover every display flag, hidden-state retention, repeated resets, empty-rule pruning, cache invalidation, and account/character isolation.
- Validation: 21/21 isolated rule/editor/persistence cases pass; all addon sources parse under Lua 5.1; `git diff --check` passes. Native ESO acceptance remains pending.

## Ownership-boundary follow-up

- Saved-rule validation now runs for both account/character profiles immediately after loading and for source profiles before import. Newly encountered saved-rule tables are checked once before use.
- Malformed present fields are rejected with a profile/rule/field Lua error, leaving data available for repair. No guessed repairs, silent skips, or discarded unrelated entries. Missing optional fields and valid legacy data retain their documented behavior.
- Maintained code now calls required addon functions directly; missing required controls/dialog data and broken built-in definitions fail near the cause. Scans require compiled rules; synthetic tests use real resolved rules instead of relying on fallback compilation.
- Pattern setters require dense string arrays, list switching requires a boolean, and valid Reset behavior still retains all display flags.
- Validation: 29/29 headless cases and 187 isolated packaging assertions pass; all addon Lua syntax checks and `git diff --check` pass. In-game acceptance remains pending.
- The separate [implementation and decision review](Don_DeltaOnlySavedVariables.md#follow-up---fail-fast-internals-and-saved-data-ownership-boundary) records the affected methods, files, and explicit handling decisions.
