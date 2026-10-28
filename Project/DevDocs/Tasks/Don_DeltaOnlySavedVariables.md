# Delta-Only Saved Variables - Implementation and Decision Review

This is the separate post-implementation work log and review document requested by the user. It records each subtask's files, methods, decisions, verification, and subsequent corrections.

The [design and acceptance checklist](DeltaOnlySavedVariables.md) remains the companion specification. This document distinguishes historical implementation choices from the corrected current behavior.

**Current state:** implementation committed on `main`; automated checks passed; native ESO acceptance remains pending.

**Important correction:** Reset restores only a built-in group's name and patterns. It preserves every display setting, including hidden state. The original implementation incorrectly cleared display settings; that mistake and its correction are recorded below.

## Commit and subtask index

| Subtask | Commit | Outcome |
|---|---|---|
| 0a. Pre-work checkpoint | `d5eaf6a` | Preserved existing documentation changes before implementation. |
| 0b. Breakdown | `f74252b` | Added the numbered implementation checklist to the design document. |
| 1. Delta storage and setters | `ed870f7` | Sparse persistence, legacy conversion, and initial tests. |
| 2. Runtime cache and consumers | `c1fffbb` | Shared lazy compiled cache, imports, and list switching. |
| 3. Editor and lifecycle | `703035e` | Routed editor mutations through database APIs; added handler tests. |
| 4. Final regression and documentation | `47e67a7` | Persistence/performance coverage and acceptance documentation. |
| Post-implementation Reset correction | `ae25468` | Preserved display settings and restricted Reset to name/pattern edits. |

No branch switch was made. The initial workflow warning recommended a separate branch because persistence changes are substantial, but branch switching required approval.

## Subtask 0 - checkpoint and breakdown

### Files changed

The checkpoint committed pre-existing changes in:

- [COMPLETED.md](../COMPLETED.md).
- [TODO.md](../TODO.md).
- [DeltaOnlySavedVariables.md](DeltaOnlySavedVariables.md).

The breakdown commit changed only [DeltaOnlySavedVariables.md](DeltaOnlySavedVariables.md), adding subtasks 0-4 and the initial work-log section.

### Methods added or changed

None. These commits changed documentation only.

### Decisions and limitations

1. **Checkpoint existing work as requested.** The three pending documentation files were inspected and committed before addon code was edited.
2. **Remain on the current branch.** Work stayed on `main`; there was no approved branch switch.
3. **Use isolated synthetic fixtures for new tests.** Tests would not transfer inventory or intentionally write live saved variables.
4. **Support existing full-pattern saved data.** Legacy lists would be reconciled against the installed baseline rather than discarded.
5. **Originally embed the log in the design document.** This did not meet the user's intended separate-document workflow. This new document addresses that organizational mistake.
6. **Treat client acceptance separately.** Headless tests cannot establish native ESO focus ordering, actual UI persistence, or real-client timings.

### Verification

The working tree was inspected and the checkpoint and breakdown were committed. No code tests were necessary for these documentation-only commits.

## Subtask 1 - delta storage and focused setters

**Commit:** `ed870f7`.

### Files changed

| File | Changes |
|---|---|
| [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) | Added delta calculation, focused mutation APIs, legacy conversion, and baseline-plus-override resolution. |
| [Core/RuleTests.lua](../../../Core/RuleTests.lua) | New shared test suite, initially containing five isolated cases. |
| [Core/Tests.lua](../../../Core/Tests.lua) | Included the new tests in `/ictest`; adjusted an existing flag-write test to use a value different from the baseline. |
| [InventoryCompanion_DEV.txt](../../../InventoryCompanion_DEV.txt) | Added the shared rule-test module to the load order. |
| [Project/Tests/Run-RuleTests.py](../../Tests/Run-RuleTests.py) | New headless Lua 5.1 runner using Python's `lupa` package. |
| [DeltaOnlySavedVariables.md](DeltaOnlySavedVariables.md) | Appended subtask work and validation results. |

### Public methods added

These methods are in [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua):

