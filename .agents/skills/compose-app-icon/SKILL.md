---
description: Author and validate Apple Icon Composer `.icon` packages (Icon Composer 1.x and 2.x). Use this when the user asks to generate an app icon, scaffold a `.icon` from parameters, set up light/dark/tinted appearance variants (specializations), change any field of an existing `icon.json` (fills, blend modes, shadows, translucency, Liquid Glass Mode/Specular/Blur Material/Refractivity, right-to-left asset mirroring, layer layouts, asset filenames), or validate/diagnose a `.icon` package or standalone `icon.json` against the bundled JSON Schema.
license: Apache-2.0
metadata:
    github-path: plugins/icon-composer/skills/compose-app-icon
    github-ref: refs/tags/v2.0.0
    github-repo: https://github.com/giginet/apple-icon-composer-skill
    github-tree-sha: bec45b8da61a029572fca433835d25e81676f3a0
name: compose-app-icon
---
# Apple Icon Composer `.icon` packages

A `.icon` is a directory (macOS document package) containing a declarative `icon.json` and an `Assets/` folder. This skill **authors** new packages, **edits** existing ones in place, and **validates** them against the bundled JSON Schema. All three workflows share one bundled `uv` project.

## Icon Composer 1.x vs 2.0

The schema covers both generations. Icon Composer 2.0 (Xcode 27) added Liquid Glass controls and a forward-compatibility gate; everything a 1.x document contains still validates.

| Area | Icon Composer 1.x | Icon Composer 2.0 |
|---|---|---|
| Document capability gate | — | `features: ["refractivity", "specular-location"]` |
| Group blur | `blur` | **`blur-material`** (`blur` is ignored by 2.0) |
| Refractivity | — | `refractivity: { enabled, strength, depth }` |
| Specular placement | — | `specular-highlight-placement: automatic \| inside \| outside` |
| Per-appearance shadow / translucency | nested keys | whole-object `shadow-specializations` / `translucency-specializations` |
| Specialization slot | `appearance` | `appearance` + `idiom` + `localization` |
| RTL mirroring | — | `implicit-asset-mirroring`, `asset-mirroring: { mirrorable }` |
| Group is required to carry `shadow`/`translucency` | yes | **no** — omit either when it is specialized or left at its default |

`features` is a hard gate, not a hint: Icon Composer refuses to open a document listing a feature it does not recognize ("This document uses features from a newer version of Icon Composer"). That is the point — it stops Icon Composer 1.x from silently dropping a 2.0-only effect. So **whenever a group carries any `refractivity*` key, the document must declare `features: ["refractivity"]`**, and any `specular-highlight-placement*` key requires `"specular-location"`. The bundled schema enforces both.

## Preflight: confirm `uv` is installed

Before running any commands, execute `which uv`. If it exits non-zero (no `uv` on PATH), stop and report the error to the user — this skill requires `uv`. Do not fall back to a system `python3`; the bundled `pyproject.toml` pins `requires-python = ">=3.9"` and dependency versions via `uv.lock`.

## Running the bundled CLIs

The two Python CLIs (`create_icon.py`, `validate_icon.py`), the `icon-schema.json` they validate against, and the `pyproject.toml` / `uv.lock` that pin their dependencies all live together in this skill's **`scripts/`** directory, which is a self-contained `uv` project. Run every command from inside it:

```bash
# Claude Code / Codex plugin install:
cd "${CLAUDE_PLUGIN_ROOT}/skills/compose-app-icon/scripts"
# gh skill install: cd into the scripts/ directory next to this SKILL.md instead.

uv sync                                  # once, to populate .venv from uv.lock
uv run python create_icon.py   ...       # author a new .icon
uv run python validate_icon.py ...       # validate a .icon or icon.json
```

The rest of this document shows commands as `uv run python <script>.py ...` — always run them from that `scripts/` directory.

## Creating a new `.icon`

```bash
uv run python create_icon.py \
    --output /path/to/Foo.icon \
    --icon /path/to/icon.json \
    --asset star.png=/path/to/star.png \
    --asset ring.png=/path/to/ring.png
```

Flags:

| Flag | Meaning |
|---|---|
| `--output PATH` | Target `.icon` directory (must end with `.icon`). |
| `--icon PATH` | `icon.json` document, or `-` to read the JSON from stdin. |
| `--asset NAME=PATH` | Register one image asset. Repeat for each `image-name` referenced in the document. `NAME` is the filename inside `Assets/`; `PATH` is the source file on disk. |
| `--force` | Overwrite `--output` if it already exists. |
| `--no-validate` | Skip JSON Schema validation (rarely what you want). |

