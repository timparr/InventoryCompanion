# AutoCategory integration: SPEC

Updated 2026-10-31. **Planned, not implemented or compatibility-certified.**
This document defines required behavior, accepted author decisions, and open
decisions. It is not a test log or a claim that all requirements are feasible.

Read the [implementation plan](todo_implementation_autocategoryIntegration.md)
for sequencing and the [spike results](AutoCategorySpikeResults.md) for dated
evidence, failed approaches, dependency contracts and current gate status.
The [Show/Notify prerequisite](../Completed/ItemTrackerFlags.md) is complete.

**Handoff warning:** native insertion and sampled rendering/lifecycle work.
Top heading placement and general crowded-gap ordering remain blockers Q1/Q2.
Guild Bank is explicitly deferred to later DEV testing, not passed. Manual
profile projection is not proof of automatic integration reprojection.

## Goal and scope

Configure ordinary Inventory Companion (IC) groups once and optionally use
their existing filters as native AutoCategory inventory partitions.
AutoCategory continues classifying, drawing and sorting its own sections.

- Integration is opt-in, disabled by default; participation defaults off.
- Support seven contexts with independent order: Backpack, Bank, Guild Bank,
  House Bank, Crafting Station, Craft Bag, Furniture Vault. Standard and
  subscriber bank share Bank. Keyboard is the initial platform; gamepad is
  outside scope unless separately verified.
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
  view toggle, context dropdown, order list/arrows, marker chooser and
  participation. Return an open AutoCategory view to normal; preserve choices.
  Category-column width is zero, returning space to names. While active reserve
  consistent width across all row types, including nonparticipants and items.
- Do not expose working-looking controls or save placeholder settings before
  matching and projection work.

### AutoCategory view in the group editor

- A top **AutoCategory** view toggle switches between the existing normal group
  view and the AutoCategory view; it does not toggle integration/participation.
- A dropdown selects one of the seven contexts. The normal view keeps its
  current ordering.
- Show most important first: ordinary groups interleaved with user-selected
  AutoCategory **marker** rows present in that context's active list.
  Markers follow AutoCategory's classification order, have a distinct
  label/badge and no arrows. Their order is changed only in AutoCategory
  settings; explain that briefly in the view.
- Unselected external categories belong below their nearest marker above.
  Our groups in that marker's slot precede the next lower distinct external
  classification priority, even if that category is not a selected marker.
- Up/down arrows move one group past its neighbouring group or marker.
  Crossing a marker changes its slot; edit only the selected context's saved
  order. Up means more important, Down less important.
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
- Selecting a marker displays read-only name/filter text; it cannot invoke IC
  name/pattern editing, Reset, Delete or participation handlers.
- Do not add drag/drop, tracker-order editing or another filter editor.

### Marker selection and defaults

- **Choose markers** opens a checklist of AutoCategory categories present in
  any of the active profile's seven lists. Selection applies across contexts
  wherever the category exists. Retain selected missing names as visibly
  missing/removable choices.
- Missing setting resolves AutoCategory's localized default New, Selling,
  Container and Stolen names, only where present. These commonly overlap
  recent pickups, junk, containers/plunder and stolen name-based groups.
- Explicitly selecting none is valid: all groups occupy the top slot.
- Deselecting a marker appends its groups to the preceding marker's slot, or
  top. A renamed/deleted external marker resolves the same way for display and
  placement, without rewriting saved order until the next user move.
- First participation in a context appends the group to the top slot, above
  all external categories. Turning it off/on retains position.
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
- Below marker M, allocate strictly between M's run priority and the next lower
  distinct priority among *all* external assignments. Entries tied with M stay
  above our groups. Top is above the highest external run priority; a last slot
  with no lower bound extends downward.
- Groups in a slot retain their saved sequence. Whole-number priorities are
  preferred when there is room; fractions are allowed, not proof that every
  crowded slot can render in the intended order.
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
  a new Cyrodiil map is New; an old one is Cyrodiil. Unmatched containers remain
  available to Container.

