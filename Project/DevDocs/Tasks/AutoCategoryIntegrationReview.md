# AutoCategory integration: spec and plan review

Review dated 2026-10-31. This is a reference assessment of the
[spec](todo_plan_autocategoryIntegration.md),
[implementation plan](todo_implementation_autocategoryIntegration.md), and
[spike evidence](AutoCategorySpikeResults.md), grounded in the current IC code.
It is a review, not an authorization to implement or a claim that the feature
has passed acceptance.

**Status update:** D4 was approved by the author on 2026-11-01, and the
integration has since been implemented. The findings below preserve the
review's 2026-10-31 assessment; post-implementation acceptance remains pending.

## Overall assessment

The spec is useful and unusually clear about ownership, safety, user experience,
persistence, and evidence limits. It is coherent as a desired outcome, but some
core ordering and lifecycle behavior is not yet demonstrated generally. The
plan is technically thoughtful and mostly follows the spec, but its previous
sequence treated additional ordering research as a prerequisite to beginning
implementation. The revised plan starts implementation first and puts remaining
assumption checks after implementation, before activation or release.

I do **not** recommend reopening the spike now. The existing evidence is enough
to implement against the sampled native-insertion strategy while keeping the
integration disabled until the post-implementation checks pass. If those checks
show that the unchanged spec cannot be met, stop and bring the evidence and
options back to the author; do not silently weaken behavior or change who owns
classification/rendering.

## Findings, prioritized by impact

### 1. Ordering remains a release/activation blocker, not an implementation-start blocker

