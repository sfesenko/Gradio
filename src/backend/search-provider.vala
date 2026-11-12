// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    [DBus (name = "org.gnome.Shell.SearchProvider2")]
    public interface SearchProviderIface : GLib.Object {
        public abstract async string[] get_initial_result_set (string[] terms) throws GLib.Error;
        public abstract async string[] get_subsearch_result_set (string[] previous_results,
            string[] terms) throws GLib.Error;

        [DBus (name = "GetResultMetas")]
        public abstract async GLib.HashTable<string, GLib.Variant>[] get_result_metas (
            string[] ids) throws GLib.Error;

        public abstract void activate_result (string identifier, string[] terms,
            uint timestamp) throws GLib.Error;
        public abstract void launch_search (string[] terms, uint timestamp) throws GLib.Error;
    }

    // GNOME Shell search provider for the local station library. Only the
    // name is matched, and results are station IDs.
    public class SearchProvider : GLib.Object, SearchProviderIface {
        public signal void station_activated (RadioStation station);
        public signal void search_launched ();

        private const int MAX_RESULTS = 20;

        private AppConfig config;

        public SearchProvider (AppConfig config) {
            this.config = config;
        }

        public bool register (GLib.DBusConnection connection) {
            try {
                connection.register_object<SearchProviderIface> (
                    "/io/github/sfesenko/gradio/SearchProvider", this);
                return true;
            } catch (GLib.Error e) {
                return false;
            }
        }

        public async string[] get_initial_result_set (string[] terms) throws GLib.Error {
            return match_ids (config, terms);
        }

        public async string[] get_subsearch_result_set (string[] previous_results,
                string[] terms) throws GLib.Error {
            string[] matches = match_ids (config, terms);
            string[] result = {};
            foreach (string id in matches) {
                foreach (string previous in previous_results) {
                    if (previous == id) {
                        result += id;
                        break;
                    }
                }
            }
            return result;
        }

        public async GLib.HashTable<string, GLib.Variant>[] get_result_metas (
                string[] ids) throws GLib.Error {
            GLib.HashTable<string, GLib.Variant>[] metas = {};
            foreach (string id in ids) {
                var station = config.find_station (id);
                // The shell expects one entry per requested id; keep the
                // arrays aligned even if the library changed in between.
                metas += station != null ? result_meta (station) : placeholder_meta (id);
            }
            return metas;
        }

        public void activate_result (string identifier, string[] terms,
                uint timestamp) throws GLib.Error {
            var station = config.find_station (identifier);
            if (station != null)
                station_activated (station);
        }

        public void launch_search (string[] terms, uint timestamp) throws GLib.Error {
            search_launched ();
        }

        public static string[] match_ids (AppConfig config, string[] terms) {
            string[] result = {};
            var effective = new GLib.GenericArray<string> ();
            foreach (string term in terms) {
                string normalized = term.strip ().down ();
                if (normalized != "")
                    effective.add (normalized);
            }
            if (effective.length == 0)
                return result;

            for (uint i = 0; i < config.stations.length; i++) {
                var station = config.stations.get (i);
                string name = station.name.down ();
                bool matches = true;
                for (uint j = 0; j < effective.length; j++) {
                    if (!name.contains (effective.get (j))) {
                        matches = false;
                        break;
                    }
                }
                if (!matches)
                    continue;
                result += station.id;
                if (result.length >= MAX_RESULTS)
                    break;
            }
            return result;
        }

        public static GLib.HashTable<string, GLib.Variant> result_meta (RadioStation station) {
            var meta = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
            meta.insert ("id", new GLib.Variant.string (station.id));
            meta.insert ("name", new GLib.Variant.string (station.name));
            string description = station.secondary_text (false);
            if (description != "")
                meta.insert ("description", new GLib.Variant.string (description));
            return meta;
        }

        private static GLib.HashTable<string, GLib.Variant> placeholder_meta (string id) {
            var meta = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
            meta.insert ("id", new GLib.Variant.string (id));
            meta.insert ("name", new GLib.Variant.string (""));
            return meta;
        }
    }
}
