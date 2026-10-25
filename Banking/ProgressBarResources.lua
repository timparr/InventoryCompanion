InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local CAPACITY_RESOURCES = {
    {
        key = "capacity:bag",
        resourceKey = "bag",
        name = "Backpack",
        texture = "EsoUI/Art/Tooltips/icon_bag.dds",
        defaultShowBar = true,
        warningThreshold = 0.75,
        dangerThreshold = 0.90,
    },
    {
        key = "capacity:bank",
        resourceKey = "bank",
        name = "Bank",
        texture = "EsoUI/Art/Tooltips/icon_bank.dds",
        defaultShowBar = true,
        warningThreshold = 0.80,
        dangerThreshold = 0.95,
    },
}

local DEFAULT_CURRENCY_WARNING_THRESHOLD = 0.75
local DEFAULT_CURRENCY_DANGER_THRESHOLD = 0.90
local malformedPreferenceWarnings = {}
local progressBarResources

local function WarnMalformedPreference(message)
    if malformedPreferenceWarnings[message] then return end
    malformedPreferenceWarnings[message] = true
    d("[InventoryCompanion] Ignoring malformed progress bar preference: " .. message)
end

local function EnsurePreferences()
    if type(this.accountWide.progressBarPreferences) ~= "table" then
        if this.accountWide.progressBarPreferences ~= nil then
            WarnMalformedPreference("progressBarPreferences must be a table")
        end
        this.accountWide.progressBarPreferences = {}
    end
end

local function GetResourceDefaults(resource)
    if resource.kind == "capacity" then
        return resource.defaultShowBar, resource.warningThreshold, resource.dangerThreshold
    end
    return false, DEFAULT_CURRENCY_WARNING_THRESHOLD, DEFAULT_CURRENCY_DANGER_THRESHOLD
end

local function IsValidThreshold(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value <= 1
        and value < math.huge
end

local function StoreDeviation(preference, setting, value, defaultValue)
    if value == defaultValue then
        preference[setting] = nil
    else
        preference[setting] = value
    end
end

local function GetStoredPreference(resource, create)
    EnsurePreferences()
    local preferences = this.accountWide.progressBarPreferences
    local preference = preferences[resource.key]
    if type(preference) ~= "table" then
        if preference ~= nil then
            WarnMalformedPreference(resource.key .. " must be a table")
        end
        if not create then return nil end
        preference = {}
        preferences[resource.key] = preference
    end
    return preference
end

local function BuildProgressBarResourceList()
    local resources = {}
    for _, definition in ipairs(CAPACITY_RESOURCES) do
        table.insert(resources, {
            key = definition.key,
            kind = "capacity",
            resourceKey = definition.resourceKey,
            name = definition.name,
            texture = definition.texture,
            defaultShowBar = definition.defaultShowBar,
            warningThreshold = definition.warningThreshold,
            dangerThreshold = definition.dangerThreshold,
        })
    end

    for _, currencyType in ipairs(this.GetCappedCurrencyList()) do
        local info = this.GetCappedCurrencyInfo(currencyType)
        assert(info and info.cap ~= nil, "Capped currency is missing cap information")
        table.insert(resources, {
            key = "currency:" .. tostring(currencyType),
            kind = "currency",
            currencyType = currencyType,
            name = info.name,
            texture = info.keyboardTexture or info.gamepadTexture,
            defaultShowBar = false,
            warningThreshold = DEFAULT_CURRENCY_WARNING_THRESHOLD,
            dangerThreshold = DEFAULT_CURRENCY_DANGER_THRESHOLD,
        })
    end

    return resources
end

local function GetProgressBarResourceList()
    if not progressBarResources then
        progressBarResources = BuildProgressBarResourceList()
    end
    return progressBarResources
end

local function FindProgressBarResource(resourceKey)
    for _, resource in ipairs(GetProgressBarResourceList()) do
        if resource.key == resourceKey then
            return resource
        end
    end
    return nil
end

function this.GetProgressBarResources()
    return GetProgressBarResourceList()
end

function this.GetProgressBarResourceValues(resource)
    assert(type(resource) == "table" and type(resource.key) == "string", "A progress bar resource descriptor is required")

    if resource.kind == "currency" then
        local info = this.GetCappedCurrencyInfo(resource.currencyType)
        if not info or info.cap == nil then
            return nil
        end
        return {
            amount = info.amount,
            cap = info.cap,
        }
    end

    assert(resource.kind == "capacity", "Unknown progress bar resource kind: " .. tostring(resource.kind))
    if resource.resourceKey == "bag" then
        return {
            amount = GetNumBagUsedSlots(BAG_BACKPACK),
            cap = GetBagSize(BAG_BACKPACK),
        }
    end
    if resource.resourceKey == "bank" then
        return {
            amount = GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK),
            cap = GetBagSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK),
        }
    end
    error("Unknown capacity progress bar resource: " .. tostring(resource.resourceKey))
