local this = InventoryCompanion
local integration = {}
this.AutoCategoryIntegration = integration

local pluginName = "Inventory Companion"
local ruleTag = "Inventory Companion"
local predicateName = "ic_group"
local iconMarkup = "|t18:18:EsoUI/Art/Buttons/plus_up.dds|t "
local topAnchor = "@top"
local bottomAnchor = "@bottom"
local defaultNewAnchor = "@default-new"

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
    status = { state = state, message = message }
    if this.RefreshAutoCategoryUI then this.RefreshAutoCategoryUI() end
end

function integration.GetStatus()
    return status.state, status.message
end

function integration.IsAvailable()
    -- An unsupported external layout must stay editable so placements can be changed or integration disabled.
    return status.state == "available" or status.state == "disabled" or status.state == "unsupported"
end

function integration.IsEditorActive()
    return integration.IsAvailable() and this.GetAutoCategoryState().enabled
end

function integration.GetContexts()
    local result = { { key = "master", title = "Master (all contexts)" } }
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

function integration.ChoosePreset(reset)
    assert(type(reset) == "boolean", "Preset chooser mode must be boolean")
    ZO_Dialogs_ShowDialog("INVENTORYCOMPANION_AUTOCATEGORY_PRESET", { reset = reset })
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
        if a.autoCategoryRank ~= b.autoCategoryRank then
            if a.autoCategoryRank == nil then return false end
            if b.autoCategoryRank == nil then return true end
            return a.autoCategoryRank < b.autoCategoryRank
        end
        local nameA, nameB = a.displayName:lower(), b.displayName:lower()
        if nameA ~= nameB then return nameA < nameB end
        return left < right
    end)
    return keys
end

local function GetCategoryName(rule)
    local rank = rule.autoCategoryRank
    if rank == nil then return iconMarkup .. rule.displayName end
    assert(rank == math.floor(rank) and rank <= 0xFFFFFF,
        "AutoCategory rank cannot be represented by the approved category-name prefix: " .. tostring(rank))
    return "|c" .. string.format("%06X", rank) .. "|r" .. iconMarkup .. rule.displayName
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

local function BuildDefinitions()
    local rules = GetRuntimeRules()
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

local function GetNativeAssignments(context)
    local ac = AutoCategory
    local bag = ac.saved.bags[context.bagType()]
    local assignments = {}
    for _, assignment in ipairs(bag.rules) do
        if assignment.icOwned ~= true then
            assert(type(assignment.name) == "string" and assignment.name ~= "",
                "AutoCategory external assignment has an invalid name")
            assert(type(assignment.runpriority) == "number" and assignment.runpriority == assignment.runpriority
                and math.abs(assignment.runpriority) < math.huge,
                "AutoCategory external assignment has an invalid run priority")
            assert(type(assignment.showpriority) == "number" and assignment.showpriority == assignment.showpriority
                and math.abs(assignment.showpriority) < math.huge,
                "AutoCategory external assignment has an invalid show priority")
            assignments[#assignments + 1] = {
                name = assignment.name,
                runpriority = assignment.runpriority,
                showpriority = assignment.showpriority,
                isHidden = assignment.isHidden == true,
            }
        end
    end
    return assignments
end

local function SortRun(entries)
    table.sort(entries, function(a, b)
        if a.runpriority ~= b.runpriority then return a.runpriority > b.runpriority end
        return a.name < b.name
    end)
    return entries
end

local function SortShow(entries)
    table.sort(entries, function(a, b)
        if a.showpriority ~= b.showpriority then return a.showpriority > b.showpriority end
        return a.name < b.name
    end)
    return entries
end

local function HeadingId(name, ordinal, firstContext)
    return "heading:" .. string.format("%q", name) .. ":" .. tostring(ordinal) .. ":" .. firstContext
end

