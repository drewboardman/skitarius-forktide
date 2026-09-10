This is the source code repository for **Forktide**.

**Forktide** is a fork of **Skitarius**, a mod for *Warhammer 40,000: Darktide* which allows for the creation and execution of user-defined action sequences, with a multitude of additional features. It is intended primarily as an accessibility tool, but can accommodate the needs of power-users as well.

It is renamed and packaged separately so it can be installed alongside the original. The upstream project by CATBIRDS is on [GitHub](https://github.com/CATBIRDS/Skitarius) and [Nexus](https://www.nexusmods.com/warhammer40kdarktide/mods/510).

## Development

Tests and performance benchmarks run without a copy of the game:

- [`tests/README.md`](tests/README.md) — Busted unit tests.
- [`benchmarks/README.md`](benchmarks/README.md) — LuaJIT CPU benchmarks and baseline comparison.

Both also run automatically in GitHub Actions, with results published to the workflow summary.

Releases are built by `.github/workflows/release.yml`: push a `v*` tag (or run the workflow manually) and it runs the tests, packages `mods/Forktide/` into `Forktide-<version>.zip` and publishes it as a GitHub Release. `tools/package.sh <version>` builds the same zip locally.
