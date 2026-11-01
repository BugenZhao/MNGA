# Task: userInterfaceOrientation Modernization

## Overview

`userInterfaceOrientation` (on `UIApplication` and `UIViewController`) and `orientation` on `UIDevice` encode orientation as an enum. Layout code that branches on orientation does not adapt to modern iOS — under multitasking, Stage Manager, and resizable scenes, "portrait vs landscape" no longer maps cleanly to the available space.

**Detection patterns:**

- `UIApplication.shared.statusBarOrientation`
- `UIApplication.shared.windows` + orientation
- `UIDevice.current.orientation`
- `self.interfaceOrientation` (deprecated UIViewController)
- `UIWindowScene.interfaceOrientation` (deprecated UIWindowScene)
- `UIWindowScene.Geometry.interfaceOrientation` in a layout decision (current API, not deprecated)
- `windowScene(_:didUpdate:interfaceOrientation:traitCollection:)` (deprecated UIWindowSceneDelegate)
- Any comparison against `UIInterfaceOrientation` cases (`.portrait`, `.landscapeLeft`, etc.)

## The scene's interface orientation is not the replacement

`UIWindowScene.Geometry.interfaceOrientation`, reached as `windowScene.effectiveGeometry.interfaceOrientation`, is current API. Being current does not put it out of scope. A layout decision that reads it is a detection target, and it takes the same replacement as every other entry: a size class or a bounds comparison, per Step 2.

Interface orientation describes how the UI is rotated relative to the device reference. It does not encode an aspect ratio. A scene reporting a landscape orientation can be taller than wide, as a narrow iPad Split View column is. So rewriting `UIApplication.shared.statusBarOrientation` as `windowScene.effectiveGeometry.interfaceOrientation` renames the API and keeps the defect this task exists to remove. The same holds for the deprecated `UIWindowScene.interfaceOrientation`, whose modern spelling is the geometry property, not a different value.

Some code needs the interface orientation rather than the shape of the space. Two cases: distinguishing landscape-left from landscape-right, and driving a rotation transform or an animation direction. Those are not an invitation to swap one orientation source for another. Pattern 2 lists them as cases where the output is a TODO and the existing source stays put.

---

## Scope: Layout-Related Uses Only

**Only migrate uses that drive layout.** A use is layout-related if it:
- Appears in a `UIView` or `UIViewController` subclass (or extension)
- Appears in layout related methods like `layoutSubviews`, `updateProperties`, etc.
- Drives frame calculations, constraint setup, or visibility of UI elements
- Controls layout direction (horizontal vs vertical stacking)

**Leave non-layout uses alone** (camera capture, motion sensors, analytics, video recording). Add no TODO, make no change.

**One exception, in a scene delegate.** Pattern 4 migrates a deprecated `UIWindowSceneDelegate` callback. It therefore applies outside a view or view controller, and to work that is not layout, such as regenerating assets sized to the scene. The deprecated method is the target there. The work inside the callback is what the guard protects. Every other pattern in this task keeps the view and layout restriction above.

### Orientation Locking (Non-Layout)

For apps locking orientation (e.g., games), the modern API is `prefersInterfaceOrientationLocked` (iOS 26+). Override in VC and call `setNeedsUpdateOfPrefersInterfaceOrientationLocked()` when preference changes.

Outside this task's auto-fix scope. When encountering `supportedInterfaceOrientations` or forced orientation APIs, add a TODO:

```swift
// TODO: Modernization - Consider adopting `prefersInterfaceOrientationLocked` (iOS 26+)
// as the modern replacement for orientation locking via `supportedInterfaceOrientations`.
```

---

## Step 1: Classify the Purpose

| Category | How to recognize | Replacement approach |
|----------|-----------------|---------------------|
| **Constrained space removal** | Hides/removes UI in landscape to reclaim space | Size class check |
| **Aspect ratio detection** | Checks wider-than-tall to choose layout variant | Superview bounds comparison |
| **Subview flow direction** | Chooses horizontal vs vertical stacking | Size class or superview bounds |

---

## Step 2: Apply the Correct Replacement

### Pattern 1: Constrained Space → Size Class

| Original intent | Replacement |
|----------------|-------------|
| Narrow horizontal space (landscape iPhone) | `traitCollection.horizontalSizeClass == .compact` |
| Narrow vertical space (landscape iPhone hiding toolbar) | `traitCollection.verticalSizeClass == .compact` |

Use `self.traitCollection` in view/VC subclasses — never `UITraitCollection.current` when an instance is available.

---

### Pattern 2: Aspect Ratio → Compare Window Bounds (only when clearly equivalent)

**Do NOT replace with `width > height` heuristics when:**
- Code distinguishes **landscape-left vs landscape-right** — window bounds cannot distinguish these
- Orientation drives **animation direction or rotation transforms** — these depend on actual orientation
- Replacement requires inventing heuristics (checking `window.transform`) — never do this

