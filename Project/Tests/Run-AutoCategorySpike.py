"""Run the isolated native-insertion spike; never loads or writes game saved variables."""

import argparse
import hashlib
from pathlib import Path

from lupa.lua51 import LuaRuntime


root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument(
    "--autocategory",
    type=Path,
    default=root.parent / "AutoCategory",
    help="Installed AutoCategory directory (read-only).",
)
args = parser.parse_args()
external = args.autocategory.resolve()
manifest = external / "AutoCategory.addon"
print(f"Read-only dependency: {external}")
for line in manifest.read_text(encoding="utf-8-sig").splitlines():
    if line.startswith(("## Version:", "## AddOnVersion:", "## APIVersion:")):
        print(line)

sources = [
    external / name
    for name in (
        "AutoCategory_Global.lua",
        "Plugin_API.lua",
        "AC_Classes.lua",
        "AutoCategory.lua",
        "AutoCategory_API.lua",
    )
]
fingerprints = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
lua = LuaRuntime(unpack_returned_tuples=True)
fixture = root / "Project" / "Tests" / "AutoCategorySpikeTests.lua"
lua.execute(fixture.read_text(encoding="utf-8-sig"), name=str(fixture))
for path in sources:
    lua.execute(path.read_text(encoding="utf-8-sig"), name=str(path))
lua.execute(
    "AC_UI.divider = function() return { type = 'divider' } end; "
    "AC_UI.header = function(name) return { type = 'header', name = name } end"
)
settings = external / "settings" / "BagSet.lua"
fingerprints[settings] = hashlib.sha256(settings.read_bytes()).hexdigest()
lua.execute(settings.read_text(encoding="utf-8-sig"), name=str(settings))
for relative in (
    "Core\\Constants.lua",
    "Tracking\\ItemDatabase.lua",
    "Tracking\\AutoCategoryIntegration.lua",
    "Project\\Tests\\AutoCategorySpikeRuntime.lua",
):
    path = root / relative
    lua.execute(path.read_text(encoding="utf-8-sig"), name=relative)

tests = lua.globals().GetAutoCategorySpikeTests()
failures = []
for index in range(1, len(tests) + 1):
    test = tests[index]
    try:
        details = test.run()
        print(f"PASS {test.name}")
        if details:
            print(f"  {details}")
    except Exception as error:
        failures.append(test.name)
        print(f"FAIL {test.name}: {error}")

for path, before in fingerprints.items():
    assert hashlib.sha256(path.read_bytes()).hexdigest() == before, f"Dependency changed: {path}"
print(f"{len(tests) - len(failures)}/{len(tests)} native-insertion spike tests passed.")
print("Actual dependency modules executed; ESO UI/library boundaries mocked.")
print("No live inventory/saved variables accessed. Rendering, startup, and reload remain unverified.")
raise SystemExit(bool(failures))
