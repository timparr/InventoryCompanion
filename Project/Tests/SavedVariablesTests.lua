local function LoadAddon(saved)
    local calls = { constructors = 0, modules = 0, strings = 0 }
    EVENT_ADD_ON_LOADED = 1
    EVENT_MANAGER = {
        RegisterForEvent = function(_, _, _, callback) calls.onLoaded = callback end,
        UnregisterForEvent = function() end,
    }
    SLASH_COMMANDS = {}
    ZO_CreateStringId = function() calls.strings = calls.strings + 1 end
    d = function() end
    assert(loadstring(SavedVariablesInitSource))()
    local addon = InventoryCompanion
    _G[addon.SettingsName] = saved
    assert(loadstring(SavedVariablesDatabaseSource))()
    addon.preLoadedRulesets = {
        builtin = {
            displayName = "Built-in", patterns = { "a", "b" },
            display = { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false },
        },
    }
    addon.defaultsAccount = { trackedRules = {}, bankItemDelay = 100 }
    addon.defaultsCharacter = { trackedRules = {}, useCharacterItemList = false }
    for _, method in ipairs({
        "InitCutsceneTicker", "InitContextMenus", "InitializeCurrencyHelper", "InitializeProgressBarResources",
        "InitResourceProgressBars", "InitItemTrackerPanel", "InitCurrencyPanel", "CreateSettingsPanel", "UpdateEventRegistry",
    }) do
        addon[method] = function() calls.modules = calls.modules + 1 end
    end
    local function NewProfile(_, name, version, namespace, defaults, key)
        calls.constructors = calls.constructors + 1
        assert(namespace == nil and version == 2, "Constructors must request schema version 2 without a namespace")
        local root = _G[name]
        if root == nil then root = {}; _G[name] = root end
        root.Default = root.Default or {}
        root.Default.account = root.Default.account or {}
        local profile = root.Default.account[key]
        if profile == nil then profile = {}; root.Default.account[key] = profile end
        -- Reproduce ZOS's destructive version handling, including its downgrade overwrite.
        if profile.version == nil or profile.version < version then
            for field in pairs(profile) do profile[field] = nil end
        end
        profile.version = version
        for field, value in pairs(defaults) do
            if profile[field] == nil then profile[field] = type(value) == "table" and {} or value end
        end
        return profile
    end
    ZO_SavedVars = {
        NewAccountWide = function(self, name, version, namespace, defaults)
            return NewProfile(self, name, version, namespace, defaults, "$AccountWide")
        end,
        NewCharacterIdSettings = function(self, name, version, namespace, defaults)
            return NewProfile(self, name, version, namespace, defaults, "character")
        end,
    }
    calls.initialize = function() calls.onLoaded(EVENT_ADD_ON_LOADED, addon.Name) end
    return addon, calls
end

local function AssertStopped(addon, calls, expectedMessage)
    local ok, message = pcall(calls.initialize)
    assert(not ok and tostring(message):find(expectedMessage, 1, true), "Expected initialization error: " .. tostring(message))
    assert(calls.constructors == 0 and calls.modules == 0 and calls.strings == 0,
        "Rejected data must stop initialization before constructors, modules, or UI setup")
    assert(not addon.state.isLoaded and addon.accountWide == nil and addon.character == nil,
        "Rejected addon must remain unloaded")
end

