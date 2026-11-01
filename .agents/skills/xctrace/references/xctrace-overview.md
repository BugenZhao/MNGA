---
name: xctrace-overview
description: Load this skill first whenever xctrace comes up for any reason, and whenever the user wants to do any profiling, performance, or optimization work — for example, finding out why an app is slow, uses too much CPU or memory, or stops responding, or wanting to optimize a piece of code and measure the result. Covers capturing traces, and opening and reading `.trace` and `.atrc` (Apple Trace) files from the command line. Gives a concise orientation and points to the other skills in this plugin.
---

# xctrace overview

`xctrace` is Apple's command-line interface to Instruments.
It is used for two main purposes: capturing traces, and opening and reading `.trace` and `.atrc` (Apple Trace) files.

`xctrace`'s command surface can change between tool versions.
Before relying on any specific subcommand or flag, refresh your understanding by running the following, in order:

1. `xctrace help` — lists the currently available top-level commands.
2. `xctrace help <command>` — shows the options for a specific command.
3. `man xctrace` — the most thorough reference, including usage examples. You can skip the `man` page if the previous commands already provide sufficient understanding.

## Other skills in this plugin

- **xctrace-hangs-triage** — guidance for using the `xctrace triage --style hangs` command.

## Using Tools

### Exploring file content

Summaries provided by `triage` often take advantage of a subset of information available in a trace.
`xctrace` provides a set of commands designed to efficiently explore and read all available information.

#### File organization

Note that `xctrace` is just a CLI interface for Instruments.
Instruments is meant to provide users with a rich GUI experience; `xctrace` is a CLI interface on top of that experience.
The GUI is organized into the following hierarchical structure:

 - *File*: either a `.trace` file or an `.atrc` file containing all the tracing data and symbols
 - *Run*: a *File* may contain one or more distinct profiles called *Run*, which can be identified either by number or name.
 - *Track*: information in each run is divided into logical units called *Tracks*. There are two kinds of tracks: *Instrument Tracks* and *Dynamic Tracks*.
   i. *Instrument Tracks*: have constant titles and are defined by the Instruments used in the *Run*. There is always one *Instrument Track* per Instrument.
   ii. *Dynamic Tracks*: the number of tracks and their titles is based on the recorded data according to a prototype. For example, there is a prototype for all "Process" tracks and all instances of the "Process" track share the same features. However, there is no actual track with the title "Process".
 - *Details*: Each *Track* has one or more *Details*. A Detail presents data related to the track arranged in a specific view. The most common views are:
   i. *List*: Data are presented in a table.
   ii. *Summary*: Data are presented in a hierarchical structure, with mathematical operations applied to the underlying data, such as SUM, AVERAGE or STANDARD DEVIATION.
   iii. *Call Tree*: A call tree is a hierarchical structure of function calls. There is a more detailed explanation in the following section.

#### Navigating the file

Let us assume that the user has provided a file and a run.
`xctrace` provides a set of commands used to navigate the file, exploring *Tracks* and *Details*.
Those commands are designed to be used in the following file exploration flow:

**1. Use Table of Contents**

Table of Contents command is invoked via `xctrace toc`.
This command reveals what *Instrument Tracks*, *Dynamic Track* prototypes and details are available.
Table of Contents result has two sections: the first section lists the *Instrument Tracks* while the second section lists the *Dynamic Track* prototypes.
Let us suppose that the result of a Table of Contents call is the following (the example is heavily truncated):

```
os_signpost
├── [summary] Summary: Intervals (schema: OSSignpostIntervals)
└── [list] List: Intervals (schema: OSSignpostIntervals)
Time Profiler
└── [calltree] Profile (schema: time-profile)
SwiftUI
└── [summary] Summary: All Updates (schema: swiftui-updates)
    ├── focus: [summary] Downstream Updates (schema: swiftui-updates)
    ├── focus: [list] Updates (schema: swiftui-updates)
    └── focus: [calltree] View Hierarchy (schema: swiftui-updates)

Details for dynamic tracks
os_signpost / OS Logging Subsystem
├── [summary] Summary: Intervals (schema: OSSignpostIntervals)
└── [list] List: Intervals (schema: OSSignpostIntervals)

Process
└── [calltree] Profile (schema: time-profile)

Process / Thread
└── [calltree] Profile (schema: time-profile)
```

