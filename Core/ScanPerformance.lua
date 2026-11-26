local this = InventoryCompanion

local RUN_COUNT = 3
local OPERATIONS_PER_RUN = 1000
local running = false

local function BuildBagIdList()
    local bagIds = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
    if IsESOPlusSubscriber() then
        bagIds[#bagIds + 1] = BAG_VIRTUAL
    end
    return bagIds
end

local function CountEntries(items)
    local count = 0
    for _ in pairs(items) do count = count + 1 end
    return count
end

local function CountList(items)
    local count = 0
    for _ in ipairs(items) do count = count + 1 end
    return count
end

local function GetSortedTimes(times)
    local sortedTimes = {}
    for index, milliseconds in ipairs(times) do
        sortedTimes[index] = milliseconds
    end
    table.sort(sortedTimes)
    return sortedTimes
end

local function RunTrackerPerformanceTest(onComplete)
    if running then
        local report = "[InventoryCompanion tracker timing] A tracker timing test is already running."
        if onComplete then return onComplete(report) end
        error(report, 0)
    end

    running = true
    local trackedItems = this.GetActiveTrackedItems()
    local bagIds = BuildBagIdList()
    local bankOpen = IsBankOpen()
    local ruleCount = CountEntries(this.GetActiveTrackedRules())
    local scanTimes, displayListTimes, layoutTimes = {}, {}, {}
    local reportLines = {}
    local runIndex, operationIndex = 1, 0
    local runScanMilliseconds, runDisplayListMilliseconds, runLayoutMilliseconds = 0, 0, 0
    local lastSnapshotIdCount, lastDisplayRowCount, lastLayoutRowCount, lastLayoutGroupCount

    local function FinishReport(line)
        if line then reportLines[#reportLines + 1] = line end
        running = false
        local report = table.concat(reportLines, "\n")
        if onComplete then return onComplete(report) end
        error(report, 0)
    end

    reportLines[#reportLines + 1] = string.format(
        "[InventoryCompanion tracker timing] Starting %d runs of %d iterations: scan, display-list build, and layout-model build. Each timer covers only its function; UI yields between iterations. Rules: %d; bags: %d; bank %s.",
        RUN_COUNT, OPERATIONS_PER_RUN, ruleCount, #bagIds, bankOpen and "open" or "closed")
    if onComplete then
        d("[InventoryCompanion tracker timing] Started; the complete report will be recorded in diagnostic SavedVariables when finished.")
    else
        d("[InventoryCompanion tracker timing] Started; the complete report will be raised as an error when finished.")
    end

    local function RunNextOperation()
        if IsBankOpen() ~= bankOpen then
            return FinishReport("[InventoryCompanion tracker timing] Aborted: bank state changed during the test.")
        end

        local activeRules = this.GetActiveTrackedRules()
        local scanOk, snapshot, elapsed = pcall(function()
            local startedAt = GetGameTimeMilliseconds()
            local result = this.GetMasterItemList(trackedItems, activeRules, bagIds)
            return result, GetGameTimeMilliseconds() - startedAt
        end)
        if not scanOk then
            return FinishReport("[InventoryCompanion tracker timing] Scan failed: " .. tostring(snapshot))
        end
        runScanMilliseconds = runScanMilliseconds + elapsed
        if not snapshot or not snapshot.items then
            return FinishReport("[InventoryCompanion tracker timing] Scan failed: GetMasterItemList returned an invalid snapshot.")
        end
        lastSnapshotIdCount = CountEntries(snapshot.items)

        local showEmpty = this.GetPanelSettings("Tracker").showEmptyTrackedItems ~= false
        local displayOk, displayList, displayElapsed = pcall(function()
            local startedAt = GetGameTimeMilliseconds()
            local result = this.BuildTrackerDisplayListForPerformanceTest(
                snapshot, activeRules, trackedItems, showEmpty)
            return result, GetGameTimeMilliseconds() - startedAt
        end)
        if not displayOk then
            return FinishReport("[InventoryCompanion tracker timing] Display-list build failed: " .. tostring(displayList))
        end
        runDisplayListMilliseconds = runDisplayListMilliseconds + displayElapsed
        if type(displayList) ~= "table" then
            return FinishReport("[InventoryCompanion tracker timing] Display-list build failed: builder returned an invalid list.")
        end
        lastDisplayRowCount = CountList(displayList)

        local layoutOk, layoutModel, layoutElapsed = pcall(function()
            local startedAt = GetGameTimeMilliseconds()
            local result = this.BuildTrackerLayoutModelForPerformanceTest(displayList, activeRules)
            return result, GetGameTimeMilliseconds() - startedAt
        end)
        if not layoutOk then
            return FinishReport("[InventoryCompanion tracker timing] Layout-model build failed: " .. tostring(layoutModel))
        end
        runLayoutMilliseconds = runLayoutMilliseconds + layoutElapsed
        if type(layoutModel) ~= "table" then
            return FinishReport("[InventoryCompanion tracker timing] Layout-model build failed: builder returned an invalid model.")
        end
        lastLayoutRowCount = layoutModel.baseRows
        lastLayoutGroupCount = #layoutModel.order

        operationIndex = operationIndex + 1
        if operationIndex == OPERATIONS_PER_RUN then
            scanTimes[runIndex] = runScanMilliseconds / OPERATIONS_PER_RUN
            displayListTimes[runIndex] = runDisplayListMilliseconds / OPERATIONS_PER_RUN
            layoutTimes[runIndex] = runLayoutMilliseconds / OPERATIONS_PER_RUN
            reportLines[#reportLines + 1] = string.format(
                "[InventoryCompanion tracker timing] Run %d/%d (%d iterations): scans %d ms total (%.3f ms/scan); display-list builds %d ms total (%.3f ms/build); layout-model builds %d ms total (%.3f ms/build); last output %d IDs, %d display rows, %d layout rows/%d groups.",
                runIndex, RUN_COUNT, OPERATIONS_PER_RUN,
                runScanMilliseconds, scanTimes[runIndex],
                runDisplayListMilliseconds, displayListTimes[runIndex],
                runLayoutMilliseconds, layoutTimes[runIndex], lastSnapshotIdCount,
                lastDisplayRowCount, lastLayoutRowCount, lastLayoutGroupCount)

            if runIndex == RUN_COUNT then
                local sortedScanTimes = GetSortedTimes(scanTimes)
                local sortedDisplayListTimes = GetSortedTimes(displayListTimes)
                local sortedLayoutTimes = GetSortedTimes(layoutTimes)
                return FinishReport(string.format(
                    "[InventoryCompanion tracker timing] Complete: %d iterations total; scan min/median/max %.3f/%.3f/%.3f ms; display-list %.3f/%.3f/%.3f ms; layout-model %.3f/%.3f/%.3f ms.",
                    RUN_COUNT * OPERATIONS_PER_RUN,
                    sortedScanTimes[1], sortedScanTimes[2], sortedScanTimes[3],
                    sortedDisplayListTimes[1], sortedDisplayListTimes[2], sortedDisplayListTimes[3],
                    sortedLayoutTimes[1], sortedLayoutTimes[2], sortedLayoutTimes[3]))
            end

            runIndex = runIndex + 1
            operationIndex = 0
            runScanMilliseconds, runDisplayListMilliseconds, runLayoutMilliseconds = 0, 0, 0
        end

        zo_callLater(RunNextOperation, 0)
    end

    zo_callLater(RunNextOperation, 0)
end

local function RunTrackerBookkeepingComparisonTest(onComplete)
    if running then
        local report = "[InventoryCompanion tracker timing] A tracker timing test is already running."
        if onComplete then return onComplete(report) end
        error(report, 0)
    end

    running = true
    local trackedItems = this.GetActiveTrackedItems()
    local bagIds = BuildBagIdList()
    local bankOpen = IsBankOpen()
    local ruleCount = CountEntries(this.GetActiveTrackedRules())
    local withBookkeepingTimes, withoutBookkeepingTimes, pairedDifferences = {}, {}, {}
    local reportLines = {}
    local runIndex, pairIndex, variantIndex = 1, 0, 1
    local runWithBookkeepingMilliseconds, runWithoutBookkeepingMilliseconds = 0, 0
    local lastSnapshotIdCount

    local function FinishReport(line)
        if line then reportLines[#reportLines + 1] = line end
        running = false
        local report = table.concat(reportLines, "\n")
        if onComplete then return onComplete(report) end
        error(report, 0)
    end

    reportLines[#reportLines + 1] = string.format(
        "[InventoryCompanion tracker timing] Starting %d runs of %d matched scan pairs: group-count bookkeeping on versus off; the off path retains shared item/index data and uses legacy list-based index deduplication. Variant order alternates; each timer covers only GetMasterItemList. Rules: %d; bags: %d; bank %s.",
        RUN_COUNT, OPERATIONS_PER_RUN, ruleCount, #bagIds, bankOpen and "open" or "closed")
    d("[InventoryCompanion tracker timing] Started; the complete comparison will be raised as an error when finished.")

    local function RunNextScan()
        if IsBankOpen() ~= bankOpen then
            return FinishReport("[InventoryCompanion tracker timing] Aborted: bank state changed during the test.")
        end

        local withFirst = (runIndex + pairIndex) % 2 == 0
        local withBookkeeping = (variantIndex == 1 and withFirst)
            or (variantIndex == 2 and not withFirst)
        local activeRules = this.GetActiveTrackedRules()
        local scanOk, snapshot, elapsed = pcall(function()
            local startedAt = GetGameTimeMilliseconds()
            local result
            if withBookkeeping then
                result = this.GetMasterItemList(trackedItems, activeRules, bagIds)
            else
                result = this.GetMasterItemListWithoutGroupBookkeepingForPerformanceTest(
                    trackedItems, activeRules, bagIds)
            end
            return result, GetGameTimeMilliseconds() - startedAt
        end)
        if not scanOk then
            return FinishReport("[InventoryCompanion tracker timing] Scan failed: " .. tostring(snapshot))
        end
        if not snapshot or type(snapshot.items) ~= "table" then
            return FinishReport("[InventoryCompanion tracker timing] Scan failed: GetMasterItemList returned an invalid snapshot.")
        end
        if withBookkeeping and type(snapshot.groups) ~= "table" then
            return FinishReport("[InventoryCompanion tracker timing] Scan failed: bookkeeping-enabled scan returned no groups.")
        end
        if not withBookkeeping and snapshot.groups ~= nil then
            return FinishReport("[InventoryCompanion tracker timing] Scan failed: bookkeeping-disabled scan returned groups.")
        end

        lastSnapshotIdCount = CountEntries(snapshot.items)
        if withBookkeeping then
            runWithBookkeepingMilliseconds = runWithBookkeepingMilliseconds + elapsed
        else
            runWithoutBookkeepingMilliseconds = runWithoutBookkeepingMilliseconds + elapsed
        end

        if variantIndex == 1 then
            variantIndex = 2
        else
            variantIndex = 1
            pairIndex = pairIndex + 1
            if pairIndex == OPERATIONS_PER_RUN then
                withBookkeepingTimes[runIndex] =
                    runWithBookkeepingMilliseconds / OPERATIONS_PER_RUN
                withoutBookkeepingTimes[runIndex] =
                    runWithoutBookkeepingMilliseconds / OPERATIONS_PER_RUN
                pairedDifferences[runIndex] =
                    withBookkeepingTimes[runIndex] - withoutBookkeepingTimes[runIndex]
                reportLines[#reportLines + 1] = string.format(
                    "[InventoryCompanion tracker timing] Run %d/%d (%d scans per mode): with bookkeeping %d ms total (%.3f ms/scan); without bookkeeping %d ms total (%.3f ms/scan); difference %.3f ms/scan; last output %d IDs.",
                    runIndex, RUN_COUNT, OPERATIONS_PER_RUN,
                    runWithBookkeepingMilliseconds, withBookkeepingTimes[runIndex],
                    runWithoutBookkeepingMilliseconds, withoutBookkeepingTimes[runIndex],
                    pairedDifferences[runIndex],
                    lastSnapshotIdCount)

                if runIndex == RUN_COUNT then
                    local sortedWithBookkeepingTimes = GetSortedTimes(withBookkeepingTimes)
                    local sortedWithoutBookkeepingTimes = GetSortedTimes(withoutBookkeepingTimes)
                    local sortedPairedDifferences = GetSortedTimes(pairedDifferences)
                    return FinishReport(string.format(
                        "[InventoryCompanion tracker timing] Complete: %d scans per mode; with bookkeeping min/median/max %.3f/%.3f/%.3f ms/scan; without bookkeeping %.3f/%.3f/%.3f ms/scan; median paired difference %.3f ms/scan.",
                        RUN_COUNT * OPERATIONS_PER_RUN,
                        sortedWithBookkeepingTimes[1], sortedWithBookkeepingTimes[2],
                        sortedWithBookkeepingTimes[3],
                        sortedWithoutBookkeepingTimes[1], sortedWithoutBookkeepingTimes[2],
                        sortedWithoutBookkeepingTimes[3],
                        sortedPairedDifferences[2]))
                end

                runIndex = runIndex + 1
                pairIndex = 0
                runWithBookkeepingMilliseconds, runWithoutBookkeepingMilliseconds = 0, 0
            end
        end

        zo_callLater(RunNextScan, 0)
    end

    zo_callLater(RunNextScan, 0)
end

this.RunTrackerPerformanceTest = RunTrackerPerformanceTest
this.RunTrackerBookkeepingComparisonTest = RunTrackerBookkeepingComparisonTest
SLASH_COMMANDS["/ictrackperf"] = function() RunTrackerPerformanceTest() end
SLASH_COMMANDS["/ictrackperfcompare"] = function() RunTrackerBookkeepingComparisonTest() end
