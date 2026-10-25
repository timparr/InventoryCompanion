InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local COLUMN_COUNT = 3
local CELL_HEIGHT = 24
local CELL_GAP_X = 8
local CELL_GAP_Y = 4
local GRID_PADDING_X = 10
local GRID_PADDING_Y = 8

local CAPACITIES = {
    bag = {
        name = "Backpack",
        texture = "EsoUI/Art/Tooltips/icon_bag.dds",
    },
    bank = {
        name = "Bank",
        texture = "EsoUI/Art/Tooltips/icon_bank.dds",
    },
}

local currencyCells = {}
local hasVisibleCurrencies = false
local hasCurrencyResourcesToTrack = false
local hasVisibleCapacities = false
local hasVisibleCappedCurrencies = false
local malformedPreferenceWarnings = {}
local RESOURCE_SETTINGS_ROW_HEIGHT = 34
local RESOURCE_SETTINGS_ROW_GAP = 6
local settingsCheckboxControlId = 0
local ReorderResourceSettingsRows
local resourceSettingsListControl

local function OnCurrencyMoveStop(control)
    this.accountWide.currencyOffsetX = control:GetLeft()
    this.accountWide.currencyOffsetY = control:GetTop()
end

local function OnCurrencyPanelMouseUp(_, button)
    if button ~= MOUSE_BUTTON_INDEX_RIGHT then return end

    ClearMenu()
    local showEmptyCurrencies = this.accountWide.showEmptyCurrencies ~= false
    AddCustomMenuItem(
        showEmptyCurrencies and "Hide Zero-Balance Currencies" or "Show Zero-Balance Currencies",
        function()
            this.accountWide.showEmptyCurrencies = not showEmptyCurrencies
            this.RefreshCurrencyPanel()
            this.UpdateEventRegistry()
        end,
        MENU_ADD_OPTION_LABEL
    )
    ShowMenu()
end

local function WarnMalformedPreference(message)
    if malformedPreferenceWarnings[message] then return end
    malformedPreferenceWarnings[message] = true
    d("[InventoryCompanion] Ignoring malformed currency preference: " .. message)
end

-- Saved variables persist across addon versions and can be edited externally, so validate this
-- input boundary; warn and recover only the affected preference tables, preserving other settings.
local function EnsurePreferences()
    if type(this.accountWide.currencyPreferences) ~= "table" then
        if this.accountWide.currencyPreferences ~= nil then
            WarnMalformedPreference("currencyPreferences must be a table")
        end
        this.accountWide.currencyPreferences = {}
    end
    if type(this.accountWide.capacityPreferences) ~= "table" then
        if this.accountWide.capacityPreferences ~= nil then
            WarnMalformedPreference("capacityPreferences must be a table")
        end
        this.accountWide.capacityPreferences = {}
    end
end

local function GetCurrencyLocationPreference(currencyType, location, create)
    local currencyPreferences = this.accountWide.currencyPreferences
    local currencyPreference = currencyPreferences[currencyType]
    if type(currencyPreference) ~= "table" then
        if currencyPreference ~= nil then
            WarnMalformedPreference(string.format("currencyPreferences[%s] must be a table", tostring(currencyType)))
        end
        if not create then return nil end
        currencyPreference = {}
        currencyPreferences[currencyType] = currencyPreference
    end

    local locations = currencyPreference.locations
    if type(locations) ~= "table" then
        if locations ~= nil then
            WarnMalformedPreference(string.format("currencyPreferences[%s].locations must be a table", tostring(currencyType)))
        end
        if not create then return nil end
        locations = {}
        currencyPreference.locations = locations
    end

    local locationPreference = locations[location]
    if type(locationPreference) ~= "table" then
        if locationPreference ~= nil then
            WarnMalformedPreference(string.format("currency preference location %s for ID %s must be a table", tostring(location), tostring(currencyType)))
        end
        if not create then return nil end
        locationPreference = {}
        locations[location] = locationPreference
    end
    return locationPreference
end

local function GetCapacityPreference(resourceKey, create)
    local preferences = this.accountWide.capacityPreferences
    local preference = preferences[resourceKey]
    if type(preference) ~= "table" then
        if preference ~= nil then
            WarnMalformedPreference("capacityPreferences." .. resourceKey .. " must be a table")
        end
        if not create then return nil end
        preference = {}
        preferences[resourceKey] = preference
    end
    return preference
end

local function GetCurrencyPreference(currencyType, create)
    local currencyPreferences = this.accountWide.currencyPreferences
    local preference = currencyPreferences[currencyType]
    if type(preference) ~= "table" then
        if preference ~= nil then
            WarnMalformedPreference(string.format("currencyPreferences[%s] must be a table", tostring(currencyType)))
        end
        if not create then return nil end
        preference = {}
        currencyPreferences[currencyType] = preference
    end
    return preference
end

local function IsValidOrder(value)
    return type(value) == "number" and value > 0 and value < math.huge and value == math.floor(value)
end

-- Malformed preference fields are also persisted input: report them and use the documented
-- defaults (discovery order and visible) rather than allowing one bad field to break the panel.
local function GetResourceOrder(entry)
    local preference
    if entry.kind == "currency" then
        local currencyPreference = GetCurrencyPreference(entry.currencyType, false)
        if currencyPreference and currencyPreference.order ~= nil then
            if not IsValidOrder(currencyPreference.order) then
                WarnMalformedPreference("resource order for currency:" .. tostring(entry.currencyType) .. " must be a positive integer")
            else
                return currencyPreference.order
            end
        end
        preference = GetCurrencyLocationPreference(entry.currencyType, entry.location, false)
    else
        preference = GetCapacityPreference(entry.resourceKey, false)
    end
    if preference and preference.order ~= nil and not IsValidOrder(preference.order) then
        WarnMalformedPreference("resource order for " .. entry.key .. " must be a positive integer")
    end
    return preference and IsValidOrder(preference.order) and preference.order or nil
