// SPDX-License-Identifier: GPL-3.0-or-later

using Json;

namespace Gradio {

    public class AppConfig : GLib.Object {
        public const int FORMAT_VERSION = 1;
        public const int DEFAULT_WINDOW_WIDTH = 900;
        public const int DEFAULT_WINDOW_HEIGHT = 600;
        public const int MIN_WINDOW_WIDTH = 320;
        public const int MIN_WINDOW_HEIGHT = 240;
        public const int MAX_WINDOW_SIZE = 16384;
        public const int DEFAULT_ICON_SIZE = 48;

        public double volume = 0.8;
        public bool show_technical_info = false;
        public int window_width = DEFAULT_WINDOW_WIDTH;
        public int window_height = DEFAULT_WINDOW_HEIGHT;
        public bool maximized = false;
        public int icon_size = DEFAULT_ICON_SIZE;
        public SearchSortMode search_sort = SearchSortMode.RELEVANCE;
        public SearchFilters search_filters = new SearchFilters ();
        public GLib.GenericArray<RadioStation> stations = new GLib.GenericArray<RadioStation> ();

        public string path { get; private set; }

        public AppConfig (string? path = null) {
            this.path = path ?? default_path ();
        }

        public static int normalize_icon_size (int size) {
            switch (size) {
                case 32:
                case 48:
                case 64:
                case 96:
                    return size;
                default:
                    return DEFAULT_ICON_SIZE;
            }
        }

        public static string default_path () {
            return GLib.Path.build_filename (GLib.Environment.get_user_config_dir (), "gradio", "config.json");
        }

        public static AppConfig load (string path) throws GLib.Error {
            var config = new AppConfig (path);
            if (!GLib.FileUtils.test (path, GLib.FileTest.EXISTS))
                return config;

            string contents;
            GLib.FileUtils.get_contents (path, out contents);
            if (contents.strip () == "")
                return config;

            var parser = new Json.Parser ();
            parser.load_from_data (contents);
            var root = parser.get_root ();
            if (root == null || root.get_value_type () != typeof (Json.Object))
                throw new GLib.FileError.FAILED ("invalid config root");

            var obj = root.get_object ();
            var settings_node = obj.get_member ("settings");
            var settings = settings_node != null && settings_node.get_value_type () == typeof (Json.Object)
                ? settings_node.get_object () : null;
            if (settings != null) {
                var volume_node = settings.get_member ("volume");
                if (volume_node != null && volume_node.get_value_type () == typeof (double)) {
                    double value = volume_node.get_double ();
                    if (value == value)
                        config.volume = value.clamp (0.0, 1.0);
                } else if (volume_node != null && volume_node.get_value_type () == typeof (int64)) {
                    config.volume = ((double) volume_node.get_int ()).clamp (0.0, 1.0);
                }
                config.show_technical_info = settings.get_boolean_member_with_default ("show_technical_info", config.show_technical_info);

                int width = (int) settings.get_int_member_with_default ("window_width", config.window_width);
                int height = (int) settings.get_int_member_with_default ("window_height", config.window_height);
                if (width >= MIN_WINDOW_WIDTH && width <= MAX_WINDOW_SIZE)
                    config.window_width = width;
                if (height >= MIN_WINDOW_HEIGHT && height <= MAX_WINDOW_SIZE)
                    config.window_height = height;
                config.maximized = settings.get_boolean_member_with_default ("maximized", config.maximized);
                config.icon_size = normalize_icon_size (
                    (int) settings.get_int_member_with_default ("icon_size", config.icon_size));
                config.search_sort = StationSort.search_from_string (
                    settings.get_string_member_with_default ("search_sort",
                        StationSort.search_to_string (config.search_sort)));

                var filters_node = settings.get_member ("search_filters");
                if (filters_node != null && filters_node.get_value_type () == typeof (Json.Object)) {
                    var filters = filters_node.get_object ();
                    config.search_filters.country = filters.get_string_member_with_default ("country", "");
                    config.search_filters.state = filters.get_string_member_with_default ("state", "");
                    config.search_filters.language = filters.get_string_member_with_default ("language", "");
                    config.search_filters.tag = filters.get_string_member_with_default ("tag", "");
                }
            }

            var array_node = obj.get_member ("stations");
            var array = array_node != null && array_node.get_value_type () == typeof (Json.Array)
                ? array_node.get_array () : null;
            if (array != null) {
                for (uint i = 0; i < array.get_length (); i++) {
                    var element = array.get_element (i);
                    if (element == null || element.get_value_type () != typeof (Json.Object))
                        continue;
                    var station = RadioStation.from_json_object (element.get_object ());
                    if (station == null || station.id == "")
                        continue;
                    config.add_station (station);
                }
            }

            return config;
        }