The `os_signpost` and `Time Profiler` tracks in the first section are *Instrument Tracks* and contain details `Summary: Intervals`, `List: Intervals` and `Profile`.
All of these details can already be queried by the `xctrace show` command, because the names of the tracks and details are constant.
On the other hand, `os_signpost / OS Logging Subsystem`, `os_signpost / OS Logging Subsystem / OS Logging Category`, `Process` and `Process / Thread` are *Dynamic Track* prototypes.
The tool `xctrace show` can only query concrete tracks, so we first need to learn the actual titles of the tracks represented by these prototypes.

**2. Exploring Dynamic Tracks**

What actual *Dynamic Tracks* are included in a Run can be revealed using command `xctrace list tracks`.
To expand a *Dynamic Track* prototype, copy its entire title from the "Details for dynamic tracks" section of the table of contents and pass it to the `--type` option.

Prototypes may appear both at the top level, such as "Process", and nested inside an *Instrument Track*, such as "os_signpost / OS Logging Subsystem".
Either way, the approach is the same: `xctrace list tracks --type "Process"` reveals a list of process names, and `xctrace list tracks --type "os_signpost/OS Logging Subsystem"` reveals the subsystems recorded under os_signpost.

The result always lists all concrete tracks matching the prototype, so it can be quite long.
It is recommended to use `grep` in order to filter the results.
For example, if a user is only interested in Threads inside of a process Calculator with PID 12345, the command printing all threads of Calculator may look like this: `xctrace list tracks --type "Process/Thread" | grep 'Calculator (12345)/'`.

**3. Using the Show command**

Following the previous examples, let us print a summary of os_signposts from the AppKit framework.

We have already printed the Table of Contents in step 1; now let us print the available dynamic tracks for os_signpost as per step 2:

```
xctrace list tracks --type "os_signpost/OS Logging Subsystem"
os_signpost/com.apple.AppKit
os_signpost/com.apple.coreanimation
os_signpost/com.apple.FileURL
```

It appears that signposts are present for the AppKit framework.
Now we have everything we need to know in order to execute a show command:

```
xctrace show --track "os_signpost/com.apple.AppKit" --summary "Summary: Intervals"
ID        Category / Name / Start Message / End Message                    Count   Duration  Min Duration  Avg Duration  Std Dev Duration  Max Duration
122176:0  * All *                                                             76  209.38 ms      22.25 µs       2.76 ms          15.18 ms     105.34 ms
122820:1  ├─ Application                                                       1    4.21 ms       4.21 ms       4.21 ms               n/a       4.21 ms
122820:2  │  └─ Deactivation                                                   1    4.21 ms       4.21 ms       4.21 ms               n/a       4.21 ms
122820:3  │     └─ BundleID=com.apple.example, LIWDT=0.                        1    4.21 ms       4.21 ms       4.21 ms               n/a       4.21 ms
122820:4  │        └─  enableTelemetry=YES                                     1    4.21 ms       4.21 ms       4.21 ms               n/a       4.21 ms
122176:1  ├─ UpdateCycle                                                      74   99.83 ms      22.25 µs       1.35 ms           9.51 ms      81.85 ms
122176:2  │  ├─ EventDispatch                                                 37   88.70 ms      22.25 µs       2.40 ms          13.44 ms      81.85 ms
56948:2   │  └─ UpdateSequence                                                37   11.13 ms      47.29 µs     300.78 µs         852.18 µs       3.89 ms
2116:1    └─ UpdateCycle.Stalls                                                1  105.34 ms     105.34 ms     105.34 ms               n/a     105.34 ms
2116:2       └─ UpdateSequence                                                 1  105.34 ms     105.34 ms     105.34 ms               n/a     105.34 ms
```
**4. Focus Destinations**

