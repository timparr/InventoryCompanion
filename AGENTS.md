# Project Instructions

## Fail Hard, Fail Fast - All Work

- Do not guard addon-owned functions or required internal state that should exist. Call/use them directly so defects we can fix throw errors as close to the root cause as possible.
- Do not hide broken internal assumptions with nil checks, silent early returns, fallback values/tables, or catches that continue as though the operation succeeded. Validate internal API contracts at entry when useful and throw on violations.
- Availability checks for external ZOS APIs are allowed (for example, checking whether a ZOS function is nil before calling it); this is not permission to guard our own functions.
- Missing optional saved fields may inherit documented defaults, and recognized legacy data may follow explicit migration rules. Do not infer a blanket saved-data exception or generalize scoped recovery rules; any other exception must be explicitly agreed and documented.
- Apply this rule to every implementation, refactor, bug fix, and review.

## Instruction Maintenance

- Keep this file concise; move context-specific guidance into scoped instruction files when it grows enough to justify the extra files.
- Decide when accumulated preferences warrant scoped instruction files; keep a concise pointer here stating when each specialized file applies.
- Prefer conversational discussion during planning. Use structured question forms only when implementation is underway and a quick, specific decision is needed.

## Git Workflow

- Warn the user before starting substantial or risky work that would be advisable to do on a separate branch, and explain why.
- Do not switch branches without the user's approval.
- Keep the initial unit-test work on `main`; reconsider using a branch if testing requires substantial changes to the existing system.
- Prioritize in-game tests for rule matching and overrides, plus safe synthetic inventory-burst performance checks that never mutate live inventory or saved variables.
