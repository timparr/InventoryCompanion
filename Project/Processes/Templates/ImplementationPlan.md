# <Feature name>: implementation plan

Status: PROVISIONAL - not approved; coding not authorized
TODO item: <ID and link>
Spec: <relative link and approved revision when available>
Owner: <author>
Updated: <date>

Use the [feature development process](../FeatureDevelopment.md). Keep this plan
aligned with the spec during discussion, but do not silently change requirements.
When copied into DevDocs/Plans, change this process link to
`../../Processes/FeatureDevelopment.md` and set the spec link to
`../FeatureSpecs/<Feature>.md`.

## Current implementation and prior art

<Verified files, methods, callers, invariants, related helpers, and relevant
historical decisions. Distinguish inspected facts from assumptions/questions.>

## Technical options and decisions

| ID | Alternatives and trade-offs | Recommendation | Agreed choice and evidence |
|---|---|---|---|
| D1 | <Feasibility, preservation, complexity, risk> | <Proposal> | PENDING |

## Data, compatibility, and failure contracts

<Representation and ownership; boundary validation; migration of all profiles;
schema/downgrade impact; internal fail-fast assumptions; external failures,
cleanup/rollback, and preservation. Mark irrelevant sections N/A with a reason.>

## Ordered implementation

### Step 1: <Outcome>

- Depends on: <Actual prerequisite, or None>.
- Spec coverage: <Acceptance criterion IDs>.
- Files/methods and affected callers: <Exact source locations>.
- Changes: <Complete behavior and wiring, including relevant UI/XML, manifest
  load order, settings, events, profiles, and integrations>.
- Preservation/error handling: <Invariants and failure behavior>.
- Verification: <Focused tests and observable expected results>.

<Repeat steps as needed in dependency order, without treating list order alone
as a dependency.>

## Verification and acceptance mapping

| Spec criterion | Implementation step | Test / command | Required evidence | Actual result |
|---|---|---|---|---|
| AC1 | <Step> | <Existing runner / new regression / in-game action> | <Expected shape, threshold, or observation> | PENDING |

<Separate offline safety checks from approved in-game tests; record required
backups, migration/downgrade checks, and what synthetic tests cannot establish.
Never use normal saved-data/inventory mutation for synthetic tests.>

## Open questions and risks

| ID | Question / risk | Blocking phase and mitigation | Resolution |
|---|---|---|---|
| Q1 | <Question, or None when resolved> | <Dependency or approval needed> | PENDING |

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
