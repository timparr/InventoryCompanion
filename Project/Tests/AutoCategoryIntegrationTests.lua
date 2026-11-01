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
local originalOnRuleMutation = integration.OnRuleMutation
local originalOnEnablementChanged = integration.OnEnablementChanged

AC_BAG_TYPE_BACKPACK, AC_BAG_TYPE_BANK, AC_BAG_TYPE_GUILDBANK = 1, 2, 3
AC_BAG_TYPE_HOUSEBANK, AC_BAG_TYPE_CRAFTSTATION, AC_BAG_TYPE_CRAFTBAG = 4, 5, 6
AC_BAG_TYPE_FURNVAULT = 7
INVENTORY_BACKPACK, INVENTORY_BANK, INVENTORY_GUILD_BANK = 11, 12, 13
INVENTORY_HOUSE_BANK, INVENTORY_CRAFT_BAG, INVENTORY_FURNITURE_VAULT = 14, 15, 16
SI_ITEMFILTERTYPE_NEW = 999
function GetString() return "New" end

local function NewOrder()
    local order = { contexts = {} }
    for _, context in ipairs(contexts) do
        order.contexts[context.key] = { display = {}, matching = {} }
    end
    return order
end

local function Assignment(name, runpriority, showpriority, extra)
    local assignment = {
        name = name, runpriority = runpriority, showpriority = showpriority,
        isHidden = false,
    }
    for key, value in pairs(extra or {}) do assignment[key] = value end
    return assignment
end