Some Details have *Focus Destinations*: these focused Details show the data associated with a row.
Focus Destinations are listed with `focus:` prefix below the connected Detail in the table of contents, and in a footer at the end of `xctrace show`. Example:

```
This detail has 1 focus destination; follow it with --focus <ID> --title <label>:
  [list] List: Intervals (schema: OSSignpostIntervals)
```

To follow a Focus Destination, pass the row's ID to `--focus` option and the name of the Focus Destination to the `--title` option.
Focusing is useful when you need the individual rows that were merged into a summary row or call tree node.
For example, to list every interval merged into `UpdateCycle` in the summary above (it has a single destination, so no `--title` is needed):

```
xctrace show --track "os_signpost/com.apple.AppKit" --summary "Summary: Intervals" --focus "122176:1" --title "List: Intervals"
```

### Reading Call trees

A call tree is a prefix tree of backtraces collected during a program's execution, where individual nodes are stack frames.
This tree is used to analyze the cost of individual parts of the program.
A call tree can be built upon two different models:

 - *stochastic call trees*: Usually produced by sampling instruments, such as CPU Profiler or Time Profiler. Backtraces are sampled at regular intervals and are given a weight corresponding to the interval since the last sample was taken. Such a call tree does not give a *complete* picture.
 - *deterministic call trees*: Most commonly encountered when looking at System Call Calltree, Allocations Calltree or Filesystem Calltree. All events monitored by such an instrument (system calls, allocations) are recorded and all events have backtraces. This means that such a call tree offers a complete understanding of a measured metric.

#### Sorting and Arranging Columns

Call Trees are rendered as hierarchical tables.
Most Call Trees contain the following columns:

 - "Symbol Names": the stack frames of backtraces
 - "# Samples": a 'metric' describing how many backtraces are passing through this node
 - "Library Name": name of the library the symbol belongs to

There also might be any number of different 'metrics'.
Each 'metric' column comes with a matching 'Self metric' column.
The 'Self metric' column contains a value which was measured directly within that function.
A node's 'metric' value is the sum of its own 'Self metric' and the 'Self metric' values of all its descendants.

Columns can be arranged by using the option `--arrange-columns`.
Note that not all columns are visible by default.
The option `--arrange-columns` takes a string argument `<arrangement expression>`.

The `<arrangement expression>` is a list of column names separated by character `|`.
A special token `...` is used to indicate where the default columns are supposed to be displayed.
Every token can be used at most once in any expression.
As a general rule, "Symbol Names" is always displayed by default, "Library Name" and "# Samples" are always hidden by default.

Examples:

 - `--arrange-columns "Library Name|..."` will display the column "Library Name" followed by all other columns.
 - `--arrange-columns "# Samples|...|Library Name|Symbol Names"` will display the "# Samples" as the first column, followed by default columns and then "Library Name" and "Symbol Names". While "Symbol Names" is one of default columns, it will only be displayed once with precedence given to the explicit place used in the expression.

There are also special CLI-only columns which always appear as a prefix in the CLI outputs.
Those columns are:

 - "is heaviest" (only in `markdown` formatting) indicating that the node belongs to the heaviest stack trace. The "is heaviest" column is always the first column and nodes belonging to the heaviest stack trace have a single "*" in that column. Use `grep '|\*|'` to extract just the frames of the heaviest stack.
 - "tree level" in `markdown` formatting, "tree level" is used to indicate the depth of the stack frame in the tree hierarchy instead of the whitespace which is used in the `text` formatting.
 - "ID" each node is associated with a Node ID which can be used to identify a specific node in a specific call tree with a specific configuration.

