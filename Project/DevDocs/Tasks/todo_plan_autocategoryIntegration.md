# AutoCategory integration: SPEC

Updated 2026-11-01. **Implemented, but not compatibility-certified.**
This document defines required behavior, accepted author decisions, and open
decisions. It is not a test log or a claim that all requirements are feasible.

**Profile synchronization supersession (2026-11-03):** the
[synchronization fix](../../../AutoCategorySynchronizationFix.md) supersedes
earlier no-exclusion behavior and profile-mismatch pauses. It defines
independent IC/AC scopes, active-only automatic replacement of generated
assignments, preserved AC-side options, Included/Excluded sections with an
internal Other matching barrier, complete profile copying and cancellable
reset/re-setup. Saved-variable schema is now 8. Its offline evidence and
pending in-game checks take precedence over older status descriptions here.

**Ordering contract supersession:** the [ordering-fix plan](todo_implementation_autocategoryOrderingFix.md)
replaces this document's earlier Master, preset, heading-visibility, and
rank/anchor ordering design. Each of the seven contexts now has independent
Display and Priority sequences; native assignments are reorderable rows;
cross-context copying is one-time; there is no Master inheritance or hide
control. Saved ordering is a schema-5 list of `ic:<rule key>` and
`ac:<category name>` references. Runtime priority projection uses distinct
integers 2-1000 and preserves all unrelated native assignment fields. The
ordering-fix plan and current implementation report are authoritative for
these behaviors; unrelated integration requirements and release gates below
remain in force. This also supersedes the earlier D4 approval for rank-bearing
category prefixes; current category names are stable when order changes.

**Failure isolation:** AutoCategory-related failures warn and disable integration
for the session instead of aborting IC startup or other features. Invalid
integration settings are preserved but not used; core profiles still upgrade
safely before ZOS loading. Pending integration work is cancelled, predicates
fall through, and managed assignments are removed when external APIs permit.
Cleanup failures are reported separately. Reload is required after correcting
the cause. Newer unsupported saved schemas and unrelated core-data errors
continue to stop initialization.

## Terminology

- **Group:** an ordinary Inventory Companion (IC) group with IC name/pattern
  filters.
- **Heading:** an existing AutoCategory (AC) category, represented by a reference
  row in the IC editor. A visible heading can anchor IC groups; it is not an
  IC group. "Managed heading" specifically means the native AC section created
  for a participating IC group.
- **Order reference:** a stable `ic:<rule key>` or native `ac:<category name>`
  entry in one context's Display or Priority sequence.
- **Context:** one of the seven native inventory/container contexts.

Read the [implementation plan](todo_implementation_autocategoryIntegration.md)
for sequencing and the [spike results](AutoCategorySpikeResults.md) for dated
evidence, failed approaches, dependency contracts and current gate status.
See the [review](AutoCategoryIntegrationReview.md) for the spec/plan assessment
and concrete recommendations.
The [Show/Notify prerequisite](../Completed/ItemTrackerFlags.md) is complete.
The current implementation and remaining acceptance gates are summarized in
the [implementation report](AutoCategoryImplementationReport.md).

**Handoff status, 2026-10-31 23:08 UTC:** all seven follow-up test steps are
finished, including exact-tag cleanup. Empty colour-rank prefixes passed sampled
ESO top/crowded order, visual appearance, rank reversal/cache rebuild and account
reload persistence. Offline scale/boundary/lifecycle suite passes 31/31.
These are supported sampled mechanisms, not an unlimited placement guarantee.
Q1/Q2 now concern a supported placement contract and demonstrated bounds;
D4 prefix-name adoption was approved by the author on 2026-11-01. Reordering changes names and
restarts collapse state while old flags remain. Guild Bank stays deferred;
alignment/collapse interaction and general external run/show mismatches are not
certified. The production integration hooks have since been implemented; their
automated coverage does not replace in-game acceptance. See SPIKE RESULTS for
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
  placement and heading-visibility overrides: Backpack, Bank, Guild Bank, House Bank, Crafting Station,
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
- On first enablement for an IC tracked-list profile without an initialized
  Master arrangement, ask the user to choose a starting preset. Preselect
  **Prefer IC groups** and briefly explain both choices. Re-enabling integration
  after setup preserves the arrangement and does not reapply a preset.
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
  view toggle, context selector, order list/arrows, heading hide controls and
  participation. Return an open AutoCategory view to normal; preserve choices.
  Category-column width is zero, returning space to names. While active reserve
  consistent width across all row types, including nonparticipants and items.
