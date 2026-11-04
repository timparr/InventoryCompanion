InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

function this.GetAutoCategoryInfoText()
    if this.AutoCategoryIntegration.NeedsRecovery() then
        return this.AutoCategoryIntegration.GetRecoveryMessage()
    end
    local _, message = this.AutoCategoryIntegration.GetStatus()
    return message
end

local function GetProfileControls()
    local names, keys = {}, {}
    local function RefreshSources()
        ZO_ClearTable(names)
        ZO_ClearTable(keys)
        for key, profile in pairs(this.GetSavedAccountProfiles()) do
            if key == "$AccountWide" or profile.itemListInitialized == true then
                keys[#keys + 1] = key
            end
        end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local profile = this.GetSavedAccountProfiles()[key]
            names[#names + 1] = key == "$AccountWide" and "Account-wide"
                or profile["$LastCharacterName"] or ("Character " .. key)
        end
    end
    RefreshSources()
    local selected
    return {
        { type = "checkbox", name = "Use Character Settings",
            tooltip = "Off uses the shared account profile. On resumes your character profile, or copies account settings on first use.",
            getFunc = function() return this.character.useCharacterItemList end,
            setFunc = function(value)
                this.SetUseCharacterItemList(value)
                RefreshSources()
                InventoryCompanion_ProfileCopySource:UpdateChoices(names, keys)
                this.RefreshProfileSettings()
            end },
        { type = "dropdown", name = "Copy From", choices = names, choicesValues = keys,
            reference = "InventoryCompanion_ProfileCopySource",
            getFunc = function() return selected end,
            setFunc = function(value) selected = value end },
        { type = "description", text = function()
            return "Copy replaces all settings, items and groups in the "
                .. (this.character.useCharacterItemList and "current character" or "shared account")
                .. " profile. Account-only controls are not copied."
        end },
        { type = "button", name = "Copy Full Profile", disabled = function() return selected == nil end,
            func = function()
                local destination = this.GetSettingsProfile()
                local source = this.GetSavedAccountProfiles()[selected]
                if source == nil then
                    this.Utils.UserError("The selected source profile is no longer available.", "Profile Copy")
                    return
                end
                if source.trackedRules == destination.trackedRules then
                    this.Utils.UserError("Choose a different source profile.", "Profile Copy")
                    return
                end
                ZO_Dialogs_ShowDialog("InventoryCompanion_CONFIRM_PROFILE_COPY",
                    { source = selected, destination = destination })
            end, width = "full" },
    }
end

local function RegisterProfileCopyDialog()
ZO_Dialogs_RegisterCustomDialog("InventoryCompanion_CONFIRM_PROFILE_COPY", {
    gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
    title = { text = "Replace Full Profile" },
    mainText = { text = function(dialog)
        return "Replace the "
            .. (this.character.useCharacterItemList and "current character" or "shared account")
            .. " profile with " .. dialog.data.source
            .. "?\nAll destination settings, items and groups will be replaced. This cannot be undone."
    end },
    buttons = {
        { text = "Replace", callback = function(dialog)
            assert(dialog.data.destination == this.GetSettingsProfile(), "Profile copy destination changed")
            if this.CopyProfile(dialog.data.source) then
                this.RefreshProfileSettings()
                this.Utils.UserMessage("Full profile replaced.", "Profile Copy")
            else
                this.Utils.UserError("Source profile is unavailable or invalid.", "Profile Copy")
            end
        end },
        { text = SI_DIALOG_CANCEL },
    },
})
end

local function RefreshProgressBarSettings()
    this.RefreshResourceProgressBars()
    this.UpdateEventRegistry()
    if type(LibAddonMenu2.RefreshAddonPanel) == "function" then
        LibAddonMenu2:RefreshAddonPanel("InventoryCompanionPanel")
    end
end

local function MakeProgressBarColorPicker(name, getColor, setColor, defaultColor)
    return {
        type = "colorpicker",
        name = name,
        getFunc = function()
            local color = getColor()
            return color.r, color.g, color.b, color.a
        end,
        setFunc = function(r, g, b, a)
            setColor({ r = r, g = g, b = b, a = a })
            RefreshProgressBarSettings()
        end,
        default = defaultColor,
    }
end

local function GetStandaloneProgressBarControls()
    local controls = {}
    for _, resource in ipairs(this.GetProgressBarResources()) do
        local resourceKey = resource.key
        local settings = this.GetProgressBarSettings(resourceKey)
        table.insert(controls, {
            type = "checkbox",
            name = "Show " .. resource.name .. " Bar",
            tooltip = "Show this resource in its own movable progress bar. This is independent of the Currency Summary Panel.",
            getFunc = function()
                return this.GetProgressBarSettings(resourceKey).showBar
            end,
            setFunc = function(value)
                this.SetProgressBarSetting(resourceKey, "showBar", value)
                RefreshProgressBarSettings()
            end,
            default = settings.showBar,
        })

        table.insert(controls, {
            type = "submenu",
            name = resource.name .. " Bar Advanced Settings",
            controls = {
                {
                    type = "slider",
                    name = "Warning Threshold (%)",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function()
                        return this.GetProgressBarSettings(resourceKey).warningThreshold * 100
                    end,
                    setFunc = function(value)
                        this.SetProgressBarSetting(resourceKey, "warningThreshold", value / 100)
                        RefreshProgressBarSettings()
                    end,
                    default = settings.warningThreshold * 100,
                },
                {
                    type = "slider",
                    name = "Danger Threshold (%)",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function()
                        return this.GetProgressBarSettings(resourceKey).dangerThreshold * 100
                    end,
                    setFunc = function(value)
                        this.SetProgressBarSetting(resourceKey, "dangerThreshold", value / 100)
                        RefreshProgressBarSettings()
                    end,
                    default = settings.dangerThreshold * 100,
                },
                MakeProgressBarColorPicker(
                    "Normal Bar Color",
                    function() return this.GetProgressBarNormalColor(resourceKey) end,
                    function(color) this.SetProgressBarSetting(resourceKey, "normalColor", color) end,
                    this.GetProgressBarNormalColor(resourceKey)
                ),
            },
        })
    end

    table.insert(controls, {
        type = "header",
        name = "Shared Alert Colors",
    })
    table.insert(controls, MakeProgressBarColorPicker(
        "Warning Color",
        function() return this.GetProgressBarAlertColor("warning") end,
        function(color) this.SetProgressBarAlertColor("warning", color) end,
        { r = 0.95, g = 0.55, b = 0.08, a = 1 }
    ))
    table.insert(controls, MakeProgressBarColorPicker(
        "Danger Color",
        function() return this.GetProgressBarAlertColor("danger") end,
        function(color) this.SetProgressBarAlertColor("danger", color) end,
        { r = 0.85, g = 0.18, b = 0.18, a = 1 }
    ))
    return controls
end

function this.CreateSettingsPanel()
    RegisterProfileCopyDialog()
    local LAM = LibAddonMenu2
    local panelName = this.Utils.DisplayName()

    local panelData = {
        type = "panel",
        name = panelName,
        displayName = panelName,
        author = this.Author,
        version = tostring(this.Version),
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local settingsPanel = LAM:RegisterAddonPanel("InventoryCompanionPanel", panelData)
    this.OpenSettingsPanel = function()
        LAM:OpenToPanel(settingsPanel)
    end
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
        if panel == settingsPanel then
            this.state.isCurrencySettingsOpen = true
        end
    end)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel == settingsPanel then
            this.state.isCurrencySettingsOpen = false
        end
    end)
    this.RefreshAutoCategoryUI = function()
        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", settingsPanel)
        if this.RefreshAutoCategoryEditor then this.RefreshAutoCategoryEditor() end
        if this.RefreshTrackedItemsEditor then this.RefreshTrackedItemsEditor() end
        if this.RefreshGroupsEditor then this.RefreshGroupsEditor() end
    end

    local optionsData = {
        {
            type = "header",
            name = "Account-wide Settings",
        },
        {
            type = "slider",
            name = "Item Transfer Delay (ms)",
            tooltip = "Delay between item transfers. Lower values speed up transfers, but setting it too low may cause ESO to disconnect you.",
            min = 1,
            max = 2000,
            step = 10,
            getFunc = function() return this.accountWide.bankItemDelay end,
            setFunc = function(v) this.accountWide.bankItemDelay = v end,
            default = this.defaultsAccount.bankItemDelay,
        },
        {
            type = "checkbox",
            name = "Auto-Merge Chest Stacks",
            tooltip = "Automatically merge matching backpack items onto existing stacks when opening house storage chests.",
            getFunc = function() return this.accountWide.autoMergeChests end,
            setFunc = function(v) 
                this.accountWide.autoMergeChests = v 
                this.UpdateEventRegistry()
            end,
            default = this.defaultsAccount.autoMergeChests,
        },
        {
            type = "header",
            name = "AutoCategory Integration",
        },
        {
            type = "description",
            text = function()
                local _, message = this.AutoCategoryIntegration.GetStatus()
                if this.AutoCategoryIntegration.NeedsRecovery() then
                    return this.AutoCategoryIntegration.GetRecoveryMessage()
                end
                return message
            end,
        },
        {
            type = "button",
            name = "More information",
            func = function() this.OpenAutoCategoryPanel() end,
            hidden = function() return not this.AutoCategoryIntegration.NeedsRecovery() end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Enable AutoCategory Integration",
            tooltip = "Enable integration for the whole account. Category orders and inclusion follow the selected settings profile.",
            getFunc = function() return this.GetAutoCategoryState().configuredEnabled end,
            setFunc = function(enabled)
                this.SetAutoCategoryIntegrationEnabled(enabled)
                this.RefreshAutoCategoryUI()
            end,
            disabled = function() return not this.AutoCategoryIntegration.IsAvailable() end,
        },
        {
            type = "button",
            name = "Open AutoCategory Editor",
            tooltip = "Manage category order and choose which groups and native categories to include in each inventory area.",
            func = function()
                this.OpenAutoCategoryPanel()
            end,
            disabled = function() return not this.AutoCategoryIntegration.IsPanelAvailable() end,
            hidden = function() return this.AutoCategoryIntegration.NeedsRecovery() end,
            width = "full",
        },
        {
            type = "header",
            name = "Panel Setup",
        },
        {
            type = "button",
            name = "Manage Items",
            tooltip = "Choose which items and groups to track, show on the panel, or receive notifications for.",
            func = function()
                this.OpenEditItemsPanel()
            end,
            width = "full",
        },
        {
            type = "submenu",
            name = "Item Tracker Panel",
            tooltip = "Configure the movable tracked items HUD window.",
            controls = {
                {
                    type = "checkbox",
                    name = "Show Tracked Items Panel",
                    tooltip = "Master switch to show or hide the Item Tracker window.",
                    getFunc = function() return this.GetSettingsProfile().showTrackedItemsPanel ~= false end,
                    setFunc = this.SetItemTrackerPanelVisible,
                    default = this.defaultsAccount.showTrackedItemsPanel,
                },
                {
                    type = "slider",
                    name = "Tracker Group Threshold",
                    tooltip = "Minimum number of visible items required before group headers are rendered. Below this, items render as a flat, alphabetized list.",
                    min = 1,
                    max = 30,
                    step = 1,
                    getFunc = function() return this.GetSettingsProfile().trackerGroupThreshold or 8 end,
                    setFunc = function(v) 
                        this.GetSettingsProfile().trackerGroupThreshold = v
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.trackerGroupThreshold,
                },
                {
                    type = "slider",
                    name = "Tracker Title Size",
                    tooltip = "Set the regular-weight tracker title font size. The edit icon scales to match; item rows are unchanged.",
                    min = 16,
                    max = 28,
                    step = 1,
                    getFunc = function() return this.GetSettingsProfile().trackerTitleSize end,
                    setFunc = function(value)
                        this.GetSettingsProfile().trackerTitleSize = value
                        this.RefreshItemTrackerPanel()
                    end,
                    default = this.defaultsAccount.trackerTitleSize,
                },
                {
                    type = "slider",
                    name = "Maximum Visible Rows",
                    tooltip = "Limit the tracker item area. Wrapped lines use additional rows. When needed, names become single-line, categories collapse, and remaining overflow scrolls. The title is not counted.",
                    min = 5,
                    max = 50,
                    step = 1,
                    getFunc = function() return this.GetSettingsProfile().trackerMaxRows end,
                    setFunc = function(value)
                        this.GetSettingsProfile().trackerMaxRows = value
                        this.RefreshItemTrackerPanel("settings")
                    end,
                    default = this.defaultsAccount.trackerMaxRows,
                },
				{
                    type = "checkbox",
                    name = "Multiline Item Names",
                    tooltip = "If enabled, long item names will wrap onto multiple lines instead of truncating with ellipses.",
                    getFunc = function() return this.GetSettingsProfile().wrapTrackedItemNames == true end,
                    setFunc = function(v) 
                        this.GetSettingsProfile().wrapTrackedItemNames = v
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.wrapTrackedItemNames,
                },
				{
                    type = "checkbox",
                    name = "Show Empty Tracked Items",
                    tooltip = "If enabled, tracked items with a count of 0 will still be shown.",
                    getFunc = function() return this.GetSettingsProfile().showEmptyTrackedItems ~= false end,
                    setFunc = function(v) 
                        this.GetSettingsProfile().showEmptyTrackedItems = v
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.showEmptyTrackedItems,
                },
            },
        },
        {
            type = "submenu",
            name = "Currency Summary Panel",
            tooltip = "Choose which currencies and capacity indicators appear in the Currency Summary Panel.",
            controls = this.GetCurrencyPanelSettingsControls(),
        },
        {
            type = "submenu",
            name = "Standalone Progress Bars",
            tooltip = "Choose which capped resources have independent movable progress bars.",
            controls = GetStandaloneProgressBarControls(),
        },
        {
            type = "header",
            name = "Debugging",
        },
        {
            type = "checkbox",
            name = "Enable Debug Mode",
            tooltip = "Output verbose debug logs to the chat window.",
            getFunc = function() return this.accountWide.debugEnabled end,
            setFunc = function(v) 
                this.accountWide.debugEnabled = v
            end,
            default = this.defaultsAccount.debugEnabled,
        },
        {
            type = "slider",
            name = "AutoCategory Editor Slow-Action Limit (ms)",
            tooltip = "With Debug Mode on, AutoCategory editor actions that take longer than this print a timing report to chat.",
            min = 50,
            max = 5000,
            step = 50,
            getFunc = function() return this.accountWide.autoCategoryTimingThresholdMs end,
            setFunc = function(v) this.accountWide.autoCategoryTimingThresholdMs = v end,
            disabled = function() return not this.accountWide.debugEnabled end,
            default = this.defaultsAccount.autoCategoryTimingThresholdMs,
        },
    }

    local integrationControls = {}
    local first
    for index, option in ipairs(optionsData) do
        if option.type == "header" and option.name == "AutoCategory Integration" then first = index end
        if first and option.type == "header" and option.name == "Panel Setup" then
            for position = first, index - 1 do integrationControls[#integrationControls + 1] = optionsData[position] end
            for _ = first, index - 1 do table.remove(optionsData, first) end
            break
        end
    end
    table.insert(optionsData, 4, { type = "header", name = "Profile Settings" })
    local profileControls = GetProfileControls()
    for index = #profileControls, 1, -1 do table.insert(optionsData, 5, profileControls[index]) end
    for _, control in ipairs({
        { type = "button", name = "Manage Groups", func = this.OpenEditGroupsPanel, width = "half" },
        { type = "button", name = "Manage AutoCategory", func = this.OpenAutoCategoryPanel, width = "half",
            disabled = function() return not this.AutoCategoryIntegration.IsPanelAvailable() end },
    }) do
        table.insert(optionsData, 5 + #profileControls + 2, control)
    end
    optionsData[#optionsData + 1] = { type = "header", name = "Integrations" }
    for _, option in ipairs(integrationControls) do
        if option.type ~= "header" and option.type ~= "description" then optionsData[#optionsData + 1] = option end
    end
    for _, integration in ipairs({ "TTC", "FCO ItemSaver" }) do
        local controls = {
            { type = "description", text = "Planned future development; not yet implemented." },
            { type = "checkbox", name = "Enable " .. integration, getFunc = function() return false end,
                setFunc = function() error("Planned integration controls are disabled") end,
                disabled = true },
        }
        if integration == "TTC" then
            for _, band in ipairs({
                { "Trash below", 100 }, { "Low Level up to", 100 }, { "Mid Level up to", 1000 },
                { "Expensive up to", 5000 }, { "Superior up to", 10000 }, { "Amazing up to", 100000 },
                { "Jackpot above", 100000 },
            }) do
                local label, value = band[1], band[2]
                controls[#controls + 1] = { type = "editbox", name = label .. " (gold per item)",
                    setFunc = function() error("Planned integration controls are disabled") end,
                    getFunc = function() return tostring(value) end, disabled = true }
            end
        end
        optionsData[#optionsData + 1] = { type = "submenu", name = integration .. " (planned)",
            disabled = true, controls = controls }
    end
    optionsData[#optionsData + 1] = { type = "submenu", name = "AutoCategory Information",
        controls = { { type = "description", text = this.GetAutoCategoryInfoText } } }
    LAM:RegisterOptionControls("InventoryCompanionPanel", optionsData)
end
