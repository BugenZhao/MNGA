# Task: User Interface Idiom Modernization

## Overview

`userInterfaceIdiom` encodes a device class, not the space a view actually has. Apps already run at many sizes: Split View, Slide Over, Stage Manager, iPhone Mirroring, and external displays. An idiom check therefore does not predict how much room the layout has. `UIDevice.current` also reports the device rather than the environment the code is rendering in, so it can disagree with the context the view is actually in.

**Detection patterns:**

- `UIDevice.current.userInterfaceIdiom` / `UIDevice.currentDevice.userInterfaceIdiom`, and the ObjC bracket form `[[UIDevice currentDevice] userInterfaceIdiom]`
- `UITraitCollection.current.userInterfaceIdiom`
- `UIUserInterfaceIdiomPad` / `UIUserInterfaceIdiomPhone`, and `.pad` / `.phone` in Swift. Also `.tv`, `.carPlay`, `.mac`, and `.vision` when they gate layout
- `UI_USER_INTERFACE_IDIOM()` — deprecated since iOS 13
- `#if targetEnvironment(macCatalyst)` and `ProcessInfo.processInfo.isiOSAppOnMac` when either drives layout
- App-defined idiom macros and helpers: `IS_PAD`, `isiPad`, `isPad`, `isPhone`, `deviceIsPad`
- A layout decision that already reads `traitCollection.userInterfaceIdiom` locally. Reading it from the right place does not make it the right question; Pattern 1 still applies

App-defined helpers are the target site. Fix the helper, not only its callers. Renaming such a helper and updating its call sites in the same file is in scope, even though the call-site lines do not themselves contain the target API.

---

## Scope: Layout and Available-Space Uses Only

**Migrate uses that decide layout or react to available space.** A use is in scope if it:

- Chooses a layout variant (one column vs two, sidebar vs stack, grid column count)
- Decides whether UI is shown, hidden, or relocated to reclaim space
- Sets sizes, spacing, insets, or font metrics that exist because "iPad is bigger"
- Picks a presentation style that is really about room (`.formSheet`/`.popover` vs full screen)

**Leave out of scope, with no change and no TODO:** device-specific asset or resource names, analytics and telemetry dimensions, `.vision` / `.tv` / `.carPlay` platform branches, App Store or entitlement gating, and test fixtures that construct a specific idiom deliberately.

**Out of scope, so leave it alone here:** an idiom check driving `supportedInterfaceOrientations` or any other orientation mask. Do not convert it to a size class, and do not remove any existing comment or TODO attached to it.

**One exception, and it is a source change only.** An idiom read that is correct as written, and that drives UI behavior, must read from the local trait collection when one is reachable, keeping the same comparison and the same branches. This includes a hardware capability gate, such as a pointer or hover affordance. The trait reflects the scene the code renders in, and `UIDevice.current` cannot, because one process can drive scenes with different idioms. When no trait collection is reachable, and reaching one would mean changing a signature or its callers, ask the user how to proceed (Core Principle 5). A read that reports the device rather than the environment keeps `UIDevice.current`, including analytics dimensions and per-device asset names.

---

## Step 1: Classify the Purpose

| Category                     | How to recognize                                                    | Replacement                                 |
| ---------------------------- | ------------------------------------------------------------------- | ------------------------------------------- |
| **Available space**          | Two columns, sidebar, popover, wider margins on pad                 | Horizontal size class                       |
| **Constrained height**       | Hides a bar or shrinks a header on phone                            | Vertical size class                         |
| **Genuine idiom dependence** | Any decision that truly turns on idiom, not on space                | Keep idiom, but read it locally (Pattern 2) |
| **Product decision**         | Feature exists on one device but not because of space               | Ask the user (Core Principle 5)             |

When the intent is not clear from the code, it is the fourth row. Ask; do not guess which size class the designer meant.

---

## Step 2: Apply the Correct Replacement

### Pattern 1: Available space → size class

| Original intent | Replacement |
|---|---|
| "iPad, so there is room for the wide layout" | `traitCollection.horizontalSizeClass == .regular` |
| "iPhone, so use the narrow layout" | `traitCollection.horizontalSizeClass == .compact` |
| "iPhone landscape, so vertical space is tight" | `traitCollection.verticalSizeClass == .compact` |

```swift
// Before
if UIDevice.current.userInterfaceIdiom == .pad {
    stackView.axis = .horizontal
} else {
    stackView.axis = .vertical
}

// After
if traitCollection.horizontalSizeClass == .regular {
    stackView.axis = .horizontal
} else {
    stackView.axis = .vertical
}
```

Use `self.traitCollection` in `UIView` and `UIViewController` subclasses. Never substitute `UITraitCollection.current`, and never reach `UIDevice.current` or `UIScreen.main` for this.

