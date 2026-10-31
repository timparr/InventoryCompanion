# Item tracker editor flags and row options: implementation

Status: In progress on `feature/item-tracker-row-options`, branched from main
after the group-pattern branch was fast-forward merged on 2026-10-31.
The two-line layout and compact Show/Notify boxes were approved conversationally
on 2026-10-31. Runtime and editor implementation is in place; 99/99 isolated
tests passed, including Lua 5.1 syntax and existing performance limits. Changed
XML/SVG and whitespace/link checks passed. The user confirmed the in-game
acceptance tests passed on 2026-10-31.
Implementation completed and archived at the user's request on 2026-10-31.
Automated and user-reported in-game acceptance are complete.

Feature behavior and compatibility requirements are in the
[feature plan](ItemTrackerFlags.md). The approved design replaces the
earlier quick-toggle / Options proposal and includes independent display
locations and Chat/HUD delivery now, not as a later destination extension.

## 1. Resolve and save independent settings

### Representation and legacy compatibility

In [Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua), add optional
boolean display flags `showBackpack`, `showBank`, `notifyChat`, and `notifyHud`.
Keep `group` for grouping, plus legacy `show`, `bank`, and `notify` values.
New editor actions write only the selected new flag or `group`.

`ResolveItemDisplay(display)` creates a resolved view without changing saved
data. Missing location flags derive from legacy Show/Totals; missing delivery
flags derive from legacy Notify. Explicit false is significant:

- `showBackpack`: defaults to legacy `show ~= false`.
- `showBank`: defaults to legacy Show enabled and `bank == true`.
- `notifyChat` / `notifyHud`: each defaults to legacy `notify == true`.
- Resolved `show` and `notify` represent whether any location/destination is on.

Set `SettingsVersion = 3` to protect against older builds that cannot safely
read/preserve the new fields, despite the additive representation. Existing
rule delta arrays are unchanged.

`PrepareSavedVariables()` validates every account/profile and constructs all
upgrade work before publishing changes. Version 2 profiles retain their saved
tables and settings and receive only the version 3 marker. Version 1 profiles
also undergo the existing sparse-rule conversion. Publish upgraded versions
before ZOS constructors run, preventing their destructive old-version reset.
Already-current data is not remigrated; unknown future versions are rejected.

An actual schema 2 build from commit `9dc0e12` is executed in the isolated
regression suite to prove version 3 is rejected before unknown-flag validation,
without changing account or inactive-profile data. Downgrading requires a
compatible saved-data backup restored with ESO closed; switching DEV/release
does not create separate saved variables.

In-game evidence (2026-10-31): user tested loading DEV, then switching to the
older release, and confirmed it throws as expected. This confirms downgrade
rejection in game. The user subsequently confirmed the acceptance tests passed,
covering native row interaction, counts/delivery, and reload/settings preservation.

### Validation, sparse writes, and import

- Validate new flags at saved-data loading/import boundaries, including inactive
  profiles. Reject malformed recognized values before migration/import publishes
  changes; preserve unrelated fields.
- `UpdateRuleFlag()` accepts the new keys and prunes values matching their
  inherited legacy/default behavior. `NormalizeRule()` uses the same default
  calculation; do not lose explicit false overrides.
- `CopyProfile()` copies independent fields without aliasing the source.
- `GetRuntimeRules()` publishes resolved rule display views;
  `GetActiveTrackedRules()` continues returning editor copies.
- Individual item editors write the current active saved table. Untracked rows
  promote only on an actual edit, preserving link, icon, and other settings.

## 2. Select counts and notification destinations

### Tracker counts

In [Tracking/ItemTrackerPanel.lua](../../../Tracking/ItemTrackerPanel.lua):

- Honor both location flags for grouped headers/members, flat lists, individual
  items, and the per-item policies folded into Miscellaneous.
- The scan snapshot's `bankCount` is the overall total, not bank-only stock.
  Calculate bank-only holdings as `bankCount - bagCount`; do not double-count
  backpack holdings.
- Backpack-only displays its carried count; bank-only displays bank holdings;
  both retains the current `total \ backpack` presentation.
- Zero-stock eligibility follows selected locations. Neither location hides
  the relevant source without untracking or suppressing other matching sources.
- Include location policy in layout signatures without changing expansion,
  overflow limits, row budgets, or saved collapse preferences.

### Pickup notifications

`HandleTrackedItemInventoryUpdate()` in
[Tracking/ItemDatabase.lua](../../../Tracking/ItemDatabase.lua) unions Chat/HUD
requests from individual settings and all visible matching rules, then emits
at most one notification per gain with only selected message arguments.
Retain the existing positive-gain detection and backpack/craft-bag event scope.
Hidden rules and Include/Exclude vetoes do not contribute destinations.

In [Core/Utils.lua](../../../Core/Utils.lua), the item notification call opts
into destination-restricted duplicate/burst handling. Do not generate a HUD
"check chat" prompt for Chat-only delivery or redirect HUD-only bursts to chat.
Other warning callers, including currency/capacity messages, keep their existing
limiter behavior.

`HasTrackedItemNotifications()` participates in the slot-listener condition in
[Core/Events.lua](../../../Core/Events.lua), so hiding the HUD does not disable
requested pickup delivery. Editor mutations update listener registration.

## 3. Render aligned row controls and compact boxes

In [Tracking/EditPanelItemsTab.xml](../../../Tracking/EditPanelItemsTab.xml):

- Preserve the 810-pixel row width; use a 52-pixel two-line row and 54-pixel
  spacing. Show/Notify are native buttons with title and detail labels.
