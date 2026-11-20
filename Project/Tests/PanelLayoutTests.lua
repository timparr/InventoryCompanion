local function Load()
    InventoryCompanion = { state = {}, Utils = {}, SetVisibilityTickerNeeded = function() end }
    IsShiftKeyDown = function() return true end
    assert(loadstring(PanelLayoutSource))()
    return InventoryCompanion, InventoryCompanion.PanelLayout
end

local function Control(x, y, width, height)
    local control = { x = x, y = y, width = width, height = height, hidden = false, writes = 0, handlers = {} }
    function control:GetLeft() return self.x end
    function control:GetTop() return self.y end
    function control:GetWidth() return self.width end
    function control:GetHeight() return self.height end
    function control:IsHidden() return self.hidden end
    function control:SetHidden(value) self.hidden = value end
    function control:ClearAnchors() end
    function control:SetAnchor(_, _, _, left, top) self.x, self.y = left, top; self.writes = self.writes + 1 end
    function control:SetHandler(key, handler) self.handlers[key] = handler end
    function control:StopMoving() self.handlers.OnMoveStop() end
    return control
end

local function Fixture(scene)
    local addon, layout = Load()
    TOPLEFT = 1
    GuiRoot = Control(0, 0, 1000, 700)
    ZO_CompassFrame = Control(0, 0, 1, 1)
    ZO_CompassFrame.hidden = true
    for _, name in ipairs({ "ZO_PlayerInventory", "ZO_PlayerBank", "ZO_PlayerBankMenu",
        "ZO_HouseBank", "ZO_HouseBankMenu", "ZO_GuildBank", "ZO_GuildBankMenu",
        "ZO_FurnitureVault", "ZO_FurnitureVaultMenu", "ZO_GameMenu_InGame",
        "ZO_OptionsWindow", "ZO_AddOns", "LAMAddonSettingsWindow", "ZO_StoreWindow", "ZO_BuyBack",
        "ZO_RepairWindow", "ZO_StoreWindowMenu", "ZO_StorePanelTabContainer",
        "ZO_Character", "ZO_CharacterWindowStats", "ZO_PlayerProgress", "ZO_MainMenuCategoryBar",
        "ZO_SharedRightPanelBackground", "ZO_SharedRightPanelBackgroundLeft" }) do
        _G[name] = nil
    end
    local state = { scene = scene, currencyVisible = false, saves = 0 }
    state.profile = {
        Tracker = { showTrackedItemsPanel = true, Layout_NoScene = { offsetX = 50, offsetY = 50 } },
        Currency = { Layout_NoScene = { offsetX = 700, offsetY = 100 } },
    }
    SCENE_MANAGER = { IsShowing = function(_, name) return name == state.scene end }
    IsInGamepadPreferredMode = function() return false end
    GetCurrentCharacterId = function() return "character" end
    addon.GetSettingsProfile = function() return state.profile end
    addon.GetPanelSettings = function(key) return state.profile[key] end
    addon.GetPanelLayout = function(key, name, character)
        local panel = state.profile[key]
        if name == "Layout_NoScene" then return panel[name] end
        return panel[name] and panel[name][character]
    end
    addon.SavePanelLayout = function(key, name, character, x, y)
        state.saves = state.saves + 1
        local panel = state.profile[key]
        if name == "Layout_NoScene" then panel[name] = { offsetX = x, offsetY = y }
        else
            panel[name] = panel[name] or {}
            panel[name][character] = { offsetX = x, offsetY = y }
        end
    end
    addon.ResetPanelLayouts = function(key)
        state.profile[key].Layout_NoScene = { offsetX = 50, offsetY = 50 }
    end
    addon.IsEditorWindowOpen = function() return false end
    addon.Utils.IsItemInteractionActive = function() return false end
    addon.GetProgressBarResources = function() return {} end
    addon.HasVisibleCurrencyResources = function() return state.currencyVisible end
    addon.HasVisibleCapacityResources = function() return false end
    state.tracker, state.currency = Control(0, 0, 100, 100), Control(0, 0, 120, 80)
    layout.Initialize()
    layout.RegisterPanel("Tracker", state.tracker)
    layout.RegisterPanel("Currency", state.currency)
    return addon, layout, state
end