**The mapping is not one to one, and that is the point.** An iPad in a narrow Split View reports `.compact` horizontally, and a large iPhone in landscape reports `.regular`. The old code asked the wrong question; the replacement asks about space, which is what the layout needed.

**Pick the axis the code is actually about.** Width decisions (columns, sidebars, popovers, horizontal margins) use `horizontalSizeClass`. Height decisions use `verticalSizeClass`:

```swift
// Before — hides the tall header on phone because vertical room is tight
headerView.isHidden = UIDevice.current.userInterfaceIdiom == .phone

// After
headerView.isHidden = traitCollection.verticalSizeClass == .compact
```

Mapping a height decision onto `horizontalSizeClass` is the most common inversion. A phone in landscape is `.compact` vertically and can be `.regular` horizontally, so the two are not interchangeable.

### Pattern 2: Genuine idiom dependence → read the idiom locally

When the check really is about idiom, keep the check and change where the value comes from. `UITraitCollection` carries `userInterfaceIdiom`, and it reflects the environment the view is in, which is what the code wants. `UIDevice.current.userInterfaceIdiom` describes the hardware and does not vary by context, so prefer the trait collection and treat `UIDevice.current` as a last resort.

```swift
// Before — the Mac idiom draws a window title bar, so the in-app header duplicates it
customHeaderView.isHidden = UIDevice.current.userInterfaceIdiom == .mac

// After
customHeaderView.isHidden = traitCollection.userInterfaceIdiom == .mac
```

An `else` branch keeps working unchanged, because `UIUserInterfaceIdiomUnspecified` falls to it exactly as it did before the edit. No extra handling is required.

If the stored result of a Pattern 2 check is cached, it needs invalidation like any other trait-derived value. Refer to the invalidation section below.

### Where to read the trait collection from

| Enclosing type | Source |
|---|---|
| `UIView` / `UIViewController` subclass, instance method | `self.traitCollection` |
| Non-view class holding a view or view controller (property or parameter) | That object's `traitCollection`, preferring the most local one |
| Non-view class with no view reachable at all | Add a `traitCollection: UITraitCollection` parameter and update the callers to pass their own |

A read does not need new API when a view is reachable. Use the reachable object's trait collection and make the smallest edit.

### Pattern 3: Read what an app-defined helper actually tests

An `IS_PAD` macro or `isiPad` helper is not always a plain `idiom == .pad`. Some cover additional cases, and Mac Catalyst reports the `.pad` idiom unless the app is built as Optimized for Mac, so a helper written years ago may be relied on to be true there. Read the definition before rewriting any call site; narrowing it to `idiom == .pad` can silently change behavior.

For a layout use, Pattern 1 removes the question entirely, because a size class check covers every case the helper covered. When the use is genuinely about idiom, preserve each case the helper tested:

```objc
// Before — helper covers more than one idiom
if (IS_PAD) { ... }

// After — genuine idiom use, every case the helper covered is preserved
UIUserInterfaceIdiom idiom = self.traitCollection.userInterfaceIdiom;
if (idiom == UIUserInterfaceIdiomPad || idiom == UIUserInterfaceIdiomMac) { ... }
```

**A global or `static` helper is deleted, not rewritten.** A `static let isPad = UIDevice.current.userInterfaceIdiom == .pad` has no environment and no trait collection to read, and it evaluates once per process, so it can never follow a resize. Delete it and read the size class in each view that used it. This is the one case where the fix lands at the call sites rather than at the helper.

---

## Invalidation: the replaced value is no longer fixed

This is the regression this migration introduces. `UIDevice.current.userInterfaceIdiom` is fixed for the life of the process, so caching a decision derived from it at `init` was safe. Both replacements are traits, and traits change: a size class changes whenever the scene resizes, and the trait collection's `userInterfaceIdiom` is inherited per trait environment rather than being a process-wide constant. The same cached decision that was safe before the edit is now stale.

Whenever a trait drives a stored value (a constraint constant, an ivar, a configured subview, a cached layout choice), register for the change:

```swift
registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: MyView, previousTraitCollection) in
    self.updateLayoutForSizeClass()
}
```

> **ObjC:** `[self registerForTraitChanges:@[UITraitHorizontalSizeClass.class] withHandler:^(typeof(self) self, UITraitCollection *previousTraitCollection) { ... }]`, or `withAction:@selector(updateLayoutForSizeClass)`.

Register for the trait you actually read: `UITraitHorizontalSizeClass`, `UITraitVerticalSizeClass`, or `UITraitUserInterfaceIdiom` for a cached Pattern 2 value. Where an `update…` method already exists, the handler calls it by name rather than duplicating its body.

**These APIs need iOS 17, Mac Catalyst 17, tvOS 17, or visionOS 1, or later.** `registerForTraitChanges` and its trait types, such as `UITraitHorizontalSizeClass`, do not exist before then. With an earlier deployment target, put the same recalculation in `traitCollectionDidChange:`, which UIKit still calls on later releases.

