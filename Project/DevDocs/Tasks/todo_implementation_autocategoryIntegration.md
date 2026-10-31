# AutoCategory integration: implementation plan

Status: Planned, not implemented or compatibility-certified. Updated on
2026-10-31 with confirmed combined ordering, read-only external filters,
managed-first initial placement, scoped participation, hidden inactive UI, and
accepted defaults. After the spike, native insertion was chosen and
AutoCategory's own bag lists became the order record (stage 2).

Behavior, accepted defaults, and remaining technical gates are in the
[feature spec](todo_plan_autocategoryIntegration.md). This document follows
implementation order: external lifecycle verification, saved representation,
managed predicate, adapter synchronization, editor, then completion checks.
Proposed new field/helper names below are implementation targets, not APIs
that already exist.

## 1. Verify the external lifecycle before projecting categories

### Evidence and existing extension points

The original read-only inspection was on 2026-10-30. It did not establish the
installed AutoCategory version or certify a complete category CRUD lifecycle.
On 2026-10-31, its bag mapping was rechecked: Backpack and Bank are distinct
contexts, and subscriber bank maps to Bank. Other mapped contexts do not
automatically imply tested integration support.

AutoCategory links below point outside this repository to the installed addon;
they are read-only evidence, not modification targets.

- [Plugin_API.lua](../../../../AutoCategory/Plugin_API.lua) exposes
  `AutoCategory.AddRuleFunc(name, func)` and
  `AutoCategory.RegisterPlugin(name, initfunc, predefined)`. The former installs
  the function in `AutoCategory.Environment`; omitting the function installs an
  always-false dummy. Supply the real bridge, never that dummy to mask a defect.
  Plugin predefines (`pred=1`) do not establish dynamic bag assignment/removal.
- [DressingRoom2018_Plugin.lua](../../../../AutoCategory/plugins/DressingRoom2018_Plugin.lua)
  is bundled prior art for a predicate using current bag/slot context.
- [AutoCategory_API.lua](../../../../AutoCategory/AutoCategory_API.lua),
  `MatchCategoryRules`, sets `checkingItemBagId`, `checkingItemSlotIndex`, and
  `checkingItemLink`, evaluates compiled bag rules, and returns on the first
  true result. Its result includes category name, run/show priorities, bag type,
  and hidden state. Rule failures are caught externally and mark rules damaged;
  do not add another catch concealing our failures.
- The same file maps `BAG_BANK` and `BAG_SUBSCRIBER_BANK` to
  `AC_BAG_TYPE_BANK`. `BAG_BACKPACK` maps to `AC_BAG_TYPE_BACKPACK`. Restrict our
  initial acceptance to the specified inventories, not every mapped view.
- [AutoCategory.lua](../../../../AutoCategory/AutoCategory.lua),
  `onPlayerActivated`, loads plugin predefines, combines rules, selects saved
  variables, calls initializers, initializes caches/menu/classes, and finally
  sets `AutoCategory.Inited`. Late plugin registration does not rerun that pass.
- In that file, `RulesW:AddRule`, `cache.AddRule`, `cacheInitBag`,
  `cacheBagInitialize`, and `cacheInitialize` touch different definition/cache
  layers. `cache.AddRule` documents nil success/error-string failure.
  `saved.bags[acBagType].rules` holds assignments with `name`, `runpriority`,
  `showpriority`, and `isHidden`; lookups include `GetRuleByName` and
  `GetBagRuleByName`.
- [AC_Classes.lua](../../../../AutoCategory/AC_Classes.lua),
  `RuleApi.compile`, compiles `return(<expression>)` through `zo_loadstring`.
  `BagRuleApi` exposes backing-rule/priority operations but is not yet evidence
  of a complete supported add/remove API.
- [settings/BagSet.lua](../../../../AutoCategory/settings/BagSet.lua) contains
  `AddCat_BagAdd_LAM:execute`, `bagSet_RemoveCat_LAM:execute`, and run/show
  priority setters. Trace their complete mutation/refresh paths.
- `RefreshList(inventoryType, even_if_hidden)` and
  `RefreshCurrentList(even_if_hidden)` are in
  [AutoCategory.lua](../../../../AutoCategory/AutoCategory.lua). Verify narrow
  refresh arguments; the latter spans many inventory/crafting views.
  `AdditionCategoryName` depends on `SHOW_CATEGORY_SET_TITLE` and bag handling,
  so it is not a proven exact-label solution.

