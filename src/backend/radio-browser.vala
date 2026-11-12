// SPDX-License-Identifier: GPL-3.0-or-later

using Soup;

namespace Gradio {

    public class VoteResult : GLib.Object {
        public bool ok = false;
        public RadioStation? station = null;
    }

    public class RadioBrowser {
        public const string radio_browser = "https://de1.api.radio-browser.info/json";
        public static string? api_base = null;
        public static string[]? server_candidates = null;

        public const string search_path = "/stations/search";
        public const string countries_path = "/countries";
        public const string languages_path = "/languages";
        public const string tags_path = "/tags";

        public const string radio_station_search = radio_browser + search_path;
        public const string languages_endpoint = radio_browser + languages_path;
        public const string tags_endpoint = radio_browser + tags_path;

        public const int DISCOVER_POPULAR_LIMIT = 100;
        public const int DISCOVER_NEW_LIMIT = 18;

        public static string api_url (string path) {
            string normalized = path.strip ();
            if (normalized.has_prefix ("http://") || normalized.has_prefix ("https://"))
                return normalized;

            string prefix = api_base;
            if (prefix == null || prefix == "")
                prefix = radio_browser;
            while (prefix.has_suffix ("/"))
                prefix = prefix.substring (0, prefix.length - 1);
            while (normalized.has_prefix ("/"))
                normalized = normalized.substring (1);
            return prefix + "/" + normalized;
        }

        public static GLib.HashTable<string,string> search_params (string query, int limit,
                SearchFilters? filters = null) {
            var params = new GLib.HashTable<string,string> (str_hash, str_equal);
            params.insert ("name", query);
            params.insert ("limit", limit.to_string ());
            params.insert ("hidebroken", "true");
            params.insert ("order", "clickcount");
            params.insert ("reverse", "true");
            if (filters != null) {
                if (filters.country != "")
                    params.insert ("country", filters.country);
                if (filters.state != "")
                    params.insert ("state", filters.state);
                if (filters.language != "")
                    params.insert ("language", filters.language);
                if (filters.tag != "")
                    params.insert ("tagList", filters.tag);
            }
            return params;
        }

        public static string search_url (string query, int limit = 50, SearchFilters? filters = null) {
            return Http.url_with_query (api_url (search_path),
                search_params (query, limit, filters));
        }

        public static GLib.GenericArray<RadioStation> parse_stations (string json) throws GLib.Error {
            var stations = new GLib.GenericArray<RadioStation> ();

            var parser = new Json.Parser ();
            parser.load_from_data (json);
            var root = parser.get_root ();
            if (root == null || root.get_value_type () != typeof (Json.Array))
                throw new GLib.FileError.FAILED ("invalid station list");

            var array = root.get_array ();
            for (uint i = 0; i < array.get_length (); i++) {
                var element = array.get_element (i);
                if (element == null || element.get_value_type () != typeof (Json.Object))
                    continue;

                var station = RadioStation.from_json_object (element.get_object ());
                if (station == null)
                    continue;
                if (station.id == "" || station.name == "" || station.url == "")
                    continue;

                stations.add (station);
            }

            return stations;
        }

        // Filter pickers are filled from the reference endpoints. The station
        // count order puts the most useful values first.
        private static GLib.HashTable<string, string> filter_list_params () {
            var params = new GLib.HashTable<string, string> (str_hash, str_equal);
            params.insert ("hidebroken", "true");
            params.insert ("order", "stationcount");
            params.insert ("reverse", "true");
            return params;
        }

        public static string[] parse_names (string json) throws GLib.Error {
            var parser = new Json.Parser ();
            parser.load_from_data (json);
            var root = parser.get_root ();
            if (root == null || root.get_value_type () != typeof (Json.Array))
                throw new GLib.FileError.FAILED ("invalid filter list");

            var array = root.get_array ();
            string[] names = {};
            for (uint i = 0; i < array.get_length (); i++) {
                var element = array.get_element (i);
                if (element == null || element.get_value_type () != typeof (Json.Object))
                    continue;
                var object = element.get_object ();
                var node = object.get_member ("name");
                if (node == null || node.get_value_type () != typeof (string))
                    continue;
                string name = node.get_string ().strip ();
                if (name != "")
                    names += name;
            }
            return names;
        }

        public static async string[] filter_names_async (Soup.Session session, string path,
            GLib.Cancellable? cancellable = null) throws GLib.Error {
            string contents = yield api_get_async (session, path, filter_list_params (),
                cancellable);
            return parse_names (contents);
        }

