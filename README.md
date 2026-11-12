# Gradio — GTK4 / half-elmish rewrite

Gradio is an internet radio player for GNOME. This branch is a from-scratch
GTK4 rewrite built on the half-elmish architecture: a full elmish-style
message/update loop (model, messages, commands, subscriptions) with an
imperative GTK4 view.

The GTK3 implementation and its libsoup 3 baseline live on the
`libsoup3-baseline` branch and the `v7.3-gtk3-baseline` tag. This branch has
no shared git history with it; it is a deliberate rewrite.

- **Architecture:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Agent conventions:** [AGENTS.md](AGENTS.md)

## Build

Requirements: `meson`, `ninja`, `vala`, `gtk4` (≥ 4.12), `libsoup-3.0`,
`json-glib`, `gstreamer`, `gettext`, `protobuf-c` (and `protoc` with the
protobuf-c plugin at build time), and the GStreamer plugin sets
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

- **Library:** one list, drag-to-reorder, sorting by name/country/state/language/bitrate; add/edit local stations; remote metadata refresh with “Unavailable” badges.
- **Search:** radio-browser search and Discover presets; persisted country/state/language/tag filters; results mark already-added stations.
- **Playback:** GStreamer play/stop, volume, stream metadata, background playback, sleep inhibition.
- **Station details:** slide-in panel with homepage, stream URLs, track history, and voting.
- **Icons:** cached under `~/.cache/gradio/favicons/`, with homepage discovery and cache clearing.
- **Integrations:** MPRIS 2.2, media keys, GNOME Shell search, desktop notifications.
- **Cast:** Google Cast discovery, stream casting, and one-output-at-a-time routing back to local playback.
- **Config:** JSON at `~/.config/gradio/config.json` (`XDG_CONFIG_HOME` honored); window geometry and preferences persisted; import/export JSON or M3U.
- **Tests:** headless core tests for model, config, HTTP, search, player, and runtime.

Out of scope: codec installer, collections, headerbar tabs, tray icon,
multi-select.

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
