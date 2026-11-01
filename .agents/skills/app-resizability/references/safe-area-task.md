# Task: Safe Area Inset Modernization

## Overview

Older layouts hardcoded the heights of status bars (20pt), navigation bars (44pt), tab bars (49pt), and home indicators (34pt). They positioned content with `topLayoutGuide` and `bottomLayoutGuide`. Modern iOS exposes the same geometry through `safeAreaInsets` and `safeAreaLayoutGuide`, which already encode the current device, orientation, and split view configuration. Update code that hardcodes those numbers, re-uses one edge's inset for the opposite edge, or infers display geometry from inset values.

Two more assumptions break on modern iOS. Both appear in code that uses `safeAreaInsets` correctly in other respects.

**An inset can hold a leading or trailing edge for the life of the scene.** On some devices, and in some configurations, the system puts a vertical bar on one of those edges. The bar arrives as a horizontal safe area inset. That inset stays for as long as the configuration lasts. It is not a landscape condition, and it is not a sensor housing. Code that treats a horizontal inset as a temporary landscape artifact puts content under the bar.

**An inset can change at any time, including with no change in size.** A scene resizes while the app runs. For example: a window is dragged, display dimensions change, a split view collapses, or a bar appears or disappears. An inset read once is wrong from the first change onward.

An inset derived from a width or a size class is worse. It is wrong whenever the inset changes and the size does not. A vertical bar does exactly that.

**Detection patterns:**

- Deprecated guides:
  - `topLayoutGuide`, `bottomLayoutGuide`
- Hardcoded bar heights used as constraint constants or in `UIEdgeInsets`:
  - Common literal values to look for: `20` (status bar), `44` (navigation bar), `64` (status + nav), `88` (status + large nav), `34` (home indicator), `49` (tab bar), `83` (tab + home indicator).
  - Patterns: `.constant = <literal>` for those values, `UIEdgeInsetsMake(<literal>, ...)`, `UIEdgeInsets(top: <literal>, ...)`.
- Symmetry and asymmetry mistakes with `safeAreaInsets`:
  - The same edge accessor used on opposite anchors, for example `safeAreaInsets.left` applied to leading **and** trailing, in a ternary or a paired calculation.
  - `max(safeAreaInsets.left, safeAreaInsets.right)` applied to both sides.
  - Threshold checks such as `safeAreaInsets.top > <literal>`, `safeAreaInsets.left > 0`, or `safeAreaInsets.bottom > 0` used as a proxy for display geometry.
  - `UIDevice` model checks gating layout decisions.
- A horizontal inset treated as an orientation condition:
  - A horizontal inset read only inside a landscape check, a `bounds.width > bounds.height` comparison, or a size class check.
  - A leading or trailing constraint whose constant is zero in one orientation and an inset in the other.
- A stored inset:
  - A safe area inset assigned to a property, an ivar, a `lazy var`, or a `static let`.
  - An inset read in `init`, `viewDidLoad`, `awakeFromNib`, `viewWillAppear`, or any one-time setup method.
  - A constraint constant computed once from an inset with no path to update it.
  - `additionalSafeAreaInsets` set from a stored or previously read value.
- An inset derived rather than read:
  - A helper that returns insets given a width, a size class, a screen, or a device model.
- An inset read from the wrong object:
  - `view.window?.safeAreaInsets`, `UIApplication.shared` reached for insets, or an ancestor's insets used for a child's layout.
- Content pinned to the wrong edges:
  - A view holding text, controls, or a list constrained to the superview's `topAnchor`, `bottomAnchor`, `leadingAnchor`, or `trailingAnchor` rather than to the safe area guide.
  - A full-bleed layer and its content pinned to the same edges, so the content bleeds with the background.
- Scroll view inset handling:
  - `contentInsetAdjustmentBehavior` set to `.never`.
  - `contentInset` or `scrollIndicatorInsets` assigned from `safeAreaInsets`.
  - `adjustedContentInset` read and then a safe area inset added on top of it.
