local this = InventoryCompanion

local rows = {}
local selectedReference
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

local function ConfigureCombo(containerName, selected, select)
    local combo = ZO_ComboBox_ObjectFromContainer(GetControl(Window("TopActionBar"), containerName))
    assert(combo, "AutoCategory editor is missing its " .. containerName .. " selector")
    combo:SetSortsItems(false)
    combo:ClearItems()
    for _, entryContext in ipairs(this.AutoCategoryIntegration.GetContexts()) do
        local entry = combo:CreateItemEntry(entryContext.title,
            function(_, _, itemData, selectionChanged)
                if selectionChanged and itemData then select(itemData.key) end
            end)
        entry.key = entryContext.key
        combo:AddItem(entry)
        if entryContext.key == selected then combo:SetSelectedItem(entryContext.title) end
    end
    return combo
end

local function ConfigureToolbar()
    local topBar = Window("TopActionBar")
    GetControl(topBar, "FindBox"):SetHandler("OnTextChanged", function(control)
        searchQuery = control:GetText():lower():match("^%s*(.-)%s*$")
        this.RefreshAutoCategoryEditor()
    end)

    contextCombo = ConfigureCombo("ContextMode", context, function(value)
        context = value
        selectedReference = nil
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
    copy:SetHandler("OnClicked", function() this.AutoCategoryIntegration.Run(function()
        local currentSource = copyContextCombo.selectedKey
        assert(IsActive() and currentSource ~= context, "AutoCategory copy targets an invalid context")
        this.AutoCategoryIntegration.CopyBothOrders(currentSource, context)
        selectedReference = nil
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
    display:SetHandler("OnClicked", function()
        mode = "display"
        this.RefreshAutoCategoryEditor()
    end)
    priority:SetHandler("OnClicked", function()
        mode = "matching"
        this.RefreshAutoCategoryEditor()
    end)
    local useOther = GetControl(options, "BtnUseOtherOrder")
    useOther:SetText(mode == "display" and "Use priority list" or "Use display list")
    useOther:SetHandler("OnClicked", function() this.AutoCategoryIntegration.Run(function()
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
    if this.AutoCategoryIntegration.HasPendingOrderChanges() then
        info:SetText(info:GetText() .. " Changes apply to AutoCategory five seconds after your last edit.")
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

local function IsSelected(entry)
    return selectedReference == entry.reference
end

local function RowAlpha(entry)
    return IsSelected(entry) and 0.4 or 0
end

local function ConfigureParticipation(row, entry, contextAtRender, modeAtRender)
    local participation = GetControl(row, "Participation")
    participation:SetHidden(entry.kind ~= "group")
    if entry.kind ~= "group" then return end
    ZO_CheckButton_SetCheckState(participation, entry.participating)
    ZO_CheckButton_SetToggleFunction(participation, function(_, enabled) this.AutoCategoryIntegration.Run(function()
        assert(row.autoCategoryEntry == entry, "AutoCategory participation action targets a stale row")
        AssertCurrentView(contextAtRender, modeAtRender)
        this.SetAutoCategoryParticipation(entry.ruleKey, enabled)
        this.RefreshAutoCategoryEditor()
        this.RefreshTrackedItemsEditor()
    end) end)
    participation:SetHandler("OnMouseEnter", function(control)
        ShowTooltip(control, "Include this group in AutoCategory across all seven contexts.")
    end)
    participation:SetHandler("OnMouseExit", HideTooltip)
end

local function ConfigureMoves(row, entry, orderIndex, count, contextAtRender, modeAtRender)
    local moveUp, moveDown = GetControl(row, "MoveUp"), GetControl(row, "MoveDown")
    local canMove = entry.kind == "heading" or entry.participating
    moveUp:SetHidden(not canMove)
    moveDown:SetHidden(not canMove)
    if not canMove then return end
    moveUp:SetEnabled(orderIndex > 1)
    moveDown:SetEnabled(orderIndex < count)
    local function Move(direction)
        assert(row.autoCategoryEntry == entry, "AutoCategory move action targets a stale row")
        AssertCurrentView(contextAtRender, modeAtRender)
        if direction < 0 and orderIndex == 1 or direction > 0 and orderIndex == count then return end
        local applied = this.AutoCategoryIntegration.MoveEntry(entry.reference, contextAtRender, modeAtRender, direction)
        if not applied then return end
        selectedReference = entry.reference
        PlaySound(SOUNDS.MENU_BAR_CLICK)
        this.RefreshAutoCategoryEditor()
    end
    moveUp:SetHandler("OnClicked", function() this.AutoCategoryIntegration.Run(Move, -1) end)
    moveDown:SetHandler("OnClicked", function() this.AutoCategoryIntegration.Run(Move, 1) end)
    moveUp:SetHandler("OnMouseEnter", function(control) ShowTooltip(control, "Move this assignment up one position.") end)
    moveDown:SetHandler("OnMouseEnter", function(control) ShowTooltip(control, "Move this assignment down one position.") end)
    moveUp:SetHandler("OnMouseExit", HideTooltip)
    moveDown:SetHandler("OnMouseExit", HideTooltip)
end

local function PopulateRow(row, entry, displayIndex, scrollChild, contextAtRender, modeAtRender)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 0, (displayIndex - 1) * ROW_HEIGHT)
    row:SetHidden(false)
    row.autoCategoryEntry = entry

    local label = GetControl(row, "Name")
    local bg = GetControl(row, "BG")
    bg:SetAlpha(RowAlpha(entry))
    if entry.kind == "heading" then
        label:SetText(EscapeEsoMarkup(entry.name))
        label:SetColor(0.9, 0.82, 0.65, 1)
    else
        label:SetText(entry.name)
        if modeAtRender == "display" then label:SetColor(0.72, 0.88, 0.74, 1)
        else label:SetColor(0.76, 0.78, 0.98, 1) end
    end

    row:SetHandler("OnMouseEnter", function()
        if not IsSelected(entry) then bg:SetAlpha(0.2) end
    end)
    row:SetHandler("OnMouseExit", function() bg:SetAlpha(RowAlpha(entry)) end)
    row:SetHandler("OnMouseDown", function() this.AutoCategoryIntegration.Run(function()
        assert(row.autoCategoryEntry == entry and IsActive(), "AutoCategory row selection targets stale data")
        selectedReference = entry.reference
        this.RefreshAutoCategoryEditor()
    end) end)

    ConfigureParticipation(row, entry, contextAtRender, modeAtRender)
    ConfigureMoves(row, entry, entry.index, entry.orderCount, contextAtRender, modeAtRender)
end

local function PopulateList(contextAtRender, modeAtRender)
    for _, row in ipairs(rows) do row:SetHidden(true) end
    local scrollChild = GetControl(Window("List"), "ScrollChild")
    assert(scrollChild, "AutoCategory editor is missing its list ScrollChild")
    local entries = this.AutoCategoryIntegration.ResolveAutoCategoryOrder(contextAtRender, { mode = modeAtRender })
    local displayed = {}
    local selectedFound = false
    for _, entry in ipairs(entries) do
        if searchQuery == "" or entry.name:lower():find(searchQuery, 1, true) then
            displayed[#displayed + 1] = entry
            if entry.reference == selectedReference then selectedFound = true end
        end
    end
    if not selectedFound then selectedReference = nil end
    for index, entry in ipairs(displayed) do
        PopulateRow(GetOrCreateRow(scrollChild, index), entry, index, scrollChild, contextAtRender, modeAtRender)
    end
end

local function PopulateDetails()
    local details = Window("HeadingDetails")
    if selectedReference == nil or selectedReference:sub(1, 3) ~= "ac:" then
        details:SetText("Native assignments retain their AutoCategory filters. IC group patterns remain editable in Edit Groups.")
        return
    end
    local name = selectedReference:sub(4)
    local definition = this.AutoCategoryIntegration.GetHeadingDetails(name)
    details:SetText(definition
        and ("|cFFD27F" .. EscapeEsoMarkup(name) .. "|r filter: " .. EscapeEsoMarkup(definition.rule))
        or ("Native AutoCategory assignment: " .. EscapeEsoMarkup(name)))
end

function this.RefreshAutoCategoryEditor()
    if InventoryCompanion_AutoCategoryWindow:IsHidden() then return end
    if not IsActive() then
        this.OpenEditGroupsPanel()
        return
    end
    this.AutoCategoryIntegration.Run(function()
        ConfigureToolbar()
        local contextAtRender, modeAtRender = context, mode
        PopulateList(contextAtRender, modeAtRender)
        PopulateDetails()
    end)
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
