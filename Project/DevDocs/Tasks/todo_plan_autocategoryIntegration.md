# AutoCategory integration: SPEC

Updated 2026-10-31. **Planned, not implemented or compatibility-certified.**
This document defines required behavior, accepted author decisions, and open
decisions. It is not a test log or a claim that all requirements are feasible.

Read the [implementation plan](todo_implementation_autocategoryIntegration.md)
for sequencing and the [spike results](AutoCategorySpikeResults.md) for dated
evidence, failed approaches, dependency contracts and current gate status.
See the [review](AutoCategoryIntegrationReview.md) for the spec/plan assessment
and concrete recommendations.
The [Show/Notify prerequisite](../Completed/ItemTrackerFlags.md) is complete.

**Handoff status, 2026-10-31 23:08 UTC:** all seven follow-up test steps are
finished, including exact-tag cleanup. Empty colour-rank prefixes passed sampled
ESO top/crowded order, visual appearance, rank reversal/cache rebuild and account
reload persistence. Offline scale/boundary/lifecycle suite passes 31/31.
These are supported sampled mechanisms, not an unlimited placement guarantee.
Q1/Q2 now concern a supported placement contract and demonstrated bounds;
D4 prefix-name adoption is an author decision. Reordering changes names and
restarts collapse state while old flags remain. Guild Bank stays deferred;
alignment/collapse interaction and general external run/show mismatches are not
certified. Automatic IC integration hooks remain unbuilt. See SPIKE RESULTS for
commands, dated outcomes, failed alternatives and exact evidence limits.
No further standalone pre-implementation spike work is planned. The remaining
assumptions and deferred context coverage are post-implementation acceptance
requirements before integration activation or release; see the implementation
plan.

## Goal and scope

Configure ordinary Inventory Companion (IC) groups once and optionally use
their existing filters as native AutoCategory inventory partitions.
AutoCategory continues classifying, drawing and sorting its own sections.

- Integration is opt-in, disabled by default; participation defaults off.
- Support seven contexts using one shared master order with sparse per-context
  placement overrides: Backpack, Bank, Guild Bank, House Bank, Crafting Station,
  Craft Bag, Furniture Vault. Standard and subscriber bank share Bank. Keyboard
  is the initial platform; gamepad is outside scope unless separately verified.
- Use the active account-wide or character-specific IC tracked-list profile.
  Do not add an independent integration profile selection.
- One managed category per participating ordinary group. Individually tracked
  items and Miscellaneous are not exported; Miscellaneous is tracker
  presentation, not ordinary pattern membership.
- Reuse compiled case-insensitive name/wildcard matching, include-any /
  exclude-none, and existing no-includes/empty-pattern semantics.
- No item transfers, item mutation, full scans, compilation or settings writes
  during classification.
- AutoCategory's installed source and unowned entries are read-only: never
  change their names, definitions, filters, assignments, run/show priorities,
  hide state or relative order. Preserve unrelated saved data and settings.
- No integration/UI implementation is authorized by the documentation/spike
  task itself. Substantial implementation requires the normal project approval
  and branch discussion.

## User experience

### Enablement and participation

- Main settings provide integration enablement and explicit compatibility
  status. This is the entry point, not an inactive editor preview.
- Add the full **AutoCategory** label last on ordinary group rows in the item
  tracker editor, after Show and Notify, as an independent participation toggle.
  Individual items and Miscellaneous have no participation control.
- Participation is independent of Show backpack/bank, grouping, Notify
  Chat/HUD, hidden-HUD-group state, expansion and tracker height decisions.
  A group hidden in IC can still classify into AutoCategory.
- Notify remains pickup delivery: no changes to destination union, positive-gain
  detection, hidden-group notification policy or duplicate/burst handling.
  Classification sends no notifications. AutoCategory collapse remains
  independent of IC expansion.
- Off, missing or incompatible integration hides all integration editor UI:
  view toggle, context dropdown, order list/arrows, heading hide controls and
  participation. Return an open AutoCategory view to normal; preserve choices.
  Category-column width is zero, returning space to names. While active reserve
  consistent width across all row types, including nonparticipants and items.
- Do not expose working-looking controls or save placeholder settings before
  matching and projection work.

### AutoCategory view in the group editor

