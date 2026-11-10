// SPDX-License-Identifier: GPL-3.0-or-later

using Soup;

namespace Gradio {

    public class RadioBrowser {
        public const string radio_browser = "https://de1.api.radio-browser.info/json";
        public const string radio_station_search = radio_browser + "/stations/search";

        public static string search_url (string query, int limit = 50, SearchFilters? filters = null) {            var params = new GLib.HashTable<string,string> (str_hash, str_equal);
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

        public static async GLib.GenericArray<RadioStation> search_async (Soup.Session session,
            string query, int limit = 50, SearchFilters? filters = null,
            GLib.Cancellable? cancellable = null) throws GLib.Error {
            string contents = yield Http.get_string_async (session,
                search_url (query, limit, filters), cancellable);
            return parse_stations (contents);
        }
    }
}
