# Project Instructions

## Instruction Maintenance

- Keep this file concise; move context-specific guidance into scoped instruction files when it grows enough to justify the extra files.
- Decide when accumulated preferences warrant scoped instruction files; keep a concise pointer here stating when each specialized file applies.

## Git Workflow

- Warn the user before starting substantial or risky work that would be advisable to do on a separate branch, and explain why.
- Do not switch branches without the user's approval.
- Keep the initial unit-test work on `main`; reconsider using a branch if testing requires substantial changes to the existing system.
- Prioritize in-game tests for rule matching and overrides, plus safe synthetic inventory-burst performance checks that never mutate live inventory or saved variables.