In these cases, add a TODO explaining why bounds cannot substitute. Do not swap the source of the orientation either. `UIDevice.current.orientation` and `windowScene.effectiveGeometry.interfaceOrientation` are different values, and which one a rotation transform wants depends on what the content is rotating against. The TODO is the output here, and the developer decides which value the code wants.

**When replacement IS clearly equivalent (simple portrait-vs-landscape for layout):**

```swift
// After
if view.bounds.height > view.bounds.width {
    useVerticalLayout()
} else {
    useHorizontalLayout()
}
```

In view controller subclasses using `view` to check for the available size is correct. In view subclasses, using `superview` is appropriate.

---

### Pattern 3: Subview Flow Direction → Size Class or View Bounds

Choose based on context:
- Decision "compact vs regular" → use size class (Pattern 1)
- Decision purely geometric ("wider than tall") → use view bounds (Pattern 2)

```swift
// Geometric — is the available space taller than wide?
stackView.axis = view.bounds.height > view.bounds.width ? .vertical : .horizontal

// Trait-based — compact width means stack vertically
stackView.axis = traitCollection.horizontalSizeClass == .compact ? .vertical : .horizontal
```

---

### Pattern 4: Deprecated Scene Callback → didUpdateEffectiveGeometry

`windowScene(_:didUpdate:interfaceOrientation:traitCollection:)` is deprecated. The replacement for its geometry work is `windowScene(_:didUpdateEffectiveGeometry:)`.

**Everything in this pattern requires iOS 26 or later.** The replacement callback, `effectiveGeometry.coordinateSpace`, and `isInteractivelyResizing` all arrived in iOS 26.

- **Target is iOS 26 or later.** Apply the pattern. Replace the deprecated method.
- **Target is earlier.** Leave the deprecated method as it is. Add a TODO naming the replacement, and do not add the new callback. Do not use `@available`: a wrapped implementation does not run below the floor. Removing the deprecated method as well stops the app responding to geometry changes there. Supporting both releases needs both methods, which is a larger change than this task makes.
- **No target is discoverable**, as in a single file with no project. Assume the current SDK and apply the pattern.

**The deprecated method has four triggers, and the new one covers three.** The old callback fires on the coordinate space, the interface orientation, the trait collection, and a move between screens. UIKit guarantees both methods on a screen move, so screen-change work carries straight over. `UIWindowScene.Geometry` carries no trait, so the new callback never fires for a trait change alone.

Read the body before you delete the method. A body that depends on the trait collection needs a second destination. The deprecation attribute names it: traits inherited from the scene, read through the `traitCollection` of a view or a view controller. Move that work to `registerForTraitChanges` on the view that owns the value. A Dark Mode change, a Dynamic Type change, or a contrast change alters the traits and leaves the geometry alone. Moving such a body into the new callback alone stops the update running.

The rename alone is incomplete. Both parts below are required together, per Core Principle 12.

1. Implement `windowScene(_:didUpdateEffectiveGeometry:)` in place of the deprecated method. Carry over the geometry work and any screen-change work. Move trait work to the view that owns it.
2. Guard the body. Compare the value the work depends on against a copy the delegate stored, and do the work only when that comparison shows a change. Where the work is expensive and keyed on the scene's size, also require that the interaction has finished, by checking `isInteractivelyResizing` on the geometry.

**Read the current geometry from `windowScene.effectiveGeometry`, and do not read the parameter.** The parameter is the geometry as it was before this change; the body needs the geometry as it is now. Read the current value from the scene, and compare it against a copy the delegate stored on the previous call.

A body migrated from the deprecated callback often reads `windowScene.coordinateSpace` directly. That property is deprecated too, replaced by `effectiveGeometry.coordinateSpace` in the same release as this callback. Migrate that read in the same edit.

This is the one property outside this task's detection list that the task touches, and the exception is deliberate. The read sits inside the method being rewritten, so it is part of the change and not nearby code (Core Principle 9). Do not migrate such a read anywhere else in the file.

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private var lastSize: CGSize = .zero

    func windowScene(_ windowScene: UIWindowScene, didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry) {
        let geometry = windowScene.effectiveGeometry
        let size = geometry.coordinateSpace.bounds.size
        guard !geometry.isInteractivelyResizing, size != lastSize else { return }
        lastSize = size
        rebuildExpensiveContent(for: size)
    }
}
```

A body that does its work on every call is a regression rather than a migration. The callback arrives far more often than the size changes during an interactive resize. An unguarded body therefore runs its work repeatedly across one drag.

`isInteractivelyResizing` answers one question: is a user interaction resizing the scene right now. The callback runs again with the final geometry once the drag ends. The deferred work still happens, once instead of every frame.

Two limits on that check. It belongs on expensive work only, such as regenerating assets, rasterizing tiles, or fetching over the network. Constraints, `layoutSubviews`, and ordinary layout are built to run every frame, so gating them makes the resize lag the drag.

The check also does not replace the comparison. The callback reports any change to the scene's geometry, orientation and lock state included. Without the size comparison, the work reruns when the size it depends on did not change.
