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

Requirements: `meson`, `ninja`, `vala`, `gtk4` (≥ 4.12), `libsoup-3.0`,
`json-glib`, `gstreamer`, `gettext`, and the GStreamer plugin sets
`gst-plugins-base`, `gst-plugins-good`, `gst-plugins-bad`, `gst-plugins-ugly`,
`gst-libav` for common stream codecs.

```bash
meson setup builddir
meson compile -C builddir
meson test -C builddir        # headless — no display needed
./builddir/gradio
```

## Current state

Gradio is a usable single-list radio player:

- One library list; `+` opens the Add view with radio-browser search and
  Discover lists (popular and recently added stations)
- Blank name with any filter browses everything matching that filter
- Add stays in search and marks results as added; Back returns to the list
- GStreamer playback with play/stop, volume, and stream metadata
- Background playback: closing the window keeps the stream alive while the
  app holds a background slot, and sleep is inhibited during playback
- Slide-in station details with homepage, stream URLs, session track history,
  and voting; removal is on the library row
- Station icons cached under `~/.cache/gradio/favicons/`, with homepage icon
  discovery via HTML `<link rel="icon">` and `/favicon.ico`
- Drag stations to reorder the library; search-result sorting stays on the search tab
- Library sorting by name, country, state, language, or bitrate (ascending or
  descending); Custom order keeps drag-and-drop reordering and reverses it
  when descending is on
- Add and edit local stations that are not in radio-browser; remote stations
  stay read-only
- Remote station metadata refreshes on startup; stations missing upstream get
  an “Unavailable” badge and stay in the library
- Persisted country, state, language, and tag search filters; country,
  language, and tag are searchable pickers filled from radio-browser
- Window geometry and station-icon size are remembered
- Preferences for technical information, notifications, background playback,
  status bar, player-in-header placement, station-icon size, resuming the last
  station on startup, and clearing the icon cache
- Import and export the station library as JSON, or export an M3U playlist
- MPRIS 2.2 controls, media keys, and the GNOME media widget
- GNOME Shell search over the local library
- Desktop notifications for now-playing changes and playback errors
- JSON config at `~/.config/gradio/config.json` (`XDG_CONFIG_HOME` honored);
  cache lives at `~/.cache/gradio/`
- Headless core tests for the model, config, HTTP, search, player, and runtime

Gradio keeps the extras that fit the single-list design: import/export (JSON and
M3U), MPRIS, the GNOME Shell search provider, notifications, voting, filter
pickers, Discover presets, background playback, and optional resume of the
last station. A codec installer is not included; common GStreamer codec
packages are regular dependencies. Collections, headerbar tabs, tray icon,
and multi-select remain out of scope.

## Packaging

**Arch Linux** — builds a package from the live work tree:

```bash
./scripts/build-package.sh              # → scripts/dist/*.pkg.tar.zst
./scripts/build-package.sh -C           # clean build
./scripts/build-package.sh -i           # install after building
```

## License

Gradio is licensed under GPL-3.0-or-later; see [LICENSE.md](LICENSE.md).
Portions derived from the MIT-licensed GTK4 half-elmish template remain
available under MIT; see [LICENSE](LICENSE). The combined work is distributed
under GPL-3.0-or-later.