end

local function IsResourceVisible(entry)
    if entry.kind == "currency" then
        local preference = GetCurrencyLocationPreference(entry.currencyType, entry.location, false)
        if preference and preference.hidden ~= nil and type(preference.hidden) ~= "boolean" then
            WarnMalformedPreference("hidden flag for " .. entry.key .. " must be boolean")
        end
        return not (preference and preference.hidden == true)
    end

    local preference = GetCapacityPreference(entry.resourceKey, false)
    if preference and preference.showCompact ~= nil and type(preference.showCompact) ~= "boolean" then
        WarnMalformedPreference("compact visibility flag for " .. entry.key .. " must be boolean")
    end
    return not (preference and preference.showCompact == false)
end

local function IsCurrencySettingsRowVisible(currencyType)
    local preference = GetCurrencyPreference(currencyType, false)
    if preference and preference.showCompact ~= nil then
        if type(preference.showCompact) ~= "boolean" then
            WarnMalformedPreference("compact visibility flag for currency:" .. tostring(currencyType) .. " must be boolean")
        else
            return preference.showCompact
        end
    end

    for _, location in ipairs({ CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_BANK, CURRENCY_LOCATION_ACCOUNT }) do
        local locationPreference = GetCurrencyLocationPreference(currencyType, location, false)
        if not (locationPreference and locationPreference.hidden == true) then
            return true
        end
    end
    return false
end

local function GetResourceEntries()
    local entries = {}
    local discoveryIndex = 0

    for _, currencyType in ipairs(this.GetCurrencyList()) do
        local summary = this.GetInfo(currencyType)
        assert(summary, "Discovered currency is missing summary information")
        local locations = {}
        if summary.isAccountWide then
            locations[1] = CURRENCY_LOCATION_ACCOUNT
        else
            locations[1] = CURRENCY_LOCATION_CHARACTER
            if summary.canBeStoredInBank then
                locations[2] = CURRENCY_LOCATION_BANK
            end
        end

        for _, location in ipairs(locations) do
            local info = this.GetInfoAtLocation(currencyType, location)
            assert(info, "Discovered currency is missing location information")
            discoveryIndex = discoveryIndex + 1
            table.insert(entries, {
                kind = "currency",
                currencyType = currencyType,
                location = location,
                name = info.name,
                locationName = info.locationName,
                amount = info.amount,
                cap = info.cap,
                texture = info.keyboardTexture,
                discoveryIndex = discoveryIndex,
                key = string.format("currency:%d:%d", currencyType, location),
            })
        end
    end

    for _, resourceKey in ipairs({ "bag", "bank" }) do
        local capacity = CAPACITIES[resourceKey]
        discoveryIndex = discoveryIndex + 1
        table.insert(entries, {
            kind = "capacity",
            resourceKey = resourceKey,
            name = capacity.name,
            texture = capacity.texture,
            discoveryIndex = discoveryIndex,
            key = "capacity:" .. resourceKey,
        })
    end

    for _, entry in ipairs(entries) do
        entry.order = GetResourceOrder(entry)
        entry.isVisible = IsResourceVisible(entry)
    end

    table.sort(entries, function(left, right)
        if left.order and right.order and left.order ~= right.order then
            return left.order < right.order
        elseif left.order ~= nil and right.order == nil then
            return true
        elseif left.order == nil and right.order ~= nil then
            return false
        elseif left.discoveryIndex ~= right.discoveryIndex then
            return left.discoveryIndex < right.discoveryIndex
        end
        return left.key < right.key
    end)

    for index, entry in ipairs(entries) do
        if entry.kind == "capacity" then
            if entry.resourceKey == "bag" then
                entry.amount = GetNumBagUsedSlots(BAG_BACKPACK)
                entry.cap = GetBagSize(BAG_BACKPACK)
            else
                entry.amount = GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK)
                entry.cap = GetBagSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK)
            end
        end
    end
    return entries
end

local function InitializeCurrencyPanelPreferences()
    local isFirstInitialization = this.accountWide.currencyPreferences == nil
    EnsurePreferences()
    if not isFirstInitialization then return end

    -- Keep the existing currency set out by default; currencies discovered in later sessions have no preference and remain visible.
    for _, entry in ipairs(GetResourceEntries()) do
        if entry.kind == "currency" and entry.currencyType ~= CURT_MONEY then
            local preference = GetCurrencyPreference(entry.currencyType, true)
            preference.showCompact = false
            local locationPreference = GetCurrencyLocationPreference(entry.currencyType, entry.location, true)
            locationPreference.hidden = true
        end
    end
end

local function FormatResourceValue(amount, cap)
    local formattedAmount = this.Utils.FormatBigNumber(amount)
    if type(cap) == "number" and cap > 0 then
        local percent = math.floor(amount / cap * 100 + 0.5)
        return string.format("%s (%d%%)", formattedAmount, percent)
    end
    return formattedAmount
end

local function GetCurrencyLocationName(location)
    if location == CURRENCY_LOCATION_CHARACTER then return GetString("SI_CURRENCYLOCATION", CURRENCY_LOCATION_CHARACTER) end
    if location == CURRENCY_LOCATION_BANK then return GetString("SI_CURRENCYLOCATION", CURRENCY_LOCATION_BANK) end
    if location == CURRENCY_LOCATION_ACCOUNT then return GetString("SI_CURRENCYLOCATION", CURRENCY_LOCATION_ACCOUNT) end
    error("Unsupported currency location in compact panel tooltip: " .. tostring(location))
end

