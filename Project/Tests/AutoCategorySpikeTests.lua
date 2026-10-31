InventoryCompanion = { Name = "InventoryCompanion_DEV", SettingsName = "InventoryCompanion_AutoCategorySpike", IsDevelopment = true }
SLASH_COMMANDS = {}
EVENT_ADD_ON_LOADED = "EVENT_ADD_ON_LOADED"
local registeredEvents = {}
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, eventCode, callback)
        registeredEvents[name] = { eventCode = eventCode, callback = callback }
    end,
    UnregisterForEvent = function(_, name)
        registeredEvents[name] = nil
    end,
}
IsInGamepadPreferredMode = function() return false end
ZO_ScrollList_GetDataList = function(list) return list.data end
SI_AC_MENU_UBS_BUTTON_EXPORT_TO_ALL_BAGS = "Export to all bags"

ZO_Object = {}
function ZO_Object:Subclass()
    local class = {}
    class.__index = class
    return setmetatable(class, { __index = self })
end
function ZO_Object.New(class)
    return setmetatable({}, class)
end
function ZO_ClearTable(values)
    for key in pairs(values) do values[key] = nil end
end
function GetString(value) return tostring(value) end
zo_loadstring = loadstring
function ZO_IndexOfElementInNumericallyIndexedTable(values, element)
    for index, value in ipairs(values) do
        if value == element then return index end
    end
end

local color = { Colorize = function(_, text) return text end }
local logger = { SetDebug = function() end, Debug = function() end }
LibSFUtils = {
    colors = { gold = color, purple = color },
    SafeLoggerFunction = function() return function() return logger end end,
    LoadLanguage = function() end,
    safeClearTable = function(values)
        if values == nil then values = {} end
        ZO_ClearTable(values)
        return values
    end,
    colorRGBToHex = function() return "FFFFFF" end,
    safeTable = function(values) return values or {} end,
    EvtMgr = { New = function() return { registerEvt = function() end } end },
}

local bagNames = {
    "BAG_BACKPACK", "BAG_WORN", "BAG_BANK", "BAG_SUBSCRIBER_BANK",
    "BAG_VIRTUAL", "BAG_GUILDBANK", "BAG_HOUSE_BANK_ONE", "BAG_HOUSE_BANK_TWO",
    "BAG_HOUSE_BANK_THREE", "BAG_HOUSE_BANK_FOUR", "BAG_HOUSE_BANK_FIVE",
    "BAG_HOUSE_BANK_SIX", "BAG_HOUSE_BANK_SEVEN", "BAG_HOUSE_BANK_EIGHT",
    "BAG_FURNITURE_VAULT",
}
for index, name in ipairs(bagNames) do _G[name] = index end
local inventoryNames = {
    "INVENTORY_BACKPACK", "INVENTORY_CRAFT_BAG", "INVENTORY_GUILD_BANK",
    "INVENTORY_HOUSE_BANK", "INVENTORY_BANK", "INVENTORY_FURNITURE_VAULT",
}
for index, name in ipairs(inventoryNames) do _G[name] = index end
SMITHING = { deconstructionPanel = { inventory = {}, control = {} },
    improvementPanel = { inventory = {}, control = {} } }
UNIVERSAL_DECONSTRUCTION = { deconstructionPanel = { inventory = {}, control = {} } }

local link = "synthetic:Plunder Skull"
local itemName = "Plunder Skull"
local matcherCalls, linkReads, scanCalls, refreshCalls = 0, 0, 0, 0
function GetItemLink()
    linkReads = linkReads + 1
    return link
end
function GetItemLinkName()
    matcherCalls = matcherCalls + 1
    return itemName
end
function GetBagSize()
    scanCalls = scanCalls + 1
    error("Classification must not enumerate inventory")
end
PLAYER_INVENTORY = { UpdateList = function() refreshCalls = refreshCalls + 1 end }

