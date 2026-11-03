# AutoCategory ordering fix: implementation plan

**ARCHIVED 2026-11-03.** Historical redesign; current requirements are in
the [master feature document](../../AutoCategoryIntegration.md).

Updated 2026-11-01. **Implementation is present; in-game acceptance remains pending.**

This is the current ordering-fix plan, incorporating the subsequent saved-data
discussion. It supersedes the proposed ordering replacement section in the
[original implementation plan](todo_implementation_autocategoryIntegration.md),
not the integration's unrelated requirements or release gates.
Read the [spec](todo_plan_autocategoryIntegration.md),
[dependency evidence](AutoCategorySpikeResults.md) and
[implementation report](AutoCategoryImplementationReport.md) for the current
contract and evidence limits. The spec, report, user manual and working
changelog now reflect this ordering design. The regression runner passes
117/117 isolated addon tests, including synthetic schema-4 downgrade
protection. Normal saved variables and live inventory were not used. ESO
acceptance, compatibility certification and release readiness remain pending.
The owner-only `/iccleanautocategory` command runs only for ESO account
`@Tim-P`; it clears that account's integration data and explicitly IC-owned
AutoCategory assignments while preserving unrelated settings, then asks for
`/reloadui`. Its account-isolation and cleanup behavior is covered by synthetic
tests.

AutoCategory errors now warn and disable integration for the session, without
preventing core addon startup or operation. Invalid integration-only saved data
is preserved, excluded from runtime use, and not normalized. Core profiles still
upgrade to schema 5 before ZOS constructors, preserving downgrade protection.
This supersedes the earlier requirement to abort all startup on legacy AC
ordering. Newer unsupported schemas and unrelated core data errors still stop
loading; they are not integration-only failures.

## Problem and required outcome

The editor currently sorts exact numeric display priorities. AC keyboard
inventory instead builds a sort key using
`string.format("%04d%s", 1000-showPriority, categoryName)`, losing fractional
distinctions. Matching priority is independently evaluated.

The observed Backpack case has New and Set matching at 100, Utility near 99.94
and Test group near 99.89. Set claims items before the catch-all Test group,
but its generated set-name headings can appear below Test group.

The fix must make the editor accurately explain and control both orders.
Display-only edits must not change matching; matching-only edits must not
change display. Do not equate an inventory heading's position with its
classification precedence.

## Agreed design direction

- Use independent lists for all seven contexts. There is no Master inheritance
  or per-context override layer. Each context owns its display and matching
  sequences; editing one never implicitly changes another.
- Provide a one-time **Copy from [context]** action for convenient setup.
  Copying does not establish an ongoing link between contexts.
- Store order as lists, not rank/anchor properties on groups. List position
  is the virtual rank; a calculator produces AC's numeric priorities.
- References are strings: `ic:<group slug>` and `ac:<category name>`.
- IC references use stable rule keys, not display names. Renaming a group
  does not alter its list identity.
- Store AC names directly in the lists. Do not add a separate heading-ID
  registry; it would not solve AC's name-based rename identity.
- AC definitions, filters and assignment membership remain in AC. IC may
  rewrite native assignments' run/show priorities, not their unrelated fields.
- Remove rank-bearing colour prefixes and fractional priority allocation.
- Disabling IC's AC integration removes IC-owned bag assignments and leaves
  native AC priorities/order unchanged. Rebuild affected AC caches and refresh
  inventory immediately: IC headings disappear and their items are classified
  by the remaining native rules, without requiring `/reloadui`. Verify this
  in game; this is integration disable, not unloading the addon itself.
- The integration is unreleased and its legacy setup exists only in the
  author's game. Do not implement rank/prefix migration. The agreed transition
  is to restore the most recent suitable saved-variable backup and let the
  author rebuild integration configuration. This does not authorize silent
  resets, loss of unrelated data or unsafe downgrades.

## Saved-variable shape

Within each IC account-wide or character profile:

