-- Core/InventoryCompanion_Events.lua
InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local activeListeners = {}
local visibilityTickerActive = false

------------------------------------------------------------------
-- Debounce Queue System (Local)
------------------------------------------------------------------
local pendingActions = {}
local callLaterHandle = nil
local DEFAULT_DELAY_MS = 500

local function SchedulePendingActions(delayMs)
    if callLaterHandle or next(pendingActions) == nil then return end
    callLaterHandle = zo_callLater(function()
        callLaterHandle = nil
        local executing = pendingActions
        pendingActions = {}
        for _, action in pairs(executing) do
            if action.stillNeeded() then action.run() end
        end
    end, delayMs)
end

local function Enqueue(key, func, delayMs, stillNeeded)
    assert(type(stillNeeded) == "function", "Queued refresh requires a current-consumer predicate")
    delayMs = delayMs or DEFAULT_DELAY_MS
    pendingActions[key] = { run = func, stillNeeded = stillNeeded }
    SchedulePendingActions(delayMs)
end

local function PrunePendingActions()
    for key, action in pairs(pendingActions) do
        if not action.stillNeeded() then pendingActions[key] = nil end
    end
    if next(pendingActions) == nil and callLaterHandle then
        zo_removeCallLater(callLaterHandle)
        callLaterHandle = nil
    end
end

------------------------------------------------------------------
-- Event Conditions & Handlers
------------------------------------------------------------------
local function ShouldListenOpenBank()
    return this.accountWide.autoMergeChests ~= false
end

local function ShouldListenSlotUpdate()
    local showMeters   = this.HasVisibleProgressBars()
    local showTracker  = this.GetPanelSettings("Tracker").showTrackedItemsPanel ~= false
    local showCapacity = this.HasVisibleCapacityResources()

    return showMeters or showTracker or showCapacity or this.HasCapacityNotifications()
        or this.HasTrackedItemNotifications()
end

local function ShouldListenFullInventoryUpdate()
    return this.GetPanelSettings("Tracker").showTrackedItemsPanel ~= false
end

local function ShouldListenCurrencyUpdates()
    return this.HasCurrencyResourcesToTrack()
        or this.HasVisibleCurrencyProgressBars()
        or this.HasCurrencyNotifications()
end

local function ShouldListenCurrencyCapUpdates()
    return this.HasVisibleCappedCurrencyResources() or this.HasVisibleCappedProgressBars()
end

local function ShouldListenBagCapacity()
    return this.IsProgressBarVisible("capacity:bag") or this.IsCapacityResourceVisible("bag")
end

local function ShouldListenBankCapacity()
    return this.IsProgressBarVisible("capacity:bank") or this.IsCapacityResourceVisible("bank")
end

local function OnBankOpened(eventCode, bankType)
    if this.accountWide.autoMergeChests ~= false then
        this.OnBankOpened(eventCode, bankType)
    end
end

local function OnInventorySlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    this.HandleTrackedItemInventoryUpdate(bagId, slotIndex, stackCountChange)

    if this.HasCapacityNotifications() then
        local eventKind = bagId == BAG_BACKPACK and "bag"
            or ((bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK) and "bank" or nil)
        this.NotifyLiveCapacityChanges(nil, eventKind, stackCountChange)
    end

    if this.GetPanelSettings("Tracker").showTrackedItemsPanel ~= false then
        this.QueueTrackerSlotUpdate(bagId, slotIndex)
    end

    if this.HasVisibleCapacityResources() then
        Enqueue("RefreshCurrencyFromSlot", function()
            if this.HasVisibleCapacityResources() then this.RefreshCurrencyPanel() end
        end, 500, this.HasVisibleCapacityResources)
    end

    if this.HasVisibleProgressBars() then
        Enqueue("RefreshProgressFromSlot", function()
            if this.HasVisibleProgressBars() then this.RefreshResourceProgressBars() end
        end, 500, this.HasVisibleProgressBars)
    end
end

local function OnFullInventoryUpdate()
    if this.GetPanelSettings("Tracker").showTrackedItemsPanel ~= false then
        this.NoteTrackerFullInventoryUpdate()
    end
end

local function OnCurrencyUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
    this.NotifyCurrencyChange(currencyType, currencyLocation, newAmount, reason)
    local function ShouldRefresh()
        return this.IsCurrencyResourceVisible(currencyType, currencyLocation)
            or this.IsCurrencyProgressBarVisible(currencyType)
    end
    if not ShouldRefresh() then
        return
    end
    Enqueue("RefreshFromCurrencyUpdate", function()
        if this.IsCurrencyResourceVisible(currencyType, currencyLocation) then this.RefreshCurrencyPanel() end
        if this.IsCurrencyProgressBarVisible(currencyType) then this.RefreshResourceProgressBars() end
        this.UpdateEventRegistry()
    end, 500, ShouldRefresh)
end

local function OnCurrencyCapsChanged()
    if this.HasVisibleCurrencyResources() or this.HasVisibleCappedProgressBars() then
        local function ShouldRefresh()
            return this.HasVisibleCurrencyResources() or this.HasVisibleCappedProgressBars()
        end
        Enqueue("RefreshFromCurrencyCaps", function()
            this.RefreshProgressBarResourceDiscovery()
            if this.HasVisibleCurrencyResources() then
                this.RefreshCurrencyPanel()
            end
            if this.HasVisibleCappedProgressBars() then this.RefreshResourceProgressBars() end
            this.UpdateEventRegistry()
        end, 500, ShouldRefresh)
    end
end

local function OnCapacityChanged()
    Enqueue("RefreshProgressFromCapacity", function()
        if this.HasVisibleProgressBars() then this.RefreshResourceProgressBars() end
    end, 500, this.HasVisibleProgressBars)
    if this.HasVisibleCapacityResources() then
        Enqueue("RefreshCurrencyFromCapacity", function()
            if this.HasVisibleCapacityResources() then this.RefreshCurrencyPanel() end
        end, 500, this.HasVisibleCapacityResources)
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
if EVENT_INVENTORY_FULL_UPDATE then
    eventRegistry[EVENT_INVENTORY_FULL_UPDATE] = {
        name = "FullInventoryUpdate", condition = ShouldListenFullInventoryUpdate, handler = OnFullInventoryUpdate,
    }
end

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

    PrunePendingActions()

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

EVENT_MANAGER:RegisterForEvent(this.Name .. "_Event_PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
    if this.state and this.state.isLoaded then
        this.BeginCurrencyNotificationSuppression()
    end
end)

function this.SetVisibilityTickerNeeded(needed)
    if needed == visibilityTickerActive then return end
    local updateName = this.Name .. "_HideCheck"
    if needed then
        EVENT_MANAGER:RegisterForUpdate(updateName, 100, this.PanelLayout.UpdateContext)
    else
        EVENT_MANAGER:UnregisterForUpdate(updateName)
    end
    visibilityTickerActive = needed
end
