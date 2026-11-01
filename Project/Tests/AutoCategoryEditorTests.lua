-- Loaded only by the headless runner, before Tracking/EditPanelAutoCategoryTab.lua, in the AutoCategory test state.
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
    function control:SetColor() end
    function control:SetAlpha(alpha) self.alpha = alpha end
    function control:SetEnabled(enabled) self.enabled = enabled end
    return control
end

local window = Control("InventoryCompanion_AutoCategoryWindow")
InventoryCompanion_AutoCategoryWindow = window
local combo
local createdRows = {}

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
function ZO_ComboBox_ObjectFromContainer()
    combo = {
        items = {},
        SetSortsItems = function() end,
        ClearItems = function(self) self.items = {} end,
        CreateItemEntry = function(_, name, callback) return { name = name, callback = callback } end,
        AddItem = function(self, entry) self.items[#self.items + 1] = entry end,
        SetSelectedItem = function(self, name) self.selected = name end,
    }
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
        local text = GetControl(row, "Name").text
        texts[#texts + 1] = text:match("|cFFD27FAutoCategory|r (.-)  ") or text
    end
    return table.concat(texts, ",")
end

local function Setup(rules)
    this.NewAutoCategoryTestFixture()
    AutoCategory.GetRuleByName = function(name) return { rule = "filter(" .. name .. ")" } end
    this.accountWide.autoCategoryInitialized = true
    this.accountWide.autoCategoryIntegrationEnabled = true
    this.accountWide.trackedRules = rules
    this.ValidateSavedRuleProfiles()
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
            name = "AutoCategory editor tab renders, filters, moves, and toggles participation",
            run = WithActiveIntegration(function()
                Setup({
                    alpha = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 100 },
                    beta = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 200 },
                    gamma = { autoCategoryAnchor = "@default-new", autoCategoryRank = 300 },
                })
                this.RefreshAutoCategoryEditor()
                assert(RowTexts() == "New,Alpha,Beta,Gamma,Selling,Low level", RowTexts())
                assert(combo.selected == "Master (all contexts)" and #combo.items == 8)
                assert(not GetControl(RowByText("Gamma"), "Participation").hidden)
                assert(GetControl(RowByText("Gamma"), "Participation").checked == false)
                assert(not GetControl(RowByText("Selling"), "Visibility").hidden)
                assert(GetControl(RowByText("Alpha"), "MoveDown").hidden,
                    "Moves stay hidden while nonparticipating groups are shown")

                local optionsBar = GetControl(window, "OptionsBar")
                GetControl(optionsBar, "LblShowNonparticipating").handlers.OnMouseDown(nil, MOUSE_BUTTON_INDEX_LEFT)
                assert(RowTexts() == "New,Alpha,Beta,Selling,Low level", RowTexts())
                local moveDown = GetControl(RowByText("Alpha"), "MoveDown")
                assert(not moveDown.hidden and moveDown.enabled)
                moveDown.handlers.OnClicked()
                assert(RowTexts() == "New,Beta,Alpha,Selling,Low level", RowTexts())

                ZO_CheckButton_OnClicked(GetControl(optionsBar, "ChkShowNonparticipating"))
                local gammaParticipation = GetControl(RowByText("Gamma"), "Participation")
                gammaParticipation:toggleFunction(true)
                assert(this.accountWide.trackedRules.gamma.autoCategoryEnabled == true)

                RowByText("Selling").handlers.OnMouseDown()
                assert(GetControl(window, "HeadingDetails").text:find("filter(Selling)", 1, true),
                    GetControl(window, "HeadingDetails").text)

                combo.items[3].callback(nil, nil, combo.items[3], true)
                assert(GetControl(GetControl(window, "TopActionBar"), "BtnReset").text == "Reset to Master")
                assert(GetControl(optionsBar, "ChkShowNonparticipating").hidden)
            end),
        },
        {
            name = "AutoCategory editor tab falls back to Groups when integration becomes inactive",
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
