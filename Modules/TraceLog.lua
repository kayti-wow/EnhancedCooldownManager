-- Trace log buffer (circular buffer for last 100 debug messages)

local _, ns = ...

local TRACE_LOG_MAX = 100
local traceLogBuffer = {}
local traceLogIndex = 0
local traceLogCount = 0

--- Adds a message to the trace log buffer.
---@param message string
local function AddToTraceLog(message)
    traceLogIndex = (traceLogIndex % TRACE_LOG_MAX) + 1
    traceLogBuffer[traceLogIndex] = string.format("[%s] %s", date("%H:%M:%S"), message)
    if traceLogCount < TRACE_LOG_MAX then
        traceLogCount = traceLogCount + 1
    end
end

--- Returns the trace log contents as a single string.
---@return string
local function GetTraceLog()
    if traceLogCount == 0 then
        return "(No trace logs recorded)"
    end

    local lines = {}
    local startIdx = (traceLogCount < TRACE_LOG_MAX) and 1 or (traceLogIndex + 1)
    for i = 1, traceLogCount do
        local idx = ((startIdx - 2 + i) % TRACE_LOG_MAX) + 1
        lines[i] = traceLogBuffer[idx]
    end
    return table.concat(lines, "\n")
end

ns.AddToTraceLog = AddToTraceLog
ns.GetTraceLog = GetTraceLog