### Minimum viable native-insertion probe

Before integration scaffolding, run
`python Project\Tests\Run-AutoCategorySpike.py`. The standalone
[runner](../../Tests/Run-AutoCategorySpike.py) reads the installed dependency
modules without copying them into this repository or accessing game saves.
[AutoCategorySpikeTests.lua](../../Tests/AutoCategorySpikeTests.lua) supplies
isolated ESO/library boundaries and synthetic Plunder Skull state. Registration,
rule compilation, cache sorting/rebuilds, and classification execute the actual
AutoCategory implementation, using our real compiled rule matcher.

Current result on 2026-10-31: **15/15 tests passed** against installed
`AutoCategory.addon` version **4.5.2**, AddOnVersion **134**. Higher AutoCategory
`runpriority` runs first; our derived rank 1 means most important, so projection
must translate rather than assign the same numeric rank as run priority.
Native runtime insertion works in these isolated fixtures without replacing
`MatchCategoryRules`, including Bank/subscriber-bank mapping, external entries
between managed entries, a full cache rebuild, no-match fallthrough, and cleanup.
This establishes a candidate path, not a supported dynamic public CRUD API.

For the user's real Plunder Skull, reload DEV with AutoCategory enabled and run
`/icacspike` (or `/icacspike <item-name substring>`). The DEV-only
[Core/AutoCategorySpike.lua](../../../Core/AutoCategorySpike.lua) finds one
backpack item read-only, discovers its actual AutoCategory baseline and matching
Inventory Companion group (preferring Witches), then tests:

1. Spike A / existing Container category / Spike B: A wins.
2. Existing Container category / Spike A / Spike B: Container wins.
3. Spike B / existing Container category / Spike A: B wins.
4. Full cache rebuild retains that temporary order.

At the user's request, successful execution intentionally opens ESO's copyable
error window with the full report, headed `DIAGNOSTIC REPORT` / `not a test
failure`. This occurs only after runtime state is restored. Missing/disabled
dependency messages remain ordinary chat status; real probe failures still throw.

The command uses the actual baseline category name, not a hardcoded spelling.
Both test entries reuse the selected group's real matcher; this minimal probe
tests registration/precedence, not two distinct production groups.
It copies runtime state before running classification/cache operations, restores
original table references, predicate/compiled state, item context, and IC profile
references before returning, and rethrows failures after cleanup. The standalone
suite exercises this same command on success and injected external failure.
This cleanup protects test isolation; it is not production move rollback logic.

No item transfers, saved-variable writes, installed-source edits, or persistent
test categories are performed. The command deliberately substitutes the
dependency's settings display-list control during the probe so its cache builder
cannot alter the live settings UI. It does not refresh the visible inventory.
The user's first missing-addon check exposed an assertion instead of ordinary
optional-dependency reporting. The slash-command boundary now prints one useful
message and does not run the probe when AutoCategory is absent, disabled,
initializing, or exposes an incompatible namespace; isolated coverage passes.
The enabled in-game run then exposed an incorrect table-only check for the
dependency's display-order window, which can be an ESO userdata control. Removed
that unnecessary check: the probe temporarily substitutes the window and restores
its original reference without invoking it. Added userdata restoration coverage.
In-game evidence on 2026-10-31: the user supplied the complete diagnostic report
for `Dremora Plunder Skull, Public & Sweeper`. Its existing category was
`Container`; the selected matching IC rule was `Test group`, not Witches.
All three mixed orders returned their expected winners:
Spike A / Container / Spike B => Spike A;
Container / Spike A / Spike B => Container;
Spike B / Container / Spike A => Spike B.
The full cache rebuild also passed, with three predicate calls reported.
Original runtime state was restored before the copyable report. This confirms
native insertion and mixed precedence in game for the selected item and matcher;
it does not certify Witches specifically or two distinct production groups.
Updated missing-addon behavior still awaits explicit confirmation.

### Next in-game test: bounded Backpack rendering

Reload DEV, use keyboard inventory, open Backpack with no item search/filter
excluding the skull, and run `/icacspike render`. The command repeats the proven
classification checks. The DEV **Debug Key** now invokes that same rendering
command instead of its usual full diagnostic suite, at the user's request.
This temporary binding override lives only in the DEV probe module.
The rendering command repeats the proven
classification checks, restores all original Backpack assignments into its
isolated projection, prepends two temporary managed assignments with Spike B
winning, then invokes `AutoCategory.RefreshList(INVENTORY_BACKPACK, true)`.
Other categories remain assigned. It verifies that the resulting real scroll
list contains both a Spike B header and the chosen item's Spike B row.

