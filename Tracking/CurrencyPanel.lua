InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local COLUMN_COUNT = 3
local CELL_WIDTH = 84
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
        texture = "EsoUI/Art/Tooltips/icon_bag.dds",
    },
}

local currencyCells = {}
local hasVisibleCurrencies = false
local hasVisibleCapacities = false
local hasVisibleCappedCurrencies = false
local malformedPreferenceWarnings = {}
local RESOURCE_SETTINGS_ROW_HEIGHT = 34
local RESOURCE_SETTINGS_ROW_GAP = 6
local ReorderResourceSettingsRows
local resourceSettingsListControl

local function OnCurrencyMoveStop(control)
    this.accountWide.currencyOffsetX = control:GetLeft()
    this.accountWide.currencyOffsetY = control:GetTop()
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

local function IsValidOrder(value)
    return type(value) == "number" and value > 0 and value < math.huge and value == math.floor(value)
end

-- Malformed preference fields are also persisted input: report them and use the documented
-- defaults (discovery order and visible) rather than allowing one bad field to break the panel.
local function GetResourceOrder(entry)
    local preference
    if entry.kind == "currency" then
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
            local preference = GetCurrencyLocationPreference(entry.currencyType, entry.location, true)
            preference.hidden = true
        end
    end
end

local function GetEntryText(entry)
    return this.Utils.FormatBigNumber(entry.amount)
end

local function GetOrCreateCell(index)
    local cell = currencyCells[index]
    if cell then return cell end

    local container = InventoryCompanion_CurrencyFloatContainer
    cell = WINDOW_MANAGER:CreateControl("InventoryCompanion_CurrencyFloatCell" .. index, container, CT_CONTROL)
    cell:SetDimensions(CELL_WIDTH, CELL_HEIGHT)
    cell:SetMouseEnabled(false)

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
    label:SetDimensions(CELL_WIDTH - 26, 20)
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

local function SaveVisibleEntryOrder(visibleEntries, allEntries)
    for index, entry in ipairs(visibleEntries) do
        if entry.kind == "currency" then
            local preference = GetCurrencyLocationPreference(entry.currencyType, entry.location, true)
            preference.order = index
        else
            local preference = GetCapacityPreference(entry.resourceKey, true)
            preference.order = index
        end
    end
    for _, entry in ipairs(allEntries) do
        if not entry.isVisible then
            if entry.kind == "currency" then
                local preference = GetCurrencyLocationPreference(entry.currencyType, entry.location, false)
                if preference then preference.order = nil end
            else
                local preference = GetCapacityPreference(entry.resourceKey, false)
                if preference then preference.order = nil end
            end
        end
    end
end

local function MoveResource(entryKey, direction)
    local entries = GetResourceEntries()
    local visibleEntries = {}
    local currentIndex
    for index, entry in ipairs(entries) do
        if entry.isVisible then
            table.insert(visibleEntries, entry)
            if entry.key == entryKey then currentIndex = #visibleEntries end
        end
    end
    if not currentIndex then return false end

    local targetIndex = currentIndex + direction
    if not visibleEntries[targetIndex] then return false end
    visibleEntries[currentIndex], visibleEntries[targetIndex] = visibleEntries[targetIndex], visibleEntries[currentIndex]
    SaveVisibleEntryOrder(visibleEntries, entries)
    return true
end

local function SetResourceVisibility(entryKey, visible)
    local entries = GetResourceEntries()
    local entry
    local visibleEntries = {}
    for _, resourceEntry in ipairs(entries) do
        if resourceEntry.key == entryKey then
            entry = resourceEntry
        elseif resourceEntry.isVisible then
            table.insert(visibleEntries, resourceEntry)
        end
    end
    assert(entry, "Settings row is missing its resource entry")

    SetEntryPreference(entry, visible)
    if visible then
        table.insert(visibleEntries, entry)
    end
    SaveVisibleEntryOrder(visibleEntries, entries)
end

local function ResetCurrencyPanelPreferences()
    this.accountWide.currencyPreferences = {}
    this.accountWide.capacityPreferences = {}

    for _, entry in ipairs(GetResourceEntries()) do
        if entry.kind == "currency" and entry.currencyType ~= CURT_MONEY then
            local preference = GetCurrencyLocationPreference(entry.currencyType, entry.location, true)
            preference.hidden = true
        end
    end

    ReorderResourceSettingsRows(resourceSettingsListControl)
    this.RefreshCurrencyPanel()
    this.UpdateEventRegistry()
end