- **`UpdateRuleProperty(ruleName, propertyKey, value)`** supports `displayName` only. Writes that property without copying patterns or display flags. Removes the override when restored to its baseline value. A `nil` value also clears the override.
- **`UpdateRuleFlag(ruleName, flagKey, value)`** updates only the selected supported display flag. Removes baseline-equivalent values and preserves unrelated fields. Accepts boolean values or `nil`.
- **`UpdateRulePatterns(ruleName, uiPatterns)`** accepts the complete edited list and calculates `addedPatterns` (edited values absent from baseline) and `removedPatterns` (baseline values absent from the edited list).
- **`InvalidateRuleCache()`** marks runtime rules invalid. This subtask introduced the flag; the actual lazy cache arrived in subtask 2.

The existing **`SetRuleFlag`** became a compatibility alias for `UpdateRuleFlag`.

The new test module added **`GetRuleTests()`**, returning named test cases for both headless execution and `/ictest`.

### Internal helpers added

In [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua):

| Helper | Responsibility |
|---|---|
| `PatternSet` | Validate that pattern values are strings and deduplicate them using a Lua set. |
| `SortedPatterns` | Turn a set into a sorted array. |
| `GetPatternList` | Apply saved removals and additions to baseline patterns. |
| `ReconcilePatterns` | Calculate and store the two delta arrays; remove the legacy full `patterns` field. |
| `PruneRule` | Remove empty display tables and empty built-in overrides. |
| `NormalizeRule` | Convert legacy full-pattern lists and remove redundant baseline name/flag values. |

**`GetActiveTrackedRules(includeHidden)` was rewritten** to resolve defaults plus these overrides without sharing editable pattern/display tables with the baseline. Subtask 2 subsequently moved resolution into the cache.

### Decisions made

1. **Storage names and shape:** used sorted arrays named `addedPatterns` and `removedPatterns`, rather than a nested collection object.
2. **Full-list reconciliation:** the UI supplies its complete edited list. The database calculates the delta; it does not expose separate public add/remove/modify-pattern methods. The design's `GetList()` behavior is provided by the internal `GetPatternList`, not a public object method named `GetList`.
3. **Equality rules:** pattern uniqueness is case-sensitive and exact, while matching remains case-insensitive. `"Rune"` and `"rune"` are therefore distinct saved values.
4. **Automatic legacy conversion:** old `patterns` arrays are converted when active rules are resolved. Reading rules can therefore modify the active saved-variable table in memory; this is not a separate migration command.
5. **Migration against the installed baseline:** preserves the old effective list at conversion time, apart from intentional uniqueness/sorting. It cannot distinguish an intentional edit from a default copied by an older editor.
6. **Prune baseline-equivalent values:** names and flags equal to the current baseline are removed. A choice equal to today's default is not retained as a permanent pin against future default changes.
7. **Custom groups use the same delta format:** custom groups have no baseline patterns, so their patterns are additions. An empty custom-group table is retained because its key defines the group.
8. **Partial custom display settings inherit defaults:** missing flags use standard custom-group defaults instead of remaining unset. These are `show=true`, `notify=false`, `bank=false`, `group=true`, `isExpanded=true`, and `isHidden=false`.
9. **Input failures are explicit:** mutation APIs assert on unsupported properties/flags or invalid value types rather than silently accepting them. Pattern values are checked before creating the saved override.
10. **Test tooling:** added a Python/`lupa` runner for execution outside ESO. The addon itself has no Python dependency. The missing `lupa` package was installed in the available Python environment.
11. **No runtime cache persistence:** only raw overrides belong in saved variables.

### Verification at this point

Five isolated cases passed:

- Sequential specification edits and reversions.
- Duplicate patterns, empty lists, and custom groups.
- Surgical name/flag/pattern writes.
- Legacy conversion, unchanged baseline tables, and subsequent baseline additions.
- Invalid mutations failing without creating saved overrides.

All addon Lua files in the core, banking, and tracking directories passed Lua 5.1 syntax checks. `git diff --check` passed.

**Reset behavior was not changed in this subtask.**

## Subtask 2 - lazy runtime cache and consumers

**Commit:** `c1fffbb`.

### Files changed

