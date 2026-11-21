# <Feature name>: implementation plan

Save this document as `002 <FeatureName> - Implementation Plan.md` in
`Project\DevDocs\Features\<FeatureName>`.

Status: PROVISIONAL - not approved; coding not authorized
TODO item: <ID and link>
Spec: <relative link and approved revision when available>
Owner: <author>
Updated: <date>

## Open questions

List only genuinely open, unanswered questions, including choices to be made
and matters requiring investigation. When a question is resolved, incorporate
the answer into the relevant spec or plan section and remove it from this list.
Do not retain answered questions, resolution notes, or question history here.
Remove this section when no open questions remain.

Bold the investigation and decision labels so the type of work is easy to scan.

| ID | Question | What is needed to resolve it |
|---|---|---|
| Q1 | <Unanswered question> | **Investigation** / **Behavior decision** / **Logic/data-design decision:** <Specify the evidence or choice needed, including a sequence where necessary, not the blocking phase.> |

Use the [feature development process](../FeatureDevelopment.md). Keep this plan
aligned with the spec during discussion, but do not silently change requirements.
When copied into the feature folder, change this process link to
`../../../Processes/FeatureDevelopment.md` and set the spec link to
`001 <FeatureName> - Specification.md` in the same folder. Enclose relative
Markdown link targets containing spaces in angle brackets.

The spec is authoritative for product behavior. Reference its requirements and
acceptance criteria instead of repeating settled behavior, wireframes, or product
decisions; include only the context needed to explain a technical choice.
Organize implementation into meaningful tasks based on the work: a task may
cover one requirement, several related requirements, or part of a larger one.
Record actual dependencies rather than assuming a one-to-one mapping or that
list order establishes dependencies. Keep detail proportionate to the work.

## Current implementation and prior art

<Verified files, methods, callers, invariants, related helpers, and relevant
historical decisions. Distinguish inspected facts from assumptions/questions.>

## Technical options and decisions

| ID | Alternatives and trade-offs | Recommendation | Agreed choice and evidence |
|---|---|---|---|
| D1 | <Feasibility, preservation, complexity, risk> | <Proposal> | PENDING |

## SavedVariables changes and migration

<State whether this work changes SavedVariables and whether migration or a
schema-version bump is needed, with evidence from the current and previous
supported readers. Mark the assessment PENDING until investigated; if no
change or migration is needed, say so and explain why.>

<Show a concise before-and-after structure, or the relevant proposed fields
and ownership when no equivalent structure exists. Identify added, changed,
removed, or retained data without including real user data. Mark unsettled
representation choices as provisional. Explain migration, preservation, and
downgrade protection, or link to their detailed contracts below.>

## Data, compatibility, and failure contracts

<Boundary validation; migration of all profiles; schema/downgrade safeguards;
internal fail-fast assumptions; external failures, cleanup/rollback, and
preservation. Refer to the SavedVariables section rather than repeating its
structure. Mark irrelevant sections N/A with a reason.>

## Implementation tasks

Describe the shape of the code, not actual implementation code. An outcome such
as "ensure initialization refreshes visibility" may introduce a task, but must
be followed by named methods, contracts, and caller wiring sufficient to implement
it. Use exact file paths with extensions; distinguish existing methods to modify
from proposed methods to create. Scale the detail to the change without inventing
unnecessary helpers or abstractions.

### Task 1: <Outcome>

- Depends on: <Actual prerequisite, or None>.
- Spec coverage: <Acceptance criterion IDs>.
- Files/methods and affected callers: <Exact paths including extensions; existing
  symbols and source locations; proposed new method names and ownership>.
- Changes: <Complete behavior and wiring, including relevant UI/XML, manifest
  load order, settings, events, profiles, and integrations>.
- Method contracts:
  - Create/modify `<method>` in `<path.ext>`: <Responsibility, inputs, outputs,
    state read/written, validation and failure behavior>.
  - Create/modify `<other method>` in `<path.ext>`: <Its contract and relationship
    to the first method; reuse existing helpers where applicable>.
- Caller wiring and execution order: <Name the existing/new callers, what they
  pass, which methods they call, and when. Trace relevant initialization, UI
  callbacks, events, profile changes, rendering, and exit/recovery paths; mark
  unrelated paths N/A rather than merely saying they must be handled>.
- State and data flow: <Who owns state, where values originate, how they reach
  consumers, and how persistence, cleanup or rollback occurs>.
- Preservation/error handling: <Invariants and failure behavior>.
- Verification: <Focused tests tied to named methods/contracts and observable
  expected results>.

<Repeat tasks as needed. Group related work and record real prerequisites; do
not add one task per requirement mechanically or treat list order as a dependency.>

## Verification and acceptance mapping

| Spec criterion | Implementation task | Test / command | Required evidence | Actual result |
|---|---|---|---|---|
| AC1 | <Task> | <Existing runner / new regression / in-game action> | <Expected shape, threshold, or observation> | PENDING |

<Separate offline safety checks from approved in-game tests; record required
backups, migration/downgrade checks, and what synthetic tests cannot establish.
Never use normal saved-data/inventory mutation for synthetic tests.>

## Independent plan review

Reviewer: PENDING
Reviewed plan/spec revision and source identity: PENDING

| Finding | Evidence | Tim's decision | Resolution / re-review |
|---|---|---|---|
| <Finding or explicit no-findings result after review> | <Reference> | PENDING | PENDING |

## Approvals

- Explicit spec approval and revision: PENDING
- Explicit plan approval and revision: PENDING
- Explicit GO to code: PENDING

## Implementation record and deviations

<Record actual files/methods changed, decisions, deviations, and approval evidence
as work happens. Changes to approved behavior/design return to the process gates.>

## Independent code review and verification

- Reviewer and reviewed diff/source identity: PENDING
- Findings, agreed corrections, and re-review: PENDING
- Actual test results and retained evidence: PENDING
- Unavailable checks and remaining limitations: PENDING

## Acceptance and handoff

- Approved in-game test scope: PENDING
- Actual Tim-reported results: PENDING
- Explicit feature acceptance: PENDING
- Current spec, user docs, TODO, completed-work index, and archive links updated: PENDING
- Commit/merge authorization and outcome: PENDING
- Release: separate process; not authorized by feature acceptance.
