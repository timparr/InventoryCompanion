InventoryCompanion = { SettingsName = "InventoryCompanion_AutoCategorySpike", IsDevelopment = true }
SLASH_COMMANDS = {}
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
    ac.Inited = true
    ac.Environment = {}
    ac.acctSaved = {
        general = {},
        appearance = { CATEGORY_OTHER_TEXT = "Other" },
    }
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
    Add("Slash command reports unavailable dependency without running the probe or throwing", function()
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
                SLASH_COMMANDS["/icacspike"]("")
                Equal(#messages, index, "One useful status per invocation")
                assert(messages[index]:find(case.fragment, 1, true), "Wrong dependency status")
            end
            Equal(probeCalls, 0, "No probe calls while unavailable")
        end)
        AutoCategory = ac
        d, ic.RunAutoCategoryNativeProbe = originalPrint, originalProbe
        if not ok then error(failure, 0) end
    end)
    Add("DEV Debug Key dispatches the same rendering command", function()
        local command = SLASH_COMMANDS["/icacspike"]
        local argument
        SLASH_COMMANDS["/icacspike"] = function(value) argument = value end
        local ok, failure = pcall(ic.Debug)
        SLASH_COMMANDS["/icacspike"] = command
        if not ok then error(failure, 0) end
        Equal(argument, "render", "Debug key rendering mode")
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
    return tests
end
