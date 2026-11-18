local function LoadAddon(saved, releaseReader)
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
    assert(loadstring(releaseReader and Schema10ReleaseInitSource or SavedVariablesInitSource))()
    assert(loadstring(releaseReader and Schema10ReleaseConstantsSource or SavedVariablesConstantsSource))()
    local addon = InventoryCompanion
    _G[addon.SettingsName] = saved
    assert(loadstring(releaseReader and Schema10ReleaseDatabaseSource or SavedVariablesDatabaseSource))()
    assert(loadstring(releaseReader and Schema10ReleaseIntegrationSource or SavedVariablesIntegrationSource))()
    addon.preLoadedRulesets = {
        builtin = {
            displayName = "Built-in", patterns = { "a", "b" },
            display = { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false },
        },
    }
    addon.defaultsAccount = { trackedRules = {}, debug = {}, bankItemDelay = 100, guildBankPartialWithdrawEnabled = true,
        PanelSettings = {
            Tracker = {
                showTrackedItemsPanel = true, showEmptyTrackedItems = true, wrapTrackedItemNames = false,
                trackerGroupThreshold = 8, trackerMaxRows = 20, trackerTitleSize = 20,
                Layout_NoScene = { offsetX = 50, offsetY = 50 },
            },
            Currency = {
                showEmptyCurrencies = true, currencyGridColumns = 3,
                currencyPreferences = {}, capacityPreferences = {},
                Layout_NoScene = { offsetX = 50, offsetY = 150 },
            },
        },
        autoCategoryTimingThresholdMs = 500 }
    addon.defaultsCharacter = { itemListInitialized = false, useCharacterItemList = false }
    for _, method in ipairs({
        "InitContextMenus", "InitializeCurrencyHelper", "InitializeProgressBarResources",
        "InitializeCurrencyGridColumns", "InitResourceProgressBars", "InitItemTrackerPanel", "InitCurrencyPanel",
        "CreateSettingsPanel", "UpdateEventRegistry",
    }) do
        addon[method] = function() calls.modules = calls.modules + 1 end
    end
    if releaseReader then
        addon.InitCutsceneTicker = function() calls.modules = calls.modules + 1 end
    end
    addon.PanelLayout = {
        Initialize = function() end,
        CompleteInitialization = function() end,
        OnProfileChanged = function() end,
    }
    local function NewProfile(_, name, version, namespace, defaults, key)
        calls.constructors = calls.constructors + 1
        assert(namespace == nil and version == addon.SettingsVersion,
            "Constructors must request the active schema version without a namespace")
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
            if profile[field] == nil then
                profile[field] = type(value) == "table" and addon.CopySavedValue(value) or value
            end
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
    assert(not ok and (expectedMessage == nil or tostring(message):find(expectedMessage, 1, true)),
        "Expected initialization error: " .. tostring(message))
    assert(calls.constructors == 0 and calls.modules == 0 and calls.strings == 0,
        "Rejected data must stop initialization before constructors, modules, or UI setup")
    assert(not addon.state.isLoaded and addon.accountWide == nil and addon.character == nil,
        "Rejected addon must remain unloaded")
end

local function NewCollisionRules()
    return {
        custom_collision = {
            displayName = "Furniture Materials",
            patterns = { "Mundane Rune", "*test item *" },
            autoCategoryEnabled = true,
            display = {
                notifyChat = true, notifyHud = true, showBackpack = false, showBank = true,
                group = false, isExpanded = false,
            },
        },
        furniture_materials = {
            displayName = "Obsolete built-in data",
            addedPatterns = { "stale target pattern" },
            display = { notifyChat = false },
        },
        custom_miscellaneous = {
            displayName = "Miscellaneous",
            patterns = { "custom miscellaneous item" },
        },
        uppercase_collision = {
            displayName = "FURNITURE MATERIALS",
            patterns = { "leave me unchanged" },
        },
    }
end

local function NewCollisionOrder()
    return { contexts = { backpack = {
        display = {
            "ic:custom_collision", "ic:furniture_materials", "ic:custom_miscellaneous", "ic:__ic_other",
        },
        matching = { "ic:custom_collision", "ic:furniture_materials", "ic:custom_miscellaneous" },
        hidden = { ["ic:custom_collision"] = true, ["ic:furniture_materials"] = false },
        displayPositions = {
            ["ic:custom_collision"] = 7, ["ic:furniture_materials"] = 9,
            ["ic:custom_miscellaneous"] = 4,
        },
    } } }
end

