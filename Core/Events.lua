-- Core/InventoryCompanion_Events.lua
InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local activeListeners = {}

------------------------------------------------------------------
-- Debounce Queue System (Local)
------------------------------------------------------------------
local pendingActions = {}
local callLaterHandle = nil
local DEFAULT_DELAY_MS = 500

local function Enqueue(key, func, delayMs)
    delayMs = delayMs or DEFAULT_DELAY_MS

    if not pendingActions[key] then
        pendingActions[key] = func
    end

    if callLaterHandle then
        zo_removeCallLater(callLaterHandle)
        callLaterHandle = nil
    end

    callLaterHandle = zo_callLater(function()
        callLaterHandle = nil
        
        local executing = pendingActions
        pendingActions = {}

        for _, qFunc in pairs(executing) do
            qFunc()
        end
    end, delayMs)
end

------------------------------------------------------------------
-- Event Conditions & Handlers
------------------------------------------------------------------
local function ShouldListenOpenBank()
    return this.accountWide.autoMergeChests ~= false
end

local function ShouldListenSlotUpdate()
    local showMeters   = this.accountWide.showBagBar or this.accountWide.showBankBar
    local showTracker  = this.accountWide.showTrackedItemsPanel ~= false
    local showCapacity = this.HasVisibleCapacityResources()

    return showMeters or showTracker or showCapacity
end

local function ShouldListenCurrencyUpdates()
    return this.HasCurrencyResourcesToTrack()
end

local function ShouldListenCurrencyCapUpdates()
    return this.HasVisibleCappedCurrencyResources()
end

local function ShouldListenBagCapacity()
    return this.accountWide.showBagBar or this.IsCapacityResourceVisible("bag")
end

local function ShouldListenBankCapacity()
    return this.accountWide.showBankBar or this.IsCapacityResourceVisible("bank")
end

local function OnBankOpened(eventCode, bankType)
    if this.accountWide.autoMergeChests ~= false then
        this.OnBankOpened(eventCode, bankType)
    end
end

local function OnInventorySlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    this.HandleTrackedItemInventoryUpdate(bagId, slotIndex, stackCountChange)

    if this.accountWide.showTrackedItemsPanel ~= false then
        Enqueue("RefreshItemTracker", function()
            this.RefreshItemTrackerPanel()
        end, 500)
    end

    if this.HasVisibleCapacityResources() then
        Enqueue("RefreshCurrency", function()
            this.RefreshCurrencyPanel()
        end, 500)
    end

    if this.accountWide.showBagBar or this.accountWide.showBankBar then
        Enqueue("RefreshProgress", function()
            this.RefreshProgressPanels()
        end, 500)
    end
end

local function OnCurrencyUpdate(eventCode, currencyType, currencyLocation)
    if not this.IsCurrencyResourceVisible(currencyType, currencyLocation) then
        return
    end
    Enqueue("RefreshCurrency", function()
        this.RefreshCurrencyPanel()
        this.UpdateEventRegistry()
    end, 500)
end

local function OnCurrencyCapsChanged()
    if this.HasVisibleCurrencyResources() then
        Enqueue("RefreshCurrency", function()
            this.RefreshCurrencyPanel()
        end, 500)
    end
end

local function OnCapacityChanged()
    Enqueue("RefreshProgress", function()
        this.RefreshProgressPanels()
    end, 500)
    if this.HasVisibleCapacityResources() then
        Enqueue("RefreshCurrency", function()
            this.RefreshCurrencyPanel()
        end, 500)
    end
end

------------------------------------------------------------------
-- Event Registry & Management
------------------------------------------------------------------
local eventRegistry = {
    [EVENT_OPEN_BANK]                    = { name = "OpenBank",     condition = ShouldListenOpenBank,     handler = OnBankOpened },
    [EVENT_INVENTORY_SINGLE_SLOT_UPDATE] = {
        name = "SlotUpdate",
        condition = ShouldListenSlotUpdate,
        handler = OnInventorySlotUpdate,
        filters = {
            { name = "Backpack", value = BAG_BACKPACK },
            { name = "Virtual", value = BAG_VIRTUAL },
            { name = "Bank", value = BAG_BANK },
            { name = "SubscriberBank", value = BAG_SUBSCRIBER_BANK },
        },
    },
    [EVENT_CURRENCY_UPDATE]                = { name = "CurrencyUpdate", condition = ShouldListenCurrencyUpdates, handler = OnCurrencyUpdate },
    [EVENT_CURRENCY_CAPS_CHANGED]          = { name = "CurrencyCapsChanged", condition = ShouldListenCurrencyCapUpdates, handler = OnCurrencyCapsChanged },
    [EVENT_INVENTORY_BAG_CAPACITY_CHANGED] = { name = "BagCapacity",  condition = ShouldListenBagCapacity,  handler = OnCapacityChanged },
    [EVENT_INVENTORY_BANK_CAPACITY_CHANGED]= { name = "BankCapacity", condition = ShouldListenBankCapacity, handler = OnCapacityChanged },
}

