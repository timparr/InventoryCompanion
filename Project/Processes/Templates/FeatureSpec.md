# <Feature name>: feature spec

Save this document as `001 <FeatureName> - Specification.md` in
`Project\DevDocs\Features\<FeatureName>`.

Status: DRAFT - not approved
TODO item: <ID and link>
Owner: <author>
Updated: <date>
Implementation plan: <relative link>

## Overview / proposed changelog text

Make this the first section. Write user-facing update notes that explain what
changed, why it is useful, where to find new controls, and how to use the new
behavior. Existing users may read only the changelog, not the README, so include
enough practical detail for them to understand and use the feature. Keep
technical requirements below rather than maintaining a separate overview and
changelog summary.
Use normal Markdown headings, lists, and emphasis so the notes render clearly
in this document; do not wrap them in a code block. During implementation,
transfer the delivered wording into the changelog, converting it to the
changelog's BBCode format. This is draft wording, not a claim that the feature
has shipped.

- **<User-facing change>.** <Where to find it, how to use it, and the benefit.>

## Open questions

List only genuinely OPEN, unanswered questions. When a question is resolved,
incorporate the answer into the relevant document requirements and remove it
from this list. Do not retain answered questions, resolution notes, or a
question history here. Remove this section when no open questions remain.

| ID | Question | Blocking phase and why |
|---|---|---|
| Q1 | <Unanswered question> | <Spec / plan / coding / acceptance> |

Use the [feature development process](../FeatureDevelopment.md). Replace
placeholders without copying historical approvals or test results. When copied
into the feature folder, change this process link to
`../../../Processes/FeatureDevelopment.md` and set the plan link to
`002 <FeatureName> - Implementation Plan.md` in the same folder. Enclose
relative Markdown link targets containing spaces in angle brackets.

## Scope and non-goals

- In scope: <included behavior and contexts>.
- Out of scope: <explicit exclusions and deferred ideas>.

## User experience and behavior

<Observable workflows, controls/labels, defaults, examples, and wireframes.
Describe success, cancellation, empty/unavailable cases, errors, profile/context
changes, and reload behavior where relevant. Specify outcomes, not an arbitrary
internal implementation.>

## Preservation and compatibility

<Existing behavior to preserve; saved data and profile ownership; external
dependencies; legacy/downgrade impact. Any proposed schema or representation
choice remains provisional until assessed in the plan.>

## Acceptance criteria

| ID | Required observable result | Verification and environment |
|---|---|---|
| AC1 | <Measurable requirement, output shape, or threshold> | <Offline / in-game / both; what proves it> |

## Options and product decisions

| ID | Options and trade-offs | Recommendation | Agreed decision and evidence |
|---|---|---|---|
| D1 | <User impact of alternatives> | <Proposal, not agreement> | PENDING |

## Feasibility notes

<Relevant source/dependency evidence and constraints discovered during product
discussion. Link technical detail to the plan; flag effects on product choices.>

## Independent spec review

Reviewer: PENDING
Reviewed document revision/source identity: PENDING

| Finding | Evidence | Tim's decision | Resolution / re-review |
|---|---|---|---|
| <Finding or explicit no-findings result after review> | <Reference> | PENDING | PENDING |

## Approvals and acceptance

- Product discussion agreement: PENDING
- Explicit spec approval: PENDING
- Feature acceptance: PENDING
- Actual acceptance evidence and disclosed limitations: PENDING

Spec approval does not authorize coding. Record plan approval and GO to code in
the implementation plan.