`create_icon.py` validates against `icon-schema.json` before writing and checks every referenced `image-name` against the supplied `--asset` map.

## Editing an existing `.icon`

There is no `update` subcommand. Because `icon.json` is just JSON and the schema is well-defined, edit the file in place with the Edit tool and then re-validate:

1. `Read` the current `<pkg>.icon/icon.json` to see what's there.
2. Use the `Edit` tool to change exactly the field(s) the user asked about — a color string, a blend-mode enum, a `position.scale`, a specialization entry, etc. Refer to the schema sections below for allowed values.
3. If an asset image needs to change, overwrite the file in `<pkg>.icon/Assets/` (same filename → no `image-name` edit needed; new filename → update every `image-name` / `image-name-specializations.value` that referenced the old name and place the new asset in `Assets/`).
4. Re-validate the whole package so both the schema and the asset-reference cross-check pass:

    ```bash
    uv run python validate_icon.py /path/to/Foo.icon
    ```

Prefer minimal, targeted edits — keep keys in their existing order, don't reformat the file, and only add a `-specializations` array when the user actually wants a per-appearance override. The `create_icon.py` CLI's output format (`sort_keys=True`, 2-space indent) is the target style if the file is being re-written wholesale.

## Validating a `.icon` or `icon.json`

```bash
uv run python validate_icon.py /path/to/Foo.icon
# or, for a bare document:
uv run python validate_icon.py /path/to/icon.json
```

`validate_icon.py`:

1. Parses `icon.json` and checks it against `icon-schema.json` using `jsonschema` (Draft 2020-12).
2. Reports every schema violation with a JSON pointer and the validator's message.
3. When pointed at a `.icon` directory, cross-checks every `image-name` and `image-name-specializations.value` against the files in `Assets/`, reporting both missing and orphaned files.

| Flag | Meaning |
|---|---|
| _(positional)_ | Either a `.icon` directory or an `icon.json` file. |
| `--skip-assets` | Do not cross-check `image-name` references against `Assets/`. |

Exit codes: **0** = valid, **1** = schema or asset violation, **2** = bad input path.

### Reading the output

**Valid result:**

```
VALID: /path/to/Foo.icon/icon.json
```

A non-fatal warning may follow when some files in `Assets/` are not referenced by any layer:

```
warning: 2 unused asset(s) in Assets/: old-dark.png, old-light.png
```

**Schema errors** look like:

```
INVALID: /path/to/Foo.icon/icon.json (3 error(s))
  at /groups/0/layers/0
    Additional properties are not allowed ('fil' was unexpected)
  at /groups/0/shadow/kind
    'Natural' is not one of ['automatic', 'neutral', 'layer-color', 'none']
  at /groups/0/layers/1
    {'image-name-specializations': ...} is not valid under any of the given schemas
```

**Missing asset errors** look like:

```
INVALID: /path/to/Foo.icon has 1 missing asset(s)
  Assets/symbol-dark.png is referenced but not on disk
```

### Common failure patterns

Every message below is produced by `jsonschema` and maps back to a specific rule in `icon-schema.json`.

- **`Additional properties are not allowed`** — an unrecognized key (typo, wrong case, or a UI label written as JSON). First suspects: `shadow.kind` set to `"Natural"/"Chromatic"/"Off"` (use `"neutral"/"layer-color"/"none"`); a `-specialization` (singular) array (the key is always `-specializations` plural); a nested `shadow.kind-specializations` or `translucency.value-specializations` (no such thing — specialize the whole object from the group); typos like `"ligthing"`.
- **`'X' is not one of [...]`** — enum mismatch; see the enum table below.
- **`is not valid under any of the given schemas`** — a `fill`, a `color` string, or an `image-name` choice failed every `oneOf`/`anyOf` branch. A `fill` must have exactly one of `solid`/`automatic-gradient`/`linear-gradient` (or be one of the keywords `automatic`/`none`/`system-light`/`system-dark`); a color needs exactly 4 components for `srgb`/`extended-srgb`/`display-p3`, exactly 2 for `gray`/`extended-gray`, or the `named:system-*` form; a layer must contain either `image-name` (string) or `image-name-specializations` (array).
- **`'X' is a required property`** — a required field is missing: `groups` and `supported-platforms` at top level; `layers` on every group; `name` on every layer; `shadow.kind`/`shadow.opacity`, `translucency.enabled`/`translucency.value`, and all three of `refractivity.enabled`/`strength`/`depth` when the parent object is present; `features` when a group uses `refractivity` or `specular-highlight-placement`.

