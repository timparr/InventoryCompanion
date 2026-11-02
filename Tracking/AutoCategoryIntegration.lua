local this = InventoryCompanion
local integration = {}
this.AutoCategoryIntegration = integration

local pluginName = "Inventory Companion"
local ruleTag = "Inventory Companion"
local predicateName = "ic_group"
local categoryNameMarkupSuffix = "|cFFFFFF|r"

local contexts = {
    { key = "backpack", title = "Backpack", bagType = function() return AC_BAG_TYPE_BACKPACK end,
        inventoryType = function() return INVENTORY_BACKPACK end },
    { key = "bank", title = "Bank", bagType = function() return AC_BAG_TYPE_BANK end,
        inventoryType = function() return INVENTORY_BANK end },
    { key = "guild_bank", title = "Guild Bank", bagType = function() return AC_BAG_TYPE_GUILDBANK end,
        inventoryType = function() return INVENTORY_GUILD_BANK end },
    { key = "house_bank", title = "House Bank", bagType = function() return AC_BAG_TYPE_HOUSEBANK end,
        inventoryType = function() return INVENTORY_HOUSE_BANK end },
    { key = "crafting_station", title = "Crafting Station", bagType = function() return AC_BAG_TYPE_CRAFTSTATION end,
        inventoryType = function() return 880 end },
    { key = "craft_bag", title = "Craft Bag", bagType = function() return AC_BAG_TYPE_CRAFTBAG end,
        inventoryType = function() return INVENTORY_CRAFT_BAG end },
    { key = "furniture_vault", title = "Furniture Vault", bagType = function() return AC_BAG_TYPE_FURNVAULT end,
        inventoryType = function() return INVENTORY_FURNITURE_VAULT end },
}

local contextByKey = {}
for _, context in ipairs(contexts) do contextByKey[context.key] = context end

local status = { state = "uninitialized", message = "AutoCategory integration has not initialized." }
local registeredPlugin
local hooksInstalled = false
local reconciling = false
local pendingGeneration = 0
local InstallExternalHooks
local function SetStatus(state, message)
    if status.state == state and status.message == message then return end
    status = { state = state, message = message }
    if this.RefreshAutoCategoryUI then this.RefreshAutoCategoryUI() end
end

-- Action timing diagnostics, active only in Debug Mode. Slow actions are reported to chat, never raised, so
-- diagnostics cannot block the editor or disable the integration.
local timing = {
    historySize = 12,
    history = {},
}
integration.Timing = timing
local activeAction
local nextFrameCheck = 0
local unpackValues = unpack or table.unpack

local function PackValues(...)
    return { n = select("#", ...), ... }
end

local function FormatTimingValue(value)
    if type(value) ~= "table" then return tostring(value) end
    local parts = {}
    for index, item in ipairs(value) do parts[index] = tostring(item) end
    return "[" .. #parts .. "] " .. table.concat(parts, ", ")
end