- A top **AutoCategory** view toggle switches between the existing normal group
  view and the AutoCategory view; it does not toggle integration/participation.
- A dropdown selects the shared **General** order or one of the seven contexts.
  General edits the master order; a context displays the master order with its
  own placement overrides applied. The normal view keeps its current ordering.
- Show most important first: ordinary groups interleaved with user-selected
  visible AutoCategory heading rows present in that context's active list.
  Heading rows follow AutoCategory's classification order, have a distinct
  label/badge and no order arrows. Their order is changed only in AutoCategory
  settings; explain that briefly in the view.
- Each external heading row has the normal hide/unhide control. Hiding a heading
  hides it from the ordinary AutoCategory editor view and removes it as an
  ordering reference; it does not change AutoCategory's own hidden setting.
- Provide a **Show all AutoCategory groups** checkbox. When checked, hidden
  heading rows are included so the user can unhide them. When unchecked, hidden
  headings are omitted to make the effective ordering easier to work with.
  This checkbox only filters editor rows; it does not change saved hidden state,
  AutoCategory settings, or projection.
- A managed group ordered after a visible AutoCategory heading is placed
  immediately below that heading. Consecutive managed groups in that slot form
  a contiguous block in saved order before the next external heading. A hidden
  heading cannot anchor groups: resolve its groups to the nearest preceding
  visible heading, or the top slot if none exists. Do not rewrite saved order
  just because a heading is hidden; the next explicit move may persist the
  resolved placement.
- Up/down arrows move one group past its neighbouring group or visible heading.
  In General, moves change the master order. In a context, moves save only that
  group's placement difference from the master, not a copy of the entire list.
  Crossing a visible heading changes its slot. Up means more important, Down
  less important.
- Match the currency panel's native ordering rows in ESO's main settings:
  up/down buttons, hover tooltips, click sound, immediate save/reorder and
  moved-row highlight. Also preserve selection and scroll visibility.
- Participation is separate from position. Off retains position but contributes
  no assignment and cannot win. Never-ordered groups appear after ordered rows
  without arrows until first participation appends them to the top slot.
- Disable Up/Down at endpoints. While search hides groups, disable all moves
  with an explanation; do not move across invisible rows.
- View/context selection alone does not save, normalize order, reorder the
  tracker, project or refresh inventory.
- Selecting an external heading displays read-only name/filter text and its
  hide/unhide control; it cannot invoke IC name/pattern editing, Reset, Delete
  or participation handlers.
- Do not add drag/drop, tracker-order editing or another filter editor.

### Shared order and context overrides

**Accepted direction, detailed semantics still to be refined:** configure one
master order and store only placement differences for each context, following
the existing group-override principle rather than maintaining seven independent
order lists.

- Groups without a context override continue to inherit master-order changes.
  A context-specific move overrides the moved group's placement; it does not
  freeze the rest of the context list.
- Placement refers to stable group identities and external heading identities,
  not numeric row indices. The exact override representation and resolution
  algorithm are not decided here.
- Contexts retain their actual native AutoCategory heading order and available
  headings. General must not imply that every context has the same headings.
  Missing or IC-hidden headings cannot act as references; resolve affected
  placements to a preceding usable heading or top, without rewriting saved
  placement merely because a heading is unavailable.

Required example:

```text
General: New / A / B / To sell / C / D
Bank:    New / A / To sell / B / C / D
```

The user moved only B immediately below To sell in Bank:

- Bank stores B's placement override, not a full Bank order.
- Swapping C and D in General also swaps them in Bank:
  `New / A / To sell / B / D / C`.
- Swapping A and B in General does not move B out of its overridden Bank
  placement. A remains inherited; B remains immediately below To sell.

**Still to refine with the author:** how General presents headings whose native
order differs by context; the precise preceding-heading fallback; how moves
within a slot are represented; interactions between overridden groups; deleted
anchors and cycle/conflict handling; redundant-override handling; and the UI
for identifying/resetting overrides. These are open design details, not
authorization to add more pre-implementation spike tests.

### AutoCategory heading visibility and defaults

- Every AutoCategory heading present in any of the active profile's seven lists
  is available as an editor reference row wherever it exists. By default,
  headings are shown unless the user has hidden them in IC. Hidden heading names
  are stored per active IC tracked-list profile; missing external headings do
  not cause AutoCategory data to be changed.
