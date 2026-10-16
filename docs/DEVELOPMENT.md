# Development

The repository installs one local Python package, `fau_tools`, with one command, `fau`. [uv](https://docs.astral.sh/uv/) 0.13.1 selects Python 3.15.0 from `.python-version` and installs the dependencies pinned by `uv.lock`. No other addon, website checkout or global Python packages are required.

## One-time private environment setup

Lupa 2.8 supplies Lua 5.1; Ruff 0.17.1 supplies Python lint/format checks. The setuptools backend and Lupa source-build requirements are pinned too. To change dependencies, edit their exact pins, run `uv lock`, and rerun `fau check`. Do not inject old `.work/pydeps` wheels.

Keep the environment, managed Python and caches inside `.work/`. Before the first `uv sync` or `uv run`, configure these absolute paths from the checkout root. PowerShell:

```powershell
$env:UV_CACHE_DIR = "$PWD/.work/uv-cache"
$env:UV_PYTHON_INSTALL_DIR = "$PWD/.work/uv-python"
$env:UV_PYTHON_BIN_DIR = "$PWD/.work/uv-bin"
$env:UV_PROJECT_ENVIRONMENT = "$PWD/.work/venv"
```

For a POSIX shell:

```sh
export UV_CACHE_DIR="$PWD/.work/uv-cache"
export UV_PYTHON_INSTALL_DIR="$PWD/.work/uv-python"
export UV_PYTHON_BIN_DIR="$PWD/.work/uv-bin"
export UV_PROJECT_ENVIRONMENT="$PWD/.work/venv"
```

These environment paths are absolute, so subsequent `uv --project` invocations can run from elsewhere. Add them to the shell's project setup if needed. No global Python dependency install is required.

Python 3.15 on Windows x64 and Ubuntu x64 needs a C compiler to build Lupa 2.8 from source. On Windows without MSVC, the official Python 3.15.0 x86 runtime can use Lupa's ABI3 wheel:

```powershell
$env:UV_PYTHON = 'cpython-3.15.0-windows-x86-none'
uv python install $env:UV_PYTHON
```

CI uses Python 3.15.0 on Ubuntu with a compiler. Keep `.python-version`, CI and this document aligned for upgrades.

After setup, run:

```sh
uv run --locked fau check
```

`uv run` installs the editable package and syncs the locked environment automatically. From another directory, select the checkout explicitly:

```sh
uv run --project /path/to/FindAnUpgrade --locked fau check
uv run --project /path/to/FindAnUpgrade --locked fau build
```

Repository inputs, default caches and outputs are resolved from the installed editable package's checkout. Explicit path arguments are resolved from the caller's directory. Commands never rely on an undocumented `cd` into a tool folder. `python -m fau_tools` is the equivalent module entry point in the same environment.

## Commands

| Command after `uv run --locked` | Purpose |
| --- | --- |
| `fau check` | Ruff lint/format, deterministic data checks, Lua/Python behavior tests and both ZIP builds |
| `fau build` | Validate and build the addon and matching source ZIPs in `dist/` |
| `fau sync check` | Offline catalog verification using owned normalized inputs |
| `fau import [cache options]` | Reparse owned caches into an isolated stage, diff and fully check it; leave tracked inputs untouched |
| `fau sync reparse [cache options]` | Validate the same offline stage, then replace only the listed owned outputs |
| `fau sync refresh [cache options]` | Acquire pinned public sources, stage, diff, check and apply the catalog |
| `fau --help` | Common commands and advanced source/repair/release entry points |

Use [DATABASE-SYNC.md](DATABASE-SYNC.md) for source pins, cache options and safe recovery. [RELEASING.md](RELEASING.md) describes the separately authorized publishing workflow. Neither checks, builds nor catalog sync commands install or publish the addon.

## Ownership

| Path | Contents |
| --- | --- |
| `FindAnUpgrade/` | Exact shipped addon payload, licenses and generated Lua tables |
| `data/` | Owned normalized facts, source hashes, identity history, gap evidence and checked generated projections |
| `fau_tools/` | CLI/context; source acquisition; nonexecuting parsers/imports; classification/catalog projections; sync; package/release checks |
| `tests/` | Lua scenarios, client fixtures and Python regression tests |
| `docs/` | Maintained behavior/source contracts, provenance, license boundaries and current operating instructions |
| `.work/` | Ignored raw source caches, native fixtures, temporary import stages and private environments |
| `dist/` | Ignored ZIPs, validation reports, import diffs and delivery receipts |

`fau_tools/context.py` owns repository paths and the shared source/staging inventory. Domain modules use normal package imports; tests do not inject tool paths or load scripts dynamically. Related classification, catalog, source acquisition and publisher functions share modules. Complex source parsers retain their own boundaries rather than being joined into a generic framework.

The old `tools/*.py` entry scripts are replaced by the CLI. Historical plans, iteration reviews, private installers and mock renderers are recoverable from Git; they are not inputs to future imports. Source/license/contract receipts remain tracked. Build metadata, caches, staging files and reports remain ignored.

## Focused checks

From the checkout, run a Python suite or format/lint separately:

```sh
uv run --locked python -m unittest discover -s tests -p catalog_sync_test.py
uv run --locked ruff check fau_tools tests
uv run --locked ruff format --check fau_tools tests
uv run --locked ruff format fau_tools tests
```

Tests execute imports, staging, failed writes, provenance rules, packaging and release guards with disposable fixtures. Publishers use mocked network calls in tests. Generated facts and Lua bytes must be deterministic. Generated Lua headers retain their original script labels for byte stability; regeneration now uses `fau data quests` and `fau data catalog`. Native source fixtures are optional in an ordinary checkout and fetched at exact pins by CI.

Check `dist/validation-evidence.json` and `dist/test-results.json` for actual results. Source/mocks do not prove native rendering, input or taint safety; pending client checks remain in [VALIDATION.md](VALIDATION.md).