- Reserve 190 pixels for Show and 120 for Notify. The future full AutoCategory
  label goes last, before the individual Remove X; its column is zero width
  while integration is disabled or unavailable. Anchor the item label between
  the row's left edge and Show so it receives the released space.
- Keep required label fonts readable. Use the existing warm
  `(1.0, 0.94, 0.76)` color with active/inactive opacity, not literal grey.
- Use one clamped, high-tier native backdrop with three reusable checkbox rows.
  Show has grouping (groups only), backpack, and bank; Notify has Chat and HUD.
  No heading, explanatory section, Done button, confirmation tick, or Options.
- AutoCategory participation remains a separate integration task. When enabled,
  its column width must be consistent across rows, regardless of individual
  group participation; no functional-looking placeholder is shipped now.

In [Tracking/EditPanelItemsTab.lua](../../../Tracking/EditPanelItemsTab.lua):

- `ConfigureRowStateStyles()` renders Backpack / Bank / Both / None under Show,
  with ", grouped" when enabled and displayed. Notify detail is Chat / HUD /
  Both / None. No parentheses.
- `OpenRowOptions()` binds current effective settings, applies checkbox and
  label actions through explicit `SetEntryFlag()` boolean writes, and anchors
  the box below the control or above when necessary.
- Each edit refreshes the editor and tracker once, then reopens/rebinds the box
  to the current target if that row still passes the active filters.
- `ShouldIncludeEntry()` and import-preview counts use effective flags:
  Show means either location, Notify means either destination, Inactive means
  neither display nor notification.

## 4. Keep popup actions tied to their row and profile

- Capture stable key, row kind, editor revision, saved-rules table, and context
  revision. Resolve current authoritative data when applying an action.
- Clear popup state at list rebuild, effective editor hide, scrolling,
  click-outside, same-control click, and Escape. Never save popup state.
- Clearing rule overrides refreshes both editors and the tracker; profile
  switches/imports and rule-editor refreshes update listener registration.
- Use native checkbox controls and the same global mouse-down / mouse-over
  ancestry pattern already used by installed addons/libraries. Preserve native
  scroll handling through a prehook, not handler replacement.
- Invalidate old popup callbacks on dismissal/retargeting. Assert stale internal
  action contracts before writing; do not return success or silently redirect
  to recycled rows, another profile, or a deleted item.
- Verify actual ESO keyboard dispatch, Escape/editor lifecycle, clamping,
  scroll hooks, fonts, and mouse propagation in game. Headless control mocks
  and valid XML do not prove native rendering or input behavior.

## 5. Verification and completion

### Automated coverage

Extend existing suites rather than changing live inventory or saved variables:

- [Core/RuleTests.lua](../../../Core/RuleTests.lua): legacy inheritance, explicit
  independent flags, sparse pruning, malformed saved/import values, destination
  union, hidden/excluded rules, and no-output behavior.
- [Project/Tests/RulePersistenceTests.lua](../../Tests/RulePersistenceTests.lua):
  serialization/reload/import of explicit independent flags without runtime data.
- [Project/Tests/TrackerPanelTests.lua](../../Tests/TrackerPanelTests.lua):
  exact selected-location counts for grouped, flat, single-member Miscellaneous,
  and individual display, plus existing expansion/performance checks.
- [Project/Tests/ItemEditorTests.lua](../../Tests/ItemEditorTests.lua): all
  Show/Notify summaries, color/opacity, one write/refresh per click, untracked
  promotion, current-data rebinding, and stale profile/row/popup protection.
- [Project/Tests/ItemNotificationTests.lua](../../Tests/ItemNotificationTests.lua):
  duplicate/burst delivery never escapes selected destinations; unrelated
  warning delivery stays unchanged.

Use [Project/Tests/Run-RuleTests.py](../../Tests/Run-RuleTests.py), optionally
`--item-editor-only` for focused editor runs. Check Lua 5.1 syntax, changed XML,
and whitespace. The in-game listener diagnostic isolates the new query from
real user preferences when exercising its synthetic scenarios.

### In-game acceptance (user confirmed passed on 2026-10-31)

1. Labels/details align at the normal window width. None uses existing inactive
   coloring; AutoCategory column collapses when integration is off, giving
   item names more room without misaligning Show/Notify.
2. Both popup types render correctly, labels toggle once, changes stay visible
   for a second edit, and click-away/same-control/Escape dismiss safely.
3. Filtering, scrolling, removal, importing, profile/tab switching, and hiding
   cannot leave a stale popup or write to a different target.
4. Backpack-only, bank-only, both, and neither produce the documented counts
   and zero-stock behavior, including Miscellaneous and craft-bag holdings.
5. Chat-only, HUD-only, both, and neither deliver correctly with the tracker
   hidden; overlapping groups do not duplicate a gain message.
6. Reload retains flags but not an open popup; existing profile data and
   saved expansion choices survive.

Update [UserManual.bbcode](../../../UserManual.bbcode) and the authoritative
working changelog from actual changes. These records are archived in Completed;
the acceptance checklist above records the verified scope. Follow the
[release checklist](../../Publishing/ReleaseChecklist.md) before staging;
the cumulative backward-compatible feature work warrants a minor-version
recommendation, not an automatic version change or release.

## Dependencies

Saved flag interpretation precedes count/delivery and editor writes. Presentation
and lifecycle ship together. Documentation/tests follow implementation.
AutoCategory registration, partition ownership, ordering, and optional-addon
compatibility remain governed by its separate
[plan](../Tasks/todo_plan_autocategoryIntegration.md).
