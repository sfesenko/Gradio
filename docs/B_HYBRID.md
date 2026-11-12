# B+Hybrid — Escape Hatch for Retained-Native Widgets

Half-elmish (`dispatch → pure updateModel → Cmd/Sub` + imperative `updateView` only) is optimal for most business logic. GTK4 widgets that own retained-native state (`WebKit.WebView`, `Shumate.Map`, `GStreamer` pipeline, `Gtk.DrawingArea` with drag) break the `updateView` pure-render assumption: they keep `BackForwardList`, `WebContext`, `loaded_url` cache, tile cache, etc., that must be reset imperatively.

`B+hybrid` is **not** a second architecture — it is half-elmish plus a narrow imperative escape **per-view**, keeping the `dispatch→updateModel→Cmd` loop intact and `lib_core` GTK-free.

## When to adopt

All three must hold; otherwise stay half-elmish:

1. Widget keeps retained-native state outside GTK property bindings.
2. Rebuilding it from `model` in `updateView` would recreate/lose state every message.
3. Events arrive at continuous rate (`value_changed`, `motion`, etc.) — coalescing needed.

**Stay half-elmish:** `StationRow`, the library list, any state fully derived from `model`.
**Adopt B+hybrid:** `WebKit.WebView`, `Shumate.Map`, `DrawingArea+GestureDrag`, `GStreamer` — widget owns state not reconstructible from `model`.

## Pattern per-view

Add a per-view context, keep the loop:

```vala
// Model: one context per resource (e.g. per retained-native view)
private App.MyContext _empty_ctx = new App.MyContext ();
private App.MyContext? _active_ctx = null;
public App.MyContext current_ctx { get { return _active_ctx ?? _empty_ctx; } }
public void set_active (App.MyContext? ctx) {
    if (_active_ctx != null && _active_ctx != ctx) { /* flush/coalesce */ }
    _active_ctx = ctx;
    notify_property ("current_ctx");
}
```

```vala
// View: single widget instance, recreated only on current_ctx change + coalesced native events
view.notify["current_ctx"].connect (() => recreate_for_new_ctx ());
var vadj = scrolled.get_vadjustment ();
vadj.value_changed.connect (() => {
    pending_y = (int) vadj.get_value ();
    if (coalesce_id == 0) coalesce_id = Timeout.add (1500, () => { save; coalesce_id = 0; return false; });
});
```

Apply only to the view that owns the retained-native widget; other views stay plain half-elmish.

## What stays, what changes

- **Stays:** `src/elmish.vala` loop, `lib_core` no-GTK, headless `meson test`, `docs/ARCHITECTURE.md` flow.
- **Changes only when B+hybrid:** the one view + its context (`notify["current_ctx"]`). View still receives `dispatch` → `updateModel` → `updateView`. `lib_core` stays GTK-free.

## How to apply

See `docs/MIGRATING_TO_HYBRID.md` for the incremental checklist (per-view, no build changes).
