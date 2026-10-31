# AutoCategory integration plan

Status: Proposed; investigation only. No integration code or settings have been implemented.

Technical findings and implementation tasks: [Implementation document](todo_implementation_autocategoryIntegration.md).

UI prerequisite: complete the [item tracker flags/options improvement](todo_plan_itemTrackerFlags.md) first. The approved layout reserves a group-only AutoCategory toggle last, after the two-line Show and Notify controls. Participation remains independent of HUD display and delivery.

The AutoCategory column must have zero width when integration is disabled or unavailable, returning the space to item names. When enabled, keep the column width consistent across all row types, even for nonparticipating groups.

## Goal

Let users configure their groups in Inventory Companion once and optionally use those same groups as inventory partitions in AutoCategory. Avoid requiring users to understand and duplicate AutoCategory rule expressions.

AutoCategory remains responsible for drawing and sorting its inventory sections. Inventory Companion supplies matching based on its current group definitions. Do not edit AutoCategory's installed source.

## Proposed first version

- Opt-in integration, disabled by default; Inventory Companion remains fully usable without AutoCategory.
- Backpack and standard/subscriber bank inventories initially. Craft bag, house chests, guild bank, furniture vault, and crafting/deconstruction views are not initial acceptance requirements.
- Use the active account-wide or character-specific Inventory Companion rules.
- Reuse compiled Inventory Companion matching, including its case-insensitive name/wildcard semantics.
- Keep category names and matching current after group creation, rename, pattern changes, deletion, and tracked-list switches.
- Leave unmatched items to existing AutoCategory categories.
- Preserve unrelated AutoCategory rules, priorities, settings, and saved data.
- Keep AutoCategory category collapse independent of tracker expansion preferences and automatic tracker height decisions.
- No inventory transfers, item mutation, or full inventory scans from a per-item category predicate.

## AutoCategory view controls

The AutoCategory view must provide two dropdowns:

- **Inventory:** Backpack / Bank (including subscriber bank under the Bank context).
- **Ordering:** Rule precedence / Display order.

These are separate from our tracker display ordering. The selected inventory and ordering mode determine which AutoCategory arrangement is inspected or edited; switching views alone must not mutate it. Exact labels, placement, and UI composition remain to be determined during development.

Use the existing currency settings up/down move interaction where editing is supported. Do not equate AutoCategory rule precedence with its display order.

## Development questions: combined category view

Investigate and test these during development; they are not settled behaviour or promises of API support:

- Can the AutoCategory view safely list our managed groups alongside AutoCategory built-in and user-created categories for the selected inventory?
- Can users move those categories relative to each other without damaging ownership, defaults, or profile-specific assignments?
- Which operations are supported through stable interfaces, and which depend on version-sensitive internals?
- What should hide/show mean? Determine the difference between disabling rule participation, hiding matching items, and collapsing a category. Verify whether unmatched/disabled items fall through to later rules.
- Can external filter expressions remain read-only while their assignments/order are managed here? Is reliable navigation to AutoCategory's own editor available?
- How should source badges, missing categories, collisions, and external edits be presented and reconciled?
- How do bag-specific rule precedence and display order interact with managed groups, and what should each arrow operation change?

Do not silently edit external filters, hide items, or implement a second rule editor while exploring this view. Agree concrete interaction semantics after testing what the installed AutoCategory build supports.

## Product decisions to resolve before coding

These are recommendations, not agreed behaviour.