- Do not expose working-looking controls or save placeholder settings before
  matching and projection work.

### AutoCategory view in the group editor

- A top **AutoCategory** view toggle switches between the existing normal group
  view and the AutoCategory view; it does not toggle integration/participation.
- In Master only, each ordinary IC group row shows an **AutoCategory**
  participation checkbox, including nonparticipating and never-ordered groups.
  It displays and changes the same setting as the Edit Items toggle, not a
  separate ordering setting. Explain in its tooltip that participation applies
  across all contexts. Keep both editors synchronized. External AC headings
  have no participation checkbox. Turning participation off retains placement
  and context overrides; turning it on uses an existing placement or the
  first-participation rule below.
- Master has **Show nonparticipating IC groups**, initially checked. Unchecking
  it omits those rows without changing participation, placements, projection
  or inventory. Dim nonparticipating rows using the existing left-panel group
  treatment, keeping their names readable and participation controls usable.
  Do not add a "Not participating" label: dimming, the unchecked checkbox and
  absence of move controls are sufficient indicators.
- Context views show only participating IC groups, with no participation
  controls or nonparticipant filter. Explain: "Enable additional groups in
  Master or Edit Items." Keep the normal group view unchanged.
- A mode selector has eight choices: **Master (all contexts)** first, followed by
  Backpack, Bank, Guild Bank, House Bank, Crafting Station, Craft Bag and
  Furniture Vault. Master edits shared defaults; each context displays those
  defaults with its placement and heading-visibility overrides applied. The normal view keeps its
  current ordering. Decide during development whether to use a dropdown or
  small clickable context icons. Icons must have descriptive tooltips and an
  obvious selected state; the selected mode's name must remain visible.
- An info label beside or below the selector updates immediately with the selection:
  - Master: "Set shared group placements here. Heading labels show where each
    row applies; elsewhere, groups use the nearest applicable heading above.
    Context-specific overrides are retained."
  - Context: "This order controls matching and heading order in <context>.
    Moves and heading hide choices here override the shared Master defaults
    for this context only."
- Show most important first in each context: ordinary groups interleaved with
  visible headings from its active AC list in native classification order.
  Master combines those lists using labelled heading occurrences as described
  below. Heading rows have a distinct label/badge and no order arrows; their
  native order is changed only in AutoCategory settings.
- External AutoCategory heading rows must be obviously distinct from IC group
  rows, including when selected or shown as hidden. Use a recognizable
  AutoCategory icon/badge or explicit label, optionally reinforced by a
  contrasting colour or background stripe. Do not rely on colour alone.
  Exact icon, colours and background treatment remain to be chosen during UI
  refinement; preserve readable text and selection/highlight visibility.
- Each external heading row has the normal hide/unhide control. Hiding a heading
  hides it from the ordinary AutoCategory editor view and removes it as an
  ordering reference in the affected contexts; it does not change AutoCategory's
  own hidden setting. Master controls the selected occurrence's shared visibility;
  context controls override visibility only in that context, as described below.
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
  In Master, moves change the shared order. In a context, moves save only that
  group's placement difference from the master, not a copy of the entire list.
  Crossing a visible heading changes its slot. Up means more important, Down
  less important.
- Show move controls only in the clean ordering view: in Master, both
  Show nonparticipating IC groups and Show all AutoCategory groups must be
  unchecked; in contexts, Show all AutoCategory groups must be unchecked.
  Otherwise hide all move arrows, while participation and heading hide/unhide
  controls remain usable. Explain: "Hide inactive groups and hidden headings
  to adjust priorities." There is no separate enable/move mode.
  Only participating IC groups have arrows. Moves use participating groups
  and usable heading references without changing retained nonparticipant
  placements; no click jumps over visible inactive rows.
