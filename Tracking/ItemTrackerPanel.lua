InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local trackerRows = {}
local previousLayout = nil
local trackerSlotIndex
local pendingSlotUpdates = {}
local slotUpdateScheduled = false
local slotUpdateHandle
local slicedTrackerJob
local markerPollPass
local markerPollRegistered = false
local markerAvailabilitySignature
local trackerRefreshGeneration = 0
local pendingTrackerRender
local pendingIncrementalRender
local lastInventoryRenderAt
local priorityWatchRevision
local priorityWatchSignature
local priorityWatchHadMismatch
local ROW_HEIGHT = 22
local ROW_WIDTH = 320
local MAX_GROUP_ITEM_ROWS = 200
local MIN_COUNT_WIDTH = 36
local COUNT_WIDTH_PER_CHARACTER = 8

local function WatchFCOGroupPriority()
    if not this.DiagnosticLog.IsEnabled() then return end
    if this.IsDevelopment ~= true then return end
    local revision = this.DiagnosticLog.GetEnableRevision()
    if priorityWatchRevision ~= revision then
        priorityWatchRevision = revision
        priorityWatchSignature = nil
    end
    if this.accountWide.fcoIntegrationState ~= "enabled" then return end
    local profile = this.GetAutoCategoryProfile()
    if profile.fcoTestGroupsCreated ~= true then return end
    local state, message = this.AutoCategoryIntegration.GetStatus()
    if state ~= "available" then return end
    local groups = this.FCOItemSaver.GetGroups()
    local contexts = { "backpack", "bank" }
    local records = {}
    local mismatches = {}
    for _, contextKey in ipairs(contexts) do
        local saved = profile.autoCategoryOrder.contexts[contextKey]
        for _, mode in ipairs({ "matching", "display" }) do
            local positions = {}
            for index, reference in ipairs(saved[mode]) do positions[reference] = index end
            local actualPositions = {}
            for _, row in ipairs(this.AutoCategoryIntegration.ResolveAutoCategoryOrder(
                contextKey, { mode = mode })) do
                if row.kind == "group" then actualPositions[row.reference] = row.index end
            end
            for _, group in ipairs(groups) do
                local reference = "ic:" .. group.key
                local savedPosition = positions[reference]
                local actualPosition = actualPositions[reference]
                records[#records + 1] = {
                    context = contextKey, mode = mode, group = group.key,
                    savedPosition = savedPosition, actualPosition = actualPosition,
                }
                if savedPosition ~= actualPosition then
                    mismatches[#mismatches + 1] = string.format("%s/%s %s saved=%s actual=%s",
                        contextKey, mode, group.key, tostring(savedPosition), tostring(actualPosition))
                end
            end
        end
    end
    local signatureParts = {}
    for _, record in ipairs(records) do
        signatureParts[#signatureParts + 1] = string.format("%s/%s/%s=%s/%s",
            record.context, record.mode, record.group,
            tostring(record.savedPosition), tostring(record.actualPosition))
    end
    local signature = table.concat(signatureParts, ";")
    if priorityWatchSignature == signature then return end
    local previous = priorityWatchSignature
    priorityWatchSignature = signature
    local hadMismatch = #mismatches > 0
    local event = previous == nil and "acPriorityBaseline"
        or priorityWatchHadMismatch and not hadMismatch and "acPriorityRecovered" or "acPriorityChanged"
    priorityWatchHadMismatch = hadMismatch
    local details = { "Integration status: " .. tostring(state) .. "; " .. tostring(message) }
    for _, record in ipairs(records) do
        details[#details + 1] = string.format("%s/%s %s saved=%s actual=%s",
            record.context, record.mode, record.group,
            tostring(record.savedPosition), tostring(record.actualPosition))
    end
    this.DiagnosticLog.Event(event, hadMismatch and table.concat(mismatches, "; ")
        or "FCO group saved and actual positions captured without mismatches", details)
end

function this.ResetPriorityWatch()
    priorityWatchRevision = this.DiagnosticLog.GetEnableRevision()
    priorityWatchSignature = nil
    priorityWatchHadMismatch = nil
end

local function GetRowsContainer()
    return InventoryCompanion_ItemTrackerFloatContainerRows
end

local function GetRowsChild()
    return GetControl(GetRowsContainer(), "ScrollChild")
end

local function OnTrackerMoveStop(control)
    this.PanelLayout.OnMoveStop("Tracker")
end

local function OnTrackerMouseUp(control, button)
    if button == MOUSE_BUTTON_INDEX_RIGHT then
        ClearMenu()

        -- 1. Toggle: Show/Hide Empty Tracked Items
        local showEmpty = (this.GetPanelSettings("Tracker").showEmptyTrackedItems ~= false)
        AddCustomMenuItem(
            (showEmpty and "Hide Empty Tracked Items" or "Show Empty Tracked Items"),
            function()
                this.GetPanelSettings("Tracker").showEmptyTrackedItems = not showEmpty
                this.RefreshItemTrackerPanel()
            end,
            MENU_ADD_OPTION_LABEL
        )

        -- 2. Toggle: Multiline / Single Line View
        local isWrapped = (this.GetPanelSettings("Tracker").wrapTrackedItemNames == true)
        AddCustomMenuItem(
            (isWrapped and "Single Line View" or "Multiline View"),
            function()
                this.GetPanelSettings("Tracker").wrapTrackedItemNames = not isWrapped
                this.RefreshItemTrackerPanel()
            end,
            MENU_ADD_OPTION_LABEL
        )

        -- 3. Open Full Settings Editor
        AddCustomMenuItem(
            "Manage Tracking...",
            function()
                this.ToggleTrackedItemsEditor()
            end,
            MENU_ADD_OPTION_LABEL
        )

        ShowMenu()
    end
end

function this.InitItemTrackerPanel()
    this.PanelLayout.RegisterPanel("Tracker", InventoryCompanion_ItemTrackerFloat)
    InventoryCompanion_ItemTrackerFloat:SetHandler("OnMoveStop", OnTrackerMoveStop)
    InventoryCompanion_ItemTrackerFloat:SetHandler("OnMouseUp", OnTrackerMouseUp)

    if InventoryCompanion_ItemTrackerFloatContainer then
        InventoryCompanion_ItemTrackerFloatContainer:SetHandler("OnMouseDown", function(control, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                this.PanelLayout.OnMoveStart("Tracker")
                InventoryCompanion_ItemTrackerFloat:StartMoving()
            end
        end)
        InventoryCompanion_ItemTrackerFloatContainer:SetHandler("OnMouseUp", OnTrackerMouseUp)
    end

    -- Edit Icon
    InventoryCompanion_ItemTrackerFloatEditIcon:SetAlpha(0.6)
    InventoryCompanion_ItemTrackerFloatEditIcon:SetHandler("OnMouseEnter", function(control) control:SetAlpha(1.0) end)
    InventoryCompanion_ItemTrackerFloatEditIcon:SetHandler("OnMouseExit", function(control) control:SetAlpha(0.6) end)
    InventoryCompanion_ItemTrackerFloatEditIcon:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            this.ToggleTrackedItemsEditor()
        end
    end)

    local settingsIcon = InventoryCompanion_ItemTrackerFloatSettingsIcon
    settingsIcon:SetAlpha(0.6)
    settingsIcon:SetHandler("OnMouseEnter", function(control) control:SetAlpha(1.0) end)
    settingsIcon:SetHandler("OnMouseExit", function(control) control:SetAlpha(0.6) end)
    settingsIcon:SetHandler("OnClicked", function()
        this.OpenSettingsPanel()
    end)

    this.RefreshItemTrackerPanel()
end

------------------------------------------------------------------
-- RenderPopulatedRows
------------------------------------------------------------------
local function HideAllTrackerRows()
    for _, row in ipairs(trackerRows) do
        row:SetHidden(true)
    end
end

local function GetOrCreateTrackerRow(rowIndex)
    local row = trackerRows[rowIndex]
    if not row then
        row = CreateControlFromVirtual("InventoryCompanion_ItemTrackerFloatRow_", GetRowsChild(), "InventoryCompanion_ItemTrackerRow_Multi_Template", rowIndex)
        trackerRows[rowIndex] = row
    end
    return row
end

local function ApplyRowAnchors(row, rowIndex, wrapped)
    row:ClearAnchors()
    if rowIndex == 1 then
        row:SetAnchor(TOPLEFT, GetRowsChild(), TOPLEFT, 0, 0)
    else
        row:SetAnchor(TOPLEFT, trackerRows[rowIndex - 1], BOTTOMLEFT, 0, wrapped and 4 or 2)
    end
end

local function GetAvailableNameWidth(row, nameControl)
    local rowWidth = row:GetWidth()
    local nameLeft = nameControl:GetLeft() - row:GetLeft()
    
    local rightControlsWidth = 0

    for i = 1, row:GetNumChildren() do
        local child = row:GetChild(i)
        if child and not child:IsHidden() and child ~= nameControl then
            local childLeft = child:GetLeft() - row:GetLeft()
            if childLeft > nameLeft then
                rightControlsWidth = rightControlsWidth + child:GetWidth()
            end
        end
    end

    local availableWidth = (rowWidth - nameLeft) - rightControlsWidth - 8
    return math.max(50, availableWidth)
