local this = InventoryCompanion

local rows = {}
local selectedGroup
local selectedHeading
local movedGroup
local context = "master"
local showNonparticipatingGroups = true
local showAllHeadings = false
local searchQuery = ""
local contextCombo

local ROW_HEIGHT = 32

local function EscapeEsoMarkup(value)
    return value:gsub("|", "||")
end

local function Window(name)
    return GetControl(InventoryCompanion_AutoCategoryWindow, name)
end

local function IsActive()
    return this.AutoCategoryIntegration.IsEditorActive()
end

local function AssertCurrentView(contextAtRender)
    assert(IsActive() and context == contextAtRender, "AutoCategory editor action targets a stale view")
end

local function MovesAllowed()
    return searchQuery == ""
        and not showAllHeadings
        and (context ~= "master" or not showNonparticipatingGroups)
end

local function ShowTooltip(control, text)
    InitializeTooltip(InformationTooltip, control, RIGHT, -4, 0)
    InformationTooltip:AddLine(text)
end

local function HideTooltip()
    ClearTooltip(InformationTooltip)
end

local function BindCheckLabel(label, check)
    label:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then ZO_CheckButton_OnClicked(check) end
    end)
end

------------------------------------------------------------------
-- Toolbar
------------------------------------------------------------------
local function ConfigureContextCombo()
    contextCombo = contextCombo or ZO_ComboBox_ObjectFromContainer(GetControl(Window("TopActionBar"), "ContextMode"))
    assert(contextCombo, "AutoCategory editor is missing its context selector")
    contextCombo:SetSortsItems(false)
    contextCombo:ClearItems()
    for _, entryContext in ipairs(this.AutoCategoryIntegration.GetContexts()) do
        local entry = contextCombo:CreateItemEntry(entryContext.title,
            function(_, _, itemData, selectionChanged)
                if selectionChanged and itemData then
                    context = itemData.key
                    selectedHeading = nil
                    this.RefreshAutoCategoryEditor()
                end
            end)
        entry.key = entryContext.key
        contextCombo:AddItem(entry)
        if entryContext.key == context then
            contextCombo:SetSelectedItem(entryContext.title)
        end
    end
end

local function ConfigureToolbar()
    local topBar = Window("TopActionBar")
    local optionsBar = Window("OptionsBar")
    local master = context == "master"

    local findBox = GetControl(topBar, "FindBox")
    findBox:SetHandler("OnTextChanged", function(control)
        searchQuery = control:GetText():lower():match("^%s*(.-)%s*$")
        this.RefreshAutoCategoryEditor()
    end)

    ConfigureContextCombo()

    local reset = GetControl(topBar, "BtnReset")
    reset:SetText(master and "Reset" or "Reset to Master")
    reset:SetHandler("OnClicked", function()
        assert(IsActive(), "AutoCategory reset action targets an inactive integration")
        if context == "master" then
            this.AutoCategoryIntegration.ChoosePreset(true)
        else
            this.ResetAutoCategoryContext(context)
            this.RefreshAutoCategoryEditor()
        end
    end)

    local showNon = GetControl(optionsBar, "ChkShowNonparticipating")
    local showNonLabel = GetControl(optionsBar, "LblShowNonparticipating")
    showNon:SetHidden(not master)
    showNonLabel:SetHidden(not master)
    ZO_CheckButton_SetCheckState(showNon, showNonparticipatingGroups)
    ZO_CheckButton_SetToggleFunction(showNon, function(_, checked)
        assert(context == "master", "Nonparticipating filter targets a non-Master view")
        showNonparticipatingGroups = checked
        this.RefreshAutoCategoryEditor()
    end)
    BindCheckLabel(showNonLabel, showNon)

    local showAll = GetControl(optionsBar, "ChkShowAllHeadings")
    ZO_CheckButton_SetCheckState(showAll, showAllHeadings)
    ZO_CheckButton_SetToggleFunction(showAll, function(_, checked)
        showAllHeadings = checked
        this.RefreshAutoCategoryEditor()
    end)
    BindCheckLabel(GetControl(optionsBar, "LblShowAllHeadings"), showAll)

    local info = Window("Info")
    if searchQuery ~= "" then
        info:SetText("Clear search to move groups.")
    elseif (master and showNonparticipatingGroups) or showAllHeadings then
        info:SetText("Hide nonparticipating groups and hidden headings to move groups.")
    elseif master then
        info:SetText("Set shared group placements here. Heading labels show where each row applies; elsewhere, groups fall back to the nearest applicable heading.")
    else
        info:SetText("This shows the effective order for this context. Group matching uses the same IC filters; Master changes flow through unless you override a group here.")
    end
