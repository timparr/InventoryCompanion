InventoryCompanion = {
    Name = "InventoryCompanion",
	DisplayName = "Inventory Companion",
    Author = "@Tim-P",
    Version = 1.00,
    SettingsVersion = 1.0,
    SettingsName = "InventoryCompanion_SavedVariables",
}
local this = InventoryCompanion
this.state = {
    isLoaded = false, -- Set to true when it has finished loading so that we can check if it is safe to rely on our defined structures. Note that this is NOT breaking the guarding against our own code - if something has not loaded YET but we don't necessarily expect it to, then that is fine. We mitigated it. If it still fails after the addon is loaded, then we have something we need to fix and that is what the fail hard, fail fast mantra is for
	
    lastActiveEditTab = "InventoryCompanion_TrackedItemsScene", -- Tracks the last viewed edit panel tab
}

------------------------------------------------------------------
-- Core Initialization
------------------------------------------------------------------
local function Initialize()
    -- Register keybind display names in ESO controls menu
    ZO_CreateStringId("SI_BINDING_NAME_InventoryCompanion_Deposit_Crafted_Items", "Deposit Items to Bank")
    ZO_CreateStringId("SI_BINDING_NAME_InventoryCompanion_Withdraw_Crafted_Items", "Withdraw Items from Bank")
	ZO_CreateStringId("SI_BINDING_NAME_InventoryCompanion_Toggle_EditPanel", "Show/Hide Tracking Settings")
    ZO_CreateStringId("SI_BINDING_NAME_InventoryCompanion_Debug_Key", "Debug Key")
	
    -- Load Saved Variables
    this.accountWide = ZO_SavedVars:NewAccountWide(this.SettingsName, this.SettingsVersion, nil, this.defaultsAccount)
    this.character   = ZO_SavedVars:NewCharacterIdSettings(this.SettingsName, this.SettingsVersion, nil, this.defaultsCharacter)

    -- Initialize modules
    this.UpdateEventRegistry()
    this.InitCutsceneTicker()
    this.CreateSettingsPanel()
    this.InitContextMenus()
    this.InitProgressPanels()
    this.InitItemTrackerPanel()
    this.InitCurrencyPanel()

    this.state.isLoaded = true
end

