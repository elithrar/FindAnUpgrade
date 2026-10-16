"""Repository paths and maintained source inventory shared by all commands.

The editable/installable package determines its checkout from its own location,
never the caller's working directory. Explicit input paths remain caller supplied.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / ".work"
DIST = ROOT / "dist"
SOURCE_SUFFIXES = {
    "FindAnUpgrade": {".lua", ".toc", ".md", ".txt", ""},
    "data": {".json"},
    "docs": {".md", ".json"},
    "tests": {".py", ".lua"},
    "fau_tools": {".py"},
    ".github": {".yml", ".yaml"},
}
SOURCE_ROOT = (
    "AGENTS.md",
    "README.md",
    "LICENSE",
    ".gitignore",
    ".gitattributes",
    "pyproject.toml",
    "uv.lock",
    ".python-version",
)


def source_files(root=ROOT):
    """Exact maintained sources; temporary caches and build outputs are excluded."""
    files = [root / name for name in SOURCE_ROOT]
    for directory, suffixes in SOURCE_SUFFIXES.items():
        files.extend(
            file
            for file in (root / directory).rglob("*")
            if file.is_file()
            and not any(
                part
                in {"__pycache__", ".work", ".venv", "build", "dist", ".ruff_cache"}
                or part.endswith(".egg-info")
                for part in file.relative_to(root).parts
            )
            and file.suffix in suffixes
            and not any(
                part.startswith(".")
                for part in file.relative_to(root / directory).parts
            )
        )
    return sorted(files)