- Layout margin asymmetry and system minimum overrides:
  - The same edge accessor used on opposite anchors, for example `layoutMargins.left` applied to leading **and** trailing, in a ternary or a paired calculation.
  - `max(layoutMargins.left, layoutMargins.right)` applied to both sides.
  - `viewRespectsSystemMinimumLayoutMargins = NO` or `false` without a justifying comment.
- Keyboard avoidance computed by hand:
  - A `UIKeyboardWillShowNotification` or `keyboardWillChangeFrame` observer that reads `UIKeyboardFrameEndUserInfoKey` and applies it to a constraint, an inset, or a frame.
  - A keyboard frame used without converting it from screen coordinates, or converted once and stored.
- Manual frame math:
  - Hardcoded numeric offsets in `layoutSubviews`, `viewWillLayoutSubviews`, or manual `frame =` assignments that must derive from `safeAreaInsets`.
- SwiftUI:
  - `ignoresSafeArea()` called with no edges.
  - Bar content placed in a `ZStack` or an `overlay` with its own bottom or side padding.
  - Hardcoded horizontal padding that stands in for a side inset.
  - `GeometryReader` used to read insets for a layout decision.
  - An inset from a `GeometryProxy` applied as padding inside the view that reported it.
  - A bar edge inferred from a size class, a width comparison, or a device check rather than read from the environment.

Read the surrounding context before you treat any literal as a target. Confirm it is a bar offset and not a font size, an animation duration, or a touch target dimension.

---

## Rules

Audit the code and apply the following changes.

Every rule applies to Swift and to Objective-C, except Rule 13, which is SwiftUI only. The API names are the same in both languages.

## 1. Replace deprecated layout guides

Both guides are `UIViewController` properties, and `UIViewController` has no safe area guide of its own. Every replacement therefore goes through `view`. Map each spelling:

- `topLayoutGuide.bottomAnchor` → `view.safeAreaLayoutGuide.topAnchor`
- `bottomLayoutGuide.topAnchor` → `view.safeAreaLayoutGuide.bottomAnchor`
- `topLayoutGuide.length` → `view.safeAreaInsets.top`
- `bottomLayoutGuide.length` → `view.safeAreaInsets.bottom`
- `topLayoutGuide.topAnchor` → `view.topAnchor`

The last mapping is the trap. That anchor is the top of the view, not the top of the safe area. Mapping it to the guide pushes content down by the whole top inset.

## 2. Fix hardcoded status bar and navigation bar offsets

Remove literals such as `20`, `44`, `64`, `88`, `34`, `49`, and `83` used to clear a bar or a home indicator. Constrain to `safeAreaLayoutGuide` instead. For manual layout, read `safeAreaInsets` in `layoutSubviews`.

## 3. Constrain to the safe area instead of superview edges

- Pin to `safeAreaLayoutGuide` anchors when a view must not underlap a bar or a device inset.
- Pin to the superview when a view must extend under bars, such as a background fill or a media surface.
- For a scroll view, pin the frame to the superview and let the scroll view adjust its own content inset. Rule 7 covers that case.

## 4. Layout margins

- Do NOT assume left and right layout margins are equal. Read each edge's own value instead of reusing one side for the other.
- Report `viewRespectsSystemMinimumLayoutMargins = false` and change nothing. It narrows the margins below the system minimum, which may be deliberate, and the file rarely says why. Tell the developer where it is and let them decide.
- Use `layoutMarginsGuide` for content that must be inset by the system standard amount.

## 5. Handle `safeAreaInsets` in manual layout

- Replace hardcoded inset values in `layoutSubviews` and in manual frame math with `safeAreaInsets` from the view being laid out.
- Read the inset in the layout method itself. Rule 9 states why a value read anywhere else goes stale.

## 6. Remove assumptions about inset symmetry and hardware placement

**Asymmetric horizontal insets are the normal case.** Where a vertical bar is present, one horizontal edge usually carries the whole inset and the other carries zero. Which edge carries it changes with the orientation and with the display in use.

The inset is also much larger than the horizontal insets of earlier devices. Symmetric-inset code gives away, or overdraws, a large part of the width. Treat it as wrong by default.

