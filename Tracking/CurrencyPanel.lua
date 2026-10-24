InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local TEXTURES = {
    icon_gold = "|t16:16:/esoui/art/currency/currency_gold.dds|t",
    icon_bag  = "|t16:16:/esoui/art/tooltips/icon_bag.dds|t",
    icon_bank = "|t16:16:/esoui/art/tooltips/icon_bank.dds|t",
}

local COLORS = {
    white  = "|cffffff",
    red    = "|cff0000",
    yellow = "|cffff00",
    green  = "|c50c878",
    gold   = "|cffffcc",
}

local function OnCurrencyMoveStop(control)
    this.accountWide.currencyOffsetX = control:GetLeft()
    this.accountWide.currencyOffsetY = control:GetTop()
end

local function GetFormattedCurrencyData()
    local segments = {}

    if this.accountWide.showGold ~= false then
        local gold = GetCurrentMoney()
        local goldFmt = FormatIntegerWithDigitGrouping(gold, ",", 3)
        local goldColor = COLORS.gold
        if gold > 10000000 then goldColor = COLORS.red
        elseif gold > 5000000 then goldColor = COLORS.yellow
        elseif gold > 1000000 then goldColor = COLORS.green end
        table.insert(segments, string.format("%s %s%s|r", TEXTURES.icon_gold, goldColor, goldFmt))
    end

    if this.accountWide.showBag ~= false then
        local bagMax = GetBagSize(BAG_BACKPACK)
        local bagUsed = GetNumBagUsedSlots(BAG_BACKPACK)
        local bagColor = COLORS.white
        if bagUsed >= (bagMax - 5) then bagColor = COLORS.red
        elseif bagUsed > (bagMax - 20) then bagColor = COLORS.yellow
        elseif bagUsed > (bagMax * 0.5) then bagColor = COLORS.green end
        table.insert(segments, string.format("%s %s%d/%d|r", TEXTURES.icon_bag, bagColor, bagUsed, bagMax))
    end

    if this.accountWide.showBank ~= false then
        local bankMax = GetBagSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK)
        local bankUsed = GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK)
        local bankColor = COLORS.white
        if bankUsed >= (bankMax - 5) then bankColor = COLORS.red
        elseif bankUsed > (bankMax - 20) then bankColor = COLORS.yellow
        elseif bankUsed > (bankMax * 0.5) then bankColor = COLORS.green end
        table.insert(segments, string.format("%s %s%d/%d|r", TEXTURES.icon_bank, bankColor, bankUsed, bankMax))
    end

    return table.concat(segments, "   ")
end

function this.InitCurrencyPanel()
    if InventoryCompanion_CurrencyFloat then
        InventoryCompanion_CurrencyFloat:ClearAnchors()
        InventoryCompanion_CurrencyFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, this.accountWide.currencyOffsetX or 50, this.accountWide.currencyOffsetY or 150)
        InventoryCompanion_CurrencyFloat:SetHandler("OnMoveStop", OnCurrencyMoveStop)
    end

    if InventoryCompanion_CurrencyFloatContainer then
        InventoryCompanion_CurrencyFloatContainer:SetHandler("OnMouseDown", function(control, button)
            if button == MOUSE_BUTTON_INDEX_LEFT and InventoryCompanion_CurrencyFloat then
                InventoryCompanion_CurrencyFloat:StartMoving()
            end
        end)
    end

this.RefreshCurrencyPanel()
end

function this.RefreshCurrencyPanel()
    local hasInfo = (this.accountWide.showGold ~= false) or (this.accountWide.showBag ~= false) or (this.accountWide.showBank ~= false)
    if not InventoryCompanion_CurrencyFloatInfoLabel or not hasInfo then
        if InventoryCompanion_CurrencyFloat then InventoryCompanion_CurrencyFloat:SetHidden(true) end
        return
    end

    InventoryCompanion_CurrencyFloatInfoLabel:SetText(GetFormattedCurrencyData())   
end