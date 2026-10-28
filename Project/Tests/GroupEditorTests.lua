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
    function control:SetAnchor() self.moves = self.moves + 1 end
    function control:SetFont() end
    function control:SetColor() end
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
SCENE_SHOWING, SCENE_HIDDEN = "showing", "hidden"
SCENE_MANAGER = {}
ZO_Scene = { New = function()
    return { AddFragment = function() end, RegisterCallback = function() end }
end }
ZO_FadeSceneFragment = { New = function() return {} end }
GAMEPAD_DIALOGS = { BASIC = 1 }
SI_DIALOG_CANCEL = "Cancel"
InventoryCompanion_GroupsWindow = Control("window")
InventoryCompanion_GroupsWindowLeftPane = Control("left")
InventoryCompanion_GroupsWindowRightPane = Control("right")
function ZO_Dialogs_RegisterCustomDialog(name, data) dialogs[name] = data end
function ZO_Dialogs_ShowDialog(name, data) dialogs[name].buttons[1].callback({ data = data }) end
function zo_callLater(callback) callback() end
function SetGameCameraUIMode() end
function GetGameTimeMilliseconds() return 100 end
this.RefreshItemTrackerPanel = function() hudRefreshes = hudRefreshes + 1 end
this.Utils = { UserWarning = function(message) error(message) end, UserMessage = function() end }

local function Click(control)
    assert(control.handlers.OnClicked, "Control has no click handler: " .. control.name)
    control.handlers.OnClicked(control)
end

local function Right(name) return GetControl(InventoryCompanion_GroupsWindowRightPane, name) end
local function Action(name) return GetControl(Right("ActionBar"), name) end
local function Pattern(index) return GetControl(controls["InventoryCompanion_PatternEditRow_" .. index], "Edit") end
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

    Add("Group editor hide, unhide and full reset invalidate runtime rules", function()
        local original = this.GetRuntimeRules()
        Click(Action("BtnHide"))
        Equal(this.GetActiveTrackedRules().default, nil, "Hide excludes group")
        assert(this.GetRuntimeRules() ~= original, "Hide invalidates")
        Equal(Action("BtnHide"):GetText(), "Unhide Group", "Hidden group offers Unhide")
        Click(Action("BtnHide"))
        assert(this.GetActiveTrackedRules().default, "Unhide restores group")
        Equal(this.accountWide.trackedRules.default, nil, "Default unhidden state pruned")
        this.UpdateRuleFlag("default", "notify", true)
        this.UpdateRuleProperty("default", "displayName", "Renamed")
        this.UpdateRulePatterns("default", {})
        this.RefreshGroupsEditor()
        Click(Action("BtnReset"))
        Equal(this.accountWide.trackedRules.default, nil, "Reset clears all fields")
        Equal(this.GetRuntimeRules().default.display.notify, false, "Reset restores flags")
        Equal(#this.GetRuntimeRules().default.patterns, 3, "Reset restores patterns")
    end)

    Add("Group editor creates and deletes sparse custom groups", function()
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
    end)

    return tests
end
