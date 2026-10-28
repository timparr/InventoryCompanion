-- Tracking/ItemDatabase.lua
InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local itemCountsCache = {}
local cacheInvalid = true
local customDisplayDefaults = {
    show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false,
}

function this.InvalidateRuleCache()
    cacheInvalid = true
end

-- Items
function this.GetActiveTrackedItems()
    if this.character and this.character.useCharacterItemList then
        this.character.trackedItems = this.character.trackedItems or {}
        return this.character.trackedItems
    else
        this.accountWide.trackedItems = this.accountWide.trackedItems or {}
        return this.accountWide.trackedItems
    end
end

------------------------------------------------------------------
-- Rules
------------------------------------------------------------------
local function GetRawSavedRules()
    if this.character.useCharacterItemList then
        this.character.trackedRules = this.character.trackedRules or {}
        return this.character.trackedRules
    else
        this.accountWide.trackedRules = this.accountWide.trackedRules or {}
        return this.accountWide.trackedRules
    end
end

local function PatternSet(patterns)
    local values = {}
    for _, pattern in ipairs(patterns or {}) do
        assert(type(pattern) == "string", "Rule patterns must be strings")
        values[pattern] = true
    end
    return values
end

local function SortedPatterns(values)
    local patterns = {}
    for pattern in pairs(values) do
        table.insert(patterns, pattern)
    end
    table.sort(patterns)
    return patterns
end

local function GetPatternList(base, saved)
    local values = PatternSet(base and base.patterns)
    for _, pattern in ipairs(saved.removedPatterns or {}) do
        values[pattern] = nil
    end
    for _, pattern in ipairs(saved.addedPatterns or {}) do
        values[pattern] = true
    end
    return SortedPatterns(values)
end

local function ReconcilePatterns(base, saved, patterns)
    local defaults = PatternSet(base and base.patterns)
    local edited = PatternSet(patterns)
    local added, removed = {}, {}
    for pattern in pairs(edited) do
        if not defaults[pattern] then added[pattern] = true end
    end
    for pattern in pairs(defaults) do
        if not edited[pattern] then removed[pattern] = true end
    end
    saved.addedPatterns = next(added) and SortedPatterns(added) or nil
    saved.removedPatterns = next(removed) and SortedPatterns(removed) or nil
    saved.patterns = nil
end

local function PruneRule(savedRules, ruleName)
    local saved = savedRules[ruleName]
    if saved.display and not next(saved.display) then saved.display = nil end
    if this.preLoadedRulesets[ruleName] and not next(saved) then
        savedRules[ruleName] = nil
    end
end

local function NormalizeRule(savedRules, ruleName)
    local saved = savedRules[ruleName]
    local base = this.preLoadedRulesets[ruleName]
    if saved.patterns ~= nil then
        ReconcilePatterns(base, saved, saved.patterns)
    end
    local defaultName = base and base.displayName or ruleName
    if saved.displayName == defaultName then saved.displayName = nil end
    local defaults = base and base.display or customDisplayDefaults
    for key, value in pairs(saved.display or {}) do
        if value == defaults[key] then saved.display[key] = nil end
    end
    PruneRule(savedRules, ruleName)
end

function this.GetActiveTrackedRules(includeHidden)
    local savedRules = GetRawSavedRules()
    for ruleName in pairs(savedRules) do NormalizeRule(savedRules, ruleName) end
    local resolvedRules = {}
    local function Resolve(ruleName, base)
        local saved = savedRules[ruleName] or {}
        local display = {}
        for key, value in pairs(base and base.display or customDisplayDefaults) do
            display[key] = value
        end
        for key, value in pairs(saved.display or {}) do display[key] = value end
        if includeHidden or ruleName == "miscellaneous" or not display.isHidden then
            resolvedRules[ruleName] = {
                displayName = saved.displayName or (base and base.displayName) or ruleName,
                patterns = GetPatternList(base, saved),
                display = display,
                isPreloaded = base ~= nil,
            }
        end
    end
    for ruleName, base in pairs(this.preLoadedRulesets) do Resolve(ruleName, base) end
    for ruleName in pairs(savedRules) do
        if not this.preLoadedRulesets[ruleName] then Resolve(ruleName) end
    end
    return resolvedRules
end

function this.UpdateRuleFlag(ruleName, flagKey, value)
    assert(customDisplayDefaults[flagKey] ~= nil, "Unknown rule display flag: " .. tostring(flagKey))
    assert(value == nil or type(value) == "boolean", "Rule display flags must be boolean or nil")
    local savedRules = GetRawSavedRules()
    savedRules[ruleName] = savedRules[ruleName] or {}
    local saved = savedRules[ruleName]
    local base = this.preLoadedRulesets[ruleName]
    local defaults = base and base.display or customDisplayDefaults
    saved.display = saved.display or {}
    if value == defaults[flagKey] then value = nil end
    saved.display[flagKey] = value
    PruneRule(savedRules, ruleName)
    this.InvalidateRuleCache()
end

this.SetRuleFlag = this.UpdateRuleFlag