```lua
autoCategoryOrder = {
    contexts = {
        backpack = {
            display = {
                "ac:New",
                "ic:utility",
                "ic:custom_7693902",
                "ac:Set",
            },
            matching = {
                "ac:New",
                "ic:utility",
                "ic:custom_7693902",
                "ac:Set",
            },
        },
        bank = {
            display = {
                "ac:New",
                "ac:Set",
                "ic:utility",
                "ic:custom_7693902",
            },
            matching = {
                "ac:New",
                "ac:Set",
                "ic:utility",
                "ic:custom_7693902",
            },
        },
    },
}
```

This example abbreviates the category and context sets; it is not a complete
live profile. Each context stores two complete sequences of its participating
IC groups and native assignments. Initialize missing optional context data at
the loading/import boundary under an explicit rule, never by inheriting another
context. No rank numbers, Master sequence or override metadata are required.

Groups continue owning names, patterns and participation. Ordering no longer
depends on per-group anchors/ranks. Native AC assignments are first-class
ordering rows, not optional anchors: always include them in the context's
unfiltered editor list in both modes. Remove editor-only heading visibility
preferences and hide/show-all controls as part of the obsolete ordering setup.
Normal text search may still filter rows without changing the underlying order.
This does not change AC's own inventory-hidden flags or classification behavior.

Numeric priorities are stored in AC's assignments, not duplicated as IC's
authoritative ordering data. A runtime last-projection snapshot supports
external-edit detection; define startup import separately rather than assuming
that runtime snapshot survives reload.

Parse only the leading `ic:` or `ac:` namespace; preserve the full remaining
slug/name verbatim, including colons and ESO markup. Validate dense lists,
supported namespaces, duplicate references and reference validity at the
saved-data boundary. Native assignment names are profile/context dependent.
AC renames/deletions require reconciliation; do not infer a rename from
similar names. Duplicate native assignments with the same name cannot be
represented by this model: detect and report them before writing rather than
silently merge or invent occurrence IDs.

## Legacy setup and first live test

- No legacy integration migration is required. Before the first live test,
  identify the most recent suitable saved-variable backup and confirm its
  contents and exact restore scope with the author. AC and IC have separate
  saved files; do not assume restoring IC also cleans AC's old owned entries.
- Preserve the current files before any restore. Restore only explicitly
  agreed files while ESO is fully exited so it cannot overwrite the restored
  data on logout. The author will rebuild the new integration setup.
- This plan records permission for that transition strategy, not an instruction
  to restore files during documentation work. Saved-schema validation and
  downgrade protection remain required before using normal shared game data.

## Implementation sequence

### 1. Lock contracts and saved-data safety

- Update the spec/report to the agreed decisions. Continue on the existing
  `feature/autocategory-integration` branch; no additional branch is needed.
  Preserve existing dirty work and do not switch branches without approval.
- Bump the IC saved-variable schema for this incompatible representation.
  Validate every profile non-destructively before ZOS constructors.
- Test older supported DEV/release builds, including schema-4 sources, reject
  new saves without mutation before any normal shared saved-data testing.
- Define category-add/remove/rename, participation, absent dependency and
  IC/AC profile-switch behavior, preserving unrelated profile data.

### 2. Implement list resolution and external read-back

- Resolve each independent context sequence into a complete assignment permutation.
  Include hidden native assignments because they still affect matching.
- Observe native AC renames while IC is loaded. Installed AC's settings call
  `AutoCategory.renameRule(oldName, newName)`, which resolves the usable name
  and calls `AutoCategory.renameBagRule(oldName, newName)` to update the seven
  bags. Hook the successful assignment rename, using its actual resolved name,
  and replace affected `ac:<oldName>` references in place in both sequences.
  Preserve positions and scope changes to the corresponding AC profile/bags;
  do not rewrite unrelated IC profiles. Distinguish normal user renames from
  startup duplicate-name handling and our own definition/projection work.
