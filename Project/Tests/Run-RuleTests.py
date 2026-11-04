"""Run isolated addon tests with Lua 5.1: python -m pip install lupa; python Project\\Tests\\Run-RuleTests.py."""

from pathlib import Path
import argparse
import re
import subprocess
import xml.etree.ElementTree as ET
from time import perf_counter

from lupa.lua51 import LuaRuntime


root = Path(__file__).resolve().parents[2]
editor_xml = ET.parse(root / "Tracking" / "EditPanelItemsTab.xml")
editor_row = editor_xml.find(".//Control[@name='InventoryCompanion_TrackedItemRow_Template']/Controls")
item_label = editor_row.find("Label[@name='$(parent)ItemLabel']")
assert item_label.find("Dimensions").get("x") == "432", "Tracking names must retain the full width without an AutoCategory column"
assert len(item_label.findall("Anchor")) == 1, "Item names must not depend on a forward sibling anchor"
assert editor_row.find("*[@name='$(parent)AutoCategory']") is None
assert editor_row.find("*[@name='$(parent)CategorySpace']") is None
editor_window = editor_xml.find(".//TopLevelControl[@name='InventoryCompanion_TrackedItemsWindow']/Controls")
assert editor_window.find("Label[@name='$(parent)Title']").get("text") == "Manage Tracking"
headers = editor_window.find("Control[@name='$(parent)ColumnHeaders']")
assert headers.find("Dimensions").get("x") == editor_xml.find(
    ".//Control[@name='InventoryCompanion_TrackedItemRow_Template']/Dimensions"
).get("x"), "Column headings and rows must share the same width"
header_anchor = headers.find("Anchor")
assert header_anchor.get("relativeTo") == "$(parent)FilterBar" and header_anchor.get("relativePoint") == "BOTTOMLEFT"
scroll_anchor = editor_window.find("Control[@name='$(parent)ScrollContainer']/Anchor[@point='TOPLEFT']")
assert scroll_anchor.get("relativeTo") == "$(parent)ColumnHeaders" and scroll_anchor.get("relativePoint") == "BOTTOMLEFT"
header_controls = headers.find("Controls")
removal_space = header_controls.find("Button[@name='$(parent)RemovalSpace']")
remove_button = editor_row.find("Button[@name='$(parent)BtnRemove']")
assert removal_space.get("inherits") == remove_button.get("inherits") == "ZO_CloseButton"
assert removal_space.get("hidden") == "true" and removal_space.get("mouseEnabled") == "false"
for attribute in ("point", "relativeTo", "relativePoint", "offsetX", "offsetY"):
    assert removal_space.find("Anchor").get(attribute, "0") == remove_button.find("Anchor").get(attribute, "0")
for column, target in (("Show", "Notify"), ("Notify", "BtnRemove")):
    button = editor_row.find(f"Button[@name='$(parent){column}']")
    heading = header_controls.find(f"Label[@name='$(parent){column}']")
    assert heading.get("text") == column and heading.get("horizontalAlignment") == "CENTER"
    assert heading.find("Dimensions").get("x") == button.find("Dimensions").get("x")
    assert button.find("Controls/Label[@name='$(parent)Title']") is None
    detail = button.find("Controls/Label[@name='$(parent)Detail']")
    assert detail.get("font") == item_label.get("font") == "ZoFontGame"
    assert detail.get("verticalAlignment") == "CENTER" and detail.get("wrapMode") == "ELLIPSE"
    assert detail.find("Dimensions").get("y") == button.find("Dimensions").get("y") == "30", \
        "Regular-size summaries need the full row height to avoid clipping"
    assert button.find("Anchor").get("relativeTo") == "$(parent)" + target
    assert heading.find("Anchor").get("relativeTo") == "$(parent)" + (
        "RemovalSpace" if target == "BtnRemove" else target
    )
    for attribute in ("point", "relativePoint", "offsetX"):
        assert heading.find("Anchor").get(attribute) == button.find("Anchor").get(attribute), \
            f"{column} heading must align with its row summaries"
options_popup = editor_xml.find(".//TopLevelControl[@name='InventoryCompanion_ItemRowOptions']/Controls")
assert len(options_popup.findall("Control")) == 3, "Only Show/Notify checkbox options remain"
for index in range(1, 4):
    option = options_popup.find(f"Control[@name='$(parent)Option{index}']")
    assert option is not None and option.get("inherits") == "InventoryCompanion_ItemOption_Template", \
        f"Tracking options need checkbox option {index}"
