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
local icCategoryNameMarkupSuffix = "|cFFFFFF|r"
local originalOnRuleMutation = integration.OnRuleMutation
local originalOnEnablementChanged = integration.OnEnablementChanged

AC_BAG_TYPE_BACKPACK, AC_BAG_TYPE_BANK, AC_BAG_TYPE_GUILDBANK = 1, 2, 3
AC_BAG_TYPE_HOUSEBANK, AC_BAG_TYPE_CRAFTSTATION, AC_BAG_TYPE_CRAFTBAG = 4, 5, 6
AC_BAG_TYPE_FURNVAULT = 7
INVENTORY_BACKPACK, INVENTORY_BANK, INVENTORY_GUILD_BANK = 11, 12, 13
INVENTORY_HOUSE_BANK, INVENTORY_CRAFT_BAG, INVENTORY_FURNITURE_VAULT = 14, 15, 16
-- Distinct IDs and strings: insertion must resolve AutoCategory's localized New heading, never ESO's filter label.
SI_ITEMFILTERTYPE_NEW = 999
SI_AC_DEFAULT_CATEGORY_NEW = 998
local localizedStrings = { [SI_ITEMFILTERTYPE_NEW] = "Filter New", [SI_AC_DEFAULT_CATEGORY_NEW] = "New" }
function GetString(stringId)
    return assert(localizedStrings[stringId], "GetString mock received an unexpected string ID")
end

local fakeClock = 0
function GetGameTimeMilliseconds() return fakeClock end
function GetTimeStamp() return 1793641920 end
function GetDateStringFromTimestamp(timestamp)
    assert(timestamp == 1793641920)
    return "2026-11-02"