| File | Changes |
|---|---|
| [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) | Added the shared cache, compiled-rule matching, private active-rule views, list-switch setter, and sparse/deep-enough profile copying. |
| [Tracking/EditPanelItemsTab.lua](../../../Tracking/EditPanelItemsTab.lua) | Routed list switching through the new setter and used compiled matching when excluding already-matched items from the untracked list. |
| [Core/Settings.lua](../../../Core/Settings.lua) | Routed the character-specific-list setting through the same setter. |
| [Core/Init.lua](../../../Core/Init.lua) | Invalidated rules after `/icclearoverrides`. |
| [Core/Tests.lua](../../../Core/Tests.lua) | Adjusted profile-copy expectations to delta fields and exercised notifications through the real cache rather than a stubbed active-rule resolver. |
| [Core/RuleTests.lua](../../../Core/RuleTests.lua) | Added five cache/consumer test cases and expanded fixture restoration. |
| [Project/Tests/Run-RuleTests.py](../../Tests/Run-RuleTests.py) | Initialized a synthetic settings namespace for profile-copy tests. |
| [DeltaOnlySavedVariables.md](DeltaOnlySavedVariables.md) | Recorded the subtask and verification. |

### Public methods added

In [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua):

- **`GetRuntimeRules()`** returns the shared cache, including hidden groups. Rebuilds only when invalid or when the active saved-rule/baseline table identity changes.
- **`SetUseCharacterItemList(value)`** changes the active-list preference and invalidates the cache.
- **`ItemMatchesRuntimeRule(itemLink, rule)`** retrieves the item name and matches it against the rule's compiled patterns.

### Existing methods and handlers changed

- **`GetActiveTrackedRules(includeHidden)`** now obtains resolved rules from `GetRuntimeRules`. It returns fresh rule tables with copied raw pattern/display tables, filters hidden rules unless requested, and preserves the existing miscellaneous-group exception.
- **`CopyProfile(sourceKey)`** snapshots destination-bound data before clearing, copies only explicit rule fields, copies pattern/display collections, converts copied legacy rule lists, then replaces destination contents and invalidates.
- **`CompilePatterns`** changed from a local function declaration to a forward-declared local function variable so the earlier cache-builder function could refer to it.
- **`HandleTrackedItemInventoryUpdate`** uses cached compiled rules directly and excludes hidden groups from rule notifications.
- **`GetMasterItemList`** uses each rule's existing `compiledPatterns` when supplied. It retains a compilation fallback for caller-supplied raw rule tables, including existing synthetic tests.
- **`InitCharacterToggle` / its `ApplyUseChar` callback** in [Tracking/EditPanelItemsTab.lua](../../../Tracking/EditPanelItemsTab.lua) route checkbox and label interactions through `SetUseCharacterItemList`.
- **`CollectUntrackedItems`** in the same file uses `ItemMatchesRuntimeRule`.
- The character-list settings callback and `/icclearoverrides` handler now invalidate through the common API.

### Internal helper and state added

- **`CopyValues(values)`** copies the flat tables used for raw pattern arrays and display flags. It is not a general recursive deep-copy utility.
- **`runtimeRules`** holds the last fully built cache.
- **`cachedSavedRules` and `cachedBaseline`** remember the table identities associated with that cache.
- **`cacheInvalid`** controls lazy replacement; errors leave it invalid.

### Decisions made

1. **Cache all groups, filter at consumption.** Hidden groups remain available to the group editor, but normal active views and rule notifications exclude them.
2. **Publish only complete replacement caches.** Construction occurs in a local table; only successful construction replaces the cache. An old cache is not partially overwritten on failure.
3. **Do not eagerly rebuild in setters.** Setters invalidate; the next reader rebuilds, including notification readers that run before another scan.
4. **Copy mutable views rather than change existing UI assumptions.** The item editor mutates its display view, and HUD layout changes miscellaneous-group display fields. Copying those views keeps them from corrupting the shared cache.
5. **Share compiled arrays by convention.** Active views reference the cached compiled arrays. These arrays, and the cache returned by `GetRuntimeRules`, are read-only by contract, not protected with Lua metatables.
6. **Keep the raw-rule compilation fallback.** This preserves the existing `GetMasterItemList` calling contract for supplied synthetic/raw rules. Normal resolved addon rules reuse compiled arrays.
7. **Detect replaced tables, not arbitrary nested edits.** Replacing the active saved-rule or baseline table triggers rebuilding even without explicit invalidation. In-place nested changes still require a setter or `InvalidateRuleCache`.
8. **Preserve missing imported flags.** Import no longer fills every rule display flag with a boolean fallback, which would mask baseline defaults.
9. **Isolate copied profiles.** Pattern arrays and display tables do not alias the source. Normalization operates on the copied rule rather than migrating the source profile in place.
10. **Snapshot before clearing.** This also makes self-copy safe rather than clearing the source before reading it.
11. **Do not invalidate a failed profile lookup.** A missing source returns `false`; successful imports invalidate.
12. **Keep compilation semantics unchanged.** Case-insensitive substring matching and anchored wildcard behavior were retained.

