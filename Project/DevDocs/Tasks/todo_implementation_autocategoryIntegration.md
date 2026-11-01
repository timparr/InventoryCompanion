# AutoCategory integration: IMPLEMENTATION PLAN

Updated 2026-11-01. **Planned; no integration or editor UI is implemented.**
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

- IC stores master anchor/rank placements, sparse context overrides and
  external-heading visibility, and writes only entries it owns.
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

## 1. Save participation, heading visibility and anchor/rank placements

### Proposed representation

Extend [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua), using
stable rule keys and the existing `useCharacterItemList` selection:

```lua
trackedRules = {
    maps = { autoCategoryEnabled = true },
    cyrodiil = { autoCategoryEnabled = true },
}
autoCategoryIntegrationEnabled = true
autoCategoryHiddenHeadings = {}
autoCategoryOrder = {
    master = {
        a = { anchor = "New", rank = 100 },
        b = { anchor = "New", rank = 200 },
        c = { anchor = "Selling", rank = 300 },
        d = { anchor = "Selling", rank = 400 },
    },
    overrides = {
        bank = {
            b = { anchor = "Selling", rank = 350 },
        },
    },
}
```

Names and anchor encoding are provisional, not existing APIs or finalized
schema. Example heading names identify actual AC categories, not hardcoded
English defaults. The top-slot encoding, rank validity, and other unresolved
details remain subject to the [spec refinement](todo_plan_autocategoryIntegration.md#shared-order-and-context-overrides).

- Sparse participation on ordinary rules, missing false; participation applies
  across contexts. Enablement/heading visibility/placements belong to each IC tracked-list
  profile; no separate integration profile switch.
- All available external headings are shown unless hidden in IC; there is no
  selected-marker checklist or special New/Selling/Container/Stolen default set.
  Hidden heading choices are profile-scoped and do not alter AC hide settings.
- The master assigns each ordered group a heading anchor (or top) and rank.
  Context overrides contain only differing anchor/rank fields; omitted fields
  inherit the master. Never save complete resolved lists or group-to-group
  anchor chains. Standard/subscriber Bank share one context.
- Retain placements for nonparticipants; first participation appends a never-
  ordered group to the master top slot. Missing/hidden headings resolve to a
  preceding usable heading/top without read-time writes. Do not invent the
  unresolved fallback or General heading-order rules.
- Never persist compiled patterns/computed priorities or a registry of old
  category names.

### Resolve ranks and clean up spacing

- Resolve inherited/overridden anchor and rank for each group, bucket by usable
  heading and sort by ascending rank. Managed blocks immediately follow their
  heading; native external heading order remains unchanged.
- Enforce no rank ties between different groups in any effective context,
  including retained nonparticipants. Rank allocation considers the master and
  all overrides so a master move cannot collide with another group's context
  rank. Exact allocation/master-edit semantics remain to be refined.
- Implement one profile-wide cleanup: collect all distinct stored ranks,
  sort them, and map them monotonically to new ranks at least 10 apart.
  Apply the same old-to-new mapping to every master/override occurrence.
  Prepare and validate the entire change before saving it.
- Cleanup preserves all seven effective orders, heading anchors and sparse
  inheritance. Never renumber just one context or clean up on view/render.
  IC ordering ranks are distinct from native run/show priorities and D4
  category-name rank prefixes.

### Validation, migration and mutation

- Extend `ValidateSavedRules` and profile/import validation for booleans,
  hidden heading choices, master placements and sparse context overrides.
  Validate recognized context/group keys, anchor/rank shapes and effective
  no-tie invariants after inheritance. Unknown group keys are pruned at load with a reported
  count. Malformed recognized values reject before partial publication.
- Extend `PrepareSavedVariables` to validate every profile and preserve
  unrelated data plus existing v1/v2/v3 migrations before ZOS constructors.
  Recheck current schema; planning version 3 implies next version 4.
- Extend `NormalizeRule` / `PruneRule` and `GetRuntimeRules`; preserve sparse
  participation-only overrides and avoid empty custom groups. Expose
  participation deliberately in `GetActiveTrackedRules` editor copies.
- Proposed narrow mutations: `SetAutoCategoryParticipation`,
  `MoveAutoCategoryGroup(view, ruleKey, direction)`,
  `SetAutoCategoryHeadingHidden(name, hidden)`, plus profile-scoped enablement.
  General moves update the master; context moves update the moved group's
  differing anchor/rank fields. Cleanup may remap all saved ranks but must not
  change any effective order. Override-reset UI/mutations remain undecided.
- `DeleteCustomRule` removes master placement, overrides and participation;
  `ResetRule` retains them.
  `CopyProfile` copies all integration choices without aliasing.
  `SetUseCharacterItemList` selects them consistently.

Extend [SavedVariablesTests.lua](../../Tests/SavedVariablesTests.lua) and
[RulePersistenceTests.lua](../../Tests/RulePersistenceTests.lua):
all-profile migration/import, malformed input/no partial writes, defaults vs
explicit false/empty, proxy-shaped ZO_SavedVars isolation, round-trip/copy,
rename/delete/Reset, heading hide/unhide, master/context moves, partial-field
inheritance, the spec's insertion/master-swap examples, no rank ties, and
cleanup preserving every context order/anchor without materializing overrides.
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
  master placements and sparse overrides, resolves usable heading anchors,
  and sorts each heading bucket by rank in native external heading order.
  `ComputePlacement` uses the spike-supported placement mechanism without
  assuming run/show equality or mirroring. Keep the implementation disabled
  until the post-implementation gate proves the required output shapes.
- Isolate category-name decoration/rank formatting in one helper. The tested
  empty-colour rank prefix is a candidate mechanism, not an approved production
  identity strategy; keep D4 open and do not enable projection with rank-bearing
  names until the author approves the name/collapse-state trade-off.
- Managed blocks must appear immediately below their usable heading, before
  the next external heading, in both classification and display order.
  Respect external priority ties and the immediate lower distinct run gap;
  top is above all external run priorities and last extends down. Prefer whole
  numbers when feasible. Report impossible adjacency instead of changing
  external entries or silently placing another heading inside the block.

Add focused `Project/Tests/AutoCategoryIntegrationTests.lua` with actual AC
modules: opposite overlap order by context, subscriber mapping, heading
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
create/delete/Reset, profile copy/switch, participation/placements/heading visibility/enablement.

- Pattern-only changes need native classification cache invalidation/refresh,
  not assignment projection if labels/order remain unchanged. Renames,
  participation, placements/heading visibility, delete and profile changes require reconciliation.
- Detect actual AC account/character changes and resets, select the latest active
  profile and reproject automatically. Manual probe switches do not supply that
  hook. Trace normal settings failure implications without patching installed AC
  or introducing its nil-global workaround.
- Handle AC edits affecting headings/external priorities while preserving external
  entries. Login with shared AC account/different character IC groups reconciles
  only active owned entries. Disable removes active owned entries; inactive
  residue is reconciled on activation.
- Coalesce bursts to at most one projection and refresh per affected context.
  Bank-only moves do not refresh Backpack. General edits affect contexts whose
  inherited order changes; rank cleanup preserving effective orders does not
  itself require projection/refresh. Stale pending callbacks cannot publish
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
  General/seven-context selector and native ordered rows.
  Normal `GetSortedGroupNames` unchanged; AutoCategory uses master/resolved order,
  heading badges/read-only filter details, group arrows/participation/conflict
  warnings and never-ordered tail. No Miscellaneous or drag/drop.
- External heading rows use normal hide/unhide controls. Add
  **Show all AutoCategory groups** to reveal hidden rows for unhiding; turning
  it off omits them. Revealing a hidden row does not make it an anchor.
  Checkbox changes only editor filtering, with no saved placement changes,
  projection or inventory refresh. Hide/unhide changes effective anchors and
  reconciles affected contexts without changing AC settings.
- Follow [CurrencyPanel.lua](../../../Tracking/CurrencyPanel.lua)
  `GetCurrencyPanelSettingsControls` / `CreateResourceSettingsList` /
  `CreateResourceSettingsRow`: 28-by-26 `ZO_DefaultButton` arrows,
  tooltip/sound/save/reorder/highlight interaction. Do not call currency-specific
  helpers or copy its hidden-resource order pruning; nonparticipants keep order.
- Preserve moved selection/scroll. Disable endpoint/search moves. Close stale
  popup/callbacks on profile/import/reset/delete/view changes using existing
  patterns; external heading selection must never bind editable group actions.
  Override indicators/reset controls await author refinement; do not invent
  their behavior while implementing the agreed master/rank model.
- D2: decide final texture identity/tint, convert chosen v5 plain SVG to 64x64
  DXT5 DDS/alpha and verify asset path. New asset needs game restart. Do not add
  badge UI/colour settings from D3 without separate author decision.

Extend [GroupEditorTests.lua](../../Tests/GroupEditorTests.lua) and
[ItemEditorTests.lua](../../Tests/ItemEditorTests.lua): zero writes on view/context
selection, Show-all zero writes/projections/refreshes, hide/unhide reference
behavior, row ordering/selection/endpoints/search, external-heading restrictions,
rename/delete/recycled callbacks, profile isolation, width and inactive layout,
Show/Notify unchanged, and XML assertions. Verify toolbar fit, native dropdown/
arrows, tint/readability and scrolling in ESO.

## 5. Post-implementation verification and release

These are completion gates after the feature and its tests are implemented,
not work to perform before implementation starts. Do not repeat completed spike
steps. Use the actual integration adapter and UI; record observed limits and
results in [AutoCategorySpikeResults.md](AutoCategorySpikeResults.md).

- **Q1/Q2:** verify the implemented output in top, crowded, heading-anchor, arbitrary
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
  Bank, top/crowded/immediately-below-heading order, all edits, both profile modes and shared
  character groups, automatic switching, resets, reload/disable/uninstall,
  edit-while-absent, immutable external entries, new-schema downgrade safety.
- Check Lua/XML, paths/whitespace, new textures against
  [ESO-Game-Textures.md](../../Resources/ESO-Game-Textures.md), and documentation links.
  Record version, supported contracts, precise context/platform limits, workload/
  timings and dated offline/ESO results in the spike/results record.
- Update [UserManual.bbcode](../../../UserManual.bbcode): participation,
  General/context inheritance, ranks/cleanup, view/arrows/heading hide/unhide
  and Show-all controls, overlap examples, owned settings moves overwritten,
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
