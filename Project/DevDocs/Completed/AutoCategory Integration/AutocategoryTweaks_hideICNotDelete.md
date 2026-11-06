**ARCHIVED 2026-11-04.** Completed exclusion/Other work and dated evidence.
The [master feature specification](../../FeatureSpecs/AutoCategoryIntegration.md)
owns final behavior. In particular, its dedicated AutoCategory participation
editor supersedes this plan's tracking-editor area selector and summaries.

## Open questions

None. The decisions below are confirmed.

---

# Context-specific exclusion and movable Other

This was the implementation document for the agreed changes below.
The [master feature document](../../FeatureSpecs/AutoCategoryIntegration.md) owns the overall
integration contract, implemented baseline, dependency guidance and evidence
status. Earlier plans and investigations are retained in its archive index.

### Assessment

Yes—this is a coherent improvement. **Excluding a group from Bank should not remove it from Craft Bag.** Keeping the AutoCategory column as an area selector makes that distinction accessible without introducing another global toggle.

The schema-8 implementation confirmed the original diagnosis:

- `SetEntryIncluded` changes IC group participation across every context, whereas native AC exclusions are context-specific.
- `Other’s projection` currently places it immediately after included categories in **both** orders, before excluded categories.

One important distinction: **moving Other above Sets in Display changes presentation only.** Sets still classifies matching items if it remains included ahead of Other in Priority. That separation should remain intentional.

## 1. Goal

Use the same context-specific Included/Excluded behavior for IC groups and native AC categories.

Allow users to position **Other** in Display order without exposing or weakening its automatic matching barrier.

Example: **Rare Mats included in Craft Bag, excluded in Bank**, with neither choice affecting the other.

## 2. Context-specific inclusion

- Inclusion belongs to the selected IC profile and one of the existing seven contexts.
- Toggling a row affects only the selected context.
- Inclusion is shared between that context’s Display and Priority lists.
- Excluded rows remain accessible below the **Excluded** divider in both lists.
- Newly created IC groups start Included in all seven contexts. Insert them immediately above Other's current position in each context's Display order, including when the user has moved Other. In matching order, insert them immediately before the automatic Other barrier, at the bottom of the visible included Priority list.
- Exclusion does not delete the source IC group or its saved configuration.
- Exclusion must not remove assignments or alter inclusion in other contexts.
- Retain the existing position-restoration rules when re-including a row.
- Tooltips must describe context-specific behavior, not participation “across all seven contexts.”

Matching order must always be:

1. Included IC groups and native AC categories.
2. Other.
3. Excluded IC groups and native AC categories.

Excluded assignments therefore receive no items, without requiring global removal of their categories.

## 3. Other in Display order

- Show **Other** as a special row in each context’s Display list.
- Support normal ordering controls, including multi-selection moves.
- Save its display position independently for each context.
- Initially place Other at the bottom of each context's included Display list, immediately before the Excluded section. This is its starting position, not a pinned position: subsequent moves and reloads preserve the user's saved placement.
- Keep it ahead of the Excluded section.
- Do not provide an inclusion toggle or allow deletion.
- Do not expose it as an ordinary editable IC group.
- Omit it from the Priority list; its matching position remains automatic.
- Explain in its tooltip that moving it changes display order, not matching precedence.

Ordering helpers must explicitly handle the unequal list membership:

- **Use display list** transfers ordinary-row ordering to Priority without transferring Other.
- **Use priority list** transfers ordinary-row ordering to Display while retaining Other’s saved display slot.
- Cross-context copying includes Other’s display placement and preserves existing destination-membership rules.

## 4. Items-editor area selector

Retain the **AutoCategory** column, replacing its global toggle with:

- A compact summary using the length-based algorithm below.
- A dropdown containing seven independently checked areas.
- Checked means Included; unchecked means Excluded.
- Each change has exactly the same effect as toggling that group in the corresponding AutoCategory context.
- Changes refresh both editors consistently.
- Individual tracked items and Miscellaneous remain without this control.
- Preserve existing inactive-integration and recovery behavior.

There must be one shared inclusion model—not separate settings maintained by the two editors.

### Area-summary algorithm (confirmed)

Evaluate these cases in order:

1. All seven enabled: **All**.
2. None enabled: **None**.
3. Exactly one enabled: show that area's name.
4. Exactly one disabled: show **Not: <area name>**.
5. Join enabled area names with comma-space separators. If the complete text fits the summary label, use it.
6. Otherwise join disabled area names with comma-space separators, prefixed with **Not: **. If the complete text fits, use it.
7. Otherwise show the enabled count in words: **Two Areas**, **Three Areas**, **Four Areas** or **Five Areas**.

Use the existing context order for name lists. Test fit using rendered text
width in the label's actual font against its available width, including
separators and the **Not: ** prefix, rather than a fixed area-count rule.
Enabled names take precedence whenever they fit; do not choose disabled names
merely because they are shorter. The single-area cases take precedence over
the fit checks; allow enough width for **Not: Furniture Vault**.
The tooltip and dropdown always expose the complete per-area state.

## 5. Persistence and migration

- Reuse the existing per-context ordering/exclusion model where practical.
- Remove the global participation flag’s authority over context-level choices.
- Confirmed migration behavior:
  - Previously participating groups become included in all contexts.
  - Previously nonparticipating groups remain excluded in all contexts. Because they have no existing order entries, initialize them at the bottom of each context's lists, in the Excluded section.
- Distinguish migrated nonparticipants from newly created groups: new groups start Included immediately above Other in every context's Display and matching orders.
- Initialize Other's saved display position at the bottom of each context's included list. Do not reset a subsequently saved placement.
- Preserve existing orders, native exclusions, restoration positions, assignment options and unrelated saved data.
- Validate and migrate **every IC profile before ZOS constructors**.
- Increment the schema version and verify downgrade rejection before testing against normal shared DEV/release saves.
- Preserve active-destination-only synchronization and all existing profile-scope combinations.