It is possible to sort nodes according to a specific column, for example: `--sort "# Samples"`.
By default, the tree is sorted according to the first visible column which contains a 'metric'.
Column "Symbol Names" is always used as a tie breaker.

#### Inspecting Frames

The `xctrace` CLI can be used to project call tree data to the source code or assembly corresponding to a given stack frame.
This can be achieved via the option `--source`.
Neither source code nor disassembly may always be available.
Using option `--include-source-info` will reveal source code location in the "Symbol Names" column.
Frames with source code location present are likely to work when using `--source`.

The `--source-mode` may be useful, for example when trying to analyze what Swift Runtime calls are made in the analyzed function.

### Symbolication

A Call Tree may sometimes contain symbols which are labeled with an address instead of a name.
This is due to missing symbolication data.
Symbolication is the process of mapping addresses from memory to the names of functions they belong to.
Symbolication data might be contained within binaries themselves or in a dedicated `.dSYM` file.
An unsymbolicated label in a Call Tree can look like this:

```
0x10ba0fb8c (TestBinary +0xa2fb97) <67ERTE70-5899-1D59-XG44-347625943P58>
```

 - `0x10ba0fb8c`: return address on the stack
 - `TestBinary`: name of the binary
 - `+0xa2fb97`: offset of the return address from the load address of the binary
 - `67ERTE70-5899-1D59-XG44-347625943P58`: UUID corresponding to a specific build of the binary

Building the same library twice (even if the source code is exactly the same) may produce different binaries - for example, individual functions may be laid out in a different order.
The UUID can be used to determine whether a `.dSYM` (or a binary with symbolication data) corresponds to the binary which was traced.

If `.dSYM` (or a binary with symbolication data) can not be located automatically, ask user to provide it.

After the user has provided matching `.dSYM`s (or binaries with symbolication data), `xctrace symbolicate` can be used to add symbols to the `.trace` file.
In order to avoid confusion, it is possible to check what the UUID of a `.dSYM` (or a binary with symbolication data) is via the utility `dwarfdump`.
Executing `dwarfdump <path to .dSYM or binary with symbolication data> --uuid` will print UUIDs for each architecture contained within:

```
$ dwarfdump /path/to/dSYM/or/binary/with/symbolication/data/TestBinary.dSYM --uuid
UUID: 67ERTE70-5899-1D59-XG44-347625943P58 (arm64) /path/to/dSYM/or/binary/with/symbolication/data/TestBinary.dSYM/Contents/Resources/DWARF/TestBinary
```

## Tips and tricks

- Where possible, use `markdown` formatting, which arranges call trees and outlines into a markdown table.
- Some outputs, such as call trees, can be very long. Plan to redirect or filter them rather than rely on raw terminal output.
- Call trees come with built-in metrics that depend on the instrument. For example, a CPU Profiler usually comes with Samples (number of backtraces) and Cycles (number of CPU cycles elapsed), while a Time Profiler usually comes with Samples and Weight (elapsed time). When in doubt about which metrics are present, inspect the columns of the call tree.

| Command | Length | Commentary |
|---|---|---|
| `xctrace triage` | 100s of lines | We're trying to provide concise results by default. |
| `xctrace show` | 100s of kilobytes | `show` can be potentially very expansive because, depending on the configuration, the result might be worth an entire database table of data. |
| `xctrace toc` | usually <200 lines | Schema of the file, the length mostly depends on the number of instruments included in the run. |
| `xctrace list` | 100s of lines | Schema of the recorded data, the length mostly depends on what events were observed during recording.  |

## Common pitfalls

- Avoid writing scripts that count whitespace to infer node depth.
- It is almost always better to use `xctrace show` than `xctrace export`. The `show` command presents curated data, while the `export` command is a tool printing the raw data as XML.
- When specifying time, do NOT use real numbers, use integers. The default unit is nanoseconds (ns). Feel free to also use seconds (s), milliseconds (ms), or microseconds (us) — as long as you use integers. Negative integers are not permitted.
