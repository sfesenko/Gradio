// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    private class FaviconRequest : GLib.Object {
        public string station_id;
        public string url;

        public FaviconRequest (string station_id, string url) {
            this.station_id = station_id;
            this.url = url;
        }
    }

    public class AppRuntime : Gradio.Commands {
        private const int FAVICON_CONCURRENCY = 4;

        public Elmish.Dispatch<Message>? dispatch { get; private set; }
        public AppConfig config { get; private set; }
        public Player player { get; private set; }
        public FaviconCache favicon_cache { get; private set; }

        private Soup.Session session;        private uint save_id = 0;
        private bool signals_connected = false;
        private bool load_failed;
        private bool dirty = false;
        private bool backup_pending;
        private GLib.GenericArray<FaviconRequest> favicon_queue = new GLib.GenericArray<FaviconRequest> ();
        private GLib.HashTable<string, GLib.GenericArray<string>> favicon_inflight =
            new GLib.HashTable<string, GLib.GenericArray<string>> (str_hash, str_equal);
        private GLib.HashTable<string, bool> favicon_backfilled =
            new GLib.HashTable<string, bool> (str_hash, str_equal);
        private GLib.HashTable<string, bool> favicon_homepages =
            new GLib.HashTable<string, bool> (str_hash, str_equal);
        private FaviconCooldown favicon_cooldown = new FaviconCooldown ();
        private int favicon_active = 0;
        private GLib.Application? application = null;

        public AppRuntime (AppConfig config, bool load_failed = false, string? favicon_dir = null) {
            this.config = config;
            this.load_failed = load_failed;
            this.backup_pending = load_failed;
            session = new Soup.Session ();
            session.set_user_agent ("gradio-gtk4");
            session.timeout = 10;
            player = new Player ();
            favicon_cache = new FaviconCache (favicon_dir);
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
                dirty = true;
                player.set_volume (volume);
                schedule_save ();
            });
        }

        public override Elmish.Cmd<Message>? save_config () {
            return new Elmish.Cmd<Message> ((dispatch) => {
                dirty = true;
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
                favicon_cache.clear ();
                favicon_cooldown.clear ();
                favicon_backfilled.remove_all ();
            });
        }

        public void set_application (GLib.Application application) {
            this.application = application;
        }

        public override Elmish.Cmd<Message>? vote (string station_id) {
            return new Elmish.Cmd<Message> ((dispatch) => {
                vote_async.begin (station_id);
            });
        }

        public override Elmish.Cmd<Message>? import_stations (string path) {
            return new Elmish.Cmd<Message> ((dispatch) => {
                import_async.begin (path);
            });
        }

        public override Elmish.Cmd<Message>? export_stations (GLib.GenericArray<RadioStation> stations,
                string path) {
            var copy = new GLib.GenericArray<RadioStation> ();
            for (uint i = 0; i < stations.length; i++)
                copy.add (stations.get (i));
            return new Elmish.Cmd<Message> ((dispatch) => {
                export_async.begin (copy, path);
            });
        }

        public override Elmish.Cmd<Message>? export_playlist (GLib.GenericArray<RadioStation> stations,
                string path) {
            var copy = new GLib.GenericArray<RadioStation> ();
            for (uint i = 0; i < stations.length; i++)
                copy.add (stations.get (i));
            return new Elmish.Cmd<Message> ((dispatch) => {
                export_playlist_async.begin (copy, path);
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
            var target = dispatch;
            try {
                int limit = mode == DiscoverMode.POPULAR
                    ? RadioBrowser.DISCOVER_POPULAR_LIMIT
                    : RadioBrowser.DISCOVER_NEW_LIMIT;
                var stations = yield RadioBrowser.discover_async (session, mode,
                    Locale.region_code (), limit);
                if (target != null)
                    target (new DiscoverResultsMessage (mode, stations, generation));
            } catch (GLib.Error e) {
                if (target != null)
                    target (new DiscoverFailedMessage (mode, e.message, generation));
            }
        }

        private async void discover_server_async () {
            var target = dispatch;
            try {
                string? discovered_base = yield RadioBrowser.discover_server_async (session);
                if (target != null && discovered_base != null)
                    target (new ServerDiscoveredMessage (discovered_base));
            } catch (GLib.Error e) {
                if (target != null)
                    target (new ServerDiscoveryFailedMessage (e.message));
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

            var target_dispatch = dispatch;
            if (target_dispatch != null)
                target_dispatch (new LibraryRefreshedMessage (updated_all, missing_all));
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

            string? cached = favicon_cache.lookup (url);
            if (cached != null) {
                dispatch_cached_favicon (station_id, url, cached);
                return;
            }

            var waiting = favicon_inflight.lookup (url);
            if (waiting != null) {
                waiting.add (station_id);
                return;
            }

            var ids = new GLib.GenericArray<string> ();
            ids.add (station_id);
            favicon_inflight.set (url, ids);
            favicon_queue.add (new FaviconRequest (station_id, url));
            pump_favicons ();
        }

        private void dispatch_cached_favicon (string station_id, string url, string path) {
            GLib.Idle.add (() => {
                var target = this.dispatch;
                if (target != null) {
                    target (new FaviconDiscoveredMessage (station_id, url));
                    target (new FaviconLoadedMessage (station_id, url, path));
                }
                return false;
            });
        }

        private void pump_favicons () {
            while (favicon_active < FAVICON_CONCURRENCY && favicon_queue.length > 0) {
                var request = favicon_queue.get (0);
                favicon_queue.remove_index (0);
                favicon_active++;
                fetch_favicon.begin (request.url);
            }
        }

        private async void backfill_favicon (string station_id, string homepage) {
            try {
                var updated = yield RadioBrowser.station_by_uuid_async (session, station_id);
                if (updated != null && updated.favicon != "" &&
                        Http.is_valid_url (updated.favicon)) {
                    request_icon_url (station_id, updated.favicon);
                    return;
                }
            } catch (GLib.Error e) {
            }

            resolve_homepage_favicon.begin (station_id, homepage);
        }

        private async void resolve_homepage_favicon (string station_id, string homepage) {
            string key = "h:" + homepage;
            int64 now = GLib.get_monotonic_time ();
            if (favicon_cooldown.is_blocked (key, now))
                return;
            if (favicon_homepages.contains (homepage))
                return;

            favicon_homepages.set (homepage, true);
            string? icon_url = null;
            bool html_failed = false;
            try {
                string html = yield Http.get_string_async (session, homepage);
                if (html.length <= 512 * 1024)
                    icon_url = FaviconResolver.icon_url_from_html (html, homepage);
            } catch (GLib.Error e) {
                html_failed = true;
            }
            favicon_homepages.remove (homepage);

            if (icon_url == null)
                icon_url = FaviconResolver.origin_icon_url (homepage);

            if (icon_url == null) {
                favicon_cooldown.record_failure (key, now);
                return;
            }
            if (html_failed)
                favicon_cooldown.record_failure (key, now);

            request_icon_url (station_id, icon_url);
        }

        private async void fetch_favicon (string url) {
            string path = "";
            try {
                var bytes = yield Http.get_bytes_async (session, url);
                unowned uint8[]? data = bytes.get_data ();
                if (data != null) {
                    string? stored = favicon_cache.store (url, data);
                    if (stored != null)
                        path = stored;
                }
            } catch (GLib.Error e) {
            }

            if (path == "")
                favicon_cooldown.record_failure ("u:" + url, GLib.get_monotonic_time ());
            finish_favicon (url, path);
        }

        private void finish_favicon (string url, string path) {
            favicon_active--;
            unowned GLib.GenericArray<string>? ids = favicon_inflight.lookup (url);
            if (ids != null) {
                for (uint i = 0; i < ids.length; i++) {
                    var target = dispatch;
                    if (target != null) {
                        if (path != "")
                            target (new FaviconDiscoveredMessage (ids.get (i), url));
                        target (new FaviconLoadedMessage (ids.get (i), url, path));
                    }
                }
                favicon_inflight.remove (url);
            }
            pump_favicons ();
        }

        public void save_now () {
            if (load_failed && !dirty)
                return;

            if (backup_pending) {
                backup_pending = false;
                if (GLib.FileUtils.test (config.path, GLib.FileTest.EXISTS)) {
                    string backup = config.path + ".corrupt";
                    GLib.FileUtils.remove (backup);
                    GLib.FileUtils.rename (config.path, backup);
                }
            }

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

        private async void import_async (string path) {
            var target = dispatch;
            try {
                string contents;
                GLib.FileUtils.get_contents (path, out contents);
                var stations = StationTransfer.parse (contents);
                if (target != null)
                    target (new StationsImportedMessage (stations));
            } catch (GLib.Error e) {
                if (target != null)
                    target (new ImportFailedMessage (e.message));
            }
        }

        private async void export_async (GLib.GenericArray<RadioStation> stations, string path) {
            var target = dispatch;
            try {
                string data = StationTransfer.export_json (stations);
                GLib.FileUtils.set_contents (path, data);
                if (target != null)
                    target (new ExportSucceededMessage (path, (int) stations.length));
            } catch (GLib.Error e) {
                if (target != null)
                    target (new ExportFailedMessage (e.message));
            }
        }

        private async void export_playlist_async (GLib.GenericArray<RadioStation> stations,
                string path) {
            var target = dispatch;
            try {
                string data = StationTransfer.export_m3u (stations);
                GLib.FileUtils.set_contents (path, data);
                if (target != null)
                    target (new ExportSucceededMessage (path, (int) stations.length));
            } catch (GLib.Error e) {
                if (target != null)
                    target (new ExportFailedMessage (e.message));
            }
        }

        private async void load_filter_names_async (SearchFilterKind field, string endpoint) {
            var target = dispatch;
            try {
                var names = yield RadioBrowser.filter_names_async (session, endpoint);
                if (target != null)
                    target (new FilterOptionsLoadedMessage (field, names));
            } catch (GLib.Error e) {
                // Filter lists are a convenience: fall back to the entries the
                // user already has instead of reporting an error.
            }
        }

        private async void vote_async (string station_id) {
            var target = dispatch;
            try {
                var result = yield RadioBrowser.vote_async (session, station_id);
                if (target == null)
                    return;
                if (result.ok)
                    target (new VoteSucceededMessage (station_id, result.station));
                else
                    target (new VoteFailedMessage (station_id, _("Voting failed")));
            } catch (GLib.Error e) {
                if (target != null)
                    target (new VoteFailedMessage (station_id, e.message));
            }
        }

        private async void search_async (string query, uint generation) {            try {
                var stations = yield RadioBrowser.search_async (session, query, 50, config.search_filters);
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
