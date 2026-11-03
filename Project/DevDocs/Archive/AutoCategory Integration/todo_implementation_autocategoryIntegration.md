# AutoCategory integration: IMPLEMENTATION PLAN

**ARCHIVED 2026-11-03.** Historical plan, not current work instructions;
use the [master feature document](../../AutoCategoryIntegration.md) and its
linked current implementation document.

Updated 2026-11-01. **Implemented; automated tests pass, but post-implementation
compatibility acceptance is incomplete.** See the
[implementation report](AutoCategoryImplementationReport.md) for delivered
work, verification, deviations and remaining gates.
The [spec](todo_plan_autocategoryIntegration.md) owns required behavior and open
decisions; the [spike results](AutoCategorySpikeResults.md) own completed spike
evidence, failed approaches and dependency contracts. See the [review](AutoCategoryIntegrationReview.md)
for the assessment and concrete recommendations.

Use the [spec terminology](todo_plan_autocategoryIntegration.md#terminology):
groups are IC groups; headings are external AC category references unless
explicitly called managed headings. Master combines context-labelled heading
occurrences and shared placements, not a native AC context.

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
  `AutoCategory_API.MatchCategoryRules`, edit external entries/source, or project to inactive
  AutoCategory profiles.
- Preserve the spike's limits: sampled rank prefixes are not proof of unlimited
  placement, and external run/show mismatches remain unresolved. Rank-bearing
  category names are approved under **D4** (2026-11-01): the author accepts
  expanded-after-reorder behavior and retained old per-name collapse flags.
  This approval does not waive post-implementation acceptance or placement limits.
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

Method references use `FileName.MethodName` to identify their source file,
not to prescribe Lua namespaces. Proposed methods name their intended file.

Extend [Tracking/ItemDatabase.lua](../../../../Tracking/ItemDatabase.lua), using
stable rule keys and the existing `useCharacterItemList` selection:
the example's `trackedRules` is `character.trackedRules` when that flag is true,
otherwise `accountWide.trackedRules`. Profile-level integration state uses the
same selected profile; this does not change the existing account/character split.

```lua
trackedRules = {
    a = {
        autoCategoryEnabled = true,
        autoCategoryAnchor = "New",
        autoCategoryRank = 100,
    },
    b = {
        autoCategoryEnabled = true,
        autoCategoryAnchor = "New",
        autoCategoryRank = 200,
        autoCategoryOverrides = {
            bank = { anchor = "Selling", rank = 350 },
        },
    },
    c = {
        autoCategoryEnabled = true,
        autoCategoryAnchor = "Selling",
        autoCategoryRank = 300,
    },
    d = {
        autoCategoryEnabled = true,
        autoCategoryAnchor = "Selling",
        autoCategoryRank = 400,
    },
}
autoCategoryIntegrationEnabled = true
autoCategoryOrder = {
    headingVisibility = {
        ["new-shared-occurrence"] = false,
    },
    overrides = {
        bank = {
            headings = {
                ["new-shared-occurrence"] = true,
            },
        },
    },
}
```

Names and anchor encoding are provisional, not existing APIs or finalized
schema. Example heading names identify actual AC categories, not hardcoded
English defaults. Product behaviour remains subject to the
[spec refinement](todo_plan_autocategoryIntegration.md#shared-order-and-context-overrides);
top/bottom/default-New placement encoding, rank validity and insertion/cleanup triggers are
implementation details to settle here without changing that behaviour.
In differing-order cases, an anchor must distinguish the selected Master
heading occurrence and its applicability, not just the AC category name.
The simple string anchors above assume a shared occurrence; finalize occurrence
identity/encoding before implementing persistence.

- Sparse participation on ordinary rules, missing false; participation applies
  across contexts. Enablement/heading visibility/placements belong to each IC tracked-list
  profile; no separate integration profile switch.
- All available external headings are shown unless hidden in IC; there is no
  selected-marker checklist or special New/Selling/Container/Stolen default set.
  Master occurrence visibility is profile-scoped, defaults to visible, and does
  not alter AC hide settings. Key visibility by occurrence identity, not category
  name; a native context heading maps to its corresponding Master occurrence.
- Store each group's Master placement on its saved rule as
  `autoCategoryAnchor` and `autoCategoryRank`, alongside participation.
  Do not duplicate these fields in a profile-level Master map. Rank alone
  cannot identify its heading slot. Both placement fields are absent for a
  never-ordered group; ordered groups have a valid anchor and rank, including
  an explicit encoding for top rather than treating a missing anchor as top.
  Profile-level state holds enablement, initialization, heading visibility
  and heading visibility overrides, not a second copy of group placements.
- Store sparse context placement overrides on the same saved rule in
  `autoCategoryOverrides[context]`. Each entry contains only overridden
  anchor/rank fields; omitted fields inherit that rule's Master placement.
  Do not duplicate group overrides in a profile-level map. External headings
  are not IC groups, so their visibility overrides remain profile-level.
  Explicit true/false heading visibility is a
  local override, including when a later Master change agrees with it.
  Never save complete resolved lists or group-to-group anchor chains.
  Standard/subscriber Bank share one context.
- Derive effective visibility per native context from occurrence visibility and
  its context override. Derive Master labels and row inclusion from that result;
  do not persist another per-context hide list or derived row visibility flag.
  Visibility edits never change native occurrence scope or identity.
- Retain placements for nonparticipants; enabling a group without a placement
  inserts it immediately after the last participating IC group in Master,
  or at the bottom of Master if none participate. Apply this to existing and
  newly created groups alike; reuse any saved placement on off/on. Allocate
  its anchor/rank using the normal insertion mechanism, not the prior preset
  choice or a group-to-group anchor. Missing/hidden headings resolve to a
  preceding applicable, IC-unhidden occurrence in the combined Master sequence,
  or top, without read-time writes or newly materialized context overrides.
- Never persist compiled patterns/computed priorities or a registry of old
  category names.

### Initialize presets and reset placements

- Implement the [preset/reset UX](todo_plan_autocategoryIntegration.md#starting-presets-and-order-reset).
  On first enablement of an uninitialized profile, present both presets with
  Prefer IC groups preselected. Prepare the arrangement before publishing
  enablement; cancellation preserves prior state. Re-enable initialized
  profiles without reapplying defaults.
- Prefer IC groups resolves the localized default New identity in each context
  (only when available and IC-unhidden), otherwise top. Prefer AutoCategory
  groups resolves below every external assignment, including IC-hidden
  reference headings. Sort initial groups by display name with a stable-key
  secondary comparison for equal names; assign distinct ranks.
- Represent these preset placements without duplicating IC group rows or
  creating seven complete lists. A single occurrence-name anchor is insufficient
  for defaults that must resolve across different New occurrences or context
  bottom positions. Finalize explicit default-New/bottom placement encoding
  in the schema; do not silently generate user context overrides.
- Presets initialize ordinary group placements independently of participation.
  Persist the resulting placements and profile initialization state, not the
  user's preset choice. Do not retain a preferred-preset field or consult the
  previous choice when placing newly created or newly participating groups.
  Subsequent moves replace the applicable placement normally; do not reapply
  the preset after initialization.
- Master Reset to defaults presents the same chooser, warns about replacement
  and updates Master while retaining context overrides. Context Reset to Master
  clears only that context's group-placement overrides, retaining its heading
  visibility overrides. Preserve hidden-heading choices,
  participation and all unrelated settings. Do not add individual-group
  override indicators or reset controls; show effective order and provide
  only the whole-context Reset to Master.
- Validate/copy/migrate the initialization and resulting placement state alongside
  existing master/context data. Check cancellation, first-enable versus
  re-enable, both preset outcomes across all seven synthetic contexts,
  missing/hidden New, different New occurrences and native last headings,
  retained overrides on Master reset, and isolated context reset.

### Combine native heading lists for Master

- Build a context-labelled sequence of heading occurrences from the active
  AC profile's seven native lists. Share occurrences where ordering permits;
  repeat AC headings where needed to represent conflicting native positions.
  Filtering by any context must reproduce its exact native heading sequence.
  No external category or assignment is duplicated or reordered by this UI.
- Show the occurrence's context scope explicitly, including "Bank only" and
  multi-context labels. Ordinary labels list effectively anchor-visible contexts,
  not hidden ones. Omit an occurrence when none remain; Show-all reveals the
  original native scope and hidden contexts, including partially hidden rows.
  Keep the full underlying sequence for identity and fallback resolution;
  filtering visibility must not rebuild native scopes or discard placements.
  Each IC group has one Master placement and one Master
  row; exceptions use existing sparse context overrides, not duplicated groups.
- For a Master anchor inapplicable to a context, walk upward through the
  combined heading occurrences to the nearest applicable, IC-unhidden one,
  or top. Bucket by the resulting native heading and retain rank sorting.
  Do not erase saved anchors, treat applicability as AC hide state, or save
  fallback results as context overrides.
- Choose a deterministic combination and occurrence-identity mechanism during
  implementation. Preserve placement identities through rebuilding; opening
  or switching views must not write settings. When an external heading is
  deleted/renamed, resolve upward from the group's placement in the current
  list to the nearest currently valid anchor, or top; do not bind fallback to
  a heading selected historically. Preserve enough occurrence/placement identity
  to locate that position through rebuilding without rewriting saved group
  placements. The representation is an implementation decision, not an open
  product decision. Do not assume a
  minimal-duplicate optimization or add standalone spike tests.

### Resolve ranks and clean up spacing

Implement the [shared-order UX](todo_plan_autocategoryIntegration.md#shared-order-and-context-overrides):
moving B between C and D in Bank changes only Bank's placement and preserves
that location when unrelated parts of the list change. When inherited neighbours
move in Master, they can pass the overridden group: its rank/anchor overrides
remain unchanged. This behaviour is confirmed; retain the algorithm rather
than introducing neighbour-following relationships.

- Resolve inherited/overridden anchor and rank for each group, bucket by usable
  heading and sort by ascending rank. Managed blocks immediately follow their
  heading; native external heading order remains unchanged.
- Master placements resolve context-labelled occurrences first; a context
  override resolves its selected heading in that context. Combined-row
  presentation does not replace the established independent anchor/rank model.
- Anchor to an external heading or top, never another IC group. A context
  override can independently replace anchor and/or rank; other fields inherit.
  Inserting a group allocates its own position rather than rewriting neighbours.
- Enforce no rank ties between different groups in any effective context,
  including retained nonparticipants. Rank allocation considers the master and
  all overrides so a master move cannot collide with another group's context
  rank, even if the groups currently have different anchors. The same inherited
  rank for the same group across contexts is not a tie between different groups.
  No alphabetical tie-break is permitted. Exact allocation/master-edit
  mechanics remain to be refined.
- Use spaced ranks such as 100, 200, 300 initially. Allocate insertion values
  considering every saved rank in the profile, cleaning up when needed rather
  than introducing collisions.
- Implement one profile-wide cleanup: collect all distinct stored ranks,
  from saved rules' Master ranks and their `autoCategoryOverrides`, including
  retained nonparticipants, sort them, and map them strictly
  monotonically to new ranks at least 10 apart.
  Apply the same old-to-new mapping to each saved rule's `autoCategoryRank`
  and every context group rank override.
  Equal old values receive equal new values; distinct values remain distinct.
  Prepare and validate the entire change before saving it.
- For example, `100, 200, 201, 202, 300` maps to `10, 20, 30, 40, 50`.
  The old master gap 200..300 becomes 20..50 because override positions occupy
  intermediate values. Many overrides can require master positions hundreds
  apart.
- Cleanup preserves all seven effective orders, heading anchors and sparse
  inheritance; do not materialize inherited fields or complete context lists.
  Never renumber just one context or clean up on view/render.
  IC ordering ranks are distinct from native run/show priorities and D4
  category-name rank prefixes.

Numeric examples retained from the spec for implementation reference:

```text
Master:
  A: anchor New,     rank 100
  B: anchor New,     rank 200
  C: anchor To sell, rank 300
  D: anchor To sell, rank 400

Bank, B moved directly below To sell:
  B override: anchor To sell, rank 250
  Result: New / A / To sell / B / C / D
```

Swapping C/D's Master ranks also swaps them in Bank; swapping A/B's Master
ranks leaves B's Bank anchor/rank overridden.

Alternatively, B between C/D uses rank 350; inserting A between C/B uses
rank 325 without rewriting B:

```text
Bank overrides:
  A: anchor To sell, rank 325
  B: anchor To sell, rank 350
Result: New / To sell / C / A / B / D
```

If C/D exchange Master ranks, the numeric model produces
`New / To sell / D / A / B / C`, as required by the confirmed spec behaviour.
Overridden numerical importance is not a group-following relationship.

### Validation, migration and mutation

- Extend `ItemDatabase.ValidateSavedRules` and profile/import validation for booleans,
  per-rule Master placements and sparse `autoCategoryOverrides`, plus
  profile-level Master occurrence visibility and context heading overrides.
  Validate recognized context/group keys,
  occurrence identities, visibility booleans, anchor/rank shapes and effective
  no-tie invariants after inheritance. Unknown group keys are pruned at load with a reported
  count. Malformed recognized values reject before partial publication.
- Extend `ItemDatabase.PrepareSavedVariables` to validate every profile and preserve
  unrelated data plus existing v1/v2/v3 migrations before ZOS constructors.
  Recheck current schema; planning version 3 implies next version 4.
- Extend `ItemDatabase.NormalizeRule` / `ItemDatabase.PruneRule` and
  `ItemDatabase.GetRuntimeRules`; preserve sparse
  participation-only or placement-only saved rules, including nonparticipating
  built-ins with retained anchors/ranks, and avoid empty custom groups. Resolve
  participation, Master anchor/rank and context placement overrides deliberately in runtime rules and
  `ItemDatabase.GetActiveTrackedRules` editor copies; do not lose them through normalization
  or known-field copy paths.
- Proposed narrow mutations: `ItemDatabase.SetAutoCategoryParticipation`,
  `ItemDatabase.MoveAutoCategoryGroup(view, ruleKey, direction)`,
  `ItemDatabase.SetAutoCategoryHeadingVisibility(view, occurrenceId, visible)`, plus
  profile-scoped enablement.
  Master moves update the saved rule's anchor/rank; context moves update the moved group's
  `autoCategoryOverrides[context]` anchor/rank fields. Context placement reset
  clears only that context's entry across the selected profile's saved rules,
  retaining Master fields, other contexts and profile-level heading visibility.
  Master visibility edits update only the selected
  occurrence's shared value; context edits update only its local heading override.
  Cleanup operates only on group ranks, not heading visibility, and must not
  change any effective order. Add profile initialization/preset application,
  Master reset and context reset mutations; no individual-group override reset
  mutation/UI is required.
- `ItemDatabase.DeleteCustomRule` removes the rule with its participation, Master placement
  and embedded context placement overrides;
  `ItemDatabase.ResetRule` retains them.
  `ItemDatabase.CopyProfile` copies all integration choices without aliasing.
  `ItemDatabase.SetUseCharacterItemList` selects them consistently.

Extend [SavedVariablesTests.lua](../../../Tests/SavedVariablesTests.lua) and
[RulePersistenceTests.lua](../../../Tests/RulePersistenceTests.lua):
all-profile migration/import, malformed input/no partial writes, defaults vs
explicit false/empty, proxy-shaped ZO_SavedVars isolation, round-trip/copy,
per-rule Master anchor/rank and context override preservation through normalization
and editor/runtime copies, placement-only built-in rules, rejection of incomplete
Master placement pairs, independent partial context overrides, account/character
selection and context reset across embedded overrides without changing heading visibility,
rename/delete/Reset, heading hide/unhide, master/context moves, partial-field
inheritance, the spec's insertion/master-swap examples, no rank ties, and
cleanup preserving every context order/anchor without materializing overrides.
Include visibility inheritance/explicit true and false, same-name occurrence
isolation, context-only edits and copy isolation, and retained visibility
overrides on placement resets. Check derived Master scope labels and last-context
row hiding/recovery without duplicate saved visibility state.
Include occurrence identity round trips, shared/conflicting native heading
sequences, single Master row per IC group, and applicable-heading fallback
without modifying saved placements or creating overrides.
As part of post-implementation verification, execute a real pre-feature build
on new-schema synthetic fixtures and prove rejection before mutation.
**Do not load new fields on normal game saves until this downgrade check passes.**

## 2. Implement native predicate and placement

Add one focused module, provisionally
`Tracking/AutoCategoryIntegration.lua`, using existing helpers/patterns.

- Register the AC expression function `ic_group(ruleKey)` using
  `ItemDatabase.GetRuntimeRules` and
  `ItemDatabase.ItemMatchesRuntimeRule(AutoCategory.checkingItemLink, rules[ruleKey])`.
  Integration disabled/nonparticipating legitimately returns false; unknown
  keys or missing owned state in our registered expression are defects and throw.
- Escape keys as Lua string literals; names are labels, not identity.
  No duplicated matcher, scan, compilation, projection, sort or notification.
- Per classified item, at most one existing matcher call for each managed entry
  AC evaluates before its first match. Rely on native first-match dispatch,
  not a precomputed managed winner.
- Pure proposed `AutoCategoryIntegration.ResolveAutoCategoryOrder(context)` combines saved group
  master placements and sparse overrides, resolves usable heading anchors,
  and sorts each heading bucket by rank in native external heading order.
  `AutoCategoryIntegration.ComputePlacement` uses the spike-supported placement mechanism without
  assuming run/show equality or mirroring. Keep the implementation disabled
  until the post-implementation gate proves the required output shapes.
- Isolate category-name decoration/rank formatting in one helper. The tested
  empty-colour rank prefix is the approved production naming mechanism under
  D4. Document the accepted name/collapse-state trade-off; activation still
  requires the post-implementation acceptance gates.
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
  `Plugin_API.RegisterPlugin` or direct cache insertion alone.
- Proposed `AutoCategoryIntegration.ProjectAutoCategory()` is the sole production AC assignment writer.
  Validate external shapes and prepare the complete change set before mutation.
  Touch only `icOwned = true` entries in the active profile's seven lists:
  remove unwanted/stale, add missing, update changed run/show values.
  No label-based ownership, inactive writes, or external reorder.
- Rebuild only affected cache layers using verified error conventions. Explicit
  absent/disabled/active/incompatible status; external failures reported,
  required IC functions/state called directly. No speculative transaction/
  rollback system or success report after failure.

### Listener and toggle lifecycle

- Reuse IC's existing `Init` startup path for one-time plugin registration;
  do not add a second persistent addon-load listener. At the external dependency
  boundary, detect AC availability/compatibility before calling its APIs.
  When AC is absent, register no plugin, definitions, hooks, observers or
  scheduled integration work. Preserve saved choices and hide integration UI;
  loading the module's function definitions is harmless.
- When compatible AC is present, register the plugin and real predicate even
  with integration off, supplying the required definitions before AC activation.
  Disabled initialization removes active owned assignments; the predicate
  returns false while disabled. Registration retains definitions in memory
  and incurs startup processing, not ongoing polling or inventory listeners.
  Do not claim measured time/memory bounds from the spike.
- IC-owned settings/group/profile mutations call the integration synchronization
  path directly; do not introduce listeners to observe our own mutation methods.
  Disabled mutations preserve settings without classification/projection work,
  apart from the explicit disable/startup cleanup of active owned assignments.
- Observe AC profile switches/resets and heading/priority edits through verified
  external callbacks or hooks. Identify their exact targets during implementation,
  not another standalone spike. Register detachable observers only while the
  integration is enabled and compatible; detach them when no longer needed.
  If a required hook cannot be detached, install it once and gate its integration
  work on current enablement/compatibility. Avoid duplicate hooks on re-enable.
- Any required ongoing ZOS event listeners follow
  `Events.UpdateEventRegistry`'s conditional registration/removal pattern.
  Do not add inventory-slot listeners or polling for classification: AC invokes
  our predicate. Tracker visibility and Show/Notify toggles do not control
  integration observers; integration has its own enablement/compatibility gate.
- Disable cancels/invalidates pending reconciliation, detaches observers and
  removes active owned assignments before refreshing affected contexts.
  Profile changes invalidate pending work before selecting the latest profile
  and reconciling according to its enablement. Re-enable restores required
  observers and reconciles without reapplying the initial preset.

### Required synchronization

Trace every `ItemDatabase.InvalidateRuleCache` caller in
[ItemDatabase.lua](../../../../Tracking/ItemDatabase.lua): pattern/property updates,
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
  Bank-only moves do not refresh Backpack. Master edits affect contexts whose
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
Verify no AC API calls/observers/scheduled work when absent; disabled startup
registration and owned cleanup without ongoing observers; observer detach or
permanent-hook gating, no duplicate hooks on re-enable, canceled pending work,
and unchanged integration lifecycle when tracker visibility/Show/Notify changes.

## 4. Add settings and editor after the adapter works

- [Core/Settings.lua](../../../../Core/Settings.lua): opt-in/status tied to IC
  profile selection and first-enable preset chooser, no new Notify controls or
  inactive preview.
- [EditPanelItemsTab.lua](../../../../Tracking/EditPanelItemsTab.lua) /
  [XML](../../../../Tracking/EditPanelItemsTab.xml): ordinary-group AutoCategory
  toggle after Notify, aligned active width/zero inactive width; preserve existing
  Show/Notify popups, name readability, selection and recycled-row/profile checks.
- [EditPanelGroupsTab.lua](../../../../Tracking/EditPanelGroupsTab.lua) /
  [XML](../../../../Tracking/EditPanelGroupsTab.xml): toolbar view toggle,
  eight-choice selector (Master (all contexts) first, then the seven contexts)
  and native ordered rows.
  Normal `EditPanelGroupsTab.GetSortedGroupNames` unchanged; AutoCategory uses master/resolved order,
  heading badges/read-only filter details, group arrows/participation/conflict
  warnings and never-ordered tail. No Miscellaneous or drag/drop.
- In Master only, add an AutoCategory participation checkbox to every ordinary
  IC row, including nonparticipants and never-ordered rows. Bind it
  and the Edit Items toggle to the same participation mutation path and refresh
  both editors from shared state. The tooltip must explain that participation
  applies across all contexts. External headings
  have no participation control. Off retains placement/overrides; on reuses
  existing placement or invokes the first-participation initialization.
- Add Master's **Show nonparticipating IC groups** filter, initially checked.
  Filter changes only editor visibility, with no participation/placement writes,
  projection or inventory refresh. Dim nonparticipating rows consistently with
  the existing left-panel group treatment; keep names readable and checkboxes
  usable, including selected/hover states. Add no nonparticipation status label.
  Context views omit nonparticipants entirely and have neither participation
  controls nor this filter. Show the spec's Master/Edit Items enablement note.
- Show move controls only when Master's Show nonparticipating IC groups and
  Show all AutoCategory groups are both unchecked, or when the context's
  Show all AutoCategory groups is unchecked. Otherwise hide all arrows and
  show the spec's explanation; retain usable participation/hide controls.
  Enforce the same eligibility in move handlers so stale callbacks cannot move
  groups in expanded views. Only participating IC rows have arrows. Resolve
  neighbours from participating groups and usable heading references without
  rewriting retained nonparticipant placements. Add no separate enable/move mode.
- Master shows the combined context-labelled heading occurrences; context views
  omit inapplicable occurrences and use native AC order. Show every IC group
  only once in Master. Scope labels must be understandable without relying
  on colour or tooltips alone.
- Choose during development between a dropdown and small clickable context
  icons for the eight modes. Icons require descriptive tooltips, clear selected
  state and a visible selected-mode name; keep Master first in either layout.
- Add a selection-dependent info label beside or below the selector using the spec's
  Master/context wording. Explain both matching and heading order, inherited
  changes and retained context overrides; do not imply every resolved context
  order stays unchanged after a Master edit.
- Distinguish external heading rows with an AutoCategory icon/badge or explicit
  label, optionally colour/background stripes, never colour alone. Keep the
  distinction readable during selection, moved-row highlights and revealed
  hidden states. Exact visual treatment awaits UI refinement.
- External heading rows use normal hide/unhide controls. Add
  **Show all AutoCategory groups** to reveal hidden rows for unhiding; turning
  it off omits them. Revealing a hidden row does not make it an anchor.
  Checkbox changes only editor filtering, with no saved placement changes,
  projection or inventory refresh. Hide/unhide changes effective anchors and
  reconciles affected contexts without changing AC settings. Route Master edits
  to occurrence visibility and context edits to heading visibility overrides.
  Refresh derived Master labels after context edits; omit rows with no visible
  contexts and reveal their original scope/hidden contexts under Show-all.
- Follow [CurrencyPanel.lua](../../../../Tracking/CurrencyPanel.lua)
  `CurrencyPanel.GetCurrencyPanelSettingsControls` /
  `CurrencyPanel.CreateResourceSettingsList` /
  `CurrencyPanel.CreateResourceSettingsRow`: 28-by-26 `ZO_DefaultButton` arrows,
  tooltip/sound/save/reorder/highlight interaction. Do not call currency-specific
  helpers or copy its hidden-resource order pruning; nonparticipants keep order.
- Preserve moved selection/scroll. Disable endpoint/search moves. Close stale
  popup/callbacks on profile/import/reset/delete/view changes using existing
  patterns; external heading selection must never bind editable group actions.
  Add Master Reset to defaults with the preset chooser and context Reset to
  Master with context-only group-placement override clearing. Show effective
  context order without override indicators or individual-group reset controls.
- D2: decide final texture identity/tint, convert chosen v5 plain SVG to 64x64
  DXT5 DDS/alpha and verify asset path. New asset needs game restart. Do not add
  badge UI/colour settings from D3 without separate author decision.

Extend [GroupEditorTests.lua](../../../Tests/GroupEditorTests.lua) and
[ItemEditorTests.lua](../../../Tests/ItemEditorTests.lua): zero writes on view/context
selection, all eight choices and corresponding explanation text, external-row
visual distinction in selected/revealed-hidden states,
combined Master occurrence scopes/native subsequences, single IC group rows
and upward applicable/unhidden-heading fallback,
Show-all zero writes/projections/refreshes, hide/unhide reference
behavior and occurrence/context isolation, derived labels after Bank-only hiding,
last-context omission and Show-all recovery, row ordering/selection/endpoints/search, external-heading restrictions,
current-list fallback after external heading deletion/rename/reordering without
historical fallback attachment, absence of individual override badges/reset controls,
rename/delete/recycled callbacks, profile isolation, width and inactive layout,
Master-only participation toggles synchronized with Edit Items, context omission
of nonparticipants/participation controls/filter, default-on Master filter with
zero writes/projections/refreshes, readable dimming and usable unchecked controls
without status labels/arrows, never-ordered controls, retained placements on
off/on, arrow visibility and handler eligibility for all combinations of the
two Master filters and the context Show-all filter, expanded-view explanations
and usable participation/hide controls, unchanged nonparticipant placements,
first participation for existing/new groups without placements after the last
participating Master group or at bottom when none participate,
Show/Notify unchanged, and XML assertions. Verify toolbar fit, chosen mode
selector/tooltips/selected state, native arrows, tint/readability and scrolling
in ESO.

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
- **D4 approved:** verify and document production rank-bearing prefix behavior,
  including the accepted expanded-after-reorder behavior and old collapse flags
  remaining. Naming approval is complete; implementation acceptance is not.
- **Q3:** verify automatic edits, profile switches, disable, cache invalidation,
  reclassification and affected-context refresh through the implemented hooks.
- **Q4:** synthetic migration/import validation and pre-feature downgrade
  rejection have passed in the focused runner. No normal saved data has been
  loaded; retain that boundary for further testing.
- **Q5:** agree workload and numerical timing limits when preparing the
  post-implementation measurement; count matchers, scans, compilation,
  projection writes and refreshes, then measure off/on sort and edit bursts.
  Synthetic checks never mutate live inventory or saved variables.
- Guild Bank remains untested in the spike. Verify the implemented native path
  in the required keyboard context matrix; if the known BulkMode path bypass
  prevents the spec behavior, stop and discuss scope/design rather than count it
  as passed. Do not claim gamepad, untested crafting tabs, or merchant modes.

- Wire focused suites into [Run-RuleTests.py](../../../Tests/Run-RuleTests.py) and
  use the existing Lua setup. Run smallest relevant suite first; full related
  runner for completed cross-surface integration.
- Preserve [ItemNotificationTests.lua](../../../Tests/ItemNotificationTests.lua)
  destination/hidden-rule/listener/duplicate coverage. Extend existing in-game
  rule tests only for safe matching/synthetic workload.
- Execute every [spec acceptance criterion](todo_plan_autocategoryIntegration.md#acceptance-criteria):
  all seven keyboard contexts, subscriber
  Bank, top/crowded/immediately-below-heading order, all edits, both profile modes and shared
  character groups, automatic switching, resets, reload/disable/uninstall,
  edit-while-absent, immutable external entries, new-schema downgrade safety.
- Check Lua/XML, paths/whitespace, new textures against
  [ESO-Game-Textures.md](../../../Resources/ESO-Game-Textures.md), and documentation links.
  Record version, supported contracts, precise context/platform limits, workload/
  timings and dated offline/ESO results in the spike/results record.
- Update [UserManual.bbcode](../../../../UserManual.bbcode): participation,
  Master/context inheritance, ranks/cleanup, view/arrows/heading hide/unhide
  and Show-all controls, overlap examples, owned settings moves overwritten,
  collapse residue, uninstall `(!)` rows, active-profile scope, compatibility,
  performance and saved-data/downgrade behavior.
- **Before shipping, tear down the DEV spike runtime:** the probe source is now
  in `Project/Tests/AutoCategorySpikeRuntime.lua` and removed from the DEV
  manifest. Keep its offline fixtures/runner usable and validate after
  relocation. No spike slash commands, event handlers, gate plugin or
  Debug override may remain registered by the shipped runtime; normal
  `Tests.RunTests("verbose copy")` Debug behavior must be restored. Do not remove the
  production integration module or its required optional AutoCategory
  dependency. Verify exact-token cleanup of any remaining test assignments
  before unloading the cleanup command, then reload to verify the gate plugin
  and commands are absent and production integration still works. Record this
  teardown evidence in SPIKE RESULTS.
- Update authoritative working changelog from actual implementation first;
  follow [ReleaseChecklist.md](../../../Publishing/ReleaseChecklist.md) for numbering,
  approval and publication. Archive only after automated and user-reported
  acceptance. Do not call planned APIs implemented or untested behavior supported.

## Open-question closure checklist

- [ ] Q1/Q2: post-implementation classification and native heading-order checks
      pass for the supported contract; unsupported cases fail visibly.
- [ ] Q3: automatic CRUD, profile hook, cache/refresh and disable pass.
- [x] Q4: migration/import/downgrade pass on synthetic data before normal saves.
- [ ] Q5: workload/threshold agreement and post-implementation measurement pass.
- [ ] D1 author approval if a revised strategy is needed; otherwise not applicable.
- [ ] D2 final asset identity/tint approved and asset verified.
- [ ] D3 optional badge decisions only if separately taken into scope.
- [x] D4 empty colour-rank prefix naming approved (2026-11-01), including
      expanded-after-reorder behavior and retained old collapse flags.
- [ ] Guild Bank passes the implemented seven-context keyboard matrix.
- [ ] Probe Debug/report housekeeping completed.
- [ ] Pre-shipping spike teardown: manifest entry removed, source retained
  outside runtime loading, offline reuse validated, no gate registrations or
  tagged assignments remain.


found after imp
autocat lets users move categories up/down - we can do this for them in our ui (which is better, or will be) we can do view priority AND resolve priority. if we can come up with a cool ui/ux for this, then we can apply it to our own groups as well 
(maybe use the view priority AS the other one, unless we override it - so view priorities always have even numbers and overrides have odd ones etc. I think the max is 1000 so no 10 gaps here....)
our ui sucks - labels look wrong in itemeditor, alignment issues when autocat col is not collapsed 
our ui sucks - group editor is the wrong place for this we don't need the patterns when we are moving groups up/down. a third 'tab' would be much better
I think there are issues with movement and display, but its hard to see at the moment.
In a different panel we can have priority and display modes separately (on a toggle) and make the changes that autocat allows users to make in their own ui. They also have a 'hide' mechanic, but I think that actually removes items from the inventory so we don't want to hook into that (unless we want to make this a 'autocategory+ type of thing)

OUR category display order and priority order can be changed in autocategory - how does that interact with what we do here? Probably need to rewrite those numbers instead of our own stored ranks? and that is the source of truth?

to add to the todo -> "add more config panels instead of settings. Make the game settings the top level enable/disable one offs and move (defo) the currency editor to a panel and any other 'complicated' ui"

editor tab duplication (deferred until the AutoCategory tab works in game) - the third tab copies window scaffolding that Items and Groups already duplicated between themselves:
- XML window frame (~50 near-identical lines per window): title, Other Settings, Close, tab buttons, search box.
- Lua scene setup: each tab creates its scene and repeats the same show/hide camera-mode + `UpdateEditorLayout` handlers; Items and Groups register them twice (scene callback and window handler).
- each tab wires its own search box and tab-button visibility.
Plan:
1. Lua first (low risk): shared helpers to register a tab's scene/show/hide behaviour and to configure tab buttons, removing the double-registered handlers. Check in game that each tab still opens, closes, switches and searches.
2. XML later, once the AutoCategory tab layout/buttons have settled: one shared virtual window frame inherited by all three tabs.

ordering model rethink (needs discussion) - AutoCategory exposes run/show priority numbers to users in its own settings panel, so they are a legitimate target for us to edit directly. Consider dropping our stored ranks and the colour-code rank prefix in category names, and treating AutoCategory's priorities as the source of truth. Open points: how alphabetical tie-breaking is handled without the prefix; how edits made in AutoCategory's panel map back to our UI; whether Master/context overrides still need stored data; migration from stored ranks/prefixed names. (The prefix made renames frequent, which exposed the definition-sync index bug, but was not its cause.)
### Ordering replacement plan (2026-11-01, proposed; not implemented)

**Superseded for this fix by the dedicated
[ordering-fix implementation plan](todo_implementation_autocategoryOrderingFix.md).**
That plan includes the subsequent ordered-list and direct `ic:`/`ac:` reference
decisions. The section below is retained as discussion history.

**Problem confirmed:** the editor sorts exact `showpriority` values, whereas
AC keyboard inventory builds its sort key with
`string.format("%04d%s", 1000-showPriority, categoryName)`. Fractional
differences can disappear. In the account-wide Backpack snapshot, New and Set
both run at 100; Utility runs at approximately 99.94 and Test group at 99.89.
Set therefore claims items before Test group, but its generated set-name
headings can appear below it. Editor order, matching order and rendered order
must no longer be presented as interchangeable.

**Accepted scope:** AC exposes category priorities to its users, so IC may
rewrite native AC assignments' run/show priorities on their behalf. This
supersedes the previous prohibition for those two fields only, not permission
to rewrite external definitions, filters, membership, names or hidden flags.
Keep Master and seven context overrides, using virtual order rather than AC
numbers. Removing the colour-rank prefix is intended. Legacy rank/prefix
migration is not a product requirement; safe saved-data handling still is.

This replaces a core mechanism and saved-data representation. Recommend a
separate implementation branch, with author approval before switching.
Existing dirty work must be preserved. No runtime changes are part of this
planning step.

#### 1. Agree the user-facing order contract

- Recommend two explicitly labelled views: **Display order** (where headings
  appear) and **Matching order** (first matching category wins). Both contain
  participating IC groups and native AC assignments, with move controls for
  both kinds. Do not expose priority numbers as the primary controls.
- Recommend independent sequences initially, preserving AC's existing
  run/show differences. Offer an explicit **Use display order for matching**
  action, with an explanation that it can change which group owns an item.
  A persistent linked mode is a separate decision, not an implicit default.
- Matching view explains catch-all shadowing: New, Utility, Test group (`*`),
  Set means Set cannot claim remaining named items. Display-only moves must
  never change classification.
- Represent `autoset()` as the parent Set assignment with an explanation that
  AC expands it into individual set-name headings. Those sibling headings
  share their parent's priorities and remain alphabetically ordered within
  its block; distinct assignment priorities do not order siblings separately.
- Master is shared intent, not a claim that seven differing bags have one
  actual order. Context views must show their resolved native order. Mark
  context overrides and provide explicit reset-to-Master controls for each
  sequence. Preserve the existing editor-only heading visibility meaning;
  do not repurpose it as AC inventory hiding or exclusion from matching.

**Decision gate:** approve the independent views plus explicit copy action,
or choose a linked-by-default design before implementation. Also agree what
disable means after native priorities have been changed (see step 5).

#### 2. Establish identities, read-back and Master/override semantics

- Use stable IC rule keys for managed assignments, independent of display
  names and rank. Identify native assignments within each active AC profile
  and bag; explicitly handle duplicate names/occurrences rather than silently
  merging them. Definitions and runtime-expanded headings are not assignments.
- Store independent virtual sequences for display and matching. Keep Master;
  record a context override only where its applicable order differs, and
  remove redundant overrides. Specify how context-only categories, new
  assignments and deleted assignments enter/leave each sequence.
- Import existing AC run and show orders separately. Importing must not
  automatically make them equal. Before normalizing fractions/ties, determine
  the current effective inventory order using AC's actual sort keys, not just
  numeric `showpriority`; surface any ambiguous dynamic-heading import.
- Re-read on editor open, after AC cache/profile changes, and immediately
  before every write. Track the last projected snapshot and its profile/bag
  identity so our own output is not mistaken for an external edit.
- Reconcile against that snapshot before applying a pending IC move: adopt
  independent AC edits, then apply the user's specific move to the fresh
  sequence. Recompute stale moves, or report a conflicting/disappeared target;
  never replay a stale whole-list order over newer AC edits.
- Keep outgoing and incoming IC/AC profile snapshots separate. Profile
  switching must not import one profile's projection into another's Master.
  External edits to IC-owned priorities are adopted, not silently reverted.

#### 3. Replace fractional insertion with an integer calculator

- Installed AC run and show sliders both support **2..1000**, inclusive:
  **999 distinct assignment priorities per bag per sequence**. Verify the
  classifier and native sort keys with the actual installed modules.
- Assign distinct descending integers within that range to every assignment
  in each resolved sequence, including native AC assignments. Simple
  consecutive values are sufficient; no even/odd scheme, fractional gaps,
  colour-rank prefixes or alphabetical tie-block insertion.
- Preflight all seven bags and definitions before any persistent writes.
  Reject over-capacity or malformed external layouts with an actionable
  visible error and no partial writes; do not silently clamp or omit rows.
  Hidden assignments still count because they can participate in matching.
- Preserve every unrelated assignment field and all external definitions.
  Validate rendered sort keys as well as numeric order. Distinct priorities
  order assignment blocks; they do not prevent arbitrary external plugins
  from changing classification or generating unexpected heading names.

#### 4. Wire projection and editor together

- Replace anchor/fraction/tie allocation and rank-bearing managed names.
  Use stable icon/name identity with collision checks. A reorder must not
  rename a managed category or reset its collapse state.
- Plan changes, then write changed run/show fields and owned assignments,
  rebuild caches and refresh affected contexts once. Retain feedback-loop
  suppression and invalidate delayed work when profile/generation changes.
- Add the display/matching selector, move controls for native assignments,
  override indicators/reset and the explicit copy action to the dedicated
  AutoCategory tab. Search/filtering must not redefine underlying move order.
- Show Set as an expandable-category parent, not a promise of one literal
  inventory heading. Explain why a category can appear below a catch-all in
  Display order yet match before it in Matching order.
- Keep pattern editing on Groups. Defer shared editor-frame refactoring,
  unrelated layout repairs and optional inventory-hiding features.

#### 5. Saved-data and disable safety before live use

- Update the spec and implementation report to the approved contract before
  changing runtime behavior; mark old prefix/fraction evidence historical.
- Bump the IC saved-variable schema for the incompatible representation.
  Validate every profile before constructors; preserve unrelated saved data.
  If legacy integration configuration is deliberately reset rather than
  migrated, obtain explicit approval and report exactly what is reset. Do
  not discard all saved variables or silently reinterpret old fields.
- Verify downgrade rejection against supported older DEV/release sources
  using synthetic saves, including the currently installed schema-4 build,
  before testing on shared normal saved data.
- Recommend disable removes IC-owned assignments but leaves the current
  native AC priority order intact. If restoration is requested instead,
  design conditional restoration that cannot overwrite subsequent user
  edits; do not assume an old priority snapshot is still authoritative.
- Test install/reload, absent dependency, both profiles, enable/disable,
  native category CRUD, IC CRUD and external priority changes.

#### 6. Focused automated acceptance

- Reproduce New/Set tied at 100, Utility/Test group between 100 and 99, and
  AC's actual integer-string display sorting. Assert the replacement UI and
  native inventory agree, not merely that calculated numbers are distinct.
- Two cases with real classifier/filter behavior: Set before catch-all
  retains set headings; Set after catch-all claims no remaining items.
  Cover named set expansion, New precedence and overlapping IC filters.
- Display-only movement leaves matching unchanged; matching-only movement
  leaves display unchanged; explicit copy produces the same parent order.
- Verify strict integer priorities, exact output permutations and sort keys
  at 0, 1, 999 and 1000 assignments. Zero is a valid empty bag; 1000 rejects
  before any bag writes. Exercise all seven contexts and differing membership.
- Round-trip read/project/read is idempotent. Cover external edits immediately
  before a pending projection, conflicting moves, own-hook suppression,
  reloads, cross-profile isolation and sparse override reconstruction.
- Assert unrelated external fields/definitions are unchanged, stable managed
  names survive reorders, collision/capacity errors cause no planned writes,
  and synthetic tests never touch live inventory or saved variables.

#### 7. In-game acceptance and documentation

- First validate the author's Backpack: show both sequences and demonstrate
  Set before/after Test group, independently of its display position. Get
  explicit confirmation that the UI explains the observed inventory.
- Check native inventory order against each context view, individual set-name
  blocks, collapse/reorder/reload, external AC-panel edits and both profile
  directions. Include Bank/subscriber Bank and the previously deferred Guild
  Bank; do not mark untested contexts or gamepad supported.
- Agree workload/timing limits, then run safe synthetic burst checks without
  mutating live inventory or saved data.
- Update user documentation for the two orders, catch-all behavior, Master
  overrides, external-edit read-back, capacity and disable semantics. Update
  the working changelog from actual changes; retain the existing release,
  downgrade and spike-teardown gates.

what is the downgrade schema test that keeps failing? Is it something to do with sv version?
