// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    private class FaviconRequest : GLib.Object {
        public string station_id;
        public string url;
        public uint generation;

        public FaviconRequest (string station_id, string url, uint generation) {
            this.station_id = station_id;
            this.url = url;
            this.generation = generation;
        }
    }

    public class AppRuntime : Gradio.Commands {
        private const int FAVICON_CONCURRENCY = 4;

        private unowned Elmish.Dispatch<Message>? dispatch;
        public AppConfig config { get; private set; }
        public Player player { get; private set; }
        public FaviconCache favicon_cache { get; private set; }

        private Soup.Session session;
        private ConfigStore config_store;
        private uint save_id = 0;
        private bool signals_connected = false;
        private GLib.GenericArray<FaviconRequest> favicon_queue = new GLib.GenericArray<FaviconRequest> ();
        private GLib.HashTable<string, GLib.GenericArray<string>> favicon_inflight =
            new GLib.HashTable<string, GLib.GenericArray<string>> (str_hash, str_equal);
        private GLib.HashTable<string, bool> favicon_backfilled =
            new GLib.HashTable<string, bool> (str_hash, str_equal);
        private GLib.HashTable<string, GLib.GenericArray<string>> favicon_homepages =
            new GLib.HashTable<string, GLib.GenericArray<string>> (str_hash, str_equal);
        private FaviconCooldown favicon_cooldown = new FaviconCooldown ();
        private int favicon_active = 0;
        private uint favicon_generation = 0;
        private GLib.Application? application = null;
        private bool background_hold = false;
        private SleepInhibitor sleep_inhibitor = new SleepInhibitor ();

        public AppRuntime (AppConfig config, bool load_failed = false,
                bool read_only = false, string? favicon_dir = null) {
            this.config = config;
            this.config_store = new ConfigStore (config, load_failed, read_only);
            session = new Soup.Session ();
            session.set_user_agent ("gradio-gtk4");
            session.timeout = 10;
            player = new Player ();
            favicon_cache = new FaviconCache (favicon_dir);
        }

        public void attach (Elmish.Dispatch<Message> dispatch) {
            this.dispatch = dispatch;
            config_store.save_failed.connect ((message) => {
                if (this.dispatch != null)
                    this.dispatch (new ConfigSaveFailedMessage (message));
            });
            if (!signals_connected) {
                player.state_changed.connect ((playing) => {
                    if (this.dispatch != null)
                        this.dispatch (new PlayerStateChangedMessage (playing));
                });
                player.metadata_changed.connect ((title, bitrate) => {
                    if (this.dispatch != null)
                        this.dispatch (new PlayerMetadataChangedMessage (title, bitrate));
                });
                player.playback_error.connect ((message) => {
                    if (this.dispatch != null)
                        this.dispatch (new PlayerErrorMessage (message));
                });
                player.playback_reconnecting.connect ((message) => {
                    if (this.dispatch != null)
                        this.dispatch (new PlayerReconnectingMessage (message));
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
                config_store.mark_dirty ();
                player.set_volume (volume);
                schedule_save ();
            });
        }

        public override Elmish.Cmd<Message>? save_config () {
            return new Elmish.Cmd<Message> ((dispatch) => {
                config_store.mark_dirty ();
                schedule_save ();
            });
        }

        public override Elmish.Cmd<Message>? load_favicons (GLib.GenericArray<RadioStation> stations) {
            var copy = new GLib.GenericArray<RadioStation> ();
            for (uint i = 0; i < stations.length; i++)
                copy.add (stations.get (i));

            return new Elmish.Cmd<Message> ((dispatch) => {
                queue_favicons (copy);
            });
        }

        public override Elmish.Cmd<Message>? clear_favicon_cache () {
            return new Elmish.Cmd<Message> ((dispatch) => {
                favicon_generation++;
                favicon_queue = new GLib.GenericArray<FaviconRequest> ();
                favicon_inflight.remove_all ();
                favicon_homepages.remove_all ();
                favicon_cache.clear_async (() => {});
                favicon_cooldown.clear ();
                favicon_backfilled.remove_all ();
            });
        }

        public void set_application (GLib.Application application) {
            this.application = application;
        }

        public override Elmish.Cmd<Message>? background_on_close () {
            return new Elmish.Cmd<Message> ((dispatch) => {
                var app = application;
                if (app == null)
                    return;
                app.activate_action ("hide-window", null);
                if (!background_hold) {
                    background_hold = true;
                    app.hold ();
                }
            });
        }

        public override Elmish.Cmd<Message>? release_background () {
            return new Elmish.Cmd<Message> ((dispatch) => {
                if (!background_hold)
                    return;
                background_hold = false;
                var app = application;
                if (app != null)
                    app.release ();
            });
        }

        public override Elmish.Cmd<Message>? quit_application () {
            return new Elmish.Cmd<Message> ((dispatch) => {
                var app = application;
                if (app != null)
                    app.quit ();
            });
        }

        public override Elmish.Cmd<Message>? inhibit_sleep () {
            return new Elmish.Cmd<Message> ((dispatch) => {
                inhibit_sleep_async.begin ();
            });
        }

        private async void inhibit_sleep_async () {
            yield sleep_inhibitor.acquire_async ();
        }

        public override Elmish.Cmd<Message>? release_sleep () {
            return new Elmish.Cmd<Message> ((dispatch) => {
                sleep_inhibitor.release ();
            });
        }

        public void shutdown () {
            CastService.shutdown ();
            sleep_inhibitor.release ();
            player.shutdown ();
            config_store.flush_sync ();
        }

        public override Elmish.Cmd<Message>? vote (string station_id) {
            return new Elmish.Cmd<Message> ((dispatch) => {
                vote_async.begin (station_id);
            });
        }

        public override Elmish.Cmd<Message>? import_stations (string path) {
            return new Elmish.Cmd<Message> ((dispatch) => {
                import_async (path);
            });
        }

        public override Elmish.Cmd<Message>? export_stations (GLib.GenericArray<RadioStation> stations,
                string path) {
            var copy = new GLib.GenericArray<RadioStation> ();
            for (uint i = 0; i < stations.length; i++)
                copy.add (stations.get (i));
            return new Elmish.Cmd<Message> ((dispatch) => {
                export_async (copy, path);
            });
        }

        public override Elmish.Cmd<Message>? export_playlist (GLib.GenericArray<RadioStation> stations,
                string path) {
            var copy = new GLib.GenericArray<RadioStation> ();
            for (uint i = 0; i < stations.length; i++)
                copy.add (stations.get (i));
            return new Elmish.Cmd<Message> ((dispatch) => {
                export_playlist_async (copy, path);
            });
        }

        public override Elmish.Cmd<Message>? load_filter_options () {
            return new Elmish.Cmd<Message> ((dispatch) => {
                load_filter_names_async.begin (SearchFilterKind.COUNTRY,
                    RadioBrowser.countries_path);
                load_filter_names_async.begin (SearchFilterKind.LANGUAGE,
                    RadioBrowser.languages_path);
                load_filter_names_async.begin (SearchFilterKind.TAG,
                    RadioBrowser.tags_path);
            });
        }

        public override Elmish.Cmd<Message>? refresh_library (GLib.GenericArray<RadioStation> stations) {
            var ids = new GLib.GenericArray<string> ();
            for (uint i = 0; i < stations.length; i++)
                ids.add (stations.get (i).id);
            return new Elmish.Cmd<Message> ((dispatch) => {
                refresh_library_async.begin (ids);
            });
        }

        public override Elmish.Cmd<Message>? discover_server () {
            return new Elmish.Cmd<Message> ((dispatch) => {
                discover_server_async.begin ();
            });
        }

        public override Elmish.Cmd<Message>? discover (uint generation) {
            return new Elmish.Cmd<Message> ((dispatch) => {
                discover_mode_async.begin (DiscoverMode.POPULAR, generation);
                discover_mode_async.begin (DiscoverMode.NEW, generation);
            });
        }

        public override Elmish.Cmd<Message>? report_click (string station_id) {
            return new Elmish.Cmd<Message> ((dispatch) => {
                report_click_async.begin (station_id);
            });
        }

        private async void report_click_async (string station_id) {
            try {
                yield RadioBrowser.report_click_async (session, station_id);
            } catch (GLib.Error e) {
                // Click reporting is fire-and-forget; playback already runs.
            }
        }

        private async void discover_mode_async (DiscoverMode mode, uint generation) {
            try {
                int limit = mode == DiscoverMode.POPULAR
                    ? RadioBrowser.DISCOVER_POPULAR_LIMIT
                    : RadioBrowser.DISCOVER_NEW_LIMIT;
                var stations = yield RadioBrowser.discover_async (session, mode,
                    Locale.region_code (), limit);
                if (dispatch != null)
                    dispatch (new DiscoverResultsMessage (mode, stations, generation));
            } catch (GLib.Error e) {
                if (dispatch != null)
                    dispatch (new DiscoverFailedMessage (mode, e.message, generation));
            }
        }

        private async void discover_server_async () {
            try {
                string? discovered_base = yield RadioBrowser.discover_server_async (session);
                if (dispatch != null && discovered_base != null)
                    dispatch (new ServerDiscoveredMessage (discovered_base));
            } catch (GLib.Error e) {
                if (dispatch != null)
                    dispatch (new ServerDiscoveryFailedMessage (e.message));
            }
        }

        private async void refresh_library_async (GLib.GenericArray<string> ids) {
            if (ids.length == 0)
                return;

            var updated_all = new GLib.GenericArray<RadioStation> ();
            string[] missing_all = {};

            for (uint offset = 0; offset < ids.length; offset += 100) {
                string[] batch = {};
                for (uint i = offset; i < ids.length && i < offset + 100; i++)
                    batch += ids.get (i);

                try {
                    var updated = yield RadioBrowser.stations_by_uuid_async (session, batch);
                    var found = new GLib.HashTable<string, bool> (str_hash, str_equal);
                    for (uint i = 0; i < updated.length; i++) {
                        updated_all.add (updated.get (i));
                        found.set (updated.get (i).id, true);
                    }
                    foreach (string id in batch) {
                        if (!found.contains (id))
                            missing_all += id;
                    }
                } catch (GLib.Error e) {
                    // A refresh is best-effort. Discard the whole result rather than
                    // marking stations orphaned because a batch failed.
                    return;
                }
            }

            if (dispatch != null)
                dispatch (new LibraryRefreshedMessage (updated_all, missing_all));
        }

        public override Elmish.Cmd<Message>? notify_error (string message) {
            return new Elmish.Cmd<Message> ((dispatch) => {
                var app = application;
                if (app == null)
                    return;
                var notification = new GLib.Notification (_("Playback error"));
                notification.set_body (message);
                notification.set_icon (new GLib.ThemedIcon ("dialog-error-symbolic"));
                notification.set_default_action ("app.raise");
                app.send_notification ("playback-error", notification);
            });
        }

        public override Elmish.Cmd<Message>? notify_now_playing (string station_name,
                string title) {
            return new Elmish.Cmd<Message> ((dispatch) => {
                var app = application;
                if (app == null)
                    return;
                var notification = new GLib.Notification (
                    station_name != "" ? station_name : _("Now playing"));
                notification.set_body (title != "" && title != station_name
                    ? title : _("Playing"));
                notification.set_icon (new GLib.ThemedIcon ("media-playback-start-symbolic"));
                notification.set_default_action ("app.raise");
                app.send_notification ("now-playing", notification);
            });
        }

        private void queue_favicons (GLib.GenericArray<RadioStation> stations) {
            for (uint i = 0; i < stations.length; i++) {
                var station = stations.get (i);
                if (station.id == "")
                    continue;

                var configured = config.find_station (station.id);
                string favicon = station.favicon;
                if (favicon == "" && configured != null)
                    favicon = configured.favicon;

                if (favicon != "") {
                    request_icon_url (station.id, favicon);
                    continue;
                }

                // Homepage discovery is only for library stations: it costs an
                // extra request and would otherwise run for every search result.
                if (configured == null)
                    continue;

                string homepage = station.homepage != "" ? station.homepage : configured.homepage;
                if (homepage == "" || !Http.is_valid_url (homepage))
                    continue;

                if (favicon_backfilled.contains (station.id)) {
                    resolve_homepage_favicon.begin (station.id, homepage);
                    continue;
                }

                favicon_backfilled.set (station.id, true);
                backfill_favicon.begin (station.id, homepage);
            }

            pump_favicons ();
        }

        private void request_icon_url (string station_id, string url) {
            if (!Http.is_valid_url (url))
                return;
            if (favicon_cooldown.is_blocked ("u:" + url, GLib.get_monotonic_time ()))
                return;

            uint generation = favicon_generation;
            var waiting = favicon_inflight.lookup (url);
            if (waiting != null) {
                waiting.add (station_id);
                return;
            }

            var ids = new GLib.GenericArray<string> ();
            ids.add (station_id);
            favicon_inflight.set (url, ids);

            favicon_cache.lookup_async (url, (cached) => {
                if (generation != favicon_generation)
                    return;
                if (cached != null) {
                    favicon_inflight.remove (url);
                    for (uint i = 0; i < ids.length; i++) {
                        if (this.dispatch != null) {
                            this.dispatch (new FaviconDiscoveredMessage (ids.get (i), url));
                            this.dispatch (new FaviconLoadedMessage (ids.get (i), url, cached));
                        }
                    }
                    return;
                }
                favicon_queue.add (new FaviconRequest (station_id, url, generation));
                pump_favicons ();
            });
        }



        private void pump_favicons () {
            while (favicon_active < FAVICON_CONCURRENCY && favicon_queue.length > 0) {
                var request = favicon_queue.get (0);
                favicon_queue.remove_index (0);
                favicon_active++;
                fetch_favicon.begin (request.url, request.generation);
            }
        }

        private async void backfill_favicon (string station_id, string homepage) {
            uint generation = favicon_generation;
            try {
                var updated = yield RadioBrowser.station_by_uuid_async (session, station_id);
                if (generation != favicon_generation)
                    return;
                if (updated != null && updated.favicon != "" &&
                        Http.is_valid_url (updated.favicon)) {
                    request_icon_url (station_id, updated.favicon);
                    return;
                }
            } catch (GLib.Error e) {
            }

            if (generation != favicon_generation)
                return;
            resolve_homepage_favicon.begin (station_id, homepage);
        }

        private async void resolve_homepage_favicon (string station_id, string homepage) {
            uint generation = favicon_generation;
            string key = "h:" + homepage;
            int64 now = GLib.get_monotonic_time ();
            if (favicon_cooldown.is_blocked (key, now))
                return;

            var waiters = favicon_homepages.lookup (homepage);
            if (waiters != null) {
                waiters.add (station_id);
                return;
            }

            waiters = new GLib.GenericArray<string> ();
            waiters.add (station_id);
            favicon_homepages.set (homepage, waiters);
            string? icon_url = null;
            bool html_failed = false;
            try {
                string html = yield Http.get_string_async (session, homepage);
                if (generation != favicon_generation)
                    return;
                if (html.length <= 512 * 1024)
                    icon_url = yield parse_icon_url_async (html, homepage);
            } catch (GLib.Error e) {
                html_failed = true;
            }
            if (generation != favicon_generation)
                return;
            favicon_homepages.remove (homepage);

            if (icon_url == null)
                icon_url = FaviconResolver.origin_icon_url (homepage);

            if (icon_url == null) {
                favicon_cooldown.record_failure (key, now);
                return;
            }
            if (html_failed)
                favicon_cooldown.record_failure (key, now);

            for (uint i = 0; i < waiters.length; i++)
                request_icon_url (waiters.get (i), icon_url);
        }

        private async string? parse_icon_url_async (string html, string homepage) {
            string? icon_url = null;
            var loop = new GLib.MainLoop ();
            BackgroundTask.run (() => {
                icon_url = FaviconResolver.icon_url_from_html (html, homepage);
                return true;
            }, () => {
                loop.quit ();
            });
            loop.run ();
            return icon_url;
        }

        private async void fetch_favicon (string url, uint generation) {
            try {
                var bytes = yield Http.get_bytes_async (session, url);
                unowned uint8[]? data = bytes.get_data ();
                if (data != null) {
                    if (generation != favicon_generation) {
                        finish_favicon (url, "", generation);
                        return;
                    }
                    var payload = data;
                    favicon_cache.store_async (url, payload, (stored) => {
                        if (generation != favicon_generation) {
                            finish_favicon (url, "", generation);
                            return;
                        }
                        if (stored == null || stored == "")
                            favicon_cooldown.record_failure ("u:" + url,
                                GLib.get_monotonic_time ());
                        finish_favicon (url, stored ?? "", generation);
                    });
                    return;
                }
            } catch (GLib.Error e) {
            }

            if (generation == favicon_generation)
                favicon_cooldown.record_failure ("u:" + url,
                    GLib.get_monotonic_time ());
            finish_favicon (url, "", generation);
        }

        private void finish_favicon (string url, string path, uint generation) {
            favicon_active--;
            if (generation == favicon_generation) {
                unowned GLib.GenericArray<string>? ids = favicon_inflight.lookup (url);
                if (ids != null) {
                    for (uint i = 0; i < ids.length; i++) {
                        if (dispatch != null) {
                            if (path != "")
                                dispatch (new FaviconDiscoveredMessage (ids.get (i), url));
                            dispatch (new FaviconLoadedMessage (ids.get (i), url, path));
                        }
                    }
                    favicon_inflight.remove (url);
                }
            }
            pump_favicons ();
        }

        public void save_now () {
            // Synchronous convenience for tests and shutdown. The interactive
            // path uses ConfigStore.save() so the main loop is never blocked.
            config_store.flush_sync ();
        }

        private void schedule_save () {
            if (save_id != 0)
                GLib.Source.remove (save_id);
            save_id = GLib.Timeout.add (500, () => {
                save_id = 0;
                config_store.save ();
                return false;
            });
        }

        private void import_async (string path) {
            FileIO.load_text_async.begin (path, (obj, res) => {
                string contents;
                try {
                    contents = FileIO.load_text_async.end (res);
                } catch (GLib.Error e) {
                    if (dispatch != null)
                        dispatch (new ImportFailedMessage (e.message));
                    return;
                }

                BackgroundTask.run (() => {
                    try {
                        var stations = StationTransfer.parse (contents);
                        if (dispatch != null)
                            dispatch (new StationsImportedMessage (stations));
                    } catch (GLib.Error e) {
                        if (dispatch != null)
                            dispatch (new ImportFailedMessage (e.message));
                    }
                    return true;
                }, (ok) => {});
            });
        }

        private void export_async (GLib.GenericArray<RadioStation> stations, string path) {
            BackgroundTask.run (() => {
                try {
                    string data = StationTransfer.export_json (stations);
                    FileIO.save_text_atomic_sync (path, data);
                    if (dispatch != null)
                        dispatch (new ExportSucceededMessage (path, (int) stations.length));
                } catch (GLib.Error e) {
                    if (dispatch != null)
                        dispatch (new ExportFailedMessage (e.message));
                }
                return true;
            }, (ok) => {});
        }

        private void export_playlist_async (GLib.GenericArray<RadioStation> stations,
                string path) {
            BackgroundTask.run (() => {
                try {
                    string data = StationTransfer.export_m3u (stations);
                    FileIO.save_text_atomic_sync (path, data);
                    if (dispatch != null)
                        dispatch (new ExportSucceededMessage (path, (int) stations.length));
                } catch (GLib.Error e) {
                    if (dispatch != null)
                        dispatch (new ExportFailedMessage (e.message));
                }
                return true;
            }, (ok) => {});
        }

        private async void load_filter_names_async (SearchFilterKind field, string endpoint) {
            try {
                var names = yield RadioBrowser.filter_names_async (session, endpoint);
                if (dispatch != null)
                    dispatch (new FilterOptionsLoadedMessage (field, names));
            } catch (GLib.Error e) {
                // Filter lists are a convenience: fall back to the entries the
                // user already has instead of reporting an error.
            }
        }

        private async void vote_async (string station_id) {
            try {
                var result = yield RadioBrowser.vote_async (session, station_id);
                if (dispatch == null)
                    return;
                if (result.ok)
                    dispatch (new VoteSucceededMessage (station_id, result.station));
                else
                    dispatch (new VoteFailedMessage (station_id, _("Voting failed")));
            } catch (GLib.Error e) {
                if (dispatch != null)
                    dispatch (new VoteFailedMessage (station_id, e.message));
            }
        }

        private async void search_async (string query, uint generation) {
            try {
                var stations = yield RadioBrowser.search_async (session, query, 50, config.search_filters);
                if (dispatch != null)
                    dispatch (new SearchResultsMessage (stations, generation));
            } catch (GLib.Error e) {
                if (dispatch != null)
                    dispatch (new SearchFailedMessage (e.message, generation));
            }
        }

    public override Elmish.Cmd<Gradio.Message>? discover_cast () {
        return Gradio.CastService.discover_cmd ();
    }

    public override Elmish.Cmd<Gradio.Message>? cast (string device_id, string host,
            int port, string url) {
        return Gradio.CastService.cast_cmd (device_id, host, port, url);
    }

    public override Elmish.Cmd<Gradio.Message>? stop_cast (string device_id, string host,
            int port) {
        return Gradio.CastService.stop_cmd (device_id, host, port);
    }
    }
}