end
function GetTimeString() return "17:52:00" end
local frameUpdates = {}
EVENT_MANAGER = EVENT_MANAGER or {}
function EVENT_MANAGER:RegisterForUpdate(name, _, callback) frameUpdates[name] = callback end
function EVENT_MANAGER:UnregisterForUpdate(name) frameUpdates[name] = nil end
this.AutoCategoryTestClock = {
    Advance = function(ms) fakeClock = fakeClock + ms end,
    RunFrame = function()
        local callbacks = {}
        for _, callback in pairs(frameUpdates) do callbacks[#callbacks + 1] = callback end
        for _, callback in ipairs(callbacks) do callback() end
        return #callbacks
    end,
    Reset = function()
        frameUpdates = {}
        this.accountWide.debugEnabled = true
        this.accountWide.autoCategoryTimingThresholdMs = 100
        integration.Timing.lastSlowReport = nil
    end,
}

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
    this.autoCategoryFailureTraceback = nil
    integration.failureDiagnostics = nil
    local function Display()
        return { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false }
    end
    this.preLoadedRulesets = {
        alpha = { displayName = "Alpha", patterns = { "alpha" }, display = Display() },
        beta = { displayName = "Beta", patterns = { "beta" }, display = Display() },
        gamma = { displayName = "Gamma", patterns = { "gamma" }, display = Display() },
        miscellaneous = { displayName = "Miscellaneous", patterns = {}, display = Display() },
    }
    this.accountWide = {
        trackedRules = {}, trackedItems = {}, debug = { autoCategoryRemovedLines = {} },
        autoCategoryOrder = NewOrder(),
    }
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

local setupDialogs, shownSetup = {}, nil
GAMEPAD_DIALOGS = { BASIC = 1 }
SI_DIALOG_CONFIRM = "Confirm"
SI_DIALOG_CANCEL = "Cancel"
function ZO_Dialogs_RegisterCustomDialog(name, definition) setupDialogs[name] = definition end
function ZO_Dialogs_ShowDialog(name, data)
    local definition = assert(setupDialogs[name])
    assert(type(definition.radioButtons) == "table" and #definition.radioButtons == 2,
        "Setup must offer exactly two radio arrangement choices")
    assert(#definition.buttons == 2 and definition.buttons[1].text == SI_DIALOG_CONFIRM
        and definition.buttons[2].text == SI_DIALOG_CANCEL,
        "Setup must use exactly Confirm and Cancel action buttons")
    -- ESO's radio dialog preselects the first choice; GetClickedButton returns the clicked button control.
    local clicked = { data = definition.radioButtons[1].data }
    shownSetup = {
        definition = definition, data = data,
        radioButtonGroup = { GetClickedButton = function() return clicked end },
        SelectRadio = function(index) clicked = { data = assert(definition.radioButtons[index]).data } end,
        ClearRadio = function() clicked = nil end,
    }
end

local function ConfirmSetup(radioIndex)
    assert(shownSetup, "AutoCategory setup dialog was not shown")
    if radioIndex then shownSetup.SelectRadio(radioIndex) end
    shownSetup.definition.buttons[1].callback(shownSetup)
end

local function CancelSetup()
    assert(shownSetup, "AutoCategory setup dialog was not shown")
    shownSetup.definition.buttons[2].callback(shownSetup)
end

local function PrepareInitialSetup()
    NewFixture()
    NewStartupAutoCategory()
    d = function() end
    this.RefreshAutoCategoryUI = function() end
    integration.Initialize()
    assert(integration.IsAvailable())
    AutoCategory.Inited = true
    shownSetup = nil
end

function this.GetAutoCategoryIntegrationTests()
    return {
        {
            name = "AutoCategory bulk movement preserves contiguous blocks and separated selections",
            run = function()
                local sequence = { "ac:A", "ic:alpha", "ic:beta", "ac:B", "ac:C" }
                local block = { ["ic:alpha"] = true, ["ic:beta"] = true }
                local moved, changed = integration.GetMovedSequence(sequence, block, -1)
                assert(changed and Names(moved) == "alpha,beta,A,B,C", Names(moved))
                moved = integration.GetMovedSequence(sequence, block, 1)
                assert(Names(moved) == "A,B,alpha,beta,C", Names(moved))
                local separated = { ["ic:alpha"] = true, ["ac:B"] = true }
                moved = integration.GetMovedSequence(sequence, separated, -1)
                assert(Names(moved) == "alpha,A,B,beta,C", Names(moved))
                moved = integration.GetMovedSequence(sequence, separated, "top")
                assert(Names(moved) == "alpha,B,A,beta,C")
                moved = integration.GetMovedSequence(sequence, separated, "bottom")
                assert(Names(moved) == "A,beta,C,alpha,B")
                assert(Names(sequence) == "A,alpha,beta,B,C", "Movement must not mutate its input")
                local ok = pcall(integration.GetMovedSequence, sequence, { missing = true }, 1)
                assert(not ok, "Missing selected references must fail")
            end,
        },
        {
            name = "AutoCategory bulk jumps equal repeated single steps for every selection including merging and boundaries",
            run = function()
                local sequence = { "ac:1", "ic:2", "ac:3", "ic:4", "ac:5", "ic:6", "ac:7" }
                for mask = 0, 127 do
                    local selection = {}
                    for index, reference in ipairs(sequence) do
                        if math.floor(mask / 2 ^ (index - 1)) % 2 == 1 then selection[reference] = true end
                    end
                    for _, movement in ipairs({ -10, -5, -1, 1, 5, 10, "top", "bottom" }) do
                        local moved = integration.GetMovedSequence(sequence, selection, movement)
                        local selectedBefore, otherBefore, selectedAfter, otherAfter = {}, {}, {}, {}
                        for _, reference in ipairs(sequence) do
                            local target = selection[reference] and selectedBefore or otherBefore
                            target[#target + 1] = reference
                        end
                        for _, reference in ipairs(moved) do
                            local target = selection[reference] and selectedAfter or otherAfter
                            target[#target + 1] = reference
                        end
                        assert(#moved == #sequence and Names(selectedBefore) == Names(selectedAfter)
                            and Names(otherBefore) == Names(otherAfter), "Movement changed membership or relative order")
                        if type(movement) == "number" then
                            local repeated = sequence
                            for _ = 1, math.abs(movement) do
                                repeated = integration.GetMovedSequence(repeated, selection, movement < 0 and -1 or 1)
                            end
                            assert(Names(moved) == Names(repeated), "Jump differs from repeated steps")
                        end
                    end
                end
                local moved = integration.GetMovedSequence(sequence, { ["ac:1"] = true, ["ac:3"] = true }, -1)
                assert(Names(moved) == "1,3,2,4,5,6,7", "Only the boundary run should remain pinned")
            end,
        },
        {
            name = "AutoCategory bulk operations apply immediately once and isolate context and mode",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true } })
                local _, scheduled = InstallHooks()
                assert(integration.ProjectAutoCategory(), this.autoCategoryFailure)
                local saved = this.accountWide.autoCategoryOrder
                local oldMatching = Names(saved.contexts.backpack.matching)
                local oldBank = Names(saved.contexts.bank.display)
                local callbacks = #scheduled
                local selection = { ["ic:alpha"] = true, ["ic:beta"] = true }
                assert(integration.MoveEntries(selection, "backpack", "display", -10), this.autoCategoryFailure)
                assert(#scheduled == callbacks, "Bulk movement must apply without scheduling a deferred apply")
                local orders = this.accountWide.autoCategoryOrder.contexts
                assert(Names(orders.backpack.display) == "alpha,beta,New,Selling,Low level")
                assert(Names(orders.backpack.matching) == oldMatching and Names(orders.bank.display) == oldBank)
                local bag
                for _, context in ipairs(contexts) do
                    if context.key == "backpack" then bag = AutoCategory.saved.bags[context.bag] end
                end
                local alpha
                for _, assignment in ipairs(bag.rules) do
                    if assignment.icRuleKey == "alpha" then alpha = assignment end
                end
                assert(alpha.showpriority == 1000, "AutoCategory must receive the moved order immediately")
                assert(not integration.MoveEntries(selection, "backpack", "display", -1))
            end,
        },
        {
            name = "Renaming a participating group updates its AutoCategory heading",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                local _, scheduled = InstallHooks()
                integration.OnRuleMutation = originalOnRuleMutation
                assert(integration.ProjectAutoCategory(), this.autoCategoryFailure)
                local oldName = "Alpha" .. icCategoryNameMarkupSuffix
                assert(FindAssignment("backpack", oldName), "Initial AutoCategory heading is missing")

                this.UpdateRuleProperty("alpha", "displayName", "Alpha Prime")
                assert(#scheduled == 1, "Group rename must schedule AutoCategory reconciliation")
                scheduled[1]()

                assert(not integration.IsFaulted(), this.autoCategoryFailure)
                assert(FindAssignment("backpack", "Alpha Prime" .. icCategoryNameMarkupSuffix),
                    "Renamed group must update its AutoCategory heading")
                assert(not FindAssignment("backpack", oldName), "Old AutoCategory heading must be removed")
            end,
        },
        {
            name = "AutoCategory timing reports a slow move with phases without disabling integration",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true } })
                this.AutoCategoryTestClock.Reset()
                InstallHooks()
                assert(integration.ProjectAutoCategory(), this.autoCategoryFailure)
                local refreshList = AutoCategory.RefreshList
                local forcedRefreshes = 0
                AutoCategory.RefreshList = function(inventoryType, evenIfHidden)
                    if evenIfHidden ~= false then forcedRefreshes = forcedRefreshes + 1 end
                    this.AutoCategoryTestClock.Advance(150)
                    return refreshList(inventoryType, evenIfHidden)
                end
                local ok, report = pcall(integration.TimeAction, "editor", "move", integration.TimingSnapshot,
                    integration.MoveEntries, { ["ic:beta"] = true }, "backpack", "display", -1)
                AutoCategory.RefreshList = refreshList
                assert(ok, "A slow move must report to chat without raising: " .. tostring(report))
                assert(forcedRefreshes == 0, "Projection must not force hidden inventories to rebuild")
                report = tostring(integration.Timing.lastSlowReport)
                assert(report:find("editor: move took 150 ms synchronously", 1, true), report)
                assert(report:find("\n  MoveEntries: 150 ms", 1, true), report)
                assert(report:find("ProjectPlans: 150 ms", 1, true), report)
                assert(report:find("AutoCategory RefreshList backpack: 150 ms", 1, true), report)
                assert(not integration.IsFaulted(), "Timing reports must not disable integration")
            end,
        },
        {
            name = "AutoCategory timing reports an integration failure caught during a slow action",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.AutoCategoryTestClock.Reset()
                local ok, failure = pcall(integration.TimeAction, "editor", "failing click", integration.TimingSnapshot,
                    integration.Run, function()
                        this.AutoCategoryTestClock.Advance(150)
                        error("simulated editor defect")
                    end)
                assert(ok, "Run absorbs the failure and the timing report goes to chat: " .. tostring(failure))
                local report = tostring(integration.Timing.lastSlowReport)
                assert(report:find("Integration failed during this action: ", 1, true)
                    and report:find("simulated editor defect", 1, true), report)
                assert(integration.IsFaulted())
            end,
        },
        {
            name = "AutoCategory timing raises integration failures with a traceback next frame only in Debug Mode",
            run = function()
                local function FailingDefect() error("simulated integration defect") end
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.AutoCategoryTestClock.Reset()
                this.AutoCategoryTestClock.RunFrame()
                assert(integration.Run(FailingDefect) == false, "The failing caller must still get false")
                assert(integration.IsFaulted(), "Debug Mode must still disable the integration")
                local ok, report = pcall(this.AutoCategoryTestClock.RunFrame)
                report = tostring(report)
                assert(not ok and report:find("disabled by this failure", 1, true)
                    and report:find("simulated integration defect", 1, true)
                    and report:find("stack traceback", 1, true), report)
                assert(this.AutoCategoryTestClock.RunFrame() == 0, "The failure report must unregister before raising")
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                assert(integration.Run(FailingDefect) == false and integration.IsFaulted())
                assert(this.AutoCategoryTestClock.RunFrame() == 0, "Debug Mode off must only warn in chat")
            end,
        },
        {
            name = "AutoCategory profile boundary validation runs at load, not on every matcher rule read",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.accountWide.autoCategorySetupComplete = "not a boolean"
                this.GetRuntimeRules()
                assert(not integration.IsFaulted(), "Hot-path rule reads must not repeat boundary validation")
                this.ValidateSavedRuleProfiles()
                assert(integration.IsFaulted() and this.autoCategoryFailure:find("autoCategorySetupComplete", 1, true),
                    "Load-boundary validation must still catch malformed saved data")
            end,
        },
        {
            name = "First enable prompts with IC first and cancellation leaves all saved choices unchanged",
            run = function()
                PrepareInitialSetup()
                local profile = this.accountWide
                local rules, order = profile.trackedRules, profile.autoCategoryOrder
                assert(this.SetAutoCategoryIntegrationEnabled(true) == false)
                assert(not integration.IsFaulted(), this.autoCategoryFailure)
                assert(shownSetup, "Enabling must open the setup dialog instead of publishing enablement")
                local radios = shownSetup.definition.radioButtons
                assert(radios[1].text == "Near the top (default)" and radios[1].data == "ic")
                assert(radios[2].text == "At the bottom" and radios[2].data == "ac")
                assert(shownSetup.radioButtonGroup:GetClickedButton().data == "ic",
                    "Near the top must be the preselected default")
                CancelSetup()
                shownSetup.definition.noChoiceCallback(shownSetup)
                shownSetup.ClearRadio()
                local ok, failure = pcall(shownSetup.definition.buttons[1].callback, shownSetup)
                assert(not ok and tostring(failure):find("no selected arrangement", 1, true),
                    "Confirm without a selected radio choice must fail explicitly")
                assert(profile.autoCategoryIntegrationEnabled == nil and profile.autoCategorySetupComplete == nil)
                assert(profile.trackedRules == rules and next(rules) == nil and profile.autoCategoryOrder == order)
                assert(#AutoCategory.saved.bags[1].rules == 3)
            end,
        },
        {
            name = "Prefer IC seeds all Show and Notify destinations once and places groups after New in seven contexts",
            run = function()
                PrepareInitialSetup()
                local off = { showBackpack = false, showBank = false, notifyChat = false, notifyHud = false }
                this.accountWide.trackedRules = {
                    alpha = { display = { showBackpack = false, showBank = true } },
                    beta = { display = { showBackpack = false, showBank = false, notifyChat = true } },
                    gamma = { display = { showBackpack = false, showBank = false, notifyHud = true, isHidden = true } },
                    dormant = { displayName = "Dormant", display = off },
                    backpack = { displayName = "Backpack", display = { showBackpack = true } },
                    miscellaneous = {},
                }
                -- Individually tracked items must never be exported as definitions or order entries.
                this.accountWide.trackedItems = { [10] = { link = "item", icon = "icon" } }
                this.InvalidateRuleCache()
                assert(this.SetAutoCategoryIntegrationEnabled(true) == false)
                ConfirmSetup()
                assert(not integration.IsFaulted(), this.autoCategoryFailure)
                local profile = this.accountWide
                assert(profile.autoCategoryIntegrationEnabled and profile.autoCategorySetupComplete)
                local rules = this.GetRuntimeRules()
                assert(rules.alpha.autoCategoryEnabled and rules.beta.autoCategoryEnabled
                    and rules.gamma.autoCategoryEnabled and rules.backpack.autoCategoryEnabled)
                assert(not rules.dormant.autoCategoryEnabled and not rules.miscellaneous.autoCategoryEnabled)
                for _, context in ipairs(contexts) do
                    for _, mode in ipairs({ "display", "matching" }) do
                        assert(Names(profile.autoCategoryOrder.contexts[context.key][mode])
                            == "New,alpha,backpack,beta,gamma,Selling,Low level")
                    end
                end
                this.SetAutoCategoryParticipation("alpha", false)
                local order = profile.autoCategoryOrder
                this.SetAutoCategoryIntegrationEnabled(false)
                shownSetup = nil
                this.SetAutoCategoryIntegrationEnabled(true)
                assert(shownSetup == nil and profile.autoCategoryOrder == order
                    and not this.GetRuntimeRules().alpha.autoCategoryEnabled,
                    "Re-enable must preserve orders and manual participation, not reseed from Show")
                this.character.useCharacterItemList = true
                this.SetAutoCategoryIntegrationEnabled(true)
                assert(shownSetup and shownSetup.data.profile == this.character,
                    "First-time setup must follow the selected profile")
            end,
        },
        {
            name = "Prefer AutoCategory puts IC groups last in both orders without copying between native orders",
            run = function()
                PrepareInitialSetup()
                AutoCategory.saved.bags[1].rules[1].showpriority = 0
                this.SetAutoCategoryIntegrationEnabled(true)
                ConfirmSetup(2)
                assert(not integration.IsFaulted(), this.autoCategoryFailure)
                local order = this.accountWide.autoCategoryOrder.contexts.backpack
                assert(Names(order.matching) == "New,Selling,Low level,alpha,beta,gamma")
                assert(Names(order.display) == "Selling,Low level,New,alpha,beta,gamma")
                for _, context in ipairs(contexts) do
                    assert(Names(this.accountWide.autoCategoryOrder.contexts[context.key].matching)
                        == "New,Selling,Low level,alpha,beta,gamma")
                end
            end,
        },
        {
            name = "Fresh AutoCategory projection preserves the saved order without a runtime snapshot",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                local savedOrder = { "ic:alpha", "ac:New", "ac:Selling", "ac:Low level" }
                for _, context in ipairs(contexts) do
                    for _, orderMode in ipairs({ "display", "matching" }) do
                        this.accountWide.autoCategoryOrder.contexts[context.key][orderMode] =
                            { unpack(savedOrder) }
                    end
                end
                assert(integration.ProjectAutoCategory(), this.autoCategoryFailure)
                for _, context in ipairs(contexts) do
                    for _, orderMode in ipairs({ "display", "matching" }) do
                        assert(Names(this.accountWide.autoCategoryOrder.contexts[context.key][orderMode])
                            == "alpha,New,Selling,Low level")
                    end
                end
                assert(FindAssignment("backpack", "Alpha" .. icCategoryNameMarkupSuffix).showpriority == 1000)
            end,
        },
        {
            name = "Prefer IC uses the top when New is hidden or missing",
            run = function()
                PrepareInitialSetup()
                AutoCategory.saved.bags[1].rules[1].isHidden = true
                table.remove(AutoCategory.saved.bags[2].rules, 1)
                assert(integration.CompleteInitialSetup("ic", this.accountWide))
                for _, mode in ipairs({ "display", "matching" }) do
                    assert(Names(this.accountWide.autoCategoryOrder.contexts.backpack[mode])
                        == "alpha,beta,gamma,New,Selling,Low level")
                    assert(Names(this.accountWide.autoCategoryOrder.contexts.bank[mode])
                        == "alpha,beta,gamma,Selling,Low level")
                end
                assert(AutoCategory.saved.bags[1].rules[1].isHidden)
            end,
        },
        {
            name = "Setup with no participating groups is remembered across re-enable",
            run = function()
                PrepareInitialSetup()
                for _, key in ipairs({ "alpha", "beta", "gamma" }) do
                    this.accountWide.trackedRules[key] = { display = {
                        showBackpack = false, showBank = false, notifyChat = false, notifyHud = false,
                    } }
                end
                this.InvalidateRuleCache()
                assert(integration.CompleteInitialSetup("ic", this.accountWide))
                assert(this.accountWide.autoCategorySetupComplete)
                assert(Names(this.accountWide.autoCategoryOrder.contexts.backpack.display) == "New,Selling,Low level")
                this.SetAutoCategoryIntegrationEnabled(false)
                shownSetup = nil
                this.SetAutoCategoryIntegrationEnabled(true)
                assert(shownSetup == nil)
            end,
        },
        {
            name = "Setup preflight failure leaves participation enablement and order untouched",
            run = function()
                PrepareInitialSetup()
                local profile = this.accountWide
                local rules, order = profile.trackedRules, profile.autoCategoryOrder
                local assignments = AutoCategory.saved.bags[7].rules
                for index = 4, 1000 do assignments[index] = Assignment("Native " .. index, index, index) end
                d = function() end
                assert(integration.CompleteInitialSetup("ic", profile) == false)
                assert(integration.IsFaulted())
                assert(this.autoCategoryFailure:find("at most 999", 1, true),
                    "Expected the capacity preflight error, got: " .. tostring(this.autoCategoryFailure))
                assert(profile.autoCategoryIntegrationEnabled == nil and profile.autoCategorySetupComplete == nil)
                assert(profile.trackedRules == rules and next(rules) == nil and profile.autoCategoryOrder == order)
                assert(#AutoCategory.saved.bags[1].rules == 3)
            end,
        },
        {
            name = "Changing profile while setup is open cancels without applying to either profile",
            run = function()
                PrepareInitialSetup()
                this.SetAutoCategoryIntegrationEnabled(true)
                this.character.useCharacterItemList = true
                local warning
                d = function(message) warning = message end
                ConfirmSetup()
                assert(warning:find("profile changed", 1, true))
                assert(not this.accountWide.autoCategorySetupComplete and not this.character.autoCategorySetupComplete)
                assert(not this.accountWide.autoCategoryIntegrationEnabled and not this.character.autoCategoryIntegrationEnabled)
                assert(not integration.IsFaulted())
            end,
        },
        {
            name = "Legacy Show and Notify flags seed participation during setup",
            run = function()
                PrepareInitialSetup()
                this.accountWide.trackedRules = {
                    alpha = { display = { show = false, notify = true } },
                    beta = { display = { show = true, bank = true, showBackpack = false } },
                    gamma = { display = { show = false, notify = false } },
                }
                this.InvalidateRuleCache()
                assert(integration.CompleteInitialSetup("ic", this.accountWide), this.autoCategoryFailure)
                local rules = this.GetRuntimeRules()
                assert(rules.alpha.autoCategoryEnabled, "Legacy notify must resolve to chat and HUD participation")
                assert(rules.beta.autoCategoryEnabled, "Legacy bank flag must resolve to Show Bank participation")
                assert(not rules.gamma.autoCategoryEnabled, "Groups with no effective destination must not participate")
            end,
        },
        {
            name = "Missing or empty AutoCategory New string fails setup without publishing anything",
            run = function()
                PrepareInitialSetup()
                local profile = this.accountWide
                local savedId = SI_AC_DEFAULT_CATEGORY_NEW
                SI_AC_DEFAULT_CATEGORY_NEW = nil
                local completed = integration.CompleteInitialSetup("ic", profile)
                SI_AC_DEFAULT_CATEGORY_NEW = savedId
                assert(completed == false and integration.IsFaulted())
                assert(this.autoCategoryFailure:find("default New category string is unavailable", 1, true),
                    this.autoCategoryFailure)
                assert(profile.autoCategoryIntegrationEnabled == nil and profile.autoCategorySetupComplete == nil)
                assert(next(profile.trackedRules) == nil, "A failed preflight must not publish participation")
                PrepareInitialSetup()
                profile = this.accountWide
                localizedStrings[SI_AC_DEFAULT_CATEGORY_NEW] = ""
                completed = integration.CompleteInitialSetup("ic", profile)
                localizedStrings[SI_AC_DEFAULT_CATEGORY_NEW] = "New"
                assert(completed == false and integration.IsFaulted())
                assert(this.autoCategoryFailure:find("default New category name is unavailable", 1, true),
                    this.autoCategoryFailure)
                assert(profile.autoCategorySetupComplete == nil and next(profile.trackedRules) == nil)
            end,
        },
        {
            name = "Setup contract violations and projection failures fail explicitly without completing setup",
            run = function()
                PrepareInitialSetup()
                assert(integration.CompleteInitialSetup("sideways", this.accountWide) == false)
                assert(integration.IsFaulted()
                    and this.autoCategoryFailure:find("Unknown AutoCategory starting preset", 1, true))
                PrepareInitialSetup()
                assert(integration.CompleteInitialSetup("ic", this.character) == false)
                assert(integration.IsFaulted()
                    and this.autoCategoryFailure:find("setup profile changed", 1, true))
                assert(this.accountWide.autoCategorySetupComplete == nil
                    and this.character.autoCategorySetupComplete == nil)
                PrepareInitialSetup()
                local profile = this.accountWide
                AutoCategory.cacheRuleInitialize = function() error("synthetic projection failure") end
                assert(integration.CompleteInitialSetup("ic", profile) == false)
                assert(integration.IsFaulted()
                    and this.autoCategoryFailure:find("synthetic projection failure", 1, true),
                    this.autoCategoryFailure)
                assert(profile.autoCategorySetupComplete == nil, "A projection failure must not mark setup complete")
                assert(not this.GetAutoCategoryState().enabled, "A faulted integration must not remain enabled")
            end,
        },
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
            name = "Synchronized moves skip registry rebuilds and refresh only the changed bag",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true } })
                assert(integration.ProjectAutoCategory())
                local ac = AutoCategory
                local registryRebuilds, compiles, cacheInits, refreshes, uiRefreshes = 0, 0, {}, {}, 0
                local originalCacheRuleInitialize = ac.cacheRuleInitialize
                ac.cacheRuleInitialize = function(...)
                    registryRebuilds = registryRebuilds + 1
                    return originalCacheRuleInitialize(...)
                end
                ac.RulesW.CompileAll = function() compiles = compiles + 1 end
                ac.cacheInitBag = function(bagType) cacheInits[#cacheInits + 1] = bagType end
                ac.RefreshList = function(inventoryType) refreshes[#refreshes + 1] = inventoryType end
                this.RefreshAutoCategoryUI = function() uiRefreshes = uiRefreshes + 1 end
                assert(integration.MoveEntries({ ["ic:alpha"] = true }, "backpack", "display", "top"))
                assert(table.concat(cacheInits, ",") == "1" and table.concat(refreshes, ",") == "11",
                    "A backpack display move must rebuild and refresh only the backpack")
                assert(integration.MoveEntry("ic:alpha", "backpack", "matching", -1))
                assert(integration.CopyBothOrders("backpack", "bank"))
                assert(table.concat(cacheInits, ",") == "1,1,2" and table.concat(refreshes, ",") == "11,11,12",
                    "Each move must refresh exactly its own changed bag: "
                        .. table.concat(cacheInits, ",") .. " / " .. table.concat(refreshes, ","))
                assert(registryRebuilds == 0 and compiles == 0,
                    "Moves with synchronized definitions must not rebuild or recompile the rule registry")
                local priorities = {}
                for index, assignment in ipairs(ac.saved.bags[1].rules) do
                    priorities[index] = assignment.showpriority .. ":" .. assignment.runpriority
                end
                assert(integration.MoveEntries({ ["ic:alpha"] = true }, "backpack", "display", "top") == false)
                for index, assignment in ipairs(ac.saved.bags[1].rules) do
                    assert(priorities[index] == assignment.showpriority .. ":" .. assignment.runpriority,
                        "A boundary move must not rewrite native priorities")
                end
                assert(#cacheInits == 3 and #refreshes == 3, "A no-op move must not refresh any bag")
                -- Externally deleted owned definitions must resynchronize on the next projection.
                ac.RuleList.removeRuleByName(ac.RulesW, "Alpha" .. icCategoryNameMarkupSuffix)
                assert(integration.MoveEntries({ ["ic:beta"] = true }, "backpack", "display", "top"))
                assert(registryRebuilds > 0 and compiles > 0,
                    "An externally removed owned definition must trigger resynchronization")
                assert(not integration.IsFaulted(), this.autoCategoryFailure)
                assert(uiRefreshes == 0,
                    "Moves with unchanged status must not rebuild hidden editors or refresh the settings panel")
                this.accountWide.autoCategoryIntegrationEnabled = nil
                integration.OnProfileChanged()
                assert(uiRefreshes == 1, "A real status transition must refresh the UI immediately")
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
            name = "Participation changes preserve existing assignments when profiles do not align",
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
                local managed = FindAssignment("backpack", "Alpha" .. icCategoryNameMarkupSuffix)
                assert(managed and managed.icRuleKey == "alpha")
                this.SetAutoCategoryParticipation("alpha", false)
                local savedAlpha = this.accountWide.trackedRules.alpha or {}
                assert(savedAlpha.autoCategoryAnchor == nil and savedAlpha.autoCategoryRank == nil)
                assert(FindAssignment("backpack", managed.name) == managed
                    and managed.runpriority ~= nil and managed.showpriority ~= nil,
                    "Changing participation must not delete an existing AC assignment")
                assert(select(1, integration.GetStatus()) == "unsupported" and not integration.IsFaulted(),
                    "Integration should pause without error when saved profiles no longer align")
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
            name = "Mismatched profile assignments pause integration without changing saved data",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                local profile = this.accountWide
                this.character.trackedRules.custom_missing = {
                    displayName = "Saved only in character list",
                    addedPatterns = { "synthetic missing group" },
                }
                this.ValidateSavedRuleProfiles()
                local savedOrder = profile.autoCategoryOrder
                local savedRules = profile.trackedRules
                local previousDevelopment = this.IsDevelopment
                local previousState = this.state
                this.IsDevelopment = true
                this.state = { isLoaded = false }
                local passiveSnapshot = this.GetRuntimeRuleDiagnostics("custom_missing")
                assert(passiveSnapshot.cacheInvalid and passiveSnapshot.firstAccess == nil,
                    "Passive diagnostics must not build the lazy runtime-rule cache")
                local orphan = Assignment("Orphan", 42, 43, { icOwned = true, icRuleKey = "custom_missing" })
                local backpack = AutoCategory.saved.bags[1].rules
                backpack[#backpack + 1] = orphan
                this.accountWide.debugEnabled = false

                local prepared = integration.PreflightAutoCategory()
                assert(prepared == nil and not integration.IsFaulted())
                assert(select(1, integration.GetStatus()) == "unsupported",
                    "A missing active-profile group should pause integration without reporting an error")
                assert(integration.ProjectAutoCategory() == false and not integration.IsFaulted(),
                    "Projection should remain paused without escalating the mismatch to an error")
                assert(backpack[#backpack] == orphan and orphan.runpriority == 42 and orphan.showpriority == 43,
                    "A profile mismatch must preserve AutoCategory assignments and priorities")
                assert(profile.trackedRules == savedRules and profile.autoCategoryOrder == savedOrder
                    and profile.autoCategoryIntegrationEnabled,
                    "A profile mismatch must preserve IC saved rules, order, and enablement")
                assert(#profile.debug.autoCategoryRemovedLines == 0,
                    "Do not archive or remove a mismatch that can be ignored without changing saved data")
                local runtime = this.GetRuntimeRuleDiagnostics("custom_missing")
                assert(runtime.firstAccess ~= nil and runtime.firstAccess.cachePath == "built",
                    "The natural rule-cache access should still be observable after preflight")
                assert(#integration.unavailableAssignments == 1
                    and integration.unavailableAssignments[1].ruleKey == "custom_missing",
                    "The ignored mismatch should remain available to diagnostics")
                this.IsDevelopment = previousDevelopment
                this.state = previousState
            end,
        },
        {
            name = "Account-wide assignments are retained when a character disables group participation",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                local previousState = this.state
                this.state = { isLoaded = true }
                this.accountWide.trackedRules.custom_missing = {
                    displayName = "Character-specific group",
                    addedPatterns = { "synthetic character-specific group" },
                    autoCategoryEnabled = false,
                }
                this.character.trackedRules.custom_missing = {
                    displayName = "Character-specific group",
                    addedPatterns = { "synthetic character-specific group" },
                    autoCategoryEnabled = true,
                }
                this.ValidateSavedRuleProfiles()
                local assignment = Assignment("Character-specific group", 42, 43,
                    { icOwned = true, icRuleKey = "custom_missing" })
                local backpack = AutoCategory.saved.bags[1].rules
                backpack[#backpack + 1] = assignment

                local prepared = integration.PreflightAutoCategory()
                assert(prepared == nil and not integration.IsFaulted()
                    and select(1, integration.GetStatus()) == "unsupported",
                    "A participation mismatch must pause integration without faulting")
                assert(backpack[#backpack] == assignment and assignment.runpriority == 42
                    and assignment.showpriority == 43,
                    "The account-wide assignment and its priorities must remain untouched")
                assert(#integration.unavailableAssignments == 1
                    and integration.unavailableAssignments[1].ruleKey == "custom_missing",
                    "The non-participating active-profile group must be reported as a mismatch")
                this.state = previousState
            end,
        },
        {
            name = "Archived AutoCategory assignments are restored and mismatches are ignored",
            run = function()
                PrepareActive({})
                local previousState = this.state
                this.state = { isLoaded = true }
                local originalIndices = {}
                for _, context in ipairs(contexts) do
                    local bag = AutoCategory.saved.bags[context.bag]
                    local orphan = Assignment("Orphan", 42, 43,
                        { icOwned = true, icRuleKey = "custom_missing" })
                    originalIndices[context.key] = #bag.rules + 1
                    this.accountWide.debug.autoCategoryRemovedLines[#this.accountWide.debug.autoCategoryRemovedLines + 1] = {
                        timestamp = 1793641920,
                        dateTime = "2026-11-02 17:52:00",
                        context = context.key,
                        bagType = context.bag,
                        index = originalIndices[context.key],
                        line = orphan,
                    }
                end

                local prepared, failure = integration.PreflightAutoCategory()
                assert(prepared == nil and tostring(failure):find("paused", 1, true),
                    "Recovery should restore the archive and pause on the active-profile mismatch")
                assert(not integration.IsFaulted(), "An ignored mismatch must not fault integration")
                local archived = this.accountWide.debug.autoCategoryRemovedLines
                assert(#archived == #contexts, "Keep every historical archive row")
                for index, context in ipairs(contexts) do
                    local record = archived[index]
                    assert(record.dateTime == "2026-11-02 17:52:00"
                        and record.context == context.key and record.bagType == context.bag
                        and record.index == originalIndices[context.key]
                        and record.line.name == "Orphan" and record.line.icRuleKey == "custom_missing"
                        and record.line.runpriority == 42 and record.line.showpriority == 43
                        and record.restored == true,
                        "Recovery must preserve the archive row and mark it restored")
                    local restored = AutoCategory.saved.bags[context.bag].rules[originalIndices[context.key]]
                    assert(restored.name == "Orphan" and restored.icRuleKey == "custom_missing"
                        and restored.runpriority == 42 and restored.showpriority == 43,
                        "Recovery must put the original assignment back at its saved position")
                end
                local summary = integration.GetOrphanedAssignmentReport(false)
                assert(#summary == 2 and summary[1]:find("7", 1, true)
                    and summary[1]:find("restored: 7", 1, true)
                    and summary[2]:find("Current active-profile mismatches ignored: 7", 1, true),
                    "Normal debug report should summarize archived, restored, and ignored rows")
                local detailed = integration.GetOrphanedAssignmentReport(true)
                assert(#detailed == #contexts * 2 + 2
                    and detailed[3]:find("context=backpack", 1, true)
                    and detailed[3]:find("restored=true", 1, true)
                    and detailed[3]:find("custom_missing", 1, true)
                    and detailed[#detailed]:find("ignored #7", 1, true),
                    "Very verbose report should list archived and currently ignored assignment rows")
                assert(integration.ProjectAutoCategory() == false and not integration.IsFaulted(),
                    "A restored mismatch must remain safely ignored rather than projected")
                for _, context in ipairs(contexts) do
                    local rules = AutoCategory.saved.bags[context.bag].rules
                    local matches = 0
                    for _, assignment in ipairs(rules) do
                        if assignment.icRuleKey == "custom_missing" then matches = matches + 1 end
                    end
                    assert(matches == 1, "Repeated preflight must not duplicate a restored assignment")
                end
                this.state = previousState
            end,
        },
        {
            name = "Failed AutoCategory projection rolls assignment lists and priorities back",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                assert(integration.ProjectAutoCategory())
                local backpack = AutoCategory.saved.bags[1].rules
                local original = {}
                for index, assignment in ipairs(backpack) do
                    original[index] = {
                        assignment = assignment, name = assignment.name, icOwned = assignment.icOwned,
                        icRuleKey = assignment.icRuleKey, runpriority = assignment.runpriority,
                        showpriority = assignment.showpriority,
                    }
                end
                local savedOrder = table.concat(this.accountWide.autoCategoryOrder.contexts.backpack.display, ",")
                AutoCategory.cacheInitBag = function() error("synthetic refresh failure") end

                assert(integration.MoveEntry("ic:alpha", "backpack", "display", "top") == false)
                assert(integration.IsFaulted())
                assert(#backpack == #original, "A failed projection must not add or delete saved assignments")
                for index, entry in ipairs(original) do
                    local assignment = backpack[index]
                    assert(assignment == entry.assignment and assignment.name == entry.name
                        and assignment.icOwned == entry.icOwned and assignment.icRuleKey == entry.icRuleKey
                        and assignment.runpriority == entry.runpriority and assignment.showpriority == entry.showpriority,
                        "A failed projection must restore assignment values and ordering")
                end
                assert(table.concat(this.accountWide.autoCategoryOrder.contexts.backpack.display, ",") == savedOrder,
                    "A failed projection must not save its proposed order")
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
                local rebuilds = 0
                local originalCacheRuleInitialize = AutoCategory.cacheRuleInitialize
                AutoCategory.cacheRuleInitialize = function(...)
                    rebuilds = rebuilds + 1
                    return originalCacheRuleInitialize(...)
                end
                scheduled[3]()
                assert(rebuilds == 0 and not integration.IsFaulted(),
                    "Reconciling unchanged definitions must not rebuild the rule registry")
                -- Renaming a group changes its exported definition; participation alone does not.
                this.accountWide.trackedRules.alpha = { displayName = "Alpha Prime" }
                this.InvalidateRuleCache()
                hooks.cacheInitBag()
                assert(#scheduled == 4)
                AutoCategory.cacheRuleInitialize = function() error("synthetic cache failure") end
                assert(pcall(scheduled[4]), "Deferred integration errors must not escape")
                assert(integration.IsFaulted() and not this.GetAutoCategoryState().enabled)
                assert(warnings[1]:find("synthetic cache failure", 1, true))
                local warningCount = #warnings
                hooks.cacheInitBag()
                assert(#scheduled == 4 and #warnings == warningCount,
                    "A failed session must stop scheduling and avoid repeated warnings")
            end,
        },
    }
end
