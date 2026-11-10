// SPDX-License-Identifier: GPL-3.0-or-later

using Json;

namespace Gradio {

    public class AppConfig : GLib.Object {
        public const int FORMAT_VERSION = 1;

        public double volume = 0.8;
        public bool show_technical_info = false;
        public GLib.GenericArray<RadioStation> stations = new GLib.GenericArray<RadioStation> ();

        public string path { get; private set; }

        public AppConfig (string? path = null) {
            this.path = path ?? default_path ();
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
