local function Load()
    InventoryCompanion = { Utils = { FormatBigNumber = tostring }, PanelLayout = { UpdateVisibility = function() end } }
    assert(loadstring(CurrencyGridSource))()
    local addon = InventoryCompanion
    local settings = { currencyGridColumns = 3, showEmptyCurrencies = true,
        currencyPreferences = {}, capacityPreferences = {} }
    addon.GetPanelSettings = function() return settings end
    local entries = {}
    addon.GetCurrencyPanelResourceEntries = function() return entries end
    return addon, settings, entries
end

local function Control(name)
    local control = { name = name, x = 70, y = 90, handlers = {} }
    function control:SetDimensions(w, h) self.width, self.height = w, h end
    function control:SetWidth(w) self.width = w end
    function control:SetText(text) self.text = text end
    function control:GetTextWidth() return #self.text * 7 end
    function control:SetHandler(key, handler) self.handlers[key] = handler end
    function control:SetAnchor(_, _, _, x, y) self.x, self.y = x, y end
    function control:ClearAnchors() end
    function control:SetHidden(value) self.hidden = value end
    function control:SetTexture() end
    function control:SetMouseEnabled() end
    function control:SetDrawLayer() end
    function control:SetDrawLevel() end
    function control:SetFont() end
    function control:SetColor() end
    function control:SetVerticalAlignment() end
    function control:SetHorizontalAlignment() end
    function control:SetWrapMode() end
    return control
end

function GetCurrencyGridColumnsTests()
    return {
        {
            name = "Currency grid columns startup maximum groups locations and retains above-cap selection",
            run = function()
                local addon, settings, entries = Load()
                entries[1] = { kind = "currency", currencyType = 1, location = 0 }
                entries[2] = { kind = "currency", currencyType = 1, location = 1 }
                entries[3] = { kind = "currency", currencyType = 2 }
                entries[4] = { kind = "capacity" }
                entries[5] = { kind = "capacity" }
                addon.InitializeCurrencyGridColumns()
                assert(addon.GetCurrencyGridColumnLimit() == 4)
                settings.currencyGridColumns = 8
                assert(addon.GetEffectiveCurrencyGridColumns() == 4 and settings.currencyGridColumns == 8)
                entries[6] = { kind = "currency", currencyType = 3 }
                assert(addon.GetCurrencyGridColumnLimit() == 4, "No live rediscovery")
            end,
        },
        {
            name = "Currency grid columns settings slider definition validates and writes active panel",
            run = function()
                local addon, settings = Load()
                addon.InitializeCurrencyGridColumns()
                local refreshes = 0
                addon.RefreshCurrencyPanel = function() refreshes = refreshes + 1 end
                addon.defaultsAccount = { PanelSettings = { Currency = { showEmptyCurrencies = true } } }
                local controls = addon.GetCurrencyPanelSettingsControls()
                local slider = controls[2]
                assert(slider.type == "slider" and slider.name == "Grid Columns")
                assert(slider.min == 1 and slider.max == 3 and slider.step == 1 and slider.default == 3)
                slider.setFunc(1)
                assert(slider.getFunc() == 1 and refreshes == 1)
                for _, bad in ipairs({ 0, 4, 1.5, "2", math.huge }) do
                    assert(not pcall(slider.setFunc, bad))
                end
                assert(settings.currencyGridColumns == 1)
            end,
        },
        {
            name = "Currency grid columns rendering preserves anchor and lays out occupied variable-width columns",
            run = function()
                local addon, settings, entries = Load()
                TOPLEFT, TOPRIGHT = 1, 2
                local created = {}
                WINDOW_MANAGER = { CreateControl = function(_, name)
                    local control = Control(name); created[name] = control; return control
                end }
                InventoryCompanion_CurrencyFloat = Control("panel")
                InventoryCompanion_CurrencyFloatContainer = Control("container")
                for index = 1, 5 do
                    entries[index] = { kind = "capacity", resourceKey = "test" .. index, isVisible = true,
                        amount = index == 1 and 10000 or index, cap = 100000 }
                end
                addon.InitializeCurrencyGridColumns()
                settings.currencyGridColumns = 2
                addon.RefreshCurrencyPanel()
                local first = created.InventoryCompanion_CurrencyFloatCell1
                local second = created.InventoryCompanion_CurrencyFloatCell2
                local third = created.InventoryCompanion_CurrencyFloatCell3
                assert(first.x == 0 and first.y == 0)
                assert(second.x == first.width + 8 and second.y == 0)
                assert(third.x == 0 and third.y == 28)
                assert(InventoryCompanion_CurrencyFloat.x == 70 and InventoryCompanion_CurrencyFloat.y == 90)
                settings.currencyGridColumns = 5
                for index = 5, 2, -1 do entries[index] = nil end
                addon.RefreshCurrencyPanel()
                assert(InventoryCompanion_CurrencyFloatContainer.width == first.width)
                assert(second.hidden)
                entries[1] = nil
                addon.RefreshCurrencyPanel()
                assert(InventoryCompanion_CurrencyFloat.hidden)
            end,
        },
    }
end