### Verification at this point

Ten total isolated cases passed. New coverage included:

- Lazy cache reuse, replacement, and name/flag/pattern invalidation.
- Private editor views not corrupting cached raw values.
- Hidden-group inclusion/exclusion and account/character switching.
- Failed cache construction not publishing partial state.
- Sparse profile copying, source isolation, missing sources, and self-copy.
- Real scanning and notification functions seeing current compiled patterns, including edits before any scan.

All addon Lua syntax checks and `git diff --check` passed. Native UI behavior and real-client timings remained pending.

## Subtask 3 - editor mutations and group lifecycle

**Commit:** `703035e`.

### Files changed

| File | Changes |
|---|---|
| [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) | Added lifecycle APIs and reset-availability query. |
| [Tracking/EditPanelGroupsTab.lua](../../../Tracking/EditPanelGroupsTab.lua) | Replaced direct saved-rule writes with mutation APIs; updated action buttons and focus-loss handling. |
| [Core/RuleTests.lua](../../../Core/RuleTests.lua) | Added a lifecycle test case. |
| [Project/Tests/GroupEditorTests.lua](../../Tests/GroupEditorTests.lua) | New headless harness exercising actual editor handlers with fake ESO controls. |
| [Project/Tests/Run-RuleTests.py](../../Tests/Run-RuleTests.py) | Loaded the fake-control harness and actual group-editor module for handler tests. |
| [DeltaOnlySavedVariables.md](DeltaOnlySavedVariables.md) | Recorded implementation and validation. |

### Public methods added

In [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua):

- **`CreateCustomRule(ruleName, displayName)`** rejects an existing key or built-in rule and creates a sparse custom group through the name setter.
- **`DeleteCustomRule(ruleName)`** rejects built-in deletion, removes the custom key, and invalidates.
- **`ResetRule(ruleName)`** rejects custom-group reset and invalidates after changing the built-in override. Its original implementation was incorrect; see the correction section for current behavior.
- **`HasRuleOverrides(ruleName)`**, as originally named, checked whether any saved fields remained. The correction replaced it with **`HasResettableRuleOverrides(ruleName)`**, which checks only name/pattern fields.

The headless test harness added **`GetGroupEditorTests()`**. It is not loaded by the addon manifest.

### Existing editor methods changed

In [Tracking/EditPanelGroupsTab.lua](../../../Tracking/EditPanelGroupsTab.lua):

- **`CommitGroupNameEdit`** calls `UpdateRuleProperty` instead of constructing a baseline clone.
- **`SaveRulePatterns`** delegates to `UpdateRulePatterns`; it no longer resets a renamed group's name or copies display defaults.
- **`HandlePatternFocusLost`** saves, refreshes the HUD, and refreshes action-button state without calling the full editor refresh.
- **`ConfigureCustomGroupActionBar` and `ConfigurePreloadedHideButton`** use `SetRuleFlag` for unhide as well as hide.
- **`SetActionButtons`** uses resolved hidden state and the reset-availability query.
- **`InitNewGroupButton`** calls `CreateCustomRule` rather than saving a full default display table and empty pattern array.
- **`DoDeleteGroup`** calls `DeleteCustomRule`.
- **`DoResetGroup`** calls `ResetRule`.
- **`DoesGroupNameExist`, `GenerateUniqueGroupName`, and action-button helper signatures** had unused saved-rule parameters removed after direct persistence writes were eliminated.
- **`HasMeaningfulOverride`** was removed in favor of the database query.

