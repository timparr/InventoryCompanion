local function LoadLog(saved, enabled, source)
    local messages = {}
    local addon = { Name = "InventoryCompanion_DEV", Version = "test",
        accountWide = { diagnosticLoggingEnabled = enabled == true } }
    local clock = 100
    local environment = setmetatable({
        InventoryCompanion = addon, InventoryCompanion_Diagnostics = saved,
        GetTimeStamp = function() clock = clock + 1; return clock end,
        GetGameTimeMilliseconds = function() return clock * 10 end,
        GetAPIVersion = function() return 101049 end,
        IsESOPlusSubscriber = function() return true end,
        GetUnitName = function() return "Test character" end,
        GetCurrentCharacterId = function() return "123" end,
        d = function(message) messages[#messages + 1] = message end,
    }, { __index = _G })
    local chunk = assert(loadstring(source or DiagnosticLogSource))
    setfenv(chunk, environment)()
    return addon.DiagnosticLog, environment, messages, addon
end

local function AssertFails(callback, expected)
    local ok, failure = pcall(callback)
    assert(not ok and tostring(failure):find(expected, 1, true),
        "Expected failure containing " .. expected .. ", got " .. tostring(failure))
end

local function Event()
    return { timestamp = 1, gameTimeMs = 2, kind = "test", message = "kept" }
end

local function Sample()
    return { timestamp = 1, elapsedMs = 2 }
end

local function LoadFinalizer(addon, messages)
    local first = assert(TestReportSource:find("local function FinishTestReport(", 1, true))
    local last = assert(TestReportSource:find("local function RunTests(", first, true))
    local environment = setmetatable({
        InventoryCompanion = addon,
        d = function(message) messages[#messages + 1] = message end,
    }, { __index = _G })
    local chunk = assert(loadstring("local this = InventoryCompanion\n"
        .. TestReportSource:sub(first, last - 1) .. "\nreturn FinishTestReport"))
    setfenv(chunk, environment)
    return chunk()
end

function GetDiagnosticLogTests()
    return {
        { name = "Explicit error events persist complete chunked details with logging off", run = function()
            local log, environment, _, addon = LoadLog(nil, false)
            log.Initialize()
            log.Start()
            local input = { string.rep("x", 1899) .. string.rep("\195\169", 2000), "" }
            for index = 1, 110 do input[#input + 1] = "trace " .. index end
            assert(log.Event("acFailure", "Requested error", input, true))
            assert(not log.Event("background", "Still disabled"))
            local saved = environment.InventoryCompanion_Diagnostics
            assert(#saved.events == 1 and addon.accountWide.diagnosticLoggingEnabled == false
                and #saved.testReports == 0)
            local details = saved.events[1].details
            assert(table.concat(details, "") == table.concat(input, "")
                and details[#details - 110] == "" and details[#details] == "trace 110")
            for _, line in ipairs(details) do
                assert(#line <= 1900, "Explicit error strings must survive ESO serialization")
            end
            input[1] = "changed"
            local reload = LoadLog(saved, false)
            reload.Initialize()
            assert(reload.IsAvailable() and reload.GetStore().events[1].details[1] ~= "changed")
        end },
        { name = "Explicit error events report unavailable saved diagnostics without modifying them", run = function()
            local saved = { schemaVersion = 999 }
            local log, environment = LoadLog(saved, false)
            log.Initialize()
            log.Start()
            local recorded, reason = log.Event("acFailure", "Requested error", { "trace" }, true)
            assert(recorded == nil and reason:find("Unsupported diagnostic schema", 1, true)
                and environment.InventoryCompanion_Diagnostics == saved and saved.events == nil)
        end },
        { name = "Manifest loads existing settings and persists both saved globals using ESO tokenization", run = function()
            local declaration = assert(DiagnosticManifestSource:match("## SavedVariables: ([^\r\n]+)"))
            local settings = { version = 11, preserved = true }
            local disk = { InventoryCompanion_SavedVariables_dev = settings }
            local loaded = {}
            for name in declaration:gmatch("%S+") do loaded[name] = disk[name] end
            assert(loaded.InventoryCompanion_SavedVariables_dev == settings
                and loaded.InventoryCompanion_SavedVariables == nil,
                "ESO must load the existing settings global, not construct fresh defaults")
            local log, environment = LoadLog(loaded.InventoryCompanion_Diagnostics, false)
            environment.InventoryCompanion_SavedVariables_dev = loaded.InventoryCompanion_SavedVariables_dev
            log.Initialize()
            log.Start()
            log.RecordTestReport({ "report" })
            local written = {}
            for name in declaration:gmatch("%S+") do written[name] = environment[name] end
            assert(written.InventoryCompanion_SavedVariables_dev == settings
                and written.InventoryCompanion_SavedVariables == nil
                and written.InventoryCompanion_Diagnostics.testReports[1].lines[1] == "report",
                "Both settings and diagnostic data must remain owned by this installation's save file")
        end },
        { name = "Oversized test report lines survive ESO serialization without losing text or UTF-8 boundaries", run = function()
            local function Serialize(value)
                if type(value) == "string" and #value > 2000 then return nil end
                if type(value) ~= "table" then return value end
                local copy = {}
                for key, entry in pairs(value) do copy[key] = Serialize(entry) end
                return copy
            end
            local log, environment = LoadLog(nil, false)
            log.Initialize()
            log.Start()
            for _, text in ipairs({
                string.rep("x", 2000), string.rep("x", 2001), string.rep("x", 10000),
                string.rep('"\n\\', 1000), string.rep("\226\130\172", 900),
                string.rep("\240\159\152\128", 600),
            }) do
                local longLine = "FAIL example: " .. text
                local input = { "header", longLine, "", "footer" }
                local report = log.RecordTestReport(input)
                local saved = Serialize(environment.InventoryCompanion_Diagnostics)
                local reload = LoadLog(saved, false)
                reload.Initialize()
                assert(reload.IsAvailable(), "ESO serialization must not leave holes in report history")
                local restored = saved.testReports[#saved.testReports].lines
                assert(restored[1] == "header" and restored[#restored - 1] == ""
                    and restored[#restored] == "footer")
                assert(table.concat(restored, "", 2, #restored - 2) == longLine,
                    "Chunking must retain every byte of the original failure detail")
                assert(input[2] == longLine and #input == 4, "Caller-owned report lines must not change")
                for _, line in ipairs(report.lines) do
                    assert(#line <= 1900, "Report chunks must stay below ESO's 2000-byte string limit")
                    local first = line:byte(1)
                    assert(first == nil or first < 128 or first >= 192,
                        "A stored chunk must not start in the middle of a UTF-8 character")
                end
            end
        end },
        { name = "Diagnostic formats 1 and 2 migrate atomically and retain unrelated evidence", run = function()
            for version = 1, 2 do
                local original = { schemaVersion = version, runs = { { label = "benchmark" } },
                    nextRunId = 2, unrelated = { keep = true } }
                if version == 1 then
                    original.playEvents, original.scanSamples = { Event() }, { Sample() }
                else
                    original.events, original.samples = { Event() }, { trackerScan = { Sample() } }
                end
                local log, environment = LoadLog(original)
                log.Initialize()
                local migrated = environment.InventoryCompanion_Diagnostics
                assert(migrated.schemaVersion == 3 and migrated.events[1].message == "kept")
                assert(migrated.samples.trackerScan[1].elapsedMs == 2)
                assert(migrated.runs[1].label == "benchmark" and migrated.unrelated.keep)
                assert(migrated.nextRunId == 2 and #migrated.testReports == 0)
                assert(original.schemaVersion == version, "Migration must stage without mutating its source")
                local reload, reloaded = LoadLog(migrated)
                reload.Initialize()
                assert(reload.IsAvailable() and reloaded.InventoryCompanion_Diagnostics.schemaVersion == 3)
            end
        end },
        { name = "Malformed diagnostics remain untouched and report recording fails explicitly", run = function()
            local badStores = {
                { schemaVersion = 2, events = { [2] = Event() }, samples = {} },
                { schemaVersion = 3, events = {}, samples = {}, testReports = {
                    { sequence = 2, timestamp = 1, lines = { "kept" } },
                    { sequence = 1, timestamp = 1, lines = { "out of order" } },
                }, nextTestReportSequence = 3 },
                { schemaVersion = 3, events = {}, samples = {}, testReports = {}, nextTestReportSequence = 0 },
                { schemaVersion = 4, untouched = true },
            }
            for _, original in ipairs(badStores) do
                local log, environment, messages = LoadLog(original)
                log.Initialize()
                assert(not log.IsAvailable() and environment.InventoryCompanion_Diagnostics == original)
                log.Start()
                local report, reason = log.RecordTestReport({ "FAIL fixture" })
                assert(report == nil and type(reason) == "string" and #messages == 1)
                assert(messages[1]:find("unchanged", 1, true))
            end
        end },
        { name = "Preserved diagnostic format-1 and format-2 readers refuse report-bearing format unchanged", run = function()
            local current, currentEnvironment = LoadLog(nil)
            current.Initialize()
            current.Start()
            current.RecordTestReport({ "complete report" })
            local saved = currentEnvironment.InventoryCompanion_Diagnostics
            local older, olderEnvironment, messages = LoadLog(saved, true, HistoricalDiagnosticSchema2Source)
            older.Initialize()
            assert(not older.IsAvailable() and olderEnvironment.InventoryCompanion_Diagnostics == saved)
            assert(saved.schemaVersion == 3 and saved.testReports[1].lines[1] == "complete report")
            assert(#messages == 1 and messages[1]:find("unchanged", 1, true))
            local first = assert(HistoricalDiagnosticSchema1Source:find(
                "local function ValidateDiagnosticStore(", 1, true))
            local last = assert(HistoricalDiagnosticSchema1Source:find(
                "function this.InitializeFCOItemSaverDiagnostics(", first, true))
            local oldest = assert(loadstring(HistoricalDiagnosticSchema1Source:sub(first, last - 1)
                .. "\nreturn ValidateDiagnosticStore"))()
            AssertFails(function() oldest(saved) end, "Unsupported diagnostic schema")
            assert(saved.schemaVersion == 3 and saved.testReports[1].lines[1] == "complete report")
        end },
        { name = "Early diagnostic failures follow the session marker only when enabled", run = function()
            for _, enabled in ipairs({ false, true }) do
                local log, environment = LoadLog(nil, enabled)
                log.Initialize()
                log.Event("earlyFailure", "preflight problem")
                log.Start()
                local events = environment.InventoryCompanion_Diagnostics.events
                if enabled then
                    assert(#events == 2 and events[1].kind == "session" and events[2].kind == "earlyFailure")
                else
                    assert(#events == 0)
                end
            end
        end },
        { name = "Background logging stays bounded and does not evict complete test reports", run = function()
            local log, environment = LoadLog(nil, true)
            log.Initialize()
            log.Start()
            local lines = {}
            for index = 1, 125 do lines[index] = "line " .. index end
            log.RecordTestReport(lines)
            log.Event("details", "bounded details", lines)
            local details = environment.InventoryCompanion_Diagnostics.events[2].details
            assert(#details == 100 and details[100]:find("omitted", 1, true))
            for index = 1, 2010 do
                log.Event("tick", tostring(index))
                log.Sample("timing", { value = index })
            end
            local saved = environment.InventoryCompanion_Diagnostics
            assert(#saved.events == 1000 and saved.events[1].message == "1011")
            assert(#saved.samples.timing == 2000 and saved.samples.timing[1].value == 11)
            assert(#saved.testReports[1].lines == 125 and saved.testReports[1].lines[125] == "line 125")
        end },
        { name = "Test reports save with logging off and retain exactly the latest ten completions", run = function()
            local log, environment, _, addon = LoadLog(nil, false)
            log.Initialize()
            log.Start()
            local completeSecond = function() return log.RecordTestReport({ "second invocation finished first" }) end
            local completeFirst = function() return log.RecordTestReport({ "first invocation finished second" }) end
            local second, first = completeSecond(), completeFirst()
            assert(second.sequence == 1 and first.sequence == 2 and first.timestamp > second.timestamp)
            for index = 3, 11 do log.RecordTestReport({ "completion " .. index }) end
            local saved = environment.InventoryCompanion_Diagnostics
            assert(#saved.testReports == 10 and saved.testReports[1].sequence == 2)
            assert(saved.testReports[10].sequence == 11 and saved.nextTestReportSequence == 12)
            assert(not addon.accountWide.diagnosticLoggingEnabled and #saved.events == 0)
            local reload, reloaded = LoadLog(saved, false)
            reload.Initialize()
            reload.Start()
            assert(reloaded.InventoryCompanion_Diagnostics.testReports[1].lines[1]
                == "first invocation finished second")
            local nextReport = reload.RecordTestReport({ "after reload" })
            assert(nextReport.sequence == 12 and #reloaded.InventoryCompanion_Diagnostics.testReports == 10)
        end },
        { name = "Report ownership and Clear preserve unrelated diagnostic data", run = function()
            local log, environment = LoadLog(nil, false)
            log.Initialize()
            log.Start()
            local input = { "original" }
            log.RecordTestReport(input)
            input[1] = "changed"
            local saved = environment.InventoryCompanion_Diagnostics
            assert(saved.testReports[1].lines[1] == "original")
            saved.runs, saved.nextRunId = { "benchmark" }, 2
            log.Clear()
            assert(#saved.testReports == 0 and #saved.events == 0 and next(saved.samples) == nil)
            assert(saved.runs[1] == "benchmark" and saved.nextRunId == 2)
            assert(log.RecordTestReport({ "next" }).sequence == 2)
        end },
        { name = "Logging revisions expose off-on transitions without coupling to AC", run = function()
            local log = LoadLog(nil, true)
            log.Initialize()
            log.Start()
            local first = log.GetEnableRevision()
            log.SetEnabled(false)
            log.SetEnabled(true)
            assert(log.GetEnableRevision() == first + 2)
            log.SetEnabled(true)
            assert(log.GetEnableRevision() == first + 2)
        end },
        { name = "Malformed report inputs fail at the API boundary without partial history writes", run = function()
            local log, environment = LoadLog(nil)
            log.Initialize()
            log.Start()
            AssertFails(function() log.RecordTestReport({ [2] = "sparse" }) end, "dense")
            AssertFails(function() log.RecordTestReport({ "text", {} }) end, "text")
            assert(#environment.InventoryCompanion_Diagnostics.testReports == 0)
            assert(environment.InventoryCompanion_Diagnostics.nextTestReportSequence == 1)
        end },
        { name = "Copy and verbose finalization saves full failures instead of raising report errors", run = function()
            local log, environment, messages, addon = LoadLog(nil, false)
            log.Initialize()
            log.Start()
            local finish = LoadFinalizer(addon, messages)
            local lines = { "[InventoryCompanion tests] 0/1 passed.", "[InventoryCompanion tests] FAIL example" }
            finish(lines, { copy = true }, {}, { "FAIL example" })
            assert(#environment.InventoryCompanion_Diagnostics.testReports == 1)
            assert(messages[2]:find("FAIL example", 1, true))
            assert(messages[3]:find("memory", 1, true) and messages[3]:find("/reloadui", 1, true))
            finish(lines, { verbose = true, copy = true }, {}, { "FAIL example" })
            assert(#environment.InventoryCompanion_Diagnostics.testReports == 2)
            assert(messages[5] == lines[2])
            assert(not addon.accountWide.diagnosticLoggingEnabled)
        end },
        { name = "Unavailable-store finalization visibly distinguishes unsaved reports", run = function()
            local log, _, messages, addon = LoadLog({ schemaVersion = 99 }, false)
            log.Initialize()
            log.Start()
            local finish = LoadFinalizer(addon, messages)
            finish({ "summary", "FAIL example" }, { copy = true }, {}, { "FAIL example" })
            assert(messages[#messages]:find("NOT saved", 1, true))
            assert(not messages[#messages]:find("recorded", 1, true))
        end },
    }
end
