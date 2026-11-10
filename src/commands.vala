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