### Decisions made

1. **Keep persistence responsibility in the database.** UI handlers supply intent rather than constructing saved-variable rule tables.
2. **New custom groups persist only their name.** Default display settings and an empty pattern list are resolved rather than redundantly saved.
3. **Preserve focus-loss rows.** Saving a pattern updates the HUD and action buttons, not the group/pattern lists. Explicit add/delete actions still rebuild lists normally.
4. **Do not normalize the visible editing buffer immediately.** Reconciliation deduplicates/sorts effective saved rules without replacing the current row buffer on focus loss. A later explicit rebuild displays the normalized list.
5. **Use actual handlers in headless tests.** Fake controls provide enough methods to load and exercise the real editor module; tests check row identity, anchor movement, refresh counts, saved deltas, and button actions.
6. **Keep fake controls out of the addon.** Only the Python runner loads the fake-control harness. Shared database tests remain available through `/ictest`.
7. **Original mistaken Reset decision:** I interpreted "clears its saved overrides" as clearing the entire group override, including display settings. I also made display-only overrides eligible for Reset. This exceeded the intended behavior and was not a requirement of delta storage. It was corrected after user review.

### Verification at this point

Sixteen total headless cases passed: eleven shared rule cases and five editor-handler cases.

The handler tests covered rename/pattern independence, focus-loss row preservation, pattern addition/deletion, hide/unhide/reset, and custom creation/deletion. At this historical point, the reset expectations matched the mistaken full-reset behavior; passing tests did not make that product decision correct.

All addon Lua syntax checks and `git diff --check` passed. Native ESO focus/event ordering remained unverified.

## Subtask 4 - final regression checks and documentation

**Commit:** `47e67a7`.

### Files changed

| File | Changes |
|---|---|
| [Core/RuleTests.lua](../../../Core/RuleTests.lua) | Added untouched-default, exhaustive subset, stable-matcher, and cached-burst assertions. |
| [Core/Tests.lua](../../../Core/Tests.lua) | Invalidated the synthetic cache after restoring original live runtime references. |
| [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) | Corrected the scope of `ItemMatchesRuntimeRule` so compilation does not define/redefine the public matcher. |
| [Project/Tests/GroupEditorTests.lua](../../Tests/GroupEditorTests.lua) | Restricted the deterministic group-creation clock override to the relevant test. |
| [Project/Tests/RulePersistenceTests.lua](../../Tests/RulePersistenceTests.lua) | New serialized reload and actual clear-command tests in a separate Lua state. |
| [Project/Tests/Run-RuleTests.py](../../Tests/Run-RuleTests.py) | Added real monotonic timing, ordered suite collection, persistence-state setup, and performance detail output. |
| [UserManual.md](../../../UserManual.md) | Documented default inheritance and Reset; Reset wording was subsequently corrected. |
| [TODO.md](../TODO.md) | Changed the outstanding task from implementation to in-game acceptance. |
| [COMPLETED.md](../COMPLETED.md) | Recorded implementation under an explicit awaiting-in-game-acceptance heading. |
| [DeltaOnlySavedVariables.md](DeltaOnlySavedVariables.md) | Added the storage contract, test commands, downgrade warning, final results, and client acceptance checklist. |

### Methods and helpers added or changed

- **`GetRuleTests()`** gained three cases, bringing shared coverage to fourteen.
- **`GetRulePersistenceTests()`** was added in the headless-only persistence harness.
- **`Serialize(value)`**, a local test helper, produces deterministic synthetic saved-data Lua, rejects unsupported runtime values, and rejects persisted `compiledPatterns`/`isPreloaded` fields.
- **`ItemMatchesRuntimeRule`** was moved out of the compilation loop into its own top-level function definition. This was a real implementation defect found during final direct review; a matcher-identity assertion now guards against recurrence.
- The outer **`RunTests`** cleanup invalidates after restoring original account, character, and baseline references so synthetic cached rules are not retained as the next live cache.

### Decisions made

