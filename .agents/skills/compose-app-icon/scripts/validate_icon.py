#!/usr/bin/env python3
"""Validate an Icon Composer .icon package (or its icon.json) against the bundled JSON Schema."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

SCHEMA_PATH = Path(__file__).resolve().parent / "icon-schema.json"


def _resolve_icon_json(target: Path) -> tuple[Path, Path | None]:
    """Return (icon.json path, .icon package root or None)."""
    if target.is_dir() and target.suffix == ".icon":
        return target / "icon.json", target
    if target.is_file() and target.name == "icon.json":
        return target, target.parent if target.parent.suffix == ".icon" else None
    if target.is_file():
        return target, None
    raise FileNotFoundError(f"{target} is not a .icon directory or icon.json file")


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


def _format_error(err) -> str:
    pointer = "/" + "/".join(str(p) for p in err.absolute_path)
    return f"  at {pointer}\n    {err.message}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "path", help="Path to a .icon package directory or an icon.json file"
    )
    parser.add_argument(
        "--skip-assets",
        action="store_true",
        help="Do not cross-check referenced image-name values against files in Assets/",
    )
    args = parser.parse_args(argv)

    target = Path(args.path).resolve()
    try:
        icon_json_path, icon_pkg = _resolve_icon_json(target)
    except FileNotFoundError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    schema = json.loads(SCHEMA_PATH.read_text())
    data = json.loads(icon_json_path.read_text())

    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.absolute_path))

    if errors:
        print(f"INVALID: {icon_json_path} ({len(errors)} error(s))")
        for err in errors:
            print(_format_error(err))
        return 1

    if icon_pkg is not None and not args.skip_assets:
        assets_dir = icon_pkg / "Assets"
        referenced = _collect_referenced_assets(data)
        present = (
            {p.name for p in assets_dir.iterdir()} if assets_dir.is_dir() else set()
        )
        missing = sorted(referenced - present)
        orphaned = sorted(present - referenced)
        if missing:
            print(f"INVALID: {icon_pkg} has {len(missing)} missing asset(s)")
            for name in missing:
                print(f"  Assets/{name} is referenced but not on disk")
            return 1
        if orphaned:
            # Orphans are a warning, not an error.
            print(
                f"warning: {len(orphaned)} unused asset(s) in Assets/: {', '.join(orphaned)}"
            )

    print(f"VALID: {icon_json_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
