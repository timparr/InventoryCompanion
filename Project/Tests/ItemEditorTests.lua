local this = InventoryCompanion
local controls = {}
local editorRefreshes, trackerRefreshes, ruleWrites, registryUpdates = 0, 0, 0, 0
local inventory = {}
local events, mouseOver = {}, nil

local function Control(name)
    local control = { name = name, children = {}, handlers = {}, hidden = false, text = "" }
    function control:SetHidden(value) self.hidden = value end
    function control:SetEnabled(value) self.enabled = value end
    function control:IsHidden() return self.hidden end
    function control:SetHandler(event, handler) self.handlers[event] = handler end
    function control:SetText(text) self.text = text end
    function control:GetText() return self.text end
    function control:GetFont() return self.font or "ZoFontGameSmall" end
    function control:GetWidth() return self.width or 170 end
    function control:SetFont(font) self.font = font end
    function control:GetTextWidth()
        assert(self.width == nil, "Text measurement must use an unconstrained label")
        assert(self.font == "ZoFontGameSmall", "Measure using the summary label's font")
        return #self.text * 7
    end
    function control:SetColor(r, g, b, a) self.color = { r, g, b, a } end
    function control:SetDimensions(w, h) self.width, self.height = w, h end
    function control:SetWidth(width) self.width = width end
    function control:GetHeight() return self.height or 52 end
    function control:GetTop() return self.top or 0 end
    function control:GetParent() return self.parent end
    function control:SetDrawTier() end
    function control:ClearAnchors() end
    function control:SetAnchor() end
    controls[name] = control
    return control
end

function GetControl(parent, name)
    if not parent.children[name] then parent.children[name] = Control(parent.name .. name) end
    parent.children[name].parent = parent
    return parent.children[name]
end
function CreateControlFromVirtual(prefix, parent, template, index) return Control(prefix .. index) end
function ZO_CheckButton_SetCheckState(control, checked) control.checked = checked end
function ZO_CheckButton_SetToggleFunction(control, callback) control.toggle = callback end
function ZO_ComboBox_ObjectFromContainer()
    return { SetSortsItems = function() end }
end
function ZO_Dialogs_RegisterCustomDialog() end
InformationTooltip = { AddLine = function() end }
function InitializeTooltip() end
function ClearTooltip() end
function SetGameCameraUIMode() end
function GetUnitName() return "Test character" end
function GetItemLinkName(link) return link end
function GetItemLinkIcon() return "icon" end
GetStringWidth = nil
function IsESOPlusSubscriber() return false end
TOPLEFT, SCENE_SHOWING, SCENE_HIDDEN = "TOPLEFT", "showing", "hidden"
TOPRIGHT, BOTTOMRIGHT, RIGHT, DT_HIGH, KEY_ESCAPE = "TOPRIGHT", "BOTTOMRIGHT", "RIGHT", 1, 27
MOUSE_BUTTON_INDEX_LEFT, EVENT_GLOBAL_MOUSE_DOWN = 1, 9
BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK = 1, 2, 3
SCENE_MANAGER = {}
ZO_Scene = { New = function()
    return { AddFragment = function() end, RegisterCallback = function() end }
end }
ZO_FadeSceneFragment = { New = function() return {} end }
GAMEPAD_DIALOGS = { BASIC = 1 }
InventoryCompanion_TrackedItemsWindow = Control("window")
InventoryCompanion_ItemRowOptions = Control("options")
GetControl(InventoryCompanion_TrackedItemsWindow, "ScrollContainer").scroll = Control("scroll")
GuiRoot = Control("root")
GuiRoot.height = 1080
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, _, callback) events[name] = callback end,
    UnregisterForEvent = function(_, name) events[name] = nil end,
}
WINDOW_MANAGER = { GetMouseOverControl = function() return mouseOver end }
function ZO_PreHookHandler(control, event, callback)
    local original = control.handlers[event]
    control.handlers[event] = function(...)
        callback(...)
        if original then original(...) end
    end
