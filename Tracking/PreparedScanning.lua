local this = InventoryCompanion
local prepared = {}
this.PreparedScanning = prepared

local function SupportsMarkers(bagId)
    return bagId == BAG_BACKPACK or bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK
end

local function BuildMarkerKey(markers, markerIds)
    local matched = {}
    for _, markerId in ipairs(markerIds) do
        assert(type(markers[markerId]) == "boolean", "FCO marker answer must be boolean")
        if markers[markerId] then matched[#matched + 1] = tostring(markerId) end
    end
    return table.concat(matched, ",")
end

function prepared.GetPreparedMasterItemList(trackedItems, activeRules, bagIds, work)
    assert(type(activeRules) == "table" and type(bagIds) == "table",
        "Prepared scanning requires rules and bag IDs")
    local started = GetGameTimeMilliseconds()
    local markerIds, keyById = this.FCOItemSaver.GetActiveMarkerIds(activeRules)
    local context = {
        markerIds = markerIds,
        keyById = keyById,
        inputs = {},
        bags = {},
        markerAnswers = {},
    }
    if work then
        work.markerIds = markerIds
        context.Checkpoint = work.checkpoint
    end

    for _, bagId in ipairs(bagIds) do
        context.bags[bagId] = {}
        context.markerAnswers[bagId] = {}
    end

    context.OnBagRead = function(bagId, contents)
        assert(context.bags[bagId] ~= nil, "Prepared scan read an unrequested bag")
        for _, item in ipairs(contents) do
            if context.Checkpoint then context.Checkpoint() end
            assert(item.bagId == bagId, "Scanner returned an item for a different bag")
            context.inputs[#context.inputs + 1] = item
            context.bags[bagId][item.slotIndex] = item
        end
    end

    context.PrepareGroupSlotLists = function(compiledRules)
        local groupSlots = {}
        for ruleKey, rule in pairs(compiledRules) do
            if context.Checkpoint then context.Checkpoint() end
            groupSlots[ruleKey] = {}
            if rule.slotMatcher then
                assert(rule.markerKey == ruleKey and keyById ~= nil,
                    "Prepared scan encountered an invalid FCO slot matcher: " .. ruleKey)
            end
        end
        if #markerIds == 0 then return groupSlots end

        for _, item in ipairs(context.inputs) do
            if context.Checkpoint then context.Checkpoint() end
            if SupportsMarkers(item.bagId) then
                local marked, answers = this.FCOItemSaver.ReadMarkers(markerIds, item.bagId, item.slotIndex)
                assert(type(marked) == "boolean" and type(answers) == "table",
                    "FCO adapter returned invalid prepared marker answers")
                context.markerAnswers[item.bagId][item.slotIndex] = answers
                for markerId, ruleKey in pairs(keyById) do
                    if answers[markerId] then
                        groupSlots[ruleKey][#groupSlots[ruleKey] + 1] = {
                            bagId = item.bagId,
                            slotIndex = item.slotIndex,
                        }
                    end
                end
            end
        end
        return groupSlots
    end

    context.MatchIndexedGroups = function(compiledRules, groupSlots)
        local slotMatches = {}
        for _, item in ipairs(context.inputs) do
            if context.Checkpoint then context.Checkpoint() end
            slotMatches[item] = {}
        end
        for ruleKey, rule in pairs(compiledRules) do
            if context.Checkpoint then context.Checkpoint() end
            if not rule.isInactive then
                for _, item in ipairs(context.inputs) do
                    if context.Checkpoint then context.Checkpoint() end
                    local name = item.link and GetItemLinkName(item.link)
                    local answers = context.markerAnswers[item.bagId][item.slotIndex]
                    if this.ItemMatchesCompiledRule(name and name:lower(), rule,
                        item.bagId, item.slotIndex, answers) then
                        slotMatches[item][ruleKey] = true
                    end
                end
            end
        end
        return slotMatches
    end

    context.CaptureSlot = function(item, matchedRules, slotIndex)
        local bag = slotIndex.bags[item.bagId]
        assert(not bag.ordered[item.slotIndex], "Prepared scan captured a duplicate slot")
        bag.ordered[item.slotIndex] = true
        bag.order[#bag.order + 1] = item.slotIndex
        bag.slots[item.slotIndex] = {
            itemData = item,
            matchedRules = matchedRules,
            markerKey = SupportsMarkers(item.bagId)
                and BuildMarkerKey(context.markerAnswers[item.bagId][item.slotIndex], markerIds) or "",
        }
    end

    local snapshot, slotIndex = this.GetMasterItemListForPreparedMatchingDiagnostics(
        trackedItems, activeRules, bagIds, context)
    if work then
        work.entries = #context.inputs
    else
        this.DiagnosticLog.Sample("trackerScan", {
            scanMs = GetGameTimeMilliseconds() - started,
            entries = #context.inputs,
            markerCount = #markerIds,
        })
    end
    return snapshot, slotIndex
end
