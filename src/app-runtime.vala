// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class AppRuntime : Gradio.Commands {
        public Elmish.Dispatch<Message>? dispatch { get; private set; }
        public AppConfig config { get; private set; }
        public Player player { get; private set; }

        private Soup.Session session;
        private uint save_id = 0;
        private bool signals_connected = false;

        public AppRuntime (AppConfig config) {
            this.config = config;
            session = new Soup.Session ();
            session.set_user_agent ("gradio-gtk4");
            player = new Player ();
        }

        public void attach (Elmish.Dispatch<Message> dispatch) {
            this.dispatch = dispatch;
            if (!signals_connected) {
                player.state_changed.connect ((playing) => {
                    var target = this.dispatch;
                    if (target != null)
                        target (new PlayerStateChangedMessage (playing));
                });
                player.metadata_changed.connect ((title, bitrate) => {
                    var target = this.dispatch;
                    if (target != null)
                        target (new PlayerMetadataChangedMessage (title, bitrate));
                });
                player.playback_error.connect ((message) => {
                    var target = this.dispatch;
                    if (target != null)
                        target (new PlayerErrorMessage (message));
                });
                signals_connected = true;
            }
            player.set_volume (config.volume);
        }

        public override Elmish.Cmd<Message>? search (string query, uint generation) {
            return new Elmish.Cmd<Message> ((dispatch) => {
                search_async.begin (query, generation);
            });
        }

        public override Elmish.Cmd<Message>? play (RadioStation station) {
            return new Elmish.Cmd<Message> ((dispatch) => {
                player.play (station);
            });
        }

        public override Elmish.Cmd<Message>? stop () {
            return new Elmish.Cmd<Message> ((dispatch) => {
                player.stop ();
            });
        }

        public override Elmish.Cmd<Message>? set_volume (double volume) {
            return new Elmish.Cmd<Message> ((dispatch) => {
                player.set_volume (volume);
                schedule_save ();
            });
        }

        public override Elmish.Cmd<Message>? save_config () {
            return new Elmish.Cmd<Message> ((dispatch) => {
                schedule_save ();
            });
        }

        public void save_now () {
            try {
                config.save ();
            } catch (GLib.Error e) {
                var target = dispatch;
                if (target != null)
                    target (new ConfigSaveFailedMessage (e.message));
            }
        }

        private void schedule_save () {
            if (save_id != 0)
                GLib.Source.remove (save_id);
            save_id = GLib.Timeout.add (500, () => {
                save_id = 0;
                save_now ();
                return false;
            });
        }

        private async void search_async (string query, uint generation) {
            try {
                var stations = yield RadioBrowser.search_async (session, query);
                var target = dispatch;
                if (target != null)
                    target (new SearchResultsMessage (stations, generation));
            } catch (GLib.Error e) {
                var target = dispatch;
                if (target != null)
                    target (new SearchFailedMessage (e.message, generation));
            }
        }
    }
}
