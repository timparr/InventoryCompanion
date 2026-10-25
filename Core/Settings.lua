InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

function this.CreateSettingsPanel()
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

    LAM:RegisterAddonPanel("InventoryCompanionPanel", panelData)

    local optionsData = {
        {
            type = "header",
            name = "Bank & Chest Operations",
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
            name = "On-Screen Indicators",
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
                    getFunc = function() return this.accountWide.showTrackedItemsPanel ~= false end,
                    setFunc = function(v) 
                        this.accountWide.showTrackedItemsPanel = v 
                        this.UpdateEventRegistry()
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.showTrackedItemsPanel,
                },
                -- NEW --
                {
                    type = "slider",
                    name = "Tracker Group Threshold",
                    tooltip = "Minimum number of visible items required before group headers are rendered. Below this, items render as a flat, alphabetized list.",
                    min = 1,
                    max = 30,
                    step = 1,
                    getFunc = function() return this.accountWide.trackerGroupThreshold or 8 end,
                    setFunc = function(v) 
                        this.accountWide.trackerGroupThreshold = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.trackerGroupThreshold,
                },
                -- /NEW --
				{
                    type = "checkbox",
                    name = "Multiline Item Names",
                    tooltip = "If enabled, long item names will wrap onto multiple lines instead of truncating with ellipses.",
                    getFunc = function() return this.accountWide.wrapTrackedItemNames == true end,
                    setFunc = function(v) 
                        this.accountWide.wrapTrackedItemNames = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.wrapTrackedItemNames,
                },
				{
                    type = "checkbox",
                    name = "Show Empty Tracked Items",
                    tooltip = "If enabled, tracked items with a count of 0 will still be shown.",
                    getFunc = function() return this.accountWide.showEmptyTrackedItems ~= false end,
                    setFunc = function(v) 
                        this.accountWide.showEmptyTrackedItems = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.showEmptyTrackedItems,
                },
                {
                    type = "checkbox",
                    name = "Use Character-Specific List",
                    tooltip = "If enabled, this character uses their own independent tracked items list instead of the shared account-wide list.",
                    getFunc = function() return this.character.useCharacterItemList == true end,
                    setFunc = function(v) 
                        this.character.useCharacterItemList = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                        if this.RefreshTrackedItemsEditor then this.RefreshTrackedItemsEditor() end
                    end,
                    default = this.defaultsCharacter.useCharacterItemList,
                },
            },
        },
        {
            type = "submenu",
            name = "Currency & Info Panel",
            tooltip = "Configure gold, bag, and bank summary elements.",
            controls = {
                {
                    type = "checkbox",
                    name = "Display Gold",
                    getFunc = function() return this.accountWide.showGold ~= false end,
                    setFunc = function(v) 
                        this.accountWide.showGold = v 
                        this.UpdateEventRegistry()
                        this.RefreshCurrencyPanel()
                    end,
                    default = this.defaultsAccount.showGold,
                },
                {
                    type = "checkbox",
                    name = "Display Bag Space",
                    getFunc = function() return this.accountWide.showBag ~= false end,
                    setFunc = function(v) 
                        this.accountWide.showBag = v 
                        this.UpdateEventRegistry()
                        this.RefreshCurrencyPanel()
                    end,
                    default = this.defaultsAccount.showBag,
                },
                {
                    type = "checkbox",
                    name = "Display Bank Space",
                    getFunc = function() return this.accountWide.showBank ~= false end,
                    setFunc = function(v) 
                        this.accountWide.showBank = v 
                        this.UpdateEventRegistry()
                        this.RefreshCurrencyPanel()
                    end,
                    default = this.defaultsAccount.showBank,
                },
            },
        },
        {
            type = "submenu",
            name = "Standalone Progress Bars",
            controls = {
                {
                    type = "checkbox",
                    name = "Show Backpack Bar",
                    getFunc = function() return this.accountWide.showBagBar ~= false end,
                    setFunc = function(v)
                        this.accountWide.showBagBar = v
                        this.UpdateEventRegistry()
                        this.RefreshProgressPanels()
                    end,
                    default = this.defaultsAccount.showBagBar,
                },
                {
                    type = "checkbox",
                    name = "Show Bank Bar",
                    getFunc = function() return this.accountWide.showBankBar ~= false end,
                    setFunc = function(v)
                        this.accountWide.showBankBar = v
                        this.UpdateEventRegistry()
                        this.RefreshProgressPanels()
                    end,
                    default = this.defaultsAccount.showBankBar,
                },
            },
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
    }

    LAM:RegisterOptionControls("InventoryCompanionPanel", optionsData)
end

-- Helper function to combine arrays into your main options table
local function AppendControls(target, source)
    for _, control in ipairs(source) do
        table.insert(target, control)
    end
    return target
end