function GetSavedVariablesTests()
    return {
        {
            name = "Released schema 10 rejects schema 11 profiles before initialization without mutation",
            run = function()
                for _, location in ipairs({ "$AccountWide", "inactive", "otherAccount" }) do
                    local newer = { version = 11, itemListInitialized = true, currencyGridColumns = 5,
                        scenePositions = { characterA = { inventory = { tracker = { x = 70, y = 90 } } } },
                        unrelated = { keep = true } }
                    local saved = { Default = { account = {
                        ["$AccountWide"] = { version = 9, trackedRules = { builtin = {} } },
                    } } }
                    if location == "otherAccount" then
                        saved.Default.other = { inactive = newer }
                    else
                        saved.Default.account[location] = newer
                    end
                    local addon, calls = LoadAddon(saved, true)
                    local before = addon.CopySavedValue(saved)
                    AssertStopped(addon, calls, "supports version 10")
                    assert(addon.SavedValuesEqual(saved, before),
                        "Released reader must not modify any saved data before rejecting a newer schema")
                end
            end,
        },
        {
            name = "Released schema 10 profile copy does not copy unknown feature fields",
            run = function()
                local source = { version = 10, itemListInitialized = true, trackedRules = {}, trackedItems = {},
                    currencyGridColumns = 6, scenePositions = { sourceCharacter = { inventory = { x = 7 } } } }
                local destination = { version = 10, itemListInitialized = true, useCharacterItemList = true,
                    trackedRules = {}, trackedItems = {}, currencyGridColumns = 2,
                    scenePositions = { destinationCharacter = { inventory = { x = 19 } } } }
                local addon, calls = LoadAddon({ Default = { account = {
                    ["$AccountWide"] = source, character = destination,
                } } }, true)
                calls.initialize()
                assert(addon.CopyProfile("$AccountWide"))
                assert(destination.currencyGridColumns == 2 and destination.scenePositions.destinationCharacter
                    and destination.scenePositions.sourceCharacter == nil,
                    "Unknown source fields are not copied or used to replace destination fields")
                local firstUseAddon, firstUseCalls = LoadAddon({ Default = { account = {
                    ["$AccountWide"] = source,
                } } }, true)
                firstUseCalls.initialize()
                firstUseAddon.SetUseCharacterItemList(true)
                assert(firstUseAddon.character.currencyGridColumns == nil
                    and firstUseAddon.character.scenePositions == nil,
                    "First-use character initialization also omits unknown account fields")
            end,
        },
        {
            name = "Full profile copy replaces every preference map and preserves destination metadata and account controls",
            run = function()
                local source = { version = 11, itemListInitialized = true, trackedRules = { source = {} },
                    trackedItems = {}, PanelSettings = {
                        Tracker = { trackerMaxRows = 24, Layout_NoScene = { offsetX = 77, offsetY = 50 },
                            Layout_FurnitureVaultScene = { sourceCharacter = { offsetX = 31, offsetY = 42 } },
                            Layout_BankScene = { sourceCharacter = { offsetX = 71, offsetY = 82 } } },
                        Currency = { currencyPreferences = {}, capacityPreferences = {},
                            Layout_NoScene = { offsetX = 50, offsetY = 150 } },
                        ["capacity:bag"] = { showBar = true,
                            Layout_NoScene = { offsetX = 50, offsetY = 90 } },
                    },
                    bankItemDelay = 999, autoCategoryIntegrationEnabled = true }
                local destination = { version = 11, useCharacterItemList = true, itemListInitialized = true,
                    trackedRules = { destination = {} }, trackedItems = {}, PanelSettings = {
                        Tracker = { Layout_NoScene = { offsetX = 9, offsetY = 8 },
                            Layout_BankScene = { destinationCharacter = { offsetX = 19, offsetY = 18 } } },
                        Currency = { currencyPreferences = { [2] = { showCompact = false } },
                            capacityPreferences = {}, Layout_NoScene = { offsetX = 20, offsetY = 30 } },
                        ["capacity:bank"] = { showBar = false,
                            Layout_NoScene = { offsetX = 50, offsetY = 130 } },
                    },
                    ["$LastCharacterName"] = "Destination", unrelated = { keep = true } }
                local account = { version = 11, bankItemDelay = 321, autoCategoryIntegrationEnabled = false }
                local addon, calls = LoadAddon({ Default = { account = {
                    ["$AccountWide"] = account, character = destination, source = source,
                } } })
                calls.initialize()
                source.PanelSettings.Currency.currencyGridColumns = nil
                local sourceBefore = addon.CopySavedValue(source)
                assert(addon.CopyProfile("source"))
                assert(addon.SavedValuesEqual(source, sourceBefore),
                    "Defaulting copied preferences must not mutate the source")
                assert(destination.PanelSettings.Currency.currencyGridColumns == 3,
                    "Copying a profile must default a missing column count")
                assert(destination.PanelSettings.Tracker.Layout_FurnitureVaultScene.sourceCharacter.offsetX == 31,
                    "Full copying must preserve character-owned vault positions")
                assert(destination.trackedRules.source and not destination.trackedRules.destination
                    and next(destination.PanelSettings.Currency.currencyPreferences) == nil
                    and destination.PanelSettings["capacity:bank"] == nil
                    and destination.PanelSettings["capacity:bag"].showBar)
                assert(destination.PanelSettings.Tracker.Layout_NoScene.offsetX == 77
                    and destination.PanelSettings.Tracker.Layout_BankScene.sourceCharacter.offsetX == 71
                    and destination.PanelSettings.Tracker.Layout_BankScene.destinationCharacter == nil
                    and destination["$LastCharacterName"] == "Destination"
                    and destination.version == 11 and destination.useCharacterItemList and destination.unrelated.keep)
                assert(destination.bankItemDelay == nil and destination.autoCategoryIntegrationEnabled == nil
                    and account.bankItemDelay == 321 and account.autoCategoryIntegrationEnabled == false)
                source.PanelSettings.Currency.currencyPreferences[1] = { showCompact = false }
                assert(destination.PanelSettings.Currency.currencyPreferences[1] == nil)
                local before = addon.CopySavedValue(destination)
                source.PanelSettings["capacity:bag"].showBar = "yes"
                sourceBefore = addon.CopySavedValue(source)
                assert(not pcall(addon.CopyProfile, "source"))
                assert(addon.SavedValuesEqual(destination, before), "Invalid import must not partially replace any fields")
                assert(addon.SavedValuesEqual(source, sourceBefore),
                    "A rejected copy must leave its source unchanged")
            end,
        },
        {
            name = "Schema 11 profile preparation defaults missing columns and rejects explicit invalid values",
            run = function()
                local addon = LoadAddon(nil)
                local profile = { PanelSettings = { Currency = {} } }
                addon.PrepareProfilePreferences(profile)
                assert(profile.PanelSettings.Currency.currencyGridColumns == 3)
                assert(profile.PanelSettings.Tracker.Layout_NoScene)
                profile.PanelSettings.Currency.currencyGridColumns = 99
                addon.PrepareProfilePreferences(profile)
                assert(profile.PanelSettings.Currency.currencyGridColumns == 99,
                    "Preparation must preserve explicit above-cap choices")
                for _, invalid in ipairs({ 0, -1, 1.5, "3", math.huge }) do
                    profile.PanelSettings.Currency.currencyGridColumns = invalid
                    assert(not pcall(addon.PrepareProfilePreferences, profile),
                        "Explicit invalid column counts must not be defaulted")
                end
            end,
        },
        {
            name = "Schema 10 migration maps panel fields and preserves sparse resource state",
            run = function()
                local currencyPreferences = {
                    [1] = {
                        showCompact = false,
                        order = 4,
                        locations = { [2] = { hidden = true, showCompact = false, notify = false } },
                    },
                }
                local capacityPreferences = { backpack = { showBar = true, order = 3 } }
                local alertColors = {
                    warning = { r = 0.9, g = 0.6, b = 0.2, a = 1 },
                    danger = { r = 0.8, g = 0.1, b = 0.1, a = 1 },
                }
                local account = {
                    version = 10, itemListInitialized = true, trackedRules = {}, trackedItems = {},
                    showTrackedItemsPanel = false, showEmptyTrackedItems = false, wrapTrackedItemNames = true,
                    trackerGroupThreshold = 6, trackerMaxRows = 31, trackerTitleSize = 24,
                    trackerOffsetX = -45.5, trackerOffsetY = 220.25,
                    showEmptyCurrencies = false, currencyGridColumns = 5,
                    currencyOffsetX = -20.5, currencyOffsetY = 180.25,
                    currencyPreferences = currencyPreferences, capacityPreferences = capacityPreferences,
                    progressBarPreferences = {
                        ["capacity:bag"] = {
                            showBar = false, warningThreshold = 0.96, dangerThreshold = 0.8,
                            offsetX = 17.5, normalColor = { r = 0.1, g = 0.2, b = 0.3, a = 1 },
                            customSetting = { preserve = true },
                        },
                        ["currency:42"] = { showBar = false, offsetY = 240.5, customFlag = "keep" },
                    },
                    progressBarAlertColors = alertColors,
                    currencyNamesById = { [1] = "Known Currency" },
                    filterShow = false, filterNotify = false, filterCraftbag = true,
                    filterMute = false, filterUntracked = true,
                    unrelatedMetadata = { preserve = true },
                }
                local inactive = {
                    version = 10, itemListInitialized = true, useCharacterItemList = false,
                    trackedRules = {}, trackedItems = {}, trackerOffsetX = 99,
                    currencyPreferences = { [2] = { showCompact = false } },
                }
                local saved = { Default = { account = {
                    ["$AccountWide"] = account, inactive = inactive,
                }, otherAccount = { ["$AccountWide"] = { version = 10, itemListInitialized = true,
                    trackedRules = {}, trackedItems = {}, trackerOffsetY = 71 } } } }
                local addon = LoadAddon(saved)
                addon.PrepareSavedVariables()

                assert(account.version == 11 and inactive.version == 11
                    and saved.Default.otherAccount["$AccountWide"].version == 11)
                assert(account.PanelSettings.Tracker.showTrackedItemsPanel == false
                    and account.PanelSettings.Tracker.showEmptyTrackedItems == false
                    and account.PanelSettings.Tracker.wrapTrackedItemNames
                    and account.PanelSettings.Tracker.trackerGroupThreshold == 6
                    and account.PanelSettings.Tracker.trackerMaxRows == 31
                    and account.PanelSettings.Tracker.trackerTitleSize == 24)
                assert(account.PanelSettings.Tracker.Layout_NoScene.offsetX == -45.5
                    and account.PanelSettings.Tracker.Layout_NoScene.offsetY == 220.25)
                assert(account.PanelSettings.Currency.showEmptyCurrencies == false
                    and account.PanelSettings.Currency.currencyGridColumns == 5
                    and account.PanelSettings.Currency.Layout_NoScene.offsetX == -20.5
                    and account.PanelSettings.Currency.Layout_NoScene.offsetY == 180.25)
                assert(account.PanelSettings.Currency.currencyPreferences ~= currencyPreferences
                    and account.PanelSettings.Currency.currencyPreferences[1] ~= currencyPreferences[1]
                    and account.PanelSettings.Currency.currencyPreferences[1].locations[2].notify == false)
                assert(account.PanelSettings.Currency.capacityPreferences ~= capacityPreferences
                    and account.PanelSettings.Currency.capacityPreferences.backpack.order == 3)
                local bag = account.PanelSettings["capacity:bag"]
                assert(bag.showBar == false and bag.warningThreshold == 0.75 and bag.dangerThreshold == 0.90
                    and bag.Layout_NoScene.offsetX == 17.5 and bag.Layout_NoScene.offsetY == nil
                    and bag.normalColor.r == 0.1 and bag.customSetting.preserve)
                local currencyBar = account.PanelSettings["currency:42"]
                assert(currencyBar.showBar == false and currencyBar.Layout_NoScene.offsetX == nil
                    and currencyBar.Layout_NoScene.offsetY == 240.5 and currencyBar.customFlag == "keep")
                assert(account.progressBarAlertColors == alertColors
                    and account.currencyNamesById[1] == "Known Currency"
                    and not account.filterShow and not account.filterNotify and account.filterCraftbag
                    and not account.filterMute and account.filterUntracked
                    and account.unrelatedMetadata.preserve)
                assert(inactive.PanelSettings.Tracker.Layout_NoScene.offsetX == 99
                    and inactive.PanelSettings.Tracker.Layout_NoScene.offsetY == 50)
                assert(account.trackerOffsetX == nil and account.progressBarPreferences == nil
                    and account.currencyPreferences == nil and account.capacityPreferences == nil
                    and account.currencyOffsetX == nil and account.currencyGridColumns == nil)
                local first = addon.CopySavedValue(account.PanelSettings)
                addon.PrepareSavedVariables()
                assert(addon.SavedValuesEqual(account.PanelSettings, first),
                    "Schema-11 preparation must preserve the complete converted panel tree")
            end,
        },
        {
            name = "Schema 11 panel layout helpers preserve sparse scenes and reset only known layouts",
            run = function()
                local profile = {
                    version = 11, itemListInitialized = true, trackedRules = {}, trackedItems = {},
                    PanelSettings = {
                        Tracker = {
                            trackerMaxRows = 20,
                            Layout_NoScene = { offsetX = -123.5, offsetY = 800.25 },
                            Layout_BankScene = { characterA = { offsetX = -50.5, offsetY = 5000 } },
                            Layout_Custom = { retain = true },
                        },
                        Currency = { Layout_NoScene = { offsetX = 12.5, offsetY = 250.25 } },
                        FuturePanel = { futureSetting = { preserve = true } },
                    },
                }
                local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = profile } } })
                calls.initialize()

                local absent = addon.GetPanelLayout("Tracker", "Layout_SettingsScene", "current-character")
                assert(absent == nil and profile.PanelSettings.Tracker.Layout_SettingsScene == nil,
                    "Reading an absent scene layout must not create it")
                addon.SavePanelLayout("Tracker", "Layout_BankScene", "characterB", -8.25, 3900.5)
                assert(addon.GetPanelLayout("Tracker", "Layout_BankScene", "characterA").offsetX == -50.5
                    and addon.GetPanelLayout("Tracker", "Layout_BankScene", "characterB").offsetY == 3900.5
                    and addon.GetPanelLayout("Tracker", "Layout_NoScene").offsetX == -123.5)
                addon.SavePanelLayout("Currency", "Layout_NoScene", nil, -44.25, 901.5)
                addon.SavePanelLayout("Tracker", "Layout_FurnitureVaultScene", "characterA", 600, 300)
                addon.SavePanelLayout("Currency", "Layout_FurnitureVaultScene", "characterB", 650, 400)
                addon.PrepareSavedVariables()
                assert(addon.GetPanelLayout("Tracker", "Layout_FurnitureVaultScene", "characterA").offsetX == 600,
                    "Same-schema preparation must preserve vault positions")
                assert(addon.GetPanelLayout("Currency", "Layout_NoScene").offsetX == -44.25)
                assert(not pcall(addon.GetPanelSettings, "FuturePanel"))
                assert(not pcall(addon.GetPanelLayout, "Tracker", "Layout_BankScene", ""))
                assert(not pcall(addon.SavePanelLayout, "Tracker", "Layout_BankScene", "characterC", 1, nil))

                addon.ResetPanelLayouts("Tracker")
                assert(addon.GetPanelLayout("Tracker", "Layout_NoScene").offsetX == 50
                    and addon.GetPanelLayout("Tracker", "Layout_NoScene").offsetY == 50
                    and addon.GetPanelLayout("Tracker", "Layout_BankScene", "characterA") == nil
                    and addon.GetPanelLayout("Tracker", "Layout_BankScene", "characterB") == nil
                    and addon.GetPanelLayout("Tracker", "Layout_FurnitureVaultScene", "characterA") == nil
                    and addon.GetPanelLayout("Currency", "Layout_FurnitureVaultScene", "characterB").offsetX == 650
                    and profile.PanelSettings.Tracker.Layout_Custom.retain)
            end,
        },
        {
            name = "Malformed schema-11 scenes abort every account migration without mutation",
            run = function()
                local malformedTrees = {
                    { Tracker = { Layout_FurnitureVaultScene = { characterA = { offsetX = 10 } } } },
                    { Tracker = { Layout_BankScene = { characterA = { offsetX = 10 } } } },
                    { Tracker = { Layout_BankScene = { [42] = { offsetX = 10, offsetY = 20 } } } },
                    { Tracker = { Layout_SettingsScene = { characterA = { offsetX = math.huge, offsetY = 20 } } } },
                    { Currency = { Layout_NoScene = { offsetX = math.huge, offsetY = 20 } } },
                    { ["capacity:bag"] = { Layout_NoScene = { offsetX = -1, offsetY = 20 } } },
                    { Tracker = false },
                }
                for caseIndex, panelSettings in ipairs(malformedTrees) do
                    local legacy = {
                        version = 10, itemListInitialized = true, trackedRules = {}, trackerOffsetX = 75,
                    }
                    local invalid = {
                        version = 11, itemListInitialized = true, trackedRules = {},
                        PanelSettings = panelSettings,
                    }
                    local saved = { Default = { account = {
                        ["$AccountWide"] = legacy, inactive = invalid,
                    } } }
                    local addon = LoadAddon(saved)
                    local before = addon.CopySavedValue(saved)
                    local ok = pcall(addon.PrepareSavedVariables)
                    assert(not ok and addon.SavedValuesEqual(saved, before),
                        "Malformed layout case " .. tostring(caseIndex)
                            .. " must not partially publish another profile's schema migration")
                end
            end,
        },
        {
            name = "Schema boundary rejects overlapping old and new panel fields without mutation",
            run = function()
                for _, fixture in ipairs({
                    { version = 10, itemListInitialized = true, trackedRules = {}, trackerOffsetX = 12,
                        PanelSettings = { FuturePanel = { preserve = true } } },
                    { version = 11, itemListInitialized = true, trackedRules = {}, trackerOffsetX = 12 },
                }) do
                    local saved = { Default = { account = { ["$AccountWide"] = fixture } } }
                    local addon = LoadAddon(saved)
                    local before = addon.CopySavedValue(saved)
                    assert(not pcall(addon.PrepareSavedVariables)
                        and addon.SavedValuesEqual(saved, before),
                        "A schema collision must not overwrite data or partially publish a migration")
                end
            end,
        },
        {
            name = "Built-in names colliding with current or future virtual groups stop before saved data changes",
            run = function()
                for _, fixture in ipairs({
                    { virtualKey = "miscellaneous", name = "Miscellaneous", builtInKey = "new_miscellaneous" },
                    { virtualKey = "future_virtual", name = "Future Virtual Group", builtInKey = "new_future_group" },
                }) do
                    local profile = { version = 11, itemListInitialized = true, trackedRules = {} }
                    local saved = { Default = { account = { ["$AccountWide"] = profile } } }
                    local addon, calls = LoadAddon(saved)
                    local function Rule(displayName, isVirtual)
                        return {
                            displayName = displayName, isVirtual = isVirtual,
                            patterns = {}, display = {
                                show = true, notify = false, bank = false, group = true,
                                isExpanded = true, isHidden = false,
                            },
                        }
                    end
                    addon.preLoadedRulesets = {
                        [fixture.virtualKey] = Rule(fixture.name, true),
                        [fixture.builtInKey] = Rule(fixture.name, false),
                    }
                    local before = addon.CopySavedValue(saved)
                    AssertStopped(addon, calls, "collides with virtual group")
                    assert(addon.SavedValuesEqual(saved, before) and profile.version == 11,
                        "A built-in/virtual name conflict must not alter any saved data or version")
                end
            end,
        },
        {
            name = "Schema 11 repairs exact-name collisions in all initialized profiles and account backup",
            run = function()
                local addon = LoadAddon(nil)
                addon.preLoadedRulesets = {
                    furniture_materials = {
                        displayName = "Furniture Materials",
                        patterns = { "Mundane Rune", "Heartwood", "Regulus", "Bast", "Clean Pelt",
                            "Alchemical Resin", "Decorative Wax", "Ochre" },
                        display = {
                        show = false, notify = false, bank = false, group = true,
                            isExpanded = true, isHidden = false,
                        },
                    },
                    miscellaneous = {
                        displayName = "Miscellaneous", patterns = {},
                        isVirtual = true,
                        display = {
                            show = true, notify = false, bank = false, group = true,
                            isExpanded = true, isHidden = false,
                        },
                    },
                }
                local function Profile(useCharacter)
                    return {
                        version = 11, itemListInitialized = true, useCharacterItemList = useCharacter,
                        trackedRules = NewCollisionRules(), autoCategoryOrder = NewCollisionOrder(),
                    }
                end
                local account = Profile(false)
                local character = Profile(true)
                local inactive = Profile(true)
                local otherAccount = Profile(false)
                local caseOnly = {
                    version = 11, itemListInitialized = true,
                    trackedRules = { uppercase_collision = {
                        displayName = "FURNITURE MATERIALS", patterns = { "leave me unchanged" },
                    } },
                }
                account.accountWideListBackup = {
                    formatVersion = 1, trackedRules = NewCollisionRules(), trackedItems = {},
                    autoCategoryOrder = NewCollisionOrder(),
                }
                local caseOnlyRules = caseOnly.trackedRules
                local saved = { Default = {
                    account = { ["$AccountWide"] = account, character = character, inactive = inactive, caseOnly = caseOnly },
                    other = { ["$AccountWide"] = otherAccount },
                } }
                _G.InventoryCompanion_SavedVariables = saved
                addon.PrepareSavedVariables()
                assert(account.version == 11 and character.version == 11 and inactive.version == 11
                    and otherAccount.version == 11 and caseOnly.version == 11)
                for _, profile in ipairs({ account, character, inactive, otherAccount }) do
                    local rules = profile.trackedRules
                    local promoted = rules.furniture_materials
                    assert(promoted and promoted.displayName == nil and promoted.autoCategoryEnabled == true
                        and rules.custom_collision == nil and rules.uppercase_collision.displayName == "FURNITURE MATERIALS"
                        and rules.custom_miscellaneous.displayName == "Miscellaneous"
                        and rules.custom_miscellaneous.patterns[1] == "custom miscellaneous item")
                    assert(table.concat(promoted.addedPatterns, ",") == "*test item *"
                        and table.concat(promoted.removedPatterns, ",") ==
                            "Alchemical Resin,Bast,Clean Pelt,Decorative Wax,Heartwood,Ochre,Regulus")
                    local resolved = addon.GetRuntimeRules(rules).furniture_materials
                    assert(table.concat(resolved.patterns, ",") == "*test item *,Mundane Rune")
                    assert(resolved.display.notifyChat and resolved.display.notifyHud
                        and not resolved.display.showBackpack and resolved.display.showBank
                        and not resolved.display.group and not resolved.display.isExpanded
                        and resolved.display.isHidden == false)
                    local order = profile.autoCategoryOrder.contexts.backpack
                    assert(table.concat(order.display, ",")
                            == "ic:furniture_materials,ic:custom_miscellaneous,ic:__ic_other"
                        and table.concat(order.matching, ",")
                            == "ic:furniture_materials,ic:custom_miscellaneous")
                    assert(order.hidden["ic:furniture_materials"] == true
                        and order.hidden["ic:custom_collision"] == nil
                        and order.displayPositions["ic:furniture_materials"] == 7
                        and order.displayPositions["ic:custom_collision"] == nil
                        and order.displayPositions["ic:custom_miscellaneous"] == 4)
                end
                assert(account.accountWideListBackup.trackedRules.custom_collision == nil
                    and account.accountWideListBackup.trackedRules.furniture_materials.addedPatterns[1] == "*test item *")
                assert(caseOnly.trackedRules == caseOnlyRules
                    and caseOnly.trackedRules.uppercase_collision.displayName == "FURNITURE MATERIALS")
            end,
        },
        {
            name = "Collision promotion keeps the custom order position when the built-in reference comes first",
            run = function()
                local addon = LoadAddon(nil)
                addon.preLoadedRulesets = {
                    furniture_materials = {
                        displayName = "Furniture Materials",
                        patterns = { "Mundane Rune", "Heartwood" },
                        display = {
                            show = false, notify = false, bank = false, group = true,
                            isExpanded = true, isHidden = false,
                        },
                    },
                }
                local profile = {
                    version = 11, itemListInitialized = true, useCharacterItemList = false,
                    trackedRules = NewCollisionRules(), autoCategoryOrder = NewCollisionOrder(),
                }
                local order = profile.autoCategoryOrder.contexts.backpack
                order.display = {
                    "ic:custom_miscellaneous", "ic:furniture_materials", "ic:custom_collision", "ic:__ic_other",
                }
                order.matching = {
                    "ic:custom_miscellaneous", "ic:furniture_materials", "ic:custom_collision",
                }
                profile.autoCategoryOrder.contexts.bank = {
                    display = { "ic:furniture_materials" },
                    matching = { "ic:furniture_materials" },
                    hidden = { ["ic:furniture_materials"] = false },
                    displayPositions = { ["ic:furniture_materials"] = 9 },
                }
                profile.autoCategoryOrder.contexts.guild_bank = {
                    display = { "ic:custom_collision" },
                    matching = { "ic:custom_collision" },
                    hidden = { ["ic:custom_collision"] = false },
                    displayPositions = { ["ic:custom_collision"] = 11 },
                }
                _G.InventoryCompanion_SavedVariables = {
                    Default = { account = { ["$AccountWide"] = profile } },
                }

                addon.PrepareSavedVariables()

                local promotedOrder = profile.autoCategoryOrder.contexts.backpack
                local displayed = table.concat(promotedOrder.display, ",")
                local matching = table.concat(promotedOrder.matching, ",")
                assert(displayed == "ic:custom_miscellaneous,ic:furniture_materials,ic:__ic_other"
                    and matching == "ic:custom_miscellaneous,ic:furniture_materials",
                    "Unexpected remapped order: display=" .. displayed .. "; matching=" .. matching)
                assert(promotedOrder.hidden["ic:furniture_materials"] == true
                    and promotedOrder.hidden["ic:custom_collision"] == nil
                    and promotedOrder.displayPositions["ic:furniture_materials"] == 7
                    and promotedOrder.displayPositions["ic:custom_collision"] == nil)
                local targetOnly = profile.autoCategoryOrder.contexts.bank
                assert(targetOnly.hidden["ic:furniture_materials"] == false
                    and targetOnly.displayPositions["ic:furniture_materials"] == 9)
                local sourceOnly = profile.autoCategoryOrder.contexts.guild_bank
                assert(sourceOnly.hidden["ic:furniture_materials"] == false
                    and sourceOnly.hidden["ic:custom_collision"] == nil
                    and sourceOnly.displayPositions["ic:furniture_materials"] == 11
                    and sourceOnly.displayPositions["ic:custom_collision"] == nil)
            end,
        },
        {
            name = "Ambiguous exact-name collisions fail before publishing any profile migration",
            run = function()
                local addon = LoadAddon(nil)
                addon.preLoadedRulesets = {
                    furniture_materials = {
                        displayName = "Furniture Materials",
                        patterns = { "Mundane Rune", "Heartwood" },
                        display = {
                            show = false, notify = false, bank = false, group = true,
                            isExpanded = true, isHidden = false,
                        },
                    },
                    miscellaneous = {
                        displayName = "Miscellaneous", patterns = {},
                        isVirtual = true,
                        display = {
                            show = true, notify = false, bank = false, group = true,
                            isExpanded = true, isHidden = false,
                        },
                    },
                }
                local colliding = {
                    version = 11, itemListInitialized = true,
                    trackedRules = NewCollisionRules(), autoCategoryOrder = NewCollisionOrder(),
                }
                colliding.trackedRules.second_collision = {
                    displayName = "Furniture Materials", patterns = { "second" },
                }
                local other = {
                    version = 11, itemListInitialized = true,
                    trackedRules = NewCollisionRules(), autoCategoryOrder = NewCollisionOrder(),
                }
                local savedRules, savedOrder = colliding.trackedRules, colliding.autoCategoryOrder
                local otherRules, otherOrder = other.trackedRules, other.autoCategoryOrder
                _G.InventoryCompanion_SavedVariables = { Default = { account = {
                    ["$AccountWide"] = colliding, inactive = other,
                } } }
                local ok, failure = pcall(addon.PrepareSavedVariables)
                assert(not ok and tostring(failure):find("multiple custom groups named Furniture Materials", 1, true))
                assert(colliding.version == 11 and colliding.trackedRules == savedRules
                    and colliding.autoCategoryOrder == savedOrder and other.version == 11
                    and other.trackedRules == otherRules and other.autoCategoryOrder == otherOrder)
            end,
        },
        {
            name = "Guild-bank partial withdrawal setting defaults on and validates saved booleans before constructors",
            run = function()
                local addon, calls = LoadAddon({ Default = { account = { ["$AccountWide"] = { version = 11 } } } })
                calls.initialize()
                assert(addon.accountWide.guildBankPartialWithdrawEnabled == true)

                local disabledAddon, disabledCalls = LoadAddon({ Default = { account = {
                    ["$AccountWide"] = { version = 11, guildBankPartialWithdrawEnabled = false },
                } } })
                disabledCalls.initialize()
                assert(disabledAddon.accountWide.guildBankPartialWithdrawEnabled == false)

                local invalidAddon, invalidCalls = LoadAddon({ Default = { account = {
                    ["$AccountWide"] = { version = 11, guildBankPartialWithdrawEnabled = "yes" },
                } } })
                AssertStopped(invalidAddon, invalidCalls, "guildBankPartialWithdrawEnabled must be boolean")
            end,
        },
        {
            name = "Schema 11 upgrades every supported source and preserves settings on unused character stubs",
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
                    assert(account.version == 11 and active.version == 11 and unused.version == 11)
                    assert(active.itemListInitialized and active.trackedRules.personal
                        and active.PanelSettings.Tracker.Layout_NoScene.offsetX == 87
                        and active.PanelSettings.Tracker.Layout_NoScene.offsetY == 63)
                    assert(active.PanelSettings.Currency.currencyPreferences ~= account.PanelSettings.Currency.currencyPreferences
                        and active.PanelSettings.Currency.currencyPreferences[1]
                            ~= account.PanelSettings.Currency.currencyPreferences[1])
                    assert(unused.trackedRules == nil and unused.trackerOffsetX == nil
                        and unused.PanelSettings.Tracker.Layout_NoScene.offsetX == 91
                        and unused.itemListInitialized == false and unused.unrelated == "keep")
                    unused.itemListInitialized, unused.trackedRules, unused.trackedItems = true, { retained = {} }, {}
                    unused.PanelSettings.Tracker.Layout_NoScene.offsetX = 92
                    addon.PrepareSavedVariables()
                    assert(unused.itemListInitialized and unused.trackedRules.retained
                        and unused.PanelSettings.Tracker.Layout_NoScene.offsetX == 92,
                        "A later reload must retain initialized inactive schema-11 content")
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
                assert(character.itemListInitialized
                    and character.PanelSettings.Tracker.Layout_NoScene.offsetX == 72
                    and character.bankItemDelay == nil and character.autoCategoryIntegrationEnabled == nil)
                character.PanelSettings.Tracker.Layout_NoScene.offsetX = 99
                character.PanelSettings.Currency.currencyPreferences[1].locations[1].hidden = false
                addon.SetUseCharacterItemList(false)
                assert(addon.GetSettingsProfile() == account
                    and account.PanelSettings.Tracker.Layout_NoScene.offsetX == 72
                    and account.PanelSettings.Currency.currencyPreferences[1].locations[1].hidden)
                account.PanelSettings.Tracker.Layout_NoScene.offsetX = 120
                addon.SetUseCharacterItemList(true)
                assert(addon.GetSettingsProfile() == character
                    and character.PanelSettings.Tracker.Layout_NoScene.offsetX == 99
                    and character.PanelSettings.Currency.currencyPreferences[1].locations[1].hidden == false)
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
                    AssertStopped(addon, calls)
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
                    assert(profile.version == 11)
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
                    assert(broken.version == 11 and valid.version == 11 and valid.unrelated.keep)
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
                assert(configured.version == 11 and configured.autoCategorySetupComplete == true)
                assert(ordered.version == 11 and ordered.autoCategorySetupComplete == true)
                assert(configured.trackedRules == rules and configured.unrelated.keep)
                assert(unused.version == 11 and unused.autoCategorySetupComplete == nil
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
                    assert(profile.version == 11, "Inactive profiles and accounts must upgrade")
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
                assert(profile.version == 11 and profile.trackedRules == rules and profile.keep.value == 7)
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
                assert(profile.version == 11 and profile.trackedRules == rules
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
                    assert(accountProfile.version == 11 and inactiveProfile.version == 11,
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
                    assert(broken.version == 11 and untouched.version == 11
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
            name = "Fresh installations initialize schema version 11",
            run = function()
                for _, fixture in ipairs({ {}, { Default = {} }, { Default = { account = {} } } }) do
                    local addon, calls = LoadAddon(fixture)
                    calls.initialize()
                    assert(addon.SettingsVersion == 11 and addon.accountWide.version == 11 and addon.character.version == 11)
                    assert(addon.accountWide.autoCategoryOrder.contexts.backpack
                        and addon.character.itemListInitialized == false and addon.character.trackedRules == nil)
                    assert(addon.state.isLoaded and calls.constructors == 2 and calls.modules == 9)
                end
                local addon, calls = LoadAddon(nil)
                calls.initialize()
                assert(addon.state.isLoaded and addon.accountWide.version == 11 and addon.character.version == 11)
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
                assert(account.PanelSettings.Tracker.trackerMaxRows == 24
                    and character.trackedRules.characterOnly.displayName == "Keep"
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
                    assert(profile.version == 11, "Every account/character profile must be upgraded")
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
                assert(profile.version == 11 and profile.trackedRules.empty and profile.trackedRules.builtin.display.isHidden)
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
                    local future = { version = 12, trackedRules = { unknownFutureSchema = true }, keep = true }
                    local saved = { Default = { account = { legacy = legacy } } }
                    if location == "otherAccount" then
                        saved.Default.otherAccount = { ["$AccountWide"] = future }
                    else
                        saved.Default.account[location] = future
                    end
                    local addon, calls = LoadAddon(saved)
                    AssertStopped(addon, calls, "supports version 11")
                    assert(future.version == 12 and future.keep and future.trackedRules.unknownFutureSchema)
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
                addon.SettingsVersion = 12
                AssertStopped(addon, calls, "no supported migration from version 1 to version 12")
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
                assert(addon.state.isLoaded and profile.version == 11 and next(profile.trackedRules) == nil)
                assert(profile.bankItemDelay == 432 and profile.keep)
            end,
        },
    }
end