**A trait read during `init` is not yet meaningful.** A view that is not in a window reports `UIUserInterfaceSizeClassUnspecified`, so setup code reading the size class in `initWithFrame:` or `awakeFromNib` gets the fallback branch. The registration is what delivers the first correct value, which is another reason it is not optional here.

**Two ways to satisfy this, and either is acceptable.** Register and recalculate as above, or move the read to the point of use so nothing is cached. From those same releases, UIKit tracks the traits an override reads from its own trait collection, then invalidates that method when one of those traits changes. Registration is therefore not needed inside `layoutSubviews`, `drawRect:`, `updateConstraints`, `viewWillLayoutSubviews`, `viewDidLayoutSubviews`, `updateViewConstraints`, or `updateConfiguration`. `updateProperties` joins them in iOS 26, and [Automatic trait tracking](https://developer.apple.com/documentation/UIKit/automatic-trait-tracking) lists every supported method. This is OS behavior rather than new API, so an existing binary gets it with no rebuild. Pick one; do not leave a cached value with no invalidation path.

**When the enclosing type cannot register.** `registerForTraitChanges` requires a `UITraitChangeObservable`, which a plain `NSObject` helper is not. In that case do not cache: read the trait from the reachable view at the moment the value is used, rather than once in a stored property or `lazy var` initializer. Moving the read is the fix; a TODO is not.

---

## SwiftUI

The replacement is the environment value:

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
@Environment(\.verticalSizeClass) private var verticalSizeClass

// Before
.padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 32 : 16)
if UIDevice.current.userInterfaceIdiom != .phone { heroHeader }

// After — test `.regular`, so a nil size class takes the narrow branch
.padding(.horizontal, horizontalSizeClass == .regular ? 32 : 16)
if verticalSizeClass == .regular { heroHeader }
```

nil means the environment has no size class, the same state UIKit reports as `unspecified`. Write "there is room" as `== .regular`, never as `!= .compact`: with an Optional the two differ, because `!= .compact` is also true when the size class is absent.

A height decision reads `@Environment(\.verticalSizeClass)` instead. The axis rule from Pattern 1 applies unchanged.

**Nothing to register for.** SwiftUI re-evaluates the body when the environment changes, so a `View` that reads the environment directly needs none of the invalidation work above.

**When there is no environment to read.** The size class describes the space available to the view that reads it, so read it in a `View` or a `ViewModifier`. `@Environment` also resolves in an `App` or a `Scene`, where there is no such view, so do not drive layout from it. A model, view model, or other non-`View` type receives the size class as a parameter on each call, or the decision moves into the view. Do not store it on that type unless absolutely necessary. Doing so adds the burden of keeping it up to date on every resize.

**At the UIKit boundary.** In a `UIViewRepresentable` or a `UIViewControllerRepresentable`, read `context.environment.horizontalSizeClass` in `makeUIView` and `updateUIView`. A SwiftUI view hosted in a `UIHostingController` inherits the host's traits, so its environment already reflects the host and needs no plumbing.

**Pattern 2 has no SwiftUI equivalent.** There is no idiom environment value, so leave a remaining `UIDevice.current.userInterfaceIdiom` in place rather than inventing a source.

---

## Post-file Checklist

- [ ] Every migrated site was a layout or available-space decision, not a product or capability decision?
- [ ] An idiom-derived orientation mask (`supportedInterfaceOrientations`) left unconverted?
- [ ] Replacement reads a local trait collection, not `UITraitCollection.current`, `UIDevice.current`, or `UIScreen.main`?
- [ ] Non-view class with a reachable view → used that view's trait collection, without adding a parameter it did not need?
- [ ] Non-view class with no reachable view → signature changed and callers updated?
- [ ] A trait drives a stored value → either `registerForTraitChanges` with a handler that recalculates it, or the read was moved to the point of use?
- [ ] Cached Pattern 2 value → registered for `UITraitUserInterfaceIdiom`, not a size class trait?
- [ ] SwiftUI view reads `@Environment(\.horizontalSizeClass)` or `@Environment(\.verticalSizeClass)`, not `UIDevice.current`?
- [ ] App-defined idiom helper → its definition was read, and every idiom case it covered is preserved?
- [ ] App-defined idiom helper fixed at the helper, not only at its call sites?
- [ ] Out-of-scope uses (assets, analytics, platform branches, tests) left untouched, with no TODO?
- [ ] Branch count unchanged? An idiom `if`/`else` stays an `if`/`else`.
- [ ] Vertical space decision mapped to `verticalSizeClass`, not `horizontalSizeClass`?

## API Reference

- [UITraitCollection](https://developer.apple.com/documentation/uikit/uitraitcollection)
- [EnvironmentValues.horizontalSizeClass](https://developer.apple.com/documentation/swiftui/environmentvalues/horizontalsizeclass)