end

function this.GetProgressBarSettings(resourceKey)
    local resource = FindProgressBarResource(resourceKey)
    assert(resource, "Unknown progress bar resource: " .. tostring(resourceKey))

    local defaultShowBar, defaultWarningThreshold, defaultDangerThreshold = GetResourceDefaults(resource)
    local preference = GetStoredPreference(resource, false)
    local showBar = defaultShowBar
    local warningThreshold = defaultWarningThreshold
    local dangerThreshold = defaultDangerThreshold

    if preference then
        if preference.showBar ~= nil then
            if type(preference.showBar) == "boolean" then
                showBar = preference.showBar
            else
                WarnMalformedPreference(resource.key .. ".showBar must be boolean")
            end
        end
        if preference.warningThreshold ~= nil then
            if IsValidThreshold(preference.warningThreshold) then
                warningThreshold = preference.warningThreshold
            else
                WarnMalformedPreference(resource.key .. ".warningThreshold must be between 0 and 1")
            end
        end
        if preference.dangerThreshold ~= nil then
            if IsValidThreshold(preference.dangerThreshold) then
                dangerThreshold = preference.dangerThreshold
            else
                WarnMalformedPreference(resource.key .. ".dangerThreshold must be between 0 and 1")
            end
        end
    end

    if warningThreshold > dangerThreshold then
        WarnMalformedPreference(resource.key .. " warning threshold must not exceed its danger threshold")
        warningThreshold = defaultWarningThreshold
        dangerThreshold = defaultDangerThreshold
    end

    return {
        showBar = showBar,
        warningThreshold = warningThreshold,
        dangerThreshold = dangerThreshold,
    }
end

function this.SetProgressBarSetting(resourceKey, setting, value)
    local resource = FindProgressBarResource(resourceKey)
    assert(resource, "Unknown progress bar resource: " .. tostring(resourceKey))
    assert(
        setting == "showBar" or setting == "warningThreshold" or setting == "dangerThreshold",
        "Unknown progress bar setting: " .. tostring(setting)
    )

    if setting == "showBar" then
        assert(type(value) == "boolean", "showBar must be boolean")
    else
        assert(IsValidThreshold(value), setting .. " must be between 0 and 1")
    end

    local preference = GetStoredPreference(resource, true)
    local settings = this.GetProgressBarSettings(resourceKey)
    local defaultShowBar, defaultWarningThreshold, defaultDangerThreshold = GetResourceDefaults(resource)

    if setting == "showBar" then
        StoreDeviation(preference, "showBar", value, defaultShowBar)
    elseif setting == "warningThreshold" then
        StoreDeviation(preference, "warningThreshold", value, defaultWarningThreshold)
        if value > settings.dangerThreshold then
            StoreDeviation(preference, "dangerThreshold", value, defaultDangerThreshold)
        end
    else
        StoreDeviation(preference, "dangerThreshold", value, defaultDangerThreshold)
        if value < settings.warningThreshold then
            StoreDeviation(preference, "warningThreshold", value, defaultWarningThreshold)
        end
    end

    if next(preference) == nil then
        this.accountWide.progressBarPreferences[resource.key] = nil
    end
end

function this.InitializeProgressBarResources()
    EnsurePreferences()
    progressBarResources = BuildProgressBarResourceList()
end