Original addon rule/cache/profile state is restored synchronously before the
copyable report appears. Only the rendered list remains temporary. A normal
Backpack refresh is scheduled after 20 seconds, using original state; no test
predicate remains installed during that window. Close the diagnostic report
promptly and observe `InventoryCompanion Spike B`. Do not click its temporary
header/collapse control or change settings; such UI interactions are outside the
probe. Ordinary inventory refreshes may end the preview earlier.

Acceptance: the skull visibly appears under Spike B, other categories remain
normal, and it returns to Container after the scheduled redraw. The rendering
test's offline coverage mocks the refresh/scroll-list boundary and verifies
restoration and scheduled redraw; it does not certify ESO rendering.
User-reported visual results are pending. Startup/profile/reload persistence
remain separate future tests.

First visual result on 2026-10-31: the user reported every inventory item under
the spike category. The selected `Test group` is the user's deliberate
"match too much" fixture (pattern `*`), so placing everything there was correct
for that group. An interim fix restricted the predicate to the exact selected link.

Second visual result on 2026-10-31: the report and screenshots showed only
`Dremora Plunder Skull, Public & Sweeper` under Spike B. Container still held
the other six plunder skulls (three gold Dremora, three purple `Plunder Skull`).
All other categories were unchanged. Header/item placement and external category
retention are confirmed visually. The one-item scope was a test artifact, not a
matching failure. Neither saved-variable file contained a Witches or plunder group.

Current probe: it no longer reads user groups. It creates a temporary
`*<search>*` group (default `*plunder skull*`) in the copied tracked lists,
using the real create/update/runtime-compile/matcher path. Real user groups and
saved data are untouched. The predicate matches by that group for every item.
The live-list check requires every listed item to be under Spike B exactly when
it matches the group, and reports both counts. Offline coverage uses the real
matcher with two matching skulls and one unrelated item. Expected rerun: all
seven skulls under Spike B; everything else unchanged; normal view after 20s.

Isolation defect found in game on 2026-10-31: the first run of that build wrote
`ic_acspike_group` ("Spike Group", `*plunder skull*`) into the user's real IC
group list. A second press then failed with "Rule already exists".
Cause: `ZO_SavedVars` interfaces are empty proxies whose metatable forwards
reads and writes to the raw table (`__index = current`). The probe's deep copy
preserved that metatable, so the "copied" profiles still wrote to live data.
Earlier probe builds only read IC rules, so they were unaffected; AutoCategory's
`saved` is a plain table and was isolated correctly. Fix: profiles are detached
by copying the raw table behind the proxy (asserting the ZOS shape), without the
proxy metatable. The probe also removes the leaked key from both real profiles
once, reports `REPAIRED`, and states that its only write is that repair.
The offline fixture now uses ZO_SavedVars-shaped proxies and compares raw saved
tables. Restoring the old copy reproduces the in-game leak (3 failures); the fix
passes 16/16. **Lesson for production code:** never clone ZO_SavedVars interfaces
by `pairs` or by metatable reuse; work with the raw table or explicit fields.

Rendering result on 2026-10-31 (fixed build): the report began `REPAIRED`, having
removed the leaked group from the real account list (the character list was
clean). All three mixed orders and the cache rebuild passed again. The live
Backpack list check passed: **all 7 matching skulls under Spike B; 11 other items
kept their categories**. Visible native section rendering with a group-wide
managed matcher is now proven for keyboard Backpack. The user then confirmed the
visual check passed, including the scheduled return to normal categories. The
one-off repair code and its test were removed afterwards; the proxy-shaped
isolation tests remain as the regression guard.

**Actual section
rendering, plugin startup, external-profile switching, and reload/uninstall
persistence are not certified by these tests.** Agree a safe rendering probe
after classification succeeds; do not leave experimental expressions persisted
just to obtain a screenshot.

### Remaining spike tasks and exit gate

Status after the Backpack rendering pass (2026-10-31):
- **Answered:** native insertion works, mixed external/managed order decides the
  winner, cache rebuilds keep it, and keyboard Backpack renders it. Native
  insertion is the chosen strategy; classification ownership is not needed.