autocategory_xml = ET.parse(root / "Tracking" / "EditPanelAutoCategoryTab.xml")
autocategory_row = autocategory_xml.find(".//Control[@name='InventoryCompanion_AutoCategoryRow_Template']/Controls")
for child in ("BG", "Orders", "Name", "MoveUp", "MoveDown", "Participation"):
    assert autocategory_row.find(f"*[@name='$(parent){child}']") is not None, f"AutoCategory row needs {child}"
assert autocategory_row.find("*[@name='$(parent)Selection']") is None, "Selection checkboxes are obsolete"
name_label = autocategory_row.find("Label[@name='$(parent)Name']")
orders_label = autocategory_row.find("Label[@name='$(parent)Orders']")
name_anchor = name_label.find("Anchor")
orders_anchor = orders_label.find("Anchor")
assert name_anchor.get("relativeTo") == "$(parent)" and name_anchor.get("relativePoint") == "LEFT"
assert orders_anchor.get("relativeTo") == "$(parent)Participation"
assert orders_anchor.get("point") == "RIGHT" and orders_anchor.get("relativePoint") == "LEFT"
assert name_label.get("verticalAlignment") == "CENTER" and orders_label.get("verticalAlignment") == "CENTER"
autocategory_window = autocategory_xml.find(".//TopLevelControl[@name='InventoryCompanion_AutoCategoryWindow']/Controls")
participation_button = autocategory_row.find("Button[@name='$(parent)Participation']")
assert participation_button.get("inherits") is None and participation_button.find("Textures") is None, \
    "Hide/Show actions must be plain buttons without default texture bars"
order_title = autocategory_window.find("Label[@name='$(parent)OrderTitle']")
order_info = autocategory_window.find("Label[@name='$(parent)Info']")
order_instructions = autocategory_window.find("Label[@name='$(parent)Instructions']")
assert order_title.get("font") == "ZoFontWinH3" and order_info.get("font") == "ZoFontGame"
assert order_info.get("wrapMode") is None and order_info.get("color") is None, \
    "The main paragraph must use the same default wrapping and colour as LAM descriptions"
assert order_instructions.get("font") == "ZoFontGame" and order_instructions.get("color") is None, \
    "Selection guidance must use the larger regular font and normal text colour"
assert order_info.find("Dimensions").get("y") is None, "Explanation height must not clip its last wrapped line"
assert order_instructions.find("Dimensions").get("y") is None
movement_anchor = autocategory_window.find("Control[@name='$(parent)MovementBar']/Anchor")
assert movement_anchor.get("point") == "BOTTOMLEFT" and movement_anchor.get("relativeTo") == "$(parent)"
assert movement_anchor.get("relativePoint") == "BOTTOMLEFT" and movement_anchor.get("offsetY") == "-20"
guidance_anchor = order_instructions.find("Anchor")
assert guidance_anchor.get("point") == "BOTTOMLEFT" and guidance_anchor.get("relativeTo") == "$(parent)MovementBar"
assert guidance_anchor.get("relativePoint") == "TOPLEFT" and guidance_anchor.get("offsetY") == "-8", \
    "Selection guidance must sit directly above the bottom movement buttons"
list_top = autocategory_window.find("Control[@name='$(parent)List']/Anchor[@point='TOPLEFT']")
list_bottom = autocategory_window.find("Control[@name='$(parent)List']/Anchor[@point='BOTTOMRIGHT']")
assert list_top.get("relativeTo") == "$(parent)Info" and list_top.get("relativePoint") == "BOTTOMLEFT"
assert list_bottom.get("relativeTo") == "$(parent)Instructions" and list_bottom.get("relativePoint") == "TOPRIGHT"
assert list_bottom.get("offsetY") == "-8", "The list must leave room for the full guidance text"
control_names = [control.get("name") for control in autocategory_window]
assert control_names.index("$(parent)MovementBar") < control_names.index("$(parent)Instructions") \
    < control_names.index("$(parent)List"), "Footer anchors must not refer to later siblings"
for path in (
    "TopActionBar/Controls/*[@name='$(parent)ContextMode']",
    "OptionsBar/Controls/*[@name='$(parent)CopyFromLabel']",
    "OptionsBar/Controls/*[@name='$(parent)CopyContext']",
    "OptionsBar/Controls/*[@name='$(parent)BtnCopy']",
    "OptionsBar/Controls/*[@name='$(parent)BtnDisplayOrder']",
    "OptionsBar/Controls/*[@name='$(parent)BtnPriorityOrder']",
    "Info", "Instructions", "List", "MovementBar",
    "Recovery/Controls/*[@name='$(parent)Warning']",
    "Recovery/Controls/*[@name='$(parent)BtnRetry']",
    "Recovery/Controls/*[@name='$(parent)BtnRepair']",
    "Recovery/Controls/*[@name='$(parent)BtnReset']",
    "Recovery/Controls/*[@name='$(parent)BtnEnableSetup']",
    "Recovery/Controls/*[@name='$(parent)BtnDetails']",
    "Recovery/Controls/*[@name='$(parent)Help']",
):
    parent, _, rest = path.partition("/")
    node = autocategory_window.find(f"*[@name='$(parent){parent}']")
    assert node is not None and (not rest or node.find(rest) is not None), f"AutoCategory window needs {path}"
