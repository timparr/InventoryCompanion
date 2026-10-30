-- Loaded only by the headless runner, in a separate Lua state from ESO.
local this = InventoryCompanion
local controls, dialogs = {}, {}
local hudRefreshes, groupRefreshes = 0, 0

local function Control(name)
    local control = { name = name, children = {}, handlers = {}, text = "", hidden = false, moves = 0 }
    function control:SetHidden(value) self.hidden = value end
    function control:SetHandler(event, handler) self.handlers[event] = handler end
    function control:SetText(text) self.text = text end
    function control:GetText() return self.text end
    function control:ClearAnchors() self.moves = self.moves + 1 end
    function control:SetAnchor(point, relative, relativePoint, x, y)
        self.moves = self.moves + 1
        self.anchor = { point = point, relative = relative, relativePoint = relativePoint, x = x, y = y }
    end
    function control:SetFont() end
    function control:SetColor(r, g, b, a) self.color = { r, g, b, a } end
    function control:SetTexture(texture) self.texture = texture end
    function control:SetNormalTexture(texture) self.normalTexture = texture end
    function control:SetPressedTexture(texture) self.pressedTexture = texture end
    function control:SetMouseOverTexture(texture) self.mouseOverTexture = texture end
    function control:SetDisabledTexture(texture) self.disabledTexture = texture end
    function control:SetAlpha() end
    function control:TakeFocus() self.focused = true end
    function control:SelectAll() self.selectedAll = true end
    function control:LoseFocus()
        self.focused = false
        if self.handlers.OnFocusLost then self.handlers.OnFocusLost(self) end
    end
    controls[name] = control
    return control
end

function GetControl(parent, name)
    if not parent.children[name] then parent.children[name] = Control(parent.name .. name) end
    return parent.children[name]
end

function CreateControlFromVirtual(prefix, parent, template, index)
    return Control(prefix .. index)
end

TOPLEFT, TOPRIGHT = "TOPLEFT", "TOPRIGHT"
TOP = "TOP"
SCENE_SHOWING, SCENE_HIDDEN = "showing", "hidden"
SCENE_MANAGER = {}
ZO_Scene = { New = function()
    return { AddFragment = function() end, RegisterCallback = function() end }
end }
ZO_FadeSceneFragment = { New = function() return {} end }
GAMEPAD_DIALOGS = { BASIC = 1 }
SI_DIALOG_CANCEL = "Cancel"
InformationTooltip = {
    lines = {},
    AddLine = function(self, text) table.insert(self.lines, text) end,
}
function InitializeTooltip(tooltip, control)
    tooltip.control = control
    tooltip.lines = {}
end
function ClearTooltip(tooltip) tooltip.cleared = true end
InventoryCompanion_GroupsWindow = Control("window")
InventoryCompanion_GroupsWindowLeftPane = Control("left")
InventoryCompanion_GroupsWindowRightPane = Control("right")
function ZO_Dialogs_RegisterCustomDialog(name, data) dialogs[name] = data end
function ZO_Dialogs_ShowDialog(name, data) dialogs[name].buttons[1].callback({ data = data }) end
function zo_callLater(callback) callback() end
function SetGameCameraUIMode() end
this.RefreshItemTrackerPanel = function() hudRefreshes = hudRefreshes + 1 end
this.Utils = { UserWarning = function(message) error(message) end, UserMessage = function() end }

local function Click(control)
    local handler = control.handlers.OnClicked or control.handlers.OnMouseDown
    assert(handler, "Control has no click handler: " .. control.name)
    handler(control)
end

local function Right(name) return GetControl(InventoryCompanion_GroupsWindowRightPane, name) end
local function Action(name) return GetControl(Right("ActionBar"), name) end
local function Pattern(index) return GetControl(controls["InventoryCompanion_PatternEditRow_" .. index], "Edit") end
local function PatternKind(index) return GetControl(controls["InventoryCompanion_PatternEditRow_" .. index], "LblKind") end
local function PatternKindButton(index) return GetControl(controls["InventoryCompanion_PatternEditRow_" .. index], "BtnKind") end
local function Equal(actual, expected, message) assert(actual == expected, message) end

