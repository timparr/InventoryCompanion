# AutoCategory integration: IMPLEMENTATION PLAN

Updated 2026-10-31. **Planned; no integration or editor UI is implemented.**
The [spec](todo_plan_autocategoryIntegration.md) owns required behavior and open
decisions; the [spike results](AutoCategorySpikeResults.md) own evidence, failed
attempts and reusable AutoCategory contracts. Do not treat proposed names below
as existing APIs or spike passes as completed production stages.

## Handoff and dependencies

- Native insertion is the chosen strategy. IC stores its own per-context group
  order/markers; AC receives only owned assignments. Do not replace
  `MatchCategoryRules`, edit external entries/source, or silently change the
  design when a placement fails.
- **Q1/Q2 block live activation:** no proven top-heading mapping; general crowded
  ordering and differing external run/show orders unresolved. Native rendering
  must match classification/editor order, not merely accept priority values.
- **Q3 remains implementation research:** manual switching/projection/reloads
  passed, but automatic integration hooks and full dynamic CRUD are unbuilt.
- **Q4 must pass before normal saves:** schema/downgrade safety. **Q5** workload
  and timing thresholds must be agreed before performance acceptance.
- **D2** asset path/tint must be decided before final publication. **D3** badge
  UI is separate, not a plain-heading prerequisite. If ordering cannot satisfy
  the unchanged spec, stop for **D1** author decision.
- Guild Bank is deferred to later DEV testing, not removed from acceptance.
  Do not claim gamepad or untested crafting/merchant modes are certified.
- This task stays on current `main`, changes documentation/probes only and
  authorizes no production implementation. Before substantial runtime work,
  warn about branch/risk and obtain approval before switching branches.

Dependency order:

1. Close Q1/Q2 and record approved placement contract before live projection.
2. Establish saved representation, migration and downgrade Q4 before normal data.
3. Implement predicate plus adapter/lifecycle Q3 using that contract.
4. Adapter must work before active settings/participation/editor controls.
5. Complete keyboard/context/behavior/performance acceptance and publication.

Pure tests/research can precede their runtime dependencies; no live activation
bypasses ordering or saved-data safety. Deferred contexts remain release gates.

## 1. Close ordering blockers before live activation

