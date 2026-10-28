"""Run isolated rule tests with Lua 5.1: python -m pip install lupa; python Project\\Tests\\Run-RuleTests.py."""

from pathlib import Path
from time import perf_counter

from lupa.lua51 import LuaRuntime


root = Path(__file__).resolve().parents[2]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('InventoryCompanion = { SettingsName = "InventoryCompanion_RuleTests" }')
lua.globals().GetGameTimeMilliseconds = lambda: int(perf_counter() * 1000)
compile_lua = lua.eval("function(source, name) assert(loadstring(source, name)) end")
for folder in ("Core", "Banking", "Tracking"):
    for path in sorted((root / folder).glob("*.lua")):
        compile_lua(path.read_text(encoding="utf-8-sig"), str(path.relative_to(root)))

for relative in (
    "Tracking\\ItemDatabase.lua",
    "Core\\RuleTests.lua",
    "Project\\Tests\\GroupEditorTests.lua",
    "Tracking\\EditPanelGroupsTab.lua",
):
    lua.execute((root / relative).read_text(encoding="utf-8-sig"), name=relative)

persistence_lua = LuaRuntime(unpack_returned_tuples=True)
persistence_lua.execute("""
SLASH_COMMANDS = {}
EVENT_MANAGER = { RegisterForEvent = function() end }
function d() end
""")
for relative in ("Core\\Init.lua", "Tracking\\ItemDatabase.lua", "Project\\Tests\\RulePersistenceTests.lua"):
    persistence_lua.execute((root / relative).read_text(encoding="utf-8-sig"), name=relative)
persistence_lua.globals().RuleDatabaseSource = (root / "Tracking\\ItemDatabase.lua").read_text(encoding="utf-8-sig")
persistence_lua.globals().RuleConstantsSource = (root / "Core\\Constants.lua").read_text(encoding="utf-8-sig")
saved_variables_lua = LuaRuntime(unpack_returned_tuples=True)
saved_variables_lua.globals().SavedVariablesInitSource = (root / "Core\\Init.lua").read_text(encoding="utf-8-sig")
saved_variables_lua.globals().SavedVariablesDatabaseSource = (root / "Tracking\\ItemDatabase.lua").read_text(encoding="utf-8-sig")
saved_variables_lua.execute((root / "Project\\Tests\\SavedVariablesTests.lua").read_text(encoding="utf-8-sig"))
tests = []
for suite in (
    lua.globals().InventoryCompanion.GetRuleTests(),
    lua.globals().InventoryCompanion.GetGroupEditorTests(),
    persistence_lua.globals().InventoryCompanion.GetRulePersistenceTests(),
    saved_variables_lua.globals().GetSavedVariablesTests(),
):
    tests.extend(suite[index] for index in range(1, len(suite) + 1))

failures = []
for test in tests:
    try:
        details = test.run()
        print(f"PASS {test.name}")
        if details:
            print(f"  {details}")
    except Exception as error:
        failures.append(test.name)
        print(f"FAIL {test.name}: {error}")

print(f"{len(tests) - len(failures)}/{len(tests)} isolated rule tests passed; addon Lua syntax checked (Lua 5.1).")
raise SystemExit(bool(failures))
