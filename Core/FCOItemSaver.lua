local this = InventoryCompanion

local groups = {
    {
        key = "__ic_fco_deconstruct",
        name = "Deconstruct",
        markerConstant = "FCOIS_CON_ICON_DECONSTRUCTION",
        legacyMarkerId = 9,
    },
    {
        key = "__ic_fco_sell_vendor",
        name = "Sell to vendor",
        markerConstant = "FCOIS_CON_ICON_SELL",
        legacyMarkerId = 5,
    },
    {
        key = "__ic_fco_sell_guild",
        name = "Sell at guild store",
        markerConstant = "FCOIS_CON_ICON_SELL_AT_GUILDSTORE",
        legacyMarkerId = 11,
    },
}

local adapter = {}
this.FCOItemSaver = adapter

local function ResolveMarker(group)
    local markerId = _G[group.markerConstant]
    if markerId == nil then return nil end
    assert(type(markerId) == "number" and markerId >= 1 and markerId % 1 == 0,
        "FCO ItemSaver marker constant is invalid: " .. group.markerConstant)
    return markerId
end

local function ReadinessFailure()
    if type(FCOIS) ~= "table" or FCOIS.libsLoadedProperly ~= true
        or type(FCOIS.addonVars) ~= "table" or FCOIS.addonVars.gAddonLoaded ~= true then
        return "FCO ItemSaver is not loaded and ready"
    end
    if type(FCOIS.IsMarked) ~= "function"
        or type(FCOIS.GetSavedVarsMarkedItemsTableName) ~= "function" then
        return "FCO ItemSaver marker API is unavailable"
    end
    if type(FCOIS.settingsVars) ~= "table" or type(FCOIS.settingsVars.settings) ~= "table" then
        return "FCO ItemSaver settings are not ready"
    end
    return nil
end

function adapter.IsReady()
    return ReadinessFailure() == nil
end

function adapter.GetReadinessReason()
    return ReadinessFailure()
end

function adapter.GetGroups()
    return groups
end

function adapter.GetRuleKeyForMarker(markerId)
    for _, group in ipairs(groups) do
        if ResolveMarker(group) == markerId then return group.key end
    end
end

function adapter.GetMarkerId(ruleKey)
    for _, group in ipairs(groups) do
        if group.key == ruleKey then return ResolveMarker(group) end
    end
end

function adapter.IsMarkerAvailable(ruleKey)
    local readyReason = ReadinessFailure()
    if readyReason then return false, readyReason end
    local group
    for _, candidate in ipairs(groups) do
        if candidate.key == ruleKey then group = candidate; break end
    end
    assert(group ~= nil, "Unknown FCO ItemSaver group: " .. tostring(ruleKey))
    local markerId = ResolveMarker(group)
    if markerId == nil then return false, "FCO marker constant is unavailable" end
    return adapter.IsMarkerIdAvailable(markerId)
end

function adapter.IsMarkerIdAvailable(markerId)
    assert(type(markerId) == "number" and markerId >= 1 and markerId < math.huge
        and markerId % 1 == 0, "FCO marker ID must be a positive integer")
    local readyReason = ReadinessFailure()
    if readyReason then return false, readyReason end
    local settings = FCOIS.settingsVars.settings
    if type(settings.isIconEnabled) ~= "table" or settings.isIconEnabled[markerId] ~= true then
        return false, "FCO marker is disabled or unavailable"
    end
    local storageName = FCOIS.GetSavedVarsMarkedItemsTableName()
    if type(storageName) ~= "string" or type(settings[storageName]) ~= "table"
        or type(FCOIS[storageName]) ~= "table" then
        return false, "FCO marker storage is unavailable"
    end
    local markerStorage = FCOIS[storageName][markerId]
    if markerStorage ~= nil and type(markerStorage) ~= "table" then
        return false, "FCO marker storage is malformed"
    end
    return true
end

function adapter.GetInactiveReason(ruleKey)
    local state = this.accountWide.fcoIntegrationState
    if state == "suspended" then return "FCO suspended" end
    if state ~= "enabled" then return "FCO integration is off" end
    local available, reason = adapter.IsMarkerAvailable(ruleKey)
    if not available then return reason end
    return nil
