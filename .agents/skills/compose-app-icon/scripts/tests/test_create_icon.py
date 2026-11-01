from __future__ import annotations

import argparse
import io
import json
from pathlib import Path

import pytest

from create_icon import _parse_asset, main


# tests/ -> scripts -> compose-app-icon -> skills -> icon-composer -> plugins -> repo root
REPO_ROOT = Path(__file__).resolve().parents[6]
FIXTURES = REPO_ROOT / "fixtures"
SIMPLE = FIXTURES / "simple-image.icon"
SIMPLE_ICON_JSON = SIMPLE / "icon.json"
SIMPLE_ASSET = SIMPLE / "Assets" / "video.fill.png"


# ---- _parse_asset ---------------------------------------------------------


def test_parse_asset_valid(tmp_path: Path) -> None:
    src = tmp_path / "a.png"
    src.write_bytes(b"x")
    name, resolved = _parse_asset(f"foo={src}")
    assert name == "foo"
    assert resolved == src.resolve()


def test_parse_asset_missing_equals_rejected() -> None:
    with pytest.raises(argparse.ArgumentTypeError):
        _parse_asset("no-equals")


def test_parse_asset_missing_file_rejected() -> None:
    with pytest.raises(argparse.ArgumentTypeError):
        _parse_asset("foo=/does/not/exist.png")


def test_parse_asset_empty_name_rejected(tmp_path: Path) -> None:
    src = tmp_path / "a.png"
    src.write_bytes(b"")
    with pytest.raises(argparse.ArgumentTypeError):
        _parse_asset(f"={src}")


# ---- main: happy paths ----------------------------------------------------


def test_roundtrip_from_fixture(tmp_path: Path) -> None:
    output = tmp_path / "out.icon"
    exit_code = main(
        [
            "--output",
            str(output),
            "--icon",
            str(SIMPLE_ICON_JSON),
            "--asset",
            f"video.fill.png={SIMPLE_ASSET}",
        ]
    )
    assert exit_code == 0
    assert (output / "icon.json").is_file()
    assert (output / "Assets" / "video.fill.png").is_file()

    # The written icon.json must deserialize to the same structure as the source.
    assert json.loads((output / "icon.json").read_text()) == json.loads(
        SIMPLE_ICON_JSON.read_text()
    )


def test_reads_icon_json_from_stdin(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr("sys.stdin", io.StringIO(SIMPLE_ICON_JSON.read_text()))
    exit_code = main(
        [
            "--output",
            str(tmp_path / "out.icon"),
            "--icon",
            "-",
            "--asset",
            f"video.fill.png={SIMPLE_ASSET}",
        ]
    )
    assert exit_code == 0


def test_force_overwrites_existing_output(tmp_path: Path) -> None:
    output = tmp_path / "out.icon"
    output.mkdir()
    (output / "stale.txt").write_text("stale")
    exit_code = main(
        [
            "--output",
            str(output),
            "--icon",
            str(SIMPLE_ICON_JSON),
            "--asset",
            f"video.fill.png={SIMPLE_ASSET}",
            "--force",
        ]
    )
    assert exit_code == 0
    assert not (output / "stale.txt").exists()
    assert (output / "icon.json").is_file()


# ---- main: error paths ----------------------------------------------------


def test_output_without_dot_icon_rejected(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(
        [
            "--output",
            str(tmp_path / "no-suffix"),
            "--icon",
            str(SIMPLE_ICON_JSON),
            "--asset",
            f"video.fill.png={SIMPLE_ASSET}",
        ]
    )
    assert exit_code == 2
    assert ".icon" in capsys.readouterr().err


def test_missing_asset_flag_rejected(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(
        [
            "--output",
            str(tmp_path / "out.icon"),
            "--icon",
            str(SIMPLE_ICON_JSON),
        ]
    )
    assert exit_code == 1
    assert "video.fill.png" in capsys.readouterr().err


def test_schema_violation_rejected(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    bad = tmp_path / "bad.json"
    bad.write_text(json.dumps({"groups": []}))  # missing supported-platforms
    exit_code = main(
        [
            "--output",
            str(tmp_path / "out.icon"),
            "--icon",
            str(bad),
        ]
    )
    assert exit_code == 1
    assert "schema" in capsys.readouterr().err


def test_existing_output_without_force_rejected(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    output = tmp_path / "out.icon"
    output.mkdir()
    exit_code = main(
        [
            "--output",
            str(output),
            "--icon",
            str(SIMPLE_ICON_JSON),
            "--asset",
            f"video.fill.png={SIMPLE_ASSET}",
        ]
    )
    assert exit_code == 1
    assert "--force" in capsys.readouterr().err


def test_no_validate_skips_schema_check(tmp_path: Path) -> None:
    # Document is missing 'supported-platforms' — invalid against schema.
    bad = tmp_path / "bad.json"
    bad.write_text(json.dumps({"groups": []}))
    exit_code = main(
        [
            "--output",
            str(tmp_path / "out.icon"),
            "--icon",
            str(bad),
            "--no-validate",
        ]
    )
    assert exit_code == 0


def test_creates_icon_composer_2_document(tmp_path: Path) -> None:
    # A group carrying the Icon Composer 2 Liquid Glass keys must survive
    # schema validation and land on disk verbatim.
    src = tmp_path / "symbol.png"
    src.write_bytes(b"\x89PNG\r\n\x1a\n")
    icon = tmp_path / "icon.json"
    icon.write_text(
        json.dumps(
            {
                "features": ["refractivity"],
                "groups": [
                    {
                        "blur-material": 0.5,
                        "layers": [{"name": "symbol", "image-name": "symbol.png"}],
                        "refractivity": {
                            "enabled": True,
                            "strength": 0.58,
                            "depth": 0.61,
                        },
                        "shadow-specializations": [
                            {"value": {"kind": "neutral", "opacity": 0.5}},
                            {
                                "appearance": "dark",
                                "value": {"kind": "layer-color", "opacity": 0.5},
                            },
                        ],
                        "translucency": {"enabled": True, "value": 0.5},
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )
    output = tmp_path / "v2.icon"
    exit_code = main(
        [
            "--output",
            str(output),
            "--icon",
            str(icon),
            "--asset",
            f"symbol.png={src}",
        ]
    )
    assert exit_code == 0
    written = json.loads((output / "icon.json").read_text())
    assert written["features"] == ["refractivity"]
    assert written["groups"][0]["refractivity"]["depth"] == 0.61


def test_refractivity_without_feature_declaration_rejected(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    src = tmp_path / "symbol.png"
    src.write_bytes(b"\x89PNG\r\n\x1a\n")
    icon = tmp_path / "icon.json"
    icon.write_text(
        json.dumps(
            {
                "groups": [
                    {
                        "layers": [{"name": "symbol", "image-name": "symbol.png"}],
                        "refractivity": {
                            "enabled": True,
                            "strength": 0.58,
                            "depth": 0.61,
                        },
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )
    exit_code = main(
        [
            "--output",
            str(tmp_path / "v2.icon"),
            "--icon",
            str(icon),
            "--asset",
            f"symbol.png={src}",
        ]
    )
    assert exit_code == 1
    assert "features" in capsys.readouterr().err
