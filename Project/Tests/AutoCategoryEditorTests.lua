local this = InventoryCompanion
local integration = this.AutoCategoryIntegration

local function Control(name)
    local control = { name = name, children = {}, handlers = {}, text = "", hidden = false }
    function control:SetHidden(value) self.hidden = value end
    function control:IsHidden() return self.hidden end
    function control:SetHandler(event, handler) self.handlers[event] = handler end
    function control:SetText(text) self.text = text end
    function control:GetText() return self.text end
    function control:GetTextHeight() return 30 end
    function control:ClearAnchors() end
    function control:SetAnchor(_, _, _, x, y) self.offsetX, self.offsetY = x, y end
    function control:SetColor(...) self.color = { ... } end
    function control:SetAlpha(alpha) self.alpha = alpha end
    function control:SetEnabled(enabled) self.enabled = enabled end
    function control:SetHeight(height) self.height = height end
    return control
end

local window = Control("InventoryCompanion_AutoCategoryWindow")
InventoryCompanion_AutoCategoryWindow = window
local combos, createdRows = {}, {}

function GetControl(parent, name)
    if not parent.children[name] then parent.children[name] = Control(parent.name .. name) end
    return parent.children[name]
end
function CreateControlFromVirtual(prefix, parent, template, index)
    assert(template == "InventoryCompanion_AutoCategoryRow_Template", "Unexpected row template: " .. template)
    local row = Control(prefix .. index)
    createdRows[index] = row
    return row
