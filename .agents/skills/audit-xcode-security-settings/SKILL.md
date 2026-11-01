---
description: |
  Audit and enable security-oriented Xcode build settings. Progressively enables compiler warnings, static analyzer checkers, and Enhanced Security features. Use when: user wants to secure their Xcode project, audit security settings, enable hardening, review security posture of build configuration, set up security-focused static analysis, enable static analysis, improve warning coverage, harden diagnostics, or catch more bugs at compile time in C/C++/Objective-C/Swift. SKIP: network security (TLS/ATS), code signing, privacy APIs.
name: audit-xcode-security-settings
---
# Audit Xcode Security Settings

Assess an Xcode project's security posture and progressively enable security build settings and entitlements — from broadly applicable warnings through Enhanced Security hardening.

## Tool Preferences

When XcodeGlob, XcodeGrep, XcodeRead, XcodeLS, and XcodeUpdate tools are available, ALWAYS use them. Do not fall back to Bash filesystem tools (`ls`, `find`, `cat`, `grep`) to learn about the project. They trigger extra permission prompts and bypass project scoping.

**Tool names may carry an MCP server prefix.** These tools are hosted by an MCP server whose name varies by environment (`xcode-mcp`, `xcode-tools`, `xcode`, etc.), so their fully qualified names look like `mcp__<server>__XcodeGlob`. Some harnesses register short aliases (just `XcodeGlob`); others only expose the prefixed form. Do not hardcode a specific server name. On the first call, use whichever form the available-tool registry advertises — look up the prefix once, then reuse it for the rest of the session. If a short-name call fails with an unknown-tool error, do not guess at the prefix: look it up in the registry and retry with the full name.

- **XcodeGlob** for file discovery — `find` is forbidden for files inside the project.
- **XcodeGrep** for content search — `grep`/`rg` is forbidden for files inside the project.
- **XcodeRead** for file contents — `cat`/`Read` is forbidden for files registered in the project.
- **XcodeLS** for directory listing — `ls` is forbidden for any path inside the project.
- **XcodeUpdate** for in-place edits of project-registered text files (xcconfig files, source files) — same `filePath` / `oldString` / `newString` (+ optional `replaceAll`) signature as the built-in `Edit` tool, but accepts Xcode workspace-relative paths. `Edit` is forbidden for files registered in the project. **Do not** use `XcodeUpdate` / `Edit` / `plutil` to add or update `.entitlements` keys — use `AddEntitlement`.
- **AddEntitlement** for adding or updating a target's entitlements — pass `targetName`, `entitlementKey`, `entitlementValueType` (`bool` / `string` / `int` / `stringArray` / `dictionary`), and the value. Always prefer it for entitlement changes; it adds or updates only and cannot remove keys.
- **XcodeListTargets** for enumerating targets — do not parse `project.pbxproj` manually. Returns each target's `PRODUCT_TYPE_IDENTIFIER` and role flags (`IS_AGGREGATE`, `IS_TEST_TARGET`, `IS_APP_EXTENSION`, `SUPPORTS_HOSTING_TESTS`) directly.

**Project root and name are already in the system prompt context.** Do NOT run `ls` to "verify" the project layout before starting. The system prompt already tells you the working directory and the project structure.

**Empty XcodeGlob results are not a failure.** The `.xcodeproj` and `.xcworkspace` are not indexed as files inside the Xcode workspace — `XcodeGlob "**/*.xcodeproj"` correctly returns 0 matches. Use the project name from system-prompt context instead. Do not fall back to filesystem `ls`/`find`.

**All `Xcode*` tools take Xcode workspace-relative paths.** `XcodeGlob`, `XcodeGrep`, `XcodeRead`, `XcodeLS`, `XcodeUpdate`, `XcodeWrite`, and `XcodeRM` interpret their path arguments — and return paths — relative to the Xcode workspace root (what you see at the top of the Project Navigator). Not the git repository root; not the `.xcodeproj` bundle. Anything the user sees in Xcode (entitlements, xcconfig, plan and decision documents, source files) is reachable via its workspace-relative path; pass that path through these tools as-is, and don't construct absolute filesystem paths for it.

To read or edit a specific file:
- Prefer `XcodeRead` / `XcodeUpdate` with the workspace-relative path. `XcodeRead` reads `.entitlements` plists too — they're project-registered files, navigable just like any source file — so read them this way. To add or update an entitlement, use `AddEntitlement`, not `XcodeUpdate`.

**For entitlements files, never derive the path by hand.** Each target's authoritative entitlements path is the evaluated value of its `CODE_SIGN_ENTITLEMENTS` build setting — get it from `GetTargetBuildSettings` and use it as-is. Do not parse `project.pbxproj` to reconstruct the path, and do not glob `**/*.entitlements`: orphaned `.entitlements` files may exist on disk that aren't referenced by any target. One entitlements file can be referenced by multiple targets.

Fall back to Bash only for operations the Xcode tools cannot do (e.g., git operations).

## Bundled Reference Documents

All reference material lives under `references/` next to this file.

- `references/security-settings-reference.md` — the canonical list of security build settings and entitlements this skill tracks, with hardened values, CLI flags, and language scope.
- `references/reading-build-settings.md` — `GetTargetBuildSettings` schema, the filter script recipe, the audit-table construction, and the "already hardened" / "deliberately disabled" predicates.
- `references/enhanced-security.md` — the Enhanced Security capability: build settings, entitlements, supported product types.
- `references/pointer-authentication.md` — arm64e pointer signing: supported platforms, consumer-side compatibility notes.
- `references/universal-binaries-for-libraries.md` — universal-binary guidance for library/framework targets (pointer authentication adds the `arm64e` slice automatically), qualifying product types, XCFramework guidance.
- `references/security-compiler-warnings.md` — the security-focused compiler warnings and settings enabled by Enhanced Security.
- `references/cpp-hardening.md` — C++ stdlib hardening (`CLANG_CXX_STANDARD_LIBRARY_HARDENING`) and bounds-safe buffers (`ENABLE_CPLUSPLUS_BOUNDS_SAFE_BUFFERS`).
- `references/typed-allocators.md` — type-aware allocator support and the `hardened-heap` sub-option.
- `references/stack-zero-init.md` — automatic stack-variable zero-initialization at runtime.
- `references/readonly-platform-memory.md` — read-only protection of dyld state.
- `references/runtime-restrictions.md` — dylib and Mach-message platform restrictions.
- `references/hardware-memory-tagging.md` — MTE entitlements and supported hardware.
- `references/checked-pointer-arithmetic.md` — Checked Pointer Arithmetic (CPA2).
- `references/additional-settings.md` — opt-in diagnostic settings beyond the defaults (may have more false positives).
- `references/adoption-strategy.md` — recommended ordering for validating Enhanced Security features (lowest-risk to highest-effort).
- `references/decision-document.md` — how to maintain the persistent `xcode-security-settings.md` decision document.

