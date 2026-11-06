# Project processes

Before starting a task, check this folder for an applicable process and follow
its discussion, review, and approval gates. If no process applies, follow
[AGENTS.md](../../AGENTS.md); do not invent additional approval gates.

| Task | Process |
|---|---|
| Select a TODO item, specify a feature/change, plan, implement, review, and accept it | [Feature development](FeatureDevelopment.md) |
| Prepare, review, test, package, publish, and close out a release | [Release](Release.md) |

Feature completion does not authorize release work. Release approval does not
approve unrelated product or implementation changes.

## Documents and templates

- [Feature-spec template](Templates/FeatureSpec.md): copy into
  [DevDocs/FeatureSpecs](../DevDocs/FeatureSpecs) as `<Feature>.md`.
- [Implementation-plan template](Templates/ImplementationPlan.md): copy into
  [DevDocs/Plans](../DevDocs/Plans) as `<Feature>ImplementationPlan.md`.
- [Release-review template](Templates/ReleaseReview.md): copy into
  [Publishing/Current release](<../Publishing/Current release>) as
  `ReleaseReview.md`, following the release process.
- [Release reviewer reference](References/ReleaseReview.md): review navigation,
  coverage, and evidence-discovery guidance.
- [ESOUI formatting reference](References/ESOUIFormatting.md): publishing text
  conventions.
- [Master TODO](../Tasks/TODO.md): active work and optional ideas.
- [Proposals](../Tasks/Proposals): unapproved design discussion.
- [DevDocs/Archive](../DevDocs/Archive): completed plans, decisions, investigations,
  and dated evidence. Historical documents are reference material, not templates
  to copy with their old approvals or test results.
- Main process checklists live together here; reusable document templates live
  in Templates, and supporting guidance lives in References.
- Scripts, publishing source documents, illustrations, working release files,
  and final ZIPs stay in [Publishing](../Publishing).

The templates use the
[item-tracker row-options spec](../DevDocs/Archive/ItemTracker/RowOptionsSpecification.md)
and [implementation record](../DevDocs/Archive/ItemTracker/RowOptionsImplementation.md)
as structural examples, not as current requirements. When copying a template,
replace all placeholders and rebase its relative links for the destination.
