# AutoCategory integration: investigation and implementation

Status: Design input, not implemented or compatibility-certified.

Product scope and unresolved decisions: [Plan](todo_plan_autocategoryIntegration.md).

## Evidence scope

Read-only inspection on 2026-10-30 of the locally installed sibling `AutoCategory` addon and the current Inventory Companion DEV checkout. The installed AutoCategory version number has not been established in this investigation. Recheck its manifest/version and the cited contracts before coding; do not assume all AutoCategory releases expose identical internals.

AutoCategory references below are relative to this document and point outside our repository to the installed addon. They are evidence/navigation, not files we should modify.

## Confirmed extension points

### Register a custom matching predicate

[`Plugin_API.lua`](../../../../AutoCategory/Plugin_API.lua) exposes:

```lua
AutoCategory.AddRuleFunc(name, func)
AutoCategory.RegisterPlugin(name, initfunc, predefined)
```

`AddRuleFunc` installs a function into `AutoCategory.Environment`, which is the environment used to execute its compiled rule expressions. An omitted function becomes AutoCategory's always-false dummy. Our adapter should supply a real function and must not use that dummy to hide a broken internal contract.

`RegisterPlugin` records an initializer and optional predefined rules. Predefined rules are marked `pred=1`. This confirms predicate/plugin registration, not a complete supported CRUD API for assigning arbitrary dynamic groups to bags.

The installed [`DressingRoom2018_Plugin.lua`](../../../../AutoCategory/plugins/DressingRoom2018_Plugin.lua) is concrete prior art: it registers `drm_inset`, inspects the current bag/slot, and registers its initializer. Other bundled plugins use the same pattern.

### Per-item evaluation and first-match semantics

[`AutoCategory_API.lua`](../../../../AutoCategory/AutoCategory_API.lua), `MatchCategoryRules`, sets:

```lua
self.checkingItemBagId = bagId
self.checkingItemSlotIndex = slotIndex
self.checkingItemLink = GetItemLink(bagId, slotIndex)
```

It evaluates compiled rules in bag-rule order, using `AutoCategory.Environment`, and returns immediately on the first true result. Return values include match status, category name, run priority, show priority, bag type, and hidden state.

Consequences:

- The bridge can inspect the current item link without a full inventory scan.
- Each item receives one winning partition, unlike our overlapping group summaries.
- Run order and display order are separate concerns.
- AutoCategory catches expression failures, marks the rule damaged, and removes its compiled function. Do not add a second broad catch that conceals our failures; ensure external error status is visible to users.

`AdditionCategoryName` can append a dynamic suffix, but the result depends on AutoCategory's global `SHOW_CATEGORY_SET_TITLE` setting and special bag handling. Do not rely on it for exact Inventory Companion group labels without a deliberate compatibility decision.

### Initialization order matters

[`AutoCategory.lua`](../../../../AutoCategory/AutoCategory.lua), `onPlayerActivated`, loads plugin predefines, combines rules, selects current saved variables, calls plugin initializers, initializes caches/menu/classes, then sets `AutoCategory.Inited = true`.

An adapter that calls `RegisterPlugin` after that pass will not automatically receive the already-completed initialization/predefine loading. Establish deterministic load ordering and readiness before choosing the registration path. Do not assume an optional dependency alone guarantees that our saved rules are ready when AutoCategory initializes.

### Rule storage, compilation, and bag assignment are distinct

Observed in [`AutoCategory.lua`](../../../../AutoCategory/AutoCategory.lua):

- `RulesW:AddRule(newRule, overwriteFlag)` updates combined lookup/tag structures and compiles a rule.
- `cache.AddRule(rule)` updates rule-list/cache structures; its comment says nil means success and an error string means failure.
- `cacheInitBag`, `cacheBagInitialize`, and `cacheInitialize` rebuild derived bag structures.
- `saved.bags[acBagType].rules` holds bag assignments, including `name`, `runpriority`, `showpriority`, and `isHidden`.
- `GetRuleByName` and `GetBagRuleByName` provide lookups.

