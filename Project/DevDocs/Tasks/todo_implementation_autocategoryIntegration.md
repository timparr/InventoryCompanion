# AutoCategory integration: implementation plan

Status: Planned, not implemented or compatibility-certified. Native insertion
is proven in game. Revised 2026-10-31 (author): Inventory Companion owns its
groups' order per context, positioned against user-selected AutoCategory marker
categories, and projects only its own entries into AutoCategory's seven bag
lists. AutoCategory's entries are never edited. Supersedes the "edit
AutoCategory's combined order" and "AutoCategory's list is the order record"
designs.

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
- **Decided (author, 2026-10-31):** briefly, AutoCategory's assignments were to
  be the order record (option 1). Revised the same day: editing data we do not
  own loses order when AutoCategory is absent/reset and when groups are renamed
  while it is off, and a mixed list of ~29 categories per context is unwieldy.
  IC now owns the order with marker categories (stage 2).
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
  Document that in the manual. (2) offline: placement values (fractional and
  above-1000 run/show priorities, `%04d` formatting of fractions in ESO's Lua,
  saved/settings-window survival), `icOwned` marker survival (cache rebuild,
  Export to all bags, settings window), a skipped same-name collision, and
  inline-texture markup in category names (lookup, compile, tie-break, collapse,
  settings dropdown, header). (3) in game: plugin registration plus
  projected entries survive `/reloadui` and classify in Backpack and Bank,
  including subscriber bank. (4) each of the seven contexts. (5) AutoCategory
  account/character profile switch path and reprojection. Gamepad stays out of
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
  Superseded 2026-10-31: IC owns per-context order with markers (stage 2).
- ~~Establish names/collision/manual-edit reconciliation.~~ Decided in stage 2
  (`icOwned` marker on entries, collisions skipped before registration, manual
  moves overwritten).
  Keyboard/gamepad scope remains: keyboard verified, gamepad out of scope.

Record concrete contracts, ordering storage, and the chosen strategy here before
dependent storage/runtime work. Native insertion is preferred; classification
ownership needs explicit approval after the spike. Stop if neither strategy is
safe. Do not silently substitute a managed-only list or an unapproved
`MatchCategoryRules` replacement.

## 2. Save participation, order, and markers

Decided 2026-10-31 (author): **Inventory Companion owns the order** of its
groups for each AutoCategory context. AutoCategory's categories appear only as
fixed **markers** the user selects; their relative order is read from
AutoCategory and never written.

### Representation

[Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) stores rule
overrides under the active profile's `trackedRules[ruleKey]`; the stable rule
key survives display-name edits. Participation goes on each saved rule; order
and markers go on the tracked-list profile:

```lua
trackedRules = {
    maps = { autoCategoryEnabled = true },
    cyrodiil = { autoCategoryEnabled = true },
}
autoCategoryIntegrationEnabled = true
autoCategoryMarkers = { "New", "Selling", "Container", "Stolen" } -- category names
autoCategoryOrder = {
    [AC_BAG_TYPE_BACKPACK] = {
        { ruleKey = "plunder" },                  -- top slot
        { ruleKey = "maps", below = "New" },
        { ruleKey = "cyrodiil", below = "New" },
    },
    -- one list per context, 1..7
}
```

- Missing `autoCategoryEnabled` resolves false; use sparse writes. Participation
  applies to every context.
- `autoCategoryIntegrationEnabled`, `autoCategoryMarkers`, and
  `autoCategoryOrder` live in both account and character tracked-list profiles,
  resolved through the existing `useCharacterItemList` choice. No independent
  integration profile mode.
- Missing `autoCategoryMarkers` means the defaults: AutoCategory's localized
  default names for New, Selling, Container, and Stolen (read from its
  `SI_AC_DEFAULT_CATEGORY_*` strings at the boundary), filtered to categories
  that exist. An explicit empty list is valid.
- `autoCategoryOrder[context]` is an ordered list. `below` names the marker the
  group sits beneath; absent means the top slot. Entries are kept for
  nonparticipating groups so turning participation off/on keeps the position.
  Groups never ordered are absent and are appended to the top slot when first
  enrolled.