local function NewFixture(headingLists)
    this.autoCategoryFailure = nil
    local function Display()
        return { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false }
    end
    this.preLoadedRulesets = {
        alpha = { displayName = "Alpha", patterns = { "alpha" }, display = Display() },
        beta = { displayName = "Beta", patterns = { "beta" }, display = Display() },
        gamma = { displayName = "Gamma", patterns = { "gamma" }, display = Display() },
        miscellaneous = { displayName = "Miscellaneous", patterns = {}, display = Display() },
    }
    this.accountWide = { trackedRules = {}, trackedItems = {}, autoCategoryOrder = NewOrder() }
    this.character = { trackedRules = {}, trackedItems = {}, useCharacterItemList = false, autoCategoryOrder = NewOrder() }
    this.InvalidateRuleCache()
    this.ValidateSavedRuleProfiles()
    AutoCategory = { saved = { bags = {} } }
    local defaults = { "New", "Selling", "Low level" }
    for _, context in ipairs(contexts) do
        local names = headingLists and headingLists[context.key] or defaults
        local assignments = {}
        for index, name in ipairs(names) do
            assignments[#assignments + 1] = Assignment(name,
                (#names - index + 1) * 100, (#names - index + 1) * 100)
        end
        AutoCategory.saved.bags[context.bag] = { rules = assignments }
    end
    integration.OnRuleMutation = function() end
    integration.OnEnablementChanged = function() end
end
this.NewAutoCategoryTestFixture = NewFixture

local function NewStartupAutoCategory()
    local registry = { ruleList = {}, ruleNames = {}, compiled = {} }
    registry.AddRule = function(self, rule, overwrite)
        local index = self.ruleNames[rule.name]
        if index then
            if overwrite then self.ruleList[index] = rule end
        else
            self.ruleList[#self.ruleList + 1] = rule
            self.ruleNames[rule.name] = #self.ruleList
        end
    end
    local ac = {
        Inited = false,
        saved = AutoCategory.saved,
        acctSaved = { bags = {}, rules = {} },
        charSaved = { bags = {}, rules = {} },
        Plugins = {},
        RulesW = registry,
        RuleList = {},
        predefinedRules = {},
        RefreshList = function() end,
        UpdateCurrentSavedVars = function() end,
        cacheInitBag = function() end,
        cacheInitialize = function() end,
        cacheRuleInitialize = function()
            registry.ruleNames = {}
            for index, rule in ipairs(registry.ruleList) do registry.ruleNames[rule.name] = index end
        end,
        AddRuleFunc = function(_, predicate) registry.predicate = predicate end,
        renameBagRule = function() end,
    }
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
    ac.RulesW.CompileAll = function() end
    ac.RegisterPlugin = function(name, initialize, definitions)
        ac.Plugins[name] = { initialize = initialize, predef = definitions }
    end
    ac.RefreshList = function() end
    AutoCategory = ac
    return ac
end

local function PrepareActive(rules)
    NewFixture()
    local bags = AutoCategory.saved.bags
    NewStartupAutoCategory()
    AutoCategory.saved.bags = bags
    AutoCategory.Inited = true
    AutoCategory.Plugins["Inventory Companion"] = { predef = {} }
    this.accountWide.trackedRules = rules or {}
    this.accountWide.autoCategoryIntegrationEnabled = true
    this.ValidateSavedRuleProfiles()
    this.InvalidateRuleCache()
    d = function() end
end

local function Names(sequence)
    local names = {}
    for _, reference in ipairs(sequence) do names[#names + 1] = reference:sub(4) end
    return table.concat(names, ",")
end

local function FindAssignment(contextKey, name)
    local bag = AutoCategory.saved.bags[contexts[1].bag]
    for _, context in ipairs(contexts) do
        if context.key == contextKey then bag = AutoCategory.saved.bags[context.bag]; break end
    end
    for _, assignment in ipairs(bag.rules) do
        if assignment.name == name then return assignment end
    end
end

local function InstallHooks()
    local hooks = {}
    ZO_PostHook = function(target, name, callback)
        assert(target == AutoCategory)
        hooks[name] = callback or true
    end
    local scheduled = {}
    zo_callLater = function(callback) scheduled[#scheduled + 1] = callback end
    return hooks, scheduled
end

function this.GetAutoCategoryIntegrationTests()
    return {
        {
            name = "Startup imports the native fractional display key independently from matching priority",
            run = function()
                PrepareActive({
                    alpha = { autoCategoryEnabled = true },
                    beta = {}, gamma = {},
                })
                AutoCategory.saved.bags[1].rules = {
                    Assignment("New", 100, 100),
                    Assignment("Set", 100, 100, { isHidden = true, externalMetadata = "preserved" }),
                    Assignment("Utility", 99.94, 99.94, { icOwned = true, icRuleKey = "alpha" }),
                    Assignment("Test group", 99.89, 99.89),
                }
                assert(integration.ProjectAutoCategory())
                local orders = this.accountWide.autoCategoryOrder.contexts.backpack
                assert(Names(orders.display) == "New,Set,Test group,alpha", Names(orders.display))
                assert(Names(orders.matching) == "New,Set,alpha,Test group", Names(orders.matching))
                local unique = {}
                for _, assignment in ipairs(AutoCategory.saved.bags[1].rules) do
                    assert(assignment.showpriority >= 2 and assignment.showpriority <= 1000
                        and assignment.showpriority == math.floor(assignment.showpriority))
                    assert(assignment.runpriority >= 2 and assignment.runpriority <= 1000
                        and assignment.runpriority == math.floor(assignment.runpriority))
                    unique[assignment.showpriority] = true
                end
                assert(#AutoCategory.saved.bags[1].rules == 4)
                assert(FindAssignment("backpack", "Set").isHidden == true)
                assert(FindAssignment("backpack", "Set").externalMetadata == "preserved")
            end,
        },
        {
            name = "Display and matching moves update only their own context sequence",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                integration.ProjectAutoCategory()
                local contextOrder = this.accountWide.autoCategoryOrder.contexts.backpack
                local bankDisplay = Names(this.accountWide.autoCategoryOrder.contexts.bank.display)
                local oldMatching, oldRun = Names(contextOrder.matching), {}
                for _, assignment in ipairs(AutoCategory.saved.bags[1].rules) do
                    oldRun[assignment.name] = assignment.runpriority
                end
                assert(integration.MoveEntry("ic:alpha", "backpack", "display", -1))
                contextOrder = this.accountWide.autoCategoryOrder.contexts.backpack
                assert(Names(contextOrder.matching) == oldMatching)
                for name, priority in pairs(oldRun) do
                    assert(FindAssignment("backpack", name).runpriority == priority)
                end
                local oldDisplay = Names(contextOrder.display)
                assert(integration.MoveEntry("ic:alpha", "backpack", "matching", -1))
                contextOrder = this.accountWide.autoCategoryOrder.contexts.backpack
                assert(Names(contextOrder.display) == oldDisplay)
                assert(Names(contextOrder.matching) ~= oldMatching)
                assert(Names(this.accountWide.autoCategoryOrder.contexts.bank.display) == bankDisplay)
            end,
        },
        {
            name = "Cross-context copy preserves destination-only slots and never changes participation",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                AutoCategory.saved.bags[2].rules[#AutoCategory.saved.bags[2].rules + 1] =
                    Assignment("Bank only", 50, 50)
                integration.ProjectAutoCategory()
                integration.MoveEntry("ac:New", "backpack", "display", 1)
                local sourceBefore = Names(this.accountWide.autoCategoryOrder.contexts.backpack.display)
                local alphaParticipation = this.accountWide.trackedRules.alpha.autoCategoryEnabled
                assert(integration.CopyBothOrders("backpack", "bank"))
                local bankOrder = this.accountWide.autoCategoryOrder.contexts.bank
                assert(Names(bankOrder.display) == "Selling,New,Low level,Bank only,alpha", Names(bankOrder.display))
                assert(this.accountWide.trackedRules.alpha.autoCategoryEnabled == alphaParticipation)
                assert(Names(this.accountWide.autoCategoryOrder.contexts.backpack.display) == sourceBefore)
                local matching = Names(bankOrder.matching)
                assert(integration.UseOtherOrder("bank", "display"))
                assert(Names(this.accountWide.autoCategoryOrder.contexts.bank.display) == matching)
                assert(integration.CopyBothOrders("bank", "bank") == false)
            end,
        },
        {
            name = "Participation adds and removes stable IC references without rank-based fields",
            run = function()
                PrepareActive({})
                integration.OnRuleMutation = originalOnRuleMutation
                this.SetAutoCategoryParticipation("alpha", true)
                local reference = "ic:alpha"
                for _, context in ipairs(contexts) do
                    local order = this.accountWide.autoCategoryOrder.contexts[context.key]
                    assert(order.display[#order.display] == reference)
                    assert(order.matching[#order.matching] == reference)
                end
                local managed = FindAssignment("backpack", "|t18:18:EsoUI/Art/Buttons/plus_up.dds|t Alpha")
                assert(managed and managed.icRuleKey == "alpha")
                this.SetAutoCategoryParticipation("alpha", false)
                local savedAlpha = this.accountWide.trackedRules.alpha or {}
                assert(savedAlpha.autoCategoryAnchor == nil and savedAlpha.autoCategoryRank == nil)
                assert(FindAssignment("backpack", managed.name) == nil)
            end,
        },
        {
            name = "Projection round-trip is idempotent and disabling preserves native assignments",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                integration.ProjectAutoCategory()
                local nativeBefore = {}
                for _, assignment in ipairs(AutoCategory.saved.bags[1].rules) do
                    if assignment.icOwned ~= true then
                        nativeBefore[assignment.name] = {
                            runpriority = assignment.runpriority,
                            showpriority = assignment.showpriority,
                            isHidden = assignment.isHidden,
                        }
                    end
                end
                integration.ProjectAutoCategory()
                for name, previous in pairs(nativeBefore) do
                    local assignment = FindAssignment("backpack", name)
                    assert(assignment.runpriority == previous.runpriority)
                    assert(assignment.showpriority == previous.showpriority)
                    assert(assignment.isHidden == previous.isHidden)
                end

                integration.OnEnablementChanged = originalOnEnablementChanged
                this.SetAutoCategoryIntegrationEnabled(false)
                for _, assignment in ipairs(AutoCategory.saved.bags[1].rules) do
                    assert(assignment.icOwned ~= true)
                    local previous = nativeBefore[assignment.name]
                    assert(previous ~= nil, "Disabling must leave native assignments intact")
                    assert(assignment.runpriority == previous.runpriority)
                    assert(assignment.showpriority == previous.showpriority)
                    assert(assignment.isHidden == previous.isHidden)
                end
            end,
        },
        {
            name = "Saved-data cleanup removes only explicitly IC-owned assignments in both AC profiles",
            run = function()
                PrepareActive({})
                for _, profileName in ipairs({ "acctSaved", "charSaved" }) do
                    local profile = AutoCategory[profileName]
                    for _, context in ipairs(contexts) do
                        profile.bags[context.bag] = { rules = {
                            Assignment("IC-owned", 100, 100, { icOwned = true, icRuleKey = "alpha" }),
                            Assignment("Native", 90, 90, { custom = "preserved" }),
                        } }
                    end
                end
                local removals = integration.PreflightSavedDataCleanup()
                assert(#removals == 14)
                assert(integration.ApplySavedDataCleanup(removals) == 14)
                for _, profileName in ipairs({ "acctSaved", "charSaved" }) do
                    for _, context in ipairs(contexts) do
                        local rules = AutoCategory[profileName].bags[context.bag].rules
                        assert(#rules == 1 and rules[1].name == "Native" and rules[1].custom == "preserved")
                    end
                end
            end,
        },
        {
            name = "Reconciliation removes deleted native rows and imports newly assigned categories",
            run = function()
                PrepareActive({})
                integration.ProjectAutoCategory()
                local bank = AutoCategory.saved.bags[2].rules
                table.remove(bank, 2)
                bank[#bank + 1] = Assignment("New native", 75, 75)
                integration.ProjectAutoCategory()
                local order = this.accountWide.autoCategoryOrder.contexts.bank
                assert(not table.concat(order.display, ","):find("ac:Selling", 1, true))
                assert(table.concat(order.display, ","):find("ac:New native", 1, true))
                assert(#order.display == 3 and #order.matching == 3)
            end,
        },
        {
            name = "Integer projection accepts 999 assignments and rejects 1000 without writes",
            run = function()
                PrepareActive({})
                local backpack = AutoCategory.saved.bags[1]
                backpack.rules = {}
                for index = 1, 999 do
                    backpack.rules[index] = Assignment(string.format("Native %03d", index), 1000 - index, 1000 - index,
                        { filter = "preserved" })
                end
                assert(integration.ProjectAutoCategory())
                assert(#backpack.rules == 999)
                for index, assignment in ipairs(backpack.rules) do
                    assert(assignment.showpriority >= 2 and assignment.runpriority >= 2)
                    assert(assignment.filter == "preserved")
                end
                local beforeOrder = table.concat(this.accountWide.autoCategoryOrder.contexts.backpack.display, ",")
                backpack.rules[1000] = Assignment("Native 1000", 1, 1)
                local beforeFirst, beforeLast = backpack.rules[1].showpriority, backpack.rules[1000].showpriority
                local prepared = integration.PreflightAutoCategory()
                assert(prepared == nil, "1000 assignments must fail preflight")
                assert(table.concat(this.accountWide.autoCategoryOrder.contexts.backpack.display, ",") == beforeOrder)
                assert(backpack.rules[1].showpriority == beforeFirst and backpack.rules[1000].showpriority == beforeLast)
                assert(integration.IsFaulted() and not this.GetAutoCategoryState().enabled)
            end,
        },
        {
            name = "AutoCategory classifier failure disables the predicate and preserves core rules",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                AutoCategory.Inited = false
                AutoCategory.Plugins["Inventory Companion"] = nil
                this.accountWide.autoCategoryIntegrationEnabled = nil
                integration.Initialize()
                AutoCategory.Plugins["Inventory Companion"].initialize()
                this.accountWide.autoCategoryIntegrationEnabled = true
                AutoCategory.checkingItemLink = "synthetic link"
                local match = this.ItemMatchesRuntimeRule
                this.ItemMatchesRuntimeRule = function() error("synthetic matching failure") end
                local predicate = AutoCategory.RulesW.predicate
                local ok, result = pcall(predicate, "alpha")
                this.ItemMatchesRuntimeRule = match
                assert(ok and result == false and integration.IsFaulted())
                assert(predicate("alpha") == false)
                assert(this.GetRuntimeRules().alpha, "IC core rule resolution must remain available")
            end,
        },
        {
            name = "AutoCategory startup errors disable integration without escaping to core startup",
            run = function()
                PrepareActive({})
                AutoCategory.Inited = false
                AutoCategory.Plugins["Inventory Companion"] = nil
                AutoCategory.RegisterPlugin = function() error("synthetic registration failure") end
                local warnings = {}
                d = function(message) warnings[#warnings + 1] = message end
                assert(pcall(integration.Initialize))
                assert(integration.IsFaulted() and not integration.IsAvailable())
                assert(not this.GetAutoCategoryState().enabled)
                assert(select(1, integration.GetStatus()) == "error")
                assert(warnings[1]:find("synthetic registration failure", 1, true))
                assert(this.accountWide.autoCategoryIntegrationEnabled,
                    "Session disable must preserve the saved enablement choice")
            end,
        },
        {
            name = "AutoCategory plugin registers before assignments initialize and projects after activation",
            run = function()
                NewFixture()
                NewStartupAutoCategory()
                integration.Initialize()
                assert(AutoCategory.Plugins["Inventory Companion"] ~= nil)
                assert(select(1, integration.GetStatus()) == "disabled")

                PrepareActive({})
                AutoCategory.Inited = false
                AutoCategory.Plugins["Inventory Companion"] = nil
                local hooks, scheduled = InstallHooks()
                integration.Initialize()
                assert(select(1, integration.GetStatus()) == "pending")
                assert(hooks.UpdateCurrentSavedVars and hooks.cacheInitBag and hooks.cacheInitialize and hooks.renameBagRule)
                AutoCategory.Plugins["Inventory Companion"].initialize()
                AutoCategory.Inited = true
                assert(#scheduled == 1)
                scheduled[1]()
                assert(select(1, integration.GetStatus()) == "available")
                for _, context in ipairs(contexts) do
                    for _, assignment in ipairs(AutoCategory.saved.bags[context.bag].rules) do
                        if assignment.name == "Selling" then assignment.name = "Sale" end
                    end
                end
                hooks.renameBagRule("Selling", "Sale")
                for _, context in ipairs(contexts) do
                    local order = this.accountWide.autoCategoryOrder.contexts[context.key]
                    for _, mode in ipairs({ "display", "matching" }) do
                        for _, reference in ipairs(order[mode]) do
                            assert(reference ~= "ac:Selling")
                        end
                    end
                end
                assert(#scheduled == 2)
                scheduled[2]()
                for _, context in ipairs(contexts) do
                    local order = this.accountWide.autoCategoryOrder.contexts[context.key]
                    assert(table.concat(order.display, ","):find("ac:Sale", 1, true))
                    assert(table.concat(order.matching, ","):find("ac:Sale", 1, true))
                end
                local warnings = {}
                d = function(message) warnings[#warnings + 1] = message end
                hooks.cacheInitBag()
                assert(#scheduled == 3)
                AutoCategory.cacheRuleInitialize = function() error("synthetic cache failure") end
                assert(pcall(scheduled[3]), "Deferred integration errors must not escape")
                assert(integration.IsFaulted() and not this.GetAutoCategoryState().enabled)
                assert(warnings[1]:find("synthetic cache failure", 1, true))
                local warningCount = #warnings
                hooks.cacheInitBag()
                assert(#scheduled == 3 and #warnings == warningCount,
                    "A failed session must stop scheduling and avoid repeated warnings")
            end,
        },
    }
end