function this.GetGroupEditorTests()
    local refresh = this.RefreshGroupsEditor
    this.RefreshGroupsEditor = function()
        groupRefreshes = groupRefreshes + 1
        refresh()
    end
    local tests = {}
    local function Add(name, run)
        table.insert(tests, { name = name, run = function()
            this.accountWide = { trackedRules = {} }
            this.character = { trackedRules = {}, useCharacterItemList = false }
            this.preLoadedRulesets = {
                default = {
                    displayName = "Default", patterns = { "a", "b", "c" },
                    display = { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false },
                },
            }
            this.InvalidateRuleCache()
            this.RefreshGroupsEditor()
            run()
        end })
    end

    Add("Group editor rename writes only the name and pattern editing preserves it", function()
        Click(Right("BtnEditGroupName"))
        Right("GroupEditBox"):SetText("Renamed")
        Right("GroupEditBox"):LoseFocus()
        local saved = this.accountWide.trackedRules.default
        Equal(saved.displayName, "Renamed", "Name should be saved")
        Equal(saved.patterns, nil, "Rename must not copy patterns")
        Equal(saved.display, nil, "Rename must not copy flags")
        local edit = Pattern(1)
        edit:SetText("a1")
        edit:LoseFocus()
        Equal(saved.displayName, "Renamed", "Pattern edit must not reset name")
        Equal(saved.addedPatterns[1], "a1", "Changed pattern should be added")
        Equal(saved.removedPatterns[1], "a", "Old pattern should be removed")
    end)

    Add("Pattern focus-loss preserves rows while refreshing HUD and Reset", function()
        local edit = Pattern(1)
        local row = controls["InventoryCompanion_PatternEditRow_1"]
        local moves, refreshes, hud = row.moves, groupRefreshes, hudRefreshes
        edit:SetText("a1")
        edit.handlers.OnTextChanged(edit)
        edit:LoseFocus()
        Equal(groupRefreshes, refreshes, "Focus-loss must not rebuild group rows")
        Equal(row.moves, moves, "Focus-loss must not reanchor rows")
        Equal(Pattern(1), edit, "Edit control must be preserved")
        Equal(edit:GetText(), "a1", "Edit text must be preserved")
        Equal(hudRefreshes, hud + 1, "Focus-loss should refresh HUD")
        Equal(Action("BtnReset").hidden, false, "Pattern override should offer Reset immediately")
        edit:SetText("a")
        edit:LoseFocus()
        Equal(this.accountWide.trackedRules.default, nil, "Reversion clears saved override")
        Equal(Action("BtnReset").hidden, true, "Reversion hides Reset without rebuilding rows")
    end)

    Add("Pattern kind toggle persists encoded exclusion and retains row text", function()
        local suffix = this.constants.RULE_PATTERN_EXCLUSION_SUFFIX
        local edit = Pattern(1)
        local kind = PatternKind(1)
        Equal(edit:GetText(), "a", "Initial pattern is shown without encoding")
        Equal(kind.color[1], 0.2, "Include label is green")
        Equal(kind.color[2], 0.8, "Include label is green")
        Equal(kind.texture, "EsoUI/Art/Bank/bank_tabicon_deposit_up.dds", "Include indicator uses deposit icon")
        kind.handlers.OnMouseEnter(kind)
        Equal(InformationTooltip.lines[1], "Include rule", "Status dot tooltip identifies the current kind")
        assert(InformationTooltip.lines[2]:find("adds an item to this group", 1, true),
            "Status dot tooltip explains include behavior")
        assert(PatternKindButton(1).handlers.OnClicked, "Swap icon hit area changes the row kind")
        local button = PatternKindButton(1)
        Equal(button.normalTexture, "EsoUI/Art/CharacterWindow/swap_button_up.dds",
            "Swap button receives its normal texture through the button API")
        Equal(button.pressedTexture, "EsoUI/Art/CharacterWindow/swap_button_down.dds",
            "Swap button receives its pressed texture")
        Equal(button.mouseOverTexture, "EsoUI/Art/CharacterWindow/swap_button_over.dds",
            "Swap button receives its hover texture")
        Equal(button.disabledTexture, "EsoUI/Art/CharacterWindow/swap_button_disabled.dds",
            "Swap button receives its disabled texture")
        PatternKindButton(1).handlers.OnMouseEnter(PatternKindButton(1))
        Equal(InformationTooltip.lines[1], "Make this an Exclude rule", "Toggle tooltip names its action")
        assert(InformationTooltip.lines[2]:find("Exclusions section", 1, true),
            "Toggle tooltip explains where the row will move")

        Click(PatternKindButton(1))
        Equal(Pattern(3):GetText(), "a", "Toggled pattern moves to the exclusion section")
        Equal(PatternKind(3).color[1], 1.0, "Exclude label is red")
        Equal(PatternKind(3).color[2], 0.3, "Exclude label is red")
        Equal(PatternKind(3).texture, "EsoUI/Art/Bank/bank_tabicon_withdraw_up.dds",
            "Moved exclusion indicator uses withdraw icon")
        Equal(Pattern(1):GetText(), "b", "Remaining includes move up")
        PatternKindButton(3).handlers.OnMouseEnter(PatternKindButton(3))
        Equal(InformationTooltip.lines[1], "Make this an Include rule", "Exclude toggle tooltip names inverse action")
        assert(InformationTooltip.lines[2]:find("above the Exclusions section", 1, true),
            "Include action tooltip explains the row's destination")
        Click(PatternKindButton(3))
        Equal(Pattern(1):GetText(), "a", "Rule returns to the include section")
        Equal(PatternKind(1).texture, "EsoUI/Art/Bank/bank_tabicon_deposit_up.dds",
            "Returning to Include restores the deposit icon on the rebound control")
        Click(PatternKindButton(1))
        local saved = this.accountWide.trackedRules.default
        Equal(saved.removedPatterns[1], "a", "Toggling removes the baseline include")
        Equal(saved.addedPatterns[1], "a" .. suffix, "Toggling adds the encoded exclusion")

        edit = Pattern(3)
        edit:SetText("a-new")
        edit:LoseFocus()
        Equal(saved.addedPatterns[1], "a-new" .. suffix, "Editing preserves exclusion kind")
        Equal(Pattern(3):GetText(), "a-new", "Suffix is hidden from the edit field")

        local delete = GetControl(controls["InventoryCompanion_PatternEditRow_3"], "BtnDelete")
        delete.handlers.OnMouseEnter(delete)
        Equal(InformationTooltip.lines[1], "Remove pattern", "Delete tooltip explains its action")
        assert(InformationTooltip.lines[2]:find("Remove this Exclude rule", 1, true),
            "Delete tooltip identifies the row kind")
        Click(delete)
        Equal(this.GetRuntimeRules().default.patterns[1], "b", "Deleting the exclusion preserves remaining includes")
        Equal(this.accountWide.trackedRules.default.removedPatterns[1], "a", "Deleted baseline include remains removed")
        Equal(this.accountWide.trackedRules.default.addedPatterns, nil, "Deleted custom exclusion is pruned")
    end)

    Add("Empty pattern rows retain their kind but compile to no match", function()
        Click(Right("BtnAddRule"))
        Equal(Pattern(1):GetText(), "", "New empty pattern is visible")
        Click(PatternKindButton(1))
        Equal(PatternKind(4).color[1], 1.0, "Empty row can be an exclusion")
        Equal(this.accountWide.trackedRules.default.addedPatterns[1],
            this.constants.RULE_PATTERN_EXCLUSION_SUFFIX, "Empty exclusion is stored with its kind")
        Equal(#this.GetRuntimeRules().default.compiledExcludedPatterns, 0,
            "Empty exclusion compiles to no matcher")
        Click(GetControl(controls["InventoryCompanion_PatternEditRow_4"], "BtnDelete"))
        Equal(this.accountWide.trackedRules.default, nil, "Deleting the empty exclusion restores defaults")
    end)

    Add("Excluded patterns appear below includes with a section divider", function()
        local suffix = this.constants.RULE_PATTERN_EXCLUSION_SUFFIX
        this.UpdateRulePatterns("default", { "a" .. suffix, "b", "c" })
        this.RefreshGroupsEditor()

        Equal(Pattern(1):GetText(), "b", "First include appears at the top")
        Equal(Pattern(2):GetText(), "c", "Second include appears before exclusions")
        assert(PatternKind(1).color[2] == 0.8, "Top row is an include")
        Equal(Pattern(3):GetText(), "a", "Excluded pattern appears at the bottom")
        Equal(PatternKind(3).color[1], 1.0, "Bottom row is an exclusion")

        local divider = controls["InventoryCompanion_PatternExclusionDivider_1"]
        assert(divider and not divider.hidden, "Include/exclude divider is visible")
        Equal(divider.anchor.y, 72, "Divider follows the include rows")
        Equal(controls["InventoryCompanion_PatternEditRow_3"].anchor.y, 100,
            "Exclude row follows the divider")

        Click(PatternKindButton(1))
        Equal(Pattern(1):GetText(), "c", "Toggled row moves below the remaining include")
        Equal(PatternKind(1).color[2], 0.8, "First row remains an include")
        Equal(Pattern(3):GetText(), "b", "Toggled pattern moves to the exclusion section")
        Equal(PatternKind(3).color[1], 1.0, "Moved row shows its new kind")
        Equal(divider.anchor.y, 36, "Divider moves with the include/exclude boundary")
        Equal(controls["InventoryCompanion_PatternEditRow_2"].anchor.y, 64,
            "Exclusions are repositioned immediately after the divider")

        Click(PatternKindButton(1))
        assert(divider.hidden, "Divider is hidden when there are no Include rows")
        this.UpdateRulePatterns("default", { "a", "b", "c" })
        this.RefreshGroupsEditor()
        assert(divider.hidden, "Divider is hidden when there are no Exclude rows")
    end)

    Add("Group editor pattern add and delete reconcile deltas", function()
        Click(Right("BtnAddRule"))
        local edit = Pattern(1)
        Equal(edit:GetText(), "", "Added blank sorts first after explicit list rebuild")
        edit:SetText("d")
        edit:LoseFocus()
        Equal(this.accountWide.trackedRules.default.addedPatterns[1], "d", "Added pattern saved")
        Click(GetControl(controls["InventoryCompanion_PatternEditRow_2"], "BtnDelete"))
        Equal(this.accountWide.trackedRules.default.removedPatterns[1], "a", "Deleting baseline records removal")
    end)

    Add("Group editor reset preserves display settings and hidden state", function()
        local original = this.GetRuntimeRules()
        Click(Action("BtnHide"))
        Equal(this.GetActiveTrackedRules().default, nil, "Hide excludes group")
        assert(this.GetRuntimeRules() ~= original, "Hide invalidates")
        Equal(Action("BtnHide"):GetText(), "Unhide Group", "Hidden group offers Unhide")
        Click(Action("BtnHide"))
        assert(this.GetActiveTrackedRules().default, "Unhide restores group")
        Equal(this.accountWide.trackedRules.default, nil, "Default unhidden state pruned")
        this.UpdateRuleFlag("default", "notify", true)
        this.UpdateRuleFlag("default", "isHidden", true)
        this.RefreshGroupsEditor()
        Equal(Action("BtnReset").hidden, true, "Display-only overrides do not offer Reset")
        this.UpdateRuleProperty("default", "displayName", "Renamed")
        this.UpdateRulePatterns("default", {})
        this.RefreshGroupsEditor()
        Click(Action("BtnReset"))
        Equal(this.accountWide.trackedRules.default.displayName, nil, "Reset clears custom name")
        Equal(this.GetRuntimeRules().default.display.notify, true, "Reset preserves notify flag")
        Equal(this.GetRuntimeRules().default.display.isHidden, true, "Reset preserves hidden state")
        Equal(#this.GetRuntimeRules().default.patterns, 3, "Reset restores patterns")
        Equal(Action("BtnReset").hidden, true, "Reset hides once only display overrides remain")
        Equal(Action("BtnHide"):GetText(), "Unhide Group", "Hidden group stays hidden after reset")
    end)

    Add("Group editor creates and deletes sparse custom groups", function()
        local originalClock = GetGameTimeMilliseconds
        GetGameTimeMilliseconds = function() return 100 end
        Click(GetControl(GetControl(InventoryCompanion_GroupsWindow, "TopActionBar"), "BtnNewGroup"))
        local saved = this.accountWide.trackedRules.custom_100
        assert(saved, "New group is saved")
        Equal(saved.displayName, "New Group", "New group gets a name")
        Equal(saved.patterns, nil, "New group does not persist an empty pattern list")
        Equal(saved.display, nil, "New group does not persist default flags")
        assert(this.GetRuntimeRules().custom_100, "New group is cached")
        Click(Action("BtnHide"))
        Equal(this.GetActiveTrackedRules().custom_100, nil, "Custom hide invalidates")
        Click(Action("BtnHide"))
        assert(this.GetActiveTrackedRules().custom_100, "Custom unhide invalidates")
        Click(Action("BtnDelete"))
        Equal(this.accountWide.trackedRules.custom_100, nil, "Delete removes saved group")
        Equal(this.GetRuntimeRules().custom_100, nil, "Delete removes cached group")
        GetGameTimeMilliseconds = originalClock
    end)

    Add("Missing maintained editor functions and controls fail at their use", function()
        local refresh = this.RefreshItemTrackerPanel
        this.RefreshItemTrackerPanel = nil
        local ok, err = pcall(function() Click(Action("BtnHide")) end)
        this.RefreshItemTrackerPanel = refresh
        assert(not ok and tostring(err):find("RefreshItemTrackerPanel", 1, true), "Missing required refresh must throw")
        local getControl = GetControl
        GetControl = function(parent, name)
            if parent == InventoryCompanion_GroupsWindowLeftPane and name == "ScrollChild" then return nil end
            return getControl(parent, name)
        end
        ok, err = pcall(this.RefreshGroupsEditor)
        GetControl = getControl
        assert(not ok and tostring(err):find("ScrollChild", 1, true), "Missing required scroll child must throw")
        ok, err = pcall(dialogs.InventoryCompanion_CONFIRM_RESET_GROUP_DIALOG.buttons[1].callback, { data = {} })
        assert(not ok and tostring(err):find("requires a group ID", 1, true), "Missing internal dialog payload must throw")
    end)

    return tests
end