[`AC_Classes.lua`](../../../../AutoCategory/AC_Classes.lua), `RuleApi.compile`, compiles `"return(" .. rule.rule .. ")"` through `zo_loadstring`. `BagRuleApi` includes priority normalization and backing-rule lookup, but the inspected portion does not establish a general public add/remove assignment operation.

[`settings/BagSet.lua`](../../../../AutoCategory/settings/BagSet.lua) contains the actual add/remove/priority UI paths, notably `AddCat_BagAdd_LAM:execute`, `bagSet_RemoveCat_LAM:execute`, and the run/show priority setters. Their complete mutation and cache-refresh paths still need tracing before implementation.

**Important:** registering a predicate or predefined category does not by itself prove it will be assigned to backpack/bank or safely removed later.

### Refresh support

`AutoCategory.RefreshList(inventoryType, even_if_hidden)` and `RefreshCurrentList(even_if_hidden)` exist in [`AutoCategory.lua`](../../../../AutoCategory/AutoCategory.lua). The latter iterates multiple inventory/crafting contexts, and some refresh branches have visibility-specific behaviour. Prefer the narrow supported inventory refresh after verifying argument semantics; do not call the broad helper on every item.

## Inventory Companion code to reuse

[`Tracking/ItemDatabase.lua`](../../../Tracking/ItemDatabase.lua):

- `GetRuntimeRules()` owns cached effective rules with compiled patterns.
- `ItemMatchesRuntimeRule(itemLink, rule)` gets the item name, lowercases it, and tests the compiled patterns.
- `InvalidateRuleCache()` is the existing mutation boundary; inspect its full callers before adding synchronization.
- `GetActiveTrackedRules()` returns view copies, filtering hidden groups by default; avoid allocating those copies per item.
- `SetUseCharacterItemList`, `UpdateRuleFlag`, `UpdateRuleProperty`, `UpdateRulePatterns`, `CreateCustomRule`, `DeleteCustomRule`, `ResetRule`, and `CopyProfile` are relevant synchronization surfaces.

Do not invoke `GetMasterItemList()` from AutoCategory's per-item evaluation. Its inventory snapshots are unnecessary for name-pattern matching.

[`Tracking/ItemTrackerPanel.lua`](../../../Tracking/ItemTrackerPanel.lua) constructs Miscellaneous by folding certain single-member/ungrouped/individually tracked items into a presentation group. That is not equivalent to matching a normal rule's patterns. Do not export the HUD's transient display model as the integration's rule source.

## Proposed code shape

### Existing reorder interaction to copy

The author requests the existing currency settings move mechanic, not a new drag/drop or numeric-only interface. In [CurrencyPanel.lua](../../../Tracking/CurrencyPanel.lua), `CreateResourceSettingsRow` creates per-row up/down `ZO_DefaultButton` controls (28 by 26), with explanatory hover tooltips and click sound. On click, `MoveResource` swaps adjacent shown entries, `SaveSettingsRowOrder` persists order, the settings list is reordered, the moved row is highlighted, and the currency panel refreshes.

Copy this interaction/style for group-editor ordering, adapting its data handling rather than calling currency-specific helpers. Provide Alphabetical / Tracker order / AutoCategory views. In the AutoCategory view, require an inventory dropdown (Backpack / Bank) and an ordering dropdown (Rule precedence / Display order); exact UI composition remains open. Keep tracker order, AutoCategory precedence, and AutoCategory display order distinct. Switching views/dropdowns alone must not change stored orders. Reuse the highlight/keep-visible behaviour where applicable. Decide movement across filtered or nonparticipating groups explicitly: the currency implementation operates on shown resources, which is not automatically the correct group-editor policy. Verify boundary-button state and maintain stable row keys during refresh. Drag/drop and a numeric rank field are not required for the initial design.

Tracker ordering is a separate capability, not a requirement to couple AutoCategory priority to tracker display position. Do not expand the first row-options refactor into this ordering implementation.

Keep the first implementation in one focused module, provisionally `Tracking/AutoCategoryIntegration.lua`, plus direct wiring in existing initialization/settings/mutation surfaces. Exact names are provisional, not new established APIs.

