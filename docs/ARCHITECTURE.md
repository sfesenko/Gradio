# Half-Elmish Architecture (GTK4 + Vala)

Half-elmish is an Elm-style update loop with an imperative view. Everything
except the view — model, messages, update, commands, subscriptions — is full
elmish; the view mutates GTK widgets directly.

## The loop

```
                ┌─────────────────────────────────────────────┐
                │                                             │
  widget signal │                                             │ return Cmd? (side effects)
       │        ▼                                             ▼
   dispatch(msg) ──► updateModel(msg, model, commands)   Cmd.exec(dispatch, cmd)
                     (pure: model + cmd only)                  │
                       │                                       │  async IO may
                       │ model updated                         │  dispatch back
                       ▼                                       │
               queue view update (coalesced, idle)  ◄──────────┘
                       │
                       ▼
               updateView(msg, model, view)
               (imperative widget mutation)
```

| Piece | File | Pure? |
|---|---|---|
| `Gradio.Message` + subclasses, `Gradio.AppModel` | `src/model/messages.vala` | yes |
| `updateModel` | `src/app-update.vala` | yes |
| `Gradio.Commands` (command factory) | `src/commands.vala` | yes |
| `AppRuntime` (IO implementation) | `src/app-runtime.vala` | no (IO) |
| Models: stations, config, sorting, transfer | `src/model/` | yes |
| HTTP, radio-browser, player, favicons, MPRIS | `src/backend/` | no (IO) |
| mDNS, Cast connection and service | `src/cast/` | no (IO) |
| `MainView` and view components | `src/app-view.vala`, `src/view/` | no (widgets) |
| `ElmishProgram`, `Cmd`, `Sub` | `src/elmish.vala` | yes |

Everything except `src/app-view.vala`, `src/view/`, and `src/main.vala` is
compiled into `lib_core` (see `meson.build`). The core has no GTK imports, so
`meson test` runs headless; backend tests link libsoup and GStreamer but still
need no display.

## Gradio state and IO

`AppModel` holds view state (`LIBRARY`/`ADD_STATION`), `AppConfig` (settings +
stations), search results, current station, playback state, stream metadata,
and details selection.

- **Stations:** `RadioStation` adds `state`, `is_local`, and `orphaned` to
  radio-browser metadata. Local stations use `local-<uuid>` IDs and are
  editable; remote stations are read-only.
- **Refresh:** remote stations refresh on startup through the batch
  `refresh_library` command (`/json/stations/byuuid`). A failed batch discards
  the whole result so stations are not falsely marked orphaned.
- **Sorting:** `AppConfig` persists library order and sort settings;
  `AppModel.library_order` caches the sorted view. `config.stations` stays in
  custom order. The cache rebuilds only when the library revision or sort
  settings change.
- **Commands:** `updateModel` switches on `MessageKind`, calls a pure
  `update_<case>` helper, then refreshes the sort cache. Helpers mutate only
  the model and return a `Cmd` or `null`.
- **Runtime:** tests inject a recording `Commands` fake; production uses
  `AppRuntime` (Soup session, GStreamer player, 500 ms debounced config
  writer). Async results dispatch back through the captured dispatch.
- **Persistence:** JSON at `$XDG_CONFIG_HOME/gradio/config.json` (default
  `~/.config/gradio/config.json`). Unparseable files start empty and are backed
  up as `config.json.corrupt` before the next save. The GTK3
  `~/.local/share/gradio/gradio.db` is never read; caches live under
  `$XDG_CACHE_HOME/gradio/`.

## Messages: plain classes + enum discriminator

Every message is a **plain class** subclass of `Gradio.Message` — neither
`GLib.Object` nor `[Compact]` — with a `MessageKind` discriminator. Dispatch
switches on `kind`, then reads payloads with `is`/`as` casts.

Plain classes are required by the generic core: valac needs ref-counting and
type information to store a message beyond the dispatch scope. Compact classes
and structs are rejected as generic type arguments. Do not change this without
reworking the core.

