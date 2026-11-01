-- Tracking/EditPanelTabManager.lua
InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

this.state = this.state or {}
this.state.lastActiveEditTab = this.state.lastActiveEditTab or "InventoryCompanion_TrackedItemsScene"

local ITEMS_SCENE = "InventoryCompanion_TrackedItemsScene"
local GROUPS_SCENE = "InventoryCompanion_GroupsScene"
local AUTOCATEGORY_SCENE = "InventoryCompanion_AutoCategoryScene"

local editorTabs = {
    { scene = ITEMS_SCENE, window = "InventoryCompanion_TrackedItemsWindow", refresh = "RefreshTrackedItemsEditor" },
    { scene = GROUPS_SCENE, window = "InventoryCompanion_GroupsWindow", refresh = "RefreshGroupsEditor" },
    { scene = AUTOCATEGORY_SCENE, window = "InventoryCompanion_AutoCategoryWindow", refresh = "RefreshAutoCategoryEditor" },
}

local function GetTab(sceneName)
    for _, tab in ipairs(editorTabs) do
        if tab.scene == sceneName then return tab end
    end
    error("Unknown editor tab scene: " .. tostring(sceneName))
end

local function GetShowingTab()
    for _, tab in ipairs(editorTabs) do
        if SCENE_MANAGER:IsShowing(tab.scene) then return tab end
    end
end

------------------------------------------------------------------
-- Panel Switching & Toggle Endpoints
------------------------------------------------------------------
local function SyncPanelGeometry(sourceWindow, targetWindow)
    targetWindow:ClearAnchors()
    targetWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sourceWindow:GetLeft(), sourceWindow:GetTop())
    targetWindow:SetDimensions(sourceWindow:GetWidth(), sourceWindow:GetHeight())
end

function this.IsEditorWindowOpen()
    for _, tab in ipairs(editorTabs) do
        local window = _G[tab.window]
        if window and not window:IsHidden() then return true, window end
    end
    return false
end

function this.UpdateEditorLayout()
    local isOpen, openWindow = this.IsEditorWindowOpen()
    if isOpen and this.AdjustTrackerPositionForEditor then
        this.Utils.DebugMessage(" -> Adjusting for editor window")
        this.AdjustTrackerPositionForEditor(openWindow)
    else
        this.Utils.DebugMessage("<- Restoring Tracker Position")
        if this.RestoreTrackerPosition then
            this.RestoreTrackerPosition()
        end
    end
end

local function OpenEditorTab(sceneName)
    local target = GetTab(sceneName)
    local showing = GetShowingTab()
    if showing and showing ~= target then
        SyncPanelGeometry(_G[showing.window], _G[target.window])
    end

    this.state.lastActiveEditTab = sceneName
    for _, tab in ipairs(editorTabs) do
        if tab ~= target then SCENE_MANAGER:Hide(tab.scene) end
    end
    SCENE_MANAGER:Show(sceneName)
    this[target.refresh]()
end

function this.OpenEditItemsPanel()
    OpenEditorTab(ITEMS_SCENE)
end

function this.OpenEditGroupsPanel()
    OpenEditorTab(GROUPS_SCENE)
end

function this.OpenAutoCategoryPanel()
    assert(this.AutoCategoryIntegration.IsEditorActive(), "AutoCategory editor opened while integration is inactive")
    OpenEditorTab(AUTOCATEGORY_SCENE)
end

function this.OpenSettingsFromEditor()
    for _, tab in ipairs(editorTabs) do
        SCENE_MANAGER:Hide(tab.scene)
    end
    this.OpenSettingsPanel()
end

function this.ToggleTrackedItemsEditor()
    local showing = GetShowingTab()
    if showing then
        this.state.lastActiveEditTab = showing.scene
        SCENE_MANAGER:Hide(showing.scene)
        return
    end

    local sceneName = this.state.lastActiveEditTab
    -- The AutoCategory tab may have been closed before integration was disabled or AutoCategory was removed.
    if sceneName == AUTOCATEGORY_SCENE and not this.AutoCategoryIntegration.IsEditorActive() then
        sceneName = GROUPS_SCENE
    end
    SCENE_MANAGER:Show(sceneName)
    this[GetTab(sceneName).refresh]()
end