local function GetEntryText(entry)
    if entry.kind == "capacity" then
        return FormatResourceValue(entry.amount, entry.cap)
    end

    local values = {}
    for _, locationEntry in ipairs(entry.currencyLocations) do
        table.insert(values, FormatResourceValue(locationEntry.amount, locationEntry.cap))
    end
    return table.concat(values, " · ")
end

local function GetFullResourceAmount(amount)
    return FormatIntegerWithDigitGrouping(amount, ",", 3)
end

local function FormatTooltipAmount(amount, cap)
    local amountText = GetFullResourceAmount(amount)
    if type(cap) == "number" and cap > 0 then
        local percent = math.floor(amount / cap * 100 + 0.5)
        amountText = string.format("%s / %s (%d%%)", amountText, GetFullResourceAmount(cap), percent)
    end
    return amountText
end

local function AddCurrencyLocationTooltipLine(locationEntry)
    local amountText = FormatTooltipAmount(locationEntry.amount, locationEntry.cap)
    local locationName = GetCurrencyLocationName(locationEntry.location)
    InformationTooltip:AddLine(string.format("%s: %s", locationName, amountText), "ZoFontGame", 1, 1, 1, 1)
end

local function ShowCellTooltip(cell)
    local entry = cell.resourceEntry
    if not entry then return end

    InitializeTooltip(InformationTooltip, cell, TOP, 0, -5)
    InformationTooltip:AddLine(entry.name, "ZoFontGame", 1, 1, 1, 1)
    if entry.kind == "currency" then
        for _, locationEntry in ipairs(entry.currencyLocations) do
            AddCurrencyLocationTooltipLine(locationEntry)
        end
    else
        local amountText = FormatTooltipAmount(entry.amount, entry.cap)
        InformationTooltip:AddLine(string.format("Used: %s", amountText), "ZoFontGame", 1, 1, 1, 1)
    end
end

local function HideCellTooltip()
    ClearTooltip(InformationTooltip)
end

local function GetVisibleGridEntries(resourceEntries)
    local currencyEntriesByType = {}
    for _, entry in ipairs(resourceEntries) do
        if entry.kind == "currency" then
            currencyEntriesByType[entry.currencyType] = currencyEntriesByType[entry.currencyType] or {}
            currencyEntriesByType[entry.currencyType][entry.location] = entry
        end
    end

    local gridEntries = {}
    local addedCurrencies = {}
    local function HasPositiveBalance(currencyLocations)
        if this.accountWide.showEmptyCurrencies ~= false then return true end
        for _, locationEntry in ipairs(currencyLocations) do
            if locationEntry.amount > 0 then return true end
        end
        return false
    end

    for _, entry in ipairs(resourceEntries) do
        if entry.kind == "capacity" then
            if entry.isVisible then table.insert(gridEntries, entry) end
        elseif entry.location == CURRENCY_LOCATION_ACCOUNT then
            if IsCurrencySettingsRowVisible(entry.currencyType) then
                local currencyLocations = { entry }
                if HasPositiveBalance(currencyLocations) then
                    table.insert(gridEntries, {
                        kind = "currency",
                        name = entry.name,
                        texture = entry.texture,
                        currencyLocations = currencyLocations,
                    })
                end
            end
        elseif not addedCurrencies[entry.currencyType] then
            addedCurrencies[entry.currencyType] = true
            local currencyLocations = currencyEntriesByType[entry.currencyType]
            local visibleLocations = {}
            if IsCurrencySettingsRowVisible(entry.currencyType) then
                for _, location in ipairs({ CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_BANK }) do
                    local locationEntry = currencyLocations[location]
                    if locationEntry and locationEntry.isVisible then
                        table.insert(visibleLocations, locationEntry)
                    end
                end
                if #visibleLocations > 0 and HasPositiveBalance(visibleLocations) then
                    table.insert(gridEntries, {
                        kind = "currency",
                        name = entry.name,
                        texture = entry.texture,
                        currencyLocations = visibleLocations,
                    })
                end
            end
        end
    end
    return gridEntries
end

local function GetOrCreateCell(index)
    local cell = currencyCells[index]
    if cell then return cell end

    local container = InventoryCompanion_CurrencyFloatContainer
    cell = WINDOW_MANAGER:CreateControl("InventoryCompanion_CurrencyFloatCell" .. index, container, CT_CONTROL)
    cell:SetDimensions(0, CELL_HEIGHT)
    cell:SetMouseEnabled(true)
    cell:SetHandler("OnMouseEnter", ShowCellTooltip)
    cell:SetHandler("OnMouseExit", HideCellTooltip)
    cell:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            InventoryCompanion_CurrencyFloat:StartMoving()
        end
    end)

    local icon = WINDOW_MANAGER:CreateControl("InventoryCompanion_CurrencyFloatCell" .. index .. "Icon", cell, CT_TEXTURE)
    icon:SetDimensions(20, 20)
    icon:SetAnchor(TOPLEFT, cell, TOPLEFT, 0, 2)
    icon:SetDrawLayer(DL_CONTROLS)
    icon:SetDrawLevel(2)
    icon:SetMouseEnabled(false)

    local label = WINDOW_MANAGER:CreateControl("InventoryCompanion_CurrencyFloatCell" .. index .. "Label", cell, CT_LABEL)
    label:SetFont("ZoFontGameMedium")
    label:SetColor(1, 1, 1, 1)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetDimensions(0, 20)
    label:SetAnchor(TOPLEFT, icon, TOPRIGHT, 6, 0)
    label:SetMouseEnabled(false)

    cell.icon = icon
    cell.label = label
    currencyCells[index] = cell
    return cell
end

