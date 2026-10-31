# AutoCategory integration

Status: Planned; no integration code or settings are implemented. Native
insertion is proven in game. Revised on 2026-10-31 (author decision): Inventory
Companion owns the order of its groups, positioned against user-selected
AutoCategory **marker** categories, and never edits AutoCategory's own
entries. All seven AutoCategory inventory contexts are in scope. This
supersedes the earlier "edit AutoCategory's combined order" and "AutoCategory's
list is the order record" designs.

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
- Support all seven AutoCategory contexts: Backpack, Bank, Guild Bank, House
  Bank, Crafting Station, Craft Bag, and Furniture Vault. Standard and
  subscriber bank share Bank (AutoCategory's own mapping). Each context has its
  own order.
- Use the active account-wide or character-specific Inventory Companion groups.
- Reuse compiled name/wildcard matching, including case-insensitive matching,
  include-any / exclude-none semantics, and empty-pattern behavior.
- Each participating ordinary group can supply one managed category.
  Miscellaneous and individually tracked items are not exported initially:
  Miscellaneous is assembled by tracker presentation rather than ordinary
  pattern membership.
- Provide one ordering view per context: our groups interleaved with the
  AutoCategory categories the user has selected as markers. Groups start at the
  top and can be moved past markers with arrows.
- AutoCategory's own categories are entirely read-only: never change their
  definitions, priorities, display order, hide state, or assignments. Their
  relative order is AutoCategory's and is changed only in its settings window.
- Preserve external definitions, settings, and saved data. Our writes to
  AutoCategory's bag lists touch only our own entries. Unmatched items remain
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
  unavailable: the top view toggle, context selector, ordering list, arrows,
  marker selection, and participation controls. Return an open AutoCategory view
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
- In that view, a dropdown selects the context: Backpack, Bank, Guild Bank,
  House Bank, Crafting Station, Craft Bag, Furniture Vault.
- The list shows, most important first, our ordinary groups interleaved with
  **marker rows**: the AutoCategory categories the user selected (see below)
  that exist in that context's active AutoCategory list. Markers appear in
  AutoCategory's own order, have a distinct label/badge, and have no arrows.
  Every unselected AutoCategory category is treated as sitting below the
  nearest marker above it. A short note states that the order between markers
  is set in AutoCategory's settings.
- Up/down arrows on group rows move a group past its neighbour, which is either
  another group or a marker. Moving past a marker changes which marker the group
  sits below. This edits only our saved order for the selected context.
- Use the currency panel's ordering rows in ESO's main game settings panel as
  the explicit interaction model: the same native per-row up/down arrow buttons,
  hover tooltips, click sound, immediate save/reorder, and moved-row highlight.
  Up makes the group more important; Down makes it less important. Additionally,
  keep the moved group selected and visible in the group editor.
- Indicate participation separately from position. A nonparticipating group
  keeps its stored position but has no AutoCategory entry and cannot win.
- Switching view or context alone must not write settings, normalize saved
  order, reorder the tracker, change participation, or refresh inventories.
- This view edits classification precedence. Display position of our
  sections is governed by show priority (see Saved-data compatibility).
- Do not add tracker-order editing, drag/drop, or a second filter-expression
  editor as prerequisites.
- Selecting a marker row shows its read-only name and AutoCategory filter
  text; it is not editable here.

### Marker selection

Users choose which AutoCategory categories are important enough to appear as
markers. This is a separate small configuration, not a decision we make for
them.

- A **Choose markers** button in the AutoCategory view opens a checklist of the
  AutoCategory categories present in any of the active profile's seven lists.
  Selection applies to every context where that category exists.
- Missing setting uses defaults: AutoCategory's default **New**, **Selling**,
  **Container**, and **Stolen** categories, resolved through AutoCategory's own
  localized default names, and only where such a category exists. Rationale:
  these are the defaults most likely to overlap name-based groups (recent
  pickups, junk, plunder/containers, stolen goods). Explicitly selecting none
  is valid and means every group sits above all AutoCategory categories.
- Deselecting a marker moves the groups below it to the end of the preceding
  marker's slot (or the top slot). A marker that disappears from AutoCategory
  (renamed/deleted there) is treated the same way at display and placement
  time, without rewriting saved order until the user next moves a group.

### Accepted defaults and edge behavior

The author accepted these defaults on 2026-10-31.

- New/missing participation is off; global opt-in does not enroll all groups.
- A group that first participates in a context is appended to the top slot
  (above the first marker), so new groups start above all AutoCategory
  categories. Turning participation off keeps its stored position.
- Groups that have never had a position are listed after the ordered rows,
  without arrows, until they first participate.
- The normal view retains its current ordering. Search may narrow either view,
  but disable move buttons while search hides groups, with a tooltip explaining
  why; do not silently move across invisible rows.
- Disable Up at the first position and Down at the last. Miscellaneous has no
  position or move/participation controls in this view.
- Renaming preserves identity and position. Deleting a group removes its
  participation, position, and AutoCategory entries; built-in name/pattern
  Reset preserves participation and position, matching the existing
  separation between Reset and display preferences.

## Overlapping groups and classification

AutoCategory evaluates its list top-down and the first true category wins
(highest run priority first; equal priorities by ascending name). Our entries
are placed so that this order equals the order in our view, so no separate
winner calculation is needed. Each managed predicate returns true when the
current character's integration is enabled, the group participates, and its
compiled matcher matches the item.

Example: both Maps and Cyrodiil match a Cyrodiil map. Backpack orders Maps
first, so it wins there. Bank orders Cyrodiil first, so it wins in both standard
and subscriber bank. Turning the winning group's participation off lets the
next matching group (or AutoCategory category) win without losing its position.

Example with markers: `Plunder / New / Cyrodiil / Container`. A plunder skull
picked up recently is under Plunder, because it is above New. A new Cyrodiil
map is under New. An old Cyrodiil map is under Cyrodiil. A Container item not
matching any group falls to Container.

Do not rely on Lua table iteration, tracker position, alphabetical display
names, or AutoCategory's display priority to choose the winner.

## Saved-data compatibility

Decided 2026-10-31: **Inventory Companion owns the order.** AutoCategory's bag
lists receive a projection of it.

- **Order** is saved per context in the active Inventory Companion tracked
  list (account-wide or character, alongside the groups it orders). For each
  context it records the ordered groups and, for each group, the marker
  category it sits below (none means the top slot). Order survives edits made
  while AutoCategory is absent, AutoCategory resets, and changes to
  AutoCategory's own order.
- **Marker selection** is saved in the same tracked list. Missing means the
  documented defaults.
- **Participation** (per group) and integration enablement live in the same
  tracked list, independently of Show/Notify and hidden-group settings.
- **Definitions** are registered every session through AutoCategory's plugin
  API (`RegisterPlugin` predefined rules plus `AddRuleFunc`) and are never
  written to `AutoCatRules`. Expressions reference stable internal rule keys
  (`ic_group("<key>")`), so renames do not orphan them. Register the predicate
  function before definitions: offline tests show a definition whose function is
  absent is marked damaged for the session.
- **Projection.** At AutoCategory plugin init (before its cache is built), after
  our edits, and after an AutoCategory profile switch, rewrite **only our own
  entries** in each of the active profile's seven bag lists: remove entries for
  groups that are deleted, not participating, or renamed; insert or update
  entries for participating groups. Never alter any other entry.
- **Placement.** A group below marker M gets a run priority strictly between M's
  priority and the next lower distinct priority in that list, so entries tied
  with M stay in M's slot. Groups sharing a slot are spaced evenly in their saved
  order; fractional priorities are allowed. The top slot is above the highest
  existing priority; a slot with nothing below it extends downwards. Write only
  values that change.
- **Display order is separate** (code reading, 2026-10-31). Sections are drawn
  by `showpriority`, not run priority. The keyboard and gamepad sort key is
  `string.format("%04d%s", 1000 - showpriority, name)`. Fractions are
  truncated, so ties fall back to alphabetical name order. Values above 1000
  give negative keys, which sort above all categories but in reversed order
  among themselves.
- **Decided 2026-10-31:** our entries' show priority equals their run priority
  (except the top-slot mirroring below).
  Users see one order and will treat "which group claims an item" and "where
  its heading appears" as the same thing, so independent display ordering is
  not offered. The aim is that headings appear in the order shown in our view.
  Use whole numbers whenever the slot has room (typical gaps between
  AutoCategory defaults are 10–25), and fractions only when crowded. Groups
  sharing a whole number then display alphabetically, which is a visible
  mismatch. Top slot (above 1000): display among our groups is reversed by
  AutoCategory's formula, so **initially mirror show priorities within that slot
  only** (provisional, 2026-10-31). Try it in game during development and change
  it if it misbehaves. Hide state set in AutoCategory is left alone.
- **Ownership** is marked on the entry itself: every entry we insert into an
  AutoCategory bag list carries `icOwned = true`. An entry is ours only if it
  has the marker, never from a matching label. Projection removes marked
  entries that no longer correspond to a participating group's current name,
  which covers renames and deletions (even made while AutoCategory was absent)
  and other characters' groups. IC keeps no list of names, so nothing grows.
  Decided 2026-10-31, replacing a saved name registry.
- **Category names (decided 2026-10-31).** Every group is registered under a
  marked name so users can see in the bag which headings come from Inventory
  Companion. Preferred: a small inline texture icon before the group name
  (`|t18:18:<texture>|t Plunder`). A built-in ESO texture is used until IC has
  its own. Fallback, if markup in category names proves unsafe:
  `Plunder · Inventory Companion`. The decoration is a single constant chosen
  by in-game trial. The icon is explained in the manual and the AutoCategory
  view.
- **IC icon (designed 2026-10-31).** Our own icon: a wide flap satchel with a
  luggage tag, drawn pure white so it can be tinted in game (ESO multiplies a
  texture by its tint colour). Sources are in
  [Project/Art/CategoryIcon](../../Art/CategoryIcon/); **v5 is chosen**
  (v1–v4 are earlier iterations kept for reference).
  - `CategoryIcon.svg`: the plain icon, used in AutoCategory headings as a
    single inline texture, tinted gold. A heading is a whole group, so headings
    never show include/exclude marks.
  - Include/exclude marks use **two layers** (option 1): a bag layer with a cut
    gap (`CategoryIconIncludeBag.svg` / `CategoryIconExcludeBag.svg`) plus a
    separate badge layer (`CategoryIconIncludeBadge.svg` /
    `CategoryIconExcludeBadge.svg`, a solid plus or a bar), each tinted
    separately. A white badge cannot be kept white inside one tinted texture,
    so these can only be drawn as two stacked controls in IC's own UI, not
    inline in text. Where they appear in IC's UI is not decided yet.
  - Colours: include **blue**, exclude **red** (red/green is the most common
    colour-blind confusion; shape also differs). Badge colouring is still
    open: (A) coloured bag + white badge, clearest; (B) gold bag + coloured
    badge, weakest at 18 px; (C) coloured bag + gold badge. A colour setting
    may follow; good defaults matter more.
  - Textures: convert to 64×64 DXT5 `.dds` with alpha. The texture path is part
    of the category name, so it must never change after release; DEV and
    release folder paths differ, so switching builds renames categories. New
    texture files need a full game restart, not `/reloadui`.
- **Collisions.** AutoCategory renames duplicate category names at load
  (`addTableRules` → `GetUsableRuleName` → `renameBagRule`). That rename
  rewrites the first bag entry with the old name, which could be the user's own
  entry, redirecting it to our category. Marked names make a clash practically
  impossible; as a backstop, skip registering any group whose marked name
  equals an existing AutoCategory category that is not ours, and report it in
  the view.
- **Known residue (AutoCategory's own behaviour):** a heading's collapsed state
  is stored by name in AutoCategory's `collapses` table and is never pruned, even
  for its own renames. A renamed group's heading starts expanded and its old
  collapse flag remains. That is a small, user-driven leftover in AutoCategory's
  data, not ours; document it rather than editing `collapses`.
- **Absent definitions** are harmless (verified offline with AutoCategory's real
  modules): entries are skipped without errors and shown as red `(!)` rows in
  its settings, which the user can delete. While IC is loaded with integration
  off, definitions stay registered with a false predicate, so no `(!)` rows
  appear. Disabling integration removes our entries from the active profile.
- **Shared AutoCategory profiles.** When characters share AutoCategory's
  account profile but have character-specific IC groups, its lists reflect the
  logged-in character's groups; each login reprojects. Marked entries in an
  inactive AutoCategory profile are cleaned when that profile next becomes
  active.
- Moving our entries in AutoCategory's own settings is overwritten at the next
  projection. Document this.

- Missing optional settings use the documented defaults above. Explicit false
  is meaningful. Validate malformed recognized values at loading/import, with
  an actionable error and without partial publication. Treat AutoCategory's
  bag lists as external input: validate the structure before reading or writing.
- Profile selection/copy preserves independent order, markers, participation,
  and enablement without aliasing. Changing Bank order cannot change Backpack.
- Protect new data against older builds that cannot preserve it. Plan a schema
  increment from the current version 3, validate every profile, and finish
  migration before ZOS saved-variable constructors run. Recheck the current
  schema at implementation time.
- Preserve unrelated saved fields and legacy migrations. DEV and release share
  saved variables; prove downgrade rejection before testing on normal data.
- Never clone `ZO_SavedVars` interfaces by copying the proxy: they forward
  writes to live data (found by the spike).

## Technical decisions still gated

Native insertion is proven in game; ownership, placement, markers, contexts,
and defaults above are decided. Remaining investigations:

1. **Placement values:** with AutoCategory's real modules, prove fractional and
   above-1000 run priorities sort and classify as computed, survive its saved
   variables, and are not altered merely by opening its settings window. Prove
   ESO's `string.format("%04d", fraction)` truncates rather than erroring
   (standard Lua 5.3+ would error); if it errors, use whole numbers only and
   renumber our own entries within a slot when crowded. Prove the `icOwned`
   marker survives cache rebuilds, "Export to all bags", and opening/using
   AutoCategory's settings window, and that a same-name collision is skipped
   before registration without AutoCategory renaming anything. Prove an inline
   texture (`|t…|t`) in a category name is safe as AutoCategory's identity:
   lookup, compile, sort tie-break, collapse state, settings dropdown, and
   keyboard header rendering. If not, use the `· Inventory Companion` fallback.
2. **Registration/lifecycle:** in game, plugin registration plus projected
   entries survive `/reloadui` and classify in Backpack and Bank (including
   subscriber bank).
3. **Contexts:** each of the seven contexts classifies through its list (guild
   bank, house bank, crafting station, craft bag, furniture vault included).
4. **Profiles:** find AutoCategory's account/character switch path and prove
   reprojection into the newly active profile without touching the other.
5. **Platforms:** keyboard is verified; gamepad remains out of scope unless
   verified.

## Acceptance criteria

1. Absent/disabled integration preserves current behavior and editor name width.
   All integration editor UI is hidden, with no inactive preview. Saved choices
   remain intact. Missing optional dependency is normal; incompatible enabled
   integration reports an explicit useful status.
2. The view toggle and context selector show each context's own list of groups
   and present markers in AutoCategory's order. Merely switching views or
   contexts produces zero saved writes/projections/refreshes.
3. Up/down changes and persists only the selected context's order, moves past
   groups and markers, maintains selection/scroll visibility, and handles
   endpoints and active search as documented.
4. A two-group overlap chooses the higher group. Different Bank/Backpack orders
   produce different winners; subscriber bank uses Bank. A group above a marker
   beats that AutoCategory category; below it, the category wins.
5. Disabling a participant falls through to the next match. Exclusions,
   no-includes, and empty patterns match identically to the existing matcher.
6. Show, grouping, Notify, hidden tracker state, and tracker expansion do not
   change classification. Classification does not change pickup delivery or
   AutoCategory collapse.
7. Rename, pattern edit, delete, participation/order change, marker selection,
   Reset, profile copy, and tracked-list switch update AutoCategory without
   reload, except for an explicitly verified/documented external limitation.
8. AutoCategory's own entries (names, filters, run and show priority, hide
   state) are byte-for-byte unchanged by every operation. Projection is
   idempotent: repeated reloads/cycles create no duplicates or drift. Stale
   owned entries are removed; name collisions are reported, not claimed.
9. Order, markers, and participation survive reload/copy without aliasing, and
   survive loading without AutoCategory and editing groups meanwhile. Malformed
   values prevent partial migration/import; older builds reject the new schema
   without modifying data. Disabling integration or the addon leaves
   AutoCategory working without errors.
10. Per-item matching performs zero `GetMasterItemList` calls or bag enumeration,
    and does not compile patterns, rebuild projections, or refresh inventories.
    Synthetic workload/count limits and measured in-game timing gates pass.
11. External API/data incompatibility is surfaced; failures of maintained
    functions/state remain fail-fast rather than becoming false/unmatched.
    Do not add speculative transaction/rollback machinery; investigate recovery
    only if the actual API path demonstrates a need.

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

In game, verify rendering in all seven contexts, subscriber-bank context,
opposite overlap orders, participation fallthrough, groups above/below markers,
unchanged external entries, an unmatched item, quoted/non-ASCII labels, both
addons' profiles, reload, editing groups while AutoCategory is disabled, and
disabled/missing-addon paths. Measure a representative
full sort and group-edit burst against integration-off baseline and record
explicit workload/timing limits before declaring performance acceptance.

Use a separate branch for substantial runtime implementation only with the
author's approval. Documentation refinement does not start that implementation.
Update user documentation and the authoritative working changelog from actual
implemented behavior; assess cumulative unpublished changes before recommending
a version. Do not mix unrelated packaging work into this feature.
