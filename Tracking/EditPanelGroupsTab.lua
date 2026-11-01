local this = InventoryCompanion

local groupRows = {}
local patternRows = {}
local patternExclusionDivider
local selectedGroupName = nil
local selectedAutoCategoryHeading
local SetActionButtons
local autoCategoryViewActive = false
local autoCategoryContext = "master"
local showNonparticipatingGroups = true
local showAllAutoCategoryHeadings = false
local autoCategorySearch = ""
local autoCategoryModeCombo
local movedAutoCategoryGroup

------------------------------------------------------------------
-- Constants
------------------------------------------------------------------
local constants = {
    newGroupBaseName = "New Group",
	quirkyNameList = {"%s","Another %s", "Yet another %s", "Now you are starting to annoy me"}
}

local function EscapeEsoMarkup(value)
    return value:gsub("|", "||")
end

------------------------------------------------------------------
-- Sanitization & Commit Logic
------------------------------------------------------------------
local function SanitizeGroupName(name)
    -- Trim whitespace
    name = name:match("^%s*(.-)%s*$")
    -- Strip control characters (\0-\31, \127)
    name = name:gsub("[%z\1-\31\127]", "")
    -- Escape pipes (| to ||) to prevent ESO formatting injection
    name = name:gsub("|", "||")
    return name
end

local function GetSortedGroupNames()
    local activeRules = this.GetActiveTrackedRules(true)
    local groupNames = {}
    for name in pairs(activeRules) do
        table.insert(groupNames, name)
    end
	
	table.sort(groupNames, function(a, b)
        local nameA = activeRules[a].displayName
        local nameB = activeRules[b].displayName
        return nameA:lower() < nameB:lower()
    end)
    
    return groupNames, activeRules
end

------------------------------------------------------------------
-- Populate Group List Pane
------------------------------------------------------------------
local function HideAllGroupRows()
    for _, row in ipairs(groupRows) do
        row:SetHidden(true)
    end
end

local function GetOrCreateGroupRow(scrollChild, index)
    local row = groupRows[index]
    if not row then
        row = CreateControlFromVirtual("InventoryCompanion_GroupRow_", scrollChild, "InventoryCompanion_GroupRow_Template", index)
        table.insert(groupRows, row)
    end
    return row
end

local function IsAutoCategoryActive()
    return this.AutoCategoryIntegration.IsAvailable() and this.GetAutoCategoryState().enabled
end

local function ConfigureAutoCategoryToolbar()
    local topBar = GetControl(InventoryCompanion_GroupsWindow, "TopActionBar")
    local btnMode = GetControl(topBar, "BtnAutoCategory")
    local modeControl = GetControl(topBar, "AutoCategoryMode")
    local reset = GetControl(topBar, "BtnResetAutoCategory")
    local newGroup = GetControl(topBar, "BtnNewGroup")
    local autoBar = GetControl(InventoryCompanion_GroupsWindow, "AutoCategoryBar")
    local active = IsAutoCategoryActive()
    if not active then autoCategoryViewActive = false end
    btnMode:SetHidden(not active)
    btnMode:SetText(autoCategoryViewActive and "Groups" or "AutoCategory")
    btnMode:SetHandler("OnClicked", function()
        assert(IsAutoCategoryActive(), "AutoCategory view is no longer available")
        autoCategoryViewActive = not autoCategoryViewActive
        if autoCategoryViewActive then
            local findBox = GetControl(topBar, "FindBox")
            autoCategorySearch = findBox:GetText():lower():match("^%s*(.-)%s*$")
        else
            selectedAutoCategoryHeading = nil
        end
        this.RefreshGroupsEditor()
    end)

    modeControl:SetHidden(not (active and autoCategoryViewActive))
    reset:SetHidden(not (active and autoCategoryViewActive))
    newGroup:SetHidden(active and autoCategoryViewActive)
    autoBar:SetHidden(not (active and autoCategoryViewActive))
    local leftPane = GetControl(InventoryCompanion_GroupsWindow, "LeftPane")
    leftPane:ClearAnchors()
    leftPane:SetAnchor(TOPLEFT, topBar, BOTTOMLEFT, 0,
        autoCategoryViewActive and 42 or 12)

    if not (active and autoCategoryViewActive) then return end

    autoCategoryModeCombo = autoCategoryModeCombo or ZO_ComboBox_ObjectFromContainer(modeControl)
    assert(autoCategoryModeCombo, "AutoCategory editor is missing its context selector")
    autoCategoryModeCombo:SetSortsItems(false)
    autoCategoryModeCombo:ClearItems()
    for _, context in ipairs(this.AutoCategoryIntegration.GetContexts()) do
        local entry = autoCategoryModeCombo:CreateItemEntry(context.title,
            function(_, _, itemData, selectionChanged)
                if selectionChanged and itemData then
                    autoCategoryContext = itemData.key
                    this.RefreshGroupsEditor()
                end
            end)
        entry.key = context.key
        autoCategoryModeCombo:AddItem(entry)
        if context.key == autoCategoryContext then
            autoCategoryModeCombo:SetSelectedItem(context.title)
        end
    end

    local master = autoCategoryContext == "master"
    local showNon = GetControl(autoBar, "ChkShowNonparticipating")
    local showAll = GetControl(autoBar, "ChkShowAllHeadings")
    showNon:SetHidden(not master)
    GetControl(autoBar, "LblShowNonparticipating"):SetHidden(not master)
    ZO_CheckButton_SetCheckState(showNon, showNonparticipatingGroups)
    ZO_CheckButton_SetToggleFunction(showNon, function(_, checked)
        assert(autoCategoryViewActive and autoCategoryContext == "master",
            "Nonparticipating filter callback targets a stale view")
        showNonparticipatingGroups = checked
        this.RefreshGroupsEditor()
    end)
    ZO_CheckButton_SetCheckState(showAll, showAllAutoCategoryHeadings)
    ZO_CheckButton_SetToggleFunction(showAll, function(_, checked)
        assert(autoCategoryViewActive, "Heading filter callback targets a stale view")
        showAllAutoCategoryHeadings = checked
        this.RefreshGroupsEditor()
    end)

    local info = GetControl(autoBar, "Info")
    if autoCategorySearch ~= "" then
        info:SetText("Clear search to move groups.")
    elseif (master and showNonparticipatingGroups) or showAllAutoCategoryHeadings then
        info:SetText("Hide inactive groups and hidden headings to adjust priorities.")
    elseif master then
        info:SetText("Set shared group placements here. Heading labels show where each row applies; elsewhere, groups fall back to the nearest applicable heading.")
    else
        info:SetText("This shows effective order for " .. autoCategoryContext
            .. ". Group matching uses the same IC filters; Master changes flow through unless you override a group here.")
    end
    local resetText = autoCategoryContext == "master" and "Reset" or "Reset to Master"
    reset:SetText(resetText)
    reset:SetHandler("OnClicked", function()
        assert(IsAutoCategoryActive() and autoCategoryViewActive,
            "AutoCategory reset action targets an inactive view")
        if autoCategoryContext == "master" then
            this.AutoCategoryIntegration.ChoosePreset(true)
        else
            this.ResetAutoCategoryContext(autoCategoryContext)
            this.RefreshGroupsEditor()
        end
    end)
    local findBox = GetControl(topBar, "FindBox")
    findBox:SetHandler("OnTextChanged", function(control)
        if autoCategoryViewActive then
            autoCategorySearch = control:GetText():lower():match("^%s*(.-)%s*$")
            this.RefreshGroupsEditor()
        end
    end)
