# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository.
Read `docs/ARCHITECTURE.md` first — it explains the half-elmish pattern this
codebase follows.

## Build / test / run

```bash
meson setup builddir
meson compile -C builddir
meson test -C builddir      # headless, no display needed
./builddir/gradio
```

Arch package: `./scripts/build-package.sh` (see README).

## Layout

- `src/elmish.vala` — generic half-elmish core (`ElmishProgram`, `Cmd`, `Sub`,
  `Dispatch`, `Cmd.map`). App-agnostic; treat as infrastructure.
- `src/model/messages.vala` — message classes + `Gradio.AppModel`.
- `src/model/radio-station.vala` — station data, JSON conversion, display text.
- `src/model/app-config.vala` — settings + station library stored as JSON.
- `src/commands.vala` — `Commands` factory (the injected IO boundary).
- `src/app-update.vala` — `updateModel`, the pure update function.
- `src/backend/` — libsoup HTTP, radio-browser search, GStreamer player.
- `src/app-runtime.vala` — production `Commands`: async search, playback,
  debounced config saves, player signal wiring.
- `src/app-view.vala` — main window and headerbar; `src/view/` holds the
  station row, details panel, player bar, and preferences dialog. Widgets
  exist only in the view layer.
- `src/main.vala` — wires the program: config load, AppRuntime, createView,
  updateModel, updateView, actions and accelerators.
- `tests/` — glib unit tests, no GTK.

## Rules (non-negotiable)

1. **All application state changes go through `dispatch(new XMessage(...))` →
   `updateModel`.** Never mutate the model from widgets, views, or callbacks.
2. **`updateModel` is pure**: only mutates the model and returns a `Cmd` or
   `null`. No IO, no dialogs, no GTK, no threads. Side effects go into the
   returned `Cmd` (the sub receives `dispatch` and can dispatch results back).
3. **Messages are PLAIN classes** (`Gradio.Message` subclasses: neither
   `GLib.Object` nor `[Compact]`) with the `MessageKind` enum discriminator,
   both declared in `src/model/messages.vala`. When adding a message, add the
   enum entry AND the class AND an `updateModel` case AND a test. Dispatch on
   `msg.kind`; read payloads with `is`/`as` casts (valid for plain classes).
   Do not switch messages to `[Compact]` classes or structs — valac rejects
   both as generic type arguments of the core (verified; see
   `docs/ARCHITECTURE.md`).
4. **View code only lives in `src/app-view.vala`** (or a new file under
   `src/view/` when the view grows). Widget signals become messages;
   `updateView` only re-renders from the model. Transient widget state (entry
   text, focus) may stay in the view. `updateView` must render from `model` —
   `msg` is a kind hint only, because coalescing delivers just the latest
   message of a burst (intermediate payloads are dropped).
5. **`string[]` is not ref-counted.** If a Cmd reads the model asynchronously,
   copy the array inside the sub.
6. **Tests go in `tests/`**, must compile without GTK, follow the existing
   `assert`-style (glib Test). Keep the core library GTK-free — that is what
   enables headless tests.
7. **Components**: each component owns its message type; lift child commands
   into the parent space with `Cmd.map` — never couple components to each
   other's messages.

## Style

- SPDX header `// SPDX-License-Identifier: MIT` on template-derived source
  files; new Gradio files use `// SPDX-License-Identifier: GPL-3.0-or-later`.
- Namespaces: `Elmish` (core), `Gradio` (app).
- User-visible strings go through `_()` (gettext).

## Verification before claiming a change works

1. `meson compile -C builddir` succeeds.
2. `meson test -C builddir` passes — including new tests for new messages.
3. If you touched the view: `./builddir/gradio` starts without errors.
