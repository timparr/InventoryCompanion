InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local TEXTURES = {
    icon_bag      = "EsoUI/Art/Tooltips/icon_bag.dds",
    icon_bank     = "EsoUI/Art/Tooltips/icon_bank.dds",
    progress_bg   = "/esoui/art/miscellaneous/progressbar_frame_bg.dds",
    progress_fill = "/esoui/art/miscellaneous/progressbar_genericfill.dds",
}

local BAR_COLORS = {
    bag_normal  = ZO_XP_BAR_GRADIENT_COLORS,
    bank_normal = { ZO_ColorDef:New(0.45, 0.20, 0.65, 1.0), ZO_ColorDef:New(0.70, 0.40, 0.90, 1.0) },
    warning     = { ZO_ColorDef:New(0.90, 0.50, 0.05, 1.0), ZO_ColorDef:New(1.00, 0.70, 0.10, 1.0) },
    danger      = { ZO_ColorDef:New(0.70, 0.15, 0.15, 1.0), ZO_ColorDef:New(0.95, 0.25, 0.25, 1.0) },
}

------------------------------------------------------------------
-- Local Generic Status Bar Updater
------------------------------------------------------------------
local function UpdateMeterControl(control, used, max, warnThreshold, dangerThreshold, normalColors)
    if not (control and control.bar) then return end

    local pctUsed = (max > 0) and (used / max) or 0

    control.bar:SetMinMax(0, max)
    control.bar:SetValue(used)

    if pctUsed >= dangerThreshold then
        ZO_StatusBar_SetGradientColor(control.bar, BAR_COLORS.danger)
    elseif pctUsed >= warnThreshold then
        ZO_StatusBar_SetGradientColor(control.bar, BAR_COLORS.warning)
    else
        ZO_StatusBar_SetGradientColor(control.bar, normalColors)
    end

    control.label:SetText(string.format("%d / %d", used, max))
end

------------------------------------------------------------------
-- Programmatic Progress Bar Builder
------------------------------------------------------------------
local function BuildProgressBar(parentControl, iconTexturePath)
    if not parentControl then return end

    -- 1. Bag/Bank Icon
    local icon = WINDOW_MANAGER:CreateControl(parentControl:GetName() .. "Icon", parentControl, CT_TEXTURE)
    icon:SetDimensions(22, 22)
    icon:SetAnchor(TOPLEFT, parentControl, TOPLEFT, 0, 0)
    icon:SetTexture(iconTexturePath)
    icon:SetDrawLayer(DL_CONTROLS)
    icon:SetDrawLevel(3)

    -- 2. Dark Background Track
    local bg = WINDOW_MANAGER:CreateControl(parentControl:GetName() .. "TrackBG", parentControl, CT_TEXTURE)
    bg:SetDimensions(206, 22)
    bg:SetAnchor(TOPLEFT, icon, TOPRIGHT, 6, 0)
    bg:SetTexture(TEXTURES.progress_bg)
    bg:SetTextureCoords(0.0195, 0.5898, 0, 0.625)
    bg:SetDrawLayer(DL_CONTROLS)
    bg:SetDrawLevel(1)

    -- 3. Status Bar Fill
    local bar = WINDOW_MANAGER:CreateControl(parentControl:GetName() .. "Bar", parentControl, CT_STATUSBAR)
    bar:SetDimensions(200, 22)
    bar:SetAnchor(TOPLEFT, bg, TOPLEFT, 3, 0)
    bar:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
    bar:SetTexture(TEXTURES.progress_fill)
    bar:SetTextureCoords(0, 1, 0, 0.625)
    bar:SetDrawLayer(DL_CONTROLS)
    bar:SetDrawLevel(2)

    -- 4. Text Label
    local label = WINDOW_MANAGER:CreateControl(parentControl:GetName() .. "Label", parentControl, CT_LABEL)
    label:SetFont("ZoFontGameSmall")
    label:SetColor(1, 1, 1, 1)
    label:SetAnchor(CENTER, bg, CENTER, 0, 0)
    label:SetDrawLayer(DL_CONTROLS)
    label:SetDrawLevel(4)

    parentControl.bar = bar
    parentControl.label = label
end

------------------------------------------------------------------
-- Public Panel Handlers
------------------------------------------------------------------

function this.RefreshProgressPanels()
    -- 1. Refresh Backpack Bar
    if InventoryCompanion_BagBarFloat and InventoryCompanion_BagBarFloat.bar and this.accountWide.showBagBar then
        local used = GetNumBagUsedSlots(BAG_BACKPACK)
        local max  = GetBagSize(BAG_BACKPACK)
        UpdateMeterControl(
            InventoryCompanion_BagBarFloat, 
            used, 
            max, 
            this.accountWide.warningThresholdBag or 0.75, 
            this.accountWide.dangerThresholdBag or 0.90, 
            BAR_COLORS.bag_normal
        )
    end

    -- 2. Refresh Bank Bar
    if InventoryCompanion_BankBarFloat and InventoryCompanion_BankBarFloat.bar and this.accountWide.showBankBar then
        local used = GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK)
        local max  = GetBagSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK)
        UpdateMeterControl(
            InventoryCompanion_BankBarFloat, 
            used, 
            max, 
            this.accountWide.warningThresholdBank or 0.80, 
            this.accountWide.dangerThresholdBank or 0.95, 
            BAR_COLORS.bank_normal
        )
    end
end

function this.InitProgressPanels()
    -- Initialize Bag Bar
    if InventoryCompanion_BagBarFloat then
        InventoryCompanion_BagBarFloat:ClearAnchors()
        InventoryCompanion_BagBarFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, this.accountWide.bagBarOffsetX or 50, this.accountWide.bagBarOffsetY or 90)
        InventoryCompanion_BagBarFloat:SetHandler("OnMoveStop", function(control)
            this.accountWide.bagBarOffsetX = control:GetLeft()
            this.accountWide.bagBarOffsetY = control:GetTop()
        end)
        InventoryCompanion_BagBarFloat:SetHidden(not this.accountWide.showBagBar)

        if not InventoryCompanion_BagBarFloat.bar then
            BuildProgressBar(InventoryCompanion_BagBarFloat, TEXTURES.icon_bag)
        end
    end

    -- Initialize Bank Bar
    if InventoryCompanion_BankBarFloat then
        InventoryCompanion_BankBarFloat:ClearAnchors()
        InventoryCompanion_BankBarFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, this.accountWide.bankBarOffsetX or 50, this.accountWide.bankBarOffsetY or 130)
        InventoryCompanion_BankBarFloat:SetHandler("OnMoveStop", function(control)
            this.accountWide.bankBarOffsetX = control:GetLeft()
            this.accountWide.bankBarOffsetY = control:GetTop()
        end)
        InventoryCompanion_BankBarFloat:SetHidden(not this.accountWide.showBankBar)

        if not InventoryCompanion_BankBarFloat.bar then
            BuildProgressBar(InventoryCompanion_BankBarFloat, TEXTURES.icon_bank)
        end
    end

    -- Refresh values immediately upon initialization
    this.RefreshProgressPanels()
end