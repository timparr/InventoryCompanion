# AutoCategory integration

Status: Planned; no integration code or settings are implemented. Updated on
2026-10-31 to record the confirmed combined-list scope, character
participation, inactive UI behavior, and accepted defaults. After the native
insertion spike, ordering storage was changed: AutoCategory's own active
per-bag list is the order record (see Saved-data compatibility).

The [implementation plan](todo_implementation_autocategoryIntegration.md)
contains the investigated extension points, ordered changes, tests, and gates.
The [Show/Notify row-options prerequisite](../Completed/ItemTrackerFlags.md)
is complete; it is not another implementation stage for this feature.

## Goal and initial scope

Configure groups once in Inventory Companion and optionally use them as
AutoCategory inventory partitions, without duplicating filter expressions.
AutoCategory continues drawing and sorting its inventory sections. Do not
modify its installed source.

- Integration is opt-in and disabled by default.
- Support Backpack and Bank initially. Standard and subscriber bank share
  the Bank ranking context.
- AutoCategory also recognizes craft bag, guild bank, house bank, and furniture
  vault contexts. Add selector options only when their matching, lifecycle, and
  rendering have been verified; those contexts and crafting/deconstruction views
  are not initial acceptance requirements.
- Use the active account-wide or character-specific Inventory Companion groups.
- Reuse compiled name/wildcard matching, including case-insensitive matching,
  include-any / exclude-none semantics, and empty-pattern behavior.
- Each participating ordinary group can supply one managed category.
  Miscellaneous and individually tracked items are not exported initially:
  Miscellaneous is assembled by tracker presentation rather than ordinary
  pattern membership.
- Provide a combined ordering view of our groups and the selected inventory's
  existing AutoCategory categories if technically feasible. Initially place our
  groups above existing categories; users can then interleave them with arrows.
- External filter expressions and definitions are read-only in Phase I.
  Reordering their selected-inventory assignments is permitted; editing filters,
  creating/deleting external rules, and changing their hide/enable state are not.
- Preserve external definitions, settings, inactive profiles, and saved data.
  Change run precedence only through initial managed insertion or explicit
  ordering actions, not unrelated synchronization. Unmatched items remain
  available to AutoCategory's other rules.
- No inventory transfers, item mutation, or full scans during classification.

## User experience

### Participation and existing Show/Notify controls

Add the full **AutoCategory** label last on group rows in the item tracker
editor, after Show and Notify, as an independent participation toggle.
Individual rows have no participation control.

- Participation does not depend on Show backpack/bank, grouping, Notify
  Chat/HUD, hidden-HUD-group state, or expansion. Hiding a group from the
  tracker does not remove its AutoCategory partition.
- Notify remains pickup delivery. Classification neither sends a notification
  nor changes its destination union, positive-gain detection, hidden-group
  notification policy, or duplicate/burst handling.
- AutoCategory collapse remains independent of tracker expansion and automatic
  height decisions.
- When integration is disabled or unavailable, the AutoCategory column has zero
  width, returning space to names. When active, reserve the same width across
  all row types, including nonparticipating groups and individual items.
- All integration editor UI is hidden while AutoCategory/integration is off or
  unavailable: the top view toggle, inventory selector, combined list, arrows,
  external details, and participation controls. Return an open AutoCategory view
  to the normal group view. Keep saved order/participation intact; do not add an
  inactive preview. The main settings enable control is the entry point for
  turning integration on, not another inactive editor view.
- Do not expose a working-looking control or save placeholder settings before
  the adapter and matching work.

### Alternative AutoCategory view in the group editor

This is required functionality, not an unresolved overlap proposal.

- Put an **AutoCategory** view toggle at the top of the group editor. It
  switches between the existing normal group view and the AutoCategory view;
  it does not enable/disable integration or toggle a selected group's
  participation.
- In that view, provide an inventory selector: **Backpack / Bank** initially.
  A dropdown or radio buttons may be used to fit the existing toolbar. Select
  only verified supported contexts, not every raw ESO bag ID.
- Show ordinary Inventory Companion groups and existing assigned AutoCategory
  categories in one most-important-to-least-important list for the selected
  inventory. Distinguish sources with a label/badge and stable row identity.
  Show external categories as read-only definitions, but allow their order to
  change with the same up/down buttons.