- Hiding a heading removes it from the effective reference sequence. Groups
  ordered after it resolve to the nearest preceding visible heading, or top.
  Unhiding it restores it as a reference without changing the saved group order.
- A missing heading is not displayed in a context where it does not exist.
  When renamed or deleted externally, preserve IC's hidden-name choice without
  rewriting group order; resolve affected groups to the nearest preceding
  visible heading or top.
- First participation appends a never-ordered group to the master top slot,
  above all external categories, inherited by contexts without an override.
  Turning it off/on retains its master placement and context overrides.
- Rename preserves stable identity/position. Delete removes participation,
  order and owned entries. Built-in name/pattern Reset retains participation
  and position.

## Classification and visible order

**Required outcome:** the editor order represents both which category wins
and where managed headings appear. Independent display ordering is not offered.
This requirement is retained despite the unresolved numeric mapping Q1/Q2.

- AutoCategory's first true category wins: descending run priority, ties by
  ascending name. Each managed predicate tests integration enablement,
  participation and the existing compiled group matcher.
- Projection must place our entries in that native order; do not introduce
  another winner calculation or depend on Lua iteration, tracker order or
  alphabetical managed labels.
- Below visible heading M, managed groups must immediately follow M in saved
  order and native classification/heading order, before the next external
  heading. Entries tied with M stay above our groups. Top is above the highest
  external run priority; a last slot with no lower bound extends downward.
- Groups in a slot retain their saved sequence. Whole-number priorities are
  preferred when there is room; fractions are allowed, not proof that every
  crowded slot can render in the intended order. If immediate adjacency cannot
  be achieved without changing external entries, report the incompatibility
  and seek D1; do not silently insert another external heading between the
  marker and its managed groups.
- Run and show priorities are implementation outputs, not saved IC order.
  **No universal `runpriority = showpriority` rule is approved.** That former
  assumption and above-1000 mirroring were superseded by ESO evidence.
  Prove a mapping satisfying both classification and headings before activation.
- Preserve external run/show differences and hide state. If an external list
  cannot support the requested outcome unchanged, report the limitation and
  seek D1; do not silently reorder, cap groups or fall back to alphabetical
  headings.

Examples:

- Maps and Cyrodiil both match a map. Maps first in Backpack wins there;
  Cyrodiil first in Bank wins in standard and subscriber bank. Turning the
  winner off falls through without losing position.
- `Plunder / New / Cyrodiil / Container`: a recently picked-up skull is Plunder;
  a new Cyrodiil map is New; an old one is Cyrodiil. Cyrodiil appears
  immediately below the visible New heading. If New is hidden, Cyrodiil resolves
  to the preceding visible AutoCategory heading, or top if none exists.
  Plunder is an IC group, not an external heading reference. Unmatched
  containers remain available to Container.

## Persistence, ownership and lifecycle

Accepted author design, 2026-10-31: **IC owns the master group order, sparse
per-context placement overrides, and external-heading visibility.** Visible external headings are ordering
references; IC hidden headings are not. This supersedes editing/storing
AutoCategory's combined list as the order record. New field/helper names belong
in the implementation plan, not assumed existing APIs.

- Enablement, hidden-heading choices, master order and sparse context overrides
  live alongside groups in each IC tracked-list profile; participation lives
  on the ordinary group. Do not persist seven complete derived context lists.
  Use stable rule keys; display names are not identity. Keep master positions
  and overrides for nonparticipants. Never persist compiled matchers or derived
  priorities.
- Missing optional fields inherit documented defaults; explicit false/empty
  selections are meaningful. Preserve choices while AC is absent/reset and
  through group edits made while off.
- Validate all profiles and imports at the boundary; malformed recognized data
  produces an actionable error without partial publication. Preserve unrelated
  data and legacy migrations. Validate external AC structures before mutation.
- Increment the saved schema when old builds cannot preserve these fields.
  Recheck current version (3 at planning); validate/migrate every profile before
  ZOS constructors. Prove older supported builds reject newer data unchanged
  before DEV or release uses normal game saves. They share saved variables.
- Never clone ZO_SavedVars write-through proxies; the spike found and repaired
  a live-data leak from preserving their metatable.
