# AutoCategory integration and settings/editor polish

Updated 2026-11-04.

## Status and authority

This is the single authoritative specification of the completed AutoCategory
feature and its associated profile/settings/editor work. The author closed this
work on 2026-11-04. The current saved-variable schema is **10**.

The final behavior below incorporates the exclusion/Other changes, approved
polishing decisions and subsequent UI tweaks. Plans, snag lists, screenshots,
spikes and dated test reports are retained in the
[historical document index](#historical-document-index); they are reference
material, not outstanding tasks or independent current requirements.

Feature completion does not certify a release package or turn historical offline
results into new in-game evidence. Publication review, version selection and
candidate testing follow the [release checklist](../../Publishing/ReleaseChecklist.md).

## Documentation handoff

Use this specification when updating the [user manual](../../Publishing/Source%20Documents/UserManual.bbcode)
and archived [feature overview](../../Publishing/Archive/Legacy%20Sources/Features.md).

- **Feature overview:** optional reuse of IC group filters in AutoCategory,
  independent per-area Display/Priority orders, Hide/Show participation, movable
  Display-only Other, full profiles and visit-scoped undo.
- **Manual:** enablement and first setup; the seven-area selector; Display versus
  Priority; selection/movement; Hide/Show and re-inclusion; both-order context
  copying; undo scope; full-profile switching/copying; disable and recovery.
- Use the final labels **Manage Tracking**, **Manage Groups** and
  **Manage AutoCategory**. Do not revive the removed tracking-editor AutoCategory
  column, area-summary popup, divergence warnings, cross-mode copy or Store/Reset
  snapshot buttons from earlier plans or screenshots.
- Distinguish IC's special Other from the tracker's Miscellaneous group and any
  native AC category named Other. Explain that Hide affects matching in one
  inventory area, not just visibility or the source group.
- TTC and FCO ItemSaver are disabled planned placeholders, not available
  integrations. Do not advertise their proposed pricing/marker behavior.
- Describe keyboard inventory behavior; gamepad is outside the initial scope.
  Do not claim universal context/dependency compatibility or publish synthetic
  timings as real ESO performance guarantees.

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
- Copying another context copies both Display and Priority in one operation,
  regardless of the visible mode. It is a one-time operation, retaining
  destination-specific membership and existing destination-slot merge behavior.
- There are no same-context cross-mode copy actions or divergence warnings.
- Search/filtering must not alter saved order or classification.
- Project distinct integer priorities within AC's supported 2-1000 range.
  Reserve one slot for Other: at most **998 user assignments plus Other** per
  context. Reject excess capacity before publication, not by dropping rows.
- Native assignments may have their run/show priorities rewritten by intentional
  IC ordering. Preserve their names, definitions, membership, hide flags and all
  unrelated options. Do not edit installed AC source or replace its classifier.

## Inclusion and Other

- Both IC groups and native categories have one per-context inclusion state
  shared by Display and Priority. Excluding in Bank does not affect Craft Bag.
- Manage AutoCategory is the only participation editor. Included rows offer
  **Hide**, excluded rows offer **Show**; Other has neither action.
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
- Context copying carries Other's display placement under the
  destination-membership rules; there is no cross-mode copy action.
- Moving Other above Sets in Display changes presentation only: included Sets
  still gets its matching opportunity before Other.

## User experience

Integration remains opt-in and disabled by default. Main Settings groups its
information, account-wide Enable toggle and a compact Settings button inside
the AutoCategory expander under Integrations. This single button also opens
recovery during a failure; there is no duplicate More information action.
Other integrations are expanders too, without standalone section buttons.
Panels has one row of three editor-management buttons. Debugging is the final
expander. The profile-copy explanation precedes its source dropdown.

The order editor uses a separate larger Display/Priority order heading without
a colon. The main explanation is one paragraph using the same ZoFontGame font,
default colour and default wrapping as Main Settings descriptions. It names
the selected inventory area. Selection/movement instructions use the same
full-size regular font and normal text colour immediately above the bottom
movement buttons. The list ends above this guidance, without overlap.
Native line counts select concise equivalent copy if the two labels
would exceed three lines. Both label heights follow the rendered text, and the
list fills the remaining space without clipping the explanation.
Hide/Show remain actual buttons but no longer inherit decorative button bars.

First setup uses the native two-radio arrangement dialog:
**Near the top (default)** or **At the bottom**, with Confirm/Cancel. Near the top
inserts initially participating groups alphabetically after AC's localized,
visible New assignment, or at the top if unavailable/hidden; bottom follows
native assignments. Use AC's localized New string, not ESO's similarly named
item-filter string. Cancel/dismissal publishes nothing.

Existing first-time setup seeds participation from effective Show Backpack,
Show Bank, Notify Chat and Notify HUD flags. Later tracker-flag edits do not
reseed it. This is separate from the confirmed all-areas Included default for
newly created groups.

The AutoCategory editor has a context selector, Display/Priority modes, ordering
and context-copy actions, Hide/Show action buttons, red excluded names and a
single Excluded divider. State and action must be understandable without colour.
Excluded rows have no move controls. Special Other has ordering controls only.

Manage Tracking replaces the former Manage Items name. It has no AutoCategory
column or area-selector popup: use Manage AutoCategory for participation and
ordering, including recovery access. This supersedes the earlier area-selector
design without changing saved inclusion choices.

Fixed Show and Notify headings align with the corresponding row controls.
Single-line summaries use the same regular body font as item/group names and
omit repeated `Show:` and `Notify:` prefixes. Item/group names retain their full
width regardless of AutoCategory availability or state.

All three editors share aligned navigation:
**Main Settings**, **Manage Tracking**, **Manage Groups**, **Manage AutoCategory**.
The current editor's button is disabled. On Tracking/Groups, the AutoCategory
button is hidden if AC is absent, but is available if AC is loaded and integration
is off. That off view shares Main Settings' integration information and
account-wide enable toggle. Ordering becomes available only after successful
setup/synchronization; genuine failures show recovery, not an ordinary off view.

Movement actions are grouped **Up 1 / Up 5 / Move to Top**, then
**Down 1 / Down 5 / Move to Bottom**, preserving Shift multi-selection and block
moves. Display/Priority mode buttons sit together; Copy From is at the right and
explains that it copies both orders. Excluded rows cannot be moved.

Manage Groups filters the displayed names in its left-hand list, not pattern
contents or the right-hand rule editor. Filtering, clearing a search and no-result
views never change definitions, participation or saved order. Manage Tracking
keeps its existing Show/Notify actions, with single-line summaries that truncate
rather than wrap.

## Main Settings and full profiles

Main Settings is the only home for profile selection and full-profile copying.
The selected account or character profile owns tracked items/groups,
AutoCategory setup/orders/inclusion, tracker visibility/layout, currency/capacity
preferences, resource-bar settings and editor filters.

The explicit account-wide exceptions are integration enablement switches,
Item Transfer Delay, Auto-Merge Chest Stacks, Debug Mode and diagnostic timing
thresholds. Inventory/cache records, schema/identity metadata, diagnostic history
and recovery backups are not profile preferences. Planned TTC/FCO controls have
no saved configuration or runtime behavior.

- First use of character settings deep-copies account profile content once.
- Switching to account settings retains the character profile unchanged.
- Switching back resumes that retained character profile; it does not merge
  later account changes. Initialized empty lists are valid, not first use.
- **Copy From** replaces the complete destination profile after preview and
  confirmation, removing destination-only settings/items/groups. It is not a
  merge or groups-only import. Account-to-character, character-to-account and
  character-to-character copying use independent nested tables.
- Copying preserves destination identity, scope selection, schema metadata,
  account-only controls and unrelated data. Sources belong to the same account;
  self-copy, unavailable sources and invalid data are reported explicitly.
- Selection and copying refresh the affected panels, geometry, event behavior,
  matching caches and active AC output through the existing lifecycle.

The **Panels** section has the three management buttons in one row, followed by
tracker, currency/capacity and standalone-resource settings. **Integrations** has
an explanation and individual expanders, not a row of integration launch
buttons. The AutoCategory expander contains its information, Enable and Settings
controls. TTC and FCO ItemSaver remain visibly disabled/off and marked planned;
their presence does not indicate implemented price bands or marker groups.
**Debugging** is the final expander. The DEV failure-simulation control is removed.

## Visit-scoped Undo changes

All three editors apply edits immediately and automatically take an independent,
memory-only opening baseline after initialization/synchronization.
**Undo changes** appears only while meaningful editable state differs from that
baseline; manual reversal also hides it. Undo restores the baseline and keeps it
available for subsequent edits during the same visit.

- Tracking/Groups restore coherent editable item/rule state and its dependent
  configuration, not unrelated preferences or runtime selection/scroll state.
- AutoCategory restores the currently viewed context/mode's opening order and
  the context's shared inclusion state. Inclusion affects both modes; undo does
  not independently restore the opposite order or any other context. Membership
  reconciliation still preserves Other's Display-only invariant.
- Changing context or mode does not replace the opening baseline. Snapshots and
  callbacks remain bound to their profile and editor.
- Close, tab switch, opening Main Settings or closing by hotkey discards the
  baseline. Reopening/reload starts a new visit; nothing is saved across sessions.
- Validate external references before restoration. Changed/missing dependencies
  cause an explicit failure without partial restore or overwriting unrelated AC
  definitions/options.

There are no Store Current Settings, Reset to Last Stored Settings, staged
Save/Cancel or ordinary arrangement-reset controls. Undo is separate from the
failure-recovery panel and its last-resort reset. Account-wide integration
enablement is not undoable profile content.

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

On first enabling character settings, copy the account profile by value once:
groups, items, panel preferences, editor filters, integration setup, inclusion,
orders and restoration positions. Enablement remains account-wide and is not
copied. Switching back to account settings never replaces the account profile;
later character switches resume retained content. Explicit full-profile copying
replaces initialized destinations only after confirmation. Historical recovery
archives are not replayed automatically into an unverified destination.

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
  groups, items and existing participation choices. This is the last-resort
  recovery reset, not an ordinary ordering-editor action.
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

Schema 10 stores full selected profiles. Integration enablement, transfer delay,
chest-stack merging, Debug Mode and timing diagnostics remain account-wide.
Tracker/currency/progress-bar settings and editor filters follow the selected
profile. Full copying replaces rather than merges and preserves destination
identity, scope/schema metadata, account controls, caches and recovery data.

The schema-10 migration alone clears unused character content for account-mode
characters, preserving unrelated data. Character-mode profiles are upgraded,
inheriting missing legacy preferences from the account profile. First enabling
character mode deep-copies account content; subsequent switches resume retained
character content without copying account changes. Every future migration must
upgrade inactive initialized profiles too, without repeating this cleanup.
The actual schema-9 build is tested for non-mutating rejection of schema 10.

### Earlier schema migration contracts

Schema 8 stored per-profile integration enablement/setup, global group
participation, independent context `display`/`matching` lists, native `hidden`
flags, `displayPositions` and an `itemListInitialized` marker.

Schema 9 extends `hidden` to IC references, retains excluded group
references in context sequences and stores `ic:__ic_other` in Display only.
The global flag no longer controls context inclusion. Migrate enabled groups
as included everywhere; existing nonparticipants become excluded tails in every
context, not newly included groups. Initialize Other last in the included
Display section. The archived
[exclusion/Other plan](<../Archive/AutoCategory Integration/AutocategoryTweaks_hideICNotDelete.md#illustrative-saved-variable-excerpts>)
contains illustrative SV excerpts, not a second current data contract.
Stored account-wide list backups migrate with their owning profile. Schema-4
through schema-8 builds are exercised directly for non-mutating downgrade
rejection. Reset preserves per-context IC inclusion, clearing native exclusions
and restoration positions as before.

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
See the archived [source trail and failure history](<../Archive/AutoCategory Integration/AutoCategorySpikeResults.md#dependency-contracts-and-source-trail>).

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

## Verification record and release evidence

The current isolated runner was rerun during this consolidation. Older rows
retain dated source evidence; dependency-spike and in-game results were not
rerun or newly certified.

| Evidence | Recorded result | Limit |
| --- | --- | --- |
| Isolated addon runner, 2026-11-04 | 211/211, Lua 5.1 syntax and editor XML checks; full profiles, migration/downgrade rejection, undo, tracking columns and dedicated participation editor | Synthetic boundaries; no live inventory or normal saved-variable access |
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

The following scenarios remain the reference matrix for release testing and
future regressions, not an open implementation plan:

1. Pass schema-10 all-profile migration/import/copy and actual older-build
   downgrade rejection using synthetic data.
2. Cover context inclusion through Manage AutoCategory, preservation of tracking
   flags, exclusion/re-inclusion positions, moved-Other insertion, all/none
   groups, both-order context copying, rollback,
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

Older source documents list pending Guild Bank/lifecycle, visual, performance,
heading-asset and packaging checks. Those are dated evidence gaps, not surviving
feature tasks after the author's completion decision. Do not invent results for
them: use the actual candidate and release checklist to establish publication
evidence. The separate installed release tree is not updated by DEV completion.
Optional badge/colour controls and gamepad support are outside this feature.

## Historical document index

All retained under [Archive / AutoCategory Integration](<../Archive/AutoCategory Integration>).
Historical proposals are superseded by this specification, including Master
inheritance, rank/anchor placement, fractional priorities, rank-bearing names,
five-second ordering queues, runtime profile merging and the tracking-editor
area selector. Archived checklists do not reopen completed work.

- [Settings/profile/editor polishing plan](<../Archive/AutoCategory Integration/AutoCategory_Polishing_ImplementationPlan.md>)
- [Original polishing snag lists and reference screenshots](<../Archive/AutoCategory Integration/AutoCategory_Polishing_Tweaks.md>)
- [Context-specific exclusion and movable Other plan](<../Archive/AutoCategory Integration/AutocategoryTweaks_hideICNotDelete.md>)
- [Original specification](<../Archive/AutoCategory Integration/todo_plan_autocategoryIntegration.md>)
- [Original implementation plan](<../Archive/AutoCategory Integration/todo_implementation_autocategoryIntegration.md>)
- [Ordering redesign](<../Archive/AutoCategory Integration/todo_implementation_autocategoryOrderingFix.md>)
- [Profile synchronization fix and baseline evidence](<../Archive/AutoCategory Integration/AutoCategorySynchronizationFix.md>)
- [Implementation report](<../Archive/AutoCategory Integration/AutoCategoryImplementationReport.md>)
- [Spike results, dependency contracts and failed approaches](<../Archive/AutoCategory Integration/AutoCategorySpikeResults.md>)
- [Original spec/plan review](<../Archive/AutoCategory Integration/AutoCategoryIntegrationReview.md>)
- [Setup, responsiveness and deferred test history](<../Archive/AutoCategory Integration/todo_testing_autocategoryFixes.md>)
- [Historical gate-testing prompt](<../Archive/AutoCategory Integration/prompt_autocategoryGateTesting.md>)
- [Historical in-game-testing prompt](<../Archive/AutoCategory Integration/prompt_autocategoryInGameTests.md>)
- [Heading-icon discussion](<../Archive/AutoCategory Integration/prompt_categoryIcon.md>)
- [Earlier UI improvement notes](<../Archive/AutoCategory Integration/UIImprovements.md>)
