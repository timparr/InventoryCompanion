# AutoCategory integration: implementation plan

Status: Planned, not implemented or compatibility-certified. Updated on
2026-10-31 with confirmed combined ordering, read-only external filters,
managed-first initial placement, shared ordering with scoped participation,
hidden inactive UI, and accepted defaults.

Behavior, accepted defaults, and remaining technical gates are in the
[feature spec](todo_plan_autocategoryIntegration.md). This document follows
implementation order: external lifecycle verification, saved representation,
ranked matching, adapter synchronization, editor, then completion checks.
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
- Establish one authoritative account-wide mixed-order record per inventory,
  including retained nonparticipant positions. Native assignments are its active
  projection, not sufficient storage for absent assignments. Derive managed
  ranks from it; do not persist competing per-character ranks. Verify stable
  external identities and compatibility with AutoCategory's own active profile.
  Test external edits, new-group insertion, and character-specific participation
  changes without replacing shared order.
- Establish names/collision/manual-edit reconciliation and verified keyboard /
  gamepad scope. External definitions/filters are read-only in Phase I; only
  their selected-context ordering is editable here.

Record concrete contracts, ordering storage, and the chosen strategy here before
dependent storage/runtime work. Native insertion is preferred; classification
ownership needs explicit approval after the spike. Stop if neither strategy is
safe. Do not silently substitute a managed-only list or an unapproved
`MatchCategoryRules` replacement.

## 2. Save scoped participation and shared inventory ordering

### Current behavior and proposed representation

[Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) stores rule
overrides under the active profile's `trackedRules[ruleKey]`. `GetRuntimeRules`
merges built-in defaults and sparse overrides. Display flags have their own
boolean validation and inheritance; rank is neither a display flag nor a
pattern. The stable rule key survives display-name edits.

Add optional participation directly to each saved rule, separate from `display`.
Store combined order at account scope, provisionally `autoCategoryOrder`.
Managed ranks are derived runtime values, not another saved ordering source.

```lua
trackedRules = {
    maps = { autoCategoryEnabled = true },
    cyrodiil = { autoCategoryEnabled = true },
}
```

- Missing `autoCategoryEnabled` resolves false. Use sparse writes for that
  default. Participation is shared across the supported inventory contexts;
  ranks are independent per context.
- Each inventory order is a dense ordered list of unique source-qualified
  identities. Validate structure and identities at loading/import, preserve
  unrelated data, and report duplicate references rather than ambiguous order.
  Derive finite positive integer managed ranks from list positions/subsequence.
- Missing groups follow the accepted stable-key append behavior. Reading the
  effective order must not save anything.
- Rank all ordinary groups, including nonparticipants; omit Miscellaneous.
  Their relative ranks must come from the managed subsequence of the combined
  list, not a separately editable competing order. A move validates the complete
  selected-context row list, updates its authoritative ordering, and derives
  managed runtime ranks in the same operation. Leave the other inventory intact;
  the selected inventory's order is intentionally shared across characters.
- Add `autoCategoryIntegrationEnabled`, default false, to both account and
  character tracked-list profiles. Resolve it using the existing
  `useCharacterItemList` choice. The settings panel already supports that choice;
  do not add an independent integration profile mode.

### Combined-order storage contract

Use one account-wide ordered-reference record per supported inventory as the
ordering authority; AutoCategory assignments and managed ranks are projections.
Stage 1 establishes reference identity and projection mechanics, not independent
per-character ordering. Native assignments cannot retain nonparticipant
positions by themselves.

- Each row reference identifies its source and stable identity, not just label:
  our rule key or a verified AutoCategory assignment identity.
- Scope saved mixed order by account and inventory context, not character or
  tracked-list profile pair. Resolve external references against AutoCategory's
  active assignment profile through the verified spike contract. Do not copy
  external definitions into our rules or overwrite inactive external profiles.
- Include nonparticipating groups as retained positions without active
  assignments; toggling participation must not reset other positions.
- On first setup prepend our effective group order to the existing external
  order. After explicit interleaving, synchronization must preserve it. Append
  new groups within the managed subsequence using the spike's documented anchor,
  not by restoring a managed-first block on each refresh.
