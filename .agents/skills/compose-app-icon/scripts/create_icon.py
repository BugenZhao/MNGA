#!/usr/bin/env python3
"""Create an Apple Icon Composer .icon package from an icon.json document and asset files."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

SCHEMA_PATH = Path(__file__).resolve().parent / "icon-schema.json"


def _parse_asset(spec: str) -> tuple[str, Path]:
    if "=" not in spec:
        raise argparse.ArgumentTypeError(f"--asset expects NAME=PATH, got {spec!r}")
    name, _, raw_path = spec.partition("=")
    name = name.strip()
    path = Path(raw_path).expanduser().resolve()
    if not name:
        raise argparse.ArgumentTypeError(f"--asset NAME must not be empty ({spec!r})")
    if not path.is_file():
        raise argparse.ArgumentTypeError(f"--asset {name} file not found: {path}")
    return name, path


def _collect_referenced_assets(doc: dict) -> set[str]:
    names: set[str] = set()
    for group in doc.get("groups", []) or []:
        for layer in group.get("layers", []) or []:
            if isinstance(layer.get("image-name"), str):
                names.add(layer["image-name"])
            for entry in layer.get("image-name-specializations", []) or []:
                value = entry.get("value")
                if isinstance(value, str) and value != "automatic":
                    names.add(value)
    return names


def _load_icon(arg: str) -> dict:
    if arg == "-":
        return json.loads(sys.stdin.read())
    return json.loads(Path(arg).expanduser().read_text())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        required=True,
        help="Path to the .icon package to create (must end with .icon)",
    )
    parser.add_argument(
        "--icon",
        required=True,
        help="Path to an icon.json file, or '-' to read from stdin",
    )
    parser.add_argument(
        "--asset",
        action="append",
        default=[],
        type=_parse_asset,
        metavar="NAME=PATH",
        help="Register an image asset; may be repeated. NAME must match an image-name in the icon document.",
    )
    parser.add_argument(
        "--no-validate",
        action="store_true",
        help="Skip JSON Schema validation before writing",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite the output directory if it already exists",
    )
    args = parser.parse_args(argv)

    output = Path(args.output).expanduser().resolve()
    if output.suffix != ".icon":
        print("error: --output must end with .icon", file=sys.stderr)
        return 2

    icon = _load_icon(args.icon)
    asset_map: dict[str, Path] = dict(args.asset)

    if not args.no_validate:
        schema = json.loads(SCHEMA_PATH.read_text())
        errors = sorted(
            Draft202012Validator(schema).iter_errors(icon),
            key=lambda e: list(e.absolute_path),
        )
        if errors:
            print(
                f"error: icon document failed schema validation ({len(errors)} error(s))",
                file=sys.stderr,
            )
            for err in errors:
                pointer = "/" + "/".join(str(p) for p in err.absolute_path)
                print(f"  at {pointer}: {err.message}", file=sys.stderr)
            return 1

    referenced = _collect_referenced_assets(icon)
    missing = sorted(referenced - asset_map.keys())
    if missing:
        print(
            f"error: missing --asset for image-name(s): {', '.join(missing)}",
            file=sys.stderr,
        )
        return 1

    if output.exists():
        if not args.force:
            print(
                f"error: {output} already exists (use --force to overwrite)",
                file=sys.stderr,
            )
            return 1
        shutil.rmtree(output)

    assets_dir = output / "Assets"
    assets_dir.mkdir(parents=True)

    # Copy every supplied asset — not just the referenced ones, matching
    # Icon Composer's behavior of preserving all files in Assets/.
    for name, src in asset_map.items():
        shutil.copyfile(src, assets_dir / name)

    (output / "icon.json").write_text(json.dumps(icon, indent=2, sort_keys=True) + "\n")

    print(f"created {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