The skill ships one helper script:

- `scripts/filter_build_settings.py` — filters `GetTargetBuildSettings` JSON to the macros tracked in `security-settings-reference.md`. See `references/reading-build-settings.md` for usage.

### Common Failure Modes

| Symptom | Cause | Correct Response |
|---|---|---|
| Tool call fails with "unknown tool" / "tool not found" for `XcodeGlob` etc. | The harness registers these tools only under their full MCP-prefixed name (`mcp__<server>__XcodeGlob`) in this environment | Look up the prefix in the available-tool registry, retry once with the full name, then use the full name for the rest of the session. |
| `XcodeGlob "**/*.xcodeproj"` returns 0 matches | The `.xcodeproj` itself isn't a project-indexed file | Use the project name from system context; do not fall back to `find` or `ls` |
| `XcodeRead <workspace-relative-path>` fails for a file truly inside the `.xcodeproj` / `.xcworkspace` bundle (e.g. `WorkspaceSettings.xcsettings`) | That file isn't a project-navigator member | Translate to filesystem absolute path using the project root from system context, then use `Read` / `Edit`. (Does not apply to `.entitlements` files — those are navigable.) |
| `Read` on an entitlements path you derived by hand returns *File does not exist* | The path was reconstructed from `project.pbxproj` group nesting or guessed by globbing `**/*.entitlements`. Xcode's authoritative path for a target's entitlements is the evaluated value of `CODE_SIGN_ENTITLEMENTS`, not whatever the navigator shows. | Look up `CODE_SIGN_ENTITLEMENTS` for the target via `GetTargetBuildSettings` (or read it from the audit table) and use its evaluated value as the path. |

## Workflow

## Phase 1: Briefing

Before doing any work, tell the user — in two or three sentences — what this skill is, what it will do, and roughly how much of their time and attention to expect:

- **What it is.** An audit of the project's Xcode security build settings and entitlements (compiler warnings, Enhanced Security entitlements, pointer authentication, checked pointer arithmetic, universal binaries for libraries, etc.).
- **What happens.** The skill runs in two parts of roughly equal length. First, **planning**: I analyze the project and write an editable plan file at the project root for you to review. Then, **execution**: once you pick Run, I apply only the changes you approved. Nothing is modified until you pick Run.
- **Time commitment.** *Planning* is a few minutes of my analysis (longer on projects with many targets — I'll narrate progress) plus your review of the plan file, which can be quick or thorough — your call. *Execution* takes about as long: applying the approved changes, with two things that can pause for your input — the inquiry step (if there are deliberately-disabled settings whose rationale isn't documented), and a final yes/no on whether to keep the plan file in your project as a record.
This all usually takes about 15-30 minutes, split roughly evenly between the two parts, depending on the number of build targets and how long it takes for you to review and approve the plan.

Keep it tight — the user already invoked the skill knowing they wanted an audit.
The briefing exists so they have realistic expectations.

**Then check for source control.** The project has **source control** if either:

- The Environment block's `Is a git repository` field is `true`, or
- A single filesystem check at the project root finds any of `.git`, `.hg`, `.svn`, `.bzr`, `.fslckout`, `_FOSSIL_`, `CVS`.

Otherwise the project has **no source control**. Record this state — Phase 4 Step 3 uses it to decide whether to include the ⚠️ blockquote in the plan file.

After delivering the briefing, pause via `AskUserQuestion`. If the project has source control:

- **Begin audit** — proceed to Phase 2.
- **Cancel** — exit with "Cancelled — no changes applied."

If the project has **no source control**, tell the user first: *"It is strongly recommended setting up source control before continuing. This skill modifies build settings and entitlements; without something like Git, rollback requires manual undo and you won't have a clean way to review the differences. Xcode has built-in support for [Source control management](doc://com.apple.documentation/documentation/xcode/source-control-management)"* Then ask:

- **Set up source control first (Recommended)** — exit with "[Set up source control](doc://com.apple.documentation/documentation/xcode/configuring-your-xcode-project-to-use-source-control) and re-run the skill."
- **Proceed without source control** — proceed to Phase 2; Phase 4 Step 3 will surface the no-source-control reminder again in the plan file.
- **Cancel** — exit with "Cancelled — no changes applied."

The pause exists so the briefing stays on screen long enough to read; Discovery and Analysis output would otherwise scroll it away. Failing early when there's no source control avoids spending minutes on discovery and analysis only for the user to bail at plan-approval time.

## Phase 2: Discovery

Read the Environment block in the system prompt. Relevant fields:
- `Primary working directory` — the project root (the project name is the basename).
- `Is a git repository` — whether the project is git-tracked (used by the source-control check in Phase 1).

## Track Progress

Every per-target / per-setting action that needs to happen must have its own task for transparency.

- Phase 1 (Briefing) is one task that completes when the user picks Begin audit / Cancel.
- Phase 3 creates one task per target (`Audit <target>`); the task closes once Phase 3 has produced both the per-target audit-table rows and (for supported product types) the Enhanced-Security category for that target. Phase 3 stores all per-target state in the task's `description` field (see Phase 3 Step 4 for the format) so later phases can read it back via `TaskGet`. Phases 4–7 read these task descriptions.
- Phase 4 (Plan & Approve) is one task that completes when the user picks Run/Cancel.
- On Run, Phase 4 step 5 parses the plan and creates fine-grained tasks. For each apply task it embeds that target's delta (extracted from the corresponding `Audit <target>` task's description) into the apply task's own `description` so Phase 5 doesn't have to look it up again.
  - For each **Enhanced Security** sub-item that's checked:
    - **Enable Enhanced Security**: `Enable Enhanced Security at project level` (one task). On pbxproj-only projects, this task encapsulates the guide-and-verify flow described in Phase 5 Step 1a.
    - **Update entitlements**: one `Apply Enhanced Security entitlements to <target>` per target needing changes.
    - **Hardware memory tagging**: `Apply Hardware Memory Tagging` (one task; walks supported targets internally).
    - **Checked pointer arithmetic**: `Apply Checked Pointer Arithmetic` (one task; walks supported targets internally).
  - For each **Warnings** sub-item that's checked:
    - `Apply Compiler Warnings` if that sub-item is checked.
    - `Apply Static Analyzer Warnings` if that sub-item is checked.
    - `Apply Clang-Tidy Warnings` if that sub-item is checked.
  - `Apply Additional Diagnostic Settings` if checked.
  - `Emit Bounds Safety Adoption guidance` if checked.
  - One `Inquire about <MACRO> on <target>` per Phase-6 candidate (only if "Inquire about disabled settings" is checked).
  - `Report and update decision document`.
  - `Prompt to remove plan file` — always last; also fires on error paths.