end

local function PopulateGroupRow(row, groupName, index, scrollChild, activeRules)
    local rowHeight = 32
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 0, (index - 1) * rowHeight)
    row:SetHidden(false)

    local isSelected = (groupName == selectedGroupName)
    local nameLabel = GetControl(row, "Name")
    nameLabel:SetWidth(240)
    for _, controlName in ipairs({ "Participation", "Visibility", "MoveUp", "MoveDown" }) do
        GetControl(row, controlName):SetHidden(true)
    end

    local ruleData = activeRules[groupName]
    local displayName = ruleData.displayName

    -- Apply hidden styling (Red text with "(hidden)" suffix)
    if ruleData.display.isHidden == true then
        displayName = string.format("|cFF5252%s (hidden)|r", displayName)
    end

    nameLabel:SetText(displayName)

    -- Styling based on selection state
    if isSelected then
        nameLabel:SetFont("ZoFontGameBold")
        nameLabel:SetColor(0.95, 0.95, 0.95, 1.0)
    else
        nameLabel:SetFont("ZoFontGame")
        nameLabel:SetColor(0.60, 0.60, 0.60, 1.0)
    end

    local bgTex = GetControl(row, "BG")
    bgTex:SetAlpha(isSelected and 0.4 or 0.0)

    -- Mouse handlers for hover and click effects
    row:SetHandler("OnMouseEnter", function()
        if not isSelected then
            nameLabel:SetColor(0.85, 0.85, 0.85, 1.0)
            bgTex:SetAlpha(0.2)
        end
    end)

    row:SetHandler("OnMouseExit", function()
        if not isSelected then
            nameLabel:SetColor(0.60, 0.60, 0.60, 1.0)
            bgTex:SetAlpha(0.0)
        end
    end)

    row:SetHandler("OnMouseDown", function()
        selectedGroupName = groupName
        selectedAutoCategoryHeading = nil
        this.RefreshGroupsEditor()
    end)
end

local function PopulateGroupListPane(groupNames, activeRules)
    HideAllGroupRows()

    local scrollChild = GetControl(InventoryCompanion_GroupsWindowLeftPane, "ScrollChild")
    assert(scrollChild, "Groups editor is missing its group-list ScrollChild")

    if not selectedGroupName or not activeRules[selectedGroupName] then
        selectedGroupName = groupNames[1]
    end

    for index, groupName in ipairs(groupNames) do
        local row = GetOrCreateGroupRow(scrollChild, index)
        PopulateGroupRow(row, groupName, index, scrollChild, activeRules)
    end
end

