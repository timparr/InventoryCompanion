Here is the complete, end-to-end work plan for Task A2, detailing the exact proposal to refactor group renaming and pattern edits to write clean delta overrides instead of duplicating baseline data.

---

## Task A2 Work Plan: Delta-Only Saved Variables via Explicit Surgical Setters

### Step 1: Introduce the Root-Level Property Setter (`Tracking/ItemDatabase.lua`)

* **Objective:** Create a dedicated, single-responsibility helper to write root-level rule properties (`displayName`, `patterns`) without touching nested flags or duplicating unedited baseline data.
* **Proposed Code:**
```lua
--- Set a single root-level property override on a rule without cloning unrelated tables
function this.SetRuleProperty(ruleName, propertyKey, value)
    local savedRules = GetRawSavedRules()
    savedRules[ruleName] = savedRules[ruleName] or {}
    savedRules[ruleName][propertyKey] = value
end

```



---

### Step 2: Refactor Group Editor Write Operations (`Tracking/EditPanelGroupsTab.lua`)

* **Objective:** Clean up write paths so they stop force-injecting unedited baseline tables into saved variables.
* **A. Refactor `CommitGroupNameEdit`:**
* *Change:* Replace the bloated save block that force-injects default patterns and full display fallback tables with a clean surgical setter call.
* *New Implementation snippet:*
```lua
this.SetRuleProperty(selectedGroupName, "displayName", finalName)

```




* **B. Refactor `SaveRulePatterns`:**
* *Change:* Replace the bloated pattern-saving logic that force-injects unedited display names and default display flags with a clean surgical setter call.
* *New Implementation snippet:*
```lua
this.SetRuleProperty(groupName, "patterns", patterns)

```
See further discussion below:




---

### Step 3: Verify Read-Side Compatibility (`Tracking/ItemDatabase.lua`)

* **Objective:** Confirm that `GetActiveTrackedRules` handles delta overrides seamlessly.
* **Audit Status:** Verified. Because `GetActiveTrackedRules` checks `savedData.displayName ~= nil` and `savedData.patterns ~= nil` before applying changes, it safely skips missing properties and falls back to preloaded baseline data automatically. No read-side code changes are required.

---

### Step 4: Testing & Verification

* **Objective:** Ensure functional correctness and check output saved variables.
* **Action Items:**
* Execute the synthetic unit tests in `Core/Init.lua` to verify baseline-to-override resolution.
* Test renaming a group and modifying patterns via the UI, then inspect `InventoryCompanion_SavedVariables` to confirm that saved tables contain *only* the modified delta properties.

More discussion:
## Updated Architecture Plan: Pattern-Override System & Cached Compilation

### 1. Core Objective & Design Philosophy

* **Upstream Safety:** Allow the developer to update the built-in default baseline pattern lists upstream without user overrides blocking new defaults or causing positional index collisions.
* **Separation of Concerns:** Keep raw user modifications and delta states cleanly separated from runtime execution performance.

---

### 2. Data Mutation Endpoints (The Write API)

Located alongside `SetRuleFlag` in `ItemDatabase.lua`, three dedicated mutation functions handle all rule edits:

1. **`UpdateRuleFlag(ruleName, flagKey, value)`**
* Handles display property toggles (e.g., `isHidden`, `show`, `notify`).
* Invalidates and immediately recompiles that rule's cache entry.


2. **`UpdateRuleProperty(ruleName, propKey, value)`**
* Handles general metadata updates (e.g., changing a group's `displayName`).
* Invalidates and immediately recompiles that rule's cache entry.


3. **`UpdateRulePatterns(ruleName, uiPatterns)`**
* Implements the **full-reconciliation algorithm**: fetches the default baseline, compares it against the incoming `uiPatterns` list from the UI, and generates fresh overrides (or clears them if matching baseline).
* Invalidates and immediately recompiles that rule's cache entry.



---

### 3. Caching & Compilation Strategy (`rulelist` Cache)

* **Runtime vs. Saved Variables:**
* *Should you save the compiled rulelist to saved variables?* **No.** Saved variables should strictly store raw user data (overrides, deltas, display flags). Serializing compiled Lua regex patterns or internal executable structures to disk is unnecessary, prone to corruption, and bloats saved files.
* Instead, the compiled rule list is maintained as a **runtime-only cache** in memory. It is built automatically at addon startup and instantly regenerated whenever a mutation function (`UpdateRuleFlag`, `UpdateRuleProperty`, or `UpdateRulePatterns`) executes.


* **Compilation Logic:** Combines the default baseline with any saved user overrides, then runs `CompilePatterns()` once per rule into optimized Lua regex strings.

---

### 4. Consumption Layer Update

* All consumers of rule data (such as `GetMasterItemList`, bag/bank scanning loops, and item matching functions) are refactored to consume the **pre-compiled rule lists** directly from the cache rather than raw text patterns, eliminating redundant compilation overhead during inventory scans.



---

### 5. Theorycrafting Test Workflow

* **Initial State:** Default patterns = `{a, b, c}` (No overrides).
* **Step 1:** Add a new pattern `d` via `UpdateRulePatterns` $\rightarrow$ Evaluated against baseline, stored as custom addition. Cache recompiled.
* **Step 2:** Change pattern `a` to `a1` $\rightarrow$ Reconciled against baseline. Cache recompiled.
* **Step 3:** Change pattern `a1` back to `a` $\rightarrow$ Algorithm detects original default is restored, automatically clears overrides. Cache recompiled.

---

### 6. UI Stability & Behavior on Blur (Resolved)

* **Question:** Will the UI update/re-render when the pattern is changed and the on-blur save happens?
* **Answer:** **No, the UI group editor rows do not re-render or jump.** When an input field loses focus and triggers an on-blur save, it updates the data backend and refreshes the HUD tracker, but it *does not* call the group editor's list refresh function (`RefreshGroupsEditor`). As a result, the active rows on screen remain completely stable and untouched while the user is typing or tabbing through inputs.