- Match the currency panel's native ordering rows in ESO's main settings:
  up/down buttons, hover tooltips, click sound, immediate save/reorder and
  moved-row highlight. Also preserve selection and scroll visibility.
- Participation is separate from position. Off retains position but contributes
  no assignment and cannot win. When included by Master's filter, never-ordered
  groups appear after ordered rows without arrows until first participation
  establishes their placement as described below.
- Disable Up/Down at endpoints. While search hides groups, disable all moves
  with an explanation; do not move across invisible rows.
- View/context selection alone does not save, normalize order, reorder the
  tracker, project or refresh inventory.
- Selecting an external heading displays read-only name/filter text and its
  hide/unhide control; it cannot invoke IC name/pattern editing, Reset, Delete
  or participation handlers.
- Do not add drag/drop, tracker-order editing or another filter editor.

### Shared order and context overrides

Configure the shared order once in Master. In a context such as Bank, moving
a group changes its placement only there; the rest of the list continues to
inherit Master changes.

- Master shows a combined sequence of heading occurrences. Share a row across
  contexts where their native heading order permits it; use separate
  occurrences of the same heading where their positions differ. Filtering to
  any one context must reproduce that context's native AC heading order.
  Do not choose one context's order for all or invent a best-fit common order.
- Each occurrence has an underlying native context scope, for example
  Bank only or Backpack and Furniture Vault. Its ordinary Master label lists
  only contexts where it is effectively usable as an anchor, after visibility
  overrides. Hiding Low level in Bank removes Bank from that label; other
  contexts remain. If none remain, omit the row from ordinary Master.
  Show all AutoCategory groups reveals it with its original native scope and
  hidden contexts clearly indicated, including partially hidden rows.
  Do not change occurrence identity, native scope or saved group placements
  when effective visibility changes. Unavailable occurrences never anchor
  groups in that context; this is not a change to AC's own hidden setting.
- Each IC group appears only once in Master. Its position beneath a heading
  occurrence applies directly in the contexts labelled on that row. In other
  contexts, walk upward through the combined Master heading sequence to the
  nearest occurrence that applies there and is not hidden in IC, or use top
  if none exists. Preserve the stored Master placement and create no override
  merely to resolve this fallback.
- More specialized placement belongs in a context override, not a second
  Master row for the same IC group. Fallback can make inherited groups share
  a heading slot; their inherited ordering still determines their sequence.
- Moving B between C and D in Bank places it between them in Bank without
  changing Master or other contexts. Changes elsewhere in the list do not
  disturb that placement while C and D retain their positions.
- Inserting another group into the Bank list changes that group's placement,
  not a chain of neighbouring groups' choices.
- A context-specific placement does not follow a particular neighbouring group
  automatically when that neighbour is moved. Inherited groups can move past
  it when their Master positions change.
- Each context shows its actual available AutoCategory headings in native
  order. Missing or IC-hidden headings are not references; affected groups
  resolve to a preceding usable heading or top without erasing user choices.
- Internal order maintenance must not change any context's visible order or
  chosen heading placement. It requires no user reconfiguration.

Combined-heading example ("Other contexts" means the five contexts other than
Backpack and Furniture Vault):

```text
Native AC orders:
  Other contexts:  New / Selling / Low level
  Backpack:        New / Low level / Selling
  Furniture Vault: Low level / New / Selling

Master heading rows:
  New       [Other contexts, Backpack]
  Low level [Backpack, Furniture Vault]
  New       [Furniture Vault only]
  Selling   [All contexts]
  Low level [Other contexts]
```

An IC group placed below the Furniture-Vault-only New row uses New in Furniture
Vault, the preceding Low level row in Backpack, and the first New row in Other
contexts. It appears once in Master; each context can override the inherited
result if required.

Behaviour examples:

```text
Master:                         New / A / B / To sell / C / D
Bank, after moving B below Sell: New / A / To sell / B / C / D
```

Swapping C and D in Master also swaps them in Bank:
`New / A / To sell / B / D / C`. Swapping A and B in Master does not move B
out of its Bank-specific placement.