The spec requires the editor order to control both the winning classification
and visible heading order, while preserving AutoCategory's native behavior and
leaving external entries unchanged ([spec: Classification and visible order](todo_plan_autocategoryIntegration.md#classification-and-visible-order)).
That contract is not proven generally.

**Proven behavior**

- Five rank-prefixed headings passed top and crowded-order checks in ESO.
- Runtime rank replacement/full-cache rebuild and account-profile reload passed
  for the sampled entries.
- A 128-group, seven-context synthetic scale fixture passed offline.
- The spike also tested failed alternatives and recorded their results; see
  [heading-order evidence](AutoCategorySpikeResults.md#heading-order-and-fractional-formatter).

**Limitations**

- The offline scale fixture is not 128 actual ESO headings.
- Prefix capacity is finite, and adjacent floating-point priorities may leave
  insufficient room.
- External run/show priority mismatches can still produce heading order that
  disagrees with classification order.
- Plain fractional priorities can format to identical keys and then sort
  alphabetically.
- Prefix reorder changes category identity and restarts collapse state for the
  renamed heading, leaving old collapse flags.

The revised plan should implement from the spike-supported mechanism without
claiming a universal solution. The actual adapter must then pass the
post-implementation order checks before enablement. Unsupported layouts must
be reported and must not silently fall back to alphabetical order. If the
required behavior cannot be delivered unchanged, D1 is an author decision.

**Open decision:** D4, adoption of rank-bearing prefixes as production category
names, remains explicitly undecided. The code and plan must not treat a spike
pass as approval. Resolve the name/collapse trade-off with the author before
enabling production projection.

### 2. Guild Bank is required by the spec but has a known unverified path

Guild Bank remains one of the spec's seven required contexts, but it was
deferred in the spike, not passed. The inspected dependency notes also say
Guild Bank uses a separate assignment list and has a BulkMode bypass
([dependency contracts](AutoCategorySpikeResults.md#dependency-contracts-and-source-trail)).
That is a real feasibility risk for native classification.

This does not justify reopening the spike before implementation. The plan should
check the actual implemented behavior in the post-implementation keyboard
context matrix. If the bypass prevents the required behavior without changing
the native-classification design, stop and discuss a scope/design decision.
Do not count unavailable or untested Guild Bank behavior as a pass.

### 3. Automatic lifecycle and refresh are implementation work with acceptance still due

The profile evidence proves manual active-only projection in sampled cases, not
automatic production reconciliation. The spike leaves automatic profile-change
detection, dynamic edits, cache invalidation, refresh, and disable behavior
open. The plan appropriately identifies these as required surfaces.

Existing IC mutation points make the proposed placement sensible:
[profile selection and rule mutations](../../../Tracking/ItemDatabase.lua#L407),
[name/pattern updates](../../../Tracking/ItemDatabase.lua#L434),
[profile copy](../../../Tracking/ItemDatabase.lua#L494), and
[runtime matching](../../../Tracking/ItemDatabase.lua#L611).
AutoCategory's refresh/cache limitations are in the spike's inspected contracts;
manual probe behavior does not prove that the production hooks work.

**Concrete improvement:** Implement one explicit adapter lifecycle contract.
It should distinguish edits that only invalidate classification from edits
that require assignment reconciliation, detect active profile changes, write
only the active AutoCategory profile, and cancel stale pending refresh work
when disabled or switched. Then verify these behaviors through the completed
implementation before activation.

### 4. Saved-data migration is correctly treated as a hard safety boundary

The proposed profile-local storage for participation, markers, and context
order is a good fit. IC already validates and migrates saved profiles in
[PrepareSavedVariables](../../../Tracking/ItemDatabase.lua#L275), and its
current schema is version 3 ([Core/Init.lua](../../../Core/Init.lua#L1)).
The plan correctly calls for a schema increment, all-profile/import validation,
and proof that an older build rejects new data unchanged.

This should be tested after the migration implementation exists but before
loading the new schema with normal game saves. The test should include
write-through saved-variable proxies and verify the older build leaves the
synthetic new-version data unchanged.

**Implementation detail:** `GetActiveTrackedRules` returns a restricted copy
of rule fields. Adding a saved participation flag alone will not expose it to
the UI. Integrate it deliberately into runtime/editor data, `CopyProfile`,
normalization/pruning, and custom-rule deletion so that profile choices and
order references do not get lost or aliased.

## Feasibility, efficiency, and code placement

- **Persistence and narrow mutations:** Extending
  [ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) for validation,
  active-profile access, rule mutations, and profile copies follows its current
  responsibility. Keep AutoCategory reconciliation behind a dedicated adapter
  rather than embedding external API calls throughout persistence code.
- **Native adapter:** A focused
  `Tracking/AutoCategoryIntegration.lua` is justified. Reusing
  `ItemMatchesRuntimeRule` avoids a second pattern compiler or divergent
  matching semantics. Native first-match behavior means the cost can scale with
  the number of managed rules evaluated before a match; the spec's no-scan and
  no-compile constraints are useful, but Q5 still needs a measured workload and
  agreed timing limits after implementation.
- **Lifecycle placement:** Current IC startup is in
  [Core/Init.lua](../../../Core/Init.lua). Registration must respect the
  spike's event-order evidence and occur only when both saved profiles and the
  external plugin contracts are ready. The DEV manifest already has an
  optional AutoCategory dependency; the release manifest does not.
- **Editor placement:** Group ordering/view changes belong in
  [EditPanelGroupsTab.lua](../../../Tracking/EditPanelGroupsTab.lua), while
  participation belongs in the existing item/group row flow. The currency
  panel's reorder rows are a reasonable interaction precedent, but its
  resource-specific helpers and hidden-item pruning should not be coupled to
  the new feature.
- **Complexity:** The feature is substantial. The largest risks are numeric/
  string ordering semantics and lifecycle synchronization, not the arrows or
  settings controls. Implementing data and adapter before UI limits the cost of
  reworking editor behavior if the adapter contract fails.

## Suggested spec improvements

These are clarifications for the next author/spec review, not new requirements
approved by this review:

1. Define the supported AutoCategory compatibility boundary and what visible
   status/action the user sees when the current external lists cannot satisfy
   the requested placement. Avoid implying arbitrary external priorities and
   names are supported.
2. State explicitly that ordering and Guild Bank checks occur after
   implementation and before activation/release, not as a request to repeat
   the spike before coding.
3. Keep D4 visibly unresolved until the author decides whether category names
   may carry rank prefixes and accepts the resulting collapse-state behavior.
4. Make the Guild Bank BulkMode risk explicit in the acceptance criteria. The
   existing seven-context criterion is correct; clarify that the post-
   implementation path must be demonstrated rather than inferred from the
   other six contexts.
5. Keep Q5 open until the implementation exists. Agree on synthetic
   inventory/group/burst sizes and numeric thresholds when preparing that
   post-implementation measurement, then record counts and timings.

Other useful details are already covered: profile ownership, marker behavior,
collision preflight, downgrade safety, cancellation of pending work, and
separation from Show/Notify. They should remain acceptance criteria rather
than being expanded into more pre-implementation spike work.
