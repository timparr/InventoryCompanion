local function LoadAddon(saved)
    function GetDisplayName() return "account" end
    local calls = { constructors = 0, modules = 0, strings = 0, warnings = {} }
    EVENT_ADD_ON_LOADED = 1
    EVENT_MANAGER = {
        RegisterForEvent = function(_, _, _, callback) calls.onLoaded = callback end,
        UnregisterForEvent = function() end,
    }
    SLASH_COMMANDS = {}
    ZO_CreateStringId = function() calls.strings = calls.strings + 1 end
    d = function(message) calls.warnings[#calls.warnings + 1] = message end
    assert(loadstring(SavedVariablesInitSource))()
    assert(loadstring(SavedVariablesConstantsSource))()
    local addon = InventoryCompanion
    _G[addon.SettingsName] = saved
    assert(loadstring(SavedVariablesDatabaseSource))()
    assert(loadstring(SavedVariablesIntegrationSource))()
    addon.preLoadedRulesets = {
        builtin = {
            displayName = "Built-in", patterns = { "a", "b" },
            display = { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false },
        },
    }
    addon.defaultsAccount = { trackedRules = {}, debug = {}, bankItemDelay = 100, guildBankPartialWithdrawEnabled = true,
        trackerMaxRows = 20, trackerTitleSize = 20,
        autoCategoryTimingThresholdMs = 500 }
    addon.defaultsCharacter = { itemListInitialized = false, useCharacterItemList = false }
    for _, method in ipairs({
        "InitCutsceneTicker", "InitContextMenus", "InitializeCurrencyHelper", "InitializeProgressBarResources",
        "InitResourceProgressBars", "InitItemTrackerPanel", "InitCurrencyPanel", "CreateSettingsPanel", "UpdateEventRegistry",
    }) do
        addon[method] = function() calls.modules = calls.modules + 1 end
    end
    local function NewProfile(_, name, version, namespace, defaults, key)
        calls.constructors = calls.constructors + 1
        assert(namespace == nil and version == 10, "Constructors must request schema version 10 without a namespace")
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
            name = "Full profile copy replaces every preference map and preserves destination metadata and account controls",
            run = function()
                local source = { version = 10, itemListInitialized = true, trackedRules = { source = {} },
                    trackedItems = {}, trackerOffsetX = 77, currencyPreferences = {},
                    bankItemDelay = 999, autoCategoryIntegrationEnabled = true }
                local destination = { version = 10, useCharacterItemList = true, itemListInitialized = true,
                    trackedRules = { destination = {} }, trackedItems = {},
                    currencyPreferences = { [2] = { showCompact = false } },
                    progressBarPreferences = { ["capacity:bank"] = { showBar = false } },
                    ["$LastCharacterName"] = "Destination", unrelated = { keep = true } }
                local account = { version = 10, bankItemDelay = 321, autoCategoryIntegrationEnabled = false }
                local addon, calls = LoadAddon({ Default = { account = {
                    ["$AccountWide"] = account, character = destination, source = source,
                } } })
                calls.initialize()
                assert(addon.CopyProfile("source"))
                assert(destination.trackedRules.source and not destination.trackedRules.destination
                    and next(destination.currencyPreferences) == nil and next(destination.progressBarPreferences) == nil)
                assert(destination.trackerOffsetX == 77 and destination["$LastCharacterName"] == "Destination"
                    and destination.version == 10 and destination.useCharacterItemList and destination.unrelated.keep)
                assert(destination.bankItemDelay == nil and destination.autoCategoryIntegrationEnabled == nil
                    and account.bankItemDelay == 321 and account.autoCategoryIntegrationEnabled == false)
                source.currencyPreferences[1] = { showCompact = false }
                assert(destination.currencyPreferences[1] == nil)
                local before = addon.CopySavedValue(destination)
                source.progressBarPreferences = { ["capacity:bag"] = { showBar = "yes" } }
                assert(not pcall(addon.CopyProfile, "source"))
                assert(addon.SavedValuesEqual(destination, before), "Invalid import must not partially replace any fields")
            end,
        },
        {
            name = "Guild-bank partial withdrawal setting defaults on and validates saved booleans before constructors",
            run = function()
                local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = { version = 10 } } } })
                calls.initialize()
                assert(addon.accountWide.guildBankPartialWithdrawEnabled == true)

                local disabledAddon, disabledCalls = LoadAddon({ Default = { account = {
                    ["$AccountWide"] = { version = 10, guildBankPartialWithdrawEnabled = false },
                } } })
                disabledCalls.initialize()
                assert(disabledAddon.accountWide.guildBankPartialWithdrawEnabled == false)

                local invalidAddon, invalidCalls = LoadAddon({ Default = { account = {
                    ["$AccountWide"] = { version = 10, guildBankPartialWithdrawEnabled = "yes" },
                } } })
                AssertStopped(invalidAddon, invalidCalls, "guildBankPartialWithdrawEnabled must be boolean")
            end,
        },
        {
            name = "Schema 10 upgrades every supported source and clears unused character profiles only once",
            run = function()
                for version = 1, 9 do
                    local account = { version = version, trackerOffsetX = 87, trackedRules = { shared = {} },
                        currencyPreferences = { [1] = { showCompact = false } } }
                    local active = { version = version, useCharacterItemList = true,
                        trackedRules = { personal = {} }, trackerOffsetY = 63 }
                    local unused = { version = version, useCharacterItemList = false,
                        trackedRules = { discarded = {} }, trackerOffsetX = 91, unrelated = "keep" }
                    local addon = LoadAddon({ Default = { account = {
                        ["$AccountWide"] = account, character = active, unused = unused,
                    } } })
                    addon.PrepareSavedVariables()
                    assert(account.version == 10 and active.version == 10 and unused.version == 10)
                    assert(active.itemListInitialized and active.trackedRules.personal
                        and active.trackerOffsetX == 87 and active.trackerOffsetY == 63)
                    assert(active.currencyPreferences ~= account.currencyPreferences
                        and active.currencyPreferences[1] ~= account.currencyPreferences[1])
                    assert(unused.trackedRules == nil and unused.trackerOffsetX == nil
                        and unused.itemListInitialized == false and unused.unrelated == "keep")
                    unused.itemListInitialized, unused.trackedRules, unused.trackedItems = true, { retained = {} }, {}
                    unused.trackerOffsetX = 92
                    addon.PrepareSavedVariables()
                    assert(unused.itemListInitialized and unused.trackedRules.retained and unused.trackerOffsetX == 92,
                        "A later reload must retain initialized inactive schema-10 content")
                end
            end,
        },
        {
            name = "Full profile first-use copy and later resume preserve account-only controls and isolation",
            run = function()
                local account = { version = 9, trackedRules = { shared = {} }, trackerOffsetX = 72,
                    bankItemDelay = 321, autoCategoryIntegrationEnabled = false,
                    currencyPreferences = { [1] = { locations = { [1] = { hidden = true } } } } }
                local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = account } } })
                calls.initialize()
                addon.SetUseCharacterItemList(true)
                local character = addon.character
                assert(character.itemListInitialized and character.trackerOffsetX == 72
                    and character.bankItemDelay == nil and character.autoCategoryIntegrationEnabled == nil)
                character.trackerOffsetX = 99
                character.currencyPreferences[1].locations[1].hidden = false
                addon.SetUseCharacterItemList(false)
                assert(addon.GetSettingsProfile() == account and account.trackerOffsetX == 72
                    and account.currencyPreferences[1].locations[1].hidden)
                account.trackerOffsetX = 120
                addon.SetUseCharacterItemList(true)
                assert(addon.GetSettingsProfile() == character and character.trackerOffsetX == 99
                    and character.currencyPreferences[1].locations[1].hidden == false)
                assert(account.bankItemDelay == 321 and account.autoCategoryIntegrationEnabled == false)
            end,
        },
        {
            name = "Malformed inactive full-profile preferences abort every migration before constructors",
            run = function()
                for _, bad in ipairs({
                    { currencyPreferences = { [1] = { locations = { [1] = { hidden = "yes" } } } } },
                    { progressBarPreferences = { ["capacity:bag"] = { warningThreshold = 2 } } },
                    { progressBarAlertColors = { warning = { r = 2, g = 0, b = 0, a = 1 } } },
                    { trackerOffsetX = 0 / 0 },
                }) do
                    local account = { version = 1, trackedRules = { builtin = { patterns = { "b" } } } }
                    bad.version, bad.itemListInitialized = 10, true
                    local saved = { Default = { account = { ["$AccountWide"] = account, inactive = bad } } }
                    local addon, calls = LoadAddon(saved)
                    local rules = account.trackedRules
                    AssertStopped(addon, calls, "Saved profile.")
                    assert(account.version == 1 and account.trackedRules == rules
                        and rules.builtin.patterns[1] == "b" and bad.version == 10)
                end
            end,
        },
        {
            name = "Actual schema-9 build rejects schema-10 full profiles in every location without mutation",
            run = function()
                for _, location in ipairs({ "$AccountWide", "inactive", "otherAccount" }) do
                    local profile = { version = 10, itemListInitialized = true, trackerOffsetX = 83,
                        currencyPreferences = { [1] = { showCompact = false } }, trackedRules = { keep = {} } }
                    local saved = { Default = { account = {} } }
                    if location == "otherAccount" then
                        saved.Default.other = { inactive = profile }
                    else
                        saved.Default.account[location] = profile
                    end
                    local addon, calls = LoadAddon(saved)
                    local before, equal = addon.CopySavedValue(saved), addon.SavedValuesEqual
                    assert(loadstring(Schema9InitSource))()
                    assert(loadstring(Schema9ConstantsSource))()
                    assert(loadstring(Schema9DatabaseSource))()
                    local old = InventoryCompanion
                    _G[old.SettingsName] = saved
                    assert(old.SettingsVersion == 9)
                    local ok, message = pcall(old.PrepareSavedVariables)
                    assert(not ok and tostring(message):find("supports version 9", 1, true))
                    assert(calls.constructors == 0 and equal(saved, before),
                        "Downgrade refusal must leave the entire saved tree unchanged")
                end
            end,
        },
        {
            name = "Schema 9 migrates all profiles and backups non-destructively and preserves moved Other on reload",
            run = function()
                local function Profile()
                    return {
                        version = 8, unrelated = { keep = true }, useCharacterItemList = true,
                        trackedRules = {
                            custom = { autoCategoryEnabled = true, addedPatterns = { "*" } },
                            dormant = { displayName = "Dormant", display = { notifyChat = true } },
                        },
                        autoCategoryOrder = { contexts = { bank = {
                            display = { "ic:custom", "ac:Sets", "ac:Maps" },
                            matching = { "ac:Sets", "ic:custom", "ac:Maps" },
                            hidden = { ["ac:Maps"] = true }, displayPositions = { ["ac:Maps"] = 2 },
                        } } },
                    }
                end
                local account, character, inactive = Profile(), Profile(), Profile()
                account.accountWideListBackup = {
                    formatVersion = 1, trackedRules = { dormant = {} }, trackedItems = {},
                    autoCategoryOrder = { contexts = {} },
                }
                local rules, unrelated = account.trackedRules, account.unrelated
                local addon, calls = LoadAddon({ Default = {
                    account = { ["$AccountWide"] = account, character = character },
                    other = { inactive = inactive },
                } })
                addon.PrepareSavedVariables()
                assert(calls.constructors == 0 and account.trackedRules == rules and account.unrelated == unrelated)
                for _, profile in ipairs({ account, character, inactive }) do
                    assert(profile.version == 10)
                    for _, context in ipairs(addon.AutoCategoryIntegration.GetContexts()) do
                        local order = profile.autoCategoryOrder.contexts[context.key]
                        assert(not order.hidden["ic:custom"] and order.hidden["ic:dormant"] and order.hidden["ic:builtin"])
                        assert(order.display[1] == "ic:custom")
                        assert(order.display[#order.display] == "ic:dormant"
                            and order.matching[#order.matching] == "ic:dormant")
                    end
                    local bank = profile.autoCategoryOrder.contexts.bank
                    assert(table.concat(bank.display, ",") ==
                        "ic:custom,ac:Sets,ic:__ic_other,ac:Maps,ic:builtin,ic:dormant")
                    assert(table.concat(bank.matching, ",") ==
                        "ac:Sets,ic:custom,ac:Maps,ic:builtin,ic:dormant")
                    assert(bank.hidden["ac:Maps"] and bank.displayPositions["ac:Maps"] == 2)
                end
                assert(account.accountWideListBackup.autoCategoryOrder.contexts.bank.hidden["ic:dormant"])
                local bank = account.autoCategoryOrder.contexts.bank
                table.remove(bank.display, 3)
                table.insert(bank.display, 1, "ic:__ic_other")
                bank.hidden["ic:custom"] = true
                addon.PrepareSavedVariables()
                assert(account.autoCategoryOrder.contexts.bank.display[1] == "ic:__ic_other"
                    and account.autoCategoryOrder.contexts.bank.hidden["ic:custom"])
                calls.initialize()
                assert(addon.state.isLoaded and account.trackedRules == rules)
            end,
        },
        {
            name = "Actual schema 4 through 8 builds reject schema 9 before constructors or migration",
            run = function()
                for _, sources in ipairs({
                    { LegacySavedVariablesInitSource, LegacySavedVariablesConstantsSource, LegacySavedVariablesDatabaseSource, 4 },
                    { Schema5InitSource, SavedVariablesConstantsSource, Schema5DatabaseSource, 5 },
                    { Schema6InitSource, Schema6ConstantsSource, Schema6DatabaseSource, 6 },
                    { Schema7InitSource, Schema7ConstantsSource, Schema7DatabaseSource, 7 },
                    { Schema8InitSource, Schema8ConstantsSource, Schema8DatabaseSource, 8 },
                }) do
                    for _, location in ipairs({ "$AccountWide", "character", "inactive", "otherAccount" }) do
                        local order = { contexts = { backpack = {
                            display = { "ic:__ic_other", "ac:Maps", "ic:custom" }, matching = { "ac:Maps", "ic:custom" },
                            hidden = { ["ac:Maps"] = true, ["ic:custom"] = true }, displayPositions = { ["ac:Maps"] = 4 },
                        } } }
                        local future = { version = 9, trackedRules = { custom = {} },
                            autoCategoryOrder = order, itemListInitialized = true }
                        local legacy = { version = 1, trackedRules = { builtin = { patterns = { "Keep*" } } } }
                        local saved = { Default = { account = { legacy = legacy } } }
                        if location == "otherAccount" then saved.Default.other = { character = future }
                        else saved.Default.account[location] = future end
                        local _, calls = LoadAddon(saved)
                        assert(loadstring(sources[1]))()
                        local old = InventoryCompanion
                        assert(loadstring(sources[2]))()
                        assert(loadstring(sources[3]))()
                        assert(old.SettingsVersion == sources[4])
                        local ok, message = pcall(old.PrepareSavedVariables)
                        assert(not ok and tostring(message):find("supports version " .. sources[4], 1, true))
                        assert(calls.constructors == 0 and future.version == 9 and future.autoCategoryOrder == order)
                        assert(order.contexts.backpack.hidden["ac:Maps"] and order.contexts.backpack.displayPositions["ac:Maps"] == 4)
                        assert(order.contexts.backpack.hidden["ic:custom"]
                            and order.contexts.backpack.display[1] == "ic:__ic_other")
                        assert(legacy.version == 1 and legacy.trackedRules.builtin.patterns[1] == "Keep*")
                    end
                end
            end,
        },
        {
            name = "Schema 9 migration validates exclusions and remembered positions in every saved profile",
            run = function()
                local valid = { version = 7, trackedRules = { custom = {} }, unrelated = { keep = true } }
                for _, bad in ipairs({
                    { hidden = "bad" }, { hidden = { ["ic:missing"] = true } },
                    { hidden = { ["ac:Maps"] = 1 } }, { displayPositions = { ["ac:Maps"] = 0 } },
                    { displayPositions = { ["ic:missing"] = 2 } }, { displayPositions = { ["ac:Maps"] = math.huge } },
                    { hidden = { ["ic:__ic_other"] = true } },
                    { matching = { "ic:__ic_other" } },
                    { display = { "ic:__ic_other", "ic:__ic_other" } },
                }) do
                    bad.display, bad.matching = bad.display or {}, bad.matching or {}
                    local broken = { version = 7, useCharacterItemList = true, trackedRules = { custom = {} },
                        autoCategoryOrder = { contexts = { backpack = bad } } }
                    local order = broken.autoCategoryOrder
                    local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = valid },
                        other = { inactive = broken } } })
                    addon.PrepareSavedVariables()
                    assert(addon.AutoCategoryIntegration.IsFaulted() and calls.constructors == 0)
                    assert(broken.autoCategoryOrder == order and order.contexts.backpack == bad)
                    assert(broken.version == 10 and valid.version == 10 and valid.unrelated.keep)
                end
            end,
        },
        {
            name = "First-time IC scope switches copy complete profiles once and preserve initialized destinations",
            run = function()
                for _, characterSource in ipairs({ false }) do
                    local source = {
                        version = 7, trackedRules = { custom = { autoCategoryEnabled = true, addedPatterns = { "*" },
                            display = { notify = true, notifyChat = false, notifyHud = true, showBackpack = false, showBank = true } } },
                        trackedItems = { [10] = { link = "item", display = { isExpanded = false, notifyHud = true }, extra = "keep" } },
                        autoCategoryIntegrationEnabled = true, autoCategorySetupComplete = true,
                        autoCategoryOrder = { contexts = { backpack = {
                            display = { "ic:custom", "ac:Maps" }, matching = { "ic:custom", "ac:Maps" },
                            hidden = { ["ac:Maps"] = true }, displayPositions = { ["ac:Maps"] = 4 },
                        } } },
                    }
                    local account = {}
                    if characterSource then
                        source.useCharacterItemList = true
                        account.character = source
                    else
                        account["$AccountWide"] = source
                    end
                    local addon, calls = LoadAddon({ Default = { account = account } })
                    calls.initialize()
                    local sourceProfile = addon.GetAutoCategoryProfile()
                    local destination = characterSource and addon.accountWide or addon.character
                    destination.unrelated = "preserved"
                    addon.SetUseCharacterItemList(not characterSource)
                    assert(addon.GetAutoCategoryProfile() == destination and destination.itemListInitialized)
                    assert(destination.trackedRules.custom.autoCategoryEnabled and destination.autoCategorySetupComplete)
                    local display = addon.GetRuntimeRules().custom.display
                    assert(display.notifyChat == false and display.notifyHud == true)
                    assert(destination.trackedItems[10].display.isExpanded == false
                        and destination.trackedItems[10].extra == "keep" and destination.unrelated == "preserved")
                    local order = destination.autoCategoryOrder.contexts.backpack
                    assert(order.hidden["ac:Maps"] and order.displayPositions["ac:Maps"] == 4)
                    order.hidden["ac:Maps"] = nil
                    destination.trackedRules.custom.addedPatterns[1] = "changed"
                    assert(sourceProfile.autoCategoryOrder.contexts.backpack.hidden["ac:Maps"]
                        and sourceProfile.trackedRules.custom.addedPatterns[1] == "*")
                    addon.SetUseCharacterItemList(characterSource)
                    addon.SetUseCharacterItemList(not characterSource)
                    assert(destination.trackedRules.custom.addedPatterns[1] == "changed",
                        "Switching back must not copy over an initialized destination")
                end
                local addon, calls = LoadAddon({ Default = { account = {
                    ["$AccountWide"] = { version = 7, trackedRules = { source = {} } },
                    character = { version = 7, trackedRules = { destination = {} }, useCharacterItemList = false },
                } } })
                calls.initialize()
                addon.SetUseCharacterItemList(true)
                assert(addon.character.trackedRules.source and not addon.character.trackedRules.destination
                    and addon.character.autoCategorySetupComplete == nil,
                    "This release clears unused account-mode character content before first-use copying")
            end,
        },
        {
            name = "AutoCategory saved-data slash test is registered only in DEV and dispatches explicit actions",
            run = function()
                InventoryCompanion = { IsDevelopment = false }
                LoadAddon(nil)
                assert(SLASH_COMMANDS["/icactest"] == nil)
                InventoryCompanion.IsDevelopment = true
                local addon = LoadAddon(nil)
                local injected, removed, verified = 0, 0, 0
                local scenarios = {}
                addon.AutoCategoryIntegration.InjectTestAssignment = function(scenario)
                    injected = injected + 1
                    if scenario then scenarios[#scenarios + 1] = scenario end
                end
                addon.AutoCategoryIntegration.RemoveTestAssignment = function() removed = removed + 1 end
                addon.AutoCategoryIntegration.ShowTestVerification = function() verified = verified + 1 end
                SLASH_COMMANDS["/icactest"](" INJECT ")
                for index = 1, 4 do SLASH_COMMANDS["/icactest"]("inject" .. index) end
                SLASH_COMMANDS["/icactest"]("inject5")
                SLASH_COMMANDS["/icactest"]("remove")
                SLASH_COMMANDS["/icactest"]("verify")
                SLASH_COMMANDS["/icactest"]("")
                assert(injected == 5 and table.concat(scenarios, ",") == "1,2,3,4"
                    and removed == 1 and verified == 1)
                InventoryCompanion.IsDevelopment = false
            end,
        },
        {
            name = "Schema 5 migration preserves configured profiles and leaves unused profiles ready for setup",
            run = function()
                local configured = { version = 5, trackedRules = { custom = { autoCategoryEnabled = true } },
                    autoCategoryIntegrationEnabled = true, unrelated = { keep = true } }
                local ordered = { version = 5, useCharacterItemList = true, trackedRules = { custom = {} }, autoCategoryOrder = { contexts = {
                    backpack = { display = { "ic:custom" }, matching = { "ic:custom" } },
                } } }
                local unused = { version = 5, trackedRules = {}, autoCategoryIntegrationEnabled = true,
                    autoCategoryOrder = { contexts = {
                        backpack = { display = { "ac:New" }, matching = { "ac:New" } },
                    } } }
                local addon = LoadAddon({ Default = { account = {
                    ["$AccountWide"] = configured, inactive = unused,
                }, other = { character = ordered } } })
                local rules = configured.trackedRules
                addon.PrepareSavedVariables()
                assert(configured.version == 10 and configured.autoCategorySetupComplete == true)
                assert(ordered.version == 10 and ordered.autoCategorySetupComplete == true)
                assert(configured.trackedRules == rules and configured.unrelated.keep)
                assert(unused.version == 10 and unused.autoCategorySetupComplete == nil
                    and unused.autoCategoryOrder == nil and unused.itemListInitialized == false)
            end,
        },
        {
            name = "Malformed AutoCategory recovery log is rejected before SavedVariables constructors",
            run = function()
                local log = {
                    {
                        timestamp = 1793641920,
                        dateTime = "2026-11-02 17:52:00",
                        context = "backpack",
                        bagType = 1,
                        index = 4,
                        restored = true,
                        line = { icOwned = true, icRuleKey = "custom_missing" },
                    },
                }
                local profile = { version = 7, debug = { autoCategoryRemovedLines = log } }
                local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = profile } } })
                local ok, message = pcall(calls.initialize)
                assert(not ok and tostring(message):find(".line must be an IC-owned assignment", 1, true))
                assert(calls.constructors == 0 and profile.version == 7
                    and profile.debug.autoCategoryRemovedLines == log,
                    "Malformed recovery data must stop before constructors and remain unchanged")
            end,
        },
        {
            name = "Actual schema-6 build rejects schema-7 list backups without mutation",
            run = function()
                for _, location in ipairs({ "$AccountWide", "inactive", "otherAccount" }) do
                    local backup = {
                        formatVersion = 1, trackedRules = { custom = {} }, trackedItems = {},
                        autoCategoryOrder = { contexts = {} },
                    }
                    local profile = { version = 7, trackedRules = { keep = {} },
                        accountWideListBackup = backup, unrelated = { keep = true } }
                    local saved = { Default = { account = {} } }
                    if location == "otherAccount" then
                        saved.Default.other = { character = profile }
                    else
                        saved.Default.account[location] = profile
                    end
                    local _, calls = LoadAddon(saved)
                    assert(loadstring(Schema6InitSource))()
                    local old = InventoryCompanion
                    _G[old.SettingsName] = saved
                    assert(loadstring(Schema6ConstantsSource))()
                    assert(loadstring(Schema6DatabaseSource))()
                    assert(old.SettingsVersion == 6)
                    local ok, message = pcall(old.PrepareSavedVariables)
                    assert(not ok and tostring(message):find("supports version 6", 1, true))
                    assert(calls.constructors == 0 and profile.version == 7
                        and profile.accountWideListBackup == backup and profile.unrelated.keep,
                        "Schema-6 build must leave schema-7 saved data unchanged")
                end
            end,
        },
        {
            name = "Actual schema-5 build rejects schema-6 setup data before any mutation",
            run = function()
                for _, location in ipairs({ "$AccountWide", "inactive", "otherAccount" }) do
                    local rules = { custom = { autoCategoryEnabled = true } }
                    local order = { contexts = {
                        backpack = { display = { "ic:custom" }, matching = { "ic:custom" } },
                    } }
                    local profile = { version = 6, trackedRules = rules, autoCategoryOrder = order,
                        autoCategorySetupComplete = true, unrelated = { keep = true } }
                    local saved = { Default = { account = {} } }
                    if location == "otherAccount" then
                        saved.Default.other = { character = profile }
                    else
                        saved.Default.account[location] = profile
                    end
                    local _, calls = LoadAddon(saved)
                    assert(loadstring(Schema5InitSource))()
                    local old = InventoryCompanion
                    _G[old.SettingsName] = saved
                    assert(loadstring(SavedVariablesConstantsSource))()
                    assert(loadstring(Schema5DatabaseSource))()
                    assert(old.SettingsVersion == 5)
                    local ok, message = pcall(old.PrepareSavedVariables)
                    assert(not ok and tostring(message):find("supports version 5", 1, true))
                    assert(calls.constructors == 0 and profile.version == 6 and profile.trackedRules == rules
                        and profile.autoCategoryOrder == order and profile.autoCategorySetupComplete
                        and profile.unrelated.keep)
                end
            end,
        },
        {
            name = "Version 2 upgrades every profile without rewriting saved settings before ZOS loading",
            run = function()
                local rules = { builtin = { display = { notify = true, notifyHud = false } } }
                local items = { [10] = { link = "item", display = { show = false, showBank = true }, keep = true } }
                local account = { version = 2, trackedRules = rules, trackedItems = items, keep = { value = 42 } }
                local inactive = { version = 2, trackedRules = {}, bankItemDelay = 456 }
                local other = { version = 2, trackedRules = {} }
                local saved = { Default = { account = { ["$AccountWide"] = account, inactive = inactive },
                    other = { ["$AccountWide"] = other } } }
                local addon, calls = LoadAddon(saved)
                addon.PrepareSavedVariables()
                assert(calls.constructors == 0, "Preparation must precede ZOS loading")
                for _, profile in ipairs({ account, inactive, other }) do
                    assert(profile.version == 10, "Inactive profiles and accounts must upgrade")
                end
                assert(account.trackedRules == rules and account.trackedItems == items,
                    "Version-only migration must preserve saved tables")
                assert(rules.builtin.display.notify and rules.builtin.display.notifyHud == false)
                assert(items[10].display.show == false and items[10].display.showBank and items[10].keep)
                assert(account.keep.value == 42 and inactive.bankItemDelay == 456)
                calls.initialize()
                assert(addon.state.isLoaded and account.trackedItems == items and account.keep.value == 42,
                    "ZOS constructors must not erase upgraded profiles")
                local display = addon.ResolveItemDisplay(items[10].display)
                assert(not display.showBackpack and display.showBank, "Independent bank-only setting must survive")
            end,
        },
        {
            name = "Schema-4 build rejects schema 5 ordering before constructors without mutation",
            run = function()
                local rules = {
                    custom = {
                        display = { notifyChat = true, notifyHud = false },
                        autoCategoryEnabled = true,
                    },
                }
                local order = { contexts = {
                    backpack = { display = { "ic:custom" }, matching = { "ic:custom" } },
                } }
                local profile = {
                    version = 5,
                    trackedRules = rules,
                    autoCategoryIntegrationEnabled = true,
                    autoCategoryOrder = order,
                    keep = true,
                }
                for _, location in ipairs({ "$AccountWide", "inactive", "otherAccount" }) do
                    local saved = { Default = { account = {} } }
                    if location == "otherAccount" then
                        saved.Default.otherAccount = { ["$AccountWide"] = profile }
                    else
                        saved.Default.account[location] = profile
                    end
                    local _, calls = LoadAddon(saved)
                    assert(loadstring(LegacySavedVariablesInitSource))()
                    local old = InventoryCompanion
                    _G[old.SettingsName] = saved
                    assert(loadstring(LegacySavedVariablesConstantsSource))()
                    assert(loadstring(LegacySavedVariablesDatabaseSource))()
                    assert(old.SettingsVersion == 4, "Regression fixture must be the actual pre-feature build")
                    local ok, message = pcall(old.PrepareSavedVariables)
                    assert(not ok and tostring(message):find("supports version 4", 1, true),
                        "Schema-4 build must reject schema 5 before encountering new fields")
                    assert(calls.constructors == 0 and profile.version == 5 and profile.trackedRules == rules
                        and profile.trackedRules.custom.autoCategoryEnabled and profile.autoCategoryOrder == order and profile.keep,
                        "Older build must leave newer saved data untouched")
                end
            end,
        },
        {
            name = "Schema 3 migration initializes independent context orders without completing setup",
            run = function()
                local rules = { custom = { addedPatterns = { "Keep*" } } }
                local profile = { version = 3, trackedRules = rules, keep = { value = 7 } }
                local addon = LoadAddon({ Default = { account = { ["$AccountWide"] = profile } } })
                addon.PrepareSavedVariables()
                assert(profile.version == 10 and profile.trackedRules == rules and profile.keep.value == 7)
                assert(profile.autoCategorySetupComplete == nil)
                assert(profile.autoCategoryIntegrationEnabled == nil and profile.autoCategoryOrder.contexts.backpack,
                    "Migration must initialize context order without enabling the integration")
                assert(profile.autoCategoryOrder.contexts.backpack.display[1] == "ic:__ic_other"
                    and profile.autoCategoryOrder.contexts.backpack.hidden["ic:custom"]
                    and profile.autoCategoryOrder.contexts.backpack.hidden["ic:builtin"])
            end,
        },
        {
            name = "Schema 4 AutoCategory errors preserve integration data and allow core startup",
            run = function()
                local rules = { custom = { autoCategoryEnabled = true, autoCategoryAnchor = "top", autoCategoryRank = 100 } }
                local order = { headingVisibility = { ["heading:test"] = false } }
                local profile = {
                    version = 4, trackedRules = rules, autoCategoryIntegrationEnabled = true,
                    autoCategoryInitialized = true, autoCategoryOrder = order, unrelated = { keep = true },
                }
                local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = profile } } })
                calls.initialize()
                assert(addon.state.isLoaded and calls.constructors == 2 and calls.modules == 9)
                assert(addon.AutoCategoryIntegration.IsFaulted() and not addon.GetAutoCategoryState().enabled)
                assert(calls.warnings[1]:find("WARNING", 1, true)
                    and calls.warnings[1]:find("cannot migrate safely", 1, true))
                assert(profile.version == 10 and profile.trackedRules == rules
                    and profile.autoCategoryOrder == order and profile.unrelated.keep,
                    "Invalid integration settings must be preserved while core schema upgrades safely")
                assert(addon.GetRuntimeRules().custom, "Core rules must remain usable")
                local _, message = addon.AutoCategoryIntegration.GetStatus()
                assert(message:find("cannot migrate safely", 1, true))
                local reloaded, reloadCalls = LoadAddon({ Default = { account = { ["$AccountWide"] = profile } } })
                reloadCalls.initialize()
                assert(reloaded.state.isLoaded and reloaded.AutoCategoryIntegration.IsFaulted())
                assert(profile.autoCategoryOrder == order and profile.trackedRules == rules,
                    "Repeated startup must retain quarantined AutoCategory data")
            end,
        },
        {
            name = "AutoCategory cleanup command is account-restricted and removes only integration data",
            run = function()
                    local function LegacyProfile(version)
                        return {
                            version = version,
                            trackedRules = {
                                custom = {
                                    autoCategoryEnabled = true,
                                    autoCategoryAnchor = "top",
                                    autoCategoryRank = 100,
                                    autoCategoryOverrides = { bank = { rank = 200 } },
                                    displayName = "Keep this group",
                                },
                            },
                            autoCategoryIntegrationEnabled = true,
                            autoCategoryInitialized = true,
                            autoCategoryOrder = { legacy = true },
                            unrelated = { keep = true },
                        }
                    end
                    local accountProfile = LegacyProfile(4)
                    local inactiveProfile = LegacyProfile(4)
                    local otherAccountProfile = {
                        version = 5,
                        trackedRules = { custom = { displayName = "Other account" } },
                        unrelated = { keep = true },
                    }
                    local saved = { Default = {
                        ["@Tim-P"] = { ["$AccountWide"] = accountProfile, inactive = inactiveProfile },
                        ["@Other"] = { ["$AccountWide"] = otherAccountProfile },
                    } }
                    local addon = LoadAddon(saved)
                    local command = SLASH_COMMANDS["/iccleanautocategory"]
                    GetDisplayName = function() return "@Other" end
                    command()
                    assert(accountProfile.autoCategoryOrder.legacy and accountProfile.trackedRules.custom.autoCategoryEnabled,
                        "A different ESO account must not be changed")

                    GetDisplayName = function() return "@TIM-P" end
                    command()
                    for _, profile in ipairs({ accountProfile, inactiveProfile }) do
                        assert(profile.autoCategoryIntegrationEnabled == nil and profile.autoCategoryOrder == nil
                            and profile.autoCategoryInitialized == nil)
                        local rule = profile.trackedRules.custom
                        assert(rule.autoCategoryEnabled == nil and rule.autoCategoryAnchor == nil
                            and rule.autoCategoryRank == nil and rule.autoCategoryOverrides == nil)
                        assert(rule.displayName == "Keep this group" and profile.unrelated.keep)
                        assert(profile.version == 4, "Cleanup must leave normal schema migration to startup")
                    end
                    assert(otherAccountProfile.trackedRules.custom.displayName == "Other account"
                        and otherAccountProfile.unrelated.keep,
                        "Other saved-variable account buckets must be preserved")

                    addon.PrepareSavedVariables()
                    assert(accountProfile.version == 10 and inactiveProfile.version == 10,
                        "Cleaned schema-4 profiles should migrate normally on restart")
                    assert(accountProfile.autoCategoryOrder.contexts.backpack
                        and not accountProfile.trackedRules.custom.autoCategoryEnabled)
            end,
        },
        {
            name = "Malformed AutoCategory fields disable only integration and preserve every profile",
            run = function()
                local malformedProfiles = {
                    { version = 3, trackedRules = { bad = { autoCategoryEnabled = 1 } } },
                    { version = 3, trackedRules = { bad = { autoCategoryAnchor = "top" } } },
                    { version = 3, trackedRules = {
                        a = { autoCategoryAnchor = "top", autoCategoryRank = 100 },
                        b = { autoCategoryAnchor = "heading:x", autoCategoryRank = 100 },
                    } },
                    { version = 3, autoCategoryOrder = {
                        overrides = { unknown_context = { headings = {} } },
                    } },
                    { version = 3, autoCategoryOrder = {
                        headingVisibility = { ["heading:x"] = "hidden" },
                    } },
                    { version = 6, autoCategorySetupComplete = "yes" },
                }
                for _, broken in ipairs(malformedProfiles) do
                    broken.useCharacterItemList = true
                    local untouched = { version = 3, useCharacterItemList = true,
                        trackedRules = { keep = { addedPatterns = { "Keep*" } } } }
                    local saved = { Default = { account = { invalid = broken, untouched = untouched } } }
                    local addon, calls = LoadAddon(saved)
                    calls.initialize()
                    assert(addon.state.isLoaded and calls.constructors == 2)
                    assert(addon.AutoCategoryIntegration.IsFaulted())
                    assert(broken.version == 10 and untouched.version == 10
                        and untouched.trackedRules.keep.addedPatterns[1] == "Keep*",
                        "Integration errors must not erase unrelated profile data")
                end
            end,
        },
        {
            name = "Incompatible AutoCategory at load warns while core modules finish initializing",
            run = function()
                local previousAutoCategory = AutoCategory
                AutoCategory = {}
                local addon, calls = LoadAddon(nil)
                calls.initialize()
                AutoCategory = previousAutoCategory
                assert(addon.state.isLoaded and calls.constructors == 2 and calls.modules == 9)
                assert(addon.AutoCategoryIntegration.IsFaulted() and not addon.GetAutoCategoryState().enabled)
                assert(calls.warnings[1]:find("AutoCategory", 1, true)
                    and calls.warnings[1]:find("synchronization stopped", 1, true)
                    and calls.warnings[1]:find("IC Settings > Integrations > AutoCategory > Settings", 1, true))
                assert(addon.GetRuntimeRules().builtin)
            end,
        },
        {
            name = "Fresh installations initialize schema version 10",
            run = function()
                for _, fixture in ipairs({ {}, { Default = {} }, { Default = { account = {} } } }) do
                    local addon, calls = LoadAddon(fixture)
                    calls.initialize()
                    assert(addon.SettingsVersion == 10 and addon.accountWide.version == 10 and addon.character.version == 10)
                    assert(addon.accountWide.autoCategoryOrder.contexts.backpack
                        and addon.character.itemListInitialized == false and addon.character.trackedRules == nil)
                    assert(addon.state.isLoaded and calls.constructors == 2 and calls.modules == 9)
                end
                local addon, calls = LoadAddon(nil)
                calls.initialize()
                assert(addon.state.isLoaded and addon.accountWide.version == 10 and addon.character.version == 10)
            end,
        },
        {
            name = "Account-wide list backup survives reload and restores only account-wide list settings",
            run = function()
                local account = {
                    version = 6,
                    trackedRules = { custom = { displayName = "Saved group", autoCategoryEnabled = true } },
                    trackedItems = { [123] = { link = "item", display = { show = true } } },
                    autoCategoryIntegrationEnabled = true,
                    autoCategorySetupComplete = true,
                    autoCategoryOrder = { contexts = {
                        backpack = { display = { "ic:custom" }, matching = { "ic:custom" } },
                    } },
                    trackerMaxRows = 24,
                }
                local character = {
                    version = 6, trackedRules = { characterOnly = { displayName = "Keep" } },
                    trackedItems = { [456] = { link = "character item" } },
                    useCharacterItemList = true,
                }
                local saved = { Default = { account = { ["$AccountWide"] = account, character = character } } }
                local addon, calls = LoadAddon(saved)
                calls.initialize()
                SLASH_COMMANDS["/iclistbackup"]("save")
                local backup = account.accountWideListBackup
                assert(backup and backup.trackedRules ~= account.trackedRules
                    and backup.trackedRules.custom ~= account.trackedRules.custom
                    and backup.trackedItems[123] ~= account.trackedItems[123])

                account.trackedRules.custom.displayName = "Changed after backup"
                account.trackedRules.custom.autoCategoryEnabled = nil
                account.trackedItems[123] = nil
                account.autoCategoryIntegrationEnabled = nil
                account.autoCategoryOrder.contexts.backpack.display[1] = "ac:New"
                local reloaded, reloadCalls = LoadAddon(saved)
                reloadCalls.initialize()
                assert(reloaded.character.useCharacterItemList)
                SLASH_COMMANDS["/iclistbackup"]("recover")
                assert(account.trackedRules.custom.displayName == "Saved group"
                    and account.trackedRules.custom.autoCategoryEnabled)
                assert(account.trackedItems[123].link == "item")
                assert(account.autoCategoryIntegrationEnabled and account.autoCategorySetupComplete)
                assert(account.autoCategoryOrder.contexts.backpack.display[1] == "ic:custom")
                assert(account.trackerMaxRows == 24 and character.trackedRules.characterOnly.displayName == "Keep"
                    and character.trackedItems[456].link == "character item"
                    and character.useCharacterItemList)
                assert(account.accountWideListBackup == backup,
                    "Recovery must preserve the backup for repeated use")
            end,
        },
        {
            name = "Invalid account-wide list backup refuses recovery without changing live lists",
            run = function()
                local profile = { version = 6, trackedRules = { live = {} }, trackedItems = {} }
                local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = profile } } })
                calls.initialize()
                profile.accountWideListBackup = {
                    formatVersion = 2, trackedRules = {}, trackedItems = {}, autoCategoryOrder = { contexts = {} },
                }
                local ok = pcall(SLASH_COMMANDS["/iclistbackup"], "recover")
                assert(not ok and profile.trackedRules.live and next(profile.trackedItems) == nil,
                    "Invalid backup must be reported before replacing live account-wide lists")
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
                    assert(profile.version == 10, "Every account/character profile must be upgraded")
                end
                local rule = bank.trackedRules.builtin
                assert(rule.patterns == nil and table.concat(rule.addedPatterns, ",") == "c" and table.concat(rule.removedPatterns, ",") == "a")
                assert(rule.displayName == "Renamed" and rule.display.notify and rule.display.show == nil)
                assert(character.trackedRules.builtin == nil and character.trackedRules.custom.addedPatterns[1] == "Custom*")
                assert(inactive.trackedRules == nil and inactive.itemListInitialized == false
                    and inactive["$LastCharacterName"] == "Other")
                assert(bank.trackedItems == items and bank.bankItemDelay == 321 and bank.unrelated.keep and saved.unrelatedNamespace.keep)
                assert(addon.GetRuntimeRules().custom.patterns[1] == "Custom*", "Selected character must resolve migrated patterns")
                addon.SetUseCharacterItemList(false)
                assert(table.concat(addon.GetRuntimeRules().builtin.patterns, ",") == "b,c", "Account effective patterns must survive")
                local migratedRules = bank.trackedRules
                addon.PrepareSavedVariables()
                assert(bank.trackedRules == migratedRules, "Repeated preparation must not remigrate current data")
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
                assert(profile.version == 10 and profile.trackedRules.empty and profile.trackedRules.builtin.display.isHidden)
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
                    local future = { version = 11, trackedRules = { unknownFutureSchema = true }, keep = true }
                    local saved = { Default = { account = { legacy = legacy } } }
                    if location == "otherAccount" then
                        saved.Default.otherAccount = { ["$AccountWide"] = future }
                    else
                        saved.Default.account[location] = future
                    end
                    local addon, calls = LoadAddon(saved)
                    AssertStopped(addon, calls, "supports version 10")
                    assert(future.version == 11 and future.keep and future.trackedRules.unknownFutureSchema)
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
            name = "Increasing the expected version cannot silently skip an unimplemented migration",
            run = function()
                local profile = { version = 1, trackedRules = { custom = { patterns = { "Keep*" } } } }
                local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = profile } } })
                addon.SettingsVersion = 11
                AssertStopped(addon, calls, "no supported migration from version 1 to version 11")
                assert(profile.version == 1 and profile.trackedRules.custom.patterns[1] == "Keep*")
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
                assert(addon.state.isLoaded and profile.version == 10 and next(profile.trackedRules) == nil)
                assert(profile.bankItemDelay == 432 and profile.keep)
            end,
        },
    }
end