local function PopulateAutoCategoryListPane(activeRules)
    HideAllGroupRows()
    local scrollChild = GetControl(InventoryCompanion_GroupsWindowLeftPane, "ScrollChild")
    assert(scrollChild, "Groups editor is missing its group-list ScrollChild")
    local rows = this.AutoCategoryIntegration.ResolveAutoCategoryOrder(autoCategoryContext, {
        showNonparticipants = showNonparticipatingGroups,
        showAllHeadings = showAllAutoCategoryHeadings,
    })
    local filtered = {}
    local query = autoCategorySearch
    local selectedHeadingStillVisible = false
    for _, entry in ipairs(rows) do
        local include = entry.kind == "heading"
            or autoCategoryContext == "master" and showNonparticipatingGroups
            or entry.participating
        if include and (query == "" or entry.name:lower():find(query, 1, true)) then
            filtered[#filtered + 1] = entry
            if selectedAutoCategoryHeading
                and entry.kind == "heading"
                and entry.occurrenceId == selectedAutoCategoryHeading.occurrenceId then
                selectedHeadingStillVisible = true
                selectedAutoCategoryHeading = entry
            end
        end
    end
    if selectedAutoCategoryHeading and not selectedHeadingStillVisible then
        selectedAutoCategoryHeading = nil
    end
    local hasSelectedGroup = selectedGroupName and activeRules[selectedGroupName]
    if not hasSelectedGroup then
        selectedGroupName = nil
        for _, entry in ipairs(filtered) do
            if entry.kind == "group" then
                selectedGroupName = entry.ruleKey
                break
            end
        end
    end

    local movesAllowed = autoCategorySearch == ""
        and not showAllAutoCategoryHeadings
        and (autoCategoryContext ~= "master" or not showNonparticipatingGroups)
    local state = this.GetAutoCategoryState()
    for index, entry in ipairs(filtered) do
        local row = GetOrCreateGroupRow(scrollChild, index)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 0, (index - 1) * 32)
        row:SetHidden(false)
        row.autoCategoryEntry = entry
        local selected = entry.kind == "group" and entry.ruleKey == selectedGroupName
            or entry.kind == "heading" and selectedAutoCategoryHeading
                and entry.occurrenceId == selectedAutoCategoryHeading.occurrenceId
        local label = GetControl(row, "Name")
        label:SetWidth(154)
        local bg = GetControl(row, "BG")
        bg:SetAlpha(selected and 0.4 or (entry.kind == "group" and entry.ruleKey == movedAutoCategoryGroup and 0.45 or 0))
        if entry.kind == "heading" then
            label:SetText("|cFFD27FAutoCategory|r " .. EscapeEsoMarkup(entry.name)
                .. "  |cAAAAAA[" .. EscapeEsoMarkup(entry.scopeLabel) .. "]|r")
            label:SetColor(0.9, 0.82, 0.65, 1)
        else
            label:SetText(entry.name)
            local isNonparticipant = not entry.participating
            label:SetColor(isNonparticipant and 0.48 or (selected and 0.95 or 0.7),
                isNonparticipant and 0.48 or (selected and 0.95 or 0.7),
                isNonparticipant and 0.48 or (selected and 0.95 or 0.7), 1)
        end
        row:SetHandler("OnMouseEnter", function()
            if not selected then bg:SetAlpha(0.2) end
        end)
        row:SetHandler("OnMouseExit", function()
            bg:SetAlpha(selected and 0.4 or (entry.kind == "group" and entry.ruleKey == movedAutoCategoryGroup and 0.45 or 0))
        end)
        row:SetHandler("OnMouseDown", function()
            assert(row.autoCategoryEntry == entry and IsAutoCategoryActive(),
                "AutoCategory row selection targets stale data")
            if entry.kind == "group" then
                selectedGroupName = entry.ruleKey
                selectedAutoCategoryHeading = nil
            else
                selectedAutoCategoryHeading = entry
            end
            this.RefreshGroupsEditor()
        end)

        local participation = GetControl(row, "Participation")
        local visibility = GetControl(row, "Visibility")
        local moveUp, moveDown = GetControl(row, "MoveUp"), GetControl(row, "MoveDown")
        local contextAtRender = autoCategoryContext
        participation:SetHidden(not (autoCategoryContext == "master" and entry.kind == "group"))
        visibility:SetHidden(entry.kind ~= "heading")
        moveUp:SetHidden(not (movesAllowed and entry.kind == "group" and entry.participating))
        moveDown:SetHidden(not (movesAllowed and entry.kind == "group" and entry.participating))

        if entry.kind == "group" and autoCategoryContext == "master" then
            local checkLabel = GetControl(participation, "Label")
            checkLabel:SetHidden(true)
            ZO_CheckButton_SetCheckState(participation, entry.participating)
            ZO_CheckButton_SetToggleFunction(participation, function(_, enabled)
                assert(row.autoCategoryEntry == entry and autoCategoryContext == "master"
                    and IsAutoCategoryActive(), "AutoCategory participation action targets a stale row")
                this.SetAutoCategoryParticipation(entry.ruleKey, enabled)
                this.RefreshGroupsEditor()
                this.RefreshTrackedItemsEditor()
            end)
            participation:SetHandler("OnMouseEnter", function(control)
                InitializeTooltip(InformationTooltip, control, RIGHT, -4, 0)
                InformationTooltip:AddLine("Participation applies across all AutoCategory contexts.")
            end)
            participation:SetHandler("OnMouseExit", function()
                ClearTooltip(InformationTooltip)
            end)
        end
        if entry.kind == "heading" then
            local visibilityLabel = GetControl(visibility, "Label")
            visibilityLabel:SetHidden(true)
            local isVisible
            if autoCategoryContext == "master" then
                isVisible = not (state.order.headingVisibility
                    and state.order.headingVisibility[entry.occurrenceId] == false)
            else
                isVisible = not entry.hidden
            end
            ZO_CheckButton_SetCheckState(visibility, isVisible)
            ZO_CheckButton_SetToggleFunction(visibility, function(_, visible)
                assert(row.autoCategoryEntry == entry and IsAutoCategoryActive()
                    and autoCategoryContext == contextAtRender,
                    "AutoCategory heading action targets a stale row")
                this.SetAutoCategoryHeadingVisibility(contextAtRender, entry.occurrenceId, visible)
                this.RefreshGroupsEditor()
            end)
        end
        if entry.kind == "group" and entry.participating and movesAllowed then
            local canMoveUp = index > 1
            local canMoveDown = index < #filtered
            moveUp:SetEnabled(canMoveUp)
            moveDown:SetEnabled(canMoveDown)
            local function Move(direction)
                assert(row.autoCategoryEntry == entry and IsAutoCategoryActive()
                    and autoCategoryViewActive and autoCategoryContext == contextAtRender
                    and autoCategorySearch == "" and not showAllAutoCategoryHeadings
                    and (autoCategoryContext ~= "master" or not showNonparticipatingGroups),
                    "AutoCategory move action targets a stale or expanded view")
                if direction < 0 and not canMoveUp or direction > 0 and not canMoveDown then return end
                this.AutoCategoryIntegration.MoveGroup(entry.ruleKey, autoCategoryContext, direction)
                movedAutoCategoryGroup = entry.ruleKey
                if SOUNDS and SOUNDS.MENU_BAR_CLICK then PlaySound(SOUNDS.MENU_BAR_CLICK) end
                this.RefreshGroupsEditor()
            end
            moveUp:SetHandler("OnClicked", function() Move(-1) end)
            moveDown:SetHandler("OnClicked", function() Move(1) end)
            moveUp:SetHandler("OnMouseEnter", function(control)
                InitializeTooltip(InformationTooltip, control, RIGHT, -4, 0)
                InformationTooltip:AddLine("Move this group up.")
            end)
            moveDown:SetHandler("OnMouseEnter", function(control)
                InitializeTooltip(InformationTooltip, control, RIGHT, -4, 0)
                InformationTooltip:AddLine("Move this group down.")
            end)
            moveUp:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
            moveDown:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        end
    end
    if #filtered == 0 then selectedAutoCategoryHeading = nil end
