InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local BAR_COLORS = {
    bag_normal = ZO_XP_BAR_GRADIENT_COLORS,
    bank_normal = {
        ZO_ColorDef:New(0.45, 0.20, 0.65, 1.0),
        ZO_ColorDef:New(0.70, 0.40, 0.90, 1.0),
    },
    warning = {
        ZO_ColorDef:New(0.90, 0.50, 0.05, 1.0),
        ZO_ColorDef:New(1.00, 0.70, 0.10, 1.0),
    },
    danger = {
        ZO_ColorDef:New(0.70, 0.15, 0.15, 1.0),
        ZO_ColorDef:New(0.95, 0.25, 0.25, 1.0),
    },
}

local progressBarControls = {}
local isCutsceneHidden = false

local function GetControlName(resourceKey)
    return "InventoryCompanion_ProgressBar_" .. resourceKey:gsub("[^%w]", "_")
end

local function GetLegacyCapacityVisibility(resource)
    if resource.resourceKey == "bag" then
        return this.accountWide.showBagBar ~= false
    end
    if resource.resourceKey == "bank" then
        return this.accountWide.showBankBar ~= false
    end
    return true
end

local function GetEffectiveSettings(resource)
    local settings = this.GetProgressBarSettings(resource.key)
    if resource.kind == "capacity" then
        local preference = type(this.accountWide.progressBarPreferences) == "table"
            and this.accountWide.progressBarPreferences[resource.key]
        if type(preference) ~= "table" or preference.showBar == nil then
            settings.showBar = settings.showBar and GetLegacyCapacityVisibility(resource)
        end
        if resource.resourceKey == "bag" then
            if type(preference) ~= "table" or preference.warningThreshold == nil then
                settings.warningThreshold = this.accountWide.warningThresholdBag or settings.warningThreshold
            end
            if type(preference) ~= "table" or preference.dangerThreshold == nil then
                settings.dangerThreshold = this.accountWide.dangerThresholdBag or settings.dangerThreshold
            end
        elseif resource.resourceKey == "bank" then
            if type(preference) ~= "table" or preference.warningThreshold == nil then
                settings.warningThreshold = this.accountWide.warningThresholdBank or settings.warningThreshold
            end
            if type(preference) ~= "table" or preference.dangerThreshold == nil then
                settings.dangerThreshold = this.accountWide.dangerThresholdBank or settings.dangerThreshold
            end
        end
    end
    return settings
end

local function CreateProgressBarControl(resource, resourceSettings)
    local control = CreateControlFromVirtual(
        GetControlName(resource.key),
        GuiRoot,
        "InventoryCompanion_ProgressBar_Template"
    )
    control:SetAnchor(
        TOPLEFT,
        GuiRoot,
        TOPLEFT,
        resourceSettings.offsetX,
        resourceSettings.offsetY
    )
    control.resourceKey = resource.key
    control.icon:SetTexture(resource.texture)
    control.icon:SetDrawLayer(DL_CONTROLS)
    control.icon:SetDrawLevel(3)
    control.trackBG:SetTexture("/esoui/art/miscellaneous/progressbar_frame_bg.dds")
    control.trackBG:SetTextureCoords(0.0195, 0.5898, 0, 0.625)
    control.trackBG:SetDrawLayer(DL_CONTROLS)
    control.trackBG:SetDrawLevel(1)
    control.bar:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
    control.bar:SetTexture("/esoui/art/miscellaneous/progressbar_genericfill.dds")
    control.bar:SetTextureCoords(0, 1, 0, 0.625)
    control.bar:SetDrawLayer(DL_CONTROLS)
    control.bar:SetDrawLevel(2)
    control.bar:SetMinMax(0, 1)
    control.bar:SetValue(0)
    control.label:SetDrawLayer(DL_CONTROLS)
    control.label:SetDrawLevel(4)
    progressBarControls[resource.key] = control

    control:SetHandler("OnMoveStop", function(movedControl)
        this.SetProgressBarPosition(resource.key, movedControl:GetLeft(), movedControl:GetTop())
    end)

    return control
end

local function GetNormalColors(resource)
    if resource.kind == "capacity" and resource.resourceKey == "bag" then
        return BAR_COLORS.bag_normal
    end
    if resource.kind == "capacity" and resource.resourceKey == "bank" then
        return BAR_COLORS.bank_normal
    end
    return BAR_COLORS.bag_normal
end

local function UpdateProgressBar(resource, control, settings)
    local values = this.GetProgressBarResourceValues(resource)
    if not values then
        control:SetHidden(true)
        return
    end

    local percent = values.cap > 0 and values.amount / values.cap or 0
    control.bar:SetMinMax(0, values.cap)
    control.bar:SetValue(values.amount)

    if percent >= settings.dangerThreshold then
        ZO_StatusBar_SetGradientColor(control.bar, BAR_COLORS.danger)
    elseif percent >= settings.warningThreshold then
        ZO_StatusBar_SetGradientColor(control.bar, BAR_COLORS.warning)
    else
        ZO_StatusBar_SetGradientColor(control.bar, GetNormalColors(resource))
    end

    control.label:SetText(string.format("%d / %d", values.amount, values.cap))
    control:SetHidden(not settings.showBar or isCutsceneHidden)
end

function this.RefreshResourceProgressBars()
    for _, resource in ipairs(this.GetProgressBarResources()) do
        local settings = GetEffectiveSettings(resource)
        local control = progressBarControls[resource.key]
        if settings.showBar or control then
            control = control or CreateProgressBarControl(resource, this.GetProgressBarSettings(resource.key))
            UpdateProgressBar(resource, control, settings)
        end
    end
end

this.RefreshProgressPanels = this.RefreshResourceProgressBars

function this.InitResourceProgressBars()
    for _, resource in ipairs(this.GetProgressBarResources()) do
        local settings = GetEffectiveSettings(resource)
        if settings.showBar then
            local control = progressBarControls[resource.key]
                or CreateProgressBarControl(resource, this.GetProgressBarSettings(resource.key))
            UpdateProgressBar(resource, control, settings)
        end
    end
end

function this.SetProgressBarsHidden(hidden)
    isCutsceneHidden = hidden == true
    for _, resource in ipairs(this.GetProgressBarResources()) do
        local control = progressBarControls[resource.key]
        if control then
            control:SetHidden(isCutsceneHidden or not GetEffectiveSettings(resource).showBar)
        end
    end
end

function this.HasVisibleProgressBars()
    for _, resource in ipairs(this.GetProgressBarResources()) do
        if GetEffectiveSettings(resource).showBar then
            return true
        end
    end
    return false
end

function this.IsProgressBarVisible(resourceKey)
    local resource
    for _, candidate in ipairs(this.GetProgressBarResources()) do
        if candidate.key == resourceKey then
            resource = candidate
            break
        end
    end
    return resource ~= nil and GetEffectiveSettings(resource).showBar
end