- Rank and AutoCategory evaluation order are the same thing: this list is a view
  of AutoCategory's active bag-rule order for the selected inventory, not a
  separate copy. Initially place our groups at the top, retaining existing
  external relative order. Later synchronization must not move them back to the
  top after a user has interleaved categories, whether in our editor or in
  AutoCategory's own settings.
- Use the currency panel's ordering rows in ESO's main game settings panel as
  the explicit interaction model: the same native per-row up/down arrow buttons,
  hover tooltips, click sound, immediate save/reorder, and moved-row highlight.
  Up makes the group more important; Down makes it less important. Additionally,
  keep the moved group selected and visible in the group editor.
- Indicate participation separately from rank. A nonparticipating group's
  stored position is retained but it cannot win classification.
- Switching view or inventory alone must not write settings, normalize saved
  ranks, reorder the tracker, change participation, or refresh inventories.
- This view edits classification precedence only. A separate Rule precedence /
  Display order selector is not required. AutoCategory's section display order
  is not synonymous with classification rank.
- Do not add tracker-order editing, drag/drop, or a second filter-expression
  editor as prerequisites.
- Selecting an external row shows read-only details, not our editable
  name/pattern controls. Do not imply that its expression can be edited here.

### Accepted defaults and edge behavior

The author accepted these defaults on 2026-10-31. Combined-list movement extends
them to external rows without adding external filter editing.

- New/missing participation is off; global opt-in does not enroll all groups.
- A group enters AutoCategory's list when it first participates in a context's
  active profile, at the end of the managed subsequence (top of the list when
  no managed groups exist yet). Turning participation off keeps its entry and
  position; its predicate simply returns false. Up/down moves adjacent rows in
  the complete combined selected-context list.
- Never-enrolled groups have no position. Proposed: list them below the ordered
  rows without arrows until they first participate. Awaiting confirmation.
- Positions come only from AutoCategory's list. Ties are resolved by stable
  internal-rule-key order, independent of mutable display names; normalize run
  priorities only when the user moves a row or a new group is inserted.
- The normal view retains its current ordering. Search may narrow either view,
  but disable move buttons while search hides groups, with a tooltip explaining
  why; do not silently move across invisible rows.
- Disable Up at the first position and Down at the last. Miscellaneous has no
  rank or move/participation controls in this view.
- Renaming preserves identity and position. Deleting a group removes its
  participation and its entries from AutoCategory's active lists; built-in
  name/pattern Reset preserves participation and position, matching the
  existing separation between Reset and display preferences.

## Overlapping groups and classification

For the requested inventory context, examine participating ordinary groups in
ascending effective rank: rank 1 is most important. The first group whose
compiled matcher returns true is the single Inventory Companion winner.
Return no managed winner when none matches.

Example: both Maps and Cyrodiil match a Cyrodiil map. Backpack ranks Maps first,
so it wins there. Bank ranks Cyrodiil first, so it wins in both standard and
subscriber bank. Moving Cyrodiil above Maps in Backpack changes only the
Backpack winner. Turning the winning group's participation off permits the
next matching participating group to win without losing the disabled group's
position.

Every managed predicate must agree with that winner; a lower-ranked matching
group must return false even if AutoCategory happens to evaluate its expression
first. Do not rely on Lua table iteration, tracker position, alphabetical
display names, or AutoCategory's category display priority to choose the group.

This guarantees a winner **among our participating groups**, not precedence
over every external category. The managed-group subsequence and ranks derive
from the same combined order used for actual classification. With native
insertion, AutoCategory still chooses the first true category in its own
bag-rule order; an external category placed earlier can win first.

Example: Maps / External Quest Items / Cyrodiil means Maps wins when it matches;
otherwise External Quest Items gets its turn before Cyrodiil. Moving the external
category above Maps lets its existing expression win before either group.
Moving it below both gives our groups precedence. A combined list that changes
only our private ranks but not actual external-rule evaluation is unacceptable.

## Saved-data compatibility

