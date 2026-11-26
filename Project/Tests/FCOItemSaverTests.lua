local this = InventoryCompanion
local contexts = {
    "backpack", "bank", "guild_bank", "house_bank", "crafting_station", "craft_bag", "furniture_vault",
}

local function NewOrder()
    local order = { contexts = {} }
    for _, key in ipairs(contexts) do
        order.contexts[key] = { display = {}, matching = {}, hidden = {}, displayPositions = {} }
    end
    return order
end

local function Setup()
    this.SettingsName = "InventoryCompanion_FCOTests"
    this.preLoadedRulesets = {}
    this.accountWide = { fcoIntegrationState = "off", autoCategoryIntegrationEnabled = false,
        trackedRules = {}, autoCategoryOrder = NewOrder() }
    local profile = { fcoTestGroupsCreated = false, trackedRules = {}, autoCategoryOrder = NewOrder() }
    this.character = { useCharacterItemList = false }
    this.GetAutoCategoryProfile = function() return profile end
    this.ValidateFCOCleanupProfile = function() end
    this.ValidateAccountWideListBackup = function(backup, path)
        assert(type(backup) == "table" and type(backup.trackedRules) == "table",
            path .. ".trackedRules must be a table")
    end
    this.GetRuntimeRules = function()
        local rules = {}
        for key, rule in pairs(profile.trackedRules) do
            rules[key] = { displayName = rule.displayName or key }
        end
        return rules
    end
    this.Utils = { UserError = function(message) this.lastFCOTestError = message end }
    this.lastFCOTestError = nil
    this.InvalidateRuleCache = function() end
    this.ResetPriorityWatch = function() end
    this.InvalidateEditorHistory = function() end
    this.AutoCategoryIntegration = { OnProfileChanged = function() end, OnFCOAvailabilityChanged = function() end,
        PreflightDeletedFCOGroups = function() return {} end, ApplyDeletedFCOGroups = function() end }
    this.RefreshTrackedItemsEditor = function() end
    this.RefreshGroupsEditor = function() end
    this.RefreshAutoCategoryEditor = function() end
    this.RefreshItemTrackerPanel = function() end
    this.UpdateEventRegistry = function() end
    this.StartTrackerMarkerPolling = function() end
    local saved = { Default = { account = { ["$AccountWide"] = this.accountWide, character = profile } } }
    _G[this.SettingsName] = saved
    FCOIS = {
        libsLoadedProperly = true,
        addonVars = { gAddonLoaded = true },
        settingsVars = { settings = { isIconEnabled = { [1] = true, [2] = true, [3] = true },
            markedItems = {} } },
        GetSavedVarsMarkedItemsTableName = function() return "markedItems" end,
        IsMarked = function() return false, { [1] = false, [2] = false, [3] = false } end,
        markedItems = { [1] = {}, [2] = {}, [3] = {} },
    }
    FCOIS_CON_ICON_DECONSTRUCTION = 1
    FCOIS_CON_ICON_SELL = 2
    FCOIS_CON_ICON_SELL_AT_GUILDSTORE = 3
    return profile, saved
end