local function Equal(actual, expected, message)
    assert(actual == expected,
        string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = Copy(entry) end
    return result
end

LibSFUtils.deepCopy = Copy

local function Same(actual, expected, path)
    Equal(type(actual), type(expected), path .. " type")
    if type(expected) ~= "table" then
        Equal(actual, expected, path)
        return
    end
    for key, value in pairs(expected) do Same(actual[key], value, path .. "." .. tostring(key)) end
    for key in pairs(actual) do assert(expected[key] ~= nil, path .. " gained " .. tostring(key)) end
end

function GetAutoCategorySpikeTests()
    local ac, ic = AutoCategory, InventoryCompanion
    ac.Inited = false
    ac.Environment = {}
    ac.acctSaved = {
        general = {},
        appearance = { CATEGORY_OTHER_TEXT = "Other" },
    }
    local gateEvent = registeredEvents.InventoryCompanion_DEV_AutoCategoryGate
    assert(gateEvent ~= nil, "Gate plugin load-order handler was not registered.")
    gateEvent.callback(EVENT_ADD_ON_LOADED, "AutoCategory")
    Equal(ic.GetAutoCategoryGateRegistration(), "waiting",
        "Dependency load event must not race AutoCategory's own saved-variable initialization")
    ac.Inited = true
    local baselineOk, baselineReport = pcall(SLASH_COMMANDS["/icacspike"], "profile baseline")
    ac.Inited = false
    Equal(baselineOk, false, "Unavailable registration copyable diagnostic")
    assert(tostring(baselineReport):find("NOT AVAILABLE: gate plugin registration is waiting", 1, true),
        "Unavailable registration must report its status without a raw assertion")
    ac.saved.general = { SHOW_CATEGORY_SET_TITLE = true, ENABLE_GAMEPAD = true }
    ac.saved.appearance = { CATEGORY_FONT_COLOR = { 1, 1, 1 }, HIDDEN_CATEGORY_FONT_COLOR = { 1, 1, 1 } }
    ac.dspWin = {
        ClearList = function() end,
        AddItem = function() end,
        UpdateScrollList = function() end,
    }
    for context = 1, 7 do
        ac.saved.bags[context] = { rules = {} }
        ac.saved.collapses[context] = {}
    end
    ac.acctSaved.bags = Copy(ac.saved.bags)
    ac.acctSaved.collapses = Copy(ac.saved.collapses)
    ac.charSaved = {
        accountWide = true,
        bags = Copy(ac.saved.bags),
        collapses = Copy(ac.saved.collapses),
    }
    ac.acctRules = { rules = {} }
    gateEvent.callback(EVENT_ADD_ON_LOADED, ic.Name)
    local gateStatus = ic.GetAutoCategoryGateRegistration()
    Equal(gateStatus, "registered", "Gate plugin startup registration")
    local gatePlugin = ac.Plugins["InventoryCompanion DEV AutoCategory Gate"]
    assert(gatePlugin and gatePlugin.predef and #gatePlugin.predef == 1, "Gate plugin definition was not registered.")
    ac.RulesW:AddRule(gatePlugin.predef[1])
    gatePlugin.init()
    ac.Inited = true
    ac.saved.bags = ac.acctSaved.bags
    ac.saved.collapses = ac.acctSaved.collapses
    -- Mirror ZO_SavedVars: empty interfaces forwarding reads/writes to raw saved tables.
    local rawAccount = { trackedRules = {}, trackedItems = {} }
    local rawCharacter = { useCharacterItemList = false, trackedRules = {}, trackedItems = {} }
    local function SavedVarsInterface(raw)
        return setmetatable({}, { __index = raw, __newindex = function(_, key, value) raw[key] = value end })
    end
    ic.accountWide = SavedVarsInterface(rawAccount)
    ic.character = SavedVarsInterface(rawCharacter)
    ic.preLoadedRulesets = {}
    ic.Scanning = setmetatable({}, { __index = function() error("Scan API accessed by predicate") end })
    ic.GetMasterItemList = function()
        scanCalls = scanCalls + 1
        error("Classification must not call GetMasterItemList")
    end
    ic.CreateCustomRule("a", "Spike A")
    ic.UpdateRulePatterns("a", { "*plunder skull*" })
    ic.CreateCustomRule("b", "Spike B")
    ic.UpdateRulePatterns("b", { "*skull*" })
    local runtime = ic.GetRuntimeRules()
    local originalClassifier = ac.MatchCategoryRules
    local externalRule = { name = "Spike External", tag = "Spike", rule = "spike_external()" }
    local externalBefore = Copy(externalRule)
    ac.AddRuleFunc("spike_external", function() return itemName == "Plunder Skull" end)
    ac.RulesW:AddRule(externalRule)
    local function Entry(name, priority, showPriority)
        return { name = name, runpriority = priority, showpriority = showPriority, isHidden = false }
    end
    local contexts = { AC_BAG_TYPE_BACKPACK, AC_BAG_TYPE_BANK }
    for _, context in ipairs(contexts) do
        ac.saved.bags[context].rules = { Entry(externalRule.name, 100, 41) }
        ac.cacheInitBag(context)
    end
    local originalBags = Copy(ac.saved.bags)
    local originalRules = Copy(ac.RulesW.ruleList)
    local savedSentinel = { marker = "Never read or mutate saved-variable globals" }
    AutoCategorySavedVars, AutoCatRules = Copy(savedSentinel), Copy(savedSentinel)
    _G[ic.SettingsName] = Copy(savedSentinel)
    local order = {}
    local function Classify(bag, expected, expectedPriority, expectedShow)
        local matched, name, run, show, context, hidden = ac:MatchCategoryRules(bag, 1)
        Equal(matched, expected ~= nil, "Match status")
        Equal(name, expected or "", "Actual native winning category")
        Equal(run, expectedPriority or 0, "Run priority")
        Equal(show, expectedShow or 0, "Show priority")
        Equal(context, bag == BAG_BACKPACK and AC_BAG_TYPE_BACKPACK or AC_BAG_TYPE_BANK, "Bag context")
        Equal(hidden, false, "Hidden result")
        Equal(ac.MatchCategoryRules, originalClassifier, "Classifier not replaced")
    end
    local function SetOrder(context, names)
        order[context] = names
        for position, name in ipairs(names) do
            for _, entry in ipairs(ac.saved.bags[context].rules) do
                if entry.name == name then entry.runpriority = 400 - position end
            end
        end
        ac.cacheInitBag(context)
        for position, name in ipairs(names) do
            Equal(ac.saved.bags[context].rules[position].name, name, "Native cache sorted position")
        end
    end
    local tests = {}
    local function Add(name, run) tests[#tests + 1] = { name = name, run = run } end

    Add("Baseline existing category uses unchanged native classifier", function()
        Classify(BAG_BACKPACK, externalRule.name, 100, 41)
        Classify(BAG_BANK, externalRule.name, 100, 41)
    end)
    Add("Register real matching bridge and insert two runtime definitions/assignments", function()
        ac.AddRuleFunc("ic_spike_group", function(key)
            local context = ac.checkingItemBagId == BAG_BACKPACK and AC_BAG_TYPE_BACKPACK or AC_BAG_TYPE_BANK
            for _, name in ipairs(order[context]) do
                local candidate = name == "Spike A" and "a" or name == "Spike B" and "b" or nil
                if candidate and ic.ItemMatchesRuntimeRule(ac.checkingItemLink, runtime[candidate]) then
                    return candidate == key
                end
            end
            return false
        end)
        for _, key in ipairs({ "a", "b" }) do
            local name = key == "a" and "Spike A" or "Spike B"
            ac.RulesW:AddRule({ name = name, tag = "Spike", rule = 'ic_spike_group("' .. key .. '")' })
            assert(ac.compiledRules[name], "Actual AutoCategory compiler must register expression")
            for _, context in ipairs(contexts) do
                table.insert(ac.saved.bags[context].rules, Entry(name, 200, key == "a" and 17 or 19))
            end
        end
        SetOrder(AC_BAG_TYPE_BACKPACK, { "Spike A", externalRule.name, "Spike B" })
        SetOrder(AC_BAG_TYPE_BANK, { "Spike B", externalRule.name, "Spike A" })
        Classify(BAG_BACKPACK, "Spike A", 399, 17)
        Classify(BAG_BANK, "Spike B", 399, 19)
        Classify(BAG_SUBSCRIBER_BANK, "Spike B", 399, 19)
    end)
    Add("External category moved above managed groups wins without expression edits", function()
        SetOrder(AC_BAG_TYPE_BACKPACK, { externalRule.name, "Spike A", "Spike B" })
        Classify(BAG_BACKPACK, externalRule.name, 399, 41)
        Same(externalRule, externalBefore, "External definition")
        Classify(BAG_BANK, "Spike B", 399, 19)
    end)
    Add("Reversing managed order changes the winner with external category between", function()
        SetOrder(AC_BAG_TYPE_BACKPACK, { "Spike B", externalRule.name, "Spike A" })
        Classify(BAG_BACKPACK, "Spike B", 399, 19)
        ac.checkingItemBagId, ac.checkingItemLink = BAG_BACKPACK, link
        Equal(ac.Environment.ic_spike_group("a"), false, "Lower managed predicate cannot win when queried first")
        Equal(ac.Environment.ic_spike_group("b"), true, "Higher managed predicate agrees")
    end)
    Add("External category between groups wins when earlier group does not match", function()
        ic.UpdateRulePatterns("b", { "*survey*" })
        runtime = ic.GetRuntimeRules()
        Classify(BAG_BACKPACK, externalRule.name, 398, 41)
        ic.UpdateRulePatterns("b", { "*skull*" })
        runtime = ic.GetRuntimeRules()
    end)
    Add("Native full cache rebuild retains runtime insertion and ordering", function()
        ac.cacheInitialize()
        Classify(BAG_BACKPACK, "Spike B", 399, 19)
        Classify(BAG_SUBSCRIBER_BANK, "Spike B", 399, 19)
        Same(externalRule, externalBefore, "External definition after rebuild")
    end)
    Add("Unmatched item falls through without scans, compilation, or inventory refresh", function()
        local beforeReads, beforeMatches = linkReads, matcherCalls
        itemName, link = "Unmatched item", "synthetic:Unmatched item"
        local compiledBefore = ac.compiledRules["Spike A"]
        Classify(BAG_BACKPACK, nil)
        assert(linkReads > beforeReads and matcherCalls > beforeMatches, "Actual APIs/matcher must execute")
        Equal(scanCalls, 0, "Inventory scans")
        Equal(refreshCalls, 0, "Inventory refreshes during classification")
        Equal(ac.compiledRules["Spike A"], compiledBefore, "No recompilation during classification")
        itemName, link = "Plunder Skull", "synthetic:Plunder Skull"
    end)
    Add("Remove temporary entries and predicate; baseline and saved-variable sentinels unchanged", function()
        for _, context in ipairs(contexts) do
            ac.saved.bags[context].rules = Copy(originalBags[context].rules)
        end
        ac.RulesW.ruleList = Copy(originalRules)
        ac.compiledRules["Spike A"], ac.compiledRules["Spike B"] = nil, nil
        ac.Environment.ic_spike_group = nil
        ac.cacheInitialize()
        Classify(BAG_BACKPACK, externalRule.name, 100, 41)
        Classify(BAG_BANK, externalRule.name, 100, 41)
        Same(ac.saved.bags, originalBags, "Original assignments")
        Same(ac.RulesW.ruleList, originalRules, "Original definitions")
        Same(AutoCategorySavedVars, savedSentinel, "AutoCategory saved global")
        Same(AutoCatRules, savedSentinel, "AutoCategory rules global")
        Same(_G[ic.SettingsName], savedSentinel, "Inventory Companion saved global")
        return "Synthetic state only; UI rendering and startup lifecycle are not certified."
    end)
    Add("Persisted managed entry with absent definition is skipped and flagged, not an error", function()
        local beforeBags = Copy(ac.saved.bags)
        local ok, failure = pcall(function()
            local missing = "InventoryCompanion Missing"
            assert(ac.GetRuleByName(missing) == nil, "Fixture: definition absent")
            table.insert(ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules, 1, Entry(missing, 500, 1))
            ac.cacheInitialize()
            Equal(ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules[1].name, missing, "Entry kept first in run order")
            Classify(BAG_BACKPACK, externalRule.name, 100, 41)
            local shown = ac.BagRuleApi.formatShow(ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules[1])
            assert(shown:find("(!)", 1, true), "AutoCategory settings flag the missing category")
        end)
        ac.saved.bags = beforeBags
        ac.cacheInitialize()
        if not ok then error(failure, 0) end
    end)
    Add("Definition whose predicate function is absent is marked damaged and falls through", function()
        local beforeBags, beforeRules = Copy(ac.saved.bags), Copy(ac.RulesW.ruleList)
        local name = "InventoryCompanion Unbound"
        local ok, failure = pcall(function()
            assert(ac.Environment.ic_unbound == nil, "Fixture: predicate absent")
            ac.RulesW:AddRule({ name = name, tag = "InventoryCompanion", rule = 'ic_unbound("maps")' })
            table.insert(ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules, 1, Entry(name, 500, 1))
            ac.cacheInitialize()
            Classify(BAG_BACKPACK, externalRule.name, 100, 41)
            Equal(ac.GetRuleByName(name).damaged, true, "Rule marked damaged")
            Equal(ac.compiledRules[name], nil, "Damaged rule dropped for the session")
            Classify(BAG_BACKPACK, externalRule.name, 100, 41)
        end)
        ac.saved.bags, ac.RulesW.ruleList = beforeBags, beforeRules
        ac.compiledRules[name] = nil
        ac.cacheInitialize()
        if not ok then error(failure, 0) end
    end)
    local function CheckProbe(injectFailure)
        local beforeBags = Copy(ac.saved.bags)
        local beforeRules = Copy(ac.RulesW.ruleList)
        local beforeAccount, beforeCharacter = Copy(rawAccount), Copy(rawCharacter)
        local account, character, window = ic.accountWide, ic.character, ac.dspWin
        local bagTable, ruleList = ac.saved.bags, ac.RulesW.ruleList
        local environment, compiled = ac.Environment, ac.compiledRules
        local oldGetBagSize, oldCacheInitBag = GetBagSize, ac.cacheInitBag
        local savedBag, savedSlot, savedLink = ac.checkingItemBagId, ac.checkingItemSlotIndex, ac.checkingItemLink
        GetBagSize = function(bag)
            Equal(bag, BAG_BACKPACK, "Read-only item discovery bag")
            return 1
        end
        if injectFailure then
            ac.cacheInitBag = function(context)
                oldCacheInitBag(context)
                error("Injected external cache failure")
            end
        end
        local ok, result = pcall(ic.RunAutoCategoryNativeProbe, "plunder skull")
        GetBagSize, ac.cacheInitBag = oldGetBagSize, oldCacheInitBag
        Equal(ic.accountWide, account, "Account restored")
        Equal(ic.character, character, "Character restored")
        Same(rawAccount, beforeAccount, "Raw account saved data unchanged through proxy")
        Same(rawCharacter, beforeCharacter, "Raw character saved data unchanged through proxy")
        Equal(ac.dspWin, window, "Real UI restored")
        Equal(ac.saved.bags, bagTable, "Original bag reference restored")
        Equal(ac.RulesW.ruleList, ruleList, "Original definitions reference restored")
        Equal(ac.Environment, environment, "Expression environment identity")
        Equal(ac.compiledRules, compiled, "Compiled table identity")
        Equal(ac.checkingItemBagId, savedBag, "Checking bag restored")
        Equal(ac.checkingItemSlotIndex, savedSlot, "Checking slot restored")
        Equal(ac.checkingItemLink, savedLink, "Checking link restored")
        Equal(ac.Environment.ic_native_insertion_spike, nil, "Temporary predicate removed")
        Same(ac.saved.bags, beforeBags, "Live probe assignment restoration")
        Same(ac.RulesW.ruleList, beforeRules, "Live probe definition restoration")
        Same(AutoCategorySavedVars, savedSentinel, "Saved variables unchanged")
        Same(AutoCatRules, savedSentinel, "Saved rules unchanged")
        Same(_G[ic.SettingsName], savedSentinel, "IC saves unchanged")
        if injectFailure then
            assert(not ok and tostring(result):find("Injected external cache failure", 1, true),
                "Probe must rethrow failure after cleanup")
        else
            assert(ok, tostring(result))
            Equal(#result, 8, "Complete DEV probe report")
        end
    end
    Add("DEV Plunder Skull command runs actual modules and restores original identities", function()
        CheckProbe(false)
    end)
    Add("DEV probe accepts and restores an ESO-style userdata display control", function()
        local originalWindow = ac.dspWin
        ac.dspWin = newproxy(true)
        local ok, failure = pcall(CheckProbe, false)
        ac.dspWin = originalWindow
        if not ok then error(failure, 0) end
    end)
    Add("DEV probe restores test isolation and rethrows an external error", function()
        CheckProbe(true)
    end)
    Add("Successful slash command raises complete copyable report after restoring runtime state", function()
        local bags, definitions, account, window = ac.saved.bags, ac.RulesW.ruleList, ic.accountWide, ac.dspWin
        local oldGetBagSize = GetBagSize
        GetBagSize = function() return 1 end
        local ok, report = pcall(SLASH_COMMANDS["/icacspike"], "")
        GetBagSize = oldGetBagSize
        assert(not ok, "Successful diagnostic command intentionally opens the error window")
        for _, fragment in ipairs({
            "DIAGNOSTIC REPORT", "not a test failure", "Item: Plunder Skull",
            "PASS full cache rebuild", "Restored original runtime state",
            "Classification proof only",
        }) do
            assert(tostring(report):find(fragment, 1, true), "Missing report text: " .. fragment)
        end
        Equal(ac.saved.bags, bags, "Assignments restored before diagnostic error")
        Equal(ac.RulesW.ruleList, definitions, "Definitions restored before diagnostic error")
        Equal(ic.accountWide, account, "Account restored before diagnostic error")
        Equal(ac.dspWin, window, "Window restored before diagnostic error")
        Equal(ac.Environment.ic_native_insertion_spike, nil, "Predicate removed before diagnostic error")
    end)
    Add("Rendering probe restores rules before delayed normal redraw and preserves external assignments", function()
        local names = { "GetBagSize", "GetItemLink", "GetItemLinkName", "IsInGamepadPreferredMode", "ZO_PlayerInventory",
            "ZO_ScrollList_GetDataList", "zo_callLater", "PLAYER_INVENTORY" }
        local originals = {}
        for index, name in ipairs(names) do originals[index] = { name = name, value = _G[name] } end
        local originalRefresh, originalBags = ac.RefreshList, ac.saved.bags
        local delayed, drawCalls, list = nil, 0, {}
        local itemLinks = { [0] = link, [1] = "synthetic:Second Plunder Skull", [2] = "synthetic:Unrelated item" }
        local itemNames = { [link] = itemName, [itemLinks[1]] = "Dremora Plunder Skull, World",
            [itemLinks[2]] = "Unrelated item" }
        GetBagSize = function() return 3 end
        GetItemLink = function(_, slot) return itemLinks[slot] end
        GetItemLinkName = function(value) return itemNames[value] end
        IsInGamepadPreferredMode = function() return false end
        ZO_PlayerInventory = { IsHidden = function() return false end }
        PLAYER_INVENTORY = { inventories = { [INVENTORY_BACKPACK] = { listView = {} } } }
        ZO_ScrollList_GetDataList = function() return list end
        zo_callLater = function(callback, delay)
            Equal(delay, 20000, "Bounded visual inspection window")
            delayed = callback
        end
        ac.RefreshList = function(inventory)
            Equal(inventory, INVENTORY_BACKPACK, "Narrow refresh")
            drawCalls = drawCalls + 1
            if drawCalls == 1 then
                assert(ac.GetRuleByName("Spike External"), "External definition retained")
                Equal(#ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules, 3, "Original plus two managed assignments")
                local matched, winner = ac:MatchCategoryRules(BAG_BACKPACK, 0)
                Equal(matched, true, "Render refresh classification")
                Equal(winner, "|t18:18:EsoUI/Art/Buttons/plus_up.dds|t InventoryCompanion Spike B", "Rendering winner")
                local _, secondWinner = ac:MatchCategoryRules(BAG_BACKPACK, 1)
                Equal(secondWinner, winner, "Every group match moves, not only the selected link")
                local otherMatched, otherWinner = ac:MatchCategoryRules(BAG_BACKPACK, 2)
                Equal(otherMatched, true, "Unrelated item retains existing external match")
                Equal(otherWinner, "Spike External", "Probe group cannot capture unrelated item")
                list = {
                    { data = { AC_isHeader = true, AC_categoryName = winner } },
                    { data = { bagId = BAG_BACKPACK, slotIndex = 0, AC_categoryName = winner } },
                    { data = { bagId = BAG_BACKPACK, slotIndex = 1, AC_categoryName = winner } },
                    { data = { AC_isHeader = true, AC_categoryName = otherWinner } },
                    { data = { bagId = BAG_BACKPACK, slotIndex = 2, AC_categoryName = otherWinner } },
                }
            else
                Equal(ac.saved.bags, originalBags, "Delayed refresh uses original state")
                Equal(ac.Environment.ic_native_insertion_spike, nil, "No retained test predicate")
            end
        end
        local ok, failure = pcall(function()
            local report = ic.RunAutoCategoryNativeProbe("plunder skull", true)
            Equal(ac.saved.bags, originalBags, "Immediate original rules restoration")
            assert(table.concat(report, "\n"):find("all 2 matching items in Spike B; 1 other", 1, true),
                "List verification report")
            assert(delayed, "Normal redraw must be scheduled")
            delayed()
            Equal(drawCalls, 2, "One test refresh and one normal refresh")
        end)
        ac.RefreshList = originalRefresh
        for _, entry in ipairs(originals) do _G[entry.name] = entry.value end
        if not ok then error(failure, 0) end
    end)
    Add("Render command reports closed Backpack or gamepad as unavailable without running probe", function()
        local originalMode, originalControl = IsInGamepadPreferredMode, ZO_PlayerInventory
        local originalProbe, originalBags = ic.RunAutoCategoryNativeProbe, ac.saved.bags
        local probeCalls = 0
        ic.RunAutoCategoryNativeProbe = function()
            probeCalls = probeCalls + 1
            error("Unavailable render surface must not run probe")
        end
        local cases = {
            {
                gamepad = false,
                control = { IsHidden = function() return true end },
                expected = "keyboard Backpack is closed",
            },
            {
                gamepad = true,
                control = { IsHidden = function() return false end },
                expected = "keyboard inventory only",
            },
        }
        local ok, failure = pcall(function()
            for _, case in ipairs(cases) do
                IsInGamepadPreferredMode = function() return case.gamepad end
                ZO_PlayerInventory = case.control
                local commandOk, report = pcall(SLASH_COMMANDS["/icacspike"], "render")
                Equal(commandOk, false, "Copyable unavailable diagnostic")
                for _, fragment in ipairs({ "DIAGNOSTIC REPORT", "NOT AVAILABLE", case.expected,
                    "No AutoCategory rules, assignments, or items were changed." }) do
                    assert(tostring(report):find(fragment, 1, true), "Missing render diagnostic text: " .. fragment)
                end
            end
            Equal(probeCalls, 0, "Probe is not run for unavailable render surfaces")
            Equal(ac.saved.bags, originalBags, "Saved assignments remain untouched")
        end)
        IsInGamepadPreferredMode, ZO_PlayerInventory = originalMode, originalControl
        ic.RunAutoCategoryNativeProbe = originalProbe
        if not ok then error(failure, 0) end
    end)
    Add("Slash command reports unavailable dependency in a copyable diagnostic", function()
        local originalPrint, originalProbe = d, ic.RunAutoCategoryNativeProbe
        local messages = {}
        local probeCalls = 0
        d = function(message) messages[#messages + 1] = message end
        ic.RunAutoCategoryNativeProbe = function()
            probeCalls = probeCalls + 1
            error("Unavailable dependency must not run probe")
        end
        local ok, failure = pcall(function()
            local cases = {
                { fragment = "not loaded" },
                { dependency = "invalid", fragment = "incompatible namespace" },
                { dependency = { Inited = false, Enabled = true }, fragment = "not finished initialization" },
                { dependency = { Inited = true, Enabled = false }, fragment = "switched off" },
            }
            for index, case in ipairs(cases) do
                AutoCategory = case.dependency
                local ok, report = pcall(SLASH_COMMANDS["/icacspike"], "")
                Equal(ok, false, "Copyable availability diagnostic")
                assert(tostring(report):find(case.fragment, 1, true), "Wrong dependency status")
            end
            Equal(probeCalls, 0, "No probe calls while unavailable")
        end)
        AutoCategory = ac
        d, ic.RunAutoCategoryNativeProbe = originalPrint, originalProbe
        if not ok then error(failure, 0) end
    end)
    Add("DEV Debug Key dispatches the current multi-heading order test", function()
        local command = SLASH_COMMANDS["/icacspike"]
        local argument
        SLASH_COMMANDS["/icacspike"] = function(value) argument = value end
        local ok, failure = pcall(ic.Debug)
        SLASH_COMMANDS["/icacspike"] = command
        if not ok then error(failure, 0) end
        Equal(argument, "order plunder skull", "Debug key current gate")
    end)

    local function Fields(value)
        local fields = {}
        for key, entry in pairs(value) do fields[key] = entry end
        return fields
    end
    local function ReplaceFields(target, values)
        for key in pairs(target) do target[key] = nil end
        for key, value in pairs(values) do target[key] = value end
    end

    local function WithIsolatedAutoCategory(run)
        local bags, bagsBefore = ac.saved.bags, Copy(ac.saved.bags)
        local collapses, collapsesBefore = ac.saved.collapses, Copy(ac.saved.collapses)
        local rules, rulesBefore = ac.RulesW.ruleList, Copy(ac.RulesW.ruleList)
        local ruleNames, ruleNamesBefore = ac.RulesW.ruleNames, Copy(ac.RulesW.ruleNames)
        local environment, environmentBefore = ac.Environment, Fields(ac.Environment)
        local compiled, compiledBefore = ac.compiledRules, Fields(ac.compiledRules)
        local displayWindow = ac.dspWin
        local refreshDropdownData, refreshControls = AC_UI.RefreshDropdownData, AC_UI.RefreshControls
        local ok, failure = pcall(run)

        ac.saved.bags = bags
        ReplaceFields(bags, Copy(bagsBefore))
        ac.saved.collapses = collapses
        ReplaceFields(collapses, Copy(collapsesBefore))
        ac.RulesW.ruleList = rules
        ReplaceFields(rules, Copy(rulesBefore))
        ac.RulesW.ruleNames = ruleNames
        ReplaceFields(ruleNames, Copy(ruleNamesBefore))
        ac.Environment = environment
        ReplaceFields(environment, environmentBefore)
        ac.compiledRules = compiled
        ReplaceFields(compiled, compiledBefore)
        ac.RulesW.compiled = compiled
        ac.dspWin = displayWindow
        AC_UI.RefreshDropdownData, AC_UI.RefreshControls = refreshDropdownData, refreshControls
        ac.cacheInitialize()
        if not ok then error(failure, 0) end
    end

    Add("Fractional and above-1000 priorities classify and retain computed order", function()
        WithIsolatedAutoCategory(function()
            local activeName
            ac.AddRuleFunc("ic_gate2_priority", function(name) return name == activeName end)
            for _, name in ipairs({ "Gate2 RunFirst", "Gate2 ShowFirst" }) do
                ac.RulesW:AddRule({
                    name = name,
                    tag = "InventoryCompanion Gate 2",
                    rule = 'ic_gate2_priority("' .. name .. '")',
                })
            end
            ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules = {
                { name = "Gate2 RunFirst", runpriority = 1001.5, showpriority = 999.5, isHidden = false, icOwned = true },
                { name = "Gate2 ShowFirst", runpriority = 1000.5, showpriority = 1001.5, isHidden = false, icOwned = true },
            }

            local displayEntries = {}
            ac.dspWin = {
                ClearList = function() displayEntries = {} end,
                AddItem = function(_, entry) displayEntries[#displayEntries + 1] = entry end,
                UpdateScrollList = function() end,
            }
            ac.cacheInitBag(AC_BAG_TYPE_BACKPACK)
            local runOrder = ac.cache.entriesByBag[AC_BAG_TYPE_BACKPACK].choicesValues
            Equal(runOrder[1], "Gate2 RunFirst", "Run-priority order above 1000")
            Equal(runOrder[2], "Gate2 ShowFirst", "Fractional run-priority order")
            local showOrder = ac.cache.entriesByShowBag[AC_BAG_TYPE_BACKPACK].choicesValues
            Equal(showOrder[1], "Gate2 ShowFirst", "Show-priority order above 1000")
            Equal(showOrder[2], "Gate2 RunFirst", "Fractional show-priority order")
            Equal(displayEntries[1].name, "Gate2 ShowFirst", "Settings window display order")
            Equal(displayEntries[1].icOwned, true, "Settings window ownership marker")
            Equal(displayEntries[1].runpriority, 1000.5, "Settings window fractional priority")

            activeName = "Gate2 RunFirst"
            Classify(BAG_BACKPACK, activeName, 1001.5, 999.5)
            activeName = "Gate2 ShowFirst"
            Classify(BAG_BACKPACK, activeName, 1000.5, 1001.5)

            local fractionalSortKey = string.format("%04d", 1000 - 1000.5)
            Equal(fractionalSortKey, "0000", "Lua 5.1 fractional %04d behavior")
            local firstEntry = ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules[1]
            local secondEntry = ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules[2]
            Equal(firstEntry.runpriority, 1001.5, "Persisted computed run priority")
            Equal(firstEntry.showpriority, 999.5, "Persisted computed show priority")
            Equal(secondEntry.runpriority, 1000.5, "Persisted fractional run priority")
            Equal(secondEntry.showpriority, 1001.5, "Persisted fractional show priority")
            Equal(firstEntry.icOwned, true, "Persisted ownership marker")

            local formatted = ac.BagRuleApi.formatShow(firstEntry)
            assert(formatted:find(firstEntry.name, 1, true), "Settings dropdown retains category identity")
            Equal(firstEntry.runpriority, 1001.5, "Settings display preserves run priority")
            Equal(firstEntry.showpriority, 999.5, "Settings display preserves show priority")
            return "Lua 5.1-like runner truncates %04d fractions; ESO's runtime formatter remains unverified."
        end)
    end)

    Add("icOwned and computed priorities survive AutoCategory Export to all bags", function()
        WithIsolatedAutoCategory(function()
            local name = "Gate2 Export"
            ac.RulesW:AddRule({
                name = name,
                tag = "InventoryCompanion Gate 2",
                rule = "true",
            })
            for context = 1, 7 do
                ac.saved.bags[context].rules = {}
            end
            ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules = {
                { name = name, runpriority = 1000.5, showpriority = 1001.25, isHidden = false, icOwned = true },
            }
            ac.dspWin = {
                ClearList = function() end,
                AddItem = function() end,
                UpdateScrollList = function() end,
            }
            local originalSource = Copy(ac.saved.bags[AC_BAG_TYPE_BACKPACK])
            AC_UI.RefreshDropdownData = function() end
            AC_UI.RefreshControls = function() end

            local function FindControl(controls, target)
                for _, control in ipairs(controls) do
                    if control.name == target then return control end
                    local found = FindControl(control.controls or {}, target)
                    if found then return found end
                end
            end
            local bagSetControls = AC_UI.BagSet.controlDef().controls
            local exportButton = FindControl(bagSetControls, SI_AC_MENU_UBS_BUTTON_EXPORT_TO_ALL_BAGS)
            assert(exportButton and type(exportButton.func) == "function", "Actual settings export control exists")
            exportButton.func()

            for context = 1, 7 do
                local entry = ac.saved.bags[context].rules[1]
                Equal(entry.name, name, "Exported category name")
                Equal(entry.icOwned, true, "Exported ownership marker")
                Equal(entry.runpriority, 1000.5, "Exported run priority")
                Equal(entry.showpriority, 1001.25, "Exported show priority")
                if context ~= AC_BAG_TYPE_BACKPACK then
                    assert(entry ~= ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules[1], "Export deep-copies entries")
                end
            end
            Same(ac.saved.bags[AC_BAG_TYPE_BACKPACK], originalSource, "Export leaves source bag unchanged")
        end)
    end)

    Add("Inline texture category names survive AutoCategory identity and settings paths", function()
        WithIsolatedAutoCategory(function()
            local prefix = "|t18:18:EsoUI/Art/Buttons/plus_up.dds|t "
            local alpha = prefix .. "Gate Alpha"
            local beta = prefix .. "Gate Beta"
            local activeName = alpha
            ac.AddRuleFunc("ic_gate2_texture", function(name) return name == activeName end)
            for _, name in ipairs({ beta, alpha }) do
                ac.RulesW:AddRule({
                    name = name,
                    tag = "InventoryCompanion Gate 2",
                    rule = 'ic_gate2_texture("' .. name .. '")',
                })
            end
            ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules = {
                { name = beta, runpriority = 200, showpriority = 200, isHidden = false, icOwned = true },
                { name = alpha, runpriority = 200, showpriority = 200, isHidden = false, icOwned = true },
            }
            ac.saved.collapses[AC_BAG_TYPE_BACKPACK] = {}
            local displayEntries = {}
            ac.dspWin = {
                ClearList = function() displayEntries = {} end,
                AddItem = function(_, entry) displayEntries[#displayEntries + 1] = entry end,
                UpdateScrollList = function() end,
            }
            ac.cacheInitBag(AC_BAG_TYPE_BACKPACK)

            Equal(ac.GetRuleByName(alpha).name, alpha, "Rule lookup")
            Equal(ac.GetBagRuleByName(AC_BAG_TYPE_BACKPACK, alpha).name, alpha, "Bag-rule lookup")
            assert(ac.compiledRules[alpha] ~= nil and ac.compiledRules[beta] ~= nil,
                "Inline texture expressions compile")
            local showOrder = ac.cache.entriesByShowBag[AC_BAG_TYPE_BACKPACK].choicesValues
            Equal(showOrder[1], alpha, "Name tie-break preserves exact decorated identity")
            Equal(showOrder[2], beta, "Name tie-break preserves full inline texture name")
            Equal(displayEntries[1].name, alpha, "Settings window retains decorated name")
            assert(ac.BagRuleApi.formatShow(ac.GetBagRuleByName(AC_BAG_TYPE_BACKPACK, alpha))
                :find(alpha, 1, true), "Settings dropdown retains inline texture name")

            ac.SetCategoryCollapsed(AC_BAG_TYPE_BACKPACK, alpha, true)
            Equal(ac.IsCategoryCollapsed(AC_BAG_TYPE_BACKPACK, alpha), true, "Collapse state lookup")
            activeName = alpha
            Classify(BAG_BACKPACK, alpha, 200, 200)
            Equal(ac.saved.collapses[AC_BAG_TYPE_BACKPACK][alpha], true, "Collapse state key")
            return "Known ESO texture path used; keyboard heading rendering still requires an in-game check."
        end)
    end)

    Add("Existing category is identifiable for a pre-registration collision guard", function()
        WithIsolatedAutoCategory(function()
            local name = "Gate2 Collision"
            ac.RulesW:AddRule({
                name = name,
                tag = "Existing AutoCategory",
                rule = "true",
            })
            ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules = {
                { name = name, runpriority = 700, showpriority = 700, isHidden = false, icOwned = false },
            }
            ac.cacheInitBag(AC_BAG_TYPE_BACKPACK)
            local existingDefinition = ac.GetRuleByName(name)
            local existingAssignment = ac.GetBagRuleByName(AC_BAG_TYPE_BACKPACK, name)
            assert(existingDefinition ~= nil and existingAssignment ~= nil, "Existing collision is visible to preflight")

            local registered = false
            if existingDefinition == nil then
                ac.RegisterPlugin("InventoryCompanion Gate 2 Collision", function() end, {
                    { name = name, tag = "InventoryCompanion", rule = "true" },
                })
                registered = true
            end
            Equal(registered, false, "Collision skipped before plugin registration")
            Equal(ac.GetRuleByName(name), existingDefinition, "Existing definition is not renamed")
            Equal(ac.GetBagRuleByName(AC_BAG_TYPE_BACKPACK, name).name, name, "Existing assignment is not renamed")
            Equal(ac.GetUsableRuleName(name), name .. "1", "AutoCategory would suffix an unguarded duplicate")
            return "Guard condition is exercised; startup addTableRules rename path remains outside this fixture."
        end)
    end)

    Add("DEV gate plugin waits for IC load after dependency initialization and exposes one predefined rule", function()
        ac.acctSaved.bags, ac.acctSaved.collapses = ac.saved.bags, ac.saved.collapses
        ac.charSaved.accountWide = true
        ac.charSaved.bags, ac.charSaved.collapses = Copy(ac.saved.bags), Copy(ac.saved.collapses)
        ac.saved.bags, ac.saved.collapses = ac.acctSaved.bags, ac.acctSaved.collapses
        local status, detail = ic.GetAutoCategoryGateRegistration()
        Equal(status, "registered", "Startup gate status")
        assert(detail:find("before AutoCategory initialization", 1, true), "Startup timing report")
        local plugin = ac.Plugins["InventoryCompanion DEV AutoCategory Gate"]
        assert(plugin and plugin.predef and #plugin.predef == 1, "Registered predefined rule")
        Equal(plugin.predef[1].name, "|t18:18:EsoUI/Art/Buttons/plus_up.dds|t InventoryCompanion DEV Gate Reload",
            "Unique gate category identity")
        Same(ac.GetRuleByName(plugin.predef[1].name), plugin.predef[1], "Runtime predefined definition")
        assert(type(ac.Environment.ic_autocategory_gate_match) == "function", "Plugin init rule function")
        return "Startup event preflight and plugin initialization used the actual AutoCategory plugin API."
    end)

    Add("Collision command refuses registration without changing external definitions or either profile", function()
        local accountBefore, characterBefore = Copy(ac.acctSaved.bags), Copy(ac.charSaved.bags)
        local ok, report = pcall(SLASH_COMMANDS["/icacspike"], "collision")
        Equal(ok, false, "Copyable collision diagnostic")
        assert(tostring(report):find("PASS collision detected before registration", 1, true),
            "Collision preflight report: " .. tostring(report))
        assert(tostring(report):find("registration was not called", 1, true), "Registration refusal report")
        Same(ac.acctSaved.bags, accountBefore, "Account profile after collision preflight")
        Same(ac.charSaved.bags, characterBefore, "Character profile after collision preflight")
        Same(ac.GetRuleByName("Spike External"), externalBefore, "Existing external definition")
        return "The existing assignment was never passed through AutoCategory's duplicate-rename path."
    end)

    Add("Context and priority commands report unavailable surfaces through copyable diagnostics", function()
        local accountBefore, characterBefore = Copy(ac.acctSaved.bags), Copy(ac.charSaved.bags)
        local contextOk, contextReport = pcall(SLASH_COMMANDS["/icacspike"], "context backpack")
        Equal(contextOk, false, "Context copyable diagnostic")
        assert(tostring(contextReport):find("NOT AVAILABLE", 1, true), "Unavailable context is reported")
        local orderOk, orderReport = pcall(SLASH_COMMANDS["/icacspike"], "order")
        Equal(orderOk, false, "Order copyable diagnostic")
        assert(tostring(orderReport):find("NOT AVAILABLE", 1, true), "Unavailable Backpack is reported")
        Same(ac.acctSaved.bags, accountBefore, "Account profile after unavailable probes")
        Same(ac.charSaved.bags, characterBefore, "Character profile after unavailable probes")
        return "Unavailable UI contexts are explicit and produce no saved-profile writes."
    end)

    Add("Context and multi-group priority commands execute their native-list paths offline", function()
        local orderSummary
        WithIsolatedAutoCategory(function()
            local oldRefresh = ac.RefreshList
            local oldPlayerInventory, oldPlayerControl = PLAYER_INVENTORY, ZO_PlayerInventory
            local oldCallLater = zo_callLater
            local delayed, drawCount = nil, 0
            local crafting = false
            local sourceRows = {}
            for slot = 0, 5 do
                sourceRows[#sourceRows + 1] = {
                    data = { bagId = BAG_BACKPACK, slotIndex = slot },
                }
            end
            sourceRows[#sourceRows + 1] = {
                data = { bagId = BAG_BACKPACK, slotIndex = 99 },
            }
            local inventory = { listView = { data = sourceRows } }
            PLAYER_INVENTORY = {
                inventories = { [INVENTORY_BACKPACK] = inventory },
                UpdateList = function() end,
            }
            ZO_PlayerInventory = { IsHidden = function() return false end }
            ac.AddRuleFunc("gate_order_anchor", function()
                return ac.checkingItemSlotIndex == 99
            end)
            ac.RulesW:AddRule({
                name = "Gate Order Higher Anchor",
                tag = "InventoryCompanion DEV Gate Fixture",
                rule = "gate_order_anchor()",
            })
            ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules = {
                Entry("Gate Order Higher Anchor", 200, 200),
                Entry("Spike External", 100, 100),
            }
            ac.RulesW:AddRule({
                name = "Gate Order Invisible Anchor",
                tag = "InventoryCompanion DEV Gate Fixture",
                rule = "false",
            })
            table.insert(ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules,
                Entry("Gate Order Invisible Anchor", 105, 105))
            local function RebuildList()
                drawCount = drawCount + 1
                local groups = {}
                for _, row in ipairs(sourceRows) do
                    local data = row.data
                    local found, name, runPriority, showPriority, bagType, hidden =
                        ac:MatchCategoryRules(data.bagId, data.slotIndex, crafting and AC_BAG_TYPE_CRAFTSTATION or nil)
                    data.AC_matched = found
                    data.AC_categoryName = name or "Other"
                    data.AC_categoryPriority = runPriority
                    data.AC_bagTypeId = bagType or AC_BAG_TYPE_BACKPACK
                    data.AC_isHidden = hidden
                    data.AC_lastUpdateTime = 12345
                    local group = groups[data.AC_categoryName]
                    if group == nil then
                        group = {
                            name = data.AC_categoryName,
                            showPriority = showPriority or 0,
                            items = {},
                            sortKey = string.format("%04d%s", 1000 - (showPriority or 0), data.AC_categoryName),
                        }
                        groups[data.AC_categoryName] = group
                    end
                    group.items[#group.items + 1] = row
                end
                local ordered = {}
                for _, group in pairs(groups) do ordered[#ordered + 1] = group end
                table.sort(ordered, function(left, right) return left.sortKey < right.sortKey end)
                inventory.listView.data = {}
                for _, group in ipairs(ordered) do
                    inventory.listView.data[#inventory.listView.data + 1] = {
                        data = { AC_isHeader = true, AC_categoryName = group.name },
                    }
                    for _, row in ipairs(group.items) do
                        inventory.listView.data[#inventory.listView.data + 1] = row
                    end
                end
            end
            ac.RefreshList = function(inventoryType, force)
                assert(inventoryType == INVENTORY_BACKPACK or inventoryType == INVENTORY_BANK or inventoryType == 880,
                    "Native-list probe inventory")
                Equal(force, inventoryType ~= 880, "Context-specific refresh argument")
                if drawCount == 1 then
                    local invalidated = 0
                    for _, row in ipairs(sourceRows) do
                        if row.data.AC_lastUpdateTime == nil then
                            invalidated = invalidated + 1
                        else
                            Equal(row.data.AC_lastUpdateTime, 12345, "Other row cache left unchanged")
                        end
                    end
                    Equal(invalidated, 1, "Only selected context row invalidated before refresh")
                end
                RebuildList()
            end
            zo_callLater = function(callback, delay)
                Equal(delay, 20000, "Bounded list-preview duration")
                delayed = callback
            end
            RebuildList()
            local contextOk, contextReport = pcall(SLASH_COMMANDS["/icacspike"], "context backpack plunder skull")
            Equal(contextOk, false, "Context diagnostic")
            assert(tostring(contextReport):find("PASS backpack classification/list rendering", 1, true),
                "Context native-list success report: " .. tostring(contextReport))

            local oldBankControl, oldItemName = ZO_PlayerBank, GetItemLinkName
            ZO_PlayerBank = { IsHidden = function() return false end }
            PLAYER_INVENTORY.inventories[INVENTORY_BANK] = inventory
            for _, row in ipairs(sourceRows) do row.data.bagId = BAG_SUBSCRIBER_BANK end
            GetItemLinkName = function() return "Synthetic ESO Plus item" end
            local subscriberOk, subscriberReport =
                pcall(SLASH_COMMANDS["/icacspike"], "context subscriber-bank")
            ZO_PlayerBank, GetItemLinkName = oldBankControl, oldItemName
            PLAYER_INVENTORY.inventories[INVENTORY_BANK] = nil
            for _, row in ipairs(sourceRows) do row.data.bagId = BAG_BACKPACK end
            Equal(subscriberOk, false, "Subscriber copyable diagnostic")
            assert(tostring(subscriberReport):find("PASS subscriber-bank source was specifically observed", 1, true),
                "Automatic subscriber selection: " .. tostring(subscriberReport))

            local oldPanel = SMITHING.deconstructionPanel
            SMITHING.deconstructionPanel = {
                inventory = { list = inventory.listView },
                control = { IsHidden = function() return false end },
            }
            crafting = true
            local craftingOk, craftingReport =
                pcall(SLASH_COMMANDS["/icacspike"], "context crafting-station plunder skull")
            Equal(craftingOk, false, "Crafting copyable diagnostic")
            SMITHING.deconstructionPanel = oldPanel
            assert(tostring(craftingReport):find("PASS crafting-station classification/list rendering", 1, true),
                "Crafting refresh success: " .. tostring(craftingReport))
            delayed()
            crafting = false

            inventory.listView.data = Copy(sourceRows)
            RebuildList()
            local orderOk, orderReport = pcall(SLASH_COMMANDS["/icacspike"], "order plunder skull")
            Equal(orderOk, false, "Priority diagnostic")
            assert(tostring(orderReport):find("top-slot classification/native heading order above existing categories", 1, true),
                "Top priority report: " .. tostring(orderReport))
            assert(tostring(orderReport):find("fractional classification and visible order", 1, true),
                "Between priority report: " .. tostring(orderReport))
            assert(tostring(orderReport):find("Actual top-slot headings:", 1, true)
                and tostring(orderReport):find("Actual between-category headings:", 1, true),
                "The report includes observed headings, not only formatter output")
            assert(tostring(orderReport):find("Immediate classification gap: 105 > 100; visible higher anchor priority: 200.", 1, true),
                "Invisible immediate anchor retains the narrow gap while visible heading uses a wider anchor")
            assert(delayed ~= nil and drawCount >= 3, "Both commands exercised native refresh and delayed redraw.")
            local function DiagnosticLine(fragment)
                for line in tostring(orderReport):gmatch("[^\r\n]+") do
                    if line:find(fragment, 1, true) then return line end
                end
                return "missing: " .. fragment
            end
            orderSummary = DiagnosticLine("top-slot classification/native heading order")
                .. "\n" .. DiagnosticLine("Top-slot details:")
                .. "\n" .. DiagnosticLine("Actual top-slot headings:")
                .. "\n" .. DiagnosticLine("fractional classification and visible order")
                .. "\n" .. DiagnosticLine("ESO fractional %04d sample")
            ac.RefreshList = oldRefresh
            PLAYER_INVENTORY, ZO_PlayerInventory, zo_callLater =
                oldPlayerInventory, oldPlayerControl, oldCallLater
        end)
        return "Synthetic lists exercised one context render and five-group top/fractional heading-order paths; ESO rendering remains an in-game gate.\n"
            .. orderSummary
    end)

    Add("Profile projection writes only the active AutoCategory profile and tagged cleanup is exact", function()
        local originalMode = ac.charSaved.accountWide
        local originalBags, originalCollapses = ac.saved.bags, ac.saved.collapses
        local accountBefore, characterBefore = Copy(ac.acctSaved.bags), Copy(ac.charSaved.bags)
        local rawAccountBefore, rawCharacterBefore = Copy(rawAccount), Copy(rawCharacter)
        local originalGetBagSize = GetBagSize
        local ok, failure = pcall(function()
            GetBagSize = function(bag)
                Equal(bag, BAG_BACKPACK, "Profile item discovery bag")
                return 1
            end
            local baselineOk, baselineReport = pcall(SLASH_COMMANDS["/icacspike"], "profile baseline")
            Equal(baselineOk, false, "Baseline diagnostic window")
            assert(tostring(baselineReport):find("read-only account/character assignment baseline", 1, true),
                "Profile baseline report")

            ac.charSaved.accountWide = false
            ac.saved.bags, ac.saved.collapses = ac.charSaved.bags, ac.charSaved.collapses
            local characterOk, characterReport = pcall(SLASH_COMMANDS["/icacspike"], "profile project plunder skull")
            Equal(characterOk, false, "Character profile projection report")
            assert(tostring(characterReport):find("active profile only", 1, true), "Character active-write report")
            assert(tostring(characterReport):find("inactive profile is byte-shape/value-equivalent", 1, true),
                "Account profile preservation report")
            Same(ac.acctSaved.bags, accountBefore, "Inactive account profile")
            ac.cacheInitBag(AC_BAG_TYPE_BACKPACK)
            local characterCheckOk, characterCheckReport =
                pcall(SLASH_COMMANDS["/icacspike"], "profile check plunder skull")
            Equal(characterCheckOk, false, "Character profile reload check report")
            assert(tostring(characterCheckReport):find("exactly one tagged assignment", 1, true),
                "Character profile reload check")

            local characterWithGate = Copy(ac.charSaved.bags)
            local nextBaselineOk = pcall(SLASH_COMMANDS["/icacspike"], "profile baseline")
            Equal(nextBaselineOk, false, "Second baseline diagnostic")
            ac.charSaved.accountWide = true
            ac.saved.bags, ac.saved.collapses = ac.acctSaved.bags, ac.acctSaved.collapses
            local accountOk, accountReport = pcall(SLASH_COMMANDS["/icacspike"], "profile project plunder skull")
            Equal(accountOk, false, "Account profile projection report")
            assert(tostring(accountReport):find("inactive profile is byte-shape/value-equivalent", 1, true),
                "Character profile preservation report")
            Same(ac.charSaved.bags, characterWithGate, "Inactive character profile")
            ac.cacheInitialize()
            local accountCheckOk, accountCheckReport =
                pcall(SLASH_COMMANDS["/icacspike"], "profile check plunder skull")
            Equal(accountCheckOk, false, "Account profile reload check report")
            assert(tostring(accountCheckReport):find("exactly one tagged assignment", 1, true),
                "Account profile reload check")

            local cleanupOk, cleanupReport = pcall(SLASH_COMMANDS["/icacspike"], "cleanup")
            Equal(cleanupOk, false, "Cleanup diagnostic window")
            assert(tostring(cleanupReport):find("Removed 2 exact-token gate assignments", 1, true),
                "Cleanup counts only owned entries")
            Same(ac.acctSaved.bags, accountBefore, "Account profile after cleanup")
            Same(ac.charSaved.bags, characterBefore, "Character profile after cleanup")
            Same(rawAccount, rawAccountBefore, "Inventory Companion account saved variables")
            Same(rawCharacter, rawCharacterBefore, "Inventory Companion character saved variables")
        end)

        Add("Profile switch uses AutoCategory core path without defective settings cleanup", function()
            local originalMode = ac.charSaved.accountWide
            local originalBags, originalCollapses = ac.saved.bags, ac.saved.collapses
            local originalGeneral, originalAppearance = ac.saved.general, ac.saved.appearance
            local oldBagSet, oldCatSet = AC_UI.BagSet, AC_UI.CatSet
            local oldDropdown, oldControls = AC_UI.RefreshDropdownData, AC_UI.RefreshControls
            local accountBefore, characterBefore = Copy(ac.acctSaved.bags), Copy(ac.charSaved.bags)
            local function SettingsMustNotRun()
                error("Settings-only cleanup/refresh must not run during the core switch")
            end
            AC_UI.BagSet = { clear = SettingsMustNotRun }
            AC_UI.CatSet = { clear = SettingsMustNotRun }
            AC_UI.RefreshDropdownData = SettingsMustNotRun
            AC_UI.RefreshControls = SettingsMustNotRun
            local ok, failure = pcall(function()
                for _, target in ipairs({ "character", "account" }) do
                    local switchOk, report = pcall(SLASH_COMMANDS["/icacspike"], "profile switch " .. target)
                    Equal(switchOk, false, "Copyable switch report")
                    assert(tostring(report):find("Switched AutoCategory", 1, true), tostring(report))
                    assert(tostring(report):find("PASS account-wide assignments unchanged", 1, true), tostring(report))
                    assert(tostring(report):find("PASS character-specific assignments unchanged", 1, true), tostring(report))
                    Equal(ac.charSaved.accountWide, target == "account", "Switched mode")
                    Equal(ac.saved.bags, target == "account" and ac.acctSaved.bags or ac.charSaved.bags, "Active bags")
                    Same(ac.acctSaved.bags, accountBefore, "Account assignments")
                    Same(ac.charSaved.bags, characterBefore, "Character assignments")
                end
                local repeatOk, report = pcall(SLASH_COMMANDS["/icacspike"], "profile switch account")
                Equal(repeatOk, false, "Copyable unchanged report")
                assert(tostring(report):find("UNCHANGED", 1, true), tostring(report))
            end)
            ac.charSaved.accountWide = originalMode
            ac.saved.bags, ac.saved.collapses = originalBags, originalCollapses
            ac.saved.general, ac.saved.appearance = originalGeneral, originalAppearance
            AC_UI.BagSet, AC_UI.CatSet = oldBagSet, oldCatSet
            AC_UI.RefreshDropdownData, AC_UI.RefreshControls = oldDropdown, oldControls
            if not ok then error(failure, 0) end
        end)
        GetBagSize = originalGetBagSize
        ac.charSaved.accountWide = originalMode
        ac.saved.bags, ac.saved.collapses = originalBags, originalCollapses
        local cleanupOk, cleanupFailure = pcall(SLASH_COMMANDS["/icacspike"], "cleanup")
        if not cleanupOk and not tostring(cleanupFailure):find("Removed 0 exact-token gate assignments", 1, true) then
            error(cleanupFailure, 0)
        end
        if not ok then error(failure, 0) end
        return "Both profile directions were compared against the pre-switch inactive-profile snapshot; exact-token cleanup restored both."
    end)

    return tests
end
