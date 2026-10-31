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

SLASH_COMMANDS["/icacspike"] = function(arguments)
    local ac = AutoCategory
    local unavailable
    if ac == nil then
        unavailable = "AutoCategory is not loaded. Enable it and reload UI before running this probe."
    elseif type(ac) ~= "table" then
        unavailable = "AutoCategory exposes an incompatible namespace; the probe was not run."
    elseif not ac.Inited then
        unavailable = "AutoCategory has not finished initialization. Wait before running this probe."
    elseif not ac.Enabled then
        unavailable = "AutoCategory is switched off. Turn it on before running this probe."
    end
    if unavailable then
        d("[InventoryCompanion AutoCategory spike] " .. unavailable)
        return
    end
    local search = arguments:match("^%s*(.-)%s*$")
    local render = search == "render" or search:match("^render%s+") ~= nil
    if render then search = search:gsub("^render%s*", "") end
    if search == "" then search = "plunder skull" end
    local messages = this.RunAutoCategoryNativeProbe(search, render)
    error("[InventoryCompanion AutoCategory spike] DIAGNOSTIC REPORT - intentional copyable output, not a test failure\n"
        .. table.concat(messages, "\n"), 0)
end

function this.Debug()
    SLASH_COMMANDS["/icacspike"]("render")
end