        public static string station_by_uuid_url (string uuid) {
            return api_url ("/stations/byuuid/" + GLib.Uri.escape_string (uuid));
        }

        public static async RadioStation? station_by_uuid_async (Soup.Session session,
            string uuid, GLib.Cancellable? cancellable = null) throws GLib.Error {
            string contents = yield api_get_async (session,
                "/stations/byuuid/" + GLib.Uri.escape_string (uuid), null, cancellable);
            var stations = parse_stations (contents);
            if (stations.length == 0)
                return null;
            return stations.get (0);
        }

        public static string stations_by_uuid_url () {
            return api_url ("/stations/byuuid");
        }

        public static string stations_by_uuid_body (string[] ids) {
            var builder = new Json.Builder ();
            builder.begin_object ();
            builder.set_member_name ("uuids");
            builder.begin_array ();
            foreach (string id in ids)
                builder.add_string_value (id);
            builder.end_array ();
            builder.end_object ();
            var generator = new Json.Generator ();
            generator.set_root (builder.get_root ());
            size_t length;
            return generator.to_data (out length);
        }

        public static async GLib.GenericArray<RadioStation> stations_by_uuid_async (
                Soup.Session session, string[] ids, GLib.Cancellable? cancellable = null)
                throws GLib.Error {
            string contents = yield api_post_async (session, "/stations/byuuid",
                stations_by_uuid_body (ids), cancellable);
            return parse_stations (contents);
        }

        public static GLib.HashTable<string,string> discover_params (DiscoverMode mode,
                string region, int limit) {
            var params = new GLib.HashTable<string,string> (str_hash, str_equal);
            params.insert ("countrycode", region);
            params.insert ("limit", limit.to_string ());
            if (mode == DiscoverMode.POPULAR) {
                params.insert ("order", "votes");
                params.insert ("reverse", "true");
                params.insert ("hidebroken", "true");
            } else {
                params.insert ("order", "random");
            }
            return params;
        }

        public static string discover_url (DiscoverMode mode, string region, int limit) {
            return Http.url_with_query (api_url (search_path),
                discover_params (mode, region, limit));
        }

        public static async GLib.GenericArray<RadioStation> discover_async (Soup.Session session,
            DiscoverMode mode, string region, int limit,
            GLib.Cancellable? cancellable = null) throws GLib.Error {
            string contents = yield api_get_async (session, search_path,
                discover_params (mode, region, limit), cancellable);
            return parse_stations (contents);
        }

        public static async GLib.GenericArray<RadioStation> search_async (Soup.Session session,
            string query, int limit = 50, SearchFilters? filters = null,
            GLib.Cancellable? cancellable = null) throws GLib.Error {
            string contents = yield api_get_async (session, search_path,
                search_params (query, limit, filters), cancellable);
            return parse_stations (contents);
        }

        public static string vote_url (string uuid) {
            return api_url ("/vote/" + GLib.Uri.escape_string (uuid));
        }

        // The server either answers {"ok": true, ...} or returns the changed
        // station object directly. Accept both shapes.
        public static VoteResult parse_vote_response (string json) throws GLib.Error {
            var result = new VoteResult ();
            var parser = new Json.Parser ();
            parser.load_from_data (json);
            var root = parser.get_root ();
            if (root == null)
                throw new GLib.FileError.FAILED ("invalid vote response");

            if (root.get_value_type () == typeof (Json.Array)) {
                var array = root.get_array ();
                if (array.get_length () > 0 &&
                        array.get_element (0).get_value_type () == typeof (Json.Object)) {
                    var station = RadioStation.from_json_object (array.get_element (0).get_object ());
                    if (station != null) {
                        result.ok = true;
                        result.station = station;
                    }
                }
                return result;
            }

            if (root.get_value_type () != typeof (Json.Object))
                throw new GLib.FileError.FAILED ("invalid vote response");

            var object = root.get_object ();
            if (object.has_member ("ok")) {
                result.ok = object.get_boolean_member ("ok");
                if (!result.ok)
                    return result;
            }
            if (object.has_member ("stationuuid")) {
                var station = RadioStation.from_json_object (object);
                if (station != null) {
                    result.ok = true;
                    result.station = station;
                }
            }
            return result;
        }