```vala
private Elmish.Cmd<Gradio.Message>? update_notifications (
        Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var notifications = msg as SetNotificationsMessage;
    if (notifications == null ||
            notifications.enabled == model.config.notifications_enabled)
        return null;
    model.config.notifications_enabled = notifications.enabled;
    return commands.save_config ();
}
```

## updateModel, commands, subscriptions

```vala
public Elmish.Cmd<Gradio.Message>? updateModel (
    Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands)
```

- Only mutates the model and returns a `Cmd` (or `null`).
- No IO, dialogs, GTK, or threads. Every side effect goes into the returned
  `Cmd`.
- Messages from worker threads are marshalled to the main loop before
  `updateModel` runs, so model mutation is race-free.

A `Cmd` bundles work to run after the update and receives `dispatch`, so async
work can report back:

```vala
cmd = new Elmish.Cmd<Gradio.Message> ((dispatch) => {
    save_async.begin (path, snapshot, (obj, res) => {
        var ok = save_async.end (res, out error);
        dispatch (ok
            ? (Gradio.Message) new SavedMessage ()
            : (Gradio.Message) new SaveFailedMessage (error));
    });
});
```

GIO async IO runs on GIO's worker thread and calls back on the main loop. The
result is dispatched back through the loop; the view never handles IO results
directly.

**Gotchas:**

- `string[]` is not ref-counted. If a Cmd reads the model later, copy the array
  inside the sub.
- Returned Cmds must terminate. `Cmd.exec` runs synchronously inside
  `process()`, so a sub that synchronously re-dispatches its trigger recurses
  until stack overflow. Dispatch later via async callbacks instead.

`program.start(init_cmd)` runs an optional command when the view is created.
`program.add_subscription(sub)` runs an app-lifetime source with `dispatch`.
Components can own their message type; `Cmd.map` lifts a child command into the
parent's message space (see `src/elmish.vala`).

## updateView: the imperative half

`updateView(msg, model, view)` mutates widgets. It is not a pure render: it
applies the message and re-reads the model.

- Never mutate the model from the view. Widget signals become messages.
- Transient widget state (entry text, focus) may live in the view; application
  state belongs in the model.
- View updates are coalesced: bursts of messages collapse into one idle
  callback that re-renders from the model with the latest message. So
  `updateView` must render from `model`; `msg` is a kind hint only, because
  intermediate payloads are intentionally dropped.

## Threading and async IO

The GTK main thread must never block on IO. `updateModel` stays pure and
synchronous; a `Cmd.sub` starts asynchronous work and returns immediately. Long
work runs in a subsystem owner (GIO async, a worker task, or the player
controller thread) and reports results through `dispatch`, never by mutating the
model or widgets from a worker.

Forbidden on the main thread: blocking file IO, directory scans, `Bus.get_sync`,
`call_*_sync`, raw socket/TLS reads or writes, `tls.close`, `Thread.usleep`, and
`playbin.set_state` calls that can wait. Short CPU work (small JSON
serialization, string formatting) is allowed.

Two explicit exceptions are outside the interactive loop: startup config load
before `app.run()`, and the final config flush during shutdown.

## Cast support (Google Cast v2)

Casting is a routing target, not a second output: `PlaybackTarget.LOCAL|CAST`
lives in the model, and `updateModel` stops one transport before starting the
other. The cast layer is GTK-free and lives in `src/cast/`:

- `mdns.vala` — raw mDNS query/parser over `GSocket` (PTR/SRV/TXT/A), no Avahi.
- `cast-connection.vala` — TLS to port 8009, 4-byte length-prefixed protobuf
  frames, asynchronous reads/writes, and `close_async` teardown.
- `cast-proto.c` — manual protobuf wire encoding; `cast.proto` documents the
  message schema.