1. **Test exact output shapes, not just matching results.** The subset test checks additions, removals, effective patterns, and the absence of unrelated saved fields across all 64 subsets of six candidate patterns, with duplicate inputs.
2. **Measure the cached paths.** New performance checks use resolved cached rules rather than only testing the pre-existing raw-rule compilation fallback.
3. **Use existing thresholds.** Twenty scans of 100 items across twenty rules must complete within 500 ms; 100 matches within 100 ms; 100 updates within 200 ms.
4. **Use a real monotonic host clock.** The runner uses Python's `perf_counter` at millisecond resolution. Timings are host evidence, not ESO-client evidence.
5. **Test reload-like reconstruction in a separate Lua state.** Serialize raw overrides, reconstruct the saved table, re-execute the actual database module, and verify restored effective/compiled behavior without persisting runtime fields.
6. **Exercise the actual slash handler.** The persistence harness loads the real initialization module with minimal event/printing stubs, then invokes `/icclearoverrides` for account and character lists.
7. **Run existing packaging regression after the manifest change.** The suite uses its own temporary installation fixture, not the real adjacent installation.
8. **Do not claim client acceptance.** Project tracking explicitly leaves native UI behavior, actual UI reload persistence, and real-client timing pending.
9. **Do not change the saved-variable namespace or version.** Legacy conversion occurs in the existing namespace. Older addon builds do not understand delta fields; the documentation therefore warns to restore a backup when downgrading. This is a compatibility decision worth explicit review.
10. **Do not automatically back up or migrate on-disk files during development checks.** All new execution used synthetic data. The client checklist recommends backing up before migration testing.

### Verification at this point

- **21/21 headless cases passed:** fourteen shared rule cases, five editor cases, two persistence/command cases.
- All addon Lua sources in the core, banking, and tracking directories parsed under Lua 5.1.
- `git diff --check` passed.
- **187 existing packaging assertions passed** in a temporary fixture; live installations and saved variables were not modified.
- A recorded reference run measured 41 ms for the twenty scans, 1 ms for 100 matches, and less than 1 ms at clock resolution for 100 updates. Repeated host runs varied while remaining below thresholds.

The complete `/ictest` suite was not run inside ESO by this implementation session. Including shared tests in `/ictest` is wiring, not evidence that the game executed them.

## Post-implementation correction - Reset retains display settings

**Commit:** `ae25468`.

### Requirement clarified by the user

Reset must restore only the group's name and pattern list. It must retain display settings.

This includes all six flags:

- `show`
- `notify`
- `bank`
- `group`
- `isExpanded`
- `isHidden`

In particular, Reset must not unhide a hidden group.

### Files changed

| File | Changes |
|---|---|
| [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) | Restricted Reset to name/pattern fields and added a specifically named resettable-override query. |
| [Tracking/EditPanelGroupsTab.lua](../../../Tracking/EditPanelGroupsTab.lua) | Used that query for Reset visibility and corrected the confirmation. |
| [Core/RuleTests.lua](../../../Core/RuleTests.lua) | Verified every display flag, repeated reset, cache invalidation, pruning, and active-profile isolation. |
| [Project/Tests/GroupEditorTests.lua](../../Tests/GroupEditorTests.lua) | Verified the actual Reset handler preserves notification/hidden settings and no longer offers Reset for display-only overrides. |
| [UserManual.md](../../../UserManual.md) | Corrected user-facing Reset behavior. |
| [DeltaOnlySavedVariables.md](DeltaOnlySavedVariables.md) | Corrected the contract/checklist and appended the correction log. |

### Current methods and behavior

In [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua):

- **`ResetRule(ruleName)`** clears `displayName`, legacy `patterns`, `addedPatterns`, and `removedPatterns`. It keeps the display override table, prunes an otherwise empty rule, and invalidates the cache.
- **`HasResettableRuleOverrides(ruleName)`** replaces the original `HasRuleOverrides`. It checks only the four name/pattern fields, not display flags.
- Reset remains restricted to built-in rules and the active account/character profile.

In [Tracking/EditPanelGroupsTab.lua](../../../Tracking/EditPanelGroupsTab.lua):