### Illustrative saved-variable excerpts

These are partial IC profile examples, not complete saves or implemented
migration output. Other contexts, source group definitions and unrelated
fields are omitted, not deleted. The proposed schema is **9**, replacing
schema **8**. Stable group keys below are examples; native category references
use their actual AC names.

**Before: global participation.** Rare Mats participates in every context.
The existing hidden map supports native AC categories only; Other's position
is calculated rather than stored in the Display sequence.

```lua
version = 8,
trackedRules = {
    rare_mats = {
        autoCategoryEnabled = true,
        -- Other source-group settings omitted.
    },
},
autoCategoryOrder = {
    contexts = {
        bank = {
            display = { "ic:rare_mats", "ac:Sets" },
            matching = { "ic:rare_mats", "ac:Sets" },
            hidden = {},
            displayPositions = {},
        },
        -- Remaining contexts omitted.
    },
},
```

**After migration and a Bank-only exclusion.** Rare Mats remains included
in Craft Bag, but is excluded in Bank. Both Bank sequences retain its
reference at the end. The extended hidden map records the exclusion.
Other now has an explicit Display reference but no saved matching reference.

```lua
version = 9,
autoCategoryOrder = {
    contexts = {
        bank = {
            display = { "ac:Sets", "ic:__ic_other", "ic:rare_mats" },
            matching = { "ac:Sets", "ic:rare_mats" },
            hidden = { ["ic:rare_mats"] = true },
            displayPositions = { ["ic:rare_mats"] = 1 },
        },
        craft_bag = {
            display = { "ic:rare_mats", "ic:__ic_other" },
            matching = { "ic:rare_mats" },
            hidden = {},
            displayPositions = {},
        },
        -- Remaining contexts omitted.
    },
},
```

The Bank runtime matching order is **Sets -> Other -> Rare Mats**: projection
inserts the automatic Other barrier before excluded references. The stored
position `1` records Rare Mats' display position before exclusion for the
existing re-inclusion rules. Source group settings remain intact; the old
global participation flag is no longer the inclusion authority.

**After moving Other, then creating a group.** If the user moves Other above
Sets, a newly created group is inserted immediately above Other in Display,
not at the end. Its Priority entry goes after existing included entries,
immediately before the automatic barrier. This is a Bank context excerpt;
the new group is also included in the other six contexts.

```lua
bank = {
    display = {
        "ic:new_group", "ic:__ic_other", "ac:Sets", "ic:rare_mats",
    },
    matching = { "ac:Sets", "ic:new_group", "ic:rare_mats" },
    hidden = { ["ic:rare_mats"] = true },
    displayPositions = { ["ic:rare_mats"] = 1 },
},
```

Runtime matching is **Sets -> New Group -> Other -> Rare Mats** despite
Other displaying above Sets. No separate area-checkbox map, summary text or
user-editable Other matching position is saved. Previously nonparticipating
groups migrate with their references in each context's excluded tail and
`hidden["ic:<group key>"] = true`, rather than being treated as new groups.

## 6. Implementation plan

1. **Record the confirmed decisions** as superseding the conflicting global-participation and invisible-Other requirements.
2. **Implement and test schema migration/downgrade protection.**
3. **Unify context inclusion and projection** for IC and native rows, including groups excluded everywhere.
4. **Add Other’s Display-only ordering**, covering move, copy, reconciliation and list-conversion operations.
5. **Replace the items-editor toggle** with the shared area selector and update tooltips/documentation.
6. **Run focused offline tests**, then controlled in-game acceptance.

## 7. Acceptance criteria

- Area summaries follow the specified precedence, including long names, the **Not: ** prefix, exact-width fits and word-count fallback.
- Rare Mats classifies in Craft Bag but not Bank, including after reload.
- Either editor changes the same underlying context state.
- Excluding a group in all areas preserves its configuration and allows later re-inclusion.
- Previously nonparticipating groups migrate to the bottom Excluded section in every context without disturbing existing orders.
- Other initially appears at the bottom of each context's included Display list; moving it and reloading preserves its saved position.
- A newly created group starts Included in all seven contexts, immediately above Other's current Display position and immediately before its automatic matching barrier. Test insertion after Other has been moved above other included categories.
- Other can display above Sets without changing which category wins matching.
- No excluded category receives items.
- Other never appears in Priority or becomes excludable.
- Moves and copy operations produce complete, valid orders despite different list membership.
- Profile switching preserves independent choices and leaves inactive AC profiles untouched.
- Migration preserves unrelated data; older supported builds reject the new schema without modifying it.
- In-game checks do not transfer items or mutate live inventory.

Implemented in DEV with schema 9. Offline coverage includes migration of every
profile and stored list backup, actual schema-4 through schema-8 downgrade
rejection, context-isolated matching barriers, all-area exclusion/re-inclusion,
Other moves/copy/list conversion/new-group insertion, all 128 area-summary
combinations and both editor control paths. Controlled in-game acceptance,
including actual font sizing and the seven-context lifecycle matrix, remains
pending. Offline tests do not transfer items or load normal game saved variables.

Verification: `python Project\Tests\Run-RuleTests.py` passes **198/198**
isolated tests, including Lua 5.1 syntax and XML structure checks.

Area-summary sizing uses an unconstrained hidden label with the visible label's
font and `GetTextWidth()`, matching the existing currency settings measurement
pattern. Regression coverage excludes two areas with no global `GetStringWidth`
available and checks exact-width fits and one-pixel overflow.