- Markers and `below` are stored by AutoCategory category name (its only
  identity). A `below` name that is no longer a selected, present marker
  resolves to the nearest preceding valid marker's slot, or the top slot, at
  read time. Saved data is rewritten only by the next user move.

### Order and placement contract

`ResolveAutoCategoryOrder(context)` (pure, in the integration module) combines
our saved order with the markers present in AutoCategory's active list for that
context, in AutoCategory's run order, giving the view rows. `ComputePlacement`
then assigns each participating group a run priority:

- **Slots.** A group in marker M's slot must sort after M and every entry tied
  with M, and before the next lower distinct priority P in the list (all
  entries, not only markers). The available range is (P, M). The top slot is
  above the list's highest priority; the last slot extends below its marker.
- **Values.** Within a range, space the slot's groups evenly in saved order,
  preferring whole numbers; use fractions only when the range has fewer whole
  numbers than groups. `runpriority = showpriority` for every entry, so
  display follows the view order.
- **Top slot (provisional, try in development):** AutoCategory's display key
  `string.format("%04d%s", 1000 - showpriority, name)` reverses order above
  1000. Initially mirror show priorities within the top slot only, so headings
  follow the view. Revisit after in-game trial.
- AutoCategory sorts ties by name; our values avoid ties with each other and
  with external entries.

### Ownership and projection contract

`ProjectAutoCategory()` (integration module) is the only writer of AutoCategory
bag data:

- For each of the active profile's seven lists: remove our entries that are no
  longer wanted, insert missing ones, and update changed run/show priorities.
  Never alter, reorder, or remove any other entry. Write only changed values,
  then `cacheInitBag` each changed context.
