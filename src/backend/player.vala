// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    private enum PlayerCommandKind {
        PLAY,
        STOP,
        SET_VOLUME,
        QUIT
    }

    private class PlayerCommand : GLib.Object {
        public PlayerCommandKind kind;
        public string url;
        public double volume;

        public PlayerCommand (PlayerCommandKind kind, string url = "",
                double volume = 0.0) {
            this.kind = kind;
            this.url = url;
            this.volume = volume;
        }
    }

    public class Player : GLib.Object {
        public signal void state_changed (bool playing);
        public signal void metadata_changed (string title, int bitrate);
        public signal void playback_error (string message);
        public signal void playback_reconnecting (string message);

        private Gst.Element playbin;
        private double _volume = 0.8;
        private RadioStation? current = null;
        private uint replay_id = 0;
        private uint suppress_stop_count = 0;

        private Thread<bool>? worker = null;
        private GLib.Mutex lock = GLib.Mutex ();
        private GLib.Cond cond = GLib.Cond ();
        private GLib.Queue<PlayerCommand> queue = new GLib.Queue<PlayerCommand> ();
        private bool quit = false;

        public double volume {
            get { return _volume; }
        }

        public Player () {
            playbin = Gst.ElementFactory.make ("playbin", "playbin");
            var bus = playbin.get_bus ();
            bus.add_watch (GLib.Priority.DEFAULT, on_bus_message);
            worker = new Thread<bool> ("player-control", () => {
                worker_loop ();
                return true;
            });
        }

        public void play (RadioStation station) {
            cancel_replay ();

            if (!Http.is_valid_url (station.url)) {
                stop ();
                playback_error (_("Invalid stream URL"));
                return;
            }

            // Tear down the previous stream before switching URIs so two
            // stations never play at once.
            current = station;
            suppress_stop_count++;
            enqueue (new PlayerCommand (PlayerCommandKind.PLAY, station.url));
        }

        public void stop () {
            cancel_replay ();
            current = null;
            enqueue (new PlayerCommand (PlayerCommandKind.STOP));
        }

        public void set_volume (double value) {
            _volume = value.clamp (0.0, 1.0);
            enqueue (new PlayerCommand (PlayerCommandKind.SET_VOLUME,
                "", _volume));
        }

        public void shutdown () {
            lock.lock ();
            quit = true;
            queue.clear ();
            queue.push_tail (new PlayerCommand (PlayerCommandKind.QUIT));
            cond.signal ();
            lock.unlock ();
            if (worker != null) {
                worker.join ();
                worker = null;
            }
        }

        private void worker_loop () {
            while (true) {
                lock.lock ();
                while (!quit && queue.is_empty ())
                    cond.wait (lock);
                var command = queue.pop_head ();
                lock.unlock ();
                if (command != null)
                    execute (command);
                if (quit)
                    break;
            }
        }

        private void enqueue (PlayerCommand command) {
            lock.lock ();
            queue.push_tail (command);
            cond.signal ();
            lock.unlock ();
        }

        private void execute (PlayerCommand command) {
            switch (command.kind) {
                case PlayerCommandKind.PLAY:
                    playbin.set_state (Gst.State.NULL);
                    playbin.set ("uri", command.url);
                    if (playbin.set_state (Gst.State.PLAYING) ==
                            Gst.StateChangeReturn.FAILURE) {
                        playbin.set_state (Gst.State.NULL);
                        emit_error_on_main (_("Could not start playback"));
                    }
                    break;
                case PlayerCommandKind.STOP:
                case PlayerCommandKind.QUIT:
                    playbin.set_state (Gst.State.NULL);
                    break;
                case PlayerCommandKind.SET_VOLUME:
                    playbin.set ("volume", command.volume);
                    break;
            }
        }

        private void emit_error_on_main (string message) {
            GLib.Idle.add (() => {
                playback_error (message);
                return false;
            });
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
                    if (new_state == Gst.State.PLAYING) {
                        suppress_stop_count = 0;
                        state_changed (true);
                    } else if (new_state == Gst.State.NULL) {
                        if (suppress_stop_count > 0)
                            suppress_stop_count--;
                        else
                            state_changed (false);
                    }
                    break;
                case Gst.MessageType.TAG:
                    Gst.TagList tags;
                    msg.parse_tag (out tags);
                    string title;
                    if (!tags.get_string (Gst.Tags.TITLE, out title))
                        title = "";
                    uint bitrate;
                    if (!tags.get_uint (Gst.Tags.BITRATE, out bitrate))
                        bitrate = 0;
                    metadata_changed (title, (int) (bitrate / 1000));
                    break;
                case Gst.MessageType.ERROR:
                    GLib.Error error;
                    string debug;
                    msg.parse_error (out error, out debug);
                    suppress_stop_count++;
                    playback_error (error.message);
                    stop ();
                    break;
                case Gst.MessageType.EOS:
                    suppress_stop_count++;
                    playback_reconnecting (_("Reconnecting…"));
                    enqueue (new PlayerCommand (PlayerCommandKind.STOP));
                    schedule_replay ();
                    break;
                case Gst.MessageType.ELEMENT:
                    unowned Gst.Structure structure = msg.get_structure ();
                    if (structure != null && structure.get_name () == "missing-plugin") {
                        suppress_stop_count++;
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