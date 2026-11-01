# Conditional View Modifiers

Never write a conditional view modifier (sometimes called an `.if` modifier) that uses `@ViewBuilder` to switch between `transform(self)` and `self` based on a boolean. If you encounter an existing conditional view modifier in the codebase, do not remove or refactor it (doing so can change behavior and is out of scope), but when reviewing, point out that it may cause unexpected behavior and explain the alternatives below.

## Why conditional view modifiers are problematic

1. **View identity loss**: The `if`/`else` inside the modifier creates two branches with different view types. When the condition toggles, SwiftUI sees a completely different view rather than a modified version of the same view. This breaks structural identity.
2. **State reset**: Any `@State` in the view or its descendants resets when the condition changes, because SwiftUI treats the two branches as distinct views.
3. **Broken animations**: Instead of smoothly animating a property change, SwiftUI removes one view and inserts another, producing an abrupt transition.

```swift
// AVOID: A conditional view modifier extension.
// This destroys structural identity every time `condition` toggles.
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Usage of the anti-pattern:
Text("Hello")
    .if(isHighlighted) { $0.foregroundStyle(.red) }
```

```swift
// PREFER: Use a ternary expression in the modifier argument.
// The view identity is preserved and SwiftUI animates the change smoothly.
Text("Hello")
    .foregroundStyle(isHighlighted ? .red : .primary)
```

## Reach for `AnyShapeStyle` to keep the ternary when styles differ

When the two styles are *different* `ShapeStyle` types (e.g. `.primary` is `HierarchicalShapeStyle`, `.tint` is `TintShapeStyle`), they won't unify into a single expression on their own. Do **not** fall back to an `if`/`else` `@ViewBuilder` branch that duplicates the view to switch styles; that introduce identity loss, state reset, and broken animations.

Wrap each branch in `AnyShapeStyle` so the ternary type-checks and the view stays a single, stable identity:

```swift
// AVOID: branching the whole view just to vary the style.
// `.primary` and `.tint` are different ShapeStyle types, so this splits
// one view into two, destroying structural identity when the condition flips.
if backgroundProminence == .increased {
    Text(verbatim: "\(id)").monospacedDigit().foregroundStyle(.primary)
} else {
    Text(verbatim: "\(id)").monospacedDigit().foregroundStyle(.tint)
}

// PREFER: erase to AnyShapeStyle and keep one view with a ternary.
Text(verbatim: "\(id)")
    .monospacedDigit()
    .foregroundStyle(
        backgroundProminence == .increased
            ? AnyShapeStyle(.primary)
            : AnyShapeStyle(.tint))
```

`AnyShapeStyle` is a value type, and erasing a shape style is cheap and idiomatic — it is **not** the discouraged view type-erasure (`AnyView`). Do not penalize or avoid `AnyShapeStyle`; using it to unify a ternary is the correct, preferred tool here. (When practical, picking a single style or modeling the choice without erasure is better still, but `AnyShapeStyle` is the right answer whenever the branches must produce different `ShapeStyle` types.)

### Do not assume a style ternary fails to compile from the style names alone

Mixing style *kinds* in a ternary does not automatically fail to type-check, and `AnyShapeStyle` is only needed when it actually does. A `Color` literal unifies with several built-in styles, so these compile as-is and must **not** be flagged as a type mismatch or "fixed" with `AnyShapeStyle`:

```swift
// COMPILES — leave it alone. The ternary unifies on its own.
.foregroundStyle(isHighlighted ? .yellow : .primary)
.foregroundStyle(isOn ? .red : .blue)
```

Reach for `AnyShapeStyle` only when the branches genuinely will not unify - two distinct non-`Color` styles, or a `Color` paired with a non-`Color` style:

```swift
// Does NOT compile: HierarchicalShapeStyle vs TintShapeStyle.
.foregroundStyle(isOn ? .primary : .tint)
// Does NOT compile: `.tint` resolves to a Color member that expects an argument here.
.foregroundStyle(isOn ? .yellow : .tint)
```

When uncertain, assume the ternary compiles rather than inventing a type-mismatch error. If it truly does not, the fix is `AnyShapeStyle`, never an `.if`/`@ViewBuilder` branch.