        public void save () throws GLib.Error {
            string dir = GLib.Path.get_dirname (path);
            GLib.DirUtils.create_with_parents (dir, 0755);

            var root = new Json.Object ();
            root.set_int_member ("version", FORMAT_VERSION);

            var settings = new Json.Object ();
            settings.set_double_member ("volume", volume);
            settings.set_boolean_member ("show_technical_info", show_technical_info);
            settings.set_int_member ("window_width", window_width);
            settings.set_int_member ("window_height", window_height);
            settings.set_boolean_member ("maximized", maximized);
            settings.set_int_member ("icon_size", icon_size);
            settings.set_string_member ("search_sort", StationSort.search_to_string (search_sort));

            var filters = new Json.Object ();
            filters.set_string_member ("country", search_filters.country);
            filters.set_string_member ("state", search_filters.state);
            filters.set_string_member ("language", search_filters.language);
            filters.set_string_member ("tag", search_filters.tag);
            settings.set_object_member ("search_filters", filters);
            root.set_object_member ("settings", settings);

            var array = new Json.Array ();
            for (uint i = 0; i < stations.length; i++)
                array.add_element (stations.get (i).to_json_node ());
            root.set_array_member ("stations", array);

            var node = new Json.Node (Json.NodeType.OBJECT);
            node.set_object (root);

            var generator = new Json.Generator ();
            generator.set_root (node);
            generator.set_pretty (true);
            size_t length;
            string data = generator.to_data (out length);

            string tmp = path + ".tmp";
            GLib.FileUtils.set_contents (tmp, data);
            if (GLib.FileUtils.rename (tmp, path) != 0) {
                GLib.FileUtils.remove (tmp);
                throw new GLib.FileError.FAILED ("could not replace config file");
            }
        }

        public bool add_station (RadioStation station) {
            if (contains_station (station.id))
                return false;
            stations.add (station);
            return true;
        }

        public bool remove_station (string id) {
            for (uint i = 0; i < stations.length; i++) {
                if (stations.get (i).id == id) {
                    stations.remove_index (i);
                    return true;
                }
            }
            return false;
        }

        public bool move_station (string id, string target_id, bool after) {
            if (id == target_id)
                return false;

            int from = -1;
            int target = -1;
            for (uint i = 0; i < stations.length; i++) {
                if (stations.get (i).id == id)
                    from = (int) i;
                if (stations.get (i).id == target_id)
                    target = (int) i;
            }
            if (from < 0 || target < 0)
                return false;

            var station = stations.get ((uint) from);
            stations.remove_index ((uint) from);

            target = -1;
            for (uint i = 0; i < stations.length; i++) {
                if (stations.get (i).id == target_id) {
                    target = (int) i;
                    break;
                }
            }
            if (target < 0)
                return false;

            int insert_at = target + (after ? 1 : 0);
            if (insert_at == from) {
                stations.insert (from, station);
                return false;
            }

            stations.insert (insert_at, station);
            return true;
        }

        public bool contains_station (string id) {
            return find_station (id) != null;
        }

        public RadioStation? find_station (string id) {
            for (uint i = 0; i < stations.length; i++) {
                var station = stations.get (i);
                if (station.id == id)
                    return station;
            }
            return null;
        }
    }
}