Decided 2026-10-31 after the spike: **AutoCategory's active bag-rule list is the
order record.** Each context's assignments live in AutoCategory's saved profile
(`saved.bags[context].rules`, ordered by run priority). That profile is account-
or character-wide according to AutoCategory's own setting. Inventory Companion
stores no copy of the order and no rank field. This supersedes the earlier
"one shared account-wide order regardless of AutoCategory's profile" decision:
ordering now follows AutoCategory's profile, and reordering in AutoCategory's
own settings window is equally valid. Our editor is a friendlier view of it.

- **Definitions** are registered every session through AutoCategory's plugin
  API (`RegisterPlugin` predefined rules plus `AddRuleFunc`) and are never
  written to `AutoCatRules`. Expressions reference stable internal rule keys,
  so renames do not orphan them.
- **Assignments** are persisted by AutoCategory. Verified offline with its real
  modules: entries whose definitions are absent (IC disabled or uninstalled) are
  skipped without errors and shown as red `(!)` rows in AutoCategory's settings,
  which the user can delete. While IC is loaded with integration off, our
  definitions stay registered with a false predicate, so no `(!)` rows appear.
- **Writes to AutoCategory data** are limited to inserting/removing our own
  entries and changing run priority on explicit moves or new insertions, in
  the active profile only. Never change external expressions, show priority,
  hide state, or inactive profiles.
- **Participation** (per group) and integration enablement live in Inventory
  Companion's existing active account/character tracked list, independently of
  Show/Notify and hidden-group settings. An alt may skip groups without
  affecting another character's view of a shared AutoCategory profile:
  predicates check the current character's participation.

- Missing optional settings use the documented defaults above. Explicit false
  is meaningful. Validate malformed recognized values at loading/import, with
  an actionable error and without partial publication. Treat AutoCategory's
  bag lists as external input: validate the structure before reading or moving.
- Profile selection/copy preserves independent participation and enablement.
  Changing Bank order cannot change Backpack order.
- Protect new data against older builds that cannot preserve it. Plan a schema
  increment from the current version 3 if participation fields need it,
  validate every profile, and finish migration before ZOS saved-variable
  constructors run. Recheck the current schema at implementation time.
- Preserve unrelated saved fields and legacy migrations. DEV and release share
  saved variables; prove downgrade rejection before testing on normal data.
- Never clone `ZO_SavedVars` interfaces by copying the proxy: they forward
  writes to live data (found by the spike).

## Technical decisions still gated

Combined ordering, read-only external filters, initial managed-first placement,
native insertion (proven in game), AutoCategory's list as the order record,
scoped participation, hidden inactive UI, and the defaults above are confirmed.
The following are technical investigations, not invitations to silently narrow
scope:

1. **Registration/lifecycle:** prove plugin registration timing with
   AutoCategory as an optional dependency, and that our persisted assignments
   survive reload and classify in Backpack and Bank. (Missing definitions are
   proven harmless offline.)
2. **Profiles:** AutoCategory account/character switch shows and classifies
   with the active profile's order; first activation in a profile without our
   entries inserts them managed-first without touching the other profile.
3. **Names/ownership:** stable identity must survive group renames. Establish
   collision handling with an existing user category of the same name, and
   reconciliation when a user removes our entries in AutoCategory's own UI.
4. **Platforms:** keyboard is verified; gamepad remains out of scope unless
   verified.

## Acceptance criteria

1. Absent/disabled integration preserves current behavior and editor name width.
   All integration editor UI is hidden, with no inactive preview. Saved choices
   remain intact. Missing optional dependency is normal; incompatible enabled
   integration reports an explicit useful status.
2. The top view toggle and Backpack/Bank selector display the correct independent
   combined lists, with source labels and read-only external details. Merely
   switching views/inventory produces zero saved writes/adapter refreshes.
3. Up/down changes and persists only the selected context's order in
   AutoCategory's active profile, maintains selection/scroll visibility, and
   handles endpoints and active search as documented. Reordering in
   AutoCategory's own settings is reflected in our view.
4. A two-group overlap chooses the top participating matching group, even when
   managed predicates execute in the opposite order. Different bag/bank ranks
   produce the documented different winners; subscriber bank uses Bank.
5. Disabling a participant falls through to the next match. Exclusions,
   no-includes, and empty patterns match identically to the existing matcher.
6. Show, grouping, Notify, hidden tracker state, and tracker expansion do not
   change classification. Classification does not change pickup delivery or
   AutoCategory collapse.
