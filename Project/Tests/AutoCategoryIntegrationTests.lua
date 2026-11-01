local this = InventoryCompanion
local integration = this.AutoCategoryIntegration

local contexts = {
    { key = "backpack", bag = 1 },
    { key = "bank", bag = 2 },
    { key = "guild_bank", bag = 3 },
    { key = "house_bank", bag = 4 },
    { key = "crafting_station", bag = 5 },
    { key = "craft_bag", bag = 6 },
    { key = "furniture_vault", bag = 7 },
}

AC_BAG_TYPE_BACKPACK, AC_BAG_TYPE_BANK, AC_BAG_TYPE_GUILDBANK = 1, 2, 3
AC_BAG_TYPE_HOUSEBANK, AC_BAG_TYPE_CRAFTSTATION, AC_BAG_TYPE_CRAFTBAG = 4, 5, 6
AC_BAG_TYPE_FURNVAULT = 7
INVENTORY_BACKPACK, INVENTORY_BANK, INVENTORY_GUILD_BANK = 11, 12, 13
INVENTORY_HOUSE_BANK, INVENTORY_CRAFT_BAG, INVENTORY_FURNITURE_VAULT = 14, 15, 16
SI_ITEMFILTERTYPE_NEW = 999
function GetString() return "New" end

local function NewFixture(headingLists)
    local function Display()
        return { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false }
    end
    this.preLoadedRulesets = {
        alpha = { displayName = "Alpha", patterns = { "alpha" }, display = Display() },
        beta = { displayName = "Beta", patterns = { "beta" }, display = Display() },
        gamma = { displayName = "Gamma", patterns = { "gamma" }, display = Display() },
        miscellaneous = { displayName = "Miscellaneous", patterns = {}, display = Display() },
    }
    this.accountWide = { trackedRules = {}, trackedItems = {} }
    this.character = { trackedRules = {}, trackedItems = {}, useCharacterItemList = false }
    this.InvalidateRuleCache()
    this.ValidateSavedRuleProfiles()
    AutoCategory = { saved = { bags = {} } }
    local defaults = { "New", "Selling", "Low level" }
    for _, context in ipairs(contexts) do
        local names = headingLists and headingLists[context.key] or defaults
        local assignments = {}
        for index, name in ipairs(names) do
            assignments[#assignments + 1] = {
                name = name,
                runpriority = (#names - index + 1) * 100,
                showpriority = (#names - index + 1) * 100,
                isHidden = false,
            }
        end
        AutoCategory.saved.bags[context.bag] = { rules = assignments }
    end
    integration.OnRuleMutation = function() end
    integration.OnEnablementChanged = function() end
end

local function FindRow(rows, kind, value)
    for _, row in ipairs(rows) do
        if row.kind == kind and (kind == "group" and row.ruleKey == value
            or kind == "heading" and row.name == value) then
            return row
        end
    end
end

function this.GetAutoCategoryIntegrationTests()
    return {
        {
            name = "AutoCategory presets place every ordinary group without enabling participation",
            run = function()
                NewFixture()
                local placements = integration.BuildPresetPlacements("prefer_ic_groups")
                assert(placements.alpha and placements.beta and placements.gamma)
                assert(placements.miscellaneous == nil, "Miscellaneous must not be exported")
                assert(placements.alpha.anchor == "@default-new" and placements.beta.rank == 200)
                this.ApplyAutoCategoryPreset("prefer_ic_groups", false)
                assert(this.GetAutoCategoryState().initialized and not this.GetAutoCategoryState().enabled)
                assert(this.accountWide.trackedRules.alpha.autoCategoryEnabled == nil)
                assert(this.accountWide.trackedRules.gamma.autoCategoryRank == 300)
            end,
        },
        {
            name = "First participation inserts after the last participating group before inactive peers",
            run = function()
                NewFixture()
                this.accountWide.autoCategoryInitialized = true
                this.accountWide.trackedRules = {
                    alpha = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 100 },
                    beta = { autoCategoryAnchor = "@default-new", autoCategoryRank = 200 },
                }
                this.ValidateSavedRuleProfiles()
                assert(this.GetRuntimeRules().gamma ~= nil, "Fixture must include gamma")
                local alpha
                for _, row in ipairs(integration.ResolveAutoCategoryOrder("master", { showNonparticipants = true })) do
                    if row.kind == "group" and row.ruleKey == "alpha" then alpha = row end
                end
                assert(alpha ~= nil, "Fixture must resolve the participating group")
                this.SetAutoCategoryParticipation("gamma", true)
                local gamma = this.accountWide.trackedRules.gamma
                assert(gamma.autoCategoryEnabled == true and gamma.autoCategoryAnchor == alpha.resolvedAnchorId)
                assert(gamma.autoCategoryRank == 101, "The new group must fit between the last active and inactive groups")
                assert(this.accountWide.trackedRules.alpha.autoCategoryRank == 100)
                assert(this.accountWide.trackedRules.beta.autoCategoryRank == 200)
            end,
        },
        {
            name = "First participation persists rank rebalancing and preserves context overrides",
            run = function()
                NewFixture()
                this.accountWide.autoCategoryInitialized = true
                this.accountWide.trackedRules = {
                    alpha = { autoCategoryEnabled = true, autoCategoryAnchor = "New", autoCategoryRank = 1000 },
                    beta = {
                        autoCategoryAnchor = "New", autoCategoryRank = 1001,
                        autoCategoryOverrides = { bank = { rank = 2000 } },
                    },
                }
                this.ValidateSavedRuleProfiles()
                this.SetAutoCategoryParticipation("gamma", true)
                local saved = this.accountWide.trackedRules
                assert(saved.alpha.autoCategoryRank == 100 and saved.beta.autoCategoryRank == 200)
                assert(saved.beta.autoCategoryOverrides.bank.rank == 300)
                assert(saved.gamma.autoCategoryRank == 101)
                assert(saved.beta.autoCategoryOverrides.bank.anchor == nil,
                    "Rank cleanup must preserve sparse context placement fields")
            end,
        },
        {
            name = "Context moves alter only the moved group and leave Master ordering unchanged",
            run = function()
                NewFixture()
                this.accountWide.autoCategoryInitialized = true
                this.accountWide.autoCategoryIntegrationEnabled = true
                this.accountWide.trackedRules = {
                    alpha = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 100 },
                    beta = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 200 },
                    gamma = { autoCategoryEnabled = true, autoCategoryAnchor = "@default-new", autoCategoryRank = 300 },
                }
                this.ValidateSavedRuleProfiles()
                assert(integration.MoveGroup("beta", "bank", -1))
                local master = integration.ResolveAutoCategoryOrder("master")
                local bank = integration.ResolveAutoCategoryOrder("bank")
                local function GroupNames(rows)
                    local names = {}
                    for _, row in ipairs(rows) do
                        if row.kind == "group" and row.participating then names[#names + 1] = row.ruleKey end
                    end
                    return table.concat(names, ",")
                end
                assert(GroupNames(master) == "alpha,beta,gamma")
                assert(GroupNames(bank) == "beta,alpha,gamma")
                assert(this.accountWide.trackedRules.alpha.autoCategoryOverrides == nil)
                assert(this.accountWide.trackedRules.gamma.autoCategoryOverrides == nil)
                assert(this.accountWide.trackedRules.beta.autoCategoryOverrides.bank.rank == 99)
            end,
        },
        {
            name = "Context heading visibility overrides are isolated and reset to Master",
            run = function()
                NewFixture()
                local master = integration.ResolveAutoCategoryOrder("master")
                local newHeading = FindRow(master, "heading", "New")
                assert(newHeading)
                local scopeCount = 0
                for _ in pairs(newHeading.contexts) do scopeCount = scopeCount + 1 end
                assert(scopeCount == 7, "Identical heading order should share one Master occurrence, got "
                    .. tostring(scopeCount))
                this.SetAutoCategoryHeadingVisibility("master", newHeading.occurrenceId, false)
                local afterMasterHide = integration.ResolveAutoCategoryOrder("master")
                local visibleNew = {}
                for _, row in ipairs(afterMasterHide) do
                    if row.kind == "heading" and row.name == "New" then
                        visibleNew[#visibleNew + 1] = row.occurrenceId
                    end
                end
                assert(#visibleNew == 0,
                    "Master heading remained visible for " .. newHeading.occurrenceId .. "; still visible: "
                        .. table.concat(visibleNew, ",") .. "; stored="
                        .. tostring(this.GetAutoCategoryState().order.headingVisibility[newHeading.occurrenceId]))
                this.SetAutoCategoryHeadingVisibility("bank", newHeading.occurrenceId, true)
                assert(FindRow(integration.ResolveAutoCategoryOrder("bank"), "heading", "New"))
                this.ResetAutoCategoryContext("bank")
                assert(FindRow(integration.ResolveAutoCategoryOrder("bank"), "heading", "New") == nil)
                assert(this.accountWide.autoCategoryOrder.overrides == nil)
            end,
        },
        {
            name = "Context views preserve their native heading sequences when orders differ",
            run = function()
                NewFixture({
                    backpack = { "New", "Selling", "Low level" },
                    bank = { "New", "Low level", "Selling" },
                    guild_bank = { "Selling", "New", "Low level" },
                })
                local function HeadingNames(key)
                    local names = {}
                    for _, row in ipairs(integration.ResolveAutoCategoryOrder(key)) do
                        if row.kind == "heading" then names[#names + 1] = row.name end
                    end
                    return table.concat(names, ",")
                end
                assert(HeadingNames("backpack") == "New,Selling,Low level")
                assert(HeadingNames("bank") == "New,Low level,Selling")
                assert(HeadingNames("guild_bank") == "Selling,New,Low level")
                local master = integration.ResolveAutoCategoryOrder("master")
                local newOccurrences = 0
                for _, row in ipairs(master) do
                    if row.kind == "heading" and row.name == "New" then newOccurrences = newOccurrences + 1 end
                end
                assert(newOccurrences >= 2, "Differing native orders require separate heading occurrences")
            end,
        },
    }
end