end

------------------------------------------------------------------
-- Group Name Editing
------------------------------------------------------------------
local function GetQuirkyDefaultNames()
    local base = constants.newGroupBaseName
    local names = {}
    for _, pattern in ipairs(constants.quirkyNameList) do
        if pattern:find("%%s") then
            table.insert(names, string.format(pattern, base))
        else
            table.insert(names, pattern)
        end
    end
    return names
end

local function DoesGroupNameExist(targetName, excludeKey)
    local activeRules = this.GetActiveTrackedRules(true)
    for key, rule in pairs(activeRules) do
        if key ~= excludeKey and rule.displayName:lower() == targetName:lower() then
            return true
        end
    end
    return false
end

local function GenerateUniqueGroupName(baseName, excludeKey)
    baseName = baseName or constants.newGroupBaseName

    if baseName ~= constants.newGroupBaseName and baseName ~= "" then
        if not DoesGroupNameExist(baseName, excludeKey) then
            return baseName
        end
        
        local counter = 2
        while true do
            local candidate = string.format("%s %d", baseName, counter)
            if not DoesGroupNameExist(candidate, excludeKey) then
                return candidate
            end
            counter = counter + 1
        end
    end

    local quirkyNames = GetQuirkyDefaultNames()
    for _, name in ipairs(quirkyNames) do
        if not DoesGroupNameExist(name, excludeKey) then
            return name
        end
    end

    local counter = 5
    while true do
        local candidate = string.format("%s %d", constants.newGroupBaseName, counter)
        if not DoesGroupNameExist(candidate, excludeKey) then
            return candidate
        end
        counter = counter + 1
    end
end

local function CommitGroupNameEdit(editBox, titleLabel, pencilBtn)
    local rawText = editBox:GetText()
    local sanitized = SanitizeGroupName(rawText)

    if sanitized == "" then
        this.Utils.UserWarning("Group name cannot be empty. Changes reverted.")
        editBox:SetHidden(true)
        titleLabel:SetHidden(false)
        pencilBtn:SetHidden(false)
        this.RefreshGroupsEditor()
        return
    end

    local finalName = GenerateUniqueGroupName(sanitized, selectedGroupName)

    if finalName ~= sanitized then
        this.Utils.UserMessage(string.format("Group name already exists. Automatically renamed to '%s'.", finalName))
    end

    this.UpdateRuleProperty(selectedGroupName, "displayName", finalName)

    editBox:SetHidden(true)
    titleLabel:SetHidden(false)
    pencilBtn:SetHidden(false)
    this.RefreshGroupsEditor()
    this.RefreshItemTrackerPanel()
end

local function HandlePencilClick(titleLabel, pencilBtn, editBox, activeRules)
    local ruleData = activeRules[selectedGroupName]
    local displayName = ruleData.displayName

    editBox:SetText(displayName)
    titleLabel:SetHidden(true)
    pencilBtn:SetHidden(true)
    editBox:SetHidden(false)
    editBox:TakeFocus()
end

------------------------------------------------------------------
-- PopulateSingleGroupPane (Pattern Helpers & Handlers)
------------------------------------------------------------------
local function HideAllPatternRows()
    for _, row in ipairs(patternRows) do
        row:SetHidden(true)
    end
    if patternExclusionDivider then patternExclusionDivider:SetHidden(true) end
end

local function GetOrCreatePatternRow(scrollChild, index)
    local row = patternRows[index]
    if not row then
        row = CreateControlFromVirtual("InventoryCompanion_PatternEditRow_", scrollChild, "InventoryCompanion_PatternEditRow_Template", index)
        table.insert(patternRows, row)
    end
    return row
end

local function GetOrCreatePatternExclusionDivider(scrollChild)
    if not patternExclusionDivider then
        patternExclusionDivider = CreateControlFromVirtual(
            "InventoryCompanion_PatternExclusionDivider_", scrollChild,
            "InventoryCompanion_PatternExclusionDivider_Template", 1)
    end
    return patternExclusionDivider