-- 1. Bank & Chest Section
local function GetBankAndChestOptions(this)
    return {
        {
            type = "header",
            name = "Bank & Chest Operations",
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
    }
end

-- 2. On-Screen Indicators Submenu
local function GetOnScreenIndicatorsSubmenu(this)
    return {
        {
            type = "header",
            name = "On-Screen Indicators",
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
                    getFunc = function() return this.accountWide.showTrackedItemsPanel ~= false end,
                    setFunc = function(v) 
                        this.accountWide.showTrackedItemsPanel = v 
                        this.UpdateEventRegistry()
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.showTrackedItemsPanel,
                },
                {
                    type = "slider",
                    name = "Tracker Group Threshold",
                    tooltip = "Minimum number of visible items required before group headers are rendered.",
                    min = 1,
                    max = 30,
                    step = 1,
                    getFunc = function() return this.accountWide.trackerGroupThreshold or 8 end,
                    setFunc = function(v) 
                        this.accountWide.trackerGroupThreshold = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.trackerGroupThreshold,
                },
                -- (Other item tracker controls...)
            },
        },
        -- (Currency Submenu and Standalone Progress Bars Submenu can go here too...)
    }
end

-- 3. Debugging Section
local function GetDebuggingOptions(this)
    return {
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
    }
end

-- Main Panel Creation Function
function this.CreateSettingsPanel()
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

    LAM:RegisterAddonPanel("InventoryCompanionPanel", panelData)

    -- Assemble options cleanly
    local optionsData = {}
    AppendControls(optionsData, GetBankAndChestOptions(this))
    AppendControls(optionsData, GetOnScreenIndicatorsSubmenu(this))
    AppendControls(optionsData, GetDebuggingOptions(this))

    LAM:RegisterOptionControls("InventoryCompanionPanel", optionsData)
end

function this.CreateSettingsPanel()
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

    local optionsData = {
        {
            type = "header",
            name = "Bank & Chest Operations",
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
            name = "On-Screen Indicators",
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
                    getFunc = function() return this.accountWide.showTrackedItemsPanel ~= false end,
                    setFunc = function(v) 
                        this.accountWide.showTrackedItemsPanel = v 
                        this.UpdateEventRegistry()
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.showTrackedItemsPanel,
                },
                {
                    type = "slider",
                    name = "Tracker Group Threshold",
                    tooltip = "Minimum number of visible items required before group headers are rendered. Below this, items render as a flat, alphabetized list.",
                    min = 1,
                    max = 30,
                    step = 1,
                    getFunc = function() return this.accountWide.trackerGroupThreshold or 8 end,
                    setFunc = function(v) 
                        this.accountWide.trackerGroupThreshold = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.trackerGroupThreshold,
                },
				{
                    type = "checkbox",
                    name = "Multiline Item Names",
                    tooltip = "If enabled, long item names will wrap onto multiple lines instead of truncating with ellipses.",
                    getFunc = function() return this.accountWide.wrapTrackedItemNames == true end,
                    setFunc = function(v) 
                        this.accountWide.wrapTrackedItemNames = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.wrapTrackedItemNames,
                },
				{
                    type = "checkbox",
                    name = "Show Empty Tracked Items",
                    tooltip = "If enabled, tracked items with a count of 0 will still be shown.",
                    getFunc = function() return this.accountWide.showEmptyTrackedItems ~= false end,
                    setFunc = function(v) 
                        this.accountWide.showEmptyTrackedItems = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                    end,
                    default = this.defaultsAccount.showEmptyTrackedItems,
                },
                {
                    type = "checkbox",
                    name = "Use Character-Specific List",
                    tooltip = "If enabled, this character uses their own independent tracked items list instead of the shared account-wide list.",
                    getFunc = function() return this.character.useCharacterItemList == true end,
                    setFunc = function(v) 
                        this.character.useCharacterItemList = v 
                        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
                        if this.RefreshTrackedItemsEditor then this.RefreshTrackedItemsEditor() end
                    end,
                    default = this.defaultsCharacter.useCharacterItemList,
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
            controls = {
                {
                    type = "checkbox",
                    name = "Show Backpack Bar",
                    getFunc = function() return this.accountWide.showBagBar ~= false end,
                    setFunc = function(v)
                        this.accountWide.showBagBar = v
                        this.UpdateEventRegistry()
                        this.RefreshProgressPanels()
                    end,
                    default = this.defaultsAccount.showBagBar,
                },
                {
                    type = "checkbox",
                    name = "Show Bank Bar",
                    getFunc = function() return this.accountWide.showBankBar ~= false end,
                    setFunc = function(v)
                        this.accountWide.showBankBar = v
                        this.UpdateEventRegistry()
                        this.RefreshProgressPanels()
                    end,
                    default = this.defaultsAccount.showBankBar,
                },
            },
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
    }

    LAM:RegisterOptionControls("InventoryCompanionPanel", optionsData)
end