- Do NOT assume left and right insets are equal. Either edge can carry an inset while the other carries none. The two values are unrelated.
- Do NOT assume top and bottom insets are equal, or that one follows from the other. They vary independently by device, orientation, and window size.
- Do NOT treat a horizontal inset as a landscape condition. It can be present in portrait, in landscape, in a window, and in a split view column. An orientation branch leaves content under the inset everywhere else.
- Do NOT infer which edge carries an inset from the device, the model, the orientation, the size, or the size class. Orientation is one input among several, so it is never sufficient on its own. This holds for a sensor housing, a notch, a Dynamic Island, and a vertical bar alike. Interface orientation is a poor proxy: two physically different poses report the same orientation and the same geometry.
- Read each edge's own inset value. An average, a maximum, or one edge applied to both sides collapses an asymmetric pair into one number. No single number is correct for both edges.
- Do NOT test an inset against a threshold to decide whether a safe area exists. A layout never needs to know whether there is an inset, only how large it is, and applying a zero inset is already correct. So delete the test and the branch it gates, and apply the inset directly.
- **Subtracting both horizontal insets from one total width is correct.** `bounds.width - safeAreaInsets.left - safeAreaInsets.right` accounts for both edges and needs no direction mapping. Leave that expression alone.

Watch for these shapes:

- `safeAreaInsets.top` used for both top and bottom.
- `safeAreaInsets.left` used for both left and right.
- One "horizontal inset" computed from `safeAreaInsets.left` and applied to both sides.
- `max(safeAreaInsets.left, safeAreaInsets.right)` applied to both sides.
- A device model string or a `UIDevice` check used to locate a hardware obstruction.
- A named hardware constant subtracted from an inset, such as a sensor housing height. The inset already accounts for the hardware, so the subtraction double-counts it. Delete the constant and the arithmetic around it.

### Asking which edge holds a vertical bar

Read `traitCollection.verticalBarEdge` (iOS 27.1).

A read inside a layout method needs nothing else. UIKit tracks the traits a layout pass reads, so it lays the view out again when the edge changes.

A read anywhere else needs a registration in the same edit. Call this from a view controller. In a `UIView` subclass, call `setNeedsLayout()` on `self`.

```swift
registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) { (self: Self, _) in
    self.view.setNeedsLayout()
}
```

Two limits on that trait. It resolves to `leading` or `trailing`, which follow layout direction, while `safeAreaInsets` uses physical edges. And `unspecified` is ambiguous: it covers both a configuration where no bar is possible and one where a bar is allowed but the edge is not resolved. Read the inset when you need the size of the space.

### `safeAreaInsets` is physical; `safeAreaLayoutGuide` resolves direction

`safeAreaInsets` describes the physical enclosure. `.left` is the physical left in both layout directions, and it never means *leading*.

- Constrain to `safeAreaLayoutGuide.leadingAnchor` or `.trailingAnchor` when the code means a direction. Do NOT read `.left` or `.right` there.
- The same rule applies where the code writes. `additionalSafeAreaInsets` is a `UIEdgeInsets`, so a value set on `left` lands on the trailing side in a right-to-left layout.
- A container's offsets follow the rule too. A split view reports a column's offset as an inset on that column. It lands in `.left` in one direction and in `.right` in the other. A constraint to the guide is correct in both.

## 7. UIScrollView considerations

- Let the scroll view adjust its own content inset. `.automatic` is already the default, so the edit a legacy app needs is removing an assignment of `.never`.
- Do NOT add safe area insets on top of `adjustedContentInset`. That value already contains them.

## 8. Preserve existing visual behavior

- Do NOT change layouts that are intentionally edge to edge, such as backgrounds, media players, and maps.
- Adjust only content that must respect the safe area. The goal is correctness on modern devices, not a redesign.

## 9. Never store a safe area inset

An inset read once describes one configuration. The next resize, rotation, or bar change makes it wrong, and nothing tells the stored copy to update. An inset read before the view reaches a window is zero, so a one-time read caches zero permanently.