end

local function DecodePatternRows(patterns)
    local includes, excludes = {}, {}
    local suffix = this.constants.RULE_PATTERN_EXCLUSION_SUFFIX
    for _, storedPattern in ipairs(patterns) do
        local isExclusion = storedPattern:sub(-#suffix) == suffix
        local pattern = isExclusion and storedPattern:sub(1, #storedPattern - #suffix) or storedPattern
        table.insert(isExclusion and excludes or includes, {
            pattern = pattern,
            isExclusion = isExclusion,
            lastSavedPattern = pattern,
        })
    end
    for _, row in ipairs(excludes) do table.insert(includes, row) end
    return includes, #includes - #excludes
end

local function EncodePatternRows(rows)
    local patterns = {}
    local suffix = this.constants.RULE_PATTERN_EXCLUSION_SUFFIX
    for _, row in ipairs(rows) do
        assert(type(row.pattern) == "string", "Pattern row text must be a string")
        assert(row.pattern:sub(-#suffix) ~= suffix, "Pattern text cannot end with the reserved exclusion marker")
        table.insert(patterns, row.pattern .. (row.isExclusion and suffix or ""))
    end
    return patterns
end

local function SaveRulePatterns(groupName, rows)
    this.UpdateRulePatterns(groupName, EncodePatternRows(rows))
    for _, row in ipairs(rows) do row.lastSavedPattern = row.pattern end
end

local function HandlePatternTextChanged(self, row)
    row.pattern = self:GetText()
end

local function HandlePatternFocusLost(self, row, rows, targetGroup)
    local pattern = self:GetText()
    local suffix = this.constants.RULE_PATTERN_EXCLUSION_SUFFIX
    if pattern:sub(-#suffix) == suffix then
        this.Utils.UserWarning("Pattern text cannot end with the reserved exclusion marker.")
        row.pattern = row.lastSavedPattern
        self:SetText(row.pattern)
        return
    end
    row.pattern = pattern

    if targetGroup == selectedGroupName then
        SaveRulePatterns(targetGroup, rows)
        this.RefreshItemTrackerPanel()
        SetActionButtons(this.GetActiveTrackedRules(true))
    end
end

local function HandlePatternDelete(rows, index, targetGroup)
    table.remove(rows, index)
    SaveRulePatterns(targetGroup, rows)
    this.RefreshGroupsEditor()
    this.RefreshItemTrackerPanel()
end

local function HandleAddRule(rows, targetGroup)
    table.insert(rows, { pattern = "", isExclusion = false, lastSavedPattern = "" })
    SaveRulePatterns(targetGroup, rows)
    this.RefreshGroupsEditor()
end

local function SetPatternKindLabel(label, isExclusion)
    if isExclusion then
        label:SetTexture("EsoUI/Art/Bank/bank_tabicon_withdraw_up.dds")
        label:SetColor(1.0, 0.3, 0.3, 1.0)
    else
        label:SetTexture("EsoUI/Art/Bank/bank_tabicon_deposit_up.dds")
        label:SetColor(0.2, 0.8, 0.4, 1.0)
    end
end

local function ShowPatternKindTooltip(control, row, isAction)
    InitializeTooltip(InformationTooltip, control, TOP, 0, -5)
    if isAction then
        InformationTooltip:AddLine(row.isExclusion and "Make this an Include rule" or "Make this an Exclude rule",
            "ZoFontGame", 1, 1, 1, 1)
        InformationTooltip:AddLine(row.isExclusion
            and "The pattern will move above the Exclusions section."
            or "The pattern will move to the Exclusions section below.",
            "ZoFontGame", 0.8, 0.8, 0.8, 1)
    else
        InformationTooltip:AddLine(row.isExclusion and "Exclude rule" or "Include rule",
            "ZoFontGame", 1, 1, 1, 1)
        InformationTooltip:AddLine(row.isExclusion
            and "This pattern removes matching items from this group."
            or "Matching this pattern adds an item to this group.",
            "ZoFontGame", 0.8, 0.8, 0.8, 1)
    end
end

local function ShowPatternDeleteTooltip(control, row)
    InitializeTooltip(InformationTooltip, control, TOP, 0, -5)
    InformationTooltip:AddLine("Remove pattern", "ZoFontGame", 1, 1, 1, 1)
    InformationTooltip:AddLine("Remove this " .. (row.isExclusion and "Exclude" or "Include")
        .. " rule from the group.", "ZoFontGame", 0.8, 0.8, 0.8, 1)
end

local function HandlePatternKindToggle(label, row, rows, targetGroup)
    row.isExclusion = not row.isExclusion
    SetPatternKindLabel(label, row.isExclusion)
    if targetGroup == selectedGroupName then
        SaveRulePatterns(targetGroup, rows)
        this.RefreshGroupsEditor()
        this.RefreshItemTrackerPanel()
    end
end

local function ConfigureCustomGroupActionBar(btnReset, btnHide, btnDelete, actionBar, groupId, activeRules, isHidden)
    btnReset:SetHidden(true)
    
    -- Show and position the Hide/Unhide button on the far left
    btnHide:SetHidden(false)
    btnHide:ClearAnchors()
    btnHide:SetAnchor(TOPLEFT, actionBar, TOPLEFT, 0, 0)
    
    if isHidden then
        btnHide:SetText("Unhide Group")
        btnHide:SetHandler("OnClicked", function()
            this.SetRuleFlag(groupId, "isHidden", false)
            this.RefreshGroupsEditor()
            this.RefreshItemTrackerPanel()
        end)
    else
        btnHide:SetText("Hide Group")
        btnHide:SetHandler("OnClicked", function()
            this.SetRuleFlag(groupId, "isHidden", true)
            this.RefreshGroupsEditor()
            this.RefreshItemTrackerPanel()
        end)
    end

    -- Show and position the Delete button to the right of the Hide button
    btnDelete:SetHidden(false)
    btnDelete:ClearAnchors()
    btnDelete:SetAnchor(TOPLEFT, btnHide, TOPRIGHT, 10, 0)
    btnDelete:SetHandler("OnClicked", function()
        local ruleData = activeRules[groupId]
        local displayName = ruleData.displayName

        ZO_Dialogs_ShowDialog("InventoryCompanion_CONFIRM_DELETE_GROUP_DIALOG", {
            groupId = groupId,
            groupName = displayName,
        })
    end)
end

local function ConfigurePreloadedHideButton(btnHide, groupId, isHidden)
    btnHide:SetHidden(false)
    if isHidden then
        btnHide:SetText("Unhide Group")
        btnHide:SetHandler("OnClicked", function()
            this.SetRuleFlag(groupId, "isHidden", false)
            this.RefreshGroupsEditor()
            this.RefreshItemTrackerPanel()
        end)
    else
        btnHide:SetText("Hide Group")
        btnHide:SetHandler("OnClicked", function()
            this.SetRuleFlag(groupId, "isHidden", true)
            this.RefreshGroupsEditor()
            this.RefreshItemTrackerPanel()
        end)
    end
end

local function ConfigurePreloadedResetButton(btnReset, btnHide, actionBar, hasOverride, groupId, activeRules)
    if hasOverride then
        btnReset:SetHidden(false)
        btnReset:ClearAnchors()
        btnReset:SetAnchor(TOPLEFT, actionBar, TOPLEFT, 0, 0)

        btnHide:ClearAnchors()
        btnHide:SetAnchor(TOPLEFT, btnReset, TOPRIGHT, 10, 0)

        btnReset:SetHandler("OnClicked", function()
            local ruleData = activeRules[groupId]
            local displayName = ruleData.displayName

            ZO_Dialogs_ShowDialog("InventoryCompanion_CONFIRM_RESET_GROUP_DIALOG", {
                groupId = groupId,
                groupName = displayName,
            })
        end)
    else
        btnReset:SetHidden(true)
        btnHide:ClearAnchors()
        btnHide:SetAnchor(TOPLEFT, actionBar, TOPLEFT, 0, 0)
    end
end

SetActionButtons = function(activeRules)
    local rightPane = InventoryCompanion_GroupsWindowRightPane
    local actionBar = GetControl(rightPane, "ActionBar")
    local btnReset = GetControl(actionBar, "BtnReset")
    local btnHide = GetControl(actionBar, "BtnHide")
    local btnDelete = GetControl(actionBar, "BtnDelete")

    local groupId = selectedGroupName
    if autoCategoryViewActive and selectedAutoCategoryHeading then
        btnReset:SetHidden(true)
        btnHide:SetHidden(true)
        btnDelete:SetHidden(true)
        btnReset:SetHandler("OnClicked", nil)
        btnHide:SetHandler("OnClicked", nil)
        btnDelete:SetHandler("OnClicked", nil)
        return
    end
    
    -- Miscellaneous can never be hidden or deleted.
    if groupId == "miscellaneous" then
        btnHide:SetHidden(true)
        btnDelete:SetHidden(true)
        
        local hasOverride = this.HasResettableRuleOverrides(groupId)
        if hasOverride then
            btnReset:SetHidden(false)
            btnReset:ClearAnchors()
            btnReset:SetAnchor(TOPLEFT, actionBar, TOPLEFT, 0, 0)
            btnReset:SetHandler("OnClicked", function()
                local ruleData = activeRules[groupId]
                local displayName = ruleData.displayName

                ZO_Dialogs_ShowDialog("InventoryCompanion_CONFIRM_RESET_GROUP_DIALOG", {
                    groupId = groupId,
                    groupName = displayName,
                })
            end)
        else
            btnReset:SetHidden(true)
        end
        return
    end

    local basePreloaded = this.preLoadedRulesets[groupId]
    local hasOverride = this.HasResettableRuleOverrides(groupId)

    local ruleData = activeRules[groupId]
    local isHidden = ruleData.display.isHidden == true

    if not basePreloaded then
		ConfigureCustomGroupActionBar(btnReset, btnHide, btnDelete, actionBar, groupId, activeRules, isHidden)
    else
        btnDelete:SetHidden(true)
        ConfigurePreloadedHideButton(btnHide, groupId, isHidden)
        ConfigurePreloadedResetButton(btnReset, btnHide, actionBar, hasOverride, groupId, activeRules)
    end	
end

local function PopulateSingleGroupPane(activeRules)
    local rightPane = InventoryCompanion_GroupsWindowRightPane
    local titleLabel = GetControl(rightPane, "GroupTitleLabel")
    local editBox = GetControl(rightPane, "GroupEditBox")
    local pencilBtn = GetControl(rightPane, "BtnEditGroupName")
    local descLabel = GetControl(rightPane, "DescriptionLabel")
    local headingDetails = GetControl(rightPane, "AutoCategoryHeadingDetails")
    local patternScrollContainer = GetControl(rightPane, "PatternScrollContainer")
    local btnAddRule = GetControl(rightPane, "BtnAddRule")

    headingDetails:SetHidden(true)
    if autoCategoryViewActive and selectedAutoCategoryHeading then
        editBox:SetHidden(true)
        titleLabel:SetHidden(false)
        pencilBtn:SetHidden(true)
        patternScrollContainer:SetHidden(true)
        btnAddRule:SetHidden(true)
        descLabel:SetHidden(true)
        HideAllPatternRows()
        titleLabel:SetText("AutoCategory heading: " .. EscapeEsoMarkup(selectedAutoCategoryHeading.name))
        local details = this.AutoCategoryIntegration.GetHeadingDetails(selectedAutoCategoryHeading.name)
        headingDetails:SetText(details and ("AutoCategory filter: " .. EscapeEsoMarkup(details.rule))
            or "This AutoCategory heading is no longer available. Refresh the editor to use the current heading list.")
        headingDetails:SetHidden(false)
        return
    end
    if not selectedGroupName then return end

    editBox:SetHidden(true)
    titleLabel:SetHidden(false)
    pencilBtn:SetHidden(false)

    local ruleData = activeRules[selectedGroupName]
    local displayName = ruleData.displayName

    if selectedGroupName == "miscellaneous" then
        titleLabel:SetText(string.format("Group Name: %s (Special Group)", displayName))

        patternScrollContainer:SetHidden(true)
        btnAddRule:SetHidden(true)
        HideAllPatternRows()

        descLabel:SetText("This is a special catch-all group which collects items not matched by any other active group. It does not use custom pattern rules, but you can customize its display name above.")
        descLabel:SetHidden(false)
    else
        descLabel:SetHidden(true)
        patternScrollContainer:SetHidden(false)
        btnAddRule:SetHidden(false)

        local rows, includeCount = DecodePatternRows(ruleData.patterns)

        titleLabel:SetText(string.format("Group Name: %s (%d patterns/rules)", displayName, #rows))

        HideAllPatternRows()
        local patternScrollChild = GetControl(patternScrollContainer, "ScrollChild")
        local rowHeight = 36
        local offsetY = 0
        for i, patternRow in ipairs(rows) do
            if includeCount > 0 and i == includeCount + 1 then
                local divider = GetOrCreatePatternExclusionDivider(patternScrollChild)
                divider:ClearAnchors()
                divider:SetAnchor(TOPLEFT, patternScrollChild, TOPLEFT, 0, offsetY)
                divider:SetHidden(false)
                offsetY = offsetY + 28
            end
            local row = GetOrCreatePatternRow(patternScrollChild, i)
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, patternScrollChild, TOPLEFT, 0, offsetY)
            row:SetHidden(false)
            offsetY = offsetY + rowHeight

            local rowEditBox = GetControl(row, "Edit")
            rowEditBox:SetHandler("OnTextChanged", nil)
            rowEditBox:SetHandler("OnFocusLost", nil)
            rowEditBox:SetText(patternRow.pattern)
            
            local targetGroup = selectedGroupName

            rowEditBox:SetHandler("OnTextChanged", function(self) HandlePatternTextChanged(self, patternRow) end)
            rowEditBox:SetHandler("OnFocusLost", function(self)
                HandlePatternFocusLost(self, patternRow, rows, targetGroup)
            end)

            local lblKind = GetControl(row, "LblKind")
            SetPatternKindLabel(lblKind, patternRow.isExclusion)
            lblKind:SetHandler("OnMouseEnter", function(self)
                ShowPatternKindTooltip(self, patternRow, false)
            end)
            lblKind:SetHandler("OnMouseExit", function()
                ClearTooltip(InformationTooltip)
            end)
            local btnKind = GetControl(row, "BtnKind")
            btnKind:SetNormalTexture("EsoUI/Art/CharacterWindow/swap_button_up.dds")
            btnKind:SetPressedTexture("EsoUI/Art/CharacterWindow/swap_button_down.dds")
            btnKind:SetMouseOverTexture("EsoUI/Art/CharacterWindow/swap_button_over.dds")
            btnKind:SetDisabledTexture("EsoUI/Art/CharacterWindow/swap_button_disabled.dds")
            btnKind:SetHandler("OnClicked", function()
                ClearTooltip(InformationTooltip)
                HandlePatternKindToggle(lblKind, patternRow, rows, targetGroup)
            end)
            btnKind:SetHandler("OnMouseEnter", function(self)
                ShowPatternKindTooltip(self, patternRow, true)
            end)
            btnKind:SetHandler("OnMouseExit", function()
                ClearTooltip(InformationTooltip)
            end)

            local btnDelete = GetControl(row, "BtnDelete")
            btnDelete:SetHandler("OnClicked", function() HandlePatternDelete(rows, i, targetGroup) end)
            btnDelete:SetHandler("OnMouseEnter", function(self)
                ShowPatternDeleteTooltip(self, patternRow)
            end)
            btnDelete:SetHandler("OnMouseExit", function()
                ClearTooltip(InformationTooltip)
            end)
        end

        btnAddRule:SetHandler("OnClicked", function() HandleAddRule(rows, selectedGroupName) end)
    end

    pencilBtn:SetHandler("OnClicked", function() HandlePencilClick(titleLabel, pencilBtn, editBox, activeRules) end)
    editBox:SetHandler("OnFocusLost", function() CommitGroupNameEdit(editBox, titleLabel, pencilBtn) end)
    editBox:SetHandler("OnEnter", function(self)
        self:LoseFocus()
        CommitGroupNameEdit(editBox, titleLabel, pencilBtn)
    end)
end

------------------------------------------------------------------
--	Refresh Groups Editor
------------------------------------------------------------------
local function InitEditItemsButton()
    local btnEditItems = GetControl(InventoryCompanion_GroupsWindow, "BtnEditItems")
	btnEditItems:SetHandler("OnClicked", function() this.OpenEditItemsPanel() end)
end

local function InitNewGroupButton()
    local topBar = GetControl(InventoryCompanion_GroupsWindow, "TopActionBar")
    local btnNewGroup = GetControl(topBar, "BtnNewGroup")
    
    btnNewGroup:SetHandler("OnClicked", function()
        local timestampKey = string.format("custom_%d", GetGameTimeMilliseconds())
        local uniqueDisplayName = GenerateUniqueGroupName(nil, nil)
        
        this.CreateCustomRule(timestampKey, uniqueDisplayName)
        
        selectedGroupName = timestampKey
        this.RefreshGroupsEditor()

        local rightPane = InventoryCompanion_GroupsWindowRightPane
        local titleLabel = GetControl(rightPane, "GroupTitleLabel")
        local editBox = GetControl(rightPane, "GroupEditBox")
        local pencilBtn = GetControl(rightPane, "BtnEditGroupName")

        editBox:SetText(uniqueDisplayName)
        titleLabel:SetHidden(true)
        pencilBtn:SetHidden(true)
        editBox:SetHidden(false)
        editBox:TakeFocus()
        editBox:SelectAll()

        this.RefreshItemTrackerPanel()
    end)
end

local function InitToolbar()
    InitEditItemsButton()
    InitNewGroupButton()
    ConfigureAutoCategoryToolbar()
end

function this.RefreshGroupsEditor()
    InitToolbar()

    local groupNames, activeRules = GetSortedGroupNames()
    if autoCategoryViewActive and IsAutoCategoryActive() then
        PopulateAutoCategoryListPane(activeRules)
    else
        selectedAutoCategoryHeading = nil
        PopulateGroupListPane(groupNames, activeRules)
    end
    PopulateSingleGroupPane(activeRules)
	SetActionButtons(activeRules)
    this.UpdateEventRegistry()
end

------------------------------------------------------------------
-- Scene Integration & Endpoints
------------------------------------------------------------------
local groupsScene = ZO_Scene:New("InventoryCompanion_GroupsScene", SCENE_MANAGER)
groupsScene:AddFragment(ZO_FadeSceneFragment:New(InventoryCompanion_GroupsWindow))

--these don't seem to ever fire...
groupsScene:RegisterCallback(SCENE_SHOWING, function()
    SetGameCameraUIMode(true)
    this.RefreshGroupsEditor()
	this.UpdateEditorLayout()
end)

groupsScene:RegisterCallback(SCENE_HIDDEN, function()
    SetGameCameraUIMode(false)
	this.UpdateEditorLayout()
end)

-- ...so I put these in
InventoryCompanion_GroupsWindow:SetHandler("OnEffectivelyShown", function()
    SetGameCameraUIMode(true)
    this.RefreshGroupsEditor()
    this.UpdateEditorLayout()
end)

InventoryCompanion_GroupsWindow:SetHandler("OnEffectivelyHidden", function()
    SetGameCameraUIMode(false)
    this.UpdateEditorLayout()
end)
------------------------------------------------------------------
-- Custom Confirmation Dialog Registrations
------------------------------------------------------------------
local function DoDeleteGroup(dialog)
    local data = dialog.data
    this.DeleteCustomRule(data.groupId)
    selectedGroupName = nil
    this.RefreshGroupsEditor()
    this.RefreshItemTrackerPanel()
    
    zo_callLater(function() SetGameCameraUIMode(true) end, 50)
end

local function DoResetGroup(dialog)
    -- Support dialog.data being either a table with .groupId or a direct string key
    local groupId = type(dialog.data) == "table" and dialog.data.groupId or dialog.data
    assert(type(groupId) == "string" and groupId ~= "", "Reset dialog requires a group ID")
    
    this.ResetRule(groupId)
    
    this.RefreshGroupsEditor()
    this.RefreshItemTrackerPanel()
    
    zo_callLater(function() SetGameCameraUIMode(true) end, 50)
end

ZO_Dialogs_RegisterCustomDialog("InventoryCompanion_CONFIRM_DELETE_GROUP_DIALOG", {
    gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
    title = { text = "Confirm Group Deletion" },
    mainText = {
        text = function(dialog)
            local data = dialog.data
            return string.format(
                "Are you sure you want to delete the custom group '%s'?\n\n|cFF5252This action cannot be undone.|r",
                data.groupName
            )
        end
    },
    buttons = {
        [1] = {
            text = "Delete",
            callback = DoDeleteGroup
        },
        [2] = {
            text = SI_DIALOG_CANCEL,
            callback = function(dialog)
                zo_callLater(function() SetGameCameraUIMode(true) end, 50)
            end
        }
    }
})

ZO_Dialogs_RegisterCustomDialog("InventoryCompanion_CONFIRM_RESET_GROUP_DIALOG", {
    gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
    title = { text = "Confirm Group Reset" },
    mainText = {
        text = function(dialog)
            local data = dialog.data
            return string.format(
                "Are you sure you want to reset the name and patterns for '%s' to their defaults?\n\n|cFF5252Its custom name and pattern edits will be cleared. Display settings will be kept.|r",
                data.groupName
            )
        end
    },
    buttons = {
        [1] = {
            text = "Reset",
            callback = DoResetGroup
        },
        [2] = {
            text = SI_DIALOG_CANCEL,
            callback = function(dialog)
                zo_callLater(function() SetGameCameraUIMode(true) end, 50)
            end
        }
    }
})