1. **Activation boundary:** detect AutoCategory presence and readiness, validate the specific functions/data contracts the selected strategy uses, and report unsupported versions/contracts explicitly. Absence is an ordinary optional-dependency condition.
2. **Predicate bridge:** register a namespaced expression function such as `ic_group(ruleKey)`. Resolve a validated rule key against cached runtime rules and evaluate the current item's link with `ItemMatchesRuntimeRule`.
3. **Managed category projection:** derive a stable ordered set of participating groups and display labels. Build expressions with correctly escaped Lua string literals, never raw display-name interpolation. Keep ownership separate from editable labels.
4. **Lifecycle adapter:** reconcile only our owned definitions/assignments using verified registration, compilation, bag assignment, removal, and cache operations. Do not overwrite another rule on a name collision.
5. **Synchronization:** invalidate/rebuild the projection once per relevant change/burst and request a bounded inventory refresh. Keep matching read-only. Track our rule/profile changes and AutoCategory's own profile selection/reset paths.
6. **Settings:** opt-in flag and clear compatibility status; decide account/character scope and missing-field default. Validate any new saved fields at the existing loading boundary.
7. **Manifest/init:** add the module and optional dependency/load ordering only after verifying the actual installed manifest identity and lifecycle. Register functions before any category expression can execute.

A logical expression might be `ic_group("pvp")`; this is illustrative only. It must not be placed into users' AutoCategory rules until activation, persistence, and removal behaviour are established.

## Required technical spike before committing to storage strategy

- [ ] Read AutoCategory's manifest and establish the version/dependency identity.
- [ ] Trace full add/delete/rename and bag-assignment paths, priority comparator direction/ties, backing-rule persistence, and cache compilation semantics.
- [ ] Test whether the selected bag's built-in/user-created categories can be shown and safely reordered alongside our groups, separately for run precedence and display order. Leave external expression editing, visibility/participation semantics, source presentation, and editor navigation as open questions until tested; see the plan's combined-view questions.
- [ ] Establish whether transient runtime-only definitions AND assignments survive cache rebuild/profile switches safely.
- [ ] If persistence is necessary, define explicit ownership and reload-safe cleanup without touching unrelated profiles/settings.
- [ ] Decide what happens when Inventory Companion is disabled/uninstalled but persisted expressions remain. A broken or silently false stranded expression is not an acceptable unexplained result.
- [ ] Establish registration timing both when AutoCategory is ready first and when our data is ready first.
- [ ] Verify keyboard and gamepad consumption of these categories separately; do not claim gamepad support from keyboard-only inspection.
- [ ] Demonstrate one category assigned to backpack/bank, falling through for a non-match, and removed cleanly in isolated fixtures before live opt-in.

If runtime-only lifecycle is unsafe and persisted ownership cannot be made reversible, stop and present the limitation. A hook replacing `MatchCategoryRules` is a different, more fragile design and requires explicit discussion, preservation of its complete return contract, and compatibility tests; it is not the default shortcut.

## Test implementation

Use the existing Lua 5.1 isolated runner and a narrowly scoped AutoCategory fixture rather than importing a full dependent addon into the tests. Test:

- Missing dependency, not-ready dependency, and incompatible contract notification.
- Predicate true/false agreement with actual compiled Inventory Companion matching.
- Deterministic overlap order, special-character rule keys/labels, empty patterns, and collision handling.
- Rename/delete/reset/import and both addons' profile changes.
- Repeated enable/synchronize/disable cycles: no duplicates, idempotent cleanup, no unrelated mutations.
- No inheritance of HUD collapse or automatic height layout decisions.
- Exact zero inventory-scan calls during classification; bounded compilation and refresh counts per configuration burst.
- Errors from required internal functions/state propagate rather than turning into unmatched-item success.
- Saved-field normalization and owned-data preservation if the chosen design introduces persistence.

Then perform the real UI/performance checks in the linked plan. Do not infer correctness or real ESO API costs from fast mock execution.
