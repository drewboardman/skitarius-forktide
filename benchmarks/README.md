# Benchmarks

`run.lua` measures the CPU cost of the mod's hot paths without launching
Darktide. It drives the real `SkitariusOmnissiah`, `SkitariusWeaponManager`
and `SkitariusEngram` methods through the same fixture the tests use
(`tests/support/charge_release_fixture.lua`), so the numbers track changes to
shipping code instead of to a rewrite of it.

## Running

Requires LuaJIT (or Lua 5.1) and Python 3. From the repository root:

```sh
mkdir -p reports
luajit benchmarks/run.lua > reports/benchmarks.json
python3 tools/report.py benchmarks reports/benchmarks.json
```

The report lists the median and min–max nanoseconds per operation for each
scenario, which is enough to spot a regression or confirm an optimisation.

## Comparing against a baseline

Save a run as a baseline, then compare later runs against it:

```sh
cp reports/benchmarks.json reports/baseline.json
# ... change code ...
luajit benchmarks/run.lua > reports/benchmarks.json
python3 tools/report.py benchmarks reports/benchmarks.json --baseline reports/baseline.json
```

The comparison is only shown when the baseline was recorded with the same
runtime, OS, architecture, JIT mode, clock source and scenarios, so results
from a laptop and a CI runner are never mixed. A mismatch is reported as a
note and the comparison column is left blank instead of failing the command.

## What the numbers mean

Values are CPU nanoseconds per call, measured with `os.clock()` over a warmed
batch that auto-scales until each sample runs for at least 50 ms (nine samples,
normal garbage collection). They include the loop and fixture overhead and are
**not** frame times or FPS estimates. Compare the same scenario on the same
machine with the same harness; shared CI runners can vary between builds.

## In CI

`.github/workflows/test.yml` runs the benchmarks on every push, publishes the
table to the workflow summary and stores the JSON report as an artifact. On
pushes it also downloads the previous run's artifact and fills in the
"Change vs baseline" column. No performance pass/fail threshold is applied.