## Ground-truth check & rendering with `ictool` (macOS + Xcode only)

`validate_icon.py` checks the document against the JSON Schema, but the schema cannot model every constraint Icon Composer enforces at load time. When Xcode is installed, `ictool` — the command-line tool bundled inside `Icon Composer.app` — gives the authoritative answer by rendering the document the same way the app opens it, and as a bonus exports preview PNGs per platform / appearance.

This is optional and macOS-only: it is unavailable on agent hosts without Xcode, so always run `validate_icon.py` first as the portable check, then use `ictool` as a final confirmation and to produce previews when it's present.

### Locating `ictool`

`xcode-select -p` prints the active Xcode's `Developer` directory (e.g. `/Applications/Xcode.app/Contents/Developer`); `ictool` lives one level up under `Applications/Icon Composer.app`:

```bash
ICTOOL="$(dirname "$(xcode-select -p)")/Applications/Icon Composer.app/Contents/Executables/ictool"
[ -x "$ICTOOL" ] || { echo "ictool not found — Xcode 26+ with Icon Composer required"; }
"$ICTOOL" --version          # Icon Composer 2.0 → {"bundle-version": "125", "short-bundle-version": "2.0"}
```

Check `short-bundle-version` before trusting a "this opens fine" result: only Icon Composer **2.0+** understands `features`, `blur-material` and `refractivity`. A 1.5 `ictool` will reject any document declaring `features`.

### Rendering a rendition (and validating by side effect)

```bash
"$ICTOOL" /path/to/Foo.icon \
    --export-image --output-file /tmp/foo.png \
    --platform iOS --rendition Default --width 1024 --height 1024 --scale 2
```

| Flag | Meaning |
|---|---|
| `--export-image` | The only operation; renders the document to `--output-file` (PNG). |
| `--output-file PATH` | Where to write the rendered PNG. |
| `--platform` | `iOS`, `macOS`, or `watchOS`. |
| `--rendition` | `Default`, `Dark`, `TintedLight`, `TintedDark`, `ClearLight`, `ClearDark`. |
| `--width` / `--height` / `--scale` | Output size in points × scale (e.g. `1024 1024 2` → 2048×2048 px). |
| `--light-angle` | _(optional)_ lighting angle. |
| `--tint-color` / `--tint-strength` | _(optional)_ tint for the `Tinted*` renditions; each takes a single value, e.g. `--tint-color 0.25 --tint-strength 0.75`. |
| `--design-generation` | _(Icon Composer 2.0+, optional)_ `26` or `27` — render the icon the way that OS generation composites it. Use `26` to check how a 2.0 document degrades on the previous generation. |

Unknown keys are ignored silently by `ictool`, so a clean render does **not** prove every key is spelled right — that is `validate_icon.py`'s job. What `ictool` does catch is wrong *values* and wrong *shapes*: a bad `lighting`/`blend-mode` enum, an unknown `features` entry, a `refractivity` missing `strength`, a `shadow`/`translucency` missing a key, an unknown color name. Run both.

There is **no separate validate subcommand** — validation is a side effect of rendering:

- **Success** → exit `0`, prints `{}`, and writes the PNG. Icon Composer can open the document.
- **Failure** → non-zero exit and `The data couldn't be read because it is missing.` (or a more specific message). Icon Composer would refuse to open it, even if `validate_icon.py` said `VALID`.

So after authoring or editing, render the `Default` rendition (and `Dark` / a `Tinted*` one if the icon uses specializations) to confirm the package actually opens and to eyeball the result. This is exactly what catches engine-level issues the schema can't — for example a `position` with `scale` but no `translation-in-points`, which renders fine only once both keys are present.

## Canvas and asset sizing

Icon Composer's design canvas is **1024 × 1024 points**. Image assets should be 1024 × 1024 PNG (or SVG) with the visible content centered; `position.translation-in-points` operates in this 1024-point coordinate system, so `[0, 0]` means no offset from the canvas center. Smaller assets render at their native size and look visually smaller than the canvas.

## `icon.json` — top-level shape