end

------------------------------------------------------------------
-- Rows
------------------------------------------------------------------
local function GetOrCreateRow(scrollChild, index)
    local row = rows[index]
    if not row then
        row = CreateControlFromVirtual("InventoryCompanion_AutoCategoryRow_", scrollChild, "InventoryCompanion_AutoCategoryRow_Template", index)
        rows[index] = row
    end
    return row
end

local function IsSelected(entry)
    if entry.kind == "group" then return entry.ruleKey == selectedGroup end
    return selectedHeading ~= nil and entry.occurrenceId == selectedHeading.occurrenceId
end

local function RowAlpha(entry)
    if IsSelected(entry) then return 0.4 end
    if entry.kind == "group" and entry.ruleKey == movedGroup then return 0.45 end
    return 0
end

local function ConfigureParticipation(row, entry, contextAtRender)
    local participation = GetControl(row, "Participation")
    participation:SetHidden(not (contextAtRender == "master" and entry.kind == "group"))
    if contextAtRender ~= "master" or entry.kind ~= "group" then return end
    ZO_CheckButton_SetCheckState(participation, entry.participating)
    ZO_CheckButton_SetToggleFunction(participation, function(_, enabled)
        assert(row.autoCategoryEntry == entry, "AutoCategory participation action targets a stale row")
        AssertCurrentView(contextAtRender)
        this.SetAutoCategoryParticipation(entry.ruleKey, enabled)
        this.RefreshAutoCategoryEditor()
        this.RefreshTrackedItemsEditor()
    end)
    participation:SetHandler("OnMouseEnter", function(control)
        ShowTooltip(control, "Include this group in AutoCategory. Participation applies across all AutoCategory contexts.")
    end)
    participation:SetHandler("OnMouseExit", HideTooltip)
end

local function ConfigureVisibility(row, entry, contextAtRender)
    local visibility = GetControl(row, "Visibility")
    visibility:SetHidden(entry.kind ~= "heading")
    if entry.kind ~= "heading" then return end
    local isVisible
    if contextAtRender == "master" then
        local headingVisibility = this.GetAutoCategoryState().order.headingVisibility
        isVisible = not (headingVisibility and headingVisibility[entry.occurrenceId] == false)
    else
        isVisible = not entry.hidden
    end
    ZO_CheckButton_SetCheckState(visibility, isVisible)
    ZO_CheckButton_SetToggleFunction(visibility, function(_, visible)
        assert(row.autoCategoryEntry == entry, "AutoCategory heading action targets a stale row")
        AssertCurrentView(contextAtRender)
        this.SetAutoCategoryHeadingVisibility(contextAtRender, entry.occurrenceId, visible)
        this.RefreshAutoCategoryEditor()
    end)
    visibility:SetHandler("OnMouseEnter", function(control)
        ShowTooltip(control, "Show this AutoCategory heading in this list.")
    end)
    visibility:SetHandler("OnMouseExit", HideTooltip)
end

local function ConfigureMoves(row, entry, index, count, contextAtRender)
    local moveUp, moveDown = GetControl(row, "MoveUp"), GetControl(row, "MoveDown")
    local canMove = MovesAllowed() and entry.kind == "group" and entry.participating
    moveUp:SetHidden(not canMove)
    moveDown:SetHidden(not canMove)
    if not canMove then return end

    local canMoveUp, canMoveDown = index > 1, index < count
    moveUp:SetEnabled(canMoveUp)
    moveDown:SetEnabled(canMoveDown)
    local function Move(direction)
        assert(row.autoCategoryEntry == entry and MovesAllowed(),
            "AutoCategory move action targets a stale or expanded view")
        AssertCurrentView(contextAtRender)
        if direction < 0 and not canMoveUp or direction > 0 and not canMoveDown then return end
        this.AutoCategoryIntegration.MoveGroup(entry.ruleKey, contextAtRender, direction)
        movedGroup = entry.ruleKey
        PlaySound(SOUNDS.MENU_BAR_CLICK)
        this.RefreshAutoCategoryEditor()
    end
    moveUp:SetHandler("OnClicked", function() Move(-1) end)
    moveDown:SetHandler("OnClicked", function() Move(1) end)
    moveUp:SetHandler("OnMouseEnter", function(control) ShowTooltip(control, "Move this group up.") end)
    moveDown:SetHandler("OnMouseEnter", function(control) ShowTooltip(control, "Move this group down.") end)
    moveUp:SetHandler("OnMouseExit", HideTooltip)
    moveDown:SetHandler("OnMouseExit", HideTooltip)
end

