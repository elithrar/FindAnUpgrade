# Development

Use [uv](https://docs.astral.sh/uv/) 0.13.1. `.python-version` pins Python 3.15.0, the latest stable release checked against [Python.org](https://www.python.org/downloads/) on 2026-10-16. `uv.lock` pins the development dependencies, including Lupa 2.8 and Ruff 0.17.1. The source-build constraints in `pyproject.toml` pin Lupa's build tools too.

Keep local environments, managed Python, and caches in `.work/`. For PowerShell:

```powershell
$env:UV_CACHE_DIR = "$PWD/.work/uv-cache"
$env:UV_PYTHON_INSTALL_DIR = "$PWD/.work/uv-python"
$env:UV_PYTHON_BIN_DIR = "$PWD/.work/uv-bin"
$env:UV_PROJECT_ENVIRONMENT = "$PWD/.work/venv"
uv sync --locked
uv run --locked python tools/verify.py
```

For a POSIX shell:

```sh
export UV_CACHE_DIR="$PWD/.work/uv-cache"
export UV_PYTHON_INSTALL_DIR="$PWD/.work/uv-python"
export UV_PYTHON_BIN_DIR="$PWD/.work/uv-bin"
export UV_PROJECT_ENVIRONMENT="$PWD/.work/venv"
uv sync --locked
uv run --locked python tools/verify.py
```

Python 3.15 on Windows x64 and Ubuntu x64 currently needs a C compiler to build Lupa 2.8 from source. On Windows without MSVC, select the official Python 3.15.0 x86 runtime before syncing; Lupa publishes a compatible ABI3 wheel:

```powershell
$env:UV_PYTHON = 'cpython-3.15.0-windows-x86-none'
uv python install $env:UV_PYTHON
uv sync --locked
uv run --locked python tools/verify.py
```

This uses Python 3.15 and Lua 5.1. It does not substitute an older Python or Lua version. CI uses Python 3.15.0 on Ubuntu, where the runner supplies a C compiler.

## Checks

The verifier runs Ruff lint and format checks, the Lua 5.1 scenarios, Python unit tests, data regeneration checks, package tests, release tests, and the final build. Ruff checks Python style and correctness; the Lua and Python suites execute the behavior tests. Reports and archives go to `dist/`.

To format or lint Python separately:

```sh
uv run --locked ruff format tools tests
uv run --locked ruff check tools tests
uv run --locked ruff format --check tools tests
```

The Ruff rule set covers pycodestyle, Pyflakes, import sorting, and Python modernization (`E`, `F`, `I`, `UP`). The formatter owns wrapping; `E501` is excluded so long embedded source strings and URLs remain intact.

Optional screenshot renderers use Pillow:

```sh
uv sync --locked --group visual
uv run --locked --group visual python tools/render_sidebar_mock.py --help
```

Do not add `.work/pydeps` to `PYTHONPATH`; stale wheels can shadow locked dependencies. To update a dependency intentionally, edit its exact pin, run `uv lock`, and rerun the verifier. Keep `.python-version`, CI's Python version, and these instructions aligned when upgrading Python.

## Data and releases

Use `uv run --locked python tools/sync_catalog.py check` for the offline catalog check. Acquisition, staged imports, cache receipts, and recovery are described in [DATABASE-SYNC.md](DATABASE-SYNC.md). Preserve exact IDs, source hashes, and unknown values when changing import tools.

The workflows run the same locked verifier. Release publishing is restricted to `elithrar/FindAnUpgrade` and runs only for a pushed `v*` tag or an explicit manual dispatch. The release validator requires an existing annotated version tag on `main`, matching metadata, and an exact tested package. `CF_API_KEY` is a repository secret; `CF_PROJECT_ID` is a repository variable. Never print the key. See [RELEASING.md](RELEASING.md) for the publishing procedure.

Source contracts and mocks do not prove native rendering or taint safety. Record outstanding client checks in [VALIDATION.md](VALIDATION.md).