function GetFCOItemSaverTests()
    local tests = {}
    local function Add(name, run) tests[#tests + 1] = { name = name, run = run } end

    Add("FCO baseline identities register only when saved profile metadata exists", function()
        Setup()
        this.FCOItemSaver.RegisterBuiltInGroups()
        assert(next(this.preLoadedRulesets) == nil)
        this.GetAutoCategoryProfile().fcoTestGroupsCreated = true
        this.FCOItemSaver.RegisterBuiltInGroups()
        assert(this.preLoadedRulesets.__ic_fco_deconstruct.isFCOGroup)
        assert(this.preLoadedRulesets.__ic_fco_sell_vendor.markerKey == "__ic_fco_sell_vendor")
        assert(this.preLoadedRulesets.__ic_fco_sell_guild.isFCOGroup)
    end)

    Add("FCO enable creates no groups while Suspend and removal do not require the dependency", function()
        Setup()
        local adapter = this.FCOItemSaver
        adapter.Enable()
        assert(this.accountWide.fcoIntegrationState == "enabled" and next(this.preLoadedRulesets) == nil)
        adapter.Suspend()
        assert(this.accountWide.fcoIntegrationState == "suspended")
        FCOIS = nil
        adapter.Suspend()
        assert(this.accountWide.fcoIntegrationState == "suspended",
            "Suspend instead must be harmless when already suspended and FCO is absent")
        assert(adapter.GetInactiveReason("__ic_fco_deconstruct") == "FCO suspended")
        assert(adapter.RemoveTestGroups())
    end)

    Add("FCO test groups preserve repeat edits and prepend all seven AutoCategory contexts", function()
        Setup()
        local profile = this.GetAutoCategoryProfile()
        this.accountWide.fcoIntegrationState = "enabled"
        assert(this.FCOItemSaver.AddTestGroups())
        local expected = "ic:__ic_fco_deconstruct,ic:__ic_fco_sell_vendor,ic:__ic_fco_sell_guild"
        for _, key in ipairs(contexts) do
            local order = profile.autoCategoryOrder.contexts[key]
            assert(table.concat(order.matching, ",") == expected)
            assert(table.concat(order.display, ",") == expected)
            assert(order.displayPositions["ic:__ic_fco_deconstruct"] == 1
                and order.displayPositions["ic:__ic_fco_sell_vendor"] == 2
                and order.displayPositions["ic:__ic_fco_sell_guild"] == 3)
        end
        for _, group in ipairs(this.FCOItemSaver.GetGroups()) do
            local rule = profile.trackedRules[group.key]
            assert(rule.display.show and not rule.display.bank and rule.display.group
                and rule.autoCategoryEnabled and rule.markerConditions.include[1])
        end
        profile.trackedRules.__ic_fco_deconstruct.display.show = false
        local before = table.concat(profile.autoCategoryOrder.contexts.backpack.display, ",")
        assert(not this.FCOItemSaver.AddTestGroups())
        assert(profile.trackedRules.__ic_fco_deconstruct.display.show == false
            and table.concat(profile.autoCategoryOrder.contexts.backpack.display, ",") == before)
    end)

    Add("FCO overlap actions create normal reusable groups and report unavailable markers", function()
        local profile = Setup()
        this.accountWide.fcoIntegrationState = "enabled"
        FCOIS.settingsVars.settings.isIconEnabled[3] = false
        assert(this.FCOItemSaver.AddOverlappingTestGroups())
        local rules = profile.trackedRules
        assert(rules.__ic_fco_test_marker_1.markerConditions.include[1] == 1
            and rules.__ic_fco_test_marker_2.markerConditions.include[1] == 2
            and rules.__ic_fco_test_marker_3 == nil)
        assert(#rules.__ic_fco_test_multiple.markerConditions.include == 2
            and rules.__ic_fco_test_negative.markerConditions.exclude[1] == 1
            and rules.__ic_fco_test_mixed.patterns[1] == "*map*")
        assert(this.lastFCOTestError:find("3:", 1, true))
        rules.__ic_fco_test_mixed.patterns[1] = "edited"
        assert(not this.FCOItemSaver.AddOverlappingTestGroups())
        assert(rules.__ic_fco_test_mixed.patterns[1] == "edited")
    end)

    Add("FCO test actions report name collisions and preserve the unrelated group", function()
        local profile = Setup()
        this.accountWide.fcoIntegrationState = "enabled"
        profile.trackedRules.mine = { displayName = "Deconstruct", patterns = { "keep" } }
        assert(this.FCOItemSaver.AddTestGroups())
        assert(profile.trackedRules.mine.patterns[1] == "keep"
            and profile.trackedRules.__ic_fco_deconstruct == nil
            and profile.trackedRules.__ic_fco_sell_vendor.markerConditions.include[1] == 2)
        assert(this.lastFCOTestError:find("Deconstruct", 1, true))
    end)

    Add("FCO removal clears only owned current-profile groups and references", function()
        Setup()
        local profile = this.GetAutoCategoryProfile()
        this.accountWide.fcoIntegrationState = "enabled"
        this.FCOItemSaver.AddTestGroups()
        profile.trackedRules.custom = { display = { show = true } }
        profile.autoCategoryOrder.contexts.backpack.display[#profile.autoCategoryOrder.contexts.backpack.display + 1] =
            "ic:custom"
        this.FCOItemSaver.RemoveTestGroups()
        assert(profile.fcoTestGroupsCreated == false and profile.trackedRules.custom)
        assert(profile.trackedRules.__ic_fco_deconstruct == nil)
        assert(table.concat(profile.autoCategoryOrder.contexts.backpack.display, ",") == "ic:custom")
    end)

    Add("FCO turn-off clears groups and references from every profile and backup", function()
        local profile, saved = Setup()
        this.accountWide.fcoIntegrationState = "enabled"
        this.FCOItemSaver.AddTestGroups()
        local other = {
            fcoTestGroupsCreated = true, trackedRules = {
                __ic_fco_sell_vendor = { markerConditions = { include = { 2 }, exclude = {} } } },
            autoCategoryOrder = NewOrder(),
        }
        other.accountWideListBackup = {
            fcoTestGroupsCreated = true, trackedRules = {
                __ic_fco_sell_guild = { markerConditions = { include = { 3 }, exclude = {} } } },
            autoCategoryOrder = NewOrder(),
        }
        saved.Default.other = { character = other }
        this.FCOItemSaver.TurnOff()
        assert(this.accountWide.fcoIntegrationState == "off")
        assert(profile.trackedRules.__ic_fco_deconstruct == nil and other.trackedRules.__ic_fco_sell_vendor == nil
            and other.accountWideListBackup.trackedRules.__ic_fco_sell_guild == nil)
        assert(other.fcoTestGroupsCreated == false and other.accountWideListBackup.fcoTestGroupsCreated == false)
        assert(next(this.preLoadedRulesets) == nil)
    end)

    Add("FCO turn-off removes arbitrary marker groups and tombstones built-ins without harming unrelated rules", function()
        local profile, saved = Setup()
        this.accountWide.fcoIntegrationState = "enabled"
        this.preLoadedRulesets.original = { displayName = "Original" }
        profile.trackedRules.custom = { markerConditions = { include = { 1, 2 }, exclude = { 3 } } }
        profile.trackedRules.original = { markerConditions = { include = {}, exclude = { 1 } } }
        profile.trackedRules.__ic_fco_deconstruct = { patterns = { "ordinary" } }
        profile.trackedRules.unrelated = { patterns = { "keep" } }
        local order = profile.autoCategoryOrder.contexts.backpack
        order.display = { "ic:custom", "ic:original", "ic:unrelated" }
        order.matching = { "ic:original", "ic:custom", "ic:unrelated" }
        order.hidden["ic:custom"] = true
        order.displayPositions["ic:original"] = 2
        local backup = { trackedRules = {
            backupCustom = { markerConditions = { include = { 3 }, exclude = {} } },
            keep = { patterns = { "unchanged" } },
        }, autoCategoryOrder = NewOrder() }
        saved.Default.other = { character = { accountWideListBackup = backup } }
        this.FCOItemSaver.TurnOff()
        assert(profile.trackedRules.custom == nil
            and profile.trackedRules.original.deletedBuiltIn == true
            and profile.trackedRules.__ic_fco_deconstruct.patterns[1] == "ordinary"
            and profile.trackedRules.unrelated.patterns[1] == "keep")
        assert(table.concat(order.display, ",") == "ic:unrelated"
            and table.concat(order.matching, ",") == "ic:unrelated"
            and order.hidden["ic:custom"] == nil and order.displayPositions["ic:original"] == nil)
        assert(backup.trackedRules.backupCustom == nil and backup.trackedRules.keep.patterns[1] == "unchanged")
        assert(FCOIS.markedItems[1] and FCOIS.markedItems[2] and FCOIS.markedItems[3])
    end)

    Add("FCO marker collection uses changed custom conditions instead of legacy key identity", function()
        Setup()
        this.accountWide.fcoIntegrationState = "enabled"
        local ids = this.FCOItemSaver.GetActiveMarkerIds({
            __ic_fco_deconstruct = { markerConditions = { include = { 2 }, exclude = { 3 } } },
            another = { markerConditions = { include = { 2 }, exclude = {} } },
        })
        assert(#ids == 2 and ids[1] == 2 and ids[2] == 3)
    end)

    Add("FCO availability monitoring detects marker changes without any groups", function()
        Setup()
        local before = this.FCOItemSaver.GetAvailabilitySignature({})
        FCOIS.settingsVars.settings.isIconEnabled[1] = false
        local disabled = this.FCOItemSaver.GetAvailabilitySignature({})
        assert(before ~= disabled)
        FCOIS.settingsVars.settings.isIconEnabled[1] = true
        assert(this.FCOItemSaver.GetAvailabilitySignature({}) == before)
        FCOIS = nil
        assert(this.FCOItemSaver.GetAvailabilitySignature({}) ~= before)
    end)

    Add("FCO turn-off preserves AC templates when another profile retains the same group key", function()
        local profile, saved = Setup()
        this.accountWide.fcoIntegrationState = "enabled"
        profile.trackedRules.shared = { markerConditions = { include = { 1 }, exclude = {} } }
        profile.trackedRules.removed = { markerConditions = { include = { 2 }, exclude = {} } }
        saved.Default.other = { character = { trackedRules = { shared = { patterns = { "keep" } } } } }
        local captured
        this.AutoCategoryIntegration.PreflightDeletedFCOGroups = function(keys)
            captured = keys
            return {}
        end
        this.FCOItemSaver.TurnOff()
        assert(captured.removed and not captured.shared)
        assert(saved.Default.other.character.trackedRules.shared.patterns[1] == "keep")
    end)

    Add("FCO turn-off stages every profile and backup before deleting from any of them", function()
        local _, saved = Setup()
        this.accountWide.fcoIntegrationState = "enabled"
        this.FCOItemSaver.RegisterBuiltInGroups(true)
        local first = {
            fcoTestGroupsCreated = true,
            trackedRules = { __ic_fco_deconstruct = { display = {} } },
            autoCategoryOrder = NewOrder(),
        }
        saved.Default.account.first = first
        local invalid = {
            fcoTestGroupsCreated = true,
            trackedRules = { __ic_fco_sell_vendor = { display = {} } },
            autoCategoryOrder = { contexts = { backpack = { display = false } } },
        }
        saved.Default.account.invalid = invalid
        local baseline = this.preLoadedRulesets
        local ok, failure = pcall(this.FCOItemSaver.TurnOff)
        assert(not ok and tostring(failure):find("display must be a table", 1, true))
        assert(this.accountWide.fcoIntegrationState == "enabled")
        assert(first.fcoTestGroupsCreated == true
            and first.trackedRules.__ic_fco_deconstruct
            and this.preLoadedRulesets == baseline,
            "A later malformed profile must not leave earlier profiles partially deleted")
    end)

    Add("FCO turn-off skips absent optional collections only after validating all profiles", function()
        local _, saved = Setup()
        this.accountWide.fcoIntegrationState = "enabled"
        local uninitialized = { itemListInitialized = false }
        saved.Default.account.uninitialized = uninitialized
        this.FCOItemSaver.TurnOff()
        assert(uninitialized.fcoTestGroupsCreated == false)
        assert(uninitialized.trackedRules == nil and uninitialized.autoCategoryOrder == nil)
    end)

    Add("FCO turn-off validates retained backups before mutating any profile", function()
        local _, saved = Setup()
        this.accountWide.fcoIntegrationState = "enabled"
        local earlier = { fcoTestGroupsCreated = true,
            trackedRules = { __ic_fco_deconstruct = {} }, autoCategoryOrder = NewOrder() }
        saved.Default.account.earlier = earlier
        local later = { fcoTestGroupsCreated = true, trackedRules = {}, autoCategoryOrder = NewOrder(),
            accountWideListBackup = { fcoTestGroupsCreated = true, trackedRules = false } }
        saved.Default.account.later = later
        local ok, failure = pcall(this.FCOItemSaver.TurnOff)
        assert(not ok and tostring(failure):find("accountWideListBackup.trackedRules must be a table", 1, true))
        assert(earlier.fcoTestGroupsCreated == true and earlier.trackedRules.__ic_fco_deconstruct
            and this.accountWide.fcoIntegrationState == "enabled",
            "Malformed retained backup must not allow earlier profile deletion")
    end)
    return tests
end