```jsonc
{
  "features": ["refractivity"],                           // IC2: required when a group uses the matching keys
  "color-space-for-untagged-svg-colors": "display-p3",   // optional: "srgb" | "display-p3"
  "fill": { ... },                                        // OR fill-specializations (background)
  "fill-specializations": [ ... ],                        // per-slot background fill
  "implicit-asset-mirroring": true,                       // IC2: mirror assets for RTL languages
  "languages": ["ja", "ar"],                              // IC2: locale IDs with localized assets
  "groups": [ ... ],                                      // REQUIRED: ordered layer groups
  "supported-platforms": { "squares": "shared" }          // REQUIRED
}
```

### Groups — one record per Liquid Glass-rendered bundle

A group shares the same Liquid Glass rendering pipeline across its layers. `layers` is the only required key; every other key below has an optional sibling `<key>-specializations`.

| JSON key | Type | UI label | Notes |
|---|---|---|---|
| `layers` | array | — | **Required**, at least one layer. |
| `name` | string | — | Display name of the group. |
| `lighting` | `"individual"` \| `"combined"` | **Mode** | How light interacts per-layer or across the group. |
| `specular` | boolean | **Specular** | Highlight on/off. |
| `specular-highlight-placement` | `"automatic"` \| `"inside"` \| `"outside"` | **Specular Outside** | **IC2.** Needs `"specular-location"` in `features`. |
| `blur-material` | number 0–1 | **Blur Material** | **IC2**, default `0.5`. Replaces the 1.x `blur`, which 2.0 ignores. |
| `refractivity` | `{ enabled: bool, strength: number, depth: number }` | **Refractivity** | **IC2.** All three keys required. Needs `"refractivity"` in `features`. |
| `translucency` | `{ enabled: bool, value: number }` | Translucency | Both keys required when present. |
| `shadow` | `{ kind: string, opacity: number }` | Shadow | Both keys required when present. See the UI ↔ JSON table below. |
| `blend-mode` | string | Color | Same enum as layers. |
| `opacity` | number 0–1 | Color | |
| `hidden` | boolean | Composition.Visible | Hides the whole group. |
| `asset-mirroring` | `{ mirrorable: bool }` | **In Right to Left** | **IC2.** Opt this group's assets in or out of RTL mirroring. |
| `position` | `{ scale: number, translation-in-points: [x, y] }` | Composition.Layout | Omit when identity; otherwise include **both** keys (see gotchas). |

Icon Composer 2 also still reads the flat `refractivity-strength` / `refractivity-depth` (and their `-specializations`), but writes the nested `refractivity` object — prefer the object.

### Layers — image-backed records inside a group

| JSON key | Type | Category | Notes |
|---|---|---|---|
| `name` | string | — | **Required** display name. |
| `image-name` | string | Composition.Layout | Filename in `Assets/`. Required unless `image-name-specializations` is present. |
| `image-name-specializations` | array | Composition.Layout | Per-slot filenames. |
| `fill` | fill | Color | See Fill below. |
| `fill-specializations` | array | Color | |
| `blend-mode` | string | Color | Enum: `normal, darken, multiply, plus-darker, lighten, screen, plus-lighter, overlay, soft-light, hard-light`. |
| `blend-mode-specializations` | array | Color | |
| `opacity` | number 0–1 | Color | |
| `opacity-specializations` | array | Color | |
| `glass` | boolean | Effects | Liquid Glass on/off for this layer (not the same as group-level `specular`). |
| `glass-specializations` | array | Effects | |
| `hidden` | boolean | Composition.Visible | |
| `hidden-specializations` | array | Composition.Visible | |
| `position` | position object | Composition.Layout | |
| `position-specializations` | array | Composition.Layout | |
| `asset-mirroring` | `{ mirrorable: bool }` | **In Right to Left** | **IC2.** |
| `asset-mirroring-specializations` | array | — | **IC2.** |

### Fill — object shapes and keywords

```jsonc
{ "solid":              "extended-srgb:1.0,1.0,1.0,1.0" }
{ "automatic-gradient": "extended-srgb:0.0,0.5,1.0,1.0" }
{ "linear-gradient":   ["extended-srgb:...", "extended-srgb:..."] }
```

A fill may also be a bare keyword string instead of an object:

| Keyword | Meaning |
|---|---|
| `"automatic"` | Inherit the value being specialized. |
| `"none"` | Paint nothing. |
| `"system-light"` / `"system-dark"` | Apple's standard light / dark background. |

Color strings are `<colorspace>:<components>` or `named:<system color>`:

| Form | Components | Example |
|---|---|---|
| `extended-srgb`, `srgb`, `display-p3` | exactly 4 (r,g,b,a) | `display-p3:1.00000,0.18845,0.18108,1.00000` |
| `gray`, `extended-gray` | exactly 2 (white,alpha) | `extended-gray:1.00000,1.00000` |
| `named:` | — | `named:system-blue` |

Named colors are `system-` plus `red, green, blue, orange, yellow, brown, pink, purple, gray, teal, indigo, mint, cyan`. A wrong component count or an unknown color name makes Icon Composer refuse the document (`Expected four comma separated color components`, `Unknown color name:`).

A `linear-gradient` may carry an optional sibling `orientation` — the gradient's direction as normalized start/stop points (0–1 on each axis). Icon Composer writes it when you rotate a gradient; it is only valid alongside `linear-gradient`. Omit it for the default direction.

```jsonc
{ "linear-gradient": ["display-p3:1,1,1,1", "srgb:0.81,0.88,1,1"],
  "orientation": { "start": { "x": 0.5, "y": 0 }, "stop": { "x": 0.5, "y": 0.7 } } }
```

## Specializations — per-slot overrides

Any specializable property `X` has an optional sibling array `X-specializations`. Each entry is a **slot** plus a `value`:

```jsonc
"fill-specializations": [
  { "value": { "automatic-gradient": "extended-srgb:0,0.53,1,1" } }, // no slot keys = applies everywhere
  { "appearance": "dark",   "value": { "linear-gradient": [ "...", "..." ] } },
  { "appearance": "tinted", "value": "automatic" },                   // inherit the base value
  { "idiom": "watchOS", "localization": "ar", "value": { "solid": "named:system-teal" } }
]
```

Slot keys — omit a key to mean "applies to all":

| Key | Values |
|---|---|
| `appearance` | `base` (what the others inherit from), `light`, `dark`, `tinted` |
| `idiom` | **IC2.** `square`, `iOS`, `macOS`, `watchOS` |
| `localization` | **IC2.** A locale ID such as `ja` or `ar` |

**`"automatic"` is a `fill` keyword, not a universal sentinel.** Every other specialization's `value` must be the property's own type — `"automatic"` in an `opacity-specializations`, `hidden-specializations`, `blend-mode-specializations` or `position-specializations` entry makes Icon Composer refuse the document.

Specializations exist for exactly these properties:

- **Color** (layer & group): `fill`, `blend-mode`, `opacity`
- **Liquid Glass** (group): `lighting`, `specular`, `specular-highlight-placement`, `blur-material`, `refractivity`, `translucency`, `shadow`
- **Effects** (layer): `glass`
- **Composition.Visible** (layer & group): `hidden`
- **Composition.Layout** (layer & group): `image-name`, `position`
- **Mirroring** (layer & group): `asset-mirroring`

`shadow`, `translucency` and `refractivity` are specialized **as whole objects** — there is no nested `shadow.kind-specializations` or `translucency.value-specializations`. When a group specializes its shadow, Icon Composer 2 writes only `shadow-specializations` and drops the plain `shadow` key:

```jsonc
"shadow-specializations": [
  { "value": { "kind": "neutral", "opacity": 0.5 } },
  { "appearance": "light", "value": { "kind": "layer-color", "opacity": 0.5 } }
]
```

## UI ↔ JSON label mapping

Several Icon Composer UI labels differ from the JSON keys they write.

| UI | JSON |
|---|---|
| Shadow: **Natural** | `shadow.kind: "neutral"` |
| Shadow: **Chromatic** | `shadow.kind: "layer-color"` |
| Shadow: **Off** | `shadow.kind: "none"` |
| Blend Mode: **Plus Darker** | `"plus-darker"` |
| Blend Mode: **Plus Lighter** | `"plus-lighter"` |
| Blend Mode: **Soft / Hard Light** | `"soft-light"` / `"hard-light"` |
| Liquid Glass: **Mode** | `lighting` |
| Liquid Glass: **Blur Material** | `blur-material` |
| Liquid Glass: **Refractivity** (Strength / Depth) | `refractivity.enabled` / `.strength` / `.depth` |
| Liquid Glass: **Specular Outside** | `specular-highlight-placement: "outside"` |
| **Mirror Assets in Right to Left** | `implicit-asset-mirroring` |
| **In Right to Left** (per layer/group) | `asset-mirroring.mirrorable` |

Blend modes are otherwise the UI label lower-cased and kebab-cased. `shadow.kind` also accepts `"automatic"` (inherit).

## Minimal example

