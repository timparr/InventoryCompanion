InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local function Check(condition, message)
    if not condition then
        error(message, 2)
    end
end

local function CheckEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

local function CountEntries(values)
    local count = 0
    for _ in pairs(values) do
        count = count + 1
    end
    return count
end

local function PruneDiagnosticSavedVariables(accountWide, character)
    local removedCount = 0
    local visited = {}

    local function RemoveLastQueryKeys(values)
        if type(values) ~= "table" or visited[values] then
            return
        end
        visited[values] = true

        for key, value in pairs(values) do
            if type(key) == "string" and key:lower() == "lastquery" then
                values[key] = nil
                removedCount = removedCount + 1
            elseif type(key) == "string"
                and key:lower() ~= "trackeditems"
                and key:lower() ~= "trackedrules"
                and type(value) == "table" then
                RemoveLastQueryKeys(value)
            end
        end
    end

    RemoveLastQueryKeys(accountWide)
    RemoveLastQueryKeys(character)

    if accountWide.currencyInfo ~= nil then
        accountWide.currencyInfo = nil
        removedCount = removedCount + 1
    end

    return removedCount
end

local function RecordCurrencyName(namesById, currencyType, name, namesChanged)
    local previousName = namesById[currencyType]
    if previousName ~= nil and previousName ~= name then
        Check(type(previousName) == "string", "Saved currency name is invalid for ID " .. currencyType)
        table.insert(namesChanged, string.format(
            "WARN Currency ID %d name changed from '%s' to '%s' (name is localized)",
            currencyType,
            previousName,
            name
        ))
    end
    namesById[currencyType] = name
end

local function AuditCurrencyNames(accountWide)
    local namesById = accountWide.currencyNamesById
    if namesById == nil then
        namesById = {}
        accountWide.currencyNamesById = namesById
    elseif type(namesById) ~= "table" then
        error("Saved currencyNamesById data is not a table")
    end

    local namesChanged = {}
    local currencyCount = 0
    for currencyType = CURT_ITERATION_BEGIN, CURT_ITERATION_END do
        if IsCurrencyValid(currencyType) then
            local name = GetCurrencyName(currencyType, false, false)
            Check(type(name) == "string" and name ~= "", "Currency name is unavailable")
            currencyCount = currencyCount + 1
            RecordCurrencyName(namesById, currencyType, name, namesChanged)
        end
    end

    Check(currencyCount > 0, "No valid currency IDs were found")
    return currencyCount, namesChanged
end

