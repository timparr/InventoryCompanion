# FCO ItemSaver Integration: In-game MVP Test Checklist

**Status:** MVP checklist remains draft; preliminary diagnostic observations
are recorded below. The actual marker-based IC group has not been implemented.

**Scope:** one IC group with a single FCO marker condition, for example
**Sell at Guild Store**. No combined name condition, multiple markers,
marker-writing from IC or marker-driven transfers are assumed. Supported
locations, refresh timing, unavailable-addon behaviour and performance limits
still need agreement.

See the [feasibility report](FCOItemSaverIntegrationSpike.md) for context and
open design decisions.

## Preliminary diagnostic spike

Before implementing marker-based groups, investigate the uncertain parts with
the proposed [diagnostic spike spec](../../DevDocs/FeatureSpecs/FCOItemSaverDiagnosticSpikeFeatureSpec.md)
and [implementation plan](../../DevDocs/Plans/FCOItemSaverDiagnosticSpikeImplementationPlan.md):

- [x] Query the real FCO marker for occupied backpack slots and report matching
  counts and timings without changing items or markers.
- [x] Observe inventory slot events while the user changes a marker manually,
  comparing marker snapshots before and after the observation.
- [ ] Exercise an isolated candidate aggregation with synthetic marked and
  unmarked slots sharing an item ID; distinguish this from a test of the
  existing IC tracker, which does not yet support marker groups.
- [ ] Compare baseline and marker-query timings on identical backpack data,
  and measure a safe synthetic scan/burst. Record measurements, not an
  unagreed performance pass/fail.

The spike does not implement the MVP group. The user ran the synthetic command
but its output was not captured, so the synthetic in-game result remains
pending. The remaining group checks below require implementation and approved
testing.

**Observed on 20 November 2026:** the initial backpack scan showed no matching
slots; ten FCO-query passes took 22 ms, while baseline iteration measured 0 ms.
One marker changed from false to true at slot 57, with zero observed backpack
slot events. This was detected by the stop snapshot, not automatically. The
occupied-slot count and synthetic output were not visible in the supplied
screenshot. See the [report](FCOItemSaverIntegrationSpike.md) for limitations.

### Diagnostic commands

The temporary DEV-branch diagnostics are implemented and partly exercised.
Follow the backup and deployment safeguards below before further testing, and
enable FCO in a supported mode. Results currently appear in chat, not a
copyable error report.

1. Run `/icfcotest scan` for the guild-store marker, or
   `/icfcotest scan <markerId>` for another enabled FCO marker. Record the
   marked slot and quantity results and the two ten-pass timings. The baseline
   measures iteration over captured slots; the other timing measures FCO
   queries over those same slots, not a complete tracker refresh.
2. Run `/icfcotest watch`, manually change the selected marker on one backpack
   item without moving it, then run `/icfcotest stop`. Record the candidate
   marker change and slot-event count. A missing net change, moved/replaced
   item or changed stack is inconclusive; an event is correlation, not proof
   that FCO caused it. Use `watch <markerId>` for a different marker.
3. Run `/icfcotest synthetic` to check the isolated mixed-copy candidate and
   report synthetic timings. This is not a test of the actual IC tracker.
4. Restore the original marker after observation. A watch remains active until
   `stop` or UI reload; the stop command unregisters its event listener even
   if the final query fails.

## Setup and correctness

- [ ] Follow the applicable backup and test-deployment safeguards before
  testing. If the schema changes, include the required actual older-schema
  backup and migration UAT; do not substitute a synthetic migration test.
- [ ] With FCO enabled in a supported mode, create one IC group using the
  chosen marker. Record the test items, quantities, locations and original FCO
  markings so any intentional test changes can be restored.
- [ ] Mark one suitable backpack item in FCO. Confirm the group displays it
  with the correct count. Confirm an unmarked item and an item marked only with
  a different FCO marker do not enter the group.
- [ ] Where FCO's configured identity mode permits, use two copies of the same
  item ID with only one marked. Confirm the group counts only the marked copy,
  while ordinary IC counts for that item remain correct. Record the FCO identity
  mode and any case that cannot be constructed.
- [ ] Add and remove the marker without moving the item. Confirm the group
  updates after the agreed scene transition and counts remain correct. Record
  whether refresh was automatic or required a manual action.
- [ ] With the proposed noisy test group, verify its agreed tracker display and
  chat/HUD notification settings. Confirm return to the main scene causes a
  refresh after a marker-only change, without relying on a slot-update event.
- [ ] Exercise each agreed MVP location, including backpack and bank if both
  are supported. Verify location-specific and combined counts as applicable.
  Check ordinary stack changes and moving a marked item between supported
  locations; record FCO's observed marker behaviour. Verify bank contents are
  available at the chosen scene-transition refresh point.
- [ ] Reload the UI and confirm the group definition, marker selection and
  displayed results persist. Confirm an existing name-only group still behaves
  as before.
- [ ] Disable or make FCO unavailable using the agreed test procedure; confirm
  the agreed visible unavailable state and preservation of the IC group.
  Re-enable FCO and confirm the group resumes working.
- [ ] If notifications or AutoCategory reuse are included in the agreed MVP,
  verify the same single-marker group in those consumers, including correct
  counts and refresh. Otherwise record them as out of scope.

## Performance and evidence

- [ ] With a representative inventory and the same addon configuration,
  compare a baseline without the FCO group against the single-marker group.
  Record inventory size, test actions, refresh timings or other available
  measurements, and any visible stutter. Repeat the same actions for both.
- [ ] Exercise a representative inventory-update burst and repeated marker
  changes; record responsiveness and errors. Synthetic burst checks must not
  mutate live inventory or saved variables. Manual marking is a deliberate test
  change, not a synthetic workload.
- [ ] Agree the measurable performance limit and how to measure it before
  acceptance. Record the actual measurements and environment; do not mark
  performance as passing solely because it feels responsive.
- [ ] Record results, errors and unavailable cases. Restore intentional test
  marker changes and follow the applicable SavedVariables recovery procedure
  if a rollback is needed.