function this.UpdateRuleProperty(ruleName, propertyKey, value)
    assert(propertyKey == "displayName", "Use UpdateRulePatterns for pattern edits")
    assert(value == nil or type(value) == "string", "Rule display name must be a string or nil")
    local savedRules = GetRawSavedRules()
    savedRules[ruleName] = savedRules[ruleName] or {}
    local base = this.preLoadedRulesets[ruleName]
    if value == (base and base.displayName or ruleName) then value = nil end
    savedRules[ruleName][propertyKey] = value
    PruneRule(savedRules, ruleName)
    this.InvalidateRuleCache()
end

function this.UpdateRulePatterns(ruleName, uiPatterns)
    assert(type(uiPatterns) == "table", "Rule patterns must be a list")
    -- Validate before creating an override, so failed edits leave saved state unchanged.
    PatternSet(uiPatterns)
    local savedRules = GetRawSavedRules()
    savedRules[ruleName] = savedRules[ruleName] or {}
    ReconcilePatterns(this.preLoadedRulesets[ruleName], savedRules[ruleName], uiPatterns)
    PruneRule(savedRules, ruleName)
    this.InvalidateRuleCache()
end

------------------------------------------------------------------
-- Profile Copying Logic
------------------------------------------------------------------
function this.CopyProfile(sourceKey)
    local sv = _G[this.SettingsName]
    if not sv or not sv.Default then return false end

    local sourceBlock = nil

    for _, accData in pairs(sv.Default) do
        if sourceKey == "$AccountWide" then
            if accData["$AccountWide"] then
                sourceBlock = accData["$AccountWide"]
                break
            end
        else
            if accData[sourceKey] then
                sourceBlock = accData[sourceKey]
                break
            end
        end
    end

    local destTable = this.GetActiveTrackedItems()
    local destRules = GetRawSavedRules()

    if sourceBlock and destTable and destRules then
        -- Copy Tracked Items
        ZO_ClearTable(destTable)
        if sourceBlock.trackedItems then
            for itemId, data in pairs(sourceBlock.trackedItems) do
                local srcDisplay = data.display or {}
                local mode = data.mode or 1
                destTable[itemId] = {
                    link = data.link,
                    icon = data.icon,
                    display = {
                        show = srcDisplay.show ~= false or (mode ~= 3),
                        notify = srcDisplay.notify == true or (mode == 2),
                        bank = srcDisplay.bank == true,
                        group = srcDisplay.group == true,
                    },
                }
            end
        end

        -- Copy Tracked Rule Overrides & Custom Rules
        ZO_ClearTable(destRules)
        if sourceBlock.trackedRules then
            for ruleKey, ruleData in pairs(sourceBlock.trackedRules) do -- NEW FOR KEY CHANGE
                local ruleDisplay = ruleData.display or {}
                destRules[ruleKey] = { -- NEW FOR KEY CHANGE
                    displayName = ruleData.displayName, -- NEW FOR KEY CHANGE
                    patterns = ruleData.patterns,
                    display = {
                        show = ruleDisplay.show ~= false,
                        notify = ruleDisplay.notify == true,
                        bank = ruleDisplay.bank == true,
                        group = ruleDisplay.group == true,
                        isExpanded = ruleDisplay.isExpanded,
                        isHidden = ruleDisplay.isHidden == true,
                    }
                }
            end
        end

        return true
    end

    return false
end

------------------------------------------------------------------
-- Pattern Compilation & Matching
------------------------------------------------------------------
local function CompilePatterns(patterns)
    local compiled = {}
    for _, pattern in ipairs(patterns or {}) do
        local cleaned = pattern:lower()
        if cleaned:find("*", 1, true) then
            local p = cleaned:gsub("([%^%$%(%)%%%.%[%+%-%?])", "%%%1")
            p = p:gsub("%*", ".*")
            table.insert(compiled, "^" .. p .. "$")
        else
            local p = cleaned:gsub("([%^%$%(%)%%%.%[%+%-%?])", "%%%1")
            table.insert(compiled, p)
        end
    end
    return compiled
end

function this.ItemMatchesRule(itemLink, pattern)
    local name = GetItemLinkName(itemLink)
    if not name then return false end
    local compiled = CompilePatterns({pattern})
    return name:lower():match(compiled[1]) ~= nil
end

function this.ItemMatchesAnyRule(itemLink, patterns)
    if not patterns then return false end
    for _, pattern in ipairs(patterns) do
        if this.ItemMatchesRule(itemLink, pattern) then
            return true
        end
    end
    return false
end

------------------------------------------------------------------
-- Update Display List
------------------------------------------------------------------

function this.GetTrackedItemCount(itemId)
    if not itemId then return 0 end

    local bagList = { BAG_BACKPACK }
    if IsESOPlusSubscriber() then
        table.insert(bagList, BAG_VIRTUAL)
    end

    local contents = this.Scanning.GetBagContents(bagList, function(item)
        return item.itemId == itemId
    end)

    local total = 0
    for _, item in ipairs(contents) do
        total = total + item.count
    end

    return total
end

