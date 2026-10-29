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
| Ownership-boundary follow-up | Follow-up after `199df83` | Validates external saved rules and removes guards/fallbacks that hide maintained-code defects; see the final section. |

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
4. **Automatic legacy conversion (original decision, superseded by the versioned-startup follow-up below):** old `patterns` arrays were converted when active rules were resolved. Reading rules could therefore modify the active saved-variable table in memory; this was not a separate migration command.
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
6. **Originally keep the raw-rule compilation fallback.** This preserved the existing `GetMasterItemList` calling contract for supplied synthetic/raw rules. The ownership-boundary follow-up below supersedes this choice: scans now require compiled rules, and tests supply real resolved rules.
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
9. **Do not change the saved-variable namespace or version (original decision, superseded below).** Initially, legacy conversion occurred in the existing namespace without a version bump. The versioned-startup follow-up keeps the namespace but increments the ESO saved-variable version to 2 and adds pre-load downgrade refusal.
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

In ESO, `/ictest verbose` includes the twenty shared cases alongside the existing suite. Fake UI, serialization, and startup/version harnesses are headless-only. Shared fixtures restore original runtime references after execution, including test failures.

## Remaining review and client acceptance

- Review current-baseline reconciliation, pruning equal values, and the versioned startup migration/downgrade policy documented below.
- Back up saved variables before client migration testing.
- Verify native focus-loss behavior, HUD/notification updates, and exact persisted fields after a UI reload.
- Verify both list-switch controls, profile imports, custom lifecycle actions, and Reset preserving every display setting.
- Run `/ictest verbose` in the client and confirm timing thresholds on that environment.
- Test `/icclearoverrides` only on a disposable profile because it deliberately clears all overrides for that active list.

The [design and acceptance checklist](DeltaOnlySavedVariables.md) contains the detailed sequential pattern scenarios and client checklist. No claim is made that these native-client checks have been executed.

## Follow-up - saved-variable version and downgrade protection

The user approved preserving settings through explicit migration from ESO saved-variable version 1 to 2, remaining on `main`. The working tree was clean at `84dbc01`; this document records the plan before implementation.

### Subtasks

1. [x] Implement version-2 startup migration and pre-load downgrade refusal, with isolated unit tests. Validate every stored profile in the addon's `Default` namespace before publishing any migration; preserve unrelated settings. Newer or malformed versions must stop initialization before ZOS can reset or overwrite them.
2. [x] Update user/design documentation, run the focused rule and packaging checks, and record the results and remaining client checks.

Commit each completed subtask and append its changes/results here.

### Compatibility decision

The ZOS loader clears data when its stored version is missing or lower than the requested version, and assigns the requested version even when the stored version is higher. Therefore our check and data-preserving migration must run before either ZOS constructor. Version 1 profiles already converted by the earlier development implementation must also migrate without losing deltas. Already-released builds without this guard still cannot safely downgrade; restore a pre-migration backup instead.

