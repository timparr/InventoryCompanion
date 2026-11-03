# AutoCategory integration implementation report

**ARCHIVED 2026-11-03.** Historical report; current status and requirements
are in the [master feature document](../../AutoCategoryIntegration.md).

## Status

The [profile synchronization fix](AutoCategorySynchronizationFix.md)
is implemented on main, uncommitted, as of 2026-11-03. Integration remains
opt-in and disabled by default. Current verification is **192/192 isolated
addon tests** with Lua 5.1 syntax checks, plus **31/31 installed-dependency
spike fixtures**, using synthetic state only. ESO in-game acceptance,
compatibility certification and release readiness remain incomplete.

### Current synchronization implementation

- Schema **8** stores per-context native exclusions and remembered display
  positions, plus an item-list initialization marker. All profiles migrate
  before ZOS constructors. Actual schema-4 through schema-7 builds reject
  schema-8 synthetic data without mutation.
- The selected IC profile owns groups, participation, enablement and order;
  AC selects the destination independently. All four scope combinations,
  A/B/A shared-profile replacement, cold startup and both mode switches
  synchronize automatically. Incomplete runtime, malformed data and ownership
  collisions remain failures, not excuses to delete rows.
- Generated assignments preserve complete AC-side options in owned,
  per-bag templates. Projection writes only the active destination, rolls
  assignment/template changes back on failure, and publishes proposed IC
  ordering/participation only after success. Dormant native ordering references
  survive destination changes; historical recovery archives are not replayed.
- Included/Excluded labels and sections apply to both order lists. Native
  exclusion is enforced by matching precedence around the predicate-gated,
  internal Other helper. One priority slot is reserved for it: at most **998**
  user assignments plus Other per context.
- First-time profile initialization and explicit copying share complete
  by-value semantics. Reset warns and defers all mutation until a new setup
  arrangement is confirmed. Ordinary disable preserves IC choices and the
  last native priorities while removing generated rows.
- Genuine malformed-priority DEV fixtures continue exercising recovery;
  normal stale assignments now exercise successful synchronization.
- A synthetic burst of 100 pattern updates across 128 groups/seven contexts
  produced seven refreshes, zero cache rebuilds and a final sampled 6 ms CPU cost.
  This is offline evidence, not an ESO performance certification.

See the linked synchronization plan for the pending in-game acceptance steps,
including the Other heading, native exclusions and profile transitions.
The summaries below are historical where superseded by that plan.

### Earlier ordering implementation (schema 5)

- Saved-variable schema is version 5. Each account-wide and character profile
  stores independent Display and Priority lists for seven contexts, using
  stable `ic:<rule key>` and `ac:<category name>` references. Lists are
  validated before ZOS constructors. Invalid or legacy AutoCategory setup is
  preserved but excluded from use, with a warning and session-only integration
  disable. Core profiles upgrade non-destructively even when integration data
  cannot be used. The downgrade test pins the actual schema-4
  build at `9d2531ef621725351039ad7d3044b4a55d426b75`.
- The editor has independent Display and Priority modes, native assignment
  rows, participation controls, full-list moves, one-time cross-context
  copying, and one-time same-context order copying. There are no presets,
  Master sequence, heading visibility controls, rank prefixes, or per-group
  rank/anchor fields.
- Projection preflights every context, assigns integer priorities from 1000
  down to 2, and rejects lists over 999 assignments before writing. It changes
  only native run/show priorities, preserving native names, membership,
  visibility and other assignment fields. Rename reconciliation, disable
  cleanup, round-trip idempotence, independent move modes, and copy behavior
  have focused regression coverage.
- User documentation and the Unreleased changelog describe the new behavior.
- AutoCategory-only failures no longer prevent the rest of IC from loading.
  Saved-data validation, plugin registration/initialization, deferred work,
  classification, hooks, projection and editor actions report errors and stop
  integration for the session. Pending work is invalidated and managed
  assignments are removed where the external APIs remain usable; cleanup
  failures are also reported. Saved enablement choices are retained, but
  effective enablement and the editor remain off until reload. Higher saved
  versions and core-data errors retain the hard startup stop. Tests cover
  legacy and malformed AC data with successful core startup, repeated startup,
  incompatible dependencies, registration/classifier/deferred cache failures,
  warning delivery and prevention of further scheduling after failure.
- Added `/iccleanautocategory` as an owner-only cleanup command. It proceeds
  only when ESO's current account is `@Tim-P`, targets only that account's IC
  profile buckets, clears IC integration/legacy ordering fields, and removes
  only assignments explicitly marked `icOwned` from AutoCategory's account
  and character saved profiles. It preserves unrelated IC settings, other
  account buckets, native AC assignments and definitions, and instructs the
  owner to run `/reloadui`. Synthetic tests cover account rejection and schema-4
  cleanup before constructors; no live saved variables were touched.
