local this = InventoryCompanion
local integration = this.AutoCategoryIntegration

local contexts = {
    { key = "backpack", bag = 1 },
    { key = "bank", bag = 2 },
    { key = "guild_bank", bag = 3 },
    { key = "house_bank", bag = 4 },
    { key = "crafting_station", bag = 5 },
    { key = "craft_bag", bag = 6 },
    { key = "furniture_vault", bag = 7 },
}

AC_BAG_TYPE_BACKPACK, AC_BAG_TYPE_BANK, AC_BAG_TYPE_GUILDBANK = 1, 2, 3
AC_BAG_TYPE_HOUSEBANK, AC_BAG_TYPE_CRAFTSTATION, AC_BAG_TYPE_CRAFTBAG = 4, 5, 6
AC_BAG_TYPE_FURNVAULT = 7
INVENTORY_BACKPACK, INVENTORY_BANK, INVENTORY_GUILD_BANK = 11, 12, 13
INVENTORY_HOUSE_BANK, INVENTORY_CRAFT_BAG, INVENTORY_FURNITURE_VAULT = 14, 15, 16
SI_ITEMFILTERTYPE_NEW = 999
function GetString() return "New" end

local function NewFixture(headingLists)
    local function Display()
        return { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false }
    end
    this.preLoadedRulesets = {
        alpha = { displayName = "Alpha", patterns = { "alpha" }, display = Display() },
        beta = { displayName = "Beta", patterns = { "beta" }, display = Display() },
        gamma = { displayName = "Gamma", patterns = { "gamma" }, display = Display() },
        miscellaneous = { displayName = "Miscellaneous", patterns = {}, display = Display() },
    }
    this.accountWide = { trackedRules = {}, trackedItems = {} }
    this.character = { trackedRules = {}, trackedItems = {}, useCharacterItemList = false }
    this.InvalidateRuleCache()
    this.ValidateSavedRuleProfiles()
    AutoCategory = { saved = { bags = {} } }
    local defaults = { "New", "Selling", "Low level" }
    for _, context in ipairs(contexts) do
        local names = headingLists and headingLists[context.key] or defaults
        local assignments = {}
        for index, name in ipairs(names) do
            assignments[#assignments + 1] = {
                name = name,
                runpriority = (#names - index + 1) * 100,
                showpriority = (#names - index + 1) * 100,
                isHidden = false,
            }
        end
        AutoCategory.saved.bags[context.bag] = { rules = assignments }
    end
    integration.OnRuleMutation = function() end
    integration.OnEnablementChanged = function() end
end
this.NewAutoCategoryTestFixture = NewFixture

local function FindRow(rows, kind, value)
    for _, row in ipairs(rows) do
        if row.kind == kind and (kind == "group" and row.ruleKey == value
            or kind == "heading" and row.name == value) then
            return row
        end
    end
end

local function NewStartupAutoCategory()
    AutoCategory = {
        Inited = false,
        saved = { bags = {} },
        acctSaved = { bags = {} },
        charSaved = { bags = {} },
        Plugins = {},
        RulesW = {
            ruleList = {},
            ruleNames = {},
            compiled = {},
            AddRule = function() end,
            CompileAll = function() end,
        },
        RuleList = { removeRuleByName = function() end },
        predefinedRules = {},
        RegisterPlugin = function(name, initialize, definitions)
            AutoCategory.Plugins[name] = { initialize = initialize, predef = definitions }
        end,
        AddRuleFunc = function() end,
        GetRuleByName = function() end,
        RefreshList = function() end,
        UpdateCurrentSavedVars = function() end,
        cacheInitBag = function() end,
        cacheInitialize = function() end,
        cacheRuleInitialize = function() end,
    }
    SI_DIALOG_CONFIRM = "Confirm"
    SI_DIALOG_CANCEL = "Cancel"
    ZO_Dialogs_RegisterCustomDialog = function() end
    d = function() end
end

-- Runs a full projection against fixture headings New/Selling/Low level (300/200/100) after
-- applying external Bank edits, and returns the resulting native Bank order for a priority field.
local function ProjectBank(editBank, buildRules)
    NewFixture()
    local fixtureBags = AutoCategory.saved.bags
    NewStartupAutoCategory()
    AutoCategory.saved.bags = fixtureBags
    AutoCategory.Inited = true
    AutoCategory.Plugins["Inventory Companion"] = { predef = {} }
    this.accountWide.autoCategoryInitialized = true
    this.accountWide.autoCategoryIntegrationEnabled = true
    local function HeadingId(name)
        for _, row in ipairs(integration.ResolveAutoCategoryOrder("master", { showAllHeadings = true })) do
            if row.kind == "heading" and row.name == name then return row.occurrenceId end
        end
        error("Fixture heading is missing: " .. name)
    end
    this.accountWide.trackedRules = buildRules(HeadingId)
    this.ValidateSavedRuleProfiles()
    for _, assignment in ipairs(AutoCategory.saved.bags[2].rules) do editBank(assignment) end

    integration.ProjectAutoCategory()

    return function(field)
        local entries = {}
        for _, assignment in ipairs(AutoCategory.saved.bags[2].rules) do entries[#entries + 1] = assignment end
        table.sort(entries, function(a, b)
            if a[field] ~= b[field] then return a[field] > b[field] end
            return a.name < b.name
        end)
        local names = {}
        for _, assignment in ipairs(entries) do
            local label = assignment.name
            if assignment.icOwned then label = assignment.name:match("Alpha$") and "alpha" or "beta" end
            names[#names + 1] = label
        end
        return table.concat(names, ",")
    end
end

-- Mirrors AutoCategory's rule registry: removeRuleByName shifts ruleList without reindexing
-- other ruleNames entries, and only cacheRuleInitialize rebuilds the name lookup.
local function InstallRuleRegistry(ac)
    local registry = ac.RulesW
    registry.ruleList, registry.ruleNames = {}, {}
    registry.AddRule = function(self, rule, overwrite)
        local index = self.ruleNames[rule.name]
        if index then
            if overwrite then self.ruleList[index] = rule end
        else
            self.ruleList[#self.ruleList + 1] = rule
            self.ruleNames[rule.name] = #self.ruleList
        end
    end
    ac.RuleList.removeRuleByName = function(self, name)
        local index = self.ruleNames[name]
        if index then
            self.ruleNames[name] = nil
            table.remove(self.ruleList, index)
        end
    end
    ac.GetRuleByName = function(name)
        local index = registry.ruleNames[name]
        return index and registry.ruleList[index]
    end
    ac.cacheRuleInitialize = function()
        registry.ruleNames = {}
        for index, rule in ipairs(registry.ruleList) do registry.ruleNames[rule.name] = index end
    end
end

function this.GetAutoCategoryIntegrationTests()
    return {
        {
            name = "Definition sync replaces renamed categories without losing other registered rules",
            run = function()
                NewFixture()
                local fixtureBags = AutoCategory.saved.bags
                NewStartupAutoCategory()
                AutoCategory.saved.bags = fixtureBags
                AutoCategory.Inited = true
                AutoCategory.Plugins["Inventory Companion"] = { predef = {} }
                InstallRuleRegistry(AutoCategory)
                this.accountWide.autoCategoryInitialized = true
                this.accountWide.autoCategoryIntegrationEnabled = true
                integration.ProjectAutoCategory()

                local registry, plugin = AutoCategory.RulesW, AutoCategory.Plugins["Inventory Companion"]
                local current = {}
                for _, rule in ipairs(registry.ruleList) do current[#current + 1] = rule.name end
                assert(#current == 3, "First sync must register one category per ordinary group")
                -- A previous rank-prefixed name for the first group, as left behind by a move or rename.
                local obsolete = { name = "|c000001|r" .. current[1], icIntegrationOwned = true, icRuleKey = "obsolete" }
                local external = { name = "External gate", tag = "Other add-on" }
                table.insert(registry.ruleList, 1, obsolete)
                table.insert(plugin.predef, 1, obsolete)
                registry.ruleList[#registry.ruleList + 1] = external
                AutoCategory.cacheRuleInitialize()

                integration.ProjectAutoCategory()

                local counts = {}
                for _, rule in ipairs(registry.ruleList) do counts[rule.name] = (counts[rule.name] or 0) + 1 end
                assert(counts[obsolete.name] == nil, "Obsolete integration category must be removed")
                assert(counts[external.name] == 1, "External categories must be preserved")
                for _, name in ipairs(current) do
                    assert(counts[name] == 1, "Integration category must remain registered exactly once: " .. name)
                end
                assert(#registry.ruleList == #current + 1, "Sync must not duplicate or drop categories")
            end,
        },
        {
            name = "AutoCategory plugin registers before active bag assignments are initialized",
            run = function()
                NewFixture()
                NewStartupAutoCategory()

                integration.Initialize()

                local plugin = AutoCategory.Plugins["Inventory Companion"]
                assert(plugin ~= nil, "Plugin registration must not require active bag assignments")
                assert(#plugin.predef > 0, "Plugin definitions must be registered before AutoCategory initializes")
                assert(select(1, integration.GetStatus()) == "disabled")
            end,
        },
        {
            name = "Enabled AutoCategory integration starts pending and projects after AutoCategory initializes",
            run = function()
                NewFixture()
                this.accountWide.autoCategoryInitialized = true
                this.accountWide.autoCategoryIntegrationEnabled = true
                NewStartupAutoCategory()
                local hooked, scheduled, projected = {}, {}, 0
                ZO_PostHook = function(target, name)
                    assert(target == AutoCategory)
                    hooked[name] = true
                end
                zo_callLater = function(callback) scheduled[#scheduled + 1] = callback end
                local project = integration.ProjectAutoCategory
                integration.ProjectAutoCategory = function() projected = projected + 1 end

                local ok, failure = pcall(function()
                    integration.Initialize()
                    assert(select(1, integration.GetStatus()) == "pending")
                    assert(hooked.UpdateCurrentSavedVars and hooked.cacheInitBag and hooked.cacheInitialize,
                        "Enabled startup must install AutoCategory lifecycle hooks")
                    assert(#scheduled == 0, "Projection must not be scheduled before AutoCategory initializes")

                    -- AutoCategory runs plugin initializers and then sets Inited in the same call.
                    AutoCategory.Plugins["Inventory Companion"].initialize()
                    AutoCategory.Inited = true
                    assert(#scheduled == 1, "Plugin initialization must schedule the first projection")
                    scheduled[1]()
                    assert(projected == 1, "Scheduled startup reconcile must project once AutoCategory is initialized")
                end)
                integration.ProjectAutoCategory = project
                assert(ok, failure)
            end,
        },
        {
            name = "AutoCategory preset dialog fits keyboard dialog buttons and applies the selected arrangement",
            run = function()
                NewFixture()
                AutoCategory = {
                    saved = { bags = {} },
                    acctSaved = { bags = {} },
                    charSaved = { bags = {} },
                    Plugins = {},
                    RegisterPlugin = function(name, initialize, definitions)
                        AutoCategory.Plugins[name] = { initialize = initialize, predef = definitions }
                    end,
                }
                SI_DIALOG_CONFIRM = "Confirm"
                SI_DIALOG_CANCEL = "Cancel"
                local registered
                ZO_Dialogs_RegisterCustomDialog = function(name, info)
                    assert(name == "INVENTORYCOMPANION_AUTOCATEGORY_PRESET")
                    registered = info
                end
                d = function() end

                integration.Initialize()

                assert(registered ~= nil, "Preset dialog must be registered")
                -- ESO keyboard ZO_Dialog has exactly two button controls; a third indexes nil.
                assert(#registered.buttons <= 2, "Keyboard dialogs support at most two buttons")
                assert(registered.noChoiceCallback ~= nil, "Escape/dismissal must have a no-choice path")
                for _, radio in ipairs(registered.radioButtons) do
                    integration.BuildPresetPlacements(radio.data)
                end

                local function FakeDialog(preset, reset)
                    return {
                        data = { reset = reset },
                        radioButtonGroup = {
                            GetClickedButton = function() return { data = preset } end,
                        },
                    }
                end
                registered.buttons[2].callback(FakeDialog("prefer_ic_groups", false))
                registered.noChoiceCallback(FakeDialog("prefer_ic_groups", false))
                assert(not this.GetAutoCategoryState().initialized, "Cancel must not apply a preset")

                registered.buttons[1].callback(FakeDialog("prefer_autocategory_groups", false))
                local state = this.GetAutoCategoryState()
                assert(state.initialized and state.enabled, "Confirm must apply the preset and enable integration")
            end,
        },
        {
            name = "Projection preserves independent external run and show priority orders",
            run = function()
                local Order = ProjectBank(function(assignment)
                    -- Mirrors an AutoCategory settings edit that moves only one priority field of a heading.
                    if assignment.name == "Low level" then assignment.runpriority = 350 end
                    -- Ties with the anchor stay above managed groups in that field.
                    if assignment.name == "Selling" then assignment.showpriority = 300 end
                end, function()
                    return {
                        alpha = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 100 },
                        beta = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 200 },
                    }
                end)
                assert(Order("runpriority") == "Low level,New,alpha,beta,Selling", Order("runpriority"))
                assert(Order("showpriority") == "New,Selling,alpha,beta,Low level", Order("showpriority"))
                assert(select(1, integration.GetStatus()) == "available")
            end,
        },
        {
            name = "Projection places groups of tied headings after the alphabetical tie block",
            run = function()
                local Order = ProjectBank(function(assignment)
                    if assignment.name == "Selling" then assignment.showpriority = 300 end
                end, function(headingId)
                    return {
                        alpha = { autoCategoryEnabled = true, autoCategoryAnchor = headingId("Selling"), autoCategoryRank = 100 },
                        beta = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 200 },
                    }
                end)
                -- AutoCategory orders the New/Selling show tie alphabetically; neither group can sit inside it.
                assert(Order("showpriority") == "New,Selling,beta,alpha,Low level", Order("showpriority"))
                assert(Order("runpriority") == "New,beta,Selling,alpha,Low level", Order("runpriority"))
                assert(select(1, integration.GetStatus()) == "available")
            end,
        },
        {
            name = "AutoCategory presets place every ordinary group without enabling participation",
            run = function()
                NewFixture()
                local placements = integration.BuildPresetPlacements("prefer_ic_groups")
                assert(placements.alpha and placements.beta and placements.gamma)
                assert(placements.miscellaneous == nil, "Miscellaneous must not be exported")
                assert(placements.alpha.anchor == "@default-new" and placements.beta.rank == 200)
                this.ApplyAutoCategoryPreset("prefer_ic_groups", false)
                assert(this.GetAutoCategoryState().initialized and not this.GetAutoCategoryState().enabled)
                assert(this.accountWide.trackedRules.alpha.autoCategoryEnabled == nil)
                assert(this.accountWide.trackedRules.gamma.autoCategoryRank == 300)
            end,
        },
        {
            name = "First participation inserts after the last participating group before inactive peers",
            run = function()
                NewFixture()
                this.accountWide.autoCategoryInitialized = true
                this.accountWide.trackedRules = {
                    alpha = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 100 },
                    beta = { autoCategoryAnchor = "@default-new", autoCategoryRank = 200 },
                }
                this.ValidateSavedRuleProfiles()
                assert(this.GetRuntimeRules().gamma ~= nil, "Fixture must include gamma")
                local alpha
                for _, row in ipairs(integration.ResolveAutoCategoryOrder("master", { showNonparticipants = true })) do
                    if row.kind == "group" and row.ruleKey == "alpha" then alpha = row end
                end
                assert(alpha ~= nil, "Fixture must resolve the participating group")
                this.SetAutoCategoryParticipation("gamma", true)
                local gamma = this.accountWide.trackedRules.gamma
                assert(gamma.autoCategoryEnabled == true and gamma.autoCategoryAnchor == alpha.resolvedAnchorId)
                assert(gamma.autoCategoryRank == 101, "The new group must fit between the last active and inactive groups")
                assert(this.accountWide.trackedRules.alpha.autoCategoryRank == 100)
                assert(this.accountWide.trackedRules.beta.autoCategoryRank == 200)
            end,
        },
        {
            name = "First participation persists rank rebalancing and preserves context overrides",
            run = function()
                NewFixture()
                this.accountWide.autoCategoryInitialized = true
                this.accountWide.trackedRules = {
                    alpha = { autoCategoryEnabled = true, autoCategoryAnchor = "New", autoCategoryRank = 1000 },
                    beta = {
                        autoCategoryAnchor = "New", autoCategoryRank = 1001,
                        autoCategoryOverrides = { bank = { rank = 2000 } },
                    },
                }
                this.ValidateSavedRuleProfiles()
                this.SetAutoCategoryParticipation("gamma", true)
                local saved = this.accountWide.trackedRules
                assert(saved.alpha.autoCategoryRank == 100 and saved.beta.autoCategoryRank == 200)
                assert(saved.beta.autoCategoryOverrides.bank.rank == 300)
                assert(saved.gamma.autoCategoryRank == 101)
                assert(saved.beta.autoCategoryOverrides.bank.anchor == nil,
                    "Rank cleanup must preserve sparse context placement fields")
            end,
        },
        {
            name = "Context moves alter only the moved group and leave Master ordering unchanged",
            run = function()
                NewFixture()
                this.accountWide.autoCategoryInitialized = true
                this.accountWide.autoCategoryIntegrationEnabled = true
                this.accountWide.trackedRules = {
                    alpha = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 100 },
                    beta = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 200 },
                    gamma = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 300 },
                }
                this.ValidateSavedRuleProfiles()
                assert(integration.MoveGroup("beta", "bank", -1))
                local master = integration.ResolveAutoCategoryOrder("master")
                local bank = integration.ResolveAutoCategoryOrder("bank")
                local function GroupNames(rows)
                    local names = {}
                    for _, row in ipairs(rows) do
                        if row.kind == "group" and row.participating then names[#names + 1] = row.ruleKey end
                    end
                    return table.concat(names, ",")
                end
                assert(GroupNames(master) == "alpha,beta,gamma")
                assert(GroupNames(bank) == "beta,alpha,gamma")
                assert(this.accountWide.trackedRules.alpha.autoCategoryOverrides == nil)
                assert(this.accountWide.trackedRules.gamma.autoCategoryOverrides == nil)
                assert(this.accountWide.trackedRules.beta.autoCategoryOverrides.bank.rank == 99)
            end,
        },
        {
            name = "Context heading visibility overrides are isolated and reset to Master",
            run = function()
                NewFixture()
                local master = integration.ResolveAutoCategoryOrder("master")
                local newHeading = FindRow(master, "heading", "New")
                assert(newHeading)
                local scopeCount = 0
                for _ in pairs(newHeading.contexts) do scopeCount = scopeCount + 1 end
                assert(scopeCount == 7, "Identical heading order should share one Master occurrence, got "
                    .. tostring(scopeCount))
                this.SetAutoCategoryHeadingVisibility("master", newHeading.occurrenceId, false)
                local afterMasterHide = integration.ResolveAutoCategoryOrder("master")
                local visibleNew = {}
                for _, row in ipairs(afterMasterHide) do
                    if row.kind == "heading" and row.name == "New" then
                        visibleNew[#visibleNew + 1] = row.occurrenceId
                    end
                end
                assert(#visibleNew == 0,
                    "Master heading remained visible for " .. newHeading.occurrenceId .. "; still visible: "
                        .. table.concat(visibleNew, ",") .. "; stored="
                        .. tostring(this.GetAutoCategoryState().order.headingVisibility[newHeading.occurrenceId]))
                this.SetAutoCategoryHeadingVisibility("bank", newHeading.occurrenceId, true)
                assert(FindRow(integration.ResolveAutoCategoryOrder("bank"), "heading", "New"))
                this.ResetAutoCategoryContext("bank")
                assert(FindRow(integration.ResolveAutoCategoryOrder("bank"), "heading", "New") == nil)
                assert(this.accountWide.autoCategoryOrder.overrides == nil)
            end,
        },
        {
            name = "Context views preserve their native heading sequences when orders differ",
            run = function()
                NewFixture({
                    backpack = { "New", "Selling", "Low level" },
                    bank = { "New", "Low level", "Selling" },
                    guild_bank = { "Selling", "New", "Low level" },
                })
                local function HeadingNames(key)
                    local names = {}
                    for _, row in ipairs(integration.ResolveAutoCategoryOrder(key)) do
                        if row.kind == "heading" then names[#names + 1] = row.name end
                    end
                    return table.concat(names, ",")
                end
                assert(HeadingNames("backpack") == "New,Selling,Low level")
                assert(HeadingNames("bank") == "New,Low level,Selling")
                assert(HeadingNames("guild_bank") == "Selling,New,Low level")
                local master = integration.ResolveAutoCategoryOrder("master")
                local newOccurrences = 0
                for _, row in ipairs(master) do
                    if row.kind == "heading" and row.name == "New" then newOccurrences = newOccurrences + 1 end
                end
                assert(newOccurrences >= 2, "Differing native orders require separate heading occurrences")
            end,
        },
    }
end