7. Rename, pattern edit, delete, participation/rank change, Reset, profile copy,
   and tracked-list switch synchronize without reload, except for an explicitly
   verified/documented external limitation.
8. Initial setup puts our groups above existing categories while preserving
   external relative order. Moving an external rule above, between, or below
   matching groups changes the actual winner in that inventory only. Later
   synchronization/reload retains the user's interleaving. External expressions,
   display priorities, hide state, and unrelated data remain intact.
   Enable/synchronize/disable/reload cycles create no duplicates or stranded
   expressions. Name collisions/manual edits have explicit safe outcomes.
9. Participation flags survive reload/copy without aliasing. Malformed values
   in any profile prevent partial migration/import; older builds reject the
   new schema without modifying data. Characters sharing an AutoCategory
   profile see the same order while independently skipping groups. Disabling
   integration or the addon leaves AutoCategory working without errors.
10. Per-item matching performs zero `GetMasterItemList` calls or bag enumeration,
    and does not compile patterns, rebuild projections, or refresh inventories.
    Synthetic workload/count limits and measured in-game timing gates pass.
11. External API/data incompatibility is surfaced; failures of maintained
    functions/state remain fail-fast rather than becoming false/unmatched.
    A move validates external structures, updates the verified order path, and
    refreshes the cache. Do not add speculative transaction/rollback machinery;
    investigate recovery only if the actual API path demonstrates a need.

## Verification and release safety

The implementation plan attaches focused tests to each stage. Offline fixtures
must count matcher calls, scans, compilation, writes, registrations, removals,
and refreshes; timing alone is insufficient. Never mutate live inventory or
either addon's real saved variables in synthetic checks.

The minimum native-insertion probe is now prepared before integration
scaffolding: a standalone actual-module suite passed 15/15 against AutoCategory
4.5.2, and the DEV-only `/icacspike` command is ready for the user's Plunder
Skull (existing Container category versus our Witches matcher). See the
[probe instructions and evidence](todo_implementation_autocategoryIntegration.md#minimum-viable-native-insertion-probe).
It restores isolated state immediately and checks returned classification,
not visible inventory rendering. The user's in-game report confirmed all three
mixed-order winners and a full cache rebuild for `Dremora Plunder Skull, Public
& Sweeper`, baseline `Container`, using the matching `Test group` rule rather
than Witches. Visible rendering and remaining lifecycle verification are pending.
The next prepared test is `/icacspike render`: a bounded 20-second Backpack
preview, also invoked by the DEV Debug Key at the user's request. It provides
original rule state restored immediately, actual header/item list
checks, and a scheduled normal redraw. Visual acceptance remains pending; see
the implementation plan for instructions and interaction limits.
The first preview placed all inventory under the spike header, which is correct:
`Test group` is the user's deliberate `*` "match too much" fixture. A second,
exact-link-scoped preview showed one skull under Spike B with other categories
intact, confirming visible placement. The probe now uses its own temporary
`*plunder skull*` group in isolated state, rather than user groups. It checks
that exactly the matching items render under Spike B. The all-skulls visual
rerun is pending. Its first in-game run leaked the temporary group into the
real IC list, because `ZO_SavedVars` interfaces are write-through proxies.
Isolation is fixed and covered by proxy-shaped tests, and the probe repairs the
leak once; details are in the implementation plan. The fixed build then passed
in game: the repair removed the leaked account group, and all 7 matching skulls
rendered under Spike B while 11 other items kept their categories. Keyboard
Backpack rendering through native insertion is proven, and the user confirmed
the visual check, including the return to normal categories after the preview.

In game, verify actual Backpack/Bank rendering, subscriber-bank context,
opposite overlap rankings, participation fallthrough, an external category,
external rows moved above/between/below our groups, unchanged external filters,
an unmatched item, quoted/non-ASCII labels, external edits, both addons'
profiles, reload, and disabled/missing-addon paths. Measure a representative
full sort and group-edit burst against integration-off baseline and record
explicit workload/timing limits before declaring performance acceptance.

Use a separate branch for substantial runtime implementation only with the
author's approval. Documentation refinement does not start that implementation.
Update user documentation and the authoritative working changelog from actual
implemented behavior; assess cumulative unpublished changes before recommending
a version. Do not mix unrelated packaging work into this feature.
