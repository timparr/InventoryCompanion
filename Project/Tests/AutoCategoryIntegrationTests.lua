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
    AutoCategory = nil
    integration.Initialize()
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
    integration.Initialize()
    AutoCategory.saved.bags = bags
    AutoCategory.Inited = true
    AutoCategory.Plugins["Inventory Companion"] = { predef = {} }
    this.accountWide.trackedRules = rules or {}
    this.accountWide.autoCategoryIntegrationEnabled = true
    this.ValidateSavedRuleProfiles()
    for _, context in ipairs(contexts) do
        local order = this.accountWide.autoCategoryOrder.contexts[context.key]
        for key in pairs(this.preLoadedRulesets) do
            if key ~= "miscellaneous" then
                order.hidden["ic:" .. key] = not (rules and rules[key] and rules[key].autoCategoryEnabled) and true or nil
            end
        end
    end
    this.InvalidateRuleCache()
    d = function() end
end
this.NewActiveAutoCategoryTestFixture = PrepareActive

local function Names(sequence)
    local names = {}
    for _, reference in ipairs(sequence) do
        if reference ~= "ic:__ic_other" then names[#names + 1] = reference:sub(4) end
    end
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
    if name == "InventoryCompanion_AUTOCATEGORY_REPAIR" or name == "InventoryCompanion_AUTOCATEGORY_RESET" then
        assert(#definition.buttons == 2 and type(definition.mainText.text) == "function")
        shownSetup = { definition = definition, data = data }
        return
    end
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

local function CopyFixtureValue(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, entry in pairs(value) do copy[key] = CopyFixtureValue(entry) end
    return copy
end

local function NativeProfile(names)
    local profile = { bags = {}, unrelated = { keep = true } }
    for _, context in ipairs(contexts) do
        local assignments = {}
        for index, name in ipairs(names) do
            assignments[index] = Assignment(name, 1000 - index, 1000 - index, { external = "preserved" })
        end
        profile.bags[context.bag] = { rules = assignments }
    end
    return profile
end

local function SourceProfile(keys, mapsFirst)
    local profile = {
        trackedRules = {}, trackedItems = {}, itemListInitialized = true,
        autoCategoryIntegrationEnabled = true, autoCategorySetupComplete = true, autoCategoryOrder = NewOrder(),
    }
    for _, key in ipairs(keys) do
        profile.trackedRules[key] = { displayName = key, addedPatterns = { key }, autoCategoryEnabled = true }
    end
    for _, context in ipairs(contexts) do
        local sequence = { "ac:New" }
        if mapsFirst then table.insert(sequence, 1, "ac:Maps") end
        for _, key in ipairs(keys) do sequence[#sequence + 1] = "ic:" .. key end
        if not mapsFirst then sequence[#sequence + 1] = "ac:Maps" end
        profile.autoCategoryOrder.contexts[context.key] = { display = sequence, matching = CopyFixtureValue(sequence) }
    end
    return profile
end

local function AssertManagedKeys(expected)
    expected = CopyFixtureValue(expected)
    expected.__ic_other = true
    for key in pairs(this.preLoadedRulesets) do
        if key ~= "miscellaneous" then expected[key] = true end
    end
    for _, context in ipairs(contexts) do
        local seen = {}
        for _, row in ipairs(AutoCategory.saved.bags[context.bag].rules) do
            if row.icOwned then
                assert(expected[row.icRuleKey] and not seen[row.icRuleKey], "Unexpected or duplicate managed identity")
                seen[row.icRuleKey] = true
            else
                assert(row.external == "preserved")
            end
        end
        for key in pairs(expected) do assert(seen[key], "Missing managed identity: " .. key) end
    end
end

function this.GetAutoCategoryIntegrationTests()
    return {
        {
            name = "Group undo removes newly generated definitions without changing native assignments",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                assert(integration.ProjectAutoCategory())
                this.UpdateEventRegistry, this.RefreshItemTrackerPanel = function() end, function() end
                local baseline = this.CaptureEditorState("groups")
                for _, context in ipairs(contexts) do
                    for _, row in ipairs(AutoCategory.saved.bags[context.bag].rules) do
                        if not row.icOwned then row.undoNativeMarker = "keep" end
                    end
                end
                this.CreateCustomRule("new_undo_group", "New undo group")
                assert(integration.ProjectAutoCategory())
                assert(this.GetRuntimeRules().new_undo_group)
                assert(this.RestoreEditorState("groups", baseline), this.autoCategoryFailure)
                assert(this.GetRuntimeRules().new_undo_group == nil)
                for _, context in ipairs(contexts) do
                    for _, row in ipairs(AutoCategory.saved.bags[context.bag].rules) do
                        assert(row.icRuleKey ~= "new_undo_group")
                        if not row.icOwned then assert(row.undoNativeMarker == "keep") end
                    end
                end
            end,
        },
        {
            name = "AutoCategory undo restores current page and shared inclusion without rewinding other pages",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true } })
                assert(integration.ProjectAutoCategory())
                this.UpdateEventRegistry, this.RefreshItemTrackerPanel = function() end, function() end
                local baseline = this.CaptureEditorState("autocategory", "backpack", "display")
                integration.MoveEntries({ ["ic:alpha"] = true }, "backpack", "display", "bottom")
                integration.MoveEntries({ ["ic:beta"] = true }, "bank", "matching", "top")
                local bank = this.CopySavedValue(this.accountWide.autoCategoryOrder.contexts.bank)
                integration.MoveEntries({ ["ic:beta"] = true }, "backpack", "matching", "top")
                local priority = this.CopySavedValue(this.accountWide.autoCategoryOrder.contexts.backpack.matching)
                assert(this.RestoreEditorState("autocategory", baseline, "backpack", "display"))
                assert(this.SavedValuesEqual(this.accountWide.autoCategoryOrder.contexts.bank, bank))
                assert(this.SavedValuesEqual(this.accountWide.autoCategoryOrder.contexts.backpack.matching, priority))
                assert(this.SavedValuesEqual(this.CaptureEditorState("autocategory", "backpack", "display"), baseline))
                integration.SetEntryIncluded("ic:alpha", "backpack", false)
                assert(this.RestoreEditorState("autocategory", baseline, "backpack", "display"))
                assert(integration.IsEntryIncluded("ic:alpha", "backpack"))
            end,
        },
        {
            name = "Undo rejects externally deleted categories without partially restoring saved or native state",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                assert(integration.ProjectAutoCategory())
                local baseline = this.CaptureEditorState("autocategory", "backpack", "display")
                local bag = AutoCategory.saved.bags[contexts[1].bag].rules
                for index = #bag, 1, -1 do
                    if bag[index].name == "Selling" then table.remove(bag, index) end
                end
                local saved = this.CopySavedValue(this.accountWide)
                local native = this.CopySavedValue(AutoCategory.saved)
                local reported = false
                this.Utils = { UserError = function() reported = true end }
                assert(not this.RestoreEditorState("autocategory", baseline, "backpack", "display"))
                assert(reported and this.SavedValuesEqual(this.accountWide, saved)
                    and this.SavedValuesEqual(AutoCategory.saved, native))
            end,
        },
        {
            name = "Reset preserves per-area IC inclusion while replacing native exclusions and saved positions",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                assert(integration.ProjectAutoCategory())
                assert(integration.SetEntryIncluded("ic:alpha", "bank", false))
                assert(integration.SetEntryIncluded("ic:beta", "craft_bag", true))
                assert(integration.SetEntryIncluded("ac:Selling", "bank", false))
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ShowIntegrationReset())
                ConfirmSetup()
                ConfirmSetup()
                assert(not integration.NeedsRecovery())
                assert(not integration.IsEntryIncluded("ic:alpha", "bank")
                    and integration.IsEntryIncluded("ic:alpha", "craft_bag")
                    and integration.IsEntryIncluded("ic:beta", "craft_bag")
                    and not integration.IsEntryIncluded("ic:beta", "bank"))
                local bank = this.accountWide.autoCategoryOrder.contexts.bank
                assert(not bank.hidden["ac:Selling"] and next(bank.displayPositions) == nil)
            end,
        },
        {
            name = "Context inclusion retains assignments and classifies Rare Mats in Craft Bag but not Bank after reload",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                assert(integration.ProjectAutoCategory())
                local rule = this.accountWide.trackedRules.alpha
                local bankAssignment = FindAssignment("bank", "Alpha" .. icCategoryNameMarkupSuffix)
                bankAssignment.custom = { keep = true }
                assert(integration.SetEntryIncluded("ic:alpha", "bank", false))
                assert(not integration.IsEntryIncluded("ic:alpha", "bank")
                    and integration.IsEntryIncluded("ic:alpha", "craft_bag"))
                assert(this.accountWide.trackedRules.alpha == rule and rule.autoCategoryEnabled == true)
                assert(FindAssignment("bank", bankAssignment.name) == bankAssignment and bankAssignment.custom.keep)
                local function Classify(context)
                    local candidates = {}
                    for _, assignment in ipairs(AutoCategory.saved.bags[context].rules) do
                        candidates[#candidates + 1] = assignment
                    end
                    table.sort(candidates, function(a, b) return a.runpriority > b.runpriority end)
                    for _, assignment in ipairs(candidates) do
                        if assignment.icRuleKey == "__ic_other" then
                            return assignment.icRuleKey
                        end
                        if assignment.icRuleKey == "alpha" then
                            local previous = GetItemLinkName
                            GetItemLinkName = function(link) return link end
                            local matches = this.ItemMatchesRuntimeRule("alpha", this.GetRuntimeRules().alpha)
                            GetItemLinkName = previous
                            if matches then return assignment.icRuleKey end
                        end
                    end
                end
                assert(Classify(2) == "__ic_other" and Classify(6) == "alpha")
                this.InvalidateRuleCache()
                this.ValidateSavedRuleProfiles()
                assert(integration.ProjectAutoCategory())
                assert(Classify(2) == "__ic_other" and Classify(6) == "alpha")
                for _, context in ipairs(contexts) do
                    assert(integration.SetEntryIncluded("ic:alpha", context.key, false))
                    assert(FindAssignment(context.key, bankAssignment.name))
                end
                assert(this.accountWide.trackedRules.alpha == rule)
                assert(integration.SetEntryIncluded("ic:alpha", "craft_bag", true))
                assert(Classify(6) == "alpha" and Classify(2) == "__ic_other")
            end,
        },
        {
            name = "Other moves independently survives reload and copy and brackets new groups in every context",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true } })
                assert(integration.ProjectAutoCategory())
                local reference = "ic:__ic_other"
                for _, context in ipairs(contexts) do
                    local included = integration.GetIncludedSequence(context.key, "display")
                    assert(included[#included] == reference)
                    assert(integration.MoveEntries({ [reference] = true }, context.key, "display", "top"))
                end
                local other = FindAssignment("bank", "Other" .. icCategoryNameMarkupSuffix)
                local matching = other.runpriority
                assert(FindAssignment("bank", "Alpha" .. icCategoryNameMarkupSuffix).runpriority > matching)
                assert(FindAssignment("bank", "Gamma" .. icCategoryNameMarkupSuffix).runpriority < matching)
                this.ValidateSavedRuleProfiles()
                assert(integration.ProjectAutoCategory())
                assert(this.accountWide.autoCategoryOrder.contexts.bank.display[1] == reference)
                this.CreateCustomRule("new_group", "New Group")
                assert(integration.ProjectAutoCategory())
                for _, context in ipairs(contexts) do
                    local order = this.accountWide.autoCategoryOrder.contexts[context.key]
                    assert(order.display[1] == "ic:new_group" and order.display[2] == reference)
                    local priority = integration.GetIncludedSequence(context.key, "matching")
                    assert(priority[#priority] == "ic:new_group")
                end
                assert(integration.UseOtherOrder("bank", "matching"))
                for _, value in ipairs(this.accountWide.autoCategoryOrder.contexts.bank.matching) do
                    assert(value ~= reference)
                end
                assert(integration.UseOtherOrder("bank", "display"))
                assert(this.accountWide.autoCategoryOrder.contexts.bank.display[2] == reference)
                assert(integration.MoveEntries({ [reference] = true, ["ic:new_group"] = true },
                    "bank", "display", "bottom"))
                assert(integration.CopyBothOrders("bank", "craft_bag"))
                local source = integration.GetIncludedSequence("bank", "display")
                local destination = integration.GetIncludedSequence("craft_bag", "display")
                assert(table.concat(source, ",") == table.concat(destination, ","))
                local prepared = integration.PreflightAutoCategory({ bank = { matching = { reference } } })
                assert(prepared == nil and integration.NeedsRecovery())
            end,
        },
        {
            name = "Area summaries honor precedence exact rendered width prefix and word fallback for every inclusion mask",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                local reference = "ic:alpha"
                local titles = integration.GetContexts()
                for mask = 0, 127 do
                    local enabled, disabled = {}, {}
                    for index, context in ipairs(titles) do
                        local included = math.floor(mask / 2 ^ (index - 1)) % 2 == 1
                        this.accountWide.autoCategoryOrder.contexts[context.key].hidden[reference] = not included or nil
                        local names = included and enabled or disabled
                        names[#names + 1] = context.title
                    end
                    local expected = #enabled == 7 and "All" or #enabled == 0 and "None"
                        or #enabled == 1 and enabled[1] or #disabled == 1 and "Not: " .. disabled[1]
                    local enabledText, disabledText = table.concat(enabled, ", "), "Not: " .. table.concat(disabled, ", ")
                    if expected then
                        assert(integration.GetAreaSummary(reference, function() error("Single-area precedence must not measure") end)
                            == expected)
                    else
                        local calls = {}
                        local function Fits(width)
                            return function(text)
                                calls[#calls + 1] = text
                                return #text * 7 <= width
                            end
                        end
                        assert(integration.GetAreaSummary(reference, Fits(#enabledText * 7)) == enabledText)
                        assert(calls[1] == enabledText and #calls == 1)
                        local fallback = ({ [2] = "Two Areas", [3] = "Three Areas",
                            [4] = "Four Areas", [5] = "Five Areas" })[#enabled]
                        assert(integration.GetAreaSummary(reference, Fits(0)) == fallback)
                        if #disabledText < #enabledText then
                            assert(integration.GetAreaSummary(reference, Fits(#disabledText * 7)) == disabledText)
                            assert(integration.GetAreaSummary(reference, Fits(#disabledText * 7 - 1)) == fallback)
                        end
                    end
                end
            end,
        },
        {
            name = "AutoCategory numbered injections replace prior scenarios and exercise few repeated many and cutoff rows",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local previousDevelopment = this.IsDevelopment
                this.IsDevelopment = true
                local groups = this.accountWide.trackedRules
                local savedOrder = this.accountWide.autoCategoryOrder
                local expectedCounts = { 3, 7, 30, 5 }
                local inactiveRows = { Assignment("Inactive", 91, 92,
                    { icOwned = true, icRuleKey = "other_character" }) }
                AutoCategory.charSaved.bags = { [1] = { rules = inactiveRows } }
                for _, scenario in ipairs({ 3, 1, 4, 2, 3, 3, 1 }) do
                    integration.InjectTestAssignment(scenario)
                    local counts = integration.VerifyTestAssignment()
                    assert(counts.test == expectedCounts[scenario]
                        and counts.unavailable == expectedCounts[scenario],
                        "A new scenario must replace, not accumulate, previous test rows")
                    local keys = {}
                    local preview = integration.GetProblemRowsMessage()
                    for _, record in ipairs(integration.unavailableAssignments) do
                        keys[record.ruleKey] = true
                        assert(record.ruleKey:find("_scenario" .. scenario .. "_", 1, true))
                        assert(preview:find(record.ruleKey, 1, true),
                            "Every scenario row must appear in the scrollable panel")
                    end
                    local unique = 0
                    for _ in pairs(keys) do unique = unique + 1 end
                    assert(unique == (scenario == 2 and 1 or expectedCounts[scenario]))
                    assert(integration.ShowAssignmentRepair())
                    local summary = shownSetup.data.summary
                    local shown = 0
                    for line in summary:gmatch("[^\n]+") do
                        if line:find(": IC DEV recovery test", 1, true) then shown = shown + 1 end
                    end
                    assert(shown == (expectedCounts[scenario] <= 5 and expectedCounts[scenario] or 3))
                    if scenario == 2 then
                        assert(preview:find("Furniture Vault:", 1, true)
                            and summary:find("4 more", 1, true))
                    elseif scenario == 3 then
                        assert(preview:find("Group 30", 1, true) and summary:find("27 more", 1, true))
                    end
                    assert(this.accountWide.trackedRules == groups and #inactiveRows == 1
                        and inactiveRows[1].icRuleKey == "other_character")
                    for _, context in ipairs(contexts) do
                        for _, mode in ipairs({ "display", "matching" }) do
                            assert(table.concat(this.accountWide.autoCategoryOrder.contexts[context.key][mode], ",")
                                == table.concat(savedOrder.contexts[context.key][mode], ","))
                        end
                    end
                end
                ConfirmSetup()
                assert(not integration.NeedsRecovery() and integration.VerifyTestAssignment().test == 0)
                integration.InjectTestAssignment(2)
                assert(integration.RemoveTestAssignment() == 7)
                assert(not integration.NeedsRecovery() and integration.VerifyTestAssignment().test == 0)
                this.IsDevelopment = previousDevelopment
            end,
        },
        {
            name = "AutoCategory scenario replacement does not delete genuine mismatches",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local previousDevelopment = this.IsDevelopment
                this.IsDevelopment = true
                integration.InjectTestAssignment(3)
                local bag = AutoCategory.saved.bags[1].rules
                local real = Assignment("Real malformed row", "invalid priority", 43,
                    { icOwned = true, icRuleKey = "real_missing_group" })
                bag[#bag + 1] = real
                assert(not pcall(integration.InjectTestAssignment, 1),
                    "Unrelated real failures must not be bypassed to install a scenario")
                local counts = integration.VerifyTestAssignment()
                assert(counts.test == 0 and counts.unavailable == 1 and bag[#bag] == real)
                assert(not pcall(integration.InjectTestAssignment, 9))
                this.IsDevelopment = previousDevelopment
            end,
        },
        {
            name = "AutoCategory recovery scrollable lists every escaped row and confirmation bounds its preview",
            run = function()
                PrepareActive({})
                local previousRows = integration.unavailableAssignments
                integration.Fail("synthetic preview failure")
                integration.unavailableAssignments = {}
                assert(integration.GetProblemRowsMessage():find("No specific", 1, true))
                local records = integration.unavailableAssignments
                for index = 1, 21 do
                    records[index] = {
                        context = "backpack", ruleKey = "missing_" .. index,
                        line = { name = "Category " .. index .. "|cFFFFFF|r" },
                    }
                end
                local preview = integration.GetProblemRowsMessage()
                assert(preview:find("Problematic assignments (21)", 1, true)
                    and preview:find("Backpack: Category 1||cFFFFFF||r [key=missing_1]", 1, true)
                    and preview:find("[key=missing_20]", 1, true)
                    and preview:find("[key=missing_21]", 1, true))
                local bag = AutoCategory.saved.bags[1].rules
                for index = 1, 21 do
                    bag[#bag + 1] = Assignment("Category " .. index, "invalid priority", 43,
                        { icOwned = true, icRuleKey = "missing_" .. index })
                end
                this.RefreshAutoCategoryUI = function() end
                assert(not integration.RetrySynchronization())
                assert(integration.ShowAssignmentRepair())
                local summary = shownSetup.data.summary
                assert(summary:find("Remove 21 affected", 1, true)
                    and summary:find("Backpack: Category 3", 1, true)
                    and not summary:find("Backpack: Category 4", 1, true)
                    and summary:find("18 more", 1, true)
                    and summary:find("cancel and review", 1, true))
                local ok, report = pcall(integration.ShowRecoveryDetails)
                assert(not ok and tostring(report):find("run priority is invalid", 1, true))
                while #bag > 8 do table.remove(bag) end
                assert(not integration.RetrySynchronization())
                assert(integration.ShowAssignmentRepair())
                summary = shownSetup.data.summary
                assert(summary:find("Remove 5 affected", 1, true)
                    and summary:find("Backpack: Category 5", 1, true)
                    and not summary:find("more.", 1, true))
                integration.unavailableAssignments = previousRows
            end,
        },
        {
            name = "AutoCategory verification reports real mismatches separately and throws a copyable read-only report",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local previousDevelopment = this.IsDevelopment
                this.IsDevelopment = true
                AutoCategory.acctSaved.bags = AutoCategory.saved.bags
                local order, groups = this.accountWide.autoCategoryOrder, this.accountWide.trackedRules
                for _, context in ipairs(contexts) do
                    local rows = AutoCategory.saved.bags[context.bag].rules
                    rows[#rows + 1] = Assignment("Treasure Maps", 42, 43,
                        { icOwned = true, icRuleKey = "real_missing_group" })
                end
                local counts, report = integration.VerifyTestAssignment()
                assert(counts.test == 0 and counts.unavailable == 7 and counts.managed > 7)
                assert(report:find("AC profile: account-wide", 1, true)
                    and report:find("Reserved test row result: item gone", 1, true)
                    and report:find("Real assignment check: 7 unavailable", 1, true)
                    and report:find("real_missing_group", 1, true)
                    and report:find("does not prove a real repair succeeded", 1, true))
                local ok, thrown = pcall(integration.ShowTestVerification)
                assert(not ok and thrown == report and integration.lastVerificationReport == report)
                assert(not integration.NeedsRecovery() and this.accountWide.autoCategoryOrder == order
                    and this.accountWide.trackedRules == groups,
                    "Verification must not reconcile, build plans or fault integration")
                for _, context in ipairs(contexts) do
                    local rows = AutoCategory.saved.bags[context.bag].rules
                    assert(rows[#rows].icRuleKey == "real_missing_group")
                end
                this.IsDevelopment = previousDevelopment
            end,
        },
        {
            name = "AutoCategory saved-data verification distinguishes repair from confirmed reset and setup again",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local previousDevelopment = this.IsDevelopment
                this.IsDevelopment = true
                local messages = {}
                d = function(message) messages[#messages + 1] = message end
                local function Verify(expected)
                    messages = {}
                    local counts = integration.VerifyTestAssignment()
                    assert(messages[#messages - 1]:find(expected, 1, true))
                    return counts
                end
                integration.InjectTestAssignment()
                assert(Verify("test item still present").test == 1)
                assert(integration.ShowAssignmentRepair())
                ConfirmSetup()
                local repaired = Verify("item gone")
                assert(repaired.test == 0 and repaired.managed > 0)
                integration.InjectTestAssignment()
                local profile = this.accountWide
                local groups, order, items = profile.trackedRules, profile.autoCategoryOrder, profile.trackedItems
                local characterOrder = this.character.autoCategoryOrder
                local nativeRows = {}
                for _, context in ipairs(contexts) do
                    nativeRows[context.key] = {}
                    for _, row in ipairs(AutoCategory.saved.bags[context.bag].rules) do
                        if row.icOwned ~= true then
                            nativeRows[context.key][#nativeRows[context.key] + 1] = {
                                row = row, name = row.name, runpriority = row.runpriority,
                                showpriority = row.showpriority, isHidden = row.isHidden,
                            }
                        end
                    end
                end
                local inactive = { bags = { [1] = { rules = {
                    Assignment("Inactive", 91, 92, { icOwned = true, icRuleKey = "other_character" }),
                } } } }
                AutoCategory.charSaved = inactive
                assert(integration.ShowIntegrationReset())
                assert(shownSetup.data.summary:find("Custom integration ordering WILL BE LOST", 1, true))
                assert(profile.autoCategoryOrder == order and profile.autoCategoryIntegrationEnabled == true,
                    "Reset preview must not change saved data")
                ConfirmSetup()
                assert(shownSetup.definition.radioButtons ~= nil, "Reset must ask for the new arrangement before writing")
                assert(profile.autoCategoryOrder == order and profile.autoCategoryIntegrationEnabled == true)
                CancelSetup()
                assert(profile.autoCategoryOrder == order, "Cancelling arrangement must preserve the previous setup")
                assert(integration.ShowIntegrationReset())
                ConfirmSetup()
                ConfirmSetup(2)
                assert(not integration.NeedsRecovery() and integration.IsEditorActive())
                local reset = Verify("item gone")
                assert(reset.test == 0 and reset.managed > 0 and reset.native == repaired.native)
                assert(profile.trackedRules == groups and profile.trackedItems == items
                    and profile.trackedRules.alpha.autoCategoryEnabled == true
                    and profile.autoCategoryIntegrationEnabled == true and profile.autoCategorySetupComplete == true
                    and this.character.autoCategoryOrder == characterOrder
                    and AutoCategory.charSaved == inactive and #inactive.bags[1].rules == 1)
                for _, context in ipairs(contexts) do
                    assert(not profile.autoCategoryOrder.contexts[context.key].hidden["ic:alpha"]
                        and profile.autoCategoryOrder.contexts[context.key].hidden["ic:beta"]
                        and profile.autoCategoryOrder.contexts[context.key].hidden["ic:gamma"]
                        and next(profile.autoCategoryOrder.contexts[context.key].displayPositions) == nil)
                    for index, previous in ipairs(nativeRows[context.key]) do
                        local row = AutoCategory.saved.bags[context.bag].rules[index]
                        assert(row == previous.row and row.name == previous.name and row.isHidden == previous.isHidden,
                            "Reset must preserve native assignments and unrelated fields")
                    end
                end
                assert(integration.lastResetBackup.fields.autoCategoryOrder == order)
                assert(profile.autoCategorySetupComplete and integration.IsEditorActive()
                    and not integration.IsAwaitingSetup())
                this.IsDevelopment = previousDevelopment
            end,
        },
        {
            name = "AutoCategory reset rolls back assignments and settings if cache refresh fails",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local previousDevelopment = this.IsDevelopment
                this.IsDevelopment = true
                integration.InjectTestAssignment()
                this.IsDevelopment = previousDevelopment
                local profile = this.accountWide
                local order, bag = profile.autoCategoryOrder, AutoCategory.saved.bags[1].rules
                local count, injected = #bag, bag[#bag]
                assert(integration.ShowIntegrationReset())
                AutoCategory.cacheInitBag = function() error("synthetic reset cache failure") end
                ConfirmSetup()
                ConfirmSetup()
                assert(integration.NeedsRecovery() and not integration.IsAwaitingSetup()
                    and profile.autoCategoryOrder == order and profile.autoCategoryIntegrationEnabled == true
                    and #bag == count and bag[#bag] == injected)
            end,
        },
        {
            name = "AutoCategory reset refuses sparse assignment lists instead of silently dropping unidentified rows",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                integration.Fail("synthetic failure")
                local bag = AutoCategory.saved.bags[1].rules
                local row = bag[2]
                bag[2] = nil
                assert(not integration.ShowIntegrationReset())
                assert(bag[2] == nil and bag[3] ~= nil and this.accountWide.autoCategoryIntegrationEnabled)
                bag[2] = row
            end,
        },
        {
            name = "AutoCategory reset refuses profile changes after confirmation without deleting assignments",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                integration.Fail("synthetic failure")
                assert(integration.ShowIntegrationReset())
                local bag = AutoCategory.saved.bags[1].rules
                local count = #bag
                shownSetup.data.profile = this.character
                ConfirmSetup()
                assert(not pcall(ConfirmSetup))
                assert(#bag == count and this.accountWide.autoCategoryIntegrationEnabled)
            end,
        },
        {
            name = "AutoCategory orphan survives plugin startup again and can be repaired from reloaded saved tables",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local previousDevelopment = this.IsDevelopment
                this.IsDevelopment = true
                integration.InjectTestAssignment()
                this.IsDevelopment = previousDevelopment
                local previousIntegration = this.AutoCategoryIntegration
                local previousRepairDialog = setupDialogs["InventoryCompanion_AUTOCATEGORY_REPAIR"]
                assert(loadstring(AutoCategoryIntegrationSource))()
                local reloaded = this.AutoCategoryIntegration
                this.autoCategoryFailure = nil
                this.autoCategoryFailureTraceback = nil
                AutoCategory.Inited = false
                AutoCategory.Plugins = {}
                local _, scheduled = InstallHooks()
                reloaded.Initialize()
                AutoCategory.Plugins["Inventory Companion"].initialize()
                AutoCategory.Inited = true
                assert(#scheduled == 1)
                scheduled[1]()
                assert(reloaded.NeedsRecovery() and reloaded.IsPanelAvailable()
                    and this.GetAutoCategoryState().configuredEnabled and not this.GetAutoCategoryState().enabled)
                assert(reloaded.ShowAssignmentRepair())
                ConfirmSetup()
                assert(not reloaded.NeedsRecovery() and reloaded.IsEditorActive())
                this.AutoCategoryIntegration = previousIntegration
                setupDialogs["InventoryCompanion_AUTOCATEGORY_REPAIR"] = previousRepairDialog
            end,
        },
        {
            name = "AutoCategory injected saved assignment is removed by confirmed repair without touching other data",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local ac, profile = AutoCategory, this.accountWide
                local order, groups = profile.autoCategoryOrder, profile.trackedRules
                local before = {}
                for _, context in ipairs(contexts) do
                    before[context.key] = {}
                    for index, row in ipairs(ac.saved.bags[context.bag].rules) do
                        before[context.key][index] = {
                            row = row, name = row.name, runpriority = row.runpriority,
                            showpriority = row.showpriority, isHidden = row.isHidden,
                        }
                    end
                end
                local inactive = { bags = { [1] = { rules = {
                    Assignment("Inactive", 91, 92, { icOwned = true, icRuleKey = "other_character" }),
                } } } }
                ac.charSaved = inactive
                local wasDevelopment = this.IsDevelopment
                this.IsDevelopment = true
                integration.InjectTestAssignment()
                this.IsDevelopment = wasDevelopment
                local bag = ac.saved.bags[1].rules
                local injected = bag[#bag]
                assert(#bag == #before.backpack + 1 and injected.icOwned == true
                    and this.GetRuntimeRules()[injected.icRuleKey] == nil)
                assert(integration.CanRepairAssignments() and integration.NeedsRecovery())
                assert(profile.autoCategoryOrder == order and profile.trackedRules == groups
                    and profile.autoCategoryIntegrationEnabled == true)
                assert(not integration.RetrySynchronization(), "Retry must not remove damaged saved assignments")
                assert(bag[#bag] == injected)
                assert(integration.ShowAssignmentRepair())
                assert(shownSetup.definition.mainText.text(shownSetup):find(injected.name, 1, true))
                assert(bag[#bag] == injected and profile.autoCategoryOrder == order,
                    "Preview must not edit assignments or order")
                ConfirmSetup()
                assert(not integration.NeedsRecovery() and integration.IsEditorActive())
                assert(#integration.lastRepairBackup.rows == 1
                    and integration.lastRepairBackup.rows[1].line.icRuleKey == injected.icRuleKey
                    and integration.lastRepairBackup.rows[1].line ~= injected)
                for _, context in ipairs(contexts) do
                    local rows = ac.saved.bags[context.bag].rules
                    assert(#rows == #before[context.key], "Only the injected row should be removed")
                    for index, previous in ipairs(before[context.key]) do
                        local row = rows[index]
                        assert(row == previous.row and row.name == previous.name
                            and row.runpriority == previous.runpriority and row.showpriority == previous.showpriority
                            and row.isHidden == previous.isHidden, "Existing assignments must be unchanged")
                    end
                    for _, mode in ipairs({ "display", "matching" }) do
                        assert(table.concat(profile.autoCategoryOrder.contexts[context.key][mode], ",")
                            == table.concat(order.contexts[context.key][mode], ","))
                    end
                end
                assert(profile.trackedRules == groups and ac.charSaved == inactive
                    and inactive.bags[1].rules[1].icRuleKey == "other_character")
                assert(not pcall(integration.InjectTestAssignment)
                    and not pcall(integration.RemoveTestAssignment), "Saved-data tests must be DEV-only")
            end,
        },
        {
            name = "AutoCategory saved-data test cleanup removes only its own row and retries recovery",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local bag = AutoCategory.saved.bags[1].rules
                local count = #bag
                local wasDevelopment = this.IsDevelopment
                this.IsDevelopment = true
                integration.InjectTestAssignment()
                integration.InjectTestAssignment()
                assert(#bag == count + 1, "Repeated injection must replace the prior row without accumulating rows")
                assert(integration.RemoveTestAssignment() == 1)
                assert(#bag == count and not integration.NeedsRecovery())
                assert(integration.RemoveTestAssignment() == 0 and #bag == count)
                this.IsDevelopment = wasDevelopment
            end,
        },
        {
            name = "AutoCategory assignment repair rolls back when synchronization fails and refuses incomplete runtime",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local wasDevelopment = this.IsDevelopment
                this.IsDevelopment = true
                integration.InjectTestAssignment()
                this.IsDevelopment = wasDevelopment
                local bag = AutoCategory.saved.bags[1].rules
                local injected = bag[#bag]
                local count, order = #bag, this.accountWide.autoCategoryOrder
                local originalRules = this.GetRuntimeRules
                this.GetRuntimeRules = function() return {} end
                assert(not integration.ShowAssignmentRepair())
                this.GetRuntimeRules = originalRules
                assert(#bag == count and bag[#bag] == injected and this.accountWide.autoCategoryOrder == order)
                assert(integration.ShowAssignmentRepair())
                local cacheInit = AutoCategory.cacheInitBag
                AutoCategory.cacheInitBag = function() error("synthetic repair refresh failure") end
                ConfirmSetup()
                AutoCategory.cacheInitBag = cacheInit
                assert(integration.NeedsRecovery() and #bag == count and bag[#bag] == injected
                    and this.accountWide.autoCategoryOrder == order,
                    "Failed repair must restore assignments and retain saved order")
            end,
        },
        {
            name = "AutoCategory assignment repair restores data when post-projection UI refresh fails",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local wasDevelopment = this.IsDevelopment
                this.IsDevelopment = true
                integration.InjectTestAssignment()
                this.IsDevelopment = wasDevelopment
                local bag = AutoCategory.saved.bags[1].rules
                local count, injected, order = #bag, bag[#bag], this.accountWide.autoCategoryOrder
                assert(integration.ShowAssignmentRepair())
                this.RefreshAutoCategoryUI = function()
                    if not integration.NeedsRecovery() then error("synthetic post-projection UI failure") end
                end
                ConfirmSetup()
                assert(integration.NeedsRecovery() and #bag == count and bag[#bag] == injected
                    and this.accountWide.autoCategoryOrder == order)
                this.RefreshAutoCategoryUI = function() end
            end,
        },
        {
            name = "AutoCategory assignment repair refuses a changed profile or candidate after confirmation",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local wasDevelopment = this.IsDevelopment
                this.IsDevelopment = true
                integration.InjectTestAssignment()
                this.IsDevelopment = wasDevelopment
                assert(integration.ShowAssignmentRepair())
                local bag = AutoCategory.saved.bags[1].rules
                local count = #bag
                local row = bag[count]
                row.showpriority = 17
                assert(not pcall(ConfirmSetup), "Changed candidates must require a fresh confirmation")
                assert(#bag == count and bag[count] == row and row.showpriority == 17)
                assert(integration.ShowAssignmentRepair())
                shownSetup.data.profile = this.character
                assert(not pcall(ConfirmSetup), "A changed profile must prevent repair")
                assert(#bag == count and bag[count] == row)
            end,
        },
        {
            name = "AutoCategory failed state preserves boolean enablement and blocks writes until retry succeeds",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                InstallHooks()
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local prepared = integration.PreflightAutoCategory()
                local profile = this.accountWide
                local order, rules = profile.autoCategoryOrder, profile.trackedRules
                local bag = AutoCategory.saved.bags[1].rules
                local count = #bag
                integration.Fail("Synthetic dependency failure")
                local state = this.GetAutoCategoryState()
                assert(state.configuredEnabled == true and state.enabled == false and state.failed == true)
                assert(type(state.enabled) == "boolean" and type(state.failed) == "boolean")
                assert(profile.autoCategoryIntegrationEnabled == true and profile.autoCategoryOrder == order
                    and profile.trackedRules == rules and #bag == count,
                    "Forced failure must not edit saved data")
                assert(integration.IsPanelAvailable() and not integration.IsEditorActive())
                assert(integration.ProjectAutoCategory(prepared) == false and #bag == count,
                    "A prepared plan must not bypass failure gating")
                assert(not pcall(this.SetAutoCategoryParticipation, "alpha", false))
                assert(profile.trackedRules.alpha.autoCategoryEnabled == true)
                assert(integration.RetrySynchronization(), this.autoCategoryFailure)
                state = this.GetAutoCategoryState()
                assert(state.configuredEnabled and state.enabled and not state.failed)
                assert(integration.IsEditorActive() and integration.IsPanelAvailable())
                assert(profile.trackedRules == rules and profile.trackedRules.alpha.autoCategoryEnabled)
                assert(integration.ForceTestFailure == nil, "Production must not expose a failure simulator")
                profile.autoCategoryIntegrationEnabled = nil
                state = this.GetAutoCategoryState()
                assert(not state.enabled and not state.configuredEnabled and not state.failed)
                assert(integration.IsPanelAvailable() and not integration.IsEditorActive(),
                    "Loaded but off retains the enablement panel")
            end,
        },
        {
            name = "AutoCategory retry retains recovery UI and data when validation still fails",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                InstallHooks()
                this.RefreshAutoCategoryUI = function() end
                assert(integration.ProjectAutoCategory())
                local profile = this.accountWide
                local order = profile.autoCategoryOrder
                local count = #AutoCategory.saved.bags[1].rules
                profile.autoCategorySetupComplete = "malformed"
                integration.Fail("Saved integration data needs validation")
                assert(not integration.RetrySynchronization())
                assert(integration.IsFaulted() and integration.NeedsRecovery() and integration.IsPanelAvailable())
                assert(this.autoCategoryFailure:find("autoCategorySetupComplete must be boolean", 1, true))
                assert(profile.autoCategorySetupComplete == "malformed" and profile.autoCategoryOrder == order
                    and profile.autoCategoryIntegrationEnabled == true and #AutoCategory.saved.bags[1].rules == count,
                    "An unsuccessful retry must not normalize away or overwrite damaged data")
                profile.autoCategorySetupComplete = true
                assert(integration.RetrySynchronization(), this.autoCategoryFailure)
            end,
        },
        {
            name = "AutoCategory stale assignments synchronize automatically and restore AC-side settings on return",
            run = function()
                PrepareActive({})
                InstallHooks()
                this.RefreshAutoCategoryUI = function() end
                local bag = AutoCategory.saved.bags[1].rules
                local orphan = Assignment("Missing", 42, 43, { icOwned = true, icRuleKey = "custom_missing" })
                bag[#bag + 1] = orphan
                orphan.customSetting = { preserve = "AC-side value" }
                assert(integration.ProjectAutoCategory())
                assert(not integration.NeedsRecovery() and integration.IsEditorActive())
                assert(AutoCategory.saved.bags[1].icAssignmentTemplates.custom_missing.customSetting.preserve == "AC-side value")
                for _, row in ipairs(bag) do assert(row ~= orphan) end
                this.accountWide.trackedRules.custom_missing = {
                    displayName = "Missing", addedPatterns = { "missing" }, autoCategoryEnabled = true,
                }
                this.InvalidateRuleCache()
                assert(integration.ProjectAutoCategory())
                local restored = FindAssignment("backpack", "Missing" .. icCategoryNameMarkupSuffix)
                assert(restored and restored.customSetting.preserve == "AC-side value")
            end,
        },
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
                assert(Names(orders.backpack.display) == "alpha,beta,New,Selling,Low level,gamma")
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
                assert(not ok and report:find("synchronization stopped after this failure", 1, true)
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
                            == "New,alpha,backpack,beta,gamma,Selling,Low level,dormant")
                    end
                end
                this.SetAutoCategoryParticipation("alpha", false)
                local order = profile.autoCategoryOrder
                this.SetAutoCategoryIntegrationEnabled(false)
                shownSetup = nil
                this.SetAutoCategoryIntegrationEnabled(true)
                assert(shownSetup == nil and profile.autoCategoryOrder == order
                    and profile.autoCategoryOrder.contexts.backpack.hidden["ic:alpha"],
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
                            == "alpha,New,Selling,Low level,beta,gamma")
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
                assert(Names(this.accountWide.autoCategoryOrder.contexts.backpack.display) == "New,Selling,Low level,alpha,beta,gamma")
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
                assert(Names(orders.display) == "New,Set,Test group,alpha,beta,gamma", Names(orders.display))
                assert(Names(orders.matching) == "New,Set,alpha,Test group,beta,gamma", Names(orders.matching))
                local unique = {}
                for _, assignment in ipairs(AutoCategory.saved.bags[1].rules) do
                    assert(assignment.showpriority >= 2 and assignment.showpriority <= 1000
                        and assignment.showpriority == math.floor(assignment.showpriority))
                    assert(assignment.runpriority >= 2 and assignment.runpriority <= 1000
                        and assignment.runpriority == math.floor(assignment.runpriority))
                    unique[assignment.showpriority] = true
                end
                assert(#AutoCategory.saved.bags[1].rules == 7)
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
                assert(Names(bankOrder.display) == "Selling,New,Low level,Bank only,alpha,beta,gamma", Names(bankOrder.display))
                assert(this.accountWide.trackedRules.alpha.autoCategoryEnabled == alphaParticipation)
                assert(Names(this.accountWide.autoCategoryOrder.contexts.backpack.display) == sourceBefore)
                local matching = Names(bankOrder.matching)
                assert(integration.UseOtherOrder("bank", "display"))
                assert(Names(this.accountWide.autoCategoryOrder.contexts.bank.display) == matching)
                assert(integration.CopyBothOrders("bank", "bank") == false)
            end,
        },
        {
            name = "Legacy all-area inclusion changes retain excluded assignments behind Other",
            run = function()
                PrepareActive({})
                integration.OnRuleMutation = originalOnRuleMutation
                this.SetAutoCategoryParticipation("alpha", true)
                local reference = "ic:alpha"
                for _, context in ipairs(contexts) do
                    local order = this.accountWide.autoCategoryOrder.contexts[context.key]
                    assert(not order.hidden[reference])
                    assert(FindAssignment(context.key, "Alpha" .. icCategoryNameMarkupSuffix))
                end
                local managed = FindAssignment("backpack", "Alpha" .. icCategoryNameMarkupSuffix)
                assert(managed and managed.icRuleKey == "alpha")
                this.SetAutoCategoryParticipation("alpha", false)
                local savedAlpha = this.accountWide.trackedRules.alpha or {}
                assert(savedAlpha.autoCategoryAnchor == nil and savedAlpha.autoCategoryRank == nil)
                assert(FindAssignment("backpack", managed.name) == managed
                    and managed.runpriority < FindAssignment("backpack", "Other" .. icCategoryNameMarkupSuffix).runpriority,
                    "Excluded IC assignments must remain behind the matching barrier")
                assert(select(1, integration.GetStatus()) == "available" and not integration.IsFaulted())
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
                        profile.bags[context.bag].icAssignmentTemplates = {
                            alpha = { icOwned = true, icRuleKey = "alpha", name = "IC-owned", custom = "saved" },
                        }
                        profile.bags[context.bag].unrelatedTemplates = { keep = true }
                    end
                end
                local removals = integration.PreflightSavedDataCleanup()
                assert(#removals == 14)
                assert(integration.ApplySavedDataCleanup(removals) == 14)
                for _, profileName in ipairs({ "acctSaved", "charSaved" }) do
                    for _, context in ipairs(contexts) do
                        local rules = AutoCategory[profileName].bags[context.bag].rules
                        assert(#rules == 1 and rules[1].name == "Native" and rules[1].custom == "preserved")
                        assert(AutoCategory[profileName].bags[context.bag].icAssignmentTemplates == nil
                            and AutoCategory[profileName].bags[context.bag].unrelatedTemplates.keep)
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
                assert(#order.display == 7 and #order.matching == 6)
            end,
        },
        {
            name = "Integer projection reserves one of 999 assignments for Other and rejects overflow without writes",
            run = function()
                PrepareActive({})
                local backpack = AutoCategory.saved.bags[1]
                backpack.rules = {}
                for index = 1, 995 do
                    backpack.rules[index] = Assignment(string.format("Native %03d", index), 1000 - index, 1000 - index,
                        { filter = "preserved" })
                end
                assert(integration.ProjectAutoCategory())
                assert(#backpack.rules == 999)
                for index, assignment in ipairs(backpack.rules) do
                    assert(assignment.showpriority >= 2 and assignment.runpriority >= 2)
                    assert(assignment.filter == "preserved" or assignment.icOwned)
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
            name = "Mismatched profile assignments are replaced without changing source profiles",
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
                assert(passiveSnapshot.cacheInvalid,
                    "Passive diagnostics must not build the lazy runtime-rule cache")
                local orphan = Assignment("Orphan", 42, 43, { icOwned = true, icRuleKey = "custom_missing" })
                local backpack = AutoCategory.saved.bags[1].rules
                backpack[#backpack + 1] = orphan
                this.accountWide.debugEnabled = false

                local prepared = integration.PreflightAutoCategory()
                assert(prepared ~= nil and not integration.IsFaulted())
                assert(backpack[#backpack] == orphan and orphan.runpriority == 42 and orphan.showpriority == 43,
                    "A profile mismatch must preserve AutoCategory assignments and priorities")
                assert(profile.trackedRules == savedRules and profile.autoCategoryOrder == savedOrder
                    and profile.autoCategoryIntegrationEnabled,
                    "A profile mismatch must preserve IC saved rules, order, and enablement")
                assert(#profile.debug.autoCategoryRemovedLines == 0,
                    "Do not archive or remove a mismatch that can be ignored without changing saved data")
                local runtime = this.GetRuntimeRuleDiagnostics("custom_missing")
                assert(runtime.firstAccess ~= nil and not runtime.cacheInvalid,
                    "The natural rule-cache access should still be observable after preflight")
                if passiveSnapshot.firstAccess == nil then
                    assert(runtime.firstAccess.cachePath == "built",
                        "The first natural access should build the invalid cache")
                else
                    for field, value in pairs(passiveSnapshot.firstAccess) do
                        assert(runtime.firstAccess[field] == value,
                            "An earlier session-first access must not be overwritten: " .. field)
                    end
                end
                assert(integration.ProjectAutoCategory(prepared))
                for _, row in ipairs(backpack) do assert(row ~= orphan) end
                assert(AutoCategory.saved.bags[1].icAssignmentTemplates.custom_missing.icRuleKey == "custom_missing")
                assert(this.character.trackedRules.custom_missing.addedPatterns[1] == "synthetic missing group")
                assert(not integration.NeedsRecovery() and #integration.unavailableAssignments == 0)
                this.IsDevelopment = previousDevelopment
                this.state = previousState
            end,
        },
        {
            name = "Legacy global flags no longer remove account-wide assignments",
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
                assert(prepared ~= nil and not integration.IsFaulted())
                assert(backpack[#backpack] == assignment and assignment.runpriority == 42
                    and assignment.showpriority == 43,
                    "The account-wide assignment and its priorities must remain untouched")
                assert(integration.ProjectAutoCategory(prepared))
                assert(FindAssignment("backpack", "Character-specific group" .. icCategoryNameMarkupSuffix) == assignment)
                assert(this.character.trackedRules.custom_missing.autoCategoryEnabled == true)
                assert(not integration.NeedsRecovery())
                this.state = previousState
            end,
        },
        {
            name = "Historical AutoCategory recovery archives remain intact without being replayed into the active profile",
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
                assert(prepared ~= nil, tostring(failure))
                assert(not integration.IsFaulted())
                local archived = this.accountWide.debug.autoCategoryRemovedLines
                assert(#archived == #contexts, "Keep every historical archive row")
                for index, context in ipairs(contexts) do
                    local record = archived[index]
                    assert(record.dateTime == "2026-11-02 17:52:00"
                        and record.context == context.key and record.bagType == context.bag
                        and record.index == originalIndices[context.key]
                        and record.line.name == "Orphan" and record.line.icRuleKey == "custom_missing"
                        and record.line.runpriority == 42 and record.line.showpriority == 43
                        and record.restored == nil,
                        "Historical recovery rows must be preserved without replay or mutation")
                end
                local summary = integration.GetOrphanedAssignmentReport(false)
                assert(#summary == 2 and summary[1]:find("7", 1, true)
                    and summary[1]:find("restored: 0", 1, true),
                    "Normal debug report must retain the historical archive summary")
                local detailed = integration.GetOrphanedAssignmentReport(true)
                assert(#detailed == #contexts + 2
                    and detailed[3]:find("context=backpack", 1, true)
                    and detailed[3]:find("custom_missing", 1, true),
                    "Very verbose report must retain historical assignment details")
                assert(integration.ProjectAutoCategory(prepared) and not integration.IsFaulted())
                for _, context in ipairs(contexts) do
                    local rules = AutoCategory.saved.bags[context.bag].rules
                    local matches = 0
                    for _, assignment in ipairs(rules) do
                        if assignment.icRuleKey == "custom_missing" then matches = matches + 1 end
                    end
                    assert(matches == 0, "Historical recovery rows must not create active assignments")
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
        {
            name = "Synchronization covers all four IC AC scopes and A B A with distinct identities and saved orders",
            run = function()
                for _, characterIC in ipairs({ false, true }) do
                    for _, characterAC in ipairs({ false, true }) do
                        PrepareActive({})
                        local sharedIC = SourceProfile({ "shared_maps", "shared_surveys" }, true)
                        local a = SourceProfile({ "a_maps", "a_treasure" }, false)
                        local b = SourceProfile({ "b_materials" }, false)
                        for _, context in ipairs(contexts) do
                            sharedIC.autoCategoryOrder.contexts[context.key].hidden = { ["ac:New"] = true }
                            a.autoCategoryOrder.contexts[context.key].hidden = { ["ac:Maps"] = true }
                        end
                        a.useCharacterItemList, b.useCharacterItemList = characterIC, characterIC
                        local sharedAC, aAC, bAC = NativeProfile({ "New", "Maps" }),
                            NativeProfile({ "New", "Maps" }), NativeProfile({ "New", "Maps" })
                        this.accountWide, this.character = sharedIC, a
                        AutoCategory.acctSaved, AutoCategory.charSaved = sharedAC, aAC
                        AutoCategory.saved = characterAC and aAC or sharedAC
                        this.ValidateSavedRuleProfiles()
                        this.InvalidateRuleCache()
                        assert(integration.ProjectAutoCategory(), this.autoCategoryFailure)
                        AssertManagedKeys(characterIC and { a_maps = true, a_treasure = true }
                            or { shared_maps = true, shared_surveys = true })
                        local helper = FindAssignment("backpack", "Other" .. icCategoryNameMarkupSuffix)
                        assert(FindAssignment("backpack", characterIC and "Maps" or "New").runpriority < helper.runpriority)
                        local aOrder = a.autoCategoryOrder
                        local sharedOrder = sharedIC.autoCategoryOrder
                        local aOutput = CopyFixtureValue(aAC)
                        local desired = characterIC and a or sharedIC
                        local managed = FindAssignment("backpack", (characterIC and "a_treasure" or "shared_maps")
                            .. icCategoryNameMarkupSuffix)
                        managed.custom = { value = "AC-side setting" }
                        managed.isHidden = true
                        this.character = b
                        AutoCategory.charSaved = bAC
                        AutoCategory.saved = characterAC and bAC or sharedAC
                        this.ValidateSavedRuleProfiles()
                        this.InvalidateRuleCache()
                        assert(integration.ProjectAutoCategory(), this.autoCategoryFailure)
                        AssertManagedKeys(characterIC and { b_materials = true }
                            or { shared_maps = true, shared_surveys = true })
                        if characterIC then
                            assert(FindAssignment("backpack", "Maps").runpriority
                                > FindAssignment("backpack", "Other" .. icCategoryNameMarkupSuffix).runpriority)
                        end
                        assert(a.autoCategoryOrder == aOrder and a.trackedRules.a_treasure.autoCategoryEnabled)
                        if characterIC then
                            assert(table.concat(sharedIC.autoCategoryOrder.contexts.backpack.display, ",")
                                == table.concat(sharedOrder.contexts.backpack.display, ","))
                        end
                        if characterAC then
                            assert(#aAC.bags[1].rules == #aOutput.bags[1].rules
                                and managed.custom.value == "AC-side setting")
                        end
                        this.character = a
                        AutoCategory.charSaved = aAC
                        AutoCategory.saved = characterAC and aAC or sharedAC
                        this.ValidateSavedRuleProfiles()
                        this.InvalidateRuleCache()
                        assert(integration.ProjectAutoCategory(), this.autoCategoryFailure)
                        AssertManagedKeys(characterIC and { a_maps = true, a_treasure = true }
                            or { shared_maps = true, shared_surveys = true })
                        local restored = FindAssignment("backpack", (characterIC and "a_treasure" or "shared_maps")
                            .. icCategoryNameMarkupSuffix)
                        assert(restored.custom.value == "AC-side setting" and restored.isHidden == true)
                        local display = desired.autoCategoryOrder.contexts.backpack.display
                        assert(display[characterIC and #display or 1] == "ac:Maps")
                        assert(sharedAC.unrelated.keep and aAC.unrelated.keep and bAC.unrelated.keep)
                    end
                end
            end,
        },
        {
            name = "Synchronization applies Maps order across both mode switches without losing dormant native references",
            run = function()
                PrepareActive({})
                this.accountWide = SourceProfile({ "shared" }, false)
                this.character = SourceProfile({ "character" }, false)
                this.character.useCharacterItemList = false
                local sharedAC, charAC = NativeProfile({ "New", "Maps" }), NativeProfile({ "New", "Maps" })
                AutoCategory.saved, AutoCategory.acctSaved, AutoCategory.charSaved = sharedAC, sharedAC, charAC
                this.ValidateSavedRuleProfiles()
                this.InvalidateRuleCache()
                assert(integration.ProjectAutoCategory())
                assert(integration.MoveEntry("ac:Maps", "backpack", "display", -1))
                assert(integration.MoveEntry("ac:Maps", "backpack", "display", -1))
                assert(this.accountWide.autoCategoryOrder.contexts.backpack.display[1] == "ac:Maps")
                local _, scheduled = InstallHooks()
                local function Drain()
                    local pending = {}
                    for index, callback in ipairs(scheduled) do pending[index] = callback end
                    for index = #scheduled, 1, -1 do scheduled[index] = nil end
                    for _, callback in ipairs(pending) do callback() end
                    assert(not integration.NeedsRecovery(), this.autoCategoryFailure)
                end
                this.SetUseCharacterItemList(true)
                Drain()
                assert(this.character.autoCategoryOrder.contexts.backpack.display[6] == "ac:Maps",
                    table.concat(this.character.autoCategoryOrder.contexts.backpack.display, ","))
                assert(FindAssignment("backpack", "Maps").showpriority < FindAssignment("backpack", "New").showpriority)
                this.SetUseCharacterItemList(false)
                Drain()
                assert(FindAssignment("backpack", "Maps").showpriority > FindAssignment("backpack", "New").showpriority)
                local sharedOrder = this.accountWide.autoCategoryOrder
                local sharedMapsPriority = sharedAC.bags[1].rules[2].showpriority
                AutoCategory.saved = charAC
                integration.OnProfileChanged()
                Drain()
                assert(this.accountWide.autoCategoryOrder.contexts.backpack.display[1] == "ac:Maps")
                assert(FindAssignment("backpack", "Maps").showpriority > FindAssignment("backpack", "New").showpriority)
                assert(sharedAC.bags[1].rules[2].showpriority == sharedMapsPriority)
                local withoutMaps = NativeProfile({ "New" })
                AutoCategory.saved = withoutMaps
                integration.OnProfileChanged()
                Drain()
                assert(this.accountWide.autoCategoryOrder.contexts.backpack.display[1] == "ac:Maps")
                for _, row in ipairs(integration.ResolveAutoCategoryOrder("backpack")) do
                    assert(row.reference ~= "ac:Maps", "Dormant native categories must not be shown in another AC profile")
                end
                AutoCategory.saved = sharedAC
                integration.OnProfileChanged()
                Drain()
                assert(FindAssignment("backpack", "Maps").showpriority > FindAssignment("backpack", "New").showpriority)
                assert(sharedOrder.contexts.backpack.display[1] == "ac:Maps")
            end,
        },
        {
            name = "Native exclusion uses an enablement-gated Other predicate without deleting native Other or settings",
            run = function()
                PrepareInitialSetup()
                local ac = AutoCategory
                local _, scheduled = InstallHooks()
                this.accountWide.autoCategoryIntegrationEnabled = true
                this.accountWide.autoCategorySetupComplete = true
                ac.Plugins["Inventory Companion"].initialize()
                for _, callback in ipairs(scheduled) do callback() end
                local nativeOther = Assignment("Other", 90, 90, { external = "Other remains native" })
                ac.saved.bags[1].rules[#ac.saved.bags[1].rules + 1] = nativeOther
                assert(integration.ProjectAutoCategory())
                local native = FindAssignment("backpack", "Selling")
                local isHidden = native.isHidden
                assert(integration.SetEntryIncluded("ac:Selling", "backpack", false))
                local helper = FindAssignment("backpack", "Other" .. icCategoryNameMarkupSuffix)
                assert(helper and helper.icOwned and helper.icRuleKey == "__ic_other")
                assert(FindAssignment("backpack", "New").runpriority > helper.runpriority
                    and helper.runpriority > native.runpriority)
                assert(FindAssignment("backpack", "Other") == nativeOther and native.isHidden == isHidden)
                local previousGetName = GetItemLinkName
                GetItemLinkName = function(link) return link end
                ac.checkingItemLink = "uncategorized synthetic item"
                assert(ac.RulesW.predicate("__ic_other") == true)
                for _, row in ipairs(integration.ResolveAutoCategoryOrder("backpack", { mode = "matching" })) do
                    assert(row.reference ~= "ic:__ic_other")
                end
                assert(this.GetRuntimeRules().__ic_other == nil)
                local priority = native.runpriority
                integration.OnEnablementChanged = originalOnEnablementChanged
                assert(this.SetAutoCategoryIntegrationEnabled(false))
                assert(ac.RulesW.predicate("__ic_other") == false)
                assert(FindAssignment("backpack", helper.name) == nil and native.runpriority == priority)
                assert(this.accountWide.autoCategoryOrder.contexts.backpack.hidden["ac:Selling"])
                assert(this.SetAutoCategoryIntegrationEnabled(true))
                assert(integration.ProjectAutoCategory())
                assert(FindAssignment("backpack", helper.name).runpriority > native.runpriority)
                GetItemLinkName = previousGetName
            end,
        },
        {
            name = "Re-inclusion restores display insertion and initializes matching from the restored display number",
            run = function()
                for _, reference in ipairs({ "ac:Selling", "ic:alpha" }) do
                    PrepareActive({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true },
                        gamma = { autoCategoryEnabled = true } })
                    assert(integration.ProjectAutoCategory())
                    local remaining = { "ac:New", "ic:beta", "ic:gamma", "ac:Low level",
                        reference == "ic:alpha" and "ac:Selling" or "ic:alpha" }
                    local display = CopyFixtureValue(remaining)
                    table.insert(display, 4, reference)
                    display[#display + 1] = "ic:__ic_other"
                    local matching = CopyFixtureValue(remaining)
                    table.insert(matching, 1, reference)
                    assert(this.SetAutoCategoryContextOrder("backpack", "display", display))
                    assert(this.SetAutoCategoryContextOrder("backpack", "matching", matching))
                    assert(integration.SetEntryIncluded(reference, "backpack", false))
                    local order = this.accountWide.autoCategoryOrder.contexts.backpack
                    assert(order.displayPositions[reference] == 4)
                    assert(integration.SetEntryIncluded(reference, "backpack", true))
                    local restored = this.accountWide.autoCategoryOrder.contexts.backpack
                    assert(restored.display[5] == reference and restored.matching[6] == reference,
                        "Matching must use restored display number 5, not old matching number 1")
                    assert(#restored.display == 7 and #restored.matching == 6)
                    this.ValidateAutoCategoryRecoveryData()
                end
            end,
        },
        {
            name = "Failed exclusion rolls back assignments templates and proposed profile state",
            run = function()
                for _, reference in ipairs({ "ac:Selling", "ic:alpha" }) do
                    PrepareActive({ alpha = { autoCategoryEnabled = true } })
                    assert(integration.ProjectAutoCategory())
                    local order = this.accountWide.autoCategoryOrder
                    local bag = AutoCategory.saved.bags[1]
                    local rows, templates = CopyFixtureValue(bag.rules), bag.icAssignmentTemplates
                    AutoCategory.cacheInitBag = function() error("synthetic exclusion cache failure") end
                    assert(integration.SetEntryIncluded(reference, "backpack", false) == false)
                    assert(integration.IsFaulted() and this.accountWide.autoCategoryOrder == order)
                    assert(this.accountWide.trackedRules.alpha.autoCategoryEnabled)
                    assert(bag.icAssignmentTemplates == templates and #bag.rules == #rows)
                    for index, row in ipairs(bag.rules) do
                        assert(row.name == rows[index].name and row.runpriority == rows[index].runpriority
                            and row.showpriority == rows[index].showpriority)
                    end
                    assert(not order.contexts.backpack.hidden[reference]
                        and next(order.contexts.backpack.displayPositions) == nil)
                end
            end,
        },
        {
            name = "Synchronization rejects incomplete runtime malformed templates and ownership collisions before deleting stale rows",
            run = function()
                for _, scenario in ipairs({ "runtime", "runtime-fields", "runtime-extra", "templates", "collision", "sparse" }) do
                    PrepareActive({ alpha = { autoCategoryEnabled = true } })
                    local bag = AutoCategory.saved.bags[1]
                    local orphan = Assignment("Stale", 42, 43, { icOwned = true, icRuleKey = "other_profile" })
                    bag.rules[#bag.rules + 1] = orphan
                    local order = this.accountWide.autoCategoryOrder
                    local originalRuntime = this.GetRuntimeRules
                    if scenario == "runtime" then this.GetRuntimeRules = function() return {} end
                    elseif scenario == "runtime-fields" or scenario == "runtime-extra" then
                        local incomplete = CopyFixtureValue(originalRuntime())
                        if scenario == "runtime-fields" then incomplete.alpha.display = nil
                        else
                            incomplete.unexpected = CopyFixtureValue(incomplete.alpha)
                            incomplete.unexpected.isPreloaded = false
                        end
                        this.GetRuntimeRules = function() return incomplete end
                    elseif scenario == "templates" then bag.icAssignmentTemplates = { other_profile = { custom = true } }
                    elseif scenario == "collision" then
                        bag.rules[#bag.rules + 1] = Assignment("Other" .. icCategoryNameMarkupSuffix, 40, 40)
                    else bag.rules[2] = nil end
                    assert(integration.ProjectAutoCategory() == false and integration.IsFaulted(), scenario)
                    this.GetRuntimeRules = originalRuntime
                    assert(bag.rules[4] == orphan and orphan.runpriority == 42 and orphan.showpriority == 43
                        and this.accountWide.autoCategoryOrder == order)
                end
            end,
        },
        {
            name = "Missing AutoCategory preserves editable source participation without projecting or faulting IC",
            run = function()
                NewFixture()
                AutoCategory = nil
                integration.Initialize()
                this.accountWide.autoCategoryIntegrationEnabled = true
                this.accountWide.autoCategorySetupComplete = true
                local order = this.accountWide.autoCategoryOrder
                this.SetAutoCategoryParticipation("alpha", true)
                assert(this.GetRuntimeRules().alpha.autoCategoryEnabled)
                this.SetAutoCategoryParticipation("alpha", false)
                assert(not this.GetRuntimeRules().alpha.autoCategoryEnabled)
                assert(not integration.IsFaulted() and this.accountWide.autoCategoryOrder == order)
                assert(select(1, integration.GetStatus()) == "absent")
            end,
        },
        {
            name = "Explicit profile copying includes exclusions restoration references and complete item preferences by value",
            run = function()
                PrepareActive({ alpha = { autoCategoryEnabled = true } })
                assert(integration.ProjectAutoCategory())
                assert(integration.SetEntryIncluded("ac:Selling", "backpack", false))
                local source = CopyFixtureValue(this.accountWide)
                source.trackedItems[99] = { link = "item", display = { isHidden = true, isExpanded = false,
                    notifyChat = false, notifyHud = true }, extra = { keep = true } }
                _G[this.SettingsName] = { Default = { account = { source = source } } }
                InstallHooks()
                assert(this.CopyProfile("source"))
                local destination = this.accountWide
                local order = destination.autoCategoryOrder.contexts.backpack
                assert(order.hidden["ac:Selling"] and order.displayPositions["ac:Selling"] == 2)
                assert(destination.trackedItems[99].display.isExpanded == false
                    and destination.trackedItems[99].display.notifyChat == false
                    and destination.trackedItems[99].extra.keep)
                order.hidden["ac:Selling"] = nil
                destination.trackedItems[99].extra.keep = false
                assert(source.autoCategoryOrder.contexts.backpack.hidden["ac:Selling"]
                    and source.trackedItems[99].extra.keep)
            end,
        },
        {
            name = "Cold startup and reload-equivalent deferred projection use IC saved order and remove stale assignments",
            run = function()
                NewFixture()
                this.accountWide.trackedRules.alpha = { autoCategoryEnabled = true }
                this.accountWide.autoCategoryIntegrationEnabled = true
                this.accountWide.autoCategorySetupComplete = true
                for _, context in ipairs(contexts) do
                    this.accountWide.autoCategoryOrder.contexts[context.key] = {
                        display = { "ac:Low level", "ic:alpha", "ac:New", "ac:Selling" },
                        matching = { "ic:alpha", "ac:Low level", "ac:Selling", "ac:New" },
                    }
                    local bag = AutoCategory.saved.bags[context.bag]
                    bag.rules[#bag.rules + 1] = Assignment("Stale", 200, 200,
                        { icOwned = true, icRuleKey = "previous_character", custom = { keep = true } })
                end
                this.ValidateSavedRuleProfiles()
                this.InvalidateRuleCache()
                local ac = NewStartupAutoCategory()
                local _, scheduled = InstallHooks()
                integration.Initialize()
                ac.Plugins["Inventory Companion"].initialize()
                assert(select(1, integration.GetStatus()) == "pending")
                ac.Inited = true
                scheduled[1]()
                assert(integration.IsEditorActive() and not integration.NeedsRecovery())
                local order = this.accountWide.autoCategoryOrder.contexts.backpack
                assert(order.display[1] == "ac:Low level" and order.matching[1] == "ic:alpha")
                assert(FindAssignment("backpack", "Stale") == nil)
                assert(ac.saved.bags[1].icAssignmentTemplates.previous_character.custom.keep)
                local before = table.concat(order.display, ",")
                this.InvalidateRuleCache()
                integration.OnProfileChanged()
                scheduled[#scheduled]()
                assert(table.concat(this.accountWide.autoCategoryOrder.contexts.backpack.display, ",") == before)
            end,
        },
        {
            name = "Synthetic inventory-style burst coalesces 100 pattern updates across 128 groups and seven contexts",
            run = function()
                local rules = {}
                for index = 1, 128 do
                    rules["burst_" .. index] = {
                        displayName = "Burst " .. index, addedPatterns = { "synthetic*" }, autoCategoryEnabled = true,
                    }
                end
                PrepareActive(rules)
                assert(integration.ProjectAutoCategory())
                integration.OnRuleMutation = originalOnRuleMutation
                local _, scheduled = InstallHooks()
                local refreshes, caches = 0, 0
                AutoCategory.RefreshList = function() refreshes = refreshes + 1 end
                AutoCategory.cacheInitBag = function() caches = caches + 1 end
                local order, sourceRules = this.accountWide.autoCategoryOrder, this.accountWide.trackedRules
                local started = os.clock()
                for _ = 1, 100 do integration.OnRuleMutation("patterns", "burst_1") end
                assert(#scheduled == 100)
                for _, callback in ipairs(scheduled) do callback() end
                assert(refreshes == 7 and caches == 0 and not integration.NeedsRecovery())
                assert(this.accountWide.autoCategoryOrder == order and this.accountWide.trackedRules == sourceRules)
                for _, context in ipairs(contexts) do
                    assert(#AutoCategory.saved.bags[context.bag].rules == 135)
                end
                return string.format("Synthetic only: 100 updates, 128 groups, seven contexts; %.2f ms CPU; seven refreshes, zero cache rebuilds.",
                    (os.clock() - started) * 1000)
            end,
        },
        {
            name = "Group additions renames and deletions reconcile active output and preserve inactive profiles",
            run = function()
                PrepareActive({})
                assert(integration.ProjectAutoCategory())
                integration.OnRuleMutation = originalOnRuleMutation
                local _, scheduled = InstallHooks()
                local inactive = NativeProfile({ "Inactive" })
                AutoCategory.charSaved = inactive
                this.CreateCustomRule("lifecycle", "Original")
                this.UpdateRulePatterns("lifecycle", { "synthetic*" })
                scheduled[#scheduled]()
                assert(FindAssignment("backpack", "Original" .. icCategoryNameMarkupSuffix))
                this.UpdateRuleProperty("lifecycle", "displayName", "Renamed")
                scheduled[#scheduled]()
                assert(FindAssignment("backpack", "Original" .. icCategoryNameMarkupSuffix) == nil)
                assert(FindAssignment("backpack", "Renamed" .. icCategoryNameMarkupSuffix))
                this.DeleteCustomRule("lifecycle")
                scheduled[#scheduled]()
                assert(FindAssignment("backpack", "Renamed" .. icCategoryNameMarkupSuffix) == nil)
                assert(not integration.NeedsRecovery() and this.GetRuntimeRules().lifecycle == nil)
                for _, context in ipairs(contexts) do
                    local orders = this.accountWide.autoCategoryOrder.contexts[context.key]
                    assert(orders.displayPositions["ic:lifecycle"] == nil)
                    for _, mode in ipairs({ "display", "matching" }) do
                        for _, reference in ipairs(orders[mode]) do assert(reference ~= "ic:lifecycle") end
                    end
                    assert(#inactive.bags[context.bag].rules == 1
                        and inactive.bags[context.bag].rules[1].name == "Inactive")
                end
            end,
        },
    }
end
