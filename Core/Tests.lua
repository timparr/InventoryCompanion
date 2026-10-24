InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local function Check(condition, message)
    if not condition then
        error(message, 2)
    end
end

local function CheckEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

local function CountEntries(values)
    local count = 0
    for _ in pairs(values) do
        count = count + 1
    end
    return count
end

local function RunTests(arguments)
    if not this.state or not this.state.isLoaded then
        d("[InventoryCompanion tests] Addon is not fully loaded.")
        return
    end

    local mode = tostring(arguments or ""):lower():match("^%s*(.-)%s*$")
    if mode ~= "" and mode ~= "verbose" and mode ~= "copy" then
        d("[InventoryCompanion tests] Usage: /ictest [verbose|copy]")
        return
    end

    local original = {
        accountWide = this.accountWide,
        character = this.character,
        preLoadedRulesets = this.preLoadedRulesets,
        getBagContents = this.Scanning.GetBagContents,
        getItemLinkName = _G.GetItemLinkName,
    }

    local namesByLink = {
        ["item-exact"] = "Mundane Rune",
        ["item-wildcard"] = "Treasure Map: Glenumbra",
        ["item-special"] = "Wayfinder's Kit +1",
    }

    local syntheticBags = {
        [BAG_BACKPACK] = {},
        [BAG_VIRTUAL] = {},
    }
    for index = 1, 100 do
        local link = "synthetic-item-" .. index
        namesByLink[link] = string.format("Synthetic Item %03d", index)
        local bagId = index <= 50 and BAG_BACKPACK or BAG_VIRTUAL
        table.insert(syntheticBags[bagId], {
            bagId = bagId,
            slotIndex = index,
            itemId = 980000 + index,
            link = link,
            icon = "synthetic-icon",
            count = 1,
            maxCount = 200,
        })
    end

    local results = {}
    local passed = 0
    local performanceMs
    local slotMatchMs
    local performanceLimitMs = 2000
    local slotMatchLimitMs = 1000
    local environmentOk, environmentError = pcall(function()
        this.accountWide = { trackedRules = {} }
        this.character = { useCharacterItemList = false }
        this.preLoadedRulesets = {}
        this.Scanning.GetBagContents = function(bagIds)
            local bag = syntheticBags[bagIds[1]]
            return bag or {}
        end
        _G.GetItemLinkName = function(itemLink)
            return namesByLink[itemLink]
        end

        local baselineRules = {
            default = {
                displayName = "Default Group",
                patterns = { "Default *" },
                display = {
                    show = true,
                    notify = false,
                    bank = false,
                    group = true,
                    isExpanded = true,
                    isHidden = false,
                },
            },
            hidden = {
                displayName = "Hidden Group",
                patterns = { "Hidden *" },
                display = { show = true, isHidden = false },
            },
        }

        local tests = {
            {
                name = "Case-insensitive substring matching",
                run = function()
                    Check(this.ItemMatchesRule("item-exact", "mundane rune"), "Expected case-insensitive exact match")
                    Check(this.ItemMatchesRule("item-exact", "mundane"), "Expected plain text patterns to match substrings")
                end,
            },
            {
                name = "Wildcard matching",
                run = function()
                    Check(this.ItemMatchesRule("item-wildcard", "Treasure Map:*"), "Expected wildcard match")
                    Check(not this.ItemMatchesRule("item-wildcard", "Treasure * Grahtwood"), "Unexpected wildcard match")
                end,
            },
            {
                name = "Literal punctuation and missing names",
                run = function()
                    Check(this.ItemMatchesRule("item-special", "Wayfinder's Kit +1"), "Expected punctuation to be matched literally")
                    Check(not this.ItemMatchesRule("item-special", "Wayfinder's Kit 1"), "Expected plus sign to be significant")
                    Check(not this.ItemMatchesRule("missing-item", "Anything"), "Missing item name should not match")
                end,
            },
            {
                name = "Any-pattern matching",
                run = function()
                    Check(this.ItemMatchesAnyRule("item-wildcard", { "No Match", "Treasure Map:*" }), "Expected one matching pattern")
                    Check(not this.ItemMatchesAnyRule("item-wildcard", { "No Match", "Still No Match" }), "Unexpected any-pattern match")
                    Check(not this.ItemMatchesAnyRule("item-wildcard", nil), "Nil pattern list should not match")
                end,
            },
            {
                name = "Baseline and saved-rule override resolution",
                run = function()
                    this.preLoadedRulesets = baselineRules
                    this.accountWide = {
                        trackedRules = {
                            default = { displayName = "Renamed", display = { show = false } },
                            hidden = { display = { isHidden = true } },
                            custom = { patterns = { "Custom *" } },
                        },
                    }

                    local activeRules = this.GetActiveTrackedRules()
                    CheckEqual(activeRules.default.displayName, "Renamed", "Saved display-name override should apply")
                    CheckEqual(activeRules.default.patterns[1], "Default *", "Unmodified patterns should come from the baseline")
                    CheckEqual(activeRules.default.display.show, false, "Saved display flag should apply")
                    CheckEqual(activeRules.default.display.notify, false, "Unmodified display flag should remain at baseline")
                    Check(activeRules.hidden == nil, "Hidden rule should be filtered by default")
                    CheckEqual(activeRules.custom.displayName, "custom", "Custom rule should use its key as the default name")
                    CheckEqual(activeRules.custom.display.show, true, "Custom rule should receive default display settings")
                    Check(this.GetActiveTrackedRules(true).hidden ~= nil, "includeHidden should retain hidden rules")
                    CheckEqual(baselineRules.default.displayName, "Default Group", "Reading overrides must not mutate the baseline")
                end,
            },
            {
                name = "Display-flag writes preserve other overrides",
                run = function()
                    this.accountWide = {
                        trackedRules = {
                            default = {
                                displayName = "Existing Name",
                                patterns = { "Existing *" },
                                display = { notify = false },
                            },
                        },
                    }

                    this.SetRuleFlag("default", "show", true)
                    local savedRule = this.accountWide.trackedRules.default
                    CheckEqual(savedRule.displayName, "Existing Name", "Flag update should preserve display name")
                    CheckEqual(savedRule.patterns[1], "Existing *", "Flag update should preserve patterns")
                    CheckEqual(savedRule.display.notify, false, "Flag update should preserve other flags")
                    CheckEqual(savedRule.display.show, true, "Flag update should write selected flag")
                    CheckEqual(CountEntries(savedRule), 3, "Flag update should not add unrelated root properties")
                    CheckEqual(CountEntries(savedRule.display), 2, "Flag update should not add unrelated display flags")
                end,
            },
            {
                name = "100-item backpack and craft-bag scan",
                run = function()
                    local rules = {
                        synthetic = { patterns = { "Synthetic Item *" } },
                    }
                    local snapshot = this.GetMasterItemList({}, rules, { BAG_BACKPACK, BAG_VIRTUAL })
                    CheckEqual(CountEntries(snapshot.items), 100, "Every synthetic item should be included")
                    CheckEqual(#snapshot.ruleIndex.synthetic, 100, "Every synthetic item should be indexed under its rule")

                    local bagCount = 0
                    local bankCount = 0
                    for _, item in pairs(snapshot.items) do
                        bagCount = bagCount + item.bagCount
                        bankCount = bankCount + item.bankCount
                    end
                    CheckEqual(bagCount, 50, "Only backpack items should contribute to the backpack count")
                    CheckEqual(bankCount, 100, "The overall total should include backpack and craft-bag items")
                end,
            },
            {
                name = "Repeated 100-item inventory scan performance",
                run = function()
                    local rules = {}
                    for index = 1, 20 do
                        rules["synthetic-" .. index] = { patterns = { "Synthetic Item *" } }
                    end

                    local startedAt = GetGameTimeMilliseconds()
                    for _ = 1, 20 do
                        local snapshot = this.GetMasterItemList({}, rules, { BAG_BACKPACK, BAG_VIRTUAL })
                        CheckEqual(CountEntries(snapshot.items), 100, "Repeated scan should retain all synthetic items")
                    end
                    performanceMs = GetGameTimeMilliseconds() - startedAt
                    Check(
                        performanceMs <= performanceLimitMs,
                        string.format("20 scans of 100 items across 20 rules took %d ms (limit %d ms)", performanceMs, performanceLimitMs)
                    )
                end,
            },
            {
                name = "100 repeated slot-rule matches",
                run = function()
                    local startedAt = GetGameTimeMilliseconds()
                    for index = 1, 100 do
                        Check(
                            this.ItemMatchesAnyRule("synthetic-item-" .. index, { "Synthetic Item *" }),
                            "Synthetic slot update should match its tracked rule"
                        )
                    end
                    slotMatchMs = GetGameTimeMilliseconds() - startedAt
                    Check(
                        slotMatchMs <= slotMatchLimitMs,
                        string.format("100 slot-rule matches took %d ms (limit %d ms)", slotMatchMs, slotMatchLimitMs)
                    )
                end,
            },
        }

        for _, test in ipairs(tests) do
            local ok, err = pcall(test.run)
            if ok then
                passed = passed + 1
                table.insert(results, "PASS " .. test.name)
            else
                table.insert(results, "FAIL " .. test.name .. ": " .. tostring(err))
            end
        end
    end)

    this.accountWide = original.accountWide
    this.character = original.character
    this.preLoadedRulesets = original.preLoadedRulesets
    this.Scanning.GetBagContents = original.getBagContents
    _G.GetItemLinkName = original.getItemLinkName

    if not environmentOk then
        table.insert(results, "FAIL test setup: " .. tostring(environmentError))
    end

    local total = #results
    local summary
    if performanceMs and slotMatchMs then
        summary = string.format(
            "[InventoryCompanion tests] %d/%d passed; 20 x 100-item scans / 20 rules: %d/%d ms; 100 slot-rule matches: %d/%d ms.",
            passed,
            total,
            performanceMs,
            performanceLimitMs,
            slotMatchMs,
            slotMatchLimitMs
        )
    else
        summary = string.format("[InventoryCompanion tests] %d/%d passed.", passed, total)
    end

    local reportLines = { summary }
    for _, result in ipairs(results) do
        table.insert(reportLines, "[InventoryCompanion tests] " .. result)
    end

    local hasFailures = passed < total
    if mode == "copy" or hasFailures then
        error(table.concat(reportLines, "\n"), 0)
    elseif mode == "verbose" then
        for _, reportLine in ipairs(reportLines) do
            d(reportLine)
        end
    else
        d(summary)
        for _, result in ipairs(results) do
            if result:sub(1, 5) == "FAIL " then
                d("[InventoryCompanion tests] " .. result)
            end
        end
    end
end

SLASH_COMMANDS["/ictest"] = RunTests
