"""Run isolated addon tests with Lua 5.1: python -m pip install lupa; python Project\\Tests\\Run-RuleTests.py."""

from pathlib import Path
import argparse
import subprocess
from time import perf_counter

from lupa.lua51 import LuaRuntime


root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--item-editor-only", action="store_true", help="Run only item-editor regression tests.")
args = parser.parse_args()
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('InventoryCompanion = { SettingsName = "InventoryCompanion_RuleTests" }')
lua.globals().GetGameTimeMilliseconds = lambda: int(perf_counter() * 1000)
compile_lua = lua.eval("function(source, name) assert(loadstring(source, name)) end")
for folder in ("Core", "Banking", "Tracking"):
    for path in sorted((root / folder).glob("*.lua")):
        compile_lua(path.read_text(encoding="utf-8-sig"), str(path.relative_to(root)))

lua.execute((root / "Core\\Constants.lua").read_text(encoding="utf-8-sig"), name="Core\\Constants.lua")
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
function ZO_ClearTable(values) for key in pairs(values) do values[key] = nil end end
""")
for relative in ("Core\\Init.lua", "Tracking\\ItemDatabase.lua", "Project\\Tests\\RulePersistenceTests.lua"):
    if relative == "Tracking\\ItemDatabase.lua":
        persistence_lua.execute((root / "Core\\Constants.lua").read_text(encoding="utf-8-sig"), name="Core\\Constants.lua")
    persistence_lua.execute((root / relative).read_text(encoding="utf-8-sig"), name=relative)
persistence_lua.globals().RuleDatabaseSource = (root / "Tracking\\ItemDatabase.lua").read_text(encoding="utf-8-sig")
persistence_lua.globals().RuleConstantsSource = (root / "Core\\Constants.lua").read_text(encoding="utf-8-sig")
saved_variables_lua = LuaRuntime(unpack_returned_tuples=True)
saved_variables_lua.globals().SavedVariablesInitSource = (root / "Core\\Init.lua").read_text(encoding="utf-8-sig")
saved_variables_lua.globals().SavedVariablesConstantsSource = (root / "Core\\Constants.lua").read_text(encoding="utf-8-sig")
saved_variables_lua.globals().SavedVariablesDatabaseSource = (root / "Tracking\\ItemDatabase.lua").read_text(encoding="utf-8-sig")
for field, relative in (
    ("LegacySavedVariablesInitSource", "Core/Init.lua"),
    ("LegacySavedVariablesConstantsSource", "Core/Constants.lua"),
    ("LegacySavedVariablesDatabaseSource", "Tracking/ItemDatabase.lua"),
):
    saved_variables_lua.globals()[field] = subprocess.check_output(
        ["git", "--no-pager", "show", f"9dc0e12:{relative}"], cwd=root
    ).decode("utf-8-sig")
saved_variables_lua.execute((root / "Project\\Tests\\SavedVariablesTests.lua").read_text(encoding="utf-8-sig"))
tracker_lua = LuaRuntime(unpack_returned_tuples=True)
tracker_lua.execute("SLASH_COMMANDS = {}; EVENT_MANAGER = { RegisterForEvent = function() end }")
tracker_lua.globals().GetGameTimeMilliseconds = lambda: int(perf_counter() * 1000)
tracker_lua.globals().TrackerEventSource = (root / "Core\\Events.lua").read_text(encoding="utf-8-sig")
tracker_lua.globals().TrackerPanelSource = (root / "Tracking\\ItemTrackerPanel.lua").read_text(encoding="utf-8-sig")
for relative in (
    "Core\\Init.lua",
    "Core\\Constants.lua",
    "Tracking\\ItemDatabase.lua",
    "Project\\Tests\\TrackerPanelTests.lua",
    "Tracking\\ItemTrackerPanel.lua",
    "Core\\Settings.lua",
    "Tracking\\EditPanelTabManager.lua",
):
    tracker_lua.execute((root / relative).read_text(encoding="utf-8-sig"), name=relative)
item_editor_lua = LuaRuntime(unpack_returned_tuples=True)
item_editor_lua.execute('InventoryCompanion = { Name = "InventoryCompanion_DEV", SettingsName = "InventoryCompanion_ItemEditorTests" }')
for relative in (
    "Core\\Constants.lua",
    "Tracking\\ItemDatabase.lua",
    "Project\\Tests\\ItemEditorTests.lua",
    "Tracking\\EditPanelItemsTab.lua",
):
    item_editor_lua.execute((root / relative).read_text(encoding="utf-8-sig"), name=relative)
tests = []
suites = (item_editor_lua.globals().InventoryCompanion.GetItemEditorTests(),)
if not args.item_editor_only:
    notification_lua = LuaRuntime(unpack_returned_tuples=True)
    notification_lua.execute('InventoryCompanion = { Name = "InventoryCompanion_NotificationTests" }')
    for relative in ("Core\\Utils.lua", "Project\\Tests\\ItemNotificationTests.lua"):
        notification_lua.execute((root / relative).read_text(encoding="utf-8-sig"), name=relative)
    suites += (
        notification_lua.globals().InventoryCompanion.GetItemNotificationTests(),
        lua.globals().InventoryCompanion.GetRuleTests(),
        lua.globals().InventoryCompanion.GetGroupEditorTests(),
        persistence_lua.globals().InventoryCompanion.GetRulePersistenceTests(),
        saved_variables_lua.globals().GetSavedVariablesTests(),
        tracker_lua.globals().InventoryCompanion.GetTrackerPanelTests(),
    )
for suite in suites:
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

print(f"{len(tests) - len(failures)}/{len(tests)} isolated addon tests passed; addon Lua syntax checked (Lua 5.1).")
raise SystemExit(bool(failures))