When entering each phase or sub-step:
- Print one line naming the phase or sub-step in plain English — never the phase number. Use the phase's name (e.g., "▶ Briefing", "▶ Analyzing project", "▶ Plan & Approve", "▶ Applying settings"); for sub-steps, name what's being done (e.g., "▶ Detecting languages", "▶ Building the audit table").
- Update the task to `in_progress`.

When finishing each phase or sub-step:
- Print one line: "✓ <same label>" with a brief outcome if applicable (e.g., "✓ Detecting languages: C and Swift found.").
- Update the task to `completed`.

Apply steps may record what they did in their own task's `description` before completing it, one line per target. Phase 7 reads those lines instead of re-deriving state or scraping earlier output.

### Phase 3: Analyze Project and Settings

No user interaction. Gather facts in the background.

#### Step 1: Locate the existing decision document

`XcodeGlob '**/xcode-security-settings.md'`. If found, `XcodeRead` it and extract languages + prior setting decisions with their statuses and rationale. This informs subsequent phases.

#### Step 2: Detect languages

One `XcodeGlob` per language. Empty result is not a failure — record the language as absent.

- `**/*.c` → C
- `**/*.cpp`, `**/*.cxx`, `**/*.cc` → C++
- `**/*.m` → Objective-C
- `**/*.mm` → Objective-C++
- `**/*.swift` → Swift

**Objective-C++ implies C++ is present.** `.mm` files contain C++ source, so any audit gated on "C++ present" (C++ stdlib hardening, bounds-safe-buffers guidance, `CLANG_ANALYZER_OSOBJECT_C_STYLE_CAST`, etc.) must fire when Objective-C++ is detected, even when no `.cpp`/`.cxx`/`.cc` files exist.

**Filename extension is not authoritative.** An Xcode project can override a file's compiled language via `explicitFileType` / `lastKnownFileType` in `project.pbxproj` — most commonly a `.m` file marked `sourcecode.cpp.objcpp` (compiled as Objective-C++), or a `.h` marked `sourcecode.c.h` / `sourcecode.cpp.h`. To catch these overrides, `grep -E 'sourcecode\.cpp\.[a-zA-Z0-9]+' <project-root>/<ProjectName>.xcodeproj/project.pbxproj` via Bash. `project.pbxproj` is Xcode's project description file inside the `.xcodeproj` bundle; read it directly. Treat any `sourcecode.cpp.objcpp` match as both Objective-C++ and C++; treat any other `sourcecode.cpp.*` match as C++.

#### Step 3: Build the audit table

See `references/reading-build-settings.md` for column definitions, the construction recipe, and the canonical predicates ("already hardened", "at default OFF", "deliberately disabled"). At a glance:

1. Call `XcodeListTargets` to enumerate targets. Skip entries with `IS_AGGREGATE = true` (they have no product type). Record `TARGET_NAME`, `CONTAINING_PROJECT`, and `PRODUCT_TYPE_IDENTIFIER` for each remaining target — Step 4 categorizes targets by `PRODUCT_TYPE_IDENTIFIER` directly (no inference).
2. For each target: `TaskCreate "Audit <target>"`, set in_progress. Call `GetTargetBuildSettings`, run `scripts/filter_build_settings.py` over the resulting JSON, and record `evaluatedValue` and `setAtTargetLevel` (`yes` if `targetValue` is present in the JSON) per tracked macro. Hold these rows ready to write into the task's `description` in Step 4 (along with the category). Leave the task in_progress — Step 4 closes it.
3. Scan for explicit settings in two passes with the filter regex: `XcodeGrep` over `*.xcconfig`, and `grep -nE '<filter regex>' <project-root>/<ProjectName>.xcodeproj/project.pbxproj` via Bash. `project.pbxproj` is Xcode's project description file inside the `.xcodeproj` bundle; read it directly. Record per-macro `numMatchesInXCConfigs`, `numMatchesInPbxproj`, and the file:line citations.
4. The audit table is the joined view: one row per (target, tracked macro). Phases 4, 5, and 6 all consume this table; nothing else is re-fetched.

This step scales with target count: each `GetTargetBuildSettings` call takes several seconds, and there is one per target. On projects with roughly ten or more targets it can take a few minutes.

#### Step 4: Per-target Enhanced-Security state

Route each target into one of three categories by the `PRODUCT_TYPE_IDENTIFIER` recorded in Step 3:

- **Entitlements-supported** — product type is in the "Supported Product Types" list of `references/enhanced-security.md` (applications, XPC services, system extensions, driver extensions [build settings only], tools). Read the entitlements plist at the path stored in this target's `CODE_SIGN_ENTITLEMENTS` build setting and classify the target as **Up-to-date**, **Partial**, **Off**, or **No-entitlements-file**. Multiple targets can share the same `CODE_SIGN_ENTITLEMENTS` path; classify each target independently.
- **Library/framework** — product type is in the qualifying set listed in `references/universal-binaries-for-libraries.md` (frameworks, static frameworks, static libraries, dynamic libraries). No entitlements read. Phase 5 will check the universal-binary configuration for these.
- **Skipped** — anything else (test bundles, app extensions, etc.).

Now write everything Phase 3 has learned about this target into the `Audit <target>` task's `description` via `TaskUpdate`, then set it `completed`. The description holds the entire per-target state Phases 4–6 need to consult later. Format:

```
Category: <category> [/ <sub-state>]      # e.g. "Entitlements-supported / Partial", "Library/framework", "Skipped"
Entitlements path: <evaluated CODE_SIGN_ENTITLEMENTS>     # omit for Library/framework and Skipped
SDKROOT: <value>
SUPPORTED_PLATFORMS: <value>
Missing entitlements: <comma-separated short names>      # Entitlements-supported only; required and default-ON keys the target lacks; omit if empty
Checked pointer arithmetic: <eligible-entitlement | eligible-slice-only | enabled | not-eligible: <reason>>   # Entitlements-supported and Library/framework targets
Deliberately-disabled: <MACRO>=<value> (<source>[+<source>...]), ...   # one per disabled row; sources ⊆ {target-level, xcconfig, pbxproj} joined with '+' when more than one applies; omit the line entirely if none

Audit table:
  <MACRO>=<value> setAtTargetLevel=<yes|no> numMatchesInXCConfigs=<n> numMatchesInPbxproj=<n> matchLocations=<citations>
  ...
```

