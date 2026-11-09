# half-elmish-template

A GitHub template for **Vala + GTK4** apps built on the **half-elmish**
architecture: a full elmish-style message/update loop (model, messages,
commands, subscriptions) with an imperative GTK view — the only deviation
from full Elm.

Includes a minimal working demo (a counter — button → dispatch → update →
view), the elmish core with `Cmd`/`Sub`/`Cmd.map` composition, and everything
a new GNOME-style app needs: meson build, i18n, appdata/desktop files, icons,
headless tests, Flatpak manifest, and an Arch Linux PKGBUILD.

- **Architecture docs:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — read
  this before extending the template.
- **B+hybrid escape:** [docs/B_HYBRID.md](docs/B_HYBRID.md) — when retained-native widgets need direct `notify`/`value_changed` coalesce.
- **Agent conventions:** [AGENTS.md](AGENTS.md)

## Build

Requirements: `meson`, `ninja`, `vala`, `gtk4` (≥ 4.10), `gettext`.

```bash
meson setup builddir
meson compile -C builddir
meson test -C builddir        # headless — no display needed
./builddir/half-elmish-template
```

## When to use B+hybrid

B+hybrid is **not** a second architecture — it is half-elmish plus a narrow imperative escape inside the view/model boundary ([docs/B_HYBRID.md](docs/B_HYBRID.md)). Only adopt when a retained-native widget forces it (WebView, Map, DrawingArea+drag). See [docs/MIGRATING_TO_HYBRID.md](docs/MIGRATING_TO_HYBRID.md) for the pattern.

## What the template demonstrates

| Pattern | Where |
|---|---|
| Plain-class messages + `kind` enum discriminator (ref-counted, type-safe, generic-arg-compatible) | `src/model/messages.vala` |
| Pure, testable `updateModel` | `src/app-update.vala` |
| GTK-free core library (headless tests) | `meson.build` (`lib_core`) |
| Async side effects via `Cmd`, dispatching results back | `src/elmish.vala`, `src/app-update.vala` |
| Component composition via `Cmd.map` (own message types per component) | `src/elmish.vala` |
| Coalesced view updates | `src/elmish.vala` |
| Thread-safe dispatch (worker → main loop marshalling) | `src/elmish.vala` |
| Subscriptions (`Sub`, event sources) | `src/elmish.vala` |
| Imperative GTK4 view (signals → messages, `update` reflects model) | `src/app-view.vala` |

## Tests

```bash
meson test -C builddir
```

- `test_update` — model behavior for every message kind (5 tests)
- `test_elmish` — the core itself: Cmd chains, dispatch-back, coalescing,
  subscriptions, thread marshalling, `Cmd.map`, plain-class messages (12 tests)

All run without GTK — the core library imports nothing from GTK.

## Naming: half-elmish?

The loop is full elmish (dispatch → pure update → Cmd), the view is the only
exception: imperative widget mutation instead of a pure render function —
exactly the split the F# ecosystem calls "half-elmish" (Elmish.Uno,
Elmish.XamarinForms' StaticView). Model, messages, and update never deviate
from full Elm. If you prefer stricter purity, only `updateView` needs to
change: render everything from `model` and drop the `msg` parameter.

## Renaming the template

The project is named `half-elmish-template` with app id
`com.example.half_elmish_template` and namespace `App` (core: `Elmish`).
To make it yours:

1. Pick a repo name, e.g. `my-app`, and an app id following the
   `com.github.<username>.<name>` convention (hyphens become underscores).
2. Update: `meson.build` (`project()`), `src/main.vala` (application id),
   `data/com.example.half_elmish_template.{desktop.in,appdata.xml.in}` (file
   names + content), the two SVGs under `data/icons/`, `po/meson.build`
   (gettext domain), the Flatpak manifest, and `scripts/PKGBUILD`
   (`pkgname`, `pkgdesc`).
3. Rename namespaces (`App` → yours) and the demo counter to your first
   feature — the whole point of a template.
4. Update `_("Elmish Counter")`-style strings and this README.

## Packaging

**Arch Linux** — builds a package from the live work tree (uncommitted changes
included):

```bash
./scripts/build-package.sh              # → scripts/dist/*.pkg.tar.zst
./scripts/build-package.sh -C           # clean build; safe — the checkout is never touched
./scripts/build-package.sh -i           # install after building
```

`makepkg -C` wipes only a throwaway copy in `$srcdir`; your source tree is
untouched (verified behavior). `pkgver` in `scripts/PKGBUILD` must be bumped
with releases.

**Flatpak** — `com.example.half_elmish_template.json` builds the local tree:

```bash
flatpak-builder --user --install build-flatpak com.example.half_elmish_template.json
```

## License

MIT — see [LICENSE](LICENSE). Template code is yours to relicense; MIT keeps
every migration path open (GPL, closed-source, ...).
