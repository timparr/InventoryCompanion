# Hotfix Release Waiver

Status: [Hotfix Waiver - Authorized]
Waiver authorized by: @Tim-P
Waiver authorized (UTC): <YYYY-MM-DDTHH:mm:ssZ>
Release version: <agreed major.minor.patch version>
Hotfix reason: <brief user-facing reason and why this is a hotfix>
Source identity: <DEV commit and any uncommitted source changes>
Full standards review: SKIPPED
Waiver scope: Skip the full release standards review for this hotfix only.
Candidate SHA256: <filled after staging>
Focused synthetic tests: <x>/<y> passed
DEV diagnostic: <x>/<y> passed; runtime version=<release version>
DEV diagnostic evidence: <repository path to retained diagnostic output>
UAT runtime identity: <SHA256 of the DEV runtime files used for UAT>
DEV UAT report: <actual user-reported result from DEV testing>
Package verification: PENDING (Finalize has not run)
Publication approval: NOT GRANTED

## What this waiver means

The author explicitly authorized skipping the full release standards review for
this hotfix. No full code, standards, or documentation review is claimed by this
record. Focused synthetic tests and UAT performed in DEV must identify the
release runtime version and evidence. The staging process then verifies the
candidate identity and package contents, and Finalize verifies the archive hash.
The final author approval of the exact package remains required. This waiver
does not authorize staging, ESOUI upload, or GitHub publication by itself.

DEV UAT is acceptable only when the package is a direct runtime-file port of
the tested DEV version. Any runtime code changes after UAT require repeating
the relevant tests and updating this record.

## Final package

Finalize records package verification in this document. The final ZIP SHA-256 is
provided separately with the final package approval because embedding a ZIP's
own hash inside that ZIP would be self-referential.