For a separate example, move B between C and D in Bank, then insert A between
C and B. Bank becomes `New / To sell / C / A / B / D`. If C and D themselves
are subsequently swapped in Master, Bank becomes
`New / To sell / D / A / B / C`. A and B retain their Bank-specific placement;
the inherited C and D move past them. Overrides do not bind a group to its
neighbours or guarantee it remains between those neighbours after they move.
This behaviour is confirmed; do not change the ordering algorithm to introduce
neighbour-following relationships.

Context views show effective placement, not override bookkeeping. Do not add
override indicators or individual-group Reset to Master controls. Users adjust
the context order directly or use the whole-context Reset to Master.

Saved representation, rank assignment and cleanup algorithms belong in the
[implementation plan](todo_implementation_autocategoryIntegration.md#resolve-ranks-and-clean-up-spacing),
not in this user-facing contract.

### Starting presets and order reset

- Offer two Master presets, with **Prefer IC groups** preselected:
  - **Prefer IC groups:** place all ordinary IC groups immediately below AC's
    localized default New heading where it is available and not hidden in IC;
    otherwise use top. New retains precedence, with IC groups ahead of the
    remaining AC categories.
  - **Prefer AutoCategory groups:** place all ordinary IC groups below all
    external AC headings in each context, including categories hidden only
    from the IC editor. IC groups catch items not matched by an AC category.
- Both presets initially order IC groups alphabetically by display name and
  retain one IC group row in Master. Different New occurrences or final headings
  must not require duplicate IC group rows or manual context setup.
- The preset choice is a one-off action, not a saved preference. Store only the
  resulting placements; do not remember the choice, reapply it later, or use it
  to place newly created or newly participating groups. Subsequent moves change
  those placements normally.
- Master has **Reset to defaults**. Clicking it asks for the preset again, with
  Prefer IC groups preselected, and warns that it replaces the shared Master
  arrangement. Existing context overrides are retained; inherited placements
  follow the new defaults.
- Each context has **Reset to Master**, clearing only that context's placement
  overrides so it inherits the current Master again. It does not reset Master
  or another context; heading-visibility overrides are retained.
- Preset/reset actions do not change group participation, heading hide choices,
  filters, Show/Notify settings, or external AC entries. Canceling the preset
  choice leaves the previous enablement and arrangement unchanged.

### AutoCategory heading visibility and defaults

- Every AutoCategory heading present in any of the active profile's seven lists
  is available as an editor reference row wherever it exists. By default,
  heading occurrences are visible in Master and contexts inherit that visibility.
  Store shared occurrence visibility and sparse context visibility overrides
  per active IC tracked-list profile, not a category-name-wide hide list.
  Missing external headings do not cause AutoCategory data to be changed.
- Master hide/unhide changes shared visibility for that occurrence only,
  not other rows with the same category name. Context hide/unhide changes only
  that context's visibility override for its corresponding occurrence.
  Missing overrides inherit Master; explicit visible/hidden overrides remain
  local when shared visibility changes. Neither operation changes native scope.
- Derive effective visible contexts, Master labels and row inclusion from shared
  visibility plus context overrides. Do not also store a "hidden in Bank and
  Backpack" list or a derived Master shown/hidden flag.
- Hiding a heading removes it from the affected context's effective reference sequence. Groups
  ordered after it resolve to the nearest preceding visible heading, or top.
  Unhiding it restores it as a reference without changing the saved group order.
- A missing heading is not displayed in a context where it does not exist.
  When renamed or deleted externally, preserve IC's stored visibility choices without
  rewriting group order. Resolve affected groups upward from their placement
  in the current list to the nearest currently available, applicable and
  IC-visible heading, or top if none exists. This is not attachment to a
  historically selected fallback heading; reevaluate against the current list.
- Enabling participation for a group without a saved placement inserts it
  immediately after the last participating IC group in Master, or at the
  bottom of Master if none participate. This applies to existing groups as
  well as newly created ones and is inherited by contexts without an override.
  Groups with a saved placement reuse it; turning participation off/on retains
  their Master placement and context overrides.
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
per-context placement and heading-visibility overrides.** Visible external headings are ordering
references; IC hidden headings are not. This supersedes editing/storing
AutoCategory's combined list as the order record. New field/helper names belong
in the implementation plan, not assumed existing APIs.

- Enablement, Master occurrence visibility, master placements and sparse context overrides
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
- **Temporary implementation approved 2026-11-02:** use a white no-op suffix
  (`<name>|cFFFFFF|r`) to distinguish IC category identities while the custom
  texture is unavailable. It preserves the heading's normal rendered color and
  is not the final icon design.
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
| Q4 | SYNTHETIC SAFETY CHECKS PASS; NO NORMAL SAVES USED | Does migration preserve all profiles/imports and do older builds reject new schema without mutation? | Focused runner verifies synthetic migration/import fixtures and schema-v4 rejection by the actual pre-feature schema-v3 sources at `HEAD`; no normal saved data has been loaded. |
| Q5 | POST-IMPLEMENTATION MEASUREMENT | What synthetic inventory/group/burst workload and numerical timing limits define performance acceptance? | Agree workload and limits when preparing post-implementation measurement; record call counts and off/on timings. No numerical limits are accepted yet. |
| D1 | CONDITIONAL author decision | If Q1/Q2 are impossible under unchanged native rendering, which explicitly revised design is acceptable? | Present failed approaches, supported alternatives and risks; obtain approval. No classification/render takeover or semantic change by assumption. |
| D2 | OPEN author decision | Final heading texture path / DEV-release identity policy and exact gold tint? | Decide before final asset registration/publication. No new converter/tool install assumed. |
| D3 | OPEN, separate UI scope | Where should include/exclude badges appear; which badge colours and optional colour settings? | Author choice: coloured bag/white badge, gold bag/coloured badge, or coloured bag/gold badge. Not blocking plain category headings. |
| D4 | APPROVED author decision, 2026-11-01 | Adopt empty colour-rank prefixes in production category names? | Author accepts rank-bearing name changes, expanded-after-reorder behavior and retained old collapse flags. ESO sampled appearance/order/reorder/account reload and cleanup passed; 128-group scale passed offline. Production acceptance remains required. |

After Test 7/7 on 2026-10-31, the author initially left D4 open.
On 2026-11-01, the author approved the demonstrated empty colour-rank prefix
for production naming, accepting expanded-after-reorder behavior and old
per-name collapse flags remaining in AC saved data. This closes the naming
decision, not the post-implementation acceptance gates or known placement limits.
This historical approval is superseded by the ordering-fix contract above.

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
2. Master/context views show the master or resolved inherited order and
   available visible external headings; opening or switching produces zero
   writes/projections/refreshes. All eight selector choices update the mode
   explanation; external rows remain visually distinct in normal, selected
   and revealed-hidden states. Context-labelled Master heading occurrences
   preserve each native heading sequence when filtered; each IC group appears
   once. The combined-heading example and upward applicable-heading fallback
   pass without creating context overrides or rewriting Master placements.
   Master-only participation controls stay synchronized with Edit Items.
   Its default-on nonparticipant filter only changes row visibility; dimmed
   nonparticipants remain readable and toggleable, with no status label or
   move controls. Context views omit them and their participation controls.
   Heading visibility inherits Master unless overridden in a context. Hiding
   one occurrence does not hide same-name occurrences elsewhere. Bank-only
   changes update Master's effective context label; hiding its last visible
   context omits the row, and Show-all reveals its original scope/hidden contexts.
   Visibility changes preserve occurrence identity and saved group placements.
3. Arrows update shared placement in Master or context-specific placement in
   the selected context, preserving selection/highlight/visibility. Untouched
   choices inherit subsequent Master changes; agreed behaviour examples above
   pass. Internal order maintenance preserves every context's visible order
   and heading placement. Endpoints and search are correct. Arrows appear only
   with inactive groups and hidden headings filtered out; expanded views keep
   participation/hide controls and explain how to enable ordering. Moves
   preserve nonparticipant placements. First participation without a placement
   inserts after the last participating Master group, or bottom if none exist;
   off/on reuses an existing placement.
   First enablement and Master reset offer both presets with Prefer IC groups
   preselected; re-enable preserves choices. Context Reset to Master clears
   only that context's overrides. Presets/reset preserve participation, heading
   hide choices and unrelated data; cancellation publishes no changes.
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
