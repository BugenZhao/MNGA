---
description: "Use when an app's layout must adapt to a window that changes size while the app runs, or when an app must support more than one window. That includes being asked to make an app resizable or support a resizable window, a layout that breaks or does not adapt as the window resizes, and preparing or optimizing an app for the foldable iPhone Duo, split-screen multitasking, or Stage Manager. Modernizes the app by replacing legacy shared-state APIs with context-appropriate alternatives: mainScreen, interfaceOrientation, userInterfaceIdiom, application and scene lifecycle, and safe area insets."
name: app-resizability
---
# App Resizability Skill

## When to Use

Use this skill whenever the request is about any of the following, whether or not it names an API:

- Getting an app ready for, or optimizing it for, the foldable iPhone Duo.
- An app that must adapt when its window changes size while it runs.
- Split-screen multitasking, Stage Manager, or a resizable scene.
- Any deprecated API named in the Scope section below.

The request does not have to be technical. "Get my app ready for the iPhone Duo", "optimize this app for the foldable iPhone", and "make this app resize properly" all activate this skill. iPhone Duo is the foldable iPhone, so treat questions about iPhone Duo or the foldable iPhone as the same request. Treat a request about the foldable iPhone Duo as a request for every task in the Task Registry, because a screen that changes size exposes all of them at once.

## Purpose

Modernize UIKit apps to behave correctly on modern iOS by:
- Eliminating references to legacy shared-state APIs
- Migrating from application lifecycle to scene lifecycle
- Supporting dynamic scene sizing and multi-window environments

## Scope

This skill performs **specific, targeted modernizations** in both **Swift and Objective-C** codebases:
- Replace legacy shared-state APIs with context-appropriate modern APIs
- Migrate to scene-based lifecycle
- Update apps to support a resizable user interface by removing usage of:
  - main screen (`UIScreen.mainScreen`, `UIScreen.main`)
  - interface orientation (`interfaceOrientation`)
  - user interface idiom (`userInterfaceIdiom`, `UI_USER_INTERFACE_IDIOM()`)
  - assumptions of symmetric safe areas (`safeAreaLayoutGuide`, `safeAreaInsets`)
  - application lifecycle in place of scene lifecycle (`UIApplicationDelegate`)

## Core Principles

1. **Closest to consumer** — Prefer information nearest the point of use (e.g., view's trait collection over window's).
2. **Always apply a replacement when the target API is present.** A TODO alone is a failure. **An empty diff for a file containing the target API is also a failure.** If the file contains the target deprecated API and a concrete replacement is feasible under any pattern in the active task's reference file, apply it. Only skip when the target API appears exclusively inside dead code (`#if 0`/`#endif`). When uncertain between two valid replacements, pick the one that best fits the user's request rather than producing an empty diff. **Never silently skip a file**: if you are unwilling to apply a change, talk to the user about possible options — never produce no output for it. **Do not get stuck weighing edge cases on simple files; when the substitution is obvious, apply it and move on.**
3. **TODOs must be actionable.** State why the change is needed, what the replacement would look like, and any lifecycle or threading concerns. Place the TODO on its own line above the unchanged code, never inline. A vague TODO ("fix this later") is worse than none, because it consumes review attention and informs nobody.

   **Indent every line of an inserted comment to match the line it precedes.** A continuation line at a different indent leaves the block misaligned. Re-emitting the following line to realign it edits a line you were not asked to touch.