The Category line is first so any client that surfaces a snippet shows something meaningful. The Audit-table block is the per-(target, tracked macro) rows from Step 3 in `key=value` form — one line per tracked macro, using the canonical column names defined in `references/reading-build-settings.md`. `matchLocations` carries the file:line citations in the same `<source>:<file>:<line>[,<line>...]` format used throughout. **Skipped** targets get this Category line, the platform fields, and the Audit-table block. **Library/framework** targets get those three plus the `Checked pointer arithmetic:` line. Both complete immediately (no entitlements read).

**`Checked pointer arithmetic` is the single source of truth for this feature.** Compute it once, here, and record one of four values. Every later phase reads this line and applies no test of its own.

- `enabled` — nothing to do for this target. For an Entitlements-supported target: the entitlements file carries `com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow` and the evaluated `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE` is `YES`. For a Library/framework target: the evaluated `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE` is `YES` — there is no entitlement to check.
- `not-eligible: <reason>` — one of: `platform`, when `SUPPORTED_PLATFORMS` / `SDKROOT` matches neither `iphoneos` nor `watchos`; `opted out`, when `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE` is `deliberately disabled` for the target; `no arm64e`, when `ENABLE_POINTER_AUTHENTICATION` is `deliberately disabled`; or `outside the capability`, when `ENABLE_ENHANCED_SECURITY` is `deliberately disabled`. A macro that is merely `at default OFF` is not a reason — enabling Enhanced Security lifts it. `outside the capability` applies to Entitlements-supported targets only: the capability supplies the entitlement, and a library takes none.
- `eligible-entitlement` — an Entitlements-supported target that can take checked pointer arithmetic and is not yet fully configured for it: it is missing the `arm64e.x1` slice, the checked-pointer-arithmetic entitlement, or both. Step 4 applies whichever is missing.
- `eligible-slice-only` — a Library/framework target that can take checked pointer arithmetic and does not have the build setting. There is no entitlement half for these targets: entitlements are granted per process from the main executable, so the library builds the slice and the consuming app's entitlement is what enforces the checks. Step 4 applies the build setting only.

The key is never listed under `Missing entitlements`, which stays required and default-ON keys only, so it cannot make a target **Partial** and cannot reach Step 1b.

On large projects this iterates over many `.entitlements` plists — if Step 3 took noticeable time, this one will too.

### Phase 4: Plan & Approve

This phase produces a tailored, editable plan file that the user reviews before any changes happen. Once approved, Phases 5–7 run end-to-end with no further prompts.

#### Step 1: Source-control state

Source control was checked in Phase 1, and the user already accepted any no-source-control state at that point. Phase 4 Step 3 uses the recorded state to decide whether to include the ⚠️ blockquote in the plan file.

#### Step 2: Skip if everything is already configured

`TaskList` the `Audit <target>` tasks and `TaskGet` each. Early-exit if **all** default-checked plan items are already at their target state:

- Every Enhanced-Security category (from each task's `Category:` line) is **Up-to-date** or **Skipped**.
- No task's `Checked pointer arithmetic:` line reads `eligible-entitlement` or `eligible-slice-only`.
- Every relevant Warnings setting (compiler, static analyzer, and clang-tidy) is `already hardened` on every applicable target (per each task's Audit-table block).
- No task's `Deliberately-disabled:` line yields a row (after the Phase-6 exclusions below).

Optional follow-ups (Additional diagnostic settings, Bounds safety adoption) do **not** block early-exit. Report "Everything in scope is already configured" and exit; do not write a plan file.

#### Step 3: Write the plan file

Create `xcode-security-audit-plan.md` at the **root of the Xcode workspace** via `XcodeWrite` (path: `xcode-security-audit-plan.md`, no parent group). `XcodeWrite` both writes the file to disk under `<project-root>/` and registers it in the project so the user can open it directly from Xcode's Project Navigator.

Include only items that apply to the project (see omission rules below). Use this template — substitute the placeholders in `<…>`:

````markdown
# Xcode Security Audit — Plan
**Project:** <name> · <N> targets · languages: <list>
**Generated:** <YYYY-MM-DD>
> ⚠️ **No source control detected.** This skill modifies build settings and entitlements.
> Without source control (e.g., Git), rollback requires manual undo. Consider [setting up source control](doc://com.apple.documentation/documentation/xcode/configuring-your-xcode-project-to-use-source-control) before picking **Run**.
Edit the items below — set what steps to perform now, or leave them unchecked to defer them. Questions about any item, or want a more detailed plan? Just ask — I'll answer, and can expand this plan on the points you care about before you decide.
## Phases
- **Enhanced Security** — the project's runtime-protection bundle. Apply to: <target list>. (Group — check the sub-items below.)
  - [x] **[Enable Enhanced Security](doc://com.apple.documentation/documentation/Xcode/enabling-enhanced-security-for-your-app)** — sets `ENABLE_ENHANCED_SECURITY=YES` at the project level. (Your project doesn't use a project-level xcconfig — I'll walk you through enabling it in Xcode's Build Settings UI yourself, then verify by reading project file.)
  - [x] **[Update entitlements](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process)** — adds the hardened-process entitlement family per target (Memory Safety, Runtime Protections).
  - [x] **[Hardware memory tagging](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process.checked-allocations)** — adds the hardware memory tagging entitlement, in soft mode, on supported platforms (<target list filtered to MTE-supported platforms>).
  - [x] **[Checked pointer arithmetic](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow)** — adds the arm64e.x1 slice and the entitlement to enforce pointer-arithmetic overflow checking (<target list filtered to arm64e.x1-supported platforms>). Run time enforcement requires hardware memory tagging enabled. Latent pointer-arithmetic bugs will terminate the app on capable hardware.
- **[Warnings](doc://com.apple.documentation/documentation/Xcode/build-settings-reference)** — additional diagnostics on all C/C++/ObjC targets. (Group — check the sub-items below.)
  - [x] **Compiler warnings** — <N> settings promoting security-relevant compiler diagnostics (fire on every build).
  - [x] **Static analyzer warnings** — <N> security checkers (run during Build and analyze).
  - [x] **Clang-tidy warnings** — <N> clang-tidy-integrated checks (run during Build and analyze).
- [x] **Inquire about disabled settings** — <M> found (e.g., `<setting>=NO` on `<target>`). May trigger follow-up questions if no rationale is documented.
- [ ] **Additional diagnostic settings** — extra opt-in warnings/checkers beyond the defaults. Off by default: they surface more findings to review and can be noisier (more false positives).
- [ ] **[Bounds safety adoption](https://clang.llvm.org/docs/BoundsSafetyAdoptionGuide.html)** — pointer to a separate skill. No changes applied here.
## Decision document
The skill creates or updates `xcode-security-settings.md` to record every setting decision (kept, deferred, disabled, with rationale). Edit the path to relocate.
- Path: `xcode-security-settings.md`
````

Include the ⚠️ blockquote only when the project has **no source control**; omit it otherwise.

Include the trailing parenthetical on the **Enable Enhanced Security** sub-item only when the project is pbxproj-only (no `*.xcconfig` files surfaced by Phase 3's project-wide scan); omit it otherwise.

The decision document should live in the same directory as the rest of the documentation, or at the project level.

##### Item omission rules

A plan item is omitted entirely when it doesn't apply:

- **Enhanced Security** — omit (along with all sub-items) only if every supported-product-type category from Phase 3 step 4 is **Up-to-date** or **Skipped**, and no task's `Checked pointer arithmetic:` line reads `eligible-entitlement` or `eligible-slice-only`. **Enhanced Security** must be enabled otherwise.
- **Enable Enhanced Security** (sub-item) — never omitted when Enhanced Security is shown; the trailing pbxproj-only parenthetical is the only conditional part.
- **Update entitlements** (sub-item) — never omitted when Enhanced Security is shown.
- **Hardware memory tagging** (sub-item) — omit if no target's `SUPPORTED_PLATFORMS` / `SDKROOT` matches `macosx`, `iphoneos`, `iphonesimulator`, `watchos`, `xros`, or `xrsimulator`.
- **Checked pointer arithmetic** (sub-item) — omit if no task's `Checked pointer arithmetic:` line reads `eligible-entitlement` or `eligible-slice-only`.
- **Warnings** — omit the parent (and all three sub-items) if pure-Swift, or if every setting across all three groups is `already hardened` on every applicable target. Otherwise omit an individual sub-item — **Compiler warnings**, **Static analyzer warnings**, or **Clang-tidy warnings** — when every setting in that group is `already hardened` on every applicable target, or the group has no applicable settings for the detected languages.
- **Inquire about disabled settings** — omit if the `deliberately disabled` predicate yields no rows.
- **Additional diagnostic settings** — never omitted; always offered.
- **Bounds safety adoption** — omit if Phase 3 step 2 detected no C, C++, or Objective-C++ (counting `sourcecode.cpp.*` overrides as C++).

##### Default check state

**Group headings carry no checkbox.** The parent lines that have sub-items — **Enhanced Security** and **Warnings** — are plain bold group labels, not checkable items; their sub-items carry the checkboxes. This avoids the ambiguity of a checked parent whose sub-items are all unchecked. Every other item (including leaf items with no sub-items, like **Inquire about disabled settings**, **Additional diagnostic settings**, **Bounds safety adoption**) is checkable.

The user can flip items and sub-items under **Phases** by editing the plan file before picking **Run**.

#### Step 4: Ask for approval

Tell the user:

> "Plan written to `xcode-security-audit-plan.md` and added to the Xcode project — open it to review. Edit it as needed — uncheck or delete items to skip them; edit the decision document path to relocate. When ready, pick Run. Pick Cancel to abort without changes. Nothing is modified until you pick Run."

Then ask via `AskUserQuestion` with single-select options:
- **Run** — proceed to "Phase 5"
- **Cancel** — abort

#### Step 5: Handle the response

If the user asks a question or requests more detail instead of picking Run/Cancel: answer it, consulting the relevant doc from **Bundled Reference Documents** (e.g. `references/additional-settings.md` for the additional diagnostic settings). If they want that detail captured, update `xcode-security-audit-plan.md` via `XcodeUpdate` to elaborate on those points. Then re-present the Step 4 approval prompt — nothing is applied until the user picks Run.

If **Cancel**: run the final cleanup task (`Prompt to remove plan file`, see "Phase 7: Report and Decision Document" below). The keep-or-remove prompt is offered on Cancel too, so the user's choice to abandon the audit doesn't silently differ from a normal completion. Report "Cancelled — no changes applied," and exit the skill.

If the plan file is missing at re-read time (the user deleted it from disk before responding), treat it as a Cancel — and skip the `Prompt to remove plan file` task (there's nothing to remove).

If **Run**: `XcodeRead xcode-security-audit-plan.md`. Parse:
- Each `- [x]` or `- [X]` bullet is a checked item; the item name is the bold portion (between `**…**`).
- A bold bullet with **no** checkbox (e.g. `- **Enhanced Security** …`, `- **Warnings** …`) is a group heading, not a checkable item. It creates no task of its own — its checked sub-items drive the work. Do not treat it as checked or unchecked.
- Items written as `- [ ]` and items deleted from the file are skipped — both produce identical skip behavior.
- Under the "Decision document" heading, the value after `Path:` is the decision document location.

Create the fine-grained tasks listed in **Track Progress**:

- For each `Apply Enhanced Security entitlements to <target>` task, copy the per-target delta from the corresponding `Audit <target>` task's description (`Category:`, `Entitlements path:`, `Missing entitlements:`) into the apply task's own description so Phase 5 reads from one place.
- The **Warnings** parent line is a heading, not a task — it produces no task of its own. Each checked **Warnings** sub-item creates its corresponding apply task: **Compiler warnings** → `Apply Compiler Warnings`, **Static analyzer warnings** → `Apply Static Analyzer Warnings`, **Clang-tidy warnings** → `Apply Clang-Tidy Warnings`. This mirrors how the **Enhanced Security** parent maps to its sub-item tasks.
- To create the `Inquire about <MACRO> on <target>` tasks (only when **Inquire about disabled settings** is checked), `TaskList` the `Audit <target>` tasks and `TaskGet` each; the `Deliberately-disabled:` line of each description lists that target's candidate rows. Apply the Phase-6 exclusions documented below when filtering.
- When creating the `Report and update decision document` task, put the parsed decision-document path in its description so Phase 7 reads it from there.

If the parsed plan has zero checked items, run the final cleanup task immediately and report "Plan was empty — nothing to do."

### Phase 5: Apply Settings

Read build-setting state from each `Audit <target>` task's description (the Audit-table block) when needed; per-target apply state comes from each apply task's own description.

**How to apply build settings:**
- **Project uses `.xcconfig` files** — edit the xcconfig directly. Supports both project-level and target-level settings.
- **Project uses `.pbxproj` only** — use `UpdateTargetBuildSetting` for target-level settings. Ask the user to enable project-level settings. Once the user responds that it was set, verify that it was set correctly using grep on the project file.
- **Mixed** — if a target has an `.xcconfig` file, edit the xcconfig. Otherwise, use the Xcode build setting tools. Never introduce a new configuration method.

`ENABLE_ENHANCED_SECURITY` must be set at project level such that any existing and future build targets inherit this setting.
This setting should be disabled only after serious consideration and with strong justification.

#### Step 1: Enhanced Security

**1a. Enable Enhanced Security at the project level.** Walk the `Enable Enhanced Security at project level` task. Two paths inside it:

- **Project uses a project-level xcconfig** — write `ENABLE_ENHANCED_SECURITY = YES` to the xcconfig via `XcodeUpdate`. Mark the task completed.
- **Project is pbxproj-only** — no MCP tool can write a project-level pbxproj setting directly, so the user has to set it in Xcode. Give these exact steps (repeat them verbatim whenever you re-show them): *"Open the project in Xcode. Select the project in the Project Navigator (the top entry, not a target). Go to **Build Settings**, switch the scope to **All / Combined**, search for `ENABLE_ENHANCED_SECURITY`, and set the **project-level** column (left of the target columns) to `YES`. Save."* Then `AskUserQuestion` with two options: **I've enabled it** and **Show me the steps again**. On **I've enabled it**, verify with Bash: `grep -E 'ENABLE_ENHANCED_SECURITY *= *YES' <project-root>/<ProjectName>.xcodeproj/project.pbxproj`. If a match is found, mark the task completed. If not, **do not move on**: the confirmation was most likely accepted without the change actually being made — an accidental Enter, or Save was missed. Say that plainly, **re-show the steps verbatim**, and ask again. Loop — re-run the grep after each confirmation and re-show the steps every time it still isn't found — until the grep finds `ENABLE_ENHANCED_SECURITY = YES`.

**1b. Update Enhanced Security entitlements.** The fine-grained `Apply Enhanced Security entitlements to <target>` tasks created in Phase 4 step 5 already enumerate the targets needing changes (the **Partial**, **Off**, and **No-entitlements-file** categories — **Up-to-date** and **Skipped** are excluded). Walk those tasks.

Read `references/enhanced-security.md` for the full key list, defaults, and the supported product-type list. For details on individual sub-options, see:
- `references/pointer-authentication.md` — arm64e pointer signing
- `references/typed-allocators.md` — type-aware memory allocation
- `references/stack-zero-init.md` — automatic stack variable zeroing
- `references/readonly-platform-memory.md` — dyld state protection
- `references/runtime-restrictions.md` — dylib and Mach message restrictions
- `references/security-compiler-warnings.md` — security-focused compiler warnings
- `references/cpp-hardening.md` — C++ stdlib hardening and bounds checking
- `references/hardware-memory-tagging.md` — ARM MTE
- `references/checked-pointer-arithmetic.md` — checked pointer arithmetic (CPA2)

**Pointer authentication and binary dependencies.** Enhanced Security is a bundle of independent protections; only pointer authentication cascades to `arm64e`. Always recommend `ENABLE_ENHANCED_SECURITY = YES` at the project level. If the project has a binary Swift Package, xcframework, or prebuilt framework that does not ship `arm64e`, the right mitigation is to override `ENABLE_POINTER_AUTHENTICATION = NO` at the target level on every target that links the dependency — not to skip Enhanced Security. List the offending dependencies in the report so the user can ask the vendor for `arm64e` support and lift the override later.

`arm64e.x1` is a pointer-authentication slice, so it should not be built where pointer authentication is off. A binary dependency that ships no `arm64e` slice will likely not ship `arm64e.x1` either. On every target that gets a target-level `ENABLE_POINTER_AUTHENTICATION = NO`, also set a target-level `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE = NO`. Step 4 skips these targets, so the audit never adds the checked pointer arithmetic entitlement there. If a target already carries `com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow` from an earlier configuration, report it — the build will warn that it has no effect without `arm64e.x1`.

**Producer side — universal binary on library/framework targets.** Pointer authentication is highly recommended on library and framework targets too — do not skip it on the grounds that the universal binary is a larger on-disk artifact (RAM footprint and execution cost are unchanged; dyld loads only one slice). Enabling pointer authentication already builds both the `arm64` and `arm64e` slices automatically, so no explicit `ARCHS` is needed. The same argument extends to checked pointer arithmetic, which requires the `arm64e.x1` slice appended: a consumer building for `arm64e.x1` gets checked arithmetic over the library's code only if the library ships that slice — the consumer app must meet other requisites as well for run time enforcement. Step 4 applies the build setting to these targets. See `references/universal-binaries-for-libraries.md` and `references/checked-pointer-arithmetic.md`.

For each task:

1. **Compose the change set** from this apply task's description (the `Category:` / `Missing entitlements:` lines copied in from the audit task).
   - **Entitlements-supported** categories (Partial / Off / No-entitlements-file): add/update entitlements via `AddEntitlement`; create `.entitlements` if missing and wire `CODE_SIGN_ENTITLEMENTS`. DriverKit targets are supported for build settings only — skip entitlement changes for them.
   - **Library/framework** category: no entitlements work, and no build-setting change either — pointer authentication already emits both slices. The only thing to do is the distribution check in item 2 below.

2. **Per-target build settings.** `ENABLE_ENHANCED_SECURITY = YES` is already set at the project level (Step 1a above), so it cascades `ENABLE_POINTER_AUTHENTICATION = YES` to every target. Simulator builds need no override — the build system drops `arm64e` for simulator SDKs automatically. The only per-target override: for each target that links a binary dependency that doesn't ship `arm64e`, set an unconditional target-level `ENABLE_POINTER_AUTHENTICATION = NO` (that dependency can't be linked as `arm64e` on any platform). Skip targets that already have an explicit target-level value (per the Audit-table block in their `Audit <target>` task).

   For each **Library/framework**-category target where pointer authentication will end up enabled (the target's platform supports arm64e and there is no existing target-level `ENABLE_POINTER_AUTHENTICATION = NO`), no build-setting change is needed — pointer authentication appends the `arm64e` slice automatically. Only check that the distributed build emits both the `arm64` and `arm64e` slices: if the target sets `ONLY_ACTIVE_ARCH = YES` in its Release/distribution configuration, warn in the report that consumers get a single-architecture artifact.

   Do not auto-enable default-OFF sub-options. Hardware memory tagging belongs to Step 3, checked pointer arithmetic to Step 4.

3. **Apply** the change set per target: add or update entitlements with `AddEntitlement` (creating the `.entitlements` file and wiring `CODE_SIGN_ENTITLEMENTS` when the target has none); and apply build-setting changes.

After all targets are processed, report: "Enabled Enhanced Security on N target(s). Added a target-level `ENABLE_POINTER_AUTHENTICATION = NO` on T target(s) that link arm64e-less binary dependencies. Universal `arm64`/`arm64e` binary on U library/framework target(s)." If the project is pbxproj-only and `Verify Enhanced Security at project level` succeeded, append: "Enhanced Security is enabled at the project level (you set it in Xcode)." If the user skipped the guide step, append: "Project-level `ENABLE_ENHANCED_SECURITY` was not enabled this run — re-run the skill after enabling it in Xcode."

The user already approved this in "Phase 4" — no further prompt is needed.

The per-target `Apply Enhanced Security entitlements` tasks dominate Phase-5 wall time on multi-target projects. Each one edits the target's `.entitlements` plist.

#### Step 2: Warnings

If pure Swift, skip the whole step. This step covers three groups, each gated on its own plan sub-item — **Compiler warnings**, **Static analyzer warnings**, and **Clang-tidy warnings**. Skip any group whose sub-item was unchecked or deleted. For every setting, consult that target's `Audit <target>` task description (the Audit-table block) and skip individual settings whose row is `already hardened`. Otherwise apply target-level (see "How to apply build settings").

**Compiler warnings** (fire on every build):

- `GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR` — non-void function returning without a value is undefined behavior; callers read whatever happened to be in the return register. Promoting to error catches this at compile time. `YES_ERROR` is the documented Xcode value for "treat this specific warning as an error" — it does not flip every warning into an error.
- `GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE` — reading uninitialized stack values leaks prior frame contents and lets attackers control flow with stale data. Aggressive mode warns on more cases (e.g., conditional initialization paths).
- `CLANG_WARN_IMPLICIT_FALLTHROUGH = YES` — implicit `switch` fallthrough is one of the most common sources of branching bugs; the warning forces an explicit `[[fallthrough]]` / `__attribute__((fallthrough))` whenever intentional.
- `GCC_WARN_64_TO_32_BIT_CONVERSION = YES` — silent narrowing of `size_t`/pointers to `int` is a classic source of integer-truncation vulnerabilities (length checks pass on the wide value, then fail open on the narrow one).
- `GCC_TREAT_IMPLICIT_FUNCTION_DECLARATIONS_AS_ERRORS = YES` (C/ObjC only) — implicit declarations were removed in C99 and produce wrong calling conventions and wrong return-type assumptions in modern C. Always an error.

The two `YES_ERROR` / `… ERRORS = YES` settings are scoped: they only promote *their own specific warning* to an error, not all warnings in the project.

**Static analyzer warnings** (run during *Build and analyze*, not regular builds):

- `CLANG_ANALYZER_SECURITY_FLOATLOOPCOUNTER = YES` — floating-point loop counters can stall or overshoot due to rounding; the analyzer flags loops where this can become a security-relevant bug.
- `CLANG_ANALYZER_SECURITY_INSECUREAPI_RAND = YES` — `rand()` / `random()` are predictable PRNGs unsuitable for any security purpose; analyzer flags their use so callers switch to `arc4random_uniform` or `SecRandomCopyBytes`.
- `CLANG_ANALYZER_SECURITY_INSECUREAPI_STRCPY = YES` — flags `strcpy`, `strcat`, and friends that are inherently unsafe; callers should switch to size-bounded variants (`strlcpy`, `strlcat`, `snprintf`).

**Clang-tidy warnings** (clang-tidy-integrated checks that are part of the clang static analyzer; they fire only during *Build and analyze* / `clang --analyze`, never on normal builds, so there is no build-break risk and adopters need to install nothing extra):

- `CLANG_TIDY_BUGPRONE_REDUNDANT_BRANCH_CONDITION = YES` — flags a branch condition that is redundant with an enclosing condition, a common sign of a copy-paste or logic error.

Report briefly per group, e.g.: "Enabled compiler warnings, static analyzer warnings, and clang-tidy warnings." — naming only the groups actually applied.

#### Step 3: Hardware Memory Tagging

If the **Hardware memory tagging** sub-item (under Enhanced Security) was unchecked or deleted, skip this step.

Hardware memory tagging is supported only for targets whose `SUPPORTED_PLATFORMS` (or `SDKROOT`) is `macosx`, `iphoneos` / `iphonesimulator`, `watchos`, or `xros` / `xrsimulator`.
Hardware backing requires an iPhone or iPad with an A19 chip or later, a Mac or Apple Vision Pro with an M5 chip or later, or an Apple Watch with an S11 chip or later.

Read `references/hardware-memory-tagging.md` and apply both keys to every supported target: `com.apple.security.hardened-process.checked-allocations`, and its `soft-mode` sub-option for a non-fatal rollout. Soft mode alone does nothing — it modifies the parent key rather than replacing it. The user already approved this in "Phase 4" — no further prompt is needed.

#### Step 4: Checked Pointer Arithmetic

Run this step after Step 1 and Step 3, whichever of them run: it reads settings Step 1 can change and the entitlements Step 3 can add. Checked pointer arithmetic requires the `arm64e.x1` slice, and this step enables that slice only on a target already building the `arm64e` slice with pointer authentication. Run time enforcement additionally requires hardware memory tagging on the same target.

Skip this step if the **Checked pointer arithmetic** sub-item was unchecked or deleted.

Apply to every target whose `Checked pointer arithmetic:` line reads `eligible-entitlement` or `eligible-slice-only`; skip the rest. That line is computed in Phase 3 step 4 and is the only eligibility test — do not re-derive it here.

Then check the conditions below per target, reading each value fresh: Step 1 may have changed the build settings, and Step 3 may have added the entitlement. Skip a target and report it when any condition it is subject to fails.

- `ENABLE_ENHANCED_SECURITY` evaluates to `YES` — `eligible-entitlement` targets only, since the entitlement needs the capability.
- `ENABLE_POINTER_AUTHENTICATION` evaluates to `YES` — both kinds of target, since `arm64e.x1` is a pointer-authentication slice.
- `com.apple.security.hardened-process.checked-allocations` is in the entitlements file — `eligible-entitlement` targets only, since run time enforcement depends on hardware memory tagging. The key is absent when Step 3 did not run, skipped this target, or the **Hardware memory tagging** sub-item was unchecked.

Run time enforcement requires a device running iOS with an A20 Pro chip or later, or a device running watchOS with an S11 chip or later.

Read `references/checked-pointer-arithmetic.md` and apply per target. For an `eligible-entitlement` target, apply both halves: set `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE = YES` at target level (the target's xcconfig, otherwise `UpdateTargetBuildSetting`), and add `com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow` with `AddEntitlement`. Both halves are required because the slice alone does not enforce checked pointer arithmetic, and Xcode warns at build time if the entitlement is set while the target is not building `arm64e.x1`. For an `eligible-slice-only` target, apply the build setting only.

Record the outcome for every target in the `Apply Checked Pointer Arithmetic` task's `description` via `TaskUpdate`, one line per target, so Phase 7 (Report and Decision Document) reads it from one place:

```
<target>: applied | skipped: <reason>
```

Use `skipped: not eligible — <reason from the target's Checked pointer arithmetic: line>` for a target that was never eligible, and `skipped: ENABLE_ENHANCED_SECURITY is <value>`, `skipped: ENABLE_POINTER_AUTHENTICATION is <value>`, or `skipped: no hardware memory tagging entitlement` for one that was eligible but failed the re-read above. The user already approved this in "Phase 4" — no further prompt is needed.

#### Step 5: Additional Diagnostic Settings

If the **Additional diagnostic settings** plan item was unchecked or deleted, skip this step.

Read `references/additional-settings.md` and follow it. The user already approved this in "Phase 4" — no further prompt is needed.

#### Step 6: Bounds Safety Adoption

If the **Bounds safety adoption** plan item was unchecked or deleted, skip this step.

This step does not apply changes — it emits guidance only.

For C projects (C present per Phase 3 step 2), print:
> "To adopt `ENABLE_C_BOUNDS_SAFETY` (annotation-based bounds safety for C), invoke the `adopt-c-bounds-safety` skill."

For C++ projects (C++ **or** Objective-C++ present per Phase 3 step 2 — including any `sourcecode.cpp.*` override on files with other extensions), print:
> "To adopt `ENABLE_CPLUSPLUS_BOUNDS_SAFE_BUFFERS` (C++ bounds-safe buffer patterns), read the documentation at https://clang.llvm.org/docs/SafeBuffers.html"

### Phase 6: Inquire about Disabled Settings

If the **Inquire about disabled settings** plan item was unchecked or deleted, skip this phase.

This phase pauses for one user response per deliberately-disabled setting that lacks a documented rationale. If the candidate list is long, surface the count up front so the user knows what to expect ("I found 7 deliberately-disabled settings; let me ask about each").

A row is a candidate when the `deliberately disabled` predicate (defined in `references/reading-build-settings.md`) holds. `TaskList` the `Audit <target>` tasks and `TaskGet` each; the `Deliberately-disabled:` line of each description lists that target's candidate rows. Flag an *unconditional* `ENABLE_POINTER_AUTHENTICATION = NO`, since that disables pointer authentication on device builds. Flag `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE = NO` on a target whose `Checked pointer arithmetic:` line reads `not-eligible: opted out` — that reason means the opt-out is the only thing standing between the target and the `arm64e.x1` slice. Do not flag it for the other `not-eligible` reasons, where the slice could not be built anyway. Restrict to settings whose Scope (in `references/security-settings-reference.md`) covers a language detected in Phase 3 step 2; both settings above have no Scope and are flagged regardless.

For each candidate, walk the corresponding `Inquire about <MACRO> on <target>` task created in Phase 4 step 5:

- If the decision document has an entry with status `Disabled` and a rationale → note it in the report and move on.
- Otherwise → `AskUserQuestion`: "I found `<MACRO>` explicitly set to `NO` with no explanation. Is there a reason for this?" Double-check that the macro is `deliberately disabled` and not merely at Xcode's default OFF — only call out explicit overrides. Record the rationale (or recommend re-enabling if none).

Same flow applies to `ENABLE_ENHANCED_SECURITY = NO` if it appears on any task's `Deliberately-disabled:` line.

### Phase 7: Report and Decision Document

Produce a lean summary:

1. **Enabled** — project-wide settings that were enabled.
2. **Enhanced Security per target** — one line per target: name, final status (up-to-date / applied / skipped-by-user), terse delta (entitlements added, whether an entitlements file was created, which slices the target now builds, whether checked pointer arithmetic was applied). Roll up Skipped targets into one line. For checked pointer arithmetic, `TaskGet` the `Apply Checked Pointer Arithmetic` task and use its per-target outcome lines, including the reason for each skip.
3. **Already active** — settings already configured correctly.
4. **Inquired** — settings found disabled and the outcome of the inquiry.
5. **Test your app** — action item for the user: test on real hardware (not the simulator) that supports every enabled hardening, watch for protections firing, and fix the crashes and simulated crash reports that surface. Ship to customers only once the hardened app is adequately tested — otherwise it may crash or run slowly in production. For hardware memory tagging specifically, fix the simulated crash reports soft mode produces before disabling soft mode for enforcement. Checked pointer arithmetic has no soft mode and memory tagging's does not cover it, so test on capable hardware before shipping: a latent pointer-arithmetic bug terminates the app.

**Decision document.** `TaskGet` the `Report and update decision document` task to read the decision-document path. Then read `references/decision-document.md` and follow it to create or update the document at that path.

After Phase 7 — and on any error path during Phases 5–7 — this final task runs:

1. **`Prompt to remove plan file`** — ask the user via `AskUserQuestion`: "The audit is complete. Remove the plan file `xcode-security-audit-plan.md` from your project?"
   - **Yes, remove it (Recommended)** → `XcodeRM xcode-security-audit-plan.md deleteFiles:true`
   - **No, keep it** → leave it in place; it stays in the Project Navigator as a record of what was approved. The user can delete it later from Xcode or Finder.

If removal fails, warn the user but do not block exit.

## User-Facing Interaction Guidelines

- **Keep replies lean.** Short sentences.
- **Speak in complete sentences.** No fragments. Don't emit telegraphic noun phrases like "No existing decision document." — write a full sentence ("I didn't find an existing decision document — I'll create one at the end.").
- **Phases are internal.** Never reference phase numbers or step numbers in user-facing prose. Describe outcomes plainly: say "I won't need to ask you about disabled settings" instead of "there will be no Phase 6 inquiry questions". This applies to narration, status lines, and any AskUserQuestion text.
- **No skill-internal jargon.** Don't use words like "catalog", "audit table" in user-facing prose — those are internal to the skill. Describe what's happening in everyday Xcode terms: "checking known security build settings", "the list of targets", "the analysis I just ran".
- **Keep user questions minimal.** Three scheduled questions: the briefing-acknowledgment prompt (Begin audit / Cancel) at the end of "Phase 1", the plan approval prompt (Run / Cancel) at the end of "Phase 4", and the keep-or-remove-plan-file prompt at the end of "Phase 7". Other questions are situational: inquiries about deliberately-disabled settings during "Phase 6" (only when an explicit `= NO` lacks a documented rationale), and the `Enable Enhanced Security at project level` confirmation prompt (only for pbxproj-only projects when that sub-item is checked).
- **Report progress** so the user can track: "Enabling...", "Evaluating...", "Keeping/Reverting..."
- **Use `AskUserQuestion`** for the briefing acknowledgment (Begin audit / Cancel), for the plan approval (Run / Cancel), for inquiring about disabled settings during "Phase 6", for the `Enable Enhanced Security at project level` confirmation in Phase 5 Step 1a (pbxproj-only), and for the keep-or-remove-plan-file prompt at the end of "Phase 7".
- **When asking a question provide context the user needs to answer the question**. For example, describe the benefit of the security protection before asking whether to enable it. Describe it in terms of the protection it provides, not how it is enabled.
- **When emitting lists of Xcode build settings, use bullet lists** Don't use comma-separated lists.