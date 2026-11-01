local this = InventoryCompanion
local integration = this.AutoCategoryIntegration

local function Control(name)
    local control = { name = name, children = {}, handlers = {}, text = "", hidden = false }
    function control:SetHidden(value) self.hidden = value end
    function control:IsHidden() return self.hidden end
    function control:SetHandler(event, handler) self.handlers[event] = handler end
    function control:SetText(text) self.text = text end
    function control:GetText() return self.text end
    function control:ClearAnchors() end
    function control:SetAnchor(_, _, _, x, y) self.offsetX, self.offsetY = x, y end
    function control:SetColor(...) self.color = { ... } end
    function control:SetAlpha(alpha) self.alpha = alpha end
    function control:SetEnabled(enabled) self.enabled = enabled end
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
InformationTooltip = { AddLine = function() end }
function InitializeTooltip() end
function ClearTooltip() end
function PlaySound() end
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

local function RowTexts()
    local texts = {}
    for _, row in ipairs(VisibleRows()) do
        texts[#texts + 1] = GetControl(row, "Name").text
    end
    return table.concat(texts, ",")
end

local function Setup(rules)
    this.NewAutoCategoryTestFixture()
    local contexts = this.AutoCategoryIntegration.GetContexts()
    local order = { contexts = {} }
    for _, entry in ipairs(contexts) do
        local native = { "ac:New", "ac:Selling", "ac:Low level" }
        order.contexts[entry.key] = { display = native, matching = { "ac:New", "ac:Selling", "ac:Low level" } }
    end
    order.contexts.backpack.display = { "ac:New", "ic:alpha", "ic:beta", "ac:Selling", "ac:Low level" }
    order.contexts.backpack.matching = { "ac:New", "ic:alpha", "ic:beta", "ac:Selling", "ac:Low level" }
    this.accountWide.trackedRules = rules
    this.accountWide.autoCategoryOrder = order
    this.accountWide.autoCategoryIntegrationEnabled = true
    this.InvalidateRuleCache()
    this.ValidateSavedRuleProfiles()
    this.AutoCategoryIntegration.GetHeadingDetails = function(name) return { rule = "filter(" .. name .. ")" } end
    this.AutoCategoryIntegration.MoveEntry = function(reference, context, mode, direction)
        this.AutoCategoryIntegration.lastMove = { reference, context, mode, direction }
        return true
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
                assert(not GetControl(RowByText("Gamma"), "Participation").hidden)
                assert(GetControl(RowByText("Gamma"), "Participation").checked == false)
                assert(GetControl(RowByText("New"), "Participation").hidden)
                assert(GetControl(RowByText("Alpha"), "MoveDown").hidden == false)

                local find = GetControl(GetControl(window, "TopActionBar"), "FindBox")
                find.text = "Alpha"
                find.handlers.OnTextChanged(find)
                assert(RowTexts() == "Alpha")
                GetControl(RowByText("Alpha"), "MoveDown").handlers.OnClicked()
                local move = integration.lastMove
                assert(move[1] == "ic:alpha" and move[2] == "backpack" and move[3] == "display" and move[4] == 1)

                local options = GetControl(window, "OptionsBar")
                GetControl(options, "BtnPriorityOrder").handlers.OnClicked()
                assert(GetControl(window, "Info").text:find("First matching assignment wins", 1, true))
                assert(GetControl(options, "BtnUseOtherOrder").text == "Use display list")
                GetControl(options, "BtnUseOtherOrder").handlers.OnClicked()
                assert(integration.lastCopyMode[1] == "backpack" and integration.lastCopyMode[2] == "matching")
                GetControl(options, "BtnDisplayOrder").handlers.OnClicked()
                assert(GetControl(options, "BtnUseOtherOrder").text == "Use priority list")

                find.text = ""
                find.handlers.OnTextChanged(find)
                local participation = GetControl(RowByText("Gamma"), "Participation")
                participation:toggleFunction(true)
                assert(this.GetRuntimeRules().gamma.autoCategoryEnabled)
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
    }
end