- Supply definitions every session through AC plugin predefines and a real
  predicate function, before evaluation; never write definitions to AutoCatRules.
  Expressions use escaped stable keys such as `ic_group("<key>")`.
- At plugin init, relevant IC edits/profile copy/switch, AC profile switch and
  disable, reconcile only owned assignments in the *active* AC profile's seven
  lists. Write only changed values; rebuild/refresh affected contexts.
  Never project into inactive AC profiles.
- Every inserted assignment carries `icOwned = true`; only that marker grants
  ownership, never a matching label. Remove stale owned entries after delete,
  rename, nonparticipation, or another character's groups. Do not store a
  growing registry of old category names.
- Preflight name conflicts before registration and projection against external
  definitions/assignments. Skip/report conflicts rather than permitting AC to
  rename/redirect a user's existing rule.
- With integration off but IC loaded, definitions remain available with a
  deliberately disabled predicate; remove owned active-profile assignments.
  Absent definitions after uninstall were harmless in offline fixtures
  (red `(!)` settings rows); document and verify the completed disable/uninstall
  behavior rather than treating that fixture as ESO certification.
- Shared AC account profile with character-specific IC groups reflects the
  logged-in character; login reprojects. Inactive owned residue is reconciled
  when that profile next becomes active.
- Manual moves of our entries in AC settings are overwritten at projection.
  AC's unpruned per-name collapse flags after rename remain untouched and are
  documented; renamed headings start expanded.

## Category decoration and icon

- Use one constant small inline texture prefix before the group name. A
  built-in plus texture passed the spike. Text fallback if a future asset/name
  constraint requires it: `<name> · Inventory Companion`. Do not fall back
  silently. Explain the decoration in the manual and editor.
- Chosen IC source artwork is the white wide-flap satchel with luggage tag,
  [CategoryIcon/v5](../../Art/CategoryIcon/v5/); v1-v4 are earlier references.
  Plain `CategoryIcon.svg` is the heading icon, tinted gold. A whole-group
  heading never shows include/exclude badges.
- Convert final asset to 64x64 DXT5 `.dds`, preserving alpha and white artwork
  for multiplicative tint. Conversion/alpha checks are not done by this spike.
  New textures require full game restart, not just `/reloadui`.
- Final path is part of the category name and must remain stable after release.
  DEV/release folder paths differ; resolve identity consequences with the
  author under D2 before publishing.
- Existing include/exclude design uses two stacked controls: cut-gap bag
  (`CategoryIconIncludeBag.svg` / `CategoryIconExcludeBag.svg`) and separate
  solid plus/bar badge (`CategoryIconIncludeBadge.svg` /
  `CategoryIconExcludeBadge.svg`). Not a single inline texture.
  Include blue/exclude red avoids red-green ambiguity; shape differs too.
  Placement/colours remain D3, not prerequisites for plain headings.

## Open questions and decisions