end
this.UpdateEditorLayout = function() end
this.UpdateEventRegistry = function() registryUpdates = registryUpdates + 1 end
this.RefreshItemTrackerPanel = function() trackerRefreshes = trackerRefreshes + 1 end
this.GetTrackedItemCount = function() return 0 end
this.Scanning = { GetBagContents = function(bags, predicate)
    local result = {}
    for _, item in ipairs(inventory) do
        if predicate(item) then table.insert(result, item) end
    end
    return result
end }

local function Equal(actual, expected, message) assert(actual == expected, message) end
local function Row(index) return controls["InventoryCompanion_TrackedItemRow_" .. index] end
local function Handler(index, name)
    local control = GetControl(Row(index), name)
    return control.handlers.OnMouseDown or control.handlers.OnClicked
end
local function Option(index) return GetControl(InventoryCompanion_ItemRowOptions, "Option" .. index) end
local function SetOption(index, checked)
    local check = GetControl(Option(index), "Check")
    check.toggle(check, checked)
end
local function Detail(index, kind) return GetControl(GetControl(Row(index), kind), "Detail") end
local function Reject(callback, message)
    local ok, err = pcall(callback)
    assert(not ok and tostring(err):find(message, 1, true), "Expected contract error: " .. message)
end
local function Item(show)
    return { link = "A item", icon = "saved-icon",
        display = { show = show, notify = false, bank = false, group = false } }
end

