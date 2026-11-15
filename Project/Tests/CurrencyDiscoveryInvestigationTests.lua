function GetCurrencyDiscoveryInvestigationTests()
    return {
        {
            name = "Currency discovery reinitialization finds added currencies without changing saved preferences",
            run = function()
                local profile = { currencyPreferences = { [1] = { showCompact = false } } }
                InventoryCompanion = { GetSettingsProfile = function() return profile end }
                CURT_ITERATION_BEGIN, CURT_ITERATION_END = 1, 3
                local available = { [1] = true }
                IsCurrencyValid = function(currencyType) return available[currencyType] == true end
                ShouldShowCurrencyInCurrencyPanel = function() return true end
                GetCurrencyName = function(currencyType) return "Currency " .. currencyType end
                GetCurrencyKeyboardIcon = function() return "keyboard-icon" end
                GetCurrencyGamepadIcon = function() return "gamepad-icon" end
                assert(loadstring(CurrencyDiscoveryHelperSource))()
                local addon = InventoryCompanion
                local preferences = profile.currencyPreferences
                addon.InitializeCurrencyHelper()
                assert(#addon.GetCurrencyList() == 1)
                available[2] = true
                addon.InitializeCurrencyHelper()
                local currencies = addon.GetCurrencyList()
                assert(#currencies == 2 and currencies[1] == 1 and currencies[2] == 2)
                assert(profile.currencyPreferences == preferences and preferences[1].showCompact == false
                    and preferences[2] == nil, "Rediscovery must not change user preferences")
                available[1] = nil
                addon.InitializeCurrencyHelper()
                assert(#addon.GetCurrencyList() == 1 and addon.GetCurrencyList()[1] == 2)
                assert(preferences[1].showCompact == false, "Lost availability must not erase saved preferences")
            end,
        },
    }
end
