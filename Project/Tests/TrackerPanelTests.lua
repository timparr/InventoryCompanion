local this = InventoryCompanion
local controls, pooled = {}, {}
local counters, fixture

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
        return #tostring(self.text) * 7
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
function GetItemLinkName(link) return link end
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
    fixture.items[id] = { link = string.rep("x", length or 8) .. string.format("%04d", id),
        icon = "icon", bagCount = 1, bankCount = 1 }
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

local function SavedExpanded(name) return this.GetActiveTrackedRules()[name].display.isExpanded end
local function VisibleRows()
    local result = {}
    for _, row in ipairs(pooled) do
        if not row.hidden then result[#result + 1] = row end
    end
    return result
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
        this.accountWide.trackerMaxRows = 10
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
        assert(not Expanded("group1") and not Expanded("group2"))
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
        assert(Expanded("group1") and Expanded("group2") and this.accountWide.wrapTrackedItemNames)
        for _, row in ipairs(VisibleRows()) do Equal(row.height, 22) end
        Equal(counters.writes, 0)
        this.accountWide.trackerMaxRows = 20
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
        assert(count:GetWidth() >= #count.text * 8, "Long bank count lacks estimated width")
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
        this.accountWide.wrapTrackedItemNames = true
        this.RefreshItemTrackerPanel()
        CheckRightMargin(false)
        Click("group1")
        CheckRightMargin(true)
        for _, row in ipairs(VisibleRows()) do Equal(row:GetHeight(), 22) end
        Click("group1")
        CheckRightMargin(false)
        this.accountWide.showTrackedItemsPanel = false
        this.RefreshItemTrackerPanel()
        this.accountWide.showTrackedItemsPanel = true
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
        assert(not Expanded("group1") and not Expanded("group2"))
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
        this.accountWide.trackerMaxRows = 8
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
        this.accountWide.trackerMaxRows = 10
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
        this.accountWide.trackerMaxRows = 11
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
            Equal(GetControl(visible[1], "Count").text, tostring(size * 2) .. " \\ " .. tostring(size))
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
        Equal(GetControl(visible[1], "Count").text, "200")
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
        this.accountWide.trackerMaxRows = 8
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

    Add("Tracker toggle stays hidden across interaction and editor visibility ticks", function()
        Setup({ 2 }, 20, false)
        this.RefreshItemTrackerPanel()
        local tick
        EVENT_MANAGER.RegisterForUpdate = function(_, _, _, callback) tick = callback end
        ZO_CompassFrame = Control("compass", GuiRoot)
        InventoryCompanion_TrackedItemsWindow = Control("itemsEditor", GuiRoot)
        InventoryCompanion_GroupsWindow = Control("groupsEditor", GuiRoot)
        InventoryCompanion_CurrencyFloat = Control("currency", GuiRoot)
        local interaction = false
        this.Utils.IsItemInteractionActive = function() return interaction end
        this.HasVisibleCurrencyResources = function() return false end
        this.SetProgressBarsHidden = function() end
        local adjust, restore = this.AdjustTrackerPositionForInteraction, this.RestoreTrackerPosition
        local adjustments = 0
        this.AdjustTrackerPositionForInteraction = function() adjustments = adjustments + 1 end
        this.RestoreTrackerPosition = function() end
        this.InitCutsceneTicker()

        for _, context in ipairs({ "world", "interaction", "items", "groups" }) do
            interaction = context == "interaction"
            InventoryCompanion_TrackedItemsWindow:SetHidden(context ~= "items")
            InventoryCompanion_GroupsWindow:SetHidden(context ~= "groups")
            this.SetItemTrackerPanelVisible(false)
            local before = adjustments
            tick()
            tick()
            assert(InventoryCompanion_ItemTrackerFloat:IsHidden(), context .. " forced hidden tracker visible")
            Equal(adjustments, before)
            this.ToggleItemTrackerPanel()
            tick()
            assert(not InventoryCompanion_ItemTrackerFloat:IsHidden(), context .. " did not restore tracker")
            Equal(adjustments, before + (interaction and 1 or 0))
        end
        InventoryCompanion_TrackedItemsWindow:SetHidden(true)
        InventoryCompanion_GroupsWindow:SetHidden(true)
        ZO_CompassFrame:SetHidden(true)
        tick()
        assert(InventoryCompanion_ItemTrackerFloat:IsHidden(), "Cutscene suppression must remain active")
        this.AdjustTrackerPositionForInteraction, this.RestoreTrackerPosition = adjust, restore
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
            Equal(InventoryCompanion_ItemTrackerFloatSettingsIcon.width, size)
            Equal(InventoryCompanion_ItemTrackerFloatSettingsIcon.height, size)
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
        local options, openedPanel
        local settingsPanel = {}
        LibAddonMenu2 = {
            RegisterAddonPanel = function() return settingsPanel end,
            RegisterOptionControls = function(_, _, controls) options = controls end,
            OpenToPanel = function(_, panel) openedPanel = panel end,
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
        this.accountWide.showTrackedItemsPanel = true
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
        Equal(Count("group1"), "14")
        Equal(GetControl(VisibleRows()[2], "Count").text, "7")
        this.UpdateRuleFlag("group1", "showBackpack", true)
        this.RefreshItemTrackerPanel()
        Equal(Count("group1"), "20 \\ 6")
        this.UpdateRuleFlag("group1", "showBank", false)
        this.RefreshItemTrackerPanel()
        Equal(Count("group1"), "6")
        this.UpdateRuleFlag("group1", "showBackpack", false)
        this.RefreshItemTrackerPanel()
        for _, row in ipairs(VisibleRows()) do
            assert(GetControl(row, "Name").text ~= "group1", "Neither location must hide group")
        end

        Setup({ 1 }, 20, true)
        local id = fixture.index.group1[1]
        fixture.items[id].bagCount, fixture.items[id].bankCount = 3, 10
        this.UpdateRuleFlag("group1", "showBackpack", false)
        this.UpdateRuleFlag("group1", "showBank", true)
        this.RefreshItemTrackerPanel()
        Equal(Count("miscellaneous"), "7")
        Click("miscellaneous")
        Equal(GetControl(VisibleRows()[2], "Count").text, "7")
        this.accountWide.trackerGroupThreshold = 8
        this.RefreshItemTrackerPanel()
        Equal(GetControl(VisibleRows()[1], "Count").text, "7")
        this.UpdateRuleFlag("group1", "showBank", false)
        this.accountWide.trackedItems[id] = { display = { showBackpack = false, showBank = true } }
        this.RefreshItemTrackerPanel()
        Equal(GetControl(VisibleRows()[1], "Count").text, "7")
    end)
    return tests
end