- Reset visibility uses `HasResettableRuleOverrides`, including the special miscellaneous group.
- Display-only changes no longer expose a button that cannot reset anything.
- The confirmation explicitly says that the custom name and pattern edits are cleared and display settings are kept.

### Decisions and accountability

1. **Preserve all display settings, not just some.** Hidden state is a display setting and is retained even though the pre-delta Reset code previously cleared it.
2. **Keep Reset available only for resettable changes.** Hiding a group alone does not offer Reset; Unhide remains the separate action.
3. **Do not remove the whole override table if display edits remain.** An empty name/pattern portion does not imply the entire saved group override is empty.
4. **Preserve the record of the mistake.** This correction supersedes the original full-reset implementation and its tests; it is not described as an inherent delta-storage requirement.

### Verification

All **21 headless cases** passed after the correction, including extended lifecycle and editor assertions. All addon Lua syntax checks and `git diff --check` passed.

The packaging suite's 187-assertion pass was from subtask 4; it was not rerun for this Reset-only correction. Native ESO acceptance remains pending.

## Current storage and API reference

The raw persisted shape is:

```lua
trackedRules = {
    builtin_slug = {
        displayName = "My name",
        display = { notify = false },
        addedPatterns = { "new pattern" },
        removedPatterns = { "removed baseline pattern" },
    },
    custom_slug = {
        displayName = "My custom group",
        addedPatterns = { "custom*" },
    },
}
```

Fields are optional. Missing built-in values inherit the installed baseline. Missing custom-group display flags inherit standard custom defaults. Raw pattern arrays are unique and sorted; effective lists are baseline minus removals plus additions, sorted.

Compiled patterns live only in the runtime cache. `GetActiveTrackedRules` provides private raw pattern/display views but shares compiled arrays by convention. All rule edits must use the mutation APIs or explicitly invalidate the cache.

The currently exposed rule-related APIs added by this work are:

| Method | Purpose |
|---|---|
| `UpdateRuleProperty` | Set/clear a name override. |
| `UpdateRuleFlag` | Set/clear one display-flag override. |
| `SetRuleFlag` | Compatibility alias for `UpdateRuleFlag`. |
| `UpdateRulePatterns` | Reconcile the full edited list into deltas. |
| `InvalidateRuleCache` | Mark runtime rules invalid. |
| `GetRuntimeRules` | Get all cached resolved/compiled rules. |
| `SetUseCharacterItemList` | Switch active lists and invalidate. |
| `ItemMatchesRuntimeRule` | Match an item using compiled patterns. |
| `CreateCustomRule` | Create a sparse custom group. |
| `DeleteCustomRule` | Delete a custom group. |
| `ResetRule` | Restore a built-in name/pattern list only. |
| `HasResettableRuleOverrides` | Determine whether Reset has name/pattern work to do. |

Existing `GetActiveTrackedRules`, `CopyProfile`, `GetMasterItemList`, and inventory-update handling were modified rather than replaced with new public entry points.

## How to reproduce automated verification

From the development checkout:

```powershell
python -m pip install lupa
python Project\Tests\Run-RuleTests.py
& .\Project\Publishing\Test-PackageRelease.ps1
git diff --check
```

The package install is needed only if `lupa` is not already available. These checks do not transfer inventory or modify live saved-variable files.

In ESO, `/ictest verbose` includes the fourteen shared cases alongside the existing suite. Fake UI and serialization harnesses are headless-only. Shared fixtures restore original runtime references after execution, including test failures.

## Remaining review and client acceptance

- Review automatic on-read migration, current-baseline reconciliation, pruning equal values, unchanged saved-variable version, and downgrade requirements.
- Back up saved variables before client migration testing.
- Verify native focus-loss behavior, HUD/notification updates, and exact persisted fields after a UI reload.
- Verify both list-switch controls, profile imports, custom lifecycle actions, and Reset preserving every display setting.
- Run `/ictest verbose` in the client and confirm timing thresholds on that environment.
- Test `/icclearoverrides` only on a disposable profile because it deliberately clears all overrides for that active list.

The [design and acceptance checklist](DeltaOnlySavedVariables.md) contains the detailed sequential pattern scenarios and client checklist. No claim is made that these native-client checks have been executed.