function GetPanelLayoutTests()
    return {
        {
            name = "Panel layout requests the visibility ticker only while a HUD consumer needs it",
            run = function()
                local addon, layout, state = Fixture(nil)
                local needed
                addon.SetVisibilityTickerNeeded = function(value) needed = value end
                state.profile.Tracker.showTrackedItemsPanel = false
                layout.CompleteInitialization()
                assert(needed == false)

                state.profile.Tracker.showTrackedItemsPanel = true
                layout.UpdateVisibility()
                assert(needed and state.tracker:IsHidden(), "A hidden compass must not stop observation")
                state.currencyVisible = true
                state.profile.Tracker.showTrackedItemsPanel = false
                layout.UpdateVisibility()
                assert(needed, "The currency panel still needs observation")
                state.currencyVisible = false

                local key = "capacity:bag"
                local barSettings = { showBar = true, Layout_NoScene = { offsetX = 300, offsetY = 100 } }
                state.profile[key] = barSettings
                addon.GetProgressBarSettings = function() return barSettings end
                addon.GetProgressBarResources = function() return { { key = key } } end
                addon.GetProgressBarResourceValues = function() return { amount = 5, cap = 10 } end
                layout.RegisterPanel(key, Control(0, 0, 200, 30))
                layout.UpdateVisibility()
                assert(needed, "A standalone bar independently needs observation")
                barSettings.showBar = false
                layout.UpdateVisibility()
                assert(needed == false)

                addon.state.isCurrencySettingsOpen = true
                layout.UpdateContext()
                assert(needed and state.currency:IsHidden(), "Observe input mode changes even in keyboard mode")
                IsInGamepadPreferredMode = function() return true end
                layout.UpdateContext()
                assert(needed and not state.currency:IsHidden())
                addon.state.isCurrencySettingsOpen = false
                layout.UpdateContext()
                assert(needed == false and state.currency:IsHidden())
            end,
        },
        {
            name = "Panel layout default drop docks and aligns while Shift preserves the exact scene drop",
            run = function()
                local _, layout, state = Fixture("inventory")
                ZO_PlayerInventory = Control(800, 0, 200, 700)
                state.currencyVisible = true
                state.profile.Currency.Layout_NoScene = { offsetX = 200, offsetY = 100 }
                layout.CompleteInitialization()
                local shift = false
                IsShiftKeyDown = function() return shift end
                layout.OnMoveStart("Tracker")
                state.tracker.x, state.tracker.y = 204, 189
                shift = true
                layout.OnMoveStop("Tracker")
                assert(state.tracker.x == 204 and state.tracker.y == 189)
                layout.OnMoveStart("Tracker")
                shift = false
                layout.OnMoveStop("Tracker")
                assert(state.tracker.x == 200 and state.tracker.y == 185)
                assert(state.currency.x == 200 and state.currency.y == 100)
                local saved = state.profile.Tracker.Layout_InventoryScene.character
                assert(saved.offsetX == 200 and saved.offsetY == 185 and state.saves == 2)
                state.scene = nil; layout.UpdateContext()
                assert(state.tracker.x == 50 and state.tracker.y == 50)
                state.scene = "inventory"; layout.UpdateContext()
                assert(state.tracker.x == 200 and state.tracker.y == 185)
                layout.OnMoveStart("Tracker")
                state.scene = nil; layout.UpdateContext()
                assert(state.saves == 2, "Canceling a drag must not save")
            end,
        },
        {
            name = "Panel layout snapping ignores hidden and distant targets and rejects ZOS overlap",
            run = function()
                local _, layout, state = Fixture("inventory")
                ZO_PlayerInventory = Control(200, 185, 600, 515)
                state.profile.Currency.Layout_NoScene = { offsetX = 200, offsetY = 100 }
                layout.CompleteInitialization()
                IsShiftKeyDown = function() return false end
                local function Drop(x, y)
                    layout.OnMoveStart("Tracker")
                    state.tracker.x, state.tracker.y = x, y
                    layout.OnMoveStop("Tracker")
                    assert(state.tracker.x == x and state.tracker.y == y)
                end
                Drop(204, 189) -- hidden target
                state.currencyVisible = true
                layout.UpdateVisibility()
                Drop(204, 189) -- docking here would overlap ZOS UI
                Drop(204, 400) -- aligned edge, but target is far away
                state.scene = nil
                ZO_CompassFrame.hidden = false
                layout.UpdateContext()
                layout.OnMoveStart("Tracker")
                state.tracker.x, state.tracker.y = 204, 189
                layout.OnMoveStop("Tracker")
                local saved = state.profile.Tracker.Layout_NoScene
                assert(saved.offsetX == 200 and saved.offsetY == 185, "Normal drops must save only the normal layout")
            end,
        },
        {
            name = "Panel layout full-width bars dock side by side or clear overlap beyond the usual range",
            run = function()
                local addon, layout, state = Fixture("inventory")
                ZO_PlayerInventory = Control(800, 0, 200, 700)
                state.profile["capacity:bag"] = { Layout_NoScene = { offsetX = 200, offsetY = 100 } }
                state.profile["capacity:bank"] = { Layout_NoScene = { offsetX = 500, offsetY = 100 } }
                addon.GetProgressBarResources = function()
                    return { { key = "capacity:bag" }, { key = "capacity:bank" } }
                end
                addon.GetProgressBarSettings = function() return { showBar = true } end
                addon.GetProgressBarResourceValues = function() return 1 end
                local target = Control(0, 0, 234, 22)
                local bar = Control(0, 0, 234, 22)
                layout.RegisterPanel("capacity:bag", target)
                layout.RegisterPanel("capacity:bank", bar)
                layout.CompleteInitialization()
                local shift = false
                IsShiftKeyDown = function() return shift end
                local function Drop(x, y)
                    layout.OnMoveStart("capacity:bank")
                    bar.x, bar.y = x, y
                    layout.OnMoveStop("capacity:bank")
                end
                Drop(440, 101)
                assert(bar.x == target.x + target.width + 5 and bar.y == target.y)
                Drop(400, 102)
                assert(bar.x == 400 and bar.y == 127, "Choose the shortest clear move, even beyond 12 px")
                ZO_PlayerInventory = Control(0, 123, 800, 577)
                Drop(400, 102)
                assert(bar.x == 400 and bar.y == 73, "Use the next clear edge if ESO UI blocks the nearest")
                shift = true
                Drop(400, 102)
                assert(bar.x == 400 and bar.y == 102, "Shift preserves an intentional overlap")
                assert(target.x == 200 and target.y == 100)
            end,
        },
        {
            name = "Panel layout resource registration preserves scene anchors across bar refresh and setting changes",
            run = function()
                local profile = { PanelSettings = {}, progressBarAlertColors = {} }
                local registered = {}
                InventoryCompanion = {
                    GetSettingsProfile = function() return profile end,
                    GetCappedCurrencyList = function() return {} end,
                    GetPanelLayout = function(key) return profile.PanelSettings[key].Layout_NoScene end,
                    SavePanelLayout = function(key, _, _, x, y)
                        profile.PanelSettings[key].Layout_NoScene = { offsetX = x, offsetY = y }
                    end,
                    PanelLayout = {
                        RegisterPanel = function(key, control) registered[key] = control end,
                        UpdateVisibility = function() end,
                    },
                }
                local addon = InventoryCompanion
                local function Visual()
                    local c = Control(0, 0, 300, 30)
                    for _, method in ipairs({ "SetTexture", "SetDrawLayer", "SetDrawLevel", "SetTextureCoords",
                        "SetBarAlignment", "SetMinMax", "SetValue", "SetText" }) do c[method] = function() end end
                    return c
                end
                ZO_ColorDef = { New = function() return {} end }
                ZO_XP_BAR_GRADIENT_COLORS = {}
                ZO_StatusBar_SetGradientColor = function() end
                CreateControlFromVirtual = Visual
                GetControl = Visual
                GetNumBagUsedSlots = function() return 1 end
                GetBagSize = function() return 100 end
                GetBagUseableSize = function() return 100 end
                assert(loadstring(ProgressBarSource))()
                assert(loadstring(ResourceBarSource))()
                addon.InitializeProgressBarResources()
                assert(addon.GetProgressBarSettings("capacity:bag").offsetY == 90)
                addon.InitResourceProgressBars()
                local bag = assert(registered["capacity:bag"])
                bag.x, bag.y = 700, 400
                addon.RefreshResourceProgressBars()
                assert(bag.x == 700 and bag.y == 400, "Refresh must not restore normal anchors")
                addon.SetProgressBarSetting("capacity:bag", "showBar", false)
                assert(profile.PanelSettings["capacity:bag"].Layout_NoScene.offsetY == 90)
                addon.SetProgressBarSetting("capacity:bag", "showBar", true)
                assert(profile.PanelSettings["capacity:bag"].Layout_NoScene.offsetY == 90,
                    "Pruning a default preference must retain its layouts")
            end,
        },
        {
            name = "Panel layout deterministic side stacks, spacing and rollback",
            run = function()
                local _, layout = Load()
                local window = { x = 200, y = 0, width = 300, height = 400 }
                local panels = { { key = "a", width = 100, height = 80 }, { key = "b", width = 150, height = 60 } }
                local result = layout.PlaceDisplaced(panels, window, { window }, {}, 1000, 500)
                assert(result.a.offsetX == 505 and result.a.offsetY == 0)
                assert(result.b.offsetX == 505 and result.b.offsetY == 85)
                local blocker = { x = 505, y = 0, width = 150, height = 450 }
                result = layout.PlaceDisplaced(panels, window, { window, blocker }, {}, 1000, 500)
                assert(result.a.offsetX == 95 and result.b.offsetX == 45, "Retry must discard right-side partial results")
                local retained = { x = 505, y = 0, width = 100, height = 10 }
                result = layout.PlaceDisplaced(panels, window, { window }, { retained }, 1000, 500)
                assert(result.a.offsetY == 15 and result.b.offsetY == 100)
            end,
        },
        {
            name = "Panel layout fallback reserves retained panels without sacrificing ZOS avoidance",
            run = function()
                local _, layout = Load()
                local panels = { { key = "a", width = 100, height = 100 } }
                local window = { x = 300, y = 0, width = 400, height = 100 }
                local retained = {
                    { x = 195, y = 0, width = 100, height = 700 },
                    { x = 705, y = 0, width = 100, height = 700 },
                }
                local result = layout.PlaceDisplaced(panels, window, { window }, retained, 1000, 700)
                assert(result.a.offsetX == 900 and result.a.offsetY == 0,
                    "Fallback must skip retained panels when a clear candidate exists")
                window = { x = 800, y = 0, width = 200, height = 700 }
                retained = { { x = 0, y = 0, width = 800, height = 700 } }
                result = layout.PlaceDisplaced(panels, window, { window }, retained, 1000, 700)
                assert(result.a.offsetX == 695,
                    "When all candidates overlap IC, retain a ZOS-clear candidate rather than the first fallback")
            end,
        },
        {
            name = "Panel layout constrained fallback staggers 20 pixels and clamps oversized panels",
            run = function()
                local _, layout = Load()
                local window = { x = 0, y = 0, width = 500, height = 300 }
                local panels = { { key = "a", width = 100, height = 80 }, { key = "b", width = 100, height = 80 } }
                local result = layout.PlaceDisplaced(panels, window, { window }, {}, 500, 300)
                assert(result.b.offsetX - result.a.offsetX == 20 and result.b.offsetY - result.a.offsetY == 20)
                panels[1].width, panels[1].height = 600, 400
                result = layout.PlaceDisplaced(panels, window, { window }, {}, 500, 300)
                assert(result.a.offsetX == 0 and result.a.offsetY == 0)
            end,
        },
        {
            name = "Panel layout startup placeholder visibility drag and normal restoration",
            run = function()
                local addon, layout = Load()
                TOPLEFT = 1
                GuiRoot = Control(0, 0, 1000, 700)
                ZO_PlayerBank = Control(0, 0, 400, 500)
                ZO_PlayerInventory = nil
                ZO_CompassFrame = Control(0, 0, 1, 1)
                local scene, character = "bank", "character-one"
                SCENE_MANAGER = { IsShowing = function(_, name) return scene == name end }
                IsInGamepadPreferredMode = function() return false end
                GetCurrentCharacterId = function() return character end
                local profile = { Tracker = { showTrackedItemsPanel = true,
                    Layout_NoScene = { offsetX = 50, offsetY = 50 } },
                    Currency = { Layout_NoScene = { offsetX = 20, offsetY = 200 } } }
                addon.GetSettingsProfile = function() return profile end
                addon.GetPanelSettings = function(key) return assert(profile[key]) end
                addon.GetPanelLayout = function(key, name, id)
                    local panel = profile[key]
                    if name == "Layout_NoScene" then return panel[name] end
                    return panel[name] and panel[name][id]
                end
                addon.SavePanelLayout = function(key, name, id, x, y)
                    if name == "Layout_NoScene" then profile[key][name] = { offsetX = x, offsetY = y }
                    else
                        profile[key][name] = profile[key][name] or {}
                        profile[key][name][id] = { offsetX = x, offsetY = y }
                    end
                end
                addon.IsEditorWindowOpen = function() return false end
                addon.GetProgressBarResources = function() return {} end
                addon.HasVisibleCurrencyResources = function() return false end
                addon.HasVisibleCapacityResources = function() return false end
                local tracker = Control(0, 0, 100, 100)
                layout.Initialize()
                layout.RegisterPanel("Tracker", tracker)
                assert(tracker.x == 50)
                layout.UpdateContext()
                assert(tracker.x == 50, "Startup callbacks cannot enter scenes")
                layout.CompleteInitialization()
                assert(tracker.x == 405 and not tracker.hidden)
                local writes = tracker.writes
                tracker.width = 200
                for _ = 1, 20 do layout.UpdateContext() end
                assert(tracker.writes == writes, "Unobstructed growth must not force anchors")
                layout.OnMoveStart("Tracker")
                tracker.x, tracker.y = 650, 200
                layout.OnMoveStop("Tracker")
                assert(profile.Tracker.Layout_BankScene[character].offsetX == 650)
                assert(profile.Tracker.Layout_NoScene.offsetX == 50)
                scene = nil; layout.UpdateContext()
                assert(tracker.x == 50 and tracker.y == 50)
                scene = "bank"; layout.UpdateContext()
                assert(tracker.x == 650 and tracker.y == 200)
                layout.OnMoveStart("Tracker"); tracker.x = 700
                scene = nil; layout.UpdateContext()
                assert(tracker.x == 50 and profile.Tracker.Layout_BankScene[character].offsetX == 650)
                profile.Tracker.showTrackedItemsPanel = false
                layout.UpdateContext()
                assert(tracker.hidden)
                profile.Tracker.showTrackedItemsPanel = true
                ZO_PlayerInventory = Control(0, 0, 400, 500)
                ZO_HouseBank = Control(0, 0, 400, 500)
                ZO_GuildBank = Control(0, 0, 400, 500)
                ZO_GameMenu_InGame = Control(0, 0, 400, 500)
                for _, mapping in ipairs({
                    { "inventory", "Layout_InventoryScene" }, { "houseBank", "Layout_HouseBankScene" },
                    { "guildBank", "Layout_GuildBankScene" }, { "store", "Layout_MerchantScene" },
                    { "store_keyboard", "Layout_MerchantScene" }, { "fence_keyboard", "Layout_FenceScene" },
                    { "gameMenuInGame", "Layout_SettingsScene" },
                }) do
                    scene = mapping[1]
                    addon.state.isCurrencySettingsOpen = scene == "gameMenuInGame"
                    layout.UpdateContext()
                    assert(not tracker.hidden)
                    layout.OnMoveStart("Tracker")
                    tracker.x, tracker.y = 700, 300
                    layout.OnMoveStop("Tracker")
                    assert(profile.Tracker[mapping[2]][character].offsetX == 700, mapping[1])
                    scene = nil
                    addon.state.isCurrencySettingsOpen = false
                    layout.UpdateContext()
                    assert(tracker.x == 50)
                end
                local merchantSaved = profile.Tracker.Layout_MerchantScene
                profile.Tracker.Layout_MerchantScene = nil
                ZO_PlayerInventory.hidden = true
                for _, name in ipairs({ "ZO_StoreWindow", "ZO_BuyBack", "ZO_RepairWindow" }) do
                    _G[name] = Control(0, 0, 400, 500)
                    scene = "store"; layout.UpdateContext()
                    assert(not layout.IsNormalContext() and tracker.x == 405,
                        name .. " must establish merchant context when inventory is hidden")
                    _G[name].width = 450
                    layout.UpdateContext()
                    assert(tracker.x == 455, "Merchant growth must correct newly obstructed positions")
                    scene = nil; layout.UpdateContext()
                    _G[name] = nil
                end
                ZO_PlayerInventory.hidden = false
                profile.Tracker.Layout_MerchantScene = merchantSaved
                for _, mapping in ipairs({
                    { "store", "ZO_StoreWindow" },
                    { "store", "ZO_BuyBack" },
                    { "store", "ZO_RepairWindow" },
                    { "store", "ZO_StoreWindowMenu" },
                    { "store", "ZO_StorePanelTabContainer" },
                    { "fence_keyboard", "ZO_Fence_Keyboard_WindowMenu" },
                }) do
                    local savedKey = mapping[1] == "store" and "Layout_MerchantScene" or "Layout_FenceScene"
                    local saved = profile.Tracker[savedKey]
                    profile.Tracker[savedKey] = nil
                    _G[mapping[2]] = Control(405, 0, 150, 500)
                    scene = mapping[1]; layout.UpdateContext()
                    assert(tracker.y >= 505,
                        mapping[2] .. " must block automatic placement alongside inventory")
                    scene = nil; layout.UpdateContext()
                    _G[mapping[2]] = nil
                    profile.Tracker[savedKey] = saved
                end
                local editor = Control(0, 0, 400, 500)
                addon.IsEditorWindowOpen = function() return true, editor end
                layout.UpdateContext()
                editor = Control(0, 0, 450, 550)
                layout.UpdateContext()
                assert(tracker.x == 455, "Editor geometry changes must correct overlap within its shared layout")
                layout.OnMoveStart("Tracker"); tracker.x, tracker.y = 700, 200
                layout.OnMoveStop("Tracker")
                assert(profile.Tracker.Layout_EditorScene[character].offsetY == 200)
                addon.IsEditorWindowOpen = function() return false end
                layout.UpdateContext()
                layout.OnMoveStart("Tracker"); tracker.x, tracker.y = 75, 85
                layout.OnMoveStop("Tracker")
                assert(profile.Tracker.Layout_NoScene.offsetX == 75)
                assert(profile.Tracker.Layout_EditorScene[character].offsetX == 700)
                character = "character-two"
                scene = "bank"; layout.UpdateContext()
                assert(tracker.x == 405, "Another character must not inherit saved scene coordinates")
                layout.OnMoveStart("Tracker"); tracker.x, tracker.y = 800, 250
                layout.OnMoveStop("Tracker")
                assert(profile.Tracker.Layout_BankScene["character-one"].offsetX == 650)
                assert(profile.Tracker.Layout_BankScene["character-two"].offsetX == 800)
            end,
        },
        {
            name = "Panel layout bank and vault deposit withdrawal share visibility and saved positions",
            run = function()
                for _, mapping in ipairs({
                    { "bank", "ZO_PlayerBank", "ZO_PlayerBankMenu", "Layout_BankScene" },
                    { "houseBank", "ZO_HouseBank", "ZO_HouseBankMenu", "Layout_HouseBankScene" },
                    { "guildBank", "ZO_GuildBank", "ZO_GuildBankMenu", "Layout_GuildBankScene" },
                    { "furnitureVault", "ZO_FurnitureVault", "ZO_FurnitureVaultMenu", "Layout_FurnitureVaultScene" },
                }) do
                    local _, layout, state = Fixture(mapping[1])
                    local withdrawal = Control(0, 0, 400, 500)
                    withdrawal.hidden = true
                    _G[mapping[2]] = withdrawal
                    _G[mapping[3]] = Control(0, 0, 400, 30)
                    ZO_PlayerInventory = Control(0, 0, 400, 500)
                    layout.CompleteInitialization()
                    assert(not state.tracker.hidden and state.tracker.x == 405, mapping[1] .. " deposit")
                    layout.OnMoveStart("Tracker")
                    state.tracker.x, state.tracker.y = 650, 200
                    layout.OnMoveStop("Tracker")
                    assert(state.profile.Tracker[mapping[4]].character.offsetX == 650)
                    withdrawal.hidden, ZO_PlayerInventory.hidden = false, true
                    layout.UpdateContext()
                    assert(not state.tracker.hidden and state.tracker.x == 650, mapping[1] .. " withdrawal")
                    withdrawal.hidden, ZO_PlayerInventory.hidden = true, false
                    layout.UpdateContext()
                    assert(not state.tracker.hidden and state.tracker.x == 650)
                    assert(state.saves == 1, "Tab changes must not persist automatic coordinates")
                    state.scene = nil; layout.UpdateContext()
                    assert(state.tracker.x == 50 and state.tracker.hidden)
                    state.scene = mapping[1]; layout.UpdateContext()
                    assert(state.tracker.x == 650, "Re-entry must restore the shared saved tab position")
                end
            end,
        },
        {
            name = "Panel layout hides the HUD in other settings and restores it after closing the menu",
            run = function()
                local addon, layout, state = Fixture("gameMenuInGame")
                ZO_CompassFrame.hidden = false
                ZO_OptionsWindow = Control(0, 0, 400, 500)
                LAMAddonSettingsWindow = Control(0, 0, 400, 500)
                layout.CompleteInitialization()
                assert(state.tracker.hidden and state.tracker.x == 50)

                addon.state.isCurrencySettingsOpen = true
                layout.UpdateContext()
                assert(not state.tracker.hidden and state.tracker.x == 405)
                assert(state.currency.hidden, "Empty currency panel stays hidden")

                addon.state.isCurrencySettingsOpen = false
                layout.UpdateContext()
                assert(state.tracker.hidden and state.tracker.x == 50 and state.saves == 0)
                state.scene = nil
                layout.UpdateContext()
                assert(not state.tracker.hidden and state.tracker.x == 50)
            end,
        },
        {
            name = "Panel layout inventory avoids equipment, stats, and the top header as well as the backpack",
            run = function()
                local _, layout, state = Fixture("inventory")
                state.currencyVisible = true
                state.profile.Currency.Layout_NoScene = { offsetX = 880, offsetY = 100 }
                ZO_PlayerInventory = Control(750, 0, 250, 600)
                ZO_Character = Control(0, 100, 160, 400)
                ZO_CharacterWindowStats = Control(160, 170, 240, 330)
                ZO_PlayerProgress = Control(0, 0, 250, 60)
                ZO_MainMenuCategoryBar = Control(300, 0, 445, 60)
                layout.CompleteInitialization()
                assert(state.tracker.x == 645 and state.tracker.y == 65, "Header must not obscure the displaced tracker")
                assert(state.currency.x == 625 and state.currency.y == 170, "Backpack overlap must join the stack")
                ZO_CharacterWindowStats.width = 585
                layout.UpdateContext()
                assert(state.tracker.x == 645 and state.tracker.y == 65, "A panel still clear of stats stays put")
                assert(state.currency.x == 625 and state.currency.y == 505, "Growing stats must displace an overlapping panel")
                assert(state.saves == 0)

                state.scene = nil
                layout.UpdateContext()
                assert(state.tracker.x == 50 and state.tracker.y == 50)
                assert(state.currency.x == 880 and state.currency.y == 100)
            end,
        },
        {
            name = "Panel layout leaves a gap to the shared right backdrop throughout inventory interactions",
            run = function()
                for _, mapping in ipairs({
                    { "inventory", "Layout_InventoryScene" },
                    { "bank", "Layout_BankScene", "ZO_PlayerBank" },
                    { "houseBank", "Layout_HouseBankScene", "ZO_HouseBank" },
                    { "guildBank", "Layout_GuildBankScene", "ZO_GuildBank" },
                    { "furnitureVault", "Layout_FurnitureVaultScene", "ZO_FurnitureVault" },
                    { "store", "Layout_MerchantScene" },
                    { "store_keyboard", "Layout_MerchantScene" },
                    { "fence_keyboard", "Layout_FenceScene" },
                }) do
                    local scene, layoutKey, withdrawalWindow = unpack(mapping)
                    for _, controlName in ipairs(withdrawalWindow and { "ZO_PlayerInventory", withdrawalWindow }
                        or { "ZO_PlayerInventory" }) do
                        local _, layout, state = Fixture(scene)
                        local label = scene .. ": " .. controlName
                        state.profile.Tracker[layoutKey] = { character = { offsetX = 640, offsetY = 100 } }
                        _G[controlName] = Control(750, 100, 250, 500)
                        ZO_SharedRightPanelBackground = Control(750, 100, 250, 500)
                        ZO_SharedRightPanelBackground.hidden = true
                        ZO_SharedRightPanelBackgroundLeft = Control(685, 25, 1024, 1024)
                        layout.CompleteInitialization()
                        assert(state.tracker.x == 640, label .. " moved for a hidden backdrop")

                        ZO_SharedRightPanelBackground.hidden = false
                        layout.UpdateContext()
                        assert(state.tracker.x + state.tracker.width == ZO_SharedRightPanelBackgroundLeft.x - 5, label)
                        assert(state.tracker.y == 100, label .. " changed vertical alignment")
                        assert(state.profile.Tracker[layoutKey].character.offsetX == 640 and state.saves == 0, label)
                    end
                end
            end,
        },
        {
            name = "Panel layout settings geometry corrects saved positions without writes or drag interruption",
            run = function()
                local addon, layout, state = Fixture("gameMenuInGame")
                addon.state.isCurrencySettingsOpen = true
                local tracker = state.tracker
                state.profile.Tracker.Layout_SettingsScene = { character = { offsetX = 450, offsetY = 50 } }
                ZO_GameMenu_InGame = Control(0, 0, 400, 500)
                layout.CompleteInitialization()
                assert(tracker.x == 450 and not tracker.hidden)
                local writes = tracker.writes
                for _ = 1, 20 do layout.UpdateContext() end
                assert(tracker.writes == writes)
                ZO_AddOns = Control(0, 0, 600, 500)
                layout.UpdateContext()
                assert(tracker.x == 605, "The wider ZOS addon manager must trigger overlap correction")
                assert(state.profile.Tracker.Layout_SettingsScene.character.offsetX == 450 and state.saves == 0)
                ZO_AddOns.hidden = true
                layout.UpdateContext()
                assert(tracker.x == 605, "Narrowing must leave an unobstructed correction alone")
                LAMAddonSettingsWindow = Control(0, 0, 600, 500)
                writes = tracker.writes
                layout.OnMoveStart("Tracker")
                tracker.x = 700
                LAMAddonSettingsWindow.hidden = false
                LAMAddonSettingsWindow.width = 800
                for _ = 1, 5 do layout.UpdateContext() end
                assert(tracker.x == 700 and tracker.writes == writes, "Geometry updates must not interrupt dragging")
                layout.OnMoveStop("Tracker")
                layout.UpdateContext()
                assert(tracker.x == 805 and state.saves == 1, "Deferred geometry must be corrected after release")
                assert(state.profile.Tracker.Layout_SettingsScene.character.offsetX == 700)
                writes = tracker.writes
                for _ = 1, 20 do layout.UpdateContext() end
                assert(tracker.writes == writes, "Corrected geometry must settle")
                state.scene = nil; layout.UpdateContext()
                assert(tracker.x == 50 and state.profile.Tracker.Layout_NoScene.offsetX == 50)
                state.scene = "gameMenuInGame"; LAMAddonSettingsWindow.hidden = true
                layout.UpdateContext()
                assert(tracker.x == 700, "A new visit starts from saved rather than temporary coordinates")
                LAMAddonSettingsWindow.hidden = false
                layout.ResetPanelPosition("Tracker")
                assert(tracker.x == 805, "Position reset must also avoid related wider settings controls")
            end,
        },
        {
            name = "Panel layout panel growth preserves IC overlap and corrects screen edges only during scenes",
            run = function()
                local _, layout, state = Fixture("bank")
                ZO_PlayerBank = Control(0, 0, 400, 500)
                state.currencyVisible = true
                layout.CompleteInitialization()
                assert(state.tracker.x == 405 and state.currency.x == 700)
                state.tracker.width = 350
                layout.UpdateContext()
                assert(state.currency.x == 700 and state.currency.y == 100,
                    "Growing tracker must not disturb another panel solely because they overlap")
                state.currency.width = 650
                layout.UpdateContext()
                assert(state.currency.x >= 0 and state.currency.x + state.currency.width <= 1000,
                    "Panel growth past the screen edge must be corrected")
                assert(state.saves == 0)
                state.scene = nil; layout.UpdateContext()
                local writes = state.currency.writes
                state.currency.width = 900
                layout.UpdateContext()
                assert(state.currency.x == 700 and state.currency.writes == writes,
                    "Normal-context resizing must not invoke scene correction")
            end,
        },
        {
            name = "Panel layout saved overlapping bars survive reentry and IC size changes",
            run = function()
                local addon, layout, state = Fixture("inventory")
                ZO_PlayerInventory = Control(400, 0, 600, 700)
                state.currencyVisible = true
                local bar = Control(0, 0, 120, 30)
                state.profile["capacity:bag"] = { Layout_NoScene = { offsetX = 50, offsetY = 300 } }
                addon.GetProgressBarResources = function() return { { key = "capacity:bag" } } end
                addon.GetProgressBarSettings = function() return { showBar = true } end
                addon.GetProgressBarResourceValues = function() return 1 end
                layout.RegisterPanel("capacity:bag", bar)
                for index, key in ipairs({ "Tracker", "Currency", "capacity:bag" }) do
                    state.profile[key].Layout_InventoryScene = {
                        character = { offsetX = 280, offsetY = 80 + index * 20 },
                    }
                end
                local function AssertStack()
                    assert(state.tracker.x == 280 and state.tracker.y == 100)
                    assert(state.currency.x == 280 and state.currency.y == 120)
                    assert(bar.x == 280 and bar.y == 140)
                end
                layout.CompleteInitialization()
                AssertStack()
                state.scene = nil; layout.UpdateContext()
                state.scene = "inventory"; layout.UpdateContext()
                AssertStack()
                state.currency.height = 150
                local writes = state.currency.writes + state.tracker.writes + bar.writes
                for _ = 1, 10 do layout.UpdateContext() end
                AssertStack()
                assert(writes == state.currency.writes + state.tracker.writes + bar.writes)
                state.currency.width = 121
                layout.UpdateContext()
                assert(state.currency.x + state.currency.width <= 400,
                    "Growth into actual ZOS UI must still be corrected")
                assert(state.tracker.x == 280 and state.tracker.y == 100 and bar.x == 280 and bar.y == 140,
                    "Correction must not dismantle the remaining stack")
                assert(state.saves == 0
                    and state.profile.Currency.Layout_InventoryScene.character.offsetX == 280)
            end,
        },
        {
            name = "Panel layout ZOS edge contact and small gaps do not trigger padding correction",
            run = function()
                for _, x in ipairs({ 300, 297 }) do
                    local addon, layout, state = Fixture("gameMenuInGame")
                    addon.state.isCurrencySettingsOpen = true
                    ZO_GameMenu_InGame = Control(400, 0, 600, 700)
                    state.profile.Tracker.Layout_SettingsScene = {
                        character = { offsetX = x, offsetY = 100 },
                    }
                    layout.CompleteInitialization()
                    assert(state.tracker.x == x and state.tracker.y == 100,
                        "A saved position touching or within five pixels of ZOS must remain unchanged")
                    local writes = state.tracker.writes
                    ZO_GameMenu_InGame.height = 650
                    layout.UpdateContext()
                    assert(state.tracker.writes == writes)
                    ZO_AddOns = Control(x + 99, 0, 1000 - x - 99, 700)
                    layout.UpdateContext()
                    assert(state.tracker.x + state.tracker.width <= ZO_AddOns.x,
                        "Even one pixel of actual new ZOS overlap must trigger correction")
                    assert(state.profile.Tracker.Layout_SettingsScene.character.offsetX == x and state.saves == 0)
                end
            end,
        },
    }
end