- Loading/import validates duplicate identities, recognized reference types,
  and malformed ordering records before publication. Missing external
  assignments are an external reconciliation condition: preserve saved intent
  and report unresolved references rather than discarding them or rewriting
  filters. Establish rename/replacement identity behavior during the spike.
- Tracked-profile copy transfers participation/enablement, not shared order.
  Define how disabling/removing managed entries preserves the user's
  external relative order. Explicit external ordering edits are user changes;
  unrelated synchronization must not restore an obsolete snapshot over them.
- Until authoritative storage/identity is proven, do not claim that saving
  `autoCategoryRank` alone implements or persists combined ordering.

### Loading, migration, mutation, and copying

Change [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua):

- Extend `ValidateSavedRules` for participation; validate shared order at the
  account loading boundary. Validate inactive participation profiles and import
  sources, not just the visible list.
- Extend `PrepareSavedVariables` to validate all new recognized fields, scoped
  enable preferences, and any combined-order records before publishing any
  migration. Preserve existing version
  1 sparse-rule conversion and version 2/3 data.
- Increase `SettingsVersion` in [Core/Init.lua](../../../Core/Init.lua) from
  the current 3 to 4, if still current at implementation time. Upgrade old
  profiles before ZOS constructors; optional fields retain their defaults
  without eagerly enrolling groups or writing every rank.
- Extend `NormalizeRule` / `PruneRule` only for sparse participation; do not drop
  participation-only overrides or create empty custom groups as a side effect.
- Publish resolved participation in `GetRuntimeRules` and expose derived rank/
  order through the integration's editor APIs. Never save compiled patterns,
  effective projection arrays, or cached winners.
- Add narrow `SetAutoCategoryParticipation(ruleKey, value)` and
  `MoveAutoCategoryEntry(rowIdentity, context, direction)` mutation entry points.
  The move accepts either a managed or external row and validates the current
  pair of active profile identities before writes. Do not force rank tables
  through boolean `UpdateRuleFlag` or the display-name-only `UpdateRuleProperty`.
- `DeleteCustomRule` naturally removes the group's stored fields. `ResetRule`
  keeps participation/rank because current Reset restores name/patterns only.
  New groups inherit off/append behavior. Name edits retain their stable key.
- Extend `CopyProfile` to validate/copy participation and scoped enablement,
  without nested-table aliasing or copying/replacing shared combined order,
  before replacing destination state. Importing enabled integration requires
  successful reconciliation before reporting active status; invalidate/publish
  the new tracked context once.
- `SetUseCharacterItemList` selects participation/enablement; shared order is
  unchanged. Groups absent from the selected list retain their saved positions.

### Saved-data regression tests

Extend [SavedVariablesTests.lua](../../Tests/SavedVariablesTests.lua) and
[RulePersistenceTests.lua](../../Tests/RulePersistenceTests.lua):

- Version 1/2/3 upgrades preserve unrelated account/inactive-character data;
  missing new fields remain off with deterministic effective ranks.
- Malformed flags, combined-order records, holes, and duplicate identities
  reject loading/import without partial writes.
- Round-trip participation and different Backpack/Bank orders; copy without
  aliasing; preserve unknown data and existing sparse pattern/display fields.
  Cover shared mixed external references and separate participation/enablement
  in account/character profiles, including inactive profiles. Tracked-profile
  copy cannot overwrite shared ordering.
- Moves normalize only the selected context; reads/renames/Reset do not change
  ranks; deletion/new group behavior matches the spec.
- Execute a real pre-feature schema 3 build against schema 4 fixtures and prove
  rejection before mutation, including inactive profiles. Never use the user's
  real saved variables to establish downgrade safety.

## 3. Resolve ranks and select one managed winner

### Runtime matching

Add one focused module, provisionally
`Tracking/AutoCategoryIntegration.lua`, with direct owned API wiring rather
than another general integration framework.

- Add `GetAutoCategoryGroupOrder(context)` to produce the complete effective
  ordinary-group order from the authoritative combined list's managed
  subsequence, with the accepted rank/key defaults for initial setup.
  Add `GetAutoCategoryEntryOrder(context)` for the combined editor/projection
  rows. Build the participating projection from the same source of truth.