- For unobserved external changes, do not infer rename identity: remove native
  references whose assignments no longer exist in that AC context, and add
  newly discovered assignments. An AC definition absent from a bag is not an
  assignment to import; an unloaded dependency is not evidence of deletion.
  Report reconciliation changes rather than silently conceal malformed data.
- Recover placement from AC's actual assignments, which already hold both
  native and IC-owned run/show numbers. Read each complete bag order and map
  owned assignments back to `ic:<slug>` and native ones to `ac:<name>`.
  Reconcile display and priority independently, placing new native categories
  relative to both IC and native rows according to those observed orders,
  not arbitrarily appending them or attempting to reconstruct a missed rename.
  Use the actual display sort-key behavior and report ambiguous tied/dynamic
  heading cases as described below.
- Recognize IC-owned identity independently of native name matching. A rename
  of an owned category must not convert it into an `ac:` row or break the
  mapping to its stable group slug; test this separately.
- Read AC on editor open, cache/profile changes and immediately before every
  write. Import run/show independently; never silently equate them.
- Track snapshots by both IC and AC profile identity and bag. Distinguish our
  own projection from external edits; never import outgoing profile output
  into the incoming profile's defaults.
- Before applying a pending IC move, reconcile external edits and apply the
  specific move to the fresh list. Report disappeared/conflicting targets;
  never replay a stale whole-list order over newer AC edits.
- Import existing display order using AC's actual sort keys, not simply raw
  numeric priority. Surface ambiguity where old ties and dynamic heading
  expansion cannot be faithfully represented as ordered parent blocks.

### 3. Replace the priority calculator and projection

- Apply ordering changes immediately after each move; do not defer them until
  the editor closes or require an Apply action. Re-read/reconcile AC first,
  calculate the proposed saved order and native priorities, preflight them,
  then persist and project the validated change. Failed preflight must not
  leave a saved move presented as successfully applied.
- A Display move changes only show priorities; a Priority move changes only
  run priorities. A move updates only the selected context. Copy actions and
  participation changes recalculate only the affected sequences/contexts;
  no inheritance or reset-to-Master behavior remains.
- Opening the editor reads/reconciles; closing it performs no deferred writes.
  Write only changed priorities, then rebuild affected caches and refresh
  inventory so each successful move has immediate feedback.
- Installed AC run/show sliders support integers **2..1000**, inclusive:
  **999 distinct assignment priorities per bag per sequence**.
- For each resolved sequence of N assignments, assign `1001 - index`:
  first = 1000, last = `1001 - N`. Empty bags are valid; N > 999 fails visibly.
  No fractions, even/odd reservations, prefixes or alphabetical tie insertion.
- Preflight all seven bags, definitions, collisions and capacity before any
  persistent writes. Invalid external input produces an actionable error,
  not clamping, omitted rows or partial planned writes.
- Update only native run/show fields and required owned assignments.
  Preserve native definitions, names, filters, membership and hidden flags.
- Use stable managed names independent of order; moving a category must not
  rename it or reset its collapse state.
- Rebuild caches/refresh changed contexts once, suppress feedback loops and
  invalidate stale deferred work when generation or profile changes.

### 4. Update the dedicated AutoCategory editor

**Mode design discussed 2026-11-01:**

- Provide two clear modes the user can flip between: **Display order**
  ("Where groups appear in inventory") and **Priority order**
  ("First matching group wins"). Priority is the user-facing name for the
  matching sequence; it is not the display priority.
- Change group-row colours between modes to make the editing purpose obvious.
  Keep a persistent mode label and explanatory text as well: colour must not
  be the only indication. Exact colours remain to be chosen.
- In Priority order, provide a **Use display list** button. It copies the
  current context's display sequence into its priority sequence and applies
  immediately using the same read-back/preflight/projection path as a move.
  This is a one-time copy, not a persistent link; subsequent edits to either
  sequence remain independent.
- Provide the reciprocal **Use priority list** button in Display order. It
  copies the current context's priority sequence into its display sequence,
  applying immediately without changing the source priority sequence.
