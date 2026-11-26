local this = InventoryCompanion

function GetPreparedScanningTests()
    return {
        {
            name = "Prepared and single-slot scans share mixed positive and negative marker matching",
            run = function()
                local items = {
                    { bagId = BAG_BACKPACK, slotIndex = 0, itemId = 101, link = "ordinary writ", count = 1 },
                    { bagId = BAG_BACKPACK, slotIndex = 1, itemId = 102, link = "ordinary helm", count = 1 },
                    { bagId = BAG_BACKPACK, slotIndex = 2, itemId = 103, link = "master writ", count = 1 },
                    { bagId = BAG_BACKPACK, slotIndex = 3, itemId = 104, link = "ordinary writ", count = 1 },
                    { bagId = BAG_BACKPACK, slotIndex = 4, itemId = 105, link = "ordinary helm", count = 1 },
                    { bagId = BAG_VIRTUAL, slotIndex = 0, itemId = 106, link = "ordinary writ", count = 1 },
                }
                local answers = {
                    [0] = { [5] = false, [9] = false, [11] = false, [17] = false },
                    [1] = { [5] = false, [9] = false, [11] = false, [17] = true },
                    [2] = { [5] = false, [9] = true, [11] = false, [17] = false },
                    [3] = { [5] = true, [9] = false, [11] = false, [17] = false },
                    [4] = { [5] = false, [9] = false, [11] = false, [17] = false },
                }
                local reads = 0
                this.Scanning = {
                    GetBagContents = function(bagIds)
                        local found = {}
                        for _, item in ipairs(items) do
                            if item.bagId == bagIds[1] then found[#found + 1] = item end
                        end
                        return found
                    end,
                    ReadSlot = function(bagId, slotIndex)
                        for _, item in ipairs(items) do
                            if item.bagId == bagId and item.slotIndex == slotIndex then return item end
                        end
                    end,
                }
                this.FCOItemSaver = {
                    GetActiveMarkerIds = function() return { 5, 9, 11, 17 }, {} end,
                    ReadMarkers = function(markerIds, bagId, slotIndex)
                        assert(bagId == BAG_BACKPACK)
                        reads = reads + 1
                        local result, any = {}, false
                        for _, id in ipairs(markerIds) do
                            result[id] = answers[slotIndex][id]
                            any = any or result[id]
                        end
                        return any, result
                    end,
                }
                this.DiagnosticLog = { Sample = function() end }
                function GetGameTimeMilliseconds() return 0 end
                function GetItemLinkName(link) return link end
                local rules = {
                    mixed = {
                        compiledPatterns = { "writ" }, compiledExcludedPatterns = { "master" },
                        markerConditions = { include = { 17, 9 }, exclude = { 5, 11 } },
                    },
                    shared = {
                        compiledPatterns = {}, compiledExcludedPatterns = {},
                        markerConditions = { include = { 17 }, exclude = {} },
                    },
                }
                local _, index = this.PreparedScanning.GetPreparedMasterItemList(
                    {}, rules, { BAG_BACKPACK, BAG_VIRTUAL })
                assert(reads == 5, "Prepared scanning must batch marker reads once per supported slot")
                local expectedMixed = { true, true, false, false, false }
                for slot = 0, 4 do
                    local record = index.bags[BAG_BACKPACK].slots[slot]
                    assert((record.matchedRules.mixed == true) == expectedMixed[slot + 1])
                    assert((record.matchedRules.shared == true) == (slot == 1))
                    local incremental = this.EvaluateTrackerSlot(BAG_BACKPACK, slot, rules)
                    assert((incremental.matchedRules.mixed == true) == expectedMixed[slot + 1])
                    assert((incremental.matchedRules.shared == true) == (slot == 1))
                    assert(this.ItemMatchesRuntimeRule(items[slot + 1].link, rules.mixed, BAG_BACKPACK, slot)
                        == expectedMixed[slot + 1])
                end
                assert(index.bags[BAG_VIRTUAL].slots[0].matchedRules.mixed,
                    "Name matches must still work in unsupported marker bags, including with marker exclusions")
                assert(not index.bags[BAG_VIRTUAL].slots[0].matchedRules.shared)
                assert(this.EvaluateTrackerSlot(BAG_VIRTUAL, 0, rules).matchedRules.mixed
                    and this.ItemMatchesRuntimeRule("ordinary writ", rules.mixed, BAG_VIRTUAL, 0),
                    "Prepared, incremental and direct matching must preserve unsupported-bag name coverage")
            end,
        },
        {
            name = "Prepared scan keeps empty marker keys for Craft Bag while checking backpack answers",
            run = function()
                local markerReads = 0
                this.Scanning = {
                    GetBagContents = function(bagIds)
                        if bagIds[1] == BAG_BACKPACK then
                            return { {
                                bagId = BAG_BACKPACK, slotIndex = 0, itemId = 101,
                                link = "Marked item", count = 2,
                            } }
                        end
                        assert(bagIds[1] == BAG_VIRTUAL)
                        return { {
                            bagId = BAG_VIRTUAL, slotIndex = 7, itemId = 202,
                            link = "Craft Bag item", count = 3,
                        } }
                    end,
                }
                this.FCOItemSaver = {
                    GetActiveMarkerIds = function()
                        return { 5 }, { [5] = "__ic_fco_deconstruct" }
                    end,
                    ReadMarkers = function(markerIds, bagId, slotIndex)
                        markerReads = markerReads + 1
                        assert(bagId == BAG_BACKPACK and slotIndex == 0 and markerIds[1] == 5)
                        return true, { [5] = true }
                    end,
                }
                this.DiagnosticLog = { Sample = function() end }
                function GetGameTimeMilliseconds() return 0 end
                function GetItemLinkName(link) return link end
                local rule = {
                    compiledPatterns = {}, compiledExcludedPatterns = {},
                    markerId = 5, markerKey = "__ic_fco_deconstruct",
                    slotMatcher = function() return true end,
                }
                local snapshot, slotIndex = this.PreparedScanning.GetPreparedMasterItemList(
                    {}, { __ic_fco_deconstruct = rule }, { BAG_BACKPACK, BAG_VIRTUAL })
                assert(markerReads == 1, "Only the supported backpack slot may call the marker API")
                assert(slotIndex.bags[BAG_BACKPACK].slots[0].markerKey == "5",
                    "Supported slots must retain the validated marker answer")
                assert(slotIndex.bags[BAG_VIRTUAL].slots[7].markerKey == "",
                    "Unsupported Craft Bag slots must have an empty marker key")
                assert(snapshot.items[101].bagCount == 2
                    and slotIndex.bags[BAG_VIRTUAL].slots[7].itemData.count == 3)
                this.FCOItemSaver.ReadMarkers = function() return false, {} end
                local ok, failure = pcall(this.PreparedScanning.GetPreparedMasterItemList,
                    {}, { __ic_fco_deconstruct = rule }, { BAG_BACKPACK, BAG_VIRTUAL })
                assert(not ok and tostring(failure):find("FCO marker answer must be boolean", 1, true),
                    "Missing answers for supported occupied slots must still fail")
            end,
        },
    }
end