- Add `GetAutoCategoryWinner(itemLink, context)` to walk that participating
  projection and return the first matching rule key, or nil for a genuine
  no-match. Rank 1 is most important. Invalid internal contexts/contracts throw;
  unsupported externally supplied inventories are handled at the adapter boundary.
- Call the existing `ItemMatchesRuntimeRule` in
  [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua). It already
  uses the shared include/exclude matcher and compiled lists; do not duplicate
  pattern matching or derive classification from HUD presentation.
- Read `GetRuntimeRules`, not per-item editor copies from
  `GetActiveTrackedRules` (which also filters hidden groups by default).
  Ignore all Show/Notify/grouping/hidden/expansion display policies here.
- Map backpack/bank/subscriber-bank at the external boundary; both bank bag IDs
  select `bank`. Register `ic_group(ruleKey)` so it is true exactly when the
  resolved winner equals that rule key. An earlier-evaluated lower-ranked
  managed predicate must still return false.
- Escape stable rule keys as Lua string literals for expressions. Display
  names are labels only. Validate owned expression keys during synchronization;
  a broken internal lookup must not become an unexplained no-match.
- These predicate targets assume native insertion. With approved classification
  ownership, dispatch the combined list in order and evaluate external rules
  through their verified AutoCategory contracts; stop at the first true entry.
  Do not choose a managed winner first and bypass an earlier external category.
  Amend this stage with the approved complete dispatcher contract before coding.

### Cache and measurable work

Rebuild the two ordered projections once per relevant configuration revision.
Do not compile patterns, sort groups, scan bags, mutate settings, or refresh
inventory in a predicate.

Multiple managed expressions may ask about the same item. Avoid rescanning all
groups for every expression: retain a bounded last-classification result keyed
by full item link, inventory context, and active projection revision, including
no-match results. Matching is name-based, so count changes do not invalidate an
otherwise identical link. Invalidate on matching/participation/rank/profile
changes. Do not key only by bag/slot or retain an unbounded cache of items.

For G participating groups and N consecutive distinct classification inputs,
assert at most N*G existing-matcher calls. Subsequent managed predicates for
the same input/revision only compare the cached winning key. A burst of B
managed-predicate queries for one item requires at most G matcher calls, not
B*G. This bounds our work without assuming AutoCategory expression order.

### Runtime regression tests

Add narrowly scoped `Project/Tests/AutoCategoryIntegrationTests.lua`, loaded
by the existing isolated runner, using the real Inventory Companion matcher:

- Two overlapping groups with opposite Backpack/Bank ranks produce opposite
  winners; subscriber bank equals Bank. Evaluate managed predicates in reversed
  and arbitrary order to prove a single winner independent of call order.
- Test disabled participants, hidden tracker groups, all Show/Notify states,
  exclusions, empty patterns, no includes, unmatched items, duplicate labels,
  renamed/non-ASCII/quoted names, and deterministic missing-rank defaults.
- Assert zero scan/compile/write/refresh calls from predicates and the exact
  matcher bounds above. Same slot with a changed link and any projection/profile
  revision must not reuse a stale winner.
- Missing required owned functions/state throw; do not convert such failures to
  a successful false predicate.
- Combined-order fixtures put one matching external category above, between,
  and below overlapping managed groups. Assert the actual result, not merely
  sorted labels. If ownership is selected, add complete external result/error/
  side-effect parity tests and dispatcher workload bounds before implementation.

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

Coalesce a relevant edit burst into one projection rebuild and at most one
verified refresh per affected supported inventory. A Bank-only rank edit
does not refresh Backpack. Ensure pending work uses the latest active profile
and revision; no old callback may publish after disable/profile switch.
Show/Notify-only changes must not alter the winner or add classification
listeners. Retain existing pickup-notification event registration.

### Adapter regression tests

Extend the focused fixture, not the full dependent addon:

- Absent/not-ready/incompatible contracts; both load orders; no expressions
  execute before registration.
- Enable/synchronize/disable repeated cycles: no duplicates, idempotent cleanup,
  user-category and inactive-profile preservation.
- Rename/delete/pattern/participation/rank/Reset/copy and both addons' switches;
  pending burst then disable/switch cannot resurrect stale categories.
