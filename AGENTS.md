# AGENTS.md

Read `docs/ARCHITECTURE.md`.

## Build / test / run

```bash
meson setup builddir
meson compile -C builddir
meson test -C builddir
./builddir/gradio
```

Arch package: `./scripts/build-package.sh`

## Layout

- `src/elmish.vala` — elmish core (`ElmishProgram`, `Cmd`, `Sub`, `Cmd.map`)
- `src/model/` — messages, `AppModel`, stations, config, sorting, filters,
  validation, transfer
- `src/commands.vala` — `Gradio.Commands` IO boundary
- `src/app-update.vala` — `updateModel`
- `src/app-runtime.vala` — production `Commands`
- `src/backend/` — HTTP, radio-browser, player, config store, file IO,
  favicons, MPRIS, sleep inhibitor, search provider
- `src/cast/` — mDNS, Cast connection and service, protobuf encoding
- `src/app-view.vala`, `src/view/` — GTK widgets
- `src/main.vala` — program wiring
- `tests/` — headless glib tests

## Rules

1. State changes: `dispatch(new XMessage(...))` → `updateModel` only. Never
   mutate the model from views or callbacks.
2. `updateModel`: mutate model, return `Cmd` or `null`. No IO, dialogs, GTK, or
   threads.
3. Messages: plain classes + `MessageKind` in `src/model/messages.vala`. No
   `GLib.Object`, no `[Compact]`, no structs. Add enum entry, class, update
   case, test. Dispatch on `msg.kind`; payloads with `is`/`as`.
4. View code: `src/app-view.vala` or `src/view/`. Signals → messages.
   `updateView` renders from `model`; `msg` is a kind hint only. Transient
   widget state stays in the view.
5. Copy `string[]` if a Cmd reads it asynchronously.
6. Tests: `tests/`, no GTK, glib Test.
7. Components own their message type; lift child commands with `Cmd.map`.

## Style

- SPDX: MIT on template-derived files, GPL-3.0-or-later on new Gradio files.
- Namespaces: `Elmish`, `Gradio`.
- User-visible strings: `_()`.

## Verify

1. `meson compile -C builddir`
2. `meson test -C builddir`
3. View changes: `./builddir/gradio` starts without errors.