local function RunBankItems(arguments)
    if not this.state or not this.state.isLoaded then
        d("[InventoryCompanion bank items] Addon is not fully loaded.")
        return
    end
    if not IsBankOpen() then
        d("[InventoryCompanion bank items] Open a bank or house chest before running this command.")
        return
    end

    local limitText = tostring(arguments or ""):match("^%s*(.-)%s*$")
    local limit = limitText == "" and 10 or tonumber(limitText)
    if not limit or limit % 1 ~= 0 or limit < 1 or limit > 20 then
        d("[InventoryCompanion bank items] Usage: /icbankitems [1-20]")
        return
    end

    local bags = {
        { id = BAG_BANK, label = "Standard bank" },
        { id = BAG_SUBSCRIBER_BANK, label = "ESO Plus subscriber bank" },
    }

    for _, bag in ipairs(bags) do
        if bag.id ~= BAG_SUBSCRIBER_BANK or IsESOPlusSubscriber() then
            local contents = this.Scanning.GetBagContents({ bag.id })
            d(string.format(
                "[InventoryCompanion bank items] %s: %d occupied slots; listing up to %d.",
                bag.label,
                #contents,
                limit
            ))

            for index = 1, math.min(#contents, limit) do
                local item = contents[index]
                d(string.format(
                    "  x%s %s (item ID %s, slot %s)",
                    tostring(item.count),
                    GetItemLinkName(item.link) or item.link,
                    tostring(item.itemId),
                    tostring(item.slotIndex)
                ))
            end
        else
            d("[InventoryCompanion bank items] ESO Plus subscriber bank unavailable on this account.")
        end
    end
end

local function RunCleanup()
    if not this.state or not this.state.isLoaded then
        d("[InventoryCompanion cleanup] Addon is not fully loaded.")
        return
    end

    local pruneOk, removedDiagnosticCount = pcall(function()
        return PruneDiagnosticSavedVariables(this.accountWide, this.character)
    end)
    if pruneOk then
        d(string.format(
            "[InventoryCompanion cleanup] Removed %d known diagnostic saved-variable entries.",
            removedDiagnosticCount
        ))
    else
        d("[InventoryCompanion cleanup] Failed to prune diagnostic entries: " .. tostring(removedDiagnosticCount))
    end

    local currencyAuditOk, currencyCount, changedCurrencyNames = pcall(function()
        local count, changes = AuditCurrencyNames(this.accountWide)
        return count, changes
    end)
    if currencyAuditOk then
        d(string.format("[InventoryCompanion cleanup] Checked %d valid currency IDs.", currencyCount))
        for _, warning in ipairs(changedCurrencyNames) do
            d("[InventoryCompanion cleanup] " .. warning)
        end
    else
        d("[InventoryCompanion cleanup] Failed to audit currency names: " .. tostring(currencyCount))
    end
end

local function RunTests(arguments)
    if not this.state or not this.state.isLoaded then
        d("[InventoryCompanion tests] Addon is not fully loaded.")
        return
    end

    local options = {}
    for option in tostring(arguments or ""):lower():gmatch("%S+") do
        if option ~= "verbose" and option ~= "copy" then
            d("[InventoryCompanion tests] Usage: /ictest [verbose] [copy]")
            return
        end
        options[option] = true
    end

    local liveScanIterations = 100
    local liveScanLimitMs = 1000
    local liveScanMs
    local liveItemCount
    local bankOpenDuringLiveScan = IsBankOpen()

    local original = {
        getBagContents = this.Scanning.GetBagContents,
        getItemLinkName = _G.GetItemLinkName,
    }

    local results = {}
    local passed = 0

    local liveBagIds = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
    if IsESOPlusSubscriber() then
        table.insert(liveBagIds, BAG_VIRTUAL)
    end

    local scanOk, scanError = pcall(function()
        local startedAt = GetGameTimeMilliseconds()
        for iteration = 1, liveScanIterations do
            local contents = original.getBagContents(liveBagIds)
            if iteration == liveScanIterations then
                liveItemCount = #contents
                for _, itemData in ipairs(contents) do
                    Check(itemData.itemId and itemData.itemId > 0, "Live scan returned an invalid item ID")
                    Check(itemData.link and itemData.link ~= "", "Live scan returned an empty item link")
                    Check(type(itemData.count) == "number", "Live scan returned an invalid stack count")
                end
            end
        end
        liveScanMs = GetGameTimeMilliseconds() - startedAt
    end)

    if scanOk then
        local result = string.format(
            "PASS Live read-only scan: %d scans, %d occupied entries on final scan, bank %s",
            liveScanIterations,
            liveItemCount,
            bankOpenDuringLiveScan and "open" or "closed"
        )
        if liveScanMs > liveScanLimitMs then
            result = string.format(
                "FAIL %s; took %d ms (target <= %d ms)",
                result:sub(6),
                liveScanMs,
                liveScanLimitMs
            )
        else
            passed = passed + 1
        end
        table.insert(results, result)
    else
        table.insert(results, "FAIL Live read-only scan: " .. tostring(scanError))
    end

    local syntheticOriginal = {
        accountWide = this.accountWide,
        character = this.character,
        preLoadedRulesets = this.preLoadedRulesets,
        getBagContents = this.Scanning.GetBagContents,
        getActiveTrackedItems = this.GetActiveTrackedItems,
        getActiveTrackedRules = this.GetActiveTrackedRules,
        getItemLinkName = _G.GetItemLinkName,
        getItemId = _G.GetItemId,
        getItemLink = _G.GetItemLink,
        isESOPlusSubscriber = _G.IsESOPlusSubscriber,
        userWarning = this.Utils.UserWarning,
    }

    local namesByLink = {
        ["item-exact"] = "Mundane Rune",
        ["item-wildcard"] = "Treasure Map: Glenumbra",
        ["item-special"] = "Wayfinder's Kit +1",
    }

    local syntheticBags = {
        [BAG_BACKPACK] = {},
        [BAG_VIRTUAL] = {},
    }
    for index = 1, 100 do
        local link = "synthetic-item-" .. index
        namesByLink[link] = string.format("Synthetic Item %03d", index)
        local bagId = index <= 50 and BAG_BACKPACK or BAG_VIRTUAL
        table.insert(syntheticBags[bagId], {
            bagId = bagId,
            slotIndex = index,
            itemId = 980000 + index,
            link = link,
            icon = "synthetic-icon",
            count = 1,
            maxCount = 200,
        })
    end

    local performanceMs
    local slotMatchMs
    local slotUpdateMs
    local performanceLimitMs = 2000
    local slotMatchLimitMs = 1000
    local slotUpdateLimitMs = 2000
    local environmentOk, environmentError = pcall(function()
        this.accountWide = { trackedRules = {} }
        this.character = { useCharacterItemList = false }
        this.preLoadedRulesets = {}
        this.Scanning.GetBagContents = function(bagIds, selectFunc)
            local contents = {}
            for _, bagId in ipairs(bagIds) do
                for _, itemData in ipairs(syntheticBags[bagId] or {}) do
                    if not selectFunc or selectFunc(itemData) then
                        table.insert(contents, itemData)
                    end
                end
            end
            return contents
        end
        _G.GetItemLinkName = function(itemLink)
            return namesByLink[itemLink]
        end
        _G.GetItemId = function(bagId, slotIndex)
            local itemData = syntheticBags[bagId] and syntheticBags[bagId][slotIndex]
            return itemData and itemData.itemId or 0
        end
        _G.GetItemLink = function(bagId, slotIndex)
            local itemData = syntheticBags[bagId] and syntheticBags[bagId][slotIndex]
            return itemData and itemData.link or ""
        end
        _G.IsESOPlusSubscriber = function()
            return true
        end

        local baselineRules = {
            default = {
                displayName = "Default Group",
                patterns = { "Default *" },
                display = {
                    show = true,
                    notify = false,
                    bank = false,
                    group = true,
                    isExpanded = true,
                    isHidden = false,
                },
            },
            hidden = {
                displayName = "Hidden Group",
                patterns = { "Hidden *" },
                display = { show = true, isHidden = false },
            },
        }

        local tests = {
            {
                name = "Progress bar resource model and preferences",
                run = function()
                    local savedPreferences = this.accountWide.progressBarPreferences
                    local savedAlertColors = this.accountWide.progressBarAlertColors
                    local savedTestValue = this.accountWide.unrelatedProgressTestValue
                    local ok, err = pcall(function()
                        this.accountWide.progressBarPreferences = {}
                        this.accountWide.progressBarAlertColors = {}
                        local resources = this.GetProgressBarResources()
                        local resourcesByKey = {}
                        local capacityCount = 0

                        for _, resource in ipairs(resources) do
                            Check(type(resource.key) == "string" and resource.key ~= "", "Progress resource needs a stable key")
                            Check(not resourcesByKey[resource.key], "Progress resource keys must be unique")
                            resourcesByKey[resource.key] = resource

                            local values = this.GetProgressBarResourceValues(resource)
                            Check(values ~= nil, "Progress resource values should be available")
                            Check(type(values.amount) == "number", "Progress resource amount should be numeric")
                            Check(type(values.cap) == "number" and values.cap > 0, "Progress resource cap should be positive")

                            local settings = this.GetProgressBarSettings(resource.key)
                            Check(type(settings.showBar) == "boolean", "Progress bar visibility default should be boolean")
                            Check(
                                settings.warningThreshold >= 0
                                    and settings.warningThreshold <= settings.dangerThreshold
                                    and settings.dangerThreshold <= 1,
                                "Progress bar thresholds should be ordered within 0 to 1"
                            )

                            if resource.kind == "capacity" then
                                capacityCount = capacityCount + 1
                                CheckEqual(resource.defaultShowBar, true, "Capacity bars should preserve their visible defaults")
                            else
                                CheckEqual(resource.kind, "currency", "Progress resource kind should be capacity or currency")
                                CheckEqual(resource.defaultShowBar, false, "Capped currency bars should default to hidden")
                            end
                        end

                        CheckEqual(capacityCount, 2, "Expected backpack and bank capacity resources")
                        local bag = resourcesByKey["capacity:bag"]
                        local bank = resourcesByKey["capacity:bank"]
                        Check(bag ~= nil and bank ~= nil, "Expected stable backpack and bank resource identities")
                        CheckEqual(this.GetProgressBarSettings(bag.key).warningThreshold, 0.75, "Backpack warning default should be preserved")
                        CheckEqual(this.GetProgressBarSettings(bag.key).dangerThreshold, 0.90, "Backpack danger default should be preserved")
                        CheckEqual(this.GetProgressBarSettings(bank.key).warningThreshold, 0.80, "Bank warning default should be preserved")
                        CheckEqual(this.GetProgressBarSettings(bank.key).dangerThreshold, 0.95, "Bank danger default should be preserved")
                        local originalNormalColor = this.GetProgressBarNormalColor(bag.key)
                        this.SetProgressBarSetting(bag.key, "normalColor", { r = 0.1, g = 0.2, b = 0.3, a = 0.4 })
                        local changedNormalColor = this.GetProgressBarSettings(bag.key).normalColor
                        CheckEqual(changedNormalColor.r, 0.1, "Per-bar normal color should persist")
                        CheckEqual(this.GetProgressBarSettings(bank.key).normalColor, nil, "Per-bar normal colors should be independent")
                        this.SetProgressBarAlertColor("warning", { r = 0.7, g = 0.6, b = 0.2, a = 1 })
                        CheckEqual(this.GetProgressBarAlertColor("warning").g, 0.6, "Shared warning color should persist")
                        CheckEqual(this.GetProgressBarAlertColor("danger").r, 0.85, "Changing warning color should not alter danger color")
                        Check(type(originalNormalColor) == "table", "Default normal color should be available to settings")
                        CheckEqual(this.GetProgressBarSettings(bag.key).offsetX, 50, "Backpack default horizontal position should be stable")
                        CheckEqual(this.GetProgressBarSettings(bag.key).offsetY, 90, "Backpack default vertical position should be stable")
                        CheckEqual(this.GetProgressBarSettings(bank.key).offsetX, 50, "Bank default horizontal position should be stable")
                        CheckEqual(this.GetProgressBarSettings(bank.key).offsetY, 130, "Bank default vertical position should be stable")
                        this.SetProgressBarPosition(bag.key, 25, 35)
                        CheckEqual(this.GetProgressBarSettings(bag.key).offsetX, 25, "Backpack position should persist independently")
                        CheckEqual(this.GetProgressBarSettings(bag.key).offsetY, 35, "Backpack position should persist independently")
                        CheckEqual(this.GetProgressBarSettings(bank.key).offsetY, 130, "Moving backpack should not move bank")

                        for _, currencyType in ipairs(this.GetCappedCurrencyList()) do
                            local key = "currency:" .. tostring(currencyType)
                            Check(resourcesByKey[key] ~= nil, "Every capped ESO currency should have a progress resource")
                            local info = this.GetCappedCurrencyInfo(currencyType)
                            Check(info and type(info.amount) == "number" and type(info.cap) == "number", "Capped currency values should be numeric")
                        end

                        this.accountWide.unrelatedProgressTestValue = "preserved"
                        this.SetProgressBarSetting(bag.key, "showBar", false)
                        CheckEqual(this.GetProgressBarSettings(bag.key).showBar, false, "False visibility overrides should persist")
                        CheckEqual(this.GetProgressBarSettings(bank.key).showBar, true, "Visibility preferences should be independent")
                        for _, resource in ipairs(resources) do
                            if resource.kind == "currency" then
                                this.SetProgressBarSetting(resource.key, "showBar", true)
                                CheckEqual(this.GetProgressBarSettings(resource.key).showBar, true, "Currency bars should be independently configurable")
                                Check(this.HasVisibleCurrencyProgressBars(), "An enabled capped-currency bar should be discoverable by event registration")
                                Check(this.IsCurrencyProgressBarVisible(resource.currencyType), "An enabled capped-currency bar should be individually discoverable")
                                CheckEqual(this.GetProgressBarSettings(bag.key).showBar, false, "Currency preferences should not affect capacity bars")
                                break
                            end
                        end

                        this.SetProgressBarSetting(bag.key, "warningThreshold", 0.96)
                        local settings = this.GetProgressBarSettings(bag.key)
                        CheckEqual(settings.warningThreshold, 0.96, "Warning threshold change should be retained")
                        CheckEqual(settings.dangerThreshold, 0.96, "Crossing warning should move danger to the selected value")
                        this.SetProgressBarSetting(bag.key, "dangerThreshold", 0.20)
                        settings = this.GetProgressBarSettings(bag.key)
                        CheckEqual(settings.warningThreshold, 0.20, "Crossing danger should move warning to the selected value")
                        CheckEqual(settings.dangerThreshold, 0.20, "Danger threshold change should be retained")

                        this.accountWide.progressBarPreferences = {
                            [bag.key] = { showBar = "invalid", warningThreshold = 1.5, dangerThreshold = 0.2 },
                            ["capacity:future"] = { futureSetting = true },
                        }
                        settings = this.GetProgressBarSettings(bag.key)
                        CheckEqual(settings.showBar, true, "Malformed visibility should fall back to the resource default")
                        CheckEqual(settings.warningThreshold, 0.75, "Malformed threshold ordering should fall back to defaults")
                        CheckEqual(settings.dangerThreshold, 0.90, "Malformed threshold ordering should fall back to defaults")
                        CheckEqual(
                            this.accountWide.progressBarPreferences["capacity:future"].futureSetting,
                            true,
                            "Unknown resource preferences should be preserved"
                        )
                        this.accountWide.progressBarPreferences = "malformed"
                        CheckEqual(this.GetProgressBarSettings(bag.key).showBar, true, "Malformed preference tables should use resource defaults")
                        Check(type(this.accountWide.progressBarPreferences) == "table", "Malformed preference tables should be recovered")
                        CheckEqual(this.accountWide.unrelatedProgressTestValue, "preserved", "Unrelated saved variables should remain unchanged")
                    end)
                    this.accountWide.progressBarPreferences = savedPreferences
                    this.accountWide.progressBarAlertColors = savedAlertColors
                    this.accountWide.unrelatedProgressTestValue = savedTestValue
                    if not ok then error(err) end
                end,
            },
            {
                name = "Currency notification preferences and changes",
                run = function()
                    local savedPreferences = this.accountWide.currencyPreferences
                    local savedUserWarning = this.Utils.UserWarning
                    local ok, err = pcall(function()
                        local currencyTypes = this.GetCurrencyList()
                        local currencyType = currencyTypes[1]
                        Check(currencyType ~= nil, "Expected a currency for notification tests")
                        this.accountWide.currencyPreferences = {}
                        local notifications = {}
                        this.Utils.UserWarning = function(chat, hud)
                            table.insert(notifications, { chat = chat, hud = hud })
                        end

                        this.SetCurrencyNotificationEnabled(currencyType, true)
                        Check(this.IsCurrencyNotificationEnabled(currencyType), "Currency notification preference should turn on")
                        Check(this.HasCurrencyNotifications(), "Enabled currency notification should request an event listener")

                        this.BeginCurrencyNotificationSuppression(0)
                        local location = CURRENCY_LOCATION_CHARACTER
                        this.SetCurrencyNotificationBaseline(currencyType, location, 20)
                        Check(
                            not this.NotifyCurrencyChange(currencyType, location, 20),
                            "A login balance matching the baseline should not notify"
                        )
                        Check(not this.FlushCurrencyNotifications(), "Unchanged balances should queue nothing")
                        CheckEqual(#notifications, 0, "Startup balances should not produce notifications")

                        Check(this.NotifyCurrencyChange(currencyType, location, 25), "Positive currency changes should queue")
                        CheckEqual(#notifications, 0, "Changes should be held until the quiet period ends")
                        Check(this.FlushCurrencyNotifications(), "A held change should announce when flushed")
                        CheckEqual(#notifications, 1, "One positive change should produce one notification")
                        Check(notifications[1].chat:find("Gained 5", 1, true) ~= nil, "Gain should identify the amount gained")

                        this.NotifyCurrencyChange(currencyType, location, 20)
                        this.FlushCurrencyNotifications()
                        CheckEqual(#notifications, 2, "A currency decrease should produce a notification")
                        Check(
                            notifications[2].chat:find("Spent 5", 1, true) ~= nil,
                            "Currency decrease notification should identify the amount spent"
                        )

                        this.NotifyCurrencyChange(currencyType, location, 1020)
                        this.NotifyCurrencyChange(currencyType, location, 2020)
                        this.NotifyCurrencyChange(currencyType, location, 12020)
                        CheckEqual(#notifications, 2, "A burst should not announce each change")
                        this.FlushCurrencyNotifications()
                        CheckEqual(#notifications, 3, "A burst should produce one combined notification")
                        Check(
                            notifications[3].chat:find("Gained 12k", 1, true) ~= nil
                                and notifications[3].chat:find("12k total", 1, true) ~= nil,
                            "Combined notification should use big-number formatting for the net change and total"
                        )

                        this.NotifyCurrencyChange(currencyType, location, 13020)
                        this.NotifyCurrencyChange(currencyType, location, 12020)
                        Check(not this.FlushCurrencyNotifications(), "Changes that cancel out should not announce")
                        CheckEqual(#notifications, 3, "Net-zero bursts should add no notifications")

                        local unseededLocation = CURRENCY_LOCATION_BANK
                        this.SetCurrencyNotificationBaseline(currencyType, unseededLocation, nil)
                        Check(
                            not this.NotifyCurrencyChange(currencyType, unseededLocation, 500),
                            "The first observed balance should initialize silently"
                        )
                        CheckEqual(#notifications, 3, "Initializing a balance should not add notifications")

                        this.BeginCurrencyNotificationSuppression(1000)
                        this.SetCurrencyNotificationBaseline(currencyType, location, 20)
                        Check(
                            not this.NotifyCurrencyChange(currencyType, location, 0, nil, 2000),
                            "Balance reports shortly after a load screen should not notify"
                        )
                        Check(
                            not this.NotifyCurrencyChange(currencyType, location, 20, nil, 3000),
                            "Restored balances after a load screen should not notify"
                        )
                        Check(not this.FlushCurrencyNotifications(), "Load-screen reports should queue nothing")
                        Check(
                            this.NotifyCurrencyChange(currencyType, location, 25, nil, 7000),
                            "Changes after the load window should queue"
                        )
                        this.FlushCurrencyNotifications()
                        CheckEqual(#notifications, 4, "A change after the load window should notify")
                        this.SetCurrencyNotificationBaseline(currencyType, location, 20)

                        this.SetCurrencyNotificationEnabled(currencyType, false)
                        Check(not this.HasCurrencyNotifications(), "Disabled currency notifications should release the event listener")
                        this.SetCurrencyNotificationBaseline(currencyType, location, 20)
                        Check(
                            not this.NotifyCurrencyChange(currencyType, location, 30),
                            "Disabled currency notifications should not emit messages"
                        )
                        this.FlushCurrencyNotifications()
                        CheckEqual(#notifications, 4, "Disabled currency notification should not add messages")
                    end)
                    this.FlushCurrencyNotifications()
                    this.SeedCurrencyNotificationBaselines()
                    this.accountWide.currencyPreferences = savedPreferences
                    this.Utils.UserWarning = savedUserWarning
                    if not ok then error(err) end
                end,
            },
            {
                name = "Prune known saved-variable diagnostic keys only",
                run = function()
                    local accountWide = {
                        currencyInfo = { CURT_EVENT_TICKETS = { currencyType = 18 } },
                        nested = { lastquery = { stale = true }, keep = "value" },
                        trackedRules = { keep = true, lastquery = { patterns = { "Last Query*" } } },
                    }
                    local character = {
                        nested = { LastQuery = "stale" },
                        trackedItems = { keep = true },
                    }

                    local removedCount = PruneDiagnosticSavedVariables(accountWide, character)
                    CheckEqual(removedCount, 3, "Only known diagnostic data should be removed")
                    Check(accountWide.currencyInfo == nil, "Currency diagnostic data should be removed")
                    Check(accountWide.nested.lastquery == nil, "Nested lastquery data should be removed")
                    Check(character.nested.LastQuery == nil, "Case-insensitive lastquery data should be removed")
                    CheckEqual(accountWide.nested.keep, "value", "Unrelated account settings should remain")
                    Check(accountWide.trackedRules.keep, "Tracked rules should remain")
                    Check(accountWide.trackedRules.lastquery ~= nil, "A user-created rule named lastquery should remain")
                    Check(character.trackedItems.keep, "Tracked items should remain")

                    local currencyNames = { [42] = "Old Name" }
                    local nameWarnings = {}
                    RecordCurrencyName(currencyNames, 42, "New Name", nameWarnings)
                    CheckEqual(#nameWarnings, 1, "A renamed currency ID should produce one warning")
                    Check(nameWarnings[1]:find("Currency ID 42", 1, true) ~= nil, "Warning should identify the currency ID")
                    CheckEqual(currencyNames[42], "New Name", "Currency name history should track the latest name")
                    RecordCurrencyName(currencyNames, 42, "New Name", nameWarnings)
                    CheckEqual(#nameWarnings, 1, "An unchanged currency name should not warn again")
                end,
            },
            {
                name = "Currency panel resource preferences",
                run = function()
                    local savedCurrencyPreferences = this.accountWide.currencyPreferences
                    local savedCapacityPreferences = this.accountWide.capacityPreferences
                    local ok, err = pcall(function()
                        this.accountWide.currencyPreferences = {}
                        this.accountWide.capacityPreferences = {}

                        local entries = this.GetCurrencyPanelResourceEntries()
                        Check(#entries > 0, "Expected currency and capacity resources")

                        local currencyEntry
                        for _, entry in ipairs(entries) do
                            Check(entry.isVisible, "Resources should be visible by default")
                            if entry.kind == "currency" and not currencyEntry then
                                currencyEntry = entry
                            elseif entry.kind == "capacity" then
                                CheckEqual(
                                    this.IsCapacityResourceVisible(entry.resourceKey),
                                    true,
                                    "Capacity resources should be visible by default"
                                )
                            end
                        end
                        Check(currencyEntry ~= nil, "Expected a discovered currency resource")

                        this.accountWide.capacityPreferences.bag = { showCompact = false }
                        CheckEqual(this.IsCapacityResourceVisible("bag"), false, "A hidden backpack capacity should report hidden")
                        this.accountWide.capacityPreferences.bag.showCompact = nil
                        CheckEqual(this.IsCapacityResourceVisible("bag"), true, "A shown backpack capacity should report visible")

                        this.accountWide.currencyPreferences[currencyEntry.currencyType] = {
                            locations = {
                                [currencyEntry.location] = { hidden = true },
                            },
                        }
                        local hiddenCount = 0
                        for _, entry in ipairs(this.GetCurrencyPanelResourceEntries()) do
                            if entry.key == currencyEntry.key then
                                Check(not entry.isVisible, "Hiding one currency location should hide that entry")
                                hiddenCount = hiddenCount + 1
                            else
                                Check(entry.isVisible, "Hiding one currency location should not affect other resources")
                            end
                        end
                        CheckEqual(hiddenCount, 1, "Expected exactly one matching currency location")

                        this.accountWide.currencyPreferences = {}
                        this.accountWide.capacityPreferences = {}
                        local function SetTestOrder(entry, order)
                            if entry.kind == "currency" then
                                this.accountWide.currencyPreferences[entry.currencyType] = {
                                    locations = { [entry.location] = { order = order } },
                                }
                            else
                                this.accountWide.capacityPreferences[entry.resourceKey] = { order = order }
                            end
                        end
                        SetTestOrder(entries[1], 2)
                        SetTestOrder(entries[2], 1)
                        local orderedEntries = this.GetCurrencyPanelResourceEntries()
                        CheckEqual(orderedEntries[1].key, entries[2].key, "Explicit resource order should be applied")
                        CheckEqual(orderedEntries[2].key, entries[1].key, "Explicit resource order should be deterministic")
                    end)
                    this.accountWide.currencyPreferences = savedCurrencyPreferences
                    this.accountWide.capacityPreferences = savedCapacityPreferences
                    if not ok then error(err) end
                end,
            },
            {
                name = "Live currency helper API",
                run = function()
                    local currencyTypes = this.GetCurrencyList()
                    local seenCurrencyTypes = {}
                    Check(#currencyTypes > 0, "Expected at least one displayable currency")

                    for _, currencyType in ipairs(currencyTypes) do
                        Check(IsCurrencyValid(currencyType), "Currency list contains an invalid currency type")
                        Check(not seenCurrencyTypes[currencyType], "Currency list contains a duplicate type")
                        seenCurrencyTypes[currencyType] = true

                        local info = this.GetInfo(currencyType)
                        Check(info ~= nil, "Expected current information for every listed currency")
                        Check(type(info.name) == "string" and info.name ~= "", "Currency name should be available")
                        Check(type(info.amount) == "number", "Currency amount should be numeric")
                        Check(type(info.locationName) == "string", "Currency location name should be available")

                        local characterAmount, totalAmount = this.GetTotalInfo(currencyType)
                        Check(type(totalAmount) == "number", "Currency total should be numeric")
                        if info.isAccountWide then
                            Check(characterAmount == nil, "Account-wide currency should not have a character total")
                            CheckEqual(totalAmount, info.amount, "Account-wide total should match current amount")
                        else
                            Check(type(characterAmount) == "number", "Character currency amount should be numeric")
                            Check(totalAmount >= characterAmount, "Currency total should include character amount")
                        end

                        local capInfo = this.GetCapInfo(currencyType)
                        if info.cap ~= nil then
                            Check(capInfo ~= nil, "Capped currency should return cap information")
                            CheckEqual(capInfo.amount, info.amount, "Cap amount should match current amount")
                            CheckEqual(capInfo.cap, info.cap, "Cap information should match currency information")
                            Check(type(this.IsCurrencyNearCap(currencyType)) == "boolean", "Near-cap query should return a boolean")
                        else
                            Check(capInfo == nil, "Uncapped currency should not return cap information")
                        end
                    end

                    for currencyType = CURT_ITERATION_BEGIN, CURT_ITERATION_END do
                        if IsCurrencyValid(currencyType) and ShouldShowCurrencyInCurrencyPanel(currencyType) then
                            Check(seenCurrencyTypes[currencyType], "A displayable currency is missing from the helper list")
                        end
                    end
                end,
            },
            {
                name = "Case-insensitive substring matching",
                run = function()
                    Check(this.ItemMatchesRule("item-exact", "mundane rune"), "Expected case-insensitive exact match")
                    Check(this.ItemMatchesRule("item-exact", "mundane"), "Expected plain text patterns to match substrings")
                end,
            },
            {
                name = "Wildcard matching",
                run = function()
                    Check(this.ItemMatchesRule("item-wildcard", "Treasure Map:*"), "Expected wildcard match")
                    Check(not this.ItemMatchesRule("item-wildcard", "Treasure * Grahtwood"), "Unexpected wildcard match")
                end,
            },
            {
                name = "Literal punctuation and missing names",
                run = function()
                    Check(this.ItemMatchesRule("item-special", "Wayfinder's Kit +1"), "Expected punctuation to be matched literally")
                    Check(not this.ItemMatchesRule("item-special", "Wayfinder's Kit 1"), "Expected plus sign to be significant")
                    Check(not this.ItemMatchesRule("missing-item", "Anything"), "Missing item name should not match")
                end,
            },
            {
                name = "Any-pattern matching",
                run = function()
                    Check(this.ItemMatchesAnyRule("item-wildcard", { "No Match", "Treasure Map:*" }), "Expected one matching pattern")
                    Check(not this.ItemMatchesAnyRule("item-wildcard", { "No Match", "Still No Match" }), "Unexpected any-pattern match")
                    Check(not this.ItemMatchesAnyRule("item-wildcard", nil), "Nil pattern list should not match")
                end,
            },
            {
                name = "Baseline and saved-rule override resolution",
                run = function()
                    this.preLoadedRulesets = baselineRules
                    this.accountWide = {
                        trackedRules = {
                            default = { displayName = "Renamed", display = { show = false } },
                            hidden = { display = { isHidden = true } },
                            custom = { patterns = { "Custom *" } },
                        },
                    }

                    local activeRules = this.GetActiveTrackedRules()
                    CheckEqual(activeRules.default.displayName, "Renamed", "Saved display-name override should apply")
                    CheckEqual(activeRules.default.patterns[1], "Default *", "Unmodified patterns should come from the baseline")
                    CheckEqual(activeRules.default.display.show, false, "Saved display flag should apply")
                    CheckEqual(activeRules.default.display.notify, false, "Unmodified display flag should remain at baseline")
                    Check(activeRules.hidden == nil, "Hidden rule should be filtered by default")
                    CheckEqual(activeRules.custom.displayName, "custom", "Custom rule should use its key as the default name")
                    CheckEqual(activeRules.custom.display.show, true, "Custom rule should receive default display settings")
                    Check(this.GetActiveTrackedRules(true).hidden ~= nil, "includeHidden should retain hidden rules")
                    CheckEqual(baselineRules.default.displayName, "Default Group", "Reading overrides must not mutate the baseline")
                end,
            },
            {
                name = "Display-flag writes preserve other overrides",
                run = function()
                    this.accountWide = {
                        trackedRules = {
                            default = {
                                displayName = "Existing Name",
                                patterns = { "Existing *" },
                                display = { notify = false },
                            },
                        },
                    }

                    this.SetRuleFlag("default", "show", true)
                    local savedRule = this.accountWide.trackedRules.default
                    CheckEqual(savedRule.displayName, "Existing Name", "Flag update should preserve display name")
                    CheckEqual(savedRule.patterns[1], "Existing *", "Flag update should preserve patterns")
                    CheckEqual(savedRule.display.notify, false, "Flag update should preserve other flags")
                    CheckEqual(savedRule.display.show, true, "Flag update should write selected flag")
                    CheckEqual(CountEntries(savedRule), 3, "Flag update should not add unrelated root properties")
                    CheckEqual(CountEntries(savedRule.display), 2, "Flag update should not add unrelated display flags")
                end,
            },
            {
                name = "100-item backpack and craft-bag scan",
                run = function()
                    local rules = {
                        synthetic = { patterns = { "Synthetic Item *" } },
                    }
                    local snapshot = this.GetMasterItemList({}, rules, { BAG_BACKPACK, BAG_VIRTUAL })
                    CheckEqual(CountEntries(snapshot.items), 100, "Every synthetic item should be included")
                    CheckEqual(#snapshot.ruleIndex.synthetic, 100, "Every synthetic item should be indexed under its rule")

                    local bagCount = 0
                    local bankCount = 0
                    for _, item in pairs(snapshot.items) do
                        bagCount = bagCount + item.bagCount
                        bankCount = bankCount + item.bankCount
                    end
                    CheckEqual(bagCount, 50, "Only backpack items should contribute to the backpack count")
                    CheckEqual(bankCount, 100, "The overall total should include backpack and craft-bag items")
                end,
            },
            {
                name = "Repeated 100-item inventory scan performance",
                run = function()
                    local rules = {}
                    for index = 1, 20 do
                        rules["synthetic-" .. index] = { patterns = { "Synthetic Item *" } }
                    end

                    local startedAt = GetGameTimeMilliseconds()
                    for _ = 1, 20 do
                        local snapshot = this.GetMasterItemList({}, rules, { BAG_BACKPACK, BAG_VIRTUAL })
                        CheckEqual(CountEntries(snapshot.items), 100, "Repeated scan should retain all synthetic items")
                    end
                    performanceMs = GetGameTimeMilliseconds() - startedAt
                    Check(
                        performanceMs <= performanceLimitMs,
                        string.format("20 scans of 100 items across 20 rules took %d ms (limit %d ms)", performanceMs, performanceLimitMs)
                    )
                end,
            },
            {
                name = "100 repeated slot-rule matches",
                run = function()
                    local startedAt = GetGameTimeMilliseconds()
                    for index = 1, 100 do
                        Check(
                            this.ItemMatchesAnyRule("synthetic-item-" .. index, { "Synthetic Item *" }),
                            "Synthetic slot update should match its tracked rule"
                        )
                    end
                    slotMatchMs = GetGameTimeMilliseconds() - startedAt
                    Check(
                        slotMatchMs <= slotMatchLimitMs,
                        string.format("100 slot-rule matches took %d ms (limit %d ms)", slotMatchMs, slotMatchLimitMs)
                    )
                end,
            },
            {
                name = "100 synthetic tracked-item slot updates",
                run = function()
                    local warningCount = 0
                    this.GetActiveTrackedItems = function()
                        return {}
                    end
                    this.GetActiveTrackedRules = function()
                        return {
                            synthetic = {
                                patterns = { "Synthetic Item *" },
                                display = { notify = true },
                            },
                        }
                    end
                    this.Utils.UserWarning = function()
                        warningCount = warningCount + 1
                    end

                    local startedAt = GetGameTimeMilliseconds()
                    for index = 1, 100 do
                        local bagId = index <= 50 and BAG_BACKPACK or BAG_VIRTUAL
                        local slotIndex = index <= 50 and index or index - 50
                        this.HandleTrackedItemInventoryUpdate(bagId, slotIndex, 1)
                    end
                    slotUpdateMs = GetGameTimeMilliseconds() - startedAt

                    CheckEqual(warningCount, 100, "Every matching synthetic slot update should trigger a notification")
                    Check(
                        slotUpdateMs <= slotUpdateLimitMs,
                        string.format(
                            "100 tracked-item slot updates took %d ms (limit %d ms)",
                            slotUpdateMs,
                            slotUpdateLimitMs
                        )
                    )
                end,
            },
        }

        for _, test in ipairs(tests) do
            local ok, err = pcall(test.run)
            if ok then
                passed = passed + 1
                table.insert(results, "PASS " .. test.name)
            else
                table.insert(results, "FAIL " .. test.name .. ": " .. tostring(err))
            end
        end
    end)

    this.accountWide = syntheticOriginal.accountWide
    this.character = syntheticOriginal.character
    this.preLoadedRulesets = syntheticOriginal.preLoadedRulesets
    this.Scanning.GetBagContents = syntheticOriginal.getBagContents
    this.GetActiveTrackedItems = syntheticOriginal.getActiveTrackedItems
    this.GetActiveTrackedRules = syntheticOriginal.getActiveTrackedRules
    _G.GetItemLinkName = syntheticOriginal.getItemLinkName
    _G.GetItemId = syntheticOriginal.getItemId
    _G.GetItemLink = syntheticOriginal.getItemLink
    _G.IsESOPlusSubscriber = syntheticOriginal.isESOPlusSubscriber
    this.Utils.UserWarning = syntheticOriginal.userWarning

    if not environmentOk then
        table.insert(results, "FAIL test setup: " .. tostring(environmentError))
    end

    local total = 0
    for _, result in ipairs(results) do
        if result:sub(1, 5) ~= "WARN " then
            total = total + 1
        end
    end
    local summary
    if performanceMs and slotMatchMs and slotUpdateMs then
        summary = string.format(
            "[InventoryCompanion tests] %d/%d passed; 20 x 100-item scans / 20 rules: %d/%d ms; 100 slot-rule matches: %d/%d ms; 100 tracked-item slot updates: %d/%d ms%s",
            passed,
            total,
            performanceMs,
            performanceLimitMs,
            slotMatchMs,
            slotMatchLimitMs,
            slotUpdateMs,
            slotUpdateLimitMs,
            string.format(
                "; 100 live backpack/bank%s scans (bank %s): %d/%d ms, %d occupied entries",
                IsESOPlusSubscriber() and "/craft-bag" or "",
                bankOpenDuringLiveScan and "open" or "closed",
                liveScanMs or 0,
                liveScanLimitMs,
                liveItemCount or 0
            )
        )
    else
        summary = string.format("[InventoryCompanion tests] %d/%d passed.", passed, total)
    end

    local reportLines = { summary }
    for _, result in ipairs(results) do
        table.insert(reportLines, "[InventoryCompanion tests] " .. result)
    end

    local hasFailures = passed < total
    if options.copy or hasFailures then
        error(table.concat(reportLines, "\n"), 0)
    elseif options.verbose then
        for _, reportLine in ipairs(reportLines) do
            d(reportLine)
        end
    else
        d(summary)
        for _, result in ipairs(results) do
            if result:sub(1, 5) == "FAIL " or result:sub(1, 5) == "WARN " then
                d("[InventoryCompanion tests] " .. result)
            end
        end
    end
end

this.RunTests = RunTests
SLASH_COMMANDS["/ictest"] = RunTests
SLASH_COMMANDS["/icclean"] = RunCleanup
SLASH_COMMANDS["/icbankitems"] = RunBankItems