Read [dependency contracts and prior failures](AutoCategorySpikeResults.md#dependency-contracts-and-source-trail)
instead of redoing baseline load-order research. Recheck if AC version changes.
Reuse [AutoCategorySpike.lua](../../../Core/AutoCategorySpike.lua) and its
[real-module fixture](../../Tests/AutoCategorySpikeTests.lua).

### Q1: top placement

- Trace actual native show-key comparison and classification priority ordering.
  Explore independent run/show mappings only as explicit candidates.
  Equal run/show >1000 and mirroring that stays above 1000 are not solutions;
  negative values have not been tested.
- Prove many managed headings above external headings in saved order while
  retaining native classification and every external entry unchanged.
  Include external high priorities and arbitrary labels; no hardcoded default-
  only solution.
- Validate offline first with the existing spike runner, then give one
  reversible DEV command and wait for ESO's copyable report. Measure actual
  native heading order, not formatter success.

### Q2: crowded and external-order cases

- Test more managed entries than whole-number slots, gaps narrower than one,
  identical formatted integer keys, reversed alphabetical managed labels,
  equal external priorities, no markers/entries, bottom slots and hidden or
  unmatched immediate anchors.
- Allocation must respect all external run priorities, even invisible headings.
  Visible rendering anchors can be farther away than numerical gap bounds.
- Test existing categories whose run/show orders differ. Determine whether
  unchanged native rendering can satisfy the required view/heading order.
  Do not assume distinct fractional priorities avoid display-key ties.
- Record precise supported range/algorithm and residual limitations. If no safe
  mapping exists, present D1 alternatives before changing semantics, adding
  group caps, changing names to force sort, or taking over rendering/classification.

### Stage exit and probe housekeeping

Close Q1/Q2 with offline and ESO evidence plus any required author decision.
Do not repeat already-passed lifecycle/context samples just to change key
bindings. Guild Bank remains deferred by the author.

At the end of the probe phase, remove its temporary Debug override so
[Core/Init.lua](../../../Core/Init.lua) uses `this.RunTests("verbose copy")`;
update the corresponding offline expectation and stale profile report
instructions to explicit commands. This is **pending**, not done by this
documentation consolidation. Original account-wide mode and exact tagged
assignment cleanup already passed; code-defined DEV gate plugin remains.

## 2. Save participation, order and markers

### Proposed representation

Extend [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua), using
stable rule keys and the existing `useCharacterItemList` selection:

```lua
trackedRules = {
    maps = { autoCategoryEnabled = true },
    cyrodiil = { autoCategoryEnabled = true },
}
autoCategoryIntegrationEnabled = true
autoCategoryMarkers = { "New", "Selling", "Container", "Stolen" }
autoCategoryOrder = {
    [AC_BAG_TYPE_BACKPACK] = {
        { ruleKey = "plunder" },
        { ruleKey = "maps", below = "New" },
        { ruleKey = "cyrodiil", below = "New" },
    },
}
```

Names are targets, not existing fields. Example marker names stand for actual
localized AC identities resolved through `SI_AC_DEFAULT_CATEGORY_*`.

- Sparse participation on ordinary rules, missing false; participation applies
  across contexts. Enablement/markers/order belong to each IC tracked-list
  profile; no separate integration profile switch.
- Missing markers resolves documented defaults; explicit empty list is valid.
  `autoCategoryOrder` has seven independent ordered lists of `{ ruleKey, below? }`.
  Absent `below` means top. Retain order for nonparticipants; append never-
  ordered groups to top when first enrolled.
- Resolve missing/deselected markers into preceding valid slot/top, without
  read-time writes. Test reconstructing the spec's ordering after AC changes;
  do not guess silently if the proposed representation proves insufficient.
- Never persist compiled patterns/computed priorities or a registry of old
  category names.

### Validation, migration and mutation (Q4)

- Extend `ValidateSavedRules` and profile/import validation for booleans,
  markers (nonempty-string array) and context order (valid entries, no duplicate
  keys per context). Unknown group keys are pruned at load with a reported
  count. Malformed recognized values reject before partial publication.
- Extend `PrepareSavedVariables` to validate every profile and preserve
  unrelated data plus existing v1/v2/v3 migrations before ZOS constructors.
  Recheck current schema; planning version 3 implies next version 4.
- Extend `NormalizeRule` / `PruneRule` and `GetRuntimeRules`; preserve sparse
  participation-only overrides and avoid empty custom groups.
- Proposed narrow mutations: `SetAutoCategoryParticipation`,
  `MoveAutoCategoryGroup(context, ruleKey, direction)`,
  `SetAutoCategoryMarkers(names)`, plus profile-scoped enablement.
  Move swaps neighbours or changes marker slot; only selected context changes.
- `DeleteCustomRule` removes order/participation; `ResetRule` retains them.
  `CopyProfile` copies all integration choices without aliasing.
  `SetUseCharacterItemList` selects them consistently.

Extend [SavedVariablesTests.lua](../../Tests/SavedVariablesTests.lua) and
[RulePersistenceTests.lua](../../Tests/RulePersistenceTests.lua):
all-profile migration/import, malformed input/no partial writes, defaults vs
explicit false/empty, proxy-shaped ZO_SavedVars isolation, round-trip/copy,
rename/delete/Reset, marker/group moves, endpoints and Bank/Backpack independence.
Execute a real pre-feature build on new-schema synthetic fixtures and prove
rejection before mutation. **Do not test new fields on normal game saves first.**

## 3. Implement native predicate and placement

Add one focused module, provisionally
`Tracking/AutoCategoryIntegration.lua`, using existing helpers/patterns.

- Register `ic_group(ruleKey)` using `GetRuntimeRules` and
  `ItemMatchesRuntimeRule(AutoCategory.checkingItemLink, rules[ruleKey])`.
  Integration disabled/nonparticipating legitimately returns false; unknown
  keys or missing owned state in our registered expression are defects and throw.
- Escape keys as Lua string literals; names are labels, not identity.
  No duplicated matcher, scan, compilation, projection, sort or notification.
- Per classified item, at most one existing matcher call for each managed entry
  AC evaluates before its first match. Rely on native first-match dispatch,
  not a precomputed managed winner.
- Pure proposed `ResolveAutoCategoryOrder(context)` combines saved group
  positions with active markers in native run order.
  `ComputePlacement` uses the **Q1/Q2-approved mapping**, with separate run/show
  outputs where required, never an assumed equality/mirroring formula.
- Below marker M: inside the immediate lower distinct external run gap, after
  every entry tied with M. Top above all external run priorities; last extends
  down. Prefer whole numbers when feasible; preserve managed heading sequence
  in fractional cases. Write no external entry.

Add focused `Project/Tests/AutoCategoryIntegrationTests.lua` with actual AC
modules: opposite overlap order by context, subscriber mapping, marker
precedence/ties, top/crowded/bottom/arbitrary labels, hidden/external run/show
differences, no-match/participation fallthrough, exclusions/empty patterns,
non-ASCII/quoted names, missing owned state, and zero scan/compile/write/refresh
from classification. Include the exact approved Q1/Q2 output shapes.

## 4. Wire registration, projection and synchronization (Q3)

### Registration and ownership

- Add optional dependency/module to the appropriate DEV/release manifests when
  implementing. DEV already declares optional AC for the spike; release is not
  wired. Keep IC functional without AC.
- Register on IC's own `EVENT_ADD_ON_LOADED` after AC's event completes and IC
  groups are ready, before AC player activation. AC plugin init occurs after
  active-profile selection and before initial caches. Supply the real predicate
  before evaluation; no omitted-function dummy or pretend late registration.
- Preflight every proposed decorated definition against runtime/default/plugin
  and saved definitions plus both profiles' assignments. Unowned conflicts
  are skipped/reported before AC can rename/redirect existing categories.
- Plugin predefines supply stable-key expressions every session, including
  deliberately disabled behavior while integration off. No writes to AutoCatRules.
  Trace dynamic additions/removals/renames after startup; do not infer CRUD from
  `RegisterPlugin` or direct cache insertion alone.
- Proposed `ProjectAutoCategory()` is the sole production AC assignment writer.
  Validate external shapes and prepare the complete change set before mutation.
  Touch only `icOwned = true` entries in the active profile's seven lists:
  remove unwanted/stale, add missing, update changed run/show values.
  No label-based ownership, inactive writes, or external reorder.
- Rebuild only affected cache layers using verified error conventions. Explicit
  absent/disabled/active/incompatible status; external failures reported,
  required IC functions/state called directly. No speculative transaction/
  rollback system or success report after failure.

### Required synchronization

Trace every `InvalidateRuleCache` caller in
[ItemDatabase.lua](../../../Tracking/ItemDatabase.lua): pattern/property updates,
create/delete/Reset, profile copy/switch, participation/order/marker/enablement.

- Pattern-only changes need native classification cache invalidation/refresh,
  not assignment projection if labels/order remain unchanged. Renames,
  participation, order/markers, delete and profile changes require reconciliation.
- Detect actual AC account/character changes and resets, select the latest active
  profile and reproject automatically. Manual probe switches do not supply that
  hook. Trace normal settings failure implications without patching installed AC
  or introducing its nil-global workaround.
- Handle AC edits affecting markers/external priorities while preserving external
  entries. Login with shared AC account/different character IC groups reconciles
  only active owned entries. Disable removes active owned entries; inactive
  residue is reconciled on activation.
- Coalesce bursts to at most one projection and refresh per affected context.
  Bank-only moves do not touch Backpack. Stale pending callbacks cannot publish
  after disable/profile switch; Show/Notify-only edits do no integration work.
- Verify reclassification, not just redraw: keyboard rows cache AC timestamps/
  hashes; true does not force reevaluation. Crafting preview/restore require
  false. Use the narrow verified refresh surface; test production affected-row
  invalidation rather than copying the one-row probe as a complete solution.

Adapter tests: absent/incompatible/lifecycle, all seven synthetic lists, repeated
enable/disable/edit/reload/profile cycles, idempotent writes/definitions, collision
refusal, stale rename/delete/other-character removal, reset/empty lists, manual
owned moves overwritten, external entries byte-for-byte unchanged, inactive
profiles unchanged, automatic profile hook and pending-callback races.
Count registrations/writes/cache rebuilds/refreshes; inject failures visibly.

## 5. Add settings and editor only after adapter works

- [Core/Settings.lua](../../../Core/Settings.lua): opt-in/status tied to IC
  profile selection, no new Notify controls or inactive preview.
- [EditPanelItemsTab.lua](../../../Tracking/EditPanelItemsTab.lua) /
  [XML](../../../Tracking/EditPanelItemsTab.xml): ordinary-group AutoCategory
  toggle after Notify, aligned active width/zero inactive width; preserve existing
  Show/Notify popups, name readability, selection and recycled-row/profile checks.
- [EditPanelGroupsTab.lua](../../../Tracking/EditPanelGroupsTab.lua) /
  [XML](../../../Tracking/EditPanelGroupsTab.xml): toolbar view toggle,
  seven-context selector, marker chooser and native ordered rows.
  Normal `GetSortedGroupNames` unchanged; AutoCategory uses resolved order,
  marker badges/read-only filter details, group arrows/participation/conflict
  warnings and never-ordered tail. No Miscellaneous or drag/drop.
- Marker checklist includes active categories across contexts and removable
  missing selections; save invokes marker mutation and affected reconciliation.
- Follow [CurrencyPanel.lua](../../../Tracking/CurrencyPanel.lua)
  `GetCurrencyPanelSettingsControls` / `CreateResourceSettingsList` /
  `CreateResourceSettingsRow`: 28-by-26 `ZO_DefaultButton` arrows,
  tooltip/sound/save/reorder/highlight interaction. Do not call currency-specific
  helpers or copy its hidden-resource order pruning; nonparticipants keep order.
- Preserve moved selection/scroll. Disable endpoint/search moves. Close stale
  popup/callbacks on profile/import/reset/delete/view changes using existing
  patterns; marker selection must never bind editable group actions.
- D2: decide final texture identity/tint, convert chosen v5 plain SVG to 64x64
  DXT5 DDS/alpha and verify asset path. New asset needs game restart. Do not add
  badge UI/colour settings from D3 without separate author decision.

Extend [GroupEditorTests.lua](../../Tests/GroupEditorTests.lua) and
[ItemEditorTests.lua](../../Tests/ItemEditorTests.lua): zero writes on view/context
selection, row ordering/selection/endpoints/search, marker restrictions,
rename/delete/recycled callbacks, profile isolation, width and inactive layout,
Show/Notify unchanged, and XML assertions. Verify toolbar fit, native dropdown/
arrows, tint/readability and scrolling in ESO.

## 6. Acceptance, performance and release

- Wire focused suites into [Run-RuleTests.py](../../Tests/Run-RuleTests.py) and
  use the existing Lua setup. Run smallest relevant suite first; full related
  runner for completed cross-surface integration.
- Preserve [ItemNotificationTests.lua](../../Tests/ItemNotificationTests.lua)
  destination/hidden-rule/listener/duplicate coverage. Extend existing in-game
  rule tests only for safe matching/synthetic workload.
- **Q5 first:** agree inventory/group/burst sizes and numerical timing limits;
  count matchers, scans, compilation, projection writes and refreshes, then
  measure integration off/on sort and edit-burst baselines. Synthetic checks
  never mutate live inventory or saves. Timing alone is insufficient.
- Execute every [spec acceptance criterion](todo_plan_autocategoryIntegration.md#acceptance-criteria):
  all seven keyboard contexts (Guild still needs later DEV evidence), subscriber
  Bank, top/crowded/marker heading order, all edits, both profile modes and shared
  character groups, automatic switching, resets, reload/disable/uninstall,
  edit-while-absent, immutable external entries, new-schema downgrade safety.
- Check Lua/XML, paths/whitespace, new textures against
  [ESO-Game-Textures.md](../../Resources/ESO-Game-Textures.md), and documentation links.
  Record version, supported contracts, precise context/platform limits, workload/
  timings and dated offline/ESO results in the spike/results record.
- Update [UserManual.bbcode](../../../UserManual.bbcode): participation,
  view/arrows/markers, overlap examples, owned settings moves overwritten,
  collapse residue, uninstall `(!)` rows, active-profile scope, compatibility,
  performance and saved-data/downgrade behavior.
- **Before shipping, tear down the DEV spike runtime:** remove
  `Core/AutoCategorySpike.lua` from the DEV manifest and relocate the probe
  source to a clearly non-loaded development/test location for possible reuse.
  Keep its offline fixtures/runner usable, updating paths and validating them
  after relocation. No spike slash commands, event handlers, gate plugin or
  Debug override may remain registered by the shipped runtime; normal
  `RunTests("verbose copy")` Debug behavior must be restored. Do not remove the
  production integration module or its required optional AutoCategory
  dependency. Verify exact-token cleanup of any remaining test assignments
  before unloading the cleanup command, then reload to verify the gate plugin
  and commands are absent and production integration still works. Record this
  teardown evidence in SPIKE RESULTS.
- Update authoritative working changelog from actual implementation first;
  follow [ReleaseChecklist.md](../../Publishing/ReleaseChecklist.md) for numbering,
  approval and publication. Archive only after automated and user-reported
  acceptance. Do not call planned APIs implemented or untested behavior supported.

## Open-question closure checklist

- [ ] Q1 top placement: offline + actual ESO order.
- [ ] Q2 crowded/arbitrary labels/external run-show differences: approved contract.
- [ ] Q3 dynamic CRUD, auto-profile hook, cache/refresh and disable: wired/tested.
- [ ] Q4 migration/import/downgrade: synthetic safety before normal data.
- [ ] Q5 workload/threshold agreement and measured acceptance.
- [ ] D1 author approval if a revised strategy is needed; otherwise not applicable.
- [ ] D2 final asset identity/tint approved and asset verified.
- [ ] D3 optional badge decisions only if separately taken into scope.
- [ ] Deferred Guild Bank tested in later DEV; full seven-context keyboard matrix.
- [ ] Probe Debug/report housekeeping completed.
- [ ] Pre-shipping spike teardown: manifest entry removed, source retained
  outside runtime loading, offline reuse validated, no gate registrations or
  tagged assignments remain.
