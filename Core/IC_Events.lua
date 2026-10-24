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

        for qKey, qFunc in pairs(executing) do
            local success, err = pcall(qFunc)
            if not success and this.Utils and this.Utils.UserError then
                this.Utils.UserError("Queue error [" .. tostring(qKey) .. "]: " .. tostring(err))
            end
        end
    end, delayMs)
end

------------------------------------------------------------------
-- Event Conditions & Handlers
------------------------------------------------------------------
local function ShouldListenOpenBank()
    return this.accountWide and (this.accountWide.autoMergeChests ~= false)
end

local function ShouldListenSlotUpdate()
    local showMeters   = this.accountWide and (this.accountWide.showBagBar or this.accountWide.showBankBar)
    local showTracker  = this.accountWide and (this.accountWide.showTrackedItemsPanel ~= false)
    local showCurrency = this.accountWide and ((this.accountWide.showGold ~= false) or (this.accountWide.showBag ~= false) or (this.accountWide.showBank ~= false))

    return showMeters or showTracker or showCurrency
end

local function ShouldListenMoneyUpdate()
    return this.accountWide and (this.accountWide.showGold ~= false)
end

local function ShouldListenBagCapacity()
    return this.accountWide and (this.accountWide.showBagBar or this.accountWide.showBag)
end

local function ShouldListenBankCapacity()
    return this.accountWide and (this.accountWide.showBankBar or this.accountWide.showBank)
end

local function OnBankOpened(eventCode, bankType)
    if this.accountWide and (this.accountWide.autoMergeChests ~= false) and this.OnBankOpened then
        this.OnBankOpened(eventCode, bankType)
    end
end

local function OnInventorySlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    if this.HandleTrackedItemInventoryUpdate then
        this.HandleTrackedItemInventoryUpdate(bagId, slotIndex, stackCountChange)
    end

    if this.accountWide and this.accountWide.showTrackedItemsPanel ~= false and this.RefreshItemTrackerPanel then
        Enqueue("RefreshItemTracker", function()
            this.RefreshItemTrackerPanel()
        end, 500)
    end

    if this.RefreshCurrencyPanel then
        Enqueue("RefreshCurrency", function()
            this.RefreshCurrencyPanel()
        end, 500)
    end

    if this.RefreshProgressPanels and this.accountWide and (this.accountWide.showBagBar or this.accountWide.showBankBar) then
        Enqueue("RefreshProgress", function()
            this.RefreshProgressPanels()
        end, 500)
    end
end

local function OnMoneyUpdate(eventCode, newMoney, oldMoney, reason)
    if this.RefreshCurrencyPanel then
        Enqueue("RefreshCurrency", function()
            this.RefreshCurrencyPanel()
        end, 500)
    end
end

local function OnCapacityChanged()
    if this.RefreshProgressPanels then
        Enqueue("RefreshProgress", function()
            this.RefreshProgressPanels()
        end, 500)
    end
    if this.RefreshCurrencyPanel then
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
    [EVENT_INVENTORY_SINGLE_SLOT_UPDATE]   = { name = "SlotUpdate",   condition = ShouldListenSlotUpdate,   handler = OnInventorySlotUpdate },
    [EVENT_MONEY_UPDATE]                 = { name = "MoneyUpdate",  condition = ShouldListenMoneyUpdate,  handler = OnMoneyUpdate },
    [EVENT_INVENTORY_BAG_CAPACITY_CHANGED] = { name = "BagCapacity",  condition = ShouldListenBagCapacity,  handler = OnCapacityChanged },
    [EVENT_INVENTORY_BANK_CAPACITY_CHANGED]= { name = "BankCapacity", condition = ShouldListenBankCapacity, handler = OnCapacityChanged },
}

function this.UpdateEventRegistry()
    for eventCode, entry in pairs(eventRegistry) do
        local eventId = string.format("%s_Event_%s", this.Name, entry.name)
        local shouldBeActive = false

        if entry.condition then
            local success, result = pcall(entry.condition)
            shouldBeActive = success and (result == true)
        end

        local isCurrentlyActive = (activeListeners[eventId] == true)

        if shouldBeActive and not isCurrentlyActive then
            EVENT_MANAGER:RegisterForEvent(eventId, eventCode, entry.handler)
            activeListeners[eventId] = true

        elseif not shouldBeActive and isCurrentlyActive then
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

            if InventoryCompanion_CurrencyFloat then
                local showInfo = (this.accountWide.showGold ~= false) or (this.accountWide.showBag ~= false) or (this.accountWide.showBank ~= false)
                InventoryCompanion_CurrencyFloat:SetHidden((not showInfo) or inCutscene)
            end

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
    d("|c50c878[IC Events Audit]|r Checking Registered Engine Listeners...")

    local totalDefined = 0
    local totalActive  = 0

    for eventCode, entry in pairs(eventRegistry) do
        totalDefined = totalDefined + 1
        local eventId  = string.format("%s_Event_%s", this.Name, entry.name)
        local isActive = (activeListeners[eventId] == true)

        local statusTag = isActive and "|c50c878[ACTIVE]|r" or "|c888888[OFF]|r"
        if isActive then totalActive = totalActive + 1 end

        d(string.format("  -> %s %s (Code: %d)", statusTag, entry.name, eventCode))
    end

    d(string.format("Audit Summary: |cFFFF00%d/%d|r engine events active.", totalActive, totalDefined))
end