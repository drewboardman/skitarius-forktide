-- CPU benchmarks for the mod's hot paths, measured without launching Darktide.
--
-- Every scenario drives real mod code through the shared test fixture and is
-- measured three ways:
--   * ns/op with the JIT on  - steady state once traces have compiled
--   * ns/op with the JIT off - interpreter, the worst case for cold code
--   * bytes/op               - allocation pressure between GC cycles
--
-- A fixed reference workload is measured in the same process so results can be
-- normalised across machines that run at different speeds.

local fixture = require("tests.support.charge_release_fixture")

local SAMPLES = 9
local MIN_SAMPLE_SECONDS = 0.05
local ALLOCATION_SAMPLES = 3
local ALLOCATION_ITERATIONS = 20000
local MAX_ITERATIONS = 134217728
local NANOSECONDS = 1000000000

local jit = rawget(_G, "jit")
local jit_available = jit ~= nil and jit.status() == true

local sink = 0

local function batch(run, iterations)
    local checksum = 0
    for index = 1, iterations do
        checksum = checksum + run(index)
    end
    return checksum
end

-- Grow the batch until one call takes long enough to time accurately, which
-- also warms the JIT before the measured samples.
local function calibrate(run)
    local iterations = 1000
    while true do
        collectgarbage("collect")
        local start = os.clock()
        sink = sink + batch(run, iterations)
        if os.clock() - start >= MIN_SAMPLE_SECONDS then
            return iterations
        end
        iterations = iterations * 2
        assert(iterations <= MAX_ITERATIONS, "Benchmark did not reach a measurable duration")
    end
end

local function sample(run, iterations)
    local samples = {}
    for index = 1, SAMPLES do
        collectgarbage("collect")
        local start = os.clock()
        sink = sink + batch(run, iterations)
        samples[index] = (os.clock() - start) * NANOSECONDS / iterations
    end
    return samples
end

-- Allocations per operation, with the collector stopped so nothing is reclaimed
-- mid-measurement. Median of a few samples to shrug off noise.
local function sample_bytes(run)
    local samples = {}
    for index = 1, ALLOCATION_SAMPLES do
        collectgarbage("collect")
        collectgarbage("collect")
        collectgarbage("stop")
        local before = collectgarbage("count")
        sink = sink + batch(run, ALLOCATION_ITERATIONS)
        local after = collectgarbage("count")
        collectgarbage("restart")
        samples[index] = (after - before) * 1024 / ALLOCATION_ITERATIONS
    end
    table.sort(samples)
    return samples[math.ceil(#samples / 2)]
end

local function measure(run)
    local iterations = calibrate(run)
    local result = {
        iterations = iterations,
        ns_per_op = sample(run, iterations),
        bytes_per_op = sample_bytes(run),
    }
    if jit_available then
        jit.off()
        jit.flush()
        result.ns_per_op_interpreted = sample(run, calibrate(run))
        jit.on()
    end
    return result
end

-- Reference workload: pure CPU and allocation-free, so a faster machine simply
-- shrinks its ns/op and the ratios stay comparable across machines.
local REFERENCE_TABLE = { 3, 1, 4, 1, 5, 9, 2, 6 }
local function reference_run(index)
    local sum = 0
    for step = 1, 64 do
        sum = sum + REFERENCE_TABLE[(step + index) % 8 + 1] * step
    end
    return sum % 977
end

local levels = { 0, 0.25, 0.49, 0.50, 0.75, 1 }
local manual = fixture("none", 100, 50)
local sequence = fixture("charged", 100, 50)
sequence.engram:new_engram("override_primary")
local frame = fixture("none", 100, 50)

local scenarios = {
    {
        name = "Manual charge release",
        runs = "query",
        run = function(index) return manual.release_at(levels[index % #levels + 1]) and 1 or 0 end,
    },
    {
        name = "Active sequence charge release",
        runs = "query",
        run = function(index) return sequence.release_at(levels[index % #levels + 1]) and 1 or 0 end,
    },
    {
        name = "Input handler",
        runs = "query",
        run = function() return frame.omnissiah:omnissiah("action_one_pressed", false) and 1 or 0 end,
    },
    {
        name = "Weapon identity refresh",
        runs = "frame",
        run = function()
            frame.weapon:refresh_weapon()
            return frame.weapon.name and 1 or 0
        end,
    },
    {
        name = "HUD refresh",
        runs = "frame",
        run = function()
            frame.widget:update_hud()
            return 1
        end,
    },
    {
        name = "Sprint buffer update",
        runs = "frame",
        run = function()
            frame.weapon:update_sprint_buffer()
            return 1
        end,
    },
}

local function number_list(values)
    local parts = {}
    for index, value in ipairs(values) do
        parts[index] = string.format("%.6f", value)
    end
    return table.concat(parts, ",")
end

local revision = "unknown"
local revision_command = io.popen("git rev-parse HEAD 2>/dev/null")
if revision_command then
    revision = revision_command:read("*l") or "unknown"
    revision_command:close()
end
local dirty = false
local dirty_command = io.popen("git status --porcelain --untracked-files=normal 2>/dev/null")
if dirty_command then
    dirty = dirty_command:read("*a") ~= ""
    dirty_command:close()
end

local reference = measure(reference_run)
local runtime = jit_available and jit.version or _VERSION
local os_name = jit_available and jit.os or "unknown"
local arch = jit_available and jit.arch or "unknown"

io.write(string.format(
    '{"schema":2,"revision":%q,"dirty":%s,"runtime":%q,"os":%q,"arch":%q,"jit":%s,' ..
    '"clock":"os.clock CPU seconds","samples":%d,\n',
    revision, tostring(dirty), runtime, os_name, arch, tostring(jit_available), SAMPLES
))
io.write(string.format(
    '"reference":{"name":"mixed arithmetic and table reads","ns_per_op":[%s]},\n',
    number_list(reference.ns_per_op)
))
io.write('"cases":[\n')
for index, scenario in ipairs(scenarios) do
    local result = measure(scenario.run)
    io.write(string.format(
        '{"name":%q,"runs":%q,"iterations":%d,"ns_per_op":[%s],"bytes_per_op":%.4f',
        scenario.name, scenario.runs, result.iterations, number_list(result.ns_per_op), result.bytes_per_op
    ))
    if result.ns_per_op_interpreted then
        io.write(string.format(',"ns_per_op_interpreted":[%s]', number_list(result.ns_per_op_interpreted)))
    end
    io.write("}")
    io.write(index < #scenarios and ",\n" or "\n")
end
io.write(string.format('],"checksum":%.0f}\n', sink))

