local this = InventoryCompanion
local controls, pooled = {}, {}
local counters, fixture

TOPLEFT, TOPRIGHT, BOTTOMLEFT = "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT"
MOUSE_BUTTON_INDEX_LEFT, MOUSE_BUTTON_INDEX_RIGHT = 1, 2
TEXT_WRAP_MODE_ELLIPSIS, DL_CONTROLS = 1, 1
ZO_SCROLL_BAR_WIDTH = 16
ZoFontGame = { GetFontInfo = function() return "regular-font" end }
BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK, BAG_VIRTUAL = 1, 2, 3, 4

local function Control(name, parent, width, height)
    local control = { name = name, parent = parent, width = width or 0, height = height or 22,
        hidden = false, children = {}, handlers = {}, text = "", x = 0, y = 0 }
    controls[name] = control
    function control:SetHidden(value) self.hidden = value end
    function control:IsHidden() return self.hidden end
    function control:SetHandler(event, handler) self.handlers[event] = handler end
    function control:SetText(text) self.text = text end
    function control:SetTexture(texture) self.texture = texture end
    function control:SetWidth(value) self.width = value end
    function control:SetHeight(value)
        self.height = value
        if self.isRow then counters.rowLayouts = counters.rowLayouts + 1 end
    end
    function control:SetDimensions(w, h) self.width, self.height = w, h end
    function control:GetWidth() return self.width end
    function control:GetHeight() return self.height end
    function control:ClearAnchors() self.relative = nil end
    function control:SetAnchor(point, relative, relativePoint, x, y)
        self.point, self.relative, self.relativePoint = point, relative, relativePoint
        self.x, self.y = x or 0, y or 0
    end
    function control:GetLeft()
        if self.isRow then return self.parent:GetLeft() + self.x end
        local relative = self.relative or self.parent
        local left = relative and relative:GetLeft() or 0
        if self.relativePoint == TOPRIGHT then left = left + relative:GetWidth() end
        if self.point == TOPRIGHT then left = left - self.width end
        return left + self.x
    end
    function control:GetTop()
        local relative = self.relative or self.parent
        local top = relative and relative:GetTop() or 0
        if self.relativePoint == BOTTOMLEFT then top = top + relative:GetHeight() end
        return top + self.y
    end
    function control:GetTextWidth() return #tostring(self.text) * 7 end
    function control:GetNumLines()
        counters.measurements = counters.measurements + 1
        return math.max(1, math.ceil(self:GetTextWidth() / math.max(1, self.width)))
    end
    function control:SetDimensionConstraints(w, h) self.width, self.height = w, h end
    function control:GetNumChildren() return #self.children end
    function control:GetChild(index) return self.children[index] end
    function control:SetMouseEnabled() end
    function control:SetDrawLayer() end
    function control:SetDrawLevel() end
    function control:SetAlpha() end
    function control:SetWrapMode() end
    function control:SetFont(font)
        self.font = font
        self.height = tonumber(font:match("|(%d+)|"))
    end
    function control:StartMoving() end
    return control
end

