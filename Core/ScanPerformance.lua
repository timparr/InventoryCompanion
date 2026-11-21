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

local function RunTrackerPerformanceTest()
    if running then
        d("[InventoryCompanion tracker timing] A tracker timing test is already running.")
        return
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
        error(table.concat(reportLines, "\n"), 0)
    end

    reportLines[#reportLines + 1] = string.format(
        "[InventoryCompanion tracker timing] Starting %d runs of %d iterations: scan, display-list build, and layout-model build. Each timer covers only its function; UI yields between iterations. Rules: %d; bags: %d; bank %s.",
        RUN_COUNT, OPERATIONS_PER_RUN, ruleCount, #bagIds, bankOpen and "open" or "closed")
    d("[InventoryCompanion tracker timing] Started; the complete report will be raised as an error when finished.")

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
                local function GetSortedTimes(times)
                    local sortedTimes = {}
                    for index, milliseconds in ipairs(times) do
                        sortedTimes[index] = milliseconds
                    end
                    table.sort(sortedTimes)
                    return sortedTimes
                end

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

SLASH_COMMANDS["/ictrackperf"] = RunTrackerPerformanceTest
