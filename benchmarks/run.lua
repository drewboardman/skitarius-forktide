local fixture = require("tests.support.charge_release_fixture")

local manual = fixture("none", 100, 50)
local sequence = fixture("charged", 100, 50)
sequence.engram:new_engram("override_primary")
local weapon = fixture("none", 100, 50).weapon
local levels = { 0, 0.25, 0.49, 0.50, 0.75, 1 }

local cases = {
    {
        name = "Manual charge release",
        run = function(i) return manual.release_at(levels[i % #levels + 1]) and 1 or 0 end,
    },
    {
        name = "Active sequence charge release",
        run = function(i) return sequence.release_at(levels[i % #levels + 1]) and 1 or 0 end,
    },
    {
        name = "Equipped ranged weapon refresh",
        run = function()
            weapon:refresh_weapon()
            return weapon:weapon_type() == "RANGED" and 1 or 0
        end,
    },
}

assert(not manual.release_at(0.49) and manual.release_at(0.50))
assert(not sequence.release_at(0.49) and sequence.release_at(0.50))
assert(weapon:weapon_name() == "forcestaff_p2_m1")

local sink = 0
local function measure(run, iterations)
    local checksum = 0
    local start = os.clock()
    for i = 1, iterations do
        checksum = checksum + run(i)
    end
    local elapsed = os.clock() - start
    sink = sink + checksum
    return elapsed
end

local revision_command = assert(io.popen("git rev-parse HEAD"))
local revision = revision_command:read("*l")
revision_command:close()
local dirty_command = assert(io.popen("git status --porcelain --untracked-files=normal"))
local dirty = dirty_command:read("*a") ~= ""
dirty_command:close()

io.write(string.format(
    '{"schema":1,"revision":%q,"dirty":%s,"runtime":%q,"os":%q,"arch":%q,"jit":%s,"samples":9,"clock":"os.clock CPU seconds","cases":[\n',
    revision, tostring(dirty), jit and jit.version or _VERSION,
    jit and jit.os or "unknown", jit and jit.arch or "unknown", tostring(jit and jit.status() or false)
))

for index, case in ipairs(cases) do
    local iterations = 1000
    repeat
        local elapsed = measure(case.run, iterations)
        if elapsed >= 0.05 then break end
        iterations = iterations * 2
        assert(iterations <= 134217728, "Benchmark did not reach measurable duration")
    until false

    local samples = {}
    for sample = 1, 9 do
        collectgarbage("collect")
        samples[sample] = measure(case.run, iterations) * 1000000000 / iterations
    end
    io.write(string.format('{"name":%q,"iterations":%d,"ns_per_op":[', case.name, iterations))
    for sample, value in ipairs(samples) do
        io.write(string.format("%s%.6f", sample > 1 and "," or "", value))
    end
    io.write("]}", index < #cases and ",\n" or "\n")
end

io.write(string.format('],"checksum":%.0f}\n', sink))