local function SetEntryPreference(entry, visible)
    if entry.kind == "currency" then
        local preference = GetCurrencyLocationPreference(entry.currencyType, entry.location, true)
        if visible then
            preference.hidden = nil
        else
            preference.hidden = true
        end
    else
        local preference = GetCapacityPreference(entry.resourceKey, true)
        if visible then
            preference.showCompact = nil
        else
            preference.showCompact = false
        end
    end
    entry.isVisible = visible
end

local function GetResourceSettingsRows(entries)
    local rows = {}
    local rowsByKey = {}

    for index, entry in ipairs(entries) do
        local rowKey = entry.kind == "currency"
            and string.format("currency:%d", entry.currencyType)
            or entry.key
        local row = rowsByKey[rowKey]
        if not row then
            row = {
                key = rowKey,
                kind = entry.kind,
                currencyType = entry.currencyType,
                name = entry.name,
                texture = entry.texture,
                entries = {},
                isVisible = false,
                discoveryIndex = index,
            }
            if entry.kind == "currency" then
                row.isVisible = IsCurrencySettingsRowVisible(entry.currencyType)
            else
                row.isVisible = entry.isVisible
            end
            rowsByKey[rowKey] = row
            table.insert(rows, row)
        end
        table.insert(row.entries, entry)
        if entry.order then
            row.orderIndex = row.orderIndex and math.min(row.orderIndex, entry.order) or entry.order
        end
        if entry.kind == "currency" and entry.location == CURRENCY_LOCATION_ACCOUNT then
            row.hasSelectedLocation = row.isVisible
        elseif entry.isVisible then
            row.hasSelectedLocation = true
        end
    end

    table.sort(rows, function(left, right)
        local leftOrder = left.orderIndex or math.huge
        local rightOrder = right.orderIndex or math.huge
        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end
        if left.discoveryIndex ~= right.discoveryIndex then
            return left.discoveryIndex < right.discoveryIndex
        end
        return left.key < right.key
    end)

    return rows
end

local function SaveSettingsRowOrder(shownRows, allEntries)
    local orderedCurrencyTypes = {}
    for index, row in ipairs(shownRows) do
        if row.kind == "currency" then
            local preference = GetCurrencyPreference(row.currencyType, true)
            preference.order = index
            orderedCurrencyTypes[row.currencyType] = true
            for _, entry in ipairs(row.entries) do
                local locationPreference = GetCurrencyLocationPreference(entry.currencyType, entry.location, false)
                if locationPreference then locationPreference.order = nil end
            end
        else
            local preference = GetCapacityPreference(row.entries[1].resourceKey, true)
            preference.order = index
        end
    end

    for _, entry in ipairs(allEntries) do
        if entry.kind == "currency" then
            local preference = GetCurrencyPreference(entry.currencyType, false)
            if preference and not orderedCurrencyTypes[entry.currencyType] then
                preference.order = nil
            end
            local locationPreference = GetCurrencyLocationPreference(entry.currencyType, entry.location, false)
            if locationPreference then locationPreference.order = nil end
        elseif not entry.isVisible then
            local preference = GetCapacityPreference(entry.resourceKey, false)
            if preference then preference.order = nil end
        end
    end
end

local function MoveResource(rowKey, direction)
    local entries = GetResourceEntries()
    local settingsRows = GetResourceSettingsRows(entries)
    local visibleEntries = {}
    local currentIndex
    for _, row in ipairs(settingsRows) do
        if row.isVisible then
            table.insert(visibleEntries, row)
            if row.key == rowKey then currentIndex = #visibleEntries end
        end
    end
    if not currentIndex then return false end

    local targetIndex = currentIndex + direction
    if not visibleEntries[targetIndex] then return false end
    visibleEntries[currentIndex], visibleEntries[targetIndex] = visibleEntries[targetIndex], visibleEntries[currentIndex]

    SaveSettingsRowOrder(visibleEntries, entries)
    return true
end

local function SetCurrencyLocationVisibility(entryKey, visible)
    local entries = GetResourceEntries()
    local entry
    for _, resourceEntry in ipairs(entries) do
        if resourceEntry.key == entryKey then
            entry = resourceEntry
            break
        end
    end
    assert(entry, "Settings checkbox is missing its resource entry")

    SetEntryPreference(entry, visible)
end

local function SetSettingsRowVisibility(row, visible)
    if row.kind == "currency" then
        local preference = GetCurrencyPreference(row.currencyType, true)
        if visible then
            preference.showCompact = nil
        else
            preference.showCompact = false
            preference.order = nil
        end
    else
        SetEntryPreference(row.entries[1], visible)
    end

    local entries = GetResourceEntries()
    local shownRows = {}
    for _, settingsRow in ipairs(GetResourceSettingsRows(entries)) do
        if settingsRow.isVisible then
            table.insert(shownRows, settingsRow)
        end
    end
    if visible then
        local isAlreadyShown = false
        for _, settingsRow in ipairs(shownRows) do
            if settingsRow.key == row.key then
                isAlreadyShown = true
                break
            end
        end
        if not isAlreadyShown then
            table.insert(shownRows, row)
        end
    else
        for index, settingsRow in ipairs(shownRows) do
            if settingsRow.key == row.key then
                table.remove(shownRows, index)
                break
            end
        end
    end
    SaveSettingsRowOrder(shownRows, entries)
end

local function ResetCurrencyPanelPreferences()
    this.accountWide.currencyPreferences = {}
    this.accountWide.capacityPreferences = {}

    for _, entry in ipairs(GetResourceEntries()) do
        if entry.kind == "currency" and entry.currencyType ~= CURT_MONEY then
            local preference = GetCurrencyPreference(entry.currencyType, true)
            preference.showCompact = false
            local locationPreference = GetCurrencyLocationPreference(entry.currencyType, entry.location, true)
            locationPreference.hidden = true
        end
    end

    ReorderResourceSettingsRows(resourceSettingsListControl)
    this.RefreshCurrencyPanel()
    this.UpdateEventRegistry()
