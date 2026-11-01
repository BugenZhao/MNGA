from __future__ import annotations

import json
from pathlib import Path

import pytest

from validate_icon import main


# tests/ -> scripts -> compose-app-icon -> skills -> icon-composer -> plugins -> repo root
REPO_ROOT = Path(__file__).resolve().parents[6]
FIXTURES = REPO_ROOT / "fixtures"


@pytest.mark.parametrize(
    "name",
    [
        "simple-image",
        "variables-changed",
        "complex-icon",
        "test-generated",
        "scaled-layer",
        "version2-complex",
    ],
)
def test_fixtures_are_valid(name: str, capsys: pytest.CaptureFixture[str]) -> None:
    exit_code = main([str(FIXTURES / f"{name}.icon")])
    out = capsys.readouterr().out
    assert exit_code == 0
    assert "VALID" in out


def test_accepts_bare_icon_json(capsys: pytest.CaptureFixture[str]) -> None:
    exit_code = main([str(FIXTURES / "simple-image.icon" / "icon.json")])
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_schema_violation_reports_exit_1(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    pkg = tmp_path / "bad.icon"
    pkg.mkdir()
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "groups": [
                    {
                        "layers": [{"name": "x", "image-name": "x.png"}],
                        "shadow": {
                            "kind": "Natural",
                            "opacity": 0.5,
                        },  # UI label, not JSON
                        "translucency": {"enabled": True, "value": 0.5},
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )
    (pkg / "Assets").mkdir()
    (pkg / "Assets" / "x.png").write_bytes(b"\x89PNG\r\n\x1a\n")

    exit_code = main([str(pkg)])
    captured = capsys.readouterr().out
    assert exit_code == 1
    assert "INVALID" in captured
    assert "shadow" in captured


def _icon_with_position(tmp_path: Path, position: dict) -> Path:
    """Write a minimal valid .icon whose single layer carries the given position."""
    pkg = tmp_path / "positioned.icon"
    (pkg / "Assets").mkdir(parents=True)
    (pkg / "Assets" / "symbol.png").write_bytes(b"\x89PNG\r\n\x1a\n")
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "groups": [
                    {
                        "layers": [
                            {
                                "name": "symbol",
                                "image-name": "symbol.png",
                                "position": position,
                            }
                        ],
                        "shadow": {"kind": "neutral", "opacity": 0.5},
                        "translucency": {"enabled": True, "value": 0.5},
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )
    return pkg


def test_scale_only_position_rejected(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # Regression for #1: Icon Composer 1.5 cannot open a package whose position
    # has 'scale' but no 'translation-in-points', so the schema must reject it.
    exit_code = main([str(_icon_with_position(tmp_path, {"scale": 0.78}))])
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "INVALID" in out
    assert "translation-in-points" in out


def test_scale_with_translation_position_valid(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(
        [
            str(
                _icon_with_position(
                    tmp_path, {"scale": 0.78, "translation-in-points": [0, 0]}
                )
            )
        ]
    )
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_missing_path_exits_2(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main([str(tmp_path / "does-not-exist.icon")])
    assert exit_code == 2


def test_referenced_asset_missing_on_disk(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    pkg = tmp_path / "missing-asset.icon"
    pkg.mkdir()
    (pkg / "Assets").mkdir()
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "groups": [
                    {
                        "layers": [{"name": "x", "image-name": "missing.png"}],
                        "shadow": {"kind": "neutral", "opacity": 0.5},
                        "translucency": {"enabled": True, "value": 0.5},
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )

    exit_code = main([str(pkg)])
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "missing asset" in out
    assert "missing.png" in out


def test_skip_assets_bypasses_asset_check(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    pkg = tmp_path / "skip.icon"
    pkg.mkdir()
    (pkg / "Assets").mkdir()
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "groups": [
                    {
                        "layers": [{"name": "x", "image-name": "missing.png"}],
                        "shadow": {"kind": "neutral", "opacity": 0.5},
                        "translucency": {"enabled": True, "value": 0.5},
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )

    exit_code = main([str(pkg), "--skip-assets"])
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_orphaned_assets_emit_warning(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    pkg = tmp_path / "orphan.icon"
    pkg.mkdir()
    assets = pkg / "Assets"
    assets.mkdir()
    (assets / "used.png").write_bytes(b"\x89PNG\r\n\x1a\n")
    (assets / "unused.png").write_bytes(b"\x89PNG\r\n\x1a\n")
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "groups": [
                    {
                        "layers": [{"name": "x", "image-name": "used.png"}],
                        "shadow": {"kind": "neutral", "opacity": 0.5},
                        "translucency": {"enabled": True, "value": 0.5},
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )

    exit_code = main([str(pkg)])
    out = capsys.readouterr().out
    assert exit_code == 0
    assert "warning" in out
    assert "unused.png" in out


_LINEAR_GRADIENT = [
    "display-p3:1.00000,1.00000,1.00000,1.00000",
    "srgb:0.80000,0.88000,1.00000,1.00000",
]


def _icon_with_background_fill(tmp_path: Path, fill: dict) -> Path:
    """Write a minimal valid .icon whose top-level background carries the given fill."""
    pkg = tmp_path / "filled.icon"
    (pkg / "Assets").mkdir(parents=True)
    (pkg / "Assets" / "symbol.png").write_bytes(b"\x89PNG\r\n\x1a\n")
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "fill": fill,
                "groups": [
                    {
                        "layers": [{"name": "symbol", "image-name": "symbol.png"}],
                        "shadow": {"kind": "neutral", "opacity": 0.5},
                        "translucency": {"enabled": True, "value": 0.5},
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )
    return pkg


def test_linear_gradient_with_orientation_valid(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # Icon Composer writes an 'orientation' (start/stop points) next to a rotated
    # linear-gradient, so the schema must accept it.
    fill = {
        "linear-gradient": _LINEAR_GRADIENT,
        "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 0.7}},
    }
    exit_code = main([str(_icon_with_background_fill(tmp_path, fill))])
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_orientation_without_linear_gradient_rejected(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # 'orientation' is only meaningful alongside a linear-gradient.
    fill = {
        "solid": "srgb:0.50000,0.50000,0.50000,1.00000",
        "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 0.7}},
    }
    exit_code = main([str(_icon_with_background_fill(tmp_path, fill))])
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "INVALID" in out


# --- Icon Composer 2 ------------------------------------------------------


def _icon_with_group(tmp_path: Path, group_extra: dict, **doc_extra: object) -> Path:
    """Write a minimal .icon whose single group carries the given extra keys."""
    pkg = tmp_path / "v2.icon"
    (pkg / "Assets").mkdir(parents=True)
    (pkg / "Assets" / "symbol.png").write_bytes(b"\x89PNG\r\n\x1a\n")
    group: dict = {"layers": [{"name": "symbol", "image-name": "symbol.png"}]}
    group.update(group_extra)
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "groups": [group],
                "supported-platforms": {"squares": "shared"},
                **doc_extra,
            }
        )
    )
    return pkg


_REFRACTIVITY = {"enabled": True, "strength": 0.5, "depth": 0.6}


def test_group_without_shadow_or_translucency_valid(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # Icon Composer 2 omits 'shadow' entirely when the group specializes it,
    # so neither key may be required on a group.
    exit_code = main([str(_icon_with_group(tmp_path, {}))])
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_blur_material_valid(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main([str(_icon_with_group(tmp_path, {"blur-material": 0.5}))])
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_blur_material_out_of_range_rejected(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main([str(_icon_with_group(tmp_path, {"blur-material": 1.5}))])
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "blur-material" in out


def test_refractivity_requires_all_three_keys(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # ictool refuses a refractivity object missing 'strength' or 'depth'.
    exit_code = main(
        [
            str(
                _icon_with_group(
                    tmp_path,
                    {"refractivity": {"enabled": True}},
                    features=["refractivity"],
                )
            )
        ]
    )
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "strength" in out


def test_refractivity_requires_feature_declaration(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # Icon Composer 2 always writes features: ["refractivity"] alongside the key,
    # so that Icon Composer 1.x refuses the document instead of dropping the effect.
    exit_code = main([str(_icon_with_group(tmp_path, {"refractivity": _REFRACTIVITY}))])
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "features" in out


def test_refractivity_with_feature_valid(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(
        [
            str(
                _icon_with_group(
                    tmp_path,
                    {"refractivity": _REFRACTIVITY},
                    features=["refractivity"],
                )
            )
        ]
    )
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_unknown_feature_rejected(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main([str(_icon_with_group(tmp_path, {}, features=["translucency"]))])
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "features" in out


def test_specular_highlight_placement_requires_feature(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(
        [str(_icon_with_group(tmp_path, {"specular-highlight-placement": "inside"}))]
    )
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "features" in out


def test_specular_highlight_placement_with_feature_valid(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(
        [
            str(
                _icon_with_group(
                    tmp_path,
                    {"specular-highlight-placement": "inside"},
                    features=["specular-location"],
                )
            )
        ]
    )
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_shadow_specializations_take_whole_objects(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(
        [
            str(
                _icon_with_group(
                    tmp_path,
                    {
                        "shadow-specializations": [
                            {"value": {"kind": "neutral", "opacity": 0.5}},
                            {
                                "appearance": "dark",
                                "value": {"kind": "layer-color", "opacity": 0.4},
                            },
                        ]
                    },
                )
            )
        ]
    )
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_nested_shadow_kind_specializations_rejected(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # Icon Composer has no nested 'shadow.kind-specializations'; the whole shadow
    # object is specialized through the group's 'shadow-specializations'.
    exit_code = main(
        [
            str(
                _icon_with_group(
                    tmp_path,
                    {
                        "shadow": {
                            "kind": "neutral",
                            "opacity": 0.5,
                            "kind-specializations": [
                                {"appearance": "dark", "value": "none"}
                            ],
                        }
                    },
                )
            )
        ]
    )
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "kind-specializations" in out


def test_specialization_slot_accepts_idiom_and_localization(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(
        [
            str(
                _icon_with_group(
                    tmp_path,
                    {
                        "shadow-specializations": [
                            {
                                "idiom": "watchOS",
                                "localization": "ja",
                                "value": {"kind": "none", "opacity": 0.5},
                            }
                        ]
                    },
                )
            )
        ]
    )
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_specialization_slot_rejects_unknown_idiom(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(
        [
            str(
                _icon_with_group(
                    tmp_path,
                    {
                        "shadow-specializations": [
                            {
                                "idiom": "visionOS",
                                "value": {"kind": "none", "opacity": 0.5},
                            }
                        ]
                    },
                )
            )
        ]
    )
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "visionOS" in out


def test_asset_mirroring_is_an_object(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(
        [str(_icon_with_group(tmp_path, {"asset-mirroring": {"mirrorable": False}}))]
    )
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_named_system_color_valid(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(
        [str(_icon_with_background_fill(tmp_path, {"solid": "named:system-blue"}))]
    )
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_rgb_color_needs_four_components(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # ictool: 'Expected four comma separated color components'.
    exit_code = main(
        [str(_icon_with_background_fill(tmp_path, {"solid": "srgb:0.5,0.5,1.0"}))]
    )
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "INVALID" in out


def test_fill_keyword_valid(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    pkg = tmp_path / "keyword.icon"
    (pkg / "Assets").mkdir(parents=True)
    (pkg / "Assets" / "symbol.png").write_bytes(b"\x89PNG\r\n\x1a\n")
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "fill": "system-dark",
                "groups": [{"layers": [{"name": "s", "image-name": "symbol.png"}]}],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )
    exit_code = main([str(pkg)])
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out