local function OnAddOnLoaded(eventCode, name)
    if name == this.Name then
        EVENT_MANAGER:UnregisterForEvent(this.Name, eventCode)
        Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(this.Name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
-- Register the slash commands to clear corrupt rule overrides

------------------------------------------------------------------
-- Keybind Endpoints
------------------------------------------------------------------
function this.Deposit()
    this.ProcessBags({ BAG_BACKPACK }, BAG_BANK)
end

function this.Withdraw()
    this.ProcessBags({ BAG_BANK, BAG_SUBSCRIBER_BANK }, BAG_BACKPACK)
end

function this.ToggleEditPanel()
    this.ToggleTrackedItemsEditor()
end

------------------------------------------------------------------
-- Debug Routines
------------------------------------------------------------------
SLASH_COMMANDS["/icclearoverrides"] = function()
    local modeText = ""
    if this.character and this.character.useCharacterItemList then
        this.character.trackedRules = {}
        modeText = "Character-specific"
    else
        this.accountWide.trackedRules = {}
        modeText = "Account-wide"
    end
    
    d(string.format("[InventoryCompanion] Cleared all rule overrides for current mode (%s). All rules restored to baseline defaults.", modeText))
    
    -- Refresh UI panels if active
    if this.RefreshGroupsEditor then this.RefreshGroupsEditor() end
    if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
end

------------------------------------------------------------------
-- Debug Key - only the last will actually run. This is fine
------------------------------------------------------------------
local currencyLocationConstants =
{
    { name = "CURRENCY_LOCATION_ACCOUNT", value = CURRENCY_LOCATION_ACCOUNT },
    { name = "CURRENCY_LOCATION_ALL", value = CURRENCY_LOCATION_ALL },
    { name = "CURRENCY_LOCATION_BANK", value = CURRENCY_LOCATION_BANK },
    { name = "CURRENCY_LOCATION_CHARACTER", value = CURRENCY_LOCATION_CHARACTER },
    { name = "CURRENCY_LOCATION_GUILD_BANK", value = CURRENCY_LOCATION_GUILD_BANK },
    { name = "CURRENCY_LOCATION_MAX_VALUE", value = CURRENCY_LOCATION_MAX_VALUE },
}

function DebugPrintInventoryCurrencyRows()
    local row = 0
    local IS_PLURAL = false
    local IS_UPPER = false
    this.accountWide.currencyInfo = {}

    for currencyType = CURT_ITERATION_BEGIN, CURT_ITERATION_END do
        if IsCurrencyValid(currencyType) and ShouldShowCurrencyInCurrencyPanel(currencyType) then
            row = row + 1

            local constantNames = {}
            for _, constant in ipairs(minedConstants) do
                if constant.value == currencyType then
                    table.insert(constantNames, constant.name)
                end
            end

            local name = GetCurrencyName(currencyType, IS_PLURAL, IS_UPPER)
            local texture = GetCurrencyKeyboardIcon(currencyType)
            local location = GetCurrencyPlayerStoredLocation(currencyType)
            local amount = GetCurrencyAmount(currencyType, location)
            local cap = IsCurrencyCapped(currencyType, location) and GetMaxPossibleCurrency(currencyType, location) or nil
            local isAccountWide = location == CURRENCY_LOCATION_ACCOUNT
            local canBeStoredInBank = CanCurrencyBeStoredInLocation(currencyType, CURRENCY_LOCATION_BANK)

            local locationNames = {}
            for _, constant in ipairs(currencyLocationConstants) do
                if constant.value == location then
                    table.insert(locationNames, constant.name)
                end
            end

            local locationName = #locationNames > 0 and table.concat(locationNames, " / ") or "unknown"
            local debugLine = string.format("[%d] constant: %s | name: %s | texture: %s | amount: %s | location: %s (%s) | cap: %s | isAccountWide: %s | canBeStoredInBank: %s",
                row, #constantNames > 0 and table.concat(constantNames, " / ") or "unknown",
                tostring(name), tostring(texture), tostring(amount), locationName, tostring(location),
                tostring(cap), tostring(isAccountWide), tostring(canBeStoredInBank))

            local info =
            {
                constants = constantNames,
                currencyType = currencyType,
                name = name,
                texture = texture,
                amount = amount,
                location = location,
                locationName = locationName,
                cap = cap,
                isAccountWide = isAccountWide,
                canBeStoredInBank = canBeStoredInBank,
            }
            for _, constantName in ipairs(constantNames) do
                this.accountWide.currencyInfo[constantName] = info
            end

            d(debugLine)
        end
    end
end

minedConstants =
{
    { name = "CURT_ALLIANCE_POINTS", value = CURT_ALLIANCE_POINTS },
    { name = "CURT_ARCHIVAL_FORTUNES", value = CURT_ARCHIVAL_FORTUNES },
    { name = "CURT_CHAOTIC_CREATIA", value = CURT_CHAOTIC_CREATIA },
    { name = "CURT_CROWN_GEMS", value = CURT_CROWN_GEMS },
    { name = "CURT_CROWNS", value = CURT_CROWNS },
    { name = "CURT_ENDEAVOR_SEALS", value = CURT_ENDEAVOR_SEALS },
    { name = "CURT_ENDLESS_DUNGEON", value = CURT_ENDLESS_DUNGEON },
    { name = "CURT_IMPERIAL_FRAGMENTS", value = CURT_IMPERIAL_FRAGMENTS },
    { name = "CURT_ITERATION_BEGIN", value = CURT_ITERATION_BEGIN },
    { name = "CURT_ITERATION_END", value = CURT_ITERATION_END },
    { name = "CURT_MONEY", value = CURT_MONEY },
    { name = "CURT_NONE", value = CURT_NONE },
    { name = "CURT_SEALS", value = CURT_SEALS },
    { name = "CURT_STYLE_STONES", value = CURT_STYLE_STONES },
    { name = "CURT_TELVAR_STONES", value = CURT_TELVAR_STONES },
    { name = "CURT_TOME_CHALLENGE_REROLLS", value = CURT_TOME_CHALLENGE_REROLLS },
    { name = "CURT_TOME_POINT_CACHES", value = CURT_TOME_POINT_CACHES },
    { name = "CURT_TOME_POINTS", value = CURT_TOME_POINTS },
    { name = "CURT_TOME_TOKENS", value = CURT_TOME_TOKENS },
    { name = "CURT_TRADE_BARS", value = CURT_TRADE_BARS },
    { name = "CURT_TRANSMUTE_CRYSTALS", value = CURT_TRANSMUTE_CRYSTALS },
    { name = "CURT_UNDAUNTED_CRESTS", value = CURT_UNDAUNTED_CRESTS },
    { name = "CURT_UNDAUNTED_KEYS", value = CURT_UNDAUNTED_KEYS },
    { name = "CURT_WRIT_VOUCHERS", value = CURT_WRIT_VOUCHERS },
}

for _, currency in ipairs(minedConstants) do
    currency.cap = nil
    currency.isAccountWide = false
    currency.canBeStoredInBank = false

    if IsCurrencyValid(currency.value) then
        local location = GetCurrencyPlayerStoredLocation(currency.value)
        if IsCurrencyCapped(currency.value, location) then
            currency.cap = GetMaxPossibleCurrency(currency.value, location)
        end
        currency.isAccountWide = location == CURRENCY_LOCATION_ACCOUNT
        currency.canBeStoredInBank = CanCurrencyBeStoredInLocation(currency.value, CURRENCY_LOCATION_BANK)
    end
end

function this.Debug()
	DebugPrintInventoryCurrencyRows()
end
