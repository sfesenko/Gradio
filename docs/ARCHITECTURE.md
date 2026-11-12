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
   dispatch(msg) ──► updateModel(msg, model)          Cmd.exec(dispatch, cmd)
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

Four pieces, four responsibilities:

| Piece | File | Pure? | Testable without GTK? |
|---|---|---|---|
| `App.Message` + subclasses | `src/model/messages.vala` | yes | yes |
| `AppModel` | `src/model/messages.vala` | yes | yes |
| `updateModel` | `src/app-update.vala` | yes | yes |
| `Commands` (command factory) | `src/commands.vala` | yes | yes |
| `AppRuntime` (IO implementation) | `src/app-runtime.vala` | no (IO) | yes |
| `RadioStation`, `AppConfig` | `src/model/` | yes | yes |
| `Http`, `RadioBrowser`, `Player` | `src/backend/` | no (IO) | yes |
| `MainView` and `src/view/` components | `src/app-view.vala`, `src/view/` | no (widgets) | no |
| `ElmishProgram`, `Cmd`, `Sub` | `src/elmish.vala` | yes | yes |

Everything except `src/app-view.vala`, `src/view/`, and `src/main.vala` is
compiled into `lib_core` (see `meson.build`). The core has **no GTK imports**,
which is what makes `meson test` run headless; backend tests link libsoup and
GStreamer but still need no display.

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
- **Lookup:** linear `find_station`; add an id→station index only if library
  size demands it.
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

Every message is a **plain class** subclass of `App.Message`:

- *Plain* means neither `GLib.Object` nor `[Compact]`. Valac compiles such
  classes as GType-registered, atomically ref-counted classes: one allocation
  per message, `is`/`as` type checks, and — crucially — valid **generic type
  arguments** for the elmish core (generated C passes `<class>_ref` as the
  copy function and `<class>_unref` as the destroy function at generic
  instantiation, exactly like GObject).
- Dispatch switches on the `kind` enum (fast, exhaustive), then reads payloads
  via `is`/`as` (type-safe):

```vala
case MessageKind.INCREMENT:
    model.count++;
    break;
```

### Why not compact classes or structs? (verified, Vala 0.56.19)

Valac's type-erased generic codegen requires every stored generic value to be
either ref-counted or copyable (`get_dup_func_expression` in
`valaccodebasemodule.vala`), and type-checkable (`get_type_id_expression`).

| Representation | Generic core | Per-kind payload safety | Per-event cost |
|---|---|---|---|
| GObject subclasses | ✓ | ✓ (`is`/`as`) | ~150–400 ns |
| **Plain classes** | ✓ | ✓ (`is`/`as`) | **~60–150 ns** |
| Compact classes | ✗ "duplicating instance" (no ref/dup machinery) | ✗ derived compact classes can't have fields | ~15–30 ns |
| Structs | ✗ "use `?` to box value types" | ✗ union payload | ~5–15 ns |

- **Compact classes** are rejected as generic type arguments: the core stores
  `Message? pending_message` past the dispatch scope, and valac needs a ref or
  copy function to manage that storage. `Cmd<unowned Msg>` compiles but
  forfeits ownership — dangling pointer (with destructor) or leak (without).
- **Structs** are rejected outright: "not a supported generic type argument,
  use `?` to box value types" — and boxing re-adds allocation.
- **GObject vs plain**: identical semantics for the core; plain classes skip
  the GObject machinery (property system, instance data, qdata) — cheaper to
  create and destroy, same refcount safety.

Cost figures are indicative (~140 ns/dispatch); at UI rates all four are
negligible — the choice is about type safety, composability, and simplicity,
not raw speed.

## updateModel: the pure half

```vala
public Elmish.Cmd<App.Message>? updateModel (App.Message msg, AppModel model)
```

Contract:

- Only mutates the model and returns a `Cmd` (or `null`).
- **No IO**, no dialogs, no GTK. Every side effect — file save, network,
  playback — goes into a returned `Cmd`.
