local this = InventoryCompanion
this.DiagnosticLog = {}
local log = this.DiagnosticLog

local schemaVersion = 3
local maxEvents, maxSamples, maxDetails, maxReports = 1000, 2000, 100, 10
local store, unavailableReason
local initialized, started = false, false
local pendingEvents = {}
local enableRevision = 0

local function IsFinite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function IsPositiveInteger(value)
    return IsFinite(value) and value > 0 and value == math.floor(value)
end

local function CopyScalarTree(value, path, visiting)
    if type(value) ~= "table" then
        assert(type(value) == "string" or type(value) == "boolean" or IsFinite(value),
            "Invalid diagnostic value at " .. path)
        return value
    end
    assert(not visiting[value], "Cyclic diagnostic data at " .. path)
    visiting[value] = true
    local copy = {}
    for key, entry in pairs(value) do
        assert(type(key) == "string" or IsFinite(key), "Invalid diagnostic key at " .. path)
        copy[key] = CopyScalarTree(entry, path .. "." .. tostring(key), visiting)
    end
    visiting[value] = nil
    return copy
end

local function ValidateList(list, label, validateEntry)
    assert(type(list) == "table", label .. " must be a table")
    local count = 0
    for index, entry in pairs(list) do
        assert(IsPositiveInteger(index), label .. " must be a list")
        count = count + 1
        validateEntry(entry)
    end
    for index = 1, count do assert(list[index] ~= nil, label .. " must be a dense list") end
    return count
end

local function ValidateLine(line)
    assert(type(line) == "string", "Diagnostic report/detail lines must be text")
end