end

function this.IsCurrencyResourceVisible(currencyType, location)
    EnsurePreferences()
    if not IsCurrencySettingsRowVisible(currencyType) then return false end
    local preference = GetCurrencyLocationPreference(currencyType, location, false)
    if location == CURRENCY_LOCATION_ACCOUNT then return true end
    return not (preference and preference.hidden == true)
end

function this.IsCurrencyNotificationEnabled(currencyType)
    EnsurePreferences()
    local preference = GetCurrencyPreference(currencyType, false)
    if preference and preference.notify ~= nil and type(preference.notify) ~= "boolean" then
        WarnMalformedPreference("currency notification flag for ID " .. tostring(currencyType) .. " must be boolean")
    end
    return preference ~= nil and preference.notify == true
end

function this.HasCurrencyNotifications()
    for _, currencyType in ipairs(this.GetCurrencyList()) do
        if this.IsCurrencyNotificationEnabled(currencyType) then
            return true
        end
    end
    return false
end

function this.SetCurrencyNotificationEnabled(currencyType, enabled)
    assert(type(enabled) == "boolean", "Currency notification state must be boolean")
    EnsurePreferences()
    local preference = GetCurrencyPreference(currencyType, true)
    preference.notify = enabled and true or nil
    if enabled then
        this.SeedCurrencyNotificationBaselines()
    end
    if next(preference) == nil then
        this.accountWide.currencyPreferences[currencyType] = nil
    end
end

-- Last-known balances per currency/location. ESO reports login balances as changes from 0,
-- so notifications compare against this baseline instead of the event's old amount.
local notificationBaselines = {}

local function GetBaselineKey(currencyType, currencyLocation)
    return tostring(currencyType) .. ":" .. tostring(currencyLocation)
end

function this.SetCurrencyNotificationBaseline(currencyType, currencyLocation, amount)
    notificationBaselines[GetBaselineKey(currencyType, currencyLocation)] = amount
end

function this.SeedCurrencyNotificationBaselines()
    for _, currencyType in ipairs(this.GetCurrencyList()) do
        for _, location in ipairs({ CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_BANK, CURRENCY_LOCATION_ACCOUNT }) do
            this.SetCurrencyNotificationBaseline(currencyType, location, GetCurrencyAmount(currencyType, location))
        end
    end
end

-- ESO re-sends balances after load screens (login, wayshrines), so changes are ignored briefly afterwards.
local LOAD_SUPPRESSION_MS = 5000
local suppressNotificationsUntil = 0

-- Rapid changes (e.g. selling many items) are merged and announced once the balance has been quiet for this long.
local NOTIFICATION_QUIET_MS = 1000
local pendingNotifications = {}

local function FlushCurrencyNotification(key)
    local pending = pendingNotifications[key]
    if not pending then return false end
    pendingNotifications[key] = nil
    if pending.timer then
        zo_removeCallLater(pending.timer)
    end
    if pending.delta == 0 then return false end

    local currencyName = GetCurrencyName(pending.currencyType, false, false)
    local locationName = GetString("SI_CURRENCYLOCATION", pending.currencyLocation)
    local direction = pending.delta > 0 and "Gained" or "Spent"
    local changedText = (this.Utils.FormatBigNumber(math.abs(pending.delta)))
    local totalText = (this.Utils.FormatBigNumber(pending.total))
    this.Utils.UserWarning(
        string.format("%s %s %s (%s total, %s)", direction, changedText, currencyName, totalText, locationName),
        string.format("%s %s %s", direction, changedText, currencyName)
    )
    return true
end

