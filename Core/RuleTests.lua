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
                local scanning, utils = this.Scanning, this.Utils
                local globalNames = {
                    this.SettingsName, "ZO_ClearTable", "GetItemLinkName", "GetItemId", "GetItemLink",
                    "IsESOPlusSubscriber", "BAG_BACKPACK", "BAG_BANK", "BAG_VIRTUAL", "GetGameTimeMilliseconds",
                }
                local globals = {}
                for _, key in ipairs(globalNames) do table.insert(globals, { key = key, value = _G[key] }) end
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
                this.Scanning, this.Utils = scanning, utils
                for _, entry in ipairs(globals) do _G[entry.key] = entry.value end
                this.InvalidateRuleCache()
                if not ok then error(err, 0) end
                return err
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

    Add("Runtime cache rebuilds lazily and keeps editor views isolated", function()
        local original = this.GetRuntimeRules()
        Equal(this.GetRuntimeRules(), original, "Unchanged rules reuse cache")
        this.UpdateRulePatterns("default", { "new*" })
        List(original.default.patterns, { "a", "b", "c" }, "Mutation does not eagerly rebuild")
        local updated = this.GetRuntimeRules()
        assert(updated ~= original, "Pattern mutation should replace the cache")
        Equal(this.GetRuntimeRules(), updated, "Rebuilt cache reused")
        List(updated.default.compiledPatterns, { "^new.*$" }, "Compiled wildcard")
        this.UpdateRuleProperty("default", "displayName", "Changed")
        local renamed = this.GetRuntimeRules()
        assert(renamed ~= updated, "Rename should invalidate")
        Equal(renamed.default.displayName, "Changed", "Cached name updates")
        this.UpdateRuleFlag("default", "notify", true)
        local flagged = this.GetRuntimeRules()
        assert(flagged ~= renamed, "Flag should invalidate")
        Equal(flagged.default.display.notify, true, "Cached flag updates")
        local view = this.GetActiveTrackedRules()
        view.default.patterns[1] = "editor-only"
        view.default.display.notify = false
        Equal(flagged.default.patterns[1], "new*", "Editor list cannot corrupt cache")
        Equal(flagged.default.display.notify, true, "Editor flags cannot corrupt cache")
        Equal(this.accountWide.trackedRules.default.compiledPatterns, nil, "No compiled saved data")
    end)

    Add("Hidden groups stay cached and list switching invalidates immediately", function()
        this.UpdateRuleFlag("default", "isHidden", true)
        assert(this.GetRuntimeRules().default, "Hidden rule must be cached")
        Equal(this.GetActiveTrackedRules().default, nil, "Hidden rule excluded from normal view")
        assert(this.GetActiveTrackedRules(true).default, "Editor includes hidden rules")
        this.UpdateRuleFlag("default", "isHidden", false)
        assert(this.GetActiveTrackedRules().default, "Unhide invalidates")
        this.UpdateRulePatterns("default", { "account" })
        local account = this.GetRuntimeRules()
        this.SetUseCharacterItemList(true)
        List(this.GetRuntimeRules().default.patterns, { "a", "b", "c" }, "Character inherits baseline")
        this.UpdateRulePatterns("default", { "character" })
        List(this.GetRuntimeRules().default.patterns, { "character" }, "Character override")
        this.SetUseCharacterItemList(false)
        local restored = this.GetRuntimeRules()
        assert(restored ~= account, "Switching rebuilds cache")
        List(restored.default.patterns, { "account" }, "Account override retained")
    end)

    Add("Failed runtime rebuilds do not publish partial caches", function()
        local original = this.GetRuntimeRules()
        this.preLoadedRulesets.default.patterns = { true }
        this.InvalidateRuleCache()
        assert(not pcall(this.GetRuntimeRules), "Invalid baseline should surface an error")
        List(original.default.patterns, { "a", "b", "c" }, "Published cache unchanged after failure")
        this.preLoadedRulesets.default.patterns = { "repaired" }
        List(this.GetRuntimeRules().default.patterns, { "repaired" }, "Failed rebuild remains invalid")
    end)

    Add("Profile copy preserves sparse deltas and never aliases its source", function()
        _G.ZO_ClearTable = function(values) for key in pairs(values) do values[key] = nil end end
        this.preLoadedRulesets.default.display.notify = true
        local source = {
            trackedItems = { [123] = { link = "item", mode = 3, display = { show = false } } },
            trackedRules = {
                default = { addedPatterns = { "d" }, removedPatterns = { "a" }, display = { show = false } },
                custom = { patterns = { "custom" } },
            },
        }
        _G[this.SettingsName] = { Default = { account = { source = source } } }
        local before = this.GetRuntimeRules()
        assert(this.CopyProfile("source"), "Profile copy should succeed")
        local copied = this.accountWide.trackedRules
        Equal(copied.default.display.notify, nil, "Missing source flag stays absent")
        Equal(this.GetRuntimeRules().default.display.notify, true, "Missing flag inherits baseline")
        assert(this.GetRuntimeRules() ~= before, "Profile copy invalidates")
        List(this.GetRuntimeRules().default.patterns, { "b", "c", "d" }, "Copied effective patterns")
        this.UpdateRulePatterns("default", { "b", "c", "d", "e" })
        List(source.trackedRules.default.addedPatterns, { "d" }, "Source additions isolated")
        this.UpdateRuleFlag("default", "show", true)
        Equal(source.trackedRules.default.display.show, false, "Source flags isolated")
        Equal(source.trackedRules.custom.patterns[1], "custom", "Source legacy data not migrated in place")
        local valid = this.GetRuntimeRules()
        assert(not this.CopyProfile("missing"), "Unknown profile should fail")
        Equal(this.GetRuntimeRules(), valid, "Failed copy does not invalidate")
        _G[this.SettingsName].Default.account.self = this.accountWide
        assert(this.CopyProfile("self"), "Self-copy should preserve data")
        Equal(this.accountWide.trackedItems[123].link, "item", "Self-copy retains items")
        List(this.GetRuntimeRules().default.patterns, { "b", "c", "d", "e" }, "Self-copy retains rules")
    end)

    Add("Scanning and notifications use current compiled rules", function()
        _G.BAG_BACKPACK, _G.BAG_BANK, _G.BAG_VIRTUAL = 1, 2, 3
        _G.GetItemLinkName = function(link) return link == "item" and "Target +1" or nil end
        _G.GetItemId = function() return 987654321 end
        _G.GetItemLink = function() return "item" end
        _G.IsESOPlusSubscriber = function() return false end
        local entries = { { itemId = 987654321, link = "item", icon = "icon", count = 2 } }
        this.Scanning = { GetBagContents = function() return entries end }
        local warnings = 0
        this.Utils = {
            FormatBigNumber = tostring,
            UserWarning = function() warnings = warnings + 1 end,
        }
        this.UpdateRulePatterns("default", { "Target +1" })
        this.UpdateRuleFlag("default", "notify", true)
        local cache = this.GetRuntimeRules()
        assert(this.ItemMatchesRuntimeRule("item", cache.default), "Literal punctuation matches")
        assert(not this.ItemMatchesRuntimeRule("missing", cache.default), "Missing item never matches")
        local snapshot = this.GetMasterItemList({}, this.GetActiveTrackedRules(), { BAG_BACKPACK })
        Equal(#snapshot.ruleIndex.default, 1, "Scan uses compiled rule")
        this.HandleTrackedItemInventoryUpdate(BAG_BACKPACK, 1, 1)
        Equal(warnings, 1, "Notification uses compiled rule")
        this.UpdateRulePatterns("default", { "Other*" })
        this.HandleTrackedItemInventoryUpdate(BAG_BACKPACK, 1, 1)
        Equal(warnings, 1, "Notification sees pattern change before any scan")
        this.UpdateRulePatterns("default", { "Target*" })
        this.UpdateRuleFlag("default", "isHidden", true)
        this.HandleTrackedItemInventoryUpdate(BAG_BACKPACK, 1, 1)
        Equal(warnings, 1, "Hidden groups do not notify")
        this.UpdateRuleFlag("default", "isHidden", false)
        this.HandleTrackedItemInventoryUpdate(BAG_BACKPACK, 1, 1)
        Equal(warnings, 2, "Unhiding takes effect immediately")
    end)

    Add("Group lifecycle mutations invalidate and clear only the active profile", function()
        local initial = this.GetRuntimeRules()
        this.CreateCustomRule("custom", "Custom")
        local created = this.GetRuntimeRules()
        assert(created ~= initial and created.custom, "Creation must invalidate")
        Equal(next(created.custom.patterns), nil, "Custom group starts empty")
        Equal(this.accountWide.trackedRules.custom.display, nil, "Custom defaults are not copied")
        this.UpdateRulePatterns("custom", { "custom*" })
        this.DeleteCustomRule("custom")
        Equal(this.GetRuntimeRules().custom, nil, "Deletion must invalidate")
        this.UpdateRuleProperty("default", "displayName", "Changed")
        this.UpdateRulePatterns("default", {})
        this.UpdateRuleFlag("default", "notify", true)
        this.UpdateRuleFlag("default", "isHidden", true)
        assert(this.HasRuleOverrides("default"), "Edited group has overrides")
        this.ResetRule("default")
        Equal(this.accountWide.trackedRules.default, nil, "Reset clears every override")
        List(this.GetRuntimeRules().default.patterns, { "a", "b", "c" }, "Reset restores patterns")
        Equal(this.GetRuntimeRules().default.displayName, "Default", "Reset restores name")
        Equal(this.GetRuntimeRules().default.display.notify, false, "Reset restores flags")
        assert(not this.HasRuleOverrides("default"), "Reset removes meaningful override")
        this.SetUseCharacterItemList(true)
        this.CreateCustomRule("custom", "Character custom")
        this.SetUseCharacterItemList(false)
        Equal(this.GetRuntimeRules().custom, nil, "Character group does not leak to account")
        assert(not pcall(this.DeleteCustomRule, "default"), "Built-ins cannot be deleted")
        assert(not pcall(this.CreateCustomRule, "default", "Duplicate"), "Built-ins cannot be replaced")
        assert(not pcall(this.ResetRule, "custom"), "Custom groups cannot be reset as built-ins")
    end)

    Add("Untouched defaults allocate no saved rule data", function()
        local matcher = this.ItemMatchesRuntimeRule
        Equal(type(matcher), "function", "Runtime matcher exists before cache construction")
        local cache = this.GetRuntimeRules()
        Equal(this.ItemMatchesRuntimeRule, matcher, "Compiling patterns must not redefine the matcher")
        Equal(next(this.accountWide.trackedRules), nil, "Reading defaults must not persist rules")
        List(cache.default.patterns, { "a", "b", "c" }, "Defaults are sorted")
        this.UpdateRuleFlag("default", "show", true)
        this.UpdateRuleProperty("default", "displayName", "Default")
        this.UpdateRulePatterns("default", { "c", "a", "b", "a" })
        Equal(next(this.accountWide.trackedRules), nil, "Writing baseline values must not persist rules")
        this.UpdateRuleProperty("default", "displayName", "Renamed")
        this.preLoadedRulesets.default.display.notify = true
        this.preLoadedRulesets.default.patterns = { "new default" }
        this.InvalidateRuleCache()
        local updated = this.GetRuntimeRules().default
        Equal(updated.displayName, "Renamed", "Explicit name is preserved")
        Equal(updated.display.notify, true, "Unmodified flag follows updated baseline")
        List(updated.patterns, { "new default" }, "Unmodified patterns follow updated baseline")
    end)

    Add("Reconciled pattern deltas obey set invariants across repeated edits", function()
        local candidates = { "a", "b", "c", "d", "e", "f" }
        for iteration = 0, 63 do
            local edited, expected, added, removed = {}, {}, {}, {}
            for index, pattern in ipairs(candidates) do
                local included = math.floor(iteration / (2 ^ (index - 1))) % 2 == 1
                if included then
                    table.insert(edited, pattern)
                    table.insert(edited, pattern)
                    table.insert(expected, pattern)
                    if index > 3 then table.insert(added, pattern) end
                elseif index <= 3 then
                    table.insert(removed, pattern)
                end
            end
            this.UpdateRulePatterns("default", edited)
            local saved = this.accountWide.trackedRules.default or {}
            List(saved.addedPatterns or {}, added, "Exact addition delta " .. iteration)
            List(saved.removedPatterns or {}, removed, "Exact removal delta " .. iteration)
            List(this.GetRuntimeRules().default.patterns, expected, "Exact effective set " .. iteration)
            for key in pairs(saved) do
                assert(key == "addedPatterns" or key == "removedPatterns", "Unexpected saved field: " .. key)
            end
        end
    end)

    Add("Cached synthetic scans and inventory bursts stay within thresholds", function()
        _G.BAG_BACKPACK, _G.BAG_BANK, _G.BAG_VIRTUAL = 1, 2, 3
        _G.GetItemLinkName = function(link) return link end
        _G.GetItemId = function(_, slotIndex) return 990000 + slotIndex end
        _G.GetItemLink = function(_, slotIndex) return "Synthetic Item " .. slotIndex end
        _G.IsESOPlusSubscriber = function() return false end
        local entries = {}
        for index = 1, 100 do
            entries[index] = { itemId = 990000 + index, link = "Synthetic Item " .. index, icon = "icon", count = 1 }
        end
        this.Scanning = { GetBagContents = function() return entries end }
        local warnings = 0
        this.Utils = { FormatBigNumber = tostring, UserWarning = function() warnings = warnings + 1 end }
        this.preLoadedRulesets = {}
        for index = 1, 20 do
            this.preLoadedRulesets["synthetic_" .. index] = {
                patterns = { "Synthetic Item *" }, display = { show = true, notify = true },
            }
        end
        local cache = this.GetRuntimeRules()
        local started = GetGameTimeMilliseconds()
        for _ = 1, 20 do
            local snapshot = this.GetMasterItemList({}, this.GetActiveTrackedRules(), { BAG_BACKPACK })
            Equal(#snapshot.ruleIndex.synthetic_1, 100, "All items matched")
            Equal(#snapshot.ruleIndex.synthetic_20, 100, "All rules matched")
        end
        local scanMs = GetGameTimeMilliseconds() - started
        started = GetGameTimeMilliseconds()
        for index = 1, 100 do
            assert(this.ItemMatchesRuntimeRule("Synthetic Item " .. index, cache.synthetic_1), "Burst rule match")
        end
        local matchMs = GetGameTimeMilliseconds() - started
        started = GetGameTimeMilliseconds()
        for index = 1, 100 do this.HandleTrackedItemInventoryUpdate(BAG_BACKPACK, index, 1) end
        local updateMs = GetGameTimeMilliseconds() - started
        Equal(warnings, 100, "Every synthetic update notifies")
        Equal(this.GetRuntimeRules(), cache, "Bursts reuse the cache")
        Equal(next(this.accountWide.trackedRules), nil, "Bursts do not write saved rules")
        local timings = string.format("20 scans: %d/500 ms; 100 matches: %d/100 ms; 100 updates: %d/200 ms",
            scanMs, matchMs, updateMs)
        assert(scanMs <= 500 and matchMs <= 100 and updateMs <= 200, timings)
        return timings
    end)

    return tests
end