- Remaining acceptance follows the ordering-fix plan: verify classification
  and rendered order in ESO, including all seven contexts, reload/profile
  behavior, external edits, and the user's Set/Test-group case. Do not treat
  offline tests as compatibility certification.

The following sections preserve historical evidence from the earlier
schema-4 Master/preset implementation. Where they conflict with the current
ordering contract above, the ordering-fix plan and current summary take
precedence.

## Historical delivery notes (before ordering redesign)

- Added schema-v4 saved-state validation and migration for integration
  enablement, participation, heading visibility and sparse placement overrides.
  Added mutations for presets, per-context placements, first participation,
  resets and rank rebalancing.
- Added `Tracking/AutoCategoryIntegration.lua` as the native AutoCategory
  adapter. It projects only managed definitions and assignments to the active
  AutoCategory profile, reuses IC's runtime rule matching, and hooks profile and
  rule lifecycle changes.
- Corrected startup registration timing: plugin preflight no longer requires
  AutoCategory's active bag assignments before player activation. Projection and
  assignment cleanup validate those bags when they become available, and
  scheduled reconciliation waits for AutoCategory initialization.
- The Debug Key (`/ictest`) now performs a read-only in-game AutoCategory
  lifecycle check: plugin registration, post-initialization active bag shape,
  integration status, and managed-assignment counts across all seven contexts.
  Running it before AutoCategory initializes or before a scheduled projection
  completes reports a rerunnable pending warning rather than a false pass.
- Fixed the starting-arrangement dialog crash when enabling the integration.
  ESO's keyboard `ZO_Dialog` has only two button controls (`NUM_DIALOG_BUTTONS = 2`),
  so the original third button raised `ZO_Dialog.lua:560: attempt to index a nil
  value`. The two arrangements are now dialog radio buttons, with Confirm/Cancel
  buttons; Escape or other dismissal also refreshes the UI without applying a
  preset. The unused gamepad dialog type was removed because both callers are
  keyboard-only UI.
- Fixed editor crashes after the preset was confirmed. The Items-tab row
  AutoCategory toggle was a bare `ZO_CheckButton`, but Lua looked up a `Label`
  child (`EditPanelItemsTab.lua:745: attempt to index a nil value`) and widened
  the checkbox itself to 110 px. It is now a container with `Check` and `Label`
  children; clicking the label also toggles participation, and both show the
  tooltip. The Groups-tab AutoCategory view had the same defect on its
  participation and heading-visibility checkboxes, which only looked up nonexistent
  labels in order to hide them; those lookups were removed.
- The offline suite does not instantiate XML, so Lua/XML child-name mismatches
  passed. The test runner now asserts the item-row toggle has `Check` and `Label`
  children and that the Groups-tab row checkboxes are not queried for children.
  A general name-only `GetControl` check was evaluated and rejected because child
  names such as `Label` exist in other templates and would not catch this defect.
- Fixed `/reloadui` with integration enabled: startup registration called a
  nonexistent `integration.InstallExternalHooks` instead of the module-local
  hook installer (`AutoCategoryIntegration.lua:1275: function expected instead
  of nil`). This path was unreachable until a profile was first enabled, and the
  offline startup test covered only the disabled case.
- Replaced the add-on-load startup reconcile with one scheduled from IC's
  AutoCategory plugin initializer. The add-on-load reconcile always found
  `Inited == false` (registration is refused otherwise) and was not retried,
  leaving first activation dependent on lifecycle hooks. AutoCategory calls plugin
  initializers and sets `Inited` in the same synchronous player-activation call,
  so the deferred reconcile now runs after initialization.
- Fixed projection rejecting valid AutoCategory layouts whose run and show
  orders differ. AutoCategory's settings edit `runpriority` and `showpriority`
  independently (`BagSet.lua` setters), and the plan requires those differences
  to be preserved. The final order check built one expected order from external
  show priorities and applied it to both fields, so changing one field in
  AutoCategory settings raised `runpriority mapping cannot preserve the required
  order in Bank` on every reconcile. The check now derives each field's expected
  order from that field's own native sequence, matching how slot priorities were
  already allocated, and places managed groups after entries tied with their
  heading, as the plan requires.
- External AutoCategory ties no longer stop projection. Tied headings are
  ordered alphabetically by AutoCategory itself and no priority can place a
  managed group inside a tie block, so groups anchored to any heading in a block
  are allocated together after the whole block, in that block's alphabetical
  heading order and then saved IC order. Duplicate heading names, which cannot be
  separated alphabetically, anchor at the first native occurrence.
