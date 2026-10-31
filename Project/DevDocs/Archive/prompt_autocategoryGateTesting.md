# Prompt: continue AutoCategory integration gate testing

**ARCHIVED 2026-10-31. Historical prompt, not current instructions.**
Use the three authoritative documents linked below; do not execute this prompt
as a separate source of feature requirements or workflow permissions.

Read [AGENTS.md](../../../AGENTS.md), then the three authoritative documents:

1. [SPEC](../Tasks/todo_plan_autocategoryIntegration.md): required behavior and explicit
   Q1-Q5 / D1-D3 open-question and decision register.
2. [IMPLEMENTATION PLAN](../Tasks/todo_implementation_autocategoryIntegration.md):
   dependencies and stage 1 ordering blockers; no runtime/editor implementation
   is authorized by this testing prompt.
3. [SPIKE RESULTS](../Tasks/AutoCategorySpikeResults.md): current gates, dated evidence,
   failed approaches, dependency contracts, commands and pending housekeeping.

Continue only nondeferred probes agreed with the user. Guild Bank is deferred
to later DEV testing, not passed. Do not repeat completed lifecycle/context
tests or ask baseline load-order questions already answered by the results.
Top placement and crowded/arbitrary-label order remain Q1/Q2 blockers.

Stay on the current branch. Do not edit installed AutoCategory source, move
items, change IC saved variables, convert icons or build integration/settings UI.
Reuse the DEV slash probe; validate code changes offline before asking the user
to run them. Give one explicit command with a short `<item>` placeholder,
wait for results, and use ESO's copyable diagnostic window, not chat-only output.
Respect the exact tagged-assignment authorization and cleanup boundaries in the
results document; request permission for any additional persistent mutation.

Record dated command/results and offline-vs-ESO limits in SPIKE RESULTS.
Update SPEC decisions and IMPLEMENTATION PLAN dependencies when evidence changes
them; do not duplicate the full log or infer passes from unavailable contexts.
Finish pending Debug Key/report housekeeping when the test phase ends.