- `cast-service.vala` — Cast v2 commands: mDNS discovery, LAUNCH of the
  Default Media Receiver, media LOAD, PING/PONG, and STOP. After the first
  MEDIA_STATUS it polls `GET_STATUS` every 10 s and declares the cast lost
  after 30 s of silence; receiver states map to `CastStartedMessage`,
  `CastPausedMessage`, `CastBufferingMessage`, and `CastLostMessage`
  (`CastStatus.LOST|PAUSED|BUFFERING`).

The device is selected explicitly; its mDNS `id`, friendly name, host, and
port are persisted in `AppConfig`. Cast stream URLs must be reachable from the
device itself. While a cast is active the same volume level is sent to the
receiver with `SET_VOLUME` and to the local player, so switching outputs keeps
the level consistent; otherwise the controls only drive the local player.

`AppConfig` also persists `cast_mode` (the last output was a cast) and
`cast_loss_action` (`WAIT` stops playback, `PLAY_LOCAL` replays the current
station locally). On startup `cast_mode` restores `PlaybackTarget.CAST` and,
with `resume_playback`, the last station is re-cast once (`cast_resume_pending`
allows a single re-discovery when the device is not reachable yet). Stopping
playback while casting clears `cast_mode` and returns to local output; a cast
lost with `cast_loss_action = WAIT` keeps `PlaybackTarget.CAST` so Play can
start a new cast.

`SyncCastSessionMessage` probes the persisted device:
`CONNECT receiver-0` → `GET_STATUS` (no LAUNCH) → `CONNECT` to the running
media app → `MEDIA_STATUS`. The probe and its TCP connect are bounded; for a
local output the restore starts immediately while the probe runs, and for a
cast output the restore waits for the probe so a live session can be adopted
instead of re-loaded. If the session is playing an http(s) URL the
connection is adopted (`CastAdoptedMessage`) even when the last output was
local: no new LOAD, the UI switches to the cast state, the station is
re-added to the library when missing, and play/pause/stop control the live
session. A session without a usable URL, or one detected while local playback
is already running, is only shown in the cast popover (`cast_remote_label`).
`MEDIA_STATUS` metadata titles are forwarded as `CastMetadataMessage` on
every liveness poll, so the now-playing line keeps updating while casting.
A poll without `media.metadata` carries no title information and never clears
the title that is already shown. An empty `status` array after a known player
state is reported as a lost session (stopped from another sender).
A failed adoption never falls back to re-loading the station: that would
restart the stream the device is already playing.
`cast_keep_on_quit` (default true) decides whether quitting keeps the cast
running or sends a STOP. The STOP is best-effort: the app does not wait for
the receiver to acknowledge it before the main loop exits.

Most receivers (including Android TV's Default Media Receiver) expose no
`media.metadata` at all, so track titles come from layer 2 when
`cast_track_titles` (default true) is enabled: `CastMetadataPoller` opens a
short-lived connection to the casted URL, reads up to the first ICY metadata
block after `icy-metaint` bytes and aborts. Polls run immediately and then
every `cast_track_titles_interval` seconds (default 20; 10/20/30/60 in
Preferences). Because ICY has no seek, a fresh connection is the only way to
skip the intervening audio; this costs roughly one metaint block per interval
(~3 MB/h at 16000) instead of a second copy of the whole stream. Titles become
`CastMetadataMessage`, reusing the same title, history and notification path.
The poller starts when the cast is playing (adopted/started/buffering), stops
on pause, stop, loss, failure and shutdown, and backs off on network/server
errors. When the option is off, no second connection is made and the UI falls
back to the station's country/bitrate line. A stream without `icy-metaint`
(HLS, for example) simply yields no title.

`JsonUtil` (`src/model/json-util.vala`) holds the shared "parse and return null
on bad input" helpers (`object_from`, `string_member`, `object_member`,
`int_member`).

## Testing

`tests/` contains headless glib tests. The core is GTK-free and the runtime is
injected with a recording `Commands` fake, so model, config, HTTP, search,
player, Cast, and runtime behavior are tested without a display. Run
`meson test -C builddir`.