- Dispatch is synchronous: `updateModel` runs before the next message, so
  model mutation is race-free (messages from worker threads are marshalled to
  the main loop first — `ElmishProgram.dispatch`).

### Commands (Cmd) — the side-effect channel

`updateModel` returns a `Cmd` bundling the work to do *after* the model
update. The sub receives `dispatch`, so async work can report back:

```vala
cmd = new Elmish.Cmd<App.Message> ((dispatch) => {
    save_async.begin (path, snapshot, (obj, res) => {
        var ok = save_async.end (res, out error);
        dispatch (ok
            ? (App.Message) new SavedMessage ()
            : (App.Message) new SaveFailedMessage (error));
    });
});
```

GIO async IO (`load_contents_async`, `replace_contents_async`) runs on GIO's
worker thread and calls back on the main loop — no manual threads. The result
message is dispatched back through the loop, so the view never handles IO
results directly.

**Gotcha:** `string[]` is not ref-counted. If a Cmd will read the model later
(from another thread, or after the function returned), build a fresh copy of
the array inside the sub.

**Termination:** returned Cmds must terminate — `Cmd.exec` runs synchronously
inside `process()`, so a sub that synchronously re-dispatches its own trigger
message recurses until stack overflow. Async callbacks (GIO, timeouts, idle)
dispatch later through the main loop and are the intended pattern.

### Composition: Cmd.map

Components are the scalability story: each component works with **its own
message type**. `Cmd.map<MessageOut>(mapper)` lifts a child command into the
parent's message space:

```vala
// child component returns Cmd<CounterMsg>; parent maps it into its own space
var mapped = counter_cmd.map<App.Message> ((m) => new CounterEvent (m));
```

`updateModel` can then return `mapped` directly. Subscriptions compose the
same way (wrap the child dispatch). This is the elmish composition primitive —
see `src/elmish.vala`.

### Initial command

`program.start (init_cmd)` runs an optional command when the view is created —
used to load persisted state asynchronously and dispatch the result back.

### Subscriptions (Sub) — the event sources

`program.add_subscription (sub)` runs the sub immediately with `dispatch`;
the sub sets up its own sources (timers, gio watchers, dbus...).

## updateView: the imperative half

`updateView(msg, model, view)` mutates widgets. It is **not** a pure render:
it applies the message and re-reads the model. Rules for the view:

- Never mutate the model from the view. Widget signals become messages:
  `button.clicked → dispatch (new IncrementMessage ())`.
- Transient widget state (entry text, focus) may live in the view; only
  application state belongs in the model.
- View updates are coalesced: bursts of messages collapse into one idle
  callback that re-renders from the model with the latest message. So
  `updateView` must render from `model`; `msg` is a kind hint only —
  intermediate payloads in a burst are intentionally dropped.
- The program holds the view and the view holds a bound `dispatch`, i.e. a
  reference cycle. Harmless for a single-window app lifetime; in a
  multi-window app, clear the view's `dispatch` (or `weak` it) on window
  close or each closed window leaks its program+view pair.
- Dispatching before `start()` updates the model but drops the view update
  (there is no view yet); `createView` builds from the live model, so state
  still converges. Subscriptions are fire-and-forget (no removal handle) —
  a per-view subscription that outlives its view leaks; prefer app-lifetime
  subs or disconnect explicitly.

## View construction: code, .ui, or Blueprint — all supported

The core treats the view as an opaque generic parameter (`createView` +
`updateView`); half-elmish only requires the view to mutate widgets
imperatively. Any construction method fits:

| Style | How |
|---|---|
| Code | `build_ui` constructs widgets, connects signals → `dispatch` |
| `.ui` (GtkBuilder XML) | `Gtk.Builder.new_from_resource`, `get_object` by name into view fields; signals connect to dispatch |
| Blueprint | compiles to `.ui` → same GtkBuilder path (`blueprint-compiler` is a build-time only dep) |