```bash
# Compose the icon document
cat > /tmp/icon.json <<'JSON'
{
  "fill": { "automatic-gradient": "extended-srgb:0.20,0.50,1.00,1.00" },
  "groups": [{
    "layers": [
      { "name": "symbol", "image-name": "symbol.png", "glass": true }
    ],
    "shadow": { "kind": "neutral", "opacity": 0.5 },
    "translucency": { "enabled": true, "value": 0.5 }
  }],
  "supported-platforms": { "squares": "shared" }
}
JSON

uv run python create_icon.py \
    --output /tmp/Hello.icon \
    --icon /tmp/icon.json \
    --asset symbol.png=/path/to/symbol-1024.png
```

## Icon Composer 2 Liquid Glass example

A group using the 2.0 controls. Note the `features` declaration, the absence of a plain `shadow` key (it is fully specialized), and `blur-material` rather than `blur`:

```jsonc
{
  "features": ["refractivity"],
  "groups": [{
    "blur-material": 0.5,
    "lighting": "individual",
    "layers": [ { "name": "symbol", "image-name": "symbol.png", "glass": true } ],
    "refractivity": { "enabled": true, "strength": 0.577, "depth": 0.611 },
    "shadow-specializations": [
      { "value": { "kind": "neutral", "opacity": 0.5 } },
      { "appearance": "light", "value": { "kind": "layer-color", "opacity": 0.5 } }
    ],
    "translucency": { "enabled": true, "value": 0.5 }
  }],
  "supported-platforms": { "squares": "shared" }
}
```

`fixtures/version2-complex.icon` in this repository is a full Icon Composer 2 document saved by the app — use it as the reference for what 2.0 actually writes.

## Dark-mode specialization example

```jsonc
// icon.json snippet: same layer, ring is cream in light, gradient in dark
{
  "name": "ring",
  "image-name": "ring.png",
  "fill-specializations": [
    { "value": { "solid": "extended-srgb:1.00,0.95,0.70,1.00" } },
    { "appearance": "dark",
      "value": { "linear-gradient": [
        "extended-srgb:0.95,0.30,0.60,1",
        "extended-srgb:0.40,0.20,0.80,1"
      ] } }
  ]
}
```

## Shortcut: list every asset referenced by a document

```bash
jq -r '
  [
    .groups[].layers[]
    | (."image-name"? // empty),
      (."image-name-specializations"? // [] | .[] | .value)
  ]
  | unique[]
' /path/to/icon.json
```

Use this to build the `--asset` flags for `create_icon.py` when retrofitting an existing document.

## Gotchas

- Use JSON values, not UI labels (`"neutral"` not `"Natural"`, `"layer-color"` not `"Chromatic"`).
- Declare `features` whenever you write an Icon Composer 2-only key: `refractivity*` needs `"refractivity"`, `specular-highlight-placement*` needs `"specular-location"`. Never invent a feature name — an unknown one makes *every* version of Icon Composer refuse the document.
- Write `blur-material`, not `blur`. Icon Composer 2 silently ignores `blur`, so a value set there is lost on the next save.
- `refractivity` is all-or-nothing: `enabled`, `strength` **and** `depth` must all be present, or Icon Composer reports `The data couldn't be read because it is missing.` The same applies to `shadow` (`kind` + `opacity`) and `translucency` (`enabled` + `value`).
- Do not add `-specializations` inside `shadow`, `translucency` or `refractivity`. Specialize the whole object from the group (`shadow-specializations`), and drop the plain key when you do.
- `"automatic"` is only a `fill` value. In a boolean, number, enum or position specialization it is a decode error.
- A `position` object must carry **both** `scale` and `translation-in-points`. A scale-only `position` validates against older schemas but Icon Composer 1.5 refuses to open the package (`The document … could not be opened. The data is missing.`); always pair `scale` with `translation-in-points` (use `[0, 0]` when there is no offset).
- Do not emit `position` blocks with identity values (`scale: 1`, `translation-in-points: [0, 0]`) — Icon Composer's own save output omits them. Omit the whole object rather than writing a partial one.
- On a single layer, use either `fill` _or_ `fill-specializations`, not both. The same pattern holds for the other `X`/`X-specializations` pairs: put a no-`appearance` entry in the specializations array for the light case.
- Every `image-name` (and every `image-name-specializations.value`) must map to a file in `Assets/` (supplied via `--asset` when creating).
- Icon Composer fails fast on the first unknown value, so re-validate after fixing each error. The schema does not check image dimensions, but Icon Composer is designed around 1024 × 1024 point assets.