- Existing external rules still win according to their own precedence; a
  nonmatch falls through. Initial managed-first insertion and explicit
  above/between/below moves affect classification; subsequent reconciliation
  retains interleaving. External expression/show priority/hide state remain
  byte-for-byte unchanged.
- Characters sharing one AutoCategory profile retain separate participation/
  enablement while using the same order, without modifying inactive data or reviving a stale
  external-order snapshot on disable. External edits while active/disabled
  reconcile according to the verified storage contract.
- Count registrations/removals/compiles and bounded refreshes. Bank-only edits
  affect Bank only; merely opening/changing editor view affects neither.
- Real external operation failures produce explicit status; internal failures
  propagate. If persisted projection is selected, test reload and missing-addon
  cleanup contracts before live opt-in.

## 5. Add settings, participation, and the ranked group-editor view

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
  the shared `GetAutoCategoryEntryOrder`, not an independent sort. Exclude
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
  Adapt these operations to group ranks; do not call currency-specific helpers.
  Also retain group selection and scroll the moved group into view.
- The currency implementation reorders shown resources only and clears hidden
  resource order. Intentionally do not copy that storage policy: the group view
  keeps nonparticipating groups ranked so enabling/disabling participation does
  not discard position. This is a data-policy difference, not a different arrow
  interaction.
- Click handlers call `MoveAutoCategoryEntry` with the source-qualified identity,
  current inventory and profile context, then rebuild from authoritative state.
  Both managed and external rows use this same arrow interaction. Disable endpoint
  buttons and all moves when search hides rows, with explanatory tooltips.
- Switching away hides ranking controls and restores normal ordering. Close
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
  disabled states. Nonparticipants retain editable positions but do not win.
- Mixed rows retain source-qualified selection with duplicate labels; external
  selection displays read-only details and cannot trigger our name/pattern/
  Reset/Delete handlers. Moving an external row updates actual run precedence,
  not its expression, show priority, or hide state.
- Rename cannot reorder a ranked group. Profile/context switches and deletion
  cannot reuse stale handlers or lose the other context's order.
- Category width is zero when inactive and aligned when active; no individual
  toggle. Show/Notify remain unchanged. Extend current runner XML assertions
  for inactive and active layouts rather than deleting the zero-width invariant.
- Off/missing/incompatible status hides every integration editor control and
  returns to the normal view, without saved writes. Re-enabling restores shared
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
  opposite overlap ranks, reordered actual categories, bank/subscriber bank,
  external categories above/between/below groups, read-only external details,
  shared ordering with different character participation, AutoCategory profiles,
  refresh/edit bursts, profile/reload, and safe disable.
- Measure the integration-off/on sort and edit-burst baseline. Record item/group
  counts, matcher/refresh counts, timing limits and results, AutoCategory version,
  verified APIs, and keyboard/gamepad support here before completion.
- Update [UserManual.bbcode](../../../UserManual.bbcode) with participation,
  the top view toggle, per-inventory rank/up/down behavior, winning-group example,
  mixed-order precedence, read-only Phase I external filters, profile-scoped
  enable/disable, and saved-data/downgrade guidance.
  Update the authoritative working changelog from actual implemented changes
  and follow [ReleaseChecklist.md](../../Publishing/ReleaseChecklist.md).
- Archive only after automated and user-reported in-game acceptance is complete.
  Do not label the current plan as implemented or promise unverified APIs.

## Dependencies and work order

Stage 1 establishes lifecycle feasibility and external placement before any live
projection. Stage 2 establishes saved contracts before stage 3 matching and
stage 5 editor controls can write them. Stage 3 supplies the shared ordering and
winner consumed by stage 4 and stage 5. Stage 4 must work before exposing active
participation controls. Stage 6 verifies the completed runtime/editor work.
Pure managed-rank fixtures may be developed independently of the spike, but
combined-order persistence/dispatcher work depends on its authoritative-storage
and native-insertion/ownership decision. No live changes bypass its exit gate.

Warn and obtain approval before switching to a feature branch for substantial
runtime implementation. These documentation edits do not authorize that work
or changes to installed AutoCategory source/saved variables.
