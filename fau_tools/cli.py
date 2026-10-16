"""One explicit entry point for maintained checkout, catalog, and release tasks."""

import argparse
import json
import sys


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    parser = argparse.ArgumentParser(
        prog="fau",
        description="FindAnUpgrade tooling: check, build, and safely import the owned catalog.",
        epilog="Use fau COMMAND --help for options. Metadata, source, and data commands are advanced import maintenance; publication commands require separately authorized release credentials and tags.",
    )
    commands = parser.add_subparsers(dest="command", title="commands", required=True)
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
        ("release", "Prepare or verify an authorized exact release tag"),
        ("publish-github", "Prepare an authorized release draft or finalize it"),
        ("publish-curseforge", "Upload an authorized exact Forever release once"),
    ):
        commands.add_parser(name, help=description, add_help=False)
    if not argv or argv[0] in ("-h", "--help"):
        parser.print_help()
        return
    command = parser.parse_args(argv[:1]).command
    arguments = argv[1:]
    if command in {
        "check",
        "build",
        "data",
        "source",
        "release",
        "publish-github",
        "publish-curseforge",
    } and arguments in (["--help"], ["-h"]):
        detail = argparse.ArgumentParser(prog="fau " + command)
        match command:
            case "data":
                detail.add_argument(
                    "mode", choices=("classify", "tags", "quests", "catalog")
                )
            case "source":
                detail.add_argument("mode", choices=("att", "public"))
            case "release":
                detail.add_argument("--verify", action="store_true")
            case "publish-github":
                detail.add_argument("--finalize", action="store_true")
        detail.print_help()
        return
    match command:
        case "check":
            from fau_tools import verify

            if arguments:
                parser.error("check accepts no arguments")
            verify.main()
        case "build":
            from fau_tools import packaging

            if arguments:
                parser.error("build accepts no arguments")
            print(json.dumps(packaging.build(), indent=2))
        case "sync" | "import":
            from fau_tools import sync

            sync.main(
                (["reparse", "--stage-only"] if command == "import" else []) + arguments
            )
        case "data":
            from fau_tools import catalog, classification

            if not arguments:
                parser.error("data requires classify, tags, quests, or catalog")
            mode, *arguments = arguments
            match mode:
                case "classify":
                    classification.import_main(arguments)
                case "tags":
                    classification.taxonomy_main(arguments)
                case "quests":
                    classification.quests_main(arguments)
                case "catalog":
                    catalog.generate_main(arguments)
                case _:
                    parser.error("data requires classify, tags, quests, or catalog")
        case "source":
            from fau_tools import sources

            if not arguments:
                parser.error("source requires att or public")
            mode, *arguments = arguments
            match mode:
                case "att":
                    sources.att_main(arguments)
                case "public":
                    sources.public_main(arguments)
                case _:
                    parser.error("source requires att or public")
        case "metadata":
            from fau_tools import questie

            questie.main(arguments)
        case "chains":
            from fau_tools import chains

            chains.main(arguments)
        case "membership":
            from fau_tools import membership

            membership.main(arguments)
        case "import-att":
            from fau_tools import att

            att.main(arguments)
        case "import-catalog":
            from fau_tools import importer

            importer.main(arguments)
        case "migrate":
            from fau_tools import migration

            migration.main(arguments)
        case "release":
            from fau_tools import release

            release.main(arguments)
        case "publish-github":
            from fau_tools import publishing

            if arguments == ["--finalize"]:
                publishing.finalize()
            elif not arguments:
                publishing.prepare()
            else:
                parser.error("publish-github accepts only --finalize")
        case "publish-curseforge":
            from fau_tools import publishing

            if arguments:
                parser.error("publish-curseforge accepts no arguments")
            publishing.upload()