- Unrepresentable external layouts are now treated as an external boundary
  rather than a defect: projection writes nothing, reports
  `unsupported` in Settings and once in chat, keeps settings and editors usable
  so placements can be changed or integration disabled, and resumes
  automatically on the next successful reconcile. The Debug Key reports this as a
  WARN. After the tie handling above, the only remaining case is a floating-point
  priority gap too small to divide. Internal order-check failures still throw.
- Fixed definition sync corrupting AutoCategory's rule registry when an
  integration category is renamed (rank change from a move, group rename) or
  removed. AutoCategory's `removeRuleByName` shifts later rules without
  reindexing `ruleNames`, and sync looked names up before rebuilding the index,
  so a lookup could return a neighbouring rule. In game this raised
  `AutoCategory definition collision appeared after preflight` because the
  neighbour was the retained spike gate rule; with an integration-owned
  neighbour it would instead have silently overwritten and dropped another IC
  category. Sync now rebuilds the index with `cacheRuleInitialize` after
  removals and before lookups. The offline fake previously made these
  registry calls no-ops, which is why no test exercised it.
- Added the settings enablement/status entry, the Edit Items participation
  checkbox, and an AutoCategory view with context selection, heading
  visibility, filters, reset and movement controls.
- Moved the AutoCategory view out of Edit Groups into its own third editor
  tab (`EditPanelAutoCategoryTab.lua/.xml`, scene
  `InventoryCompanion_AutoCategoryScene`), at the user's request, because the
  Groups tab shared its space with the patterns panel and order was hard to
  inspect. The new window keeps the same behavior (context combo, search,
  show-nonparticipating and show-all-headings options, reset, per-row move,
  participation and heading-visibility controls, heading details) but uses an
  830-pixel-wide list with no patterns panel. Edit Groups was restored to its
  pre-integration panel from `main`. Items and Groups gain an `AutoCategory`
  button that is shown only while integration is enabled and available; the
  AutoCategory tab returns to Groups if integration becomes inactive while it
  is open, and the editor toggle reopens Groups instead of an inactive
  AutoCategory tab. The tab manager now handles three tabs, and the cutscene
  ticker, Settings status refresh, Items-row participation toggle and
  `/icclearoverrides` refresh the new tab. The ordering UI itself is
  unchanged; buttons and further layout are to be decided once the user has
  seen it in game.
- Added focused adapter tests and wired them into the existing rule-test
  runner. Added schema migration and downgrade-protection coverage using
  synthetic saved-variable fixtures.
- Updated the user manual and synchronized the spec, implementation plan,
  spike-status record and historical review with the current D4 and
  implementation status.

## Historical verification (before ordering redesign)