end

function adapter.GetConditionsInactiveReason(conditions)
    local state = this.accountWide.fcoIntegrationState
    if state == "suspended" then return "FCO suspended" end
    if state ~= "enabled" then return "FCO integration is off" end
    local readyReason = ReadinessFailure()
    if readyReason then return readyReason end
    for _, list in ipairs({ conditions.include, conditions.exclude }) do
        for _, markerId in ipairs(list) do
            local available, reason = adapter.IsMarkerIdAvailable(markerId)
            if not available then return reason end
        end
    end
end

function adapter.IsGroupActive(ruleKey)
    return adapter.GetInactiveReason(ruleKey) == nil
end

function adapter.GetActiveMarkerIds(activeRules)
    local markerIds, keyById = {}, {}
    if this.accountWide.fcoIntegrationState ~= "enabled" then return markerIds, keyById end
    if not adapter.IsReady() then return markerIds, keyById end
    local seen = {}
    for _, rule in pairs(activeRules) do
        if not rule.isInactive and rule.markerConditions then
            for _, list in ipairs({ rule.markerConditions.include, rule.markerConditions.exclude }) do
                for _, markerId in ipairs(list) do
                    if not seen[markerId] then
                        seen[markerId] = true
                        markerIds[#markerIds + 1] = markerId
                    end
                end
            end
        end
    end
    for _, group in ipairs(groups) do
        if activeRules[group.key] and activeRules[group.key].isFCOGroup
            and not activeRules[group.key].isInactive then
            local available = adapter.IsMarkerAvailable(group.key)
            if available then
                local markerId = ResolveMarker(group)
                if not seen[markerId] then
                    seen[markerId] = true
                    markerIds[#markerIds + 1] = markerId
                end
                keyById[markerId] = group.key
            end
        end
    end
    table.sort(markerIds)
    return markerIds, keyById
end

function adapter.GetAvailabilitySignature(rules)
    local ids, seen = {}, {}
    if adapter.IsReady() then
        local icons = FCOIS.settingsVars.settings.isIconEnabled
        if type(icons) == "table" then
            for markerId in pairs(icons) do
                if type(markerId) == "number" and markerId >= 1 and markerId < math.huge
                    and markerId % 1 == 0 then
                    seen[markerId] = true
                    ids[#ids + 1] = markerId
                end
            end
        end
    end
    for _, rule in pairs(rules) do
        if rule.markerConditions then
            for _, list in ipairs({ rule.markerConditions.include, rule.markerConditions.exclude }) do
                for _, markerId in ipairs(list) do
                    if not seen[markerId] then
                        seen[markerId] = true
                        ids[#ids + 1] = markerId
                    end
                end
            end
        elseif rule.isFCOGroup and rule.markerId and not seen[rule.markerId] then
            seen[rule.markerId] = true
            ids[#ids + 1] = rule.markerId
        end
    end
    table.sort(ids)
    local parts = { adapter.GetReadinessReason() or "ready" }
    for _, markerId in ipairs(ids) do
        local available, reason = adapter.IsMarkerIdAvailable(markerId)
        parts[#parts + 1] = tostring(markerId) .. ":" .. (available and "available" or reason)
    end
    return table.concat(parts, ";"), #ids
end

function adapter.ReadMarkers(markerIds, bagId, slotIndex)
    assert(type(markerIds) == "table" and type(bagId) == "number" and type(slotIndex) == "number",
        "FCO marker reads require marker IDs and a bag slot")
    if #markerIds == 0 then return false, {} end
    assert(adapter.IsReady(), adapter.GetReadinessReason() or "FCO ItemSaver is not ready")
    for _, markerId in ipairs(markerIds) do
        local available, reason = adapter.IsMarkerIdAvailable(markerId)
        assert(available, reason)
    end
    local marked, markers = FCOIS.IsMarked(bagId, slotIndex, markerIds)
    if marked == nil and markers == nil and this.Scanning.ReadSlot(bagId, slotIndex) == nil then
        markers = {}
        for _, markerId in ipairs(markerIds) do markers[markerId] = false end
        return false, markers
    end
    assert(type(marked) == "boolean" and type(markers) == "table",
        string.format("FCO ItemSaver marker query failed (bag %d, slot %d)", bagId, slotIndex))
    for _, markerId in ipairs(markerIds) do
        assert(type(markers[markerId]) == "boolean",
            string.format("FCO marker %d returned an invalid answer (bag %d, slot %d)",
                markerId, bagId, slotIndex))
    end
    return marked, markers
end

function adapter.ReadMarker(ruleKey, bagId, slotIndex)
    local markerId = adapter.GetMarkerId(ruleKey)
    assert(markerId ~= nil, "FCO marker constant is unavailable for " .. tostring(ruleKey))
    local marked, markers = adapter.ReadMarkers({ markerId }, bagId, slotIndex)
    assert(markers[markerId] == marked, "FCO single-marker result disagrees with marker table")
    return marked
end

function adapter.ReadSlotMarkerKey(bagId, slotIndex, markerIds)
    if #markerIds == 0 or (bagId ~= BAG_BACKPACK and bagId ~= BAG_BANK
        and bagId ~= BAG_SUBSCRIBER_BANK) then
        return ""
    end
    local _, markers = adapter.ReadMarkers(markerIds, bagId, slotIndex)
    local marked = {}
    for _, markerId in ipairs(markerIds) do
        if markers[markerId] then marked[#marked + 1] = tostring(markerId) end
    end
    return table.concat(marked, ",")
end

function adapter.RegisterBuiltInGroups(force)
    local saved = _G[this.SettingsName]
    local shouldRegister = force == true
    local function Inspect(value, seen)
        if type(value) ~= "table" then return end
        if type(value.version) == "number" and value.version > 14 then return end
        seen = seen or {}
        if seen[value] then return end
        seen[value] = true
        if value.fcoTestGroupsCreated == true then shouldRegister = true end
        for key, child in pairs(value) do
            if type(key) == "string" then
                for _, group in ipairs(groups) do
                    if key == group.key or key == "ic:" .. group.key then shouldRegister = true end
                end
            end
            if type(child) == "string" then
                for _, group in ipairs(groups) do
                    if child == group.key or child == "ic:" .. group.key then shouldRegister = true end
                end
            end
            if type(child) == "table" then Inspect(child, seen) end
        end
    end
    if saved ~= nil then Inspect(saved) end
    if not shouldRegister then return end
    for _, group in ipairs(groups) do
        if this.preLoadedRulesets[group.key] ~= nil then
            assert(this.preLoadedRulesets[group.key].isFCOGroup == true,
                "FCO ItemSaver baseline key is already registered: " .. group.key)
        else
            local ruleKey = group.key
            local definition = {
                displayName = group.name,
                patterns = {},
                isFCOGroup = true,
                markerKey = ruleKey,
                markerConstant = group.markerConstant,
                display = {
                    show = true, notify = false, bank = false, group = true,
                    isExpanded = true, isHidden = false,
                },
            }
            definition.slotMatcher = function(bagId, slotIndex)
                return adapter.ReadMarker(ruleKey, bagId, slotIndex)
            end
            this.preLoadedRulesets[ruleKey] = definition
        end
    end
end

local function InvalidateFCOChanges()
    this.InvalidateRuleCache()
    this.ResetPriorityWatch()
    this.InvalidateEditorHistory()
    this.AutoCategoryIntegration.OnProfileChanged()
    this.AutoCategoryIntegration.OnFCOAvailabilityChanged()
    this.RefreshTrackedItemsEditor()
    this.RefreshGroupsEditor()
    this.RefreshAutoCategoryEditor()
    this.RefreshItemTrackerPanel()
    this.UpdateEventRegistry()
    this.StartTrackerMarkerPolling()
end

function adapter.Enable()
    assert(adapter.IsReady(), adapter.GetReadinessReason() or "FCO ItemSaver is not ready")
    assert(this.accountWide.fcoIntegrationState == "off", "FCO integration is not off")
    this.accountWide.fcoIntegrationState = "enabled"
    InvalidateFCOChanges()
end
function adapter.Suspend()
    local state = this.accountWide.fcoIntegrationState
    assert(state == "enabled" or state == "suspended", "FCO integration is not enabled or suspended")
    if state == "suspended" then return end
    this.accountWide.fcoIntegrationState = "suspended"
    InvalidateFCOChanges()
end
function adapter.Resume()
    assert(this.accountWide.fcoIntegrationState == "suspended", "FCO integration is not suspended")
    assert(adapter.IsReady(), adapter.GetReadinessReason() or "FCO ItemSaver is not ready")
    this.accountWide.fcoIntegrationState = "enabled"
    InvalidateFCOChanges()
end

local function RemoveReference(sequence, target)
    for index = #sequence, 1, -1 do
        if sequence[index] == target then table.remove(sequence, index) end
    end
end

function adapter.AddTestGroups()
    assert(this.accountWide.fcoIntegrationState == "enabled", "Enable FCO integration before adding test groups")
    assert(adapter.IsReady(), adapter.GetReadinessReason() or "FCO ItemSaver is not ready")
    local profile = this.GetAutoCategoryProfile()
    local rules = profile.trackedRules
    local order = profile.autoCategoryOrder
    assert(type(rules) == "table" and type(order) == "table" and type(order.contexts) == "table",
        "Current profile is not prepared for FCO test groups")
    local definitions, unavailable = {}, {}
    for _, group in ipairs(groups) do
        local markerId = ResolveMarker(group)
        local available, reason
        if markerId then available, reason = adapter.IsMarkerIdAvailable(markerId) end
        if available then
            definitions[#definitions + 1] = {
                key = group.key, name = group.name,
                conditions = { include = { markerId }, exclude = {} },
            }
        else
            unavailable[#unavailable + 1] = group.name .. ": " .. (reason or "marker constant unavailable")
        end
    end
    local created = adapter.CreateTestGroups(definitions)
    if #unavailable > 0 then
        this.Utils.UserError("FCO test groups not created: " .. table.concat(unavailable, "; "), "FCO")
    end
    return created > 0
end

function adapter.CreateTestGroups(definitions)
    local profile = this.GetAutoCategoryProfile()
    local rules, order = profile.trackedRules, profile.autoCategoryOrder
    local existingNames = {}
    for _, rule in pairs(this.GetRuntimeRules()) do existingNames[rule.displayName] = true end
    local created, collisions = {}, {}
    for _, definition in ipairs(definitions) do
        if rules[definition.key] == nil and this.preLoadedRulesets[definition.key] == nil then
            if existingNames[definition.name] then
                collisions[#collisions + 1] = definition.name
            else
                existingNames[definition.name] = true
                created[#created + 1] = definition
            end
        end
    end
    for _, definition in ipairs(created) do
        rules[definition.key] = {
            displayName = definition.name, patterns = definition.patterns or {},
            markerConditions = definition.conditions,
            display = { show = true, notify = false, bank = false, group = true,
                isExpanded = true, isHidden = false },
            autoCategoryEnabled = true,
        }
    end
    for _, context in pairs(order.contexts) do
        for index = #created, 1, -1 do
            local reference = "ic:" .. created[index].key
            RemoveReference(context.matching, reference)
            RemoveReference(context.display, reference)
            table.insert(context.matching, 1, reference)
            table.insert(context.display, 1, reference)
            context.hidden[reference] = nil
            for key, position in pairs(context.displayPositions) do
                if key ~= reference then context.displayPositions[key] = position + 1 end
            end
            context.displayPositions[reference] = 1
        end
    end
    if #created > 0 then InvalidateFCOChanges() end
    if #collisions > 0 then
        this.Utils.UserError("FCO test group names already exist: " .. table.concat(collisions, ", "), "FCO")
    end
    return #created
end

function adapter.AddOverlappingTestGroups()
    assert(this.accountWide.fcoIntegrationState == "enabled", "Enable FCO integration before adding test groups")
    assert(adapter.IsReady(), adapter.GetReadinessReason() or "FCO ItemSaver is not ready")
    local markerIds, unavailable = {}, {}
    local iconSettings = FCOIS.settingsVars.settings.isIconEnabled
    assert(type(iconSettings) == "table", "FCO ItemSaver marker settings are unavailable")
    for markerId, enabled in pairs(iconSettings) do
        if type(markerId) == "number" and markerId >= 1 and markerId < math.huge
            and markerId % 1 == 0 then
            local available, reason = adapter.IsMarkerIdAvailable(markerId)
            if enabled == true and available then
                markerIds[#markerIds + 1] = markerId
            else
                unavailable[#unavailable + 1] = tostring(markerId) .. ": " .. reason
            end
        end
    end
    table.sort(markerIds)
    table.sort(unavailable)
    local definitions = {}
    for _, markerId in ipairs(markerIds) do
        definitions[#definitions + 1] = {
            key = "__ic_fco_test_marker_" .. markerId,
            name = "FCO test marker " .. markerId,
            conditions = { include = { markerId }, exclude = {} },
        }
    end
    if #markerIds > 0 then
        definitions[#definitions + 1] = {
            key = "__ic_fco_test_mixed", name = "FCO test mixed name and marker",
            patterns = { "*map*" }, conditions = { include = { markerIds[1] }, exclude = {} },
        }
        definitions[#definitions + 1] = {
            key = "__ic_fco_test_negative", name = "FCO test negative marker",
            patterns = { "*" }, conditions = { include = {}, exclude = { markerIds[1] } },
        }
    end
    if #markerIds > 1 then
        definitions[#definitions + 1] = {
            key = "__ic_fco_test_multiple", name = "FCO test multiple markers",
            conditions = { include = { markerIds[1], markerIds[2] }, exclude = {} },
        }
    else
        unavailable[#unavailable + 1] = "multiple-marker group requires two available markers"
    end
    local count = adapter.CreateTestGroups(definitions)
    if #unavailable > 0 then
        this.Utils.UserError("FCO test markers unavailable: " .. table.concat(unavailable, "; "), "FCO")
    end
    return count > 0
end

function adapter.RemoveTestGroups()
    local profile = this.GetAutoCategoryProfile()
    local keys = {}
    for _, group in ipairs(groups) do
        keys[group.key] = true
        profile.trackedRules[group.key] = nil
    end
    for _, context in pairs(profile.autoCategoryOrder.contexts) do
        for key in pairs(keys) do
            local reference = "ic:" .. key
            RemoveReference(context.display, reference)
            RemoveReference(context.matching, reference)
            context.hidden[reference] = nil
            context.displayPositions[reference] = nil
        end
    end
    profile.fcoTestGroupsCreated = false
    InvalidateFCOChanges()
    return true
end

local function CollectProfileFCOCleanup(profile, path, cleanup, visited)
    assert(type(profile) == "table", path .. " must be a table")
    if visited[profile] then return end
    visited[profile] = true
    this.ValidateFCOCleanupProfile(profile, path)
    assert(profile.fcoTestGroupsCreated == nil or type(profile.fcoTestGroupsCreated) == "boolean",
        path .. ".fcoTestGroupsCreated must be a boolean")
    if profile.trackedRules ~= nil then
        assert(type(profile.trackedRules) == "table", path .. ".trackedRules must be a table")
    end
    local order = profile.autoCategoryOrder
    if order ~= nil then
        assert(type(order) == "table", path .. ".autoCategoryOrder must be a table")
        local contexts = order.contexts
        if contexts ~= nil then
            assert(type(contexts) == "table", path .. ".autoCategoryOrder.contexts must be a table")
            for contextKey, context in pairs(contexts) do
                local contextPath = path .. ".autoCategoryOrder.contexts." .. tostring(contextKey)
                assert(type(context) == "table", contextPath .. " must be a table")
                for _, mode in ipairs({ "display", "matching" }) do
                    local sequence = context[mode]
                    if sequence ~= nil then
                        assert(type(sequence) == "table", contextPath .. "." .. mode .. " must be a table")
                    end
                end
                for _, field in ipairs({ "hidden", "displayPositions" }) do
                    local values = context[field]
                    if values ~= nil then
                        assert(type(values) == "table", contextPath .. "." .. field .. " must be a table")
                    end
                end
            end
        end
    end
    local keys = {}
    if profile.trackedRules then
        for key, rule in pairs(profile.trackedRules) do
            assert(type(key) == "string" and type(rule) == "table",
                path .. ".trackedRules contains an invalid rule")
            local conditions = rule.markerConditions
            if conditions ~= nil then
                assert(type(conditions) == "table" and type(conditions.include) == "table"
                    and type(conditions.exclude) == "table",
                    path .. ".trackedRules[" .. key .. "].markerConditions is malformed")
                assert(key ~= "miscellaneous"
                    and (not this.preLoadedRulesets[key] or this.preLoadedRulesets[key].isVirtual ~= true),
                    path .. ".trackedRules[" .. key .. "] cannot delete a virtual group")
                keys[key] = true
            elseif this.preLoadedRulesets[key] and this.preLoadedRulesets[key].isFCOGroup then
                keys[key] = true
            end
        end
    end
    cleanup[#cleanup + 1] = { profile = profile, keys = keys }
    if profile.accountWideListBackup ~= nil then
        this.ValidateAccountWideListBackup(profile.accountWideListBackup, path .. ".accountWideListBackup")
        CollectProfileFCOCleanup(profile.accountWideListBackup, path .. ".accountWideListBackup", cleanup, visited)
    end
end

local function RemoveProfileFCOData(profile, keys)
    if profile.trackedRules then
        for key in pairs(keys) do
            local baseline = this.preLoadedRulesets[key]
            if baseline and not baseline.isFCOGroup then
                profile.trackedRules[key] = { deletedBuiltIn = true }
            else
                profile.trackedRules[key] = nil
            end
        end
    end
    local contexts = profile.autoCategoryOrder and profile.autoCategoryOrder.contexts
    if contexts then
        for _, context in pairs(contexts) do
            for key in pairs(keys) do
                local reference = "ic:" .. key
                if context.display then RemoveReference(context.display, reference) end
                if context.matching then RemoveReference(context.matching, reference) end
                if context.hidden then context.hidden[reference] = nil end
                if context.displayPositions then context.displayPositions[reference] = nil end
            end
        end
    end
    profile.fcoTestGroupsCreated = false
end

function adapter.TurnOff()
    local saved = assert(_G[this.SettingsName], "SavedVariables are unavailable")
    assert(type(saved.Default) == "table", "SavedVariables Default must be a table")
    local cleanup, visited = {}, {}
    for accountName, account in pairs(saved.Default) do
        assert(type(account) == "table", "SavedVariables account " .. tostring(accountName) .. " must be a table")
        for profileName, profile in pairs(account) do
            CollectProfileFCOCleanup(profile,
                "SavedVariables.Default." .. tostring(accountName) .. "." .. tostring(profileName),
                cleanup, visited)
        end
    end
    local removed, surviving = {}, {}
    for _, entry in ipairs(cleanup) do
        for key in pairs(entry.keys) do removed[key] = true end
    end
    for key in pairs(removed) do
        local baseline = this.preLoadedRulesets[key]
        for _, entry in ipairs(cleanup) do
            local rule = entry.profile.trackedRules and entry.profile.trackedRules[key]
            if not entry.keys[key] and ((rule and not rule.deletedBuiltIn)
                or (baseline and not baseline.isFCOGroup and not (rule and rule.deletedBuiltIn))) then
                surviving[key] = true
                break
            end
        end
    end
    for key in pairs(surviving) do removed[key] = nil end
    local acRemovals = this.AutoCategoryIntegration.PreflightDeletedFCOGroups(removed)
    for _, entry in ipairs(cleanup) do RemoveProfileFCOData(entry.profile, entry.keys) end
    this.AutoCategoryIntegration.ApplyDeletedFCOGroups(acRemovals)
    this.accountWide.fcoIntegrationState = "off"
    for _, group in ipairs(groups) do
        local baseline = this.preLoadedRulesets[group.key]
        if baseline and baseline.isFCOGroup then this.preLoadedRulesets[group.key] = nil end
    end
    InvalidateFCOChanges()
end