1. **Participation control:** The author has confirmed group rows only and the full AutoCategory label last on the row. Add an explicit per-group participation flag independent of tracker visibility/grouping. Confirm the flag's default and interaction with hidden rules before implementation; hiding a HUD group must not unexpectedly remove an inventory partition.
2. **Overlapping matches and editor ordering:** Keep tracker display order independent of AutoCategory ordering. In the group editor, provide Alphabetical / Tracker order / AutoCategory views, with the two required dropdowns in the AutoCategory view. Use the same per-row up/down arrow pattern already implemented for currency settings in editable order views; Alphabetical is read-only ordering. AutoCategory's first matching category wins. Keep the moved row selected/visible and highlight it. Resolve filtered-list movement, equal/default priority, and storage normalization during development; do not make tracker position affect AutoCategory matches.
3. **Existing AutoCategory precedence:** Open development question: test a combined category view that allows our groups to sit among existing rules. Do not assume all our managed categories take precedence over all existing rules. Decide defaults and permitted edits after verifying the selected bag's rule precedence and display order.
4. **Names and ownership:** Recommend recognizable managed category names and stable internal ownership keyed by our rule identity, not display name. Establish behaviour for name collisions and manual edits of managed entries.
5. **Miscellaneous and individually tracked items:** Recommend excluding our special Miscellaneous group initially. It is assembled by tracker display logic, not simply matched by ordinary patterns. Decide separately whether individually tracked items need a dedicated partition.
6. **Enable/disable and uninstall:** Decide runtime-only categories versus persisted managed entries after the technical spike below. Disabling must restore ordinary AutoCategory behaviour without deleting user rules. Uninstall/reload must not leave broken rule expressions unnoticed.
7. **AutoCategory profile switches:** Confirm how our managed groups follow AutoCategory's own account/character selection and preserve inactive profiles.

## Implementation stages

- [ ] Resolve the product decisions above conversationally.
- [ ] Reuse the currency settings arrow-button interaction for group ordering; keep this ordering work separate from the initial row-options UI task.
- [ ] Complete the category-management/load-order spike in the implementation document. Stop if safe registration and removal cannot be established; do not substitute a broad hook silently.
- [ ] Implement a narrow optional adapter and per-item matching bridge.
- [ ] Implement owned category lifecycle and synchronization using verified AutoCategory operations.
- [ ] Add settings and external-dependency status/error reporting.
- [ ] Add isolated contract/count tests and synthetic inventory-sort performance checks.
- [ ] Test real AutoCategory rendering, profile changes, fallback categories, enable/disable, and persistence in game.
- [ ] Update user documentation and the working Unreleased changelog. Assess the cumulative unpublished changes before recommending a version; this integration would normally be a minor feature.

## Acceptance criteria

1. With AutoCategory absent or integration disabled, existing behaviour is unchanged.
2. A participating group creates the expected partition in the supported inventories; its matching agrees with Inventory Companion's matcher.
3. Overlapping items receive the documented winning group consistently.
4. Editing/renaming/deleting groups and switching our tracked list update partitions without reload unless an explicitly documented external limitation requires it.
5. Existing unrelated AutoCategory rules and saved variables are preserved.
6. Disabling integration removes its effect; reload and missing-addon cases do not strand erroneous expressions or duplicate managed categories.
7. Tracker manual/automatic expansion does not change AutoCategory collapse and vice versa.
8. Category matching causes zero calls to `GetMasterItemList` or bag enumeration; compilation/cache rebuilds are not repeated for each item.
9. External incompatibility produces an explicit useful message, not a success-shaped fallback. Internal contract errors remain visible near their cause.

## Verification scope

Offline tests must simulate the relevant AutoCategory contracts and count matcher invocations, scans, registrations, removals, and refreshes. Timing alone is insufficient because mocked ESO APIs are cheap.

In-game tests must use the installed AutoCategory build and actual category rendering. Include an existing user category, an unmatched item, an overlapping match, quoted/non-ASCII display names, a manual rename, both addons' profile contexts, and disabled/missing integration paths. Check bank and subscriber-bank presentation without transferring items merely to generate load.

Measure a representative full inventory sort and a burst of group edits against a baseline with integration off. Set explicit workload/timing limits after measurement; do not invent an artificial per-scan delay.

## Constraints and release safety

Use a separate branch for substantial implementation only with the author's approval. Current release packaging and numbering-policy work are unrelated and must not be mixed into this feature.

Do not change live AutoCategory saved variables during offline tests or exploratory probes. Treat its APIs and saved data as external boundaries. Validate adapter compatibility once at activation; after that, our own maintained state/functions must obey explicit contracts.
