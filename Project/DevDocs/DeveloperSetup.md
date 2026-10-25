# Developer Setup

## ESO API in VS Code

The workspace configures Lua Language Server for Lua 5.1 and loads local ESO API definitions from the ignored `generated-eso-api/luals` directory. These generated files are editor-only and must not be added to `InventoryCompanion.txt`.

The API definitions are generated with the community [ESO-LuaLS-Generator](https://github.com/Hydra9268/ESO-LuaLS-Generator) from [UESP ESO API exports](https://esoapi.uesp.net/current/index.html). For a new development machine:

1. Install the VS Code **Lua** extension (Lua Language Server) and Python 3.12.
2. Clone the generator to `%USERPROFILE%\Documents\ESO-LuaLS-Generator`:

   ```powershell
   git clone https://github.com/Hydra9268/ESO-LuaLS-Generator.git "$env:USERPROFILE\Documents\ESO-LuaLS-Generator"
   ```

3. From the addon root, generate and install the local definitions:

   ```powershell
   .\Project\DevDocs\UpdateESOApiLibrary.ps1
   ```

Reload the VS Code window after initial generation or after updating the API.

To refresh the generator and its bundled UESP exports later:

```powershell
git -C "$env:USERPROFILE\Documents\ESO-LuaLS-Generator" pull --ff-only
.\Project\DevDocs\UpdateESOApiLibrary.ps1
```

## In-Game Diagnostics

- `/ictest [verbose] [copy]` runs diagnostic tests and live inventory scans. It does not intentionally modify saved variables.
- `/icclean` explicitly prunes known diagnostic saved-variable leftovers and updates the currency-name diagnostic history.
- `/icbankitems [1-20]` lists sample standard-bank and ESO Plus subscriber-bank contents while a bank or house chest is open. It is read-only.