- Do NOT assign a safe area inset to a property, an ivar, a `lazy var`, a `static let`, or a file-scope static.
- Delete the property the inset was stored in, and every read of it. A property left behind is always zero, and it still reads as a value the layout uses.
- Do NOT read an inset in `init`, `viewDidLoad`, `awakeFromNib`, or `viewWillAppear`. The first three run before the view reaches a window, so they read zero.
- Read the inset where you lay out: `layoutSubviews`, `viewWillLayoutSubviews`, or `viewDidLayoutSubviews`.
- Prefer constraints against `safeAreaLayoutGuide`. They need no client work, because the guide updates before any change notification arrives.
- Do NOT compute an inset from a width, a size class, a screen, or a device model. A horizontal inset can appear and disappear with no change in size, so no function of size gives the right answer. Replace a helper of the form `insets(forWidth:)` with a read from the view that lays out.

### Responding to a change

- Use `safeAreaInsetsDidChange()` or `viewSafeAreaInsetsDidChange()` to invalidate layout, not to recompute a cached copy. Call `super` in the view controller override, which requires it.
- Do NOT read a dependent view's frame in the callback. Views constrained to the guide keep their old frames until the next layout pass. Call `setNeedsLayout()` and let layout run.
- Call `setNeedsUpdateConstraints()` instead when the read lives in `updateConstraints`. `setNeedsLayout()` does not re-run that method.
- A change can arrive inside an animation. Constraints against the guide animate with it. Frames computed by hand in the callback do not.
- One transition can deliver more than one inset set, and the first can be incomplete. Reading at layout time avoids building a layout from a half-updated set.
- **`additionalSafeAreaInsets` carries only the extra space, never the safe area itself.** The property adds to the system insets rather than replacing them. Assign the amount your own chrome needs and nothing else. A value built as the current safe area plus your toolbar counts the safe area twice.

## 10. Use `keyboardLayoutGuide` for keyboard avoidance

A keyboard notification reports a frame in screen coordinates. An app that occupies part of the screen has to convert it, and the converted value goes stale on the next resize. That is the same defect as reading a screen or a window instead of your own view.

- Constrain content to `view.keyboardLayoutGuide`. It tracks the keyboard with no observer and no conversion.
- Remove the notification observer and the stored frame once the constraint replaces them.
- Keep an observer only where the app does something other than layout, such as scrolling to a field or ending an edit.

## 11. Read insets from the view that lays out

Insets are set per view, not per window. An ancestor's value is not a stale version of a child's value. It is a different value.

- Read `safeAreaInsets` from the view whose content you are positioning. Not the window, not `UIApplication.shared`, not an ancestor, and not another view controller.
- A presented view carries insets its window does not. A popover's content view and its window report different values, in either direction.
- A sheet carries its own inset for a vertical bar. Its content is inset even where the presenting view is not, so a sheet's layout has to read its own view.
- Two sibling split view columns differ from each other, and both differ from the window. One column can carry a bar's inset while the other carries none.
- Do NOT look for a container's contribution in `additionalSafeAreaInsets`. The contribution is composed into each view's own `safeAreaInsets` instead.
- Two scenes of one process report different geometry at the same moment. No global answer exists to read. Follow Core Principle 11.

## 12. Corner intrusions, when manual layout needs numbers

`safeAreaInsets` does not describe a rounded corner. A view with zero horizontal insets can still have content clipped at its corners.

`safeAreaLayoutGuide` does not handle corners either. Its constants come from `safeAreaInsets` unchanged, so constraint-based code needs the same fix as manual layout. Ask for a corner-adapted region (iOS 26):

- Constraint-based code: constrain to `view.layoutGuide(for: .safeArea(cornerAdaptation: .horizontal))`.
- Manual layout: read `view.directionalEdgeInsets(for: .safeArea(cornerAdaptation: .horizontal))`, which returns direction-resolved values.

Both equal the plain safe area in every other respect. Use them only where a corner can clip content.

## 13. SwiftUI safe areas

SwiftUI reports safe areas differently from UIKit, so the UIKit advice above does not carry over. Apply this rule only in files that are already SwiftUI.

