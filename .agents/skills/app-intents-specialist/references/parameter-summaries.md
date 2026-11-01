# Parameter Summaries

`static var parameterSummary` builds the sentence the Shortcuts editor renders for your intent, and the DSL is small: `Summary("…\(\.$x)…") { \.$y }` for the static case, `When(\.$p, .equalTo, v) { … } otherwise: { … }` and `Switch(\.$p) { Case(v) { … } }` for the conditional cases. `Summary`, `When`, `Switch`, `Case`, and `DefaultCase` are typealiases the `AppIntent` protocol vends, so you write them unqualified inside the intent. Every trap below comes from the DSL doing something the plain-English reading of it doesn't suggest — the order the editor shows fields, which fields it shows at all, and what a `When` condition is actually allowed to test.

## The visible order follows the summary, not your `@Parameter` declaration order

`ParameterSummaryString` records the key paths in interpolation order, then the trailing `@ParameterKeyPathsBuilder` block appends its key paths after them. That combined list — not the order you declared the `@Parameter`s in — is the order the Shortcuts editor lays out the fields. So reordering properties in the struct changes nothing; reordering the interpolations (and the block) is the only lever. (Which parameters appear at all is `parameters.md`'s subject — this file is about the order and the conditional shape.)

```swift
// AVOID: assuming the editor mirrors declaration order. You declared amount first,
// but the summary interpolates recipient first — so the editor shows recipient
// above amount. Editing the property order to "fix" the layout does nothing.
@Parameter(title: "Amount")    var amount: Double
@Parameter(title: "Recipient") var recipient: PersonEntity
static var parameterSummary: some ParameterSummary {
    Summary("Send \(\.$recipient) \(\.$amount)")
}
```

```swift
// PREFER: drive the layout from the summary. The field order is exactly the
// interpolation order, then the trailing block — this reads "Send <amount> to
// <recipient>" and lays the editor out that way, regardless of declaration order.
static var parameterSummary: some ParameterSummary {
    Summary("Send \(\.$amount) to \(\.$recipient)") {
        \.$memo
    }
}
```

## A `When` condition tests one parameter's value to show or hide others — the tested key path must be a real `@Parameter`

`When(_:_:_:otherwise:)` takes a key path to an `IntentParameter`, a comparison operator, a value, and two `Summary` blocks: the `when` block applies when the condition holds, the `otherwise` block when it doesn't. It is a value test on an existing parameter, not a general predicate — the first argument must be `\.$someParameter` for a parameter that actually exists on this intent, and the comparison value must match that parameter's type. Use it to reveal parameters only when they're relevant, so the editor isn't cluttered with fields that don't apply.

```swift
// AVOID: hand-writing an "if" that the editor can't see, and mutating parameter
// visibility from perform(). The summary is static metadata read at edit time;
// perform() runs far too late to influence which fields Shortcuts drew. Every
// parameter you interpolate here shows unconditionally.
static var parameterSummary: some ParameterSummary {
    Summary("Create \(\.$kind) event \(\.$recurrenceRule)")
}
@Parameter(title: "Kind")     var kind: EventKind      // AppEnum: .single, .repeating
@Parameter(title: "Repeat")   var recurrenceRule: RecurrenceEntity
```

```swift
// PREFER: gate the extra parameter with When, keyed off the parameter that
// decides its relevance. recurrenceRule appears only for repeating events; for a
// single event the otherwise branch omits it, so the editor stays clean.
static var parameterSummary: some ParameterSummary {
    When(\.$kind, .equalTo, .repeating) {
        Summary("Create \(\.$kind) event \(\.$recurrenceRule)")
    } otherwise: {
        Summary("Create \(\.$kind) event")
    }
}
```

## Pick the `When` comparator that matches the parameter's type — the operators are separate enums

The comparison operator is not one big enum; the initializer overloads accept different operator types, so a mismatch fails to compile rather than doing the wrong thing at runtime. `.equalTo` / `.notEqualTo` are `EquatableComparisonOperator` and need a matching value. `.hasNoValue` / `.hasAnyValue` are `HasValueComparisonOperator` and take no value (test presence of an optional parameter). `.oneOf` is `OneOfComparisonOperator` and takes an array. `.lessThan` / `.lessThanOrEqualTo` / `.greaterThan` / `.greaterThanOrEqualTo` are `ComparableComparisonOperator` for `Comparable` values. Reaching for `.equalTo` with an array, or passing a value to `.hasAnyValue`, is a type error — not a silent no-op.

```swift
// AVOID: using an equality comparator to mean "is one of these" or "is set". These
// don't type-check: .equalTo wants a single value, not an array, and .hasAnyValue
// takes no value at all — the presence check has its own no-argument overload.
static var parameterSummary: some ParameterSummary {
    When(\.$priority, .equalTo, [.high, .urgent]) {   // wrong: .equalTo isn't array-shaped
        Summary("Flag \(\.$task)")
    } otherwise: {
        Summary("Add \(\.$task)")
    }
}
```

```swift
// PREFER: .oneOf for membership (takes an array); the no-value overload for
// "is this optional parameter set". Each operator lives in its own enum, so the
// value shape is dictated by the comparator you chose.
static var parameterSummary: some ParameterSummary {
    When(\.$priority, .oneOf, [.high, .urgent]) {
        Summary("Flag \(\.$task) with \(\.$reason)")
    } otherwise: {
        Summary("Add \(\.$task)")
    }
}
```

## `Switch`/`Case` branch a summary over one parameter's discrete values — cover the rest with `DefaultCase`

For a parameter with several discrete values, `Switch(\.$param) { Case(value) { Summary(…) } … }` is clearer than nesting `When`s. Each `Case` takes a single value or an array of values (`Case([.a, .b])`) and a `Summary` block; `DefaultCase { Summary(…) }` covers everything not matched. Because it is a `switch`-style construct, a value that hits no `Case` and has no `DefaultCase` has no summary to render — add a `DefaultCase` so every possible value maps to something.

```swift
// AVOID: a Switch that omits DefaultCase while the Cases don't cover every value.
// mode is an AppEnum with three cases but only two are handled — when mode is the
// third value, no branch matches and the editor has no summary to show for it.
static var parameterSummary: some ParameterSummary {
    Switch(\.$mode) {
        Case(.photo) { Summary("Capture photo \(\.$resolution)") }
        Case(.video) { Summary("Record video \(\.$resolution) \(\.$frameRate)") }
    }
}
@Parameter(title: "Mode") var mode: CaptureMode   // AppEnum: .photo, .video, .timelapse
```

```swift
// PREFER: handle the covered values explicitly and route the rest through
// DefaultCase, so every value of mode maps to a summary. Case also accepts an
// array — Case([.photo, .timelapse]) — when several values share one layout.
static var parameterSummary: some ParameterSummary {
    Switch(\.$mode) {
        Case(.video) { Summary("Record video \(\.$resolution) \(\.$frameRate)") }
        DefaultCase { Summary("Capture \(\.$mode) \(\.$resolution)") }
    }
}
```

## A literal `%` in the summary string is auto-escaped — type it once

The summary format string uses `%`-prefixed tokens internally to mark where each interpolated parameter goes, so a literal percent sign in your text has to be escaped. The string interpolation does this for you: literal segments have `%` doubled to `%%` automatically. So write the percent once, as you'd say it — do not pre-escape it yourself, or you'll get a doubled `%%` in the rendered sentence.

```swift
// AVOID: manually escaping the percent. The literal is already escaped for you, so
// "%%" here becomes "%%" on screen — a stray doubled sign in the shortcut label.
static var parameterSummary: some ParameterSummary {
    Summary("Apply \(\.$discount)%% off")
}
```

```swift
// PREFER: write the percent once. The interpolation doubles it internally so the
// token machinery is unambiguous, and the user sees a single "%".
static var parameterSummary: some ParameterSummary {
    Summary("Apply \(\.$discount)% off")
}
```
