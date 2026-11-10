// SPDX-License-Identifier: GPL-3.0-or-later

using Soup;

namespace Gradio {

    public class VoteResult : GLib.Object {
        public bool ok = false;
        public RadioStation? station = null;
    }

    public class RadioBrowser {
        public const string radio_browser = "https://de1.api.radio-browser.info/json";
        public const string radio_station_search = radio_browser + "/stations/search";
        public const string countries_endpoint = radio_browser + "/countries";
        public const string languages_endpoint = radio_browser + "/languages";
        public const string tags_endpoint = radio_browser + "/tags";

        public static string search_url (string query, int limit = 50, SearchFilters? filters = null) {
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
            return Http.url_with_query (radio_station_search, params);
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
        public static string filter_list_url (string endpoint) {
            var params = new GLib.HashTable<string, string> (str_hash, str_equal);
            params.insert ("hidebroken", "true");
            params.insert ("order", "stationcount");
            params.insert ("reverse", "true");
            return Http.url_with_query (endpoint, params);
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

        public static async string[] load_names_async (Soup.Session session, string endpoint,
            GLib.Cancellable? cancellable = null) throws GLib.Error {
            string contents = yield Http.get_string_async (session,
                filter_list_url (endpoint), cancellable);
            return parse_names (contents);
        }

        public static string station_by_uuid_url (string uuid) {
            return radio_browser + "/stations/byuuid/" + GLib.Uri.escape_string (uuid);
        }

        public static async RadioStation? station_by_uuid_async (Soup.Session session,
            string uuid, GLib.Cancellable? cancellable = null) throws GLib.Error {
            string contents = yield Http.get_string_async (session,
                station_by_uuid_url (uuid), cancellable);
            var stations = parse_stations (contents);
            if (stations.length == 0)
                return null;
            return stations.get (0);
        }

        public static string stations_by_uuid_url () {
            return radio_browser + "/stations/byuuid";
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
            string contents = yield Http.post_string_async (session, stations_by_uuid_url (),
                stations_by_uuid_body (ids), "application/json", cancellable);
            return parse_stations (contents);
        }

        public static async GLib.GenericArray<RadioStation> search_async (Soup.Session session,
            string query, int limit = 50, SearchFilters? filters = null,
            GLib.Cancellable? cancellable = null) throws GLib.Error {
            string contents = yield Http.get_string_async (session,
                search_url (query, limit, filters), cancellable);
            return parse_stations (contents);
        }

        public static string vote_url (string uuid) {
            return radio_browser + "/vote/" + GLib.Uri.escape_string (uuid);
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
            string contents = yield Http.get_string_async (session, vote_url (uuid), cancellable);
            return parse_vote_response (contents);
        }
    }
}
