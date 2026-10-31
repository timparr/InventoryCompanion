local this = InventoryCompanion

local function Serialize(value)
    if type(value) == "string" then return string.format("%q", value) end
    if type(value) ~= "table" then
        assert(type(value) == "boolean" or type(value) == "number", "Saved data contains a runtime value")
        return tostring(value)
    end
    local fields = {}
    for key, entry in pairs(value) do
        assert(key ~= "compiledPatterns" and key ~= "compiledExcludedPatterns" and key ~= "isPreloaded",
            "Runtime fields must not be persisted")
        table.insert(fields, "[" .. Serialize(key) .. "]=" .. Serialize(entry))
    end
    table.sort(fields)
    return "{" .. table.concat(fields, ",") .. "}"
end

function this.GetRulePersistenceTests()
    return {
        {
            name = "Production baseline definitions satisfy strict rule contracts",
            run = function()
                assert(loadstring(RuleConstantsSource))()
                this.accountWide = { trackedRules = {} }
                this.character = { trackedRules = {}, useCharacterItemList = false }
                this.ValidateSavedRuleProfiles()
                this.InvalidateRuleCache()
                local runtime = this.GetRuntimeRules()
                local count = 0
                for key in pairs(this.preLoadedRulesets) do
                    assert(runtime[key] and runtime[key].isPreloaded, "Production rule must resolve: " .. key)
                    count = count + 1
                end
                assert(count > 0, "Production baseline must not be empty")
                assert(next(this.accountWide.trackedRules) == nil, "Production defaults must not allocate saved overrides")
            end,
        },
        {
            name = "Serialized rule deltas survive database reinitialization",
            run = function()
                this.accountWide = { trackedRules = {} }
                this.character = { trackedRules = {}, useCharacterItemList = false }
                this.preLoadedRulesets = {
                    default = {
                        displayName = "Default", patterns = { "a", "b", "c" },
                        display = { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false },
                    },
                }
                this.UpdateRulePatterns("default", { "b", "c", "d" })
                this.UpdateRuleProperty("default", "displayName", "Renamed")
                this.UpdateRuleFlag("default", "notify", true)
                this.UpdateRuleFlag("default", "notifyHud", false)
                this.UpdateRuleFlag("default", "showBackpack", false)
                this.UpdateRuleFlag("default", "showBank", true)
                this.CreateCustomRule("custom", "Custom")
                local suffix = this.constants.RULE_PATTERN_EXCLUSION_SUFFIX
                this.UpdateRulePatterns("custom", { "Custom*", "Cyrodiil" .. suffix })
                local previous = this.GetRuntimeRules()
                local saved = Serialize(this.accountWide.trackedRules)
                this.accountWide.trackedRules = assert(loadstring("return " .. saved))()
                assert(loadstring(RuleDatabaseSource))()
                local restored = this.GetRuntimeRules()
                assert(restored ~= previous, "Reload must initialize a new runtime cache")
                assert(table.concat(restored.default.patterns, ",") == "b,c,d", "Reload must preserve effective patterns")
                assert(restored.default.displayName == "Renamed", "Reload must preserve names")
                assert(restored.default.display.notify, "Reload must preserve explicit flags")
                assert(restored.default.display.show, "Reload must inherit untouched baseline flags")
                assert(not restored.default.display.showBackpack and restored.default.display.showBank,
                    "Reload must preserve bank-only display")
                assert(restored.default.display.notifyChat and not restored.default.display.notifyHud,
                    "Reload must preserve chat-only delivery")
                assert(restored.custom.compiledPatterns[1] == "^custom.*$", "Reload must compile custom additions")
                assert(restored.custom.compiledExcludedPatterns[1] == "cyrodiil",
                    "Reload must compile the stored exclusion without its marker")
                assert(restored.custom.patterns[2] == "Cyrodiil" .. suffix,
                    "Reload must preserve the encoded stored string")
                assert(Serialize(this.accountWide.trackedRules) == saved, "Reload must not persist runtime fields")
            end,
        },
        {
            name = "Imported item and rule independent flags preserve explicit false and source isolation",
            run = function()
                this.accountWide = { trackedRules = {}, trackedItems = {} }
                this.character = { trackedRules = {}, trackedItems = {}, useCharacterItemList = false }
                this.preLoadedRulesets = {}
                local source = {
                    trackedItems = { [10] = { link = "item", icon = "icon",
                        display = { show = true, notify = true, showBackpack = false, showBank = true,
                            notifyChat = false, notifyHud = true } } },
                    trackedRules = { custom = { addedPatterns = { "*" },
                        display = { showBackpack = false, showBank = true, notifyChat = false, notifyHud = true } } },
                }
                _G[this.SettingsName] = { Default = { account = { source = source } } }
                assert(this.CopyProfile("source"), "Profile copy should succeed")
                local item = this.ResolveItemDisplay(this.accountWide.trackedItems[10].display)
                local rule = this.GetRuntimeRules().custom.display
                assert(not item.showBackpack and item.showBank and not item.notifyChat and item.notifyHud,
                    "Item import must preserve independent flags")
                assert(not rule.showBackpack and rule.showBank and not rule.notifyChat and rule.notifyHud,
                    "Rule import must preserve independent flags")
                local saved = Serialize(this.accountWide)
                this.accountWide = assert(loadstring("return " .. saved))()
                assert(loadstring(RuleDatabaseSource))()
                item = this.ResolveItemDisplay(this.accountWide.trackedItems[10].display)
                assert(not item.showBackpack and item.showBank and not item.notifyChat and item.notifyHud,
                    "Item serialize/reload must preserve flags")
                this.accountWide.trackedItems[10].display.notifyHud = false
                assert(source.trackedItems[10].display.notifyHud, "Imported item must not alias source")
            end,
        },
        {
            name = "Actual clear-overrides command invalidates only the selected profile",
            run = function()
                this.accountWide = { trackedRules = { custom = { addedPatterns = { "Custom*" } } } }
                this.character = { trackedRules = {}, useCharacterItemList = false }
                this.preLoadedRulesets = {}
                this.character.trackedRules = { character_group = { addedPatterns = { "Character*" } } }
                local refreshes = 0
                this.RefreshTrackedItemsEditor = function() refreshes = refreshes + 1 end
                this.RefreshGroupsEditor = function() refreshes = refreshes + 1 end
                this.RefreshItemTrackerPanel = function() refreshes = refreshes + 1 end
                this.SetUseCharacterItemList(false)
                local accountCache = this.GetRuntimeRules()
                SLASH_COMMANDS["/icclearoverrides"]()
                local cleared = this.GetRuntimeRules()
                assert(cleared ~= accountCache and not cleared.custom, "Clear command must invalidate account rules")
                assert(next(this.accountWide.trackedRules) == nil, "Account overrides must be removed")
                assert(this.character.trackedRules.character_group, "Character data must remain")
                this.SetUseCharacterItemList(true)
                local characterCache = this.GetRuntimeRules()
                assert(characterCache.character_group, "Character custom rule must be resolved")
                SLASH_COMMANDS["/icclearoverrides"]()
                assert(this.GetRuntimeRules() ~= characterCache, "Character clear must invalidate")
                assert(next(this.character.trackedRules) == nil, "Character overrides must be removed")
                assert(refreshes == 6, "Both editors and the tracker must refresh on each clear")
            end,
        },
    }
end