        public static async VoteResult vote_async (Soup.Session session, string uuid,
            GLib.Cancellable? cancellable = null) throws GLib.Error {
            string contents = yield api_get_async (session,
                "/vote/" + GLib.Uri.escape_string (uuid), null, cancellable);
            return parse_vote_response (contents);
        }

        public static string click_url (string uuid) {
            return api_url ("/url/" + GLib.Uri.escape_string (uuid));
        }

        public static async string report_click_async (Soup.Session session, string uuid,
            GLib.Cancellable? cancellable = null) throws GLib.Error {
            return yield api_get_async (session,
                "/url/" + GLib.Uri.escape_string (uuid), null, cancellable);
        }

        public static string server_base_for_host (string hostname) throws GLib.Error {
            string host = hostname.strip ();
            while (host.has_suffix ("."))
                host = host.substring (0, host.length - 1);
            if (host == "")
                throw new GLib.FileError.FAILED ("empty hostname");
            return "https://" + host + "/json";
        }

        public static string[] ordered_candidates (string[] hostnames) {
            var seen = new GLib.HashTable<string, bool> (str_hash, str_equal);
            string[] result = {};
            foreach (string raw in hostnames) {
                string host = raw.strip ();
                if (host == "" || seen.contains (host))
                    continue;
                seen.set (host, true);
                result += host;
            }
            return result;
        }

        public static string? next_candidate (string current, string[] candidates) {
            for (uint i = 0; i < candidates.length; i++) {
                if (candidates[i] != current)
                    continue;
                if (i + 1 < candidates.length)
                    return candidates[i + 1];
                return null;
            }
            if (candidates.length > 0)
                return candidates[0];
            return null;
        }

        public static async string? discover_server_async (Soup.Session session,
            GLib.Cancellable? cancellable = null) throws GLib.Error {
            var resolver = GLib.Resolver.get_default ();
            var resolved = yield resolver.lookup_by_name_async (
                "all.api.radio-browser.info", cancellable);

            var addresses = new GLib.GenericArray<GLib.InetAddress> ();
            foreach (unowned GLib.InetAddress address in resolved)
                addresses.add (address);
            for (uint i = addresses.length; i > 1; i--) {
                uint j = (uint) GLib.Random.int_range (0, (int) i);
                var swap = addresses.get (i - 1);
                addresses.set (i - 1, addresses.get (j));
                addresses.set (j, swap);
            }

            string[] hosts = {};
            foreach (var address in addresses) {
                try {
                    string host = yield resolver.lookup_by_address_async (address, cancellable);
                    if (host != "")
                        hosts += host;
                } catch (GLib.Error e) {
                    // One address without a reverse name must not stop discovery.
                }
            }

            string[] candidates = ordered_candidates (hosts);
            string[] healthy = {};
            foreach (string host in candidates) {
                string server_base;
                try {
                    server_base = server_base_for_host (host);
                    yield Http.get_string_async (session, server_base + "/stats", cancellable);
                    healthy += server_base;
                } catch (GLib.Error e) {
                    // Skip unhealthy servers; another candidate may answer.
                }
            }

            if (healthy.length == 0)
                throw new HttpError.REQUEST_FAILED ("No radio-browser server available");

            server_candidates = healthy;
            api_base = healthy[0];
            return api_base;
        }

        public static bool failover () {
            string current = api_base;
            if (current == null || current == "")
                current = radio_browser;
            string[]? known = server_candidates;
            if (known == null)
                return false;
            string? next = next_candidate (current, known);
            if (next == null)
                return false;
            api_base = next;
            return true;
        }

        private static async string api_get_async (Soup.Session session, string path,
                GLib.HashTable<string,string>? query,
                GLib.Cancellable? cancellable) throws GLib.Error {
            try {
                return yield Http.get_string_async (session,
                    Http.url_with_query (api_url (path), query), cancellable);
            } catch (GLib.Error first) {
                if (!Http.should_failover (first) || !failover ())
                    throw first;
                return yield Http.get_string_async (session,
                    Http.url_with_query (api_url (path), query), cancellable);
            }
        }

        private static async string api_post_async (Soup.Session session, string path,
                string body, GLib.Cancellable? cancellable) throws GLib.Error {
            try {
                return yield Http.post_string_async (session, api_url (path), body,
                    "application/json", cancellable);
            } catch (GLib.Error first) {
                if (!Http.should_failover (first) || !failover ())
                    throw first;
                return yield Http.post_string_async (session, api_url (path), body,
                    "application/json", cancellable);
            }
        }
    }
}
