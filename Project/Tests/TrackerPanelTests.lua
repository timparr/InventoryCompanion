local this = InventoryCompanion
local controls, pooled = {}, {}
local counters, fixture
local trackerTestDefaults = this.defaultsAccount
local productionGetBagContents = this.Scanning.GetBagContents
local productionReadSlot = this.Scanning.ReadSlot
local productionGetMasterItemList = this.GetMasterItemList
local productionHandleTrackedItemInventoryUpdate = this.HandleTrackedItemInventoryUpdate
local function NewAutoCategoryOrder()
    local order = { contexts = {} }
    for _, key in ipairs({ "backpack", "bank", "guild_bank", "house_bank",
        "crafting_station", "craft_bag", "furniture_vault" }) do
        order.contexts[key] = { display = {}, matching = {}, hidden = {}, displayPositions = {} }
    end
    return order
end

TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT = "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"
MOUSE_BUTTON_INDEX_LEFT, MOUSE_BUTTON_INDEX_RIGHT = 1, 2
TEXT_WRAP_MODE_ELLIPSIS, DL_CONTROLS = 1, 1
ZO_SCROLL_BAR_WIDTH = 16
ZoFontGame = { GetFontInfo = function() return "regular-font" end }
BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK, BAG_VIRTUAL = 1, 2, 3, 4

local function Control(name, parent, width, height)
    local control = { name = name, parent = parent, width = width or 0, height = height or 22,
        hidden = false, children = {}, handlers = {}, text = "", x = 0, y = 0, color = nil }
    controls[name] = control
    function control:SetHidden(value) self.hidden = value end
    function control:SetEnabled(value) self.enabled = value end
    function control:IsHidden() return self.hidden end
    function control:SetHandler(event, handler) self.handlers[event] = handler end
    function control:SetText(text) self.text = text end
    function control:SetTexture(texture) self.texture = texture end
    function control:SetColor(r, g, b, a) self.color = { r, g, b, a } end
    function control:SetWidth(value) self.width = value end
    function control:SetHeight(value)
        self.height = value
        if self.isRow then counters.rowLayouts = counters.rowLayouts + 1 end
    end
    function control:SetDimensions(w, h) self.width, self.height = w, h end
    function control:GetWidth()
        if self.bottomRight then
            return self.bottomRight.relative:GetWidth() + self.bottomRight.x - self.x
        end
        return self.width
    end
    function control:GetHeight() return self.height end
    function control:ClearAnchors() self.relative, self.bottomRight = nil, nil end
    function control:SetAnchor(point, relative, relativePoint, x, y)
        if point == BOTTOMRIGHT then
            self.bottomRight = { relative = relative, x = x or 0, y = y or 0 }
            return
        end
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
    function control:GetTextWidth()
        if counters.zeroTextWidths then return 0 end
        local text, icons = tostring(self.text):gsub("|t16:16:[^|]+|t", "")
        return #text * 7 + icons * 16
    end
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
        self.height = tonumber(font:match("|(%d+)|")) or self.height
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
InventoryCompanion_ItemTrackerFloatSettingsIcon = Control("settings", InventoryCompanion_ItemTrackerFloatContainer, 18, 18)
InventoryCompanion_ItemTrackerFloatContainerRows = Control("rows", InventoryCompanion_ItemTrackerFloatContainer, 340, 24)
local rows = InventoryCompanion_ItemTrackerFloatContainerRows
local scroll = Control("rowsScroll", rows, 320, 24)
local child = Control("rowsScrollChild", scroll, 320, 22)
InventoryCompanion_ItemTrackerFloatContainer:SetAnchor(TOPLEFT, InventoryCompanion_ItemTrackerFloat, TOPLEFT, 10, 4)
rows:SetAnchor(TOPLEFT, InventoryCompanion_ItemTrackerFloatTitle, BOTTOMLEFT, 0, 4)
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
function GetItemLinkName(link)
    return fixture and fixture.names[link] or link
end
InformationTooltip = { lines = {} }
function InformationTooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function InitializeTooltip(tooltip)
    tooltip.lines = {}
end
function ClearTooltip(tooltip)
    tooltip.cleared = true
end
function GetItemQualityColor()
    return {
        Colorize = function(_, text) return text end,
        UnpackRGBA = function() return 0.2, 0.4, 0.8, 1 end,
    }
end
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
    local link = string.rep("x", length or 8) .. string.format("%04d", id)
    fixture.items[id] = { link = link,
        icon = "icon", bagCount = 1, bankCount = 1 }
    fixture.names[link] = group
    fixture.groupItems[group][id] = fixture.items[id]
    for _, bagId in ipairs({ BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }) do
        local slots = fixture.slotRecords[bagId]
        local slotIndex = fixture.slotCount[bagId]
        slots[slotIndex] = { itemId = id, link = link, icon = "icon", count = 1, maxCount = 200 }
        fixture.slotCount[bagId] = slotIndex + 1
    end
    return id
end