- **Code findings, not yet tested in game:** `AutoCategory.RegisterPlugin(name,
  init, predefined)` is the supported registration path. Plugin predefined
  definitions are rebuilt every session and never written to `AutoCatRules`.
  `onPlayerActivated` runs plugin `init` after profiles are selected
  (`UpdateCurrentSavedVars`) and before the first `cacheInitialize`. That suits
  definitions registered at our `EVENT_ADD_ON_LOADED`, provided AutoCategory
  is an optional dependency so it loads first. Bag **assignments** are different:
  `saved.bags` is AutoCategory's own saved profile data (account or character),
  so any assignment present at logout is persisted by AutoCategory.
- **Decided (author, 2026-10-31):** AutoCategory's own assignments are the
  order record (option 1). Order follows AutoCategory's account/character
  profile and is equally editable in its own settings window. See stage 2.
- **Remaining gates:** (1) ~~offline: absent definition~~ **passed 2026-10-31**
  with the real modules (17/17). A persisted entry with no definition is skipped
  by `MatchCategoryRules`; other categories classify normally, and AutoCategory's
  settings list shows it as red `(!)` with its "category missing" tooltip. A
  definition whose `ic_group` function is absent fails inside AutoCategory's
  pcall: the rule is marked damaged and dropped for the session, then falls
  through. Consequences: always register `ic_group` before definitions; while IC
  is loaded but integration is off, keep registering definitions with a
  predicate returning false, avoiding `(!)` rows. Disabling or uninstalling IC
  leaves harmless `(!)` rows the user can delete in AutoCategory settings.
  Document that in the manual. (2) in game: plugin registration plus
  assignment survives `/reloadui` and classifies in Backpack and Bank;
  (3) AutoCategory account/character profile switch. Gamepad stays out of
  scope unless verified.

Original task list:
- Establish actual manifest identity, version, dependency requirements, and
  registration timing with either addon becoming ready first.
- Trace add/delete/rename/assignment, compilation, run-priority comparator/ties,
  show-priority separation, cache rebuild, and profile switch/reset paths.
- Demonstrate one category in Backpack and Bank, nonmatch fallthrough, rename,
  removal, and repeated synchronization in isolated fixtures.
- Test runtime-only definitions AND assignments across cache rebuilds/profile
  switches. If persistence is necessary, specify owned-data identity and safe
  disable/reload/uninstall handling without stranded `ic_group` expressions.
- Prove native insertion into AutoCategory's bag-rule list, initially above its
  existing categories with their relative order retained. Demonstrate moving an
  external category above, between, and below our groups, and verify actual
  first-match classification follows each combined order. Trace run-priority
  normalization; do not change show priority, expressions, or hide state.
- If native insertion cannot work, investigate taking responsibility for the
  complete combined classification dispatch, not just managed matches. Document
  external expression/environment behavior, damage/error handling, complete
  return tuple, no-match behavior, hidden rules, supported inventories, context
  side effects, coexistence with other hooks, and clean unhook/disable. Preserve
  AutoCategory rendering. Present evidence and risks for author approval before
  implementing that materially different strategy.
- ~~Establish one authoritative account-wide mixed-order record per inventory.~~
  Superseded 2026-10-31: AutoCategory's active bag lists are the order record
  (stage 2). Still verify AutoCategory profile compatibility, external edits,
  new-group insertion, and character-specific participation.
- Establish names/collision/manual-edit reconciliation and verified keyboard /
  gamepad scope. External definitions/filters are read-only in Phase I; only
  their selected-context ordering is editable here.

Record concrete contracts, ordering storage, and the chosen strategy here before
dependent storage/runtime work. Native insertion is preferred; classification
ownership needs explicit approval after the spike. Stop if neither strategy is
safe. Do not silently substitute a managed-only list or an unapproved
`MatchCategoryRules` replacement.

## 2. Save participation; read and write order through AutoCategory

Decided 2026-10-31 (author approval after the spike): **AutoCategory's active
bag-rule list is the only order record.** Inventory Companion stores no copy of
the order and no rank field. The earlier shared account-wide order record,
projection, and nonparticipant-position storage are withdrawn.

### Representation

[Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) stores rule
overrides under the active profile's `trackedRules[ruleKey]`; the stable rule
key survives display-name edits. Add optional participation directly to each
saved rule, separate from `display`:

```lua
trackedRules = {
    maps = { autoCategoryEnabled = true },
    cyrodiil = { autoCategoryEnabled = true },
}
```

- Missing `autoCategoryEnabled` resolves false; use sparse writes. Participation
  applies to every supported inventory context.
- Add `autoCategoryIntegrationEnabled`, default false, to both account and
  character tracked-list profiles, resolved through the existing
  `useCharacterItemList` choice. Do not add an independent integration profile
  mode.

### Order contract (AutoCategory's data)

- Order for a context is the sorted `AutoCategory.saved.bags[context].rules`
  (higher `runpriority` first; AutoCategory's `cacheInitBag` sorts it). That
  table belongs to AutoCategory's active account or character profile.
- Our rows are entries whose `name` is a managed category name registered
  through our plugin definitions; identity resolves through the definition's
  expression `ic_group("<ruleKey>")`, not the label. Everything else is external.
- **Insertion:** when a group first participates and the active profile has no
  entry for it, insert it after the last managed entry, or at the top when there
  are none, with a run priority between its neighbours. Renumber run priorities
  only when no gap exists. Never move existing entries to make room otherwise.
- **Move:** swap adjacent rows' positions in the selected context by adjusting
  run priority, then `cacheInitBag(context)`. External rows may move; nothing else
  about them changes. Validate the bag-list structure first (external input).
- **Participation off** keeps the entry and position; the predicate returns false.
  **Delete** removes our entries from the active profile's lists.
- Never write show priority, hide state, external definitions, or inactive
  AutoCategory profiles. Integration disable leaves entries in place; their
  definitions stay registered with a false predicate while IC is loaded
  (stage 1 gate 1 showed absent definitions are harmless but appear as `(!)`).
- Reading the order never writes.

### Loading, migration, mutation, and copying

Change [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua):

- Extend `ValidateSavedRules` for participation, including inactive profiles and
  import sources. Extend `PrepareSavedVariables` to validate new fields before
  publishing any migration; preserve version 1 conversion and version 2/3 data.
- Increase `SettingsVersion` in [Core/Init.lua](../../../Core/Init.lua) from 3
  to 4 if still current, so older builds reject the new fields. Optional fields
  keep their defaults without eager writes.
- Extend `NormalizeRule` / `PruneRule` for sparse participation; do not drop
  participation-only overrides or create empty custom groups.
- Publish resolved participation in `GetRuntimeRules`. Never save compiled
  patterns or cached order.
- Add narrow `SetAutoCategoryParticipation(ruleKey, value)`; the move entry point
  lives in the integration module because it writes AutoCategory data.
- `DeleteCustomRule` removes stored fields; `ResetRule` keeps participation.
  `CopyProfile` copies participation and enablement without aliasing.
  `SetUseCharacterItemList` selects participation and enablement.

### Saved-data regression tests

Extend [SavedVariablesTests.lua](../../Tests/SavedVariablesTests.lua) and
[RulePersistenceTests.lua](../../Tests/RulePersistenceTests.lua):

- Version 1/2/3 upgrades preserve unrelated account/inactive-character data;
  missing new fields remain off.
- Malformed participation/enablement rejects loading/import without partial writes.
- Round-trip participation; copy without aliasing; preserve unknown data and
  existing sparse pattern/display fields. Use `ZO_SavedVars`-shaped proxy
  fixtures (write-through metatables), as the spike showed plain tables hide leaks.
- Execute a real pre-feature schema 3 build against schema 4 fixtures and prove
  rejection before mutation. Never use the user's real saved variables.
- Order-contract tests run in the AutoCategory fixture with the real modules:
  insertion anchor, move, gaps/renumbering, participation off, delete, and
  untouched external fields and inactive profile.

## 3. Managed predicate

### Runtime matching

Add one focused module, provisionally `Tracking/AutoCategoryIntegration.lua`.

- AutoCategory evaluates the active list top to bottom and returns the first
  true entry (verified in game). The highest-placed participating matching
  group therefore wins without any precomputed winner: register
  `ic_group(ruleKey)` returning `participating(ruleKey) and
  ItemMatchesRuntimeRule(AutoCategory.checkingItemLink, rules[ruleKey])`.
  External categories interleave naturally.
- Use the existing `ItemMatchesRuntimeRule` and `GetRuntimeRules`; do not
  duplicate pattern matching or read HUD presentation/display policies.
- Escape stable rule keys as Lua string literals. Display names are labels.
  An unknown key in our own expression is a maintained defect: throw.
- Map Backpack/Bank/subscriber bank only at the AutoCategory boundary for the
  editor's context selector; the predicate does not need the context.

### Measurable work

Per classified item, at most one matcher call per managed entry AutoCategory
evaluates before the first match, the same cost as any native category. No
pattern compilation, sorting, scans, settings writes, or refreshes in a
predicate. Add a winner cache only if in-game measurement shows a need.

### Runtime regression tests

Add `Project/Tests/AutoCategoryIntegrationTests.lua`, run with the real
AutoCategory modules like the spike suite:

- Two overlapping groups with opposite Backpack/Bank order produce opposite
  winners; subscriber bank equals Bank. Participation off falls through.
- Hidden tracker groups and all Show/Notify states do not affect matching;
  exclusions, empty patterns, unmatched items, non-ASCII/quoted names.
- Zero scan/compile/write/refresh calls from predicates; matcher calls bounded
  as above. External category above/between/below changes the actual result.
- Missing owned functions/state throw rather than becoming false.

## 4. Activate, synchronize managed entries, and project explicit mixed order

### Activation and lifecycle

Use the contracts established in stage 1:

- In [InventoryCompanion_DEV.txt](../../../InventoryCompanion_DEV.txt), add the
  module and verified optional dependency identity. Wire activation through
  [Core/Init.lua](../../../Core/Init.lua) /
  [Core/Events.lua](../../../Core/Events.lua) after saved rules are ready.
  Register the real predicate before any managed expression can execute.
- Expose explicit absent, disabled, waiting, active, and incompatible status.
  Absence is an ordinary optional-dependency condition. If enabled but external
  contracts are unsupported, use existing status/warning conventions and do not
  publish partial managed state.
- Validate external API/data shapes at activation/reconciliation boundaries.
  Call our established owned functions directly after validation.
- Reconcile owned definitions/assignments using stable rule identity. Initially
  insert managed groups above existing categories. Apply explicit combined-order
  edits to actual selected-context run precedence through verified operations;
  external ordering is editable, external definitions are not.
- Preserve external relative order on initial insertion and retain user
  interleaving on synchronization. Do not reset to managed-first on edits,
  reload, or profile switches. Never change category show priority, expressions,
  hide state, or external assignments in inactive profiles.
- Preserve collisions/manual external edits according to the spike's explicit
  policy. Do not claim ownership from a matching label alone.
- Remove stale owned entries for deleted/disabled groups and old active contexts.
  Disable removes integration's effect without deleting user rules. Keep inactive
  AutoCategory profiles intact and reconcile their own active switch/reset paths.
- Validate/prepare the complete reconciliation before mutation where possible;
  report external operation errors and do not announce successful activation
  after incomplete registration/removal.
- For up/down, validate external structures, perform the simple order change
  through the verified AutoCategory path, then refresh its cache. Lua runs
  synchronously; do not assume normal moves can be interrupted or add speculative
  transactions/rollback. Maintained defects throw visibly, external failures are
  reported, and no success is announced after an error. Add recovery only if
  investigation establishes a concrete API need.

### Synchronization surfaces

Trace every caller of `InvalidateRuleCache` in
[Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) before wiring.
Cover `SetUseCharacterItemList`, `UpdateRulePatterns`, `UpdateRuleProperty`,
`CreateCustomRule`, `DeleteCustomRule`, `ResetRule`, `CopyProfile`, and the new
participation/mixed-row move methods, plus active-profile enable/disable and
AutoCategory's own profile/reset/external-order events.

Coalesce a relevant edit burst into at most one verified refresh per affected
supported inventory. A Bank-only order edit
does not refresh Backpack. Ensure pending work uses the latest active profile
and revision; no old callback may publish after disable/profile switch.
Show/Notify-only changes must not alter classification or add classification
listeners. Retain existing pickup-notification event registration.

### Adapter regression tests

Extend the focused fixture, not the full dependent addon:

- Absent/not-ready/incompatible contracts; both load orders; no expressions
  execute before registration.
- Enable/synchronize/disable repeated cycles: no duplicates, idempotent cleanup,
  user-category and inactive-profile preservation.
- Rename/delete/pattern/participation/move/Reset/copy and both addons' switches;
  pending burst then disable/switch cannot resurrect stale categories.
- Existing external rules still win according to their own precedence; a
  nonmatch falls through. Initial managed-first insertion and explicit
  above/between/below moves affect classification; subsequent reconciliation
  retains interleaving. External expression/show priority/hide state remain
  byte-for-byte unchanged.
- Characters sharing one AutoCategory profile retain separate participation/
  enablement while using the same order, without modifying inactive data.
  Reordering or removing our entries in AutoCategory's own UI is respected;
  synchronization re-inserts only entries for participating groups that are
  missing, at the stage 2 anchor.
- Count registrations/removals/compiles and bounded refreshes. Bank-only edits
  affect Bank only; merely opening/changing editor view affects neither.
- Real external operation failures produce explicit status; internal failures
  propagate. Test reload persistence and missing-definition behavior
  (integration off, addon disabled/uninstalled) before live opt-in.

## 5. Add settings, participation, and the ordered group-editor view

### Profile settings and item editor

Add opt-in and compatibility status to
[Core/Settings.lua](../../../Core/Settings.lua). Do not build another Notify
setting: completed Chat/HUD pickup delivery stays independent. Resolve opt-in
against the existing account/character tracked-list selection and refresh status
when that selection changes; clearly identify both active profile contexts.
All integration editor controls are hidden while off/unavailable: view toggle,
inventory selector, mixed list, arrows, external details, and participation.
Return an active mixed view to normal and preserve saved choices. Do not add an
inactive/read-only preview. Retain only the main settings activation entry point
and applicable dependency/error reporting.

In [Tracking/EditPanelItemsTab.lua](../../../Tracking/EditPanelItemsTab.lua)
and [Tracking/EditPanelItemsTab.xml](../../../Tracking/EditPanelItemsTab.xml),
bind the group-only AutoCategory control after Notify to the new participation
mutation. Collapse the existing category-space column to zero width while
disabled/unavailable; reserve one consistent width across row types when active.
Preserve current Show/Notify popups, recycled-row/profile identity checks, name
readability, and row selection. Refresh/rebind on adapter status changes.

### Group editor changes

Change [Tracking/EditPanelGroupsTab.lua](../../../Tracking/EditPanelGroupsTab.lua)
and [Tracking/EditPanelGroupsTab.xml](../../../Tracking/EditPanelGroupsTab.xml):

- Extend `InitToolbar` with the top AutoCategory view toggle and the supported
  inventory dropdown/radios. View/context selection is transient; it performs
  no saved writes or inventory refresh.
- Keep `GetSortedGroupNames` for the normal view. The AutoCategory view uses
  `GetAutoCategoryEntryOrder(context)`, which reads AutoCategory's active
  sorted bag list (stage 2), not an independent sort. Exclude
  Miscellaneous and indicate participation independently of hidden-HUD styling.
- Add source badges/labels and source-qualified row selection. External rows
  show read-only names/filter details and ordering buttons, never our editable
  name/pattern controls, participation toggles, Reset/Delete, or hide controls.
  Preserve external damaged/hidden status as information, not editable state.
- Extend `PopulateGroupRow` / `PopulateGroupListPane` with up/down controls;
  preserve the right-hand pattern/name editing pane and selection by stable key.
- The exact interaction model is the currency panel's ordering rows in ESO's
  main game settings panel, built by `GetCurrencyPanelSettingsControls` /
  `CreateResourceSettingsList` in
  [Tracking/CurrencyPanel.lua](../../../Tracking/CurrencyPanel.lua). Copy
  `CreateResourceSettingsRow`'s 28-by-26 native `ZO_DefaultButton` up/down arrows,
  options hover tooltips, and click sound. Follow its click sequence:
  `MoveResource` / `SaveSettingsRowOrder`, `ReorderResourceSettingsRows`,
  `HighlightResourceSettingsRow`, then refresh the affected display.
  Adapt these operations to the combined list; do not call currency-specific helpers.
  Also retain group selection and scroll the moved group into view.
- The currency implementation reorders shown resources only and clears hidden
  resource order. Intentionally do not copy that storage policy: a group whose
  participation is turned off keeps its AutoCategory entry and position, so
  re-enabling does not discard it. This is a data-policy difference, not a different arrow
  interaction.
- Click handlers call `MoveAutoCategoryEntry(entryName, context, direction)`,
  then rebuild the view from AutoCategory's list.
  Both managed and external rows use this same arrow interaction. Disable endpoint
  buttons and all moves when search hides rows, with explanatory tooltips.
- Switching away hides ordering controls and restores normal ordering. Close
  stale popup/callback state on profile/import/reset/delete/view changes using
  existing editor conventions. No callback may target a recycled row/profile.
- Do not add separate display-order or tracker-order editing. Additional
  inventory options require tested context support, not a larger enum alone.

### Editor regression tests

Extend [GroupEditorTests.lua](../../Tests/GroupEditorTests.lua) and
[ItemEditorTests.lua](../../Tests/ItemEditorTests.lua):

- Top toggle/context selector chooses the correct list without writes/refresh.
- Up/down persists one context, swaps adjacent complete-list positions, keeps
  stable-key selection/highlight/visibility, and has correct endpoint/search
  disabled states. Participation-off groups retain editable positions but do
  not win.
- Mixed rows retain source-qualified selection with duplicate labels; external
  selection displays read-only details and cannot trigger our name/pattern/
  Reset/Delete handlers. Moving an external row updates actual run precedence,
  not its expression, show priority, or hide state.
- Rename cannot reorder a group. Profile/context switches and deletion
  cannot reuse stale handlers or change the other context's order.
- Category width is zero when inactive and aligned when active; no individual
  toggle. Show/Notify remain unchanged. Extend current runner XML assertions
  for inactive and active layouts rather than deleting the zero-width invariant.
- Off/missing/incompatible status hides every integration editor control and
  returns to the normal view, without saved writes. Re-enabling restores
  order and participation choices; no inactive preview is presented.
- Native textures, radio/dropdown behavior, scroll visibility, toolbar fit, and
  label readability require in-game verification, not just XML parsing.

## 6. Verification, documentation, and completion gates

- Wire the new fixture into
  [Run-RuleTests.py](../../Tests/Run-RuleTests.py) and use the existing Lua 5.1
  setup. Run `python Project\Tests\Run-RuleTests.py` for the related persistence,
  saved-data, group/item editor, notification, tracker, and new adapter suites.
  Extend [Core/RuleTests.lua](../../../Core/RuleTests.lua) /
  [Core/Tests.lua](../../../Core/Tests.lua) only where useful for safe in-game
  matching checks; synthetic tests must never mutate live inventory or saves.
- Preserve [ItemNotificationTests.lua](../../Tests/ItemNotificationTests.lua)
  coverage: destination union, hidden-rule/exclusion policy, listener
  registration with HUD hidden, and no redirect to unselected destinations.
- Check changed XML, texture paths against
  [ESO-Game-Textures.md](../../Resources/ESO-Game-Textures.md), Lua syntax,
  documentation links, and whitespace.
- In game, execute the feature spec's full acceptance matrix, including
  opposite overlap orders, reordered actual categories, bank/subscriber bank,
  external categories above/between/below groups, read-only external details,
  a shared AutoCategory profile with different character participation,
  AutoCategory account/character profile switch,
  refresh/edit bursts, profile/reload, and safe disable.
- Measure the integration-off/on sort and edit-burst baseline. Record item/group
  counts, matcher/refresh counts, timing limits and results, AutoCategory version,
  verified APIs, and keyboard/gamepad support here before completion.
- Update [UserManual.bbcode](../../../UserManual.bbcode) with participation,
  the top view toggle, per-inventory up/down ordering (shared with AutoCategory's own settings), winning-group example,
  mixed-order precedence, read-only Phase I external filters, profile-scoped
  enable/disable, and saved-data/downgrade guidance.
  Update the authoritative working changelog from actual implemented changes
  and follow [ReleaseChecklist.md](../../Publishing/ReleaseChecklist.md).
- Archive only after automated and user-reported in-game acceptance is complete.
  Do not label the current plan as implemented or promise unverified APIs.

## Dependencies and work order

Stage 1 established native insertion; its remaining lifecycle gates
(missing definitions, reload, Bank, profile switch) precede live activation.
Stage 2 establishes participation storage and the AutoCategory order contract
before stage 3's predicate and stage 5's editor use them. Stage 4 must work
before exposing active participation controls. Stage 6 verifies the completed
runtime/editor work. No live changes bypass the stage 1 exit gate.

Warn and obtain approval before switching to a feature branch for substantial
runtime implementation. These documentation edits do not authorize that work
or changes to installed AutoCategory source/saved variables.