local function BuildTimingReport(record, stage, elapsedMs)
    local lines = {
        string.format("[InventoryCompanion] Slow AutoCategory %s: %s took %d ms %s (threshold %d ms).",
            record.source, record.operation, elapsedMs, stage, record.thresholdMs),
        "Synchronous total: " .. tostring(record.totalMs) .. " ms",
        "Since previous timed action finished: "
            .. (record.sincePreviousMs and (record.sincePreviousMs .. " ms") or "none this session"),
    }
    if record.failure then lines[#lines + 1] = "Integration failed during this action: " .. record.failure end
    lines[#lines + 1] = "Phases:"
    for _, phase in ipairs(record.phases) do
        lines[#lines + 1] = "  " .. string.rep("  ", phase.depth) .. phase.name .. ": "
            .. (phase.ms and (phase.ms .. " ms") or "did not finish")
    end
    lines[#lines + 1] = "State at start:"
    local keys = {}
    for key in pairs(record.snapshot) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        lines[#lines + 1] = "  " .. key .. ": " .. FormatTimingValue(record.snapshot[key])
    end
    lines[#lines + 1] = "Recent timed actions (oldest first):"
    for _, entry in ipairs(timing.history) do
        lines[#lines + 1] = string.format("  %s: %s, %d ms, +%s ms after previous", entry.source, entry.operation,
            entry.totalMs, tostring(entry.sincePreviousMs or "-"))
    end
    return table.concat(lines, "\n")
end

local function ReportSlowAction(record, stage, elapsedMs)
    local report = BuildTimingReport(record, stage, elapsedMs)
    timing.lastSlowReport = report
    d(report)
end

local function ScheduleNextFrameCheck(record)
    nextFrameCheck = nextFrameCheck + 1
    local updateName = "InventoryCompanion_AutoCategoryTiming" .. nextFrameCheck
    EVENT_MANAGER:RegisterForUpdate(updateName, 0, function()
        EVENT_MANAGER:UnregisterForUpdate(updateName)
        local elapsed = GetGameTimeMilliseconds() - record.started
        record.nextFrameMs = elapsed
        if elapsed > record.thresholdMs then ReportSlowAction(record, "before the next frame", elapsed) end
    end)
end

local function AppendTraceback(failure)
    return debug.traceback(tostring(failure), 2)
end

function integration.TimePhase(name, operation, ...)
    local record = activeAction
    if record == nil then return operation(...) end
    local phase = { name = name, depth = record.depth }
    record.phases[#record.phases + 1] = phase
    record.depth = record.depth + 1
    local started = GetGameTimeMilliseconds()
    local results = PackValues(operation(...))
    phase.ms = GetGameTimeMilliseconds() - started
    record.depth = phase.depth
    return unpackValues(results, 1, results.n)
end

-- Times a user action or deferred callback; nested calls are recorded as phases of the outer action.
function integration.TimeAction(source, operation, snapshot, action, ...)
    assert(type(source) == "string" and type(operation) == "string", "Timed action requires source and operation names")
    assert(type(snapshot) == "function" and type(action) == "function", "Timed action requires snapshot and action functions")
    if activeAction ~= nil then return integration.TimePhase(source .. " " .. operation, action, ...) end
    if this.accountWide.debugEnabled ~= true then return action(...) end
    local started = GetGameTimeMilliseconds()
    local record = {
        source = source, operation = operation, snapshot = snapshot(), phases = {}, depth = 0, started = started,
        sincePreviousMs = timing.lastFinished and started - timing.lastFinished or nil,
        thresholdMs = this.accountWide.autoCategoryTimingThresholdMs,
    }
    local faultedBefore = integration.IsFaulted()
    local arguments = PackValues(...)
    activeAction = record
    -- Lua 5.1 xpcall does not forward extra arguments.
    local results = PackValues(xpcall(function() return action(unpackValues(arguments, 1, arguments.n)) end,
        AppendTraceback))
    activeAction = nil
    if not faultedBefore and integration.IsFaulted() then record.failure = this.autoCategoryFailure end
    local finished = GetGameTimeMilliseconds()
    record.totalMs = finished - started
    timing.lastFinished = finished
    timing.lastAction = record
    table.insert(timing.history, {
        source = source, operation = operation, totalMs = record.totalMs, sincePreviousMs = record.sincePreviousMs,
    })
    if #timing.history > timing.historySize then table.remove(timing.history, 1) end
    if not results[1] then error(results[2], 0) end
    if record.totalMs > record.thresholdMs then
        ReportSlowAction(record, "synchronously", record.totalMs)
    else
        ScheduleNextFrameCheck(record)
    end
    return unpackValues(results, 2, results.n)
end

local function IntegrationSnapshot()
    return {
        integrationState = status.state,
        faulted = integration.IsFaulted(),
        reconciling = reconciling,
        autoCategoryInited = AutoCategory ~= nil and AutoCategory.Inited == true,
    }
end
integration.TimingSnapshot = IntegrationSnapshot

function integration.GetStatus()
    return status.state, status.message
end

function integration.IsFaulted()
    return this.autoCategoryFailure ~= nil
end

function integration.Run(operation, ...)
    if integration.IsFaulted() then return false, this.autoCategoryFailure end
    local arguments = { n = select("#", ...), ... }
    local traceback
    -- Lua 5.1 xpcall does not forward extra arguments; the handler keeps the stack for Debug Mode reports.
    local ok, result = xpcall(function() return operation(unpackValues(arguments, 1, arguments.n)) end,
        function(failure)
            traceback = debug.traceback(tostring(failure), 2)
            return failure
        end)
    if not ok then
        integration.Fail(result, traceback)
        return false, result
    end
    return result
end

function integration.IsAvailable()
    return not integration.IsFaulted() and (status.state == "available" or status.state == "disabled")
end

function integration.IsEditorActive()
    return integration.IsAvailable() and this.GetAutoCategoryState().enabled
end

function integration.GetContexts()
    local result = {}
    for _, context in ipairs(contexts) do
        result[#result + 1] = { key = context.key, title = context.title }
    end
    return result
end

function integration.GetHeadingDetails(name)
    assert(type(name) == "string" and name ~= "", "AutoCategory heading name must be non-empty")
    local definition = AutoCategory.GetRuleByName(name)
    if definition == nil then return nil end
    assert(type(definition) == "table" and type(definition.rule) == "string",
        "AutoCategory heading definition is malformed: " .. name)
    return { name = name, rule = definition.rule }
end

local function GetRuntimeRules()
    return this.GetRuntimeRules()
end

local function IsOrdinaryRule(ruleKey, rule)
    return ruleKey ~= "miscellaneous" and rule.isPreloaded ~= nil
end

local function GetOrderedRuleKeys(rules)
    local keys = {}
    for ruleKey, rule in pairs(rules) do
        if IsOrdinaryRule(ruleKey, rule) then table.insert(keys, ruleKey) end
    end
    table.sort(keys, function(left, right)
        local a, b = rules[left], rules[right]
        local nameA, nameB = a.displayName:lower(), b.displayName:lower()
        if nameA ~= nameB then return nameA < nameB end
        return left < right
    end)
    return keys
end

local function GetCategoryName(rule)
    return rule.displayName .. categoryNameMarkupSuffix
end

local function QuoteLuaString(value)
    assert(type(value) == "string" and value ~= "", "AutoCategory group key must be a non-empty string")
    return string.format("%q", value)
end

local function BuildDefinition(ruleKey, rule)
    return {
        name = GetCategoryName(rule),
        tag = ruleTag,
        rule = predicateName .. "(" .. QuoteLuaString(ruleKey) .. ")",
        description = "Inventory Companion group: " .. rule.displayName,
        icIntegrationOwned = true,
        icRuleKey = ruleKey,
    }
end

local function BuildDefinitions(rules)
    rules = rules or GetRuntimeRules()
    local definitions = {}
    for _, ruleKey in ipairs(GetOrderedRuleKeys(rules)) do
        definitions[#definitions + 1] = BuildDefinition(ruleKey, rules[ruleKey])
    end
    return definitions
end

local function ContainsName(entries, name)
    if entries == nil then return false end
    assert(type(entries) == "table", "AutoCategory rule collection must be a table")
    for _, entry in pairs(entries) do
        assert(type(entry) == "table", "AutoCategory rule collection contains a malformed entry")
        if entry.name == name then return true end
    end
    return false
end

local function CheckExternalShape(ac)
    assert(type(ac) == "table", "AutoCategory namespace must be a table")
    assert(type(ac.RegisterPlugin) == "function" and type(ac.AddRuleFunc) == "function",
        "AutoCategory plugin registration APIs are unavailable")
    assert(type(ac.Plugins) == "table" and type(ac.RulesW) == "table"
        and type(ac.RulesW.ruleList) == "table" and type(ac.RulesW.ruleNames) == "table"
        and type(ac.RulesW.AddRule) == "function",
        "AutoCategory rule/plugin registries are incompatible")
    assert(type(ac.acctSaved) == "table" and type(ac.charSaved) == "table",
        "AutoCategory account or character saved profiles are unavailable")
    assert(type(ac.GetRuleByName) == "function" and type(ac.predefinedRules) == "table"
        and type(ac.RefreshList) == "function",
        "AutoCategory rule lookup, definitions, or refresh APIs are unavailable")
    assert(type(ac.cacheInitBag) == "function" and type(ac.cacheInitialize) == "function"
        and type(ac.cacheRuleInitialize) == "function" and type(ac.RulesW.CompileAll) == "function"
        and type(ac.RuleList) == "table" and type(ac.RuleList.removeRuleByName) == "function"
        and type(ac.RulesW.compiled) == "table",
        "AutoCategory cache or rule lifecycle APIs are incompatible")
end

local function CheckActiveAssignments(ac, allowNotReady)
    if allowNotReady and ac.Inited ~= true then
        if type(ac.saved) ~= "table" or type(ac.saved.bags) ~= "table" then return false end
        for _, context in ipairs(contexts) do
            local bag = ac.saved.bags[context.bagType()]
            if bag == nil then return false end
            assert(type(bag) == "table", "AutoCategory active assignments are malformed for " .. context.title)
            if bag.rules == nil then return false end
            assert(type(bag.rules) == "table", "AutoCategory active assignments are malformed for " .. context.title)
        end
        return true
    end
    assert(type(ac.saved) == "table" and type(ac.saved.bags) == "table",
        "AutoCategory active profile assignments are unavailable")
    for _, context in ipairs(contexts) do
        local bagType = context.bagType()
        assert(type(bagType) == "number" and type(ac.saved.bags[bagType]) == "table"
            and type(ac.saved.bags[bagType].rules) == "table",
            "AutoCategory is missing active assignments for " .. context.title)
    end
    return true
end

local function CheckDefinitionCollision(ac, definitions)
    local sources = {
        ac.RulesW.ruleList,
        ac.predefinedRules,
        ac.default_rules and ac.default_rules.rules,
        ac.acctRules and ac.acctRules.rules,
    }
    for _, profile in ipairs({ ac.acctSaved, ac.charSaved }) do
        if profile.rules ~= nil then sources[#sources + 1] = profile.rules end
    end
    for pluginKey, plugin in pairs(ac.Plugins) do
        if pluginKey ~= pluginName and plugin.predef then sources[#sources + 1] = plugin.predef end
    end
    for _, definition in ipairs(definitions) do
        for _, source in ipairs(sources) do
            if ContainsName(source, definition.name) then
                local existing
                for _, entry in pairs(source) do
                    if entry.name == definition.name then existing = entry; break end
                end
                if not (existing and existing.icIntegrationOwned) then
                    return false, "AutoCategory name collision: " .. definition.name
                end
            end
        end
        for _, profile in ipairs({ ac.acctSaved, ac.charSaved }) do
            for _, context in ipairs(contexts) do
                local bag = profile.bags and profile.bags[context.bagType()]
                if bag ~= nil then
                    assert(type(bag.rules) == "table", "AutoCategory saved assignments are malformed")
                    for _, assignment in ipairs(bag.rules) do
                        assert(type(assignment) == "table", "AutoCategory assignment is malformed")
                        if assignment.name == definition.name and assignment.icOwned ~= true then
                            return false, "AutoCategory assignment collision: " .. definition.name
                        end
                    end
                end
            end
        end
    end
    return true
end

local function SameDefinition(existing, desired)
    if type(existing) ~= "table" then return false end
    for key, value in pairs(desired) do
        if existing[key] ~= value then return false end
    end
    return true
end

local function DefinitionsMatch(ac, plugin, definitions)
    if #plugin.predef ~= #definitions then return false end
    local pluginByName, predefinedByName = {}, {}
    for _, definition in ipairs(plugin.predef) do pluginByName[definition.name] = definition end
    local ownedCount = 0
    for _, definition in ipairs(ac.predefinedRules) do
        if definition.icIntegrationOwned then
            predefinedByName[definition.name] = definition
            ownedCount = ownedCount + 1
        end
    end
    if ownedCount ~= #definitions then return false end
    for _, definition in ipairs(definitions) do
        if not SameDefinition(pluginByName[definition.name], definition)
            or not SameDefinition(predefinedByName[definition.name], definition)
            or not SameDefinition(ac.GetRuleByName(definition.name), definition) then
            return false
        end
    end
    return true
end

local function SyncDefinitions(ac, definitions)
    local plugin = ac.Plugins[pluginName]
    assert(plugin and type(plugin.predef) == "table", "AutoCategory did not retain the integration plugin")
    if DefinitionsMatch(ac, plugin, definitions) then return end
    local desiredNames = {}
    for _, definition in ipairs(definitions) do desiredNames[definition.name] = true end

    for index = #plugin.predef, 1, -1 do
        local definition = plugin.predef[index]
        if definition.icIntegrationOwned and not desiredNames[definition.name] then
            ac.RuleList.removeRuleByName(ac.RulesW, definition.name)
            ac.RulesW.compiled[definition.name] = nil
            table.remove(plugin.predef, index)
            for predefIndex = #ac.predefinedRules, 1, -1 do
                if ac.predefinedRules[predefIndex].name == definition.name
                    and ac.predefinedRules[predefIndex].icIntegrationOwned then
                    table.remove(ac.predefinedRules, predefIndex)
                end
            end
        end
    end
    -- removeRuleByName shifts later rules without reindexing ruleNames, so name lookups are stale until rebuilt.
    ac.cacheRuleInitialize()
    for _, definition in ipairs(definitions) do
        local existing = ac.GetRuleByName(definition.name)
        if existing and existing.icIntegrationOwned then
            ac.RulesW.AddRule(ac.RulesW, definition, true)
        elseif existing == nil then
            ac.RulesW.AddRule(ac.RulesW, definition)
        else
            error("AutoCategory definition collision appeared after preflight: " .. definition.name)
        end
        local found
        for index, old in ipairs(plugin.predef) do
            if old.icRuleKey == definition.icRuleKey then
                plugin.predef[index] = definition
                found = true
                break
            end
        end
        if not found then plugin.predef[#plugin.predef + 1] = definition end
        found = false
        for index, old in ipairs(ac.predefinedRules) do
            if old.icRuleKey == definition.icRuleKey and old.icIntegrationOwned then
                ac.predefinedRules[index] = definition
                found = true
                break
            end
        end
        if not found then ac.predefinedRules[#ac.predefinedRules + 1] = definition end
    end
    ac.cacheRuleInitialize()
    ac.RulesW.CompileAll(ac.RulesW)
end

local function RefreshContexts(ac, changed, rebuildCache)
    for _, context in ipairs(contexts) do
        if changed[context.key] then
            if rebuildCache then
                integration.TimePhase("AutoCategory cacheInitBag " .. context.key, ac.cacheInitBag, context.bagType())
            end
            -- Hidden inventories are only marked dirty by ZOS and rebuild when next shown; forcing them re-sorts every bag.
            integration.TimePhase("AutoCategory RefreshList " .. context.key, ac.RefreshList,
                context.inventoryType(), false)
        end
    end
end

local function RemoveOwnedAssignments(refresh)
    local ac = AutoCategory
    CheckExternalShape(ac)
    if not CheckActiveAssignments(ac, true) then return end
    local changed = {}
    for _, context in ipairs(contexts) do
        local bag = ac.saved.bags[context.bagType()]
        for index = #bag.rules, 1, -1 do
            if bag.rules[index].icOwned == true then
                table.remove(bag.rules, index)
                changed[context.key] = true
            end
        end
    end
    if refresh then RefreshContexts(ac, changed, true) end
end

-- Debug Mode raises the failure from the next frame so the failing caller still gets its normal false result.
local function RaiseDebugFailure(message, traceback)
    -- Saved-variable migration can disable the integration before accountWide (and its Debug Mode flag) loads.
    if this.accountWide == nil or this.accountWide.debugEnabled ~= true then return end
    local report = "[InventoryCompanion] AutoCategory integration was disabled by this failure (Debug Mode report):\n"
        .. (traceback or debug.traceback(message, 3))
    integration.lastFailureReport = report
    EVENT_MANAGER:RegisterForUpdate("InventoryCompanion_AutoCategoryFailure", 0, function()
        EVENT_MANAGER:UnregisterForUpdate("InventoryCompanion_AutoCategoryFailure")
        error(report, 0)
    end)
end

function integration.Fail(failure, traceback)
    if integration.IsFaulted() then return end
    this.autoCategoryFailure = tostring(failure)
    RaiseDebugFailure(this.autoCategoryFailure, traceback)
    pendingGeneration = pendingGeneration + 1
    reconciling = false
    status = {
        state = "error",
        message = "AutoCategory integration disabled for this session: " .. this.autoCategoryFailure
            .. " Other Inventory Companion features remain available. Correct the problem and /reloadui.",
    }
    d("[InventoryCompanion] WARNING: " .. status.message)
    if AutoCategory ~= nil then
        local ok, cleanupFailure = pcall(RemoveOwnedAssignments, AutoCategory.Inited == true)
        if not ok then
            d("[InventoryCompanion] WARNING: AutoCategory assignment cleanup also failed: " .. tostring(cleanupFailure))
        end
    end
    if this.state ~= nil and this.state.isLoaded then
        local ok, refreshFailure = pcall(this.RefreshAutoCategoryUI)
        if not ok then
            d("[InventoryCompanion] WARNING: AutoCategory UI refresh also failed: " .. tostring(refreshFailure))
        end
    end
end

function integration.PreflightSavedDataCleanup()
    if AutoCategory == nil then return nil end
    CheckExternalShape(AutoCategory)
    local removals = {}
    for _, profileName in ipairs({ "acctSaved", "charSaved" }) do
        local profile = AutoCategory[profileName]
        assert(type(profile.bags) == "table",
            "AutoCategory " .. profileName .. " bag assignments are unavailable; no cleanup was performed")
        for _, context in ipairs(contexts) do
            local bag = profile.bags[context.bagType()]
            assert(type(bag) == "table" and type(bag.rules) == "table",
                "AutoCategory " .. profileName .. " assignments are unavailable for " .. context.title
                    .. "; no cleanup was performed")
            for index, assignment in ipairs(bag.rules) do
                assert(type(assignment) == "table", "AutoCategory assignment is malformed; no cleanup was performed")
                if assignment.icOwned == true then
                    removals[#removals + 1] = {
                        profile = profile,
                        rules = bag.rules,
                        index = index,
                        assignment = assignment,
                        context = context,
                    }
                end
            end
        end
    end
    return removals
end

function integration.ApplySavedDataCleanup(removals)
    assert(type(removals) == "table", "AutoCategory cleanup preflight is required")
    local byRules, changedActive, count = {}, {}, 0
    for _, removal in ipairs(removals) do
        local current = removal.rules[removal.index]
        assert(current == removal.assignment,
            "AutoCategory assignments changed after cleanup preflight; no cleanup was applied")
        byRules[removal.rules] = byRules[removal.rules] or {}
        byRules[removal.rules][#byRules[removal.rules] + 1] = removal
    end
    for rules, entries in pairs(byRules) do
        table.sort(entries, function(left, right) return left.index > right.index end)
        for _, removal in ipairs(entries) do
            assert(rules[removal.index] == removal.assignment,
                "AutoCategory assignments changed during cleanup")
            table.remove(rules, removal.index)
            count = count + 1
            if removal.profile.bags == AutoCategory.saved.bags then
                changedActive[removal.context.key] = true
            end
        end
    end
    if AutoCategory.Inited == true then RefreshContexts(AutoCategory, changedActive, true) end
    SetStatus("disabled", "AutoCategory integration data was cleared for the selected Inventory Companion account.")
    return count
end

local function ScheduleReconcile(reason, refreshOnly)
    if AutoCategory == nil or status.state == "absent" or not this.GetAutoCategoryState().enabled then return end
    pendingGeneration = pendingGeneration + 1
    local generation = pendingGeneration
    zo_callLater(function() integration.Run(function()
        if generation ~= pendingGeneration or not this.GetAutoCategoryState().enabled then return end
        if AutoCategory.Inited ~= true then return end
        if refreshOnly then
            local changed = {}
            for _, context in ipairs(contexts) do changed[context.key] = true end
            RefreshContexts(AutoCategory, changed, false)
        else
            integration.ProjectAutoCategory()
        end
    end) end, 100)
end

function integration.OnRuleMutation(kind, ruleKey)
    if AutoCategory == nil or status.state == "absent" then return end
    if not this.GetAutoCategoryState().enabled then return end
    if kind == "patterns" then
        local rule = GetRuntimeRules()[ruleKey]
        assert(rule ~= nil, "Pattern mutation references an unknown Inventory Companion group: "
            .. tostring(ruleKey))
        if not rule.autoCategoryEnabled then return end
    end
    if kind == "participation" then
        integration.ProjectAutoCategory()
        return
    end
    ScheduleReconcile(kind, kind == "patterns")
end

function integration.OnProfileChanged()
    pendingGeneration = pendingGeneration + 1
    if AutoCategory == nil or status.state == "absent" then return end
    if this.GetAutoCategoryState().enabled then
        ScheduleReconcile("profile", false)
    else
        RemoveOwnedAssignments(AutoCategory.Inited == true)
        SetStatus("disabled", "AutoCategory integration is disabled for the selected Inventory Companion profile.")
    end
end

function integration.OnEnablementChanged(enabled)
    assert(type(enabled) == "boolean", "AutoCategory enablement must be boolean")
    pendingGeneration = pendingGeneration + 1
    if AutoCategory == nil or status.state == "absent" then
        SetStatus("absent", "AutoCategory is not loaded; saved integration choices are preserved.")
        return
    end
    if enabled then
        InstallExternalHooks()
        ScheduleReconcile("enabled", false)
    else
        RemoveOwnedAssignments(AutoCategory.Inited == true)
        SetStatus("disabled", "AutoCategory integration is disabled for this Inventory Companion profile.")
    end
end

InstallExternalHooks = function()
    if hooksInstalled then return end
    local ac = AutoCategory
    assert(type(ac) == "table" and type(ac.UpdateCurrentSavedVars) == "function"
        and type(ac.cacheInitBag) == "function" and type(ac.cacheInitialize) == "function",
        "AutoCategory lifecycle hook targets are unavailable")
    assert(type(ZO_PostHook) == "function", "ESO post-hook API is unavailable")
    ZO_PostHook(ac, "UpdateCurrentSavedVars", function() integration.Run(function()
        if not reconciling then integration.OnProfileChanged() end
    end) end)
    ZO_PostHook(ac, "cacheInitBag", function() integration.Run(function()
        if not reconciling and this.GetAutoCategoryState().enabled then ScheduleReconcile("external-heading-edit", false) end
    end) end)
    ZO_PostHook(ac, "cacheInitialize", function() integration.Run(function()
        if not reconciling and this.GetAutoCategoryState().enabled then ScheduleReconcile("external-heading-edit", false) end
    end) end)
    hooksInstalled = true
end

local function RegisterPlugin()
    local ac = AutoCategory
    if ac == nil then
        SetStatus("absent", "AutoCategory is not loaded; saved integration choices are preserved.")
        return false
    end
    local ok, failure = pcall(CheckExternalShape, ac)
    if not ok then
        integration.Fail(failure)
        return false
    end
    if ac.Inited == true then
        integration.Fail("AutoCategory initialized before Inventory Companion could register its plugin.")
        return false
    end
    local definitions = BuildDefinitions()
    local collisionFree, collision = CheckDefinitionCollision(ac, definitions)
    if not collisionFree then
        integration.Fail(collision)
        return false
    end
    if ac.Plugins[pluginName] ~= nil then
        integration.Fail("AutoCategory plugin name is already registered.")
        return false
    end
    ac.RegisterPlugin(pluginName, function() integration.Run(function()
        local function MatchesRule(ruleKey)
            local rules = GetRuntimeRules()
            local rule = rules[ruleKey]
            assert(rule ~= nil, "Registered AutoCategory expression references unknown Inventory Companion group: "
                .. tostring(ruleKey))
            if not this.GetAutoCategoryState().enabled or not rule.autoCategoryEnabled then return false end
            assert(type(ac.checkingItemLink) == "string", "AutoCategory checkingItemLink must be a string")
            return this.ItemMatchesRuntimeRule(ac.checkingItemLink, rule)
        end
        ac.AddRuleFunc(predicateName, function(ruleKey)
            return integration.Run(MatchesRule, ruleKey) == true
        end)
        if this.GetAutoCategoryState().enabled then
            -- AutoCategory sets Inited synchronously after plugin initializers, before this deferred call runs.
            ScheduleReconcile("autocategory-initialized", false)
        else
            RemoveOwnedAssignments(false)
        end
    end) end, definitions)
    registeredPlugin = ac.Plugins[pluginName]
    assert(registeredPlugin and registeredPlugin.predef == definitions,
        "AutoCategory did not retain Inventory Companion's plugin definitions")
    local enabled = this.GetAutoCategoryState().enabled
    SetStatus(enabled and "pending" or "disabled",
        enabled and "AutoCategory plugin is registered; integration will activate after AutoCategory initializes."
            or "AutoCategory integration is disabled for this Inventory Companion profile.")
    if enabled then InstallExternalHooks() end
    return true
end

function integration.Initialize()
    if AutoCategory == nil then
        SetStatus("absent", "AutoCategory is not loaded; saved integration choices are preserved.")
        return
    end
    RegisterPlugin()
end

local projectedOrders = setmetatable({}, { __mode = "k" })
local renameHookInstalled = false

local function CopySequence(sequence)
    local copy = {}
    for index, value in ipairs(sequence) do copy[index] = value end
    return copy
end

local function SameSequence(left, right)
    if #left ~= #right then return false end
    for index = 1, #left do
        if left[index] ~= right[index] then return false end
    end
    return true
end

local function GetManagedRuleKey(assignment, definitionsByName)
    if assignment.icOwned ~= true then return nil end
    if assignment.icRuleKey ~= nil then
        assert(type(assignment.icRuleKey) == "string" and assignment.icRuleKey ~= "",
            "AutoCategory managed assignment has an invalid IC rule identity")
        return assignment.icRuleKey
    end
    local definition = definitionsByName[assignment.name]
    assert(definition and definition.icRuleKey,
        "AutoCategory managed assignment cannot be mapped to an IC group: " .. tostring(assignment.name))
    return definition.icRuleKey
end

local function SortAssignments(entries, mode)
    table.sort(entries, function(left, right)
        if mode == "display" then
            local leftKey = string.format("%04d%s", 1000 - left.assignment.showpriority, left.assignment.name)
            local rightKey = string.format("%04d%s", 1000 - right.assignment.showpriority, right.assignment.name)
            return leftKey < rightKey
        end
        local leftPriority, rightPriority = left.assignment.runpriority, right.assignment.runpriority
        if leftPriority ~= rightPriority then return leftPriority > rightPriority end
        return left.assignment.name < right.assignment.name
    end)
end

local function BuildContextModel(context, definitions, rules)
    local ac = AutoCategory
    local bag = ac.saved.bags[context.bagType()]
    local definitionsByName, definitionsByKey = {}, {}
    for _, definition in ipairs(definitions) do
        definitionsByName[definition.name] = definition
        definitionsByKey[definition.icRuleKey] = definition
    end
    local entries, members, actualAssignments, nativeNames = {}, {}, {}, {}
    for _, assignment in ipairs(bag.rules) do
        assert(type(assignment) == "table" and type(assignment.name) == "string" and assignment.name ~= "",
            "AutoCategory assignment is malformed in " .. context.title)
        assert(type(assignment.runpriority) == "number" and assignment.runpriority == assignment.runpriority
            and math.abs(assignment.runpriority) < math.huge,
            "AutoCategory run priority is invalid in " .. context.title .. ": " .. assignment.name)
        assert(type(assignment.showpriority) == "number" and assignment.showpriority == assignment.showpriority
            and math.abs(assignment.showpriority) < math.huge,
            "AutoCategory display priority is invalid in " .. context.title .. ": " .. assignment.name)
        local ruleKey = GetManagedRuleKey(assignment, definitionsByName)
        local reference
        if ruleKey then
            assert(definitionsByKey[ruleKey] ~= nil,
                "AutoCategory assignment references an unavailable IC group: " .. ruleKey)
            reference = "ic:" .. ruleKey
            assert(actualAssignments[reference] == nil,
                "AutoCategory has duplicate managed assignments for " .. reference .. " in " .. context.title)
            actualAssignments[reference] = assignment
            local rule = rules[ruleKey]
            assert(rule ~= nil, "AutoCategory assignment references an unknown IC group: " .. ruleKey)
            if rule.autoCategoryEnabled then
                members[reference] = { reference = reference, ruleKey = ruleKey, assignment = assignment }
            end
        else
            assert(nativeNames[assignment.name] == nil,
                "AutoCategory has duplicate native assignments named '" .. assignment.name .. "' in " .. context.title)
            nativeNames[assignment.name] = assignment
            reference = "ac:" .. assignment.name
            members[reference] = { reference = reference, name = assignment.name, assignment = assignment }
        end
        entries[#entries + 1] = {
            reference = reference,
            assignment = assignment,
        }
    end
    for ruleKey, rule in pairs(rules) do
        if IsOrdinaryRule(ruleKey, rule) and rule.autoCategoryEnabled then
            local reference = "ic:" .. ruleKey
            if members[reference] == nil then
                members[reference] = {
                    reference = reference,
                    ruleKey = ruleKey,
                    assignment = { name = definitionsByKey[ruleKey].name, runpriority = 0, showpriority = 0 },
                }
            end
        end
    end
    for _, mode in ipairs({ "display", "matching" }) do
        local sorted = {}
        for _, entry in ipairs(entries) do
            if members[entry.reference] then sorted[#sorted + 1] = entry end
        end
        SortAssignments(sorted, mode)
        local sequence = {}
        for index, entry in ipairs(sorted) do sequence[index] = entry.reference end
        entries[mode] = sequence
    end
    return { entries = entries, members = members, definitions = definitionsByKey }
end

local function FilterToMembers(sequence, members)
    local result, seen = {}, {}
    for _, reference in ipairs(sequence) do
        if members[reference] and not seen[reference] then
            result[#result + 1] = reference
            seen[reference] = true
        end
    end
    return result, seen
end

local function MergeObservedReferences(saved, observed, members)
    local result, present = FilterToMembers(saved, members)
    for index, reference in ipairs(observed) do
        if members[reference] and not present[reference] then
            local insertion
            for nextIndex = index + 1, #observed do
                for resultIndex, existing in ipairs(result) do
                    if existing == observed[nextIndex] then insertion = resultIndex; break end
                end
                if insertion then break end
            end
            if insertion then
                table.insert(result, insertion, reference)
            else
                local previous
                for previousIndex = index - 1, 1, -1 do
                    for resultIndex, existing in ipairs(result) do
                        if existing == observed[previousIndex] then previous = resultIndex; break end
                    end
                    if previous then break end
                end
                table.insert(result, previous and previous + 1 or #result + 1, reference)
            end
            present[reference] = true
        end
    end
    for reference in pairs(members) do
        if not present[reference] then result[#result + 1] = reference end
    end
    return result
end

local function SnapshotMatches(snapshot, observed, members)
    if snapshot == nil then return false end
    local observedSet = {}
    for _, reference in ipairs(observed) do observedSet[reference] = true end
    local expected = {}
    for _, reference in ipairs(snapshot) do
        if members[reference] and observedSet[reference] then expected[#expected + 1] = reference end
    end
    return SameSequence(expected, observed)
end

local function ValidateCompleteSequence(sequence, members, context, mode)
    assert(type(sequence) == "table", context .. " " .. mode .. " order must be a list")
    local seen = {}
    for index, reference in ipairs(sequence) do
        assert(type(reference) == "string" and members[reference],
            context .. " " .. mode .. " order has an unavailable reference at position " .. tostring(index))
        assert(not seen[reference], context .. " " .. mode .. " order repeats " .. reference)
        seen[reference] = true
    end
    local memberCount = 0
    for reference in pairs(members) do
        memberCount = memberCount + 1
        assert(seen[reference], context .. " " .. mode .. " order is missing " .. reference)
    end
    assert(#sequence == memberCount, context .. " " .. mode .. " order is not a complete permutation")
    assert(memberCount <= 999,
        context .. " has " .. tostring(memberCount) .. " assignments; AutoCategory supports at most 999 per order")
end

local function GetCurrentOrderData()
    local profile = this.GetAutoCategoryProfile()
    local order = profile.autoCategoryOrder
    assert(type(order) == "table" and type(order.contexts) == "table",
        "Schema-5 AutoCategory context orders are unavailable")
    return profile, order
end

local function BuildStartingSequence(model, mode, rules, preset)
    local sequence, groups = {}, {}
    for _, reference in ipairs(model.entries[mode]) do
        if reference:sub(1, 3) == "ac:" then sequence[#sequence + 1] = reference end
    end
    for _, ruleKey in ipairs(GetOrderedRuleKeys(rules)) do
        if rules[ruleKey].autoCategoryEnabled then groups[#groups + 1] = "ic:" .. ruleKey end
    end
    local insertion = #sequence + 1
    if preset == "ic" then
        insertion = 1
        assert(SI_AC_DEFAULT_CATEGORY_NEW ~= nil, "AutoCategory's default New category string is unavailable")
        local newName = GetString(SI_AC_DEFAULT_CATEGORY_NEW)
        assert(type(newName) == "string" and newName ~= "",
            "AutoCategory's default New category name is unavailable")
        local newReference = "ac:" .. newName
        for index, reference in ipairs(sequence) do
            if reference == newReference and model.members[reference].assignment.isHidden ~= true then
                insertion = index + 1
                break
            end
        end
    end
    for index, reference in ipairs(groups) do table.insert(sequence, insertion + index - 1, reference) end
    return sequence
end

local function BuildPlans(orderOverride, setupRules, preset)
    local ac = AutoCategory
    CheckExternalShape(ac)
    assert(ac.Inited == true, "AutoCategory must finish initialization before projection")
    CheckActiveAssignments(ac)
    assert(setupRules ~= nil or this.GetAutoCategoryState().enabled,
        "Cannot project while AutoCategory integration is disabled")
    local rules = setupRules or GetRuntimeRules()
    local definitions = BuildDefinitions(rules)
    local collisionFree, collision = CheckDefinitionCollision(ac, definitions)
    assert(collisionFree, collision)
    local profile, storedOrder = GetCurrentOrderData()
    local snapshotByContext = projectedOrders[ac.saved]
    local plans, reconciled = {}, { contexts = {} }
    for _, context in ipairs(contexts) do
        local model = BuildContextModel(context, definitions, rules)
        local savedContext = storedOrder.contexts[context.key]
        assert(type(savedContext) == "table", "Missing saved AutoCategory context: " .. context.key)
        local override = orderOverride and orderOverride[context.key]
        local priorSnapshot = snapshotByContext and snapshotByContext[context.key]
        local resolved = {}
        for _, mode in ipairs({ "display", "matching" }) do
            local observed = model.entries[mode]
            local savedSequence = savedContext[mode]
            assert(type(savedSequence) == "table", "Missing saved AutoCategory " .. mode .. " order: " .. context.key)
            local sequence
            if preset then
                sequence = BuildStartingSequence(model, mode, rules, preset)
            elseif override and override[mode] ~= nil then
                sequence = CopySequence(override[mode])
            elseif priorSnapshot and SnapshotMatches(priorSnapshot[mode], observed, model.members) then
                sequence = MergeObservedReferences(savedSequence, observed, model.members)
            else
                sequence = MergeObservedReferences(observed, observed, model.members)
            end
            ValidateCompleteSequence(sequence, model.members, context.title, mode)
            resolved[mode] = sequence
        end
        local planned = {}
        for _, mode in ipairs({ "display", "matching" }) do
            local field = mode == "display" and "showpriority" or "runpriority"
            for index, reference in ipairs(resolved[mode]) do
                local entry = model.members[reference]
                local target = planned[reference]
                if target == nil then
                    target = {
                        reference = reference, ruleKey = entry.ruleKey, name = entry.name,
                        assignment = entry.assignment, isManaged = reference:sub(1, 3) == "ic:",
                    }
                    if target.isManaged then target.name = model.definitions[entry.ruleKey].name end
                    planned[reference] = target
                end
                target[field] = 1001 - index
            end
        end
        plans[context.key] = { assignments = planned, orders = resolved }
        reconciled.contexts[context.key] = resolved
    end
    return plans, reconciled, profile
end

local function ProjectPlans(plans)
    local ac = AutoCategory
    integration.TimePhase("SyncDefinitions", SyncDefinitions, ac, integration.TimePhase("BuildDefinitions", BuildDefinitions))
    local changed = {}
    reconciling = true
    local ok, failure = xpcall(function()
        for _, context in ipairs(contexts) do
            local bag = ac.saved.bags[context.bagType()]
            local plan = plans[context.key]
            local managedByKey, wantedManaged = {}, {}
            for _, assignment in ipairs(bag.rules) do
                if assignment.icOwned == true then
                    local key = GetManagedRuleKey(assignment, {})
                    managedByKey[key] = assignment
                end
            end
            for _, target in pairs(plan.assignments) do
                if target.isManaged then wantedManaged[target.ruleKey] = true end
            end
            for index = #bag.rules, 1, -1 do
                local assignment = bag.rules[index]
                if assignment.icOwned == true then
                    local key = GetManagedRuleKey(assignment, {})
                    if not wantedManaged[key] then
                        table.remove(bag.rules, index)
                        changed[context.key] = true
                    end
                end
            end
            local nativeByName = {}
            for _, assignment in ipairs(bag.rules) do
                if assignment.icOwned ~= true then nativeByName[assignment.name] = assignment end
            end
            for _, target in pairs(plan.assignments) do
                local assignment
                if target.isManaged then
                    assignment = managedByKey[target.ruleKey]
                    if assignment == nil then
                        assignment = { name = target.name, icOwned = true, icRuleKey = target.ruleKey }
                        bag.rules[#bag.rules + 1] = assignment
                        managedByKey[target.ruleKey] = assignment
                        changed[context.key] = true
                    end
                    if assignment.name ~= target.name then
                        assignment.name = target.name
                        changed[context.key] = true
                    end
                    if assignment.icRuleKey ~= target.ruleKey then
                        assignment.icRuleKey = target.ruleKey
                        changed[context.key] = true
                    end
                else
                    assignment = nativeByName[target.name]
                    assert(assignment ~= nil, "AutoCategory native assignment disappeared after preflight: " .. target.name)
                end
                if assignment.runpriority ~= target.runpriority then
                    assignment.runpriority = target.runpriority
                    changed[context.key] = true
                end
                if assignment.showpriority ~= target.showpriority then
                    assignment.showpriority = target.showpriority
                    changed[context.key] = true
                end
            end
        end
        RefreshContexts(ac, changed, true)
    end, function(errorValue)
        reconciling = false
        return errorValue
    end)
    reconciling = false
    if not ok then error(failure) end
    local snapshots = {}
    for _, context in ipairs(contexts) do
        snapshots[context.key] = {
            display = CopySequence(plans[context.key].orders.display),
            matching = CopySequence(plans[context.key].orders.matching),
        }
    end
    projectedOrders[ac.saved] = snapshots
    return changed
end

local function ReportProjectionFailure(failure)
    integration.Fail(failure)
    return false
end

function integration.PreflightAutoCategory(orderOverride)
    if integration.IsFaulted() then return nil, this.autoCategoryFailure end
    local ok, plans, reconciled, profile = pcall(integration.TimePhase, "BuildPlans", BuildPlans, orderOverride)
    if not ok then
        integration.Fail(plans)
        return nil, tostring(plans)
    end
    return { plans = plans, order = reconciled, profile = profile }
end

function integration.ProjectAutoCategory(preflight)
    local prepared = preflight
    if prepared == nil then
        local failure
        prepared, failure = integration.PreflightAutoCategory()
        if prepared == nil then return ReportProjectionFailure(failure) end
    end

    local changed = integration.TimePhase("ProjectPlans", ProjectPlans, prepared.plans)
    prepared.profile.autoCategoryOrder = prepared.order
    SetStatus("available", "AutoCategory display and matching orders are synchronized for the selected context.")
    return changed
end

function integration.CompleteInitialSetup(preset, profile)
    assert(preset == "ic" or preset == "ac", "Unknown AutoCategory starting preset")
    assert(profile == this.GetAutoCategoryProfile(), "AutoCategory setup profile changed while the dialog was open")
    assert(profile.autoCategorySetupComplete ~= true, "AutoCategory initial setup is already complete")
    assert(integration.IsAvailable(), "AutoCategory integration is unavailable")
    local rules, participation = {}, {}
    for ruleKey, rule in pairs(GetRuntimeRules()) do
        local copy = {}
        for key, value in pairs(rule) do copy[key] = value end
        rules[ruleKey] = copy
        if IsOrdinaryRule(ruleKey, rule) then
            local display = this.ResolveItemDisplay(rule.display)
            copy.autoCategoryEnabled = rule.autoCategoryEnabled or display.show or display.notify
            if copy.autoCategoryEnabled then participation[#participation + 1] = ruleKey end
        end
    end
    -- Check every context before publishing participation, enablement, or orders.
    local plans, order = BuildPlans(nil, rules, preset)
    for _, ruleKey in ipairs(participation) do
        local saved = profile.trackedRules[ruleKey]
        if saved == nil then saved = {}; profile.trackedRules[ruleKey] = saved end
        saved.autoCategoryEnabled = true
    end
    this.InvalidateRuleCache()
    profile.autoCategoryIntegrationEnabled = true
    integration.ProjectAutoCategory({ plans = plans, order = order, profile = profile })
    if integration.IsFaulted() then return false end
    profile.autoCategorySetupComplete = true
    integration.OnEnablementChanged(true)
    this.RefreshAutoCategoryUI()
    return true
end

local setupDialogRegistered = false
function integration.ShowInitialSetup()
    assert(integration.IsAvailable(), "AutoCategory integration is unavailable")
    if not setupDialogRegistered then
        local function Choose(dialog, preset)
            if dialog.data.profile ~= this.GetAutoCategoryProfile() then
                d("[InventoryCompanion] AutoCategory setup cancelled because the selected item-list profile changed.")
                this.RefreshAutoCategoryUI()
                return
            end
            integration.CompleteInitialSetup(preset, dialog.data.profile)
        end
        ZO_Dialogs_RegisterCustomDialog("InventoryCompanion_AUTOCATEGORY_SETUP", {
            gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
            title = { text = "Set Up AutoCategory Integration" },
            mainText = { text = "Enable AutoCategory integration to manage category order in Inventory Companion "
                .. "and use your IC groups in your backpack, bank and other inventories.\n\n"
                .. "Where should IC groups appear among your existing AutoCategory categories? "
                .. "You can change this later in the group editor." },
            radioButtons = {
                { text = "Near the top (default)", data = "ic" },
                { text = "At the bottom", data = "ac" },
            },
            buttons = {
                { text = SI_DIALOG_CONFIRM, callback = function(dialog)
                    local selected = dialog.radioButtonGroup:GetClickedButton()
                    assert(selected ~= nil, "AutoCategory setup dialog has no selected arrangement")
                    Choose(dialog, selected.data)
                end },
                { text = SI_DIALOG_CANCEL, callback = function() this.RefreshAutoCategoryUI() end },
            },
            noChoiceCallback = function() this.RefreshAutoCategoryUI() end,
        })
        setupDialogRegistered = true
    end
    ZO_Dialogs_ShowDialog("InventoryCompanion_AUTOCATEGORY_SETUP", { profile = this.GetAutoCategoryProfile() })
    return false
end

function integration.ResolveAutoCategoryOrder(contextKey, options)
    assert(contextByKey[contextKey], "Unknown AutoCategory context: " .. tostring(contextKey))
    local mode = options and options.mode or "display"
    assert(mode == "display" or mode == "matching", "Unknown AutoCategory ordering mode: " .. tostring(mode))
    local _, order = GetCurrentOrderData()
    local sequence = order.contexts[contextKey][mode]
    local rules = GetRuntimeRules()
    -- The two mode lists only share membership after reconciliation, so the other list may lack a reference.
    local positions = { display = {}, matching = {} }
    for _, modeName in ipairs({ "display", "matching" }) do
        for index, reference in ipairs(order.contexts[contextKey][modeName]) do
            positions[modeName][reference] = index
        end
    end
    local rows = {}
    for index, reference in ipairs(sequence) do
        if reference:sub(1, 3) == "ic:" then
            local ruleKey = reference:sub(4)
            local rule = rules[ruleKey]
            assert(rule and IsOrdinaryRule(ruleKey, rule) and rule.autoCategoryEnabled,
                "Saved AutoCategory order references a nonparticipating IC group: " .. ruleKey)
            rows[#rows + 1] = {
                kind = "group", reference = reference, ruleKey = ruleKey,
                name = rule.displayName, participating = true, index = index,
                displayPosition = positions.display[reference], matchingPosition = positions.matching[reference],
            }
        else
            rows[#rows + 1] = {
                kind = "heading", reference = reference, name = reference:sub(4),
                index = index, hidden = false, scopeLabel = contextByKey[contextKey].title,
                displayPosition = positions.display[reference], matchingPosition = positions.matching[reference],
            }
        end
    end
    local nonparticipants = {}
    for ruleKey, rule in pairs(rules) do
        if IsOrdinaryRule(ruleKey, rule) and not rule.autoCategoryEnabled then
            nonparticipants[#nonparticipants + 1] = { ruleKey = ruleKey, rule = rule }
        end
    end
    table.sort(nonparticipants, function(left, right) return left.ruleKey < right.ruleKey end)
    for _, entry in ipairs(nonparticipants) do
        rows[#rows + 1] = {
            kind = "group", reference = "ic:" .. entry.ruleKey, ruleKey = entry.ruleKey,
            name = entry.rule.displayName, participating = false, index = #rows + 1,
            orderCount = #sequence,
        }
    end
    for _, row in ipairs(rows) do row.orderCount = row.orderCount or #sequence end
    return rows
end

local function ApplyOrderOverride(orderOverride)
    local prepared, failure = integration.PreflightAutoCategory(orderOverride)
    if prepared == nil then return ReportProjectionFailure(failure) end
    return integration.ProjectAutoCategory(prepared) ~= false
end

function integration.GetMovedSequence(sequence, selection, movement)
    assert(movement == "top" or movement == "bottom"
        or movement == -1 or movement == 1 or movement == -5 or movement == 5
        or movement == -10 or movement == 10, "Unknown AutoCategory movement")
    local present = {}
    for _, reference in ipairs(sequence) do present[reference] = true end
    for reference, selected in pairs(selection) do
        assert(selected == true and present[reference],
            "AutoCategory selection references a missing assignment: " .. tostring(reference))
    end
    local result
    if movement == "top" or movement == "bottom" then
        result = {}
        for _, selected in ipairs({ movement == "top", movement ~= "top" }) do
            for _, reference in ipairs(sequence) do
                if (selection[reference] == true) == selected then result[#result + 1] = reference end
            end
        end
    else
        result = CopySequence(sequence)
        local first, last, step = 2, #result, 1
        if movement > 0 then first, last, step = #result - 1, 1, -1 end
        for _ = 1, math.abs(movement) do
            for index = first, last, step do
                local neighbour = index - step
                if selection[result[index]] and not selection[result[neighbour]] then
                    result[index], result[neighbour] = result[neighbour], result[index]
                end
            end
        end
    end
    for index, reference in ipairs(result) do
        if reference ~= sequence[index] then return result, true end
    end
    return result, false
end

function integration.MoveEntries(selection, contextKey, mode, movement)
    assert(contextByKey[contextKey], "Unknown AutoCategory context: " .. tostring(contextKey))
    assert(mode == "display" or mode == "matching", "Unknown AutoCategory ordering mode: " .. tostring(mode))
    local _, order = GetCurrentOrderData()
    local sequence, changed = integration.GetMovedSequence(order.contexts[contextKey][mode], selection, movement)
    if not changed then return false end
    return ApplyOrderOverride({ [contextKey] = { [mode] = sequence } })
end

function integration.MoveEntry(reference, contextKey, mode, direction)
    assert(direction == -1 or direction == 1, "AutoCategory move direction must be -1 or 1")
    return integration.MoveEntries({ [reference] = true }, contextKey, mode, direction)
end

function integration.UseOtherOrder(contextKey, activeMode)
    assert(contextByKey[contextKey], "Unknown AutoCategory context: " .. tostring(contextKey))
    assert(activeMode == "display" or activeMode == "matching", "Unknown AutoCategory ordering mode")
    local _, order = GetCurrentOrderData()
    local sourceMode = activeMode == "display" and "matching" or "display"
    return ApplyOrderOverride({
        [contextKey] = { [activeMode] = CopySequence(order.contexts[contextKey][sourceMode]) },
    })
end

local function MergeDestinationSlots(source, destination)
    local destinationSet, sourceSet, shared, result = {}, {}, {}, {}
    for _, reference in ipairs(destination) do destinationSet[reference] = true end
    for _, reference in ipairs(source) do
        sourceSet[reference] = true
        if destinationSet[reference] then shared[#shared + 1] = reference end
    end
    local sharedIndex = 1
    for index, reference in ipairs(destination) do
        if not sourceSet[reference] then
            result[index] = reference
        else
            result[index] = shared[sharedIndex]
            sharedIndex = sharedIndex + 1
        end
    end
    assert(sharedIndex == #shared + 1, "Cross-context copy lost a shared AutoCategory reference")
    return result
end

function integration.CopyBothOrders(sourceContext, destinationContext)
    assert(contextByKey[sourceContext] and contextByKey[destinationContext],
        "Unknown AutoCategory copy context")
    if sourceContext == destinationContext then return false end
    local _, order = GetCurrentOrderData()
    local source, destination = order.contexts[sourceContext], order.contexts[destinationContext]
    local override = { [destinationContext] = {} }
    for _, mode in ipairs({ "display", "matching" }) do
        override[destinationContext][mode] = MergeDestinationSlots(source[mode], destination[mode])
    end
    return ApplyOrderOverride(override)
end

local originalInstallExternalHooks = InstallExternalHooks
InstallExternalHooks = function()
    originalInstallExternalHooks()
    if renameHookInstalled then return end
    local ac = AutoCategory
    assert(type(ac.renameBagRule) == "function", "AutoCategory renameBagRule hook target is unavailable")
    ZO_PostHook(ac, "renameBagRule", function(oldName, newName) integration.Run(function()
        if reconciling or ac.Inited ~= true then return end
        assert(type(oldName) == "string" and oldName ~= "" and type(newName) == "string" and newName ~= "",
            "AutoCategory rename hook supplied invalid names")
        local profile = this.GetAutoCategoryProfile()
        local oldReference, newReference = "ac:" .. oldName, "ac:" .. newName
        for _, context in ipairs(contexts) do
            local lists = profile.autoCategoryOrder.contexts[context.key]
            for _, mode in ipairs({ "display", "matching" }) do
                local seen = {}
                for index, reference in ipairs(lists[mode]) do
                    if reference == oldReference then lists[mode][index] = newReference end
                    assert(not seen[lists[mode][index]],
                        "AutoCategory rename creates duplicate order reference: " .. newReference)
                    seen[lists[mode][index]] = true
                end
            end
        end
        local snapshots = projectedOrders[ac.saved]
        if snapshots then
            for _, context in ipairs(contexts) do
                for _, mode in ipairs({ "display", "matching" }) do
                    for index, reference in ipairs(snapshots[context.key][mode]) do
                        if reference == oldReference then snapshots[context.key][mode][index] = newReference end
                    end
                end
            end
        end
        ScheduleReconcile("native-category-renamed", false)
    end) end)
    renameHookInstalled = true
end

for _, name in ipairs({
    "Initialize", "OnRuleMutation", "OnProfileChanged", "OnEnablementChanged",
    "ProjectAutoCategory", "MoveEntry", "MoveEntries", "UseOtherOrder", "CopyBothOrders", "GetHeadingDetails",
    "CompleteInitialSetup", "ShowInitialSetup",
}) do
    local operation = integration[name]
    integration[name] = function(...) return integration.TimePhase(name, integration.Run, operation, ...) end
end