- **Ownership marker.** Every entry we insert carries `icOwned = true`. An entry
  is ours only if marked; labels alone never claim. Projection removes marked
  entries that do not correspond to a current participating group's name
  (renames, deletions, other characters' groups), so IC stores no name list.
- **Category name.** Register each group as `AutoCategoryName(displayName)`:
  one constant decoration, preferred an inline texture icon prefix
  (`|t18:18:<texture>|t <name>`), fallback `<name> · Inventory Companion`.
  Choose by in-game trial after the gate-2 markup check.
- **Collision (backstop).** AutoCategory's `addTableRules` renames duplicate
  rule names at load and calls `renameBagRule`, which rewrites the first bag
  entry with the old name, possibly the user's. Exclude from `RegisterPlugin`
  any group whose decorated name equals a non-owned AutoCategory rule (its
  account rules are loaded at its `EVENT_ADD_ON_LOADED`, before ours). The view
  shows the conflict until renamed.
- **Definitions** are registered via `RegisterPlugin` predefined rules with
  expression `ic_group("<ruleKey>")` and the decorated category name, after
  `AddRuleFunc("ic_group", ...)`. Registered for every group while IC is loaded,
  including when integration is off (predicate returns false).
- **When it runs:** in our plugin init (after AutoCategory selects its profile,
  before its first cache build), after IC edits that change membership, names,
  participation, order, or markers, after IC tracked-list switch/copy, after
  AutoCategory's account/character switch (path to trace, stage 1 gate 5), and
  on integration disable (removes all our entries from the active profile).
- Shared AutoCategory profile with character-specific IC groups: each login
  reprojects for that character; marked entries from another character's
  groups are removed. Our entries moved in AutoCategory's own settings
  are overwritten at the next projection. Document both, plus AutoCategory's
  unpruned per-name collapse flags after a rename.
- Validate AutoCategory's bag-list structure (external input) before reading or
  writing. Never write inactive AutoCategory profiles.

### Loading, migration, mutation, and copying

Change [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua):

- Extend `ValidateSavedRules` for participation, and profile validation for
  enablement, markers (array of nonempty strings), and order (seven-context
  table of `{ ruleKey, below? }`, no duplicate keys per context), including
  inactive profiles and import sources. Order entries for unknown rule keys are
  pruned at load with a reported count, not an error (users edit saved data).
  Extend `PrepareSavedVariables` to validate new fields before publishing any
  migration; preserve version 1 conversion and version 2/3 data.
- Increase `SettingsVersion` in [Core/Init.lua](../../../Core/Init.lua) from 3
  to 4 if still current, so older builds reject the new fields. Optional fields
  keep their defaults without eager writes.
- Extend `NormalizeRule` / `PruneRule` for sparse participation; do not drop
  participation-only overrides or create empty custom groups.
- Publish resolved participation in `GetRuntimeRules`. Never save compiled
  patterns or computed priorities.
- Add narrow `SetAutoCategoryParticipation(ruleKey, value)`,
  `MoveAutoCategoryGroup(context, ruleKey, direction)`, and
  `SetAutoCategoryMarkers(names)`. A move past a marker changes `below`; a move
  past a group swaps list positions.
- `DeleteCustomRule` removes participation and order entries; `ResetRule` keeps
  them. `CopyProfile` copies participation, enablement, markers, and order
  without aliasing. `SetUseCharacterItemList` selects all of them.

### Saved-data regression tests

Extend [SavedVariablesTests.lua](../../Tests/SavedVariablesTests.lua) and
[RulePersistenceTests.lua](../../Tests/RulePersistenceTests.lua):

- Version 1/2/3 upgrades preserve unrelated account/inactive-character data;
  missing new fields resolve to defaults.
- Malformed participation/enablement/markers/order rejects loading/import
  without partial writes; unknown order keys are pruned and reported.
- Round-trip and copy without aliasing; preserve unknown data and existing
  sparse fields. Use `ZO_SavedVars`-shaped proxy fixtures (write-through
  metatables), as the spike showed plain tables hide leaks.
- Moves: past group, past marker, endpoints, participation-off retention,
  rename keeps position, delete removes it, Bank move leaves Backpack unchanged.
- Execute a real pre-feature schema 3 build against schema 4 fixtures and prove
  rejection before mutation. Never use the user's real saved variables.

## 3. Managed predicate

### Runtime matching

Add one focused module, provisionally `Tracking/AutoCategoryIntegration.lua`.

- AutoCategory evaluates the active list top to bottom and returns the first
  true entry (verified in game). Projection makes that order equal our view, so
  no precomputed winner is needed. Register `ic_group(ruleKey)` returning
  `integrationEnabled and participating(ruleKey) and
  ItemMatchesRuntimeRule(AutoCategory.checkingItemLink, rules[ruleKey])`.
- Use the existing `ItemMatchesRuntimeRule` and `GetRuntimeRules`; do not
  duplicate pattern matching or read HUD presentation/display policies.
- Escape stable rule keys as Lua string literals. Display names are labels.
  An unknown key in our own registered expression is a maintained defect:
  throw.

### Measurable work

Per classified item, at most one matcher call per managed entry AutoCategory
evaluates before the first match, the same cost as any native category. No
pattern compilation, sorting, scans, settings writes, or refreshes in a
predicate.

### Runtime and placement regression tests

Add `Project/Tests/AutoCategoryIntegrationTests.lua`, run with the real
AutoCategory modules like the spike suite:

- Two overlapping groups with opposite Backpack/Bank order produce opposite
  winners; subscriber bank equals Bank. Participation off falls through.
- Group above a marker beats that category; below it, the category wins.
  Tied external priorities stay in their marker's slot.
- Placement: whole numbers when room exists, fractions when crowded, top slot,
  last slot, missing/deselected markers, no ties with external entries;
  AutoCategory's run sort and display key both follow the view (top-slot
  mirroring included).
- Hidden tracker groups and Show/Notify states do not affect matching;
  exclusions, empty patterns, unmatched items, non-ASCII/quoted names.
- Zero scan/compile/write/refresh calls from predicates.
- Missing owned functions/state throw rather than becoming false.

## 4. Activate and project

### Activation and lifecycle

- In [InventoryCompanion_DEV.txt](../../../InventoryCompanion_DEV.txt), add the
  module and AutoCategory as an optional dependency (so it loads first). Call
  `RegisterPlugin` at our `EVENT_ADD_ON_LOADED` after saved rules are ready;
  AutoCategory then calls our init after selecting its profile and before its
  first cache build. Register `ic_group` before definitions.
