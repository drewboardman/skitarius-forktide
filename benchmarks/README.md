# Benchmarks

`run.lua` measures the CPU and allocation cost of the mod's hot paths without
launching Darktide. It drives the real `ForktideOmnissiah`,
`ForktideWeaponManager`, `ForktideWidgetManager` and `HudElementForktide`
methods through the same fixture the tests use
(`tests/support/charge_release_fixture.lua`), so the numbers track changes to
shipping code instead of to a rewrite of it.

## What is measured

Each scenario is measured three ways:

- **ns/op (interpreter)** — median of nine warmed samples with the JIT disabled.
  This is the stable measure of the work the code does, and it is what the
  report compares against a baseline.
- **ns/op (JIT)** — steady state once LuaJIT has compiled a trace. Treat it as a
  lower bound: a tight benchmark loop with stable inputs can be optimised far
  more aggressively (sometimes hoisted clean out of the loop) than the same
  function interleaved with real game code, so it swings between runs.
- **bytes/op** — allocations per operation, measured with the collector paused.
  This is GC pressure, and garbage causes hitches more reliably than raw CPU.

`Runs` records whether a scenario is charged **per frame** (it runs once inside
`mod.update`) or **per input query** (the engine calls `InputService._get` many
times per frame, so multiply by the query count).

## Running

Requires LuaJIT (or Lua 5.1) and Python 3. From the repository root:

```sh
mkdir -p reports
luajit benchmarks/run.lua > reports/benchmarks.json
python3 tools/report.py benchmarks reports/benchmarks.json
```

## Comparing against a baseline

Save a run as a baseline, then compare later runs against it:

```sh
cp reports/benchmarks.json reports/baseline.json
# ... change code ...
luajit benchmarks/run.lua > reports/benchmarks.json
python3 tools/report.py benchmarks reports/benchmarks.json --baseline reports/baseline.json
```

## Why a reference workload

ns/op describes the machine as much as the code: an M-series laptop core and a
shared CI runner can differ by 2–3x, so comparing raw numbers across machines is
meaningless. `run.lua` therefore also times a fixed, allocation-free reference
workload in the same process, and the report expresses changes relative to it. A
slower machine shrinks the reference too, so the ratio — and the reported change
— stays meaningful.

Reports are only compared at all when the runtime, OS, architecture and JIT
setting match; anything else is reported as a note and skipped. Even then, treat
small changes as noise (identical code varies a few percent between runs) and
read the median, not a single sample.

## Limitations

- Only the mod's own Lua code is timed. Calls into the engine (`ScriptUnit`,
  `Managers`, the HUD element lookup) are stubbed by the fixture, so engine-side
  cost is not included and the absolute numbers are a floor, not the whole story.
- `bytes/op` is measured with the JIT on, which is the in-game steady state.
  LuaJIT sinks allocations that do not escape and interns repeated substrings,
  so allocation that a cold run would make may not appear here. That is
  representative of a warmed game, not of the first seconds after loading.
- Input-path scenarios are measured per query. The engine does not tell us how
  many queries it issues per frame, so only the per-frame scenarios can be read
  directly as a share of the frame budget.
- `os.clock()` is CPU time; it ignores time spent anywhere else in the engine.

## In CI

`.github/workflows/test.yml` runs the benchmarks on every push, publishes the
table to the workflow summary and stores the JSON report as an artifact. On
pushes it also downloads the previous run's artifact and fills in the
"Change vs baseline" column. No performance pass/fail threshold is applied.