local function PopulateRow(row, entry, index, count, scrollChild)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 0, (index - 1) * ROW_HEIGHT)
    row:SetHidden(false)
    row.autoCategoryEntry = entry

    local selected = IsSelected(entry)
    local label = GetControl(row, "Name")
    local bg = GetControl(row, "BG")
    bg:SetAlpha(RowAlpha(entry))
    if entry.kind == "heading" then
        label:SetText("|cFFD27FAutoCategory|r " .. EscapeEsoMarkup(entry.name)
            .. "  |cAAAAAA[" .. EscapeEsoMarkup(entry.scopeLabel) .. "]|r")
        label:SetColor(0.9, 0.82, 0.65, 1)
    else
        label:SetText(entry.name)
        local shade = not entry.participating and 0.48 or (selected and 0.95 or 0.7)
        label:SetColor(shade, shade, shade, 1)
    end

    row:SetHandler("OnMouseEnter", function()
        if not selected then bg:SetAlpha(0.2) end
    end)
    row:SetHandler("OnMouseExit", function()
        bg:SetAlpha(RowAlpha(entry))
    end)
    row:SetHandler("OnMouseDown", function()
        assert(row.autoCategoryEntry == entry and IsActive(), "AutoCategory row selection targets stale data")
        if entry.kind == "group" then
            selectedGroup = entry.ruleKey
            selectedHeading = nil
        else
            selectedHeading = entry
        end
        this.RefreshAutoCategoryEditor()
    end)

    local contextAtRender = context
    ConfigureParticipation(row, entry, contextAtRender)
    ConfigureVisibility(row, entry, contextAtRender)
    ConfigureMoves(row, entry, index, count, contextAtRender)
end

local function GetFilteredEntries()
    local resolved = this.AutoCategoryIntegration.ResolveAutoCategoryOrder(context, {
        showNonparticipants = showNonparticipatingGroups,
        showAllHeadings = showAllHeadings,
    })
    local filtered = {}
    local selectedHeadingVisible = false
    for _, entry in ipairs(resolved) do
        local include = entry.kind == "heading"
            or context == "master" and showNonparticipatingGroups
            or entry.participating
        if include and (searchQuery == "" or entry.name:lower():find(searchQuery, 1, true)) then
            filtered[#filtered + 1] = entry
            if selectedHeading and entry.kind == "heading" and entry.occurrenceId == selectedHeading.occurrenceId then
                selectedHeadingVisible = true
                selectedHeading = entry
            end
        end
    end
    if not selectedHeadingVisible then selectedHeading = nil end
    return filtered
end

local function PopulateList()
    for _, row in ipairs(rows) do row:SetHidden(true) end
    local scrollChild = GetControl(Window("List"), "ScrollChild")
    assert(scrollChild, "AutoCategory editor is missing its list ScrollChild")
    local entries = GetFilteredEntries()
    for index, entry in ipairs(entries) do
        PopulateRow(GetOrCreateRow(scrollChild, index), entry, index, #entries, scrollChild)
    end
end

local function PopulateHeadingDetails()
    local details = Window("HeadingDetails")
    if not selectedHeading then
        details:SetText("|cAAAAAASelect an AutoCategory heading to see its filter.|r")
        return
    end
    local definition = this.AutoCategoryIntegration.GetHeadingDetails(selectedHeading.name)
    details:SetText(definition
        and ("|cFFD27F" .. EscapeEsoMarkup(selectedHeading.name) .. "|r filter: " .. EscapeEsoMarkup(definition.rule))
        or "This AutoCategory heading is no longer available.")
end

------------------------------------------------------------------
-- Refresh & Scene
------------------------------------------------------------------
function this.RefreshAutoCategoryEditor()
    if InventoryCompanion_AutoCategoryWindow:IsHidden() then return end
    if not IsActive() then
        -- Integration was disabled or AutoCategory became unavailable while this editor was open.
        this.OpenEditGroupsPanel()
        return
    end
    ConfigureToolbar()
    PopulateList()
    PopulateHeadingDetails()
end

local autoCategoryScene = ZO_Scene:New("InventoryCompanion_AutoCategoryScene", SCENE_MANAGER)
autoCategoryScene:AddFragment(ZO_FadeSceneFragment:New(InventoryCompanion_AutoCategoryWindow))

InventoryCompanion_AutoCategoryWindow:SetHandler("OnEffectivelyShown", function()
    SetGameCameraUIMode(true)
    this.RefreshAutoCategoryEditor()
    this.UpdateEditorLayout()
end)

InventoryCompanion_AutoCategoryWindow:SetHandler("OnEffectivelyHidden", function()
    SetGameCameraUIMode(false)
    this.UpdateEditorLayout()
end)
