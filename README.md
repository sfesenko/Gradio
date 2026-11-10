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

Requirements: `meson`, `ninja`, `vala`, `gtk4` (≥ 4.10), `libsoup-3.0`,
`json-glib`, `gstreamer`, `gettext`.

```bash
meson setup builddir
meson compile -C builddir
meson test -C builddir        # headless — no display needed
./builddir/gradio
```

## Current state

Gradio is a usable single-list radio player:

- One library list; `+` opens a radio-browser name search
- Blank name with any filter browses everything matching that filter
- Add stays in search and marks results as added; Back returns to the list
- GStreamer playback with play/stop, volume, and stream metadata
- Slide-in station details with homepage, stream URL, and remove
- Station icons cached under `~/.cache/gradio/favicons/`, with homepage icon
  discovery and an RSS fallback
- Drag stations to reorder the library; search-result sorting stays on the search tab
- Persisted country, state, language, and tag search filters
- Window geometry and station-icon size are remembered
- Preferences for technical information and clearing the icon cache
- JSON config at `~/.config/gradio/config.json` (`XDG_CONFIG_HOME` honored);
  cache lives at `~/.cache/gradio/`
- Headless core tests for the model, config, HTTP, search, player, and runtime

Gradio adds the parity extras: discover, station editing, import/export, MPRIS, the
GNOME Shell search provider, notifications, codec installation, and
background/resume playback. Collections, headerbar tabs, tray icon, and
multi-select are dropped.

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
