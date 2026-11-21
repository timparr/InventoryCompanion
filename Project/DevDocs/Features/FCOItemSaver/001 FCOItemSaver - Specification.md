# FCO ItemSaver diagnostic spike: feature spec

Status: APPROVED for temporary diagnostic implementation; in-game acceptance pending
TODO item: None; user-requested feasibility spike, not the MVP feature
Owner: Copilot
Updated: 2026-11-20
Implementation plan: [diagnostic spike plan](<002 FCOItemSaver - Implementation Plan.md>)

## Overview / proposed changelog text

- **DEV-only FCO diagnostics.** A temporary diagnostic command would inspect one
  FCO marker in the backpack, compare scan timings and observe slot events while
  the user manually changes a marker. It investigates the proposed integration;
  it does not add FCO conditions to IC groups.

This is draft wording; no released feature is claimed.

## Open questions

| ID | Question | Blocking phase and why |
|---|---|---|
| Q1 | Does FCO produce an observable slot event for a manual marker change in the installed game and addon configuration? | Investigation; requires the spike and in-game evidence. |
| Q2 | What performance limit should the eventual MVP meet? | MVP acceptance; this spike records measurements without choosing a limit. |

## Scope and non-goals

- In scope: a read-only, DEV-only diagnostic for one marker and backpack slots;
  bounded event observation; a synthetic candidate count aggregation and
  synthetic timing exercise; offline validation of diagnostic behaviour.
- Out of scope: actual IC marker groups, new saved settings, FCO marker changes
  by IC, inventory movement, bank scans, notifications, AutoCategory changes,
  release work and claims of MVP acceptance.

## User experience and behavior

- `/icfcotest scan [markerId]` proposes a backpack scan, using FCO's guild-store
  marker when omitted. Show the marker ID, occupied-slot and matched-slot
  counts, matched quantity and item links/counts, plus separate baseline and
  FCO-query timing over ten iterations on the same captured slots.
  Timings use `GetGameTimeMilliseconds()` and are observations, not pass/fail;
  zero milliseconds means below the clock's resolution, not zero cost.
- `/icfcotest watch [markerId]` captures a marker snapshot and starts observing
  backpack slot-update events. The user manually changes one marker without
  moving the item, then `/icfcotest stop` reports event count and affected
  slots and compares the before/after marker state. Report no net marker change
  as inconclusive, not proof of no events. Repeated start is rejected; stop
  unregisters observation. Reload also ends it. No marker polling is required.
  A moved or replaced item, or an item without a usable unique ID, is reported
  as inconclusive for that slot rather than as a marker change.
- `/icfcotest synthetic` runs an isolated prototype with marked and unmarked
  synthetic slots sharing an item ID, and a bounded synthetic timing workload.
  Label its result as prototype evidence, not proof the existing tracker works.
- Invalid or FCO-disabled marker, invalid command, missing or unready FCO, unsupported gamepad mode,
  absent marker-query result and event-observer misuse produce explicit
  diagnostic messages. No API call is made in unsupported gamepad mode.
- Event counts are correlation evidence only: unrelated inventory activity can
  produce events and absence of events in one run does not prove all FCO
  marking paths behave alike.

## Preservation and compatibility

The diagnostic reads live backpack state but does not intentionally write IC or
FCO SavedVariables, set markers, modify inventory or change existing group
matching. The user may manually change markers for observation and should
restore them. It is registered only in DEV and must not require FCO to load IC.
External FCO API failures must be surfaced, not silently reported as unmarked.
FCO's query can change its own transient state; the diagnostic checks that its
settings are already available before calling it. No saved-data schema change
is proposed. The temporary runtime file, manifest entry and its offline test
harness wiring must be removed or deliberately redesigned before any release:
release packaging otherwise includes manifest files even when their commands
are DEV-gated.

## Acceptance criteria

| ID | Required observable result | Verification and environment |
|---|---|---|
| AC1 | Scan reports slot/quantity results and separate baseline/query timings for the selected marker; no match is explicit. | Offline stubbed tests; approved in-game check with FCO. |
| AC2 | Watch/stop reports before/after changes and backpack event evidence, unregistering on stop; invalid lifecycle actions are reported. | Offline event stubs; approved in-game manual marking. |
| AC3 | Synthetic prototype reports marked count separately from all copies sharing an item ID; timing is labelled diagnostic. | Offline tests and in-game diagnostic. |
| AC4 | Missing/unready FCO, invalid inputs, unsupported mode and nil query results are explicit; no live inventory or saved data is mutated by the diagnostic. | Offline tests; inspect runtime paths; approved in-game checks where applicable. |
| AC5 | Existing behaviour and release command surface remain unchanged; no schema migration is introduced. | Offline runner, manifest/load-order review and release-mode stub. |

## Options and product decisions

| ID | Options and trade-offs | Recommendation | Agreed decision and evidence |
|---|---|---|---|
| D1 | Standalone command vs extending `/ictest`: interactive observation needs a start/stop lifecycle. | Separate DEV-only `/icfcotest`. | PENDING |
| D2 | Synthetic aggregation before feature implementation cannot test IC's real tracker. | Prototype only, explicitly labelled; real group regression waits for implementation. | PENDING |

## Feasibility notes

FCO exposes `FCOIS.IsMarked`; its API documents gamepad limitations. IC scans
slots but aggregates tracker records by item ID. The existing synthetic
[rule tests](../../../../Core/RuleTests.lua) and read-only performance tests in
[Tests.lua](../../../../Core/Tests.lua) are prior art. See the
[spike report](<003 FCOItemSaver - Spike Report.md>).

## Independent spec review

Reviewer: independent `rubber-duck` agent, `spike-spec-review`
Reviewed document identity before clarification: Git blob `1d51c14b9c3b698ef09fe12a1a6d6054309e1980`;
provisional plan blob `618fd4d553dcf7eb0310f9d244538fecdab30bb8`.

| Finding | Evidence | Tim's decision | Resolution / re-review |
|---|---|---|---|
| Release packaging includes manifest files even when their command is DEV-gated. | `Project/Publishing/PackageRelease.ps1` manifest handling | Temporary branch-only diagnostic. | Remove file and manifest entry before release; focused review found approach workable. |
| Define how FCO readiness and `IsMarked` return shapes distinguish failure from an unmarked item. | Installed `FCOIS_API.lua`, `IsMarked` | Use explicit checks. | Detailed in plan; focused reviews resolved return, disabled marker and missing storage cases. |
| Specify and test the exact gamepad/ADCUI safety checks. | Installed `FCOIS_API.lua`, API limitations | Use explicit checks. | Detailed in plan; focused review verified gate. |
| Define scan iteration counts, manual evidence procedure, watcher edge cases and offline harness wiring. | Spec/plan wording | Clarify without expanding scope. | Updated here and in plan; plan review led to unique-ID and marker-range checks. |

## Approvals and acceptance

- Product discussion agreement: user requested a temporary branch-only spike.
- Explicit spec approval: user stated "ok I'm approveing both"; subsequent
  focused reviews resolved the documented technical findings.
- Feature acceptance: PENDING
- Actual acceptance evidence and disclosed limitations: PENDING

Spec approval does not authorize coding; plan approval and a separate GO are
recorded in the implementation plan.
