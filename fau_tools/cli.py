"""Route checkout commands while domain parsers own their options and help."""

import argparse
import json
import sys

PROG = "python -m fau_tools"


def command_parser():
    """Own command structure; forwarded leaf options stay with domain parsers."""
    parser = argparse.ArgumentParser(
        prog=PROG,
        description="FindAnUpgrade tooling: check, build, and safely import the owned catalog.",
        epilog=f"Use {PROG} COMMAND --help for options. Publication requires separately authorized release credentials and tags.",
    )
    commands = parser.add_subparsers(dest="command", title="commands", required=True)
    forwarded = {
        "sync",
        "import",
        "metadata",
        "chains",
        "membership",
        "import-att",
        "import-catalog",
        "migrate",
        "observations",
    }
    groups = {
        "data": ("classify", "tags", "quests", "catalog"),
        "source": ("att", "public"),
    }
    for name, description in (
        ("check", "Run lint, deterministic data checks, Lua/Python tests, and build"),
        ("build", "Build deterministic addon and maintained-source archives"),
        ("sync", "Check tracked inputs, reparse caches, or refresh public sources"),
        ("import", "Stage and validate offline caches without replacing owned data"),
        ("data", "Advanced classification, taxonomy, and Lua projection maintenance"),
        ("source", "Acquire pinned ATT files or public Forever pages"),
        ("metadata", "Acquire or parse pinned Questie metadata"),
        ("chains", "Acquire or parse exact quest chain evidence"),
        ("membership", "Verify compiled ATT membership without running upstream Lua"),
        ("import-att", "Import the original pinned ATT snapshot"),
        ("import-catalog", "Normalize complete cached catalog sources"),
        ("migrate", "Validate or explicitly copy owned renamed saved settings"),
        (
            "observations",
            "Validate and compare an untrusted manual quest-data JSON export",
        ),
        ("release", "Prepare or verify an authorized exact release tag"),
        ("publish-github", "Prepare an authorized release draft or finalize it"),
        ("publish-curseforge", "Upload an authorized exact Forever release once"),
    ):
        command = commands.add_parser(
            name,
            help=description,
            description=description,
            add_help=name not in forwarded,
        )
        command.set_defaults(command_parser=command)
        if name in groups:
            modes = command.add_subparsers(dest="mode", required=True)
            for mode in groups[name]:
                leaf = modes.add_parser(mode, add_help=False)
                leaf.set_defaults(command_parser=leaf)
        elif name == "release":
            command.add_argument("--verify", action="store_true")
        elif name == "publish-github":
            command.add_argument("--finalize", action="store_true")
    return parser


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    parser = command_parser()
    if not argv:
        parser.print_help()
        return
    selected, arguments = parser.parse_known_args(argv)
    command = selected.command
    detail = selected.command_parser
    prog = detail.prog
    if (
        command in {"check", "build", "release", "publish-github", "publish-curseforge"}
        and arguments
    ):
        detail.error("unrecognized arguments: " + " ".join(arguments))
    match command:
        case "check":
            from fau_tools import verify

            verify.main()
        case "build":
            from fau_tools import packaging

            print(json.dumps(packaging.build(), indent=2))
        case "sync" | "import":
            from fau_tools import sync

            if command == "import":
                if "--help" in arguments or "-h" in arguments:
                    print(
                        f"{PROG} import is an alias for {PROG} sync reparse --stage-only.\n"
                    )
                sync.main(["reparse", "--stage-only", *arguments], prog=f"{PROG} sync")
            else:
                sync.main(arguments, prog=prog)
        case "data":
            from fau_tools import catalog, classification

            match selected.mode:
                case "classify":
                    classification.import_main(arguments, prog=prog)
                case "tags":
                    classification.taxonomy_main(arguments, prog=prog)
                case "quests":
                    classification.quests_main(arguments, prog=prog)
                case "catalog":
                    catalog.generate_main(arguments, prog=prog)
        case "source":
            from fau_tools import sources

            if selected.mode == "att":
                sources.att_main(arguments, prog=prog)
            else:
                sources.public_main(arguments, prog=prog)
        case "metadata":
            from fau_tools import questie

            questie.main(arguments, prog=prog)
        case "chains":
            from fau_tools import chains

            chains.main(arguments, prog=prog)
        case "membership":
            from fau_tools import membership

            membership.main(arguments, prog=prog)
        case "import-att":
            from fau_tools import att

            att.main(arguments, prog=prog)
        case "import-catalog":
            from fau_tools import importer

            importer.main(arguments, prog=prog)
        case "migrate":
            from fau_tools import migration

            migration.main(arguments, prog=prog)
        case "observations":
            from fau_tools import observations

            observations.main(arguments, prog=prog)
        case "release":
            from fau_tools import release

            release.main(argv[1:])
        case "publish-github":
            from fau_tools import publishing

            if argv[1:] == ["--finalize"]:
                publishing.finalize()
            elif len(argv) == 1:
                publishing.prepare()
            else:
                detail.error("publish-github accepts only --finalize")
        case "publish-curseforge":
            from fau_tools import publishing

            publishing.upload()
