# AutoCategory integration: master feature document

Updated 2026-11-03.

## Status and authority

This is the authoritative overall feature document. It consolidates the
integration, ordering, setup, responsiveness and profile-synchronization
documents, distinguishing implemented behavior from agreed work not yet done.

- **Implemented baseline:** opt-in integration, independent context orders,
  initial setup, active-profile synchronization, native exclusions and recovery.
  The latest recorded saved-variable schema is **8**.
- **Agreed next change, not implemented:** context-specific IC group exclusion,
  a Display-only Other row and the items-editor area selector, with proposed
  schema **9**. The [current implementation document](Tasks/AutocategoryTweaks_hideICNotDelete.md)
  owns detailed work sequencing, migration examples and acceptance for this work.
- **Verification:** historical offline results and limited ESO confirmations
  exist; full compatibility certification and release readiness remain pending.
  Documentation consolidation does not constitute a new test pass.

For requirements use this document and the current implementation document.
The [historical documents](<#historical-document-index>) retain dated evidence
and dependency investigations, not independent current requirements or work
authorizations. In particular, Master inheritance, rank/anchor placement,
fractional priorities, rank-bearing names and five-second ordering queues are
superseded designs.

## Open decisions and acceptance gates

- There are no remaining behavioral questions for the current exclusion/Other
  change; its decisions are confirmed in the implementation document.
- Final heading asset, DEV/release identity policy and exact tint still require
  publication review. The old built-in texture probe is evidence, not an
  approved final asset. Optional include/exclude badges and colour settings
  are outside this change.
- Guild Bank and the complete keyboard context/lifecycle matrix still require
  in-game confirmation. Gamepad is outside the initial supported scope.
- Record the outstanding in-game performance baseline and confirm its proposed
  limits; historical offline timings do not certify real ESO performance.
- Verify release packaging and dependency declarations before publishing.
  Do not assume the separate installed release tree contains DEV integration.

## Purpose and terminology

Configure ordinary Inventory Companion (IC) group filters once and reuse them
as native AutoCategory (AC) categories. AC continues selecting categories,
rendering headings, sorting inventory and managing collapse state.

- **Group:** an ordinary IC group, identified by its stable rule key.
- **Native category:** an existing AC category, identified by its complete name.
- **Managed category:** an AC definition/assignment supplied by IC.
- **Context/area:** one of the seven inventory contexts below.
- **Display:** heading presentation order.
- **Priority / matching:** first-match classification order, independent of Display.
- **Other:** IC's special catch-all helper, distinct from any native AC Other.

Individual tracked items and the IC Miscellaneous presentation group are not
exported. Participation is independent of tracker Show/Notify, hidden state,
expansion and pickup notification behavior. Reuse IC's compiled include-any /
exclude-none name and wildcard matching, including existing empty-pattern
semantics; do not introduce a second matching implementation.

## Contexts and ordering

Support Backpack, Bank, Guild Bank, House Bank, Crafting Station, Craft Bag and
Furniture Vault. Standard and subscriber bank share Bank. Other crafting tabs,
professions, universal deconstruction and merchant buy/buyback are not implicitly
certified by a sampled context pass; merchant Sell is supplementary evidence.

Each context owns independent Display and Priority sequences. There is no
Master list or ongoing inheritance. Stable references are `ic:<rule key>` and
`ac:<full category name>`; preserve names containing colons and ESO markup.
Renaming an IC group does not change its stable identity.

- Display edits must not change matching; Priority edits must not change Display.
- Support row moves, selected-block moves, top/bottom and existing step sizes.
- Copying another context is a one-time operation, retaining destination-specific
  membership and existing destination-slot merge behavior.
- Same-context "Use priority list" / "Use display list" copies ordering, not an
  ongoing link. The target change handles Other's unequal list membership.
- Search/filtering must not alter saved order or classification.
- Project distinct integer priorities within AC's supported 2-1000 range.
  Reserve one slot for Other: at most **998 user assignments plus Other** per
  context. Reject excess capacity before publication, not by dropping rows.
- Native assignments may have their run/show priorities rewritten by intentional
  IC ordering. Preserve their names, definitions, membership, hide flags and all
  unrelated options. Do not edit installed AC source or replace its classifier.

## Inclusion and Other

### Implemented schema-8 baseline

IC group inclusion currently toggles the global `autoCategoryEnabled` flag.
Native category exclusions are per-context. Both editors use Included/Excluded
sections, but excluding an IC group currently removes its participation across
all contexts. Other is automatic and absent from both IC ordering lists.

### Agreed target behavior

The current implementation document supersedes that global IC-group behavior:

- Both IC groups and native categories have one per-context inclusion state
  shared by Display and Priority. Excluding in Bank does not affect Craft Bag.
- Excluded rows remain accessible below the Excluded divider, without deleting
  source configuration or removing participation in other areas.
- Runtime matching is always **included categories -> Other -> excluded
  categories**. Excluded categories remain saved but receive no items.
- On exclusion remember the display position. Re-inclusion follows the existing
  insert-below-occupant rule, appending if out of range; matching insertion uses
  the restored display number, not the pre-exclusion matching number.
- Other initially appears last in the included Display section. It can be moved
  and its per-context position persists; it cannot be excluded or deleted and is
  not an ordinary editable group. It stays absent from Priority.
- New groups start Included in all seven contexts. Insert immediately above
  Other's current Display position, even after it has moved. Matching insertion
  is immediately before the automatic barrier.
- "Use display list" omits Other when transferring order to Priority.
  "Use priority list" retains Other's saved display slot. Context copying carries
  its display placement under the destination-membership rules.
- Moving Other above Sets in Display changes presentation only: included Sets
  still gets its matching opportunity before Other.

## User experience

Integration remains opt-in and disabled by default. Settings expose enablement,
status and an Open AutoCategory Editor action. Preserve the existing recovery
entry points and distinguish unavailable/inactive controls from usable ones.

First setup uses the native two-radio arrangement dialog:
**Near the top (default)** or **At the bottom**, with Confirm/Cancel. Near the top
inserts initially participating groups alphabetically after AC's localized,
visible New assignment, or at the top if unavailable/hidden; bottom follows
native assignments. Use AC's localized New string, not ESO's similarly named
item-filter string. Cancel/dismissal publishes nothing.

Existing first-time setup seeds participation from effective Show Backpack,
Show Bank, Notify Chat and Notify HUD flags. Later tracker-flag edits do not
reseed it. This is separate from the confirmed all-areas Included default for
newly created groups in the target design.

The AutoCategory editor has a context selector, Display/Priority modes, ordering
and copy actions, green Included/red Excluded labels, red excluded names and a
single Excluded divider. State and action must be understandable without colour.
Excluded rows have no move controls. Special Other has ordering controls only.

The target items-editor AutoCategory column opens a seven-checkbox area selector,
using the same inclusion operation as the ordering editor. Individual items and
Miscellaneous have no selector. Preserve column alignment and failure access.

Choose its summary in this order:

1. All enabled: **All**. None enabled: **None**.
2. One enabled: its name. One disabled: **Not: <name>**.
3. Use the comma-separated enabled names if they fit.
4. Otherwise use **Not: ** plus disabled names if they fit.
5. Otherwise use the enabled count in words, such as **Three Areas**.

Measure rendered width using the label's font and available space, including
separators/prefix. Keep context order, prefer enabled names when they fit and
accommodate the longest single-area exception. Tooltip/dropdown exposes the
complete state. Save neither summary text nor a duplicate checkbox-state map.

## Profile ownership and synchronization

IC selects the source configuration; AC independently selects the destination.
All four combinations are supported:

| IC source | AC destination | Behavior |
| --- | --- | --- |
| Account-wide | Account-wide | Shared IC arrangement in shared AC |
| Character | Account-wide | Active character replaces generated shared AC rows |
| Account-wide | Character | Shared IC arrangement in active character's AC |
| Character | Character | Active character's IC arrangement in its AC |

Synchronize after both sides are ready on login/reload, either scope change and
relevant group/profile edits. Never force scopes to match or project into
inactive AC profiles. In shared AC/character IC, A/B/A must restore each IC
source's own arrangement without deleting either source.

1. Establish complete selected IC runtime and AC readiness.
2. Validate ownership, collisions and all affected context plans before writing.
3. Replace obsolete IC-owned output and add/update current output in active AC.
4. Apply selected IC orders and refresh affected caches/lists without recursion.
5. Publish proposed IC settings only after successful projection; on failure
   restore assignments/templates and report the cause.

Generated assignments are replaceable output, not the only copy of settings.
Preserve complete AC-side options by stable identity in each active bag's
`icAssignmentTemplates`. Never identify ownership from a similar label.
Unavailable native references can remain dormant across destination switches;
an observed deletion in the same source/destination is a different case.
Cold startup uses saved IC order, not stale generated AC layout.

On first selection of a wholly uninitialized IC destination, copy the complete
source configuration by value once: groups, items, tracker/notification choices,
integration enablement/setup, inclusion, orders and restoration positions.
Explicit profile copying uses compatible complete-copy semantics. Do not
overwrite initialized destinations; existing groups with uninitialized integration
use setup rather than replacement. Historical recovery archives are not replayed
automatically into an unverified destination.

## Disable, reset and failure handling

- Ordinary disable removes generated assignments, including Other, from active
  AC and refreshes it. Preserve IC choices and last projected native priorities.
  Re-enable recreates output. The predicate must stop matching while disabled.
- Explain: "IC exclusions will stop applying. AutoCategory keeps the last
  matching order set by IC; previously excluded categories may match later
  than others." Do not restore an initial native-priority snapshot.
- Reset warns, then offers the starting arrangement; cancellation at either
  stage preserves all state. Commit only after confirmation, replacing layout
  and resettable exclusions/restoration references while preserving source
  groups, items and existing participation choices. The current implementation
  change must preserve these existing reset contracts unless explicitly revised.
- Missing AC must not prevent ordinary IC operation. Offline evidence shows
  missing IC definitions fall through in AC, with missing assignments marked
  red in its settings; this is not in-game uninstall certification.
- Integration failures report the root cause, stop integration for the session,
  cancel stale scheduled work and remove generated output where external APIs
  permit. Report cleanup failures separately; keep recovery access and saved
  choices. Genuine failures retain Retry/Repair/Reset diagnostics.
- Normal stale assignments are synchronization, not recovery errors. Incomplete
  IC runtime, collisions, malformed priorities and broken contracts are errors,
  not permission to silently delete or substitute data.
- Unsupported newer schemas and unrelated core-data errors still stop startup.
  Preserve/report malformed integration-only saved data rather than normalizing
  it into success. After boundary validation, internal contracts fail directly.

## Saved variables and migration

Schema 8 stores per-profile integration enablement/setup, global group
participation, independent context `display`/`matching` lists, native `hidden`
flags, `displayPositions` and an `itemListInitialized` marker.

Proposed schema 9 extends `hidden` to IC references, retains excluded group
references in context sequences and stores `ic:__ic_other` in Display only.
The global flag no longer controls context inclusion. Migrate enabled groups
as included everywhere; existing nonparticipants become excluded tails in every
context, not newly included groups. Initialize Other last in the included
Display section. The implementation document contains illustrative SV excerpts.

Validate every profile and import before ZOS constructors, preserving unrelated
data, options, markers and inactive profiles. Do not persist derived priorities
as a competing IC order model. Schema increments are required whenever older
builds cannot safely preserve new data. DEV/release share saves: test actual
older supported builds rejecting the new schema without constructors or
mutation before normal game-data testing. No backup restore, cleanup command
or live-save editing is authorized by this document.

## Dependency contracts to retain

The inspected release was **AutoCategory 4.5.2 / AddOnVersion 134**; recheck
contracts on dependency changes rather than assuming permanent API guarantees.
See the archived [source trail and failure history](<Archive/AutoCategory Integration/AutoCategorySpikeResults.md#dependency-contracts-and-source-trail>).

- Declare AC as optional. Register on IC's own add-on-loaded event after AC's
  load handler, not a second listener assumed to run later on AC's event.
- `RegisterPlugin` stores definitions/initializer but does not immediately
  initialize or assign categories; late registration does not replay startup.
  Install the real `AddRuleFunc` predicate before evaluation.
- Wait for active saved assignments and `Inited` before projection. Definitions
  are code-supplied each session; do not write IC definitions to `AutoCatRules`.
- Preflight collisions against definitions and assignments. AC's rule-add path
  can otherwise rename conflicts and redirect existing assignments.
- Higher `runpriority` wins; ties sort by name. Native display uses
  `string.format("%04d%s", 1000-showpriority, categoryName)`: fractional
  differences can disappear. This motivated integer sequences, not prefixes.
- Registry, bag-cache and list-refresh APIs operate at different layers.
  `cache.AddRule` uses nil-success / error-string-failure. `RefreshList(..., true)`
  does not force cached keyboard reclassification; crafting needs false.
- Group definition changes may require registry/compile updates; ordering-only
  changes should not. Refresh only changed bags; no-op moves write nothing.
- AC's profile setter rebuilds caches; settings-only switching has a recorded
  nil-global defect. Do not patch dependency source or invent its missing global.
- Collapse state is name-based. Real renames may restart expansion and leave
  old flags; do not prune unrelated AC state.
- Guild Bank uses a separate assignment list and has a BulkMode bypass.
  Its presence in a synthetic context list is not proof of in-game support.
- Synthetic copies must detach ZO_SavedVars write-through proxies/metatables.
  A historical probe leaked state by copying a proxy; retain that regression.
- ESO uses Lua 5.1; `xpcall` argument forwarding requires a closure.

## Verification record and remaining work

These are recorded results from the source documents, not rerun during this
consolidation:

| Evidence | Recorded result | Limit |
| --- | --- | --- |
| Isolated addon runner, 2026-11-03 | 192/192, Lua 5.1 syntax checks | Synthetic boundaries; schema-8 baseline |
| Installed-dependency spike runner | 31/31 | Inspected AC modules, not complete ESO execution |
| Synthetic burst | 100 updates, 128 groups, seven contexts; seven refreshes, zero cache rebuilds; sampled 6 ms CPU | Not an ESO performance certification |
| Setup and reorder UX, 2026-11-01 | Author-confirmed setup and responsiveness; 50 ms slow-action setting produced no reports | Earlier feature state, not acceptance of schema-9 changes |
| Historical context spike | Six contexts sampled; Guild Bank deferred | Not full current lifecycle/context certification |

Existing commands:

```powershell
python Project\Tests\Run-RuleTests.py
python Project\Tests\Run-AutoCategorySpike.py
```

Use the existing Lua 5.1 runner/runtime, not default Lua 5.4+. In-game
`/ictest verbose copy` has proposed limits: 20 synthetic rule edits 250 ms,
five reorder preflights 250 ms total, one registry/compile pass 250 ms and
2000 synthetic classifications across 20 groups 100 ms. Measure and record;
these thresholds are not reported passes.

Before calling the target implementation complete:

1. Pass schema-9 all-profile migration/import/copy and actual older-build
   downgrade rejection using synthetic data.
2. Cover context inclusion from both editors, exclusion/re-inclusion positions,
   moved-Other insertion, all/none groups, order conversion/copy, rollback,
   collisions, recovery and no-op/changed-bag performance contracts.
3. Verify classification and rendered order in each required keyboard context,
   with overlapping filters, Bank/subscriber mapping, Other and native categories.
4. Exercise reload, A/B/A, all four scopes, both scope switches, dormant native
   references, first-time copying, rename/delete, AC-side options and external edits.
5. Confirm disable/re-enable, reset warning/arrangement cancellation, successful
   reset and genuine-failure recovery. Check an IC-absent session separately.
6. Measure safe synthetic bursts and real UI responsiveness; no transfers,
   inventory mutation or normal saved-variable writes from synthetic tests.

Back up IC and AC saves before approved in-game schema testing. Distinguish
offline passes, native-list inspection, unavailable cases and user visual
confirmation. If a dependency limitation prevents the required behavior,
present evidence and obtain a decision rather than silently changing semantics
or taking over AC classification/rendering.

## Historical document index

All retained under [Archive / AutoCategory Integration](<Archive/AutoCategory Integration>):

- [Original specification](<Archive/AutoCategory Integration/todo_plan_autocategoryIntegration.md>)
- [Original implementation plan](<Archive/AutoCategory Integration/todo_implementation_autocategoryIntegration.md>)
- [Ordering redesign](<Archive/AutoCategory Integration/todo_implementation_autocategoryOrderingFix.md>)
- [Profile synchronization fix and latest baseline evidence](<Archive/AutoCategory Integration/AutoCategorySynchronizationFix.md>)
- [Implementation report](<Archive/AutoCategory Integration/AutoCategoryImplementationReport.md>)
- [Spike results, dependency contracts and failed approaches](<Archive/AutoCategory Integration/AutoCategorySpikeResults.md>)
- [Original spec/plan review](<Archive/AutoCategory Integration/AutoCategoryIntegrationReview.md>)
- [Setup, responsiveness and deferred test history](<Archive/AutoCategory Integration/todo_testing_autocategoryFixes.md>)
- [Historical gate-testing prompt](<Archive/AutoCategory Integration/prompt_autocategoryGateTesting.md>)
- [Historical in-game-testing prompt](<Archive/AutoCategory Integration/prompt_autocategoryInGameTests.md>)
