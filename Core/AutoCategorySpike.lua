local this = InventoryCompanion

local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, entry in pairs(value) do result[key] = Copy(entry, seen) end
    return setmetatable(result, getmetatable(value))
end

local function ContextBagType(context)
    return context.bagType()
end

local function ContextSpecialType(context)
    return context.specialType and context.specialType() or nil
end

local function Fields(value)
    local fields = {}
    for key, entry in pairs(value) do fields[key] = entry end
    return fields
end

local function ReplaceFields(target, values)
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(values) do target[key] = value end
end

-- ZO_SavedVars interfaces are empty proxies forwarding reads/writes to raw data via their metatable.
local function DetachedProfile(profile)
    local metatable = getmetatable(profile)
    if metatable == nil then return Copy(profile) end
    assert(type(metatable.__index) == "table",
        "Unsupported saved-variable profile shape; probe isolation cannot be guaranteed")
    return Copy(metatable.__index)
end

local function Equal(actual, expected, message)
    assert(actual == expected,
        string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local gateToken = "InventoryCompanion-DEV-AutoCategory-Gate-20261031"
local gatePluginName = "InventoryCompanion DEV AutoCategory Gate"
local gateRuleName = "|t18:18:EsoUI/Art/Buttons/plus_up.dds|t InventoryCompanion DEV Gate Reload"
local gateRuleTag = "InventoryCompanion DEV AutoCategory Gate"
local gatePredicateName = "ic_autocategory_gate_match"
local gateSearch
local gateRegistration = { status = "waiting", detail = "Waiting for AutoCategory saved data." }
local profileBaseline
function this.GetAutoCategoryGateRegistration()
    return gateRegistration.status, gateRegistration.detail
end
local gateContexts = {
    backpack = {
        bagType = function() return AC_BAG_TYPE_BACKPACK end,
        inventoryType = INVENTORY_BACKPACK,
        bagIds = { BAG_BACKPACK },
        control = function() return ZO_PlayerInventory end,
    },
    bank = {
        bagType = function() return AC_BAG_TYPE_BANK end,
        inventoryType = INVENTORY_BANK,
        bagIds = { BAG_BANK },
        control = function() return ZO_PlayerBank end,
    },
    ["subscriber-bank"] = {
        bagType = function() return AC_BAG_TYPE_BANK end,
        inventoryType = INVENTORY_BANK,
        bagIds = { BAG_SUBSCRIBER_BANK },
        control = function() return ZO_PlayerBank end,
    },
    ["guild-bank"] = {
        bagType = function() return AC_BAG_TYPE_GUILDBANK end,
        inventoryType = INVENTORY_GUILD_BANK,
        bagIds = { BAG_GUILDBANK },
        control = function() return ZO_GuildBank end,
    },
    ["house-bank"] = {
        bagType = function() return AC_BAG_TYPE_HOUSEBANK end,
        inventoryType = INVENTORY_HOUSE_BANK,
        bagIds = {
            BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TWO, BAG_HOUSE_BANK_THREE,
            BAG_HOUSE_BANK_FOUR, BAG_HOUSE_BANK_FIVE, BAG_HOUSE_BANK_SIX,
            BAG_HOUSE_BANK_SEVEN, BAG_HOUSE_BANK_EIGHT,
        },
        control = function() return ZO_HouseBank end,
    },
    ["craft-bag"] = {
        bagType = function() return AC_BAG_TYPE_CRAFTBAG end,
        inventoryType = INVENTORY_CRAFT_BAG,
        bagIds = { BAG_VIRTUAL },
        control = function() return ZO_CraftBag end,
    },
    ["crafting-station"] = {
        bagType = function() return AC_BAG_TYPE_CRAFTSTATION end,
        inventoryType = 880,
        specialType = function() return AC_BAG_TYPE_CRAFTSTATION end,
        bagIds = { BAG_BACKPACK },
        inventory = function() return SMITHING.deconstructionPanel.inventory end,
        control = function() return SMITHING.deconstructionPanel.control end,
    },
    ["furniture-vault"] = {
        bagType = function() return AC_BAG_TYPE_FURNVAULT end,
        inventoryType = INVENTORY_FURNITURE_VAULT,
        bagIds = { BAG_FURNITURE_VAULT },
        control = function() return ZO_FurnitureVault end,
    },
}

local function ContainsName(rules, name, source)
    if rules == nil then return false end
    if type(rules) ~= "table" then return false, source .. " is not a table" end
    for _, rule in pairs(rules) do
        if type(rule) == "table" and rule.name == name then return true end
    end
    return false
end

local function GateNameCollision(name)
    local ac = AutoCategory
    if type(ac.RulesW) ~= "table" or type(ac.Plugins) ~= "table" then
        return true, "AutoCategory rule/plugin registries are unavailable", "unavailable"
    end
    local sources = {
        { ac.RulesW.ruleList, "runtime rule list" },
        { ac.predefinedRules, "predefined rules" },
        { ac.default_rules and ac.default_rules.rules, "default rules" },
        { ac.acctRules and ac.acctRules.rules, "account rules" },
        { ac.acctSaved and ac.acctSaved.rules, "account saved rules" },
        { ac.charSaved and ac.charSaved.rules, "character saved rules" },
    }
    for _, source in ipairs(sources) do
        local found, failure = ContainsName(source[1], name, source[2])
        if failure then return true, failure, "unavailable" end
        if found then return true, source[2] end
    end
    for pluginName, plugin in pairs(ac.Plugins) do
        if pluginName ~= gatePluginName and plugin.predef then
            local found, failure = ContainsName(plugin.predef, name, "plugin " .. pluginName)
            if failure then return true, failure, "unavailable" end
            if found then return true, "plugin " .. pluginName end
        end
    end
    for _, profileName in ipairs({ "acctSaved", "charSaved" }) do
        local profile = ac[profileName]
        if type(profile) ~= "table" or type(profile.bags) ~= "table" then
            return true, profileName .. " bag assignments are unavailable", "unavailable"
        end
        for bagType = 1, 7 do
            local bag = profile.bags[bagType]
            if type(bag) ~= "table" or type(bag.rules) ~= "table" then
                return true, profileName .. " bag " .. bagType .. " assignments are unavailable", "unavailable"
            end
            for _, entry in ipairs(bag.rules) do
                if type(entry) ~= "table" then
                    return true, profileName .. " bag " .. bagType .. " contains a malformed assignment", "unavailable"
                end
                if entry.name == name
                    and not (name == gateRuleName and entry.icAutoCategoryGate == gateToken) then
                    return true, profileName .. " bag " .. bagType .. " assignment"
                end
            end
        end
    end
    return false
end

local function RegisterGatePlugin()
    local ac = AutoCategory
    if type(ac) ~= "table" or type(ac.RegisterPlugin) ~= "function" or type(ac.AddRuleFunc) ~= "function" then
        gateRegistration = { status = "unavailable", detail = "AutoCategory plugin API is unavailable." }
        return false
    end
    if ac.Inited then
        gateRegistration = { status = "late", detail = "AutoCategory initialized before the gate plugin could register." }
        return false
    end
    if type(ac.Plugins) ~= "table" or ac.Plugins[gatePluginName] ~= nil then
        gateRegistration = { status = "collision", detail = "The gate plugin name is already registered." }
        return false
    end
    local collides, source, status = GateNameCollision(gateRuleName)
    if collides then
        gateRegistration = {
            status = status or "collision",
            detail = "Gate rule registration refused before AutoCategory can rename anything: " .. source,
        }
        return false
    end
    local predefined = {
        {
            name = gateRuleName,
            tag = gateRuleTag,
            rule = gatePredicateName .. "()",
            description = "Temporary Inventory Companion DEV reload/profile gate.",
        },
    }
    ac.RegisterPlugin(gatePluginName, function()
        ac.AddRuleFunc(gatePredicateName, function()
            if type(gateSearch) ~= "string" or gateSearch == "" then return false end
            local link = ac.checkingItemLink
            return link ~= "" and GetItemLinkName(link):lower():find(gateSearch, 1, true) ~= nil
        end)
    end, predefined)
    assert(ac.Plugins[gatePluginName] ~= nil, "AutoCategory did not retain the gate plugin registration")
    gateRegistration = { status = "registered", detail = "Preflight passed; gate plugin registered before AutoCategory initialization." }
    return true
end

local gateEventName = "InventoryCompanion_DEV_AutoCategoryGate"
EVENT_MANAGER:RegisterForEvent(gateEventName, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= this.Name then return end
    EVENT_MANAGER:UnregisterForEvent(gateEventName, EVENT_ADD_ON_LOADED)
    RegisterGatePlugin()
end)

function this.RunAutoCategoryNativeProbe(search, render)
    assert(this.IsDevelopment, "AutoCategory spike is DEV-only")
    local ac = AutoCategory
    assert(type(ac) == "table" and ac.Inited and ac.Enabled,
        "Enable AutoCategory and wait for initialization before running /icacspike")
    for _, name in ipairs({ "AddRuleFunc", "GetRuleByName", "MatchCategoryRules", "cacheInitBag", "cacheInitialize" }) do
        assert(type(ac[name]) == "function", "Unsupported AutoCategory contract: " .. name)
    end
    assert(type(ac.RulesW) == "table" and type(ac.RulesW.AddRule) == "function",
        "Unsupported AutoCategory RulesW contract")
    for _, name in ipairs({ "saved", "cache", "compiledRules", "Environment" }) do
        assert(type(ac[name]) == "table", "Unsupported AutoCategory state: " .. name)
    end
    assert(type(ac.saved.bags) == "table" and type(ac.saved.bags[AC_BAG_TYPE_BACKPACK]) == "table",
        "AutoCategory Backpack assignments are unavailable")
    if render then
        assert(not IsInGamepadPreferredMode(), "Rendering probe currently supports keyboard inventory only")
        assert(not ZO_PlayerInventory:IsHidden(), "Open your Backpack before running /icacspike render")
        assert(type(ac.RefreshList) == "function", "AutoCategory inventory refresh API is unavailable")
    end
    search = search:lower()
    local groupKey = "ic_acspike_group"
    local slot, itemLink
    for index = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local candidate = GetItemLink(BAG_BACKPACK, index)
        if candidate ~= "" and GetItemLinkName(candidate):lower():find(search, 1, true) then
            slot, itemLink = index, candidate
            break
        end
    end
    assert(slot ~= nil, "No backpack item found containing: " .. search)

    local snapshots = {}
    for _, target in ipairs({ ac.saved, ac.RulesW, ac.cache, ac.compiledRules, ac.Environment }) do
        snapshots[#snapshots + 1] = { target = target, fields = Fields(target) }
    end
    local originalAccount, originalCharacter = this.accountWide, this.character
    local originalWindow = ac.dspWin
    local originalContext = {
        bag = ac.checkingItemBagId, slot = ac.checkingItemSlotIndex,
        link = ac.checkingItemLink, suffix = ac.AdditionCategoryName,
    }
    local originalClassifier = ac.MatchCategoryRules
    local messages = {}
    local rendered = false
    local ok, failure = pcall(function()
        for _, snapshot in ipairs(snapshots) do
            ReplaceFields(snapshot.target, Copy(snapshot.fields))
        end
        ac.RulesW.compiled = ac.compiledRules
        this.accountWide, this.character = DetachedProfile(originalAccount), DetachedProfile(originalCharacter)
        this.InvalidateRuleCache()
        -- The real bag-cache path also repopulates its settings window; keep that UI isolated.
        ac.dspWin = { ClearList = function() end, AddItem = function() end, UpdateScrollList = function() end }

        local matched, externalName = ac:MatchCategoryRules(BAG_BACKPACK, slot)
        assert(matched, "The chosen item must already match an AutoCategory category")
        local externalRule = ac.GetRuleByName(externalName)
        assert(externalRule ~= nil,
            "Baseline category has a dynamic label; choose an item with a plain category name")
        local externalEntry
        for _, entry in ipairs(ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules) do
            if entry.name == externalName then externalEntry = Copy(entry); break end
        end
        assert(externalEntry ~= nil, "Baseline category has no Backpack assignment")
        local baselineExpression = externalRule.rule
        -- Probe-owned group lives only in the copied tracked lists, so user groups are never read or changed.
        local groupPattern = "*" .. search .. "*"
        this.CreateCustomRule(groupKey, "Spike Group")
        this.UpdateRulePatterns(groupKey, { groupPattern })
        local rules = this.GetRuntimeRules()
        assert(this.ItemMatchesRuntimeRule(itemLink, rules[groupKey]), "Probe group must match the chosen item")

        local iconPrefix = "|t18:18:EsoUI/Art/Buttons/plus_up.dds|t "
        local names = {
            iconPrefix .. "InventoryCompanion Spike A",
            iconPrefix .. "InventoryCompanion Spike B",
        }
        local predicateName = "ic_native_insertion_spike"
        assert(ac.Environment[predicateName] == nil, "Test predicate name is already in use")
        for _, name in ipairs(names) do
            assert(ac.GetRuleByName(name) == nil, "Test category name is already in use: " .. name)
        end
        local managedOrder = { names[1], names[2] }
        local predicateCalls = 0
        ac.AddRuleFunc(predicateName, function(name)
            predicateCalls = predicateCalls + 1
            Equal(ac.checkingItemBagId, BAG_BACKPACK, "Predicate inventory")
            if this.ItemMatchesRuntimeRule(ac.checkingItemLink, rules[groupKey]) then
                return name == managedOrder[1]
            end
            return false
        end)
        for _, name in ipairs(names) do
            ac.RulesW:AddRule({
                name = name, tag = "InventoryCompanion Spike",
                rule = predicateName .. "(" .. string.format("%q", name) .. ")",
            })
            assert(ac.compiledRules[name] ~= nil, "AutoCategory did not compile: " .. name)
        end
        local entries = {
            [names[1]] = { name = names[1], runpriority = 300, showpriority = 17, isHidden = false },
            [names[2]] = { name = names[2], runpriority = 200, showpriority = 19, isHidden = false },
            [externalName] = externalEntry,
        }
        local function CheckOrder(order, expected)
            managedOrder = {}
            local assignments = {}
            for position, name in ipairs(order) do
                entries[name].runpriority = 400 - position
                assignments[#assignments + 1] = entries[name]
                if name ~= externalName then managedOrder[#managedOrder + 1] = name end
            end
            ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules = assignments
            ac.cacheInitBag(AC_BAG_TYPE_BACKPACK)
            local found, winner = ac:MatchCategoryRules(BAG_BACKPACK, slot)
            Equal(found, true, "Native classifier match")
            Equal(winner, expected, "Actual classification")
            Equal(ac.MatchCategoryRules, originalClassifier, "Classifier remains unchanged")
            Equal(externalRule.rule, baselineExpression, "External expression unchanged")
            messages[#messages + 1] = "PASS " .. table.concat(order, " > ") .. " => " .. winner
        end
        messages[#messages + 1] = "Item: " .. GetItemLinkName(itemLink)
            .. "; baseline: " .. externalName .. "; temporary IC group pattern: " .. groupPattern
        local formatOk, fractionalSortKey = pcall(string.format, "%04d", -0.5)
        messages[#messages + 1] = formatOk
            and "PASS ESO fractional %04d: " .. fractionalSortKey
            or "FAIL ESO fractional %04d: " .. tostring(fractionalSortKey)
        CheckOrder({ names[1], externalName, names[2] }, names[1])
        CheckOrder({ externalName, names[1], names[2] }, externalName)
        CheckOrder({ names[2], externalName, names[1] }, names[2])
        ac.cacheInitialize()
        local found, winner = ac:MatchCategoryRules(BAG_BACKPACK, slot)
        Equal(found, true, "Match after full cache rebuild")
        Equal(winner, names[2], "Runtime insertion survives full cache rebuild")
        assert(predicateCalls > 0, "Native classifier must invoke our real matcher bridge")
        messages[#messages + 1] = "PASS full cache rebuild; predicate calls: " .. predicateCalls
        if render then
            local assignments = Copy(snapshots[1].fields.bags[AC_BAG_TYPE_BACKPACK].rules)
            local priority = 0
            for _, entry in ipairs(assignments) do priority = math.max(priority, entry.runpriority) end
            for index, name in ipairs({ names[2], names[1] }) do
                local entry = Copy(entries[name])
                entry.runpriority = priority + 3 - index
                entry.showpriority = 999 - index
                assignments[#assignments + 1] = entry
            end
            ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules = assignments
            ac.cacheInitBag(AC_BAG_TYPE_BACKPACK)
            rendered = true
            ac.RefreshList(INVENTORY_BACKPACK, true)
            local inventory = PLAYER_INVENTORY.inventories[INVENTORY_BACKPACK]
            local headerFound, itemFound = false, false
            local grouped, others = 0, 0
            for _, entry in ipairs(ZO_ScrollList_GetDataList(inventory.listView)) do
                local data = entry.data
                if data.AC_isHeader then
                    if data.AC_categoryName == names[2] then headerFound = true end
                else
                    local entryLink = GetItemLink(data.bagId, data.slotIndex)
                    local matches = this.ItemMatchesRuntimeRule(entryLink, rules[groupKey])
                    Equal(data.AC_categoryName == names[2], matches,
                        "Spike B placement for " .. GetItemLinkName(entryLink))
                    if matches then grouped = grouped + 1 else others = others + 1 end
                    if data.bagId == BAG_BACKPACK and data.slotIndex == slot then itemFound = true end
                end
            end
            assert(headerFound, "Backpack refresh did not build the temporary category header")
            assert(itemFound, "Backpack refresh did not place the chosen item in the temporary category")
            messages[#messages + 1] = string.format(
                "PASS actual Backpack list: all %d matching items in Spike B; %d other items kept their categories.",
                grouped, others)
        end
    end)
    for _, snapshot in ipairs(snapshots) do ReplaceFields(snapshot.target, snapshot.fields) end
    this.accountWide, this.character = originalAccount, originalCharacter
    ac.dspWin = originalWindow
    ac.checkingItemBagId, ac.checkingItemSlotIndex = originalContext.bag, originalContext.slot
    ac.checkingItemLink, ac.AdditionCategoryName = originalContext.link, originalContext.suffix
    this.InvalidateRuleCache()
    if rendered then
        -- Only the drawn list remains temporary; no copied rule state survives the command.
        zo_callLater(function() ac.RefreshList(INVENTORY_BACKPACK, true) end, 20000)
        messages[#messages + 1] = "Observe the inline-texture Spike B heading now; normal Backpack redraws in 20 seconds."
        messages[#messages + 1] = "Do not click the temporary header/collapse control. Rules have already been restored."
    end
    if not ok then error(failure, 0) end
    messages[#messages + 1] = "Restored original runtime state; no inventory transfers or saved-variable writes."
    messages[#messages + 1] = render
        and "Rendering list verified; visual approval, startup and reload are not certified."
        or "Classification proof only: live section rendering, startup and reload are not certified."
    return messages
end

local function Same(actual, expected, path, seen)
    if type(actual) ~= type(expected) then
        error(path .. ": expected " .. type(expected) .. ", got " .. type(actual), 0)
    end
    if type(expected) ~= "table" then
        Equal(actual, expected, path)
        return
    end
    seen = seen or {}
    if seen[expected] then
        Equal(actual, seen[expected], path .. " table reference")
        return
    end
    seen[expected] = actual
    for key, value in pairs(expected) do Same(actual[key], value, path .. "." .. tostring(key), seen) end
    for key in pairs(actual) do
        assert(expected[key] ~= nil, path .. " unexpectedly contains " .. tostring(key))
    end
end

local function ActiveAutoCategoryProfiles()
    local ac = AutoCategory
    assert(type(ac.acctSaved) == "table" and type(ac.charSaved) == "table",
        "AutoCategory saved profiles are unavailable")
    assert(type(ac.charSaved.accountWide) == "boolean",
        "AutoCategory character accountWide setting is unavailable")
    local accountWide = ac.charSaved.accountWide
    local activeName, active, inactiveName, inactive
    if accountWide then
        activeName, active, inactiveName, inactive = "account-wide", ac.acctSaved, "character-specific", ac.charSaved
    else
        activeName, active, inactiveName, inactive = "character-specific", ac.charSaved, "account-wide", ac.acctSaved
    end
    assert(type(active.bags) == "table" and type(inactive.bags) == "table",
        "AutoCategory profile bag assignments are unavailable")
    Equal(ac.saved.bags, active.bags, "AutoCategory's active bag-profile reference")
    return activeName, active, inactiveName, inactive
end

local function TaggedEntryCount(profile)
    local count = 0
    for bagType = 1, 7 do
        local bag = profile.bags[bagType]
        assert(type(bag) == "table" and type(bag.rules) == "table",
            "AutoCategory profile bag " .. bagType .. " is unavailable")
        for _, entry in ipairs(bag.rules) do
            if entry.icAutoCategoryGate == gateToken and entry.name == gateRuleName then
                count = count + 1
            end
        end
    end
    return count
end

local function FindGateItem(search)
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local link = GetItemLink(BAG_BACKPACK, slot)
        if link ~= "" and GetItemLinkName(link):lower():find(search, 1, true) then
            return slot, link
        end
    end
end

local function ClassifyWithoutSavedWrites(bagId, slot, specialType)
    local ac = AutoCategory
    local originalBags, originalCollapses = ac.saved.bags, ac.saved.collapses
    local originalContext = {
        bag = ac.checkingItemBagId,
        slot = ac.checkingItemSlotIndex,
        link = ac.checkingItemLink,
        suffix = ac.AdditionCategoryName,
    }
    ac.saved.bags, ac.saved.collapses = Copy(originalBags), Copy(originalCollapses)
    local ok, found, name, runPriority, showPriority, bagType, hidden = pcall(function()
        return ac:MatchCategoryRules(bagId, slot, specialType)
    end)
    ac.saved.bags, ac.saved.collapses = originalBags, originalCollapses
    ac.checkingItemBagId, ac.checkingItemSlotIndex = originalContext.bag, originalContext.slot
    ac.checkingItemLink, ac.AdditionCategoryName = originalContext.link, originalContext.suffix
    if not ok then error(found, 0) end
    return found, name, runPriority, showPriority, bagType, hidden
end

local function ShowDiagnostic(title, messages)
    error("[InventoryCompanion AutoCategory gate] " .. title
        .. " - DIAGNOSTIC REPORT - intentional copyable output, not a test failure\n"
        .. table.concat(messages, "\n"), 0)
end

local function RunGateProfileCommand(action, search)
    local ac = AutoCategory
    if gateRegistration.status ~= "registered" then
        return ShowDiagnostic("profile " .. action, {
            "NOT AVAILABLE: gate plugin registration is " .. gateRegistration.status .. ": " .. gateRegistration.detail,
            "No profile baseline, projection, or check was performed; no saved assignments were changed.",
        })
    end
    assert(ac.Inited and ac.Enabled, "Enable AutoCategory and wait for initialization before running this command")
    local activeName, active, inactiveName, inactive = ActiveAutoCategoryProfiles()
    local messages = {
        "Plugin registration: " .. gateRegistration.status .. "; " .. gateRegistration.detail,
        "Active AutoCategory profile: " .. activeName .. "; inactive profile: " .. inactiveName .. ".",
    }

    if action == "baseline" then
        profileBaseline = {
            activeName = activeName,
            accountBags = Copy(ac.acctSaved.bags),
            characterBags = Copy(ac.charSaved.bags),
        }
        messages[#messages + 1] = "PASS read-only account/character assignment baseline captured for this UI session."
        messages[#messages + 1] = "Press the Debug Key next to switch AutoCategory profiles without /reloadui; the following press projects the plunder skull test entry."
        return ShowDiagnostic("profile baseline", messages)
    end

    if action == "switch" then
        assert(search == "account" or search == "character",
            "Use /icacspike profile switch account or /icacspike profile switch character.")
        local accountWide = search == "account"
        if ac.charSaved.accountWide == accountWide then
            messages[#messages + 1] = "UNCHANGED: the requested profile is already active; no switch was performed."
            return ShowDiagnostic("profile switch", messages)
        end
        local accountBefore, characterBefore = Copy(ac.acctSaved.bags), Copy(ac.charSaved.bags)
        ac.charSaved.accountWide = accountWide
        ac.UpdateCurrentSavedVars()
        local switchedName = ActiveAutoCategoryProfiles()
        messages[#messages + 1] = "Switched AutoCategory from " .. activeName .. " to " .. switchedName
            .. " using its core profile/cache switch; no test assignment was added."
        for _, comparison in ipairs({
            { name = "account-wide", actual = ac.acctSaved.bags, expected = accountBefore },
            { name = "character-specific", actual = ac.charSaved.bags, expected = characterBefore },
        }) do
            local unchanged, failure = pcall(Same, comparison.actual, comparison.expected, comparison.name .. " assignments")
            messages[#messages + 1] = unchanged
                and "PASS " .. comparison.name .. " assignments unchanged by the switch."
                or "FAIL AutoCategory's switch changed " .. comparison.name .. " assignments: " .. tostring(failure)
        end
        messages[#messages + 1] = "AutoCategory may normalize legacy profile fields and rebuild caches during this authorized switch."
        messages[#messages + 1] = "Settings-only selection/refresh calls were not used: AutoCategory's CatSet.clear has a nil-global defect. Close any open AutoCategory settings panel."
        messages[#messages + 1] = "If both assignment comparisons pass, press Debug Key next to project the plunder skull test."
        return ShowDiagnostic("profile switch", messages)
    end

    if action == "project" then
        assert(type(search) == "string" and search ~= "", "Provide a Backpack item-name substring.")
        search = search:lower()
        local slot, itemLink = FindGateItem(search)
        assert(slot ~= nil, "No Backpack item found containing: " .. search)
        local rule = ac.GetRuleByName(gateRuleName)
        assert(rule ~= nil, "The registered gate definition is missing.")
        local rules = active.bags[AC_BAG_TYPE_BACKPACK].rules
        local gateEntry, taggedCount
        taggedCount = 0
        for _, entry in ipairs(rules) do
            if entry.name == gateRuleName then
                if entry.icAutoCategoryGate == gateToken then
                    taggedCount = taggedCount + 1
                    gateEntry = entry
                else
                    error("Refusing to overwrite an untagged AutoCategory assignment with the gate name.", 0)
                end
            end
        end
        assert(taggedCount <= 1, "Duplicate gate assignments exist in the active profile; run /icacspike cleanup.")
        local inserted = taggedCount == 0
        if inserted then
            local maxPriority = 1000
            for _, entry in ipairs(rules) do maxPriority = math.max(maxPriority, entry.runpriority or 0) end
            gateEntry = {
                name = gateRuleName,
                runpriority = maxPriority + 1.5,
                showpriority = maxPriority + 1.5,
                isHidden = false,
                icAutoCategoryGate = gateToken,
            }
            table.insert(rules, 1, gateEntry)
        end
        gateSearch = search
        local found, winner = ClassifyWithoutSavedWrites(BAG_BACKPACK, slot)
        Equal(found, true, "Gate item classification")
        Equal(winner, gateRuleName, "Gate item category")
        messages[#messages + 1] = (inserted and "PASS added one uniquely tagged entry to the active profile only."
            or "PASS reused the single existing tagged entry; no duplicate was added.")
        messages[#messages + 1] = "Item: " .. GetItemLinkName(itemLink) .. "; priority: "
            .. tostring(gateEntry.runpriority)
        messages[#messages + 1] = "PASS native classification: " .. winner
        if profileBaseline and profileBaseline.activeName ~= activeName then
            local expectedInactive = inactiveName == "account-wide"
                and profileBaseline.accountBags or profileBaseline.characterBags
            Same(inactive.bags, expectedInactive, "Inactive " .. inactiveName .. " profile")
            messages[#messages + 1] = "PASS inactive profile is byte-shape/value-equivalent to the pre-switch baseline."
        else
            messages[#messages + 1] = "OPEN inactive-profile comparison: capture /icacspike profile baseline before switching modes."
        end
        return ShowDiagnostic("profile projection", messages)
    end

    assert(action == "check", "Unknown profile action: " .. tostring(action))
    local taggedCount = TaggedEntryCount(active)
    Equal(taggedCount, 1, "Tagged gate assignments in active profile")
    assert(ac.GetRuleByName(gateRuleName) ~= nil, "The plugin definition is missing after reload/profile switch.")
    assert(type(search) == "string" and search ~= "", "Provide a Backpack item-name substring.")
    search = search:lower()
    local slot, itemLink = FindGateItem(search)
    assert(slot ~= nil, "No Backpack item found containing: " .. search)
    gateSearch = search
    local cacheEntry = ac.cache.entriesByName[AC_BAG_TYPE_BACKPACK]
        and ac.cache.entriesByName[AC_BAG_TYPE_BACKPACK][gateRuleName]
    assert(cacheEntry ~= nil, "The active AutoCategory cache does not contain the gate assignment; reload UI before checking.")
    local found, winner = ClassifyWithoutSavedWrites(BAG_BACKPACK, slot)
    Equal(found, true, "Persisted gate classification")
    Equal(winner, gateRuleName, "Persisted gate category")
    messages[#messages + 1] = "PASS exactly one tagged assignment and its predefined plugin definition are present."
    messages[#messages + 1] = "PASS native classification after reload/profile selection: "
        .. GetItemLinkName(itemLink) .. " => " .. winner
    messages[#messages + 1] = "This checks AutoCategory's persisted active profile; it does not prove an unimplemented IC auto-projection hook."
    return ShowDiagnostic("profile/reload check", messages)
end

local function RunGateCleanup()
    local ac = AutoCategory
    assert(type(ac) == "table" and type(ac.acctSaved) == "table" and type(ac.charSaved) == "table",
        "AutoCategory saved profiles are unavailable; no cleanup was performed.")
    local removed = 0
    for _, profileName in ipairs({ "acctSaved", "charSaved" }) do
        local profile = ac[profileName]
        assert(type(profile.bags) == "table", profileName .. " bag assignments are unavailable; no cleanup was performed.")
        for bagType = 1, 7 do
            local bag = profile.bags[bagType]
            assert(type(bag) == "table" and type(bag.rules) == "table",
                profileName .. " bag " .. bagType .. " assignments are unavailable; no cleanup was performed.")
            for index = #bag.rules, 1, -1 do
                local entry = bag.rules[index]
                if entry.name == gateRuleName and entry.icAutoCategoryGate == gateToken then
                    table.remove(bag.rules, index)
                    removed = removed + 1
                end
            end
        end
    end
    gateSearch, profileBaseline = nil, nil
    if ac.Inited then ac.cacheInitialize() end
    ShowDiagnostic("cleanup", {
        "Removed " .. removed .. " exact-token gate assignments across the account and character profiles.",
        "No other AutoCategory entries, definitions, collapse state, Inventory Companion saved variables, or items were changed.",
    })
end

local function RunCollisionProbe()
    local ac = AutoCategory
    local activeName, active = ActiveAutoCategoryProfiles()
    local candidate
    for _, entry in ipairs(active.bags[AC_BAG_TYPE_BACKPACK].rules) do
        if entry.name ~= gateRuleName and ac.GetRuleByName(entry.name) then
            candidate = entry.name
            break
        end
    end
    assert(candidate ~= nil, "No existing Backpack category is available as a collision fixture.")
    local originalRule = ac.GetRuleByName(candidate)
    local definitionBefore = Copy(originalRule)
    local assignmentsBefore = {
        account = Copy(ac.acctSaved.bags),
        character = Copy(ac.charSaved.bags),
    }
    local collides, source = GateNameCollision(candidate)
    Equal(collides, true, "Existing category collision preflight")
    Equal(ac.GetRuleByName(candidate), originalRule, "Existing rule object identity")
    Same(originalRule, definitionBefore, "Existing rule definition")
    Same(ac.acctSaved.bags, assignmentsBefore.account, "Account assignments after preflight")
    Same(ac.charSaved.bags, assignmentsBefore.character, "Character assignments after preflight")
    ShowDiagnostic("collision preflight", {
        "Candidate: " .. candidate .. "; active profile: " .. activeName .. ".",
        "PASS collision detected before registration (" .. tostring(source) .. ").",
        "PASS registration was not called; existing rule identity/definition and both profiles' assignments are unchanged.",
        "The current startup collision test safely refuses the candidate; it does not deliberately invoke AutoCategory's renaming path.",
    })
end

local function WithIsolatedAutoCategory(run, refreshType, refreshEvenIfHidden)
    local ac = AutoCategory
    local snapshots = {}
    for _, target in ipairs({ ac.saved, ac.RulesW, ac.cache, ac.compiledRules, ac.Environment }) do
        snapshots[#snapshots + 1] = { target = target, fields = Fields(target) }
    end
    local originalWindow = ac.dspWin
    local originalContext = {
        bag = ac.checkingItemBagId,
        slot = ac.checkingItemSlotIndex,
        link = ac.checkingItemLink,
        suffix = ac.AdditionCategoryName,
    }
    local originalClassifier = ac.MatchCategoryRules
    local rendered = false
    local messages = {}
    local ok, failure = pcall(function()
        for _, snapshot in ipairs(snapshots) do
            ReplaceFields(snapshot.target, Copy(snapshot.fields))
        end
        ac.RulesW.compiled = ac.compiledRules
        ac.dspWin = {
            ClearList = function() end,
            AddItem = function() end,
            UpdateScrollList = function() end,
        }
        run(messages, function() rendered = true end)
        Equal(ac.MatchCategoryRules, originalClassifier, "Classifier remains unchanged")
    end)
    for _, snapshot in ipairs(snapshots) do ReplaceFields(snapshot.target, snapshot.fields) end
    ac.dspWin = originalWindow
    ac.checkingItemBagId, ac.checkingItemSlotIndex = originalContext.bag, originalContext.slot
    ac.checkingItemLink, ac.AdditionCategoryName = originalContext.link, originalContext.suffix
    if rendered then
        zo_callLater(function() ac.RefreshList(refreshType, refreshEvenIfHidden ~= false) end, 20000)
        messages[#messages + 1] = "Temporary native list preview only; original AutoCategory state was restored. Normal redraw is scheduled in 20 seconds."
        messages[#messages + 1] = "Do not click temporary test headings; no item or saved-variable change is needed."
    end
    if not ok then error(failure, 0) end
    return messages
end

local function ContextInventory(context)
    if context.inventory then
        local inventory = context.inventory()
        if inventory == nil then return nil, nil end
        return inventory, inventory.list
    end
    local inventory = PLAYER_INVENTORY.inventories[context.inventoryType]
    if inventory == nil then return nil, nil end
    return inventory, inventory.listView
end

local function IsContextOpen(context)
    local control = context.control()
    if control == nil or type(control.IsHidden) ~= "function" then return false end
    return not control:IsHidden()
end

local function IsContextBag(context, bagId)
    for _, allowed in ipairs(context.bagIds) do
        if bagId == allowed then return true end
    end
    return false
end

local function FindContextItem(context, rows, search)
    for _, row in ipairs(rows) do
        local data = row.data
        if type(data) == "table" and not data.AC_isHeader
            and IsContextBag(context, data.bagId) and data.slotIndex ~= nil then
            local link = GetItemLink(data.bagId, data.slotIndex)
            if link ~= "" and GetItemLinkName(link):lower():find(search, 1, true) then
                return { bagId = data.bagId, slot = data.slotIndex, link = link }
            end
        end
    end
end

local function RunContextProbe(contextName, search)
    local context = gateContexts[contextName]
    if context == nil then
        return ShowDiagnostic("inventory context", {
            "NOT AVAILABLE: unknown context '" .. tostring(contextName) .. "'.",
            "Use backpack, bank, subscriber-bank, guild-bank, house-bank, crafting-station, craft-bag, or furniture-vault.",
        })
    end
    if IsInGamepadPreferredMode() then
        return ShowDiagnostic("inventory context", {
            "NOT AVAILABLE: these probes currently cover keyboard inventory lists only.",
            "No AutoCategory assignments, rules, or items were changed.",
        })
    end
    if not IsContextOpen(context) then
        return ShowDiagnostic("inventory context", {
            "NOT AVAILABLE: open the " .. contextName .. " inventory/context, then retry.",
            "No AutoCategory assignments, rules, or items were changed.",
        })
    end
    local _, list = ContextInventory(context)
    if list == nil then
        return ShowDiagnostic("inventory context", {
            "NOT AVAILABLE: AutoCategory's native list surface for " .. contextName .. " is unavailable.",
            "No AutoCategory assignments, rules, or items were changed.",
        })
    end
    if search == "" and contextName ~= "subscriber-bank" then search = "plunder skull" end
    search = search:lower()
    local item = FindContextItem(context, ZO_ScrollList_GetDataList(list), search)
    if item == nil then
        return ShowDiagnostic("inventory context", {
            "NOT AVAILABLE: no visible " .. contextName .. " item matches '" .. search .. "'.",
            contextName == "subscriber-bank" and "ESO+ slots share the normal bank list. Run /icacspike context subscriber-bank without an item name to select any ESO+ row by bag ID; if none is available, leave this gate open."
                or "Use a visible item-name substring from this context, then retry.",
            "No AutoCategory assignments, rules, or items were changed.",
        })
    end

    local ac = AutoCategory
    local contextBagType = ContextBagType(context)
    local specialType = ContextSpecialType(context)
    local name = "|t18:18:EsoUI/Art/Buttons/plus_up.dds|t InventoryCompanion DEV Context " .. contextName
    local predicate = "ic_autocategory_gate_context_" .. contextName:gsub("[^%w]", "_")
    local refreshType = context.inventoryType
    local refreshEvenIfHidden = contextName ~= "crafting-station"
    local messages = WithIsolatedAutoCategory(function(report, markRendered)
        assert(ac.GetRuleByName(name) == nil, "Temporary context name is already registered: " .. name)
        assert(ac.Environment[predicate] == nil, "Temporary context predicate is already registered: " .. predicate)
        local baselineFound, baselineName = ac:MatchCategoryRules(item.bagId, item.slot, specialType)
        local rules = ac.saved.bags[contextBagType].rules
        local maxPriority = 0
        for _, entry in ipairs(rules) do maxPriority = math.max(maxPriority, entry.runpriority or 0) end
        ac.AddRuleFunc(predicate, function()
            return ac.checkingItemBagId == item.bagId and ac.checkingItemSlotIndex == item.slot
        end)
        ac.RulesW:AddRule({
            name = name,
            tag = gateRuleTag,
            rule = predicate .. "()",
        })
        assert(ac.compiledRules[name] ~= nil, "AutoCategory did not compile the context probe.")
        rules[#rules + 1] = {
            name = name,
            runpriority = maxPriority + 1,
            showpriority = maxPriority + 1,
            isHidden = false,
            icAutoCategoryGate = gateToken,
        }
        ac.cacheInitBag(contextBagType)
        for _, row in ipairs(ZO_ScrollList_GetDataList(list)) do
            local data = row.data
            if not data.AC_isHeader and data.bagId == item.bagId and data.slotIndex == item.slot then
                data.AC_lastUpdateTime = nil
            end
        end
        markRendered()
        ac.RefreshList(refreshType, refreshEvenIfHidden)
        local renderedRows = ZO_ScrollList_GetDataList(list)
        local headerFound, itemFound = false, false
        for _, row in ipairs(renderedRows) do
            local data = row.data
            if data.AC_isHeader and data.AC_categoryName == name then
                headerFound = true
            elseif data.bagId == item.bagId and data.slotIndex == item.slot then
                itemFound = true
                Equal(data.AC_categoryName, name, "Native list category identity")
                Equal(data.AC_bagTypeId, contextBagType, "Native list context")
            end
        end
        assert(headerFound, "Native " .. contextName .. " list did not render the temporary heading.")
        assert(itemFound, "The selected item was not present in the native " .. contextName .. " list.")
        local found, winner, runPriority = ac:MatchCategoryRules(item.bagId, item.slot, specialType)
        Equal(found, true, "Native context classification")
        Equal(winner, name, "Native context winner")
        report[#report + 1] = "PASS " .. contextName .. " classification/list rendering: "
            .. GetItemLinkName(item.link) .. " => " .. winner
        report[#report + 1] = "Bag ID " .. item.bagId         .. "; AutoCategory context " .. contextBagType
            .. "; temporary run priority " .. tostring(runPriority) .. "."
        report[#report + 1] = baselineFound
            and "Baseline category before probe: " .. baselineName .. "."
            or "Baseline was ungrouped; the test category still rendered through native insertion."
        if contextName == "subscriber-bank" then
            Equal(item.bagId, BAG_SUBSCRIBER_BANK, "Subscriber-bank item source")
            report[#report + 1] = "PASS subscriber-bank source was specifically observed."
        end
    end, refreshType, refreshEvenIfHidden)
    ShowDiagnostic("inventory context", messages)
end

local function CollectHeaders(list)
    local headers = {}
    for _, row in ipairs(ZO_ScrollList_GetDataList(list)) do
        local data = row.data
        if type(data) == "table" and data.AC_isHeader then
            headers[#headers + 1] = data.AC_categoryName
        end
    end
    return headers
end

local function HeaderIndex(headers, name)
    for index, value in ipairs(headers) do
        if value == name then return index end
    end
end

local function JoinNames(names)
    return table.concat(names, " > ")
end

local function RunOrderProbe(search)
    if IsInGamepadPreferredMode() or ZO_PlayerInventory == nil or ZO_PlayerInventory:IsHidden() then
        return ShowDiagnostic("priority/heading order", {
            "NOT AVAILABLE: open the keyboard Backpack before running /icacspike order.",
            "No AutoCategory assignments, rules, or items were changed.",
        })
    end
    local inventory = PLAYER_INVENTORY.inventories[INVENTORY_BACKPACK]
    assert(inventory and inventory.listView, "AutoCategory's Backpack scroll list is unavailable.")
    search = (search == "" and "plunder skull" or search):lower()
    local ac = AutoCategory
    local originalBag, originalSlot = ac.checkingItemBagId, ac.checkingItemSlotIndex
    local originalLink, originalSuffix = ac.checkingItemLink, ac.AdditionCategoryName
    local visibleHeaders = CollectHeaders(inventory.listView)
    local candidatesByCategory = {}
    for _, row in ipairs(ZO_ScrollList_GetDataList(inventory.listView)) do
        local data = row.data
        if type(data) == "table" and not data.AC_isHeader and data.bagId == BAG_BACKPACK
            and data.slotIndex ~= nil then
            local link = GetItemLink(data.bagId, data.slotIndex)
            if link ~= "" and GetItemLinkName(link):lower():find(search, 1, true) then
                local found, categoryName, runPriority =
                    ClassifyWithoutSavedWrites(data.bagId, data.slotIndex)
                local definition = found and ac.GetRuleByName(categoryName)
                if definition and definition.name == categoryName then
                    local entries = candidatesByCategory[categoryName]
                    if entries == nil then
                        entries = { priority = runPriority, items = {} }
                        candidatesByCategory[categoryName] = entries
                    end
                    entries.items[#entries.items + 1] = {
                        bagId = data.bagId,
                        slot = data.slotIndex,
                        link = link,
                    }
                end
            end
        end
    end
    ac.checkingItemBagId, ac.checkingItemSlotIndex = originalBag, originalSlot
    ac.checkingItemLink, ac.AdditionCategoryName = originalLink, originalSuffix

    local lowerName, lowerItems, lowerPriority
    for categoryName, entry in pairs(candidatesByCategory) do
        if lowerItems == nil or #entry.items > #lowerItems then
            lowerName, lowerItems, lowerPriority = categoryName, entry.items, entry.priority
        end
    end
    if lowerItems == nil or #lowerItems < 6 then
        return ShowDiagnostic("priority/heading order", {
            "NOT AVAILABLE: '" .. search .. "' must match at least six visible Backpack items in one existing category; found "
                .. tostring(lowerItems and #lowerItems or 0) .. ".",
            "Six allows five temporary headings plus an unchanged lower-category anchor.",
            "No AutoCategory assignments, rules, or items were changed.",
        })
    end
    local bagRules = ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules
    local lowerEntry
    for _, entry in ipairs(bagRules) do
        if entry.name == lowerName then lowerEntry = entry; break end
    end
    assert(lowerEntry ~= nil, "Baseline category has no native Backpack assignment.")
    local higherPriority = math.huge
    for _, entry in ipairs(bagRules) do
        if entry.name ~= lowerName and entry.runpriority > lowerPriority
            and entry.runpriority < higherPriority then
            higherPriority = entry.runpriority
        end
    end
    local higherName, visibleHigherPriority = nil, math.huge
    if higherPriority < math.huge then
        for _, name in ipairs(visibleHeaders) do
            for _, entry in ipairs(bagRules) do
                if entry.name == name and entry.runpriority >= higherPriority
                    and entry.runpriority < visibleHigherPriority then
                    higherName = name
                    visibleHigherPriority = entry.runpriority
                    break
                end
            end
        end
    end
    local selected = {}
    for index = 1, 5 do selected[index] = lowerItems[index] end
    local names, predicates = {}, {}
    local iconPrefix = "|t18:18:EsoUI/Art/Buttons/plus_up.dds|t "
    for index = 1, #selected do
        names[index] = iconPrefix .. "InventoryCompanion DEV Gate Order " .. index
        predicates[index] = "ic_autocategory_gate_order_" .. index
    end
    local messages = WithIsolatedAutoCategory(function(report, markRendered)
        local currentRules = ac.saved.bags[AC_BAG_TYPE_BACKPACK].rules
        local highestPriority = 1000
        for _, entry in ipairs(currentRules) do highestPriority = math.max(highestPriority, entry.runpriority or 0) end
        for index, name in ipairs(names) do
            assert(ac.GetRuleByName(name) == nil, "Temporary order category is already registered: " .. name)
            assert(ac.Environment[predicates[index]] == nil, "Temporary order predicate is already registered.")
            local item = selected[index]
            ac.AddRuleFunc(predicates[index], function()
                return ac.checkingItemBagId == item.bagId and ac.checkingItemSlotIndex == item.slot
            end)
            ac.RulesW:AddRule({ name = name, tag = gateRuleTag, rule = predicates[index] .. "()" })
            assert(ac.compiledRules[name] ~= nil, "AutoCategory did not compile " .. name)
        end

        local function ApplyPriorities(priorities)
            for index, name in ipairs(names) do
                local existing
                for _, entry in ipairs(currentRules) do
                    if entry.name == name and entry.icAutoCategoryGate == gateToken then
                        existing = entry
                        break
                    end
                end
                local entry = existing or {
                    name = name,
                    isHidden = false,
                    icAutoCategoryGate = gateToken,
                }
                entry.runpriority, entry.showpriority = priorities[index], priorities[index]
                if not existing then currentRules[#currentRules + 1] = entry end
            end
            ac.cacheInitBag(AC_BAG_TYPE_BACKPACK)
        end

        local function CheckClassification()
            local failures = {}
            for index, item in ipairs(selected) do
                local found, winner = ac:MatchCategoryRules(item.bagId, item.slot)
                if found ~= true or winner ~= names[index] then
                    failures[#failures + 1] = GetItemLinkName(item.link) .. " expected " .. names[index]
                        .. ", got " .. tostring(winner)
                end
            end
            return failures
        end

        local function RenderAndCheck(expected)
            local failures = CheckClassification()
            markRendered()
            ac.RefreshList(INVENTORY_BACKPACK, true)
            local headers = CollectHeaders(inventory.listView)
            local previous = 0
            for _, name in ipairs(expected) do
                local position = HeaderIndex(headers, name)
                if position == nil then
                    failures[#failures + 1] = "Native list omitted heading " .. name
                elseif position <= previous then
                    failures[#failures + 1] = "Heading order differs at " .. name
                else
                    previous = position
                end
            end
            for index, item in ipairs(selected) do
                local foundItem = false
                for _, row in ipairs(ZO_ScrollList_GetDataList(inventory.listView)) do
                    local data = row.data
                    if data.bagId == item.bagId and data.slotIndex == item.slot then
                        foundItem = true
                        if data.AC_categoryName ~= names[index] then
                            failures[#failures + 1] = "Native item row expected " .. names[index]
                                .. ", got " .. tostring(data.AC_categoryName)
                        end
                        break
                    end
                end
                if not foundItem then failures[#failures + 1] = "Native list omitted item " .. GetItemLinkName(item.link) end
            end
            return headers, failures
        end

        local topPriorities = {}
        for index = 1, #names do topPriorities[index] = highestPriority + (#names - index + 1) end
        ApplyPriorities(topPriorities)
        local topHeaders, topFailures = RenderAndCheck(names)
        local firstTestHeader = HeaderIndex(topHeaders, names[1])
        local lastTestHeader = HeaderIndex(topHeaders, names[#names])
        local testNameSet = {}
        for _, name in ipairs(names) do testNameSet[name] = true end
        local existingAfter = false
        for index, name in ipairs(topHeaders) do
            if lastTestHeader and index > lastTestHeader then existingAfter = true end
            if firstTestHeader and lastTestHeader and index < lastTestHeader and not testNameSet[name] then
                topFailures[#topFailures + 1] = "Existing category heading appeared before all top-slot groups: " .. name
            end
        end
        if not existingAfter then topFailures[#topFailures + 1] = "No existing category heading appeared below the test groups." end
        report[#report + 1] = (#topFailures == 0 and "PASS" or "FAIL")
            .. " top-slot classification/native heading order above existing categories: " .. JoinNames(names)
        if #topFailures > 0 then report[#report + 1] = "Top-slot details: " .. table.concat(topFailures, " | ") end
        report[#report + 1] = "Actual top-slot headings: " .. JoinNames(topHeaders)
        report[#report + 1] = "Top run/show priorities: " .. JoinNames(topPriorities)

        if higherName == nil or higherPriority <= lowerPriority then
            report[#report + 1] = "OPEN between-category heading order: no visible higher-priority external anchor was available."
            return
        end
        local step = (higherPriority - lowerPriority) / (#names + 1)
        local betweenPriorities = {}
        for index = 1, #names do
            local value = lowerPriority + step * (#names - index + 1)
            if value == math.floor(value) then value = value + step / 4 end
            assert(value > lowerPriority and value < higherPriority,
                "Could not compute a fractional priority inside the existing category gap.")
            if index > 1 then
                assert(value < betweenPriorities[index - 1], "Computed fractional priorities are not strictly ordered.")
            end
            betweenPriorities[index] = value
        end
        ApplyPriorities(betweenPriorities)
        local betweenHeaders, betweenFailures = RenderAndCheck(names)
        local higherIndex = HeaderIndex(betweenHeaders, higherName)
        local firstTestIndex = HeaderIndex(betweenHeaders, names[1])
        local finalTestIndex = HeaderIndex(betweenHeaders, names[#names])
        local lowerIndex = HeaderIndex(betweenHeaders, lowerName)
        if not higherIndex or not firstTestIndex or not finalTestIndex or not lowerIndex then
            betweenFailures[#betweenFailures + 1] = "Native list is missing an external anchor or test heading."
        elseif higherIndex >= firstTestIndex or finalTestIndex >= lowerIndex then
            betweenFailures[#betweenFailures + 1] = "Managed headings did not sort between external anchors."
        end
        report[#report + 1] = (#betweenFailures == 0 and "PASS" or "FAIL")
            .. " fractional classification and visible order: " .. higherName
            .. " > " .. JoinNames(names) .. " > " .. lowerName
        if #betweenFailures > 0 then
            report[#report + 1] = "Between-category details: " .. table.concat(betweenFailures, " | ")
        end
        report[#report + 1] = "Actual between-category headings: " .. JoinNames(betweenHeaders)
        local formatOk, formatted = pcall(string.format, "%04d", 1000 - betweenPriorities[1])
        report[#report + 1] = formatOk
            and "ESO fractional %04d sample: " .. formatted .. "; formatter output alone is not order evidence."
            or "FAIL ESO fractional %04d: " .. tostring(formatted)
        report[#report + 1] = "Between run/show priorities: " .. JoinNames(betweenPriorities)
        report[#report + 1] = "Immediate classification gap: " .. tostring(higherPriority)
            .. " > " .. tostring(lowerPriority) .. "; visible higher anchor priority: "
            .. tostring(visibleHigherPriority) .. "."
    end, INVENTORY_BACKPACK)
    messages[#messages + 1] = "Baseline category with six matching items: " .. lowerName
        .. "; matched items tested: 5; external gap: " .. tostring(higherName or "unavailable")
        .. " (" .. tostring(higherPriority) .. " > " .. tostring(lowerPriority) .. ")."
    ShowDiagnostic("priority/heading order", messages)
end

local function AutoCategoryUnavailable()
    local ac = AutoCategory
    if ac == nil then return "AutoCategory is not loaded. Enable it and reload UI before running this probe." end
    if type(ac) ~= "table" then return "AutoCategory exposes an incompatible namespace; the probe was not run." end
    if not ac.Inited then return "AutoCategory has not finished initialization. Wait before running this probe." end
    if not ac.Enabled then return "AutoCategory is switched off. Turn it on before running this probe." end
end

SLASH_COMMANDS["/icacspike"] = function(arguments)
    local input = arguments:match("^%s*(.-)%s*$")
    local command, rest = input:match("^(%S+)%s*(.-)$")
    command = command or ""
    rest = rest or ""

    if command == "cleanup" then
        if AutoCategory == nil or type(AutoCategory) ~= "table" then
            return ShowDiagnostic("cleanup", {
                "NOT AVAILABLE: AutoCategory saved profiles are not loaded; no cleanup was performed.",
            })
        end
        return RunGateCleanup()
    end

    local unavailable = AutoCategoryUnavailable()
    if unavailable then
        return ShowDiagnostic("AutoCategory availability", { "NOT AVAILABLE: " .. unavailable })
    end

    if command == "profile" then
        local action, search = rest:match("^(%S+)%s*(.-)$")
        if action ~= "baseline" and action ~= "switch" and action ~= "project" and action ~= "check" then
            return ShowDiagnostic("profile command", {
                "Use /icacspike profile baseline, /icacspike profile project <item-name>, or /icacspike profile check <item-name>.",
                "Switch using /icacspike profile switch account or /icacspike profile switch character.",
            })
        end
        return RunGateProfileCommand(action, search or "")
    elseif command == "collision" then
        return RunCollisionProbe()
    elseif command == "context" then
        local contextName, search = rest:match("^(%S+)%s*(.-)$")
        if contextName == nil then
            return ShowDiagnostic("inventory context", {
                "Use /icacspike context <context> <visible-item-name>.",
                "Contexts: backpack, bank, subscriber-bank, guild-bank, house-bank, crafting-station, craft-bag, furniture-vault.",
            })
        end
        return RunContextProbe(contextName, search or "")
    elseif command == "order" then
        return RunOrderProbe(rest)
    elseif command == "render" then
        local search = rest
        if search == "" then search = "plunder skull" end
        if IsInGamepadPreferredMode() then
            return ShowDiagnostic("inline texture rendering", {
                "NOT AVAILABLE: the rendering probe currently supports keyboard inventory only.",
                "No AutoCategory rules, assignments, or items were changed.",
            })
        end
        if ZO_PlayerInventory == nil or ZO_PlayerInventory:IsHidden() then
            return ShowDiagnostic("inline texture rendering", {
                "NOT AVAILABLE: the keyboard Backpack is closed. Open Backpack, then run /icacspike render.",
                "No AutoCategory rules, assignments, or items were changed.",
            })
        end
        local messages = this.RunAutoCategoryNativeProbe(search, true)
        return ShowDiagnostic("inline texture rendering", messages)
    end

    local search = command == "" and rest or input
    if search == "" then search = "plunder skull" end
    local messages = this.RunAutoCategoryNativeProbe(search, false)
    ShowDiagnostic("native classification", messages)
end

SLASH_COMMANDS["/icaccleanup"] = function()
    SLASH_COMMANDS["/icacspike"]("cleanup")
end

function this.Debug()
    SLASH_COMMANDS["/icacspike"]("order plunder skull")
end