function GetSavedVariablesTests()
    return {
        {
            name = "Fresh installations initialize schema version 2",
            run = function()
                for _, fixture in ipairs({ {}, { Default = {} }, { Default = { account = {} } } }) do
                    local addon, calls = LoadAddon(fixture)
                    calls.initialize()
                    assert(addon.SettingsVersion == 2 and addon.accountWide.version == 2 and addon.character.version == 2)
                    assert(addon.state.isLoaded and calls.constructors == 2 and calls.modules == 9)
                end
                local addon, calls = LoadAddon(nil)
                calls.initialize()
                assert(addon.state.isLoaded and addon.accountWide.version == 2 and addon.character.version == 2)
            end,
        },
        {
            name = "Startup migrates all version 1 profiles before destructive ZOS loading",
            run = function()
                local items = { [123] = { link = "item" } }
                local bank = { version = 1, trackedItems = items, bankItemDelay = 321, unrelated = { keep = true },
                    trackedRules = { builtin = { displayName = "Renamed", patterns = { "b", "c" }, display = { notify = true, show = true } } } }
                local character = { version = 1, useCharacterItemList = true, trackedRules = {
                    custom = { displayName = "Custom", patterns = { "Custom*" } },
                    builtin = { displayName = "Built-in", patterns = { "a", "b" } },
                } }
                local inactive = { version = 1, trackedRules = { custom = { patterns = { "Other*" } } }, ["$LastCharacterName"] = "Other" }
                local otherAccount = { version = 1, trackedRules = {} }
                local saved = { Default = { account = { ["$AccountWide"] = bank, character = character, other = inactive },
                    otherAccount = { ["$AccountWide"] = otherAccount } }, unrelatedNamespace = { keep = true } }
                local addon, calls = LoadAddon(saved)
                calls.initialize()
                assert(addon.state.isLoaded and calls.constructors == 2 and calls.modules == 9)
                for _, profile in ipairs({ bank, character, inactive, otherAccount }) do
                    assert(profile.version == 2, "Every account/character profile must be upgraded")
                end
                local rule = bank.trackedRules.builtin
                assert(rule.patterns == nil and table.concat(rule.addedPatterns, ",") == "c" and table.concat(rule.removedPatterns, ",") == "a")
                assert(rule.displayName == "Renamed" and rule.display.notify and rule.display.show == nil)
                assert(character.trackedRules.builtin == nil and character.trackedRules.custom.addedPatterns[1] == "Custom*")
                assert(inactive.trackedRules.custom.addedPatterns[1] == "Other*" and inactive["$LastCharacterName"] == "Other")
                assert(bank.trackedItems == items and bank.bankItemDelay == 321 and bank.unrelated.keep and saved.unrelatedNamespace.keep)
                assert(addon.GetRuntimeRules().custom.patterns[1] == "Custom*", "Selected character must resolve migrated patterns")
                addon.SetUseCharacterItemList(false)
                assert(table.concat(addon.GetRuntimeRules().builtin.patterns, ",") == "b,c", "Account effective patterns must survive")
                local migratedRules = bank.trackedRules
                addon.PrepareSavedVariables()
                assert(bank.trackedRules == migratedRules, "Repeated preparation must not remigrate version 2 data")
                local reloaded, reloadCalls = LoadAddon(saved)
                reloadCalls.initialize()
                assert(reloaded.state.isLoaded and bank.trackedRules == migratedRules, "A reload must preserve migrated tables")
            end,
        },
        {
            name = "Already converted development deltas and empty custom groups survive version migration",
            run = function()
                local profile = { version = 1, trackedRules = {
                    builtin = { addedPatterns = { "c" }, removedPatterns = { "a" }, display = { isHidden = true } },
                    empty = {},
                } }
                local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = profile } } })
                calls.initialize()
                assert(profile.version == 2 and profile.trackedRules.empty and profile.trackedRules.builtin.display.isHidden)
                assert(table.concat(addon.GetRuntimeRules().builtin.patterns, ",") == "b,c")
                assert(#addon.GetRuntimeRules().empty.patterns == 0)
            end,
        },
        {
            name = "Higher saved versions refuse loading even in inactive characters or other accounts",
            run = function()
                for _, location in ipairs({ "$AccountWide", "character", "inactive", "otherAccount" }) do
                    local originalRules = { builtin = { patterns = { "b", "c" }, display = { show = true } } }
                    local legacy = { version = 1, trackedRules = originalRules }
                    local future = { version = 3, trackedRules = { unknownFutureSchema = true }, keep = true }
                    local saved = { Default = { account = { legacy = legacy } } }
                    if location == "otherAccount" then
                        saved.Default.otherAccount = { ["$AccountWide"] = future }
                    else
                        saved.Default.account[location] = future
                    end
                    local addon, calls = LoadAddon(saved)
                    AssertStopped(addon, calls, "supports version 2")
                    assert(future.version == 3 and future.keep and future.trackedRules.unknownFutureSchema)
                    assert(legacy.version == 1 and legacy.trackedRules == originalRules and originalRules.builtin.patterns[1] == "b")
                    assert(originalRules.builtin.display.show, "Downgrade refusal must not partially normalize old data")
                end
            end,
        },
        {
            name = "Downgrade guard uses the addon's expected version rather than a fixed threshold",
            run = function()
                local profile = { version = 2, trackedRules = { custom = { addedPatterns = { "Keep*" } } } }
                local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = profile } } })
                addon.SettingsVersion = 1
                AssertStopped(addon, calls, "supports version 1")
                assert(profile.version == 2 and profile.trackedRules.custom.addedPatterns[1] == "Keep*")
            end,
        },
        {
            name = "Malformed saved versions and namespace containers fail without reset",
            run = function()
                for _, version in ipairs({ false, "2", 0, -1, 1.5, math.huge, 0 / 0 }) do
                    local profile = { version = version, keep = true }
                    local addon, calls = LoadAddon({ Default = { account = { character = profile } } })
                    AssertStopped(addon, calls, ".version must be a positive integer")
                    assert(profile.keep and (profile.version == version or version ~= version))
                end
                local profile = { keep = true }
                local addon, calls = LoadAddon({ Default = { account = { character = profile } } })
                AssertStopped(addon, calls, ".version must be a positive integer")
                assert(profile.version == nil and profile.keep, "Existing unversioned data must not be silently erased")
                for _, malformed in ipairs({ false, { Default = false }, { Default = { account = false } },
                    { Default = { account = { character = false } } } }) do
                    addon, calls = LoadAddon(malformed)
                    AssertStopped(addon, calls, "must be a table")
                end
            end,
        },
        {
            name = "Failed migration validates every profile before publishing changes",
            run = function()
                for _, version in ipairs({ 1, 2 }) do
                    local rules = { builtin = { displayName = "Built-in", patterns = { "a", "b" }, display = { show = true } } }
                    local valid = { version = 1, trackedRules = rules }
                    local invalid = { version = version, trackedRules = { custom = { patterns = { [2] = "hole" } } } }
                    local addon, calls = LoadAddon({ Default = { account = { valid = valid, invalid = invalid } } })
                    AssertStopped(addon, calls, "must not contain holes")
                    assert(valid.version == 1 and valid.trackedRules == rules and rules.builtin.patterns[1] == "a")
                    assert(rules.builtin.display.show and rules.builtin.displayName == "Built-in")
                    assert(invalid.version == version and invalid.trackedRules.custom.patterns[2] == "hole")
                end
            end,
        },
        {
            name = "Malformed maintained baselines abort migration without writes",
            run = function()
                local profile = { version = 1, trackedRules = { builtin = { patterns = { "a" } } } }
                local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = profile } } })
                addon.preLoadedRulesets.builtin.display.notify = nil
                AssertStopped(addon, calls, ".display.notify must be boolean")
                assert(profile.version == 1 and profile.trackedRules.builtin.patterns[1] == "a")
            end,
        },
        {
            name = "Missing optional legacy rules are initialized without losing unrelated settings",
            run = function()
                local profile = { version = 1, bankItemDelay = 432, keep = true }
                local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = profile } } })
                calls.initialize()
                assert(addon.state.isLoaded and profile.version == 2 and next(profile.trackedRules) == nil)
                assert(profile.bankItemDelay == 432 and profile.keep)
            end,
        },
    }
end