local function NativeHeadingSequence(context)
    local assignments = GetNativeAssignments(context)
    local sequence = {}
    for _, entry in ipairs(SortShow(assignments)) do
        sequence[#sequence + 1] = entry.name
    end
    return sequence, assignments
end

local function HasCycle(nodes, sequences)
    local edges, indegree, nodeCount = {}, {}, 0
    for node in pairs(nodes) do
        edges[node], indegree[node] = {}, 0
        nodeCount = nodeCount + 1
    end
    for _, sequence in pairs(sequences) do
        for index = 1, #sequence - 1 do
            local left, right = sequence[index], sequence[index + 1]
            if left ~= right and not edges[left][right] then
                edges[left][right] = true
                indegree[right] = indegree[right] + 1
            end
        end
    end
    local queue = {}
    for node, degree in pairs(indegree) do
        if degree == 0 then queue[#queue + 1] = node end
    end
    local visited = 0
    while #queue > 0 do
        local node = table.remove(queue)
        visited = visited + 1
        for target in pairs(edges[node]) do
            indegree[target] = indegree[target] - 1
            if indegree[target] == 0 then queue[#queue + 1] = target end
        end
    end
    return visited ~= nodeCount
end

local function BuildHeadingModel()
    local nodes, sequences, byContext = {}, {}, {}
    local candidates = {}
    local serial = 0
    for _, context in ipairs(contexts) do
        local names = NativeHeadingSequence(context)
        local sequence, ordinals = {}, {}
        for _, name in ipairs(names) do
            ordinals[name] = (ordinals[name] or 0) + 1
            local ordinal = ordinals[name]
            local candidateKey = name .. "\0" .. tostring(ordinal)
            local node
            for _, existing in ipairs(candidates[candidateKey] or {}) do
                if not existing.contexts[context.key] then
                    node = existing
                    sequence[#sequence + 1] = node
                    sequences[context.key] = sequence
                    if HasCycle(nodes, sequences) then
                        sequence[#sequence] = nil
                        sequences[context.key] = nil
                        node = nil
                    else
                        node.contexts[context.key] = true
                        break
                    end
                end
            end
            if node == nil then
                serial = serial + 1
                node = { name = name, ordinal = ordinal, serial = serial, contexts = { [context.key] = true } }
                nodes[node] = true
                sequence[#sequence + 1] = node
                sequences[context.key] = sequence
                candidates[candidateKey] = candidates[candidateKey] or {}
                candidates[candidateKey][#candidates[candidateKey] + 1] = node
            end
        end
        sequences[context.key] = sequence
        byContext[context.key] = {}
        for index, node in ipairs(sequence) do byContext[context.key][index] = node end
    end

    local ordered, used = {}, {}
    while #ordered < (function() local count = 0; for _ in pairs(nodes) do count = count + 1 end; return count end)() do
        local available = {}
        for node in pairs(nodes) do
            if not used[node] then
                local blocked = false
                for _, sequence in pairs(sequences) do
                    for index = 1, #sequence - 1 do
                        if sequence[index + 1] == node and not used[sequence[index]] then
                            blocked = true
                            break
                        end
                    end
                    if blocked then break end
                end
                if not blocked then available[#available + 1] = node end
            end
        end
        assert(#available > 0, "AutoCategory heading occurrence ordering contains a cycle")
        table.sort(available, function(a, b) return a.serial < b.serial end)
        local node = available[1]
        used[node] = true
        node.id = HeadingId(node.name, node.ordinal, (function()
            for _, context in ipairs(contexts) do
                if node.contexts[context.key] then return context.key end
            end
        end)())
        ordered[#ordered + 1] = node
    end
    return ordered, byContext
end

local function IsHeadingVisible(state, contextKey, occurrenceId)
    local order = state.order
    local visible = order.headingVisibility and order.headingVisibility[occurrenceId]
    local contextOverride = order.overrides and order.overrides[contextKey]
    local headingOverride = contextOverride and contextOverride.headings
        and contextOverride.headings[occurrenceId]
    if headingOverride ~= nil then visible = headingOverride end
    return visible ~= false
end

local function ResolveAnchor(anchor, contextKey, nodeById, sequence)
    if anchor == topAnchor then return nil end
    if anchor == bottomAnchor then return "bottom" end
    if anchor == defaultNewAnchor then
        local newName = GetString(SI_ITEMFILTERTYPE_NEW)
        for _, node in ipairs(sequence) do
            if node.name == newName and IsHeadingVisible(this.GetAutoCategoryState(), contextKey, node.id) then
                return node
            end
        end
        return nil
    end
    local node = nodeById[anchor]
    if node and node.contexts[contextKey] then return node end
    for index = #sequence, 1, -1 do
        if sequence[index].contexts[contextKey]
            and IsHeadingVisible(this.GetAutoCategoryState(), contextKey, sequence[index].id) then
            return sequence[index]
        end
    end
    return nil
end

local function GetRulePlacement(rule, contextKey)
    local placement = { anchor = rule.autoCategoryAnchor, rank = rule.autoCategoryRank }
    local overrides = rule.autoCategoryOverrides
    local override = overrides and overrides[contextKey]
    if override then
        if override.anchor ~= nil then placement.anchor = override.anchor end
        if override.rank ~= nil then placement.rank = override.rank end
    end
    return placement
end

local function GetMasterAnchorIndex(anchor, orderedNodes, nodeById)
    if anchor == topAnchor or anchor == defaultNewAnchor then return 0 end
    if anchor == bottomAnchor then return #orderedNodes + 1 end
    for index, node in ipairs(orderedNodes) do
        if node.id == anchor then return index end
    end
    return #orderedNodes + 1
end

local function ResolveRows(contextKey, options)
    local state = this.GetAutoCategoryState()
    local rules = GetRuntimeRules()
    local orderedNodes, byContext = BuildHeadingModel()
    local nodesById = {}
    for _, node in ipairs(orderedNodes) do nodesById[node.id] = node end
    local groups = {}
    for ruleKey, rule in pairs(rules) do
        if IsOrdinaryRule(ruleKey, rule) then
            local placement = GetRulePlacement(rule, contextKey)
            local participating = rule.autoCategoryEnabled == true
            if contextKey == "master" or participating then
                assert(not (participating and state.enabled)
                    or (placement.anchor ~= nil and placement.rank ~= nil),
                    "Participating AutoCategory group has no saved placement: " .. ruleKey)
                groups[#groups + 1] = {
                    kind = "group",
                    ruleKey = ruleKey,
                    name = rule.displayName,
                    participating = participating,
                    anchor = placement.anchor,
                    rank = placement.rank,
                    placementIndex = GetMasterAnchorIndex(placement.anchor, orderedNodes, nodesById),
                }
            end
        end
    end
    table.sort(groups, function(a, b)
        if a.placementIndex ~= b.placementIndex then return a.placementIndex < b.placementIndex end
        if a.rank == nil and b.rank == nil then return a.ruleKey < b.ruleKey end
        if a.rank == nil then return false end
        if b.rank == nil then return true end
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.ruleKey < b.ruleKey
    end)

    local output, groupsByAnchor = {}, {}
    local function IsUsable(node)
        if contextKey == "master" then
            for _, context in ipairs(contexts) do
                if node.contexts[context.key] and IsHeadingVisible(state, context.key, node.id) then return true end
            end
            return false
        end
        return node.contexts[contextKey] and IsHeadingVisible(state, contextKey, node.id)
    end
    local function ResolveGroupAnchor(group)
        if group.anchor == nil then return "@never-ordered" end
        if group.anchor == topAnchor then return nil end
        if group.anchor == bottomAnchor then return bottomAnchor end
        local anchorIndex = GetMasterAnchorIndex(group.anchor, orderedNodes, nodesById)
        if group.anchor == defaultNewAnchor then
            local newName = GetString(SI_ITEMFILTERTYPE_NEW)
            for _, node in ipairs(orderedNodes) do
                if node.name == newName and IsUsable(node) then return node.id end
            end
            return nil
        end
        local exact = nodesById[group.anchor]
        if exact and IsUsable(exact) then return exact.id end
        for index = math.min(anchorIndex - 1, #orderedNodes), 1, -1 do
            if IsUsable(orderedNodes[index]) then return orderedNodes[index].id end
        end
        return nil
    end
    for _, group in ipairs(groups) do
        group.resolvedAnchorId = ResolveGroupAnchor(group)
        local bucketKey = group.resolvedAnchorId or topAnchor
        groupsByAnchor[bucketKey] = groupsByAnchor[bucketKey] or {}
        groupsByAnchor[bucketKey][#groupsByAnchor[bucketKey] + 1] = group
    end
    for _, bucket in pairs(groupsByAnchor) do
        table.sort(bucket, function(a, b)
            if a.rank == nil and b.rank == nil then return a.ruleKey < b.ruleKey end
            if a.rank == nil then return false end
            if b.rank == nil then return true end
            if a.rank ~= b.rank then return a.rank < b.rank end
            return a.ruleKey < b.ruleKey
        end)
    end
    local function AppendGroups(anchorId)
        for _, group in ipairs(groupsByAnchor[anchorId or topAnchor] or {}) do
            output[#output + 1] = {
                kind = group.kind,
                ruleKey = group.ruleKey,
                name = group.name,
                participating = group.participating,
                anchor = group.anchor,
                rank = group.rank,
                resolvedAnchorId = group.resolvedAnchorId,
            }
        end
    end

    if contextKey == "master" then
        AppendGroups(nil)
        for _, node in ipairs(orderedNodes) do
            local visibleContexts, hiddenContexts = {}, {}
            for _, context in ipairs(contexts) do
                if node.contexts[context.key] then
                    if IsHeadingVisible(state, context.key, node.id) then
                        visibleContexts[#visibleContexts + 1] = context.title
                    else
                        hiddenContexts[#hiddenContexts + 1] = context.title
                    end
                end
            end
            if #visibleContexts > 0 or (options and options.showAllHeadings) then
                local scopeLabel = #visibleContexts > 0 and table.concat(visibleContexts, ", ") or "Hidden"
                if options and options.showAllHeadings and #hiddenContexts > 0 then
                    scopeLabel = scopeLabel .. "; hidden in " .. table.concat(hiddenContexts, ", ")
                end
                output[#output + 1] = {
                    kind = "heading",
                    occurrenceId = node.id,
                    name = node.name,
                    contexts = node.contexts,
                    scopeLabel = scopeLabel,
                    visibleContexts = visibleContexts,
                    hiddenContexts = hiddenContexts,
                }
            end
            AppendGroups(node.id)
        end
        AppendGroups(bottomAnchor)
        if options == nil or options.showNonparticipants ~= false then
            for _, ruleKey in ipairs(GetOrderedRuleKeys(rules)) do
                local rule = rules[ruleKey]
                if IsOrdinaryRule(ruleKey, rule) and not rule.autoCategoryEnabled
                    and rule.autoCategoryAnchor == nil then
                    output[#output + 1] = {
                        kind = "group", ruleKey = ruleKey, name = rule.displayName,
                        participating = false, anchor = nil, rank = nil, resolvedAnchorId = nil,
                    }
                end
            end
        end
        return output
    end

    local nativeNodes = byContext[contextKey]
    assert(nativeNodes, "Unknown AutoCategory context: " .. tostring(contextKey))
    local selectedContext = contextByKey[contextKey]
    AppendGroups(nil)
    for _, node in ipairs(nativeNodes) do
        if IsHeadingVisible(state, contextKey, node.id) or (options and options.showAllHeadings) then
            output[#output + 1] = {
                kind = "heading",
                occurrenceId = node.id,
                name = node.name,
                contexts = node.contexts,
                scopeLabel = selectedContext.title,
                hidden = not IsHeadingVisible(state, contextKey, node.id),
            }
        end
        AppendGroups(node.id)
    end
    AppendGroups(bottomAnchor)
    return output
end

function integration.ResolveAutoCategoryOrder(contextKey, options)
    assert(contextKey == "master" or contextByKey[contextKey],
        "Unknown AutoCategory view: " .. tostring(contextKey))
    return ResolveRows(contextKey, options)
end

function integration.MoveGroup(ruleKey, contextKey, direction, rebalanced)
    assert(contextKey == "master" or contextByKey[contextKey],
        "Unknown AutoCategory view: " .. tostring(contextKey))
    assert(direction == -1 or direction == 1, "AutoCategory move direction must be -1 or 1")
    local rows = {}
    for _, candidate in ipairs(ResolveRows(contextKey, {
        showNonparticipants = false,
        showAllHeadings = false,
    })) do
        if candidate.kind ~= "group" or candidate.participating then
            rows[#rows + 1] = candidate
        end
    end
    local rowIndex
    for index, row in ipairs(rows) do
        if row.kind == "group" and row.ruleKey == ruleKey then rowIndex = index; break end
    end
    assert(rowIndex, "AutoCategory move targets a group outside the current view: " .. tostring(ruleKey))
    local row = rows[rowIndex]
    assert(row.participating, "Only participating AutoCategory groups can be moved")
    local neighbor = rows[rowIndex + direction]
    if neighbor == nil then return false end
    local placementContext = contextKey
    if contextKey == "master" then placementContext = nil end
    local rules = GetRuntimeRules()
    local selectedPlacement = GetRulePlacement(rules[ruleKey], contextKey)
    assert(selectedPlacement.anchor ~= nil and selectedPlacement.rank ~= nil,
        "Participating AutoCategory group has no saved placement: " .. ruleKey)

    local targetAnchor
    local lowerRank, upperRank
    if neighbor.kind == "heading" then
        targetAnchor = neighbor.occurrenceId
    elseif neighbor.kind == "group" then
        assert(neighbor.participating, "A participating group cannot move across a nonparticipating row")
        targetAnchor = neighbor.resolvedAnchorId or topAnchor
        if direction < 0 then upperRank = neighbor.rank else lowerRank = neighbor.rank end
    else
        error("Unsupported AutoCategory move target")
    end

    local targetRank
    for index, candidateRow in ipairs(rows) do
        if candidateRow.kind == "group" and candidateRow.participating
            and candidateRow.resolvedAnchorId == targetAnchor then
            if neighbor.kind == "heading" then
                targetRank = targetRank and math.min(targetRank, candidateRow.rank) or candidateRow.rank
            elseif direction < 0 and index < rowIndex - 1 then
                lowerRank = lowerRank and math.max(lowerRank, candidateRow.rank) or candidateRow.rank
            elseif direction > 0 and index > rowIndex + 1 then
                upperRank = upperRank and math.min(upperRank, candidateRow.rank) or candidateRow.rank
            end
        end
    end
    if neighbor.kind == "heading" then upperRank = targetRank end

    local function FindAvailableRank()
        local usedRanks = {}
        for candidateKey, candidate in pairs(rules) do
            if candidateKey ~= ruleKey and IsOrdinaryRule(candidateKey, candidate) then
                for _, context in ipairs(contexts) do
                    local override = candidate.autoCategoryOverrides
                        and candidate.autoCategoryOverrides[context.key]
                    local effectiveRank = override and override.rank or candidate.autoCategoryRank
                    if effectiveRank ~= nil then usedRanks[effectiveRank] = true end
                end
            end
        end
        local rank
        if lowerRank ~= nil and upperRank ~= nil then
            rank = math.floor(upperRank) - 1
            while rank > lowerRank and usedRanks[rank] do rank = rank - 1 end
            if rank <= lowerRank then return nil end
        elseif upperRank ~= nil then
            rank = math.floor(upperRank) - 1
            while rank > 0 and usedRanks[rank] do rank = rank - 1 end
            if rank <= 0 then return nil end
        elseif lowerRank ~= nil then
            rank = math.floor(lowerRank) + 1
            while rank <= 0xFFFFFF and usedRanks[rank] do rank = rank + 1 end
            if rank > 0xFFFFFF then return nil end
        else
            rank = selectedPlacement.rank + 1
            while rank <= 0xFFFFFF and usedRanks[rank] do rank = rank + 1 end
            if rank > 0xFFFFFF then
                rank = selectedPlacement.rank - 1
                while rank > 0 and usedRanks[rank] do rank = rank - 1 end
                if rank <= 0 then return nil end
            end
        end
        return rank
    end

    local rank = FindAvailableRank()
    if rank == nil then
        assert(not rebalanced, "AutoCategory cannot allocate a rank for this move")
        this.RebalanceAutoCategoryRanks()
        return integration.MoveGroup(ruleKey, contextKey, direction, true)
    end
    assert(targetAnchor ~= nil and rank > 0 and rank <= 0xFFFFFF,
        "AutoCategory move cannot be represented in the target placement")
    this.SetAutoCategoryPlacement(ruleKey, targetAnchor, rank, placementContext)
    return true
end

function integration.BuildPresetPlacements(preset)
    assert(preset == "prefer_ic_groups" or preset == "prefer_autocategory_groups",
        "Unknown AutoCategory starting preset: " .. tostring(preset))
    local rules = GetRuntimeRules()
    local keys = GetOrderedRuleKeys(rules)
    table.sort(keys, function(left, right)
        local a, b = rules[left], rules[right]
        local nameA, nameB = a.displayName:lower(), b.displayName:lower()
        if nameA ~= nameB then return nameA < nameB end
        return left < right
    end)
    local placements = {}
    for index, ruleKey in ipairs(keys) do
        placements[ruleKey] = {
            anchor = preset == "prefer_ic_groups" and defaultNewAnchor or bottomAnchor,
            rank = index * 100,
        }
    end
    return placements
end

function integration.InitializeRulePlacement(ruleKey)
    local rules = GetRuntimeRules()
    local rule = rules[ruleKey]
    assert(rule ~= nil and IsOrdinaryRule(ruleKey, rule),
        "Cannot initialize AutoCategory placement for unknown or excluded group: " .. tostring(ruleKey))
    if rule.autoCategoryAnchor ~= nil then
        return rule.autoCategoryAnchor, rule.autoCategoryRank
    end

    local function BuildCleanup()
        local ranks = {}
        for _, candidate in pairs(rules) do
            if candidate.autoCategoryRank ~= nil then ranks[candidate.autoCategoryRank] = true end
            for _, placement in pairs(candidate.autoCategoryOverrides or {}) do
                if placement.rank ~= nil then ranks[placement.rank] = true end
            end
        end
        local orderedRanks = {}
        for rank in pairs(ranks) do orderedRanks[#orderedRanks + 1] = rank end
        table.sort(orderedRanks)
        assert(#orderedRanks * 100 <= 0xFFFFFF, "AutoCategory rank space is exhausted")
        local replacement = {}
        for index, rank in ipairs(orderedRanks) do replacement[rank] = index * 100 end
        local cleanup = {}
        for candidateKey, candidate in pairs(rules) do
            local entry = { overrides = {} }
            if candidate.autoCategoryRank ~= nil then
                entry.master = replacement[candidate.autoCategoryRank]
            end
            for contextKey, placement in pairs(candidate.autoCategoryOverrides or {}) do
                if placement.rank ~= nil then entry.overrides[contextKey] = replacement[placement.rank] end
            end
            if entry.master ~= nil or next(entry.overrides) ~= nil then cleanup[candidateKey] = entry end
        end
        return cleanup, replacement
    end

    local function FindPlacement(cleanup, replacement)
        local rows = ResolveRows("master", { showNonparticipants = true, showAllHeadings = false })
        local lastGroup
        for _, row in ipairs(rows) do
            if row.kind == "group" and row.participating then lastGroup = row end
        end
        local used, maximumRank = {}, 0
        for _, candidate in pairs(rules) do
            local rank = candidate.autoCategoryRank
            if rank ~= nil then rank = replacement and replacement[rank] or rank end
            if rank ~= nil then used[rank] = true; maximumRank = math.max(maximumRank, rank) end
            for _, placement in pairs(candidate.autoCategoryOverrides or {}) do
                rank = placement.rank
                if rank ~= nil then rank = replacement and replacement[rank] or rank end
                if rank ~= nil then used[rank] = true; maximumRank = math.max(maximumRank, rank) end
            end
        end
        if not lastGroup then
            if maximumRank <= 0xFFFFFF - 100 then return bottomAnchor, maximumRank + 100 end
            return nil
        end
        local anchor = lastGroup.resolvedAnchorId or topAnchor
        local previousRank = lastGroup.rank
        if replacement then previousRank = replacement[previousRank] end
        local nextRank
        for index = 1, #rows do
            if rows[index] == lastGroup then
                for nextIndex = index + 1, #rows do
                    local nextRow = rows[nextIndex]
                    if nextRow.kind == "heading" then break end
                    if nextRow.kind == "group" and nextRow.resolvedAnchorId == lastGroup.resolvedAnchorId then
                        nextRank = nextRow.rank
                        if replacement then nextRank = replacement[nextRank] end
                        break
                    end
                end
                break
            end
        end
        local rank = previousRank + 1
        while rank <= 0xFFFFFF and (used[rank] or (nextRank ~= nil and rank >= nextRank)) do
            rank = rank + 1
        end
        if rank <= 0xFFFFFF then return anchor, rank end
        return nil
    end

    local anchor, rank = FindPlacement()
    if anchor ~= nil then return anchor, rank end
    local cleanup, replacement = BuildCleanup()
    anchor, rank = FindPlacement(cleanup, replacement)
    assert(anchor ~= nil, "AutoCategory cannot allocate a rank after the last participating group")
    return anchor, rank, cleanup
end

local function GetExternalPrioritySequence(entries, field)
    local copy = {}
    for _, entry in ipairs(entries) do
        copy[#copy + 1] = {
            name = entry.name,
            runpriority = entry.runpriority,
            showpriority = entry.showpriority,
            priority = entry[field],
        }
    end
    table.sort(copy, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.name < b.name
    end)
    return copy
end

local function GetInsertionTarget(group, contextKey)
    if group.resolvedAnchorId == nil then return topAnchor end
    if group.resolvedAnchorId == bottomAnchor then return bottomAnchor end
    local _, byContext = BuildHeadingModel()
    for _, node in ipairs(byContext[contextKey]) do
        if node.id == group.resolvedAnchorId then return node.name end
    end
    error("Resolved AutoCategory anchor is unavailable in " .. contextKey .. ": " .. group.resolvedAnchorId)
end

local function SpreadPriorities(high, low, count)
    local values = {}
    for index = 1, count do
        local value
        if high - low > count then
            value = high - index
        else
            value = high - (high - low) * index / (count + 1)
        end
        if not (value < high and value > low) then return nil end
        values[index] = value
    end
    return values
end

-- Ties among external headings resolve alphabetically in AutoCategory, so groups anchored to any
-- heading in a tie block follow the whole block, in that block's alphabetical heading order.
-- Duplicate heading names cannot be ordered alphabetically; the first native occurrence anchors.
local function AllocateFieldPriorities(external, field, groupBuckets)
    local sequence = GetExternalPrioritySequence(external, field)
    local priorities = {}
    local placed = {}
    local function Assign(bucketNames, high, low)
        local groups = {}
        for _, name in ipairs(bucketNames) do
            if not placed[name] then
                placed[name] = true
                for _, group in ipairs(groupBuckets[name] or {}) do groups[#groups + 1] = group end
            end
        end
        if #groups == 0 then return true end
        local values = SpreadPriorities(high, low, #groups)
        if values == nil then return false end
        for index, group in ipairs(groups) do priorities[group.ruleKey] = values[index] end
        return true
    end

    local maximum, minimum = 0, 0
    for _, entry in ipairs(sequence) do
        maximum = math.max(maximum, entry.priority)
        minimum = math.min(minimum, entry.priority)
    end
    local topCount = groupBuckets[topAnchor] and #groupBuckets[topAnchor] or 0
    local bottomCount = groupBuckets[bottomAnchor] and #groupBuckets[bottomAnchor] or 0
    assert(Assign({ topAnchor }, maximum + topCount + 1, maximum))
    assert(Assign({ bottomAnchor }, minimum, minimum - bottomCount - 1))

    local index = 1
    while index <= #sequence do
        local high = sequence[index].priority
        local block = {}
        while index <= #sequence and sequence[index].priority == high do
            block[#block + 1] = sequence[index].name
            index = index + 1
        end
        local blockCount = 0
        for _, name in ipairs(block) do
            if not placed[name] then
                blockCount = blockCount + (groupBuckets[name] and #groupBuckets[name] or 0)
            end
        end
        local low = sequence[index] and sequence[index].priority or high - blockCount - 1
        if not Assign(block, high, low) then
            return nil, "AutoCategory has no " .. field .. " room below '" .. block[1] .. "'"
        end
    end
    return priorities
end

local function GetContextProjection(context)
    local rows = ResolveRows(context.key)
    local groups = {}
    for _, row in ipairs(rows) do
        if row.kind == "group" and row.participating then groups[#groups + 1] = row end
    end
    local groupBuckets = {}
    for _, group in ipairs(groups) do
        local target = GetInsertionTarget(group, context.key)
        groupBuckets[target] = groupBuckets[target] or {}
        groupBuckets[target][#groupBuckets[target] + 1] = group
    end
    local external = GetNativeAssignments(context)
    local runPriorities, runFailure = AllocateFieldPriorities(external, "runpriority", groupBuckets)
    if runPriorities == nil then return nil, runFailure .. " in " .. context.title end
    local showPriorities, showFailure = AllocateFieldPriorities(external, "showpriority", groupBuckets)
    if showPriorities == nil then return nil, showFailure .. " in " .. context.title end
    local proposed = {}
    for _, group in ipairs(groups) do
        local rule = GetRuntimeRules()[group.ruleKey]
        proposed[group.ruleKey] = {
            ruleKey = group.ruleKey,
            name = GetCategoryName(rule),
            runpriority = runPriorities[group.ruleKey],
            showpriority = showPriorities[group.ruleKey],
            isHidden = false,
            icOwned = true,
        }
    end

    -- AutoCategory edits run and show priorities independently, so each field has its own native order.
    local function Desired(field)
        local desired = {}
        local placed = {}
        local function AddDesiredTarget(target)
            local bucket = groupBuckets[target]
            if bucket and not placed[target] then
                placed[target] = true
                for _, group in ipairs(bucket) do desired[#desired + 1] = group.ruleKey end
            end
        end
        AddDesiredTarget(topAnchor)
        local sequence = GetExternalPrioritySequence(external, field)
        local tiedTargets = {}
        for index, entry in ipairs(sequence) do
            desired[#desired + 1] = entry.name
            tiedTargets[#tiedTargets + 1] = entry.name
            local nextEntry = sequence[index + 1]
            if nextEntry == nil or nextEntry.priority ~= entry.priority then
                for _, target in ipairs(tiedTargets) do AddDesiredTarget(target) end
                tiedTargets = {}
            end
        end
        AddDesiredTarget(bottomAnchor)
        return desired
    end

    local function Expected(field)
        local desired = Desired(field)
        local sorted = {}
        for _, entry in ipairs(external) do
            sorted[#sorted + 1] = {
                name = entry.name, priority = entry[field], key = entry.name,
            }
        end
        for key, assignment in pairs(proposed) do
            sorted[#sorted + 1] = { name = assignment.name, priority = assignment[field], key = key }
        end
        table.sort(sorted, function(a, b)
            if a.priority ~= b.priority then return a.priority > b.priority end
            return a.name < b.name
        end)
        local result = {}
        for _, entry in ipairs(sorted) do result[#result + 1] = entry.key end
        assert(#result == #desired, "AutoCategory projection order is incomplete in " .. context.title)
        for index = 1, #result do
            assert(result[index] == desired[index],
                "AutoCategory " .. field .. " mapping cannot preserve the required order in " .. context.title)
        end
    end
    Expected("runpriority")
    Expected("showpriority")
    return proposed, external
end

local function SameAssignment(left, right)
    return left.name == right.name and left.runpriority == right.runpriority
        and left.showpriority == right.showpriority and left.isHidden == right.isHidden
        and left.icOwned == right.icOwned
end

local function SyncDefinitions(ac, definitions)
    local plugin = ac.Plugins[pluginName]
    assert(plugin and type(plugin.predef) == "table", "AutoCategory did not retain the integration plugin")
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

local function WriteProjection(ac, plans)
    local changed = {}
    for _, context in ipairs(contexts) do
        local bagType = context.bagType()
        local bag = ac.saved.bags[bagType]
        local plan = plans[context.key]
        local externalNames = {}
        for _, assignment in ipairs(bag.rules) do
            if assignment.icOwned ~= true then externalNames[assignment.name] = true end
        end
        local desiredNames = {}
        for _, assignment in pairs(plan) do
            assert(not externalNames[assignment.name],
                "AutoCategory assignment collision appeared after preflight: " .. assignment.name)
            desiredNames[assignment.name] = true
        end
        for index = #bag.rules, 1, -1 do
            local assignment = bag.rules[index]
            if assignment.icOwned == true and not desiredNames[assignment.name] then
                table.remove(bag.rules, index)
                changed[context.key] = true
            end
        end
        for _, assignment in pairs(plan) do
            local existing
            for _, candidate in ipairs(bag.rules) do
                if candidate.icOwned == true and candidate.name == assignment.name then
                    existing = candidate
                    break
                end
            end
            if existing then
                if not SameAssignment(existing, assignment) then
                    for field, value in pairs(assignment) do existing[field] = value end
                    changed[context.key] = true
                end
            else
                bag.rules[#bag.rules + 1] = {
                    name = assignment.name,
                    runpriority = assignment.runpriority,
                    showpriority = assignment.showpriority,
                    isHidden = assignment.isHidden,
                    icOwned = true,
                }
                changed[context.key] = true
            end
        end
    end
    return changed
end

local function RefreshContexts(ac, changed, rebuildCache)
    for _, context in ipairs(contexts) do
        if changed[context.key] then
            if rebuildCache then ac.cacheInitBag(context.bagType()) end
            ac.RefreshList(context.inventoryType(), context.key ~= "crafting_station")
        end
    end
end

function integration.ProjectAutoCategory()
    local ac = AutoCategory
    CheckExternalShape(ac)
    assert(ac.Inited == true, "AutoCategory must finish initialization before projection")
    CheckActiveAssignments(ac)
    assert(this.GetAutoCategoryState().enabled, "Cannot project while AutoCategory integration is disabled")
    local definitions = BuildDefinitions()
    local collisionFree, collision = CheckDefinitionCollision(ac, definitions)
    assert(collisionFree, collision)
    local plans = {}
    for _, context in ipairs(contexts) do
        local plan, failure = GetContextProjection(context)
        if plan == nil then
            -- External AutoCategory layouts we cannot represent are reported without writing anything.
            if status.state ~= "unsupported" or status.message ~= failure then
                d("[InventoryCompanion] AutoCategory integration paused: " .. failure)
            end
            SetStatus("unsupported", "AutoCategory integration is paused: " .. failure
                .. ". Change the AutoCategory priorities or this group's placement to resume.")
            return {}
        end
        plans[context.key] = plan
    end
    SyncDefinitions(ac, definitions)
    reconciling = true
    local ok, changed = xpcall(function()
        local changedContexts = WriteProjection(ac, plans)
        RefreshContexts(ac, changedContexts, true)
        return changedContexts
    end, function(failure)
        reconciling = false
        return failure
    end)
    reconciling = false
    if not ok then error(changed) end
    SetStatus("available", "AutoCategory integration is active for the selected Inventory Companion profile.")
    return changed
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
    if refresh then RefreshContexts(ac, changed) end
end

local function ScheduleReconcile(reason, refreshOnly)
    if AutoCategory == nil or status.state == "absent" or not this.GetAutoCategoryState().enabled then return end
    pendingGeneration = pendingGeneration + 1
    local generation = pendingGeneration
    zo_callLater(function()
        if generation ~= pendingGeneration or not this.GetAutoCategoryState().enabled then return end
        if AutoCategory.Inited ~= true then return end
        if refreshOnly then
            local changed = {}
            for _, context in ipairs(contexts) do changed[context.key] = true end
            RefreshContexts(AutoCategory, changed, false)
        else
            integration.ProjectAutoCategory()
        end
    end, 100)
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
    ZO_PostHook(ac, "UpdateCurrentSavedVars", function()
        if not reconciling then integration.OnProfileChanged() end
    end)
    ZO_PostHook(ac, "cacheInitBag", function()
        if not reconciling and this.GetAutoCategoryState().enabled then ScheduleReconcile("external-heading-edit", false) end
    end)
    ZO_PostHook(ac, "cacheInitialize", function()
        if not reconciling and this.GetAutoCategoryState().enabled then ScheduleReconcile("external-heading-edit", false) end
    end)
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
        SetStatus("incompatible", tostring(failure))
        d("[InventoryCompanion] AutoCategory integration unavailable: " .. tostring(failure))
        return false
    end
    if ac.Inited == true then
        SetStatus("incompatible", "AutoCategory initialized before Inventory Companion could register its plugin.")
        d("[InventoryCompanion] AutoCategory integration unavailable: " .. status.message)
        return false
    end
    local definitions = BuildDefinitions()
    local collisionFree, collision = CheckDefinitionCollision(ac, definitions)
    if not collisionFree then
        SetStatus("collision", collision)
        d("[InventoryCompanion] AutoCategory integration refused: " .. collision)
        return false
    end
    if ac.Plugins[pluginName] ~= nil then
        SetStatus("collision", "AutoCategory plugin name is already registered.")
        d("[InventoryCompanion] AutoCategory integration refused: " .. status.message)
        return false
    end
    ac.RegisterPlugin(pluginName, function()
        ac.AddRuleFunc(predicateName, function(ruleKey)
            local rules = GetRuntimeRules()
            local rule = rules[ruleKey]
            assert(rule ~= nil, "Registered AutoCategory expression references unknown Inventory Companion group: "
                .. tostring(ruleKey))
            if not this.GetAutoCategoryState().enabled or not rule.autoCategoryEnabled then return false end
            assert(type(ac.checkingItemLink) == "string", "AutoCategory checkingItemLink must be a string")
            return this.ItemMatchesRuntimeRule(ac.checkingItemLink, rule)
        end)
        if this.GetAutoCategoryState().enabled then
            -- AutoCategory sets Inited synchronously after plugin initializers, before this deferred call runs.
            ScheduleReconcile("autocategory-initialized", false)
        else
            RemoveOwnedAssignments(false)
        end
    end, definitions)
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
    -- Keyboard ZO_Dialog has only two button controls, so the arrangement is a radio choice.
    ZO_Dialogs_RegisterCustomDialog("INVENTORYCOMPANION_AUTOCATEGORY_PRESET", {
        title = { text = "AutoCategory Starting Arrangement" },
        mainText = {
            text = function(dialog)
                if dialog.data and dialog.data.reset then
                    return "Replace the shared Master placement defaults with a starting arrangement? Context-specific overrides and participation choices will be retained."
                end
                return "Choose how Inventory Companion groups should be arranged relative to AutoCategory headings. The arrangement can be changed later."
            end,
        },
        radioButtons = {
            { text = "Prefer IC groups", data = "prefer_ic_groups" },
            { text = "Prefer AutoCategory groups", data = "prefer_autocategory_groups" },
        },
        buttons = {
            {
                text = SI_DIALOG_CONFIRM,
                callback = function(dialog)
                    local selected = dialog.radioButtonGroup:GetClickedButton()
                    assert(selected ~= nil, "AutoCategory preset dialog has no selected arrangement")
                    local enabled
                    if not (dialog.data and dialog.data.reset) then enabled = true end
                    this.ApplyAutoCategoryPreset(selected.data, enabled)
                    if this.RefreshAutoCategoryUI then this.RefreshAutoCategoryUI() end
                end,
            },
            {
                text = SI_DIALOG_CANCEL,
                callback = function()
                    if this.RefreshAutoCategoryUI then this.RefreshAutoCategoryUI() end
                end,
            },
        },
        noChoiceCallback = function()
            if this.RefreshAutoCategoryUI then this.RefreshAutoCategoryUI() end
        end,
    })
    RegisterPlugin()
end