- `EdgeInsets` is directional. `leading` means leading and flips with layout direction. The physical-edge problem in Rule 6 does not exist here, so change nothing for it.
- A `GeometryProxy` reports a `size` that is already inset, unlike `view.bounds`. That size is the region the content can use.
- Read `@Environment(\.toolbarVerticalEdge)` when SwiftUI code must know which edge holds a vertical bar (iOS 27.1). It is the counterpart to `traitCollection.verticalBarEdge` in Rule 6, it resolves to `leading` or `trailing`, and it needs no registration because a `View` re-evaluates when the environment changes. It is `nil` where the system never places a bar.
- The insets a `GeometryProxy` reports describe the space the view was offered, not the region it ended up with. Its frame already starts at the leading offset, so applying a reported inset as padding inside that view counts the inset twice. Let the framework place the content.

### Choosing the modifier

Choose by what the content is.

- Use `safeAreaBar(edge:)` for bar content (iOS 26). Below that deployment target use `safeAreaInset(edge:)`. It places the content the same way, and it gives up two things: the bar appearance, and the extended scroll edge effect on any scroll view the inset affects.
- Use `safeAreaInset(edge:)` for other content beside the inset region.
- Use `safeAreaPadding` to add a fixed margin measured from the safe area rather than from the view edge.

### Bar content stacked as an overlay

A bar in a `ZStack` or an `overlay` covers the content behind it. Repadding it leaves it covering that content. `safeAreaBar(edge:)` reserves the bar's space as well as placing it, so move the bar out of the stack.

This applies only when the stacked layer is bar content. A background, an artwork layer, a gradient, or a scrim is not a bar. A `ZStack` that puts one thing behind another is doing its job, so leave that structure alone. The test is whether the layer holds controls the layout must reserve space for.

### Hardcoded padding standing in for an inset

`safeAreaPadding` does not read or track the inset. It adds a fixed amount *into* the safe area, so the number survives and is measured from the safe area rather than from the view edge.

That is why converting a stand-in literal to `safeAreaPadding` fixes nothing. A literal that exists to clear a bar or a device inset is still a literal, and it still cannot follow an inset that appears at runtime. **Delete it.** The framework already places content inside the safe area, so no horizontal padding is the correct result.

Reach for `safeAreaPadding(edge, length)` only where the margin is a design value in its own right, one the layout wants even with no inset present. Pass the length when you do: the form with no length substitutes the system default and silently replaces a designed number.

### Scoping `ignoresSafeArea`

Name the edges the content must reach in the `edges:` parameter, and name only those.

- A bare `ignoresSafeArea()` extends content under every edge, including one that holds a vertical bar. That is wrong for content the user reads or touches.
- It is correct on a layer meant to reach every edge: a background fill, an artwork backdrop, a gradient, or a scrim. Leave those alone.
- `.all`, and a list naming every edge, mean the same thing as the bare call. Neither is a scope.
- The first parameter selects safe area *regions*, not edges. A value such as `.container` on its own scopes nothing, and it needs an `edges:` argument beside it.
- The modifier does not set the reported insets to zero. It stops the view from honoring them. A view that ignores the safe area and then reads `safeAreaInsets` gets values that no longer describe its content.

### Reading insets in SwiftUI

Do NOT use `GeometryReader` to read insets for a layout decision. Stop needing the number instead of finding another way to read it: `safeAreaInset(edge:)`, `safeAreaBar(edge:)`, and `safeAreaPadding` place content against the safe area without handing you a value to apply yourself.

Reading `proxy.size` is a different matter and stays fine. A size is the region the content can use, so a decision made from it is sound. Subtracting insets from it is the defect, because that size is already inset.

A `View` also re-evaluates whenever its inputs change, including on every frame of a live resize, so nothing needs caching.

## Constraints

- Do NOT convert UIKit code to SwiftUI, and do NOT add dependencies. Rule 13 applies only to files that are already SwiftUI.
- Make the smallest change that fixes each issue.
- Do NOT modify a file that has no issues.
