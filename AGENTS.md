# Project Instructions

## Fail Hard, Fail Fast - All Work

- Do not guard addon-owned functions or required internal state that should exist. Call/use them directly so defects we can fix throw errors as close to the root cause as possible.
- Do not hide broken internal assumptions with nil checks, silent early returns, fallback values/tables, or catches that continue as though the operation succeeded. Validate internal API contracts at entry when useful and throw on violations.
- Defensive guarding starts at the boundary between our maintained code and externally controlled code/data: ZOS APIs, dependent addons/libraries, and other external inputs. ZOS is an example, not the only permitted boundary; this is not permission to guard our own required functions or state.
- Treat our own saved data as externally controlled input because users can modify it outside the addon. Validate/normalize it at the loading/import boundary, preserve unrelated data, and report malformed values rather than silently concealing them. Missing optional fields may inherit documented defaults; recognized legacy data may follow explicit migration rules.
- After boundary validation, maintained internal code must rely on its established contracts and fail near the root cause when they are violated, rather than repeatedly guarding against defects we can fix.
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