function this.HandleTrackedItemInventoryUpdate(bagId, slotIndex, stackCountChange)
    if bagId ~= BAG_BACKPACK and bagId ~= BAG_VIRTUAL then return end

    local itemId = GetItemId(bagId, slotIndex)
    if not itemId or itemId <= 0 then return end

    local itemLink = GetItemLink(bagId, slotIndex)
    if not itemLink or itemLink == "" then return end

    local trackedList = this.GetActiveTrackedItems()
    local trackedRules = this.GetActiveTrackedRules()
    
    local targetData = trackedList[itemId]
    local isNotified = targetData and targetData.display.notify

    if not isNotified then
        for _, ruleData in pairs(trackedRules) do
            local patterns = ruleData.patterns or { ruleData.pattern }
            if (ruleData.display.notify) and this.ItemMatchesAnyRule(itemLink, patterns) then
                isNotified = true
                break
            end
        end
    end

    if isNotified then
        local currentCount = this.GetTrackedItemCount(itemId)
        local gained = (stackCountChange and stackCountChange > 0) and stackCountChange or 0

        if gained <= 0 then
            local previousCount = itemCountsCache[itemId] or currentCount
            gained = currentCount - previousCount
        end

        if gained > 0 then
		
			local formattedCount = this.Utils.FormatBigNumber(currentCount)
			local currentString = tostring(currentCount)

			local messageText = (formattedCount == currentString) and "You now have" or "You have about "

			local hud = string.format("Gained %d x %s. %s %s.", gained, itemLink, messageText, formattedCount)
			local chat = string.format("%d x %s (%s total)", gained, itemLink, currentString)

            this.Utils.UserWarning(chat, hud)
        end

        itemCountsCache[itemId] = currentCount
    end
end

------------------------------------------------------------------
-- Internal Helpers & Scan Engine
------------------------------------------------------------------
local function addToRuleIndex(ruleIndex, ruleName, itemId)
    ruleIndex[ruleName] = ruleIndex[ruleName] or {}
    local list = ruleIndex[ruleName]
    for _, id in ipairs(list) do
        if id == itemId then return end
    end
    table.insert(list, itemId)
end

local function findMatchingRulesCompiled(lowerName, compiledRules)
    local matchedRules = {}
    for ruleName, patterns in pairs(compiledRules) do
        for _, luaPattern in ipairs(patterns) do
            if lowerName:match(luaPattern) ~= nil then
                matchedRules[ruleName] = true
                break
            end
        end
    end
    return matchedRules
end

local function hasAnyMatch(matchedRules)
    for _ in pairs(matchedRules) do return true end
    return false
end

local function updateItemCounts(itemRecord, count, isBank)
    if not isBank then
        itemRecord.bagCount = itemRecord.bagCount + count
    end
    itemRecord.bankCount = itemRecord.bankCount + count
end

local function registerItemRules(itemRecord, ruleIndex, matchedRules, itemId)
    for ruleName in pairs(matchedRules) do
        itemRecord.matchedRules[ruleName] = true
        addToRuleIndex(ruleIndex, ruleName, itemId)
    end
end

local function evaluateAndRecordItem(masterItems, ruleIndex, trackedItems, compiledRules, itemData, isBank)
    local itemId = itemData.itemId
    local link = itemData.link
    local isTracked = trackedItems and trackedItems[itemId] ~= nil

    local itemName = GetItemLinkName(link)
    local lowerName = itemName and itemName:lower() or ""

    local matchedRules = findMatchingRulesCompiled(lowerName, compiledRules)

    if not isTracked and not hasAnyMatch(matchedRules) then return end

    if not masterItems[itemId] then
        masterItems[itemId] = {
            itemId = itemId,
            link = link,
            icon = itemData.icon or GetItemLinkIcon(link),
            bagCount = 0,
            bankCount = 0,
            matchedRules = {},
        }
    end

    local itemRecord = masterItems[itemId]
    updateItemCounts(itemRecord, itemData.count, isBank)
    registerItemRules(itemRecord, ruleIndex, matchedRules, itemId)
end

local function addRescuePassForTrackedItems(masterItems, trackedItems)
    if not trackedItems then return end
    
    for itemId, data in pairs(trackedItems) do
        if not masterItems[itemId] then
            masterItems[itemId] = {
                itemId = itemId,
                link = data.link,
                icon = data.icon or GetItemLinkIcon(data.link),
                bagCount = 0,
                bankCount = 0,
                matchedRules = {},
            }
        end
    end
end

function this.GetMasterItemList(trackedItems, activeRules, bagIdList)
    local masterItems = {}
    local ruleIndex = {}

    local compiledRules = {}
    for ruleName, ruleData in pairs(activeRules) do
        compiledRules[ruleName] = CompilePatterns(ruleData.patterns or { ruleData.pattern })
    end

    for _, bagId in ipairs(bagIdList) do
        local isBank = (bagId ~= BAG_BACKPACK)
        local contents = this.Scanning.GetBagContents({ bagId })
        for _, itemData in ipairs(contents) do
            evaluateAndRecordItem(masterItems, ruleIndex, trackedItems, compiledRules, itemData, isBank)
        end
    end

    addRescuePassForTrackedItems(masterItems, trackedItems)

    return {
        items = masterItems,
        ruleIndex = ruleIndex,
    }
end