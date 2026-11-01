---
name: xctrace-hangs-triage
description: Guidance for investigating app hangs, freezes, or unresponsive/stuck UI (for example, "the app is frozen" or "the UI stopped responding") using xctrace's `triage --style hangs` command against a recorded trace. If you load this skill, load `xctrace-overview` as well.
---

# xctrace hangs triage

## What is a hang

A hang is a period during which an app's main thread cannot respond to user input or update the UI within an acceptable time.
The user perceives a hang as the app freezing, becoming unresponsive to taps or gestures, or failing to animate.

## Hang severity

`triage --style hangs` classifies every reported hang into one of five tiers, ordered from lightest to most severe by duration:

- **Potential Interaction Delay** — the lightest tier, above 33ms. Mainly useful for tracking down causes of hitches, but this tier is still reported by the Hangs instrument itself, not the Animation Hitches template.
- **Brief Unresponsiveness** — above 100ms.
- **Microhang** — above 250ms.
- **Hang** — above 500ms.
- **Severe Hang** — above 2s. Risks the user force-quitting the app, or the system treating it as unresponsive.

True animation and scroll frame drops are a distinct concept, covered by the "Animation Hitches" template in Instruments, not by `triage --style hangs`.
`triage` has no dedicated style for them.

## Busy vs. blocked hangs

Before diving into a hang's call tree, establish which of the following categories it falls into.
This steers the rest of the analysis toward the right data.

- **Busy hang** — the blocking thread shows high CPU utilization while blocking the UI. Emphasis should be given to the time profile.
- **Blocked hang** — the blocking thread shows low CPU utilization while blocking the UI. Emphasis should be given to system calls.

A hang can be a combination of both, for example a thread that is busy for part of the hang and blocked on a system call for the rest.
Even so, establishing which category dominates first helps steer the analysis before looking at the combined case.

## Common pitfalls

- When confirming a hypothesis, drilling down or determining a root cause, look beyond just Profiler data. Profiling data is important, but there are other data sources which may paint more complete picture and complement what the Profiler shows. You can explore available data sources using the `xctrace toc` command.
- If you don't have sufficient data to diagnose the hang, ask the user to capture a new trace with the data you need.