end
function ZO_ComboBox_ObjectFromContainer(container)
    local combo = {
        items = {},
        SetSortsItems = function() end,
        ClearItems = function(self) self.items = {} end,
        CreateItemEntry = function(_, name, callback) return { name = name, callback = callback } end,
        AddItem = function(self, entry) self.items[#self.items + 1] = entry end,
        SetSelectedItem = function(self, name) self.selected = name end,
    }
    combos[container.name] = combo
    return combo
end
function ZO_CheckButton_SetCheckState(control, checked) control.checked = checked end
function ZO_CheckButton_SetToggleFunction(control, callback) control.toggleFunction = callback end
function ZO_CheckButton_OnClicked(control)
    control.checked = not control.checked
    control:toggleFunction(control.checked)
end
InformationTooltip = { AddLine = function(self, text) self.text = text end }
function InitializeTooltip() end
function ClearTooltip() end
function PlaySound() end
function d() end
local shiftHeld = false
function IsShiftKeyDown() return shiftHeld end
local scrolledRow
function ZO_Scroll_ScrollControlIntoView(_, row) scrolledRow = row end
function ZO_Scroll_UpdateScrollBar() end
SOUNDS = { MENU_BAR_CLICK = "click" }
TOPLEFT, RIGHT, MOUSE_BUTTON_INDEX_LEFT = "TOPLEFT", "RIGHT", 1
SCENE_MANAGER = {}
ZO_Scene = { New = function() return { AddFragment = function() end } end }
ZO_FadeSceneFragment = { New = function() return {} end }
function SetGameCameraUIMode() end

local function VisibleRows()
    local result = {}
    for _, row in ipairs(createdRows) do
        if not row.hidden then result[#result + 1] = row end
    end
    return result
end

local function RowByText(text)
    for _, row in ipairs(VisibleRows()) do
        if GetControl(row, "Name").text:find(text, 1, true) then return row end
    end
    error("No visible AutoCategory editor row contains: " .. text)
end

local function LogicalRowName(row)
    return (GetControl(row, "Name").text:gsub("^AutoCategory: ", ""))
end

local function RowTexts()
    local texts = {}
    for _, row in ipairs(VisibleRows()) do
        if row.autoCategoryEntry.kind ~= "divider" and row.autoCategoryEntry.kind ~= "other" then
            texts[#texts + 1] = LogicalRowName(row)
        end
    end
    return table.concat(texts, ",")
end

local function ClickRow(text)
    local row = RowByText(text)
    row.handlers.OnMouseDown(row, MOUSE_BUTTON_INDEX_LEFT)
end

local function ShiftClickRow(text)
    shiftHeld = true
    local ok, err = pcall(ClickRow, text)
    shiftHeld = false
    assert(ok, err)
end

local function RowSelected(row)
    local background = GetControl(row, "BG")
    return (background.alpha or 0) > 0.5
end

local function SelectedTexts()
    local texts = {}
    for _, row in ipairs(VisibleRows()) do
        if RowSelected(row) then texts[#texts + 1] = LogicalRowName(row) end
    end
    return table.concat(texts, ",")
end

local function ClickToolbar(name)
    local button = GetControl(GetControl(window, "MovementBar"), name)
    assert(button.enabled, "Toolbar button is disabled: " .. name)
    button.handlers.OnClicked()
end

local function Setup(rules)
    this.NewActiveAutoCategoryTestFixture(rules)
    local contexts = this.AutoCategoryIntegration.GetContexts()
    local order = { contexts = {} }
    for _, entry in ipairs(contexts) do
        local native = { "ac:New", "ac:Selling", "ac:Low level" }
        order.contexts[entry.key] = {
            display = native, matching = { "ac:New", "ac:Selling", "ac:Low level" }, hidden = {},
        }
        for _, key in ipairs({ "alpha", "beta", "gamma" }) do
            order.contexts[entry.key].hidden["ic:" .. key] =
                not (rules[key] and rules[key].autoCategoryEnabled) and true or nil
        end
    end
    for _, mode in ipairs({ "display", "matching" }) do
        local sequence = { "ac:New" }
        for _, key in ipairs({ "alpha", "beta" }) do
            if rules[key] and rules[key].autoCategoryEnabled then sequence[#sequence + 1] = "ic:" .. key end
        end
        sequence[#sequence + 1] = "ac:Selling"
        sequence[#sequence + 1] = "ac:Low level"
        order.contexts.backpack[mode] = sequence
    end
    this.accountWide.trackedRules = rules
    this.accountWide.autoCategoryOrder = order
    this.accountWide.autoCategoryIntegrationEnabled = true
    this.InvalidateRuleCache()
    this.ValidateSavedRuleProfiles()
    assert(integration.ProjectAutoCategory())
    this.AutoCategoryIntegration.GetHeadingDetails = function(name) return { rule = "filter(" .. name .. ")" } end
    this.AutoCategoryIntegration.MoveEntries = function(selection, context, mode, movement)
        local selected = {}
        for reference in pairs(selection) do selected[reference] = true end
        this.AutoCategoryIntegration.lastMove = { selected, context, mode, movement }
        local orders = this.accountWide.autoCategoryOrder.contexts[context]
        local sequence, changed = integration.GetMovedSequence(orders[mode], selection, movement)
        orders[mode] = sequence
        return changed
    end
    this.AutoCategoryIntegration.UseOtherOrder = function(context, mode)
        this.AutoCategoryIntegration.lastCopyMode = { context, mode }
        return true
    end
    this.AutoCategoryIntegration.CopyBothOrders = function(source, destination)
        this.AutoCategoryIntegration.lastCrossCopy = { source, destination }
        return true
    end
    this.RefreshTrackedItemsEditor = function() end
    this.UpdateEditorLayout = function() end
    window.hidden = false
    this.RefreshAutoCategoryEditor()
    GetControl(GetControl(window, "OptionsBar"), "BtnDisplayOrder").handlers.OnClicked()
    local contextCombo = combos[window.name .. "TopActionBarContextMode"]
    contextCombo.items[1].callback(nil, nil, contextCombo.items[1], true)
    integration.lastMove = nil
    scrolledRow = nil
end

function this.GetAutoCategoryEditorTests()
    local function WithActiveIntegration(run)
        return function()
            local isAvailable = integration.IsAvailable
            integration.IsAvailable = function() return true end
            local ok, err = pcall(run)
            integration.IsAvailable = isAvailable
            assert(ok, err)
        end
    end

    return {
        {
            name = "AutoCategory editor shares Included Excluded state across modes with labels colours divider and tooltips",
            run = WithActiveIntegration(function()
                Setup({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true } })
                local function State(name, expected)
                    local row = RowByText(name)
                    local toggle = GetControl(row, "Participation")
                    local label = GetControl(toggle, "State")
                    assert(label.text == expected and not toggle.hidden)
                    toggle.handlers.OnMouseEnter(toggle)
                    assert(InformationTooltip.text:find(expected, 1, true)
                        and InformationTooltip.text:find("both lists", 1, true))
                    if expected == "Excluded" then
                        assert(label.color[1] == 1 and label.color[2] == 0.25)
                        assert(GetControl(row, "Name").color[1] == 1)
                        assert(GetControl(row, "MoveUp").hidden and GetControl(row, "MoveDown").hidden)
                    else
                        assert(label.color[1] == 0.2 and label.color[2] == 0.8)
                    end
                    return toggle
                end
                State("Alpha", "Included").handlers.OnClicked()
                State("Alpha", "Excluded")
                State("Selling", "Included").handlers.OnClicked()
                State("Selling", "Excluded")
                local divider
                for index, row in ipairs(VisibleRows()) do
                    if row.autoCategoryEntry.kind == "divider" then
                        divider = index
                        assert(GetControl(row, "Name").text == "Excluded")
                        assert(GetControl(row, "Participation").hidden)
                    end
                    if row.autoCategoryEntry.kind == "other" then
                        assert(GetControl(row, "Participation").hidden)
                    end
                end
                assert(divider)
                local visible = VisibleRows()
                assert(visible[#visible].autoCategoryEntry.reference == "ac:Selling",
                    "New exclusions append to the saved excluded tail")
                GetControl(GetControl(window, "OptionsBar"), "BtnPriorityOrder").handlers.OnClicked()
                State("Alpha", "Excluded")
                State("Selling", "Excluded").handlers.OnClicked()
                State("Selling", "Included")
                GetControl(GetControl(window, "OptionsBar"), "BtnDisplayOrder").handlers.OnClicked()
                State("Selling", "Included")
                State("Alpha", "Excluded").handlers.OnClicked()
                State("Alpha", "Included")
                assert(not this.accountWide.autoCategoryOrder.contexts.backpack.hidden["ac:Selling"]
                    and this.GetRuntimeRules().alpha.autoCategoryEnabled)
            end),
        },
        {
            name = "AutoCategory editor failure view avoids rule resolution and keeps recovery controls available",
            run = WithActiveIntegration(function()
                Setup({ alpha = { autoCategoryEnabled = true } })
                local previousResolve = integration.ResolveAutoCategoryOrder
                integration.ResolveAutoCategoryOrder = function() error("Failure UI must not resolve normal editor rules") end
                integration.Fail("synthetic editor failure")
                this.RefreshAutoCategoryEditor()
                local recovery = GetControl(window, "Recovery")
                assert(not recovery.hidden)
                assert(GetControl(recovery, "Warning").text == integration.GetRecoveryMessage())
                assert(not GetControl(recovery, "Problems").hidden)
                assert(GetControl(GetControl(recovery, "Problems"), "ScrollChildProblemRows").text
                    == integration.GetProblemRowsMessage())
                for _, name in ipairs({ "TopActionBar", "OptionsBar", "Info", "List", "MovementBar" }) do
                    assert(GetControl(window, name).hidden, "Normal editing must be hidden: " .. name)
                end
                assert(#VisibleRows() == 0 and not GetControl(window, "BtnEditItems").hidden
                    and not GetControl(window, "BtnEditGroups").hidden)
                local oldRetry, oldDetails = integration.RetrySynchronization, integration.ShowRecoveryDetails
                local retried, detailed = 0, 0
                integration.RetrySynchronization = function() retried = retried + 1 end
                integration.ShowRecoveryDetails = function() detailed = detailed + 1 end
                GetControl(recovery, "BtnRetry").handlers.OnClicked()
                GetControl(recovery, "BtnDetails").handlers.OnClicked()
                assert(retried == 1 and detailed == 1, "Recovery must not go through the faulted Run gate")
                local previousCanRepair, previousShowRepair = integration.CanRepairAssignments, integration.ShowAssignmentRepair
                assert(GetControl(recovery, "BtnRepair").enabled == false,
                    "A code failure must not offer assignment repair")
                local repaired = 0
                integration.CanRepairAssignments = function() return true end
                integration.ShowAssignmentRepair = function() repaired = repaired + 1 end
                this.RefreshAutoCategoryEditor()
                assert(GetControl(recovery, "BtnRepair").enabled)
                GetControl(recovery, "BtnRepair").handlers.OnClicked()
                assert(repaired == 1)
                integration.CanRepairAssignments, integration.ShowAssignmentRepair = previousCanRepair, previousShowRepair
                integration.RetrySynchronization, integration.ShowRecoveryDetails = oldRetry, oldDetails
                integration.ResolveAutoCategoryOrder = previousResolve
                local previousReset = integration.ShowIntegrationReset
                local resets = 0
                integration.ShowIntegrationReset = function() resets = resets + 1 end
                assert(not GetControl(recovery, "BtnReset").hidden)
                GetControl(recovery, "BtnReset").handlers.OnClicked()
                assert(resets == 1)
                integration.ShowIntegrationReset = previousReset
                this.autoCategoryFailure = nil
                this.autoCategoryFailureTraceback = nil
                local previousAwaiting, previousEnable = integration.IsAwaitingSetup, this.SetAutoCategoryIntegrationEnabled
                integration.IsAwaitingSetup = function() return true end
                local enabledAgain = false
                this.SetAutoCategoryIntegrationEnabled = function(enabled) enabledAgain = enabled end
                this.RefreshAutoCategoryEditor()
                assert(not recovery.hidden and not GetControl(recovery, "BtnEnableSetup").hidden
                    and GetControl(recovery, "BtnReset").hidden and GetControl(recovery, "BtnRetry").hidden
                    and GetControl(window, "List").hidden)
                assert(GetControl(recovery, "Problems").hidden)
                GetControl(recovery, "BtnEnableSetup").handlers.OnClicked()
                assert(enabledAgain)
                integration.IsAwaitingSetup, this.SetAutoCategoryIntegrationEnabled = previousAwaiting, previousEnable
                this.RefreshAutoCategoryEditor()
                assert(recovery.hidden and not GetControl(window, "List").hidden and #VisibleRows() > 0,
                    "Recovered view must restore normal editing")
            end),
        },
        {
            name = "AutoCategory editor clicks start a new selection and shift-clicks toggle membership",
            run = WithActiveIntegration(function()
                Setup({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true }, gamma = {} })
                ClickRow("Alpha")
                assert(SelectedTexts() == "Alpha")
                ClickRow("Beta")
                assert(SelectedTexts() == "Beta", "A plain click must replace the selection")
                ShiftClickRow("Alpha")
                assert(SelectedTexts() == "Alpha,Beta")
                ShiftClickRow("Selling")
                assert(SelectedTexts() == "Alpha,Beta,Selling")
                ClickRow("Alpha")
                assert(SelectedTexts() == "Alpha", "A plain click must start a new selection")
                ClickRow("Alpha")
                assert(SelectedTexts() == "Alpha", "Clicking the only selected row must keep it selected")
                ShiftClickRow("Alpha")
                assert(SelectedTexts() == "", "Shift-clicking a selected row must remove it")
                ClickRow("Gamma")
                assert(SelectedTexts() == "")
                assert(GetControl(RowByText("Gamma"), "MoveUp").hidden)
                assert(not this.GetRuntimeRules().gamma.autoCategoryEnabled)
            end),
        },
        {
            name = "AutoCategory editor highlights and moves the whole block from every selected row",
            run = WithActiveIntegration(function()
                Setup({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true } })
                ShiftClickRow("Alpha")
                ShiftClickRow("Beta")
                local alpha = RowByText("Alpha")
                local background = GetControl(alpha, "BG")
                assert(background.alpha > 0.5)
                alpha.handlers.OnMouseEnter()
                alpha.handlers.OnMouseExit()
                assert(background.alpha > 0.5, "Hover exit must retain the selection highlight")
                GetControl(RowByText("Beta"), "MoveUp").handlers.OnClicked()
                assert(RowTexts() == "Alpha,Beta,New,Selling,Low level,Gamma", RowTexts())
                assert(SelectedTexts() == "Alpha,Beta")
                assert(scrolledRow == RowByText("Alpha"))
                assert(not GetControl(RowByText("Beta"), "MoveUp").enabled)
                GetControl(RowByText("Alpha"), "MoveDown").handlers.OnClicked()
                assert(RowTexts() == "New,Alpha,Beta,Selling,Low level,Gamma")
                assert(scrolledRow == RowByText("Beta"))
                ClickToolbar("BtnClear")
                assert(SelectedTexts() == "")
                assert(GetControl(RowByText("Alpha"), "BG").alpha == 0)
                assert(this.GetRuntimeRules().alpha.autoCategoryEnabled)
            end),
        },
        {
            name = "AutoCategory editor Select block expands every same-type seed and disables mixed selections",
            run = WithActiveIntegration(function()
                Setup({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true } })
                ShiftClickRow("New")
                ShiftClickRow("Low level")
                ClickToolbar("BtnSelectBlock")
                assert(SelectedTexts() == "New,Selling,Low level", SelectedTexts())
                ShiftClickRow("Alpha")
                assert(not GetControl(GetControl(window, "MovementBar"), "BtnSelectBlock").enabled)
                ClickToolbar("BtnClear")
                ClickRow("Alpha")
                ClickToolbar("BtnSelectBlock")
                assert(SelectedTexts() == "Alpha,Beta")
                GetControl(GetControl(window, "OptionsBar"), "BtnPriorityOrder").handlers.OnClicked()
                assert(SelectedTexts() == "", "Mode switches must clear the selection")
                ShiftClickRow("Alpha")
                local combo = combos[window.name .. "TopActionBarContextMode"]
                combo.items[2].callback(nil, nil, combo.items[2], true)
                assert(SelectedTexts() == "", "Context switches must clear the selection")
            end),
        },
        {
            name = "AutoCategory editor flood-fills separate IC runs without selecting the intervening AC heading",
            run = WithActiveIntegration(function()
                Setup({
                    alpha = { autoCategoryEnabled = true },
                    beta = { autoCategoryEnabled = true },
                    gamma = { autoCategoryEnabled = true },
                })
                this.accountWide.autoCategoryOrder.contexts.backpack.display = {
                    "ac:New", "ic:alpha", "ac:Selling", "ic:beta", "ic:gamma", "ac:Low level",
                }
                this.RefreshAutoCategoryEditor()
                ShiftClickRow("Alpha")
                ShiftClickRow("Gamma")
                ClickToolbar("BtnSelectBlock")
                assert(SelectedTexts() == "Alpha,Beta,Gamma", SelectedTexts())
            end),
        },
        {
            name = "AutoCategory editor clears selection on profile switches even when references are shared",
            run = WithActiveIntegration(function()
                Setup({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true } })
                ShiftClickRow("Alpha")
                ShiftClickRow("Beta")
                this.character.trackedRules = { alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true } }
                this.character.autoCategoryOrder = this.accountWide.autoCategoryOrder
                this.character.autoCategoryIntegrationEnabled = true
                this.character.useCharacterItemList = true
                this.ValidateSavedRuleProfiles()
                this.InvalidateRuleCache()
                this.RefreshAutoCategoryEditor()
                assert(RowTexts():find("Alpha", 1, true) and SelectedTexts() == "")
                assert(not GetControl(GetControl(window, "MovementBar"), "BtnClear").enabled)
            end),
        },
        {
            name = "AutoCategory editor toolbar handles separated selections, boundaries and stable top-bottom gathering",
            run = WithActiveIntegration(function()
                Setup({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true } })
                ShiftClickRow("Alpha")
                ShiftClickRow("Selling")
                GetControl(RowByText("Selling"), "MoveUp").handlers.OnClicked()
                assert(RowTexts() == "Alpha,New,Selling,Beta,Low level,Gamma", RowTexts())
                ClickToolbar("BtnBottom")
                assert(RowTexts() == "New,Beta,Low level,Alpha,Selling,Gamma", RowTexts())
                assert(SelectedTexts() == "Alpha,Selling")
                assert(not GetControl(GetControl(window, "MovementBar"), "BtnBottom").enabled)
                ClickToolbar("BtnTop")
                assert(RowTexts() == "Alpha,Selling,New,Beta,Low level,Gamma")
                ClickToolbar("BtnDown5")
                assert(RowTexts() == "New,Beta,Low level,Alpha,Selling,Gamma")
                ClickToolbar("BtnUp5")
                assert(RowTexts() == "Alpha,Selling,New,Beta,Low level,Gamma")
                ClickToolbar("BtnDown1")
                assert(RowTexts() == "New,Alpha,Selling,Beta,Low level,Gamma")
                ClickToolbar("BtnUp1")
                assert(RowTexts() == "Alpha,Selling,New,Beta,Low level,Gamma")
                GetControl(RowByText("New"), "MoveDown").handlers.OnClicked()
                assert(SelectedTexts() == "New", "Moving an unselected row must select only that row")
            end),
        },
        {
            name = "AutoCategory editor exposes independent modes, all assignments, and full-list move semantics",
            run = WithActiveIntegration(function()
                Setup({
                    alpha = { autoCategoryEnabled = true },
                    beta = { autoCategoryEnabled = true },
                    gamma = {},
                })
                this.RefreshAutoCategoryEditor()
                assert(RowTexts() == "New,Alpha,Beta,Selling,Low level,Gamma", RowTexts())
                local contextCombo = combos[window.name .. "TopActionBarContextMode"]
                assert(contextCombo.selected == "Backpack" and #contextCombo.items == 7)
                local alphaLabel = GetControl(RowByText("Alpha"), "Name")
                assert(alphaLabel.color[1] == 0.2 and alphaLabel.color[2] == 0.8 and alphaLabel.color[3] == 0.4,
                    "Display groups use the darker shared green")
                local sellingLabel = GetControl(RowByText("Selling"), "Name")
                assert(sellingLabel.text == "AutoCategory: Selling")
                assert(sellingLabel.color[1] == 0.65 and sellingLabel.color[2] == 0.68
                    and sellingLabel.color[3] == 1, "Native categories use a non-green tint")
                assert(not GetControl(RowByText("Gamma"), "Participation").hidden)
                assert(GetControl(GetControl(RowByText("Gamma"), "Participation"), "State").text == "Excluded")
                assert(not GetControl(RowByText("New"), "Participation").hidden)
                assert(GetControl(RowByText("Alpha"), "MoveDown").hidden == false)
                assert(GetControl(RowByText("Alpha"), "Orders").text == "",
                    "Rows at the same position in both lists must show no divergence marker: "
                        .. GetControl(RowByText("Alpha"), "Orders").text)
                assert(GetControl(RowByText("Gamma"), "Orders").text == "",
                    "Nonparticipating groups have no order positions")

                GetControl(RowByText("Alpha"), "MoveDown").handlers.OnClicked()
                local move = integration.lastMove
                assert(move[1]["ic:alpha"] and move[2] == "backpack" and move[3] == "display" and move[4] == 1)
                assert(GetControl(RowByText("Alpha"), "Orders").text == "Priority 2",
                    "Diverging rows must show their position in the other list: "
                        .. GetControl(RowByText("Alpha"), "Orders").text)
                assert(GetControl(RowByText("Beta"), "Orders").text == "Priority 3",
                    GetControl(RowByText("Beta"), "Orders").text)

                local options = GetControl(window, "OptionsBar")
                GetControl(options, "BtnPriorityOrder").handlers.OnClicked()
                alphaLabel = GetControl(RowByText("Alpha"), "Name")
                assert(alphaLabel.color[1] == 0.60 and alphaLabel.color[2] == 0.90
                    and alphaLabel.color[3] == 0.65, "Priority groups use pale green")
                assert(GetControl(window, "Info").text:find("more than one group", 1, true))
                assert(GetControl(window, "Info").text:find("Hold shift", 1, true))
                assert(GetControl(options, "BtnUseOtherOrder").text == "Use display list")
                GetControl(options, "BtnUseOtherOrder").handlers.OnClicked()
                assert(integration.lastCopyMode[1] == "backpack" and integration.lastCopyMode[2] == "matching")
                GetControl(options, "BtnDisplayOrder").handlers.OnClicked()
                assert(GetControl(options, "BtnUseOtherOrder").text == "Use priority list")

                local participation = GetControl(RowByText("Gamma"), "Participation")
                participation.handlers.OnClicked()
                assert(integration.IsEntryIncluded("ic:gamma", "backpack"))
                assert(integration.lastCrossCopy == nil)
            end),
        },
        {
            name = "AutoCategory editor falls back to Groups when integration becomes inactive",
            run = WithActiveIntegration(function()
                Setup({})
                this.accountWide.autoCategoryIntegrationEnabled = false
                local opened = 0
                local openGroups = this.OpenEditGroupsPanel
                this.OpenEditGroupsPanel = function() opened = opened + 1 end
                local ok, err = pcall(this.RefreshAutoCategoryEditor)
                this.OpenEditGroupsPanel = openGroups
                assert(ok, err)
                assert(opened == 1, "Inactive integration must leave the AutoCategory tab")
                window.hidden = true
                this.RefreshAutoCategoryEditor()
            end),
        },
        {
            name = "AutoCategory editor timing reports slow clicks with start state and phases without disabling integration",
            run = WithActiveIntegration(function()
                Setup({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true }, gamma = {} })
                local clock = this.AutoCategoryTestClock
                clock.Reset()
                ClickRow("Alpha")
                assert(clock.RunFrame() == 1, "Each timed action must schedule one next-frame check")
                local resolve = integration.ResolveAutoCategoryOrder
                integration.ResolveAutoCategoryOrder = function(...)
                    clock.Advance(120)
                    return resolve(...)
                end
                local ok, report = pcall(ClickRow, "Beta")
                integration.ResolveAutoCategoryOrder = resolve
                assert(ok, "A slow click must report to chat without raising: " .. tostring(report))
                report = tostring(integration.Timing.lastSlowReport)
                for _, expected in ipairs({
                    "Slow AutoCategory editor: row click 1 took 120 ms synchronously (threshold 100 ms)",
                    "row: ic:beta (group",
                    "selected: [1] ic:alpha",
                    "*ic:alpha",
                    "context: backpack",
                    "mode: display",
                    "\n  RefreshAutoCategoryEditor: 120 ms",
                    "\n    ResolveAutoCategoryOrder: 120 ms",
                    "editor: row click 1, 0 ms",
                }) do
                    assert(report:find(expected, 1, true), "Missing '" .. expected .. "' in:\n" .. report)
                end
                assert(SelectedTexts() == "Beta", "The slow action must still complete before reporting")
                assert(not integration.IsFaulted(), "Timing reports must not disable integration")
                assert(clock.RunFrame() == 0, "A synchronously reported action needs no frame check")
            end),
        },
        {
            name = "AutoCategory editor timing reports slow next frames and does nothing when Debug Mode is off",
            run = WithActiveIntegration(function()
                Setup({ alpha = { autoCategoryEnabled = true }, beta = { autoCategoryEnabled = true }, gamma = {} })
                local clock = this.AutoCategoryTestClock
                clock.Reset()
                ClickRow("Alpha")
                clock.RunFrame()
                ClickRow("Beta")
                clock.Advance(130)
                local ok, failure = pcall(clock.RunFrame)
                local report = tostring(integration.Timing.lastSlowReport)
                assert(ok and report:find("row click 1 took 130 ms before the next frame", 1, true),
                    tostring(failure) .. "\n" .. report)
                assert(clock.RunFrame() == 0, "Next-frame checks must unregister before reporting")
                local reported = integration.Timing.lastSlowReport
                local previous = integration.Timing.lastAction
                this.accountWide.debugEnabled = false
                local resolve = integration.ResolveAutoCategoryOrder
                integration.ResolveAutoCategoryOrder = function(...)
                    clock.Advance(1000)
                    return resolve(...)
                end
                ClickRow("Alpha")
                integration.ResolveAutoCategoryOrder = resolve
                assert(clock.RunFrame() == 0, "Debug Mode off must not schedule frame checks")
                assert(integration.Timing.lastSlowReport == reported and integration.Timing.lastAction == previous,
                    "Debug Mode off must not time or report actions")
                assert(SelectedTexts() == "Alpha", "Untimed actions must still run")
            end),
        },
    }
end