4. **Don't add a redundant TODO when an existing annotation already covers the migration.** If the call site already has a `#pragma clang diagnostic ignored` paired with a bug-report reference, an existing `// TODO`, or a deprecation comment that points at the migration, do not add another one. Only add a new TODO when it provides additional migration guidance not present in the existing annotation.
5. **Ask the user before making a risky code change; fall back to a TODO only when interactive guidance is unavailable.** When a replacement risks breaking callers or changing observable behavior (e.g., changing a method signature in a header that other modules import; substituting `width > height` for orientation when left-vs-right matters), the first move is to ask the user how to proceed. Only when the skill is running non-interactively, or when the user explicitly declines to provide guidance, drop a TODO and move on. This does **not** apply to standard, drop-in safe replacements specified by the active task's reference file — those must be applied per Core Principle 2.
6. **Honor explicit user instructions; otherwise apply the defaults from the task reference file.** When the user asks for a specific approach — a particular attribute, parameter name, parameter position, trait source, or fallback behavior — use that exactly. Don't silently substitute what you consider the modern equivalent. When the user is general ("modernize this app", "fix `UIScreen.main` usages"), apply the defaults from the active task's reference file.
7. **Never replace dynamic values with literals** — Always keep replacements dynamic.
8. **Preserve control flow** — Prefer drop-in replacements that maintain the original code structure. Only add guard/early-return patterns when a direct substitution does not work. **When editing code around control flow (`if`/`else`, `switch`/`case`/`default`, `do`/`catch`), verify that the branching structure is preserved after your edit. Never collapse an `if`/`else` into sequential execution: both bodies then run unconditionally, which is a critical bug. Keep every branch whose condition is sound, and replace only the deprecated value inside it. Remove a branch only when the active task names that condition itself as the defect and states that the correct behavior is unconditional. In that case delete the condition, keep the body that matches the correct behavior, and name the branch you removed in your summary so a reviewer can check it.**
9. **Stay in scope — no opportunistic cleanup.** Only modify lines containing the target deprecated API for the active task. Do NOT also fix other deprecation that happens to live nearby. Do NOT trim trailing whitespace, reformat blank lines, or "clean up" surrounding formatting. Even if you see an obvious modernization opportunity on an adjacent line, leave it alone — each task is independent and out-of-scope edits convert a successful in-scope change into a warning.
10. **Extract repeated expressions** — When the same replacement value is used multiple times in a scope, extract it into a named local variable.
11. **Never walk global scene/window state** — Never use `UIApplication.shared`, `UIDevice.current`, `UIScreen.main`, or other shared objects as a replacement. If no local object is available, modify the method to accept a new parameter and update its callers to pass one.
12. **Complete patterns — atomic, never partial** — Every multi-part pattern the active task defines requires ALL of its parts applied together as a single unit. **When the active task requires both an API replacement AND a reactive update (e.g., trait change observation), these form a single atomic change — never apply one without the other.** If you cannot complete every part the task specifies, do not apply a partial change — either complete the pattern or skip with an explicit reason.
13. **Preserve unrelated guards and fallbacks.** When removing a reference to the target API, change ONLY that reference. Do not simultaneously delete `respondsToSelector:` checks, nil guards, `if (x != nil)` defenses, version checks (`#available`, `@available`), or any other defensive logic that wraps the call site — unless the user explicitly asks for it. Each guard exists for an independent reason (selector availability across SDK versions, nil-window safety, feature flags); the modernization touches only the value you came to replace, not the surrounding control flow.
14. **Off-target replacement guard.** Before editing any line, verify two things: (a) the line contains the **target deprecated API** for the **active task**, and (b) you're editing the deprecation the user asked about — not a nearby line that "looks similar."

---

## Prerequisites

Run all three checks once per project, before Phase 1. These checks are read-only: add no key, change no value, and delete no key, in the `Info.plist` or in the build settings. Report what you read, then continue with the workflow. An app that fails a check cannot resize, whatever the source code says.

Read each key in the target `Info.plist` and in the build settings. Build settings live in the project file and in any `.xcconfig`. The build merges every source, so read them all before you report. A key missing from one source proves nothing. When two sources set the same key, the project file wins.

Skip all three checks when the request names files rather than a project. Say nothing about them. Do not search the file system for a project.