This register is authoritative for unresolved requirements/choices. The
[results](AutoCategorySpikeResults.md#current-gate-status) establish evidence;
the [plan](todo_implementation_autocategoryIntegration.md#implementation-sequence)
assigns work. **Do not mark an assumption verified merely because a candidate
can format or classify. Remaining verification follows implementation; it is
not a reason to reopen the spike before implementation starts.**

| ID | State / owner | Question or decision | Required closure |
| --- | --- | --- | --- |
| Q1 | POST-IMPLEMENTATION ACCEPTANCE | How can all top-slot managed headings appear above existing headings in saved order? | Verify the implemented adapter's classification and native heading order, bounds, and visible unsupported-state behavior before activation. Spike evidence is sampled; no additional pre-implementation probe. |
| Q2 | POST-IMPLEMENTATION ACCEPTANCE | How does managed order handle crowded keys and external run/show differences? | Verify implemented output, including heading order and known finite/mismatch limits, before activation. If the unchanged spec cannot be met, stop for D1; no silent alphabetical fallback. |
| Q3 | IMPLEMENTATION + ACCEPTANCE | Which lifecycle hooks and dynamic definition/cache/refresh paths reliably cover edits, AC profile changes, disable and pending work? | Implement the hooks, then verify active-only automatic behavior against the completed feature. Manual projection alone is not closure. |
| Q4 | POST-IMPLEMENTATION SAFETY GATE | Does migration preserve all profiles/imports and do older builds reject new schema without mutation? | Verify on synthetic proxy fixtures and with the real pre-feature build before loading new-schema data from normal game saves. |
| Q5 | POST-IMPLEMENTATION MEASUREMENT | What synthetic inventory/group/burst workload and numerical timing limits define performance acceptance? | Agree workload and limits when preparing post-implementation measurement; record call counts and off/on timings. No numerical limits are accepted yet. |
| D1 | CONDITIONAL author decision | If Q1/Q2 are impossible under unchanged native rendering, which explicitly revised design is acceptable? | Present failed approaches, supported alternatives and risks; obtain approval. No classification/render takeover or semantic change by assumption. |
| D2 | OPEN author decision | Final heading texture path / DEV-release identity policy and exact gold tint? | Decide before final asset registration/publication. No new converter/tool install assumed. |
| D3 | OPEN, separate UI scope | Where should include/exclude badges appear; which badge colours and optional colour settings? | Author choice: coloured bag/white badge, gold bag/coloured badge, or coloured bag/gold badge. Not blocking plain category headings. |
| D4 | OPEN author decision; sampled lifecycle tests finished | Adopt empty colour-rank prefixes in production category names? | ESO appearance/order/reorder/account reload and cleanup passed; 128-group scale passed offline. Approve rank-name changes and documented expanded-after-reorder/collapse residue; suggestion alone is not adoption. |

After Test 7/7 on 2026-10-31, the author explicitly chose to leave D4 open.
The demonstrated prefix mechanism is not yet approved production naming.

**Deferred coverage, not open design choices:** Guild Bank requires
post-implementation DEV acceptance; gamepad is outside initial certification.
Other crafting tabs/professions/universal deconstruction, merchant buy/buyback,
interactive collapse and non-Backpack reloads have no spike certification. The
feature must still pass its seven-context keyboard acceptance matrix after
implementation; never equate deferral with a pass.

## Acceptance criteria

1. Off/missing integration preserves IC behavior and name width; all integration
   editor UI hides without erasing choices. Enabled incompatible external
   contracts report explicit useful status, not success-shaped fallbacks.
2. General/context views show the master or resolved inherited order and
   available visible external headings; opening or switching produces zero
   writes/projections/refreshes.
3. Arrows update the master in General or sparse placement overrides in the
   selected context, preserving selection/highlight/visibility. Untouched groups
   inherit subsequent master changes; the B/C/D example above passes.
   Endpoints and search are correct.
4. Opposite overlap orders produce opposite winners; Bank and subscriber match.
   Immediate placement below visible headings and arbitrary managed labels
   produce matching native classification and heading order, including
   top/crowded/last slots.
5. Nonparticipants fall through; existing include/exclude/empty-pattern behavior
   is unchanged. Show/Notify/hidden/expansion never alter classification.
6. Rename, edit, delete, participation/order/heading visibility, Reset, copy
    and both profile modes update without reload, except an explicitly approved
    and documented external limitation.
7. External entries remain byte-for-byte unchanged; projection is idempotent
   across repeated reload/edit/enable/disable/profile cycles, removes stale owned
   entries and refuses collisions before AC rename/redirect.
8. Every required context renders natively in ESO, including subscriber Bank.
   Shared AC profiles with differing character IC groups, active-only automatic
   reprojection, reset, disable/uninstall and edit-while-absent pass.
9. Saved choices survive reload/copy/migration without aliasing or unrelated
   changes; malformed input cannot partially publish. Downgrade rejects intact.
10. Per-item classification has zero bag enumeration/GetMasterItemList calls,
    compilation, projection or refresh; at most one existing matcher call per
    evaluated managed entry. Agreed Q5 workload/count/timing limits pass.
11. External failures are explicit; required IC functions/state fail near the
    defect. No guards or always-false defaults hide maintained defects; no
    speculative rollback machinery without evidence of need.
12. Before shipping, tear down the DEV spike framework: remove its manifest
    entry and retain reusable probe source only outside runtime loading, with
    offline tests still usable. Clean any exact-tagged test assignments before
    unloading cleanup, restore normal verbose-copy unit-test Debug behavior,
    and verify after reload that no spike commands, handlers or gate plugin
    remain registered. Preserve the production integration and its required
    optional dependency. Record teardown evidence in SPIKE RESULTS.