local function CopyReportLines(reportLines)
    local lines = {}
    for _, line in ipairs(reportLines) do
        local first = 1
        repeat
            -- ESO discards saved strings over 2000 bytes; keep chunks below that limit.
            local last = math.min(first + 1899, #line)
            if last < #line then
                while last >= first and line:byte(last + 1) >= 128 and line:byte(last + 1) < 192 do
                    last = last - 1
                end
                assert(last >= first, "Invalid UTF-8 at diagnostic report chunk boundary")
            end
            lines[#lines + 1] = line:sub(first, last)
            first = last + 1
        until first > #line
    end
    return lines
end

local function ValidateEvent(event)
    assert(type(event) == "table" and IsFinite(event.timestamp) and IsFinite(event.gameTimeMs)
        and type(event.kind) == "string" and type(event.message) == "string",
        "Invalid saved diagnostic event")
    if event.details ~= nil then ValidateList(event.details, "Diagnostic event details", ValidateLine) end
end

local function ValidateSample(sample)
    assert(type(sample) == "table" and IsFinite(sample.timestamp), "Invalid saved diagnostic sample")
end

local function ValidateCurrent(saved)
    ValidateList(saved.events, "Saved diagnostic events", ValidateEvent)
    assert(type(saved.samples) == "table", "Saved diagnostic samples must be a table")
    for stream, samples in pairs(saved.samples) do
        assert(type(stream) == "string", "Diagnostic sample stream names must be text")
        ValidateList(samples, "Saved diagnostic samples " .. stream, ValidateSample)
    end
    local count = ValidateList(saved.testReports, "Saved test reports", function(report)
        assert(type(report) == "table" and IsPositiveInteger(report.sequence) and IsFinite(report.timestamp),
            "Invalid saved diagnostic test report")
        ValidateList(report.lines, "Saved test report lines", ValidateLine)
    end)
    assert(count <= maxReports, "Too many saved diagnostic test reports")
    local previous = 0
    for _, report in ipairs(saved.testReports) do
        assert(report.sequence > previous, "Saved test report sequences must increase")
        previous = report.sequence
    end
    assert(IsPositiveInteger(saved.nextTestReportSequence) and saved.nextTestReportSequence > previous,
        "Invalid next diagnostic test report sequence")
end

local function PrepareStore(saved)
    if saved == nil then
        return { schemaVersion = schemaVersion, events = {}, samples = {},
            testReports = {}, nextTestReportSequence = 1 }
    end
    assert(type(saved) == "table", "Saved diagnostic data must be a table")
    assert(saved.schemaVersion == 1 or saved.schemaVersion == 2 or saved.schemaVersion == schemaVersion,
        "Unsupported diagnostic schema: " .. tostring(saved.schemaVersion))
    local candidate = CopyScalarTree(saved, "diagnostics", {})
    if candidate.schemaVersion < schemaVersion then
        assert(candidate.testReports == nil and candidate.nextTestReportSequence == nil,
            "Older diagnostic data contains report-history fields")
        if candidate.schemaVersion == 1 then
            assert(candidate.events == nil and candidate.samples == nil,
                "Schema 1 diagnostic data has schema 2 fields")
            if candidate.playEvents ~= nil then
                ValidateList(candidate.playEvents, "Saved play events", ValidateEvent)
            end
            if candidate.scanSamples ~= nil then
                ValidateList(candidate.scanSamples, "Saved tracker scan samples", ValidateSample)
            end
            candidate.events = candidate.playEvents or {}
            candidate.samples = {}
            if candidate.scanSamples ~= nil then candidate.samples.trackerScan = candidate.scanSamples end
            candidate.playEvents, candidate.scanSamples = nil, nil
        end
        candidate.testReports, candidate.nextTestReportSequence = {}, 1
        candidate.schemaVersion = schemaVersion
    end
    ValidateCurrent(candidate)
    return candidate
end

local function AppendNewest(entries, entry, limit)
    entries[#entries + 1] = entry
    while #entries > limit do table.remove(entries, 1) end
end

local function AssertInitialized()
    assert(initialized, "Diagnostic log has not been initialized")
end

function log.Initialize()
    assert(not initialized, "Diagnostic log is already initialized")
    initialized = true
    local ok, prepared = pcall(PrepareStore, InventoryCompanion_Diagnostics)
    if not ok then
        unavailableReason = tostring(prepared)
        d("[InventoryCompanion] Diagnostic recording unavailable; saved data unchanged: " .. unavailableReason)
        return
    end
    store = prepared
    InventoryCompanion_Diagnostics = prepared
end

function log.IsAvailable()
    AssertInitialized()
    return store ~= nil
end

function log.IsEnabled()
    AssertInitialized()
    return started and store ~= nil and this.accountWide.diagnosticLoggingEnabled == true
end

function log.GetEnableRevision()
    AssertInitialized()
    return enableRevision
end

function log.Start()
    AssertInitialized()
    assert(not started, "Diagnostic log is already started")
    assert(type(this.accountWide.diagnosticLoggingEnabled) == "boolean",
        "Diagnostic logging setting must be validated before Start")
    started = true
    enableRevision = enableRevision + 1
    local earlier = pendingEvents
    pendingEvents = nil
    log.Event("session", string.format("UI loaded: %s %s; API %s; ESO Plus %s; character %s (%s).",
        tostring(this.Name), tostring(this.Version), tostring(GetAPIVersion()), tostring(IsESOPlusSubscriber()),
        tostring(GetUnitName("player")), tostring(GetCurrentCharacterId())))
    if log.IsEnabled() then
        for _, event in ipairs(earlier) do AppendNewest(store.events, event, maxEvents) end
    end
end

function log.Event(kind, message, details, force)
    AssertInitialized()
    assert(type(kind) == "string" and type(message) == "string", "Diagnostic events need a kind and message")
    assert(force == nil or type(force) == "boolean", "Forced diagnostic recording must be a boolean")
    if force then assert(started, "Explicit diagnostic events cannot be recorded before Start") end
    if details ~= nil then ValidateList(details, "Diagnostic event details", ValidateLine) end
    if store == nil then return nil, unavailableReason end
    if started and not force and not log.IsEnabled() then return false end
    local lines
    if details ~= nil then
        local source = CopyReportLines(details)
        lines = {}
        local count = force and #source or math.min(#source, maxDetails)
        for index = 1, count do lines[index] = source[index] end
        if not force and #source > maxDetails then
            lines[maxDetails] = string.format("... %d more line(s) omitted", #source - maxDetails + 1)
        end
    end
    AppendNewest(started and store.events or pendingEvents, { timestamp = GetTimeStamp(),
        gameTimeMs = GetGameTimeMilliseconds(), kind = kind, message = message, details = lines }, maxEvents)
    return true
end

function log.Sample(stream, entry)
    AssertInitialized()
    assert(started, "Diagnostic samples cannot be recorded before the diagnostic log starts")
    assert(type(stream) == "string" and type(entry) == "table", "Diagnostic samples need a stream and entry table")
    if not log.IsEnabled() then return end
    local sample = CopyScalarTree(entry, "sample", {})
    sample.timestamp = GetTimeStamp()
    if store.samples[stream] == nil then store.samples[stream] = {} end
    AppendNewest(store.samples[stream], sample, maxSamples)
end

function log.SetEnabled(enabled)
    AssertInitialized()
    assert(started, "Diagnostic logging cannot change before Start")
    assert(log.IsAvailable(), "Diagnostic log is unavailable: " .. tostring(unavailableReason))
    assert(type(enabled) == "boolean", "Diagnostic logging setting must be a boolean")
    if this.accountWide.diagnosticLoggingEnabled == enabled then return end
    if not enabled then log.Event("loggingDisabled", "Diagnostic logging turned off.") end
    this.accountWide.diagnosticLoggingEnabled = enabled
    enableRevision = enableRevision + 1
    if enabled then log.Event("loggingEnabled", "Diagnostic logging turned on.") end
end

function log.RecordTestReport(reportLines)
    AssertInitialized()
    assert(started, "Test reports cannot be recorded before the diagnostic log starts")
    ValidateList(reportLines, "Test report lines", ValidateLine)
    if store == nil then return nil, unavailableReason end
    local lines = CopyReportLines(reportLines)
    local sequence = store.nextTestReportSequence
    assert(IsPositiveInteger(sequence + 1) and sequence + 1 > sequence, "Test report sequence exhausted")
    local report = { sequence = sequence, timestamp = GetTimeStamp(), lines = lines }
    AppendNewest(store.testReports, report, maxReports)
    store.nextTestReportSequence = sequence + 1
    return report
end

function log.Clear()
    assert(log.IsAvailable(), "Diagnostic log is unavailable: " .. tostring(unavailableReason))
    store.events, store.samples, store.testReports = {}, {}, {}
    d("[InventoryCompanion] Diagnostic log and test reports cleared. /reloadui or log out to save the change.")
end

function log.GetStore()
    AssertInitialized()
    return store, unavailableReason
end