function this.UpdateEventRegistry()
    local desiredListeners = {}

    local function AddDesiredListener(eventCode, entry, filter)
        local suffix = filter and ("_" .. filter.name) or ""
        local eventId = string.format("%s_Event_%s%s", this.Name, entry.name, suffix)
        desiredListeners[eventId] = {
            eventCode = eventCode,
            handler = entry.handler,
            filter = filter,
        }
    end

    for eventCode, entry in pairs(eventRegistry) do
        if entry.condition() == true then
            if entry.filters then
                for _, filter in ipairs(entry.filters) do
                    AddDesiredListener(eventCode, entry, filter)
                end
            else
                AddDesiredListener(eventCode, entry)
            end
        end
    end

    for eventId, listener in pairs(desiredListeners) do
        if not activeListeners[eventId] then
            EVENT_MANAGER:RegisterForEvent(eventId, listener.eventCode, listener.handler)
            if listener.filter then
                EVENT_MANAGER:AddFilterForEvent(
                    eventId,
                    listener.eventCode,
                    REGISTER_FILTER_BAG_ID,
                    listener.filter.value
                )
            end
            activeListeners[eventId] = listener.eventCode
        end
    end

    for eventId, eventCode in pairs(activeListeners) do
        if not desiredListeners[eventId] then
            EVENT_MANAGER:UnregisterForEvent(eventId, eventCode)
            activeListeners[eventId] = nil
        end
    end
end

function this.InitCutsceneTicker()
    EVENT_MANAGER:RegisterForUpdate(this.Name .. "_HideCheck", 100, function()
        if ZO_CompassFrame then
            local inCutscene = ZO_CompassFrame:IsHidden()
            local isItemEditorOpen = InventoryCompanion_TrackedItemsWindow and (not InventoryCompanion_TrackedItemsWindow:IsHidden())
            local isGroupEditorOpen = InventoryCompanion_GroupsWindow and (not InventoryCompanion_GroupsWindow:IsHidden())
            local isEditorOpen = isItemEditorOpen or isGroupEditorOpen
        
            local isInteractionOpen = this.Utils.IsItemInteractionActive()

            if InventoryCompanion_ItemTrackerFloat then
                local showTracked = (this.accountWide.showTrackedItemsPanel ~= false)
                local shouldShowTracker = (showTracked and not inCutscene) or isEditorOpen or isInteractionOpen
                InventoryCompanion_ItemTrackerFloat:SetHidden(not shouldShowTracker)

                if shouldShowTracker and isInteractionOpen and this.AdjustTrackerPositionForInteraction then
                    this.AdjustTrackerPositionForInteraction()
                elseif not isEditorOpen and not isInteractionOpen and this.RestoreTrackerPosition then
                    this.RestoreTrackerPosition()
                end
            end

            local showCurrencies = this.HasVisibleCurrencyResources()
            local showCapacities = this.HasVisibleCapacityResources()
            local showInfo = showCurrencies or showCapacities
            local shouldShowCurrencyPanel = this.state.isCurrencySettingsOpen or (showInfo and not inCutscene)
            InventoryCompanion_CurrencyFloat:SetHidden(not shouldShowCurrencyPanel)

            if InventoryCompanion_BagBarFloat then
                InventoryCompanion_BagBarFloat:SetHidden((not this.accountWide.showBagBar) or inCutscene)
            end

            if InventoryCompanion_BankBarFloat then
                InventoryCompanion_BankBarFloat:SetHidden((not this.accountWide.showBankBar) or inCutscene)
            end
        end
    end)
end

function this.DebugAudit()
    local reportLines = { "[IC Events Audit] Checking Registered Engine Listeners..." }

    local totalDefined = 0
    local totalActive  = 0

    local function AuditListener(eventCode, entry, filter)
        local suffix = filter and ("_" .. filter.name) or ""
        local eventId = string.format("%s_Event_%s%s", this.Name, entry.name, suffix)
        local isActive = activeListeners[eventId] == eventCode
        local statusTag = isActive and "|c50c878[ACTIVE]|r" or "|c888888[OFF]|r"
        local listenerName = entry.name .. suffix

        totalDefined = totalDefined + 1
        if isActive then totalActive = totalActive + 1 end
        table.insert(reportLines, string.format("  -> %s %s (Code: %d)", statusTag, listenerName, eventCode))
    end

    for eventCode, entry in pairs(eventRegistry) do
        if entry.filters then
            for _, filter in ipairs(entry.filters) do
                AuditListener(eventCode, entry, filter)
            end
        else
            AuditListener(eventCode, entry)
        end
    end

    table.insert(reportLines, string.format("Audit Summary: %d/%d engine listeners active.", totalActive, totalDefined))
    error(table.concat(reportLines, "\n"), 0)
end