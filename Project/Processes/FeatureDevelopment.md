# Feature development process

Use this process when selecting and specifying TODO work, planning a feature or
behavior change, implementing it, reviewing the code, and obtaining acceptance.
The same gates apply to fixes or refactors needing product/design decisions.
An already-approved spec or plan can be reused only after checking that it
covers the requested work and current implementation; do not repeat settled
discussion without a reason. Small, fully specified fixes need proportionate
documents and review, not unnecessary planning machinery.

Follow [project rules](../../AGENTS.md). Discuss decisions with Tim; do not treat
silence, a draft, a review finding, or a passed test as approval. Keep product
decisions in the spec and technical sequencing in the plan. Reading source and
recording feasibility are allowed during planning; coding is a separate gate.

## 1. Select and frame the work

1. Agree the item from the [master TODO](../Tasks/TODO.md), its problem, intended
   outcome, scope, and non-goals with Tim. Do not silently select adjacent work.
2. Inspect current behavior and relevant authoritative specs and archived
   decisions. Check the current branch before recommending a separate branch;
   do not switch without approval.
3. Create a linked spec and provisional implementation plan using the
   [spec](Templates/FeatureSpec.md) and
   [plan](Templates/ImplementationPlan.md) templates. Record the TODO identity,
   document status, and open questions. Leave approvals and unperformed tests
   pending; do not carry historical results forward as fresh evidence.

## 2. Specify and discuss the product

1. Describe the problem, users' observable behavior, UX, defaults, boundaries,
   preservation/compatibility requirements, non-goals, and measurable acceptance
   criteria. Include examples and wireframes where helpful.
2. Present genuine alternatives and their user impact to Tim. Distinguish
   recommendations from agreed decisions. Some implementation details will arise:
   use them to explain feasibility and risk, not to choose behavior implicitly.
3. Work through open questions. Update the spec's decision register and the
   provisional plan together as choices settle. Do not expand scope silently.
4. Once Tim agrees the proposed behavior and blocking product questions are
   resolved, request an independent spec review.

### Independent spec review and approval

- Use a different agent from the authoring agent, not a self-review. Give it the
  current spec, provisional plan, relevant source/context, and a bounded,
  read-only objective. Identify the reviewer and the document revision/commit
  reviewed. Review does not authorize edits or implementation.
- Assess clarity, consistency, completeness, user-visible edge cases,
  compatibility, scope, feasibility, and whether acceptance criteria are
  measurable. Separate confirmed defects, questions, and optional suggestions.
- Present findings to Tim before changing agreed behavior. Record decisions,
  revise both documents as needed, and repeat focused independent review of
  revisions affecting the assessed requirements.
- Obtain explicit spec approval with no unresolved blocking findings or product
  questions. Plan drafting may continue; spec approval alone does not authorize
  coding.

## 3. Develop and discuss the implementation plan

1. Inspect actual code and prior art. Identify affected files, methods, callers,
   UI/XML, manifest load order, external integrations, and saved-data boundaries.
2. Plan implementation in dependency order with expected results per step.
   Specify representation, validation, migration/downgrade protection, error
   handling, preservation, cleanup/rollback, and verification where applicable.
3. Map every spec acceptance criterion to implementation and tests. Record what
   offline tests can prove and what requires Tim's in-game observations.
4. Discuss technical options, risks, and open questions with Tim. Keep proposals
   separate from decisions. If feasibility requires a product change, return to
   spec discussion and review before finalizing the plan.

### Independent plan review and approval to code

- Use a different agent from the plan author, with the approved spec, current
  plan, and relevant source. The reviewer may have reviewed the spec, but must
  not have authored the plan it now reviews.
- Assess spec coverage, correctness of source assumptions, sequencing,
  integration surfaces, saved-data safety, fail-fast contracts, maintainability,
  and adequacy of the verification strategy. Do not substitute product redesign
  for assessment of the agreed requirements.
- Discuss findings with Tim, resolve blocking questions, update documents, and
  repeat focused independent review when relevant changes are made.
- Record explicit plan approval and a separate explicit GO to code. Do not infer
  either from spec approval or a favorable review.

## 4. Implement and verify

1. Implement the approved plan in coherent steps, preserving existing behavior
   outside scope. Add directly related regression tests and documentation.
2. Record actual changes, decisions, deviations, and test evidence in the plan.
   Stop for discussion if discoveries change approved scope, behavior, data
   contracts, or design. Revisit the affected spec/plan and review gates.
3. Run focused existing validation commands. Follow the saved-schema migration
   and actual older-build downgrade safeguards before normal saved-data testing.
   Never use live inventory or saved-variable mutation as a synthetic test.
4. Keep unperformed checks pending and failed checks explicit. Offline success
   does not prove UI rendering, event delivery, or real transfer behavior.

## 5. Independently review the code

- Give a different agent from the implementer the approved spec/plan, exact diff
  or source identity, relevant callers, and actual test evidence.
- Review implementation against requirements and project rules, including
  behavior preservation, internal/external boundaries, migration, lifecycle,
  performance, and all relevant UX surfaces. Tests support review; they do not
  replace source inspection.
- Present findings to Tim and agree corrections. Make only authorized changes,
  run focused tests, and independently re-review material corrections. Product
  or design changes return to their earlier approval gates.
- An exploitable-vulnerability review follows the dedicated security-review
  workflow; ordinary code review is not a substitute for it.

## 6. Accept and close the feature

1. Obtain Tim's approval for the agreed in-game acceptance checks, after required
   backups and offline safety checks. Record actual results, unavailable cases,
   limitations, and observations against the spec's acceptance criteria.
2. Failures or unexpected behavior return to discussion and the affected
   implementation/review gates. Do not claim acceptance from silence.
3. Obtain explicit feature acceptance. Update the current spec to reflect
   delivered behavior, preserving the decision trail. Archive the completed
   plan under `Project\DevDocs\Archive\<Feature>` and update inbound links, the
   [completed-work index](../DevDocs/Archive/CompletedWork.md), and TODO status.
4. Retain actual diagnostic output under [Tests/Evidence](../Tests/Evidence).
   Mark retained plans and dated results historical, not current instructions.
   Commit/merge only within the user's authorization; do not switch branches,
   push, publish, or change release versions merely because a feature is done.
5. A release request follows the separate [release process](Release.md).
