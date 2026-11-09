# Migrating to B+Hybrid

For **existing half-elmish apps** that need a retained-native widget later (e.g. you started as `Notes`/`Counter` and now add `WebKit.WebView`, `Shumate.Map`, `GStreamer`, `DrawingArea`+drag). Adoption is **additive per-view** — the loop, core, and all other views stay untouched.

## What you add (code pattern only, no build changes)

```
half-elmish (before)  ──►  B+hybrid (after, per-view)
dispatch→updateModel→Cmd   dispatch→updateModel→Cmd  (unchanged)
updateView(msg,model,view) updateView(msg,model,view) + per-view escape
                       ───  lib_core still no GTK, other views still plain half-elmish
```

## Checklist — apply per-view

Assume existing project has `src/model/messages.vala`, `src/app-update.vala`, `src/app-view.vala`, `tests/test_update.vala` (headless).

### 1. Model — add per-view context (only for the retained-native view)

Do **not** replace `AppModel`; add a `BookContext`-like object per resource:

```vala
// src/model/my-context.vala (new, GLib.Object for notify_property)
public class App.MyContext : GLib.Object {
    public string id { get; set; default = ""; }
    public string last_url { get; set; default = ""; }
    public double scroll_y { get; set; default = 0; }
    // retained per-resource state only
}
```

In `AppModel` (minimal diff — same as vCHM `design.md:32`):

```vala
private App.MyContext _empty = new App.MyContext ();
private App.MyContext? _active = null;
public App.MyContext current_ctx { get { return _active ?? _empty; } }
public void set_active (App.MyContext? ctx) {
    if (_active != null && _active != ctx) { /* flush pending coalesced */ }
    _active = ctx;
    notify_property ("current_ctx");
}
```

Add `current_ctx` to `updateModel` handled messages only for the view that needs it (e.g. `OPEN_FILE_DONE → set_active`, `NAVIGATE_DONE` uses `current_ctx`). Other messages unchanged.

### 2. View — apply escape only to the retained-native widget

* Keep one widget instance (e.g. one `WebView` / `Map`), recreate only on `notify["current_ctx"]`. Do not create per-message.
* Coalesce continuous events via `ScrolledWindow.get_vadjustment().value_changed` → `Timeout 1500ms`. Capture `pending_y` on every event; flush only on timeout.

```vala
var vadj = scrolled.get_vadjustment ();
vadj.value_changed.connect (() => {
    pending_y = (int) vadj.get_value ();
    if (coalesce_id == 0) coalesce_id = Timeout.add (1500, () => { save; coalesce_id = 0; return false; });
});
```

Other views (`src/components/counter/` etc.) stay plain half-elmish — `updateView` per-message, no coalescing.

### 3. Keep `lib_core` GTK-free

The new context class must be plain `GLib.Object` (no GTK imports). The view file (`src/app-view.vala`) already imports GTK — add the hybrid code there. Do not list GTK-importing files in `lib_core`.

### 4. Tests — headless stay headless

Add model tests dispatching the new message and asserting `model.current_ctx` changes (like `tests/test_update.vala`). No GTK needed.

## When this is unnecessary

If the new widget has no retained-native state (`Gtk.Label`, `ListBox`, `ColumnView` with `ListStore`) or only one-shot loads (`FileDialog`, `AlertDialog`), stay half-elmish — drive it from a `Cmd` (`updateModel` returns `Cmd` that calls `view.load_uri` via `dispatch`). B+hybrid only when the trigger rule (`docs/B_HYBRID.md`) holds.

## Rollback

Delete the code you added: the context class and the coalesced handler in the view. Nothing else changes.