local function Setup(sizes, budget, expanded, wrapped, length)
    counters = { scans = 0, creations = 0, measurements = 0, rowLayouts = 0, writes = 0 }
    fixture = { index = {}, items = {}, groupIds = {}, groupItems = {}, names = {},
        slotRecords = { [BAG_BACKPACK] = {}, [BAG_BANK] = {}, [BAG_SUBSCRIBER_BANK] = {} },
        slotCount = { [BAG_BACKPACK] = 0, [BAG_BANK] = 0, [BAG_SUBSCRIBER_BANK] = 0 } }
    this.Scanning.GetBagContents = function(bagIdList, selectFunc, checkpoint)
        if not fixture.suppressScanCount then counters.scans = counters.scans + 1 end
        local contents = {}
        for _, bagId in ipairs(bagIdList) do
            for slotIndex, record in pairs(fixture.slotRecords[bagId] or {}) do
                if checkpoint then checkpoint() end
                local item = fixture.items[record.itemId]
                local count = item and (bagId == BAG_BACKPACK and item.bagCount
                    or (bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK) and item.bankCount)
                if item and count and count > 0 then
                    local itemData = {
                        bagId = bagId, slotIndex = slotIndex, itemId = record.itemId,
                        link = record.link, icon = record.icon, count = count, maxCount = record.maxCount,
                    }
                    if not selectFunc or selectFunc(itemData) then contents[#contents + 1] = itemData end
                end
            end
            for _, itemData in ipairs(fixture.extraSources or {}) do
                if itemData.bagId == bagId then
                    if checkpoint then checkpoint() end
                    if not selectFunc or selectFunc(itemData) then contents[#contents + 1] = itemData end
                end
            end
        end
        return contents
    end
    this.Scanning.ReadSlot = function(bagId, slotIndex)
        local record = fixture.slotRecords[bagId] and fixture.slotRecords[bagId][slotIndex]
        local item = record and fixture.items[record.itemId]
        local count = item and (bagId == BAG_BACKPACK and item.bagCount
            or (bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK) and item.bankCount)
        if not item or not count or count <= 0 then return nil end
        return { bagId = bagId, slotIndex = slotIndex, itemId = record.itemId,
            link = record.link, icon = record.icon, count = count, maxCount = record.maxCount }
    end
    this.accountWide = { fcoIntegrationState = "off", fcoTestGroupsCreated = false,
        trackedRules = {}, trackedItems = {}, autoCategoryOrder = NewAutoCategoryOrder(),
        PanelSettings = { Tracker = { showTrackedItemsPanel = true,
        showEmptyTrackedItems = false, trackerMaxRows = budget, trackerGroupThreshold = 1,
        Layout_NoScene = { offsetX = 50, offsetY = 50 }, wrapTrackedItemNames = wrapped == true, trackerTitleSize = 20 },
        Currency = { showEmptyCurrencies = true, currencyGridColumns = 3,
            currencyPreferences = {}, capacityPreferences = {}, Layout_NoScene = { offsetX = 50, offsetY = 150 } } } }
    this.character = { fcoTestGroupsCreated = false,
        trackedRules = {}, trackedItems = {}, autoCategoryOrder = NewAutoCategoryOrder(),
        useCharacterItemList = false }
    _G[this.SettingsName] = { Default = { account = { ["$AccountWide"] = this.accountWide,
        character = this.character } } }
    function GetDisplayName() return "account" end
    GAMEPAD_DIALOGS, SI_DIALOG_CANCEL = { BASIC = 1 }, "Cancel"
    function ZO_Dialogs_RegisterCustomDialog() end
    this.defaultsAccount = trackerTestDefaults
    this.PanelLayout = {
        IsNormalContext = function() return true end,
        UpdateVisibility = function() end,
        OnMoveStop = function() end,
        OnMoveStart = function() end,
        UpdateContext = function() end,
        RegisterPanel = function(_, control)
            control:ClearAnchors()
            control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 50, 50)
        end,
    }
    this.preLoadedRulesets = {}
    for index, size in ipairs(sizes) do
        local name = "group" .. index
        fixture.groupIds[name], fixture.index[name], fixture.groupItems[name] = index, {}, {}
        this.preLoadedRulesets[name] = { displayName = name, patterns = { name },
            display = { show = true, bank = false, notify = false, isHidden = false,
                group = true, isExpanded = expanded == true } }
        for _ = 1, size do AddItem(name, length) end
    end
    this.preLoadedRulesets.miscellaneous = { displayName = "miscellaneous", patterns = {},
        display = { show = true, bank = false, notify = false, isHidden = false,
            group = true, isExpanded = false } }
    this.InvalidateRuleCache()
    this.GetMasterItemList = function(trackedItems, activeRules, bagIdList)
        counters.scans = counters.scans + 1
        local snapshot = { items = {}, groups = {}, ruleIndex = {} }
        for id, item in pairs(fixture.items) do snapshot.items[id] = item end
        for name, ids in pairs(fixture.index) do
            snapshot.ruleIndex[name] = {}
            for index, id in ipairs(ids) do snapshot.ruleIndex[name][index] = id end
        end
        for name in pairs(activeRules) do
            snapshot.groups[name] = { items = fixture.groupItems[name] or {} }
        end
        fixture.suppressScanCount = true
        local _, slotIndex = this.PreparedScanning.GetPreparedMasterItemList(trackedItems, activeRules, bagIdList)
        fixture.suppressScanCount = false
        return snapshot, slotIndex
    end
    GuiRoot.height = 1080
    return fixture
end

local function SavedExpanded(name) return this.GetActiveTrackedRules()[name].display.isExpanded end
local function VisibleRows()
    local result = {}
    for _, row in ipairs(pooled) do
        if not row.hidden then result[#result + 1] = row end
    end
    return result
end
local function SnapshotSignature(snapshot)
    local parts = {}
    local itemIds = {}
    for itemId in pairs(snapshot.items) do itemIds[#itemIds + 1] = itemId end
    table.sort(itemIds)
    for _, itemId in ipairs(itemIds) do
        local item = snapshot.items[itemId]
        local matches = {}
        for ruleName in pairs(item.matchedRules) do matches[#matches + 1] = ruleName end
        table.sort(matches)
        parts[#parts + 1] = table.concat({ tostring(itemId), tostring(item.bagCount),
            tostring(item.bankCount), table.concat(matches, ",") }, ":")
    end
    local ruleNames = {}
    for ruleName in pairs(snapshot.ruleIndex) do ruleNames[#ruleNames + 1] = ruleName end
    table.sort(ruleNames)
    for _, ruleName in ipairs(ruleNames) do
        local ids = {}
        for _, itemId in ipairs(snapshot.ruleIndex[ruleName]) do ids[#ids + 1] = itemId end
        table.sort(ids)
        parts[#parts + 1] = ruleName .. "=" .. table.concat(ids, ",")
    end
    return table.concat(parts, "|")
end
local function Expanded(name)
    for _, row in ipairs(VisibleRows()) do
        if GetControl(row, "Name").text == name then
            return GetControl(row, "ExpandIcon").texture == "EsoUI/Art/Buttons/minus_up.dds"
        end
    end
    error("Missing group header: " .. name)
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

local function WithTrackerRefreshClock(run)
    local oldClock, oldCallLater, oldRemoveCallLater = GetGameTimeMilliseconds, zo_callLater, zo_removeCallLater
    local oldSample, oldEvaluate = this.DiagnosticLog.Sample, this.EvaluateTrackerSlot
    local oldContents = this.Scanning.GetBagContents
    local clock, serial, pending = 0, 0, {}
    GetGameTimeMilliseconds = function() return clock end
    function zo_callLater(callback, delay)
        serial = serial + 1
        pending[serial] = { callback = callback, due = clock + delay }
        return serial
    end
    function zo_removeCallLater(handle) pending[handle] = nil end
    local function Advance(target)
        while true do
            local key
            for candidate, work in pairs(pending) do
                if work.due <= target and (not key or work.due < pending[key].due
                    or work.due == pending[key].due and candidate < key) then
                    key = candidate
                end
            end
            if not key then break end
            local work = pending[key]
            pending[key] = nil
            clock = work.due
            work.callback()
        end
        clock = target
    end
    local ok, err = pcall(run, Advance, pending)
    GetGameTimeMilliseconds, zo_callLater, zo_removeCallLater = oldClock, oldCallLater, oldRemoveCallLater
    this.DiagnosticLog.Sample, this.EvaluateTrackerSlot = oldSample, oldEvaluate
    this.Scanning.GetBagContents = oldContents
    assert(ok, err)
end

local function RenderedGroupCount(name)
    for _, row in ipairs(VisibleRows()) do
        if row.itemData.isGroup and row.itemData.ruleName == name then
            return row.itemData.count, GetControl(row, "Count").text
        end
    end
end

function this.GetTrackerPanelTests()
    local tests = {}
    local function Add(name, run) tests[#tests + 1] = { name = name, run = run } end

    Add("Tracker opens preferred categories at the exact row budget without saving layout decisions", function()
        Setup({ 2, 2 }, 6, true)
        this.RefreshItemTrackerPanel()
        Equal(#VisibleRows(), 6)
        assert(Expanded("group1") and Expanded("group2"))
        Equal(counters.scans, 1)
        Equal(counters.writes, 0)
        this.RefreshItemTrackerPanel()
        Equal(counters.writes, 0)
    end)

    Add("Tracker manual collapse survives content, settings, reintroduction, and UI reload", function()
        Setup({ 2, 2 }, 6, true)
        this.RefreshItemTrackerPanel()
        Click("group1")
        this.RefreshItemTrackerPanel()
        assert(not Expanded("group1") and Expanded("group2"))
        Equal(#VisibleRows(), 4)
        AddItem("group2")
        this.accountWide.PanelSettings.Tracker.trackerMaxRows = 10
        this.RefreshItemTrackerPanel("inventory")
        assert(not Expanded("group1") and Expanded("group2"))
        this.SetRuleFlag("group1", "bank", true)
        this.RefreshItemTrackerPanel()
        assert(not Expanded("group1") and Expanded("group2"))
        this.RefreshItemTrackerPanel("settings")
        assert(not Expanded("group1") and Expanded("group2"))
        local ids = fixture.index.group1
        fixture.index.group1 = {}
        this.RefreshItemTrackerPanel("inventory")
        fixture.index.group1 = ids
        this.RefreshItemTrackerPanel("inventory")
        assert(not Expanded("group1") and Expanded("group2"))
        local writes = counters.writes
        for _, row in ipairs(pooled) do row:SetHidden(true) end
        assert(loadstring(TrackerPanelSource))()
        this.RefreshItemTrackerPanel()
        assert(not Expanded("group1") and Expanded("group2"))
        assert(not SavedExpanded("group1") and SavedExpanded("group2"))
        Equal(counters.writes, writes)
        Click("group1")
        assert(Expanded("group1") and SavedExpanded("group1"))
    end)

    Add("Tracker saved closed categories stay closed on initial layout even when everything fits", function()
        Setup({ 2, 2 }, 6, false)
        this.RefreshItemTrackerPanel()
        assert(not Expanded("group1") and not Expanded("group2"),
            "Incremental overflow did not collapse both newly growing groups ("
                .. tostring(Expanded("group1")) .. "/" .. tostring(Expanded("group2")) .. ")")
        Equal(#VisibleRows(), 2)
        Equal(counters.writes, 0)
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
        assert(SavedExpanded("group1") and SavedExpanded("group2") and SavedExpanded("group3"))
        Equal(counters.writes, 3)
        this.RefreshItemTrackerPanel()
        assert(not Expanded("group1") and not Expanded("group2") and Expanded("group3"))
    end)

    Add("Tracker single-line fallback precedes collapse and preserves wrapping preference", function()
        Setup({ 2, 2 }, 6, true, true, 80)
        this.RefreshItemTrackerPanel()
        Equal(#VisibleRows(), 6)
        assert(Expanded("group1") and Expanded("group2") and this.accountWide.PanelSettings.Tracker.wrapTrackedItemNames)
        for _, row in ipairs(VisibleRows()) do Equal(row.height, 22) end
        Equal(counters.writes, 0)
        this.accountWide.PanelSettings.Tracker.trackerMaxRows = 20
        this.RefreshItemTrackerPanel("settings")
        local multiline = false
        for _, row in ipairs(VisibleRows()) do if row.height > 22 then multiline = true end end
        assert(multiline, "Wrapping should return when the preferred layout fits")
    end)

    Add("Tracker reserves count space before first-frame text measurement", function()
        Setup({ 1 }, 5, true, false, 80)
        this.SetRuleFlag("miscellaneous", "isExpanded", true)
        counters.zeroTextWidths = true
        this.RefreshItemTrackerPanel()

        local memberRow = VisibleRows()[2]
        local name, count = GetControl(memberRow, "Name"), GetControl(memberRow, "Count")
        assert(name:GetLeft() + name:GetWidth() < count:GetLeft(), "Item name overlaps its count")
        assert(count:GetWidth() >= 36, "Count label has no reserved width before text measurement")
        Equal(name.color[1], 0.2)
        Equal(name.color[2], 0.4)
        Equal(name.color[3], 0.8)

        this.preLoadedRulesets.group1.display.bank = true
        local item = next(fixture.items)
        fixture.items[item].bagCount = 999999
        fixture.items[item].bankCount = 999999
        this.RefreshItemTrackerPanel()

        memberRow = VisibleRows()[2]
        name, count = GetControl(memberRow, "Name"), GetControl(memberRow, "Count")
        assert(name:GetLeft() + name:GetWidth() < count:GetLeft(), "Long bank count overlaps its item name")
        local visibleText = count.text:gsub("|t16:16:[^|]+|t", "  ")
        assert(count:GetWidth() >= #visibleText * 8, "Long bank count lacks estimated width")
    end)

    Add("Tracker counts two and three wrapped lines as row equivalents", function()
        Setup({ 2 }, 7, true, true, 40)
        this.RefreshItemTrackerPanel()
        local units = 0
        for _, row in ipairs(VisibleRows()) do units = units + row.height / 22 end
        Equal(units, 5)
        for group, items in pairs(fixture.groupItems) do
            for _, item in pairs(items) do
                fixture.names[item.link] = nil
                item.link = string.rep("x", 80)
                fixture.names[item.link] = group
                for _, slots in pairs(fixture.slotRecords) do
                    for _, record in pairs(slots) do
                        if record.itemId == item.itemId or record.link ~= nil
                            and fixture.items[record.itemId] == item then
                            record.link = item.link
                        end
                    end
                end
            end
        end
        this.RefreshItemTrackerPanel("inventory")
        units = 0
        for _, row in ipairs(VisibleRows()) do units = units + row.height / 22 end
        Equal(units, 7)
    end)

    Add("Tracker keeps a fixed panel width and narrows rows only while scrolling", function()
        Setup({ 12 }, 5, false)
        this.RefreshItemTrackerPanel()

        local function CheckRightMargin(scrollable)
            local panel = InventoryCompanion_ItemTrackerFloat
            local contentWidth = 320 - (scrollable and ZO_SCROLL_BAR_WIDTH or 0)
            Equal(rows:GetWidth(), 320)
            Equal(InventoryCompanion_ItemTrackerFloatContainer:GetWidth(), 320)
            Equal(panel:GetWidth(), 340)
            Equal(scroll:GetWidth(), contentWidth)
            Equal(child:GetWidth(), contentWidth)
            for _, row in ipairs(VisibleRows()) do
                Equal(row:GetWidth(), contentWidth)
                local name, count = GetControl(row, "Name"), GetControl(row, "Count")
                local countRight = count:GetLeft() + count:GetWidth()
                Equal(panel:GetLeft() + panel:GetWidth() - countRight,
                    14 + (scrollable and ZO_SCROLL_BAR_WIDTH or 0))
                assert(name:GetLeft() + name:GetWidth() < count:GetLeft(),
                    "Item name overlaps its count")
                assert(countRight <= scroll:GetLeft() + scroll:GetWidth(),
                    "Count is clipped by the scroll viewport")
            end
        end

        CheckRightMargin(false)
        Click("group1")
        assert(child.height > rows.height)
        CheckRightMargin(true)
        Click("group1")
        CheckRightMargin(false)
        this.accountWide.PanelSettings.Tracker.wrapTrackedItemNames = true
        this.RefreshItemTrackerPanel()
        CheckRightMargin(false)
        Click("group1")
        CheckRightMargin(true)
        for _, row in ipairs(VisibleRows()) do Equal(row:GetHeight(), 22) end
        Click("group1")
        CheckRightMargin(false)
        this.accountWide.PanelSettings.Tracker.showTrackedItemsPanel = false
        this.RefreshItemTrackerPanel()
        this.accountWide.PanelSettings.Tracker.showTrackedItemsPanel = true
        this.RefreshItemTrackerPanel()
        CheckRightMargin(false)
    end)

    Add("Tracker passive overflow retains only the uniquely growing already-open category", function()
        Setup({ 2, 2 }, 6, true)
        this.RefreshItemTrackerPanel()
        AddItem("group1")
        this.RefreshItemTrackerPanel("inventory")
        assert(Expanded("group1") and not Expanded("group2"))
        Equal(#VisibleRows(), 5)
        assert(SavedExpanded("group1") and SavedExpanded("group2"))
        Equal(counters.writes, 0)
        this.RefreshItemTrackerPanel()
        assert(Expanded("group1") and not Expanded("group2"))
        fixture.items[fixture.index.group1[3]].bagCount = 0
        this.RefreshItemTrackerPanel("inventory")
        assert(Expanded("group1") and Expanded("group2"))
        Equal(counters.writes, 0)
    end)

    Add("Tracker multi-category growth burst collapses all on overflow", function()
        Setup({ 2, 2 }, 6, true)
        this.RefreshItemTrackerPanel()
        AddItem("group1")
        AddItem("group2")
        this.RefreshItemTrackerPanel("inventory")
        assert(not Expanded("group1") and not Expanded("group2"),
            "Incremental overflow did not collapse both newly growing groups ("
                .. tostring(Expanded("group1")) .. "/" .. tostring(Expanded("group2")) .. ")")
        Equal(#VisibleRows(), 2)
        assert(SavedExpanded("group1") and SavedExpanded("group2"))
        Equal(counters.writes, 0)
    end)

    Add("Tracker clicks toggle the rendered state of automatically collapsed categories", function()
        Setup({ 3, 3 }, 7, true)
        this.RefreshItemTrackerPanel()
        assert(not Expanded("group1") and not Expanded("group2"))
        assert(SavedExpanded("group1") and SavedExpanded("group2"))
        Click("group1")
        assert(Expanded("group1") and not Expanded("group2"))
        assert(SavedExpanded("group1"))
        Click("group1")
        assert(not Expanded("group1") and not SavedExpanded("group1"))
        this.accountWide.PanelSettings.Tracker.trackerMaxRows = 8
        this.RefreshItemTrackerPanel("settings")
        assert(not Expanded("group1") and Expanded("group2"))
        Equal(counters.writes, 2)
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

    Add("Tracker configuration reintroduction restores only preferred groups without displacing others", function()
        Setup({ 4, 4 }, 6, true)
        this.RefreshItemTrackerPanel()
        Click("group1")
        this.SetRuleFlag("group2", "bank", true)
        this.RefreshItemTrackerPanel()
        assert(Expanded("group1") and not Expanded("group2"))
        this.accountWide.PanelSettings.Tracker.trackerMaxRows = 10
        this.RefreshItemTrackerPanel("settings")
        assert(Expanded("group1") and Expanded("group2"))
    end)

    Add("Tracker edited manually closed categories cannot reopen into spare space", function()
        Setup({ 4, 4, 4 }, 8, true)
        this.RefreshItemTrackerPanel()
        Click("group2")
        Click("group2")
        this.SetRuleFlag("group2", "bank", true)
        this.RefreshItemTrackerPanel()
        assert(not Expanded("group1") and not Expanded("group2") and not Expanded("group3"))
        Equal(#VisibleRows(), 3)
        this.accountWide.PanelSettings.Tracker.trackerMaxRows = 11
        this.RefreshItemTrackerPanel("settings")
        assert(Expanded("group1") and not Expanded("group2") and Expanded("group3"))
        assert(not SavedExpanded("group2"))
        Equal(counters.writes, 3)
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

    Add("Tracker groups over 200 show overflow instead of members and retain full totals", function()
        for _, size in ipairs({ 199, 200, 201, 5000 }) do
            Setup({ size }, 20, false, true)
            this.preLoadedRulesets.group1.display.bank = true
            for _, item in pairs(fixture.items) do item.bankCount = 2 end
            local ids = fixture.index.group1
            for index = 1, math.floor(#ids / 2) do
                ids[index], ids[#ids - index + 1] = ids[#ids - index + 1], ids[index]
            end
            this.RefreshItemTrackerPanel()
            local scans, layouts, measurements = counters.scans, counters.rowLayouts, counters.measurements
            if not Expanded("group1") then Click("group1") end
            local visible = VisibleRows()
            Equal(#visible, size > 200 and 2 or size + 1)
            if size <= 200 then
                Equal(counters.scans, scans + 1)
                Equal(counters.rowLayouts - layouts, #visible)
                Equal(counters.measurements, measurements)
            end
            Equal(GetControl(visible[1], "Count").text,
                "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t " .. size
                .. "  |t16:16:EsoUI/Art/Tooltips/icon_bag.dds|t " .. size)
            if size > 200 then
                Equal(GetControl(visible[2], "Name").text,
                    "Your patterns matched " .. size .. " items - too many to display here.")
                Equal(GetControl(visible[2], "Count").text, "")
                Equal(GetControl(visible[1], "Icon").texture, "/esoui/art/buttons/info_up.dds")
                Equal(table.concat(GetControl(visible[1], "Icon").color, ","), "1,0.75,0,1")
                Equal(GetControl(visible[1], "Icon"):IsHidden(), false)
                Equal(GetControl(visible[2], "Icon"):IsHidden(), true)
                Equal(table.concat(GetControl(visible[2], "Name").color, ","), "1,1,1,1")
                Equal(scroll.offset, 0)
            else
                for index = 2, #visible do
                    Equal(GetControl(visible[index], "Name").text, fixture.items[10000 + index - 1].link)
                end
                assert(child.height > rows.height, "Members must remain scrollable")
                ZO_Scroll_OnMouseWheel(rows, -10000)
                Equal(scroll.offset, child.height - rows.height)
            end
            Click("group1")
            Equal(#VisibleRows(), 1)
            Equal(scroll.offset, 0)
        end
    end)

    Add("Tracker group cap applies after zero-stock filtering", function()
        Setup({ 500 }, 20, false)
        for index = 1, 300 do fixture.items[10000 + index].bagCount = 0 end
        this.RefreshItemTrackerPanel()
        Click("group1")
        local visible = VisibleRows()
        Equal(#visible, 201)
        Equal(GetControl(visible[1], "Count").text, "|t16:16:EsoUI/Art/Tooltips/icon_bag.dds|t 200")
        for index = 2, #visible do
            Equal(GetControl(visible[index], "Name").text, fixture.items[10300 + index - 1].link)
        end
    end)

    Add("Tracker large-group expansion and refresh stay within synthetic limits", function()
        Setup({ 5000 }, 20, false, true, 80)
        this.RefreshItemTrackerPanel()
        if Expanded("group1") then Click("group1") end
        local started = GetGameTimeMilliseconds()
        Click("group1")
        local elapsed = GetGameTimeMilliseconds() - started
        assert(elapsed <= 1000, "Large-group expansion timing limit exceeded: " .. elapsed)
        Equal(#VisibleRows(), 2)
        local creations = counters.creations
        started = GetGameTimeMilliseconds()
        for _ = 1, 5 do this.RefreshItemTrackerPanel("inventory") end
        local refreshElapsed = GetGameTimeMilliseconds() - started
        assert(refreshElapsed <= 1500, "Large-group refresh timing limit exceeded: " .. refreshElapsed)
        Equal(counters.creations, creations)
        Equal(#VisibleRows(), 2)
        return string.format("5000 matches, overflow message only: expand %d/1000 ms; 5 refreshes %d/1500 ms",
            elapsed, refreshElapsed)
    end)

    Add("Tracker overflow clears when eligible membership drops to 200", function()
        Setup({ 201 }, 20, false)
        this.RefreshItemTrackerPanel()
        if not Expanded("group1") then Click("group1") end
        Equal(#VisibleRows(), 2)
        Equal(table.concat(GetControl(VisibleRows()[1], "Name").color, ","), "1,0.25,0.25,1")
        Click("group1")
        Equal(#VisibleRows(), 1)
        Equal(table.concat(GetControl(VisibleRows()[1], "Name").color, ","), "1,0.25,0.25,1")
        Click("group1")
        fixture.items[10201].bagCount = 0
        this.RefreshItemTrackerPanel("inventory")
        if not Expanded("group1") then Click("group1") end
        Equal(#VisibleRows(), 201)
        Equal(table.concat(GetControl(VisibleRows()[1], "Name").color, ","), "0.2,0.4,0.8,1")
        Equal(GetControl(VisibleRows()[1], "Icon").texture, "icon")
        Equal(table.concat(GetControl(VisibleRows()[1], "Icon").color, ","), "1,1,1,1")
        Equal(GetControl(VisibleRows()[2], "Icon"):IsHidden(), false)
        Equal(GetControl(VisibleRows()[2], "Icon").texture, "icon")
        Equal(table.concat(GetControl(VisibleRows()[2], "Icon").color, ","), "1,1,1,1")
        Equal(table.concat(GetControl(VisibleRows()[2], "Name").color, ","), "0.2,0.4,0.8,1")
        fixture.items[10201].bagCount = 1
        this.RefreshItemTrackerPanel("inventory")
        if not Expanded("group1") then Click("group1") end
        Equal(#VisibleRows(), 2)
        Equal(GetControl(VisibleRows()[2], "Name").text,
            "Your patterns matched 201 items - too many to display here.")
        Equal(table.concat(GetControl(VisibleRows()[1], "Name").color, ","), "1,0.25,0.25,1")
    end)

    Add("Tracker excessive headers and flat lists remain accessible within the viewport", function()
        Setup({ 2, 2, 2, 2, 2, 2 }, 5, false)
        this.RefreshItemTrackerPanel()
        Equal(#VisibleRows(), 6)
        assert(child.height > rows.height)
        this.accountWide.PanelSettings.Tracker.trackerGroupThreshold = 30
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
        this.UpdateRuleFlag("group1", "group", false)
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

    Add("Tracker preserves singleton headers and labels differing ungrouped sources", function()
        Setup({ 1 }, 5, true)
        this.RefreshItemTrackerPanel()
        assert(Expanded("group1"), "A singleton group keeps its header")
        Equal(#VisibleRows(), 2)

        local singletonId = fixture.index.group1[1]
        fixture.items[singletonId].bagCount, fixture.items[singletonId].bankCount = 0, 0
        this.RefreshItemTrackerPanel("inventory")
        Equal(#VisibleRows(), 1)
        assert(GetControl(VisibleRows()[1], "Name").text:find("No tracked items", 1, true))
        this.accountWide.PanelSettings.Tracker.showEmptyTrackedItems = true
        this.RefreshItemTrackerPanel("settings")
        assert(Expanded("group1"), "A zero-stock singleton retains its header when empty items are shown")
        Equal(#VisibleRows(), 2)

        Setup({ 1, 0 }, 5, true)
        this.accountWide.PanelSettings.Tracker.trackerGroupThreshold = 8
        local itemId = fixture.index.group1[1]
        local first = fixture.groupItems.group1[itemId]
        first.link = "Sealed Writ"
        first.bagCount, first.bankCount = 2, 5
        fixture.items[itemId].link = first.link
        fixture.items[itemId].bagCount, fixture.items[itemId].bankCount = 2, 5
        fixture.index.group2[1] = itemId
        fixture.groupItems.group2[itemId] = {
            itemId = itemId, link = "Sealed Writ Variant", icon = "icon", bagCount = 1, bankCount = 6,
        }
        this.preLoadedRulesets.group1.patterns = { "Sealed Writ" }
        this.preLoadedRulesets.group2.patterns = { "Sealed Writ Variant" }
        fixture.extraSources = {
            { bagId = BAG_BACKPACK, slotIndex = 1001, itemId = itemId, link = "Sealed Writ Variant",
                icon = "icon", count = 1, maxCount = 200 },
            { bagId = BAG_BANK, slotIndex = 1001, itemId = itemId, link = "Sealed Writ Variant",
                icon = "icon", count = 6, maxCount = 200 },
        }
        this.UpdateRuleFlag("group1", "group", false)
        this.UpdateRuleFlag("group1", "showBank", true)
        this.UpdateRuleFlag("group2", "group", false)
        this.UpdateRuleFlag("group2", "showBank", true)
        this.UpdateRuleFlag("miscellaneous", "isExpanded", true)
        this.accountWide.trackedItems[itemId] = {
            link = "Sealed Writ", display = { showBackpack = true, showBank = true },
        }
        this.RefreshItemTrackerPanel()

        local visible = VisibleRows()
        Equal(#visible, 3)
        Equal(GetControl(visible[1], "Name").text, "miscellaneous")
        local miscCount = GetControl(visible[1], "Count").text
        assert(miscCount == "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t 3  |t16:16:EsoUI/Art/Tooltips/icon_bag.dds|t 2"
            or miscCount == "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t 5  |t16:16:EsoUI/Art/Tooltips/icon_bag.dds|t 1",
            "The Miscellaneous header uses one first-source count and never adds duplicate sources")
        Equal(GetControl(visible[2], "Name").text, "[group1]:Sealed Writ")
        Equal(GetControl(visible[2], "Count").text,
            "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t 3  |t16:16:EsoUI/Art/Tooltips/icon_bag.dds|t 2")
        Equal(GetControl(visible[3], "Name").text, "[g...]:Sealed Writ Variant")
        Equal(GetControl(visible[3], "Count").text,
            "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t 5  |t16:16:EsoUI/Art/Tooltips/icon_bag.dds|t 1")
        assert(visible[2].itemData.rowIdentity ~= visible[3].itemData.rowIdentity,
            "Duplicate source rows need distinct identities")

        this.UpdateRuleFlag("group2", "showBackpack", false)
        fixture.groupItems.group2[itemId].bankCount = 1
        this.RefreshItemTrackerPanel()
        local remainingRows = VisibleRows()
        local remainingNames = {}
        for _, row in ipairs(remainingRows) do remainingNames[#remainingNames + 1] = GetControl(row, "Name").text end
        assert(#remainingRows == 2, "Unexpected remaining rows: " .. table.concat(remainingNames, " | "))
        Equal(GetControl(remainingRows[1], "Name").text, "miscellaneous")
        Equal(GetControl(remainingRows[2], "Name").text, "[group1]:Sealed Writ")
        this.UpdateRuleFlag("group2", "showBackpack", true)
        fixture.groupItems.group2[itemId].bankCount = 6
        this.RefreshItemTrackerPanel()
        visible = VisibleRows()

        local label = GetControl(visible[2], "Name")
        label.handlers.OnMouseEnter(label)
        Equal(InformationTooltip.lines[1], "[group1]:Sealed Writ")
        label.handlers.OnMouseExit(label)
        assert(InformationTooltip.cleared)

        this.preLoadedRulesets.group1.displayName = string.rep("Long group name ", 8)
        this.InvalidateRuleCache()
        this.RefreshItemTrackerPanel()
        visible = VisibleRows()
        local truncated = GetControl(visible[2], "Name").text
        assert(truncated:find("%.%.%.%]:Sealed Writ$"),
            "Unwrapped labels truncate only the source prefix and retain the item name")

        local unicodeName = string.rep("é", 40)
        this.preLoadedRulesets.group1.displayName = unicodeName
        this.InvalidateRuleCache()
        this.RefreshItemTrackerPanel()
        visible = VisibleRows()
        local groupOneRow
        for _, row in ipairs(visible) do
            if row.itemData.sourceRuleName == "group1" then groupOneRow = row end
        end
        assert(groupOneRow, "The group1 source row remains visible")
        local unicodeLabel = GetControl(groupOneRow, "Name").text
        local retainedPrefix = unicodeLabel:match("^%[(.-)%.%.%.%]:Sealed Writ$")
        assert(unicodeLabel == "Sealed Writ" or
            (retainedPrefix and string.rep("é", #retainedPrefix / #"é") == retainedPrefix),
            "Source-name truncation preserves UTF-8 character boundaries: " .. unicodeLabel)

        first.bagCount, first.bankCount = 2, 5
        fixture.groupItems.group2[itemId].bagCount = 2
        fixture.groupItems.group2[itemId].bankCount = 5
        this.RefreshItemTrackerPanel("inventory")
        visible = VisibleRows()
        Equal(#visible, 1)
        local deduplicatedName = GetControl(visible[1], "Name").text
        assert(deduplicatedName == "Sealed Writ" or deduplicatedName == "Sealed Writ Variant",
            "Equal source counts deduplicate using the first encountered link")
    end)

    Add("Tracker compares hidden-location and individually tracked source counts before flattening", function()
        Setup({ 1, 0 }, 5, true)
        this.accountWide.PanelSettings.Tracker.trackerGroupThreshold = 8
        local itemId = fixture.index.group1[1]
        fixture.groupItems.group1[itemId].bagCount = 2
        fixture.groupItems.group1[itemId].bankCount = 8
        fixture.index.group2[1] = itemId
        fixture.groupItems.group2[itemId] = {
            itemId = itemId, link = fixture.items[itemId].link, icon = "icon", bagCount = 2, bankCount = 7,
        }
        local rows = this.GetTrackerDisplayList()
        Equal(#rows, 4)
        Equal(rows[1].link, "group1")
        Equal(rows[3].link, "group2")

        Setup({ 1 }, 5, true)
        this.accountWide.PanelSettings.Tracker.trackerGroupThreshold = 8
        itemId = fixture.index.group1[1]
        fixture.groupItems.group1[itemId] = {
            itemId = itemId, link = fixture.items[itemId].link, icon = "icon", bagCount = 2, bankCount = 2,
        }
        fixture.items[itemId].bagCount, fixture.items[itemId].bankCount = 3, 4
        this.accountWide.trackedItems[itemId] = {
            link = fixture.items[itemId].link, display = { showBackpack = true, showBank = false },
        }
        this.UpdateRuleFlag("miscellaneous", "isExpanded", true)
        rows = this.GetTrackerDisplayList()
        Equal(#rows, 4)
        Equal(rows[1].ruleName, "group1")
        Equal(rows[3].ruleName, "miscellaneous")
        Equal(rows[4].sourceRuleName, "trackedItem")

        Setup({ 1, 0 }, 5, true)
        this.accountWide.PanelSettings.Tracker.trackerGroupThreshold = 8
        itemId = fixture.index.group1[1]
        fixture.index.group2[1] = itemId
        fixture.groupItems.group2[itemId] = {
            itemId = itemId, link = fixture.items[itemId].link, icon = "icon", bagCount = 1, bankCount = 4,
        }
        fixture.groupItems.group1[itemId].bagCount = 1
        fixture.groupItems.group1[itemId].bankCount = 4
        this.UpdateRuleFlag("group1", "group", false)
        this.UpdateRuleFlag("group1", "showBank", false)
        this.UpdateRuleFlag("group2", "group", false)
        this.UpdateRuleFlag("group2", "showBank", true)
        rows = this.GetTrackerDisplayList()
        Equal(#rows, 1)
        assert(not rows[1].isGroup, "Different display flags alone do not prevent flattening")

        Setup({ 1, 0 }, 5, true)
        this.accountWide.PanelSettings.Tracker.trackerGroupThreshold = 8
        itemId = fixture.index.group1[1]
        fixture.index.group2[1] = itemId
        fixture.groupItems.group2[itemId] = {
            itemId = itemId, link = fixture.items[itemId].link, icon = "icon", bagCount = 1, bankCount = 2,
        }
        fixture.groupItems.group1[itemId].bagCount = 1
        fixture.groupItems.group1[itemId].bankCount = 3
        this.UpdateRuleFlag("group2", "isHidden", true)
        rows = this.GetTrackerDisplayList()
        Equal(#rows, 1)
        assert(not rows[1].isGroup, "Hidden rules are outside the tracker comparison set")
    end)

    Add("Tracker preserves ungrouped-rule precedence over the tracked-item fallback", function()
        Setup({ 1 }, 5, true)
        this.accountWide.PanelSettings.Tracker.trackerGroupThreshold = 8
        local itemId = fixture.index.group1[1]
        fixture.groupItems.group1[itemId] = {
            itemId = itemId,
            link = fixture.items[itemId].link,
            icon = fixture.items[itemId].icon,
            bagCount = 2,
            bankCount = 5,
        }
        fixture.items[itemId].bagCount, fixture.items[itemId].bankCount = 7, 9
        this.UpdateRuleFlag("group1", "group", false)
        this.accountWide.trackedItems[itemId] = {
            link = fixture.items[itemId].link,
            display = { showBackpack = true, showBank = true },
        }
        this.UpdateRuleFlag("miscellaneous", "isExpanded", true)

        local rows = this.GetTrackerDisplayList()
        Equal(#rows, 1)
        Equal(rows[1].count, 2)
        Equal(rows[1].bankCount, 5)
    end)

    Add("Tracker uses a strict threshold boundary for equal source counts", function()
        Setup({ 2 }, 5, true)
        this.accountWide.PanelSettings.Tracker.trackerGroupThreshold = 3
        local rows = this.GetTrackerDisplayList()
        Equal(#rows, 2)
        assert(not rows[1].isGroup, "One below the threshold is flat")
        this.accountWide.PanelSettings.Tracker.trackerGroupThreshold = 2
        rows = this.GetTrackerDisplayList()
        Equal(#rows, 3)
        assert(rows[1].isGroup, "At the threshold the tracker is grouped")
    end)

    Add("Tracker builds a scaled synthetic set of duplicate source rows", function()
        Setup({ 100, 0 }, 20, false)
        this.accountWide.PanelSettings.Tracker.trackerGroupThreshold = 8
        for _, itemId in ipairs(fixture.index.group1) do
            fixture.index.group2[#fixture.index.group2 + 1] = itemId
            fixture.groupItems.group2[itemId] = {
                itemId = itemId,
                link = fixture.items[itemId].link,
                icon = fixture.items[itemId].icon,
                bagCount = 2,
                bankCount = 2,
            }
        end
        this.UpdateRuleFlag("group1", "group", false)
        this.UpdateRuleFlag("group2", "group", false)

        local started = GetGameTimeMilliseconds()
        local rows
        for _ = 1, 5 do rows = this.GetTrackerDisplayList() end
        local elapsed = GetGameTimeMilliseconds() - started

        Equal(#rows, 201)
        Equal(rows[1].ruleName, "miscellaneous")
        Equal(rows[2].sourceRuleName, "group1")
        Equal(rows[102].sourceRuleName, "group2")
        Equal(rows[2].count, 1)
        Equal(rows[102].count, 2)
        return string.format("100 same-ID source pairs, 5 display-list builds: %d ms (no timing limit)", elapsed)
    end)

    Add("Tracker trials never create member controls for collapsed categories", function()
        Setup({ 200, 200 }, 5, false, true, 80)
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
        _G[this.SettingsName] = { Default = { account = {} } }
        assert(not this.CopyProfile("missing"))
        local _, failed = this.GetTrackerContext()
        Equal(failed, reset)
        _G[this.SettingsName] = { Default = { account = { source = { trackedRules = {}, trackedItems = {} } } } }
        assert(this.CopyProfile("source"))
        local importedContext, imported = this.GetTrackerContext()
        assert(importedContext ~= context, "Complete profile copies replace rules by value")
        Equal(imported, reset + 1)
    end)

    Add("Tracker context reinitialization discards temporary collapses but preserves manual choices", function()
        Setup({ 3, 3 }, 7, false)
        this.RefreshItemTrackerPanel()
        Click("group1")
        Click("group2")
        assert(not Expanded("group1") and Expanded("group2"))
        assert(this.accountWide.trackedRules.group2.display.isExpanded == true)
        this.SetUseCharacterItemList(false)
        this.RefreshItemTrackerPanel()
        assert(not Expanded("group1") and not Expanded("group2"))
        assert(SavedExpanded("group1") and SavedExpanded("group2"))
        this.accountWide.PanelSettings.Tracker.trackerMaxRows = 8
        this.RefreshItemTrackerPanel("settings")
        assert(Expanded("group1") and Expanded("group2"))
        Click("group1")
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
        local firstSlot = fixture.slotCount[BAG_BACKPACK] - 1
        for _ = 1, 50 do handler(2, BAG_BACKPACK, firstSlot, true, nil, nil, 1) end
        AddItem("group2")
        local secondSlot = fixture.slotCount[BAG_BACKPACK] - 1
        for _ = 1, 50 do handler(2, BAG_BACKPACK, secondSlot, true, nil, nil, 1) end
        Equal(counters.scans, scans)
        local callbacks = {}
        for handle, callback in pairs(pending) do
            callbacks[#callbacks + 1] = callback
            pending[handle] = nil
        end
        Equal(#callbacks, 1)
        for _, callback in ipairs(callbacks) do callback() end
        Equal(counters.scans, scans)
        assert(Expanded("group1") and Expanded("group2"), "Index updates must not redraw before the display callback")
        local handle, render = next(pending)
        assert(render, "The batched index update must schedule one visual refresh")
        pending[handle] = nil
        render()
        assert(next(pending) == nil)
        assert(not Expanded("group1") and not Expanded("group2"))
    end)

    for _, operation in ipairs({ "withdrawal", "split" }) do
        local isSplit = operation == "split"
        Add("Tracker FCO notifications preserve " .. operation .. " updates without another action", function()
            Setup({ 1 }, 20, true)
            local globalNames = { "EVENT_MANAGER", "zo_callLater", "zo_removeCallLater",
                "GetItemId", "GetItemLink", "GetSlotStackSize", "GetItemLinkIcon", "GetBagSize",
                "IsBankOpen", "FCOIS", "FCOIS_CON_ICON_DECONSTRUCTION", "FCOIS_CON_ICON_SELL",
                "FCOIS_CON_ICON_SELL_AT_GUILDSTORE" }
            local methodNames = { "HasVisibleProgressBars", "HasVisibleCapacityResources",
                "HasCapacityNotifications", "HasCurrencyResourcesToTrack", "HasCurrencyNotifications",
                "HasVisibleCurrencyProgressBars", "HasVisibleCappedCurrencyResources",
                "HasVisibleCappedProgressBars", "IsProgressBarVisible", "IsCapacityResourceVisible",
                "HandleTrackedItemInventoryUpdate", "GetMasterItemList", "UpdateEventRegistry" }
            local globals, methods = {}, {}
            for _, name in ipairs(globalNames) do globals[name] = _G[name] end
            for _, name in ipairs(methodNames) do methods[name] = this[name] end
            local oldReadSlot, oldGetBagContents = this.Scanning.ReadSlot, this.Scanning.GetBagContents
            local oldWarning, warnings = this.Utils.UserWarning, {}
            local ok, err = pcall(function()
                local itemId = fixture.index.group1[1]
                local backpack = fixture.slotRecords[BAG_BACKPACK][0]
                local bank = fixture.slotRecords[BAG_BANK][0]
                backpack.count, bank.count = isSplit and 6 or 0, isSplit and 0 or 6
                fixture.slotRecords[BAG_SUBSCRIBER_BANK][0].count = 0
                local function Slot(bagId, slotIndex)
                    return fixture.slotRecords[bagId][slotIndex]
                end
                function GetItemId(bagId, slotIndex)
                    local record = Slot(bagId, slotIndex)
                    return record and record.count > 0 and record.itemId or 0
                end
                function GetItemLink(bagId, slotIndex)
                    local record = Slot(bagId, slotIndex)
                    return record and record.count > 0 and record.link or ""
                end
                function GetSlotStackSize(bagId, slotIndex) return Slot(bagId, slotIndex).count, 200 end
                function GetItemLinkIcon() return "icon" end
                function GetBagSize(bagId) return fixture.slotCount[bagId] end
                function IsBankOpen() return true end
                this.Scanning.ReadSlot, this.Scanning.GetBagContents = productionReadSlot, productionGetBagContents
                this.GetMasterItemList = productionGetMasterItemList
                FCOIS_CON_ICON_DECONSTRUCTION, FCOIS_CON_ICON_SELL, FCOIS_CON_ICON_SELL_AT_GUILDSTORE = 1, 2, 3
                FCOIS = {
                    libsLoadedProperly = true, addonVars = { gAddonLoaded = true },
                    markedItems = { [1] = {}, [2] = {}, [3] = {} },
                    settingsVars = { settings = { isIconEnabled = { [1] = true, [2] = true, [3] = true },
                        markedItems = { [1] = {}, [2] = {}, [3] = {} } } },
                    GetSavedVarsMarkedItemsTableName = function() return "markedItems" end,
                    IsMarked = function(_, slotIndex, markerIds)
                        local marked, answers = false, {}
                        for _, markerId in ipairs(markerIds) do
                            answers[markerId] = slotIndex == 0 and markerId == 1
                            marked = marked or answers[markerId]
                        end
                        return marked, answers
                    end,
                }
                this.accountWide.fcoIntegrationState = "enabled"
                this.accountWide.fcoTestGroupsCreated = true
                this.FCOItemSaver.RegisterBuiltInGroups(true)
                this.accountWide.trackedRules.__ic_fco_deconstruct = {
                    display = { notifyChat = true, notifyHud = false },
                }
                this.InvalidateRuleCache()
                this.RefreshItemTrackerPanel()
                local function Count()
                    for _, row in ipairs(VisibleRows()) do
                        if row.itemData.isGroup and row.itemData.ruleName == "__ic_fco_deconstruct" then
                            return row.itemData.count, GetControl(row, "Count").text
                        end
                    end
                    return 0
                end
                Equal(Count(), isSplit and 6 or 0)
                local pending, registered, serial = {}, {}, 0
                function zo_callLater(callback)
                    serial = serial + 1
                    pending[serial] = callback
                    return serial
                end
                function zo_removeCallLater(handle) pending[handle] = nil end
                EVENT_MANAGER = {
                    RegisterForEvent = function(_, name, _, handler) registered[name] = handler end,
                    UnregisterForEvent = function() end,
                    AddFilterForEvent = function() end,
                }
                for _, name in ipairs(methodNames) do this[name] = function() return false end end
                this.HandleTrackedItemInventoryUpdate = productionHandleTrackedItemInventoryUpdate
                this.GetMasterItemList = productionGetMasterItemList
                this.Utils.UserWarning = function(chat, hud) warnings[#warnings + 1] = { chat, hud } end
                EVENT_OPEN_BANK, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, EVENT_CURRENCY_UPDATE = 1, 2, 3
                EVENT_CURRENCY_CAPS_CHANGED, EVENT_INVENTORY_BAG_CAPACITY_CHANGED = 4, 5
                EVENT_INVENTORY_BANK_CAPACITY_CHANGED, EVENT_PLAYER_ACTIVATED = 6, 7
                REGISTER_FILTER_BAG_ID = 1
                assert(loadstring(TrackerEventSource))()
                this.UpdateEventRegistry()
                local handler = assert(registered[this.Name .. "_Event_SlotUpdate_Backpack"])
                if isSplit then
                    backpack.count = 3
                    fixture.slotRecords[BAG_BACKPACK][1] = {
                        itemId = itemId, link = backpack.link, icon = "icon", count = 3, maxCount = 200,
                    }
                    fixture.slotCount[BAG_BACKPACK] = 2
                    handler(2, BAG_BACKPACK, 0, false, nil, nil, -3)
                    handler(2, BAG_BACKPACK, 1, true, nil, nil, 3)
                else
                    backpack.count, bank.count = 6, 0
                    registered[this.Name .. "_Event_SlotUpdate_Bank"](2, BAG_BANK, 0, false, nil, nil, -6)
                    handler(2, BAG_BACKPACK, 0, true, nil, nil, 6)
                    Equal(#warnings, 1)
                    assert(warnings[1][1] and not warnings[1][2], "Chat-only notification must remain chat-only")
                end
                Equal(serial, 1, "The operation's slot events must share one queued update")
                local callback = assert(pending[1])
                pending[1] = nil
                callback()
                Equal(serial, 2, "Slot application must schedule one separate visual refresh")
                callback = assert(pending[2])
                pending[2] = nil
                callback()
                assert(next(pending) == nil, "No later inventory action or full scan is needed")
                local count, text = Count()
                Equal(count, isSplit and 3 or 6)
                Equal(text, "|t16:16:EsoUI/Art/Tooltips/icon_bag.dds|t " .. count)
                if isSplit then Equal(#warnings, 0, "An unmarked split destination must not notify") end
            end)
            for _, name in ipairs(globalNames) do _G[name] = globals[name] end
            for _, name in ipairs(methodNames) do this[name] = methods[name] end
            this.Scanning.ReadSlot, this.Scanning.GetBagContents = oldReadSlot, oldGetBagContents
            this.Utils.UserWarning = oldWarning
            assert(ok, err)
        end)
    end

    Add("Tracker throttles redraws to 333 ms with immediate first and final updates", function()
        WithTrackerRefreshClock(function(Advance, pending)
            Setup({ 1 }, 20, true)
            this.RefreshItemTrackerPanel()
            local itemId = fixture.index.group1[1]
            local evaluated, renders = 0, {}
            local evaluate = this.EvaluateTrackerSlot
            this.EvaluateTrackerSlot = function(...)
                local record = evaluate(...)
                evaluated = record.itemData.count
                return record
            end
            this.DiagnosticLog.Sample = function(kind, sample)
                if kind == "trackerRefresh" and sample.reason == "incremental" then
                    local count, text = RenderedGroupCount("group1")
                    renders[#renders + 1] = {
                        at = GetGameTimeMilliseconds(), count = count, text = text, rows = sample.rows,
                    }
                end
            end
            for index = 0, 40 do
                Advance(index * 50)
                fixture.items[itemId].bagCount = index + 2
                this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
                Advance(index * 50)
                Equal(evaluated, index + 2, "Slot evaluation must not wait for the display deadline")
                Equal(#renders, math.floor(index * 50 / 333) + 1,
                    "A continuous burst must show progress without postponing the next redraw")
            end
            Advance(2330)
            Equal(#renders, 7)
            Advance(2331)
            Equal(#renders, 8)
            local counts, rows = { 2, 8, 15, 21, 28, 35, 41, 42 }, 0
            for index, render in ipairs(renders) do
                Equal(render.at, (index - 1) * 333)
                Equal(render.count, counts[index], "Each redraw must show the latest applied count")
                Equal(render.text, "|t16:16:EsoUI/Art/Tooltips/icon_bag.dds|t " .. render.count)
                rows = rows + render.rows
            end
            Equal(rows, 41, "Refresh samples must retain all coalesced slot work")
            assert(next(pending) == nil, "No redraw timer should remain after the final update")
            Advance(3100)
            fixture.items[itemId].bagCount = 100
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Advance(3100)
            Equal(#renders, 9, "An isolated move after idle must redraw immediately")
            Equal(renders[9].at, 3100)
            Equal(renders[9].count, 100)
            Advance(3200)
            fixture.items[itemId].bagCount = 101
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Advance(3200)
            local scheduledCallback
            for _, work in pairs(pending) do
                if work.due == 3433 then scheduledCallback = work.callback end
            end
            assert(scheduledCallback)
            Advance(3432)
            fixture.items[itemId].bagCount = 102
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Advance(3432)
            Equal(#renders, 9)
            Advance(3433)
            Equal(#renders, 10, "An update just before expiry must not postpone the redraw")
            Equal(renders[10].at, 3433)
            Equal(renders[10].count, 102)
            Equal(renders[10].rows, 2)
            Advance(5000)
            Equal(#renders, 10, "An idle tracker must not keep redrawing")
            assert(next(pending) == nil)
            Equal(counters.scans, 1, "Throttling display work must not introduce full rescans")
        end)
    end)

    Add("Tracker slot updates preserve a completed full scan's 333 ms redraw deadline", function()
        WithTrackerRefreshClock(function(Advance)
            Setup({ 1 }, 20, true)
            this.RefreshItemTrackerPanel()
            local itemId = fixture.index.group1[1]
            local incremental, full = 0, 0
            this.DiagnosticLog.Sample = function(kind, sample)
                if kind == "trackerRefresh" then
                    if sample.reason == "incremental" then incremental = incremental + 1
                    elseif sample.reason == "inventory" then full = full + 1 end
                end
            end
            fixture.items[itemId].bagCount = 2
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Advance(0)
            Equal(incremental, 1)
            Advance(100)
            this.NoteTrackerFullInventoryUpdate()
            Advance(100)
            Advance(200)
            fixture.items[itemId].bagCount = 5
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Advance(200)
            Advance(332)
            Equal(RenderedGroupCount("group1"), 2)
            Equal(full, 0)
            Equal(incremental, 1)
            Advance(333)
            Equal(RenderedGroupCount("group1"), 5)
            Advance(1000)
            Equal(full, 1)
            Equal(incremental, 1, "Full completion must not be followed by a duplicate incremental render")
        end)
    end)

    Add("Tracker full updates share the incremental redraw throttle without restarting it", function()
        WithTrackerRefreshClock(function(Advance)
            Setup({ 1 }, 20, true)
            this.RefreshItemTrackerPanel()
            fixture.items[fixture.index.group1[1]].bagCount = 5
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Advance(0)
            Equal(RenderedGroupCount("group1"), 5)
            Advance(100)
            fixture.items[fixture.index.group1[1]].bagCount = 6
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Advance(100)
            Advance(200)
            this.NoteTrackerFullInventoryUpdate()
            Advance(332)
            Equal(RenderedGroupCount("group1"), 5)
            Advance(333)
            Equal(RenderedGroupCount("group1"), 6)
        end)
    end)

    Add("Tracker updates during sliced jobs retain redraw cadence without an extra quiet wait", function()
        WithTrackerRefreshClock(function(Advance)
            Setup({ 1 }, 20, true)
            this.RefreshItemTrackerPanel()
            fixture.items[fixture.index.group1[1]].bagCount = 2
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Advance(0)
            local contents, yielded = this.Scanning.GetBagContents, false
            this.Scanning.GetBagContents = function(bagIds, selectFunc, checkpoint)
                if checkpoint and not yielded then
                    yielded = true
                    coroutine.yield()
                end
                return contents(bagIds, selectFunc, checkpoint)
            end
            Advance(100)
            this.NoteTrackerFullInventoryUpdate()
            Advance(100)
            assert(yielded)
            Advance(105)
            fixture.items[fixture.index.group1[1]].bagCount = 5
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Advance(332)
            Equal(RenderedGroupCount("group1"), 2)
            Advance(333)
            Equal(RenderedGroupCount("group1"), 5)
            local remainingYields = 40
            this.Scanning.GetBagContents = function(bagIds, selectFunc, checkpoint)
                while remainingYields > 0 do
                    remainingYields = remainingYields - 1
                    coroutine.yield()
                end
                return contents(bagIds, selectFunc, checkpoint)
            end
            Advance(400)
            this.NoteTrackerFullInventoryUpdate()
            Advance(405)
            fixture.items[fixture.index.group1[1]].bagCount = 6
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Advance(799)
            Equal(RenderedGroupCount("group1"), 5)
            Advance(800)
            Equal(RenderedGroupCount("group1"), 6,
                "A scan finishing after the interval must render without an extra quiet wait")
        end)
    end)

    Add("Tracker explicit refresh resets the interval for the next inventory update", function()
        WithTrackerRefreshClock(function(Advance, pending)
            Setup({ 1 }, 20, true)
            this.RefreshItemTrackerPanel()
            local itemId = fixture.index.group1[1]
            fixture.items[itemId].bagCount = 2
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Advance(0)
            Equal(RenderedGroupCount("group1"), 2)
            Advance(100)
            this.RefreshItemTrackerPanel("settings")
            fixture.items[itemId].bagCount = 3
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Advance(100)
            Equal(RenderedGroupCount("group1"), 3)
            assert(next(pending) == nil)
        end)
    end)

    Add("Tracker synchronous render callbacks retain a reentrant slot update", function()
        WithTrackerRefreshClock(function()
            Setup({ 1 }, 20, true)
            this.RefreshItemTrackerPanel()
            zo_callLater = function(callback) callback() end
            local itemId = fixture.index.group1[1]
            local counts = {}
            this.DiagnosticLog.Sample = function(kind, sample)
                if kind == "trackerRefresh" and sample.reason == "incremental" then
                    counts[#counts + 1] = RenderedGroupCount("group1")
                    if #counts == 1 then
                        fixture.items[itemId].bagCount = 3
                        this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
                    end
                end
            end
            fixture.items[itemId].bagCount = 2
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            Equal(#counts, 2)
            Equal(counts[1], 2)
            Equal(counts[2], 3)
            Equal(RenderedGroupCount("group1"), 3)
        end)
    end)

    for _, reason in ipairs({ "inventory", "settings", "hidden", "rules", "profile", "index" }) do
        local refreshReason = reason
        Add("Tracker cancels obsolete pending inventory renders after " .. reason .. " changes", function()
            WithTrackerRefreshClock(function(Advance, pending)
                Setup({ 1 }, 20, true)
                this.RefreshItemTrackerPanel()
                local renders = 0
                this.DiagnosticLog.Sample = function(kind, sample)
                    if kind == "trackerRefresh" and sample.reason == "incremental" then renders = renders + 1 end
                end
                fixture.items[fixture.index.group1[1]].bagCount = 2
                this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
                Advance(0)
                Equal(renders, 1)
                renders = 0
                Advance(50)
                fixture.items[fixture.index.group1[1]].bagCount = 5
                this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
                Advance(50)
                Equal(renders, 0, "The changed slot should be pending visual refresh")
                local staleCallback
                for _, work in pairs(pending) do
                    if work.due == 333 then staleCallback = work.callback end
                end
                assert(staleCallback)
                if refreshReason == "hidden" then
                    this.accountWide.PanelSettings.Tracker.showTrackedItemsPanel = false
                    this.RefreshItemTrackerPanel("settings")
                elseif refreshReason == "rules" then
                    this.accountWide.trackedRules.group1 = { display = { showBackpack = false } }
                    this.InvalidateRuleCache()
                elseif refreshReason == "profile" then
                    this.SetUseCharacterItemList(true)
                elseif refreshReason == "index" then
                    this.GetTrackerDisplayList()
                else
                    this.RefreshItemTrackerPanel(refreshReason)
                end
                staleCallback()
                Advance(1500)
                Equal(renders, 0, "Obsolete inventory renders must not overwrite the newer view")
                if refreshReason == "hidden" then
                    assert(InventoryCompanion_ItemTrackerFloat:IsHidden())
                elseif refreshReason == "rules" then
                    assert(RenderedGroupCount("group1") == nil)
                elseif refreshReason == "index" then
                    Equal(RenderedGroupCount("group1"), 2, "An old-index render must not replace the current view")
                else
                    Equal(RenderedGroupCount("group1"), 5)
                end
            end)
        end)
    end

    Add("Full inventory update listener is registered, coalesces sliced refreshes, and preserves tracker layout", function()
        Setup({ 2 }, 20, false)
        local previousManager = EVENT_MANAGER
        local previousCallLater, previousRemoveCallLater = zo_callLater, zo_removeCallLater
        this.RefreshItemTrackerPanel()
        Click("group1")
        EVENT_OPEN_BANK, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, EVENT_CURRENCY_UPDATE = 1, 2, 3
        EVENT_CURRENCY_CAPS_CHANGED, EVENT_INVENTORY_BAG_CAPACITY_CHANGED = 4, 5
        EVENT_INVENTORY_BANK_CAPACITY_CHANGED, EVENT_PLAYER_ACTIVATED = 6, 7
        EVENT_INVENTORY_FULL_UPDATE, REGISTER_FILTER_BAG_ID = 8, 1
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
            "HasCapacityNotifications", "HasCurrencyResourcesToTrack", "HasCurrencyNotifications",
            "HasVisibleCurrencyProgressBars", "HasVisibleCappedCurrencyResources",
            "HasVisibleCappedProgressBars", "IsProgressBarVisible", "IsCapacityResourceVisible" }) do
            this[name] = function() return false end
        end
        this.HandleTrackedItemInventoryUpdate = function() end
        assert(loadstring(TrackerEventSource))()
        this.UpdateEventRegistry()
        local fullUpdate = assert(registered[this.Name .. "_Event_FullInventoryUpdate"],
            "Full-inventory callback must register at module scope")
        local rowsBefore = counters.rowLayouts
        local scansBefore = counters.scans
        fullUpdate(8)
        fullUpdate(8)
        local function RunOneCallback()
            local key
            for candidate in pairs(pending) do
                if key == nil or candidate < key then key = candidate end
            end
            assert(key ~= nil, "Expected queued tracker work")
            local callback = pending[key]
            pending[key] = nil
            callback()
        end
        RunOneCallback()
        Equal(counters.rowLayouts, rowsBefore, "Sliced scan must defer rendering until completion")
        RunOneCallback()
        assert(counters.rowLayouts > rowsBefore)
        while next(pending) do RunOneCallback() end
        Equal(counters.scans, scansBefore + 6, "Two full updates during one job must coalesce into one top-up")
        assert(Expanded("group1") and #VisibleRows() > 1,
            "The coalesced refresh must retain the user's expanded view")
        local hiddenScans = counters.scans
        this.GetPanelSettings("Tracker").showTrackedItemsPanel = false
        fullUpdate(8)
        Equal(counters.scans, hiddenScans, "Hidden tracker must ignore full-inventory updates")
        EVENT_MANAGER = previousManager
        zo_callLater, zo_removeCallLater = previousCallLater, previousRemoveCallLater
    end)

    Add("Event listeners retain shared consumers, apply distinct bag filters, and cancel stale delayed refreshes", function()
        Setup({}, 20, false)
        local previousManager = EVENT_MANAGER
        local previousCallLater, previousRemoveCallLater = zo_callLater, zo_removeCallLater
        this.accountWide.autoMergeChests = false
        this.GetPanelSettings("Tracker").showTrackedItemsPanel = false
        EVENT_OPEN_BANK, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, EVENT_CURRENCY_UPDATE = 201, 202, 203
        EVENT_CURRENCY_CAPS_CHANGED, EVENT_INVENTORY_BAG_CAPACITY_CHANGED = 204, 205
        EVENT_INVENTORY_BANK_CAPACITY_CHANGED, EVENT_PLAYER_ACTIVATED = 206, 207
        EVENT_INVENTORY_FULL_UPDATE, REGISTER_FILTER_BAG_ID = 208, 1
        local demand = {}
        local registrations, unregistrations, filters = {}, {}, {}
        EVENT_MANAGER = {
            RegisterForEvent = function(_, name, eventCode, handler)
                assert(registrations[name] == nil, "Listener was registered twice: " .. name)
                registrations[name] = { eventCode = eventCode, handler = handler }
                return true
            end,
            UnregisterForEvent = function(_, name, eventCode)
                assert(registrations[name] and registrations[name].eventCode == eventCode)
                registrations[name] = nil
                unregistrations[name] = (unregistrations[name] or 0) + 1
            end,
            AddFilterForEvent = function(_, name, eventCode, filterType, bagId)
                assert(registrations[name] and registrations[name].eventCode == eventCode)
                assert(filterType == REGISTER_FILTER_BAG_ID)
                filters[name] = bagId
                return true
            end,
        }
        local pending, nextHandle, removedHandles = {}, 0, {}
        function zo_callLater(callback, delay)
            nextHandle = nextHandle + 1
            Equal(delay, 500)
            pending[nextHandle] = callback
            return nextHandle
        end
        function zo_removeCallLater(handle)
            pending[handle] = nil
            removedHandles[handle] = true
        end
        local function Demand(name) return demand[name] == true end
        this.HasVisibleProgressBars = function() return Demand("progress") end
        this.HasVisibleCapacityResources = function() return Demand("capacity") end
        this.HasCapacityNotifications = function() return Demand("capacityNotify") end
        this.HasTrackedItemNotifications = function() return Demand("itemNotify") end
        this.HasCurrencyResourcesToTrack = function() return Demand("currencyPanel") end
        this.HasVisibleCurrencyProgressBars = function() return Demand("currencyBars") end
        this.HasCurrencyNotifications = function() return Demand("currencyNotify") end
        this.HasVisibleCappedCurrencyResources = function() return Demand("cappedCurrency") end
        this.HasVisibleCappedProgressBars = function() return Demand("cappedBars") end
        this.IsProgressBarVisible = function(key) return key == "capacity:bag" and Demand("progressBag") end
        this.IsCapacityResourceVisible = function(key) return key == "bag" and Demand("capacityBag") end
        this.HasVisibleCurrencyResources = function() return Demand("currencyPanel") end
        this.HasCurrencyNotifications = function() return Demand("currencyNotify") end
        this.IsCurrencyResourceVisible = function() return Demand("currencyPanel") end
        this.IsCurrencyProgressBarVisible = function() return Demand("currencyBars") end
        this.HasVisibleCappedProgressBars = function() return Demand("cappedBars") end
        this.HasVisibleCappedCurrencyResources = function() return Demand("cappedCurrency") end
        this.HasVisibleCurrencyResources = function() return Demand("currencyPanel") end
        this.NotifyCurrencyChange = function() end
        this.RefreshCurrencyPanel = function() demand.panelRefreshes = (demand.panelRefreshes or 0) + 1 end
        this.RefreshResourceProgressBars = function() demand.progressRefreshes = (demand.progressRefreshes or 0) + 1 end
        this.RefreshProgressBarResourceDiscovery = function() end
        this.HandleTrackedItemInventoryUpdate = function() end
        this.NoteTrackerFullInventoryUpdate = function() end
        assert(loadstring(TrackerEventSource))()
        this.UpdateEventRegistry()
        local playerEvent = this.Name .. "_Event_PlayerActivated"
        assert(registrations[playerEvent], "Startup currency-suppression listener is the one justified always-on event")
        local function CountListeners(eventCode)
            local count = 0
            for _, listener in pairs(registrations) do
                if eventCode == nil or listener.eventCode == eventCode then count = count + 1 end
            end
            return count
        end
        Equal(CountListeners(), 1)

        demand.itemNotify = true
        this.UpdateEventRegistry()
        Equal(CountListeners(EVENT_INVENTORY_SINGLE_SLOT_UPDATE), 4)
        assert(not registrations[this.Name .. "_Event_FullInventoryUpdate"],
            "Item notifications alone must not retain a tracker-only full-inventory listener")
        this.GetPanelSettings("Tracker").showTrackedItemsPanel = true
        this.UpdateEventRegistry()
        assert(registrations[this.Name .. "_Event_FullInventoryUpdate"])
        local filterValues, slotNames = {}, {}
        for name, bagId in pairs(filters) do
            slotNames[#slotNames + 1] = name
            filterValues[bagId] = (filterValues[bagId] or 0) + 1
        end
        table.sort(slotNames)
        assert(#slotNames == 4 and filterValues[BAG_BACKPACK] == 1 and filterValues[BAG_VIRTUAL] == 1
            and filterValues[BAG_BANK] == 1 and filterValues[BAG_SUBSCRIBER_BANK] == 1,
            "Four distinct event namespaces must each receive exactly one successful bag filter")
        demand.capacity = true
        this.UpdateEventRegistry()
        this.GetPanelSettings("Tracker").showTrackedItemsPanel = false
        this.UpdateEventRegistry()
        Equal(CountListeners(EVENT_INVENTORY_SINGLE_SLOT_UPDATE), 4)
        assert(not registrations[this.Name .. "_Event_FullInventoryUpdate"],
            "Hiding the tracker must release its full-update listener while retaining shared slot listeners")
        demand.itemNotify, demand.capacity = false, false
        this.UpdateEventRegistry()
        Equal(CountListeners(EVENT_INVENTORY_SINGLE_SLOT_UPDATE), 0)
        assert(not registrations[this.Name .. "_Event_FullInventoryUpdate"])

        demand.currencyNotify = true
        this.UpdateEventRegistry()
        assert(registrations[this.Name .. "_Event_CurrencyUpdate"])
        demand.currencyNotify, demand.currencyPanel = false, true
        this.UpdateEventRegistry()
        assert(registrations[this.Name .. "_Event_CurrencyUpdate"])
        demand.currencyPanel, demand.currencyBars = false, true
        this.UpdateEventRegistry()
        assert(registrations[this.Name .. "_Event_CurrencyUpdate"])
        demand.currencyBars, demand.currencyNotify = false, true
        this.UpdateEventRegistry()
        assert(registrations[this.Name .. "_Event_CurrencyUpdate"],
            "Notification-only consumer keeps the shared currency event registered")
        demand.currencyNotify = false
        this.UpdateEventRegistry()
        assert(not registrations[this.Name .. "_Event_CurrencyUpdate"])

        demand.cappedCurrency = true
        this.UpdateEventRegistry()
        assert(registrations[this.Name .. "_Event_CurrencyCapsChanged"])
        demand.cappedCurrency, demand.cappedBars = false, true
        this.UpdateEventRegistry()
        assert(registrations[this.Name .. "_Event_CurrencyCapsChanged"])
        demand.cappedBars = false
        this.UpdateEventRegistry()
        assert(not registrations[this.Name .. "_Event_CurrencyCapsChanged"])

        demand.currencyPanel, demand.currencyBars = true, true
        this.UpdateEventRegistry()
        local currency = registrations[this.Name .. "_Event_CurrencyUpdate"].handler
        currency(203, 1, 1, 5, 4, 0)
        currency(203, 1, 1, 6, 5, 0)
        Equal(nextHandle, 1, "Repeated updates must share one timer")
        demand.currencyPanel = false
        this.UpdateEventRegistry()
        assert(next(pending) ~= nil, "A still-active bar consumer must retain shared queued work")
        local handle, callback
        for id, run in pairs(pending) do handle, callback = id, run end
        pending[handle] = nil
        callback()
        Equal(demand.panelRefreshes or 0, 0)
        Equal(demand.progressRefreshes or 0, 1)
        demand.currencyBars = false
        demand.currencyPanel = true
        this.UpdateEventRegistry()
        currency(203, 1, 1, 7, 6, 0)
        local staleHandle
        for id in pairs(pending) do staleHandle = id end
        assert(staleHandle ~= nil)
        demand.currencyPanel = false
        this.UpdateEventRegistry()
        assert(pending[staleHandle] == nil and removedHandles[staleHandle],
            string.format("Turning off the final currency consumer must cancel callback %s (pending=%s removed=%s next=%d)",
                tostring(staleHandle), tostring(pending[staleHandle] ~= nil),
                tostring(removedHandles[staleHandle] == true), nextHandle))
        Equal(CountListeners(), 1)
        local marker = assert(TrackerInGameTestSource:find(
            'name = "Event listener transitions and refresh debounce"', 1, true))
        local first = assert(TrackerInGameTestSource:find("run = function()", marker, true))
            + #"run = function()"
        local last = assert(TrackerInGameTestSource:find("                end,\n            },\n        }", first, true))
        local diagnostic = assert(loadstring("local this = InventoryCompanion\n"
            .. "return function(syntheticOriginal, Check, CheckEqual, CountEntries)\n"
            .. TrackerInGameTestSource:sub(first, last - 1) .. "\nend"))()
        diagnostic({ accountWide = this.accountWide, character = this.character }, assert, Equal, function(entries)
            local count = 0
            for _ in pairs(entries) do count = count + 1 end
            return count
        end)
        Equal(CountListeners(), 1, "The in-game diagnostic must restore the original event ownership")
        EVENT_MANAGER = previousManager
        zo_callLater, zo_removeCallLater = previousCallLater, previousRemoveCallLater
    end)

    Add("Sliced prepared scan yields repeatedly and renders the synchronous scan result", function()
        Setup({ 24 }, 50, true)
        this.RefreshItemTrackerPanel()
        local rules, trackedItems = this.GetActiveTrackedRules(), this.GetActiveTrackedItems()
        local expectedSnapshot = this.PreparedScanning.GetPreparedMasterItemList(
            trackedItems, rules, this.GetTrackerBagIdList())
        local expectedRows = this.BuildTrackerDisplayListForPerformanceTest(expectedSnapshot, rules,
            trackedItems, this.GetPanelSettings("Tracker").showEmptyTrackedItems)
        local oldClock, oldCallLater, oldRemoveCallLater = GetGameTimeMilliseconds, zo_callLater, zo_removeCallLater
        local oldSample = this.DiagnosticLog.Sample
        local samples, pending, delays, serial, clock = {}, {}, {}, 0, 0
        GetGameTimeMilliseconds = function() clock = clock + 10; return clock end
        function zo_callLater(callback, delay)
            serial = serial + 1
            pending[serial], delays[serial] = callback, delay
            return serial
        end
        function zo_removeCallLater(handle) pending[handle] = nil end
        this.DiagnosticLog.Sample = function(name, sample)
            assert(name ~= "trackerRefresh" or sample.reason ~= "incremental",
                "A slot event during a sliced job must leave rendering to its completion")
            samples[name] = sample
        end
        local rowsBefore = counters.rowLayouts
        this.RefreshItemTrackerPanel("inventory")
        local function RunOne()
            local key
            for candidate in pairs(pending) do
                if key == nil or candidate < key then key = candidate end
            end
            assert(key ~= nil)
            local callback = pending[key]
            pending[key] = nil
            callback()
            return key
        end
        local firstHandle = RunOne()
        assert(delays[firstHandle] == 0 and next(pending) ~= nil,
            "The first work slice must yield and enqueue a delayed continuation")
        assert(counters.rowLayouts == rowsBefore, "A partial scan must not render")
        this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
        local applyHandle = serial
        assert(delays[applyHandle] == 0)
        local apply = assert(pending[applyHandle])
        pending[applyHandle] = nil
        apply()
        Equal(counters.rowLayouts, rowsBefore, "The old index must not render while its replacement is being built")
        while next(pending) do RunOne() end
        local sample = assert(samples.trackerScan)
        assert(sample.sliceCount > 1 and sample.requestedDelayMs == 10 and sample.maxSliceMs <= 30,
            string.format("Production scan diagnostics must report multiple bounded slices (count=%s max=%s delay=%s)",
                tostring(sample.sliceCount), tostring(sample.maxSliceMs), tostring(sample.requestedDelayMs)))
        local rows = VisibleRows()
        Equal(#rows, #expectedRows, "Sliced scan display row count")
        for index, expected in ipairs(expectedRows) do
            local actual = rows[index].itemData
            if expected.isGroup then
                assert(actual.isGroup and actual.ruleName == expected.ruleName)
            else
                assert(actual.itemId == expected.itemId,
                    "Sliced and synchronous display order differs at row " .. index)
            end
        end
        this.DiagnosticLog.Sample = oldSample
        GetGameTimeMilliseconds, zo_callLater, zo_removeCallLater =
            oldClock, oldCallLater, oldRemoveCallLater
    end)

    Add("Sparse virtual bag reads yield through production scanner and preserve occupied slots", function()
        local scanned = Setup({ 3 }, 20, true)
        local originalReadSlot = this.Scanning.ReadSlot
        this.Scanning.GetBagContents = productionGetBagContents
        function GetBagSize(bagId)
            assert(bagId == BAG_BACKPACK)
            return 3
        end
        local virtualSlots = {
            [100000] = scanned.index.group1[1],
            [900000] = scanned.index.group1[2],
        }
        local virtualNext = { [100000] = 900000 }
        function GetNextVirtualBagSlotId(slotIndex)
            if slotIndex == nil then return 100000 end
            return virtualNext[slotIndex]
        end
        this.Scanning.ReadSlot = function(bagId, slotIndex)
            if bagId ~= BAG_VIRTUAL then return originalReadSlot(bagId, slotIndex) end
            local itemId = virtualSlots[slotIndex]
            if itemId == nil then return nil end
            local item = fixture.items[itemId]
            return { bagId = bagId, slotIndex = slotIndex, itemId = itemId, link = item.link,
                icon = item.icon, count = item.bagCount, maxCount = 200 }
        end
        local rules, trackedItems = this.GetActiveTrackedRules(), this.GetActiveTrackedItems()
        local bags = { BAG_BACKPACK, BAG_VIRTUAL }
        local expected = this.PreparedScanning.GetPreparedMasterItemList(trackedItems, rules, bags)
        local checkpoints, yields = 0, 0
        local worker = coroutine.create(function()
            return this.PreparedScanning.GetPreparedMasterItemList(trackedItems, rules, bags, {
                checkpoint = function()
                    checkpoints = checkpoints + 1
                    if checkpoints % 5 == 0 then coroutine.yield() end
                end,
            })
        end)
        local actual, slotIndex
        repeat
            local ok, snapshot, index = coroutine.resume(worker)
            assert(ok, tostring(snapshot))
            if coroutine.status(worker) == "dead" then actual, slotIndex = snapshot, index
            else yields = yields + 1 end
        until coroutine.status(worker) == "dead"
        assert(yields > 2 and checkpoints > 15, "Prepared scan must yield across scanner and matching stages")
        assert(SnapshotSignature(actual) == SnapshotSignature(expected),
            "Sparse virtual-slot slicing must preserve the synchronous prepared result")
        local virtual = slotIndex.bags[BAG_VIRTUAL]
        Equal(#virtual.order, 2)
        Equal(virtual.order[1], 100000)
        Equal(virtual.order[2], 900000)
        assert(virtual.slots[100000] and virtual.slots[900000])
    end)

    Add("Incremental slot index matches fresh scans after dirty replay and completion flush", function()
        Setup({ 2 }, 20, true)
        this.RefreshItemTrackerPanel()
        local oldEvent, mismatches = this.DiagnosticLog.Event, {}
        this.DiagnosticLog.Event = function(name, message, details)
            if name == "trackerMismatch" then mismatches[#mismatches + 1] = { message, details } end
        end
        local itemId = fixture.index.group1[1]
        fixture.items[itemId].bagCount = 3
        this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
        assert(this.GetTrackerDisplayList(), "Incremental slot update must keep the display usable")
        local oldCallLater, oldRemoveCallLater = zo_callLater, zo_removeCallLater
        local pending, serial = {}, 0
        function zo_callLater(callback)
            serial = serial + 1
            pending[serial] = callback
            return serial
        end
        function zo_removeCallLater(handle) pending[handle] = nil end
        this.RefreshItemTrackerPanel("inventory")
        fixture.items[itemId].bagCount = 4
        fixture.items[itemId].bankCount = 3
        this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
        this.QueueTrackerSlotUpdate(BAG_BANK, 0)
        this.QueueTrackerSlotUpdate(BAG_SUBSCRIBER_BANK, 0)
        while next(pending) do
            local key
            for candidate in pairs(pending) do
                if key == nil or candidate < key then key = candidate end
            end
            local callback = pending[key]
            pending[key] = nil
            callback()
        end
        assert(#mismatches == 0,
            "Dirty replay and completion-time pending-slot flush must match an independent fresh scan: "
                .. (mismatches[1] and (tostring(mismatches[1][1]) .. " "
                    .. table.concat(mismatches[1][2], "; ")) or "unknown"))
        this.DiagnosticLog.Event = oldEvent
        zo_callLater, zo_removeCallLater = oldCallLater, oldRemoveCallLater
    end)

    Add("Tracker mismatch log identifies the differing slots with live state and replay membership", function()
        Setup({ 2 }, 20, true)
        this.RefreshItemTrackerPanel()
        local oldEvent, mismatches = this.DiagnosticLog.Event, {}
        local oldUserError, alerts, recorded = this.Utils.UserError, {}, true
        this.Utils.UserError = function(chat, hud) alerts[#alerts + 1] = { chat, hud } end
        this.DiagnosticLog.Event = function(name, message, details)
            if name == "trackerMismatch" then mismatches[#mismatches + 1] = details end
            return recorded
        end
        local itemId = fixture.index.group1[1]
        fixture.items[itemId].bagCount = 3
        this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
        assert(this.GetTrackerDisplayList(), "Incremental slot update must keep the display usable")
        local oldCallLater, oldRemoveCallLater = zo_callLater, zo_removeCallLater
        local pending, serial = {}, 0
        function zo_callLater(callback)
            serial = serial + 1
            pending[serial] = callback
            return serial
        end
        function zo_removeCallLater(handle) pending[handle] = nil end
        local function DrainAfterSilentChange()
            this.RefreshItemTrackerPanel("inventory")
            fixture.items[itemId].bagCount = fixture.items[itemId].bagCount + 1
            fixture.items[itemId].bankCount = (fixture.items[itemId].bankCount or 0) + 1
            this.QueueTrackerSlotUpdate(BAG_BACKPACK, 0)
            while next(pending) do
                local key
                for candidate in pairs(pending) do
                    if key == nil or candidate < key then key = candidate end
                end
                local callback = pending[key]
                pending[key] = nil
                callback()
            end
        end
        DrainAfterSilentChange()
        Equal(#mismatches, 1)
        Equal(#alerts, 1)
        assert(alerts[1][1]:find("TODO F16", 1, true) and alerts[1][2]:find("TODO F16", 1, true),
            "The alert must point at the TODO reference")
        recorded = false
        DrainAfterSilentChange()
        Equal(#alerts, 1)
        this.DiagnosticLog.Event = oldEvent
        this.Utils.UserError = oldUserError
        zo_callLater, zo_removeCallLater = oldCallLater, oldRemoveCallLater
        local text = table.concat(mismatches[1], "\n")
        assert(text:find("scan: replayed slots=1", 1, true), text)
        assert(text:find("bag 2 slot 0 previous=", 1, true) and text:find("replayed=false", 1, true), text)
        assert(text:find("bag 1 slot 0", 1, true) == nil, "A replayed slot that matches must not be listed: " .. text)
    end)

    Add("Cancelling a yielded tracker scan removes its delayed continuation and suppresses stale rendering", function()
        Setup({ 24 }, 50, true)
        this.RefreshItemTrackerPanel()
        local oldClock, oldCallLater, oldRemoveCallLater = GetGameTimeMilliseconds, zo_callLater, zo_removeCallLater
        local oldSample = this.DiagnosticLog.Sample
        local samples, pending, removed, serial, clock = {}, {}, {}, 0, 0
        GetGameTimeMilliseconds = function() clock = clock + 10; return clock end
        function zo_callLater(callback, delay)
            serial = serial + 1
            pending[serial] = { callback = callback, delay = delay }
            return serial
        end
        function zo_removeCallLater(handle)
            pending[handle] = nil
            removed[handle] = true
        end
        this.DiagnosticLog.Sample = function(name, sample) samples[name] = sample end
        local rowsBefore = counters.rowLayouts
        this.RefreshItemTrackerPanel("inventory")
        local function RunOne()
            local key
            for candidate in pairs(pending) do
                if key == nil or candidate < key then key = candidate end
            end
            assert(key ~= nil)
            local entry = pending[key]
            pending[key] = nil
            entry.callback()
            return key
        end
        RunOne()
        local continuation
        for key, entry in pairs(pending) do
            if entry.delay == 10 then continuation = key end
        end
        assert(continuation ~= nil, "Yielded work must own a cancellable delayed continuation")
        this.CancelSlicedTrackerRefresh()
        assert(pending[continuation] == nil and removed[continuation],
            "Cancellation must remove the pending scheduled callback")
        assert(counters.rowLayouts == rowsBefore and samples.trackerScan == nil,
            "Cancelled work must not render or report a completed scan")
        this.DiagnosticLog.Sample = oldSample
        GetGameTimeMilliseconds, zo_callLater, zo_removeCallLater =
            oldClock, oldCallLater, oldRemoveCallLater
    end)

    Add("FCO marker poll timer follows lifecycle, profile, readiness, and tracker visibility transitions", function()
        Setup({ 1 }, 20, true)
        local adapter = this.FCOItemSaver
        local previousManager, previousSceneManager, previousFCOIS = EVENT_MANAGER, SCENE_MANAGER, FCOIS
        local previousConstants = {
            FCOIS_CON_ICON_DECONSTRUCTION, FCOIS_CON_ICON_SELL, FCOIS_CON_ICON_SELL_AT_GUILDSTORE,
        }
        local previousProfileChanged = this.AutoCategoryIntegration.OnProfileChanged
        local previousRefreshes = {
            this.RefreshTrackedItemsEditor, this.RefreshGroupsEditor,
            this.RefreshAutoCategoryEditor, this.UpdateEventRegistry,
        }
        local registrations, unregistrations = {}, {}
        EVENT_MANAGER = {
            RegisterForUpdate = function(_, name, interval, callback)
                assert(interval == 1000 and callback == this.PollTrackerMarkers)
                assert(not registrations[name], "Marker timer must not be registered twice")
                registrations[name] = callback
            end,
            UnregisterForUpdate = function(_, name)
                assert(registrations[name], "Marker timer must only be unregistered while owned")
                registrations[name] = nil
                unregistrations[name] = (unregistrations[name] or 0) + 1
            end,
        }
        SCENE_MANAGER = { GetCurrentScene = function()
            return { GetName = function() return "inventory" end }
        end }
        this.AutoCategoryIntegration.OnProfileChanged = function() end
        this.RefreshTrackedItemsEditor = function() end
        this.RefreshGroupsEditor = function() end
        this.RefreshAutoCategoryEditor = function() end
        this.UpdateEventRegistry = function() end
        FCOIS = {
            libsLoadedProperly = true, addonVars = { gAddonLoaded = true },
            settingsVars = { settings = { isIconEnabled = { [1] = true, [2] = true, [3] = true },
                markedItems = { [1] = {}, [2] = {}, [3] = {} } } },
            GetSavedVarsMarkedItemsTableName = function() return "markedItems" end,
            IsMarked = function() return false, { [1] = false, [2] = false, [3] = false } end,
            markedItems = { [1] = {}, [2] = {}, [3] = {} },
        }
        FCOIS_CON_ICON_DECONSTRUCTION, FCOIS_CON_ICON_SELL, FCOIS_CON_ICON_SELL_AT_GUILDSTORE = 1, 2, 3
        local timerName = this.Name .. "_FCOItemSaverMarkerPoll"
        this.StartTrackerMarkerPolling()
        assert(not registrations[timerName], "Off state must not own a marker timer")
        adapter.Enable()
        assert(registrations[timerName], "Availability monitoring must start even without groups")
        assert(adapter.AddTestGroups())
        assert(registrations[timerName])
        this.StartTrackerMarkerPolling()
        Equal(unregistrations[timerName] or 0, 0, "Repeated start must not duplicate the timer")
        adapter.Suspend()
        assert(not registrations[timerName] and unregistrations[timerName] == 1)
        adapter.Resume()
        assert(registrations[timerName])
        assert(adapter.RemoveTestGroups())
        assert(registrations[timerName] and unregistrations[timerName] == 1)

        this.character.itemListInitialized = true
        this.character.PanelSettings = this.accountWide.PanelSettings
        this.SetUseCharacterItemList(true)
        assert(registrations[timerName], "Profile without FCO groups must retain availability monitoring")
        assert(adapter.AddTestGroups())
        assert(registrations[timerName], "Adding groups in the selected profile must start polling")
        this.SetUseCharacterItemList(false)
        assert(registrations[timerName], "Profile changes must retain availability monitoring")
        this.SetUseCharacterItemList(true)
        assert(registrations[timerName])
        this.SetItemTrackerPanelVisible(false)
        assert(registrations[timerName], "Hidden tracker must continue monitoring marker availability")
        FCOIS.settingsVars.settings.isIconEnabled[1] = false
        registrations[timerName]()
        assert(this.GetRuntimeRules().__ic_fco_deconstruct.isInactive,
            "Marker availability changes must invalidate hidden tracker rules")
        FCOIS.settingsVars.settings.isIconEnabled[1] = true
        registrations[timerName]()
        assert(not this.GetRuntimeRules().__ic_fco_deconstruct.isInactive,
            "Re-enabled markers must reactivate groups without showing the tracker")
        this.SetItemTrackerPanelVisible(true)
        assert(registrations[timerName], "Visible tracker must reacquire its marker timer")
        FCOIS = nil
        registrations[timerName]()
        assert(registrations[timerName] and this.GetRuntimeRules().__ic_fco_deconstruct.isInactive,
            "Unavailable dependency must remain monitored for recovery")
        adapter.TurnOff()
        assert(this.accountWide.fcoIntegrationState == "off" and not registrations[timerName])

        this.AutoCategoryIntegration.OnProfileChanged = previousProfileChanged
        this.RefreshTrackedItemsEditor, this.RefreshGroupsEditor =
            previousRefreshes[1], previousRefreshes[2]
        this.RefreshAutoCategoryEditor, this.UpdateEventRegistry =
            previousRefreshes[3], previousRefreshes[4]
        EVENT_MANAGER, SCENE_MANAGER = previousManager, previousSceneManager
        FCOIS = previousFCOIS
        FCOIS_CON_ICON_DECONSTRUCTION, FCOIS_CON_ICON_SELL, FCOIS_CON_ICON_SELL_AT_GUILDSTORE =
            previousConstants[1], previousConstants[2], previousConstants[3]
    end)

    Add("FCO marker polling is non-HUD visible-only, bounded to eight slots, and cancels stale passes", function()
        Setup({ 20 }, 50, true)
        local adapter = this.FCOItemSaver
        local previousManager, previousSceneManager, previousFCOIS = EVENT_MANAGER, SCENE_MANAGER, FCOIS
        local previousCallLater, previousRemoveCallLater = zo_callLater, zo_removeCallLater
        local previousProfileChanged = this.AutoCategoryIntegration.OnProfileChanged
        local previousRefreshes = {
            this.RefreshTrackedItemsEditor, this.RefreshGroupsEditor,
            this.RefreshAutoCategoryEditor, this.UpdateEventRegistry,
        }
        local currentScene, updates, registrations, unregistrations = "inventory", {}, 0, 0
        local previousConstants = {
            FCOIS_CON_ICON_DECONSTRUCTION, FCOIS_CON_ICON_SELL, FCOIS_CON_ICON_SELL_AT_GUILDSTORE,
        }
        EVENT_MANAGER = {
            RegisterForUpdate = function(_, name, interval, callback)
                assert(name == this.Name .. "_FCOItemSaverMarkerPoll" and interval == 1000)
                registrations = registrations + 1
                assert(registrations == unregistrations + 1, "Only one marker poll timer may be active")
                updates[name] = callback
            end,
            UnregisterForUpdate = function(_, name)
                assert(updates[name])
                updates[name] = nil
                unregistrations = unregistrations + 1
            end,
        }
        SCENE_MANAGER = { GetCurrentScene = function()
            return { GetName = function() return currentScene end }
        end }
        this.AutoCategoryIntegration.OnProfileChanged = function() end
        this.RefreshTrackedItemsEditor = function() end
        this.RefreshGroupsEditor = function() end
        this.RefreshAutoCategoryEditor = function() end
        this.UpdateEventRegistry = function() end
        local markerChanged, markerQueries = false, {}
        FCOIS = {
            libsLoadedProperly = true, addonVars = { gAddonLoaded = true },
            settingsVars = { settings = { isIconEnabled = { [1] = true, [2] = true, [3] = true },
                markedItems = { [1] = {}, [2] = {}, [3] = {} } } },
            GetSavedVarsMarkedItemsTableName = function() return "markedItems" end,
            IsMarked = function(bagId, slotIndex, markerIds)
                markerQueries[#markerQueries + 1] = { bagId, slotIndex, markerChanged }
                local markers, marked = {}, false
                for _, markerId in ipairs(markerIds) do
                    markers[markerId] = markerChanged and bagId == BAG_BACKPACK
                        and slotIndex == 1 and markerId == 1
                    marked = marked or markers[markerId]
                end
                return marked, markers
            end,
            markedItems = { [1] = {}, [2] = {}, [3] = {} },
        }
        FCOIS_CON_ICON_DECONSTRUCTION, FCOIS_CON_ICON_SELL, FCOIS_CON_ICON_SELL_AT_GUILDSTORE = 1, 2, 3
        adapter.Enable()
        assert(adapter.AddTestGroups())
        assert(registrations == 1 and next(updates) ~= nil)
        local readSlotMarkerKey = adapter.ReadSlotMarkerKey
        local reads = 0
        adapter.ReadSlotMarkerKey = function(...)
            reads = reads + 1
            return readSlotMarkerKey(...)
        end
        local queuedSlots, queueSlotUpdate = {}, this.QueueTrackerSlotUpdate
        this.QueueTrackerSlotUpdate = function(bagId, slotIndex)
            queuedSlots[#queuedSlots + 1] = { bagId, slotIndex }
            return queueSlotUpdate(bagId, slotIndex)
        end
        local oldClock = GetGameTimeMilliseconds
        local clock = 0
        GetGameTimeMilliseconds = function() clock = clock + 3; return clock end
        local pending, delays, serial = {}, {}, 0
        function zo_callLater(callback, delay)
            serial = serial + 1
            pending[serial], delays[serial] = callback, delay
            return serial
        end
        function zo_removeCallLater(handle) pending[handle] = nil end
        currentScene = "hud"
        this.PollTrackerMarkers()
        Equal(reads, 0, "HUD must not query markers")
        currentScene = "inventory"
        markerChanged = true
        this.PollTrackerMarkers()
        Equal(reads, 8, "Each poll slice may query at most eight occupied slots")
        assert(#queuedSlots == 1, string.format(
            "A marker change must queue the affected slot for tracker re-evaluation (queries=%d first=%s/%s/%s)",
            #markerQueries, tostring(markerQueries[1] and markerQueries[1][1]),
            tostring(markerQueries[1] and markerQueries[1][2]),
            tostring(markerQueries[1] and markerQueries[1][3])))
        Equal(queuedSlots[1][1], BAG_BACKPACK)
        Equal(queuedSlots[1][2], 1)
        local queuedHandle
        for handle, delay in pairs(delays) do
            if delay == 10 then queuedHandle = handle end
        end
        assert(queuedHandle and delays[queuedHandle] == 10)
        currentScene = "hud"
        this.StartTrackerMarkerPolling()
        assert(registrations == 1 and unregistrations == 0 and next(updates) ~= nil,
            "HUD transition must retain availability monitoring and invalidate its active pass")
        assert(pending[queuedHandle] == nil, "Visibility transition must cancel the delayed poll continuation")
        currentScene = "inventory"
        this.StartTrackerMarkerPolling()
        assert(registrations == 1 and next(updates) ~= nil)
        this.PollTrackerMarkers()
        Equal(reads, 16, "Visible non-HUD polling restarts with a fresh bounded pass")
        local function RunOnePollSlice()
            local handle
            for candidate in pairs(pending) do
                if handle == nil or candidate < handle then handle = candidate end
            end
            assert(handle)
            local callback = pending[handle]
            pending[handle] = nil
            callback()
        end
        while next(pending) do
            local before = reads
            RunOnePollSlice()
            assert(reads - before <= 8, "Poll continuation exceeded its eight-slot work budget")
        end
        assert(reads == 8 + 60 + 1,
            "Polling must visit each indexed occupied slot once per pass plus the queued slot refresh; got " .. reads)
        adapter.TurnOff()
        assert(registrations == 1 and unregistrations == 1)
        adapter.ReadSlotMarkerKey = readSlotMarkerKey
        this.QueueTrackerSlotUpdate = queueSlotUpdate
        GetGameTimeMilliseconds = oldClock
        this.AutoCategoryIntegration.OnProfileChanged = previousProfileChanged
        this.RefreshTrackedItemsEditor, this.RefreshGroupsEditor =
            previousRefreshes[1], previousRefreshes[2]
        this.RefreshAutoCategoryEditor, this.UpdateEventRegistry =
            previousRefreshes[3], previousRefreshes[4]
        EVENT_MANAGER, SCENE_MANAGER, FCOIS = previousManager, previousSceneManager, previousFCOIS
        zo_callLater, zo_removeCallLater = previousCallLater, previousRemoveCallLater
        FCOIS_CON_ICON_DECONSTRUCTION, FCOIS_CON_ICON_SELL, FCOIS_CON_ICON_SELL_AT_GUILDSTORE =
            previousConstants[1], previousConstants[2], previousConstants[3]
    end)

    Add("FCO Suspend, unavailable dependency and Turn Off make mixed groups wholly inactive with no marker queries", function()
        Setup({ 1, 1 }, 20, true)
        local adapter = this.FCOItemSaver
        local previousManager, previousSceneManager, previousFCOIS = EVENT_MANAGER, SCENE_MANAGER, FCOIS
        local previousProfileChanged = this.AutoCategoryIntegration.OnProfileChanged
        local previousRefreshes = {
            this.RefreshTrackedItemsEditor, this.RefreshGroupsEditor,
            this.RefreshAutoCategoryEditor, this.UpdateEventRegistry,
        }
        local previousConstants = {
            FCOIS_CON_ICON_DECONSTRUCTION, FCOIS_CON_ICON_SELL, FCOIS_CON_ICON_SELL_AT_GUILDSTORE,
        }
        EVENT_MANAGER = { RegisterForUpdate = function() end, UnregisterForUpdate = function() end }
        SCENE_MANAGER = { GetCurrentScene = function()
            return { GetName = function() return "inventory" end }
        end }
        this.AutoCategoryIntegration.OnProfileChanged = function() end
        this.RefreshTrackedItemsEditor = function() end
        this.RefreshGroupsEditor = function() end
        this.RefreshAutoCategoryEditor = function() end
        this.UpdateEventRegistry = function() end
        local queries = 0
        local function InstallFCOIS()
            FCOIS = {
                libsLoadedProperly = true, addonVars = { gAddonLoaded = true },
                settingsVars = { settings = { isIconEnabled = { [1] = true, [2] = true, [3] = true },
                    markedItems = { [1] = {}, [2] = {}, [3] = {} } } },
                GetSavedVarsMarkedItemsTableName = function() return "markedItems" end,
                IsMarked = function(bagId, slotIndex, markerIds)
                    queries = queries + 1
                    local markers, marked = {}, false
                    for _, markerId in ipairs(markerIds) do
                        markers[markerId] = markerId == 1 and bagId == BAG_BACKPACK and slotIndex == 0
                        marked = marked or markers[markerId]
                    end
                    return marked, markers
                end,
                markedItems = { [1] = {}, [2] = {}, [3] = {} },
            }
        end
        InstallFCOIS()
        FCOIS_CON_ICON_DECONSTRUCTION, FCOIS_CON_ICON_SELL, FCOIS_CON_ICON_SELL_AT_GUILDSTORE = 1, 2, 3
        adapter.Enable()
        assert(adapter.AddTestGroups())
        local key = "__ic_fco_deconstruct"
        this.accountWide.trackedRules[key].addedPatterns = { "group2" }
        this.InvalidateRuleCache()
        local markedId, nameId = fixture.index.group1[1], fixture.index.group2[1]

        local function Scan()
            queries = 0
            local snapshot = this.PreparedScanning.GetPreparedMasterItemList(
                this.GetActiveTrackedItems(), this.GetActiveTrackedRules(), { BAG_BACKPACK, BAG_BANK })
            return snapshot
        end
        local function AssertNameGroups(snapshot)
            assert(snapshot.items[markedId].matchedRules.group1, "Name-only scanning must continue")
            assert(snapshot.items[nameId].matchedRules.group2, "Name-only scanning must continue")
        end

        local snapshot = Scan()
        assert(queries > 0, "An enabled ready group must query markers")
        assert(snapshot.items[markedId].matchedRules[key], "Marker condition must match while active")
        assert(snapshot.items[nameId].matchedRules[key], "Name condition must match while active")
        AssertNameGroups(snapshot)

        adapter.Suspend()
        snapshot = Scan()
        Equal(queries, 0)
        assert(not snapshot.items[markedId].matchedRules[key] and not snapshot.items[nameId].matchedRules[key],
            "A suspended mixed group must be wholly inactive, including its name condition")
        assert(this.GetActiveTrackedRules()[key].isInactive == true)
        AssertNameGroups(snapshot)

        adapter.Resume()
        snapshot = Scan()
        assert(queries > 0 and snapshot.items[markedId].matchedRules[key]
            and snapshot.items[nameId].matchedRules[key], "Resume must restore retained participation")

        FCOIS = nil
        this.InvalidateRuleCache()
        snapshot = Scan()
        Equal(queries, 0)
        assert(this.GetActiveTrackedRules()[key].isInactive == true
            and not snapshot.items[markedId].matchedRules[key] and not snapshot.items[nameId].matchedRules[key],
            "An unavailable dependency must deactivate the whole group without marker queries")
        AssertNameGroups(snapshot)

        InstallFCOIS()
        this.InvalidateRuleCache()
        adapter.TurnOff()
        snapshot = Scan()
        Equal(queries, 0)
        assert(this.GetActiveTrackedRules()[key] == nil, "Turn Off must remove the groups")
        AssertNameGroups(snapshot)

        this.AutoCategoryIntegration.OnProfileChanged = previousProfileChanged
        this.RefreshTrackedItemsEditor, this.RefreshGroupsEditor =
            previousRefreshes[1], previousRefreshes[2]
        this.RefreshAutoCategoryEditor, this.UpdateEventRegistry =
            previousRefreshes[3], previousRefreshes[4]
        EVENT_MANAGER, SCENE_MANAGER = previousManager, previousSceneManager
        FCOIS = previousFCOIS
        FCOIS_CON_ICON_DECONSTRUCTION, FCOIS_CON_ICON_SELL, FCOIS_CON_ICON_SELL_AT_GUILDSTORE =
            previousConstants[1], previousConstants[2], previousConstants[3]
    end)

    Add("DEV FCO priority watcher gates on logging, deduplicates, and resets after a logging toggle", function()
        Setup({ 1 }, 20, true)
        local previousDevelopment, previousLog = this.IsDevelopment, this.DiagnosticLog
        local integration = this.AutoCategoryIntegration
        local previousStatus, previousResolve = integration.GetStatus, integration.ResolveAutoCategoryOrder
        local previousCallLater, previousRemoveCallLater = zo_callLater, zo_removeCallLater
        local previousClock = GetGameTimeMilliseconds
        local profile = this.GetAutoCategoryProfile()
        local groups = this.FCOItemSaver.GetGroups()
        local rowsByContext = { backpack = {}, bank = {} }
        local savedOrder = profile.autoCategoryOrder.contexts
        local events, statusCalls, orderCalls, revisionCalls = {}, 0, 0, 0
        local enabled, revision = false, 1
        local pending, serial, clock = {}, 0, 0

        this.IsDevelopment = true
        this.accountWide.fcoIntegrationState = "enabled"
        this.FCOItemSaver.RegisterBuiltInGroups(true)
        for _, group in ipairs(groups) do
            profile.trackedRules[group.key] = {
                display = { show = true, notify = false, bank = false, group = true,
                    isExpanded = true, isHidden = false },
                autoCategoryEnabled = true,
            }
        end
        profile.fcoTestGroupsCreated = true
        for _, contextKey in ipairs({ "backpack", "bank" }) do
            for _, mode in ipairs({ "matching", "display" }) do
                local sequence = savedOrder[contextKey][mode]
                for index = #sequence, 1, -1 do table.remove(sequence, index) end
                for index, group in ipairs(groups) do
                    local reference = "ic:" .. group.key
                    sequence[index] = reference
                    rowsByContext[contextKey][mode .. ":" .. reference] = index
                end
            end
        end
        integration.GetStatus = function()
            statusCalls = statusCalls + 1
            return "available", "ready"
        end
        integration.ResolveAutoCategoryOrder = function(contextKey, options)
            orderCalls = orderCalls + 1
            local rows = {}
            for _, group in ipairs(groups) do
                local reference = "ic:" .. group.key
                rows[#rows + 1] = {
                    kind = "group", reference = reference,
                    index = rowsByContext[contextKey][options.mode .. ":" .. reference],
                }
            end
            table.sort(rows, function(left, right) return left.index < right.index end)
            for index, row in ipairs(rows) do row.index = index end
            return rows
        end
        this.DiagnosticLog = {
            IsEnabled = function() return enabled end,
            GetEnableRevision = function()
                revisionCalls = revisionCalls + 1
                return revision
            end,
            Event = function(kind, message, details)
                events[#events + 1] = { kind = kind, message = message, details = details }
            end,
            Sample = function() end,
        }
        function GetGameTimeMilliseconds() clock = clock + 1; return clock end
        function zo_callLater(callback, delay)
            serial = serial + 1
            pending[serial] = { callback = callback, delay = delay }
            return serial
        end
        function zo_removeCallLater(handle) pending[handle] = nil end
        local function RefreshAndDrain()
            this.RefreshItemTrackerPanel("inventory")
            while next(pending) do
                local handle
                for candidate in pairs(pending) do
                    if handle == nil or candidate < handle then handle = candidate end
                end
                local callback = pending[handle].callback
                pending[handle] = nil
                callback()
            end
        end
        local function LastEventKind() return events[#events] and events[#events].kind end

        RefreshAndDrain()
        Equal(revisionCalls, 0, "Logging-off watcher must not query its revision")
        Equal(statusCalls, 0, "Logging-off watcher must not inspect AutoCategory")
        Equal(orderCalls, 0, "Logging-off watcher must not resolve group positions")

        enabled = true
        RefreshAndDrain()
        Equal(LastEventKind(), "acPriorityBaseline")
        local eventCount = #events
        RefreshAndDrain()
        Equal(#events, eventCount, "An unchanged baseline must be deduplicated")

        rowsByContext.backpack["matching:ic:" .. groups[1].key] = 3
        rowsByContext.backpack["matching:ic:" .. groups[3].key] = 1
        RefreshAndDrain()
        Equal(LastEventKind(), "acPriorityChanged")
        rowsByContext.backpack["matching:ic:" .. groups[1].key] = 1
        rowsByContext.backpack["matching:ic:" .. groups[3].key] = 3
        RefreshAndDrain()
        Equal(LastEventKind(), "acPriorityRecovered")

        enabled, revision = false, revision + 1
        RefreshAndDrain()
        enabled = true
        RefreshAndDrain()
        Equal(LastEventKind(), "acPriorityBaseline",
            "A logging revision change must establish a new baseline even without an intervening enabled scan")
        Equal(revisionCalls, 5)

        this.IsDevelopment, this.DiagnosticLog = previousDevelopment, previousLog
        integration.GetStatus, integration.ResolveAutoCategoryOrder = previousStatus, previousResolve
        zo_callLater, zo_removeCallLater, GetGameTimeMilliseconds =
            previousCallLater, previousRemoveCallLater, previousClock
        this.ResetPriorityWatch()
    end)

    Add("Tracker visibility ticker registers once on demand, unregisters, and restarts", function()
        Setup({ 2 }, 20, false)
        EVENT_OPEN_BANK, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, EVENT_CURRENCY_UPDATE = 1, 2, 3
        EVENT_CURRENCY_CAPS_CHANGED, EVENT_INVENTORY_BAG_CAPACITY_CHANGED = 4, 5
        EVENT_INVENTORY_BANK_CAPACITY_CHANGED, EVENT_PLAYER_ACTIVATED = 6, 7
        local tick, starts, stops = nil, 0, 0
        local updateName = this.Name .. "_HideCheck"
        EVENT_MANAGER.RegisterForUpdate = function(_, name, delay, callback)
            Equal(name, updateName)
            Equal(delay, 100)
            tick, starts = callback, starts + 1
        end
        EVENT_MANAGER.UnregisterForUpdate = function(_, name)
            Equal(name, updateName)
            tick, stops = nil, stops + 1
        end
        assert(loadstring(TrackerEventSource))()
        local updates = 0
        this.PanelLayout.UpdateContext = function() updates = updates + 1 end
        this.SetVisibilityTickerNeeded(false)
        Equal(starts, 0)
        Equal(stops, 0)
        this.SetVisibilityTickerNeeded(true)
        this.SetVisibilityTickerNeeded(true)
        Equal(starts, 1)
        tick()
        this.SetVisibilityTickerNeeded(false)
        this.SetVisibilityTickerNeeded(false)
        Equal(stops, 1)
        assert(tick == nil)
        this.SetVisibilityTickerNeeded(true)
        Equal(starts, 2)
        tick()
        Equal(updates, 2)
    end)

    Add("Tracker row preference validates defaults and malformed external input", function()
        Setup({}, 20, false)
        this.accountWide.PanelSettings.Tracker.trackerMaxRows = nil
        this.ValidateTrackerSettings()
        Equal(this.accountWide.PanelSettings.Tracker.trackerMaxRows, 20)
        for _, value in ipairs({ "20", true, {}, 0, 4, 51, 5.5, math.huge, 0 / 0 }) do
            this.accountWide.PanelSettings.Tracker.trackerMaxRows = value
            assert(not pcall(this.ValidateTrackerSettings), "Malformed row budget must fail")
        end
        for _, value in ipairs({ 5, 20, 50 }) do
            this.accountWide.PanelSettings.Tracker.trackerMaxRows = value
            this.ValidateTrackerSettings()
            Equal(this.accountWide.PanelSettings.Tracker.trackerMaxRows, value)
        end
    end)

    Add("Tracker title uses adjustable regular font and matching icon without changing rows", function()
        Setup({ 2 }, 20, false)
        for _, size in ipairs({ 16, 20, 28 }) do
            this.accountWide.PanelSettings.Tracker.trackerTitleSize = size
            this.RefreshItemTrackerPanel()
            Equal(InventoryCompanion_ItemTrackerFloatTitle.font, "regular-font|" .. size .. "|soft-shadow-thin")
            Equal(InventoryCompanion_ItemTrackerFloatEditIcon.width, size)
            Equal(InventoryCompanion_ItemTrackerFloatEditIcon.height, size)
            Equal(InventoryCompanion_ItemTrackerFloatSettingsIcon.width, size)
            Equal(InventoryCompanion_ItemTrackerFloatSettingsIcon.height, size)
            for _, row in ipairs(VisibleRows()) do Equal(row.height, 22) end
        end
        this.accountWide.PanelSettings.Tracker.trackerTitleSize = nil
        this.ValidateTrackerSettings()
        Equal(this.accountWide.PanelSettings.Tracker.trackerTitleSize, 20)
        for _, value in ipairs({ "20", true, {}, 15, 29, 20.5, math.huge, 0 / 0 }) do
            this.accountWide.PanelSettings.Tracker.trackerTitleSize = value
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
        assert(this.accountWide.PanelSettings.Tracker.showTrackedItemsPanel == false)
        assert(InventoryCompanion_ItemTrackerFloat:IsHidden())
        Equal(counters.scans, scans)
        Equal(updates, 1)
        this.ToggleItemTrackerPanel()
        assert(this.accountWide.PanelSettings.Tracker.showTrackedItemsPanel == true)
        assert(not InventoryCompanion_ItemTrackerFloat:IsHidden())
        Equal(counters.scans, scans + 1)
        Equal(updates, 2)
        this.accountWide.PanelSettings.Tracker.showTrackedItemsPanel = nil
        this.ToggleItemTrackerPanel()
        assert(this.accountWide.PanelSettings.Tracker.showTrackedItemsPanel == false, "Missing optional visibility means shown, so toggle must hide")
        this.UpdateEventRegistry = registry
    end)

    Add("Debug key runs tests without the long tracker performance benchmark", function()
        local previous = this.RunTests
        local arguments
        this.RunTests = function(value) arguments = value end
        this.Debug()
        this.RunTests = previous
        assert(arguments == "verbose copy autocategory")
    end)

    Add("Main addon settings expose AutoCategory recovery navigation and open the item editor", function()
        Setup({ 2 }, 20, false)
        this.accountWide.PanelSettings.Tracker.showTrackedItemsPanel = false
        this.accountWide.fcoIntegrationState = "off"
        this.defaultsCharacter = {}
        this.Utils.DisplayName = function() return "Inventory Companion" end
        this.GetCurrencyPanelSettingsControls = function() return {} end
        this.GetProgressBarResources = function() return {} end
        this.GetProgressBarAlertColor = function() return {} end
        local options, openedPanel
        local dialogs, shownDialog = {}, nil
        local previousDialogRegistrar = ZO_Dialogs_RegisterCustomDialog
        local previousShowDialog, previousRefreshProfile = ZO_Dialogs_ShowDialog, this.RefreshProfileSettings
        ZO_Dialogs_RegisterCustomDialog = function(name, dialog) dialogs[name] = dialog end
        ZO_Dialogs_ShowDialog = function(name) shownDialog = name end
        this.RefreshProfileSettings = function() end
        local settingsPanel = {}
        LibAddonMenu2 = {
            RegisterAddonPanel = function() return settingsPanel end,
            RegisterOptionControls = function(_, _, controls) options = controls end,
            OpenToPanel = function(_, panel) openedPanel = panel end,
        }
        CALLBACK_MANAGER = { RegisterCallback = function() end }
        this.CreateSettingsPanel()
        local button, visibility, statusDescription, enableToggle, editorButton, simulateButton
        local scope, copySource
        local navigation, integrationsIndex, copyIndex, explanationIndex
        local debugging, fcoPanel
        for index, option in ipairs(options) do
            if option.name == "Use Character Settings" then scope = option end
            if option.name == "Copy From" then copySource, copyIndex = option, index end
            if option.text == "You can copy all the settings from another profile, replacing your current settings." then
                explanationIndex = index
            end
            if option.reference == "InventoryCompanion_PanelNavigation" then navigation = option end
            if option.name == "Integrations" then
                integrationsIndex = index
                assert(options[index + 1].text ==
                    "You can extend the capabilities of IC by linking it to these other addons.")
            end
            if option.name == "AutoCategory" then
                assert(option.type == "submenu")
                statusDescription = option.controls[2]
                local buttonCount = 0
                for _, child in ipairs(option.controls) do
                    if child.type == "button" then buttonCount = buttonCount + 1 end
                    if child.name == "Enable" then enableToggle = child end
                    if child.name == "Settings" then editorButton = child end
                end
                assert(buttonCount == 1, "AutoCategory must have a single Settings destination")
            end
            if option.name == "Simulate integration failure (DEV)" then simulateButton = option end
            if option.name == "Debugging" then debugging = option end
            if option.name == "FCO ItemSaver (planned)" then fcoPanel = option end
            if option.name == "TTC (planned)" then
                assert(option.disabled == true, "TTC must remain a disabled future-development panel")
            end
            if option.name == "Item Tracker Panel" then
                for _, control in ipairs(option.controls) do
                    if control.name == "Show Tracked Items Panel" then visibility = control end
                end
            end
        end
        assert(explanationIndex < copyIndex, "Profile-copy explanation must precede the dropdown")
        assert(options[#options].name == "Debugging" and options[#options].type == "submenu",
            "Debugging must be the final expander")
        for index = integrationsIndex + 2, #options do
            assert(options[index].type == "submenu", "Only expanders may follow the integration introduction")
        end
        local previousWindowManager = WINDOW_MANAGER
        local created = 0
        WINDOW_MANAGER = { CreateControlFromVirtual = function(_, _, parent, template)
            assert(template == "ZO_DefaultButton")
            created = created + 1
            return Control("settingsNavigationButton" .. created, parent)
        end }
        local navigationRow = Control("settingsNavigation", GuiRoot, 600, 32)
        navigation.createFunc(navigationRow)
        WINDOW_MANAGER = previousWindowManager
        assert(created == 3)
        for index, name in ipairs({ "Manage Tracking", "Manage Groups", "Manage AutoCategory" }) do
            local panelButton = navigationRow.panelButtons[index]
            assert(panelButton.text == name and panelButton.y == 0)
            assert(panelButton.x == (index - 1) * (panelButton.width + 8))
            assert(panelButton.x + panelButton.width <= navigationRow:GetWidth())
        end
        button = navigationRow.panelButtons[1]
        local previousAutoCategory = AutoCategory
        AutoCategory = nil
        navigation.refreshFunc(navigationRow)
        assert(not navigationRow.panelButtons[3].enabled)
        AutoCategory = {}
        navigation.refreshFunc(navigationRow)
        assert(navigationRow.panelButtons[3].enabled)
        AutoCategory = previousAutoCategory
        assert(editorButton and editorButton.width == "half" and editorButton.hidden == nil,
            "The compact Settings button must remain visible for both editing and recovery")
        AutoCategory = nil
        assert(editorButton.disabled(), "Settings must be unavailable when AutoCategory is not loaded")
        AutoCategory = {}
        assert(not editorButton.disabled())

        local fcoControls, fcoRow = {}, nil
        assert(fcoPanel and fcoPanel.disabled == false,
            "The FCO future-development panel must be usable for implemented lifecycle actions")
        for _, control in ipairs(fcoPanel.controls) do
            if control.name then fcoControls[control.name] = control end
            if control.reference == "InventoryCompanion_FCOActions" then fcoRow = control end
            assert(control.type ~= "checkbox", "The disabled FCO placeholder must be replaced")
        end
        local debugControls = {}
        for _, control in ipairs(debugging.controls) do
            debugControls[control.name] = control
            assert(fcoControls[control.name] == nil, "FCO lifecycle actions must not remain under Debugging")
        end
        assert(debugControls["Add test FCO groups"] and debugControls["Add overlapping FCO test groups"]
            and not fcoControls["Add test FCO groups"] and not fcoControls["Add overlapping FCO test groups"],
            "Temporary test-group buttons must stay under Debugging, not the FCO panel")
        assert(fcoRow and fcoRow.type == "custom")
        local isReady, enableCount, suspendCount = false, 0, 0
        local fco = this.FCOItemSaver
        local previousFCO = { fco.GetReadinessReason, fco.Enable, fco.Suspend, fco.Resume, fco.TurnOff }
        this.FCOItemSaver.GetReadinessReason = function() return not isReady and "FCO unavailable" or nil end
        this.FCOItemSaver.Enable = function() enableCount = enableCount + 1; this.accountWide.fcoIntegrationState = "enabled" end
        this.FCOItemSaver.Suspend = function() suspendCount = suspendCount + 1; this.accountWide.fcoIntegrationState = "suspended" end
        this.FCOItemSaver.Resume = function() this.accountWide.fcoIntegrationState = "enabled" end
        this.FCOItemSaver.TurnOff = function() this.accountWide.fcoIntegrationState = "off" end
        WINDOW_MANAGER = {
            CreateControlFromVirtual = function(_, _, parent) return Control("fcoButton", parent) end,
            CreateControl = function(_, _, parent) return Control("fcoReason", parent) end,
        }
        local row = Control("fcoActions", GuiRoot, 600, 68)
        fcoRow.createFunc(row)
        WINDOW_MANAGER = previousWindowManager
        local function CheckActions(first, second, reason)
            fcoRow.refreshFunc(row)
            for index, expected in ipairs({ first or false, second or false }) do
                local action = row.fcoButtons[index]
                assert(action.hidden == not expected)
                assert(action.text == (expected or ""))
                assert(action.x == (index - 1) * (action.width + 8) and action.y == 0)
                assert((action.handlers.OnClicked ~= nil) == (expected ~= false))
            end
            assert(row.fcoReason.hidden == (reason == nil))
            assert(row.fcoReason.text == (reason or ""))
        end
        CheckActions(nil, nil, "FCO unavailable")
        isReady = true
        CheckActions("Enable")
        row.fcoButtons[1].handlers.OnClicked()
        assert(shownDialog == "InventoryCompanion_CONFIRM_FCO_ENABLE" and enableCount == 0,
            "Opening the confirmation must not enable the integration")
        assert(dialogs[shownDialog].mainText.text:find("add marker conditions to your groups", 1, true))
        dialogs[shownDialog].buttons[1].callback()
        assert(enableCount == 1 and this.accountWide.fcoIntegrationState == "enabled")
        CheckActions("Suspend", "Turn Off")
        isReady = false
        CheckActions("Suspend", "Turn Off")
        row.fcoButtons[1].handlers.OnClicked()
        assert(suspendCount == 0 and shownDialog == "InventoryCompanion_CONFIRM_FCO_SUSPEND")
        dialogs[shownDialog].buttons[1].callback()
        assert(suspendCount == 1 and this.accountWide.fcoIntegrationState == "suspended")
        CheckActions("Turn Off", nil, "FCO unavailable")
        isReady = true
        CheckActions("Resume", "Turn Off")
        row.fcoButtons[1].handlers.OnClicked()
        assert(shownDialog == "InventoryCompanion_CONFIRM_FCO_RESUME")
        dialogs[shownDialog].buttons[1].callback()
        assert(this.accountWide.fcoIntegrationState == "enabled")
        this.accountWide.fcoIntegrationState = "suspended"
        isReady = false
        CheckActions("Turn Off", nil, "FCO unavailable")
        row.fcoButtons[1].handlers.OnClicked()
        local turnOffDialog = dialogs[shownDialog]
        assert(#turnOffDialog.buttons == 2 and turnOffDialog.buttons[2].callback == nil
            and this.accountWide.fcoIntegrationState == "suspended",
            "Opening Turn Off or cancelling must preserve state and use the standard two-button dialog")
        assert(turnOffDialog.mainText.text:find("all profiles", 1, true))
        assert(turnOffDialog.mainText.text:find("suspend the integration instead", 1, true))
        assert(turnOffDialog.buttons[1].text == "Yes, delete my groups"
            and turnOffDialog.buttons[2].text == "No")
        turnOffDialog.buttons[1].callback()
        assert(this.accountWide.fcoIntegrationState == "off",
            "Only explicit deletion confirmation must turn integration off")
        assert(debugControls["Add overlapping FCO test groups"].disabled(),
            "Creating overlapping groups must require enabled integration")
        debugControls["Add overlapping FCO test groups"].func()
        assert(shownDialog == "InventoryCompanion_CONFIRM_ADD_FCO_OVERLAP_GROUPS"
            and #dialogs[shownDialog].buttons == 2,
            "Overlapping group creation must require confirmation")
        this.accountWide.fcoIntegrationState = "off"
        fco.GetReadinessReason, fco.Enable, fco.Suspend, fco.Resume, fco.TurnOff =
            previousFCO[1], previousFCO[2], previousFCO[3], previousFCO[4], previousFCO[5]
        ZO_Dialogs_RegisterCustomDialog = previousDialogRegistrar
        ZO_Dialogs_ShowDialog, this.RefreshProfileSettings = previousShowDialog, previousRefreshProfile
        assert(statusDescription and type(statusDescription.text) == "function")
        local integration = this.AutoCategoryIntegration
        local originalGetStatus, originalIsFaulted, originalOpenPanel =
            integration.GetStatus, integration.IsFaulted, this.OpenAutoCategoryPanel
        local openRecoveryCalls = 0
        integration.GetStatus = function() return "error", "synthetic raw traceback" end
        integration.IsFaulted = function() return true end
        this.OpenAutoCategoryPanel = function() openRecoveryCalls = openRecoveryCalls + 1 end
        this.accountWide.autoCategoryIntegrationEnabled = true
        local statusText = statusDescription.text()
        assert(statusText == integration.GetRecoveryMessage()
            and statusText:find("needs attention", 1, true)
            and statusText:find("groups and saved order are preserved", 1, true)
            and statusText:find("large_yellow_warning.dds", 1, true)
            and statusText:find("Reason:", 1, true),
            "Settings and recovery panel must share a warning with the specific reason")
        assert(enableToggle.getFunc() == true and enableToggle.disabled(),
            "A fault must retain the saved enable choice while blocking normal controls")
        assert(not editorButton.disabled(), "The Settings button must remain usable during a failure")
        assert(simulateButton == nil, "Settings must not expose a failure simulator")
        editorButton.func()
        Equal(openRecoveryCalls, 1)
        AutoCategory = previousAutoCategory
        integration.GetStatus, integration.IsFaulted, this.OpenAutoCategoryPanel =
            originalGetStatus, originalIsFaulted, originalOpenPanel
        local originalRefreshProfile = this.RefreshProfileSettings
        this.RefreshProfileSettings = function() end
        local updates = 0
        InventoryCompanion_ProfileCopySource = { UpdateChoices = function(_, names, keys)
            updates = updates + 1
            assert(#names == #keys and #keys == 2, "Newly initialized character must become a copy source")
        end }
        assert(#copySource.choicesValues == 1)
        scope.setFunc(true)
        scope.setFunc(false)
        assert(updates == 2 and this.character.itemListInitialized
            and this.accountWide.autoCategoryIntegrationEnabled == true)
        this.RefreshProfileSettings = originalRefreshProfile
        assert(visibility.setFunc == this.SetItemTrackerPanelVisible, "Checkbox and keybinding must share visibility handling")
        local current = "gameMenuInGame"
        SCENE_MANAGER = {
            IsShowing = function(_, name) return current == name end,
            Hide = function(_, name) if current == name then current = nil end end,
            Show = function(_, name) current = name end,
        }
        local refreshes = 0
        this.RefreshTrackedItemsEditor = function() refreshes = refreshes + 1 end
        button.handlers.OnClicked()
        Equal(current, "InventoryCompanion_TrackedItemsScene")
        Equal(refreshes, 1)
        button.handlers.OnClicked()
        Equal(current, "InventoryCompanion_TrackedItemsScene")
        Equal(refreshes, 2)
        assert(this.accountWide.PanelSettings.Tracker.showTrackedItemsPanel == false, "Opening the editor must not change saved HUD visibility")
        this.accountWide.PanelSettings.Tracker.showTrackedItemsPanel = true
        this.InitItemTrackerPanel()
        InventoryCompanion_ItemTrackerFloatSettingsIcon.handlers.OnClicked()
        Equal(openedPanel, settingsPanel)
        for _, scene in ipairs({ "InventoryCompanion_TrackedItemsScene", "InventoryCompanion_GroupsScene" }) do
            current, openedPanel = scene, nil
            this.state.lastActiveEditTab = scene
            this.OpenSettingsFromEditor()
            Equal(current, nil)
            Equal(openedPanel, settingsPanel)
            Equal(this.state.lastActiveEditTab, scene)
        end
    end)
    Add("AutoCategory recovery panel opens and reopens through editor navigation while writes are disabled", function()
        Setup({}, 20, false)
        local integration = this.AutoCategoryIntegration
        local previousFaulted = integration.IsFaulted
        local previousRefresh, previousGroups = this.RefreshAutoCategoryEditor, this.RefreshGroupsEditor
        local previousManager = SCENE_MANAGER
        InventoryCompanion_AutoCategoryWindow = Control("autoCategoryEditor", GuiRoot)
        local current, refreshes, groupRefreshes = nil, 0, 0
        SCENE_MANAGER = {
            IsShowing = function(_, name) return current == name end,
            Show = function(_, name) current = name end,
            Hide = function(_, name) if current == name then current = nil end end,
        }
        integration.IsFaulted = function() return true end
        local previousAutoCategory = AutoCategory
        AutoCategory = {}
        this.RefreshAutoCategoryEditor = function()
            assert(integration.NeedsRecovery() and not this.GetAutoCategoryState().enabled)
            refreshes = refreshes + 1
        end
        this.RefreshGroupsEditor = function() groupRefreshes = groupRefreshes + 1 end
        this.OpenAutoCategoryPanel()
        Equal(current, "InventoryCompanion_AutoCategoryScene")
        Equal(refreshes, 1)
        this.ToggleTrackedItemsEditor()
        Equal(current, nil)
        this.ToggleTrackedItemsEditor()
        Equal(current, "InventoryCompanion_AutoCategoryScene")
        Equal(refreshes, 2)
        this.ToggleTrackedItemsEditor()
        integration.IsFaulted = function() return false end
        this.accountWide.autoCategoryIntegrationEnabled = nil
        AutoCategory = nil
        this.ToggleTrackedItemsEditor()
        Equal(current, "InventoryCompanion_GroupsScene")
        Equal(groupRefreshes, 1)
        integration.IsFaulted = previousFaulted
        this.RefreshAutoCategoryEditor, this.RefreshGroupsEditor = previousRefresh, previousGroups
        SCENE_MANAGER = previousManager
        AutoCategory = previousAutoCategory
        InventoryCompanion_AutoCategoryWindow:SetHidden(true)
    end)
    Add("Tracker independent locations render exact backpack bank-only and combined counts", function()
        Setup({ 2 }, 20, true)
        for _, item in pairs(fixture.items) do item.bagCount, item.bankCount = 3, 10 end
        local function Count(name)
            for _, row in ipairs(VisibleRows()) do
                if GetControl(row, "Name").text == name then return GetControl(row, "Count").text end
            end
            error("Missing count row: " .. name)
        end
        this.UpdateRuleFlag("group1", "showBackpack", false)
        this.UpdateRuleFlag("group1", "showBank", true)
        this.RefreshItemTrackerPanel()
        Equal(Count("group1"), "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t 14")
        Equal(GetControl(VisibleRows()[2], "Count").text, "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t 7")
        this.UpdateRuleFlag("group1", "showBackpack", true)
        this.RefreshItemTrackerPanel()
        Equal(Count("group1"), "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t 14  |t16:16:EsoUI/Art/Tooltips/icon_bag.dds|t 6")
        this.UpdateRuleFlag("group1", "showBank", false)
        this.RefreshItemTrackerPanel()
        Equal(Count("group1"), "|t16:16:EsoUI/Art/Tooltips/icon_bag.dds|t 6")
        this.UpdateRuleFlag("group1", "showBackpack", false)
        this.RefreshItemTrackerPanel()
        for _, row in ipairs(VisibleRows()) do
            assert(GetControl(row, "Name").text ~= "group1", "Neither location must hide group")
        end

        Setup({ 1 }, 20, true)
        this.UpdateRuleFlag("group1", "group", false)
        local id = fixture.index.group1[1]
        fixture.items[id].bagCount, fixture.items[id].bankCount = 3, 10
        this.UpdateRuleFlag("group1", "showBackpack", false)
        this.UpdateRuleFlag("group1", "showBank", true)
        this.RefreshItemTrackerPanel()
        Equal(Count("miscellaneous"), "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t 7")
        Click("miscellaneous")
        Equal(GetControl(VisibleRows()[2], "Count").text, "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t 7")
        this.accountWide.PanelSettings.Tracker.trackerGroupThreshold = 8
        this.RefreshItemTrackerPanel()
        Equal(GetControl(VisibleRows()[1], "Count").text, "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t 7")
        this.UpdateRuleFlag("group1", "showBank", false)
        this.accountWide.trackedItems[id] = { display = { showBackpack = false, showBank = true } }
        this.RefreshItemTrackerPanel()
        Equal(GetControl(VisibleRows()[1], "Count").text, "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t 7")

        Setup({ 2, 2 }, 20, true)
        for _, item in pairs(fixture.items) do item.bagCount, item.bankCount = 3, 10 end
        this.UpdateRuleFlag("group1", "showBackpack", false)
        this.UpdateRuleFlag("group1", "showBank", true)
        this.UpdateRuleFlag("group2", "showBackpack", true)
        this.UpdateRuleFlag("group2", "showBank", false)
        this.RefreshItemTrackerPanel()
        Equal(Count("group1"), "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t 14")
        Equal(Count("group2"), "|t16:16:EsoUI/Art/Tooltips/icon_bag.dds|t 6")
        for _, row in ipairs(VisibleRows()) do
            assert(not GetControl(row, "Count").text:find("\\", 1, true), "Location icons replace the separator")
        end
    end)
    return tests
end
