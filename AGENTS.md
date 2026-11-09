# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository.
Read `docs/ARCHITECTURE.md` first — it explains the half-elmish pattern this
codebase follows.

## Build / test / run

```bash
meson setup builddir
meson compile -C builddir
meson test -C builddir      # headless, no display needed
./builddir/half-elmish-template
```

Arch package: `./scripts/build-package.sh` (see README).

## Layout

- `src/elmish.vala` — generic half-elmish core (`ElmishProgram`, `Cmd`, `Sub`,
  `Dispatch`, `Cmd.map`). App-agnostic; treat as infrastructure.
- `src/model/messages.vala` — message classes + `AppModel`.
- `src/app-update.vala` — `updateModel`, the pure update function.
- `src/app-view.vala` — GTK4 view. The only file where widgets exist.
- `src/main.vala` — wires the program: createView, updateModel, updateView,
  init command, subscriptions.
- `tests/` — glib unit tests, no GTK.

## Rules (non-negotiable)

1. **All application state changes go through `dispatch(new XMessage(...))` →
   `updateModel`.** Never mutate the model from widgets, views, or callbacks.
2. **`updateModel` is pure**: only mutates the model and returns a `Cmd` or
   `null`. No IO, no dialogs, no GTK, no threads. Side effects go into the
   returned `Cmd` (the sub receives `dispatch` and can dispatch results back).
3. **Messages are PLAIN classes** (`App.Message` subclasses: neither
   `GLib.Object` nor `[Compact]`) with the `MessageKind` enum discriminator,
   both declared in `src/model/messages.vala`. When adding a message, add the
   enum entry AND the class AND an `updateModel` case AND a test. Dispatch on
   `msg.kind`; read payloads with `is`/`as` casts (valid for plain classes).
   Do not switch messages to `[Compact]` classes or structs — valac rejects
   both as generic type arguments of the core (verified; see
   `docs/ARCHITECTURE.md`).
4. **View code only lives in `src/app-view.vala`.** Widget signals become
   messages; `updateView` only re-renders from the model. Transient widget
   state (entry text, focus) may stay in the view. `updateView` must render
   from `model` — `msg` is a kind hint only, because coalescing delivers just
   the latest message of a burst (intermediate payloads are dropped).
5. **`string[]` is not ref-counted.** If a Cmd reads the model asynchronously,
   copy the array inside the sub.
6. **Tests go in `tests/`**, must compile without GTK, follow the existing
   `assert`-style (glib Test). Keep the core library GTK-free — that is what
   enables headless tests.
7. **Components**: each component owns its message type; lift child commands
   into the parent space with `Cmd.map` — never couple components to each
   other's messages.

## Style

- SPDX header `// SPDX-License-Identifier: MIT` on every source file.
- Namespaces: `Elmish` (core), `App` (app).
- User-visible strings go through `_()` (gettext).

## Verification before claiming a change works

1. `meson compile -C builddir` succeeds.
2. `meson test -C builddir` passes — including new tests for new messages.
3. If you touched the view: `./builddir/half-elmish-template` starts without
   errors.
