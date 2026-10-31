InventoryCompanion = { SettingsName = "InventoryCompanion_AutoCategorySpike", IsDevelopment = true }
SLASH_COMMANDS = {}

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
            Equal(#result, 7, "Complete DEV probe report")
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
                Equal(winner, "InventoryCompanion Spike B", "Rendering winner")
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
    return tests
end
