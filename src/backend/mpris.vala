// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    [DBus (name = "org.mpris.MediaPlayer2")]
    public interface MprisRootIface : GLib.Object {
        public abstract bool can_quit { owned get; }
        public abstract bool can_raise { owned get; }
        public abstract bool has_track_list { owned get; }
        public abstract string identity { owned get; }
        public abstract string desktop_entry { owned get; }
        public abstract string[] supported_uri_schemes { owned get; }
        public abstract string[] supported_mime_types { owned get; }

        [DBus (name = "Raise")]
        public abstract void raise_root () throws GLib.Error;

        [DBus (name = "Quit")]
        public abstract void quit_root () throws GLib.Error;
    }

    [DBus (name = "org.mpris.MediaPlayer2.Player")]
    public interface MprisPlayerIface : GLib.Object {
        public abstract string playback_status { owned get; }
        public abstract GLib.Variant metadata { owned get; }
        public abstract double volume { owned get; set; }
        public abstract int64 position { owned get; }
        public abstract bool can_control { owned get; }
        public abstract bool can_play { owned get; }
        public abstract bool can_pause { owned get; }
        public abstract bool can_go_next { owned get; }
        public abstract bool can_go_previous { owned get; }
        public abstract bool can_seek { owned get; }

        [DBus (name = "Play")]
        public abstract void play () throws GLib.Error;

        [DBus (name = "Pause")]
        public abstract void pause () throws GLib.Error;

        [DBus (name = "PlayPause")]
        public abstract void play_pause () throws GLib.Error;

        [DBus (name = "Stop")]
        public abstract void stop () throws GLib.Error;

        [DBus (name = "Next")]
        public abstract void next () throws GLib.Error;

        [DBus (name = "Previous")]
        public abstract void previous () throws GLib.Error;

        [DBus (name = "Seek")]
        public abstract void seek (int64 offset) throws GLib.Error;

        [DBus (name = "SetPosition")]
        public abstract void set_position (GLib.ObjectPath track_id, int64 position) throws GLib.Error;

        [DBus (name = "OpenUri")]
        public abstract void open_uri (string uri) throws GLib.Error;
    }

    // MPRIS 2.2 server. Passive: the desktop discovers it over D-Bus.
    // State is pushed in from the elmish update loop via update().
    public class MprisServer : GLib.Object, MprisRootIface, MprisPlayerIface {
        public const string BUS_NAME = "org.mpris.MediaPlayer2.gradio";
        public const string OBJECT_PATH = "/org/mpris/MediaPlayer2";
        public const string TRACK_PREFIX = "/io/github/sfesenko/gradio/track/";

        private unowned Elmish.Dispatch<Message> dispatch;
        private GLib.Application app;
        private GLib.DBusConnection? connection = null;
        private uint owner_id = 0;

        private string status = "Stopped";
        private GLib.Variant current_metadata;
        private double current_volume = 0.8;
        private bool has_station = false;
        private bool playing = false;
        private bool stopped = false;

        public MprisServer (Elmish.Dispatch<Message> dispatch, GLib.Application app) {
            this.dispatch = dispatch;
            this.app = app;
            current_metadata = metadata_for (null, "");
        }

        public bool register () {
            try {
                connection = GLib.Bus.get_sync (GLib.BusType.SESSION);
            } catch (GLib.Error e) {
                connection = null;
                return false;
            }
            try {
                connection.register_object<MprisRootIface> (OBJECT_PATH, this);
                connection.register_object<MprisPlayerIface> (OBJECT_PATH, this);
            } catch (GLib.Error e) {
                return false;
            }
            owner_id = GLib.Bus.own_name_on_connection (connection, BUS_NAME,
                GLib.BusNameOwnerFlags.NONE);
            return true;
        }

        public void update (AppModel model) {
            stopped = model.playback_stopped;
            string new_status = playback_status_for (model.playing,
                model.current_station != null, stopped);
            bool new_has_station = model.current_station != null;
            bool new_playing = model.playing;
            var new_metadata = metadata_for (model.current_station, model.stream_title);
            double new_volume = model.config.volume;

            bool status_changed = new_status != status;
            bool metadata_changed = !new_metadata.equal (current_metadata);
            bool volume_changed = new_volume != current_volume;

            status = new_status;
            has_station = new_has_station;
            playing = new_playing;
            current_metadata = new_metadata;
            current_volume = new_volume;

            if (status_changed || metadata_changed || volume_changed)
                emit_player_changed (status_changed, metadata_changed, volume_changed);
        }

        private void emit_player_changed (bool status_changed, bool metadata_changed,
                bool volume_changed) {
            var the_connection = connection;
            if (the_connection == null)
                return;

            var changed = new GLib.VariantDict (null);
            if (status_changed)
                changed.insert_value ("PlaybackStatus", new GLib.Variant.string (status));
            if (metadata_changed)
                changed.insert_value ("Metadata", current_metadata);
            if (volume_changed)
                changed.insert_value ("Volume", new GLib.Variant.double (current_volume));

            var tuple = new GLib.VariantBuilder (new GLib.VariantType ("(sa{sv}as)"));
            tuple.add_value (new GLib.Variant.string ("org.mpris.MediaPlayer2.Player"));
            tuple.add_value (changed.end ());
            tuple.add_value (new GLib.Variant.strv ({}));
            try {
                the_connection.emit_signal (null, OBJECT_PATH,
                    "org.freedesktop.DBus.Properties", "PropertiesChanged", tuple.end ());
            } catch (GLib.Error e) {
            }
        }

        // ── MPRIS root ─────────────────────────────────────────────────────

        private static string[] uri_schemes = { "http", "https" };
        private static string[] no_mime_types = {};

        public bool can_quit { get { return true; } }
        public bool can_raise { get { return true; } }
        public bool has_track_list { get { return false; } }
        public string identity { owned get { return "Gradio"; } }
        public string desktop_entry { owned get { return "io.github.sfesenko.gradio"; } }
        public string[] supported_uri_schemes { owned get { return uri_schemes; } }
        public string[] supported_mime_types { owned get { return no_mime_types; } }

        public void raise_root () throws GLib.Error {
            app.activate_action ("raise", null);
        }

        public void quit_root () throws GLib.Error {
            app.quit ();
        }

        // ── MPRIS player ───────────────────────────────────────────────────

        public string playback_status { owned get { return status; } }
        public GLib.Variant metadata { owned get { return current_metadata; } }
        public int64 position { get { return 0; } }
        public bool can_control { get { return true; } }
        public bool can_play { get { return has_station; } }
        public bool can_pause { get { return has_station; } }
        public bool can_go_next { get { return false; } }
        public bool can_go_previous { get { return false; } }
        public bool can_seek { get { return false; } }

        public double volume {
            get { return current_volume; }
            set {
                if (value != value || value < 0.0 || value > 1.0)
                    return;
                current_volume = value;
                dispatch (new SetVolumeMessage (value));
            }
        }

        public void play () throws GLib.Error {
            stopped = false;
            if (has_station && !playing)
                dispatch (new TogglePlayMessage ());
        }

        public void pause () throws GLib.Error {
            // Live radio cannot buffer, so "pause" tears down the pipeline and
            // resuming reconnects. The model still reports Paused over MPRIS.
            stopped = false;
            if (playing)
                dispatch (new TogglePlayMessage ());
        }

        public void play_pause () throws GLib.Error {
            stopped = false;
            if (has_station)
                dispatch (new TogglePlayMessage ());
        }

        public void stop () throws GLib.Error {
            stopped = true;
            if (has_station)
                dispatch (new StopPlaybackMessage ());
        }

        public void next () throws GLib.Error {
        }

        public void previous () throws GLib.Error {
        }

        public void seek (int64 offset) throws GLib.Error {
        }

        public void set_position (GLib.ObjectPath track_id, int64 position) throws GLib.Error {
        }

        public void open_uri (string uri) throws GLib.Error {
        }

        // ── pure helpers ───────────────────────────────────────────────────

        public static string playback_status_for (bool playing, bool has_station, bool stopped) {
            if (playing)
                return "Playing";
            if (has_station && !stopped)
                return "Paused";
            return "Stopped";
        }

        public static string track_id_for (string station_id) {
            var builder = new GLib.StringBuilder (TRACK_PREFIX);
            for (int i = 0; i < station_id.length; i++) {
                char c = station_id[i];
                bool safe = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                    (c >= '0' && c <= '9') || c == '_';
                builder.append_c (safe ? c : '_');
            }
            if (builder.len == TRACK_PREFIX.length)
                builder.append ("unknown");
            return builder.str;
        }

        public static GLib.Variant metadata_for (RadioStation? station, string stream_title) {
            var dict = new GLib.VariantDict (null);
            if (station != null) {
                dict.insert_value ("mpris:trackid",
                    new GLib.Variant.object_path (track_id_for (station.id)));
                bool has_stream_title = stream_title != "";
                string title = has_stream_title ? stream_title : station.name;
                dict.insert_value ("xesam:title", new GLib.Variant.string (title));
                if (has_stream_title && station.name != "")
                    dict.insert_value ("xesam:artist", new GLib.Variant.strv ({ station.name }));
                if (station.url != "")
                    dict.insert_value ("xesam:url", new GLib.Variant.string (station.url));
            }
            return dict.end ();
        }
    }
}
