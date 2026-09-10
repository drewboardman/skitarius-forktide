# Benchmarks

`run.lua` measures the CPU and allocation cost of the mod's hot paths without
launching Darktide. It drives the real `SkitariusOmnissiah`,
`SkitariusWeaponManager`, `SkitariusWidgetManager` and `HudElementSkitarius`
methods through the same fixture the tests use
(`tests/support/charge_release_fixture.lua`), so the numbers track changes to
shipping code instead of to a rewrite of it.

## What is measured

Each scenario is measured three ways:

- **ns/op** — median of nine warmed samples with the JIT on (steady state).
- **ns/op with the JIT off** — the interpreter, worst case before traces
  compile. LuaJIT only compiles code that runs often, so a function called once
  per frame can behave very differently from a hot benchmark loop.
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

## In CI

`.github/workflows/test.yml` runs the benchmarks on every push, publishes the
table to the workflow summary and stores the JSON report as an artifact. On
pushes it also downloads the previous run's artifact and fills in the
"Change vs baseline" column. No performance pass/fail threshold is applied.