function this.IsCurrencyResourceVisible(currencyType, location)
    EnsurePreferences()
    local preference = GetCurrencyLocationPreference(currencyType, location, false)
    return not (preference and preference.hidden == true)
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
    local entries = GetResourceEntries()
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
        local leftName = string.lower(string.format("%s (%s)", left.name, left.locationName or ""))
        local rightName = string.lower(string.format("%s (%s)", right.name, right.locationName or ""))
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
            row.visibilityButton:SetText(shown and "Hide" or "Show")
            row.upButton:SetHidden(not shown)
            row.downButton:SetHidden(not shown)
            row.upButton:SetEnabled(index > 1)
            row.downButton:SetEnabled(index < #resourceEntries)
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

local function CreateResourceSettingsRow(control, entry, resourceList)
    local row = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
    row:SetDimensions(control:GetWidth(), RESOURCE_SETTINGS_ROW_HEIGHT)
    row.resourceEntry = entry
    resourceList.resourceRows[entry.key] = row

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
    name:SetAnchor(RIGHT, row, RIGHT, -151, 0)
    name:SetText(entry.kind == "currency"
        and string.format("%s (%s)", entry.name, entry.locationName)
        or entry.name .. " space")
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

    local visibilityButton = WINDOW_MANAGER:CreateControlFromVirtual(nil, row, "ZO_DefaultButton")
    visibilityButton:SetDimensions(54, 26)
    visibilityButton:SetAnchor(RIGHT, row, RIGHT, -66, 0)
    visibilityButton:SetClickSound("Click")
    visibilityButton:SetHandler("OnClicked", function()
        SetResourceVisibility(entry.key, not IsResourceVisible(entry))
        ReorderResourceSettingsRows(resourceList)
        this.RefreshCurrencyPanel()
        this.UpdateEventRegistry()
    end)
    row.visibilityButton = visibilityButton
end

local function CreateResourceSettingsList(control, entries)
    resourceSettingsListControl = control
    control.resourceRows = {}

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

    for _, entry in ipairs(entries) do
        CreateResourceSettingsRow(control, entry, control)
    end
    ReorderResourceSettingsRows(control)
end

function this.GetCurrencyPanelSettingsControls()
    local entries = this.GetCurrencyPanelResourceEntries()
    local listHeight = (RESOURCE_SETTINGS_ROW_HEIGHT + RESOURCE_SETTINGS_ROW_GAP) * (#entries + 2) + RESOURCE_SETTINGS_ROW_GAP * 2
    local controls = {
        {
            type = "description",
            text = "Choose which entries appear in the Currency Summary Panel. Use the arrows to reorder shown entries. Hidden entries are listed alphabetically.",
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
    InventoryCompanion_CurrencyFloat:ClearAnchors()
    InventoryCompanion_CurrencyFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, this.accountWide.currencyOffsetX or 50, this.accountWide.currencyOffsetY or 150)
    InventoryCompanion_CurrencyFloat:SetHandler("OnMoveStop", OnCurrencyMoveStop)

    this.RefreshCurrencyPanel()
    InventoryCompanion_CurrencyFloatContainer:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            InventoryCompanion_CurrencyFloat:StartMoving()
        end
    end)
end

function this.RefreshCurrencyPanel()
    local panel = InventoryCompanion_CurrencyFloat
    local container = InventoryCompanion_CurrencyFloatContainer

    local entries = {}
    hasVisibleCurrencies = false
    hasVisibleCapacities = false
    hasVisibleCappedCurrencies = false
    for _, entry in ipairs(this.GetCurrencyPanelResourceEntries()) do
        if entry.isVisible then
            table.insert(entries, entry)
            if entry.kind == "currency" then
                hasVisibleCurrencies = true
                if entry.cap ~= nil then
                    hasVisibleCappedCurrencies = true
                end
            else
                hasVisibleCapacities = true
            end
        end
    end

    local rowCount = math.ceil(#entries / COLUMN_COUNT)
    local gridHeight = rowCount > 0 and (rowCount * CELL_HEIGHT + (rowCount - 1) * CELL_GAP_Y) or 0
    container:SetDimensions(COLUMN_COUNT * CELL_WIDTH + (COLUMN_COUNT - 1) * CELL_GAP_X, gridHeight)
    panel:SetDimensions(COLUMN_COUNT * CELL_WIDTH + (COLUMN_COUNT - 1) * CELL_GAP_X + GRID_PADDING_X * 2, gridHeight + GRID_PADDING_Y * 2)

    for index, entry in ipairs(entries) do
        local cell = GetOrCreateCell(index)
        local zeroBasedIndex = index - 1
        local column = zeroBasedIndex % COLUMN_COUNT
        local row = math.floor(zeroBasedIndex / COLUMN_COUNT)
        cell:ClearAnchors()
        cell:SetAnchor(TOPLEFT, container, TOPLEFT, column * (CELL_WIDTH + CELL_GAP_X), row * (CELL_HEIGHT + CELL_GAP_Y))
        cell.icon:SetTexture(entry.texture or "")
        cell.label:SetText(GetEntryText(entry))
        cell:SetHidden(false)
    end
    for index = #entries + 1, #currencyCells do
        currencyCells[index]:SetHidden(true)
    end

    panel:SetHidden(#entries == 0)
end