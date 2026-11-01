# Reading Build Settings

How to consume `GetTargetBuildSettings` output during a security audit, and how to assemble the audit table that Phases 2–4 of `SKILL.md` rely on.

## Schema

`GetTargetBuildSettings` returns:

```json
{ "buildSettings": [ { "macroName": "...", "evaluatedValue": "...", "value": "...", "targetValue": "..." }, ... ] }
```

Field reference:

- **`macroName`** — setting name (always present).
- **`evaluatedValue`** — fully resolved value after `$(...)` macro expansion. This is what the build actually sees. Use this for audit decisions. May be omitted when the resolved value is empty — treat its absence as an empty string.
- **`value`** — raw, unexpanded value as written in the source (often missing).
- **`targetValue`** — present only when the setting is explicitly set at the **target** level (vs. inherited from project level). Use this to detect per-target overrides.

`value` might hold the default value of the setting — read the xcconfig and pbxproj files directly to see if the value was overridden or it's just the default.

## Filter recipes

If `GetTargetBuildSettings` writes its output to a saved file due to a token limit, run `scripts/filter_build_settings.py` against that file to extract the tracked macros (security-reference macros plus `CODE_SIGN_ENTITLEMENTS`, `SDKROOT`, `SUPPORTED_PLATFORMS`). Do not read the saved file linearly.

The script lives at `scripts/filter_build_settings.py` (relative to the skill root). It derives its filter regex from `references/security-settings-reference.md` at runtime, so adding settings to the reference automatically extends the filter. Override with `--regex` if you need a narrower filter.

### Compact `name=value` view

```sh
python3 scripts/filter_build_settings.py <saved-file>
```

### With explicit target-override flag

```sh
python3 scripts/filter_build_settings.py <saved-file> --show-overrides
```

### Show only unhardened settings

```sh
python3 scripts/filter_build_settings.py <saved-file> --unhardened-only
```

The `--show-overrides` and `--unhardened-only` flags can be combined.

## The audit table

The audit table is a per-(target, tracked macro) view assembled by Phase 3 of `SKILL.md`. Phases 4–6 consume it; nothing else is re-fetched. Each target's rows physically live in that target's `Audit <target>` task description — see `SKILL.md` Phase 3 Step 4 for the on-task format.

A *tracked macro* is either:

- a **security-reference macro** (from `security-settings-reference.md`) — the build settings whose values the audit evaluates, or
- one of three additional macros — `CODE_SIGN_ENTITLEMENTS`, `SDKROOT`, `SUPPORTED_PLATFORMS` — that downstream phases read to locate the entitlements plist and decide platform eligibility.

### Columns

| Column | Meaning |
|---|---|
| `target` | the target name |
| `macroName` | the setting name — a security-reference macro or one of `CODE_SIGN_ENTITLEMENTS` / `SDKROOT` / `SUPPORTED_PLATFORMS` |
| `evaluatedValue` | what the build sees (from `GetTargetBuildSettings` JSON) |
| `setAtTargetLevel` | `yes` if `targetValue` is present in the JSON, else `no` |
| `numMatchesInXCConfigs` | count of `*.xcconfig` lines (under project-root) mentioning this macro |
| `numMatchesInPbxproj` | count of `project.pbxproj` lines mentioning this macro |
| `matchLocations` | citations from all sources, joined by `; `. Each entry is either `target` or `<source>:<file>:<line>[,<line>...]` (line numbers grouped per (source, file)). File paths are relative to `<project-root>`. |

### Construction recipe

1. **Per target.** Call `GetTargetBuildSettings`, run `scripts/filter_build_settings.py` over its output, and record `evaluatedValue` and `setAtTargetLevel` per tracked macro.
2. **Project-wide once.** Scan in two passes with the filter regex: `XcodeGrep` over `*.xcconfig`, and `grep -nE` via Bash on `<project-root>/<ProjectName>.xcodeproj/project.pbxproj` (Xcode's project description file inside the `.xcodeproj` bundle). Group hits by (source, file) and per macro count `numMatchesInXCConfigs` / `numMatchesInPbxproj`; collect the file:line citations into `matchLocations`.
3. **Join.** For each (target, tracked macro), emit one row combining the per-target columns with the project-wide counts and citations.

The filter regex comes from `references/security-settings-reference.md` (backtick-quoted macro names extracted at runtime) together with `CODE_SIGN_ENTITLEMENTS`, `SDKROOT`, and `SUPPORTED_PLATFORMS`; both the script and the project-wide grep share it, so adding a setting to the reference automatically extends both.

### Predicates

Three named predicates referenced from `SKILL.md`. They apply to the security-reference macros. The other three (`CODE_SIGN_ENTITLEMENTS`, `SDKROOT`, `SUPPORTED_PLATFORMS`) are path/identifier values, not security toggles, so the YES/NO comparisons in the predicates are not meaningful for them.

- **already hardened** ≡ `evaluatedValue ∈ {YES, YES_AGGRESSIVE, YES_ERROR}`
- **at default OFF** ≡ `evaluatedValue = NO` AND `setAtTargetLevel = no` AND `numMatchesInXCConfigs = 0` AND `numMatchesInPbxproj = 0`
- **deliberately disabled** ≡ `evaluatedValue ∉ {YES, YES_AGGRESSIVE, YES_ERROR}` AND (`setAtTargetLevel = yes` OR `numMatchesInXCConfigs > 0` OR `numMatchesInPbxproj > 0`)

## Product type

The target's product type identifier comes from `XcodeListTargets` (`PRODUCT_TYPE_IDENTIFIER`). It matches the strings used in `enhanced-security.md` ("Supported Product Types") and `universal-binaries-for-libraries.md` ("Qualifying Product Types"), so phases that classify targets by capability can compare against those lists directly.

Targets with `IS_AGGREGATE = true` have no product type and are skipped at enumeration time (see `SKILL.md` Phase 3 Step 3).