Source verified during implementation: [ZOS saved-variable implementation](https://github.com/esoui/esoui/blob/master/esoui/libraries/utility/zo_savedvars.lua), `CreateExposedInterface`. This follow-up uses ESO's existing per-profile `version`, not an additional addon-owned schema marker.

### Subtask 1 completed - startup migration and tests

- [Core/Init.lua](../../../Core/Init.lua): increased `SettingsVersion` to 2; calls required `PrepareSavedVariables()` first, before string registration, ZOS constructors, and module initialization.
- [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua): added `PrepareSavedVariables()`. It checks every stored account/character profile in `Default`, including inactive characters and other accounts. Newer versions raise a contextual error with update/backup guidance. Malformed containers/versions also throw rather than being reset; existing unversioned profiles are rejected, while genuinely absent profiles remain normal fresh installations.
- Conversion reuses `NormalizeRule` and the shallow-copy helpers. It stages separate rule/display tables for every version-1 profile; only after all validation/conversion succeeds does it publish replacement rules and version 2. Items, unrelated settings, metadata, and other namespaces remain unchanged. Version-1 development data already containing deltas is supported. Version-2 data is validated but not remigrated.
- [Project/Tests/SavedVariablesTests.lua](../../Tests/SavedVariablesTests.lua): nine headless startup cases exercise the actual addon-loaded handler with a ZOS double reproducing its destructive version behavior. Coverage includes fresh installs, every stored profile, effective patterns/flags/items preservation, already-converted data, empty custom groups, idempotency/reload, dynamic expected-version refusal, malformed versions/containers/rules, broken maintained baselines, and missing optional legacy rules.
- [Project/Tests/Run-RuleTests.py](../../Tests/Run-RuleTests.py): runs the startup tests in their own Lua state, without live inventory or saved variables.
- Validation: 38/38 isolated tests pass; all addon Lua parses under Lua 5.1; `git diff --check` passes. Latest synthetic burst checks: 46/500 ms for scans, 0/100 ms for matches, 1/200 ms for updates.
- The guard throws before constructors/modules/UI setup, leaving `state.isLoaded` false. It does not silently continue, reset data, or implement an automatic downgrade conversion.

### Subtask 2 completed - documentation and final validation

- Subtask 1 implementation/tests committed as `a862f50`; the pre-work plan was committed as `306dfca`.
- [UserManual.md](../../../UserManual.md) explains the settings-preserving upgrade, inactive-profile scope, compatibility error, lack of automatic backup, and the need to restore a backup when reverting to builds without the guard.
- [DeltaOnlySavedVariables.md](DeltaOnlySavedVariables.md) now records the current versioned startup policy, future migration requirements, updated test inventory, and disposable-profile client acceptance checks. Earlier decisions here are explicitly marked superseded rather than silently rewritten as though they were original choices.
- Final verification also made the supported upgrade pair explicitly version 1 to 2, rather than allowing a version-1 conversion to stamp any future expected version. A tenth startup test raises the expected version to 3 and verifies refusal until that migration is implemented.
- Final validation: 39/39 isolated cases passed; addon Lua 5.1 syntax checks passed; 187 isolated packaging assertions passed without touching the live installation or saved variables. Whitespace and relative documentation links were checked.
- Remaining: verify native ESO error presentation, startup migration, persistence across reloads, and refusal using disposable higher-version profiles. No live saved-variable file or inventory was used for development checks.

### Native-client evidence retained for the future release review - 2026-10-28

- Tim supplied the [complete diagnostic report](../../Tests/Evidence/1.3.0-20261028-client-tests.txt): **78/78 passed**, release installation `InventoryCompanion`, runtime 1.3.0, DEV=false, AddOnVersion 10300. Environment: live build `eso.live.12.1.6.3309674`, API 101051, EU Megaserver, English, ESO Plus enabled, bank closed.
- Performance: synthetic scans 50/500 ms, slot-rule matches 0/100 ms, tracked-item updates 2/200 ms; 100 read-only live scans 332/500 ms with 1106 occupied entries. All reported thresholds passed.
- All 31 staged file hashes were independently checked against the staging records after receipt. Candidate SHA256: `AF8430F1232A06A6C4290117614BDBC1FA64B6106916C016D099FB24ECF057E5`. These results apply to that candidate, not unspecified later DEV changes.
- After Tim's UI reload, both on-disk installation saved-variable files were written at approximately **17:25:31 UTC**. A read-only comparison with the pre-staging backups confirmed all 11 profiles at version 2, no missing original profiles, no legacy pattern lists, six added-pattern lists, four removed-pattern lists, and no persisted runtime rule fields.
- Every profile's saved rules exactly matched the expected conversion of its pre-staging backup using the production migration/current baseline. No unrelated profile fields, including tracked items, changed. Private saved data and account/character identifiers are not copied into this record.
- This supplies native startup/reload-persistence evidence and the full diagnostic run for later review. It does **not** prove native higher-version refusal/error presentation, visual/editor behavior, actual transfers, or every other release-review requirement.
- No review, approval, finalization, or publication was performed. Reuse this evidence when reviewing the unchanged staged 1.3.0 candidate; repeat affected checks only if candidate changes or findings justify it.

## Follow-up - fail-fast internals and saved-data ownership boundary

The user clarified the project-wide rule: defensive checks belong at boundaries with code/data we do not maintain. ZOS and dependent addons are examples. Our saved data also crosses a boundary because users can edit it outside the addon. Within maintained code, required functions and state must not be hidden behind guards or silent fallbacks.

### Baseline and scope

- The working tree was clean at `199df83`; no extra pre-work checkpoint was needed.
- Work remained on `main`, without a branch switch.
- This follow-up covers the delta-rule database and its editor/settings/import/clear consumers. It is not a claim that every unrelated pre-existing addon subsystem has been audited.
- The persisted schema and Reset semantics are unchanged.

### Files and methods changed

| File | Changes |
|---|---|
| [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) | Added boundary and internal contract helpers; removed custom-default fallbacks for broken built-in definitions and the raw-rule scan compilation fallback. Tightened profile import before destination replacement. |
| [Core/Init.lua](../../../Core/Init.lua) | Calls `ValidateSavedRuleProfiles` immediately after ZOS saved-variable loading, before module initialization. The clear command directly calls required refresh functions. |
| [Tracking/EditPanelGroupsTab.lua](../../../Tracking/EditPanelGroupsTab.lua) | Direct calls to required addon methods; explicit missing-control/payload errors; removed name/pattern fallbacks for required resolved fields. |
| [Tracking/EditPanelItemsTab.lua](../../../Tracking/EditPanelItemsTab.lua) | Direct required-method calls in import, list-switch, scene, and toggle paths; required import/scroll controls fail explicitly; resolved rule names no longer fall back to slugs. |
| [Core/Settings.lua](../../../Core/Settings.lua) | Character-list changes directly call required editor/HUD refresh methods. |
| [Core/Tests.lua](../../../Core/Tests.lua) | Synthetic scans use real resolved/compiled rules instead of depending on production fallback behavior. Built-in fixtures supply all required baseline fields. |
| [Core/RuleTests.lua](../../../Core/RuleTests.lua) | Added six boundary/internal-failure cases, retaining isolated fixture restoration. |
| [Project/Tests/GroupEditorTests.lua](../../Tests/GroupEditorTests.lua) | Added actual handler checks for missing maintained methods, missing required controls, and invalid internal dialog data. |
| [Project/Tests/RulePersistenceTests.lua](../../Tests/RulePersistenceTests.lua) | Added an actual production-baseline contract check and provided required refresh stubs for clear-command tests. |
| [Project/Tests/Run-RuleTests.py](../../Tests/Run-RuleTests.py) | Supplies the production constants source to the isolated baseline test. |
| [DeltaOnlySavedVariables.md](DeltaOnlySavedVariables.md) | Records the updated boundary policy and current verification commands/counts. |

New helpers/API in the database:

- **`CheckPatternList(patterns, context)`** requires a dense, positive-integer-indexed array of strings. Holes, named keys, non-string elements, zero/negative/fractional indices, and non-table values fail at validation.
- **`ValidateSavedRules(rules, context)`** validates rule keys, rule tables, optional names, legacy/delta lists, and known boolean display flags. It is a read-only check.
- **`LoadSavedRules(profile, context, initializeMissing)`** validates each newly encountered saved-rule table. A weak-key in-memory set avoids revalidating the same trusted table on each consumer access.
- **`ValidateSavedRuleProfiles()`** is the public initialization entry point. Checks both account and character rule profiles, even when one is inactive, and validates the character-list preference.
- **`GetBaseline(ruleName)`** enforces maintained built-in definitions: string name, dense pattern list, and all six boolean display flags. Runs before baseline-dependent mutations and before cache normalization.
- **`GetDisplayDefaults(base)` / `GetDefaultName(ruleName, base)`** explicitly distinguish a custom group from an existing built-in definition. A broken built-in definition cannot silently become a custom default.
- **`CopyOptionalValues(values)`** handles legitimately absent imported fields; ordinary `CopyValues` now requires its table argument.

### Decisions made

1. **Reject malformed saved rules rather than guess a repair.** Invalid present data throws a contextual Lua error naming the account/character/import profile, rule key, and field. Initialization/import stops; malformed entries are not silently skipped, reset, or replaced with success-shaped defaults. The boundary exception permits deliberate recovery but does not require guessing at user intent.
2. **Preserve evidence and unrelated data.** Validation does not delete malformed entries. Validated legacy conversion still applies afterward. Source import validation occurs before clearing destination items/rules, and unrelated saved fields are preserved by active-profile normalization.
3. **Treat missing and malformed differently.** Missing optional name/display/delta fields still inherit defaults. A missing `trackedRules` table can be initialized at the explicit loading boundary. Losing that required table later in maintained code throws instead of recreating it silently.
4. **Validate inactive rules during initialization.** Corruption in the inactive account/character rule list is reported before module initialization rather than surfacing only when the user switches lists.
5. **Validate newly encountered table identities once.** Explicit loading validates both profiles; first access also validates newly supplied/replaced rule tables, including test fixtures. Subsequent in-memory edits are our code's responsibility and must use the mutation APIs. There is no repeated defensive schema pass in matching/scan loops.
6. **Check complete baselines before migration.** A malformed built-in definition raises a maintained-code error before cache rebuilding normalizes saved overrides. This avoids converting valid legacy lists against an incomplete built-in definition.
7. **Strengthen internal entry contracts.** Pattern setters reject sparse/dictionary input before writing. List switching requires a boolean. No fallback masks missing compiled rule data in scans.
8. **Fix tests to meet production contracts.** Synthetic raw-rule callers were changed to construct real resolved rules, not retained as a reason to silently compile missing runtime fields in production.
9. **Remove guards around our own code.** Required refresh/layout functions are called directly. Missing editor controls and missing Reset dialog IDs produce explicit errors. Group-name/pattern views rely on the resolved cache contract.
10. **Keep legitimate control flow.** No selected group, no matching item, empty external inventory slots, no source profile found, optional saved overrides, and empty custom groups remain valid cases. Test catches still restore fixtures and report/rethrow failures.
11. **Do not broaden tracked-item migration.** Import checks item container/entry/display-table shapes before replacement because they are part of the same transaction, but this follow-up does not introduce a new full tracked-item schema or alter existing legacy item-mode semantics.

### Verification

- **29/29 headless cases pass:** twenty shared rule cases, six actual group-editor handler cases, and three production-baseline/persistence/command cases.
- Malformed saved cases include false/scalar containers, invalid keys/names/flags, unknown display flags, sparse/named arrays, and invalid pattern elements. Tests verify failed imports retain the destination and leave source data available for repair.
- Internal failure cases verify invalid list switches, missing built-in fields, absent compiled scan rules, missing required refresh functions/controls, and invalid Reset dialog payloads.
- The actual production built-in definitions pass the strict contract, and existing delta, Reset, serialization, notification, and burst tests still pass.
- All addon Lua sources parse under Lua 5.1; `git diff --check` passes.
- The existing isolated packaging suite passes **187 assertions**, without modifying live installations or saved-variable files.
- A reference run measured 50 ms for twenty 100-item/twenty-rule scans, 0 ms at millisecond resolution for 100 matches, and 0 ms for 100 updates, all below existing thresholds. These are host measurements, not ESO-client evidence.
- Native ESO initialization, focus/event behavior, saved-file reload persistence, and real-client timings still need client acceptance.