assert autocategory_window.find("*[@name='$(parent)TopActionBar']/Controls/*[@name='$(parent)FindBox']") is None, \
    "The AutoCategory order filter is obsolete: filtering an ordering list hides what rows move against"
assert autocategory_row.find("*[@name='$(parent)Visibility']") is None, "Heading visibility controls are obsolete"
assert autocategory_window.find("*[@name='$(parent)HeadingDetails']") is None, "Movement toolbar replaces heading details"
recovery = autocategory_window.find("*[@name='$(parent)Recovery']/Controls")
problems = recovery.find("*[@name='$(parent)Problems']")
assert problems.find("Dimensions") is None and len(problems.findall("Anchor")) == 2, \
    "Recovery problems must fill remaining panel height rather than use a short fixed viewport"
problem_rows = problems.find(".//Label[@name='$(parent)ProblemRows']")
assert problem_rows.get("font") == "$(MEDIUM_FONT)|20|soft-shadow-thin", \
    "Problem rows need larger regular-weight text"
movement_bar = autocategory_window.find("*[@name='$(parent)MovementBar']/Controls")
for child in ("BtnSelectBlock", "BtnClear", "BtnUp1", "BtnDown1", "BtnUp5", "BtnDown5", "BtnTop", "BtnBottom"):
    assert movement_bar.find(f"Button[@name='$(parent){child}']") is not None, f"Movement toolbar needs {child}"
assert movement_bar.find("Button[@name='$(parent)BtnUp10']") is None, "Ten-step movement buttons are obsolete"
for xml_name, window_name in (
    ("EditPanelItemsTab.xml", "InventoryCompanion_TrackedItemsWindow"),
    ("EditPanelGroupsTab.xml", "InventoryCompanion_GroupsWindow"),
    ("EditPanelAutoCategoryTab.xml", "InventoryCompanion_AutoCategoryWindow"),
):
    window = ET.parse(root / "Tracking" / xml_name).find(f".//TopLevelControl[@name='{window_name}']/Controls")
    assert window.find("Button[@name='$(parent)BtnEditItems']").get("text") == "Manage Tracking"
    previous_right = 0
    for name in ("BtnOtherSettings", "BtnEditItems", "BtnEditGroups", "BtnAutoCategory"):
        button = window.find(f"Button[@name='$(parent){name}']")
        left = int(button.find("Anchor").get("offsetX"))
        assert left >= previous_right + 5, f"{window_name} navigation must not overlap"
        previous_right = left + int(button.find("Dimensions").get("x"))
    assert previous_right <= 810, f"{window_name} navigation must leave room for Close"
    assert window.find("Button[@name='$(parent)BtnAutoCategory']") is not None, f"{window_name} needs the AutoCategory tab button"
    undo = window.find("Button[@name='$(parent)BtnUndo']")
    assert undo is not None and undo.get("text") == "Undo changes", f"{window_name} needs the exact Undo changes action"
manifest = (root / "InventoryCompanion_DEV.txt").read_text(encoding="utf-8-sig")
autocategory_tab_lua = (root / "Tracking" / "EditPanelAutoCategoryTab.lua").read_text(encoding="utf-8-sig")
autocategory_tab_xml = (root / "Tracking" / "EditPanelAutoCategoryTab.xml").read_text(encoding="utf-8-sig")
template_children = {"ScrollChild", "ScrollChildProblemRows"}  # Scroll-container descendants.
lookups = re.findall(r'Window\("(\w+)"', autocategory_tab_lua) + re.findall(r'GetControl\((?:[^"()]|\([^()]*\))*?,\s*"(\w+)"', autocategory_tab_lua)
for name in set(lookups) - template_children:
    assert f'name="$(parent){name}"' in autocategory_tab_xml, f"AutoCategory tab Lua looks up missing XML child {name}"
for relative in ("Tracking/EditPanelAutoCategoryTab.xml", "Tracking/EditPanelAutoCategoryTab.lua"):
    assert relative in manifest, f"Manifest must load {relative}"
