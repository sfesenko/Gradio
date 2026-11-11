// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class Commands : GLib.Object {
        public virtual Elmish.Cmd<Message>? search (string query, uint generation) { return null; }
        public virtual Elmish.Cmd<Message>? play (RadioStation station) { return null; }
        public virtual Elmish.Cmd<Message>? stop () { return null; }
        public virtual Elmish.Cmd<Message>? set_volume (double volume) { return null; }
        public virtual Elmish.Cmd<Message>? save_config () { return null; }
        public virtual Elmish.Cmd<Message>? load_favicons (GLib.GenericArray<RadioStation> stations) { return null; }
        public virtual Elmish.Cmd<Message>? clear_favicon_cache () { return null; }
        public virtual Elmish.Cmd<Message>? vote (string station_id) { return null; }
        public virtual Elmish.Cmd<Message>? notify_error (string message) { return null; }
        public virtual Elmish.Cmd<Message>? import_stations (string path) { return null; }
        public virtual Elmish.Cmd<Message>? export_stations (GLib.GenericArray<RadioStation> stations, string path) { return null; }
        public virtual Elmish.Cmd<Message>? export_playlist (GLib.GenericArray<RadioStation> stations, string path) { return null; }
        public virtual Elmish.Cmd<Message>? load_filter_options () { return null; }
        public virtual Elmish.Cmd<Message>? refresh_library (GLib.GenericArray<RadioStation> stations) { return null; }
        public virtual Elmish.Cmd<Message>? discover_server () { return null; }
        public virtual Elmish.Cmd<Message>? discover (uint generation) { return null; }
        public virtual Elmish.Cmd<Message>? report_click (string station_id) { return null; }
        public virtual Elmish.Cmd<Message>? background_on_close () { return null; }
        public virtual Elmish.Cmd<Message>? quit_application () { return null; }
        public virtual Elmish.Cmd<Message>? release_background () { return null; }
        public virtual Elmish.Cmd<Message>? inhibit_sleep () { return null; }
        public virtual Elmish.Cmd<Message>? release_sleep () { return null; }
        public virtual Elmish.Cmd<Message>? notify_now_playing (string station_name, string title) { return null; }

        public static Elmish.Cmd<Message>? chain (Elmish.Cmd<Message>? first, Elmish.Cmd<Message>? second) {
            if (first == null)
                return second;
            if (second == null)
                return first;
            return new Elmish.Cmd<Message> ((dispatch) => {
                Elmish.Cmd.exec<Message> (dispatch, first);
            }, second);
        }
    }
}