| Check | Result |
| --- | --- |
| `python Project\Tests\Run-RuleTests.py` | 115/115 isolated addon tests passed on 2026-11-01; addon Lua syntax checked (Lua 5.1). The downgrade fixture now pins actual schema-3 commit `a78f87957009e261e076c1c7f334f7a5fc0b1f7e` instead of moving `HEAD`; the previously reproduced fixture-version failure is fixed. |
| Synthetic schema safety | Migration preserves fixture data; the pinned pre-feature build rejects schema-4 data before new-field validation and leaves fixture data unchanged. This is synthetic coverage, not normal saved-data testing. |
| AutoCategory startup regression | PASS: registration succeeds with an empty active-bag registry, matching the pre-player-activation state that previously marked integration incompatible. |
| Enabled-startup regression | PASS: with integration enabled, startup reports pending, installs lifecycle hooks, schedules nothing before AutoCategory initializes, and the plugin initializer schedules exactly one projection that runs once `Inited` is true. With only the old hook call restored, it fails with the in-game error. |
| Independent run/show projection regression | PASS: a full `ProjectAutoCategory` run with a Bank heading whose run priority was raised above the anchor and another heading tied with the anchor in show priority writes managed groups immediately after the anchor in each field's native order. Restoring the shared show-order check reproduces the in-game `runpriority mapping` error; removing tie handling fails the show order. In game, the user first hit this error after moving a heading's priority in AutoCategory's own settings on 2026-11-01. |
| Tie-block projection regression | PASS: groups anchored to two Bank headings tied in show priority are written after the alphabetical tie block in show order and immediately after their own headings in run order. Allocating each tied heading separately fails both projection tests and leaves AutoCategory unwritten. Duplicate-name anchoring has no dedicated offline test. |
| Preset dialog regression | PASS: the registered dialog uses at most two buttons, Cancel and no-choice dismissal leave the profile uninitialized, and Confirm applies the selected radio arrangement and enables integration. In-game dialog display is not yet verified. |
| Definition-sync regression | PASS offline against a fake that mirrors AutoCategory's registry (removal shifts `ruleList`; `ruleNames` is stale until `cacheRuleInitialize`): replacing an obsolete rank-prefixed category ahead of current IC categories and an external rule removes only the obsolete one and keeps every other rule exactly once. Without the index rebuild it fails with the in-game `definition collision appeared after preflight` error (first seen in ESO on 2026-11-01). Not yet re-verified in game. |
| AutoCategory editor tab | PASS offline: with mocked controls, the tab renders managed groups and headings, filters by search, moves a group through the integration, toggles participation from the row label, shows heading details, switches context, and falls back to Groups when integration is inactive. Breaking label toggling or reversing the move direction fails the render test. Runner assertions require every child the tab Lua looks up to exist in its XML (a renamed lookup fails), the row/window children, the `AutoCategory` buttons in Items and Groups, and both new files in the DEV manifest. Not yet seen in game. |
| Editor control-layout regression | PASS: runner XML assertions require the item-row toggle `Check`/`Label` children; both the original assertions failed against the previous commit. The Groups-tab row assertion was replaced by the AutoCategory-tab lookup check when the view moved. In-game: Confirm reached the editor refresh (dialog fix verified on 2026-11-01), then crashed on the missing label; the layout fix itself is not yet verified in game. |
| Debug Key AutoCategory check | PASS in ESO Live on 2026-11-01 10:34:15 UTC (API 101051; AutoCategory AddOnVersion 134): plugin registered, AutoCategory initialized, all seven active assignment lists present, integration disabled, zero participating groups and zero managed assignments. This verifies startup/load readiness without writes; enabled projection and assignment-count behavior remain unverified in-game. |
| Debug Key AutoCategory check, enabled startup | PASS in ESO Live on 2026-11-01 10:47:01 UTC (timestamp 1793530021; game eso.live.12.1.6.3309674; API 101051; AutoCategory AddOnVersion 134; 85/85 in-game tests): after `/reloadui` with integration enabled, plugin registered, AutoCategory initialized, integration active, zero participating groups and zero managed assignments across seven contexts. This verifies the enabled-startup fix and the preset Confirm path; projection with participating groups remains unverified. |
| Normal saved data / live inventory | Not used. |
| ESO in-game acceptance | Partial: Debug Key startup checks passed with integration disabled and enabled, as described above. Projection with participating groups and the remaining acceptance matrix are not yet verified. In-game order verification is deferred by the user until the ordering UI is reworked, because the current editors make order hard to inspect. |
| Standalone spike testing | Not reopened or repeated. |

## Historical differences from the earlier implementation plan

- Context moves persist only the moved group's context placement override;
  they do not swap a neighboring group's order. This avoids introducing an
  unrelated override and follows the spec's group-specific context semantics.
- Master combines differently ordered heading lists by heading occurrence and
  a cycle-checked ordering model, rather than assuming one global native
  sequence. Inconsistent/unrepresentable layouts remain acceptance risks; this
  does not claim to solve arbitrary external priority or run/show mismatches.
- The runtime uses the spike-proven built-in plus texture. The final texture
  identity/tint and DEV-versus-release category identity choice remain open
  under D2; no new asset was introduced.
- Only the DEV manifest in this Git repository was wired. The release manifest
  is outside this repository and was not modified; confirm its scope and update
  it before a release package can load the integration.

## Historical decisions and remaining acceptance

- **D4 is approved.** Production rank-bearing empty colour prefixes are
  authorized, including the accepted renamed-heading expansion behavior and
  retained old per-name collapse flags.
- **Q1/Q2:** verify both winning classification and visible heading order in
  ESO for top, crowded, heading-anchored and arbitrary-label placements,
  including external run/show mismatches and finite rank/priority bounds.
  Unsupported cases must fail visibly rather than silently changing external
  entries or falling back to alphabetical order.
- **Q3:** exercise profile switches, edits/renames/deletes, cache invalidation,
  reclassification, refresh and disable against the actual AutoCategory
  runtime. Offline lifecycle tests are not in-game acceptance.
- **Guild Bank and the seven-context matrix:** verify all required keyboard
  contexts, including subscriber Bank and Guild Bank's BulkMode path. Guild
  Bank remains untested. Do not infer gamepad, other crafting tabs, or merchant
  buy/buyback support.
- **Q5:** agree a synthetic workload and numerical timing limits, then measure
  matcher/scan/compile/projection/refresh counts and off/on edit-burst timing.
  Use synthetic data only; do not mutate live inventory or saved variables.
- **D2 and pre-shipping:** settle final asset identity/tint and release
  category-name identity, then complete the documented DEV spike teardown and
  confirm the release manifest. D1 remains conditional if the unchanged
  classification/order contract cannot pass.

Until these gates pass, do not claim compatibility certification or release
readiness. The schema-v4 downgrade test has passed on synthetic data; continue
to avoid normal saved data until the remaining safety checks and in-game
acceptance are complete.
