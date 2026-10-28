local this = InventoryCompanion

local function Serialize(value)
    if type(value) == "string" then return string.format("%q", value) end
    if type(value) ~= "table" then
        assert(type(value) == "boolean" or type(value) == "number", "Saved data contains a runtime value")
        return tostring(value)
    end
    local fields = {}
    for key, entry in pairs(value) do
        assert(key ~= "compiledPatterns" and key ~= "isPreloaded", "Runtime fields must not be persisted")
        table.insert(fields, "[" .. Serialize(key) .. "]=" .. Serialize(entry))
    end
    table.sort(fields)
    return "{" .. table.concat(fields, ",") .. "}"
end

function this.GetRulePersistenceTests()
    return {
        {
            name = "Serialized rule deltas survive database reinitialization",
            run = function()
                this.accountWide = { trackedRules = {} }
                this.character = { trackedRules = {}, useCharacterItemList = false }
                this.preLoadedRulesets = {
                    default = {
                        displayName = "Default", patterns = { "a", "b", "c" },
                        display = { show = true, notify = false, isHidden = false },
                    },
                }
                this.UpdateRulePatterns("default", { "b", "c", "d" })
                this.UpdateRuleProperty("default", "displayName", "Renamed")
                this.UpdateRuleFlag("default", "notify", true)
                this.CreateCustomRule("custom", "Custom")
                this.UpdateRulePatterns("custom", { "Custom*" })
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
                assert(restored.custom.compiledPatterns[1] == "^custom.*$", "Reload must compile custom additions")
                assert(Serialize(this.accountWide.trackedRules) == saved, "Reload must not persist runtime fields")
            end,
        },
        {
            name = "Actual clear-overrides command invalidates only the selected profile",
            run = function()
                this.accountWide = { trackedRules = { custom = { addedPatterns = { "Custom*" } } } }
                this.character = { trackedRules = {}, useCharacterItemList = false }
                this.preLoadedRulesets = {}
                this.character.trackedRules = { character_group = { addedPatterns = { "Character*" } } }
                this.RefreshGroupsEditor, this.RefreshItemTrackerPanel = nil, nil
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
            end,
        },
    }
end