## Persistence, ownership and lifecycle

Accepted author design, 2026-10-31: **IC owns per-context group order and marker
selection.** This supersedes editing/storing AutoCategory's combined list as
the order record. New field/helper names belong in the implementation plan,
not assumed existing APIs.

- Enablement, marker selection and seven-context order live alongside groups
  in each IC tracked-list profile; participation lives on the ordinary group.
  Use stable rule keys; display names are not identity. Keep positions for
  nonparticipants. Never persist compiled matchers or derived priorities.
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
the [plan](todo_implementation_autocategoryIntegration.md#1-close-ordering-blockers-before-live-activation)
assigns work. **Do not mark an investigation decided merely because a candidate
can format or classify.**

| ID | State / owner | Question or decision | Required closure |
| --- | --- | --- | --- |
| Q1 | BLOCKING research | How can all top-slot managed headings appear above existing headings in saved order? | Offline then ESO native classification AND heading order, no external edits. Equal >1000 run/show fails; no alternative validated. |
| Q2 | BLOCKING research | How does arbitrary managed order survive crowded fractional gaps / integer display-key ties, and external run/show order differences? | Adversarial labels/density and external-priority fixtures, then actual ESO order. No arbitrary limit or alphabetical fallback without D1. |
| Q3 | OPEN implementation research | Which lifecycle hooks and dynamic definition/cache/refresh paths reliably cover edits, AC profile changes, disable and pending work? | Trace installed contracts, wire every surface and test active-only automatic behavior. Manual projection is not closure. |
| Q4 | OPEN validation | Does migration preserve all profiles/imports and do older builds reject new schema without mutation? | Synthetic proxy fixtures and execution of real pre-feature build before normal-save testing. |
| Q5 | OPEN author agreement / measurement | What synthetic inventory/group/burst workload and numerical timing limits define performance acceptance? | Agree before measuring; record call counts and off/on timings. No numerical limits yet accepted. |
| D1 | CONDITIONAL author decision | If Q1/Q2 are impossible under unchanged native rendering, which explicitly revised design is acceptable? | Present failed approaches, supported alternatives and risks; obtain approval. No classification/render takeover or semantic change by assumption. |
| D2 | OPEN author decision | Final heading texture path / DEV-release identity policy and exact gold tint? | Decide before final asset registration/publication. No new converter/tool install assumed. |
| D3 | OPEN, separate UI scope | Where should include/exclude badges appear; which badge colours and optional colour settings? | Author choice: coloured bag/white badge, gold bag/coloured badge, or coloured bag/gold badge. Not blocking plain category headings. |

**Deferred coverage, not open design choices:** Guild Bank to later DEV testing;
gamepad outside initial certification. Other crafting tabs/professions/universal
deconstruction, merchant buy/buyback, interactive collapse and non-Backpack
reloads have no spike certification. The feature must still pass its agreed
seven-context keyboard acceptance matrix; never equate deferral with a pass.

## Acceptance criteria

1. Off/missing integration preserves IC behavior and name width; all integration
   editor UI hides without erasing choices. Enabled incompatible external
   contracts report explicit useful status, not success-shaped fallbacks.
2. View/context show correct independent order and present markers; opening or
   switching produces zero writes/projections/refreshes.
3. Arrows move past groups/markers, persist only that context and preserve
   selection/highlight/visibility; endpoints and search are correct.
4. Opposite overlap orders produce opposite winners; Bank and subscriber match.
   Above/below markers and arbitrary managed labels produce matching native
   classification and heading order, including top/crowded/last slots.
5. Nonparticipants fall through; existing include/exclude/empty-pattern behavior
   is unchanged. Show/Notify/hidden/expansion never alter classification.
6. Rename, edit, delete, participation/order/markers, Reset, copy and both
   profile modes update without reload, except an explicitly approved and
   documented external limitation.
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