- Explain the concrete Set/Test-group case: Set may have higher matching
  priority while its generated headings appear lower in display order.
- Provide exactly two copy actions:
  1. **Copy both orders from [context dropdown] [Go]** copies both display and
     priority sequences from the source into the currently selected context,
     regardless of active mode. This is the "use the same setup in this bag"
     action. Do not offer a separate cross-context single-mode copy.
     Selecting a source alone does not write anything.
  2. **Use priority list** in Display mode, or **Use display list** in Priority
     mode, copies the current context's other-mode sequence into the active
     mode. It leaves the source sequence unchanged.
- Example: Bank in Display mode offers **Copy both orders from [Backpack] [Go]**
  and **Use priority list** (from Bank itself). Switching to Priority mode
  keeps the first action unchanged and changes the second to **Use display list**.
- Every copy is a one-time operation, never inheritance. Preflight and apply
  immediately. Cross-context copy changes order only: never create native AC
  definitions or bag assignments, or change IC group participation, to match
  the source. Skip source references absent from the destination. Keep
  destination-only references in their existing list slots and fill the
  remaining slots with shared references in source order, independently for
  each sequence. This preserves destination membership exactly.
  Disable cross-context actions when source equals
  destination rather than presenting a successful no-op.

- Add clearly labelled Display order and Priority order modes, move controls
  for both native and IC rows, a context selector and the agreed copy
  action. Show full context order; search must not redefine move semantics.
- Remove per-heading editor hide controls and Show all headings. All native AC
  assignments must remain available as individual ordering rows in both modes,
  including assignments AC marks inventory-hidden; preserve those native flags.
- Explain first-match-wins and catch-all shadowing in Matching order.
- Show Set as the `autoset()` parent assignment. Its generated set-name
  headings are not saved as separate list references; they share the parent's
  priority and remain sibling headings within that block.
- Distinct priorities solve ordering between assignment blocks, not arbitrary
  plugin-generated names or every third-party classification behavior.
- Keep pattern editing on Groups. Defer shared-window refactoring, unrelated
  layout fixes and AC inventory-hiding features.

### 5. Automated verification

- Reproduce the exact New/Set/Utility/Test-group fractional failure with actual
  installed AC classification and native display-key code.
- Assert editor order agrees with native rendered sort keys, not just numbers.
- Set before catch-all claims set items; Set after catch-all claims none of the
  remaining named items. Cover New precedence, overlapping IC rules and set
  expansion. Display-only moves preserve matching and vice versa.
- Test 0, 1, 999 and 1000 assignments; exact permutations, integer bounds,
  unrelated-field preservation and no writes on preflight failure.
- Cover independent context edits, one-time copying, new/deleted references, group
  renames, AC rename/delete reconciliation, duplicate names and malformed saves.
- Test external edits just before a deferred write, stale moves, own-hook
  suppression, reload, profile isolation, enable/disable and round-trip
  read/project/read idempotence.
- Synthetic tests must never mutate live inventory or normal saved variables.

### 6. In-game acceptance and documentation

- First demonstrate the author's Backpack case: inspect both orders, move Set
  before/after Test group in Matching order, and separately move its display
  block. Obtain confirmation that the UI explains the actual inventory.
- Verify all seven keyboard contexts, Bank/subscriber Bank, the previously
  deferred Guild Bank, collapse/reorder/reload, AC-panel edits and both profile
  directions. Do not label untested contexts or gamepad supported.
- Agree workload/timing limits, then run safe synthetic burst checks.
- Update user documentation, implementation report and working changelog from
  actual results. Retain existing downgrade, release and spike-teardown gates.

## Completion criteria

The fix is complete only when both editor modes match native behavior, integer
projection preserves the selected orders, AC edits survive read-back, profile
and saved-data tests pass, and the relevant in-game acceptance is recorded.
Planning and offline passes alone are not compatibility certification.