function this.GetItemEditorTests()
    local refresh = this.RefreshTrackedItemsEditor
    this.RefreshTrackedItemsEditor = function()
        editorRefreshes = editorRefreshes + 1
        refresh()
    end
    local write = this.UpdateRuleFlag
    this.UpdateRuleFlag = function(...)
        ruleWrites = ruleWrites + 1
        write(...)
    end
    local tests = {}
    local function Add(name, run)
        table.insert(tests, { name = name, run = function()
            this.accountWide = { trackedItems = {}, trackedRules = {} }
            this.Utils = { DebugMessage = function() end }
            this.character = { trackedItems = {}, trackedRules = {}, useCharacterItemList = false,
                filterShow = true, filterNotify = true, filterMute = true, filterUntracked = false }
            this.preLoadedRulesets = { default = { displayName = "Default", patterns = { "*match*" },
                display = { show = true, notify = false, bank = false, group = true,
                    isExpanded = true, isHidden = false } } }
            inventory = {}
            editorRefreshes, trackerRefreshes, ruleWrites, registryUpdates = 0, 0, 0, 0
            this.InvalidateRuleCache()
            this.ValidateSavedRuleProfiles()
            run()
        end })
    end

    Add("Item editor leaves AutoCategory participation to its dedicated editor", function()
        local integration = this.AutoCategoryIntegration
        local previousAvailable, previousPanel = integration.IsAvailable, this.OpenAutoCategoryPanel
        local previousAutoCategory = AutoCategory
        local previousCallLater, scheduled = zo_callLater, {}
        zo_callLater = function(callback, delay)
            assert(type(callback) == "function" and delay == 100)
            scheduled[#scheduled + 1] = callback
        end
        AutoCategory = {}
        integration.IsAvailable = function() return not integration.IsFaulted() end
        this.autoCategoryFailure = nil
        this.accountWide.autoCategoryIntegrationEnabled = true
        this.accountWide.trackedRules.default = { autoCategoryEnabled = true }
        this.InvalidateRuleCache()
        local opened = 0
        this.OpenAutoCategoryPanel = function() opened = opened + 1 end
        local ok, failure = pcall(function()
            local bank = this.accountWide.autoCategoryOrder.contexts.bank
            bank.hidden["ic:default"] = true
            for _, state in ipairs({ "enabled", "off", "failed", "absent" }) do
                AutoCategory = state ~= "absent" and {} or nil
                this.accountWide.autoCategoryIntegrationEnabled = state ~= "off"
                this.autoCategoryFailure = state == "failed" and "synthetic failure" or nil
                this.RefreshTrackedItemsEditor()
                assert(Row(1).children.AutoCategory == nil and Row(1).children.CategorySpace == nil,
                    "Tracking rows must not create or configure AutoCategory columns")
                local navigation = GetControl(InventoryCompanion_TrackedItemsWindow, "BtnAutoCategory")
                assert(navigation.hidden == (state == "absent"))
                if state ~= "absent" then navigation.handlers.OnClicked() end
            end
            assert(opened == 3 and ruleWrites == 0 and trackerRefreshes == 0)
            AutoCategory = {}
            this.accountWide.autoCategoryIntegrationEnabled = true
            this.RefreshTrackedItemsEditor()
            Handler(1, "Show")()
            SetOption(2, false)
            Handler(1, "Notify")()
            SetOption(2, true)
            assert(ruleWrites == 2 and this.accountWide.trackedRules.default.autoCategoryEnabled == true)
            assert(#scheduled == 2, "Tracking edits must still schedule normal integration refreshes")
            for _, callback in ipairs(scheduled) do callback() end
            assert(this.accountWide.autoCategoryOrder.contexts.bank == bank and bank.hidden["ic:default"] == true,
                "Show and Notify must preserve AutoCategory participation")
        end)
        integration.IsAvailable, this.OpenAutoCategoryPanel = previousAvailable, previousPanel
        AutoCategory, this.autoCategoryFailure = previousAutoCategory, nil
        zo_callLater = previousCallLater
        assert(ok, failure)
    end)

    Add("Item editor toggles absent Show from its effective true default", function()
        local item = Item(nil)
        this.accountWide.trackedItems[10] = item
        this.RefreshTrackedItemsEditor()
        Handler(1, "Show")()
        SetOption(1, false)
        Equal(item.display.showBackpack, false, "Inherited backpack Show should turn off")
        Equal(item.display.notify, false, "Notify must be unchanged")
        Equal(item.icon, "saved-icon", "Icon must be unchanged")
        Equal(editorRefreshes, 2, "Action should refresh editor once")
        Equal(trackerRefreshes, 1, "Action should refresh tracker once")
    end)

    Add("Item editor group flags save sparse overrides and prune defaults", function()
        this.RefreshTrackedItemsEditor()
        Handler(1, "Show")()
        SetOption(3, true)
        Equal(this.accountWide.trackedRules.default.display.showBank, true, "Bank override should persist")
        Equal(this.accountWide.trackedRules.default.display.show, nil, "Unrelated flags stay sparse")
        SetOption(3, false)
        Equal(this.accountWide.trackedRules.default, nil, "Default should prune override")
        Equal(ruleWrites, 2, "Each click should write once")
        Equal(editorRefreshes, 3, "Each click should refresh editor once")
        Equal(trackerRefreshes, 2, "Each click should refresh tracker once")
    end)

    Add("Item editor untracked promotion preserves other values", function()
        this.GetSettingsProfile().filterUntracked = true
        inventory = { { itemId = 10, link = "A item", icon = "new-icon" } }
        this.RefreshTrackedItemsEditor()
        Equal(this.accountWide.trackedItems[10], nil, "Rendering must not promote item")
        Handler(1, "Notify")()
        SetOption(1, true)
        local tracked = this.accountWide.trackedItems[10]
        Equal(tracked.display.notifyChat, true, "Chat should promote item")
        Equal(this.ResolveItemDisplay(tracked.display).notifyHud, false, "HUD must remain off")
        Equal(tracked.display.show, false, "Promotion must preserve Show")
        Equal(tracked.display.bank, false, "Promotion must preserve bank")
        Equal(tracked.display.group, false, "Promotion must preserve group")
        Equal(tracked.link, "A item", "Promotion must preserve link")
        Equal(tracked.icon, "new-icon", "Promotion must preserve icon")
        Handler(1, "Show")()
        Equal(GetControl(Option(1), "Label").text, "Show backpack", "Items have no grouping control")
        Equal(Option(3).hidden, true, "Items have only two display controls")
        Equal(trackerRefreshes, 1, "Promotion should refresh tracker once")
    end)

    Add("Item editor recycled row rejects old actions without writes", function()
        local item = Item(true)
        this.accountWide.trackedItems[10] = item
        this.RefreshTrackedItemsEditor()
        local old = Handler(1, "Notify")
        this.accountWide.trackedItems[10] = nil
        this.RefreshTrackedItemsEditor()
        Reject(old, "obsolete row")
        Equal(ruleWrites, 0, "Old action must not write recycled group")
        Equal(trackerRefreshes, 0, "Rejected action must not refresh tracker")
    end)

    Add("Item editor profile switch rejects old toggles and removal", function()
        local item = Item(true)
        this.accountWide.trackedItems[10] = item
        this.character.trackedItems[10] = Item(true)
        this.RefreshTrackedItemsEditor()
        local toggle, remove = Handler(1, "Notify"), Handler(1, "BtnRemove")
        this.SetUseCharacterItemList(true)
        Reject(toggle, "obsolete profile")
        Reject(remove, "obsolete profile")
        Equal(item.display.notify, false, "Account data must not change")
        Equal(this.character.trackedItems[10].display.notify, false, "Character data must not change")
        this.RefreshTrackedItemsEditor()
        Handler(1, "Notify")()
        SetOption(1, true)
        Equal(this.character.trackedItems[10].display.notifyChat, true, "Fresh action targets character")
        Equal(item.display.notify, false, "Fresh action must not target account")
    end)

    Add("Item editor hidden and removed targets reject callbacks", function()
        this.accountWide.trackedItems[10] = Item(true)
        this.RefreshTrackedItemsEditor()
        local old = Handler(1, "Notify")
        InventoryCompanion_TrackedItemsWindow.handlers.OnEffectivelyHidden()
        Reject(old, "obsolete row")
        this.RefreshTrackedItemsEditor()
        local remove = Handler(1, "BtnRemove")
        this.accountWide.trackedItems[10] = nil
        Reject(remove, "removed item")
        Equal(trackerRefreshes, 0, "Invalid actions must not refresh tracker")
    end)

    Add("Item editor reads current flags rather than retained entry data", function()
        this.accountWide.trackedItems[10] = Item(true)
        this.RefreshTrackedItemsEditor()
        local replacement = Item(true)
        replacement.display.notify = true
        this.accountWide.trackedItems[10] = replacement
        Handler(1, "Notify")()
        Equal(GetControl(Option(1), "Check").checked, true, "Opening must use current saved value")
        SetOption(1, false)
        Equal(replacement.display.notifyChat, false, "Checkbox must edit current item")
        Equal(trackerRefreshes, 1, "Toggle should refresh tracker once")
    end)
    Add("Item editor popups dismiss without writes and invalidate checkbox callbacks", function()
        this.RefreshTrackedItemsEditor()
        Handler(1, "Notify")()
        local oldCheck = GetControl(Option(1), "Check")
        local oldToggle = oldCheck.toggle
        mouseOver = oldCheck
        events[this.Name .. "_ItemRowOptions"]()
        Equal(InventoryCompanion_ItemRowOptions.hidden, false, "Inside click must not close popup")
        mouseOver = GuiRoot
        events[this.Name .. "_ItemRowOptions"]()
        Equal(InventoryCompanion_ItemRowOptions.hidden, true, "Outside click must close popup")
        Reject(function() oldToggle(oldCheck, true) end, "obsolete popup")
        Handler(1, "Show")()
        InventoryCompanion_ItemRowOptions.handlers.OnKeyDown(nil, KEY_ESCAPE)
        Equal(InventoryCompanion_ItemRowOptions.hidden, true, "Escape must close popup")
        Handler(1, "Show")()
        GetControl(InventoryCompanion_TrackedItemsWindow, "ScrollContainer").scroll.handlers.OnScrollOffsetChanged()
        Equal(InventoryCompanion_ItemRowOptions.hidden, true, "Scrolling must close popup")
        Equal(ruleWrites, 0, "Opening and dismissal must not write")
        Equal(trackerRefreshes, 0, "Opening and dismissal must not refresh tracker")
    end)

    Add("Item editor shows all display and notification summaries in existing colors", function()
        for _, backpack in ipairs({ false, true }) do
            for _, bank in ipairs({ false, true }) do
                for _, grouped in ipairs({ false, true }) do
                    this.UpdateRuleFlag("default", "showBackpack", backpack)
                    this.UpdateRuleFlag("default", "showBank", bank)
                    this.UpdateRuleFlag("default", "group", grouped)
                    this.RefreshTrackedItemsEditor()
                    local expected = backpack and (bank and "Both" or "Backpack") or (bank and "Bank" or "None")
                    if (backpack or bank) and grouped then expected = expected .. ", grouped" end
                    Equal(Detail(1, "Show").text, expected, "Show summary must omit the column heading")
                    Equal(Detail(1, "Show").color[1], 1, "Existing warm color must be used")
                    Equal(Detail(1, "Show").color[4], (backpack or bank) and 1 or 0.5, "Inactive opacity must be retained")
                end
            end
        end
        for _, chat in ipairs({ false, true }) do
            for _, hud in ipairs({ false, true }) do
                this.UpdateRuleFlag("default", "notifyChat", chat)
                this.UpdateRuleFlag("default", "notifyHud", hud)
                this.RefreshTrackedItemsEditor()
                local expected = chat and (hud and "Both" or "Chat") or (hud and "HUD" or "None")
                Equal(Detail(1, "Notify").text, expected, "Notify summary must omit the column heading")
            end
        end
    end)

    Add("Item editor checkbox labels apply once and retarget popup after refresh", function()
        this.RefreshTrackedItemsEditor()
        Handler(1, "Notify")()
        GetControl(Option(1), "Label").handlers.OnMouseDown(nil, MOUSE_BUTTON_INDEX_LEFT)
        Equal(ruleWrites, 1, "Label click must write once")
        Equal(editorRefreshes, 2, "Label click must refresh editor once")
        Equal(trackerRefreshes, 1, "Label click must refresh tracker once")
        Equal(registryUpdates, 1, "Label click must update listeners once")
        Equal(GetControl(Option(1), "Check").checked, true, "Rebound popup must show current value")
        SetOption(2, true)
        Equal(Detail(1, "Notify").text, "Both", "Second edit must target same rule")
        Equal(ruleWrites, 2, "Second checkbox must write once")
        Handler(1, "Notify")()
        Equal(InventoryCompanion_ItemRowOptions.hidden, true, "Same trigger must dismiss popup")
    end)
    Add("Item editor Undo changes follows visit lifecycle and detects manual reversal", function()
        this.RefreshGroupsEditor, this.RefreshAutoCategoryEditor = function() end, function() end
        this.RefreshTrackedItemsEditor()
        local undo = GetControl(InventoryCompanion_TrackedItemsWindow, "BtnUndo")
        assert(undo.hidden)
        this.UpdateRuleFlag("default", "show", false)
        this.RefreshTrackedItemsEditor()
        assert(not undo.hidden)
        this.UpdateRuleFlag("default", "show", true)
        this.RefreshTrackedItemsEditor()
        assert(undo.hidden, "Manual reversal must hide Undo changes")
        this.UpdateRuleFlag("default", "show", false)
        this.RefreshTrackedItemsEditor()
        undo.handlers.OnClicked()
        assert(this.GetRuntimeRules().default.display.show and undo.hidden)
        this.UpdateRuleFlag("default", "show", false)
        this.RefreshTrackedItemsEditor()
        local stale = undo.handlers.OnClicked
        this.EndEditorVisit(InventoryCompanion_TrackedItemsWindow)
        this.RefreshTrackedItemsEditor()
        assert(undo.hidden and not this.GetRuntimeRules().default.display.show,
            "Reopening establishes a new baseline, not the previous opening state")
        Reject(stale, "previous editor visit")
    end)
    Add("Item editor removal updates notification listeners", function()
        this.accountWide.trackedItems[10] = Item(true)
        this.RefreshTrackedItemsEditor()
        Handler(1, "BtnRemove")()
        Equal(registryUpdates, 1, "Removing item must update listeners")
    end)
    return tests
end
