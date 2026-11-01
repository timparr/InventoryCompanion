local this = InventoryCompanion

local rows = {}
local selectedReferences = {}
local selectionProfile
local scrollAfterMove
local context = "backpack"
local mode = "display"
local searchQuery = ""
local contextCombo
local copyContextCombo

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

local function AssertCurrentView(contextAtRender, modeAtRender)
    assert(IsActive() and context == contextAtRender and mode == modeAtRender,
        "AutoCategory editor action targets a stale view")
end

local function ShowTooltip(control, text)
    InitializeTooltip(InformationTooltip, control, RIGHT, -4, 0)
    InformationTooltip:AddLine(text)
end

local function HideTooltip()
    ClearTooltip(InformationTooltip)
end

local function IsSelected(entry)
    return selectedReferences[entry.reference] == true
end

local function DescribeEntry(entry)
    if entry == nil then return "none" end
    return entry.reference .. " (" .. entry.kind .. ", order " .. tostring(entry.index) .. "/"
        .. tostring(entry.orderCount) .. ", participating " .. tostring(entry.participating) .. ")"
end

local function EditorSnapshot(entry)
    return function()
        local snapshot = this.AutoCategoryIntegration.TimingSnapshot()
        local selected = {}
        for reference in pairs(selectedReferences) do selected[#selected + 1] = reference end
        table.sort(selected)
        local visible = {}
        for _, row in ipairs(rows) do
            if not row:IsHidden() then
                visible[#visible + 1] = (IsSelected(row.autoCategoryEntry) and "*" or "") .. row.autoCategoryEntry.reference
            end
        end
        snapshot.context = context
        snapshot.mode = mode
        snapshot.search = searchQuery
        snapshot.row = DescribeEntry(entry)
        snapshot.selected = selected
        snapshot.createdRows = #rows
        snapshot.visibleRows = visible
        return snapshot
    end
end

-- Every editor click/change goes through Timed so slow actions report the list state they started from.
local function Timed(operation, entry, action, ...)
    return this.AutoCategoryIntegration.TimeAction("editor", operation, EditorSnapshot(entry), action, ...)
end

local function Phase(name, operation, ...)
    return this.AutoCategoryIntegration.TimePhase(name, operation, ...)
end

local function ConfigureCombo(containerName, selected, select)
    local combo = ZO_ComboBox_ObjectFromContainer(GetControl(Window("TopActionBar"), containerName))
    assert(combo, "AutoCategory editor is missing its " .. containerName .. " selector")
    combo:SetSortsItems(false)
    combo:ClearItems()
    for _, entryContext in ipairs(this.AutoCategoryIntegration.GetContexts()) do
        local entry = combo:CreateItemEntry(entryContext.title,
            function(_, _, itemData, selectionChanged)
                if selectionChanged and itemData then
                    Timed(containerName .. " selected " .. itemData.key, nil, select, itemData.key)
                end
            end)
        entry.key = entryContext.key
        combo:AddItem(entry)
        if entryContext.key == selected then combo:SetSelectedItem(entryContext.title) end
    end
    return combo
end

local function ConfigureToolbar()
    local topBar = Window("TopActionBar")
    GetControl(topBar, "FindBox"):SetHandler("OnTextChanged", function(control) Timed("search text changed", nil, function()
        searchQuery = control:GetText():lower():match("^%s*(.-)%s*$")
        selectedReferences = {}
        this.RefreshAutoCategoryEditor()
    end) end)

    contextCombo = ConfigureCombo("ContextMode", context, function(value)
        context = value
        selectedReferences = {}
        this.RefreshAutoCategoryEditor()
    end)

    local source = copyContextCombo and copyContextCombo.selectedKey or nil
    if source == nil or source == context then
        source = this.AutoCategoryIntegration.GetContexts()[1].key
        if source == context then source = this.AutoCategoryIntegration.GetContexts()[2].key end
    end
    copyContextCombo = ConfigureCombo("CopyContext", source, function(value)
        copyContextCombo.selectedKey = value
        GetControl(Window("TopActionBar"), "BtnCopyBoth"):SetEnabled(value ~= context)
    end)
    copyContextCombo.selectedKey = source

    local copy = GetControl(topBar, "BtnCopyBoth")
    copy:SetText("Copy both orders")
    copy:SetEnabled(source ~= context)
    copy:SetHandler("OnClicked", function() Timed("copy both orders", nil, this.AutoCategoryIntegration.Run, function()
        local currentSource = copyContextCombo.selectedKey
        assert(IsActive() and currentSource ~= context, "AutoCategory copy targets an invalid context")
        this.AutoCategoryIntegration.CopyBothOrders(currentSource, context)
        selectedReferences = {}
        this.RefreshAutoCategoryEditor()
    end) end)
    copy:SetHandler("OnMouseEnter", function(control)
        ShowTooltip(control, "Copy both orders from the selected context. Only references present in this context are reordered.")
    end)
    copy:SetHandler("OnMouseExit", HideTooltip)

    local options = Window("OptionsBar")
    local display = GetControl(options, "BtnDisplayOrder")
    local priority = GetControl(options, "BtnPriorityOrder")
    display:SetEnabled(mode ~= "display")
    priority:SetEnabled(mode ~= "matching")
    display:SetHandler("OnClicked", function() Timed("display order mode", nil, function()
        mode = "display"
        selectedReferences = {}
        this.RefreshAutoCategoryEditor()
    end) end)
    priority:SetHandler("OnClicked", function() Timed("priority order mode", nil, function()
        mode = "matching"
        selectedReferences = {}
        this.RefreshAutoCategoryEditor()
    end) end)
    local useOther = GetControl(options, "BtnUseOtherOrder")
    useOther:SetText(mode == "display" and "Use priority list" or "Use display list")
    useOther:SetHandler("OnClicked", function() Timed("use other order", nil, this.AutoCategoryIntegration.Run, function()
        AssertCurrentView(context, mode)
        this.AutoCategoryIntegration.UseOtherOrder(context, mode)
        this.RefreshAutoCategoryEditor()
    end) end)

    local info = Window("Info")
    if mode == "display" then
        info:SetText("Display order — Where assignment headings appear in inventory. Set's generated set-name headings stay together under Set. Use Priority order to change which matching rule wins.")
    else
        info:SetText("Priority order — First matching assignment wins. A catch-all group before Set shadows Set; moving Set changes classification, not its inventory heading position. Display order is independent.")
    end
end

local function GetOrCreateRow(scrollChild, index)
    local row = rows[index]
    if row == nil then
        row = CreateControlFromVirtual("InventoryCompanion_AutoCategoryRow_", scrollChild,
            "InventoryCompanion_AutoCategoryRow_Template", index)
        rows[index] = row
    end
    return row
end

local function CanOrder(entry)
    return entry.kind == "heading" or entry.participating
end

local function SelectionCount()
    local count = 0
    for _ in pairs(selectedReferences) do count = count + 1 end
    return count
end

local function SetRowBackground(row, entry, hovered)
    local bg = GetControl(row, "BG")
    if IsSelected(entry) then
        bg:SetColor(0.16, 0.42, 0.64, 1)
        bg:SetAlpha(0.8)
    else
        bg:SetColor(1, 1, 1, 1)
        bg:SetAlpha(hovered and 0.12 or 0)
    end
end

local function MoveSelection(movement)
    local applied = this.AutoCategoryIntegration.MoveEntries(selectedReferences, context, mode, movement)
    if not applied then return end
    local movingDown = movement == "bottom" or type(movement) == "number" and movement > 0
    scrollAfterMove = movingDown and "last" or "first"
    PlaySound(SOUNDS.MENU_BAR_CLICK)
    this.RefreshAutoCategoryEditor()
end

local function ConfigureParticipation(row, entry, contextAtRender, modeAtRender)
    local participation = GetControl(row, "Participation")
    participation:SetHidden(entry.kind ~= "group")
    if entry.kind ~= "group" then return end
    ZO_CheckButton_SetCheckState(participation, entry.participating)
    ZO_CheckButton_SetToggleFunction(participation, function(_, enabled)
        Timed("participation " .. tostring(enabled), entry, this.AutoCategoryIntegration.Run, function()
            assert(row.autoCategoryEntry == entry, "AutoCategory participation action targets a stale row")
            AssertCurrentView(contextAtRender, modeAtRender)
            Phase("SetAutoCategoryParticipation", this.SetAutoCategoryParticipation, entry.ruleKey, enabled)
            this.RefreshAutoCategoryEditor()
            Phase("RefreshTrackedItemsEditor", this.RefreshTrackedItemsEditor)
        end)
    end)
    participation:SetHandler("OnMouseEnter", function(control)
        ShowTooltip(control, "Include this group in AutoCategory across all seven contexts.")
    end)
    participation:SetHandler("OnMouseExit", HideTooltip)
end

local function ConfigureMoves(row, entry, canMoveUp, canMoveDown, contextAtRender, modeAtRender)
    local moveUp, moveDown = GetControl(row, "MoveUp"), GetControl(row, "MoveDown")
    local canMove = CanOrder(entry)
    moveUp:SetHidden(not canMove)
    moveDown:SetHidden(not canMove)
    if not canMove then return end
    moveUp:SetEnabled(IsSelected(entry) and canMoveUp or not IsSelected(entry) and entry.index > 1)
    moveDown:SetEnabled(IsSelected(entry) and canMoveDown or not IsSelected(entry) and entry.index < entry.orderCount)
    local function Move(direction)
        assert(row.autoCategoryEntry == entry, "AutoCategory move action targets a stale row")
        AssertCurrentView(contextAtRender, modeAtRender)
        if not IsSelected(entry) then selectedReferences = { [entry.reference] = true } end
        MoveSelection(direction)
    end
    moveUp:SetHandler("OnClicked", function() Timed("row up", entry, this.AutoCategoryIntegration.Run, Move, -1) end)
    moveDown:SetHandler("OnClicked", function() Timed("row down", entry, this.AutoCategoryIntegration.Run, Move, 1) end)
    moveUp:SetHandler("OnMouseEnter", function(control)
        ShowTooltip(control, IsSelected(entry) and "Move the whole selection up one step." or "Select and move this assignment up one step.")
    end)
    moveDown:SetHandler("OnMouseEnter", function(control)
        ShowTooltip(control, IsSelected(entry) and "Move the whole selection down one step." or "Select and move this assignment down one step.")
    end)
    moveUp:SetHandler("OnMouseExit", HideTooltip)
    moveDown:SetHandler("OnMouseExit", HideTooltip)
end

local function PopulateRow(row, entry, displayIndex, scrollChild, contextAtRender, modeAtRender, canMoveUp, canMoveDown)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 0, (displayIndex - 1) * ROW_HEIGHT)
    row:SetHidden(false)
    row.autoCategoryEntry = entry

    local label = GetControl(row, "Name")
    SetRowBackground(row, entry, false)
    if entry.kind == "heading" then
        label:SetText(EscapeEsoMarkup(entry.name))
        label:SetColor(0.9, 0.82, 0.65, 1)
    else
        label:SetText(entry.name)
        if modeAtRender == "display" then label:SetColor(0.72, 0.88, 0.74, 1)
        else label:SetColor(0.76, 0.78, 0.98, 1) end
    end

    row:SetHandler("OnMouseEnter", function()
        SetRowBackground(row, entry, true)
    end)
    row:SetHandler("OnMouseExit", function() SetRowBackground(row, entry, false) end)
    local function Select(enabled)
        assert(row.autoCategoryEntry == entry, "AutoCategory row selection targets stale data")
        AssertCurrentView(contextAtRender, modeAtRender)
        assert(CanOrder(entry), "Cannot select a nonparticipating AutoCategory group")
        selectedReferences[entry.reference] = enabled and true or nil
        this.RefreshAutoCategoryEditor()
    end
    local selection = GetControl(row, "Selection")
    selection:SetHidden(not CanOrder(entry))
    ZO_CheckButton_SetCheckState(selection, IsSelected(entry))
    ZO_CheckButton_SetToggleFunction(selection, function(_, enabled)
        Timed("selection checkbox " .. tostring(enabled), entry, this.AutoCategoryIntegration.Run, Select, enabled)
    end)
    selection:SetHandler("OnMouseEnter", function(control) ShowTooltip(control, "Select this row for ordering moves.") end)
    selection:SetHandler("OnMouseExit", HideTooltip)
    row:SetHandler("OnMouseDown", function(_, button)
        Timed("row click " .. tostring(button), entry, this.AutoCategoryIntegration.Run, function()
            if button ~= MOUSE_BUTTON_INDEX_LEFT or not CanOrder(entry) then return end
            local enabled = not IsSelected(entry)
            if enabled and SelectionCount() == 1 then selectedReferences = {} end
            Select(enabled)
        end)
    end)

    ConfigureParticipation(row, entry, contextAtRender, modeAtRender)
    ConfigureMoves(row, entry, canMoveUp, canMoveDown, contextAtRender, modeAtRender)
end

local function ConfigureMovementToolbar(entries, sequence, contextAtRender, modeAtRender)
    local toolbar = Window("MovementBar")
    local function Configure(name, enabled, action, tooltip)
        local button = GetControl(toolbar, name)
        button:SetEnabled(enabled)
        button:SetHandler("OnClicked", function() Timed("toolbar " .. name, nil, this.AutoCategoryIntegration.Run, function()
            AssertCurrentView(contextAtRender, modeAtRender)
            action()
        end) end)
        button:SetHandler("OnMouseEnter", function(control) ShowTooltip(control, tooltip) end)
        button:SetHandler("OnMouseExit", HideTooltip)
    end
    for _, action in ipairs({
        { "BtnTop", "top" }, { "BtnBottom", "bottom" },
        { "BtnUp5", -5 }, { "BtnDown5", 5 }, { "BtnUp10", -10 }, { "BtnDown10", 10 },
    }) do
        local movement = action[2]
        local _, changed = this.AutoCategoryIntegration.GetMovedSequence(sequence, selectedReferences, movement)
        Configure(action[1], changed, function() MoveSelection(movement) end,
            "Move the whole selection. Five/ten steps behave like repeated one-step moves.")
    end
    local selectedKind, mixed = nil, false
    for _, entry in ipairs(entries) do
        if IsSelected(entry) then
            if selectedKind and selectedKind ~= entry.kind then mixed = true end
            selectedKind = entry.kind
        end
    end
    Configure("BtnSelectBlock", selectedKind ~= nil and not mixed and searchQuery == "", function()
        assert(searchQuery == "" and not mixed, "Cannot expand mixed or filtered AutoCategory selections")
        local runStart = 1
        while runStart <= #sequence do
            local runEnd, seeded = runStart, false
            local kind = entries[runStart].kind
            while runEnd <= #sequence and entries[runEnd].kind == kind do
                seeded = seeded or IsSelected(entries[runEnd])
                runEnd = runEnd + 1
            end
            if seeded then
                for index = runStart, runEnd - 1 do selectedReferences[sequence[index]] = true end
            end
            runStart = runEnd
        end
        this.RefreshAutoCategoryEditor()
    end, "Add touching rows of the same type around every selected row. Unavailable for mixed selections or while searching.")
    Configure("BtnClear", next(selectedReferences) ~= nil, function()
        selectedReferences = {}
        this.RefreshAutoCategoryEditor()
    end, "Clear the row selection without changing participation or ordering.")
end

local function PopulateList(contextAtRender, modeAtRender)
    for _, row in ipairs(rows) do row:SetHidden(true) end
    local scrollChild = GetControl(Window("List"), "ScrollChild")
    assert(scrollChild, "AutoCategory editor is missing its list ScrollChild")
    local entries = Phase("ResolveAutoCategoryOrder", this.AutoCategoryIntegration.ResolveAutoCategoryOrder,
        contextAtRender, { mode = modeAtRender })
    local displayed, sequence, visibleOrderable = {}, {}, {}
    for _, entry in ipairs(entries) do
        if searchQuery == "" or entry.name:lower():find(searchQuery, 1, true) then
            displayed[#displayed + 1] = entry
            if CanOrder(entry) then visibleOrderable[entry.reference] = true end
        end
        if CanOrder(entry) then sequence[#sequence + 1] = entry.reference end
    end
    for reference in pairs(selectedReferences) do
        if not visibleOrderable[reference] then selectedReferences[reference] = nil end
    end
    local _, canMoveUp = this.AutoCategoryIntegration.GetMovedSequence(sequence, selectedReferences, -1)
    local _, canMoveDown = this.AutoCategoryIntegration.GetMovedSequence(sequence, selectedReferences, 1)
    local firstSelected, lastSelected
    Phase("populate " .. #displayed .. " rows", function()
        for index, entry in ipairs(displayed) do
            local row = GetOrCreateRow(scrollChild, index)
            PopulateRow(row, entry, index, scrollChild, contextAtRender, modeAtRender, canMoveUp, canMoveDown)
            if IsSelected(entry) then
                firstSelected = firstSelected or row
                lastSelected = row
            end
        end
    end)
    scrollChild:SetHeight(#displayed * ROW_HEIGHT)
    ZO_Scroll_UpdateScrollBar(Window("List"))
    Phase("ConfigureMovementToolbar", ConfigureMovementToolbar, entries, sequence, contextAtRender, modeAtRender)
    if scrollAfterMove and firstSelected then
        ZO_Scroll_ScrollControlIntoView(Window("List"), scrollAfterMove == "last" and lastSelected or firstSelected)
    end
    scrollAfterMove = nil
end

function this.RefreshAutoCategoryEditor()
    if InventoryCompanion_AutoCategoryWindow:IsHidden() then return end
    if not IsActive() then
        this.OpenEditGroupsPanel()
        return
    end
    Phase("RefreshAutoCategoryEditor", this.AutoCategoryIntegration.Run, function()
        local profile = this.GetAutoCategoryProfile()
        if selectionProfile ~= profile then
            selectedReferences = {}
            selectionProfile = profile
        end
        Phase("ConfigureToolbar", ConfigureToolbar)
        local contextAtRender, modeAtRender = context, mode
        PopulateList(contextAtRender, modeAtRender)
    end)
end

local autoCategoryScene = ZO_Scene:New("InventoryCompanion_AutoCategoryScene", SCENE_MANAGER)
autoCategoryScene:AddFragment(ZO_FadeSceneFragment:New(InventoryCompanion_AutoCategoryWindow))

InventoryCompanion_AutoCategoryWindow:SetHandler("OnEffectivelyShown", function() Timed("open editor", nil, function()
    SetGameCameraUIMode(true)
    this.RefreshAutoCategoryEditor()
    this.UpdateEditorLayout()
end) end)

InventoryCompanion_AutoCategoryWindow:SetHandler("OnEffectivelyHidden", function()
    SetGameCameraUIMode(false)
    this.UpdateEditorLayout()
end)
