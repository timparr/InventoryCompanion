# ESOUI Release Standards Review

Complete this review for the exact frozen release candidate described below, not for a changing development checkout. Save the completed review as `ReleaseReview.md` in the development root. Treat the timestamp as an audit record, not a freshness gate. Do not approve while a mandatory requirement, required test, or material compliance question remains unresolved.

Reviewed (UTC): <YYYY-MM-DDTHH:mm:ssZ>
Reviewer: <AI assistant and model name, if available; do not guess>
Checked by: <human author/checker>
Release version: <manifest version>
Candidate SHA256: <candidate identity>
Review status: <PENDING or APPROVED>

## Release process

Describe how the intended release files were copied, extracted into a clean staging installation, staged, and frozen before review. State the staging location or other identifying details as appropriate. Confirm that the version and candidate hash above identify those frozen files, and that review findings and test results below apply to this candidate. Do not describe the changing development checkout as the reviewed release.

-- Example --
## Release process

A copy of the intended release files was extracted into a clean staging installation, staged, and frozen as the review candidate. Its version and SHA-256 identity are recorded above. The review and release tests apply to that frozen copy; the candidate is not changed during review.

Only after the files were frozen were they assessed against ESOUI's mandatory upload rules and prohibited-functionality requirements, together with its release best-practice guidance:

- Mandatory upload rules: https://www.esoui.com/forums/showthread.php?t=11
- Mandatory prohibited-functionality requirements: https://www.esoui.com/forums/showthread.php?t=9865
- Release best practices: https://www.esoui.com/forums/showthread.php?t=10790
-- /Example --

<Record the actual release process and candidate identity.>

## Guidance reviewed

After freezing the candidate, review it against the current ESOUI mandatory rules and best-practice guidance. Record which guidance was checked, when it was checked, and any source that could not be accessed. A failed or blocked fetch is unresolved, not evidence that the guidance is unchanged.

- Mandatory upload rules: https://www.esoui.com/forums/showthread.php?t=11
- Mandatory prohibited-functionality requirements: https://www.esoui.com/forums/showthread.php?t=9865
- Release best practices: https://www.esoui.com/forums/showthread.php?t=10790
- Relevant linked guidance (manifest, events, saved variables, API versions, dependency versions, removal criteria, or other applicable topics): <links and review status>

<Record currentness, findings, and any inaccessible guidance or staff clarification.>

## Findings against the guidance

<<list of headings for the guidance. Review the code to determine if it meets each of these>>
<<Mandatory guidance>>

### Release package

Record the exact package-content verification. Confirm the expected top-level layout and runtime files, and check that SavedVariables, generated API files, editor configuration, backups, unrelated documents, and other prohibited or unintended files are absent.

<Status and findings>

## Overall code quality

Summarize the release code's correctness, maintainability, and performance-relevant design. Identify material defects or limitations found; distinguish reviewed evidence from guarantees. Do not claim the release is bug-free.

<Overall assessment and any issues>

## User testing and performance

Record who tested the frozen candidate, when, the tested setup and dependency versions, and the actual results. Include passed/failed counts and relevant functional scenarios. For performance tests, record workload, measurements, limits, and whether the test is synthetic/read-only or affects live state. Do not claim tests were run without reported results; disclose incomplete output or untested scenarios.

<User-test results and evidence>

<Performance measurements, workloads, and limits>

## Review conclusion

Summarize whether the frozen release meets the mandatory rules and applicable best practices. List unresolved requirements or required follow-up. Approve only when required checks and human confirmations are complete.

<Conclusion and approval rationale>