parser = argparse.ArgumentParser()
parser.add_argument("--item-editor-only", action="store_true", help="Run only item-editor regression tests.")
parser.add_argument("--test-filter", help="Run tests whose names match this regular expression.")
args = parser.parse_args()
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('InventoryCompanion = { SettingsName = "InventoryCompanion_RuleTests" }')
lua.execute('function GetDisplayName() return "account" end')
lua.globals().GetGameTimeMilliseconds = lambda: int(perf_counter() * 1000)
compile_lua = lua.eval("function(source, name) assert(loadstring(source, name)) end")
for folder in ("Core", "Banking", "Tracking"):
    for path in sorted((root / folder).glob("*.lua")):
        compile_lua(path.read_text(encoding="utf-8-sig"), str(path.relative_to(root)))

lua.execute((root / "Core\\Constants.lua").read_text(encoding="utf-8-sig"), name="Core\\Constants.lua")
for relative in (
    "Tracking\\ItemDatabase.lua",
    "Tracking\\AutoCategoryIntegration.lua",
    "Core\\RuleTests.lua",
    "Project\\Tests\\GroupEditorTests.lua",
    "Tracking\\EditPanelTabManager.lua",
    "Tracking\\EditPanelGroupsTab.lua",
):
    lua.execute((root / relative).read_text(encoding="utf-8-sig"), name=relative)

persistence_lua = LuaRuntime(unpack_returned_tuples=True)
persistence_lua.execute("""
function GetDisplayName() return "account" end
SLASH_COMMANDS = {}
EVENT_MANAGER = { RegisterForEvent = function() end }
function d() end
function ZO_ClearTable(values) for key in pairs(values) do values[key] = nil end end
""")
for relative in ("Core\\Init.lua", "Tracking\\ItemDatabase.lua", "Project\\Tests\\RulePersistenceTests.lua"):
    if relative == "Tracking\\ItemDatabase.lua":
        persistence_lua.execute((root / "Core\\Constants.lua").read_text(encoding="utf-8-sig"), name="Core\\Constants.lua")
    persistence_lua.execute((root / relative).read_text(encoding="utf-8-sig"), name=relative)
persistence_lua.execute(
    (root / "Tracking\\AutoCategoryIntegration.lua").read_text(encoding="utf-8-sig"),
    name="Tracking\\AutoCategoryIntegration.lua",
)
persistence_lua.globals().RuleDatabaseSource = (root / "Tracking\\ItemDatabase.lua").read_text(encoding="utf-8-sig")
persistence_lua.globals().RuleConstantsSource = (root / "Core\\Constants.lua").read_text(encoding="utf-8-sig")
saved_variables_lua = LuaRuntime(unpack_returned_tuples=True)
saved_variables_lua.globals().SavedVariablesInitSource = (root / "Core\\Init.lua").read_text(encoding="utf-8-sig")
saved_variables_lua.globals().SavedVariablesConstantsSource = (root / "Core\\Constants.lua").read_text(encoding="utf-8-sig")
saved_variables_lua.globals().SavedVariablesDatabaseSource = (root / "Tracking\\ItemDatabase.lua").read_text(encoding="utf-8-sig")
saved_variables_lua.globals().SavedVariablesIntegrationSource = (
    root / "Tracking\\AutoCategoryIntegration.lua"
).read_text(encoding="utf-8-sig")
# Pin the last schema-4 build so downgrade protection tests the incompatible ordering change.
legacy_saved_variables_commit = "9d2531ef621725351039ad7d3044b4a55d426b75"
for field, relative in (
    ("LegacySavedVariablesInitSource", "Core/Init.lua"),
    ("LegacySavedVariablesConstantsSource", "Core/Constants.lua"),
    ("LegacySavedVariablesDatabaseSource", "Tracking/ItemDatabase.lua"),
):
    saved_variables_lua.globals()[field] = subprocess.check_output(
        ["git", "--no-pager", "show", f"{legacy_saved_variables_commit}:{relative}"], cwd=root
    ).decode("utf-8-sig")
saved_variables_lua.execute((root / "Project\\Tests\\SavedVariablesTests.lua").read_text(encoding="utf-8-sig"))
for field, relative in (
    ("Schema5InitSource", "Core/Init.lua"),
    ("Schema5DatabaseSource", "Tracking/ItemDatabase.lua"),
):
    saved_variables_lua.globals()[field] = subprocess.check_output(
        ["git", "--no-pager", "show", f"3e1afd6faf202769229add36dc148ade5b6a6912:{relative}"], cwd=root
    ).decode("utf-8-sig")
