# Project Instructions

## Processes

- Before starting any task, check [Project/Processes](Project/Processes/README.md) for an applicable process and follow its discussion, independent-review, and approval gates. Use [FeatureDevelopment.md](Project/Processes/FeatureDevelopment.md) for specification, planning, implementation, and acceptance; use [Release.md](Project/Processes/Release.md) for releases. If no process applies, follow these project rules.

## Fail Hard, Fail Fast - All Work

- Do not guard addon-owned functions or required internal state that should exist. Call/use them directly so defects we can fix throw errors as close to the root cause as possible.
- Do not hide broken internal assumptions with nil checks, silent early returns, fallback values/tables, or catches that continue as though the operation succeeded. Validate internal API contracts at entry when useful and throw on violations.
- Defensive guarding starts at the boundary between our maintained code and externally controlled code/data: ZOS APIs, dependent addons/libraries, and other external inputs. ZOS is an example, not the only permitted boundary; this is not permission to guard our own required functions or state.
- Treat our own saved data as externally controlled input because users can modify it outside the addon. Validate/normalize it at the loading/import boundary, preserve unrelated data, and report malformed values rather than silently concealing them. Missing optional fields may inherit documented defaults; recognized legacy data may follow explicit migration rules.
- Increment the saved-variable schema version whenever older builds cannot safely read or preserve new saved data, even for additive fields. Validate every profile and migrate non-destructively before ZOS constructors; test that older supported builds reject the newer version without changing data. DEV and release share saved variables, so downgrade protection is required before testing on normal game data.
- When the saved-variable schema version changes from the previous release, UAT must exercise migration using an actual older-schema SavedVariables backup. Follow the release checklist's backup, logout, restore, verification, and recovery safeguards; synthetic migration tests alone are insufficient.
- After boundary validation, maintained internal code must rely on its established contracts and fail near the root cause when they are violated, rather than repeatedly guarding against defects we can fix.
- Apply this rule to every implementation, refactor, bug fix, and review.

## Instruction Maintenance

- Keep this file concise; move context-specific guidance into scoped instruction files when it grows enough to justify the extra files.
- Decide when accumulated preferences warrant scoped instruction files; keep a concise pointer here stating when each specialized file applies.
- Prefer conversational discussion, including release-test evidence and confirmations. The user does not want question panels or structured forms; keep requests in the conversation.
- For ESO addon load ordering and AutoCategory integration, start with the [master feature specification](Project/DevDocs/FeatureSpecs/AutoCategoryIntegration.md), which consolidates final behavior and links archived plans and spike/dependency contracts; consult those contracts before repeating research.

## Git Workflow

- For any release request, do not inspect or change files yet. First give the user a brief outline of the release steps and ask conversationally for approval to begin; then stop and wait. Follow the release checklist's later approval gates as well.
- At the start of each release, update the authoritative working changelog from the actual changes first, then use it to recommend a build/patch or minor version increment (major only for incompatible changes), with a brief reason and proposed version, before staging. Follow `Project/Processes/Release.md` for numbering and release steps.
- Before recommending a release version, verify the current DEV manifest/runtime version and the staging script. The Stage tool packages the version in the DEV manifest verbatim, then advances DEV to the next patch; under this workflow, do not recommend a candidate below the current DEV version. If a higher version is agreed, keep manifest `Version`, `AddOnVersion`, and `Core/Init.lua` synchronized before staging.
- Keep the latest unpublished changelog heading tagged `[current version]`; at the next release review, ask whether that version was actually released and remove the marker only if the author confirms publication.
- In release reviews, mark not-yet-testable or not-yet-decided items (including UAT, candidate/package checks before staging, and an unagreed release version) `PENDING`; do not label them `FAIL` or report results before the relevant gate. Use `FAIL` only for an assessed criterion that actually failed.
- Set the review's top-level `Status` to `[Approved to Test]` only when no checks failed or remain unresolved and every item in Pending items explicitly requires test deployment for assessment. Otherwise leave it `[Not Approved]`. After test deployment, set it to `[Approved for Release]` only when every check passes, no finding remains unresolved, and Pending items is `- None.`. These statuses do not replace the separate GO approvals for staging or UAT.
- Preserve prefilled review-template results, especially author certifications such as `Certified by @Tim-P`; do not replace, reinterpret, or clear them when populating a report. Update only fields intentionally left blank or explicitly authorized for revision.
- Keep the review Summary concise. In the review's Pending items subsection adjacent to Findings, list only review-form criteria whose result is `PENDING`. Do not list tests, metrics, or process steps/approvals as standalone items; they may be mentioned only as the missing evidence explaining why a review criterion is pending. Remove a criterion when its form result is resolved.
- Before recommending a separate branch for substantial or risky work, check the current branch. If already on a feature branch for that work, continue there; do not suggest another branch merely because the work is substantial. Otherwise, warn the user when a separate branch is advisable and explain why.
- Do not switch branches without the user's approval.
- Keep the initial unit-test work on `main`; reconsider using a branch if testing requires substantial changes to the existing system.
- Prioritize in-game tests for rule matching and overrides, plus safe synthetic inventory-burst performance checks that never mutate live inventory or saved variables.
