# Cast support (Google Cast v2)

Casting is a routing target, not a second output: `PlaybackTarget.LOCAL|CAST`
lives in the model, and `updateModel` stops one transport before starting the
other. The layer is GTK-free and lives in `src/cast/`:

- `mdns.vala` — raw mDNS query/parser over `GSocket` (PTR/SRV/TXT/A), no Avahi.
- `cast-connection.vala` — TLS to port 8009, 4-byte length-prefixed protobuf
  frames, asynchronous reads/writes, `close_async` teardown.
- `cast-proto.c` — manual protobuf wire encoding; `cast.proto` documents the
  message schema.
- `cast-service.vala` — Cast v2 commands: discovery, LAUNCH of the Default
  Media Receiver, media LOAD, PING/PONG, STOP.

## Transport rules

- Every `CastConnection` has its own UUID source id. Reusing one id makes the
  receiver treat a new socket as the same sender and it can drop the older,
  live connection.
- The receiver pings every 5 s and closes the socket ~5 s after a missed
  `PONG`. `CastService` answers `PING` immediately and runs its own `PING`
  every 5 s; a missing `PONG` for 10 s is treated as a dropped sender and
  re-attached, not as a lost cast.
- A receiver `CLOSE` message ends the virtual connection and is handled as a
  sender loss.
- `CastConnection.closed` carries the reason (`eof`, `read: ...`, `write: ...`,
  `empty frame`, `frame too large: N`, `drain`). The service logs it; no read,
  write, PONG, `SET_VOLUME`, probe, or adoption error is discarded. Set
  `GRADIO_CAST_TRACE=1` to log every frame and state change.

## Device and config

The device is selected explicitly; its mDNS `id`, friendly name, host, and port
are persisted in `AppConfig`. Cast stream URLs must be reachable from the
device itself.

| Key | Meaning |
|---|---|
| `cast_mode` | last output was a cast; restored on startup |
| `cast_loss_action` | `WAIT` stops playback, `PLAY_LOCAL` replays locally |
| `cast_keep_on_quit` | default `true`; quit sends a best-effort STOP |
| `cast_track_titles` | default `true`; layer-2 ICY title polling |
| `cast_track_titles_interval` | seconds, default 20 (10/20/30/60 in Preferences) |

The receiver owns the volume level. While a cast is active a volume change
drives the local player and the receiver (`SET_VOLUME`). The level is never
pushed when a cast starts or is attached: the receiver's
`RECEIVER_STATUS.volume` is adopted into the model instead, and changes made
from another sender are mirrored back so the slider follows the device.
Otherwise the controls only drive the local player.

## Session lifecycle

After the first `MEDIA_STATUS` the service polls `GET_STATUS` every 10 s and
declares the cast lost after 30 s of silence. Receiver states map to
`CastStartedMessage`, `CastPausedMessage`, `CastBufferingMessage`, and
`CastLostMessage` (`CastStatus.LOST|PAUSED|BUFFERING`).

On startup `cast_mode` restores `PlaybackTarget.CAST` and, with
`resume_playback`, the last station is re-cast once (`cast_resume_pending`
allows a single re-discovery while the device is not reachable yet). Stopping
playback while casting clears `cast_mode` and returns to local output; a cast
lost with `cast_loss_action = WAIT` keeps `PlaybackTarget.CAST` so Play can
start a new cast.

`SyncCastSessionMessage` probes the persisted device: `CONNECT receiver-0` →
`GET_STATUS` (no LAUNCH) → `CONNECT` to the running media app → `MEDIA_STATUS`.
The probe and its TCP connect are bounded. For a local output the restore starts
immediately while the probe runs; for a cast output the restore waits for the
probe so a live session can be adopted instead of re-loaded.

Adoption rules:

- A session playing an http(s) URL is adopted (`CastAdoptedMessage`) even when
  the last output was local: no new LOAD, the UI switches to the cast state,
  the station is re-added to the library when missing, and play/pause/stop
  control the live session.
- A session without a usable URL, or one detected while local playback is
  already running, is only shown in the cast popover (`cast_remote_label`).
- A failed adoption never falls back to re-loading the station: that would
  restart the stream the device is already playing.
- A probe that reports no `media.metadata` (the common case) does not erase the
  title already shown for the same stream; only a different `contentId` starts
  with a fresh, possibly empty, title.

`MEDIA_STATUS` metadata titles are forwarded as `CastMetadataMessage` on every
liveness poll, so the now-playing line keeps updating. A poll without
`media.metadata` never clears the title already shown. An empty `status` array
after a known player state means the session stopped on another sender and is
reported as lost. Local player tags never overwrite a cast title: while casting
the receiver (or the ICY poller) owns the title.

A dropped sender socket is not a lost cast: the receiver keeps the media
session playing. The service re-probes the device and re-attaches without a new
`LOAD`, and only reports `CastLostMessage` when the probe finds no live,
adoptable session or the re-attach fails.

## Track titles (layer 2)

Most receivers (including Android TV's Default Media Receiver) expose no
`media.metadata`, so titles come from the stream's ICY tags when
`cast_track_titles` is enabled. `CastMetadataPoller` opens a short-lived
connection to the casted URL, reads up to the first ICY metadata block after
`icy-metaint` bytes and aborts; ICY has no seek, so a fresh connection is the
only way to skip the intervening audio. Titles become `CastMetadataMessage`,
reusing the title, history and notification path. The poller runs only while the
cast is playing and backs off on network/server errors; a stream without
`icy-metaint` (HLS, for example) yields no title, and with the option off the UI
falls back to the station's country/bitrate line. Implementation details:
`src/backend/cast-metadata-poller.vala`.

## Shutdown

`cast_keep_on_quit` decides whether quitting keeps the cast running or sends a
STOP. The STOP is best-effort: the app does not wait for the receiver to
acknowledge it before the main loop exits.