## When to use this pattern

Elmish is not strictly superior to usual Vala GTK (signals + widgets-as-state
+ GObject bindings) — it is a tradeoff. Start half-elmish always; it is the
simplest, fully tested option and covers most apps. Retained-native widgets
(WebKit, maps, GStreamer, drawing surfaces) are handled in the view layer
without changing the loop.

**Use it when:** business logic deserves headless tests; multiple paths mutate
the same state; async flows need status feedback; no widget owns state that
`updateView(msg, model, view)` cannot rebuild from `model` alone.

**Skip it when:** the app is a small tool where GTK widgets *are* the model
(editable trees, live bindings everywhere); message ceremony outweighs
testability.

## Adding a new feature, step by step

Example: a "decrement" button.

1. **Message** — `src/model/messages.vala`:
   ```vala
   // enum: add DECREMENT,
   public class DecrementMessage : App.Message {
       public override MessageKind kind { get { return MessageKind.DECREMENT; } }
   }
   ```
2. **updateModel** — `src/app-update.vala`:
   ```vala
   case MessageKind.DECREMENT:
       model.count--;
       break;
   ```
3. **Test** — `tests/test_update.vala`: dispatch the message, assert model state.
4. **View** — `src/app-view.vala`: add the button, connect it to
   `dispatch (new DecrementMessage ())`; add the kind to `update()`.
5. `meson test -C builddir` — green, no display needed.

## Testing strategy

The core library (`src/elmish.vala`, `src/model/messages.vala`,
`src/app-update.vala`) has zero GTK imports, so every test in `tests/` runs
headless with plain glib assertions:

- `test_update.vala` — model behavior for each message kind
- `test_app_config.vala` — JSON persistence, duplicates, invalid files
- `test_radio_station.vala` — station JSON and display text
- `test_http.vala` — URL validation, query building, GETs against a local server
- `test_radio_browser.vala` — search URL and station parsing
- `test_player.vala` — GStreamer volume and error handling
- `test_app_runtime.vala` — debounced saves and save-failure dispatch
- `test_cast.vala` — Cast JSON helpers and service parsing
- `test_mdns.vala` — mDNS name decompression, record parsing, device assembly
- `test_elmish.vala` — the core itself: Cmd chains, dispatch-back, coalescing,
  subscriptions, thread marshalling, `Cmd.map` composition, plain-class
  messages in the generic core (12 tests)

Tests that need the main loop (coalescing, worker dispatch) pump it with
`MainContext.default().iteration (true)`.

## GTK4 notes (differences vs GTK3 codebases)

- No `Gtk.init` — `Gtk.Application` handles it; no `show_all` — widgets are
  visible by default.
- `Gtk.Window.set_titlebar` still exists (`Gtk.HeaderBar` retained).
- Removed: `Gtk.TreeView` (use `Gtk.ListBox`/`Gtk.ColumnView`), `Gtk.EventBox`
  (use gestures/buttons), `Gtk.IconSize` (pixel sizes), `Gtk.Menu` (use
  `GMenu`/popovers), `Gtk.Dialog` (use `Gtk.FileDialog`/`Gtk.AlertDialog` or
  libadwaita).
- `show_close_button` → `show_title_buttons` (GTK ≥ 4.10).
- Theme handling is left entirely to GTK: `GTK_THEME` wins, then the
  `gtk-theme` (Legacy Applications) setting, then built-in Adwaita.

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
- `cast-proto.c` / `cast.proto` — protobuf wire encoding; `protoc` generates
  `cast.pb-c.c/h` at build time and `libprotobuf-c` is linked.
- `cast-service.vala` — Cast v2 commands: mDNS discovery, LAUNCH of the
  Default Media Receiver, media LOAD, PING/PONG, and STOP.

The device is selected explicitly; its mDNS `id`, friendly name, host, and
port are persisted in `AppConfig`. Cast stream URLs must be reachable from the
device itself.
