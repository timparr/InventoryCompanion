"""Run isolated rule tests with Lua 5.1: python -m pip install lupa; python Project\\Tests\\Run-RuleTests.py."""

from pathlib import Path

from lupa.lua51 import LuaRuntime


root = Path(__file__).resolve().parents[2]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('InventoryCompanion = { SettingsName = "InventoryCompanion_RuleTests" }')
compile_lua = lua.eval("function(source, name) assert(loadstring(source, name)) end")
for folder in ("Core", "Banking", "Tracking"):
    for path in sorted((root / folder).glob("*.lua")):
        compile_lua(path.read_text(encoding="utf-8-sig"), str(path.relative_to(root)))

for relative in ("Tracking\\ItemDatabase.lua", "Core\\RuleTests.lua"):
    lua.execute((root / relative).read_text(encoding="utf-8-sig"), name=relative)

tests = lua.globals().InventoryCompanion.GetRuleTests()
failures = []
for index in range(1, len(tests) + 1):
    test = tests[index]
    try:
        test.run()
        print(f"PASS {test.name}")
    except Exception as error:
        failures.append(test.name)
        print(f"FAIL {test.name}: {error}")

print(f"{len(tests) - len(failures)}/{len(tests)} isolated rule tests passed; addon Lua syntax checked (Lua 5.1).")
raise SystemExit(bool(failures))