schema6_saved_variables_commit = "485333a904864bb3f064ca43fb26a30f60dce8ac"
for field, relative in (
    ("Schema6InitSource", "Core/Init.lua"),
    ("Schema6ConstantsSource", "Core/Constants.lua"),
    ("Schema6DatabaseSource", "Tracking/ItemDatabase.lua"),
):
    saved_variables_lua.globals()[field] = subprocess.check_output(
        ["git", "--no-pager", "show", f"{schema6_saved_variables_commit}:{relative}"], cwd=root
    ).decode("utf-8-sig")
for field, relative in (
    ("Schema7InitSource", "Core/Init.lua"),
    ("Schema7ConstantsSource", "Core/Constants.lua"),
    ("Schema7DatabaseSource", "Tracking/ItemDatabase.lua"),
):
    saved_variables_lua.globals()[field] = subprocess.check_output(
        ["git", "--no-pager", "show", f"88f5807a6c5cf5b7a1e2866e29e8fc841138cabf:{relative}"], cwd=root
    ).decode("utf-8-sig")
for field, relative in (
    ("Schema8InitSource", "Core/Init.lua"),
    ("Schema8ConstantsSource", "Core/Constants.lua"),
    ("Schema8DatabaseSource", "Tracking/ItemDatabase.lua"),
):
    saved_variables_lua.globals()[field] = subprocess.check_output(
        ["git", "--no-pager", "show", f"dd05da8489602874e1fdc12bb516f83b7364d877:{relative}"], cwd=root
    ).decode("utf-8-sig")
for field, relative in (
    ("Schema9InitSource", "Core/Init.lua"),
    ("Schema9ConstantsSource", "Core/Constants.lua"),
    ("Schema9DatabaseSource", "Tracking/ItemDatabase.lua"),
):
    saved_variables_lua.globals()[field] = subprocess.check_output(
        ["git", "--no-pager", "show", f"b04cf78:{relative}"], cwd=root
    ).decode("utf-8-sig")
tracker_lua = LuaRuntime(unpack_returned_tuples=True)
tracker_lua.execute("SLASH_COMMANDS = {}; EVENT_MANAGER = { RegisterForEvent = function() end }")
tracker_lua.globals().GetGameTimeMilliseconds = lambda: int(perf_counter() * 1000)
tracker_lua.globals().TrackerEventSource = (root / "Core\\Events.lua").read_text(encoding="utf-8-sig")
tracker_lua.globals().TrackerPanelSource = (root / "Tracking\\ItemTrackerPanel.lua").read_text(encoding="utf-8-sig")
for relative in (
    "Core\\Init.lua",
    "Core\\Constants.lua",
    "Tracking\\ItemDatabase.lua",
    "Tracking\\AutoCategoryIntegration.lua",
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
    "Tracking\\AutoCategoryIntegration.lua",
    "Project\\Tests\\ItemEditorTests.lua",
    "Tracking\\EditPanelTabManager.lua",
    "Tracking\\EditPanelItemsTab.lua",
):
    item_editor_lua.execute((root / relative).read_text(encoding="utf-8-sig"), name=relative)
autocategory_lua = LuaRuntime(unpack_returned_tuples=True)
autocategory_lua.execute(
    'InventoryCompanion = { SettingsName = "InventoryCompanion_AutoCategoryTests" }'
)
# ESO does not expose debug.getinfo; keep the diagnostic tests representative of that runtime.
autocategory_lua.execute("debug.getinfo = nil")
autocategory_lua.globals().AutoCategoryIntegrationSource = (
    root / "Tracking\\AutoCategoryIntegration.lua"
).read_text(encoding="utf-8-sig")
for relative in (
    "Core\\Constants.lua",
    "Tracking\\ItemDatabase.lua",
    "Tracking\\AutoCategoryIntegration.lua",
    "Project\\Tests\\AutoCategoryIntegrationTests.lua",
    "Project\\Tests\\AutoCategoryEditorTests.lua",
    "Tracking\\EditPanelTabManager.lua",
    "Tracking\\EditPanelAutoCategoryTab.lua",
):
    autocategory_lua.execute((root / relative).read_text(encoding="utf-8-sig"), name=relative)
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
        autocategory_lua.globals().InventoryCompanion.GetAutoCategoryIntegrationTests(),
        autocategory_lua.globals().InventoryCompanion.GetAutoCategoryEditorTests(),
    )
for suite in suites:
    tests.extend(suite[index] for index in range(1, len(suite) + 1))
if args.test_filter:
    tests = [test for test in tests if re.search(args.test_filter, test.name, re.IGNORECASE)]
    assert tests, f"No tests matched {args.test_filter!r}"

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
