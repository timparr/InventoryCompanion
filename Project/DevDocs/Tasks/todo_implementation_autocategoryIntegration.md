# AutoCategory integration: IMPLEMENTATION PLAN

Updated 2026-10-31. **Planned; no integration or editor UI is implemented.**
The [spec](todo_plan_autocategoryIntegration.md) owns required behavior and open
decisions; the [spike results](AutoCategorySpikeResults.md) own completed spike
evidence, failed approaches and dependency contracts. See the [review](AutoCategoryIntegrationReview.md)
for the assessment and concrete recommendations.

## Implementation sequence

Implementation starts with the saved representation and migration, then the
native predicate/adapter, lifecycle synchronization, and editor/settings UI.
The completed spike is the evidence base; **do not schedule more standalone
pre-implementation tests or repeat completed spike work**. Build and validate
the feature as implementation proceeds. Remaining assumptions are checked
against the implemented feature in the post-implementation gate below, before
integration activation or release. If a requirement cannot be met, keep
integration disabled and return the design decision to the author; do not
silently weaken the spec or take over AutoCategory behavior.

- IC stores per-context order/markers and writes only entries it owns.
  AutoCategory continues native classification and rendering. Do not replace
  `MatchCategoryRules`, edit external entries/source, or project to inactive
  AutoCategory profiles.
- Preserve the spike's limits: sampled rank prefixes are not proof of unlimited
  placement, and external run/show mismatches remain unresolved. Rank-bearing
  category names and their collapse-state consequences remain **D4**, an author
  decision; do not assume production adoption from test success.
- Keep integration opt-in and disabled until post-implementation acceptance
  passes. Q1-Q5 and Guild Bank are post-implementation verification, not
  pre-implementation research gates.
- Schema safety is a hard boundary: verify downgrade rejection on synthetic
  data before loading the new schema with normal game saves.
- D2 asset identity/tint must be decided before final publication. D3 badge UI
  remains separate from the plain-heading scope. D1 applies if implementation
  cannot satisfy the unchanged ordering requirements.
- This is substantial runtime work on the current branch; discuss branch/risk
  before implementation and do not switch branches without author approval.

## 1. Save participation, order and markers

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

### Validation, migration and mutation

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
As part of post-implementation verification, execute a real pre-feature build
on new-schema synthetic fixtures and prove rejection before mutation.
**Do not load new fields on normal game saves until this downgrade check passes.**

## 2. Implement native predicate and placement

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
  `ComputePlacement` uses the spike-supported placement mechanism without
  assuming run/show equality or mirroring. Keep the implementation disabled
  until the post-implementation gate proves the required output shapes.
- Isolate category-name decoration/rank formatting in one helper. The tested
  empty-colour rank prefix is a candidate mechanism, not an approved production
  identity strategy; keep D4 open and do not enable projection with rank-bearing
  names until the author approves the name/collapse-state trade-off.
- Below marker M: inside the immediate lower distinct external run gap, after
  every entry tied with M. Top above all external run priorities; last extends
  down. Prefer whole numbers when feasible; preserve managed heading sequence
  in fractional cases. Write no external entry.

Add focused `Project/Tests/AutoCategoryIntegrationTests.lua` with actual AC
modules: opposite overlap order by context, subscriber mapping, marker
precedence/ties, top/crowded/bottom/arbitrary labels, hidden/external run/show
differences, no-match/participation fallthrough, exclusions/empty patterns,
non-ASCII/quoted names, missing owned state, and zero scan/compile/write/refresh
from classification. Include the required Q1/Q2 output shapes and known
unsupported bounds; do not create an alternate pre-implementation spike.

## 3. Wire registration, projection and synchronization

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

## 4. Add settings and editor after the adapter works

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

## 5. Post-implementation verification and release

These are completion gates after the feature and its tests are implemented,
not work to perform before implementation starts. Do not repeat completed spike
steps. Use the actual integration adapter and UI; record observed limits and
results in [AutoCategorySpikeResults.md](AutoCategorySpikeResults.md).

- **Q1/Q2:** verify the implemented output in top, crowded, marker, arbitrary
  label and external run/show mismatch cases. Confirm both winning classification
  and native heading order, not just priority values or formatter output. Check
  finite rank/priority bounds and visible failure for unsupported layouts.
  Sampled spike passes do not certify all category names or priorities.
- **D4:** confirm whether rank-bearing prefixes are approved for production
  names, including name/collapse-state behavior. If not approved, do not enable
  integration with those names; return the choice to the author.
- **Q3:** verify automatic edits, profile switches, disable, cache invalidation,
  reclassification and affected-context refresh through the implemented hooks.
- **Q4:** verify migration/import across profiles and old-build downgrade
  rejection on synthetic saves before any normal-save testing.
- **Q5:** agree workload and numerical timing limits when preparing the
  post-implementation measurement; count matchers, scans, compilation,
  projection writes and refreshes, then measure off/on sort and edit bursts.
  Synthetic checks never mutate live inventory or saved variables.
- Guild Bank remains untested in the spike. Verify the implemented native path
  in the required keyboard context matrix; if the known BulkMode path bypass
  prevents the spec behavior, stop and discuss scope/design rather than count it
  as passed. Do not claim gamepad, untested crafting tabs, or merchant modes.

- Wire focused suites into [Run-RuleTests.py](../../Tests/Run-RuleTests.py) and
  use the existing Lua setup. Run smallest relevant suite first; full related
  runner for completed cross-surface integration.
- Preserve [ItemNotificationTests.lua](../../Tests/ItemNotificationTests.lua)
  destination/hidden-rule/listener/duplicate coverage. Extend existing in-game
  rule tests only for safe matching/synthetic workload.
- Execute every [spec acceptance criterion](todo_plan_autocategoryIntegration.md#acceptance-criteria):
  all seven keyboard contexts, subscriber
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

- [ ] Q1/Q2: post-implementation classification and native heading-order checks
      pass for the supported contract; unsupported cases fail visibly.
- [ ] Q3: automatic CRUD, profile hook, cache/refresh and disable pass.
- [ ] Q4: migration/import/downgrade pass on synthetic data before normal saves.
- [ ] Q5: workload/threshold agreement and post-implementation measurement pass.
- [ ] D1 author approval if a revised strategy is needed; otherwise not applicable.
- [ ] D2 final asset identity/tint approved and asset verified.
- [ ] D3 optional badge decisions only if separately taken into scope.
- [ ] D4 prefix-name adoption approved, or another approved identity strategy
      is used.
- [ ] Guild Bank passes the implemented seven-context keyboard matrix.
- [ ] Probe Debug/report housekeeping completed.
- [ ] Pre-shipping spike teardown: manifest entry removed, source retained
  outside runtime loading, offline reuse validated, no gate registrations or
  tagged assignments remain.
