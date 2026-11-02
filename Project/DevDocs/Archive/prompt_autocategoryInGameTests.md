# AutoCategory in-game gate tests

**ARCHIVED 2026-10-31. Historical request, not current instructions.**
Current requirements, sequencing and evidence live only in the
[SPEC](../Tasks/todo_plan_autocategoryIntegration.md),
[IMPLEMENTATION PLAN](../Tasks/todo_implementation_autocategoryIntegration.md)
and [SPIKE RESULTS](../Tasks/AutoCategorySpikeResults.md).
The original request below is retained as history; its duplicated logging
instructions and remaining-gate assumptions are superseded.

Read [AGENTS.md](../../../AGENTS.md), the
[AutoCategory integration gate plan](../Tasks/todo_implementation_autocategoryIntegration.md),
and the existing [DEV slash-command probe](../../Tests/AutoCategorySpikeRuntime.lua).
Reuse that probe where possible. Add only the minimal DEV-only slash commands
needed to answer these remaining in-game questions:

1. Does an inline texture render correctly in an AutoCategory heading while
   preserving the category's identity and usability?
2. Can many managed groups sit above AutoCategory's existing categories, or fit
   between them using fractional priorities, with the intended classification
   and visible heading order? Verify ESO's fractional formatter and priorities
   above 1000; formatting success alone is not proof of heading order.
3. Can a name collision be detected before registration without AutoCategory
   renaming an existing rule or redirecting an existing assignment?
4. Do plugin registration and category assignments work after `/reloadui`,
   without duplicates or missing definitions?
5. Does classification and native list rendering work in all seven contexts:
   Backpack, Bank (including subscriber bank), Guild Bank, House Bank, Crafting
   Station, Craft Bag, and Furniture Vault?
6. Does switching AutoCategory between account-wide and character-specific
   profiles reproject to the active profile without changing the inactive one?

Validate the commands offline before asking me to use them. Then walk me through
testing one command at a time, wait for my results, and record which questions
are answered and which remain open. Reports must use ESO's copyable diagnostic
window, not chat-only output. Note unavailable contexts rather than claiming
they passed.

Keep probes reversible. Never move items, modify Inventory Companion saved
variables, or edit AutoCategory's installed source or existing categories.
I authorize temporary, uniquely tagged AutoCategory test entries in both
profiles only where needed for reload/profile tests. Provide a cleanup command
that removes only those entries. Keep projection writes confined to the active
profile and verify the inactive profile stays unchanged.

Stay on the current branch. Do not implement the integration, convert icons,
build editor/settings UI, or make unrelated changes. Build the test commands,
guide the tests, and report the answers. Nothing more.

After each test, update both the
[implementation plan](../Tasks/todo_implementation_autocategoryIntegration.md) and
[feature spec](../Tasks/todo_plan_autocategoryIntegration.md) with dated evidence:
the command and result, whether verified offline or in ESO, remaining
uncertainties, and implications for implementation. Record failed approaches
and supported alternatives; do not claim untested behavior works. Keep the
current gate status consistent so the implementation agent can distinguish
proven behavior, known limitations, and decisions still needed.