- Expose explicit absent, disabled, active, and incompatible status. Absence is
  an ordinary optional-dependency condition. If enabled but external contracts
  are unsupported, report it and do not project.
- Validate external API/data shapes at the projection boundary. Call our own
  functions directly after validation.
- Validate/prepare the complete projection before mutation. Lua runs
  synchronously; do not add speculative transactions/rollback. Maintained
  defects throw visibly; external failures are reported; no success is
  announced after an error.

### Synchronization surfaces

Trace every caller of `InvalidateRuleCache` in
[Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) before wiring.
Cover `SetUseCharacterItemList`, `UpdateRulePatterns`, `UpdateRuleProperty`,
`CreateCustomRule`, `DeleteCustomRule`, `ResetRule`, `CopyProfile`, the new
participation/move/marker methods, integration enable/disable, and
AutoCategory's account/character switch.

- Pattern-only edits need a cache refresh but no projection (the predicate reads
  live rules). Renames, participation, order, marker, delete, and profile
  changes need projection.
- Coalesce an edit burst into at most one projection and one refresh per
  affected context. A Bank-only move does not touch Backpack. Pending work uses
  the latest active profile; no stale callback may publish after disable or a
  profile switch. Show/Notify-only changes must not project or refresh.
  Retain existing pickup-notification event registration.

### Adapter regression tests

Extend the focused fixture, not the full dependent addon:

- Absent/incompatible contracts; no expressions execute before registration.
- Enable/project/disable repeated cycles: no duplicates, idempotent, and every
  external entry byte-for-byte unchanged (name, run/show priority, hide state).
- Rename while AutoCategory absent then reload: stale entry removed, renamed
  entry placed at its saved position. Delete removes. Collision skipped before
  registration, with no AutoCategory rename of the user's entry. Another
  character's marked entries are removed. Unmarked entries with our names are
  never touched.
- AutoCategory list reset/emptied: projection restores our entries at their
  saved positions relative to present markers.
- Manual move of our entry in AutoCategory's data is overwritten on the next
  projection.
- Count registrations/writes/cache rebuilds; merely opening or switching the
  editor view does nothing. Real external failures produce explicit status;
  internal failures propagate.

## 5. Add settings, participation, markers, and the ordered group-editor view

### Profile settings and item editor

Add opt-in and compatibility status to
[Core/Settings.lua](../../../Core/Settings.lua). Do not build another Notify
setting. Resolve opt-in against the existing account/character tracked-list
selection and refresh status when that changes. All integration editor
controls are hidden while off/unavailable: view toggle, context selector,
ordering list, arrows, marker selection, and participation. Return an active
AutoCategory view to normal and preserve saved choices. No inactive preview.

In [Tracking/EditPanelItemsTab.lua](../../../Tracking/EditPanelItemsTab.lua)
and [Tracking/EditPanelItemsTab.xml](../../../Tracking/EditPanelItemsTab.xml),
bind the group-only AutoCategory control after Notify to the new participation
mutation. Collapse the existing category-space column to zero width while
disabled/unavailable; reserve one consistent width across row types when active.
Preserve current Show/Notify popups, recycled-row/profile identity checks, name
readability, and row selection.

### Group editor changes

Change [Tracking/EditPanelGroupsTab.lua](../../../Tracking/EditPanelGroupsTab.lua)
and [Tracking/EditPanelGroupsTab.xml](../../../Tracking/EditPanelGroupsTab.xml):

- Extend `InitToolbar` with the AutoCategory view toggle, a seven-context
  dropdown, and a **Choose markers** button. View/context selection is
  transient: no saved writes, projection, or refresh.
- Keep `GetSortedGroupNames` for the normal view. The AutoCategory view lists
  `ResolveAutoCategoryOrder(context)` rows: groups with up/down arrows and
  participation indication; marker rows with a badge and no arrows; then
  never-ordered groups without arrows. Exclude Miscellaneous. Show collision
  warnings on affected group rows. Note that marker order is set in
  AutoCategory's settings.
