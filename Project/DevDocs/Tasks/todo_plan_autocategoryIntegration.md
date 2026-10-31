# AutoCategory integration

Status: Planned; no integration code or settings are implemented. Updated on
2026-10-31 to record the confirmed combined-list scope, shared ordering,
character participation, inactive UI behavior, and accepted defaults.

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
- Rank and projected AutoCategory evaluation order must agree with this list.
  Initially place our groups at the top, retaining existing external relative
  order. Later synchronization must not move them back to the top after a user
  has interleaved categories.
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
- All ordinary groups have an effective position, including nonparticipants.
  Up/down moves adjacent rows in the complete combined selected-context list.
- Existing explicit ranks sort first. Groups without a rank follow in stable
  internal-rule-key order, independent of mutable display names. New groups
  append to the managed-group subsequence, not ahead of previously ranked
  groups. The technical spike must define their precise insertion anchor in
  an already interleaved list without resetting existing external order.
- The normal view retains its current ordering. Search may narrow either view,
  but disable move buttons while search hides groups, with a tooltip explaining
  why; do not silently move across invisible rows.
- Disable Up at the first position and Down at the last. Miscellaneous has no
  rank or move/participation controls in this view.
- Renaming preserves identity and rank. Deleting a group removes its settings;
  built-in name/pattern Reset preserves participation and rank, matching the
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

Store one shared account-wide combined order for Backpack and another for Bank.
Use stable source-qualified identities, not display names, and derive managed
ranks from those lists. Do not save a competing rank list in each character's
tracked-rule profile. Group ranks alone cannot retain external interleaving or
positions for nonparticipants.

Per-group participation follows the existing active account/character tracked
list, independently of Show/Notify and hidden-group settings. An alt may skip
groups it does not need without changing shared order. Integration enablement
can follow the existing tracked-list scope; ordering cannot. There is no
requirement for independent per-character ordering or profile-pair order lists.
AutoCategory's own assignment profiles remain an external compatibility boundary:
the spike must establish how shared ordering references are applied to the active
external assignments without changing inactive external profiles.

- Missing optional settings use the documented defaults above. Explicit false
  is meaningful. Validate malformed recognized values at loading/import, with
  an actionable error and without partial publication.
- Profile selection/copy preserves independent participation and enablement,
  not a character-specific order. Copying tracked rules must not overwrite
  shared ordering. Changing Bank order cannot change Backpack order; skipping
  a group retains its shared position.
- Protect new data against older builds that cannot preserve it. Plan a schema
  increment from the current version 3, validate every profile, and finish
  migration before ZOS saved-variable constructors run. Recheck the current
  schema at implementation time rather than hardcoding a stale version.
- Preserve unrelated saved fields and legacy migrations. DEV and release share
  saved variables; prove downgrade rejection before testing on normal data.

## Technical decisions still gated

Combined ordering if feasible, read-only external filters, initial managed-first
placement, shared ordering with scoped participation, hidden inactive UI, and
the defaults above are confirmed. The
following are technical investigations, not invitations to silently narrow scope:

1. **Registration/storage:** verify the installed version, load order, rule
   definition/assignment add/remove paths, and cache rebuilds. Prefer reversible
   runtime-only projection if it works. Persisted expressions require safe
   disable, reload, and missing-addon/uninstall behavior.
2. **Insertion versus classification ownership:** determine whether our rules
   can be inserted into AutoCategory's native assignments and reordered with
   existing rules. This is the preferred strategy. If not, investigate whether
   we must take responsibility for its complete classification dispatch while
   AutoCategory keeps rendering. Compare lifecycle, external-expression
   evaluation, full return contracts, and compatibility risk before choosing.
3. **Combined ordering/storage:** prove that arrows affect actual mixed
   classification, not just displayed order. Establish authoritative storage,
   run-priority normalization, stable external identities, missing/renamed/new
   category reconciliation, new-group insertion anchors, and reversible profile
   switching. Keep external filters/display priority/hide state unchanged.
   Independent per-character ordering is not required.
4. **Names/ownership:** stable identity must survive group renames. Establish
   collision and manual external-edit reconciliation without overwriting a
   user's category merely because its name matches.
5. **AutoCategory profiles/platforms:** establish its account/character profile
   switch/reset lifecycle and keyboard/gamepad support. Preserve inactive
   profiles and state the verified support limits.

If native insertion is infeasible, present the classification-ownership option
with evidence and tradeoffs for approval before implementation. Do not silently
install a replacement `MatchCategoryRules` hook or ship a managed-only list as
though it fulfills the combined requirement. If neither strategy is safe,
report the limitation and agree a scope change.

## Acceptance criteria

1. Absent/disabled integration preserves current behavior and editor name width.
   All integration editor UI is hidden, with no inactive preview. Saved choices
   remain intact. Missing optional dependency is normal; incompatible enabled
   integration reports an explicit useful status.
2. The top view toggle and Backpack/Bank selector display the correct independent
   combined lists, with source labels and read-only external details. Merely
   switching views/inventory produces zero saved writes/adapter refreshes.
3. Up/down changes and persists only the selected context's ordering, maintains
   selection/scroll visibility, and handles endpoints and active search as
   documented.
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
9. Saved ranks and flags survive reload/copy without aliasing. Malformed values
   in any profile prevent partial migration/import; older builds reject the
   new schema without modifying data. Characters use the same account-wide
   Backpack/Bank orders while independently skipping nonparticipating groups.
   Tracked-list selection/copy does not replace shared order.
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
