// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class Player : GLib.Object {
        public signal void state_changed (bool playing);
        public signal void metadata_changed (string title, int bitrate);
        public signal void playback_error (string message);

        private Gst.Element playbin;
        private double _volume = 0.8;
        private RadioStation? current = null;
        private uint replay_id = 0;

        public double volume {
            get { return _volume; }
        }

        public Player () {
            playbin = Gst.ElementFactory.make ("playbin", "playbin");
            var bus = playbin.get_bus ();
            bus.add_watch (GLib.Priority.DEFAULT, on_bus_message);
        }

        public void play (RadioStation station) {
            cancel_replay ();

            if (!Http.is_valid_url (station.url)) {
                playback_error (_("Invalid stream URL"));
                return;
            }

            current = station;
            playbin.set ("uri", station.url);
            playbin.set_state (Gst.State.PLAYING);
        }

        public void stop () {
            cancel_replay ();
            current = null;
            playbin.set_state (Gst.State.NULL);
        }

        public void set_volume (double value) {
            _volume = value.clamp (0.0, 1.0);
            playbin.set ("volume", _volume);
        }

        private void cancel_replay () {
            if (replay_id != 0) {
                GLib.Source.remove (replay_id);
                replay_id = 0;
            }
        }

        private void schedule_replay () {
            cancel_replay ();
            replay_id = GLib.Timeout.add_seconds (10, () => {
                replay_id = 0;
                if (current != null)
                    play (current);
                return false;
            });
        }

        private bool on_bus_message (Gst.Bus bus, Gst.Message msg) {
            switch (msg.type) {
                case Gst.MessageType.STATE_CHANGED:
                    Gst.State old_state, new_state, pending;
                    msg.parse_state_changed (out old_state, out new_state, out pending);
                    state_changed (new_state == Gst.State.PLAYING);
                    break;
                case Gst.MessageType.TAG:
                    Gst.TagList tags;
                    msg.parse_tag (out tags);
                    string title;
                    if (!tags.get_string (Gst.Tags.TITLE, out title))
                        title = "";
                    int bitrate;
                    if (!tags.get_int (Gst.Tags.BITRATE, out bitrate))
                        bitrate = 0;
                    metadata_changed (title, bitrate / 1000);
                    break;
                case Gst.MessageType.ERROR:
                    GLib.Error error;
                    string debug;
                    msg.parse_error (out error, out debug);
                    playback_error (error.message);
                    stop ();
                    break;
                case Gst.MessageType.EOS:
                    playback_error (_("End of stream"));
                    playbin.set_state (Gst.State.NULL);
                    schedule_replay ();
                    break;
                case Gst.MessageType.ELEMENT:
                    unowned Gst.Structure structure = msg.get_structure ();
                    if (structure != null && structure.get_name () == "missing-plugin") {
                        playback_error (_("A required codec is missing."));
                        stop ();
                    }
                    break;
                default:
                    break;
            }
            return true;
        }
    }
}