- Selecting a marker shows its read-only name and filter text; it never binds
  our name/pattern editing, Reset/Delete, or participation controls.
- **Choose markers** opens a checklist of category names present in any of the
  active AutoCategory profile's seven lists, plus selected names that are no
  longer present (shown as missing, removable). Saving calls
  `SetAutoCategoryMarkers` and projects.
- Interaction model: the currency panel's ordering rows in ESO's main game
  settings panel, built by `GetCurrencyPanelSettingsControls` /
  `CreateResourceSettingsList` in
  [Tracking/CurrencyPanel.lua](../../../Tracking/CurrencyPanel.lua). Copy
  `CreateResourceSettingsRow`'s 28-by-26 native `ZO_DefaultButton` up/down arrows,
  hover tooltips, and click sound. Follow its click sequence:
  move / save, reorder rows, highlight moved row, then refresh the affected
  context. Do not call currency-specific helpers. Also keep the group selected
  and scrolled into view.
- The currency implementation clears hidden resources' order. Intentionally do
  not copy that: nonparticipating groups keep their positions.
- Disable endpoint buttons, and all moves while search hides rows, with
  explanatory tooltips.
- Close stale popup/callback state on profile/import/reset/delete/view changes
  using existing editor conventions. No callback may target a recycled row or
  profile.

### Editor regression tests

Extend [GroupEditorTests.lua](../../Tests/GroupEditorTests.lua) and
[ItemEditorTests.lua](../../Tests/ItemEditorTests.lua):

- Toggle/context selector shows the correct rows without writes/projection.
- Up/down past groups and markers persists one context, keeps stable-key
  selection/highlight/visibility, and has correct endpoint/search states.
- Marker rows have no arrows and cannot trigger our name/pattern/Reset/Delete
  handlers. Marker selection adds/removes rows and resolves orphaned `below`.
- Rename cannot reorder a group; deletion and profile/context switches cannot
  reuse stale handlers or change another context's order.
- Category width is zero when inactive and aligned when active. Show/Notify
  unchanged. Extend current runner XML assertions for both layouts.
- Off/missing/incompatible hides every integration control and returns to the
  normal view without writes; re-enabling restores order, markers, and
  participation.
- Native textures, dropdown behavior, scroll visibility, toolbar fit, and label
  readability require in-game verification.

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
  opposite overlap orders, all seven contexts, bank/subscriber bank, groups
  above/below markers with matching headings order (including the provisional
  top-slot mirroring), unchanged AutoCategory entries, a shared AutoCategory
  profile with different character groups, AutoCategory account/character
  switch, editing groups while AutoCategory is disabled, refresh/edit bursts,
  profile/reload, and safe disable.
- Measure the integration-off/on sort and edit-burst baseline. Record item/group
  counts, matcher/refresh counts, timing limits and results, AutoCategory version,
  verified APIs, and keyboard/gamepad support here before completion.
- Update [UserManual.bbcode](../../../UserManual.bbcode) with participation,
  the view toggle, per-context up/down ordering against markers, choosing
  markers, winning-group example, that AutoCategory's own order is set in its
  settings and our entries there are managed by IC, `(!)` rows after
  uninstalling, profile-scoped enable/disable, and saved-data/downgrade
  guidance.
  Update the authoritative working changelog from actual implemented changes
  and follow [ReleaseChecklist.md](../../Publishing/ReleaseChecklist.md).
- Archive only after automated and user-reported in-game acceptance is complete.
  Do not label the current plan as implemented or promise unverified APIs.

## Dependencies and work order

Stage 1 established native insertion; its remaining gates (placement values,
reload, contexts, profile switch) precede live activation. Stage 2 establishes
saved order, markers, participation, and the placement/projection contracts
before stage 3's predicate and stage 5's editor use them. Stage 4 must work
before exposing active participation controls. Stage 6 verifies the completed
runtime/editor work. No live changes bypass the stage 1 exit gate.

Warn and obtain approval before switching to a feature branch for substantial
runtime implementation. These documentation edits do not authorize that work
or changes to installed AutoCategory source/saved variables.