function this.FlushCurrencyNotifications()
    local flushed = false
    local keys = {}
    for key in pairs(pendingNotifications) do
        keys[#keys + 1] = key
    end
    for _, key in ipairs(keys) do
        flushed = FlushCurrencyNotification(key) or flushed
    end
    return flushed
end

function this.BeginCurrencyNotificationSuppression(now)
    suppressNotificationsUntil = (now or GetGameTimeMilliseconds()) + LOAD_SUPPRESSION_MS
    this.SeedCurrencyNotificationBaselines()
    for key, pending in pairs(pendingNotifications) do
        if pending.timer then
            zo_removeCallLater(pending.timer)
        end
        pendingNotifications[key] = nil
    end
end

-- Returns true when the change was queued; the announcement is sent after the quiet period.
function this.NotifyCurrencyChange(currencyType, currencyLocation, newAmount, reason, now)
    if type(newAmount) ~= "number" then return false end

    local key = GetBaselineKey(currencyType, currencyLocation)
    local previousAmount = notificationBaselines[key]
    notificationBaselines[key] = newAmount

    local isInitialReport = CURRENCY_CHANGE_REASON_PLAYER_INIT ~= nil
        and reason == CURRENCY_CHANGE_REASON_PLAYER_INIT
    if isInitialReport
        or (now or GetGameTimeMilliseconds()) < suppressNotificationsUntil
        or previousAmount == nil
        or previousAmount == newAmount
        or not this.IsCurrencyNotificationEnabled(currencyType) then
        return false
    end

    local pending = pendingNotifications[key]
    if not pending then
        pending = { currencyType = currencyType, currencyLocation = currencyLocation, delta = 0 }
        pendingNotifications[key] = pending
    elseif pending.timer then
        zo_removeCallLater(pending.timer)
    end
    pending.delta = pending.delta + (newAmount - previousAmount)
    pending.total = newAmount
    pending.timer = zo_callLater(function()
        pending.timer = nil
        FlushCurrencyNotification(key)
    end, NOTIFICATION_QUIET_MS)
    return true
end

function this.IsCapacityResourceVisible(resourceKey)
    EnsurePreferences()
    local preference = GetCapacityPreference(resourceKey, false)
    return not (preference and preference.showCompact == false)
end

function this.GetCurrencyPanelResourceEntries()
    EnsurePreferences()
    return GetResourceEntries()
end

function this.HasVisibleCurrencyResources()
    return hasVisibleCurrencies
end

function this.HasCurrencyResourcesToTrack()
    return hasCurrencyResourcesToTrack
end

function this.HasVisibleCapacityResources()
    return hasVisibleCapacities
end

function this.HasVisibleCappedCurrencyResources()
    return hasVisibleCappedCurrencies
end

local function RefreshResourceSettingsList(control)
    ReorderResourceSettingsRows(control)
end

local function HighlightResourceSettingsRow(row)
    row.highlightToken = (row.highlightToken or 0) + 1
    local highlightToken = row.highlightToken
    row.highlight:SetHidden(false)
    zo_callLater(function()
        if row.highlightToken == highlightToken then
            row.highlight:SetHidden(true)
        end
    end, 2000)
end

ReorderResourceSettingsRows = function(control)
    local entries = GetResourceSettingsRows(GetResourceEntries())
    local shownEntries = {}
    local hiddenEntries = {}
    for _, entry in ipairs(entries) do
        if entry.isVisible then
            table.insert(shownEntries, entry)
        else
            table.insert(hiddenEntries, entry)
        end
    end
    table.sort(hiddenEntries, function(left, right)
        local leftName = string.lower(left.name)
        local rightName = string.lower(right.name)
        if leftName ~= rightName then
            return leftName < rightName
        end
        return left.key < right.key
    end)

    control.shownHeader:SetText(string.format("Shown in panel (%d)", #shownEntries))
    control.hiddenHeader:SetText(string.format("Not shown in panel (%d)", #hiddenEntries))
    local nextY = RESOURCE_SETTINGS_ROW_HEIGHT + RESOURCE_SETTINGS_ROW_GAP
    local function PlaceRows(resourceEntries, shown)
        for index, entry in ipairs(resourceEntries) do
            local row = control.resourceRows[entry.key]
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, control, TOPLEFT, 0, nextY)
            row.upButton:SetHidden(not shown)
            row.downButton:SetHidden(not shown)
            row.upButton:SetEnabled(index > 1)
            row.downButton:SetEnabled(index < #resourceEntries)
            for _, locationEntry in ipairs(entry.entries) do
                local checkbox = row.locationCheckboxes[locationEntry.key]
                if checkbox then
                    ZO_CheckButton_SetCheckState(checkbox, locationEntry.isVisible)
                end
            end
            if row.notifyCheckbox then
                ZO_CheckButton_SetCheckState(
                    row.notifyCheckbox,
                    this.IsCurrencyNotificationEnabled(row.currencyType)
                )
            end
            row.visibilityButton:SetText(shown and "Hide" or "Show")
            if entry.kind == "currency" and not entry.hasSelectedLocation and shown then
                row.resourceName:SetColor(1, 0.2, 0.2, 1)
            else
                row.resourceName:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
            end
            nextY = nextY + RESOURCE_SETTINGS_ROW_HEIGHT + RESOURCE_SETTINGS_ROW_GAP
        end
    end
    PlaceRows(shownEntries, true)
    nextY = nextY + RESOURCE_SETTINGS_ROW_GAP
    control.hiddenHeader:ClearAnchors()
    control.hiddenHeader:SetAnchor(TOPLEFT, control, TOPLEFT, 0, nextY)
    nextY = nextY + RESOURCE_SETTINGS_ROW_HEIGHT + RESOURCE_SETTINGS_ROW_GAP
    PlaceRows(hiddenEntries, false)
end

local function CreateSettingsCheckbox(row, labelText, width, rightOffset, isChecked, onChanged)
    settingsCheckboxControlId = settingsCheckboxControlId + 1
    local option = WINDOW_MANAGER:CreateControl(nil, row, CT_CONTROL)
    option:SetDimensions(width, 26)
    option:SetAnchor(RIGHT, row, RIGHT, rightOffset, 0)
    option:SetMouseEnabled(true)

    local checkboxName = "InventoryCompanion_CurrencySettingsCheckbox" .. settingsCheckboxControlId
    local checkbox = WINDOW_MANAGER:CreateControlFromVirtual(checkboxName, option, "ZO_CheckButton")
    checkbox:SetDimensions(24, 24)
    checkbox:SetScale(0.8)
    checkbox:SetAnchor(LEFT, option, LEFT, 0, 0)
    ZO_CheckButton_SetLabelText(checkbox, "")
    ZO_CheckButton_SetLabelWidth(checkbox, 0)
    ZO_CheckButton_SetCheckState(checkbox, isChecked)
    ZO_CheckButton_SetToggleFunction(checkbox, function(_, checked)
        onChanged(checked)
    end)
    checkbox:SetClickSound("Click")

    local label = WINDOW_MANAGER:CreateControl(nil, option, CT_LABEL)
    label:SetFont("ZoFontGameSmall")
    label:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetText(labelText)
    label:SetAnchor(LEFT, checkbox, RIGHT, 2, 0)
    label:SetDimensions(width - 30, 24)
    label:SetMouseEnabled(true)
    label:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local checked = not ZO_CheckButton_IsChecked(checkbox)
        ZO_CheckButton_SetCheckState(checkbox, checked)
        onChanged(checked)
    end)
    return checkbox
end

local function CreateResourceSettingsRow(control, entry, resourceList)
    local row = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
    row:SetDimensions(control:GetWidth(), RESOURCE_SETTINGS_ROW_HEIGHT)
    resourceList.resourceRows[entry.key] = row
    row.locationCheckboxes = {}

    local highlight = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
    highlight:SetAnchorFill(row)
    highlight:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds")
    highlight:SetCenterColor(0.9, 0.62, 0.05, 0.8)
    highlight:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
    highlight:SetEdgeColor(1, 0.85, 0.2, 1)
    highlight:SetInsets(4, 4, -4, -4)
    highlight:SetDrawLayer(DL_CONTROLS)
    highlight:SetDrawLevel(-1)
    highlight:SetHidden(true)
    row.highlight = highlight

    local icon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    icon:SetDimensions(24, 24)
    icon:SetAnchor(LEFT, row, LEFT, 0, 0)
    icon:SetTexture(entry.texture or "")
    row.resourceIcon = icon

    local name = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    name:SetFont("ZoFontGame")
    name:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    name:SetAnchor(LEFT, icon, RIGHT, 8, 0)
    local hasLocationCheckboxes = entry.kind == "currency"
        and entry.location ~= CURRENCY_LOCATION_ACCOUNT
    local hasCurrencyNotifications = entry.kind == "currency"
    name:SetAnchor(
        RIGHT,
        row,
        RIGHT,
        hasLocationCheckboxes and -480 or (hasCurrencyNotifications and -245 or -130),
        0
    )
    name:SetText(entry.kind == "currency" and entry.name or entry.name .. " space")
    row.resourceName = name

    local function CreateArrowButton(text, tooltip, direction)
        local button = WINDOW_MANAGER:CreateControlFromVirtual(nil, row, "ZO_DefaultButton")
        button:SetDimensions(28, 26)
        button:SetAnchor(RIGHT, row, RIGHT, direction < 0 and -30 or 0, 0)
        button:SetText(text)
        button.data = { tooltipText = tooltip }
        button:SetClickSound("Click")
        button:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
        button:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
        button:SetHandler("OnClicked", function()
            if MoveResource(entry.key, direction) then
                ReorderResourceSettingsRows(resourceList)
                HighlightResourceSettingsRow(resourceList.resourceRows[entry.key])
                this.RefreshCurrencyPanel()
            end
        end)
        return button
    end

    row.downButton = CreateArrowButton("↓", "Move this entry down in the panel", 1)
    row.upButton = CreateArrowButton("↑", "Move this entry up in the panel", -1)

    if hasCurrencyNotifications then
        row.notifyCheckbox = CreateSettingsCheckbox(
            row,
            "Notify",
            90,
            hasLocationCheckboxes and -390 or -150,
            this.IsCurrencyNotificationEnabled(entry.currencyType),
            function(enabled)
                this.SetCurrencyNotificationEnabled(entry.currencyType, enabled)
                this.UpdateEventRegistry()
            end
        )
    end

    if entry.kind == "currency" then
        local locationOptions = {
            { location = CURRENCY_LOCATION_CHARACTER, label = GetString("SI_CURRENCYLOCATION", CURRENCY_LOCATION_CHARACTER), width = 130, rightOffset = -260 },
            { location = CURRENCY_LOCATION_BANK, label = GetString("SI_CURRENCYLOCATION", CURRENCY_LOCATION_BANK), width = 104, rightOffset = -150 },
        }
        for _, option in ipairs(locationOptions) do
            for _, locationEntry in ipairs(entry.entries) do
                if locationEntry.location == option.location then
                    local locationEntryKey = locationEntry.key
                    row.locationCheckboxes[locationEntry.key] = CreateSettingsCheckbox(
                        row,
                        option.label,
                        option.width,
                        option.rightOffset,
                        locationEntry.isVisible,
                        function(visible)
                            SetCurrencyLocationVisibility(locationEntryKey, visible)
                            ReorderResourceSettingsRows(resourceList)
                            this.RefreshCurrencyPanel()
                            this.UpdateEventRegistry()
                        end
                    )
                end
            end
        end
    end

    local visibilityButton = WINDOW_MANAGER:CreateControlFromVirtual(nil, row, "ZO_DefaultButton")
    visibilityButton:SetDimensions(54, 26)
    visibilityButton:SetAnchor(RIGHT, row, RIGHT, -66, 0)
    visibilityButton:SetClickSound("Click")
    visibilityButton:SetHandler("OnClicked", function()
        local isVisible
        if entry.kind == "currency" then
            isVisible = IsCurrencySettingsRowVisible(entry.currencyType)
        else
            isVisible = this.IsCapacityResourceVisible(entry.resourceKey)
        end
        SetSettingsRowVisibility(entry, not isVisible)
        ReorderResourceSettingsRows(resourceList)
        this.RefreshCurrencyPanel()
        this.UpdateEventRegistry()
    end)
    row.visibilityButton = visibilityButton
end

local function CreateResourceSettingsList(control, entries)
    resourceSettingsListControl = control
    control.resourceRows = {}
    local settingsRows = GetResourceSettingsRows(entries)

    local function CreateHeader(name)
        local header = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        header:SetDimensions(control:GetWidth(), RESOURCE_SETTINGS_ROW_HEIGHT)
        header:SetFont("ZoFontWinH4")
        header:SetColor(ZO_HIGHLIGHT_TEXT:UnpackRGBA())
        header:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        header:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        header:SetText(name)
        return header
    end
    control.shownHeader = CreateHeader("Shown in panel")
    control.hiddenHeader = CreateHeader("Not shown in panel")

    for _, entry in ipairs(settingsRows) do
        CreateResourceSettingsRow(control, entry, control)
    end
    ReorderResourceSettingsRows(control)
end

function this.GetCurrencyPanelSettingsControls()
    local entries = this.GetCurrencyPanelResourceEntries()
    local settingsRows = GetResourceSettingsRows(entries)
    local listHeight = (RESOURCE_SETTINGS_ROW_HEIGHT + RESOURCE_SETTINGS_ROW_GAP) * (#settingsRows + 2) + RESOURCE_SETTINGS_ROW_GAP * 2
    local controls = {
        {
            type = "checkbox",
            name = "Show Empty Currencies",
            tooltip = "If enabled, currencies with a zero balance remain in the panel. Disable this to show only currencies with a positive balance in at least one selected location.",
            getFunc = function() return this.accountWide.showEmptyCurrencies ~= false end,
            setFunc = function(value)
                this.accountWide.showEmptyCurrencies = value
                this.RefreshCurrencyPanel()
                this.UpdateEventRegistry()
            end,
            default = this.defaultsAccount.showEmptyCurrencies,
        },
        {
            type = "description",
            text = "Choose which locations appear for each currency. Click a location label or checkbox to toggle it. Use Notify for alerts on currency changes, Show/Hide to control the row, and arrows to reorder shown resources. A shown currency with no selected locations remains in the list in red but contributes no HUD value. Notifications work even when the currency is not shown in this panel.",
        },
        {
            type = "button",
            name = "Reset Panel",
            tooltip = "Show only gold, backpack space, and bank space. Reset resource ordering; keep the panel position and standalone bars.",
            warning = "This resets compact-grid visibility and ordering to defaults.",
            isDangerous = true,
            func = ResetCurrencyPanelPreferences,
        },
        {
            type = "custom",
            reference = "InventoryCompanion_ResourceSettingsList",
            minHeight = listHeight,
            maxHeight = listHeight,
            createFunc = function(control)
                CreateResourceSettingsList(control, entries)
            end,
            refreshFunc = RefreshResourceSettingsList,
        },
    }

    return controls
end

function this.InitCurrencyPanel()
    InitializeCurrencyPanelPreferences()
    this.SeedCurrencyNotificationBaselines()
    InventoryCompanion_CurrencyFloat:ClearAnchors()
    InventoryCompanion_CurrencyFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, this.accountWide.currencyOffsetX or 50, this.accountWide.currencyOffsetY or 150)
    InventoryCompanion_CurrencyFloat:SetHandler("OnMoveStop", OnCurrencyMoveStop)
    InventoryCompanion_CurrencyFloat:SetHandler("OnMouseUp", OnCurrencyPanelMouseUp)

    this.RefreshCurrencyPanel()
    InventoryCompanion_CurrencyFloatContainer:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            InventoryCompanion_CurrencyFloat:StartMoving()
        end
    end)
    InventoryCompanion_CurrencyFloatContainer:SetHandler("OnMouseUp", OnCurrencyPanelMouseUp)
end

function this.RefreshCurrencyPanel()
    local panel = InventoryCompanion_CurrencyFloat
    local container = InventoryCompanion_CurrencyFloatContainer

    local resourceEntries = this.GetCurrencyPanelResourceEntries()
    hasVisibleCurrencies = false
    hasCurrencyResourcesToTrack = false
    hasVisibleCapacities = false
    hasVisibleCappedCurrencies = false
    for _, entry in ipairs(resourceEntries) do
        if entry.kind == "currency"
            and entry.isVisible
            and IsCurrencySettingsRowVisible(entry.currencyType) then
            hasCurrencyResourcesToTrack = true
            break
        end
    end
    local entries = GetVisibleGridEntries(resourceEntries)
    for _, entry in ipairs(entries) do
        if entry.kind == "currency" then
            hasVisibleCurrencies = true
            for _, locationEntry in ipairs(entry.currencyLocations) do
                if locationEntry.cap ~= nil then
                    hasVisibleCappedCurrencies = true
                end
            end
        else
            hasVisibleCapacities = true
        end
    end

    local columnWidths = { 0, 0, 0 }
    for index, entry in ipairs(entries) do
        local cell = GetOrCreateCell(index)
        cell.label:SetWidth(0)
        cell.label:SetText(GetEntryText(entry))
        local column = (index - 1) % COLUMN_COUNT + 1
        columnWidths[column] = math.max(columnWidths[column], math.ceil(cell.label:GetTextWidth()) + 26)
    end

    local columnCount = math.min(COLUMN_COUNT, #entries)
    local rowCount = math.ceil(#entries / COLUMN_COUNT)
    local gridHeight = rowCount > 0 and (rowCount * CELL_HEIGHT + (rowCount - 1) * CELL_GAP_Y) or 0
    local gridWidth = 0
    for column = 1, columnCount do
        gridWidth = gridWidth + columnWidths[column]
    end
    gridWidth = gridWidth + math.max(0, columnCount - 1) * CELL_GAP_X
    container:SetDimensions(gridWidth, gridHeight)
    panel:SetDimensions(gridWidth + GRID_PADDING_X * 2, gridHeight + GRID_PADDING_Y * 2)

    for index, entry in ipairs(entries) do
        local cell = GetOrCreateCell(index)
        local zeroBasedIndex = index - 1
        local column = zeroBasedIndex % COLUMN_COUNT
        local row = math.floor(zeroBasedIndex / COLUMN_COUNT)
        local columnOffset = 0
        for previousColumn = 1, column do
            columnOffset = columnOffset + columnWidths[previousColumn] + CELL_GAP_X
        end
        cell:ClearAnchors()
        cell:SetDimensions(columnWidths[column + 1], CELL_HEIGHT)
        cell:SetAnchor(TOPLEFT, container, TOPLEFT, columnOffset, row * (CELL_HEIGHT + CELL_GAP_Y))
        cell.icon:SetTexture(entry.texture or "")
        cell.label:SetDimensions(columnWidths[column + 1] - 26, 20)
        cell.label:SetText(GetEntryText(entry))
        cell.resourceEntry = entry
        cell:SetHidden(false)
    end
    for index = #entries + 1, #currencyCells do
        currencyCells[index]:SetHidden(true)
    end

    panel:SetHidden(#entries == 0)
end