function GetControl(parent, suffix) return assert(controls[parent.name .. suffix], suffix) end
function CreateControlFromVirtual(prefix, parent, _, index)
    counters.creations = counters.creations + 1
    local row = Control(prefix .. index, parent, 320, 22)
    row.isRow = true
    for _, suffix in ipairs({ "ExpandIcon", "Icon", "Name", "Count" }) do
        local child = Control(row.name .. suffix, row, suffix == "Count" and 0 or 18, 22)
        if suffix == "Count" then child:SetAnchor(TOPRIGHT, row, TOPRIGHT, -4, 2) end
        row.children[#row.children + 1] = child
    end
    pooled[index] = row
    return row
end

GuiRoot = Control("root", nil, 1920, 1080)
InventoryCompanion_ItemTrackerFloat = Control("tracker", GuiRoot, 360, 60)
InventoryCompanion_ItemTrackerFloatContainer = Control("container", InventoryCompanion_ItemTrackerFloat, 340, 52)
InventoryCompanion_ItemTrackerFloatTitle = Control("title", InventoryCompanion_ItemTrackerFloatContainer, 100, 22)
InventoryCompanion_ItemTrackerFloatEditIcon = Control("edit", InventoryCompanion_ItemTrackerFloatContainer, 18, 18)
InventoryCompanion_ItemTrackerFloatContainerRows = Control("rows", InventoryCompanion_ItemTrackerFloatContainer, 340, 24)
local rows = InventoryCompanion_ItemTrackerFloatContainerRows
local scroll = Control("rowsScroll", rows, 320, 24)
local child = Control("rowsScrollChild", scroll, 320, 22)
rows.scroll = scroll
scroll.offset = 0
function scroll:GetScrollOffsets() return 0, self.offset end
function ZO_Scroll_UpdateScrollBar() end
function ZO_Scroll_ScrollAbsoluteInstantly(_, offset)
    scroll.offset = offset
end
function ZO_Scroll_ResetToTop() scroll.offset = 0 end
function ZO_Scroll_OnMouseWheel(_, delta)
    scroll.offset = math.max(0, math.min(child.height - rows.height, scroll.offset - delta * 40))
end
function GetItemLinkName(link) return link end
function GetItemQualityColor() return { Colorize = function(_, text) return text end } end
function GetItemLinkQuality() return 1 end
function IsESOPlusSubscriber() return false end
function ZO_ClearTable(values) for key in pairs(values) do values[key] = nil end end
this.Utils = { FormatBigNumber = tostring }

local realSetRuleFlag = this.SetRuleFlag
this.SetRuleFlag = function(...)
    counters.writes = counters.writes + 1
    return realSetRuleFlag(...)
end

local function AddItem(group, length)
    local index = #fixture.index[group] + 1
    local id = fixture.groupIds[group] * 10000 + index
    fixture.index[group][index] = id
    fixture.items[id] = { link = string.rep("x", length or 8) .. string.format("%04d", id),
        icon = "icon", bagCount = 1, bankCount = 0 }
    return id
end

local function Setup(sizes, budget, expanded, wrapped, length)
    counters = { scans = 0, creations = 0, measurements = 0, rowLayouts = 0, writes = 0 }
    fixture = { index = {}, items = {}, groupIds = {} }
    this.accountWide = { trackedRules = {}, trackedItems = {}, showTrackedItemsPanel = true,
        showEmptyTrackedItems = false, trackerMaxRows = budget, trackerGroupThreshold = 1,
        trackerOffsetX = 50, trackerOffsetY = 50, wrapTrackedItemNames = wrapped == true, trackerTitleSize = 20 }
    this.character = { trackedRules = {}, trackedItems = {}, useCharacterItemList = false }
    this.defaultsAccount = { trackerMaxRows = 20, trackerTitleSize = 20 }
    this.preLoadedRulesets = {}
    for index, size in ipairs(sizes) do
        local name = "group" .. index
        fixture.groupIds[name], fixture.index[name] = index, {}
        this.preLoadedRulesets[name] = { displayName = name, patterns = { name },
            display = { show = true, bank = false, notify = false, isHidden = false,
                group = true, isExpanded = expanded == true } }
        for _ = 1, size do AddItem(name, length) end
    end
    this.preLoadedRulesets.miscellaneous = { displayName = "miscellaneous", patterns = {},
        display = { show = true, bank = false, notify = false, isHidden = false,
            group = true, isExpanded = false } }
    this.InvalidateRuleCache()
    this.GetMasterItemList = function()
        counters.scans = counters.scans + 1
        local snapshot = { items = {}, ruleIndex = {} }
        for id, item in pairs(fixture.items) do snapshot.items[id] = item end
        for name, ids in pairs(fixture.index) do
            snapshot.ruleIndex[name] = {}
            for i, id in ipairs(ids) do snapshot.ruleIndex[name][i] = id end
        end
        return snapshot
    end
    GuiRoot.height = 1080
    return fixture
end

local function Expanded(name) return this.GetActiveTrackedRules()[name].display.isExpanded end
local function VisibleRows()
    local result = {}
    for _, row in ipairs(pooled) do
        if not row.hidden then result[#result + 1] = row end
    end
    return result
end
local function Click(name)
    for _, row in ipairs(VisibleRows()) do
        if GetControl(row, "Name").text == name then
            row.handlers.OnMouseDown(row, MOUSE_BUTTON_INDEX_LEFT)
            return
        end
    end
    error("Missing group header: " .. name)
end
local function Equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end

function this.GetTrackerPanelTests()
    local tests = {}
    local function Add(name, run) tests[#tests + 1] = { name = name, run = run } end

    Add("Tracker opens all categories at the exact row budget and scans once", function()
        Setup({ 2, 2 }, 6, false)
        this.RefreshItemTrackerPanel()
        Equal(#VisibleRows(), 6)
        assert(Expanded("group1") and Expanded("group2"))
        Equal(counters.scans, 1)
        Equal(counters.writes, 2)
        this.RefreshItemTrackerPanel()
        Equal(counters.writes, 2)
    end)

    Add("Tracker manual collapse sticks until relevant content changes", function()
        Setup({ 2, 2 }, 6, true)
        this.RefreshItemTrackerPanel()
        Click("group1")
        this.RefreshItemTrackerPanel()
        assert(not Expanded("group1") and Expanded("group2"))
        Equal(#VisibleRows(), 4)
    end)

    Add("Tracker explicit expansion preserves others when it fits and collapses all others on overflow", function()
        Setup({ 3, 3, 3 }, 9, false)
        this.RefreshItemTrackerPanel()
        Click("group1")
        Click("group2")
        assert(Expanded("group1") and Expanded("group2"))
        Equal(#VisibleRows(), 9)
        Click("group3")
        assert(not Expanded("group1") and not Expanded("group2") and Expanded("group3"))
        Equal(#VisibleRows(), 6)
    end)

    Add("Tracker single-line fallback precedes collapse and preserves wrapping preference", function()
        Setup({ 2, 2 }, 6, true, true, 80)
        this.RefreshItemTrackerPanel()
        Equal(#VisibleRows(), 6)
        assert(Expanded("group1") and Expanded("group2") and this.accountWide.wrapTrackedItemNames)
        for _, row in ipairs(VisibleRows()) do Equal(row.height, 22) end
        Equal(counters.writes, 0)
        this.accountWide.trackerMaxRows = 20
        this.RefreshItemTrackerPanel("settings")
        local multiline = false
        for _, row in ipairs(VisibleRows()) do if row.height > 22 then multiline = true end end
        assert(multiline, "Wrapping should return when the preferred layout fits")
    end)

    Add("Tracker counts two and three wrapped lines as row equivalents", function()
        Setup({ 2 }, 7, true, true, 40)
        this.RefreshItemTrackerPanel()
        local units = 0
        for _, row in ipairs(VisibleRows()) do units = units + row.height / 22 end
        Equal(units, 5)
        for _, item in pairs(fixture.items) do item.link = string.rep("x", 80) end
        this.RefreshItemTrackerPanel("inventory")
        units = 0
        for _, row in ipairs(VisibleRows()) do units = units + row.height / 22 end
        Equal(units, 7)
    end)

    Add("Tracker passive overflow retains only the uniquely growing already-open category", function()
        Setup({ 2, 2 }, 6, true)
        this.RefreshItemTrackerPanel()
        AddItem("group1")
        this.RefreshItemTrackerPanel("inventory")
        assert(Expanded("group1") and not Expanded("group2"))
        Equal(#VisibleRows(), 5)
    end)

    Add("Tracker multi-category growth burst collapses all on overflow", function()
        Setup({ 2, 2 }, 6, true)
        this.RefreshItemTrackerPanel()
        AddItem("group1")
        AddItem("group2")
        this.RefreshItemTrackerPanel("inventory")
        assert(not Expanded("group1") and not Expanded("group2"))
        Equal(#VisibleRows(), 2)
    end)

    Add("Tracker does not open a collapsed receiving category on overflow", function()
        Setup({ 4, 4 }, 6, false)
        this.RefreshItemTrackerPanel()
        Click("group1")
        AddItem("group2")
        this.RefreshItemTrackerPanel("inventory")
        assert(Expanded("group1") and not Expanded("group2"))
        Equal(#VisibleRows(), 6)
    end)

    Add("Tracker configuration reintroduction does not displace open categories", function()
        Setup({ 4, 4 }, 6, false)
        this.RefreshItemTrackerPanel()
        Click("group1")
        this.SetRuleFlag("group2", "bank", true)
        this.RefreshItemTrackerPanel()
        assert(Expanded("group1") and not Expanded("group2"))
        this.accountWide.trackerMaxRows = 10
        this.RefreshItemTrackerPanel("settings")
        assert(Expanded("group1") and Expanded("group2"))
    end)

    Add("Tracker oversized category scrolls with a fixed header and clamps after shrinking", function()
        Setup({ 12, 2 }, 5, false)
        this.RefreshItemTrackerPanel()
        Click("group1")
        assert(Expanded("group1") and not Expanded("group2"))
        Equal(#VisibleRows(), 14)
        assert(child.height > rows.height)
        assert(InventoryCompanion_ItemTrackerFloat.height <= GuiRoot.height)
        ZO_Scroll_OnMouseWheel(rows, -5)
        local offset = scroll.offset
        this.RefreshItemTrackerPanel()
        Equal(scroll.offset, offset)
        Click("group1")
        Equal(scroll.offset, 0)
        Equal(#VisibleRows(), 2)
    end)

    Add("Tracker excessive headers and flat lists remain accessible within the viewport", function()
        Setup({ 2, 2, 2, 2, 2, 2 }, 5, false)
        this.RefreshItemTrackerPanel()
        Equal(#VisibleRows(), 6)
        assert(child.height > rows.height)
        this.accountWide.trackerGroupThreshold = 30
        this.RefreshItemTrackerPanel("settings")
        Equal(#VisibleRows(), 12)
        assert(child.height > rows.height)
    end)

    Add("Tracker empty state and small-screen bounds remain valid", function()
        Setup({}, 20, false)
        this.RefreshItemTrackerPanel()
        Equal(#VisibleRows(), 1)
        Equal(GetControl(VisibleRows()[1], "Count").text, "")
        Setup({ 30 }, 50, false)
        GuiRoot.height = 240
        this.RefreshItemTrackerPanel()
        Click("group1")
        assert(InventoryCompanion_ItemTrackerFloat.height <= 240)
    end)

    Add("Tracker keeps Miscellaneous and zero-stock filtering in the row policy", function()
        Setup({ 1, 3 }, 5, false)
        this.RefreshItemTrackerPanel()
        Equal(#VisibleRows(), 2)
        Click("miscellaneous")
        Equal(#VisibleRows(), 3)
        assert(Expanded("miscellaneous"))
        for _, item in pairs(fixture.items) do item.bagCount = 0 end
        this.RefreshItemTrackerPanel("inventory")
        Equal(#VisibleRows(), 1)
        assert(GetControl(VisibleRows()[1], "Name").text:find("No tracked items", 1, true))
    end)

    Add("Tracker trials never create member controls for collapsed categories", function()
        Setup({ 1000, 1000 }, 5, false, true, 80)
        local before = #pooled
        this.RefreshItemTrackerPanel()
        Equal(#VisibleRows(), 2)
        Equal(counters.creations, math.max(0, 2 - before))
        Equal(counters.rowLayouts, 2)
        Equal(counters.measurements, 0)
    end)

    Add("Tracker trials reuse a warmed pool with bounded measurement and layout work", function()
        Setup({ 30, 30, 30 }, 20, true, true, 80)
        this.RefreshItemTrackerPanel()
        local creations = counters.creations
        counters.scans, counters.rowLayouts, counters.measurements, counters.writes = 0, 0, 0, 0
        this.RefreshItemTrackerPanel()
        Equal(counters.scans, 1)
        Equal(counters.creations, creations)
        Equal(counters.rowLayouts, #VisibleRows())
        assert(counters.measurements <= 90 + #VisibleRows(), "One candidate measurement pass and one final pass")
        Equal(counters.writes, 0)
    end)

    Add("Tracker context switches reset comparisons and scroll offsets", function()
        Setup({ 12, 2 }, 5, false)
        this.RefreshItemTrackerPanel()
        Click("group1")
        ZO_Scroll_OnMouseWheel(rows, -5)
        assert(scroll.offset > 0)
        this.SetUseCharacterItemList(true)
        this.RefreshItemTrackerPanel("inventory")
        Equal(scroll.offset, 0)
    end)

    Add("Tracker context revision changes only at profile and reset boundaries", function()
        Setup({ 2 }, 5, false)
        local context, revision = this.GetTrackerContext()
        this.SetRuleFlag("group1", "isExpanded", true)
        this.InvalidateRuleCache()
        local after, unchanged = this.GetTrackerContext()
        Equal(context, after)
        Equal(revision, unchanged)
        this.ResetRule("group1")
        local _, reset = this.GetTrackerContext()
        Equal(reset, revision + 1)
        _G[this.SettingsName] = nil
        assert(not this.CopyProfile("missing"))
        local _, failed = this.GetTrackerContext()
        Equal(failed, reset)
        _G[this.SettingsName] = { Default = { account = { source = { trackedRules = {}, trackedItems = {} } } } }
        assert(this.CopyProfile("source"))
        local importedContext, imported = this.GetTrackerContext()
        Equal(importedContext, context)
        Equal(imported, reset + 1)
    end)

    Add("Tracker final automatic expansion choices survive context reinitialization", function()
        Setup({ 3, 3 }, 7, false)
        this.RefreshItemTrackerPanel()
        Click("group1")
        Click("group2")
        assert(not Expanded("group1") and Expanded("group2"))
        assert(this.accountWide.trackedRules.group2.display.isExpanded == true)
        this.SetUseCharacterItemList(false)
        this.RefreshItemTrackerPanel()
        assert(not Expanded("group1") and Expanded("group2"))
        Equal(#VisibleRows(), 5)
    end)

    Add("Tracker uses the actual inventory debounce queue for a multi-category burst", function()
        Setup({ 2, 2 }, 6, true)
        this.RefreshItemTrackerPanel()
        EVENT_OPEN_BANK, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, EVENT_CURRENCY_UPDATE = 1, 2, 3
        EVENT_CURRENCY_CAPS_CHANGED, EVENT_INVENTORY_BAG_CAPACITY_CHANGED = 4, 5
        EVENT_INVENTORY_BANK_CAPACITY_CHANGED, EVENT_PLAYER_ACTIVATED = 6, 7
        REGISTER_FILTER_BAG_ID = 1
        local registered, pending, serial = {}, {}, 0
        EVENT_MANAGER = {
            RegisterForEvent = function(_, name, _, handler) registered[name] = handler end,
            UnregisterForEvent = function() end,
            AddFilterForEvent = function() end,
        }
        function zo_callLater(callback)
            serial = serial + 1
            pending[serial] = callback
            return serial
        end
        function zo_removeCallLater(handle) pending[handle] = nil end
        for _, name in ipairs({ "HasVisibleProgressBars", "HasVisibleCapacityResources",
            "HasCapacityNotifications", "HasCurrencyResourcesToTrack", "HasCurrencyNotifications", "HasVisibleCurrencyProgressBars",
            "HasVisibleCappedCurrencyResources", "HasVisibleCappedProgressBars",
            "IsProgressBarVisible", "IsCapacityResourceVisible" }) do
            this[name] = function() return false end
        end
        this.HandleTrackedItemInventoryUpdate = function() end
        assert(loadstring(TrackerEventSource))()
        this.UpdateEventRegistry()
        local handler = assert(registered[this.Name .. "_Event_SlotUpdate_Backpack"])
        local scans = counters.scans
        AddItem("group1")
        for index = 1, 50 do handler(2, BAG_BACKPACK, index, true, nil, nil, 1) end
        AddItem("group2")
        for index = 51, 100 do handler(2, BAG_BACKPACK, index, true, nil, nil, 1) end
        Equal(counters.scans, scans)
        local callbacks = 0
        for _, callback in pairs(pending) do callbacks = callbacks + 1; callback() end
        Equal(callbacks, 1)
        Equal(counters.scans, scans + 1)
        assert(not Expanded("group1") and not Expanded("group2"))
    end)

    Add("Tracker row preference validates defaults and malformed external input", function()
        Setup({}, 20, false)
        this.accountWide.trackerMaxRows = nil
        this.ValidateTrackerSettings()
        Equal(this.accountWide.trackerMaxRows, 20)
        for _, value in ipairs({ "20", true, {}, 0, 4, 51, 5.5, math.huge, 0 / 0 }) do
            this.accountWide.trackerMaxRows = value
            assert(not pcall(this.ValidateTrackerSettings), "Malformed row budget must fail")
        end
        for _, value in ipairs({ 5, 20, 50 }) do
            this.accountWide.trackerMaxRows = value
            this.ValidateTrackerSettings()
            Equal(this.accountWide.trackerMaxRows, value)
        end
    end)

    Add("Tracker title uses adjustable regular font and matching icon without changing rows", function()
        Setup({ 2 }, 20, false)
        for _, size in ipairs({ 16, 20, 28 }) do
            this.accountWide.trackerTitleSize = size
            this.RefreshItemTrackerPanel()
            Equal(InventoryCompanion_ItemTrackerFloatTitle.font, "regular-font|" .. size .. "|soft-shadow-thin")
            Equal(InventoryCompanion_ItemTrackerFloatEditIcon.width, size)
            Equal(InventoryCompanion_ItemTrackerFloatEditIcon.height, size)
            for _, row in ipairs(VisibleRows()) do Equal(row.height, 22) end
        end
        this.accountWide.trackerTitleSize = nil
        this.ValidateTrackerSettings()
        Equal(this.accountWide.trackerTitleSize, 20)
        for _, value in ipairs({ "20", true, {}, 15, 29, 20.5, math.huge, 0 / 0 }) do
            this.accountWide.trackerTitleSize = value
            assert(not pcall(this.ValidateTrackerSettings))
        end
    end)

    Add("Tracker warmed synthetic refresh workloads stay within explicit limits", function()
        local results = {}
        for _, workload in ipairs({ { 20, 100, 250 }, { 1000, 20, 1500 } }) do
            Setup({ workload[1] }, 20, false, true, 80)
            this.RefreshItemTrackerPanel()
            local creations = counters.creations
            local started = GetGameTimeMilliseconds()
            for _ = 1, workload[2] do this.RefreshItemTrackerPanel("inventory") end
            local elapsed = GetGameTimeMilliseconds() - started
            assert(elapsed <= workload[3], "Tracker refresh timing limit exceeded: " .. elapsed)
            Equal(counters.creations, creations)
            results[#results + 1] = string.format("%d x %d items: %d/%d ms", workload[2], workload[1], elapsed, workload[3])
        end
        return table.concat(results, "; ")
    end)
    Add("Tracker keybinding changes saved visibility and updates inventory listeners immediately", function()
        Setup({ 2 }, 20, false)
        this.RefreshItemTrackerPanel()
        local registry = this.UpdateEventRegistry
        local updates = 0
        this.UpdateEventRegistry = function() updates = updates + 1 end
        local scans = counters.scans
        this.ToggleItemTrackerPanel()
        assert(this.accountWide.showTrackedItemsPanel == false)
        assert(InventoryCompanion_ItemTrackerFloat:IsHidden())
        Equal(counters.scans, scans)
        Equal(updates, 1)
        this.ToggleItemTrackerPanel()
        assert(this.accountWide.showTrackedItemsPanel == true)
        assert(not InventoryCompanion_ItemTrackerFloat:IsHidden())
        Equal(counters.scans, scans + 1)
        Equal(updates, 2)
        this.accountWide.showTrackedItemsPanel = nil
        this.ToggleItemTrackerPanel()
        assert(this.accountWide.showTrackedItemsPanel == false, "Missing optional visibility means shown, so toggle must hide")
        this.UpdateEventRegistry = registry
    end)

    Add("Main addon settings open the item editor directly even when tracker is disabled", function()
        Setup({ 2 }, 20, false)
        this.accountWide.showTrackedItemsPanel = false
        this.defaultsCharacter = {}
        this.Utils.DisplayName = function() return "Inventory Companion" end
        this.GetCurrencyPanelSettingsControls = function() return {} end
        this.GetProgressBarResources = function() return {} end
        this.GetProgressBarAlertColor = function() return {} end
        local options
        LibAddonMenu2 = {
            RegisterAddonPanel = function() return {} end,
            RegisterOptionControls = function(_, _, controls) options = controls end,
        }
        CALLBACK_MANAGER = { RegisterCallback = function() end }
        this.CreateSettingsPanel()
        local button, visibility
        for _, option in ipairs(options) do
            if option.name == "Open Item Tracking Editor" then button = option end
            if option.name == "Item Tracker Panel" then
                for _, control in ipairs(option.controls) do
                    if control.name == "Show Tracked Items Panel" then visibility = control end
                end
            end
        end
        assert(button and button.type == "button", "Editor shortcut must be on the main settings page, not inside a submenu")
        assert(visibility.setFunc == this.SetItemTrackerPanelVisible, "Checkbox and keybinding must share visibility handling")
        local current = "gameMenuInGame"
        SCENE_MANAGER = {
            IsShowing = function(_, name) return current == name end,
            Hide = function(_, name) if current == name then current = nil end end,
            Show = function(_, name) current = name end,
        }
        local refreshes = 0
        this.RefreshTrackedItemsEditor = function() refreshes = refreshes + 1 end
        button.func()
        Equal(current, "InventoryCompanion_TrackedItemsScene")
        Equal(refreshes, 1)
        button.func()
        Equal(current, "InventoryCompanion_TrackedItemsScene")
        Equal(refreshes, 2)
        assert(this.accountWide.showTrackedItemsPanel == false, "Opening the editor must not change saved HUD visibility")
    end)
    return tests
end
