# Gradio — GTK4 / half-elmish rewrite

Gradio is an internet radio player for GNOME. This branch is a from-scratch
GTK4 rewrite built on the half-elmish architecture: a full elmish-style
message/update loop (model, messages, commands, subscriptions) with an
imperative GTK4 view.

The GTK3 implementation and its libsoup 3 baseline live on the
`libsoup3-baseline` branch and the `v7.3-gtk3-baseline` tag. This branch has
no shared git history with it; it is a deliberate rewrite.

- **Architecture:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **B+hybrid escape hatch:** [docs/B_HYBRID.md](docs/B_HYBRID.md)
- **Agent conventions:** [AGENTS.md](AGENTS.md)

## Build

Requirements: `meson`, `ninja`, `vala`, `gtk4` (≥ 4.10), `gettext`.

```bash
meson setup builddir
meson compile -C builddir
meson test -C builddir        # headless — no display needed
./builddir/gradio
```

## Current state

This is the scaffold milestone:

- Gradio app ID, desktop file, appstream metadata, icons and GSettings schema
- GTK4 main window with Library, Discover, Collections and Settings pages
- Model/messages for page navigation and play/pause state
- Headless elmish and model tests

The radio-browser backend, library persistence, playback, MPRIS and search
provider are ported from the GTK3 branch in subsequent milestones.

## Packaging

**Arch Linux** — builds a package from the live work tree:

```bash
./scripts/build-package.sh              # → scripts/dist/*.pkg.tar.zst
./scripts/build-package.sh -C           # clean build
./scripts/build-package.sh -i           # install after building
```

**Flatpak** — builds the local tree:

```bash
flatpak-builder --user --install build-flatpak de.haeckerfelix.gradio.json
```

## License

Gradio is licensed under GPL-3.0-or-later; see [LICENSE.md](LICENSE.md).
Portions derived from the MIT-licensed GTK4 half-elmish template remain
available under MIT; see [LICENSE](LICENSE). The combined work is distributed
under GPL-3.0-or-later.