| Check | Already satisfied when | Otherwise report |
|-------|------------------------|------------------|
| Launch screen | The target sets `UILaunchScreen`, `UILaunchScreens`, `UILaunchStoryboardName`, `UILaunchStoryboards`, or `INFOPLIST_KEY_UILaunchScreen_Generation` | The app declares no launch screen. iOS 27 rejects the App Store upload with `ITMS-90870`. Refer to [TN3208](https://developer.apple.com/documentation/technotes/tn3208-preparing-your-apps-launch-screen-to-meet-app-store-requirements). One key is enough, so leave an existing storyboard alone |
| iPad orientations | The iPad declaration lists all four orientations, or the target declares none. `UISupportedInterfaceOrientations~ipad` is the iPad declaration, and plain `UISupportedInterfaceOrientations` is when that key is absent | Name the orientations the declaration omits. Add that a `supportedInterfaceOrientations` override can still lock the scene, and that you did not look for one. Check iPad only: a portrait-only iPhone declaration is normal |
| Full screen opt-out | `UIRequiresFullScreen` is absent, or `UIRequiresFullScreenIgnoredStartingWithVersion` is already set | The target sets `UIRequiresFullScreen`. iOS 27 ignores it and resizes the scene anyway. Refer to [TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key) |

Both keys in the last row stay exactly as you found them. Never delete `UIRequiresFullScreen`, because deletion makes the app resizable at once and the layouts may not be ready. Never add `UIRequiresFullScreenIgnoredStartingWithVersion`, because its value decides which releases keep the old behavior, and that is the developer's decision. A value of 27 or earlier makes the app fully resizable on iOS 27, which is the opposite of a safe step. The key comes out after the app handles resizing. Confirming that means running the app and resizing it. One view controller can break while the rest is correct.

---

## Workflow

### Phase 0: Fast Path for Simple Cases

**Before reaching for the decision tree, check if the occurrence matches the simple case.** A large fraction of `UIScreen.main`/`UIScreen.mainScreen` occurrences are simple substitutions inside a UIView/UIViewController instance method where the value is consumed fresh. These cases need no analysis — just substitute and move on:

| Original | Replacement |
|----------|-------------|
| `UIScreen.main.scale` (Swift) inside a UIView/UIViewController instance method, used inline (not stored) | `self.traitCollection.displayScale` |
| `[UIScreen mainScreen].scale` (ObjC) inside a UIView/UIViewController instance method, used inline (not stored) | `self.traitCollection.displayScale` |
| `UIScreen.main.scale` inside `layoutSubviews`, `drawRect:`, `updateConstraints`, or `viewIsAppearing:` | `self.traitCollection.displayScale` (no registration needed — UIKit auto-calls these on trait change) |

**Do not over-think simple substitutions.** If the enclosing class is `UIView`/`UIViewController` and the value isn't being assigned to an ivar, layer property, constraint, or stored image, just substitute. **Empty diffs on simple files are the most common mistake — apply the substitution and move on.** Reach for the decision tree only when the simple case doesn't fit (non-view class, cached value, class/static method, special user instructions).

### Phase 1: Detection

Identify patterns to modernize using each relevant task file's detection patterns. Run detection for every task in the Task Registry that applies to this codebase, not just one — see [Task Registry](#task-registry) below.

### Phase 2: Analysis

For each occurrence, read surrounding context to understand:
- Class hierarchy (UIView/UIViewController subclass vs plain NSObject vs non-view class)
- Method type (instance, static, free function, cached `dispatch_once` helper)
- Lifecycle phase (init, viewDidLoad, viewWillAppear, layoutSubviews)
- Code intent (what question the code was asking: available space, layout variant, rendering, device class, lifecycle)

The active task's reference file may add task-specific bullets to this list.

Use subagents to identify code that needs to be updated to keep your context window small.

### Phase 3: Decision & Validation

| Condition | Action |
|-----------|--------|
| Safe 1:1 replacement exists | **Apply it.** No added commentary (no `// TODO: FIXME`, no `// TODO`, no `// FIXME` — just the replacement). Use the replacement specified by the active task's reference file. |
| Multiple valid approaches or code relocation >10 lines | **Ask the user.** |
| No safe replacement possible (extremely rare) | **Add todo** with an explicit task outlined for the user. Never produce a silent empty diff. Re-check every pattern with a subagent before concluding nothing applies. |

Use subagents to validate against the active task's Post-file Checklist before any code change.

### Phase 3b: File Processing Completeness

**Process EVERY file that contains the target deprecated API.** Do not stop early, skip files, or silently drop files from the work queue. A file that was identified in Phase 1 but produces no diff and no skip explanation is a processing failure.

**Explicit file tracking:** At the start of processing, write out the complete list of files to be modified using available task / todo tools or a markdown file. As you process each file, mark it done. Before finishing, compare this list against your output — any file without a diff or an explicit skip reason is a failure that must be addressed before completing.

**Context size:** If you are concerned about context size, use subagents to process individual files or tasks.

**Silent-drop prevention:** Before finishing, use subagents to compare the list of files you were given against the list of files you produced output for. If any file is missing from your output, go back and process it. Common causes of silent drops:
- **File size:** Large files (1000+ lines) are not exempt. Process them with the same approach.
- **Complexity:** Files with preprocessor macros, complex class hierarchies, or unusual code patterns still need changes.
- **Project grouping:** Do not skip all files from a specific project or directory. If you notice you've dropped multiple files from the same project, that indicates a systematic issue — investigate and fix.
- **Ambiguity:** If you're unsure how to fix a file, ask the user — do not silently produce an empty diff.

**Large or complex files:** Files with heavy preprocessor usage (`#if`/`#ifdef` nesting), 1000+ lines, or less common patterns (C++ interop, `dispatch_once` caching, deeply nested macros) are not exempt from processing. If the target API appears in such a file, apply the same decision tree. If the file is too large to edit in one pass, process the deprecated API usages one at a time. Use subagents if helpful. If you genuinely cannot determine a safe replacement due to macro expansion or preprocessor complexity, ask the user — never silently skip it.

**Batch processing discipline:** When processing a list of files, do NOT attempt to analyze all files first and then produce all diffs at once. Instead, process files **one at a time or in small batches (3–5 files)**: read context, decide, produce the diff, then move to the next batch. This prevents the tail end of the file list from being silently dropped due to output limits or context exhaustion. If you notice you have produced output for fewer files than you were given, STOP and process the remaining files before finishing.

If you find empty diffs for files that should have straightforward replacements, go back and process them — straightforward files are fast to handle and should never be dropped.

### Phase 4: Implementation

Apply the active task's implementation gates, rules, and post-file checklist from its reference file. The pattern-specific decision tree, gate questions, and validation rules live alongside the patterns they govern in each task file. Use subagents for verification.

### Phase 5: Final Verification

**File coverage audit:** Use subagents to compare the list of files you were given (or detected in Phase 1) against the files you actually produced diffs for. Every input file must have a non-empty diff. If any file is missing changes, go back and process it now.

The active task's reference file may add task-specific verification steps.

---

## Task Registry

Apply every task in this registry to the codebase unless the developer's request explicitly scopes to a subset. Each task is independent and has its own detection patterns, decision tree, and verification rules in its reference file. Run them in order from top to bottom.

| Task | File | Description |
|------|------|-------------|
| UIScreen.main modernization | [uiscreen-task.md](references/uiscreen-task.md) | Replace `UIScreen.main` with context-appropriate APIs |
| userInterfaceOrientation modernization | [orientation-task.md](references/orientation-task.md) | Replace layout-related orientation checks with size classes or window bounds, and migrate the deprecated scene geometry callback |
| Scene lifecycle migration | [scene-lifecycle-task.md](references/scene-lifecycle-task.md) | Migrate AppDelegate to SceneDelegate |
| Safe Area Insets | [safe-area-task.md](references/safe-area-task.md) | Replace `topLayoutGuide` and `bottomLayoutGuide`, replace hard coded values for insets with safe area references, and ensure that existing references work with asymmetric safe areas and with insets that change while the app runs |
| userInterfaceIdiom modernization | [idiom-task.md](references/idiom-task.md) | Replace layout-related idiom checks with size classes, and read a genuinely needed idiom from the local trait collection |