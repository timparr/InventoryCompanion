local this = InventoryCompanion

local function Equal(actual, expected, message)
    assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local function List(actual, expected, message)
    Equal(#actual, #expected, message .. " length")
    for index, value in ipairs(expected) do Equal(actual[index], value, message .. " #" .. index) end
end

function this.GetRuleTests()
    local tests = {}
    local function Add(name, run)
        table.insert(tests, {
            name = name,
            run = function()
                local accountWide, character, baseline = this.accountWide, this.character, this.preLoadedRulesets
                this.accountWide = { trackedRules = {}, trackedItems = {} }
                this.character = { trackedRules = {}, trackedItems = {}, useCharacterItemList = false }
                this.preLoadedRulesets = {
                    default = {
                        displayName = "Default",
                        patterns = { "c", "a", "b" },
                        display = { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false },
                    },
                }
                this.InvalidateRuleCache()
                local ok, err = pcall(run)
                this.accountWide, this.character, this.preLoadedRulesets = accountWide, character, baseline
                this.InvalidateRuleCache()
                if not ok then error(err, 0) end
            end,
        })
    end

    Add("Delta patterns follow the sequential specification", function()
        local function State(edited, added, removed, effective)
            this.UpdateRulePatterns("default", edited)
            local saved = this.accountWide.trackedRules.default or {}
            List(saved.addedPatterns or {}, added, "Added")
            List(saved.removedPatterns or {}, removed, "Removed")
            Equal(saved.patterns, nil, "No full baseline copy")
            List(this.GetActiveTrackedRules().default.patterns, effective, "Effective list")
        end
        State({ "a", "b", "c" }, {}, {}, { "a", "b", "c" })
        Equal(this.accountWide.trackedRules.default, nil, "No redundant rule")
        State({ "a", "b", "c", "d" }, { "d" }, {}, { "a", "b", "c", "d" })
        State({ "a1", "b", "c", "d" }, { "a1", "d" }, { "a" }, { "a1", "b", "c", "d" })
        State({ "a", "b", "c", "d" }, { "d" }, {}, { "a", "b", "c", "d" })
        State({ "a", "b", "c", "d1" }, { "d1" }, {}, { "a", "b", "c", "d1" })
        State({ "a", "b", "d1" }, { "d1" }, { "c" }, { "a", "b", "d1" })
        State({ "a", "b", "c" }, {}, {}, { "a", "b", "c" })
        Equal(this.accountWide.trackedRules.default, nil, "Reverting removes the override")
    end)

    Add("Delta patterns are unique and support empty lists and custom groups", function()
        this.UpdateRulePatterns("default", { "a", "a", "c" })
        List(this.GetActiveTrackedRules().default.patterns, { "a", "c" }, "Duplicate edit")
        List(this.accountWide.trackedRules.default.removedPatterns, { "b" }, "Duplicate edit removes old value")
        this.UpdateRulePatterns("default", {})
        List(this.GetActiveTrackedRules().default.patterns, {}, "Remove all defaults")
        this.UpdateRulePatterns("custom", { "z", "z", "a" })
        List(this.accountWide.trackedRules.custom.addedPatterns, { "a", "z" }, "Custom additions")
        this.UpdateRulePatterns("custom", {})
        assert(this.accountWide.trackedRules.custom, "An empty custom group must remain")
        Equal(this.accountWide.trackedRules.custom.addedPatterns, nil, "Empty collection is absent")
    end)

    Add("Rule setters write only selected fields and prune restored defaults", function()
        this.UpdateRuleProperty("default", "displayName", "Renamed")
        local saved = this.accountWide.trackedRules.default
        Equal(saved.displayName, "Renamed", "Name")
        Equal(saved.display, nil, "Rename does not copy flags")
        Equal(saved.addedPatterns, nil, "Rename does not copy patterns")
        this.UpdateRuleFlag("default", "show", false)
        this.UpdateRulePatterns("default", { "a", "b", "c", "d" })
        Equal(saved.displayName, "Renamed", "Pattern editing preserves name")
        Equal(saved.display.show, false, "Pattern editing preserves flag")
        this.UpdateRulePatterns("default", { "a", "b", "c" })
        this.UpdateRuleFlag("default", "show", true)
        Equal(saved.display, nil, "Restored display table pruned")
        this.UpdateRuleProperty("default", "displayName", "Default")
        Equal(this.accountWide.trackedRules.default, nil, "Restored rule pruned")
        this.SetRuleFlag("default", "notify", true)
        Equal(this.accountWide.trackedRules.default.display.notify, true, "Compatible flag setter")
    end)

    Add("Legacy rules convert to sparse overrides without altering the baseline", function()
        this.accountWide.trackedRules = {
            default = {
                displayName = "Default", patterns = { "b", "c", "d", "d" },
                display = { show = true, notify = true, isHidden = false },
            },
            custom = { patterns = { "z", "z" }, display = { notify = true } },
        }
        local rules = this.GetActiveTrackedRules()
        local saved = this.accountWide.trackedRules.default
        List(saved.addedPatterns, { "d" }, "Legacy additions")
        List(saved.removedPatterns, { "a" }, "Legacy removals")
        Equal(saved.patterns, nil, "Legacy list removed")
        Equal(saved.displayName, nil, "Legacy default name removed")
        Equal(saved.display.show, nil, "Legacy default flag removed")
        Equal(saved.display.notify, true, "Edited flag retained")
        List(rules.default.patterns, { "b", "c", "d" }, "Legacy effective list")
        Equal(rules.custom.display.show, true, "Partial custom display inherits defaults")
        List(this.preLoadedRulesets.default.patterns, { "c", "a", "b" }, "Baseline unchanged")
        this.preLoadedRulesets.default.patterns = { "a", "b", "c", "e" }
        this.InvalidateRuleCache()
        List(this.GetActiveTrackedRules().default.patterns, { "b", "c", "d", "e" }, "New defaults remain visible")
    end)

    Add("Invalid rule mutations fail without writing saved state", function()
        assert(not pcall(this.UpdateRulePatterns, "default", { true }), "Invalid patterns should fail")
        assert(not pcall(this.UpdateRuleFlag, "default", "missing", true), "Unknown flags should fail")
        assert(not pcall(this.UpdateRuleFlag, "default", "show", "yes"), "Invalid flag values should fail")
        assert(not pcall(this.UpdateRuleProperty, "default", "patterns", {}), "Wrong mutation API should fail")
        Equal(next(this.accountWide.trackedRules), nil, "Failed edits leave no overrides")
    end)

    return tests
end