end

local function GetCountText(item)
    if item.isEmpty then return "" end
    local counts = {}
    if item.showBank then
        counts[#counts + 1] = "|t16:16:EsoUI/Art/Tooltips/icon_bank.dds|t "
            .. this.Utils.FormatBigNumber(item.bankCount - item.count)
    end
    if item.showBackpack ~= false then
        counts[#counts + 1] = "|t16:16:EsoUI/Art/Tooltips/icon_bag.dds|t "
            .. this.Utils.FormatBigNumber(item.count)
    end
    return table.concat(counts, "  ")
end

local function EstimateCountWidth(text)
    local visibleText = text:gsub("|t16:16:[^|]+|t", "  ")
    return #visibleText * COUNT_WIDTH_PER_CHARACTER
end

local function PopulateBaseRow(rowIndex, itemData, wrapped)
    local row = GetOrCreateTrackerRow(rowIndex)
    row.itemData = itemData
    ApplyRowAnchors(row, rowIndex, wrapped)
    row:SetWidth(ROW_WIDTH)
    
    local nameControl = GetControl(row, "Name")
    local iconControl = GetControl(row, "Icon")
    local expandIcon  = GetControl(row, "ExpandIcon")
    local countCtrl   = GetControl(row, "Count")
    
    if itemData.isGroup then
        local iconPath = itemData.isExpanded and "EsoUI/Art/Buttons/minus_up.dds" or "EsoUI/Art/Buttons/plus_up.dds"
        expandIcon:SetTexture(iconPath)
        expandIcon:SetDrawLayer(DL_CONTROLS)
        expandIcon:SetDrawLevel(3)
        expandIcon:SetAlpha(1.0)
        expandIcon:SetHidden(false)

        iconControl:ClearAnchors()
        iconControl:SetAnchor(TOPLEFT, row, TOPLEFT, 22, 2)
        
        nameControl:ClearAnchors()
        nameControl:SetAnchor(TOPLEFT, row, TOPLEFT, 44, 0)

        row:SetHandler("OnMouseDown", function(control, button)
            if button == MOUSE_BUTTON_INDEX_LEFT and itemData.ruleName then
                local newState = not itemData.isExpanded
                this.SetRuleFlag(itemData.ruleName, "isExpanded", newState)
                this.RefreshItemTrackerPanel(newState and "expand" or "collapse", itemData.ruleName)
            end
        end)
        row:SetHandler("OnMouseUp", function(control, button)
            if button == MOUSE_BUTTON_INDEX_RIGHT then
                OnTrackerMouseUp(control, button)
            end
        end)
        row:SetMouseEnabled(true)
        row:SetHandler("OnMouseWheel", function(_, delta)
            ZO_Scroll_OnMouseWheel(GetRowsContainer(), delta)
        end)

    elseif itemData.isGroupMember then
        expandIcon:SetHidden(true)

        iconControl:ClearAnchors()
        iconControl:SetAnchor(TOPLEFT, row, TOPLEFT, 18, 2)
        
        nameControl:ClearAnchors()
        nameControl:SetAnchor(TOPLEFT, row, TOPLEFT, 40, 0)

        row:SetHandler("OnMouseDown", nil)
        row:SetHandler("OnMouseUp", nil)
        row:SetHandler("OnMouseWheel", nil)
        row:SetMouseEnabled(false)

    else
        expandIcon:SetHidden(true)

        iconControl:ClearAnchors()
        iconControl:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 2)
        
        nameControl:ClearAnchors()
        nameControl:SetAnchor(TOPLEFT, row, TOPLEFT, 22, 0)

        row:SetHandler("OnMouseDown", nil)
        row:SetHandler("OnMouseUp", nil)
        row:SetHandler("OnMouseWheel", nil)
        row:SetMouseEnabled(false)
    end

    iconControl:SetTexture(itemData.icon or "")
    iconControl:SetHidden(itemData.overflowCount ~= nil)
    iconControl:SetDrawLayer(DL_CONTROLS)
    iconControl:SetDrawLevel(2)
    iconControl:SetAlpha(1.0)
    if itemData.isOverflowGroup then
        iconControl:SetColor(1, 0.75, 0, 1)
    else
        iconControl:SetColor(1, 1, 1, 1)
    end
            
    nameControl:SetText(itemData.displayLabel or itemData.link)
    if itemData.displayLabel then
        nameControl:SetMouseEnabled(true)
        nameControl:SetHandler("OnMouseEnter", function(control)
            InitializeTooltip(InformationTooltip, control, TOP, 0, -5)
            InformationTooltip:AddLine(itemData.displayLabel, "ZoFontGame", 1, 1, 1, 1)
        end)
        nameControl:SetHandler("OnMouseExit", function()
            ClearTooltip(InformationTooltip)
        end)
    else
        nameControl:SetMouseEnabled(false)
        nameControl:SetHandler("OnMouseEnter", nil)
        nameControl:SetHandler("OnMouseExit", nil)
    end
    if itemData.isOverflowGroup then
        nameControl:SetColor(1, 0.25, 0.25, 1)
    elseif itemData.isEmpty then
        nameControl:SetColor(1, 1, 1, 1)
    else
        local quality = itemData.quality or GetItemLinkQuality(itemData.link) or 0
        local colorDef = GetItemQualityColor(math.max(0, quality))
        if colorDef then
            nameControl:SetColor(colorDef:UnpackRGBA())
        end
    end

    local countText = GetCountText(itemData)
    countCtrl:SetText(countText)

    row:SetHidden(false)
    return { row = row, nameControl = nameControl, countCtrl = countCtrl, countText = countText }
end

local function CalculateMaxCountWidth(computedRows)
    local maxWidth = 0
    for _, entry in ipairs(computedRows) do
        entry.countCtrl:SetWidth(0)
        local width = entry.countCtrl:GetTextWidth()
        if entry.countText ~= "" then
            width = math.max(width, MIN_COUNT_WIDTH, EstimateCountWidth(entry.countText))
        end
        if width > maxWidth then
            maxWidth = width
        end
    end
    return maxWidth
end

local function CalculateMinAvailableNameWidth(computedRows, maxCountWidth)
    local minWidth = 99999
    for _, entry in ipairs(computedRows) do
        entry.countCtrl:SetWidth(maxCountWidth)
        local availWidth = math.max(50, GetAvailableNameWidth(entry.row, entry.nameControl))
        if availWidth < minWidth then
            minWidth = availWidth
        end
    end
    return minWidth
end

local function GetUtf8Length(value)
    local count = 0
    for index = 1, #value do
        local byte = value:byte(index)
        if byte < 0x80 or byte >= 0xC0 then count = count + 1 end
    end
    return count
end

local function GetUtf8Prefix(value, characterCount)
    local byteIndex, count = 1, 0
    while byteIndex <= #value and count < characterCount do
        local firstByte = value:byte(byteIndex)
        local byteCount = firstByte >= 0xF0 and 4
            or firstByte >= 0xE0 and 3
            or firstByte >= 0xC0 and 2
            or 1
        byteIndex = byteIndex + byteCount
        count = count + 1
    end
    return value:sub(1, math.min(byteIndex - 1, #value))
end

local function GetTruncatedDisplayLabel(item, nameControl, availableWidth)
    local fullLabel = item.displayLabel
    nameControl:SetText(fullLabel)
    if nameControl:GetTextWidth() <= availableWidth then return fullLabel end

    local groupName = item.displayPrefix:sub(2, -3)
    for length = GetUtf8Length(groupName) - 1, 0, -1 do
        local shortened = "[" .. GetUtf8Prefix(groupName, length) .. "..." .. "]:"
            .. item.displayItemName
        nameControl:SetText(shortened)
        if nameControl:GetTextWidth() <= availableWidth then return shortened end
    end
    nameControl:SetText(item.displayItemName)
    return item.displayItemName
end

local function ApplyFinalRowLayout(computedRows, minAvailableWidth, items, wrapped)
    local height = 0
    for index, entry in ipairs(computedRows) do
        local nameControl = entry.nameControl
        local row = entry.row

        nameControl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        if wrapped and not items[index].isGroup then
            nameControl:SetDimensionConstraints(minAvailableWidth, 0, minAvailableWidth, 0)
            if items[index].displayLabel then nameControl:SetText(items[index].displayLabel) end
            items[index].rowUnits = math.max(1, nameControl:GetNumLines())
        else
            nameControl:SetDimensionConstraints(minAvailableWidth, ROW_HEIGHT, minAvailableWidth, ROW_HEIGHT)
            if items[index].displayLabel then
                nameControl:SetText(GetTruncatedDisplayLabel(items[index], nameControl, minAvailableWidth))
            end
            items[index].rowUnits = 1
        end
        row:SetHeight(items[index].rowUnits * ROW_HEIGHT)
        height = height + row:GetHeight() + (index > 1 and (wrapped and 4 or 2) or 0)
    end
    return height
end

local function MeasureWrappedRows(items)
    local row = GetOrCreateTrackerRow(1)
    local name, count = GetControl(row, "Name"), GetControl(row, "Count")
    local maxCountWidth, maxIndent = 0, 22
    count:SetWidth(0)
    for _, item in ipairs(items) do
        local text = GetCountText(item)
        count:SetText(text)
        maxCountWidth = math.max(maxCountWidth, count:GetTextWidth(), EstimateCountWidth(text))
        maxIndent = math.max(maxIndent, item.isGroup and 44 or (item.isGroupMember and 40 or 22))
    end
    local width = math.max(50, ROW_WIDTH - maxIndent - maxCountWidth - 12)
    name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    name:SetDimensionConstraints(width, 0, width, 0)
    for _, item in ipairs(items) do
        if item.isGroup then
            item.rowUnits = 1
        else
            name:SetText(item.displayLabel or item.link)
            item.rowUnits = math.max(1, name:GetNumLines())
        end
    end
end

local function RenderPopulatedRows(itemsToDisplay, wrapped)
    HideAllTrackerRows()
    local computedRows = {}
    for rowIndex, itemData in ipairs(itemsToDisplay) do
        table.insert(computedRows, PopulateBaseRow(rowIndex, itemData, wrapped))
    end
    
    local maxCountWidth = CalculateMaxCountWidth(computedRows)
    local minAvailableWidth = CalculateMinAvailableNameWidth(computedRows, maxCountWidth)
    
    return ApplyFinalRowLayout(computedRows, minAvailableWidth, itemsToDisplay, wrapped)
end

------------------------------------------------------------------
-- BuildDisplayList
------------------------------------------------------------------
local function CollectSortedGroupNames(activeRules, snapshot, miscRows)
    local sortedGroupNames = {}
    for ruleName, ruleData in pairs(activeRules) do
        if ruleName ~= "miscellaneous" and ruleData.display.group and ruleData.display.show then
            local itemIds = snapshot.ruleIndex[ruleName]
            if itemIds and #itemIds > 0 then
                table.insert(sortedGroupNames, ruleName)
            end
        end
    end
    table.sort(sortedGroupNames)
    if #miscRows > 0 then
        table.insert(sortedGroupNames, "miscellaneous")
    end
    return sortedGroupNames
end

local function GetItemLocations(display)
    return display.showBackpack ~= false, display.showBank == true
end

local function GetRelevantCount(item, backpack, bank)
    return (backpack and item.bagCount or 0) + (bank and (item.bankCount - item.bagCount) or 0)
end

local function CreateRowIdentity(sourceRuleName, itemId)
    sourceRuleName = tostring(sourceRuleName)
    return string.format("%d:%s:%s", #sourceRuleName, sourceRuleName, tostring(itemId))
end

local function CreateMiscRow(itemId, itemData, display, sourceRuleName, displayName, duplicate)
    local linkName = GetItemLinkName(itemData.link) or ""
    local displayLabel
    if duplicate then
        displayLabel = string.format("[%s]:%s", displayName, linkName)
    end
    local row = {
        itemId = itemId,
        link = itemData.link,
        icon = itemData.icon,
        bagCount = itemData.bagCount,
        count = itemData.bagCount,
        bankCount = itemData.bankCount,
        showBackpack = display.showBackpack,
        showBank = display.showBank,
        sortName = displayLabel or linkName,
        displayLabel = displayLabel,
        displayPrefix = duplicate and ("[" .. displayName .. "]:") or nil,
        displayItemName = duplicate and linkName or nil,
        sourceRuleName = sourceRuleName,
        sourceDisplayName = duplicate and displayName or nil,
        rowIdentity = CreateRowIdentity(sourceRuleName, itemId),
        isGroupMember = true,
        parentGroup = "miscellaneous",
    }
    return row
end

local function ProcessGroupsAndMembers(sortedGroupNames, activeRules, snapshot, miscRows,
    miscHeaderSources, showEmpty, itemsToDisplay)
    for _, ruleName in ipairs(sortedGroupNames) do
        local ruleData = activeRules[ruleName]
        local itemIds = snapshot.ruleIndex[ruleName]
        local headerSources = {}
        local detailRows = {}
        if ruleName == "miscellaneous" then
            for itemId, source in pairs(miscHeaderSources) do
                headerSources[#headerSources + 1] = {
                    itemId = itemId,
                    itemData = source.itemData,
                    display = source.display,
                }
            end
        elseif itemIds then
            local group = snapshot.groups[ruleName]
            for _, itemId in ipairs(itemIds) do
                headerSources[#headerSources + 1] = {
                    itemId = itemId,
                    itemData = group.items[itemId],
                    display = ruleData.display,
                }
            end
        end

        local totalGroupCount = 0
        local totalGroupBankCount = 0
        local highestQuality = -1
        local bestIcon = nil
        local bestLink = nil
        local showBank = ruleData.display.showBank == true
        local showBackpack = ruleData.display.showBackpack ~= false
        for _, source in ipairs(headerSources) do
            local itemData = source.itemData
            local itemShowBackpack, itemShowBank = GetItemLocations(source.display)
            if GetRelevantCount(itemData, itemShowBackpack, itemShowBank) > 0 then
                totalGroupCount = totalGroupCount + (itemShowBackpack and itemData.bagCount or 0)
                totalGroupBankCount = totalGroupBankCount
                    + GetRelevantCount(itemData, itemShowBackpack, itemShowBank)

                if not bestIcon and itemData.icon and itemData.icon ~= "" then
                    bestIcon = itemData.icon
                end

                local quality = GetItemLinkQuality(itemData.link) or 0
                if quality > highestQuality then
                    highestQuality = quality
                    bestIcon = itemData.icon
                    bestLink = itemData.link
                elseif quality == highestQuality and itemData.link < (bestLink or "") then
                    bestIcon = itemData.icon
                    bestLink = itemData.link
                end
            end
        end

        if ruleName == "miscellaneous" then
            bestIcon = "EsoUI/Art/Tooltips/icon_bag.dds"
            showBackpack = false
            showBank = false
            for _, source in ipairs(headerSources) do
                local itemShowBackpack, itemShowBank = GetItemLocations(source.display)
                showBackpack = showBackpack or itemShowBackpack
                showBank = showBank or itemShowBank
            end
            for _, row in ipairs(miscRows) do
                if GetRelevantCount(row, row.showBackpack ~= false, row.showBank == true) > 0 or showEmpty then
                    detailRows[#detailRows + 1] = row
                end
            end
        else
            bestIcon = bestIcon or "/esoui/art/quickslots/quickslot_emptyslot.dds"
        end

        if totalGroupBankCount > 0 or showEmpty
            or ruleName == "miscellaneous" and #detailRows > 0 then
            local colorDef = GetItemQualityColor(math.max(0, highestQuality))
            local groupTitle = ruleData.displayName or ruleName
            local displayName = colorDef and colorDef:Colorize(groupTitle) or groupTitle

            local groupHeader = {
                link = displayName,
                icon = bestIcon,
                count = showBackpack and totalGroupCount or 0,
                showBackpack = showBackpack,
                showBank = showBank,
                bankCount = showBank and totalGroupBankCount or 0,
                sortName = groupTitle,
                isGroup = true,
                isExpanded = ruleData.display.isExpanded == true,
                ruleName = ruleName,
                quality = math.max(0, highestQuality),
            }
            table.insert(itemsToDisplay, groupHeader)

            if ruleName ~= "miscellaneous" and itemIds then
                local group = snapshot.groups[ruleName]
                for _, itemId in ipairs(itemIds) do
                    local itemData = group.items[itemId]
                    local itemShowBackpack, itemShowBank = GetItemLocations(ruleData.display)
                    if GetRelevantCount(itemData, itemShowBackpack, itemShowBank) > 0 or showEmpty then
                        detailRows[#detailRows + 1] = {
                            itemId = itemId,
                            link = itemData.link,
                            icon = itemData.icon,
                            count = itemData.bagCount,
                            showBackpack = itemShowBackpack,
                            showBank = itemShowBank,
                            bankCount = itemData.bankCount,
                            sortName = GetItemLinkName(itemData.link) or "",
                            sourceRuleName = ruleName,
                            rowIdentity = CreateRowIdentity(ruleName, itemId),
                            isGroupMember = true,
                            parentGroup = ruleName,
                        }
                    end
                end
            end

            local memberCount = #detailRows
            if memberCount > MAX_GROUP_ITEM_ROWS then
                groupHeader.isOverflowGroup = true
                groupHeader.link = groupTitle
                groupHeader.icon = "/esoui/art/buttons/info_up.dds"
                itemsToDisplay[#itemsToDisplay + 1] = {
                    link = string.format("Your patterns matched %d items - too many to display here.",
                        memberCount),
                    isEmpty = true,
                    isGroupMember = true,
                    parentGroup = ruleName,
                    itemId = "overflow",
                    rowIdentity = CreateRowIdentity(ruleName, "overflow"),
                    overflowCount = memberCount,
                }
            else
                table.sort(detailRows, function(a, b)
                    if a.sortName == b.sortName then return a.rowIdentity < b.rowIdentity end
                    return a.sortName < b.sortName
                end)
                for _, member in ipairs(detailRows) do
                    itemsToDisplay[#itemsToDisplay + 1] = member
                end
            end
        end
    end
end

local function CollectAllVisibleItems(snapshot, activeRules, trackedItems, showEmpty, seenVisibleIds)
    local allVisibleItems = {}
    local sourcesByItemId = {}
    local ungroupedItemIds = {}

    for ruleName, ruleData in pairs(activeRules) do
        if ruleName ~= "miscellaneous" and ruleData.display.show then
            local itemIds = snapshot.ruleIndex[ruleName]
            if itemIds then
                for _, itemId in ipairs(itemIds) do
                    local itemData = snapshot.groups[ruleName].items[itemId]
                    assert(itemData ~= nil, "Missing group item in tracker snapshot: " .. ruleName .. "/" .. tostring(itemId))
                    local sources = sourcesByItemId[itemId] or {}
                    sourcesByItemId[itemId] = sources
                    sources[#sources + 1] = itemData
                    if not ruleData.display.group then ungroupedItemIds[itemId] = true end
                    if not seenVisibleIds[itemId] then
                        local showBackpack, showBank = GetItemLocations(ruleData.display)
                        local relevantCount = GetRelevantCount(itemData, showBackpack, showBank)
                        if relevantCount > 0 or showEmpty then
                            seenVisibleIds[itemId] = true
                            table.insert(allVisibleItems, {
                                link = itemData.link,
                                icon = itemData.icon,
                                count = itemData.bagCount,
                                showBackpack = showBackpack,
                                showBank = showBank,
                                bankCount = itemData.bankCount,
                                sortName = GetItemLinkName(itemData.link) or "",
                            })
                        end
                    end
                end
            end
        end
    end

    if trackedItems then
        for itemId, data in pairs(trackedItems) do
            local itemData = snapshot.items[itemId]
            local display = this.ResolveItemDisplay(data.display)
            if display.show and not ungroupedItemIds[itemId] then
                assert(itemData ~= nil, "Missing tracked item in tracker snapshot: " .. tostring(itemId))
                local sources = sourcesByItemId[itemId] or {}
                sourcesByItemId[itemId] = sources
                sources[#sources + 1] = itemData
            end
            if display.show and not seenVisibleIds[itemId] then
                assert(itemData ~= nil, "Missing tracked item in tracker snapshot: " .. tostring(itemId))
                local bagCount = itemData.bagCount
                local bankCount = itemData.bankCount
                local showBank = display.showBank
                local relevantCount = GetRelevantCount(itemData, display.showBackpack, showBank)

                if relevantCount > 0 or showEmpty then
                    seenVisibleIds[itemId] = true
                    table.insert(allVisibleItems, {
                        link = itemData.link,
                        icon = itemData.icon,
                        count = bagCount,
                        showBackpack = display.showBackpack,
                        showBank = showBank,
                        bankCount = bankCount,
                        sortName = GetItemLinkName(itemData.link) or "",
                    })
                end
            end
        end
    end

    local differingItemCount = 0
    for _, sources in pairs(sourcesByItemId) do
        if #sources > 1 then
            local first = sources[1]
            local firstBankCount = first.bankCount - first.bagCount
            for index = 2, #sources do
                local source = sources[index]
                if source.bagCount ~= first.bagCount
                    or source.bankCount - source.bagCount ~= firstBankCount then
                    differingItemCount = differingItemCount + 1
                    break
                end
            end
        end
    end

    return allVisibleItems, differingItemCount
end

local function FoldSingleMemberAndUngroupedIntoMisc(snapshot, activeRules, trackedItems)
    local ungroupedSourcesByItemId = {}
    local miscRows = {}
    local miscHeaderSources = {}
    local processedItemIds = {}

    for ruleName, ruleData in pairs(activeRules) do
        if ruleName ~= "miscellaneous" and ruleData.display.show and not ruleData.display.group then
            local itemIds = snapshot.ruleIndex[ruleName]
            if itemIds then
                for _, itemId in ipairs(itemIds) do
                    local sources = ungroupedSourcesByItemId[itemId] or {}
                    ungroupedSourcesByItemId[itemId] = sources
                    sources[#sources + 1] = {
                        ruleName = ruleName,
                        displayName = ruleData.displayName or ruleName,
                        display = ruleData.display,
                        itemData = snapshot.groups[ruleName].items[itemId],
                    }
                end
            end
        end
    end

    for itemId, sources in pairs(ungroupedSourcesByItemId) do
        local first = sources[1]
        miscHeaderSources[itemId] = first
        processedItemIds[itemId] = true

        local firstItem = first.itemData
        local firstBankCount = firstItem.bankCount - firstItem.bagCount
        local hasDifferentCounts = false
        for index = 2, #sources do
            local itemData = sources[index].itemData
            if itemData.bagCount ~= firstItem.bagCount
                or itemData.bankCount - itemData.bagCount ~= firstBankCount then
                hasDifferentCounts = true
                break
            end
        end

        if hasDifferentCounts then
            for _, source in ipairs(sources) do
                miscRows[#miscRows + 1] = CreateMiscRow(itemId, source.itemData, source.display,
                    source.ruleName, source.displayName, true)
            end
        else
            miscRows[#miscRows + 1] = CreateMiscRow(itemId, first.itemData, first.display,
                first.ruleName, first.displayName, false)
        end
    end

    if trackedItems then
        for itemId, data in pairs(trackedItems) do
            local display = this.ResolveItemDisplay(data.display)
            if display.show and not processedItemIds[itemId] then
                local source = {
                    ruleName = "trackedItem",
                    displayName = "",
                    display = display,
                    itemData = snapshot.items[itemId],
                }
                miscHeaderSources[itemId] = source
                miscRows[#miscRows + 1] = CreateMiscRow(itemId, source.itemData, display,
                    source.ruleName, source.displayName, false)
                processedItemIds[itemId] = true
            end
        end
    end

    if activeRules["miscellaneous"] then
        activeRules["miscellaneous"].display.group = true
        activeRules["miscellaneous"].display.show = true
    end
    return miscRows, miscHeaderSources
end

local function BuildDisplayList(snapshot, activeRules, trackedItems, showEmpty)
    local seenVisibleIds = {}
    local allVisibleItems, differingItemCount =
        CollectAllVisibleItems(snapshot, activeRules, trackedItems, showEmpty, seenVisibleIds)
    local hasDifferingCounts = differingItemCount > 0

    local threshold = (this.accountWide and this.GetPanelSettings("Tracker").trackerGroupThreshold) or 8
    if #allVisibleItems < threshold and not hasDifferingCounts then
        table.sort(allVisibleItems, function(a, b) return a.sortName < b.sortName end)
        return allVisibleItems, differingItemCount
    end

    local miscRows, miscHeaderSources = FoldSingleMemberAndUngroupedIntoMisc(snapshot, activeRules, trackedItems)
    local sortedGroupNames = CollectSortedGroupNames(activeRules, snapshot, miscRows)
    local itemsToDisplay = {}
    ProcessGroupsAndMembers(sortedGroupNames, activeRules, snapshot, miscRows,
        miscHeaderSources, showEmpty, itemsToDisplay)
    return itemsToDisplay, differingItemCount
end

function this.BuildTrackerDisplayListForPerformanceTest(snapshot, activeRules, trackedItems, showEmpty)
    return BuildDisplayList(snapshot, activeRules, trackedItems, showEmpty)
end

local function RuleSignature(rule)
    local parts = { tostring(rule.display.show), tostring(rule.display.showBank),
        tostring(rule.display.group), tostring(rule.display.isHidden), tostring(rule.display.showBackpack) }
    for _, pattern in ipairs(rule.patterns) do
        parts[#parts + 1] = #pattern .. ":" .. pattern
    end
    return table.concat(parts, ";")
end

local function BuildLayoutModel(items, rules)
    local model = { items = items, groups = {}, order = {}, baseRows = 0 }
    for _, item in ipairs(items) do
        if item.isGroup then
            local group = {
                expanded = item.isExpanded, preferredExpanded = item.isExpanded,
                members = {}, memberCount = 0,
                ruleSignature = RuleSignature(rules[item.ruleName]), signatureParts = {},
            }
            model.groups[item.ruleName] = group
            model.order[#model.order + 1] = item.ruleName
        elseif item.isGroupMember then
            local group = model.groups[item.parentGroup]
            local memberIdentity = item.rowIdentity or item.itemId
            group.members[memberIdentity] = true
            group.memberCount = group.memberCount + 1
            group.signatureParts[#group.signatureParts + 1] = tostring(memberIdentity) .. ":"
                .. tostring(item.showBank) .. ":" .. tostring(item.showBackpack) .. ":"
                .. tostring(item.displayLabel) .. ":" .. tostring(item.overflowCount)
        end
        if not item.isGroupMember then
            model.baseRows = model.baseRows + 1
        end
    end
    for _, name in ipairs(model.order) do
        local group = model.groups[name]
        group.signature = group.ruleSignature .. ";" .. table.concat(group.signatureParts, ";")
        group.signatureParts = nil
    end
    return model
end

function this.BuildTrackerLayoutModelForPerformanceTest(items, rules)
    return BuildLayoutModel(items, rules)
end

local function SelectRows(model, expanded)
    local rows = {}
    for _, item in ipairs(model.items) do
        if item.isGroup then item.isExpanded = expanded[item.ruleName] end
        if not item.isGroupMember or expanded[item.parentGroup] then
            rows[#rows + 1] = item
        end
    end
    return rows
end

local function CountRows(model, expanded)
    local count = model.baseRows
    for _, name in ipairs(model.order) do
        if expanded[name] then
            local group = model.groups[name]
            count = count + group.memberCount
        end
    end
    return count
end

local function LayoutChanged(model, previous)
    if not previous or #model.order ~= #previous.order then return true end
    for _, name in ipairs(model.order) do
        local group, old = model.groups[name], previous.groups[name]
        if not old or group.signature ~= old.signature or group.memberCount ~= old.memberCount then return true end
        for id in pairs(group.members) do
            if not old.members[id] then return true end
        end
    end
    return false
end

local function ChooseLayout(model, previous, reason, target, budget)
    local expanded, allExpanded = {}, {}
    for _, name in ipairs(model.order) do
        local group = model.groups[name]
        local old = previous and previous.groups[name]
        expanded[name] = group.preferredExpanded
        if old and old.preferredExpanded == group.preferredExpanded
            and not ((reason == "expand" or reason == "collapse") and name == target) then
            expanded[name] = group.preferredExpanded and old.expanded
        end
        allExpanded[name] = group.preferredExpanded
    end

    local function Fits(selection)
        return CountRows(model, selection) <= budget
    end

    local changed = LayoutChanged(model, previous)
    local function Reintroduced(name)
        if not model.groups[name].preferredExpanded then return false end
        local group, old = model.groups[name], previous.groups[name]
        if not old or old.signature ~= group.signature then
            -- Membership changes during inventory bursts are growth, not configuration changes.
            if old and reason == "inventory" and old.ruleSignature == group.ruleSignature then return false end
            return true
        end
        return false
    end
    if reason ~= "expand" and reason ~= "collapse"
        and (changed or reason == "settings")
        and Fits(allExpanded) then
        expanded = allExpanded
    elseif reason ~= "expand" and reason ~= "collapse" and previous then
        -- Reintroduced/edited categories may use spare space, but may not displace others.
        for _, name in ipairs(model.order) do
            if Reintroduced(name) then
                expanded[name] = false
            end
        end
        local used = CountRows(model, expanded)
        for _, name in ipairs(model.order) do
            if Reintroduced(name) then
                local additional = model.groups[name].memberCount
                if used + additional <= budget then
                    expanded[name] = true
                    used = used + additional
                end
            end
        end
    end

    local collapsed = false
    if not Fits(expanded) and (changed or not previous or reason == "expand"
        or reason == "settings" or previous.budget ~= budget) then
        local retain = nil
        if reason == "expand" then
            retain = target
        elseif reason == "inventory" and previous then
            local candidates = 0
            for _, name in ipairs(model.order) do
                local group, old = model.groups[name], previous.groups[name]
                if old and old.expanded and expanded[name] and group.ruleSignature == old.ruleSignature
                    and group.memberCount > old.memberCount then
                    candidates = candidates + 1
                    retain = name
                end
            end
            if candidates ~= 1 then retain = nil end
        end
        for _, name in ipairs(model.order) do
            expanded[name] = name == retain
        end
        collapsed = true
    end
    return expanded, collapsed
end

local function ApplyViewport(contentHeight, budget, wrapped, previousOffset, target)
    local container = InventoryCompanion_ItemTrackerFloatContainer
    local headerHeight = InventoryCompanion_ItemTrackerFloatTitle:GetHeight() + 4
    local gap = wrapped and 4 or 2
    local maxHeight = math.max(1, math.min(budget * (ROW_HEIGHT + gap) - gap,
        GuiRoot:GetHeight() - headerHeight - 8))
    local viewportHeight = math.min(contentHeight, maxHeight)
    local scrollable = contentHeight > viewportHeight
    local contentWidth = ROW_WIDTH - (scrollable and ZO_SCROLL_BAR_WIDTH or 0)
    local rows = GetRowsContainer()
    rows:SetWidth(ROW_WIDTH)
    rows:SetHeight(viewportHeight)
    rows.scroll:ClearAnchors()
    rows.scroll:SetAnchor(TOPLEFT, rows, TOPLEFT, 0, 0)
    rows.scroll:SetAnchor(BOTTOMRIGHT, rows, BOTTOMRIGHT,
        scrollable and -ZO_SCROLL_BAR_WIDTH or 0, 0)
    GetRowsChild():SetDimensions(contentWidth, contentHeight)
    if scrollable then
        for _, row in ipairs(trackerRows) do
            if not row:IsHidden() then
                row:SetWidth(contentWidth)
                local name = GetControl(row, "Name")
                local nameWidth = name:GetWidth() - ZO_SCROLL_BAR_WIDTH
                name:SetDimensionConstraints(nameWidth, ROW_HEIGHT, nameWidth, ROW_HEIGHT)
                if not wrapped and row.itemData.displayLabel then
                    name:SetText(GetTruncatedDisplayLabel(row.itemData, name, nameWidth))
                end
            end
        end
    end
    container:SetWidth(ROW_WIDTH)
    container:SetHeight(headerHeight + viewportHeight)
    InventoryCompanion_ItemTrackerFloat:SetWidth(ROW_WIDTH + 20)
    InventoryCompanion_ItemTrackerFloat:SetHeight(headerHeight + viewportHeight + 8)
    ZO_Scroll_UpdateScrollBar(rows)
    local offset = math.max(0, math.min(previousOffset, contentHeight - viewportHeight))
    if target then
        local top = target:GetTop() - GetRowsChild():GetTop()
        if top < offset then offset = top end
        if top + ROW_HEIGHT > offset + viewportHeight then offset = top + ROW_HEIGHT - viewportHeight end
    end
    if scrollable then
        ZO_Scroll_ScrollAbsoluteInstantly(rows, offset)
    else
        ZO_Scroll_ResetToTop(rows)
    end
end

------------------------------------------------------------------
-- Editor Collision & Repositioning Handling
------------------------------------------------------------------

------------------------------------------------------------------
-- Refresh Panel
------------------------------------------------------------------
local function GetTrackerCoordinates()
    local oldLeft = InventoryCompanion_ItemTrackerFloat:GetLeft()
    local oldTop = InventoryCompanion_ItemTrackerFloat:GetTop()
    return oldLeft, oldTop
end

function this.GetTrackerDisplayList()
    local trackedItems = this.GetActiveTrackedItems()
    local activeRules = this.GetActiveTrackedRules()
    local showEmpty = this.GetPanelSettings("Tracker").showEmptyTrackedItems ~= false

    local snapshot, slotIndex = this.GetMasterItemList(trackedItems, activeRules, this.GetTrackerBagIdList())
    if slotIndex then
        slotIndex.profile, slotIndex.revision = this.GetTrackerContext()
        slotIndex.runtimeRules, slotIndex.subscriber = this.GetRuntimeRules(), IsESOPlusSubscriber()
        trackerSlotIndex = slotIndex
    end
    local displayList, differingItemCount =
        BuildDisplayList(snapshot, activeRules, trackedItems, showEmpty)
    return displayList, activeRules, snapshot, differingItemCount
end

local function ApplyBoundedPosition(oldLeft, oldTop)
    InventoryCompanion_ItemTrackerFloat:ClearAnchors()
    InventoryCompanion_ItemTrackerFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, oldLeft, oldTop)
    InventoryCompanion_ItemTrackerFloat:SetHidden(false)

    local newHeight = InventoryCompanion_ItemTrackerFloat:GetHeight()
    local bottomLimit = GuiRoot:GetHeight()
    local finalTop = oldTop

    if this.PanelLayout.IsNormalContext() and (oldTop + newHeight) > bottomLimit then
        finalTop = math.max(0, bottomLimit - newHeight)
    end

    InventoryCompanion_ItemTrackerFloat:ClearAnchors()
    InventoryCompanion_ItemTrackerFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, oldLeft, finalTop)
    this.PanelLayout.UpdateVisibility()
end

local slicedTrackerBudgetMs = 8
local slicedTrackerDelayMs = 10
local inventoryRenderIntervalMs = 333

local function SameRuleNames(slotIndex, activeRules)
    for ruleName in pairs(activeRules) do
        if not slotIndex.ruleNames[ruleName] then return false end
    end
    for ruleName in pairs(slotIndex.ruleNames) do
        if not activeRules[ruleName] then return false end
    end
    return true
end

local function SlotIndexIsCurrent(slotIndex, activeRules)
    local profile, revision = this.GetTrackerContext()
    if profile ~= slotIndex.profile or revision ~= slotIndex.revision
        or this.GetRuntimeRules() ~= slotIndex.runtimeRules or IsESOPlusSubscriber() ~= slotIndex.subscriber
        or not SameRuleNames(slotIndex, activeRules) then
        return false
    end
    local markerIds = this.FCOItemSaver.GetActiveMarkerIds(activeRules)
    if #markerIds ~= #slotIndex.markerIds then return false end
    for index, markerId in ipairs(markerIds) do
        if slotIndex.markerIds[index] ~= markerId then return false end
    end
    return true
end

local function MarkSlot(set, bagId, slotIndex)
    local slots = set[bagId]
    if not slots then slots = {}; set[bagId] = slots end
    slots[slotIndex] = true
end

local function ApplySlotsToIndex(slotIndex, changed, rules)
    local slotCount = 0
    for bagId, slots in pairs(changed) do
        local bag = slotIndex.bags[bagId]
        if bag then
            for slot in pairs(slots) do
                slotCount = slotCount + 1
                if not bag.ordered[slot] then
                    bag.ordered[slot] = true
                    bag.order[#bag.order + 1] = slot
                end
                local record = this.EvaluateTrackerSlot(bagId, slot, rules)
                if record then
                    record.markerKey = this.FCOItemSaver.ReadSlotMarkerKey(bagId, slot, slotIndex.markerIds)
                end
                bag.slots[slot] = record
            end
        end
    end
    return slotCount
end

local function CompareTrackerSnapshots(left, right)
    local differences = {}
    local itemIds = {}
    for itemId in pairs(left.items) do itemIds[itemId] = true end
    for itemId in pairs(right.items) do itemIds[itemId] = true end
    for itemId in pairs(itemIds) do
        local a, b = left.items[itemId], right.items[itemId]
        local different = a == nil or b == nil
        if not different then
            different = a.bagCount ~= b.bagCount or a.bankCount ~= b.bankCount
            for key in pairs(a.matchedRules) do if not b.matchedRules[key] then different = true end end
            for key in pairs(b.matchedRules) do if not a.matchedRules[key] then different = true end end
        end
        if different then
            differences[#differences + 1] = string.format("item %s indexed=%s fresh=%s",
                tostring(itemId), a and string.format("%d/%d", a.bagCount, a.bankCount) or "missing",
                b and string.format("%d/%d", b.bagCount, b.bankCount) or "missing")
            if #differences >= 20 then break end
        end
    end
    return differences
end

local RenderTrackerDisplayList

local function ScheduleTrackerRender(render)
    local token = {}
    render.timerToken = token
    if render.handle then zo_removeCallLater(render.handle) end
    render.handle = nil
    local delay = 0
    if lastInventoryRenderAt then
        delay = math.max(0, math.min(inventoryRenderIntervalMs,
            lastInventoryRenderAt + inventoryRenderIntervalMs - GetGameTimeMilliseconds()))
    end
    local started = false
    local handle = zo_callLater(function()
        started = true
        if render.timerToken ~= token then return end
        render.handle = nil
        render.callback()
    end, delay)
    if not started then render.handle = handle end
end

local function CancelPendingIncrementalRender()
    local render = pendingIncrementalRender
    pendingIncrementalRender = nil
    if render then
        render.timerToken = nil
        if render.handle then zo_removeCallLater(render.handle) end
    end
end

local function CountMarkedSlots(set)
    local count = 0
    for _, slots in pairs(set) do
        for _ in pairs(slots) do count = count + 1 end
    end
    return count
end

local function DescribeSlotRecord(record)
    if not record then return "empty" end
    return string.format("%s x%s", tostring(record.itemData.itemId), tostring(record.itemData.count))
end

local function DescribeSlotDifferences(previous, fresh, dirty)
    local lines, total = {}, 0
    for _, bagId in ipairs(fresh.bagIds) do
        local previousSlots, freshSlots = previous.bags[bagId].slots, fresh.bags[bagId].slots
        local candidates = {}
        for slot in pairs(previousSlots) do candidates[slot] = true end
        for slot in pairs(freshSlots) do candidates[slot] = true end
        for slot in pairs(candidates) do
            local a, b = previousSlots[slot], freshSlots[slot]
            if not a or not b or a.itemData.itemId ~= b.itemData.itemId or a.itemData.count ~= b.itemData.count then
                total = total + 1
                if #lines < 20 then
                    lines[#lines + 1] = string.format("bag %d slot %d previous=%s fresh=%s live=%s replayed=%s",
                        bagId, slot, DescribeSlotRecord(a), DescribeSlotRecord(b),
                        DescribeSlotRecord(this.EvaluateTrackerSlot(bagId, slot, {})),
                        tostring(dirty[bagId] ~= nil and dirty[bagId][slot] == true))
                end
            end
        end
    end
    return lines, total
end

local function AdoptTrackerSlotIndex(slotIndex, freshSnapshot, trackedItems, activeRules, job)
    slotIndex.profile, slotIndex.revision = this.GetTrackerContext()
    slotIndex.runtimeRules, slotIndex.subscriber = this.GetRuntimeRules(), IsESOPlusSubscriber()
    local previous = trackerSlotIndex
    trackerSlotIndex = slotIndex
    if not previous or not previous.incrementallyUpdated or not SlotIndexIsCurrent(previous, activeRules) then return end
    local incremental = this.BuildTrackerSnapshotFromSlotIndex(previous, trackedItems, activeRules)
    local differences = CompareTrackerSnapshots(incremental, freshSnapshot)
    if #differences > 0 then
        local slotLines, slotTotal = DescribeSlotDifferences(previous, slotIndex, job.dirty)
        differences[#differences + 1] = string.format(
            "scan: replayed slots=%d, bankOpen=%s, wallMs=%s, slices=%s, fullUpdateDuringScan=%s, "
                .. "incremental updates applied to previous index=%s (%s slots)",
            CountMarkedSlots(job.dirty), tostring(IsBankOpen()), tostring(job.metrics.wallMs),
            tostring(job.metrics.sliceCount), tostring(job.rerun == true),
            tostring(previous.updateCount), tostring(previous.updatedSlotCount))
        differences[#differences + 1] = string.format("slot differences between previous and fresh index: %d", slotTotal)
        for _, line in ipairs(slotLines) do differences[#differences + 1] = line end
        if this.DiagnosticLog.Event("trackerMismatch", "Incremental tracker differs from a fresh scan", differences) == true then
            this.Utils.UserError("Tracker mismatch logged (TODO F16). Reload the UI, then ask Copilot to analyse the diagnostic log.",
                "Tracker mismatch logged - see TODO F16")
        end
    end
end

local function RenderTrackerDisplayList(items, rules, reason, targetGroup)
    CancelPendingIncrementalRender()
    lastInventoryRenderAt = GetGameTimeMilliseconds()
    local oldLeft, oldTop = GetTrackerCoordinates()
    HideAllTrackerRows()
    local context, revision = this.GetTrackerContext()
    local contextChanged = not previousLayout or previousLayout.context ~= context
        or previousLayout.revision ~= revision
    if contextChanged then previousLayout = nil end
    local _, scrollOffset = GetRowsContainer().scroll:GetScrollOffsets()
    if contextChanged then scrollOffset = 0 end
    if #items == 0 then
        items = { { link = "|c888888No tracked items in backpack|r", count = 0,
            icon = "EsoUI/Art/Buttons/edit_up.dds", isEmpty = true } }
    end
    local budget = math.min(this.GetPanelSettings("Tracker").trackerMaxRows,
        math.max(1, math.floor((GuiRoot:GetHeight() - InventoryCompanion_ItemTrackerFloatTitle:GetHeight() - 12) / 24)))
    local model = BuildLayoutModel(items, rules)
    local expanded, collapsed = ChooseLayout(model, previousLayout, reason, targetGroup, budget)
    local selected = SelectRows(model, expanded)
    local wrapped = false
    if this.GetPanelSettings("Tracker").wrapTrackedItemNames == true and not collapsed and #selected <= budget then
        MeasureWrappedRows(selected)
        local units = 0
        for _, item in ipairs(selected) do units = units + item.rowUnits end
        wrapped = units <= budget
    end
    for _, name in ipairs(model.order) do model.groups[name].expanded = expanded[name] end
    local contentHeight = RenderPopulatedRows(selected, wrapped)
    local target
    for index, item in ipairs(selected) do
        if item.isGroup and reason == "expand" and item.ruleName == targetGroup then target = trackerRows[index] end
    end
    ApplyViewport(contentHeight, budget, wrapped, scrollOffset, target)
    model.context, model.revision, model.budget = context, revision, budget
    previousLayout = model
    ApplyBoundedPosition(oldLeft, oldTop)
end

local function StartSlicedTrackerRefresh(reason, targetGroup)
    CancelPendingIncrementalRender()
    trackerRefreshGeneration = trackerRefreshGeneration + 1
    local generation = trackerRefreshGeneration
    local trackedItems, rules = this.GetActiveTrackedItems(), this.GetActiveTrackedRules()
    local profile, revision = this.GetTrackerContext()
    local runtimeRules = this.GetRuntimeRules()
    local bankOpen, subscriber = IsBankOpen(), IsESOPlusSubscriber()
    local showEmpty = this.GetPanelSettings("Tracker").showEmptyTrackedItems ~= false
    local job = {
        started = GetGameTimeMilliseconds(),
        dirty = {},
        work = { entries = 0, markerIds = {} },
        metrics = { elapsedMs = 0, maxSliceMs = 0, sliceCount = 0,
            targetSliceMs = slicedTrackerBudgetMs, requestedDelayMs = slicedTrackerDelayMs },
    }
    slicedTrackerJob = job
    local checks = 0
    job.work.checkpoint = function()
        checks = checks + 1
        if checks >= 16 then
            checks = 0
            if GetGameTimeMilliseconds() - job.sliceStarted >= slicedTrackerBudgetMs then coroutine.yield() end
        end
    end
    local bagIds = this.GetTrackerBagIdList()
    local worker = coroutine.create(function()
        local snapshot, slotIndex = this.PreparedScanning.GetPreparedMasterItemList(
            trackedItems, rules, bagIds, job.work)
        job.slotIndex = slotIndex
        return snapshot
    end)
    local function Step()
        if slicedTrackerJob ~= job then return end
        local currentProfile, currentRevision = this.GetTrackerContext()
        if currentProfile ~= profile or currentRevision ~= revision or this.GetRuntimeRules() ~= runtimeRules
            or IsBankOpen() ~= bankOpen or IsESOPlusSubscriber() ~= subscriber
            or this.GetPanelSettings("Tracker").showTrackedItemsPanel == false then
            slicedTrackerJob = nil
            this.RefreshItemTrackerPanel("inventory")
            return
        end
        job.sliceStarted = GetGameTimeMilliseconds()
        local ok, snapshot = coroutine.resume(worker)
        local sliceMs = GetGameTimeMilliseconds() - job.sliceStarted
        job.metrics.elapsedMs = job.metrics.elapsedMs + sliceMs
        job.metrics.maxSliceMs = math.max(job.metrics.maxSliceMs, sliceMs)
        job.metrics.sliceCount = job.metrics.sliceCount + 1
        if not ok then
            slicedTrackerJob = nil
            error(snapshot, 0)
        end
        if coroutine.status(worker) ~= "dead" then
            local started = false
            local handle = zo_callLater(function()
                started = true
                job.handle = nil
                Step()
            end, slicedTrackerDelayMs)
            if not started then job.handle = handle end
            return
        end
        slicedTrackerJob = nil
        job.metrics.status = "completed"
        job.metrics.wallMs = GetGameTimeMilliseconds() - job.started
        local slotIndex = job.slotIndex
        job.metrics.dirtySlots = ApplySlotsToIndex(slotIndex, job.dirty, rules)
        if job.metrics.dirtySlots > 0 then
            snapshot = this.BuildTrackerSnapshotFromSlotIndex(slotIndex, trackedItems, rules)
        end
        local previous = trackerSlotIndex
        if previous and SlotIndexIsCurrent(previous, rules) and pendingSlotUpdates then
            local pending = pendingSlotUpdates
            pendingSlotUpdates = {}
            local flushed = ApplySlotsToIndex(previous, pending, rules)
            if flushed > 0 then
                previous.incrementallyUpdated = true
                previous.updateCount = (previous.updateCount or 0) + 1
                previous.updatedSlotCount = (previous.updatedSlotCount or 0) + flushed
            end
        end
        if job.rerun then slotIndex.fullUpdateSeen = true end
        AdoptTrackerSlotIndex(slotIndex, snapshot, trackedItems, rules, job)
        job.metrics.finishMs = GetGameTimeMilliseconds() - job.started - job.metrics.wallMs
        local render = { generation = generation }
        pendingTrackerRender = render
        render.callback = function()
            if pendingTrackerRender ~= render then return end
            pendingTrackerRender = nil
            local renderStartedAt = GetGameTimeMilliseconds()
            if generation == trackerRefreshGeneration and slicedTrackerJob == nil
                and trackerSlotIndex == slotIndex
                and this.GetPanelSettings("Tracker").showTrackedItemsPanel ~= false then
                if slotIndex.updateCount then snapshot = this.BuildTrackerSnapshotFromSlotIndex(slotIndex, trackedItems, rules) end
                RenderTrackerDisplayList(BuildDisplayList(snapshot, rules, trackedItems, showEmpty), rules, reason, targetGroup)
                WatchFCOGroupPriority()
            end
            this.DiagnosticLog.Sample("trackerScan", {
                algorithm = "sliced", status = "completed", scanMs = job.metrics.elapsedMs,
                wallMs = job.metrics.wallMs, maxSliceMs = job.metrics.maxSliceMs,
                sliceCount = job.metrics.sliceCount, targetSliceMs = slicedTrackerBudgetMs,
                requestedDelayMs = slicedTrackerDelayMs, entries = job.work.entries,
                markerCount = #job.work.markerIds, finishMs = job.metrics.finishMs,
            })
            this.DiagnosticLog.Sample("trackerRefresh", {
                reason = tostring(reason), scanMs = job.metrics.elapsedMs,
                renderMs = GetGameTimeMilliseconds() - renderStartedAt,
                rows = job.work.entries, bankOpen = bankOpen,
            })
            if job.rerun then StartSlicedTrackerRefresh("inventory") end
        end
        ScheduleTrackerRender(render)
    end
    local started = false
    local handle = zo_callLater(function()
        started = true
        job.handle = nil
        Step()
    end, 0)
    if not started then job.handle = handle end
end

function this.CancelSlicedTrackerRefresh()
    CancelPendingIncrementalRender()
    trackerRefreshGeneration = trackerRefreshGeneration + 1
    if slicedTrackerJob and slicedTrackerJob.handle then
        zo_removeCallLater(slicedTrackerJob.handle)
        slicedTrackerJob.handle = nil
    end
    if pendingTrackerRender then
        pendingTrackerRender.timerToken = nil
        if pendingTrackerRender.handle then zo_removeCallLater(pendingTrackerRender.handle) end
    end
    pendingTrackerRender = nil
    slicedTrackerJob = nil
end

local function CancelPendingTrackerSlotUpdates()
    if slotUpdateHandle then
        zo_removeCallLater(slotUpdateHandle)
        slotUpdateHandle = nil
    end
    pendingSlotUpdates = {}
    slotUpdateScheduled = false
end

local function QueueIncrementalTrackerRender(slotIndex, scanMs, count)
    if slicedTrackerJob or pendingTrackerRender then return end
    if pendingIncrementalRender and pendingIncrementalRender.slotIndex ~= slotIndex then
        CancelPendingIncrementalRender()
    end
    if pendingIncrementalRender then
        pendingIncrementalRender.scanMs = pendingIncrementalRender.scanMs + scanMs
        pendingIncrementalRender.rows = pendingIncrementalRender.rows + count
        return
    end
    local render = {
        slotIndex = slotIndex, generation = trackerRefreshGeneration,
        scanMs = scanMs, rows = count,
    }
    pendingIncrementalRender = render
    render.callback = function()
        if pendingIncrementalRender ~= render then return end
        pendingIncrementalRender = nil
        if render.generation ~= trackerRefreshGeneration or trackerSlotIndex ~= slotIndex
            or slicedTrackerJob or this.GetPanelSettings("Tracker").showTrackedItemsPanel == false then
            return
        end
        local trackedItems, rules = this.GetActiveTrackedItems(), this.GetActiveTrackedRules()
        if not SlotIndexIsCurrent(slotIndex, rules) then
            trackerSlotIndex = nil
            this.RefreshItemTrackerPanel("inventory")
            return
        end
        local renderStarted = GetGameTimeMilliseconds()
        local snapshot = this.BuildTrackerSnapshotFromSlotIndex(slotIndex, trackedItems, rules)
        local showEmpty = this.GetPanelSettings("Tracker").showEmptyTrackedItems ~= false
        RenderTrackerDisplayList(BuildDisplayList(snapshot, rules, trackedItems, showEmpty), rules, "inventory")
        this.DiagnosticLog.Sample("trackerRefresh", {
            reason = "incremental", scanMs = render.scanMs,
            renderMs = GetGameTimeMilliseconds() - renderStarted,
            rows = render.rows, bankOpen = IsBankOpen(),
        })
    end
    ScheduleTrackerRender(render)
end

local function ApplyTrackerSlotUpdates()
    slotUpdateScheduled = false
    slotUpdateHandle = nil
    local pending = pendingSlotUpdates
    pendingSlotUpdates = {}
    local slotIndex = trackerSlotIndex
    if not slotIndex or this.GetPanelSettings("Tracker").showTrackedItemsPanel == false then return end
    local started = GetGameTimeMilliseconds()
    local rules = this.GetActiveTrackedRules()
    if not SlotIndexIsCurrent(slotIndex, rules) then
        trackerSlotIndex = nil
        this.RefreshItemTrackerPanel("inventory")
        return
    end
    local count = ApplySlotsToIndex(slotIndex, pending, rules)
    if count == 0 then return end
    slotIndex.incrementallyUpdated = true
    slotIndex.updateCount = (slotIndex.updateCount or 0) + 1
    slotIndex.updatedSlotCount = (slotIndex.updatedSlotCount or 0) + count
    QueueIncrementalTrackerRender(slotIndex, GetGameTimeMilliseconds() - started, count)
end

function this.QueueTrackerSlotUpdate(bagId, slotIndex)
    if slicedTrackerJob then MarkSlot(slicedTrackerJob.dirty, bagId, slotIndex) end
    if not trackerSlotIndex then
        if not slicedTrackerJob then this.RefreshItemTrackerPanel("inventory") end
        return
    end
    MarkSlot(pendingSlotUpdates, bagId, slotIndex)
    if not slotUpdateScheduled then
        slotUpdateScheduled = true
        local started = false
        local handle = zo_callLater(function()
            started = true
            slotUpdateHandle = nil
            ApplyTrackerSlotUpdates()
        end, 0)
        if not started then slotUpdateHandle = handle end
    end
end

function this.NoteTrackerFullInventoryUpdate()
    if slicedTrackerJob then slicedTrackerJob.rerun = true
    else this.RefreshItemTrackerPanel("inventory") end
end

local function MarkerPollAllowed()
    if InventoryCompanion_ItemTrackerFloat:IsHidden() then return false end
    local scene = SCENE_MANAGER:GetCurrentScene()
    return scene ~= nil and scene:GetName() ~= "hud"
end

function this.PollTrackerMarkers()
    if this.accountWide.fcoIntegrationState ~= "enabled" then
        this.StopTrackerMarkerPolling()
        return
    end
    local signature = this.FCOItemSaver.GetAvailabilitySignature(this.GetRuntimeRules())
    if signature ~= markerAvailabilitySignature then
        markerAvailabilitySignature = signature
        if markerPollPass and markerPollPass.handle then zo_removeCallLater(markerPollPass.handle) end
        markerPollPass = nil
        this.InvalidateRuleCache()
        this.CancelSlicedTrackerRefresh()
        this.AutoCategoryIntegration.OnFCOAvailabilityChanged()
        this.RefreshGroupsEditor()
        this.RefreshAutoCategoryEditor()
        this.RefreshItemTrackerPanel()
    end
    if not this.FCOItemSaver.IsReady() then return end
    if markerPollPass or not trackerSlotIndex or not MarkerPollAllowed() then return end
    local rules = this.GetActiveTrackedRules()
    if not SlotIndexIsCurrent(trackerSlotIndex, rules) then
        this.RefreshItemTrackerPanel("inventory")
        return
    end
    local slotIndex = trackerSlotIndex
    if #slotIndex.markerIds == 0 then return end
    local pass = {}
    markerPollPass = pass
    local worker = coroutine.create(function()
        local checks = 0
        for _, bagId in ipairs(slotIndex.bagIds) do
            local bag = slotIndex.bags[bagId]
            local position = 1
            while bag.order[position] do
                local slot = bag.order[position]
                local record = bag.slots[slot]
                if record and this.FCOItemSaver.ReadSlotMarkerKey(bagId, slot, slotIndex.markerIds) ~= record.markerKey then
                    this.QueueTrackerSlotUpdate(bagId, slot)
                end
                position = position + 1
                checks = checks + 1
                if checks >= 8 then
                    checks = 0
                    if GetGameTimeMilliseconds() - pass.sliceStarted >= 2 then coroutine.yield() end
                end
            end
        end
    end)
    local function Step()
        if markerPollPass ~= pass then return end
        if trackerSlotIndex ~= slotIndex or not MarkerPollAllowed()
            or this.accountWide.fcoIntegrationState ~= "enabled" then
            markerPollPass = nil
            return
        end
        pass.sliceStarted = GetGameTimeMilliseconds()
        local ok, failure = coroutine.resume(worker)
        if not ok then markerPollPass = nil; error(failure, 0) end
        if coroutine.status(worker) ~= "dead" then
            local started = false
            local handle = zo_callLater(function()
                started = true
                pass.handle = nil
                Step()
            end, slicedTrackerDelayMs)
            if not started then pass.handle = handle end
        else markerPollPass = nil end
    end
    Step()
end

function this.StartTrackerMarkerPolling()
    local updateName = this.Name .. "_FCOItemSaverMarkerPoll"
    if this.accountWide.fcoIntegrationState ~= "enabled" then
        this.StopTrackerMarkerPolling()
        return
    end
    local signature = this.FCOItemSaver.GetAvailabilitySignature(this.GetRuntimeRules())
    if not MarkerPollAllowed() and markerPollPass then
        if markerPollPass.handle then zo_removeCallLater(markerPollPass.handle) end
        markerPollPass = nil
    end
    if markerPollRegistered then return end
    markerAvailabilitySignature = signature
    EVENT_MANAGER:RegisterForUpdate(updateName, 1000, this.PollTrackerMarkers)
    markerPollRegistered = true
end

function this.StopTrackerMarkerPolling()
    if markerPollRegistered then
        EVENT_MANAGER:UnregisterForUpdate(this.Name .. "_FCOItemSaverMarkerPoll")
        markerPollRegistered = false
    end
    if markerPollPass and markerPollPass.handle then
        zo_removeCallLater(markerPollPass.handle)
        markerPollPass.handle = nil
    end
    markerPollPass = nil
    markerAvailabilitySignature = nil
end

function this.SetItemTrackerPanelVisible(visible)
    assert(type(visible) == "boolean", "Tracker visibility must be a boolean")
    this.GetPanelSettings("Tracker").showTrackedItemsPanel = visible
    this.UpdateEventRegistry()
    this.RefreshItemTrackerPanel()
    this.StartTrackerMarkerPolling()
end

function this.ToggleItemTrackerPanel()
    this.SetItemTrackerPanelVisible(this.GetPanelSettings("Tracker").showTrackedItemsPanel == false)
end

function this.RefreshItemTrackerPanel(reason, targetGroup)
    if reason == "inventory" and slicedTrackerJob then return end
    if reason ~= "inventory" then lastInventoryRenderAt = nil end
    local titleSize = this.GetPanelSettings("Tracker").trackerTitleSize
    InventoryCompanion_ItemTrackerFloatTitle:SetFont(string.format("%s|%d|soft-shadow-thin",
        ZoFontGame:GetFontInfo(), titleSize))
    InventoryCompanion_ItemTrackerFloatEditIcon:SetDimensions(titleSize, titleSize)
    InventoryCompanion_ItemTrackerFloatSettingsIcon:SetDimensions(titleSize, titleSize)
    if this.GetPanelSettings("Tracker").showTrackedItemsPanel == false then
        this.CancelSlicedTrackerRefresh()
        CancelPendingTrackerSlotUpdates()
        InventoryCompanion_ItemTrackerFloat:SetHidden(true)
        this.PanelLayout.UpdateVisibility()
        return
    end

    if reason == "inventory" then
        this.CancelSlicedTrackerRefresh()
        StartSlicedTrackerRefresh(reason, targetGroup)
        return
    end
    this.CancelSlicedTrackerRefresh()
    CancelPendingTrackerSlotUpdates()
    local scanStarted = GetGameTimeMilliseconds()
    local oldLeft, oldTop = GetTrackerCoordinates()
    HideAllTrackerRows()

    local context, revision = this.GetTrackerContext()
    local contextChanged = not previousLayout or previousLayout.context ~= context
        or previousLayout.revision ~= revision
    if contextChanged then previousLayout = nil end
    local _, scrollOffset = GetRowsContainer().scroll:GetScrollOffsets()
    if contextChanged then scrollOffset = 0 end
    local items, rules = this.GetTrackerDisplayList()
    local scanFinished = GetGameTimeMilliseconds()
    if #items == 0 then
        items = { { link = "|c888888No tracked items in backpack|r", count = 0,
            icon = "EsoUI/Art/Buttons/edit_up.dds", isEmpty = true } }
    end
    local budget = math.min(this.GetPanelSettings("Tracker").trackerMaxRows,
        math.max(1, math.floor((GuiRoot:GetHeight() - InventoryCompanion_ItemTrackerFloatTitle:GetHeight() - 12) / 24)))
    local model = BuildLayoutModel(items, rules)
    -- Single-line row totals are a lower bound: an overflowing selection cannot fit wrapped.
    local expanded, collapsed = ChooseLayout(model, previousLayout, reason, targetGroup, budget)
    local selected = SelectRows(model, expanded)
    local wrapped = false
    if this.GetPanelSettings("Tracker").wrapTrackedItemNames == true and not collapsed and #selected <= budget then
        MeasureWrappedRows(selected)
        local units = 0
        for _, item in ipairs(selected) do units = units + item.rowUnits end
        wrapped = units <= budget
    end
    for _, name in ipairs(model.order) do
        model.groups[name].expanded = expanded[name]
    end
    local contentHeight = RenderPopulatedRows(selected, wrapped)
    local target = nil
    for index, item in ipairs(selected) do
        if item.isGroup then
            if reason == "expand" and item.ruleName == targetGroup then target = trackerRows[index] end
        end
    end
    ApplyViewport(contentHeight, budget, wrapped, scrollOffset, target)
    model.context, model.revision, model.budget = context, revision, budget
    previousLayout = model
    ApplyBoundedPosition(oldLeft, oldTop)
    this.DiagnosticLog.Sample("trackerRefresh", {
        reason = tostring(reason), scanMs = scanFinished - scanStarted,
        renderMs = GetGameTimeMilliseconds() - scanFinished, rows = #items,
        bankOpen = IsBankOpen(),
    })
end